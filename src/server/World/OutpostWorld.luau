--[[
	Saga Outpost's world, built by the server so everyone shares it: a wide
	crater basin on the moon, ringed by weathered crater slopes. In the middle
	stands the Shelter, the base players arrive in (an armoured barracks on
	landing legs, ramps down from its doors: the mech garage with its
	eight bays and a door at each end, the Store, the player Market, PROBE-7,
	the leaderboard, the Arena Uplink and the kaiju arena); outside is the
	quarry, where they mine and hunt: the Loop, four biomes round the core
	between four haul roads due north, east, south and west, each with its
	own ground (Roblox terrain, Shared.Frontier.ground: their borders sway
	and mix, and the land rises where nothing stands), rock and landmarks,
	and a sign for it either side of each road (Shared.Frontier.Biomes). A
	working
	frontier outpost runs along the north edge (habitat modules strung on
	tubes, a refinery tower, a drill rig over its pit, conveyors, pipes and
	floodlight masts), with the landing pad and shuttle south-east. Over it
	all, only stars in the black, and the rift tearing across the north
	(Client.SkyRift draws that).

	  OutpostWorld.build(at, parent) -> {
	      Model, Spawn (CFrame: in the Shelter's garage lane, facing bay 04's
	      Mole drill, on its floor: Shared.Outpost.ShelterLift over the
	      quarry's),
	      Probe (BasePart, the terminal), Board (BasePart with the
	      leaderboard's face), Gate (BasePart), Stations ({ Store, Market }:
	      the Shelter's counters, for their prompts), Crew ({ { Id, CFrame } }:
	      where the Shelter's crew stand, by Shared.Vendors id, for
	      OutpostServer to build them), Shelter ({ Box, Lift, Ramps,
	      Feet }: its half size, x and z, kept clear of rocks; how high its
	      floor stands; each ramp's footprint, { Middle (on the quarry
	      floor), Half (half sizes, x and z), SlopeHalf (the slope's half
	      width) }, the main door's first; where its legs stand),
	      Spots ({ CFrame }, where rocks may grow), ArrivalSpots and
	      NearSpots (indexes into Spots: the welcome field outside the
	      Shelter's door, and the field round the middle, filled first),
	      OutcropSpots (the frontier's outcrops and lone rocks,
	      Shared.Frontier), Veins ({ { Site, Spots } }: the three Rift Veins,
	      each a site and its six spots, which move when a vein does),
	      VeinSites ({ { Angle, Rocks = { CFrame }, Scar } }: every place by
	      the walls with room for one), Zones (each spot's Shared.Outpost
	      zone), Scars ({ CFrame }: each vein's dormant rift, facing in),
	      Parking ({ Kind, CFrame }: the garage bays for the mechs),
	      KeepOut ({ { Vector3, studs } }: the Shelter, buildings, workings,
	      ramps and vein sites, for wild kaiju to keep clear of),
	      Secrets (empty: retired Easter eggs stay disabled) }
	  OutpostWorld.Terrain   the terrain the Loop's ground is laid in (the
	      workspace's when not handed in; offline tests hand in their own)
	  OutpostWorld.rock(size, cframe, rng, tint?, stone?) -> Model   one rock of
	      that size (Shared.Outpost.Sizes), its main chunk named "Body"; `tint`
	      colours its crystals (a frontier band's, Shared.Frontier.Bands),
	      `stone` its basalt (a biome's, Shared.Frontier.Biomes)
	  OutpostWorld.veinMarks(parent, scar, rng, color?, index?) -> Model   a vein's
	      Rift Gate over its dormant rift: scorched bed, cracks, an arch of
	      black rock with fire at its feet, and its "Enter the Rift" prompt
	      (moved with it; `color` the guarded vein's cracks,
	      Shared.Frontier.Bands.Guarded)
]]
local OutpostWorld = {}

-- The frontier's rules (Shared.Frontier: outcrops and veins). Offline scene
-- tests hand it in here.
OutpostWorld.Frontier = (function()
	local ok, module = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Frontier", 10))
	end)
	return if ok then module else nil
end)()
-- The Outpost's rules (Shared.Outpost: how high the Shelter stands on its
-- legs, how long its ramps run). Offline scene tests hand it in here too.
OutpostWorld.Rules = (function()
	local ok, module = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Outpost", 10))
	end)
	return if ok then module else nil
end)()

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
-- The everyday mining rocks: dark basalt, so they stand out on the pale
-- regolith, with glassy crystals that glow from inside.
local BASALT = Color3.fromRGB(84, 86, 106)
local BASALT_DARK = Color3.fromRGB(58, 60, 76)
local BASALT_LIGHT = Color3.fromRGB(118, 118, 136)
local CRYSTAL_CORE = Color3.fromRGB(215, 250, 255)
local BED = Color3.fromRGB(92, 92, 104)

local function part(parent, cframe, size, color, material, shape, props)
	local p = Instance.new(
		if shape == "Wedge" then "WedgePart" elseif shape == "CornerWedge" then "CornerWedgePart" else "Part"
	)
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

-- One crystal standing out of `base`: a shaft with a pointed tip, leaning
-- `lean` radians toward `heading` (a yaw). A big one is glass that glows
-- from a core inside; a small one is all glow.
local function shard(
	parent,
	base: Vector3,
	heading: number,
	lean: number,
	length: number,
	width: number,
	rng,
	core,
	color: Color3?
)
	local glow = color or GLOW
	local tip = math.min(width * 1.5, length * 0.45)
	local shaft = length - tip
	local at = CFrame.new(base)
		* CFrame.Angles(0, heading, 0)
		* CFrame.Angles(0, 0, -lean)
		* CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
		* CFrame.new(0, shaft / 2 - width * 0.75, 0)
	local material = if core then Enum.Material.Glass else Enum.Material.Neon
	local look = if core then { Transparency = 0.35, Reflectance = 0.15 } else nil
	part(parent, at, Vector3.new(width, shaft, width), glow, material, nil, look).Name = "Crystal"
	local point = at * CFrame.new(0, (shaft + tip) / 2, 0)
	part(parent, point, Vector3.new(width, tip, width), glow, material, "CornerWedge", look).Name = "Crystal"
	if core then
		local heart = if color then color:Lerp(Color3.new(1, 1, 1), 0.65) else CRYSTAL_CORE
		part(parent, at, Vector3.new(width * 0.5, shaft * 0.9, width * 0.5), heart, Enum.Material.Neon).Name =
			"CrystalCore"
	end
end

-- A glowing ore vein across one side of a stone: two strokes with a bend.
local function vein(parent, stone: BasePart, rng, color: Color3?)
	local side = rng:NextInteger(0, 3)
	local across = if side % 2 == 0 then stone.Size.X else stone.Size.Z
	local depth = (if side % 2 == 0 then stone.Size.Z else stone.Size.X) / 2
	local stroke = math.min(across, stone.Size.Y) * 0.3
	local face = stone.CFrame * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, stone.Size.Y * 0.08, depth)
	local first = face * CFrame.Angles(0, 0, rng:NextNumber(-1.2, 1.2)) * CFrame.new(0, -stroke / 2, 0)
	local bend = rng:NextNumber(0.5, 0.9) * (if rng:NextNumber() < 0.5 then -1 else 1)
	local second = first * CFrame.new(0, stroke / 2, 0) * CFrame.Angles(0, 0, bend) * CFrame.new(0, stroke / 2, 0)
	for _, at in { first, second } do
		part(parent, at, Vector3.new(0.16, stroke + 0.12, 0.16), color or GLOW, Enum.Material.Neon).Name = "Vein"
	end
end

-- The face of a block that looks most upward: its centre and its normal.
local function upFace(p: BasePart): (Vector3, Vector3)
	local best, normal, depth = -2, Vector3.yAxis, p.Size.Y / 2
	for _, axis in
		{ { p.CFrame.RightVector, p.Size.X }, { p.CFrame.UpVector, p.Size.Y }, { p.CFrame.LookVector, p.Size.Z } }
	do
		for _, sign in { 1, -1 } do
			local n = axis[1] * sign
			if n.Y > best then
				best, normal, depth = n.Y, n, axis[2] / 2
			end
		end
	end
	return p.CFrame.Position + normal * depth, normal
end

-- The everyday rocks (Regolith Chunk, Crystal Boulder): tilted basalt
-- chunks heaped on a scorched bed, ore veins in their sides and a crystal
-- cluster bursting out of the top (the boulder has a second one breaking
-- out of a flank).
local function crystalRock(model: Model, big: boolean, cframe: CFrame, rng, tint: Color3?, stone: Color3?): Model
	local s = if big then 6 else 3.6
	local glow = tint or GLOW
	-- (Out in a biome, its basalt takes on the biome's stone.)
	local basalt = if stone then BASALT:Lerp(stone, 0.7) else BASALT
	local pale, dark = BASALT_LIGHT, BASALT_DARK
	if stone then
		pale, dark = pale:Lerp(stone, 0.5), dark:Lerp(stone, 0.5)
	end
	local function lean(low: number, high: number): number
		return rng:NextNumber(low, high) * (if rng:NextNumber() < 0.5 then -1 else 1)
	end
	local ground = cframe * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local bed = disc(model, ground * CFrame.new(0, 0.04, 0), s * 0.64, 0.08, BED, Enum.Material.Slate)
	bed.CastShadow = false
	local body = solid(
		part(
			model,
			ground * CFrame.new(0, s * 0.18, 0) * CFrame.Angles(lean(0.3, 0.5), 0, lean(0.2, 0.4)),
			Vector3.new(s * 0.78, s * 0.62, s * 0.7),
			basalt,
			Enum.Material.Basalt
		)
	)
	body.Name = "Body"
	model.PrimaryPart = body
	-- Stones heaped around it, tipped every way and sunk into the bed.
	local stones = {}
	local around = if big then 4 else 3
	for i = 1, around do
		local a = i / around * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = s * rng:NextNumber(0.3, 0.42)
		local w, h = s * rng:NextNumber(0.36, 0.5), s * rng:NextNumber(0.28, 0.42)
		table.insert(
			stones,
			part(
				model,
				ground
					* CFrame.new(math.cos(a) * r, h * 0.15, math.sin(a) * r)
					* CFrame.Angles(lean(0.2, 0.6), rng:NextNumber(0, 6.28), lean(0.2, 0.6)),
				Vector3.new(w, h, w * rng:NextNumber(0.75, 1.1)),
				basalt:Lerp(if i % 2 == 0 then pale else dark, rng:NextNumber(0.2, 0.7)),
				Enum.Material.Basalt
			)
		)
	end
	-- The cluster on the top face: one tall crystal, the rest fanned out.
	local base, up = upFace(body)
	local heading = math.atan2(-up.Z, up.X)
	local tilt = math.acos(math.clamp(up.Y, -1, 1))
	shard(
		model,
		base,
		heading,
		tilt * 0.5,
		s * (if big then 0.78 else 0.62),
		s * (if big then 0.16 else 0.14),
		rng,
		true,
		tint
	)
	local fan = if big then 3 else 2
	for i = 1, fan do
		local h = heading + i / fan * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local first = big and i == 1
		local width = s * (if first then 0.12 else 0.09)
		-- Rooted beside the tall one on the same face, never inside the rock.
		local away = Vector3.new(math.cos(h), 0, -math.sin(h))
		away = (away - up * away:Dot(up)).Unit
		local length = s * (if first then 0.54 else rng:NextNumber(0.36, 0.46))
		shard(model, base + away * width * 1.1, h, rng:NextNumber(0.5, 0.85), length, width, rng, first, tint)
	end
	if big then
		-- A second, smaller cluster breaking out of the flank that faces most
		-- upward (one facing down would hide it).
		local flank, outward = nil, Vector3.new(0, -2, 0)
		for side = 0, 3 do
			local across = if side % 2 == 0 then body.Size.X else body.Size.Z
			local depth = (if side % 2 == 0 then body.Size.Z else body.Size.X) / 2
			local at = body.CFrame
				* CFrame.Angles(0, side * math.pi / 2, 0)
				* CFrame.new(rng:NextNumber(-0.2, 0.2) * across, body.Size.Y * 0.18, depth - 0.1)
			local facing = at:VectorToWorldSpace(Vector3.zAxis)
			if facing.Y > outward.Y then
				flank, outward = at, facing
			end
		end
		local h = math.atan2(-outward.Z, outward.X)
		for i = 1, 2 do
			shard(
				model,
				flank.Position + Vector3.new(0, (i - 1.5) * s * 0.1, 0),
				h + (i - 1.5) * 0.6,
				math.clamp(math.acos(math.clamp(outward.Y, -1, 1)), 0.6, 1.15),
				s * rng:NextNumber(0.28, 0.36),
				s * 0.08,
				rng,
				nil,
				tint
			)
		end
	end
	vein(model, body, rng, tint)
	vein(model, stones[1], rng, tint)
	if big then
		vein(model, stones[2], rng, tint)
	end
	-- Rubble at its foot, and a chip of crystal knocked loose.
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = s * rng:NextNumber(0.56, 0.72)
		local w = s * rng:NextNumber(0.09, 0.14)
		part(
			model,
			ground
				* CFrame.new(math.cos(a) * r, w * 0.25, math.sin(a) * r)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			Vector3.new(w, w * 0.7, w * 0.85),
			basalt:Lerp(dark, rng:NextNumber(0, 1)),
			Enum.Material.Basalt
		)
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local chip = part(
		model,
		ground
			* CFrame.new(math.cos(a) * s * 0.55, 0.18, math.sin(a) * s * 0.55)
			* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			* CFrame.Angles(1.3, 0, 0),
		Vector3.new(s * 0.06, s * 0.16, s * 0.06),
		glow,
		Enum.Material.Neon,
		"Wedge"
	)
	chip.Name = "Crystal"
	-- A small glow on its own bed. The field round the middle holds a hundred
	-- rocks, and wider lights overlapped into a floor (and miners) washed
	-- cyan-white; the neon crystals glow without lighting anything.
	light(body, glow, s * 1.4, 0.5)
	return model
end

-- The rarer rocks: kit art (when imported) or a heap of tilted slabs, with
-- crystals breaking through, sized and coloured by its kind.
local ROCK_KIT = {
	Monolith = { "rock_tallA", "rock_tallB", "rock_tallC", "rock_tallD", "rock_tallG", "rock_tallH", "rock_tallI" },
	Geode = { "rock_crystalsLargeA", "rock_crystalsLargeB", "rock_crystals", "meteor_detailed" },
}
local ROCK_TINT = {
	Monolith = Color3.fromRGB(104, 98, 114),
	Geode = Color3.fromRGB(100, 78, 128),
}

function OutpostWorld.rock(size: string, cframe: CFrame, rng: Random, tint: Color3?, stone: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Rock"
	if size == "Pebble" or size == "Boulder" then
		-- (Out along the trails their crystals warm from cyan to gold to
		-- rose; a Rift Vein's are rift-touched violet.)
		return crystalRock(model, size == "Boulder", cframe, rng, tint, stone)
	end
	local spec = ({
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
		light(body, crystal, s * 1.8, if size == "Geode" then 1.4 else 0.7) -- (small, like the everyday rocks')
		return model
	end
	local body = part(
		model,
		cframe
			* CFrame.new(0, s * 0.42 * tall, 0)
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)),
		Vector3.new(s, s * 0.85 * tall, s * 0.9),
		stone,
		Enum.Material.Glass
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
			Enum.Material.Glass
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
	light(body, crystal, s * 1.8, if size == "Geode" then 1.4 else 0.7)
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

-- The base's signs, one system everywhere: a dark face in a steel frame,
-- a bar of its station's colour (`color`) down the left, the name in warm
-- white condensed capitals and a plain line under it in grey. Nothing
-- glows: the colour is a marking, not a light. Read from its front (build
-- it with CFrame.lookAt(where, toward the reader)), and from its back too
-- if `both` (a blade sign standing out from a wall). Returns the panel, its
-- front's SurfaceGui and title.
local SIGN_FACE = Color3.fromRGB(30, 33, 40)
local SIGN_EDGE = Color3.fromRGB(92, 96, 106)
local SIGN_TEXT = Color3.fromRGB(238, 234, 224)
local SIGN_SUB = Color3.fromRGB(150, 156, 166)
local function signFace(board: BasePart, side: Enum.NormalId, size: Vector3, title: string, sub: string?, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = side
	gui.CanvasSize = Vector2.new(size.X * 40, size.Y * 40)
	gui.LightInfluence = 0
	gui.Parent = board
	local tall = size.Y * 40
	local edge = math.max(2, math.floor(tall * 0.05))
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = SIGN_EDGE
	frame.Parent = gui
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Position = UDim2.fromOffset(edge, edge)
	face.Size = UDim2.new(1, -edge * 2, 1, -edge * 2)
	face.BorderSizePixel = 0
	face.BackgroundColor3 = SIGN_FACE
	face.Parent = frame
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0, math.max(3, math.floor(tall * 0.09)), 1, 0)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = color
	bar.Parent = face
	local inset = math.floor(tall * 0.09) + math.floor(tall * 0.16)
	local head = Instance.new("TextLabel")
	head.Name = "Title"
	head.BackgroundTransparency = 1
	head.Position = UDim2.new(0, inset, if sub then 0.1 else 0.14, 0)
	head.Size = UDim2.new(1, -inset * 1.4, if sub then 0.5 else 0.72, 0)
	head.Text = title
	head.TextScaled = true
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Font = Enum.Font.Oswald
	head.TextColor3 = SIGN_TEXT
	head.Parent = face
	if sub then
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.BackgroundTransparency = 1
		line.Position = UDim2.new(0, inset, 0.64, 0)
		line.Size = UDim2.new(1, -inset * 1.4, 0.24, 0)
		line.Text = sub
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Font = Enum.Font.GothamMedium
		line.TextColor3 = SIGN_SUB
		line.Parent = face
	end
	return gui, head
end
local function signPanel(parent, cframe: CFrame, size: Vector3, title: string, sub: string?, color: Color3, both: boolean?)
	local board = part(parent, cframe, size, HULL_DARK, Enum.Material.Metal)
	board.Name = "Sign"
	local gui, head = signFace(board, Enum.NormalId.Front, size, title, sub, color)
	if both then
		signFace(board, Enum.NormalId.Back, size, title, sub, color)
	end
	return board, gui, head
end

-- Standing at `from`, turned to face `toward` (level).
local function facingPoint(from: Vector3, toward: Vector3): CFrame
	return CFrame.new(from) * CFrame.Angles(0, math.atan2(-(toward.X - from.X), -(toward.Z - from.Z)), 0)
end

-- A rod of `radius` from `a` to `b` (a cylinder along it).
local function strut(parent, a: Vector3, b: Vector3, radius: number, color: Color3, material)
	local along = b - a
	local axis = along.Unit
	local up = if math.abs(axis.Y) < 0.95 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local side = axis:Cross(up).Unit
	return part(
		parent,
		CFrame.fromMatrix((a + b) / 2, axis, side:Cross(axis).Unit, side),
		Vector3.new(along.Magnitude, radius * 2, radius * 2),
		color,
		material or Enum.Material.Metal,
		"Cylinder"
	)
end

-- PROBE-7 STATION: the probe that brought the first miners' supplies,
-- landed and unfolded where it came down. It stands on four landing legs
-- over its pad; its top split into four petals that peeled back round the
-- glowing core; its front hatch folded down over the terminal, its side
-- bays opened into racks of swing refill cells, its solar wings swung out
-- level and its mast telescoped up to the dish. Its name turns over it
-- (ProbeSign: Client.OutpostScene turns it).
-- Returns the terminal's screen.
local PROBE_HULL = Color3.fromRGB(176, 164, 136)
local PROBE_GOLD = Color3.fromRGB(214, 166, 72)
local function probe(parent, at: CFrame)
	local m = folder(parent, "Probe")
	local F = 0.86 -- the floor
	local function p(x, y, z)
		return (at * CFrame.new(x, F + y, z)).Position
	end
	local function cf(x, y, z)
		return at * CFrame.new(x, F + y, z)
	end
	-- Its landing pad: hazard-ringed, scorched under the pod.
	disc(m, cf(0, 0.03, 0), 12.5, 0.06, HAZARD)
	disc(m, cf(0, 0.05, 0), 11.9, 0.06, Color3.fromRGB(48, 52, 60))
	disc(m, cf(0, 0.07, 0), 6, 0.06, Color3.fromRGB(30, 30, 36))
	-- The pod, its heat shield, and the core where the top opened.
	solid(part(m, cf(0, 11, 0), Vector3.one * 12, PROBE_HULL, Enum.Material.DiamondPlate, "Ball"))
	part(
		m,
		cf(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(1.6, 12.8, 12.8),
		PROBE_GOLD,
		Enum.Material.Metal,
		"Cylinder"
	)
	part(
		m,
		cf(0, 16, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.5, 7, 7),
		HULL_DARK,
		Enum.Material.Metal,
		"Cylinder"
	)
	local core = part(m, cf(0, 16.8, 0), Vector3.one * 3.2, GLOW, Enum.Material.Neon, "Ball")
	core.Name = "ProbeCore"
	light(core, GLOW, 24, 1.5)
	-- The four petals of its top, peeled back on their hinges.
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local hinge = Vector3.new(0, 16, 0) + out * 3.4
		local tip = hinge + out * 4.4 + Vector3.new(0, -2.2, 0)
		local petal =
			strut(m, p(hinge.X, hinge.Y, hinge.Z), p(tip.X, tip.Y, tip.Z), 0.2, PROBE_HULL, Enum.Material.DiamondPlate)
		petal.Shape = Enum.PartType.Block
		petal.Size = Vector3.new(petal.Size.X, 0.35, 4.2)
		part(
			m,
			cf(hinge.X, hinge.Y, hinge.Z) * CFrame.Angles(0, -a, 0),
			Vector3.new(0.6, 0.6, 3),
			PROBE_GOLD,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
	-- Four landing legs: a strut to the knee, a hydraulic leg to the foot.
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local hip = Vector3.new(math.cos(a) * 5.9, 9.5, math.sin(a) * 5.9)
		local knee = Vector3.new(math.cos(a) * 10, 6.5, math.sin(a) * 10)
		local foot = Vector3.new(math.cos(a) * 11, 0.5, math.sin(a) * 11)
		strut(m, p(hip.X, hip.Y, hip.Z), p(knee.X, knee.Y, knee.Z), 0.55, STEEL)
		strut(m, p(knee.X, knee.Y, knee.Z), p(foot.X, foot.Y, foot.Z), 0.38, HULL_DARK)
		local sleeve = knee + (foot - knee) * 0.45
		strut(m, p(knee.X, knee.Y, knee.Z), p(sleeve.X, sleeve.Y, sleeve.Z), 0.56, HAZARD)
		part(m, cf(knee.X, knee.Y, knee.Z), Vector3.one * 1.4, STEEL, Enum.Material.Metal, "Ball")
		solid(disc(m, cf(foot.X, 0.25, foot.Z), 1.5, 0.5, HULL_DARK, Enum.Material.Metal))
	end
	-- The terminal, and the front hatch folded down over it.
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
	light(screen, Color3.fromRGB(180, 220, 240), 16, 1.2)
	local hatch = strut(m, p(0, 8.6, -5.4), p(0, 6.3, -10.2), 0.2, PROBE_HULL, Enum.Material.DiamondPlate)
	hatch.Shape = Enum.PartType.Block
	hatch.Size = Vector3.new(hatch.Size.X, 0.4, 7)
	-- The side bays, opened into racks of swing refill cells.
	for _, s in { -1, 1 } do
		local x = s * 8.2
		solid(part(m, cf(x, 3.6, 0), Vector3.new(3.2, 0.4, 6), HULL_DARK, Enum.Material.Metal))
		part(m, cf(x + s * 1.5, 5.4, 0), Vector3.new(0.3, 4, 6), PROBE_HULL, Enum.Material.DiamondPlate)
		part(m, cf(x, 7.5, 0), Vector3.new(3.4, 0.3, 6.4), PROBE_GOLD, Enum.Material.Metal)
		for k = -1, 1 do
			part(
				m,
				cf(x - s * 0.2, 4.7, k * 1.9) * CFrame.Angles(0, 0, math.rad(90)),
				Vector3.new(1.8, 1.1, 1.1),
				if k == 0 then SAGA else GLOW,
				Enum.Material.Neon,
				"Cylinder"
			)
		end
	end
	-- The solar wings, swung out level on their booms.
	for _, s in { -1, 1 } do
		strut(m, p(s * 5.8, 13.5, -1), p(s * 9, 13.5, -1), 0.35, STEEL)
		local wing = cf(s * 13.5, 13.7, -1) * CFrame.Angles(math.rad(8), 0, 0)
		part(m, wing, Vector3.new(9, 0.35, 7), Color3.fromRGB(40, 60, 110), Enum.Material.Glass)
		for k = -1, 1 do
			part(m, wing * CFrame.new(k * 3, 0.22, 0), Vector3.new(0.15, 0.1, 7), STEEL, Enum.Material.Metal)
		end
		part(m, wing * CFrame.new(0, 0, -3.55), Vector3.new(9, 0.16, 0.16), STEEL, Enum.Material.Metal)
	end
	-- The mast, telescoped up, the dish on top and a beacon.
	strut(m, p(2.2, 16.2, 2.4), p(2.2, 21, 2.4), 0.45, STEEL)
	strut(m, p(2.2, 21, 2.4), p(2.2, 25, 2.4), 0.33, HULL)
	strut(m, p(2.2, 25, 2.4), p(2.2, 28.4, 2.4), 0.22, STEEL)
	part(
		m,
		cf(2.2, 28.9, 2.4) * CFrame.Angles(math.rad(-35), 0, math.rad(90)),
		Vector3.new(0.4, 5.2, 5.2),
		HULL,
		Enum.Material.Metal,
		"Cylinder"
	)
	part(
		m,
		cf(2.2, 29.5, 2.0) * CFrame.Angles(math.rad(-35), 0, math.rad(90)),
		Vector3.new(1.4, 0.4, 0.4),
		HULL_DARK,
		Enum.Material.Metal,
		"Cylinder"
	)
	part(m, cf(2.2, 30.3, 2.4), Vector3.one * 0.6, Color3.fromRGB(255, 70, 70), Enum.Material.Neon, "Ball")
	-- Its name in light over the core, turning (the client spins it; see
	-- OutpostScene).
	local holo = part(
		m,
		cf(0, 22.5, 0),
		Vector3.new(12, 3.6, 0.1),
		GLOW,
		Enum.Material.SmoothPlastic,
		nil,
		{ Transparency = 1, CastShadow = false }
	)
	holo.Name = "ProbeSign"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(480, 144)
		gui.LightInfluence = 0
		gui.Brightness = 1.2
		gui.Parent = holo
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = "PROBE-7"
		text.TextScaled = true
		text.Font = Enum.Font.Oswald
		text.TextColor3 = Color3.fromRGB(200, 230, 245)
		text.TextTransparency = 0.1
		text.Parent = gui
	end
	-- Power cables from its belly into sockets in the floor.
	for _, spot in { Vector3.new(-4, 0, 9.5), Vector3.new(4, 0, 9.5), Vector3.new(0, 0, 10.5) } do
		strut(m, p(spot.X * 0.3, 5.4, 2), p(spot.X, 0.6, spot.Z), 0.3, Color3.fromRGB(30, 30, 36))
		part(m, cf(spot.X, 0.3, spot.Z), Vector3.new(1.4, 0.6, 1.4), HAZARD, Enum.Material.Metal)
	end
	-- Its name, on the heat shield over the hatch.
	local name = (at * CFrame.new(0, F + 13.6, -5.7)).Position
	signPanel(
		m,
		facingPoint(name, name + at:VectorToWorldSpace(Vector3.new(0, 0, -1))),
		Vector3.new(7, 1.5, 0.3),
		"PROBE-7 STATION",
		"SWING REFILLS",
		GLOW
	)
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
	part(m, frame.CFrame * CFrame.new(0, 7.8, 0), Vector3.new(30.4, 0.6, 0.9), STEEL, Enum.Material.Metal)
	light(face, Color3.fromRGB(220, 230, 240), 22, 0.8)
	return face
end

-- The season, outside only: carved pumpkins at the Shelter's landing and in
-- a few patches out in the quarry. Static, non-interactive. (AMBER is also
-- the Shelter's work lights.)
local ORANGE = Color3.fromRGB(225, 106, 32)
local AMBER = Color3.fromRGB(255, 203, 126)
local LEAF = Color3.fromRGB(45, 91, 68)
local VIOLET = Color3.fromRGB(163, 105, 236)

-- A carved pumpkin standing at `pose`, `scale` times life size ("Pearl": a
-- pale one with violet eyes).
local function pumpkin(parent, pose: CFrame, scale: number, style: string?)
	local m = folder(parent, "MoonPumpkin")
	m:SetAttribute("PumpkinScale", scale)
	local rind = if style == "Pearl" then Color3.fromRGB(224, 214, 186) else ORANGE
	local groove = if style == "Pearl" then Color3.fromRGB(188, 175, 151) else Color3.fromRGB(191, 77, 28)
	local glow = if style == "Pearl" then VIOLET else AMBER
	for i = 0, 7 do
		local a = i * math.pi / 4
		part(m, pose * CFrame.new(math.cos(a) * .48 * scale, .9 * scale, math.sin(a) * .48 * scale),
			Vector3.new(1.3, 1.65, 1.3) * scale, if i % 2 == 0 then rind else groove,
			Enum.Material.SmoothPlastic, "Ball")
	end
	part(m, pose * CFrame.new(0, 1.85 * scale, 0) * CFrame.Angles(0, 0, -.25),
		Vector3.new(.27, .6, .27) * scale, LEAF, Enum.Material.Wood)
	for _, xEye in { -.38, .38 } do
		part(m, pose * CFrame.new(xEye * scale, 1.08 * scale, 1.04 * scale) * CFrame.Angles(0, 0, xEye * .5),
			Vector3.new(.3, .35, .12) * scale, glow, Enum.Material.Neon, if style == "Pearl" then "Ball" else nil)
	end
	local smile = part(m, pose * CFrame.new(0, .6 * scale, 1.08 * scale),
		Vector3.new(.7, .18, .12) * scale, glow, Enum.Material.Neon)
	if scale > 2.5 then
		-- A gap-toothed smile on the giant ones.
		part(m, pose * CFrame.new(.12 * scale, .66 * scale, 1.16 * scale),
			Vector3.new(.14, .13, .06) * scale, rind)
		light(smile, glow, 20, .75)
	end
	return m
end

-- Pumpkin patches out in the quarry, by the paths: a big one, a pearl and a
-- little one. Returns their footprints, kept clear of rocks.
local function harvestPatches(parent, at: CFrame)
	local decor = folder(parent, "HarvestPatches")
	local exclusions = {}
	for i, patch in { { -81, 153, 3.4 }, { 81, 153, 3.6 }, { -118, -6, 3.8 } } do
		local x, z, size = patch[1], patch[2], patch[3]
		table.insert(exclusions, { (at * CFrame.new(x, 0, z)).Position, 11 })
		local pose = at * CFrame.new(x, 0, z) * CFrame.Angles(0, if x < 0 then -.3 else .3, 0)
		pumpkin(decor, pose, size, if i == 2 then "Pearl" else nil)
		pumpkin(decor, at * CFrame.new(x - 5, 0, z + 3) * CFrame.Angles(0, -.5, 0), 1.05, "Pearl")
		pumpkin(decor, at * CFrame.new(x + 4.5, 0, z + 3.5) * CFrame.Angles(0, .3, 0), .55)
	end
	return exclusions
end

-- The Arena Uplink: a ring gate on a pad, for queuing duels.
local function gate(parent, at: CFrame)
	local m = folder(parent, "ArenaGate")
	-- (a steel pad, a red ring painted on it)
	disc(m, at * CFrame.new(0, 0.4, 0), 9, 0.8, HULL_DARK, Enum.Material.Metal)
	disc(m, at * CFrame.new(0, 0.82, 0), 7, 0.06, Color3.fromRGB(176, 70, 60))
	disc(m, at * CFrame.new(0, 0.84, 0), 6.3, 0.06, HULL_DARK, Enum.Material.Metal)
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
		Color3.fromRGB(196, 78, 66),
		Enum.Material.Neon,
		"Cylinder",
		{ Transparency = 0.62 }
	)
	local pad =
		part(m, at * CFrame.new(0, 2, 0), Vector3.new(6, 4, 6), Color3.new(1, 1, 1), nil, nil, { Transparency = 1 })
	pad.Name = "GatePad"
	light(pad, Color3.fromRGB(255, 140, 120), 18, 1)
	return pad
end

-- Stars, far off in the black: nothing else up there but the rift (the
-- client's, Client.SkyRift).
local function sky(parent, at: CFrame)
	local m = folder(parent, "Sky")
	pcall(function()
		(m :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
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
-- Where a vein's dormant rift sits: its Rift Gate, a way into the
-- critters' own world (Server.RiftServer). Scorched ground with cracks of
-- that world's fire running out from it, and over it an arch of black,
-- jagged rock standing round the tear (drawn by each player's client in
-- that world's colours: RiftTear), embers rising, fire at its feet, and
-- its prompt ("Enter the Rift": PromptKind Rift, Vein `index`). Its own
-- model, so it moves with its vein; the guarded vein's cracks are `color`.
function OutpostWorld.veinMarks(parent, at: CFrame, rng, color: Color3?, index: number?): Model
	local model = Instance.new("Model")
	model.Name = "VeinMarks"
	model.Parent = parent
	local hell = Color3.fromRGB(255, 84, 24)
	local ember = Color3.fromRGB(255, 150, 52)
	local black = Color3.fromRGB(26, 20, 24)
	local bed = disc(model, at * CFrame.new(0, 0.06, 0), 7.5, 0.1, Color3.fromRGB(40, 24, 22), Enum.Material.Slate)
	bed.CastShadow = false
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local length = rng:NextNumber(3, 7)
		local crack = part(
			model,
			at * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.13, -(1.6 + length / 2)),
			Vector3.new(rng:NextNumber(0.16, 0.3), 0.06, length),
			color or hell,
			Enum.Material.Neon
		)
		crack.Name = "ScarCrack"
		crack.CastShadow = false
	end
	-- The arch: jagged shards of black rock in a horseshoe round the tear
	-- (5.4 up, about 9 tall: FrontierServer.scar), each bit set at its own
	-- angle, the inside edge of each glowing.
	local arch = Instance.new("Model")
	arch.Name = "RiftGate"
	arch.Parent = model
	local middle = at * CFrame.new(0, 5.4, 0)
	local pieces = 13
	for i = 0, pieces - 1 do
		local t = math.rad(-28) + i / (pieces - 1) * math.rad(236)
		local r = 6.3 + rng:NextNumber(-0.3, 0.5)
		local frame = middle * CFrame.new(math.cos(t) * r, math.sin(t) * r, 0) * CFrame.Angles(0, 0, t)
		local long = rng:NextNumber(1.8, 3.4)
		part(
			arch,
			frame * CFrame.new(long / 2 - 0.6, 0, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.3, 0.3)),
			Vector3.new(long, rng:NextNumber(1.6, 2.6), rng:NextNumber(1.4, 2.2)),
			black,
			Enum.Material.Slate,
			if i % 3 == 0 then "Wedge" else nil
		)
		local edge = part(arch, frame * CFrame.new(-0.55, 0, 0), Vector3.new(0.18, 1.5, 0.5), hell, Enum.Material.Neon)
		edge.CastShadow = false
	end
	-- Its feet, broken out of the ground either side, fire licking up them.
	for _, side in { -1, 1 } do
		local foot = part(
			arch,
			middle * CFrame.new(side * 6.2, -4.6, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(3.2, 2.4, 3),
			black,
			Enum.Material.Slate
		)
		local flame = Instance.new("Fire")
		flame.Size = 4
		flame.Heat = 9
		flame.Color = ember
		flame.SecondaryColor = Color3.fromRGB(150, 26, 20)
		flame.Parent = foot
	end
	-- The hole's light, and embers rising out of it.
	local heart = part(arch, middle, Vector3.new(1, 1, 1), hell, Enum.Material.Neon)
	heart.Name = "Heart"
	heart.Transparency = 1
	local glow = Instance.new("PointLight")
	glow.Color = hell
	glow.Range = 22
	glow.Brightness = 1.6
	glow.Shadows = false
	glow.Parent = heart
	local embers = Instance.new("ParticleEmitter")
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Rate = 9
	embers.Lifetime = NumberRange.new(1.8, 3)
	embers.Speed = NumberRange.new(2, 5)
	embers.SpreadAngle = Vector2.new(40, 40)
	embers.Size = NumberSequence.new(0.22)
	embers.Color = ColorSequence.new(ember, hell)
	embers.LightEmission = 1
	embers.Parent = heart
	-- The way in.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterRift"
	prompt.ActionText = "Enter the Rift"
	prompt.ObjectText = "RIFT GATE"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Rift")
	prompt:SetAttribute("Vein", index or 0)
	prompt.Parent = heart
	return model
end

local NEAR_SPOTS = 52 -- rock spots in the field round the middle (the outcrops lead out from it)
local NEAR_REACH = 140 -- studs: the field stays inside the core (Shared.Frontier.Core)

-- Two wedges make the triangle a, b, c, `thick` studs through; returns them.
local function triangle(parent, at, a, b, c, thick: number, color, material): { BasePart }
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
	local faces = {}
	for _, spec in {
		{ (a + b) / 2, right, back, math.abs(ab:Dot(back)) },
		{ (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) },
	} do
		table.insert(
			faces,
			part(
				parent,
				at * CFrame.fromMatrix(spec[1], spec[2], up, spec[3]),
				Vector3.new(thick, height, math.max(0.05, spec[4])),
				color,
				material,
				"Wedge"
			)
		)
	end
	return faces
end

-- Connected triangles make a continuous crater surface rather than separate
-- vertical towers. Shared vertices keep the silhouette and slopes seam-free.
local function craterFace(parent, at, a, b, c, color, material)
	for _, face in triangle(parent, at, a, b, c, 0.6, color, material) do
		face.Name = "CraterSurface"
	end
end

local function craterRim(parent, at: CFrame)
	local rim = folder(parent, "NaturalCraterRim")
	-- Sent to every player whole, like the sky. It stands 470-770 studs out,
	-- so from most of the quarry its far side is past what streaming sends
	-- (1,024 studs at best, much less on a phone), and it never loaded.
	pcall(function()
		(rim :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local rng = Random.new(8217)
	local segments = 72
	-- Low debris apron, eroded inner wall, broad crest, and a falling outer slope.
	-- All scenery stays beyond the playable benches and machine routes.
	local profile = {
		{ 471, 12 }, { 503, 24 }, { 555, 65 },
		{ 619, 105 }, { 687, 68 }, { 772, -12 },
	}
	local rings = {}
	for band, spec in profile do
		local points = {}
		for i = 0, segments - 1 do
			local angle = i / segments * math.pi * 2
			local relief = math.sin(angle * 3 + 0.4) * 25 + math.sin(angle * 5 - 0.7) * 14
			local erosion = (0.5 + 0.5 * math.sin(angle * 11 + 0.8)) ^ 4
			local weight = if band == 1 then 0 else if band == 2 then 0.24 else if band == 6 then 0.25 else 1
			local radius = spec[1] + weight * (math.sin(angle * 3) * 22 + math.sin(angle * 7 + band * 0.7) * 14)
			local channelDepth = if band == 3 then 26 else 12
			local height = spec[2] + weight * (relief - erosion * channelDepth + math.sin(angle * 9 + band) * 5)
			local bearing = angle + weight * math.sin(angle * 6 + band) * 0.018
			points[i + 1] = Vector3.new(math.cos(bearing) * radius, height, math.sin(bearing) * radius)
		end
		rings[band] = points
	end
	for band = 1, #rings - 1 do
		for i = 1, segments do
			local j = i % segments + 1
			local angle = (i - 1) / segments * math.pi * 2
			local height = (rings[band][i].Y + rings[band + 1][j].Y) / 2
			local shade = math.clamp(height / 160, 0, 0.85)
			local color = Color3.fromRGB(99, 102, 113):Lerp(Color3.fromRGB(139, 141, 151), shade)
			color = color:Lerp(REGOLITH_DARK, (0.5 + 0.5 * math.sin(angle * 11 + 0.8)) * 0.08)
			local material = if band == 1 or band == 5 then Enum.Material.Sand else Enum.Material.Rock
			craterFace(rim, at, rings[band][i], rings[band + 1][i], rings[band + 1][j], color, material)
			craterFace(rim, at, rings[band][i], rings[band + 1][j], rings[band][j], color, material)
		end
	end
	-- Low, half-buried fragments break up the join with the worked quarry benches.
	for i = 0, 47 do
		local angle = (i + rng:NextNumber(-0.25, 0.25)) / 48 * math.pi * 2
		local radius = rng:NextNumber(481, 495)
		local width = rng:NextNumber(8, 18)
		local rockAt = at * CFrame.new(math.cos(angle) * radius, 16 + (radius - 481) * 0.35, math.sin(angle) * radius)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), angle, rng:NextNumber(-0.25, 0.25))
		local height = rng:NextNumber(5, 9)
		local color = REGOLITH:Lerp(RIM, rng:NextNumber(0.2, 0.65))
		for side = -1, 1, 2 do
			local rock = part(rim, rockAt * CFrame.new(0, 0, side * width * 0.175)
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				Vector3.new(width, height, width * 0.35), color, Enum.Material.Rock, "Wedge")
			rock.Name = "CraterScree"
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

-- The biomes' ground and landmarks (Shared.Frontier.Biomes) ---------------------------------------------

-- Ashfall: a smouldering vent, an ember glowing in its throat.
local function vent(parent, base: CFrame, rng, biome, smoke: boolean): number
	local dark = biome.Stone:Lerp(Color3.new(0, 0, 0), 0.35)
	disc(parent, base * CFrame.new(0, 0.7, 0), 6.5, 1.4, dark, Enum.Material.Basalt)
	disc(parent, base * CFrame.new(0, 1.7, 0), 3.8, 1.2, dark, Enum.Material.Basalt)
	local ember = disc(parent, base * CFrame.new(0, 2.32, 0), 2.6, 0.12, biome.Glow, Enum.Material.Neon)
	for _ = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2)
		part(
			parent,
			base
				* CFrame.new(math.cos(a) * 4.6, 1.5, math.sin(a) * 4.6)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.3, 0.3)),
			Vector3.new(1.6, 3.4, 2.4),
			dark,
			Enum.Material.Basalt,
			"Wedge"
		)
	end
	if smoke then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Rate, emitter.Lifetime = 3, NumberRange.new(3, 5)
		emitter.Speed = NumberRange.new(3, 5)
		emitter.Size = NumberSequence.new(2, 9)
		emitter.Transparency = NumberSequence.new(0.65, 1)
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 100, 96))
		emitter.Parent = ember
	end
	return 7
end

-- Rimefrost: a cluster of ice spires on a drift of frost.
local function spires(parent, base: CFrame, rng, biome): number
	disc(parent, base * CFrame.new(0, 0.06, 0), 7, 0.12, biome.Ground, Enum.Material.Snow)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local h = rng:NextNumber(7, 15)
		local ice = part(
			parent,
			base
				* CFrame.new(math.cos(a) * 2.2, h / 2 - 0.5, math.sin(a) * 2.2)
				* CFrame.Angles(math.sin(a) * 0.22, rng:NextNumber(0, 6.28), -math.cos(a) * 0.22),
			Vector3.new(2.2, h, 2.2),
			biome.Glow:Lerp(Color3.new(1, 1, 1), 0.55),
			Enum.Material.Ice
		)
		ice.Transparency = 0.15
	end
	return 7
end

-- Stormglass: a pylon of storm glass with a charge running up its core.
local function pylon(parent, base: CFrame, rng, biome): number
	disc(parent, base * CFrame.new(0, 0.3, 0), 4.5, 0.6, biome.Stone, Enum.Material.Slate)
	local h = rng:NextNumber(11, 18)
	for i = 1, 2 do
		local glass = part(
			parent,
			base
				* CFrame.new(0, h / 2, 0)
				* CFrame.Angles(0, i * math.pi / 4 + rng:NextNumber(0, 0.5), if i == 1 then 0.1 else -0.08),
			Vector3.new(2.4, h, 2.4),
			Color3.fromRGB(150, 132, 222),
			Enum.Material.Glass
		)
		glass.Transparency = 0.3
	end
	part(parent, base * CFrame.new(0, h * 0.45, 0), Vector3.new(0.7, h * 0.8, 0.7), biome.Glow, Enum.Material.Neon)
	return 5
end

-- Blightwood: a dead tree in the mud, a spore pod swelling on a branch.
local function snag(parent, base: CFrame, rng, biome): number
	disc(parent, base * CFrame.new(0, 0.06, 0), 6, 0.12, biome.Ground, Enum.Material.Mud)
	local bark = Color3.fromRGB(58, 52, 44)
	local h = rng:NextNumber(9, 13)
	local trunk = base * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), 0)
	part(parent, trunk * CFrame.new(0, h / 2, 0), Vector3.new(1.4, h, 1.4), bark, Enum.Material.Wood)
	local tip = trunk
	for i, side in { -1, 1 } do
		local branch = trunk
			* CFrame.new(0, h * (0.62 + i * 0.12), 0)
			* CFrame.Angles(0, 0, side * 0.75)
			* CFrame.new(0, 2.4, 0)
		part(parent, branch, Vector3.new(0.7, 4.8, 0.7), bark, Enum.Material.Wood)
		tip = branch * CFrame.new(0, 2.6, 0)
	end
	part(parent, tip, Vector3.new(1.8, 1.8, 1.8), biome.Glow, Enum.Material.Neon, "Ball")
	return 6
end

local LANDMARK = { Ashfall = vent, Rimefrost = spires, Stormglass = pylon, Blightwood = snag }

-- Each biome's landmarks, out past the core deep in its own ground (where
-- its look counts LANDMARK_DEEP or more, clear of its swaying borders):
-- BIOME_LANDMARKS of them where `clear` says there's room; returns where
-- they stand, as { Vector3, studs } to keep the rocks off.
local BIOME_LANDMARKS, LANDMARK_DEEP = 6, 0.95
local function biomeGround(parent, at: CFrame, rng, Frontier, clear: (Vector3, number) -> boolean): { any }
	local taken = {}
	for index, biome in Frontier.Biomes do
		local here = folder(parent, biome.Id)
		local placed, tries = 0, 0
		while placed < BIOME_LANDMARKS and tries < 400 do
			tries += 1
			local a = biome.Angle + rng:NextNumber(-math.pi / 3, math.pi / 3)
			local r = rng:NextNumber(Frontier.Core + 35, 370)
			local offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local p = (at * CFrame.new(offset)).Position
			local roomy = Frontier.biomeMix(offset)[index] >= LANDMARK_DEEP and clear(p, 0)
			for _, other in taken do
				if (other[1] - p).Magnitude < 44 then
					roomy = false
				end
			end
			if roomy then
				placed += 1
				local base = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local reach = LANDMARK[biome.Id](here, base, rng, biome, placed % 2 == 1)
				table.insert(taken, { p, reach + 6 })
			end
		end
	end
	return taken
end

-- The ground under the Loop, in Roblox terrain (Shared.Frontier.ground):
-- each biome's own materials, mixed in blotches across its swaying borders
-- and ragged into the core's regolith, flush with the quarry floor. The land
-- rises (each biome's Relief) only well clear of anything standing
-- (`blocked`: { Vector3, studs }), of the roads (`roads`: { { from, to } },
-- RoadHalf either side) and of the walls: RISE_CLEAR studs past them it
-- starts, RISE_FULL past them it's up. Laid in OutpostWorld.Terrain
-- (offline tests hand one in) or the workspace's; returns how many columns
-- it laid (0 with no terrain to lay them in).
local RISE_CLEAR, RISE_FULL, ROAD_HALF = 6, 26, 14
local function biomeTerrain(at: CFrame, Frontier, blocked: { any }, roads: { any }): number
	local terrain = OutpostWorld.Terrain
	if not terrain then
		local ok, found = pcall(function()
			return workspace:FindFirstChildOfClass("Terrain")
		end)
		terrain = if ok then found else nil
	end
	if not terrain then
		return 0
	end
	local ground = Frontier.Ground
	for name, color in ground.Colors do
		terrain:SetMaterialColor(Enum.Material[name], color)
	end
	local cell, reach, depth = ground.Cell, ground.Reach, ground.Depth
	local origin = at.Position
	-- (On terrain's grid: whole cells, wherever the quarry is.)
	local min = Vector3.new(
		math.floor((origin.X - reach) / cell) * cell,
		math.floor((origin.Y - depth) / cell) * cell,
		math.floor((origin.Z - reach) / cell) * cell
	)
	local size = math.ceil((origin.X + reach - min.X) / cell)
	local deep = math.ceil((origin.Z + reach - min.Z) / cell)
	local layers = math.ceil((origin.Y + ground.Depth - min.Y) / cell)
	local function middle(i: number, k: number): (number, number)
		return min.X + (i - 0.5) * cell - origin.X, min.Z + (k - 0.5) * cell - origin.Z
	end
	-- How much room each column has: studs past the nearest thing standing.
	local room = table.create(size * deep, math.huge)
	for _, b in blocked do
		local center, radius = b[1] - origin, b[2]
		local span = radius + RISE_FULL
		local i0 = math.max(1, math.floor((center.X + origin.X - span - min.X) / cell) + 1)
		local i1 = math.min(size, math.floor((center.X + origin.X + span - min.X) / cell) + 1)
		local k0 = math.max(1, math.floor((center.Z + origin.Z - span - min.Z) / cell) + 1)
		local k1 = math.min(deep, math.floor((center.Z + origin.Z + span - min.Z) / cell) + 1)
		for i = i0, i1 do
			for k = k0, k1 do
				local x, z = middle(i, k)
				local d = math.sqrt((x - center.X) ^ 2 + (z - center.Z) ^ 2) - radius
				local index = (i - 1) * deep + k
				if d < room[index] then
					room[index] = d
				end
			end
		end
	end
	local function roadRoom(x: number, z: number): number
		local best = math.huge
		for _, line in roads do
			local ax, az = line[1].X - origin.X, line[1].Z - origin.Z
			local dx, dz = line[2].X - origin.X - ax, line[2].Z - origin.Z - az
			local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
			local px, pz = ax + dx * t - x, az + dz * t - z
			best = math.min(best, math.sqrt(px * px + pz * pz) - ROAD_HALF)
		end
		return best
	end
	local AIR = Enum.Material.Air
	local materials, occupancies = table.create(size), table.create(size)
	local laid = 0
	for i = 1, size do
		local mi, oi = table.create(layers), table.create(layers)
		for y = 1, layers do
			mi[y], oi[y] = table.create(deep, AIR), table.create(deep, 0)
		end
		materials[i], occupancies[i] = mi, oi
		for k = 1, deep do
			local x, z = middle(i, k)
			local out = math.sqrt(x * x + z * z)
			if out <= reach then
				local name, _, rise = Frontier.ground(x, z)
				local height = 0
				if rise > 0.05 then
					local clear = math.min(room[(i - 1) * deep + k], roadRoom(x, z), reach - 24 - out)
					local t = math.clamp((clear - RISE_CLEAR) / (RISE_FULL - RISE_CLEAR), 0, 1)
					height = rise * t * t * (3 - 2 * t)
				end
				local material = Enum.Material[name]
				local top = origin.Y + height
				for y = 1, layers do
					local fill = math.clamp((top - (min.Y + (y - 1) * cell)) / cell, 0, 1)
					if fill > 0 then
						mi[y][k], oi[y][k] = material, fill
					end
				end
				laid += 1
			end
		end
	end
	terrain:WriteVoxels(
		Region3.new(min, min + Vector3.new(size * cell, layers * cell, deep * cell)),
		cell,
		materials,
		occupancies
	)
	return laid
end

-- At each spoke's mouth, just out of the core, a sign either side of the
-- road naming the biome that side, facing whoever heads out; returns where
-- they stand ({ Vector3, studs }, to keep the rocks off).
local function crossroads(parent, at: CFrame, Frontier): { any }
	local signs = folder(parent, "Crossroads")
	local feet = {}
	for _, a in Frontier.Spokes do
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local right = Vector3.new(-out.Z, 0, out.X)
		for _, side in { -1, 1 } do
			-- (Right of the road heading out is clockwise round the Loop.)
			local biome = Frontier.biomeOf(a + side * 0.1)
			local foot = at.Position + out * (Frontier.Core + 30) + right * side * 15
			part(signs, CFrame.new(foot + Vector3.new(0, 4.5, 0)), Vector3.new(0.8, 9, 0.8), STEEL, Enum.Material.Metal)
			local high = foot + Vector3.new(0, 9.6, 0)
			signPanel(
				signs,
				facingPoint(high, high - out),
				Vector3.new(10, 3.4, 0.4),
				string.upper(biome.Name),
				biome.Label,
				biome.Glow
			)
			table.insert(feet, { foot, 9 })
		end
	end
	return feet
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

-- The survey table, on the west side of the hall: a low steel table with
-- the quarry's survey under its glass (Shared.Frontier's bands as rings,
-- the Core, the Fringe and the Edge, the crater wall round them and the
-- Shelter in the middle), four benches round it for a briefing, and its
-- name on a post. The client sweeps a scan across the map
-- (Client.ShelterLife).
local function surveyTable(parent, at: CFrame)
	local m = folder(parent, "SurveyTable")
	local frontier = OutpostWorld.Frontier
	local core, edge, rim = 150, 300, 440
	if frontier then
		core, edge = frontier.Core or core, frontier.EdgeFrom or edge
	end
	-- The table: a plinth, a steel top round the map, the map's dark glass.
	solid(part(m, at * CFrame.new(0, 1.2, 0), Vector3.new(7, 2.4, 7), HULL_DARK, Enum.Material.Metal))
	solid(part(m, at * CFrame.new(0, 2.55, 0), Vector3.new(11.6, 0.3, 11.6), STEEL, Enum.Material.Metal))
	local glass = part(m, at * CFrame.new(0, 2.72, 0), Vector3.new(10.4, 0.06, 10.4), Color3.fromRGB(14, 20, 28),
		Enum.Material.Glass)
	glass.Name = "SurveyMap"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(520, 520)
	gui.LightInfluence = 0
	gui.Brightness = 0.9
	gui.Parent = glass
	local map = Instance.new("Frame")
	map.Size = UDim2.fromScale(1, 1)
	map.BorderSizePixel = 0
	map.BackgroundColor3 = Color3.fromRGB(12, 19, 27)
	map.Parent = gui
	-- (a faint grid, every 100 studs)
	for k = -4, 4 do
		for _, across in { true, false } do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.fromRGB(46, 70, 86)
			line.BackgroundTransparency = 0.55
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = if across then UDim2.fromScale(0.5 + k * 100 / (rim * 2.2), 0.5) else UDim2.fromScale(0.5, 0.5 + k * 100 / (rim * 2.2))
			line.Size = if across then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1)
			line.Parent = map
		end
	end
	local function ring(radius: number, color: Color3, thick: number, name: string?)
		local share = radius * 2 / (rim * 2.2)
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(share, share)
		circle.BackgroundTransparency = 1
		circle.Parent = map
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim2.fromScale(0.5, 0).X -- (a UDim: half the size, a circle)
		round.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thick
		stroke.Parent = circle
		if name then
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.new(0.5, 0, 0, -2)
			label.Size = UDim2.fromOffset(120, 18)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 15
			label.TextColor3 = color
			label.Text = name
			label.Parent = circle
		end
	end
	ring(rim, Color3.fromRGB(150, 150, 160), 3)
	if frontier and frontier.Bands then
		ring(edge, frontier.Bands.Edge.Color:Lerp(Color3.new(0.5, 0.5, 0.5), 0.35), 2, "EDGE")
		ring(core, frontier.Bands.Fringe.Color:Lerp(Color3.new(0.5, 0.5, 0.5), 0.35), 2, "FRINGE")
	end
	local shelterMark = Instance.new("Frame")
	shelterMark.AnchorPoint = Vector2.new(0.5, 0.5)
	shelterMark.Position = UDim2.fromScale(0.5, 0.5)
	shelterMark.Size = UDim2.fromOffset(18, 13)
	shelterMark.BorderSizePixel = 0
	shelterMark.BackgroundColor3 = Color3.fromRGB(232, 228, 216)
	shelterMark.Parent = map
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.fromOffset(260, 24)
	title.Font = Enum.Font.Oswald
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(200, 210, 220)
	title.Text = "QUARRY SURVEY"
	title.Parent = map
	-- Four benches facing the table, between the ways in.
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local spot = (at * CFrame.new(math.cos(a) * 11.5, 0, math.sin(a) * 11.5)).Position
		local face = facingPoint(spot, at.Position)
		solid(part(m, face * CFrame.new(0, 0.65, 0), Vector3.new(4.4, 1.3, 1.4), HULL_DARK, Enum.Material.Metal))
		local seat = Instance.new("Seat")
		seat.Name = "BriefingBench"
		seat.Anchored = true
		seat.Size = Vector3.new(5, 0.5, 1.9)
		seat.CFrame = face * CFrame.new(0, 1.55, 0)
		seat.Color = Color3.fromRGB(84, 88, 98)
		seat.Material = Enum.Material.Metal
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Parent = m
		part(m, face * CFrame.new(0, 2.7, 1.05), Vector3.new(5, 1.9, 0.35), Color3.fromRGB(84, 88, 98), Enum.Material.Metal)
	end
	-- Its name, on a post by the way in from the hall.
	part(m, at * CFrame.new(9.4, 1.6, 0), Vector3.new(0.5, 3.2, 0.5), STEEL, Enum.Material.Metal)
	local spot = (at * CFrame.new(9.4, 3.9, 0)).Position
	signPanel(m, facingPoint(spot, spot + at:VectorToWorldSpace(Vector3.new(1, 0, 0))), Vector3.new(7, 1.6, 0.3),
		"QUARRY SURVEY", "BANDS AND RANGES", Color3.fromRGB(200, 214, 228))
	return m
end

-- The Gem Gallery: five glass cases on plinths in an arc round `at` (on the
-- floor, in front of the arc), one for each rarity, Common to Legendary,
-- each lit in its colour. The client sets a gem spinning in each case and
-- writes its odds on the plinth (Client.ShelterLife).
local GALLERY_COLORS = {
	Color3.fromRGB(200, 200, 200),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 90, 220),
	Color3.fromRGB(255, 176, 60),
}
local function gemGallery(parent, at: CFrame)
	local m = folder(parent, "GemGallery")
	for i, color in GALLERY_COLORS do
		local a = math.rad(-50 + (i - 1) * 25)
		local spot = (at * CFrame.new(math.cos(a) * 13, 0, math.sin(a) * 13)).Position
		local face = facingPoint(spot, at.Position)
		local plinth = solid(part(m, face * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(3.4, 3, 3),
			HULL_DARK, Enum.Material.Metal, "Cylinder"))
		plinth.Name = "GalleryPlinth" .. i
		-- (a steel collar, its rarity's colour a thin painted band in it)
		part(m, face * CFrame.new(0, 3.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 3.3, 3.3), STEEL,
			Enum.Material.Metal, "Cylinder")
		part(m, face * CFrame.new(0, 3.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.1, 3.34, 3.34), color,
			Enum.Material.SmoothPlastic, "Cylinder")
		solid(part(m, face * CFrame.new(0, 5.36, 0), Vector3.new(2.6, 3.6, 2.6), Color3.fromRGB(200, 214, 228), Enum.Material.Glass,
			nil, { Transparency = 0.78, CastShadow = false }))
		local cap = part(m, face * CFrame.new(0, 7.31, 0), Vector3.new(2.9, 0.3, 2.9), HULL_DARK, Enum.Material.Metal)
		-- (lit from the cap like a museum case: white light, the gem gives the colour)
		light(cap, Color3.fromRGB(255, 244, 228), 9, 1.4, true)
	end
	return m
end

-- The Shelter: the outpost's base in the middle of the basin, built like a
-- barracks: a block of dark armour plate with rusted inserts and red running
-- lights, a raised deck over the garage with two exhaust stacks glowing red,
-- and the whole of it up on eight landing legs, its floor `lift` over the
-- quarry's (Shared.Outpost.ShelterLift: a keel under the middle of it, set
-- well back, so the legs stand clear and nobody gets under the hall). Big enough to hold the lobby (168 by 120 studs, the walls
-- 34 high, a skylight over the hall). Players arrive inside; a wide ramp
-- runs down from the main door to the quarry, and one from each garage
-- door, gentle enough for the mechs to climb (ShelterRamp long).
--   North: the mech garage, eight bays in a row facing a lane that runs out
--   of a big door at each end (east and west), behind a barrier with gaps.
--   The hall: the kaiju arena in the middle (a steel stage and stands),
--   the Store and the player Market as shopfronts in the west wall, the
--   survey table between them and the arena, the Gem Gallery, PROBE-7 and
--   the leaderboard on the east, the Arena Uplink by the door, INFO-9's
--   kiosk by the arena, and the field guide on the wall beside the door.
--   One wide door south, to the quarry.
-- Inside it's a working base, not a showroom: matte concrete underfoot,
-- plate walls with a rusted band, warm work lights, and one sign system
-- (signPanel): station colours are markings, never neon. The season stays
-- outside (pumpkins at the landing). `at` is its floor's frame (the
-- quarry's, lifted).
-- Returns its places, in `at`'s frame:
-- { Parking, Spawn, Probe, Board, Gate (CFrames for those builders), Store,
--   Market (the counters, for their prompts), Crew ({ Id, CFrame }: where
--   its crew stand), Box (half sizes, x and z), Ramps ({ { Middle, Half,
--   SlopeHalf } }: each ramp and its landing, on the quarry floor, Half
--   their half sizes, x and z, SlopeHalf the slope's half width), Feet
--   ({ Vector3 }: where its legs stand) }
local SHELTER = {
	HalfWidth = 84, -- x, inside
	HalfDepth = 60, -- z, inside
	Height = 34,
	Door = 14, -- the main door's half width (south)
	DoorHeight = 22,
	Lane = { -36, -16 }, -- the garage lane's z, and its doors
	LaneDoorHeight = 26,
	Barrier = -14, -- z of the barrier between the garage and the hall
	Landing = 10, -- how far each door's landing stands out from the wall
	FrontRamp = { Landing = 27, Ramp = 19 }, -- the main door's (half widths)
	LaneRamp = 12, -- each garage door's (half width: the lane and a little)
	Keel = 12, -- how far in from the walls the keel under it is set
	-- The well in the hall's floor for the stairs down to the Kaiju Arena
	-- (Shared.KaijuPit), on the west side between the Market and the stage:
	-- its edges (x, z), and the landing at the foot of its steps (x long).
	Well = { MinX = -52, MaxX = -26, MinZ = 30, MaxZ = 40, Landing = 7 },
}
local ARMOR = Color3.fromRGB(96, 100, 110) -- the Shelter's plate: dark gunmetal
local RUST = Color3.fromRGB(128, 76, 50) -- its armour inserts, weathered brown
local RED = Color3.fromRGB(255, 62, 50) -- its running lights
-- Each station's colour: the bar on its signs, its crew's visor and belt
-- (Shared.Vendors has the same). Markings, never lights.
local STATION = {
	Store = Color3.fromRGB(122, 150, 214),
	Market = Color3.fromRGB(96, 186, 156),
	Gems = Color3.fromRGB(226, 190, 112),
	Arena = Color3.fromRGB(214, 84, 70),
	Info = Color3.fromRGB(200, 214, 228),
	Quarry = HAZARD,
	Exit = Color3.fromRGB(76, 190, 110),
}
local function shelter(parent, at: CFrame, rules)
	local m = folder(parent, "Shelter")
	local lift = rules.ShelterLift
	local W, D, H = SHELTER.HalfWidth, SHELTER.HalfDepth, SHELTER.Height
	local laneN, laneS = SHELTER.Lane[1], SHELTER.Lane[2]
	local laneMid = (laneN + laneS) / 2
	local walls = ARMOR
	local function at3(x, y, z)
		return at * CFrame.new(x, y, z)
	end
	local function facing(x, y, z, dx, dz)
		local p = at3(x, y, z).Position
		return CFrame.lookAt(p, p + (at:VectorToWorldSpace(Vector3.new(dx, 0, dz))))
	end
	-- A box from `a` to `b` (points in `at`'s frame), `w` by `h` across.
	local function beam(a: Vector3, b: Vector3, w: number, h: number, color)
		local axis = (b - a).Unit
		local side = axis:Cross(Vector3.new(0, 1, 0))
		side = if side.Magnitude > 1e-3 then side.Unit else Vector3.new(1, 0, 0)
		return part(m, at * CFrame.fromMatrix((a + b) / 2, side, axis:Cross(side), axis), Vector3.new(w, h, (b - a).Magnitude),
			color, Enum.Material.Metal)
	end

	-- A box from (x0, y0, z0) to (x1, y1, z1), with the stairs' well cut out
	-- of it where it crosses (up to four boxes round the hole).
	local well = SHELTER.Well
	local function holed(x0, x1, y0, y1, z0, z1, color, material, isSolid: boolean?)
		local function box(a0, a1, b0, b1)
			if a1 - a0 > 0.01 and b1 - b0 > 0.01 then
				local p = part(m, at3((a0 + a1) / 2, (y0 + y1) / 2, (b0 + b1) / 2), Vector3.new(a1 - a0, y1 - y0, b1 - b0), color, material)
				if isSolid then
					solid(p)
				end
			end
		end
		local wx0, wx1 = math.max(x0, well.MinX), math.min(x1, well.MaxX)
		local wz0, wz1 = math.max(z0, well.MinZ), math.min(z1, well.MaxZ)
		if wx0 >= wx1 or wz0 >= wz1 then
			box(x0, x1, z0, z1)
			return
		end
		box(x0, x1, z0, wz0)
		box(x0, x1, wz1, z1)
		box(x0, wx0, wz0, wz1)
		box(wx1, x1, wz0, wz1)
	end

	-- The floor: one slab under it all, matte concrete (the hall's a shade
	-- paler), the garage lane dark.
	holed(-(W + 2), W + 2, 0, 0.8, -(D + 2), D + 2, CONCRETE, Enum.Material.Concrete, true)
	holed(-W, W, 0.8, 0.86, SHELTER.Barrier, D, Color3.fromRGB(104, 106, 112), Enum.Material.Concrete)
	-- Where you arrive: a compass rose painted on the floor.
	local paint = Color3.fromRGB(196, 150, 78)
	local rose = at3(0, 0.86, D - 10)
	disc(m, rose, 6.4, 0.06, paint)
	disc(m, rose * CFrame.new(0, 0.01, 0), 6, 0.06, Color3.fromRGB(104, 106, 112), Enum.Material.Concrete)
	for k = 0, 3 do
		part(m, rose * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(k * 45), 0),
			Vector3.new(if k % 2 == 0 then 11.4 else 7.4, 0.06, 0.36), paint)
	end
	disc(m, rose * CFrame.new(0, 0.05, 0), 1.1, 0.06, paint)
	part(m, at3(0, 0.83, laneMid), Vector3.new(W * 2 + 4, 0.06, laneS - laneN),
		Color3.fromRGB(36, 38, 44), Enum.Material.Slate)
	for x = -72, 72, 24 do
		part(m, at3(x, 0.88, laneMid), Vector3.new(4, 0.06, 0.5), HAZARD, Enum.Material.SmoothPlastic)
	end

	-- Under the floor, the keel: a block set well in from the walls, down to
	-- the quarry floor, so the space under the edges is open (the legs
	-- stand clear in it) and nobody walks in under the hall.
	local keel = SHELTER.Keel
	holed(-(W + 2 - keel), W + 2 - keel, -lift, 0, -(D + 2 - keel), D + 2 - keel, HULL_DARK, Enum.Material.Metal, true)

	-- The stairs down to the Kaiju Arena, in the well: steps from the hall's
	-- floor at its east end down to a landing at its west end, before a
	-- lit doorway. Walk onto the landing and you're downstairs
	-- (Server.KaijuPitServer). A rail round its other three sides, and its
	-- sign over the far end, facing the way in.
	local stairs = {}
	do
		local top, bottom = 0.86, -lift + 0.4
		local midZ, wide = (well.MinZ + well.MaxZ) / 2, well.MaxZ - well.MinZ
		local count = 13
		local rise, tread = (top - bottom) / count, (well.MaxX - well.MinX - well.Landing) / count
		solid(part(m, at3((well.MinX + well.MaxX) / 2, bottom - 0.2, midZ), Vector3.new(well.MaxX - well.MinX, 0.4, wide),
			CONCRETE, Enum.Material.Concrete))
		for i = 1, count do
			local x = well.MaxX - (i - 0.5) * tread
			local h = top - i * rise
			solid(part(m, at3(x, (bottom + h) / 2, midZ), Vector3.new(tread, math.max(h - bottom, 0.05), wide), CONCRETE,
				Enum.Material.Concrete))
			part(m, at3(x + tread / 2 - 0.15, h + 0.01, midZ), Vector3.new(0.3, 0.04, wide), HAZARD, Enum.Material.SmoothPlastic)
		end
		-- (hazard paint round the well's lip)
		for _, edge in { { (well.MinX + well.MaxX) / 2, well.MinZ + 0.1, well.MaxX - well.MinX, 0.2 },
			{ (well.MinX + well.MaxX) / 2, well.MaxZ - 0.1, well.MaxX - well.MinX, 0.2 },
			{ well.MinX + 0.1, midZ, 0.2, wide } } do
			part(m, at3(edge[1], 0.5, edge[2]), Vector3.new(edge[3], 0.6, edge[4]), HAZARD, Enum.Material.SmoothPlastic)
		end
		-- The doorway at the foot, glowing the arena's red.
		local door = part(m, at3(well.MinX + 0.15, bottom + 3.4, midZ), Vector3.new(0.2, 6.4, 6), STATION.Arena, Enum.Material.Neon)
		door.Name = "ArenaDoor"
		light(door, STATION.Arena, 16, 1.2)
		for _, dz in { -3.6, 3.6 } do
			part(m, at3(well.MinX + 0.4, bottom + 3.5, midZ + dz), Vector3.new(0.8, 7, 1.2), HAZARD, Enum.Material.Metal)
		end
		-- The rail: north, south and west, posts and two bars.
		for _, run in {
			{ well.MinX - 0.3, well.MaxX, well.MinZ - 0.3, well.MinZ - 0.3 },
			{ well.MinX - 0.3, well.MaxX, well.MaxZ + 0.3, well.MaxZ + 0.3 },
			{ well.MinX - 0.3, well.MinX - 0.3, well.MinZ - 0.3, well.MaxZ + 0.3 },
		} do
			local a, b = Vector3.new(run[1], 0, run[3]), Vector3.new(run[2], 0, run[4])
			local length = (b - a).Magnitude
			local along = (b - a).Unit
			for k = 0, math.floor(length / 3.25) do
				local q = a + along * math.min(k * 3.25, length)
				solid(part(m, at3(q.X, 2.1, q.Z), Vector3.new(0.3, 2.5, 0.3), STEEL, Enum.Material.Metal))
			end
			local mid = (a + b) / 2
			local size = Vector3.new(math.abs(b.X - a.X) + 0.3, 0.2, math.abs(b.Z - a.Z) + 0.3)
			solid(part(m, at3(mid.X, 3.4, mid.Z), size, HAZARD, Enum.Material.Metal))
			part(m, at3(mid.X, 2.2, mid.Z), size, STEEL, Enum.Material.Metal)
		end
		for _, dz in { -4.6, 4.6 } do
			part(m, at3(well.MinX - 1.6, 3.6, midZ + dz), Vector3.new(0.5, 7.2, 0.5), HULL_DARK, Enum.Material.Metal)
		end
		signPanel(m, facing(well.MinX - 1.6, 6.4, midZ, 1, 0), Vector3.new(11, 3.2, 0.4), "KAIJU ARENA",
			"DOWNSTAIRS: KAIJU BATTLES", STATION.Arena)
		signPanel(m, facing((well.MinX + well.MaxX) / 2, 4.6, well.MaxZ + 0.5, 0, 1), Vector3.new(8, 1.8, 0.3), "KAIJU ARENA",
			"STAIRS DOWN", STATION.Arena)
		-- Its landing (walk onto it and you're downstairs), and where you come
		-- back up: at the top of the steps, facing the hall.
		stairs.Landing = at3(well.MinX + well.Landing / 2, bottom + 3, midZ)
		stairs.Size = Vector3.new(well.Landing, 6, wide)
		stairs.Top = facing(well.MaxX + 5, 3.5, midZ, 1, 0)
	end

	-- The walls, round the doors: each length, its centre, and whether it's
	-- a lintel over a door (no plinth on those).
	local lengths = {}
	local function wall(x, z, sx, sz, y0, y1, lintel)
		solid(part(m, at3(x, (y0 + y1) / 2, z), Vector3.new(sx, y1 - y0, sz), walls, Enum.Material.Metal))
		table.insert(lengths, { X = x, Z = z, SX = sx, SZ = sz, Lintel = lintel })
	end
	wall(0, -D - 1, W * 2 + 4, 2, 0, H)
	local side = W + 2 - SHELTER.Door
	wall(-(SHELTER.Door + side / 2), D + 1, side, 2, 0, H)
	wall(SHELTER.Door + side / 2, D + 1, side, 2, 0, H)
	wall(0, D + 1, SHELTER.Door * 2, 2, SHELTER.DoorHeight, H, true)
	for _, s in { -1, 1 } do
		local x = s * (W + 1)
		wall(x, (-D - 2 + laneN) / 2, 2, laneN + D + 2, 0, H)
		wall(x, (laneS + D + 2) / 2, 2, D + 2 - laneS, 0, H)
		wall(x, laneMid, 2, laneS - laneN, SHELTER.LaneDoorHeight, H, true)
	end
	-- Bands along every length, proud of both faces: a dark plinth, and up
	-- under the roof a band of rusted plate.
	for _, l in lengths do
		local thick = Vector3.new(if l.SX > 2 then l.SX else 2.5, 0, if l.SZ > 2 then l.SZ else 2.5)
		if not l.Lintel then
			part(m, at3(l.X, 1.6, l.Z), thick + Vector3.new(0, 3.2, 0), HULL_DARK, Enum.Material.Metal)
		end
		part(m, at3(l.X, 29, l.Z), thick + Vector3.new(0, 4, 0) - Vector3.new(if l.SX > 2 then 1 else 0, 0, if l.SZ > 2 then 1 else 0),
			RUST, Enum.Material.CorrodedMetal)
	end
	-- Outside: a red running light under the band (the front's broken round
	-- the name), and rusted plates set into the front either side of the door.
	for _, s in { -1, 1 } do
		part(m, at3(s * 55, 26.4, D + 2.2), Vector3.new(62, 0.4, 0.3), RED, Enum.Material.Neon)
		part(m, at3(s * (W + 2.2), 26.4, 0), Vector3.new(0.3, 0.4, D * 2 + 4), RED, Enum.Material.Neon)
		for _, x in { 43, 69 } do
			part(m, at3(s * x, 13, D + 2.3), Vector3.new(22, 16, 0.6), RUST, Enum.Material.CorrodedMetal)
		end
	end
	-- Heavy ribs up the outside; armoured towers at the corners, a red
	-- beacon on each; and deeper ribs over the other legs (two at the front,
	-- one each side), down to them. The legs come out of the towers and
	-- those ribs.
	for _, x in { -56, -30, 30, 56 } do
		local leg = math.abs(x) == 56
		part(m, at3(x, if leg then (H - 3) / 2 else (H + 1) / 2, D + 2.8), Vector3.new(if leg then 5 else 4, if leg then H + 5 else H + 1, 3.6),
			HULL_DARK, Enum.Material.Metal)
	end
	for _, x in { -52, -26, 0, 26, 52 } do
		part(m, at3(x, (H + 1) / 2, -D - 2.8), Vector3.new(4, H + 1, 3.6), HULL_DARK, Enum.Material.Metal)
	end
	for _, s in { -1, 1 } do
		for _, z in { -54, -6 } do
			part(m, at3(s * (W + 2.8), (H + 1) / 2, z), Vector3.new(3.6, H + 1, 4), HULL_DARK, Enum.Material.Metal)
		end
		part(m, at3(s * (W + 3), (H - 3) / 2, 24), Vector3.new(4, H + 5, 6), HULL_DARK, Enum.Material.Metal)
		for _, z in { -1, 1 } do
			local tower = at3(s * (W + 2), H / 2, z * (D + 2))
			solid(part(m, tower, Vector3.new(7, H + 8, 7), HULL_DARK, Enum.Material.Metal))
			local beacon = part(m, tower * CFrame.new(0, (H + 8) / 2 + 0.5, 0), Vector3.new(1.4, 1, 1.4), RED, Enum.Material.Neon)
			if z > 0 then
				light(beacon, RED, 18, 0.8)
			end
		end
	end

	-- The legs: one out of each corner tower, one out of each side's middle
	-- rib and two out of the front's, each a heavy thigh angled down and
	-- out from high on the wall to its knee, a yellow piston to the knee
	-- from under the floor's edge, and a shin down to a broad pad on the
	-- quarry floor.
	local feet = {}
	local legs = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(legs, { Vector3.new(sx * (W + 2), 0, sz * (D + 2)), Vector3.new(sx, 0, sz).Unit })
		end
		table.insert(legs, { Vector3.new(sx * (W + 2), 0, 24), Vector3.new(sx, 0, 0) })
		table.insert(legs, { Vector3.new(sx * 56, 0, D + 2), Vector3.new(0, 0, 1) })
	end
	for _, leg in legs do
		local base, out = leg[1], leg[2]
		local hip = base + out * 1.5 + Vector3.new(0, 9, 0)
		local knee = base + out * 11 + Vector3.new(0, 6 - lift, 0)
		local foot = base + out * 13 + Vector3.new(0, 1.2 - lift, 0)
		solid(beam(hip, knee, 4.4, 3.4, ARMOR))
		solid(beam(knee, foot, 3.4, 3.4, HULL_DARK))
		part(m, at * CFrame.new(knee), Vector3.one * 4.4, STEEL, Enum.Material.Metal, "Ball")
		strut(m, (at * CFrame.new(base + Vector3.new(0, -0.6, 0))).Position, (at * CFrame.new(knee)).Position, 0.7, HAZARD)
		solid(disc(m, at3(foot.X, 0.6 - lift, foot.Z), 4.4, 1.2, HULL_DARK, Enum.Material.DiamondPlate))
		table.insert(feet, at3(foot.X, -lift, foot.Z).Position)
	end

	-- The roof, round a raised skylight over the hall (its glass dulled,
	-- tinted, so the hall's not a greenhouse); behind it, over the garage,
	-- the upper deck, the barracks' second storey, with its two exhaust
	-- stacks glowing red.
	local roofY = H + 0.6
	local sky = { X = 34, Z0 = -2, Z1 = 40 }
	local function roof(x, z, sx, sz)
		solid(part(m, at3(x, roofY, z), Vector3.new(sx, 1.2, sz), HULL_DARK, Enum.Material.DiamondPlate))
	end
	roof(0, (-D - 2 + sky.Z0) / 2, W * 2 + 4, sky.Z0 + D + 2)
	roof(0, (sky.Z1 + D + 2) / 2, W * 2 + 4, D + 2 - sky.Z1)
	for _, s in { -1, 1 } do
		roof(s * (sky.X + (W + 2 - sky.X) / 2), (sky.Z0 + sky.Z1) / 2, W + 2 - sky.X, sky.Z1 - sky.Z0)
	end
	local glass = Color3.fromRGB(70, 84, 100)
	local skyMid = (sky.Z0 + sky.Z1) / 2
	for _, z in { sky.Z0, sky.Z1 } do
		part(m, at3(0, roofY + 4.4, z), Vector3.new(sky.X * 2, 8, 0.4), glass, Enum.Material.Glass, nil, { Transparency = 0.4 })
	end
	for _, s in { -1, 1 } do
		part(m, at3(s * sky.X, roofY + 4.4, skyMid), Vector3.new(0.4, 8, sky.Z1 - sky.Z0), glass, Enum.Material.Glass, nil, { Transparency = 0.4 })
	end
	part(m, at3(0, roofY + 8.6, skyMid), Vector3.new(sky.X * 2 + 1, 0.4, sky.Z1 - sky.Z0 + 1), glass, Enum.Material.Glass, nil, { Transparency = 0.5 })
	part(m, at3(0, roofY + 8.3, skyMid), Vector3.new(sky.X * 2, 0.8, 1), HULL_DARK, Enum.Material.Metal)
	local deckTop = roofY + 9.6
	solid(part(m, at3(0, roofY + 5.1, -40), Vector3.new(136, 9, 36), ARMOR, Enum.Material.Metal))
	part(m, at3(0, roofY + 6, -21.7), Vector3.new(130, 2.6, 0.6), RUST, Enum.Material.CorrodedMetal)
	part(m, at3(0, roofY + 2.2, -21.8), Vector3.new(128, 0.4, 0.4), RED, Enum.Material.Neon)
	for _, s in { -1, 1 } do
		local stack = at3(s * 40, deckTop + 5, -48)
		part(m, stack, Vector3.new(9, 10, 8), HULL_DARK, Enum.Material.Metal)
		part(m, stack * CFrame.new(0, 5.6, 0), Vector3.new(10, 1.2, 9), ARMOR, Enum.Material.Metal)
		local glow = part(m, stack * CFrame.new(0, 6.3, 0), Vector3.new(7, 0.3, 6), RED, Enum.Material.Neon)
		light(glow, RED, 22, 1)
		part(m, stack * CFrame.new(0, 2.2, 4.05), Vector3.new(6.4, 1.2, 0.2), RED, Enum.Material.Neon)
	end
	-- Lights: work lights over the garage, amber lamps along the hall's
	-- sides, two hung over the arena from the skylight, and warm panels down
	-- each side of the skylight, so the hall is evenly lit without glare.
	for _, x in { -48, 0, 48 } do
		local lamp = part(m, at3(x, roofY - 0.9, (laneN + SHELTER.Barrier) / 2 - 8), Vector3.new(10, 0.4, 3), AMBER, Enum.Material.Neon)
		light(lamp, Color3.fromRGB(255, 232, 200), 52, 1.2)
	end
	for _, s in { -1, 1 } do
		for _, z in { 8, 44 } do
			local lamp = part(m, at3(s * 62, roofY - 0.9, z), Vector3.new(3, 0.4, 10), AMBER, Enum.Material.Neon)
			light(lamp, Color3.fromRGB(255, 226, 190), 46, 1)
		end
		-- (an industrial pendant: a dark shade, the lamp's face under it)
		local shade = part(m, at3(s * 14, 28.4, 18), Vector3.new(3, 1.4, 3), HULL_DARK, Enum.Material.Metal)
		local hung = part(m, at3(s * 14, 27.64, 18), Vector3.new(2.2, 0.14, 2.2), AMBER, Enum.Material.Neon)
		tube(m, shade.CFrame.Position, at3(s * 14, roofY + 8.2, 18).Position, 0.08, HULL_DARK)
		light(hung, Color3.fromRGB(255, 214, 170), 40, 1.3)
		for _, z in { -4, 20, 44 } do
			local panel = part(m, at3(s * 46, roofY - 0.75, z), Vector3.new(10, 0.3, 3), Color3.fromRGB(255, 236, 206), Enum.Material.Neon)
			light(panel, Color3.fromRGB(255, 238, 214), 42, 0.9)
		end
	end

	-- The main door: hazard posts inside, and outside an armoured gatehouse
	-- standing out over the landing (two piers and a lintel, lit red down
	-- the piers' inner edges and under the lintel, a sloped brow on top),
	-- the name over it, and inside, over the door, the way to the quarry.
	local gate = { Out = 8, Pier = 9.4, Top = SHELTER.DoorHeight + 4 }
	for _, s in { -1, 1 } do
		part(m, at3(s * (SHELTER.Door + 1.2), SHELTER.DoorHeight / 2, D + 1), Vector3.new(2.4, SHELTER.DoorHeight, 2.8), HAZARD, Enum.Material.Metal)
		solid(part(m, at3(s * (SHELTER.Door + gate.Pier / 2), gate.Top / 2, D + 2 + gate.Out / 2), Vector3.new(gate.Pier, gate.Top, gate.Out),
			HULL_DARK, Enum.Material.Metal))
		part(m, at3(s * (SHELTER.Door + 0.4), SHELTER.DoorHeight / 2 + 1, D + 2 + gate.Out + 0.06), Vector3.new(0.3, SHELTER.DoorHeight - 6, 0.12),
			RED, Enum.Material.Neon)
	end
	part(m, at3(0, (SHELTER.DoorHeight + gate.Top) / 2, D + 2 + gate.Out / 2), Vector3.new(SHELTER.Door * 2, gate.Top - SHELTER.DoorHeight, gate.Out),
		ARMOR, Enum.Material.Metal)
	part(m, at3(0, gate.Top + 1.3, D + 3 + gate.Out / 2) * CFrame.Angles(0, math.pi, 0), Vector3.new((SHELTER.Door + gate.Pier) * 2 + 1, 2.6, gate.Out + 2),
		HULL_DARK, Enum.Material.Metal, "Wedge")
	part(m, at3(0, SHELTER.DoorHeight + 0.2, D + 2 + gate.Out + 0.1), Vector3.new(SHELTER.Door * 2, 0.4, 0.4), RED, Enum.Material.Neon)
	local name = signPanel(m, facing(0, 31.3, D + 2.5, 0, 1), Vector3.new(48, 5.4, 0.4), "SAGA SHELTER",
		"FORWARD OPERATING BASE 07", SAGA)
	light(name, Color3.fromRGB(255, 232, 200), 24, 0.8)
	local core = if OutpostWorld.Frontier then OutpostWorld.Frontier.Core else 150
	signPanel(m, facing(0, 25, D - 0.2, 0, -1), Vector3.new(26, 3.2, 0.4), "QUARRY ACCESS",
		string.format("RIFT ACTIVITY BEYOND %d STUDS", core), STATION.Quarry)

	-- The ramps: a wide one from the main door down to the quarry, and one
	-- from each garage door for the mechs (lift over ShelterRamp studs: a
	-- mech climbs it). Each runs out from a landing at the floor's height, the
	-- top of its slope edged in hazard paint, hazard stripes down its sides;
	-- red beacons mark the foot of the main one.
	local ramps = {}
	local function ramp(edge: Vector3, out: Vector3, landingHalf: number, rampHalf: number, beacons: boolean)
		local up = Vector3.new(0, 1, 0)
		local f = at * CFrame.fromMatrix(edge, out:Cross(up), up, -out)
		local tall, landing, run = lift + 0.8, SHELTER.Landing, rules.ShelterRamp
		solid(part(m, f * CFrame.new(0, 0.8 - tall / 2, -landing / 2), Vector3.new(landingHalf * 2, tall, landing), CONCRETE, Enum.Material.Concrete))
		local slope = f * CFrame.new(0, 0.8 - tall / 2, -landing - run / 2)
		solid(part(m, slope, Vector3.new(rampHalf * 2, tall, run), CONCRETE, Enum.Material.Concrete, "Wedge"))
		part(m, f * CFrame.new(0, 0.83, -landing + 0.4), Vector3.new(rampHalf * 2, 0.06, 0.8), HAZARD, Enum.Material.SmoothPlastic)
		for _, s in { -1, 1 } do
			part(m, slope * CFrame.new(s * (rampHalf - 0.6), 0.08, 0) * CFrame.Angles(-math.atan2(tall, run), 0, 0),
				Vector3.new(0.9, 0.2, math.sqrt(tall * tall + run * run)), HAZARD, Enum.Material.SmoothPlastic)
			if beacons then
				local beacon = part(m, f * CFrame.new(s * (rampHalf + 1.2), 0.8 - lift, -landing - run + 1), Vector3.new(1, 1.6, 1), RED, Enum.Material.Neon)
				light(beacon, RED, 12, 0.7)
			end
		end
		local length, wide = landing + run, math.max(landingHalf, rampHalf)
		local middle = edge + out * (length / 2)
		table.insert(ramps, {
			Middle = at3(middle.X, -lift, middle.Z).Position,
			Half = if math.abs(out.X) > 0.5 then Vector2.new(length / 2, wide) else Vector2.new(wide, length / 2),
			SlopeHalf = rampHalf,
		})
	end
	ramp(Vector3.new(0, 0, D + 2), Vector3.new(0, 0, 1), SHELTER.FrontRamp.Landing, SHELTER.FrontRamp.Ramp, true)
	for _, s in { -1, 1 } do
		ramp(Vector3.new(s * (W + 2), 0, laneMid), Vector3.new(s, 0, 0), SHELTER.LaneRamp, SHELTER.LaneRamp, false)
	end

	-- The garage: eight bays along the north wall, facing the lane, a Mole
	-- drill in every one (the base's standard mech).
	local bays = table.create(8, "Mole")
	local names = { Mole = "MOLE DRILL" }
	local bayZ = -48
	local parking = {}
	for k = 0, #bays do
		part(m, at3(-76 + k * 19, 0.88, bayZ - 1), Vector3.new(0.5, 0.06, 20), HAZARD, Enum.Material.SmoothPlastic)
	end
	for i, kind in bays do
		local x = -66.5 + (i - 1) * 19
		signPanel(m, facing(x, 21, -D + 0.4, 0, 1), Vector3.new(15, 5, 0.4), string.format("BAY %02d", i), names[kind], HAZARD)
		local spot = at3(x, 1, bayZ).Position
		table.insert(parking, { Kind = kind, CFrame = CFrame.lookAt(spot, spot - at.LookVector) })
	end
	signPanel(m, facing(0, 30, -D + 0.4, 0, 1), Vector3.new(56, 5.5, 0.4), "MECH GARAGE",
		"BAYS 01 TO 08, EXIT BY EITHER GARAGE DOOR", HAZARD)
	-- Each garage door: hazard posts, the rolled-up door, EXIT over it.
	for _, s in { -1, 1 } do
		for _, z in { laneN - 1, laneS + 1 } do
			part(m, at3(s * (W - 0.7), SHELTER.LaneDoorHeight / 2, z), Vector3.new(1.4, SHELTER.LaneDoorHeight, 1.4), HAZARD, Enum.Material.Metal)
		end
		part(m, at3(s * (W + 1), SHELTER.LaneDoorHeight + 1.4, laneMid) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(laneS - laneN, 2.6, 2.6), HULL_DARK, Enum.Material.Metal, "Cylinder")
		signPanel(m, facing(s * (W - 0.4), SHELTER.LaneDoorHeight + 3.4, laneMid, -s, 0),
			Vector3.new(10, 2.6, 0.4), "EXIT", nil, STATION.Exit)
		for _, z in { -57, -53.5 } do
			part(m, at3(s * 80.5, 2.1, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2.6, 2.4, 2.4),
				Color3.fromRGB(200, 60, 50), Enum.Material.Metal, "Cylinder")
		end
	end
	-- The barrier between the garage and the hall, with gaps to walk through.
	for _, span in { { -W, -56 }, { -44, -8 }, { 8, 44 }, { 56, W } } do
		local x, len = (span[1] + span[2]) / 2, span[2] - span[1]
		solid(part(m, at3(x, 2.3, SHELTER.Barrier), Vector3.new(len, 3, 1.6), CONCRETE, Enum.Material.Concrete))
		part(m, at3(x, 3.9, SHELTER.Barrier), Vector3.new(len, 0.4, 1.7), HAZARD, Enum.Material.SmoothPlastic)
	end

	-- The kaiju arena: a steel stage with a hazard line round its edge and the
	-- holo projector's lens in the middle, two tiers of stands open to the
	-- door and the garage (plain plate, no trim), floodlight pylons, and its
	-- sign over the way in.
	local arena = at3(0, 0.8, 18)
	solid(disc(m, arena * CFrame.new(0, 0.5, 0), 12.6, 1, STEEL, Enum.Material.DiamondPlate))
	solid(disc(m, arena * CFrame.new(0, 0.75, 0), 12, 1.5, Color3.fromRGB(56, 58, 64), Enum.Material.Concrete))
	disc(m, arena * CFrame.new(0, 1.51, 0), 11.2, 0.04, HAZARD)
	disc(m, arena * CFrame.new(0, 1.52, 0), 10.5, 0.05, Color3.fromRGB(56, 58, 64), Enum.Material.Concrete)
	-- (the projector's lens, glowing faintly: the hologram stands on it)
	disc(m, arena * CFrame.new(0, 1.54, 0), 2.2, 0.08, Color3.fromRGB(46, 78, 116), Enum.Material.Neon).Name = "ProjectorLens"
	for tier, spec in { { 16, 1.6 }, { 19.5, 3.2 } } do
		local r, h = spec[1], spec[2]
		for k = 0, 11 do
			local a = (k + 0.5) / 12 * math.pi * 2
			if math.abs(math.cos(a)) >= 0.3 then
				local seat = arena * CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(0, math.pi / 2 - a, 0)
				local length = 2 * math.pi * r / 12 - 0.6
				solid(part(m, seat, Vector3.new(length, h, 3), if tier == 1 then Color3.fromRGB(110, 114, 124) else Color3.fromRGB(82, 86, 96),
					Enum.Material.Metal))
			end
		end
	end
	for k = 0, 3 do
		local a = (k + 0.5) / 4 * math.pi * 2
		local foot = arena * CFrame.new(math.cos(a) * 13.6, 0, math.sin(a) * 13.6)
		part(m, foot * CFrame.new(0, 4.5, 0), Vector3.new(1, 9, 1), HULL_DARK, Enum.Material.Metal)
		-- (a floodlight on top, tipped down at the stage)
		local head = CFrame.lookAt((foot * CFrame.new(0, 9.4, 0)).Position, arena.Position) * CFrame.Angles(math.rad(-10), 0, 0)
		part(m, head, Vector3.new(1.8, 1.2, 1.4), HULL_DARK, Enum.Material.Metal)
		part(m, head * CFrame.new(0, 0, -0.72), Vector3.new(1.4, 0.8, 0.06), AMBER, Enum.Material.Neon)
	end
	-- (Its sign up high, clear of the hologram on the stage.)
	for _, s in { -1, 1 } do
		part(m, arena * CFrame.new(s * 7, 8.5, 19.5), Vector3.new(0.8, 17, 0.8), HULL_DARK, Enum.Material.Metal)
	end
	signPanel(m, facing(0, 18.4, 18 + 19.5, 0, 1), Vector3.new(16, 3.4, 0.4), "KAIJU ARENA",
		"DOWNSTAIRS: TAKE THE WEST STAIRS", STATION.Arena)

	-- The Store and the player Market: two shopfronts in the west wall, built
	-- alike. Each is an alcove, the Shelter's wall at its back and a ceiling
	-- over it, behind a steel portal: two columns and a fascia carrying the
	-- shop's lightbox (dark lettering on a lit face, the station's colour in
	-- a block beside the name), with a blade sign standing out from a column
	-- so it reads from down the hall. Inside, a counter with a steel top
	-- and a till, lit from above by downlights. No neon.
	local function storefront(z: number, brand: string, blade: string, color: Color3)
		local x = -W + 18
		part(m, at3(-W + 9, 15, z), Vector3.new(18, 0.8, 22.4), HULL_DARK, Enum.Material.Metal)
		for _, dz in { -10.5, 10.5 } do
			solid(part(m, at3(x - 0.4, 7.9, z + dz), Vector3.new(1.6, 15.8, 1.6), ARMOR, Enum.Material.Metal))
			part(m, at3(x - 0.4, 1.3, z + dz), Vector3.new(2, 1, 2), HULL_DARK, Enum.Material.Metal)
		end
		part(m, at3(x - 0.4, 17.4, z), Vector3.new(1.6, 4.4, 22.6), ARMOR, Enum.Material.Metal)
		-- The lightbox, on the fascia's face.
		local box = part(m, facing(x + 0.5, 17.4, z, 1, 0), Vector3.new(19, 3.2, 0.2), HULL_DARK, Enum.Material.Metal)
		box.Name = "Lightbox"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(19 * 40, 3.2 * 40)
		gui.LightInfluence = 0
		gui.Brightness = 1.1
		gui.Parent = box
		local lit = Instance.new("Frame")
		lit.Size = UDim2.fromScale(1, 1)
		lit.BorderSizePixel = 0
		lit.BackgroundColor3 = Color3.fromRGB(232, 228, 218)
		lit.Parent = gui
		local mark = Instance.new("Frame")
		mark.Position = UDim2.fromScale(0.03, 0.18)
		mark.Size = UDim2.fromScale(0.05, 0.64)
		mark.SizeConstraint = Enum.SizeConstraint.RelativeYY
		mark.BorderSizePixel = 0
		mark.BackgroundColor3 = color
		mark.Parent = lit
		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Text = "◆"
		glyph.TextScaled = true
		glyph.Font = Enum.Font.GothamBold
		glyph.TextColor3 = Color3.fromRGB(240, 238, 232)
		glyph.Parent = mark
		local word = Instance.new("TextLabel")
		word.BackgroundTransparency = 1
		word.Position = UDim2.fromScale(0.13, 0.12)
		word.Size = UDim2.fromScale(0.84, 0.76)
		word.Text = brand
		word.TextScaled = true
		word.TextXAlignment = Enum.TextXAlignment.Left
		word.Font = Enum.Font.Oswald
		word.TextColor3 = Color3.fromRGB(30, 32, 38)
		word.Parent = lit
		-- The blade sign, out from the north column at head height and over.
		local bladeAt = at3(x + 3.1, 12.6, z - 10.5)
		part(m, bladeAt * CFrame.new(-2.6, 1.15, 0), Vector3.new(3.6, 0.2, 0.2), STEEL, Enum.Material.Metal)
		signPanel(m, CFrame.lookAt(bladeAt.Position, bladeAt.Position + at:VectorToWorldSpace(Vector3.new(0, 0, 1))),
			Vector3.new(5.6, 2, 0.24), blade, nil, color, true)
		-- The counter, its steel top and a till on it.
		local counter = solid(part(m, at3(x, 2.6, z), Vector3.new(3.2, 3.6, 16), HULL_DARK, Enum.Material.Metal))
		counter.Name = blade .. "Counter"
		part(m, at3(x + 0.1, 4.55, z), Vector3.new(3.8, 0.3, 16.4), STEEL, Enum.Material.Metal)
		local till = part(m, at3(x, 5.3, z - 5) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(-20), 0, 0),
			Vector3.new(1.8, 1.1, 0.14), HULL_DARK, Enum.Material.Metal)
		local screen = Instance.new("SurfaceGui")
		screen.Face = Enum.NormalId.Back
		screen.CanvasSize = Vector2.new(72, 44)
		screen.LightInfluence = 0
		screen.Parent = till
		local glow = Instance.new("Frame")
		glow.Size = UDim2.fromScale(1, 1)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
		glow.Parent = screen
		local strip = Instance.new("Frame")
		strip.Size = UDim2.new(1, 0, 0, 8)
		strip.BorderSizePixel = 0
		strip.BackgroundColor3 = color
		strip.Parent = glow
		-- Downlights in the ceiling: warm white onto the counter and the wall.
		for _, dz in { -5, 5 } do
			local lamp = part(m, at3(-W + 10, 14.55, z + dz), Vector3.new(2, 0.12, 2), Color3.fromRGB(255, 240, 220), Enum.Material.Neon)
			light(lamp, Color3.fromRGB(255, 236, 214), 18, 1.1, true)
		end
		return counter
	end
	-- (Its stands of suits, helmets, picks and skins are the client's:
	-- Client.StoreDisplays.)
	local store = storefront(6, "SAGA OUTFITTERS", "STORE", STATION.Store)
	local market = storefront(40, "MINERS' MARKET", "MARKET", STATION.Market)
	-- Behind the Market's counter: the escrow lockers, where sold gear waits
	-- for its buyer, a wall of numbered doors, a lamp on each.
	do
		local lockers = part(m, facing(-W + 0.3, 8.2, 40, 1, 0), Vector3.new(18, 11, 0.2), HULL_DARK, Enum.Material.Metal)
		lockers.Name = "EscrowLockers"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(18 * 30, 11 * 30)
		gui.LightInfluence = 0.6
		gui.Parent = lockers
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BorderSizePixel = 0
		back.BackgroundColor3 = Color3.fromRGB(40, 43, 50)
		back.Parent = gui
		local wall = Instance.new("Frame")
		wall.Position = UDim2.fromOffset(6, 6)
		wall.Size = UDim2.new(1, -12, 1, -12)
		wall.BackgroundTransparency = 1
		wall.Parent = back
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(1 / 6, -6, 1 / 4, -6)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.Parent = wall
		for n = 1, 24 do
			local door = Instance.new("Frame")
			door.BorderSizePixel = 0
			door.BackgroundColor3 = Color3.fromRGB(70, 74, 84)
			door.LayoutOrder = n
			door.Parent = wall
			local number = Instance.new("TextLabel")
			number.BackgroundTransparency = 1
			number.Position = UDim2.fromScale(0.08, 0.08)
			number.Size = UDim2.fromScale(0.5, 0.3)
			number.TextScaled = true
			number.TextXAlignment = Enum.TextXAlignment.Left
			number.Font = Enum.Font.Oswald
			number.TextColor3 = Color3.fromRGB(176, 180, 188)
			number.Text = string.format("%02d", n)
			number.Parent = door
			local handle = Instance.new("Frame")
			handle.AnchorPoint = Vector2.new(1, 0.5)
			handle.Position = UDim2.fromScale(0.9, 0.55)
			handle.Size = UDim2.fromScale(0.06, 0.32)
			handle.BorderSizePixel = 0
			handle.BackgroundColor3 = Color3.fromRGB(150, 156, 166)
			handle.Parent = door
			local lamp = Instance.new("Frame")
			lamp.Position = UDim2.fromScale(0.08, 0.72)
			lamp.Size = UDim2.fromOffset(7, 7)
			lamp.BorderSizePixel = 0
			lamp.BackgroundColor3 = if n % 5 == 2 or n % 7 == 3 then STATION.Market else Color3.fromRGB(110, 114, 122)
			lamp.Parent = door
		end
	end

	-- The field guide, on the wall beside the door: what a new miner needs,
	-- a numbered row each, the subject in the station colour it belongs to.
	local _, _, head = signPanel(m, facing(-44, 13, D - 0.2, 0, -1), Vector3.new(36, 14, 0.4), "FIELD GUIDE", nil, SAGA)
	do
		-- (the title's inset from the colour bar, as signFace sets it)
		local tall = 14 * 40
		local inset = math.floor(tall * 0.09) + math.floor(tall * 0.16)
		head.Size = UDim2.new(1, -inset * 1.4, 0.16, 0)
		head.Position = UDim2.new(0, inset, 0.06, 0)
		local rows = Instance.new("Frame")
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.new(0, inset, 0.27, 0)
		rows.Size = UDim2.new(1, -inset * 1.4, 0.68, 0)
		rows.Parent = head.Parent
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = rows
		for n, row in
			{
				{ "QUARRY", "Every rock you break yields one gem.", STATION.Quarry },
				{ "FRONTIER", string.format("Luck rises past %d studs. So does rift activity.", core), STATION.Quarry },
				{ "KAIJU", "Your team fights beside you. Heal them once clear.", STATION.Gems },
				{ "SWINGS", "Arena Uplink win streaks restore swings.", STATION.Arena },
				{ "MECHS", "Bays 01 to 08. Exit by either garage door.", HAZARD },
				{ "QUESTIONS", "INFO-9, by the arena.", STATION.Info },
			}
		do
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.Size = UDim2.fromScale(1, 1 / 6)
			line.LayoutOrder = n
			line.Parent = rows
			for k, cell in
				{
					{ string.format("%02d", n), 0, 0.07, Color3.fromRGB(120, 126, 136), Enum.Font.Oswald },
					{ row[1], 0.08, 0.2, row[3], Enum.Font.Oswald },
					{ row[2], 0.3, 0.7, Color3.fromRGB(226, 228, 232), Enum.Font.GothamMedium },
				}
			do
				local text = Instance.new("TextLabel")
				text.Name = if k == 3 then "Line" else "Cell"
				text.BackgroundTransparency = 1
				text.Position = UDim2.fromScale(cell[2], 0.14)
				text.Size = UDim2.fromScale(cell[3], 0.72)
				text.TextScaled = true
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.Font = cell[5]
				text.TextColor3 = cell[4]
				text.Text = cell[1]
				text.Parent = line
			end
		end
	end

	-- The Arena Uplink's sign, over its gate by the door.
	signPanel(m, facing(36, 21.5, 46, -0.7, 0.7), Vector3.new(18, 4, 0.4), "ARENA UPLINK",
		"RANKED 1V1 DUELS", STATION.Arena)

	-- The season, kept outside: a pair of giant pumpkins on the quarry floor
	-- either side of the landing, a little one by each. Inside, the base is
	-- all business.
	for _, s in { -1, 1 } do
		pumpkin(m, at3(s * 36, -lift, D + 8) * CFrame.Angles(0, s * -.3, 0), 3.2, nil)
		pumpkin(m, at3(s * 41, -lift, D + 16) * CFrame.Angles(0, s * .4, 0), 1.1, nil)
	end
	-- The survey table on the west side of the hall, the Gem Gallery on the
	-- east, in front of the leaderboard.
	surveyTable(m, at3(-42, 0.86, 14))
	gemGallery(m, at3(30, 0.86, 4))

	-- The crew: the old town's shopkeepers, each by the station they run
	-- now (OutpostServer builds them, Shared.Vendors has their lines), and
	-- INFO-9, the info rep, by its kiosk. They stand beside their counters,
	-- not at them, so their Talk prompt and the counter's don't sit on top
	-- of each other. Ilsa buys gems at a desk in the Gem Gallery, the cases
	-- behind: a pale-topped counter lit gold along its front edge, its name
	-- on the front, a balance on top.
	local gold = GALLERY_COLORS[5]
	local desk = at3(31, 0.86, 4)
	solid(part(m, desk * CFrame.new(0, 1.7, 0), Vector3.new(2.4, 3.4, 8), HULL_DARK, Enum.Material.Metal))
	part(
		m,
		desk * CFrame.new(0.1, 3.5, 0),
		Vector3.new(2.8, 0.2, 8.4),
		Color3.fromRGB(206, 212, 224),
		Enum.Material.SmoothPlastic
	)
	local front = desk.Position + at:VectorToWorldSpace(Vector3.new(-1.25, 1.9, 0))
	signPanel(
		m,
		facingPoint(front, front - at:VectorToWorldSpace(Vector3.new(1, 0, 0))),
		Vector3.new(7, 1.9, 0.12),
		"GEM BUYER",
		"SPARE GEMS BOUGHT AT MARKET RATE",
		STATION.Gems
	)
	part(m, desk * CFrame.new(0, 4.6, 2), Vector3.new(0.24, 2, 0.24), gold, Enum.Material.Metal)
	part(m, desk * CFrame.new(0, 5.55, 2), Vector3.new(0.16, 0.16, 2.8), gold, Enum.Material.Metal)
	for _, dz in { -1.3, 1.3 } do
		disc(m, desk * CFrame.new(0, 4.75, 2 + dz), 0.6, 0.1, gold, Enum.Material.Metal)
	end
	-- INFO-9's kiosk, between the arena and the door, facing where players
	-- arrive: a post with a screen on top.
	local kiosk = facingPoint(at3(18.5, 0.86, 38).Position, at3(0, 0.86, D - 10).Position)
	solid(part(m, kiosk * CFrame.new(0, 2.2, 0), Vector3.new(1.6, 4.4, 1.2), HULL_DARK, Enum.Material.Metal))
	local screen = signPanel(m, kiosk * CFrame.new(0, 5.7, 0), Vector3.new(5, 2.6, 0.3), "INFORMATION", "INFO-9", STATION.Info)
	light(screen, Color3.fromRGB(230, 236, 244), 10, 0.4)
	local function stand(x, z, tx, tz)
		return facingPoint(at3(x, 0.86, z).Position, at3(tx, 0.86, tz).Position)
	end
	local crew = {
		{ Id = "GemBuyer", CFrame = stand(34.5, 4, 0, 4) }, -- Ilsa, behind her desk
		{ Id = "ArenaMaster", CFrame = stand(47.5, 50, 0, 50) }, -- Brutus, by the Uplink
		{ Id = "Broker", CFrame = stand(-61, 52, 0, 52) }, -- Tamsin, by the Market
		{ Id = "Outfitter", CFrame = stand(-58, 25.5, 0, 25.5) }, -- Borin, by the Store's suits
		{ Id = "Foreman", CFrame = stand(-24.5, 49, 0, 50) }, -- Garrick, by the door
		{ Id = "InfoBot", CFrame = stand(15, 41, 0, D - 10) }, -- INFO-9, by its kiosk
	}

	-- Players arrive in the garage lane facing bay 04's Mole drill (the
	-- camera starts behind them, over the barrier in the hall).
	local spawnAt = at3(-66.5 + 3 * 19, 3.5, laneMid + 2).Position
	local mech = parking[4].CFrame.Position
	return {
		Parking = parking,
		Spawn = facingPoint(spawnAt, mech),
		Probe = at3(68, 0, 36) * CFrame.Angles(0, math.rad(90), 0),
		Board = at3(72, 0, 2) * CFrame.Angles(0, math.rad(90), 0),
		Gate = at3(36, 0.8, 46),
		Store = store,
		Market = market,
		Crew = crew,
		Box = Vector2.new(W + 4, D + 4),
		Ramps = ramps,
		Feet = feet,
		Stairs = stairs,
	}
end

-- A secret: something hidden with a prompt-able part named "Secret".
function OutpostWorld.build(at: CFrame, parent: Instance)
	local root = Instance.new("Model")
	root.Name = "SagaOutpost"
	root:SetAttribute("Landscape", "Moon Quarry")
	root:SetAttribute("LandscapeVersion", 4)
	root:SetAttribute("SkySetting", "MoonBase")
	local rng = Random.new(4242)
	local ground = folder(root, "Ground")
	local Frontier = assert(OutpostWorld.Frontier, "OutpostWorld needs Shared.Frontier")
	-- The quarry floor and its regolith, worked benches, and a continuous
	-- natural crater rim. Invisible boundary walls stay beyond the benches.
	-- (Under the Loop's terrain, it's what you stand on: biomeTerrain hides
	-- it once that's laid.)
	local floor = solid(disc(ground, at * CFrame.new(0, -1, 0), 520, 2, REGOLITH, Enum.Material.Slate))
	for _ = 1, 90 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(10, 430)
		local radius = rng:NextNumber(10, 34)
		local color = REGOLITH:Lerp(REGOLITH_DARK, rng:NextNumber(0.1, 0.5))
		-- (Out past the core, the ground's the biomes' own: biomeTerrain.)
		if r <= Frontier.Core - 10 then
			disc(ground, at * CFrame.new(math.cos(a) * r, 0.05, math.sin(a) * r), radius, 0.1, color, Enum.Material.Sand)
		end
	end
	local standing = {} -- (craters and masts out on the floor: the land stays flat round them)
	for _, c in
		{
			{ 130, 40, 11 },
			{ -70, 100, 15 },
			{ 95, -20, 8 },
			{ -110, -40, 7 },
			{ 48, 150, 12 },
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
		table.insert(standing, { (at * CFrame.new(c[1], 0, c[2])).Position, c[3] + 4 })
	end
	local benchRamps = benches(ground, at)
	craterRim(ground, at)
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

	-- Haul roads out from the Shelter's walls: the four spokes, due north,
	-- east, south and west between the biomes (Shared.Frontier.Spokes: the
	-- Crossroads), the ring road round through all four (the Loop), and jump
	-- ramps on them.
	local roads = folder(root, "Roads")
	local roadLines = {}
	for _, a in Frontier.Spokes do
		local from = (at * CFrame.new(math.cos(a) * 104, 0, math.sin(a) * 104)).Position
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
	local ramps = {}
	-- (One on each spoke: north, east, south, west.)
	for i, out in { 345, 215, 330, 200 } do
		local a = Frontier.Spokes[i]
		local p = (at * CFrame.new(math.cos(a) * out, 0, math.sin(a) * out)).Position
		local outward = (at * CFrame.new(math.cos(a) * (out + 10), 0, math.sin(a) * (out + 10))).Position
		-- Low end towards the outpost, so you hit it driving out.
		jumpRamp(roads, CFrame.lookAt(p, p + (p - outward)))
		ramps[i] = p
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + math.rad(15)
		mast(roads, at * CFrame.new(math.cos(a) * 275, 0, math.sin(a) * 275), if i % 2 == 0 then SAGA else GLOW)
		table.insert(standing, { (at * CFrame.new(math.cos(a) * 275, 0, math.sin(a) * 275)).Position, 4 })
	end

	-- The Shelter in the middle, up on its legs: the lobby, the mech
	-- garage, the stations.
	local rules = assert(OutpostWorld.Rules, "OutpostWorld needs Shared.Outpost")
	local lift = rules.ShelterLift
	local home = shelter(root, at * CFrame.new(0, lift, 0), rules)
	local parking = home.Parking

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

	local hidden = {}

	-- The outpost along the north edge.
	local base = folder(root, "Outpost")
	local north = at * CFrame.new(0, 0, -110)
	-- Landing pad and shuttle, south-east of the Shelter.
	local padAt = at * CFrame.new(72, 0, 118)
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
	local solar = at * CFrame.new(-150, 0, 40) * CFrame.Angles(0, math.rad(30), 0)
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
	-- Fuel tanks to the east, with a gantry (clear of the garage's east
	-- door and of the way down its ramp).
	local tanks = at * CFrame.new(160, 0, 10)
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
	for i, c in { { -108, 22, 0 }, { 112, 70, 0 } } do
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
	for _, c in { { -50, -70 }, { 54, -66 }, { 100, 30 } } do
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

	-- PROBE-7 and the leaderboard on the Shelter's east wall, the Arena
	-- Uplink by its door; Halloween patches out in the quarry.
	local probeScreen = probe(root, home.Probe)
	local face = billboard(root, home.Board)
	local gatePad = gate(root, home.Gate)
	local festiveExclusions = harvestPatches(root, at)
	sky(root, at)

	-- Where rocks can grow: across the basin, clear of the buildings.
	local keepOut = {
		{ (north).Position, 60 },
		{ (north * CFrame.new(-70, 0, -18)).Position, 18 },
		{ (north * CFrame.new(72, 0, -14)).Position, 18 },
		{ padAt.Position, 40 },
		{ (at * CFrame.new(-150, 0, 40)).Position, 30 },
		{ (at * CFrame.new(160, 0, 10)).Position, 24 },
		{ (at * CFrame.new(-108, 0, 22)).Position, 10 },
		{ rigAt.Position, 16 },
		-- (the container stacks out in the quarry)
		{ (at * CFrame.new(-280, 0, -56)).Position, 20 },
		{ (at * CFrame.new(120, 0, -326)).Position, 20 },
		{ (at * CFrame.new(-200, 0, 244)).Position, 20 },
		{ (at * CFrame.new(340, 0, 64)).Position, 20 },
	}
	for _, exclusion in festiveExclusions do
		table.insert(keepOut, exclusion)
	end
	for _, secret in hidden do
		table.insert(keepOut, { secret.CFrame.Position, 26 })
	end
	for _, p in ramps do
		table.insert(keepOut, { p, 24 })
	end
	for _, p in benchRamps do
		table.insert(keepOut, { p, 40 })
	end
	-- (and off the Shelter's ramps, and clear of its feet)
	for _, r in home.Ramps do
		table.insert(keepOut, { r.Middle, math.sqrt(r.Half.X ^ 2 + r.Half.Y ^ 2) + 4 })
	end
	for _, foot in home.Feet do
		table.insert(keepOut, { foot, 8 })
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
	local arrivalSpots = {}
	-- The welcome rocks: two loose clusters right outside the Shelter's door,
	-- beside its ramp down and past its foot, flanking a clear lane out to
	-- the quarry.
	for _, p in { { -27, 80 }, { 27, 80 }, { -30, 96 }, { 30, 96 },
		{ -16, 126 }, { 16, 126 }, { -28, 138 }, { 28, 138 } } do
		table.insert(spots, at * CFrame.new(p[1], 0, p[2]))
		table.insert(arrivalSpots, #spots)
	end
	-- Room for a rock at `p`: off the roads and buildings, `gap` from the rest.
	local function clear(p: Vector3, gap: number): boolean
		if onRoad(p) then
			return false
		end
		-- (not in the Shelter, nor right up against its walls)
		local inside = p - at.Position
		if math.abs(inside.X) < home.Box.X and math.abs(inside.Z) < home.Box.Y then
			return false
		end
		for _, k in keepOut do
			if (p - k[1]).Magnitude < k[2] then
				return false
			end
		end
		for _, s in spots do
			if (s.Position - p).Magnitude < gap then
				return false
			end
		end
		return true
	end
	-- The biomes round the core: their ground, their landmarks, and a sign
	-- at each spoke's mouth (kept clear of the rocks after).
	local biomes = folder(root, "Biomes")
	for _, standing in biomeGround(biomes, at, rng, Frontier, clear) do
		table.insert(keepOut, standing)
	end
	for _, standing in crossroads(biomes, at, Frontier) do
		table.insert(keepOut, standing)
	end
	-- The frontier first (Shared.Frontier). Where the Rift Veins may surface
	-- by the walls: every site with room for all six rocks (kept clear of
	-- the outcrops, so a vein can always move there).
	local zoneOf = {}
	local function spotAt(offset: Vector3): Vector3
		return (at * CFrame.new(offset.X, 0, offset.Z)).Position
	end
	local veinSites = {}
	for _, base in Frontier.veinSites(rng) do
		-- (A road or a ramp in the way: it shifts a little round the wall.)
		for _, shift in { 0, 0.07, -0.07, 0.14, -0.14, 0.21, -0.21 } do
			local angle = base + shift
			local rocks, scar = Frontier.veinAt(angle, rng)
			local places, room = {}, true
			for _, offset in rocks do
				local p = spotAt(offset)
				if not clear(p, 12) then
					room = false
					break
				end
				table.insert(places, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			end
			if room then
				local scarAt = spotAt(scar)
				table.insert(veinSites, { Angle = angle, Rocks = places, Scar = CFrame.lookAt(scarAt, at.Position) })
				for _, cf in places do
					table.insert(keepOut, { cf.Position, 12 })
				end
				break
			end
		end
	end
	-- Outcrops: seams of rocks along a grain (no glowing cracks on the
	-- ground), and lone rocks between (a few leading out of the core).
	local outcropSpots = {}
	local function grow(offset: Vector3, zone: string, gap: number): boolean
		local p = spotAt(offset)
		if not clear(p, gap) then
			return false
		end
		table.insert(spots, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		zoneOf[#spots] = zone
		table.insert(outcropSpots, #spots)
		return true
	end
	local crops, lone = Frontier.outcrops(rng)
	for _, crop in crops do
		for _, offset in crop.Rocks do
			grow(offset, Frontier.zoneOf(offset.Magnitude), 12)
		end
	end
	for _, offset in lone do
		grow(offset, Frontier.zoneOf(offset.Magnitude), 12)
	end
	-- The three Rift Veins, far apart: their rocks take spots of their own,
	-- which move to another site when the vein does (OutpostServer).
	local veins, scars, taken, angles = {}, {}, {}, {}
	local siteAngles = {}
	for i, siteInfo in veinSites do
		siteAngles[i] = siteInfo.Angle
	end
	for _ = 1, Frontier.Veins.Count do
		local index = Frontier.pickSite(siteAngles, taken, angles, rng)
		if not index then
			break
		end
		taken[index] = true
		table.insert(angles, siteAngles[index])
		local vein = { Site = index, Spots = {} }
		local zone = if #veins + 1 == Frontier.Veins.Guarded then "Guarded" else "Vein"
		for _, cf in veinSites[index].Rocks do
			table.insert(spots, cf)
			zoneOf[#spots] = zone
			table.insert(vein.Spots, #spots)
		end
		table.insert(veins, vein)
		table.insert(scars, veinSites[index].Scar)
	end
	-- Then a field round the middle, where people mine between fights
	-- (spread evenly by distance, not area). The lane from the pad stays open.
	local nearSpots = {}
	local tries = 0
	while #nearSpots < NEAR_SPOTS and tries < 8000 do
		tries += 1
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(36, NEAR_REACH)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local p = (at * CFrame.new(x, 0, z)).Position
		if not (math.abs(x) < 10 and z > -60) and clear(p, 12) then
			table.insert(spots, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			table.insert(nearSpots, #spots)
		end
	end

	-- Every spot's zone (its rock mix and luck, and respawns keep it).
	local zones = {}
	for index in spots do
		zones[index] = zoneOf[index] or "Common"
	end
	-- (Wild kaiju keep out of the Shelter: circles over its floor.)
	for _, x in { -56, 0, 56 } do
		for _, z in { -32, 32 } do
			table.insert(keepOut, { (at * CFrame.new(x, 0, z)).Position, 46 })
		end
	end
	-- The ground under it all (Shared.Frontier.ground), the land rising only
	-- where nothing stands: no rock spot, vein site or its gate, building,
	-- crater, mast or road.
	local blocked = table.clone(keepOut)
	for _, b in standing do
		table.insert(blocked, b)
	end
	for _, cf in spots do
		table.insert(blocked, { cf.Position, 7 })
	end
	for _, vs in veinSites do
		for _, cf in vs.Rocks do
			table.insert(blocked, { cf.Position, 7 })
		end
		table.insert(blocked, { vs.Scar.Position, 16 })
	end
	if biomeTerrain(at, Frontier, blocked, roadLines) > 0 then
		floor.Transparency = 1
	end
	root.Parent = parent
	return {
		Model = root,
		Spawn = home.Spawn,
		Stations = { Store = home.Store, Market = home.Market },
		Crew = home.Crew,
		Shelter = { Box = home.Box, Lift = lift, Ramps = home.Ramps, Feet = home.Feet },
		-- The stairs down to the Kaiju Arena: { Landing (CFrame), Size, Top (CFrame) }.
		Stairs = home.Stairs,
		Probe = probeScreen,
		Board = face,
		Gate = gatePad,
		Spots = spots,
		ArrivalSpots = arrivalSpots,
		NearSpots = nearSpots,
		OutcropSpots = outcropSpots,
		Veins = veins,
		VeinSites = veinSites,
		Scars = scars,
		Zones = zones,
		FieldSpots = {},
		Parking = parking,
		Secrets = hidden,
		KeepOut = keepOut,
	}
end

return OutpostWorld
