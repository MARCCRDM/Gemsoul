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

	All of it is built in the boss's realm (Shared.RiftRealms: its
	colours, its sky, what falls from it, the fire's colour), with the
	realm's own set pieces stood by the walls of every cave
	(RiftWorld.Features: craters and dud bombs, charred logs, frozen
	ponds, a frozen tide, the freezer's blocks, charged vines, static
	spires, blades, bog pools, a rotting grove). No two bosses' trips look
	alike.

	  RiftWorld.build(id, origin, rng, realm?) -> {
	      Folder, Origin (CFrame: the landing's middle, on its floor),
	      Start (CFrame: where you land, facing the way in),
	      Landing ({ Center, Radius, Size }),
	      Rooms ({ { Center (Vector3, on its floor), Radius, Size } }),
	      Boss ({ Center, Radius, Size }),
	      Gates ({ Model }: cave n's wall of fire, on the way out of it;
	          its "Into" attribute a spot a little way into the next cave),
	      Exit (BasePart: the way home in the landing, its prompt "RiftExit"),
	      Home (Model: the way home in the throne cave, shut till it's beaten),
	  }
	  RiftWorld.inside(area, position, margin?)   on that cave's floor
	  RiftWorld.healRock(parent, at, rng) -> Model   a healing crystal (RiftRun.Heal)
	  (and what's left of the crews who came before, by the walls and
	  heaped by the throne: Server.World.FallenMiners)
	  RiftWorld.openGate(gate)     the fire dies down and the way's open
	  RiftWorld.openHome(world)    the way home in the throne cave opens
	  RiftWorld.Spacing, Landing, Cave, Throne, Passage, Wall, Thick: its
	      measures (studs: cell to cell, the caves' floors, a passage's
	      width, the walls' height and thickness)
	  RiftWorld.Features[name](model, center, size, doors, rng)   a realm's
	      set pieces in one cave
]]
local RiftRun = require(game:GetService("ReplicatedStorage").Shared.RiftRun)
local RiftRealms = require(game:GetService("ReplicatedStorage").Shared.RiftRealms)
local FallenMiners = require(script.Parent.FallenMiners)

local RiftWorld = {}

RiftWorld.Spacing = 116
RiftWorld.Landing = 52
RiftWorld.Cave = 76
RiftWorld.Throne = 96
RiftWorld.Passage = 22
RiftWorld.Wall = 34
RiftWorld.Thick = 8

-- The realm being built (RiftRealms): its colours. `build` sets it.
local P = RiftRealms.Default
local BONE = Color3.fromRGB(214, 200, 172)
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
	f.Color = P.Flame
	f.SecondaryColor = P.FlameEdge
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
		P.Rock,
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
			if rng:NextNumber() < 0.5 then P.Basalt else P.Rock,
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
			P.Obsidian,
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
			P.Basalt,
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
				P.Glow
			)
		)
		seam.Name = "Seam"
		seam.Transparency = 0.3
	end
end

-- A brazier: a bowl of fire on a short stem.
local function brazier(parent, at: Vector3)
	part(parent, CFrame.new(at + UP * 1.8), Vector3.new(1.4, 3.6, 1.4), P.Obsidian, Enum.Material.Slate, nil, true)
	local bowl = part(
		parent,
		CFrame.new(at + UP * 3.9) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(1.2, 4, 4),
		P.Obsidian,
		Enum.Material.Slate,
		"Cylinder",
		true
	)
	bowl.Name = "Brazier"
	local coals = glow(part(parent, CFrame.new(at + UP * 4.55), Vector3.new(3, 0.3, 3), P.Accent))
	fire(coals, 6, 10)
	light(coals, P.Accent, 36, 2.2)
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
			if i == 3 then P.Obsidian else P.Basalt,
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
		P.Basalt,
		Enum.Material[P.FloorMaterial] or Enum.Material.Basalt,
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
				P.Glow
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
			P.Obsidian,
			Enum.Material.Slate,
			nil,
			true
		)
		brazier(model, center + Vector3.new(c[1], 0, c[2]) * (half - 6))
	end
	if P.Stalagmites then
		for _, d in SIDES do
			if not doors[key(d)] then
				local side = Vector3.new(-d.Z, 0, d.X)
				for _, s in { -1, 1 } do
					local at = center + d * (half - 4) + side * s * rng:NextNumber(half * 0.3, half * 0.6)
					stalagmite(model, at, rng:NextNumber(6, 13), rng)
				end
			end
		end
	end
	local feature = RiftWorld.Features[P.Feature]
	if feature then
		feature(model, center, size, doors, rng)
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
	part(
		model,
		face(mid - UP * 2, dir),
		Vector3.new(width + 2, 4, length + 4),
		P.Basalt,
		Enum.Material[P.FloorMaterial] or Enum.Material.Basalt,
		nil,
		true
	).Name =
		"Floor"
	rockFace(model, from + side * width / 2, to + side * width / 2, -side, rng, false)
	rockFace(model, from - side * width / 2, to - side * width / 2, side, rng, false)
	local tall = RiftWorld.Wall
	local arch = face(mid + UP * (tall - 3), side)
	part(model, arch, Vector3.new(14, 7, width + RiftWorld.Thick * 2 + 6), P.Basalt, Enum.Material.Slate).Name = "Arch"
	for i = 1, 5 do
		local across = (i - 3) * width / 5 + rng:NextNumber(-1, 1)
		local long = rng:NextNumber(4, 9)
		part(
			model,
			CFrame.new(mid + side * across + dir * rng:NextNumber(-4, 4) + UP * (tall - 6.5 - long / 2))
				* CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0),
			Vector3.new(2.2, long, 2.2),
			P.Obsidian,
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
		part(model, frame * CFrame.new(0, 9, 0), Vector3.new(width, 18, 1.2), P.Glow, Enum.Material.Neon, nil, true)
	wall.Name = "Wall"
	wall.Transparency = 0.78
	wall.CastShadow = false
	local inner =
		part(model, frame * CFrame.new(0, 8, -0.9), Vector3.new(width - 2, 16, 0.4), P.Accent, Enum.Material.Neon)
	inner.Name = "Glow"
	inner.Transparency = 0.85
	local tongues = { P.Glow, P.Accent, P.Tongue }
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
		local base = part(model, frame * CFrame.new(i * 6.5, 0.5, 0), Vector3.new(1, 1, 1), P.Glow, Enum.Material.Neon)
		base.Name = "Flame"
		base.Transparency = 1
		fire(base, 9, 16)
	end
	light(wall, P.Accent, 34, 2.4)
	for _, s in { -1, 1 } do
		part(
			model,
			frame * CFrame.new(s * (width / 2 + 1.5), 10, 0),
			Vector3.new(3, 20, 3),
			P.Obsidian,
			Enum.Material.Slate,
			nil,
			true
		)
		part(
			model,
			frame * CFrame.new(s * (width / 2 + 1.5), 22, 0) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0),
			Vector3.new(3, 4, 3),
			P.Obsidian,
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
		part(model, at * CFrame.Angles(0, 0, a), Vector3.new(3.2, 1.8, 1.6), P.Obsidian, Enum.Material.Slate)
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
	part(model, frame * CFrame.new(0, 2, 0), Vector3.new(20, 4, 10), P.Obsidian, Enum.Material.Slate, nil, true)
	part(model, frame * CFrame.new(0, 5, 2), Vector3.new(14, 2.5, 6), P.Obsidian, Enum.Material.Slate, nil, true)
	part(model, frame * CFrame.new(0, 14, 4.5), Vector3.new(12, 18, 2.5), P.Obsidian, Enum.Material.Slate, nil, true)
	local skull =
		part(model, frame * CFrame.new(0, 25, 4.5), Vector3.new(7, 7, 7), BONE, Enum.Material.SmoothPlastic, "Ball")
	skull.Name = "Skull"
	for _, s in { -1, 1 } do
		glow(part(model, frame * CFrame.new(s * 1.5, 25.4, 1.5), Vector3.new(1.4, 1.4, 1.4), P.Dark, nil, "Ball"))
		local pillar = part(
			model,
			frame * CFrame.new(s * 13, 6, 0),
			Vector3.new(3, 12, 3),
			P.Obsidian,
			Enum.Material.Slate,
			nil,
			true
		)
		local top =
			part(model, frame * CFrame.new(s * 13, 12.3, 0), Vector3.new(3.4, 0.6, 3.4), P.Accent, Enum.Material.Neon)
		fire(top, 10, 20)
		light(pillar, P.Accent, 44, 2.5)
	end
	local ring = glow(
		part(
			model,
			CFrame.new(center + UP * 0.05) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.1, 30, 30),
			P.Dark,
			nil,
			"Cylinder"
		)
	)
	ring.Transparency = 0.55
	part(
		model,
		CFrame.new(center + UP * 0.08) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.1, 27, 27),
		P.Under,
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
		local rim = glow(part(model, frame, Vector3.new(width * 1.9, 3, (b - a).Magnitude + 3), P.Dark))
		rim.Name = "ScarRim"
		rim.Transparency = 0.35
		glow(part(model, frame, Vector3.new(width, 4, (b - a).Magnitude + 2), P.Scar)).Name = "Scar"
		if i % 3 == 0 then
			local strand = mid + side * (if i % 2 == 0 then 1 else -1) * rng:NextNumber(30, 60)
			glow(
				part(
					model,
					face((mid + strand) / 2, flat(strand - mid)),
					Vector3.new(2, 2, (strand - mid).Magnitude),
					P.Strand
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
			P.Cloud,
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
				P.CloudUnder,
				nil,
				"Cylinder"
			)
		)
		under.Transparency = 0.6
	end
	local ashFrom = part(model, CFrame.new(center + UP * 70), Vector3.new(span, 1, span), P.Under)
	ashFrom.Name = "Ash"
	ashFrom.Transparency = 1
	local ash = Instance.new("ParticleEmitter")
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Rate = P.Ash.Rate
	ash.Lifetime = NumberRange.new(8, 12)
	ash.Speed = NumberRange.new(P.Ash.Speed * 0.75, P.Ash.Speed * 1.25)
	ash.SpreadAngle = Vector2.new(25, 25)
	ash.Size = NumberSequence.new(P.Ash.Size)
	ash.Color = ColorSequence.new(P.Ash.From, P.Ash.To)
	ash.LightEmission = 0.4
	ash.Parent = ashFrom
	return model
end

-- The realms' set pieces -----------------------------------------------------------------------------------------
-- Each stands by a cave's walls (clear of the doors and of the floor's
-- middle, which is for fighting), in the realm's colours.

-- Spots by the walls: `count` of them, each { At, In (into the cave),
-- Along (along its wall), Reach (how far in from it a piece may stand and
-- leave the floor's middle clear, 16 studs round its centre) }, off the
-- doors.
local function wallSpots(center: Vector3, half: number, doors, rng, count: number)
	local spots = {}
	local gap = RiftWorld.Passage / 2 + 7
	local reach = math.max(0, half - 6 - 17)
	local i = 0
	while #spots < count and i < 24 do
		i += 1
		local d = SIDES[(i - 1) % 4 + 1]
		local side = Vector3.new(-d.Z, 0, d.X)
		local s = if i % 8 < 4 then 1 else -1
		local along
		if doors[key(d)] then
			along = s * rng:NextNumber(gap, half - 7)
		else
			along = s * rng:NextNumber(half * 0.15, half - 7)
		end
		table.insert(spots, { At = center + d * (half - 6) + side * along, In = -d, Along = side, Reach = reach })
	end
	return spots
end

local function cylinder(parent, at: Vector3, radius: number, length: number, color: Color3, material, solid: boolean?, lean: CFrame?)
	-- (A cylinder's axis is X: stood up, it's turned a quarter.)
	return part(
		parent,
		CFrame.new(at) * (lean or CFrame.identity) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(length, radius * 2, radius * 2),
		color,
		material,
		"Cylinder",
		solid
	)
end

local function disc(parent, at: Vector3, radius: number, thick: number, color: Color3, material)
	return part(
		parent,
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(thick, radius * 2, radius * 2),
		color,
		material,
		"Cylinder"
	)
end

RiftWorld.Features = {}

-- Drago's crater flats: shallow craters ringed with rubble, their floors
-- still glowing, and the dud bombs that made them nose-down in the ground.
RiftWorld.Features.Craters = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	for n, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(5, spot.Reach)
		local r = rng:NextNumber(5, 7.5)
		local floor = glow(disc(model, at + UP * 0.08, r, 0.16, P.Dark))
		floor.Name = "Crater"
		floor.Transparency = 0.45
		light(floor, P.Glow, 16, 0.8)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local sz = rng:NextNumber(1.8, 3.4)
			part(
				model,
				CFrame.new(at + Vector3.new(math.cos(a) * r, sz * 0.3, math.sin(a) * r))
					* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)),
				Vector3.new(sz, sz * 0.7, sz * 0.8),
				if i % 2 == 0 then P.Rock else P.Basalt,
				Enum.Material.Slate
			)
		end
		if n < 3 then
			-- A dud bomb, nose down, its fins up.
			local iron = Color3.fromRGB(62, 58, 64)
			local lean = CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.Angles(0.95, 0, 0)
			local body = cylinder(model, at + UP * 2.6, 1.1, 6, iron, Enum.Material.Metal, true, lean)
			body.Name = "DudBomb"
			part(model, body.CFrame * CFrame.new(-3.2, 0, 0), Vector3.new(1.8, 1.8, 1.8), iron, Enum.Material.Metal, "Ball")
			for f = 1, 3 do
				part(
					model,
					body.CFrame * CFrame.new(2.6, 0, 0) * CFrame.Angles(f * math.pi * 2 / 3, 0, 0) * CFrame.new(0, 1.3, 0),
					Vector3.new(1.6, 1.4, 0.15),
					P.Dark,
					Enum.Material.Metal
				)
			end
		end
	end
end

-- Sahur's burning grove: charred trunks still burning at their tops,
-- ember cracks up them, and logs fallen by the walls.
RiftWorld.Features.Logs = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local bark = Color3.fromRGB(32, 24, 20)
	for n, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(2, spot.Reach)
		local tall = rng:NextNumber(13, 20)
		local r = rng:NextNumber(2.2, 3.1)
		local trunk = cylinder(model, at + UP * tall / 2, r, tall, bark, Enum.Material.Wood, true)
		trunk.Name = "Trunk"
		for c = 1, 2 do
			local a = rng:NextNumber(0, 6)
			local crack = glow(
				part(
					model,
					CFrame.new(at + UP * rng:NextNumber(3, tall - 3)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
						* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, 0),
					Vector3.new(0.5, rng:NextNumber(3, 6), 0.4),
					P.Glow
				)
			)
			crack.Transparency = 0.25
		end
		local top = glow(disc(model, at + UP * (tall + 0.1), r * 0.8, 0.3, P.Accent))
		top.Name = "Burning"
		fire(top, 7, 12)
		light(top, P.Accent, 30, 1.6)
		if n % 2 == 1 then
			local long = rng:NextNumber(9, 13)
			part(
				model,
				CFrame.new(at + spot.Along * rng:NextNumber(6, 9) + spot.In * 3 + UP * 1.4)
					* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
				Vector3.new(long, 3, 3),
				bark,
				Enum.Material.Wood,
				"Cylinder",
				true
			).Name = "Log"
		end
	end
end

-- Paperotti's frozen pond: sheets of ice over the floor, hail heaped on
-- them, and slabs of ice stood up at their edges.
RiftWorld.Features.Floes = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local ice = Color3.fromRGB(150, 200, 240)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(5, spot.Reach)
		local r = rng:NextNumber(6, 9)
		local pond = disc(model, at + UP * 0.12, r, 0.24, ice, Enum.Material.Glass)
		pond.Name = "Pond"
		pond.Transparency = 0.35
		light(pond, P.Glow, 18, 0.7)
		for _ = 1, 6 do
			local a, out = rng:NextNumber(0, 6.28), rng:NextNumber(0, r + 2)
			local sz = rng:NextNumber(0.8, 1.7)
			part(
				model,
				CFrame.new(at + Vector3.new(math.cos(a) * out, sz / 2, math.sin(a) * out)),
				Vector3.new(sz, sz, sz),
				Color3.fromRGB(236, 244, 255),
				Enum.Material.SmoothPlastic,
				"Ball"
			).Name =
				"Hail"
		end
		for _, s in { -1, 1 } do
			local slab = part(
				model,
				CFrame.new(at + spot.Along * s * r * 0.7 - spot.In * 1 + UP * 2.4)
					* CFrame.Angles(0, rng:NextNumber(0, 6), 0)
					* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, 0),
				Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(4, 6), 2.2),
				ice,
				Enum.Material.Glass,
				"Wedge",
				true
			)
			slab.Transparency = 0.3
		end
	end
end

-- Tralalero's frozen tide: waves frozen as they broke against the walls,
-- their foam still glowing, fins cutting up through the floor toward you,
-- and tide lines across it.
RiftWorld.Features.Tide = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local ice = Color3.fromRGB(140, 220, 235)
	local fin = Color3.fromRGB(22, 36, 46)
	for n, spot in wallSpots(center, half, doors, rng, 4) do
		if n <= 2 then
			-- A crest: three wedges in a row, leaning in over the floor.
			local frame = face(spot.At + spot.In * 1, spot.In)
			for i, w in { 10, 8, 5 } do
				local tall = 4 + w * 0.5
				local crest = part(
					model,
					frame * CFrame.new((i - 2) * 7, tall / 2, 0) * CFrame.Angles(-0.35, 0, 0),
					Vector3.new(6.5, tall, w),
					ice,
					Enum.Material.Glass,
					"Wedge",
					i == 1
				)
				crest.Transparency = 0.3
				crest.Name = "Crest"
			end
			local foam = glow(part(model, frame * CFrame.new(0, 9.2, 1.5), Vector3.new(20, 0.5, 1.2), P.Glow))
			foam.Transparency = 0.4
			light(foam, P.Glow, 22, 0.8)
		else
			-- Fins, in a line toward the middle (as far as the cave allows).
			local step = math.max(1, math.min(4.5, spot.Reach / 3))
			for i = 1, 3 do
				part(
					model,
					face(spot.At + spot.In * (i * step) + spot.Along * (i - 2) * 1.5, spot.In)
						* CFrame.new(0, 2.6, 0),
					Vector3.new(2.4, 5.2, 4),
					fin,
					Enum.Material.Slate,
					"Wedge",
					true
				).Name =
					"Fin"
			end
			local line = glow(
				part(
					model,
					face(spot.At + spot.In * math.min(9, spot.Reach), spot.Along) * CFrame.new(0, 0.06, 0),
					Vector3.new(0.5, 0.08, 14),
					P.Glow
				)
			)
			line.Transparency = 0.5
		end
	end
end

-- Frigo's freezer: blocks of ice stacked by the walls, something dark
-- frozen in each with its eyes still lit, and icicles hanging off the rock.
RiftWorld.Features.Freezer = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local ice = Color3.fromRGB(190, 225, 250)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(2, spot.Reach)
		local y = 0
		local bottom
		for i = 1, 2 do
			local w = rng:NextNumber(5, 7) - (i - 1) * 1.2
			local block = part(
				model,
				CFrame.new(at + UP * (y + w / 2)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
				Vector3.new(w, w, w),
				ice,
				Enum.Material.Glass,
				nil,
				i == 1
			)
			block.Transparency = 0.35
			block.Name = "IceBlock"
			bottom = bottom or block
			local thing = part(
				model,
				block.CFrame * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
				Vector3.new(2.2, 2, 2.2),
				Color3.fromRGB(40, 36, 50),
				Enum.Material.SmoothPlastic
			)
			for _, sgn in { -1, 1 } do
				glow(part(model, thing.CFrame * CFrame.new(sgn * 0.55, 0.3, -1.05), Vector3.new(0.35, 0.35, 0.35), P.Glow, nil, "Ball"))
			end
			y += w
		end
		light(bottom, P.Glow, 18, 0.7)
		for i = 1, 2 do
			local long = rng:NextNumber(5, 9)
			local icicle = part(
				model,
				CFrame.new(spot.At - spot.In * 2 + spot.Along * (i - 1.5) * 4 + UP * (RiftWorld.Wall - 1 - long / 2))
					* CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0),
				Vector3.new(1.3, long, 1.3),
				ice,
				Enum.Material.Glass,
				"Wedge"
			)
			icicle.Transparency = 0.3
			icicle.Name = "Icicle"
		end
	end
end

-- Chimpanzini's charged jungle: vines hanging off the walls with sparks
-- caught in them, and trunks banded with live current, bananas at their
-- feet.
RiftWorld.Features.Vines = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local vine = Color3.fromRGB(54, 72, 30)
	local trunkColor = Color3.fromRGB(48, 60, 32)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		for i = 1, 2 do
			local long = rng:NextNumber(8, 18)
			local top = spot.At - spot.In * 1.5 + spot.Along * (i - 1.5) * 5 + UP * (RiftWorld.Wall + 1)
			cylinder(model, top - UP * long / 2, 0.35, long, vine, Enum.Material.Grass, false).Name = "Vine"
			glow(part(model, CFrame.new(top - UP * rng:NextNumber(2, long - 1)), Vector3.new(0.6, 0.6, 0.6), P.Glow, nil, "Ball"))
		end
		local at = spot.At + spot.In * math.min(3, spot.Reach)
		local tall, r = rng:NextNumber(11, 16), rng:NextNumber(1.6, 2.1)
		cylinder(model, at + UP * tall / 2, r, tall, trunkColor, Enum.Material.Wood, true).Name = "Trunk"
		for i = 1, 2 do
			local ring = glow(disc(model, at + UP * (tall * (0.3 + i * 0.25)), r + 0.4, 0.3, P.Glow))
			ring.Transparency = 0.3
			if i == 1 then
				light(ring, P.Glow, 20, 0.9)
			end
		end
		for i = 1, 2 do
			part(
				model,
				CFrame.new(at + spot.In * (r + 1.2) + spot.Along * (i - 1.5) * 1.6 + UP * 0.5)
					* CFrame.Angles(0, rng:NextNumber(0, 6), 0.4),
				Vector3.new(0.8, 0.8, 2.6),
				Color3.fromRGB(240, 200, 60),
				Enum.Material.SmoothPlastic,
				"Wedge"
			).Name =
				"Banana"
		end
	end
end

-- Gattini's static spires: clusters of crystal standing out of the floor,
-- their tips lit and arcs of static jumping between them.
RiftWorld.Features.Spires = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local crystal = Color3.fromRGB(110, 96, 150)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		local tips, big = {}, nil
		for i = 1, 3 do
			local at = spot.At + spot.In * math.min(rng:NextNumber(1, 5), spot.Reach) + spot.Along * (i - 2) * rng:NextNumber(3, 4.5)
			local tall, w = rng:NextNumber(9, 17), rng:NextNumber(1.8, 2.8)
			local lean = CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.Angles(rng:NextNumber(-0.18, 0.18), 0, 0)
			local spire = part(
				model,
				CFrame.new(at) * lean * CFrame.new(0, tall / 2, 0),
				Vector3.new(w, tall, w),
				crystal,
				Enum.Material.Glass,
				"Wedge",
				i == 2
			)
			spire.Transparency = 0.15
			spire.Name = "Spire"
			big = big or spire
			local tip = glow(part(model, CFrame.new(at) * lean * CFrame.new(0, tall + 1, 0), Vector3.new(0.9, 2.4, 0.9), P.Glow, nil, "Wedge"))
			table.insert(tips, tip.CFrame.Position)
		end
		light(big, P.Glow, 20, 0.9)
		local a, b = tips[1], tips[3]
		local arc = glow(part(model, face((a + b) / 2, flat(b - a)) * CFrame.Angles(math.atan2(b.Y - a.Y, flat(b - a).Magnitude), 0, 0), Vector3.new(0.25, 0.25, (b - a).Magnitude), P.Glow))
		arc.Transparency = 0.25
		arc.Name = "Arc"
		local spark = glow(part(model, CFrame.new(spot.At + spot.In * 8 + UP * 0.06) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.3, 0.08, rng:NextNumber(4, 8)), P.Glow))
		spark.Transparency = 0.4
	end
end

-- Cappuccino's blade roost: katanas driven into the floor at a lean, their
-- edges lit, kunai scattered round them.
RiftWorld.Features.Blades = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local steel = Color3.fromRGB(200, 205, 215)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(rng:NextNumber(3, 7), spot.Reach)
		local lean = CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.Angles(rng:NextNumber(0.3, 0.55), 0, 0)
		local frame = CFrame.new(at) * lean
		local blade = part(model, frame * CFrame.new(0, 6, 0), Vector3.new(0.35, 16, 2.4), steel, Enum.Material.Metal, nil, true)
		blade.Name = "Blade"
		local edge = glow(part(model, frame * CFrame.new(0, 6, -1.25), Vector3.new(0.14, 15.6, 0.3), P.Glow))
		edge.Transparency = 0.2
		light(edge, P.Glow, 16, 0.7)
		part(model, frame * CFrame.new(0, 14.2, 0), Vector3.new(3, 0.4, 3), Color3.fromRGB(60, 48, 30), Enum.Material.Metal)
		cylinder(model, (frame * CFrame.new(0, 16.6, 0)).Position, 0.55, 4.4, Color3.fromRGB(36, 28, 24), Enum.Material.Fabric, false, lean)
		for i = 1, 3 do
			part(
				model,
				CFrame.new(spot.At + spot.In * rng:NextNumber(2, 10) + spot.Along * rng:NextNumber(-6, 6) + UP * 0.15)
					* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
				Vector3.new(0.5, 0.2, 2.4),
				steel,
				Enum.Material.Metal,
				"Wedge"
			).Name =
				"Kunai"
		end
	end
end

-- Ranocchio's bog: pools of poison glowing in the floor, bubbling, lily
-- pads on them and reeds round them, mounds of muck between.
RiftWorld.Features.Bog = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	for n, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(6, spot.Reach)
		local r = rng:NextNumber(5, 8)
		local rim = disc(model, at + UP * 0.1, r + 1.2, 0.2, Color3.fromRGB(26, 40, 28), Enum.Material.Mud)
		rim.Name = "Rim"
		local pool = glow(disc(model, at + UP * 0.22, r, 0.2, P.Glow))
		pool.Name = "Pool"
		pool.Transparency = 0.5
		light(pool, P.Glow, 18, 0.8)
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Rate = 5
		bubbles.Lifetime = NumberRange.new(1.2, 2)
		bubbles.Speed = NumberRange.new(1.5, 3)
		bubbles.Size = NumberSequence.new(0.5)
		bubbles.Color = ColorSequence.new(P.Glow)
		bubbles.LightEmission = 0.6
		bubbles.Parent = pool
		disc(model, at + spot.Along * r * 0.4 + UP * 0.34, 2.2, 0.16, Color3.fromRGB(60, 120, 50), Enum.Material.Grass).Name = "LilyPad"
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local tall = rng:NextNumber(5, 7.5)
			cylinder(
				model,
				at + Vector3.new(math.cos(a) * (r + 0.8), tall / 2, math.sin(a) * (r + 0.8)),
				0.3,
				tall,
				Color3.fromRGB(40, 70, 36),
				Enum.Material.Grass,
				false,
				CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, 0)
			).Name =
				"Reed"
		end
		if n < 3 then
			part(
				model,
				CFrame.new(spot.At + spot.Along * (r + 6) + spot.In * math.min(3, spot.Reach) + UP * 0.6),
				Vector3.new(6, 6, 6),
				Color3.fromRGB(60, 84, 46),
				Enum.Material.Mud,
				"Ball",
				true
			).Name =
				"Mound"
		end
	end
end

-- Patapim's rotting grove: dead trees with roots hanging off their boughs,
-- moss up their trunks, and toadstools glowing underneath.
RiftWorld.Features.Grove = function(model, center: Vector3, size: number, doors, rng)
	local half = size / 2
	local bark = Color3.fromRGB(54, 44, 32)
	for _, spot in wallSpots(center, half, doors, rng, 3) do
		local at = spot.At + spot.In * math.min(3, spot.Reach)
		local tall, r = rng:NextNumber(15, 21), rng:NextNumber(2, 2.7)
		cylinder(model, at + UP * tall / 2, r, tall, bark, Enum.Material.Wood, true).Name = "Trunk"
		part(
			model,
			CFrame.new(at + UP * tall * 0.3) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.new(0, 0, -r),
			Vector3.new(2.4, tall * 0.35, 0.4),
			Color3.fromRGB(60, 110, 50),
			Enum.Material.Grass
		).Name =
			"Moss"
		for i = 1, 2 do
			local yaw = rng:NextNumber(0, 6)
			local long = rng:NextNumber(7, 10)
			local bough = CFrame.new(at + UP * (tall - 1.5)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rng:NextNumber(-1.25, -0.95), 0, 0)
			cylinder(model, (bough * CFrame.new(0, long / 2, 0)).Position, 0.8, long, bark, Enum.Material.Wood, false, bough - bough.Position).Name =
				"Bough"
			if i == 1 then
				local tip = (bough * CFrame.new(0, long, 0)).Position
				local drop = rng:NextNumber(6, 10)
				cylinder(model, tip - UP * drop / 2, 0.25, drop, bark, Enum.Material.Wood, false).Name = "Root"
			end
		end
		local shroom = spot.At + spot.In * rng:NextNumber(6, 9) + spot.Along * rng:NextNumber(-5, 5)
		cylinder(model, shroom + UP * 1.25, 0.5, 2.5, Color3.fromRGB(200, 190, 150), Enum.Material.SmoothPlastic, false)
		disc(model, shroom + UP * 2.9, rng:NextNumber(1.8, 2.6), 0.9, Color3.fromRGB(120, 100, 60), Enum.Material.SmoothPlastic).Name = "Cap"
		local gills = glow(disc(model, shroom + UP * 2.4, 1.6, 0.15, P.Glow))
		gills.Transparency = 0.3
		light(gills, P.Glow, 16, 0.8)
	end
end

function RiftWorld.build(id: string, origin: CFrame, rng, realm)
	P = realm or RiftRealms.Default
	local folder = Instance.new("Folder")
	folder.Name = "Rift_" .. id
	folder:SetAttribute("Realm", P.Id)
	folder:SetAttribute("RealmName", P.Name)
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
			-- (Where it leads: a little way into the next cave. Once it's
			-- open, the arrows on the ground lead there: Client.GroundGuide.)
			gates[i - 1]:SetAttribute("Into", to + dir * 8)
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
	-- What's left of the crews who came before: a couple by the walls of
	-- each cave, more round the throne, and their heap beside it
	-- (Server.World.FallenMiners; props only).
	local remains = { Glow = P.Accent, Scratch = P.Dark, Shards = true }
	for i = 2, last - 1 do
		local doors = {}
		for _, j in { i - 1, i + 1 } do
			table.insert(doors, flat(centers[j] - centers[i]).Unit)
		end
		remains.Doors = doors
		FallenMiners.scatter(folder, centers[i], sizes[i] - 6, FallenMiners.Count.Cave, rng, remains)
	end
	local heapAt = seat - seatFrame.RightVector * 20 + facing * 5
	FallenMiners.heap(folder, heapAt, facing, rng, remains)
	remains.Doors = { -facing, flat(centers[last - 1] - bossAt).Unit }
	remains.Avoid = {
		{ At = seat, Radius = 16 },
		{ At = beside, Radius = 10 },
		{ At = heapAt, Radius = 11 },
	}
	FallenMiners.scatter(folder, bossAt, RiftWorld.Throne - 8, FallenMiners.Count.Throne, rng, remains)
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
		part(model, base * CFrame.new(0, 1.6, 0), Vector3.new(5.2, 3.2, 4.6), P.Obsidian, Enum.Material.Basalt, nil, true)
	body.Name = "Body"
	model.PrimaryPart = body
	local cap = part(
		model,
		base * CFrame.new(0.6, 3.2, -0.3) * CFrame.Angles(0.2, 0.5, 0.15),
		Vector3.new(3.4, 1.6, 3),
		P.Rock,
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
