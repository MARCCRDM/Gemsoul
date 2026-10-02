-- Joining the PvP Arena is explicit; training visitors cannot receive player damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Combat = require(ReplicatedStorage.Shared.Combat)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local ArenaSessions = {}
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
		return Shop.reply(false, "Couldn't enter the Arena. Try again.")
	end
	player:SetAttribute("PvPEnabled", pvp == true)
	CombatServer.reset(player)
	player:SetAttribute("CombatSession", if pvp then "PvP" else "Training")
	local protection = Instance.new("ForceField")
	protection.Parent = character
	Debris:AddItem(protection, 3)
	return Shop.reply(
		true,
		if pvp
			then "PvP Arena: other Arena fighters can attack you."
			else "Training Arena: practise on dummies. Player damage is off."
	)
end
local function leave(player)
	CombatServer.reset(player)
	player:SetAttribute("PvPEnabled", false)
	player:SetAttribute("CombatSession", nil)
	player:SetAttribute("Blocking", false)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if player.Character then
		player.Character:PivotTo(if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 6, 0))
	end
	return Shop.reply(true, "Back at base.")
end
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
			player:SetAttribute("PvPEnabled", false)
			player:SetAttribute("CombatSession", nil)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
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
			if player:GetAttribute("CombatSession") and root and not Combat.inArena(root.Position) then
				leave(player)
			end
		end
	end)
end
return ArenaSessions
