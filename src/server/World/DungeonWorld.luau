-- Room geometry is generated server-side and owned by one run.
local Rules = require(game:GetService("ReplicatedStorage").Shared.DungeonRules)
local GemConfig = require(game:GetService("ReplicatedStorage").Shared.GemConfig)
local World = {}
local function block(parent, name, size, at, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end
-- Neutral fixtures reveal material and facial detail without washing out element colors.
local function fillLight(parent, at, range, brightness)
	local fixture =
		block(parent, "CombatFill", Vector3.new(5, 0.25, 2), at, Color3.fromRGB(215, 228, 245), Enum.Material.Neon)
	fixture.CanCollide = false
	fixture.CanTouch = false
	fixture.CanQuery = false
	fixture.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(225, 233, 247)
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = fixture
end
function World.build(id, rooms, origin)
	local folder = Instance.new("Folder")
	folder.Name = "Dungeon_" .. id
	folder.Parent = workspace
	local centers, gates = {}, {}
	local wallColor = Color3.fromRGB(27, 37, 49)
	for i, room in rooms do
		local center = origin + Vector3.new(room.X * Rules.Spacing, 0, room.Z * Rules.Spacing)
		centers[i] = center
		local color = GemConfig.ElementColors[Rules.Roster[room.Theme].Element]
		block(folder, "RoomFloor", Vector3.new(64, 2, 64), center, Color3.fromRGB(65, 74, 88))
		fillLight(folder, center + Vector3.new(-16, 16, 0), 48, 1.7)
		fillLight(folder, center + Vector3.new(16, 16, 0), 48, 1.7)
		local doors = {}
		for _, index in { i - 1, i + 1 } do
			local neighbor = rooms[index]
			if neighbor then
				doors[(neighbor.X - room.X) .. ":" .. (neighbor.Z - room.Z)] = true
			end
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local dx, dz = d[1], d[2]
			if doors[dx .. ":" .. dz] then
				for _, sign in { -1, 1 } do
					local at = center + Vector3.new(dx * 32 + dz * sign * 20, 7, dz * 32 + dx * sign * 20)
					block(
						folder,
						"DoorWall",
						if dx ~= 0 then Vector3.new(2, 14, 24) else Vector3.new(24, 14, 2),
						at,
						wallColor
					)
				end
			else
				block(
					folder,
					"Wall",
					if dx ~= 0 then Vector3.new(2, 14, 64) else Vector3.new(64, 14, 2),
					center + Vector3.new(dx * 32, 7, dz * 32),
					wallColor
				)
			end
		end
		for n = 1, room.Pillars do
			local angle = (n - 1) * math.pi / 2 + math.pi / 4
			local at = center + Vector3.new(math.cos(angle) * 24, 5, math.sin(angle) * 24)
			block(folder, "Pillar", Vector3.new(4, 10, 4), at, wallColor)
			local light = block(
				folder,
				"ElementLamp",
				Vector3.new(4.1, 0.35, 4.1),
				at + Vector3.new(0, 4, 0),
				color,
				Enum.Material.Neon
			)
			local glow = Instance.new("PointLight")
			glow.Color = color
			glow.Range = 35
			glow.Brightness = 1.4
			glow.Shadows = false
			glow.Parent = light
		end
		if i > 1 then
			local previous = centers[i - 1]
			local delta = center - previous
			local midpoint = (center + previous) / 2
			local horizontal = delta.X ~= 0
			fillLight(folder, midpoint + Vector3.new(0, 11, 0), 30, 1.4)
			block(
				folder,
				"Corridor",
				if horizontal then Vector3.new(30, 2, 16) else Vector3.new(16, 2, 30),
				midpoint,
				wallColor
			)
			for _, sign in { -1, 1 } do
				block(
					folder,
					"CorridorWall",
					if horizontal then Vector3.new(30, 12, 2) else Vector3.new(2, 12, 30),
					midpoint + Vector3.new(if horizontal then 0 else sign * 9, 6, if horizontal then sign * 9 else 0),
					wallColor
				)
			end
			local gate = block(
				folder,
				"SealedGate",
				if horizontal then Vector3.new(2, 14, 16) else Vector3.new(16, 14, 2),
				midpoint + Vector3.new(0, 7, 0),
				color,
				Enum.Material.Neon
			)
			gate.Transparency = 0.35
			gates[i - 1] = gate
		end
	end
	return { Folder = folder, Centers = centers, Gates = gates }
end
return World
