--[[
	Player duels in the Arena: queues, challenges and matches.

	Request actions:
	  "DuelQueue", mode       join the 1v1 queue, or (party leader of two)
	                          the 2v2 queue for the whole party
	  "DuelCancel"            leave the queue (any member cancels a party's)
	  "DuelChallenge", userId challenge someone in the server to a friendly 1v1
	  "DuelRespond", userId, accept   answer a challenge
	  "DuelLeave"             forfeit the current duel

	The Social remote tells clients:
	  "Queue", { Mode, Since, Waiting } | nil   your queue state
	  "Challenge", fromId, fromName, rating     someone challenged you
	  "Match", { Id, Mode, Ranked, StartsAt, Ends, Team, Teams }
	  "Fight"                                   the countdown is over
	  "MatchEnd", { Won, Draw, Reason, Rating, Delta, Coins, Ranked }
	  "Feed", text                              a duel result, for everyone's chat

	A match: both sides are moved into one of the Arena's lanes, shielded and
	facing off for a countdown, then fight until a side is down (or the time
	runs out: the healthier side wins). Duel fighters only hurt their
	opponents (Shared.Matchmaking.versus). Leaving the Arena, the session or
	the game forfeits. Queue matches are rated (Elo); challenges are friendly.
	Each player's rating, wins and losses save in their profile (Duel).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local Season = require(ReplicatedStorage.Shared.Season)
local CombatServer = require(script.Parent.CombatServer)
local ArenaSessions = require(script.Parent.ArenaSessions)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Duels = {}

-- { Mode, Players, Since, SinceServer, Rating, Size }
local queue = {}
-- [id] = { Id, Mode, Ranked, Teams, Out, Slot, State, StartsAt, Ends, Connections }
local matches = {}
local matchOf: { [Player]: any } = {}
local challenges: { [Player]: { [Player]: number } } = {} -- target -> challenger -> expiry
local nextId = 0

local function serverNow(): number
	local ok, now = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return if ok and type(now) == "number" then now else os.clock()
end

-- The player's duel record (created on first use).
function Duels.record(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	profile.Duel = profile.Duel or { Rating = Matchmaking.StartRating, Wins = 0, Losses = 0, Streak = 0 }
	return profile.Duel
end

-- Public on the player, for everyone's player list.
local function publish(player: Player)
	local record = Duels.record(player)
	if record then
		player:SetAttribute("DuelRating", record.Rating)
		player:SetAttribute("DuelWins", record.Wins)
	end
	local profile = PlayerData.get(player)
	if profile and profile.Season then
		player:SetAttribute("SeasonLevel", (Season.levelFor(profile.Season.XP or 0)))
	end
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root :: BasePart
	end
	return nil, nil
end

-- Why `player` can't start a duel right now, or nil.
local function busy(player: Player): string?
	if matchOf[player] then
		return "is already in a duel"
	elseif player:GetAttribute("CombatSession") then
		return "is in an Arena session"
	elseif player:GetAttribute("Expedition") then
		return "is on an expedition"
	elseif not alive(player) then
		return "isn't ready"
	elseif not PlayerData.get(player) then
		return "is still loading"
	end
	return nil
end

-- "You are on an expedition." / "Sam is on an expedition."
local function subject(member: Player, player: Player, reason: string): string
	if member == player then
		return "You " .. (string.gsub(reason, "^is ", "are ")) .. "."
	end
	return member.DisplayName .. " " .. reason .. "."
end

local function entryOf(player: Player)
	for i, entry in queue do
		if table.find(entry.Players, player) then
			return entry, i
		end
	end
	return nil, nil
end

local function waiting(mode: string): number
	local n = 0
	for _, entry in queue do
		if entry.Mode == mode then
			n += 1
		end
	end
	return n
end

local function pushQueue(entry)
	for _, member in entry.Players do
		member:SetAttribute("DuelQueue", entry.Mode)
		Remotes.Social:FireClient(
			member,
			"Queue",
			{ Mode = entry.Mode, Since = entry.SinceServer, Waiting = waiting(entry.Mode) }
		)
	end
end

local function dequeue(player: Player, note: string?)
	local entry, index = entryOf(player)
	if not entry then
		return false
	end
	table.remove(queue, index)
	for _, member in entry.Players do
		member:SetAttribute("DuelQueue", nil)
		Remotes.Social:FireClient(member, "Queue", nil)
		if note and member ~= player then
			Remotes.Notify:FireClient(member, note)
		end
	end
	return true
end

local function freeSlot(): number?
	local used = {}
	for _, match in matches do
		used[match.Slot] = true
	end
	for slot = 1, Matchmaking.Lanes do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function teamRating(team): number
	local sum, n = 0, 0
	for _, member in team do
		local record = Duels.record(member)
		sum += if record then record.Rating else Matchmaking.StartRating
		n += 1
	end
	return if n > 0 then sum / n else Matchmaking.StartRating
end

local function teamsInfo(match)
	local teams = {}
	for t, team in match.Teams do
		teams[t] = {}
		for _, member in team do
			local record = Duels.record(member)
			table.insert(teams[t], {
				UserId = member.UserId,
				Name = member.DisplayName,
				Rating = if record then record.Rating else Matchmaking.StartRating,
			})
		end
	end
	return teams
end

local finish -- (below)

-- A fighter is out (down, forfeited or gone); a side with no one left loses.
local function knockOut(match, player: Player, reason: string)
	if match.State == "Done" or match.Out[player] then
		return
	end
	match.Out[player] = reason
	for t, team in match.Teams do
		local standing = false
		for _, member in team do
			if not match.Out[member] then
				standing = true
			end
		end
		if not standing then
			finish(match, if t == 1 then 2 else 1, reason)
			return
		end
	end
end

local function release(match)
	for _, team in match.Teams do
		for _, member in team do
			if matchOf[member] == match then
				matchOf[member] = nil
			end
			if member.Parent then
				member:SetAttribute("MatchId", nil)
				member:SetAttribute("MatchTeam", nil)
				if member:GetAttribute("CombatSession") == "Duel" then
					ArenaSessions.leave(member)
				end
				local humanoid = alive(member)
				if humanoid then
					humanoid.Health = humanoid.MaxHealth
				end
			end
		end
	end
	for _, connection in match.Connections do
		connection:Disconnect()
	end
	matches[match.Id] = nil
end

-- The match is over: `winner` is the winning team (nil: a draw).
function finish(match, winner: number?, reason: string)
	if match.State == "Done" then
		return
	end
	match.State = "Done"
	local ratings = { teamRating(match.Teams[1]), teamRating(match.Teams[2]) }
	local rewards = if match.Ranked then Matchmaking.Rewards.Ranked else Matchmaking.Rewards.Friendly
	local names = {}
	for t, team in match.Teams do
		local list = {}
		for _, member in team do
			table.insert(list, member.DisplayName)
		end
		names[t] = table.concat(list, " & ")
	end
	for t, team in match.Teams do
		local won = winner == t
		local other = ratings[if t == 1 then 2 else 1]
		for _, member in team do
			local record = Duels.record(member)
			local before = if record then record.Rating else Matchmaking.StartRating
			local after = before
			if record and winner then
				if match.Ranked then
					after = Matchmaking.rated(before, other, won)
					record.Rating = after
				end
				record.Wins += if won then 1 else 0
				record.Losses += if won then 0 else 1
				record.Streak = if won then record.Streak + 1 else 0
			end
			local coins = if winner == nil then 0 elseif won then rewards.Win else rewards.Loss
			if member.Parent then
				if coins > 0 then
					PlayerData.addCoins(member, coins)
				end
				Progress.addXP(member, if won then "DuelWin" else "DuelPlay")
				publish(member)
				PlayerData.sync(member)
				Remotes.Social:FireClient(member, "MatchEnd", {
					Won = won,
					Draw = winner == nil,
					Reason = reason,
					Ranked = match.Ranked,
					Rating = after,
					Delta = after - before,
					Coins = coins,
					Opponents = names[if t == 1 then 2 else 1],
				})
			end
		end
	end
	-- Everyone hears how it went (their chat feed).
	if winner then
		Remotes.Social:FireAllClients(
			"Feed",
			string.format(
				"⚔ %s defeated %s in a %s %s.",
				names[winner],
				names[if winner == 1 then 2 else 1],
				if match.Ranked then "ranked" else "friendly",
				match.Mode
			)
		)
	end
	task.delay(Matchmaking.EndPause, release, match)
end

local function startMatch(mode: string, teams, ranked: boolean): (boolean, string?)
	local slot = freeSlot()
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local floor = landmarks and landmarks:GetAttribute("ArenaFloor")
	if not slot or typeof(floor) ~= "Vector3" then
		return false, "The Arena is full. Try again in a moment."
	end
	for _, team in teams do
		for _, member in team do
			local reason = busy(member)
			if reason then
				return false, member.DisplayName .. " " .. reason .. "."
			end
		end
	end
	nextId += 1
	local now = os.clock()
	local match = {
		Id = "D" .. nextId,
		Mode = mode,
		Ranked = ranked,
		Teams = teams,
		Out = {},
		Slot = slot,
		State = "Countdown",
		StartsAt = now + Matchmaking.Countdown,
		Ends = now + Matchmaking.Countdown + Matchmaking.TimeLimit,
		Connections = {},
	}
	matches[match.Id] = match
	local startsAt = serverNow() + Matchmaking.Countdown
	local info = teamsInfo(match)
	for t, team in teams do
		for index, member in team do
			dequeue(member)
			matchOf[member] = match
			CombatServer.reset(member)
			member:SetAttribute("MatchId", match.Id)
			member:SetAttribute("MatchTeam", t)
			member:SetAttribute("PvPEnabled", true)
			member:SetAttribute("CombatSession", "Duel")
			local humanoid, root = alive(member)
			local spot, centre = Matchmaking.lane(slot, t, index, #team)
			if humanoid and root then
				local at = floor + spot + Vector3.new(0, 3, 0)
				member.Character:PivotTo(CFrame.lookAt(at, floor + centre + Vector3.new(0, 3, 0)))
				humanoid.Health = humanoid.MaxHealth
				local shield = Instance.new("ForceField")
				shield.Visible = true
				shield.Parent = member.Character
				Debris:AddItem(shield, Matchmaking.Countdown)
				table.insert(
					match.Connections,
					humanoid.Died:Connect(function()
						knockOut(match, member, "Defeated")
					end)
				)
			end
			Remotes.Social:FireClient(member, "Match", {
				Id = match.Id,
				Mode = mode,
				Ranked = ranked,
				StartsAt = startsAt,
				Ends = startsAt + Matchmaking.TimeLimit,
				Team = t,
				Teams = info,
			})
		end
	end
	return true, nil
end

-- Queue ----------------------------------------------------------------------

local function join(player: Player, mode: any)
	local spec = Matchmaking.Modes[mode]
	if not spec then
		return reply(false, "Unknown duel mode.")
	end
	local group = { player }
	if spec.Size > 1 then
		local party = Party.of(player)
		if not party or #party.Members ~= spec.Size then
			return reply(false, string.format("A %s needs a party of exactly %d.", spec.Name, spec.Size))
		end
		if party.Leader ~= player then
			return reply(false, "Only the party leader can queue the party.")
		end
		group = table.clone(party.Members)
	end
	for _, member in group do
		local reason = busy(member)
		if reason then
			return reply(false, subject(member, player, reason))
		end
	end
	for _, member in group do
		dequeue(member)
	end
	local entry = {
		Mode = mode,
		Players = group,
		Since = os.clock(),
		SinceServer = serverNow(),
		Rating = teamRating(group),
		Size = spec.Size,
	}
	table.insert(queue, entry)
	pushQueue(entry)
	for _, other in queue do
		if other ~= entry and other.Mode == mode then
			pushQueue(other) -- (the waiting count changed)
		end
	end
	return reply(true, "Searching for a " .. spec.Name .. "…")
end

-- Pairs waiting entries of each mode while there's a lane free.
function Duels.pairUp()
	for mode in Matchmaking.Modes do
		local entries = {}
		for _, entry in queue do
			if entry.Mode == mode then
				table.insert(entries, entry)
			end
		end
		for _, pair in Matchmaking.pair(entries, os.clock()) do
			if not freeSlot() then
				return
			end
			local a, b = entries[pair[1]], entries[pair[2]]
			local ok, problem = startMatch(mode, { table.clone(a.Players), table.clone(b.Players) }, true)
			if not ok then
				-- Someone became busy: drop whoever it was from the queue.
				for _, entry in { a, b } do
					for _, member in entry.Players do
						if busy(member) then
							dequeue(member, problem)
							Remotes.Notify:FireClient(member, "Left the duel queue: " .. (problem or ""))
						end
					end
				end
			end
		end
	end
end

-- Challenges -----------------------------------------------------------------

local function byUserId(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function challenge(player: Player, userId: any)
	local target = byUserId(userId)
	if not target or target == player then
		return reply(false, "That player isn't here.")
	end
	for _, member in { player, target } do
		local reason = busy(member)
		if reason then
			return reply(false, subject(member, player, reason))
		end
	end
	challenges[target] = challenges[target] or {}
	challenges[target][player] = os.clock() + Matchmaking.ChallengeSeconds
	local record = Duels.record(player)
	Remotes.Social:FireClient(
		target,
		"Challenge",
		player.UserId,
		player.DisplayName,
		if record then record.Rating else Matchmaking.StartRating
	)
	return reply(true, "Challenged " .. target.DisplayName .. " to a duel.")
end

local function respond(player: Player, userId: any, accept: any)
	local from = byUserId(userId)
	local pending = challenges[player]
	local expiry = from and pending and pending[from]
	if pending and from then
		pending[from] = nil
	end
	if not from or not expiry or os.clock() > expiry then
		return reply(false, "That challenge has expired.")
	end
	if accept ~= true then
		Remotes.Notify:FireClient(from, player.DisplayName .. " declined your duel.")
		return reply(true, "Challenge declined.")
	end
	local ok, problem = startMatch("1v1", { { from }, { player } }, false)
	if not ok then
		return reply(false, problem or "The duel couldn't start.")
	end
	return reply(true, "Duel accepted!")
end

-- Lifecycle ------------------------------------------------------------------

local function step()
	local now = os.clock()
	Duels.pairUp()
	-- A party that changed shape can't stay queued as a pair.
	for i = #queue, 1, -1 do
		local entry = queue[i]
		if entry.Size > 1 then
			local party = Party.of(entry.Players[1])
			local intact = party ~= nil and #party.Members == entry.Size
			for _, member in entry.Players do
				intact = intact and Party.of(member) == party
			end
			if not intact then
				dequeue(entry.Players[1], "Your party changed, so it left the duel queue.")
			end
		end
	end
	for _, pending in challenges do
		for from, expiry in pending do
			if now > expiry then
				pending[from] = nil
			end
		end
	end
	for _, match in matches do
		if match.State == "Countdown" and now >= match.StartsAt then
			match.State = "Fight"
			for _, team in match.Teams do
				for _, member in team do
					Remotes.Social:FireClient(member, "Fight")
				end
			end
		elseif match.State == "Fight" and now >= match.Ends then
			-- Time: the side with more health left (by share) wins.
			local share = {}
			for t, team in match.Teams do
				share[t] = 0
				for _, member in team do
					local humanoid = alive(member)
					if humanoid and not match.Out[member] then
						share[t] += humanoid.Health / math.max(1, humanoid.MaxHealth)
					end
				end
			end
			local winner = if share[1] > share[2] + 0.01 then 1 elseif share[2] > share[1] + 0.01 then 2 else nil
			finish(match, winner, "Time")
		end
	end
end

function Duels.matchOf(player: Player)
	return matchOf[player]
end

function Duels.start()
	Shop.register("DuelQueue", join)
	Shop.register("DuelCancel", function(player)
		if not dequeue(player, player.DisplayName .. " left the duel queue.") then
			return reply(false, "You're not in a queue.")
		end
		return reply(true, "Left the duel queue.")
	end)
	Shop.register("DuelChallenge", challenge)
	Shop.register("DuelRespond", respond)
	Shop.register("DuelLeave", function(player)
		local match = matchOf[player]
		if not match or match.State == "Done" then
			return reply(false, "You're not in a duel.")
		end
		knockOut(match, player, "Forfeit")
		return reply(true, "You forfeited the duel.")
	end)
	local function watch(player: Player)
		-- Leaving the Arena session (the Leave button, walking out, respawning)
		-- forfeits a duel in progress.
		player:GetAttributeChangedSignal("CombatSession"):Connect(function()
			local match = matchOf[player]
			if match and match.State ~= "Done" and player:GetAttribute("CombatSession") ~= "Duel" then
				knockOut(match, player, "Left")
			end
		end)
		task.spawn(function()
			for _ = 1, 60 do
				if not player.Parent then
					return
				end
				if PlayerData.get(player) then
					publish(player)
					return
				end
				task.wait(1)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dequeue(player, player.DisplayName .. " left the game, so your party left the duel queue.")
		local match = matchOf[player]
		if match then
			knockOut(match, player, "Left")
		end
		challenges[player] = nil
		for _, pending in challenges do
			pending[player] = nil
		end
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 0.25 then
			timer = 0
			step()
		end
	end)
end

-- (Tests drive the clock themselves.)
Duels._step = step

return Duels
