-- Plays the theme song's loop that fits what you're doing: the menu, the
-- Outpost, a dungeon or a fight (see Modules.Music).
local Players = game:GetService("Players")

local Music = require(script.Parent.Modules.Music)

local player = Players.LocalPlayer
local WATCHED = { "DungeonId", "CombatSession", "Outpost" }

local splashOver = false
local function update()
	if not splashOver then
		return
	end
	local attributes = {}
	for _, name in WATCHED do
		attributes[name] = player:GetAttribute(name)
	end
	Music.play(Music.moodFor(attributes))
end
for _, name in WATCHED do
	player:GetAttributeChangedSignal(name):Connect(update)
end
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
