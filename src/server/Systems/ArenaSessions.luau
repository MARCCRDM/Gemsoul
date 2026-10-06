local ArenaDrop = require(script.Parent.ArenaDrop)
-- Joining the PvP Arena is explicit; training visitors cannot receive player damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Combat = require(ReplicatedStorage.Shared.Combat)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local ArenaSessions = {}
-- Hooks set by the Duelist (a computer rival in PvP); nil when not running.
ArenaSessions.onDungeonLeave = nil
ArenaSessions.onEnter = nil :: ((Player, boolean) -> ())?
ArenaSessions.onLeave = nil :: ((Player) -> ())?
local busy = {}
local function enter(player, pvp)
	if busy[player] or player:GetAttribute("CombatSession") then
		return Shop.reply(false, "Leave your current Arena session first.")
	end
	if player:GetAttribute("Expedition") then
		return Shop.reply(false, "Return from your expedition before entering the Arena.")
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = landmarks and landmarks:GetAttribute("ArenaFloor")
	if not PlayerData.get(player) or not humanoid or humanoid.Health <= 0 or typeof(center) ~= "Vector3" then
		return Shop.reply(false, "The Arena isn't ready yet.")
	end
	busy[player] = true
	ArenaDrop.prepare(player)
	local angle = math.rad((player.UserId % 8) * 45)
	local spot = center + Vector3.new(math.cos(angle) * 22, 4, math.sin(angle) * 22)
	local ok = pcall(function()
		player:RequestStreamAroundAsync(spot)
		if player.Character ~= character or humanoid.Health <= 0 then
			error("Character changed")
		end
		character:PivotTo(CFrame.lookAt(spot, center + Vector3.new(0, 4, 0)))
	end)
	busy[player] = nil
	if not ok then
		ArenaDrop.cancel(character)
		return Shop.reply(false, "Couldn't enter the Arena. Try again.")
	end
	player:SetAttribute("PvPEnabled", pvp == true)
	CombatServer.reset(player)
	player:SetAttribute("CombatSession", if pvp then "PvP" else "Training")
	local protection = Instance.new("ForceField")
	protection.Visible = false
	protection.Parent = character
	Debris:AddItem(protection, 3)
	if ArenaSessions.onEnter then
		task.spawn(ArenaSessions.onEnter, player, pvp == true)
	end
	return Shop.reply(
		true,
		if pvp
			then "PvP Arena: a rival miner steps in. Other Arena fighters can attack you too."
			else "Training Arena: a sparring partner steps in. Player damage is off."
	)
end
local function leave(player)
	if player.Character then
		ArenaDrop.cancel(player.Character)
	end
	player:SetAttribute("ArenaInserted", nil)
	player:SetAttribute("ArenaDropPreparing", nil)
	if ArenaSessions.onDungeonLeave then
		ArenaSessions.onDungeonLeave(player)
	end
	if ArenaSessions.onLeave then
		ArenaSessions.onLeave(player)
	end
	CombatServer.reset(player)
	player:SetAttribute("PvPEnabled", false)
	player:SetAttribute("CombatSession", nil)
	player:SetAttribute("RaidId", nil)
	player:SetAttribute("Blocking", false)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	-- Came from the Saga Outpost (a duel challenged there): back to it.
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local outpost = landmarks and landmarks:GetAttribute("OutpostSpawn")
	if player.Character then
		if player:GetAttribute("Outpost") and typeof(outpost) == "CFrame" then
			player.Character:PivotTo(outpost)
			return Shop.reply(true, "Back at the Outpost.")
		end
		player.Character:PivotTo(if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 6, 0))
	end
	return Shop.reply(true, "Back at base.")
end
-- Back to the menu (a finished duel uses this too).
ArenaSessions.leave = leave
function ArenaSessions.start()
	Shop.register("ArenaTraining", function(player)
		return enter(player, false)
	end)
	Shop.register("ArenaPvP", function(player)
		return enter(player, true)
	end)
	Shop.register("ArenaLeave", leave)
	local function watch(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("ArenaInserted", nil)
			player:SetAttribute("ArenaDropUntil", nil)
			player:SetAttribute("ArenaDropFocus", nil)
			if ArenaSessions.onLeave then
				ArenaSessions.onLeave(player)
			end
			player:SetAttribute("PvPEnabled", false)
			player:SetAttribute("CombatSession", nil)
			player:SetAttribute("RaidId", nil)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		if ArenaSessions.onLeave then
			ArenaSessions.onLeave(player)
		end
	end)
	-- Leaving the floor ends PvP eligibility; re-entry requires an explicit session.
	local timer = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.25 then
			return
		end
		timer = 0
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if
				player:GetAttribute("CombatSession")
				and root
				and not player:GetAttribute("DungeonId")
				and not Combat.inArena(root.Position)
			then
				leave(player)
			end
		end
	end)
end
return ArenaSessions
