--[[
	The roster's 28 new kinds (Shared.KaijuRoster), built from blocks like
	the first four (Shared.KaijuModels): a hide of the kind's own colour (as
	its concept render has it, docs/kaiju-concepts), plates in its element's
	colour and glows in its element's light. Each faces -Z, stands on the
	ground at the origin, about two to five studs tall at scale 1.

	KaijuModels hands its builders' helpers in (install) and takes back a
	builder for each kind:

	  Shapes.install(kit) -> { [kind] = function(model, palette) }
	  Shapes.Hides[kind]  its hide and second shade (KaijuModels.forPortrait
	                      lifts the dark ones)
	  Shapes.Hover[kind]  a flyer's height above the ground, studs at scale 1
	                      (its legs dangle; KaijuModels adds it to its hip
	                      height)

	Joints, as on the first four (Shared.CreatureMotion): its trunk on a Body
	joint at its hips; legs (Stride), arms (Arm), jaw (Jaw), tail segments
	(Tail); a flyer's wings (Wing), a many-headed one's heads and a
	serpent's head (Head).
]]
local Shapes = {}

local V, C = Vector3.new, Color3.fromRGB
local CF, A = CFrame.new, CFrame.Angles
local rad = math.rad

-- Each kind's hide and its second shade.
Shapes.Hides = {
	Emberjaw = { C(40, 40, 46), C(64, 62, 70) },
	Stormwing = { C(112, 120, 140), C(150, 158, 176) },
	Ironhide = { C(60, 74, 108), C(82, 98, 134) },
	Sickleclaw = { C(88, 100, 70), C(112, 124, 90) },
	Moonmoth = { C(226, 214, 186), C(124, 104, 92) },
	Shellfire = { C(150, 116, 62), C(118, 90, 48) },
	Mossback = { C(94, 70, 50), C(74, 108, 54) },
	Bastion = { C(152, 158, 168), C(126, 132, 144) },
	Hulkshell = { C(80, 98, 90), C(102, 120, 110) },
	Dreadmaw = { C(214, 208, 196), C(178, 172, 160) },
	Hornblade = { C(152, 76, 54), C(118, 58, 42) },
	Titanfin = { C(66, 104, 150), C(92, 130, 174) },
	Drillhorn = { C(82, 64, 54), C(108, 88, 72) },
	Grandape = { C(98, 74, 62), C(152, 148, 142) },
	Thornlob = { C(112, 98, 132), C(90, 78, 108) },
	Starspine = { C(86, 86, 142), C(108, 108, 168) },
	Nulltalon = { C(44, 44, 50), C(70, 68, 64) },
	Sporeback = { C(94, 92, 74), C(74, 72, 58) },
	Nightwing = { C(38, 34, 42), C(86, 44, 50) },
	Longcoil = { C(72, 132, 114), C(56, 108, 92) },
	Glassjaw = { C(172, 158, 132), C(146, 132, 108) },
	Razorclaw = { C(38, 46, 66), C(58, 68, 92) },
	Triskull = { C(172, 132, 66), C(138, 104, 50) },
	Brightsteel = { C(188, 194, 206), C(150, 156, 172) },
	Dreadcrown = { C(150, 52, 46), C(62, 42, 46) },
	Bladebrow = { C(150, 160, 180), C(124, 134, 156) },
	Lankshade = { C(196, 206, 184), C(168, 178, 158) },
	Voltfin = { C(42, 52, 78), C(200, 196, 180) },
}

Shapes.Hover = { Stormwing = 1.1, Moonmoth = 1.1, Nightwing = 0.9 }

function Shapes.install(kit)
	local make, limb, glow, plate, wedge, claws, root = kit.make, kit.limb, kit.glow, kit.plate, kit.wedge, kit.claws, kit.root
	local CLAW = kit.Claw

	-- A block from a to b, `w` thick (on a joint of `kind` at a, if given).
	local function strut(model, attach, name, a: Vector3, b: Vector3, w: number, color, kind: string?, side: number?)
		local dir = b - a
		local look = dir.Unit
		local right = look:Cross(if math.abs(look.Y) > 0.95 then V(0, 0, -1) else V(0, 1, 0)).Unit
		local cf = CFrame.fromMatrix((a + b) / 2, right, right:Cross(look))
		local size = V(w, w, dir.Magnitude)
		if kind then
			return limb(model, attach, name, size, cf, a, kind, side or 1, color)
		end
		return make(model, attach, name, size, cf, color)
	end

	-- A leg straight down from its hip at (x, top, z) to a foot on the
	-- ground, `w` wide; claws on its toes.
	local function leg(model, trunk, x, z, top, w, foot: Vector3, side, hide, hide2, toes: number?)
		local h = top - foot.Y * 0.5
		local p = limb(model, trunk, "Leg", V(w, h, w), CF(x, top - h / 2, z), V(x, top, z), "Stride", side, hide)
		local front = z - (foot.Z - w) / 2
		make(model, p, "Foot", foot, CF(x, foot.Y / 2, front), hide2)
		if toes then
			claws(model, p, x, foot.Y * 0.45, front - foot.Z / 2 - 0.08, toes, foot.X / toes, V(0.14, 0.16, 0.24))
		end
		return p
	end

	-- An arm hanging from its shoulder at `at`, swung forward by `pitch` and
	-- out by `roll` (degrees). Returns it and the frame at its hand.
	local function arm(model, trunk, at: Vector3, size: Vector3, pitch, roll, side, color)
		local frame = CF(at) * A(rad(pitch), 0, rad(roll * side))
		local p = limb(model, trunk, "Arm", size, frame * CF(0, -size.Y / 2, 0), at, "Arm", side, color)
		return p, frame * CF(0, -size.Y, 0)
	end

	-- A tail from `top`, each segment tilted down by its own angle (degrees;
	-- up if negative) and turned by `yaw`; `deco(seg, frame, i, size)`
	-- dresses each. Returns its last segment and the frame at its tip.
	local function tail(model, parent, top: Vector3, sizes, tilts, color, deco, yaw: number?)
		local frame
		for i, s in sizes do
			local tilt = A(0, rad(yaw or 0), 0) * A(rad(tilts[i] or tilts[#tilts]), 0, 0)
			frame = CF(top + tilt:VectorToWorldSpace(V(0, 0, s.Z / 2))) * tilt
			local seg = limb(model, parent, "Tail", s, frame, top, "Tail", 1, color)
			if deco then
				deco(seg, frame, i, s)
			end
			parent, top = seg, top + tilt:VectorToWorldSpace(V(0, 0, s.Z - 0.08))
		end
		return parent, frame
	end

	-- A wing out to one side from its root at `at`, raised `lift` degrees and
	-- swept back `sweep`. Returns it and the frame at its root.
	local function wing(model, trunk, at: Vector3, size: Vector3, lift, sweep, side, color)
		local frame = CF(at) * A(0, rad(-sweep * side), rad(lift * side))
		local p = limb(model, trunk, "Wing", size, frame * CF(side * size.X / 2, 0, 0), at, "Wing", side, color)
		return p, frame
	end

	-- Turns a joint's frame at its pivot (its rest pose unchanged): a wing
	-- held upright flaps about the vertical, not about its own plane.
	local function reseat(p, frame: CFrame)
		local joint = p:FindFirstChild("CreatureMotion")
		joint.C0 = joint.Part0.CFrame:Inverse() * frame
		joint.C1 = p.CFrame:Inverse() * frame
		joint:SetAttribute("CreatureRest", joint.C0)
	end

	-- A spike: a block turned on its edge in its element's colour, a glow
	-- through its middle if `lit`.
	local function spike(model, attach, s: number, cf: CFrame, pal, lit: boolean?)
		local p = plate(model, attach, "Spike", V(s * 0.3, s, s), cf * A(rad(45), 0, 0), pal)
		if lit then
			glow(model, attach, "SpikeGlow", V(s * 0.34, s * 0.68, s * 0.68), cf * A(rad(45), 0, 0), pal)
		end
		return p
	end

	local function eyes(model, head, x, y, z, size: Vector3, pal)
		for _, side in { -1, 1 } do
			glow(model, head, "Eye", size, CF(side * x, y, z), pal)
		end
	end

	local B = {}

	-- Emberjaw: a black upright brute, glowing plates down its back and tail.
	function B.Emberjaw(model, pal, H, H2)
		local r = root(model, V(2, 2, 2), 2.3)
		local lean = CF(0, 2.85, 0.15) * A(rad(-8), 0, 0)
		local torso = limb(model, r, "Torso", V(2.0, 2.5, 1.7), lean, V(0, 1.75, 0.2), "Body", 1, H)
		make(model, torso, "Belly", V(1.3, 1.7, 0.2), lean * CF(0, -0.15, -0.86), H2)
		for i, s in { 1.0, 1.25, 1.15, 0.9 } do
			spike(model, torso, s, lean * CF(0, 1.05 - (i - 1) * 0.55, 0.86), pal, true)
		end
		local head = make(model, torso, "Head", V(1.15, 0.95, 1.25), CF(0, 4.3, -0.5), H)
		make(model, head, "Snout", V(0.95, 0.55, 0.75), CF(0, 4.18, -1.3), H)
		make(model, head, "Brow", V(1.2, 0.22, 0.5), CF(0, 4.75, -0.95), H2)
		eyes(model, head, 0.38, 4.48, -1.14, V(0.2, 0.12, 0.08), pal)
		local jaw = limb(model, head, "Jaw", V(0.9, 0.28, 1.0), CF(0, 3.78, -1.15), V(0, 3.92, -0.65), "Jaw", 1, H2)
		for i = -1, 1 do
			make(model, jaw, "Tooth", V(0.14, 0.14, 0.12), CF(i * 0.28, 3.97, -1.58), CLAW)
		end
		for _, side in { -1, 1 } do
			local p, hand = arm(model, torso, V(side * 1.05, 3.4, -0.45), V(0.45, 0.95, 0.5), 40, 12, side, H)
			claws(model, p, hand.Position.X, hand.Position.Y - 0.05, hand.Position.Z - 0.1, 3, 0.14, V(0.1, 0.2, 0.14))
			local l = leg(model, torso, side * 0.62, 0.35, 1.75, 0.8, V(1.0, 0.4, 1.35), side, H, H2, 3)
			make(model, l, "Thigh", V(0.95, 0.85, 1.05), CF(side * 0.66, 1.45, 0.3), H)
		end
		tail(
			model,
			torso,
			V(0, 1.95, 0.95),
			{ V(1.05, 0.9, 1.1), V(0.85, 0.72, 1.05), V(0.66, 0.55, 1.0), V(0.48, 0.4, 0.95), V(0.3, 0.26, 0.85) },
			{ 30, 20, 10, 2, -4 },
			H,
			function(seg, frame, i, s)
				if i <= 4 then
					spike(model, seg, 0.9 - i * 0.12, frame * CF(0, s.Y / 2, 0), pal, true)
				end
			end
		)
	end

	-- Stormwing: a slate flyer, all wing, a beak and a crest of light.
	function B.Stormwing(model, pal, H, H2)
		local r = root(model, V(1.1, 1.1, 1.1), 1.45)
		local tilt = CF(0, 1.5, 0.05) * A(rad(-30), 0, 0)
		local body = limb(model, r, "Body", V(0.85, 1.0, 1.2), tilt, V(0, 1.2, 0.2), "Body", 1, H)
		plate(model, body, "Chest", V(0.6, 0.65, 0.12), tilt * CF(0, 0.05, -0.62), pal)
		make(model, body, "Neck", V(0.4, 0.55, 0.4), CF(0, 2.15, -0.42) * A(rad(-25), 0, 0), H)
		local head = make(model, body, "Head", V(0.5, 0.5, 0.75), CF(0, 2.5, -0.62), H)
		make(model, head, "Beak", V(0.28, 0.2, 1.1), CF(0, 2.47, -1.5), H2)
		eyes(model, head, 0.26, 2.58, -0.82, V(0.06, 0.12, 0.14), pal)
		local jaw = limb(model, head, "Jaw", V(0.24, 0.14, 1.0), CF(0, 2.3, -1.4), V(0, 2.34, -0.9), "Jaw", 1, H2)
		make(model, jaw, "Tip", V(0.2, 0.12, 0.2), CF(0, 2.32, -1.92), H2)
		plate(model, head, "Crest", V(0.18, 0.3, 0.55), CF(0, 2.82, -0.42), pal)
		for i = -2, 2 do
			glow(model, head, "Crest", V(0.07, 0.5, 0.07), CF(0, 2.9, -0.42) * A(rad(-25), 0, rad(i * 22)) * CF(0, 0.3, 0), pal)
		end
		for _, side in { -1, 1 } do
			local w, frame =
				wing(model, body, V(side * 0.4, 1.85, -0.15), V(1.9, 0.12, 1.15), 14, 8, side, H)
			plate(model, w, "Edge", V(1.75, 0.15, 0.22), frame * CF(side * 0.95, 0, -0.5), pal)
			local tip = frame * CF(side * 1.85, 0, 0) * A(0, rad(-18 * side), rad(-6 * side))
			make(model, w, "Outer", V(1.6, 0.1, 0.75), tip * CF(side * 0.78, 0, -0.1), H2)
			glow(model, w, "Tip", V(1.45, 0.13, 0.12), tip * CF(side * 0.82, 0, -0.45), pal)
			leg(model, body, side * 0.22, 0.35, 0.95, 0.16, V(0.32, 0.1, 0.4), side, H, H2, 2)
		end
		tail(model, body, V(0, 1.1, 0.6), { V(0.3, 0.25, 0.6), V(0.18, 0.16, 0.55) }, { 35, 20 }, H, function(seg, frame, i, s)
			if i == 2 then
				glow(model, seg, "Vane", V(0.3, 0.06, 0.25), frame * CF(0, 0, s.Z / 2), pal)
			end
		end)
	end

	-- Ironhide: a low navy roller, rows of glowing spikes along its back,
	-- a horn on its snout.
	function B.Ironhide(model, pal, H, H2)
		local r = root(model, V(2, 1, 2.4), 1.3)
		local body = limb(model, r, "Body", V(2.1, 1.1, 3.1), CF(0, 1.5, 0.1), V(0, 1.25, 0.1), "Body", 1, H)
		make(model, body, "Dome", V(2.4, 0.55, 2.9), CF(0, 2.2, 0.15), H2)
		make(model, body, "Crown", V(1.7, 0.4, 2.3), CF(0, 2.6, 0.15), H)
		for _, x in { -0.55, 0, 0.55 } do
			for _, z in { -0.7, 0.05, 0.8 } do
				plate(model, body, "Spike", V(0.24, 0.4, 0.24), CF(x, 2.98, z) * A(0, rad(45), 0), pal)
				glow(model, body, "Tip", V(0.14, 0.14, 0.14), CF(x, 3.22, z) * A(0, rad(45), 0), pal)
			end
		end
		for _, x in { -1, 1 } do
			for _, z in { -0.9, 0.15, 1.2 } do
				plate(model, body, "Spike", V(0.36, 0.22, 0.22), CF(x * 1.32, 2.35, z), pal)
			end
		end
		local head = make(model, body, "Head", V(1.1, 0.8, 1.0), CF(0, 1.55, -1.95), H)
		make(model, head, "Snout", V(0.8, 0.55, 0.6), CF(0, 1.42, -2.7), H2)
		plate(model, head, "Horn", V(0.24, 0.65, 0.26), CF(0, 1.95, -2.82) * A(rad(-22), 0, 0), pal)
		plate(model, head, "Horn", V(0.18, 0.35, 0.2), CF(0, 2.05, -2.25) * A(rad(-15), 0, 0), pal)
		eyes(model, head, 0.4, 1.72, -2.42, V(0.12, 0.12, 0.18), pal)
		local jaw = limb(model, head, "Jaw", V(0.72, 0.24, 0.8), CF(0, 1.06, -2.5), V(0, 1.15, -2.05), "Jaw", 1, H2)
		for _, x in { -1, 1 } do
			make(model, jaw, "Tooth", V(0.12, 0.12, 0.1), CF(x * 0.22, 1.22, -2.86), CLAW)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.78, spot[2] * 1.0
			leg(model, body, x, z, 1.1, 0.62, V(0.78, 0.3, 0.88), -spot[1] * spot[2], H, H2, 2)
		end
		tail(
			model,
			body,
			V(0, 1.7, 1.6),
			{ V(0.9, 0.7, 0.9), V(0.74, 0.56, 0.9), V(0.58, 0.44, 0.85), V(0.44, 0.34, 0.8) },
			{ 12, 6, 2, 0 },
			H,
			function(seg, frame, i, s)
				if i < 4 then
					plate(model, seg, "Spikes", V(s.X + 0.42, 0.14, 0.16), frame, pal)
				else
					glow(model, seg, "Tip", V(0.3, 0.3, 0.3), frame * CF(0, 0, s.Z / 2) * A(rad(45), rad(45), 0), pal)
				end
			end
		)
	end

	-- Sickleclaw: an olive stalker on two legs: a visor of light, a glowing
	-- saw down its belly, long arms ending in hooks.
	function B.Sickleclaw(model, pal, H, H2)
		local r = root(model, V(1.6, 1.6, 1.6), 2.0)
		local lean = CF(0, 2.7, 0.1) * A(rad(-12), 0, 0)
		local torso = limb(model, r, "Torso", V(1.45, 1.9, 1.15), lean, V(0, 1.8, 0.15), "Body", 1, H)
		glow(model, torso, "Saw", V(0.22, 1.45, 0.1), lean * CF(0, -0.05, -0.6), pal)
		for i = 0, 3 do
			plate(model, torso, "Tooth", V(0.5, 0.1, 0.14), lean * CF(0, 0.5 - i * 0.34, -0.62), pal)
		end
		for _, x in { -1, 1 } do
			wedge(model, torso, "Fin", V(0.16, 1.1, 0.8), lean * CF(x * 0.45, 0.75, 0.75), H2)
		end
		local head = make(model, torso, "Head", V(0.95, 0.95, 0.95), CF(0, 4.05, -0.3), H)
		glow(model, head, "Visor", V(0.8, 0.2, 0.08), CF(0, 4.12, -0.79), pal)
		make(model, head, "Brow", V(1.0, 0.18, 0.4), CF(0, 4.42, -0.62), H2)
		local jaw = limb(model, head, "Jaw", V(0.8, 0.26, 0.75), CF(0, 3.48, -0.42), V(0, 3.6, -0.05), "Jaw", 1, H2)
		make(model, jaw, "Mandible", V(0.7, 0.12, 0.12), CF(0, 3.56, -0.82), CLAW)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, torso, V(side * 0.92, 3.3, -0.1), V(0.32, 1.15, 0.32), 25, 18, side, H)
			local fore = hand * A(rad(55), 0, 0)
			make(model, p, "Forearm", V(0.28, 1.0, 0.28), fore * CF(0, -0.45, 0), H2)
			local tip = fore * CF(0, -0.95, 0)
			make(model, p, "Hook", V(0.12, 0.55, 0.12), tip * A(rad(-60), 0, 0) * CF(0, -0.2, 0), CLAW)
			make(model, p, "Hook", V(0.12, 0.4, 0.12), tip * A(rad(-20), 0, rad(side * 30)) * CF(0, -0.18, 0), CLAW)
			local l = leg(model, torso, side * 0.48, 0.25, 1.85, 0.5, V(0.6, 0.25, 0.95), side, H, H2, 3)
			make(model, l, "Thigh", V(0.62, 0.8, 0.75), CF(side * 0.5, 1.55, 0.25), H2)
		end
		tail(model, torso, V(0, 1.95, 0.6), { V(0.55, 0.45, 0.8), V(0.38, 0.3, 0.75) }, { 30, 15 }, H)
	end

	-- Moonmoth: a pale furry moth holding up four wings, spots of light on
	-- them, feathered feelers.
	function B.Moonmoth(model, pal, H, H2)
		local r = root(model, V(1.1, 1.1, 1.1), 1.5)
		local body = limb(model, r, "Body", V(0.85, 1.05, 0.85), CF(0, 1.62, 0), V(0, 1.4, 0.1), "Body", 1, H2)
		make(model, body, "Ruff", V(1.15, 0.45, 1.0), CF(0, 2.02, -0.08), H)
		local head = make(model, body, "Head", V(0.75, 0.6, 0.55), CF(0, 2.38, -0.4), H)
		eyes(model, head, 0.36, 2.42, -0.55, V(0.2, 0.28, 0.24), pal)
		local jaw = limb(model, head, "Jaw", V(0.38, 0.14, 0.3), CF(0, 2.08, -0.62), V(0, 2.13, -0.45), "Jaw", 1, H2)
		make(model, jaw, "Proboscis", V(0.08, 0.08, 0.3), CF(0, 2.05, -0.82), H2)
		for _, side in { -1, 1 } do
			local stalk = CF(side * 0.16, 2.66, -0.5) * A(rad(-25), 0, rad(-side * 22))
			plate(model, head, "Feeler", V(0.08, 0.75, 0.08), stalk * CF(0, 0.3, 0), pal)
			glow(model, head, "Plume", V(0.3, 0.42, 0.06), stalk * CF(0, 0.55, 0), pal)
			-- The wings stand up and out, swept back a little; they beat
			-- forward and back about the upright.
			local hinge = V(side * 0.38, 1.95, 0.15)
			local frame = CF(hinge) * A(0, rad(-side * 18), 0)
			local up = limb(model, body, "Wing", V(2.0, 1.75, 0.1), frame * CF(side * 1.0, 0.55, 0), hinge, "Wing", side, H)
			reseat(up, CF(hinge) * A(rad(90), 0, 0))
			make(model, up, "Edge", V(2.0, 0.22, 0.13), frame * CF(side * 1.0, 1.38, 0), H2)
			plate(model, up, "Border", V(0.2, 1.75, 0.13), frame * CF(side * 1.98, 0.55, 0), pal)
			glow(model, up, "Spot", V(0.55, 0.55, 0.14), frame * CF(side * 1.25, 0.72, 0), pal)
			glow(model, up, "Spot", V(0.25, 0.25, 0.14), frame * CF(side * 0.55, 0.12, 0), pal)
			local hinge2 = V(side * 0.36, 1.45, 0.2)
			local frame2 = CF(hinge2) * A(0, rad(-side * 26), 0)
			local low = limb(model, body, "Wing", V(1.35, 1.15, 0.1), frame2 * CF(side * 0.68, -0.45, 0), hinge2, "Wing", side, H)
			reseat(low, CF(hinge2) * A(rad(90), 0, 0))
			plate(model, low, "Border", V(0.18, 1.15, 0.13), frame2 * CF(side * 1.3, -0.45, 0), pal)
			glow(model, low, "Spot", V(0.38, 0.38, 0.14), frame2 * CF(side * 0.75, -0.5, 0), pal)
			leg(model, body, side * 0.22, -0.15, 1.15, 0.1, V(0.18, 0.08, 0.22), side, H2, H2)
		end
		tail(
			model,
			body,
			V(0, 1.35, 0.35),
			{ V(0.72, 0.68, 0.7), V(0.58, 0.55, 0.6), V(0.4, 0.38, 0.5) },
			{ 58, 50, 42 },
			H2,
			function(seg, frame, _, s)
				make(model, seg, "Fur", V(s.X + 0.06, s.Y * 0.4, s.Z * 0.35), frame * CF(0, 0, -s.Z * 0.2), H)
			end
		)
	end

	-- Shellfire: a tusked turtle under a stepped shell, light in its seams,
	-- a jet in each leg.
	function B.Shellfire(model, pal, H, H2)
		local r = root(model, V(2.2, 1, 2.4), 1.2)
		local body = limb(model, r, "Belly", V(2.4, 0.6, 2.9), CF(0, 1.0, 0), V(0, 0.9, 0), "Body", 1, H)
		make(model, body, "Shell", V(3.0, 0.55, 3.4), CF(0, 1.55, 0.05), H2)
		make(model, body, "Shell", V(2.6, 0.45, 3.0), CF(0, 2.05, 0.05), H2)
		make(model, body, "Shell", V(1.95, 0.4, 2.3), CF(0, 2.45, 0.05), H2)
		make(model, body, "Shell", V(1.1, 0.3, 1.3), CF(0, 2.75, 0.05), H)
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				plate(model, body, "Tile", V(0.82, 0.12, 0.98), CF(x * 0.5, 2.67, 0.05 + z * 0.58), pal)
			end
			glow(model, body, "Seam", V(0.08, 0.1, 3.05), CF(x * 0.75, 2.3, 0.05), pal)
			glow(model, body, "Seam", V(0.08, 0.1, 3.42), CF(x * 1.48, 1.84, 0.05), pal)
		end
		glow(model, body, "Seam", V(2.65, 0.1, 0.08), CF(0, 2.3, -0.7), pal)
		glow(model, body, "Seam", V(2.65, 0.1, 0.08), CF(0, 2.3, 0.8), pal)
		local head = make(model, body, "Head", V(1.0, 0.85, 1.0), CF(0, 1.4, -2.0), H)
		make(model, head, "Snout", V(0.8, 0.5, 0.5), CF(0, 1.3, -2.7), H)
		eyes(model, head, 0.4, 1.6, -2.42, V(0.14, 0.12, 0.16), pal)
		local jaw = limb(model, head, "Jaw", V(0.8, 0.25, 0.85), CF(0, 0.92, -2.35), V(0, 1.02, -1.9), "Jaw", 1, H2)
		for _, x in { -1, 1 } do
			make(model, jaw, "Tusk", V(0.14, 0.45, 0.14), CF(x * 0.33, 1.25, -2.72) * A(rad(-20), 0, 0), CLAW)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 1.1, spot[2] * 1.05
			local l = leg(model, body, x, z, 0.95, 0.72, V(0.82, 0.25, 0.86), -spot[1] * spot[2], H, H2, 2)
			glow(model, l, "Jet", V(0.1, 0.32, 0.32), CF(x + spot[1] * 0.37, 0.55, z), pal)
		end
		tail(model, body, V(0, 1.0, 1.45), { V(0.45, 0.35, 0.5), V(0.28, 0.24, 0.4) }, { 18, 10 }, H)
	end

	-- Mossback: a walking stump grown over with moss, a flower for a mouth,
	-- long vine arms with glowing claws.
	function B.Mossback(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.2)
		local stand = CF(0, 3.0, 0.1) * A(rad(-6), 0, 0)
		local trunk = limb(model, r, "Trunk", V(1.7, 2.6, 1.4), stand, V(0, 1.75, 0.1), "Body", 1, H)
		for _, x in { -0.5, 0.15, 0.62 } do
			make(model, trunk, "Bark", V(0.22, 2.3, 0.14), stand * CF(x, -0.1, -0.72), H)
		end
		make(model, trunk, "Moss", V(1.85, 0.4, 1.55), stand * CF(0, 1.35, 0), H2)
		make(model, trunk, "Moss", V(0.7, 0.5, 0.2), stand * CF(-0.45, 0.85, 0.75), H2)
		make(model, trunk, "Moss", V(0.5, 0.35, 0.2), stand * CF(0.55, -0.4, -0.76), H2)
		local rose = stand * CF(0, 0.45, -0.78)
		for i = 0, 3 do
			plate(model, trunk, "Petal", V(0.42, 0.42, 0.18), rose * A(0, 0, rad(i * 90 + 45)) * CF(0, 0.3, 0), pal)
		end
		glow(model, trunk, "Bloom", V(0.32, 0.32, 0.14), rose * CF(0, 0, -0.05), pal)
		eyes(model, trunk, 0.4, 3.95, -0.78, V(0.16, 0.1, 0.06), pal)
		limb(model, trunk, "Jaw", V(0.7, 0.24, 0.3), CF(0, 2.85, -0.8), V(0, 2.97, -0.68), "Jaw", 1, H)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, trunk, V(side * 1.02, 3.95, -0.05), V(0.42, 1.5, 0.42), 14, 24, side, H)
			make(model, p, "Vine", V(0.2, 1.3, 0.48), CF(side * 1.38, 3.25, -0.05) * A(rad(14), 0, rad(side * 24)), H2)
			local fore = hand * A(rad(16), 0, rad(-side * 18))
			make(model, p, "Forearm", V(0.34, 1.2, 0.34), fore * CF(0, -0.55, 0), H)
			plate(model, p, "Thorn", V(0.14, 0.24, 0.24), fore * CF(side * 0.2, -0.4, 0) * A(rad(45), 0, 0), pal)
			local tip = fore * CF(0, -1.15, 0)
			for i = -1, 1 do
				glow(model, p, "Claw", V(0.1, 0.42, 0.1), tip * A(rad(-15), 0, rad(i * 25)) * CF(0, -0.18, 0), pal)
			end
			local l = leg(model, trunk, side * 0.5, 0.15, 1.8, 0.72, V(0.95, 0.35, 1.1), side, H, H)
			make(model, l, "Root", V(0.2, 0.18, 0.6), CF(side * 0.82, 0.09, -0.1) * A(0, rad(side * 35), 0), H)
			make(model, l, "Moss", V(0.5, 0.3, 0.2), CF(side * 0.5, 1.2, -0.28), H2)
		end
		tail(model, trunk, V(0, 2.0, 0.75), { V(0.36, 0.3, 0.8), V(0.26, 0.22, 0.7) }, { 40, 25 }, H2)
	end

	-- Bastion: a stone lion sitting up on guard, a mane of eight fins tipped
	-- with light, a tail curled up behind.
	function B.Bastion(model, pal, H, H2)
		local r = root(model, V(1.8, 1.6, 2.0), 1.9)
		local sit = CF(0, 2.05, 0.15) * A(rad(-18), 0, 0)
		local body = limb(model, r, "Body", V(1.6, 2.0, 1.5), sit, V(0, 1.15, 0.55), "Body", 1, H)
		make(model, body, "Haunch", V(1.9, 1.0, 1.5), CF(0, 0.95, 0.75), H)
		make(model, body, "Chest", V(1.2, 1.1, 0.2), sit * CF(0, 0.15, -0.78), H2)
		for _, side in { -1, 1 } do
			local paw = make(model, body, "HindPaw", V(0.55, 0.3, 0.85), CF(side * 0.72, 0.15, 0.2), H2)
			claws(model, paw, side * 0.72, 0.1, -0.28, 2, 0.22, V(0.12, 0.14, 0.2))
			make(model, body, "Ear", V(0.25, 0.32, 0.2), CF(side * 0.45, 4.25, -0.8), H)
		end
		local head = make(model, body, "Head", V(1.25, 1.15, 1.05), CF(0, 3.6, -0.78), H)
		make(model, head, "Muzzle", V(0.75, 0.5, 0.45), CF(0, 3.25, -1.4), H2)
		make(model, head, "Nose", V(0.3, 0.18, 0.12), CF(0, 3.46, -1.64), H2)
		eyes(model, head, 0.32, 3.8, -1.32, V(0.3, 0.14, 0.08), pal)
		limb(model, head, "Jaw", V(0.62, 0.2, 0.42), CF(0, 2.95, -1.22), V(0, 3.05, -0.98), "Jaw", 1, H2)
		local mane = CF(0, 3.6, -0.32)
		for i = 0, 7 do
			local spoke = mane * A(0, 0, rad(i * 45 + 22.5))
			plate(model, head, "Mane", V(0.5, 0.95, 0.22), spoke * CF(0, 0.95, 0), pal)
			glow(model, head, "ManeTip", V(0.52, 0.2, 0.24), spoke * CF(0, 1.38, 0), pal)
		end
		for _, side in { -1, 1 } do
			leg(model, body, side * 0.5, -0.55, 1.75, 0.5, V(0.62, 0.3, 0.75), side, H, H2, 3)
		end
		local sizes = { V(0.34, 0.34, 0.55), V(0.3, 0.3, 0.5), V(0.27, 0.27, 0.45), V(0.24, 0.24, 0.42), V(0.2, 0.2, 0.4) }
		tail(model, body, V(0, 0.6, 1.45), sizes, { -15, -55, -100, -150, -200 }, H, function(seg, frame, i, s)
			if i == #sizes then
				plate(model, seg, "Tuft", V(0.34, 0.34, 0.34), frame * CF(0, 0, s.Z / 2), pal)
			end
		end)
	end

	-- Hulkshell: a hunched ape under a shell, the shell split with cracks of
	-- light, knuckles on the ground.
	function B.Hulkshell(model, pal, H, H2)
		local r = root(model, V(2, 2, 2), 2.2)
		local hunch = CF(0, 2.75, -0.1) * A(rad(-32), 0, 0)
		local torso = limb(model, r, "Torso", V(2.2, 1.9, 1.7), hunch, V(0, 1.85, 0.35), "Body", 1, H)
		local shell = make(model, torso, "Shell", V(2.5, 1.0, 2.0), hunch * CF(0, 0.6, 0.3), H2)
		make(model, shell, "Shell", V(1.9, 0.5, 1.6), hunch * CF(0, 1.3, 0.35), H2)
		for i, crack in { { -0.45, 0.2, 25 }, { 0.35, 0.5, -30 }, { 0.05, -0.25, 70 } } do
			glow(model, shell, "Crack", V(0.08, 0.08, 0.9), hunch * CF(crack[1], 1.56, 0.35 + crack[2]) * A(0, rad(crack[3]), 0), pal)
			glow(model, shell, "Crack", V(0.08, 0.6, 0.08), hunch * CF((i - 2) * 1.0 + 0.05, 0.75, -0.72), pal)
		end
		for _, side in { -1, 1 } do
			glow(model, shell, "Crack", V(0.08, 0.08, 1.3), hunch * CF(side * 1.26, 0.65, 0.3) * A(rad(side * 20), 0, 0), pal)
		end
		local head = make(model, torso, "Head", V(0.95, 0.9, 0.9), CF(0, 3.0, -1.5), H)
		plate(model, head, "Brow", V(1.05, 0.25, 0.42), CF(0, 3.38, -1.82), pal)
		eyes(model, head, 0.24, 3.15, -1.96, V(0.2, 0.1, 0.06), pal)
		make(model, head, "Muzzle", V(0.7, 0.4, 0.3), CF(0, 2.82, -1.98), H2)
		limb(model, head, "Jaw", V(0.75, 0.28, 0.6), CF(0, 2.5, -1.65), V(0, 2.62, -1.3), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, torso, "Shoulder", V(0.9, 0.5, 1.0), CF(side * 1.3, 3.6, -0.7) * A(0, 0, rad(-side * 12)), pal)
			local p, hand = arm(model, torso, V(side * 1.3, 3.35, -0.75), V(0.85, 1.6, 0.9), 8, 6, side, H)
			make(model, p, "Forearm", V(0.95, 1.2, 1.0), hand * CF(0, -0.6, 0), H)
			make(model, p, "Fist", V(1.05, 0.55, 1.05), hand * CF(0, -1.45, 0), H2)
			plate(model, p, "Knuckles", V(1.0, 0.3, 0.3), hand * CF(0, -1.4, -0.5), pal)
			leg(model, torso, side * 0.65, 0.55, 1.75, 0.75, V(0.9, 0.35, 1.1), side, H, H2, 2)
		end
	end

	-- Dreadmaw: a bone-white runner that is mostly jaw, its throat aglow.
	function B.Dreadmaw(model, pal, H, H2)
		local r = root(model, V(1.6, 1.4, 2.2), 1.95)
		local back = CF(0, 2.05, 0.35) * A(rad(-6), 0, 0)
		local body = limb(model, r, "Body", V(1.45, 1.35, 2.5), back, V(0, 1.95, 0.4), "Body", 1, H)
		for i = 0, 3 do
			plate(model, body, "Ridge", V(0.32, 0.32, 0.32), back * CF(0, 0.72, -0.8 + i * 0.55) * A(rad(45), 0, 0), pal)
		end
		local skull = make(model, body, "Skull", V(1.55, 0.85, 1.9), CF(0, 3.0, -1.75), H)
		make(model, skull, "Brow", V(1.6, 0.25, 0.8), CF(0, 3.48, -1.3), H2)
		eyes(model, skull, 0.72, 3.25, -1.45, V(0.12, 0.14, 0.22), pal)
		glow(model, skull, "Throat", V(1.15, 0.55, 1.45), CF(0, 2.4, -1.55), pal)
		for _, x in { -0.6, -0.25, 0.25, 0.6 } do
			make(model, skull, "Fang", V(0.16, 0.28, 0.16), CF(x, 2.45, if math.abs(x) < 0.4 then -2.62 else -2.2), CLAW)
		end
		local jaw = limb(model, skull, "Jaw", V(1.5, 0.5, 1.85), CF(0, 1.92, -1.75), V(0, 2.15, -0.85), "Jaw", 1, H)
		for _, x in { -0.6, 0.6 } do
			for _, z in { -2.45, -1.75 } do
				make(model, jaw, "Fang", V(0.16, 0.26, 0.16), CF(x, 2.28, z), CLAW)
			end
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.55, if spot[2] < 0 then -0.4 else 1.15
			local l = leg(model, body, x, z, 1.65, 0.45, V(0.55, 0.25, 0.7), -spot[1] * spot[2], H, H2, 2)
			make(model, l, "Thigh", V(0.55, 0.6, 0.7), CF(x * 1.05, 1.55, z), H2)
		end
		local sizes = { V(0.55, 0.5, 0.8), V(0.4, 0.36, 0.8), V(0.28, 0.25, 0.75), V(0.18, 0.16, 0.7), V(0.12, 0.12, 0.6) }
		tail(model, body, V(0, 2.25, 1.55), sizes, { -10, 0, 8, 0, -35 }, H, function(seg, frame, i, s)
			if i == #sizes then
				plate(model, seg, "Barb", V(0.1, 0.3, 0.3), frame * CF(0, 0, s.Z / 2) * A(rad(45), 0, 0), pal)
			end
		end)
	end

	-- Hornblade: a crouched red digger, ridged down its back, its front
	-- claws glowing.
	function B.Hornblade(model, pal, H, H2)
		local r = root(model, V(1.8, 1.2, 2.2), 1.6)
		local crouch = CF(0, 1.9, 0.25) * A(rad(-14), 0, 0)
		local body = limb(model, r, "Body", V(1.8, 1.3, 2.4), crouch, V(0, 1.6, 0.6), "Body", 1, H)
		for i = 0, 3 do
			plate(model, body, "Ridge", V(1.0 - i * 0.12, 0.34, 0.36), crouch * CF(0, 0.8, -0.75 + i * 0.55), pal)
		end
		local head = make(model, body, "Head", V(1.05, 0.85, 1.0), CF(0, 2.3, -1.35), H)
		make(model, head, "Snout", V(0.7, 0.5, 0.6), CF(0, 2.08, -2.0), H2)
		wedge(model, head, "Horn", V(0.2, 0.45, 0.4), CF(0, 2.53, -2.05) * A(0, math.pi, 0), pal.Plate)
		eyes(model, head, 0.53, 2.42, -1.6, V(0.08, 0.12, 0.16), pal)
		for _, side in { -1, 1 } do
			make(model, head, "Ear", V(0.22, 0.35, 0.18), CF(side * 0.42, 2.85, -1.1), H2)
		end
		limb(model, head, "Jaw", V(0.65, 0.22, 0.65), CF(0, 1.74, -1.95), V(0, 1.82, -1.6), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, body, V(side * 0.85, 2.1, -0.95), V(0.6, 1.35, 0.6), 22, 12, side, H)
			make(model, p, "Paw", V(0.72, 0.3, 0.72), hand * CF(0, -0.1, -0.05), H2)
			for i = -1, 1 do
				glow(model, p, "Claw", V(0.14, 0.5, 0.14), hand * CF(i * 0.22, -0.2, -0.4) * A(rad(-55), 0, 0), pal)
			end
			local l = leg(model, body, side * 0.72, 0.95, 1.4, 0.6, V(0.72, 0.3, 0.95), side, H, H2, 3)
			make(model, l, "Thigh", V(0.75, 0.75, 0.9), CF(side * 0.74, 1.25, 0.95), H)
		end
		tail(model, body, V(0, 1.75, 1.45), { V(0.6, 0.5, 0.7), V(0.45, 0.38, 0.65), V(0.3, 0.26, 0.55) }, { 20, 12, 5 }, H)
	end

	-- Titanfin: a steel-blue biped on a long neck, a hook of light on its
	-- head and a fan of glowing fins for a tail.
	function B.Titanfin(model, pal, H, H2)
		local r = root(model, V(1.6, 1.6, 1.8), 2.0)
		local lean = CF(0, 2.35, 0.2) * A(rad(-12), 0, 0)
		local body = limb(model, r, "Body", V(1.35, 1.5, 1.7), lean, V(0, 1.75, 0.3), "Body", 1, H)
		make(model, body, "Belly", V(0.95, 1.1, 0.15), lean * CF(0, -0.1, -0.86), H2)
		local neck = strut(model, body, "Neck", V(0, 2.85, -0.4), V(0, 4.25, -0.75), 0.48, H)
		local head = make(model, neck, "Head", V(0.6, 0.5, 1.0), CF(0, 4.45, -1.0), H)
		glow(model, head, "Hook", V(0.14, 0.14, 0.95), CF(0, 4.76, -0.95), pal)
		glow(model, head, "Hook", V(0.14, 0.42, 0.14), CF(0, 4.62, -1.48), pal)
		plate(model, head, "Crest", V(0.2, 0.5, 0.3), CF(0, 4.85, -0.5) * A(rad(25), 0, 0), pal)
		eyes(model, head, 0.31, 4.52, -1.2, V(0.06, 0.1, 0.16), pal)
		limb(model, head, "Jaw", V(0.5, 0.16, 0.85), CF(0, 4.14, -1.15), V(0, 4.22, -0.7), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, body, V(side * 0.72, 2.85, -0.4), V(0.32, 0.95, 0.32), 35, 25, side, H)
			plate(model, p, "Fin", V(0.08, 0.7, 0.45), hand * CF(0, 0.38, 0.2), pal)
			for i = -1, 1, 2 do
				glow(model, p, "Claw", V(0.08, 0.32, 0.08), hand * A(0, 0, rad(i * 18)) * CF(0, -0.14, 0), pal)
			end
			local l = leg(model, body, side * 0.45, 0.35, 1.8, 0.5, V(0.6, 0.3, 0.9), side, H, H2, 3)
			make(model, l, "Thigh", V(0.62, 0.7, 0.8), CF(side * 0.48, 1.5, 0.35), H2)
		end
		tail(model, body, V(0, 1.9, 1.0), { V(0.6, 0.5, 0.7), V(0.45, 0.4, 0.6) }, { 25, 10 }, H, function(seg, frame, i)
			if i == 1 then
				local fan = CF((frame * CF(0, 0.1, 0.3)).Position) * A(rad(20), 0, 0)
				for k = -2, 2 do
					local spoke = fan * A(0, 0, rad(k * 28))
					plate(model, seg, "Fan", V(0.42, 1.5, 0.12), spoke * CF(0, 0.8, 0), pal)
					glow(model, seg, "FanTip", V(0.44, 0.25, 0.14), spoke * CF(0, 1.5, 0), pal)
				end
			end
		end)
	end

	-- Drillhorn: a brown beetle on two legs, a glowing horn, drills for
	-- hands and cases over its back.
	function B.Drillhorn(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.0)
		local lean = CF(0, 2.6, 0.1) * A(rad(-14), 0, 0)
		local torso = limb(model, r, "Torso", V(1.6, 1.75, 1.35), lean, V(0, 1.75, 0.2), "Body", 1, H)
		make(model, torso, "Chest", V(1.1, 1.0, 0.15), lean * CF(0, 0.15, -0.72), H2)
		for _, side in { -1, 1 } do
			local case = lean * CF(side * 0.42, 0.15, 0.82) * A(rad(10), 0, 0)
			plate(model, torso, "Case", V(0.78, 1.7, 0.3), case, pal)
			glow(model, torso, "Vein", V(0.08, 1.4, 0.06), case * CF(0, 0, 0.17), pal)
		end
		local head = make(model, torso, "Head", V(0.95, 0.8, 0.9), CF(0, 3.65, -0.45), H)
		eyes(model, head, 0.48, 3.72, -0.7, V(0.06, 0.14, 0.2), pal)
		plate(model, head, "Horn", V(0.36, 0.55, 0.36), CF(0, 4.2, -0.75) * A(rad(-20), 0, 0), pal)
		glow(model, head, "Horn", V(0.28, 0.6, 0.28), CF(0, 4.7, -0.92) * A(rad(-5), 0, 0), pal)
		glow(model, head, "HornTip", V(0.16, 0.35, 0.16), CF(0, 5.1, -0.85) * A(rad(15), 0, 0), pal)
		local jaw = limb(model, head, "Jaw", V(0.75, 0.2, 0.5), CF(0, 3.2, -0.8), V(0, 3.3, -0.5), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			make(model, jaw, "Pincer", V(0.12, 0.14, 0.35), CF(side * 0.28, 3.2, -1.15) * A(0, rad(side * 20), 0), CLAW)
			local p, hand = arm(model, torso, V(side * 0.95, 3.15, -0.25), V(0.5, 0.85, 0.5), 55, 12, side, H)
			for i, w in { 0.6, 0.48, 0.36, 0.22 } do
				make(model, p, "Drill", V(w, 0.32, w), hand * CF(0, -0.05 - (i - 1) * 0.3, 0) * A(0, rad(i * 22), 0), H2)
			end
			glow(model, p, "Spiral", V(0.58, 0.08, 0.58), hand * CF(0, -0.2, 0) * A(0, rad(45), 0), pal)
			glow(model, p, "Spiral", V(0.44, 0.08, 0.44), hand * CF(0, -0.5, 0) * A(0, rad(45), 0), pal)
			glow(model, p, "Point", V(0.12, 0.28, 0.12), hand * CF(0, -1.12, 0), pal)
			local l = leg(model, torso, side * 0.55, 0.25, 1.75, 0.55, V(0.65, 0.3, 0.9), side, H, H2, 2)
			plate(model, l, "Knee", V(0.6, 0.32, 0.25), CF(side * 0.55, 1.0, -0.05), pal)
		end
		tail(model, torso, V(0, 1.9, 0.75), { V(0.8, 0.55, 0.7), V(0.55, 0.4, 0.6) }, { 35, 25 }, H)
	end

	-- Grandape: a great brown ape, a grey chest with a core of light in it.
	function B.Grandape(model, pal, H, H2)
		local r = root(model, V(2, 2, 2), 2.3)
		local lean = CF(0, 3.0, 0.05) * A(rad(-14), 0, 0)
		local torso = limb(model, r, "Torso", V(2.2, 2.2, 1.6), lean, V(0, 1.9, 0.25), "Body", 1, H)
		make(model, torso, "Chest", V(1.5, 1.35, 0.2), lean * CF(0, 0.1, -0.82), H2)
		glow(model, torso, "Core", V(0.42, 0.3, 0.1), lean * CF(0, 0.15, -0.94), pal)
		local head = make(model, torso, "Head", V(1.0, 1.0, 0.95), CF(0, 4.5, -0.55), H)
		make(model, head, "Face", V(0.75, 0.6, 0.15), CF(0, 4.38, -1.05), H2)
		make(model, head, "Brow", V(1.05, 0.25, 0.35), CF(0, 4.78, -0.95), H)
		eyes(model, head, 0.2, 4.55, -1.13, V(0.2, 0.1, 0.06), pal)
		limb(model, head, "Jaw", V(0.7, 0.3, 0.5), CF(0, 3.98, -0.95), V(0, 4.12, -0.6), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, torso, "Shoulder", V(0.85, 0.55, 1.0), CF(side * 1.25, 3.98, -0.15), pal)
			local p, hand = arm(model, torso, V(side * 1.35, 3.75, -0.25), V(0.8, 1.5, 0.85), 10, 10, side, H)
			make(model, p, "Forearm", V(0.85, 1.3, 0.9), hand * CF(0, -0.6, 0), H)
			make(model, p, "Fist", V(0.95, 0.6, 0.95), hand * CF(0, -1.5, 0), H2)
			plate(model, p, "Knuckles", V(0.95, 0.25, 0.3), hand * CF(0, -1.52, -0.45), pal)
			leg(model, torso, side * 0.6, 0.3, 1.95, 0.75, V(0.9, 0.35, 1.1), side, H, H2, 2)
		end
	end

	-- Thornlob: a squat purple spider, a cluster of glowing eyes, fangs of
	-- light, eight legs.
	function B.Thornlob(model, pal, H, H2)
		local r = root(model, V(1.8, 1.2, 1.8), 1.6)
		local body = limb(model, r, "Body", V(1.9, 1.5, 1.8), CF(0, 1.95, -0.1), V(0, 1.6, 0), "Body", 1, H)
		make(model, body, "Crown", V(1.55, 0.35, 1.45), CF(0, 2.86, -0.05), H)
		for _, spot in { { -0.45, 2.3, 0.2 }, { 0, 2.38, 0.26 }, { 0.45, 2.3, 0.2 }, { -0.25, 2.0, 0.24 }, { 0.25, 2.0, 0.24 }, { -0.55, 1.75, 0.16 }, { 0.55, 1.75, 0.16 }, { 0, 1.72, 0.18 } } do
			glow(model, body, "Eye", V(spot[3], spot[3], 0.08), CF(spot[1], spot[2], -1.02), pal)
		end
		local jaw = limb(model, body, "Jaw", V(0.8, 0.3, 0.3), CF(0, 1.32, -0.95), V(0, 1.45, -0.85), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			glow(model, jaw, "Fang", V(0.12, 0.35, 0.12), CF(side * 0.25, 1.08, -1.05), pal)
		end
		tail(model, body, V(0, 2.0, 0.75), { V(1.5, 1.2, 1.3) }, { 12 }, H2, function(seg, frame)
			for _, z in { -0.25, 0.25 } do
				plate(model, seg, "Band", V(1.54, 0.14, 0.22), frame * CF(0, 0.55, z), pal)
			end
		end)
		for i, z in { -0.75, -0.3, 0.15, 0.6 } do
			for _, side in { -1, 1 } do
				local hip = V(side * 0.9, 1.7, z)
				local knee = V(side * 1.85, 2.2, z * 1.45)
				local foot = V(side * 2.45, 0.05, z * 2.0)
				local thigh = strut(model, body, "Leg", hip, knee, 0.24, H, "Stride", side * (if i % 2 == 1 then 1 else -1))
				strut(model, thigh, "Shin", knee, foot, 0.2, H)
				plate(model, thigh, "Knee", V(0.3, 0.3, 0.3), CF(knee), pal)
			end
		end
	end

	-- Starspine: an indigo upright brute, two great shards of crystal
	-- growing from its shoulders.
	function B.Starspine(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.2)
		local lean = CF(0, 2.75, 0.15) * A(rad(-8), 0, 0)
		local torso = limb(model, r, "Torso", V(1.7, 2.2, 1.4), lean, V(0, 1.7, 0.2), "Body", 1, H)
		make(model, torso, "Belly", V(1.1, 1.5, 0.18), lean * CF(0, -0.1, -0.72), H2)
		-- Solid faceted crystals with a narrow luminous vein; the surface stays readable.
		local function crystal(attach, frame, width, height)
			local color = pal.Plate:Lerp(pal.Glow, 0.6)
			make(model, attach, "CrystalPrism", V(width, height * 0.7, width), frame * CF(0, height * 0.35, 0), color, Enum.Material.Glass)
			for _, side in { -1, 1 } do
				wedge(model, attach, "CrystalFacet", V(width, height * 0.3, width / 2), frame * CF(0, height * 0.85, side * width / 4) * A(0, if side == 1 then math.pi else 0, 0), color:Lerp(pal.Glow, if side == 1 then 0.35 else 0.1))
			end
			glow(model, attach, "CrystalVein", V(width * 0.12, height * 0.62, 0.025), frame * CF(0, height * 0.36, -width / 2 - 0.015), pal)
		end
		for _, side in { -1, 1 } do
			local shard = CF(side * 0.82, 3.8, 0.5) * A(rad(12), rad(25), rad(-side * 28))
			make(model, torso, "CrystalRoot", V(0.82, 0.5, 0.85), shard * CF(0, 0.05, 0), H2)
			crystal(torso, shard, 0.62, 2.15)
			wedge(model, torso, "ShoulderRidge", V(0.38, 0.65, 0.8), CF(side * 1.0, 3.55, -0.12) * A(0, 0, rad(-side * 25)), H)
			wedge(model, torso, "ShoulderScale", V(0.32, 0.45, 0.65), CF(side * 1.25, 3.35, -0.1) * A(0, 0, rad(-side * 35)), H2)
		end
		for i = 0, 2 do
			make(model, torso, "BellyScale", V(1.18 - i * 0.1, 0.36, 0.12), lean * CF(0, 0.4 - i * 0.45, -0.84), H2:Lerp(H, i * 0.12))
		end
		for i = 0, 2 do
			glow(model, torso, "Shard", V(0.16, 0.34, 0.34), lean * CF(0, 0.2 - i * 0.5, 0.75) * A(rad(45), 0, 0), pal)
		end
		local head = make(model, torso, "Head", V(1.0, 0.85, 1.05), CF(0, 4.05, -0.45), H)
		make(model, head, "Snout", V(0.8, 0.5, 0.6), CF(0, 3.95, -1.1), H)
		crystal(head, CF(0, 4.45, -0.35) * A(0, rad(45), 0), 0.3, 0.65)
		for _, side in { -1, 1 } do
			make(model, head, "Brow", V(0.42, 0.13, 0.2), CF(side * 0.29, 4.3, -0.97) * A(0, 0, rad(side * 14)), H2)
			make(model, head, "Nostril", V(0.09, 0.08, 0.025), CF(side * 0.23, 4.02, -1.41), H:Lerp(C(12, 15, 25), 0.7))
		end
		eyes(model, head, 0.3, 4.2, -0.99, V(0.18, 0.1, 0.08), pal)
		limb(model, head, "Jaw", V(0.75, 0.25, 0.85), CF(0, 3.57, -0.9), V(0, 3.7, -0.5), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, torso, V(side * 0.98, 3.35, -0.35), V(0.42, 0.95, 0.45), 30, 10, side, H)
			make(model, p, "Palm", V(0.44, 0.28, 0.42), hand * CF(0, -0.02, -0.08), H2)
			claws(model, p, hand.Position.X, hand.Position.Y - 0.05, hand.Position.Z - 0.1, 3, 0.13, V(0.1, 0.2, 0.14))
			local l = leg(model, torso, side * 0.55, 0.3, 1.7, 0.7, V(0.85, 0.35, 1.15), side, H, H2, 3)
			make(model, l, "KneeScale", V(0.64, 0.32, 0.16), CF(side * 0.55, 0.9, -0.09), H2)
			make(model, l, "Thigh", V(0.85, 0.8, 0.95), CF(side * 0.58, 1.45, 0.3), H)
		end
		local sizes = { V(0.85, 0.75, 1.0), V(0.7, 0.6, 1.0), V(0.55, 0.45, 0.95), V(0.4, 0.32, 0.9), V(0.26, 0.22, 0.8) }
		tail(model, torso, V(0, 1.9, 0.85), sizes, { 30, 18, 6, -4, -10 }, H, function(seg, frame, i, s)
			if i <= 4 then
				wedge(model, seg, "TailRidge", V(s.X * 0.7, 0.4 - i * 0.045, s.Z * 0.65), frame * CF(0, s.Y / 2 + 0.1, 0), pal.Plate)
			end
		end)
	end

	-- Nulltalon: a black armoured stalker, a slit of light in its helm and
	-- long talons of light.
	function B.Nulltalon(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.1)
		local lean = CF(0, 2.7, 0.1) * A(rad(-18), 0, 0)
		local torso = limb(model, r, "Torso", V(1.6, 1.8, 1.3), lean, V(0, 1.8, 0.25), "Body", 1, H)
		plate(model, torso, "Chest", V(1.1, 0.8, 0.15), lean * CF(0, 0.3, -0.7), pal)
		local helm = make(model, torso, "Helm", V(0.95, 0.95, 1.0), CF(0, 3.95, -0.55), H)
		glow(model, helm, "Visor", V(0.8, 0.14, 0.08), CF(0, 4.0, -1.06), pal)
		make(model, helm, "Crest", V(0.2, 0.3, 0.9), CF(0, 4.55, -0.5), H2)
		limb(model, helm, "Jaw", V(0.8, 0.25, 0.7), CF(0, 3.35, -0.7), V(0, 3.45, -0.35), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, torso, "Pauldron", V(0.8, 0.45, 0.9), CF(side * 1.0, 3.55, -0.15) * A(0, 0, rad(-side * 18)), pal)
			local p, hand = arm(model, torso, V(side * 1.0, 3.25, -0.3), V(0.45, 1.0, 0.45), 35, 15, side, H)
			local fore = hand * A(rad(30), 0, 0)
			make(model, p, "Forearm", V(0.42, 0.8, 0.42), fore * CF(0, -0.35, 0), H2)
			local tip = fore * CF(0, -0.75, 0)
			for i = -1, 1 do
				glow(model, p, "Talon", V(0.09, 0.8, 0.09), tip * A(rad(-35), 0, rad(i * 16)) * CF(0, -0.38, 0), pal)
			end
			local l = leg(model, torso, side * 0.55, 0.3, 1.8, 0.55, V(0.65, 0.3, 0.95), side, H, H2, 3)
			plate(model, l, "Knee", V(0.6, 0.35, 0.25), CF(side * 0.55, 1.05, 0.0), pal)
		end
		tail(
			model,
			torso,
			V(0, 1.95, 0.75),
			{ V(0.6, 0.55, 0.8), V(0.48, 0.42, 0.8), V(0.36, 0.3, 0.75), V(0.24, 0.2, 0.7) },
			{ 25, 12, 0, -10 },
			H,
			function(seg, frame, i, s)
				if i < 4 then
					make(model, seg, "Fin", V(0.12, 0.3, s.Z * 0.6), frame * CF(0, s.Y / 2 + 0.12, 0), H2)
				end
			end
		)
	end

	-- Sporeback: a heaped mound of fungus on stubby feet, two square eyes
	-- of light and cracks glowing all over it.
	function B.Sporeback(model, pal, H, H2)
		local r = root(model, V(2.0, 1.4, 2.0), 1.4)
		local body = limb(model, r, "Body", V(2.6, 1.6, 2.4), CF(0, 1.3, 0.1), V(0, 0.9, 0.1), "Body", 1, H)
		make(model, body, "Mound", V(2.2, 1.0, 2.0), CF(0, 2.4, 0.15), H)
		make(model, body, "Mound", V(1.5, 0.7, 1.4), CF(0, 3.1, 0.25), H)
		for _, lump in { { -1.2, 1.0, -0.5 }, { 1.2, 1.05, -0.3 }, { -1.0, 2.0, 0.6 }, { 1.05, 1.9, 0.75 }, { 0.2, 1.0, 1.25 } } do
			make(model, body, "Lump", V(0.75, 0.6, 0.7), CF(lump[1], lump[2], lump[3]), H2)
		end
		for _, side in { -1, 1 } do
			local socket = make(model, body, "Socket", V(0.62, 0.55, 0.3), CF(side * 0.42, 3.0, -0.5), H2)
			glow(model, socket, "Eye", V(0.48, 0.4, 0.12), CF(side * 0.42, 3.0, -0.66), pal)
		end
		for _, crack in { { -0.7, 1.6, -1.1, 20 }, { 0.6, 1.3, -1.1, -25 }, { 0.15, 2.3, -0.86, 10 }, { -1.31, 1.4, 0.3, 0 }, { 1.31, 1.6, -0.2, 0 }, { -0.5, 2.6, -0.62, -30 } } do
			local face = if math.abs(crack[1]) > 1.25 then A(0, rad(90), rad(crack[4])) else A(0, 0, rad(crack[4]))
			glow(model, body, "Crack", V(0.07, 0.6, 0.07), CF(crack[1], crack[2], crack[3]) * face, pal)
		end
		for _, cap in { { -0.45, 3.5, 0.6 }, { 0.5, 3.48, 0.1 }, { 0.75, 2.95, 0.9 }, { -0.85, 2.95, 0.15 } } do
			plate(model, body, "Spore", V(0.3, 0.2, 0.3), CF(cap[1], cap[2], cap[3]), pal)
		end
		limb(model, body, "Jaw", V(1.2, 0.3, 0.3), CF(0, 1.15, -1.15), V(0, 1.3, -1.0), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			leg(model, body, side * 0.7, 0.1, 0.55, 0.6, V(0.75, 0.25, 0.8), side, H2, H2)
		end
		tail(model, body, V(0, 0.8, 1.25), { V(1.2, 0.5, 0.7), V(0.8, 0.35, 0.6) }, { 15, 8 }, H)
	end

	-- Nightwing: a small black dragon on raised wings veined with light,
	-- three eyes, a spade on its tail.
	function B.Nightwing(model, pal, H, H2)
		local r = root(model, V(1.2, 1.2, 1.2), 1.6)
		local tilt = CF(0, 1.85, 0.1) * A(rad(-20), 0, 0)
		local body = limb(model, r, "Body", V(0.95, 1.3, 0.85), tilt, V(0, 1.4, 0.2), "Body", 1, H)
		make(model, body, "Chest", V(0.6, 0.8, 0.12), tilt * CF(0, 0.05, -0.45), H2)
		local head = make(model, body, "Head", V(0.8, 0.65, 0.8), CF(0, 2.75, -0.35), H)
		make(model, head, "Snout", V(0.5, 0.35, 0.45), CF(0, 2.62, -0.9), H)
		for _, spot in { { -0.2, 2.86 }, { 0.2, 2.86 }, { 0, 3.0 } } do
			glow(model, head, "Eye", V(0.12, 0.1, 0.08), CF(spot[1], spot[2], -0.77), pal)
		end
		limb(model, head, "Jaw", V(0.45, 0.16, 0.45), CF(0, 2.42, -0.88), V(0, 2.5, -0.65), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, head, "Horn", V(0.14, 0.55, 0.14), CF(side * 0.3, 3.25, -0.2) * A(rad(30), 0, rad(-side * 20)), pal)
			local w, frame = wing(model, body, V(side * 0.4, 2.35, 0.25), V(1.8, 0.1, 1.2), 40, 15, side, H)
			plate(model, w, "Edge", V(1.75, 0.15, 0.15), frame * CF(side * 0.9, 0, -0.58), pal)
			for k = 0, 2 do
				glow(model, w, "Vein", V(1.5, 0.12, 0.07), frame * CF(side * 0.85, 0, -0.3 + k * 0.32) * A(0, rad(side * (k - 1) * 10), 0), pal)
			end
			local tip = frame * CF(side * 1.75, 0, 0) * A(0, rad(-side * 25), rad(side * 15))
			make(model, w, "Outer", V(1.3, 0.08, 0.9), tip * CF(side * 0.62, 0, 0.1), H)
			glow(model, w, "Vein", V(1.1, 0.1, 0.07), tip * CF(side * 0.55, 0, 0.1), pal)
			arm(model, body, V(side * 0.48, 2.2, -0.35), V(0.22, 0.6, 0.22), 30, 10, side, H)
			leg(model, body, side * 0.3, 0.25, 1.25, 0.24, V(0.35, 0.12, 0.45), side, H, H, 2)
		end
		local sizes = { V(0.32, 0.3, 0.6), V(0.25, 0.24, 0.6), V(0.2, 0.18, 0.55), V(0.15, 0.14, 0.5) }
		tail(model, body, V(0, 1.3, 0.55), sizes, { 40, 25, 5, -20 }, H, function(seg, frame, i, s)
			if i == #sizes then
				plate(model, seg, "Spade", V(0.35, 0.08, 0.35), frame * CF(0, 0, s.Z / 2) * A(0, rad(45), 0), pal)
			end
		end)
	end

	-- Longcoil: a jade serpent, coiled, its head reared up on its neck,
	-- whiskers and eyes of light.
	function B.Longcoil(model, pal, H, H2)
		local r = root(model, V(1.8, 1.0, 1.8), 1.0)
		local body = limb(model, r, "Coil", V(1.6, 0.7, 1.6), CF(0, 0.4, 0.4), V(0, 0.5, 0.4), "Body", 1, H2)
		for i = 0, 7 do
			local a = rad(i * 45)
			local at = CF(math.cos(a) * 1.15, 0.36, 0.4 + math.sin(a) * 1.15) * A(0, -a, 0)
			make(model, body, "Coil", V(0.72, 0.72, 0.95), at, H)
			if i % 2 == 0 then
				plate(model, body, "Scale", V(0.5, 0.1, 0.6), at * CF(0, 0.38, 0), pal)
			end
		end
		for i = 0, 5 do
			local a = rad(i * 60 + 30)
			make(model, body, "Coil", V(0.62, 0.62, 0.85), CF(math.cos(a) * 0.8, 0.98, 0.45 + math.sin(a) * 0.8) * A(0, -a, 0), H)
		end
		local neck, tip = tail(
			model,
			body,
			V(0, 1.15, -0.15),
			{ V(0.7, 0.7, 0.8), V(0.62, 0.62, 0.8), V(0.55, 0.55, 0.75) },
			{ -65, -80, -35 },
			H,
			function(seg, frame, _, s)
				make(model, seg, "Belly", V(s.X * 0.7, 0.1, s.Z * 0.9), frame * CF(0, -s.Y / 2, 0), H2)
			end,
			180
		)
		local top = (tip * CF(0, 0, 0.32)).Position -- (the neck's end)
		local head = limb(model, neck, "Head", V(0.8, 0.6, 1.05), CF(top + V(0, 0.15, -0.4)), top, "Head", 1, H)
		make(model, head, "Snout", V(0.6, 0.38, 0.5), CF(top + V(0, 0.08, -1.1)), H)
		eyes(model, head, 0.36, top.Y + 0.28, top.Z - 0.62, V(0.1, 0.12, 0.22), pal)
		limb(model, head, "Jaw", V(0.55, 0.16, 0.85), CF(top + V(0, -0.22, -0.85)), top + V(0, -0.15, -0.4), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, head, "Horn", V(0.12, 0.6, 0.12), CF(top + V(side * 0.25, 0.65, -0.1)) * A(rad(30), 0, rad(-side * 20)), pal)
			plate(model, head, "Antler", V(0.1, 0.32, 0.1), CF(top + V(side * 0.42, 0.72, -0.28)) * A(rad(-10), 0, rad(-side * 50)), pal)
			glow(model, head, "Whisker", V(0.05, 0.05, 0.9), CF(top + V(side * 0.42, 0.0, -1.2)) * A(0, rad(side * 35), 0), pal)
		end
	end

	-- Glassjaw: a lean sand-coloured lizard on thin legs, a row of glowing
	-- spines down its back.
	function B.Glassjaw(model, pal, H, H2)
		local r = root(model, V(1.2, 1.0, 2.0), 1.75)
		local back = CF(0, 1.95, 0.2) * A(rad(4), 0, 0)
		local body = limb(model, r, "Body", V(0.95, 0.8, 2.6), back, V(0, 1.85, 0.4), "Body", 1, H)
		for i = 0, 6 do
			local h = 0.42 + math.sin(i / 6 * math.pi) * 0.25
			glow(model, body, "Spine", V(0.1, h, h), back * CF(0, 0.42, -1.1 + i * 0.36) * A(rad(45), 0, 0), pal)
		end
		for _, side in { -1, 1 } do
			plate(model, body, "Stripe", V(0.06, 0.16, 1.9), back * CF(side * 0.48, 0.05, 0), pal)
		end
		make(model, body, "Neck", V(0.5, 0.45, 0.6), CF(0, 2.15, -1.3) * A(rad(-15), 0, 0), H)
		local head = make(model, body, "Head", V(0.6, 0.45, 1.0), CF(0, 2.3, -1.85), H)
		make(model, head, "Snout", V(0.45, 0.32, 0.6), CF(0, 2.22, -2.6), H)
		plate(model, head, "Brow", V(0.5, 0.1, 0.7), CF(0, 2.56, -1.95), pal)
		eyes(model, head, 0.31, 2.4, -2.0, V(0.08, 0.1, 0.18), pal)
		local jaw = limb(model, head, "Jaw", V(0.42, 0.14, 1.1), CF(0, 2.0, -2.35), V(0, 2.08, -1.85), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			make(model, jaw, "Tooth", V(0.08, 0.1, 0.08), CF(side * 0.15, 2.1, -2.82), CLAW)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.48, if spot[2] < 0 then -0.75 else 1.05
			local l = leg(model, body, x, z, 1.65, 0.24, V(0.34, 0.12, 0.5), -spot[1] * spot[2], H, H2, 2)
			make(model, l, "Thigh", V(0.3, 0.45, 0.45), CF(x * 1.05, 1.5, z), H2)
		end
		local sizes = { V(0.5, 0.45, 0.9), V(0.38, 0.34, 0.9), V(0.28, 0.25, 0.85), V(0.2, 0.18, 0.8), V(0.12, 0.12, 0.75) }
		tail(model, body, V(0, 2.0, 1.45), sizes, { 10, 8, 6, 4, 2 }, H, function(seg, frame, i, s)
			if i <= 2 then
				glow(model, seg, "Spine", V(0.1, 0.35, 0.35), frame * CF(0, s.Y / 2, 0) * A(rad(45), 0, 0), pal)
			elseif i == 3 then
				plate(model, seg, "Band", V(s.X + 0.04, 0.1, 0.3), frame * CF(0, s.Y / 2, 0), pal)
			end
		end)
	end

	-- Razorclaw: a heavy navy beast on four legs, wings folded up, a glowing
	-- throat and a pincer of light on its tail.
	function B.Razorclaw(model, pal, H, H2)
		local r = root(model, V(2.0, 1.6, 2.4), 2.1)
		local body = limb(model, r, "Body", V(1.8, 1.5, 2.6), CF(0, 2.25, 0.2), V(0, 2.0, 0.3), "Body", 1, H)
		make(model, body, "Hump", V(1.9, 0.7, 1.2), CF(0, 3.05, -0.55), H2)
		local head = make(model, body, "Head", V(1.2, 0.9, 1.2), CF(0, 2.8, -1.65), H)
		make(model, head, "Snout", V(0.95, 0.55, 0.7), CF(0, 2.65, -2.4), H)
		eyes(model, head, 0.42, 3.0, -2.22, V(0.14, 0.1, 0.1), pal)
		for _, side in { -1, 1 } do
			make(model, head, "Horn", V(0.18, 0.4, 0.3), CF(side * 0.45, 3.35, -1.4) * A(rad(-30), 0, 0), H2)
		end
		glow(model, head, "Sac", V(0.85, 0.65, 0.85), CF(0, 1.95, -1.85), pal)
		limb(model, head, "Jaw", V(0.9, 0.28, 0.85), CF(0, 2.3, -2.4), V(0, 2.42, -1.98), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local w, frame = wing(model, body, V(side * 0.6, 3.3, -0.2), V(1.7, 0.1, 1.2), 45, 20, side, H2)
			plate(model, w, "Edge", V(1.6, 0.14, 0.14), frame * CF(side * 0.85, 0, -0.56), pal)
			make(model, w, "Bone", V(1.5, 0.14, 0.12), frame * CF(side * 0.85, 0, 0.1) * A(0, rad(side * 15), 0), H)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.7, if spot[2] < 0 then -0.7 else 1.05
			leg(model, body, x, z, 1.65, 0.7, V(0.85, 0.35, 0.95), -spot[1] * spot[2], H, H2, 3)
		end
		local sizes = { V(0.6, 0.55, 0.8), V(0.5, 0.45, 0.75), V(0.4, 0.36, 0.7), V(0.3, 0.28, 0.65) }
		tail(model, body, V(0, 2.45, 1.45), sizes, { 0, -25, -50, -70 }, H, function(seg, frame, i, s)
			if i <= 2 then
				plate(model, seg, "Band", V(s.X + 0.06, s.Y + 0.06, 0.2), frame, pal)
			elseif i == #sizes then
				for _, side in { -1, 1 } do
					glow(model, seg, "Pincer", V(0.12, 0.12, 0.5), frame * CF(side * 0.16, 0, s.Z / 2 + 0.2) * A(0, rad(side * 20), 0), pal)
				end
			end
		end)
	end

	-- Triskull: a golden three-headed dragon on two legs, two tails, wings.
	function B.Triskull(model, pal, H, H2)
		local r = root(model, V(2.0, 2.0, 2.0), 2.3)
		local lean = CF(0, 2.85, 0.2) * A(rad(-10), 0, 0)
		local torso = limb(model, r, "Torso", V(1.9, 2.2, 1.6), lean, V(0, 1.8, 0.3), "Body", 1, H)
		make(model, torso, "Belly", V(1.3, 1.6, 0.2), lean * CF(0, -0.1, -0.82), H2)
		for i = 0, 3 do
			glow(model, torso, "Spine", V(0.15, 0.36, 0.36), lean * CF(0, 0.85 - i * 0.5, 0.82) * A(rad(45), 0, 0), pal)
		end
		for side = -1, 1 do
			local base = V(side * 0.55, 3.75, -0.3)
			local top = V(side * 1.25, 4.6 + (if side == 0 then 0.45 else 0), -0.8 - (if side == 0 then 0.15 else 0))
			local neck = strut(model, torso, "Neck", base, top, 0.42, H, "Head", if side == 0 then 0.5 else side)
			local head = make(model, neck, "Head", V(0.55, 0.45, 0.75), CF(top + V(0, 0.1, -0.25)), H)
			make(model, head, "Snout", V(0.42, 0.3, 0.45), CF(top + V(0, 0.04, -0.82)), H)
			eyes(model, head, 0.29, top.Y + 0.2, top.Z - 0.42, V(0.06, 0.1, 0.14), pal)
			limb(model, head, "Jaw", V(0.38, 0.12, 0.62), CF(top + V(0, -0.16, -0.7)), top + V(0, -0.12, -0.3), "Jaw", 1, H2)
			for _, horn in { -1, 1 } do
				plate(model, head, "Horn", V(0.1, 0.38, 0.1), CF(top + V(horn * 0.18, 0.48, 0.0)) * A(rad(35), 0, rad(-horn * 15)), pal)
			end
		end
		for _, side in { -1, 1 } do
			local w, frame = wing(model, torso, V(side * 0.75, 3.7, 0.55), V(2.0, 0.1, 1.4), 35, 25, side, H2)
			plate(model, w, "Edge", V(1.9, 0.15, 0.15), frame * CF(side * 1.0, 0, -0.66), pal)
			make(model, w, "Bone", V(1.7, 0.14, 0.12), frame * CF(side * 0.95, 0, 0.15) * A(0, rad(side * 15), 0), H)
			local l = leg(model, torso, side * 0.6, 0.35, 1.8, 0.7, V(0.85, 0.35, 1.1), side, H, H2, 3)
			make(model, l, "Thigh", V(0.85, 0.8, 0.95), CF(side * 0.62, 1.5, 0.35), H)
			local sizes = { V(0.55, 0.5, 0.9), V(0.45, 0.4, 0.85), V(0.34, 0.3, 0.8), V(0.24, 0.2, 0.75) }
			tail(model, torso, V(side * 0.3, 1.95, 0.95), sizes, { 28, 15, 5, -5 }, H, function(seg, frame2, i, s)
				if i <= 2 then
					glow(model, seg, "Spine", V(0.1, 0.3, 0.3), frame2 * CF(0, s.Y / 2, 0) * A(rad(45), 0, 0), pal)
				end
			end, side * 18)
		end
	end

	-- Brightsteel: a chrome machine of a kaiju, a visor and four vents of
	-- light in its chest.
	function B.Brightsteel(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.25)
		local lean = CF(0, 2.85, 0.1) * A(rad(-6), 0, 0)
		local torso = limb(model, r, "Torso", V(1.7, 2.1, 1.35), lean, V(0, 1.85, 0.15), "Body", 1, H)
		make(model, torso, "Frame", V(1.2, 1.1, 0.12), lean * CF(0, 0.35, -0.7), H2)
		for _, x in { -0.28, 0.28 } do
			for _, y in { 0.1, 0.6 } do
				glow(model, torso, "Vent", V(0.42, 0.4, 0.08), lean * CF(x, y, -0.78), pal)
			end
		end
		for i = 0, 2 do
			plate(model, torso, "Fin", V(0.18, 0.45, 0.45), lean * CF(0, 0.7 - i * 0.55, 0.75) * A(rad(45), 0, 0), pal)
		end
		local head = make(model, torso, "Head", V(0.9, 0.85, 0.95), CF(0, 4.3, -0.25), H)
		glow(model, head, "Visor", V(0.75, 0.16, 0.08), CF(0, 4.35, -0.74), pal)
		make(model, head, "Crest", V(0.25, 0.25, 0.8), CF(0, 4.8, -0.2), H2)
		limb(model, head, "Jaw", V(0.7, 0.22, 0.6), CF(0, 3.82, -0.5), V(0, 3.92, -0.2), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, torso, "Shoulder", V(0.75, 0.5, 0.85), CF(side * 1.05, 3.68, 0.05), pal)
			local p, hand = arm(model, torso, V(side * 1.02, 3.45, -0.05), V(0.45, 0.85, 0.45), 20, 10, side, H)
			make(model, p, "Forearm", V(0.52, 0.75, 0.52), hand * CF(0, -0.3, 0), H2)
			make(model, p, "Hand", V(0.45, 0.32, 0.45), hand * CF(0, -0.8, 0), H)
			for i = -1, 1 do
				make(model, p, "Finger", V(0.1, 0.25, 0.1), hand * CF(i * 0.14, -1.05, -0.12), H2)
			end
			local l = leg(model, torso, side * 0.55, 0.2, 1.85, 0.6, V(0.75, 0.35, 1.05), side, H, H2, 3)
			make(model, l, "Thigh", V(0.7, 0.7, 0.8), CF(side * 0.57, 1.55, 0.2), H)
			make(model, l, "Knee", V(0.65, 0.4, 0.3), CF(side * 0.55, 1.0, -0.2), H2)
		end
		local sizes = { V(0.6, 0.55, 0.7), V(0.5, 0.45, 0.7), V(0.42, 0.36, 0.65), V(0.32, 0.28, 0.6), V(0.22, 0.2, 0.55) }
		tail(model, torso, V(0, 2.0, 0.75), sizes, { 25, 15, 5, -5, -5 }, H, function(seg, frame, i, s)
			if i == #sizes then
				glow(model, seg, "Tip", V(0.16, 0.16, 0.2), frame * CF(0, 0, s.Z / 2), pal)
			else
				make(model, seg, "Joint", V(s.X + 0.08, s.Y + 0.08, 0.12), frame * CF(0, 0, s.Z / 2 - 0.08), H2)
			end
		end)
	end

	-- Dreadcrown: a red horned tyrant, a crown of spikes tipped with light,
	-- a burst of light in its chest, pincers for hands and small wings.
	function B.Dreadcrown(model, pal, H, H2)
		local r = root(model, V(1.8, 1.8, 1.8), 2.1)
		local lean = CF(0, 2.65, 0.1) * A(rad(-8), 0, 0)
		local torso = limb(model, r, "Torso", V(1.8, 1.9, 1.4), lean, V(0, 1.7, 0.2), "Body", 1, H)
		make(model, torso, "Hips", V(1.5, 0.6, 1.3), CF(0, 1.75, 0.15), H2)
		for k = 0, 3 do
			glow(model, torso, "Star", V(0.85, 0.2, 0.08), lean * CF(0, 0.2, -0.72) * A(0, 0, rad(k * 45)), pal)
		end
		local head = make(model, torso, "Head", V(1.0, 0.9, 0.95), CF(0, 3.95, -0.3), H2)
		eyes(model, head, 0.24, 4.02, -0.79, V(0.18, 0.1, 0.06), pal)
		for _, spot in { { -0.42, -0.1, 0.65 }, { -0.2, -0.5, 0.85 }, { 0, -0.6, 0.95 }, { 0.2, -0.5, 0.85 }, { 0.42, -0.1, 0.65 } } do
			local at = CF(spot[1], 4.4 + spot[3] / 2, spot[2]) * A(0, 0, rad(-spot[1] * 30))
			plate(model, head, "Crown", V(0.2, spot[3], 0.2), at, pal)
			glow(model, head, "CrownTip", V(0.22, 0.2, 0.22), at * CF(0, spot[3] / 2, 0), pal)
		end
		limb(model, head, "Jaw", V(0.8, 0.25, 0.65), CF(0, 3.4, -0.45), V(0, 3.5, -0.15), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, torso, V(side * 1.1, 3.25, -0.2), V(0.55, 1.0, 0.55), 30, 20, side, H)
			make(model, p, "Pincer", V(0.32, 0.7, 0.45), hand * A(rad(30), 0, 0) * CF(0, -0.3, -0.12), H)
			make(model, p, "Pincer", V(0.26, 0.55, 0.36), hand * A(rad(75), 0, 0) * CF(0, -0.25, 0.1), H2)
			wing(model, torso, V(side * 0.6, 3.5, 0.6), V(1.4, 0.1, 1.0), 40, 30, side, H)
			leg(model, torso, side * 0.55, 0.3, 1.75, 0.65, V(0.8, 0.3, 1.0), side, H, H2, 3)
		end
		local sizes = { V(0.6, 0.55, 0.8), V(0.48, 0.42, 0.8), V(0.36, 0.3, 0.75), V(0.24, 0.2, 0.7) }
		tail(model, torso, V(0, 1.8, 0.8), sizes, { 30, 15, 0, -10 }, H, function(seg, frame, i, s)
			if i <= 2 then
				spike(model, seg, 0.5, frame * CF(0, s.Y / 2, 0), pal)
			end
		end)
	end

	-- Bladebrow: a slate-grey brute with four arms, a long blade over its
	-- brow edged in light.
	function B.Bladebrow(model, pal, H, H2)
		local r = root(model, V(2.0, 2.0, 2.0), 2.3)
		local lean = CF(0, 2.95, 0.1) * A(rad(-12), 0, 0)
		local torso = limb(model, r, "Torso", V(2.1, 2.2, 1.5), lean, V(0, 1.85, 0.2), "Body", 1, H)
		for _, x in { -0.28, 0.28 } do
			make(model, torso, "Pec", V(0.75, 0.5, 0.18), lean * CF(x * 1.5, 0.55, -0.8), H2)
			for _, y in { -0.1, -0.5 } do
				make(model, torso, "Ab", V(0.45, 0.32, 0.14), lean * CF(x, y, -0.78), H2)
			end
		end
		local head = make(model, torso, "Head", V(0.85, 0.8, 0.9), CF(0, 4.3, -0.4), H)
		plate(model, head, "Blade", V(0.22, 0.5, 2.6), CF(0, 4.85, -1.2), pal)
		glow(model, head, "Edge", V(0.24, 0.1, 2.5), CF(0, 4.58, -1.25), pal)
		eyes(model, head, 0.22, 4.35, -0.86, V(0.18, 0.1, 0.06), pal)
		limb(model, head, "Jaw", V(0.65, 0.22, 0.6), CF(0, 3.82, -0.6), V(0, 3.92, -0.3), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, torso, "Shoulder", V(0.7, 0.4, 0.8), CF(side * 1.15, 4.0, -0.05) * A(0, 0, rad(-side * 15)), pal)
			local upper, hand = arm(model, torso, V(side * 1.15, 3.7, -0.15), V(0.6, 1.1, 0.6), 15, 15, side, H)
			make(model, upper, "Fist", V(0.62, 0.5, 0.62), hand * CF(0, -0.25, 0), H2)
			local lower, hand2 = arm(model, torso, V(side * 1.0, 2.75, -0.3), V(0.5, 0.9, 0.5), 25, 10, side, H2)
			make(model, lower, "Fist", V(0.5, 0.42, 0.5), hand2 * CF(0, -0.2, 0), H)
			local l = leg(model, torso, side * 0.6, 0.3, 1.85, 0.75, V(0.9, 0.35, 1.15), side, H, H2, 3)
			make(model, l, "Thigh", V(0.85, 0.8, 0.95), CF(side * 0.62, 1.55, 0.3), H)
		end
		local sizes = { V(0.7, 0.6, 0.9), V(0.55, 0.45, 0.85), V(0.4, 0.32, 0.8), V(0.26, 0.22, 0.7) }
		tail(model, torso, V(0, 2.0, 0.85), sizes, { 30, 15, 5, -5 }, H, function(seg, frame, i, s)
			spike(model, seg, 0.55 - i * 0.07, frame * CF(0, s.Y / 2, 0), pal)
		end)
	end

	-- Lankshade: a pale, gaunt crawler on long thin limbs, eyes and mouth
	-- of light.
	function B.Lankshade(model, pal, H, H2)
		local r = root(model, V(1.4, 1.4, 1.4), 2.6)
		local hunch = CF(0, 3.35, -0.1) * A(rad(-50), 0, 0)
		local torso = limb(model, r, "Torso", V(1.1, 1.6, 0.8), hunch, V(0, 2.75, 0.3), "Body", 1, H)
		for i = 0, 2 do
			make(model, torso, "Spine", V(0.25, 0.25, 0.25), hunch * CF(0, 0.55 - i * 0.5, 0.45), H2)
		end
		local head = make(model, torso, "Head", V(0.8, 0.7, 0.8), CF(0, 3.85, -1.15), H)
		eyes(model, head, 0.2, 3.95, -1.56, V(0.2, 0.12, 0.06), pal)
		glow(model, head, "Mouth", V(0.45, 0.1, 0.06), CF(0, 3.62, -1.56), pal)
		limb(model, head, "Jaw", V(0.6, 0.18, 0.55), CF(0, 3.4, -1.25), V(0, 3.5, -0.95), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			local p, hand = arm(model, torso, V(side * 0.65, 3.65, -0.7), V(0.22, 1.5, 0.22), 20, 12, side, H)
			plate(model, p, "Elbow", V(0.28, 0.28, 0.28), hand, pal)
			local fore = hand * A(rad(-25), 0, rad(-side * 5))
			make(model, p, "Forearm", V(0.18, 1.6, 0.18), fore * CF(0, -0.8, 0), H)
			for i = -1, 1 do
				make(model, p, "Finger", V(0.06, 0.45, 0.06), fore * CF(i * 0.08, -1.75, 0) * A(rad(-20), 0, rad(i * 15)), H2)
			end
			local hip = V(side * 0.42, 2.75, 0.35)
			local knee = V(side * 0.5, 1.5, -0.25)
			local thigh = strut(model, torso, "Leg", hip, knee, 0.28, H, "Stride", side)
			strut(model, thigh, "Shin", knee, V(side * 0.5, 0.1, 0.3), 0.22, H)
			make(model, thigh, "Foot", V(0.35, 0.14, 0.6), CF(side * 0.5, 0.07, 0.15), H2)
			plate(model, thigh, "Knee", V(0.32, 0.32, 0.32), CF(knee), pal)
		end
	end

	-- Voltfin: a navy eel walking on two legs, a cream belly, a ridge of
	-- glowing fins down its back.
	function B.Voltfin(model, pal, H, H2)
		local r = root(model, V(1.4, 1.2, 2.0), 1.9)
		local back = CF(0, 2.1, 0.1) * A(rad(-6), 0, 0)
		local body = limb(model, r, "Body", V(1.2, 1.15, 2.4), back, V(0, 1.9, 0.3), "Body", 1, H)
		make(model, body, "Belly", V(0.9, 0.2, 2.0), back * CF(0, -0.6, 0), H2)
		make(model, body, "Chest", V(0.85, 0.9, 0.15), back * CF(0, -0.05, -1.2), H2)
		plate(model, body, "Ridge", V(0.3, 0.12, 2.2), back * CF(0, 0.62, 0), pal)
		for i = 0, 5 do
			glow(model, body, "Fin", V(0.1, 0.32 + (i % 2) * 0.16, 0.22), back * CF(0, 0.8 + (i % 2) * 0.08, -0.9 + i * 0.36), pal)
		end
		local head = make(model, body, "Head", V(0.85, 0.75, 1.1), CF(0, 2.38, -1.6), H)
		make(model, head, "Snout", V(0.65, 0.5, 0.6), CF(0, 2.24, -2.3), H)
		eyes(model, head, 0.43, 2.52, -1.75, V(0.08, 0.16, 0.2), pal)
		limb(model, head, "Jaw", V(0.6, 0.22, 0.95), CF(0, 1.9, -2.0), V(0, 2.0, -1.5), "Jaw", 1, H2)
		for _, side in { -1, 1 } do
			plate(model, head, "Gill", V(0.08, 0.5, 0.35), CF(side * 0.44, 2.25, -1.15), pal)
			plate(model, body, "Stripe", V(0.06, 0.14, 1.6), back * CF(side * 0.61, 0.2, 0.1), pal)
			local l = leg(model, body, side * 0.45, 0.25, 1.6, 0.45, V(0.6, 0.25, 0.85), side, H, H2, 3)
			make(model, l, "Thigh", V(0.55, 0.6, 0.7), CF(side * 0.47, 1.35, 0.25), H)
		end
		local sizes = { V(1.0, 0.95, 1.0), V(0.85, 0.8, 1.0), V(0.7, 0.6, 0.95), V(0.55, 0.42, 0.9), V(0.4, 0.28, 0.85) }
		tail(model, body, V(0, 2.05, 1.25), sizes, { 18, 18, 14, 8, 2 }, H, function(seg, frame, i, s)
			if i <= 3 then
				glow(model, seg, "Fin", V(0.1, 0.36, 0.26), frame * CF(0, s.Y / 2 + 0.12, 0), pal)
			elseif i == #sizes then
				plate(model, seg, "Fluke", V(0.1, 0.6, 0.45), frame * CF(0, 0, s.Z / 2 + 0.1), pal)
			end
		end)
	end

	return B
end

return Shapes
