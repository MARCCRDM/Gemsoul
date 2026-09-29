-- Zone 2: Crafting & Cutting Building.
-- A stone workshop with a forge, a heavy workbench retrofitted with floating
-- holographic displays (the manual QTE cutting station), and a row of
-- automated laser cutters in three tiers along the back wall.
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local WIDTH = 56
local DEPTH = 48
local HEIGHT = 20

local LASER_TIERS = {
	{ Tier = 1, Color = C.Amber },
	{ Tier = 2, Color = C.Cyan },
	{ Tier = 3, Color = C.Magenta },
}

local Crafting = {}

local function shell(folder: Folder, origin: CFrame, color: Color3)
	Builder.part(folder, origin, {
		Name = "Floor",
		Size = Vector3.new(WIDTH, 1, DEPTH),
		At = CFrame.new(0, -0.4, DEPTH / 2),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local props = { Thickness = 2, Color = C.Stone, Battlements = true, Trim = color }
	local hw = WIDTH / 2
	Builder.wallWithDoor(folder, origin, -hw, 0, hw, 0, HEIGHT, 12, 12, props)
	Builder.wall(folder, origin, -hw, DEPTH, hw, DEPTH, HEIGHT, props)
	Builder.wall(folder, origin, -hw, 0, -hw, DEPTH, HEIGHT, props)
	Builder.wall(folder, origin, hw, 0, hw, DEPTH, HEIGHT, props)

	-- Timber roof with a neon skylight seam down the middle.
	for _, side in { -1, 1 } do
		Builder.part(folder, origin, {
			Name = "Roof",
			Size = Vector3.new(hw - 1, 1, DEPTH),
			At = CFrame.new(side * (hw / 2 + 0.5), HEIGHT - 0.5, DEPTH / 2),
			Color = C.DarkWood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	Builder.neon(folder, origin, Vector3.new(2, 0.4, DEPTH), CFrame.new(0, HEIGHT - 0.5, DEPTH / 2), color)
	-- Hanging work lights under the roof.
	for _, z in { 12, 24, 36 } do
		Builder.neon(folder, origin, Vector3.new(10, 0.5, 0.8), CFrame.new(0, HEIGHT - 3, z), color, 30)
	end

	for _, side in { -1, 1 } do
		Builder.pillar(folder, origin, side * hw, 0, HEIGHT + 6, color, { Width = 6, Color = C.Stone })
		Builder.torch(folder, origin, CFrame.new(side * 9, 7, -1.6), color)
	end
	Builder.sign(folder, origin, CFrame.new(0, 15, -1.3), Vector3.new(16, 3.2, 0.6), "CRAFT & CUT", color)
end

local function forge(folder: Folder, origin: CFrame)
	local x, z = -WIDTH / 2 + 5, 26
	Builder.part(folder, origin, {
		Name = "Forge",
		Size = Vector3.new(8, 8, 10),
		At = CFrame.new(x, 4, z),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})
	Builder.part(folder, origin, {
		Name = "Chimney",
		Size = Vector3.new(4, HEIGHT + 4, 4),
		At = CFrame.new(x - 1, (HEIGHT + 4) / 2, z),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})
	local mouth = Builder.neon(folder, origin, Vector3.new(0.4, 3, 5), CFrame.new(x + 4, 2.5, z), C.Amber, 22)
	mouth.Name = "ForgeFire"
	mouth:AddTag(Tags.Flicker)
	Builder.part(folder, origin, {
		Name = "Anvil",
		Size = Vector3.new(2, 2, 4),
		At = CFrame.new(x + 8, 1, z),
		Color = C.Iron,
		Material = Enum.Material.CorrodedMetal,
	})
end

local function cuttingStation(folder: Folder, origin: CFrame, color: Color3)
	local z = 20
	-- Heavy stone workbench.
	local bench = Builder.part(folder, origin, {
		Name = "CuttingStation",
		Size = Vector3.new(16, 1.6, 7),
		At = CFrame.new(0, 4, z),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
		Tag = Tags.CuttingStation,
	})
	Builder.prompt(bench, "Cut Gem", "Manual Cutting Station")
	for _, x in { -6, 6 } do
		Builder.part(folder, origin, {
			Name = "BenchLeg",
			Size = Vector3.new(3, 3.2, 6),
			At = CFrame.new(x, 1.6, z),
			Color = C.Stone,
			Material = Enum.Material.Cobblestone,
		})
	end
	Builder.neon(folder, origin, Vector3.new(16.2, 0.2, 7.2), CFrame.new(0, 3.3, z), color)

	-- Iron vise and a chrome gem clamp on the bench top.
	Builder.part(folder, origin, {
		Name = "Vise",
		Size = Vector3.new(2, 1.4, 2),
		At = CFrame.new(-4, 5.5, z),
		Color = C.Iron,
		Material = Enum.Material.CorrodedMetal,
	})
	Builder.part(folder, origin, {
		Name = "GemClamp",
		Size = Vector3.new(1.4, 1, 1.4),
		At = CFrame.new(0, 5.3, z),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	Builder.neon(
		folder,
		origin,
		Vector3.new(0.9, 0.9, 0.9),
		CFrame.new(0, 6.3, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		8,
		Tags.Spin
	)

	-- Holographic displays projected from chrome emitters on the back edge.
	local displays = {
		{ X = -6.5, Yaw = -20, Size = Vector3.new(4.5, 3, 0.2), Text = "ANGLE\n42.0 DEG" },
		{ X = 0, Yaw = 0, Size = Vector3.new(7, 4, 0.2), Text = "QTE CUTTING\nPRESS [E]" },
		{ X = 6.5, Yaw = 20, Size = Vector3.new(4.5, 3, 0.2), Text = "CLARITY\n--%" },
	}
	for _, display in displays do
		Builder.part(folder, origin, {
			Name = "HoloEmitter",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 1.2, 1.2),
			At = CFrame.new(display.X, 5.1, z + 2.8) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.Chrome,
			Material = Enum.Material.Metal,
		})
		Builder.neon(folder, origin, Vector3.new(0.15, 2.5, 0.15), CFrame.new(display.X, 6.6, z + 2.8), color)
		Builder.holo(
			folder,
			origin,
			CFrame.new(display.X, 9.5, z + 3) * CFrame.Angles(0, math.rad(display.Yaw), 0),
			display.Size,
			color,
			display.Text
		)
	end
end

local function laserCutter(folder: Folder, origin: CFrame, x: number, z: number, tier: number, color: Color3)
	local base = Builder.part(folder, origin, {
		Name = "LaserCutter",
		Size = Vector3.new(9, 3, 7),
		At = CFrame.new(x, 1.5, z),
		Color = C.Chrome,
		Material = Enum.Material.DiamondPlate,
		Tag = Tags.LaserCutter,
	})
	base:SetAttribute("Tier", tier)
	Builder.prompt(base, "Use Laser Cutter", "Tier " .. tier)
	Builder.part(folder, origin, {
		Name = "CutterChamber",
		Size = Vector3.new(8, 6, 6),
		At = CFrame.new(x, 6, z),
		Color = Color3.fromRGB(180, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
	})
	Builder.part(folder, origin, {
		Name = "CutterHead",
		Size = Vector3.new(9, 2, 7),
		At = CFrame.new(x, 10, z),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	Builder.neon(folder, origin, Vector3.new(0.25, 5.4, 0.25), CFrame.new(x, 6, z), C.Red, 10, Tags.Laser)
	Builder.neon(folder, origin, Vector3.new(9.2, 0.3, 7.2), CFrame.new(x, 3.05, z), color)
	Builder.screen(folder, origin, CFrame.new(x, 13.5, z - 1), Vector3.new(5, 3.4, 2.4), {
		Name = "CutterScreen",
		Text = "LASER T" .. tier .. "\n> IDLE_",
		TextColor = color,
	})
end

function Crafting.build(folder: Folder, origin: CFrame, color: Color3)
	shell(folder, origin, color)
	forge(folder, origin)
	cuttingStation(folder, origin, color)
	for i, tier in LASER_TIERS do
		laserCutter(folder, origin, (i - 2) * 15, DEPTH - 7, tier.Tier, tier.Color)
	end
end

return Crafting
