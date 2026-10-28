--[[
	Bodies for the rest of the roster, first half: Prisma, Clawtide and
	kinds 31 to 60 (Shared.KaijuShapesMore hands in the helpers and merges
	these in). Each faces -Z and stands on the ground at the origin, after
	its concept render (docs/kaiju-concepts/kaiju-<name>.png).
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

	-- Prisma: a floating octahedron of blue glass, a cube of its element's
	-- light turning in it, a band round its middle that tilts as it speaks
	-- (its jaw), and a ring of small cubes orbiting it in two halves (its
	-- wings).
	function B.Prisma(m, pal, H, H2)
		local r = root(m, V(1.4, 1.4, 1.4), 1.6)
		local mid = CF(0, 1.62, 0)
		local core = limb(m, r, "Core", V(0.8, 0.8, 0.8), mid * A(rad(35), rad(45), 0), V(0, 1.62, 0), "Body", 1, pal.Glow)
		core.Material = Enum.Material.Neon
		make(m, core, "InnerCore", V(0.5, 0.5, 0.5), mid * A(rad(-20), rad(10), rad(30)), pal.Plate, Enum.Material.Neon)
		local diamond = mid * A(0, rad(45), 0)
		h.pyramid(m, core, "Facet", diamond, 2.1, 1.5, H, false, Enum.Material.Glass)
		h.pyramid(m, core, "Facet", diamond, 2.1, 1.5, H, true, Enum.Material.Glass)
		for _, part in m:GetChildren() do
			if part.Name == "Facet" then
				part.Transparency = 0.3
			end
		end
		make(m, core, "Girdle", V(1.55, 0.08, 1.55), diamond, H2)
		make(m, core, "Girdle", V(1.1, 0.06, 1.1), diamond * CF(0, 0.75, 0), H2)
		-- The band round its middle.
		local band = limb(m, core, "Band", V(2.3, 0.1, 0.12), mid * CF(0, 0, -1.15), V(0, 1.62, 0), "Jaw", 1, pal.Plate)
		plate(m, band, "Band", V(2.3, 0.1, 0.12), mid * CF(0, 0, 1.15), pal)
		plate(m, band, "Band", V(0.12, 0.1, 2.3), mid * CF(-1.15, 0, 0), pal)
		plate(m, band, "Band", V(0.12, 0.1, 2.3), mid * CF(1.15, 0, 0), pal)
		-- The orbiting ring.
		for _, side in { -1, 1 } do
			local at = V(side * 1.75, 1.62, 0)
			local wing = limb(m, core, "Orbit", V(0.2, 0.2, 0.2), CF(at) * A(rad(45), rad(45), 0), V(side * 0.6, 1.62, 0), "Wing", side, pal.Plate)
			for i = 1, 6 do
				local a = rad(i * 25.7 - 77) -- round its side of the ring
				local spot = V(side * math.cos(a) * 1.75, 1.62 + math.sin(i * 1.7) * 0.06, math.sin(a) * 1.75)
				local s = 0.1 + (i % 3) * 0.04
				local cube = make(m, wing, "Orbit", V(s, s, s), CF(spot) * A(rad(i * 30), rad(i * 20), 0), if i % 2 == 0 then pal.Glow else H2)
				if i % 2 == 0 then
					cube.Material = Enum.Material.Neon
				end
			end
		end
	end

	-- Clawtide: a red lobster, a great crusher claw and a slimmer cutter,
	-- a fanned tail, antennae up, six walking legs.
	function B.Clawtide(m, pal, H, H2)
		local r = root(m, V(1.6, 1.0, 2.0), 1.2)
		local body = limb(m, r, "Carapace", V(1.4, 0.9, 1.7), CF(0, 1.35, -0.2), V(0, 1.1, 0.3), "Body", 1, H)
		make(m, body, "Back", V(1.15, 0.3, 1.5), CF(0, 1.9, -0.2), H2)
		for i = 0, 2 do
			plate(m, body, "Ridge", V(0.9 - i * 0.15, 0.12, 0.22), CF(0, 2.08, -0.75 + i * 0.5), pal)
		end
		local head = make(m, body, "Head", V(0.9, 0.7, 0.8), CF(0, 1.45, -1.35), H)
		wedge(m, head, "Rostrum", V(0.24, 0.3, 0.6), CF(0, 1.78, -1.85) * A(0, math.pi, 0), H2)
		eyes(m, head, 0.3, 1.62, -1.78, V(0.16, 0.16, 0.12), pal)
		limb(m, head, "Jaw", V(0.6, 0.2, 0.4), CF(0, 1.02, -1.6), V(0, 1.1, -1.4), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local feeler = beam(m, head, "Antenna", V(s * 0.2, 1.75, -1.6), V(s * 0.55, 3.0, -1.35), 0.09, 0.09, H)
			beam(m, feeler, "Antenna", V(s * 0.55, 3.0, -1.35), V(s * 0.75, 3.55, -0.75), 0.06, 0.06, H2)
		end
		-- The abdomen and its fan.
		local fan = tail(
			m,
			body,
			{ V(0, 1.35, 0.55), V(0, 1.4, 1.3), V(0, 1.3, 2.0), V(0, 1.15, 2.6), V(0, 0.95, 3.1) },
			{ 1.1, 0.95, 0.8, 0.65 },
			H,
			function(seg, i, at, w)
				make(m, seg, "Band", V(w + 0.06, 0.12, 0.3), CF(at + V(0, w * 0.42, 0)), H2)
			end
		)
		for i = -1, 1 do
			plate(m, fan, "Fan", V(0.42, 0.1, 0.62), CF(i * 0.36, 0.92, 3.4) * A(0, rad(i * 22), 0), pal)
		end
		-- The claws: a crusher on the left, a cutter on the right.
		for _, s in { -1, 1 } do
			local big = s < 0
			local w = if big then 0.42 else 0.32
			local hand = V(s * 1.25, 1.15, -2.35)
			local p = arm(m, body, V(s * 0.62, 1.3, -0.95), V(s * 1.35, 1.25, -1.5), hand, w, H, H2)
			local size = if big then V(1.05, 0.72, 1.2) else V(0.62, 0.46, 1.1)
			make(m, p, "Claw", size, CF(hand + V(0, 0, -0.35)), H)
			make(m, p, "Pincer", V(size.X * 0.55, size.Y * 0.4, size.Z * 0.9), CF(hand + V(s * 0.12, size.Y * 0.2, -0.35 - size.Z * 0.85)), H)
			make(m, p, "Pincer", V(size.X * 0.4, size.Y * 0.32, size.Z * 0.7), CF(hand + V(-s * 0.12, -size.Y * 0.25, -0.3 - size.Z * 0.75)), H2)
		end
		for i, z in { -0.65, -0.15, 0.35 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				h.spindle(m, body, V(s * 0.6, 1.05, z), V(s * 1.3, 1.0, z + 0.05), V(s * 1.55, 0.04, z + 0.15), 0.14, H, H2, step)
			end
		end
	end

	-- Tuskmound: a woolly mammoth, shaggy brown, a humped back crusted in
	-- its element's colour, glowing tusks curving up, its trunk (its jaw)
	-- raised when it roars.
	function B.Tuskmound(m, pal, H, H2)
		local r = root(m, V(2.0, 1.6, 2.4), 1.9)
		local body = limb(m, r, "Body", V(2.2, 1.9, 3.0), CF(0, 2.5, 0.2), V(0, 2.0, 0.2), "Body", 1, H)
		make(m, body, "Hump", V(1.8, 0.75, 1.7), CF(0, 3.65, -0.35), H)
		wedge(m, body, "Back", V(1.9, 0.6, 1.4), CF(0, 3.55, 1.0), H)
		for _, s in { -1, 1 } do
			make(m, body, "Shag", V(0.22, 1.0, 2.7), CF(s * 1.15, 1.8, 0.2), H2)
			make(m, body, "Shag", V(0.2, 0.6, 1.2), CF(s * 1.12, 3.1, -0.4), H2)
		end
		make(m, body, "Shag", V(1.9, 0.5, 0.2), CF(0, 1.75, -1.32), H2)
		for i = 0, 3 do
			plate(m, body, "Crust", V(0.5 - i * 0.05, 0.22, 0.45), CF(0, 4.07 - i * 0.12, -0.8 + i * 0.45) * A(0, rad(45), 0), pal)
		end
		local head = make(m, body, "Head", V(1.3, 1.3, 1.0), CF(0, 2.95, -1.7), H)
		make(m, head, "Dome", V(1.1, 0.5, 0.8), CF(0, 3.75, -1.6), H2)
		eyes(m, head, 0.5, 3.15, -2.22, V(0.12, 0.1, 0.06), pal)
		for _, s in { -1, 1 } do
			make(m, head, "Ear", V(0.16, 0.8, 0.6), CF(s * 0.72, 2.95, -1.45) * A(0, rad(s * 15), 0), H2)
			local base = V(s * 0.45, 2.45, -2.1)
			local bend = V(s * 0.62, 1.55, -2.65)
			local tip = V(s * 0.42, 1.95, -3.2)
			litBeam(m, head, "Tusk", base, bend, 0.22, pal)
			litBeam(m, head, "Tusk", bend, tip, 0.17, pal)
		end
		-- The trunk.
		local trunk = h.beam(m, head, "Trunk", V(0, 2.55, -2.25), V(0, 1.6, -2.45), 0.42, 0.42, H, "Jaw")
		beam(m, trunk, "Trunk", V(0, 1.6, -2.45), V(0, 0.95, -2.35), 0.32, 0.32, H)
		beam(m, trunk, "TrunkTip", V(0, 0.95, -2.35), V(0, 0.75, -2.0), 0.26, 0.26, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			pillar(m, body, spot[1] * 0.68, 1.65, if spot[2] < 0 then -0.85 else 1.2, 0.72, H, H2, 3, -spot[1] * spot[2])
		end
		tail(m, body, { V(0, 2.6, 1.7), V(0, 2.1, 2.05), V(0, 1.7, 2.15) }, { 0.22, 0.16 }, H2)
	end

	-- Steamhide: a skinless red giant, all muscle blocks, a lipless grin,
	-- vents of its element's colour on its shoulders and back breathing
	-- light.
	function B.Steamhide(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.4), 2.6)
		local torso = limb(m, r, "Torso", V(2.0, 1.9, 1.15), CF(0, 3.45, 0), V(0, 2.45, 0), "Body", 1, H)
		make(m, torso, "Waist", V(1.5, 0.55, 1.0), CF(0, 2.4, 0), H)
		make(m, torso, "Hips", V(1.6, 0.45, 1.05), CF(0, 2.08, 0.02), H2)
		make(m, torso, "Traps", V(1.3, 0.35, 0.8), CF(0, 4.48, 0.12), H)
		for _, s in { -1, 1 } do
			make(m, torso, "Pec", V(0.86, 0.55, 0.16), CF(s * 0.45, 4.0, -0.6), H2)
			for row = 0, 2 do
				make(m, torso, "Abs", V(0.4, 0.3, 0.12), CF(s * 0.22, 3.4 - row * 0.36, -0.6), H2)
			end
			make(m, torso, "Lat", V(0.18, 1.1, 0.8), CF(s * 1.05, 3.45, 0.05), H2)
			make(m, torso, "Delt", V(0.72, 0.62, 0.85), CF(s * 1.2, 4.2, 0), H2)
			-- The stacks on its shoulders, breathing light.
			plate(m, torso, "Vent", V(0.38, 0.42, 0.38), CF(s * 0.52, 4.75, 0.45), pal)
			plate(m, torso, "Vent", V(0.3, 0.22, 0.3), CF(s * 0.52, 5.06, 0.45), pal)
			for i, d in { 0.32, 0.44 } do
				local puff = h.ball(m, torso, "Steam", d, V(s * (0.52 + i * 0.06), 5.08 + i * 0.26, 0.45 + i * 0.05), pal.Glow, Enum.Material.Neon)
				puff.Transparency, puff.CastShadow = 0.45, false
			end
			plate(m, torso, "Vent", V(0.3, 0.22, 0.3), CF(s * 0.3, 3.7, 0.6), pal)
		end
		local head = make(m, torso, "Head", V(0.78, 0.85, 0.78), CF(0, 4.98, -0.12), H)
		make(m, head, "Brow", V(0.82, 0.18, 0.22), CF(0, 5.22, -0.46), H2)
		eyes(m, head, 0.18, 5.08, -0.52, V(0.15, 0.08, 0.06), pal)
		make(m, head, "Teeth", V(0.54, 0.08, 0.05), CF(0, 4.78, -0.52), CLAW)
		local jaw = limb(m, head, "Jaw", V(0.62, 0.22, 0.5), CF(0, 4.54, -0.25), V(0, 4.64, -0.02), "Jaw", 1, H2)
		make(m, jaw, "Teeth", V(0.5, 0.07, 0.05), CF(0, 4.67, -0.51), CLAW)
		for _, s in { -1, 1 } do
			local hand = V(s * 1.42, 2.3, -0.1)
			local p = arm(m, torso, V(s * 1.28, 4.15, 0), V(s * 1.45, 3.2, 0.05), hand, 0.62, H, H2)
			make(m, p, "Bicep", V(0.7, 0.62, 0.72), CF(s * 1.37, 3.65, -0.04), H)
			make(m, p, "Bracer", V(0.66, 0.55, 0.66), CF(s * 1.44, 2.82, -0.03), H2)
			make(m, p, "Fist", V(0.6, 0.56, 0.62), CF(hand + V(0, -0.2, 0)), H2)
			local l = leg(m, torso, s * 0.48, 2.05, 0.05, 0.7, H, H2, 3, 0.12)
			make(m, l, "Knee", V(0.58, 0.4, 0.24), CF(s * 0.51, 1.07, -0.38), H2)
		end
	end

	-- Hillback: a walking hillside, a mossy slab of a back cracked through
	-- with its element's light, boulders and crystals on it, grey stone
	-- legs and a short stone snout.
	function B.Hillback(m, pal, H, H2)
		local r = root(m, V(2.4, 1.4, 2.6), 1.5)
		local body = limb(m, r, "Slab", V(3.0, 0.9, 3.4), CF(0, 1.95, 0.1), V(0, 1.6, 0.1), "Body", 1, H)
		make(m, body, "Skirt", V(3.2, 0.4, 3.6), CF(0, 1.45, 0.1), H)
		for _, q in { { -1, -1, 0.1 }, { 1, -1, 0 }, { -1, 1, -0.05 }, { 1, 1, 0.08 } } do
			make(m, body, "Turf", V(1.42, 0.35, 1.62), CF(q[1] * 0.74, 2.55 + q[3], 0.1 + q[2] * 0.83) * A(rad(q[3] * 20), 0, rad(-q[3] * 25)), H)
		end
		glow(m, body, "Crack", V(0.12, 0.3, 3.1), CF(0, 2.5, 0.1), pal)
		glow(m, body, "Crack", V(2.9, 0.3, 0.12), CF(0, 2.5, 0.1), pal)
		glow(m, body, "Crack", V(0.1, 0.28, 1.1), CF(0.4, 2.5, -0.4) * A(0, rad(50), 0), pal)
		plate(m, body, "Heart", V(0.42, 0.42, 0.42), CF(0, 2.55, 0.1) * A(rad(45), rad(45), 0), pal)
		for _, b in { { -0.9, 2.95, -0.8, 0.5 }, { 0.95, 2.95, 0.9, 0.42 }, { -0.75, 2.95, 1.1, 0.34 } } do
			make(m, body, "Boulder", V(b[4], b[4] * 0.8, b[4]), CF(b[1], b[2], b[3]) * A(rad(10), rad(30), 0), H2)
		end
		for _, c in { { 1.0, -1.0 }, { -1.15, 0.35 }, { 0.6, 1.35 } } do
			plate(m, body, "Crystal", V(0.2, 0.5, 0.2), CF(c[1], 3.0, c[2]) * A(rad(15), 0, rad(-12)), pal)
		end
		local head = make(m, body, "Head", V(1.0, 0.8, 0.9), CF(0, 1.5, -1.95), H2)
		make(m, head, "Snout", V(0.8, 0.55, 0.5), CF(0, 1.38, -2.6), H2)
		make(m, head, "Moss", V(1.05, 0.2, 0.7), CF(0, 1.98, -1.95), H)
		eyes(m, head, 0.36, 1.68, -2.42, V(0.14, 0.1, 0.06), pal)
		limb(m, head, "Jaw", V(0.72, 0.2, 0.6), CF(0, 1.02, -2.3), V(0, 1.12, -1.95), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			pillar(m, body, spot[1] * 1.05, 1.35, if spot[2] < 0 then -1.0 else 1.2, 0.8, H2, H2, 2, -spot[1] * spot[2])
		end
		tail(m, body, { V(0, 1.6, 1.85), V(0, 1.2, 2.45) }, { 0.6 }, H2)
	end

	-- Inkwrap: a boxy purple octopus, a domed mantle, two great lamp eyes,
	-- eight thick tentacles (its legs) lined in its element's light.
	function B.Inkwrap(m, pal, H, H2)
		local r = root(m, V(1.6, 1.6, 1.6), 2.0)
		local body = limb(m, r, "Mantle", V(1.8, 1.6, 1.7), CF(0, 2.85, 0.1), V(0, 2.1, 0.1), "Body", 1, H)
		make(m, body, "Dome", V(1.45, 0.6, 1.35), CF(0, 3.9, 0.15), H)
		make(m, body, "Crown", V(0.95, 0.35, 0.85), CF(0, 4.36, 0.2), H2)
		make(m, body, "Skirt", V(1.95, 0.45, 1.85), CF(0, 2.0, 0.1), H2)
		for _, s in { -1, 1 } do
			make(m, body, "EyeFrame", V(0.6, 0.66, 0.1), CF(s * 0.45, 2.95, -0.76), H2)
			glow(m, body, "Eye", V(0.44, 0.5, 0.1), CF(s * 0.45, 2.95, -0.8), pal)
			make(m, body, "Pupil", V(0.1, 0.34, 0.06), CF(s * 0.45, 2.95, -0.86), H2)
		end
		limb(m, body, "Beak", V(0.42, 0.3, 0.42), CF(0, 1.72, -0.35), V(0, 1.9, -0.2), "Jaw", 1, H2)
		for i = 0, 7 do
			local a = rad(i * 45 + 22.5)
			local out = V(math.sin(a), 0, -math.cos(a))
			local side = if i % 2 == 0 then 1 else -1
			local hip = V(0, 1.9, 0.1) + out * 0.7
			local knee = V(0, 1.0, 0.1) + out * 1.55
			local tip = V(0, 0.16, 0.1) + out * 1.95
			local p = h.spindle(m, body, hip, knee, tip, 0.36, H, H, side)
			plate(m, p, "Band", V(0.42, 0.12, 0.42), CF((hip + knee) / 2) * A(0, -a, 0), pal)
			litBeam(m, p, "Line", knee + V(0, 0.05, 0), tip + out * -0.05 + V(0, 0.1, 0), 0.08, pal)
			make(m, p, "Curl", V(0.24, 0.16, 0.34), CF(tip + out * 0.12 + V(0, -0.04, 0)) * A(0, -a, 0), H2)
		end
	end

	-- Nullplate: a long, low armoured lizard on six legs, its back laid with
	-- overlapping plates seamed in light, a spiked tail.
	function B.Nullplate(m, pal, H, H2)
		local r = root(m, V(1.6, 1.0, 2.4), 1.25)
		local body = limb(m, r, "Body", V(1.5, 0.95, 3.2), CF(0, 1.32, 0.1), V(0, 1.12, 0.1), "Body", 1, H)
		for i = 0, 4 do
			local z = -1.25 + i * 0.64
			make(m, body, "Plate", V(1.66, 0.3, 0.7), CF(0, 1.88, z) * A(rad(-8), 0, 0), H2)
			plate(m, body, "Spine", V(0.18, 0.42, 0.42), CF(0, 2.18, z) * A(rad(45), 0, 0), pal)
			if i < 4 then
				glow(m, body, "Seam", V(1.7, 0.07, 0.08), CF(0, 2.0, z + 0.33), pal)
			end
		end
		local head = make(m, body, "Head", V(0.85, 0.6, 1.0), CF(0, 1.4, -1.85), H)
		make(m, head, "Snout", V(0.62, 0.42, 0.7), CF(0, 1.3, -2.6), H)
		make(m, head, "Cap", V(0.9, 0.18, 0.95), CF(0, 1.78, -1.9), H2)
		eyes(m, head, 0.43, 1.5, -2.15, V(0.08, 0.1, 0.18), pal)
		limb(m, head, "Jaw", V(0.56, 0.18, 0.95), CF(0, 1.04, -2.4), V(0, 1.12, -1.95), "Jaw", 1, H2)
		for i, z in { -0.95, 0.15, 1.2 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				local p = h.spindle(m, body, V(s * 0.7, 1.05, z), V(s * 1.15, 0.72, z - 0.1), V(s * 1.18, 0.16, z), 0.32, H, H2, step)
				make(m, p, "Foot", V(0.4, 0.16, 0.5), CF(s * 1.18, 0.08, z - 0.12), H2)
			end
		end
		tail(
			m,
			body,
			{ V(0, 1.4, 1.65), V(0, 1.45, 2.45), V(0, 1.7, 3.15), V(0, 2.1, 3.65), V(0, 2.5, 3.85) },
			{ 0.78, 0.6, 0.45, 0.32 },
			H,
			function(seg, i, at, w)
				wedge(m, seg, "TailSpike", V(0.12, 0.38, 0.4), CF(at + V(0, w * 0.6, 0)), H2)
			end
		)
	end

	-- Crestbull: an upright brown dinosaur with a bull's shoulders, two long
	-- brow horns tipped in light and a horn on its nose, a thick tail.
	function B.Crestbull(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.6), 2.2)
		local lean = CF(0, 2.75, 0.15) * A(rad(-10), 0, 0)
		local torso = limb(m, r, "Torso", V(1.7, 2.0, 1.4), lean, V(0, 1.8, 0.2), "Body", 1, H)
		make(m, torso, "Shoulders", V(2.05, 0.65, 1.25), CF(0, 3.72, 0.05), H)
		make(m, torso, "Belly", V(1.15, 1.4, 0.18), lean * CF(0, -0.15, -0.74), H2)
		local head = make(m, torso, "Head", V(0.95, 0.85, 1.1), CF(0, 4.05, -0.65), H)
		make(m, head, "Snout", V(0.75, 0.55, 0.6), CF(0, 3.86, -1.4), H2)
		wedge(m, head, "NoseHorn", V(0.18, 0.36, 0.32), CF(0, 4.3, -1.5) * A(0, math.pi, 0), pal.Plate)
		eyes(m, head, 0.42, 4.15, -1.12, V(0.08, 0.1, 0.14), pal)
		for _, s in { -1, 1 } do
			local base, bend, tip = V(s * 0.35, 4.42, -0.65), V(s * 0.78, 4.92, -1.05), V(s * 0.62, 5.25, -1.55)
			beam(m, head, "Horn", base, bend, 0.2, 0.2, pal.Plate)
			litBeam(m, head, "HornTip", bend, tip, 0.14, pal)
			make(m, head, "Ear", V(0.14, 0.3, 0.26), CF(s * 0.52, 4.2, -0.35), H2)
		end
		limb(m, head, "Jaw", V(0.7, 0.22, 0.75), CF(0, 3.55, -1.25), V(0, 3.65, -0.8), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 1.0, 2.6, -1.0)
			local p = arm(m, torso, V(s * 0.95, 3.4, -0.3), V(s * 1.15, 2.95, -0.7), hand, 0.4, H, H2)
			h.talons(m, p, hand, 2, 0.32, CLAW)
			leg(m, torso, s * 0.6, 1.8, 0.35, 0.7, H, H2, 3)
		end
		tail(
			m,
			torso,
			{ V(0, 1.95, 0.9), V(0, 1.45, 1.7), V(0, 1.0, 2.4), V(0, 0.65, 3.0), V(0, 0.45, 3.5) },
			{ 0.85, 0.7, 0.55, 0.4 },
			H,
			function(seg, i, at, w)
				if i <= 2 then
					plate(m, seg, "TailPlate", V(0.2, 0.2, 0.4), CF(at + V(0, w * 0.5, 0)), pal)
				end
			end
		)
	end


	-- Rubbleking: a hunched golem of stacked sand-coloured stone, its small
	-- head sunk between huge shoulders under a crest of spikes lit in its
	-- element's colour, long arms ending in boulder fists by the ground,
	-- short thick legs.
	function B.Rubbleking(m, pal, H, H2)
		local r = root(m, V(2.2, 1.8, 2.0), 2.0)
		local lean = CF(0, 3.0, 0.1) * A(rad(-10), 0, 0)
		local torso = limb(m, r, "Torso", V(2.8, 2.2, 2.0), lean, V(0, 1.9, 0.2), "Body", 1, H)
		make(m, torso, "Pelvis", V(1.9, 0.7, 1.5), CF(0, 1.85, 0.25), H2)
		for i = 0, 3 do
			make(m, torso, "Ridge", V(2.6 - i * 0.12, 0.26, 0.3), lean * CF(0, -0.8 + i * 0.48, -1.0), H2)
		end
		make(m, torso, "Hump", V(2.2, 0.6, 1.4), CF(0, 4.2, 0.4), H)
		for _, s in { -1, 1 } do
			make(m, torso, "Shoulder", V(1.2, 1.1, 1.3), CF(s * 1.5, 3.75, 0.1) * A(0, 0, rad(s * -8)), H)
			make(m, torso, "Stone", V(0.7, 0.5, 0.8), CF(s * 0.9, 2.55, 0.85) * A(rad(10), rad(s * 15), 0), H2)
		end
		local head = make(m, torso, "Head", V(0.8, 0.7, 0.75), CF(0, 3.95, -0.85), H)
		make(m, head, "Brow", V(0.86, 0.16, 0.2), CF(0, 4.18, -1.18), H2)
		eyes(m, head, 0.2, 4.02, -1.23, V(0.18, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.66, 0.22, 0.5), CF(0, 3.58, -1.0), V(0, 3.68, -0.8), "Jaw", 1, H2)
		for i = 0, 5 do
			local spike = plate(m, torso, "Crest", V(0.13, 0.48 - math.abs(i - 2) * 0.06, 0.26), CF((i % 2 - 0.5) * 0.14, 4.48 - i * 0.03, -0.75 + i * 0.3) * A(rad(-20), 0, 0), pal)
			spike.Material = Enum.Material.Neon
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 1.95, 1.05, -0.55)
			local p = arm(m, torso, V(s * 1.6, 3.7, -0.05), V(s * 2.0, 2.55, -0.25), hand, 0.9, H, H2)
			make(m, p, "Forearm", V(0.95, 0.85, 0.95), CF(s * 1.98, 1.75, -0.42) * A(rad(-8), 0, 0), H)
			make(m, p, "Boulder", V(1.25, 1.1, 1.25), CF(hand + V(0, -0.35, -0.05)) * A(rad(10), rad(18), rad(6)), H2)
			make(m, p, "Boulder", V(0.7, 0.55, 0.7), CF(hand + V(s * 0.35, 0.1, -0.45)) * A(rad(30), rad(10), 0), H)
			plate(m, p, "Knuckle", V(0.3, 0.3, 0.3), CF(hand + V(0, -0.15, -0.68)) * A(rad(45), rad(45), 0), pal)
			leg(m, torso, s * 0.72, 1.75, 0.35, 0.88, H, H2, 3, 0.12)
		end
	end

	-- Kickjaw: a lean green dinosaur on huge legs, standing tall to kick,
	-- small arms, a long neck and head, its ribs lit with its element's light.
	function B.Kickjaw(m, pal, H, H2)
		local r = root(m, V(1.4, 1.6, 1.4), 2.3)
		local lean = CF(0, 3.0, 0.25) * A(rad(-15), 0, 0)
		local torso = limb(m, r, "Torso", V(1.0, 1.6, 1.0), lean, V(0, 2.2, 0.3), "Body", 1, H)
		make(m, torso, "Belly", V(0.7, 1.2, 0.14), lean * CF(0, -0.1, -0.54), H2)
		for _, s in { -1, 1 } do
			for i = 0, 2 do
				glow(m, torso, "Rib", V(0.05, 0.09, 0.62), lean * CF(s * 0.52, 0.3 - i * 0.3, -0.05) * A(rad(-20), 0, 0), pal)
			end
		end
		local neck = beam(m, torso, "Neck", V(0, 3.65, 0.05), V(0, 4.4, -0.3), 0.5, 0.55, H)
		local head = make(m, neck, "Head", V(0.6, 0.55, 1.0), CF(0, 4.62, -0.65), H)
		make(m, head, "Snout", V(0.45, 0.38, 0.5), CF(0, 4.55, -1.35), H)
		eyes(m, head, 0.31, 4.72, -0.85, V(0.06, 0.1, 0.14), pal)
		limb(m, head, "Jaw", V(0.42, 0.16, 0.85), CF(0, 4.3, -0.95), V(0, 4.38, -0.55), "Jaw", 1, H2)
		for i = 0, 3 do
			plate(m, torso, "Spine", V(0.12, 0.3, 0.3), CF(0, 3.95 - i * 0.42, 0.55 + i * 0.12) * A(rad(45), 0, 0), pal)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 0.55, 2.75, -0.85)
			local p = arm(m, torso, V(s * 0.52, 3.4, -0.3), V(s * 0.62, 3.0, -0.55), hand, 0.22, H, H2)
			h.talons(m, p, hand, 2, 0.2, CLAW)
			local l = leg(m, torso, s * 0.45, 2.3, 0.35, 0.72, H, H2, 3, 0.4)
			make(m, l, "Thigh", V(0.85, 0.9, 1.0), CF(s * 0.5, 1.95, 0.25), H)
		end
		tail(m, torso, { V(0, 2.4, 0.9), V(0, 2.05, 1.7), V(0, 1.65, 2.5), V(0, 1.35, 3.2) }, { 0.55, 0.42, 0.3 }, H)
	end

	-- Ogretoad: a squat, pear-shaped warty toad of an ogre, its wide head one
	-- with its body, a wide mouth, one great eye of its element's light on
	-- top, a pale belly, short arms and legs, hands and toes aglow.
	function B.Ogretoad(m, pal, H, H2)
		local r = root(m, V(2.0, 1.4, 1.8), 1.5)
		-- Its pear of a body in rounded steps, widest at the belly.
		local body = limb(m, r, "Belly", V(2.5, 0.9, 2.1), CF(0, 1.55, 0.1), V(0, 1.2, 0.1), "Body", 1, H)
		make(m, body, "Under", V(1.9, 0.35, 1.6), CF(0, 0.95, 0.15), H)
		make(m, body, "Chest", V(2.2, 0.55, 1.85), CF(0, 2.25, 0.1), H)
		make(m, body, "Neck", V(2.1, 0.3, 1.0), CF(0, 2.65, 0.4), H)
		for _, s in { -1, 1 } do
			make(m, body, "Flank", V(0.2, 0.7, 1.6), CF(s * 1.32, 1.55, 0.15), H)
		end
		make(m, body, "Paunch", V(1.8, 1.1, 0.25), CF(0, 1.62, -1.02), H2)
		local head = make(m, body, "Head", V(2.35, 0.55, 1.95), CF(0, 3.05, -0.05), H)
		make(m, head, "Crown", V(1.7, 0.25, 1.5), CF(0, 3.45, 0.05), H)
		make(m, head, "Lip", V(2.3, 0.07, 0.1), CF(0, 2.79, -1.04), C(40, 44, 36))
		local jaw = limb(m, body, "Jaw", V(2.4, 0.3, 1.0), CF(0, 2.62, -0.55), V(0, 2.72, -0.1), "Jaw", 1, H)
		make(m, jaw, "Chin", V(1.9, 0.12, 0.12), CF(0, 2.5, -1.06), H2)
		-- The great eye.
		make(m, head, "EyeBump", V(0.95, 0.65, 0.85), CF(0, 3.6, -0.4), H)
		glow(m, head, "Eye", V(0.68, 0.5, 0.1), CF(0, 3.62, -0.85), pal)
		make(m, head, "Pupil", V(0.1, 0.42, 0.06), CF(0, 3.62, -0.91), C(28, 30, 26))
		for _, w in { { -0.6, 3.62, 0.5 }, { 0.95, 3.4, 0.3 }, { -1.15, 2.4, 0.65 }, { 1.47, 1.7, 0.8 } } do
			plate(m, body, "Wart", V(0.24, 0.2, 0.24), CF(w[1], w[2], w[3]), pal)
		end
		for _, w in { { -0.95, 3.35, -0.2 }, { 0.95, 3.35, -0.35 }, { 0.2, 3.62, 0.65 }, { -1.45, 1.5, 0.5 }, { 1.2, 2.3, -0.1 }, { -0.4, 2.2, 1.08 } } do
			make(m, body, "Wart", V(0.3, 0.26, 0.3), CF(w[1], w[2], w[3]), H2)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 1.45, 1.15, -0.8)
			local p = arm(m, body, V(s * 1.2, 2.2, -0.2), V(s * 1.5, 1.65, -0.5), hand, 0.48, H, H2)
			glow(m, p, "Hand", V(0.5, 0.3, 0.5), CF(hand + V(0, -0.12, -0.05)), pal)
			for i = -1, 1 do
				glow(m, p, "Claw", V(0.12, 0.3, 0.12), CF(hand + V(i * 0.17, -0.34, -0.25)) * A(rad(-35), 0, 0), pal)
			end
			local l = leg(m, body, s * 0.85, 1.15, 0.3, 0.72, H, H2, 0, 0.12)
			for i = -1, 1 do
				glow(m, l, "Toe", V(0.16, 0.14, 0.24), CF(s * 0.9 + i * 0.22, 0.07, -0.42), pal)
			end
		end
	end

	-- Tritail: a tall, slim dark giant with a crown, three long tails raised
	-- behind it like blades, each edged in its element's light.
	function B.Tritail(m, pal, H, H2)
		local r = root(m, V(1.4, 1.8, 1.2), 2.6)
		local lean = CF(0, 3.3, 0.05) * A(rad(-6), 0, 0)
		local torso = limb(m, r, "Torso", V(1.2, 1.8, 0.8), lean, V(0, 2.4, 0.1), "Body", 1, H)
		make(m, torso, "Chest", V(0.85, 0.9, 0.14), lean * CF(0, 0.35, -0.44), H2)
		make(m, torso, "Hips", V(0.95, 0.45, 0.7), CF(0, 2.35, 0.1), H2)
		local head = make(m, torso, "Head", V(0.58, 0.68, 0.66), CF(0, 4.6, -0.1), H)
		eyes(m, head, 0.14, 4.64, -0.44, V(0.12, 0.06, 0.05), pal)
		limb(m, head, "Jaw", V(0.46, 0.16, 0.42), CF(0, 4.26, -0.2), V(0, 4.32, 0.02), "Jaw", 1, H2)
		for i = 0, 3 do
			local a = rad(i * 90 + 45)
			plate(m, head, "Crown", V(0.12, 0.34, 0.12), CF(math.cos(a) * 0.24, 5.08, -0.1 + math.sin(a) * 0.24), pal)
		end
		glow(m, head, "CrownBand", V(0.62, 0.08, 0.7), CF(0, 4.92, -0.1), pal)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.9, 2.25, -0.25)
			local p = arm(m, torso, V(s * 0.74, 4.0, 0), V(s * 0.95, 3.1, -0.1), hand, 0.3, H, H2)
			h.talons(m, p, hand, 3, 0.28, CLAW)
			leg(m, torso, s * 0.34, 2.4, 0.1, 0.42, H, H2, 2, 0.15)
		end
		for _, spec in { { 0, 0 }, { -1, 1 }, { 1, 1 } } do
			local x, out = spec[1], spec[2]
			local points = {
				V(x * 0.15, 2.55, 0.42),
				V(x * 0.55, 3.15, 0.95),
				V(x * (0.95 + out * 0.1), 4.05, 1.2),
				V(x * (1.3 + out * 0.2), 5.0, 1.25),
			}
			tail(m, torso, points, { 0.36, 0.3, 0.22 }, H, function(seg, i, at, w)
				local a, b = points[i], points[i + 1]
				litBeam(m, seg, "Blade", a + V(0, 0, 0.16), b + V(0, 0, 0.16), 0.1, pal)
			end)
		end
	end

	-- Ashcrawler: a hunched, half-molten black reptile cracked with its
	-- element's light, scutes down its back, small arms, a tail longer than
	-- its body.
	function B.Ashcrawler(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 2.0), 1.7)
		local hunch = CF(0, 2.0, 0.2) * A(rad(-12), 0, 0)
		local body = limb(m, r, "Body", V(1.5, 1.4, 2.2), hunch, V(0, 1.5, 0.5), "Body", 1, H)
		for i, c in { { 0.76, 0.1, -0.3, 30 }, { -0.76, -0.2, 0.2, -25 }, { 0.76, -0.25, 0.55, -40 }, { -0.76, 0.2, -0.5, 35 } } do
			glow(m, body, "Crack", V(0.05, 0.08, 0.9), hunch * CF(c[1], c[2], c[3]) * A(rad(c[4]), 0, 0), pal)
		end
		glow(m, body, "Crack", V(0.9, 0.06, 0.06), hunch * CF(0, 0.71, -0.3) * A(0, rad(25), 0), pal)
		for i = 0, 3 do
			plate(m, body, "Scute", V(0.5 - i * 0.05, 0.2, 0.42), hunch * CF(0, 0.78, -0.75 + i * 0.5), pal)
			make(m, body, "Bump", V(0.3, 0.26, 0.3), hunch * CF(0.4 * (if i % 2 == 0 then 1 else -1), 0.72, -0.5 + i * 0.5), H2)
		end
		local head = make(m, body, "Head", V(0.95, 0.8, 1.1), CF(0, 2.55, -1.45), H)
		make(m, head, "Snout", V(0.7, 0.5, 0.55), CF(0, 2.42, -2.2), H2)
		glow(m, head, "Crack", V(0.05, 0.06, 0.8), CF(0.48, 2.6, -1.5), pal)
		eyes(m, head, 0.4, 2.7, -2.0, V(0.12, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.66, 0.2, 0.9), CF(0, 2.08, -1.95), V(0, 2.16, -1.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local hand = V(s * 0.8, 1.25, -1.25)
			local p = arm(m, body, V(s * 0.7, 2.1, -0.8), V(s * 0.85, 1.6, -1.05), hand, 0.28, H, H2)
			h.talons(m, p, hand, 2, 0.24, CLAW)
			leg(m, body, s * 0.6, 1.5, 0.6, 0.6, H, H2, 3, 0.2)
		end
		tail(
			m,
			body,
			{ V(0, 1.8, 1.2), V(0, 1.45, 2.1), V(0, 1.05, 3.0), V(0, 0.72, 3.9), V(0, 0.5, 4.7) },
			{ 0.8, 0.62, 0.46, 0.32 },
			H,
			function(seg, i, at, w)
				glow(m, seg, "Crack", V(0.05, 0.06, 0.7), CF(at + V(w * 0.5, 0, 0)), pal)
			end
		)
	end

	-- Shrieker: a bat-bird hovering on leathery wings edged in its
	-- element's light, a flat triangle of a head, hooked feet hanging.
	function B.Shrieker(m, pal, H, H2)
		local r = root(m, V(1.2, 1.2, 1.2), 1.7)
		local tilt = CF(0, 2.15, 0.1) * A(rad(-20), 0, 0)
		local body = limb(m, r, "Body", V(0.8, 1.3, 0.75), tilt, V(0, 1.6, 0.2), "Body", 1, H)
		make(m, body, "Chest", V(0.6, 0.85, 0.12), tilt * CF(0, 0.05, -0.42), H2)
		local head = make(m, body, "Head", V(0.7, 0.42, 0.62), CF(0, 2.98, -0.28), H)
		wedge(m, head, "Crest", V(1.15, 0.2, 1.0), CF(0, 3.25, -0.05), H2)
		wedge(m, head, "Beak", V(0.32, 0.26, 0.42), CF(0, 2.86, -0.75) * A(0, math.pi, 0), H2)
		eyes(m, head, 0.24, 3.05, -0.6, V(0.14, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.36, 0.12, 0.42), CF(0, 2.7, -0.6), V(0, 2.76, -0.35), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local a, b = V(s * 0.38, 2.5, 0.15), V(s * 1.45, 3.35, 0.2)
			local c, d = V(s * 2.7, 2.35, 0.35), V(s * 1.25, 1.6, 0.35)
			local w = h.batWing(m, body, a, b, c, d, H, H2)
			litBeam(m, w, "WingEdge", b, c, 0.07, pal)
			litBeam(m, w, "WingEdge", c, d, 0.07, pal)
			plate(m, w, "WingClaw", V(0.1, 0.24, 0.1), CF(b + V(0, 0.16, 0)), pal)
			plate(m, head, "Ear", V(0.1, 0.24, 0.16), CF(s * 0.3, 3.4, 0.1) * A(rad(-20), 0, rad(-s * 15)), pal)
			local l = beam(m, body, "Leg", V(s * 0.24, 1.6, 0.25), V(s * 0.3, 0.42, 0.2), 0.16, 0.18, H2, "Stride", s)
			for i = -1, 1 do
				beam(m, l, "Talon", V(s * 0.3 + i * 0.08, 0.42, 0.2), V(s * 0.3 + i * 0.1, 0.06, 0.02), 0.06, 0.08, CLAW)
			end
		end
		tail(m, body, { V(0, 1.6, 0.55), V(0, 1.25, 1.05), V(0, 1.05, 1.45) }, { 0.22, 0.15 }, H)
	end

	-- Tonguefrost: a pale, low lizard, a spiked back, a long horn of its
	-- element's light jutting from its snout and a tongue it shoots like a
	-- whip.
	function B.Tonguefrost(m, pal, H, H2)
		local r = root(m, V(1.6, 1.2, 2.2), 1.5)
		local body = limb(m, r, "Body", V(1.5, 1.2, 2.6), CF(0, 1.75, 0.2), V(0, 1.4, 0.2), "Body", 1, H)
		make(m, body, "Belly", V(1.2, 0.2, 2.2), CF(0, 1.12, 0.2), H2)
		for i = 0, 4 do
			local z = -0.85 + i * 0.45
			make(m, body, "Spike", V(0.36, 0.42, 0.36), CF(0, 2.5, z) * A(0, rad(45), 0), H2)
			if i % 2 == 0 then
				plate(m, body, "Spike", V(0.2, 0.34, 0.2), CF(0.42, 2.4, z + 0.2) * A(0, rad(45), rad(-15)), pal)
				plate(m, body, "Spike", V(0.2, 0.34, 0.2), CF(-0.42, 2.4, z + 0.2) * A(0, rad(45), rad(15)), pal)
			end
		end
		local head = make(m, body, "Head", V(0.95, 0.75, 1.0), CF(0, 1.92, -1.5), H)
		make(m, head, "Snout", V(0.7, 0.5, 0.6), CF(0, 1.8, -2.2), H2)
		litBeam(m, head, "Horn", V(0, 2.1, -2.2), V(0, 2.6, -2.95), 0.22, pal)
		litBeam(m, head, "Horn", V(0, 2.6, -2.95), V(0, 2.95, -3.2), 0.15, pal)
		eyes(m, head, 0.43, 2.06, -1.75, V(0.08, 0.1, 0.16), pal)
		local jaw = limb(m, head, "Jaw", V(0.62, 0.18, 0.85), CF(0, 1.45, -2.0), V(0, 1.52, -1.6), "Jaw", 1, H2)
		litBeam(m, jaw, "Tongue", V(0, 1.5, -2.35), V(0, 1.2, -2.95), 0.12, pal)
		litBeam(m, jaw, "Tongue", V(0, 1.2, -2.95), V(0, 1.4, -3.4), 0.1, pal)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			leg(m, body, spot[1] * 0.62, 1.35, if spot[2] < 0 then -0.8 else 1.1, 0.48, H, H2, 3, 0.18, -spot[1] * spot[2])
		end
		tail(m, body, { V(0, 1.75, 1.45), V(0, 1.45, 2.2), V(0, 1.15, 2.85), V(0, 0.9, 3.35) }, { 0.6, 0.45, 0.3 }, H)
	end

	-- Glidespine: a dark green lizard with a row of spines in its element's
	-- colour, skin flaps (its wings) between its legs edged in its light.
	function B.Glidespine(m, pal, H, H2)
		local r = root(m, V(1.6, 1.2, 2.2), 1.5)
		local back = CF(0, 1.7, 0.2) * A(rad(-10), 0, 0)
		local body = limb(m, r, "Body", V(1.3, 1.0, 2.6), back, V(0, 1.4, 0.3), "Body", 1, H)
		make(m, body, "Belly", V(1.0, 0.18, 2.2), back * CF(0, -0.52, 0), H2)
		for i = 0, 6 do
			local hgt = 0.35 + math.sin((i + 0.5) / 7 * math.pi) * 0.25
			plate(m, body, "Spine", V(0.12, hgt, hgt), back * CF(0, 0.55 + hgt * 0.3, -1.05 + i * 0.35) * A(rad(45), 0, 0), pal)
		end
		local head = make(m, body, "Head", V(0.8, 0.65, 1.0), CF(0, 2.15, -1.45), H)
		make(m, head, "Snout", V(0.6, 0.42, 0.55), CF(0, 2.05, -2.15), H2)
		eyes(m, head, 0.36, 2.25, -1.85, V(0.1, 0.08, 0.06), pal)
		limb(m, head, "Jaw", V(0.55, 0.16, 0.85), CF(0, 1.72, -1.9), V(0, 1.8, -1.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local a, b = V(s * 0.6, 1.75, -0.75), V(s * 1.85, 1.15, -0.35)
			local c, d = V(s * 1.7, 1.05, 0.95), V(s * 0.6, 1.6, 1.05)
			local flap = limb(m, body, "Flap", V(0.22, 0.22, 0.22), CF(a), a, "Wing", s, H)
			h.triangle(m, flap, "Membrane", a, b, c, 0.06, H2)
			h.triangle(m, flap, "Membrane", a, c, d, 0.06, H2)
			litBeam(m, flap, "FlapEdge", b, c, 0.06, pal)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.85, if spot[2] < 0 then -0.6 else 0.9
			h.spindle(m, body, V(spot[1] * 0.55, 1.35, z), V(x * 1.45, 0.95, z - 0.05), V(x * 1.5, 0.08, z - 0.1), 0.28, H, H2, -spot[1] * spot[2])
		end
		tail(
			m,
			body,
			{ V(0, 1.6, 1.4), V(0, 1.35, 2.2), V(0, 1.05, 2.95), V(0, 0.75, 3.6) },
			{ 0.58, 0.44, 0.3 },
			H,
			function(seg, i, at, w)
				plate(m, seg, "Spine", V(0.1, 0.26, 0.26), CF(at + V(0, w * 0.55, 0)) * A(rad(45), 0, 0), pal)
			end
		)
	end


	-- Fathomweb: a spider-squid, a hood of pale crystal for a head, six long
	-- legs with knees of its element's colour, a banded abdomen dragging
	-- behind.
	function B.Fathomweb(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 1.6), 1.9)
		local body = limb(m, r, "Thorax", V(1.0, 0.8, 1.1), CF(0, 2.0, 0), V(0, 1.9, 0), "Body", 1, H)
		local hood = make(m, body, "Hood", V(1.0, 1.1, 1.0), CF(0, 2.85, -0.35), H2, Enum.Material.Glass)
		hood.Transparency = 0.2
		h.pyramid(m, body, "HoodTip", CF(0, 3.4, -0.35) * A(0, rad(45), 0), 1.42, 0.75, H2, false, Enum.Material.Glass)
		for _, part in m:GetChildren() do
			if part.Name == "HoodTip" then
				part.Transparency = 0.2
			end
		end
		make(m, body, "Face", V(0.7, 0.6, 0.1), CF(0, 2.7, -0.82), H)
		eyes(m, body, 0.16, 2.78, -0.88, V(0.12, 0.12, 0.06), pal)
		glow(m, body, "Core", V(0.35, 0.35, 0.35), CF(0, 3.0, -0.35) * A(rad(45), rad(45), 0), pal)
		limb(m, body, "Mandibles", V(0.5, 0.2, 0.4), CF(0, 2.28, -0.75), V(0, 2.36, -0.55), "Jaw", 1, H)
		for i, z in { -0.45, 0.05, 0.5 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				local hip, knee, tip = V(s * 0.45, 2.0, z), V(s * 1.35, 2.75, z * 1.5), V(s * 1.95, 0.05, z * 1.9)
				local p = h.spindle(m, body, hip, knee, tip, 0.14, H, H, step)
				plate(m, p, "Knee", V(0.22, 0.22, 0.22), CF(knee) * A(rad(45), rad(45), 0), pal)
				glow(m, p, "Tip", V(0.1, 0.16, 0.1), CF(tip + V(0, 0.08, 0)), pal)
			end
		end
		tail(
			m,
			body,
			{ V(0, 1.85, 0.5), V(0, 1.25, 1.25), V(0, 0.78, 2.0), V(0, 0.5, 2.75) },
			{ 0.8, 0.66, 0.5 },
			H,
			function(seg, i, at, w)
				glow(m, seg, "Band", V(w + 0.04, 0.08, 0.1), CF(at), pal)
			end
		)
	end

	-- Spitgill: a grey shark walking on two legs, a pale belly, a great
	-- dorsal fin, gill slits lit with its element's light, a long snout.
	function B.Spitgill(m, pal, H, H2)
		local r = root(m, V(1.6, 1.6, 1.6), 2.1)
		local lean = CF(0, 2.6, 0.1) * A(rad(-20), 0, 0)
		local body = limb(m, r, "Body", V(1.4, 1.8, 1.6), lean, V(0, 1.8, 0.2), "Body", 1, H)
		make(m, body, "Belly", V(1.05, 1.5, 0.2), lean * CF(0, -0.1, -0.82), H2)
		local head = make(m, body, "Head", V(1.0, 0.9, 1.4), CF(0, 3.45, -0.85), H)
		make(m, head, "Snout", V(0.72, 0.55, 0.8), CF(0, 3.5, -1.85), H)
		make(m, head, "Chin", V(0.8, 0.2, 1.4), CF(0, 3.02, -1.25), H2)
		eyes(m, head, 0.5, 3.62, -1.35, V(0.06, 0.12, 0.12), pal)
		local jaw = limb(m, head, "Jaw", V(0.82, 0.24, 1.15), CF(0, 2.82, -1.35), V(0, 2.92, -0.75), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, jaw, "Tooth", V(0.1, 0.12, 0.1), CF(s * 0.3, 2.98, -1.85), CLAW)
			make(m, head, "Tooth", V(0.1, 0.12, 0.1), CF(s * 0.28, 3.18, -1.9), CLAW)
			for i = 0, 2 do
				glow(m, head, "Gill", V(0.06, 0.4, 0.08), CF(s * 0.51, 3.3, -0.35 - i * 0.18) * A(0, 0, rad(-s * 8)), pal)
			end
			local p = arm(m, body, V(s * 0.72, 3.0, -0.45), V(s * 1.2, 2.55, -0.35), V(s * 1.45, 2.15, -0.2), 0.3, H, H)
			wedge(m, p, "Fin", V(0.12, 0.7, 0.55), CF(s * 1.35, 2.3, -0.2) * A(0, 0, rad(s * 30)), H)
			plate(m, p, "FinTip", V(0.1, 0.18, 0.3), CF(s * 1.5, 2.0, -0.18) * A(0, 0, rad(s * 30)), pal)
			leg(m, body, s * 0.5, 1.8, 0.4, 0.6, H, H2, 3, 0.2)
		end
		wedge(m, body, "Dorsal", V(0.2, 1.3, 1.1), CF(0, 4.05, 0.35), H)
		plate(m, body, "DorsalTip", V(0.18, 0.3, 0.3), CF(0, 4.6, 0.75), pal)
		local tip = tail(m, body, { V(0, 2.0, 0.9), V(0, 1.6, 1.65), V(0, 1.35, 2.3) }, { 0.7, 0.5 }, H)
		wedge(m, tip, "Caudal", V(0.14, 0.9, 0.6), CF(0, 1.95, 2.55), H)
		wedge(m, tip, "Caudal", V(0.14, 0.6, 0.5), CF(0, 0.95, 2.5) * A(math.pi, 0, 0), H)
		plate(m, tip, "CaudalTip", V(0.12, 0.25, 0.25), CF(0, 2.38, 2.75), pal)
	end

	-- Duskbat: a black bat crouched on the ground like a gargoyle, its wings
	-- spread wide and high, three long fingers fanning from each wrist with
	-- the skin between them glowing in its element's colour, a hooked thumb
	-- at each wrist, tall ears, a pig's snout and fangs.
	function B.Duskbat(m, pal, H, H2)
		local r = root(m, V(1.2, 1.2, 1.2), 1.4)
		local tilt = CF(0, 1.7, 0.15) * A(rad(-10), 0, 0)
		local body = limb(m, r, "Body", V(1.05, 1.3, 0.9), tilt, V(0, 1.15, 0.2), "Body", 1, H)
		make(m, body, "Chest", V(0.8, 0.85, 0.14), tilt * CF(0, 0.1, -0.5), H2)
		local head = make(m, body, "Head", V(0.85, 0.75, 0.75), CF(0, 2.62, -0.2), H)
		make(m, head, "Snout", V(0.46, 0.34, 0.24), CF(0, 2.5, -0.68), H2)
		for _, s in { -1, 1 } do
			make(m, head, "Nostril", V(0.08, 0.1, 0.04), CF(s * 0.1, 2.52, -0.81), H)
			wedge(m, head, "Ear", V(0.2, 0.95, 0.4), CF(s * 0.27, 3.42, -0.1) * A(0, 0, rad(-s * 8)), H)
			make(m, head, "EarInner", V(0.08, 0.6, 0.06), CF(s * 0.27, 3.3, -0.3) * A(0, 0, rad(-s * 8)), H2)
		end
		eyes(m, head, 0.24, 2.76, -0.58, V(0.16, 0.12, 0.06), pal)
		local jaw = limb(m, head, "Jaw", V(0.48, 0.16, 0.34), CF(0, 2.24, -0.48), V(0, 2.3, -0.25), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, jaw, "Fang", V(0.06, 0.18, 0.06), CF(s * 0.13, 2.38, -0.62), CLAW)
		end
		-- The wings: the arm up to the wrist, three fingers fanned from it,
		-- the skin between them lit.
		for _, s in { -1, 1 } do
			local shoulder, wrist = V(s * 0.45, 2.2, 0.2), V(s * 1.35, 3.3, 0.35)
			local tips = { V(s * 2.65, 3.15, 0.45), V(s * 2.85, 2.2, 0.45), V(s * 2.25, 1.35, 0.45) }
			local root2 = V(s * 0.55, 1.45, 0.3)
			local w = limb(m, body, "Wing", V(0.24, 0.28, 0.28), CF(shoulder), shoulder, "Wing", s, H)
			beam(m, w, "WingArm", shoulder, wrist, 0.18, 0.2, H)
			h.triangle(m, w, "WingSkin", shoulder, wrist, root2, 0.06, pal.Plate)
			local last = wrist
			for i, tip in tips do
				beam(m, w, "WingFinger", wrist, tip, 0.1 - i * 0.01, 0.12, H)
				if i > 1 then
					h.triangle(m, w, "WingSkin", wrist, tips[i - 1], tip, 0.06, pal.Plate)
				end
				last = tip
			end
			h.triangle(m, w, "WingSkin", wrist, last, root2, 0.06, pal.Plate)
			wedge(m, w, "Thumb", V(0.1, 0.3, 0.16), CF(wrist + V(0, 0.22, -0.05)) * A(0, 0, rad(-s * 25)), CLAW)
			leg(m, body, s * 0.38, 1.15, 0.25, 0.4, H, H2, 3, 0.35)
		end
		for _, part in m:GetChildren() do
			if part.Name == "WingSkin" then
				part.Material, part.CastShadow = Enum.Material.Neon, false
			end
		end
	end

	-- Tendrilis: a tall, thin dark thing with a spear for a head, four long
	-- tentacles rising off its back, each tipped in its element's light.
	function B.Tendrilis(m, pal, H, H2)
		local r = root(m, V(1.2, 1.8, 1.0), 2.4)
		local torso = limb(m, r, "Torso", V(0.8, 1.5, 0.6), CF(0, 3.1, 0.05), V(0, 2.35, 0.05), "Body", 1, H)
		make(m, torso, "Hips", V(0.7, 0.4, 0.55), CF(0, 2.3, 0.05), H2)
		local head = make(m, torso, "Head", V(0.45, 0.6, 0.5), CF(0, 4.15, -0.05), H)
		h.pyramid(m, head, "Spear", CF(0, 4.45, -0.05) * A(0, rad(45), 0), 0.5, 0.75, H2)
		glow(m, head, "Eye", V(0.3, 0.06, 0.05), CF(0, 4.22, -0.31), pal)
		limb(m, head, "Jaw", V(0.34, 0.14, 0.3), CF(0, 3.85, -0.12), V(0, 3.9, 0.05), "Jaw", 1, H2)
		for _, spec in { { -1, 0.32, 1.15 }, { -1, 0.12, 0.6 }, { 1, 0.12, 0.6 }, { 1, 0.32, 1.15 } } do
			local s, x0, out = spec[1], spec[2], spec[3]
			local points = {
				V(s * x0, 3.55, 0.3),
				V(s * (x0 + out * 0.45), 4.25, 0.6),
				V(s * (x0 + out * 0.7), 4.9, 0.5),
				V(s * (x0 + out * 0.8), 5.4, 0.35),
			}
			local tip = tail(m, torso, points, { 0.14, 0.11, 0.09 }, H, function(seg, i, at, w)
				if i == 2 then
					plate(m, seg, "Band", V(w + 0.06, 0.08, w + 0.06), CF(at), pal)
				end
			end, "Tendril")
			glow(m, tip, "Tip", V(0.16, 0.26, 0.16), CF(points[4]), pal)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 0.6, 2.15, -0.12)
			local p = arm(m, torso, V(s * 0.5, 3.7, 0), V(s * 0.6, 2.9, 0), hand, 0.18, H, H2)
			h.talons(m, p, hand, 3, 0.26, H2, V(0, -1, -0.2))
			leg(m, torso, s * 0.24, 2.35, 0.05, 0.26, H, H2, 2, 0.12)
		end
	end

	-- Snipclaw: a squat dark brute under a great box of a head, split down
	-- its brow by a seam of its element's colour, slanted eyes and a toothy
	-- grin lit in it, crab claws held out wide, each edged round its outside
	-- with a crescent blade of that light.
	function B.Snipclaw(m, pal, H, H2)
		local function lit(p, name, size, cf)
			return make(m, p, name, size, cf, pal.Plate, Enum.Material.Neon)
		end
		local r = root(m, V(1.6, 1.6, 1.3), 1.9)
		local torso = limb(m, r, "Torso", V(1.6, 1.45, 1.1), CF(0, 2.4, 0.05), V(0, 1.6, 0.05), "Body", 1, H)
		make(m, torso, "Hips", V(1.4, 0.45, 0.95), CF(0, 1.55, 0.05), H2)
		for _, s in { -1, 1 } do
			make(m, torso, "Pec", V(0.72, 0.5, 0.12), CF(s * 0.38, 2.8, -0.54), H2)
			for i = 0, 1 do
				make(m, torso, "Abs", V(0.5, 0.3, 0.1), CF(s * 0.27, 2.3 - i * 0.36, -0.55), H2)
			end
		end
		-- The head: two great lobes either side of the lit seam.
		for _, s in { -1, 1 } do
			make(m, torso, "Lobe", V(0.98, 1.2, 1.35), CF(s * 0.51, 3.75, -0.05) * A(0, 0, rad(-s * 4)), H)
			lit(torso, "Eye", V(0.42, 0.16, 0.06), CF(s * 0.44, 3.88, -0.73) * A(0, 0, rad(s * 16)))
		end
		lit(torso, "Seam", V(0.08, 0.62, 0.06), CF(0, 4.05, -0.73))
		lit(torso, "Grin", V(0.86, 0.24, 0.05), CF(0, 3.45, -0.73))
		for i = -1.5, 1.5 do
			make(m, torso, "GrinGap", V(0.05, 0.25, 0.06), CF(i * 0.2, 3.45, -0.74), H)
		end
		limb(m, torso, "Jaw", V(1.0, 0.28, 0.6), CF(0, 3.2, -0.42), V(0, 3.3, -0.12), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, torso, "Shoulder", V(0.62, 0.62, 0.82), CF(s * 0.98, 2.92, 0.05), H)
			for _, z in { -0.2, 0.25 } do
				wedge(m, torso, "Spike", V(0.14, 0.3, 0.24), CF(s * 1.08, 3.36, z) * A(0, 0, rad(-s * 20)), H2)
			end
			-- An arm held out wide, the claw up at its end.
			local hand = V(s * 2.0, 2.75, -0.4)
			local p = arm(m, torso, V(s * 1.05, 2.9, 0.05), V(s * 1.65, 2.35, -0.15), hand, 0.42, H, H2)
			local c = V(s * 2.15, 2.95, -0.55)
			make(m, p, "Claw", V(0.72, 0.78, 0.8), CF(c) * A(0, rad(-s * 12), 0), H)
			make(m, p, "Pincer", V(0.56, 0.5, 1.05), CF(c + V(-s * 0.1, 0.5, -0.45)) * A(rad(-22), rad(-s * 12), 0), H)
			make(m, p, "Pincer", V(0.46, 0.36, 0.42), CF(c + V(-s * 0.18, 0.22, -0.98)) * A(rad(-48), rad(-s * 12), 0), H)
			make(m, p, "Pincer", V(0.5, 0.4, 0.9), CF(c + V(-s * 0.1, -0.5, -0.4)) * A(rad(22), rad(-s * 12), 0), H2)
			-- Its crescent: round the outside of the claw from top to bottom.
			local arc = {}
			for _, deg in { 75, 32, -8, -48, -88 } do
				local a = rad(deg)
				table.insert(arc, c + V(s * math.cos(a) * 0.9, math.sin(a) * 0.9, -0.2 - math.abs(math.sin(a)) * 0.15))
			end
			for i = 1, #arc - 1 do
				local blade = beam(m, p, "Blade", arc[i], arc[i + 1], 0.13, 0.16, pal.Plate)
				blade.Material, blade.CastShadow = Enum.Material.Neon, false
			end
			local l = leg(m, torso, s * 0.52, 1.5, 0.1, 0.6, H, H2, 2, 0.12)
			make(m, l, "Knee", V(0.6, 0.38, 0.3), CF(s * 0.55, 0.82, -0.22), H2)
		end
	end

	-- Needlewing: a rust-red dragonfly hovering on four long see-through
	-- wings veined in its element's colour, great glowing eyes, a needle of
	-- a tail and grasping legs hanging.
	function B.Needlewing(m, pal, H, H2)
		local r = root(m, V(1.0, 1.0, 1.4), 1.6)
		local body = limb(m, r, "Thorax", V(0.7, 0.7, 1.0), CF(0, 1.7, 0), V(0, 1.6, 0), "Body", 1, H)
		make(m, body, "Back", V(0.5, 0.2, 0.8), CF(0, 2.1, 0), H2)
		local head = make(m, body, "Head", V(0.7, 0.6, 0.55), CF(0, 1.8, -0.75), H)
		for _, s in { -1, 1 } do
			glow(m, head, "Eye", V(0.36, 0.44, 0.44), CF(s * 0.3, 1.9, -0.88), pal)
		end
		limb(m, head, "Mandibles", V(0.36, 0.16, 0.3), CF(0, 1.45, -0.92), V(0, 1.52, -0.75), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			h.pane(m, body, V(s * 0.3, 2.02, -0.22), 2.5, 0.55, 24, -6, s, H2, pal.Plate)
			h.pane(m, body, V(s * 0.3, 2.02, 0.25), 2.3, 0.5, 18, 12, s, H2, pal.Plate)
			for _, z in { -0.25, 0.2 } do
				h.spindle(m, body, V(s * 0.24, 1.42, z), V(s * 0.5, 1.05, z - 0.3), V(s * 0.38, 0.75, z - 0.5), 0.08, H, H2, if z < 0 then s else -s)
			end
		end
		-- The abdomen curls down to its needle, the lowest of it.
		local tip = tail(
			m,
			body,
			{ V(0, 1.65, 0.5), V(0, 1.55, 1.35), V(0, 1.3, 2.15), V(0, 0.9, 2.8), V(0, 0.45, 3.2) },
			{ 0.36, 0.3, 0.25, 0.18 },
			H,
			function(seg, i, at, w)
				if i % 2 == 1 then
					make(m, seg, "Band", V(w + 0.04, w + 0.04, 0.1), CF(at), H2)
				end
			end
		)
		h.litBeam(m, tip, "Needle", V(0, 0.45, 3.2), V(0, 0.08, 3.35), 0.06, pal)
	end

	-- Hollowbone: a skeleton of a kaiju, bone-white, a ribcage around a core
	-- of its element's light, a skull with lit sockets, horns on its
	-- shoulders, a tail of vertebrae.
	function B.Hollowbone(m, pal, H, H2)
		local r = root(m, V(1.4, 1.8, 1.2), 2.3)
		local spine = limb(m, r, "Spine", V(0.32, 1.7, 0.32), CF(0, 3.05, 0.25), V(0, 2.2, 0.25), "Body", 1, H)
		make(m, spine, "Pelvis", V(0.9, 0.35, 0.5), CF(0, 2.25, 0.2), H2)
		glow(m, spine, "Core", V(0.42, 0.48, 0.38), CF(0, 3.05, -0.05) * A(0, rad(45), 0), pal)
		for i = 0, 2 do
			local y = 3.55 - i * 0.38
			local w = 1.05 - i * 0.12
			make(m, spine, "Rib", V(w, 0.12, 0.12), CF(0, y, -0.3), H)
			for _, s in { -1, 1 } do
				make(m, spine, "Rib", V(0.12, 0.12, 0.6), CF(s * w / 2, y, 0.0), H)
			end
		end
		make(m, spine, "Collar", V(1.3, 0.16, 0.3), CF(0, 3.88, 0.05), H2)
		local skull = make(m, spine, "Skull", V(0.75, 0.68, 0.75), CF(0, 4.35, -0.05), H)
		make(m, skull, "Brow", V(0.8, 0.14, 0.2), CF(0, 4.55, -0.42), H2)
		eyes(m, skull, 0.17, 4.4, -0.44, V(0.18, 0.15, 0.06), pal)
		local jaw = limb(m, skull, "Jaw", V(0.6, 0.18, 0.55), CF(0, 3.95, -0.18), V(0, 4.02, 0.08), "Jaw", 1, H2)
		make(m, jaw, "Teeth", V(0.5, 0.08, 0.05), CF(0, 4.07, -0.44), H)
		for _, s in { -1, 1 } do
			local horn = V(s * 0.62, 3.95, 0.1)
			beam(m, spine, "Horn", horn, horn + V(s * 0.2, 0.75, 0.15), 0.16, 0.16, pal.Plate)
			beam(m, spine, "Horn", horn + V(s * 0.2, 0.75, 0.15), horn + V(s * 0.05, 1.15, 0.35), 0.11, 0.11, pal.Plate)
			local hand = V(s * 0.82, 2.2, -0.2)
			local p = arm(m, spine, V(s * 0.66, 3.75, 0.05), V(s * 0.85, 2.95, 0), hand, 0.16, H, H)
			h.talons(m, p, hand, 3, 0.3, H2, V(0, -1, -0.3))
			local l = leg(m, spine, s * 0.34, 2.2, 0.2, 0.22, H, H2, 3, 0.15)
			plate(m, l, "Kneecap", V(0.18, 0.18, 0.12), CF(s * 0.36, 1.15, -0.06), pal)
		end
		tail(
			m,
			spine,
			{ V(0, 2.1, 0.5), V(0, 1.6, 1.05), V(0, 1.2, 1.6), V(0, 0.95, 2.2) },
			{ 0.2, 0.16, 0.13 },
			H,
			function(seg, i, at, w)
				make(m, seg, "Vertebra", V(w * 2, w * 0.9, w * 0.9), CF(at), H2)
			end
		)
	end

	-- Ribbonarm: a tall, faceless black figure, a slit of light for a face,
	-- two long flat ribbons for arms trailing to the ground, edged in its
	-- element's light.
	function B.Ribbonarm(m, pal, H, H2)
		local r = root(m, V(1.2, 1.8, 1.0), 2.5)
		local torso = limb(m, r, "Torso", V(0.9, 1.8, 0.6), CF(0, 3.3, 0), V(0, 2.4, 0), "Body", 1, H)
		make(m, torso, "Shoulders", V(1.3, 0.35, 0.65), CF(0, 4.1, 0), H2)
		make(m, torso, "Hips", V(0.75, 0.4, 0.55), CF(0, 2.35, 0), H2)
		local head = make(m, torso, "Head", V(0.55, 0.72, 0.6), CF(0, 4.66, 0), H)
		glow(m, head, "Slit", V(0.4, 0.06, 0.05), CF(0, 4.78, -0.31), pal)
		limb(m, head, "Jaw", V(0.4, 0.14, 0.4), CF(0, 4.3, -0.05), V(0, 4.36, 0.12), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			plate(m, torso, "Cap", V(0.4, 0.2, 0.5), CF(s * 0.66, 4.3, 0), pal)
			local points = { V(s * 0.72, 4.0, 0), V(s * 0.95, 2.95, -0.1), V(s * 1.45, 1.25, -0.2), V(s * 1.95, 0.08, 0.15) }
			local p = beam(m, torso, "Ribbon", points[1], points[2], 0.42, 0.06, H, "Arm", s)
			for i = 1, 3 do
				if i > 1 then
					beam(m, p, "Ribbon", points[i], points[i + 1], 0.42, 0.06, H)
				end
				h.litBeam(m, p, "RibbonEdge", points[i] + V(s * 0.2, 0, 0), points[i + 1] + V(s * 0.2, 0, 0), 0.05, pal)
			end
			make(m, p, "RibbonEnd", V(0.42, 0.06, 0.7), CF(s * 2.0, 0.04, 0.5), H)
			local l = leg(m, torso, s * 0.24, 2.4, 0, 0.28, H, H2, 0, 0.1)
			plate(m, l, "Knee", V(0.22, 0.2, 0.1), CF(s * 0.26, 1.25, -0.24), pal)
		end
	end


	-- Frostmaw: a hunched, pale titan, a sail of crystals in its element's
	-- colour along its back, a wide fanged jaw, long forearms it walks on.
	function B.Frostmaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 2.0), 2.0)
		local hunch = CF(0, 2.5, 0.3) * A(rad(-18), 0, 0)
		local body = limb(m, r, "Body", V(1.8, 1.7, 2.2), hunch, V(0, 1.7, 0.5), "Body", 1, H)
		make(m, body, "Chest", V(1.4, 1.1, 0.2), hunch * CF(0, -0.1, -1.1), H2)
		for i, c in { { 0, 0.95, -0.4, 1.3 }, { -0.35, 0.85, 0.15, 1.0 }, { 0.32, 0.85, 0.05, 1.05 }, { 0, 0.8, 0.6, 0.85 }, { -0.25, 0.7, 0.95, 0.6 } } do
			local frame = hunch * CF(c[1], c[2] + c[4] * 0.45, c[3]) * A(rad(-8 + i * 4), rad(i * 25), rad(c[1] * 25))
			local crystal = plate(m, body, "Crystal", V(0.3, c[4], 0.3), frame, pal)
			crystal.Material, crystal.Transparency = Enum.Material.Glass, 0.15
			glow(m, body, "Vein", V(0.08, c[4] * 0.7, 0.32), frame, pal)
		end
		local head = make(m, body, "Head", V(1.2, 0.95, 1.1), CF(0, 2.95, -1.2), H)
		make(m, head, "Brow", V(1.25, 0.25, 0.4), CF(0, 3.35, -1.55), H2)
		eyes(m, head, 0.34, 3.12, -1.76, V(0.16, 0.08, 0.06), pal)
		for i = -1, 1, 2 do
			make(m, head, "Fang", V(0.12, 0.3, 0.1), CF(i * 0.35, 2.48, -1.7), CLAW)
		end
		local jaw = limb(m, head, "Jaw", V(1.1, 0.35, 0.9), CF(0, 2.35, -1.35), V(0, 2.5, -0.9), "Jaw", 1, H2)
		for i = -1, 1, 2 do
			make(m, jaw, "Fang", V(0.12, 0.28, 0.1), CF(i * 0.42, 2.6, -1.75), CLAW)
		end
		for _, s in { -1, 1 } do
			local hand = V(s * 1.22, 0.65, -1.05)
			local p = arm(m, body, V(s * 1.0, 3.0, -0.55), V(s * 1.32, 1.95, -0.85), hand, 0.6, H, H)
			make(m, p, "Hand", V(0.7, 0.4, 0.75), CF(hand + V(0, -0.2, -0.05)), H2)
			h.talons(m, p, hand + V(0, -0.2, -0.35), 3, 0.3, CLAW)
			leg(m, body, s * 0.65, 1.7, 0.9, 0.65, H, H2, 3, 0.2)
		end
		tail(m, body, { V(0, 1.9, 1.4), V(0, 1.4, 2.1), V(0, 1.0, 2.7) }, { 0.6, 0.45 }, H)
	end

	-- Hivecrystal: a brown insect on six legs, a tall horn of crystal in its
	-- element's colour, clusters of its light growing from its shell.
	function B.Hivecrystal(m, pal, H, H2)
		local r = root(m, V(1.8, 1.4, 2.0), 1.8)
		local body = limb(m, r, "Body", V(1.6, 1.2, 2.2), CF(0, 2.0, 0.3), V(0, 1.7, 0.3), "Body", 1, H)
		for _, s in { -1, 1 } do
			make(m, body, "Shell", V(0.85, 0.35, 2.0), CF(s * 0.42, 2.68, 0.35) * A(0, 0, rad(-s * 10)), H2)
			for i = 0, 2 do
				local cluster = CF(s * 0.75, 2.75 + i * 0.05, -0.25 + i * 0.45) * A(rad(i * 20), rad(i * 35), rad(-s * 30))
				glow(m, body, "Cluster", V(0.22, 0.42 - i * 0.06, 0.22), cluster, pal)
			end
		end
		local head = make(m, body, "Head", V(0.9, 0.8, 0.8), CF(0, 2.05, -1.1), H)
		eyes(m, head, 0.3, 2.15, -1.52, V(0.16, 0.12, 0.06), pal)
		local horn = CF(0, 3.2, -1.2) * A(rad(-12), 0, 0)
		local base = plate(m, head, "Horn", V(0.42, 1.6, 0.42), horn, pal)
		base.Material, base.Transparency = Enum.Material.Glass, 0.1
		h.pyramid(m, head, "HornTip", horn * CF(0, 0.8, 0), 0.42, 0.55, pal.Plate, false, Enum.Material.Glass)
		glow(m, head, "HornCore", V(0.16, 1.3, 0.16), horn, pal)
		make(m, head, "HornRoot", V(0.6, 0.3, 0.6), CF(0, 2.45, -1.15), H2)
		local jaw = limb(m, head, "Mandibles", V(0.6, 0.18, 0.4), CF(0, 1.72, -1.4), V(0, 1.8, -1.2), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, jaw, "Pincer", V(0.1, 0.12, 0.35), CF(s * 0.22, 1.72, -1.7) * A(0, rad(s * 20), 0), CLAW)
		end
		for i, z in { -0.55, 0.3, 1.1 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				h.spindle(m, body, V(s * 0.7, 1.8, z), V(s * 1.45, 2.05, z + 0.05), V(s * 1.65, 0.05, z + 0.15), 0.2, H, H2, step)
			end
		end
	end

	-- Peelcroc: an armoured green crocodile whose head peels open in three
	-- jaws, the mouth inside lit with its element's light, scutes in rows
	-- down its back.
	function B.Peelcroc(m, pal, H, H2)
		local r = root(m, V(1.6, 1.0, 2.6), 1.3)
		local body = limb(m, r, "Body", V(1.5, 1.15, 3.0), CF(0, 1.4, 0.4), V(0, 1.15, 0.4), "Body", 1, H)
		for i = 0, 4 do
			for _, s in { -1, 1 } do
				make(m, body, "Scute", V(0.36, 0.32, 0.45), CF(s * 0.38, 2.1 + (i % 2) * 0.05, -0.65 + i * 0.55), H2)
			end
		end
		-- The upper jaw peeled up off the lower, two side jaws spread wide.
		local hinge = CF(0, 1.7, -1.1)
		local head = make(m, body, "Head", V(1.0, 0.6, 0.7), hinge * CF(0, 0, -0.1), H)
		local upper = hinge * A(rad(28), 0, 0)
		make(m, head, "UpperJaw", V(0.9, 0.42, 1.8), upper * CF(0, 0.1, -0.95), H)
		glow(m, head, "Mouth", V(0.72, 0.1, 1.6), upper * CF(0, -0.14, -0.95), pal)
		for i = -1, 1, 2 do
			make(m, head, "Tooth", V(0.08, 0.16, 0.08), upper * CF(i * 0.36, -0.2, -1.7), CLAW)
		end
		eyes(m, head, 0.3, 2.2, -1.25, V(0.12, 0.12, 0.12), pal)
		for _, s in { -1, 1 } do
			local side = hinge * A(0, rad(s * 20), rad(s * 30))
			make(m, head, "SideJaw", V(0.25, 0.45, 1.5), side * CF(s * 0.55, -0.1, -0.85), H)
			glow(m, head, "Mouth", V(0.08, 0.36, 1.35), side * CF(s * 0.4, -0.1, -0.85), pal)
		end
		local jaw = limb(m, head, "Jaw", V(0.85, 0.3, 1.7), CF(0, 1.0, -1.95), V(0, 1.1, -1.15), "Jaw", 1, H2)
		glow(m, jaw, "Tongue", V(0.6, 0.06, 1.3), CF(0, 1.17, -1.95), pal)
		for i = -1, 1, 2 do
			make(m, jaw, "Tooth", V(0.08, 0.16, 0.08), CF(i * 0.34, 1.22, -2.7), CLAW)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local z = if spot[2] < 0 then -0.6 else 1.4
			leg(m, body, spot[1] * 0.78, 1.0, z, 0.44, H, H2, 3, 0.12, -spot[1] * spot[2])
		end
		tail(
			m,
			body,
			{ V(0, 1.35, 1.85), V(0, 1.15, 2.7), V(0, 0.95, 3.5), V(0, 0.75, 4.2) },
			{ 0.82, 0.62, 0.44 },
			H,
			function(seg, i, at, w)
				plate(m, seg, "Ridge", V(0.14, 0.24, 0.5), CF(at + V(0, w * 0.55, 0)), pal)
			end
		)
		plate(m, body, "Ridge", V(0.14, 0.24, 0.5), CF(0, 2.05, 1.6), pal)
	end

	-- Magnetjaw: a hulking navy beetle on two legs, a domed shell over its
	-- back and shoulders with its head tucked under the front of it, slanted
	-- eyes, two great curved horns of its element's light crackling with
	-- sparks, huge blocky hands.
	function B.Magnetjaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.6), 2.1)
		local torso = limb(m, r, "Torso", V(2.2, 1.7, 1.5), CF(0, 2.6, 0.15), V(0, 1.8, 0.2), "Body", 1, H)
		for i = 0, 1 do
			make(m, torso, "Band", V(1.6, 0.18, 0.1), CF(0, 2.12 + i * 0.36, -0.63), H2)
		end
		-- The shell: two wing cases rising over its back, capped, a seam
		-- down between them.
		for _, s in { -1, 1 } do
			make(m, torso, "Shell", V(1.3, 1.45, 1.85), CF(s * 0.64, 3.38, 0.42) * A(0, 0, rad(-s * 10)), H2)
			make(m, torso, "ShellRim", V(1.0, 0.38, 1.7), CF(s * 1.15, 2.78, 0.4) * A(0, 0, rad(-s * 28)), H2)
			make(m, torso, "Pauldron", V(1.0, 0.8, 1.15), CF(s * 1.32, 3.12, -0.05), H)
		end
		make(m, torso, "ShellTop", V(1.6, 0.4, 1.5), CF(0, 4.1, 0.44), H2)
		make(m, torso, "ShellSeam", V(0.08, 0.5, 1.55), CF(0, 4.1, 0.44), H)
		-- Its head under the front of the shell.
		local head = make(m, torso, "Head", V(1.15, 0.85, 0.8), CF(0, 3.2, -0.65), H)
		make(m, head, "Brow", V(1.25, 0.22, 0.3), CF(0, 3.57, -0.92), H2)
		for _, s in { -1, 1 } do
			make(m, head, "Eye", V(0.28, 0.11, 0.06), CF(s * 0.28, 3.32, -1.06) * A(0, 0, rad(s * 14)), pal.Plate, Enum.Material.Neon)
			wedge(m, head, "Mandible", V(0.18, 0.32, 0.32), CF(s * 0.34, 2.85, -0.98) * A(math.pi, 0, 0), H2)
		end
		limb(m, head, "Jaw", V(0.75, 0.22, 0.45), CF(0, 2.82, -0.8), V(0, 2.92, -0.55), "Jaw", 1, H2)
		-- The horns: up and out, then hooked back in, sparking.
		for _, s in { -1, 1 } do
			local points = {
				V(s * 0.34, 3.6, -0.7),
				V(s * 0.66, 4.15, -0.72),
				V(s * 0.9, 4.75, -0.66),
				V(s * 0.78, 5.22, -0.58),
				V(s * 0.46, 5.4, -0.52),
				V(s * 0.27, 5.2, -0.52),
			}
			for i = 1, #points - 1 do
				local horn = beam(m, head, "Horn", points[i], points[i + 1], 0.2 - i * 0.02, 0.2 - i * 0.02, pal.Plate)
				horn.Material, horn.CastShadow = Enum.Material.Neon, false
			end
			for _, spot in { V(s * 1.16, 4.45, -0.62), V(s * 1.04, 5.15, -0.52), V(s * 0.55, 5.6, -0.5) } do
				glow(m, head, "Spark", V(0.1, 0.1, 0.1), CF(spot) * A(rad(45), rad(45), 0), pal)
			end
			-- The arms: hanging heavy, a bracer, a huge hand.
			local hand = V(s * 1.6, 1.55, -0.45)
			local p = arm(m, torso, V(s * 1.32, 3.0, -0.05), V(s * 1.62, 2.3, -0.25), hand, 0.72, H, H)
			make(m, p, "Bracer", V(0.9, 0.55, 0.9), CF(V(s * 1.61, 1.95, -0.35)), H2)
			make(m, p, "Hand", V(0.98, 0.68, 0.92), CF(hand + V(0, -0.25, -0.05)), H)
			for i = -1, 1 do
				make(m, p, "Finger", V(0.26, 0.42, 0.3), CF(hand + V(i * 0.32, -0.75, -0.3)), H2)
			end
			leg(m, torso, s * 0.62, 1.8, 0.25, 0.82, H, H2, 2, 0.12)
		end
	end

	-- Capspore: a walking mushroom, a wide cream dome of a cap spotted
	-- brown, the gills under it glowing in its element's colour round a
	-- grille of spore vents, a stumpy dark body with two square lit eyes.
	function B.Capspore(m, pal, H, H2)
		local r = root(m, V(1.4, 1.4, 1.4), 1.5)
		local body = limb(m, r, "Stem", V(1.4, 1.5, 1.2), CF(0, 1.55, 0), V(0, 0.9, 0), "Body", 1, H2)
		make(m, body, "Skirt", V(1.5, 0.35, 1.3), CF(0, 0.98, 0), H2)
		-- The cap: a thick rim, then thin discs sloping up into a dome.
		h.disc(m, body, "Cap", 3.4, 0.26, CF(0, 2.63, 0), H)
		for k = 0, 8 do
			local d = 2 * (1.62 - 1.0 * ((k + 1) / 9) ^ 1.3)
			h.disc(m, body, "Cap", d, 0.1, CF(0, 2.81 + k * 0.1, 0), H)
		end
		-- Brown spots laid flat on its slope.
		-- (out from its middle, round it, the slope's height there, its tilt)
		local spots = {
			{ 1.45, 25, 2.96, 36 }, { 1.45, 150, 2.96, 36 }, { 1.45, 265, 2.96, 36 }, { 1.18, 85, 3.16, 38 },
			{ 1.18, 205, 3.16, 38 }, { 0.95, 330, 3.36, 40 }, { 0.72, 140, 3.56, 30 }, { 0.3, 30, 3.66, 0 },
		}
		for _, spot in spots do
			local a, out = rad(spot[2]), spot[1]
			make(m, body, "Spot", V(0.34, 0.06, 0.3), CF(math.cos(a) * out, spot[3] + 0.03, math.sin(a) * out) * A(0, -a, 0) * A(0, 0, rad(-spot[4])), C(150, 116, 86))
		end
		-- Its gills lit under the rim, a grille of vents over its face.
		h.disc(m, body, "Gills", 3.2, 0.3, CF(0, 2.35, 0), pal.Plate, Enum.Material.Neon)
		h.disc(m, body, "Collar", 1.9, 0.14, CF(0, 2.13, 0), pal.Plate, Enum.Material.Neon)
		for col = -1, 1 do
			make(m, body, "Grille", V(0.2, 0.09, 0.05), CF(col * 0.3, 2.13, -0.95), H2)
		end
		for _, s in { -1, 1 } do
			make(m, body, "Eye", V(0.24, 0.24, 0.06), CF(s * 0.3, 1.82, -0.61), pal.Plate, Enum.Material.Neon)
		end
		limb(m, body, "Mouth", V(0.5, 0.12, 0.1), CF(0, 1.42, -0.6), V(0, 1.48, -0.5), "Jaw", 1, H)
		for _, s in { -1, 1 } do
			h.arm(m, body, V(s * 0.72, 1.85, 0), V(s * 0.85, 1.5, -0.05), V(s * 0.82, 1.18, -0.15), 0.28, H2, H2)
			pillar(m, body, s * 0.36, 0.85, 0.05, 0.5, H2, H2, 0)
		end
	end

	-- Coinmaw: a round brown coin purse on stubby legs, a zipper of a mouth
	-- right across it (its teeth the zipper's) with swallowed gems spilling
	-- out, eyes up on stalks, coins of its element's colour stuck to its
	-- sides.
	function B.Coinmaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.4, 1.6), 1.3)
		-- A ball of a purse in rounded steps.
		local body = limb(m, r, "Purse", V(2.6, 0.75, 2.2), CF(0, 2.22, 0), V(0, 1.0, 0), "Body", 1, H)
		make(m, body, "Dome", V(2.3, 0.3, 2.0), CF(0, 2.74, 0), H)
		make(m, body, "Dome", V(1.85, 0.25, 1.65), CF(0, 3.0, 0), H)
		make(m, body, "Dome", V(1.15, 0.18, 1.05), CF(0, 3.2, 0), H)
		for _, s in { -1, 1 } do
			make(m, body, "Bulge", V(0.22, 1.1, 1.8), CF(s * 1.39, 1.85, 0), H)
			h.disc(m, body, "Coin", 0.55, 0.08, CF(s * 1.55, 2.0, 0.3) * A(0, 0, rad(-s * 90)), pal.Plate)
			make(m, body, "Nub", V(0.35, 0.4, 0.45), CF(s * 1.5, 1.6, -0.35), H2)
		end
		make(m, body, "Seam", V(0.12, 0.06, 1.0), CF(0, 3.31, 0), H2)
		plate(m, body, "Clasp", V(0.4, 0.2, 0.3), CF(0, 3.35, -0.3), pal)
		-- The zipper: dark inside, a row of teeth above and below, its pull.
		make(m, body, "Inside", V(2.3, 0.12, 0.1), CF(0, 1.79, -1.06), C(36, 22, 18))
		for i = 0, 7 do
			make(m, body, "Tooth", V(0.16, 0.14, 0.1), CF(-1.05 + i * 0.3, 1.84, -1.12), CLAW)
		end
		plate(m, body, "Pull", V(0.18, 0.32, 0.06), CF(1.22, 1.68, -1.16), pal)
		-- Its lower half; the front of it is the lip (its jaw), hinged at the
		-- bottom so the purse falls open over the dark inside.
		make(m, body, "Lower", V(2.5, 0.8, 1.75), CF(0, 1.35, 0.225), H)
		make(m, body, "Chin", V(2.0, 0.25, 1.7), CF(0, 0.88, 0.05), H)
		make(m, body, "Inside", V(2.3, 0.7, 0.3), CF(0, 1.4, -0.6), C(36, 22, 18))
		local lip = limb(m, body, "Lip", V(2.5, 0.8, 0.45), CF(0, 1.35, -0.875), V(0, 0.95, -0.65), "Jaw", 1, H)
		for i = 0, 6 do
			make(m, lip, "Tooth", V(0.16, 0.14, 0.1), CF(-0.9 + i * 0.3, 1.74, -1.06), CLAW)
		end
		for i, g in { { -0.55, 1.5, -1.14 }, { 0.15, 1.42, -1.16 }, { 0.62, 1.55, -1.13 } } do
			local at = CF(g[1], g[2], g[3]) * A(rad(45), rad(i * 30), 0)
			if i == 2 then
				plate(m, lip, "Gem", V(0.24, 0.24, 0.24), at, pal)
			else
				glow(m, lip, "Gem", V(0.2, 0.2, 0.2), at, pal)
			end
		end
		for _, s in { -1, 1 } do
			local top = V(s * 0.7, 3.75, -0.5)
			beam(m, body, "Stalk", V(s * 0.55, 3.1, -0.35), top, 0.16, 0.16, H2)
			make(m, body, "EyeBall", V(0.5, 0.45, 0.45), CF(top + V(0, 0.2, 0)), H2)
			glow(m, body, "Eye", V(0.26, 0.2, 0.06), CF(top + V(0, 0.2, -0.23)), pal)
			pillar(m, body, s * 0.75, 0.95, -0.45, 0.45, H, H2, 2, s)
			pillar(m, body, s * 0.75, 0.95, 0.55, 0.45, H, H2, 2, -s)
		end
	end

	-- Silkling: a great grey caterpillar, its front reared up, pale bands
	-- lit with its element's light, little legs down its length.
	function B.Silkling(m, pal, H, H2)
		local r = root(m, V(1.4, 1.0, 2.4), 1.0)
		local body = limb(m, r, "Segment", V(1.1, 1.0, 0.8), CF(0, 0.6, 0.6), V(0, 0.6, 0.6), "Body", 1, H)
		for i, z in { 1.38, 2.14, 2.86 } do
			local w = 1.04 - i * 0.08
			make(m, body, "Segment", V(w, w * 0.9, 0.72), CF(0, 0.54 - i * 0.03, z), if i % 2 == 0 then H else H2)
			glow(m, body, "Band", V(w + 0.04, 0.08, 0.1), CF(0, 0.54 + w * 0.3, z + 0.34), pal)
		end
		plate(m, body, "Band", V(1.14, 0.1, 0.12), CF(0, 1.08, 0.95), pal)
		for i, seg in { { 0, 1.15, 0.05, 1.0 }, { 0, 1.75, -0.35, 0.95 }, { 0, 2.35, -0.55, 0.9 } } do
			make(m, body, "Neck", V(seg[4], seg[4] * 0.9, 0.7), CF(seg[1], seg[2], seg[3]) * A(rad(-30 - i * 12), 0, 0), if i % 2 == 1 then H2 else H)
			plate(m, body, "Band", V(seg[4] + 0.04, 0.1, 0.12), CF(seg[1], seg[2] + 0.1, seg[3] + 0.32) * A(rad(-30 - i * 12), 0, 0), pal)
		end
		local head = limb(m, body, "Head", V(1.0, 0.9, 0.9), CF(0, 2.95, -0.8), V(0, 2.6, -0.6), "Head", 1, H)
		for _, s in { -1, 1 } do
			glow(m, head, "Eye", V(0.22, 0.18, 0.06), CF(s * 0.28, 3.05, -1.26), pal)
		end
		limb(m, head, "Jaw", V(0.5, 0.16, 0.3), CF(0, 2.55, -1.15), V(0, 2.62, -0.95), "Jaw", 1, H2)
		for i, z in { 0.6, 1.4, 2.2 } do
			for _, s in { -1, 1 } do
				local step = if i % 2 == 0 then s else -s
				local p = limb(m, body, "Leg", V(0.2, 0.36, 0.22), CF(s * 0.46, 0.18, z), V(s * 0.46, 0.32, z), "Stride", step, H2)
				make(m, p, "Foot", V(0.24, 0.08, 0.26), CF(s * 0.46, 0.04, z - 0.02), H)
			end
		end
		make(m, body, "Tail", V(0.5, 0.4, 0.4), CF(0, 0.4, 3.35), H)
	end

	return B
end

return Half
