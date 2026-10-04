-- Plays the theme song's loop that fits what you're doing: the menu, the
-- Outpost, a dungeon or a fight (see Modules.Music). A 1v1 (the rival, Arena
-- PvP or a duel) is silent until the fight is engaged: your first attack,
-- guard, surge or maneuver, or the first blow either way. Then the Arena
-- song starts (at Music.StartAt).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Music = require(script.Parent.Modules.Music)

local player = Players.LocalPlayer
local WATCHED = { "DungeonId", "CombatSession", "Outpost", "Expedition" }
local FIGHT_KEYS = {
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.R] = true,
	[Enum.KeyCode.One] = true,
	[Enum.KeyCode.Two] = true,
	[Enum.KeyCode.Three] = true,
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonL2] = true,
}

local splashOver = false
local engaged = false -- this 1v1 has started fighting

local function update()
	if not splashOver then
		return
	end
	local attributes = {}
	for _, name in WATCHED do
		attributes[name] = player:GetAttribute(name)
	end
	local mood = Music.moodFor(attributes)
	if mood == "Arena" and not engaged then
		mood = "Silence" -- quiet until the first action, then the Arena song
	end
	Music.play(mood)
end

local function engage()
	if not engaged and player:GetAttribute("CombatSession") ~= nil then
		engaged = true
		update()
	end
end

for _, name in WATCHED do
	player:GetAttributeChangedSignal(name):Connect(function()
		if name == "CombatSession" then
			engaged = false -- every match waits for its own first action
		end
		update()
	end)
end

-- Your first attack, guard, surge or maneuver.
UserInputService.InputBegan:Connect(function(input)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or FIGHT_KEYS[input.KeyCode]
	then
		engage()
	end
end)
-- Or the first blow, landed, blocked or dodged, either way.
task.spawn(function()
	local fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx")
	fx.OnClientEvent:Connect(function(kind)
		if kind == "Log" or kind == "HitConfirm" then
			engage()
		end
	end)
end)

-- Starts once the splash intro (which has its own music) is over.
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	task.wait(1)
	while playerGui:FindFirstChild("Splash") do
		task.wait(0.2)
	end
	splashOver = true
	update()
end)
