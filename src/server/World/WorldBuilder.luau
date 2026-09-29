-- Builds the whole world when the server starts: lighting, the terrain
-- landscape, the village inside the walls, and the walls themselves.
local Builder = require(script.Parent.Builder)
local Kingdom = require(script.Parent.Kingdom)
local Landscape = require(script.Parent.Landscape)
local Town = require(script.Parent.Town)
local applyLighting = require(script.Parent.Lighting)

local WorldBuilder = {}

function WorldBuilder.build(): Folder
	applyLighting()

	-- The Baseplate template's own spawn would sit inside the fountain.
	for _, instance in workspace:GetChildren() do
		if instance:IsA("SpawnLocation") then
			instance.Enabled = false
		end
	end

	local world = Builder.folder(workspace, "World")
	Landscape.build(world, Kingdom.MoatDistance, Kingdom.Sides, Kingdom.GateAngle)
	Town.build(world)
	Kingdom.build(world)
	return world
end

return WorldBuilder
