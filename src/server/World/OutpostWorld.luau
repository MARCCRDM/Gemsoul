--[[
	Saga Outpost's world, built by the server so everyone shares it: a wide
	crater basin on the moon, ringed by jagged rim rock, with a working
	frontier outpost at its north edge (landing pad and shuttle, habitat
	modules strung on tubes, a refinery tower, a drill rig over its pit,
	conveyors, pipes and floodlight masts), the crashed Probe that serves as
	the market, the leaderboard billboard by the landing pad, the Arena
	Uplink gate, and planets hanging in the black sky.

	  OutpostWorld.build(at, parent) -> {
	      Model, Spawn (CFrame), Probe (BasePart, the terminal),
	      Board (BasePart with the leaderboard's face), Gate (BasePart),
	      Spots ({ CFrame }, where rocks may grow) }
	  OutpostWorld.rock(size, cframe, rng) -> Model   one rock of that size
	      (Shared.Outpost.Sizes), its main chunk named "Body"
]]
local OutpostWorld = {}

local REGOLITH = Color3.fromRGB(122, 124, 132)
local REGOLITH_DARK = Color3.fromRGB(78, 80, 90)
local RIM = Color3.fromRGB(96, 94, 104)
local HULL = Color3.fromRGB(196, 200, 208)
local HULL_DARK = Color3.fromRGB(58, 62, 72)
local HAZARD = Color3.fromRGB(240, 178, 48)
local GLOW = Color3.fromRGB(110, 220, 255)
local SAGA = Color3.fromRGB(255, 184, 72)
local STEEL = Color3.fromRGB(150, 158, 170)

local function part(parent, cframe, size, color, material, shape, props)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 2
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end
local function solid(p)
	p.CanCollide = true
	p.CanQuery = true
	return p
end
local function light(p, color, range, brightness, spot)
	local l = Instance.new(if spot then "SpotLight" else "PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	if spot then
		(l :: SpotLight).Face = Enum.NormalId.Bottom;
		(l :: SpotLight).Angle = 70
	end
	l.Parent = p
	return l
end
local function folder(parent, name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end
-- A horizontal disc (a cylinder on its side).
local function disc(parent, at: CFrame, radius: number, height: number, color, material)
	return part(
		parent,
		at * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(height, radius * 2, radius * 2),
		color,
		material,
		"Cylinder"
	)
end

-- One rock: a heap of tilted slabs with crystals breaking through, sized and
-- coloured by its kind.
function OutpostWorld.rock(size: string, cframe: CFrame, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Rock"
	local spec = ({
		Pebble = { 3.6, Color3.fromRGB(128, 126, 134), GLOW, 3 },
		Boulder = { 6, Color3.fromRGB(104, 106, 120), GLOW, 6 },
		Monolith = { 8.5, Color3.fromRGB(84, 82, 96), SAGA, 9 },
		Geode = { 7, Color3.fromRGB(70, 56, 92), Color3.fromRGB(205, 120, 255), 11 },
	})[size] or { 3, REGOLITH, GLOW, 2 }
	local s, stone, crystal, crystals = spec[1], spec[2], spec[3], spec[4]
	local tall = if size == "Monolith" then 1.7 else 1
	local body = part(
		model,
		cframe
			* CFrame.new(0, s * 0.42 * tall, 0)
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)),
		Vector3.new(s, s * 0.85 * tall, s * 0.9),
		stone,
		Enum.Material.Slate
	)
	body.Name = "Body"
	solid(body)
	model.PrimaryPart = body
	-- Lumps around it, so it never reads as a box.
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = s * rng:NextNumber(0.3, 0.5)
		part(
			model,
			cframe
				* CFrame.new(math.cos(a) * r, s * rng:NextNumber(0.2, 0.5) * tall, math.sin(a) * r)
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(-0.6, 0.6)),
			Vector3.new(
				s * rng:NextNumber(0.45, 0.7),
				s * rng:NextNumber(0.4, 0.65) * tall,
				s * rng:NextNumber(0.45, 0.7)
			),
			stone:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.2)),
			Enum.Material.Slate
		)
	end
	-- Crystals: wedges jutting out of the top and sides, glowing.
	for i = 1, crystals do
		local a = rng:NextNumber(0, math.pi * 2)
		local up = rng:NextNumber(0.45, 1.0)
		local len = s * rng:NextNumber(0.28, 0.55)
		local c = part(
			model,
			cframe
				* CFrame.new(math.cos(a) * s * 0.3, s * up * tall, math.sin(a) * s * 0.3)
				* CFrame.Angles(0, -a, 0)
				* CFrame.Angles(0, 0, -rng:NextNumber(0.2, 0.9)),
			Vector3.new(len * 0.32, len, len * 0.32),
			crystal,
			if i % 3 == 0 then Enum.Material.Glass else Enum.Material.Neon,
			"Wedge"
		)
		c.Name = "Crystal"
		c.Transparency = if c.Material == Enum.Material.Glass then 0.2 else 0
	end
	if size == "Geode" then
		local core = part(
			model,
			cframe * CFrame.new(0, s * 0.55, 0),
			Vector3.one * s * 0.45,
			Color3.fromRGB(255, 200, 255),
			Enum.Material.Neon,
			"Ball"
		)
		core.Name = "Crystal"
	end
	light(body, crystal, s * 3, if size == "Geode" then 2.4 else 1.1)
	return model
end

local function rimRock(parent, at: CFrame, rng: Random)
	local h = rng:NextNumber(18, 60)
	local w = rng:NextNumber(18, 36)
	part(
		parent,
		at
			* CFrame.new(0, h / 2 - 4, 0)
			* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.25, 0.25)),
		Vector3.new(w, h, rng:NextNumber(14, 26)),
		RIM:Lerp(REGOLITH_DARK, rng:NextNumber(0, 0.6)),
		Enum.Material.Slate
	)
end

local function crater(parent, at: CFrame, radius: number)
	disc(parent, at * CFrame.new(0, 0.12, 0), radius, 0.3, REGOLITH_DARK, Enum.Material.Slate)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part(
			parent,
			at * CFrame.new(math.cos(a) * radius, 0.4, math.sin(a) * radius) * CFrame.Angles(0, -a, 0),
			Vector3.new(radius * 0.3, 1.1, radius * 0.6),
			REGOLITH,
			Enum.Material.Slate
		)
	end
end

local function mast(parent, at: CFrame, color: Color3)
	part(parent, at * CFrame.new(0, 11, 0), Vector3.new(0.9, 22, 0.9), HULL_DARK, Enum.Material.Metal)
	part(parent, at * CFrame.new(0, 1, 0), Vector3.new(3, 2, 3), HAZARD, Enum.Material.Metal)
	local head = part(
		parent,
		at * CFrame.new(0, 22.5, 0) * CFrame.Angles(math.rad(-25), 0, 0),
		Vector3.new(3.6, 1.2, 2.2),
		HULL_DARK,
		Enum.Material.Metal
	)
	local lamp =
		part(parent, head.CFrame * CFrame.new(0, -0.65, 0), Vector3.new(3, 0.2, 1.7), color, Enum.Material.Neon)
	light(lamp, color, 60, 2.2, true)
	local beacon = part(
		parent,
		at * CFrame.new(0, 23.6, 0),
		Vector3.one * 0.7,
		Color3.fromRGB(255, 70, 60),
		Enum.Material.Neon,
		"Ball"
	)
	beacon.Name = "Beacon"
end

-- A horizontal habitat module with a row of lit windows.
local function habitat(parent, at: CFrame, length: number)
	part(parent, at * CFrame.new(0, 5, 0), Vector3.new(length, 9, 9), HULL, Enum.Material.SmoothPlastic, "Cylinder")
	for _, side in { -1, 1 } do
		part(
			parent,
			at * CFrame.new(side * (length / 2 + 0.2), 5, 0),
			Vector3.new(0.8, 7, 7),
			HULL_DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
	part(parent, at * CFrame.new(0, 5.4, -4.35), Vector3.new(length * 0.8, 1.1, 0.3), GLOW, Enum.Material.Neon)
	part(
		parent,
		at * CFrame.new(0, 2.8, -4.1),
		Vector3.new(length * 0.9, 0.35, 0.4),
		HAZARD,
		Enum.Material.SmoothPlastic
	)
	for x = -length / 2 + 3, length / 2 - 3, 6 do
		part(parent, at * CFrame.new(x, 0.6, 0), Vector3.new(1, 1.6, 7), HULL_DARK, Enum.Material.Metal)
	end
	solid(part(parent, at * CFrame.new(0, 5, 0), Vector3.new(length, 9, 8), HULL, nil, nil, { Transparency = 1 }))
end

local function tube(parent, from: Vector3, to: Vector3, radius: number, color: Color3)
	local mid, len = (from + to) / 2, (to - from).Magnitude
	part(
		parent,
		CFrame.lookAt(mid, to) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(len, radius * 2, radius * 2),
		color,
		Enum.Material.Metal,
		"Cylinder"
	)
end

-- The crashed probe: a battered sphere half in the dust, solar wings bent,
-- its screens woken up as a trading terminal.
local function probe(parent, at: CFrame)
	local m = folder(parent, "Probe")
	local tilt = at * CFrame.Angles(math.rad(14), 0, math.rad(-9))
	solid(
		part(
			m,
			tilt * CFrame.new(0, 6, 0),
			Vector3.one * 18,
			Color3.fromRGB(150, 140, 120),
			Enum.Material.DiamondPlate,
			"Ball"
		)
	)
	part(
		m,
		tilt * CFrame.new(0, 6, 0),
		Vector3.new(19, 2, 19),
		Color3.fromRGB(196, 150, 60),
		Enum.Material.Metal,
		"Cylinder",
		{ CFrame = tilt * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)) }
	)
	-- Scorched dust heaped where it hit.
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		part(
			m,
			at * CFrame.new(math.cos(a) * 10, 0.6, math.sin(a) * 10) * CFrame.Angles(0, -a, 0.3),
			Vector3.new(6, 2.4, 8),
			Color3.fromRGB(70, 66, 70),
			Enum.Material.Slate
		)
	end
	-- Bent solar wings.
	for _, side in { -1, 1 } do
		local wing = tilt * CFrame.new(side * 13, 9, 0) * CFrame.Angles(math.rad(side * 18), 0, math.rad(side * 24))
		part(m, wing, Vector3.new(12, 0.4, 7), Color3.fromRGB(40, 60, 110), Enum.Material.Glass)
		for k = -2, 2 do
			part(m, wing * CFrame.new(k * 2.3, 0.25, 0), Vector3.new(0.15, 0.1, 7), STEEL, Enum.Material.Metal)
		end
		part(m, tilt * CFrame.new(side * 8.5, 9, 0), Vector3.new(4, 0.6, 0.6), STEEL, Enum.Material.Metal)
	end
	-- Antenna mast and dish.
	part(m, tilt * CFrame.new(-3, 18, 2), Vector3.new(0.5, 9, 0.5), STEEL, Enum.Material.Metal)
	part(
		m,
		tilt * CFrame.new(-3, 22.5, 2) * CFrame.Angles(math.rad(35), 0, 0),
		Vector3.new(0.6, 5, 5),
		HULL,
		Enum.Material.Metal,
		"Cylinder",
		{ CFrame = tilt * CFrame.new(-3, 22.5, 2) * CFrame.Angles(math.rad(35), 0, math.rad(90)) }
	)
	-- The terminal: a lit console bolted to its face.
	local console = solid(part(m, at * CFrame.new(0, 3, -10.5), Vector3.new(9, 6, 1.4), HULL_DARK, Enum.Material.Metal))
	local screen = part(
		m,
		console.CFrame * CFrame.new(0, 0.6, -0.75),
		Vector3.new(7.6, 3.8, 0.1),
		Color3.fromRGB(20, 40, 60),
		Enum.Material.Neon
	)
	screen.Name = "ProbeScreen"
	part(m, console.CFrame * CFrame.new(0, -2.2, -1.3), Vector3.new(8, 0.5, 2.2), HULL, Enum.Material.Metal)
	light(screen, GLOW, 22, 2.5)
	-- A holo ring turning over it (the client spins it; see OutpostScene).
	local ring = part(
		m,
		at * CFrame.new(0, 22, 0),
		Vector3.new(0.4, 22, 22),
		GLOW,
		Enum.Material.Neon,
		"Cylinder",
		{ Transparency = 0.55 }
	)
	ring.CFrame = at * CFrame.new(0, 22, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Name = "ProbeRing"
	-- Cables from the probe into the ground.
	for i = 1, 3 do
		local a = math.rad(200 + i * 40)
		tube(
			m,
			(tilt * CFrame.new(0, 3, 0)).Position,
			(at * CFrame.new(math.cos(a) * 16, 0.3, math.sin(a) * 16)).Position,
			0.35,
			Color3.fromRGB(30, 30, 36)
		)
	end
	return screen
end

-- The leaderboard: a tall twin-panel billboard on legs.
local function billboard(parent, at: CFrame)
	local m = folder(parent, "Leaderboard")
	for _, x in { -13, 13 } do
		part(m, at * CFrame.new(x, 9, 0), Vector3.new(1.2, 18, 1.2), HULL_DARK, Enum.Material.Metal)
		part(m, at * CFrame.new(x, 0.5, 0), Vector3.new(3, 1, 3), HAZARD, Enum.Material.Metal)
	end
	local frame = part(m, at * CFrame.new(0, 17, 0.3), Vector3.new(30, 15, 0.6), HULL_DARK, Enum.Material.Metal)
	local face = part(
		m,
		at * CFrame.new(0, 17, -0.05),
		Vector3.new(28.5, 13.5, 0.2),
		Color3.fromRGB(10, 16, 28),
		Enum.Material.SmoothPlastic
	)
	face.Name = "BoardFace"
	part(m, frame.CFrame * CFrame.new(0, 7.8, 0), Vector3.new(30.4, 0.6, 0.9), GLOW, Enum.Material.Neon)
	light(face, GLOW, 26, 1.2)
	return face
end

-- The Arena Uplink: a ring gate on a pad, for queuing duels.
local function gate(parent, at: CFrame)
	local m = folder(parent, "ArenaGate")
	disc(m, at * CFrame.new(0, 0.4, 0), 9, 0.8, HULL_DARK, Enum.Material.Metal)
	disc(m, at * CFrame.new(0, 0.85, 0), 7, 0.1, Color3.fromRGB(255, 70, 90), Enum.Material.Neon)
	local ring = part(
		m,
		at * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(1.4, 17, 17),
		HULL,
		Enum.Material.Metal,
		"Cylinder"
	)
	part(
		m,
		ring.CFrame,
		Vector3.new(1.0, 15, 15),
		Color3.fromRGB(255, 70, 90),
		Enum.Material.Neon,
		"Cylinder",
		{ Transparency = 0.45 }
	)
	local pad =
		part(m, at * CFrame.new(0, 2, 0), Vector3.new(6, 4, 6), Color3.new(1, 1, 1), nil, nil, { Transparency = 1 })
	pad.Name = "GatePad"
	light(pad, Color3.fromRGB(255, 70, 90), 24, 2)
	return pad
end

-- Planets and stars, far off in the black.
local function sky(parent, at: CFrame)
	local m = folder(parent, "Sky")
	pcall(function()
		(m :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	-- A ringed gas giant filling a corner of the sky.
	local giant = at * CFrame.new(-900, 520, -1500)
	part(m, giant, Vector3.one * 760, Color3.fromRGB(214, 150, 96), Enum.Material.SmoothPlastic, "Ball")
	for i, band in
		{
			{ 120, Color3.fromRGB(176, 108, 70) },
			{ -60, Color3.fromRGB(236, 196, 140) },
			{ 200, Color3.fromRGB(160, 96, 64) },
		}
	do
		part(
			m,
			giant * CFrame.new(0, band[1], 0) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(40 + i * 6, 752 - math.abs(band[1]) * 0.5, 752 - math.abs(band[1]) * 0.5),
			band[2],
			Enum.Material.SmoothPlastic,
			"Cylinder"
		)
	end
	part(
		m,
		giant * CFrame.Angles(math.rad(16), 0, math.rad(90 + 8)),
		Vector3.new(4, 1400, 1400),
		Color3.fromRGB(230, 200, 150),
		Enum.Material.SmoothPlastic,
		"Cylinder",
		{ Transparency = 0.45 }
	)
	-- A blue home world, and a little red moon.
	local home = at * CFrame.new(1100, 380, -1300)
	part(m, home, Vector3.one * 260, Color3.fromRGB(56, 120, 220), Enum.Material.SmoothPlastic, "Ball")
	part(
		m,
		home * CFrame.new(-30, 40, 40),
		Vector3.new(200, 120, 160),
		Color3.fromRGB(80, 170, 100),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(
		m,
		home,
		Vector3.one * 272,
		Color3.fromRGB(150, 210, 255),
		Enum.Material.SmoothPlastic,
		"Ball",
		{ Transparency = 0.8 }
	)
	part(
		m,
		at * CFrame.new(300, 700, -1700),
		Vector3.one * 90,
		Color3.fromRGB(190, 90, 70),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	-- Stars on a big dome.
	local rng = Random.new(77)
	for _ = 1, 260 do
		local a, e = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.12, 1.4)
		local d = 1700
		local p = at * CFrame.new(math.cos(a) * math.cos(e) * d, math.sin(e) * d, math.sin(a) * math.cos(e) * d)
		part(m, p, Vector3.one * rng:NextNumber(2, 6), Color3.fromRGB(230, 236, 255), Enum.Material.Neon, "Ball")
	end
end

function OutpostWorld.build(at: CFrame, parent: Instance)
	local root = Instance.new("Model")
	root.Name = "SagaOutpost"
	local rng = Random.new(4242)
	local ground = folder(root, "Ground")
	-- The basin floor and its regolith, with walls off its edge so no one wanders off.
	solid(disc(ground, at * CFrame.new(0, -1, 0), 200, 2, REGOLITH, Enum.Material.Slate))
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, 170)
		disc(
			ground,
			at * CFrame.new(math.cos(a) * r, 0.05, math.sin(a) * r),
			rng:NextNumber(8, 26),
			0.1,
			REGOLITH:Lerp(REGOLITH_DARK, rng:NextNumber(0.1, 0.5)),
			Enum.Material.Sand
		)
	end
	for _, c in { { 60, 40, 11 }, { -70, 60, 15 }, { 95, -20, 8 }, { -40, -10, 7 }, { 20, 100, 13 }, { -110, -50, 10 } } do
		crater(ground, at * CFrame.new(c[1], 0, c[2]), c[3])
	end
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local r = rng:NextNumber(168, 190)
		rimRock(ground, at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng)
	end
	local fence = Instance.new("Part")
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local w = solid(
			part(
				ground,
				at * CFrame.new(math.cos(a) * 166, 20, math.sin(a) * 166) * CFrame.Angles(0, -a, 0),
				Vector3.new(4, 40, 46),
				RIM,
				nil,
				nil,
				{ Transparency = 1 }
			)
		)
		w.CastShadow = false
	end
	fence:Destroy()

	-- The outpost along the north edge.
	local base = folder(root, "Outpost")
	local north = at * CFrame.new(0, 0, -110)
	-- Landing pad and shuttle (south of the habitats: where people arrive).
	local padAt = at * CFrame.new(0, 0, 70)
	solid(disc(base, padAt * CFrame.new(0, 0.5, 0), 20, 1, HULL_DARK, Enum.Material.DiamondPlate))
	disc(base, padAt * CFrame.new(0, 1.05, 0), 16, 0.1, HAZARD, Enum.Material.SmoothPlastic)
	disc(base, padAt * CFrame.new(0, 1.1, 0), 14.6, 0.1, HULL_DARK, Enum.Material.DiamondPlate)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local lamp = part(
			base,
			padAt * CFrame.new(math.cos(a) * 19, 1.3, math.sin(a) * 19),
			Vector3.new(1, 0.5, 1),
			GLOW,
			Enum.Material.Neon
		)
		if i % 2 == 0 then
			light(lamp, GLOW, 14, 1)
		end
	end
	local ship = padAt * CFrame.new(28, 0, 6) * CFrame.Angles(0, math.rad(-30), 0)
	part(base, ship * CFrame.new(0, 6, 0), Vector3.new(26, 7, 9), HULL, Enum.Material.SmoothPlastic, "Cylinder")
	part(base, ship * CFrame.new(13, 6.4, 0), Vector3.new(6, 5, 7), HULL, Enum.Material.SmoothPlastic, "Ball")
	part(
		base,
		ship * CFrame.new(14.2, 7.2, 0),
		Vector3.new(3.4, 2.4, 5),
		Color3.fromRGB(40, 90, 140),
		Enum.Material.Glass,
		"Ball"
	)
	for _, side in { -1, 1 } do
		part(
			base,
			ship * CFrame.new(-3, 5.2, side * 8),
			Vector3.new(12, 0.8, 9),
			HULL_DARK,
			Enum.Material.Metal,
			"Wedge",
			{
				CFrame = ship
					* CFrame.new(-3, 5.2, side * 8)
					* CFrame.Angles(0, math.rad(if side > 0 then 90 else -90), 0),
			}
		)
		part(
			base,
			ship * CFrame.new(-12, 6, side * 2.6),
			Vector3.new(3, 3, 3),
			HULL_DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
		part(
			base,
			ship * CFrame.new(-13.6, 6, side * 2.6),
			Vector3.new(0.3, 2.4, 2.4),
			Color3.fromRGB(255, 150, 70),
			Enum.Material.Neon,
			"Cylinder"
		)
		for _, x in { -8, 6 } do
			part(base, ship * CFrame.new(x, 1.5, side * 3.5), Vector3.new(0.6, 3, 0.6), STEEL, Enum.Material.Metal)
		end
	end
	part(base, ship * CFrame.new(0, 6.2, -4.55), Vector3.new(18, 0.6, 0.2), HAZARD, Enum.Material.SmoothPlastic)
	-- Habitats strung on tubes.
	local habs = {
		north * CFrame.new(-36, 0, 6),
		north * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.rad(90), 0),
		north * CFrame.new(36, 0, 6),
	}
	for _, h in habs do
		habitat(base, h, 26)
	end
	tube(base, (habs[1] * CFrame.new(13, 5, 0)).Position, (habs[2] * CFrame.new(0, 5, 0)).Position, 2, HULL)
	tube(base, (habs[3] * CFrame.new(-13, 5, 0)).Position, (habs[2] * CFrame.new(0, 5, 0)).Position, 2, HULL)
	-- The refinery tower, with catwalk rings and a stack.
	local tower = north * CFrame.new(-70, 0, -18)
	for i = 0, 4 do
		local r = 9 - i * 1.2
		part(
			base,
			tower * CFrame.new(0, 4 + i * 8, 0),
			Vector3.new(8, r * 2, r * 2),
			if i % 2 == 0 then HULL else STEEL,
			Enum.Material.Metal,
			"Cylinder",
			{ CFrame = tower * CFrame.new(0, 4 + i * 8, 0) * CFrame.Angles(0, 0, math.rad(90)) }
		)
		disc(base, tower * CFrame.new(0, 8 + i * 8, 0), r + 1.6, 0.4, HULL_DARK, Enum.Material.DiamondPlate)
		local lampRing = disc(base, tower * CFrame.new(0, 8.3 + i * 8, 0), r + 1.65, 0.15, HAZARD, Enum.Material.Neon)
		lampRing.Transparency = 0.2
	end
	part(base, tower * CFrame.new(4, 50, 3), Vector3.new(2.4, 22, 2.4), HULL_DARK, Enum.Material.Metal)
	local smoke = part(base, tower * CFrame.new(4, 61.5, 3), Vector3.one, HULL_DARK, nil, nil, { Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate, emitter.Lifetime = 6, NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.Size = NumberSequence.new(3, 14)
	emitter.Transparency = NumberSequence.new(0.6, 1)
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 190, 200))
	emitter.Parent = smoke
	solid(part(base, tower * CFrame.new(0, 20, 0), Vector3.new(16, 40, 16), HULL, nil, nil, { Transparency = 1 }))
	-- The drill rig over its pit, with a glowing bit going down.
	local rig = north * CFrame.new(72, 0, -14)
	crater(base, rig, 10)
	disc(base, rig * CFrame.new(0, 0.3, 0), 7, 0.2, Color3.fromRGB(20, 18, 24), Enum.Material.Slate)
	for _, corner in { { -9, -9 }, { 9, -9 }, { -9, 9 }, { 9, 9 } } do
		part(
			base,
			rig
				* CFrame.new(corner[1] * 0.6, 14, corner[2] * 0.6)
				* CFrame.Angles(math.rad(corner[2] * -1), 0, math.rad(corner[1])),
			Vector3.new(1, 30, 1),
			HAZARD,
			Enum.Material.Metal
		)
	end
	part(base, rig * CFrame.new(0, 28, 0), Vector3.new(14, 2, 14), HULL_DARK, Enum.Material.Metal)
	part(base, rig * CFrame.new(0, 16, 0), Vector3.new(2.2, 24, 2.2), STEEL, Enum.Material.Metal)
	local bit = part(base, rig * CFrame.new(0, 3, 0), Vector3.new(4, 4, 4), SAGA, Enum.Material.Neon, "Ball")
	light(bit, SAGA, 30, 2)
	-- Conveyors from the rig to the refinery, and pipes along the ground.
	tube(base, (rig * CFrame.new(-8, 4, 0)).Position, (habs[3] * CFrame.new(10, 4, -8)).Position, 0.8, STEEL)
	for i = 0, 1 do
		local y = 1 + i * 1.6
		tube(
			base,
			(tower * CFrame.new(10, y, 6)).Position,
			(habs[1] * CFrame.new(-14, y, 0)).Position,
			0.6,
			if i == 0 then HULL_DARK else HAZARD
		)
	end
	-- Floodlight masts around the basin.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		mast(
			base,
			at * CFrame.new(math.cos(a) * 130, 0, math.sin(a) * 130) * CFrame.Angles(0, -a + math.rad(90), 0),
			if i % 2 == 0 then Color3.fromRGB(255, 236, 200) else GLOW
		)
	end
	-- A solar array to the north-west, rows of tilted panels.
	local solar = at * CFrame.new(-95, 0, -60) * CFrame.Angles(0, math.rad(30), 0)
	for row = -2, 2 do
		for col = -1, 1 do
			local panelAt = solar * CFrame.new(col * 13, 0, row * 9)
			part(base, panelAt * CFrame.new(0, 2, 0), Vector3.new(0.5, 4, 0.5), STEEL, Enum.Material.Metal)
			local panel = part(
				base,
				panelAt * CFrame.new(0, 4.2, 0) * CFrame.Angles(math.rad(-28), 0, 0),
				Vector3.new(12, 0.3, 6.5),
				Color3.fromRGB(34, 54, 104),
				Enum.Material.Glass
			)
			for k = -2, 2 do
				part(
					base,
					panel.CFrame * CFrame.new(k * 2.4, 0.2, 0),
					Vector3.new(0.1, 0.1, 6.5),
					STEEL,
					Enum.Material.Metal
				)
			end
		end
	end
	-- Fuel tanks to the north-east, with a gantry.
	local tanks = at * CFrame.new(118, 0, -40)
	for i, t in { { -7, 0, 8 }, { 7, 0, 8 }, { 0, 11, 6 } } do
		local tankAt = tanks * CFrame.new(t[1], 0, t[2])
		solid(
			part(
				base,
				tankAt * CFrame.new(0, 9, 0),
				Vector3.new(18, t[3] * 2, t[3] * 2),
				if i == 3 then HAZARD else HULL,
				Enum.Material.SmoothPlastic,
				"Cylinder",
				{ CFrame = tankAt * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)) }
			)
		)
		part(
			base,
			tankAt * CFrame.new(0, 18.4, 0),
			Vector3.new(1, t[3] * 2 - 2, t[3] * 2 - 2),
			HULL_DARK,
			Enum.Material.Metal,
			"Cylinder",
			{ CFrame = tankAt * CFrame.new(0, 18.4, 0) * CFrame.Angles(0, 0, math.rad(90)) }
		)
		part(base, tankAt * CFrame.new(0, 12, -t[3] - 0.1), Vector3.new(t[3] * 1.2, 0.6, 0.2), GLOW, Enum.Material.Neon)
	end
	tube(base, (tanks * CFrame.new(-7, 2, 0)).Position, (habs[3] * CFrame.new(13, 2, 0)).Position, 0.9, HAZARD)
	-- A comms dish on a lattice tower by the habitats.
	local comms = north * CFrame.new(-20, 0, -28)
	for _, c in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		part(base, comms * CFrame.new(c[1], 12, c[2]), Vector3.new(0.5, 24, 0.5), STEEL, Enum.Material.Metal)
	end
	for y = 4, 20, 4 do
		part(base, comms * CFrame.new(0, y, 0), Vector3.new(4.5, 0.3, 4.5), HULL_DARK, Enum.Material.Metal)
	end
	part(
		base,
		comms * CFrame.new(0, 27, 0) * CFrame.Angles(math.rad(-35), 0, math.rad(90)),
		Vector3.new(1.2, 14, 14),
		HULL,
		Enum.Material.SmoothPlastic,
		"Cylinder"
	)
	part(
		base,
		comms * CFrame.new(0, 28.5, -2) * CFrame.Angles(math.rad(-35), 0, 0),
		Vector3.new(0.5, 0.5, 5),
		STEEL,
		Enum.Material.Metal
	)
	local beacon = part(
		base,
		comms * CFrame.new(0, 31, -3.4),
		Vector3.one * 0.8,
		Color3.fromRGB(255, 70, 60),
		Enum.Material.Neon,
		"Ball"
	)
	beacon.Name = "Beacon"
	-- Cargo containers.
	for i, c in { { 46, -50, 0 }, { 46, -50, 1 }, { 60, -48, 0 }, { -56, -36, 0 }, { -110, 10, 0 }, { 112, 70, 0 } } do
		local colors = { HAZARD, Color3.fromRGB(70, 110, 160), Color3.fromRGB(170, 70, 60), STEEL }
		solid(
			part(
				base,
				at * CFrame.new(c[1], 2.4 + c[3] * 4.8, c[2]) * CFrame.Angles(0, math.rad(i * 23), 0),
				Vector3.new(12, 4.8, 5),
				colors[i % #colors + 1],
				Enum.Material.CorrodedMetal
			)
		)
	end
	-- Supply crates stacked about.
	for _, c in { { 24, 50 }, { -26, 46 }, { -50, -70 }, { 54, -66 }, { 100, 30 } } do
		for k = 0, 2 do
			solid(
				part(
					base,
					at
						* CFrame.new(c[1] + (k % 2) * 4.2, 1.6 + (if k == 2 then 3.2 else 0), c[2])
						* CFrame.Angles(0, k * 0.3, 0),
					Vector3.new(4, 3.2, 4),
					if k == 1 then HAZARD else STEEL,
					Enum.Material.DiamondPlate
				)
			)
		end
	end

	-- The Probe (market) on the east side, the leaderboard by the pad, the Arena gate west.
	local probeScreen = probe(root, at * CFrame.new(96, 0, 52) * CFrame.Angles(0, math.rad(-120), 0))
	local face = billboard(root, at * CFrame.new(-36, 0, 40) * CFrame.Angles(0, math.rad(160), 0))
	local gatePad = gate(root, at * CFrame.new(-110, 0, 40))
	sky(root, at)

	-- Where rocks can grow: across the basin, clear of the buildings.
	local keepOut = {
		{ (north).Position, 60 },
		{ (north * CFrame.new(-70, 0, -18)).Position, 18 },
		{ (north * CFrame.new(72, 0, -14)).Position, 18 },
		{ padAt.Position, 40 },
		{ (at * CFrame.new(96, 0, 52)).Position, 24 },
		{ (at * CFrame.new(-36, 0, 40)).Position, 20 },
		{ (at * CFrame.new(-95, 0, -60)).Position, 30 },
		{ (at * CFrame.new(118, 0, -40)).Position, 24 },
		{ (at * CFrame.new(-110, 0, 40)).Position, 16 },
	}
	local spots = {}
	local tries = 0
	while #spots < 70 and tries < 4000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0.02, 1)) * 150
		local p = (at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)).Position
		local ok = true
		for _, k in keepOut do
			if (p - k[1]).Magnitude < k[2] then
				ok = false
				break
			end
		end
		for _, s in spots do
			if (s.Position - p).Magnitude < 9 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(spots, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		end
	end

	root.Parent = parent
	return {
		Model = root,
		Spawn = CFrame.lookAt((padAt * CFrame.new(0, 3.5, 0)).Position, at.Position + Vector3.new(0, 3.5, 0)),
		Probe = probeScreen,
		Board = face,
		Gate = gatePad,
		Spots = spots,
	}
end

return OutpostWorld
