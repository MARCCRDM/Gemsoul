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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)
local GemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemConfig"))

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
		0.55,
		Enum.PartType.Cylinder
	)
	fade(ring, 0.2, { Size = Vector3.new(0.02, 3.4 * big, 3.4 * big) })
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

-- Element signature on a hit ---------------------------------------------------------

local ELEMENT_COLORS = {
	Fire = Color3.fromRGB(255, 110, 40),
	Frost = Color3.fromRGB(150, 215, 255),
	Shock = Color3.fromRGB(255, 230, 80),
	Poison = Color3.fromRGB(110, 230, 80),
}
-- What an elemental hit looks like on top of the impact, so each element
-- reads at a glance: Thermal bursts into flame, Cryo throws ice spikes and
-- cold mist, Ion crackles with arcs, Corrosive splashes and fumes.
local lightningRef: ((Vector3, Vector3, Color3) -> ())? = nil
function CombatVfx.element(position: Vector3, element: string?, big: number?)
	local color = element and ELEMENT_COLORS[element]
	if not color then
		return
	end
	local scale = big or 1
	if element == "Fire" then
		-- A ball of flame that swells and burns out, embers flying up.
		local flame =
			neon(Vector3.one * 0.8 * scale, CFrame.new(position), Color3.fromRGB(255, 200, 90), 0.1, Enum.PartType.Ball)
		fade(flame, 0.3, { Size = Vector3.one * 3.2 * scale, Color = Color3.fromRGB(255, 70, 20) })
		CombatFx.burst(position, color, "Embers", 0.9 * scale)
		CombatFx.flash(position, color, 4, 12, 0.3)
	elseif element == "Frost" then
		-- Ice spikes jutting out of the wound, frost mist around them.
		for i = 1, math.floor(6 * scale) do
			local out = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5)
			if out.Magnitude > 0.05 then
				out = out.Unit
				local length = 0.8 + math.random() * 0.9 * scale
				local spike = Instance.new("Part")
				spike.Name = "Vfx"
				spike.Anchored, spike.CanCollide, spike.CanQuery, spike.CanTouch, spike.CastShadow =
					true, false, false, false, false
				spike.Material = Enum.Material.Glass
				spike.Color = Color3.fromRGB(205, 238, 255)
				spike.Transparency = 0.2
				spike.Reflectance = 0.3
				spike.Size = Vector3.new(0.12, 0.12, 0.1)
				spike.CFrame = CFrame.lookAt(position, position + out)
				spike.Parent = fxFolder()
				TweenService
					:Create(spike, TweenInfo.new(0.08 + i * 0.01, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = Vector3.new(0.22, 0.22, length),
						CFrame = CFrame.lookAt(position + out * length / 2, position + out * length),
					})
					:Play()
				task.delay(0.35, function()
					fade(spike, 0.3)
				end)
			end
		end
		CombatFx.burst(position, color, "Frost", 0.8 * scale)
		CombatFx.burst(position, Color3.fromRGB(220, 240, 255), "Smoke", 0.6 * scale)
	elseif element == "Shock" then
		-- Arcs crackling out to the sides.
		local draw = lightningRef
		if draw then
			for _ = 1, 3 do
				local out = Vector3.new(math.random() - 0.5, math.random() - 0.4, math.random() - 0.5)
				if out.Magnitude > 0.05 then
					draw(position, position + out.Unit * (2 + math.random() * 2) * scale, color)
				end
			end
		end
	elseif element == "Poison" then
		-- A splash of droplets arcing out and down, and a puff of fumes.
		for _ = 1, math.floor(8 * scale) do
			local out = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
			if out.Magnitude > 0.05 then
				out = out.Unit
				local drop = neon(Vector3.one * 0.22, CFrame.new(position), color, 0.05, Enum.PartType.Ball)
				local peak = position + out * 1.2 + Vector3.new(0, 0.8 + math.random() * 0.6, 0)
				local land = position + out * (2 + math.random() * 1.5) - Vector3.new(0, 2.2, 0)
				TweenService:Create(
					drop,
					TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = CFrame.new(peak) }
				):Play()
				task.delay(0.16, function()
					fade(drop, 0.3, { CFrame = CFrame.new(land), Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad)
				end)
			end
		end
		CombatFx.burst(position, color, "Smoke", 0.9 * scale)
		CombatFx.burst(position, color, "Drips", 0.8 * scale)
	end
end

-- A ground blast's mark: a scorched disc with a glowing rim that cools and fades.
function CombatVfx.scorch(floor: Vector3, radius: number, color: Color3)
	local disc = Instance.new("Part")
	disc.Name = "Vfx"
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.SmoothPlastic
	disc.Color = color:Lerp(Color3.new(0, 0, 0), 0.8)
	disc.Transparency = 0.35
	disc.Size = Vector3.new(0.05, radius * 1.4, radius * 1.4)
	disc.CFrame = CFrame.new(floor + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = fxFolder()
	local rim = neon(
		Vector3.new(0.06, radius * 1.45, radius * 1.45),
		CFrame.new(floor + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.35,
		Enum.PartType.Cylinder
	)
	-- The rim cools first; the scorch lingers a little longer.
	task.delay(0.4, function()
		fade(rim, 1.2, { Color = color:Lerp(Color3.new(0, 0, 0), 0.6) })
	end)
	task.delay(1.6, function()
		fade(disc, 1.4)
	end)
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
local function drawBolt(points: { Vector3 }, color: Color3, width: number, life: number, glows: boolean)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		-- A white core in a coloured glow (a thin fork is just the colour).
		if glows then
			local glow = neon(Vector3.new(width * 2.6, width * 2.6, length), cf, color, 0.45)
			fade(glow, life)
		end
		local core = neon(Vector3.new(width, width, length), cf, if glows then WHITE else color, 0)
		fade(core, life * 0.8)
	end
end
function CombatVfx.lightning(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	-- (distance ~= distance: a NaN end point draws nothing.)
	if distance < 0.5 or distance ~= distance or distance > 1000 then
		return
	end
	local kinks = math.clamp(math.floor(distance / 3.5), 3, 7)
	-- Two strokes a moment apart, so it flickers.
	for flicker = 0, 1 do
		task.delay(flicker * 0.06, function()
			local points = jagged(from, to, kinks, 1.8)
			drawBolt(points, color, 0.12, 0.16, true)
			-- Forks off the main bolt.
			for _ = 1, 2 do
				local start = points[math.random(2, #points - 1)]
				local reach = Vector3.new(math.random() - 0.5, math.random() - 0.6, math.random() - 0.5) * 5
				drawBolt(jagged(start, start + reach, 2, 1.2), color, 0.06, 0.12, false)
			end
		end)
	end
	CombatFx.burst(to, color, "Sparks", 1)
	CombatFx.flash(to, color, 4, 14, 0.2)
end

lightningRef = CombatVfx.lightning

local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude
floorRay.RespectCanCollide = true
local function floorBelow(at: Vector3): Vector3
	-- The ground under it, not a fighter standing there.
	local skip: { Instance } = { fxFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(skip, enemies)
	end
	floorRay.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), floorRay)
	return if hit then hit.Position else at - Vector3.new(0, 2.6, 0)
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
	-- An element's surge flies and lands its own way.
	if CombatVfx.surge(from, to, GemConfig.elementOfColor(color), radius) then
		return
	end
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
			CFrame.new(floorBelow(to) + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			0.25,
			Enum.PartType.Cylinder
		)
		fade(floorRing, 0.4, { Size = Vector3.new(0.05, radius * 2.2, radius * 2.2) })
	end
end

-- Element surges -----------------------------------------------------------------------
--
-- Each element's surge travels and lands its own way, so a cast reads at a
-- glance from across the arena:
--   Fire    a fireball streaking out, a rolling flame trail that rises and
--           reddens behind it, a fireball bloom and a ring of fire
--   Frost   an ice lance with a frost-mist wake and glittering crystals,
--           landing in a cluster of ice spikes that shatter
--   Shock   a thick forked bolt that flickers three times, landing in a
--           ball of sparks (bolts out of the sky over an area)
--   Poison  a glob of acid lobbed in an arc, dripping as it flies, splashing
--           into a bubbling, spreading pool

local HOT = Color3.fromRGB(255, 226, 140)
local EMBER = Color3.fromRGB(200, 38, 16)
local ICE = Color3.fromRGB(205, 238, 255)
local ACID_LIGHT = Color3.fromRGB(190, 255, 140)
local SOOT = Color3.fromRGB(90, 34, 20)

-- Too many effect parts alive (a big fight): skip the optional extras.
local function busy(): boolean
	return #fxFolder():GetChildren() > 450
end

local function move(part: BasePart, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(part, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function jitter(amount: number): Vector3
	return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * amount
end

-- A flat disc lying on the ground (a cylinder on its side).
local function disc(at: Vector3, diameter: number, color: Color3, transparency: number): Part
	return neon(
		Vector3.new(0.08, diameter, diameter),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		transparency,
		Enum.PartType.Cylinder
	)
end

-- A soft puff of flame that swells, rises and burns down from white-hot
-- to a dull ember as it fades.
local function flamePuff(at: Vector3, size: number, rise: number, seconds: number)
	local puff = neon(Vector3.one * size * 0.7, CFrame.new(at), HOT, 0.25, Enum.PartType.Ball)
	fade(puff, seconds, {
		Size = Vector3.one * size * 1.5,
		Color = SOOT,
		CFrame = CFrame.new(at + Vector3.new(0, rise, 0)),
	}, Enum.EasingStyle.Quad)
end

-- A glowing ribbon streaming behind a moving part (a Roblox Trail): smooth,
-- tapering and fading from `head` to `tail` colour.
local function ribbon(part: BasePart, width: number, head: Color3, tail: Color3, life: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
	a0.Parent, a1.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(head, tail)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.Lifetime = life
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
end

-- A flying head arrives: it vanishes but its trail streams on to the end.
local function retire(part: BasePart, life: number)
	part.Transparency = 1
	Debris:AddItem(part, life + 0.05)
end

-- An ice spike stabbing up out of `base` along `direction`, then breaking
-- off and falling apart.
local function iceSpike(base: Vector3, direction: Vector3, length: number, width: number, hold: number)
	local spike = Instance.new("Part")
	spike.Name = "Vfx"
	spike.Anchored, spike.CanCollide, spike.CanQuery, spike.CanTouch, spike.CastShadow =
		true, false, false, false, false
	spike.Material = Enum.Material.Glass
	spike.Color = ICE
	spike.Transparency = 0.15
	spike.Reflectance = 0.35
	spike.Size = Vector3.new(width * 0.4, width * 0.4, 0.1)
	spike.CFrame = CFrame.lookAt(base, base + direction)
	spike.Parent = fxFolder()
	move(spike, 0.12, {
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt(base + direction * length * 0.5, base + direction * length),
	}, Enum.EasingStyle.Back)
	local glint = neon(Vector3.new(width * 0.3, width * 0.3, 0.1), spike.CFrame, WHITE, 0.2)
	move(glint, 0.12, {
		Size = Vector3.new(width * 0.25, width * 0.25, length * 0.9),
		CFrame = CFrame.lookAt(base + direction * length * 0.5, base + direction * length),
	}, Enum.EasingStyle.Back)
	task.delay(hold, function()
		-- Shatter: it drops and crumbles.
		fade(spike, 0.3, {
			Size = Vector3.new(width * 0.2, width * 0.2, length * 0.4),
			CFrame = spike.CFrame * CFrame.Angles(math.random() - 0.5, 0, math.random() - 0.5) - Vector3.new(0, 1, 0),
		})
		fade(glint, 0.15)
	end)
end

-- Small glittering ice chips flung out (and falling) from `at`.
local function iceChips(at: Vector3, count: number, reach: number)
	for _ = 1, count do
		local out = jitter(1) + Vector3.new(0, 0.35, 0)
		if out.Magnitude > 0.05 then
			out = out.Unit
			local chip = neon(
				Vector3.one * (0.12 + math.random() * 0.18),
				CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				if math.random() < 0.5 then WHITE else ICE,
				0.1
			)
			chip.Material = Enum.Material.Glass
			fade(chip, 0.45 + math.random() * 0.2, {
				CFrame = CFrame.new(at + out * reach * (0.6 + math.random() * 0.6) - Vector3.new(0, 1.2, 0))
					* CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			}, Enum.EasingStyle.Quad)
		end
	end
end

-- Acid droplets thrown up and out, falling back down.
local function acidSplash(at: Vector3, count: number, reach: number)
	local color = ELEMENT_COLORS.Poison
	for _ = 1, count do
		local out = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			out = out.Unit
			local size = 0.18 + math.random() * 0.22
			local drop = neon(
				Vector3.one * size,
				CFrame.new(at),
				color:Lerp(ACID_LIGHT, math.random() * 0.5),
				0.05,
				Enum.PartType.Ball
			)
			local peak = at + out * reach * 0.45 + Vector3.new(0, 0.8 + math.random() * 1.4, 0)
			local land = at + out * reach * (0.8 + math.random() * 0.5) - Vector3.new(0, 1.6, 0)
			move(drop, 0.16, { CFrame = CFrame.new(peak) }, Enum.EasingStyle.Quad)
			task.delay(0.16, function()
				fade(drop, 0.3, { CFrame = CFrame.new(land), Size = Vector3.one * size * 0.4 }, Enum.EasingStyle.Quad)
			end)
		end
	end
end

-- Landings ------------------------------------------------------------------

local LAND = {}

function LAND.Fire(at: Vector3, radius: number)
	local color = ELEMENT_COLORS.Fire
	local big = 1 + radius / 6
	-- The fireball bloom: a white-hot core inside a swelling ball of flame.
	local core = neon(Vector3.one * 0.8, CFrame.new(at), WHITE, 0, Enum.PartType.Ball)
	fade(core, 0.18, { Size = Vector3.one * 2.4 * big, Color = HOT })
	local ball = neon(Vector3.one * 1.2, CFrame.new(at), HOT, 0.05, Enum.PartType.Ball)
	fade(ball, 0.42, { Size = Vector3.one * 4.6 * big, Color = EMBER }, Enum.EasingStyle.Sine)
	for _ = 1, math.floor(5 * big) do
		flamePuff(
			at + jitter(1.6 * big),
			1.2 + math.random() * big,
			1 + math.random() * 1.5,
			0.35 + math.random() * 0.15
		)
	end
	CombatFx.burst(at, color, "Embers", 1.2 * big)
	CombatFx.burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(70, 56, 50), "Smoke", 0.9 * big)
	CombatFx.flash(at, color, 6, 16 + radius * 2, 0.4)
	if radius > 0 then
		-- A ring of fire racing out along the ground and burning down.
		local floor = floorBelow(at)
		-- A ring of fire racing out along the ground, then flaring up and
		-- burning down: a glowing ring with flames licking up all round it.
		local blaze = disc(floor + Vector3.new(0, 0.1, 0), 1, Color3.fromRGB(255, 150, 50), 0.5)
		move(blaze, 0.22, { Size = Vector3.new(0.12, radius * 2, radius * 2) })
		task.delay(0.22, function()
			fade(blaze, 0.35, { Size = Vector3.new(0.04, radius * 2.2, radius * 2.2), Color = EMBER })
		end)
		local count = math.clamp(math.floor(radius * 1.5), 6, 16)
		for i = 1, count do
			local angle = i / count * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			task.delay(0.18 + (i % 3) * 0.03, function()
				local spot = floor + out * radius + Vector3.new(0, 0.5, 0)
				flamePuff(spot, 1.3, 1.6, 0.35)
				CombatFx.burst(spot, color, "Embers", 0.4)
			end)
		end
	end
end

function LAND.Frost(at: Vector3, radius: number)
	local color = ELEMENT_COLORS.Frost
	local big = 1 + radius / 8
	local burst = neon(Vector3.one * 0.8, CFrame.new(at), WHITE, 0, Enum.PartType.Ball)
	fade(burst, 0.2, { Size = Vector3.one * 3 * big, Color = color })
	-- A cluster of ice spikes bursting out where it struck.
	for _ = 1, math.floor(7 * big) do
		local out = jitter(1) + Vector3.new(0, 0.25, 0)
		if out.Magnitude > 0.05 then
			iceSpike(at, out.Unit, 1.2 + math.random() * 1.4 * big, 0.28, 0.35 + math.random() * 0.15)
		end
	end
	iceChips(at, math.floor(10 * big), 3 * big)
	CombatFx.burst(at, color, "Frost", 1.2 * big)
	CombatFx.burst(at, ICE, "Smoke", 0.8 * big)
	CombatFx.flash(at, color, 5, 14 + radius * 2, 0.35)
	if radius > 0 then
		-- The ground freezes: a frost disc and a ring of spikes erupting
		-- from it, angled outward, that shatter a moment later.
		local floor = floorBelow(at)
		-- A sheet of frost (ice, not light) spreading over the ground.
		local frost = disc(floor + Vector3.new(0, 0.05, 0), 1, Color3.fromRGB(170, 215, 245), 0.55)
		frost.Material = Enum.Material.Ice
		move(frost, 0.25, { Size = Vector3.new(0.08, radius * 2, radius * 2) })
		local rim = disc(floor + Vector3.new(0, 0.07, 0), 1, ICE, 0.5)
		fade(rim, 0.45, { Size = Vector3.new(0.04, radius * 2.3, radius * 2.3) })
		task.delay(0.6, function()
			fade(frost, 0.5)
		end)
		local count = math.clamp(math.floor(radius * 1.6), 6, 18)
		for i = 1, count do
			local angle = i / count * math.pi * 2 + math.random() * 0.3
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local reach = radius * (0.55 + (i % 2) * 0.35)
			task.delay(reach / radius * 0.18, function()
				iceSpike(
					floor + out * reach,
					(out * 0.45 + Vector3.new(0, 1, 0)).Unit,
					1.6 + math.random() * 1.6,
					0.45,
					0.5
				)
			end)
		end
	end
end

function LAND.Shock(at: Vector3, radius: number)
	local color = ELEMENT_COLORS.Shock
	local big = 1 + radius / 8
	local ball = neon(Vector3.one * 0.6, CFrame.new(at), WHITE, 0, Enum.PartType.Ball)
	fade(ball, 0.16, { Size = Vector3.one * 2.6 * big, Color = color })
	-- Arcs crawling out from the strike.
	for _ = 1, math.floor(3 * big) do
		local out = jitter(1) + Vector3.new(0, -0.15, 0)
		if out.Magnitude > 0.05 then
			CombatVfx.lightning(at, at + out.Unit * (2.5 + math.random() * 2.5) * big, color)
		end
	end
	CombatFx.burst(at, color, "Sparks", 1.6 * big)
	CombatFx.flash(at, WHITE, 8, 18 + radius * 2, 0.25)
	if radius > 0 then
		-- Bolts out of the sky across the area, one after another.
		local floor = floorBelow(at)
		for i = 1, math.clamp(math.floor(radius * 0.5), 3, 6) do
			task.delay(0.03 + i * 0.05, function()
				local angle, reach = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
				local spot = floor + Vector3.new(math.cos(angle) * reach, 0.2, math.sin(angle) * reach)
				CombatVfx.lightning(
					spot + Vector3.new((math.random() - 0.5) * 4, 22, (math.random() - 0.5) * 4),
					spot,
					color
				)
				local scorch = disc(spot + Vector3.new(0, 0.04, 0), 1.6, WHITE, 0.1)
				fade(scorch, 0.35, { Size = Vector3.new(0.05, 3.2, 3.2), Color = color })
			end)
		end
		local wave = disc(floor + Vector3.new(0, 0.08, 0), 1, color:Lerp(WHITE, 0.4), 0.5)
		fade(wave, 0.35, { Size = Vector3.new(0.04, radius * 2.2, radius * 2.2) })
	end
end

function LAND.Poison(at: Vector3, radius: number)
	local color = ELEMENT_COLORS.Poison
	local big = 1 + radius / 8
	local glob = neon(Vector3.one * 1, CFrame.new(at), ACID_LIGHT, 0.1, Enum.PartType.Ball)
	fade(glob, 0.3, { Size = Vector3.one * 3.2 * big, Color = color }, Enum.EasingStyle.Sine)
	acidSplash(at, math.floor(12 * big), 3 * big)
	CombatFx.burst(at, color, "Smoke", 1.1 * big)
	CombatFx.burst(at, color, "Drips", 1 * big)
	CombatFx.flash(at, color, 4, 14 + radius * 2, 0.4)
	-- A pool of acid spreading where it lands, bubbling, then drying up.
	local floor = floorBelow(at)
	local size = if radius > 0 then radius * 2 else 4
	local pool = disc(floor + Vector3.new(0, 0.05, 0), 1, color:Lerp(Color3.new(0, 0, 0), 0.35), 0.55)
	move(pool, 0.4, { Size = Vector3.new(0.08, size, size) }, Enum.EasingStyle.Sine)
	local sheen = disc(floor + Vector3.new(0, 0.07, 0), 1, ACID_LIGHT, 0.88)
	move(sheen, 0.5, { Size = Vector3.new(0.06, size * 0.7, size * 0.7) }, Enum.EasingStyle.Sine)
	if not busy() then
		for i = 1, math.floor(6 * big) do
			task.delay(0.15 + i * 0.09, function()
				local angle, reach = math.random() * math.pi * 2, math.sqrt(math.random()) * size * 0.45
				local spot = floor + Vector3.new(math.cos(angle) * reach, 0.1, math.sin(angle) * reach)
				local bubble = neon(Vector3.one * 0.25, CFrame.new(spot), ACID_LIGHT, 0.2, Enum.PartType.Ball)
				fade(
					bubble,
					0.4,
					{ Size = Vector3.one * 0.8, CFrame = CFrame.new(spot + Vector3.new(0, 0.5, 0)) },
					Enum.EasingStyle.Sine
				)
			end)
		end
	end
	task.delay(0.9, function()
		fade(pool, 0.9)
		fade(sheen, 0.6)
	end)
end

-- Flights -------------------------------------------------------------------

local function travelTime(distance: number, speed: number): number
	return math.clamp(distance / speed, 0.06, 0.32)
end

local FLY = {}

function FLY.Fire(from: Vector3, to: Vector3, landed: () -> ())
	local distance = (to - from).Magnitude
	local travel = travelTime(distance, 110)
	local head = neon(Vector3.one * 1.5, CFrame.new(from), ELEMENT_COLORS.Fire, 0.15, Enum.PartType.Ball)
	local core = neon(Vector3.one * 0.8, CFrame.new(from), HOT, 0, Enum.PartType.Ball)
	-- A streaming tail of flame, white-hot at the head and burning down.
	ribbon(head, 1.3, HOT, EMBER, 0.2)
	move(head, travel, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	move(core, travel, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	-- Embers shed from the tail, drifting up as they burn out.
	local puffs = math.clamp(math.floor(distance / 4), 2, 8)
	for i = 1, puffs do
		local t = (i - 0.5) / puffs
		task.delay(travel * t, function()
			CombatFx.burst(from:Lerp(to, t), ELEMENT_COLORS.Fire, "Embers", 0.45)
		end)
	end
	CombatFx.burst(from, ELEMENT_COLORS.Fire, "Embers", 0.6)
	task.delay(travel, function()
		retire(head, 0.2)
		core:Destroy()
		landed()
	end)
end

function FLY.Frost(from: Vector3, to: Vector3, landed: () -> ())
	local distance = (to - from).Magnitude
	local travel = travelTime(distance, 130)
	local facing = CFrame.lookAt(from, to)
	local arrive = CFrame.lookAt(to, to + (to - from).Unit)
	local lance = Instance.new("Part")
	lance.Name = "Vfx"
	lance.Anchored, lance.CanCollide, lance.CanQuery, lance.CanTouch, lance.CastShadow =
		true, false, false, false, false
	lance.Material = Enum.Material.Glass
	lance.Color, lance.Transparency, lance.Reflectance = ICE, 0.1, 0.4
	lance.Size = Vector3.new(0.4, 0.4, 2.8)
	lance.CFrame = facing
	lance.Parent = fxFolder()
	local glow = neon(Vector3.new(0.16, 0.16, 3.2), facing, WHITE, 0)
	ribbon(glow, 0.55, WHITE, ICE, 0.25)
	move(lance, travel, { CFrame = arrive }, Enum.EasingStyle.Linear)
	move(glow, travel, { CFrame = arrive }, Enum.EasingStyle.Linear)
	-- A wake of frost mist and glittering crystals hanging in the air.
	local steps = math.clamp(math.floor(distance / 2.5), 3, 12)
	for i = 1, steps do
		local t = (i - 0.5) / steps
		task.delay(travel * t, function()
			local at = from:Lerp(to, t)
			-- A wisp of cold mist and frost glitter in its wake.
			CombatFx.burst(at, ICE, "Smoke", 0.35)
			CombatFx.burst(at, ICE, "Frost", 0.3)
			if i % 2 == 0 then
				local crystal = neon(
					Vector3.one * 0.18,
					CFrame.new(at + jitter(0.9)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
					WHITE,
					0
				)
				crystal.Material = Enum.Material.Glass
				fade(crystal, 0.6, {
					CFrame = crystal.CFrame * CFrame.Angles(2, 1, 0) - Vector3.new(0, 0.6, 0),
				}, Enum.EasingStyle.Sine)
			end
		end)
	end
	task.delay(travel, function()
		lance:Destroy()
		retire(glow, 0.25)
		landed()
	end)
end

function FLY.Shock(from: Vector3, to: Vector3, landed: () -> ())
	local color = ELEMENT_COLORS.Shock
	-- A thick bolt, flickering three times, with a glow along it.
	CombatVfx.lightning(from, to, color)
	local distance = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local glow = neon(Vector3.new(1, 1, distance), cf, color, 0.7)
	fade(glow, 0.3, { Size = Vector3.new(0.1, 0.1, distance) })
	CombatFx.burst(from, color, "Sparks", 0.7)
	landed()
end

function FLY.Poison(from: Vector3, to: Vector3, landed: () -> ())
	local color = ELEMENT_COLORS.Poison
	local distance = (to - from).Magnitude
	local travel = math.clamp(distance / 70, 0.12, 0.45)
	local height = math.clamp(distance * 0.18, 0.8, 6)
	local glob = neon(Vector3.one * 1.5, CFrame.new(from), color, 0.1, Enum.PartType.Ball)
	local core = neon(Vector3.one * 0.75, CFrame.new(from), ACID_LIGHT, 0, Enum.PartType.Ball)
	ribbon(core, 0.7, ACID_LIGHT, color, 0.18)
	-- Lobbed in an arc, wobbling, dripping as it goes.
	local started = os.clock()
	local lastDrip = 0
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min(1, (os.clock() - started) / travel)
		local at = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		local wobble = 1 + math.sin(t * 40) * 0.12
		glob.CFrame, core.CFrame = CFrame.new(at), CFrame.new(at)
		glob.Size = Vector3.new(1.5 * wobble, 1.5 / wobble, 1.5 * wobble)
		if t - lastDrip > 0.12 then
			lastDrip = t
			local drop = neon(Vector3.one * 0.22, CFrame.new(at), color, 0.1, Enum.PartType.Ball)
			fade(
				drop,
				0.35,
				{ CFrame = CFrame.new(at - Vector3.new(0, 1.8, 0)), Size = Vector3.new(0.12, 0.4, 0.12) },
				Enum.EasingStyle.Quad
			)
		end
		if t >= 1 then
			connection:Disconnect()
			glob:Destroy()
			retire(core, 0.18)
			landed()
		end
	end)
end

-- A surge's flight and landing in its element's style. Returns false for a
-- colour that isn't an element (the plain beam is drawn instead).
function CombatVfx.surge(from: Vector3, to: Vector3, element: string?, radius: number?): boolean
	local land = element and LAND[element]
	if not land then
		return false
	end
	local size = radius or 0
	if (to - from).Magnitude < 1.5 then
		land(to, size)
	else
		FLY[element](from, to, function()
			land(to, size)
		end)
	end
	return true
end

-- Aura (buffs, shields) ---------------------------------------------------------------

function CombatVfx.aura(root: BasePart, color: Color3)
	local base = root.CFrame.Position - Vector3.new(0, 2.6, 0)
	local floorRing = neon(
		Vector3.new(0.1, 1, 1),
		CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.55,
		Enum.PartType.Cylinder
	)
	fade(floorRing, 0.5, { Size = Vector3.new(0.05, 8, 8) })
	-- A soft column of light (a cylinder stood on end).
	local column = neon(
		Vector3.new(7, 3.2, 3.2),
		CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.9,
		Enum.PartType.Cylinder
	)
	fade(column, 0.5, { Size = Vector3.new(9, 0.4, 0.4) })
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
	-- The element wraps the body its own way.
	local element = GemConfig.elementOfColor(color)
	local centre = root.CFrame.Position
	if element == "Fire" then
		-- Flames spiralling up around you.
		for i = 1, 12 do
			task.delay(i * 0.03, function()
				local angle = i * 0.9
				flamePuff(
					base + Vector3.new(math.cos(angle) * 1.7, 0.6 + i * 0.35, math.sin(angle) * 1.7),
					0.9,
					1.4,
					0.4
				)
			end)
		end
	elseif element == "Frost" then
		-- A shell of ice panels forms around you, then shatters off.
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local at = CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2)
			local panel = neon(Vector3.new(1.4, 0.2, 0.08), at * CFrame.new(0, -2, 0), ICE, 0.3)
			panel.Material = Enum.Material.Glass
			panel.Reflectance = 0.3
			move(panel, 0.18, { Size = Vector3.new(1.5, 4.6, 0.12), CFrame = at }, Enum.EasingStyle.Back)
			task.delay(0.45, function()
				fade(panel, 0.3, { CFrame = at * CFrame.new(0, -0.6, -1.6) * CFrame.Angles(0.6, 0, 0) })
				iceChips(at.Position, 3, 2)
			end)
		end
	elseif element == "Shock" then
		-- Arcs snapping around you.
		for i = 0, 5 do
			task.delay(i * 0.07, function()
				local a = math.random() * math.pi * 2
				local b = a + 1.5 + math.random()
				local y1, y2 = (math.random() - 0.3) * 4, (math.random() - 0.3) * 4
				CombatVfx.lightning(
					centre + Vector3.new(math.cos(a) * 1.8, y1, math.sin(a) * 1.8),
					centre + Vector3.new(math.cos(b) * 1.8, y2, math.sin(b) * 1.8),
					ELEMENT_COLORS.Shock
				)
			end)
		end
	elseif element == "Poison" then
		-- Bubbles welling up out of a pool at your feet.
		local pool = disc(base + Vector3.new(0, 0.05, 0), 1, ELEMENT_COLORS.Poison, 0.35)
		move(pool, 0.3, { Size = Vector3.new(0.08, 6, 6) }, Enum.EasingStyle.Sine)
		task.delay(0.6, function()
			fade(pool, 0.6)
		end)
		for i = 1, 10 do
			task.delay(i * 0.05, function()
				local angle = math.random() * math.pi * 2
				local at = base + Vector3.new(math.cos(angle) * 1.6, 0.3, math.sin(angle) * 1.6)
				local bubble = neon(Vector3.one * 0.3, CFrame.new(at), ACID_LIGHT, 0.2, Enum.PartType.Ball)
				fade(bubble, 0.55, {
					Size = Vector3.one * 0.7,
					CFrame = CFrame.new(at + Vector3.new(0, 2.5 + math.random() * 2, 0)),
				}, Enum.EasingStyle.Sine)
			end)
		end
	end
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
