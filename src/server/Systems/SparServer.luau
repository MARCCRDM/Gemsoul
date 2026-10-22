--[[
	Friendly sparring in the lobby (Shared.Spar has the rules). Requests:

	  "SparAsk", userId              ask someone near you to spar
	  "SparRespond", userId, accept  answer someone who asked you
	  "Spar", false                  end your spar (for both of you)

	(A bare "Spar", true no longer takes the kit out: a spar has to be
	asked for and agreed to. It answers with how to ask.)

	The Social remote tells clients:
	  "SparAsk", fromId, fromName, seconds   someone asks you to spar
	  "SparAskOver", fromId                  that request is gone (they're
	                                         sparring with someone else, or
	                                         busy, or left): take the card down

	Once both agree, both kits come out (Spar, SparWith: each other's
	UserId) and CombatServer lets the two fight each other, and nobody
	else. It asks here when a blow would finish one of them: they're
	knocked down instead (SparDown), then up again a few seconds later at
	full health, guarded for a moment. The Outpost shows the kit in their
	hands in place of the pick (OutpostServer.refreshKit).

	A spar ends for both when either ends it, or whenever it stops making
	sense for either: leaving the Outpost, a match or Arena session, a
	machine, a respawn, leaving the game, or drifting too far apart.

	Hunting is the kit out alone, against the Outpost's wild kaiju and moon
	bugs (KaijuWilds): Hunt and Spar, with no partner. No player can hit a
	hunter or be hit by one. A creature's finishing blow, on a hunter or
	anyone else in the Outpost (a miner a rift's critter catches), kills
	them (SparServer.onKnockedOut: FrontierServer marks them Killed): they
	lie dead, robbed first out past the core (Server.Robbery), then they're
	back at base. They don't get up where they fell (getUp leaves the
	killed alone); a spar's knock-down is the only one you get up from.
	"Hunt", true / false takes the kit out or puts it away: the 1 key's
	(and the phone's kit button, Client.SparKit), in the Outpost and in the
	Rift alike, never while down.

	A 1v1 + Kaiju battle (Server.KaijuBattles) pairs its two miners here
	without an ask (SparServer.pair) and ends it with unpair. While it's
	on, SparServer.held says why the spar can't be ended by hand, and
	SparServer.onSparDown takes a miner who's knocked down out of it: down
	a moment, then their spar's over for both (no getting up into it).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Spar = require(ReplicatedStorage.Shared.Spar)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local SparServer = {}

-- Open requests: asks[target][from] = when it runs out (os.clock).
local asks: { [Player]: { [Player]: number } } = {}
-- After a no, or no answer: again[from][target] = when you can ask them again.
local again: { [Player]: { [Player]: number } } = {}
-- Your last request (os.clock), for Spar.AskGap.
local lastAsk: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function byUserId(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function partnerOf(player: Player): Player?
	local id = Spar.partner(player)
	return if id then Players:GetPlayerByUserId(id) else nil
end

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

-- What the rules need to know about a player right now.
local function stateOf(player: Player): Spar.State
	local humanoid = humanoidOf(player)
	local profile = PlayerData.get(player)
	local busy = nil
	for _, name in { "CombatSession", "MatchId", "DungeonId", "Expedition", "DungeonSelecting" } do
		if player:GetAttribute(name) then
			busy = name
		end
	end
	return {
		Outpost = player:GetAttribute("Outpost") == true,
		Alive = humanoid ~= nil and humanoid.Health > 0 and rootOf(player) ~= nil,
		Seated = (humanoid ~= nil and humanoid.SeatPart ~= nil) or player:GetAttribute("MechPilot") ~= nil,
		Busy = busy,
		Intro = profile ~= nil and profile.Intro ~= nil and profile.Intro.Done ~= true,
	}
end

local function distance(a: Player, b: Player): number?
	local ra, rb = rootOf(a), rootOf(b)
	return if ra and rb then (ra.Position - rb.Position).Magnitude else nil
end

-- Requests ---------------------------------------------------------------------------------------------

-- Takes down every open request from `from` (they're busy now, or gone).
local function withdraw(from: Player)
	for target, pending in asks do
		if pending[from] then
			pending[from] = nil
			if target.Parent then
				Remotes.Social:FireClient(target, "SparAskOver", from.UserId)
			end
		end
	end
end

-- The kit -----------------------------------------------------------------------------------------------

-- Puts the kit away (and clears what sparring left behind). A knocked-down
-- player is healed straight away: nobody walks off at 1 health. The
-- partner's spar ends too, and `note` tells them why.
local function stop(player: Player, note: string?)
	if not Spar.sparring(player) and player:GetAttribute("SparDown") == nil then
		return
	end
	local partner = partnerOf(player)
	local humanoid = humanoidOf(player)
	if Spar.isDown(player) and humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	player:SetAttribute("Spar", nil)
	player:SetAttribute("Hunt", nil)
	player:SetAttribute("SparWith", nil)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("Killed", nil)
	player:SetAttribute("SparHurt", nil)
	player:SetAttribute("Blocking", false)
	CombatServer.reset(player)
	-- (Only if they were still sparring with this player.)
	if partner and partner:GetAttribute("SparWith") == player.UserId then
		stop(partner)
		if note and partner.Parent then
			notify(partner, note)
		end
	end
end

local function start(player: Player, partner: Player)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("SparHurt", nil)
	-- Fresh: full stamina and charge, no leftover effects.
	CombatServer.reset(player)
	-- (The partner first, so the kit never comes out without one.)
	player:SetAttribute("SparWith", partner.UserId)
	player:SetAttribute("Spar", true)
end

-- Both agreed: kits out, each with the other. Their other requests, to
-- and from anyone else, are off (and whoever else asked them hears why).
local function begin(a: Player, b: Player)
	for _, player in { a, b } do
		withdraw(player)
		for from in asks[player] or {} do
			if from ~= a and from ~= b and from.Parent then
				notify(from, player.DisplayName .. " is sparring with someone else.")
			end
		end
		asks[player] = nil
	end
	start(a, b)
	start(b, a)
end

-- Why `player` can't ask `target` now (nil if they can). `answering`: they
-- asked you first, so asking back is a yes (no waiting on them).
local function askProblem(player: Player, target: Player?, answering: boolean?): string?
	local here = target ~= nil and target ~= player and target.Parent ~= nil
	if not here or not target then
		return Spar.askProblem({ Here = false, Name = "", Mine = stateOf(player), Theirs = stateOf(player) })
	end
	-- (Nobody spars in the Rift: it would knock a runner down, and the trip
	-- would read it as a fall. Server.RiftServer.)
	if player:GetAttribute("RiftRun") ~= nil then
		return "Not in the Rift."
	elseif target:GetAttribute("RiftRun") ~= nil then
		return target.DisplayName .. " is in the Rift."
	end
	if Spar.hunting(player) then
		return "Put your kit away first (1)."
	elseif Spar.hunting(target) then
		return target.DisplayName .. " is out hunting."
	end
	local partner, theirs = partnerOf(player), partnerOf(target)
	local waits = again[player]
	return Spar.askProblem({
		Here = true,
		Name = target.DisplayName,
		Mine = stateOf(player),
		Theirs = stateOf(target),
		MyPartner = if partner then partner.DisplayName elseif Spar.sparring(player) then "someone" else nil,
		TheirPartner = if theirs then theirs.DisplayName elseif Spar.sparring(target) then "someone" else nil,
		Distance = distance(player, target),
		Asked = not answering and asks[target] ~= nil and asks[target][player] ~= nil,
		Wait = if not answering and waits and waits[target] then waits[target] - os.clock() else nil,
	})
end

local function ask(player: Player, userId: any)
	local target = byUserId(userId)
	local now = os.clock()
	if lastAsk[player] and now - lastAsk[player] < Spar.AskGap then
		return reply(false, "One moment.")
	end
	-- They asked you first: asking back is a yes.
	local theirs = if target and asks[player] then asks[player][target] else nil
	local answering = theirs ~= nil and theirs > now
	local problem = askProblem(player, target, answering)
	if problem then
		return reply(false, problem)
	end
	lastAsk[player] = now
	local to = target :: Player
	if answering then
		begin(to, player)
		notify(to, player.DisplayName .. " accepted. Fight!")
		return reply(true, "")
	end
	asks[to] = asks[to] or {}
	asks[to][player] = now + Spar.AskSeconds
	Remotes.Social:FireClient(to, "SparAsk", player.UserId, player.DisplayName, Spar.AskSeconds)
	return reply(true, "Asked " .. to.DisplayName .. " to spar.")
end

local function respond(player: Player, userId: any, accept: any)
	local from = byUserId(userId)
	local pending = asks[player]
	local expiry = from and pending and pending[from]
	if pending and from then
		pending[from] = nil
	end
	if not from or not expiry or os.clock() > expiry then
		return reply(false, "That request has expired.")
	end
	if accept ~= true then
		again[from] = again[from] or {}
		again[from][player] = os.clock() + Spar.AskAgain
		notify(from, player.DisplayName .. " said no to a spar.")
		return reply(true, "")
	end
	-- Still free, both of you, and still close? (If not, the asker hears.)
	local apart = distance(player, from)
	local problem = Spar.startProblem(stateOf(player))
		or (if Spar.sparring(player) then "You're already sparring." else nil)
		or (if Spar.sparring(from) or Spar.startProblem(stateOf(from))
			then from.DisplayName .. " can't spar right now."
			else nil)
		or (if not apart or apart > Spar.MaxApart then from.DisplayName .. " is too far away now." else nil)
	if problem then
		notify(from, player.DisplayName .. " couldn't start the spar.")
		return reply(false, problem)
	end
	begin(from, player)
	notify(from, player.DisplayName .. " accepted. Fight!")
	return reply(true, "")
end

-- "Spar", on: only ending a spar (on = false) is done this way now.
local function request(player: Player, on: any)
	if type(on) ~= "boolean" then
		return reply(false, "")
	end
	if on then
		if Spar.sparring(player) then
			return reply(true, "")
		end
		return reply(false, "Ask someone to spar first: walk up to them and press Z.")
	end
	if not Spar.sparring(player) then
		return reply(true, "")
	end
	local held = SparServer.held(player)
	if held then
		return reply(false, held)
	end
	local wait = Spar.stopWait({
		Down = player:GetAttribute("SparDown"),
		Hurt = player:GetAttribute("SparHurt"),
	}, workspace:GetServerTimeNow())
	if wait > 0 then
		return reply(false, string.format("Still in the fight: you can stop in %ds.", math.ceil(wait)), { Wait = wait })
	end
	stop(player, player.DisplayName .. " ended the spar.")
	return reply(true, "")
end

-- "Hunt", on: the kit out alone to hunt creatures, or away again.
local function hunt(player: Player, on: any)
	if type(on) ~= "boolean" then
		return reply(false, "")
	end
	-- (Down, you get up first: swapping would stand you up.)
	if Spar.isDown(player) or player:GetAttribute("Robbed") ~= nil then
		return reply(false, "Get back on your feet first.")
	end
	if not on then
		if not Spar.hunting(player) then
			return reply(true, "")
		end
		stop(player)
		return reply(true, "")
	end
	if Spar.hunting(player) then
		return reply(true, "")
	elseif Spar.sparring(player) then
		return reply(false, "Finish your spar first.")
	end
	local problem = Spar.startProblem(stateOf(player))
	if problem then
		return reply(false, problem)
	end
	-- (Their spar requests are off while they hunt.)
	withdraw(player)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("SparHurt", nil)
	CombatServer.reset(player)
	player:SetAttribute("Hunt", true)
	player:SetAttribute("Spar", true)
	return reply(true, "")
end

-- Knock-downs ---------------------------------------------------------------------------------------------

-- Back on your feet: full health, a moment's guard. (`miner`: downed out
-- of a spar, by a rift's critter in the Outpost; `tripped`: only tripped,
-- so their health is what it was.)
local function getUp(player: Player, humanoid: Humanoid, miner: boolean?, tripped: boolean?)
	-- (Gone, or a new body since: nothing to do. Down at a Rift boss, they
	-- stay down till they choose: Server.RiftServer gets them up; being
	-- robbed, till it's over: Server.Robbery.)
	if
		humanoidOf(player) ~= humanoid
		or player:GetAttribute("RiftFallen") ~= nil
		or player:GetAttribute("Robbed") ~= nil
		or player:GetAttribute("Killed") ~= nil
	then
		return
	end
	player:SetAttribute("SparDown", nil)
	-- (The spar may have ended while they were down: then they were healed
	-- already, and need no guard. A miner still in the Outpost gets up
	-- whole, too.)
	if humanoid.Health > 0 and (Spar.sparring(player) or (miner and Spar.knocksDown(player))) then
		if not tripped then
			humanoid.Health = humanoid.MaxHealth
		end
		local guard = Instance.new("ForceField")
		guard.Name = "SparGuard"
		guard.Visible = false
		guard.Parent = player.Character
		Debris:AddItem(guard, Spar.GuardSeconds)
	end
end

-- A blow that would finish a sparring player: down instead. (`trip`: a
-- rift critter's trip, { Seconds, By }: down that long, their health
-- untouched, "by" whatever tripped them.)
local function knockOut(player: Player, humanoid: Humanoid, source: Player?, trip: any?): boolean
	if Spar.isDown(player) then
		return true
	end
	local seconds = if trip then trip.Seconds or Spar.DownSeconds else Spar.DownSeconds
	if not trip then
		humanoid.Health = math.max(1, math.min(humanoid.Health, 1))
	end
	CombatServer.reset(player)
	player:SetAttribute("Blocking", false)
	-- (A fresh knock-down: whether it's a kill is FrontierServer's to say.)
	player:SetAttribute("Killed", nil)
	player:SetAttribute("SparDown", workspace:GetServerTimeNow() + seconds)
	Remotes.CombatFx:FireAllClients(
		"SparKO",
		player.UserId,
		if source then source.UserId else 0,
		if trip then trip.By else nil
	)
	-- Knocked down in a battle's duel: out of it (KaijuBattles), so no
	-- getting up into it; a moment down, then the duel's over for both.
	if not trip and player:GetAttribute("SparWith") ~= nil and SparServer.onSparDown(player, source) then
		task.delay(seconds, function()
			if humanoidOf(player) == humanoid and humanoid.Health > 0 then
				humanoid.Health = humanoid.MaxHealth
			end
			stop(player)
		end)
		return true
	end
	task.delay(seconds, getUp, player, humanoid, not Spar.sparring(player), trip ~= nil)
	-- Knocked out by a creature (not tripped, not in a spar with someone):
	-- killed, in the Outpost, and robbed past its core (FrontierServer:
	-- Server.Robbery).
	if not trip and player:GetAttribute("SparWith") == nil then
		task.spawn(SparServer.onKnockedOut, player)
	end
	return true
end

-- Someone knocked out by a creature (Main sets it: FrontierServer.knockedOut).
SparServer.onKnockedOut = function(_player: Player) end

-- Knocked down in a spar: true if that's them out of it (a 1v1 + Kaiju
-- battle's duel: KaijuBattles sets it).
SparServer.onSparDown = function(_player: Player, _by: Player?): boolean
	return false
end

-- Why `player` can't end their spar by hand just now (nil: they can).
SparServer.held = function(_player: Player): string?
	return nil
end

-- Two paired to fight without an ask (a 1v1 + Kaiju battle's duel), at
-- full health: any spar they were in is ended first.
function SparServer.pair(a: Player, b: Player)
	for _, player in { a, b } do
		if Spar.sparring(player) then
			stop(player)
		end
		local humanoid = humanoidOf(player)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
	end
	begin(a, b)
end

-- Their spar over (and their partner's), kits away.
function SparServer.unpair(player: Player)
	stop(player)
end

-- The Rift's (Server.RiftServer): going in, your combat kit comes out to
-- hunt (a spar ended first); coming home, it's put away. In there it can't
-- be put away (the "Hunt" request says so).
function SparServer.riftKit(player: Player, on: boolean)
	if not on then
		if Spar.sparring(player) then
			stop(player)
		end
		return
	end
	if Spar.hunting(player) then
		return
	end
	if Spar.sparring(player) then
		stop(player, player.DisplayName .. " went into the Rift.")
	end
	withdraw(player)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("SparHurt", nil)
	CombatServer.reset(player)
	player:SetAttribute("Hunt", true)
	player:SetAttribute("Spar", true)
end

-- Tripped by a rift critter in the Outpost (a gem raid: Shared.Frontier.Raid):
-- down for `seconds`, health untouched, then up with a moment's guard.
-- Not in a spar with someone or a match, not down already, not guarded.
function SparServer.knockDown(player: Player, seconds: number, by: string?): boolean
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 or Spar.isDown(player) then
		return false
	end
	if player:GetAttribute("SparWith") ~= nil or not Spar.knocksDown(player) then
		return false
	end
	if player.Character and player.Character:FindFirstChild("SparGuard") then
		return false -- (just back up: a moment's grace)
	end
	return knockOut(player, humanoid, nil, { Seconds = seconds, By = by })
end

-- Hit in a spar: it can't end for a moment (Spar.SheatheLock).
local function watchHealth(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last and Spar.sparring(player) then
			player:SetAttribute("SparHurt", workspace:GetServerTimeNow())
		end
		last = health
	end)
end

-- Upkeep ----------------------------------------------------------------------------------------------------

-- Whether a spar still makes sense for `player`; ends it (for both) if not.
local function check(player: Player)
	if not Spar.sparring(player) then
		return
	end
	if Spar.hunting(player) then
		-- (A hunt has no partner: it lasts while hunting still makes sense.)
		if Spar.startProblem(stateOf(player)) then
			stop(player)
		end
		return
	end
	local partner = partnerOf(player)
	if not partner or not Spar.paired(player, partner) then
		stop(player)
		notify(player, "The spar is over.")
	elseif Spar.startProblem(stateOf(player)) then
		stop(player, "The spar with " .. player.DisplayName .. " is over.")
	else
		local apart = distance(player, partner)
		if apart and apart > Spar.MaxApart then
			stop(player, "You and " .. player.DisplayName .. " drifted apart: the spar is over.")
			notify(player, "You and " .. partner.DisplayName .. " drifted apart: the spar is over.")
		end
	end
end

-- Requests that ran out: the asker hears, and waits before asking again.
local function expire(now: number)
	for target, pending in asks do
		for from, expiry in pending do
			if now > expiry then
				pending[from] = nil
				again[from] = again[from] or {}
				again[from][target] = now + Spar.AskAgain
				if from.Parent then
					notify(from, target.DisplayName .. " didn't answer.")
				end
			end
		end
		if next(pending) == nil then
			asks[target] = nil
		end
	end
end

local function left(player: Player)
	stop(player, player.DisplayName .. " left the game: the spar is over.")
	withdraw(player)
	asks[player], again[player], lastAsk[player] = nil, nil, nil
	for _, waits in again do
		waits[player] = nil
	end
end

function SparServer.start()
	Shop.register("Spar", request)
	Shop.register("SparAsk", ask)
	Shop.register("SparRespond", respond)
	Shop.register("Hunt", hunt)
	CombatServer.onSparLethal(knockOut)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			player:SetAttribute("Killed", nil)
			stop(player, "The spar with " .. player.DisplayName .. " is over.")
			task.spawn(watchHealth, player, character)
		end)
		if player.Character then
			task.spawn(watchHealth, player, player.Character)
		end
		-- A match, an Arena session or leaving the Outpost ends it at once,
		-- and takes down any request they've sent.
		for _, name in { "Outpost", "CombatSession", "MatchId", "DungeonId", "Expedition" } do
			player:GetAttributeChangedSignal(name):Connect(function()
				check(player)
				if Spar.startProblem(stateOf(player)) then
					withdraw(player)
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(left)
	-- Anything else (a seat, a fall, drifting apart, requests running
	-- out): checked a few times a second.
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.25
		for _, player in Players:GetPlayers() do
			check(player)
		end
		expire(now)
	end)
end

-- For tests.
SparServer._request, SparServer._knockOut, SparServer._stop = request, knockOut, stop
SparServer._getUp, SparServer._ask, SparServer._respond = getUp, ask, respond
SparServer._asks, SparServer._hunt = asks, hunt

return SparServer
