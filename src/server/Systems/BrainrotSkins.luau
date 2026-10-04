-- Reference-guided native creature geometry. See docs/boss-model-references.md.
-- The invisible R15 skeleton remains the authoritative combat/animation driver.
local Skins = {}
local V, C, A = Vector3.new, Color3.fromRGB, CFrame.Angles
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local white, dark = C(232, 226, 202), C(19, 24, 25)
local function part(rig, bone, name, size, pos, color, shape, rotation)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	p.Name, p.Size = name, size
	p.CFrame = bone.CFrame * CFrame.new(pos) * (rotation or CFrame.identity)
	p.Color, p.Material = color, Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	if shape and shape ~= "Wedge" then
		p.Shape = shape
	end
	p.Parent = rig
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = bone, p, p
	return p
end
local function eyes(rig, bone, y, z, spacing, scale, iris)
	for _, side in { -1, 1 } do
		local x = side * spacing
		part(rig, bone, "SunkenSocket", V(0.69, 0.43, 0.29) * scale, V(x, y, z + 0.03), C(30, 25, 21), BALL)
		local eye = part(
			rig,
			bone,
			"PredatorEye",
			V(0.47, 0.19, 0.15) * scale,
			V(x, y, z - 0.13),
			iris,
			BALL,
			A(0, 0, side * 0.26)
		)
		eye.Material = Enum.Material.Neon
		part(rig, bone, "SlitPupil", V(0.065, 0.18, 0.06) * scale, V(x, y, z - 0.22), dark, BALL)
		part(
			rig,
			bone,
			"AngryBrow",
			V(0.72, 0.22, 0.24) * scale,
			V(x, y + 0.19 * scale, z - 0.14),
			C(62, 45, 28),
			nil,
			A(0, 0, side * 0.32)
		)
	end
end
local function barefoot(rig, bone, color, scale)
	part(rig, bone, "Instep", V(0.7, 0.47, 1.2) * scale, V(0, 0.07, -0.3), color, BALL)
	for i = 0, 4 do
		local s = 1 - i * 0.09
		part(
			rig,
			bone,
			"Toe",
			V(0.18 * s, 0.24 * s, 0.48 * s) * scale,
			V((i - 2) * 0.145 * scale, -0.06, -0.86 * scale),
			color,
			BALL
		)
	end
end
local function wood(rig, accent)
	local t = rig.UpperTorso
	local oak = C(108, 67, 35)
	part(rig, t, "ContinuousTimberBody", V(3.8, 1.72, 1.5), V(0, 0.5, 0), oak, CYL, A(0, 0, math.pi / 2))
	-- Fine vertical grain follows the cylinder instead of reading as armor plates.
	for i = 1, 26 do
		local a = i * math.pi * 2 / 26
		local len = 2.7 + (i % 5) * 0.19
		part(
			rig,
			t,
			"WoodGrain",
			V(0.028, len, 0.025),
			V(math.cos(a) * 0.865, 0.5, math.sin(a) * 0.755),
			if i % 3 == 0 then C(192, 137, 70) else C(130, 82, 37),
			nil,
			A(0, 0, math.sin(i) * 0.025)
		)
	end
	eyes(rig, t, 1.35, -0.75, 0.4, 1, accent)
	part(rig, t, "NoseBridge", V(0.27, 0.65, 0.3), V(0, 1, -0.82), C(187, 132, 65), BALL)
	part(rig, t, "NoseTip", V(0.42, 0.3, 0.33), V(0, 0.76, -1), C(193, 138, 71), BALL)
	for _, s in { -1, 1 } do
		part(
			rig,
			t,
			"ExpressiveBrow",
			V(0.62, 0.15, 0.2),
			V(s * 0.4, 1.57, -0.89),
			C(108, 69, 30),
			BALL,
			A(0, 0, s * 0.32)
		)
		part(rig, t, "SmileCheek", V(0.44, 0.3, 0.2), V(s * 0.44, 0.59, -0.71), C(180, 120, 57), BALL)
	end
	part(rig, t, "Snarl", V(0.92, 0.36, 0.18), V(0, 0.46, -0.76), C(69, 40, 22), BALL)
	for i = -3, 3 do
		part(
			rig,
			t,
			"SplinterFang",
			V(0.095, 0.17 + (math.abs(i) % 2) * 0.08, 0.1),
			V(i * 0.115, 0.5, -0.88),
			C(212, 185, 130),
			"Wedge",
			A(0, 0, math.pi)
		)
	end
	for i = 1, 5 do
		local fissure = part(
			rig,
			t,
			"EmberFissure",
			V(0.035, 0.4 + (i % 2) * 0.2, 0.03),
			V(-0.65 + i * 0.21, -0.3 + (i % 2) * 0.27, -0.755),
			accent,
			nil,
			A(0, 0, (i % 2 - 0.5) * 0.6)
		)
		fissure.Material = Enum.Material.Neon
	end
	for _, side in { "Left", "Right" } do
		for _, segment in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
			local b = rig[side .. segment]
			part(rig, b, "TimberLimb", V(0.29, b.Size.Y + 0.12, 0.3), V(0, 0, 0), oak, BALL)
		end
		part(
			rig,
			rig[side .. "UpperArm"],
			"Shoulder",
			V(0.78, 0.4, 0.4),
			V(if side == "Left" then 0.3 else -0.3, 0.45, 0),
			oak,
			BALL
		)
		local hand = rig[side .. "Hand"]
		part(rig, hand, "Palm", V(0.32, 0.45, 0.26), V(0, -0.02, 0), oak, BALL)
		for i = 1, 4 do
			part(rig, hand, "Finger", V(0.07, 0.33, 0.08), V((i - 2.5) * 0.075, -0.28, -0.06), oak, BALL)
		end
		barefoot(rig, rig[side .. "Foot"], oak, 1)
	end
	local h = rig.RightHand
	local build = part
	local grip = A(math.rad(-120), 0, 0)
	local function part(r, bone, name, size, pos, color, shape, rotation)
		local mount = grip * CFrame.new(0, -pos.Y, 0) * (rotation or CFrame.identity)
		return build(r, bone, name, size, V(0, 0, 0), color, shape, mount)
	end
	part(rig, h, "BatGrip", V(0.95, 0.18, 0.18), V(0, -0.3, -0.28), C(119, 70, 29), CYL, A(0, 0, math.pi / 2))
	part(rig, h, "BatBarrel", V(1.8, 0.43, 0.43), V(0, -1.48, -0.28), C(190, 132, 60), CYL, A(0, 0, math.pi / 2))
	part(rig, h, "BatEnd", V(0.43, 0.28, 0.43), V(0, -2.34, -0.28), C(190, 132, 60), BALL)
	for i = 1, 3 do
		local p = part(
			rig,
			h,
			"ThermalBatBand",
			V(0.05, 0.445, 0.445),
			V(0, -0.9 - i * 0.35, -0.28),
			accent,
			CYL,
			A(0, 0, math.pi / 2)
		)
		p.Material = Enum.Material.Neon
	end
end
local function sneaker(rig, bone, offset)
	local blue = C(24, 105, 213)
	part(rig, bone, "WhiteRubberSole", V(0.88, 0.23, 1.65), offset + V(0, -0.16, -0.26), white, BALL)
	part(rig, bone, "BlueSneaker", V(0.84, 0.52, 1.58), offset + V(0, 0.06, -0.26), blue, BALL)
	part(rig, bone, "AnkleCollar", V(0.64, 0.53, 0.62), offset + V(0, 0.3, 0.17), C(27, 76, 153), BALL)
	part(rig, bone, "ShoeTongue", V(0.35, 0.16, 0.69), offset + V(0, 0.34, -0.27), C(52, 143, 237), BALL)
	for i = 1, 4 do
		part(rig, bone, "Lace", V(0.4, 0.045, 0.05), offset + V(0, 0.39 - i * 0.035, -0.1 - i * 0.14), white)
	end
	for _, s in { -1, 1 } do
		part(rig, bone, "SideStripe", V(0.035, 0.09, 0.76), offset + V(s * 0.4, 0.11, -0.2), white, nil, A(0.12, 0, 0))
	end
end
local function shark(rig, accent)
	local t = rig.UpperTorso
	local build = part
	local function part(r, bone, name, size, pos, color, shape, rotation)
		return build(r, bone, name, size, if bone == t then pos + V(0, -1.35, 0) else pos, color, shape, rotation)
	end
	local skin = C(44, 66, 80)
	part(rig, t, "SharkBody", V(2.05, 1.85, 4.25), V(0, -0.1, 0.12), skin, BALL)
	part(rig, t, "WhiteBelly", V(1.83, 1.1, 3.75), V(0, -0.56, -0.05), C(137, 153, 149), BALL)
	part(rig, t, "SharkSnout", V(1.62, 1.04, 2.05), V(0, -0.12, -1.62), skin, BALL)
	part(rig, t, "OpenMouth", V(1.21, 0.22, 1.26), V(0, -0.5, -2.1), C(63, 28, 31), BALL)
	part(rig, t, "LowerJaw", V(1.22, 0.26, 1.5), V(0, -0.69, -1.94), C(200, 210, 205), BALL)
	for _, s in { -1, 1 } do
		part(rig, t, "SharkEye", V(0.18, 0.16, 0.25), V(s * 0.68, 0.12, -2.02), accent, BALL)
		part(rig, t, "EyeHighlight", V(0.05, 0.06, 0.06), V(s * 0.742, 0.16, -2.07), white, BALL)
		for i = 1, 4 do
			part(
				rig,
				t,
				"Gill",
				V(0.035, 0.51 - i * 0.045, 0.052),
				V(s * (0.99 - i * 0.015), -0.1, -0.85 + i * 0.17),
				C(39, 65, 73),
				nil,
				A(-0.15, 0, s * 0.08)
			)
		end
		for i = 1, 5 do
			part(
				rig,
				t,
				"SharkTooth",
				V(0.12, 0.26, 0.14),
				V(s * (0.22 + i * 0.065), -0.45, -2.4 + i * 0.13),
				white,
				"Wedge",
				A(0, 0, math.pi)
			)
		end
		part(
			rig,
			rig[if s < 0 then "LeftUpperLeg" else "RightUpperLeg"],
			"WalkingPectoralFin",
			V(0.35, 1.85, 0.85),
			V(s * 0.52, -0.68, 0),
			skin,
			BALL,
			A(0, 0, s * 0.19)
		)
	end
	part(rig, t, "DorsalFin", V(0.16, 1.55, 1.43), V(0, 1.05, 0.4), C(62, 91, 107), "Wedge", A(0, math.pi, 0))
	part(rig, t, "TailPeduncle", V(0.63, 0.64, 2), V(0, -0.03, 2.55), skin, BALL)
	part(rig, t, "UpperTailFin", V(0.16, 1.7, 1.25), V(0, 0.6, 3.37), skin, "Wedge", A(0, math.pi, 0))
	part(rig, t, "LowerTailFin", V(0.15, 0.97, 1.01), V(0, -0.58, 3.42), skin, "Wedge", A(0, 0, math.pi))
	sneaker(rig, rig.LeftFoot, V(-0.52, 0, 0))
	sneaker(rig, rig.RightFoot, V(0.52, 0, 0))
	part(rig, rig.LowerTorso, "ThirdWalkingFin", V(0.25, 1.7, 0.52), V(0, -1.65, 2.5), skin, BALL, A(-0.25, 0, 0))
	sneaker(rig, rig.LowerTorso, V(0, -2.55, 2.7))
	local p = part(rig, t, "CryoDorsalEdge", V(0.18, 0.2, 0.75), V(0, 1.4, -0.14), accent)
	p.Material = Enum.Material.Neon
end
local function tree(rig, accent)
	local t, h = rig.UpperTorso, rig.Head
	local bark, skin = C(92, 66, 38), C(134, 104, 67)
	part(rig, t, "GnarledTrunk", V(1.95, 2.65, 1.3), V(0, -0.2, 0.08), bark, BALL)
	part(rig, h, "MonkeyHead", V(1.65, 1.8, 1.35), V(0, 0, 0), bark, BALL)
	part(rig, h, "FaceMask", V(1.23, 1.17, 0.5), V(0, 0.03, -0.57), skin, BALL)
	eyes(rig, h, 0.23, -0.83, 0.34, 0.66, accent)
	part(rig, h, "LongPendulousNose", V(0.55, 1.32, 0.64), V(0, -0.36, -1.02), C(202, 146, 84), BALL, A(0.24, 0, 0))
	part(rig, h, "NoseTip", V(0.57, 0.45, 0.64), V(0, -0.88, -1.14), C(198, 137, 74), BALL)
	for _, s in { -1, 1 } do
		part(
			rig,
			h,
			"HeavyBrow",
			V(0.62, 0.22, 0.27),
			V(s * 0.35, 0.39, -0.94),
			C(74, 101, 36),
			BALL,
			A(0, 0, s * 0.32)
		)
	end
	for _, side in { "Left", "Right" } do
		for _, seg in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
			local b = rig[side .. seg]
			part(rig, b, "RootLimb", V(0.57, b.Size.Y + 0.2, 0.59), V(0, 0, 0), bark, BALL)
			for i = 1, 4 do
				part(
					rig,
					b,
					"RootRidge",
					V(0.09, b.Size.Y + 0.13, 0.1),
					V((i - 2.5) * 0.13, 0, -0.25),
					C(130, 94, 49),
					nil,
					A(0, 0, math.sin(i) * 0.1)
				)
			end
		end
		part(
			rig,
			rig[side .. "UpperArm"],
			"RootShoulder",
			V(0.9, 0.55, 0.55),
			V(if side == "Left" then 0.3 else -0.3, 0.43, 0),
			bark,
			BALL
		)
		local hand = rig[side .. "Hand"]
		part(rig, hand, "Palm", V(0.61, 0.38, 0.55), V(0, -0.04, -0.09), skin, BALL)
		for i = 1, 4 do
			part(rig, hand, "LongFinger", V(0.12, 0.49, 0.15), V((i - 2.5) * 0.145, -0.3, -0.16), skin, BALL)
		end
		barefoot(rig, rig[side .. "Foot"], skin, 1.85)
	end
	part(rig, h, "SnarlingMouth", V(0.97, 0.33, 0.2), V(0, -0.54, -0.75), C(26, 23, 18), BALL)
	for _, side in { "Left", "Right" } do
		local hand = rig[side .. "Hand"]
		for i = 1, 4 do
			part(
				rig,
				hand,
				"RootClaw",
				V(0.1, 0.37, 0.14),
				V((i - 2.5) * 0.145, -0.64, -0.19),
				C(215, 198, 147),
				"Wedge",
				A(0, 0, math.pi)
			)
		end
	end
	for _, side in { -1, 1 } do
		part(
			rig,
			h,
			"TusklikeFang",
			V(0.16, 0.46, 0.17),
			V(side * 0.39, -0.43, -0.9),
			C(217, 205, 163),
			"Wedge",
			A(0, 0, math.pi)
		)
		for i = 1, 3 do
			part(
				rig,
				t,
				"BrokenBranchSpike",
				V(0.22, 0.7 + i * 0.1, 0.28),
				V(side * (0.78 + i * 0.18), 0.65 + i * 0.18, 0.12),
				C(68, 49, 31),
				"Wedge",
				A(0, 0, -side * 0.55)
			)
		end
	end
	-- Layered leaf tufts hug the body; no spherical tree canopy.
	for i = 1, 38 do
		local a = i * 2.39996
		local y = -1.2 + (i % 9) * 0.39
		local x, z = math.cos(a) * 0.88, math.sin(a) * 0.63
		part(
			rig,
			t,
			"MossTuft",
			V(0.51, 0.64, 0.25),
			V(x, y, z),
			C(45 + (i % 4) * 9, 82 + (i % 5) * 10, 29 + (i % 3) * 7),
			BALL,
			A(0.15, a, 0.32)
		)
	end
	for i = 1, 12 do
		local a = i * math.pi / 6
		part(
			rig,
			h,
			"LeafHood",
			V(0.53, 0.57, 0.37),
			V(math.cos(a) * 0.66, 0.55 + math.sin(a) * 0.3, 0.13 + math.sin(a) * 0.41),
			C(53, 104 + (i % 3) * 12, 35),
			BALL,
			A(0, a, 0.2)
		)
	end
	for i = 1, 5 do
		local p = part(
			rig,
			t,
			"CorrosiveSpore",
			V(0.1, 0.13, 0.1),
			V(math.sin(i * 2) * 0.8, -0.8 + i * 0.38, -0.68),
			accent,
			BALL
		)
		p.Material = Enum.Material.Neon
	end
end
local function croc(rig, accent)
	local t = rig.UpperTorso
	local green, metal = C(48, 72, 40), C(43, 58, 52)
	part(rig, t, "BomberFuselage", V(1.55, 1.45, 4.6), V(0, -0.13, 0.65), metal, BALL)
	part(rig, t, "CrocSkull", V(1.67, 1.06, 1.6), V(0, -0.08, -1.14), green, BALL)
	part(rig, t, "LongUpperSnout", V(1.29, 0.48, 2.85), V(0, -0.32, -2.48), green, BALL)
	part(rig, t, "MouthCavity", V(1.08, 0.28, 2.44), V(0, -0.61, -2.35), C(53, 32, 24), BALL)
	part(rig, t, "LowerJaw", V(1.19, 0.29, 2.83), V(0, -0.87, -2.39), C(139, 148, 88), BALL, A(-0.055, 0, 0))
	for _, s in { -1, 1 } do
		part(rig, t, "RaisedEye", V(0.43, 0.34, 0.56), V(s * 0.57, 0.37, -1.6), green, BALL)
		part(rig, t, "GoldEye", V(0.14, 0.17, 0.2), V(s * 0.735, 0.3, -1.77), C(255, 92, 24), BALL)
		part(rig, t, "EyeSlit", V(0.07, 0.13, 0.06), V(s * 0.8, 0.3, -1.81), dark, BALL)
		part(rig, t, "Nostril", V(0.12, 0.08, 0.21), V(s * 0.34, -0.1, -3.47), dark, BALL)
		for i = 1, 10 do
			local z = -1.48 - i * 0.19
			part(
				rig,
				t,
				"UpperFang",
				V(0.13, 0.32 + (i % 3) * 0.05, 0.13),
				V(s * (0.5 - i * 0.012), -0.58, z),
				white,
				"Wedge",
				A(0, 0, math.pi)
			)
			part(rig, t, "LowerFang", V(0.1, 0.17, 0.1), V(s * (0.48 - i * 0.011), -0.72, z - 0.08), white, "Wedge")
		end
		part(rig, t, "MainWing", V(3.6, 0.16, 1.55), V(s * 2.35, -0.18, 0.35), metal, nil, A(0, -s * 0.13, s * 0.04))
		part(
			rig,
			t,
			"YellowLeadingEdge",
			V(3.65, 0.19, 0.2),
			V(s * 2.35, -0.18, -0.39),
			C(211, 161, 38),
			nil,
			A(0, -s * 0.13, s * 0.04)
		)
		part(rig, t, "WingPanel", V(2.4, 0.035, 0.045), V(s * 2.48, -0.06, 0.6), C(43, 58, 52), nil, A(0, -s * 0.13, 0))
		part(rig, t, "EngineNacelle", V(0.64, 0.62, 1.45), V(s * 1.9, -0.33, -0.1), C(106, 116, 92), BALL)
		part(rig, t, "PropellerHub", V(0.28, 0.28, 0.4), V(s * 1.9, -0.33, -0.89), C(215, 176, 53), BALL)
		for j = 0, 2 do
			part(
				rig,
				t,
				"PropellerBlade",
				V(0.13, 1.25, 0.06),
				V(s * 1.9, -0.33, -1.01),
				dark,
				nil,
				A(0, 0, j * math.pi / 3)
			)
		end
		part(rig, t, "TailPlane", V(1.3, 0.13, 0.75), V(s * 0.85, 0.05, 2.75), C(208, 157, 41), nil, A(0, -s * 0.16, 0))
	end
	for i = 1, 7 do
		part(
			rig,
			t,
			"ArmoredDorsalScute",
			V(0.36, 0.36, 0.43),
			V(0, 0.53, 0.5 + i * 0.25),
			C(35, 48, 32),
			"Wedge",
			A(0, math.pi, 0)
		)
	end
	part(rig, t, "CockpitGlass", V(1.05, 0.62, 1.21), V(0, 0.64, -0.01), C(82, 138, 145), BALL)
	for _, z in { -0.46, 0.13, 0.48 } do
		part(rig, t, "CanopyFrame", V(1.04, 0.065, 0.07), V(0, 0.79, z), C(135, 147, 123))
	end
	part(rig, t, "TailFin", V(0.14, 1.35, 1.1), V(0, 0.62, 2.7), C(211, 161, 38), "Wedge", A(0, math.pi, 0))
	for i = 1, 6 do
		part(rig, t, "SnoutScute", V(0.48, 0.075, 0.13), V(0, -0.04, -1.45 - i * 0.29), C(60, 85, 48), BALL)
	end
	for _, s in { -1, 1 } do
		local p = part(rig, t, "IonEngineGlow", V(0.34, 0.34, 0.12), V(s * 1.9, -0.33, 0.6), accent, BALL)
		p.Material = Enum.Material.Neon
	end
end
function Skins.apply(rig, spec, accent, boss)
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
	if spec.Shape == "Wood" then
		wood(rig, accent)
	elseif spec.Shape == "Tree" then
		tree(rig, accent)
	elseif spec.Shape == "Shark" then
		shark(rig, accent)
	else
		croc(rig, accent)
	end
	if boss then
		rig:ScaleTo(1.8)
	end
	rig:SetAttribute("BrainrotCharacter", spec.Id)
	rig:SetAttribute("CombatPoseProfile", if spec.Id == "Sahur" then "SahurBat" else nil)
	rig:SetAttribute("DungeonBoss", boss)
end
return Skins
