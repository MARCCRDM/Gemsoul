--[[
	The mini kaiju, built from blocks: a dark armoured body, plates in its
	element's colour, and glowing eyes, core and vents. About four studs tall
	at scale 1; out in the world they're scaled (Kaiju.Scale).

	  Bulwark    stands upright on two thick legs: a broad plated torso,
	             heavy arms, a visor of light across its face, a long tail
	             dragging behind and a row of fins down its back
	  Razorback  runs low and level: a long snout full of teeth, a row of
	             swept-back spines, long hind legs and a whip of a tail
	  Carapace   crouches on four stubby legs under a wide stepped shell
	             tiled in plates, a horned head and a spiked club tail

	Every model has an invisible HumanoidRootPart (its KaijuHipHeight
	attribute is the Humanoid's HipHeight), and faces -Z. Its trunk (the
	part everything else hangs from) sits on a Body joint at its hips, so it
	can lean, rear up, lunge and crouch in a fight; its legs, arms, jaw and
	tail hang from the trunk on joints of their own. Every joint is a
	Motor6D marked for the client's CreatureAnimation (CreatureMotion kinds
	Body, Stride, Arm, Jaw and Tail, from Shared.CreatureMotion).

	  KaijuModels.build(species, element) -> Model
	  KaijuModels.scale(model, scale)     resize, keeping the joints' rest poses
]]
local KaijuModels = {}

local V, C = Vector3.new, Color3.fromRGB
local CF, A = CFrame.new, CFrame.Angles
local rad = math.rad

-- Each element's plates, the glow of its eyes, core and vents, and a darker trim.
KaijuModels.Palettes = {
	Fire = { Plate = C(236, 138, 44), Glow = C(255, 196, 96), Trim = C(150, 72, 26) },
	Frost = { Plate = C(72, 178, 198), Glow = C(140, 238, 255), Trim = C(36, 104, 132) },
	Shock = { Plate = C(234, 198, 62), Glow = C(150, 222, 255), Trim = C(140, 112, 34) },
	Poison = { Plate = C(112, 196, 84), Glow = C(200, 255, 120), Trim = C(56, 116, 46) },
}
local BODY, BODY2, CLAW = C(46, 54, 74), C(68, 78, 104), C(176, 170, 156)

local function make(
	model: Model,
	attach: BasePart?,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material,
	class
)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p.CastShadow = material ~= Enum.Material.Neon
	p.Parent = model
	if attach then
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = attach, p
		weld.Parent = p
	end
	return p
end

-- A part on a joint: it swings about `pivot` (a point), driven on the client.
local function limb(
	model: Model,
	attach: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	pivot: Vector3,
	kind: string,
	side: number,
	color: Color3
)
	local p = make(model, nil, name, size, cf, color)
	local at = CF(pivot)
	local joint = Instance.new("Motor6D")
	joint.Name = "CreatureMotion"
	joint.Part0, joint.Part1 = attach, p
	joint.C0 = attach.CFrame:Inverse() * at
	joint.C1 = p.CFrame:Inverse() * at
	joint:SetAttribute("CreatureMotion", kind)
	joint:SetAttribute("CreatureRest", joint.C0)
	joint:SetAttribute("CreatureSide", side)
	joint.Parent = p
	return p
end

local function glow(model, attach, name, size, cf, palette)
	return make(model, attach, name, size, cf, palette.Glow, Enum.Material.Neon)
end

local function plate(model, attach, name, size, cf, palette)
	return make(model, attach, name, size, cf, palette.Plate)
end

local function wedge(model, attach, name, size, cf, color)
	return make(model, attach, name, size, cf, color, nil, "WedgePart")
end

local function claws(model, attach, x: number, y: number, z: number, count: number, spread: number, size: Vector3)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * spread
		make(model, attach, "Claw", size, CF(x + offset, y, z), CLAW)
	end
end

local function root(model: Model, size: Vector3, y: number): BasePart
	local r = make(model, nil, "HumanoidRootPart", size, CF(0, y, 0), BODY)
	r.Transparency = 1
	r.Massless = false
	model.PrimaryPart = r
	model:SetAttribute("KaijuHipHeight", y - size.Y / 2)
	return r
end

-- Bulwark --------------------------------------------------------------------------------------
local function bulwark(model: Model, pal)
	local r = root(model, V(2.2, 2.2, 2), 2.3)
	-- A heavy torso leaning into the walk, on its hips (level with its legs' joints).
	local torso =
		limb(model, r, "Torso", V(2.4, 2.1, 2), CF(0, 2.55, 0.15) * A(rad(-14), 0, 0), V(0, 1.68, 0.3), "Body", 1, BODY)
	plate(model, torso, "Chest", V(1.25, 0.95, 0.22), CF(0, 2.25, -0.86) * A(rad(-14), 0, 0), pal)
	glow(model, torso, "Core", V(0.46, 0.46, 0.12), CF(0, 2.98, -1.02) * A(rad(-14), 0, 0), pal)
	make(model, torso, "Hips", V(2.1, 0.7, 1.7), CF(0, 1.6, 0.35), BODY2)
	for _, x in { -1, 1 } do
		glow(model, torso, "Vent", V(0.08, 0.12, 0.95), CF(x * 1.22, 2.65, 0.25) * A(rad(-14), 0, 0), pal)
		plate(
			model,
			torso,
			"Pauldron",
			V(0.9, 0.62, 1.05),
			CF(x * 1.36, 3.15, -0.2) * A(rad(-14), 0, rad(-x * 14)),
			pal
		)
	end
	-- Dorsal fins from the neck down the back, leaning back.
	for i, h in { 0.85, 1.1, 1.0, 0.8 } do
		plate(
			model,
			torso,
			"Fin",
			V(0.32, h, 0.72),
			CF(0, 3.55 + h / 2 - i * 0.28, 0.25 + i * 0.42) * A(rad(28), 0, 0),
			pal
		)
	end
	-- Neck and a big head pushed forward: a long snout, brow, crests, a visor of light.
	make(model, torso, "Neck", V(1.25, 0.85, 1.0), CF(0, 3.48, -0.7) * A(rad(-20), 0, 0), BODY)
	local head = make(model, torso, "Head", V(1.4, 1.02, 1.42), CF(0, 3.88, -1.2), BODY2)
	make(model, head, "Snout", V(1.12, 0.56, 0.85), CF(0, 3.72, -2.08), BODY2)
	plate(model, head, "Brow", V(1.46, 0.26, 0.66), CF(0, 4.44, -1.42), pal)
	for _, x in { -1, 1 } do
		plate(model, head, "Crest", V(0.32, 0.48, 0.66), CF(x * 0.5, 4.56, -0.95) * A(rad(24), 0, 0), pal)
	end
	glow(model, head, "Visor", V(1.06, 0.18, 0.08), CF(0, 4.06, -1.92), pal)
	local jaw = limb(model, head, "Jaw", V(1.02, 0.32, 1.02), CF(0, 3.32, -1.9), V(0, 3.5, -1.45), "Jaw", 1, BODY)
	for i = -1, 1 do
		make(model, jaw, "Tooth", V(0.15, 0.15, 0.12), CF(i * 0.3, 3.52, -2.32), CLAW)
	end
	-- Arms held forward: plated forearms, clawed fists.
	for _, x in { -1, 1 } do
		local arm = limb(
			model,
			torso,
			"Arm",
			V(0.72, 1.18, 0.76),
			CF(x * 1.46, 2.4, -0.62),
			V(x * 1.4, 2.98, -0.45),
			"Arm",
			x,
			BODY
		)
		plate(model, arm, "Forearm", V(0.8, 0.5, 0.86), CF(x * 1.48, 2.1, -0.68), pal)
		make(model, arm, "Fist", V(0.84, 0.6, 0.84), CF(x * 1.5, 1.58, -0.74), BODY2)
		claws(model, arm, x * 1.5, 1.3, -1.12, 3, 0.25, V(0.16, 0.22, 0.3))
	end
	-- Thick legs, knee plates, wide clawed feet.
	for _, x in { -1, 1 } do
		local leg = limb(
			model,
			torso,
			"Leg",
			V(1.1, 1.25, 1.2),
			CF(x * 0.8, 1.05, 0.3),
			V(x * 0.8, 1.68, 0.3),
			"Stride",
			x,
			BODY
		)
		plate(model, leg, "Knee", V(1.0, 0.52, 0.3), CF(x * 0.8, 1.02, -0.36), pal)
		make(model, leg, "Foot", V(1.25, 0.45, 1.62), CF(x * 0.82, 0.22, 0.05), BODY2)
		claws(model, leg, x * 0.82, 0.18, -0.86, 3, 0.34, V(0.2, 0.22, 0.3))
	end
	-- A long tail sweeping down to the ground, a fin on each segment.
	local parent, top = torso, V(0, 1.9, 1.0)
	for i, s in { V(1.15, 0.95, 1.2), V(0.95, 0.8, 1.15), V(0.72, 0.6, 1.1), V(0.5, 0.42, 1.0) } do
		local tilt = A(rad(22), 0, 0)
		local centre = top + tilt:VectorToWorldSpace(V(0, 0, s.Z / 2))
		local seg = limb(model, parent, "Tail", s, CF(centre) * tilt, top, "Tail", 1, BODY)
		local fin = 0.62 - i * 0.12
		plate(
			model,
			seg,
			"Fin",
			V(0.24, fin, 0.5),
			CF(centre) * tilt * CF(0, s.Y / 2 + fin / 2 - 0.05, 0) * A(rad(20), 0, 0),
			pal
		)
		parent, top = seg, top + tilt:VectorToWorldSpace(V(0, 0, s.Z - 0.08))
	end
end

-- Razorback ------------------------------------------------------------------------------------
local function razorback(model: Model, pal)
	local r = root(model, V(1.4, 1.4, 1.6), 2)
	local body =
		limb(model, r, "Body", V(1.3, 1.15, 2.4), CF(0, 2.15, 0) * A(rad(8), 0, 0), V(0, 2.05, 0.45), "Body", 1, BODY)
	plate(model, body, "Chest", V(1.0, 0.3, 1.3), CF(0, 1.62, -0.45), pal)
	for _, x in { -1, 1 } do
		glow(model, body, "Vent", V(0.06, 0.12, 0.85), CF(x * 0.67, 2.3, 0.1), pal)
	end
	-- Neck and head: a long snout, teeth along the jaw, slit eyes, a crest.
	local neck = make(model, body, "Neck", V(0.72, 0.95, 0.85), CF(0, 2.62, -1.35) * A(rad(28), 0, 0), BODY)
	local head = make(model, neck, "Head", V(0.86, 0.72, 1.5), CF(0, 3.02, -2.0), BODY2)
	make(model, head, "Snout", V(0.66, 0.46, 0.62), CF(0, 2.94, -2.98), BODY2)
	for _, x in { -1, 1 } do
		glow(model, head, "Eye", V(0.12, 0.12, 0.36), CF(x * 0.44, 3.14, -2.3), pal)
	end
	wedge(model, head, "Crest", V(0.16, 0.5, 0.7), CF(0, 3.62, -1.85), pal.Plate)
	local jaw = limb(model, head, "Jaw", V(0.7, 0.22, 1.32), CF(0, 2.6, -2.45), V(0, 2.72, -1.75), "Jaw", 1, BODY)
	for i = 0, 3 do
		for _, x in { -1, 1 } do
			make(model, jaw, "Tooth", V(0.1, 0.14, 0.1), CF(x * 0.27, 2.77, -2.0 - i * 0.28), CLAW)
		end
	end
	-- Spines down the back, swept back.
	for i, h in { 0.9, 1.15, 1.05, 0.85, 0.6 } do
		wedge(
			model,
			body,
			"Spine",
			V(0.18, h, 0.75),
			CF(0, 2.72 + h / 2 - (i - 1) * 0.04, -0.9 + (i - 1) * 0.48),
			pal.Plate
		)
	end
	-- Long hind legs, bent back at the ankle.
	for _, x in { -1, 1 } do
		local leg = limb(
			model,
			body,
			"Leg",
			V(0.6, 1.1, 0.95),
			CF(x * 0.62, 1.55, 0.55),
			V(x * 0.62, 2.05, 0.45),
			"Stride",
			x,
			BODY
		)
		plate(model, leg, "Thigh", V(0.64, 0.55, 0.52), CF(x * 0.66, 1.78, 0.6), pal)
		make(model, leg, "Shin", V(0.42, 0.9, 0.42), CF(x * 0.65, 0.78, 0.95) * A(rad(-20), 0, 0), BODY)
		make(model, leg, "Foot", V(0.6, 0.25, 0.98), CF(x * 0.65, 0.14, 0.55), BODY2)
		claws(model, leg, x * 0.65, 0.12, 0.0, 3, 0.2, V(0.14, 0.16, 0.26))
	end
	-- Small clawed arms, tucked.
	for _, x in { -1, 1 } do
		local arm = limb(
			model,
			body,
			"Arm",
			V(0.3, 0.75, 0.3),
			CF(x * 0.56, 1.75, -1.0) * A(rad(-30), 0, 0),
			V(x * 0.56, 2.1, -1.0),
			"Arm",
			x,
			BODY
		)
		claws(model, arm, x * 0.56, 1.35, -1.32, 2, 0.12, V(0.1, 0.12, 0.2))
	end
	-- A long whip of a tail with spines on it.
	local parent = body
	local z = 1.1
	for i, s in { V(0.85, 0.75, 1.1), V(0.65, 0.55, 1.1), V(0.45, 0.4, 1.0), V(0.3, 0.28, 0.9) } do
		local y = 2.25 - (i - 1) * 0.04
		local seg = limb(model, parent, "Tail", s, CF(0, y, z + s.Z / 2), V(0, y, z), "Tail", 1, BODY)
		if i < 4 then
			wedge(
				model,
				seg,
				"Spine",
				V(0.14, 0.5 - i * 0.1, 0.55),
				CF(0, y + s.Y / 2 + (0.5 - i * 0.1) / 2, z + s.Z / 2),
				pal.Plate
			)
			plate(model, seg, "Stripe", V(s.X * 1.04, 0.12, 0.3), CF(0, y, z + s.Z * 0.75), pal)
		end
		parent, z = seg, z + s.Z - 0.05
	end
end

-- Carapace -------------------------------------------------------------------------------------
local function carapace(model: Model, pal)
	local r = root(model, V(2.4, 1, 2.6), 1.35)
	local belly = limb(model, r, "Belly", V(2.6, 0.7, 3.2), CF(0, 1.25, 0), V(0, 1.1, 0), "Body", 1, BODY)
	-- The shell, in three steps, tiled with plates.
	local shell = make(model, belly, "Shell", V(3.3, 0.7, 3.6), CF(0, 1.8, 0.05), BODY2)
	make(model, shell, "ShellTop", V(2.6, 0.55, 2.9), CF(0, 2.35, 0.05), BODY2)
	make(model, shell, "ShellCrown", V(1.6, 0.4, 1.9), CF(0, 2.75, 0.05), BODY)
	for _, x in { -0.85, 0, 0.85 } do
		for _, z in { -0.62, 0.7 } do
			plate(
				model,
				shell,
				"Tile",
				V(0.74, 0.22, 0.8),
				CF(x, 2.66, z) * A(0, rad(if x == 0 then 0 else 8 * x), 0),
				pal
			)
		end
	end
	for _, x in { -0.38, 0.38 } do
		plate(model, shell, "Tile", V(0.62, 0.2, 0.72), CF(x, 3.02, 0.05), pal)
	end
	-- Spikes round the rim.
	for _, spot in { { 1.5, -1.1 }, { 1.62, 0.3 }, { 1.4, 1.5 }, { -1.5, -1.1 }, { -1.62, 0.3 }, { -1.4, 1.5 } } do
		plate(model, shell, "RimSpike", V(0.42, 0.36, 0.42), CF(spot[1], 2.15, spot[2]) * A(0, rad(45), 0), pal)
	end
	for _, x in { -1, 1 } do
		glow(model, shell, "Vent", V(0.08, 0.15, 1.4), CF(x * 1.66, 1.86, 0.1), pal)
	end
	glow(model, shell, "Vent", V(1.2, 0.12, 0.08), CF(0, 1.96, -1.83), pal)
	-- A low horned head.
	local head = make(model, belly, "Head", V(1.3, 0.85, 1.1), CF(0, 1.45, -2.2), BODY2)
	wedge(model, head, "Horn", V(0.36, 0.72, 0.95), CF(0, 2.02, -2.42) * A(0, math.pi, 0), pal.Plate)
	for _, x in { -1, 1 } do
		plate(model, head, "Cheek", V(0.26, 0.6, 0.82), CF(x * 0.68, 1.5, -2.15), pal)
		glow(model, head, "Eye", V(0.22, 0.14, 0.08), CF(x * 0.38, 1.6, -2.76), pal)
	end
	local jaw = limb(model, head, "Jaw", V(1.1, 0.3, 0.9), CF(0, 1.0, -2.32), V(0, 1.15, -1.85), "Jaw", 1, BODY)
	for i = -1, 1 do
		make(model, jaw, "Tooth", V(0.16, 0.14, 0.12), CF(i * 0.34, 1.2, -2.7), CLAW)
	end
	-- Four stubby legs: front-left with back-right, front-right with back-left.
	for _, spot in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
		local x, z = spot[1] * 1.25, spot[2] * 1.2
		local side = spot[1] * spot[2] * -1
		local leg = limb(model, belly, "Leg", V(0.85, 1.0, 0.85), CF(x, 0.6, z), V(x, 1.1, z), "Stride", side, BODY)
		plate(model, leg, "Knee", V(0.9, 0.36, 0.3), CF(x, 0.86, z - 0.45), pal)
		make(model, leg, "Foot", V(1.0, 0.3, 1.0), CF(x, 0.15, z - 0.05), BODY2)
		claws(model, leg, x, 0.12, z - 0.62, 3, 0.28, V(0.18, 0.18, 0.24))
	end
	-- A short tail ending in a spiked club.
	local tail1 = limb(model, belly, "Tail", V(0.9, 0.6, 0.9), CF(0, 1.4, 2.15), V(0, 1.45, 1.75), "Tail", 1, BODY)
	local tail2 = limb(model, tail1, "Tail", V(0.7, 0.5, 0.8), CF(0, 1.3, 2.9), V(0, 1.35, 2.55), "Tail", 1, BODY)
	local club = limb(model, tail2, "Tail", V(1.1, 0.8, 1.0), CF(0, 1.25, 3.65), V(0, 1.3, 3.25), "Tail", 1, BODY2)
	for _, offset in { V(0.62, 0, 0), V(-0.62, 0, 0), V(0, 0.48, 0) } do
		plate(
			model,
			club,
			"ClubSpike",
			V(0.36, 0.36, 0.36),
			CF(V(0, 1.25, 3.65) + offset) * A(0, rad(45), rad(45)),
			pal
		)
	end
end

local BUILDERS = { Bulwark = bulwark, Razorback = razorback, Carapace = carapace }

-- A kaiju of a species and element, at scale 1, standing at the origin.
function KaijuModels.build(species: string, element: string): Model
	local model = Instance.new("Model")
	model.Name = species
	local palette = KaijuModels.Palettes[element] or KaijuModels.Palettes.Fire
	local builder = BUILDERS[species] or bulwark
	builder(model, palette)
	model:SetAttribute("KaijuSpecies", species)
	model:SetAttribute("KaijuElement", element)
	model:SetAttribute("CreatureShape", "Kaiju")
	return model
end

-- Resizes a kaiju, keeping its joints' rest poses (and its hip height) right.
function KaijuModels.scale(model: Model, scale: number)
	local before = model:GetScale()
	if scale == before then
		return
	end
	model:ScaleTo(scale)
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint:GetAttribute("CreatureMotion") then
			joint:SetAttribute("CreatureRest", joint.C0)
		end
	end
	local hip = model:GetAttribute("KaijuHipHeight")
	if hip then
		model:SetAttribute("KaijuHipHeight", hip * scale / before)
	end
end

return KaijuModels
