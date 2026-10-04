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
	      Spots ({ CFrame }, where rocks may grow),
	      Parking ({ Kind, CFrame }: the Motor Pool bays for the machines),
	      Secrets ({ BasePart }: the hidden Easter eggs, each with a SecretId) }
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

-- The quarry beyond the outpost --------------------------------------------------------

local DIRT = Color3.fromRGB(92, 86, 84)
local CONCRETE = Color3.fromRGB(86, 90, 98)
local QUARRY = 440 -- where the stepped quarry walls start (Shared.Outpost.Radius)

-- A peak of the mountain range around the quarry.
local function mountain(parent, at: CFrame, rng: Random)
	local h = rng:NextNumber(50, 130)
	local w = rng:NextNumber(34, 74)
	local d = rng:NextNumber(30, 60)
	local color = RIM:Lerp(REGOLITH_DARK, rng:NextNumber(0, 0.7))
	local base = at
		* CFrame.new(0, h / 2 - 6, 0)
		* CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	part(parent, base, Vector3.new(w, h, d), color, Enum.Material.Slate)
	-- A jagged peak: two wedges back to back make a ridge along the top.
	local peak = rng:NextNumber(0.35, 0.8) * w
	for side = -1, 1, 2 do
		part(
			parent,
			base * CFrame.new(0, h / 2 + peak / 2, side * d / 4) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
			Vector3.new(w, peak, d / 2),
			color,
			Enum.Material.Slate,
			"Wedge"
		)
	end
	-- Pale regolith dusting the taller ridges.
	if h + peak > 120 then
		for side = -1, 1, 2 do
			part(
				parent,
				base
					* CFrame.new(0, h / 2 + peak * 0.82, side * d / 16)
					* CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
				Vector3.new(w * 0.99, peak * 0.36, d / 8),
				REGOLITH:Lerp(Color3.new(1, 1, 1), 0.35),
				Enum.Material.Sand,
				"Wedge"
			)
		end
	end
end

-- Three stepped benches cut into the quarry wall, like an open-pit mine,
-- with ramps up each one.
local function benches(parent, at: CFrame)
	for level = 1, 3 do
		local r = QUARRY + level * 9
		local segments = 80
		for i = 0, segments - 1 do
			local a = i / segments * math.pi * 2
			solid(
				part(
					parent,
					at * CFrame.new(math.cos(a) * r, level * 2.5, math.sin(a) * r) * CFrame.Angles(0, -a, 0),
					Vector3.new(9.5, level * 5, 2 * math.pi * r / segments + 1.5),
					if level % 2 == 0 then REGOLITH_DARK else RIM,
					Enum.Material.Slate
				)
			)
		end
		-- A hazard rail along each bench edge.
		for i = 0, 39 do
			local a = (i + 0.5) / 40 * math.pi * 2
			part(
				parent,
				at
					* CFrame.new(math.cos(a) * (r - 4.6), level * 5 + 0.6, math.sin(a) * (r - 4.6))
					* CFrame.Angles(0, -a, 0),
				Vector3.new(0.4, 1.2, 2.4),
				HAZARD,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Ramps from the floor up to each bench, at four points round the wall.
	-- Each runs straight up to its bench's edge, over the lower benches.
	local feet = {}
	for quarter = 0, 3 do
		for level = 1, 3 do
			local a = quarter * math.pi / 2 + math.rad(20) + (level - 1) * math.rad(5)
			local length = 22 * level
			local top = QUARRY + level * 9 - 4.75
			local r = top - length / 2
			local centre = (at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)).Position
			local inward = (at * CFrame.new(math.cos(a) * (r - 10), 0, math.sin(a) * (r - 10))).Position
			-- A wedge's low edge is at its front: face the front inwards.
			solid(
				part(
					parent,
					CFrame.lookAt(centre, inward) * CFrame.new(0, level * 2.5, 0),
					Vector3.new(14, level * 5, length),
					DIRT,
					Enum.Material.Slate,
					"Wedge"
				)
			)
			table.insert(feet, centre)
		end
	end
	return feet
end

-- A dirt haul road from `from` to `to`, with marker posts along it.
local function road(parent, from: Vector3, to: Vector3, width: number)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	part(
		parent,
		CFrame.lookAt(mid, to) * CFrame.new(0, 0.08, 0),
		Vector3.new(width, 0.16, length),
		DIRT,
		Enum.Material.Sand
	)
	local steps = math.floor(length / 50)
	for i = 1, steps do
		local along = from:Lerp(to, i / (steps + 1))
		local side = CFrame.lookAt(along, to) * CFrame.new(if i % 2 == 0 then width / 2 + 2 else -width / 2 - 2, 0, 0)
		part(parent, side * CFrame.new(0, 1.5, 0), Vector3.new(0.6, 3, 0.6), HAZARD, Enum.Material.SmoothPlastic)
		part(parent, side * CFrame.new(0, 3.2, 0), Vector3.new(0.7, 0.4, 0.7), GLOW, Enum.Material.Neon)
	end
end

-- A striped jump ramp for the machines.
local function jumpRamp(parent, at: CFrame)
	solid(
		part(parent, at * CFrame.new(0, 3, 0), Vector3.new(16, 6, 26), HULL_DARK, Enum.Material.DiamondPlate, "Wedge")
	)
	for i = -1, 1, 2 do
		part(
			parent,
			at * CFrame.new(i * 7.6, 3.05, 0) * CFrame.Angles(-math.atan2(6, 26), 0, 0),
			Vector3.new(0.9, 0.2, 26.6),
			HAZARD,
			Enum.Material.SmoothPlastic
		)
	end
end

-- The Motor Pool: a concrete apron with marked bays and a canopy, where the
-- machines park. Returns the parking bays ({ Kind, CFrame }), facing out.
local function motorPool(parent, at: CFrame)
	solid(part(parent, at * CFrame.new(0, 0.4, 0), Vector3.new(140, 0.8, 76), CONCRETE, Enum.Material.Concrete))
	local bays = {
		{ "Hauler", -50, -14 },
		{ "Hauler", -27, -14 },
		{ "Mole", -4, -14 },
		{ "Mole", 18, -14 },
		{ "Digger", 42, -14 },
		{ "Skipper", -20, 20 },
		{ "Skipper", 0, 20 },
		{ "Skipper", 20, 20 },
	}
	local parking = {}
	for _, bay in bays do
		for side = -1, 1, 2 do
			local width = if bay[1] == "Skipper" then 14 else 22
			part(
				parent,
				at * CFrame.new(bay[2] + side * width / 2, 0.85, bay[3]),
				Vector3.new(0.5, 0.1, 30),
				HAZARD,
				Enum.Material.SmoothPlastic
			)
		end
		local spot = at * CFrame.new(bay[2], 1, bay[3])
		table.insert(
			parking,
			{ Kind = bay[1], CFrame = CFrame.lookAt(spot.Position, spot.Position + at.LookVector * -1) }
		)
	end
	-- The canopy over the back row, on yellow pillars, with floodlights.
	for x = -60, 60, 30 do
		part(parent, at * CFrame.new(x, 11, -34), Vector3.new(1.6, 22, 1.6), HAZARD, Enum.Material.Metal)
	end
	part(parent, at * CFrame.new(0, 22.5, -26), Vector3.new(132, 1.2, 20), HULL_DARK, Enum.Material.Metal)
	for x = -54, 54, 18 do
		local lamp = part(parent, at * CFrame.new(x, 21.7, -24), Vector3.new(6, 0.3, 2), GLOW, Enum.Material.Neon)
		light(lamp, GLOW, 34, 1.4, true)
	end
	-- The sign.
	local board = part(parent, at * CFrame.new(0, 27, -34.5), Vector3.new(44, 7, 0.6), HULL_DARK, Enum.Material.Metal)
	board.Name = "MotorPoolSign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(880, 140)
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.62)
	title.Text = "MOTOR POOL"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = HAZARD
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.36)
	sub.Text = "HOP IN AND DRIVE  ·  JUMP TO GET OUT"
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamMedium
	sub.TextColor3 = Color3.fromRGB(220, 235, 255)
	sub.Parent = gui
	-- Fuel drums and tyre stacks round the edge.
	for i = 0, 5 do
		local x = -66 + i * 3.2
		part(
			parent,
			at * CFrame.new(x, 2.6, 34),
			Vector3.new(3.4, 2.6, 2.6),
			Color3.fromRGB(200, 60, 50),
			Enum.Material.Metal,
			"Cylinder",
			{
				CFrame = at * CFrame.new(x, 2.6, 34) * CFrame.Angles(0, 0, math.rad(90)),
			}
		)
	end
	for i = 0, 3 do
		part(
			parent,
			at * CFrame.new(64, 1.4 + i * 1.6, 30) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(1.5, 7, 7),
			Color3.fromRGB(26, 26, 30),
			Enum.Material.Rubber,
			"Cylinder"
		)
	end
	return parking
end

-- A secret: something hidden with a prompt-able part named "Secret".
local function secretMarker(p: BasePart, id: string)
	p.Name = "Secret"
	p:SetAttribute("SecretId", id)
	return p
end

local function monolith(parent, at: CFrame)
	local slab = part(
		parent,
		at * CFrame.new(0, 9, 0),
		Vector3.new(2, 18, 8),
		Color3.fromRGB(8, 8, 10),
		Enum.Material.Glass,
		nil,
		{
			Reflectance = 0.25,
		}
	)
	solid(slab)
	light(slab, Color3.fromRGB(120, 90, 255), 14, 0.6)
	return secretMarker(slab, "Monolith")
end

local function rubberDuck(parent, at: CFrame)
	local yellow = Color3.fromRGB(255, 214, 40)
	local body = part(
		parent,
		at * CFrame.new(0, 0.7, 0),
		Vector3.new(1.6, 1.2, 1.9),
		yellow,
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(parent, at * CFrame.new(0, 1.6, -0.5), Vector3.one * 1, yellow, Enum.Material.SmoothPlastic, "Ball")
	part(
		parent,
		at * CFrame.new(0, 1.5, -1.1),
		Vector3.new(0.6, 0.25, 0.5),
		Color3.fromRGB(255, 130, 30),
		Enum.Material.SmoothPlastic
	)
	part(
		parent,
		at * CFrame.new(0.3, 1.8, -0.9),
		Vector3.one * 0.18,
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(
		parent,
		at * CFrame.new(-0.3, 1.8, -0.9),
		Vector3.one * 0.18,
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	return secretMarker(body, "Duck")
end

local function bomberWreck(parent, at: CFrame, rng: Random)
	local green = Color3.fromRGB(70, 120, 60)
	-- The fuselage, nose-down in a furrow, a croc snout for a nose.
	local hull = at * CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(8), 0, math.rad(12))
	local body = solid(part(parent, hull, Vector3.new(9, 7, 34), green, Enum.Material.Metal))
	part(
		parent,
		hull * CFrame.new(0, -0.5, -20),
		Vector3.new(6, 3.4, 9),
		Color3.fromRGB(86, 140, 70),
		Enum.Material.SmoothPlastic
	)
	for i = -2, 2 do
		part(
			parent,
			hull * CFrame.new(i * 1.1, -2.4, -22),
			Vector3.new(0.4, 0.8, 0.4),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			"Wedge"
		)
	end
	part(
		parent,
		hull * CFrame.new(1.6, 1.4, -22.5),
		Vector3.one * 0.9,
		Color3.fromRGB(255, 220, 60),
		Enum.Material.Neon,
		"Ball"
	)
	part(
		parent,
		hull * CFrame.new(-1.6, 1.4, -22.5),
		Vector3.one * 0.9,
		Color3.fromRGB(255, 220, 60),
		Enum.Material.Neon,
		"Ball"
	)
	-- One wing still on, one snapped off nearby.
	part(
		parent,
		hull * CFrame.new(14, 0, 2) * CFrame.Angles(0, 0, math.rad(-6)),
		Vector3.new(22, 1, 9),
		green,
		Enum.Material.Metal
	)
	solid(
		part(
			parent,
			at * CFrame.new(-24, 1, 14) * CFrame.Angles(0.2, 0.9, 0.4),
			Vector3.new(20, 1, 8),
			green,
			Enum.Material.Metal
		)
	)
	part(parent, hull * CFrame.new(0, 5, 15), Vector3.new(1, 8, 6), green, Enum.Material.Metal)
	-- Scorched ground and smoke.
	disc(parent, at * CFrame.new(0, 0.1, 6), 24, 0.2, Color3.fromRGB(40, 38, 40), Enum.Material.Slate)
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = Color3.fromRGB(60, 60, 64), 0.15, 4, 6
	smoke.Parent = body
	for _ = 1, 8 do
		solid(
			part(
				parent,
				at
					* CFrame.new(rng:NextNumber(-30, 30), 0.8, rng:NextNumber(-20, 40))
					* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
				Vector3.new(rng:NextNumber(2, 5), 0.8, rng:NextNumber(2, 6)),
				green:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.2, 0.6)),
				Enum.Material.Metal
			)
		)
	end
	-- The black box, lying by the cockpit.
	local box = part(
		parent,
		at * CFrame.new(5, 0.9, -24),
		Vector3.new(2, 1.4, 2.6),
		Color3.fromRGB(255, 110, 30),
		Enum.Material.SmoothPlastic
	)
	light(box, Color3.fromRGB(255, 120, 40), 8, 1)
	return secretMarker(box, "Bomber")
end

local function skeleton(parent, at: CFrame)
	local bone = Color3.fromRGB(226, 220, 200)
	-- Ribs arching out of the crater floor, a skull at one end.
	for i = 0, 7 do
		for side = -1, 1, 2 do
			part(
				parent,
				at * CFrame.new(side * 5, 7, -18 + i * 5) * CFrame.Angles(0, 0, math.rad(side * -24)),
				Vector3.new(1.4, 15, 1.4),
				bone,
				Enum.Material.Marble
			)
		end
	end
	part(parent, at * CFrame.new(0, 1.4, 0), Vector3.new(2.2, 2.2, 46), bone, Enum.Material.Marble)
	local skull = solid(part(parent, at * CFrame.new(0, 4, -27), Vector3.new(9, 7, 11), bone, Enum.Material.Marble))
	for side = -1, 1, 2 do
		part(
			parent,
			at * CFrame.new(side * 2.4, 5, -32.6),
			Vector3.new(2, 1.6, 0.4),
			Color3.fromRGB(20, 20, 24),
			Enum.Material.SmoothPlastic
		)
		part(
			parent,
			at * CFrame.new(side * 3.6, 7, -30) * CFrame.Angles(math.rad(-40), 0, 0),
			Vector3.new(1, 6, 1),
			bone,
			Enum.Material.Marble
		)
	end
	for i = -3, 3 do
		part(
			parent,
			at * CFrame.new(i * 1.1, 1.2, -32.8),
			Vector3.new(0.6, 1.6, 0.6),
			bone,
			Enum.Material.Marble,
			"Wedge"
		)
	end
	return secretMarker(skull, "Skeleton")
end

local function shrine(parent, at: CFrame)
	local wood = Color3.fromRGB(150, 104, 62)
	solid(
		part(
			parent,
			at * CFrame.new(0, 0.5, 0),
			Vector3.new(8, 1, 8),
			Color3.fromRGB(110, 106, 110),
			Enum.Material.Cobblestone
		)
	)
	-- The little wooden figure with its bat.
	local log = solid(
		part(parent, at * CFrame.new(0, 3.4, 0), Vector3.new(2.4, 4.8, 2.4), wood, Enum.Material.Wood, "Cylinder", {
			CFrame = at * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	)
	part(
		parent,
		at * CFrame.new(0.5, 4.2, -1.1),
		Vector3.one * 0.5,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(
		parent,
		at * CFrame.new(-0.5, 4.2, -1.1),
		Vector3.one * 0.5,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	part(
		parent,
		at * CFrame.new(0, 3.2, -1.15),
		Vector3.new(1, 0.2, 0.2),
		Color3.fromRGB(40, 20, 20),
		Enum.Material.SmoothPlastic
	)
	part(
		parent,
		at * CFrame.new(1.8, 3.6, -0.4) * CFrame.Angles(0, 0, math.rad(-30)),
		Vector3.new(0.5, 3.6, 0.5),
		Color3.fromRGB(120, 80, 46),
		Enum.Material.Wood
	)
	-- Offerings: glowing gems and candles.
	for i, color in { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 255, 140) } do
		part(parent, at * CFrame.new(-2.6 + i * 1.3, 1.4, -2.6), Vector3.new(0.6, 0.8, 0.6), color, Enum.Material.Neon)
	end
	for _, x in { -3.2, 3.2 } do
		part(
			parent,
			at * CFrame.new(x, 1.6, 2.8),
			Vector3.new(0.4, 1.2, 0.4),
			Color3.fromRGB(240, 236, 220),
			Enum.Material.SmoothPlastic
		)
		local flame = part(
			parent,
			at * CFrame.new(x, 2.4, 2.8),
			Vector3.one * 0.35,
			Color3.fromRGB(255, 180, 60),
			Enum.Material.Neon,
			"Ball"
		)
		light(flame, Color3.fromRGB(255, 170, 70), 10, 1)
	end
	return secretMarker(log, "Shrine")
end

local function footprint(parent, at: CFrame)
	-- One enormous boot print pressed into the regolith, and its plaque.
	local dark = Color3.fromRGB(70, 72, 80)
	part(parent, at * CFrame.new(0, 0.2, 0), Vector3.new(9, 0.2, 22), dark, Enum.Material.Sand)
	for i = 0, 6 do
		part(parent, at * CFrame.new(0, 0.32, -9 + i * 3), Vector3.new(8, 0.1, 0.8), REGOLITH_DARK, Enum.Material.Slate)
	end
	part(parent, at * CFrame.new(0, 0.2, -12), Vector3.new(8, 0.2, 4), dark, Enum.Material.Sand)
	part(parent, at * CFrame.new(8, 1.4, 0), Vector3.new(0.5, 2.8, 0.5), STEEL, Enum.Material.Metal)
	local plaque = solid(
		part(
			parent,
			at * CFrame.new(8, 3, 0) * CFrame.Angles(math.rad(-20), math.rad(-90), 0),
			Vector3.new(4, 2.4, 0.3),
			Color3.fromRGB(180, 140, 60),
			Enum.Material.Metal
		)
	)
	return secretMarker(plaque, "Footprint")
end

function OutpostWorld.build(at: CFrame, parent: Instance)
	local root = Instance.new("Model")
	root.Name = "SagaOutpost"
	local rng = Random.new(4242)
	local ground = folder(root, "Ground")
	-- The quarry floor and its regolith, the stepped benches and the mountain
	-- range round it, with walls off its edge so no one wanders off.
	solid(disc(ground, at * CFrame.new(0, -1, 0), 520, 2, REGOLITH, Enum.Material.Slate))
	for _ = 1, 90 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, 430)
		disc(
			ground,
			at * CFrame.new(math.cos(a) * r, 0.05, math.sin(a) * r),
			rng:NextNumber(10, 34),
			0.1,
			REGOLITH:Lerp(REGOLITH_DARK, rng:NextNumber(0.1, 0.5)),
			Enum.Material.Sand
		)
	end
	for _, c in
		{
			{ 60, 40, 11 },
			{ -70, 60, 15 },
			{ 95, -20, 8 },
			{ -40, -10, 7 },
			{ 20, 100, 13 },
			{ -110, -50, 10 },
			{ 200, -260, 24 },
			{ -230, -150, 18 },
			{ 170, 220, 16 },
			{ -330, 80, 20 },
			{ 300, -40, 14 },
			{ -150, 330, 12 },
			{ 330, 120, 30 },
			{ 60, 330, 34 },
			{ -60, -300, 15 },
			{ 260, 300, 11 },
		}
	do
		crater(ground, at * CFrame.new(c[1], 0, c[2]), c[3])
	end
	local benchRamps = benches(ground, at)
	for i = 0, 119 do
		local a = i / 120 * math.pi * 2
		mountain(
			ground,
			at * CFrame.new(math.cos(a) * rng:NextNumber(482, 540), 0, math.sin(a) * rng:NextNumber(482, 540)),
			rng
		)
	end
	for i = 0, 71 do
		local a = i / 72 * math.pi * 2
		local w = solid(
			part(
				ground,
				at * CFrame.new(math.cos(a) * 474, 40, math.sin(a) * 474) * CFrame.Angles(0, -a, 0),
				Vector3.new(4, 80, 44),
				RIM,
				nil,
				nil,
				{ Transparency = 1 }
			)
		)
		w.CastShadow = false
	end

	-- Haul roads out from the outpost, a ring road, and jump ramps on them.
	local roads = folder(root, "Roads")
	local roadLines = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.rad(30)
		local from = (at * CFrame.new(math.cos(a) * 60, 0, math.sin(a) * 60)).Position
		local to = (at * CFrame.new(math.cos(a) * 420, 0, math.sin(a) * 420)).Position
		road(roads, from, to, 18)
		table.insert(roadLines, { from, to })
	end
	local ring = 260
	for i = 0, 35 do
		local a0, a1 = i / 36 * math.pi * 2, (i + 1) / 36 * math.pi * 2
		local from = (at * CFrame.new(math.cos(a0) * ring, 0, math.sin(a0) * ring)).Position
		local to = (at * CFrame.new(math.cos(a1) * ring, 0, math.sin(a1) * ring)).Position
		road(roads, from, to, 16)
		table.insert(roadLines, { from, to })
	end
	local motorAt = at * CFrame.new(0, 0, 150)
	road(roads, (at * CFrame.new(0, 0, 92)).Position, (motorAt * CFrame.new(0, 0, -38)).Position, 20)
	local ramps = {}
	for i, spec in { { 0, 175 }, { 2, 330 }, { 3, 200 }, { 4, 345 }, { 5, 150 } } do
		local a = spec[1] / 6 * math.pi * 2 + math.rad(30)
		local p = (at * CFrame.new(math.cos(a) * spec[2], 0, math.sin(a) * spec[2])).Position
		local outward = (at * CFrame.new(math.cos(a) * (spec[2] + 10), 0, math.sin(a) * (spec[2] + 10))).Position
		-- Low end towards the outpost, so you hit it driving out.
		jumpRamp(roads, CFrame.lookAt(p, p + (p - outward)))
		ramps[i] = p
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + math.rad(15)
		mast(roads, at * CFrame.new(math.cos(a) * 275, 0, math.sin(a) * 275), if i % 2 == 0 then SAGA else GLOW)
	end

	-- The Motor Pool, south of the landing pad.
	local motor = folder(root, "MotorPool")
	local parking = motorPool(motor, motorAt)

	-- Old workings out in the quarry: a second drill rig and container stacks.
	local works = folder(root, "Workings")
	local rigAt = at * CFrame.new(300, 0, -200)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		part(
			works,
			rigAt
				* CFrame.new(math.cos(a) * 7, 16, math.sin(a) * 7)
				* CFrame.Angles(math.sin(a) * 0.18, 0, -math.cos(a) * 0.18),
			Vector3.new(1.4, 32, 1.4),
			HAZARD,
			Enum.Material.Metal
		)
	end
	part(works, rigAt * CFrame.new(0, 33, 0), Vector3.new(10, 2, 10), HULL_DARK, Enum.Material.Metal)
	part(works, rigAt * CFrame.new(0, 14, 0), Vector3.new(2, 28, 2), STEEL, Enum.Material.Metal)
	disc(works, rigAt * CFrame.new(0, 0.15, 0), 9, 0.3, Color3.fromRGB(30, 30, 34), Enum.Material.Slate)
	for _, c in { { -280, -60 }, { 120, -330 }, { -200, 240 }, { 340, 60 } } do
		for k = 0, 2 do
			part(
				works,
				at
					* CFrame.new(c[1], 4 + (if k == 2 then 8 else 0), c[2] + (if k == 1 then 9 else 0))
					* CFrame.Angles(0, 0.2 * k, 0),
				Vector3.new(20, 8, 8),
				({ Color3.fromRGB(190, 70, 50), Color3.fromRGB(60, 110, 170), HAZARD })[k + 1],
				Enum.Material.CorrodedMetal
			)
		end
	end

	-- The secrets.
	local secrets = folder(root, "Secrets")
	local duckAngle = math.rad(135)
	local hidden = {
		monolith(secrets, at * CFrame.new(-300, 0, -282) * CFrame.Angles(0, math.rad(40), 0)),
		rubberDuck(
			secrets,
			at
				* CFrame.new(math.cos(duckAngle) * (QUARRY + 27), 15, math.sin(duckAngle) * (QUARRY + 27))
				* CFrame.Angles(0, -duckAngle + math.pi / 2, 0)
		),
		bomberWreck(secrets, at * CFrame.new(-262, 0, 300) * CFrame.Angles(0, math.rad(-35), 0), rng),
		skeleton(secrets, at * CFrame.new(330, 0, 120) * CFrame.Angles(0, math.rad(70), 0)),
		shrine(secrets, at * CFrame.new(-70, 0, -405) * CFrame.Angles(0, math.rad(180), 0)),
		footprint(secrets, at * CFrame.new(60, 0, 330) * CFrame.Angles(0, math.rad(20), 0)),
	}

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
		{ motorAt.Position, 84 },
		{ rigAt.Position, 16 },
	}
	for _, secret in hidden do
		table.insert(keepOut, { secret.CFrame.Position, 26 })
	end
	for _, p in ramps do
		table.insert(keepOut, { p, 24 })
	end
	for _, p in benchRamps do
		table.insert(keepOut, { p, 40 })
	end
	-- Off the roads too (distance from each road's centre line).
	local function onRoad(p: Vector3): boolean
		for _, line in roadLines do
			local a, b = line[1] * Vector3.new(1, 0, 1), line[2] * Vector3.new(1, 0, 1)
			local q = p * Vector3.new(1, 0, 1)
			local t = math.clamp((q - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
			if (a + (b - a) * t - q).Magnitude < 14 then
				return true
			end
		end
		return false
	end
	local spots = {}
	local tries = 0
	while #spots < 170 and tries < 12000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0.01, 1)) * (QUARRY - 25)
		local p = (at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)).Position
		local ok = not onRoad(p)
		for _, k in keepOut do
			if (p - k[1]).Magnitude < k[2] then
				ok = false
				break
			end
		end
		for _, s in spots do
			if (s.Position - p).Magnitude < 12 then
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
		Parking = parking,
		Secrets = hidden,
	}
end

return OutpostWorld
