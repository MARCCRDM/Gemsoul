--[[
	The dungeons' bosses (Shared.DungeonRules.Bosses): ten brainrot creatures,
	most of them with two or three heads, built as titans: hunched over
	heavy shoulders, thick forearms and big clawed hands, short heavy legs,
	angry heads with glowing eyes, and the Rift breaking out of their backs
	in dark crystal and glowing veins of their element (riftMarks).

	Like the room fighters (BrainrotSkins) each is built of plain parts
	welded onto the R15 combat skeleton (its bones go invisible), so they
	walk, wind up, strike, guard and flinch with the standard fighting poses
	(RivalPose, BodyPoses). Their heads look about and nod, wings flap,
	tails sway, jaws and beaks snap on a blow (CreatureAnimation: Head, Wing,
	Tail, Jaw, Moss, Blade).

	  TwinCat     Gattini Gemellini      a two-headed sabre cat of storm-grey stone
	  DragonCroc  Bombardiro Drago       a crocodile brute with bat wings
	  TwinDuck    Paperotti Gemelli      two drakes on a feathered war-duck
	  FrogAvocado Ranocchio Avocadino    two toads riding a halved avocado
	  Chimpanzini Chimpanzini Bananini   three apes bursting out of a banana
	  SahurTrio   Tung Tung Tung Sahur   a charred log golem, three faces, a nail bat
	  TwinShark   Tralalero Tralala      a two-headed shark brute in sneakers
	  TreeTrio    Brr Brr Patapim        an old treant, three long-nosed faces
	  Frigo       Frigo Camelo           two camels out of a frosted freezer
	  Cappuccino  Cappuccino Assassino   a ninja coffee cup with four blades

	Shapes are placed in the body's own space (put: x right, y up, -z
	forward, from its root at rest), on the bone that carries them.

	  BrainrotBosses.Builders[shape](rig, accent)
	  BrainrotBosses.apply(rig, spec, accent, boss) -> boolean   dresses it
	      (false if `spec` isn't one of these: BrainrotSkins dresses it)
]]
local Skins = require(script.Parent.BrainrotSkins)

local Bosses = {}

local V, C, A = Vector3.new, Color3.fromRGB, CFrame.Angles
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local P, animate = Skins.part, Skins.animate
local WHITE, INK = C(236, 232, 222), C(20, 18, 22)
local IVORY = C(226, 218, 196)
local UPRIGHT = A(0, 0, math.pi / 2) -- (a cylinder stood on end)
local SIDES = { -1, 1 }
local LR = { [-1] = "Left", [1] = "Right" }

-- The Rift's crystal: near-black violet glass.
local RIFT, RIFT_EDGE = C(34, 24, 52), C(70, 46, 104)

local function dim(c: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

local function neon(p)
	p.Material = Enum.Material.Neon
	return p
end
local function wood(p)
	p.Material = Enum.Material.Wood
	return p
end

-- What `put` places in: the body's space, or a piece of it turned (a head
-- looking out to its side: see turned).
local frame = CFrame.identity

-- A part on `bone`, placed at `at` in the body's space (its root at rest)
-- and turned by `turn`.
local function put(rig, bone: string, name: string, size: Vector3, at: Vector3, color: Color3, shape, turn: CFrame?)
	local b = rig[bone]
	local cf = b.CFrame:ToObjectSpace(rig.HumanoidRootPart.CFrame * frame * CFrame.new(at) * (turn or CFrame.identity))
	return P(rig, b, name, size, cf.Position, color, shape, cf.Rotation)
end
local function ball(rig, bone, name, size, at, color, turn)
	return put(rig, bone, name, size, at, color, BALL, turn)
end

-- A point in the body's space, in `bone`'s.
local function pivotOn(rig, bone: string, at: Vector3): CFrame
	return rig[bone].CFrame:ToObjectSpace(rig.HumanoidRootPart.CFrame * frame * CFrame.new(at))
end

-- Runs `build`, everything it places turned by `turn` about `pivot` (in the
-- body's space): a head turned out to its side, so two or three of them
-- don't stand in a row.
local function turned(pivot: Vector3, turn: CFrame, build: () -> ())
	local was = frame
	frame = was * CFrame.new(pivot) * turn * CFrame.new(-pivot)
	build()
	frame = was
end
-- Head `build(x, side)` at `x`, looking out to its side by `yaw`.
local function headOut(x: number, side: number, yaw: number, build: (number, number) -> ())
	turned(V(x, 1.7, -0.3), A(0, -side * yaw, 0), function()
		build(x, side)
	end)
end

-- Moves every part of `list` together about `pivot` (in the body's space),
-- carried by `bone`: a head looking about, a wing flapping.
local function group(rig, list, kind: string, bone: string, pivot: Vector3, side: number)
	local at = pivotOn(rig, bone, pivot)
	for _, p in list do
		animate(p, kind, at, side)
	end
end

-- A pair of furious eyes looking forward (-Z) at `at`, `spacing` apart:
-- a dark socket, a glowing eye (`glow`) with a slit, and a heavy brow
-- slanting down to the middle.
local function eyes(rig, bone, list, at: Vector3, spacing: number, r: number, glow: Color3, brow: Color3?)
	for _, s in SIDES do
		local x = at.X + s * spacing
		table.insert(
			list,
			ball(rig, bone, "EyeSocket", V(r * 1.3, r * 0.95, r * 0.6), V(x, at.Y, at.Z + r * 0.12), INK)
		)
		table.insert(
			list,
			neon(
				ball(
					rig,
					bone,
					"GlowEye",
					V(r, r * 0.62, r * 0.42),
					V(x, at.Y, at.Z - r * 0.08),
					glow,
					A(0, 0, s * 0.22)
				)
			)
		)
		table.insert(
			list,
			ball(rig, bone, "SlitPupil", V(r * 0.16, r * 0.55, r * 0.1), V(x, at.Y, at.Z - r * 0.28), INK)
		)
		table.insert(
			list,
			put(
				rig,
				bone,
				"AngryBrow",
				V(r * 1.45, r * 0.32, r * 0.5),
				V(x - s * r * 0.05, at.Y + r * 0.5, at.Z - r * 0.1),
				brow or INK,
				nil,
				A(0, 0, s * 0.42)
			)
		)
	end
end

-- A titan's arms: a shoulder mass over the joint, a bulging upper arm, a
-- forearm heavier than it (gorilla-built), and a big `hand`: "Claw" (a
-- paw with long claws), "Fist", "Pad" (a frog's), "Hoof" or "Fin".
local function arms(rig, skin: Color3, dark: Color3, hand: string, bulk: number?, nail: Color3?)
	local k = bulk or 1
	for _, s in SIDES do
		local side = LR[s]
		local upper, lower, h = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
		ball(rig, upper, "Shoulder", V(1.3, 1.1, 1.25) * k, V(s * 1.45, 1.38, 0.05), dark)
		ball(rig, upper, "UpperArm", V(0.95, 1.45, 0.98) * k, V(s * 1.58, 0.82, 0.02), skin)
		ball(rig, lower, "Elbow", V(0.82, 0.7, 0.82) * k, V(s * 1.6, 0.22, 0.05), skin)
		ball(rig, lower, "Forearm", V(1.12, 1.3, 1.1) * k, V(s * 1.62, -0.2, -0.04), skin)
		ball(rig, lower, "Wrist", V(0.78, 0.5, 0.78) * k, V(s * 1.6, -0.62, -0.04), dark)
		if hand == "Claw" or hand == "Fist" then
			ball(rig, h, "Hand", V(0.95, 0.72, 1.0) * k, V(s * 1.6, -0.92, -0.08), skin)
			for i = 1, 3 do
				local x = s * 1.6 + (i - 2) * 0.27 * k
				ball(rig, h, "Knuckle", V(0.3, 0.32, 0.36) * k, V(x, -1.2, -0.42 * k), skin)
				if hand == "Claw" then
					put(
						rig,
						h,
						"Claw",
						V(0.12, 0.42, 0.22) * k,
						V(x, -1.42, -0.55 * k),
						nail or IVORY,
						"Wedge",
						A(0.5, 0, math.pi)
					)
				end
			end
			ball(rig, h, "Thumb", V(0.3, 0.42, 0.3) * k, V(s * 1.6 - s * 0.42 * k, -1.0, -0.3), skin)
		elseif hand == "Pad" then
			ball(rig, h, "Hand", V(0.7, 0.4, 0.8) * k, V(s * 1.6, -0.95, -0.1), skin)
			for i = 1, 3 do
				local x = s * 1.6 + (i - 2) * 0.3 * k
				ball(rig, h, "Finger", V(0.18, 0.18, 0.6) * k, V(x, -1.05, -0.5), skin, A(0, (i - 2) * 0.3, 0))
				ball(rig, h, "ToePad", V(0.3, 0.2, 0.3) * k, V(x + (i - 2) * 0.12, -1.07, -0.82), dim(skin, 1.25))
			end
		elseif hand == "Hoof" then
			ball(rig, h, "Fetlock", V(0.72, 0.6, 0.72) * k, V(s * 1.6, -0.9, -0.04), skin)
			put(rig, h, "Hoof", V(0.55, 0.82, 0.82) * k, V(s * 1.6, -1.3, -0.04), dark, CYL, UPRIGHT)
		elseif hand == "Fin" then
			ball(rig, h, "FinHand", V(0.38, 1.25, 0.95) * k, V(s * 1.62, -1.1, 0), skin, A(0.2, 0, s * 0.15))
		end
	end
end

-- A titan's legs: a thick thigh, a knee, a heavy shin (the feet are each
-- boss's own).
local function legs(rig, skin: Color3, dark: Color3, bulk: number?, shin: Color3?)
	local k = bulk or 1
	for _, s in SIDES do
		local side = LR[s]
		ball(rig, side .. "UpperLeg", "Thigh", V(1.2, 1.55, 1.25) * k, V(s * 0.6, -0.95, 0.02), skin)
		ball(rig, side .. "LowerLeg", "Knee", V(0.9, 0.75, 0.9) * k, V(s * 0.6, -1.55, -0.12), dark)
		ball(rig, side .. "LowerLeg", "Shin", V(0.92, 1.3, 0.95) * k, V(s * 0.6, -2.12, 0.02), shin or skin)
	end
end

-- A turn whose X axis runs along `dir`.
local function along(dir: Vector3): CFrame
	local x = dir.Unit
	local ref = if math.abs(x.Y) > 0.95 then V(0, 0, 1) else V(0, 1, 0)
	local z = x:Cross(ref).Unit
	return CFrame.fromMatrix(V(0, 0, 0), x, z:Cross(x).Unit, z)
end

-- A rod (a cylinder) from `a` to `b` in the body's space, on `bone`.
local function rod(rig, bone: string, name: string, a: Vector3, b: Vector3, thick: number, color: Color3)
	return put(rig, bone, name, V((b - a).Magnitude, thick, thick), (a + b) / 2, color, CYL, along(b - a))
end

-- A flat triangle `a`, `b`, `c` in the body's space, of two wedges (a wing's
-- membrane between its spars, a fin, a peel). Adds them to `list`.
local function tri(
	rig,
	bone: string,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color3,
	thick: number,
	list
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local one = put(
		rig,
		bone,
		name,
		V(thick, height, math.abs(ab:Dot(back))),
		(a + b) / 2,
		color,
		"Wedge",
		CFrame.fromMatrix(V(0, 0, 0), right, up, back)
	)
	local two = put(
		rig,
		bone,
		name,
		V(thick, height, math.abs(ac:Dot(back))),
		(a + c) / 2,
		color,
		"Wedge",
		CFrame.fromMatrix(V(0, 0, 0), -right, up, -back)
	)
	if list then
		table.insert(list, one)
		table.insert(list, two)
	end
	return one, two
end

-- Webbed feet: three long toes with a web between, and claws.
local function webFeet(rig, skin: Color3, web: Color3, nail: Color3, k: number?)
	k = k or 1
	for _, s in SIDES do
		local f = LR[s] .. "Foot"
		ball(rig, f, "Instep", V(0.7, 0.45, 0.9) * k, V(s * 0.62, -2.68, -0.15), skin)
		ball(rig, f, "Web", V(1.5, 0.14, 1.25) * k, V(s * 0.62, -2.82, -0.75 * k), web)
		for i = 1, 3 do
			local x = s * 0.62 + (i - 2) * 0.5 * k
			ball(rig, f, "Toe", V(0.24, 0.24, 1.0) * k, V(x, -2.78, -0.75 * k), skin, A(0, (i - 2) * -0.35, 0))
			put(
				rig,
				f,
				"Claw",
				V(0.12, 0.2, 0.26) * k,
				V(x + (i - 2) * 0.12, -2.8, -1.3 * k),
				nail,
				"Wedge",
				A(-math.pi / 2, 0, 0)
			)
		end
	end
end

-- Hooves under long legs.
local function hoofFeet(rig, skin: Color3, hoof: Color3, k: number?)
	k = k or 1
	for _, s in SIDES do
		local f = LR[s] .. "Foot"
		ball(rig, f, "Fetlock", V(0.75, 0.55, 0.75) * k, V(s * 0.6, -2.55, -0.05), skin)
		put(rig, f, "Hoof", V(0.5, 0.95, 0.95) * k, V(s * 0.6, -2.72, -0.12), hoof, CYL, UPRIGHT)
		put(rig, f, "HoofCleft", V(0.06, 0.52, 0.3) * k, V(s * 0.6, -2.72, -0.58 * k), INK)
	end
end

-- A big clawed foot (a paw): the sole, three toes and claws.
local function pawFeet(rig, skin: Color3, nail: Color3, k: number?)
	k = k or 1
	for _, s in SIDES do
		local f = LR[s] .. "Foot"
		ball(rig, f, "Paw", V(1.0, 0.55, 1.35) * k, V(s * 0.62, -2.68, -0.25), skin)
		for i = 1, 3 do
			local x = s * 0.62 + (i - 2) * 0.32 * k
			ball(rig, f, "Toe", V(0.36, 0.36, 0.42) * k, V(x, -2.75, -0.86 * k), skin)
			put(rig, f, "Claw", V(0.14, 0.3, 0.26) * k, V(x, -2.84, -1.1 * k), nail, "Wedge", A(-math.pi / 2, 0, 0))
		end
	end
end

-- Arms of wood: a knot at the shoulder, a branch down to a knotted elbow,
-- a thicker one to the wrist, a gnarled fist and `claws` twigs for claws.
local function branchArms(rig, bark: Color3, knot: Color3, k: number, claws: number)
	for _, s in SIDES do
		local side = LR[s]
		local upper, lower, hand = side .. "UpperArm", side .. "LowerArm", side .. "Hand"
		local shoulder, elbow, wrist = V(s * 1.5, 1.45, 0), V(s * 1.62, 0.3, -0.05), V(s * 1.62, -0.62, -0.1)
		wood(ball(rig, upper, "Knot", V(1.15, 1.05, 1.15) * k, shoulder, knot))
		wood(rod(rig, upper, "Branch", shoulder, elbow, 0.74 * k, bark))
		wood(ball(rig, lower, "Knot", V(0.86, 0.74, 0.86) * k, elbow, knot))
		wood(rod(rig, lower, "Branch", elbow, wrist, 0.9 * k, bark))
		wood(ball(rig, hand, "Burl", V(0.98, 0.82, 0.98) * k, wrist + V(0, -0.32, -0.02), knot))
		for i = 1, claws do
			local x = (i - (claws + 1) / 2) * 0.27 * k
			local from = wrist + V(x, -0.55, -0.22)
			wood(rod(rig, hand, "TwigClaw", from, from + V(x * 0.4, -0.6, -0.38), 0.16 * k, bark))
		end
	end
end

-- Rift-iron armor: a spiked pauldron on each shoulder and a bracer round
-- each forearm (dark iron trimmed in its element's glow), and a belt with a
-- rift-stone buckle. `parts`: which ("Pauldrons", "Bracers", "Belt").
local IRON, IRON_DARK, IRON_LIGHT = C(72, 74, 86), C(40, 41, 48), C(132, 134, 146)
local function armor(rig, accent: Color3, parts, k: number?)
	k = k or 1
	for _, s in SIDES do
		local side = LR[s]
		if parts.Pauldrons then
			local upper = side .. "UpperArm"
			local x = s * 1.6 * k
			put(rig, upper, "Pauldron", V(1.5, 0.62, 1.5) * k, V(x, 1.62, 0.05), IRON, nil, A(0, 0, -s * 0.38)).Material =
				Enum.Material.Slate
			put(
				rig,
				upper,
				"PauldronLip",
				V(1.35, 0.3, 1.6) * k,
				V(x + s * 0.32 * k, 1.28, 0.05),
				IRON_DARK,
				nil,
				A(0, 0, -s * 0.75)
			).Material =
				Enum.Material.Slate
			neon(
				put(
					rig,
					upper,
					"PauldronGlow",
					V(1.5, 0.07, 0.08) * k,
					V(x, 1.62, -0.72 * k),
					accent,
					nil,
					A(0, 0, -s * 0.38)
				)
			)
			for i = 1, 3 do
				local z = (i - 2) * 0.45 * k
				local h = (if i == 2 then 1.0 else 0.72) * k
				put(
					rig,
					upper,
					"Spike",
					V(0.2, h, 0.38) * k,
					V(x + s * 0.12, 1.95 + h * 0.4, z),
					IRON_LIGHT,
					"Wedge",
					A(0, s * math.pi / 2, s * 0.35)
				).Material =
					Enum.Material.Slate
			end
		end
		if parts.Bracers then
			local lower = side .. "LowerArm"
			put(rig, lower, "Bracer", V(0.75, 1.12, 1.12) * k, V(s * 1.62, -0.42, -0.04), IRON, CYL, UPRIGHT).Material =
				Enum.Material.Slate
			neon(put(rig, lower, "BracerGlow", V(0.07, 1.14, 1.14) * k, V(s * 1.62, -0.2, -0.04), accent, CYL, UPRIGHT))
			for i = 1, 2 do
				put(
					rig,
					lower,
					"BracerSpike",
					V(0.16, 0.5, 0.3) * k,
					V(s * 2.2 * k, -0.62 + i * 0.32, 0),
					IRON_LIGHT,
					"Wedge",
					A(0, s * math.pi / 2, s * -1.4)
				).Material =
					Enum.Material.Slate
			end
		end
	end
	if parts.Belt then
		put(rig, "LowerTorso", "Belt", V(0.42, 2.6, 1.9) * k, V(0, -0.05, 0), C(64, 46, 36), CYL, UPRIGHT).Material =
			Enum.Material.Fabric
		put(rig, "LowerTorso", "Buckle", V(0.66, 0.54, 0.16) * k, V(0, -0.05, -0.95 * k), IRON).Material =
			Enum.Material.Slate
		neon(
			put(
				rig,
				"LowerTorso",
				"BuckleStone",
				V(0.3, 0.3, 0.12) * k,
				V(0, -0.05, -1.03 * k),
				accent,
				nil,
				A(0, 0, math.pi / 4)
			)
		)
	end
end

-- Spiky tufts (fur, quills) standing out of `bone` at `spots` ({ at, turn, size }).
local function tufts(rig, bone: string, color: Color3, spots)
	for _, t in spots do
		put(rig, bone, "Tuft", t[3] or V(0.22, 0.6, 0.5), t[1], color, "Wedge", t[2])
	end
end

-- The Rift breaking out of it: dark crystal shards out of its back (each a
-- glass blade, a point and a glowing seam of its element), and glowing
-- cracks (`cracks`: { bone, size, at, turn }).
local function riftMarks(rig, accent: Color3, shards, cracks)
	for i, sh in shards do
		local at, len, w, tilt = sh[1], sh[2], sh[3], sh[4]
		local crystal = put(
			rig,
			"UpperTorso",
			"RiftShard",
			V(w, len, w * 0.7),
			at,
			if i % 2 == 0 then RIFT_EDGE else RIFT,
			nil,
			tilt
		)
		crystal.Material = Enum.Material.Glass
		crystal.Reflectance = 0.15
		put(
			rig,
			"UpperTorso",
			"RiftShardTip",
			V(w, w * 1.1, w * 0.7),
			at,
			RIFT,
			"Wedge",
			tilt * CFrame.new(0, len / 2 + w * 0.55, 0)
		)
		neon(put(rig, "UpperTorso", "RiftSeam", V(w * 0.22, len * 0.85, w * 0.75), at, accent, nil, tilt))
	end
	for _, c in cracks or {} do
		neon(put(rig, c[1], "RiftVein", c[2], c[3], accent, nil, c[4]))
	end
end

-- A tail from the hips curling up behind, `n` segments, tapering; it sways.
-- Returns where its tip is (in the body's space).
local function tail(rig, color: Color3, n: number, thick: number, lift: number, reach: number?): Vector3
	local list, points = {}, {}
	local step = (reach or 2.8) / n
	for i = 0, n do
		local k = i / n
		points[i] = V(0, -0.35 + k * k * lift, 0.7 + i * step)
	end
	for i = 1, n do
		local a, b = points[i - 1], points[i]
		local size = thick * (1 - (i - 1) / n * 0.55)
		local along = b - a
		local pitch = math.atan2(along.Y, along.Z)
		table.insert(
			list,
			ball(
				rig,
				"LowerTorso",
				"Tail",
				V(size, size, along.Magnitude + size * 0.9),
				(a + b) / 2,
				color,
				A(-pitch, 0, 0)
			)
		)
	end
	group(rig, list, "Tail", "LowerTorso", V(0, -0.35, 0.7), 1)
	return points[n]
end
-- A part that sways with the tail (its tip, a fin).
local function onTail(rig, p)
	return animate(p, "Tail", pivotOn(rig, "LowerTorso", V(0, -0.35, 0.7)), 1)
end

-- Gattini Gemellini ------------------------------------------------------------------------------------
-- A two-headed sabre cat of storm-grey stone: a deep chest and stooped
-- shoulders, tabby stripes, two snarling heads with sabre fangs and
-- lightning eyes, huge clawed paws, a long tail crackling at its tip.
local CAT = { Fur = C(104, 108, 122), Dark = C(58, 60, 70), Cream = C(206, 198, 180), Pink = C(196, 112, 120) }
local function catHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local y, z = 2.25, -0.55
	local function add(p)
		table.insert(list, p)
		return p
	end
	add(ball(rig, "UpperTorso", "CatSkull", V(1.45, 1.2, 1.3), V(x, y, z), CAT.Fur))
	add(ball(rig, "UpperTorso", "CatCheeks", V(1.6, 0.75, 1.0), V(x, y - 0.32, z - 0.15), CAT.Fur))
	add(ball(rig, "UpperTorso", "CatMuzzle", V(0.82, 0.48, 0.55), V(x, y - 0.38, z - 0.58), CAT.Cream))
	add(ball(rig, "UpperTorso", "CatNose", V(0.26, 0.16, 0.16), V(x, y - 0.18, z - 0.82), CAT.Pink))
	add(ball(rig, "UpperTorso", "Snarl", V(0.6, 0.18, 0.25), V(x, y - 0.6, z - 0.7), C(70, 20, 28)))
	for i = 1, 2 do
		-- (stripes across the brow)
		add(
			put(
				rig,
				"UpperTorso",
				"Stripe",
				V(0.95 - i * 0.2, 0.08, 0.5),
				V(x, y + 0.42 + i * 0.1, z - 0.28 + i * 0.12),
				CAT.Dark,
				nil,
				A(-0.5, 0, 0)
			)
		)
	end
	eyes(rig, "UpperTorso", list, V(x, y + 0.08, z - 0.55), 0.3, 0.3, accent)
	for _, s in SIDES do
		add(
			put(
				rig,
				"UpperTorso",
				"Sabre",
				V(0.13, 0.62, 0.2),
				V(x + s * 0.22, y - 0.86, z - 0.72),
				IVORY,
				"Wedge",
				A(0, 0, math.pi)
			)
		)
		add(
			put(
				rig,
				"UpperTorso",
				"CatEar",
				V(0.16, 0.62, 0.56),
				V(x + s * 0.48, y + 0.62, z + 0.12),
				CAT.Fur,
				"Wedge",
				A(0.35, math.pi, s * 0.5)
			)
		)
		add(
			put(
				rig,
				"UpperTorso",
				"InnerEar",
				V(0.06, 0.42, 0.34),
				V(x + s * 0.46, y + 0.58, z + 0.02),
				CAT.Pink,
				"Wedge",
				A(0.35, math.pi, s * 0.5)
			)
		)
		for i = 1, 2 do
			add(
				put(
					rig,
					"UpperTorso",
					"Whisker",
					V(0.75, 0.035, 0.035),
					V(x + s * 0.68, y - 0.35 + (i - 1.5) * 0.1, z - 0.62),
					WHITE,
					nil,
					A(0, s * 0.2, s * (i - 1.5) * 0.3)
				)
			)
		end
	end
	group(rig, list, "Head", "UpperTorso", V(x, 1.65, -0.2), side)
end
local function twinCat(rig, accent)
	-- A stooped stone chest, shoulders hunched up round two necks.
	ball(rig, "UpperTorso", "Chest", V(2.9, 2.35, 2.0), V(0, 0.95, -0.12), CAT.Fur)
	ball(rig, "UpperTorso", "Hunch", V(2.7, 1.25, 1.55), V(0, 1.7, 0.35), CAT.Dark)
	-- A cream ruff under the chins, in a V.
	for _, s in SIDES do
		ball(rig, "UpperTorso", "Ruff", V(1.25, 0.55, 0.5), V(s * 0.4, 1.12, -1.0), CAT.Cream, A(0, 0, s * 0.55))
	end
	ball(rig, "UpperTorso", "ChestFur", V(0.7, 0.9, 0.42), V(0, 0.7, -1.02), CAT.Cream)
	ball(rig, "LowerTorso", "Belly", V(2.45, 1.3, 1.75), V(0, -0.15, 0), CAT.Fur)
	for i = 1, 4 do
		-- (tabby stripes round its back and flanks)
		ball(
			rig,
			"UpperTorso",
			"Stripe",
			V(2.95 - i * 0.1, 0.2, 1.85 - i * 0.06),
			V(0, 1.65 - i * 0.38, 0.12),
			CAT.Dark,
			A(0.35, 0, 0)
		)
	end
	-- Ruffs of fur at the neck and down the spine.
	tufts(rig, "UpperTorso", CAT.Fur, {
		{ V(-1.15, 1.55, -0.35), A(0.3, 0, 0.9), V(0.25, 0.75, 0.6) },
		{ V(1.15, 1.55, -0.35), A(0.3, 0, -0.9), V(0.25, 0.75, 0.6) },
		{ V(-1.25, 1.1, -0.55), A(0.5, 0, 1.2), V(0.22, 0.6, 0.5) },
		{ V(1.25, 1.1, -0.55), A(0.5, 0, -1.2), V(0.22, 0.6, 0.5) },
	})
	for _, s in SIDES do
		ball(rig, "UpperTorso", "Neck", V(0.95, 0.9, 0.95), V(s * 0.74, 1.75, -0.3), CAT.Fur)
		headOut(s * 0.8, s, 0.25, function(x, side)
			catHead(rig, x, side, accent)
		end)
	end
	arms(rig, CAT.Fur, CAT.Dark, "Claw", 1.05, accent)
	legs(rig, CAT.Fur, CAT.Dark, 1.05)
	pawFeet(rig, CAT.Fur, IVORY, 1.05)
	armor(rig, accent, { Pauldrons = true, Bracers = true, Belt = true })
	local tip = tail(rig, CAT.Fur, 7, 0.55, 2.2, 3.0)
	onTail(rig, neon(ball(rig, "LowerTorso", "TailSpark", V(0.4, 0.4, 0.4), tip, accent)))
	riftMarks(rig, accent, {
		{ V(-0.75, 1.9, 0.95), 1.5, 0.42, A(-0.5, 0, 0.35) },
		{ V(0.1, 2.05, 1.0), 1.9, 0.5, A(-0.6, 0, -0.05) },
		{ V(0.85, 1.75, 0.9), 1.3, 0.38, A(-0.45, 0, -0.45) },
	}, {
		{ "UpperTorso", V(0.1, 1.1, 0.06), V(0.55, 0.9, -0.92), A(0, 0, 0.5) },
		{ "UpperTorso", V(0.08, 0.8, 0.06), V(-0.45, 0.3, -0.95), A(0, 0, -0.4) },
	})
end

-- Bombardiro Drago -----------------------------------------------------------------------------------------
-- A crocodile brute: a long armoured head with a jaw that snaps, horns
-- swept back, fire in its eyes and down its throat; bony plates down a
-- hunched back, great bat wings, a heavy tail.
local CROC = {
	Hide = C(76, 94, 50),
	Dark = C(44, 56, 30),
	Belly = C(198, 182, 132),
	Membrane = C(112, 40, 32),
	Spar = C(58, 40, 30),
	Horn = C(214, 200, 168),
}
local function batWing(rig, s: number, accent: Color3)
	local list = {}
	local root = V(s * 0.8, 1.95, 0.75)
	local elbow = root + V(s * 1.35, 1.25, 0.55)
	local tips = {
		elbow + V(s * 1.45, 0.55, 0.35),
		elbow + V(s * 1.55, -0.75, 0.45),
		elbow + V(s * 0.95, -1.75, 0.45),
		root + V(s * 0.55, -1.55, 0.2),
	}
	table.insert(list, rod(rig, "UpperTorso", "WingArm", root, elbow, 0.26, CROC.Spar))
	for i = 1, 3 do
		table.insert(list, rod(rig, "UpperTorso", "WingFinger", elbow, tips[i], 0.15 - i * 0.02, CROC.Spar))
	end
	-- The membrane between them, its trailing edge scalloped (each panel
	-- dips in toward the elbow between two fingers).
	for i = 1, 3 do
		local dip = elbow + ((tips[i] + tips[i + 1]) / 2 - elbow) * 0.72
		tri(rig, "UpperTorso", "WingMembrane", elbow, tips[i], dip, CROC.Membrane, 0.05, list)
		tri(rig, "UpperTorso", "WingMembrane", elbow, dip, tips[i + 1], CROC.Membrane, 0.05, list)
	end
	tri(rig, "UpperTorso", "WingMembrane", root, elbow, tips[4], CROC.Membrane, 0.05, list)
	table.insert(
		list,
		put(rig, "UpperTorso", "WingThumb", V(0.14, 0.42, 0.26), elbow + V(0, 0.22, 0), CROC.Horn, "Wedge")
	)
	for i = 1, 3 do
		table.insert(
			list,
			put(
				rig,
				"UpperTorso",
				"WingTalon",
				V(0.12, 0.3, 0.2),
				tips[i],
				CROC.Horn,
				"Wedge",
				along(tips[i] - elbow) * A(0, 0, -math.pi / 2)
			)
		)
	end
	group(rig, list, "Wing", "UpperTorso", root, s)
end
local function dragonCroc(rig, accent)
	ball(rig, "UpperTorso", "Chest", V(2.9, 2.45, 2.05), V(0, 0.95, -0.1), CROC.Hide)
	ball(rig, "UpperTorso", "Hunch", V(2.6, 1.25, 1.55), V(0, 1.7, 0.4), CROC.Dark)
	ball(rig, "LowerTorso", "Belly", V(2.5, 1.35, 1.8), V(0, -0.15, 0), CROC.Hide)
	for i = 0, 4 do
		-- (the belly's scales, in rows)
		ball(
			rig,
			"UpperTorso",
			"BellyScale",
			V(1.45 - i * 0.08, 0.38, 0.55),
			V(0, 1.45 - i * 0.42, -0.88 + i * 0.03),
			CROC.Belly,
			A(-0.12, 0, 0)
		)
	end
	-- Bony plates in three rows down its back.
	for i = 0, 3 do
		for _, x in { -0.55, 0, 0.55 } do
			local h = if x == 0 then 0.5 else 0.36
			put(
				rig,
				"UpperTorso",
				"BackPlate",
				V(0.32, h, 0.42),
				V(x, 1.95 - i * 0.48, 0.95 + i * 0.05 - math.abs(x) * 0.15),
				CROC.Dark,
				"Wedge",
				A(-0.35, math.pi, 0)
			)
		end
	end
	ball(rig, "UpperTorso", "Neck", V(1.35, 1.0, 1.2), V(0, 1.85, -0.45), CROC.Hide)
	-- The head: a broad skull, a long snout, horns, the eyes up top.
	local head = {}
	local function add(p)
		table.insert(head, p)
		return p
	end
	add(ball(rig, "UpperTorso", "Skull", V(1.6, 1.05, 1.5), V(0, 2.35, -0.8), CROC.Hide))
	add(ball(rig, "UpperTorso", "Snout", V(1.1, 0.58, 2.15), V(0, 2.18, -2.0), CROC.Hide))
	add(ball(rig, "UpperTorso", "SnoutTop", V(0.7, 0.3, 1.8), V(0, 2.42, -1.9), CROC.Dark))
	for _, s in SIDES do
		add(ball(rig, "UpperTorso", "EyeRidge", V(0.48, 0.4, 0.6), V(s * 0.42, 2.72, -1.05), CROC.Dark))
		add(
			put(
				rig,
				"UpperTorso",
				"Horn",
				V(0.22, 0.95, 0.55),
				V(s * 0.55, 2.95, -0.35),
				CROC.Horn,
				"Wedge",
				A(-0.9, math.pi, s * 0.35)
			)
		)
		add(ball(rig, "UpperTorso", "Nostril", V(0.14, 0.1, 0.14), V(s * 0.2, 2.48, -2.95), INK))
		for i = 1, 4 do
			add(
				put(
					rig,
					"UpperTorso",
					"Tooth",
					V(0.1, 0.24, 0.12),
					V(s * 0.46, 1.86, -1.25 - i * 0.36),
					IVORY,
					"Wedge",
					A(0, 0, math.pi)
				)
			)
		end
	end
	eyes(rig, "UpperTorso", head, V(0, 2.8, -1.32), 0.42, 0.28, accent)
	group(rig, head, "Head", "UpperTorso", V(0, 1.85, -0.45), 1)
	local jaw = {}
	table.insert(jaw, ball(rig, "UpperTorso", "LowerJaw", V(1.0, 0.36, 2.0), V(0, 1.82, -1.9), CROC.Hide))
	table.insert(jaw, neon(ball(rig, "UpperTorso", "FireThroat", V(0.62, 0.14, 1.5), V(0, 1.97, -1.75), accent)))
	for _, s in SIDES do
		for i = 1, 3 do
			table.insert(
				jaw,
				put(
					rig,
					"UpperTorso",
					"LowerTooth",
					V(0.09, 0.2, 0.11),
					V(s * 0.4, 2.02, -1.3 - i * 0.42),
					IVORY,
					"Wedge"
				)
			)
		end
	end
	group(rig, jaw, "Jaw", "UpperTorso", V(0, 1.95, -0.95), 1)
	batWing(rig, -1, accent)
	batWing(rig, 1, accent)
	arms(rig, CROC.Hide, CROC.Dark, "Claw", 1.05, CROC.Horn)
	legs(rig, CROC.Hide, CROC.Dark, 1.08)
	pawFeet(rig, CROC.Hide, CROC.Horn, 1.1)
	armor(rig, accent, { Bracers = true, Belt = true })
	tail(rig, CROC.Hide, 6, 1.0, 0.5, 3.0)
	riftMarks(rig, accent, {
		{ V(-0.35, 1.25, 1.0), 1.2, 0.36, A(-0.9, 0, 0.3) },
		{ V(0.35, 1.2, 1.0), 1.4, 0.4, A(-0.95, 0, -0.25) },
	}, {
		{ "UpperTorso", V(0.08, 0.9, 0.06), V(-0.62, 0.95, -0.98), A(0, 0, 0.4) },
		{ "UpperTorso", V(0.08, 0.7, 0.06), V(0.6, 0.55, -0.98), A(0, 0, -0.5) },
	})
end

-- Paperotti Gemelli --------------------------------------------------------------------------------------
-- A war-duck: a barrel of grey down with a chestnut breast scaled in
-- feathers, two drakes' heads on thick necks with serrated bills and frost
-- in their eyes, wings for arms ending in fans of long primaries, orange
-- legs and clawed webbed feet, a curled drake's tail.
local DUCK = {
	Grey = C(128, 132, 140),
	Dark = C(74, 78, 86),
	Breast = C(118, 56, 38),
	BreastDark = C(104, 48, 33),
	Head = C(26, 86, 58),
	Sheen = C(40, 110, 92),
	Bill = C(222, 146, 46),
	BillDark = C(150, 92, 30),
	Leg = C(214, 120, 40),
	Primary = C(52, 56, 66),
}
local function drakeHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	local y, z = 2.6, -0.6
	add(ball(rig, "UpperTorso", "DrakeNeck", V(0.95, 1.3, 0.95), V(x, 1.95, -0.35), DUCK.Head))
	add(ball(rig, "UpperTorso", "WhiteCollar", V(1.08, 0.22, 1.08), V(x, 1.5, -0.32), WHITE))
	add(ball(rig, "UpperTorso", "DrakeHead", V(1.4, 1.2, 1.5), V(x, y, z), DUCK.Head))
	add(ball(rig, "UpperTorso", "Sheen", V(1.1, 0.6, 1.0), V(x, y + 0.3, z + 0.18), DUCK.Sheen))
	add(ball(rig, "UpperTorso", "Bill", V(0.85, 0.28, 1.2), V(x, y - 0.15, z - 1.0), DUCK.Bill))
	add(ball(rig, "UpperTorso", "BillTip", V(0.36, 0.16, 0.2), V(x, y - 0.1, z - 1.56), DUCK.BillDark))
	for i = 1, 3 do
		-- (a serrated edge: the bill's teeth)
		for _, s in SIDES do
			add(
				put(
					rig,
					"UpperTorso",
					"BillTooth",
					V(0.07, 0.16, 0.12),
					V(x + s * 0.36, y - 0.3, z - 0.65 - i * 0.24),
					WHITE,
					"Wedge",
					A(0, 0, math.pi)
				)
			)
		end
	end
	eyes(rig, "UpperTorso", list, V(x, y + 0.15, z - 0.6), 0.34, 0.26, accent)
	add(
		put(
			rig,
			"UpperTorso",
			"Crest",
			V(0.14, 0.5, 0.75),
			V(x, y + 0.65, z + 0.25),
			DUCK.Head,
			"Wedge",
			A(0.2, math.pi, 0)
		)
	)
	group(rig, list, "Head", "UpperTorso", V(x, 1.55, -0.3), side)
	local beak = { ball(rig, "UpperTorso", "LowerBill", V(0.72, 0.18, 1.0), V(x, y - 0.38, z - 0.92), DUCK.BillDark) }
	group(rig, beak, "Jaw", "UpperTorso", V(x, y - 0.3, z - 0.35), side)
end
local function twinDuck(rig, accent)
	-- A chestnut breast, the grey of its flanks and back round it.
	ball(rig, "UpperTorso", "Barrel", V(3.1, 2.6, 2.4), V(0, 0.9, 0.05), DUCK.Breast)
	ball(rig, "UpperTorso", "Back", V(3.0, 2.4, 1.8), V(0, 0.95, 0.45), DUCK.Grey)
	ball(rig, "UpperTorso", "Underside", V(2.7, 1.1, 2.1), V(0, 0.0, -0.05), DUCK.Grey)
	ball(rig, "LowerTorso", "Bottom", V(2.6, 1.3, 2.2), V(0, -0.15, 0.1), DUCK.Grey)
	-- The drake's curl and a fan of tail feathers.
	for i = -2, 2 do
		put(
			rig,
			"LowerTorso",
			"TailFeather",
			V(0.3, 0.12, 1.1),
			V(i * 0.3, 0.05, 1.3),
			DUCK.Dark,
			nil,
			A(0.35, i * 0.2, 0)
		)
	end
	put(rig, "LowerTorso", "DrakeCurl", V(0.16, 0.5, 0.5), V(0, 0.55, 1.45), DUCK.Head, "Wedge", A(0, math.pi, 0))
	for _, s in SIDES do
		headOut(s * 0.92, s, 0.3, function(x, side)
			drakeHead(rig, x, side, accent)
		end)
	end
	-- Wings for arms, folded: rows of coverts over the shoulder, the
	-- secondaries with the speculum glowing, the long primaries lying back
	-- to a point behind.
	for _, s in SIDES do
		local side = LR[s]
		local upper, lower = side .. "UpperArm", side .. "LowerArm"
		ball(rig, upper, "WingShoulder", V(1.15, 1.55, 1.5), V(s * 1.6, 1.05, 0.1), DUCK.Grey)
		for i = 1, 3 do
			ball(
				rig,
				upper,
				"Covert",
				V(0.42, 0.62, 1.45 - i * 0.12),
				V(s * (1.9 + i * 0.04), 1.5 - i * 0.36, 0.12 + i * 0.06),
				if i == 2 then DUCK.Grey else DUCK.Dark,
				A(0.15, 0, s * 0.12)
			)
		end
		ball(rig, lower, "Secondaries", V(0.55, 1.8, 1.5), V(s * 1.72, -0.15, 0.3), DUCK.Dark, A(-0.35, 0, 0))
		neon(ball(rig, lower, "Speculum", V(0.12, 0.42, 1.15), V(s * 2.0, 0.2, 0.3), accent, A(-0.35, 0, 0)))
		ball(rig, lower, "SpeculumEdge", V(0.1, 0.1, 1.2), V(s * 2.0, -0.02, 0.35), WHITE, A(-0.35, 0, 0))
		for i = 1, 4 do
			ball(
				rig,
				lower,
				"Primary",
				V(0.18, 2.6 - i * 0.22, 0.6),
				V(s * (1.74 + i * 0.02), -0.95 + i * 0.1, 0.62 + i * 0.1),
				if i % 2 == 0 then DUCK.Primary else DUCK.Dark,
				A(-0.8, 0, 0)
			)
		end
	end
	legs(rig, DUCK.Grey, DUCK.Dark, 1.0, DUCK.Leg)
	webFeet(rig, DUCK.Leg, dim(DUCK.Leg, 0.82), IVORY, 1.15)
	riftMarks(rig, accent, {
		{ V(-0.6, 1.95, 1.0), 1.3, 0.4, A(-0.55, 0, 0.3) },
		{ V(0.05, 2.1, 1.05), 1.6, 0.46, A(-0.6, 0, 0) },
		{ V(0.65, 1.9, 1.0), 1.15, 0.36, A(-0.5, 0, -0.35) },
	})
end

-- Ranocchio Avocadino -------------------------------------------------------------------------------------
-- Two toads riding a halved avocado: its pebbly black skin, its pale
-- flesh, and the stone in the middle split by glowing poison; wide flat
-- heads with great bulging eyes, throats that swell, long frog arms and
-- heavy frog legs.
local AVO = {
	Skin = C(38, 56, 30),
	Bump = C(28, 42, 22),
	Rim = C(130, 162, 62),
	Flesh = C(194, 206, 110),
	Stone = C(108, 64, 36),
	Frog = C(86, 138, 56),
	FrogDark = C(54, 96, 38),
	FrogBelly = C(200, 206, 146),
	Lip = C(48, 30, 30),
}
local function toadHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	local y, z = 2.45, -0.35
	add(ball(rig, "UpperTorso", "ToadHead", V(1.8, 1.05, 1.75), V(x, y, z), AVO.Frog))
	add(ball(rig, "UpperTorso", "ToadBack", V(1.4, 0.68, 1.2), V(x, y + 0.28, z + 0.4), AVO.FrogDark))
	add(ball(rig, "UpperTorso", "Lips", V(1.68, 0.18, 1.28), V(x, y - 0.3, z - 0.45), AVO.Lip))
	for _, s in SIDES do
		local ex = x + s * 0.5
		add(ball(rig, "UpperTorso", "EyeBulge", V(0.72, 0.72, 0.72), V(ex, y + 0.5, z - 0.4), AVO.Frog))
		add(neon(ball(rig, "UpperTorso", "ToadEye", V(0.56, 0.52, 0.34), V(ex, y + 0.55, z - 0.66), accent)))
		add(ball(rig, "UpperTorso", "ToadPupil", V(0.38, 0.12, 0.08), V(ex, y + 0.55, z - 0.83), INK))
		add(
			put(
				rig,
				"UpperTorso",
				"ToadBrow",
				V(0.72, 0.16, 0.34),
				V(ex - s * 0.04, y + 0.9, z - 0.55),
				AVO.FrogDark,
				nil,
				A(0, 0, s * 0.38)
			)
		)
		for i = 1, 2 do
			add(
				ball(
					rig,
					"UpperTorso",
					"Wart",
					V(0.16, 0.12, 0.16),
					V(x + s * (0.3 + i * 0.25), y + 0.22, z + 0.1 + i * 0.2),
					AVO.FrogDark
				)
			)
		end
	end
	group(rig, list, "Head", "UpperTorso", V(x, 1.95, -0.1), side)
	local throat = { ball(rig, "UpperTorso", "Throat", V(1.3, 0.5, 1.0), V(x, y - 0.45, z - 0.2), AVO.FrogBelly) }
	group(rig, throat, "Jaw", "UpperTorso", V(x, y - 0.3, z + 0.3), side)
end
local function frogAvocado(rig, accent)
	ball(rig, "UpperTorso", "AvocadoSkin", V(3.1, 3.3, 2.4), V(0, 0.55, 0.1), AVO.Skin)
	ball(rig, "LowerTorso", "AvocadoBottom", V(2.7, 1.4, 2.2), V(0, -0.25, 0.1), AVO.Skin)
	-- The cut face, pear-shaped: wide below, narrow up top.
	ball(rig, "UpperTorso", "FleshRim", V(2.75, 2.3, 0.5), V(0, 0.2, -1.0), AVO.Rim)
	ball(rig, "UpperTorso", "FleshRim", V(1.95, 1.7, 0.5), V(0, 1.25, -0.98), AVO.Rim)
	ball(rig, "UpperTorso", "Flesh", V(2.5, 2.05, 0.45), V(0, 0.2, -1.08), AVO.Flesh)
	ball(rig, "UpperTorso", "Flesh", V(1.72, 1.5, 0.45), V(0, 1.25, -1.06), AVO.Flesh)
	ball(rig, "UpperTorso", "Stone", V(1.35, 1.5, 1.0), V(0, 0.25, -1.2), AVO.Stone)
	ball(rig, "UpperTorso", "StoneShine", V(0.3, 0.42, 0.12), V(0.3, 0.55, -1.68), C(160, 108, 66))
	-- The stone split by glowing poison, dripping.
	neon(put(rig, "UpperTorso", "StoneCrack", V(0.08, 1.2, 0.1), V(-0.05, 0.25, -1.68), accent, nil, A(0, 0, 0.18)))
	neon(put(rig, "UpperTorso", "StoneCrack", V(0.06, 0.55, 0.1), V(0.22, 0.05, -1.66), accent, nil, A(0, 0, -0.6)))
	for i, at in { V(-0.75, -0.55, -1.25), V(0.55, -0.75, -1.25), V(0.1, -0.95, -1.3) } do
		neon(ball(rig, "UpperTorso", "PoisonDrip", V(0.18, 0.3 + i * 0.05, 0.18), at, accent))
	end
	for i = 1, 10 do
		local a = i * 2.39996
		ball(
			rig,
			"UpperTorso",
			"SkinBump",
			V(0.3, 0.3, 0.2),
			V(math.cos(a) * 1.35, -0.55 + (i % 5) * 0.55, 0.35 + math.sin(a) * 0.75),
			AVO.Bump
		)
	end
	for _, s in SIDES do
		headOut(s * 0.95, s, 0.3, function(x, side)
			toadHead(rig, x, side, accent)
		end)
	end
	arms(rig, AVO.Frog, AVO.FrogDark, "Pad", 0.95)
	legs(rig, AVO.Frog, AVO.FrogDark, 1.15)
	webFeet(rig, AVO.Frog, AVO.FrogDark, AVO.FrogBelly, 1.2)
	riftMarks(rig, accent, {
		{ V(-0.7, 1.7, 1.05), 1.4, 0.42, A(-0.55, 0, 0.35) },
		{ V(0.1, 1.95, 1.1), 1.8, 0.48, A(-0.65, 0, -0.05) },
		{ V(0.8, 1.5, 1.0), 1.2, 0.36, A(-0.5, 0, -0.4) },
	})
end

-- Chimpanzini Bananini ----------------------------------------------------------------------------------
-- Three apes bursting out of a banana: a silverback's chest and long heavy
-- arms, the peel split down round its hips in petals, a gorilla's head
-- roaring low between two screaming chimps riding its shoulders, storm in
-- its eyes and veins.
local APE = {
	Fur = C(62, 48, 40),
	Dark = C(38, 30, 26),
	Silver = C(138, 134, 128),
	Skin = C(46, 40, 40),
	Face = C(184, 142, 108),
	Mouth = C(34, 10, 14),
	Peel = C(236, 194, 44),
	PeelInner = C(246, 234, 182),
	Ridge = C(196, 156, 40),
	PeelTip = C(78, 58, 32),
}
local function gorillaHead(rig, accent)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	local y, z = 2.1, -0.85
	add(ball(rig, "UpperTorso", "ApeSkull", V(1.55, 1.4, 1.45), V(0, y + 0.1, z + 0.15), APE.Fur))
	add(ball(rig, "UpperTorso", "Crest", V(0.42, 0.7, 1.25), V(0, y + 0.68, z + 0.3), APE.Fur))
	add(ball(rig, "UpperTorso", "ApeFace", V(1.2, 1.1, 0.6), V(0, y - 0.05, z - 0.48), APE.Skin))
	add(ball(rig, "UpperTorso", "BrowRidge", V(1.3, 0.34, 0.6), V(0, y + 0.32, z - 0.62), APE.Skin))
	add(ball(rig, "UpperTorso", "ApeMuzzle", V(1.05, 0.72, 0.7), V(0, y - 0.38, z - 0.78), APE.Skin))
	add(ball(rig, "UpperTorso", "Roar", V(0.78, 0.42, 0.3), V(0, y - 0.6, z - 1.0), APE.Mouth))
	for _, s in SIDES do
		add(ball(rig, "UpperTorso", "Nostril", V(0.2, 0.14, 0.1), V(s * 0.16, y - 0.16, z - 1.12), INK))
		add(ball(rig, "UpperTorso", "ApeEar", V(0.18, 0.36, 0.3), V(s * 0.8, y + 0.05, z + 0.1), APE.Skin))
		add(
			put(
				rig,
				"UpperTorso",
				"Fang",
				V(0.11, 0.32, 0.14),
				V(s * 0.26, y - 0.52, z - 1.1),
				IVORY,
				"Wedge",
				A(0, 0, math.pi)
			)
		)
	end
	eyes(rig, "UpperTorso", list, V(0, y + 0.1, z - 0.82), 0.3, 0.22, accent)
	group(rig, list, "Head", "UpperTorso", V(0, 1.7, -0.4), 0.3)
	local jaw = { ball(rig, "UpperTorso", "ApeChin", V(0.95, 0.36, 0.62), V(0, y - 0.86, z - 0.82), APE.Skin) }
	for _, s in SIDES do
		table.insert(
			jaw,
			put(rig, "UpperTorso", "LowerFang", V(0.1, 0.26, 0.13), V(s * 0.22, y - 0.7, z - 1.05), IVORY, "Wedge")
		)
	end
	group(rig, jaw, "Jaw", "UpperTorso", V(0, y - 0.55, z - 0.3), 0.3)
end
local function chimpHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	local y, z = 2.62, -0.2
	add(ball(rig, "UpperTorso", "ChimpSkull", V(1.05, 1.0, 1.0), V(x, y + 0.08, z + 0.1), APE.Fur))
	add(ball(rig, "UpperTorso", "ChimpFace", V(0.86, 0.86, 0.45), V(x, y - 0.05, z - 0.3), APE.Face))
	add(ball(rig, "UpperTorso", "ChimpMuzzle", V(0.74, 0.52, 0.55), V(x, y - 0.32, z - 0.5), APE.Face))
	add(ball(rig, "UpperTorso", "Scream", V(0.44, 0.36, 0.2), V(x, y - 0.36, z - 0.78), APE.Mouth))
	for _, s in SIDES do
		add(ball(rig, "UpperTorso", "ChimpEar", V(0.12, 0.46, 0.42), V(x + s * 0.56, y + 0.05, z), APE.Face))
		add(
			put(
				rig,
				"UpperTorso",
				"Fang",
				V(0.07, 0.18, 0.09),
				V(x + s * 0.13, y - 0.24, z - 0.82),
				IVORY,
				"Wedge",
				A(0, 0, math.pi)
			)
		)
	end
	-- (its hair on end)
	for i = -1, 1 do
		add(
			put(
				rig,
				"UpperTorso",
				"Tuft",
				V(0.14, 0.42, 0.36),
				V(x + i * 0.22, y + 0.62, z + 0.12),
				APE.Fur,
				"Wedge",
				A(-0.3, 0, -i * 0.5)
			)
		)
	end
	eyes(rig, "UpperTorso", list, V(x, y + 0.08, z - 0.5), 0.2, 0.17, accent)
	group(rig, list, "Head", "UpperTorso", V(x, 2.05, -0.1), side)
	local jaw = { ball(rig, "UpperTorso", "ChimpChin", V(0.52, 0.22, 0.4), V(x, y - 0.6, z - 0.62), APE.Face) }
	group(rig, jaw, "Jaw", "UpperTorso", V(x, y - 0.4, z - 0.2), side)
end
-- A petal of peel hanging off the hips at angle `a` round them (0: in front),
-- flaring out at its foot: yellow outside, pale inside, ridged, its tip brown.
local function peel(rig, a: number)
	local out = V(math.sin(a), 0, -math.cos(a))
	local across = V(math.cos(a), 0, math.sin(a))
	local up = (V(0, 1, 0) * math.cos(0.28) - out * math.sin(0.28)).Unit
	local turn = CFrame.fromMatrix(V(0, 0, 0), across, up, across:Cross(up))
	local at = V(0, -1.0, 0) + out * 1.4
	put(rig, "LowerTorso", "Peel", V(1.55, 2.0, 0.24), at, APE.Peel, BALL, turn)
	put(rig, "LowerTorso", "PeelInner", V(1.3, 1.8, 0.12), at - out * 0.1, APE.PeelInner, BALL, turn)
	put(rig, "LowerTorso", "PeelRidge", V(0.1, 1.8, 0.29), at, APE.Ridge, nil, turn)
	put(rig, "LowerTorso", "PeelTip", V(0.42, 0.32, 0.3), at - up * 0.95, APE.PeelTip, BALL, turn)
end
local function chimpanzini(rig, accent)
	ball(rig, "UpperTorso", "Chest", V(3.2, 2.5, 2.15), V(0, 0.9, -0.1), APE.Fur)
	-- A silverback's saddle, hunched high.
	ball(rig, "UpperTorso", "Saddle", V(3.0, 1.55, 1.85), V(0, 1.72, 0.3), APE.Silver)
	for _, s in SIDES do
		ball(rig, "UpperTorso", "Pec", V(1.25, 0.9, 0.55), V(s * 0.58, 1.1, -1.0), APE.Skin, A(0, 0, s * 0.12))
		-- (a chimp's shoulders, climbing out over its own)
		ball(rig, "UpperTorso", "ChimpBody", V(0.95, 0.75, 0.85), V(s * 1.28, 2.08, 0.02), APE.Fur)
	end
	ball(rig, "LowerTorso", "Belly", V(2.55, 1.35, 1.85), V(0, -0.15, 0), APE.Fur)
	-- (the banana's end still whole round its waist, the peel split below)
	put(rig, "LowerTorso", "Banana", V(0.75, 2.75, 2.75), V(0, -0.3, 0), APE.Peel, CYL, UPRIGHT)
	put(rig, "LowerTorso", "BananaRim", V(0.1, 2.6, 2.6), V(0, 0.08, 0), APE.PeelInner, CYL, UPRIGHT)
	for i = 0, 4 do
		peel(rig, (i + 0.5) / 5 * math.pi * 2)
	end
	tufts(rig, "UpperTorso", APE.Silver, {
		{ V(-1.2, 1.95, 0.55), A(0.4, 0, 0.8), V(0.25, 0.7, 0.55) },
		{ V(1.2, 1.95, 0.55), A(0.4, 0, -0.8), V(0.25, 0.7, 0.55) },
		{ V(0, 2.4, 0.75), A(0.6, 0, 0), V(0.25, 0.6, 0.6) },
	})
	gorillaHead(rig, accent)
	for _, s in SIDES do
		headOut(s * 1.3, s, 0.35, function(x, side)
			chimpHead(rig, x, side, accent)
		end)
	end
	arms(rig, APE.Fur, APE.Dark, "Fist", 1.22)
	armor(rig, accent, { Bracers = true }, 1.2)
	legs(rig, APE.Fur, APE.Dark, 1.1)
	pawFeet(rig, APE.Skin, APE.Dark, 1.1)
	riftMarks(rig, accent, {
		{ V(-0.55, 2.15, 0.95), 1.3, 0.4, A(-0.6, 0, 0.35) },
		{ V(0.55, 2.1, 0.95), 1.5, 0.44, A(-0.65, 0, -0.3) },
	}, {
		{ "LeftUpperArm", V(0.06, 0.85, 0.1), V(-2.12, 0.8, -0.15), A(0, 0, -0.3) },
		{ "RightUpperArm", V(0.06, 0.85, 0.1), V(2.12, 0.8, -0.15), A(0, 0, 0.3) },
		{ "UpperTorso", V(0.08, 0.8, 0.06), V(-0.25, 0.4, -1.1), A(0, 0, 0.4) },
	})
end

-- Tung Tung Tung Sahur ------------------------------------------------------------------------------------
-- A charred log golem: a trunk of scorched bark split by embers, three log
-- heads on it (each its own face, fire in its eyes and its grin), branch
-- arms, stump legs on roots, and a great nail-studded bat smouldering at
-- its end.
local EMBER = C(255, 116, 32)
local LOG = {
	Bark = C(92, 64, 44),
	Dark = C(58, 40, 30),
	Char = C(32, 26, 24),
	Cut = C(204, 160, 108),
	Ring = C(164, 118, 74),
	Bat = C(150, 104, 62),
	BatDark = C(96, 64, 40),
}
local function logHead(rig, x: number, y: number, z: number, k: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	local r = 0.62 * k -- (its radius)
	local top = y + 0.75 * k
	add(wood(put(rig, "UpperTorso", "LogHead", V(1.5 * k, 2 * r, 2 * r), V(x, y, z), LOG.Bark, CYL, UPRIGHT)))
	add(wood(put(rig, "UpperTorso", "LogEnd", V(0.06, 1.85 * r, 1.85 * r), V(x, top + 0.01, z), LOG.Cut, CYL, UPRIGHT)))
	add(put(rig, "UpperTorso", "LogRing", V(0.07, r, r), V(x, top + 0.02, z), LOG.Ring, CYL, UPRIGHT))
	local f = z - r -- (its face)
	for _, s in SIDES do
		local ex = x + s * 0.27 * k
		add(ball(rig, "UpperTorso", "EyeHole", V(0.4, 0.42, 0.3) * k, V(ex, y + 0.15 * k, f + 0.04), INK))
		add(neon(ball(rig, "UpperTorso", "FireEye", V(0.25, 0.27, 0.14) * k, V(ex, y + 0.14 * k, f - 0.06), accent)))
		add(
			neon(
				ball(
					rig,
					"UpperTorso",
					"EyeCore",
					V(0.1, 0.1, 0.08) * k,
					V(ex, y + 0.14 * k, f - 0.12),
					C(255, 228, 184)
				)
			)
		)
		add(
			put(
				rig,
				"UpperTorso",
				"Brow",
				V(0.48, 0.13, 0.22) * k,
				V(ex - s * 0.02 * k, y + 0.42 * k, f - 0.04),
				LOG.Char,
				nil,
				A(0, 0, s * 0.38)
			)
		)
	end
	add(wood(ball(rig, "UpperTorso", "Nose", V(0.22, 0.34, 0.3) * k, V(x, y - 0.06 * k, f - 0.08), LOG.Bark)))
	add(ball(rig, "UpperTorso", "Grin", V(0.8, 0.24, 0.2) * k, V(x, y - 0.38 * k, f + 0.02), INK))
	add(neon(ball(rig, "UpperTorso", "GrinFire", V(0.6, 0.09, 0.14) * k, V(x, y - 0.38 * k, f - 0.04), accent)))
	group(rig, list, "Head", "UpperTorso", V(x, y - 0.75 * k, z), side)
end
-- The bat in its right hand (gripped as SahurBat poses it): a great charred
-- club studded with nails, glowing near its end.
local function nailBat(rig, accent: Color3)
	local grip = A(math.rad(-120), 0, 0)
	-- (`d` along the bat from the fist)
	local function piece(name, size, d, color, shape, turn)
		return P(
			rig,
			rig.RightHand,
			name,
			size,
			V(0, 0, 0),
			color,
			shape,
			grip * CFrame.new(0, d, 0) * (turn or CFrame.identity)
		)
	end
	wood(piece("BatKnob", V(0.16, 0.38, 0.38), -0.32, LOG.BatDark, CYL, UPRIGHT))
	wood(piece("BatHandle", V(1.3, 0.24, 0.24), 0.35, LOG.Bat, CYL, UPRIGHT))
	wood(piece("BatTaper", V(0.8, 0.42, 0.42), 1.3, LOG.Bat, CYL, UPRIGHT))
	wood(piece("BatBarrel", V(1.9, 0.66, 0.66), 2.4, LOG.Bat, CYL, UPRIGHT))
	piece("BatChar", V(0.6, 0.68, 0.68), 2.95, LOG.Char, CYL, UPRIGHT)
	neon(piece("BatEmber", V(0.08, 0.69, 0.69), 2.62, accent, CYL, UPRIGHT))
	wood(piece("BatEnd", V(0.66, 0.34, 0.66), 3.35, LOG.Char, BALL))
	for i = 1, 6 do
		piece(
			"Nail",
			V(0.07, 0.44, 0.07),
			1.85 + (i % 3) * 0.5,
			IRON_LIGHT,
			nil,
			A(0, i * 2.1, 0) * CFrame.new(0, 0, -0.38) * A(math.pi / 2, 0, 0)
		).Material =
			Enum.Material.Metal
	end
end
local function sahurTrio(rig, _accent)
	local accent = EMBER -- (its fire burns orange, not in Fire's red tint)
	wood(put(rig, "UpperTorso", "Trunk", V(2.9, 2.55, 2.55), V(0, 0.8, 0.05), LOG.Bark, CYL, UPRIGHT))
	wood(put(rig, "UpperTorso", "TrunkTop", V(0.08, 2.4, 2.4), V(0, 2.26, 0.05), LOG.Cut, CYL, UPRIGHT))
	put(rig, "UpperTorso", "TrunkRing", V(0.09, 1.6, 1.6), V(0, 2.27, 0.05), LOG.Ring, CYL, UPRIGHT)
	-- Ridges of bark round it, uneven, burnt black in places.
	for i, r in
		{
			{ 0.45, 1.6, 0.9 },
			{ 1.2, 2.5, 0.75 },
			{ 1.95, 1.2, 1.3 },
			{ 2.7, 2.2, 0.6 },
			{ 3.6, 1.8, 0.95 },
			{ 4.4, 2.6, 0.8 },
			{ 5.3, 1.3, 1.25 },
			{ 5.85, 2.0, 0.5 },
		}
	do
		local a, len, y = r[1], r[2], r[3]
		local out = V(math.sin(a), 0, -math.cos(a))
		local color = if i % 3 == 0 then LOG.Char else LOG.Dark
		wood(
			put(
				rig,
				"UpperTorso",
				"BarkRidge",
				V(0.26, len, 0.16),
				V(0, y, 0.05) + out * 1.27,
				color,
				nil,
				A(0, -a, 0) * A(0, 0, (i % 2 - 0.5) * 0.08)
			)
		)
	end
	-- Lopped branches and a knot.
	for _, b in { { -1.0, 1.55, 0.45 }, { 1.15, 0.45, 0.4 } } do
		local a, y, thick = b[1], b[2], b[3]
		local out = V(math.sin(a), 0, -math.cos(a))
		local base = V(0, y, 0.05) + out * 1.1
		wood(rod(rig, "UpperTorso", "Stub", base, base + out * 0.6 + V(0, 0.25, 0), thick, LOG.Bark))
		wood(
			put(
				rig,
				"UpperTorso",
				"StubEnd",
				V(0.04, thick * 0.9, thick * 0.9),
				base + out * 0.62 + V(0, 0.26, 0),
				LOG.Cut,
				CYL,
				along(out * 0.6 + V(0, 0.25, 0))
			)
		)
	end
	ball(rig, "UpperTorso", "Knothole", V(0.42, 0.55, 0.2), V(0.55, 1.75, -1.15), LOG.Char, A(0, -0.45, 0))
	for _, c in { { -0.5, 1.5, 1.0 }, { 0.6, 0.2, 0.8 }, { 2.4, 1.1, 1.1 } } do
		local a, y, size = c[1], c[2], c[3]
		local out = V(math.sin(a), 0, -math.cos(a))
		ball(rig, "UpperTorso", "Char", V(size, size * 0.8, 0.24), V(0, y, 0.05) + out * 1.26, LOG.Char, A(0, -a, 0))
	end
	wood(put(rig, "LowerTorso", "Stump", V(1.0, 2.35, 2.35), V(0, -0.6, 0.05), LOG.Dark, CYL, UPRIGHT))
	logHead(rig, 0, 3.05, -0.3, 1.15, 0.3, accent)
	for _, s in SIDES do
		headOut(s * 1.0, s, 0.38, function(x, side)
			logHead(rig, x, 2.85, 0.25, 0.92, side, accent)
		end)
	end
	branchArms(rig, LOG.Bark, LOG.Dark, 1.05, 3)
	for _, s in SIDES do
		-- (a twig off each elbow, burning at its tip)
		local elbow = V(s * 1.62, 0.3, -0.05)
		wood(rod(rig, LR[s] .. "LowerArm", "Twig", elbow, elbow + V(s * 0.55, 0.6, 0.3), 0.14, LOG.Bark))
		neon(ball(rig, LR[s] .. "LowerArm", "Ember", V(0.22, 0.22, 0.22), elbow + V(s * 0.55, 0.6, 0.3), accent))
	end
	for _, s in SIDES do
		local side, x = LR[s], s * 0.62
		wood(rod(rig, side .. "UpperLeg", "Stump", V(x, -0.5, 0), V(x, -1.6, -0.05), 1.05, LOG.Bark))
		wood(ball(rig, side .. "LowerLeg", "Knot", V(0.98, 0.7, 0.98), V(x, -1.6, -0.05), LOG.Dark))
		wood(rod(rig, side .. "LowerLeg", "Stump", V(x, -1.6, -0.05), V(x, -2.5, 0), 1.0, LOG.Bark))
		-- Roots for feet.
		wood(ball(rig, side .. "Foot", "RootFoot", V(1.15, 0.55, 1.25), V(x, -2.65, -0.1), LOG.Dark))
		for _, dir in { V(-0.45, 0, -1), V(0.45, 0, -1), V(0, 0, -1.15), V(s * 0.9, 0, 0.3) } do
			wood(rod(rig, side .. "Foot", "Root", V(x, -2.62, -0.15), V(x, -2.84, -0.15) + dir * 0.85, 0.26, LOG.Bark))
		end
	end
	nailBat(rig, accent)
	riftMarks(rig, accent, {
		{ V(-0.6, 1.5, 1.2), 1.3, 0.4, A(-0.6, 0, 0.35) },
		{ V(0.55, 1.4, 1.2), 1.1, 0.36, A(-0.55, 0, -0.35) },
	}, {
		{ "UpperTorso", V(0.1, 1.2, 0.06), V(-0.12, 1.2, -1.24), A(0, 0, 0.3) },
		{ "UpperTorso", V(0.08, 0.8, 0.06), V(0.15, 0.25, -1.24), A(0, 0, -0.45) },
		{ "UpperTorso", V(0.08, 0.6, 0.06), V(-0.35, 0.55, -1.2), A(0, 0.3, 0.9) },
	})
end

-- Tralalero Tralala -----------------------------------------------------------------------------------------
-- A two-headed shark brute: a slate back and a white belly, a tall dorsal
-- fin, two shark heads on thick necks with their jaws open on rows of teeth
-- and frost glowing in their gills, fins on its forearms, a tail ending in
-- a crescent fin, and big blue sneakers lit along their soles.
local SHARK = {
	Skin = C(70, 102, 132),
	Dark = C(44, 66, 90),
	Belly = C(224, 230, 234),
	Mouth = C(70, 22, 32),
	Shoe = C(30, 100, 210),
	ShoeDark = C(22, 64, 150),
}
local function sharkHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	add(ball(rig, "UpperTorso", "SharkNeck", V(1.15, 1.2, 1.15), V(x, 1.95, -0.35), SHARK.Skin))
	add(ball(rig, "UpperTorso", "SharkHead", V(1.2, 1.05, 2.0), V(x, 2.5, -0.95), SHARK.Skin))
	add(ball(rig, "UpperTorso", "SharkSnout", V(0.95, 0.72, 1.1), V(x, 2.55, -1.85), SHARK.Skin))
	add(ball(rig, "UpperTorso", "SharkTop", V(0.7, 0.4, 1.6), V(x, 2.92, -1.0), SHARK.Dark))
	add(ball(rig, "UpperTorso", "SharkChin", V(1.05, 0.5, 1.6), V(x, 2.2, -1.05), SHARK.Belly))
	add(ball(rig, "UpperTorso", "Maw", V(0.95, 0.42, 1.0), V(x, 2.15, -1.55), SHARK.Mouth))
	for i = -2, 2 do
		add(
			put(
				rig,
				"UpperTorso",
				"Tooth",
				V(0.1, 0.22, 0.12),
				V(x + i * 0.17, 2.24, -1.98 + math.abs(i) * 0.14),
				WHITE,
				"Wedge",
				A(0, 0, math.pi)
			)
		)
	end
	for _, s in SIDES do
		for i = 1, 3 do
			add(
				neon(
					put(
						rig,
						"UpperTorso",
						"Gill",
						V(0.06, 0.48, 0.09),
						V(x + s * 0.57, 2.25, -0.55 + i * 0.17),
						accent,
						nil,
						A(0, 0, s * 0.15)
					)
				)
			)
		end
	end
	eyes(rig, "UpperTorso", list, V(x, 2.85, -1.45), 0.36, 0.2, accent)
	group(rig, list, "Head", "UpperTorso", V(x, 1.8, -0.3), side)
	local jaw = { ball(rig, "UpperTorso", "LowerJaw", V(1.0, 0.32, 1.45), V(x, 1.88, -1.45), SHARK.Belly) }
	for i = -1.5, 1.5 do
		table.insert(
			jaw,
			put(
				rig,
				"UpperTorso",
				"LowerTooth",
				V(0.09, 0.2, 0.11),
				V(x + i * 0.18, 2.02, -1.92 + math.abs(i) * 0.14),
				WHITE,
				"Wedge"
			)
		)
	end
	group(rig, jaw, "Jaw", "UpperTorso", V(x, 2.1, -0.75), side)
end
-- Big sneakers: a white sole lit in its element, the shoe, a white toe,
-- a padded collar, the tongue and a stripe down its side.
local function sneakers(rig, accent: Color3)
	for _, s in SIDES do
		local f, x = LR[s] .. "Foot", s * 0.62
		ball(rig, f, "Sole", V(1.2, 0.36, 2.05), V(x, -2.76, -0.35), WHITE)
		neon(ball(rig, f, "SoleGlow", V(1.24, 0.07, 2.09), V(x, -2.74, -0.35), accent))
		ball(rig, f, "Sneaker", V(1.08, 0.72, 1.85), V(x, -2.55, -0.32), SHARK.Shoe)
		ball(rig, f, "ToeCap", V(0.95, 0.5, 0.75), V(x, -2.65, -1.0), WHITE)
		ball(rig, f, "Collar", V(0.98, 0.5, 0.9), V(x, -2.2, 0.08), SHARK.ShoeDark)
		ball(rig, f, "Tongue", V(0.5, 0.42, 0.85), V(x, -2.2, -0.4), WHITE)
		put(rig, f, "Stripe", V(0.06, 0.16, 1.0), V(x + s * 0.53, -2.55, -0.3), WHITE, nil, A(0.3, 0, 0))
	end
end
local function twinShark(rig, accent)
	ball(rig, "UpperTorso", "Chest", V(3.0, 2.5, 2.1), V(0, 0.95, -0.1), SHARK.Skin)
	ball(rig, "UpperTorso", "Hunch", V(2.7, 1.3, 1.6), V(0, 1.7, 0.35), SHARK.Dark)
	ball(rig, "UpperTorso", "WhiteBelly", V(2.0, 2.1, 0.7), V(0, 0.75, -0.84), SHARK.Belly)
	ball(rig, "LowerTorso", "Belly", V(2.5, 1.3, 1.8), V(0, -0.15, 0), SHARK.Skin)
	ball(rig, "LowerTorso", "WhiteBelly", V(1.7, 0.95, 0.7), V(0, -0.15, -0.65), SHARK.Belly)
	-- The dorsal fin, tall and swept back.
	tri(rig, "UpperTorso", "DorsalFin", V(0, 2.0, 0.55), V(0, 3.55, 1.6), V(0, 1.55, 1.4), SHARK.Dark, 0.22)
	for _, s in SIDES do
		headOut(s * 0.85, s, 0.3, function(x, side)
			sharkHead(rig, x, side, accent)
		end)
	end
	arms(rig, SHARK.Skin, SHARK.Dark, "Fist", 1.1)
	armor(rig, accent, { Bracers = true }, 1.1)
	for _, s in SIDES do
		tri(
			rig,
			LR[s] .. "LowerArm",
			"ArmFin",
			V(s * 1.9, 0.25, 0.35),
			V(s * 1.95, -0.7, 0.45),
			V(s * 2.05, 0.55, 1.35),
			SHARK.Dark,
			0.14
		)
	end
	legs(rig, SHARK.Skin, SHARK.Dark, 1.05)
	sneakers(rig, accent)
	local tip = tail(rig, SHARK.Skin, 6, 0.85, 1.0, 2.7)
	local fin = {}
	tri(
		rig,
		"LowerTorso",
		"TailFin",
		tip + V(0, -0.1, -0.2),
		tip + V(0, 1.35, 0.75),
		tip + V(0, 0.2, 0.45),
		SHARK.Dark,
		0.16,
		fin
	)
	tri(
		rig,
		"LowerTorso",
		"TailFin",
		tip + V(0, 0.1, -0.2),
		tip + V(0, 0.2, 0.45),
		tip + V(0, -0.85, 0.6),
		SHARK.Dark,
		0.16,
		fin
	)
	for _, p in fin do
		onTail(rig, p)
	end
	riftMarks(rig, accent, {
		{ V(-0.75, 1.75, 0.95), 1.2, 0.38, A(-0.55, 0, 0.45) },
		{ V(0.75, 1.75, 0.95), 1.3, 0.4, A(-0.55, 0, -0.45) },
	})
end

-- Brr Brr Patapim -----------------------------------------------------------------------------------------------
-- An old treant: a great trunk of bark under a mantle of moss, branches in
-- leaf rising off its back, three long-nosed faces of bark with moss beards
-- and poison in their eyes, glowing shelf fungus and a glowing hollow, root
-- claws, and two huge bare feet.
local TREE = {
	Bark = C(84, 70, 54),
	Dark = C(52, 44, 36),
	Moss = C(66, 100, 46),
	MossLight = C(98, 134, 62),
	Leaf = C(58, 108, 50),
	LeafDark = C(40, 80, 40),
	Skin = C(178, 136, 100),
}
local function treeFace(rig, x: number, y: number, z: number, k: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	add(wood(ball(rig, "UpperTorso", "BarkHead", V(1.25, 1.45, 1.2) * k, V(x, y, z), TREE.Bark)))
	add(wood(ball(rig, "UpperTorso", "BarkBrow", V(1.2, 0.36, 0.55) * k, V(x, y + 0.28 * k, z - 0.45 * k), TREE.Dark)))
	eyes(rig, "UpperTorso", list, V(x, y + 0.06 * k, z - 0.55 * k), 0.27 * k, 0.2 * k, accent, TREE.Dark)
	add(wood(ball(rig, "UpperTorso", "NoseRoot", V(0.42, 0.42, 0.6) * k, V(x, y - 0.1 * k, z - 0.72 * k), TREE.Bark)))
	add(
		wood(
			ball(
				rig,
				"UpperTorso",
				"LongNose",
				V(0.3, 0.3, 1.1) * k,
				V(x, y - 0.32 * k, z - 1.2 * k),
				TREE.Bark,
				A(-0.45, 0, 0)
			)
		)
	)
	add(ball(rig, "UpperTorso", "Mouth", V(0.55, 0.12, 0.2) * k, V(x, y - 0.5 * k, z - 0.52 * k), INK))
	for i = 1, 3 do
		-- (a beard of moss)
		local long = 0.95 - math.abs(i - 2) * 0.25
		add(
			ball(
				rig,
				"UpperTorso",
				"MossBeard",
				V(0.36, long, 0.3) * k,
				V(x + (i - 2) * 0.28 * k, y - (0.55 + long / 2) * k, z - 0.38 * k),
				if i == 2 then TREE.Moss else TREE.MossLight
			)
		)
	end
	for _, s in SIDES do
		-- (twigs for horns)
		add(
			wood(
				rod(
					rig,
					"UpperTorso",
					"Twig",
					V(x + s * 0.3 * k, y + 0.55 * k, z),
					V(x + s * 0.65 * k, y + 1.15 * k, z + 0.15),
					0.13 * k,
					TREE.Dark
				)
			)
		)
	end
	group(rig, list, "Head", "UpperTorso", V(x, y - 0.65 * k, z + 0.2), side)
end
-- A huge bare foot: the sole, a heel and five toes, the big one inside.
local function bareFeet(rig, skin: Color3, k: number)
	for _, s in SIDES do
		local f, x = LR[s] .. "Foot", s * 0.62
		ball(rig, f, "BareFoot", V(1.25, 0.62, 1.9) * k, V(x, -2.6, -0.4), skin)
		ball(rig, f, "Heel", V(0.95, 0.6, 0.8) * k, V(x, -2.6, 0.22), skin)
		for i = 1, 5 do
			local size = if i == 1 then 0.44 else 0.36 - i * 0.03
			ball(
				rig,
				f,
				"Toe",
				V(size, size * 0.85, size * 1.15) * k,
				V(x - s * (0.46 - (i - 1) * 0.23) * k, -2.68, -1.28 * k + (i - 1) * 0.07),
				skin
			)
		end
	end
end
local function treeTrio(rig, accent)
	wood(ball(rig, "UpperTorso", "Trunk", V(3.1, 2.7, 2.3), V(0, 0.85, 0), TREE.Bark))
	wood(put(rig, "LowerTorso", "TrunkBase", V(1.5, 2.6, 2.6), V(0, -0.45, 0.02), TREE.Dark, CYL, UPRIGHT))
	for i = -2, 2 do
		-- (ridges of bark down its front)
		local x = i * 0.52
		wood(
			ball(
				rig,
				"UpperTorso",
				"BarkRidge",
				V(0.26, 2.2 - math.abs(i) * 0.3, 0.3),
				V(x, 0.75, -1.15 * math.sqrt(1 - (x / 1.55) ^ 2) + 0.05),
				TREE.Dark,
				A(0, -x * 0.5, 0)
			)
		)
	end
	-- A hollow in it, glowing.
	ball(rig, "UpperTorso", "Hollow", V(0.62, 0.9, 0.3), V(0.5, 0.95, -1.06), INK)
	neon(ball(rig, "UpperTorso", "HollowGlow", V(0.36, 0.56, 0.2), V(0.5, 0.93, -1.12), accent))
	-- A mantle of moss over its shoulders and back, hanging in strands.
	ball(rig, "UpperTorso", "Mantle", V(2.6, 0.8, 1.7), V(0, 2.0, 0.4), TREE.Moss)
	for _, s in SIDES do
		ball(rig, "UpperTorso", "Mantle", V(1.6, 0.85, 1.6), V(s * 0.95, 1.9, 0.1), TREE.MossLight)
		for i = 1, 2 do
			local top = V(s * (0.75 + i * 0.35), 1.6, -0.55 + i * 0.1)
			local strand =
				ball(rig, "UpperTorso", "MossStrand", V(0.3, 1.0 - i * 0.15, 0.24), top - V(0, 0.45, 0), TREE.Moss)
			animate(strand, "Moss", pivotOn(rig, "UpperTorso", top), s)
		end
	end
	-- Branches in leaf rising off its back; they sway.
	for i, b in
		{
			{ V(-0.75, 2.0, 0.6), V(-1.75, 3.5, 1.25) },
			{ V(0.75, 2.0, 0.6), V(1.8, 3.35, 1.15) },
			{ V(-0.2, 2.1, 0.8), V(-0.55, 3.9, 1.55) },
			{ V(0.3, 2.1, 0.8), V(0.75, 3.7, 1.75) },
		}
	do
		local s = if i % 2 == 0 then 1 else -1
		local list = { wood(rod(rig, "UpperTorso", "Branch", b[1], b[2], 0.32, TREE.Dark)) }
		table.insert(list, ball(rig, "UpperTorso", "Leaves", V(1.3, 0.95, 1.2), b[2], TREE.Leaf))
		table.insert(
			list,
			ball(rig, "UpperTorso", "Leaves", V(0.9, 0.7, 0.85), b[2] + V(s * 0.45, -0.3, -0.2), TREE.LeafDark)
		)
		group(rig, list, "Moss", "UpperTorso", b[1], s)
	end
	-- Shelf fungus glowing down its sides, toadstools on its shoulders.
	for i, f in { { -1, 0.3 }, { -1, -0.15 }, { 1, 0.6 }, { 1, 0.15 } } do
		local s, y = f[1], f[2]
		neon(
			ball(
				rig,
				"UpperTorso",
				"Fungus",
				V(0.75 - (i % 2) * 0.15, 0.16, 0.6),
				V(s * 1.12, y, -0.62 - (i % 2) * 0.05),
				accent,
				A(0, s * 0.6, 0)
			)
		)
	end
	for _, s in SIDES do
		put(rig, "UpperTorso", "Stalk", V(0.5, 0.18, 0.18), V(s * 1.15, 2.45, 0.35), IVORY, CYL, UPRIGHT)
		neon(ball(rig, "UpperTorso", "Toadstool", V(0.55, 0.3, 0.55), V(s * 1.15, 2.72, 0.35), accent))
	end
	treeFace(rig, 0, 2.4, -0.65, 1.1, 0.3, accent)
	for _, s in SIDES do
		headOut(s * 1.25, s, 0.35, function(x, side)
			treeFace(rig, x, 2.2, -0.35, 0.85, side, accent)
		end)
	end
	branchArms(rig, TREE.Bark, TREE.Dark, 1.1, 4)
	for _, s in SIDES do
		ball(rig, LR[s] .. "UpperArm", "ArmMoss", V(0.8, 0.95, 0.8), V(s * 1.72, 1.0, 0.1), TREE.Moss)
		local side, x = LR[s], s * 0.62
		wood(rod(rig, side .. "UpperLeg", "Leg", V(x, -0.4, 0), V(x, -1.6, -0.05), 1.15, TREE.Bark))
		wood(ball(rig, side .. "LowerLeg", "Knot", V(1.0, 0.75, 1.0), V(x, -1.6, -0.05), TREE.Dark))
		wood(rod(rig, side .. "LowerLeg", "Leg", V(x, -1.6, -0.05), V(x, -2.4, 0), 1.0, TREE.Bark))
	end
	bareFeet(rig, TREE.Skin, 1.1)
	riftMarks(rig, accent, {
		{ V(-0.45, 1.6, 1.0), 1.1, 0.36, A(-0.7, 0, 0.3) },
		{ V(0.5, 1.5, 1.0), 1.2, 0.38, A(-0.7, 0, -0.3) },
	})
end

-- Frigo Camelo -----------------------------------------------------------------------------------------------------
-- Two camels out of a frosted freezer: a fridge for a body, its freezer door
-- hanging open on a glowing frozen inside with ice spiking out, a crust of
-- frost and icicles, a camel's humps on top, two camel heads on long necks,
-- camel arms ending in hooves, and camel legs.
local FRIGO = {
	Shell = C(208, 214, 220),
	Panel = C(222, 228, 232),
	Seal = C(66, 70, 78),
	Handle = C(150, 156, 166),
	Fur = C(176, 132, 84),
	FurDark = C(132, 96, 60),
	Muzzle = C(196, 156, 110),
	Lip = C(120, 86, 60),
	Hoof = C(52, 44, 40),
	Frost = C(214, 236, 248),
	Ice = C(168, 214, 240),
}
local function camelHead(rig, x: number, side: number, accent: Color3)
	local list = {}
	local function add(p)
		table.insert(list, p)
		return p
	end
	-- (its long neck curves forward and up out of the fridge's top)
	add(ball(rig, "UpperTorso", "CamelNeck", V(0.85, 1.0, 0.88), V(x, 2.45, -0.45), FRIGO.Fur))
	add(ball(rig, "UpperTorso", "CamelNeck", V(0.74, 1.0, 0.74), V(x, 3.0, -0.75), FRIGO.Fur, A(-0.4, 0, 0)))
	add(ball(rig, "UpperTorso", "CamelNeck", V(0.68, 0.85, 0.68), V(x, 3.4, -1.05), FRIGO.Fur, A(-0.7, 0, 0)))
	add(ball(rig, "UpperTorso", "CamelHead", V(0.82, 0.78, 1.05), V(x, 3.65, -1.35), FRIGO.Fur))
	add(ball(rig, "UpperTorso", "CamelMuzzle", V(0.7, 0.6, 0.9), V(x, 3.5, -1.95), FRIGO.Muzzle))
	add(ball(rig, "UpperTorso", "UpperLip", V(0.62, 0.3, 0.45), V(x, 3.32, -2.22), FRIGO.Lip))
	add(
		put(
			rig,
			"UpperTorso",
			"Forelock",
			V(0.16, 0.36, 0.42),
			V(x, 4.02, -1.35),
			FRIGO.FurDark,
			"Wedge",
			A(0, math.pi, 0)
		)
	)
	for _, s in SIDES do
		add(ball(rig, "UpperTorso", "Nostril", V(0.08, 0.16, 0.12), V(x + s * 0.17, 3.6, -2.36), INK, A(0, 0, s * 0.4)))
		add(
			put(
				rig,
				"UpperTorso",
				"CamelEar",
				V(0.12, 0.34, 0.22),
				V(x + s * 0.34, 4.0, -1.2),
				FRIGO.Fur,
				"Wedge",
				A(0, math.pi, -s * 0.3)
			)
		)
	end
	eyes(rig, "UpperTorso", list, V(x, 3.78, -1.66), 0.28, 0.16, accent, FRIGO.FurDark)
	group(rig, list, "Head", "UpperTorso", V(x, 2.2, -0.4), side)
	local lip = { ball(rig, "UpperTorso", "LowerLip", V(0.55, 0.24, 0.6), V(x, 3.14, -2.05), FRIGO.Lip) }
	group(rig, lip, "Jaw", "UpperTorso", V(x, 3.3, -1.7), side)
end
local function frigo(rig, accent)
	put(rig, "UpperTorso", "Fridge", V(2.9, 3.1, 2.3), V(0, 0.75, 0.1), FRIGO.Shell)
	put(rig, "LowerTorso", "KickPlate", V(2.7, 0.55, 2.1), V(0, -0.95, 0.1), FRIGO.Seal)
	for i = 1, 3 do
		put(rig, "LowerTorso", "Grille", V(2.2, 0.05, 0.05), V(0, -1.15 + i * 0.1, -0.96), FRIGO.Handle)
	end
	-- The fridge door and its handle, magnets on it.
	put(rig, "UpperTorso", "Door", V(2.78, 2.0, 0.16), V(0, 0.2, -1.1), FRIGO.Panel)
	put(rig, "UpperTorso", "DoorGap", V(2.9, 0.06, 0.12), V(0, 1.24, -1.08), FRIGO.Seal)
	put(rig, "UpperTorso", "Handle", V(0.16, 1.3, 0.16), V(1.1, 0.55, -1.32), FRIGO.Handle).Material =
		Enum.Material.Metal
	for _, y in { 0.0, 1.1 } do
		put(rig, "UpperTorso", "HandleFoot", V(0.12, 0.12, 0.2), V(1.1, y, -1.22), FRIGO.Handle)
	end
	for i, color in { C(220, 64, 56), C(60, 130, 220) } do
		put(
			rig,
			"UpperTorso",
			"Magnet",
			V(0.3, 0.3, 0.06),
			V(-0.85 + i * 0.4, 0.75 - i * 0.25, -1.2),
			color,
			nil,
			A(0, 0, i * 0.3)
		)
	end
	-- The freezer: frozen inside and glowing, ice spiking out of it, its door
	-- hanging open with icicles along it.
	neon(put(rig, "UpperTorso", "FrozenInside", V(2.55, 0.85, 0.06), V(0, 1.78, -1.06), accent))
	for i, at in { V(-0.6, 1.6, -1.2), V(0.1, 1.95, -1.2), V(0.75, 1.62, -1.2), V(1.15, 1.95, -1.2) } do
		put(
			rig,
			"UpperTorso",
			"IceSpike",
			V(0.22, 0.75 - (i % 2) * 0.25, 0.32),
			at,
			FRIGO.Ice,
			"Wedge",
			A(-math.pi / 2 + 0.25, (i - 2.5) * 0.25, 0)
		)
	end
	local hinge = V(-1.42, 1.78, -1.12)
	turned(hinge, A(0, 0.45, 0), function()
		put(rig, "UpperTorso", "FreezerDoor", V(2.8, 0.95, 0.16), hinge + V(1.4, 0, 0), FRIGO.Panel)
		put(rig, "UpperTorso", "FreezerHandle", V(0.7, 0.14, 0.14), hinge + V(2.3, -0.3, -0.18), FRIGO.Handle).Material =
			Enum.Material.Metal
		for i = 1, 4 do
			put(
				rig,
				"UpperTorso",
				"Icicle",
				V(0.13, 0.42 - (i % 2) * 0.14, 0.14),
				hinge + V(0.35 + i * 0.55, -0.66, 0),
				FRIGO.Ice,
				"Wedge",
				A(0, 0, math.pi)
			)
		end
	end)
	-- Frost crusted on its top, a camel's humps out of it.
	for _, f in
		{
			{ V(-0.75, 2.3, -0.4), V(1.4, 0.4, 1.1) },
			{ V(0.7, 2.3, -0.55), V(1.3, 0.34, 0.9) },
			{ V(1.1, 2.28, 0.6), V(0.9, 0.3, 1.0) },
		}
	do
		ball(rig, "UpperTorso", "Frost", f[2], f[1], FRIGO.Frost)
	end
	for _, s in SIDES do
		ball(rig, "UpperTorso", "Hump", V(1.25, 1.1, 1.2), V(s * 0.6, 2.55, 0.6), FRIGO.Fur)
		ball(rig, "UpperTorso", "HumpFrost", V(0.95, 0.32, 0.9), V(s * 0.6, 3.04, 0.6), FRIGO.Frost)
		headOut(s * 0.75, s, 0.25, function(x, side)
			camelHead(rig, x, side, accent)
		end)
	end
	arms(rig, FRIGO.Fur, FRIGO.FurDark, "Hoof", 0.95)
	legs(rig, FRIGO.Fur, FRIGO.FurDark, 0.9)
	hoofFeet(rig, FRIGO.Fur, FRIGO.Hoof, 1.15)
	riftMarks(rig, accent, {
		{ V(-0.7, 1.4, 1.3), 1.2, 0.38, A(-0.5, 0, 0.3) },
		{ V(0.6, 1.2, 1.3), 1.0, 0.34, A(-0.5, 0, -0.3) },
	}, {
		{ "UpperTorso", V(0.08, 1.0, 0.05), V(-0.55, 0.15, -1.2), A(0, 0, 0.45) },
		{ "UpperTorso", V(0.07, 0.6, 0.05), V(-0.25, -0.35, -1.2), A(0, 0, -0.5) },
	})
end

-- Cappuccino Assassino ------------------------------------------------------------------------------------------
-- A ninja cappuccino: a cracked cup of a body, the Rift glowing through its
-- cracks, a head of foam wrapped in a black mask with burning eyes, a red
-- scarf streaming behind, a katana in each fist, two more arms out of its
-- back twirling kunai, thin legs and tabi.
local CUP = {
	Cup = C(234, 228, 216),
	Shade = C(200, 192, 180),
	Foam = C(206, 170, 128),
	FoamLight = C(240, 224, 198),
	Mask = C(28, 26, 32),
	Scarf = C(158, 30, 40),
	Steel = C(200, 208, 218),
	Gold = C(196, 158, 70),
}
-- A blade held at `at` (in the body's space) on `bone`, running down -Y of
-- `turn`: `kunai` a short leaf blade, else a katana with its edge alight.
local function blade(rig, bone: string, at: Vector3, turn: CFrame, accent: Color3, kunai: boolean, list)
	-- (`d` along the blade from the fist)
	local function piece(name, size, d, color, shape, extra)
		local p = put(rig, bone, name, size, at, color, shape, turn * CFrame.new(0, -d, 0) * (extra or CFrame.identity))
		if list then
			table.insert(list, p)
		end
		return p
	end
	if kunai then
		piece("KunaiGrip", V(0.14, 0.5, 0.14), 0, CUP.Scarf)
		piece("KunaiRing", V(0.08, 0.26, 0.26), -0.32, CUP.Steel, CYL)
		piece("KunaiBlade", V(0.06, 0.8, 0.32), 0.62, CUP.Steel, BALL).Material = Enum.Material.Metal
		neon(piece("KunaiEdge", V(0.07, 0.6, 0.06), 0.62, accent))
		return
	end
	piece("Tsuka", V(0.2, 0.78, 0.2), 0, CUP.Mask)
	piece("Tsuba", V(0.08, 0.52, 0.52), 0.43, CUP.Gold, CYL, UPRIGHT)
	piece("Katana", V(0.06, 2.5, 0.2), 1.72, CUP.Steel).Material = Enum.Material.Metal
	piece("KatanaTip", V(0.06, 0.32, 0.2), 3.13, CUP.Steel, "Wedge", A(0, 0, math.pi)).Material = Enum.Material.Metal
	neon(piece("KatanaEdge", V(0.07, 2.4, 0.04), 1.72, accent, nil, CFrame.new(0, 0, -0.09)))
end
local function cappuccino(rig, accent)
	put(rig, "UpperTorso", "Cup", V(2.0, 2.5, 2.5), V(0, 1.15, 0), CUP.Cup, CYL, UPRIGHT)
	put(rig, "LowerTorso", "CupBase", V(1.05, 2.05, 2.05), V(0, -0.3, 0), CUP.Cup, CYL, UPRIGHT)
	put(rig, "LowerTorso", "CupFoot", V(0.22, 2.25, 2.25), V(0, -0.78, 0), CUP.Shade, CYL, UPRIGHT)
	-- The handle, round its back.
	for _, r in
		{
			{ V(0, 1.75, 1.2), V(0, 1.75, 1.85) },
			{ V(0, 1.75, 1.85), V(0, 0.75, 1.85) },
			{ V(0, 0.75, 1.85), V(0, 0.75, 1.2) },
		}
	do
		rod(rig, "UpperTorso", "CupHandle", r[1], r[2], 0.34, CUP.Cup)
	end
	-- A black sash knotted at its side.
	put(rig, "UpperTorso", "Sash", V(0.42, 2.56, 2.56), V(0, 0.6, 0), CUP.Mask, CYL, UPRIGHT)
	ball(rig, "UpperTorso", "SashKnot", V(0.4, 0.36, 0.3), V(-0.75, 0.6, -1.05), CUP.Mask)
	-- The Rift glowing through cracks in the cup.
	for i, c in
		{ { -0.35, 1.45, 0.5, 0.95 }, { -0.12, 1.0, -0.4, 0.6 }, { 0.6, 1.6, 0.3, 0.8 }, { 0.75, 0.05, -0.5, 0.55 } }
	do
		local a, y, tilt, len = c[1], c[2], c[3], c[4]
		local bone = if i == 4 then "LowerTorso" else "UpperTorso"
		local r = if i == 4 then 1.03 else 1.26
		neon(
			put(
				rig,
				bone,
				"RiftVein",
				V(0.08, len, 0.05),
				V(math.sin(a) * r, y, -math.cos(a) * r),
				accent,
				nil,
				A(0, -a, 0) * A(0, 0, tilt)
			)
		)
	end
	-- A red scarf at its rim, streaming behind.
	put(rig, "UpperTorso", "Scarf", V(0.34, 2.72, 2.72), V(0, 2.05, 0), CUP.Scarf, CYL, UPRIGHT)
	for _, s in SIDES do
		local top = V(s * 0.28, 2.0, 1.32)
		local tailEnd = ball(
			rig,
			"UpperTorso",
			"ScarfTail",
			V(0.46, 1.6, 0.12),
			top + V(s * 0.12, -0.72, 0.16),
			CUP.Scarf,
			A(0.2, 0, s * 0.15)
		)
		animate(tailEnd, "Moss", pivotOn(rig, "UpperTorso", top), s)
	end
	-- Its head: the foam, wrapped in a black mask with its eyes burning.
	local head = {}
	local function add(p)
		table.insert(head, p)
		return p
	end
	add(ball(rig, "UpperTorso", "Foam", V(2.3, 1.7, 2.3), V(0, 2.55, 0), CUP.Foam))
	add(ball(rig, "UpperTorso", "FoamTop", V(1.5, 0.7, 1.5), V(0, 3.22, 0.05), CUP.FoamLight))
	add(put(rig, "UpperTorso", "Mask", V(0.62, 2.36, 2.36), V(0, 2.62, 0), CUP.Mask, CYL, UPRIGHT))
	add(ball(rig, "UpperTorso", "MaskKnot", V(0.42, 0.36, 0.3), V(0, 2.65, 1.2), CUP.Mask))
	eyes(rig, "UpperTorso", head, V(0, 2.64, -1.18), 0.42, 0.26, accent)
	group(rig, head, "Head", "UpperTorso", V(0, 2.1, 0), 1)
	for _, s in SIDES do
		local top = V(s * 0.12, 2.65, 1.3)
		local ribbon = put(
			rig,
			"UpperTorso",
			"MaskTail",
			V(0.24, 0.07, 1.1),
			top + V(s * 0.1, -0.2, 0.5),
			CUP.Mask,
			nil,
			A(-0.35, s * 0.25, 0)
		)
		animate(ribbon, "Moss", pivotOn(rig, "UpperTorso", top), -s)
	end
	-- Lean black arms in steel bracers, a katana in each fist.
	for _, s in SIDES do
		local side = LR[s]
		local shoulder, elbow, wrist = V(s * 1.45, 1.55, 0), V(s * 1.6, 0.3, 0), V(s * 1.6, -0.62, -0.05)
		ball(rig, side .. "UpperArm", "Shoulder", V(0.85, 0.8, 0.85), shoulder, CUP.Mask)
		ball(
			rig,
			side .. "UpperArm",
			"ShoulderPlate",
			V(1.0, 0.42, 1.0),
			shoulder + V(s * 0.08, 0.28, 0),
			CUP.Steel,
			A(0, 0, -s * 0.35)
		).Material =
			Enum.Material.Metal
		rod(rig, side .. "UpperArm", "Arm", shoulder, elbow, 0.55, CUP.Mask)
		ball(rig, side .. "LowerArm", "Elbow", V(0.56, 0.56, 0.56), elbow, CUP.Mask)
		rod(rig, side .. "LowerArm", "Arm", elbow, wrist, 0.58, CUP.Mask)
		put(
			rig,
			side .. "LowerArm",
			"Bracer",
			V(0.62, 0.68, 0.68),
			(elbow + wrist) / 2 - V(0, 0.12, 0),
			CUP.Steel,
			CYL,
			UPRIGHT
		).Material =
			Enum.Material.Metal
		ball(rig, side .. "Hand", "Fist", V(0.62, 0.56, 0.62), V(s * 1.6, -0.92, -0.08), CUP.Mask)
		blade(rig, side .. "Hand", V(s * 1.6, -0.95, -0.12), A(math.pi / 2 - 0.35, 0, 0), accent, false)
	end
	-- Two more arms out of its back, kunai raised: they twirl and slash.
	for _, s in SIDES do
		local arm = {}
		local base, elbow, hand = V(s * 0.95, 1.55, 0.75), V(s * 1.95, 2.0, 0.95), V(s * 2.35, 2.75, 0.7)
		table.insert(arm, rod(rig, "UpperTorso", "ExtraArm", base, elbow, 0.36, CUP.Mask))
		table.insert(arm, ball(rig, "UpperTorso", "ExtraElbow", V(0.42, 0.42, 0.42), elbow, CUP.Mask))
		table.insert(arm, rod(rig, "UpperTorso", "ExtraArm", elbow, hand, 0.32, CUP.Mask))
		table.insert(arm, ball(rig, "UpperTorso", "ExtraHand", V(0.42, 0.4, 0.42), hand, CUP.Mask))
		blade(rig, "UpperTorso", hand, A(math.pi, 0, s * 0.3), accent, true, arm)
		group(rig, arm, "Blade", "UpperTorso", base, s)
	end
	-- Thin legs bound at the shin, split-toed tabi.
	for _, s in SIDES do
		local side, x = LR[s], s * 0.55
		rod(rig, side .. "UpperLeg", "Leg", V(x, -0.6, 0), V(x, -1.6, -0.05), 0.66, CUP.Mask)
		ball(rig, side .. "LowerLeg", "Knee", V(0.6, 0.55, 0.6), V(x, -1.6, -0.05), CUP.Mask)
		rod(rig, side .. "LowerLeg", "Leg", V(x, -1.6, -0.05), V(x, -2.5, 0), 0.58, CUP.Mask)
		for i = 1, 2 do
			put(
				rig,
				side .. "LowerLeg",
				"Wrap",
				V(0.12, 0.64, 0.64),
				V(x, -1.85 - i * 0.22, -0.02),
				CUP.Shade,
				CYL,
				UPRIGHT
			)
		end
		ball(rig, side .. "Foot", "Tabi", V(0.78, 0.5, 1.3), V(x, -2.66, -0.25), CUP.Mask)
		ball(rig, side .. "Foot", "BigToe", V(0.26, 0.36, 0.42), V(x - s * 0.24, -2.7, -0.86), CUP.Mask)
		ball(rig, side .. "Foot", "Toes", V(0.46, 0.34, 0.45), V(x + s * 0.1, -2.7, -0.82), CUP.Mask)
	end
end

Bosses.Builders = {
	TwinCat = twinCat,
	DragonCroc = dragonCroc,
	TwinDuck = twinDuck,
	FrogAvocado = frogAvocado,
	Chimpanzini = chimpanzini,
	SahurTrio = sahurTrio,
	TwinShark = twinShark,
	TreeTrio = treeTrio,
	Frigo = frigo,
	Cappuccino = cappuccino,
}

-- Dresses `rig` as boss `spec` (DungeonRules.Bosses). False when it isn't
-- one of these (BrainrotSkins has the room fighters).
function Bosses.apply(rig, spec, accent: Color3, boss: boolean?): boolean
	local build = spec and Bosses.Builders[spec.Shape]
	if not build then
		return false
	end
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	build(rig, accent)
	Skins.finish(rig, spec, boss)
	return true
end

return Bosses
