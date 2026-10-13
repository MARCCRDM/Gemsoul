-- A daylight sky garden with a pale neighbouring planet at the horizon.
-- Cloud banks sit below the islands; all scenery is static and decorative.
local Orbit = {}
Orbit.Radius = 340
Orbit.Center = Vector3.new(-900, 440, -1550)

local function piece(parent, name, cf, size, color, shape, transparency)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.CFrame, p.Size, p.Color = name, cf, size, color
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function facet(parent, at, a, b, c, color)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
		c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right, back = ac:Cross(ab).Unit, bc.Unit
	local up = bc:Cross(right).Unit
	local height = math.abs(ab:Dot(up))
	piece(
		parent,
		"PlanetLand",
		at * CFrame.fromMatrix((a + b) / 2, right, up, back),
		Vector3.new(1, height, math.abs(ab:Dot(back))),
		color,
		"Wedge"
	)
	piece(
		parent,
		"PlanetLand",
		at * CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Vector3.new(1, height, math.abs(ac:Dot(back))),
		color,
		"Wedge"
	)
end

local function tangent(normal)
	local x = Vector3.new(0, 0, 1):Cross(normal).Unit
	return x, normal:Cross(x).Unit
end

function Orbit.build(parent, at: CFrame)
	local m = Instance.new("Model")
	m.Name = "OrbitalSky"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	-- Turn the detailed hemisphere toward the meadow. The whole planet is a
	-- distant sky landmark now, rather than a huge globe filling the void below.
	local facing = -Orbit.Center.Unit
	local east = Vector3.new(0, 1, 0):Cross(facing).Unit
	local centre = at * CFrame.fromMatrix(Orbit.Center, east, facing, east:Cross(facing))
	local scale = Orbit.Radius / 1000
	local landRadius = Orbit.Radius * 1.01
	piece(m, "PlanetOcean", centre, Vector3.one * (Orbit.Radius * 2), Color3.fromRGB(155, 189, 215), "Ball")
	-- Curved land patches share vertices and sit just above the ocean sphere.
	-- Three rings keep the triangles small enough to follow the globe's curve.
	for index, spec in
		{
			{ Vector3.new(-0.39, 1, 0.18).Unit, 0.33, 0.49, 0.2 },
			{ Vector3.new(0.49, 1, -0.18).Unit, 0.25, 0.38, 1.6 },
			{ Vector3.new(0.18, 1, 0.71).Unit, 0.29, 0.18, 3.1 },
		}
	do
		local normal, rx, rz, phase = spec[1], spec[2], spec[3], spec[4]
		local east, north = tangent(normal)
		local rings = {}
		for ring = 1, 3 do
			local vertices = {}
			for i = 0, 15 do
				local a = i / 16 * math.pi * 2
				local coast = 1 + 0.15 * math.sin(3 * a + phase) + 0.1 * math.cos(5 * a - phase)
				local u, v = math.cos(a) * rx * coast * ring / 3, math.sin(a) * rz * coast * ring / 3
				table.insert(vertices, (normal + east * u + north * v).Unit * landRadius)
			end
			rings[ring] = vertices
		end
		for ring = 1, 3 do
			local color = Color3.fromRGB(164, 189, 182):Lerp(Color3.fromRGB(193, 208, 193), (ring - 1) * 0.16)
			for i = 1, 16 do
				local nextIndex = i % 16 + 1
				local a, b = rings[ring][i], rings[ring][nextIndex]
				if ring == 1 then
					facet(m, centre, normal * landRadius, a, b, color)
				else
					local c, d = rings[ring - 1][i], rings[ring - 1][nextIndex]
					facet(m, centre, a, b, c, color)
					facet(m, centre, b, d, c, color)
				end
			end
		end
	end
	-- Cloud ribbons follow the planet, not the island's walking horizon.
	local rng = Random.new(8113)
	for band = 1, 5 do
		for puff = 1, 5 do
			local normal = Vector3.new(-0.7 + puff * 0.27, 1, -0.85 + band * 0.35 + math.sin(puff * 0.8) * 0.14).Unit
			local east, north = tangent(normal)
			piece(
				m,
				"PlanetCloud",
				centre * CFrame.fromMatrix(normal * (Orbit.Radius * 1.018), east, normal, -north),
				Vector3.new(rng:NextNumber(105, 165), 9, rng:NextNumber(25, 45)) * scale,
				Color3.fromRGB(238, 246, 248),
				"Ball",
				rng:NextNumber(0.35, 0.5)
			)
		end
	end
	piece(
		m,
		"PlanetAtmosphere",
		centre,
		Vector3.one * (Orbit.Radius * 2.028),
		Color3.fromRGB(205, 231, 249),
		"Ball",
		0.96
	)
	piece(m, "PlanetAirglow", centre, Vector3.one * (Orbit.Radius * 2.046), Color3.fromRGB(220, 239, 255), "Ball", 0.98)
	-- Soft, irregular cloud banks below the meadow give the floating land a
	-- friendly horizon. Open gaps keep the sapphire undersides in view.
	for i = 1, 8 do
		local a = i * math.pi / 4 + rng:NextNumber(-0.18, 0.18)
		local distance = rng:NextNumber(430, 660)
		local bank = at
			* CFrame.new(math.cos(a) * distance, rng:NextNumber(-104, -66), math.sin(a) * distance)
			* CFrame.Angles(0, -a + 0.3, 0)
		for puff = 1, 4 do
			piece(
				m,
				"MeadowCloudBank",
				bank * CFrame.new((puff - 2.5) * 45, rng:NextNumber(-3, 7), rng:NextNumber(-14, 14)),
				Vector3.new(rng:NextNumber(90, 140), rng:NextNumber(18, 30), rng:NextNumber(62, 90)),
				Color3.fromRGB(242, 247, 250),
				"Ball",
				rng:NextNumber(0.24, 0.38)
			)
		end
	end
	return m
end

return Orbit
