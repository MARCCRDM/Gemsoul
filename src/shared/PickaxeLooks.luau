--[[
	PickaxeLooks: every pickaxe's model, built the same wherever it shows: in
	your hand at the Outpost (the server builds it, everyone sees it), on an
	expedition (the client), and turning in 3D in the Shop and Wardrobe.

	A skin (a Cosmetic of Kind "Pick") is looks only: the pick you mine with
	(Survey, Titan, Plasma: Shared.Outpost) keeps its swings and power. With
	no skin you hold that pick in its own colour.

	  PickaxeLooks.build(parent, frame, skinId?, tierColor?, weldTo?, bright?)
	      builds into `parent`, `frame` being the grip: +Y runs up the haft to
	      the head, -Z is where the spike points. Parts are welded to `weldTo`
	      (a hand), or anchored without one. Returns the parts and the tip.
	  PickaxeLooks.Looks[id].Impact   what a swing's hit looks like
	                                  (OutpostScene draws it at the rock)

	Each skin has its own silhouette, particles, light and a trail that
	streaks through every swing.
]]
local CollectionService = game:GetService("CollectionService")

local Tags = require(script.Parent.Tags)

local PickaxeLooks = {}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder standing along the haft
local FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder pointing along the spike
local WHITE = Color3.new(1, 1, 1)

type Add = (CFrame, Vector3, Color3, Enum.Material?, { [string]: any }?) -> BasePart

-- Particles drifting off a part.
local function emitter(parent: Instance, color: Color3, rate: number, o: { [string]: any }?)
	local opts = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = "PickFx"
	e.Texture = opts.Texture or SPARKLE
	e.Color = ColorSequence.new(opts.From or color:Lerp(WHITE, 0.4), color)
	e.LightEmission = opts.Light or 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size or 0.2),
		NumberSequenceKeypoint.new(1, opts.EndSize or 0),
	})
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Alpha or 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.Life or 0.5, (opts.Life or 0.5) * 1.6)
	e.Speed = NumberRange.new(opts.Speed or 0.6, (opts.Speed or 0.6) * 2)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Acceleration = opts.Acceleration or Vector3.new(0, 1, 0)
	e.Rate = rate
	e.Parent = parent
	return e
end
local function glow(parent: Instance, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Name = "PickLight"
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = parent
	return l
end
-- A streak through every swing: a ribbon along the spike.
local function trail(tip: BasePart, along: Vector3, from: Color3, to: Color3)
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Name, b.Name = "TrailTip", "TrailBase"
	a.Position, b.Position = along * 0.5, -along * 0.5
	a.Parent, b.Parent = tip, tip
	local t = Instance.new("Trail")
	t.Name = "PickTrail"
	t.Attachment0, t.Attachment1 = a, b
	t.Color = ColorSequence.new(from, to)
	t.Transparency = NumberSequence.new(0.25, 1)
	t.LightEmission = 1
	t.Lifetime = 0.2
	t.MinLength = 0.05
	t.FaceCamera = true
	t.Parent = tip
end

-- A blade tapering to a point toward -Z: two wedges back to back.
local function spike(
	add: Add,
	at: CFrame,
	width: number,
	height: number,
	length: number,
	color: Color3,
	material: Enum.Material?,
	o: { [string]: any }?
): BasePart
	local opts = table.clone(o or {})
	opts.Wedge = true
	local top = add(at * CFrame.new(0, height / 4, 0), Vector3.new(width, height / 2, length), color, material, opts)
	add(
		at * CFrame.new(0, -height / 4, 0) * CFrame.Angles(0, 0, math.pi),
		Vector3.new(width, height / 2, length),
		color,
		material,
		opts
	)
	return top
end

-- The looks --------------------------------------------------------------------------------------

local LOOKS = {}

-- No skin: the pick you hold, in its tier's colour (glowing past Survey).
local function standard(add: Add, color: Color3, bright: boolean?): BasePart
	add(CFrame.new(0, 0.9, 0), Vector3.new(0.22, 2.6, 0.22), Color3.fromRGB(60, 56, 54), Enum.Material.Wood)
	add(CFrame.new(0, 2.1, 0), Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(40, 42, 50), Enum.Material.Metal)
	local blade = add(CFrame.new(0, 2.2, -0.55), Vector3.new(0.26, 0.3, 1.2), color, Enum.Material.Metal)
	local tip = add(
		CFrame.new(0, 2.05, -1.25) * CFrame.Angles(math.rad(-25), 0, 0),
		Vector3.new(0.2, 0.22, 0.5),
		color,
		Enum.Material.Metal
	)
	add(CFrame.new(0, 2.2, 0.4), Vector3.new(0.24, 0.26, 0.6), color, Enum.Material.Metal)
	if bright then
		local edge = add(CFrame.new(0, 2.2, -0.55), Vector3.new(0.3, 0.12, 1.0), color, Enum.Material.Neon)
		glow(edge, color, 1.5, 8)
	end
	return tip or blade
end

-- Magma Heart: basalt cracked open on a river of lava; it smoulders and burns.
LOOKS.PickMagma = {
	Impact = "Magma",
	Color = Color3.fromRGB(255, 110, 20),
	Build = function(add: Add): BasePart
		local BASALT, DARK = Color3.fromRGB(46, 36, 34), Color3.fromRGB(24, 18, 18)
		local LAVA, HOT = Color3.fromRGB(255, 96, 16), Color3.fromRGB(255, 200, 90)
		-- An eight-sided basalt haft, veins of lava climbing it.
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.24, 2.5, 0.24), BASALT, Enum.Material.Basalt)
		add(
			CFrame.new(0, 1.05, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(0.24, 2.5, 0.24),
			BASALT,
			Enum.Material.Basalt
		)
		for i, y in { 0.75, 1.3, 1.85 } do
			add(
				CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(i * 30), math.rad(12)),
				Vector3.new(0.3, 0.06, 0.3),
				LAVA,
				Enum.Material.Neon
			)
		end
		add(CFrame.new(0, 0.25, 0), Vector3.new(0.3, 0.55, 0.3), DARK, Enum.Material.Fabric)
		local pommel = add(
			CFrame.new(0, -0.12, 0),
			Vector3.new(0.4, 0.4, 0.4),
			BASALT,
			Enum.Material.Basalt,
			{ Shape = Enum.PartType.Ball }
		)
		add(
			CFrame.new(0, -0.12, 0),
			Vector3.new(0.24, 0.24, 0.24),
			LAVA,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
		-- The head: a basalt block with lava pouring through its core.
		local head = add(CFrame.new(0, 2.45, 0), Vector3.new(0.62, 0.56, 0.62), BASALT, Enum.Material.Basalt)
		add(CFrame.new(0, 2.45, 0), Vector3.new(0.68, 0.36, 0.68), LAVA, Enum.Material.CrackedLava)
		add(CFrame.new(0, 2.45, 0), Vector3.new(0.5, 0.62, 0.5), LAVA, Enum.Material.Neon, { Transparency = 0.2 })
		-- Volcanic horns crowning it.
		for side = -1, 1, 2 do
			spike(
				add,
				CFrame.new(side * 0.22, 2.85, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(side * 18)),
				0.14,
				0.2,
				0.42,
				BASALT,
				Enum.Material.Basalt
			)
		end
		-- The spike, three segments curving down to a white-hot point.
		add(
			CFrame.new(0, 2.47, -0.62) * CFrame.Angles(math.rad(-6), 0, 0),
			Vector3.new(0.38, 0.4, 0.66),
			BASALT,
			Enum.Material.Basalt
		)
		add(
			CFrame.new(0, 2.4, -1.12) * CFrame.Angles(math.rad(-16), 0, 0),
			Vector3.new(0.3, 0.3, 0.56),
			Color3.fromRGB(80, 40, 30),
			Enum.Material.CrackedLava
		)
		local tip = spike(
			add,
			CFrame.new(0, 2.26, -1.6) * CFrame.Angles(math.rad(-26), 0, 0),
			0.24,
			0.24,
			0.62,
			LAVA,
			Enum.Material.Neon
		)
		add(
			CFrame.new(0, 2.68, -0.9) * CFrame.Angles(math.rad(-10), 0, 0),
			Vector3.new(0.08, 0.06, 1.3),
			HOT,
			Enum.Material.Neon
		)
		-- The back: a blunt hammer with a molten face.
		add(CFrame.new(0, 2.45, 0.55), Vector3.new(0.52, 0.5, 0.5), BASALT, Enum.Material.Basalt)
		add(CFrame.new(0, 2.45, 0.82), Vector3.new(0.48, 0.46, 0.06), LAVA, Enum.Material.Neon)
		emitter(
			head,
			LAVA,
			26,
			{
				Texture = FIRE,
				From = HOT,
				Size = 0.55,
				Speed = 0.5,
				Life = 0.45,
				Acceleration = Vector3.new(0, 5, 0),
				Spread = 25,
			}
		)
		emitter(head, HOT, 10, { Size = 0.12, Speed = 1.2, Life = 0.9, Acceleration = Vector3.new(0, 3, 0) })
		emitter(
			pommel,
			LAVA,
			6,
			{ Texture = FIRE, Size = 0.3, Speed = 0.3, Life = 0.35, Acceleration = Vector3.new(0, 4, 0), Spread = 20 }
		)
		glow(head, LAVA, 2.5, 12)
		trail(tip, Vector3.new(0, 0, 0.62), HOT, LAVA)
		return tip
	end,
}

-- Glacier Fang: a jagged icicle the length of your arm, steaming cold.
LOOKS.PickGlacier = {
	Impact = "Frost",
	Color = Color3.fromRGB(150, 225, 255),
	Build = function(add: Add): BasePart
		local ICE, DEEP = Color3.fromRGB(214, 242, 255), Color3.fromRGB(110, 190, 255)
		local STEEL, WRAP = Color3.fromRGB(170, 190, 210), Color3.fromRGB(235, 240, 245)
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.22, 2.5, 0.22), STEEL, Enum.Material.Metal, { Reflectance = 0.2 })
		for _, y in { 0.15, 0.35, 0.55, 2.0 } do
			add(
				CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(8)),
				Vector3.new(0.28, 0.12, 0.28),
				WRAP,
				Enum.Material.Fabric
			)
		end
		local pommel = add(
			CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.new(0.3, 0.3, 0.3),
			ICE,
			Enum.Material.Ice,
			{ Transparency = 0.15 }
		)
		-- The head: a block of ice turned on its corner, shards bursting out.
		local head = add(
			CFrame.new(0, 2.45, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(0.55, 0.6, 0.55),
			ICE,
			Enum.Material.Ice,
			{ Transparency = 0.1 }
		)
		add(CFrame.new(0, 2.45, 0), Vector3.new(0.22, 0.66, 0.22), WHITE, Enum.Material.Neon, { Transparency = 0.35 })
		for i, a in { 30, 100, 160, 230, 300 } do
			local r = math.rad(a)
			spike(
				add,
				CFrame.new(math.cos(r) * 0.26, 2.55 + (i % 2) * 0.1, math.sin(r) * 0.26)
					* CFrame.Angles(0, -r - math.pi / 2, 0)
					* CFrame.Angles(math.rad(25), 0, 0),
				0.12,
				0.14,
				0.42,
				if i % 2 == 0 then DEEP else ICE,
				Enum.Material.Ice,
				{ Transparency = 0.1 }
			)
		end
		-- The fang: a long icicle, then its point.
		spike(
			add,
			CFrame.new(0, 2.44, -0.85) * CFrame.Angles(math.rad(-8), 0, 0),
			0.34,
			0.42,
			1.1,
			ICE,
			Enum.Material.Ice,
			{ Transparency = 0.12 }
		)
		local tip = spike(
			add,
			CFrame.new(0, 2.3, -1.55) * CFrame.Angles(math.rad(-20), 0, 0),
			0.2,
			0.24,
			0.7,
			DEEP,
			Enum.Material.Glass,
			{ Transparency = 0.1, Reflectance = 0.3 }
		)
		add(
			CFrame.new(0, 2.5, -0.95) * CFrame.Angles(math.rad(-10), 0, 0),
			Vector3.new(0.06, 0.06, 1.3),
			WHITE,
			Enum.Material.Neon,
			{ Transparency = 0.2 }
		)
		-- A shorter fang behind.
		spike(
			add,
			CFrame.new(0, 2.45, 0.55) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-12), 0, 0),
			0.26,
			0.3,
			0.6,
			DEEP,
			Enum.Material.Ice,
			{ Transparency = 0.12 }
		)
		emitter(
			head,
			WHITE,
			12,
			{ Size = 0.14, Speed = 0.4, Life = 1.2, Acceleration = Vector3.new(0, -1.5, 0), Light = 0.6 }
		)
		emitter(
			head,
			DEEP,
			8,
			{
				Texture = SMOKE,
				Size = 0.5,
				EndSize = 1,
				Speed = 0.3,
				Life = 1,
				Light = 0.2,
				Alpha = 0.7,
				Acceleration = Vector3.new(0, -0.6, 0),
			}
		)
		emitter(pommel, ICE, 4, { Size = 0.1, Speed = 0.3, Life = 0.8 })
		glow(head, DEEP, 1.8, 10)
		trail(tip, Vector3.new(0, 0, 0.7), WHITE, DEEP)
		return tip
	end,
}

-- Stormbreaker: a thunder hammer-pick; tesla prongs, a crackling orb.
LOOKS.PickStorm = {
	Impact = "Storm",
	Color = Color3.fromRGB(255, 230, 90),
	Build = function(add: Add): BasePart
		local STEEL, GOLD = Color3.fromRGB(56, 60, 76), Color3.fromRGB(255, 196, 70)
		local COPPER, VOLT, ARC =
			Color3.fromRGB(196, 110, 60), Color3.fromRGB(255, 240, 120), Color3.fromRGB(150, 225, 255)
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.23, 2.5, 0.23), STEEL, Enum.Material.DiamondPlate)
		for _, y in { 0.1, 0.6, 1.5 } do
			add(CFrame.new(0, y, 0), Vector3.new(0.3, 0.1, 0.3), GOLD, Enum.Material.Metal, { Reflectance = 0.25 })
		end
		-- A copper coil wound under the head.
		for i = 0, 5 do
			add(
				CFrame.new(0, 1.8 + i * 0.07, 0) * CFrame.Angles(0, 0, math.rad(6)),
				Vector3.new(0.32, 0.04, 0.32),
				COPPER,
				Enum.Material.Metal
			)
		end
		add(CFrame.new(0, -0.1, 0), Vector3.new(0.34, 0.24, 0.34), GOLD, Enum.Material.Metal, { Reflectance = 0.25 })
		-- The head: a heavy block, lightning inlaid down both sides.
		local head = add(CFrame.new(0, 2.45, 0.05), Vector3.new(0.6, 0.6, 0.8), STEEL, Enum.Material.Metal)
		for side = -1, 1, 2 do
			for n, seg in { { 0.12, 0.1, 30 }, { -0.04, -0.06, -30 }, { 0.1, -0.2, 30 } } do
				add(
					CFrame.new(side * 0.31, 2.45 + seg[2], seg[1]) * CFrame.Angles(math.rad(seg[3]), 0, 0),
					Vector3.new(0.03, 0.06, 0.24),
					if n % 2 == 0 then ARC else VOLT,
					Enum.Material.Neon
				)
			end
		end
		-- The spike: gold, long and sharp.
		add(CFrame.new(0, 2.46, -0.58), Vector3.new(0.34, 0.36, 0.5), GOLD, Enum.Material.Metal, { Reflectance = 0.3 })
		local tip = spike(
			add,
			CFrame.new(0, 2.38, -1.15) * CFrame.Angles(math.rad(-14), 0, 0),
			0.28,
			0.32,
			0.8,
			GOLD,
			Enum.Material.Metal,
			{ Reflectance = 0.3 }
		)
		add(
			CFrame.new(0, 2.62, -0.85) * CFrame.Angles(math.rad(-8), 0, 0),
			Vector3.new(0.06, 0.05, 0.9),
			VOLT,
			Enum.Material.Neon
		)
		-- The hammer, and two tesla prongs rising off it.
		add(CFrame.new(0, 2.45, 0.62), Vector3.new(0.62, 0.62, 0.3), STEEL, Enum.Material.Metal)
		add(CFrame.new(0, 2.45, 0.8), Vector3.new(0.56, 0.56, 0.06), GOLD, Enum.Material.Metal, { Reflectance = 0.3 })
		for side = -1, 1, 2 do
			add(
				CFrame.new(side * 0.2, 2.95, 0.58) * UPRIGHT,
				Vector3.new(0.5, 0.08, 0.08),
				COPPER,
				Enum.Material.Metal,
				{ Shape = Enum.PartType.Cylinder }
			)
			add(
				CFrame.new(side * 0.2, 3.22, 0.58),
				Vector3.new(0.14, 0.14, 0.14),
				VOLT,
				Enum.Material.Neon,
				{ Shape = Enum.PartType.Ball }
			)
		end
		-- The orb on top, sparks spitting off it.
		local orb = add(
			CFrame.new(0, 2.92, 0),
			Vector3.new(0.36, 0.36, 0.36),
			WHITE,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
		add(
			CFrame.new(0, 2.92, 0),
			Vector3.new(0.5, 0.5, 0.5),
			ARC,
			Enum.Material.ForceField,
			{ Shape = Enum.PartType.Ball }
		)
		emitter(orb, VOLT, 30, { Size = 0.16, Speed = 4, Life = 0.15, Acceleration = Vector3.zero })
		emitter(head, ARC, 8, { Size = 0.1, Speed = 2, Life = 0.25, Acceleration = Vector3.zero })
		glow(orb, VOLT, 3, 12)
		trail(tip, Vector3.new(0, 0, 0.8), WHITE, ARC)
		return tip
	end,
}

-- Void Reaper: a scythe of night-glass on a black haft, runes circling it.
LOOKS.PickVoid = {
	Impact = "Void",
	Color = Color3.fromRGB(170, 90, 255),
	Build = function(add: Add): BasePart
		local BLACK, NIGHT = Color3.fromRGB(18, 14, 26), Color3.fromRGB(60, 30, 100)
		local VIOLET, PALE = Color3.fromRGB(170, 90, 255), Color3.fromRGB(230, 200, 255)
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.21, 2.6, 0.21), BLACK, Enum.Material.Glass, { Reflectance = 0.15 })
		-- A violet spiral up the haft.
		for i = 0, 9 do
			local a = i * 0.9
			add(
				CFrame.new(math.cos(a) * 0.12, 0.2 + i * 0.2, math.sin(a) * 0.12) * CFrame.Angles(0, -a, math.rad(35)),
				Vector3.new(0.05, 0.16, 0.05),
				VIOLET,
				Enum.Material.Neon
			)
		end
		local pommel = add(
			CFrame.new(0, -0.18, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.new(0.3, 0.3, 0.3),
			NIGHT,
			Enum.Material.Glass
		)
		-- Runes circling the top of the haft.
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			add(
				CFrame.new(math.cos(a) * 0.42, 1.95, math.sin(a) * 0.42) * CFrame.Angles(0, -a, 0),
				Vector3.new(0.04, 0.16, 0.08),
				VIOLET,
				Enum.Material.Neon
			)
		end
		-- The head: a black core with a violet eye.
		local head =
			add(CFrame.new(0, 2.5, 0), Vector3.new(0.46, 0.5, 0.5), BLACK, Enum.Material.Glass, { Reflectance = 0.2 })
		add(
			CFrame.new(0, 2.52, -0.02),
			Vector3.new(0.5, 0.2, 0.2),
			VIOLET,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
		-- The scythe blade: arcing forward and down, its edge glowing.
		local at = CFrame.new(0, 2.56, -0.2)
		for _, size in { 0.42, 0.38, 0.33, 0.27, 0.2, 0.13 } do
			at = at * CFrame.new(0, 0, -0.32) * CFrame.Angles(math.rad(-11), 0, 0)
			add(
				at,
				Vector3.new(0.07, size, 0.36),
				NIGHT,
				Enum.Material.Glass,
				{ Transparency = 0.05, Reflectance = 0.3 }
			)
			add(at * CFrame.new(0, -size / 2, 0), Vector3.new(0.08, 0.05, 0.37), VIOLET, Enum.Material.Neon)
		end
		local tip = spike(
			add,
			at * CFrame.new(0, -0.02, -0.3) * CFrame.Angles(math.rad(-12), 0, 0),
			0.07,
			0.12,
			0.34,
			PALE,
			Enum.Material.Neon
		)
		-- A hook behind.
		spike(
			add,
			CFrame.new(0, 2.52, 0.42) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-30), 0, 0),
			0.1,
			0.22,
			0.42,
			NIGHT,
			Enum.Material.Glass
		)
		emitter(
			head,
			NIGHT,
			14,
			{
				Texture = SMOKE,
				Size = 0.4,
				EndSize = 0.9,
				Speed = 0.4,
				Life = 1,
				Light = 0,
				Alpha = 0.4,
				Acceleration = Vector3.new(0, 0.8, 0),
			}
		)
		emitter(head, VIOLET, 10, { Size = 0.12, Speed = 0.8, Life = 0.8 })
		emitter(pommel, VIOLET, 4, { Size = 0.1, Speed = 0.3, Life = 0.6 })
		glow(head, VIOLET, 2.2, 11)
		trail(tip, Vector3.new(0, 0, 0.34), PALE, VIOLET)
		return tip
	end,
}

-- Gilded Prospector: polished gold, rubies set in the head, a show-off's pick.
LOOKS.PickGilded = {
	Impact = "Gold",
	Color = Color3.fromRGB(255, 200, 80),
	Build = function(add: Add): BasePart
		local GOLD, DEEP = Color3.fromRGB(255, 196, 70), Color3.fromRGB(200, 130, 30)
		local WOOD, RUBY, EMERALD =
			Color3.fromRGB(96, 52, 30), Color3.fromRGB(230, 30, 60), Color3.fromRGB(40, 220, 120)
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.22, 2.5, 0.22), WOOD, Enum.Material.Wood)
		for _, y in { 0.05, 0.5, 1.9, 2.15 } do
			add(CFrame.new(0, y, 0), Vector3.new(0.29, 0.1, 0.29), GOLD, Enum.Material.Foil, { Reflectance = 0.3 })
		end
		local pommel = add(
			CFrame.new(0, -0.15, 0),
			Vector3.new(0.36, 0.36, 0.36),
			GOLD,
			Enum.Material.Foil,
			{ Shape = Enum.PartType.Ball, Reflectance = 0.3 }
		)
		local head =
			add(CFrame.new(0, 2.45, 0), Vector3.new(0.56, 0.52, 0.56), GOLD, Enum.Material.Foil, { Reflectance = 0.35 })
		add(CFrame.new(0, 2.45, 0), Vector3.new(0.62, 0.12, 0.62), DEEP, Enum.Material.Metal)
		-- A ruby on each side, an emerald on top.
		for side = -1, 1, 2 do
			add(
				CFrame.new(side * 0.3, 2.47, 0) * CFrame.Angles(math.rad(45), 0, 0),
				Vector3.new(0.08, 0.24, 0.24),
				RUBY,
				Enum.Material.Glass,
				{ Reflectance = 0.4 }
			)
		end
		add(
			CFrame.new(0, 2.74, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(0.2, 0.1, 0.2),
			EMERALD,
			Enum.Material.Glass,
			{ Reflectance = 0.4 }
		)
		-- An elegant curved spike, and a fluted hammer.
		add(
			CFrame.new(0, 2.47, -0.6) * CFrame.Angles(math.rad(-6), 0, 0),
			Vector3.new(0.3, 0.34, 0.66),
			GOLD,
			Enum.Material.Foil,
			{ Reflectance = 0.35 }
		)
		local tip = spike(
			add,
			CFrame.new(0, 2.33, -1.2) * CFrame.Angles(math.rad(-20), 0, 0),
			0.24,
			0.28,
			0.7,
			GOLD,
			Enum.Material.Foil,
			{ Reflectance = 0.35 }
		)
		add(CFrame.new(0, 2.45, 0.52), Vector3.new(0.44, 0.44, 0.44), GOLD, Enum.Material.Foil, { Reflectance = 0.35 })
		add(CFrame.new(0, 2.45, 0.76), Vector3.new(0.5, 0.5, 0.05), DEEP, Enum.Material.Metal)
		emitter(head, GOLD, 10, { Size = 0.16, Speed = 0.4, Life = 0.9, Acceleration = Vector3.new(0, 0.5, 0) })
		emitter(pommel, GOLD, 3, { Size = 0.12, Speed = 0.3, Life = 0.6 })
		glow(head, GOLD, 1.4, 9)
		trail(tip, Vector3.new(0, 0, 0.7), WHITE, GOLD)
		return tip
	end,
}

-- Prism Shard: a diamond pick that throws every colour (its crystal cycles
-- through the rainbow on every client: Prismatic).
LOOKS.PickPrism = {
	Impact = "Prism",
	Color = Color3.fromRGB(200, 170, 255),
	Build = function(add: Add): BasePart
		local PEARL, SILVER = Color3.fromRGB(240, 238, 248), Color3.fromRGB(200, 205, 220)
		local function prismatic(p: BasePart)
			p:SetAttribute("PrismaticBase", Color3.fromHSV(math.random(), 0.65, 1))
			CollectionService:AddTag(p, Tags.Prismatic)
			return p
		end
		add(
			CFrame.new(0, 1.05, 0),
			Vector3.new(0.21, 2.5, 0.21),
			PEARL,
			Enum.Material.SmoothPlastic,
			{ Reflectance = 0.2 }
		)
		for _, y in { 0.2, 1.2, 2.1 } do
			prismatic(add(CFrame.new(0, y, 0), Vector3.new(0.28, 0.07, 0.28), SILVER, Enum.Material.Neon))
		end
		local pommel = prismatic(
			add(
				CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Vector3.new(0.28, 0.28, 0.28),
				Color3.fromRGB(200, 170, 255),
				Enum.Material.Glass,
				{ Reflectance = 0.4 }
			)
		)
		-- The head: a cut diamond, two cubes turned on their corners.
		local head = prismatic(
			add(
				CFrame.new(0, 2.48, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
				Vector3.new(0.5, 0.5, 0.5),
				Color3.fromRGB(190, 220, 255),
				Enum.Material.Glass,
				{ Reflectance = 0.4, Transparency = 0.05 }
			)
		)
		prismatic(
			add(
				CFrame.new(0, 2.48, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
				Vector3.new(0.36, 0.36, 0.36),
				WHITE,
				Enum.Material.Neon,
				{ Transparency = 0.25 }
			)
		)
		-- Three small diamonds hanging round the head.
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2 + 0.4
			prismatic(
				add(
					CFrame.new(math.cos(a) * 0.48, 2.5 + math.sin(a * 2) * 0.12, math.sin(a) * 0.48)
						* CFrame.Angles(math.rad(45), a, math.rad(45)),
					Vector3.new(0.13, 0.13, 0.13),
					WHITE,
					Enum.Material.Glass,
					{ Reflectance = 0.4 }
				)
			)
		end
		-- A long crystal spike, faceted, and a short one behind.
		local tip = spike(
			add,
			CFrame.new(0, 2.42, -0.95) * CFrame.Angles(math.rad(-12), 0, 0),
			0.3,
			0.36,
			1.35,
			Color3.fromRGB(255, 190, 240),
			Enum.Material.Glass,
			{ Reflectance = 0.4, Transparency = 0.05 }
		)
		prismatic(tip)
		add(
			CFrame.new(0, 2.56, -0.85) * CFrame.Angles(math.rad(-12), 0, 0),
			Vector3.new(0.05, 0.05, 1.1),
			WHITE,
			Enum.Material.Neon,
			{ Transparency = 0.2 }
		)
		prismatic(
			spike(
				add,
				CFrame.new(0, 2.48, 0.5) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(-10), 0, 0),
				0.26,
				0.3,
				0.55,
				Color3.fromRGB(190, 255, 220),
				Enum.Material.Glass,
				{ Reflectance = 0.4 }
			)
		)
		emitter(head, WHITE, 14, { Size = 0.14, Speed = 0.5, Life = 0.7 })
		emitter(pommel, WHITE, 4, { Size = 0.1, Speed = 0.3, Life = 0.6 })
		glow(head, Color3.fromRGB(220, 200, 255), 1.6, 9)
		trail(tip, Vector3.new(0, 0, 1.35), WHITE, Color3.fromRGB(200, 150, 255))
		return tip
	end,
}

-- Neon Runner: matte black, cut with hot pink and cyan light.
LOOKS.PickNeon = {
	Impact = "Neon",
	Color = Color3.fromRGB(255, 70, 200),
	Build = function(add: Add): BasePart
		local BLACK, PINK, CYAN = Color3.fromRGB(16, 16, 22), Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 240, 255)
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.22, 2.5, 0.22), BLACK, Enum.Material.SmoothPlastic)
		for side = -1, 1, 2 do
			add(CFrame.new(side * 0.115, 1.05, 0), Vector3.new(0.02, 2.3, 0.06), PINK, Enum.Material.Neon)
		end
		add(CFrame.new(0, -0.08, 0), Vector3.new(0.3, 0.2, 0.3), BLACK, Enum.Material.SmoothPlastic)
		local pommel = add(CFrame.new(0, -0.08, 0), Vector3.new(0.32, 0.05, 0.32), CYAN, Enum.Material.Neon)
		-- An angular head with glowing edges.
		local head = add(CFrame.new(0, 2.45, 0), Vector3.new(0.5, 0.5, 0.7), BLACK, Enum.Material.SmoothPlastic)
		for _, y in { -0.26, 0.26 } do
			for _, x in { -0.26, 0.26 } do
				add(CFrame.new(x, 2.45 + y, 0), Vector3.new(0.04, 0.04, 0.72), CYAN, Enum.Material.Neon)
			end
		end
		add(CFrame.new(0, 2.45, 0), Vector3.new(0.52, 0.1, 0.1), PINK, Enum.Material.Neon)
		-- The spike: a black blade with a pink edge, cut square.
		add(CFrame.new(0, 2.45, -0.62), Vector3.new(0.3, 0.32, 0.5), BLACK, Enum.Material.SmoothPlastic)
		local tip = spike(
			add,
			CFrame.new(0, 2.38, -1.15) * CFrame.Angles(math.rad(-12), 0, 0),
			0.24,
			0.3,
			0.75,
			BLACK,
			Enum.Material.SmoothPlastic
		)
		add(
			CFrame.new(0, 2.25, -1.0) * CFrame.Angles(math.rad(-14), 0, 0),
			Vector3.new(0.05, 0.05, 1.1),
			PINK,
			Enum.Material.Neon
		)
		add(
			CFrame.new(0, 2.62, -0.8) * CFrame.Angles(math.rad(-6), 0, 0),
			Vector3.new(0.05, 0.05, 0.8),
			CYAN,
			Enum.Material.Neon
		)
		-- An exhaust out the back, glowing.
		add(
			CFrame.new(0, 2.45, 0.52) * FORWARD,
			Vector3.new(0.36, 0.34, 0.34),
			BLACK,
			Enum.Material.Metal,
			{ Shape = Enum.PartType.Cylinder }
		)
		add(
			CFrame.new(0, 2.45, 0.71) * FORWARD,
			Vector3.new(0.04, 0.28, 0.28),
			CYAN,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Cylinder }
		)
		emitter(head, PINK, 8, { Size = 0.1, Speed = 0.6, Life = 0.5 })
		emitter(pommel, CYAN, 4, { Size = 0.08, Speed = 0.4, Life = 0.4 })
		glow(head, PINK, 1.8, 9)
		trail(tip, Vector3.new(0, 0, 0.75), CYAN, PINK)
		return tip
	end,
}

-- Bone Crusher: a monster's tusk lashed to a spine, a skull for a hammer.
LOOKS.PickBone = {
	Impact = "Bone",
	Color = Color3.fromRGB(240, 228, 200),
	Build = function(add: Add): BasePart
		local BONE, OLD = Color3.fromRGB(236, 226, 200), Color3.fromRGB(196, 180, 150)
		local LEATHER, SOCKET = Color3.fromRGB(110, 70, 40), Color3.fromRGB(30, 22, 18)
		-- A spine: vertebrae with knuckles between.
		for i = 0, 6 do
			add(
				CFrame.new(0, 0.05 + i * 0.36, 0),
				Vector3.new(0.24, 0.28, 0.24),
				if i % 2 == 0 then BONE else OLD,
				Enum.Material.Sandstone
			)
			add(
				CFrame.new(0, 0.23 + i * 0.36, 0),
				Vector3.new(0.3, 0.1, 0.3),
				OLD,
				Enum.Material.Sandstone,
				{ Shape = Enum.PartType.Ball }
			)
		end
		add(CFrame.new(0, 2.15, 0), Vector3.new(0.34, 0.22, 0.34), LEATHER, Enum.Material.Fabric)
		-- The skull, facing back.
		local skull = add(
			CFrame.new(0, 2.5, 0.35),
			Vector3.new(0.62, 0.62, 0.62),
			BONE,
			Enum.Material.Sandstone,
			{ Shape = Enum.PartType.Ball }
		)
		add(CFrame.new(0, 2.32, 0.55), Vector3.new(0.4, 0.2, 0.3), OLD, Enum.Material.Sandstone)
		for side = -1, 1, 2 do
			add(
				CFrame.new(side * 0.13, 2.56, 0.62),
				Vector3.new(0.14, 0.14, 0.1),
				SOCKET,
				Enum.Material.SmoothPlastic,
				{ Shape = Enum.PartType.Ball }
			)
		end
		-- The tusk: curving forward to a point, lashed on with leather.
		add(CFrame.new(0, 2.48, -0.3), Vector3.new(0.4, 0.38, 0.5), BONE, Enum.Material.Sandstone)
		add(CFrame.new(0, 2.48, -0.2), Vector3.new(0.46, 0.44, 0.1), LEATHER, Enum.Material.Fabric)
		add(
			CFrame.new(0, 2.42, -0.78) * CFrame.Angles(math.rad(-14), 0, 0),
			Vector3.new(0.32, 0.32, 0.6),
			BONE,
			Enum.Material.Sandstone
		)
		local tip = spike(
			add,
			CFrame.new(0, 2.24, -1.3) * CFrame.Angles(math.rad(-28), 0, 0),
			0.24,
			0.26,
			0.7,
			BONE,
			Enum.Material.Sandstone
		)
		emitter(
			skull,
			OLD,
			3,
			{ Texture = SMOKE, Size = 0.3, EndSize = 0.6, Speed = 0.2, Life = 1, Light = 0, Alpha = 0.6 }
		)
		trail(tip, Vector3.new(0, 0, 0.7), BONE, OLD)
		return tip
	end,
}

-- Amethyst Geode: a rough rock knocked open, violet crystal glowing out of
-- its splits, and a whole cluster of amethyst bursting out as the spike.
LOOKS.PickGeode = {
	Impact = "Geode",
	Color = Color3.fromRGB(190, 110, 255),
	Build = function(add: Add): BasePart
		local ROCK, DARK = Color3.fromRGB(110, 104, 112), Color3.fromRGB(70, 66, 74)
		local AMETHYST, DEEP, PALE =
			Color3.fromRGB(196, 130, 255), Color3.fromRGB(120, 50, 200), Color3.fromRGB(240, 210, 255)
		local CRYSTAL = { Transparency = 0.08, Reflectance = 0.3 }
		add(CFrame.new(0, 1.05, 0), Vector3.new(0.24, 2.5, 0.24), ROCK, Enum.Material.Slate)
		add(CFrame.new(0, 0.3, 0), Vector3.new(0.3, 0.5, 0.3), DARK, Enum.Material.Fabric)
		local pommel = add(
			CFrame.new(0, -0.18, 0) * CFrame.Angles(math.rad(20), 0, math.rad(15)),
			Vector3.new(0.2, 0.42, 0.2),
			AMETHYST,
			Enum.Material.Glass,
			CRYSTAL
		)
		-- The geode: three rough chunks knocked together.
		local head = add(CFrame.new(0, 2.45, 0.05), Vector3.new(0.62, 0.58, 0.66), ROCK, Enum.Material.Slate)
		add(
			CFrame.new(0.04, 2.62, 0.18) * CFrame.Angles(0.3, 0.4, 0.2),
			Vector3.new(0.5, 0.42, 0.5),
			DARK,
			Enum.Material.Slate
		)
		add(
			CFrame.new(-0.05, 2.3, -0.06) * CFrame.Angles(-0.25, -0.3, 0.15),
			Vector3.new(0.52, 0.4, 0.52),
			ROCK,
			Enum.Material.Slate
		)
		-- Split open down both sides, crystal points poking out of the cracks.
		for side = -1, 1, 2 do
			add(
				CFrame.new(side * 0.32, 2.47, 0.04),
				Vector3.new(0.04, 0.42, 0.5),
				DEEP,
				Enum.Material.Neon,
				{ Transparency = 0.1 }
			)
			for i = 1, 3 do
				local at = CFrame.new(side * 0.34, 2.32 + i * 0.09, -0.1 + i * 0.1)
					* CFrame.Angles(0, -side * math.pi / 2, 0)
				spike(
					add,
					at * CFrame.Angles(math.rad(i * 12 - 20), 0, 0) * CFrame.new(0, 0, -0.1),
					0.08,
					0.1,
					0.22,
					if i == 2 then PALE else AMETHYST,
					Enum.Material.Glass,
					CRYSTAL
				)
			end
		end
		-- The front face is all crystal: a cluster bursting out, fanned wide.
		add(
			CFrame.new(0, 2.45, -0.29),
			Vector3.new(0.52, 0.48, 0.06),
			DEEP,
			Enum.Material.Neon,
			{ Transparency = 0.25 }
		)
		local tip = nil
		for i, c in
			{
				{ 0, 0, 1.05, 0.26, -6, 0 },
				{ 0.15, 0.13, 0.62, 0.18, 24, -26 },
				{ -0.15, 0.11, 0.58, 0.17, 20, 28 },
				{ 0.12, -0.14, 0.52, 0.16, -22, -20 },
				{ -0.13, -0.12, 0.5, 0.15, -18, 24 },
				{ 0.02, 0.21, 0.44, 0.14, 40, -6 },
				{ -0.02, -0.2, 0.4, 0.13, -38, 8 },
			}
		do
			local at = CFrame.new(c[1], 2.45 + c[2], -0.32)
				* CFrame.Angles(math.rad(c[5]), math.rad(c[6]), 0)
				* CFrame.new(0, 0, -c[3] / 2)
			local crystal = spike(
				add,
				at,
				c[4],
				c[4] * 1.2,
				c[3],
				if i % 2 == 1 then AMETHYST else DEEP,
				Enum.Material.Glass,
				CRYSTAL
			)
			if i == 1 then
				tip = crystal
				-- Its glowing heart.
				add(
					at * CFrame.new(0, 0, 0.1),
					Vector3.new(c[4] * 0.3, c[4] * 0.3, c[3] * 0.75),
					PALE,
					Enum.Material.Neon,
					{ Transparency = 0.2 }
				)
			end
		end
		-- Rock hammer behind.
		add(CFrame.new(0, 2.45, 0.55), Vector3.new(0.5, 0.5, 0.44), DARK, Enum.Material.Slate)
		emitter(head, AMETHYST, 10, { Size = 0.12, Speed = 0.5, Life = 0.8 })
		emitter(pommel, AMETHYST, 3, { Size = 0.08, Speed = 0.3, Life = 0.6 })
		glow(head, AMETHYST, 1.8, 9)
		trail(tip :: BasePart, Vector3.new(0, 0, 1.05), PALE, DEEP)
		return tip :: BasePart
	end,
}

PickaxeLooks.Looks = LOOKS

-- Builds a pickaxe into `parent` (see the top). `skinId` nil or unknown:
-- the standard pick in `tierColor`, glowing if `bright`.
function PickaxeLooks.build(
	parent: Instance,
	frame: CFrame,
	skinId: string?,
	tierColor: Color3?,
	weldTo: BasePart?,
	bright: boolean?
): ({ BasePart }, BasePart?)
	local parts: { BasePart } = {}
	local function add(
		at: CFrame,
		size: Vector3,
		color: Color3,
		material: Enum.Material?,
		o: { [string]: any }?
	): BasePart
		local opts = o or {}
		local p = Instance.new(if opts.Wedge then "WedgePart" else "Part") :: BasePart
		p.Name = "Pick"
		p.Size, p.Color = size, color
		p.Material = material or Enum.Material.SmoothPlastic
		if opts.Shape and p:IsA("Part") then
			(p :: Part).Shape = opts.Shape
		end
		p.Transparency = opts.Transparency or 0
		p.Reflectance = opts.Reflectance or 0
		p.CFrame = frame * at
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
		if weldTo then
			p.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = weldTo, p
			weld.Parent = p
		else
			p.Anchored = true
		end
		p.Parent = parent
		table.insert(parts, p)
		return p
	end
	local look = skinId and LOOKS[skinId]
	local tip
	if look then
		tip = look.Build(add)
	else
		tip = standard(add, tierColor or Color3.fromRGB(176, 150, 120), bright)
	end
	if tip then
		tip.Name = "PickTip"
	end
	return parts, tip
end

return PickaxeLooks
