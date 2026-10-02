--[[
	3D shapes for gems, as plain triangles (no Instances), so they can be
	built into parts by GemArt and tested outside Roblox.

	Every visual comes from the gem's properties:
	  Colour   the gem's shade; fusion stones are two-tone, prismatic stones
	           have rainbow facets
	  Size     overall scale (grade 10 is about twice grade 1)
	  Clarity  how see-through the stone is, plus dark inclusions and a
	           milky cloud inside low-clarity stones; clear stones (7+)
	           glow from a core that brightens with clarity
	  Cut      rough stones are water-worn pebbles shaped by their id; cut
	           stones are round brilliants whose symmetry, proportions and
	           facet count improve with the cut grade, sparkling at 9-10

	GemShapes.build(gem, detailed) returns:
	  {
	    Triangles = { { A, B, C: Vector3, Color: Color3 } },
	    Transparency = number,     -- for every facet
	    Material = "Glass" | "SmoothPlastic",
	    Specks = { { Position: Vector3, Radius: number, Color: Color3, Transparency: number, Glow: boolean? } },
	    Sparkles = { Vector3 },    -- points that get a small glint
	    Radius = number,           -- bounding radius, for framing a camera
	  }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local GemShapes = {}

export type Triangle = { A: Vector3, B: Vector3, C: Vector3, Color: Color3 }

local function seedOf(gem): number
	local seed = 7
	for i = 1, #gem.Id do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	return seed
end

-- Size grade to scale: grade 1 is 0.67, grade 10 is 1.3.
GemShapes.MaxRadius = 1.45 * 1.3 -- the biggest any gem can be, for fixed cameras
function GemShapes.scale(size: number): number
	return 0.6 + 0.07 * math.clamp(size, 1, 10)
end

-- Clarity 1 is nearly opaque and cloudy; clarity 10 is glass-clear.
local function transparencyFor(clarity: number): number
	return 0.02 + (math.clamp(clarity, 1, 10) - 1) * 0.062
end

-- Low-clarity stones look frosted: their colour is washed toward milky white.
local function frosted(color: Color3, clarity: number): Color3
	return color:Lerp(Color3.fromRGB(235, 235, 235), (10 - math.clamp(clarity, 1, 10)) * 0.035)
end

-- Picks each facet's colour from the gem's shade.
local function colorer(shade)
	if shade.Prismatic then
		return function(centroid: Vector3): Color3
			local hue = (math.atan2(centroid.Z, centroid.X) / (2 * math.pi) + 0.5 + centroid.Y * 0.15) % 1
			return Color3.fromHSV(hue, 0.55, 1):Lerp(shade.Color, 0.6)
		end
	elseif shade.Color2 then
		return function(centroid: Vector3): Color3
			return if centroid.Y > 0 then shade.Color else shade.Color2
		end
	end
	return function(): Color3
		return shade.Color
	end
end

-- Inclusions: dark specks and a milky cloud, more of them at low clarity.
local function inclusions(rng: Random, clarity: number, radius: number, color: Color3)
	local specks = {}
	local count = math.max(0, 7 - clarity)
	for _ = 1, count do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-1, 1))
		table.insert(specks, {
			Position = direction.Unit * rng:NextNumber(0.1, 0.5) * radius,
			Radius = rng:NextNumber(0.04, 0.09) * radius,
			Color = Color3.fromRGB(40, 34, 30),
			Transparency = 0.1,
		})
	end
	if clarity <= 6 then
		table.insert(specks, {
			Position = Vector3.new(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)) * radius,
			Radius = (0.2 + (6 - clarity) * 0.06) * radius,
			Color = color:Lerp(Color3.new(1, 1, 1), 0.6),
			Transparency = 0.45,
		})
	end
	return specks
end

-- Rough stones -------------------------------------------------------------------

-- An icosphere: an icosahedron with each face split into four, on the unit sphere.
local function icosphere(): ({ Vector3 }, { { number } })
	local t = (1 + math.sqrt(5)) / 2
	local vertices = {
		Vector3.new(-1, t, 0),
		Vector3.new(1, t, 0),
		Vector3.new(-1, -t, 0),
		Vector3.new(1, -t, 0),
		Vector3.new(0, -1, t),
		Vector3.new(0, 1, t),
		Vector3.new(0, -1, -t),
		Vector3.new(0, 1, -t),
		Vector3.new(t, 0, -1),
		Vector3.new(t, 0, 1),
		Vector3.new(-t, 0, -1),
		Vector3.new(-t, 0, 1),
	}
	for i, v in vertices do
		vertices[i] = v.Unit
	end
	local faces = {
		{ 1, 12, 6 },
		{ 1, 6, 2 },
		{ 1, 2, 8 },
		{ 1, 8, 11 },
		{ 1, 11, 12 },
		{ 2, 6, 10 },
		{ 6, 12, 5 },
		{ 12, 11, 3 },
		{ 11, 8, 7 },
		{ 8, 2, 9 },
		{ 4, 10, 5 },
		{ 4, 5, 3 },
		{ 4, 3, 7 },
		{ 4, 7, 9 },
		{ 4, 9, 10 },
		{ 5, 10, 6 },
		{ 3, 5, 12 },
		{ 7, 3, 11 },
		{ 9, 7, 8 },
		{ 10, 9, 2 },
	}
	local midpoints = {}
	local function midpoint(i: number, j: number): number
		local key = if i < j then i .. ":" .. j else j .. ":" .. i
		if not midpoints[key] then
			table.insert(vertices, ((vertices[i] + vertices[j]) / 2).Unit)
			midpoints[key] = #vertices
		end
		return midpoints[key]
	end
	local split = {}
	for _, f in faces do
		local a, b, c = midpoint(f[1], f[2]), midpoint(f[2], f[3]), midpoint(f[3], f[1])
		table.insert(split, { f[1], a, c })
		table.insert(split, { f[2], b, a })
		table.insert(split, { f[3], c, b })
		table.insert(split, { a, b, c })
	end
	return vertices, split
end

local function roughStone(gem, shade)
	local rng = Random.new(seedOf(gem))
	local scale = GemShapes.scale(gem.Size)
	-- A water-worn pebble: stretched, flattened and lumpy, different for
	-- every stone. A few broad bulges give the overall shape; a little
	-- per-vertex noise roughens the surface.
	local radii = Vector3.new(rng:NextNumber(1, 1.25), rng:NextNumber(0.55, 0.78), rng:NextNumber(0.68, 0.92))
	local bulges = {}
	for i = 1, 3 do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1))
		bulges[i] = { Direction = direction.Unit, Amount = rng:NextNumber(-0.22, 0.28) }
	end
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25))
	local vertices, faces = icosphere()
	local shaped = {}
	for i, v in vertices do
		local r = 1 + rng:NextNumber(-0.045, 0.045)
		for _, bulge in bulges do
			r += bulge.Amount * math.max(0, v:Dot(bulge.Direction)) ^ 2
		end
		shaped[i] = tilt * (v * radii * r * scale)
	end
	local colorOf = colorer(shade)
	local triangles = {}
	for _, f in faces do
		local a, b, c = shaped[f[1]], shaped[f[2]], shaped[f[3]]
		-- Natural stones vary a little in tone across their surface.
		local tone = frosted(colorOf((a + b + c) / 3), gem.Clarity)
		tone = tone:Lerp(
			if rng:NextNumber() < 0.5 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
			rng:NextNumber(0, 0.07)
		)
		table.insert(triangles, { A = a, B = b, C = c, Color = tone })
	end
	return {
		Triangles = triangles,
		Transparency = transparencyFor(gem.Clarity),
		Material = "Glass",
		Specks = inclusions(rng, gem.Clarity, 0.8 * scale, shade.Color),
		Sparkles = {},
		Radius = 1.45 * scale,
	}
end

-- Cut stones -----------------------------------------------------------------------

--[[
	A round brilliant, table facing up (+Y), girdle at y = 0:
	  table     flat polygon on top
	  crown     angled facets from the table down to the girdle
	  pavilion  facets narrowing to the culet point underneath
	Poor cuts are lopsided with a shallow pavilion and oversized table;
	good cuts are symmetrical with ideal proportions.
]]
local function cutStone(gem, shade, detailed: boolean)
	local rng = Random.new(seedOf(gem) + 1)
	local cut = math.clamp(gem.Cut or 1, 1, 10)
	local scale = GemShapes.scale(gem.Size)
	local sides = if detailed and cut >= 9 then 12 else 8
	local quality = (cut - 1) / 9 -- 0 = crude, 1 = perfect
	local wobble = (1 - quality) * 0.11 -- random error in every vertex

	local radius = 1
	local tableRadius = 0.66 - 0.11 * quality -- ideal table is ~55% of the width
	local crownHeight = 0.24 + 0.1 * quality
	local midRadius = 0.5
	local midDepth = -(0.3 + 0.15 * quality)
	local culetDepth = -(0.55 + 0.31 * quality) -- ideal pavilion is ~43% of the width

	local function jitter(v: Vector3): Vector3
		if wobble <= 0 then
			return v * scale
		end
		return (v + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * wobble)
			* scale
	end
	local function ring(r: number, y: number, offset: number): { Vector3 }
		local points = {}
		for k = 0, sides - 1 do
			local angle = (k + offset) / sides * 2 * math.pi
			points[k + 1] = jitter(Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r))
		end
		return points
	end

	local girdle = ring(radius, 0, 0)
	local tableRing = ring(tableRadius, crownHeight, 0.5)
	local pavilion = ring(midRadius, midDepth, 0.5)
	local top = jitter(Vector3.new(0, crownHeight, 0))
	local culet = jitter(Vector3.new(0, culetDepth, 0))

	local colorOf = colorer(shade)
	local triangles = {}
	local function add(a: Vector3, b: Vector3, c: Vector3)
		table.insert(triangles, { A = a, B = b, C = c, Color = frosted(colorOf((a + b + c) / 3), gem.Clarity) })
	end
	for k = 1, sides do
		local n = k % sides + 1
		add(top, tableRing[k], tableRing[n]) -- table
		add(tableRing[k], girdle[k], girdle[n]) -- crown: bezel
		add(tableRing[k], girdle[n], tableRing[n]) -- crown: star
		add(girdle[k], pavilion[k], girdle[n]) -- pavilion: upper
		add(pavilion[k], girdle[n], pavilion[n]) -- pavilion: upper
		add(pavilion[k], culet, pavilion[n]) -- pavilion: main
	end

	local sparkles = {}
	if cut >= 9 then
		local count = if cut >= 10 then 5 else 3
		for i = 1, count do
			local k = (i * 3) % sides + 1
			table.insert(sparkles, (tableRing[k] + girdle[k]) / 2 + Vector3.new(0, 0.05, 0))
		end
	end

	local specks = inclusions(rng, gem.Clarity, 0.6 * scale, shade.Color)
	if gem.Clarity >= 7 then
		-- Clear stones glow from within; the clearer, the brighter the core.
		table.insert(specks, {
			Position = Vector3.zero,
			Radius = 0.28 * scale,
			Color = shade.Color:Lerp(Color3.new(1, 1, 1), 0.25),
			Transparency = 0.75 - (math.clamp(gem.Clarity, 7, 10) - 7) * 0.1,
			Glow = true,
		})
	end
	return {
		Triangles = triangles,
		Transparency = transparencyFor(gem.Clarity) * 0.8,
		Material = "Glass",
		Specks = specks,
		Sparkles = sparkles,
		Radius = 1.1 * scale,
	}
end

function GemShapes.build(gem, detailed: boolean?)
	local shade = GemConfig.shade(gem)
	if gem.Cut then
		return cutStone(gem, shade, detailed == true)
	end
	return roughStone(gem, shade)
end

--[[
	Two wedges that together fill triangle a-b-c (the standard technique for
	drawing any triangle with Roblox parts). Returns two { CFrame, Size }.
]]
function GemShapes.wedges(a: Vector3, b: Vector3, c: Vector3, thickness: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	-- Make b-c the longest edge.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	return {
		CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back),
		Size = Vector3.new(thickness, height, math.abs(ab:Dot(back))),
	}, {
		CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Size = Vector3.new(thickness, height, math.abs(ac:Dot(back))),
	}
end

return GemShapes
