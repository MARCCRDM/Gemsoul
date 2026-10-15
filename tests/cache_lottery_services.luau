
-- (CacheLottery's extra doubles, on top of the mining reel's.)
local Random = { new = function()
	return { NextNumber = function() return 0.01 end, NextInteger = function(_, a) return a end }
end }
function methods:IsA(class) return self.ClassName == class end
local previewsBuilt = true
local drawnGear = 0
local GearArt = {
	draw = function(view, slot, id)
		if not previewsBuilt then return false end
		drawnGear += 1
		view.Name = slot .. "|" .. id
		new("WorldModel", {}, view)
		new("Camera", {}, view)
		return true
	end,
	icon = function(parent, slot) new("Frame", { Name = "Icon|" .. slot }, parent) end,
}
local Classes = { gear = function() return { Passive = { Name = "Bulwark" } } end }
local GemClient = { Profile = { Character = { Class = "Warrior" } } }
local LotterySound = { tick = function() end, reveal = function(rank) table.insert(sounds, rank) end }
task.delay = function(seconds, fn) task.spawn(function() task.wait(seconds); fn() end) end
-- (A child moved away and back is listed once, as in Roblox.)
function methods:GetChildren()
	local result, seen = {}, {}
	for _, child in self.Children do
		if child.Parent == self and not child.Destroyed and not seen[child] then
			seen[child] = true
			table.insert(result, child)
		end
	end
	return result
end
