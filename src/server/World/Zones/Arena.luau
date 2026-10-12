-- Corundum Arena: sapphire architecture around the original unobstructed fight floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Config = require(ReplicatedStorage.Shared.Config)
local Builder = require(script.Parent.Parent.Builder)
local OUTER_RADIUS, FLOOR_RADIUS, WALL_HEIGHT = 42, 30, 20
local SEGMENTS, ENTRANCE_GAP = 24, 12
local CENTER = Vector3.new(0, 0, OUTER_RADIUS + 2)
local P = {
	Floor = Color3.fromRGB(44, 65, 88),
	Inlay = Color3.fromRGB(66, 92, 116),
	Deep = Color3.fromRGB(29, 58, 100),
	Stone = Color3.fromRGB(118, 177, 216),
	Crystal = Color3.fromRGB(112, 187, 245),
	Pale = Color3.fromRGB(211, 242, 255),
	Glow = Color3.fromRGB(118, 215, 245),
	Gold = Color3.fromRGB(225, 185, 107),
	Metal = Color3.fromRGB(50, 70, 94),
}
local Arena = { Radius = OUTER_RADIUS }
local function ring(radius, gap, place)
	local length = 2 * math.pi * radius / SEGMENTS + 0.4
	for i = 0, SEGMENTS - 1 do
		local angle = (i + 0.5) / SEGMENTS * 360
		if math.min(angle, 360 - angle) > gap then
			place(CFrame.new(CENTER) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -radius), length, i)
		end
	end
end
-- Scenery cannot intercept combat rays, block movement or push the camera.
local function art(parent, frame, name, at, size, color, material, transparency, class)
	local p = Builder.part(parent, frame, {
		Name = name,
		At = at,
		Size = size,
		Color = color,
		Material = material,
		Transparency = transparency or 0,
		Class = class,
		CanCollide = false,
		CastShadow = false,
	})
	p.CanQuery, p.CanTouch = false, false
	return p
end
-- Broad bodies fade from solid sapphire into clear, short faceted terminations.
local function crystal(parent, frame, width, height, tint, termination)
	local tip = height * (termination or 0.3)
	local shaft = height - tip
	for band = 0, 2 do
		local t = band / 2
		local p = art(
			parent,
			frame,
			"SapphireBody",
			CFrame.new(0, shaft * (band + 0.5) / 3, 0),
			Vector3.new(width, shaft / 3, width),
			P.Stone:Lerp(tint, t),
			Enum.Material.Glass,
			t * 0.32
		)
		p.Reflectance = 0.06
	end
	for i = 0, 3 do
		local p = art(
			parent,
			frame,
			"SapphireFacet",
			CFrame.Angles(0, i * math.pi / 2, 0)
				* CFrame.new(width / 4, height - tip / 2, width / 4)
				* CFrame.Angles(0, math.pi, 0),
			Vector3.new(width / 2, tip, width / 2),
			tint:Lerp(P.Pale, 0.12 + i * 0.08),
			Enum.Material.Glass,
			0.24 + (i % 2) * 0.08,
			"CornerWedgePart"
		)
		p.Reflectance = 0.08
	end
end
local function band(parent, frame, radius, y, width, color, material, count)
	for i = 0, count - 1 do
		art(
			parent,
			frame,
			"InlaidRing",
			CFrame.Angles(0, i / count * math.pi * 2, 0) * CFrame.new(0, y, -radius),
			Vector3.new(2 * radius * math.tan(math.pi / count) + 0.02, 0.035, width),
			color,
			material
		)
	end
end
function Arena.build(folder: Folder, frame: CFrame, _color: Color3)
	folder:SetAttribute("Landscape", "Corundum Arena")
	-- Keep server bounds and all existing fighter/duel insertion coordinates unchanged.
	Builder.landmark("ArenaFloor", (frame * CFrame.new(CENTER + Vector3.new(0, 0.7, 0))).Position)
	Builder.landmark("ArenaRadius", FLOOR_RADIUS)
	local centre = frame * CFrame.new(CENTER)
	local floor = Builder.folder(folder, "FightingFloor")
	local architecture = Builder.folder(folder, "SapphireColosseum")
	local details = Builder.folder(folder, "CrystalArt")
	Builder.disc(
		floor,
		centre,
		{
			Name = "ArenaGrounds",
			Radius = 43,
			Height = 1,
			At = CFrame.new(0, 0.1, 0),
			Color = P.Deep,
			Material = Enum.Material.Marble,
		}
	)
	Builder.disc(floor, centre, {
		Name = "CombatFloor",
		Radius = FLOOR_RADIUS,
		Height = 1,
		At = CFrame.new(0, 0.2, 0),
		Color = P.Floor,
		Material = Enum.Material.SmoothPlastic,
	})
	-- Opaque, level floor at y=0.7; a quiet emblem instead of a bright grid.
	band(floor, centre, 28.9, 0.722, 0.18, P.Stone, Enum.Material.SmoothPlastic, 48)
	band(floor, centre, 7, 0.724, 0.12, P.Inlay, Enum.Material.SmoothPlastic, 24)
	for i = 0, 7 do
		local bearing = CFrame.Angles(0, i * math.pi / 4, 0)
		art(
			floor,
			centre,
			"CompassInlay",
			bearing * CFrame.new(0, 0.724, -3),
			Vector3.new(0.13, 0.035, 5),
			P.Inlay,
			Enum.Material.SmoothPlastic
		)
		art(
			floor,
			centre,
			"BoundaryTick",
			bearing * CFrame.new(0, 0.724, -27.9),
			Vector3.new(0.25, 0.035, 1.1),
			P.Stone,
			Enum.Material.SmoothPlastic
		)
	end
	-- Preserve the podium, seats and outer wall collision footprints.
	ring(31.5, ENTRANCE_GAP + 8, function(segment, length)
		Builder.part(architecture, frame, {
			Name = "PodiumWall",
			Size = Vector3.new(length, 4, 1.5),
			At = segment * CFrame.new(0, 2, 0),
			Color = P.Deep,
			Material = Enum.Material.Marble,
		})
		art(
			details,
			frame,
			"PodiumInlay",
			segment * CFrame.new(0, 3.5, 0.77),
			Vector3.new(length - 0.5, 0.12, 0.06),
			P.Glow,
			Enum.Material.Neon
		)
	end)
	for tier = 0, 1 do
		local height = 5 + tier * 4
		ring(FLOOR_RADIUS + 5 + tier * 4.5, ENTRANCE_GAP + 4, function(segment, length)
			Builder.part(architecture, frame, {
				Name = "SeatingTier",
				Size = Vector3.new(length, height, 4.5),
				At = segment * CFrame.new(0, height / 2, 0),
				Color = if tier == 0 then P.Deep else P.Stone,
				Material = Enum.Material.Marble,
			})
			art(
				details,
				frame,
				"SeatCushion",
				segment * CFrame.new(0, height + 0.08, 0),
				Vector3.new(length - 0.5, 0.16, 2.4),
				P.Metal,
				Enum.Material.SmoothPlastic
			)
			art(
				details,
				frame,
				"TerraceTrim",
				segment * CFrame.new(0, height - 0.4, 2.28),
				Vector3.new(length - 0.4, 0.16, 0.08),
				P.Gold,
				Enum.Material.Metal
			)
		end)
	end
	ring(OUTER_RADIUS, ENTRANCE_GAP, function(segment, length, index)
		Builder.part(architecture, frame, {
			Name = "OuterWallBase",
			Size = Vector3.new(length, 11, 3),
			At = segment * CFrame.new(0, 5.5, 0),
			Color = P.Stone,
			Material = Enum.Material.Marble,
		})
		Builder.part(architecture, frame, {
			Name = "OuterCrystalWall",
			Size = Vector3.new(length, 9, 3),
			At = segment * CFrame.new(0, 15.5, 0),
			Color = P.Crystal,
			Material = Enum.Material.Glass,
			Transparency = 0.18,
			CastShadow = false,
		})
		art(
			details,
			frame,
			"WallCoping",
			segment * CFrame.new(0, WALL_HEIGHT + 0.35, 0),
			Vector3.new(length + 0.15, 0.7, 3.5),
			P.Deep,
			Enum.Material.Marble
		)
		art(
			details,
			frame,
			"CopingLight",
			segment * CFrame.new(0, WALL_HEIGHT + 0.76, 0),
			Vector3.new(length - 0.4, 0.12, 0.3),
			P.Glow,
			Enum.Material.Neon
		)
		if index % 3 == 1 then
			crystal(details, frame * segment * CFrame.new(0, 8, -3), 5, 19, P.Crystal)
			art(
				details,
				frame,
				"SapphireBanner",
				segment * CFrame.new(0, 15.5, 1.58),
				Vector3.new(3.5, 6, 0.12),
				P.Deep,
				Enum.Material.SmoothPlastic
			)
			art(
				details,
				frame,
				"BannerCrest",
				segment * CFrame.new(0, 15.5, 1.7) * CFrame.Angles(0, 0, math.pi / 4),
				Vector3.new(1.15, 1.15, 0.1),
				P.Gold,
				Enum.Material.Metal
			)
		end
	end)
	-- Four integrated lamps outside the fight floor; the central insertion sky stays open.
	for i = 0, 3 do
		local tower = centre * CFrame.Angles(0, i * math.pi / 2 + math.pi / 4, 0) * CFrame.new(0, 0, -36)
		art(
			details,
			tower,
			"LampBracket",
			CFrame.new(0, 12, 0),
			Vector3.new(1.5, 11, 1.5),
			P.Metal,
			Enum.Material.Metal
		)
		local fixture = art(
			details,
			tower,
			"ArenaLamp",
			CFrame.new(0, 17.5, 0),
			Vector3.new(2.4, 1, 2.4),
			P.Pale,
			Enum.Material.Neon
		)
		Builder.light(fixture, P.Pale, 60, 1.5)
	end
	local gateHalf = OUTER_RADIUS * math.sin(math.rad(ENTRANCE_GAP))
	local gateZ = CENTER.Z - OUTER_RADIUS * math.cos(math.rad(ENTRANCE_GAP))
	for _, side in { -1, 1 } do
		local gateAt = frame * CFrame.new(side * (gateHalf + 2), 0, gateZ)
		Builder.part(architecture, gateAt, {
			Name = "GatePillar",
			Size = Vector3.new(6, 26, 6),
			At = CFrame.new(0, 13, 0),
			Color = P.Deep,
			Material = Enum.Material.Marble,
		})
		crystal(details, gateAt * CFrame.new(0, 22, 0), 6.5, 10, P.Pale)
		art(
			details,
			gateAt,
			"GateLight",
			CFrame.new(0, 12, -3.05),
			Vector3.new(0.4, 19, 0.12),
			P.Glow,
			Enum.Material.Neon
		)
	end
	Builder.part(architecture, frame, {
		Name = "GateLintel",
		Size = Vector3.new(gateHalf * 2 + 4, 4, 5),
		At = CFrame.new(0, WALL_HEIGHT - 1, gateZ),
		Color = P.Deep,
		Material = Enum.Material.Marble,
	})
	Builder.sign(
		architecture,
		frame,
		CFrame.new(0, WALL_HEIGHT - 1, gateZ - 2.8),
		Vector3.new(18, 2.6, 0.6),
		"CORUNDUM ARENA",
		P.Pale
	)
	local crest = centre * CFrame.new(0, 26, 44)
	crystal(details, crest, 5, 6, P.Pale, 0.7)
	crystal(details, crest * CFrame.Angles(math.pi, 0, 0), 5, 6, P.Crystal, 0.7)
	band(details, crest * CFrame.Angles(math.pi / 2, 0, 0), 7.5, 0, 0.25, P.Gold, Enum.Material.Metal, 24)
	-- Standalone arena only: avoid covering neighboring buildings in town mode.
	if Config.MenuOnly then
		local skyline = Builder.folder(folder, "SapphireSkyline")
		crystal(
			skyline,
			centre * CFrame.new(0, -0.5, 0) * CFrame.Angles(math.pi, math.pi / 8, 0),
			58,
			32,
			P.Crystal,
			0.8
		)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			crystal(
				skyline,
				centre * CFrame.new(math.cos(a) * 26, -0.5, math.sin(a) * 26) * CFrame.Angles(math.pi, a, 0),
				26,
				19,
				P.Crystal:Lerp(P.Pale, i % 3 * 0.08),
				0.65
			)
		end
		for i = 0, 4 do
			local a = (i + 0.45) / 5 * math.pi * 2
			local shelf = centre * CFrame.new(math.cos(a) * 124, 8 + i % 3 * 11, math.sin(a) * 124)
			local cap = Builder.disc(skyline, shelf, {
				Name = "FloatingSapphireShelf",
				Radius = 13,
				Height = 2,
				Color = P.Stone,
				Material = Enum.Material.Glass,
				CanCollide = false,
				CastShadow = false,
			})
			cap.CanQuery, cap.CanTouch = false, false
			crystal(skyline, shelf * CFrame.new(0, -1, 0) * CFrame.Angles(math.pi, a, 0), 23, 23, P.Crystal, 0.8)
			crystal(skyline, shelf * CFrame.new(0, 1, 0) * CFrame.Angles(0, a, 0), 9, 17, P.Pale)
		end
		Builder.part(architecture, frame, {
			Name = "ArenaApproach",
			Size = Vector3.new(28, 1, 16),
			At = CFrame.new(0, 0, -2),
			Color = P.Deep,
			Material = Enum.Material.Marble,
		})
	end
	-- Existing vendor and queue screens retain their interactions.
	for _, queue in
		{
			{ X = -6, Color = P.Gold, Text = "PVP DUELS\nCHOOSE YOUR MATCH" },
			{ X = 6, Color = P.Glow, Text = "PVE COMBAT\nTRAIN & CHALLENGE" },
		}
	do
		Builder.part(architecture, frame, {
			Name = "QueuePedestal",
			Size = Vector3.new(4, 3, 2.4),
			At = CFrame.new(queue.X, 2, -3),
			Color = P.Deep,
			Material = Enum.Material.Marble,
		})
		Builder.screen(
			architecture,
			frame,
			CFrame.new(queue.X, 5.6, -3),
			Vector3.new(5, 4, 2.4),
			{ Name = "QueueScreen", Text = queue.Text, TextColor = queue.Color }
		)
	end
	Builder.vendor(folder, frame * CFrame.new(0, 0.5, -6), "Arena", Vendors.Arena)
end
return Arena
