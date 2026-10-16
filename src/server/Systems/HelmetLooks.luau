--[[
	Helmet skins (cosmetics, Kind "Helmet"): a whole new head in place of
	the helmet you wear. The helmet's stats, rolls and gem all stay; only its
	look changes. Each skin is its own silhouette, built from parts welded to
	the head, sized to it (the human-sized head ArmorKits builds helmets
	round), so it fits any avatar.

	  HelmetLooks.build(component, character, look)  builds skin `look` into
	      the helmet's Model; false if there's no such skin or no head
	  HelmetLooks.restore(component)  puts the skin's own colours back after
	      the gem, rarity and suit passes (Equipment.dress) have recoloured it
	  HelmetLooks.has(look)

	What each part can carry:
	  VisorFace  its eyes or lens: a visor cosmetic restyles just these
	  VisorFit   how a visor takes to it (Equipment.applyVisor): "Eye", a
	             glowing eye, lit in the visor's colour whatever the visor;
	             "Lens", glass in front of the eyes, tinted by the visor and
	             see-through to them
	  VisorTint  lit by the eyes' light, not an eye: takes the visor's colour too
	  VisorLight (on a light) lit by the eyes: takes the visor's colour too
	  StoneSeat  where the helmet's gem is set (Equipment.pieceStones)
	  SeamFx     an animated glow (SeamVisibility), as a skin's seams
	A light that breathes is tagged GemGlow (GemLights).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local ArmorKits = require(script.Parent.ArmorKits)

local HelmetLooks = {}

type Segment = { Part: BasePart, Offset: CFrame, Size: Vector3 }
type Builder = { Folder: Instance, Head: Segment, U: number, Count: number }

local PART_NAME = "HelmSkin"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local MAIL = Enum.Material.DiamondPlate

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
-- A spot on the head, in head heights: +X the wearer's right, +Y up, -Z
-- the front; turned by degrees about X, then Y, then Z.
local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

-- Primitives -------------------------------------------------------------------------

-- Block, Wedge (sloping down to the front), Egg (an ellipsoid filling its
-- box), Tube (a cylinder standing along Y).
local function part(
	b: Builder,
	shape: "Block" | "Wedge" | "Egg" | "Tube",
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local u = b.U
	local mat = material or PLASTIC
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part") :: BasePart
	p.Name = PART_NAME
	p.Size = Vector3.new(math.max(size.X * u, 0.02), math.max(size.Y * u, 0.02), math.max(size.Z * u, 0.02))
	p.Color = color
	p.Material = mat
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	-- Small trim needn't cast a shadow; it's most of the shadow cost.
	p.CastShadow = mat ~= NEON and math.max(size.X, size.Y, size.Z) * u > 0.5
	p.CFrame = b.Head.Part.CFrame * b.Head.Offset * CFrame.new(cframe.Position * u) * (cframe - cframe.Position)
	if shape == "Egg" or shape == "Tube" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = if shape == "Egg" then Enum.MeshType.Sphere else Enum.MeshType.Cylinder
		mesh.Parent = p
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.Head.Part
	weld.Part1 = p
	weld.Parent = p
	-- Its own look, for restore().
	p:SetAttribute("SkinColor", color)
	p:SetAttribute("SkinMaterial", mat.Name)
	p.Parent = b.Folder
	b.Count += 1
	return p
end

local function shine(p: BasePart, reflect: number): BasePart
	p.Reflectance = reflect
	p:SetAttribute("SkinReflect", reflect)
	return p
end

local function glass(p: BasePart, transparency: number, reflect: number?): BasePart
	p.Transparency = transparency
	p.CastShadow = false
	return shine(p, reflect or 0.2)
end

-- A tube from `a` to `c`.
local function rod(b: Builder, a: Vector3, c: Vector3, d: number, color: Color3, material: Enum.Material?): BasePart
	local axis = c - a
	local up = axis.Unit
	local side = if math.abs(up.Y) < 0.95
		then Vector3.new(0, 1, 0):Cross(up).Unit
		else Vector3.new(1, 0, 0):Cross(up).Unit
	return part(b, "Tube", CFrame.fromMatrix((a + c) / 2, side, up), v(d, axis.Magnitude, d), color, material)
end

-- Tubes through `points`, round at every joint, `d0` thick at the start
-- tapering to `d1`; `color` may be a function of how far along (0-1).
local function chain(
	b: Builder,
	points: { Vector3 },
	d0: number,
	d1: number,
	color: Color3 | (number) -> Color3,
	material: Enum.Material?
): { BasePart }
	local parts = {}
	local n = #points
	local function shade(t: number): Color3
		return if type(color) == "function" then color(t) else color :: Color3
	end
	for i = 1, n - 1 do
		local t0, t1 = (i - 1) / (n - 1), i / (n - 1)
		table.insert(
			parts,
			rod(b, points[i], points[i + 1], d0 + (d1 - d0) * (t0 + t1) / 2, shade((t0 + t1) / 2), material)
		)
		local d = d0 + (d1 - d0) * t1
		table.insert(parts, part(b, "Egg", CFrame.new(points[i + 1]), v(d, d, d), shade(t1), material))
	end
	return parts
end

-- A triangle facing out of `cframe`'s front, `w` across and `h` tall, its
-- point down (or up): two wedges back to back.
local function triangle(
	b: Builder,
	cframe: CFrame,
	w: number,
	h: number,
	depth: number,
	color: Color3,
	material: Enum.Material?,
	pointUp: boolean?
): { BasePart }
	local base = CFrame.Angles(0, math.pi / 2, 0)
	local left = if pointUp then base else CFrame.Angles(math.pi, 0, 0) * base
	local right = if pointUp then CFrame.Angles(0, math.pi, 0) * base else CFrame.Angles(0, 0, math.pi) * base
	return {
		part(b, "Wedge", cframe * CFrame.new(-w / 4, 0, 0) * left, v(depth, h, w / 2), color, material),
		part(b, "Wedge", cframe * CFrame.new(w / 4, 0, 0) * right, v(depth, h, w / 2), color, material),
	}
end

-- Blocks along an arc in `frame`'s X-Y plane, round its origin, from angle
-- a0 to a1 (degrees: 0 along +X, 90 up): `ends` thick at either end,
-- `middle` thick halfway.
local function arc(
	b: Builder,
	frame: CFrame,
	radius: number,
	a0: number,
	a1: number,
	count: number,
	ends: number,
	middle: number,
	depth: number,
	color: Color3,
	material: Enum.Material?
): { BasePart }
	local parts = {}
	local step = (a1 - a0) / count
	local length = 2 * radius * math.sin(math.rad(math.abs(step)) / 2) * 1.15
	for i = 0, count - 1 do
		local t = (i + 0.5) / count
		local a = math.rad(a0 + step * (i + 0.5))
		local thick = ends + (middle - ends) * math.sin(math.pi * t)
		local cf = frame
			* CFrame.new(radius * math.cos(a), radius * math.sin(a), 0)
			* CFrame.Angles(0, 0, a + math.pi / 2)
		table.insert(parts, part(b, "Block", cf, v(length, thick, depth), color, material))
	end
	return parts
end

-- Plates in a ring round the head at height `y`, from angle `from` to `to`
-- (degrees; 0 is straight back, 90 the wearer's right), each facing out with
-- its foot flared `flare` degrees outward.
local function skirt(
	b: Builder,
	y: number,
	radius: number,
	from: number,
	to: number,
	count: number,
	height: number,
	thick: number,
	flare: number,
	color: Color3 | (number) -> Color3,
	material: Enum.Material?,
	z: number?
): { BasePart }
	local parts = {}
	local step = if count > 1 then (to - from) / (count - 1) else 0
	local width = 2 * radius * math.sin(math.rad(math.abs(step)) / 2) * 1.2
	for i = 0, count - 1 do
		local phi = math.rad(from + step * i)
		local cf = CFrame.new(radius * math.sin(phi), y, (z or 0) + radius * math.cos(phi))
			* CFrame.Angles(0, phi, 0)
			* CFrame.Angles(-math.rad(flare), 0, 0)
		local c = if type(color) == "function" then color(i) else color :: Color3
		table.insert(parts, part(b, "Block", cf, v(math.max(width, 0.06), height, thick), c, material))
	end
	return parts
end

-- An unseen part, for an effect to come off or a stone to sit on.
local function anchor(b: Builder, cframe: CFrame, size: Vector3): BasePart
	local p = part(b, "Block", cframe, size, Color3.new(0, 0, 0))
	p.Transparency = 1
	p.CastShadow = false
	p:SetAttribute("SkinColor", nil)
	p:SetAttribute("SkinMaterial", nil)
	return p
end

-- Markers and effects ----------------------------------------------------------------

-- Its eyes and lenses: a visor cosmetic restyles these (Equipment.applyVisor).
-- Every skin has eyes that glow; one with glass over its face has them
-- behind the glass.
local function eye(p: BasePart): BasePart
	p:SetAttribute("Visor", true)
	p:SetAttribute("VisorFace", true)
	p:SetAttribute("VisorFit", "Eye")
	return p
end
local function lens(p: BasePart): BasePart
	p:SetAttribute("Visor", true)
	p:SetAttribute("VisorFace", true)
	p:SetAttribute("VisorFit", "Lens")
	return p
end
-- Lit by the same light as the eyes (not an eye itself): takes the visor's
-- colour with them.
local function tint(p: BasePart): BasePart
	p:SetAttribute("Visor", true)
	p:SetAttribute("VisorTint", true)
	return p
end

-- Where the helmet's gem is set.
local function seat(p: BasePart): BasePart
	p:SetAttribute("StoneSeat", true)
	return p
end

-- A glow that moves on every client (SeamVisibility): Pulse, Shift,
-- Flicker, Rainbow, Scan or Aurora, from colour `a` towards `b`.
local function animate(p: BasePart, fx: string, a: Color3, b: Color3?, seed: number?, c: Color3?): BasePart
	p:SetAttribute("SeamFx", fx)
	p:SetAttribute("SeamA", a)
	p:SetAttribute("SeamB", b or a)
	p:SetAttribute("SeamC", c)
	p:SetAttribute("SeamSeed", seed or 0)
	CollectionService:AddTag(p, Tags.SkinSeam)
	return p
end

-- A light, breathing (GemLights) if given a period: bright to dim in
-- `period` seconds, down to `dim` (0-1).
local function lamp(p: BasePart, color: Color3, range: number, brightness: number, period: number?, dim: number?)
	local light = Instance.new("PointLight")
	light.Name = "HelmGlow"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	if period then
		light:SetAttribute("PulseBase", brightness)
		light:SetAttribute("PulsePeriod", period)
		light:SetAttribute("PulseDim", dim or 0.5)
		CollectionService:AddTag(light, Tags.GemGlow)
	end
	light.Parent = p
	return light
end
-- A light the eyes give off: it takes the visor's colour with them.
local function eyeLight(light: Light): Light
	light:SetAttribute("VisorLight", true)
	return light
end

type Emit = {
	Texture: string?,
	Colors: { Color3 },
	Size: number,
	Rate: number,
	Life: { number },
	Speed: { number },
	Spread: number?,
	Accel: Vector3?,
	Light: number?,
	Fade: number?, -- how see-through it starts (0-1)
	Grow: boolean?, -- grows as it fades, as smoke does
	Drag: number?,
	Rotate: boolean?,
}
local function emit(p: BasePart, o: Emit): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "HelmFx"
	e.Texture = o.Texture or SPARK_TEXTURE
	e.Color = if #o.Colors > 1 then ColorSequence.new(o.Colors[1], o.Colors[2]) else ColorSequence.new(o.Colors[1])
	e.Size = if o.Grow
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size * 0.4), NumberSequenceKeypoint.new(1, o.Size) })
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, o.Size),
			NumberSequenceKeypoint.new(1, 0),
		})
	e.Transparency = NumberSequence.new(o.Fade or 0.15, 1)
	e.Lifetime = NumberRange.new(o.Life[1], o.Life[2])
	e.Speed = NumberRange.new(o.Speed[1], o.Speed[2])
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Acceleration = o.Accel or Vector3.zero
	e.LightEmission = o.Light or 1
	e.Drag = o.Drag or 0
	e.Rate = o.Rate
	if o.Rotate then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
	end
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	return e
end

-- The skins ----------------------------------------------------------------------------

local DESIGNS: { [string]: (Builder) -> () } = {}

-- Hard Hat: a ribbed yellow site helmet with a headlamp, amber goggles, ear
-- defenders and a dust mask over a navy balaclava.
DESIGNS.HardHat = function(b)
	local yellow, navy = rgb(255, 196, 28), rgb(36, 46, 76)
	local dark, rubber = rgb(52, 56, 64), rgb(28, 28, 32)
	part(b, "Egg", at(0, -0.04, 0), v(0.96, 1.1, 1), navy, FABRIC)
	part(b, "Tube", at(0, -0.56, 0.02), v(0.6, 0.3, 0.6), navy, FABRIC)
	-- The shell, its ribs, brim and peak.
	shine(part(b, "Egg", at(0, 0.3, 0.03), v(1.14, 0.74, 1.22), yellow), 0.08)
	part(b, "Egg", at(0, 0.31, 0.03), v(0.11, 0.8, 1.27), yellow)
	for _, x in { -0.25, 0.25 } do
		part(b, "Egg", at(x, 0.3, 0.03), v(0.09, 0.72, 1.14), rgb(240, 182, 24))
	end
	shine(part(b, "Tube", at(0, 0.27, 0.03), v(1.26, 0.05, 1.32), yellow), 0.08)
	part(b, "Egg", at(0, 0.27, -0.5, -6), v(0.86, 0.06, 0.62), yellow)
	-- The headlamp, the stone set just under it.
	part(b, "Tube", at(0, 0.5, -0.53, 90), v(0.26, 0.14, 0.26), dark, METAL)
	local bulb = part(b, "Tube", at(0, 0.5, -0.61, 90), v(0.2, 0.03, 0.2), rgb(255, 244, 210), NEON)
	local beam = Instance.new("SpotLight")
	beam.Name = "HelmGlow"
	beam.Color = rgb(255, 236, 196)
	beam.Range = 14
	beam.Angle = 50
	beam.Brightness = 1.2
	beam.Shadows = false
	beam.Face = Enum.NormalId.Bottom -- (the lens's -Y faces forward)
	beam.Parent = bulb
	seat(part(b, "Block", at(0, 0.36, -0.53, -20), v(0.16, 0.1, 0.05), yellow))
	-- Goggles on their strap.
	part(b, "Tube", at(0, 0.07, 0.02), v(1, 0.12, 1.04), rubber, FABRIC)
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.2, 0.07, -0.5, 90), v(0.3, 0.13, 0.3), dark, METAL)
		eye(part(b, "Egg", at(side * 0.2, 0.07, -0.57), v(0.13, 0.07, 0.02), rgb(255, 214, 120), NEON))
		lens(
			glass(
				part(b, "Tube", at(side * 0.2, 0.07, -0.59, 90), v(0.23, 0.02, 0.23), rgb(255, 160, 30), GLASS),
				0.35,
				0.3
			)
		)
	end
	part(b, "Block", at(0, 0.07, -0.53), v(0.12, 0.05, 0.05), dark, METAL)
	-- Dust mask and its two filters.
	part(b, "Egg", at(0, -0.25, -0.42), v(0.44, 0.32, 0.26), rgb(92, 98, 108))
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.19, -0.3, -0.5, 90, side * 25), v(0.17, 0.12, 0.17), rgb(70, 74, 82))
		part(b, "Tube", at(side * 0.215, -0.3, -0.555, 90, side * 25), v(0.13, 0.02, 0.13), rgb(255, 120, 30))
	end
	-- Ear defenders on their arms.
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.5, 0, 0.02, 0, 0, 90), v(0.36, 0.16, 0.36), rgb(232, 80, 36))
		part(b, "Tube", at(side * 0.58, 0, 0.02, 0, 0, 90), v(0.26, 0.02, 0.26), dark)
		part(b, "Block", at(side * 0.55, 0.17, 0.02), v(0.05, 0.22, 0.1), dark, METAL)
	end
	-- Reflective tape round the shell, and a gem sticker on either side.
	shine(part(b, "Tube", at(0, 0.4, 0.03), v(1.11, 0.045, 1.19), rgb(226, 232, 240), METAL), 0.5)
	for _, side in { -1, 1 } do
		local spot = at(side * 0.566, 0.47, 0.06, 0, side * -90, 0)
		triangle(b, spot * CFrame.new(0, 0.035, 0), 0.13, 0.07, 0.015, rgb(70, 220, 255), PLASTIC, true)
		triangle(b, spot * CFrame.new(0, -0.045, 0), 0.13, 0.09, 0.015, rgb(40, 170, 230), PLASTIC)
	end
	-- The lamp's cord over the crown to the battery pack at the back, its
	-- red tail light blinking.
	chain(b, {
		v(0.1, 0.5, -0.6),
		v(0.13, 0.66, -0.32),
		v(0.14, 0.69, 0.02),
		v(0.14, 0.62, 0.38),
		v(0.13, 0.32, 0.68),
		v(0.1, 0.18, 0.6),
	}, 0.035, 0.035, rubber, FABRIC)
	shine(part(b, "Block", at(0, 0.08, 0.55, -8), v(0.32, 0.2, 0.1), dark, METAL), 0.15)
	part(b, "Block", at(0, 0.13, 0.605, -8), v(0.2, 0.03, 0.01), rgb(255, 196, 28))
	local tail = part(b, "Tube", at(0, 0.04, 0.61, 82), v(0.08, 0.02, 0.08), rgb(255, 40, 40), NEON)
	animate(tail, "Pulse", rgb(255, 40, 40))
	lamp(tail, rgb(255, 50, 40), 3, 0.5, 1.2, 0.15)
end

-- Star Bubble: a 1950s fishbowl space helmet: a white comms cap and smoked
-- face shield under clear glass, a collar ring, a blinking antenna and
-- navigation lights, stardust drifting off it.
DESIGNS.StarBubble = function(b)
	local white, silver, red = rgb(236, 238, 244), rgb(200, 206, 218), rgb(222, 52, 56)
	part(b, "Egg", at(0, 0.02, 0.05), v(0.92, 1.04, 0.98), white, FABRIC)
	-- A racing stripe over the cap, brow to nape.
	part(b, "Tube", at(0, 0.02, 0.05, 0, 0, 90), v(1.065, 0.14, 1.005), red, FABRIC)
	-- The smoked shield, the dark behind it and the eyes in the dark.
	part(b, "Egg", at(0, -0.02, -0.14), v(0.66, 0.62, 0.7), rgb(10, 12, 18))
	for _, side in { -1, 1 } do
		eye(part(b, "Egg", at(side * 0.13, 0.01, -0.48), v(0.13, 0.07, 0.025), rgb(120, 220, 255), NEON))
	end
	lens(glass(part(b, "Egg", at(0, -0.02, -0.14), v(0.7, 0.66, 0.78), rgb(24, 30, 46), GLASS), 0.4, 0.35))
	seat(part(b, "Egg", at(0, 0.37, -0.36), v(0.16, 0.12, 0.1), white, FABRIC))
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.46, 0, 0.05, 0, 0, 90), v(0.3, 0.1, 0.3), white)
		part(b, "Tube", at(side * 0.515, 0, 0.05, 0, 0, 90), v(0.18, 0.02, 0.18), rgb(30, 32, 38))
	end
	-- The bowl (kept clear: it's glass, not the visor).
	local bowl = glass(part(b, "Egg", at(0, 0.08, 0.02), v(1.52, 1.52, 1.52), rgb(206, 232, 255), GLASS), 0.62, 0.25)
	bowl:SetAttribute("Visor", true)
	part(b, "Tube", at(0, -0.62, 0.02), v(1.24, 0.17, 1.24), silver, METAL)
	part(b, "Tube", at(0, -0.51, 0.02), v(1.16, 0.06, 1.16), red)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		part(
			b,
			"Egg",
			at(0.62 * math.sin(a), -0.62, 0.02 + 0.62 * math.cos(a)),
			v(0.07, 0.07, 0.07),
			rgb(90, 96, 108),
			METAL
		)
	end
	-- Navigation lights: red on the left, green on the right.
	local port = part(b, "Egg", at(-0.5, -0.55, -0.34), v(0.09, 0.09, 0.09), rgb(255, 50, 60), NEON)
	animate(port, "Pulse", rgb(255, 50, 60), nil, 0)
	local starboard = part(b, "Egg", at(0.5, -0.55, -0.34), v(0.09, 0.09, 0.09), rgb(60, 255, 120), NEON)
	animate(starboard, "Pulse", rgb(60, 255, 120), nil, 3)
	-- The antenna, out through the top of the bowl.
	part(b, "Tube", at(0.24, 0.8, 0.05, 0, 0, -20), v(0.14, 0.05, 0.14), silver, METAL)
	rod(b, v(0.24, 0.8, 0.05), v(0.36, 1.18, 0.08), 0.035, silver, METAL)
	local tip = part(b, "Egg", at(0.365, 1.2, 0.08), v(0.11, 0.11, 0.11), red, NEON)
	animate(tip, "Pulse", red)
	lamp(tip, red, 4, 0.5, 0.9, 0.2)
	-- The life-support pack on the collar's back: two air tanks, a grille
	-- and its status lights.
	shine(part(b, "Block", at(0, -0.46, 0.74, -6), v(0.5, 0.34, 0.16), silver, METAL), 0.25)
	for k = -1, 1 do
		part(b, "Block", at(k * 0.1, -0.42, 0.83, -6), v(0.05, 0.18, 0.02), rgb(70, 76, 90))
	end
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.3, -0.44, 0.76), v(0.15, 0.42, 0.15), white)
		part(b, "Egg", at(side * 0.3, -0.22, 0.76), v(0.15, 0.1, 0.15), red)
	end
	local status = part(b, "Egg", at(0.17, -0.58, 0.83), v(0.05, 0.05, 0.03), rgb(60, 255, 120), NEON)
	animate(status, "Pulse", rgb(60, 255, 120), nil, 1.5)
	part(b, "Egg", at(-0.17, -0.58, 0.83), v(0.05, 0.05, 0.03), rgb(255, 196, 40), NEON)
	emit(bowl, {
		Colors = { rgb(200, 230, 255), rgb(255, 255, 255) },
		Size = 0.12,
		Rate = 3,
		Life = { 1.2, 2 },
		Speed = { 0.1, 0.3 },
		Fade = 0.2,
	})
end

-- Arena Plume: a bronze gladiator's helmet, its wide brim over a grated
-- face with two round eye grilles, a red horsehair crest from brow to nape
-- and white feathers at the sides.
DESIGNS.ArenaPlume = function(b)
	local bronze, deep = rgb(198, 142, 64), rgb(150, 100, 44)
	local hair, hairDark = rgb(204, 32, 38), rgb(150, 20, 28)
	shine(part(b, "Egg", at(0, 0.1, 0.03), v(1.1, 1.2, 1.16), bronze, METAL), 0.15)
	shine(part(b, "Egg", at(0, 0.1, 0.03), v(0.16, 1.27, 1.22), deep, METAL), 0.15)
	-- The grated face: a shallow plate under the brim, pierced.
	shine(part(b, "Egg", at(0, -0.02, -0.42), v(0.84, 0.76, 0.3), deep, METAL), 0.12)
	local function onFace(x: number, y: number): number
		return -0.42 - 0.15 * math.sqrt(math.max(1 - (x / 0.42) ^ 2 - ((y + 0.02) / 0.38) ^ 2, 0))
	end
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.18, 0.08, -0.556, 90), v(0.2, 0.004, 0.2), rgb(10, 8, 6))
		eye(part(b, "Egg", at(side * 0.18, 0.08, -0.566), v(0.12, 0.06, 0.02), rgb(255, 170, 60), NEON))
		lens(
			glass(
				part(b, "Tube", at(side * 0.18, 0.08, -0.56, 90), v(0.22, 0.06, 0.22), rgb(26, 20, 14), GLASS),
				0.4,
				0.2
			)
		)
		part(b, "Block", at(side * 0.18, 0.08, -0.595), v(0.22, 0.025, 0.02), bronze, METAL)
		part(b, "Block", at(side * 0.18, 0.08, -0.595), v(0.025, 0.22, 0.02), bronze, METAL)
	end
	for row = 0, 2 do
		for col = 0, 3 do
			local x, y = -0.18 + col * 0.12, -0.12 - row * 0.09
			part(b, "Tube", at(x, y, onFace(x, y) - 0.005, 90), v(0.055, 0.03, 0.055), rgb(26, 20, 14))
		end
	end
	-- An engraved band round the bowl.
	shine(part(b, "Tube", at(0, 0.46, 0.03), v(0.9, 0.04, 0.95), deep, METAL), 0.15)
	-- The brim, edged darker, the stone set on the brow above it.
	part(b, "Tube", at(0, 0.27, 0.04), v(1.42, 0.03, 1.46), deep, METAL)
	shine(part(b, "Tube", at(0, 0.285, 0.04), v(1.32, 0.045, 1.36), bronze, METAL), 0.15)
	-- A neck guard flaring out at the back.
	for _, p in skirt(b, -0.24, 0.5, -75, 75, 7, 0.28, 0.04, 28, bronze, METAL, 0.04) do
		shine(p, 0.15)
	end
	seat(shine(part(b, "Egg", at(0, 0.37, -0.5), v(0.18, 0.12, 0.08), deep, METAL), 0.15))
	part(b, "Tube", at(0, -0.5, 0.06), v(1, 0.12, 1.02), deep, METAL)
	-- The crest, brow to nape, its hair longest over the crown.
	local n = 13
	for i = 0, n - 1 do
		local t = i / (n - 1)
		local theta = math.rad(-58 + 158 * t)
		local tall = 0.24 + 0.16 * math.sin(math.pi * math.min(t * 1.15, 1))
		local r = 0.6 + tall / 2
		part(
			b,
			"Block",
			CFrame.new(0, 0.12 + r * math.cos(theta), 0.03 + r * math.sin(theta)) * CFrame.Angles(theta, 0, 0),
			v(0.13, tall, 0.15),
			if i % 2 == 0 then hair else hairDark,
			FABRIC
		)
	end
	-- Feathers at either side, in bronze holders.
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.55, 0.36, 0.08, 0, 0, side * -14), v(0.08, 0.14, 0.08), deep, METAL)
		part(b, "Egg", at(side * 0.62, 0.68, 0.1, 0, 0, side * -14), v(0.07, 0.62, 0.16), rgb(244, 240, 232), FABRIC)
		part(b, "Egg", at(side * 0.665, 0.86, 0.1, 0, 0, side * -14), v(0.05, 0.3, 0.12), rgb(220, 60, 60), FABRIC)
	end
end

-- Deep Diver: a copper diving bonnet with a brass faceplate and grilled
-- side ports on a bolted corselet, an air hose down the back and a valve
-- wheel, trailing bubbles.
DESIGNS.DeepDiver = function(b)
	local copper, brass, dark = rgb(186, 106, 60), rgb(214, 168, 80), rgb(38, 34, 32)
	local port = rgb(40, 84, 96)
	shine(part(b, "Egg", at(0, 0.08, 0.02), v(1.34, 1.34, 1.34), copper, METAL), 0.18)
	shine(part(b, "Egg", at(0, -0.64, 0.04), v(1.72, 0.52, 1.42), rgb(170, 96, 54), METAL), 0.15)
	shine(part(b, "Tube", at(0, -0.48, 0.02), v(1.12, 0.12, 1.12), brass, METAL), 0.2)
	for i = 0, 9 do
		local a = math.rad(i * 36)
		part(b, "Egg", at(0.58 * math.sin(a), -0.48, 0.02 + 0.58 * math.cos(a)), v(0.08, 0.08, 0.08), brass, METAL)
	end
	-- The faceplate.
	shine(part(b, "Tube", at(0, 0.06, -0.63, 90), v(0.6, 0.1, 0.6), brass, METAL), 0.2)
	-- The diver's eyes in the dark behind the glass.
	part(b, "Tube", at(0, 0.06, -0.683, 90), v(0.47, 0.006, 0.47), rgb(10, 14, 18))
	for _, side in { -1, 1 } do
		eye(part(b, "Egg", at(side * 0.1, 0.08, -0.69), v(0.12, 0.065, 0.02), rgb(90, 255, 210), NEON))
	end
	lens(glass(part(b, "Tube", at(0, 0.06, -0.705, 90), v(0.47, 0.02, 0.47), port, GLASS), 0.4, 0.4))
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		part(b, "Egg", at(0.265 * math.cos(a), 0.06 + 0.265 * math.sin(a), -0.685), v(0.045, 0.045, 0.03), brass, METAL)
	end
	-- Wing nuts holding the bonnet to the corselet, a nameplate between them.
	for _, side in { -1, 1 } do
		part(b, "Tube", at(side * 0.3, -0.48, -0.49, 90), v(0.06, 0.06, 0.06), brass, METAL)
		shine(part(b, "Block", at(side * 0.3, -0.48, -0.525, 0, 0, side * 12), v(0.2, 0.055, 0.025), brass, METAL), 0.2)
		part(b, "Egg", at(side * 0.3, -0.48, -0.53), v(0.07, 0.07, 0.04), brass, METAL)
	end
	shine(part(b, "Block", at(0, -0.6, -0.665), v(0.3, 0.1, 0.02), brass, METAL), 0.25)
	part(b, "Block", at(0, -0.6, -0.677), v(0.22, 0.02, 0.01), dark)
	-- The air valve on the crown.
	shine(part(b, "Tube", at(0, 0.75, 0.04), v(0.16, 0.08, 0.16), brass, METAL), 0.2)
	part(b, "Egg", at(0, 0.8, 0.04), v(0.08, 0.06, 0.08), brass, METAL)
	part(b, "Tube", at(0, 0.38, -0.6, 90), v(0.1, 0.06, 0.1), brass, METAL)
	seat(shine(part(b, "Block", at(0, 0.42, -0.56, -30), v(0.18, 0.12, 0.06), brass, METAL), 0.2))
	-- Side ports, behind grilles.
	for _, side in { -1, 1 } do
		local turn = CFrame.Angles(0, math.rad(side * -55), 0)
		local out = turn * CFrame.new(0, 0.06, -0.66)
		local frame = CFrame.new(0, 0, 0.02) * out
		shine(part(b, "Tube", frame * CFrame.Angles(math.pi / 2, 0, 0), v(0.38, 0.08, 0.38), brass, METAL), 0.2)
		lens(
			part(
				b,
				"Tube",
				frame * CFrame.new(0, 0, -0.045) * CFrame.Angles(math.pi / 2, 0, 0),
				v(0.29, 0.02, 0.29),
				port,
				GLASS
			)
		)
		for k = -1, 1 do
			part(b, "Block", frame * CFrame.new(k * 0.08, 0, -0.065), v(0.025, 0.3, 0.025), brass, METAL)
		end
	end
	-- The air valve and its wheel.
	part(b, "Tube", at(0.66, -0.22, 0.18, 0, 0, 90), v(0.15, 0.18, 0.15), brass, METAL)
	part(b, "Tube", at(0.76, -0.22, 0.18, 0, 0, 90), v(0.26, 0.035, 0.26), rgb(176, 40, 30), METAL)
	-- The hose, out of the back and down.
	part(b, "Tube", at(0.14, 0.24, 0.66, 70), v(0.18, 0.12, 0.18), brass, METAL)
	chain(
		b,
		{ v(0.14, 0.22, 0.7), v(0.28, 0.02, 0.86), v(0.36, -0.32, 0.94), v(0.34, -0.72, 0.9) },
		0.13,
		0.12,
		dark,
		FABRIC
	)
	emit(anchor(b, at(0, 0.66, 0.1), v(0.12, 0.08, 0.12)), {
		Colors = { rgb(210, 240, 255), rgb(255, 255, 255) },
		Size = 0.14,
		Rate = 4,
		Life = { 1.2, 2 },
		Speed = { 0.6, 1.2 },
		Spread = 18,
		Accel = Vector3.new(0, 1.2, 0),
		Light = 0.3,
		Fade = 0.35,
	})
end

-- Jarl's Horns: an iron spangenhelm with a nasal and spectacle guard, a
-- mail curtain, a braided ginger beard, a fur collar and great curved
-- ivory horns.
DESIGNS.JarlHorns = function(b)
	local iron, band = rgb(112, 114, 122), rgb(176, 134, 62)
	local beard, fur = rgb(188, 96, 40), rgb(174, 162, 148)
	part(b, "Egg", at(0, -0.06, 0.02), v(0.94, 1.04, 1), rgb(42, 32, 28), Enum.Material.Leather)
	-- The mail, under everything: a hood of it, flaring out over the
	-- shoulders at the sides and back.
	local mail = rgb(140, 146, 156)
	part(b, "Tube", at(0, -0.3, 0.06), v(0.98, 0.5, 1), mail, MAIL)
	skirt(b, -0.38, 0.5, -140, 140, 12, 0.44, 0.04, 16, mail, MAIL, 0.06)
	-- The bowl, its bands and the brow band with its rivets.
	shine(part(b, "Egg", at(0, 0.2, 0.02), v(1.06, 0.98, 1.12), iron, METAL), 0.12)
	shine(part(b, "Egg", at(0, 0.2, 0.02), v(0.1, 1.02, 1.16), band, METAL), 0.2)
	shine(part(b, "Egg", at(0, 0.2, 0.02), v(1.1, 1.02, 0.1), band, METAL), 0.2)
	shine(part(b, "Tube", at(0, 0.2, 0.02), v(1.09, 0.12, 1.15), band, METAL), 0.2)
	for i = 0, 9 do
		local a = math.rad(i * 36 + 18)
		part(b, "Egg", at(0.55 * math.sin(a), 0.2, 0.02 + 0.58 * math.cos(a)), v(0.06, 0.06, 0.06), iron, METAL)
	end
	seat(shine(part(b, "Egg", at(0, 0.33, -0.52), v(0.16, 0.14, 0.08), band, METAL), 0.2))
	-- Spectacle guard and nasal.
	shine(part(b, "Egg", at(0, 0.04, -0.47), v(0.66, 0.3, 0.18), iron, METAL), 0.12)
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.17, 0.04, -0.548), v(0.17, 0.11, 0.01), rgb(10, 12, 18))
		eye(part(b, "Egg", at(side * 0.17, 0.04, -0.56), v(0.11, 0.055, 0.02), rgb(140, 210, 255), NEON))
		lens(
			glass(part(b, "Egg", at(side * 0.17, 0.04, -0.555), v(0.19, 0.13, 0.04), rgb(16, 20, 30), GLASS), 0.4, 0.3)
		)
	end
	shine(part(b, "Block", at(0, -0.02, -0.57), v(0.09, 0.38, 0.05), iron, METAL), 0.12)
	-- The beard, full at the cheeks and coming to a point, its strands, its
	-- moustache and two braids.
	part(b, "Egg", at(0, -0.26, -0.42), v(0.72, 0.4, 0.34), beard, FABRIC)
	chain(b, { v(0, -0.36, -0.5), v(0, -0.52, -0.54), v(0, -0.68, -0.52) }, 0.4, 0.12, beard, FABRIC)
	for _, x in { -0.13, 0, 0.13 } do
		local y = -0.33
		local z = -0.42 - 0.17 * math.sqrt(math.max(1 - (x / 0.36) ^ 2 - ((y + 0.26) / 0.2) ^ 2, 0)) - 0.008
		part(b, "Egg", at(x, y, z, 0, 0, x * 40), v(0.035, 0.24, 0.03), rgb(164, 80, 32), FABRIC)
	end
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.14, -0.15, -0.56, 0, 0, side * -16), v(0.3, 0.08, 0.12), beard, FABRIC)
		chain(
			b,
			{ v(side * 0.12, -0.5, -0.48), v(side * 0.13, -0.64, -0.5), v(side * 0.14, -0.78, -0.49) },
			0.13,
			0.1,
			beard,
			FABRIC
		)
		part(b, "Tube", at(side * 0.14, -0.86, -0.49), v(0.1, 0.06, 0.1), band, METAL)
	end
	-- Fur collar.
	part(b, "Tube", at(0, -0.64, 0.1), v(1.46, 0.2, 1.36), fur, FABRIC)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		part(b, "Egg", at(0.66 * math.sin(a), -0.6, 0.1 + 0.62 * math.cos(a)), v(0.32, 0.22, 0.32), fur, FABRIC)
	end
	-- The horns: bone at the root, darker at the tip, sweeping out, up and forward.
	local function horn(t: number): Color3
		return rgb(238, 226, 196):Lerp(rgb(110, 90, 70), t ^ 1.6)
	end
	for _, side in { -1, 1 } do
		shine(part(b, "Tube", at(side * 0.5, 0.32, 0.02, 0, 0, side * -70), v(0.26, 0.08, 0.26), band, METAL), 0.2)
		chain(b, {
			v(side * 0.5, 0.32, 0.02),
			v(side * 0.74, 0.42, 0),
			v(side * 0.94, 0.62, -0.06),
			v(side * 1.02, 0.88, -0.14),
			v(side * 0.98, 1.08, -0.24),
			v(side * 0.9, 1.2, -0.32),
		}, 0.23, 0.04, horn)
	end
end

-- Shark Bite: your head in a shark's jaws: grey snout and white teeth
-- over a dark face, a dorsal fin, gills, beady eyes and fins at the jaw.
DESIGNS.SharkBite = function(b)
	local skin, belly = rgb(98, 122, 148), rgb(232, 234, 238)
	local gum, tooth = rgb(170, 60, 72), rgb(248, 248, 240)
	part(b, "Egg", at(0, 0.18, 0.12), v(1.3, 1.1, 1.5), skin)
	part(b, "Egg", at(0, -0.06, 0.16), v(1.12, 0.7, 1.3), belly)
	-- The mouth: gums round a dark face.
	part(b, "Egg", at(0, -0.05, -0.44), v(0.86, 0.74, 0.38), gum)
	part(b, "Egg", at(0, -0.05, -0.495), v(0.672, 0.576, 0.326), rgb(10, 12, 18))
	for _, side in { -1, 1 } do
		eye(part(b, "Egg", at(side * 0.13, 0.02, -0.65), v(0.13, 0.07, 0.02), rgb(255, 236, 170), NEON))
	end
	lens(glass(part(b, "Egg", at(0, -0.05, -0.5), v(0.7, 0.6, 0.34), rgb(20, 26, 40), GLASS), 0.4, 0.3))
	-- Upper jaw (the snout) and the lower jaw.
	part(b, "Egg", at(0, 0.44, -0.5), v(1, 0.42, 0.92), skin)
	part(b, "Egg", at(0, 0.37, -0.52), v(0.9, 0.3, 0.86), belly)
	part(b, "Egg", at(0, -0.44, -0.3), v(1, 0.32, 0.82), skin)
	part(b, "Egg", at(0, -0.39, -0.37), v(0.86, 0.24, 0.68), belly)
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.17, 0.5, -0.9), v(0.08, 0.04, 0.06), rgb(30, 34, 40))
	end
	-- Teeth round the face, top and bottom.
	for i = -3, 3 do
		local x = i * 0.1
		local z = -0.5 - 0.36 * math.sqrt(math.max(1 - (x / 0.42) ^ 2, 0))
		local yaw = math.deg(math.atan2(x, 0.42)) * 0.8
		triangle(b, at(x, 0.2, z + 0.06, 0, -yaw), 0.09, 0.13, 0.03, tooth, PLASTIC)
		if i ~= 0 then
			local zl = -0.38 - 0.3 * math.sqrt(math.max(1 - (x / 0.4) ^ 2, 0))
			triangle(b, at(x, -0.31, zl + 0.04, 0, -yaw), 0.08, 0.11, 0.03, tooth, PLASTIC, true)
		end
	end
	-- Eyes, gills, the stone on the snout's brow.
	for _, side in { -1, 1 } do
		shine(part(b, "Egg", at(side * 0.5, 0.42, -0.34), v(0.15, 0.15, 0.15), rgb(14, 14, 18), GLASS), 0.4)
		part(b, "Egg", at(side * 0.55, 0.45, -0.37), v(0.04, 0.04, 0.04), rgb(255, 255, 255), NEON)
		for k = 0, 2 do
			part(
				b,
				"Block",
				at(side * 0.63, 0.08, 0.02 + k * 0.12, 0, side * -8, 0),
				v(0.025, 0.26, 0.035),
				rgb(56, 70, 88)
			)
		end
	end
	seat(part(b, "Egg", at(0, 0.62, -0.62), v(0.18, 0.14, 0.12), skin))
	-- Dorsal fin, pectoral fins, and the body tapering to a tail fin at the back.
	part(b, "Wedge", at(0, 0.92, 0.24, -12), v(0.09, 0.52, 0.56), skin)
	for _, side in { -1, 1 } do
		part(b, "Wedge", at(side * 0.66, -0.4, 0.06, 0, 0, side * 70), v(0.05, 0.36, 0.36), skin)
	end
	chain(b, { v(0, 0.22, 0.7), v(0, 0.26, 0.92), v(0, 0.29, 1.06) }, 0.36, 0.12, skin, PLASTIC)
	part(b, "Wedge", at(0, 0.44, 1.13, -38), v(0.05, 0.36, 0.26), skin)
	part(b, "Wedge", at(0, 0.15, 1.11, 180 + 38), v(0.05, 0.26, 0.2), skin)
	part(b, "Tube", at(0, -0.58, 0.05), v(0.74, 0.24, 0.74), skin)
end

-- Shogun Kabuto: a black-lacquered samurai helmet: gold crescent crest, a
-- three-tier neck guard, turned-back wings, a red war mask with a white
-- moustache, and a burning red stare.
DESIGNS.Shogun = function(b)
	local lacquer, gold, red = rgb(26, 24, 30), rgb(232, 182, 64), rgb(176, 30, 34)
	shine(part(b, "Egg", at(0, 0.26, 0.02), v(1.08, 0.9, 1.14), lacquer), 0.25)
	for i = 0, 5 do
		shine(part(b, "Egg", at(0, 0.27, 0.02, 0, i * 30, 0), v(0.035, 0.93, 1.17), rgb(70, 52, 34)), 0.25)
	end
	shine(part(b, "Tube", at(0, 0.72, 0.02), v(0.16, 0.04, 0.16), gold, METAL), 0.4)
	part(b, "Egg", at(0, 0.74, 0.02), v(0.07, 0.07, 0.07), gold, METAL)
	-- The peak, gold-edged.
	shine(part(b, "Egg", at(0, 0.19, -0.43, 8), v(1, 0.05, 0.54), gold, METAL), 0.4)
	shine(part(b, "Egg", at(0, 0.205, -0.42, 8), v(0.96, 0.06, 0.5), lacquer), 0.25)
	-- The neck guard: three flaring tiers, gold at the hem.
	for tier = 0, 2 do
		skirt(b, 0.06 - tier * 0.16, 0.6 + tier * 0.08, -118, 118, 9, 0.17, 0.05, 18 + tier * 6, lacquer, PLASTIC, 0.06)
	end
	skirt(b, -0.38, 0.79, -118, 118, 9, 0.035, 0.055, 30, gold, METAL, 0.06)
	-- Fukigaeshi: the wings turned back at the front, a gold crest on each.
	for _, side in { -1, 1 } do
		local wing = at(side * 0.66, 0.08, -0.3, 0, side * 50, side * -6)
		shine(part(b, "Block", wing, v(0.06, 0.3, 0.34), lacquer), 0.25)
		shine(
			part(
				b,
				"Tube",
				wing * CFrame.new(side * 0.035, 0, 0) * CFrame.Angles(0, 0, math.pi / 2),
				v(0.16, 0.02, 0.16),
				gold,
				METAL
			),
			0.4
		)
	end
	-- The crescent crest on its gold sun, where the stone is set.
	seat(shine(part(b, "Tube", at(0, 0.32, -0.66, 90), v(0.2, 0.05, 0.2), gold, METAL), 0.45))
	for _, p in arc(b, at(0, 0.86, -0.67), 0.56, 196, 344, 11, 0.025, 0.09, 0.03, gold, METAL) do
		shine(p, 0.45)
	end
	-- Shadowed eyes, a red stare.
	part(b, "Egg", at(0, 0.06, -0.34), v(0.84, 0.26, 0.56), rgb(10, 10, 12))
	for _, side in { -1, 1 } do
		animate(
			eye(
				part(
					b,
					"Block",
					at(side * 0.15, 0.07, -0.61, 0, 0, side * -12),
					v(0.2, 0.045, 0.03),
					rgb(255, 40, 40),
					NEON
				)
			),
			"Pulse",
			rgb(255, 40, 40)
		)
	end
	-- The war mask (menpo): angled cheek plates, a snarl of gold teeth, a
	-- white moustache and chin tuft.
	shine(part(b, "Egg", at(0, -0.23, -0.4), v(0.74, 0.5, 0.42), red), 0.2)
	for _, side in { -1, 1 } do
		shine(part(b, "Block", at(side * 0.3, -0.24, -0.42, 0, side * -35, 0), v(0.05, 0.3, 0.24), red), 0.2)
	end
	shine(part(b, "Wedge", at(0, -0.08, -0.62, 0, 180, 0), v(0.12, 0.16, 0.1), red), 0.2)
	part(b, "Block", at(0, -0.3, -0.605), v(0.28, 0.05, 0.03), rgb(20, 14, 14))
	for k = -1.5, 1.5 do
		shine(part(b, "Block", at(k * 0.06, -0.3, -0.618), v(0.045, 0.035, 0.02), gold, METAL), 0.4)
	end
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.13, -0.21, -0.6, 0, 0, side * 22), v(0.24, 0.06, 0.06), rgb(240, 240, 236), FABRIC)
	end
	part(b, "Egg", at(0, -0.45, -0.53), v(0.12, 0.12, 0.08), rgb(240, 240, 236), FABRIC)
	-- Throat guard.
	for k = 0, 1 do
		shine(part(b, "Block", at(0, -0.52 - k * 0.1, -0.42 - k * 0.02, 12), v(0.7 + k * 0.06, 0.1, 0.05), red), 0.2)
	end
	eyeLight(lamp(anchor(b, at(0, 0.07, -0.58), v(0.04, 0.04, 0.02)), rgb(255, 50, 40), 4, 0.6, 1.8, 0.4))
	emit(anchor(b, at(0, 0.8, 0.02), v(0.6, 0.05, 0.6)), {
		Colors = { rgb(255, 170, 200), rgb(255, 214, 230) },
		Size = 0.1,
		Rate = 2,
		Life = { 2, 3 },
		Speed = { 0.1, 0.3 },
		Accel = Vector3.new(0, -0.6, 0),
		Light = 0.2,
		Fade = 0.1,
		Rotate = true,
	})
end

-- Sun Pharaoh: a gold death mask in a striped gold-and-lapis nemes, the
-- cobra on its brow, a braided beard, a broad collar, and a burning sun
-- disc held between golden horns.
DESIGNS.Pharaoh = function(b)
	local gold, lapis, turquoise = rgb(228, 178, 64), rgb(34, 62, 156), rgb(46, 196, 190)
	local function stripe(i: number): Color3
		return if i % 2 == 0 then gold else lapis
	end
	-- The face.
	shine(part(b, "Egg", at(0, -0.06, -0.07), v(0.78, 0.98, 0.84), gold, METAL), 0.3)
	for _, side in { -1, 1 } do
		eye(part(b, "Egg", at(side * 0.16, 0.06, -0.47), v(0.19, 0.08, 0.06), turquoise, NEON))
		part(b, "Egg", at(side * 0.25, 0.05, -0.39, 0, side * -30, side * 8), v(0.14, 0.03, 0.04), rgb(18, 18, 26))
		part(b, "Egg", at(side * 0.16, 0.15, -0.425, 0, 0, side * -8), v(0.24, 0.035, 0.04), lapis)
	end
	shine(part(b, "Egg", at(0, -0.06, -0.5), v(0.1, 0.18, 0.1), gold, METAL), 0.3)
	part(b, "Block", at(0, -0.24, -0.465), v(0.16, 0.025, 0.03), rgb(120, 40, 30))
	-- The headcloth: a striped cap, flaring wings at the cheeks, lappets
	-- down the front and a queue at the back.
	part(b, "Egg", at(0, 0.18, 0.08), v(1.06, 0.82, 1.06), lapis, FABRIC)
	for i = 0, 5 do
		local y = 0.62 - i * 0.07
		local k = math.sqrt(math.max(1 - ((y - 0.18) / 0.42) ^ 2, 0.05))
		if i % 2 == 0 then
			part(b, "Egg", at(0, y, 0.08), v(1.07 * k + 0.02, 0.04, 1.07 * k + 0.02), gold, FABRIC)
		end
	end
	for _, side in { -1, 1 } do
		-- A wing: one lapis panel flaring out to the shoulder, banded in gold.
		local wing = at(side * 0.56, -0.08, 0.02, 0, 0, side * 12)
		part(b, "Egg", wing, v(0.16, 0.86, 0.66), lapis, FABRIC)
		for i = -2, 2 do
			local dy = i * 0.14
			local f = math.sqrt(1 - (dy / 0.43) ^ 2)
			part(b, "Egg", wing * CFrame.new(0, dy, 0), v(0.16 * f + 0.014, 0.05, 0.66 * f + 0.014), gold, FABRIC)
		end
		for i = 0, 3 do
			part(b, "Block", at(side * 0.42, -0.44 - i * 0.1, -0.2), v(0.2, 0.1, 0.1), stripe(i + 1), FABRIC)
		end
	end
	for i = 0, 3 do
		part(b, "Tube", at(0, -0.22 - i * 0.1, 0.46), v(0.26 - i * 0.02, 0.1, 0.26 - i * 0.02), stripe(i), FABRIC)
	end
	-- The brow band, its stone, and the cobra rising over it.
	shine(part(b, "Tube", at(0, 0.3, 0.06), v(1.09, 0.08, 1.1), gold, METAL), 0.35)
	seat(shine(part(b, "Egg", at(0, 0.3, -0.48), v(0.14, 0.1, 0.06), gold, METAL), 0.35))
	chain(b, { v(0, 0.36, -0.5), v(0, 0.46, -0.56), v(0, 0.55, -0.56) }, 0.06, 0.05, gold, METAL)
	shine(part(b, "Egg", at(0, 0.56, -0.57), v(0.18, 0.2, 0.05), gold, METAL), 0.4)
	part(b, "Egg", at(0, 0.56, -0.595), v(0.09, 0.12, 0.02), rgb(196, 40, 40))
	part(b, "Egg", at(0, 0.67, -0.58), v(0.08, 0.07, 0.09), gold, METAL)
	-- The beard.
	for i = 0, 3 do
		part(b, "Tube", at(0, -0.56 - i * 0.07, -0.38 - i * 0.02, 12), v(0.1, 0.07, 0.1), stripe(i), METAL)
	end
	-- Broad collar.
	shine(part(b, "Tube", at(0, -0.6, 0.02), v(1.3, 0.08, 1.2), gold, METAL), 0.35)
	part(b, "Tube", at(0, -0.65, 0.02), v(1.42, 0.06, 1.32), lapis)
	part(b, "Tube", at(0, -0.69, 0.02), v(1.52, 0.05, 1.42), turquoise)
	shine(part(b, "Tube", at(0, -0.725, 0.02), v(1.6, 0.04, 1.5), gold, METAL), 0.35)
	-- The sun between golden horns.
	for _, side in { -1, 1 } do
		chain(b, {
			v(side * 0.06, 0.6, 0.12),
			v(side * 0.24, 0.72, 0.12),
			v(side * 0.32, 0.9, 0.12),
			v(side * 0.24, 1.1, 0.12),
		}, 0.07, 0.04, gold, METAL)
	end
	shine(part(b, "Tube", at(0, 0.94, 0.14, 90), v(0.48, 0.04, 0.48), gold, METAL), 0.4)
	local sun = part(b, "Tube", at(0, 0.94, 0.11, 90), v(0.4, 0.04, 0.4), rgb(255, 150, 40), NEON)
	animate(sun, "Shift", rgb(255, 120, 30), rgb(255, 220, 90))
	lamp(sun, rgb(255, 180, 70), 7, 0.7, 2.4, 0.45)
	emit(sun, {
		Colors = { rgb(255, 230, 150), rgb(255, 170, 60) },
		Size = 0.12,
		Rate = 3,
		Life = { 0.8, 1.4 },
		Speed = { 0.3, 0.7 },
		Accel = Vector3.new(0, 0.6, 0),
	})
end

-- Mech Ace: a mobile-suit head: white, blue and red armour, a gold V-fin,
-- a red forehead sensor, slanted green eyes over a vented faceplate, and
-- ear pods.
DESIGNS.MechAce = function(b)
	local white, blue, red = rgb(238, 240, 246), rgb(42, 84, 206), rgb(216, 32, 44)
	local gold, dark = rgb(244, 192, 60), rgb(46, 50, 60)
	shine(part(b, "Block", at(0, 0.04, 0.02), v(0.94, 0.86, 1.02), white), 0.1)
	shine(part(b, "Block", at(0, 0.5, 0.08), v(0.8, 0.14, 0.88), white), 0.1)
	shine(part(b, "Wedge", at(0, 0.5, -0.43), v(0.8, 0.14, 0.14), white), 0.1)
	shine(part(b, "Block", at(0, 0.6, 0.14), v(0.2, 0.1, 0.78), blue), 0.12)
	shine(part(b, "Wedge", at(0, 0.6, -0.31), v(0.2, 0.1, 0.12), blue), 0.12)
	-- The forehead sensor (the stone sits on it) and the V-fin.
	seat(shine(part(b, "Block", at(0, 0.36, -0.53), v(0.2, 0.16, 0.08), red), 0.2))
	shine(part(b, "Block", at(0, 0.3, -0.56), v(0.24, 0.08, 0.04), gold, METAL), 0.4)
	for _, side in { -1, 1 } do
		shine(part(b, "Block", at(side * 0.24, 0.56, -0.57, 0, 0, side * -48), v(0.07, 0.58, 0.03), gold, METAL), 0.4)
		shine(
			part(
				b,
				"Wedge",
				at(side * 0.47, 0.77, -0.57, 0, 0, side * -48) * CFrame.Angles(0, math.pi / 2, 0),
				v(0.03, 0.14, 0.07),
				gold,
				METAL
			),
			0.4
		)
	end
	-- Eyes in a dark band.
	part(b, "Block", at(0, 0.13, -0.5), v(0.72, 0.18, 0.06), rgb(14, 16, 22))
	for _, side in { -1, 1 } do
		animate(
			eye(
				part(
					b,
					"Block",
					at(side * 0.16, 0.14, -0.535, 0, 0, side * 10),
					v(0.22, 0.065, 0.02),
					rgb(80, 255, 140),
					NEON
				)
			),
			"Pulse",
			rgb(80, 255, 140)
		)
	end
	eyeLight(lamp(anchor(b, at(0, 0.14, -0.52), v(0.04, 0.04, 0.02)), rgb(90, 255, 150), 4, 0.6, 1.8, 0.4))
	-- Faceplate, chin and vents.
	shine(part(b, "Block", at(0, -0.22, -0.48), v(0.56, 0.36, 0.14), white), 0.1)
	shine(part(b, "Block", at(0, -0.43, -0.5), v(0.3, 0.1, 0.12), red), 0.2)
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			part(b, "Block", at(side * 0.11, -0.14 - k * 0.075, -0.555), v(0.13, 0.035, 0.02), dark)
		end
		-- Cheek guards, ear pods and vulcans.
		shine(part(b, "Block", at(side * 0.38, -0.12, -0.4, 0, side * 22, 0), v(0.16, 0.42, 0.22), blue), 0.12)
		shine(part(b, "Tube", at(side * 0.53, 0.06, 0.02, 0, 0, 90), v(0.38, 0.14, 0.38), white), 0.1)
		part(b, "Tube", at(side * 0.605, 0.06, 0.02, 0, 0, 90), v(0.26, 0.02, 0.26), dark)
		part(b, "Block", at(side * 0.62, 0.06, 0.02), v(0.02, 0.05, 0.2), rgb(255, 206, 60), NEON)
		part(b, "Tube", at(side * 0.3, 0.44, -0.52, 90), v(0.08, 0.12, 0.08), dark, METAL)
	end
	-- Rear fin and neck.
	shine(part(b, "Block", at(0, 0.28, 0.56), v(0.5, 0.3, 0.1), blue), 0.12)
	for k = -1, 1 do
		part(b, "Block", at(k * 0.13, 0.28, 0.615), v(0.08, 0.22, 0.02), dark)
	end
	part(b, "Tube", at(0, -0.56, 0.04), v(0.5, 0.3, 0.5), dark, METAL)
	for k = 0, 1 do
		part(b, "Tube", at(0, -0.5 - k * 0.12, 0.04), v(0.56, 0.04, 0.56), rgb(80, 86, 98), METAL)
	end
	-- Panel lines and a red marking down the sides.
	for _, side in { -1, 1 } do
		part(b, "Block", at(side * 0.476, 0.32, 0.02), v(0.012, 0.02, 0.86), dark)
		part(b, "Block", at(side * 0.476, -0.25, 0.02), v(0.012, 0.02, 0.86), dark)
		part(b, "Block", at(side * 0.476, 0.03, 0.34), v(0.012, 0.56, 0.02), dark)
		part(b, "Block", at(side * 0.476, 0.4, 0.33), v(0.012, 0.07, 0.24), red)
	end
	-- A lit vent under the rear fin, and the antenna.
	part(b, "Block", at(0, -0.04, 0.535), v(0.42, 0.18, 0.02), dark)
	for k = 0, 1 do
		part(b, "Block", at(0, -0.0 - k * 0.08, 0.547), v(0.34, 0.025, 0.01), rgb(255, 206, 60), NEON)
	end
	rod(b, v(0.22, 0.47, 0.36), v(0.32, 0.94, 0.58), 0.03, dark, METAL)
	local beacon = part(b, "Egg", at(0.325, 0.96, 0.59), v(0.06, 0.06, 0.06), red, NEON)
	animate(beacon, "Pulse", red)
end

-- Wyrmking: a crimson dragon's head: a long snout with fangs, a jaw with
-- fire in it, ember eyes under heavy brows, swept horns tipped in gold,
-- frills, a crest of spines, smoke and embers from its nostrils.
DESIGNS.Wyrmking = function(b)
	local crimson, deep, scale = rgb(152, 24, 30), rgb(104, 14, 20), rgb(214, 150, 66)
	local fang, ember = rgb(240, 230, 204), rgb(255, 140, 30)
	shine(part(b, "Egg", at(0, 0.12, 0.06), v(1.02, 0.92, 1.14), crimson), 0.1)
	-- Brows, eyes, and the gold scale on the brow where the stone is set.
	for _, side in { -1, 1 } do
		shine(part(b, "Egg", at(side * 0.22, 0.24, -0.42, 0, 0, side * 22), v(0.4, 0.14, 0.32), deep), 0.1)
		animate(
			eye(part(b, "Egg", at(side * 0.24, 0.11, -0.46, 0, 0, side * 12), v(0.2, 0.1, 0.06), ember, NEON)),
			"Flicker",
			ember,
			rgb(255, 230, 120),
			side
		)
		part(b, "Block", at(side * 0.24, 0.11, -0.495), v(0.025, 0.09, 0.01), rgb(20, 8, 6))
	end
	seat(shine(part(b, "Egg", at(0, 0.36, -0.44), v(0.2, 0.15, 0.08), scale, METAL), 0.25))
	-- The snout and its ridge, nostrils and nose horn.
	shine(part(b, "Egg", at(0, -0.1, -0.56), v(0.6, 0.38, 0.84), crimson), 0.1)
	shine(part(b, "Egg", at(0, 0.02, -0.5), v(0.3, 0.2, 0.76), deep), 0.1)
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.1, -0.03, -0.95), v(0.08, 0.05, 0.06), rgb(20, 8, 6))
	end
	chain(b, { v(0, 0.08, -0.8), v(0, 0.17, -0.85), v(0, 0.24, -0.86) }, 0.07, 0.025, fang)
	-- The jaw, the fire inside it, and the fangs.
	shine(part(b, "Egg", at(0, -0.42, -0.42, -8), v(0.56, 0.18, 0.64), deep), 0.1)
	local fire = part(b, "Egg", at(0, -0.32, -0.52), v(0.4, 0.08, 0.5), rgb(255, 90, 20), NEON)
	animate(fire, "Flicker", rgb(255, 90, 20), rgb(255, 200, 80), 2)
	lamp(fire, rgb(255, 120, 40), 6, 0.9, 0.35, 0.5)
	for _, side in { -1, 1 } do
		triangle(b, at(side * 0.2, -0.33, -0.76, 0, side * -20, 0), 0.08, 0.18, 0.04, fang, PLASTIC)
		triangle(b, at(side * 0.12, -0.31, -0.84, 0, side * -10, 0), 0.05, 0.1, 0.03, fang, PLASTIC)
		triangle(b, at(side * 0.17, -0.36, -0.66, 0, side * -20, 0), 0.06, 0.12, 0.03, fang, PLASTIC, true)
	end
	-- Horns: two great ones swept back, two smaller at the cheeks.
	local function horn(t: number): Color3
		return rgb(64, 42, 38):Lerp(rgb(236, 184, 72), math.clamp((t - 0.45) / 0.55, 0, 1))
	end
	for _, side in { -1, 1 } do
		chain(b, {
			v(side * 0.3, 0.45, 0.08),
			v(side * 0.42, 0.64, 0.34),
			v(side * 0.5, 0.74, 0.64),
			v(side * 0.52, 0.72, 0.94),
			v(side * 0.47, 0.6, 1.16),
		}, 0.2, 0.04, horn)
		chain(b, {
			v(side * 0.46, -0.02, 0.12),
			v(side * 0.62, -0.02, 0.38),
			v(side * 0.7, 0.02, 0.6),
			v(side * 0.71, 0.08, 0.76),
		}, 0.12, 0.03, horn)
		-- Frills: spines with a membrane between them.
		for k, tip in { v(0.76, 0.48, 0.58), v(0.82, 0.22, 0.66), v(0.76, -0.04, 0.6) } do
			rod(b, v(side * 0.48, 0.16, 0.22), v(side * tip.X, tip.Y, tip.Z), 0.035 - k * 0.004, deep)
		end
		part(b, "Egg", at(side * 0.64, 0.22, 0.44, 0, side * 32, 0), v(0.03, 0.56, 0.5), rgb(120, 20, 30))
	end
	-- Spines down the crown to the nape.
	for k, spot in { { 0.6, 0.02 }, { 0.57, 0.22 }, { 0.48, 0.42 }, { 0.34, 0.58 }, { 0.14, 0.68 }, { -0.1, 0.7 } } do
		local theta = math.rad(-10 + k * 22)
		local h = 0.29 - k * 0.026
		part(
			b,
			"Wedge",
			CFrame.new(0, spot[1] + h * 0.35, spot[2]) * CFrame.Angles(theta, 0, 0),
			v(0.065, h, h * 0.9),
			deep
		)
	end
	-- Overlapping scales over the back of the head, either side of the spines.
	for row, y in { 0.34, 0.2, 0.06, -0.08 } do
		local f = math.sqrt(1 - ((y - 0.12) / 0.46) ^ 2)
		local steps = if row % 2 == 1 then { -55, -33, -11, 11, 33, 55 } else { -44, -22, 22, 44 }
		for _, deg in steps do
			local phi = math.rad(deg)
			local cf = CFrame.new(0.515 * f * math.sin(phi), y, 0.06 + 0.575 * f * math.cos(phi))
				* CFrame.Angles(0, phi, 0)
				* CFrame.Angles(math.rad(-28), 0, 0)
			part(b, "Egg", cf, v(0.21, 0.15, 0.045), if row % 2 == 0 then deep else rgb(122, 16, 24))
		end
	end
	-- Neck and its gold belly scales.
	shine(part(b, "Tube", at(0, -0.56, 0.1), v(0.7, 0.34, 0.76), crimson), 0.1)
	shine(part(b, "Egg", at(0, -0.56, -0.24), v(0.42, 0.36, 0.2), scale, METAL), 0.2)
	for k = 0, 2 do
		part(b, "Egg", at(0, -0.46 - k * 0.1, -0.33), v(0.36, 0.025, 0.04), rgb(150, 96, 40), METAL)
	end
	local snout = anchor(b, at(0, -0.02, -0.97), v(0.06, 0.04, 0.04))
	emit(snout, {
		Texture = FIRE_TEXTURE,
		Colors = { rgb(255, 170, 60), rgb(255, 70, 20) },
		Size = 0.14,
		Rate = 6,
		Life = { 0.5, 0.9 },
		Speed = { 0.3, 0.7 },
		Spread = 30,
		Accel = Vector3.new(0, 1.6, 0),
	})
	emit(snout, {
		Texture = SMOKE_TEXTURE,
		Colors = { rgb(90, 80, 76), rgb(50, 46, 46) },
		Size = 0.35,
		Rate = 2,
		Life = { 1, 1.6 },
		Speed = { 0.2, 0.4 },
		Spread = 30,
		Accel = Vector3.new(0, 0.8, 0),
		Light = 0,
		Fade = 0.6,
		Grow = true,
	})
end

-- Halloween ------------------------------------------------------------------------

-- Jack-o'-Helm: a pumpkin with a carved, flickering grin, lit from inside,
-- a stem, a leaf and a curling vine, embers rising off the top.
DESIGNS.JackOLantern = function(b)
	local orange, shade = rgb(234, 112, 22), rgb(206, 90, 14)
	local glow, flash = rgb(255, 150, 30), rgb(255, 232, 120)
	part(b, "Egg", at(0, 0.06, 0.02), v(1.08, 0.98, 1.08), shade)
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		part(
			b,
			"Egg",
			at(0.3 * math.sin(a), 0.06, 0.02 + 0.3 * math.cos(a), 0, i * 45 + 22.5, 0),
			v(0.6, 0.98, 0.62),
			if i % 2 == 0 then orange else rgb(226, 104, 18)
		)
	end
	part(b, "Tube", at(0, -0.48, 0.02), v(0.62, 0.22, 0.62), rgb(150, 66, 12))
	-- The carved face, glowing.
	local carved = {}
	for _, side in { -1, 1 } do
		for _, p in triangle(b, at(side * 0.21, 0.15, -0.575, 0, side * -18, 0), 0.26, 0.2, 0.06, glow, NEON, true) do
			table.insert(carved, p)
		end
	end
	for _, p in triangle(b, at(0, -0.03, -0.6), 0.13, 0.11, 0.06, glow, NEON, true) do
		table.insert(carved, p)
	end
	for i = -2, 2 do
		local x = i * 0.13
		local y = -0.27 + 0.09 * (x / 0.3) ^ 2
		local slope = math.deg(math.atan(2 * 0.09 * x / 0.09))
		table.insert(
			carved,
			part(
				b,
				"Block",
				at(x, y, -0.585 + math.abs(x) * 0.12, 0, -x * 50, slope * 0.25),
				v(0.14, 0.09, 0.05),
				glow,
				NEON
			)
		)
	end
	for _, p in carved do
		animate(eye(p), "Flicker", glow, flash, 1)
	end
	-- Teeth left standing in the grin.
	part(b, "Block", at(-0.07, -0.245, -0.615), v(0.07, 0.05, 0.04), orange)
	part(b, "Block", at(0.12, -0.27, -0.61), v(0.07, 0.05, 0.04), orange)
	-- The light inside.
	eyeLight(lamp(anchor(b, at(0, 0, -0.1), v(0.1, 0.1, 0.1)), rgb(255, 150, 50), 8, 1.1, 0.3, 0.55))
	seat(anchor(b, at(0, 0.38, -0.55), v(0.1, 0.1, 0.02)))
	-- Stem, leaf and vine.
	local green, stalk = rgb(72, 140, 44), rgb(96, 104, 42)
	part(b, "Tube", at(0.01, 0.6, 0.03, 0, 0, -10), v(0.16, 0.22, 0.16), stalk, Enum.Material.Wood)
	local top =
		part(b, "Tube", at(0.03, 0.71, 0.03, 0, 0, -10), v(0.13, 0.05, 0.13), rgb(70, 76, 30), Enum.Material.Wood)
	part(b, "Egg", at(0.22, 0.58, 0.12, 0, 20, -14), v(0.36, 0.03, 0.22), green, FABRIC)
	-- The lid's cut round the stem, the candlelight showing through it.
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local cut = part(
			b,
			"Block",
			CFrame.new(0.21 * math.sin(a), 0.55, 0.02 + 0.21 * math.cos(a))
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 28 else -28)),
			v(0.12, 0.03, 0.04),
			glow,
			NEON
		)
		animate(tint(cut), "Flicker", glow, flash, 1)
	end
	chain(
		b,
		{ v(-0.04, 0.6, 0.03), v(-0.18, 0.66, -0.04), v(-0.28, 0.74, 0.06), v(-0.2, 0.83, 0.14), v(-0.1, 0.8, 0.08) },
		0.04,
		0.025,
		green,
		FABRIC
	)
	emit(top, {
		Colors = { rgb(255, 190, 80), rgb(255, 90, 20) },
		Size = 0.1,
		Rate = 3,
		Life = { 0.8, 1.4 },
		Speed = { 0.4, 0.8 },
		Spread = 25,
		Accel = Vector3.new(0, 1, 0),
	})
end

-- Grim Reaper: a peaked black hood round a bone skull with green fire in its
-- eyes, a tattered mantle, green mist pouring off it.
DESIGNS.GrimReaper = function(b)
	local cloth, void = rgb(34, 34, 44), rgb(4, 4, 6)
	local bone, ghost = rgb(226, 220, 198), rgb(90, 255, 130)
	part(b, "Egg", at(0, 0.1, 0.12), v(1.22, 1.22, 1.28), cloth, FABRIC)
	-- The hood's point, drooping down the back in a long tail, and the
	-- folds of the cloth either side of it.
	chain(
		b,
		{ v(0, 0.6, 0.3), v(0, 0.62, 0.52), v(0, 0.5, 0.74), v(0, 0.28, 0.86), v(0, 0.02, 0.88) },
		0.5,
		0.08,
		cloth,
		FABRIC
	)
	for _, x in { -0.38, -0.2, 0.2, 0.38 } do
		local z = 0.12 + 0.64 * math.sqrt(1 - (x / 0.61) ^ 2 - (0.1 / 0.61) ^ 2) - 0.02
		part(
			b,
			"Egg",
			at(x, 0, z, 0, math.deg(math.atan2(x, z - 0.12)), 0),
			v(0.07, 0.8, 0.07),
			rgb(46, 46, 58),
			FABRIC
		)
	end
	part(b, "Egg", at(0, 0.02, -0.32), v(0.8, 0.94, 0.52), void)
	-- The skull.
	part(b, "Egg", at(0, 0.08, -0.42), v(0.56, 0.58, 0.42), bone)
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.12, 0.08, -0.59), v(0.16, 0.14, 0.06), void)
		animate(eye(part(b, "Egg", at(side * 0.12, 0.08, -0.615), v(0.065, 0.065, 0.04), ghost, NEON)), "Pulse", ghost)
		part(b, "Egg", at(side * 0.18, -0.04, -0.52), v(0.14, 0.08, 0.12), bone)
	end
	triangle(b, at(0, -0.03, -0.615), 0.07, 0.08, 0.03, void, PLASTIC, true)
	part(b, "Egg", at(0, -0.17, -0.46), v(0.38, 0.2, 0.32), bone)
	part(b, "Block", at(0, -0.13, -0.6), v(0.25, 0.06, 0.02), void)
	for k = -2, 2 do
		part(b, "Block", at(k * 0.048, -0.13, -0.61), v(0.035, 0.05, 0.02), rgb(242, 238, 222))
	end
	seat(part(b, "Egg", at(0, 0.27, -0.56), v(0.12, 0.1, 0.06), bone))
	eyeLight(lamp(anchor(b, at(0, 0.08, -0.5), v(0.04, 0.04, 0.04)), rgb(90, 255, 130), 5, 0.7, 1.8, 0.35))
	-- The hood's rim, framing the face.
	part(b, "Egg", at(0, 0.44, -0.44, 12), v(0.8, 0.22, 0.34), cloth, FABRIC)
	for _, side in { -1, 1 } do
		part(b, "Egg", at(side * 0.35, 0.0, -0.44, 0, side * -14, side * 4), v(0.15, 0.92, 0.32), cloth, FABRIC)
	end
	-- The mantle, in tatters.
	part(b, "Tube", at(0, -0.5, 0.08), v(1.16, 0.18, 1.16), cloth, FABRIC)
	skirt(b, -0.74, 0.6, -150, 150, 11, 0.42, 0.04, 14, cloth, FABRIC, 0.08)
	skirt(b, -0.86, 0.66, -135, 135, 6, 0.3, 0.04, 18, rgb(30, 30, 38), FABRIC, 0.08)
	part(b, "Egg", at(0, -0.5, -0.5), v(0.12, 0.12, 0.08), bone)
	emit(anchor(b, at(0, -0.6, 0.1), v(0.9, 0.1, 0.9)), {
		Texture = SMOKE_TEXTURE,
		Colors = { rgb(110, 255, 150), rgb(40, 120, 70) },
		Size = 0.5,
		Rate = 5,
		Life = { 1.4, 2.2 },
		Speed = { 0.1, 0.3 },
		Accel = Vector3.new(0, -0.5, 0),
		Light = 0.4,
		Fade = 0.7,
		Grow = true,
		Rotate = true,
	})
end

-- Witch's Brim: a wide-brimmed witch's hat, its point bent and drooping, a
-- purple band with a gold buckle, over a green face with a hooked nose and
-- glowing violet eyes, lank hair, a crescent moon charm and drifting magic.
DESIGNS.WitchHat = function(b)
	local hat, band, gold = rgb(34, 26, 46), rgb(116, 42, 176), rgb(234, 184, 64)
	local skin, wart, hair = rgb(122, 172, 82), rgb(92, 136, 60), rgb(42, 28, 62)
	local violet = rgb(196, 90, 255)
	-- The face.
	part(b, "Egg", at(0, -0.06, -0.02), v(0.86, 1, 0.92), skin)
	for _, side in { -1, 1 } do
		animate(eye(part(b, "Egg", at(side * 0.16, 0.07, -0.43), v(0.15, 0.09, 0.05), violet, NEON)), "Pulse", violet)
		part(b, "Block", at(side * 0.16, 0.16, -0.43, 0, 0, side * 16), v(0.2, 0.035, 0.03), hair)
	end
	chain(b, { v(0, 0.02, -0.44), v(0, -0.07, -0.6), v(0, -0.15, -0.66), v(0, -0.18, -0.62) }, 0.12, 0.05, skin)
	part(b, "Egg", at(0.035, -0.09, -0.63), v(0.05, 0.05, 0.05), wart)
	for k = -2, 2 do
		part(
			b,
			"Block",
			at(k * 0.06, -0.3 + math.abs(k) * 0.025, -0.42 + math.abs(k) * 0.02, 0, 0, k * 10),
			v(0.07, 0.03, 0.03),
			rgb(46, 20, 34)
		)
	end
	part(b, "Block", at(0.05, -0.33, -0.43), v(0.03, 0.04, 0.02), rgb(240, 236, 210))
	part(b, "Egg", at(0, -0.48, -0.26), v(0.24, 0.18, 0.2), skin)
	-- Lank hair round the sides and back, in locks of uneven length over
	-- a dark mass of it.
	part(b, "Egg", at(0, -0.02, 0.12), v(0.94, 0.94, 0.86), rgb(36, 24, 52), FABRIC)
	for i = 0, 14 do
		local phi = math.rad(-126 + i * 18)
		local long = 0.6 + 0.16 * math.sin(i * 2.3) ^ 2
		local cf = CFrame.new(0.47 * math.sin(phi), 0.33 - long / 2, 0.04 + 0.47 * math.cos(phi))
			* CFrame.Angles(0, phi, 0)
			* CFrame.Angles(math.rad(-8), 0, math.rad(math.sin(i * 1.7) * 6))
		part(b, "Egg", cf, v(0.17, long, 0.07), if i % 2 == 0 then hair else rgb(60, 38, 86), FABRIC)
	end
	-- The brim, drooping at the front, the band and its buckle.
	part(b, "Tube", at(0, 0.36, 0.02), v(1.9, 0.04, 1.9), hat, FABRIC)
	part(b, "Egg", at(0, 0.335, -0.64, -10), v(1.1, 0.04, 0.6), hat, FABRIC)
	part(b, "Tube", at(0, 0.44, 0.04), v(0.96, 0.1, 0.96), band)
	shine(part(b, "Block", at(0, 0.44, -0.49), v(0.2, 0.14, 0.03), gold, METAL), 0.4)
	seat(part(b, "Block", at(0, 0.44, -0.505), v(0.11, 0.07, 0.01), band))
	-- The cone: narrowing up, bent back, the tip drooping.
	for k = 0, 13 do
		local d = 0.84 - k * 0.043
		part(b, "Tube", at(0, 0.52 + k * 0.037, 0.04 + k * 0.0035), v(d, 0.045, d), hat, FABRIC)
	end
	chain(
		b,
		{ v(0, 0.98, 0.09), v(0, 1.16, 0.16), v(0, 1.3, 0.32), v(0, 1.36, 0.5), v(0, 1.3, 0.66) },
		0.27,
		0.06,
		hat,
		FABRIC
	)
	-- A patch on the cone.
	part(b, "Block", at(0.18, 0.66, -0.26, -12, 24, 8), v(0.18, 0.16, 0.02), rgb(86, 60, 112), FABRIC)
	-- A little spider let down on its thread from the brim.
	local web = rgb(214, 214, 224)
	rod(b, v(0.6, 0.34, -0.38), v(0.6, 0.06, -0.38), 0.008, web)
	part(b, "Egg", at(0.6, 0.02, -0.38), v(0.1, 0.1, 0.11), rgb(16, 14, 20))
	part(b, "Egg", at(0.6, -0.05, -0.39), v(0.06, 0.055, 0.06), rgb(16, 14, 20))
	for _, side in { -1, 1 } do
		part(b, "Egg", at(0.6 + side * 0.012, -0.06, -0.42), v(0.016, 0.016, 0.01), rgb(255, 40, 40), NEON)
		for k = 1, 4 do
			local up = 0.03 - k * 0.018
			rod(
				b,
				v(0.6 + side * 0.03, up, -0.38),
				v(0.6 + side * 0.1, up - 0.04, -0.38 + (k - 2.5) * 0.04),
				0.012,
				rgb(16, 14, 20)
			)
		end
	end
	-- The crescent charm on a thread from the tip.
	rod(b, v(0, 1.3, 0.68), v(0, 1.12, 0.72), 0.015, gold)
	local moon = arc(b, at(0, 1.02, 0.72, 0, 0, -30), 0.1, 60, 300, 6, 0.015, 0.05, 0.03, gold, NEON)
	for _, p in moon do
		animate(p, "Shift", gold, violet)
	end
	lamp(moon[3], rgb(190, 110, 255), 6, 0.7, 2, 0.45)
	emit(anchor(b, at(0, 0.7, 0.04), v(0.9, 0.5, 0.9)), {
		Colors = { rgb(200, 120, 255), rgb(120, 255, 160) },
		Size = 0.1,
		Rate = 5,
		Life = { 0.9, 1.6 },
		Speed = { 0.1, 0.4 },
		Accel = Vector3.new(0, 0.4, 0),
	})
end

-- API ----------------------------------------------------------------------------------

function HelmetLooks.has(look: any): boolean
	return type(look) == "string" and DESIGNS[look] ~= nil
end

-- Builds skin `look` into `component` (the helmet's Model), round the
-- character's head. The avatar's own head is hidden under it.
function HelmetLooks.build(component: Instance, character: Model, look: string): boolean
	local design = DESIGNS[look]
	local head = ArmorKits.body(character).Head
	if not design or not head then
		return false
	end
	local human = ArmorKits.humanHead(head)
	local size = human.Size
	local b: Builder = { Folder = component, Head = human, U = (size.X + size.Y + size.Z) / 3, Count = 0 }
	design(b)
	component:SetAttribute("HelmetSkin", look)
	return true
end

-- Puts every skin part's own colour, material and shine back.
function HelmetLooks.restore(component: Instance)
	for _, p in component:GetDescendants() do
		if p:IsA("BasePart") then
			local color = p:GetAttribute("SkinColor")
			if typeof(color) == "Color3" then
				p.Color = color
				local material = p:GetAttribute("SkinMaterial")
				if type(material) == "string" then
					p.Material = (Enum.Material :: any)[material]
				end
				local reflect = p:GetAttribute("SkinReflect")
				p.Reflectance = if type(reflect) == "number" then reflect else 0
				CollectionService:RemoveTag(p, Tags.Prismatic)
				p:SetAttribute("PrismaticBase", nil)
			end
		end
	end
end

HelmetLooks.Looks = DESIGNS

return HelmetLooks
