--[[
	The Rift's world (Server.RiftServer runs a trip through it; the rules are
	Shared.RiftRun's): the critters' own side, built for one trip and gone
	with it. A pathway of caves on the pathway dungeon's grid
	(RiftRun.layout): the landing (and the way home) first, then
	RiftRun.Rooms caves, then the throne cave, joined by passages. Every
	cave and passage is walled in rock too tall to climb, its floor solid
	from wall to wall: there's nowhere to fall. The walls break into
	jagged crowns and overhanging ledges, arches of rock span the passages
	with fangs hanging from them, and above it all the roof is open to a
	burning sky with a scar torn across it. A wall of fire bars the way on
	out of each cave until it's cleared. (Each runner's client lights it:
	Client.RiftClient.)

	  RiftWorld.build(id, origin, rng) -> {
	      Folder, Origin (CFrame: the landing's middle, on its floor),
	      Start (CFrame: where you land, facing the way in),
	      Landing ({ Center, Radius, Size }),
	      Rooms ({ { Center (Vector3, on its floor), Radius, Size } }),
	      Boss ({ Center, Radius, Size }),
	      Gates ({ Model }: cave n's wall of fire, on the way out of it),
	      Exit (BasePart: the way home in the landing, its prompt "RiftExit"),
	      Home (Model: the way home in the throne cave, shut till it's beaten),
	  }
	  RiftWorld.inside(area, position, margin?)   on that cave's floor
	  RiftWorld.healRock(parent, at, rng) -> Model   a healing crystal (RiftRun.Heal)
	  RiftWorld.openGate(gate)     the fire dies down and the way's open
	  RiftWorld.openHome(world)    the way home in the throne cave opens
	  RiftWorld.Spacing, Landing, Cave, Throne, Passage, Wall, Thick: its
	      measures (studs: cell to cell, the caves' floors, a passage's
	      width, the walls' height and thickness)
]]
local RiftRun = require(game:GetService("ReplicatedStorage").Shared.RiftRun)

local RiftWorld = {}

RiftWorld.Spacing = 116
RiftWorld.Landing = 52
RiftWorld.Cave = 76
RiftWorld.Throne = 96
RiftWorld.Passage = 22
RiftWorld.Wall = 34
RiftWorld.Thick = 8

local BASALT = Color3.fromRGB(70, 54, 50)
local ROCK = Color3.fromRGB(96, 68, 58)
local UNDER = Color3.fromRGB(30, 24, 25)
local OBSIDIAN = Color3.fromRGB(24, 19, 24)
local BONE = Color3.fromRGB(214, 200, 172)
local LAVA = Color3.fromRGB(255, 78, 20)
local EMBER = Color3.fromRGB(255, 142, 46)
local BLOOD = Color3.fromRGB(150, 26, 20)
local SCAR = Color3.fromRGB(255, 220, 236)
local UP = Vector3.new(0, 1, 0)

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

-- A frame at `at`, its front (-Z) along `dir` across the ground. (Not
-- CFrame.lookAt: lune's, which the tests build the Rift with, turns the
-- other way along Z.)
local function face(at: Vector3, dir: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, yawOf(dir), 0)
end

-- Square to the grid: the step from one cell to the next (or a cave's side).
local function key(dir: Vector3): string
	return math.round(dir.X) .. ":" .. math.round(dir.Z)
end

-- A rock face along the floor's edge from `a` to `b`, standing outside it
-- (`inward` points into the cave): a solid slab Wall tall, so nobody climbs
-- or sees out; boulders leaning on its inner side so it reads as rock and
-- not a fence; jagged crowns along its top, now and then a ledge jutting
-- in over the floor (the cave's lip); and a seam of glowing rock down it.
local function rockFace(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
	local length = (b - a).Magnitude
	if length < 2 then
		return
	end
	local along = (b - a).Unit
	local tall, thick = RiftWorld.Wall, RiftWorld.Thick
	local mid = (a + b) / 2 - inward * thick / 2
	local frame = face(mid, along)
	part(
		parent,
		frame * CFrame.new(0, tall / 2, 0),
		Vector3.new(thick, tall, length + thick),
		ROCK,
		Enum.Material.Slate,
		nil,
		true
	).Name =
		"RockWall"
	-- (Its boulders: heaped at its foot, half sunk into it, never far out
	-- over the floor.)
	for _ = 1, math.max(1, math.floor(length / 11)) do
		local s = rng:NextNumber(5, 11)
		local at = a:Lerp(b, rng:NextNumber(0.08, 0.92)) + inward * rng:NextNumber(-1.5, 0.5) + UP * s * 0.35
		part(
			parent,
			CFrame.new(at)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.1)),
			if rng:NextNumber() < 0.5 then BASALT else ROCK,
			Enum.Material.Slate,
			nil,
			true
		)
	end
	-- (Its crowns, leaning in over the cave.)
	for _ = 1, math.max(1, math.floor(length / 14)) do
		local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * thick * 0.4
		local high = rng:NextNumber(6, 16)
		part(
			parent,
			face(at + UP * (tall + high / 2 - 1), -inward)
				* CFrame.Angles(rng:NextNumber(-0.25, -0.05), 0, rng:NextNumber(-0.15, 0.15)),
			Vector3.new(rng:NextNumber(5, 9), high, rng:NextNumber(5, 8)),
			OBSIDIAN,
			Enum.Material.Slate,
			"Wedge"
		)
	end
	if ledges and length > 30 and rng:NextNumber() < 0.7 then
		local span = length * rng:NextNumber(0.35, 0.6)
		local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (tall - 2.5)
		part(
			parent,
			face(at + inward * 5, along) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)),
			Vector3.new(12, 4, span),
			BASALT,
			Enum.Material.Slate
		).Name =
			"Ledge"
	end
	-- (Now and then a seam of glowing rock down it, low, where the cracks run in.)
	if rng:NextNumber() < 0.5 then
		local top = a:Lerp(b, rng:NextNumber(0.2, 0.8)) + inward * 0.05
		local drop = rng:NextNumber(5, 9)
		local seam = glow(
			part(
				parent,
				face(top + UP * drop / 2, along) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0),
				Vector3.new(0.4, drop, 1.2),
				LAVA
			)
		)
		seam.Name = "Seam"
		seam.Transparency = 0.3
	end
end

-- A brazier: a bowl of fire on a short stem.
local function brazier(parent, at: Vector3)
	part(parent, CFrame.new(at + UP * 1.8), Vector3.new(1.4, 3.6, 1.4), OBSIDIAN, Enum.Material.Slate, nil, true)
	local bowl = part(
		parent,
		CFrame.new(at + UP * 3.9) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1.2, 4, 4),
		OBSIDIAN,
		Enum.Material.Slate,
		"Cylinder",
		true
	)
	bowl.Name = "Brazier"
	local coals = glow(part(parent, CFrame.new(at + UP * 4.55), Vector3.new(3, 0.3, 3), EMBER))
	fire(coals, 6, 10)
	light(coals, EMBER, 36, 2.2)
end

-- A stalagmite: three blocks narrowing upward, leaning a little.
local function stalagmite(parent, at: Vector3, high: number, rng)
	local frame = CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 6), 0)
	local w = high * 0.32
	for i = 1, 3 do
		local seg = high / 3
		frame = frame * CFrame.new(0, seg / 2, 0)
		part(
			parent,
			frame,
			Vector3.new(w * (1.2 - i * 0.3), seg + 0.4, w * (1.1 - i * 0.28)),
			if i == 3 then OBSIDIAN else BASALT,
			Enum.Material.Slate,
			nil,
			i == 1
		)
		frame = frame * CFrame.new(0, seg / 2, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, 0)
	end
end

local SIDES = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }

-- A cave: a solid floor with cracks glowing in it, a rock face along each
-- side but the way(s) in and out (`doors`: the sides, by key), a column of
-- rock in each corner, braziers inside the corners and stalagmites by the
-- walls (clear of the doors: the floor's middle is for fighting).
local function cave(parent, center: Vector3, size: number, doors: { [string]: boolean }, rng)
	local model = Instance.new("Model")
	model.Name = "Cave"
	model.Parent = parent
	local half = size / 2
	part(
		model,
		CFrame.new(center - UP * 2),
		Vector3.new(size + 2, 4, size + 2),
		BASALT,
		Enum.Material.Basalt,
		nil,
		true
	).Name =
		"Floor"
	for _ = 1, math.floor(size / 9) do
		local at = center + Vector3.new(rng:NextNumber(-half + 4, half - 4), 0.03, rng:NextNumber(-half + 4, half - 4))
		local crack = glow(
			part(
				model,
				CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Vector3.new(rng:NextNumber(0.3, 0.7), 0.06, rng:NextNumber(5, 14)),
				LAVA
			)
		)
		crack.Name = "Crack"
		crack.Transparency = 0.2
	end
	local gap = RiftWorld.Passage + 2
	for _, d in SIDES do
		local edge = center + d * half
		local side = Vector3.new(-d.Z, 0, d.X)
		local a, b = edge - side * half, edge + side * half
		if doors[key(d)] then
			rockFace(model, a, edge - side * gap / 2, -d, rng, false)
			rockFace(model, edge + side * gap / 2, b, -d, rng, false)
		else
			rockFace(model, a, b, -d, rng, true)
		end
	end
	local thick, tall = RiftWorld.Thick, RiftWorld.Wall
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local corner = center + Vector3.new(c[1], 0, c[2]) * (half + thick / 2)
		part(
			model,
			CFrame.new(corner + UP * (tall / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Vector3.new(thick + 3, tall + 6, thick + 3),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		brazier(model, center + Vector3.new(c[1], 0, c[2]) * (half - 6))
	end
	for _, d in SIDES do
		if not doors[key(d)] then
			local side = Vector3.new(-d.Z, 0, d.X)
			for _, s in { -1, 1 } do
				local at = center + d * (half - 4) + side * s * rng:NextNumber(half * 0.3, half * 0.6)
				stalagmite(model, at, rng:NextNumber(6, 13), rng)
			end
		end
	end
	return model
end

-- A passage from one cave's door (`from`) to the next's (`to`): its floor,
-- a rock face each side, and an arch of rock across it with fangs hanging
-- from it (the cave closing in over your head, high enough to fight under).
local function passage(parent, from: Vector3, to: Vector3, rng)
	local model = Instance.new("Model")
	model.Name = "Passage"
	model.Parent = parent
	local dir = flat(to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local width = RiftWorld.Passage
	local side = Vector3.new(-dir.Z, 0, dir.X)
	part(model, face(mid - UP * 2, dir), Vector3.new(width + 2, 4, length + 4), BASALT, Enum.Material.Basalt, nil, true).Name =
		"Floor"
	rockFace(model, from + side * width / 2, to + side * width / 2, -side, rng, false)
	rockFace(model, from - side * width / 2, to - side * width / 2, side, rng, false)
	local tall = RiftWorld.Wall
	local arch = face(mid + UP * (tall - 3), side)
	part(model, arch, Vector3.new(14, 7, width + RiftWorld.Thick * 2 + 6), BASALT, Enum.Material.Slate).Name = "Arch"
	for i = 1, 5 do
		local across = (i - 3) * width / 5 + rng:NextNumber(-1, 1)
		local long = rng:NextNumber(4, 9)
		part(
			model,
			CFrame.new(mid + side * across + dir * rng:NextNumber(-4, 4) + UP * (tall - 6.5 - long / 2))
				* CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0),
			Vector3.new(2.2, long, 2.2),
			OBSIDIAN,
			Enum.Material.Slate,
			"Wedge"
		).Name =
			"Fang"
	end
	return model
end

-- A wall of fire across a passage (`dir`: the way on): a red heat-haze you
-- can't pass, a curtain of flame tongues licking up in front of it, and a
-- column of obsidian either side.
local function gate(parent, at: Vector3, dir: Vector3, room: number)
	local model = Instance.new("Model")
	model.Name = "FireGate"
	model:SetAttribute("Room", room)
	model.Parent = parent
	local frame = CFrame.new(at) * CFrame.Angles(0, yawOf(dir), 0)
	local width = RiftWorld.Passage
	local wall =
		part(model, frame * CFrame.new(0, 9, 0), Vector3.new(width, 18, 1.2), LAVA, Enum.Material.Neon, nil, true)
	wall.Name = "Wall"
	wall.Transparency = 0.78
	wall.CastShadow = false
	local inner =
		part(model, frame * CFrame.new(0, 8, -0.9), Vector3.new(width - 2, 16, 0.4), EMBER, Enum.Material.Neon)
	inner.Name = "Glow"
	inner.Transparency = 0.85
	local tongues = { LAVA, EMBER, Color3.fromRGB(255, 200, 96) }
	local count = math.floor(width / 1.3)
	for i = 0, count - 1 do
		local x = -width / 2 + 0.8 + i * (width - 1.6) / (count - 1)
		local tall = 7 + 8 * math.abs(math.sin(i * 1.7 + room)) + (if i % 3 == 0 then 2 else 0)
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
		local base = part(model, frame * CFrame.new(i * 6.5, 0.5, 0), Vector3.new(1, 1, 1), LAVA, Enum.Material.Neon)
		base.Name = "Flame"
		base.Transparency = 1
		fire(base, 9, 16)
	end
	light(wall, EMBER, 34, 2.4)
	for _, s in { -1, 1 } do
		part(
			model,
			frame * CFrame.new(s * (width / 2 + 1.5), 10, 0),
			Vector3.new(3, 20, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		part(
			model,
			frame * CFrame.new(s * (width / 2 + 1.5), 22, 0) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0),
			Vector3.new(3, 4, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			"CornerWedge"
		)
	end
	return model
end

-- A way home: a ring of black shards stood round an opening of light, its
-- prompt on the opening (PromptKind "RiftExit"). It faces the way `frame`
-- does.
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

-- The throne at the far end of the throne cave (`facing`: toward the way
-- in): a dais of obsidian, its back stood tall with a skull over it, fire
-- either side, and the scorched ring in the middle where the boss comes
-- through.
local function throne(parent, center: Vector3, facing: Vector3, size: number)
	local model = Instance.new("Model")
	model.Name = "Throne"
	model.Parent = parent
	local seat = center - facing * (size / 2 - 12)
	local frame = face(seat, facing)
	part(model, frame * CFrame.new(0, 2, 0), Vector3.new(20, 4, 10), OBSIDIAN, Enum.Material.Slate, nil, true)
	part(model, frame * CFrame.new(0, 5, 2), Vector3.new(14, 2.5, 6), OBSIDIAN, Enum.Material.Slate, nil, true)
	part(model, frame * CFrame.new(0, 14, 4.5), Vector3.new(12, 18, 2.5), OBSIDIAN, Enum.Material.Slate, nil, true)
	local skull =
		part(model, frame * CFrame.new(0, 25, 4.5), Vector3.new(7, 7, 7), BONE, Enum.Material.SmoothPlastic, "Ball")
	skull.Name = "Skull"
	for _, s in { -1, 1 } do
		glow(part(model, frame * CFrame.new(s * 1.5, 25.4, 1.5), Vector3.new(1.4, 1.4, 1.4), BLOOD, nil, "Ball"))
		local pillar = part(
			model,
			frame * CFrame.new(s * 13, 6, 0),
			Vector3.new(3, 12, 3),
			OBSIDIAN,
			Enum.Material.Slate,
			nil,
			true
		)
		local top =
			part(model, frame * CFrame.new(s * 13, 12.3, 0), Vector3.new(3.4, 0.6, 3.4), EMBER, Enum.Material.Neon)
		fire(top, 10, 20)
		light(pillar, EMBER, 44, 2.5)
	end
	local ring = glow(
		part(
			model,
			CFrame.new(center + UP * 0.05) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.1, 30, 30),
			BLOOD,
			nil,
			"Cylinder"
		)
	)
	ring.Transparency = 0.55
	part(
		model,
		CFrame.new(center + UP * 0.08) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.1, 27, 27),
		UNDER,
		Enum.Material.Basalt,
		"Cylinder"
	)
	return model, seat, frame
end

-- The sky over it all (each client lights the air: RiftClient): a scar torn
-- right across it, white-hot down the middle and bleeding red at its edges,
-- with strands torn off it; banks of black cloud round the edges, lit red
-- from below; ash falling the whole way.
local function sky(parent, center: Vector3, span: number, rng)
	local model = Instance.new("Model")
	model.Name = "Sky"
	model.Parent = parent
	local high = center + UP * 260
	local heading = rng:NextNumber(0, math.pi)
	local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local length = span * 1.5
	local points = {}
	for i = 0, 10 do
		local t = i / 10
		local wobble = if i == 0 or i == 10 then 0 else rng:NextNumber(-1, 1) * 28
		table.insert(points, high + dir * (t - 0.5) * length + side * wobble + UP * rng:NextNumber(-12, 12))
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local t = math.abs((i - 0.5) / (#points - 1) - 0.5) * 2
		local width = 4 + 12 * (1 - t)
		local frame = face(mid, flat(b - a))
		local rim = glow(part(model, frame, Vector3.new(width * 1.9, 3, (b - a).Magnitude + 3), BLOOD))
		rim.Name = "ScarRim"
		rim.Transparency = 0.35
		glow(part(model, frame, Vector3.new(width, 4, (b - a).Magnitude + 2), SCAR)).Name = "Scar"
		if i % 3 == 0 then
			local strand = mid + side * (if i % 2 == 0 then 1 else -1) * rng:NextNumber(30, 60)
			glow(
				part(
					model,
					face((mid + strand) / 2, flat(strand - mid)),
					Vector3.new(2, 2, (strand - mid).Magnitude),
					Color3.fromRGB(255, 120, 150)
				)
			).Name =
				"Strand"
		end
	end
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = span * rng:NextNumber(0.7, 0.95)
		local at = center + Vector3.new(math.cos(a) * r, rng:NextNumber(150, 210), math.sin(a) * r)
		local cloud = part(
			model,
			CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(rng:NextNumber(16, 26), rng:NextNumber(120, 210), rng:NextNumber(120, 210)),
			Color3.fromRGB(46, 16, 18),
			Enum.Material.SmoothPlastic,
			"Cylinder"
		)
		cloud.Name = "Cloud"
		cloud.Transparency = 0.2
		local under = glow(
			part(
				model,
				CFrame.new(at - UP * 9) * CFrame.Angles(0, 0, math.pi / 2),
				Vector3.new(1, cloud.Size.Y * 0.8, cloud.Size.Z * 0.8),
				Color3.fromRGB(160, 40, 24),
				nil,
				"Cylinder"
			)
		)
		under.Transparency = 0.6
	end
	local ashFrom = part(model, CFrame.new(center + UP * 70), Vector3.new(span, 1, span), UNDER)
	ashFrom.Name = "Ash"
	ashFrom.Transparency = 1
	local ash = Instance.new("ParticleEmitter")
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Rate = 70
	ash.Lifetime = NumberRange.new(8, 12)
	ash.Speed = NumberRange.new(4, 7)
	ash.SpreadAngle = Vector2.new(25, 25)
	ash.Size = NumberSequence.new(0.35)
	ash.Color = ColorSequence.new(Color3.fromRGB(110, 96, 92), EMBER)
	ash.LightEmission = 0.4
	ash.Parent = ashFrom
	return model
end

function RiftWorld.build(id: string, origin: CFrame, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Rift_" .. id
	folder.Parent = workspace
	local base = origin.Position
	local cells = RiftRun.layout(rng)
	local spacing = RiftWorld.Spacing
	local centers, sizes = {}, {}
	for i, cell in cells do
		centers[i] = base + Vector3.new(cell.X * spacing, 0, cell.Z * spacing)
		sizes[i] = if i == 1 then RiftWorld.Landing elseif i == #cells then RiftWorld.Throne else RiftWorld.Cave
	end
	-- The caves, each open toward the one before it and the one after.
	for i, center in centers do
		local doors = {}
		for _, j in { i - 1, i + 1 } do
			if centers[j] then
				doors[key(flat(centers[j] - center).Unit)] = true
			end
		end
		cave(folder, center, sizes[i], doors, rng)
	end
	-- The passages, and a wall of fire across each one out of a cave.
	local gates = {}
	for i = 1, #centers - 1 do
		local dir = flat(centers[i + 1] - centers[i]).Unit
		local from, to = centers[i] + dir * sizes[i] / 2, centers[i + 1] - dir * sizes[i + 1] / 2
		passage(folder, from, to, rng)
		if i > 1 then
			gates[i - 1] = gate(folder, (from + to) / 2, dir, i - 1)
		end
	end
	-- The landing: the way home stood against its back wall, facing in.
	local landing = centers[1]
	local ahead = flat(centers[2] - landing).Unit
	local back = landing - ahead * (RiftWorld.Landing / 2 - 3)
	local _, exit = wayHome(folder, face(back, ahead), true)
	-- The throne cave: the throne at its far end, the way home beside it.
	local last = #centers
	local bossAt = centers[last]
	local facing = -flat(centers[last] - centers[last - 1]).Unit
	local _, seat, seatFrame = throne(folder, bossAt, facing, RiftWorld.Throne)
	local beside = seat + seatFrame.RightVector * 22
	local home = wayHome(folder, face(beside, facing), false)
	-- The sky, over the middle of it all.
	local lo, hi = centers[1], centers[1]
	for _, c in centers do
		lo = Vector3.new(math.min(lo.X, c.X), base.Y, math.min(lo.Z, c.Z))
		hi = Vector3.new(math.max(hi.X, c.X), base.Y, math.max(hi.Z, c.Z))
	end
	sky(folder, (lo + hi) / 2, math.max(hi.X - lo.X, hi.Z - lo.Z) + 300, rng)
	local rooms = {}
	for room = 1, RiftRun.Rooms do
		rooms[room] = { Center = centers[room + 1], Radius = RiftWorld.Cave / 2 + 4, Size = RiftWorld.Cave }
	end
	return {
		Folder = folder,
		Origin = origin,
		Start = face(landing + ahead * 4 + UP * 3, ahead),
		Landing = { Center = landing, Radius = RiftWorld.Landing / 2 + 4, Size = RiftWorld.Landing },
		Rooms = rooms,
		Boss = { Center = bossAt, Radius = RiftWorld.Throne / 2 + 4, Size = RiftWorld.Throne },
		Gates = gates,
		Exit = exit,
		Home = home,
	}
end

-- A healing crystal (RiftRun.Heal: mined with the pick for health, never
-- gems): a squat dark rock at `at` (on the floor), green crystals growing
-- out of it, glowing softly. Its body is its PrimaryPart ("Body"), its
-- crystals "Crystal" (the client chips them in their colour).
RiftWorld.HealGreen = Color3.fromRGB(70, 240, 95)
function RiftWorld.healRock(parent: Instance, at: Vector3, rng): Model
	local model = Instance.new("Model")
	model.Name = "HealCrystal"
	local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = CFrame.new(at) * spin
	local body =
		part(model, base * CFrame.new(0, 1.6, 0), Vector3.new(5.2, 3.2, 4.6), OBSIDIAN, Enum.Material.Basalt, nil, true)
	body.Name = "Body"
	model.PrimaryPart = body
	local cap = part(
		model,
		base * CFrame.new(0.6, 3.2, -0.3) * CFrame.Angles(0.2, 0.5, 0.15),
		Vector3.new(3.4, 1.6, 3),
		ROCK,
		Enum.Material.Basalt,
		nil,
		true
	)
	cap.Name = "Cap"
	for i = 1, 5 do
		local tall = rng:NextNumber(2.2, 4.4)
		local lean = CFrame.Angles(rng:NextNumber(-0.45, 0.45), 0, rng:NextNumber(-0.45, 0.45))
		local spot = Vector3.new(rng:NextNumber(-1.8, 1.8), 2.6 + tall / 2, rng:NextNumber(-1.6, 1.6))
		local crystal = glow(
			part(
				model,
				base * CFrame.new(spot) * lean * CFrame.Angles(0, i, 0),
				Vector3.new(rng:NextNumber(0.6, 1.1), tall, rng:NextNumber(0.6, 1.1)),
				RiftWorld.HealGreen
			)
		)
		crystal.Name = "Crystal"
		crystal.Transparency = 0.12
	end
	local light = Instance.new("PointLight")
	light.Color = RiftWorld.HealGreen
	light.Range = 12
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = body
	model.Parent = parent
	return model
end

-- On `area`'s floor (a cave: { Center, Size }), `margin` studs of slack.
function RiftWorld.inside(area, position: Vector3, margin: number?): boolean
	local offset = position - area.Center
	local half = area.Size / 2 + (margin or 0)
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y > -12 and offset.Y < 60
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
