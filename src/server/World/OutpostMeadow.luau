-- The walkable meadow and its shared placement rules. All heights are local
-- to the Outpost origin; mining, scenery and paths use the same shoreline.
local Meadow = {}
local GRASS = Color3.fromRGB(117, 156, 76)
local LEAF = Color3.fromRGB(104, 151, 78)
local WOOD = Color3.fromRGB(133, 104, 74)
local PATH = Color3.fromRGB(200, 187, 148)

local function point(x, z)
	return Vector3.new(x, 0, z)
end

Meadow.Paths = {
	{ point(0, 74), point(-8, 51), point(-5, 30), point(0, 12) },
	{ point(0, 12), point(-29, 28), point(-55, 43), point(-82, 60) },
	{ point(0, 12), point(27, 22), point(58, 39), point(84, 60) },
	{ point(0, 12), point(31, -7), point(49, -30), point(70, -56) },
	{ point(0, 12), point(-15, -22), point(-3, -60), point(15, -110) },
	{ point(-29, 28), point(-66, 12), point(-99, 2), point(-128, 19) },
	{ point(58, 39), point(88, 17), point(125, 14) },
}
local CLEARINGS = {
	{ point(0, 74), 17 },
	{ point(0, 12), 15 },
	{ point(-82, 60), 23 },
	{ point(84, 60), 20 },
	{ point(70, -56), 17 },
	{ point(-128, 19), 13 },
	{ point(125, 14), 13 },
}
Meadow.Trees = {
	{ -115, 82, 17 },
	{ -126, 53, 21 },
	{ -108, -48, 19 },
	{ -126, -26, 14 },
	{ -62, -114, 22 },
	{ -83, -96, 15 },
	{ 44, -124, 19 },
	{ 98, -96, 17 },
	{ 128, -47, 22 },
	{ 138, -17, 15 },
	{ 106, 84, 19 },
	{ 79, 112, 16 },
	{ -46, 116, 20 },
	{ -70, 103, 14 },
}

function Meadow.outline(radius: number?): { Vector3 }
	local outline = {}
	local segments = if radius then 12 else 32
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local r = (radius or 164) * (0.96 + 0.1 * math.sin(3 * a + 0.4) + 0.05 * math.cos(5 * a - 0.6))
		table.insert(outline, point(math.cos(a) * r * 1.1, math.sin(a) * r * 0.95))
	end
	return outline
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local line = b - a
	local t = math.clamp((p - a):Dot(line) / line:Dot(line), 0, 1)
	return (p - (a + line * t)).Magnitude
end

function Meadow.contains(p: Vector3, margin: number?, outline: { Vector3 }?): boolean
	local polygon = outline or Meadow.outline()
	local inside = false
	for i, a in polygon do
		local b = polygon[i % #polygon + 1]
		if distanceToSegment(p, a, b) < (margin or 0) then
			return false
		end
		if (a.Z > p.Z) ~= (b.Z > p.Z) and p.X < (b.X - a.X) * (p.Z - a.Z) / (b.Z - a.Z) + a.X then
			inside = not inside
		end
	end
	return inside
end

function Meadow.clear(p: Vector3, padding: number?): boolean
	local extra = padding or 0
	if not Meadow.contains(p, 12 + extra) then
		return false
	end
	for _, clearing in CLEARINGS do
		if (p - clearing[1]).Magnitude < clearing[2] + extra then
			return false
		end
	end
	for _, path in Meadow.Paths do
		for i = 1, #path - 1 do
			if distanceToSegment(p, path[i], path[i + 1]) < 9 + extra then
				return false
			end
		end
	end
	for _, tree in Meadow.Trees do
		if (p - point(tree[1], tree[2])).Magnitude < 9 + extra then
			return false
		end
	end
	return true
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end
local function part(parent, name, cf, size, color, material, collide, shape)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.CFrame, p.Size, p.Color = name, cf, size, color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Anchored, p.CanCollide = true, collide == true
	p.CanQuery, p.CanTouch = collide == true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = name == "TreeCrown" or name == "TreeTrunk"
	p.Parent = parent
	return p
end

-- Two wedges form an extruded triangle in any plane. For the meadow the
-- thin axis is vertical, so adjoining grass faces meet at one level.
local function triangle(parent, name, at, a, b, c, thickness, color, material, collide)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
		c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local back = bc.Unit
	local up = bc:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	part(
		parent,
		name,
		at * CFrame.fromMatrix((a + b) / 2, right, up, back),
		Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		color,
		material,
		collide,
		"Wedge"
	)
	part(
		parent,
		name,
		at * CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		color,
		material,
		collide,
		"Wedge"
	)
end

function Meadow.land(parent, at: CFrame, radius: number?, boundary: boolean?)
	local ground = model(parent, "MeadowGround")
	local outline = Meadow.outline(radius)
	for i, a in outline do
		local b = outline[i % #outline + 1]
		for _, layer in
			{
				{ "GrassSurface", -0.6, 1.2, GRASS, Enum.Material.Grass, 1 },
				{ "SapphireSoil", -2.4, 2.4, Color3.fromRGB(90, 127, 137), Enum.Material.Slate, 1 },
				{ "SapphireCoast", -4.6, 2, Color3.fromRGB(116, 184, 215), Enum.Material.Glass, 0.98 },
			}
		do
			triangle(
				ground,
				layer[1],
				at * CFrame.new(0, layer[2], 0),
				Vector3.zero,
				a * layer[6],
				b * layer[6],
				layer[3],
				layer[4],
				layer[5],
				boundary and layer[1] == "GrassSurface"
			)
		end
		if boundary then
			local start, finish = (at * CFrame.new(a)).Position, (at * CFrame.new(b)).Position
			local fence = part(
				ground,
				"MeadowBoundary",
				CFrame.lookAt((start + finish) / 2 + Vector3.new(0, 9, 0), finish + Vector3.new(0, 9, 0)),
				Vector3.new(1.2, 18, (finish - start).Magnitude + 0.7),
				GRASS,
				Enum.Material.SmoothPlastic,
				true
			)
			fence.Transparency, fence.CanQuery = 1, false
		end
	end
	return ground
end

function Meadow.tree(parent, at: CFrame, height: number, seed: number?)
	local m = model(parent, "MeadowTree")
	local rng = Random.new(seed or 51)
	part(
		m,
		"TreeTrunk",
		at * CFrame.new(0, height * 0.3, 0),
		Vector3.new(height * 0.12, height * 0.6, height * 0.12),
		WOOD,
		Enum.Material.Wood,
		true
	)
	for i, spec in
		{ { -0.18, 0.65, 0.02, 0.6 }, { 0.21, 0.68, 0.07, 0.58 }, { 0, 0.88, -0.06, 0.65 }, { 0.02, 0.65, -0.23, 0.48 } }
	do
		local scale = height * spec[4]
		part(
			m,
			"TreeCrown",
			at * CFrame.new(height * spec[1], height * spec[2], height * spec[3]),
			Vector3.new(scale, scale * 0.8, scale),
			LEAF:Lerp(Color3.fromRGB(173, 187, 96), rng:NextNumber(0.05, 0.36)),
			Enum.Material.Grass,
			false,
			"Ball"
		)
	end
	return m
end

function Meadow.build(parent, at: CFrame)
	Meadow.land(parent, at, nil, true)
	local paths, nature = model(parent, "MeadowPaths"), model(parent, "MeadowNature")
	for _, route in Meadow.Paths do
		for i = 1, #route - 1 do
			local a, b = (at * CFrame.new(route[i])).Position, (at * CFrame.new(route[i + 1])).Position
			part(
				paths,
				"GardenPath",
				CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.035, 0), b + Vector3.new(0, 0.035, 0)),
				Vector3.new(6.5, 0.07, (b - a).Magnitude + 1),
				PATH,
				Enum.Material.Ground,
				false
			)
		end
	end
	for i, tree in Meadow.Trees do
		Meadow.tree(nature, at * CFrame.new(tree[1], 0, tree[2]), tree[3], i * 31)
	end
	-- Wood benches at two quiet outlooks, away from service entrances.
	for _, x in { -128, 125 } do
		local seat = at * CFrame.new(x, 1.6, 14)
		part(nature, "BenchSeat", seat, Vector3.new(8, 0.5, 2.5), WOOD, Enum.Material.Wood, true)
		part(
			nature,
			"BenchBack",
			seat * CFrame.new(0, 1, 1.2),
			Vector3.new(8, 1.5, 0.35),
			WOOD,
			Enum.Material.Wood,
			true
		)
		for _, side in { -3, 3 } do
			part(
				nature,
				"BenchLeg",
				seat * CFrame.new(side, -0.8, 0),
				Vector3.new(0.55, 1.6, 2),
				WOOD,
				Enum.Material.Wood,
				true
			)
		end
	end
	local spots, zones, fieldSpots = {}, {}, {}
	local rng = Random.new(4242)
	for x = -184, 184, 13 do
		for z = -170, 170, 13 do
			local p = point(x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2))
			if Meadow.clear(p) then
				table.insert(spots, at * CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				local starter = (p - point(-44, 6)).Magnitude < 46
				table.insert(zones, if starter then "Common" else "Field")
				if not starter then
					table.insert(fieldSpots, #spots)
				end
			end
		end
	end
	-- Small, static tufts and wildflowers: no per-frame work or mining raycasts.
	for _ = 1, 420 do
		local p = point(rng:NextNumber(-180, 180), rng:NextNumber(-155, 155))
		if not Meadow.clear(p, -3) then
			continue
		end
		local occupied = false
		for _, spot in spots do
			local delta = spot.Position - (at * CFrame.new(p)).Position
			if delta.Magnitude < 4.5 then
				occupied = true
				break
			end
		end
		if occupied then
			continue
		end
		local frame = at * CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		for blade = 1, 2 do
			part(
				nature,
				"GrassTuft",
				frame * CFrame.new((blade - 1.5) * 0.4, 0.4, 0) * CFrame.Angles(0, blade, 0.15),
				Vector3.new(0.16, rng:NextNumber(0.55, 1), 0.65),
				GRASS:Lerp(LEAF, 0.6),
				Enum.Material.Grass,
				false,
				"Wedge"
			)
		end
		if rng:NextNumber() < 0.4 then
			part(
				nature,
				"Wildflower",
				frame * CFrame.new(0, 0.85, 0),
				Vector3.new(0.55, 0.2, 0.55),
				if rng:NextNumber() < 0.55 then Color3.fromRGB(250, 224, 140) else Color3.fromRGB(230, 216, 234),
				Enum.Material.SmoothPlastic,
				false,
				"Ball"
			)
		end
	end
	return { Spots = spots, Zones = zones, FieldSpots = fieldSpots }
end

return Meadow
