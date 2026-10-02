-- Arena at the end of the west road: a compact colosseum of reinforced
-- obsidian with glowing gridlines and tiered seating. Brutus the Arena
-- Master stands at the gate between the PvP duel and PvE queue screens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local OUTER_RADIUS = 42
local FLOOR_RADIUS = 30
local WALL_HEIGHT = 20
local SEGMENTS = 24
local CENTER = Vector3.new(0, 0, OUTER_RADIUS + 2)
-- Half-angle of the entrance gap (degrees), centred on the street side.
local ENTRANCE_GAP = 12

local Arena = {}

Arena.Radius = OUTER_RADIUS

-- Calls place(frame, segmentLength) around a circle, skipping the entrance.
-- Each frame sits on the ring with X running along it and -Z facing out.
local function ring(radius: number, gap: number, place: (CFrame, number) -> ())
	local length = 2 * math.pi * radius / SEGMENTS + 0.4
	for i = 0, SEGMENTS - 1 do
		local angle = (i + 0.5) / SEGMENTS * 360
		if math.min(angle, 360 - angle) > gap then
			place(CFrame.new(CENTER) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -radius), length)
		end
	end
end

function Arena.build(folder: Folder, frame: CFrame, color: Color3)
	-- Combat is allowed on the floor (training dummies stand here).
	Builder.landmark("ArenaFloor", (frame * CFrame.new(CENTER + Vector3.new(0, 0.7, 0))).Position)
	Builder.landmark("ArenaRadius", FLOOR_RADIUS)
	Builder.disc(folder, frame, {
		Name = "ArenaGrounds",
		Radius = OUTER_RADIUS + 1,
		Height = 1,
		At = CFrame.new(CENTER + Vector3.new(0, 0.1, 0)),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.disc(folder, frame, {
		Name = "CombatFloor",
		Radius = FLOOR_RADIUS,
		Height = 1,
		At = CFrame.new(CENTER + Vector3.new(0, 0.2, 0)),
		Color = Color3.fromRGB(37, 47, 58),
		Material = Enum.Material.SmoothPlastic,
	})
	-- Cool navigation grid; warm red remains reserved for hostile telegraphs.
	local gridColor = Color3.fromRGB(58, 111, 132)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local fixture = Builder.neon(
			folder,
			frame,
			Vector3.new(3, 0.2, 2),
			CFrame.new(CENTER + Vector3.new(math.cos(angle) * 24, 15, math.sin(angle) * 24)),
			Color3.fromRGB(175, 212, 225)
		)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = Color3.fromRGB(188, 216, 232), 1.4, 38, false
		light.Parent = fixture
	end
	-- Glowing gridlines clipped to the circular floor.
	for offset = -FLOOR_RADIUS + 5, FLOOR_RADIUS - 5, 10 do
		local half = math.sqrt(FLOOR_RADIUS ^ 2 - offset ^ 2) - 0.5
		Builder.neon(
			folder,
			frame,
			Vector3.new(0.12, 0.06, half * 2),
			CFrame.new(CENTER + Vector3.new(offset, 0.72, 0)),
			gridColor
		)
		Builder.neon(
			folder,
			frame,
			Vector3.new(half * 2, 0.06, 0.12),
			CFrame.new(CENTER + Vector3.new(0, 0.72, offset)),
			gridColor
		)
	end
	-- Sits just under the floor surface so only its rim shows.
	Builder.neonBand(folder, frame, CENTER + Vector3.new(0, 0.5, 0), FLOOR_RADIUS, gridColor)

	-- Low podium wall and two tiers of seating.
	ring(FLOOR_RADIUS + 1.5, ENTRANCE_GAP + 8, function(segment, length)
		Builder.part(folder, frame, {
			Name = "PodiumWall",
			Size = Vector3.new(length, 4, 1.5),
			At = segment * CFrame.new(0, 2, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
	end)
	for tier = 0, 1 do
		local height = 5 + tier * 4
		ring(FLOOR_RADIUS + 5 + tier * 4.5, ENTRANCE_GAP + 4, function(segment, length)
			Builder.part(folder, frame, {
				Name = "SeatingTier",
				Size = Vector3.new(length, height, 4.5),
				At = segment * CFrame.new(0, height / 2, 0),
				Color = if tier == 0 then C.DarkStone else C.Stone,
				Material = Enum.Material.Cobblestone,
			})
		end)
	end

	-- Obsidian outer wall with a glowing grid on its outer face.
	ring(OUTER_RADIUS, ENTRANCE_GAP, function(segment, length)
		Builder.part(folder, frame, {
			Name = "OuterWall",
			Size = Vector3.new(length, WALL_HEIGHT, 3),
			At = segment * CFrame.new(0, WALL_HEIGHT / 2, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		Builder.neon(folder, frame, Vector3.new(length, 0.3, 0.2), segment * CFrame.new(0, 12, -1.6), color)
		Builder.neon(
			folder,
			frame,
			Vector3.new(0.3, WALL_HEIGHT - 4, 0.2),
			segment * CFrame.new(0, WALL_HEIGHT / 2, -1.6),
			color
		)
		Builder.part(folder, frame, {
			Name = "Merlon",
			Size = Vector3.new(length / 2, 2.5, 3),
			At = segment * CFrame.new(0, WALL_HEIGHT + 1.25, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
			CastShadow = false,
		})
	end)

	-- Gate towers, lintel and sign.
	local gateHalf = OUTER_RADIUS * math.sin(math.rad(ENTRANCE_GAP))
	local gateZ = CENTER.Z - OUTER_RADIUS * math.cos(math.rad(ENTRANCE_GAP))
	for _, side in { -1, 1 } do
		Builder.pillar(folder, frame, side * (gateHalf + 2), gateZ, WALL_HEIGHT + 6, color, {
			Width = 6,
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
	end
	Builder.part(folder, frame, {
		Name = "GateLintel",
		Size = Vector3.new(gateHalf * 2 + 4, 4, 5),
		At = CFrame.new(0, WALL_HEIGHT - 1, gateZ),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.sign(folder, frame, CFrame.new(0, WALL_HEIGHT - 1, gateZ - 2.8), Vector3.new(12, 2.6, 0.6), "ARENA", color)

	-- Brutus between the two queue screens.
	local queues = {
		{ X = -6, Color = C.Magenta, Text = "PVP DUELS\nCOLLATERAL\n> QUEUE: 0_" },
		{ X = 6, Color = C.Cyan, Text = "PVE COMBAT\n> QUEUE: 0_" },
	}
	for _, queue in queues do
		Builder.part(folder, frame, {
			Name = "QueuePedestal",
			Size = Vector3.new(4, 3, 2.4),
			At = CFrame.new(queue.X, 2, -3),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		Builder.screen(folder, frame, CFrame.new(queue.X, 5.6, -3), Vector3.new(5, 4, 2.4), {
			Name = "QueueScreen",
			Text = queue.Text,
			TextColor = queue.Color,
		})
	end
	Builder.vendor(folder, frame * CFrame.new(0, 0.5, -6), "Arena", Vendors.Arena)
end

return Arena
