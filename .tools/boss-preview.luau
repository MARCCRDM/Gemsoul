local colorMt = { __index = {
	Lerp = function(self, other, amount)
 return setmetatable({R=self.R*(1-amount)+other.R*amount,G=self.G*(1-amount)+other.G*amount,B=self.B*(1-amount)+other.B*amount,kind="Color3"},getmetatable(self))
 end,
} }
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b, kind = "Color3" }, colorMt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local vmt = {}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vmt)
	end,
}
vmt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local cmt = {}
local CFrame = {}
function CFrame.new(x,y,z)
 if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end
 return setmetatable({t={x or 0,y or 0,z or 0},r={1,0,0,0,1,0,0,0,1}},cmt)
end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local a=CFrame.new(); a.r={cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy}; return a
end
cmt.__mul=function(a,b)
 local c=CFrame.new()
 for i=1,3 do
  c.t[i]=a.t[i]
  for k=1,3 do c.t[i]+=a.r[(i-1)*3+k]*b.t[k] end
  for j=1,3 do
   local v=0
   for k=1,3 do v+=a.r[(i-1)*3+k]*b.r[(k-1)*3+j] end
   c.r[(i-1)*3+j]=v
  end
 end
 return c
end
CFrame.identity=CFrame.new()
local enumMt = {
	__index = function(_self, key)
		return key
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, enumMt)
		rawset(self, key, t)
		return t
	end,
})
local built = 0
local builtParts = {}
local Instance = {
	new = function(className)
		local values = { ClassName = className }
		return setmetatable({}, {
			__index = values,
			__newindex = function(_self, key, value)
				if key == "Color" then
					assert(
						type(value) == "table" and value.kind == "Color3",
						"Invalid Color assignment: " .. type(value)
					)
				end
				if key == "Size" then
					assert(value.X > 0 and value.Y > 0 and value.Z > 0, "Invalid part size")
				end
				values[key] = value
				if key == "Parent" and (className == "Part" or className == "WedgePart") then
					built += 1
					table.insert(builtParts, values)
				end
			end,
		})
	end,
}

local randomSeed = 123
local Random = {
	new = function(seed)
		randomSeed += 1
		local state = seed or randomSeed
		return {
			NextNumber = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return (low or 0) + state / 2147483647 * ((high or 1) - (low or 0))
			end,
			NextInteger = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return low + state % (high - low + 1)
			end,
		}
	end,
}

Vector3.zero=Vector3.new(0,0,0)
local Skins=(function()
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
		part(rig, bone, "EyeSocket", V(0.66, 0.75, 0.27) * scale, V(x, y, z + 0.08), C(87, 57, 27), BALL)
		part(rig, bone, "EyeWhite", V(0.49, 0.59, 0.25) * scale, V(x, y, z - 0.05), white, BALL)
		part(rig, bone, "Iris", V(0.29, 0.36, 0.13) * scale, V(x, y, z - 0.18), iris, BALL)
		part(rig, bone, "Pupil", V(0.15, 0.23, 0.09) * scale, V(x, y, z - 0.25), dark, BALL)
		part(
			rig,
			bone,
			"EyeGlint",
			V(0.07, 0.09, 0.06) * scale,
			V(x - 0.045, y + 0.075, z - 0.29),
			C(255, 255, 255),
			BALL
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
	local oak = C(166, 112, 53)
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
	eyes(rig, t, 1.35, -0.75, 0.4, 1, C(94, 62, 25))
	part(rig, t, "NoseBridge", V(0.27, 0.65, 0.3), V(0, 1, -0.82), C(187, 132, 65), BALL)
	part(rig, t, "NoseTip", V(0.42, 0.3, 0.33), V(0, 0.76, -1), C(193, 138, 71), BALL)
	for _, s in { -1, 1 } do
		part(
			rig,
			t,
			"ExpressiveBrow",
			V(0.62, 0.15, 0.2),
			V(s * 0.4, 1.8, -0.8),
			C(108, 69, 30),
			BALL,
			A(0, 0, s * -0.15)
		)
		part(rig, t, "SmileCheek", V(0.44, 0.3, 0.2), V(s * 0.44, 0.59, -0.71), C(180, 120, 57), BALL)
	end
	part(rig, t, "Smile", V(0.8, 0.23, 0.15), V(0, 0.46, -0.76), C(69, 40, 22), BALL)
	part(rig, t, "SmileTeeth", V(0.62, 0.095, 0.09), V(0, 0.51, -0.85), C(231, 203, 150), BALL)
	for _, side in { "Left", "Right" } do
		for _, segment in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
			local b = rig[side .. segment]
			part(rig, b, "TimberLimb", V(0.29, b.Size.Y + 0.12, 0.3), V(0, 0, 0), oak, BALL)
		end
		local hand = rig[side .. "Hand"]
		part(rig, hand, "Palm", V(0.32, 0.45, 0.26), V(0, -0.02, 0), oak, BALL)
		for i = 1, 4 do
			part(rig, hand, "Finger", V(0.07, 0.33, 0.08), V((i - 2.5) * 0.075, -0.28, -0.06), oak, BALL)
		end
		barefoot(rig, rig[side .. "Foot"], oak, 1)
	end
	local h = rig.RightHand
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
	local skin = C(82, 111, 126)
	part(rig, t, "SharkBody", V(2.05, 1.85, 4.25), V(0, -0.1, 0.12), skin, BALL)
	part(rig, t, "WhiteBelly", V(1.83, 1.1, 3.75), V(0, -0.56, -0.05), C(196, 204, 197), BALL)
	part(rig, t, "SharkSnout", V(1.62, 1.04, 2.05), V(0, -0.12, -1.62), skin, BALL)
	part(rig, t, "OpenMouth", V(1.21, 0.22, 1.26), V(0, -0.5, -2.1), C(63, 28, 31), BALL)
	part(rig, t, "LowerJaw", V(1.22, 0.26, 1.5), V(0, -0.69, -1.94), C(200, 210, 205), BALL)
	for _, s in { -1, 1 } do
		part(rig, t, "SharkEye", V(0.15, 0.2, 0.2), V(s * 0.68, 0.12, -2.02), dark, BALL)
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
				V(0.09, 0.13, 0.1),
				V(s * (0.22 + i * 0.065), -0.45, -2.4 + i * 0.13),
				white,
				"Wedge",
				A(0, 0, math.pi)
			)
		end
		part(
			rig,
			rig[if s < 0 then "LeftUpperArm" else "RightUpperArm"],
			"WalkingPectoralFin",
			V(0.27, 1.65, 0.85),
			V(-s * 0.18, -0.9, 0),
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
	part(rig, rig.LowerTorso, "ThirdWalkingFin", V(0.25, 1.7, 0.52), V(0, -1.24, 2.5), skin, BALL, A(-0.25, 0, 0))
	sneaker(rig, rig.LowerTorso, V(0, -2.55, 2.7))
	local p = part(rig, t, "CryoDorsalEdge", V(0.18, 0.2, 0.75), V(0, 1.62, 0.82), accent)
	p.Material = Enum.Material.Neon
end
local function tree(rig, accent)
	local t, h = rig.UpperTorso, rig.Head
	local bark, skin = C(92, 66, 38), C(180, 128, 74)
	part(rig, t, "GnarledTrunk", V(1.95, 2.65, 1.3), V(0, -0.2, 0.08), bark, BALL)
	part(rig, h, "MonkeyHead", V(1.65, 1.8, 1.35), V(0, 0, 0), bark, BALL)
	part(rig, h, "FaceMask", V(1.23, 1.17, 0.5), V(0, 0.03, -0.57), skin, BALL)
	eyes(rig, h, 0.23, -0.83, 0.34, 0.66, C(84, 78, 34))
	part(rig, h, "LongPendulousNose", V(0.55, 1.32, 0.64), V(0, -0.36, -1.02), C(202, 146, 84), BALL, A(0.24, 0, 0))
	part(rig, h, "NoseTip", V(0.57, 0.45, 0.64), V(0, -0.88, -1.14), C(198, 137, 74), BALL)
	for _, s in { -1, 1 } do
		part(
			rig,
			h,
			"HeavyBrow",
			V(0.62, 0.22, 0.27),
			V(s * 0.35, 0.55, -0.81),
			C(74, 101, 36),
			BALL,
			A(0, 0, s * 0.14)
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
		local hand = rig[side .. "Hand"]
		part(rig, hand, "Palm", V(0.61, 0.38, 0.55), V(0, -0.04, -0.09), skin, BALL)
		for i = 1, 4 do
			part(rig, hand, "LongFinger", V(0.12, 0.49, 0.15), V((i - 2.5) * 0.145, -0.3, -0.16), skin, BALL)
		end
		barefoot(rig, rig[side .. "Foot"], skin, 1.85)
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
	local green, metal = C(78, 105, 64), C(74, 91, 81)
	part(rig, t, "BomberFuselage", V(1.55, 1.45, 4.6), V(0, -0.13, 0.65), metal, BALL)
	part(rig, t, "CrocSkull", V(1.67, 1.06, 1.6), V(0, -0.08, -1.14), green, BALL)
	part(rig, t, "LongUpperSnout", V(1.29, 0.48, 2.85), V(0, -0.32, -2.48), green, BALL)
	part(rig, t, "MouthCavity", V(1.08, 0.28, 2.44), V(0, -0.61, -2.35), C(53, 32, 24), BALL)
	part(rig, t, "LowerJaw", V(1.19, 0.29, 2.83), V(0, -0.87, -2.39), C(139, 148, 88), BALL, A(-0.055, 0, 0))
	for _, s in { -1, 1 } do
		part(rig, t, "RaisedEye", V(0.43, 0.34, 0.56), V(s * 0.57, 0.3, -1.6), green, BALL)
		part(rig, t, "GoldEye", V(0.14, 0.17, 0.2), V(s * 0.735, 0.3, -1.77), C(242, 186, 39), BALL)
		part(rig, t, "EyeSlit", V(0.07, 0.13, 0.06), V(s * 0.8, 0.3, -1.81), dark, BALL)
		part(rig, t, "Nostril", V(0.12, 0.08, 0.21), V(s * 0.34, -0.1, -3.47), dark, BALL)
		for i = 1, 10 do
			local z = -1.48 - i * 0.19
			part(
				rig,
				t,
				"UpperFang",
				V(0.13, 0.23 + (i % 3) * 0.04, 0.13),
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
	rig:SetAttribute("DungeonBoss", boss)
end
return Skins

end)()
local Rules=(function()
-- Deterministic dungeon layout and encounter rules. No Roblox services.
local Dungeon = {}
Dungeon.Min = 3
Dungeon.Max = 4
Dungeon.RoomCount = 5
Dungeon.TimeLimit = 900
Dungeon.RoomSize = 64
Dungeon.Spacing = 90
Dungeon.Roster = {
	{
		Id = "Sahur",
		Name = "Tung Tung Tung Sahur",
		Element = "Fire",
		Weakness = "Frost",
		Shape = "Wood",
		Moves = { "HydraulicSlam", "BreachHammer", "TremorSlam" },
	},
	{
		Id = "Tralalero",
		Name = "Tralalero Tralala",
		Element = "Frost",
		Weakness = "Shock",
		Shape = "Shark",
		Moves = { "ServoFlurry", "StimDodge", "KineticRam" },
	},
	{
		Id = "Patapim",
		Name = "Brr Brr Patapim",
		Element = "Poison",
		Weakness = "Fire",
		Shape = "Tree",
		Moves = { "TremorSlam", "SeismicBreaker", "HydraulicSlam" },
	},
	{
		Id = "Crocodilo",
		Name = "Bombardiro Crocodilo",
		Element = "Shock",
		Weakness = "Poison",
		Shape = "Crocodile",
		Moves = { "ArmorPiercer", "KineticRam", "ServoFlurry" },
	},
}
local directions = { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }
function Dungeon.generate(rng)
	local rooms = { { X = 0, Z = 0 } }
	local used = { ["0:0"] = true }
	for i = 2, Dungeon.RoomCount do
		local previous = rooms[i - 1]
		local candidates = {}
		for _, d in directions do
			local x, z = previous.X + d[1], previous.Z + d[2]
			local clear = not used[x .. ":" .. z]
			for _, adjacent in directions do
				local ax, az = x + adjacent[1], z + adjacent[2]
				if used[ax .. ":" .. az] and (ax ~= previous.X or az ~= previous.Z) then
					clear = false
				end
			end
			if clear then
				table.insert(candidates, { X = x, Z = z })
			end
		end
		-- At this small length there is always an open end; keep failure explicit.
		assert(#candidates > 0, "Dungeon path has no free continuation")
		local room = candidates[rng:NextInteger(1, #candidates)]
		used[room.X .. ":" .. room.Z] = true
		table.insert(rooms, room)
	end
	local boss = rng:NextInteger(1, #Dungeon.Roster)
	for i, room in rooms do
		room.Index = i
		room.Boss = i == Dungeon.RoomCount
		room.Theme = if room.Boss then boss else rng:NextInteger(1, #Dungeon.Roster)
		room.Foes = {}
		for n = 1, if room.Boss then 1 else rng:NextInteger(2, 3) do
			table.insert(room.Foes, if room.Boss then boss else rng:NextInteger(1, #Dungeon.Roster))
		end
		room.Pillars = rng:NextInteger(2, 4)
	end
	return rooms
end
function Dungeon.canEnter(count, leader, allReady)
	if not leader then
		return false, "Only the party leader can queue."
	end
	if count < Dungeon.Min or count > Dungeon.Max then
		return false, "Dungeons need a party of 3–4 players."
	end
	if not allReady then
		return false, "Every party member must mark Ready first."
	end
	return true
end
function Dungeon.elementMultiplier(main, weakness, incoming)
	if incoming == weakness then
		return 1.3
	end
	if incoming == main then
		return 0.7
	end
	return 1
end
return Dungeon

end)()
local BODY = {
	-- name, size, centre
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.2, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.2, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0) },
	{ "RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, -0.15, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -0.75, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.85, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, -0.15, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -0.75, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -0.9, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, -2.05, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.75, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -0.9, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, -2.05, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.75, 0) },
}

local colors={Fire=Color3.fromRGB(238,62,54),Frost=Color3.fromRGB(64,150,255),Poison=Color3.fromRGB(70,205,90),Shock=Color3.fromRGB(255,212,40)}
for _,spec in Rules.Roster do
 table.clear(builtParts)
 local rig={}
 for _,b in BODY do
  local p=Instance.new("Part");p.Name=b[1];p.Size=b[2];p.CFrame=CFrame.new(b[3]);p.Material="SmoothPlastic";p.Color=Color3.new(1,1,1);p.Parent=rig
  p.IsA=function(_,kind) return kind=="BasePart" end
  rig[b[1]]=p
 end
 rig.GetChildren=function() local list={} for _,b in BODY do table.insert(list,rig[b[1]]) end return list end
 rig.SetAttribute=function() end
 rig.ScaleTo=function(_,scale) for _,p in builtParts do p.Size=p.Size*scale;for i=1,3 do p.CFrame.t[i]*=scale end end end
 Skins.apply(rig,spec,colors[spec.Element],true)
 print("MODEL|"..spec.Name.."|"..spec.Element.."|"..spec.Weakness)
 for _,p in builtParts do
  if p.Transparency==1 then continue end
  local row={if p.ClassName=="WedgePart" then "Wedge" else p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
  for _,n in p.CFrame.t do table.insert(row,tostring(n)) end
  for _,n in p.CFrame.r do table.insert(row,tostring(n)) end
  print(table.concat(row,"|"))
 end
end
