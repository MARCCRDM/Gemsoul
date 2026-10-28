--[[
	Bodies for the rest of the roster, second half: kinds 61 to 90
	(Shared.KaijuShapesMore hands in the helpers and merges these in). Each
	faces -Z and stands on the ground at the origin, after its concept
	render (docs/kaiju-concepts/kaiju-<name>.png).
]]
local Half = {}

local V, C = Vector3.new, Color3.fromRGB
local CF, A = CFrame.new, CFrame.Angles
local rad = math.rad

function Half.install(h)
	local make, limb, glow, plate, wedge, root = h.make, h.limb, h.glow, h.plate, h.wedge, h.root
	local beam, litBeam, tail, leg, pillar, arm, eyes = h.beam, h.litBeam, h.tail, h.leg, h.pillar, h.arm, h.eyes
	local CLAW = h.Claw
	local B = {}


	-- Tarrask: a squat brown reptile under a stepped dome of plates seamed
	-- with its element's light and spiked in its colour, a horned skull,
	-- a heavy spiked tail.
	function B.Tarrask(m, pal, H, H2)
		local r = root(m, V(2.2, 1.4, 2.6), 1.5)
		local body = limb(m, r, "Body", V(2.0, 1.1, 2.6), CF(0, 1.55, 0.2), V(0, 1.3, 0.2), "Body", 1, H)
		for i, layer in { { 2.55, 0.5, 3.0, 2.15 }, { 2.1, 0.45, 2.5, 2.6 }, { 1.4, 0.35, 1.7, 2.95 } } do
			make(m, body, "Dome", V(layer[1], layer[2], layer[3]), CF(0, layer[4], 0.2), H2)
		end
		for _, z in { -0.55, 0.2, 0.95 } do
			glow(m, body, "Seam", V(2.6, 0.06, 0.07), CF(0, 2.42, z), pal)
		end
		glow(m, body, "Seam", V(0.07, 0.06, 3.05), CF(0, 2.42, 0.2), pal)
		for _, s in { { 0, 3.25, 0.2, 0.42 }, { -0.6, 2.95, -0.6, 0.32 }, { 0.6, 2.95, -0.6, 0.32 }, { -0.6, 2.95, 1.0, 0.32 }, { 0.6, 2.95, 1.0, 0.32 } } do
			plate(m, body, "Spike", V(s[4], s[4], s[4]), CF(s[1], s[2], s[3]) * A(rad(45), rad(45), 0), pal)
		end
		local head = make(m, body, "Skull", V(1.0, 0.8, 0.9), CF(0, 1.65, -1.65), H)
		make(m, head, "Snout", V(0.75, 0.55, 0.5), CF(0, 1.52, -2.25), H2)
		eyes(m, head, 0.4, 1.8, -2.1, V(0.14, 0.1, 0.06), pal)
		for _, s in { -1, 1 } do
			beam(m, head, "Horn", V(s * 0.42, 1.95, -1.55), V(s * 0.82, 2.25, -1.25), 0.2, 0.2, H2)
			beam(m, head, "Horn", V(s * 0.82, 2.25, -1.25), V(s * 0.95, 2.6, -1.55), 0.14, 0.14, CLAW)
		end
		limb(m, head, "Jaw", V(0.7, 0.2, 0.6), CF(0, 1.15, -2.0), V(0, 1.25, -1.65), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			leg(m, body, spot[1] * 0.85, 1.3, if spot[2] < 0 then -0.75 else 1.1, 0.6, H, H2, 3, 0.15, -spot[1] * spot[2])
		end
		local club = tail(m, body, { V(0, 1.5, 1.5), V(0, 1.25, 2.3), V(0, 1.0, 3.0), V(0, 0.8, 3.6) }, { 0.85, 0.65, 0.45 }, H)
		for _, s in { -1, 1 } do
			make(m, club, "Spike", V(0.18, 0.18, 0.4), CF(s * 0.32, 0.9, 3.5) * A(0, rad(s * 50), 0), CLAW)
		end
	end

	-- Gorebull: a blocky grey bull, a hump on its shoulders, two great horns
	-- swept forward in its element's colour, tipped in its light.
	function B.Gorebull(m, pal, H, H2)
		local r = root(m, V(2.0, 1.6, 2.6), 1.9)
		local body = limb(m, r, "Body", V(1.8, 1.55, 2.8), CF(0, 2.25, 0.3), V(0, 1.85, 0.3), "Body", 1, H)
		make(m, body, "Hump", V(1.75, 0.8, 1.5), CF(0, 3.2, -0.45), H2)
		make(m, body, "Brisket", V(1.4, 0.8, 0.3), CF(0, 1.75, -1.0), H2)
		local head = make(m, body, "Head", V(1.0, 1.0, 0.9), CF(0, 2.3, -1.55), H)
		make(m, head, "Muzzle", V(0.8, 0.6, 0.4), CF(0, 1.98, -2.1), H2)
		eyes(m, head, 0.44, 2.5, -1.95, V(0.12, 0.1, 0.06), pal)
		for _, s in { -1, 1 } do
			local base, bend, tip = V(s * 0.42, 2.65, -1.6), V(s * 1.35, 2.8, -1.85), V(s * 1.6, 2.95, -2.6)
			beam(m, head, "Horn", base, bend, 0.26, 0.26, pal.Plate)
			beam(m, head, "Horn", bend, tip, 0.2, 0.2, pal.Plate)
			glow(m, head, "HornTip", V(0.18, 0.18, 0.3), CF(tip) * A(0, rad(s * 10), 0), pal)
			make(m, head, "Ear", V(0.3, 0.14, 0.2), CF(s * 0.62, 2.45, -1.35), H2)
		end
		limb(m, head, "Jaw", V(0.7, 0.2, 0.5), CF(0, 1.62, -1.95), V(0, 1.72, -1.6), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			pillar(m, body, spot[1] * 0.62, 1.65, if spot[2] < 0 then -0.85 else 1.3, 0.58, H, H2, 2, -spot[1] * spot[2])
		end
		local tip = tail(m, body, { V(0, 2.75, 1.7), V(0, 2.2, 2.0), V(0, 1.6, 2.15) }, { 0.16, 0.12 }, H)
		make(m, tip, "Tuft", V(0.24, 0.3, 0.24), CF(0, 1.5, 2.17), H2)
	end

	-- Yetihide: a shaggy snow-white yeti, long fur hanging in blocks, a
	-- fringe hiding its face but for two lit eyes, a mark of its element's
	-- light on its chest, huge hands.
	function B.Yetihide(m, pal, H, H2)
		local r = root(m, V(1.8, 2.0, 1.6), 2.4)
		local lean = CF(0, 3.0, 0.1) * A(rad(-8), 0, 0)
		local torso = limb(m, r, "Torso", V(2.0, 2.2, 1.5), lean, V(0, 1.9, 0.15), "Body", 1, H)
		for i, x in { -0.62, 0, 0.62 } do
			make(m, torso, "Fur", V(0.5, 1.1, 0.2), CF(x, 1.95 + (i % 2) * 0.15, -0.72), H2)
		end
		for _, s in { -1, 1 } do
			make(m, torso, "Fur", V(0.22, 1.5, 1.2), CF(s * 1.08, 2.45, 0.1), H2)
			plate(m, torso, "Frost", V(0.6, 0.25, 0.7), CF(s * 1.05, 3.95, 0.05) * A(0, 0, rad(-s * 12)), pal)
		end
		make(m, torso, "Fur", V(1.6, 1.2, 0.22), CF(0, 2.6, 0.85), H2)
		glow(m, torso, "Mark", V(0.5, 0.3, 0.08), lean * CF(0, 0.35, -0.8), pal)
		plate(m, torso, "MarkFrame", V(0.66, 0.08, 0.1), lean * CF(0, 0.55, -0.79), pal)
		local head = make(m, torso, "Head", V(1.1, 1.0, 1.0), CF(0, 4.45, -0.3), H)
		make(m, head, "Fringe", V(1.2, 0.42, 0.32), CF(0, 4.72, -0.78), H2)
		eyes(m, head, 0.24, 4.42, -0.82, V(0.18, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.75, 0.25, 0.6), CF(0, 3.98, -0.55), V(0, 4.08, -0.2), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 1.38, 1.85, -0.25)
			local p = arm(m, torso, V(s * 1.25, 3.8, 0), V(s * 1.48, 2.8, 0), hand, 0.75, H, H)
			make(m, p, "Hand", V(0.92, 0.75, 0.92), CF(hand + V(0, -0.35, -0.05)), H2)
			plate(m, p, "Knuckles", V(0.92, 0.2, 0.25), CF(hand + V(0, -0.35, -0.5)), pal)
			h.talons(m, p, hand + V(0, -0.7, -0.3), 3, 0.3, CLAW)
			leg(m, torso, s * 0.6, 1.9, 0.2, 0.78, H, H2, 3, 0.15)
		end
	end

	-- Longneck: a green sauropod, a long neck up to a small head, a ridge
	-- of its element's colour down its back and spines of its light down
	-- its neck, four pillar legs, a long tail.
	function B.Longneck(m, pal, H, H2)
		local r = root(m, V(1.8, 1.6, 2.6), 1.9)
		local body = limb(m, r, "Body", V(1.7, 1.5, 2.8), CF(0, 2.25, 0.4), V(0, 1.85, 0.4), "Body", 1, H)
		make(m, body, "Belly", V(1.4, 0.3, 2.4), CF(0, 1.5, 0.4), H2)
		for i = 0, 4 do
			plate(m, body, "Ridge", V(0.16, 0.4, 0.4), CF(0, 3.08, -0.6 + i * 0.5) * A(rad(45), 0, 0), pal)
		end
		local points = { V(0, 2.6, -0.85), V(0, 3.5, -1.4), V(0, 4.35, -1.8), V(0, 5.0, -2.0) }
		local neck = tail(m, body, points, { 0.68, 0.56, 0.46 }, H, function(seg, i, at, w)
			glow(m, seg, "Spine", V(0.1, 0.26, 0.26), CF(at + V(0, w * 0.3, w * 0.45)) * A(rad(45), 0, 0), pal)
		end, "Neck")
		local top = points[4]
		local head = limb(m, neck, "Head", V(0.55, 0.5, 0.9), CF(top + V(0, 0.15, -0.35)), top, "Head", 1, H)
		eyes(m, head, 0.28, top.Y + 0.25, top.Z - 0.4, V(0.06, 0.1, 0.12), pal)
		limb(m, head, "Jaw", V(0.45, 0.14, 0.6), CF(top + V(0, -0.15, -0.45)), top + V(0, -0.1, -0.2), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			pillar(m, body, spot[1] * 0.6, 1.65, if spot[2] < 0 then -0.55 else 1.4, 0.6, H, H2, 3, -spot[1] * spot[2])
		end
		tail(
			m,
			body,
			{ V(0, 2.35, 1.75), V(0, 1.95, 2.7), V(0, 1.45, 3.55), V(0, 1.0, 4.3) },
			{ 0.72, 0.52, 0.36 },
			H,
			function(seg, i, at, w)
				glow(m, seg, "Spine", V(0.08, 0.2, 0.2), CF(at + V(0, w * 0.5, 0)) * A(rad(45), 0, 0), pal)
			end
		)
	end

	-- Barnacrab: a crab under a shanty of rusted plates, patched in its
	-- element's colour, little windows lit, stalk eyes, one great claw and
	-- one small, six legs.
	function B.Barnacrab(m, pal, H, H2)
		local r = root(m, V(2.0, 1.2, 1.8), 1.6)
		local body = limb(m, r, "Body", V(2.2, 0.85, 1.8), CF(0, 1.72, 0), V(0, 1.5, 0), "Body", 1, H)
		for _, p in { { -0.55, 2.35, -0.2, 1.0, 0.5, 1.0, 6 }, { 0.5, 2.3, 0.25, 0.9, 0.45, 1.1, -8 }, { -0.1, 2.75, 0.15, 0.8, 0.4, 0.8, 4 } } do
			make(m, body, "Shanty", V(p[4], p[5], p[6]), CF(p[1], p[2], p[3]) * A(0, rad(p[7]), rad(p[7] * 0.6)), H2)
		end
		for _, p in { { 0.65, 2.55, -0.4 }, { -0.75, 2.62, 0.45 }, { 0.2, 3.0, -0.1 }, { -0.35, 2.15, -0.92 } } do
			plate(m, body, "Patch", V(0.36, 0.3, 0.06), CF(p[1], p[2], p[3] - 0.1) * A(0, rad(p[1] * 20), 0), pal)
		end
		for _, w in { { -0.55, 2.4, -0.71 }, { 0.5, 2.35, -0.31 } } do
			glow(m, body, "Window", V(0.16, 0.14, 0.06), CF(w[1], w[2], w[3]), pal)
		end
		make(m, body, "Chimney", V(0.2, 0.5, 0.2), CF(0.2, 3.2, 0.25), H)
		limb(m, body, "Mouth", V(0.7, 0.3, 0.3), CF(0, 1.4, -0.98), V(0, 1.5, -0.85), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local top = V(s * 0.45, 2.55, -0.95)
			beam(m, body, "Stalk", V(s * 0.35, 1.95, -0.8), top, 0.1, 0.1, H2)
			glow(m, body, "Eye", V(0.18, 0.18, 0.18), CF(top + V(0, 0.08, 0)), pal)
			local big = s > 0
			local w = if big then 0.42 else 0.28
			local hand = V(s * 1.3, 1.35, -2.0)
			local p = arm(m, body, V(s * 0.9, 1.6, -0.75), V(s * 1.55, 1.6, -1.3), hand, w, H, H2)
			local size = if big then V(0.9, 0.65, 1.0) else V(0.5, 0.36, 0.7)
			make(m, p, "Claw", size, CF(hand + V(0, 0, -0.3)), H)
			make(m, p, "Pincer", V(size.X * 0.5, size.Y * 0.4, size.Z * 0.8), CF(hand + V(0, -size.Y * 0.35, -0.3 - size.Z * 0.6)), H2)
		end
		for i, z in { -0.5, 0.1, 0.7 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				h.spindle(m, body, V(s * 1.0, 1.5, z), V(s * 1.85, 1.75, z * 1.3), V(s * 2.15, 0.05, z * 1.5), 0.18, H, H2, step)
			end
		end
	end

	-- Rancorn: a hunched brute with a huge head, a wide tusked mouth lit
	-- inside with its element's light, small eyes, long arms with long
	-- fingers it walks on.
	function B.Rancorn(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.8), 2.2)
		local hunch = CF(0, 2.9, 0.2) * A(rad(-25), 0, 0)
		local torso = limb(m, r, "Torso", V(1.9, 1.8, 1.6), hunch, V(0, 1.9, 0.5), "Body", 1, H)
		for i = 0, 3 do
			plate(m, torso, "Spine", V(0.14, 0.3, 0.3), hunch * CF(0, 0.95 - i * 0.05, -0.3 + i * 0.4) * A(rad(45), 0, 0), pal)
		end
		local head = make(m, torso, "Head", V(1.4, 1.15, 1.3), CF(0, 3.65, -1.05), H)
		make(m, head, "Brow", V(1.45, 0.3, 0.4), CF(0, 4.1, -1.55), H2)
		eyes(m, head, 0.3, 3.92, -1.72, V(0.12, 0.08, 0.06), pal)
		glow(m, head, "Mouth", V(1.0, 0.22, 0.1), CF(0, 3.25, -1.7), pal)
		local jaw = limb(m, head, "Jaw", V(1.3, 0.42, 1.2), CF(0, 2.95, -1.25), V(0, 3.15, -0.65), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			wedge(m, jaw, "Tusk", V(0.14, 0.45, 0.16), CF(s * 0.5, 3.35, -1.8), CLAW)
			make(m, jaw, "Tooth", V(0.1, 0.14, 0.08), CF(s * 0.2, 3.22, -1.82), CLAW)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 1.42, 0.62, -0.95)
			local p = arm(m, torso, V(s * 1.1, 3.35, -0.35), V(s * 1.5, 2.15, -0.55), hand, 0.55, H, H)
			for i = -1, 1 do
				beam(m, p, "Finger", hand + V(i * 0.17, 0, 0), hand + V(i * 0.22, -0.52, -0.35), 0.12, 0.12, H2)
			end
			leg(m, torso, s * 0.6, 1.9, 0.6, 0.66, H, H2, 3, 0.2)
		end
	end

	-- Gashclaw: a lean, dark horned reptile on two legs, horns curving back
	-- off its skull, long bladed claws of its element's light.
	function B.Gashclaw(m, pal, H, H2)
		local r = root(m, V(1.4, 1.8, 1.4), 2.3)
		local hunch = CF(0, 3.0, 0.15) * A(rad(-22), 0, 0)
		local torso = limb(m, r, "Torso", V(1.1, 1.6, 0.9), hunch, V(0, 2.1, 0.4), "Body", 1, H)
		for i = 0, 3 do
			plate(m, torso, "Spine", V(0.12, 0.26, 0.26), hunch * CF(0, 0.65 - i * 0.42, 0.5) * A(rad(45), 0, 0), pal)
		end
		local head = make(m, torso, "Head", V(0.72, 0.58, 0.9), CF(0, 3.85, -0.75), H)
		make(m, head, "Snout", V(0.52, 0.4, 0.5), CF(0, 3.75, -1.4), H2)
		eyes(m, head, 0.32, 3.95, -1.05, V(0.06, 0.1, 0.14), pal)
		for _, s in { -1, 1 } do
			local a, b, c = V(s * 0.3, 4.12, -0.6), V(s * 0.5, 4.55, -0.35), V(s * 0.45, 4.7, 0.15)
			beam(m, head, "Horn", a, b, 0.16, 0.16, H2)
			beam(m, head, "Horn", b, c, 0.12, 0.12, H2)
		end
		limb(m, head, "Jaw", V(0.48, 0.16, 0.8), CF(0, 3.5, -1.1), V(0, 3.58, -0.7), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.92, 1.75, -0.95)
			local p = arm(m, torso, V(s * 0.65, 3.4, -0.35), V(s * 0.98, 2.6, -0.6), hand, 0.3, H, H2)
			for i = -1, 1 do
				local base = hand + V(i * 0.1, 0, 0)
				h.litBeam(m, p, "Blade", base, base + V(i * 0.12, -0.75, -0.45), 0.08, pal)
			end
			leg(m, torso, s * 0.45, 2.1, 0.45, 0.45, H, H2, 3, 0.35)
		end
		tail(m, torso, { V(0, 2.1, 0.8), V(0, 1.8, 1.6), V(0, 1.5, 2.4), V(0, 1.3, 3.1) }, { 0.45, 0.34, 0.22 }, H)
	end

	-- Mossgiant: a huge bark-brown giant grown over with moss, a crack of
	-- its element's light across its chest, lichen in its colour.
	function B.Mossgiant(m, pal, H, H2)
		local r = root(m, V(1.8, 2.0, 1.4), 2.5)
		local torso = limb(m, r, "Torso", V(2.0, 2.2, 1.3), CF(0, 3.2, 0), V(0, 2.1, 0), "Body", 1, H)
		for _, p in { { -0.55, 3.8, -0.62, 0.7, 0.6 }, { 0.6, 2.7, -0.62, 0.6, 0.8 }, { 0.3, 4.05, 0.62, 0.9, 0.5 }, { -0.5, 2.6, 0.62, 0.7, 0.7 } } do
			make(m, torso, "Moss", V(p[4], p[5], 0.1), CF(p[1], p[2], p[3]), H2)
		end
		for i, c in { { 0, 0, 0 }, { 0.18, 0.18, 40 }, { -0.2, 0.12, -35 }, { 0.05, -0.22, 75 } } do
			glow(m, torso, "Crack", V(0.07, 0.5, 0.06), CF(c[1], 3.4 + c[2], -0.66) * A(0, 0, rad(c[3])), pal)
		end
		local head = make(m, torso, "Head", V(0.92, 0.95, 0.9), CF(0, 4.78, -0.05), H)
		make(m, head, "MossCap", V(0.96, 0.3, 0.94), CF(0, 5.3, -0.05), H2)
		eyes(m, head, 0.2, 4.85, -0.51, V(0.16, 0.1, 0.06), pal)
		limb(m, head, "Jaw", V(0.66, 0.22, 0.55), CF(0, 4.35, -0.2), V(0, 4.45, 0.05), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, torso, "Shoulder", V(0.7, 0.4, 0.9), CF(s * 1.15, 4.35, 0), H2)
			plate(m, torso, "Lichen", V(0.36, 0.1, 0.36), CF(s * 1.15, 4.58, 0.1), pal)
			local hand = V(s * 1.4, 1.95, -0.15)
			local p = arm(m, torso, V(s * 1.25, 4.0, 0), V(s * 1.48, 3.0, 0), hand, 0.66, H, H)
			make(m, p, "Fist", V(0.75, 0.7, 0.75), CF(hand + V(0, -0.3, -0.05)), H2)
			local l = leg(m, torso, s * 0.55, 2.1, 0.05, 0.72, H, H2, 0, 0.12)
			plate(m, l, "Lichen", V(0.3, 0.3, 0.1), CF(s * 0.58, 1.2, -0.25), pal)
		end
	end


	-- Blackhorn: a black armoured brute, one great horn forward off its
	-- brow, jagged shoulder plates in its element's colour, spines of its
	-- light down its tail.
	function B.Blackhorn(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.6), 2.2)
		local lean = CF(0, 2.85, 0.15) * A(rad(-8), 0, 0)
		local torso = limb(m, r, "Torso", V(1.8, 2.0, 1.4), lean, V(0, 1.85, 0.2), "Body", 1, H)
		make(m, torso, "Belly", V(1.2, 1.4, 0.18), lean * CF(0, -0.15, -0.74), H2)
		local head = make(m, torso, "Head", V(0.9, 0.85, 1.0), CF(0, 4.2, -0.45), H)
		make(m, head, "Snout", V(0.7, 0.5, 0.5), CF(0, 4.05, -1.1), H2)
		beam(m, head, "Horn", V(0, 4.55, -0.75), V(0, 5.0, -1.45), 0.3, 0.3, pal.Plate)
		h.litBeam(m, head, "HornTip", V(0, 5.0, -1.45), V(0, 5.12, -1.8), 0.16, pal)
		eyes(m, head, 0.3, 4.32, -0.96, V(0.16, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.66, 0.22, 0.7), CF(0, 3.72, -0.9), V(0, 3.82, -0.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			for i = 0, 1 do
				wedge(m, torso, "Pauldron", V(0.5, 0.75 - i * 0.2, 0.7), CF(s * (1.0 + i * 0.25), 3.85 + i * 0.3, 0.05 + i * 0.15) * A(0, 0, rad(-s * (20 + i * 15))), pal.Plate)
			end
			glow(m, torso, "PauldronEdge", V(0.08, 0.5, 0.08), CF(s * 1.3, 4.25, -0.15) * A(0, 0, rad(-s * 30)), pal)
			local hand = V(s * 1.15, 2.3, -0.75)
			local p = arm(m, torso, V(s * 1.05, 3.5, -0.1), V(s * 1.25, 2.8, -0.4), hand, 0.5, H, H2)
			h.talons(m, p, hand, 3, 0.3, CLAW)
			leg(m, torso, s * 0.55, 1.85, 0.35, 0.65, H, H2, 3, 0.18)
		end
		tail(
			m,
			torso,
			{ V(0, 2.0, 1.0), V(0, 1.5, 1.8), V(0, 1.05, 2.6), V(0, 0.72, 3.3), V(0, 0.6, 3.9) },
			{ 0.75, 0.6, 0.45, 0.32 },
			H,
			function(seg, i, at, w)
				glow(m, seg, "Spine", V(0.08, 0.3, 0.3), CF(at + V(0, w * 0.55, 0)) * A(rad(45), 0, 0), pal)
			end
		)
	end

	-- Gluttonjaw: a hunched, pot-bellied reptile that is mostly jaw, its
	-- maw lit inside with its element's light, spines in its colour down
	-- its back and tail, short arms.
	function B.Gluttonjaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.8), 2.1)
		local hunch = CF(0, 2.5, 0.3) * A(rad(-15), 0, 0)
		local body = limb(m, r, "Body", V(1.8, 2.0, 1.7), hunch, V(0, 1.6, 0.5), "Body", 1, H)
		make(m, body, "Belly", V(1.5, 1.5, 0.3), hunch * CF(0, -0.25, -0.85), H2)
		for i = 0, 3 do
			plate(m, body, "Spine", V(0.14, 0.4, 0.4), hunch * CF(0, 1.05, -0.4 + i * 0.4) * A(rad(45), 0, 0), pal)
		end
		local head = make(m, body, "Head", V(1.3, 0.75, 1.4), CF(0, 3.65, -0.95), H)
		eyes(m, head, 0.5, 3.85, -1.45, V(0.1, 0.08, 0.1), pal)
		glow(m, head, "Maw", V(1.12, 0.35, 1.15), CF(0, 3.18, -1.0), pal)
		make(m, head, "Teeth", V(1.15, 0.12, 0.12), CF(0, 3.25, -1.62), CLAW)
		local jaw = limb(m, head, "Jaw", V(1.25, 0.4, 1.4), CF(0, 2.86, -0.95), V(0, 3.05, -0.3), "Jaw", 1, H2)
		make(m, jaw, "Teeth", V(1.1, 0.12, 0.12), CF(0, 3.1, -1.6), CLAW)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.85, 2.15, -1.1)
			local p = arm(m, body, V(s * 0.85, 2.8, -0.6), V(s * 0.95, 2.4, -0.85), hand, 0.28, H, H2)
			h.talons(m, p, hand, 2, 0.24, CLAW)
			leg(m, body, s * 0.6, 1.6, 0.6, 0.72, H, H2, 3, 0.2)
		end
		tail(
			m,
			body,
			{ V(0, 1.9, 1.3), V(0, 1.4, 2.1), V(0, 1.0, 2.8), V(0, 0.7, 3.4) },
			{ 0.8, 0.6, 0.42 },
			H,
			function(seg, i, at, w)
				plate(m, seg, "Spine", V(0.12, 0.3, 0.3), CF(at + V(0, w * 0.55, 0)) * A(rad(45), 0, 0), pal)
			end
		)
	end

	-- Lashape: a lean, hunched red ape with a mean grin, knuckles on the
	-- ground, a long whip of a tail arcing up over its head, banded in its
	-- element's colour and tipped in its light.
	function B.Lashape(m, pal, H, H2)
		local r = root(m, V(1.6, 1.6, 1.4), 2.0)
		local hunch = CF(0, 2.55, 0.2) * A(rad(-20), 0, 0)
		local torso = limb(m, r, "Torso", V(1.4, 1.5, 1.0), hunch, V(0, 1.75, 0.35), "Body", 1, H)
		make(m, torso, "Chest", V(1.0, 0.9, 0.14), hunch * CF(0, 0.1, -0.54), H2)
		local head = make(m, torso, "Head", V(0.85, 0.8, 0.8), CF(0, 3.45, -0.4), H)
		make(m, head, "Face", V(0.66, 0.55, 0.1), CF(0, 3.42, -0.82), H2)
		make(m, head, "Brow", V(0.86, 0.16, 0.22), CF(0, 3.72, -0.75), H)
		eyes(m, head, 0.18, 3.58, -0.88, V(0.14, 0.08, 0.05), pal)
		make(m, head, "Grin", V(0.5, 0.1, 0.05), CF(0, 3.28, -0.89), CLAW)
		limb(m, head, "Jaw", V(0.6, 0.2, 0.5), CF(0, 3.02, -0.5), V(0, 3.12, -0.25), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 1.0, 0.95, -0.6)
			local p = arm(m, torso, V(s * 0.85, 3.0, -0.2), V(s * 1.12, 2.0, -0.4), hand, 0.4, H, H)
			make(m, p, "Fist", V(0.48, 0.45, 0.48), CF(hand + V(0, -0.22, 0)), H2)
			leg(m, torso, s * 0.45, 1.75, 0.4, 0.5, H, H2, 3, 0.25)
		end
		local points = { V(0, 1.85, 0.8), V(0, 2.65, 1.4), V(0, 3.6, 1.6), V(0, 4.35, 1.25), V(0, 4.7, 0.55), V(0, 4.6, -0.05) }
		local tip = tail(m, torso, points, { 0.26, 0.22, 0.19, 0.16, 0.13 }, H, function(seg, i, at, w)
			if i <= 4 then
				plate(m, seg, "Band", V(w + 0.06, 0.08, w + 0.06), CF(at), pal)
			end
		end, "Whip")
		glow(m, tip, "Lash", V(0.18, 0.18, 0.3), CF(points[6]), pal)
	end

	-- Oculus: a floating stepped saucer of slate, one great eye of its
	-- element's light under a lid (its jaw), three small wings, lights of
	-- its colour round its rim.
	function B.Oculus(m, pal, H, H2)
		local r = root(m, V(1.6, 1.0, 1.6), 1.0)
		local disc = limb(m, r, "Saucer", V(0.36, 3.0, 3.0), CF(0, 0.95, 0) * A(0, 0, rad(90)), V(0, 0.95, 0), "Body", 1, H)
		disc.Shape = Enum.PartType.Cylinder
		h.disc(m, disc, "Saucer", 2.4, 0.3, CF(0, 1.27, 0), H2)
		h.disc(m, disc, "Saucer", 1.7, 0.4, CF(0, 1.6, 0.1), H)
		h.disc(m, disc, "Belly", 2.2, 0.3, CF(0, 0.62, 0), H2)
		h.disc(m, disc, "Keel", 1.0, 0.35, CF(0, 0.3, 0), H)
		for i = 0, 3 do
			local a = rad(i * 90 + 45)
			plate(m, disc, "Rim", V(0.3, 0.2, 0.3), CF(math.cos(a) * 1.45, 0.95, math.sin(a) * 1.45) * A(0, -a, 0), pal)
			glow(m, disc, "Light", V(0.16, 0.12, 0.16), CF(math.cos(a + rad(45)) * 1.48, 0.95, math.sin(a + rad(45)) * 1.48), pal)
		end
		local eye = make(m, disc, "EyeBall", V(1.0, 0.9, 0.9), CF(0, 2.15, -0.2), H2)
		glow(m, eye, "Eye", V(0.66, 0.6, 0.1), CF(0, 2.15, -0.68), pal)
		make(m, eye, "Pupil", V(0.12, 0.42, 0.05), CF(0, 2.15, -0.74), H)
		limb(m, eye, "Lid", V(1.06, 0.3, 0.96), CF(0, 2.65, -0.22), V(0, 2.62, 0.25), "Jaw", 1, H)
		for _, s in { -1, 1 } do
			local at = V(s * 1.2, 1.1, 0.6)
			local wing = limb(m, disc, "Wing", V(0.9, 0.08, 0.5), CF(at + V(s * 0.45, 0.1, 0.1)) * A(0, rad(-s * 20), rad(s * 15)), at, "Wing", s, H2)
			plate(m, wing, "WingTip", V(0.3, 0.1, 0.3), CF(at + V(s * 0.95, 0.24, 0.25)) * A(0, rad(-s * 20), rad(s * 15)), pal)
		end
		wedge(m, disc, "Fin", V(0.1, 0.5, 0.6), CF(0, 1.55, 1.2), H2)
	end

	-- Quillhorn: a low brown lizard, four horns on its head, spines of its
	-- element's light down its flanks and spikes in its colour on its back.
	function B.Quillhorn(m, pal, H, H2)
		local r = root(m, V(1.6, 1.2, 2.2), 1.5)
		local body = limb(m, r, "Body", V(1.5, 1.1, 2.6), CF(0, 1.65, 0.2), V(0, 1.35, 0.2), "Body", 1, H)
		make(m, body, "Belly", V(1.2, 0.2, 2.2), CF(0, 1.08, 0.2), H2)
		for i = 0, 3 do
			plate(m, body, "Spike", V(0.18, 0.5, 0.18), CF(0, 2.4, -0.75 + i * 0.5) * A(rad(-15), 0, 0), pal)
		end
		for _, s in { -1, 1 } do
			for i = 0, 2 do
				glow(m, body, "Quill", V(0.1, 0.42, 0.1), CF(s * 0.82, 2.0, -0.6 + i * 0.6) * A(rad(-20), 0, rad(-s * 55)), pal)
			end
		end
		local head = make(m, body, "Head", V(0.95, 0.75, 1.0), CF(0, 1.82, -1.45), H)
		make(m, head, "Snout", V(0.7, 0.5, 0.55), CF(0, 1.72, -2.12), H2)
		eyes(m, head, 0.43, 1.95, -1.75, V(0.08, 0.1, 0.16), pal)
		for _, s in { -1, 1 } do
			wedge(m, head, "Horn", V(0.16, 0.6, 0.3), CF(s * 0.32, 2.4, -1.75) * A(rad(-25), math.pi, rad(s * 10)), H2)
			wedge(m, head, "Horn", V(0.14, 0.45, 0.26), CF(s * 0.42, 2.25, -1.2) * A(rad(10), 0, rad(-s * 25)), H2)
		end
		limb(m, head, "Jaw", V(0.62, 0.18, 0.85), CF(0, 1.38, -1.95), V(0, 1.45, -1.55), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			leg(m, body, spot[1] * 0.62, 1.3, if spot[2] < 0 then -0.8 else 1.1, 0.46, H, H2, 3, 0.16, -spot[1] * spot[2])
		end
		tail(
			m,
			body,
			{ V(0, 1.65, 1.45), V(0, 1.4, 2.25), V(0, 1.1, 3.0), V(0, 0.85, 3.65) },
			{ 0.62, 0.46, 0.3 },
			H,
			function(seg, i, at, w)
				glow(m, seg, "Quill", V(0.08, 0.3, 0.08), CF(at + V(0, w * 0.6, 0)) * A(rad(-30), 0, 0), pal)
			end
		)
	end

	-- Phasehorn: an indigo four-legged lizard flickering out of sight from
	-- the tail forward, spots of its element's light on its flanks, a horn
	-- in its colour throwing sparks.
	function B.Phasehorn(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 2.4), 1.7)
		local body = limb(m, r, "Body", V(1.4, 1.2, 2.6), CF(0, 1.95, 0.2), V(0, 1.6, 0.2), "Body", 1, H)
		for i = 0, 3 do
			make(m, body, "Ridge", V(0.26, 0.4, 0.4), CF(0, 2.62, -0.8 + i * 0.45) * A(rad(45), 0, 0), H2)
		end
		for _, s in { -1, 1 } do
			for i = 0, 1 do
				glow(m, body, "Spot", V(0.06, 0.2, 0.26), CF(s * 0.71, 2.05 - i * 0.25, -0.5 + i * 0.6), pal)
			end
		end
		-- Its back end breaking up as it flickers.
		for i, f in { { 0.4, 2.3, 1.35, 0.4 }, { -0.35, 1.8, 1.55, 0.35 }, { 0.1, 2.55, 1.6, 0.3 }, { -0.2, 2.2, 1.9, 0.25 } } do
			local bit = make(m, body, "Flicker", V(f[4], f[4], f[4]), CF(f[1], f[2], f[3]), if i % 2 == 0 then H else H2)
			bit.Transparency = 0.15 + i * 0.15
		end
		local head = make(m, body, "Head", V(0.9, 0.8, 1.0), CF(0, 2.2, -1.5), H)
		make(m, head, "Snout", V(0.65, 0.5, 0.55), CF(0, 2.08, -2.2), H2)
		plate(m, head, "Horn", V(0.18, 0.7, 0.18), CF(0, 2.7, -2.15) * A(rad(-30), 0, 0), pal)
		plate(m, head, "Crest", V(0.6, 0.12, 0.6), CF(0, 2.65, -1.4) * A(0, rad(45), 0), pal)
		for i, sp in { { 0.25, 3.25, -2.45 }, { -0.2, 3.05, -2.6 }, { 0.05, 3.45, -2.25 } } do
			glow(m, head, "Spark", V(0.1, 0.1, 0.1), CF(sp[1], sp[2], sp[3]) * A(rad(45), rad(i * 30), 0), pal)
		end
		eyes(m, head, 0.4, 2.35, -1.85, V(0.14, 0.1, 0.06), pal)
		limb(m, head, "Jaw", V(0.6, 0.18, 0.8), CF(0, 1.72, -1.95), V(0, 1.8, -1.55), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local l = leg(m, body, spot[1] * 0.55, 1.6, if spot[2] < 0 then -0.85 else 1.05, 0.46, H, H2, 3, 0.18, -spot[1] * spot[2])
			if spot[2] > 0 then
				l.Transparency = 0.3
			end
		end
		plate(m, body, "Plate", V(0.5, 0.12, 0.5), CF(0, 2.56, -0.95), pal)
		plate(m, body, "Plate", V(0.42, 0.12, 0.42), CF(0, 2.56, 0.45), pal)
		local tip = tail(m, body, { V(0, 2.0, 1.45), V(0, 1.7, 2.2), V(0, 1.4, 2.9) }, { 0.55, 0.4 }, H)
		tip.Transparency = 0.45
	end

	-- Lightbird: a bird of light, golden, hovering on wide wings fanned
	-- into long feathers and trailing long tail feathers, every tip glowing.
	function B.Lightbird(m, pal, H, H2)
		local r = root(m, V(1.0, 1.2, 1.0), 2.4)
		local body = limb(m, r, "Body", V(0.75, 1.2, 0.65), CF(0, 2.75, 0), V(0, 2.35, 0), "Body", 1, H)
		make(m, body, "Breast", V(0.6, 0.8, 0.12), CF(0, 2.8, -0.36), H2)
		local head = make(m, body, "Head", V(0.55, 0.55, 0.55), CF(0, 3.6, -0.1), H)
		wedge(m, head, "Beak", V(0.18, 0.2, 0.3), CF(0, 3.55, -0.5) * A(0, math.pi, 0), H2)
		eyes(m, head, 0.18, 3.68, -0.36, V(0.1, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.16, 0.08, 0.26), CF(0, 3.42, -0.48), V(0, 3.45, -0.35), "Jaw", 1, H2)
		for i = -1, 1, 2 do
			plate(m, head, "Crest", V(0.08, 0.36, 0.14), CF(i * 0.1, 4.0, 0.05) * A(rad(-25), 0, rad(-i * 12)), pal)
		end
		for _, s in { -1, 1 } do
			local a, b = V(s * 0.35, 3.1, 0.05), V(s * 1.7, 3.7, 0.15)
			local wing = beam(m, body, "Wing", a, b, 0.2, 0.36, H, "Wing", s)
			plate(m, wing, "WingCap", V(0.22, 0.22, 0.4), CF(b), pal)
			for i = 0, 4 do
				local root = a:Lerp(b, 0.2 + i * 0.2)
				local tip = root + V(s * (0.25 + i * 0.2), -0.55 - (4 - i) * 0.08, 0.1)
				beam(m, wing, "Feather", root, tip, 0.12, 0.05, H2)
				h.litBeam(m, wing, "FeatherTip", tip, tip + (tip - root).Unit * 0.25, 0.1, pal)
			end
			local l = beam(m, body, "Leg", V(s * 0.15, 2.2, -0.05), V(s * 0.18, 1.75, -0.15), 0.1, 0.1, H2, "Stride", s)
			make(m, l, "Talon", V(0.18, 0.08, 0.22), CF(s * 0.18, 1.72, -0.2), CLAW)
		end
		for i = -2, 2 do
			local top = V(i * 0.1, 2.2, 0.15)
			local tip = V(i * 0.32, 0.25 + math.abs(i) * 0.25, 0.35 + math.abs(i) * 0.05)
			beam(m, body, "TailFeather", top, tip, 0.12, 0.05, H2)
			h.litBeam(m, body, "FeatherTip", tip, tip + (tip - top).Unit * 0.22, 0.1, pal)
		end
	end

	-- Pulsewing: a black eight-limbed insect, two pairs of wide wings of its
	-- element's colour raised over it, a hooked head, hooked legs.
	function B.Pulsewing(m, pal, H, H2)
		local r = root(m, V(1.4, 1.2, 1.6), 1.9)
		local body = limb(m, r, "Body", V(1.0, 0.9, 1.6), CF(0, 2.2, 0.2), V(0, 2.0, 0.2), "Body", 1, H)
		make(m, body, "Back", V(0.8, 0.25, 1.3), CF(0, 2.75, 0.2), H2)
		local head = make(m, body, "Head", V(0.6, 0.55, 0.7), CF(0, 2.35, -0.8), H)
		wedge(m, head, "Hook", V(0.3, 0.5, 0.3), CF(0, 2.0, -1.2) * A(math.pi, 0, 0), H2)
		eyes(m, head, 0.24, 2.48, -1.1, V(0.14, 0.1, 0.06), pal)
		limb(m, head, "Mandibles", V(0.42, 0.14, 0.3), CF(0, 2.05, -0.95), V(0, 2.12, -0.75), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			h.pane(m, body, V(s * 0.35, 2.85, 0.0), 2.4, 1.1, 38, 10, s, pal.Plate, pal.Glow)
			h.pane(m, body, V(s * 0.35, 2.75, 0.5), 1.7, 0.8, 22, 30, s, pal.Plate, pal.Glow)
			local hand = V(s * 0.45, 1.75, -1.35)
			local p = arm(m, body, V(s * 0.35, 2.05, -0.6), V(s * 0.55, 1.95, -1.0), hand, 0.12, H, H2)
			make(m, p, "Hook", V(0.1, 0.3, 0.1), CF(hand + V(0, -0.1, -0.05)) * A(rad(-30), 0, 0), H2)
		end
		for i, z in { -0.35, 0.2, 0.75 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				local knee = V(s * 1.3, 2.4, z * 1.2)
				local tip = V(s * 1.45, 0.05, z * 1.4)
				local p = h.spindle(m, body, V(s * 0.45, 2.0, z), knee, tip + V(-s * 0.15, 0.3, 0), 0.12, H, H, step)
				beam(m, p, "Hook", tip + V(-s * 0.15, 0.3, 0), tip, 0.08, 0.08, H2)
			end
		end
		tail(m, body, { V(0, 2.15, 1.0), V(0, 1.85, 1.6), V(0, 1.5, 2.05) }, { 0.6, 0.42 }, H)
	end


	-- Dunemaw: a great sand-coloured worm risen out of a mound, ringed
	-- segments, a round maw of plates in its element's colour opening on a
	-- core of its light. No legs: it moves underground.
	function B.Dunemaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.0, 1.8), 1.0)
		for i, mound in { { 2.8, 0.3, 0.15 }, { 2.1, 0.3, 0.42 }, { 1.4, 0.25, 0.66 } } do
			make(m, r, "Mound", V(mound[1], mound[2], mound[1]), CF(0.1 * i, mound[3], 0.2) * A(0, rad(i * 20), 0), H2)
		end
		local base = limb(m, r, "Base", V(1.2, 1.0, 1.2), CF(0, 1.05, 0.3), V(0, 0.6, 0.3), "Body", 1, H)
		local points = { V(0, 1.5, 0.3), V(0, 2.35, 0.2), V(0, 3.15, -0.1), V(0, 3.8, -0.5), V(0, 4.2, -1.0) }
		local neck = tail(m, base, points, { 1.0, 0.92, 0.85, 0.78 }, H, function(seg, i, at, w)
			make(m, seg, "Ring", V(w + 0.1, 0.16, w * 0.85 + 0.1), CF(at) * A(rad(-i * 12), 0, 0), H2)
		end, "Segment")
		local top = points[5]
		local face = CF(top + V(0, 0.1, -0.35)) * A(rad(-60), 0, 0)
		local head = limb(m, neck, "Maw", V(1.1, 0.9, 0.9), face, top, "Head", 1, H)
		glow(m, head, "Gullet", V(0.6, 0.12, 0.6), face * CF(0, 0.46, 0), pal)
		for i = 0, 3 do
			local a = rad(i * 90 + 45)
			plate(m, head, "Petal", V(0.42, 0.12, 0.62), face * CF(math.cos(a) * 0.48, 0.5, math.sin(a) * 0.48) * A(0, -a, 0) * A(0, 0, rad(25)), pal)
		end
		limb(m, head, "Jaw", V(0.5, 0.12, 0.62), face * CF(0, 0.52, -0.5) * A(rad(-25), 0, 0), (face * CF(0, 0.45, -0.25)).Position, "Jaw", 1, pal.Plate)
		for i = 0, 5 do
			local a = rad(i * 60)
			make(m, head, "Tooth", V(0.08, 0.16, 0.08), face * CF(math.cos(a) * 0.3, 0.55, math.sin(a) * 0.3), CLAW)
		end
	end

	-- Lashlight: a tall, slim indigo figure with a blank mask for a face,
	-- its arms two long whips of its element's light curling to the ground.
	function B.Lashlight(m, pal, H, H2)
		local r = root(m, V(1.2, 1.8, 1.0), 2.5)
		local torso = limb(m, r, "Torso", V(0.85, 1.7, 0.55), CF(0, 3.3, 0), V(0, 2.45, 0), "Body", 1, H)
		make(m, torso, "Shoulders", V(1.1, 0.3, 0.6), CF(0, 4.05, 0), H2)
		make(m, torso, "Hips", V(0.7, 0.35, 0.5), CF(0, 2.4, 0), H2)
		local head = make(m, torso, "Head", V(0.55, 0.75, 0.6), CF(0, 4.6, -0.05), H)
		make(m, head, "Mask", V(0.45, 0.58, 0.06), CF(0, 4.6, -0.37), H2)
		glow(m, head, "Seam", V(0.04, 0.4, 0.04), CF(0, 4.6, -0.41), pal)
		limb(m, head, "Jaw", V(0.36, 0.12, 0.36), CF(0, 4.2, -0.12), V(0, 4.25, 0.05), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local points = { V(s * 0.62, 4.0, 0), V(s * 0.78, 3.35, -0.1), V(s * 1.15, 2.4, -0.3), V(s * 1.5, 1.4, -0.2), V(s * 1.7, 0.55, 0.15), V(s * 1.35, 0.1, 0.45) }
			local p = beam(m, torso, "Arm", points[1], points[2], 0.24, 0.24, H, "Arm", s)
			for i = 2, 5 do
				h.litBeam(m, p, "Whip", points[i], points[i + 1], 0.16 - i * 0.015, pal)
			end
			plate(m, p, "Cuff", V(0.3, 0.16, 0.3), CF(points[2]), pal)
			plate(m, p, "Cuff", V(0.24, 0.12, 0.24), CF(points[4]), pal)
			leg(m, torso, s * 0.24, 2.45, 0, 0.3, H, H2, 2, 0.1)
		end
	end

	-- Inkstalk: a pale cuttlefish standing on six tentacles, a tall head
	-- fin lit along its top, big eyes of its element's light, two grasping
	-- arms reaching forward.
	function B.Inkstalk(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 1.6), 1.6)
		local body = limb(m, r, "Mantle", V(0.9, 2.4, 0.9), CF(0, 3.0, 0.1), V(0, 1.9, 0.1), "Body", 1, H)
		for _, s in { -1, 1 } do
			make(m, body, "Fin", V(0.14, 2.0, 0.6), CF(s * 0.5, 3.1, 0.15), H2)
		end
		glow(m, body, "Lamp", V(0.94, 0.12, 0.94), CF(0, 4.25, 0.1), pal)
		glow(m, body, "Lamp", V(0.1, 1.9, 0.08), CF(0, 3.2, -0.46), pal)
		make(m, body, "Hood", V(1.1, 0.7, 1.05), CF(0, 2.0, 0.05), H2)
		for _, s in { -1, 1 } do
			make(m, body, "EyeFrame", V(0.36, 0.36, 0.1), CF(s * 0.4, 2.05, -0.5), H2)
			glow(m, body, "Eye", V(0.26, 0.26, 0.1), CF(s * 0.4, 2.05, -0.55), pal)
		end
		limb(m, body, "Beak", V(0.34, 0.24, 0.34), CF(0, 1.6, -0.35), V(0, 1.72, -0.25), "Jaw", 1, H2)
		for i = 0, 5 do
			local a = rad(i * 60 + 30)
			local out = V(math.sin(a), 0, -math.cos(a))
			local side = if i % 2 == 0 then 1 else -1
			local hip = V(0, 1.7, 0.1) + out * 0.45
			local knee = V(0, 0.85, 0.1) + out * 1.35
			local tip = V(0, 0.08, 0.1) + out * 1.75
			local p = h.spindle(m, body, hip, knee, tip, 0.26, H, H, side)
			plate(m, p, "Band", V(0.32, 0.1, 0.32), CF((hip + knee) / 2) * A(0, -a, 0), pal)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 0.32, 1.35, -1.85)
			local p = arm(m, body, V(s * 0.3, 1.85, -0.45), V(s * 0.42, 1.55, -1.2), hand, 0.14, H, H)
			make(m, p, "Club", V(0.22, 0.22, 0.34), CF(hand + V(0, -0.02, -0.1)), H2)
		end
	end

	-- Skyrazor: a red-brown predator on four legs, great bat wings raised
	-- with edges of its element's colour, a hooked beak, a long tail
	-- ending in a blade.
	function B.Skyrazor(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 2.0), 1.6)
		local back = CF(0, 1.9, 0.2) * A(rad(-10), 0, 0)
		local body = limb(m, r, "Body", V(1.1, 1.1, 1.8), back, V(0, 1.6, 0.3), "Body", 1, H)
		make(m, body, "Belly", V(0.8, 0.2, 1.5), back * CF(0, -0.55, 0), H2)
		local neck = beam(m, body, "Neck", V(0, 2.2, -0.7), V(0, 2.7, -1.1), 0.45, 0.5, H)
		local head = make(m, neck, "Head", V(0.6, 0.55, 0.8), CF(0, 2.88, -1.4), H)
		wedge(m, head, "Beak", V(0.3, 0.45, 0.45), CF(0, 2.7, -1.95) * A(math.pi, 0, 0), H2)
		eyes(m, head, 0.31, 2.98, -1.6, V(0.06, 0.1, 0.12), pal)
		plate(m, head, "Crest", V(0.12, 0.3, 0.5), CF(0, 3.25, -1.2) * A(rad(-30), 0, 0), pal)
		limb(m, head, "Jaw", V(0.36, 0.14, 0.5), CF(0, 2.55, -1.6), V(0, 2.62, -1.35), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local a, b = V(s * 0.45, 2.35, -0.2), V(s * 1.6, 3.6, 0.1)
			local c, d = V(s * 3.0, 3.15, 0.6), V(s * 1.8, 1.95, 1.0)
			local w = h.batWing(m, body, a, b, c, d, H, H2)
			beam(m, w, "WingEdge", b, c, 0.1, 0.12, pal.Plate)
			beam(m, w, "WingFinger", b, d, 0.08, 0.1, H)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			leg(m, body, spot[1] * 0.45, 1.5, if spot[2] < 0 then -0.5 else 0.9, 0.36, H, H2, 3, 0.2, -spot[1] * spot[2])
		end
		local tip = tail(m, body, { V(0, 1.8, 1.1), V(0, 1.6, 1.9), V(0, 1.4, 2.7), V(0, 1.25, 3.5), V(0, 1.2, 4.2) }, { 0.4, 0.32, 0.24, 0.16 }, H)
		plate(m, tip, "Blade", V(0.1, 0.42, 0.5), CF(0, 1.2, 4.4) * A(rad(45), 0, 0), pal)
		plate(m, body, "Spine", V(0.12, 0.3, 0.3), CF(0, 2.5, 0) * A(rad(45), 0, 0), pal)
	end

	-- Thornlash: a hunched dark creature, twin tails curling behind it,
	-- each ending in a cluster of spines in its element's colour and light.
	function B.Thornlash(m, pal, H, H2)
		local r = root(m, V(1.4, 1.6, 1.4), 2.0)
		local hunch = CF(0, 2.55, 0.15) * A(rad(-30), 0, 0)
		local torso = limb(m, r, "Torso", V(1.3, 1.4, 1.0), hunch, V(0, 1.8, 0.4), "Body", 1, H)
		make(m, torso, "Back", V(1.1, 0.3, 1.0), hunch * CF(0, 0.6, 0.35), H2)
		local head = make(m, torso, "Head", V(0.75, 0.65, 0.75), CF(0, 3.15, -0.65), H)
		eyes(m, head, 0.2, 3.22, -1.03, V(0.14, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.55, 0.18, 0.5), CF(0, 2.8, -0.8), V(0, 2.88, -0.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.85, 0.95, -0.75)
			local p = arm(m, torso, V(s * 0.75, 2.9, -0.3), V(s * 0.98, 2.0, -0.5), hand, 0.34, H, H)
			h.talons(m, p, hand, 3, 0.28, CLAW)
			leg(m, torso, s * 0.45, 1.8, 0.5, 0.45, H, H2, 3, 0.25)
			local points = { V(s * 0.25, 1.8, 0.9), V(s * 0.5, 1.6, 1.7), V(s * 0.9, 1.7, 2.4), V(s * 1.2, 2.3, 2.9) }
			local tip = tail(m, torso, points, { 0.3, 0.25, 0.2 }, H)
			local at = points[4]
			for i = 0, 3 do
				local spike = CF(at) * A(rad(-30 + i * 25), rad(i * 70), rad(s * (20 + i * 20))) * CF(0, 0.3, 0)
				if i % 2 == 0 then
					plate(m, tip, "Spine", V(0.12, 0.6, 0.12), spike, pal)
				else
					glow(m, tip, "Spine", V(0.1, 0.5, 0.1), spike, pal)
				end
			end
		end
	end

	-- Flickerstripe: a tall, thin black figure striped in white, a pale head
	-- with three faces round it (it turns them, a Head joint), hands of its
	-- element's colour.
	function B.Flickerstripe(m, pal, H, H2)
		local r = root(m, V(1.2, 1.8, 1.0), 2.6)
		local torso = limb(m, r, "Torso", V(0.9, 1.8, 0.6), CF(0, 3.4, 0), V(0, 2.5, 0), "Body", 1, H)
		for i = -1, 1 do
			make(m, torso, "Stripe", V(0.08, 1.7, 0.05), CF(i * 0.27, 3.4, -0.31), H2)
		end
		make(m, torso, "Stripe", V(0.92, 0.08, 0.62), CF(0, 2.75, 0), H2)
		plate(m, torso, "Belt", V(0.94, 0.12, 0.64), CF(0, 2.55, 0), pal)
		local head = limb(m, torso, "Head", V(0.6, 0.75, 0.6), CF(0, 4.75, 0), V(0, 4.35, 0), "Head", 1, H2)
		make(m, head, "Cap", V(0.64, 0.25, 0.64), CF(0, 5.2, 0), H)
		plate(m, head, "Crown", V(0.66, 0.06, 0.66), CF(0, 5.05, 0), pal)
		for _, face in { { 0, -1 }, { 1, 0 }, { -1, 0 } } do
			local fx, fz = face[1], face[2]
			for _, e in { -1, 1 } do
				local off = if fz ~= 0 then V(e * 0.14, 0, 0) else V(0, 0, e * 0.14)
				glow(m, head, "Eye", V(0.1, 0.08, 0.1), CF(V(fx * 0.31, 4.82, fz * 0.31) + off), pal)
			end
			make(m, head, "Mouth", V(if fz ~= 0 then 0.24 else 0.06, 0.05, if fz ~= 0 then 0.06 else 0.24), CF(fx * 0.31, 4.58, fz * 0.31), H)
		end
		limb(m, head, "Jaw", V(0.4, 0.12, 0.4), CF(0, 4.32, -0.08), V(0, 4.36, 0.1), "Jaw", 1, H)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.72, 2.4, -0.12)
			local p = arm(m, torso, V(s * 0.6, 4.1, 0), V(s * 0.72, 3.25, 0), hand, 0.22, H, H)
			make(m, p, "Stripe", V(0.05, 0.8, 0.06), CF(s * 0.66, 3.65, -0.1), H2)
			plate(m, p, "Hand", V(0.26, 0.32, 0.24), CF(hand + V(0, -0.12, 0)), pal)
			local l = leg(m, torso, s * 0.24, 2.5, 0, 0.3, H, H2, 0, 0.08)
			make(m, l, "Stripe", V(0.05, 1.0, 0.06), CF(s * 0.25, 1.85, -0.2) * A(rad(-14), 0, 0), H2)
		end
	end

	-- Cleaverhead: a hunched blue-grey brute under a huge flat blade of a
	-- head, edged in its element's light, four arms.
	function B.Cleaverhead(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.6), 2.1)
		local hunch = CF(0, 2.7, 0.2) * A(rad(-20), 0, 0)
		local torso = limb(m, r, "Torso", V(1.8, 1.7, 1.4), hunch, V(0, 1.8, 0.4), "Body", 1, H)
		make(m, torso, "Chest", V(1.3, 1.0, 0.2), hunch * CF(0, 0.05, -0.75), H2)
		local head = make(m, torso, "Head", V(0.8, 0.6, 0.7), CF(0, 3.3, -0.85), H)
		eyes(m, head, 0.22, 3.32, -1.21, V(0.14, 0.08, 0.06), pal)
		local blade = CF(0, 3.9, -1.0) * A(rad(18), 0, 0)
		make(m, head, "Cleaver", V(1.6, 0.3, 1.7), blade, H2)
		h.litBeam(m, head, "Edge", (blade * CF(-0.8, 0, -0.85)).Position, (blade * CF(0.8, 0, -0.85)).Position, 0.12, pal)
		for _, s in { -1, 1 } do
			h.litBeam(m, head, "Edge", (blade * CF(s * 0.8, 0, -0.85)).Position, (blade * CF(s * 0.8, 0, 0.85)).Position, 0.1, pal)
		end
		make(m, head, "Neck", V(0.5, 0.6, 0.5), CF(0, 3.6, -0.8), H)
		limb(m, head, "Jaw", V(0.6, 0.2, 0.5), CF(0, 2.95, -0.95), V(0, 3.05, -0.7), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			plate(m, torso, "Shoulder", V(0.6, 0.4, 0.8), CF(s * 1.0, 3.55, -0.1), pal)
			local hand = V(s * 1.25, 1.75, -0.95)
			local p = arm(m, torso, V(s * 1.0, 3.25, -0.3), V(s * 1.38, 2.4, -0.6), hand, 0.5, H, H)
			make(m, p, "Fist", V(0.55, 0.5, 0.55), CF(hand + V(0, -0.2, 0)), H2)
			local hand2 = V(s * 0.98, 1.25, -0.8)
			local q = arm(m, torso, V(s * 0.85, 2.4, -0.25), V(s * 1.1, 1.8, -0.5), hand2, 0.38, H, H)
			plate(m, q, "Guard", V(0.42, 0.3, 0.42), CF(hand2 + V(0, 0.2, 0)), pal)
			leg(m, torso, s * 0.55, 1.8, 0.5, 0.65, H, H2, 3, 0.2)
		end
	end

	-- Starcrop: a dark teal bird-bodied brute, wings folded at its sides,
	-- a beaked head, a star-shaped mouth of its element's colour on its belly
	-- glowing with the light it eats.
	function B.Starcrop(m, pal, H, H2)
		local r = root(m, V(1.6, 1.8, 1.4), 2.2)
		local torso = limb(m, r, "Torso", V(1.5, 2.0, 1.2), CF(0, 2.85, 0.1), V(0, 1.85, 0.1), "Body", 1, H)
		local star = CF(0, 2.75, -0.53)
		plate(m, torso, "Star", V(0.62, 0.62, 0.08), star, pal)
		plate(m, torso, "Star", V(0.62, 0.62, 0.08), star * A(0, 0, rad(45)), pal)
		glow(m, torso, "Gullet", V(0.36, 0.36, 0.1), star * CF(0, 0, -0.02) * A(0, 0, rad(22)), pal)
		local head = make(m, torso, "Head", V(0.8, 0.75, 0.8), CF(0, 4.25, -0.2), H)
		wedge(m, head, "Beak", V(0.36, 0.36, 0.5), CF(0, 4.2, -0.82) * A(0, math.pi, 0), H2)
		make(m, head, "Crest", V(0.16, 0.4, 0.6), CF(0, 4.75, 0.05), H2)
		eyes(m, head, 0.3, 4.35, -0.56, V(0.14, 0.1, 0.06), pal)
		limb(m, head, "Jaw", V(0.3, 0.12, 0.4), CF(0, 3.98, -0.72), V(0, 4.03, -0.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local p = arm(m, torso, V(s * 0.85, 3.55, 0.1), V(s * 1.15, 2.65, 0.3), V(s * 1.05, 1.85, 0.45), 0.3, H, H)
			wedge(m, p, "Feathers", V(0.14, 1.5, 0.8), CF(s * 1.12, 2.6, 0.55) * A(rad(-10), 0, rad(s * 8)), H2)
			plate(m, torso, "Spike", V(0.14, 0.4, 0.14), CF(s * 0.6, 3.95, 0.3) * A(rad(-20), 0, rad(-s * 20)), pal)
			leg(m, torso, s * 0.45, 1.85, 0.2, 0.45, H, H2, 3, -0.22)
		end
		wedge(m, torso, "TailFeathers", V(0.9, 0.3, 1.0), CF(0, 2.0, 1.0) * A(rad(-20), 0, 0), H2)
	end

	-- Drillmole: a robot mole, a stepped steel cone, a drill nose of its
	-- element's colour (its jaw lifts it), lamp eyes, tread feet.
	function B.Drillmole(m, pal, H, H2)
		local r = root(m, V(1.8, 1.6, 1.8), 1.9)
		local body = limb(m, r, "Hull", V(1.8, 1.2, 1.8), CF(0, 1.7, 0), V(0, 1.2, 0), "Body", 1, H)
		for i, step in { { 1.5, 0.6, 2.6 }, { 1.1, 0.6, 3.2 }, { 0.7, 0.6, 3.8 }, { 0.3, 0.45, 4.3 } } do
			make(m, body, "Cone", V(step[1], step[2], step[1]), CF(0, step[3], 0), if i % 2 == 1 then H2 else H)
		end
		make(m, body, "Band", V(1.86, 0.12, 1.86), CF(0, 2.05, 0), H2)
		eyes(m, body, 0.42, 1.65, -0.92, V(0.26, 0.2, 0.06), pal)
		local drill = limb(m, body, "Drill", V(0.85, 0.85, 0.35), CF(0, 2.3, -1.05) * A(0, 0, rad(45)), V(0, 2.3, -0.9), "Jaw", 1, pal.Plate)
		for i, s in { 0.62, 0.42, 0.22 } do
			plate(m, drill, "Drill", V(s, s, 0.32), CF(0, 2.3, -1.05 - i * 0.3) * A(0, 0, rad(45 + i * 15)), pal)
		end
		glow(m, drill, "Tip", V(0.1, 0.1, 0.25), CF(0, 2.3, -2.05), pal)
		for _, s in { -1, 1 } do
			local tread = limb(m, body, "Tread", V(0.55, 0.62, 1.8), CF(s * 0.98, 0.31, 0), V(s * 0.98, 0.9, 0), "Stride", s, H2)
			for i = -1, 1 do
				make(m, tread, "Cleat", V(0.58, 0.1, 0.2), CF(s * 0.98, 0.64, i * 0.6), H)
			end
			local hand = V(s * 1.15, 1.15, -0.85)
			local p = arm(m, body, V(s * 0.9, 1.8, -0.4), V(s * 1.2, 1.45, -0.6), hand, 0.22, H, H)
			h.talons(m, p, hand, 3, 0.22, CLAW)
		end
	end

	-- Gulper: a hulking grey-green alien, a huge mouth on its shoulder lit
	-- inside with its element's light, a cannon for one arm, spines in its
	-- colour down its back.
	function B.Gulper(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.8), 2.1)
		local hunch = CF(0, 2.75, 0.2) * A(rad(-15), 0, 0)
		local torso = limb(m, r, "Torso", V(2.0, 1.9, 1.6), hunch, V(0, 1.8, 0.4), "Body", 1, H)
		make(m, torso, "Chest", V(1.4, 1.1, 0.2), hunch * CF(0.2, -0.1, -0.85), H2)
		for i = 0, 3 do
			plate(m, torso, "Spine", V(0.14, 0.34, 0.34), hunch * CF(0.3, 0.95, -0.3 + i * 0.35) * A(rad(45), 0, 0), pal)
		end
		local head = make(m, torso, "Head", V(1.25, 0.6, 1.35), CF(-0.25, 4.0, -0.5), H)
		glow(m, head, "Maw", V(1.05, 0.3, 1.1), CF(-0.25, 3.62, -0.55), pal)
		make(m, head, "Teeth", V(1.05, 0.1, 0.1), CF(-0.25, 3.72, -1.15), CLAW)
		eyes(m, head, 0.18, 4.15, -1.18, V(0.12, 0.08, 0.05), pal)
		local jaw = limb(m, head, "Jaw", V(1.15, 0.35, 1.25), CF(-0.25, 3.35, -0.6), V(-0.25, 3.5, 0), "Jaw", 1, H2)
		make(m, jaw, "Teeth", V(1.0, 0.1, 0.1), CF(-0.25, 3.56, -1.18), CLAW)
		-- The cannon arm.
		local hand = V(1.3, 2.2, -1.25)
		local p = arm(m, torso, V(1.15, 3.3, -0.1), V(1.48, 2.5, -0.5), hand, 0.6, H, H)
		make(m, p, "Barrel", V(0.6, 0.6, 1.0), CF(hand + V(0, 0, -0.25)), H2)
		plate(m, p, "Ring", V(0.7, 0.7, 0.12), CF(hand + V(0, 0, -0.5)), pal)
		glow(m, p, "Muzzle", V(0.36, 0.36, 0.1), CF(hand + V(0, 0, -0.78)), pal)
		local hand2 = V(-1.2, 1.5, -0.6)
		local q = arm(m, torso, V(-1.1, 3.2, -0.1), V(-1.35, 2.3, -0.3), hand2, 0.55, H, H)
		h.talons(m, q, hand2, 3, 0.32, CLAW)
		for _, s in { -1, 1 } do
			leg(m, torso, s * 0.6, 1.8, 0.6, 0.7, H, H2, 3, 0.2)
		end
	end

	-- Pipsqueak: a small, round, friendly red-brown kaiju bristling with
	-- nubs of its element's colour, a wide smile (its jaw), bright eyes,
	-- stubby arms and legs.
	function B.Pipsqueak(m, pal, H, H2)
		local r = root(m, V(1.6, 1.2, 1.6), 1.3)
		local body = limb(m, r, "Body", V(2.1, 1.9, 1.9), CF(0, 1.85, 0), V(0, 0.9, 0), "Body", 1, H)
		make(m, body, "Top", V(1.7, 0.2, 1.5), CF(0, 2.9, 0), H)
		make(m, body, "Bottom", V(1.7, 0.2, 1.5), CF(0, 0.8, 0), H2)
		for _, s in { -1, 1 } do
			make(m, body, "Side", V(0.2, 1.5, 1.5), CF(s * 1.12, 1.85, 0), H)
		end
		for _, w in {
			{ -0.55, 3.02, -0.4 },
			{ 0.35, 3.05, 0.2 },
			{ -0.2, 3.0, 0.55 },
			{ 0.65, 2.98, -0.5 },
			{ -0.7, 2.95, 0.6 },
			{ -1.25, 2.3, -0.3 },
			{ -1.25, 1.5, 0.35 },
			{ -1.2, 2.6, 0.55 },
			{ 1.25, 2.2, 0.3 },
			{ 1.25, 1.4, -0.4 },
			{ 1.22, 2.65, -0.45 },
			{ -0.85, 2.6, -0.98 },
			{ 0.85, 1.15, -0.98 },
			{ 0.4, 2.2, 0.98 },
			{ -0.5, 1.4, 0.98 },
		} do
			plate(m, body, "Nub", V(0.24, 0.24, 0.24), CF(w[1], w[2], w[3]) * A(rad(15), rad(25), 0), pal)
		end
		for _, s in { -1, 1 } do
			make(m, body, "EyeWhite", V(0.32, 0.32, 0.06), CF(s * 0.42, 2.2, -0.96), C(236, 230, 214))
			glow(m, body, "Eye", V(0.16, 0.16, 0.06), CF(s * 0.42, 2.18, -0.99), pal)
			make(m, body, "Smile", V(0.16, 0.32, 0.08), CF(s * 0.52, 1.66, -0.97), CLAW)
		end
		limb(m, body, "Smile", V(1.2, 0.16, 0.1), CF(0, 1.46, -0.97), V(0, 1.5, -0.85), "Jaw", 1, CLAW)
		for _, s in { -1, 1 } do
			local hand = V(s * 1.42, 1.25, -0.3)
			local p = arm(m, body, V(s * 1.18, 1.95, -0.05), V(s * 1.45, 1.6, -0.15), hand, 0.34, H, H)
			make(m, p, "Hand", V(0.38, 0.32, 0.38), CF(hand + V(0, -0.1, 0)), H2)
			pillar(m, body, s * 0.5, 0.85, 0.1, 0.5, H, H2, 0)
		end
	end

	-- Shadowsphere: a black-and-white striped sphere floating over a disc of
	-- shadow on the ground, where it really is: a ring of teeth of its
	-- element's colour in the dark (its jaw).
	function B.Shadowsphere(m, pal, H, H2)
		local r = root(m, V(1.4, 1.0, 1.4), 0.8)
		local shadow = h.disc(m, r, "Shadow", 2.6, 0.06, CF(0, 0.03, 0), H2)
		local rim = h.disc(m, shadow, "Rim", 2.8, 0.04, CF(0, 0.02, 0), pal.Glow, Enum.Material.Neon)
		rim.Transparency = 0.4
		local maw = limb(m, shadow, "Maw", V(0.06, 1.7, 1.7), CF(0, 0.08, 0) * A(0, 0, rad(90)), V(0, 0.08, 0), "Jaw", 1, H2)
		maw.Shape = Enum.PartType.Cylinder
		for i = 0, 7 do
			local a = rad(i * 45)
			plate(m, maw, "Tooth", V(0.14, 0.18, 0.14), CF(math.cos(a) * 0.62, 0.17, math.sin(a) * 0.62) * A(0, -a, 0), pal)
		end
		local sphere = limb(m, r, "Sphere", V(2.2, 2.2, 2.2), CF(0, 2.0, 0), V(0, 1.0, 0), "Body", 1, H)
		sphere.Shape = Enum.PartType.Ball
		for i, band in { { -0.62, 25, 1.86 }, { 0.0, 25, 2.26 }, { 0.62, 25, 1.86 } } do
			h.disc(m, sphere, "Stripe", band[3], 0.26, CF(0, 2.0, 0) * A(0, 0, rad(band[2])) * CF(0, band[1], 0), H2)
		end
		for _, a in { 60, 120 } do
			h.disc(m, sphere, "Stripe", 2.26, 0.2, CF(0, 2.0, 0) * A(rad(90), rad(a), 0), H2)
		end
	end

	-- Twinsong: two dark kaiju that are one, a wide body split down the
	-- middle by a seam of its element's light; each half its own boxy head,
	-- one masked in its element's light and one in its colour, a long arm
	-- and two straight legs; shards of its colour down the one's back.
	function B.Twinsong(m, pal, H, H2)
		local r = root(m, V(2.0, 1.6, 1.2), 2.4)
		local torso = limb(m, r, "Torso", V(2.3, 1.7, 1.1), CF(0, 3.05, 0), V(0, 2.2, 0), "Body", 1, H)
		make(m, torso, "Hips", V(2.1, 0.35, 1.0), CF(0, 2.15, 0), H2)
		glow(m, torso, "Seam", V(0.12, 2.95, 1.14), CF(0, 3.45, 0), pal)
		for _, s in { -1, 1 } do
			local top = V(s * 0.56, 3.92, 0)
			local head = limb(m, torso, "Head", V(1.0, 0.95, 0.95), CF(top + V(0, 0.48, -0.05)), top, "Head", s, H)
			local lit = s < 0
			local mask = make(m, head, "Mask", V(0.78, 0.62, 0.06), CF(top + V(-s * 0.04, 0.5, -0.54)), if lit then pal.Glow else pal.Plate, Enum.Material.Neon)
			mask.Transparency = 0.1
			for _, x in { -0.18, 0.18 } do
				make(m, head, "EyeSlit", V(0.22, 0.08, 0.05), CF(top + V(-s * 0.04 + x, 0.6, -0.58)), H2)
			end
			make(m, head, "MouthSlit", V(0.3, 0.06, 0.05), CF(top + V(-s * 0.04, 0.36, -0.58)), H2)
			limb(m, head, "Jaw", V(0.6, 0.16, 0.5), CF(top + V(0, 0.06, -0.2)), top + V(0, 0.1, 0.05), "Jaw", 1, H2)
			plate(m, torso, "Shoulder", V(0.45, 0.28, 0.8), CF(s * 1.25, 3.85, 0), pal)
			local hand = V(s * 1.42, 1.75, -0.08)
			local p = arm(m, torso, V(s * 1.3, 3.7, 0), V(s * 1.42, 2.75, 0.02), hand, 0.34, H, H)
			plate(m, p, "Cuff", V(0.4, 0.14, 0.4), CF(hand + V(0, 0.18, 0)), pal)
			make(m, p, "Hand", V(0.36, 0.3, 0.36), CF(hand + V(0, -0.1, 0)), H2)
			pillar(m, torso, s * 0.85, 2.2, 0, 0.36, H, H2, 2)
			pillar(m, torso, s * 0.32, 2.2, 0, 0.36, H, H2, 2, -s)
		end
		for i = 0, 2 do
			plate(m, torso, "Shard", V(0.14, 0.42, 0.3), CF(0.55 + i * 0.25, 3.8 - i * 0.25, 0.6) * A(rad(30), 0, rad(-20)), pal)
		end
	end

	-- Lumeballoon: a pale balloon of a head floating on a thin neck, a
	-- smiling mask of its element's light, thin limbs trailing to the ground
	-- tipped in its colour.
	function B.Lumeballoon(m, pal, H, H2)
		local r = root(m, V(1.2, 1.2, 1.2), 2.4)
		local balloon = limb(m, r, "Balloon", V(2.0, 2.0, 2.0), CF(0, 3.3, 0), V(0, 2.4, 0), "Body", 1, H)
		balloon.Shape = Enum.PartType.Ball
		h.disc(m, balloon, "Seam", 2.06, 0.1, CF(0, 3.3, 0) * A(rad(90), 0, 0), H2)
		h.disc(m, balloon, "Knot", 0.5, 0.2, CF(0, 2.28, 0), H2)
		for _, s in { -1, 1 } do
			glow(m, balloon, "Eye", V(0.22, 0.08, 0.06), CF(s * 0.32, 3.6, -0.96) * A(0, 0, rad(s * 15)), pal)
			glow(m, balloon, "Smile", V(0.2, 0.08, 0.06), CF(s * 0.28, 3.05, -0.97) * A(0, 0, rad(-s * 30)), pal)
		end
		glow(m, balloon, "Smile", V(0.32, 0.08, 0.06), CF(0, 2.98, -0.98), pal)
		limb(m, balloon, "Jaw", V(0.5, 0.12, 0.2), CF(0, 2.86, -0.88), V(0, 2.92, -0.78), "Jaw", 1, H2)
		local neck = beam(m, balloon, "Neck", V(0, 2.25, 0), V(0, 1.85, 0), 0.14, 0.14, H2)
		make(m, neck, "Basket", V(0.5, 0.26, 0.5), CF(0, 1.75, 0), H)
		for i, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			local hip = V(c[1] * 0.18, 1.7, c[2] * 0.18)
			local knee = V(c[1] * 0.5, 0.95, c[2] * 0.45)
			local tip = V(c[1] * 0.42, 0.1, c[2] * 0.65)
			local p = h.spindle(m, neck, hip, knee, tip, 0.08, H, H, c[1] * c[2])
			plate(m, p, "Hand", V(0.16, 0.12, 0.16), CF(tip + V(0, -0.02, 0)), pal)
		end
	end

	return B
end

return Half
