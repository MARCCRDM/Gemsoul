--[[
	The combat visual effects kit (client only, nothing replicates). Built
	from neon parts, trails, particles, lights and a screen grade:

	  slash(origin, direction, range, arc, color, heavy, side)
	      a crescent trail swept across a swing's arc: a white-hot edge
	      inside a glow in the weapon's colour, sweeping one way or the other
	  impact(position, color, crit, heavy)
	      a hit: a flash core, sparks, streaks flying out, a shockwave ring
	      facing you, and for a crit a spinning gold star
	  lightning(from, to, color)
	      a jagged bolt with forks, white core in a coloured glow, flickering
	  projectile(from, to, color, fireball)
	      a glowing round (or fireball) with a trail, and an impact where it lands
	  beam(from, to, color, radius)
	      a surge's beam: a core and glow that flicker out, a burst and a
	      shockwave at the far end
	  aura(root, color)
	      a buff or shield: motes spiralling up around you, a ground ring and a
	      soft column of light
	  parry(position, color)  a star flash and two rings
	  guard(position, look, broken)
	      a shield of light where the blow met the guard; when broken it
	      shatters into shards
	  death(position, color)  shards, a rising soul column, a ring and embers
	  dash(origin, direction, distance, color)
	      speed lines along the dodge and a ring of dust where it began
	  screen(kind, seconds)
	      a colour grade on your screen: "Hurt" (a red flash), "Stun" (drained
	      colour and blur), "Crit" and "Parry" (a bright pop)
]]
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)

local CombatVfx = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 90)

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "CombatVfx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function neon(size: Vector3, cframe: CFrame, color: Color3, transparency: number?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = "Vfx"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
	if shape then
		part.Shape = shape
	end
	part.CFrame = cframe
	part.Parent = fxFolder()
	return part
end

local function fade(part: BasePart, seconds: number, goal: { [string]: any }?, style: Enum.EasingStyle?)
	local target: { [string]: any } = goal or {}
	target.Transparency = 1
	TweenService:Create(part, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), target)
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

local function camera(): Camera
	return workspace.CurrentCamera
end

-- Slash -------------------------------------------------------------------------------

local lastSide = 1
function CombatVfx.slash(
	origin: Vector3,
	direction: Vector3,
	range: number,
	arc: number,
	color: Color3,
	heavy: boolean?,
	side: number?
)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local frame = CFrame.lookAt(origin, origin + flat.Unit)
	local radius = math.max(2.5, range * 0.62)
	local segments = if heavy then 14 else 11
	local sweep = if heavy then 0.13 else 0.08
	-- No side given: alternate, so a flurry cuts back and forth.
	if not side then
		lastSide = -lastSide
	end
	local sign = side or lastSide
	-- A light swing cuts flat and a little rising; a heavy chops down from high.
	local rise = if heavy then -2.6 else 0.9
	local lift = if heavy then 1.9 else 0.7
	local spread = math.rad(arc)
	local previous: Vector3? = nil
	for i = 0, segments do
		local t = i / segments
		local angle = sign * spread * (t - 0.5)
		local point = (frame * CFrame.Angles(0, angle, 0) * CFrame.new(0, lift + rise * (t - 0.5), -radius)).Position
		if previous then
			local from, to = previous, point
			-- Thickest in the middle of the sweep, tapering at both ends.
			local swell = math.sin(t * math.pi)
			task.delay(sweep * t, function()
				local length = (to - from).Magnitude + 0.15
				local mid = CFrame.lookAt((from + to) / 2, to)
				local glow =
					neon(Vector3.new((if heavy then 0.9 else 0.6) * swell + 0.08, 0.06, length), mid, color, 0.35)
				local edge =
					neon(Vector3.new(0.14 * swell + 0.03, 0.04, length), mid * CFrame.new(0, 0.02, 0), WHITE, 0.05)
				fade(glow, 0.22, { Size = Vector3.new(0.05, 0.05, length * 1.15) })
				fade(edge, 0.16, { Size = Vector3.new(0.02, 0.02, length) })
			end)
		end
		previous = point
	end
	CombatFx.flash((frame * CFrame.new(0, lift, -radius)).Position, color, if heavy then 3 else 1.6, range + 6, 0.18)
end

-- Impact ------------------------------------------------------------------------------

function CombatVfx.impact(position: Vector3, color: Color3, crit: boolean?, heavy: boolean?)
	local big = (if crit then 1.6 else 1) * (if heavy then 1.3 else 1)
	local view = camera()
	local facing = if view then CFrame.lookAt(position, view.CFrame.Position) else CFrame.new(position)
	-- The flash core.
	local core = neon(Vector3.one * 0.6 * big, CFrame.new(position), WHITE, 0, Enum.PartType.Ball)
	fade(core, 0.14, { Size = Vector3.one * 2.4 * big, Color = color })
	-- A shockwave ring facing you.
	local ring = neon(
		Vector3.new(0.08, 1, 1),
		facing * CFrame.Angles(0, math.rad(90), 0),
		color:Lerp(WHITE, 0.3),
		0.2,
		Enum.PartType.Cylinder
	)
	fade(ring, 0.25, { Size = Vector3.new(0.02, 4.5 * big, 4.5 * big) })
	-- Streaks flying out.
	for _ = 1, math.floor(7 * big) do
		local out = Vector3.new(math.random() - 0.5, math.random() - 0.35, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			out = out.Unit
			local length = 0.9 + math.random() * 1.4 * big
			local streak = neon(
				Vector3.new(0.07, 0.07, length),
				CFrame.lookAt(position + out * 0.4, position + out * 2),
				color:Lerp(WHITE, 0.5),
				0.1
			)
			fade(streak, 0.18, { CFrame = CFrame.lookAt(position + out * 2.4 * big, position + out * 4) })
		end
	end
	CombatFx.burst(position, color, "Sparks", big)
	if crit then
		-- A gold star that spins open.
		for _, roll in { 0, 90, 45, 135 } do
			local ray = neon(
				Vector3.new(0.12, if roll % 90 == 0 then 3.4 else 2, 0.05),
				facing * CFrame.Angles(0, 0, math.rad(roll)),
				GOLD,
				0
			)
			fade(ray, 0.3, {
				CFrame = facing * CFrame.Angles(0, 0, math.rad(roll + 35)),
				Size = Vector3.new(0.03, if roll % 90 == 0 then 5 else 3, 0.02),
			})
		end
		CombatFx.flash(position, GOLD, 5, 16, 0.25)
	end
end

-- Lightning ---------------------------------------------------------------------------

local function jagged(from: Vector3, to: Vector3, kinks: number, wander: number): { Vector3 }
	local points = { from }
	for i = 1, kinks do
		local along = from:Lerp(to, i / (kinks + 1))
		table.insert(
			points,
			along + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * wander
		)
	end
	table.insert(points, to)
	return points
end
local function drawBolt(points: { Vector3 }, color: Color3, width: number, life: number)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		local glow = neon(Vector3.new(width * 2.6, width * 2.6, length), cf, color, 0.45)
		local core = neon(Vector3.new(width, width, length), cf, WHITE, 0)
		fade(glow, life)
		fade(core, life * 0.8)
	end
end
function CombatVfx.lightning(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local kinks = math.clamp(math.floor(distance / 2.5), 3, 9)
	-- Two strokes a moment apart, so it flickers.
	for flicker = 0, 1 do
		task.delay(flicker * 0.06, function()
			local points = jagged(from, to, kinks, 1.8)
			drawBolt(points, color, 0.12, 0.16)
			-- Forks off the main bolt.
			for _ = 1, 2 do
				local start = points[math.random(2, #points - 1)]
				local reach = Vector3.new(math.random() - 0.5, math.random() - 0.6, math.random() - 0.5) * 5
				drawBolt(jagged(start, start + reach, 2, 1.2), color, 0.06, 0.12)
			end
		end)
	end
	CombatFx.burst(to, color, "Sparks", 1)
	CombatFx.flash(to, color, 4, 14, 0.2)
end

-- Projectile --------------------------------------------------------------------------

function CombatVfx.projectile(from: Vector3, to: Vector3, color: Color3, fireball: boolean?)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local size = if fireball then 1.1 else 0.4
	local round = neon(Vector3.one * size, CFrame.lookAt(from, to), color, 0, Enum.PartType.Ball)
	local core = neon(Vector3.one * size * 0.55, CFrame.lookAt(from, to), WHITE, 0, Enum.PartType.Ball)
	-- A trail behind it.
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, size * 0.4, 0), Vector3.new(0, -size * 0.4, 0)
	a0.Parent, a1.Parent = round, round
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color:Lerp(WHITE, 0.4), color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = if fireball then 0.3 else 0.18
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Parent = round
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Shadows = color, if fireball then 14 else 9, 2.5, false
	glow.Parent = round
	if fireball then
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = "rbxasset://textures/particles/fire_main.dds"
		flames.Color = ColorSequence.new(color:Lerp(WHITE, 0.4), color)
		flames.LightEmission = 1
		flames.Size = NumberSequence.new(1.2, 0)
		flames.Lifetime = NumberRange.new(0.2, 0.35)
		flames.Speed = NumberRange.new(1, 3)
		flames.Rate = 60
		flames.Parent = round
	end
	local travel = math.clamp(distance / 140, 0.06, 0.5)
	local arrive = CFrame.lookAt(to, to + (to - from).Unit)
	TweenService:Create(round, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = arrive }):Play()
	TweenService:Create(core, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = arrive }):Play()
	task.delay(travel, function()
		round.Transparency, core.Transparency = 1, 1
		Debris:AddItem(round, 0.4)
		Debris:AddItem(core, 0.05)
		CombatVfx.impact(to, color, false, fireball)
		if fireball then
			CombatFx.burst(to, color, "Embers", 1.4)
		end
	end)
	CombatFx.burst(from, color, "Sparks", if fireball then 0.9 else 0.5)
end

-- Beam --------------------------------------------------------------------------------

function CombatVfx.beam(from: Vector3, to: Vector3, color: Color3, radius: number?)
	local distance = (to - from).Magnitude
	if distance > 0.1 then
		local cf = CFrame.lookAt((from + to) / 2, to)
		local glow = neon(Vector3.new(0.7, 0.7, distance), cf, color, 0.45)
		local core = neon(Vector3.new(0.18, 0.18, distance), cf, WHITE, 0)
		fade(glow, 0.3, { Size = Vector3.new(0.05, 0.05, distance) })
		fade(core, 0.2, { Size = Vector3.new(0.02, 0.02, distance) })
	end
	CombatVfx.impact(to, color, false, (radius or 0) > 0)
	if radius and radius > 0 then
		local floorRing = neon(
			Vector3.new(0.12, 1, 1),
			CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			0.25,
			Enum.PartType.Cylinder
		)
		fade(floorRing, 0.4, { Size = Vector3.new(0.05, radius * 2.2, radius * 2.2) })
	end
end

-- Aura (buffs, shields) ---------------------------------------------------------------

function CombatVfx.aura(root: BasePart, color: Color3)
	local base = root.CFrame.Position - Vector3.new(0, 2.6, 0)
	local floorRing = neon(
		Vector3.new(0.1, 1, 1),
		CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.15,
		Enum.PartType.Cylinder
	)
	fade(floorRing, 0.6, { Size = Vector3.new(0.05, 9, 9) })
	-- A soft column of light (a cylinder stood on end).
	local column = neon(
		Vector3.new(7, 3.2, 3.2),
		CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.8,
		Enum.PartType.Cylinder
	)
	fade(column, 0.7, { Size = Vector3.new(9, 0.4, 0.4) })
	-- Motes spiralling up around you.
	for i = 1, 14 do
		local angle = i * math.pi * 2 / 7
		local start = base + Vector3.new(math.cos(angle) * 1.8, 0.2, math.sin(angle) * 1.8)
		local finish = base + Vector3.new(math.cos(angle + 2.2) * 1.1, 5.5 + (i % 3), math.sin(angle + 2.2) * 1.1)
		task.delay(i * 0.025, function()
			local mote = neon(Vector3.one * 0.28, CFrame.new(start), color:Lerp(WHITE, 0.4), 0, Enum.PartType.Ball)
			fade(mote, 0.6, { CFrame = CFrame.new(finish), Size = Vector3.one * 0.05 }, Enum.EasingStyle.Sine)
		end)
	end
	CombatFx.flash(root.CFrame.Position, color, 3, 14, 0.5)
end

-- Parry and guard ---------------------------------------------------------------------

function CombatVfx.parry(position: Vector3, color: Color3?)
	local tint = color or GOLD
	local view = camera()
	local facing = if view then CFrame.lookAt(position, view.CFrame.Position) else CFrame.new(position)
	for _, roll in { 0, 60, 120 } do
		local ray = neon(Vector3.new(0.16, 5, 0.05), facing * CFrame.Angles(0, 0, math.rad(roll)), WHITE, 0)
		fade(
			ray,
			0.28,
			{ Size = Vector3.new(0.03, 8, 0.02), CFrame = facing * CFrame.Angles(0, 0, math.rad(roll + 25)) }
		)
	end
	for i, size in { 5, 8 } do
		local ring =
			neon(Vector3.new(0.08, 1, 1), facing * CFrame.Angles(0, math.rad(90), 0), tint, 0.1, Enum.PartType.Cylinder)
		fade(ring, 0.2 + i * 0.1, { Size = Vector3.new(0.02, size, size) })
	end
	CombatFx.burst(position, tint, "Sparks", 2)
	CombatFx.flash(position, tint, 7, 20, 0.3)
end

function CombatVfx.guard(position: Vector3, look: Vector3?, broken: boolean?)
	local tint = if broken then Color3.fromRGB(255, 150, 50) else Color3.fromRGB(150, 230, 255)
	local facing = if look and look.Magnitude > 0.01
		then CFrame.lookAt(position, position + look)
		else CFrame.new(position)
	local plate =
		neon(Vector3.new(0.06, 3, 3), facing * CFrame.Angles(0, math.rad(90), 0), tint, 0.35, Enum.PartType.Cylinder)
	if broken then
		plate.Transparency = 0.2
		fade(plate, 0.1)
		-- It shatters: shards of light flying apart.
		for _ = 1, 10 do
			local out = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
			if out.Magnitude > 0.05 then
				local shard = neon(
					Vector3.new(0.5, 0.06, 0.35),
					facing * CFrame.new(0, 0, -0.2) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
					tint,
					0.1
				)
				fade(shard, 0.45, { CFrame = shard.CFrame + out.Unit * 3.5 })
			end
		end
	else
		fade(plate, 0.22, { Size = Vector3.new(0.02, 3.8, 3.8) })
	end
	local rim =
		neon(Vector3.new(0.1, 3, 3), facing * CFrame.Angles(0, math.rad(90), 0), WHITE, 0.3, Enum.PartType.Cylinder)
	fade(rim, 0.18, { Size = Vector3.new(0.02, 4.4, 4.4) })
end

-- Death -------------------------------------------------------------------------------

function CombatVfx.death(position: Vector3, color: Color3)
	CombatFx.burst(position, color, "Shards", 1.6)
	CombatFx.burst(position, color, "Embers", 1.4)
	CombatFx.flash(position, color, 6, 24, 0.6)
	local column = neon(
		Vector3.new(14, 1.4, 1.4),
		CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.2,
		Enum.PartType.Cylinder
	)
	fade(column, 0.8, { Size = Vector3.new(24, 0.1, 0.1), CFrame = column.CFrame + Vector3.new(0, 4, 0) })
	local floorRing = neon(
		Vector3.new(0.1, 1, 1),
		CFrame.new(position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.1,
		Enum.PartType.Cylinder
	)
	fade(floorRing, 0.6, { Size = Vector3.new(0.05, 14, 14) })
	for _ = 1, 12 do
		local out = Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			local shard = neon(
				Vector3.new(0.4, 0.8, 0.4),
				CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				color:Lerp(WHITE, 0.2),
				0
			)
			fade(shard, 0.7, { CFrame = shard.CFrame + out.Unit * 7, Size = Vector3.new(0.1, 0.2, 0.1) })
		end
	end
end

-- Dash --------------------------------------------------------------------------------

function CombatVfx.dash(origin: Vector3, direction: Vector3, distance: number, color: Color3)
	local floor = origin - Vector3.new(0, 2.6, 0)
	local dust = neon(
		Vector3.new(0.1, 1, 1),
		CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(200, 190, 175),
		0.4,
		Enum.PartType.Cylinder
	)
	fade(dust, 0.35, { Size = Vector3.new(0.05, 6, 6) })
	if direction.Magnitude < 0.01 then
		return
	end
	local frame = CFrame.lookAt(origin, origin + direction)
	for i = 1, 6 do
		local offset = Vector3.new((math.random() - 0.5) * 1.6, (math.random() - 0.5) * 2.4, 0)
		local length = distance * (0.4 + math.random() * 0.4)
		local line = neon(
			Vector3.new(0.06, 0.06, length),
			frame * CFrame.new(offset) * CFrame.new(0, 0, -length / 2),
			color:Lerp(WHITE, 0.4),
			0.3
		)
		task.delay(i * 0.02, function()
			fade(line, 0.25, { Size = Vector3.new(0.02, 0.02, length * 1.3) })
		end)
	end
end

-- Screen grade ------------------------------------------------------------------------

local grade: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil
local function effects(): (ColorCorrectionEffect, BlurEffect)
	if not grade or not grade.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "CombatGrade"
		made.Parent = Lighting
		grade = made
	end
	if not blur or not blur.Parent then
		local made = Instance.new("BlurEffect")
		made.Name = "CombatBlur"
		made.Size = 0
		made.Parent = Lighting
		blur = made
	end
	return grade :: ColorCorrectionEffect, blur :: BlurEffect
end
local function settle(seconds: number)
	local g, b = effects()
	TweenService:Create(
		g,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TintColor = WHITE, Saturation = 0, Brightness = 0, Contrast = 0 }
	):Play()
	TweenService:Create(b, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 }):Play()
end
function CombatVfx.screen(kind: string, seconds: number?)
	local g, b = effects()
	if kind == "Hurt" then
		g.TintColor, g.Contrast = Color3.fromRGB(255, 185, 185), 0.08
		settle(0.35)
	elseif kind == "Stun" then
		g.Saturation, g.Contrast = -0.65, 0.1
		b.Size = 7
		settle(math.max(0.3, seconds or 0.8))
	elseif kind == "Crit" then
		g.Brightness, g.Contrast = 0.06, 0.12
		settle(0.18)
	elseif kind == "Parry" then
		g.Brightness, g.Saturation = 0.12, 0.25
		settle(0.25)
	end
end

return CombatVfx
