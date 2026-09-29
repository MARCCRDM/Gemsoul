-- Zone 5: Arena Building.
-- A massive colosseum of reinforced obsidian with glowing gridlines, tiered
-- seating around a gridded combat floor, and two digital queues outside the
-- gate: PvP collateral duels and PvE combat.
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local OUTER_RADIUS = 72
local FLOOR_RADIUS = 40
local WALL_HEIGHT = 30
local CENTER = Vector3.new(0, 0, OUTER_RADIUS + 8)
-- Half-angle of the entrance gap (degrees), centred on the side facing the plaza.
local ENTRANCE_GAP = 11

local Arena = {}

-- Area the zone occupies in its local space, kept clear of trees and flowers.
Arena.Footprint = { MinX = -80, MaxX = 80, MinZ = -14, MaxZ = 158 }

-- Calls place(frame, segmentLength) around a circle, skipping the entrance.
-- Each frame sits on the ring with its X axis running along the circle.
local function ring(radius: number, count: number, gap: number, place: (CFrame, number) -> ())
	local length = 2 * math.pi * radius / count + 0.4
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * 360
		local fromFront = math.min(angle, 360 - angle)
		if fromFront > gap then
			place(CFrame.new(CENTER) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -radius), length)
		end
	end
end

local function floor(folder: Folder, origin: CFrame, color: Color3)
	Builder.disc(folder, origin, {
		Name = "ArenaGrounds",
		Radius = OUTER_RADIUS + 2,
		At = CFrame.new(CENTER + Vector3.new(0, -0.45, 0)),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.part(folder, origin, {
		Name = "EntranceFloor",
		Size = Vector3.new(26, 1, 12),
		At = CFrame.new(0, -0.5, 4),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.disc(folder, origin, {
		Name = "CombatFloor",
		Radius = FLOOR_RADIUS + 2,
		At = CFrame.new(CENTER + Vector3.new(0, -0.4, 0)),
		Color = Color3.fromRGB(30, 28, 38),
		Material = Enum.Material.SmoothPlastic,
	})

	-- Glowing gridlines clipped to the circular floor.
	for offset = -FLOOR_RADIUS + 4, FLOOR_RADIUS - 4, 8 do
		local half = math.sqrt(FLOOR_RADIUS ^ 2 - offset ^ 2)
		Builder.neon(
			folder,
			origin,
			Vector3.new(0.3, 0.1, half * 2),
			CFrame.new(CENTER + Vector3.new(offset, 0.15, 0)),
			color
		)
		Builder.neon(
			folder,
			origin,
			Vector3.new(half * 2, 0.1, 0.3),
			CFrame.new(CENTER + Vector3.new(0, 0.15, offset)),
			color
		)
	end
	Builder.neonRing(folder, origin, CENTER + Vector3.new(0, 0.2, 0), FLOOR_RADIUS, 32, color, 0.5)
	Builder.neonRing(folder, origin, CENTER + Vector3.new(0, 0.2, 0), 10, 24, C.Cyan, 0.5)
end

local function stands(folder: Folder, origin: CFrame, color: Color3)
	-- Podium wall around the combat floor.
	ring(FLOOR_RADIUS + 2.5, 40, ENTRANCE_GAP + 5, function(frame, length)
		Builder.part(folder, origin, {
			Name = "PodiumWall",
			Size = Vector3.new(length, 5, 1.5),
			At = frame * CFrame.new(0, 2.5, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		Builder.neon(folder, origin, Vector3.new(length, 0.3, 1.7), frame * CFrame.new(0, 4.6, 0), C.Cyan)
	end)

	-- Stepped seating tiers rising toward the outer wall.
	for tier = 0, 3 do
		local radius = FLOOR_RADIUS + 7 + tier * 6
		local height = 6 + tier * 4
		ring(radius, 40, ENTRANCE_GAP + 3, function(frame, length)
			Builder.part(folder, origin, {
				Name = "SeatingTier",
				Size = Vector3.new(length, height, 6),
				At = frame * CFrame.new(0, height / 2, 0),
				Color = if tier % 2 == 0 then C.DarkStone else C.Stone,
				Material = Enum.Material.Cobblestone,
			})
			Builder.neon(
				folder,
				origin,
				Vector3.new(length, 0.2, 0.3),
				frame * CFrame.new(0, height + 0.05, 3.05),
				color
			)
		end)
	end
end

local function outerWall(folder: Folder, origin: CFrame, color: Color3)
	ring(OUTER_RADIUS, 48, ENTRANCE_GAP, function(frame, length)
		Builder.part(folder, origin, {
			Name = "OuterWall",
			Size = Vector3.new(length, WALL_HEIGHT, 4),
			At = frame * CFrame.new(0, WALL_HEIGHT / 2, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		-- Glowing gridlines on the outer face.
		Builder.neon(folder, origin, Vector3.new(length, 0.3, 0.2), frame * CFrame.new(0, 16, -2.1), color)
		Builder.neon(
			folder,
			origin,
			Vector3.new(0.3, WALL_HEIGHT - 4, 0.2),
			frame * CFrame.new(0, WALL_HEIGHT / 2, -2.1),
			color
		)
		Builder.part(folder, origin, {
			Name = "Merlon",
			Size = Vector3.new(length / 2, 3, 4),
			At = frame * CFrame.new(0, WALL_HEIGHT + 1.5, 0),
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
	end)

	-- Floodlight housings on the rim, aimed at the combat floor.
	for _, angle in { 45, 135, 225, 315 } do
		local position = (CFrame.new(CENTER) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(
			0,
			WALL_HEIGHT + 4,
			-OUTER_RADIUS
		)).Position
		Builder.part(folder, origin, {
			Name = "Floodlight",
			Size = Vector3.new(4, 2, 1),
			At = CFrame.lookAt(position, CENTER),
			Color = C.Chrome,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
end

local function gatehouse(folder: Folder, origin: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		Builder.pillar(folder, origin, side * 15, 9, WALL_HEIGHT + 8, color, {
			Width = 8,
			Color = C.Obsidian,
			Material = Enum.Material.Basalt,
		})
		Builder.torch(folder, origin, CFrame.new(side * 15, 10, 4.4), color)
	end
	Builder.part(folder, origin, {
		Name = "GateLintel",
		Size = Vector3.new(24, 6, 6),
		At = CFrame.new(0, WALL_HEIGHT - 1, 9),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.sign(
		folder,
		origin,
		CFrame.new(0, WALL_HEIGHT - 1, 5.7),
		Vector3.new(18, 4, 0.6),
		"ARENA // COLOSSEUM",
		color
	)
end

local function queueTerminal(
	folder: Folder,
	origin: CFrame,
	x: number,
	tag: string,
	color: Color3,
	title: string,
	action: string
)
	local z = -6
	local pad = Builder.disc(folder, origin, {
		Name = tag,
		Radius = 5,
		Height = 0.4,
		At = CFrame.new(x, 0.2, z),
		Color = C.Iron,
		Material = Enum.Material.DiamondPlate,
		Tag = tag,
	})
	Builder.neonBand(folder, origin, Vector3.new(x, 0.15, z), 5.25, color)
	Builder.part(folder, origin, {
		Name = "TerminalPedestal",
		Size = Vector3.new(6, 4, 3),
		At = CFrame.new(x, 2, z + 7),
		Color = C.Obsidian,
		Material = Enum.Material.Basalt,
	})
	Builder.screen(folder, origin, CFrame.new(x, 6.5, z + 7), Vector3.new(7, 5, 3), {
		Name = "QueueScreen",
		Text = title .. "\n> QUEUE: 0_",
		TextColor = color,
	})
	Builder.prompt(pad, action, title)
end

function Arena.build(folder: Folder, origin: CFrame, color: Color3)
	floor(folder, origin, color)
	stands(folder, origin, color)
	outerWall(folder, origin, color)
	gatehouse(folder, origin, color)
	queueTerminal(folder, origin, -24, Tags.PvPQueue, C.Magenta, "PVP DUELS\nCOLLATERAL", "Join Duel Queue")
	queueTerminal(folder, origin, 24, Tags.PvETerminal, C.Cyan, "PVE COMBAT", "Start PvE")
end

return Arena
