local Analytics = require(script.Parent.Analytics)
local ArenaDrop = require(script.Parent.ArenaDrop)
--[[
	Player duels in the Arena: queues, challenges and matches.

	Request actions:
	  "DuelQueue", mode       join a queue: "1v1" (Ranked), "casual" (Casual),
	                          or (party leader of two) "2v2" for the party
	  "DuelCancel"            leave the queue (any member cancels a party's)
	  "DuelChallenge", userId, stats   challenge someone in the server to a
	                          1v1: stats "Full" (everything earned) or "Even"
	  "DuelRespond", userId, accept   answer a challenge
	  "DuelLeave"             forfeit the current duel
	  "DuelPivot", pick?, hold?   between Ranked rounds: nil or "Keep" (as
	                          you are: READY), "Counter" (the round's loser:
	                          the armor answer to what hurt them,
	                          Systems/CounterServer) or a miner's number
	                          (the roster on: the loser's counter-pick).
	                          Locks it in; hold = true only marks it (it's
	                          worn if the window closes on it)
	  "DuelAuto", on          auto queue (Shared.AutoQueue): on call for the
	                          lobby (the default) or not
	  "DuelFill", id, accept  answer a fill-in offer for queue entry `id`
	  "DuelReady", id, accept   answer MATCH READY for ready check `id`
	  "IntroQueue"            a new player's first fight: queued with another
	                          new player, else a lobby player on call, else
	                          the sparring rival (ArenaSessions.enterTraining)

	The Social remote tells clients:
	  "Queue", { Mode, Since, Waiting, Intro } | nil   your queue state
	  "FillIn", { Id, Mode, Name, Who, Rating, Bonus, Seconds }   someone's
	                                            waiting in a queue: step in?
	  "FillInOver", id                          that queue was filled or left
	  "MatchReady", { Id, Mode, Name, Ranked, Seconds, Ends, Foes = { { Name,
	                  Rating } }, Accepted, Ready, Of }   the queue found you a
	                                            match: JOIN? (Ready of Of in)
	  "MatchReadyState", { Id, Ready, Of }      someone in it said JOIN
	  "MatchReadyOver", { Id, Reason, Searching }   it's over: "Started",
	                                            "Declined", "Expired" or "Gone"
	                                            (Searching: you're still queued)
	  "Challenge", fromId, fromName, rating, stats   someone challenged you
	  "Match", { Id, Mode, Ranked, Rules, StartsAt, Ends, Team, Teams,
	             Called, Bonus, Intro }         (Called: pulled from the lobby
	                                            for it, Bonus coins on a win)
	  "Fight"                                   the countdown is over
	  "Round", { Phase = "Pivot", Round, Winner, Reason, Wins, Team, Ends, Scout,
	             CanSwap, CanCounter, Threat, Counter }
	                                            a Ranked round is over (Scout:
	                                            the elements the other side
	                                            fought with; Threat: what hurt
	                                            you; Counter: your counter's
	                                            plan, Shared.CounterGear)
	  "Round", { Phase = "Locked", Team }       a side locked its pick
	  "Round", { Phase = "Reveal", Round, Wins, Team, StartsAt, Ends, Picks }
	                                            both picks, then the countdown
	  "MatchEnd", { Won, Draw, Reason, Rating, Delta, Coins, Ranked, Rules,
	                Streak, Called, Bonus, Intro, Tournament = { Streak, Win, Of, Counted, Champion,
	                Share, Swings, NextAt, NextShare } (a queued 1v1: the
	                arena tournament's run, Shared.SwingRestore) }
	  "Feed", text                              a duel result, for everyone's chat

	A match: both sides are moved into one of the Arena's lanes, shielded and
	facing off for a countdown, then fight until a side is down. There's no
	clock on screen: only a long stalemate cap (Matchmaking.TimeLimit) ends a
	fight nobody finishes, the healthier side winning. Duel fighters only hurt their
	opponents (Shared.Matchmaking.versus). Leaving the Arena, the session or
	the game forfeits. Each match plays by a PvP rule (Shared.PvPRules):
	Ranked queues are rated (Elo) and Casual is unrated, both on full
	progression (your current stats); a challenge plays the challenger's
	choice of full progression or even stats. Fighters carry it as MatchStats /
	MatchRarityCap, which the combat kit and stats read.
	1v1 Ranked plays rounds (Shared.Matchmaking.Rounds): first to two, three
	at most. A lethal blow ends the round: the loser's body blows apart as in
	any death (RoundKO: client ElementalDeath), but they aren't killed, so the
	match goes on, and the next round puts them back together (stage). Between rounds, the pivot window: preset swaps
	only (Presets.wear), both lock at once, then the picks are revealed.
	Each player's rating, wins and losses save in their profile (Duel).
	Auto queue (Shared.AutoQueue): a lone 1v1 queue entry calls the lobby
	after a few seconds. Free players on call (the default) are pulled in,
	closest rating first, their rating safe from a loss and a bonus on a
	win; players who turned it off are offered the match instead (FillIn).
	A new player's first fight is the "intro" queue: on a quiet server
	(AutoQueue.Intro.Populated) the sparring rival at once; on a busy one two
	new players pair at once, alone a lobby player is called, still alone
	the sparring rival.
	Nobody is put in a queued duel without saying so: when the queue pairs
	two entries, everyone in them gets MATCH READY (JOIN / DECLINE) for
	Matchmaking.ReadySeconds, and the match starts once they've all joined.
	Whoever declines or lets it run out leaves the queue; the other side
	keeps searching, its place kept. A fill-in from the lobby has said yes
	already, so only the side that was waiting is asked. (A first fight, the
	intro queue, starts at once: the new player has just pressed START.)
	Queued 1v1s (Ranked or Casual, not challenges) are the arena tournament
	(Shared.SwingRestore): the 1st, 5th and 10th win of a run restore the
	pick's swings (Restores), and ten in a row wins the tournament (Ranked:
	with its Arena Cache, ArenaStreaks).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AutoQueue = require(ReplicatedStorage.Shared.AutoQueue)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
local Season = require(ReplicatedStorage.Shared.Season)
local Leagues = require(ReplicatedStorage.Shared.Leagues)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local CombatServer = require(script.Parent.CombatServer)
local ArenaSessions = require(script.Parent.ArenaSessions)
local PrivateArenas = require(script.Parent.PrivateArenas)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Progress = require(script.Parent.Progress)
local ArenaStreaks = require(script.Parent.ArenaStreaks)
local RewardRoll = require(ReplicatedStorage.Shared.RewardRoll)
local Restores = require(script.Parent.Restores)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)
local CounterServer = require(script.Parent.CounterServer)

local reply = Shop.reply

local Duels = {}
-- (Server.IntroRoundsServer, once started: a new miner's 1v1 wins pay their set.)
Duels.IntroRounds = nil :: any

-- { Id, Mode, Players, Since, SinceServer, Rating, Size, Asked }
local queue = {}
local nextEntry = 0
-- [id] = { Id, Mode, Ranked, Teams, Out, Slot, State, StartsAt, Ends, Connections }
local matches = {}
local matchOf: { [Player]: any } = {}
-- Ready checks (MATCH READY), by id: { Id, Mode, Sides = { { Players,
-- Entry? } }, Accepted = { [Player] = true }, Ends, Start }. A side's Entry
-- is its queue entry (a called fill-in has none); Start starts the match.
local readyChecks = {}
local nextReady = 0
-- target -> challenger -> { Expiry, Stats }
local challenges: { [Player]: { [Player]: { Expiry: number, Stats: string } } } = {}
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
	-- (Solo: 1v1 wins, for the Hall of Fame. A record from before it counts
	-- every win it had as one.)
	local record = profile.Duel :: any
	record.Solo = record.Solo or record.Wins or 0
	-- Its league (Shared.Leagues): from the rating, the first time.
	if type(record.League) ~= "table" then
		pcall(function()
			local step = Leagues.stepOf(record.Rating or Matchmaking.StartRating)
			record.League = { Step = step, Season = Season.Name, Best = step, Safe = 0 }
		end)
	end
	return profile.Duel
end

-- This server's ladder for `player` (by everyone's DuelRating here): their
-- place, how many there are, how many they passed coming up from `before`,
-- and who's directly above (and the rating gap). (The Climb: Client
-- MatchResult.)
function Duels.ladder(player: Player, before: number?)
	local mine = player:GetAttribute("DuelRating") or Matchmaking.StartRating
	local rank, of, passed = 1, 0, 0
	local above, gap = nil, math.huge
	for _, other in Players:GetPlayers() do
		local rating = other:GetAttribute("DuelRating")
		if type(rating) ~= "number" then
			continue
		end
		of += 1
		if other ~= player then
			if rating > mine then
				rank += 1
				if rating - mine < gap then
					above, gap = other, rating - mine
				end
			elseif before and rating >= before and rating < mine then
				passed += 1
			end
		end
	end
	return {
		Rank = rank,
		Of = math.max(of, 1),
		Passed = passed,
		Next = if above then { Name = above.DisplayName, Gap = gap } else nil,
	}
end

-- Public on the player, for everyone's player list.
local function publish(player: Player)
	local record = Duels.record(player)
	if record then
		player:SetAttribute("DuelRating", record.Rating)
		-- (its league's step, 1-16: nameplates, PLAY, the versus card)
		pcall(function()
			local league = (record :: any).League
			player:SetAttribute("League", if type(league) == "table" and (league.Played or 0) > 0 then league.Step else nil)
			player:SetAttribute("LeagueSafe", if type(league) == "table" then league.Safe or 0 else 0)
		end)
		player:SetAttribute("DuelWins", record.Wins)
		player:SetAttribute("DuelsPlayed", (record :: any).Played or 0)
		player:SetAttribute("DuelAuto", AutoQueue.setting(record))
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
	elseif player:GetAttribute("DungeonId") or player:GetAttribute("DungeonQueue") then
		return "is in a dungeon or dungeon queue"
	elseif player:GetAttribute("RiftRun") then
		return "is in the Rift"
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
			{ Mode = entry.Mode, Since = entry.SinceServer, Waiting = waiting(entry.Mode), Intro = entry.Mode == AutoQueue.IntroMode }
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
	-- Anyone offered this entry as a fill-in: the offer's over.
	for asked in entry.Asked or {} do
		if asked.Parent then
			Remotes.Social:FireClient(asked, "FillInOver", entry.Id)
		end
	end
	return true
end

local function freeSlot(): number?
	local used = {}
	for _, match in matches do
		if match.Slot then -- (none: it's in a ring of Arena Row)
			used[match.Slot] = true
		end
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

-- Each fighter's lead kaiju (the first of the team out): what only this
-- game has, and a fair hint at what to bring against them.
local function leadKaiju(member: Player)
	local ok, lead = pcall(function()
		local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
		local profile = PlayerData.get(member)
		local roster = profile and (profile :: any).Kaiju
		if type(roster) ~= "table" or type(roster.List) ~= "table" then
			return nil
		end
		local id = roster.Active or (type(roster.Team) == "table" and roster.Team[1])
		for _, record in roster.List do
			if type(record) == "table" and (record.Id == id or id == nil) then
				local species = Kaiju.species(record.Species)
				return { Species = record.Species, Name = species and species.Name or record.Species, Element = record.Element, Level = record.Level or 1 }
			end
		end
		return nil
	end)
	return if ok then lead else nil
end

local function teamsInfo(match)
	local teams = {}
	for t, team in match.Teams do
		teams[t] = {}
		for _, member in team do
			local record = Duels.record(member) :: any
			local rating = if record then record.Rating else Matchmaking.StartRating
			table.insert(teams[t], {
				UserId = member.UserId,
				Name = member.DisplayName,
				Rating = rating,
				-- (the versus card: Client SocialUI)
				League = if record and type(record.League) == "table" then record.League.Step else Leagues.stepOf(rating),
				Wins = if record then record.Wins or 0 else 0,
				Played = if record then (record.Wins or 0) + (record.Losses or 0) else 0,
				Streak = if record then record.RankedStreak or 0 else 0,
				Kaiju = leadKaiju(member),
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
				member:SetAttribute("MatchStats", nil)
				member:SetAttribute("MatchRarityCap", nil)
				if member.Character then
					member.Character:SetAttribute("RoundKO", nil)
				end
				if member:GetAttribute("CombatSession") == "Duel" then
					-- (a new miner in the intro, after a first fight: out of the
					-- duel where they stand, their round's card up; CONTINUE or
					-- REMATCH from here, never a trip to the Outpost first)
					local stay = match.Intro and IntroRounds.eligible(PlayerData.get(member))
					ArenaSessions.leave(member, stay)
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
	for _, shield in match.Shields do
		shield:Destroy()
	end
	-- (its ring of Arena Row free again once everyone's out of it)
	if match.Center then
		for _, team in match.Teams do
			for _, member in team do
				PrivateArenas.release(member)
			end
		end
	end
	matches[match.Id] = nil
end

-- After a first fight between two new miners (Shared.AutoQueue.Intro):
-- each can ask for a REMATCH ("IntroRematch": both asking, another fight
-- between them) or go on with their intro rounds (into the Arena: the
-- offer's off, and the other's told). IntroRematch on each: the other's
-- name, while it stands (Duels.RematchFor seconds).
Duels.RematchFor = 45
Duels.Stage = "GrandArena" -- (the ring duels take first: Shared.Outpost.Settlement.Stages)
Duels.RematchTries = 30 -- (half a second apart: the loser's respawn)
local Rematch = { Offers = {} :: { [Player]: any } }
function Rematch.clear(player: Player, tell: string?)
	local offer = Rematch.Offers[player]
	if not offer then
		return
	end
	Rematch.Offers[player] = nil
	if player.Parent then
		player:SetAttribute("IntroRematch", nil)
	end
	local foe = offer.Foe
	local theirs = Rematch.Offers[foe]
	if theirs and theirs.Foe == player then
		Rematch.Offers[foe] = nil
		if foe.Parent then
			foe:SetAttribute("IntroRematch", nil)
			if tell and theirs.Wants then
				Remotes.Notify:FireClient(foe, tell)
			end
		end
	end
end
function Rematch.offer(a: Player, b: Player)
	local untilAt = os.clock() + Duels.RematchFor
	Rematch.Offers[a] = { Foe = b, Until = untilAt }
	Rematch.Offers[b] = { Foe = a, Until = untilAt }
	a:SetAttribute("IntroRematch", b.DisplayName)
	b:SetAttribute("IntroRematch", a.DisplayName)
	task.delay(Duels.RematchFor, function()
		local offer = Rematch.Offers[a]
		if offer and offer.Until == untilAt then
			Rematch.clear(a)
		end
	end)
end
function Duels.rematchOf(player: Player): Player?
	local offer = Rematch.Offers[player]
	return offer and offer.Foe or nil
end

-- The match is over: `winner` is the winning team (nil: a draw).
function finish(match, winner: number?, reason: string)
	if match.State == "Done" then
		return
	end
	match.State = "Done"
	local ratings = { teamRating(match.Teams[1]), teamRating(match.Teams[2]) }
	local leagueChange: { [Player]: any } = {} -- (each ranked 1v1 fighter's league move)
	local rewards = match.Rules.Rewards
	local names = {}
	for t, team in match.Teams do
		local list = {}
		for _, member in team do
			table.insert(list, member.DisplayName)
		end
		names[t] = table.concat(list, " & ")
	end
	-- Each side's level (its players' average): a win's XP goes by the
	-- other side's against yours (Shared.Levelling).
	local levels = {}
	for t, team in match.Teams do
		local sum = 0
		for _, member in team do
			sum += Progress.levelOf(member)
		end
		levels[t] = if #team > 0 then sum / #team else 1
	end
	-- (two new miners' first fight: a REMATCH on offer, before the cards)
	do
		local a, b = match.Teams[1] and match.Teams[1][1], match.Teams[2] and match.Teams[2][1]
		if
			match.Intro
			and winner ~= nil
			and #match.Teams[1] == 1
			and #match.Teams[2] == 1
			and a
			and b
			and a.Parent
			and b.Parent
			and not match.Called[a]
			and not match.Called[b]
		then
			Rematch.offer(a, b)
		end
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
					-- Called from the lobby (Shared.AutoQueue): a loss costs
					-- no rating.
					if match.Called[member] and after < before then
						after = before
					end
					record.Rating = after
					-- Its league moves with it, and the season's track pays
					-- the first time each tier is reached (Shared.Leagues).
					if #match.Teams[1] == 1 and #match.Teams[2] == 1 then
						pcall(function() -- (never in the way of finishing the match)
						local held = record :: any
						local saved, change = Leagues.update(held.League, after, Season.Name, before)
						held.League = saved
						local paid = {}
						for _, step in change.Track do
							local given = ArenaStreaks.leagueReward(member, Leagues.info(step).Label, Leagues.Track[step])
							if given then
								table.insert(paid, given)
							end
						end
						change.Paid = paid
						leagueChange[member] = change
						end)
					end
				end
				record.Wins += if won then 1 else 0
				if won and #match.Teams[1] == 1 and #match.Teams[2] == 1 then
					(record :: any).Solo = ((record :: any).Solo or 0) + 1
				end
				record.Losses += if won then 0 else 1
				record.Streak = if won then record.Streak + 1 else 0
			end
			-- Ranked 1v1 win streaks: Arena Caches at 10, 20 ... (ArenaStreaks).
			local rankedStreak = nil
			local solo = #match.Teams[1] == 1 and #match.Teams[2] == 1
			local foe = if solo then match.Teams[if t == 1 then 2 else 1][1] else nil
			local rankedBefore = record and (record :: any).RankedStreak or 0
			if record and winner and match.Ranked and solo then
				rankedStreak = ArenaStreaks.onRankedResult(member, won, foe and foe.UserId)
			end
			-- The arena tournament (Shared.SwingRestore): a queued 1v1's run of
			-- wins restores the pick's swings (the 1st, 5th and 10th); ten in a
			-- row wins it. Ranked runs on its streak, Casual on one of its own.
			local tournament = nil
			if record and winner and solo and match.Rules.Kind ~= "Challenge" then
				local streak, counted
				if match.Ranked then
					streak = rankedStreak or 0
					counted = won and streak > rankedBefore
				else
					streak, counted = SwingRestore.casual(record, won, foe and foe.UserId)
				end
				local share = if counted then SwingRestore.streakShare(streak) else 0
				local nextAt, nextShare = SwingRestore.next(streak)
				tournament = {
					Streak = streak,
					Win = if won then SwingRestore.round(streak) else 0,
					Of = SwingRestore.Tournament,
					Counted = counted,
					Champion = counted and SwingRestore.won(streak),
					Share = share,
					Swings = if share > 0 then Restores.give(member, share) else 0,
					NextAt = SwingRestore.round(nextAt),
					NextShare = nextShare,
				}
			end
			if record then
				-- Every finished duel counts toward the lobby's unlocks.
				(record :: any).Played = ((record :: any).Played or 0) + 1
			end
			-- Rewards (Shared.RewardRoll): every 1v1 played makes your rolls
			-- rarer, and a queued 1v1 won (Ranked or Casual) pays a win
			-- reward: two pieces, keep one, the other to the Market.
			-- A new miner's intro rounds (Server.IntroRoundsServer): a 1v1 won
			-- (any mode, the first fight too) pays the next piece of their set
			-- in place of the usual win reward; a loss eases that round.
			local introRound = nil
			local IntroRoundsServer = Duels.IntroRounds
			if IntroRoundsServer and solo and winner ~= nil and member.Parent and match.Rules.Kind ~= "Challenge" then
				if won then
					introRound = IntroRoundsServer.won(member)
				elseif member:GetAttribute("IntroRounds") or match.Intro then
					IntroRoundsServer.lost(member)
				end
			end
			local winReward = nil
			if record and solo and not match.Intro then
				RewardRoll.count(record)
				if won and match.Rules.Kind ~= "Challenge" and member.Parent and not introRound then
					winReward = ArenaStreaks.winReward(member, foe and foe.UserId)
				end
			end
			local bonus = if winner ~= nil and not match.Intro then AutoQueue.bonus(match.Called[member], won) else 0
			local coins = (if winner == nil then 0 elseif won then rewards.Win else rewards.Loss) + bonus
			if member.Parent then
                if #match.Teams[1] == 1 and #match.Teams[2] == 1 then
                    PlayerData.training(member, "PvPPlayed")
                    if won then PlayerData.training(member, "PvPWin") end
                end
				if coins > 0 then
					PlayerData.addCoins(member, coins, "Duel")
				end
				Analytics.event(
					member,
					"DuelFinished",
					1,
					if match.Intro then "Intro" elseif match.Ranked then "Ranked" else match.Rules.Kind or "Casual",
					if winner == nil then "Draw" elseif won then "Win" else "Loss",
					#match.Teams[1] .. "v" .. #match.Teams[2]
				)
				local result = if won then "DuelWin" else "DuelPlay"
				Progress.won(member, result, levels[if t == 1 then 2 else 1], result, foe)
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
					Bonus = bonus,
					JoinBonus = if match.Called[member] then match.JoinBonus else 0,
					Called = match.Called[member] == true,
					Intro = match.Intro == true,
					Opponents = names[if t == 1 then 2 else 1],
					Rules = { Name = match.Rules.Name, Stats = match.Rules.Stats },
					Streak = rankedStreak,
					-- the league move (Shared.Leagues: Before, After, Promoted,
					-- Demoted, Shielded, NewLeague, Safe, Paid) and the ladder
					League = leagueChange[member],
					Ladder = if leagueChange[member] then (function()
						local ok, ladder = pcall(Duels.ladder, member, before)
						return if ok then ladder else nil
					end)() else nil,
					Tournament = tournament,
					WinReward = winReward ~= nil,
					Plays = if record then RewardRoll.plays(record) else nil,
					Rounds = if match.Rounds
						then { Mine = match.Rounds.Wins[t], Theirs = match.Rounds.Wins[if t == 1 then 2 else 1] }
						else nil,
				})
				-- A first fight is over: the hints come down (Funnel logs the
				-- step on this), and the Outpost is next.
				if match.FirstFighters[member] then
					member:SetAttribute("FirstFight", nil)
					-- (An account from before the intro rounds: the floor arrows
					-- walk them through the Outpost: a mech, a few rocks, out to
					-- the outskirts, Client IntroGuide. A new miner's next step
					-- is their round's card, in the Arena: never the Outpost's.)
					if not IntroRounds.eligible(PlayerData.get(member)) then
						member:SetAttribute("IntroGuide", true)
						Remotes.Notify:FireClient(
							member,
							if won
								then string.format("You beat %s! Welcome to the Saga Outpost.", names[if t == 1 then 2 else 1])
								else "A hard first fight. Welcome to the Saga Outpost: gear up and come back."
						)
					end
				end
			end
		end
	end
	-- Everyone hears how it went (their chat feed).
	if winner then
		Remotes.Social:FireAllClients(
			"Feed",
			string.format(
				"⚔ %s defeated %s in a %s duel (%s).",
				names[winner],
				names[if winner == 1 then 2 else 1],
				if match.Ranked then "ranked" else "friendly",
				match.Rules.Name
			)
		)
	end
	task.delay(Matchmaking.EndPause, release, match)
end

-- A shield (no damage) on a fighter until the next fight starts.
local function shield(match, member: Player)
	local character = member.Character
	if not character then
		return
	end
	if match.Shields[member] then
		match.Shields[member]:Destroy()
	end
	local field = Instance.new("ForceField")
	field.Visible = false
	field.Parent = character
	match.Shields[member] = field
end

local function dropShields(match)
	for member, field in match.Shields do
		field:Destroy()
		match.Shields[member] = nil
	end
end

-- Where a fighter stands in a ring of Arena Row (`center`: its floor's
-- middle): the two sides StageApart studs apart across it, a team's members
-- side by side, facing the other side. Pure: (spot, the point it faces).
Duels.StageApart = 24
function Duels.stageSpot(center: Vector3, team: number, index: number, count: number): (Vector3, Vector3)
	local side = if team == 1 then -1 else 1
	local across = (index - (count + 1) / 2) * 5
	local spot = center + Vector3.new(side * Duels.StageApart / 2, 3, across)
	return spot, center + Vector3.new(0, 3, across)
end

-- Puts every fighter on their lane spot (or their spot in the match's ring
-- of Arena Row), at full health and shielded.
local function stage(match)
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local floor = landmarks and landmarks:GetAttribute("ArenaFloor")
	for t, team in match.Teams do
		for index, member in team do
			local humanoid, root = alive(member)
			if humanoid and root and match.Center then
				local at, facing = Duels.stageSpot(match.Center, t, index, #team)
				member.Character:PivotTo(CFrame.lookAt(at, facing))
				member.Character:SetAttribute("RoundKO", nil)
				humanoid.Health = humanoid.MaxHealth
				shield(match, member)
				continue
			end
			local spot, centre = Matchmaking.lane(match.Slot, t, index, #team)
			if humanoid and root and typeof(floor) == "Vector3" then
				local at = floor + spot + Vector3.new(0, 3, 0)
				member.Character:PivotTo(CFrame.lookAt(at, floor + centre + Vector3.new(0, 3, 0)))
				member.Character:SetAttribute("RoundKO", nil) -- (blown apart last round: back in one piece)
				humanoid.Health = humanoid.MaxHealth
				shield(match, member)
			end
		end
	end
end

-- The elements each side carries (gems in gear and on the Surge Array).
local function elementsOf(team): { string }
	local seen, list = {}, {}
	for _, member in team do
		local character = PlayerData.character(member)
		for _, element in if character then GearPresets.elements(character) else {} do
			if not seen[element] then
				seen[element] = true
				table.insert(list, element)
			end
		end
	end
	table.sort(list)
	return list
end

-- `rules`: the PvP rule it plays by (Shared.PvPRules.profile). `extra`
-- (Shared.AutoQueue): Called = { [player] = true } for fighters pulled from
-- the lobby; Intro for a first fight (its new players get the hints).
local function startMatch(mode: string, teams, rules, extra): (boolean, string?)
	extra = extra or {}
	local ranked = rules.Rated
	for _, team in teams do
		for _, member in team do
			local reason = busy(member)
			if reason then
				return false, member.DisplayName .. " " .. reason .. "."
			end
		end
	end
	-- In the Outpost: a ring of Arena Row (the Grand Arena first), everyone
	-- watching; the shared Arena's lanes only when every ring's taken.
	local everyone = {}
	for _, team in teams do
		for _, member in team do
			table.insert(everyone, member)
		end
	end
	local center = PrivateArenas.claimStage(everyone, Duels.Stage)
	local slot = if center then nil else freeSlot()
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local floor = landmarks and landmarks:GetAttribute("ArenaFloor")
	if not center and (not slot or typeof(floor) ~= "Vector3") then
		return false, "The Arena is full. Try again in a moment."
	end
	nextId += 1
	local now = os.clock()
	local count = 0
	for _, team in teams do
		count += #team
	end
	local countdown = math.max(Matchmaking.Countdown, ArenaDrop.duration(count))
	local rounds = Matchmaking.playsRounds(mode, rules.Kind)
	local limit = if rounds then Matchmaking.Rounds.Time else Matchmaking.TimeLimit
	local entrants, audience = {}, {}
	local match = {
		Id = "D" .. nextId,
		Mode = mode,
		Ranked = ranked,
		Rules = rules,
		Teams = teams,
		Out = {},
		Slot = slot,
		Center = center, -- (its ring of Arena Row, if it has one)
		State = "Countdown",
		StartsAt = now + countdown,
		Ends = now + countdown + limit,
		Connections = {},
		Shields = {},
		Called = extra.Called or {},
		JoinBonus = extra.JoinBonus or 0,
		Intro = extra.Intro == true,
		FirstFighters = {},
		-- Rounds (1v1 Ranked): wins per team, rounds played, the pivot's
		-- picks and locks, and what each side was scouted carrying.
		Rounds = if rounds
			then { Wins = { 0, 0 }, Played = 0, Picks = {}, Locked = {}, PivotEnds = 0, Threats = {} }
			else nil,
	}
	matches[match.Id] = match
	local startsAt = serverNow() + countdown
	local info = teamsInfo(match)
	for t, team in teams do
		for _, member in team do
			dequeue(member)
			matchOf[member] = match
			ArenaDrop.prepare(member)
			CombatServer.reset(member)
			-- The rule its stats follow (CombatServer's kit, Equipment's stats)
			-- before the health is topped up below.
			CounterServer.newRound(member)
			member:SetAttribute("MatchStats", rules.Stats)
			member:SetAttribute("MatchRarityCap", rules.RarityCap)
			member:SetAttribute("MatchId", match.Id)
			member:SetAttribute("MatchTeam", t)
			member:SetAttribute("PvPEnabled", true)
			member:SetAttribute("CombatSession", "Duel")
			if match.Intro then
				local record = Duels.record(member)
				if record and ((record :: any).Played or 0) == 0 then
					-- Their first fight: the controls' hints (Shared.FastStart).
					match.FirstFighters[member] = true
					member:SetAttribute("FirstFight", true)
				end
			end
			local humanoid = alive(member)
			if humanoid then
				table.insert(entrants, member.Character)
				table.insert(audience, member)
				table.insert(
					match.Connections,
					humanoid.Died:Connect(function()
						knockOut(match, member, "Defeated")
					end)
				)
			end
		end
	end
	stage(match)
	for t, team in teams do
		for _, member in team do
			Remotes.Social:FireClient(member, "Match", {
				Id = match.Id,
				Mode = mode,
				Ranked = ranked,
				Rules = { Name = rules.Name, Stats = rules.Stats, Label = PvPRules.label(rules) },
				Rounds = if rounds then { ToWin = Matchmaking.Rounds.ToWin, Max = Matchmaking.Rounds.Max } else nil,
				StartsAt = startsAt,
				Ends = startsAt + limit,
				Team = t,
				Teams = info,
				Called = match.Called[member] == true,
				Bonus = if match.Called[member] then (if match.Intro then match.JoinBonus else AutoQueue.FillBonus) else 0,
				BonusUpfront = match.Intro,
				Intro = match.Intro,
			})
		end
	end
	ArenaDrop.begin(entrants, audience)
	return true, nil
end

-- Rounds (1v1 Ranked) ------------------------------------------------------------

local function other(t: number): number
	return if t == 1 then 2 else 1
end

local function tell(match, payload: (number) -> any)
	for t, team in match.Teams do
		for _, member in team do
			if member.Parent then
				Remotes.Social:FireClient(member, "Round", payload(t))
			end
		end
	end
end

-- May team `t` counter between rounds? The round's loser, or both sides
-- after a drawn round (gear: Shared.CounterGear; miners: MinerRoster).
local function counters(winner: number?, t: number): boolean
	return winner == nil or winner ~= t
end

-- A round is over: `winner` took it (nil: a drawn round). The match ends
-- when a side has enough, else the pivot window opens.
local function endRound(match, winner: number?, reason: string)
	local r = match.Rounds
	if not r or (match.State ~= "Fight" and match.State ~= "RoundOver") then
		return
	end
	r.Played += 1
	if winner then
		r.Wins[winner] += 1
	end
	-- Scouting: what each side fought with in the round just played.
	local scout = { elementsOf(match.Teams[1]), elementsOf(match.Teams[2]) }
	local result = Matchmaking.roundsOver(r.Wins, r.Played)
	if result then
		finish(match, if result == "Draw" then nil else result :: number, reason)
		return
	end
	match.State = "Pivot"
	r.Picks, r.Locked, r.Threats = {}, {}, {}
	r.LastWinner = winner
	-- What hurt each fighter this round, and the counter the round's loser
	-- (both, after a draw) may wear into the next (Systems/CounterServer).
	local offers, picking = {}, MinerRoster.Enabled
	for t, team in match.Teams do
		for _, member in team do
			r.Threats[member] = CounterServer.threat(member, match.Teams[other(t)])
			if counters(winner, t) then
				offers[member] = CounterServer.offer(member, r.Threats[member])
				picking = picking or offers[member].Changes > 0
			end
		end
	end
	-- (Nothing anyone can change: a shorter break.)
	local pause = if picking then Matchmaking.Rounds.Pivot else Matchmaking.Rounds.Break
	r.PivotEnds = os.clock() + pause
	local ends = serverNow() + pause
	for _, team in match.Teams do
		for _, member in team do
			shield(match, member)
			CombatServer.reset(member)
		end
	end
	for t, team in match.Teams do
		for _, member in team do
			local offer = offers[member]
			if not member.Parent then
				continue
			end
			Remotes.Social:FireClient(member, "Round", {
				Phase = "Pivot",
				Round = r.Played,
				Winner = if winner == nil then "Draw" elseif winner == t then "You" else "Them",
				CanSwap = MinerRoster.canCounter(winner, t),
				CanCounter = offer ~= nil and offer.Changes > 0,
				Threat = r.Threats[member],
				Counter = offer,
				Reason = reason,
				Wins = { Mine = r.Wins[t], Theirs = r.Wins[other(t)] },
				Team = t,
				Ends = ends,
				Scout = scout[other(t)],
			})
		end
	end
end

-- Both locked (or the window closed): wear the picks, show them, count down.
local function reveal(match)
	local r = match.Rounds
	if not r or match.State ~= "Pivot" then
		return
	end
	local picks = {}
	for t, team in match.Teams do
		picks[t] = {}
		for _, member in team do
			local chosen = r.Picks[member]
			local countered = nil
			if type(chosen) == "number" and MinerRoster.canCounter(r.LastWinner, t) then
				PlayerData.selectMiner(member, chosen)
			elseif chosen == "Counter" and counters(r.LastWinner, t) then
				local worn = CounterServer.wear(member, r.Threats[member])
				if worn.Pieces + worn.Gems > 0 then
					countered = worn.Element
				end
			end
			CounterServer.newRound(member)
			local profile = PlayerData.get(member)
			local current = profile and profile.Miners and profile.Miners.Active or 1

			table.insert(picks[t], {
				Name = member.DisplayName,
				Preset = if MinerRoster.Enabled then "Miner " .. current else nil,
				Countered = countered,
				Locked = r.Locked[member] == true,
			})
		end
	end
	-- Every round starts like the first: back in the pods while the picks
	-- show, then the drop onto the lanes (ArenaDrop), the countdown long
	-- enough for it.
	local entrants, audience = {}, {}
	for _, team in match.Teams do
		for _, member in team do
			CombatServer.reset(member)
			if alive(member) then
				ArenaDrop.prepare(member)
				table.insert(entrants, member.Character)
				table.insert(audience, member)
			end
		end
	end
	local countdown = Matchmaking.Rounds.Reveal + math.max(Matchmaking.Countdown, ArenaDrop.duration(#entrants))
	local now = os.clock()
	match.State = "Countdown"
	match.StartsAt = now + countdown
	match.Ends = match.StartsAt + Matchmaking.Rounds.Time
	stage(match)
	local round = r.Played
	task.delay(Matchmaking.Rounds.Reveal, function()
		if match.State == "Countdown" and r.Played == round then
			ArenaDrop.begin(entrants, audience)
		else
			-- Over before the drop (a forfeit, a leave): out of the pods.
			for _, model in entrants do
				ArenaDrop.cancel(model)
			end
		end
	end)
	local startsAt = serverNow() + countdown
	tell(match, function(t)
		return {
			Phase = "Reveal",
			Round = r.Played + 1,
			Wins = { Mine = r.Wins[t], Theirs = r.Wins[other(t)] },
			Team = t,
			StartsAt = startsAt,
			Ends = startsAt + Matchmaking.Rounds.Time,
			Picks = { Mine = picks[t], Theirs = picks[other(t)] },
		}
	end)
end

local function pivot(player: Player, index: any, hold: any)
	local match = matchOf[player]
	local r = match and match.Rounds
	if not r or match.State ~= "Pivot" then
		return reply(false, "You can only change your gear between rounds.")
	end
	if r.Locked[player] then
		return reply(false, "Your pick is locked in.")
	end
	local team = player:GetAttribute("MatchTeam")
	if index == "Counter" then
		-- The armor answer to what hurt you (the round's loser only).
		if not counters(r.LastWinner, team) then
			return reply(false, "The round winner keeps their gear. The loser may counter.")
		end
		r.Picks[player] = "Counter"
	elseif index == nil or index == "Keep" then
		r.Picks[player] = nil
	else
		local profile = PlayerData.get(player)
		local roster = profile and profile.Miners
		local chosen = index
		if roster and chosen ~= roster.Active and not MinerRoster.Enabled then
			return reply(false, "You play one miner for now.")
		end
		if not MinerRoster.valid(chosen) or not roster or not roster.Slots[chosen] then
			return reply(false, "Choose one of your three miners.")
		end
		if chosen ~= roster.Active and not MinerRoster.canCounter(r.LastWinner, team) then
			return reply(false, "The round winner keeps their miner. The loser may counter-pick.")
		end
		r.Picks[player] = chosen
	end
	if hold == true then
		return reply(true, "")
	end

	r.Locked[player] = true
	tell(match, function()
		return { Phase = "Locked", Team = team }
	end)
	for _, side in match.Teams do
		for _, member in side do
			if not r.Locked[member] and not match.Out[member] then
				return reply(true, "Locked in. Waiting for your opponent…")
			end
		end
	end
	reveal(match)
	return reply(true, "Both locked in.")
end

-- A lethal blow in a round match: the fighter is downed (1 health) and the
-- round goes to the other side. Between rounds, nothing lands.
local function lethal(player: Player, humanoid: Humanoid): boolean
	local match = matchOf[player]
	if not match or match.State == "Done" then
		return false
	end
	-- A first fight (the intro's, two new miners): nobody dies in it. The
	-- loser's knocked out where they stand (blown apart, as in a Ranked
	-- round) and the fight's over; no respawn back in the lobby, no
	-- loading in the middle of their first minutes.
	if match.Intro and not match.Rounds then
		if match.State == "Fight" then
			humanoid.Health = 1
			local character = player.Character
			if character then
				character:SetAttribute("RoundKO", true)
			end
			task.defer(knockOut, match, player, "Defeated")
		end
		return true
	end
	if not match.Rounds then
		return false
	end
	if match.State == "Fight" then
		humanoid.Health = 1
		-- They go down as anyone killed does: the body blows apart (client
		-- ElementalDeath, by the element that finished them) and is gone
		-- until the next round puts them back on their lane (stage).
		local character = player.Character
		if character then
			character:SetAttribute("RoundKO", true)
		end
		match.State = "RoundOver"
		local team = player:GetAttribute("MatchTeam")
		local winner = if team == 1 then 2 elseif team == 2 then 1 else nil
		task.defer(endRound, match, winner, "Defeated")
	end
	return true
end

-- Queue ----------------------------------------------------------------------

-- When each player first reached the lobby this visit (Shared.AutoQueue:
-- a moment after logging in before they're asked anything), and the
-- fill-in cards taken down when they started searching themselves: entry
-- id -> until when its bonus carries over to a match with that queue.
local arrived: { [Player]: number } = {}
local carried: { [Player]: { [string]: number } } = {}

local function enqueue(mode: string, group, size: number)
	for _, member in group do
		dequeue(member)
	end
	-- One question at a time: a fill-in card open to someone who now
	-- searches comes down; its bonus waits in case that queue's who they
	-- meet.
	local now = os.clock()
	for _, other in queue do
		for _, member in group do
			local expiry = other.Offers and other.Offers[member]
			if expiry then
				other.Offers[member] = nil
				if expiry > now then
					carried[member] = carried[member] or {}
					carried[member][other.Id] = now + AutoQueue.CarryFor
				end
				if member.Parent then
					Remotes.Social:FireClient(member, "FillInOver", other.Id)
				end
			end
		end
	end
	nextEntry += 1
	local entry = {
		Id = "Q" .. nextEntry,
		Mode = mode,
		Players = group,
		Since = os.clock(),
		SinceServer = serverNow(),
		Rating = teamRating(group),
		Size = size,
		Asked = {},
	}
	table.insert(queue, entry)
	pushQueue(entry)
	for _, other in queue do
		if other ~= entry and other.Mode == mode then
			pushQueue(other) -- (the waiting count changed)
		end
	end
	return entry
end

local function entryById(id: any)
	for _, entry in queue do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- Ready checks (MATCH READY) ---------------------------------------------------

local function checkPlayers(check): { Player }
	local list = {}
	for _, side in check.Sides do
		for _, member in side.Players do
			table.insert(list, member)
		end
	end
	return list
end

local function readyCount(check): (number, number)
	local yes, all = 0, 0
	for _, member in checkPlayers(check) do
		all += 1
		if check.Accepted[member] then
			yes += 1
		end
	end
	return yes, all
end

local function checkOf(player: Player)
	for _, check in readyChecks do
		if table.find(checkPlayers(check), player) then
			return check
		end
	end
	return nil
end

-- Lanes not taken by a match or held for a ready check.
local function lanesFree(): number
	local taken = 0
	for _, match in matches do
		if match.Slot then
			taken += 1
		end
	end
	for _ in readyChecks do
		taken += 1
	end
	return Matchmaking.Lanes - taken
end

-- Asks everyone on `sides` to JOIN; `start()` starts the match once they
-- all have. `accepted`: who's said yes already (a called fill-in);
-- `bonus`: what a win pays on top, by player (said on the card).
local function openCheck(
	mode: string,
	sides,
	start: () -> (boolean, string?),
	accepted: { Player }?,
	bonus: { [Player]: number }?
)
	nextReady += 1
	local spec = Matchmaking.Modes[mode]
	local check = {
		Id = "R" .. nextReady,
		Mode = mode,
		Sides = sides,
		Accepted = {},
		Ends = os.clock() + Matchmaking.ReadySeconds,
		Start = start,
	}
	for _, member in accepted or {} do
		check.Accepted[member] = true
	end
	readyChecks[check.Id] = check
	for _, side in sides do
		if side.Entry then
			side.Entry.Check = check.Id
		end
	end
	local endsAt = serverNow() + Matchmaking.ReadySeconds
	local yes, all = readyCount(check)
	for s, side in sides do
		local foes = {}
		for o, other in sides do
			if o ~= s then
				for _, foe in other.Players do
					local record = Duels.record(foe)
					table.insert(foes, { Name = foe.DisplayName, Rating = if record then record.Rating else Matchmaking.StartRating })
				end
			end
		end
		for _, member in side.Players do
			Remotes.Social:FireClient(member, "MatchReady", {
				Id = check.Id,
				Mode = mode,
				Name = if spec then spec.Name else mode,
				Ranked = spec ~= nil and spec.Kind == "Ranked",
				Seconds = Matchmaking.ReadySeconds,
				Ends = endsAt,
				Foes = foes,
				Accepted = check.Accepted[member] == true,
				Ready = yes,
				Of = all,
				Bonus = bonus and bonus[member] or 0,
			})
		end
	end
	return check
end

local function closeCheck(check, reason: string)
	readyChecks[check.Id] = nil
	for _, side in check.Sides do
		if side.Entry then
			side.Entry.Check = nil
		end
	end
	for _, member in checkPlayers(check) do
		if member.Parent then
			Remotes.Social:FireClient(
				member,
				"MatchReadyOver",
				{ Id = check.Id, Reason = reason, Searching = entryOf(member) ~= nil }
			)
		end
	end
end

-- No match: `out` didn't join (declined, ran out of time, or left). Their
-- side leaves the queue; the rest keep searching where they were (a called
-- fill-in just stays in the lobby).
local function failCheck(check, out: { [Player]: boolean }, reason: string)
	for _, side in check.Sides do
		local failed, who = false, nil
		for _, member in side.Players do
			if out[member] then
				failed, who = true, who or member
			end
		end
		if failed then
			if side.Entry and entryById(side.Entry.Id) == side.Entry then
				dequeue(side.Players[1])
			end
			if reason ~= "Gone" then
				for _, member in side.Players do
					Remotes.Notify:FireClient(
						member,
						if member ~= who
							then string.format("%s didn't join, so your party left the queue.", who.DisplayName)
							elseif reason == "Expired" then "You didn't join in time: you left the queue."
							else "Match declined: you left the queue."
					)
				end
			end
		else
			for _, member in side.Players do
				if member.Parent then
					Remotes.Notify:FireClient(
						member,
						if side.Entry then "Your opponent didn't join: back to searching." else "They didn't join after all."
					)
				end
			end
		end
	end
	closeCheck(check, reason)
end

local function readyRespond(player: Player, id: any, accept: any)
	local check = readyChecks[id]
	if not check or not table.find(checkPlayers(check), player) then
		return reply(false, "That match is gone.")
	end
	if accept ~= true then
		failCheck(check, { [player] = true }, "Declined")
		return reply(true, "Declined: you left the queue.")
	end
	check.Accepted[player] = true
	local yes, all = readyCount(check)
	if yes < all then
		for _, member in checkPlayers(check) do
			Remotes.Social:FireClient(member, "MatchReadyState", { Id = check.Id, Ready = yes, Of = all })
		end
		return reply(true, "Waiting for the others to join…")
	end
	-- Everyone's in.
	closeCheck(check, "Started")
	local ok, problem = check.Start()
	if not ok then
		-- Someone became busy: they leave the queue; the rest keep searching.
		for _, side in check.Sides do
			for _, member in side.Players do
				if busy(member) and entryOf(member) then
					dequeue(member, problem)
					Remotes.Notify:FireClient(member, "Left the duel queue: " .. (problem or ""))
				elseif member.Parent then
					Remotes.Notify:FireClient(member, "The match couldn't start: " .. (problem or "The Arena is full. Try again in a moment."))
				end
			end
		end
		return reply(false, problem or "The duel couldn't start.")
	end
	return reply(true, "Match found!")
end

-- Each step: a check with someone gone (left the queue, the game, or busy
-- now) is off; one past its time leaves out whoever didn't join.
local function stepChecks(now: number)
	for id, check in table.clone(readyChecks) do
		if readyChecks[id] then
			local out, gone = {}, false
			for _, side in check.Sides do
				local left = side.Entry ~= nil and entryById(side.Entry.Id) ~= side.Entry
				for _, member in side.Players do
					if left or not member.Parent or busy(member) then
						out[member], gone = true, true
					end
				end
			end
			if gone then
				failCheck(check, out, "Gone")
			elseif now >= check.Ends then
				for _, member in checkPlayers(check) do
					if not check.Accepted[member] then
						out[member] = true
					end
				end
				failCheck(check, out, "Expired")
			end
		end
	end
end

-- A new player's first fight (Shared.AutoQueue): the intro queue.
local function introJoin(player: Player)
	local record = Duels.record(player)
	if not record then
		return reply(false, "Still loading…")
	end
	if ((record :: any).Played or 0) > 0 then
		return reply(false, "You've fought before: pick a mode from the PLAY menu.")
	end
	local reason = busy(player)
	if reason then
		return reply(false, subject(player, player, reason))
	end
	-- Alone, or no other new miner here (one just in, still loading,
	-- counts): the sparring rival at once (no search, no waiting).
	local another = false
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local theirs = Duels.record(other)
			if not theirs or ((theirs :: any).Played or 0) == 0 then
				another = true
			end
		end
	end
	if not AutoQueue.introSearches(#Players:GetPlayers()) or not another then
		local result = ArenaSessions.enterTraining(player)
		if result and result.Ok == false then
			return result
		end
		return reply(true, "Your sparring partner is ready.", { Bot = true })
	end
	enqueue(AutoQueue.IntroMode, { player }, 1)
	return reply(true, "Finding your first opponent…")
end

-- A new miner with intro rounds still to win: kept out of real players'
-- matches (no auto search, no fill-in calls) till their set's done; they
-- can still pick a mode from the PLAY menu themselves.
Duels.IntroMessage = "Finish your intro rounds first."
local function inIntro(player: Player): boolean
	return IntroRounds.eligible(PlayerData.get(player))
end
-- After the rounds, the first dungeon and then the lobby's intro (the first
-- rock, the critters: Server.IntroRoundsServer's finale) still to do: no
-- auto queue and no fill-in calls till it's done; then the search starts
-- by itself (Duels.AfterFinale seconds on).
Duels.FinaleMessage = "Finish your first mine and the critters first."
Duels.AfterFinale = 4
local function inFinale(player: Player): boolean
	local profile = PlayerData.get(player) :: any
	return profile ~= nil and (profile.IntroFinale == "Dungeon" or profile.IntroFinale == "Mines")
end

-- Auto queue: everyone with it on (the default) searches ranked 1v1 while
-- they're in the lobby, without being asked (arriving there, and back from
-- a dungeon or the Rift); CANCEL on the SEARCHING card leaves it. Only a
-- fill-in, pulled into someone else's match, is asked first (FillIn).
local function autoReturn(player: Player)
	if entryOf(player) then return reply(true, "Already searching.") end
	if inIntro(player) then return reply(false, Duels.IntroMessage) end
	if inFinale(player) then return reply(false, Duels.FinaleMessage) end
	local ready = AutoQueue.ready(function(name) return player:GetAttribute(name) end, false)
	if not ready or busy(player) then return reply(false, "Return to the lobby first.") end
	local record = Duels.record(player)
	if not record or not AutoQueue.setting(record) then
		return reply(false, "Auto queue is off.")
	end
	local entry = enqueue("1v1", { player }, 1)
	-- (Just logged in: searching, but nothing asked for a moment.)
	entry.Hold = AutoQueue.holdUntil(arrived[player], os.clock())
	return reply(true, "Searching ranked 1v1 while you mine. Cancel anytime.")
end

-- Auto queue (Shared.AutoQueue) ------------------------------------------------

-- Free lobby players with invitations enabled. Never automatically matched.
local function onCall(entry)
	local manual = {}
	for _, other in Players:GetPlayers() do
		if not table.find(entry.Players, other) and not busy(other) and not inIntro(other) and not inFinale(other) and AutoQueue.settled(arrived[other], os.clock()) then
			local ok = AutoQueue.ready(function(name)
				return other:GetAttribute(name)
			end, entryOf(other) ~= nil)
			local record = ok and Duels.record(other)
			if record and AutoQueue.setting(record) then
				local candidate = { Player = other, Rating = record.Rating }
				table.insert(manual, candidate)
			end
		end
	end
	return manual
end

local function rulesFor(mode: string)
	local spec = Matchmaking.Modes[mode]
	return PvPRules.profile(spec and spec.Kind or "Ranked")
end

-- REMATCH (after two new miners' first fight): both asking, they fight
-- again (once the last one's let them go: a few tries).
function Rematch.request(player: Player)
	local offer = Rematch.Offers[player]
	local foe = offer and offer.Foe
	if not offer or os.clock() > offer.Until or not foe.Parent then
		Rematch.clear(player)
		return reply(false, "The rematch has passed.")
	end
	local theirs = Rematch.Offers[foe]
	if not theirs or theirs.Foe ~= player then
		Rematch.clear(player)
		return reply(false, foe.DisplayName .. " went on with their intro.")
	end
	offer.Wants = true
	if not theirs.Wants then
		Remotes.Notify:FireClient(foe, player.DisplayName .. " wants a rematch! Press REMATCH to fight again.")
		return reply(true, "Waiting for " .. foe.DisplayName .. "…", { Waiting = true })
	end
	Rematch.clear(player)
	-- (the last fight lets them go, the loser back on their feet: a few
	-- tries, half a second apart)
	local WAIT = { ["is already in a duel"] = true, ["isn't ready"] = true, ["is still loading"] = true }
	local function try(n: number)
		if not (player.Parent and foe.Parent) then
			return
		end
		local who = if busy(player) then player else foe
		local reason = busy(who)
		if not reason then
			dequeue(player)
			dequeue(foe)
			local ok, problem = startMatch(AutoQueue.IntroMode, { { foe }, { player } }, rulesFor(AutoQueue.IntroMode), { Intro = true })
			if not ok then
				for _, p in { player, foe } do
					Remotes.Notify:FireClient(p, problem or "The rematch couldn't start.")
				end
			end
		elseif WAIT[reason] and n < Duels.RematchTries then
			task.delay(0.5, try, n + 1)
		else
			for _, p in { player, foe } do
				Remotes.Notify:FireClient(p, "The rematch couldn't start: " .. subject(who, p, reason))
			end
		end
	end
	try(1)
	return reply(true, "Rematch!", { Started = true })
end


-- `called` steps into `entry`'s match from the lobby.
local function fillWith(entry, called: Player): (boolean, string?)
	local spec = Matchmaking.Modes[entry.Mode]
	local newcomer = spec and spec.Intro and Duels.record(entry.Players[1])
	local joinBonus = if newcomer and not newcomer.IntroHelpRewarded then AutoQueue.FillBonus else 0
	local ok, problem = startMatch(
		entry.Mode,
		{ table.clone(entry.Players), { called } },
		rulesFor(entry.Mode),
		{ Called = { [called] = true }, Intro = spec and spec.Intro, JoinBonus = joinBonus }
	)
	if ok then
		if newcomer then
			-- Once per newcomer's first fight, including leave/requeue attempts.
			newcomer.IntroHelpRewarded = true
			if joinBonus > 0 then PlayerData.addCoins(called, joinBonus, "QueueBonus") end
			PlayerData.sync(called)
			PlayerData.sync(entry.Players[1])
			Remotes.Notify:FireClient(called, string.format("Joined the first fight: +%d coins paid now. Thanks for helping!", joinBonus))
			return true, nil
		end
		Remotes.Notify:FireClient(
			called,
			string.format(
				if spec and spec.Kind == "Ranked"
					then "Called in: %s is waiting for a %s. Win it for +%d ◆ on top; a loss costs you no rating."
					else "Called in: %s is waiting for a %s. Win it for +%d ◆ on top.",
				entry.Players[1].DisplayName,
				spec and spec.Name or entry.Mode,
				AutoQueue.FillBonus
			)
		)
	end
	return ok, problem
end

-- A lone 1v1 invites the lobby; only DuelFill acceptance starts a fill-in.
-- An unanswered intro still falls back to the sparring rival on schedule.
local function fill(entry, now: number)
	if entry.Size ~= 1 or entry.Check or (entry.Hold and now < entry.Hold) then
		return
	end
	local spec = Matchmaking.Modes[entry.Mode]
	local intro = spec and spec.Intro
	local waited = now - entry.Since
	if intro and AutoQueue.introPhase(waited) == "Bot" then
		local player = entry.Players[1]
		dequeue(player)
		Remotes.Notify:FireClient(player, "No one else is around right now: a sparring partner steps in.")
		local result = ArenaSessions.enterTraining(player)
		if result and result.Ok == false then
			Remotes.Notify:FireClient(player, result.Message or "The Arena isn't ready yet.")
		end
		return
	end
	if waited < (if intro then AutoQueue.Intro.CallAfter else AutoQueue.CallAfter) or not freeSlot() then
		return
	end
	local manual = onCall(entry)
	entry.Offers = entry.Offers or {}
	for _, candidate in manual do
		local other = candidate.Player
		if not entry.Asked[other] then
			entry.Asked[other] = true
			local seconds = math.min(AutoQueue.AskSeconds, if intro then AutoQueue.Intro.BotAfter - waited else AutoQueue.AskSeconds)
			entry.Offers[other] = now + seconds
			local newcomer = intro and Duels.record(entry.Players[1])
			Remotes.Social:FireClient(other, "FillIn", {
				Id = entry.Id,
				Mode = entry.Mode,
				Name = spec and spec.Name or entry.Mode,
				Who = entry.Players[1].DisplayName,
				Rating = entry.Rating,
				Bonus = if newcomer and newcomer.IntroHelpRewarded then 0 else AutoQueue.FillBonus,
				BonusUpfront = intro == true,
				Seconds = seconds,
				Intro = intro == true,
			})
		end
	end
end

local function setAuto(player: Player, on: any)
	local record = Duels.record(player)
	if not record then
		return reply(false, "Still loading…")
	end
	(record :: any).AutoQueue = on ~= false
	publish(player)
	PlayerData.sync(player)
	-- Off: out of the queue (on, you're searching again next time you're
	-- back in the lobby).
	if on == false then
		local entry = entryOf(player)
		if entry and entry.Mode == "1v1" and entry.Size == 1 then
			dequeue(player)
		end
	end
	return reply(
		true,
		if on ~= false
			then "Auto queue on: you search for 1v1s while you mine. You're only asked when a match needs a fill-in."
			else "Auto queue off: no 1v1 search and no fill-in requests."
	)
end

local function fillRespond(player: Player, id: any, accept: any)
	local entry = entryById(id)
	if not entry then
		return reply(false, "That queue has been filled already.")
	end
	local expiry = entry.Offers and entry.Offers[player]
	if not expiry or expiry <= os.clock() then
		return reply(false, "That invitation has expired.")
	end
	entry.Offers[player] = nil -- one response; decline and retries cannot later accept it
	if accept ~= true then
		return reply(true, "Maybe next time.")
	end
	local reason = busy(player)
	if reason then
		return reply(false, subject(player, player, reason))
	end
	if table.find(entry.Players, player) then
		return reply(false, "That's your own queue.")
	end
	if inIntro(player) and not (Matchmaking.Modes[entry.Mode] and Matchmaking.Modes[entry.Mode].Intro) then
		return reply(false, Duels.IntroMessage)
	end
	local ready = AutoQueue.ready(function(name) return player:GetAttribute(name) end, entryOf(player) ~= nil)
	if not ready or not AutoQueue.setting(Duels.record(player)) then
		return reply(false, "Return to the lobby to accept a match invitation.")
	end
	if entry.Check or checkOf(player) then
		return reply(false, "Someone else is already stepping in.")
	end
	local spec = Matchmaking.Modes[entry.Mode]
	if not (spec and spec.Intro) then
		-- You've said yes; the one waiting is asked MATCH READY too.
		openCheck(entry.Mode, { { Players = entry.Players, Entry = entry }, { Players = { player } } }, function()
			return fillWith(entry, player)
		end, { player }, { [player] = AutoQueue.FillBonus })
		return reply(true, string.format("Waiting for %s to join…", entry.Players[1].DisplayName))
	end
	local ok, problem = fillWith(entry, player)
	if not ok then
		return reply(false, problem or "The duel couldn't start.")
	end
	return reply(true, "Stepping in!")
end

local function join(player: Player, mode: any)
	local spec = Matchmaking.Modes[mode]
	if not spec or spec.Intro then
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
	enqueue(mode, group, spec.Size)
	return reply(true, "Searching for a " .. spec.Name .. "…")
end

-- Pairs waiting entries of each mode while there's a lane free, and asks
-- them MATCH READY (a first fight starts at once).
function Duels.pairUp()
	for mode in Matchmaking.Modes do
		local entries = {}
		local now = os.clock()
		for _, entry in queue do
			if entry.Mode == mode and not entry.Check and not (entry.Hold and now < entry.Hold) then
				table.insert(entries, entry)
			end
		end
		local spec = Matchmaking.Modes[mode]
		local pairs
		if spec.Intro then
			-- First fights pair at once, whatever the ratings: everyone's new.
			table.sort(entries, function(x, y)
				return x.Since < y.Since
			end)
			pairs = {}
			for i = 1, #entries - 1, 2 do
				table.insert(pairs, { i, i + 1 })
			end
		else
			pairs = Matchmaking.pair(entries, os.clock())
		end
		for _, pair in pairs do
			if not freeSlot() or lanesFree() <= 0 then
				return
			end
			local a, b = entries[pair[1]], entries[pair[2]]
			local kind = spec.Kind or "Ranked"
			-- A fill-in card taken down when its player started searching:
			-- met with that same queue, its bonus comes too (called in).
			local called, bonus = {}, {}
			for _, sides in { { a, b }, { b, a } } do
				for _, member in sides[1].Players do
					local keep = carried[member] and carried[member][sides[2].Id]
					if keep and keep > now and not spec.Intro then
						called[member], bonus[member] = true, AutoQueue.FillBonus
					end
				end
			end
			local function start()
				for member in called do
					carried[member] = nil
				end
				return startMatch(
					mode,
					{ table.clone(a.Players), table.clone(b.Players) },
					PvPRules.profile(kind),
					{ Intro = spec.Intro, Called = called }
				)
			end
			local ok, problem = true, nil
			if spec.Intro then
				ok, problem = start()
			else
				openCheck(mode, { { Players = a.Players, Entry = a }, { Players = b.Players, Entry = b } }, start, nil, bonus)
			end
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
	Duels.crossPair()
end

-- A lone 1v1 Ranked search and a lone 1v1 Casual one, each waiting
-- Matchmaking.CrossAfter with nobody in their own queue: they meet anyway,
-- as Casual (unrated), MATCH READY as always.
function Duels.crossPair()
	local now = os.clock()
	local lone = {}
	for _, mode in Matchmaking.CrossModes do
		for _, entry in queue do
			if
				entry.Mode == mode
				and entry.Size == 1
				and not entry.Check
				and not (entry.Hold and now < entry.Hold)
				and now - entry.Since >= Matchmaking.CrossAfter
				and (lone[mode] == nil or entry.Since < lone[mode].Since)
			then
				lone[mode] = entry
			end
		end
	end
	local a, b = lone[Matchmaking.CrossModes[1]], lone[Matchmaking.CrossModes[2]]
	if not (a and b) or not freeSlot() or lanesFree() <= 0 then
		return
	end
	local mode = Matchmaking.CrossMode
	local kind = Matchmaking.Modes[mode].Kind
	openCheck(mode, { { Players = a.Players, Entry = a }, { Players = b.Players, Entry = b } }, function()
		return startMatch(mode, { table.clone(a.Players), table.clone(b.Players) }, PvPRules.profile(kind), { Called = {} })
	end, nil, {})
end

-- Challenges -----------------------------------------------------------------

local function byUserId(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function challenge(player: Player, userId: any, stats: any)
	local target = byUserId(userId)
	stats = if stats == "Full" then "Full" else "Even"
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
	challenges[target][player] = { Expiry = os.clock() + Matchmaking.ChallengeSeconds, Stats = stats }
	local record = Duels.record(player)
	Remotes.Social:FireClient(
		target,
		"Challenge",
		player.UserId,
		player.DisplayName,
		if record then record.Rating else Matchmaking.StartRating,
		stats
	)
	return reply(true, "Challenged " .. target.DisplayName .. " to a duel.")
end

local function respond(player: Player, userId: any, accept: any)
	local from = byUserId(userId)
	local pending = challenges[player]
	local offer = from and pending and pending[from]
	if pending and from then
		pending[from] = nil
	end
	if not from or not offer or os.clock() > offer.Expiry then
		return reply(false, "That challenge has expired.")
	end
	if accept ~= true then
		Remotes.Notify:FireClient(from, player.DisplayName .. " declined your duel.")
		return reply(true, "Challenge declined.")
	end
	local ok, problem = startMatch("1v1", { { from }, { player } }, PvPRules.profile("Challenge", offer.Stats))
	if not ok then
		return reply(false, problem or "The duel couldn't start.")
	end
	return reply(true, "Duel accepted!")
end

-- Lifecycle ------------------------------------------------------------------

local function step()
	local now = os.clock()
	for _, entry in table.clone(queue) do
		local player = entry.Players[1]
		if busy(player) then dequeue(player) end
	end
	stepChecks(now)
	Duels.pairUp()
	-- Lone entries call the lobby (Shared.AutoQueue).
	for _, entry in table.clone(queue) do
		if entryById(entry.Id) then
			fill(entry, now)
		end
	end
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
		for from, offer in pending do
			if now > offer.Expiry then
				pending[from] = nil
			end
		end
	end
	for _, match in matches do
		if match.State == "Countdown" and now >= match.StartsAt then
			match.State = "Fight"
			dropShields(match)
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
			if match.Rounds then
				endRound(match, winner, "Time")
			else
				finish(match, winner, "Time")
			end
		elseif match.State == "Pivot" and now >= match.Rounds.PivotEnds then
			reveal(match)
		end
	end
end

function Duels.matchOf(player: Player)
	return matchOf[player]
end

-- A new miner's next intro round (Server.IntroRoundsServer): is someone alone
-- in a 1v1 queue, waiting with nobody to meet? Then they meet this player
-- (whose Training session ends where they stand: the match brings them into
-- its lane). Returns whether it joined them.
function Duels.joinWaiting(player: Player): boolean
	for _, entry in queue do
		local spec = Matchmaking.Modes[entry.Mode]
		local other = entry.Players[1]
		if
			spec
			and not spec.Intro
			and spec.Size == 1
			and entry.Size == 1
			and #entry.Players == 1
			and other ~= player
			and other.Parent ~= nil
			and not entry.Check
		then
			if player:GetAttribute("CombatSession") == "Training" then
				require(script.Parent.Duelist).despawn(player)
				player:SetAttribute("CombatSession", nil)
				player:SetAttribute("PvPEnabled", false)
			end
			if busy(player) then
				return false
			end
			enqueue(entry.Mode, { player }, 1)
			return true
		end
	end
	return false
end

function Duels.start()
	Shop.register("DuelQueue", join)
	Shop.register("DuelReturnQueue", autoReturn)
	-- A Ranked 1v1 under way: no LEAVE out of it (Server.ArenaSessions; its
	-- floor holds them in too).
	ArenaSessions.holdIn = function(player: Player): boolean
		local match = matchOf[player]
		return match ~= nil and match.Ranked == true and match.State ~= "Done"
	end
	Shop.register("DuelCancel", function(player)
		if not dequeue(player, player.DisplayName .. " left the duel queue.") then
			return reply(false, "You're not in a queue.")
		end
		return reply(true, "Left the duel queue.")
	end)
	Shop.register("DuelChallenge", challenge)
	Shop.register("DuelRespond", respond)
	Shop.register("DuelPivot", pivot)
	Shop.register("DuelAuto", setAuto)
	Shop.register("DuelFill", fillRespond)
	Shop.register("DuelReady", readyRespond)
	Shop.register("IntroQueue", introJoin)
	Shop.register("IntroRematch", Rematch.request)
	CombatServer.onLethal(lethal)
	Shop.register("DuelLeave", function(player)
		local match = matchOf[player]
		if not match or match.State == "Done" then
			return reply(false, "You're not in a duel.")
		end
		knockOut(match, player, "Forfeit")
		return reply(true, "You forfeited the duel.")
	end)
	local function watch(player: Player)
		-- When they first reach the lobby this visit (a moment before
		-- they're asked anything: Shared.AutoQueue.Settle).
		local function arrive()
			if player:GetAttribute("Outpost") and not arrived[player] then
				arrived[player] = os.clock()
			end
		end
		player:GetAttributeChangedSignal("Outpost"):Connect(arrive)
		arrive()
		-- Away: a dungeon, the Rift, or an Arena session of your own (1v1
		-- PRACTICE, the training ring: "Training" / "PvP"). Back in the lobby
		-- from any of them, you're searching again (the match-ready window
		-- still asks before a match pulls you in).
		local function away()
			local session = player:GetAttribute("CombatSession")
			return player:GetAttribute("DungeonId") or player:GetAttribute("RiftRun")
				or session == "Training" or session == "PvP"
		end
		local wasDungeon = away()
		local pendingReturn = false
		local function returned()
			local inDungeon = away()
			if inDungeon then
				wasDungeon = true
				pendingReturn = false
				dequeue(player)
			elseif wasDungeon then
				wasDungeon = false
				pendingReturn = true
			end
			if pendingReturn then
				task.defer(function()
					if pendingReturn and player.Parent and autoReturn(player).Ok then pendingReturn = false end
				end)
			end
		end
		for _, attribute in { "DungeonId", "RiftRun", "Outpost", "CombatSession", "Spar", "SparDown" } do
			player:GetAttributeChangedSignal(attribute):Connect(returned)
		end
		player.CharacterAdded:Connect(function() task.delay(1, returned) end)
		-- The lobby's intro done (its IntroFinale attribute gone): searching
		-- from here on (a few tries: it may still be wrapping up).
		player:GetAttributeChangedSignal("IntroFinale"):Connect(function()
			if player:GetAttribute("IntroFinale") ~= nil or inFinale(player) or inIntro(player) then
				return
			end
			task.delay(Duels.AfterFinale, function()
				for _ = 1, 6 do
					if not player.Parent or entryOf(player) or player:GetAttribute("MatchId") then
						return
					end
					local result = autoReturn(player)
					if result.Ok or result.Message == "Auto queue is off." then
						return
					end
					task.wait(2)
				end
			end)
		end)
		-- Leaving the Arena session (the Leave button, walking out, respawning)
		-- forfeits a duel in progress.
		-- (on with their intro rounds, in the Arena: the rematch is off)
		player:GetAttributeChangedSignal("CombatSession"):Connect(function()
			if player:GetAttribute("CombatSession") == "Training" and Rematch.Offers[player] then
				Rematch.clear(player, player.DisplayName .. " went on with their intro rounds.")
			end
		end)
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
		Rematch.clear(player, player.DisplayName .. " left.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		dequeue(player, player.DisplayName .. " left the game, so your party left the duel queue.")
		arrived[player], carried[player] = nil, nil
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
