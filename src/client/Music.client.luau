-- Plays the theme song's loop that fits what you're doing: the menu, the
-- Outpost, a dungeon or a fight (see Modules.Music).
local Players = game:GetService("Players")

local Music = require(script.Parent.Modules.Music)

local player = Players.LocalPlayer
local WATCHED = { "DungeonId", "CombatSession", "Outpost" }

local function update()
	local attributes = {}
	for _, name in WATCHED do
		attributes[name] = player:GetAttribute(name)
	end
	Music.play(Music.moodFor(attributes))
end
for _, name in WATCHED do
	player:GetAttributeChangedSignal(name):Connect(update)
end
task.delay(2, update) -- after the intro has a moment to load
