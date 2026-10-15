--[[
	Friendly sparring in the lobby (Shared.Spar has the rules). Request:

	  "Spar", on   take your combat kit out (true) or put it away (false)

	With the kit out, CombatServer lets you fight other players who have
	theirs out (and only them) and asks here when a blow would finish
	you: you're knocked down instead (SparDown), then up again a few
	seconds later at full health, guarded for a moment. The Outpost shows
	the kit in your hands in place of the pick (OutpostServer.refreshKit).

	The kit goes away by itself whenever sparring stops making sense: you
	leave the Outpost, a match or Arena session starts, you climb into a
	machine, you respawn or you leave the game.
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

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
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
		Alive = humanoid ~= nil and humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") ~= nil,
		Seated = humanoid ~= nil and humanoid.SeatPart ~= nil,
		Busy = busy,
		Intro = profile ~= nil and profile.Intro ~= nil and profile.Intro.Done ~= true,
	}
end

-- Puts the kit away (and clears what sparring left behind). A knocked-down
-- player is healed straight away: nobody walks off at 1 health.
local function stop(player: Player)
	if not Spar.sparring(player) and player:GetAttribute("SparDown") == nil then
		return
	end
	local humanoid = humanoidOf(player)
	if Spar.isDown(player) and humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	player:SetAttribute("Spar", nil)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("SparHurt", nil)
	player:SetAttribute("Blocking", false)
	CombatServer.reset(player)
end

local function start(player: Player)
	player:SetAttribute("SparDown", nil)
	player:SetAttribute("SparHurt", nil)
	-- Fresh: full stamina and charge, no leftover effects.
	CombatServer.reset(player)
	player:SetAttribute("Spar", true)
end

local function request(player: Player, on: any)
	if type(on) ~= "boolean" then
		return reply(false, "")
	end
	if on then
		if Spar.sparring(player) then
			return reply(true, "")
		end
		local problem = Spar.startProblem(stateOf(player))
		if problem then
			return reply(false, problem)
		end
		start(player)
		return reply(true, "")
	end
	if not Spar.sparring(player) then
		return reply(true, "")
	end
	local wait = Spar.stopWait({
		Down = player:GetAttribute("SparDown"),
		Hurt = player:GetAttribute("SparHurt"),
	}, workspace:GetServerTimeNow())
	if wait > 0 then
		return reply(false, string.format("Still in the fight: put it away in %ds.", math.ceil(wait)), { Wait = wait })
	end
	stop(player)
	return reply(true, "")
end

-- Back on your feet: full health, a moment's guard.
local function getUp(player: Player, humanoid: Humanoid)
	-- (Gone, or a new body since: nothing to do.)
	if humanoidOf(player) ~= humanoid then
		return
	end
	player:SetAttribute("SparDown", nil)
	if humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
		local guard = Instance.new("ForceField")
		guard.Name = "SparGuard"
		guard.Visible = false
		guard.Parent = player.Character
		Debris:AddItem(guard, Spar.GuardSeconds)
	end
end

-- A blow that would finish a sparring player: down instead.
local function knockOut(player: Player, humanoid: Humanoid, source: Player?): boolean
	if Spar.isDown(player) then
		return true
	end
	humanoid.Health = math.max(1, math.min(humanoid.Health, 1))
	CombatServer.reset(player)
	player:SetAttribute("Blocking", false)
	player:SetAttribute("SparDown", workspace:GetServerTimeNow() + Spar.DownSeconds)
	Remotes.CombatFx:FireAllClients("SparKO", player.UserId, if source then source.UserId else 0)
	task.delay(Spar.DownSeconds, getUp, player, humanoid)
	return true
end

-- Hit in a spar: the weapon stays out a moment (Spar.SheatheLock).
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

function SparServer.start()
	Shop.register("Spar", request)
	CombatServer.onSparLethal(knockOut)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			stop(player)
			task.spawn(watchHealth, player, character)
		end)
		if player.Character then
			task.spawn(watchHealth, player, player.Character)
		end
		-- A match, an Arena session or leaving the Outpost puts it away at once.
		for _, name in { "Outpost", "CombatSession", "MatchId", "DungeonId", "Expedition" } do
			player:GetAttributeChangedSignal(name):Connect(function()
				if Spar.sparring(player) and Spar.startProblem(stateOf(player)) then
					stop(player)
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- Anything else (a seat, a fall): checked a few times a second.
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.25
		for _, player in Players:GetPlayers() do
			if Spar.sparring(player) and Spar.startProblem(stateOf(player)) then
				stop(player)
			end
		end
	end)
end

-- For tests.
SparServer._request, SparServer._knockOut, SparServer._stop = request, knockOut, stop
SparServer._getUp = getUp

return SparServer
