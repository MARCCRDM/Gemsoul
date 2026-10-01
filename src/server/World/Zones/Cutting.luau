-- Ilsa's gem-cutting stall beside the Mining Guild, so fresh stones go
-- straight from the quarry to the bench: a stone bench under a canvas
-- awning with floating holographic displays (the manual QTE cutting
-- station) and a compact laser cutter, in front of a low wall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local Cutting = {}

-- Footprint along the street and back from it, for the town's lot.
Cutting.Width = 12
Cutting.Depth = 16

local function workbench(folder: Folder, frame: CFrame, color: Color3)
	-- Canvas awning over the bench.
	Builder.part(folder, frame, {
		Name = "Awning",
		Size = Vector3.new(11.5, 0.4, 6),
		At = CFrame.new(0, 9.3, -3) * CFrame.Angles(math.rad(12), 0, 0),
		Color = Color3.fromRGB(150, 90, 40),
		Material = Enum.Material.Fabric,
	})
	local bench = Builder.part(folder, frame, {
		Name = "Workbench",
		Size = Vector3.new(9, 1.4, 3.6),
		At = CFrame.new(0, 3.7, -3),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	Builder.station(bench, "Cutting", "Inspect Gems", "Gem Scanner", "Pouch")
	for _, x in { -3.8, 3.8 } do
		Builder.part(folder, frame, {
			Name = "BenchLeg",
			Size = Vector3.new(2, 3, 3),
			At = CFrame.new(x, 1.5, -3),
			Color = C.Stone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.neon(folder, frame, Vector3.new(9.2, 0.2, 3.8), CFrame.new(0, 3.05, -3), color)
	Builder.neon(
		folder,
		frame,
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(0, 5, -3) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		nil,
		Tags.Spin
	)

	-- Holographic displays facing the street.
	local displays = {
		{ X = -3.6, Yaw = 15, Size = Vector3.new(2.8, 2, 0.15), Text = "ANGLE\n42 DEG" },
		{ X = 0, Yaw = 0, Size = Vector3.new(3.6, 2.4, 0.15), Text = "QTE CUT\nREADY" },
		{ X = 3.6, Yaw = -15, Size = Vector3.new(2.8, 2, 0.15), Text = "CLARITY\n--%" },
	}
	for _, display in displays do
		Builder.holo(
			folder,
			frame,
			CFrame.new(display.X, 6.6, -2.2) * CFrame.Angles(0, math.rad(display.Yaw), 0),
			display.Size,
			color,
			display.Text
		)
	end
end

local function laserCutter(folder: Folder, frame: CFrame)
	local base = Builder.part(folder, frame, {
		Name = "LaserBase",
		Size = Vector3.new(4, 2.5, 3.4),
		At = CFrame.new(0, 1.25, 0),
		Color = C.Chrome,
		Material = Enum.Material.DiamondPlate,
	})
	Builder.station(base, "Cutting", "Inspect Gems", "Facet Analyzer", "Pouch")
	Builder.part(folder, frame, {
		Name = "LaserChamber",
		Size = Vector3.new(3.6, 3.4, 3),
		At = CFrame.new(0, 4.2, 0),
		Color = Color3.fromRGB(180, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		CanCollide = false,
	})
	Builder.part(folder, frame, {
		Name = "LaserHead",
		Size = Vector3.new(4, 1.2, 3.4),
		At = CFrame.new(0, 6.5, 0),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	Builder.neon(folder, frame, Vector3.new(0.2, 3.2, 0.2), CFrame.new(0, 4.2, 0), C.Red, nil, Tags.Laser)
	Builder.screen(folder, frame, CFrame.new(0, 8.6, 0), Vector3.new(3.6, 2.4, 1.8), {
		Name = "LaserScreen",
		Text = "LASER\nT1-T3",
		TextColor = C.Amber,
	})
end

function Cutting.build(folder: Folder, frame: CFrame, color: Color3)
	Builder.part(folder, frame, {
		Name = "StallFloor",
		Size = Vector3.new(Cutting.Width, 0.3, Cutting.Depth),
		At = CFrame.new(0, 0.65, Cutting.Depth / 2 - 2),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	Builder.part(folder, frame, {
		Name = "StallWall",
		Size = Vector3.new(Cutting.Width, 7, 1),
		At = CFrame.new(0, 4, Cutting.Depth - 2),
		Color = C.Stone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.sign(folder, frame, CFrame.new(0, 9.2, Cutting.Depth - 2.4), Vector3.new(9, 2, 0.5), "GEM ANALYSIS", color)
	-- The hand-cutting bench out front, the laser behind it to one side.
	workbench(folder, frame * CFrame.new(0, 0.5, 4), color)
	laserCutter(folder, frame * CFrame.new(3.2, 0.5, 10))
	Builder.vendor(folder, frame * CFrame.new(-3.8, 0.5, -1), "Cutting", Vendors.Cutting)
end

return Cutting
