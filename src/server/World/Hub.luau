-- Town hub: the central plaza with the CRT obelisk, spawn point, street
-- lamps, and neon-edged roads leading out to each zone's gate.
local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local Hub = {}

Hub.PlazaRadius = 45

-- Frame whose -Z axis points outward toward the zone at `angle` degrees.
function Hub.radial(angle: number): CFrame
	return CFrame.Angles(0, -math.rad(angle), 0)
end

local function obelisk(folder: Folder)
	local o = CFrame.identity
	for i, size in { 16, 12, 8 } do
		Builder.part(folder, o, {
			Name = "ObeliskStep",
			Size = Vector3.new(size, 1, size),
			At = CFrame.new(0, 0.6 + i, 0),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.part(folder, o, {
		Name = "Obelisk",
		Size = Vector3.new(5, 26, 5),
		At = CFrame.new(0, 16.5, 0),
		Color = C.Stone,
		Material = Enum.Material.Slate,
	})
	Builder.part(folder, o, {
		Name = "ObeliskCap",
		Size = Vector3.new(4, 4, 4),
		At = CFrame.new(0, 30.5, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	local crystal = Builder.neon(
		folder,
		o,
		Vector3.new(3, 3, 3),
		CFrame.new(0, 36, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		nil,
		"Spin"
	)
	crystal.Name = "SoulCrystal"
	Builder.neonRing(folder, o, Vector3.new(0, 33.5, 0), 4, 12, C.Magenta, 0.3)

	local messages = {
		"GEMSOUL\n> SYSTEM ONLINE_",
		"WELCOME, MINER\n> FOLLOW THE LIGHTS_",
		"TOWN HUB\n> 5 ZONES ACTIVE_",
		"SOUL NET v1.0\n> ALL SYSTEMS NOMINAL_",
	}
	for i, text in messages do
		Builder.screen(
			folder,
			CFrame.Angles(0, math.rad(90 * i), 0),
			CFrame.new(0, 9, -3.9),
			Vector3.new(6, 4.5, 2.8),
			{ Name = "ObeliskScreen", Text = text }
		)
	end
end

-- Round fountain pool around the obelisk steps.
local function fountain(folder: Folder)
	local radius, count = 12, 24
	local segment = 2 * math.pi * radius / count + 0.3
	for i = 0, count - 1 do
		Builder.part(folder, CFrame.identity, {
			Name = "FountainRim",
			Size = Vector3.new(segment, 2, 1.5),
			At = CFrame.Angles(0, i / count * 2 * math.pi, 0) * CFrame.new(0, 2.1, -radius),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.disc(folder, CFrame.identity, {
		Name = "FountainWater",
		Radius = radius - 0.5,
		Height = 1.2,
		At = CFrame.new(0, 1.9, 0),
		Color = Color3.fromRGB(70, 160, 210),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
end

function Hub.road(folder: Instance, zone, distance: number)
	local frame = Hub.radial(zone.Angle)
	local length = distance - Hub.PlazaRadius
	local mid = Hub.PlazaRadius + length / 2

	Builder.part(folder, frame, {
		Name = zone.Name .. "Road",
		Size = Vector3.new(14, 1, length),
		At = CFrame.new(0, 0.5, -mid),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	for _, side in { -1, 1 } do
		Builder.neon(folder, frame, Vector3.new(0.4, 0.2, length), CFrame.new(side * 7.2, 1.05, -mid), zone.Color)
	end

	-- Gate arch at the plaza edge, sign facing the plaza.
	local archZ = -(Hub.PlazaRadius + 3)
	for _, side in { -1, 1 } do
		Builder.pillar(folder, frame * CFrame.new(0, 1, 0), side * 9, archZ, 14, zone.Color)
	end
	Builder.part(folder, frame, {
		Name = "ArchBeam",
		Size = Vector3.new(22, 2, 3),
		At = CFrame.new(0, 16, archZ),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.sign(
		folder,
		frame,
		CFrame.new(0, 18.5, archZ) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(16, 3, 0.6),
		zone.Title,
		zone.Color
	)
end

function Hub.build(parent: Instance, zones, distance: number, gateAngle: number): Folder
	local folder = Builder.folder(parent, "Hub")
	local o = CFrame.identity

	Builder.disc(folder, o, {
		Name = "Plaza",
		Radius = Hub.PlazaRadius,
		Height = 1.2,
		At = CFrame.new(0, 0.5, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.neonRing(folder, o, Vector3.new(0, 1.15, 0), Hub.PlazaRadius - 1, 32, C.Cyan)
	Builder.neonRing(folder, o, Vector3.new(0, 1.15, 0), 14, 20, C.Magenta, 0.4)

	obelisk(folder)
	fountain(folder)

	local spawn = Builder.part(folder, o, {
		Class = "SpawnLocation",
		Name = "TownSpawn",
		Size = Vector3.new(8, 1, 8),
		At = CFrame.new(0, 0.65, 22),
		Color = C.Cyan,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	}) :: SpawnLocation
	spawn.Duration = 0

	local rng = Random.new(7)
	for _, zone in zones do
		Hub.road(folder, zone, distance)

		-- A lamp, flower bed and bench between each pair of roads, except
		-- where the avenue to the main gate leaves the plaza.
		local between = (zone.Angle + 36) % 360
		if between ~= gateAngle then
			local frame = Hub.radial(between)
			Builder.lamp(folder, frame * CFrame.new(0, 1.1, -(Hub.PlazaRadius - 5)), 0, 0, C.Amber)
			Builder.planter(folder, frame, CFrame.new(0, 1.1, -30), 10, rng)
			Builder.bench(folder, frame, CFrame.new(0, 1.1, -24) * CFrame.Angles(0, math.pi, 0))
		end
	end

	return folder
end

return Hub
