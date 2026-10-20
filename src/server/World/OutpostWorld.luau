--[[
	Saga Outpost's world, built by the server so everyone shares it: a wide
	crater basin on the moon, ringed by weathered crater slopes. In the middle
	stands the Shelter, the base players arrive in (the mech garage with its
	eight bays and a door at each end, the Store, the player Market, PROBE-7,
	the leaderboard, the Arena Uplink and the kaiju arena, dressed for
	Halloween); outside is the quarry, where they mine and hunt. A working
	frontier outpost runs along the north edge (habitat modules strung on
	tubes, a refinery tower, a drill rig over its pit, conveyors, pipes and
	floodlight masts), with the landing pad and shuttle south-east, and
	planets hang in the black sky.

	  OutpostWorld.build(at, parent) -> {
	      Model, Spawn (CFrame: inside the Shelter's door, facing in),
	      Probe (BasePart, the terminal), Board (BasePart with the
	      leaderboard's face), Gate (BasePart), Stations ({ Store, Market }:
	      the Shelter's counters, for their prompts), Crew ({ { Id, CFrame } }:
	      where the Shelter's crew stand, by Shared.Vendors id, for
	      OutpostServer to build them), Shelter ({ Box }: its
	      half size, x and z, kept clear of rocks),
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
	  OutpostWorld.rock(size, cframe, rng, tint?) -> Model   one rock of that size
	      (Shared.Outpost.Sizes), its main chunk named "Body"; `tint` colours
	      its crystals (a frontier band's, Shared.Frontier.Bands)
	  OutpostWorld.veinMarks(parent, scar, rng, color?) -> Model   a vein's scorched
	      bed, cracks and beam of light over its dormant rift (moved with it;
	      `color` the guarded vein's, Shared.Frontier.Bands.Guarded)
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
local function crystalRock(model: Model, big: boolean, cframe: CFrame, rng, tint: Color3?): Model
	local s = if big then 6 else 3.6
	local glow = tint or GLOW
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
			BASALT,
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
				BASALT:Lerp(if i % 2 == 0 then BASALT_LIGHT else BASALT_DARK, rng:NextNumber(0.2, 0.7)),
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
			BASALT:Lerp(BASALT_DARK, rng:NextNumber(0, 1)),
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

function OutpostWorld.rock(size: string, cframe: CFrame, rng: Random, tint: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Rock"
	if size == "Pebble" or size == "Boulder" then
		-- (Out along the trails their crystals warm from cyan to gold to
		-- rose; a Rift Vein's are rift-touched violet.)
		return crystalRock(model, size == "Boulder", cframe, rng, tint)
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

-- A sign: a dark panel with a title and a line under it, read from its
-- front (build it with CFrame.lookAt(where, toward the reader)). Returns
-- the panel, its SurfaceGui and the title.
local function signPanel(parent, cframe: CFrame, size: Vector3, title: string, sub: string?, color: Color3)
	local board = part(parent, cframe, size, HULL_DARK, Enum.Material.Metal)
	board.Name = "Sign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 20, size.Y * 20)
	gui.LightInfluence = 0
	gui.Parent = board
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.fromScale(1, if sub then 0.62 else 1)
	head.Text = title
	head.TextScaled = true
	head.Font = Enum.Font.GothamBlack
	head.TextColor3 = color
	head.Parent = gui
	if sub then
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0.03, 0.6)
		line.Size = UDim2.fromScale(0.94, 0.34)
		line.Text = sub
		line.TextScaled = true
		line.Font = Enum.Font.GothamMedium
		line.TextColor3 = Color3.fromRGB(220, 235, 255)
		line.Parent = gui
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
	light(screen, GLOW, 22, 2.5)
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
		part(m, wing * CFrame.new(0, 0, -3.55), Vector3.new(9, 0.12, 0.12), GLOW, Enum.Material.Neon)
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
		gui.Brightness = 2
		gui.Parent = holo
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = "PROBE-7"
		text.TextScaled = true
		text.Font = Enum.Font.GothamBlack
		text.TextColor3 = GLOW
		text.TextStrokeTransparency = 0.6
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
	part(m, frame.CFrame * CFrame.new(0, 7.8, 0), Vector3.new(30.4, 0.6, 0.9), GLOW, Enum.Material.Neon)
	light(face, GLOW, 26, 1.2)
	return face
end

-- Halloween, at human scale: jack-o'-lanterns, a witch's hat, ghosts, bats,
-- webs, string lights and bunting. Static, non-interactive; the Shelter
-- wears most of it (its door, its garage, the hall) and a few patches sit
-- out in the quarry.
local ORANGE = Color3.fromRGB(225, 106, 32)
local AMBER = Color3.fromRGB(255, 203, 126)
local LEAF = Color3.fromRGB(45, 91, 68)
local VIOLET = Color3.fromRGB(163, 105, 236)
local NIGHT = Color3.fromRGB(43, 30, 65)

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

-- A little jack-o'-lantern, three parts: for rows of them (the garage bays).
local function lantern(parent, pose: CFrame, scale: number)
	local m = folder(parent, "MoonLantern")
	part(m, pose * CFrame.new(0, .8 * scale, 0), Vector3.new(2, 1.6, 2) * scale, ORANGE, Enum.Material.SmoothPlastic, "Ball")
	part(m, pose * CFrame.new(0, 1.7 * scale, 0) * CFrame.Angles(0, 0, -.25), Vector3.new(.25, .5, .25) * scale, LEAF, Enum.Material.Wood)
	part(m, pose * CFrame.new(0, .85 * scale, .93 * scale), Vector3.new(1.1, .5, .12) * scale, AMBER, Enum.Material.Neon)
	return m
end

-- A crooked, faceted witch's hat with a violet band, its brim at `hat`.
local function witchHat(parent, hat: CFrame, size: number)
	disc(parent, hat, size * .85, .24, NIGHT, Enum.Material.SmoothPlastic)
	for tier = 0, 2 do
		for _, yaw in { 0, math.pi } do
			part(parent, hat * CFrame.new(tier * .3, 1 + tier * 1.1, 0) * CFrame.Angles(0, yaw, 0),
				Vector3.new(3.6 - tier, 2.2, 1.8 - tier * .45), Color3.fromRGB(53, 34, 80), nil, "Wedge")
		end
	end
	disc(parent, hat * CFrame.new(0, .35, 0), size * .52, .35, VIOLET, Enum.Material.SmoothPlastic)
end

local function ghost(parent, pose: CFrame, scale: number)
	local m = folder(parent, "MoonGhost")
	local cream = Color3.fromRGB(219, 237, 236)
	part(m, pose, Vector3.new(1.9, 2.5, 1.3) * scale, cream, Enum.Material.SmoothPlastic, "Ball")
	for j = -1, 1 do
		part(m, pose * CFrame.new(j * .55 * scale, -1.05 * scale, 0), Vector3.new(.7, .8, 1) * scale,
			cream, Enum.Material.SmoothPlastic, "Ball")
	end
	for _, side in { -1, 1 } do
		part(m, pose * CFrame.new(side * 1.1 * scale, .15 * scale, 0) * CFrame.Angles(0, 0, side * .6),
			Vector3.new(.9, .4, .55) * scale, cream, Enum.Material.SmoothPlastic, "Ball")
		part(m, pose * CFrame.new(side * .32 * scale, .25 * scale, .62 * scale),
			Vector3.new(.22, .38, .13) * scale, HULL_DARK, nil, "Ball")
	end
	part(m, pose * CFrame.new(0, -.25 * scale, .67 * scale), Vector3.new(.25, .3, .1) * scale, VIOLET, Enum.Material.Neon, "Ball")
end

local function bat(parent, pose: CFrame)
	local m = folder(parent, "HarvestBat")
	part(m, pose, Vector3.new(.6, 1, .5), HULL_DARK, nil, "Ball")
	for _, side in { -1, 1 } do
		part(m, pose * CFrame.new(side * .9, .15, 0) * CFrame.Angles(0, if side < 0 then math.pi else 0, side * -.3),
			Vector3.new(1.6, .85, .16), Color3.fromRGB(65, 41, 88), nil, "Wedge")
		part(m, pose * CFrame.new(side * .18, .6, 0), Vector3.new(.18, .45, .24), HULL_DARK, nil, "Wedge")
	end
end

-- A web in a corner, facing along `pose`'s look.
local function web(parent, pose: CFrame, size: number)
	local m = folder(parent, "HarvestWeb")
	for ray = 0, 5 do
		local a, b = ray * math.pi / 3, (ray + 1) * math.pi / 3
		tube(m, pose.Position, (pose * CFrame.new(math.cos(a) * size, math.sin(a) * size, 0)).Position, .035 * size / 3.4, HULL)
		for ring = 1, 3 do
			local r = ring * size / 3.1
			tube(m, (pose * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)).Position,
				(pose * CFrame.new(math.cos(b) * r, math.sin(b) * r, 0)).Position, .025 * size / 3.4, HULL)
		end
	end
end

-- Lights strung from `from` to `to`, sagging `sag` in the middle: mostly
-- amber bulbs, now and then a violet one.
local function stringLights(parent, from: Vector3, to: Vector3, sag: number, bulbs: number)
	local previous
	for i = 0, bulbs - 1 do
		local t = i / (bulbs - 1)
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
		if previous then
			tube(parent, previous, p, .055, HULL_DARK)
		end
		previous = p
		part(parent, CFrame.new(p) * CFrame.new(0, -.25, 0), Vector3.new(.32, .5, .32),
			if i % 4 == 0 then VIOLET else AMBER, Enum.Material.Neon, "Ball")
	end
end

-- Bunting: a cord of diamond flags, orange, violet and night, sagging `sag`,
-- the flags turned to face `face`.
local function bunting(parent, from: Vector3, to: Vector3, sag: number, flags: number, face: Vector3)
	local previous
	local colors = { ORANGE, VIOLET, NIGHT }
	for i = 0, flags - 1 do
		local t = i / (flags - 1)
		local p = from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
		if previous then
			tube(parent, previous, p, .06, HULL_DARK)
		end
		previous = p
		local facing = CFrame.lookAt(p, p + face)
		part(parent, facing * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(1.5, 1.5, .1),
			colors[i % #colors + 1], Enum.Material.SmoothPlastic)
	end
end

-- Pumpkin patches out in the quarry, by the paths: a big one, a pearl and a
-- little one, a witch's hat on some. Returns their footprints, kept clear
-- of rocks.
local function harvestPatches(parent, at: CFrame)
	local decor = folder(parent, "HarvestPatches")
	local exclusions = {}
	for i, patch in { { -81, 153, 3.4, true }, { 81, 153, 3.6 }, { -118, -6, 3.8, true } } do
		local x, z, size = patch[1], patch[2], patch[3]
		table.insert(exclusions, { (at * CFrame.new(x, 0, z)).Position, 11 })
		local pose = at * CFrame.new(x, 0, z) * CFrame.Angles(0, if x < 0 then -.3 else .3, 0)
		pumpkin(decor, pose, size, if i == 2 then "Pearl" else nil)
		pumpkin(decor, at * CFrame.new(x - 5, 0, z + 3) * CFrame.Angles(0, -.5, 0), 1.05, "Pearl")
		pumpkin(decor, at * CFrame.new(x + 4.5, 0, z + 3.5) * CFrame.Angles(0, .3, 0), .55)
		if patch[4] then
			witchHat(decor, pose * CFrame.new(0, size * 1.75, 0) * CFrame.Angles(0, 0, -.15), size)
		end
		bat(decor, at * CFrame.new(x + 2, 13 + i, z + 1) * CFrame.Angles(0, i * .4, .2))
	end
	ghost(decor, at * CFrame.new(-114, 12, -2) * CFrame.Angles(0, -.2, -.1), 1.4)
	return exclusions
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
-- Glowing cracks in the ground along an outcrop's grain, so it sparkles
-- from afar without drawing a road: two or three thin strips.
local function seam(parent, at: CFrame, grain: number, length: number, color: Color3, rng)
	local along = CFrame.Angles(0, -grain, 0)
	for i = 1, rng:NextInteger(2, 3) do
		local off = (i - 2) * rng:NextNumber(3, 5)
		local crack = part(
			parent,
			at * along * CFrame.new(rng:NextNumber(-3, 3), 0.11, off) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0),
			Vector3.new(length * rng:NextNumber(0.55, 0.9), 0.06, rng:NextNumber(0.16, 0.3)),
			color,
			Enum.Material.Neon
		)
		crack.Name = "SeamCrack"
		crack.CastShadow = false
	end
end

-- Where a vein's dormant rift sits: scorched ground, cracks of the other
-- side's light running out from it, and a thin beam of violet light over it
-- you can see from the outpost (the tear itself is drawn by each player's
-- client: RiftTear). Its own model, so it moves with its vein. The guarded
-- vein's beam is its own `color`.
function OutpostWorld.veinMarks(parent, at: CFrame, rng, color: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "VeinMarks"
	model.Parent = parent
	local beam = part(
		model,
		at * CFrame.new(0, 90, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(180, 1.1, 1.1),
		color or Color3.fromRGB(215, 90, 255),
		Enum.Material.Neon,
		"Cylinder"
	)
	beam.Name = "VeinBeam"
	beam.Transparency = 0.55
	beam.CastShadow = false
	parent = model
	local bed = disc(parent, at * CFrame.new(0, 0.06, 0), 5.5, 0.1, Color3.fromRGB(44, 30, 58), Enum.Material.Slate)
	bed.CastShadow = false
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local length = rng:NextNumber(2.5, 6)
		local crack = part(
			parent,
			at * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.13, -(1.2 + length / 2)),
			Vector3.new(rng:NextNumber(0.14, 0.26), 0.06, length),
			Color3.fromRGB(215, 90, 255),
			Enum.Material.Neon
		)
		crack.Name = "ScarCrack"
		crack.CastShadow = false
	end
	return model
end

local NEAR_SPOTS = 52 -- rock spots in the field round the middle (the outcrops lead out from it)
local NEAR_REACH = 140 -- studs: the field stays inside the core (Shared.Frontier.Core)

-- Connected triangles make a continuous crater surface rather than separate
-- vertical towers. Shared vertices keep the silhouette and slopes seam-free.
local function craterFace(parent, at, a, b, c, color, material)
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
	for _, spec in {
		{ (a + b) / 2, right, back, math.abs(ab:Dot(back)) },
		{ (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) },
	} do
		local face = part(parent, at * CFrame.fromMatrix(spec[1], spec[2], up, spec[3]),
			Vector3.new(0.6, height, math.max(0.05, spec[4])), color, material, "Wedge")
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

-- The Moon Garden, a lounge in the hall round `at` (its middle, on the
-- floor): a planter ringed in light under a lunar tree hung with glowing
-- fruit, crystal flowers, and four benches (seats) facing the tree.
local function moonGarden(parent, at: CFrame)
	local m = folder(parent, "MoonGarden")
	local teal = Color3.fromRGB(96, 236, 200)
	-- The planter: a light on the floor round its rim, a steel bed, moss on top.
	disc(m, at * CFrame.new(0, 0.03, 0), 8, 0.06, teal, Enum.Material.Neon)
	solid(disc(m, at * CFrame.new(0, 0.9, 0), 7.4, 1.8, Color3.fromRGB(64, 68, 82), Enum.Material.Metal))
	disc(m, at * CFrame.new(0, 1.85, 0), 6.9, 0.2, Color3.fromRGB(70, 128, 98), Enum.Material.Grass)
	-- The lunar tree: a pale trunk, three boughs, a canopy of leaf clusters
	-- and fruit that glows.
	local bark = Color3.fromRGB(150, 136, 168)
	solid(part(m, at * CFrame.new(0, 6.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(9, 1.8, 1.8), bark, Enum.Material.Wood, "Cylinder"))
	for k = 0, 2 do
		local a = math.rad(20 + k * 120)
		local from = Vector3.new(0, 8.6, 0)
		local to = Vector3.new(math.cos(a) * 3.8, 11.6, math.sin(a) * 3.8)
		local mid = at * CFrame.new((from + to) / 2)
		part(m, CFrame.lookAt(mid.Position, (at * CFrame.new(to)).Position) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new((to - from).Magnitude + 0.6, 0.8, 0.8), bark, Enum.Material.Wood, "Cylinder")
	end
	local leaves = { Color3.fromRGB(70, 196, 168), Color3.fromRGB(116, 222, 190), Color3.fromRGB(88, 176, 200) }
	local crown = part(m, at * CFrame.new(0, 13.2, 0), Vector3.one * 7, leaves[1], nil, "Ball")
	light(crown, Color3.fromRGB(150, 255, 220), 30, 1.2)
	for k = 0, 5 do
		local a = math.rad(k * 60 + 30)
		part(m, at * CFrame.new(math.cos(a) * 3.9, 11.6 + (k % 2) * 0.9, math.sin(a) * 3.9), Vector3.one * (4.6 + (k % 3) * 0.5),
			leaves[k % 3 + 1], nil, "Ball")
	end
	local fruit = { Color3.fromRGB(255, 150, 230), Color3.fromRGB(255, 214, 120), Color3.fromRGB(150, 230, 255) }
	for k = 0, 7 do
		local a = math.rad(k * 45 + 10)
		part(m, at * CFrame.new(math.cos(a) * (4.4 + (k % 2) * 0.8), 9.6 + (k % 3) * 0.5, math.sin(a) * (4.4 + (k % 2) * 0.8)),
			Vector3.one * 0.9, fruit[k % 3 + 1], Enum.Material.Neon, "Ball")
	end
	-- Crystal flowers round the trunk.
	for k = 0, 5 do
		local a = math.rad(k * 60)
		local base = at * CFrame.new(math.cos(a) * 4.6, 1.95, math.sin(a) * 4.6)
		part(m, base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.6, 0.25, 0.25), Color3.fromRGB(80, 150, 110), nil, "Cylinder")
		part(m, base * CFrame.new(0, 1.75, 0), Vector3.new(0.8, 1, 0.8), fruit[k % 3 + 1], Enum.Material.Neon, "Ball")
	end
	-- Four benches facing the tree, between the paths.
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local spot = (at * CFrame.new(math.cos(a) * 11.5, 0, math.sin(a) * 11.5)).Position
		local face = facingPoint(spot, at.Position)
		solid(part(m, face * CFrame.new(0, 0.65, 0), Vector3.new(4.4, 1.3, 1.4), HULL_DARK, Enum.Material.Metal))
		local seat = Instance.new("Seat")
		seat.Name = "GardenBench"
		seat.Anchored = true
		seat.Size = Vector3.new(5, 0.5, 1.9)
		seat.CFrame = face * CFrame.new(0, 1.55, 0)
		seat.Color = Color3.fromRGB(206, 212, 224)
		seat.Material = Enum.Material.SmoothPlastic
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Parent = m
		part(m, face * CFrame.new(0, 2.7, 1.05), Vector3.new(5, 1.9, 0.35), Color3.fromRGB(206, 212, 224))
	end
	-- Its name, on a post by the path in from the hall.
	part(m, at * CFrame.new(9.4, 1.6, 0), Vector3.new(0.5, 3.2, 0.5), STEEL, Enum.Material.Metal)
	local spot = (at * CFrame.new(9.4, 3.9, 0)).Position
	signPanel(m, facingPoint(spot, spot + at:VectorToWorldSpace(Vector3.new(1, 0, 0))), Vector3.new(7, 1.6, 0.3),
		"MOON GARDEN", "TAKE A SEAT", teal)
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
		part(m, face * CFrame.new(0, 3.48, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.16, 3.2, 3.2), color,
			Enum.Material.Neon, "Cylinder")
		solid(part(m, face * CFrame.new(0, 5.36, 0), Vector3.new(2.6, 3.6, 2.6), Color3.fromRGB(190, 220, 255), Enum.Material.Glass,
			nil, { Transparency = 0.72, CastShadow = false }))
		local cap = part(m, face * CFrame.new(0, 7.31, 0), Vector3.new(2.9, 0.3, 2.9), HULL_DARK, Enum.Material.Metal)
		light(cap, color, 11, 1.6)
	end
	return m
end

-- The Shelter: the outpost's base in the middle of the basin, big enough to
-- hold the lobby (168 by 120 studs, the walls 34 high, a skylight over the
-- hall). Players arrive inside; outside is where they mine and hunt.
--   North: the mech garage, eight bays in a row facing a lane that runs out
--   of a big door at each end (east and west), behind a barrier with gaps.
--   The hall: the kaiju arena in the middle (a stage and stands, opening
--   soon), the Store and the player Market on the west wall, PROBE-7 and the
--   leaderboard on the east, the Arena Uplink by the door, and how it all
--   works on the wall beside the door. One wide door south, to the quarry.
-- Dressed for Halloween. Returns its places, in `at`'s frame:
-- { Parking, Spawn, Probe, Board, Gate (CFrames for those builders), Store,
--   Market (the counters, for their prompts), Crew ({ Id, CFrame }: where
--   its crew stand), Box (half sizes, x and z) }
local SHELTER = {
	HalfWidth = 84, -- x, inside
	HalfDepth = 60, -- z, inside
	Height = 34,
	Door = 14, -- the main door's half width (south)
	DoorHeight = 22,
	Lane = { -36, -16 }, -- the garage lane's z, and its doors
	LaneDoorHeight = 26,
	Barrier = -14, -- z of the barrier between the garage and the hall
}
local function shelter(parent, at: CFrame)
	local m = folder(parent, "Shelter")
	local W, D, H = SHELTER.HalfWidth, SHELTER.HalfDepth, SHELTER.Height
	local laneN, laneS = SHELTER.Lane[1], SHELTER.Lane[2]
	local walls = Color3.fromRGB(170, 176, 188)
	local function at3(x, y, z)
		return at * CFrame.new(x, y, z)
	end
	local function facing(x, y, z, dx, dz)
		local p = at3(x, y, z).Position
		return CFrame.lookAt(p, p + (at:VectorToWorldSpace(Vector3.new(dx, 0, dz))))
	end

	-- The floor: one slab under it all, the hall's polished (pale tiles, with
	-- darker seams every 12 studs), the garage lane dark.
	solid(part(m, at3(0, 0.4, 0), Vector3.new(W * 2 + 4, 0.8, D * 2 + 4), CONCRETE, Enum.Material.Concrete))
	part(m, at3(0, 0.83, (SHELTER.Barrier + D) / 2), Vector3.new(W * 2, 0.06, D - SHELTER.Barrier),
		Color3.fromRGB(112, 118, 132), Enum.Material.SmoothPlastic)
	local seam = Color3.fromRGB(84, 90, 104)
	for x = -72, 72, 12 do
		part(m, at3(x, 0.86, (SHELTER.Barrier + D) / 2), Vector3.new(0.14, 0.04, D - SHELTER.Barrier), seam)
	end
	for z = -2, 46, 12 do
		part(m, at3(0, 0.86, z), Vector3.new(W * 2, 0.04, 0.14), seam)
	end
	-- Where you arrive: a compass rose in the floor, a light at its heart.
	local rose = at3(0, 0.86, D - 10)
	disc(m, rose, 6.4, 0.06, SAGA)
	disc(m, rose * CFrame.new(0, 0.01, 0), 6, 0.06, Color3.fromRGB(126, 132, 148))
	for k = 0, 3 do
		part(m, rose * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(k * 45), 0),
			Vector3.new(if k % 2 == 0 then 11.4 else 7.4, 0.06, 0.36), SAGA)
	end
	disc(m, rose * CFrame.new(0, 0.05, 0), 1.1, 0.06, SAGA, Enum.Material.Neon)
	part(m, at3(0, 0.83, (laneN + laneS) / 2), Vector3.new(W * 2 + 4, 0.06, laneS - laneN),
		Color3.fromRGB(36, 38, 44), Enum.Material.Slate)
	for x = -78, 78, 12 do
		part(m, at3(x, 0.88, (laneN + laneS) / 2), Vector3.new(4, 0.06, 0.5), HAZARD, Enum.Material.SmoothPlastic)
	end
	-- An apron out of the main door.
	solid(part(m, at3(0, 0.4, D + 7), Vector3.new(SHELTER.Door * 2 + 10, 0.8, 10), CONCRETE, Enum.Material.Concrete))

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
		wall(x, (laneN + laneS) / 2, 2, laneS - laneN, SHELTER.LaneDoorHeight, H, true)
	end
	-- Bands along every length, proud of both faces: a dark plinth, a row of
	-- windows, and an orange glow under the roof.
	for _, l in lengths do
		local thick = Vector3.new(if l.SX > 2 then l.SX else 2.5, 0, if l.SZ > 2 then l.SZ else 2.5)
		if not l.Lintel then
			part(m, at3(l.X, 1.6, l.Z), thick + Vector3.new(0, 3.2, 0), HULL_DARK, Enum.Material.Metal)
		end
		part(m, at3(l.X, 28, l.Z), thick + Vector3.new(0, 3, 0) - Vector3.new(if l.SX > 2 then 1 else 0, 0, if l.SZ > 2 then 1 else 0),
			Color3.fromRGB(34, 62, 100), Enum.Material.Glass)
		part(m, at3(l.X, 31.2, l.Z), thick + Vector3.new(0, 0.5, 0), ORANGE, Enum.Material.Neon)
	end
	-- Ribs up the outside, and heavier corners.
	for _, x in { -78, -56, -34, 34, 56, 78 } do
		part(m, at3(x, (H + 1) / 2, D + 2.2), Vector3.new(2.6, H + 1, 2.4), HULL_DARK, Enum.Material.Metal)
	end
	for x = -78, 78, 26 do
		part(m, at3(x, (H + 1) / 2, -D - 2.2), Vector3.new(2.6, H + 1, 2.4), HULL_DARK, Enum.Material.Metal)
	end
	for _, s in { -1, 1 } do
		for _, z in { -54, -6, 22, 50 } do
			part(m, at3(s * (W + 2.2), (H + 1) / 2, z), Vector3.new(2.4, H + 1, 2.6), HULL_DARK, Enum.Material.Metal)
		end
		for _, z in { -1, 1 } do
			solid(part(m, at3(s * (W + 2), (H + 3) / 2, z * (D + 2)), Vector3.new(5, H + 3, 5), HULL_DARK, Enum.Material.Metal))
		end
	end

	-- The roof, round a raised skylight over the hall: glass sides and a
	-- glass top, edged in orange.
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
	local glass = Color3.fromRGB(60, 110, 160)
	local skyMid = (sky.Z0 + sky.Z1) / 2
	for _, z in { sky.Z0, sky.Z1 } do
		part(m, at3(0, roofY + 4.4, z), Vector3.new(sky.X * 2, 8, 0.4), glass, Enum.Material.Glass, nil, { Transparency = 0.35 })
	end
	for _, s in { -1, 1 } do
		part(m, at3(s * sky.X, roofY + 4.4, skyMid), Vector3.new(0.4, 8, sky.Z1 - sky.Z0), glass, Enum.Material.Glass, nil, { Transparency = 0.35 })
	end
	part(m, at3(0, roofY + 8.6, skyMid), Vector3.new(sky.X * 2 + 1, 0.4, sky.Z1 - sky.Z0 + 1), glass, Enum.Material.Glass, nil, { Transparency = 0.45 })
	part(m, at3(0, roofY + 8.3, skyMid), Vector3.new(sky.X * 2, 0.8, 1), HULL_DARK, Enum.Material.Metal)
	for _, z in { sky.Z0, sky.Z1 } do
		part(m, at3(0, roofY + 8.9, z), Vector3.new(sky.X * 2 + 1.2, 0.4, 0.5), ORANGE, Enum.Material.Neon)
	end
	-- Lights: three over the garage, four along the hall's sides, two hung
	-- over the arena from the skylight.
	for _, x in { -48, 0, 48 } do
		local lamp = part(m, at3(x, roofY - 0.9, (laneN + SHELTER.Barrier) / 2 - 8), Vector3.new(10, 0.4, 3), GLOW, Enum.Material.Neon)
		light(lamp, Color3.fromRGB(220, 240, 255), 52, 1.2)
	end
	for _, s in { -1, 1 } do
		for _, z in { 8, 44 } do
			local lamp = part(m, at3(s * 62, roofY - 0.9, z), Vector3.new(3, 0.4, 10), AMBER, Enum.Material.Neon)
			light(lamp, Color3.fromRGB(255, 226, 190), 46, 1)
		end
		local hung = part(m, at3(s * 14, 28, 18), Vector3.new(2.4, 1.2, 2.4), AMBER, Enum.Material.Neon, "Ball")
		tube(m, hung.CFrame.Position, at3(s * 14, roofY + 8.2, 18).Position, 0.08, HULL_DARK)
		light(hung, Color3.fromRGB(255, 196, 130), 40, 1.3)
		-- Cool white panels down each side of the skylight, so the hall is
		-- evenly lit and its corners aren't left in the dark.
		for _, z in { -4, 20, 44 } do
			local panel = part(m, at3(s * 46, roofY - 0.75, z), Vector3.new(12, 0.3, 4), Color3.fromRGB(236, 242, 255), Enum.Material.Neon)
			light(panel, Color3.fromRGB(232, 240, 255), 42, 0.9)
		end
	end

	-- The main door: hazard posts, a canopy edged in orange, the name over it,
	-- and inside, over it, the way to the quarry.
	for _, s in { -1, 1 } do
		part(m, at3(s * (SHELTER.Door + 1.2), SHELTER.DoorHeight / 2, D + 1), Vector3.new(2.4, SHELTER.DoorHeight, 2.8), HAZARD, Enum.Material.Metal)
	end
	part(m, at3(0, SHELTER.DoorHeight + 1.5, D + 6.5), Vector3.new(SHELTER.Door * 2 + 12, 1, 9), HULL_DARK, Enum.Material.Metal)
	part(m, at3(0, SHELTER.DoorHeight + 1, D + 11), Vector3.new(SHELTER.Door * 2 + 12, 0.4, 0.4), ORANGE, Enum.Material.Neon)
	local name = signPanel(m, facing(0, 29.5, D + 2.3, 0, 1), Vector3.new(48, 7, 0.4), "SAGA SHELTER",
		"MECH GARAGE  ·  STORE  ·  MARKET  ·  KAIJU ARENA", SAGA)
	light(name, SAGA, 24, 1)
	signPanel(m, facing(0, 25, D - 0.2, 0, -1), Vector3.new(26, 3.2, 0.4), "TO THE QUARRY",
		"MINE ROCKS  ·  KITE CRITTERS  ·  TAME KAIJU", GLOW)

	-- The garage: eight bays along the north wall, facing the lane.
	local bays = { "Hauler", "Hauler", "Mole", "Mole", "Digger", "Skipper", "Skipper", "Skipper" }
	local names = {
		Hauler = "ATLAS HAULER",
		Mole = "MOLE DRILL",
		Digger = "FORGE UTILITY",
		Skipper = "SCOUT PATHFINDER",
	}
	local bayZ = -48
	local parking = {}
	for k = 0, #bays do
		part(m, at3(-76 + k * 19, 0.88, bayZ - 1), Vector3.new(0.5, 0.06, 20), HAZARD, Enum.Material.SmoothPlastic)
	end
	for i, kind in bays do
		local x = -66.5 + (i - 1) * 19
		signPanel(m, facing(x, 21, -D + 0.4, 0, 1), Vector3.new(15, 5, 0.4), "BAY " .. i, names[kind], HAZARD)
		lantern(m, at3(x, 23.5, -D + 1.2), 1.1)
		local spot = at3(x, 1, bayZ).Position
		table.insert(parking, { Kind = kind, CFrame = CFrame.lookAt(spot, spot - at.LookVector) })
	end
	signPanel(m, facing(0, 30, -D + 0.4, 0, 1), Vector3.new(56, 5.5, 0.4), "MECH GARAGE",
		"HOP IN AT ANY BAY  ·  DRIVE OUT EITHER DOOR", HAZARD)
	-- Each garage door: hazard posts, the rolled-up door, EXIT over it.
	for _, s in { -1, 1 } do
		for _, z in { laneN - 1, laneS + 1 } do
			part(m, at3(s * (W - 0.7), SHELTER.LaneDoorHeight / 2, z), Vector3.new(1.4, SHELTER.LaneDoorHeight, 1.4), HAZARD, Enum.Material.Metal)
		end
		part(m, at3(s * (W + 1), SHELTER.LaneDoorHeight + 1.4, (laneN + laneS) / 2) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(laneS - laneN, 2.6, 2.6), HULL_DARK, Enum.Material.Metal, "Cylinder")
		signPanel(m, facing(s * (W - 0.4), SHELTER.LaneDoorHeight + 3.4, (laneN + laneS) / 2, -s, 0),
			Vector3.new(10, 2.6, 0.4), "EXIT", nil, Color3.fromRGB(90, 255, 140))
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
	web(m, at3(-W + 3, 28, -D + 3) * CFrame.Angles(0, math.rad(45), 0), 3.4)

	-- The kaiju arena: a stage edged in glow, two tiers of stands open to the
	-- door and the garage, pylons, and its sign over the way in.
	local arena = at3(0, 0.8, 18)
	solid(disc(m, arena * CFrame.new(0, 0.5, 0), 12.6, 1, ORANGE, Enum.Material.Neon))
	solid(disc(m, arena * CFrame.new(0, 0.75, 0), 12, 1.5, Color3.fromRGB(46, 40, 60), Enum.Material.Slate))
	part(m, arena * CFrame.new(0, 1.52, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.06, 10, 10), VIOLET,
		Enum.Material.Neon, "Cylinder", { Transparency = 0.35 })
	-- (Pale steel, each tier's front edge lit violet.)
	for tier, spec in { { 16, 1.6 }, { 19.5, 3.2 } } do
		local r, h = spec[1], spec[2]
		for k = 0, 11 do
			local a = (k + 0.5) / 12 * math.pi * 2
			if math.abs(math.cos(a)) >= 0.3 then
				local seat = arena * CFrame.new(math.cos(a) * r, h / 2, math.sin(a) * r) * CFrame.Angles(0, math.pi / 2 - a, 0)
				local length = 2 * math.pi * r / 12 - 0.6
				solid(part(m, seat, Vector3.new(length, h, 3), if tier == 1 then Color3.fromRGB(176, 182, 196) else Color3.fromRGB(112, 118, 134),
					Enum.Material.Metal))
				part(m, seat * CFrame.new(0, h / 2 - 0.12, -1.52), Vector3.new(length, 0.2, 0.1), VIOLET, Enum.Material.Neon)
			end
		end
	end
	for k = 0, 3 do
		local a = (k + 0.5) / 4 * math.pi * 2
		part(m, arena * CFrame.new(math.cos(a) * 13.6, 4.5, math.sin(a) * 13.6), Vector3.new(1, 9, 1), HULL_DARK, Enum.Material.Metal)
		part(m, arena * CFrame.new(math.cos(a) * 13.6, 9.4, math.sin(a) * 13.6), Vector3.one * 1.6, ORANGE, Enum.Material.Neon, "Ball")
	end
	-- (Its sign up high, clear of the hologram on the stage.)
	for _, s in { -1, 1 } do
		part(m, arena * CFrame.new(s * 7, 8.5, 19.5), Vector3.new(0.8, 17, 0.8), HULL_DARK, Enum.Material.Metal)
	end
	signPanel(m, facing(0, 18.4, 18 + 19.5, 0, 1), Vector3.new(16, 3.4, 0.4), "KAIJU ARENA", "COMING SOON", VIOLET)
	for _, g in { { -8, 23, 12, 1.4, .4 }, { 9, 26, 22, 1.2, -.5 }, { 1, 29, 8, 1, 2.6 } } do
		ghost(m, at3(g[1], g[2], g[3]) * CFrame.Angles(0, g[5], -.1), g[4])
	end

	-- The Store and the player Market, booths on the west wall.
	local function booth(z, title, sub, color)
		local counter = solid(part(m, at3(-W + 18, 2.6, z), Vector3.new(3.2, 3.6, 16), HULL_DARK, Enum.Material.Metal))
		counter.Name = title .. "Counter"
		part(m, at3(-W + 18, 4.55, z), Vector3.new(3.6, 0.3, 16.4), color, Enum.Material.Neon)
		part(m, at3(-W + 9.5, 15, z), Vector3.new(17, 0.8, 22), HULL_DARK, Enum.Material.Metal)
		part(m, at3(-W + 18.2, 15, z), Vector3.new(0.5, 1.2, 22.4), color, Enum.Material.Neon)
		for _, dz in { -10.5, 10.5 } do
			part(m, at3(-W + 17.6, 7.6, z + dz), Vector3.new(0.8, 14.4, 0.8), STEEL, Enum.Material.Metal)
		end
		local sign = signPanel(m, facing(-W + 18.6, 18.2, z, 1, 0), Vector3.new(20, 4.2, 0.4), title, sub, color)
		light(sign, color, 22, 0.8)
		return counter
	end
	-- (Its stands of suits, helmets, picks and skins are the client's:
	-- Client.StoreDisplays.)
	local store = booth(6, "STORE", "SKINS  ·  HELMETS  ·  PICKS  ·  SUITS", Color3.fromRGB(196, 120, 255))
	local market = booth(40, "MARKET", "BUY  ·  SELL  ·  OFFER", Color3.fromRGB(90, 220, 170))
	signPanel(m, facing(-W + 0.4, 9.5, 40, 1, 0), Vector3.new(18, 7, 0.4), "PLAYER MARKET", "GEMS AND GEAR FROM EVERY MINER", SAGA)
	pumpkin(m, at3(-W + 12, 0.8, 22) * CFrame.Angles(0, 1.2, 0), 1.6)
	pumpkin(m, at3(-W + 9, 0.8, 25) * CFrame.Angles(0, 1.6, 0), 0.8, "Pearl")

	-- How it all works, on the wall beside the door.
	local _, gui, head = signPanel(m, facing(-44, 13, D - 0.2, 0, -1), Vector3.new(36, 14, 0.4), "HOW IT WORKS", nil, SAGA)
	do
		head.Size = UDim2.fromScale(1, 0.22)
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromScale(0.05, 0.26)
		body.Size = UDim2.fromScale(0.9, 0.7)
		body.TextScaled = true
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Font = Enum.Font.GothamMedium
		body.TextColor3 = Color3.fromRGB(220, 235, 255)
		body.Text = table.concat({
			"1  Out in the quarry, every rock pays a gem.",
			"2  Swings low? Win 1v1s at the Arena Uplink: streaks restore them.",
			"3  Your kaiju fight beside you. Heal them once you're clear.",
			"4  Mechs wait in the garage: hop in, drive out either door.",
			"5  Invite friends for reward coupons (INVITE).",
		}, "\n")
		body.Parent = gui
	end

	-- The Arena Uplink's sign, over its gate by the door.
	signPanel(m, facing(36, 21.5, 46, -0.7, 0.7), Vector3.new(18, 4, 0.4), "1V1 ARENA UPLINK",
		"WIN STREAKS RESTORE YOUR SWINGS", Color3.fromRGB(255, 90, 110))

	-- Halloween at the door: giant pumpkins (one in a witch's hat), little
	-- ones, lights along the front, bats on the roof and a ghost.
	for _, s in { -1, 1 } do
		local giant = at3(s * 24, 0, D + 10) * CFrame.Angles(0, s * -.3, 0)
		pumpkin(m, giant, 3.2, nil)
		if s < 0 then
			witchHat(m, giant * CFrame.new(0, 3.2 * 1.75, 0) * CFrame.Angles(0, 0, -.15), 3.2)
		end
		pumpkin(m, at3(s * 31, 0, D + 13) * CFrame.Angles(0, s * .4, 0), 1.1, nil)
		pumpkin(m, at3(s * 18.5, 0, D + 14) * CFrame.Angles(0, s * -.5, 0), .6, "Pearl")
		for _, x in { 40, 70 } do
			bat(m, at3(s * x, roofY + 1.6, D + 2) * CFrame.Angles(0, x * .1, .2))
		end
	end
	stringLights(m, at3(-36, 26.6, D + 2.6).Position, at3(36, 26.6, D + 2.6).Position, 1.8, 13)
	ghost(m, at3(-40, 15, D + 9) * CFrame.Angles(0, -.3, -.1), 1.2)
	pumpkin(m, at3(-20, 0.8, D - 6) * CFrame.Angles(0, math.pi + .3, 0), 1.5)
	pumpkin(m, at3(20, 0.8, D - 6) * CFrame.Angles(0, math.pi - .3, 0), 1.3, "Pearl")
	-- Bunting across the hall.
	for _, z in { 2, 34 } do
		bunting(m, at3(-W + 1, 27, z).Position, at3(W - 1, 27, z).Position, 3, 11, at:VectorToWorldSpace(Vector3.new(0, 0, 1)))
	end
	-- The Moon Garden on the west side of the hall, the Gem Gallery on the
	-- east, in front of the leaderboard.
	moonGarden(m, at3(-42, 0.86, 14))
	gemGallery(m, at3(30, 0.86, 4))

	-- The crew: the old town's shopkeepers, each by the station they run
	-- now (OutpostServer builds them, Shared.Vendors has their lines).
	-- They stand beside their counters, not at them, so their Talk prompt
	-- and the counter's don't sit on top of each other. Ilsa buys gems at a
	-- desk in the Gem Gallery, the cases behind: a pale-topped counter lit
	-- gold along its front edge, its name on the front, a balance on top.
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
	part(m, desk * CFrame.new(-1.3, 3.5, 0), Vector3.new(0.14, 0.24, 8.4), gold, Enum.Material.Neon)
	local front = desk.Position + at:VectorToWorldSpace(Vector3.new(-1.25, 1.9, 0))
	signPanel(
		m,
		facingPoint(front, front - at:VectorToWorldSpace(Vector3.new(1, 0, 0))),
		Vector3.new(7, 1.9, 0.12),
		"GEM BUYER",
		"COINS FOR YOUR SPARE GEMS",
		gold
	)
	part(m, desk * CFrame.new(0, 4.6, 2), Vector3.new(0.24, 2, 0.24), gold, Enum.Material.Metal)
	part(m, desk * CFrame.new(0, 5.55, 2), Vector3.new(0.16, 0.16, 2.8), gold, Enum.Material.Metal)
	for _, dz in { -1.3, 1.3 } do
		disc(m, desk * CFrame.new(0, 4.75, 2 + dz), 0.6, 0.1, gold, Enum.Material.Metal)
	end
	local function stand(x, z, tx, tz)
		return facingPoint(at3(x, 0.86, z).Position, at3(tx, 0.86, tz).Position)
	end
	local crew = {
		{ Id = "GemBuyer", CFrame = stand(34.5, 4, 0, 4) }, -- Ilsa, behind her desk
		{ Id = "ArenaMaster", CFrame = stand(47.5, 50, 0, 50) }, -- Brutus, by the Uplink
		{ Id = "Broker", CFrame = stand(-61, 52, 0, 52) }, -- Tamsin, by the Market
		{ Id = "Outfitter", CFrame = stand(-58, 25.5, 0, 25.5) }, -- Borin, by the Store's suits
		{ Id = "Foreman", CFrame = stand(-24.5, 49, 0, 50) }, -- Garrick, by the door
	}

	local spawnAt = at3(0, 3.5, D - 10).Position
	return {
		Parking = parking,
		Spawn = CFrame.lookAt(spawnAt, spawnAt + at.LookVector),
		Probe = at3(68, 0, 36) * CFrame.Angles(0, math.rad(90), 0),
		Board = at3(72, 0, 2) * CFrame.Angles(0, math.rad(90), 0),
		Gate = at3(36, 0.8, 46),
		Store = store,
		Market = market,
		Crew = crew,
		Box = Vector2.new(W + 4, D + 4),
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
	-- The quarry floor and its regolith, worked benches, and a continuous
	-- natural crater rim. Invisible boundary walls stay beyond the benches.
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
			{ 130, 40, 11 },
			{ -70, 100, 15 },
			{ 95, -20, 8 },
			{ -110, -40, 7 },
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

	-- Haul roads out from the Shelter's walls, a ring road, and jump ramps on them.
	local roads = folder(root, "Roads")
	local roadLines = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.rad(30)
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

	-- The Shelter in the middle: the lobby, the mech garage, the stations.
	local home = shelter(root, at)
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
	-- Fuel tanks to the east, with a gantry (clear of the garage's east door).
	local tanks = at * CFrame.new(150, 0, -20)
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
		{ (at * CFrame.new(150, 0, -20)).Position, 24 },
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
	-- flanking a clear lane out to the quarry.
	for _, p in { { -15, 84 }, { 15, 84 }, { -27, 96 }, { 27, 96 },
		{ -15, 108 }, { 15, 108 }, { -30, 122 }, { 30, 122 } } do
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
	-- The frontier first (Shared.Frontier). Where the Rift Veins may surface
	-- by the walls: every site with room for all six rocks (kept clear of
	-- the outcrops, so a vein can always move there).
	local Frontier = assert(OutpostWorld.Frontier, "OutpostWorld needs Shared.Frontier")
	local frontier = folder(root, "Frontier")
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
	-- Outcrops: seams of rocks along a grain, glowing cracks round each, and
	-- lone rocks between (a few leading out of the core).
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
		local grew = 0
		for _, offset in crop.Rocks do
			if grow(offset, Frontier.zoneOf(offset.Magnitude), 12) then
				grew += 1
			end
		end
		if grew > 0 then
			local band = Frontier.band(crop.Middle.Magnitude)
			local middle = at * CFrame.new(crop.Middle.X, 0, crop.Middle.Z)
			seam(frontier, middle, crop.Grain, crop.Length, Frontier.Bands[band].Color, rng)
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
	root.Parent = parent
	return {
		Model = root,
		Spawn = home.Spawn,
		Stations = { Store = home.Store, Market = home.Market },
		Crew = home.Crew,
		Shelter = { Box = home.Box },
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
