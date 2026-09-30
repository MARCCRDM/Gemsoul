-- Crafting & Cutting workshop on the north road. Master Gemcutter Ilsa works
-- out front at a heavy stone bench fitted with floating holographic displays
-- (the manual QTE cutting station), next to a compact laser cutter. Borin
-- the smith keeps an open-air forge next door.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local Crafting = {}

-- How far along the street (past the workshop) the smithy's centre sits.
Crafting.SmithyOffset = 25

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

-- Borin's open-air smithy beside the workshop (toward the quarry): a stone
-- floor under a timber roof, a glowing forge, an anvil where gear is made,
-- a rack of blades, material crates and a counter where he buys gems.
local function smithy(folder: Folder, f: CFrame, color: Color3)
	local wood = Color3.fromRGB(92, 62, 40)
	Builder.part(folder, f, {
		Name = "ForgeFloor",
		Size = Vector3.new(16, 0.3, 16),
		At = CFrame.new(0, 0.15, 8),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	for _, x in { -7.5, 7.5 } do
		for _, z in { 0.5, 15.5 } do
			Builder.part(folder, f, {
				Name = "Post",
				Size = Vector3.new(0.8, 10, 0.8),
				At = CFrame.new(x, 5, z),
				Color = wood,
				Material = Enum.Material.Wood,
			})
		end
	end
	Builder.part(folder, f, {
		Name = "ForgeRoof",
		Size = Vector3.new(17.5, 0.5, 17.5),
		At = CFrame.new(0, 10.6, 8) * CFrame.Angles(math.rad(-7), 0, 0),
		Color = Color3.fromRGB(70, 60, 56),
		Material = Enum.Material.Slate,
	})
	Builder.part(folder, f, {
		Name = "ForgeBackWall",
		Size = Vector3.new(15, 7, 0.8),
		At = CFrame.new(0, 3.5, 15.6),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})
	Builder.sign(folder, f, CFrame.new(0, 9.2, 0.2), Vector3.new(9, 1.8, 0.4), "THE FORGE", color)

	-- Forge hearth with glowing coals, a hood and a chimney through the roof.
	Builder.part(folder, f, {
		Name = "Hearth",
		Size = Vector3.new(5, 3, 4),
		At = CFrame.new(-4.5, 1.5, 12.8),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})
	local coals = Builder.neon(folder, f, Vector3.new(4, 0.3, 3), CFrame.new(-4.5, 3.1, 12.8), C.Amber, 14)
	coals.Name = "Coals"
	coals:AddTag(Tags.Flicker)
	Builder.part(folder, f, {
		Name = "Hood",
		Size = Vector3.new(5, 1.2, 4),
		At = CFrame.new(-4.5, 7, 12.8),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	Builder.part(folder, f, {
		Name = "ForgeFlue",
		Size = Vector3.new(1.6, 5, 1.6),
		At = CFrame.new(-4.5, 10, 13.2),
		Color = C.DarkStone,
		Material = Enum.Material.Brick,
	})

	-- The anvil, where gear is made.
	Builder.part(folder, f, {
		Name = "AnvilBase",
		Size = Vector3.new(1.4, 1.6, 1.2),
		At = CFrame.new(1, 0.95, 6),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	local anvil = Builder.part(folder, f, {
		Name = "Anvil",
		Size = Vector3.new(3, 0.7, 1.2),
		At = CFrame.new(1, 2.1, 6),
		Color = Color3.fromRGB(60, 62, 70),
		Material = Enum.Material.Metal,
	})
	Builder.station(anvil, "Forge", "Craft Gear", "Anvil", "Forge")
	Builder.neon(folder, f, Vector3.new(0.6, 0.12, 0.3), CFrame.new(1.8, 2.5, 6), C.Amber) -- a glowing blank

	-- Quench barrel.
	Builder.disc(folder, f, {
		Name = "QuenchBarrel",
		At = CFrame.new(-1.8, 1.4, 9.5),
		Radius = 1,
		Height = 2.5,
		Color = wood,
		Material = Enum.Material.Wood,
	})
	Builder.disc(folder, f, {
		Name = "Water",
		At = CFrame.new(-1.8, 2.66, 9.5),
		Radius = 0.85,
		Height = 0.05,
		Color = Color3.fromRGB(60, 110, 140),
		Material = Enum.Material.Glass,
		CanCollide = false,
	})

	-- Weapon rack along the right side.
	Builder.part(folder, f, {
		Name = "Rack",
		Size = Vector3.new(0.4, 0.4, 7),
		At = CFrame.new(6.9, 4.2, 9),
		Color = wood,
		Material = Enum.Material.Wood,
	})
	for i, z in { 6.5, 8.2, 9.9, 11.6 } do
		local long = i % 2 == 1
		Builder.part(folder, f, {
			Name = "RackBlade",
			Size = Vector3.new(0.12, if long then 3.6 else 2.8, 0.45),
			At = CFrame.new(6.6, if long then 2.6 else 2.2, z),
			Color = C.Chrome,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
	end

	-- Material crates with ingots, timber and leather on top.
	for i, spot in { { 4.6, 1, 2.2 }, { 6.4, 1, 3.6 }, { 5.2, 3, 2.6 } } do
		local crate = Builder.part(folder, f, {
			Name = "Crate",
			Size = Vector3.new(2, 2, 2),
			At = CFrame.new(spot[1], spot[2] + 0.3, spot[3]) * CFrame.Angles(0, math.rad(i * 11), 0),
			Color = Color3.fromRGB(120, 86, 52),
			Material = Enum.Material.WoodPlanks,
		})
		if i == 1 then
			Builder.station(crate, "Forge", "Buy Materials", "Supplies", "Materials")
		end
	end
	for j = 0, 2 do
		Builder.part(folder, f, {
			Name = "Ingot",
			Size = Vector3.new(0.9, 0.3, 0.4),
			At = CFrame.new(5.2, 4.45, 2.2 + j * 0.45),
			Color = if j == 1 then Color3.fromRGB(170, 215, 240) else C.Chrome,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
	end

	-- Counter where Borin buys gems, with a glowing assay scale.
	local counter = Builder.part(folder, f, {
		Name = "GemCounter",
		Size = Vector3.new(4, 3, 1.6),
		At = CFrame.new(-4.8, 1.8, 3),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	Builder.station(counter, "Forge", "Sell Gems", "Gem Counter", "SellGems")
	Builder.neon(folder, f, Vector3.new(4.1, 0.15, 1.7), CFrame.new(-4.8, 3.3, 3), color)
	Builder.neon(
		folder,
		f,
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(-4.8, 4, 3) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		nil,
		Tags.Spin
	)

	Builder.vendor(folder, f * CFrame.new(1, 0, -2.2), "Forge", Vendors.Forge)
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
	-- Beside the workshop, on the quarry side.
	smithy(folder, frame * CFrame.new(Crafting.SmithyOffset, 0.5, 0), color)
end

return Crafting
