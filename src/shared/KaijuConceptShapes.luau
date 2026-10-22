-- Concept-led silhouettes for the selected roster. Geometry stays procedural,
-- element-driven and attached to the existing CreatureMotion joint vocabulary.
local Concepts = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rad = math.rad

function Concepts.install(k)
	local make, limb, plate, wedge, root = k.make, k.limb, k.plate, k.wedge, k.root
	-- Keep luminous accents recognizably elemental, including yellow Ion eyes.
	local function glow(m, p, name, size, cf, pal)
		return make(m, p, name, size, cf, pal.Plate:Lerp(pal.Glow, 0.2), Enum.Material.Neon)
	end
	local B = {}
	local function beam(m, p, name, a, b, width, depth, color, motion, side)
		local d = b - a
		local y = d.Unit
		local x = y:Cross(if math.abs(y.Y) > 0.95 then V(0, 0, 1) else V(0, 1, 0)).Unit
		local cf = CFrame.fromMatrix((a + b) / 2, x, y)
		if motion then
			return limb(m, p, name, V(width, d.Magnitude, depth), cf, a, motion, side or 1, color)
		end
		return make(m, p, name, V(width, d.Magnitude, depth), cf, color)
	end

	-- Two right wedges form an arbitrary triangular membrane, without mesh IDs.
	local function triangle(m, p, name, a, b, c, thickness, color)
		if (b - a).Magnitude > (c - b).Magnitude and (b - a).Magnitude > (c - a).Magnitude then
			a, c = c, a
		elseif (c - a).Magnitude > (c - b).Magnitude then
			a, b = b, a
		end
		local back = (c - b).Unit
		local right = (c - a):Cross(b - a).Unit
		local up = back:Cross(right).Unit
		local height = math.abs((a - b):Dot(up))
		wedge(
			m,
			p,
			name,
			V(thickness, height, math.abs((a - b):Dot(back))),
			CFrame.fromMatrix((a + b) / 2, right, up, back),
			color
		)
		wedge(
			m,
			p,
			name,
			V(thickness, height, math.abs((a - c):Dot(back))),
			CFrame.fromMatrix((a + c) / 2, -right, up, -back),
			color
		)
	end

	local function leg(m, body, x, top, z, size, H, H2, toes)
		local hip = V(x, top, z)
		local knee = V(x * 1.08, top * 0.53, z - 0.28)
		local ankle = V(x * 1.08, 0.3, z + 0.03)
		local p = beam(m, body, "Thigh", hip, knee, size, size * 1.1, H, "Stride", if x < 0 then -1 else 1)
		beam(m, p, "Shin", knee, ankle, size * 0.7, size * 0.75, H2)
		make(m, p, "Knee", V(size * 0.8, 0.3, size * 0.6), CF(knee + V(0, 0, -size * 0.26)), H)
		make(m, p, "Foot", V(size, 0.28, size * 1.35), CF(ankle.X, 0.14, z - 0.22), H2)
		for i = 1, toes or 3 do
			wedge(
				m,
				p,
				"Toe",
				V(size * 0.2, 0.2, 0.34),
				CF(ankle.X + (i - ((toes or 3) + 1) / 2) * size * 0.29, 0.1, z - 0.22 - size * 0.67),
				H2
			)
		end
		return p
	end

	local function face(m, head, cf, width, pal, H, H2)
		for _, side in { -1, 1 } do
			glow(m, head, "Eye", V(width * 0.22, 0.13, 0.045), cf * CF(side * width * 0.29, 0.03, 0), pal)
			wedge(
				m,
				head,
				"Brow",
				V(width * 0.44, 0.16, 0.24),
				cf * CF(side * width * 0.27, 0.15, 0.04) * A(0, 0, rad(side * 12)),
				H2
			)
		end
	end

	local function tail(m, body, points, widths, H, deco)
		local parent = body
		for i = 1, #points - 1 do
			local p = beam(m, parent, "Tail", points[i], points[i + 1], widths[i], widths[i] * 0.8, H, "Tail")
			if deco then
				deco(p, i, (points[i] + points[i + 1]) / 2, widths[i])
			end
			parent = p
		end
	end

	local function talonHand(m, arm, at, s, H)
		make(m, arm, "Palm", V(0.48 * s, 0.35 * s, 0.42 * s), CF(at), H)
		for i = -1, 1 do
			local a = at + V(i * 0.16 * s, -0.1 * s, -0.18 * s)
			local b = a + V(i * 0.03, -0.2 * s, -0.16 * s)
			beam(m, arm, "Finger", a, b, 0.1 * s, 0.12 * s, H)
			wedge(m, arm, "Claw", V(0.1 * s, 0.22 * s, 0.17 * s), CF(b + V(0, -0.06 * s, 0.03)), H)
		end
	end

	function B.Emberjaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.8), 2.2)
		local torso =
			limb(m, r, "Torso", V(1.85, 2.0, 1.5), CF(0, 2.65, 0.15) * A(rad(-7), 0, 0), V(0, 1.7, 0.2), "Body", 1, H)
		make(m, torso, "Hips", V(1.65, 0.65, 1.5), CF(0, 1.75, 0.25), H)
		for _, s in { -1, 1 } do
			wedge(m, torso, "Pectoral", V(0.82, 0.8, 0.45), CF(s * 0.44, 3.1, -0.65) * A(0, 0, rad(s * 5)), H2)
			local arm = beam(m, torso, "Arm", V(s * 0.92, 3.25, -0.1), V(s * 1.13, 2.52, -0.35), 0.5, 0.62, H, "Arm", s)
			beam(m, arm, "Forearm", V(s * 1.13, 2.52, -0.35), V(s * 1.02, 2.15, -0.85), 0.46, 0.5, H2)
			talonHand(m, arm, V(s * 1.02, 2.0, -0.9), 0.95, H2)
			leg(m, torso, s * 0.62, 1.75, 0.3, 0.78, H, H2)
		end
		wedge(m, torso, "Belly", V(1.25, 1.2, 0.3), CF(0, 2.2, -0.7) * A(math.pi, 0, 0), H2)
		local head = make(m, torso, "Head", V(1.2, 0.85, 1.25), CF(0, 3.95, -0.35), H)
		make(m, head, "Snout", V(0.85, 0.47, 0.65), CF(0, 3.83, -1.14), H2)
		face(m, head, CF(0, 4.05, -0.99), 1.08, pal, H, H)
		limb(m, head, "Jaw", V(0.84, 0.22, 0.7), CF(0, 3.5, -1.05), V(0, 3.6, -0.6), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			make(m, head, "Nostril", V(0.09, 0.08, 0.025), CF(s * 0.26, 3.93, -1.48), H)
		end
		for i = 0, 3 do
			local f = CF(0, 3.9 - i * 0.52, 0.85 + i * 0.17)
			local fin = wedge(m, torso, "DorsalBlade", V(0.2, 0.95 + i * 0.04, 0.85), f * A(rad(-18), 0, 0), pal.Plate)
			fin.Material = Enum.Material.Neon
			wedge(m, torso, "DorsalProng", V(0.18, 0.65, 0.4), f * CF(0, 0.12, 0.38) * A(rad(-35), 0, 0), pal.Glow).Material =
				Enum.Material.Neon
			wedge(m, torso, "DorsalFlame", V(0.1, 0.6, 0.5), f * CF(0, 0.05, 0.02) * A(rad(-18), 0, 0), pal.Glow).Material =
				Enum.Material.Neon
		end
		tail(
			m,
			torso,
			{ V(0, 1.7, 0.8), V(0, 0.95, 1.65), V(0, 0.7, 2.6), V(0, 1.05, 3.4), V(0, 1.65, 4.1), V(0, 2.05, 4.5) },
			{ 0.9, 0.72, 0.56, 0.4, 0.24 },
			H,
			function(p, i, at, w)
				wedge(m, p, "TailBlade", V(0.16, 0.7 - i * 0.05, 0.55), CF(at + V(0, w * 0.4, 0)), pal.Plate).Material =
					Enum.Material.Neon
			end
		)
	end

	function B.Stormwing(m, pal, H, H2)
		local r = root(m, V(1, 1, 1), 1.3)
		local body = limb(m, r, "Body", V(0.8, 0.9, 1.5), CF(0, 1.3, 0.2), V(0, 1.1, 0.3), "Body", 1, H)
		local head = make(m, body, "Head", V(0.7, 0.8, 0.85), CF(0, 1.95, -0.55), H)
		-- Long triangular beak and broad swept membranes, not rectangular paddles.
		triangle(m, head, "Beak", V(-0.35, 1.95, -0.85), V(0.35, 1.95, -0.85), V(0, 1.58, -2.5), 0.24, H2)
		limb(m, head, "Jaw", V(0.22, 0.12, 1.1), CF(0, 1.57, -1.35), V(0, 1.65, -0.9), "Jaw", 1, H)
		for _, s in { -1, 1 } do
			glow(m, head, "Eye", V(0.055, 0.2, 0.2), CF(s * 0.36, 2.0, -0.72), pal)
			local pivot = V(s * 0.38, 1.5, 0.08)
			local w = limb(m, body, "Wing", V(0.35, 0.18, 0.6), CF(pivot), pivot, "Wing", s, H)
			local a = pivot + V(0, 0, -0.42)
			local b = V(s * 3.75, 1.7, -0.05)
			local c = V(s * 2.1, 1.48, 1.25)
			local d = V(s * 0.65, 1.45, 1.4)
			triangle(m, w, "WingMembrane", a, b, c, 0.12, H2)
			triangle(m, w, "WingMembrane", a, c, d, 0.12, H)
			beam(m, w, "LeadingSpar", a, b, 0.12, 0.14, H)
			beam(m, w, "LeadingLight", a:Lerp(b, 0.45), b, 0.08, 0.09, pal.Glow).Material = Enum.Material.Neon
			local e = beam(m, w, "LuminousTip", b, V(s * 2.8, 1.63, 0.52), 0.12, 0.16, pal.Glow)
			e.Material = Enum.Material.Neon
			plate(m, w, "WingKnuckle", V(0.18, 0.22, 0.32), CF(s * 1.5, 1.58, -0.1), pal)
			local foot =
				beam(m, body, "Leg", V(s * 0.23, 1.15, 0.35), V(s * 0.28, 0.3, 0.2), 0.13, 0.16, H, "Stride", s)
			for _, toe in { -1, 1 } do
				beam(m, foot, "Talon", V(s * 0.28, 0.3, 0.2), V(s * 0.28 + toe * 0.1, 0.04, -0.1), 0.08, 0.08, H2)
			end
		end
		for i = 0, 5 do
			local f = CF(0, 2.08, -0.35) * A(0, 0, rad(-65 + i * 26))
			make(m, head, "CrestRoot", V(0.17, 0.42, 0.2), f * CF(0, 0.45, 0), H2)
			plate(m, head, "CrestTip", V(0.14, 0.28, 0.18), f * CF(0, 0.8, 0), pal).Material = Enum.Material.Neon
		end
		tail(m, body, { V(0, 1.3, 0.8), V(0, 1.35, 1.6), V(0, 1.5, 2.15) }, { 0.3, 0.16 }, H)
	end

	function B.Sickleclaw(m, pal, H, H2)
		local r = root(m, V(1.5, 1.6, 1.4), 2.1)
		local body = limb(m, r, "Torso", V(1.3, 2.05, 1.0), CF(0, 2.7, 0.1), V(0, 1.7, 0.1), "Body", 1, H)
		for _, s in { -1, 1 } do
			wedge(m, body, "Thorax", V(0.62, 1.8, 0.35), CF(s * 0.36, 2.6, -0.5) * A(0, 0, rad(-s * 6)), H2)
			local fin = CF(s * 0.55, 3.3, 0.85) * A(rad(-20), 0, rad(-s * 20))
			wedge(m, body, "BackSail", V(0.15, 1.45, 1.0), fin, H2)
			wedge(m, body, "SailInset", V(0.17, 1.03, 0.65), fin * CF(0, -0.12, 0.1), H)
			local shoulder = V(s * 0.78, 3.35, -0.1)
			local elbow = V(s * 1.08, 2.8, -0.35)
			local wrist = V(s * 1.25, 2.35, -0.95)
			local p = beam(m, body, "Arm", shoulder, elbow, 0.4, 0.5, H, "Arm", s)
			beam(m, p, "Forearm", elbow, wrist, 0.35, 0.45, H2)
			-- Broad open U hooks are the signature, with a visible gap inside.
			local a = wrist + V(-s * 0.28, -0.1, 0)
			local b = wrist + V(s * 0.35, -0.1, 0)
			beam(m, p, "HookBridge", a, b, 0.22, 0.25, H2)
			beam(m, p, "OuterHook", b, b + V(s * 0.14, -0.57, -0.18), 0.22, 0.25, H2)
			wedge(m, p, "HookPoint", V(0.22, 0.42, 0.25), CF(b + V(s * 0.02, -0.7, -0.18)) * A(0, 0, rad(s * 45)), H2)
			beam(m, p, "InnerHook", a, a + V(s * 0.04, -0.38, -0.08), 0.17, 0.22, H)
			leg(m, body, s * 0.48, 1.75, 0.12, 0.58, H, H2, 2)
		end
		glow(m, body, "BellySlit", V(0.16, 1.6, 0.08), CF(0, 2.65, -0.55), pal)
		for i = 0, 6 do
			plate(m, body, "SawTooth", V(0.24, 0.13, 0.18), CF(-0.08, 3.3 - i * 0.23, -0.63) * A(0, 0, rad(15)), pal)
		end
		local head = make(m, body, "Head", V(1.0, 0.9, 0.95), CF(0, 4.1, -0.27), H2)
		make(m, head, "EyeSocket", V(1.03, 0.38, 0.16), CF(0, 4.1, -0.77), H)
		glow(m, head, "Visor", V(0.88, 0.23, 0.06), CF(0, 4.1, -0.87), pal)
		make(m, head, "Brow", V(1.05, 0.17, 0.3), CF(0, 4.35, -0.73), H)
		limb(m, head, "Jaw", V(0.73, 0.28, 0.6), CF(0, 3.55, -0.61), V(0, 3.67, -0.25), "Jaw", 1, H2)
		tail(m, body, { V(0, 1.7, 0.6), V(0, 1.1, 1.25), V(0, 0.9, 1.9) }, { 0.5, 0.3 }, H)
	end

	function B.Drillhorn(m, pal, H, H2)
		local r = root(m, V(1.7, 1.7, 1.6), 2.0)
		local body =
			limb(m, r, "Torso", V(1.6, 1.75, 1.35), CF(0, 2.45, 0.2) * A(rad(-12), 0, 0), V(0, 1.65, 0.3), "Body", 1, H)
		for i = 0, 2 do
			wedge(m, body, "BellySegment", V(1.18 - i * 0.15, 0.43, 0.3), CF(0, 2.9 - i * 0.45, -0.55), H2)
		end
		for _, s in { -1, 1 } do
			local f = CF(s * 0.67, 2.8, 0.95) * A(rad(-18), 0, rad(s * 12))
			make(m, body, "WingCase", V(0.85, 1.8, 0.45), f, H)
			wedge(m, body, "CaseBevel", V(0.75, 0.35, 0.45), f * CF(0, 1.02, 0), H2)
			plate(m, body, "CaseSeam", V(0.06, 1.4, 0.08), f * CF(-s * 0.35, 0, 0.24), pal)
			local p = beam(m, body, "Arm", V(s * 0.95, 3.1, -0.15), V(s * 1.25, 2.7, -0.65), 0.65, 0.65, H, "Arm", s)
			local f2 = CF(s * 1.25, 2.65, -0.65) * A(rad(65), 0, rad(-s * 8))
			for i = 0, 2 do
				wedge(m, p, "ForearmSegment", V(0.65 - i * 0.06, 0.25, 0.65 - i * 0.06), f2 * CF(0, -i * 0.22, 0), H2)
			end
			for i = 0, 3 do
				local w = 0.48 - i * 0.1
				make(
					m,
					p,
					"DrillFlight",
					V(w, 0.2, w),
					f2 * CF(0, -0.65 - i * 0.22, 0) * A(0, rad(i * 35), 0),
					if i % 2 == 0 then pal.Plate else H2,
					if i % 2 == 0 then Enum.Material.Neon else nil
				)
			end
			wedge(m, p, "DrillTip", V(0.15, 0.32, 0.15), f2 * CF(0, -1.45, 0) * A(0, 0, math.pi), pal.Plate).Material =
				Enum.Material.Neon
			leg(m, body, s * 0.57, 1.65, 0.3, 0.7, H, H2, 2)
		end
		local head = make(m, body, "Head", V(1.1, 0.85, 1.1), CF(0, 3.6, -0.35) * A(rad(-12), 0, 0), H2)
		make(m, head, "Muzzle", V(0.85, 0.4, 0.7), CF(0, 3.45, -1.0), H)
		limb(m, head, "Jaw", V(0.8, 0.18, 0.7), CF(0, 3.15, -0.95), V(0, 3.25, -0.5), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			glow(m, head, "Eye", V(0.065, 0.13, 0.16), CF(s * 0.56, 3.7, -0.65), pal)
		end
		for i = 0, 2 do
			local w = 0.4 - i * 0.1
			plate(
				m,
				head,
				"HornRoot",
				V(w, 0.43, w),
				CF(0, 4.05 + i * 0.36, -0.65 - i * 0.08) * A(rad(-12), 0, rad(i * 3)),
				pal
			).Material =
				Enum.Material.Neon
		end
		tail(m, body, { V(0, 1.7, 0.85), V(0, 1.3, 1.55), V(0, 1.15, 2.1) }, { 0.7, 0.4 }, H)
	end

	function B.Hulkshell(m, pal, H, H2)
		local r = root(m, V(2, 1.8, 2), 1.85)
		local body =
			limb(m, r, "Torso", V(2.2, 1.7, 2.2), CF(0, 2.2, 0.5) * A(rad(-22), 0, 0), V(0, 1.65, 0.55), "Body", 1, H)
		-- A faceted dome, low face and ground-level fists form the gorilla silhouette.
		local shell = make(m, body, "ShellCore", V(2.05, 0.7, 1.9), CF(0, 2.98, 0.65), H)
		make(m, body, "ShellCrown", V(1.35, 0.26, 1.35), CF(0, 3.72, 0.65), H2)
		for _, s in { -1, 1 } do
			make(
				m,
				shell,
				"FrontScute",
				V(1.04, 0.25, 0.95),
				CF(s * 0.51, 3.33, -0.26) * A(rad(48), 0, rad(-s * 15)),
				H2
			)
			make(
				m,
				shell,
				"RearScute",
				V(1.04, 0.25, 0.95),
				CF(s * 0.51, 3.33, 1.56) * A(rad(-48), 0, rad(-s * 15)),
				H2
			)
		end
		local cracks = {
			{ V(-0.65, 3.87, 0.1), V(-0.1, 3.87, 0.5) },
			{ V(-0.1, 3.87, 0.5), V(0.55, 3.87, 0.35) },
			{ V(0.55, 3.87, 0.35), V(1.13, 3.45, 0.4) },
			{ V(1.13, 3.45, 0.4), V(1.36, 2.97, 0.7) },
			{ V(-0.65, 3.87, 0.1), V(-1.14, 3.4, -0.06) },
			{ V(-1.14, 3.4, -0.06), V(-1.36, 3.0, 0.15) },
			{ V(1.36, 3.0, 0.7), V(1.36, 3.15, 1.15) },
			{ V(-1.36, 3.0, 0.15), V(-1.36, 2.75, 0.8) },
			{ V(-0.1, 3.87, 0.5), V(0.15, 3.87, 1.24) },
			{ V(0.15, 3.87, 1.24), V(0.65, 3.7, 1.55) },
		}
		for _, line in cracks do
			beam(m, shell, "ShellCrack", line[1], line[2], 0.045, 0.045, pal.Plate).Material = Enum.Material.Neon
		end
		for _, s in { -1, 1 } do
			for i = 0, 2 do
				make(
					m,
					shell,
					"DomeScute",
					V(0.95, 0.22, 0.7),
					CF(s * 0.93, 3.45 - math.abs(i - 1) * 0.1, -0.05 + i * 0.68) * A(rad((1 - i) * 15), 0, rad(-s * 40)),
					H2
				)
				make(
					m,
					shell,
					"SideScute",
					V(0.22, 0.73, 0.7),
					CF(s * 1.27, 2.94, -0.05 + i * 0.68) * A(0, 0, rad(s * 12)),
					H
				)
			end
			local shoulder = V(s * 1.15, 2.6, -0.45)
			local elbow = V(s * 1.48, 1.5, -1.02)
			local fist = V(s * 1.55, 0.32, -1.45)
			local p = beam(m, body, "Arm", shoulder, elbow, 0.85, 0.95, H, "Arm", s)
			beam(m, p, "Forearm", elbow, fist + V(0, 0.25, 0), 0.95, 1.0, H2)
			make(m, p, "Fist", V(0.95, 0.6, 0.9), CF(fist), H)
			for i = -1, 1 do
				make(m, p, "Knuckle", V(0.23, 0.3, 0.14), CF(fist + V(i * 0.28, -0.08, -0.45)), H2)
			end
			leg(m, body, s * 0.76, 1.7, 1.05, 0.8, H, H2, 2)
		end
		local head = make(m, body, "Head", V(1.1, 1.0, 0.9), CF(0, 2.65, -1.0), H2)
		face(m, head, CF(0, 2.78, -1.47), 1.0, pal, H, H)
		make(m, head, "Muzzle", V(0.72, 0.4, 0.4), CF(0, 2.35, -1.58), H)
		make(m, head, "Nose", V(0.38, 0.18, 0.2), CF(0, 2.6, -1.75), H2)
		limb(m, head, "Jaw", V(0.75, 0.22, 0.6), CF(0, 2.04, -1.4), V(0, 2.15, -1.05), "Jaw", 1, H2)
		for i = 0, 2 do
			make(m, head, "ForeheadRidge", V(0.9 - i * 0.13, 0.14, 0.4), CF(0, 3.03 + i * 0.16, -1.3 + i * 0.08), H)
		end
	end

	function B.Triskull(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.6), 1.9)
		local body = limb(m, r, "Torso", V(1.6, 1.6, 1.4), CF(0, 2.25, 0.2), V(0, 1.45, 0.3), "Body", 1, H)
		make(m, body, "Hips", V(1.35, 0.6, 1.25), CF(0, 1.5, 0.3), H2)
		make(m, body, "Breast", V(1.25, 0.7, 0.25), CF(0, 2.6, -0.6), H2)
		for s = -1, 1 do
			local a = V(s * 0.46, 2.8, -0.1)
			local b = V(s * 0.9, 3.8, -0.15)
			local top = V(s * 1.27, 4.75 + (if s == 0 then 0.45 else 0), -0.6)
			local neck = beam(m, body, "Neck", a, b, 0.43, 0.5, H, "Head", if s == 0 then 0.5 else s)
			beam(m, neck, "UpperNeck", b, top, 0.4, 0.45, H)
			for i = 1, 3 do
				local at = a:Lerp(top, i / 4)
				make(m, neck, "NeckScale", V(0.42, 0.19, 0.12), CF(at + V(0, 0, -0.28)) * A(rad(-12), 0, 0), H2)
				plate(m, neck, "NeckSpine", V(0.16, 0.25, 0.24), CF(at + V(0, 0, 0.29)) * A(rad(30), 0, 0), pal).Material =
					Enum.Material.Neon
			end
			local head = make(m, neck, "Head", V(0.67, 0.48, 0.8), CF(top), H)
			make(m, head, "Snout", V(0.5, 0.3, 0.55), CF(top + V(0, -0.08, -0.58)), H2)
			for _, side in { -1, 1 } do
				glow(m, head, "Eye", V(0.17, 0.12, 0.045), CF(top + V(side * 0.23, 0.12, -0.42)), pal)
				wedge(
					m,
					head,
					"Horn",
					V(0.13, 0.47, 0.22),
					CF(top + V(side * 0.23, 0.4, 0.15)) * A(rad(30), 0, rad(-side * 15)),
					H2
				)
			end
			limb(m, head, "Jaw", V(0.5, 0.13, 0.6), CF(top + V(0, -0.32, -0.48)), top + V(0, -0.2, -0.1), "Jaw", 1, H2)
		end
		for _, s in { -1, 1 } do
			local a = V(s * 0.65, 2.85, 0.6)
			local b = V(s * 1.9, 4.6, 0.95)
			local c = V(s * 3.9, 2.35, 1.1)
			local d = V(s * 1.3, 2.2, 0.8)
			local w = limb(m, body, "Wing", V(0.2, 0.3, 0.3), CF(a), a, "Wing", s, H2)
			triangle(m, w, "WingMembrane", a, b, d, 0.09, H2)
			triangle(m, w, "WingMembrane", b, c, d, 0.09, H2)
			beam(m, w, "WingFinger", a, b, 0.14, 0.16, H)
			beam(m, w, "WingFinger", b, c, 0.13, 0.15, H)
			beam(m, w, "WingEdge", c, d, 0.07, 0.07, pal.Glow).Material = Enum.Material.Neon
			beam(m, w, "WingEdge", b, (b + c) / 2, 0.06, 0.06, pal.Glow).Material = Enum.Material.Neon
			leg(m, body, s * 0.52, 1.55, 0.25, 0.6, H, H2, 2)
			tail(
				m,
				body,
				{ V(s * 0.25, 1.5, 0.85), V(s * 0.5, 0.85, 1.65), V(s * 0.85, 1.0, 2.6), V(s * 1.08, 1.65, 3.3) },
				{ 0.42, 0.32, 0.2 },
				H,
				function(p, i, at, w)
					if i < 3 then
						plate(m, p, "TailSpine", V(0.12, 0.25, 0.27), CF(at + V(0, w * 0.45, 0)), pal).Material =
							Enum.Material.Neon
					end
				end
			)
		end
	end

	function B.Brightsteel(m, pal, H, H2)
		local r = root(m, V(1.7, 1.8, 1.5), 2.1)
		local body = limb(m, r, "Torso", V(1.7, 1.5, 1.2), CF(0, 2.8, 0.1), V(0, 1.75, 0.15), "Body", 1, H)
		local dark = H2:Lerp(Color3.fromRGB(25, 35, 44), 0.5)
		make(m, body, "Waist", V(1.2, 0.25, 1.0), CF(0, 1.9, 0.1), dark, Enum.Material.Metal)
		make(m, body, "HipFrame", V(1.5, 0.4, 1.15), CF(0, 1.62, 0.1), H2, Enum.Material.Metal)
		make(m, body, "ChestHousing", V(1.52, 1.28, 0.22), CF(0, 2.8, -0.56), H2, Enum.Material.Metal)
		for _, s in { -1, 1 } do
			for _, y in { 2.5, 3.04 } do
				make(m, body, "VentSocket", V(0.61, 0.47, 0.1), CF(s * 0.36, y, -0.72), dark)
				glow(m, body, "ReactorWindow", V(0.43, 0.33, 0.055), CF(s * 0.36, y, -0.79), pal)
			end
			make(m, body, "VentLouvre", V(0.43, 0.055, 0.07), CF(s * 0.36, 3.04, -0.83), H)
			local arm = beam(m, body, "Arm", V(s * 0.95, 3.25, 0), V(s * 1.14, 2.6, -0.15), 0.4, 0.45, dark, "Arm", s)
			wedge(m, arm, "UpperArmCase", V(0.58, 0.65, 0.65), CF(s * 1.04, 2.98, -0.12), H)
			beam(m, arm, "Forearm", V(s * 1.14, 2.6, -0.15), V(s * 1.18, 2.02, -0.35), 0.5, 0.54, H2)
			make(m, arm, "Wrist", V(0.54, 0.18, 0.56), CF(s * 1.18, 1.99, -0.35), H)
			make(m, arm, "Palm", V(0.42, 0.27, 0.36), CF(s * 1.18, 1.78, -0.38), H2)
			for i = -1, 1 do
				make(m, arm, "Finger", V(0.1, 0.28, 0.12), CF(s * 1.18 + i * 0.13, 1.55, -0.43), H)
			end
			local l = leg(m, body, s * 0.52, 1.65, 0.2, 0.62, H, H2)
			make(m, l, "ShinPiston", V(0.12, 0.52, 0.13), CF(s * 0.56, 0.53, -0.06), dark, Enum.Material.Metal)
			plate(m, body, "ShoulderInset", V(0.12, 0.32, 0.35), CF(s * 1.02, 3.35, 0), pal)
			wedge(m, body, "ShoulderShell", V(0.65, 0.4, 0.85), CF(s * 0.94, 3.5, 0.1) * A(0, 0, rad(-s * 12)), H)
		end
		for i = 0, 2 do
			make(
				m,
				body,
				"CollarTier",
				V(1.3 - i * 0.3, 0.18, 0.9 - i * 0.14),
				CF(0, 3.6 + i * 0.16, 0.1),
				H,
				Enum.Material.Metal
			)
		end
		local head = make(m, body, "Head", V(0.91, 0.75, 0.9), CF(0, 4.25, -0.12), H)
		make(m, head, "FaceMask", V(0.77, 0.42, 0.16), CF(0, 4.12, -0.63), H2)
		glow(m, head, "Visor", V(0.94, 0.17, 0.07), CF(0, 4.3, -0.61), pal)
		make(m, head, "VisorBrow", V(0.96, 0.15, 0.25), CF(0, 4.49, -0.55), dark)
		wedge(m, head, "Crest", V(0.35, 0.25, 0.67), CF(0, 4.71, -0.05), H)
		limb(m, head, "Jaw", V(0.62, 0.18, 0.5), CF(0, 3.82, -0.38), V(0, 3.92, -0.1), "Jaw", 1, H2)
		tail(
			m,
			body,
			{ V(0, 1.72, 0.75), V(0, 1.0, 1.45), V(0, 0.8, 2.15), V(0, 1.05, 2.75), V(0, 1.45, 3.3) },
			{ 0.54, 0.43, 0.32, 0.22 },
			H,
			function(p, i, at, w)
				plate(m, p, "TailCollar", V(w + 0.05, 0.12, w + 0.06), CF(at), pal)
			end
		)
	end

	function B.Dreadcrown(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.7), 2.0)
		local body = limb(m, r, "Torso", V(1.75, 1.75, 1.35), CF(0, 2.55, 0.1), V(0, 1.6, 0.15), "Body", 1, H2)
		make(m, body, "ChestRim", V(1.5, 1.35, 0.18), CF(0, 2.7, -0.65), H)
		for i = 0, 3 do
			glow(m, body, "StarCore", V(1.0, 0.25, 0.08), CF(0, 2.7, -0.77) * A(0, 0, rad(i * 45)), pal)
		end
		make(m, body, "Pelvis", V(1.25, 0.45, 1.1), CF(0, 1.65, 0.1), H2)
		for _, s in { -1, 1 } do
			wedge(m, body, "ChestFlare", V(0.55, 1.0, 0.3), CF(s * 0.66, 2.7, -0.69) * A(0, 0, rad(-s * 18)), H)
			local arm = beam(m, body, "Arm", V(s * 1.0, 3.16, -0.05), V(s * 1.25, 2.6, -0.35), 0.6, 0.65, H, "Arm", s)
			beam(m, arm, "Forearm", V(s * 1.25, 2.6, -0.35), V(s * 1.35, 2.2, -0.85), 0.52, 0.6, H2)
			local base = CF(s * 1.35, 2.05, -0.85) * A(rad(20), 0, 0)
			make(m, arm, "PincerBase", V(0.73, 0.4, 0.45), base, H)
			for _, j in { -1, 1 } do
				wedge(
					m,
					arm,
					"PincerBlade",
					V(0.25, 0.7, 0.4),
					base * CF(j * 0.3, -0.45, -0.05) * A(0, 0, rad(-j * 18)),
					if j == 1 then H else H2
				)
			end
			local a = V(s * 0.62, 3.1, 0.6)
			local b = V(s * 1.4, 3.9, 0.8)
			local c = V(s * 2.28, 2.35, 0.95)
			local d = V(s * 0.85, 2.65, 0.7)
			local w = limb(m, body, "Wing", V(0.2, 0.2, 0.2), CF(a), a, "Wing", s, H2)
			triangle(m, w, "Membrane", a, b, c, 0.08, H)
			triangle(m, w, "Membrane", a, c, d, 0.08, H)
			beam(m, w, "WingEdge", b, c, 0.13, 0.14, H2)
			leg(m, body, s * 0.57, 1.7, 0.25, 0.7, H, H2)
		end
		local head = make(m, body, "Head", V(1.05, 0.8, 1.0), CF(0, 3.85, -0.22), H)
		make(m, head, "Face", V(0.75, 0.45, 0.3), CF(0, 3.75, -0.8), H)
		face(m, head, CF(0, 3.97, -0.75), 0.9, pal, H, H2)
		limb(m, head, "Jaw", V(0.7, 0.2, 0.65), CF(0, 3.35, -0.6), V(0, 3.45, -0.2), "Jaw", 1, H2)
		for i = -2, 2 do
			local a = V(i * 0.2, 4.18, -0.18)
			local b = V(i * 0.35, 4.65 + math.abs(i) * 0.08, -0.13)
			local c = b + V(i * 0.02, 0.42, -0.1)
			beam(m, head, "CrownAntler", a, b, 0.22, 0.25, H2)
			wedge(m, head, "CrownTine", V(0.18, 0.5, 0.2), CF((b + c) / 2), H2)
			plate(m, head, "CrownTip", V(0.14, 0.19, 0.16), CF(c), pal).Material = Enum.Material.Neon
		end
		tail(
			m,
			body,
			{ V(0, 1.65, 0.8), V(0, 0.85, 1.5), V(0, 0.75, 2.3), V(0, 1.1, 3.0), V(0, 1.6, 3.5) },
			{ 0.65, 0.5, 0.36, 0.22 },
			H,
			function(p, i, at, w)
				plate(m, p, "TailProng", V(0.16, 0.36, 0.3), CF(at + V(0, w * 0.5, 0)), pal)
			end
		)
	end

	function B.Bladebrow(m, pal, H, H2)
		local r = root(m, V(2, 1.8, 1.7), 2.1)
		local body = limb(
			m,
			r,
			"Torso",
			V(2.05, 2.1, 1.35),
			CF(0, 2.85, 0.15) * A(rad(-9), 0, 0),
			V(0, 1.75, 0.2),
			"Body",
			1,
			H2
		)
		for _, s in { -1, 1 } do
			wedge(m, body, "Pectoral", V(0.95, 0.85, 0.45), CF(s * 0.51, 3.35, -0.58) * A(0, 0, rad(s * 7)), H)
			for i = 0, 1 do
				wedge(m, body, "Abdominal", V(0.55, 0.42, 0.3), CF(s * 0.3, 2.66 - i * 0.46, -0.61), H)
			end
			make(m, body, "ShoulderMass", V(0.95, 0.85, 0.95), CF(s * 1.2, 3.65, 0.05) * A(0, 0, rad(-s * 18)), H)
			local arm = beam(m, body, "Arm", V(s * 1.18, 3.55, 0.05), V(s * 1.52, 2.75, -0.15), 0.6, 0.65, H2, "Arm", s)
			wedge(m, arm, "Forearm", V(0.7, 0.85, 0.67), CF(s * 1.56, 2.35, -0.4) * A(rad(20), 0, rad(s * 12)), H)
			talonHand(m, arm, V(s * 1.6, 1.85, -0.62), 1.22, H2)
			local small = beam(m, body, "Arm", V(s * 0.9, 2.7, -0.25), V(s * 1.0, 2.15, -0.55), 0.37, 0.4, H, "Arm", s)
			talonHand(m, small, V(s * 0.9, 1.97, -0.93), 0.7, H2)
			leg(m, body, s * 0.64, 1.85, 0.2, 0.85, H, H2, 2)
		end
		local head = make(m, body, "Head", V(0.85, 0.7, 0.85), CF(0, 4.18, -0.45) * A(rad(-12), 0, 0), H)
		face(m, head, CF(0, 4.23, -0.91), 0.8, pal, H, H2)
		limb(m, head, "Jaw", V(0.6, 0.2, 0.6), CF(0, 3.75, -0.75), V(0, 3.85, -0.4), "Jaw", 1, H2)
		-- Broad cleaver profile: long forward reach, deep face, luminous underside.
		make(m, head, "BrowBlade", V(0.42, 0.3, 2.75), CF(0, 4.6, -1.5), H)
		wedge(m, head, "BladeTip", V(0.42, 0.3, 0.55), CF(0, 4.6, -3.1), H)
		plate(m, head, "BladeBack", V(0.44, 0.12, 0.7), CF(0, 4.78, -0.45), pal)
		glow(m, head, "BladeEdge", V(0.43, 0.075, 2.75), CF(0, 4.44, -1.5), pal)
		tail(
			m,
			body,
			{ V(0, 1.8, 0.8), V(0, 1.0, 1.7), V(0, 1.05, 2.6), V(0, 1.55, 3.3) },
			{ 0.7, 0.5, 0.3 },
			H,
			function(p, i, at, w)
				plate(m, p, "TailBlade", V(0.18, 0.5, 0.65), CF(at + V(0, w * 0.4, 0)) * A(rad(-25), 0, 0), pal)
			end
		)
	end

	function B.Mossback(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.5), 2.15)
		local body = limb(m, r, "Trunk", V(1.65, 2.65, 1.4), CF(0, 2.93, 0.15), V(0, 1.65, 0.2), "Body", 1, H)
		local bark = H:Lerp(Color3.fromRGB(25, 24, 22), 0.3)
		local petal = Color3.fromRGB(126, 57, 72)
		make(m, body, "StumpHeart", V(1.44, 0.08, 1.12), CF(0, 4.29, 0.15), bark)
		for j = 0, 2 do
			make(
				m,
				body,
				"HeartRing",
				V(1.15 - j * 0.26, 0.04, 0.045),
				CF(0, 4.34, -0.25 + j * 0.18) * A(0, rad(j * 9), 0),
				H2
			)
		end
		for i = 0, 4 do
			local x = -0.66 + i * 0.33
			make(
				m,
				body,
				"BarkColumn",
				V(0.25, 2.0 + (i % 3) * 0.23, 0.16 + (i % 2) * 0.08),
				CF(x, 2.9 + (i % 2) * 0.13, -0.61) * A(0, rad((i - 2) * 4), rad((i - 2) * 2)),
				if i % 2 == 0 then bark else H
			)
			wedge(m, body, "BrokenRim", V(0.26, 0.35 + (i % 3) * 0.1, 0.32), CF(x, 4.34, -0.36), H)
		end
		for _, s in { -1, 1 } do
			make(m, body, "SideBark", V(0.2, 2.5, 0.85), CF(s * 0.86, 2.95, 0.2) * A(0, 0, rad(-s * 4)), bark)
			plate(m, body, "MossPatch", V(0.24, 0.45, 0.46), CF(s * 0.9, 3.35, 0.25), pal)
			local shoulder = V(s * 0.98, 3.62, 0.08)
			local elbow = V(s * 1.4, 2.7, -0.12)
			local hand = V(s * 1.62, 1.65, -0.48)
			local arm = beam(m, body, "Arm", shoulder, elbow, 0.25, 0.3, bark, "Arm", s)
			beam(m, arm, "Forearm", elbow, hand, 0.22, 0.28, H)
			for _, phase in { 0, math.pi } do
				local function vinePoint(i)
					local angle = phase + i * math.pi * 0.65
					return shoulder:Lerp(hand, i / 4) + V(math.cos(angle) * 0.28, 0, math.sin(angle) * 0.25 - 0.07)
				end
				for i = 0, 3 do
					beam(m, arm, "TwistingVine", vinePoint(i), vinePoint(i + 1), 0.13, 0.14, H2)
				end
			end
			for j = -1, 1 do
				local f = hand + V(j * 0.17, -0.1, -0.08)
				beam(m, arm, "RootFinger", f, f + V(j * 0.09, -0.35, -0.12), 0.12, 0.15, H2)
				glow(m, arm, "LuminousBud", V(0.14, 0.15, 0.16), CF(f + V(j * 0.09, -0.4, -0.12)), pal)
			end
			local l = beam(m, body, "RootLeg", V(s * 0.5, 1.7, 0.2), V(s * 0.65, 0.8, 0.03), 0.56, 0.65, H, "Stride", s)
			beam(m, l, "RootShin", V(s * 0.65, 0.85, 0.03), V(s * 0.55, 0.25, 0.15), 0.42, 0.45, bark)
			beam(m, l, "LegVine", V(s * 0.7, 1.5, -0.15), V(s * 0.48, 0.35, -0.26), 0.14, 0.16, H2)
			for j = -1, 1 do
				beam(m, l, "RootToe", V(s * 0.55, 0.35, 0.15), V(s * 0.55 + j * 0.24, 0.08, -0.45), 0.16, 0.16, H)
			end
			wedge(m, l, "RootFlare", V(0.3, 0.6, 0.5), CF(s * 0.88, 0.3, 0.15) * A(0, 0, rad(-s * 20)), H)
		end
		local rose = CF(0.1, 3.45, -0.76)
		make(m, body, "FlowerThroat", V(0.7, 0.7, 0.22), rose, bark)
		glow(m, body, "Bloom", V(0.42, 0.48, 0.08), rose * CF(0, 0, -0.14), pal)
		for i = 0, 5 do
			local f = rose * A(rad((i % 3 - 1) * 10), 0, rad(i * 60 + (i % 2) * 8))
			wedge(m, body, "OuterPetal", V(0.43, 0.48, 0.25), f * CF(0, 0.5, 0), petal)
			wedge(
				m,
				body,
				"InnerPetal",
				V(0.32, 0.32, 0.16),
				f * A(0, 0, rad(25)) * CF(0, 0.33, -0.14),
				petal:Lerp(H, 0.2)
			)
		end
		limb(m, body, "Jaw", V(0.62, 0.2, 0.35), CF(0.1, 2.85, -0.7), V(0.1, 2.98, -0.6), "Jaw", 1, bark)
		for i = 0, 3 do
			plate(
				m,
				body,
				"MossClump",
				V(0.3, 0.12, 0.28),
				CF(-0.55 + (i % 2) * 1.1, 4.29, 0.4 - math.floor(i / 2) * 0.65),
				pal
			)
		end
	end

	-- A joint turned at its pivot (its rest pose unchanged): a wing held
	-- upright flaps about the vertical, not about its own plane.
	local function reseat(p, frame: CFrame)
		local joint = p:FindFirstChild("CreatureMotion")
		joint.C0 = joint.Part0.CFrame:Inverse() * frame
		joint.C1 = p.CFrame:Inverse() * frame
		joint:SetAttribute("CreatureRest", joint.C0)
	end
	local function lit(m, p, name, size, cf, pal)
		return make(m, p, name, size, cf, pal.Glow, Enum.Material.Neon)
	end

	-- Moonmoth: a furry pale moth, four great wings held up in a V, cream
	-- blotched with dusk, a glowing window in each; feathered feelers.
	function B.Moonmoth(m, pal, H, H2)
		local r = root(m, V(1.2, 1.2, 1.2), 1.55)
		local body = limb(m, r, "Thorax", V(1.0, 1.1, 1.15), CF(0, 1.7, 0.05), V(0, 1.4, 0.1), "Body", 1, H)
		make(m, body, "Fur", V(1.25, 0.55, 1.05), CF(0, 2.12, -0.05), H)
		make(m, body, "Fur", V(0.8, 0.3, 0.9), CF(0, 2.38, 0), H2)
		make(m, body, "Collar", V(1.15, 0.22, 0.9), CF(0, 1.3, -0.05), H2)
		local head = make(m, body, "Head", V(0.78, 0.68, 0.62), CF(0, 2.05, -0.72), H)
		for _, s in { -1, 1 } do
			lit(m, head, "Eye", V(0.22, 0.3, 0.1), CF(s * 0.25, 2.1, -1.02), pal)
			local stalk = CF(s * 0.18, 2.42, -0.7) * A(rad(-20), 0, rad(-s * 28))
			make(m, head, "Feeler", V(0.08, 0.85, 0.08), stalk * CF(0, 0.38, 0), H2)
			for i = 0, 2 do
				plate(m, head, "Plume", V(0.34, 0.07, 0.06), stalk * CF(0, 0.35 + i * 0.2, 0) * A(0, 0, rad(-s * 10)), pal)
			end
		end
		local jaw = limb(m, head, "Jaw", V(0.4, 0.14, 0.32), CF(0, 1.7, -0.9), V(0, 1.76, -0.72), "Jaw", 1, H2)
		make(m, jaw, "Proboscis", V(0.07, 0.07, 0.36), CF(0, 1.64, -1.2), H2)
		-- A wing: a cream sheet standing up and out, blotched, a lit window.
		local function wingSheet(parent, frame, w, h, s, windows, blots)
			make(m, parent, "WingSheet", V(w, h, 0.1), frame * CF(s * w / 2, h / 2, 0), H)
			plate(m, parent, "WingRim", V(0.14, h, 0.12), frame * CF(s * (w - 0.07), h / 2, 0), pal)
			make(m, parent, "WingRim", V(w, 0.14, 0.12), frame * CF(s * w / 2, h - 0.07, 0), H2)
			for _, b in blots do
				make(m, parent, "Blot", V(b[3], b[4], 0.12), frame * CF(s * b[1], b[2], 0), H2)
			end
			for _, g in windows do
				lit(m, parent, "Window", V(g[3], g[4], 0.14), frame * CF(s * g[1], g[2], 0), pal)
			end
		end
		for _, s in { -1, 1 } do
			local hinge = V(s * 0.45, 2.0, 0.1)
			local frame = CF(hinge) * A(rad(-14), rad(-s * 12), rad(s * 38))
			local up = limb(m, body, "Wing", V(0.3, 0.3, 0.14), frame * CF(s * 0.15, 0.15, 0), hinge, "Wing", s, H)
			reseat(up, CF(hinge) * A(rad(90), 0, 0))
			wingSheet(up, frame, 2.4, 2.1, s, { { 1.7, 1.45, 0.55, 0.5 }, { 0.75, 0.55, 0.3, 0.3 } }, {
				{ 0.6, 1.6, 0.9, 0.5 },
				{ 1.9, 0.5, 0.5, 0.7 },
				{ 1.2, 1.0, 0.4, 0.3 },
			})
			local hinge2 = V(s * 0.42, 1.45, 0.25)
			local frame2 = CF(hinge2) * A(rad(-10), rad(-s * 18), rad(s * 72))
			local low = limb(m, body, "Wing", V(0.3, 0.3, 0.14), frame2 * CF(s * 0.15, 0.15, 0), hinge2, "Wing", s, H)
			reseat(low, CF(hinge2) * A(rad(90), 0, 0))
			wingSheet(low, frame2, 1.7, 1.25, s, { { 1.15, 0.7, 0.4, 0.4 } }, { { 0.5, 0.3, 0.6, 0.35 }, { 1.4, 1.0, 0.3, 0.25 } })
			local l = beam(m, body, "Leg", V(s * 0.3, 1.2, -0.2), V(s * 0.36, 0.18, -0.28), 0.1, 0.1, H2, "Stride", s)
			make(m, l, "Foot", V(0.16, 0.08, 0.26), CF(s * 0.36, 0.04, -0.3), H2)
		end
		tail(
			m,
			body,
			{ V(0, 1.45, 0.5), V(0, 1.05, 1.1), V(0, 0.75, 1.6), V(0, 0.55, 2.0) },
			{ 0.72, 0.6, 0.42 },
			H2,
			function(p, i, at, w)
				make(m, p, "FurBand", V(w + 0.1, w * 0.55, 0.22), CF(at), H)
			end
		)
	end

	-- Shellfire: a tusked turtle under a domed shell, tan, every seam
	-- between its scutes aglow; a jet in each leg hole.
	function B.Shellfire(m, pal, H, H2)
		local r = root(m, V(2.4, 1, 2.6), 1.15)
		local body = limb(m, r, "Belly", V(2.5, 0.7, 2.9), CF(0, 0.95, 0), V(0, 0.9, 0), "Body", 1, H2)
		make(m, body, "ShellRim", V(3.1, 0.42, 3.5), CF(0, 1.45, 0.05), H)
		make(m, body, "ShellRim", V(2.7, 0.42, 3.1), CF(0, 1.82, 0.05), H)
		local top = make(m, body, "ShellTop", V(1.5, 0.35, 1.7), CF(0, 2.55, 0.05), H)
		-- The dome: a sloping wedge on each side of the top, a corner between.
		for _, s in { -1, 1 } do
			wedge(m, body, "Scute", V(1.3, 0.5, 1.75), CF(s * 1.1, 2.3, 0.05) * A(0, rad(-s * 90), 0), H)
			wedge(m, body, "Scute", V(1.5, 0.5, 0.9), CF(0, 2.3, 0.05 + s * 1.3) * A(0, if s > 0 then math.pi else 0, 0), H)
			wedge(m, body, "ScuteCorner", V(1.0, 0.5, 0.95), CF(s * 1.0, 2.25, 1.35) * A(0, rad(180 - s * 45), 0), H2)
			wedge(m, body, "ScuteCorner", V(1.0, 0.5, 0.95), CF(s * 1.0, 2.25, -1.25) * A(0, rad(-s * 45), 0), H2)
		end
		-- The seams: a hexagon round the top, a spoke down each slope.
		local seams = {
			{ V(-0.72, 2.74, -0.5), V(0, 2.74, -0.95) },
			{ V(0, 2.74, -0.95), V(0.72, 2.74, -0.5) },
			{ V(0.72, 2.74, -0.5), V(0.72, 2.74, 0.6) },
			{ V(0.72, 2.74, 0.6), V(0, 2.74, 1.05) },
			{ V(0, 2.74, 1.05), V(-0.72, 2.74, 0.6) },
			{ V(-0.72, 2.74, 0.6), V(-0.72, 2.74, -0.5) },
			{ V(0, 2.74, -0.95), V(0, 2.08, -1.8) },
			{ V(0, 2.74, 1.05), V(0, 2.08, 1.9) },
			{ V(0.72, 2.74, -0.5), V(1.5, 2.05, -1.1) },
			{ V(-0.72, 2.74, -0.5), V(-1.5, 2.05, -1.1) },
			{ V(0.72, 2.74, 0.6), V(1.5, 2.05, 1.3) },
			{ V(-0.72, 2.74, 0.6), V(-1.5, 2.05, 1.3) },
			{ V(1.5, 2.05, -1.1), V(1.5, 2.05, 1.3) },
			{ V(-1.5, 2.05, -1.1), V(-1.5, 2.05, 1.3) },
		}
		local ember = pal.Plate:Lerp(pal.Glow, 0.35)
		for _, line in seams do
			beam(m, top, "Seam", line[1], line[2], 0.08, 0.08, ember).Material = Enum.Material.Neon
		end
		for i = 0, 3 do
			plate(m, top, "ScuteTile", V(0.2, 0.06, 0.2), CF(-0.3 + (i % 2) * 0.6, 2.75, -0.2 + math.floor(i / 2) * 0.5), pal)
		end
		local head = make(m, body, "Head", V(1.05, 0.9, 1.0), CF(0, 1.3, -2.05), H)
		make(m, head, "Beak", V(0.85, 0.55, 0.55), CF(0, 1.2, -2.75), H2)
		make(m, head, "Brow", V(1.1, 0.2, 0.5), CF(0, 1.78, -2.25), H2)
		for _, s in { -1, 1 } do
			lit(m, head, "Eye", V(0.14, 0.16, 0.14), CF(s * 0.42, 1.55, -2.5), pal)
			make(m, head, "Tusk", V(0.16, 0.5, 0.16), CF(s * 0.36, 1.2, -2.95) * A(rad(-25), 0, rad(s * 8)), Color3.fromRGB(236, 230, 220))
		end
		limb(m, head, "Jaw", V(0.8, 0.26, 0.85), CF(0, 0.85, -2.45), V(0, 0.95, -2.0), "Jaw", 1, H2)
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 1.2, spot[2] * 1.05
			local l = beam(m, body, "Leg", V(x, 1.0, z), V(x * 1.05, 0.2, z), 0.78, 0.8, H2, "Stride", -spot[1] * spot[2])
			make(m, l, "Foot", V(0.9, 0.3, 0.95), CF(x * 1.05, 0.15, z - 0.05), H)
			make(m, l, "JetHole", V(0.5, 0.5, 0.12), CF(x, 1.1, z + spot[2] * 0.5), H)
			lit(m, l, "Jet", V(0.36, 0.36, 0.1), CF(x, 1.1, z + spot[2] * 0.56), pal)
			for i = -1, 1 do
				make(m, l, "Toe", V(0.2, 0.18, 0.28), CF(x * 1.05 + i * 0.3, 0.09, z - 0.6), H2)
			end
		end
		tail(m, body, { V(0, 1.0, 1.4), V(0, 0.75, 2.0), V(0, 0.55, 2.5) }, { 0.5, 0.3 }, H2)
	end

	-- Dreadmaw: a bone-white runner that is mostly skull, its jaws wide and
	-- its throat a well of light.
	function B.Dreadmaw(m, pal, H, H2)
		local r = root(m, V(1.6, 1.4, 2.2), 2.0)
		local back = CF(0, 2.1, 0.45) * A(rad(-5), 0, 0)
		local body = limb(m, r, "Body", V(1.1, 1.1, 2.3), back, V(0, 2.0, 0.5), "Body", 1, H)
		for i = 0, 2 do
			make(m, body, "Rib", V(1.3, 0.7, 0.18), back * CF(0, -0.15, -0.5 + i * 0.5), H2)
		end
		for i = 0, 3 do
			plate(m, body, "Ridge", V(0.3, 0.3, 0.3), back * CF(0, 0.7, -0.8 + i * 0.5) * A(rad(45), 0, 0), pal)
		end
		local bone = Color3.fromRGB(240, 236, 226)
		local skull = make(m, body, "Skull", V(1.8, 0.8, 2.4), CF(0, 3.2, -1.95), H)
		make(m, skull, "Brow", V(1.9, 0.3, 1.1), CF(0, 3.72, -1.55), H2)
		make(m, skull, "Crest", V(0.6, 0.35, 1.1), CF(0, 3.85, -0.85), H)
		for _, s in { -1, 1 } do
			make(m, skull, "Socket", V(0.42, 0.3, 0.2), CF(s * 0.6, 3.42, -2.4), H2)
			lit(m, skull, "Eye", V(0.22, 0.12, 0.08), CF(s * 0.6, 3.4, -2.52), pal)
			make(m, skull, "Cheek", V(0.26, 0.5, 1.3), CF(s * 1.03, 2.95, -1.6), H2)
		end
		-- The mouth: a well of light between the skull and the jaw.
		lit(m, skull, "Throat", V(1.3, 0.75, 1.5), CF(0, 2.5, -1.4), pal)
		for _, x in { -0.65, -0.32, 0, 0.32, 0.65 } do
			make(m, skull, "Fang", V(0.16, 0.36, 0.16), CF(x, 2.62, if math.abs(x) < 0.2 then -3.1 else -2.95), bone)
		end
		local jaw = limb(m, skull, "Jaw", V(1.7, 0.5, 2.3), CF(0, 1.85, -2.3) * A(rad(16), 0, 0), V(0, 2.15, -1.1), "Jaw", 1, H)
		lit(m, jaw, "Tongue", V(1.0, 0.16, 1.5), CF(0, 2.12, -2.15) * A(rad(16), 0, 0), pal)
		for _, x in { -0.65, -0.22, 0.22, 0.65 } do
			make(m, jaw, "Fang", V(0.16, 0.32, 0.16), CF(x, 2.3, -3.15) * A(rad(16), 0, 0), bone)
		end
		for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = spot[1] * 0.6, if spot[2] < 0 then -0.45 else 1.2
			local hip = V(x, 1.75, z)
			local l = beam(m, body, "Leg", hip, V(x * 1.05, 0.25, z + 0.1), 0.42, 0.45, H, "Stride", -spot[1] * spot[2])
			make(m, l, "Thigh", V(0.55, 0.8, 0.75), CF(x * 1.02, 1.45, z), H2)
			make(m, l, "Foot", V(0.5, 0.28, 0.72), CF(x * 1.05, 0.14, z - 0.1), H2)
			for i = -1, 1 do
				make(m, l, "Toe", V(0.12, 0.14, 0.26), CF(x * 1.05 + i * 0.17, 0.08, z - 0.55), bone)
			end
		end
		tail(
			m,
			body,
			{ V(0, 2.2, 1.6), V(0, 2.3, 2.4), V(0, 2.45, 3.2), V(0, 2.35, 3.9) },
			{ 0.4, 0.26, 0.16 },
			H
		)
	end

	-- Sporeback: a heap of mossy rock on stub feet, lit cracks all over
	-- it, two square windows for eyes.
	function B.Sporeback(m, pal, H, H2)
		local r = root(m, V(2.2, 1.4, 2.2), 1.5)
		local body = limb(m, r, "Heap", V(2.7, 1.9, 2.5), CF(0, 1.45, 0.1), V(0, 0.9, 0.1), "Body", 1, H)
		make(m, body, "Heap", V(2.2, 1.3, 2.1), CF(0, 2.55, 0.2), H)
		make(m, body, "Crown", V(1.3, 0.8, 1.3), CF(0, 3.45, 0.3), H2)
		for _, lump in
			{
				{ -1.25, 1.15, -0.6, 0.8, 0.7, 0.75 },
				{ 1.3, 1.25, -0.2, 0.75, 0.8, 0.8 },
				{ -1.05, 2.3, 0.7, 0.7, 0.6, 0.7 },
				{ 1.1, 2.1, 0.85, 0.65, 0.7, 0.65 },
				{ 0.3, 1.1, 1.35, 0.9, 0.55, 0.6 },
				{ -0.6, 3.1, -0.55, 0.6, 0.5, 0.55 },
				{ 0.75, 3.2, 0.35, 0.55, 0.55, 0.5 },
				{ -0.9, 0.9, 0.9, 0.6, 0.5, 0.6 },
			}
		do
			make(m, body, "Lump", V(lump[4], lump[5], lump[6]), CF(lump[1], lump[2], lump[3]) * A(0, rad(lump[1] * 20), 0), H2)
		end
		local brow = make(m, body, "Brow", V(1.9, 0.5, 0.5), CF(0, 3.25, -0.95), H2)
		for _, s in { -1, 1 } do
			make(m, brow, "Socket", V(0.7, 0.62, 0.25), CF(s * 0.5, 3.05, -1.15), H)
			lit(m, brow, "Eye", V(0.56, 0.48, 0.1), CF(s * 0.5, 3.05, -1.3), pal)
		end
		local cracks = {
			{ V(-0.8, 2.6, -1.25), V(-0.45, 2.15, -1.3) },
			{ V(-0.45, 2.15, -1.3), V(-0.7, 1.6, -1.32) },
			{ V(0.55, 2.35, -1.3), V(0.85, 1.85, -1.25) },
			{ V(0.85, 1.85, -1.25), V(0.6, 1.3, -1.35) },
			{ V(0.1, 1.9, -1.35), V(0.2, 1.4, -1.33) },
			{ V(-1.37, 1.9, -0.3), V(-1.4, 1.4, 0.2) },
			{ V(-1.4, 1.4, 0.2), V(-1.33, 0.9, -0.1) },
			{ V(1.38, 2.0, 0.1), V(1.4, 1.5, -0.4) },
			{ V(0.4, 3.0, -1.1), V(0.1, 3.5, -0.65) },
			{ V(-0.95, 2.9, 0.3), V(-1.12, 2.4, -0.2) },
		}
		for _, line in cracks do
			beam(m, body, "Crack", line[1], line[2], 0.075, 0.075, pal.Glow).Material = Enum.Material.Neon
		end
		for _, cap in { { -0.55, 3.9, 0.5 }, { 0.6, 3.85, 0.1 }, { 0.95, 3.4, 1.0 }, { -1.1, 3.05, 0.95 }, { 0.2, 3.95, 0.8 } } do
			plate(m, body, "Spore", V(0.32, 0.18, 0.32), CF(cap[1], cap[2], cap[3]), pal)
			make(m, body, "SporeStalk", V(0.14, 0.2, 0.14), CF(cap[1], cap[2] - 0.15, cap[3]), H2)
		end
		limb(m, body, "Jaw", V(1.3, 0.3, 0.35), CF(0, 2.3, -1.3), V(0, 2.45, -1.15), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local arm = beam(m, body, "Arm", V(s * 1.3, 2.0, -0.6), V(s * 1.55, 1.1, -0.9), 0.5, 0.5, H2, "Arm", s)
			make(m, arm, "Fist", V(0.55, 0.45, 0.55), CF(s * 1.58, 0.75, -0.95), H)
			local l = beam(m, body, "Leg", V(s * 0.7, 0.9, 0.1), V(s * 0.75, 0.25, 0.1), 0.65, 0.7, H2, "Stride", s)
			make(m, l, "Foot", V(0.8, 0.28, 0.9), CF(s * 0.75, 0.14, -0.05), H)
		end
		tail(m, body, { V(0, 0.9, 1.3), V(0, 0.75, 1.95) }, { 0.9 }, H)
	end

	-- Thornlob: a squat lilac spider, round and low, a cluster of lit eyes
	-- on its face and lit fangs, eight thick legs.
	function B.Thornlob(m, pal, H, H2)
		local r = root(m, V(1.8, 1.2, 1.8), 1.55)
		local body = limb(m, r, "Body", V(2.0, 1.55, 1.9), CF(0, 1.85, -0.1), V(0, 1.5, 0), "Body", 1, H)
		make(m, body, "Crown", V(1.6, 0.45, 1.5), CF(0, 2.75, -0.05), H)
		for _, s in { -1, 1 } do
			wedge(m, body, "Cheek", V(0.5, 1.2, 0.9), CF(s * 1.0, 1.9, -0.2) * A(0, rad(s * 90), 0), H2)
		end
		make(m, body, "Face", V(1.45, 1.1, 0.2), CF(0, 1.95, -1.05), H2)
		for _, spot in
			{ { -0.42, 2.25, 0.2 }, { 0, 2.3, 0.26 }, { 0.42, 2.25, 0.2 }, { -0.22, 1.95, 0.22 }, { 0.22, 1.95, 0.22 }, { -0.5, 1.72, 0.16 }, { 0.5, 1.72, 0.16 }, { 0, 1.65, 0.16 } }
		do
			lit(m, body, "Eye", V(spot[3], spot[3], 0.1), CF(spot[1], spot[2], -1.18), pal)
		end
		local jaw = limb(m, body, "Jaw", V(0.9, 0.3, 0.4), CF(0, 1.3, -1.05), V(0, 1.45, -0.9), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			lit(m, jaw, "Fang", V(0.14, 0.4, 0.14), CF(s * 0.28, 1.05, -1.15) * A(rad(10), 0, 0), pal)
		end
		local abdomen = tail(m, body, { V(0, 1.8, 0.8), V(0, 1.7, 1.75) }, { 1.6 }, H2, function(p, _, at)
			for _, z in { -0.3, 0.25 } do
				plate(m, p, "Band", V(1.66, 0.16, 0.22), CF(at + V(0, 0.62, z)), pal)
			end
			make(m, p, "Rump", V(1.2, 1.1, 0.5), CF(at + V(0, 0, 0.55)), H)
		end)
		local _ = abdomen
		for i, z in { -0.7, -0.25, 0.2, 0.65 } do
			for _, s in { -1, 1 } do
				local hip = V(s * 0.95, 1.6, z)
				local knee = V(s * 1.75, 2.1, z * 1.5)
				local foot = V(s * 2.25, 0.2, z * 1.9)
				local thigh = beam(m, body, "Leg", hip, knee, 0.42, 0.38, H, "Stride", s * (if i % 2 == 1 then 1 else -1))
				beam(m, thigh, "Shin", knee, foot, 0.34, 0.32, H2)
				plate(m, thigh, "KneeBand", V(0.5, 0.2, 0.5), CF(knee), pal)
				make(m, thigh, "Foot", V(0.34, 0.2, 0.44), CF(foot + V(0, -0.1, -0.05)), H2)
			end
		end
	end

	-- Titanfin: a steel-blue biped on a long neck, a lit hook for a crest,
	-- a great fan of fins rising from its back.
	function B.Titanfin(m, pal, H, H2)
		local r = root(m, V(1.6, 1.6, 1.8), 2.05)
		local lean = CF(0, 2.45, 0.2) * A(rad(-10), 0, 0)
		local body = limb(m, r, "Body", V(1.45, 1.7, 1.6), lean, V(0, 1.8, 0.3), "Body", 1, H)
		make(m, body, "Belly", V(1.0, 1.2, 0.18), lean * CF(0, -0.1, -0.85), H2)
		make(m, body, "Hips", V(1.4, 0.6, 1.4), CF(0, 1.7, 0.3), H2)
		local neck = beam(m, body, "Neck", V(0, 3.0, -0.35), V(0, 4.35, -0.7), 0.5, 0.55, H)
		make(m, neck, "NeckPlate", V(0.3, 1.2, 0.15), CF(0, 3.7, -0.85) * A(rad(-14), 0, 0), H2)
		local head = make(m, neck, "Head", V(0.68, 0.55, 1.05), CF(0, 4.6, -1.0), H)
		make(m, head, "Snout", V(0.5, 0.36, 0.55), CF(0, 4.5, -1.7), H2)
		lit(m, head, "Hook", V(0.42, 0.18, 0.95), CF(0, 4.95, -1.0), pal)
		lit(m, head, "Hook", V(0.42, 0.5, 0.18), CF(0, 4.8, -1.55), pal)
		for _, s in { -1, 1 } do
			lit(m, head, "Eye", V(0.06, 0.12, 0.2), CF(s * 0.35, 4.66, -1.3), pal)
		end
		limb(m, head, "Jaw", V(0.5, 0.18, 0.9), CF(0, 4.24, -1.35), V(0, 4.32, -0.9), "Jaw", 1, H2)
		-- The fan: seven fins rising from the shoulders, splayed, each tipped in light.
		local hub = CF(0, 2.75, 0.8) * A(rad(-30), 0, 0)
		for k = -3, 3 do
			local spoke = hub * A(0, 0, rad(k * 27))
			local len = 2.6 - math.abs(k) * 0.25
			plate(m, body, "Fan", V(0.46, len, 0.14), spoke * CF(0, len / 2 + 0.2, 0), pal)
			make(m, body, "FanRib", V(0.14, len, 0.18), spoke * CF(0, len / 2 + 0.2, 0), H2)
			lit(m, body, "FanTip", V(0.5, 0.34, 0.16), spoke * CF(0, len + 0.3, 0), pal)
		end
		for _, s in { -1, 1 } do
			local arm = beam(m, body, "Arm", V(s * 0.8, 3.0, -0.35), V(s * 1.0, 2.35, -0.55), 0.34, 0.36, H, "Arm", s)
			beam(m, arm, "Forearm", V(s * 1.0, 2.35, -0.55), V(s * 0.95, 2.0, -1.0), 0.3, 0.32, H2)
			for i = -1, 1, 2 do
				lit(m, arm, "Claw", V(0.08, 0.3, 0.1), CF(s * 0.95 + i * 0.1, 1.85, -1.1) * A(rad(-30), 0, 0), pal)
			end
			leg(m, body, s * 0.5, 1.75, 0.35, 0.68, H, H2, 3)
		end
		tail(m, body, { V(0, 1.75, 0.9), V(0, 1.45, 1.6), V(0, 1.3, 2.2) }, { 0.65, 0.42 }, H, function(p, i, at, w)
			plate(m, p, "TailFin", V(0.12, 0.45, 0.5), CF(at + V(0, w * 0.5, 0)), pal)
		end)
	end

	-- Razorclaw: a navy brute hunched on two legs, bat wings folded up
	-- behind it, a lit sac in its throat and a lit pincer on its tail.
	function B.Razorclaw(m, pal, H, H2)
		local r = root(m, V(1.8, 1.8, 1.8), 2.0)
		local lean = CF(0, 2.5, 0.2) * A(rad(-22), 0, 0)
		local body = limb(m, r, "Torso", V(1.7, 1.9, 1.5), lean, V(0, 1.7, 0.3), "Body", 1, H)
		make(m, body, "Hips", V(1.5, 0.6, 1.35), CF(0, 1.65, 0.3), H2)
		make(m, body, "Hump", V(1.5, 0.5, 1.1), lean * CF(0, 1.05, 0.3), H2)
		local head = make(m, body, "Head", V(1.15, 0.85, 1.2), CF(0, 3.55, -0.95), H)
		make(m, head, "Snout", V(0.9, 0.5, 0.75), CF(0, 3.4, -1.75), H2)
		for _, s in { -1, 1 } do
			lit(m, head, "Eye", V(0.16, 0.1, 0.1), CF(s * 0.42, 3.72, -1.55), pal)
			make(m, head, "Horn", V(0.18, 0.5, 0.3), CF(s * 0.4, 4.1, -0.7) * A(rad(-30), 0, rad(-s * 10)), H2)
		end
		lit(m, head, "Sac", V(0.95, 0.75, 0.9), CF(0, 2.85, -1.2), pal)
		limb(m, head, "Jaw", V(0.85, 0.26, 0.9), CF(0, 3.05, -1.7), V(0, 3.15, -1.25), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			local a = V(s * 0.6, 3.5, 0.55)
			local b = V(s * 1.4, 4.75, 0.75)
			local c = V(s * 2.5, 3.3, 0.95)
			local d = V(s * 1.05, 2.9, 0.7)
			local w = limb(m, body, "Wing", V(0.2, 0.3, 0.3), CF(a), a, "Wing", s, H2)
			triangle(m, w, "WingMembrane", a, b, d, 0.09, H2)
			triangle(m, w, "WingMembrane", b, c, d, 0.09, H2)
			beam(m, w, "WingFinger", a, b, 0.14, 0.16, H)
			beam(m, w, "WingFinger", b, c, 0.12, 0.14, H)
			plate(m, w, "WingHook", V(0.14, 0.3, 0.14), CF(b + V(0, 0.2, 0)), pal)
			local arm = beam(m, body, "Arm", V(s * 0.95, 3.2, -0.3), V(s * 1.25, 2.5, -0.6), 0.5, 0.55, H, "Arm", s)
			beam(m, arm, "Forearm", V(s * 1.25, 2.5, -0.6), V(s * 1.2, 2.05, -1.1), 0.45, 0.5, H2)
			talonHand(m, arm, V(s * 1.2, 1.9, -1.15), 1.0, H2)
			local l = leg(m, body, s * 0.6, 1.7, 0.3, 0.8, H, H2, 3)
			plate(m, l, "ShinPlate", V(0.5, 0.6, 0.16), CF(s * 0.65, 0.75, -0.2), pal)
		end
		tail(
			m,
			body,
			{ V(0, 1.6, 0.85), V(0, 1.0, 1.6), V(0, 0.9, 2.4), V(0, 1.3, 3.1) },
			{ 0.6, 0.45, 0.3 },
			H,
			function(p, i, at, w)
				if i < 3 then
					plate(m, p, "TailBand", V(w + 0.06, w + 0.06, 0.2), CF(at), pal)
				else
					for _, s in { -1, 1 } do
						lit(m, p, "Pincer", V(0.14, 0.14, 0.6), CF(at + V(s * 0.2, 0.25, 0.5)) * A(rad(-30), rad(s * 20), 0), pal)
					end
				end
			end
		)
	end

	-- Longcoil: a jade serpent on two coils, its neck reared high to a
	-- horned dragon head, whiskers and eyes of light.
	function B.Longcoil(m, pal, H, H2)
		local r = root(m, V(2.0, 1.0, 2.0), 1.0)
		local body = limb(m, r, "Coil", V(1.7, 0.75, 1.7), CF(0, 0.42, 0.45), V(0, 0.5, 0.45), "Body", 1, H2)
		for i = 0, 9 do
			local a = rad(i * 36)
			local at = CF(math.cos(a) * 1.35, 0.4, 0.45 + math.sin(a) * 1.35) * A(0, -a, 0)
			make(m, body, "Coil", V(0.8, 0.8, 0.95), at, H)
			plate(m, body, "Scale", V(0.55, 0.1, 0.55), at * CF(0, 0.42, 0), pal)
			make(m, body, "Belly", V(0.5, 0.08, 0.6), at * CF(0, -0.4, 0), H2)
		end
		for i = 0, 6 do
			local a = rad(i * 51 + 25)
			local at = CF(math.cos(a) * 0.95, 1.12, 0.45 + math.sin(a) * 0.95) * A(0, -a, 0)
			make(m, body, "Coil", V(0.7, 0.7, 0.9), at, H)
			if i % 2 == 0 then
				plate(m, body, "Scale", V(0.45, 0.1, 0.5), at * CF(0, 0.38, 0), pal)
			end
		end
		local neckPoints = { V(0, 1.4, 0.2), V(0, 2.3, -0.1), V(0, 3.2, -0.35), V(0, 4.0, -0.45), V(0, 4.55, -0.35) }
		local widths = { 0.68, 0.62, 0.56, 0.5 }
		local parent = body
		for i = 1, #neckPoints - 1 do
			local p = beam(m, parent, "Neck", neckPoints[i], neckPoints[i + 1], widths[i], widths[i] * 0.95, H, "Tail")
			local at = (neckPoints[i] + neckPoints[i + 1]) / 2
			make(m, p, "Belly", V(widths[i] * 0.7, 0.75, 0.1), CF(at + V(0, 0, -widths[i] * 0.5)), H2)
			plate(m, p, "NeckSpine", V(0.14, 0.28, 0.3), CF(at + V(0, 0, widths[i] * 0.5)) * A(rad(-20), 0, 0), pal)
			parent = p
		end
		local top = V(0, 4.55, -0.35)
		local head = limb(m, parent, "Head", V(0.9, 0.7, 1.2), CF(top + V(0, 0.15, -0.5)), top, "Head", 1, H)
		make(m, head, "Snout", V(0.7, 0.45, 0.6), CF(top + V(0, 0.08, -1.3)), H)
		make(m, head, "Brow", V(0.95, 0.2, 0.5), CF(top + V(0, 0.55, -0.7)), H2)
		for _, s in { -1, 1 } do
			lit(m, head, "Eye", V(0.14, 0.14, 0.24), CF(top + V(s * 0.42, 0.32, -0.75)), pal)
			plate(m, head, "Horn", V(0.14, 0.7, 0.14), CF(top + V(s * 0.3, 0.8, -0.1)) * A(rad(35), 0, rad(-s * 18)), pal)
			plate(m, head, "Antler", V(0.1, 0.4, 0.1), CF(top + V(s * 0.5, 0.95, -0.3)) * A(rad(-10), 0, rad(-s * 55)), pal)
			lit(m, head, "Whisker", V(0.05, 0.05, 1.1), CF(top + V(s * 0.5, 0.0, -1.35)) * A(rad(10), rad(s * 30), 0), pal)
			make(m, head, "Frill", V(0.12, 0.5, 0.4), CF(top + V(s * 0.5, 0.25, 0.05)) * A(0, rad(-s * 25), 0), H2)
		end
		make(m, head, "Mane", V(0.3, 0.45, 0.7), CF(top + V(0, 0.65, 0.2)) * A(rad(20), 0, 0), H2)
		limb(m, head, "Jaw", V(0.62, 0.18, 0.95), CF(top + V(0, -0.24, -1.0)), top + V(0, -0.15, -0.5), "Jaw", 1, H2)
	end

	-- Nightwing: a small black dragon on great bat wings veined with
	-- light, three lit eyes under its horns, a spade on its tail.
	function B.Nightwing(m, pal, H, H2)
		local r = root(m, V(1.2, 1.2, 1.2), 1.65)
		local tilt = CF(0, 1.95, 0.1) * A(rad(-25), 0, 0)
		local body = limb(m, r, "Body", V(1.0, 1.35, 0.9), tilt, V(0, 1.45, 0.2), "Body", 1, H)
		make(m, body, "Chest", V(0.7, 0.9, 0.14), tilt * CF(0, 0.05, -0.5), H2)
		make(m, body, "Hips", V(0.9, 0.45, 0.8), CF(0, 1.45, 0.2), H)
		local head = make(m, body, "Head", V(0.85, 0.7, 0.85), CF(0, 2.9, -0.45), H)
		make(m, head, "Snout", V(0.55, 0.38, 0.5), CF(0, 2.75, -1.0), H2)
		for _, spot in { { -0.22, 2.98 }, { 0.22, 2.98 }, { 0, 3.14 } } do
			lit(m, head, "Eye", V(0.13, 0.11, 0.08), CF(spot[1], spot[2], -0.9), pal)
		end
		limb(m, head, "Jaw", V(0.5, 0.16, 0.5), CF(0, 2.54, -0.95), V(0, 2.62, -0.7), "Jaw", 1, H2)
		for _, s in { -1, 1 } do
			plate(m, head, "Horn", V(0.14, 0.6, 0.14), CF(s * 0.3, 3.4, -0.2) * A(rad(28), 0, rad(-s * 22)), pal)
			plate(m, head, "Horn", V(0.1, 0.35, 0.1), CF(s * 0.45, 3.2, 0.05) * A(rad(10), 0, rad(-s * 60)), pal)
			-- A wing raised high: three fingers of bone, a membrane between, light along each finger.
			local a = V(s * 0.5, 2.55, 0.3)
			local b = V(s * 1.5, 3.9, 0.35)
			local c = V(s * 2.9, 3.25, 0.45)
			local d = V(s * 2.5, 1.9, 0.5)
			local e = V(s * 1.1, 1.75, 0.45)
			local w = limb(m, body, "Wing", V(0.22, 0.3, 0.3), CF(a), a, "Wing", s, H)
			triangle(m, w, "WingMembrane", a, b, c, 0.08, H2)
			triangle(m, w, "WingMembrane", a, c, d, 0.08, H2)
			triangle(m, w, "WingMembrane", a, d, e, 0.08, H)
			beam(m, w, "WingFinger", a, b, 0.13, 0.15, H)
			lit(m, w, "WingVein", V(0.05, (b - a).Magnitude * 0.9, 0.05), CFrame.lookAt((a + b) / 2, b) * A(rad(90), 0, 0), pal)
			for _, tip in { c, d } do
				beam(m, w, "WingFinger", a, tip, 0.1, 0.12, H)
				lit(m, w, "WingVein", V(0.05, (tip - a).Magnitude * 0.85, 0.05), CFrame.lookAt((a + tip) / 2, tip) * A(rad(90), 0, 0), pal)
			end
			beam(m, w, "WingEdge", b, c, 0.08, 0.1, H2)
			plate(m, w, "WingClaw", V(0.1, 0.26, 0.1), CF(b + V(0, 0.18, 0)), pal)
			local arm = beam(m, body, "Arm", V(s * 0.5, 2.3, -0.3), V(s * 0.6, 1.75, -0.55), 0.2, 0.22, H, "Arm", s)
			make(m, arm, "Claw", V(0.18, 0.2, 0.22), CF(s * 0.6, 1.62, -0.6), H2)
			local l = beam(m, body, "Leg", V(s * 0.32, 1.4, 0.2), V(s * 0.4, 0.3, 0.1), 0.26, 0.28, H, "Stride", s)
			make(m, l, "Foot", V(0.36, 0.14, 0.5), CF(s * 0.4, 0.07, -0.05), H2)
			for i = -1, 1 do
				make(m, l, "Toe", V(0.08, 0.1, 0.18), CF(s * 0.4 + i * 0.12, 0.05, -0.35), H2)
			end
		end
		tail(
			m,
			body,
			{ V(0, 1.35, 0.55), V(0, 0.95, 1.2), V(0, 0.75, 1.85), V(0, 0.9, 2.5) },
			{ 0.34, 0.26, 0.18 },
			H,
			function(p, i, at, w)
				if i == 3 then
					plate(m, p, "Spade", V(0.42, 0.08, 0.42), CF(at + V(0, 0.1, 0.4)) * A(0, rad(45), 0), pal)
				else
					lit(m, p, "TailVein", V(0.05, 0.06, 0.5), CF(at + V(0, w * 0.4, 0)), pal)
				end
			end
		)
	end

	return B
end

return Concepts
