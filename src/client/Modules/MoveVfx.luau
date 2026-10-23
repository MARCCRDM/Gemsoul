--[[
	MoveVfx: each starter move's own look (client only; nothing replicates).
	The server names the show (GemTraits Show = "...") and where it happens;
	this draws it big enough to read across the arena, with a hit you feel:
	a flash, a shockwave, a shake when it's close, and its sound.

	  show(who, name, ...)   the move landing (and its pieces: a leap's jump,
	                         a flask's flight, a storm's warnings and bolts)
	  cast(who, id, seconds) what gathers while it's cast (a bolt onto your
	                         raised blade, a charging cannon, a sun in your hand)

	  FIRE   Meteor Leap, Flame Tornado, Magma Fault, Supernova
	  CRYO   Frost Chakram, Hailstorm, Permafrost Spire, Absolute Zero
	  ION    Thunder Dash, Skybreaker, Storm Call, Ion Cannon
	  ACID   Viper Lash, Toxic Flask, Toxic Tide, Maneater

	Built from neon, glass and ice parts, particles and lights, tweened and
	cleaned up after themselves, capped so a crowded fight stays smooth.

	A kaiju casting one (FxSize: "Sized" from the server) gets it at its own
	size: the server shrinks where it lands, and here its columns, flames,
	debris, particles, lights and shake shrink with it.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)
local FxSize = require(script.Parent.FxSize)
local CombatVfx = require(script.Parent.CombatVfx)

local MoveVfx = {}

local UP = Vector3.new(0, 1, 0)
local WHITE = Color3.new(1, 1, 1)
-- Fire
local HOT = Color3.fromRGB(255, 236, 170)
local FLAME = Color3.fromRGB(255, 150, 40)
local EMBER = Color3.fromRGB(255, 84, 20)
local MAGMA = Color3.fromRGB(255, 60, 10)
local CHAR = Color3.fromRGB(44, 26, 20)
local ROCK = Color3.fromRGB(70, 52, 44)
-- Cryo
local ICE = Color3.fromRGB(214, 242, 255)
local DEEP_ICE = Color3.fromRGB(110, 196, 255)
local FROST = Color3.fromRGB(160, 225, 255)
local SLATE = Color3.fromRGB(70, 84, 104)
-- Ion
local VOLT = Color3.fromRGB(255, 236, 90)
local ARC = Color3.fromRGB(150, 225, 255)
local STORM = Color3.fromRGB(46, 44, 70)
-- Acid (bright, never murky)
local LIME = Color3.fromRGB(150, 255, 70)
local TOXIC = Color3.fromRGB(95, 230, 60)
local FOAM = Color3.fromRGB(225, 255, 170)
local VENOM = Color3.fromRGB(60, 160, 40)
local FLESH = Color3.fromRGB(200, 48, 78)

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- Parts and helpers -------------------------------------------------------------------

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "MoveVfx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end
-- Too much on screen already: the extras (debris, sparks) are skipped.
local function busy(): boolean
	return #fxFolder():GetChildren() > 500
end
MoveVfx._folder = fxFolder

local function part(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number?,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = "Vfx"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.CFrame = cframe
	p.Parent = fxFolder()
	return p
end
-- A stretched sphere (a Ball part is always round; a sphere mesh stretches
-- with the part): clouds, splashes, the flytrap's jaws.
local function ellipsoid(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number?,
	material: Enum.Material?
): Part
	local p = part(size, cframe, color, transparency, nil, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local function glass(size: Vector3, cframe: CFrame, color: Color3, transparency: number?): Part
	local p = part(size, cframe, color, transparency or 0.25, nil, Enum.Material.Glass)
	p.Reflectance = 0.25
	return p
end
local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end
local function fade(p: BasePart, seconds: number, goal: { [string]: any }?, style: Enum.EasingStyle?)
	if not p.Parent then
		return
	end
	local target = goal or {}
	target.Transparency = 1
	tween(p, seconds, target, style)
	Debris:AddItem(p, seconds + 0.05)
end
local function later(seconds: number, fn: () -> ())
	task.delay(seconds, FxSize.keep(fn))
end
-- A flat disc lying on the ground (a cylinder stood on its side).
local FLAT = CFrame.Angles(0, 0, math.rad(90))
local function disc(at: Vector3, diameter: number, color: Color3, transparency: number?, material: Enum.Material?): Part
	return part(
		Vector3.new(0.08, diameter, diameter),
		CFrame.new(at) * FLAT,
		color,
		transparency,
		Enum.PartType.Cylinder,
		material
	)
end
-- A shockwave: a ring on the ground that races out and fades.
local function shockwave(at: Vector3, from: number, to: number, color: Color3, seconds: number, transparency: number?)
	local r = disc(at, from, color, transparency or 0.15)
	fade(r, seconds, { Size = Vector3.new(0.04, to, to) })
	return r
end
local function rootOf(who: any): BasePart?
	if typeof(who) == "Instance" then
		if who:IsA("BasePart") then
			return who
		end
		local character = if who:IsA("Player") then who.Character else who
		return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.RespectCanCollide = true
local function floorUnder(at: Vector3): Vector3
	local skip: { Instance } = { fxFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	for _, name in { "Enemies", "TriadVfx", "CombatFx", "CombatVfx" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	floorParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), floorParams)
	return if hit then hit.Position + Vector3.new(0, 0.05, 0) else at - Vector3.new(0, 2.9, 0)
end
local function light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, math.min(range * FxSize.get(), 60), false
	l.Parent = parent
	return l
end
local function emitter(parent: Instance, color: Color3, rate: number, o: { [string]: any }?): ParticleEmitter
	local opts = o or {}
	local k = FxSize.get()
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.Texture or SPARK_TEXTURE
	e.Color = ColorSequence.new(opts.From or color:Lerp(WHITE, 0.4), color)
	e.LightEmission = opts.Light or 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, (opts.Size or 0.4) * k),
		NumberSequenceKeypoint.new(1, (opts.EndSize or 0) * k),
	})
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Alpha or 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.Life or 0.5, (opts.Life or 0.5) * 1.5)
	e.Speed = NumberRange.new((opts.Speed or 2) * k, (opts.Speed or 2) * 1.8 * k)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Acceleration = (opts.Acceleration or Vector3.new(0, 2, 0)) * k
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Drag = opts.Drag or 0
	e.Rate = rate
	if opts.Direction then
		e.EmissionDirection = opts.Direction
	end
	if opts.Shape then
		e.Shape = opts.Shape
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	e.Parent = parent
	return e
end
local function attach(p: BasePart): Attachment
	local a = Instance.new("Attachment")
	a.Parent = p
	return a
end
-- Shakes your camera when it happens close to you (a creature's only close
-- to it, fading with the distance).
local function rumble(at: Vector3, strength: number, seconds: number, within: number?)
	if FxSize.get() ~= 1 then
		CombatFx.shakeNear(at, strength, seconds, within or 34)
	elseif CombatFx.nearMe(at, within or 34) then
		CombatFx.shake(strength, seconds)
	end
end
-- Runs `step(alpha, elapsed)` every frame for `seconds`, then `done()`
-- (at the size it was started at).
local function animate(seconds: number, step: (number, number) -> (), done: (() -> ())?)
	step = FxSize.keep(step)
	done = if done then FxSize.keep(done) else nil
	local born = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - born
		local alpha = math.clamp(elapsed / math.max(seconds, 0.01), 0, 1)
		local ok = pcall(step, alpha, elapsed)
		if alpha >= 1 or not ok then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end
-- Debris that flies on its own (client physics, no collisions).
local function chunk(
	at: Vector3,
	size: Vector3,
	color: Color3,
	velocity: Vector3,
	material: Enum.Material?,
	life: number?
)
	if busy() then
		return
	end
	-- (A creature's: smaller bits, thrown as far out for its size.)
	local k = FxSize.get()
	size *= k
	velocity *= math.sqrt(k)
	local c = part(
		size,
		CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		color,
		0,
		nil,
		material or Enum.Material.Slate
	)
	c.Anchored = false
	c.AssemblyLinearVelocity = velocity
	c.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
	Debris:AddItem(c, life or 1.2)
	later((life or 1.2) - 0.3, function()
		if c.Parent then
			tween(c, 0.25, { Transparency = 1 })
		end
	end)
end
local function outward(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end
-- A bolt of lightning (CombatVfx's jagged bolt) plus a white-hot core.
local function strike(from: Vector3, to: Vector3, color: Color3, core: number?)
	CombatVfx.lightning(from, to, color)
	local length = (to - from).Magnitude
	if length > 0.5 and (core or 0) > 0 then
		local width = (core :: number) * FxSize.get()
		local beam = part(Vector3.new(width, width, length), CFrame.lookAt((from + to) / 2, to), WHITE, 0.05)
		light(beam, color, 6, 30)
		fade(beam, 0.22, { Size = Vector3.new(0.05, 0.05, length) })
	end
end
local function flash(at: Vector3, color: Color3, brightness: number, range: number, seconds: number?)
	CombatFx.flash(at, color, brightness, range, seconds or 0.3)
end

-- Spectacle --------------------------------------------------------------------------
-- The pieces every big moment is built from (TriadVfx's R moves use them
-- too, as MoveVfx.fx): spokes of light, glowing motes, a column of light,
-- dust rolling out, a halo, what lingers on the ground, afterimages.

-- Spokes of light bursting from a point. Flat: along the ground; else up
-- and out in every direction.
local function rays(at: Vector3, color: Color3, count: number, length: number, seconds: number, flat: boolean?)
	if busy() then
		return
	end
	local k = FxSize.get()
	for i = 1, count do
		local angle = i / count * math.pi * 2 + math.random() * 0.35
		local dir = if flat
			then outward(angle)
			else (outward(angle) * (0.5 + math.random() * 0.5) + UP * math.random() * 0.9).Unit
		local reach = length * (0.6 + math.random() * 0.6) * k
		local ray = part(Vector3.new(0.3, 0.3, 0.6) * k, CFrame.lookAt(at, at + dir), color, 0.1)
		fade(ray, seconds, {
			Size = Vector3.new(0.05, 0.05, reach),
			CFrame = CFrame.lookAt(at + dir * reach / 2, at + dir * reach),
		})
	end
end
-- Glowing motes thrown out of a point, falling under their own weight
-- (embers, sparks, drops, shards of ice).
local function motes(at: Vector3, color: Color3, count: number, speed: number, lift: number, size: number, life: number?)
	if busy() then
		return
	end
	local k = FxSize.get()
	local stay = life or 1
	for _ = 1, count do
		local angle = math.random() * math.pi * 2
		local m = part(
			Vector3.one * size * (0.6 + math.random() * 0.8) * k,
			CFrame.new(at),
			if math.random() < 0.35 then color:Lerp(WHITE, 0.5) else color,
			0,
			Enum.PartType.Ball
		)
		m.Anchored = false
		m.AssemblyLinearVelocity = (outward(angle) * speed * (0.4 + math.random() * 0.8) + UP * lift * (0.6 + math.random() * 0.8))
			* math.sqrt(k)
		m.AssemblyAngularVelocity = Vector3.zero
		Debris:AddItem(m, stay)
		later(stay - 0.25, function()
			if m.Parent then
				tween(m, 0.25, { Transparency = 1, Size = Vector3.one * 0.05 })
			end
		end)
	end
end
-- A column of light that shoots up from a point, then thins away.
local function column(at: Vector3, color: Color3, radius: number, height: number, seconds: number)
	local k = FxSize.get()
	local beam = part(Vector3.new(0.5, radius * 2, radius * 2) * k, CFrame.new(at) * FLAT, color, 0.25, Enum.PartType.Cylinder)
	tween(beam, 0.12, {
		Size = Vector3.new(height, radius * 2, radius * 2) * k,
		CFrame = CFrame.new(at + UP * height * k / 2) * FLAT,
	}, Enum.EasingStyle.Quart)
	local core = part(Vector3.new(0.5, radius * 0.7, radius * 0.7) * k, CFrame.new(at) * FLAT, WHITE, 0.05, Enum.PartType.Cylinder)
	tween(core, 0.1, {
		Size = Vector3.new(height, radius * 0.7, radius * 0.7) * k,
		CFrame = CFrame.new(at + UP * height * k / 2) * FLAT,
	}, Enum.EasingStyle.Quart)
	light(core, color, 8, 30)
	later(0.14, function()
		fade(beam, seconds, { Size = Vector3.new(height, 0.3, 0.3) * k })
		fade(core, seconds * 0.7, { Size = Vector3.new(height, 0.1, 0.1) * k })
	end)
	return beam, core
end
-- Dust (or smoke, or mist) rolling out along the ground.
local function dust(at: Vector3, color: Color3, radius: number, seconds: number, count: number?)
	if busy() then
		return
	end
	local k = FxSize.get()
	local n = count or 10
	for i = 1, n do
		local angle = i / n * math.pi * 2 + math.random() * 0.4
		local s = (1.2 + math.random()) * k
		local puff = ellipsoid(Vector3.new(s, s * 0.7, s), CFrame.new(at + UP * s * 0.3), color, 0.35, Enum.Material.SmoothPlastic)
		fade(puff, seconds, {
			CFrame = CFrame.new(at + outward(angle) * radius * k + UP * s * 0.6),
			Size = Vector3.new(s * 2.4, s * 1.4, s * 2.4),
		}, Enum.EasingStyle.Quart)
	end
end
-- A ring that swells and fades: flat on the ground, or stood up to face
-- `look` (a thunderclap, a splash, a muzzle ring).
local function halo(at: Vector3, color: Color3, from: number, to: number, seconds: number, look: Vector3?, transparency: number?)
	local k = FxSize.get()
	local frame = if look and look.Magnitude > 0.01
		then CFrame.lookAt(at, at + look) * CFrame.Angles(0, math.rad(90), 0)
		else CFrame.new(at) * FLAT
	local ring = part(Vector3.new(0.15, from, from) * k, frame, color, transparency or 0.15, Enum.PartType.Cylinder)
	fade(ring, seconds, { Size = Vector3.new(0.05, to, to) * k })
	return ring
end
-- What a big hit leaves on the ground for a while: a glowing plate that
-- pulses, lit, with motes of the element drifting up off it.
local function linger(at: Vector3, color: Color3, radius: number, seconds: number, texture: string?, glow: Color3?)
	local k = FxSize.get()
	local plate = disc(at + UP * 0.05, radius * 2 * k, color, 0.45)
	light(plate, glow or color, 3, radius * 3)
	local pulse = TweenService:Create(
		plate,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.72 }
	)
	pulse:Play()
	if not busy() then
		emitter(attach(plate), color, 16, {
			Texture = texture or SPARK_TEXTURE,
			Size = 0.5,
			Speed = 2,
			Life = 0.9,
			Spread = 25,
			Acceleration = Vector3.new(0, 4, 0),
			Shape = Enum.ParticleEmitterShape.Box,
			Direction = Enum.NormalId.Right,
		})
	end
	later(seconds, function()
		pulse:Cancel()
		fade(plate, 0.6)
	end)
	return plate
end
-- Afterimages of a body left along a line (a dash, a blink).
local function ghosts(from: Vector3, to: Vector3, color: Color3, count: number, seconds: number?)
	if busy() then
		return
	end
	local k = FxSize.get()
	local dir = to - from
	if dir.Magnitude < 0.5 then
		return
	end
	for i = 1, count do
		local at = from:Lerp(to, i / (count + 1))
		local frame = CFrame.lookAt(at, at + dir)
		local body = part(Vector3.new(2, 2.2, 1) * k, frame, color, 0.35, nil, Enum.Material.ForceField)
		local head = part(Vector3.new(1.2, 1.2, 1.2) * k, frame * CFrame.new(0, 1.7 * k, 0), color, 0.35, nil, Enum.Material.ForceField)
		local legs = part(Vector3.new(1.9, 1.8, 0.9) * k, frame * CFrame.new(0, -2 * k, 0), color, 0.4, nil, Enum.Material.ForceField)
		later(i * 0.03, function()
			for _, g in { body, head, legs } do
				fade(g, seconds or 0.3)
			end
		end)
	end
end
MoveVfx.fx = { rays = rays, motes = motes, column = column, dust = dust, halo = halo, linger = linger, ghosts = ghosts }

-- FIRE ---------------------------------------------------------------------------------

local SHOW: { [string]: (any, ...any) -> () } = {}

-- Meteor Leap, the jump: fire bursts from your feet and you streak like a
-- comet, a tail of fire hanging in the air behind you.
SHOW.MeteorLeapJump = function(who, from: Vector3, to: Vector3, seconds: number)
	local a = floorUnder(from)
	CombatFx.burst(a + Vector3.new(0, 0.6, 0), EMBER, "Embers", 1.6)
	CombatFx.burst(a + Vector3.new(0, 0.4, 0), Color3.fromRGB(150, 120, 100), "Smoke", 1.1)
	shockwave(a, 3, 9, HOT, 0.35)
	rays(a + UP * 0.3, HOT, 10, 5, 0.3, true)
	dust(a, Color3.fromRGB(120, 100, 90), 4, 0.6, 8)
	motes(a + UP * 0.5, EMBER, 10, 8, 18, 0.3, 0.9)
	flash(a + UP * 2, EMBER, 6, 18, 0.25)
	-- Where it will land, burning brighter as you fall.
	local b = floorUnder(to)
	local mark = disc(b + Vector3.new(0, 0.07, 0), 1.5, EMBER, 0.55)
	tween(mark, seconds, { Size = Vector3.new(0.08, 10, 10), Transparency = 0.25 }, Enum.EasingStyle.Linear)
	local sight = disc(b + Vector3.new(0, 0.09, 0), 10, HOT, 0.7)
	tween(sight, seconds, { Size = Vector3.new(0.06, 2, 2), Transparency = 0.2 }, Enum.EasingStyle.Linear)
	later(seconds, function()
		fade(mark, 0.15)
		fade(sight, 0.1)
	end)
	local root = rootOf(who)
	if root then
		local comet = part(Vector3.one * 2.6, root.CFrame, FLAME, 0.45, Enum.PartType.Ball)
		local core = part(Vector3.one * 1.4, root.CFrame, HOT, 0.2, Enum.PartType.Ball)
		local a0 = attach(comet)
		emitter(
			a0,
			EMBER,
			70,
			{
				Texture = FIRE_TEXTURE,
				Size = 2.2,
				Speed = 1.5,
				Life = 0.45,
				Acceleration = Vector3.new(0, 6, 0),
				From = HOT,
			}
		)
		emitter(
			a0,
			Color3.fromRGB(90, 70, 60),
			20,
			{ Texture = SMOKE_TEXTURE, Size = 1.6, EndSize = 3, Speed = 1, Life = 0.7, Light = 0, Alpha = 0.5 }
		)
		light(core, EMBER, 6, 24)
		local lastTail = 0
		animate(seconds + 0.05, function(_alpha, elapsed)
			comet.CFrame = root.CFrame * CFrame.new(0, -0.4, 0.6)
			core.CFrame = root.CFrame * CFrame.new(0, -0.4, 0.3)
			-- The tail: a fireball left hanging every few frames, fading.
			if elapsed - lastTail > 0.045 and not busy() then
				lastTail = elapsed
				local puff = part(Vector3.one * 2, comet.CFrame * CFrame.new(0, 0, 0.8), if math.random() < 0.5 then FLAME else EMBER, 0.3, Enum.PartType.Ball)
				fade(puff, 0.35, { Size = Vector3.one * 0.6, CFrame = puff.CFrame + UP * 1.2 })
			end
		end, function()
			fade(comet, 0.2)
			fade(core, 0.2)
		end)
	end
	CombatSound.element("Cast", "Fire", from, { Volume = 0.9 })
	CombatSound.play("Roll", from, { Volume = 0.8, Pitch = 0.8 })
end

-- Meteor Leap, the landing: a white-hot crash, a column of fire up into the
-- sky, molten cracks racing out, rocks and embers thrown up, a ring of
-- fire blowing outward and dust rolling after it.
SHOW.MeteorLeap = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	rumble(floor, 1.1, 0.5, 44)
	flash(floor + UP * 2, EMBER, 12, radius * 4.5, 0.5)
	local dome = part(Vector3.one * 2, CFrame.new(floor), HOT, 0.05, Enum.PartType.Ball)
	fade(dome, 0.35, { Size = Vector3.one * radius * 2.1 })
	local shell = part(Vector3.one * 2, CFrame.new(floor), EMBER, 0.35, Enum.PartType.Ball)
	fade(shell, 0.55, { Size = Vector3.one * radius * 2.6 })
	column(floor, FLAME, 1.6, 22, 0.55)
	rays(floor + UP * 1.5, HOT, 18, radius * 1.6, 0.4)
	shockwave(floor + UP * 0.1, 2, radius * 2.2, HOT, 0.4, 0.05)
	shockwave(floor + UP * 0.2, 2, radius * 2.8, EMBER, 0.6, 0.3)
	later(0.12, function()
		shockwave(floor + UP * 0.15, 3, radius * 3.6, FLAME, 0.7, 0.45)
		dust(floor, Color3.fromRGB(110, 90, 80), radius * 1.4, 0.9, 12)
	end)
	-- A wall of flame rushing outward.
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2
		local tongue = part(
			Vector3.new(1, 2.2, 1.6),
			CFrame.new(floor + UP) * CFrame.Angles(0, -angle, 0),
			if i % 2 == 0 then FLAME else HOT,
			0.2
		)
		fade(
			tongue,
			0.45,
			{
				CFrame = CFrame.new(floor + outward(angle) * radius * 1.1 + UP * 1.6) * CFrame.Angles(0, -angle, 0),
				Size = Vector3.new(0.3, 3.6, 2.4),
			}
		)
	end
	-- Molten cracks.
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2 + math.random() * 0.4
		local length = radius * (0.6 + math.random() * 0.5)
		local base = CFrame.new(floor + UP * 0.06) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		local crack = part(Vector3.new(0.4, 0.08, 0.3), base, MAGMA, 0)
		tween(crack, 0.15, { Size = Vector3.new(0.45, 0.08, length), CFrame = base * CFrame.new(0, 0, -length / 2) })
		later(1.2, function()
			fade(crack, 0.8)
		end)
	end
	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		local s = 0.5 + math.random() * 0.8
		chunk(
			floor + UP * 0.8,
			Vector3.new(s, s * 0.8, s),
			if math.random() < 0.3 then MAGMA else ROCK,
			outward(angle) * (14 + math.random() * 16) + UP * (28 + math.random() * 22),
			if math.random() < 0.3 then Enum.Material.Neon else Enum.Material.Slate
		)
	end
	motes(floor + UP, EMBER, 18, 14, 26, 0.35, 1.2)
	CombatFx.burst(floor + UP, EMBER, "Embers", 2.6)
	CombatFx.burst(floor + UP * 0.5, Color3.fromRGB(110, 90, 80), "Smoke", 2.2)
	CombatSound.play("Blast", floor, { Volume = 1.2, Pitch = 0.8 })
	CombatSound.element("Impact", "Fire", floor, { Volume = 1 })
end

-- What a crash leaves: a scorched crater, lava glowing in its cracks, flames.
SHOW.Crater = function(_who, center: Vector3, radius: number, seconds: number)
	local floor = floorUnder(center)
	local scorch = disc(floor + UP * 0.03, radius * 2, CHAR, 0.05, Enum.Material.Slate)
	local glow = disc(floor + UP * 0.05, radius * 1.3, MAGMA, 0.45)
	local pulse = TweenService:Create(
		glow,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 }
	)
	pulse:Play()
	light(glow, EMBER, 2.5, radius * 3)
	local pieces = { scorch, glow }
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2 + math.random()
		local spot = part(
			Vector3.new(0.6, 0.2, 0.6),
			CFrame.new(floor + outward(angle) * radius * (0.3 + math.random() * 0.5)),
			MAGMA,
			0.3
		)
		if not busy() then
			emitter(
				attach(spot),
				FLAME,
				14,
				{
					Texture = FIRE_TEXTURE,
					Size = 1.3,
					Speed = 1,
					Life = 0.6,
					Acceleration = Vector3.new(0, 8, 0),
					Spread = 15,
					From = HOT,
				}
			)
		end
		table.insert(pieces, spot)
	end
	later(seconds, function()
		pulse:Cancel()
		for _, p in pieces do
			fade(p, 0.6)
		end
	end)
	CombatSound.play("Burn", floor, { Volume = 0.8 })
end

-- Flame Tornado: a spinning column of fire that tears across the ground, a
-- flare at its crown, rings of heat rolling up it and embers flung out.
SHOW.FlameTornado = function(_who, from: Vector3, to: Vector3, seconds: number, radius: number)
	local a, b = floorUnder(from), floorUnder(to)
	local k = FxSize.get()
	local rings, ribbons = {}, {}
	for i = 1, 7 do
		local d = radius * 0.7 + i * 0.55 * k
		local ring = part(
			Vector3.new(0.5 * k, d, d),
			CFrame.new(a),
			if i % 2 == 0 then FLAME else EMBER,
			0.55 + i * 0.03,
			Enum.PartType.Cylinder
		)
		table.insert(rings, { Part = ring, Height = i * 1.25 * k, Diameter = d })
	end
	local core = part(Vector3.new(9, 1.6, 1.6) * k, CFrame.new(a), HOT, 0.45, Enum.PartType.Cylinder)
	local crown = part(Vector3.one * 2.4 * k, CFrame.new(a), HOT, 0.25, Enum.PartType.Ball)
	light(crown, FLAME, 5, 24)
	for strand = 1, 3 do
		for n = 1, 9 do
			local flame = part(Vector3.new(0.7, 0.7, 1.6) * k, CFrame.new(a), if n % 2 == 0 then HOT else FLAME, 0.15)
			table.insert(ribbons, { Part = flame, Strand = strand, Step = n })
		end
	end
	local base =
		part(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(a) * FLAT, EMBER, 0.6, Enum.PartType.Cylinder)
	local feet = attach(base)
	emitter(
		feet,
		FLAME,
		60,
		{
			Texture = FIRE_TEXTURE,
			Size = 2.4,
			Speed = 3,
			Life = 0.6,
			Acceleration = Vector3.new(0, 18, 0),
			Spread = 35,
			From = HOT,
		}
	)
	emitter(
		feet,
		Color3.fromRGB(70, 60, 55),
		18,
		{
			Texture = SMOKE_TEXTURE,
			Size = 2.5,
			EndSize = 6,
			Speed = 6,
			Life = 1.1,
			Light = 0,
			Alpha = 0.5,
			Acceleration = Vector3.new(0, 10, 0),
			Spread = 20,
		}
	)
	light(core, EMBER, 6, 26)
	halo(a + UP * 0.2, HOT, 2 * k, radius * 3, 0.4)
	dust(a, Color3.fromRGB(90, 75, 70), radius * 1.2, 0.7, 8)
	local spin, last = 0, os.clock()
	local lastScorch, lastHalo, lastEmber = 0, 0, 0
	animate(seconds, function(alpha, elapsed)
		local now = os.clock()
		spin += (now - last) * 9
		last = now
		local at = a:Lerp(b, alpha)
		local sway = Vector3.new(math.sin(elapsed * 5) * 0.4, 0, math.cos(elapsed * 4) * 0.4) * k
		for _, r in rings do
			local lean = sway * r.Height / (6 * k)
			r.Part.CFrame = CFrame.new(at + UP * r.Height + lean)
				* CFrame.Angles(0, spin * (1 + r.Height * 0.05), 0)
				* FLAT
		end
		core.CFrame = CFrame.new(at + UP * 4.5 * k + sway * 0.5) * CFrame.Angles(0, spin, 0) * FLAT
		crown.CFrame = CFrame.new(at + UP * 9.4 * k + sway * 1.4)
		crown.Size = Vector3.one * (2.2 + math.sin(elapsed * 18) * 0.5) * k
		for _, f in ribbons do
			local h = f.Step * 0.95 * k
			local angle = spin * 1.3 + f.Strand * (math.pi * 2 / 3) + f.Step * 0.55
			local reachOut = radius * 0.45 + f.Step * 0.32 * k
			f.Part.CFrame = CFrame.lookAt(
				at + UP * h + outward(angle) * reachOut + sway * h / (6 * k),
				at + UP * (h + 0.5 * k) + outward(angle + 0.6) * reachOut
			)
		end
		base.CFrame = CFrame.new(at + UP * 0.1 * k) * FLAT
		if elapsed - lastScorch > 0.18 and not busy() then
			lastScorch = elapsed
			local mark = disc(at + UP * 0.03, radius * 1.4, CHAR, 0.3, Enum.Material.Slate)
			later(1.2, function()
				fade(mark, 0.8)
			end)
		end
		-- Rings of heat rolling up the column, embers flung from its skirt.
		if elapsed - lastHalo > 0.22 and not busy() then
			lastHalo = elapsed
			local ring = part(Vector3.new(0.3 * k, radius * 1.6, radius * 1.6), CFrame.new(at + UP * 0.5 * k) * FLAT, HOT, 0.3, Enum.PartType.Cylinder)
			fade(ring, 0.6, { Size = Vector3.new(0.1, radius * 3.4, radius * 3.4) * k, CFrame = CFrame.new(at + UP * 10 * k) * FLAT })
		end
		if elapsed - lastEmber > 0.12 then
			lastEmber = elapsed
			motes(at + UP * (1 + math.random() * 5) * k, EMBER, 2, 12, 6, 0.3, 0.8)
		end
	end, function()
		for _, r in rings do
			fade(r.Part, 0.25)
		end
		for _, f in ribbons do
			fade(f.Part, 0.25)
		end
		fade(core, 0.25)
		fade(crown, 0.25)
		fade(base, 0.25)
	end)
	CombatSound.play("Burn", a, { Volume = 1.1, Pitch = 0.7 })
	CombatSound.element("Cast", "Fire", a, { Volume = 1 })
end

-- Where a tornado (or anything spinning) blows apart: a fireball, a column
-- of flame, rays of heat and embers everywhere.
SHOW.VortexEnd = function(_who, at: Vector3, radius: number)
	local floor = floorUnder(at)
	rumble(floor, 0.8, 0.4, 36)
	flash(floor + UP * 3, EMBER, 10, radius * 4, 0.4)
	local ball = part(Vector3.one * 2, CFrame.new(floor + UP * 2), HOT, 0, Enum.PartType.Ball)
	fade(ball, 0.4, { Size = Vector3.one * radius * 2 })
	local outer = part(Vector3.one * 2, CFrame.new(floor + UP * 2), FLAME, 0.3, Enum.PartType.Ball)
	fade(outer, 0.55, { Size = Vector3.one * radius * 2.6 })
	column(floor, FLAME, 1.2, 16, 0.5)
	rays(floor + UP * 2, HOT, 14, radius * 1.5, 0.35)
	shockwave(floor + UP * 0.1, 2, radius * 2.6, FLAME, 0.45)
	later(0.1, function()
		shockwave(floor + UP * 0.15, 3, radius * 3.4, EMBER, 0.6, 0.4)
	end)
	dust(floor, Color3.fromRGB(100, 85, 80), radius * 1.3, 0.8, 10)
	motes(floor + UP * 2, EMBER, 16, 12, 20, 0.35, 1.1)
	linger(floor, EMBER, radius * 0.7, 1.4, FIRE_TEXTURE)
	CombatFx.burst(floor + UP * 2, EMBER, "Embers", 2.4)
	CombatFx.burst(floor + UP * 2, Color3.fromRGB(90, 80, 75), "Smoke", 2)
	CombatSound.play("Blast", floor, { Volume = 1.1 })
end

-- Magma Fault: the ground splits open along the line behind a white-hot
-- seam, spikes of rock and lava erupting one after another, and the far end
-- blows open in a geyser of magma.
SHOW.MagmaFault = function(_who, origin: Vector3, finish: Vector3, _width: number)
	local a, b = floorUnder(origin), floorUnder(finish)
	local line = (b - a) * Vector3.new(1, 0, 1)
	local length = math.max(2, line.Magnitude)
	local direction = if line.Magnitude > 0.1 then line.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local steps = math.max(4, math.floor(length / 1.4))
	local every = 0.022
	rumble(a, 0.7, 0.5, 30)
	-- The seam's head: a white-hot knot racing along the line.
	local head = part(Vector3.one * 1.2, CFrame.new(a + UP * 0.4), WHITE, 0, Enum.PartType.Ball)
	light(head, EMBER, 7, 20)
	animate(steps * every, function(alpha)
		head.CFrame = CFrame.new(a:Lerp(b, alpha) + UP * 0.4)
	end, function()
		fade(head, 0.2, { Size = Vector3.one * 3 })
	end)
	halo(a + UP * 0.2, HOT, 1, 6, 0.3)
	for i = 1, steps do
		later(i * every, function()
			local at = a:Lerp(b, i / steps)
			local fissure = part(
				Vector3.new(0.5, 0.1, length / steps * 1.3),
				CFrame.lookAt(at, at + direction) + UP * 0.05,
				MAGMA,
				0
			)
			later(1.2, function()
				fade(fissure, 0.7)
			end)
			local tall = 1.6 + math.random() * 2.2
			local offset = side * (math.random() - 0.5) * 1.6
			local spike = part(
				Vector3.new(0.9, 0.3, 0.9),
				CFrame.new(at + offset)
					* CFrame.Angles((math.random() - 0.5) * 0.7, math.random() * 6, (math.random() - 0.5) * 0.7),
				ROCK,
				0,
				nil,
				Enum.Material.Slate
			)
			tween(
				spike,
				0.1,
				{ Size = Vector3.new(0.9, tall, 0.9), CFrame = spike.CFrame * CFrame.new(0, tall / 2, 0) },
				Enum.EasingStyle.Back
			)
			local vein = part(Vector3.new(0.35, 0.2, 0.35), spike.CFrame, MAGMA, 0.1)
			tween(
				vein,
				0.1,
				{ Size = Vector3.new(0.35, tall * 0.9, 0.35), CFrame = spike.CFrame * CFrame.new(0, tall / 2, 0) },
				Enum.EasingStyle.Back
			)
			later(0.8 + math.random() * 0.2, function()
				fade(spike, 0.35, { Size = Vector3.new(0.6, 0.2, 0.6) })
				fade(vein, 0.35)
			end)
			if i % 2 == 0 then
				CombatFx.burst(at + UP, EMBER, "Embers", 0.9)
				motes(at + UP * 0.5, MAGMA, 3, 5, 16, 0.3, 0.8)
				chunk(
					at + UP,
					Vector3.one * 0.5,
					ROCK,
					side * (math.random() - 0.5) * 16 + UP * (18 + math.random() * 12)
				)
			end
		end)
	end
	-- The far end blows open.
	later(steps * every, function()
		flash(b + UP * 2, EMBER, 10, 24, 0.4)
		rumble(b, 0.8, 0.3, 30)
		column(b, MAGMA, 1.3, 11, 0.45)
		rays(b + UP, HOT, 12, 5, 0.35)
		shockwave(b + UP * 0.1, 1.5, 11, EMBER, 0.45, 0.2)
		dust(b, Color3.fromRGB(100, 80, 70), 4, 0.8, 8)
		motes(b + UP, MAGMA, 14, 10, 22, 0.4, 1.1)
		linger(b, MAGMA, 2.4, 1.6, FIRE_TEXTURE, EMBER)
		CombatSound.play("Blast", b, { Volume = 1, Pitch = 0.9 })
	end)
	flash(a:Lerp(b, 0.5) + UP * 2, EMBER, 6, length, 0.5)
	CombatSound.play("Blast", a, { Volume = 1, Pitch = 0.7 })
	CombatSound.element("Impact", "Fire", b, { Volume = 0.9 })
end

-- Supernova: the sun you gathered goes off — a white flash, rays to the
-- horizon, a fireball, a column of fire, halos and three shockwaves
-- rolling across the ground, and the ground left burning.
SHOW.Supernova = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	local k = FxSize.get()
	rumble(floor, 1.2, 0.6, 50)
	flash(floor + UP * 3 * k, HOT, 16, radius * 4.5, 0.6)
	local heart = CFrame.new(floor + UP * 2 * k)
	local core = part(Vector3.one * 3 * k, heart, WHITE, 0, Enum.PartType.Ball)
	fade(core, 0.35, { Size = Vector3.one * radius * 1.4 })
	local fireball = part(Vector3.one * 3 * k, heart, FLAME, 0.15, Enum.PartType.Ball)
	fade(fireball, 0.6, { Size = Vector3.one * radius * 2.1 })
	local halo2 = part(Vector3.one * 3 * k, heart, EMBER, 0.5, Enum.PartType.Ball)
	fade(halo2, 0.8, { Size = Vector3.one * radius * 2.6 })
	rays(floor + UP * 2 * k, HOT, 26, radius * 2.4, 0.5)
	-- Two halos stood up, crossing, like the sun's rings.
	halo(floor + UP * 2 * k, HOT, 2 * k, radius * 3.2, 0.55, Vector3.new(1, 0, 0), 0.25)
	halo(floor + UP * 2 * k, FLAME, 2 * k, radius * 3.2, 0.6, Vector3.new(0, 0, 1), 0.3)
	for n = 0, 2 do
		later(n * 0.12, function()
			shockwave(
				floor + UP * (0.1 + n * 0.05),
				3 * k,
				radius * (2.2 + n * 0.5),
				if n == 0 then HOT else FLAME,
				0.5 + n * 0.1,
				0.1 + n * 0.15
			)
		end)
	end
	column(floor, HOT, radius * 0.4, 28, 0.6)
	later(0.15, function()
		dust(floor, Color3.fromRGB(110, 95, 90), radius * 1.5, 1, 14)
	end)
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		chunk(
			floor + UP * k,
			Vector3.one * (0.4 + math.random() * 0.5),
			MAGMA,
			outward(angle) * (18 + math.random() * 18) + UP * (25 + math.random() * 20),
			Enum.Material.Neon
		)
	end
	motes(floor + UP * 2 * k, EMBER, 22, 16, 28, 0.4, 1.3)
	linger(floor, EMBER, radius * 0.8, 2.2, FIRE_TEXTURE)
	CombatFx.burst(floor + UP * 2 * k, EMBER, "Embers", 3)
	CombatFx.burst(floor + UP * 2 * k, Color3.fromRGB(110, 95, 90), "Smoke", 2.6)
	CombatSound.play("Blast", floor, { Volume = 1.3, Pitch = 0.75 })
	CombatSound.element("Impact", "Fire", floor, { Volume = 1.1 })
end

-- CRYO ---------------------------------------------------------------------------------

-- Frost Chakram: a spinning blade of ice flung out and back to your hand,
-- ghost blades hanging in the air behind it, a burst of shards where it
-- turns, and a frost ring where it comes home.
SHOW.FrostChakram = function(who, from: Vector3, far: Vector3, seconds: number, _radius: number)
	local lift = UP * 0.4
	local blade = glass(Vector3.new(0.3, 4.2, 4.2), CFrame.new(from), ICE, 0.15)
	blade.Shape = Enum.PartType.Cylinder
	local rim = part(Vector3.new(0.22, 4.7, 4.7), CFrame.new(from), DEEP_ICE, 0.3, Enum.PartType.Cylinder)
	local hub = part(Vector3.new(0.4, 1.3, 1.3), CFrame.new(from), WHITE, 0.05, Enum.PartType.Cylinder)
	local teeth = {}
	for i = 1, 6 do
		local tooth = glass(Vector3.new(0.25, 0.6, 1.7), CFrame.new(from), if i % 2 == 0 then ICE else FROST, 0.1)
		table.insert(teeth, tooth)
	end
	light(hub, DEEP_ICE, 5, 18)
	local trail = attach(rim)
	emitter(
		trail,
		FROST,
		60,
		{ Size = 0.5, Speed = 0.5, Life = 0.4, Acceleration = Vector3.new(0, -2, 0), From = WHITE }
	)
	halo(from + lift, ICE, 1, 6, 0.3, far - from, 0.3)
	flash(from + lift, DEEP_ICE, 5, 14, 0.2)
	local root = rootOf(who)
	local spin = 0
	local last = os.clock()
	local lastGhost, turned = 0, false
	animate(seconds, function(alpha, elapsed)
		local now = os.clock()
		spin += (now - last) * 22
		last = now
		local home = if root and root.Parent then root.Position else from
		local at = if alpha < 0.5
			then from:Lerp(far, math.sin(alpha * math.pi))
			else far:Lerp(home, 1 - math.sin(alpha * math.pi))
		local frame = CFrame.new(at + lift) * CFrame.Angles(0, spin, 0)
		blade.CFrame = frame * FLAT
		rim.CFrame = frame * FLAT
		hub.CFrame = frame * FLAT
		for i, tooth in teeth do
			local angle = i / #teeth * math.pi * 2
			tooth.CFrame = frame
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -2.5)
				* CFrame.Angles(0, math.rad(25), 0)
		end
		-- Ghost blades left hanging in the air behind it.
		if elapsed - lastGhost > 0.05 and not busy() then
			lastGhost = elapsed
			local ghost = part(Vector3.new(0.12, 4.4, 4.4), frame * FLAT, ICE, 0.5, Enum.PartType.Cylinder)
			fade(ghost, 0.35, { Size = Vector3.new(0.05, 3, 3) })
		end
		-- Where it turns: a burst of shards, a flash and frost on the ground.
		if alpha >= 0.5 and not turned then
			turned = true
			flash(far + lift, DEEP_ICE, 8, 20, 0.3)
			rays(far + lift, ICE, 12, 4, 0.3)
			motes(far + lift, ICE, 10, 9, 10, 0.25, 0.8)
			shockwave(floorUnder(far) + UP * 0.08, 1, 8, ICE, 0.35, 0.2)
			CombatFx.burst(far + lift, ICE, "Shards", 1.4)
			CombatSound.play("Freeze", far, { Volume = 0.8, Pitch = 1.3 })
		end
	end, function()
		for _, p in { blade, rim, hub, table.unpack(teeth) } do
			fade(p, 0.15)
		end
		if root and root.Parent then
			CombatFx.burst(root.Position + lift, FROST, "Frost", 0.8)
			halo(root.Position + lift, ICE, 1, 5, 0.3, root.CFrame.LookVector, 0.3)
		end
	end)
	CombatSound.play("Swing", from, { Volume = 0.9, Pitch = 1.3 })
	CombatSound.element("Cast", "Frost", from, { Volume = 0.8 })
end

-- Hailstorm: a cloud spreads over the area, wind whips round under it,
-- and hail hammers the ground, each stone leaving frost where it lands.
SHOW.Hailstorm = function(_who, center: Vector3, radius: number, seconds: number)
	local floor = floorUnder(center)
	local k = FxSize.get()
	local top = floor + UP * 13 * k
	local puffs = {}
	for i = 1, 11 do
		local angle = i / 11 * math.pi * 2
		local d = radius * (0.2 + math.random() * 0.6)
		local s = radius * (0.8 + math.random() * 0.5)
		local puff = ellipsoid(
			Vector3.new(s, s * 0.4, s),
			CFrame.new(top + outward(angle) * d + UP * (math.random() - 0.5) * k),
			if i % 2 == 0 then SLATE else Color3.fromRGB(120, 140, 170),
			1,
			Enum.Material.SmoothPlastic
		)
		tween(puff, 0.5, { Transparency = 0.15 })
		table.insert(puffs, puff)
	end
	-- Snow and sleet pouring out of the cloud's underside.
	local sheet = part(Vector3.new(radius * 1.8, 0.2, radius * 1.8), CFrame.new(top - UP * 1.5 * k), ICE, 1)
	emitter(
		attach(sheet),
		WHITE,
		110,
		{
			Size = 0.18,
			EndSize = 0.12,
			Speed = 40,
			Life = 0.4,
			Spread = 4,
			Acceleration = Vector3.zero,
			Direction = Enum.NormalId.Bottom,
			Shape = Enum.ParticleEmitterShape.Box,
			Light = 0.4,
		}
	)
	light(sheet, DEEP_ICE, 3, radius * 2.5)
	-- The cloud lit from inside now and then.
	local inner = part(Vector3.one * k, CFrame.new(top), WHITE, 1)
	local glow = light(inner, ICE, 0, radius * 3)
	local frost = disc(floor + UP * 0.04, 2 * k, FROST, 0.55, Enum.Material.Glass)
	tween(frost, 0.6, { Size = Vector3.new(0.08, radius * 2, radius * 2) })
	local rim = disc(floor + UP * 0.06, radius * 2, DEEP_ICE, 0.7)
	halo(floor + UP * 0.1, ICE, 2 * k, radius * 2.6, 0.5)
	-- Wind: arcs of frost whipping round under the cloud.
	local gusts = {}
	for i = 1, 8 do
		table.insert(gusts, part(Vector3.new(0.25, 0.25, radius * 0.6) * k, CFrame.new(top), ICE, 0.45))
	end
	local lastFlash = 0
	animate(seconds, function(_alpha, elapsed)
		for i, g in gusts do
			local angle = elapsed * 5 + i / #gusts * math.pi * 2
			local h = (3 + (i % 3) * 3) * k
			local reach = radius * (0.6 + (i % 2) * 0.3)
			g.CFrame = CFrame.lookAt(floor + UP * h + outward(angle) * reach, floor + UP * h + outward(angle + 0.5) * reach)
		end
		if elapsed - lastFlash > 0.25 then
			lastFlash = elapsed
			glow.Brightness = if math.random() < 0.4 then 8 else 1
		end
	end, function()
		for _, g in gusts do
			fade(g, 0.3)
		end
	end)
	-- Hailstones.
	local ends = os.clock() + seconds
	task.spawn(FxSize.keep(function()
		local n = 0
		while os.clock() < ends do
			n += 1
			if not busy() then
				local angle, d = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
				local spot = floor + outward(angle) * d
				-- Every so often one comes down right on top of someone.
				if n % 4 == 0 then
					for _, other in Players:GetPlayers() do
						local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if r and ((r.Position - floor) * Vector3.new(1, 0, 1)).Magnitude <= radius then
							spot = floorUnder(r.Position) + outward(math.random() * 6) * math.random() * k
							break
						end
					end
				end
				local big = n % 5 == 0
				local stone = glass(
					(if big then Vector3.new(1.1, 2.8, 1.1) else Vector3.new(0.7, 2.2, 0.7)) * k,
					CFrame.new(spot + UP * 12 * k) * CFrame.Angles(0.15, math.random() * 6, 0.1),
					ICE,
					0.05
				)
				local streak =
					part(Vector3.new(0.12, 3.5, 0.12) * k, stone.CFrame * CFrame.new(0, 2.6 * k, 0), WHITE, 0.5)
				tween(stone, 0.18, { CFrame = CFrame.new(spot + UP * 0.8 * k) }, Enum.EasingStyle.Linear)
				tween(streak, 0.18, { CFrame = CFrame.new(spot + UP * 3.4 * k) }, Enum.EasingStyle.Linear)
				later(0.18, function()
					fade(stone, 0.15, { Size = Vector3.new(1.1, 0.3, 1.1) * k })
					fade(streak, 0.08)
					shockwave(spot + UP * 0.08, 0.8 * k, (if big then 5 else 3.2) * k, ICE, 0.25, 0.15)
					-- Frost left where it hit.
					local patch = disc(spot + UP * 0.05, (1.2 + math.random()) * k, FROST, 0.5, Enum.Material.Glass)
					later(0.8, function()
						fade(patch, 0.6)
					end)
					if big then
						flash(spot + UP, ICE, 5, 12, 0.2)
						motes(spot + UP * 0.5, ICE, 5, 7, 9, 0.2, 0.6)
						rays(spot + UP * 0.3, ICE, 6, 2.5, 0.25, true)
					end
					if n % 3 == 0 then
						CombatFx.burst(spot + UP * 0.4, ICE, "Shards", 0.6)
					end
				end)
			end
			task.wait(0.03)
		end
	end))
	CombatSound.play("Freeze", floor, { Volume = 1 })
	CombatSound.element("Cast", "Frost", floor, { Volume = 0.8 })
	later(seconds, function()
		for _, puff in puffs do
			fade(puff, 0.6)
		end
		fade(sheet, 0.3)
		fade(inner, 0.2)
		fade(frost, 0.8)
		fade(rim, 0.5)
	end)
end

-- Permafrost Spire: frost cracks race out under them, then a great spike
-- of ice bursts out of the ground in a column of cold light, snow and
-- shards thrown up, and shatters.
SHOW.PermafrostSpire = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	rumble(floor, 0.6, 0.35, 30)
	-- Frost cracks first.
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2 + math.random() * 0.4
		local length = radius * (0.5 + math.random() * 0.5)
		local base = CFrame.new(floor + UP * 0.06) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		local crack = part(Vector3.new(0.3, 0.06, 0.3), base, ICE, 0.1)
		tween(crack, 0.1, { Size = Vector3.new(0.3, 0.06, length), CFrame = base * CFrame.new(0, 0, -length / 2) })
		later(1.2, function()
			fade(crack, 0.5)
		end)
	end
	local spikes = {}
	-- A spike: a shaft of ice with a pointed tip (a cube turned on its corner).
	local function spike(at: Vector3, width: number, tall: number, tilt: CFrame, color: Color3, delay: number)
		local s =
			glass(Vector3.new(width, 0.3, width), CFrame.new(at) * tilt * CFrame.Angles(0, math.rad(45), 0), color, 0.1)
		s.Material = Enum.Material.Ice
		local tip = glass(Vector3.one * 0.2, s.CFrame, color, 0.1)
		tip.Material = Enum.Material.Ice
		later(delay, function()
			local top = CFrame.new(at) * tilt * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, tall * 0.85, 0)
			tween(
				s,
				0.12,
				{
					Size = Vector3.new(width, tall * 0.85, width),
					CFrame = CFrame.new(at) * tilt * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, tall * 0.425, 0),
				},
				Enum.EasingStyle.Back
			)
			tween(
				tip,
				0.12,
				{ Size = Vector3.one * width * 0.72, CFrame = top * CFrame.Angles(math.rad(45), 0, math.rad(35)) },
				Enum.EasingStyle.Back
			)
		end)
		table.insert(spikes, s)
		table.insert(spikes, tip)
	end
	later(0.08, function()
		flash(floor + UP * 3, DEEP_ICE, 9, radius * 3, 0.4)
		column(floor, ICE, 1.2, 18, 0.5)
		rays(floor + UP * 2, ICE, 16, radius * 1.4, 0.4)
		halo(floor + UP * 0.1, ICE, 2, radius * 3, 0.5)
		dust(floor, Color3.fromRGB(200, 225, 240), radius * 1.3, 0.8, 10)
		motes(floor + UP, ICE, 16, 10, 22, 0.3, 1.1)
		rumble(floor, 0.7, 0.3, 30)
	end)
	spike(floor, 2.4, 9, CFrame.Angles(0.08, 0, -0.06), ICE, 0.08)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + math.random() * 0.3
		local at = floor + outward(angle) * (1.6 + math.random() * 1.4)
		spike(
			at,
			1.1,
			3 + math.random() * 3,
			CFrame.Angles(math.sin(angle) * 0.55, 0, -math.cos(angle) * 0.55),
			if i % 2 == 0 then DEEP_ICE else ICE,
			0.1 + i * 0.015
		)
	end
	local glow = part(Vector3.new(0.6, 6, 0.6), CFrame.new(floor + UP * 3), WHITE, 0.4)
	light(glow, DEEP_ICE, 5, 18)
	table.insert(spikes, glow)
	shockwave(floor + UP * 0.1, 2, radius * 2.2, ICE, 0.4)
	local frost = disc(floor + UP * 0.04, radius * 2, FROST, 0.5, Enum.Material.Glass)
	table.insert(spikes, frost)
	CombatFx.burst(floor + UP * 1.5, ICE, "Frost", 2)
	CombatFx.burst(floor + UP, ICE, "Shards", 1.4)
	CombatSound.play("Freeze", floor, { Volume = 1.1 })
	CombatSound.element("Impact", "Frost", floor, { Volume = 1 })
	later(1, function()
		for _ = 1, 8 do
			local angle = math.random() * math.pi * 2
			chunk(
				floor + UP * (1 + math.random() * 4),
				Vector3.new(0.7, 0.9, 0.6),
				if math.random() < 0.5 then ICE else DEEP_ICE,
				outward(angle) * (8 + math.random() * 8) + UP * 10,
				Enum.Material.Ice,
				0.9
			)
		end
		motes(floor + UP * 4, ICE, 12, 8, 8, 0.25, 0.8)
		rays(floor + UP * 4, ICE, 10, 4, 0.3)
		shockwave(floor + UP * 0.1, 2, radius * 2.4, ICE, 0.4, 0.3)
		for _, s in spikes do
			fade(s, 0.25, { Size = s.Size * 0.6 })
		end
		CombatSound.play("GuardBreak", floor, { Volume = 0.7, Pitch = 1.3 })
	end)
end

-- Absolute Zero: a flash of cold, halos of frost racing out, a dome of ice
-- crystallising over everything inside with snow falling in it, crystals
-- round its rim, then it shatters into a blizzard of shards.
SHOW.AbsoluteZero = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	local k = FxSize.get()
	rumble(floor, 0.8, 0.5, 40)
	flash(floor + UP * 2 * k, DEEP_ICE, 12, radius * 3.5, 0.6)
	column(floor, ICE, radius * 0.3, 24, 0.5)
	rays(floor + UP * 2 * k, ICE, 22, radius * 2, 0.45)
	halo(floor + UP * 2 * k, ICE, 2 * k, radius * 3.4, 0.55, Vector3.new(1, 0, 0), 0.3)
	halo(floor + UP * 2 * k, WHITE, 2 * k, radius * 3.4, 0.6, Vector3.new(0, 0, 1), 0.35)
	local dome = glass(Vector3.one * 2 * k, CFrame.new(floor), ICE, 0.5)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.Ice
	tween(dome, 0.3, { Size = Vector3.one * radius * 2 }, Enum.EasingStyle.Back)
	local shine = part(Vector3.one * 2 * k, CFrame.new(floor), WHITE, 0.82, Enum.PartType.Ball)
	fade(shine, 0.3, { Size = Vector3.one * radius * 2.05 })
	shockwave(floor + UP * 0.1, 2 * k, radius * 2.4, ICE, 0.45)
	later(0.1, function()
		shockwave(floor + UP * 0.15, 3 * k, radius * 3.2, DEEP_ICE, 0.6, 0.4)
		dust(floor, Color3.fromRGB(205, 228, 245), radius * 1.4, 1, 12)
	end)
	local floorIce = disc(floor + UP * 0.05, radius * 2, FROST, 0.4, Enum.Material.Ice)
	local crystals = { dome, floorIce }
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		local at = floor + outward(angle) * radius * (0.55 + math.random() * 0.35)
		local tall = (1.5 + math.random() * 2.5) * k
		local c = glass(
			Vector3.new(0.6, 0.2, 0.6) * k,
			CFrame.new(at) * CFrame.Angles(math.sin(angle) * 0.4, 0, -math.cos(angle) * 0.4),
			if i % 2 == 0 then DEEP_ICE else ICE,
			0.1
		)
		later(0.05 + i * 0.015, function()
			tween(
				c,
				0.15,
				{ Size = Vector3.new(0.6 * k, tall, 0.6 * k), CFrame = c.CFrame * CFrame.new(0, tall / 2, 0) },
				Enum.EasingStyle.Back
			)
		end)
		table.insert(crystals, c)
	end
	-- Snow falling inside the dome.
	local snow = part(Vector3.new(radius * 1.4, 0.2, radius * 1.4), CFrame.new(floor + UP * radius * 0.8), ICE, 1)
	emitter(attach(snow), WHITE, 40, {
		Size = 0.22,
		EndSize = 0.15,
		Speed = 3,
		Life = 1,
		Spread = 10,
		Acceleration = Vector3.new(0, -2, 0),
		Direction = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		Light = 0.5,
	})
	light(snow, DEEP_ICE, 4, radius * 3)
	table.insert(crystals, snow)
	local mist = attach(floorIce)
	emitter(
		mist,
		WHITE,
		40,
		{
			Texture = SMOKE_TEXTURE,
			Size = 2,
			EndSize = 4,
			Speed = 2,
			Life = 1,
			Light = 0.2,
			Alpha = 0.6,
			Acceleration = Vector3.new(0, 1, 0),
		}
	)
	CombatFx.burst(floor + UP * 2 * k, ICE, "Frost", 3)
	CombatSound.play("Freeze", floor, { Volume = 1.3 })
	CombatSound.play("Blast", floor, { Volume = 0.8, Pitch = 1.6 })
	later(1.5, function()
		flash(floor + UP * 2 * k, ICE, 8, radius * 3, 0.3)
		rays(floor + UP * 2 * k, ICE, 14, radius * 1.5, 0.35)
		shockwave(floor + UP * 0.1, 2 * k, radius * 2.8, ICE, 0.45, 0.2)
		motes(floor + UP * 2 * k, ICE, 20, 14, 12, 0.3, 1)
		for _ = 1, 14 do
			local angle = math.random() * math.pi * 2
			chunk(
				floor + UP * (1 + math.random() * radius * 0.6) + outward(angle) * radius * 0.6,
				Vector3.new(0.9, 1, 0.8),
				if math.random() < 0.5 then ICE else DEEP_ICE,
				outward(angle) * (12 + math.random() * 10) + UP * 12,
				Enum.Material.Ice,
				1
			)
		end
		for _, c in crystals do
			fade(c, 0.3)
		end
		rumble(floor, 0.6, 0.3, 36)
		CombatSound.play("GuardBreak", floor, { Volume = 0.9, Pitch = 1.2 })
	end)
end

-- ION ----------------------------------------------------------------------------------

-- Thunder Dash: you become a bolt of lightning between two points, leaving
-- afterimages, a scorched streak and a thunderclap where you arrive.
SHOW.ThunderDash = function(_who, from: Vector3, to: Vector3, _seconds: number)
	local chest = UP * 0.6
	strike(from + chest, to + chest, VOLT, 0.9)
	later(0.05, function()
		CombatVfx.lightning(from + chest + UP * 0.6, to + chest - UP * 0.4, ARC)
	end)
	later(0.1, function()
		CombatVfx.lightning(from + chest - UP * 0.5, to + chest + UP * 0.5, VOLT)
	end)
	local length = (to - from).Magnitude
	if length > 0.5 then
		local body = part(Vector3.new(1.4, 2.6, length), CFrame.lookAt((from + to) / 2 + chest, to + chest), VOLT, 0.55)
		fade(body, 0.3, { Size = Vector3.new(0.2, 0.4, length) })
		ghosts(from, to, ARC, 5, 0.35)
		-- A scorched streak along the ground, crackling.
		local a, b = floorUnder(from), floorUnder(to)
		local streak = part(Vector3.new(1.6, 0.06, length), CFrame.lookAt((a + b) / 2 + UP * 0.04, b + UP * 0.04), Color3.fromRGB(40, 36, 50), 0.2, nil, Enum.Material.Slate)
		local line = part(Vector3.new(0.4, 0.08, length), streak.CFrame, VOLT, 0.3)
		later(0.9, function()
			fade(streak, 0.7)
			fade(line, 0.5)
		end)
	end
	for _, at in { from, to } do
		flash(at + chest, VOLT, 8, 22, 0.3)
		CombatFx.burst(at + chest, VOLT, "Sparks", 1.6)
		shockwave(floorUnder(at) + UP * 0.08, 1, 7, VOLT, 0.3)
	end
	-- The thunderclap where you land.
	halo(to + chest, VOLT, 1, 12, 0.35, to - from, 0.2)
	rays(to + chest, VOLT, 14, 5, 0.3)
	motes(to + chest, VOLT, 12, 12, 10, 0.25, 0.7)
	dust(floorUnder(to), Color3.fromRGB(120, 115, 135), 4, 0.6, 8)
	-- Static crackling off you for a moment after.
	local ends = os.clock() + 0.5
	task.spawn(FxSize.keep(function()
		while os.clock() < ends do
			if not busy() then
				local at = to + chest + Vector3.new(math.random() - 0.5, math.random() * 2 - 1, math.random() - 0.5) * 1.5
				CombatVfx.lightning(at, at + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3, ARC)
			end
			task.wait(0.08)
		end
	end))
	rumble(to, 0.45, 0.25, 26)
	CombatSound.play("Zap", from, { Volume = 1.1, Pitch = 1.2 })
	CombatSound.element("Impact", "Shock", to, { Volume = 0.9 })
	CombatSound.play("Blast", to, { Volume = 0.6, Pitch = 1.6 })
end

-- Skybreaker: the sky answers — the clouds light up, a pillar of lightning
-- hammers the target, thunder halos ring out, and the ground is left live.
SHOW.Skybreaker = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	local sky = floor + UP * 60
	-- The sky lights up as it comes.
	local cloud = disc(floor + UP * 40, radius * 5, ARC, 0.8)
	fade(cloud, 0.5, { Size = Vector3.new(0.08, radius * 9, radius * 9) })
	local skyLight = part(Vector3.one, CFrame.new(floor + UP * 30), WHITE, 1)
	light(skyLight, ARC, 10, 60)
	fade(skyLight, 0.5)
	strike(sky + Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2), floor + UP * 0.3, VOLT, 1.6)
	later(0.04, function()
		CombatVfx.lightning(sky + Vector3.new(3, 0, -2), floor + UP * 0.3, ARC)
	end)
	later(0.09, function()
		CombatVfx.lightning(sky + Vector3.new(-3, 0, 2), floor + UP * 0.3, VOLT)
	end)
	local pillar = part(
		Vector3.new(40, radius * 0.6, radius * 0.6),
		CFrame.new(floor + UP * 20) * FLAT,
		WHITE,
		0.2,
		Enum.PartType.Cylinder
	)
	fade(pillar, 0.35, { Size = Vector3.new(40, 0.2, 0.2) })
	local afterglow = part(Vector3.new(40, radius * 1.4, radius * 1.4), CFrame.new(floor + UP * 20) * FLAT, VOLT, 0.6, Enum.PartType.Cylinder)
	fade(afterglow, 0.8, { Size = Vector3.new(40, 0.3, 0.3) })
	flash(floor + UP * 3, VOLT, 16, radius * 4.5, 0.5)
	rumble(floor, 1, 0.45, 40)
	shockwave(floor + UP * 0.1, 2, radius * 2.4, VOLT, 0.4, 0.05)
	shockwave(floor + UP * 0.15, 2, radius * 3, ARC, 0.6, 0.35)
	halo(floor + UP * 2, VOLT, 2, radius * 3.4, 0.5, Vector3.new(1, 0, 0), 0.25)
	halo(floor + UP * 2, ARC, 2, radius * 3.4, 0.55, Vector3.new(0, 0, 1), 0.3)
	rays(floor + UP * 1.5, VOLT, 20, radius * 1.8, 0.4)
	later(0.08, function()
		dust(floor, Color3.fromRGB(125, 118, 140), radius * 1.4, 0.8, 12)
	end)
	motes(floor + UP, VOLT, 20, 14, 24, 0.3, 1.1)
	local scorch = disc(floor + UP * 0.04, radius * 1.4, Color3.fromRGB(40, 36, 50), 0.15, Enum.Material.Slate)
	later(1.4, function()
		fade(scorch, 0.8)
	end)
	linger(floor, VOLT, radius * 0.7, 1.4, SPARK_TEXTURE, ARC)
	-- Lightning cracks running out across the ground, and the ground left
	-- live for a moment.
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2 + math.random() * 0.3
		local a = floor + UP * 0.1
		local b = a + outward(angle) * radius * (0.8 + math.random() * 0.6)
		CombatVfx.lightning(a, b, if i % 2 == 0 then VOLT else ARC)
	end
	local ends = os.clock() + 0.9
	task.spawn(FxSize.keep(function()
		while os.clock() < ends do
			if not busy() then
				local a = floor + outward(math.random() * 6) * radius * math.random() * 0.8 + UP * 0.2
				CombatVfx.lightning(a, a + outward(math.random() * 6) * 2 + UP * (0.5 + math.random()), ARC)
			end
			task.wait(0.14)
		end
	end))
	CombatFx.burst(floor + UP, VOLT, "Sparks", 2.6)
	CombatFx.burst(floor + UP * 0.5, Color3.fromRGB(120, 115, 130), "Smoke", 1.6)
	CombatSound.play("Zap", floor, { Volume = 1.3, Pitch = 0.8 })
	CombatSound.play("Blast", floor, { Volume = 1, Pitch = 1.3 })
	CombatSound.element("Impact", "Shock", floor, { Volume = 1 })
end

-- Storm Call: a thundercloud gathers over the area, lit from inside, wind
-- funnelling under it and rain driving down.
SHOW.StormCall = function(_who, center: Vector3, radius: number, seconds: number)
	local floor = floorUnder(center)
	local k = FxSize.get()
	local top = floor + UP * 20 * k
	local puffs = {}
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		local d = radius * (0.2 + math.random() * 0.7)
		local s = radius * (0.6 + math.random() * 0.5)
		local puff = ellipsoid(
			Vector3.new(s, s * 0.4, s),
			CFrame.new(top + outward(angle) * d + UP * (math.random() - 0.5) * 2 * k),
			if i % 3 == 0 then Color3.fromRGB(60, 58, 90) else STORM,
			1,
			Enum.Material.SmoothPlastic
		)
		tween(puff, 0.5, { Transparency = 0.1 })
		table.insert(puffs, puff)
	end
	local heart = part(Vector3.one * k, CFrame.new(top - UP * k), VOLT, 1)
	local glow = light(heart, ARC, 0, radius * 3)
	-- Rain driving down out of it.
	local rain = part(Vector3.new(radius * 1.6, 0.2, radius * 1.6), CFrame.new(top - UP * 2 * k), ARC, 1)
	emitter(attach(rain), Color3.fromRGB(170, 190, 230), 90, {
		Size = 0.1,
		EndSize = 0.08,
		Speed = 45,
		Life = 0.45,
		Spread = 3,
		Acceleration = Vector3.zero,
		Direction = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		Light = 0.3,
		Alpha = 0.4,
	})
	local rim = disc(floor + UP * 0.05, radius * 2, VOLT, 0.9)
	halo(floor + UP * 0.1, VOLT, 2 * k, radius * 2.4, 0.5, nil, 0.4)
	-- The wind kicks up dust as it arrives, static drifting up through it.
	dust(floor, Color3.fromRGB(110, 108, 130), radius * 1.2, 1, 10)
	motes(floor + UP * k, VOLT, 10, 4, 10, 0.2, 1.2)
	-- Wind funnelling under the cloud.
	local gusts = {}
	for i = 1, 8 do
		table.insert(gusts, part(Vector3.new(0.2, 0.2, radius * 0.5) * k, CFrame.new(top), Color3.fromRGB(150, 150, 190), 0.5))
	end
	animate(seconds, function(_alpha, elapsed)
		for i, g in gusts do
			local h = (4 + (i % 4) * 3.5) * k
			local angle = elapsed * 4 + i / #gusts * math.pi * 2
			local reach = radius * (0.35 + h / (20 * k) * 0.5)
			g.CFrame = CFrame.lookAt(floor + UP * h + outward(angle) * reach, floor + UP * h + outward(angle + 0.5) * reach)
		end
	end, function()
		for _, g in gusts do
			fade(g, 0.3)
		end
	end)
	local ends = os.clock() + seconds
	task.spawn(FxSize.keep(function()
		while os.clock() < ends and heart.Parent do
			-- The cloud flickers with lightning inside it.
			local lit = math.random() < 0.25
			glow.Brightness = if lit then 8 + math.random() * 6 else 0.5
			if lit then
				flash(top, ARC, 4, radius * 3, 0.12)
			end
			if math.random() < 0.25 and not busy() then
				local a = top + outward(math.random() * 6) * radius * 0.6
				CombatVfx.lightning(a, a + outward(math.random() * 6) * radius * 0.5 - UP * k, ARC)
			end
			task.wait(0.07)
		end
	end))
	CombatSound.play("Zap", top, { Volume = 0.8, Pitch = 0.6 })
	later(seconds, function()
		for _, puff in puffs do
			fade(puff, 0.6)
		end
		fade(heart, 0.2)
		fade(rain, 0.2)
		fade(rim, 0.4)
	end)
end

-- A bolt about to land: a crackling target closing in on the spot.
SHOW.StormWarn = function(_who, point: Vector3, radius: number, delay: number)
	local floor = floorUnder(point)
	local mark = disc(floor + UP * 0.07, radius * 2.8, VOLT, 0.4)
	tween(
		mark,
		delay,
		{ Size = Vector3.new(0.08, radius * 2, radius * 2), Transparency = 0.1 },
		Enum.EasingStyle.Linear
	)
	local dot = disc(floor + UP * 0.09, radius * 0.6, WHITE, 0.3)
	local guide = part(Vector3.new(0.12, 18, 0.12), CFrame.new(floor + UP * 9), ARC, 0.6)
	later(delay, function()
		fade(mark, 0.1)
		fade(dot, 0.1)
		fade(guide, 0.05)
	end)
	CombatSound.play("Warn", floor, { Volume = 0.5, Pitch = 1.5 })
end

-- A storm bolt lands (the last one bigger: it stuns).
SHOW.StormBolt = function(_who, point: Vector3, radius: number, last: number)
	local floor = floorUnder(point)
	local k = FxSize.get()
	local big = last == 1
	strike(
		floor + (UP * 20 + Vector3.new(math.random() * 3 - 1.5, 0, math.random() * 3 - 1.5)) * k,
		floor + UP * 0.3 * k,
		VOLT,
		if big then 1.4 else 0.8
	)
	if big then
		later(0.05, function()
			CombatVfx.lightning(floor + (UP * 20 + Vector3.new(2, 0, 2)) * k, floor + UP * 0.3 * k, ARC)
		end)
	end
	flash(floor + UP * 2 * k, VOLT, if big then 14 else 8, radius * 4, 0.3)
	shockwave(floor + UP * 0.1, k, radius * (if big then 3.4 else 2.4), VOLT, 0.35)
	halo(floor + UP * 1.5 * k, VOLT, k, radius * (if big then 3.4 else 2.2), 0.35, Vector3.new(1, 0, 0), 0.3)
	rays(floor + UP * k, VOLT, if big then 16 else 8, radius * (if big then 1.6 else 1), 0.3)
	motes(floor + UP * k, VOLT, if big then 14 else 6, 10, 16, 0.25, 0.8)
	if big then
		column(floor, VOLT, radius * 0.3, 20, 0.5)
		dust(floor, Color3.fromRGB(120, 115, 135), radius * 1.2, 0.7, 8)
		linger(floor, VOLT, radius * 0.6, 1.2, SPARK_TEXTURE, ARC)
	end
	local burn = disc(floor + UP * 0.04, radius * 1.3, Color3.fromRGB(40, 36, 50), 0.2, Enum.Material.Slate)
	later(0.8, function()
		fade(burn, 0.6)
	end)
	CombatFx.burst(floor + UP * k, VOLT, "Sparks", if big then 2.2 else 1.3)
	rumble(floor, if big then 0.8 else 0.4, 0.25, 30)
	CombatSound.play("Zap", floor, { Volume = if big then 1.2 else 0.9, Pitch = 0.9 + math.random() * 0.3 })
	if big then
		CombatSound.play("Blast", floor, { Volume = 0.8, Pitch = 1.4 })
	end
end

-- Ion Cannon: a beam as thick as a body, punching through the line: a
-- muzzle ring, dust blown out along the ground, and a blast at the far end.
SHOW.IonCannon = function(_who, origin: Vector3, finish: Vector3, width: number)
	local length = (finish - origin).Magnitude
	if length < 1 then
		return
	end
	local frame = CFrame.lookAt((origin + finish) / 2, finish)
	local direction = (finish - origin).Unit
	local outer = part(Vector3.new(width, width, length), frame, ARC, 0.35)
	local core = part(Vector3.new(width * 0.45, width * 0.45, length), frame, WHITE, 0)
	light(core, ARC, 8, 40)
	tween(outer, 0.08, { Size = Vector3.new(width * 1.25, width * 1.25, length) })
	later(0.12, function()
		fade(outer, 0.45, { Size = Vector3.new(0.2, 0.2, length) })
		fade(core, 0.35, { Size = Vector3.new(0.1, 0.1, length) })
	end)
	-- A glow that hangs in the air where the beam was.
	local ember = part(Vector3.new(width * 0.3, width * 0.3, length), frame, ARC, 0.5)
	later(0.3, function()
		fade(ember, 0.9, { Size = Vector3.new(0.05, 0.05, length) })
	end)
	-- Rings along it, blown outward.
	local count = math.clamp(math.floor(length / 4), 3, 12)
	for i = 1, count do
		local at = origin + direction * length * i / count
		local ring = part(
			Vector3.new(0.15, width * 1.2, width * 1.2),
			CFrame.lookAt(at, at + direction) * CFrame.Angles(0, math.rad(90), 0),
			VOLT,
			0.3,
			Enum.PartType.Cylinder
		)
		later(i * 0.012, function()
			fade(ring, 0.35, { Size = Vector3.new(0.05, width * 3, width * 3) })
		end)
		-- Dust blown out along the ground under it.
		if i % 2 == 0 then
			later(i * 0.012, function()
				dust(floorUnder(at), Color3.fromRGB(120, 118, 140), width * 1.2, 0.6, 4)
			end)
		end
	end
	-- The ground scorched under the whole line.
	local a, b = floorUnder(origin), floorUnder(finish)
	local ground = (b - a) * Vector3.new(1, 0, 1)
	if ground.Magnitude > 1 then
		local scar = part(Vector3.new(width * 0.9, 0.06, ground.Magnitude), CFrame.lookAt(a + ground / 2 + UP * 0.04, b + UP * 0.04), Color3.fromRGB(40, 36, 50), 0.25, nil, Enum.Material.Slate)
		local live = part(Vector3.new(width * 0.3, 0.08, ground.Magnitude), scar.CFrame, VOLT, 0.35)
		later(1, function()
			fade(scar, 0.8)
			fade(live, 0.5)
		end)
	end
	for _ = 1, 2 do
		CombatVfx.lightning(origin, finish, VOLT)
	end
	-- The muzzle: a ring blown back off the barrel, a flash, recoil in the dust.
	halo(origin, ARC, width, width * 4, 0.3, direction, 0.2)
	rays(origin, WHITE, 10, 4, 0.25)
	shockwave(a + UP * 0.08, 1, width * 3, VOLT, 0.3, 0.3)
	flash(origin, ARC, 12, 26, 0.3)
	-- The far end: it punches through.
	flash(finish, VOLT, 10, 26, 0.3)
	halo(finish, VOLT, width, width * 5, 0.4, direction, 0.2)
	rays(finish, VOLT, 16, 6, 0.35)
	column(b, ARC, width * 0.4, 14, 0.45)
	motes(finish, VOLT, 16, 14, 14, 0.3, 0.9)
	dust(b, Color3.fromRGB(120, 118, 140), width * 1.6, 0.7, 8)
	linger(b, VOLT, width * 0.8, 1.2, SPARK_TEXTURE, ARC)
	CombatFx.burst(origin, WHITE, "Sparks", 1.6)
	CombatFx.burst(finish, VOLT, "Sparks", 2)
	rumble(origin, 0.9, 0.4, 30)
	CombatSound.play("Beam", origin, { Volume = 1.2, Pitch = 0.7 })
	CombatSound.play("Blast", origin, { Volume = 0.8, Pitch = 1.5 })
	CombatSound.element("Impact", "Shock", finish, { Volume = 1 })
end

-- ACID ---------------------------------------------------------------------------------

-- Viper Lash: a whip of venom that strikes like a snake and drags them in:
-- a bite that spits venom, and acid dragged along the ground behind them.
SHOW.ViperLash = function(_who, origin: Vector3, tip: Vector3, hit: number)
	local length = (tip - origin).Magnitude
	if length < 0.5 then
		return
	end
	local direction = (tip - origin).Unit
	local side = direction:Cross(UP)
	side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
	local count = 16
	local segments = {}
	for i = 1, count do
		local size = 0.95 - i * 0.03
		table.insert(
			segments,
			part(Vector3.one * size, CFrame.new(origin), if i % 3 == 0 then FOAM else TOXIC, 0.05, Enum.PartType.Ball)
		)
	end
	local head = ellipsoid(Vector3.new(1.4, 0.95, 2.2), CFrame.new(origin), LIME, 0)
	local jawTop = ellipsoid(Vector3.new(1.3, 0.35, 1.5), CFrame.new(origin), VENOM, 0, Enum.Material.SmoothPlastic)
	local fangs = {
		part(Vector3.new(0.18, 0.7, 0.18), CFrame.new(origin), WHITE, 0),
		part(Vector3.new(0.18, 0.7, 0.18), CFrame.new(origin), WHITE, 0),
	}
	local eyes = {
		part(Vector3.one * 0.28, CFrame.new(origin), Color3.fromRGB(255, 230, 60), 0, Enum.PartType.Ball),
		part(Vector3.one * 0.28, CFrame.new(origin), Color3.fromRGB(255, 230, 60), 0, Enum.PartType.Ball),
	}
	local tongue = part(Vector3.new(0.08, 0.08, 0.9), CFrame.new(origin), Color3.fromRGB(255, 60, 90), 0)
	light(head, LIME, 4, 14)
	emitter(
		attach(head),
		LIME,
		40,
		{ Size = 0.3, Speed = 1, Life = 0.4, Acceleration = Vector3.new(0, -6, 0), Light = 0.5 }
	)
	halo(origin, LIME, 0.5, 4, 0.25, direction, 0.3)
	local out, back = 0.15, 0.26
	local lastDrag = 0
	animate(out + back, function(_alpha, elapsed)
		local reach = if elapsed < out then elapsed / out else 1 - (elapsed - out) / back
		reach = math.clamp(reach, 0, 1)
		local tipAt = origin + direction * length * reach
		for i, s in segments do
			local f = i / count
			local wave = math.sin(f * math.pi * 3 + elapsed * 30) * 0.6 * (1 - f) * reach
			s.CFrame = CFrame.new(origin:Lerp(tipAt, f) + side * wave)
		end
		local face = CFrame.lookAt(tipAt, tipAt + direction)
		head.CFrame = face
		jawTop.CFrame = face * CFrame.new(0, 0.5, -0.2)
		fangs[1].CFrame = face * CFrame.new(0.38, -0.4, -0.9)
		fangs[2].CFrame = face * CFrame.new(-0.38, -0.4, -0.9)
		eyes[1].CFrame = face * CFrame.new(0.48, 0.32, -0.3)
		eyes[2].CFrame = face * CFrame.new(-0.48, 0.32, -0.3)
		tongue.CFrame = face * CFrame.new(0, -0.1, -1.4 - math.abs(math.sin(elapsed * 40)) * 0.4)
		-- Dragging them back: acid smeared along the ground behind the head.
		if hit == 1 and elapsed > out and elapsed - lastDrag > 0.04 and not busy() then
			lastDrag = elapsed
			local smear = disc(floorUnder(tipAt) + UP * 0.04, 1.6 + math.random(), TOXIC, 0.4, Enum.Material.Glass)
			later(0.6, function()
				fade(smear, 0.6)
			end)
		end
	end, function()
		for _, p in segments do
			fade(p, 0.1)
		end
		for _, p in { head, jawTop, fangs[1], fangs[2], eyes[1], eyes[2], tongue } do
			fade(p, 0.1)
		end
	end)
	later(out, function()
		if hit == 1 then
			CombatFx.burst(tip, LIME, "Drips", 1.8)
			flash(tip, LIME, 7, 16, 0.25)
			rays(tip, LIME, 10, 3.5, 0.3)
			motes(tip, LIME, 10, 8, 10, 0.22, 0.8)
			halo(tip, LIME, 0.5, 6, 0.3, direction, 0.25)
			shockwave(floorUnder(tip) + UP * 0.08, 1, 6, LIME, 0.3)
			rumble(tip, 0.3, 0.2, 24)
			CombatSound.element("Impact", "Poison", tip, { Volume = 1 })
		end
	end)
	CombatSound.play("Swing", origin, { Volume = 1, Pitch = 1.4 })
	CombatSound.play("Corrode", origin, { Volume = 0.7 })
end

-- Toxic Flask: a bubbling flask spinning through the air.
SHOW.ToxicFlaskThrow = function(_who, from: Vector3, to: Vector3, seconds: number)
	local bulb = glass(Vector3.one * 1, CFrame.new(from), LIME, 0.15)
	bulb.Shape = Enum.PartType.Ball
	local brew = part(Vector3.one * 0.7, CFrame.new(from), TOXIC, 0.1, Enum.PartType.Ball)
	local neck = glass(Vector3.new(0.35, 0.6, 0.35), CFrame.new(from), FOAM, 0.2)
	local cork =
		part(Vector3.new(0.38, 0.22, 0.38), CFrame.new(from), Color3.fromRGB(150, 100, 60), 0, nil, Enum.Material.Wood)
	light(brew, LIME, 3, 12)
	emitter(
		attach(brew),
		LIME,
		26,
		{ Size = 0.35, Speed = 0.6, Life = 0.5, Acceleration = Vector3.new(0, -8, 0), Light = 0.5 }
	)
	local floor = floorUnder(to)
	local mark = disc(floor + UP * 0.07, 1, LIME, 0.5)
	tween(mark, seconds, { Size = Vector3.new(0.08, 8, 8), Transparency = 0.25 }, Enum.EasingStyle.Linear)
	local peak = 3 + (to - from).Magnitude * 0.18
	animate(seconds, function(alpha, elapsed)
		local at = from:Lerp(floor + UP * 0.5, alpha) + UP * (4 * peak * alpha * (1 - alpha))
		local turn = CFrame.new(at) * CFrame.Angles(elapsed * 14, elapsed * 5, 0)
		bulb.CFrame = turn
		brew.CFrame = turn
		neck.CFrame = turn * CFrame.new(0, 0.7, 0)
		cork.CFrame = turn * CFrame.new(0, 1.05, 0)
	end, function()
		for _, p in { bulb, brew, neck, cork, mark } do
			fade(p, 0.05)
		end
	end)
	CombatSound.play("Swing", from, { Volume = 0.8, Pitch = 1.2 })
end

-- Toxic Flask lands: glass bursts, acid splashes everywhere and a cloud of
-- poison vapour boils up.
SHOW.ToxicFlask = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	rumble(floor, 0.5, 0.3, 26)
	flash(floor + UP, LIME, 9, radius * 3.5, 0.35)
	local splash = ellipsoid(Vector3.one * 1.5, CFrame.new(floor + UP), LIME, 0.15)
	fade(splash, 0.35, { Size = Vector3.new(radius * 1.8, radius * 0.9, radius * 1.8) })
	local spray = ellipsoid(Vector3.one * 1.5, CFrame.new(floor + UP), FOAM, 0.5)
	fade(spray, 0.5, { Size = Vector3.new(radius * 2.2, radius * 1.3, radius * 2.2) })
	shockwave(floor + UP * 0.1, 1.5, radius * 2.3, LIME, 0.4)
	halo(floor + UP * 1.5, FOAM, 1, radius * 2.4, 0.4, Vector3.new(1, 0, 0), 0.35)
	rays(floor + UP, LIME, 14, radius, 0.3)
	column(floor, LIME, 0.6, 7, 0.35)
	-- A cloud of vapour boiling up and spreading.
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local s = 1.5 + math.random()
		local puff = ellipsoid(Vector3.one * s, CFrame.new(floor + UP * 0.5), if i % 2 == 0 then TOXIC else VENOM, 0.3, Enum.Material.SmoothPlastic)
		fade(puff, 1.2, {
			CFrame = CFrame.new(floor + outward(angle) * radius * 0.6 + UP * (3 + math.random() * 2)),
			Size = Vector3.one * s * 2.6,
		}, Enum.EasingStyle.Quart)
	end
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		chunk(
			floor + UP,
			Vector3.new(0.35, 0.08, 0.35),
			FOAM,
			outward(angle) * (10 + math.random() * 10) + UP * (12 + math.random() * 10),
			Enum.Material.Glass,
			0.8
		)
	end
	for _ = 1, 14 do
		local angle = math.random() * math.pi * 2
		chunk(
			floor + UP,
			Vector3.one * (0.3 + math.random() * 0.3),
			if math.random() < 0.5 then LIME else TOXIC,
			outward(angle) * (6 + math.random() * 14) + UP * (14 + math.random() * 14),
			Enum.Material.Neon,
			0.9
		)
	end
	motes(floor + UP, LIME, 14, 10, 20, 0.3, 1)
	motes(floor + UP, WHITE, 6, 8, 16, 0.15, 0.6)
	CombatFx.burst(floor + UP, LIME, "Drips", 2.2)
	CombatFx.burst(floor + UP * 0.5, TOXIC, "Smoke", 1.6)
	CombatSound.play("Block", floor, { Volume = 0.8, Pitch = 1.6 })
	CombatSound.play("Corrode", floor, { Volume = 1.1 })
	CombatSound.element("Impact", "Poison", floor, { Volume = 1 })
end

-- What a flask leaves: a bubbling pool of bright acid.
SHOW.Puddle = function(_who, center: Vector3, radius: number, seconds: number)
	local floor = floorUnder(center)
	local pool = disc(floor + UP * 0.03, 1, TOXIC, 0.15, Enum.Material.Glass)
	pool.Reflectance = 0.35
	tween(pool, 0.25, { Size = Vector3.new(0.08, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	local sheen = disc(floor + UP * 0.06, 1, LIME, 0.45)
	tween(sheen, 0.25, { Size = Vector3.new(0.06, radius * 1.6, radius * 1.6) }, Enum.EasingStyle.Back)
	light(sheen, LIME, 2, radius * 3)
	emitter(
		attach(sheen),
		FOAM,
		10,
		{ Size = 0.4, Speed = 0.6, Spread = 60, Acceleration = Vector3.new(0, 1.5, 0), Life = 0.8, Light = 0.4 }
	)
	local ends = os.clock() + seconds
	task.spawn(function()
		while os.clock() < ends and pool.Parent do
			if not busy() then
				local angle, d = math.random() * math.pi * 2, math.sqrt(math.random()) * radius * 0.85
				local bubble = part(
					Vector3.one * 0.2,
					CFrame.new(floor + outward(angle) * d + UP * 0.1),
					FOAM,
					0.3,
					Enum.PartType.Ball,
					Enum.Material.Glass
				)
				tween(bubble, 0.35, { Size = Vector3.one * (0.5 + math.random() * 0.6) })
				later(0.35, function()
					fade(bubble, 0.1, { Size = Vector3.one * 1.2 })
				end)
			end
			task.wait(0.14)
		end
	end)
	later(seconds, function()
		fade(pool, 0.6)
		fade(sheen, 0.6)
	end)
end

-- Toxic Tide: a towering wave of acid rolls out and crashes, spray flying
-- off its crest, and breaks in a burst of foam at the end.
SHOW.ToxicTide = function(_who, from: Vector3, to: Vector3, seconds: number, width: number)
	local a, b = floorUnder(from), floorUnder(to)
	local line = (b - a) * Vector3.new(1, 0, 1)
	local direction = if line.Magnitude > 0.1 then line.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local k = FxSize.get()
	local columns = 7
	local wall, crest = {}, {}
	for i = 1, columns do
		local offset = ((i - 0.5) / columns - 0.5) * width
		table.insert(wall, {
			Part = glass(Vector3.new(width / columns * 1.15, 1, 1.8 * k), CFrame.new(a), TOXIC, 0.2),
			Offset = offset,
			Back = 0,
		})
		table.insert(wall, {
			Part = part(Vector3.new(width / columns * 1.15, 1, 2.6 * k), CFrame.new(a), LIME, 0.65),
			Offset = offset,
			Back = 1.6 * k,
		})
		table.insert(crest, {
			Part = ellipsoid(Vector3.new(width / columns * 1.4, 1.1 * k, 1.6 * k), CFrame.new(a), FOAM, 0.1),
			Offset = offset,
		})
	end
	local glow = part(Vector3.one, CFrame.new(a), LIME, 1)
	light(glow, LIME, 5, width * 2)
	local spray = attach(glow)
	emitter(
		spray,
		FOAM,
		80,
		{
			Size = 0.6,
			Speed = 6,
			Life = 0.6,
			Spread = 40,
			Acceleration = Vector3.new(0, -22, 0),
			Light = 0.4,
			Shape = Enum.ParticleEmitterShape.Box,
		}
	)
	glow.Size = Vector3.new(width, 1, 1)
	-- It rises out of the ground in a splash.
	halo(a + UP * 0.2, LIME, 2 * k, width * 1.4, 0.4)
	flash(a + UP * 2, LIME, 6, width * 2, 0.3)
	motes(a + UP * k, FOAM, 10, 8, 14, 0.25, 0.8)
	local lastWet, lastSpray = 0, 0
	animate(seconds, function(alpha, elapsed)
		local front = a:Lerp(b, alpha)
		-- Rises fast, rolls tall, then breaks as it arrives.
		local height = k
			* (
				if alpha < 0.2
					then 1 + alpha / 0.2 * 6
					elseif alpha < 0.85 then 7
					else 7 * (1 - (alpha - 0.85) / 0.15) + 0.6
			)
		for i, w in wall do
			local ripple = math.sin(elapsed * 9 + i) * 0.4 * k
			local h = (height + ripple) * (if w.Back > 0 then 0.75 else 1)
			local at = front + side * w.Offset - direction * w.Back
			w.Part.Size = Vector3.new(w.Part.Size.X, h, w.Part.Size.Z)
			w.Part.CFrame = CFrame.lookAt(at + UP * h / 2, at + UP * h / 2 + direction)
				* CFrame.Angles(math.rad(-14), 0, 0)
		end
		for i, c in crest do
			local ripple = math.sin(elapsed * 9 + i * 2) * 0.4 * k
			c.Part.CFrame = CFrame.new(front + side * c.Offset + UP * (height + ripple) + direction * 0.8 * k)
		end
		glow.CFrame = CFrame.lookAt(front + UP * height, front + UP * height + direction)
			* CFrame.Angles(0, math.rad(90), 0)
		if elapsed - lastWet > 0.1 and not busy() then
			lastWet = elapsed
			local wet = part(
				Vector3.new(width, 0.06, 1.6 * k),
				CFrame.lookAt(front + UP * 0.04, front + UP * 0.04 + direction),
				TOXIC,
				0.4,
				nil,
				Enum.Material.Glass
			)
			later(0.6, function()
				fade(wet, 0.8)
			end)
		end
		-- Spray flung off the crest.
		if elapsed - lastSpray > 0.1 then
			lastSpray = elapsed
			motes(front + side * (math.random() - 0.5) * width + UP * height, FOAM, 2, 6, 8, 0.25, 0.7)
		end
	end, function()
		for _, w in wall do
			fade(w.Part, 0.3, { Size = Vector3.new(w.Part.Size.X, 0.4 * k, 2.4 * k) })
		end
		for _, c in crest do
			fade(c.Part, 0.3)
		end
		fade(glow, 0.3)
		CombatFx.burst(b + UP * k, FOAM, "Drips", 2.4)
		shockwave(b + UP * 0.1, 2 * k, width * 1.2, LIME, 0.5)
		flash(b + UP * 2 * k, LIME, 8, width * 2, 0.3)
		rays(b + UP * k, FOAM, 12, width * 0.5, 0.35)
		halo(b + UP * 2 * k, LIME, 2 * k, width * 1.4, 0.4, direction, 0.3)
		motes(b + UP * 2 * k, FOAM, 16, 10, 16, 0.3, 0.9)
		dust(b, Color3.fromRGB(120, 180, 90), width * 0.6, 0.8, 8)
		linger(b, TOXIC, width * 0.4, 1.2, nil, LIME)
		rumble(b, 0.6, 0.3, 30)
		CombatSound.play("Corrode", b, { Volume = 1 })
	end)
	rumble(a, 0.5, 0.5, 30)
	CombatSound.play("Corrode", a, { Volume = 1.1, Pitch = 0.7 })
	CombatSound.element("Cast", "Poison", a, { Volume = 1 })
end

-- Maneater: a giant flytrap bursts from the ground and snaps shut. Each jaw
-- is a fat rounded lobe, red inside, with teeth along its rim; shut, the two
-- make a pod with the teeth interlocked.
SHOW.Maneater = function(_who, _origin: Vector3, center: Vector3, radius: number)
	local floor = floorUnder(center)
	local k = FxSize.get()
	local yaw = math.random() * math.pi * 2
	local base = CFrame.new(floor) * CFrame.Angles(0, yaw, 0)
	local span = math.clamp(radius * 0.55, 3 * k, 4.5 * k)
	local jaws = {}
	for side = 0, 1 do
		local pieces = {}
		local function add(p: BasePart, offset: CFrame)
			table.insert(pieces, { Part = p, Offset = offset })
		end
		-- (the jaw's frame: hinge at the origin, up is +Y, inward is +Z)
		add(
			ellipsoid(
				Vector3.new(span * 2.3, span * 1.6, span * 0.8),
				base,
				if side == 0 then TOXIC else Color3.fromRGB(80, 205, 55),
				0,
				Enum.Material.SmoothPlastic
			),
			CFrame.new(0, span * 0.8, -span * 0.05)
		)
		add(
			ellipsoid(Vector3.new(span * 2, span * 1.3, span * 0.3), base, FLESH, 0, Enum.Material.SmoothPlastic),
			CFrame.new(0, span * 0.8, span * 0.32)
		)
		add(
			ellipsoid(Vector3.new(span * 1.2, span * 0.7, span * 0.2), base, Color3.fromRGB(255, 120, 140), 0.2),
			CFrame.new(0, span * 0.85, span * 0.4)
		)
		-- Teeth round the rim, leaning inward; the two jaws' teeth alternate.
		for n = 1, 9 do
			local phi = math.rad(-75 + (n - 1) * 150 / 8) + (if side == 1 then math.rad(8) else 0)
			local x, y = math.sin(phi) * span * 1.12, span * 0.8 + math.cos(phi) * span * 0.78
			add(
				part(
					Vector3.new(0.3, 1.1, 0.3) * k,
					base,
					Color3.fromRGB(252, 250, 232),
					0,
					nil,
					Enum.Material.SmoothPlastic
				),
				CFrame.new(x, y, span * 0.3) * CFrame.Angles(math.rad(50), 0, -phi)
			)
		end
		-- Dark veins down its back.
		add(
			part(Vector3.new(0.25 * k, span * 1.3, 0.25 * k), base, VENOM, 0, nil, Enum.Material.SmoothPlastic),
			CFrame.new(0, span * 0.8, -span * 0.42)
		)
		jaws[side + 1] = { Pieces = pieces, Turn = CFrame.Angles(0, side * math.pi, 0) }
	end
	local stalk =
		part(Vector3.new(1, 1.6, 1.6) * k, base, VENOM, 0, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
	local leaves = {}
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2
		local leaf = ellipsoid(
			Vector3.new(1.8, 0.3, 4) * k,
			CFrame.new(floor + (outward(angle) * 2.8 + UP * 0.2) * k)
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(math.rad(14), 0, 0),
			if i % 2 == 0 then TOXIC else VENOM,
			0,
			Enum.Material.SmoothPlastic
		)
		table.insert(leaves, leaf)
	end
	local glow = part(Vector3.one * k, CFrame.new(floor + UP * 2 * k), LIME, 1)
	light(glow, LIME, 4, 18)
	local function pose(open: number, lift: number)
		-- open: how far each jaw leans out (radians); lift: how far it's risen.
		local hinge = lift - span * 1.7
		for _, jaw in jaws do
			local frame = base * jaw.Turn * CFrame.new(0, hinge, -span * 0.32) * CFrame.Angles(-open, 0, 0)
			for _, piece in jaw.Pieces do
				piece.Part.CFrame = frame * piece.Offset
			end
		end
		local height = math.max(0.3 * k, hinge + span * 0.2)
		stalk.Size = Vector3.new(height, 1.6 * k, 1.6 * k)
		stalk.CFrame = CFrame.new(floor + UP * height / 2) * FLAT
	end
	pose(math.rad(70), 0)
	CombatFx.burst(floor + UP * 0.5 * k, Color3.fromRGB(120, 95, 70), "Smoke", 1.8)
	shockwave(floor + UP * 0.08, 2 * k, radius * 2.2, LIME, 0.35)
	halo(floor + UP * 0.15, LIME, 2 * k, radius * 3, 0.5, nil, 0.3)
	dust(floor, Color3.fromRGB(110, 85, 60), radius * 1.3, 0.8, 10)
	flash(floor + UP * 2 * k, LIME, 6, radius * 3, 0.3)
	-- Vines whip up out of the ground round it, and curl over.
	local vines = {}
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2 + math.random() * 0.4
		local foot = floor + outward(angle) * radius * (0.7 + math.random() * 0.3)
		local tall = (3 + math.random() * 3) * k
		local lean = CFrame.new(foot) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(25 + math.random() * 20))
		local vine = part(Vector3.new(0.35, 0.3, 0.35) * k, lean, if i % 2 == 0 then VENOM else TOXIC, 0, nil, Enum.Material.SmoothPlastic)
		later(0.04 + i * 0.02, function()
			tween(vine, 0.2, { Size = Vector3.new(0.35 * k, tall, 0.35 * k), CFrame = lean * CFrame.new(0, tall / 2, 0) }, Enum.EasingStyle.Back)
		end)
		local bud = part(Vector3.one * 0.5 * k, lean, LIME, 0, Enum.PartType.Ball)
		later(0.04 + i * 0.02, function()
			tween(bud, 0.2, { CFrame = lean * CFrame.new(0, tall, 0), Size = Vector3.one * 0.7 * k }, Enum.EasingStyle.Back)
		end)
		table.insert(vines, vine)
		table.insert(vines, bud)
	end
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		chunk(
			floor + UP * 0.5 * k,
			Vector3.one * (0.4 + math.random() * 0.4),
			Color3.fromRGB(90, 70, 50),
			outward(angle) * (8 + math.random() * 8) + UP * (16 + math.random() * 10)
		)
	end
	rumble(floor, 0.4, 0.3, 26)
	-- Bursts up wide open, snaps shut, holds them, sinks back.
	animate(0.16, function(alpha)
		pose(math.rad(70 - alpha * 10), alpha * span * 1.7)
	end, function()
		animate(0.07, function(alpha)
			pose(math.rad(60 - alpha * 58), span * 1.7)
		end, function()
			flash(floor + UP * 2 * k, LIME, 9, 22, 0.3)
			CombatFx.burst(floor + UP * span, LIME, "Drips", 2)
			rays(floor + UP * span, LIME, 14, radius * 0.9, 0.3)
			motes(floor + UP * span, LIME, 14, 10, 12, 0.3, 0.9)
			halo(floor + UP * span, FOAM, k, radius * 2, 0.35, Vector3.new(1, 0, 0), 0.3)
			shockwave(floor + UP * 0.1, 2 * k, radius * 2.6, LIME, 0.4, 0.3)
			-- A cloud of spores puffs out of the shut jaws.
			for i = 1, 6 do
				local angle = i / 6 * math.pi * 2
				local s = (1.2 + math.random()) * k
				local puff = ellipsoid(Vector3.one * s, CFrame.new(floor + UP * span), TOXIC, 0.4, Enum.Material.SmoothPlastic)
				fade(puff, 1.2, { CFrame = CFrame.new(floor + outward(angle) * radius * 0.8 + UP * (span + 2 * k)), Size = Vector3.one * s * 2.4 }, Enum.EasingStyle.Quart)
			end
			linger(floor, TOXIC, radius * 0.8, 1.6, nil, LIME)
			rumble(floor, 0.8, 0.3, 30)
			CombatSound.play("GuardBreak", floor, { Volume = 1, Pitch = 0.8 })
			CombatSound.element("Impact", "Poison", floor, { Volume = 1 })
			local born = os.clock()
			animate(1.3, function()
				pose(math.rad(2 + math.sin((os.clock() - born) * 12) * 2), span * 1.7)
			end, function()
				animate(0.3, function(alpha)
					pose(math.rad(2 + alpha * 30), span * 1.7 * (1 - alpha))
				end, function()
					for _, jaw in jaws do
						for _, piece in jaw.Pieces do
							fade(piece.Part, 0.15)
						end
					end
					fade(stalk, 0.15)
					fade(glow, 0.15)
					for _, leaf in leaves do
						fade(leaf, 0.4)
					end
					for _, vine in vines do
						fade(vine, 0.4, { Size = vine.Size * 0.3 })
					end
				end)
			end)
		end)
	end)
	CombatSound.play("Corrode", floor, { Volume = 1 })
end

-- The show for a name ------------------------------------------------------------------

function MoveVfx.show(who: any, name: string, ...)
	local draw = SHOW[name]
	if not draw then
		return
	end
	local ok, err = pcall(draw, who, ...)
	if not ok then
		warn("MoveVfx." .. name .. ": " .. tostring(err))
	end
end

-- While it's cast ----------------------------------------------------------------------

local CAST: { [string]: (BasePart, number) -> () } = {}

-- Skybreaker: lightning finds your raised blade.
CAST.Q_Skybreaker = function(root, seconds)
	local hand = root.CFrame * CFrame.new(0.8, 3.4, -0.6)
	CombatVfx.lightning(hand.Position + UP * 40, hand.Position, VOLT)
	local spark = part(Vector3.one * 0.9, hand, WHITE, 0.1, Enum.PartType.Ball)
	light(spark, VOLT, 6, 18)
	emitter(attach(spark), VOLT, 40, { Size = 0.35, Speed = 6, Life = 0.2, Acceleration = Vector3.zero })
	animate(seconds, function(_alpha, elapsed)
		spark.CFrame = root.CFrame * CFrame.new(0.8, 3.4, -0.6)
		spark.Size = Vector3.one * (0.8 + math.sin(elapsed * 40) * 0.25)
		if math.random() < 0.18 then
			CombatVfx.lightning(
				spark.Position,
				spark.Position + Vector3.new(math.random() - 0.5, -math.random(), math.random() - 0.5) * 3,
				ARC
			)
		end
	end, function()
		fade(spark, 0.1)
	end)
	CombatSound.play("Zap", hand.Position, { Volume = 1, Pitch = 0.9 })
end

-- Ion Cannon: a ball of charge swells in front of you.
CAST.E_IonCannon = function(root, seconds)
	local orb = part(Vector3.one * 0.3, root.CFrame * CFrame.new(0, 0.6, -2), WHITE, 0, Enum.PartType.Ball)
	local halo = part(Vector3.one * 0.6, orb.CFrame, ARC, 0.4, Enum.PartType.Ball)
	local glow = light(orb, ARC, 2, 12)
	emitter(attach(orb), ARC, 50, { Size = 0.3, Speed = -6, Life = 0.35, Acceleration = Vector3.zero })
	animate(seconds, function(alpha, elapsed)
		local at = root.CFrame * CFrame.new(0, 0.6, -2)
		orb.CFrame = at
		halo.CFrame = at * CFrame.Angles(elapsed * 6, elapsed * 4, 0)
		orb.Size = Vector3.one * (0.3 + alpha * 1.3)
		halo.Size = Vector3.one * (0.6 + alpha * 2.2 + math.sin(elapsed * 30) * 0.2)
		glow.Brightness = 2 + alpha * 8
	end, function()
		fade(orb, 0.1, { Size = Vector3.one * 3 })
		fade(halo, 0.1)
	end)
	CombatSound.play("Beam", root.Position, { Volume = 0.6, Pitch = 0.5 })
end

-- Supernova: a small sun gathers above your hand, rings of light pulled in to it.
CAST.E_Supernova = function(root, seconds)
	local sun = part(Vector3.one * 0.4, root.CFrame * CFrame.new(0, 4, -1), HOT, 0, Enum.PartType.Ball)
	local corona = part(Vector3.one * 0.8, sun.CFrame, FLAME, 0.45, Enum.PartType.Ball)
	local glow = light(sun, EMBER, 3, 18)
	emitter(
		attach(sun),
		FLAME,
		40,
		{ Texture = FIRE_TEXTURE, Size = 1, Speed = -3, Life = 0.4, Acceleration = Vector3.zero }
	)
	local lastRing = -1
	animate(seconds, function(alpha, elapsed)
		local at = root.CFrame * CFrame.new(0, 4, -1)
		sun.CFrame = at
		corona.CFrame = at
		sun.Size = Vector3.one * (0.4 + alpha * 2)
		corona.Size = Vector3.one * (0.8 + alpha * 3.2 + math.sin(elapsed * 20) * 0.3)
		glow.Brightness = 3 + alpha * 7
		if elapsed - lastRing > 0.12 and not busy() then
			lastRing = elapsed
			local ring = part(Vector3.new(0.1, 9, 9), at * CFrame.Angles(math.random() * 3, math.random() * 3, 0), HOT, 0.4, Enum.PartType.Cylinder)
			fade(ring, 0.25, { Size = Vector3.new(0.05, 1, 1) })
		end
	end, function()
		fade(sun, 0.12)
		fade(corona, 0.12)
	end)
end

-- Flame Tornado: fire whirls up around you.
CAST.E_FlameTornado = function(root, seconds)
	local flames = {}
	for i = 1, 8 do
		table.insert(flames, part(Vector3.new(0.6, 1.4, 0.6), root.CFrame, if i % 2 == 0 then FLAME else HOT, 0.2))
	end
	animate(seconds, function(alpha, elapsed)
		for i, f in flames do
			local angle = elapsed * 10 + i / #flames * math.pi * 2
			local h = -2.5 + (i % 4) * 0.9 + alpha * 1.5
			f.CFrame = root.CFrame * CFrame.new(math.cos(angle) * 2.2, h, math.sin(angle) * 2.2)
		end
	end, function()
		for _, f in flames do
			fade(f, 0.15)
		end
	end)
end

-- Frost Chakram: the ice blade forms in your hand, frost sparkling off it.
CAST.Q_FrostChakram = function(root, seconds)
	local blade = glass(Vector3.new(0.2, 0.4, 0.4), root.CFrame, ICE, 0.2)
	blade.Shape = Enum.PartType.Cylinder
	light(blade, DEEP_ICE, 3, 10)
	emitter(attach(blade), WHITE, 30, { Size = 0.25, Speed = 1, Life = 0.3, Acceleration = Vector3.new(0, -3, 0) })
	animate(seconds, function(alpha, elapsed)
		blade.CFrame = root.CFrame * CFrame.new(1.4, 0.4, -0.8) * CFrame.Angles(0, elapsed * 20, 0) * FLAT
		blade.Size = Vector3.new(0.2, 0.4 + alpha * 2.8, 0.4 + alpha * 2.8)
	end, function()
		fade(blade, 0.05)
	end)
end

-- Viper Lash: venom coils along your blade.
CAST.Q_ViperLash = function(root, seconds)
	CombatFx.burst(root.Position + UP, LIME, "Drips", 0.8)
	local coil = part(Vector3.new(0.3, 0.3, 2.4), root.CFrame, LIME, 0.2)
	animate(seconds, function(_alpha, elapsed)
		coil.CFrame = root.CFrame * CFrame.new(1, 0.6, -1.2) * CFrame.Angles(0, 0, elapsed * 25)
	end, function()
		fade(coil, 0.05)
	end)
end

-- Toxic Tide: acid wells up at your feet.
CAST.E_ToxicTide = function(root, seconds)
	local floor = floorUnder(root.Position)
	local pool = disc(floor + UP * 0.05, 1, LIME, 0.3)
	tween(pool, seconds, { Size = Vector3.new(0.08, 7, 7) })
	CombatFx.burst(floor + UP * 0.5, LIME, "Drips", 1.2)
	later(seconds, function()
		fade(pool, 0.3)
	end)
end

-- Storm Call and Hailstorm: the sky over you darkens.
local function gather(root: BasePart, seconds: number, color: Color3)
	local cloud = part(
		Vector3.new(4, 1.5, 4),
		root.CFrame * CFrame.new(0, 7, 0),
		color,
		1,
		Enum.PartType.Ball,
		Enum.Material.SmoothPlastic
	)
	tween(cloud, seconds, { Transparency = 0.2, Size = Vector3.new(7, 2.4, 7) })
	later(seconds, function()
		fade(cloud, 0.4)
	end)
end
CAST.E_StormCall = function(root, seconds)
	gather(root, seconds, STORM)
	CombatVfx.lightning(root.Position + UP * 7, root.Position + UP * 3.4, VOLT)
end
CAST.E_Hailstorm = function(root, seconds)
	gather(root, seconds, SLATE)
	CombatFx.burst(root.Position + UP * 3, ICE, "Frost", 1)
end

-- Meteor Leap: embers gather in your crouch, the ground glowing under you.
CAST.Q_MeteorLeap = function(root, seconds)
	local floor = floorUnder(root.Position)
	CombatFx.burst(root.Position - UP * 2, EMBER, "Embers", 1.2)
	local glow = disc(floor + UP * 0.05, 5, EMBER, 0.4)
	tween(glow, seconds, { Size = Vector3.new(0.08, 2, 2), Transparency = 0.1 })
	light(glow, EMBER, 3, 12)
	later(seconds, function()
		fade(glow, 0.15)
	end)
end

-- Magma Fault: the ground glows and cracks under your feet as you raise the blade.
CAST.Q_MagmaFault = function(root, seconds)
	local floor = floorUnder(root.Position)
	local glow = disc(floor + UP * 0.05, 1, MAGMA, 0.4)
	tween(glow, seconds, { Size = Vector3.new(0.08, 6, 6), Transparency = 0.15 })
	light(glow, EMBER, 3, 12)
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2 + math.random() * 0.5
		local base = CFrame.new(floor + UP * 0.07) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		local crack = part(Vector3.new(0.25, 0.06, 0.3), base, MAGMA, 0.1)
		tween(crack, seconds, { Size = Vector3.new(0.25, 0.06, 3), CFrame = base * CFrame.new(0, 0, -1.5) })
		later(seconds, function()
			fade(crack, 0.2)
		end)
	end
	CombatFx.burst(floor + UP * 0.5, EMBER, "Embers", 1)
	later(seconds, function()
		fade(glow, 0.2)
	end)
end

-- Permafrost Spire: frost gathers on the blade, the air around it crackling cold.
CAST.Q_PermafrostSpire = function(root, seconds)
	local shard = glass(Vector3.new(0.4, 0.4, 0.4), root.CFrame, ICE, 0.15)
	light(shard, DEEP_ICE, 3, 12)
	emitter(attach(shard), ICE, 30, { Size = 0.3, Speed = -3, Life = 0.35, Acceleration = Vector3.zero })
	local ice = disc(floorUnder(root.Position) + UP * 0.05, 1, FROST, 0.5, Enum.Material.Glass)
	tween(ice, seconds, { Size = Vector3.new(0.08, 5, 5) })
	animate(seconds, function(alpha, elapsed)
		shard.CFrame = root.CFrame * CFrame.new(1, 1.2, -1) * CFrame.Angles(elapsed * 6, elapsed * 9, 0)
		shard.Size = Vector3.new(0.4, 0.4 + alpha * 2.2, 0.4)
	end, function()
		fade(shard, 0.1)
		fade(ice, 0.3)
	end)
end

-- Absolute Zero: the cold draws in: frost spirals into a point in front of you.
CAST.E_AbsoluteZero = function(root, seconds)
	local heart = part(Vector3.one * 0.3, root.CFrame * CFrame.new(0, 0.5, -2), WHITE, 0, Enum.PartType.Ball)
	light(heart, DEEP_ICE, 2, 14)
	emitter(attach(heart), ICE, 60, { Size = 0.35, Speed = -8, Life = 0.4, Acceleration = Vector3.zero })
	local orbit = {}
	for i = 1, 6 do
		table.insert(orbit, glass(Vector3.new(0.3, 0.9, 0.3), heart.CFrame, if i % 2 == 0 then ICE else DEEP_ICE, 0.1))
	end
	animate(seconds, function(alpha, elapsed)
		local at = root.CFrame * CFrame.new(0, 0.5, -2)
		heart.CFrame = at
		heart.Size = Vector3.one * (0.3 + alpha * 1.4)
		for i, o in orbit do
			local angle = elapsed * 9 + i / #orbit * math.pi * 2
			local reach = 3 * (1 - alpha * 0.7)
			o.CFrame = at * CFrame.Angles(0, angle, 0) * CFrame.new(reach, math.sin(elapsed * 6 + i) * 0.6, 0) * CFrame.Angles(0, 0, elapsed * 5)
		end
	end, function()
		fade(heart, 0.1, { Size = Vector3.one * 3 })
		for _, o in orbit do
			fade(o, 0.1)
		end
	end)
	CombatFx.burst(root.Position, ICE, "Frost", 1)
end

-- Thunder Dash: static builds on you, arcs jumping off your body.
CAST.Q_ThunderDash = function(root, seconds)
	local charge = part(Vector3.one * 0.6, root.CFrame, WHITE, 0.3, Enum.PartType.Ball)
	light(charge, VOLT, 4, 14)
	emitter(attach(charge), VOLT, 40, { Size = 0.3, Speed = 5, Life = 0.2, Acceleration = Vector3.zero })
	animate(seconds, function(_alpha, elapsed)
		charge.CFrame = root.CFrame * CFrame.new(0, 0.4, 0)
		charge.Size = Vector3.one * (0.5 + math.sin(elapsed * 50) * 0.2)
		if math.random() < 0.3 and not busy() then
			local from = root.Position + Vector3.new(math.random() - 0.5, math.random() * 3 - 2, math.random() - 0.5) * 1.4
			CombatVfx.lightning(from, from + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3, ARC)
		end
	end, function()
		fade(charge, 0.05)
	end)
end

-- Toxic Flask: the flask bubbles and glows in your hand.
CAST.Q_ToxicFlask = function(root, seconds)
	local bulb = glass(Vector3.one * 0.9, root.CFrame, LIME, 0.15)
	bulb.Shape = Enum.PartType.Ball
	local brew = part(Vector3.one * 0.6, root.CFrame, TOXIC, 0.1, Enum.PartType.Ball)
	local glow = light(brew, LIME, 2, 10)
	emitter(attach(brew), FOAM, 30, { Size = 0.25, Speed = 1.5, Life = 0.4, Acceleration = Vector3.new(0, 3, 0), Light = 0.5 })
	animate(seconds, function(alpha, elapsed)
		local at = root.CFrame * CFrame.new(1.2, 0.8, -0.8)
		bulb.CFrame = at
		brew.CFrame = at
		brew.Size = Vector3.one * (0.6 + math.sin(elapsed * 30) * 0.08)
		glow.Brightness = 2 + alpha * 5
	end, function()
		fade(bulb, 0.05)
		fade(brew, 0.05)
	end)
end

-- Maneater: vines writhe up round your feet.
CAST.E_Maneater = function(root, seconds)
	local floor = floorUnder(root.Position)
	local vines = {}
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local lean = CFrame.new(floor + outward(angle) * 1.6) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(30))
		local vine = part(Vector3.new(0.25, 0.2, 0.25), lean, if i % 2 == 0 then VENOM else TOXIC, 0, nil, Enum.Material.SmoothPlastic)
		tween(vine, seconds, { Size = Vector3.new(0.25, 2.5, 0.25), CFrame = lean * CFrame.new(0, 1.25, 0) }, Enum.EasingStyle.Back)
		table.insert(vines, vine)
	end
	local soil = disc(floor + UP * 0.04, 1, VENOM, 0.4)
	tween(soil, seconds, { Size = Vector3.new(0.08, 5, 5) })
	light(soil, LIME, 2, 10)
	CombatFx.burst(floor + UP * 0.5, Color3.fromRGB(110, 85, 60), "Smoke", 1)
	later(seconds, function()
		for _, v in vines do
			fade(v, 0.2, { Size = Vector3.new(0.1, 0.1, 0.1) })
		end
		fade(soil, 0.3)
	end)
end

function MoveVfx.cast(who: any, id: string?, seconds: number?)
	local draw = id and CAST[id]
	local root = rootOf(who)
	if not draw or not root then
		return
	end
	local ok, err = pcall(draw, root, math.max(0.15, seconds or 0.3))
	if not ok then
		warn("MoveVfx cast " .. tostring(id) .. ": " .. tostring(err))
	end
end

MoveVfx._shows = SHOW
MoveVfx._casts = CAST
return MoveVfx
