-- Builds the whole world when the server starts: lighting, terrain, the
-- central hub, the five zone buildings in a ring facing the plaza, and the
-- kingdom walls around everything.
local Builder = require(script.Parent.Builder)
local Hub = require(script.Parent.Hub)
local Kingdom = require(script.Parent.Kingdom)
local Landscape = require(script.Parent.Landscape)
local applyLighting = require(script.Parent.Lighting)

local C = Builder.Colors

-- Distance from the plaza centre to each building's front gate.
local ZONE_DISTANCE = 110
local GROUND_Y = 1

-- Angle 0 is north (-Z); zones go clockwise around the plaza.
local ZONES = {
	{ Name = "Mining", Title = "MINE", Angle = 0, Color = C.Cyan, Module = script.Parent.Zones.Mining },
	{ Name = "Crafting", Title = "CRAFT & CUT", Angle = 72, Color = C.Amber, Module = script.Parent.Zones.Crafting },
	{ Name = "Marketplace", Title = "BAZAAR", Angle = 144, Color = C.Green, Module = script.Parent.Zones.Marketplace },
	{ Name = "Enchanting", Title = "ARCANUM", Angle = 216, Color = C.Purple, Module = script.Parent.Zones.Enchanting },
	{ Name = "Arena", Title = "ARENA", Angle = 288, Color = C.Red, Module = script.Parent.Zones.Arena },
}

local WorldBuilder = {}

function WorldBuilder.build(): Folder
	applyLighting()

	-- The Baseplate template's own spawn would sit inside the obelisk.
	for _, instance in workspace:GetChildren() do
		if instance:IsA("SpawnLocation") then
			instance.Enabled = false
		end
	end

	local town = Builder.folder(workspace, "Town")

	for _, zone in ZONES do
		-- Local -Z faces the plaza; the building extends away from it along +Z.
		zone.Origin = Hub.radial(zone.Angle) * CFrame.new(0, GROUND_Y, -ZONE_DISTANCE) * CFrame.Angles(0, math.pi, 0)
	end

	Landscape.build(town, Kingdom.MoatDistance, Kingdom.GateAngle)
	Hub.build(town, ZONES, ZONE_DISTANCE, Kingdom.GateAngle)
	for _, zone in ZONES do
		local folder = Builder.folder(town, zone.Name)
		require(zone.Module).build(folder, zone.Origin, zone.Color)
	end
	Kingdom.build(town, ZONES, ZONE_DISTANCE)

	return town
end

return WorldBuilder
