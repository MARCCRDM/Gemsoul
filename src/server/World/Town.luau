-- Village layout, in the spirit of an Oblivion town: a market square in the
-- middle, a main street from the south gate, and roads north (Mining Guild,
-- workshop, quarry), west (arena) and east (enchanting tower). Houses line
-- the streets shoulder to shoulder; the space behind them is gardens, a farm
-- field and a well.
--
-- Streets, sidewalks and building lots are painted as terrain (cobblestone,
-- pavement, dirt) so grass only grows in the gardens and outside the walls.
local Builder = require(script.Parent.Builder)
local Hub = require(script.Parent.Hub)
local Kingdom = require(script.Parent.Kingdom)
local Landscape = require(script.Parent.Landscape)
local Zones = script.Parent.Zones

local C = Builder.Colors

local GROUND = 0.5
local SQUARE_HALF = 36
local STREET_HALF = 7 -- cobbled roadway
local WALK_HALF = 11 -- roadway plus sidewalks
local FRONT = 12 -- building fronts sit this far from a street's centre line

local ZONE_COLORS = {
	Mining = C.Cyan,
	Crafting = C.Amber,
	Market = C.Green,
	Enchanting = C.Purple,
	Arena = C.Red,
}

-- Streets as axis-aligned rectangles (paved width included).
local STREETS = {
	{ X1 = -WALK_HALF, X2 = WALK_HALF, Z1 = -95, Z2 = -SQUARE_HALF, Color = C.Cyan }, -- north
	{ X1 = -WALK_HALF, X2 = WALK_HALF, Z1 = SQUARE_HALF, Z2 = Kingdom.InnerFace, Color = C.Gold }, -- south
	{ X1 = -86, X2 = -SQUARE_HALF, Z1 = -WALK_HALF, Z2 = WALK_HALF, Color = C.Red }, -- west
	{ X1 = SQUARE_HALF, X2 = 136, Z1 = -WALK_HALF, Z2 = WALK_HALF, Color = C.Purple }, -- east
}

local HOUSE_STYLES = {
	{ Stone = C.WornStone, Upper = C.Plaster, Roof = C.RoofRed },
	{ Stone = C.Stone, Upper = Color3.fromRGB(214, 196, 160), Roof = C.RoofBlue },
	{ Stone = C.WornStone, Upper = Color3.fromRGB(236, 226, 206), Roof = Color3.fromRGB(96, 70, 52) },
	{ Stone = C.DarkStone, Upper = C.Plaster, Roof = C.RoofRed },
}

local Town = {}

type Rect = { number }

local function rect(x1: number, x2: number, z1: number, z2: number): Rect
	return { math.min(x1, x2), math.max(x1, x2), math.min(z1, z2), math.max(z1, z2) }
end

local function paintRect(r: Rect, material: Enum.Material)
	Landscape.paint(Vector3.new((r[1] + r[2]) / 2, 0, (r[3] + r[4]) / 2), r[2] - r[1], r[4] - r[3], material)
end

-- Footprint of a building whose frame faces (dx, dz) at (x, z): `width` along
-- the street, `depth` back from it.
local function lot(x: number, z: number, dx: number, dz: number, width: number, depth: number): Rect
	if dx ~= 0 then
		return rect(x, x - dx * depth, z - width / 2, z + width / 2)
	end
	return rect(x - width / 2, x + width / 2, z, z - dz * depth)
end

local function streets(folder: Folder, blocked: { Rect })
	paintRect(rect(-SQUARE_HALF, SQUARE_HALF, -SQUARE_HALF, SQUARE_HALF), Enum.Material.Cobblestone)
	table.insert(blocked, rect(-SQUARE_HALF, SQUARE_HALF, -SQUARE_HALF, SQUARE_HALF))

	for _, street in STREETS do
		local r = rect(street.X1, street.X2, street.Z1, street.Z2)
		paintRect(r, Enum.Material.Pavement)
		table.insert(blocked, r)
		local alongX = (r[2] - r[1]) > (r[4] - r[3])
		local length = if alongX then r[2] - r[1] else r[4] - r[3]
		local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
		if alongX then
			paintRect(rect(r[1], r[2], -STREET_HALF, STREET_HALF), Enum.Material.Cobblestone)
		else
			paintRect(rect(-STREET_HALF, STREET_HALF, r[3], r[4]), Enum.Material.Cobblestone)
		end
		-- Neon curb inlays in the street's colour.
		for _, side in { -1, 1 } do
			local offset = side * (STREET_HALF + 0.5)
			Builder.neon(
				folder,
				CFrame.identity,
				if alongX then Vector3.new(length, 0.1, 0.3) else Vector3.new(0.3, 0.1, length),
				CFrame.new(if alongX then cx else offset, GROUND + 0.05, if alongX then offset else cz),
				street.Color
			)
		end
	end

	-- Street lamps on the sidewalks, alternating sides.
	local lamps = {
		{ -9.5, 50 },
		{ 9.5, 80 },
		{ -9.5, 110 },
		{ 9.5, 140 },
		{ -9.5, 168 },
		{ 50, -9.5 },
		{ 80, 9.5 },
		{ 110, -9.5 },
		{ -50, 9.5 },
		{ -76, -9.5 },
	}
	for _, spot in lamps do
		Builder.lamp(folder, CFrame.new(spot[1], GROUND, spot[2]), 0, 0, C.Amber, 11)
	end
end

local function houses(folder: Folder, blocked: { Rect })
	local rng = Random.new(99)
	-- x, z, facing dx, dz, width
	local spots = {}
	for _, z in { 52, 76, 100, 124, 148 } do
		table.insert(spots, { -FRONT, z, 1, 0, 20 })
		table.insert(spots, { FRONT, z, -1, 0, 20 })
	end
	for _, x in { -50, -72 } do
		table.insert(spots, { x, -FRONT, 0, 1, 18 })
		table.insert(spots, { x, FRONT, 0, -1, 18 })
	end
	for _, x in { 50, 72, 94, 116 } do
		table.insert(spots, { x, -FRONT, 0, 1, 18 })
		table.insert(spots, { x, FRONT, 0, -1, 18 })
	end

	for i, spot in spots do
		local x, z, dx, dz, width = spot[1], spot[2], spot[3], spot[4], spot[5]
		local depth = 16 + rng:NextInteger(0, 1) * 2
		local frame = Builder.facing(Vector3.new(x, 0, z), dx, dz)
		local style = HOUSE_STYLES[rng:NextInteger(1, #HOUSE_STYLES)]
		local isInn = i == 6
		Builder.house(folder, frame, {
			Name = if isInn then "Inn" else "House",
			Width = width,
			Depth = depth,
			Floors = if isInn or rng:NextNumber() < 0.7 then 2 else 1,
			Stone = style.Stone,
			Upper = style.Upper,
			Roof = style.Roof,
			Trim = if isInn then C.Gold else nil,
		})
		if isInn then
			Builder.sign(
				folder,
				frame,
				CFrame.new(0, 8.8, -0.6),
				Vector3.new(14, 2, 0.5),
				"THE GLOWING GEM INN",
				C.Gold
			)
		elseif i % 2 == 0 then
			Builder.planter(folder, frame, CFrame.new(width / 2 - 4, 0.5, -1.8), 5, rng)
		end
		local footprint = lot(x, z, dx, dz, width, depth)
		paintRect(footprint, Enum.Material.Ground)
		table.insert(blocked, footprint)
	end
end

local function zones(folder: Folder, blocked: { Rect })
	local Mining = require(Zones.Mining)
	local Crafting = require(Zones.Crafting)
	local Marketplace = require(Zones.Marketplace)
	local Enchanting = require(Zones.Enchanting)
	local Arena = require(Zones.Arena)

	local function zoneFolder(name: string): Folder
		return Builder.folder(folder, name)
	end
	-- Ground under each zone is painted as dirt once they're all placed.
	local lots: { Rect } = {}

	-- North road: Mining Guild (west side) faces the Crafting Hall (east side).
	local mining = zoneFolder("Mining")
	Mining.buildGuild(mining, Builder.facing(Vector3.new(-FRONT, 0, -62), 1, 0), ZONE_COLORS.Mining)
	table.insert(lots, lot(-FRONT, -62, 1, 0, 34, 22))
	Mining.buildQuarry(mining, Builder.facing(Vector3.new(0, 0, -95), 0, 1), ZONE_COLORS.Mining)
	table.insert(lots, rect(-42, 42, -95, -95 - Mining.QuarryDepth - 2))

	-- Ilsa's cutting stall sits next to the guild, on the quarry side.
	local Cutting = require(Zones.Cutting)
	local cuttingZ = -62 - 17 - Cutting.Width / 2 - 2
	Cutting.build(zoneFolder("Cutting"), Builder.facing(Vector3.new(-FRONT, 0, cuttingZ), 1, 0), ZONE_COLORS.Crafting)
	table.insert(lots, lot(-FRONT, cuttingZ, 1, 0, Cutting.Width, Cutting.Depth + 4))

	Crafting.build(zoneFolder("Crafting"), Builder.facing(Vector3.new(FRONT, 0, -62), -1, 0), ZONE_COLORS.Crafting)
	table.insert(lots, lot(FRONT, -62, -1, 0, 30, 20))
	-- Borin's smithy, next to the workshop on the quarry side.
	table.insert(lots, lot(FRONT, -62 - Crafting.SmithyOffset, -1, 0, 18, 17))

	Marketplace.build(zoneFolder("Marketplace"), CFrame.new(0, GROUND, 0), ZONE_COLORS.Market, SQUARE_HALF - 6)

	-- East road ends at the enchanting tower, west road at the arena.
	Enchanting.build(zoneFolder("Enchanting"), Builder.facing(Vector3.new(136, 0, 0), -1, 0), ZONE_COLORS.Enchanting)
	table.insert(lots, rect(136, 166, -16, 16))

	Arena.build(zoneFolder("Arena"), Builder.facing(Vector3.new(-86, 0, 0), 1, 0), ZONE_COLORS.Arena)
	table.insert(lots, rect(-86, -86 - 2 * Arena.Radius - 4, -Arena.Radius - 2, Arena.Radius + 2))

	for _, r in lots do
		paintRect(r, Enum.Material.Ground)
		table.insert(blocked, r)
	end
end

-- A small fenced farm field: alternating rows of tilled earth and crops.
local function farm(folder: Folder, blocked: { Rect })
	local field = rect(-100, -52, 64, 120)
	for x = field[1], field[2] - 4, 8 do
		paintRect(rect(x, x + 4, field[3], field[4]), Enum.Material.Mud)
		paintRect(rect(x + 4, x + 8, field[3], field[4]), Enum.Material.LeafyGrass)
	end
	-- Fence rails around the field.
	local x1, x2, z1, z2 = field[1] - 1, field[2] + 1, field[3] - 1, field[4] + 1
	local rails = {
		{ (x1 + x2) / 2, z1, x2 - x1, 0.4 },
		{ (x1 + x2) / 2, z2, x2 - x1, 0.4 },
		{ x1, (z1 + z2) / 2, 0.4, z2 - z1 },
		{ x2, (z1 + z2) / 2, 0.4, z2 - z1 },
	}
	for _, r in rails do
		for _, y in { 1.4, 2.6 } do
			Builder.part(folder, CFrame.identity, {
				Name = "FenceRail",
				Size = Vector3.new(r[3], 0.35, r[4]),
				At = CFrame.new(r[1], GROUND + y, r[2]),
				Color = C.Wood,
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
		end
	end
	for _, post in { { x1, z1 }, { x2, z1 }, { x1, z2 }, { x2, z2 } } do
		Builder.part(folder, CFrame.identity, {
			Name = "FencePost",
			Size = Vector3.new(0.8, 3.4, 0.8),
			At = CFrame.new(post[1], GROUND + 1.7, post[2]),
			Color = C.DarkWood,
			Material = Enum.Material.Wood,
		})
	end
	for _, spot in { { -44, 70 }, { -43, 78 } } do
		Builder.disc(folder, CFrame.identity, {
			Name = "Haystack",
			Radius = 2.4,
			Height = 3.2,
			At = CFrame.new(spot[1], GROUND + 1.6, spot[2]),
			Color = Color3.fromRGB(214, 180, 90),
			Material = Enum.Material.Grass,
		})
	end
	table.insert(blocked, rect(x1 - 4, x2 + 10, z1 - 4, z2 + 4))
end

local function well(folder: Folder, position: Vector3, blocked: { Rect })
	local o = CFrame.new(position)
	Builder.disc(folder, o, {
		Name = "Well",
		Radius = 3,
		Height = 3,
		At = CFrame.new(0, 1.5, 0),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	Builder.disc(folder, o, {
		Name = "WellWater",
		Radius = 2.3,
		Height = 0.2,
		At = CFrame.new(0, 2.8, 0),
		Color = Color3.fromRGB(60, 130, 170),
		Material = Enum.Material.Glass,
		CanCollide = false,
		CastShadow = false,
	})
	for _, x in { -2.6, 2.6 } do
		Builder.part(folder, o, {
			Name = "WellPost",
			Size = Vector3.new(0.6, 6, 0.6),
			At = CFrame.new(x, 3, 0),
			Color = C.DarkWood,
			Material = Enum.Material.Wood,
		})
	end
	for _, side in { -1, 1 } do
		Builder.part(folder, o, {
			Class = "WedgePart",
			Name = "WellRoof",
			Size = Vector3.new(7, 1.6, 2.4),
			At = CFrame.new(0, 6.6, side * 1.2) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Color = C.RoofRed,
			Material = Enum.Material.Slate,
		})
	end
	table.insert(blocked, rect(position.X - 6, position.X + 6, position.Z - 6, position.Z + 6))
end

-- Trees scattered through whatever open ground is left inside the walls.
local function gardens(folder: Folder, blocked: { Rect })
	local rng = Random.new(42)
	local planted = {}
	local function clear(p: Vector3, margin: number): boolean
		if Vector3.new(p.X, 0, p.Z).Magnitude > Kingdom.InnerFace - 12 then
			return false
		end
		for _, r in blocked do
			if p.X > r[1] - margin and p.X < r[2] + margin and p.Z > r[3] - margin and p.Z < r[4] + margin then
				return false
			end
		end
		for _, other in planted do
			if (other - p).Magnitude < 13 then
				return false
			end
		end
		return true
	end

	local placed, attempts = 0, 0
	while placed < 45 and attempts < 1500 do
		attempts += 1
		local position = Vector3.new(rng:NextNumber(-170, 170), GROUND, rng:NextNumber(-170, 170))
		if clear(position, 6) then
			Builder.tree(folder, position, rng:NextNumber(0.9, 1.4), rng)
			table.insert(planted, position)
			placed += 1
		end
	end
	placed, attempts = 0, 0
	while placed < 8 and attempts < 400 do
		attempts += 1
		local position = Vector3.new(rng:NextNumber(-160, 160), GROUND, rng:NextNumber(-160, 160))
		if clear(position, 4) then
			Builder.planter(
				folder,
				CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				CFrame.identity,
				8,
				rng
			)
			table.insert(planted, position)
			placed += 1
		end
	end
end

function Town.build(parent: Instance): Folder
	local folder = Builder.folder(parent, "Town")
	local blocked: { Rect } = {}

	streets(Builder.folder(folder, "Streets"), blocked)
	Hub.build(folder)
	zones(folder, blocked)
	houses(Builder.folder(folder, "Houses"), blocked)

	local outskirts = Builder.folder(folder, "Outskirts")
	farm(outskirts, blocked)
	well(outskirts, Vector3.new(64, GROUND, 64), blocked)
	gardens(outskirts, blocked)

	return folder
end

return Town
