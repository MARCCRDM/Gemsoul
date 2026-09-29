-- Centre of the town square: the CRT obelisk standing in a fountain, with
-- benches, flower beds and the spawn point around it.
local Builder = require(script.Parent.Builder)

local C = Builder.Colors

local GROUND = 0.5

local Hub = {}

-- Frame whose -Z axis points outward at `angle` degrees (0 = north, clockwise).
function Hub.radial(angle: number): CFrame
	return CFrame.Angles(0, -math.rad(angle), 0)
end

local function obelisk(folder: Folder)
	local o = CFrame.new(0, GROUND, 0)
	for i, size in { 9, 6.5 } do
		Builder.part(folder, o, {
			Name = "ObeliskStep",
			Size = Vector3.new(size, 1.2, size),
			At = CFrame.new(0, i * 1.2 - 0.4, 0),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.part(folder, o, {
		Name = "Obelisk",
		Size = Vector3.new(4, 16, 4),
		At = CFrame.new(0, 10.4, 0),
		Color = C.Stone,
		Material = Enum.Material.Slate,
	})
	Builder.part(folder, o, {
		Name = "ObeliskCap",
		Size = Vector3.new(3, 3, 3),
		At = CFrame.new(0, 19.4, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	local crystal = Builder.neon(
		folder,
		o,
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(0, 23.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		nil,
		"Spin"
	)
	crystal.Name = "SoulCrystal"

	-- One screen per side: south (facing the spawn), north, west and east.
	local screens = {
		{ Yaw = 180, Text = "GEMSOUL\n> WELCOME_" },
		{ Yaw = 0, Text = "MINE\n> NORTH ROAD_" },
		{ Yaw = 90, Text = "ARENA\n> WEST ROAD_" },
		{ Yaw = 270, Text = "ARCANUM\n> EAST ROAD_" },
	}
	for _, screen in screens do
		Builder.screen(
			folder,
			o * CFrame.Angles(0, math.rad(screen.Yaw), 0),
			CFrame.new(0, 8, -3.2),
			Vector3.new(4.6, 3.4, 2.4),
			{ Name = "ObeliskScreen", Text = screen.Text }
		)
	end
end

local function fountain(folder: Folder)
	local o = CFrame.new(0, GROUND, 0)
	local radius, count = 10, 20
	local segment = 2 * math.pi * radius / count + 0.3
	for i = 0, count - 1 do
		Builder.part(folder, o, {
			Name = "FountainRim",
			Size = Vector3.new(segment, 2, 1.5),
			At = CFrame.Angles(0, i / count * 2 * math.pi, 0) * CFrame.new(0, 1, -radius),
			Color = C.WornStone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.disc(folder, o, {
		Name = "FountainWater",
		Radius = radius - 0.5,
		Height = 1,
		At = CFrame.new(0, 0.9, 0),
		Color = Color3.fromRGB(70, 160, 210),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		CastShadow = false,
	})
end

function Hub.build(parent: Instance): Folder
	local folder = Builder.folder(parent, "Square")
	obelisk(folder)
	fountain(folder)

	local spawn = Builder.part(folder, CFrame.identity, {
		Class = "SpawnLocation",
		Name = "TownSpawn",
		Size = Vector3.new(8, 1, 8),
		At = CFrame.new(0, 0.62, 20),
		Color = C.Cyan,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	}) :: SpawnLocation
	spawn.Duration = 0

	-- Benches facing the fountain and flower beds behind them, on the diagonals.
	local rng = Random.new(7)
	for _, angle in { 45, 135, 225, 315 } do
		local frame = Hub.radial(angle) * CFrame.new(0, GROUND, 0)
		Builder.bench(folder, frame, CFrame.new(0, 0, -15) * CFrame.Angles(0, math.pi, 0))
		Builder.planter(folder, frame, CFrame.new(0, 0, -19), 8, rng)
	end

	return folder
end

return Hub
