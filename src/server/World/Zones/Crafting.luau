-- The Crafting Hall on the north road. Out front, Hilde the quartermaster
-- runs the stone exchange (sell gems for Guild Marks) and a materials stall;
-- next door, on the quarry side, Borin the smith works an open-air forge
-- where gear is made and upgraded. (Gem cutting is across the road, at
-- Ilsa's stall beside the Mining Guild.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors
local BRASS = Color3.fromRGB(190, 150, 70)

local Crafting = {}

-- How far along the street (past the workshop) the smithy's centre sits.
Crafting.SmithyOffset = 25

-- The front of the hall: Hilde's exchange counter, where stones are sold
-- for Guild Marks, and her materials stall.
local function exchange(folder: Folder, f: CFrame, color: Color3)
	local counter = Builder.part(folder, f, {
		Name = "ExchangeCounter",
		Size = Vector3.new(9, 3, 2),
		At = CFrame.new(0, 1.5, 0),
		Color = C.WornStone,
		Material = Enum.Material.Slate,
	})
	Builder.station(counter, "Quartermaster", "Sell Stones", "Stone Exchange", "SellGems")
	Builder.neon(folder, f, Vector3.new(9.1, 0.15, 2.1), CFrame.new(0, 3.05, 0), color)
	-- Assay scales with a floating gem, and a board of the day's rates.
	for _, x in { -2.6, 2.6 } do
		Builder.part(folder, f, {
			Name = "ScalePan",
			Size = Vector3.new(1.4, 0.15, 1.4),
			At = CFrame.new(x, 3.5, 0),
			Color = BRASS,
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
	end
	Builder.part(folder, f, {
		Name = "ScaleBeam",
		Size = Vector3.new(5.6, 0.15, 0.15),
		At = CFrame.new(0, 4.4, 0),
		Color = BRASS,
		Material = Enum.Material.Metal,
		CastShadow = false,
	})
	Builder.neon(
		folder,
		f,
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(0, 5.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		nil,
		Tags.Spin
	)
	Builder.holo(folder, f, CFrame.new(0, 7.2, 0.6), Vector3.new(5, 1.6, 0.15), color, "STONES > MARKS")
end

local function materialStall(folder: Folder, f: CFrame)
	local shelf = Builder.part(folder, f, {
		Name = "MaterialShelf",
		Size = Vector3.new(6, 0.4, 2.4),
		At = CFrame.new(0, 2.6, 0),
		Color = Color3.fromRGB(110, 76, 48),
		Material = Enum.Material.WoodPlanks,
	})
	Builder.station(shelf, "Quartermaster", "Inspect Equipment", "Equipment", "Equipment")
	for _, x in { -2.7, 2.7 } do
		Builder.part(folder, f, {
			Name = "ShelfLeg",
			Size = Vector3.new(0.4, 2.4, 2.2),
			At = CFrame.new(x, 1.2, 0),
			Color = Color3.fromRGB(90, 62, 40),
			Material = Enum.Material.Wood,
		})
	end
	-- One of each material on the shelf: ingots, timber, leather, cloth, mithril.
	local goods = {
		{ -2.2, Vector3.new(0.9, 0.35, 0.45), C.Chrome, Enum.Material.Metal },
		{ -1.1, Vector3.new(1.2, 0.4, 0.4), Color3.fromRGB(150, 105, 60), Enum.Material.Wood },
		{ 0, Vector3.new(0.9, 0.5, 0.7), Color3.fromRGB(120, 72, 40), Enum.Material.Leather },
		{ 1.1, Vector3.new(0.9, 0.45, 0.7), Color3.fromRGB(120, 90, 190), Enum.Material.Fabric },
		{ 2.2, Vector3.new(0.9, 0.35, 0.45), Color3.fromRGB(170, 215, 240), Enum.Material.Metal },
	}
	for _, good in goods do
		Builder.part(folder, f, {
			Name = "Goods",
			Size = good[2],
			At = CFrame.new(good[1], 2.8 + good[2].Y / 2, 0),
			Color = good[3],
			Material = good[4],
			CastShadow = false,
		})
	end
	Builder.part(folder, f, {
		Name = "Crate",
		Size = Vector3.new(2, 2, 2),
		At = CFrame.new(4.2, 1, 0.4) * CFrame.Angles(0, math.rad(12), 0),
		Color = Color3.fromRGB(120, 86, 52),
		Material = Enum.Material.WoodPlanks,
	})
end

-- Borin's open-air smithy beside the hall (toward the quarry): a stone
-- floor under a timber roof, a glowing forge, the anvil where gear is made,
-- a rack of blades and stacked material crates.
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
	Builder.station(anvil, "Forge", "Inspect Equipment", "Equipment Bench", "Equipment")
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
		Builder.part(folder, f, {
			Name = "Crate",
			Size = Vector3.new(2, 2, 2),
			At = CFrame.new(spot[1], spot[2] + 0.3, spot[3]) * CFrame.Angles(0, math.rad(i * 11), 0),
			Color = Color3.fromRGB(120, 86, 52),
			Material = Enum.Material.WoodPlanks,
		})
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
	Builder.sign(folder, frame, CFrame.new(0, 8.8, -0.6), Vector3.new(12, 2, 0.5), "EXPEDITION EXCHANGE", color)

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

	exchange(folder, frame * CFrame.new(-7, 0.5, -3), color)
	materialStall(folder, frame * CFrame.new(9, 0.5, -3))
	Builder.vendor(folder, frame * CFrame.new(2, 0.5, -6.5), "Quartermaster", Vendors.Quartermaster)
	-- Beside the workshop, on the quarry side.
	smithy(folder, frame * CFrame.new(Crafting.SmithyOffset, 0.5, 0), color)
end

return Crafting
