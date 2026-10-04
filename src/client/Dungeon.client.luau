-- Dungeon objectives: a short toast when the room or its goal changes. (No
-- fixed strip at the top of the screen: that space belongs to the target
-- lock's name and health bar.)
local Players = game:GetService("Players")
local UiKit = require(script.Parent.Modules.UiKit)
local player = Players.LocalPlayer

local last = ""
local function announce()
	if player:GetAttribute("DungeonId") == nil then
		last = ""
		return
	end
	local objective = player:GetAttribute("DungeonObjective")
	if not objective then
		return
	end
	local line = if player:GetAttribute("DungeonTest")
		then "Test run · " .. objective
		else string.format("Room %d / 5 · %s", player:GetAttribute("DungeonRoom") or 1, objective)
	if line ~= last then
		last = line
		UiKit.toast(line)
	end
end
for _, attribute in { "DungeonId", "DungeonRoom", "DungeonObjective" } do
	player:GetAttributeChangedSignal(attribute):Connect(announce)
end
announce()
