--[[
	Fallen miners: what's left of the crews who went in before you, by the
	walls of the Rift's caves and the dungeon's rooms, and heaped round the
	boss. Props only (nothing to bump into, nothing to press): an old
	expedition suit, its paint faded, its visor cracked and the skull's
	sockets behind it still glowing faintly; a skull where a helmet rolled
	off; the pick it dropped; a pouch of gems spilt and glinting; claw
	marks dragged across the floor; the floor stained dark under it.

	  FallenMiners.place(parent, at, facing, rng, opts?) -> Model
	      one miner at `at` (on the floor) facing `facing` (into the room:
	      the one slumped against a wall has its back to it). opts:
	        Pose     "Slumped" | "FaceDown" | "Sprawled" (else picked)
	        Glow     the colour of its visor's crack and its spilt gems
	        Scratch  the claw marks' colour (glowing in the Rift)
	        Shards   crystals of the place grown up through it
	  FallenMiners.heap(parent, at, facing, rng, opts?) -> Model
	      a heap by the boss: rubble, helmets, bones, picks stuck in it,
	      a torn crew banner, two helmets up on spikes, gems spilt round it
	  FallenMiners.scatter(parent, center, size, count, rng, opts?) -> { Model }
	      `count` of them round a square room `size` wide: by the walls
	      first (clear of the doors, opts.Doors: the sides' outward
	      Vector3s), then further in, clear of the middle and of
	      opts.Avoid ({ { At, Radius } }: a throne, a way home)
	  FallenMiners.Count   how many where: Cave, Throne, Room, BossRoom
]]
local FallenMiners = {}

FallenMiners.Count = { Cave = 2, Throne = 6, Room = 1, BossRoom = 4 }
FallenMiners.Poses = { "Slumped", "FaceDown", "Sprawled" }

local BONE = Color3.fromRGB(214, 202, 176)
local SOCKET = Color3.fromRGB(28, 22, 22)
local GLASS = Color3.fromRGB(22, 28, 36)
local LEATHER = Color3.fromRGB(92, 62, 40)
local WOOD = Color3.fromRGB(104, 76, 50)
local IRON = Color3.fromRGB(96, 98, 104)
local RUBBLE = Color3.fromRGB(58, 48, 46)
local LAMP = Color3.fromRGB(255, 214, 140)
local COLD = Color3.fromRGB(120, 220, 255)
local STAIN = Color3.fromRGB(34, 14, 14)
-- Old expedition suits, faded: shell, stripe, joints.
local SUITS = {
	{ Color3.fromRGB(176, 170, 158), Color3.fromRGB(214, 112, 42), Color3.fromRGB(62, 62, 68) },
	{ Color3.fromRGB(122, 134, 142), Color3.fromRGB(84, 164, 214), Color3.fromRGB(50, 54, 62) },
	{ Color3.fromRGB(160, 136, 74), Color3.fromRGB(44, 42, 46), Color3.fromRGB(70, 60, 44) },
	{ Color3.fromRGB(146, 64, 54), Color3.fromRGB(206, 196, 176), Color3.fromRGB(58, 44, 44) },
}
local GEMS = {
	Color3.fromRGB(255, 96, 60),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(120, 235, 110),
	Color3.fromRGB(210, 120, 255),
}

local function part(parent, cframe: CFrame, size: Vector3, color: Color3, material, shape: string?)
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
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 1.6
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neon(p: BasePart): BasePart
	p.Material = Enum.Material.Neon
	p.CastShadow = false
	return p
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- A skull: the cranium, its dark eye sockets, the jaw. (`bare`: the jaw
-- too; behind a visor only the cranium and sockets show.)
local function skull(parent, frame: CFrame, scale: number, bare: boolean, eyes: Color3?)
	part(parent, frame, Vector3.one * 1.1 * scale, BONE, Enum.Material.SmoothPlastic, "Ball")
	local sockets = part(parent, frame * CFrame.new(0, 0.04 * scale, -0.42 * scale), Vector3.new(0.74, 0.24, 0.3) * scale, SOCKET)
	if eyes then
		-- (behind the glass the sockets still glow, faintly)
		sockets.Color = eyes
		neon(sockets).Transparency = 0.3
		sockets.Name = "Eyes"
	end
	if bare then
		part(parent, frame * CFrame.new(0, -0.48 * scale, -0.16 * scale), Vector3.new(0.62, 0.22, 0.5) * scale, BONE)
	end
end

-- A helmet: the shell, the big visor bulging from its front (dark glass,
-- cracked, the crack still glowing), a headlamp. `inside`: a skull behind
-- the glass, its sockets glowing.
local function helmet(parent, frame: CFrame, shell: Color3, glow: Color3, rng, inside: boolean)
	local dome = part(parent, frame, Vector3.one * 1.85, shell, Enum.Material.SmoothPlastic, "Ball")
	dome.Name = "Helmet"
	local visor = part(parent, frame * CFrame.new(0, -0.08, -0.46), Vector3.new(1.5, 1.08, 1.02), GLASS, Enum.Material.Glass, "Ball")
	visor.Transparency = if inside then 0.3 else 0.08
	visor.Reflectance = 0.25
	visor.Name = "Visor"
	local tilt = rng:NextNumber(0.5, 0.9) * (if rng:NextNumber() < 0.5 then -1 else 1)
	neon(part(parent, frame * CFrame.new(0.12, -0.04, -0.96) * CFrame.Angles(0, 0, tilt), Vector3.new(0.07, 0.8, 0.05), glow)).Name =
		"Crack"
	local lamp = part(parent, frame * CFrame.new(0, 0.72, -0.62) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.3, 0.36, 0.36), SOCKET, nil, "Cylinder")
	if rng:NextNumber() < 0.5 then
		lamp.Color = LAMP
		neon(lamp) -- (still on, after all this time)
	end
	if inside then
		skull(parent, frame * CFrame.new(0, -0.08, -0.2), 0.82, false, glow)
	end
	return dome
end

-- Where it lay longest, the floor's stained dark.
local function stain(parent, frame: CFrame, size: number)
	local mark = part(parent, frame * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.06, size, size), STAIN, Enum.Material.SmoothPlastic, "Cylinder")
	mark.Transparency = 0.4
	mark.Name = "Stain"
end

-- A pick: the haft and the head.
local function pick(parent, frame: CFrame)
	part(parent, frame * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(3.2, 0.24, 0.24), WOOD, Enum.Material.Wood, "Cylinder")
	part(parent, frame * CFrame.new(0, 1.55, -0.25) * CFrame.Angles(math.pi / 2, 0, 0), Vector3.new(0.38, 2.4, 0.38), IRON, Enum.Material.Metal, "Wedge")
end

-- A pouch, spilt: the bag and a few gems, one lighting the floor round it.
local function spill(parent, frame: CFrame, glow: Color3?, rng)
	part(parent, frame * CFrame.new(0, 0.35, 0), Vector3.new(0.95, 0.75, 0.8), LEATHER, Enum.Material.Fabric, "Ball")
	local lit
	for i = 1, rng:NextInteger(2, 3) do
		local color = if glow and i == 1 then glow else GEMS[rng:NextInteger(1, #GEMS)]
		local size = rng:NextNumber(0.28, 0.5)
		local gem = neon(part(
			parent,
			frame
				* CFrame.new(rng:NextNumber(0.5, 1.6), size / 2, rng:NextNumber(-0.7, 0.7))
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
			Vector3.new(size, size * 1.4, size),
			color
		))
		gem.Name = "SpiltGem"
		lit = lit or gem
	end
	light(lit, lit.Color, 9, 1.4)
end

-- Three claw marks dragged across the floor.
local function scratches(parent, frame: CFrame, color: Color3, glowing: boolean)
	for i = -1, 1 do
		local mark = part(parent, frame * CFrame.new(i * 0.42, 0.04, 0) * CFrame.Angles(0, i * 0.06, 0), Vector3.new(0.16, 0.06, 3.4 - math.abs(i) * 0.6), color)
		mark.Name = "Scratch"
		if glowing then
			neon(mark).Transparency = 0.25
		end
	end
end

-- The suit's torso: the chest plate and its stripe, the joints below it,
-- shoulder pads, and the life-support pack (behind, unless it's come off).
local function torso(parent, frame: CFrame, suit, pack: boolean)
	part(parent, frame * CFrame.new(0, 0.35, 0), Vector3.new(2, 1.35, 1.15), suit[1], Enum.Material.Metal).Name = "Suit"
	part(parent, frame * CFrame.new(0, 0.62, -0.03), Vector3.new(2.04, 0.26, 1.2), suit[2])
	part(parent, frame * CFrame.new(0, -0.68, 0), Vector3.new(1.7, 0.95, 1), suit[3], Enum.Material.CorrodedMetal)
	for _, s in { -1, 1 } do
		part(parent, frame * CFrame.new(s * 1.08, 0.88, 0) * CFrame.Angles(0, 0, -s * 0.28), Vector3.new(0.78, 0.42, 1.2), suit[1], Enum.Material.Metal)
	end
	if pack then
		part(parent, frame * CFrame.new(0, 0.3, 0.84), Vector3.new(1.5, 1.55, 0.6), suit[3], Enum.Material.CorrodedMetal)
	end
end

-- An arm or a leg: the limb, and the glove or the boot at its end.
local function limb(parent, frame: CFrame, suit, length: number, thick: number)
	part(parent, frame, Vector3.new(thick, length, thick), suit[1], Enum.Material.Metal)
	part(parent, frame * CFrame.new(0, -length / 2, -0.08), Vector3.new(thick + 0.16, 0.5, thick + 0.34), suit[3], Enum.Material.CorrodedMetal)
end

-- Crystals of the place grown up through it: it's been here a long time.
local function shards(parent, frame: CFrame, glow: Color3, rng)
	for _ = 1, rng:NextInteger(1, 2) do
		local high = rng:NextNumber(1.1, 2.1)
		local shard = neon(part(
			parent,
			frame * CFrame.new(rng:NextNumber(-0.7, 0.7), high * 0.35, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(0.34, high, 0.34),
			glow
		))
		shard.Name = "Shard"
		shard.Transparency = 0.12
	end
end

-- A frame on the floor at `at`, its front (-Z) along `facing`. (Not
-- CFrame.lookAt: lune's, which the tests build these with, turns the other
-- way along Z.)
local function frameAt(at: Vector3, facing: Vector3): CFrame
	local x, z = facing.X, facing.Z
	if x * x + z * z < 1e-6 then
		x, z = 0, -1
	end
	return CFrame.new(at) * CFrame.Angles(0, math.atan2(-x, -z), 0)
end

local POSES = {}

-- Sat against the wall, head dropped onto its chest, the pick across its
-- lap, a hand by its spilt pouch.
POSES.Slumped = function(model, base: CFrame, suit, glow: Color3, rng, opts)
	stain(model, base * CFrame.new(0, 0, -0.5), 4.4)
	local body = base * CFrame.new(0, 1.5, 0.35) * CFrame.Angles(0.35, 0, rng:NextNumber(-0.12, 0.12))
	torso(model, body, suit, true)
	helmet(model, body * CFrame.new(0.1, 1.55, -0.25) * CFrame.Angles(-0.5, rng:NextNumber(-0.4, 0.4), 0.15), suit[1], glow, rng, true)
	for _, s in { -1, 1 } do
		limb(model, base * CFrame.new(s * 0.52, 0.42, -0.9) * CFrame.Angles(math.pi / 2 - 0.1, s * 0.12, 0), suit, 2.1, 0.78)
		limb(model, body * CFrame.new(s * 1.28, 0.05, -0.15) * CFrame.Angles(-0.25, 0, s * 0.18), suit, 1.85, 0.56)
	end
	pick(model, base * CFrame.new(0.25, 0.95, -1.15) * CFrame.Angles(math.pi / 2, 0, 1.1))
	spill(model, base * CFrame.new(1.35, 0, -0.6), glow, rng)
	if opts.Shards then
		shards(model, base * CFrame.new(-1.3, 0, 0.6), glow, rng)
	end
end

-- Face down, reaching for the pick it dropped, its helmet rolled away
-- (the skull bare), claw marks behind it where something dragged it.
POSES.FaceDown = function(model, base: CFrame, suit, glow: Color3, rng, opts)
	stain(model, base * CFrame.new(0, 0, 0.5), 5.2)
	local body = base * CFrame.new(0, 0.62, 0.4) * CFrame.Angles(-math.pi / 2, 0, rng:NextNumber(-0.15, 0.15))
	torso(model, body, suit, true)
	skull(model, body * CFrame.new(0, 1.55, -0.1) * CFrame.Angles(0.3, 0.4, 0), 1, true)
	helmet(model, base * CFrame.new(rng:NextNumber(1.4, 2.2), 0.9, -2.6) * CFrame.Angles(-1.2, rng:NextNumber(0, 6), 0.4), suit[1], glow, rng, false)
	limb(model, body * CFrame.new(1.05, 2.2, 0.05) * CFrame.Angles(0, 0, math.pi - 0.3), suit, 1.85, 0.56) -- (reaching)
	limb(model, body * CFrame.new(-1.3, 0.1, 0.05) * CFrame.Angles(0, 0, 0.15), suit, 1.85, 0.56)
	for _, s in { -1, 1 } do
		limb(model, body * CFrame.new(s * 0.5, -2.15, 0) * CFrame.Angles(0, 0, s * 0.12), suit, 2.1, 0.78)
	end
	pick(model, base * CFrame.new(1.6, 0.2, -3.6) * CFrame.Angles(0, 0.6, math.pi / 2))
	scratches(model, base * CFrame.new(-1.9, 0, 2.2) * CFrame.Angles(0, 0.2, 0), opts.Scratch or SOCKET, opts.Scratch ~= nil)
	if rng:NextNumber() < 0.6 then
		spill(model, base * CFrame.new(-1.6, 0, -1.4), glow, rng)
	end
	if opts.Shards then
		shards(model, base * CFrame.new(0, 1.0, 0.4), glow, rng)
	end
end

-- On its back, arms flung out, visor up (the skull behind the cracked
-- glass), its pack torn off beside it and its pick stood in the ground
-- like a marker.
POSES.Sprawled = function(model, base: CFrame, suit, glow: Color3, rng, opts)
	stain(model, base * CFrame.new(0, 0, -0.4), 5.2)
	local body = base * CFrame.new(0, 0.62, 0) * CFrame.Angles(math.pi / 2, 0, rng:NextNumber(-0.2, 0.2))
	torso(model, body, suit, false)
	local head = body * CFrame.new(0, 1.55, 0.1) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
	helmet(model, head, suit[1], glow, rng, true)
	for _, s in { -1, 1 } do
		limb(model, body * CFrame.new(s * 1.55, 0.95, 0) * CFrame.Angles(0, 0, s * 1.15), suit, 1.85, 0.56)
		limb(model, body * CFrame.new(s * 0.62, -2.1, 0) * CFrame.Angles(0, 0, s * 0.22), suit, 2.1, 0.78)
	end
	part(model, base * CFrame.new(-2.2, 0.45, 0.9) * CFrame.Angles(0.2, 0.7, 1.45), Vector3.new(1.6, 1.7, 0.7), suit[3], Enum.Material.CorrodedMetal)
	pick(model, base * CFrame.new(2.3, 1.45, -1.4) * CFrame.Angles(0.3, 0.4, 0.15))
	spill(model, base * CFrame.new(0.9, 0, 1.6), glow, rng)
	if opts.Shards then
		shards(model, base * CFrame.new(-0.9, 0, -0.6), glow, rng)
	end
end

function FallenMiners.place(parent: Instance, at: Vector3, facing: Vector3, rng, opts: any?): Model
	opts = opts or {}
	local model = Instance.new("Model")
	model.Name = "FallenMiner"
	model.Parent = parent
	local base = frameAt(at, facing)
	local pose = opts.Pose or FallenMiners.Poses[rng:NextInteger(1, #FallenMiners.Poses)]
	local suit = SUITS[rng:NextInteger(1, #SUITS)]
	POSES[pose](model, base, suit, opts.Glow or COLD, rng, opts)
	model:SetAttribute("Pose", pose)
	return model
end

-- By the boss: a heap of what the crews left. Rubble, the helmets of
-- those who never came back, bones, picks stuck in it, a torn crew banner
-- on a pole, two more helmets up on spikes, gems spilt round its foot.
function FallenMiners.heap(parent: Instance, at: Vector3, facing: Vector3, rng, opts: any?): Model
	opts = opts or {}
	local glow = opts.Glow or COLD
	local model = Instance.new("Model")
	model.Name = "FallenHeap"
	model.Parent = parent
	local base = frameAt(at, facing)
	for i = 1, 7 do
		local w = rng:NextNumber(1.4, 2.6)
		part(
			model,
			base * CFrame.new(rng:NextNumber(-2.6, 2.6), w * 0.25 + (if i > 6 then 0.8 else 0), rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(w, w * 0.55, w * 0.75),
			RUBBLE:Lerp(SOCKET, rng:NextNumber(0, 0.4)),
			Enum.Material.Slate,
			if i % 2 == 0 then "Wedge" else nil
		)
	end
	for i = 1, 3 do
		local suit = SUITS[(i - 1) % #SUITS + 1]
		local angle = (i - 1) * math.pi * 2 / 3 + rng:NextNumber(-0.4, 0.4)
		helmet(
			model,
			base * CFrame.new(math.cos(angle) * 1.7, 2.3 + (if i == 1 then 0.9 else 0), math.sin(angle) * 1.4) * CFrame.Angles(rng:NextNumber(-0.6, 0.2), angle + math.pi, rng:NextNumber(-0.3, 0.3)),
			suit[1],
			glow,
			rng,
			i % 2 == 1
		)
	end
	for _ = 1, 4 do
		part(
			model,
			base * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(0.3, 1.8), rng:NextNumber(-2.4, 2.4)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
			Vector3.new(0.28, rng:NextNumber(1.4, 2.4), 0.28),
			BONE
		)
	end
	skull(model, base * CFrame.new(-1.9, 0.6, -2.2) * CFrame.Angles(0, 0.6, 0), 1, true)
	for _, s in { -1, 1 } do
		pick(model, base * CFrame.new(s * 1.8, 2.6, 0.6) * CFrame.Angles(s * 0.3, 0, s * 0.35))
	end
	-- The banner: a pole and a torn cloth in a crew's colours.
	local pole = base * CFrame.new(0.4, 0, 1.2)
	part(model, pole * CFrame.new(0, 4.2, 0), Vector3.new(0.24, 8.4, 0.24), IRON, Enum.Material.Metal)
	local cloth = SUITS[rng:NextInteger(1, #SUITS)]
	part(model, pole * CFrame.new(-1.1, 7.4, 0) * CFrame.Angles(0, 0, 0.06), Vector3.new(2.1, 1.6, 0.08), cloth[1], Enum.Material.Fabric).Name =
		"Banner"
	part(model, pole * CFrame.new(-1.1, 7.4, 0) * CFrame.Angles(0, 0, 0.06), Vector3.new(2.12, 0.36, 0.1), cloth[2], Enum.Material.Fabric)
	-- Two of their helmets stuck up on spikes either side, as trophies.
	for _, side in { -1, 1 } do
		local foot = base * CFrame.new(side * 3.8, 0, 1.4) * CFrame.Angles(0.1, 0, -side * 0.14)
		part(model, foot * CFrame.new(0, 2.7, 0), Vector3.new(0.3, 5.4, 0.3), IRON, Enum.Material.CorrodedMetal).Name = "Spike"
		local suit = SUITS[rng:NextInteger(1, #SUITS)]
		helmet(model, foot * CFrame.new(0, 5.3, 0) * CFrame.Angles(-0.2, side * 0.45, 0), suit[1], glow, rng, true)
	end
	stain(model, base, 8)
	spill(model, base * CFrame.new(0.6, 0, -2.6), glow, rng)
	if opts.Scratch then
		scratches(model, base * CFrame.new(2.9, 0, -2.4) * CFrame.Angles(0, -0.5, 0), opts.Scratch, true)
	end
	return model
end

function FallenMiners.scatter(parent: Instance, center: Vector3, size: number, count: number, rng, opts: any?): { Model }
	opts = opts or {}
	local half = size / 2
	local doors = opts.Doors or {}
	local spots = {}
	-- By the walls without a door first (the middle of each, between the
	-- stalagmites), then by the walls with one (to the side of it).
	local sides = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	local function hasDoor(d: Vector3): boolean
		for _, door in doors do
			if (Vector3.new(door.X, 0, door.Z) - d).Magnitude < 0.5 then
				return true
			end
		end
		return false
	end
	for _, d in sides do
		if not hasDoor(d) then
			local along = Vector3.new(-d.Z, 0, d.X) * rng:NextNumber(-0.2, 0.2) * half
			table.insert(spots, { At = center + d * (half - 3.5) + along, Facing = -d, Pose = "Slumped" })
		end
	end
	for _, d in sides do
		if hasDoor(d) then
			local side = Vector3.new(-d.Z, 0, d.X) * (if rng:NextNumber() < 0.5 then -1 else 1)
			table.insert(spots, { At = center + d * (half - 6) + side * half * 0.6, Facing = side, Pose = nil })
		end
	end
	for i = 1, 4 do
		local angle = (i - 0.5) * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		table.insert(spots, { At = center + dir * half * 0.62, Facing = Vector3.new(-dir.Z, 0, dir.X), Pose = nil })
	end
	-- (shuffled within each band, so rooms differ)
	for i = #spots, 2, -1 do
		local j = rng:NextInteger(1, i)
		if (spots[i].Pose == "Slumped") == (spots[j].Pose == "Slumped") then
			spots[i], spots[j] = spots[j], spots[i]
		end
	end
	local placed = {}
	for _, spot in spots do
		if #placed >= count then
			break
		end
		local clear = true
		for _, avoid in opts.Avoid or {} do
			local gap = spot.At - avoid.At
			if Vector3.new(gap.X, 0, gap.Z).Magnitude < avoid.Radius then
				clear = false
			end
		end
		if not clear then
			continue
		end
		local pose = spot.Pose
		if pose ~= "Slumped" then
			pose = if rng:NextNumber() < 0.5 then "FaceDown" else "Sprawled"
		end
		table.insert(
			placed,
			FallenMiners.place(parent, spot.At, spot.Facing, rng, { Pose = pose, Glow = opts.Glow, Scratch = opts.Scratch, Shards = opts.Shards })
		)
	end
	return placed
end

return FallenMiners
