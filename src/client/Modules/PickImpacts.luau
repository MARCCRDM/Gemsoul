--[[
	PickImpacts: what a swing looks like where it lands, for a pickaxe skin
	(Shared.PickaxeLooks, each Look's Impact). OutpostScene plays one on
	every hit by a miner holding a skin; everyone at the Outpost sees it.

	  PickImpacts.play(kind, at, from, power, crit, scale?)
	      kind   "Magma", "Frost", "Storm", "Void", "Gold", "Prism",
	             "Neon", "Bone" or "Geode" (anything else: false)
	      at     the point on the rock that was hit
	      from   where the swing came from (bits fly back that way)
	      power  0-1, how close the rock is to breaking: bigger near the end
	      crit   a critical hit: the most of it
	      scale  under 1 for someone else's swing (fewer pieces)

	Client only; nothing replicates.
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CombatFx = require(script.Parent.CombatFx)
local CombatVfx = require(script.Parent.CombatVfx)

local PickImpacts = {}

local WHITE = Color3.new(1, 1, 1)

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "PickImpacts"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService
		:Create(
			object,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
			goal
		)
		:Play()
end

-- Facing from `at` toward `to` (straight up or down too).
local function aim(at: Vector3, to: Vector3): CFrame
	local d = to - at
	return CFrame.lookAt(at, to, if d.Magnitude > 0 and math.abs(d.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis)
end

-- A glowing (or solid) piece that only lives `life` seconds.
local function piece(
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	life: number,
	o: { [string]: any }?
): BasePart
	local opts = o or {}
	local p = Instance.new(if opts.Wedge then "WedgePart" else "Part") :: BasePart
	p.Name = "PickHit"
	if opts.Shape and p:IsA("Part") then
		(p :: Part).Shape = opts.Shape
	end
	p.Anchored = opts.Flies ~= true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = opts.Transparency or 0
	p.Parent = fxFolder()
	Debris:AddItem(p, life + 0.1)
	return p
end

-- Bits thrown off the rock (they fall, tumble and fade).
local function fling(at: Vector3, out: Vector3, count: number, speed: number, make: (number) -> BasePart, life: number)
	for i = 1, count do
		local p = make(i)
		local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.4
		local dir = (out + side + Vector3.new(0, 0.7 + math.random() * 0.7, 0)).Unit
		p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.AssemblyLinearVelocity = dir * speed * (0.6 + math.random() * 0.6)
		p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 24
		tween(p, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

-- A shockwave ring spreading over the rock's face (facing `out`): a hoop of
-- short glowing segments flying apart as it fades.
local SEGMENTS = 14
local function ring(
	at: Vector3,
	out: Vector3,
	color: Color3,
	from: number,
	to: number,
	seconds: number,
	material: Enum.Material?
)
	local face = aim(at, at + out)
	local function segment(i: number, r: number): CFrame
		return face * CFrame.Angles(0, 0, i / SEGMENTS * math.pi * 2) * CFrame.new(r, 0, 0)
	end
	local width = math.clamp(to * 0.035, 0.1, 0.3)
	for i = 1, SEGMENTS do
		local arc = math.pi * 2 / SEGMENTS * 1.15
		local bit = piece(
			segment(i, from),
			Vector3.new(width, from * arc, 0.08),
			color,
			material,
			seconds,
			{ Transparency = 0.1 }
		)
		tween(
			bit,
			seconds,
			{ CFrame = segment(i, to), Size = Vector3.new(width * 0.4, to * arc, 0.05), Transparency = 1 }
		)
	end
end

-- A ball of light that swells and fades.
local function bloom(at: Vector3, color: Color3, size: number, seconds: number, transparency: number?)
	local b = piece(CFrame.new(at), Vector3.one * size * 0.3, color, Enum.Material.Neon, seconds, {
		Shape = Enum.PartType.Ball,
		Transparency = transparency or 0.1,
	})
	tween(b, seconds, { Size = Vector3.one * size, Transparency = 1 })
	return b
end

-- A pointed crystal (two wedges back to back) snapping out of the rock
-- along `base`'s look, then shattering away.
local function shard(base: CFrame, width: number, len: number, color: Color3, material: Enum.Material, life: number)
	for half = -1, 1, 2 do
		local flip = if half < 0 then CFrame.Angles(0, 0, math.pi) else CFrame.identity
		local function at(l: number): CFrame
			return base * CFrame.new(0, half * width / 4, -l / 2) * flip
		end
		local w = piece(
			at(0.05),
			Vector3.new(width, width / 2, 0.05),
			color,
			material,
			life,
			{ Wedge = true, Transparency = 0.05 }
		)
		tween(w, 0.09, { Size = Vector3.new(width, width / 2, len), CFrame = at(len) }, Enum.EasingStyle.Back)
		task.delay(life * 0.45, function()
			tween(
				w,
				life * 0.5,
				{ Transparency = 1, Size = Vector3.new(width * 0.4, width * 0.2, len * 0.5), CFrame = at(len * 0.5) }
			)
		end)
	end
end

-- Crystals (or icicles) bursting out of the rock in a crown.
local function crystals(
	at: Vector3,
	out: Vector3,
	count: number,
	length: number,
	color: Color3,
	core: Color3,
	material: Enum.Material
)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.5
		local spread = CFrame.Angles(math.cos(a) * 0.9, math.sin(a) * 0.9, 0)
		local dir = (aim(Vector3.zero, out) * spread).LookVector
		local len = length * (0.6 + math.random() * 0.6)
		local base = aim(at, at + dir)
		shard(base, len * 0.3, len, if i % 3 == 0 then core else color, material, 0.55)
		if i % 2 == 0 then
			local glint = piece(
				base * CFrame.new(0, 0, -len * 0.35),
				Vector3.new(0.05, 0.05, len * 0.6),
				core,
				Enum.Material.Neon,
				0.3,
				{
					Transparency = 0.3,
				}
			)
			tween(glint, 0.3, { Transparency = 1 })
		end
	end
end

-- Thin streaks shooting out from the hit, shrinking as they go.
local function streaks(at: Vector3, out: Vector3, count: number, reach: number, colors: { Color3 }, seconds: number)
	for i = 1, count do
		local dir = (out + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 1.8).Unit
		local s = piece(
			aim(at, at + dir) * CFrame.new(0, 0, -0.4),
			Vector3.new(0.09, 0.09, 0.9),
			colors[(i - 1) % #colors + 1],
			Enum.Material.Neon,
			seconds
		)
		local go = reach * (0.6 + math.random() * 0.6)
		tween(
			s,
			seconds,
			{
				CFrame = aim(at + dir * go, at + dir * (go + 1)),
				Size = Vector3.new(0.03, 0.03, 0.2),
				Transparency = 0.6,
			}
		)
	end
end

local LOOKS = {}

-- Lava spatters out of the rock, a molten splash glows on it, fire rises.
function LOOKS.Magma(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local LAVA, HOT = Color3.fromRGB(255, 96, 16), Color3.fromRGB(255, 200, 90)
	bloom(at, LAVA, 3 * k, 0.3)
	CombatFx.burst(at, LAVA, "Embers", 0.6 * k)
	fling(at, out, math.ceil((5 + 5 * k) * scale), 18, function(i)
		local size = 0.25 + math.random() * 0.35
		return piece(CFrame.new(at), Vector3.one * size, if i % 3 == 0 then HOT else LAVA, Enum.Material.Neon, 0.9, {
			Shape = Enum.PartType.Ball,
			Flies = true,
		})
	end, 0.9)
	local splat = aim(at, at + out) * CFrame.Angles(0, math.pi / 2, 0)
	local pool = piece(
		splat,
		Vector3.new(0.1, 1.6 * k, 1.6 * k),
		LAVA,
		Enum.Material.Neon,
		1.3,
		{ Shape = Enum.PartType.Cylinder }
	)
	tween(
		pool,
		1.3,
		{ Transparency = 1, Color = Color3.fromRGB(90, 30, 20) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	if crit then
		ring(at, Vector3.yAxis, LAVA, 1, 8, 0.45)
		CombatFx.burst(at, HOT, "Embers", 1.2)
	end
end

-- Ice bursts out of the rock in a crown of shards; snow falls off it.
function LOOKS.Frost(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local ICE, DEEP = Color3.fromRGB(214, 242, 255), Color3.fromRGB(110, 190, 255)
	bloom(at, DEEP, 2.6 * k, 0.25, 0.3)
	crystals(at, out, math.ceil((5 + 3 * k) * scale), 1.2 + 1.1 * k, ICE, WHITE, Enum.Material.Ice)
	ring(at, out, WHITE, 0.6, 4 * k, 0.4, Enum.Material.Ice)
	CombatFx.burst(at, ICE, "Frost", 0.7 * k)
	if crit then
		crystals(at, Vector3.yAxis, 6, 2.4, DEEP, WHITE, Enum.Material.Glass)
		ring(at, Vector3.yAxis, ICE, 1, 10, 0.5, Enum.Material.Ice)
	end
end

-- Lightning cracks down out of the sky onto the pick's point.
function LOOKS.Storm(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local VOLT, ARC = Color3.fromRGB(255, 240, 120), Color3.fromRGB(150, 225, 255)
	for n = 1, if crit then 3 else 1 do
		task.delay((n - 1) * 0.07, function()
			local sky = at + Vector3.new((math.random() - 0.5) * 6, 18 + math.random() * 6, (math.random() - 0.5) * 6)
			CombatVfx.lightning(sky, at, if n == 2 then ARC else VOLT)
		end)
	end
	bloom(at, WHITE, 2.2 * k, 0.15, 0)
	ring(at, out, VOLT, 0.5, 5 * k, 0.3)
	streaks(at, out, math.ceil((6 + 4 * k) * scale), 5, { VOLT, ARC, WHITE }, 0.25)
	if crit then
		ring(at, Vector3.yAxis, ARC, 1, 9, 0.4)
	end
end

-- The rock folds in on the hit, then a violet shockwave spits back out.
function LOOKS.Void(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local VIOLET, PALE, BLACK = Color3.fromRGB(170, 90, 255), Color3.fromRGB(230, 200, 255), Color3.fromRGB(14, 8, 24)
	local shell = piece(
		CFrame.new(at),
		Vector3.one * 4 * k,
		VIOLET,
		Enum.Material.ForceField,
		0.25,
		{ Shape = Enum.PartType.Ball }
	)
	tween(shell, 0.18, { Size = Vector3.one * 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local core = piece(
		CFrame.new(at),
		Vector3.one * 0.3,
		BLACK,
		Enum.Material.SmoothPlastic,
		0.6,
		{ Shape = Enum.PartType.Ball }
	)
	tween(core, 0.18, { Size = Vector3.one * 1.3 * k })
	-- Specks drawn in from all round.
	for i = 1, math.ceil((6 + 4 * k) * scale) do
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		local speck = piece(
			aim(at + dir * 3.2 * k, at),
			Vector3.new(0.08, 0.08, 0.6),
			if i % 2 == 0 then PALE else VIOLET,
			Enum.Material.Neon,
			0.2
		)
		tween(
			speck,
			0.18,
			{ CFrame = aim(at + dir * 0.2, at), Size = Vector3.new(0.04, 0.04, 0.2) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
	task.delay(0.18, function()
		tween(core, 0.35, { Size = Vector3.one * 0.1, Transparency = 1 })
		ring(at, out, VIOLET, 0.4, 6 * k, 0.4)
		bloom(at, PALE, 2 * k, 0.2, 0.2)
		CombatFx.burst(at, VIOLET, "Sparks", 0.7 * k)
		if crit then
			ring(at, Vector3.yAxis, VIOLET, 1, 12, 0.5)
			ring(at, Vector3.yAxis, BLACK, 0.5, 8, 0.6, Enum.Material.SmoothPlastic)
		end
	end)
end

-- Coins pop out of the rock, spinning; a star glints.
function LOOKS.Gold(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local GOLD = Color3.fromRGB(255, 200, 70)
	bloom(at, GOLD, 2.4 * k, 0.25, 0.25)
	fling(at, out, math.ceil((4 + 4 * k + (if crit then 6 else 0)) * scale), 16, function()
		local coin = piece(CFrame.new(at), Vector3.new(0.1, 0.6, 0.6), GOLD, Enum.Material.Foil, 1.1, {
			Shape = Enum.PartType.Cylinder,
			Flies = true,
		})
		coin.Reflectance = 0.4
		return coin
	end, 1.1)
	-- The glint: a four-point star facing the swing.
	local face = aim(at + out * 0.3, at + out)
	for _, roll in { 0, math.pi / 2 } do
		local bar = piece(face * CFrame.Angles(0, 0, roll), Vector3.new(0.1, 0.4, 0.1), WHITE, Enum.Material.Neon, 0.35)
		tween(bar, 0.12, { Size = Vector3.new(0.12, 3.2 * k, 0.1) }, Enum.EasingStyle.Back)
		task.delay(0.12, function()
			tween(bar, 0.22, { Size = Vector3.new(0.02, 0.6, 0.02), Transparency = 1 })
		end)
	end
	CombatFx.burst(at, GOLD, "Sparks", 0.5 * k)
end

-- The hit splits into every colour: rainbow flashes, shards and rings.
function LOOKS.Prism(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local hues = { 0, 0.14, 0.33, 0.52, 0.7, 0.86 }
	for i, offset in { Vector3.new(0.5, 0, 0), Vector3.new(-0.3, 0.4, 0), Vector3.new(-0.2, -0.4, 0.3) } do
		bloom(at + offset * k, Color3.fromHSV(hues[i * 2 - 1], 0.75, 1), 2 * k, 0.28, 0.35)
	end
	fling(at, out, math.ceil((6 + 4 * k) * scale), 15, function(i)
		return piece(
			CFrame.new(at),
			Vector3.new(0.18, 0.5, 0.18),
			Color3.fromHSV(hues[(i - 1) % #hues + 1], 0.7, 1),
			Enum.Material.Glass,
			0.9,
			{
				Flies = true,
			}
		)
	end, 0.9)
	for i = 1, if crit then 4 else 2 do
		task.delay((i - 1) * 0.06, function()
			ring(at, out, Color3.fromHSV(hues[(i * 2) % #hues + 1], 0.7, 1), 0.4, (3 + i * 1.4) * k, 0.4)
		end)
	end
	CombatFx.burst(at, WHITE, "Sparks", 0.5 * k)
end

-- Hot pink and cyan sparks streak off; an X marks the hit.
function LOOKS.Neon(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local PINK, CYAN = Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 240, 255)
	streaks(at, out, math.ceil((8 + 6 * k) * scale), 6 * k, { PINK, CYAN }, 0.3)
	local face = aim(at + out * 0.3, at + out)
	for n, roll in { math.pi / 4, -math.pi / 4 } do
		local bar = piece(
			face * CFrame.Angles(0, 0, roll),
			Vector3.new(0.14, 0.4, 0.06),
			if n == 1 then PINK else CYAN,
			Enum.Material.Neon,
			0.4
		)
		tween(bar, 0.08, { Size = Vector3.new(0.16, 2.4 * k, 0.06) })
		task.delay(0.12, function()
			tween(bar, 0.25, { Transparency = 1 })
		end)
	end
	bloom(at, PINK, 2 * k, 0.2, 0.35)
	if crit then
		ring(at, out, CYAN, 0.5, 7, 0.35)
		ring(at, out, PINK, 0.3, 5, 0.3)
	end
end

-- Old bone chips and a puff of dust.
function LOOKS.Bone(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local BONE, OLD = Color3.fromRGB(236, 226, 200), Color3.fromRGB(196, 180, 150)
	CombatFx.burst(at, OLD, "Smoke", 0.8 * k)
	fling(at, out, math.ceil((5 + 4 * k) * scale), 14, function(i)
		return piece(
			CFrame.new(at),
			Vector3.new(0.22, 0.22, 0.4 + math.random() * 0.3),
			if i % 2 == 0 then BONE else OLD,
			Enum.Material.Sandstone,
			1,
			{
				Flies = true,
			}
		)
	end, 1)
	ring(at, out, BONE, 0.4, 3.5 * k, 0.3, Enum.Material.SmoothPlastic)
	if crit then
		CombatFx.burst(at, BONE, "Smoke", 1.6)
		ring(at, Vector3.yAxis, OLD, 1, 9, 0.5, Enum.Material.SmoothPlastic)
	end
end

-- Amethyst crystals grow out of the hit, glowing violet.
function LOOKS.Geode(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local AMETHYST, DEEP = Color3.fromRGB(196, 130, 255), Color3.fromRGB(120, 50, 200)
	bloom(at, AMETHYST, 2.4 * k, 0.25, 0.3)
	crystals(
		at,
		out,
		math.ceil((4 + 3 * k) * scale),
		1.4 + 1.2 * k,
		AMETHYST,
		Color3.fromRGB(240, 210, 255),
		Enum.Material.Glass
	)
	CombatFx.burst(at, AMETHYST, "Sparks", 0.5 * k)
	if crit then
		crystals(at, Vector3.yAxis, 5, 2.6, DEEP, AMETHYST, Enum.Material.Glass)
		ring(at, Vector3.yAxis, AMETHYST, 1, 9, 0.45)
	end
end

-- Twin Star: a gold star and a teal one crash together on the hit, burst,
-- and a white star glints where they met.
function LOOKS.TwinStar(at: Vector3, out: Vector3, k: number, crit: boolean, scale: number)
	local GOLD, TEAL = Color3.fromRGB(255, 205, 90), Color3.fromRGB(70, 235, 220)
	local side = aim(at, at + out).RightVector
	for n, color in { GOLD, TEAL } do
		local from = at + side * (if n == 1 then 1.8 else -1.8) * k + Vector3.new(0, 0.8, 0)
		local star =
			piece(CFrame.new(from), Vector3.one * 0.5, color, Enum.Material.Neon, 0.35, { Shape = Enum.PartType.Ball })
		tween(star, 0.12, { CFrame = CFrame.new(at) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.12, function()
			tween(star, 0.2, { Size = Vector3.one * 2 * k, Transparency = 1 })
		end)
	end
	task.delay(0.12, function()
		bloom(at, WHITE, 2.4 * k, 0.25, 0.2)
		ring(at, out, GOLD, 0.4, 4.5 * k, 0.35)
		ring(at, out, TEAL, 0.3, 3.2 * k, 0.3)
		streaks(at, out, math.ceil((8 + 6 * k) * scale), 5 * k, { GOLD, TEAL }, 0.3)
		local face = aim(at + out * 0.3, at + out)
		for _, roll in { 0, math.pi / 2 } do
			local bar =
				piece(face * CFrame.Angles(0, 0, roll), Vector3.new(0.1, 0.4, 0.1), WHITE, Enum.Material.Neon, 0.35)
			tween(bar, 0.1, { Size = Vector3.new(0.12, 3 * k, 0.1) }, Enum.EasingStyle.Back)
			task.delay(0.1, function()
				tween(bar, 0.22, { Size = Vector3.new(0.02, 0.6, 0.02), Transparency = 1 })
			end)
		end
		if crit then
			ring(at, Vector3.yAxis, GOLD, 1, 8, 0.45)
			ring(at, Vector3.yAxis, TEAL, 0.6, 6, 0.4)
		end
	end)
end

PickImpacts.Looks = LOOKS

function PickImpacts.play(
	kind: string?,
	at: Vector3,
	from: Vector3?,
	power: number,
	crit: boolean,
	scale: number?
): boolean
	local look = kind and LOOKS[kind]
	if not look then
		return false
	end
	local away = if from then Vector3.new(from.X - at.X, 0, from.Z - at.Z) else Vector3.zero
	local out = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	local k = (0.8 + math.clamp(power, 0, 1) * 0.5) * (if crit then 1.35 else 1)
	look(at, out, k, crit, math.clamp(scale or 1, 0.3, 1))
	return true
end

return PickImpacts
