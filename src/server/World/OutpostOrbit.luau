-- Local scenery at the Outpost: the planet is below the playable island,
-- and every part is decorative. No imported textures or frame callbacks.
local Orbit = {}
Orbit.Radius = 1000
Orbit.Center = Vector3.new(0, -1180, -380)

local function piece(parent, name, cf, size, color, shape, transparency)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.CFrame, p.Size, p.Color = name, cf, size, color
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = if name == "OrbitStar" or name == "PlanetAirglow"
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
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
	local centre = at * CFrame.new(Orbit.Center)
	piece(m, "PlanetOcean", centre, Vector3.one * (Orbit.Radius * 2), Color3.fromRGB(37, 99, 157), "Ball")
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
				table.insert(vertices, (normal + east * u + north * v).Unit * 1010)
			end
			rings[ring] = vertices
		end
		for ring = 1, 3 do
			local color = Color3.fromRGB(101, 142, 101):Lerp(Color3.fromRGB(152, 172, 132), (ring - 1) * 0.16)
			for i = 1, 16 do
				local nextIndex = i % 16 + 1
				local a, b = rings[ring][i], rings[ring][nextIndex]
				if ring == 1 then
					facet(m, centre, normal * 1010, a, b, color)
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
				centre * CFrame.fromMatrix(normal * 1018, east, normal, -north),
				Vector3.new(rng:NextNumber(105, 165), 9, rng:NextNumber(25, 45)),
				Color3.fromRGB(238, 246, 248),
				"Ball",
				rng:NextNumber(0.22, 0.38)
			)
		end
	end
	-- Both spheres remain under Roblox's 2048-stud part-size limit.
	piece(m, "PlanetAtmosphere", centre, Vector3.one * 2028, Color3.fromRGB(91, 182, 235), "Ball", 0.94)
	piece(m, "PlanetAirglow", centre, Vector3.one * 2046, Color3.fromRGB(105, 209, 255), "Ball", 0.96)
	-- Native sky stars are supplemented by a sparse, static constellation field.
	for i = 1, 120 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(-0.12, 0.95)
		local horizontal = math.sqrt(1 - y * y)
		local pos = Vector3.new(math.cos(a) * horizontal, y, math.sin(a) * horizontal) * 1900
		piece(
			m,
			"OrbitStar",
			at * CFrame.new(pos),
			Vector3.one * (if i % 12 == 0 then 3.8 else rng:NextNumber(1.1, 2.2)),
			if i % 7 == 0 then Color3.fromRGB(246, 226, 181) else Color3.fromRGB(204, 223, 245),
			"Ball"
		)
	end
	piece(m, "DistantMoon", at * CFrame.new(950, 530, -1600), Vector3.one * 116, Color3.fromRGB(186, 203, 213), "Ball")
	return m
end

return Orbit
