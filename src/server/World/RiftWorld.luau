--[[
	The Rift's world (Server.RiftServer runs a trip through it; the rules are
	Shared.RiftRun's): the critters' own side, built for one trip and gone
	with it. A pathway of basalt islands floating over a sea of lava, under
	a blood-red moon and black spires: the landing (and the way home) first,
	then RiftRun.Rooms islands joined by causeways caged in giant ribs, a
	wall of fire across the way out of each until it's cleared, and last the
	boss's island, ringed with spires round an obsidian throne. Ash falls
	the whole way. (Each runner's client tints it all: Client.RiftClient.)

	  RiftWorld.build(id, origin, rng) -> {
	      Folder, Origin (CFrame: the landing's middle, on its floor),
	      Start (CFrame: where you land, facing the way in),
	      Rooms ({ { Center (Vector3, on its floor), Radius } }),
	      Boss ({ Center, Radius }),
	      Gates ({ Model }: room n's wall of fire, on the way out of it),
	      Exit (BasePart: the way home on the landing, its prompt "RiftExit"),
	      Home (Model: the way home on the boss's island, shut till it's beaten),
	  }
	  RiftWorld.openGate(gate)     the fire dies down and the way's open
	  RiftWorld.openHome(world)    the way home on the boss's island opens
	  RiftWorld.Spacing, RiftWorld.Floor   how far apart the islands are; how
	      far under them the lava is
]]
local RiftRun = require(game:GetService("ReplicatedStorage").Shared.RiftRun)

local RiftWorld = {}

RiftWorld.Spacing = 92
RiftWorld.Floor = 26

local BASALT = Color3.fromRGB(46, 38, 38)
local UNDER = Color3.fromRGB(30, 24, 25)
local OBSIDIAN = Color3.fromRGB(24, 19, 24)
local BONE = Color3.fromRGB(214, 200, 172)
local LAVA = Color3.fromRGB(255, 78, 20)
local EMBER = Color3.fromRGB(255, 142, 46)
local BLOOD = Color3.fromRGB(150, 26, 20)

local function part(parent, cframe: CFrame, size: Vector3, color: Color3, material, shape: string?, solid: boolean?)
	local p = Instance.new(
		if shape == "Wedge" then "WedgePart" elseif shape == "CornerWedge" then "CornerWedgePart" else "Part"
	)
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid == true
	p.CastShadow = solid == true and math.max(size.X, size.Y, size.Z) > 3
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function glow(p: BasePart)
	p.Material = Enum.Material.Neon
	p.CastShadow = false
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function fire(parent: Instance, size: number, heat: number?)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = heat or 12
	f.Color = EMBER
	f.SecondaryColor = BLOOD
	f.Parent = parent
	return f
end

-- A yaw that turns a part's front (-Z) along `dir` (flat).
local function yawOf(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- A horn of obsidian out of the rock at `base`: three pieces, each smaller
-- and bent further over, leaning out along `yaw`.
local function horn(parent, base: Vector3, yaw: number, length: number, width: number, rng)
	local at = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local bend = rng:NextNumber(0.18, 0.32)
	for i = 1, 3 do
		local seg = length / 3
		local w = width * (1.15 - i * 0.28)
		at = at * CFrame.Angles(-bend, 0, 0)
		part(parent, at * CFrame.new(0, seg / 2, 0), Vector3.new(w, seg + 0.3, w), OBSIDIAN, Enum.Material.Slate)
		at = at * CFrame.new(0, seg, 0)
	end
end

-- A floating island: a basalt slab with its top at `center`, rough rocks
-- round its rim, its underside hanging in points over the lava, cracks
-- glowing in its floor, horns round its edge and a brazier or two.
local function island(parent, center: Vector3, radius: number, rng, opts: { Horns: number?, Braziers: number? }?)
	local model = Instance.new("Model")
	model.Name = "Island"
	model.Parent = parent
	part(
		model,
		CFrame.new(center - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(8, radius * 2, radius * 2),
		BASALT,
		Enum.Material.Basalt,
		"Cylinder",
		true
	)
	-- (Underneath, hanging rock tapering into the dark.)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * radius * rng:NextNumber(0.1, 0.45)
		local w = radius * rng:NextNumber(0.7, 1.1)
		local deep = rng:NextNumber(12, 22)
		part(
			model,
			CFrame.new(center + off - Vector3.new(0, 8 + deep / 2, 0))
				* CFrame.Angles(math.pi, rng:NextNumber(0, math.pi), 0),
			Vector3.new(w, deep, w * 0.8),
			UNDER,
			Enum.Material.Basalt,
			"CornerWedge"
		)
	end
	-- Rough rocks round the rim (solid: no stepping off by accident there).
	local rocks = math.floor(radius / 3)
	for i = 1, rocks do
		local a = i / rocks * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local at = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius - 1.5)
		local size = Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(1.5, 4.5), rng:NextNumber(3, 6))
		part(
			model,
			CFrame.new(at + Vector3.new(0, size.Y / 2 - 1, 0))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
			size,
			UNDER,
			Enum.Material.Basalt,
			nil,
			true
		)
	end
	-- Cracks in its floor with the lava's light coming through.
	for _ = 1, math.floor(radius / 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = rng:NextNumber(0.15, 0.45) * radius
		local length = rng:NextNumber(0.25, 0.45) * radius
		local mid = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (from + length / 2)
		glow(
			part(
				model,
				CFrame.new(mid + Vector3.new(0, 0.04, 0))
					* CFrame.Angles(0, -a + math.pi / 2 + rng:NextNumber(-0.2, 0.2), 0),
				Vector3.new(rng:NextNumber(0.3, 0.6), 0.1, length),
				LAVA,
				nil
			)
		)
	end
	local options = opts or {}
	for i = 1, options.Horns or 3 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / (options.Horns or 3) * math.pi * 2
		local at = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius - 2.5)
		horn(model, at, a + math.pi / 2, rng:NextNumber(9, 15), rng:NextNumber(1.8, 2.6), rng)
	end
	for i = 1, options.Braziers or 2 do
		local a = (i + 0.5) / (options.Braziers or 2) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local at = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius * 0.72)
		part(
			model,
			CFrame.new(at + Vector3.new(0, 1.5, 0)),
			Vector3.new(1.4, 3, 1.4),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		local bowl = part(
			model,
			CFrame.new(at + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(1, 3.4, 3.4),
			OBSIDIAN,
			Enum.Material.Slate,
			"Cylinder"
		)
		glow(part(model, CFrame.new(at + Vector3.new(0, 3.95, 0)), Vector3.new(2.6, 0.2, 2.6), EMBER))
		fire(bowl, 5, 9)
		light(bowl, EMBER, 26, 1.6)
	end
	return model
end

-- A causeway from `a` to `b` (island tops, their radii `ra`, `rb`): slabs
-- of rock a little out of true, caged in giant ribs.
local function causeway(parent, a: Vector3, ra: number, b: Vector3, rb: number, rng)
	local model = Instance.new("Model")
	model.Name = "Causeway"
	model.Parent = parent
	local dir = flat(b - a).Unit
	local from = a + dir * (ra - 3)
	local to = b - dir * (rb - 3)
	local length = flat(to - from).Magnitude
	local yaw = yawOf(dir)
	-- (Islands stand at their own heights: it slopes from one to the next.)
	local pitch = math.atan2(to.Y - from.Y, length)
	local count = math.max(2, math.ceil(length / 12))
	local seg = (to - from).Magnitude / count
	for i = 1, count do
		local mid = from:Lerp(to, (i - 0.5) / count)
		local frame = CFrame.new(mid) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		part(
			model,
			frame
				* CFrame.new(0, -1.5 + rng:NextNumber(-0.15, 0.15), 0)
				* CFrame.Angles(0, rng:NextNumber(-0.04, 0.04), 0),
			Vector3.new(11 + rng:NextNumber(-1, 1), 3, seg + 1.2),
			BASALT,
			Enum.Material.Basalt,
			nil,
			true
		)
		-- (A lip of rock along each side, knee high.)
		for _, side in { -1, 1 } do
			part(
				model,
				frame * CFrame.new(side * 5.4, 0.6, 0),
				Vector3.new(1.2, 1.4 + rng:NextNumber(0, 0.6), seg + 0.4),
				UNDER,
				Enum.Material.Basalt,
				nil,
				true
			)
		end
		-- A rib arching over it, every other slab: a curve of bone pieces
		-- from one side over to the other.
		if i % 2 == 0 then
			local pieces = 9
			for k = 0, pieces - 1 do
				local t0, t1 = k / pieces * math.pi, (k + 1) / pieces * math.pi
				local p0 = Vector3.new(math.cos(t0) * 8, math.sin(t0) * 13, 0)
				local p1 = Vector3.new(math.cos(t1) * 8, math.sin(t1) * 13, 0)
				local m = (p0 + p1) / 2
				local span = p1 - p0
				part(
					model,
					frame * CFrame.new(m) * CFrame.Angles(0, 0, math.atan2(span.Y, span.X)),
					Vector3.new(span.Magnitude + 0.5, 1.1 - k * 0.04, 1.1),
					BONE,
					Enum.Material.SmoothPlastic
				)
			end
		end
	end
	return model
end

-- A wall of fire across the way out of a room, at `at` on its rim, facing `dir`.
local function gate(parent, at: Vector3, dir: Vector3, room: number)
	local model = Instance.new("Model")
	model.Name = "FireGate"
	model:SetAttribute("Room", room)
	model.Parent = parent
	local frame = CFrame.new(at) * CFrame.Angles(0, yawOf(dir), 0)
	-- (The barrier itself: a red heat-haze you can't pass, a curtain of
	-- flame tongues licking up in front of it.)
	local wall = part(model, frame * CFrame.new(0, 8, 0), Vector3.new(14, 16, 1.2), LAVA, Enum.Material.Neon, nil, true)
	wall.Name = "Wall"
	wall.Transparency = 0.78
	wall.CastShadow = false
	local inner = part(model, frame * CFrame.new(0, 7, -0.9), Vector3.new(12, 14, 0.4), EMBER, Enum.Material.Neon)
	inner.Name = "Glow"
	inner.Transparency = 0.85
	local tongues = { LAVA, EMBER, Color3.fromRGB(255, 200, 96) }
	for i = 0, 10 do
		local x = -6.2 + i * 1.24
		local tall = 7 + 7 * math.abs(math.sin(i * 1.7 + room)) + (if i % 3 == 0 then 2 else 0)
		local lick = part(
			model,
			frame * CFrame.new(x, tall / 2, -0.2 + (i % 2) * 0.4) * CFrame.Angles(0, 0, math.sin(i * 2.3) * 0.12),
			Vector3.new(0.7 + (i % 3) * 0.25, tall, 0.35),
			tongues[i % 3 + 1],
			Enum.Material.Neon
		)
		lick.Name = "Tongue"
		lick.Transparency = 0.2 + (i % 3) * 0.12
	end
	for i = -1, 1 do
		local base = part(model, frame * CFrame.new(i * 4.5, 0.5, 0), Vector3.new(1, 1, 1), LAVA, Enum.Material.Neon)
		base.Name = "Flame"
		base.Transparency = 1
		fire(base, 9, 16)
	end
	light(wall, EMBER, 30, 2.4)
	for _, side in { -1, 1 } do
		part(
			model,
			frame * CFrame.new(side * 8.5, 9, 0),
			Vector3.new(3, 18, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		part(
			model,
			frame * CFrame.new(side * 8.5, 19.5, 0) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
			Vector3.new(3, 4, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			"CornerWedge"
		)
	end
	return model
end

-- A way home: a ring of black shards stood round an opening of light, its
-- prompt on the opening (PromptKind "RiftExit").
local function wayHome(parent, frame: CFrame, open: boolean)
	local model = Instance.new("Model")
	model.Name = "WayHome"
	model.Parent = parent
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local at = frame * CFrame.new(math.cos(a) * 6.5, 7.5 + math.sin(a) * 6.5, 0)
		part(model, at * CFrame.Angles(0, 0, a), Vector3.new(3.2, 1.8, 1.6), OBSIDIAN, Enum.Material.Slate)
	end
	-- (A cylinder's round faces are its X ends: turned a quarter, they face
	-- the way the frame does.)
	local opening = part(
		model,
		frame * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.4, 11, 11),
		Color3.fromRGB(150, 210, 255),
		Enum.Material.Neon,
		"Cylinder"
	)
	opening.Name = "Opening"
	opening.Transparency = if open then 0.25 else 1
	opening.CanQuery = true
	light(opening, Color3.fromRGB(150, 210, 255), 24, if open then 2 else 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Leave"
	prompt.ActionText = "Go home"
	prompt.ObjectText = "THE WAY HOME"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = open
	prompt:SetAttribute("PromptKind", "RiftExit")
	prompt.Parent = opening
	return model, opening
end

function RiftWorld.build(id: string, origin: CFrame, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Rift_" .. id
	folder.Parent = workspace
	local base = origin.Position
	-- The islands: the landing, the rooms zig-zagging in, the boss's.
	local centers, radii = { base }, { 18 }
	for room = 1, RiftRun.Rooms do
		local side = if room % 2 == 1 then 1 else -1
		centers[room + 1] = base
			+ Vector3.new(side * rng:NextNumber(14, 28), rng:NextNumber(-2, 3), -RiftWorld.Spacing * room)
		radii[room + 1] = 27 + room
	end
	local bossAt = base + Vector3.new(0, 4, -RiftWorld.Spacing * RiftRun.Rooms - 108)
	table.insert(centers, bossAt)
	table.insert(radii, 46)
	for i, center in centers do
		local boss = i == #centers
		island(folder, center, radii[i], rng, {
			Horns = if boss then 0 elseif i == 1 then 2 else 3,
			Braziers = if boss then 0 elseif i == 1 then 2 else 3,
		})
		if i > 1 then
			causeway(folder, centers[i - 1], radii[i - 1], center, radii[i], rng)
		end
	end
	-- A wall of fire on the way out of each room.
	local gates = {}
	for room = 1, RiftRun.Rooms do
		local at, toward = centers[room + 1], centers[room + 2]
		local dir = flat(toward - at).Unit
		gates[room] = gate(folder, at + dir * (radii[room + 1] - 4), dir, room)
	end
	-- The boss's island: a ring of spires round it, an obsidian throne at
	-- the far side with fire either side, a scorched ring where it comes through.
	local arena = Instance.new("Model")
	arena.Name = "Throne"
	arena.Parent = folder
	for i = 1, 9 do
		local a = (i - 0.5) / 9 * math.pi * 2 + math.pi / 2
		if math.abs(math.sin(a) - 1) < 0.15 then
			continue -- (the way in stays open)
		end
		local at = bossAt + Vector3.new(math.cos(a), 0, -math.sin(a)) * 43
		local tall = rng:NextNumber(26, 44)
		part(
			arena,
			CFrame.new(at + Vector3.new(0, tall / 2, 0)) * CFrame.Angles(0, a, rng:NextNumber(-0.08, 0.08)),
			Vector3.new(4, tall, 4),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		glow(
			part(
				arena,
				CFrame.new(at + Vector3.new(0, tall * 0.55, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.05),
				Vector3.new(0.35, tall * 0.7, 0.1),
				LAVA
			)
		)
		part(
			arena,
			CFrame.new(at + Vector3.new(0, tall + 2.4, 0)) * CFrame.Angles(0, a, 0),
			Vector3.new(4, 5, 4),
			OBSIDIAN,
			Enum.Material.Slate,
			"CornerWedge"
		)
	end
	local throne = bossAt + Vector3.new(0, 0, -34)
	part(
		arena,
		CFrame.new(throne + Vector3.new(0, 2, 0)),
		Vector3.new(20, 4, 10),
		OBSIDIAN,
		Enum.Material.Slate,
		nil,
		true
	)
	part(
		arena,
		CFrame.new(throne + Vector3.new(0, 5, -2)),
		Vector3.new(14, 2.5, 6),
		OBSIDIAN,
		Enum.Material.Slate,
		nil,
		true
	)
	part(
		arena,
		CFrame.new(throne + Vector3.new(0, 14, -4.5)),
		Vector3.new(12, 18, 2.5),
		OBSIDIAN,
		Enum.Material.Slate,
		nil,
		true
	)
	local skull = part(
		arena,
		CFrame.new(throne + Vector3.new(0, 25, -4.5)),
		Vector3.new(7, 7, 7),
		BONE,
		Enum.Material.SmoothPlastic,
		"Ball"
	)
	for _, side in { -1, 1 } do
		glow(
			part(
				arena,
				CFrame.new(skull.CFrame.Position + Vector3.new(side * 1.5, 0.4, 3)),
				Vector3.new(1.4, 1.4, 1.4),
				BLOOD,
				nil,
				"Ball"
			)
		)
		local pillar = part(
			arena,
			CFrame.new(throne + Vector3.new(side * 13, 6, 0)),
			Vector3.new(3, 12, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		local top = part(
			arena,
			CFrame.new(throne + Vector3.new(side * 13, 12.3, 0)),
			Vector3.new(3.4, 0.6, 3.4),
			EMBER,
			Enum.Material.Neon
		)
		fire(top, 10, 20)
		light(pillar, EMBER, 40, 2.5)
	end
	glow(
		part(
			arena,
			CFrame.new(bossAt + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.1, 30, 30),
			BLOOD,
			nil,
			"Cylinder"
		)
	).Transparency =
		0.55
	part(
		arena,
		CFrame.new(bossAt + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.1, 27, 27),
		UNDER,
		Enum.Material.Basalt,
		"Cylinder"
	)
	-- The ways home: on the landing (open), and on the boss's island (shut
	-- till it's beaten).
	local _, exit = wayHome(folder, CFrame.new(base + Vector3.new(0, 0, 12)) * CFrame.Angles(0, math.pi, 0), true)
	local home = wayHome(folder, CFrame.new(throne + Vector3.new(0, 0, 14)), false)
	-- The lava sea: glowing, crusted over in patches, nothing to stand on.
	local length = RiftWorld.Spacing * RiftRun.Rooms + 260
	-- (Darker than the cracks' glow, and crusted over in places, so it
	-- smoulders rather than blinds.)
	local sea = glow(
		part(
			folder,
			CFrame.new(base + Vector3.new(0, -RiftWorld.Floor, -length / 2 + 60)),
			Vector3.new(900, 1, length + 500),
			Color3.fromRGB(196, 50, 16)
		)
	)
	sea.Name = "Lava"
	for _ = 1, 80 do
		local at = base
			+ Vector3.new(rng:NextNumber(-380, 380), -RiftWorld.Floor + 0.6, rng:NextNumber(-length - 160, 220))
		part(
			folder,
			CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Vector3.new(rng:NextNumber(16, 60), 0.8, rng:NextNumber(12, 44)),
			UNDER,
			Enum.Material.Basalt
		)
	end
	-- Black spires all round, and the blood moon over the throne.
	for i = 1, 22 do
		local side = if i % 2 == 0 then 1 else -1
		local z = -rng:NextNumber(-120, length + 140)
		local x = side * rng:NextNumber(110, 320)
		local tall = rng:NextNumber(90, 240)
		local w = rng:NextNumber(12, 30)
		part(
			folder,
			CFrame.new(base + Vector3.new(x, -RiftWorld.Floor + tall / 2, z))
				* CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, math.pi), rng:NextNumber(-0.06, 0.06)),
			Vector3.new(w, tall, w * 0.8),
			OBSIDIAN,
			Enum.Material.Slate
		)
		part(
			folder,
			CFrame.new(base + Vector3.new(x, -RiftWorld.Floor + tall + w * 0.6, z))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Vector3.new(w, w * 1.4, w * 0.8),
			OBSIDIAN,
			Enum.Material.Slate,
			"CornerWedge"
		)
	end
	local moon = glow(
		part(folder, CFrame.new(bossAt + Vector3.new(60, 230, -420)), Vector3.new(170, 170, 170), BLOOD, nil, "Ball")
	)
	moon.Name = "BloodMoon"
	moon.Transparency = 0.15
	-- Ash falling the whole way.
	local sky =
		part(folder, CFrame.new(base + Vector3.new(0, 70, -length / 2)), Vector3.new(260, 1, length + 120), UNDER)
	sky.Name = "Ash"
	sky.Transparency = 1
	local ash = Instance.new("ParticleEmitter")
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Rate = 70
	ash.Lifetime = NumberRange.new(8, 12)
	ash.Speed = NumberRange.new(4, 7)
	ash.SpreadAngle = Vector2.new(25, 25)
	ash.Size = NumberSequence.new(0.35)
	ash.Color = ColorSequence.new(Color3.fromRGB(110, 96, 92), EMBER)
	ash.LightEmission = 0.4
	ash.Parent = sky
	local rooms = {}
	for room = 1, RiftRun.Rooms do
		rooms[room] = { Center = centers[room + 1], Radius = radii[room + 1] }
	end
	return {
		Folder = folder,
		Origin = origin,
		Start = CFrame.new(base + Vector3.new(0, 3, 4)) * CFrame.Angles(0, yawOf(flat(centers[2] - base).Unit), 0),
		Rooms = rooms,
		Boss = { Center = bossAt, Radius = 46 },
		Gates = gates,
		Exit = exit,
		Home = home,
	}
end

function RiftWorld.openGate(gate: Model)
	for _, d in gate:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Glow" or d.Name == "Tongue") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Fire") or d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	gate:SetAttribute("Open", true)
end

function RiftWorld.openHome(world)
	local opening = world.Home:FindFirstChild("Opening")
	if opening then
		opening.Transparency = 0.25
		local l = opening:FindFirstChildOfClass("PointLight")
		if l then
			l.Brightness = 2
		end
		local prompt = opening:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
end

return RiftWorld
