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

-- Imported art (ServerStorage.Assets) when it's there; plain parts when not.
local AssetKit = (function()
	local ok, kit = pcall(function()
		return require(script.Parent:FindFirstChild("AssetKit"))
	end)
	if ok and kit then
		return kit
	end
	return {
		has = function()
			return false
		end,
		pick = function()
			return nil
		end,
		place = function()
			return nil, nil
		end,
	}
end)()

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
-- Kit rocks for each size of mining rock, and the tint they get.
local ROCK_KIT = {
	Pebble = {
		"rock_smallA",
		"rock_smallB",
		"rock_smallC",
		"rock_smallD",
		"rock_smallE",
		"rock_smallG",
		"rock_smallH",
		"rock_smallTopA",
		"rock_smallTopB",
	},
	Boulder = { "rock_largeA", "rock_largeB", "rock_largeC", "rock_largeD", "rock_largeE", "rock_largeF" },
	Monolith = { "rock_tallA", "rock_tallB", "rock_tallC", "rock_tallD", "rock_tallG", "rock_tallH", "rock_tallI" },
	Geode = { "rock_crystalsLargeA", "rock_crystalsLargeB", "rock_crystals", "meteor_detailed" },
}
local ROCK_TINT = {
	Pebble = Color3.fromRGB(168, 160, 150),
	Boulder = Color3.fromRGB(132, 130, 142),
	Monolith = Color3.fromRGB(104, 98, 114),
	Geode = Color3.fromRGB(100, 78, 128),
}

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
	-- The kit's rock (when imported) is the shape; an invisible Body is what
	-- you hit, and the glowing crystals still say how rich it is.
	local kitName = AssetKit.pick(ROCK_KIT[size] or {}, rng)
	if kitName then
		local body = solid(
			part(
				model,
				cframe * CFrame.new(0, s * 0.42 * tall, 0),
				Vector3.new(s, s * 0.85 * tall, s * 0.9),
				stone,
				nil,
				nil,
				{ Transparency = 1 }
			)
		)
		body.Name = "Body"
		model.PrimaryPart = body
		AssetKit.place(model, kitName, cframe, {
			Width = if size == "Monolith" then nil else s * 1.2,
			Height = if size == "Monolith" then s * tall else nil,
			Yaw = rng:NextNumber(0, 6.28),
			Sink = 0.2,
			Color = ROCK_TINT[size],
		})
		for _ = 1, math.ceil(crystals / 2) do
			local a = rng:NextNumber(0, math.pi * 2)
			local len = s * rng:NextNumber(0.3, 0.55)
			local c = part(
				model,
				cframe
					* CFrame.new(math.cos(a) * s * 0.28, s * rng:NextNumber(0.55, 0.95) * tall, math.sin(a) * s * 0.28)
					* CFrame.Angles(0, -a, 0)
					* CFrame.Angles(0, 0, -rng:NextNumber(0.2, 0.8)),
				Vector3.new(len * 0.32, len, len * 0.32),
				crystal,
				Enum.Material.Neon,
				"Wedge"
			)
			c.Name = "Crystal"
		end
		if size == "Geode" then
			local core = part(
				model,
				cframe * CFrame.new(0, s * 0.62, 0),
				Vector3.one * s * 0.32,
				Color3.fromRGB(255, 200, 255),
				Enum.Material.Neon,
				"Ball"
			)
			core.Name = "Crystal"
		end
		light(body, crystal, s * 3, if size == "Geode" then 2.4 else 1.1)
		return model
	end
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

-- A pipe or cable between two points.
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
local function sky(parent, at: CFrame, daytime: boolean?)
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
	if daytime then
		return
	end
	-- Stars on a big dome.
	local rng = Random.new(77)
	for _ = 1, 260 do
		local a, e = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.12, 1.4)
		local d = 1700
		local p = at * CFrame.new(math.cos(a) * math.cos(e) * d, math.sin(e) * d, math.sin(a) * math.cos(e) * d)
		part(m, p, Vector3.one * rng:NextNumber(2, 6), Color3.fromRGB(230, 236, 255), Enum.Material.Neon, "Ball")
	end
end

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

-- The Skyport: a compact floating island ------------------------------------------------

local STONE = Color3.fromRGB(224, 208, 178) -- warm sandstone flagging
local STONE_DARK = Color3.fromRGB(186, 168, 138)
local CLIFF = Color3.fromRGB(150, 128, 100)
local MOSS = Color3.fromRGB(110, 150, 70)
local LEAF = Color3.fromRGB(70, 132, 60)
local BARK = Color3.fromRGB(104, 78, 56)
local ISLAND = 112 -- the island's walkable radius (Shared.Outpost.Radius)

-- The mining rings, one per kind of ground (Shared.Outpost.Zones): where
-- they sit, how big, how high the deck is, and their trim colour.
local RINGS = {
	{
		Zone = "Common",
		Title = "COMMON FIELD",
		Sub = "Pebbles  ·  Boulders",
		At = Vector3.new(-56, 0, 22),
		Radius = 24,
		Height = 2.4,
		Color = Color3.fromRGB(110, 220, 255),
	},
	{
		Zone = "Deep",
		Title = "DEEP VEIN",
		Sub = "Boulders  ·  Monoliths",
		At = Vector3.new(56, 0, 22),
		Radius = 24,
		Height = 2.4,
		Color = SAGA,
	},
	{
		Zone = "Crystal",
		Title = "CRYSTAL CROWN",
		Sub = "Monoliths  ·  Star Geodes",
		At = Vector3.new(0, 0, -62),
		Radius = 27,
		Height = 4.8,
		Color = Color3.fromRGB(190, 120, 255),
	},
}

-- The rocky underside that makes ground float: stacked, shrinking chunks.
local function underside(parent, centre: CFrame, radius: number, depth: number, rng: Random)
	local layers = math.max(3, math.floor(depth / 10))
	local thick = depth / layers * 1.6
	for i = 1, layers do
		local t = i / layers
		local r = radius * (1 - t * 0.85)
		-- Each layer's top sits under the one above, the first under the ground.
		local top = -2.5 - (i - 1) / layers * depth
		local count = math.max(4, math.floor(r / 5))
		for k = 1, count do
			local a = k / count * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local d = r * rng:NextNumber(0.2, 0.5)
			local size = Vector3.new(rng:NextNumber(0.5, 0.9) * r, thick, rng:NextNumber(0.5, 0.9) * r)
			part(
				parent,
				centre * CFrame.new(math.cos(a) * d, top - thick / 2, math.sin(a) * d) * CFrame.Angles(0, a, 0),
				size,
				CLIFF:Lerp(Color3.fromRGB(110, 92, 74), t),
				Enum.Material.Rock
			)
		end
	end
	-- Moss spilling over the lip.
	for k = 1, math.floor(radius / 3) do
		local a = k / math.floor(radius / 3) * math.pi * 2
		part(
			parent,
			centre * CFrame.new(math.cos(a) * (radius - 1), -1.6, math.sin(a) * (radius - 1)) * CFrame.Angles(0, -a, 0),
			Vector3.new(4, 2.4, rng:NextNumber(5, 9)),
			MOSS:Lerp(LEAF, rng:NextNumber(0, 0.5)),
			Enum.Material.Grass
		)
	end
end

-- A tree: a leaning trunk and a few rounded crowns.
local TREES = { "tree_oak", "tree_default", "tree_detailed", "tree_fat", "tree_plateau", "tree_blocks", "tree_thin" }
-- Outcrops round the rim.
local RIM_ROCKS = {
	"stone_largeA",
	"stone_largeB",
	"stone_largeC",
	"stone_largeD",
	"stone_largeE",
	"stone_largeF",
	"cliff_blockHalf_rock",
	"cliff_blockQuarter_rock",
}
-- Ground cover: { names, min height, max height } (studs).
local PLANTS = {
	{ { "grass", "grass_large", "grass_leafs", "grass_leafsLarge" }, 1.2, 2.2 },
	{ { "grass", "grass_large", "grass_leafs", "grass_leafsLarge" }, 1.2, 2.2 },
	{
		{ "flower_purpleA", "flower_purpleB", "flower_redA", "flower_redB", "flower_yellowA", "flower_yellowB" },
		1,
		1.8,
	},
	{ { "plant_bush", "plant_bushDetailed", "plant_bushLarge", "plant_bushSmall", "plant_flatTall" }, 2.5, 4.5 },
	{ { "mushroom_redGroup", "mushroom_tanGroup", "mushroom_redTall" }, 1, 2 },
	{ { "rock_smallFlatA", "rock_smallFlatB", "rock_smallFlatC", "stone_smallA", "stone_smallC" }, 0.8, 1.6 },
	{ { "stump_round", "stump_old", "log" }, 1.5, 2.5 },
}
-- Sci-fi kit set pieces: { name, x, z, height, yaw degrees }.
local PROPS = {
	{ "satelliteDish_large", 94, -34, 12, 200 },
	{ "machine_generator", -98, 76, 5, 30 },
	{ "barrels", -66, 84, 4, 10 },
	{ "rover", 20, 86, 5, -60 },
	{ "machine_wirelessCable", -102, 40, 7, 80 },
	{ "turret_double", -92, -64, 7, 130 },
	{ "satelliteDish", -30, -100, 7, 10 },
}
local function tree(parent, at: CFrame, rng: Random, scale: number?)
	local k = scale or 1
	local kitName = AssetKit.pick(TREES, rng)
	if kitName then
		local m =
			AssetKit.place(parent, kitName, at, { Height = rng:NextNumber(20, 28) * k, Yaw = rng:NextNumber(0, 6.28) })
		if m then
			-- Leaves let you walk under them; the trunk stops you.
			solid(
				part(parent, at * CFrame.new(0, 6, 0), Vector3.new(2.6, 12, 2.6), BARK, nil, nil, { Transparency = 1 })
			)
			return
		end
	end
	local lean = at * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	solid(part(parent, lean * CFrame.new(0, 7 * k, 0), Vector3.new(2 * k, 14 * k, 2 * k), BARK, Enum.Material.Wood))
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		part(
			parent,
			lean * CFrame.new(math.cos(a) * 3.5 * k, (14 + rng:NextNumber(-1, 2)) * k, math.sin(a) * 3.5 * k),
			Vector3.new(9, 5, 9) * k * rng:NextNumber(0.8, 1.15),
			LEAF:Lerp(MOSS, rng:NextNumber(0, 0.4)),
			Enum.Material.Grass,
			"Ball"
		)
	end
	part(parent, lean * CFrame.new(0, 16.5 * k, 0), Vector3.new(10, 6, 10) * k, LEAF, Enum.Material.Grass, "Ball")
end

-- A column: sandstone, some broken off, some capped with a glowing tech ring.
local function column(parent, at: CFrame, height: number, tech: boolean, broken: boolean)
	local kitName = if broken then "statue_columnDamaged" else "statue_column"
	local m, size = AssetKit.place(parent, kitName, at, {
		Height = if broken then height * 0.7 else height + 2,
		Collide = true,
	})
	if m and size then
		if tech then
			local r = math.max(size.X, size.Z) * 0.33
			disc(parent, at * CFrame.new(0, size.Y * 0.6, 0), r, 1.2, STEEL, Enum.Material.Metal)
			disc(parent, at * CFrame.new(0, size.Y * 0.6, 0), r + 0.1, 0.3, GLOW, Enum.Material.Neon)
			if not broken then
				local crystal = part(
					parent,
					at * CFrame.new(0, size.Y + 2.6, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
					Vector3.new(1.6, 1.6, 1.6),
					GLOW,
					Enum.Material.Neon,
					nil,
					{ Transparency = 0.15 }
				)
				light(crystal, GLOW, 12, 0.6)
			end
		end
		return m
	end
	solid(part(parent, at * CFrame.new(0, 0.6, 0), Vector3.new(5, 1.2, 5), STONE_DARK, Enum.Material.Sandstone))
	local shaft = solid(
		part(
			parent,
			at * CFrame.new(0, 1.2 + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(height, 3.4, 3.4),
			STONE,
			Enum.Material.Sandstone,
			"Cylinder"
		)
	)
	if broken then
		part(
			parent,
			at * CFrame.new(0, 1.2 + height, 0) * CFrame.Angles(0.3, 0.4, 0.2),
			Vector3.new(3.2, 1.4, 3.2),
			STONE,
			Enum.Material.Sandstone
		)
	else
		part(parent, at * CFrame.new(0, 1.8 + height, 0), Vector3.new(5, 1.2, 5), STONE_DARK, Enum.Material.Sandstone)
	end
	if tech then
		-- A steel collar with a cyan band, and a little hovering crystal.
		disc(parent, at * CFrame.new(0, 1.2 + height * 0.62, 0), 2.1, 1.4, STEEL, Enum.Material.Metal)
		disc(parent, at * CFrame.new(0, 1.2 + height * 0.62, 0), 2.2, 0.3, GLOW, Enum.Material.Neon)
		if not broken then
			local crystal = part(
				parent,
				at * CFrame.new(0, 4.6 + height, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
				Vector3.new(1.6, 1.6, 1.6),
				GLOW,
				Enum.Material.Neon,
				nil,
				{ Transparency = 0.15 }
			)
			light(crystal, GLOW, 12, 0.6)
		end
	end
	return shaft
end

-- A low dry-stone wall segment along the rim.
local function wall(parent, from: Vector3, to: Vector3, rng: Random)
	local length = (to - from).Magnitude
	local look = CFrame.lookAt((from + to) / 2, to)
	local n = math.max(1, math.floor(length / 5))
	for i = 0, n - 1 do
		local z = -length / 2 + (i + 0.5) * length / n
		part(
			parent,
			look
				* CFrame.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(1.3, 1.9), z)
				* CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0),
			Vector3.new(rng:NextNumber(3, 4), rng:NextNumber(2.6, 3.8), length / n + 0.6),
			STONE_DARK:Lerp(CLIFF, rng:NextNumber(0, 0.5)),
			Enum.Material.Slate
		)
	end
end

-- A sign floating over a ring's steps.
local function sign(parent, at: CFrame, title: string, sub: string, color: Color3)
	local anchor = part(parent, at, Vector3.new(1, 1, 1), color, nil, nil, { Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = anchor
	for i, spec in
		{ { title, 26, Enum.Font.GothamBlack, color }, { sub, 14, Enum.Font.GothamBold, Color3.new(1, 1, 1) } }
	do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, if i == 1 then 32 else 22)
		l.Position = UDim2.fromOffset(0, if i == 1 then 0 else 34)
		l.Text, l.TextSize, l.Font, l.TextColor3 = spec[1], spec[2], spec[3], spec[4]
		l.TextStrokeTransparency = 0.2
		l.Parent = gui
	end
	return anchor
end

-- A mining ring: a raised round deck of rubble with a neon inlay, railings
-- with a gap at its steps (facing the plaza), and a sign. Returns where
-- rocks may grow on it.
local function miningRing(parent, at: CFrame, spec, faceTo: Vector3, rng: Random)
	local m = folder(parent, "Ring" .. spec.Zone)
	local r, h, color = spec.Radius, spec.Height, spec.Color
	-- The deck and its rim.
	solid(disc(m, at * CFrame.new(0, h / 2, 0), r + 2, h, STONE_DARK, Enum.Material.Sandstone))
	solid(disc(m, at * CFrame.new(0, h + 0.05, 0), r, 0.3, Color3.fromRGB(120, 112, 104), Enum.Material.Slate))
	disc(m, at * CFrame.new(0, h + 0.25, 0), r * 0.62, 0.1, color, Enum.Material.Neon, nil)
	disc(m, at * CFrame.new(0, h + 0.3, 0), r * 0.6, 0.1, Color3.fromRGB(110, 104, 98), Enum.Material.Slate)
	-- Steps toward the plaza.
	local out = (faceTo - at.Position) * Vector3.new(1, 0, 1)
	local facing = math.atan2(out.X, out.Z)
	local steps = math.ceil(h / 1.2)
	for i = 1, steps do
		local d = r + 2 + (i - 0.5) * 2.4
		solid(
			part(
				m,
				at * CFrame.Angles(0, facing, 0) * CFrame.new(0, h - i * 1.2 + 0.6, d),
				Vector3.new(14, 1.2 * (steps - i + 1), 2.4),
				STONE,
				Enum.Material.Sandstone
			)
		)
	end
	-- Railing posts and neon rails, open at the steps.
	local posts = math.floor(r * 2 * math.pi / 7)
	for i = 0, posts - 1 do
		local a = i / posts * math.pi * 2
		-- A post's bearing in the same terms as `facing` (the steps' side).
		local pa = math.atan2(math.cos(a), math.sin(a))
		local gap = math.abs(math.atan2(math.sin(pa - facing), math.cos(pa - facing))) < math.rad(18)
		if not gap then
			local p = at * CFrame.new(math.cos(a) * (r + 1), h, math.sin(a) * (r + 1))
			solid(part(m, p * CFrame.new(0, 1.6, 0), Vector3.new(0.7, 3.2, 0.7), STEEL, Enum.Material.Metal))
			local a2 = (i + 1) / posts * math.pi * 2
			local q = at * CFrame.new(math.cos(a2) * (r + 1), h, math.sin(a2) * (r + 1))
			local pa2 = math.atan2(math.cos(a2), math.sin(a2))
			if math.abs(math.atan2(math.sin(pa2 - facing), math.cos(pa2 - facing))) >= math.rad(18) then
				local mid = (p.Position + q.Position) / 2
				local len = (q.Position - p.Position).Magnitude
				local railAt = CFrame.lookAt(mid + Vector3.new(0, 3, 0), q.Position + Vector3.new(0, 3, 0))
				part(m, railAt, Vector3.new(0.45, 0.45, len), color, Enum.Material.Neon)
				part(m, railAt * CFrame.new(0, -1.3, 0), Vector3.new(0.3, 0.3, len), STEEL, Enum.Material.Metal)
			end
		end
	end
	-- Four short tech pylons round the deck, lit in the ring's colour.
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = at * CFrame.new(math.cos(a) * (r + 3.5), 0, math.sin(a) * (r + 3.5))
		solid(part(m, p * CFrame.new(0, 3.5, 0), Vector3.new(1.6, 7, 1.6), HULL, Enum.Material.Metal))
		local lamp = part(m, p * CFrame.new(0, 7.4, 0), Vector3.new(2, 0.8, 2), color, Enum.Material.Neon)
		light(lamp, color, 20, 0.8)
	end
	sign(m, at * CFrame.Angles(0, facing, 0) * CFrame.new(0, h + 12, r + 4), spec.Title, spec.Sub or "", color)
	-- Where rocks grow: a loose grid on the deck, clear of the rim.
	local spots = {}
	local step = 8.5
	for x = -r, r, step do
		for z = -r, r, step do
			local d = math.sqrt(x * x + z * z)
			if d <= r - 5 and d >= 3 then
				local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
				local p = (at * CFrame.new(x, h + 0.3, z)).Position + jitter
				table.insert(spots, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			end
		end
	end
	return spots
end

-- A small floating islet off the edge: ground, an underside and something on top.
local function islet(parent, at: CFrame, radius: number, rng: Random, topper: string)
	local m = folder(parent, "Islet")
	disc(m, at * CFrame.new(0, -0.5, 0), radius, 1.4, STONE, Enum.Material.Sandstone)
	disc(m, at * CFrame.new(0, 0.25, 0), radius * 0.85, 0.2, MOSS, Enum.Material.Grass)
	underside(m, at, radius, radius * 1.4, rng)
	if topper == "Tree" then
		tree(m, at, rng, rng:NextNumber(0.8, 1.2))
	elseif topper == "Column" then
		column(m, at, rng:NextNumber(10, 18), rng:NextNumber() < 0.5, rng:NextNumber() < 0.4)
	elseif topper == "Beacon" then
		solid(part(m, at * CFrame.new(0, 5, 0), Vector3.new(2, 10, 2), HULL, Enum.Material.Metal))
		local top = part(m, at * CFrame.new(0, 10.6, 0), Vector3.new(3, 1.2, 3), GLOW, Enum.Material.Neon)
		light(top, GLOW, 30, 1)
	end
end

-- An orbital ring station hanging in the sky: the sci-fi on the horizon.
local function station(parent, at: CFrame)
	local m = folder(parent, "Station")
	local segments = 36
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local p = at * CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(math.cos(a) * 220, 0, math.sin(a) * 220)
		part(
			m,
			CFrame.lookAt(p.Position, at.Position) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(40, 10, 16),
			HULL,
			Enum.Material.Metal
		)
		if i % 3 == 0 then
			part(
				m,
				CFrame.lookAt(p.Position, at.Position) * CFrame.new(0, 0, -8.2),
				Vector3.new(6, 3, 0.4),
				GLOW,
				Enum.Material.Neon
			)
		end
	end
	part(m, at, Vector3.new(24, 24, 24), HULL_DARK, Enum.Material.Metal, "Ball")
	part(
		m,
		at * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(4, 60, 60),
		GLOW,
		Enum.Material.Neon,
		"Cylinder",
		{ Transparency = 0.5 }
	)
end

function OutpostWorld.build(at: CFrame, parent: Instance)
	local root = Instance.new("Model")
	root.Name = "SagaOutpost"
	local rng = Random.new(4242)
	local ground = folder(root, "Ground")

	-- The island: warm flagstones, a moss-lipped rocky underside, and a
	-- waist-high rim wall with invisible fencing above it (no falling off).
	solid(disc(ground, at * CFrame.new(0, -1, 0), ISLAND + 6, 2, STONE, Enum.Material.Sandstone))
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, ISLAND - 8)
		disc(
			ground,
			at * CFrame.new(math.cos(a) * r, 0.03, math.sin(a) * r),
			rng:NextNumber(5, 14),
			0.06,
			STONE:Lerp(STONE_DARK, rng:NextNumber(0.2, 0.7)),
			Enum.Material.Pavement
		)
	end
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(30, ISLAND - 4)
		disc(
			ground,
			at * CFrame.new(math.cos(a) * r, 0.05, math.sin(a) * r),
			rng:NextNumber(3, 8),
			0.1,
			MOSS,
			Enum.Material.Grass
		)
	end
	underside(ground, at, ISLAND + 6, 70, rng)
	local rimSegments = 28
	for i = 0, rimSegments - 1 do
		local a0, a1 = i / rimSegments * math.pi * 2, (i + 1) / rimSegments * math.pi * 2
		local from = (at * CFrame.new(math.cos(a0) * (ISLAND + 2), 0, math.sin(a0) * (ISLAND + 2))).Position
		local to = (at * CFrame.new(math.cos(a1) * (ISLAND + 2), 0, math.sin(a1) * (ISLAND + 2))).Position
		wall(ground, from, to, rng)
		local fence = solid(
			part(
				ground,
				CFrame.lookAt((from + to) / 2 + Vector3.new(0, 10, 0), to + Vector3.new(0, 10, 0)),
				Vector3.new(2, 20, (to - from).Magnitude + 1),
				STONE,
				nil,
				nil,
				{ Transparency = 1 }
			)
		)
		fence.CastShadow = false
	end

	-- The plaza: a polished landing pad at the front, a round court in the
	-- middle with the Saga beacon, and the paths to the rings.
	local plaza = folder(root, "Plaza")
	local padAt = at * CFrame.new(0, 0, 74)
	solid(disc(plaza, padAt * CFrame.new(0, 0.2, 0), 13, 0.4, HULL, Enum.Material.Metal))
	disc(plaza, padAt * CFrame.new(0, 0.45, 0), 11.5, 0.1, HULL_DARK, Enum.Material.DiamondPlate)
	disc(plaza, padAt * CFrame.new(0, 0.5, 0), 9, 0.1, SAGA, Enum.Material.Neon)
	disc(plaza, padAt * CFrame.new(0, 0.55, 0), 8.4, 0.1, HULL_DARK, Enum.Material.DiamondPlate)
	local court = at * CFrame.new(0, 0, 12)
	solid(disc(plaza, court * CFrame.new(0, 0.15, 0), 20, 0.3, STONE_DARK, Enum.Material.Marble))
	disc(plaza, court * CFrame.new(0, 0.32, 0), 17, 0.06, GLOW, Enum.Material.Neon)
	disc(plaza, court * CFrame.new(0, 0.36, 0), 16.4, 0.06, STONE, Enum.Material.Marble)
	-- The beacon: a steel spire with a slowly glowing Saga crystal.
	solid(part(plaza, court * CFrame.new(0, 7, 0), Vector3.new(2.4, 14, 2.4), HULL, Enum.Material.Metal))
	for _, y in { 4, 9 } do
		disc(plaza, court * CFrame.new(0, y, 0), 2, 0.5, GLOW, Enum.Material.Neon)
	end
	local crystal = part(
		plaza,
		court * CFrame.new(0, 17, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		Vector3.new(4, 4, 4),
		SAGA,
		Enum.Material.Neon,
		nil,
		{ Transparency = 0.1 }
	)
	light(crystal, SAGA, 40, 1.2)
	for _, target in { RINGS[1].At, RINGS[2].At, RINGS[3].At, Vector3.new(0, 0, 74) } do
		local from = court.Position
		local to = (at * CFrame.new(target)).Position
		local length = (to - from).Magnitude
		part(
			plaza,
			CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.08, 0), to + Vector3.new(0, 0.08, 0)),
			Vector3.new(7, 0.12, length),
			STONE_DARK,
			Enum.Material.Pavement
		)
	end

	-- The three mining rings: rocks grow only on their decks.
	local mining = folder(root, "MiningRings")
	local spots, zones = {}, {}
	for _, spec in RINGS do
		local ringAt = at * CFrame.new(spec.At)
		for _, spot in miningRing(mining, ringAt, spec, court.Position, rng) do
			table.insert(spots, spot)
			table.insert(zones, spec.Zone)
		end
	end

	-- Ruins and tech among them: columns (some broken, some fitted with a
	-- glowing collar), trees, and rock outcrops.
	local decor = folder(root, "Decor")
	for _, c in
		{
			{ -24, 52, 22, true, false },
			{ 24, 52, 22, true, false },
			{ -86, -10, 26, false, false },
			{ 86, -10, 26, false, true },
			{ -40, -96, 18, true, true },
			{ 44, -96, 30, false, false },
			{ -96, 54, 14, false, true },
			{ 96, 54, 20, true, false },
			{ 0, -100, 34, true, false },
		}
	do
		column(decor, at * CFrame.new(c[1], 0, c[2]), c[3], c[4], c[5])
	end
	for _, t in { { -100, 20 }, { 100, 24 }, { -78, -62 }, { 82, -64 }, { -30, 100 }, { 36, 100 }, { -100, -34 } } do
		tree(decor, at * CFrame.new(t[1], 0, t[2]), rng, rng:NextNumber(0.9, 1.3))
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(ISLAND - 14, ISLAND - 4)
		local p = at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		local rimKit = AssetKit.pick(RIM_ROCKS, rng)
		if
			rimKit
			and AssetKit.place(decor, rimKit, p, {
				Width = rng:NextNumber(7, 12),
				Yaw = rng:NextNumber(0, 6.28),
				Collide = true,
				Sink = 0.4,
				Color = STONE_DARK:Lerp(MOSS, rng:NextNumber(0, 0.25)),
			})
		then
			continue
		end
		solid(
			part(
				decor,
				p
					* CFrame.new(0, 1.5, 0)
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
				Vector3.new(rng:NextNumber(5, 10), rng:NextNumber(3, 6), rng:NextNumber(5, 9)),
				STONE_DARK:Lerp(MOSS, rng:NextNumber(0, 0.25)),
				Enum.Material.Rock
			)
		)
	end

	-- Ground cover from the Nature kit, kept off the rings, the paths, the
	-- pad, the court and the stations.
	local keepClear = {
		{ Vector3.new(0, 0, 74), 16 },
		{ Vector3.new(0, 0, 12), 23 },
		{ Vector3.new(-82, 0, 60), 14 },
		{ Vector3.new(84, 0, 60), 14 },
		{ Vector3.new(70, 0, -56), 14 },
	}
	for _, spec in RINGS do
		table.insert(keepClear, { spec.At, spec.Radius + 4 })
	end
	local function clear(x: number, z: number): boolean
		local here = Vector3.new(x, 0, z)
		for _, spot in keepClear do
			if (here - Vector3.new(spot[1].X, 0, spot[1].Z)).Magnitude < spot[2] then
				return false
			end
		end
		local from = Vector3.new(0, 0, 12)
		for _, target in { RINGS[1].At, RINGS[2].At, RINGS[3].At, Vector3.new(0, 0, 74) } do
			local line = Vector3.new(target.X, 0, target.Z) - from
			local t = math.clamp((here - from):Dot(line) / line:Dot(line), 0, 1)
			if (here - (from + line * t)).Magnitude < 6 then
				return false
			end
		end
		return true
	end
	if AssetKit.has("grass") or AssetKit.has("grass_large") then
		local placed, tries = 0, 0
		while placed < 90 and tries < 600 do
			tries += 1
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber(0, 1)) * (ISLAND - 8)
			local x, z = math.cos(a) * r, math.sin(a) * r
			local group = PLANTS[rng:NextInteger(1, #PLANTS)]
			local name = AssetKit.pick(group[1], rng)
			if name and clear(x, z) then
				AssetKit.place(decor, name, at * CFrame.new(x, 0, z), {
					Height = rng:NextNumber(group[2], group[3]),
					Yaw = rng:NextNumber(0, 6.28),
					Sink = 0.1,
				})
				placed += 1
			end
		end
	end

	-- Sci-fi set pieces round the edge: dishes, a generator, a rover, a turret.
	for _, prop in PROPS do
		AssetKit.place(decor, prop[1], at * CFrame.new(prop[2], 0, prop[3]), {
			Height = prop[4],
			Yaw = math.rad(prop[5]),
			Collide = true,
		})
	end

	-- The Probe (market), the leaderboard and the Arena Uplink, round the plaza.
	-- Out on the flanks, both facing the court, so the view from the pad is open.
	local function facing(x: number, z: number): CFrame
		local p = (at * CFrame.new(x, 0, z)).Position
		return CFrame.lookAt(p, Vector3.new(court.Position.X, p.Y, court.Position.Z))
	end
	local probeScreen = probe(root, facing(-82, 60) * CFrame.Angles(0, math.pi, 0))
	local face = billboard(root, facing(84, 60))
	local gatePad = gate(root, at * CFrame.new(70, 0, -56))

	-- The secrets, tucked round the rim.
	local secrets = folder(root, "Secrets")
	local hidden = {
		monolith(secrets, at * CFrame.new(-92, 0, 36) * CFrame.Angles(0, math.rad(60), 0)),
		rubberDuck(secrets, at * CFrame.new(58, 0, 92) * CFrame.Angles(0, math.rad(-30), 0)),
		bomberWreck(secrets, at * CFrame.new(-64, 0, -84) * CFrame.Angles(0, math.rad(-35), 0), rng),
		skeleton(secrets, at * CFrame.new(102, 0, -8) * CFrame.Angles(0, math.rad(70), 0)),
		shrine(secrets, at * CFrame.new(30, 0, -100) * CFrame.Angles(0, math.rad(180), 0)),
		footprint(secrets, at * CFrame.new(-60, 0, 86) * CFrame.Angles(0, math.rad(20), 0)),
	}

	-- Islets drifting round the island, and the sky: planets and an orbital
	-- ring station over a bright afternoon.
	local far = folder(root, "Skyline")
	for i, spec in
		{
			{ 0.2, 190, 30, 16, "Tree" },
			{ 0.9, 240, 70, 22, "Column" },
			{ 1.7, 200, 12, 12, "Beacon" },
			{ 2.4, 280, 50, 26, "Tree" },
			{ 3.2, 210, -8, 14, "Column" },
			{ 4.0, 260, 90, 18, "Beacon" },
			{ 4.8, 220, 40, 20, "Tree" },
			{ 5.6, 300, 20, 30, "Column" },
		}
	do
		local a = spec[1]
		islet(
			far,
			at * CFrame.new(math.cos(a) * spec[2], spec[3], math.sin(a) * spec[2]),
			spec[4],
			Random.new(i * 31),
			spec[5]
		)
	end
	station(far, at * CFrame.new(-260, 420, -900))
	sky(root, at, true)

	root.Parent = parent
	return {
		Model = root,
		Spawn = CFrame.lookAt((padAt * CFrame.new(0, 3.5, 0)).Position, court.Position + Vector3.new(0, 3.5, 0)),
		Probe = probeScreen,
		Board = face,
		Gate = gatePad,
		Spots = spots,
		Zones = zones,
		Parking = {},
		Secrets = hidden,
	}
end

return OutpostWorld
