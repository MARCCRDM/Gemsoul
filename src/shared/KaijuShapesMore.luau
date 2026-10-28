--[[
	The rest of the roster's bodies (Shared.KaijuRosterMore: Prisma, Clawtide
	and kinds 31 to 90), after their concept renders (docs/kaiju-concepts),
	built as Shared.KaijuShapes builds the roster's first kinds and merged in
	there: a hide of each kind's own colours, plates in its element's colour,
	glows in its element's light, every moving piece on a joint
	Shared.CreatureMotion drives (Body, Stride, Arm, Jaw, Tail, Head, Wing).

	  More.Hides[kind]   its hide and second shade, as KaijuShapes.Hides
	  More.Hover[kind]   a floater's height above the ground, as KaijuShapes.Hover
	  More.install(kit) -> { [kind] = function(model, palette, hide, hide2) }

	The builders are in two halves, Shared.KaijuShapesMoreA (Prisma to
	Silkling) and Shared.KaijuShapesMoreB (Tarrask to Lumeballoon); this
	module hands both the helpers they share.
]]
local More = {}

local V, C = Vector3.new, Color3.fromRGB
local CF, A = CFrame.new, CFrame.Angles
local rad = math.rad

More.Hides = {
	Prisma = { C(40, 92, 172), C(70, 128, 204) },
	Clawtide = { C(132, 58, 50), C(104, 44, 40) },
	Tuskmound = { C(96, 62, 44), C(72, 48, 36) },
	Steamhide = { C(152, 48, 42), C(118, 36, 32) },
	Hillback = { C(104, 134, 62), C(140, 140, 132) },
	Inkwrap = { C(72, 58, 108), C(52, 42, 82) },
	Nullplate = { C(58, 86, 88), C(42, 64, 68) },
	Crestbull = { C(104, 80, 62), C(80, 62, 50) },
	Rubbleking = { C(212, 198, 162), C(182, 168, 134) },
	Kickjaw = { C(50, 80, 62), C(132, 156, 132) },
	Ogretoad = { C(98, 112, 92), C(134, 142, 120) },
	Tritail = { C(36, 42, 64), C(56, 64, 90) },
	Ashcrawler = { C(50, 36, 34), C(74, 50, 44) },
	Shrieker = { C(88, 72, 62), C(64, 52, 46) },
	Tonguefrost = { C(202, 212, 224), C(170, 184, 200) },
	Glidespine = { C(54, 84, 54), C(72, 106, 66) },
	Fathomweb = { C(42, 58, 68), C(150, 200, 214) },
	Spitgill = { C(112, 118, 126), C(204, 204, 198) },
	Duskbat = { C(36, 32, 36), C(58, 50, 54) },
	Tendrilis = { C(46, 42, 58), C(68, 62, 82) },
	Snipclaw = { C(68, 62, 58), C(94, 88, 82) },
	Needlewing = { C(122, 56, 42), C(206, 196, 170) },
	Hollowbone = { C(208, 204, 192), C(170, 166, 154) },
	Ribbonarm = { C(32, 36, 36), C(54, 60, 58) },
	Frostmaw = { C(210, 222, 234), C(180, 194, 210) },
	Hivecrystal = { C(104, 82, 56), C(78, 62, 44) },
	Peelcroc = { C(58, 84, 58), C(42, 62, 44) },
	Magnetjaw = { C(48, 60, 96), C(68, 82, 120) },
	Capspore = { C(214, 198, 174), C(54, 58, 46) },
	Coinmaw = { C(96, 58, 42), C(126, 78, 56) },
	Silkling = { C(80, 84, 92), C(198, 202, 208) },
	Tarrask = { C(86, 68, 52), C(64, 52, 42) },
	Gorebull = { C(98, 90, 80), C(74, 68, 60) },
	Yetihide = { C(216, 222, 234), C(182, 192, 208) },
	Longneck = { C(72, 110, 74), C(56, 88, 60) },
	Barnacrab = { C(124, 84, 64), C(94, 68, 56) },
	Rancorn = { C(98, 86, 78), C(76, 66, 60) },
	Gashclaw = { C(58, 76, 68), C(80, 98, 88) },
	Mossgiant = { C(88, 88, 84), C(78, 114, 56) },
	Blackhorn = { C(32, 32, 36), C(50, 50, 56) },
	Gluttonjaw = { C(108, 92, 66), C(142, 122, 88) },
	Lashape = { C(142, 60, 46), C(112, 46, 38) },
	Oculus = { C(74, 84, 106), C(100, 112, 136) },
	Quillhorn = { C(100, 78, 56), C(78, 60, 44) },
	Phasehorn = { C(58, 66, 98), C(80, 88, 122) },
	Lightbird = { C(198, 178, 130), C(162, 142, 102) },
	Pulsewing = { C(32, 32, 36), C(54, 54, 60) },
	Dunemaw = { C(198, 162, 114), C(166, 132, 92) },
	Lashlight = { C(58, 56, 82), C(78, 76, 106) },
	Inkstalk = { C(172, 188, 208), C(142, 158, 180) },
	Skyrazor = { C(122, 62, 52), C(96, 48, 42) },
	Thornlash = { C(36, 42, 54), C(54, 62, 78) },
	Flickerstripe = { C(32, 32, 32), C(222, 222, 222) },
	Cleaverhead = { C(126, 152, 180), C(100, 124, 152) },
	Starcrop = { C(42, 78, 82), C(60, 100, 104) },
	Drillmole = { C(112, 114, 122), C(72, 74, 82) },
	Gulper = { C(98, 118, 110), C(76, 94, 88) },
	Pipsqueak = { C(152, 64, 46), C(120, 50, 38) },
	Shadowsphere = { C(234, 234, 234), C(28, 28, 32) },
	Twinsong = { C(48, 54, 74), C(72, 78, 100) },
	Lumeballoon = { C(216, 206, 178), C(182, 172, 144) },
}

-- The floaters: Prisma's crystal, Oculus's saucer and the fliers hovering
-- on their wings (their legs dangle).
More.Hover = { Prisma = 0.7, Shrieker = 0.9, Needlewing = 1.0, Oculus = 1.0, Lightbird = 1.0 }

function More.install(kit)
	local make, limb, plate, wedge, root = kit.make, kit.limb, kit.plate, kit.wedge, kit.root
	local CLAW = kit.Claw
	local h = {
		make = make,
		limb = limb,
		glow = kit.glow,
		plate = plate,
		wedge = wedge,
		root = root,
		Claw = CLAW,
	}

	-- A block from a to b (its Y along them), `width` by `depth`; on a joint
	-- of `motion` at a, if given.
	function h.beam(m, p, name, a: Vector3, b: Vector3, width, depth, color, motion: string?, side: number?)
		local d = b - a
		local y = d.Unit
		local x = y:Cross(if math.abs(y.Y) > 0.95 then V(0, 0, 1) else V(0, 1, 0)).Unit
		local cf = CFrame.fromMatrix((a + b) / 2, x, y)
		if motion then
			return limb(m, p, name, V(width, d.Magnitude, depth), cf, a, motion, side or 1, color)
		end
		return make(m, p, name, V(width, d.Magnitude, depth), cf, color)
	end
	local beam = h.beam

	-- A beam of its element's light.
	function h.litBeam(m, p, name, a: Vector3, b: Vector3, width, pal)
		local part = beam(m, p, name, a, b, width, width, pal.Glow)
		part.Material = Enum.Material.Neon
		part.CastShadow = false
		return part
	end

	-- A ball, or a disc standing on its face (a Cylinder turned upright),
	-- `d` across.
	function h.ball(m, p, name, d: number, at: Vector3, color, material)
		local part = make(m, p, name, V(d, d, d), CF(at), color, material)
		part.Shape = Enum.PartType.Ball
		return part
	end
	function h.disc(m, p, name, d: number, thick: number, cf: CFrame, color, material)
		local part = make(m, p, name, V(thick, d, d), cf * A(0, 0, rad(90)), color, material)
		part.Shape = Enum.PartType.Cylinder
		return part
	end

	-- A triangle between three points, `thick`: two right wedges (Concepts).
	function h.triangle(m, p, name, a: Vector3, b: Vector3, c: Vector3, thick, color)
		if (b - a).Magnitude > (c - b).Magnitude and (b - a).Magnitude > (c - a).Magnitude then
			a, c = c, a
		elseif (c - a).Magnitude > (c - b).Magnitude then
			a, b = b, a
		end
		local back = (c - b).Unit
		local right = (c - a):Cross(b - a).Unit
		local up = back:Cross(right).Unit
		local height = math.abs((a - b):Dot(up))
		local one = wedge(
			m,
			p,
			name,
			V(thick, height, math.abs((a - b):Dot(back))),
			CFrame.fromMatrix((a + b) / 2, right, up, back),
			color
		)
		wedge(m, p, name, V(thick, height, math.abs((a - c):Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color)
		return one
	end

	-- A square pyramid `w` across and `tall` high on the frame's base (point
	-- down if `down`): four corner wedges, each one's point at the middle.
	local TURN = { [1] = { [1] = 90, [-1] = 180 }, [-1] = { [1] = 0, [-1] = 270 } }
	function h.pyramid(m, p, name, frame: CFrame, w: number, tall: number, color, down: boolean?, material)
		local base = if down then frame * A(math.pi, 0, 0) else frame
		local first
		for _, qx in { 1, -1 } do
			for _, qz in { 1, -1 } do
				local part = make(
					m,
					p,
					name,
					V(w / 2, tall, w / 2),
					base * CF(qx * w / 4, tall / 2, qz * w / 4) * A(0, rad(TURN[qx][qz]), 0),
					color,
					material,
					"CornerWedgePart"
				)
				first = first or part
			end
		end
		return first
	end

	-- A leg from its hip at (x, top, z) to a foot on the ground: a thigh on
	-- its Stride joint, a shin, a foot and `toes` claws; its knee bent
	-- forward `bend` studs (back if negative). `side` sets which legs step
	-- together (its own side if not given).
	function h.leg(m, body, x, top, z, w, H, H2, toes: number?, bend: number?, side: number?)
		bend = bend or 0.28
		local hip = V(x, top, z)
		local knee = V(x * 1.06, top * 0.52, z - bend)
		local ankle = V(x * 1.06, 0.28, z + bend * 0.1)
		local p = beam(m, body, "Thigh", hip, knee, w, w * 1.1, H, "Stride", side or (if x < 0 then -1 else 1))
		beam(m, p, "Shin", knee, ankle, w * 0.72, w * 0.78, H2)
		local front = ankle.Z - w * 0.2
		make(m, p, "Foot", V(w * 1.05, 0.28, w * 1.35), CF(ankle.X, 0.14, front), H2)
		for i = 1, toes or 0 do
			wedge(
				m,
				p,
				"Toe",
				V(w * 0.2, 0.2, 0.3),
				CF(ankle.X + (i - (toes + 1) / 2) * w * 0.3, 0.1, front - w * 0.67 - 0.1),
				CLAW
			)
		end
		return p
	end

	-- A straight pillar of a leg, `w` thick, from its hip at (x, top, z) to
	-- a broad foot; `nails` toenails.
	function h.pillar(m, body, x, top, z, w, H, H2, nails: number?, side: number?)
		local foot = 0.3
		local p = limb(
			m,
			body,
			"Leg",
			V(w, top - foot * 0.5, w),
			CF(x, (top + foot * 0.5) / 2, z),
			V(x, top, z),
			"Stride",
			side or (if x < 0 then -1 else 1),
			H
		)
		make(m, p, "Foot", V(w * 1.16, foot, w * 1.2), CF(x, foot / 2, z - w * 0.08), H2)
		for i = 1, nails or 0 do
			make(
				m,
				p,
				"Nail",
				V(w * 0.22, foot * 0.6, 0.12),
				CF(x + (i - (nails + 1) / 2) * w * 0.34, foot * 0.3, z - w * 0.68 - 0.06),
				CLAW
			)
		end
		return p
	end

	-- A thin bent leg (a spider's, a crab's, an insect's): from its hip
	-- through its knee to its tip, the upper half on its Stride joint.
	function h.spindle(m, body, hip: Vector3, knee: Vector3, tip: Vector3, w, H, H2, side: number?)
		local p = beam(m, body, "Leg", hip, knee, w, w, H, "Stride", side or (if hip.X < 0 then -1 else 1))
		beam(m, p, "Shin", knee, tip, w * 0.75, w * 0.75, H2)
		return p
	end

	-- An arm from its shoulder through its elbow to its hand: the upper arm
	-- on its Arm joint, the forearm on it. Returns the arm.
	function h.arm(m, body, shoulder: Vector3, elbow: Vector3, hand: Vector3, w, H, H2)
		local p = beam(m, body, "Arm", shoulder, elbow, w, w, H, "Arm", if shoulder.X < 0 then -1 else 1)
		beam(m, p, "Forearm", elbow, hand, w * 0.86, w * 0.86, H2 or H)
		return p
	end

	-- `n` claws at a hand, pointing along `dir` (down and forward if not
	-- given), `s` long.
	function h.talons(m, p, at: Vector3, n: number, s: number, color, dir: Vector3?)
		dir = (dir or V(0, -1, -0.6)).Unit
		local across = if math.abs(dir.X) > 0.9 then V(0, 0, 1) else V(1, 0, 0)
		for i = 1, n do
			local base = at + across * (i - (n + 1) / 2) * s * 0.32
			beam(m, p, "Claw", base, base + dir * s, s * 0.16, s * 0.2, color)
		end
	end

	-- A tail (or a neck, or a tentacle: `name`) through `points`: a segment
	-- between each two on its own Tail joint, each `widths[i]` across;
	-- `deco(seg, i, middle, width)` dresses each. Returns its last segment.
	function h.tail(m, body, points, widths, H, deco, name: string?)
		local parent = body
		for i = 1, #points - 1 do
			local w = widths[i] or widths[#widths]
			local p = beam(m, parent, name or "Tail", points[i], points[i + 1], w, w * 0.85, H, "Tail")
			if deco then
				deco(p, i, (points[i] + points[i + 1]) / 2, w)
			end
			parent = p
		end
		return parent
	end

	-- A bat's wing out to one side on its Wing joint at `a`: a finger out to
	-- its wrist `b`, the membrane from there to its tip `c` and back to `d`
	-- on its trailing edge, in `skin`. Returns the wing.
	function h.batWing(m, body, a: Vector3, b: Vector3, c: Vector3, d: Vector3, H, skin)
		local side = if b.X < 0 then -1 else 1
		local w = limb(m, body, "Wing", V(0.24, 0.28, 0.28), CF(a), a, "Wing", side, H)
		h.triangle(m, w, "WingMembrane", a, b, c, 0.07, skin)
		h.triangle(m, w, "WingMembrane", a, c, d, 0.07, skin)
		beam(m, w, "WingFinger", a, b, 0.15, 0.17, H)
		beam(m, w, "WingFinger", b, c, 0.1, 0.12, H)
		return w
	end

	-- An insect's wing: a sheet `len` out to one side from `at` on its Wing
	-- joint, raised `lift` and swept back `sweep` degrees, see-through, a
	-- vein down it in `vein`. Returns it and its frame at the root.
	function h.pane(m, body, at: Vector3, len, wide, lift, sweep, side, color, vein)
		local frame = CF(at) * A(0, rad(-sweep * side), rad(lift * side))
		local p = limb(m, body, "Wing", V(len, 0.05, wide), frame * CF(side * len / 2, 0, 0), at, "Wing", side, color)
		p.Material, p.Transparency = Enum.Material.Glass, 0.35
		if vein then
			make(m, p, "WingVein", V(len * 0.94, 0.07, 0.06), frame * CF(side * len / 2, 0, -wide * 0.18), vein)
		end
		return p, frame
	end

	function h.eyes(m, head, x, y, z, size: Vector3, pal)
		for _, side in { -1, 1 } do
			kit.glow(m, head, "Eye", size, CF(side * x, y, z), pal)
		end
	end

	-- Turns a joint's frame at its pivot (its rest pose unchanged).
	function h.reseat(p, frame: CFrame)
		local joint = p:FindFirstChild("CreatureMotion")
		joint.C0 = joint.Part0.CFrame:Inverse() * frame
		joint.C1 = p.CFrame:Inverse() * frame
		joint:SetAttribute("CreatureRest", joint.C0)
	end

	local B = {}
	for _, half in { "KaijuShapesMoreA", "KaijuShapesMoreB" } do
		for name, builder in require(script.Parent[half]).install(h) do
			B[name] = function(m, pal, H, H2)
				builder(m, pal, H, H2)
				More.finish(m, pal, H, H2, make)
			end
		end
	end
	return B
end

-- The finish -------------------------------------------------------------------------------------------
-- What the first kinds had by hand, given to every one of these after it's
-- built, up to Budget parts in all:
--   eyes      every Eye a dark pupil on its front, so it looks at something
--   trunk     (the Body, else the biggest block of hide) lying along the
--             ground: veins of its element down both flanks, lit, unless it
--             glows already; standing up: a paler belly down its chest,
--             banded; and with fewer than Plated plates of its element's
--             colour on it, a ridge of them along its back
--   blocks    its biggest blocks of hide (Blocks of them, each with a face
--             at least Face across turned up) a lighter cap on top, as if
--             bevelled and lit from above, and a long one Seam lines across
--             it, banded like scales
-- The pale parts are HideShades: a portrait lifts them with the hide
-- (KaijuModels.forPortrait).
More.Finish = {
	Budget = 86,
	Blocks = 7,
	Face = 0.5,
	Cap = 0.06,
	Light = 0.22,
	Belly = 0.3,
	Dark = 0.38,
	Seam = 0.9,
	Plated = 8,
	Pupil = Color3.fromRGB(18, 18, 24),
}

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 1.5 / 255
end

-- A block's axes, as (unit in the world, its size along it).
local function axes(part: BasePart)
	local cf, size = part.CFrame, part.Size
	return {
		{ cf.RightVector, size.X },
		{ cf.UpVector, size.Y },
		{ cf.LookVector, size.Z },
	}
end

-- The axis most along `dir` (index, signed so it points that way), and how
-- closely.
local function along(list, dir: Vector3): (number, number, number)
	local best, sign, score = 1, 1, -1
	for i, axis in list do
		local d = axis[1]:Dot(dir)
		if math.abs(d) > score then
			best, sign, score = i, if d < 0 then -1 else 1, math.abs(d)
		end
	end
	return best, sign, score
end

-- A frame on the face of `part` that points along axis `i` (signed),
-- `out` beyond it, its Y the face's normal; and the face's two sizes, the
-- first along the frame's X, the second along its Z.
local function onFace(part: BasePart, list, i: number, sign: number, out: number)
	local others = {}
	for j = 1, 3 do
		if j ~= i then
			table.insert(others, j)
		end
	end
	local normal = list[i][1] * sign
	local x, z = list[others[1]][1], list[others[2]][1]
	local at = part.CFrame.Position + normal * (list[i][2] / 2 + out)
	return CFrame.fromMatrix(at, x, normal, -z), list[others[1]][2], list[others[2]][2]
end

-- The frame turned so its X runs along the face's longer way.
local function lengthwise(frame: CFrame, w: number, d: number): (CFrame, number, number)
	if w >= d then
		return frame, w, d
	end
	return frame * CFrame.Angles(0, math.rad(90), 0), d, w
end

function More.finish(m: Model, pal, H: Color3, H2: Color3, make)
	local f = More.Finish
	local count, hides, eyes, plated = 0, {}, {}, 0
	local glowing: { [BasePart]: number } = {}
	local trunk: BasePart? = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			if same(d.Color, pal.Plate) then
				plated += 1
			end
			if d.Material == Enum.Material.Neon then
				local weld = d:FindFirstChildOfClass("WeldConstraint")
				if weld and weld.Part0 then
					glowing[weld.Part0] = (glowing[weld.Part0] or 0) + 1
				end
				if d.Name == "Eye" then
					table.insert(eyes, d)
				end
			end
			local block = d.ClassName == "Part" and d.Shape == Enum.PartType.Block
			if block and d.Material == Enum.Material.SmoothPlastic and (same(d.Color, H) or same(d.Color, H2)) then
				table.insert(hides, d)
				if d.Name == "Body" and not trunk then
					trunk = d
				end
			end
		end
	end
	local room = f.Budget - count
	local function add(...)
		if room <= 0 then
			return nil
		end
		room -= 1
		return make(...)
	end
	local function shade(part: BasePart?)
		if part then
			part:SetAttribute("HideShade", true)
		end
		return part
	end
	table.sort(hides, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	trunk = trunk or hides[1]
	local up, front = Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)

	-- Eyes: a pupil on each, on its face turned most to the front.
	for _, eye in eyes do
		local list = axes(eye)
		local face, sign = along(list, front)
		local frame, w, d = onFace(eye, list, face, sign, 0.005)
		-- (half the eye across, a tiny one's no smaller than a speck)
		local s = math.max(math.min(w, d) * 0.5, 0.035)
		add(m, eye, "Pupil", Vector3.new(s, 0.02, s), frame, f.Pupil)
	end

	if trunk then
		local list = axes(trunk)
		local long = 1
		for i = 2, 3 do
			if list[i][2] > list[long][2] then
				long = i
			end
		end
		local standing = math.abs(list[long][1]:Dot(up)) > 0.7
		if standing then
			-- A paler belly down its chest, banded.
			local face, sign = along(list, front)
			local frame, w, d = onFace(trunk, list, face, sign, 0.025)
			local belly = trunk.Color:Lerp(Color3.new(1, 1, 1), f.Belly)
			if w >= 0.5 and d >= 0.6 then
				local panel = shade(add(m, trunk, "Belly", Vector3.new(w * 0.56, 0.05, d * 0.74), frame, belly))
				if panel then
					-- (bands across it, stacked up its upright way)
					local alongZ = math.abs(frame.LookVector:Dot(up)) > math.abs(frame.RightVector:Dot(up))
					local tall, across = if alongZ then d else w, if alongZ then w else d
					for k = 1, 2 do
						local at = (k / 3 - 0.5) * tall * 0.74
						add(
							m,
							trunk,
							"Seam",
							if alongZ then Vector3.new(across * 0.56, 0.06, 0.05) else Vector3.new(0.05, 0.06, across * 0.74),
							frame * (if alongZ then CFrame.new(0, 0.01, at) else CFrame.new(at, 0.01, 0)),
							belly:Lerp(Color3.new(0, 0, 0), f.Dark)
						)
					end
				end
			end
		elseif (glowing[trunk] or 0) < 2 then
			-- Veins of its element down its flanks, lit.
			local side = along(list, Vector3.new(1, 0, 0))
			for _, sign in { -1, 1 } do
				local frame, length, height = lengthwise(onFace(trunk, list, side, sign, 0.03))
				if length >= 0.8 then
					for _, at in { 0.16, -0.12 } do
						local vein = add(
							m,
							trunk,
							"Vein",
							Vector3.new(length * 0.6, 0.06, 0.07),
							frame * CFrame.new(0, 0, at * height),
							pal.Plate,
							Enum.Material.Neon
						)
						if vein then
							vein.CastShadow = false
						end
					end
				end
			end
		end
		if plated < f.Plated then
			-- A ridge of its element along its back.
			local top, sign = along(list, up)
			local frame, length, breadth = lengthwise(onFace(trunk, list, top, sign, 0.02))
			local n = math.clamp(math.floor(length / 0.55), 2, 4)
			local s = math.clamp(breadth * 0.28, 0.16, 0.36)
			for k = 1, n do
				local x = (k - (n + 1) / 2) * length * 0.7 / math.max(1, n - 1)
				add(
					m,
					trunk,
					"Ridge",
					Vector3.new(s * 0.9, s, s * 0.9),
					frame * CFrame.new(x, s * 0.35, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0),
					pal.Plate
				)
			end
		end
	end

	-- Its biggest blocks, biggest first: a lit cap, seams across it.
	local done = 0
	for _, part in hides do
		if done >= f.Blocks or room <= 0 then
			break
		end
		local list = axes(part)
		local top, sign, upness = along(list, up)
		if upness < 0.6 then
			continue -- (no face turned up enough to catch the light)
		end
		local frame, w, d = onFace(part, list, top, sign, f.Cap / 2)
		if w < f.Face or d < f.Face then
			continue
		end
		done += 1
		shade(add(m, part, "Bevel", Vector3.new(w * 0.84, f.Cap, d * 0.84), frame, part.Color:Lerp(Color3.new(1, 1, 1), f.Light)))
		local turned, long, short = lengthwise(frame, w, d)
		local seams = math.min(2, math.floor(long / f.Seam) - 1)
		for k = 1, seams do
			local x = (k / (seams + 1) - 0.5) * long * 0.84
			add(
				m,
				part,
				"Seam",
				Vector3.new(0.05, f.Cap, short * 0.84),
				turned * CFrame.new(x, f.Cap * 0.5, 0),
				part.Color:Lerp(Color3.new(0, 0, 0), f.Dark)
			)
		end
	end
end

return More
