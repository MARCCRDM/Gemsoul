-- Starts the background music, louder while in an Arena fight (see Modules.Music).
local Players = game:GetService("Players")

local Music = require(script.Parent.Modules.Music)

local player = Players.LocalPlayer
local function update()
	Music.setMood(player:GetAttribute("CombatSession") ~= nil)
end
player:GetAttributeChangedSignal("CombatSession"):Connect(update)
task.delay(2, update) -- after the intro has a moment to load
