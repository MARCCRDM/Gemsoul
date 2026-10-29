--[[
	The UI's images fetched as the game starts (Modules/ImagePreload): the
	surge icons on the Inventory's Q/E/R and gem cards, and the gear icon
	sheet, so the first screen that shows them has them.
]]
local Modules = script.Parent:WaitForChild("Modules")
local ImagePreload = require(Modules:WaitForChild("ImagePreload"))
local SurgeIcons = require(Modules:WaitForChild("SurgeIcons"))
local GearArt = require(Modules:WaitForChild("GearArt"))

ImagePreload.add({ SurgeIcons.ImageId, GearArt.IconSheet.ImageId })
