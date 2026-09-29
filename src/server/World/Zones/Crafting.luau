-- Crafting & Cutting workshop on the north road. Master Gemcutter Ilsa works
-- out front at a heavy stone bench fitted with floating holographic displays
-- (the manual QTE cutting station), next to a compact laser cutter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local Crafting = {}

local function workbench(folder: Folder, frame: CFrame, color: Color3)
	-- Canvas awning over the bench.
	Builder.part(folder, frame, {
		Name = "Awning",
		Size = Vector3.new(13, 0.4, 6),
		At = CFrame.new(0, 9.3, -3) * CFrame.Angles(math.rad(12), 0, 0),
		Color = Color3.fromRGB(150, 90, 40),
		Material = Enum.Material.Fabric,
	})
	local bench = Builder.part(folder, frame, {
		Name = "Workbench",
		Size = Vector3.new(10, 1.4, 3.6),
		At = CFrame.new(0, 3.7, -3),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	Builder.station(bench, "Crafting", "Cut Gem", "Cutting Bench", "HandCut")
	for _, x in { -3.8, 3.8 } do
		Builder.part(folder, frame, {
			Name = "BenchLeg",
			Size = Vector3.new(2, 3, 3),
			At = CFrame.new(x, 1.5, -3),
			Color = C.Stone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.neon(folder, frame, Vector3.new(10.2, 0.2, 3.8), CFrame.new(0, 3.05, -3), color)
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
	Builder.station(base, "Crafting", "Use Laser", "Laser Cutter", "AutoCut")
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

function Crafting.build(folder: Folder, frame: CFrame, color: Color3)
	Builder.house(folder, frame, {
		Name = "Workshop",
		Width = 30,
		Depth = 20,
		Floors = 2,
		Trim = color,
	})
	Builder.sign(folder, frame, CFrame.new(0, 8.8, -0.6), Vector3.new(12, 2, 0.5), "CRAFT & CUT", color)

	-- The forge chimney glows at the top.
	Builder.part(folder, frame, {
		Name = "ForgeChimney",
		Size = Vector3.new(4, 30, 4),
		At = CFrame.new(-11, 15, 12),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})
	local glow = Builder.neon(folder, frame, Vector3.new(3.2, 0.6, 3.2), CFrame.new(-11, 30.1, 12), C.Amber)
	glow:AddTag(Tags.Flicker)

	workbench(folder, frame * CFrame.new(-7, 0.5, 0), color)
	laserCutter(folder, frame * CFrame.new(10.5, 0.5, -2.5))
	Builder.vendor(folder, frame * CFrame.new(3.5, 0.5, -6.5), "Crafting", Vendors.Crafting)
end

return Crafting
