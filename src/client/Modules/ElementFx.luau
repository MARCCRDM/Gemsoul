--[[
	The elements on the ground (client only, nothing replicates): how a
	blast is warned of and goes off, how a lingering area looks, a heavy
	blow's stomp, and a creature's bolt and lobbed bomb, each in its
	element's own look. Kaiju, critters and players' blasts all draw with
	these (Combat.client's Nova, Telegraph, Zone and Shot).

	  ElementFx.telegraph(floor, radius, element, seconds, zones?)
	      the warning before a blast lands: a bright edge, a fill sweeping
	      out from the middle to the edge as the moment comes (so you can see
	      when), and the element stirring inside it: embers and glowing
	      cracks, frost creeping, sparks crawling, bubbles. `zones` = { a
	      share of the radius, ... }: inner rings (a player's blast: the core
	      that stuns, the middle that staggers)
	  ElementFx.erupt(floor, radius, element)
	      the blast itself, out of the ground: a geyser of flame; a spire of
	      ice bursting up and shattering; lightning striking down out of the
	      sky and crawling out along the ground; a geyser of acid raining
	      back down. With a shockwave, a scorch, embers, smoke and a shake
	  ElementFx.field(floor, radius, seconds, element)
	      ground that stays dangerous: burning ground licked by flames; a
	      sheet of ice with frost mist and spikes popping up; a field
	      crackling with arcs; a bubbling pool of acid with fumes rising
	  ElementFx.stomp(floor, radius, element)
	      a heavy blow's landing: a ring of dust and a flourish of the element
	  ElementFx.bolt(from, to, element)
	      a creature's shot: a fireball, an ice lance, a lightning bolt, a
	      glob of acid, and where it lands
	  ElementFx.lob(from, to, element, seconds)
	      a bomb arcing over (it lands as a blast: erupt)
	  ElementFx.spine(from, to, element)
	      a Razorback's spine, a glowing quill streaking in its element's
	      colour, and its element where it sticks

	`element` is "Fire", "Frost", "Shock" or "Poison", or a Color3 (an
	element's colour is read as that element; any other is drawn as plain
	energy: a flash, a shockwave and dust, never a column of light).
	Everything is drawn at the size of whoever made it (FxSize).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)
local CombatVfx = require(script.Parent.CombatVfx)
local FxSize = require(script.Parent.FxSize)
local GemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemConfig"))

local ElementFx = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Each element's palette: Core (white-hot), Main, Deep (its dark end),
-- Ground (what it leaves on the ground).
ElementFx.Palettes = {
	Fire = {
		Core = Color3.fromRGB(255, 236, 170),
		Main = Color3.fromRGB(255, 120, 34),
		Deep = Color3.fromRGB(196, 32, 14),
		Ground = Color3.fromRGB(58, 22, 14),
	},
	Frost = {
		Core = Color3.fromRGB(236, 250, 255),
		Main = Color3.fromRGB(130, 205, 255),
		Deep = Color3.fromRGB(40, 110, 220),
		Ground = Color3.fromRGB(176, 220, 248),
	},
	Shock = {
		Core = Color3.fromRGB(255, 255, 230),
		Main = Color3.fromRGB(255, 226, 70),
		Deep = Color3.fromRGB(150, 120, 255),
		Ground = Color3.fromRGB(40, 36, 70),
	},
	Poison = {
		Core = Color3.fromRGB(210, 255, 150),
		Main = Color3.fromRGB(90, 220, 80),
		Deep = Color3.fromRGB(28, 110, 40),
		Ground = Color3.fromRGB(26, 70, 30),
	},
}

-- The element `what` names (an element, or an element's colour), or nil.
function ElementFx.elementOf(what: any): string?
	if type(what) == "string" then
		return if ElementFx.Palettes[what] then what else nil
	end
	if typeof(what) == "Color3" then
		return GemConfig.elementOfColor(what)
	end
	return nil
end

-- Parts -------------------------------------------------------------------------------------------

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "ElementFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

-- Too much alive already (a big fight): the optional extras are skipped.
local function busy(): boolean
	return #fxFolder():GetChildren() > 320
end

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
	p.Transparency = transparency or 0
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.CFrame = cframe
	p.Parent = fxFolder()
	return p
end

local function tween(p: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, out: boolean?)
	TweenService:Create(
		p,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			if out == false then Enum.EasingDirection.In else Enum.EasingDirection.Out
		),
		goal
	):Play()
end

-- Fades a part out (and away) over `seconds`, with whatever else changes.
local function fade(p: BasePart, seconds: number, goal: { [string]: any }?, style: Enum.EasingStyle?)
	local to: { [string]: any } = goal and table.clone(goal) or {}
	to.Transparency = 1
	tween(p, seconds, to, style)
	Debris:AddItem(p, seconds + 0.05)
end

-- A flat disc on the ground (a cylinder on its side), `diameter` across.
local function disc(at: Vector3, diameter: number, color: Color3, transparency: number, material: Enum.Material?): Part
	return part(
		Vector3.new(0.06, diameter, diameter),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		transparency,
		Enum.PartType.Cylinder,
		material
	)
end

-- A thin bright ring on the ground: short bars round the edge.
local function ring(center: Vector3, radius: number, color: Color3, transparency: number, width: number): { Part }
	local bars = {}
	local count = math.clamp(math.floor(radius * 2.2), 14, 32)
	local length = 2 * math.pi * radius / count * 1.08
	for i = 1, count do
		local a = (i - 0.5) / count * math.pi * 2
		local at = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		table.insert(
			bars,
			part(Vector3.new(width, width * 0.5, length), CFrame.new(at) * CFrame.Angles(0, -a, 0), color, transparency)
		)
	end
	return bars
end

-- A frame at `at` looking along `dir` (straight up too, where lookAt has
-- no "up" to go by).
local function aim(at: Vector3, dir: Vector3): CFrame
	local look = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.new(0, 0, -1)
	local guess = if math.abs(look.Y) > 0.98 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = look:Cross(guess).Unit
	local up = right:Cross(look)
	return CFrame.fromMatrix(at, right, up, -look)
end

local function jitter(amount: number): Vector3
	return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * amount
end

-- A spot inside the circle (more of them towards the middle).
local function spotIn(center: Vector3, radius: number): Vector3
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

-- An emitter at `at` that pours for `seconds` (Rate a second), then
-- stops; it and its particles go once they've burnt out.
local function pour(
	at: CFrame,
	seconds: number,
	spec: {
		Texture: string,
		Rate: number,
		Colors: { Color3 },
		Size: { number },
		Speed: { number },
		Life: { number },
		Spread: number?,
		Accel: Vector3?,
		Drag: number?,
		Light: number?,
		Transparency: { number }?,
		Spin: number?,
		Burst: number?,
	}
)
	local anchor = part(Vector3.one * 0.2, at, WHITE, 1)
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.Texture
	local colors = spec.Colors
	if #colors == 1 then
		e.Color = ColorSequence.new(colors[1])
	else
		local keys = {}
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		e.Color = ColorSequence.new(keys)
	end
	local sizes = {}
	for i, s in spec.Size do
		table.insert(sizes, NumberSequenceKeypoint.new((i - 1) / (#spec.Size - 1), s))
	end
	e.Size = NumberSequence.new(sizes)
	local t = spec.Transparency or { 0, 1 }
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, t[1]),
		NumberSequenceKeypoint.new(1, t[2]),
	})
	e.Speed = NumberRange.new(spec.Speed[1], spec.Speed[2])
	e.Lifetime = NumberRange.new(spec.Life[1], spec.Life[2])
	e.SpreadAngle = Vector2.new(spec.Spread or 10, spec.Spread or 10)
	e.Acceleration = spec.Accel or Vector3.zero
	e.Drag = spec.Drag or 0
	e.LightEmission = spec.Light or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(spec.Spin or 90), spec.Spin or 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = spec.Rate
	e.Parent = attachment
	if spec.Burst then
		e:Emit(spec.Burst)
	end
	task.delay(seconds, function()
		e.Enabled = false
	end)
	Debris:AddItem(anchor, seconds + spec.Life[2] + 0.1)
end

-- A soft ball of flame that swells, rises and burns down to an ember.
local function flame(at: Vector3, size: number, rise: number, seconds: number, palette)
	local puff = part(Vector3.one * size * 0.6, CFrame.new(at), palette.Core, 0.2, Enum.PartType.Ball)
	tween(puff, seconds * 0.3, { Color = palette.Main })
	fade(puff, seconds, {
		Size = Vector3.one * size * 1.4,
		CFrame = CFrame.new(at + Vector3.new(0, rise, 0)),
	}, Enum.EasingStyle.Sine)
	task.delay(seconds * 0.3, function()
		if puff.Parent then
			tween(puff, seconds * 0.7, { Color = palette.Deep })
		end
	end)
end

-- A geyser: puffs climbing out of the ground one on another, `tall` high,
-- swelling and burning out (flame, or acid in its palette).
local function column(floor: Vector3, tall: number, wide: number, palette, count: number)
	for i = 0, count - 1 do
		local t = i / count
		task.delay(
			t * 0.16,
			FxSize.keep(function()
				local size = wide * (1.7 - t * 0.9)
				local at = floor
					+ Vector3.new(
						(math.random() - 0.5) * wide * 0.3,
						tall * t * 0.75 + size * 0.3,
						(math.random() - 0.5) * wide * 0.3
					)
				flame(at, size, tall * 0.3, 0.55 - t * 0.2, palette)
			end)
		)
	end
end

-- An ice spike stabbing up out of `base` along `dir`, holding, then
-- breaking off and crumbling.
local function spike(base: Vector3, dir: Vector3, length: number, width: number, hold: number, palette)
	local p =
		part(Vector3.new(width * 0.3, width * 0.3, 0.1), aim(base, dir), palette.Core, 0.12, nil, Enum.Material.Glass)
	p.Reflectance = 0.35
	tween(p, 0.14, {
		Size = Vector3.new(width, width, length),
		CFrame = aim(base + dir * length * 0.5, dir) * CFrame.Angles(0, 0, math.rad(45)),
	}, Enum.EasingStyle.Back)
	local edge = part(Vector3.new(width * 0.2, width * 0.2, 0.1), aim(base, dir), palette.Main, 0.3)
	tween(edge, 0.14, {
		Size = Vector3.new(width * 0.25, width * 0.25, length * 0.95),
		CFrame = aim(base + dir * length * 0.5, dir),
	}, Enum.EasingStyle.Back)
	task.delay(hold, function()
		if p.Parent then
			fade(p, 0.3, {
				Size = Vector3.new(width * 0.3, width * 0.3, length * 0.4),
				CFrame = p.CFrame * CFrame.Angles(math.random() - 0.5, 0, math.random() - 0.5)
					- Vector3.new(0, length * 0.3, 0),
			})
		end
		if edge.Parent then
			fade(edge, 0.2)
		end
	end)
end

-- Droplets of acid flung up and out, falling back.
local function droplets(at: Vector3, count: number, reach: number, height: number, palette, k: number)
	for _ = 1, count do
		local out = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			out = out.Unit
			local size = (0.2 + math.random() * 0.3) * k
			local drop = part(
				Vector3.one * size,
				CFrame.new(at),
				palette.Main:Lerp(palette.Core, math.random() * 0.6),
				0.05,
				Enum.PartType.Ball
			)
			local up = 0.18 + math.random() * 0.12
			local peak = at + out * reach * 0.35 + Vector3.new(0, height * (0.6 + math.random() * 0.6), 0)
			local land = at + out * reach * (0.6 + math.random() * 0.6)
			tween(drop, up, { CFrame = CFrame.new(peak) })
			task.delay(up, function()
				if drop.Parent then
					fade(
						drop,
						0.3,
						{ CFrame = CFrame.new(land), Size = Vector3.new(size * 1.6, size * 0.3, size * 1.6) },
						Enum.EasingStyle.Quad
					)
				end
			end)
		end
	end
end

-- A dust shockwave racing out along the ground.
local function shockwave(floor: Vector3, radius: number, color: Color3, seconds: number?)
	local wave = disc(floor + Vector3.new(0, 0.08, 0), radius * 0.3, color, 0.35)
	fade(wave, seconds or 0.4, { Size = Vector3.new(0.03, radius * 2.4, radius * 2.4) })
	CombatFx.burst(floor + Vector3.new(0, 0.4, 0), Color3.fromRGB(140, 130, 120), "Smoke", 0.8 + radius / 10)
end

-- The ground shakes you, the closer the harder (`within` studs past its edge).
local function shakeNear(floor: Vector3, radius: number, strength: number)
	local k = FxSize.get()
	CombatFx.shakeNear(floor, strength, 0.35, radius + 14 * k)
end

-- The warning --------------------------------------------------------------------------------------

function ElementFx.telegraph(floor: Vector3, radius: number, element: any, seconds: number, zones: { number }?)
	seconds = math.max(0.05, seconds)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	local made: { BasePart } = {}
	local function keep(p: BasePart)
		table.insert(made, p)
		return p
	end
	-- The area, darkened; its edge bright.
	keep(disc(floor + Vector3.new(0, 0.03, 0), radius * 2, if palette then palette.Deep else color, 0.72))
	for _, bar in ring(floor + Vector3.new(0, 0.07, 0), radius, color:Lerp(WHITE, 0.25), 0.05, 0.24 * math.max(k, 0.6)) do
		keep(bar)
	end
	-- The fill sweeping out to the edge: when it gets there, it goes off.
	local fill = keep(disc(floor + Vector3.new(0, 0.05, 0), 0.1, color, 0.5))
	tween(fill, seconds, { Size = Vector3.new(0.06, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	-- The inner zones, as thin rings.
	for i, share in zones or {} do
		for _, bar in
			ring(
				floor + Vector3.new(0, 0.09, 0),
				radius * share,
				color:Lerp(WHITE, 0.3 + 0.3 * i),
				0.25,
				0.14 * math.max(k, 0.6)
			)
		do
			keep(bar)
		end
	end
	-- Fire cracks the ground: glowing seams out from the middle.
	if name == "Fire" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2 + math.random() * 0.6
			local length = radius * (0.55 + math.random() * 0.4)
			local mid = floor + Vector3.new(math.cos(a), 0, math.sin(a)) * length * 0.5 + Vector3.new(0, 0.1, 0)
			local crack = keep(
				part(
					Vector3.new(0.18 * k, 0.05, length),
					CFrame.new(mid) * CFrame.Angles(0, -a + math.pi / 2, 0),
					palette.Core,
					0.9
				)
			)
			tween(crack, seconds, { Transparency = 0.1, Size = Vector3.new(0.3 * k, 0.05, length) })
		end
	end
	-- The element stirring inside until it goes off.
	task.spawn(FxSize.keep(function()
		local stop = os.clock() + seconds
		local step = math.clamp(seconds / 6, 0.08, 0.2)
		while os.clock() < stop and fill.Parent do
			local at = spotIn(floor, radius * 0.9)
			if name == "Fire" then
				CombatFx.burst(at + Vector3.new(0, 0.3, 0), palette.Main, "Embers", 0.35)
			elseif name == "Frost" then
				CombatFx.burst(at + Vector3.new(0, 0.3, 0), palette.Main, "Frost", 0.3)
				if not busy() then
					local frost = disc(at + Vector3.new(0, 0.06, 0), 0.4 * k, palette.Core, 0.3, Enum.Material.Ice)
					fade(frost, 0.6, { Size = Vector3.new(0.04, 1.6 * k, 1.6 * k) })
				end
			elseif name == "Shock" then
				local edge = floor
					+ Vector3.new(math.cos(math.random() * 6.3), 0.2, math.sin(math.random() * 6.3)) * radius
				CombatVfx.lightning(edge, at + Vector3.new(0, 0.2, 0), palette.Main)
			elseif name == "Poison" then
				if not busy() then
					local bubble = part(Vector3.one * 0.35 * k, CFrame.new(at), palette.Core, 0.25, Enum.PartType.Ball)
					fade(
						bubble,
						0.45,
						{ Size = Vector3.one * 0.9 * k, CFrame = CFrame.new(at + Vector3.new(0, 0.6 * k, 0)) }
					)
				end
			end
			-- (the edge pulses quicker as it comes)
			local left = math.max(0, stop - os.clock())
			fill.Transparency = 0.42 + 0.18 * math.sin(os.clock() * (10 + 30 * (1 - left / seconds)))
			task.wait(step)
		end
	end))
	task.delay(seconds, function()
		for _, p in made do
			if p.Parent then
				fade(p, 0.15)
			end
		end
	end)
end

-- The blast --------------------------------------------------------------------------------------

local ERUPT = {}

-- A geyser of flame roaring up out of the ground, a ring of fire racing
-- out and burning down, embers and black smoke.
function ERUPT.Fire(floor: Vector3, radius: number, palette, k: number)
	local tall = math.max(radius * 1.3, 7 * k)
	local wide = math.max(radius * 0.35, 1.2 * k)
	pour(CFrame.new(floor), 0.32, {
		Texture = FIRE,
		Rate = 90,
		Burst = 18,
		Colors = { palette.Core, palette.Main, palette.Deep },
		Size = { wide * 1.6, wide * 2.4, wide * 0.8 },
		Speed = { tall * 1.6, tall * 2.4 },
		Life = { 0.35, 0.6 },
		Spread = 14,
		Accel = Vector3.new(0, tall, 0),
		Drag = 2.5,
		Light = 1,
		Transparency = { 0.05, 1 },
	})
	column(floor, tall, wide * 1.4, palette, 7)
	-- The fireball at its foot, swelling and burning out.
	local ball =
		part(Vector3.one * wide, CFrame.new(floor + Vector3.new(0, wide * 0.5, 0)), palette.Core, 0, Enum.PartType.Ball)
	tween(ball, 0.12, { Color = palette.Main })
	fade(
		ball,
		0.45,
		{ Size = Vector3.one * radius * 1.5, CFrame = CFrame.new(floor + Vector3.new(0, radius * 0.5, 0)) },
		Enum.EasingStyle.Sine
	)
	-- A ring of fire racing out, flames licking up all round it.
	local blaze = disc(floor + Vector3.new(0, 0.1, 0), radius * 0.3, palette.Main, 0.35)
	tween(blaze, 0.22, { Size = Vector3.new(0.06, radius * 2, radius * 2) })
	task.delay(0.22, function()
		if blaze.Parent then
			fade(blaze, 0.5, { Size = Vector3.new(0.03, radius * 2.15, radius * 2.15), Color = palette.Deep })
		end
	end)
	local count = math.clamp(math.floor(radius * 1.4), 6, 16)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		task.delay(
			0.12 + (i % 3) * 0.04,
			FxSize.keep(function()
				local spot = floor + out * radius * (0.85 + math.random() * 0.2)
				flame(
					spot + Vector3.new(0, 0.4 * k, 0),
					(1.4 + math.random()) * k,
					(1.5 + math.random()) * k,
					0.45,
					palette
				)
			end)
		)
	end
	CombatFx.burst(floor + Vector3.new(0, 1 * k, 0), palette.Main, "Embers", 1.2 + radius / 5)
	task.delay(
		0.25,
		FxSize.keep(function()
			pour(CFrame.new(floor + Vector3.new(0, tall * 0.5, 0)), 0.3, {
				Texture = SMOKE,
				Rate = 25,
				Colors = { Color3.fromRGB(70, 52, 44), Color3.fromRGB(40, 34, 32) },
				Size = { wide * 2, wide * 4 },
				Speed = { 2, 5 },
				Life = { 0.8, 1.3 },
				Spread = 40,
				Accel = Vector3.new(0, 4 * k, 0),
				Transparency = { 0.45, 1 },
			})
		end)
	)
end

-- A spire of ice bursting up out of the middle, more round it angled out,
-- frost spreading over the ground; it all shatters a moment later.
function ERUPT.Frost(floor: Vector3, radius: number, palette, k: number)
	local tall = math.max(radius * 1.1, 5 * k)
	spike(floor - Vector3.new(0, 0.3, 0), Vector3.new(0, 1, 0), tall, math.max(radius * 0.3, 1 * k), 0.65, palette)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		spike(
			floor + out * radius * 0.2,
			(out * 0.45 + Vector3.new(0, 1, 0)).Unit,
			tall * (0.5 + math.random() * 0.2),
			math.max(radius * 0.18, 0.6 * k),
			0.55,
			palette
		)
	end
	-- Frost spreading over the ground, a ring of spikes erupting at its edge.
	local frost = disc(floor + Vector3.new(0, 0.05, 0), radius * 0.3, palette.Ground, 0.35, Enum.Material.Ice)
	tween(frost, 0.25, { Size = Vector3.new(0.06, radius * 2, radius * 2) })
	task.delay(0.9, function()
		if frost.Parent then
			fade(frost, 0.6)
		end
	end)
	local count = math.clamp(math.floor(radius * 1.4), 6, 16)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.3
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = radius * (0.6 + (i % 2) * 0.3)
		task.delay(
			0.05 + reach / radius * 0.15,
			FxSize.keep(function()
				spike(
					floor + out * reach,
					(out * 0.5 + Vector3.new(0, 1, 0)).Unit,
					(1.4 + math.random() * 1.4) * k,
					0.45 * k,
					0.45,
					palette
				)
			end)
		)
	end
	CombatFx.burst(floor + Vector3.new(0, tall * 0.5, 0), palette.Main, "Frost", 1.4 + radius / 6)
	CombatFx.burst(floor + Vector3.new(0, tall * 0.7, 0), palette.Core, "Shards", 0.8)
	pour(CFrame.new(floor), 0.4, {
		Texture = SMOKE,
		Rate = 30,
		Colors = { palette.Core, palette.Main },
		Size = { radius * 0.4, radius * 0.9 },
		Speed = { radius * 0.8, radius * 1.4 },
		Life = { 0.6, 1 },
		Spread = 80,
		Drag = 3,
		Transparency = { 0.5, 1 },
	})
end

-- Lightning striking down out of the sky, twice, arcs crawling out along
-- the ground to the edge, sparks and a white flash.
function ERUPT.Shock(floor: Vector3, radius: number, palette, k: number)
	local sky = math.max(26 * k, radius * 3)
	for strike = 0, 1 do
		task.delay(
			strike * 0.09,
			FxSize.keep(function()
				local top = floor + Vector3.new((math.random() - 0.5) * radius, sky, (math.random() - 0.5) * radius)
				CombatVfx.lightning(top, floor + Vector3.new(0, 0.3, 0), palette.Main)
				CombatVfx.lightning(
					top + jitter(2 * k),
					floor + jitter(radius * 0.4) + Vector3.new(0, 0.3, 0),
					palette.Core
				)
			end)
		)
	end
	local count = math.clamp(math.floor(radius * 0.9), 4, 9)
	for i = 1, count do
		task.delay(
			0.08 + i * 0.03,
			FxSize.keep(function()
				local a = i / count * math.pi * 2 + math.random() * 0.4
				local edge = floor + Vector3.new(math.cos(a) * radius, 0.25, math.sin(a) * radius)
				CombatVfx.lightning(
					floor + Vector3.new(0, 0.25, 0),
					edge,
					if i % 2 == 0 then palette.Main else palette.Deep
				)
			end)
		)
	end
	-- A dome of charge that flickers out, the ground left scorched.
	local dome = part(Vector3.one * radius * 0.6, CFrame.new(floor), palette.Core, 0.3, Enum.PartType.Ball)
	fade(dome, 0.3, { Size = Vector3.one * radius * 1.8, Color = palette.Main })
	CombatFx.burst(floor + Vector3.new(0, 0.6 * k, 0), palette.Main, "Sparks", 1.6 + radius / 6)
	CombatFx.flash(floor + Vector3.new(0, 4 * k, 0), WHITE, 9, radius * 3 + 10, 0.3)
end

-- A geyser of acid spouting up and raining back down, a pool spreading,
-- bubbling, and fumes rising off it.
function ERUPT.Poison(floor: Vector3, radius: number, palette, k: number)
	local tall = math.max(radius * 1.1, 5 * k)
	column(floor, tall * 0.8, math.max(radius * 0.4, 1.2 * k), palette, 6)
	droplets(floor + Vector3.new(0, 0.3, 0), math.clamp(math.floor(radius * 3), 10, 30), radius, tall, palette, k * 1.6)
	pour(CFrame.new(floor), 0.3, {
		Texture = SPARKLE,
		Rate = 70,
		Burst = 12,
		Colors = { palette.Core, palette.Main },
		Size = { 0.6 * k, 0.3 * k },
		Speed = { tall * 1.4, tall * 2 },
		Life = { 0.4, 0.7 },
		Spread = 12,
		Accel = Vector3.new(0, -tall * 3, 0),
		Light = 0.4,
	})
	pour(CFrame.new(floor), 0.6, {
		Texture = SMOKE,
		Rate = 22,
		Colors = { palette.Main, palette.Deep },
		Size = { radius * 0.5, radius * 1.1 },
		Speed = { 3 * k, 7 * k },
		Life = { 0.8, 1.3 },
		Spread = 35,
		Accel = Vector3.new(0, 3 * k, 0),
		Transparency = { 0.45, 1 },
	})
	local pool = disc(floor + Vector3.new(0, 0.05, 0), radius * 0.4, palette.Ground, 0.25)
	tween(pool, 0.35, { Size = Vector3.new(0.06, radius * 2, radius * 2) }, Enum.EasingStyle.Sine)
	local sheen = disc(floor + Vector3.new(0, 0.07, 0), radius * 0.2, palette.Main, 0.55)
	tween(sheen, 0.4, { Size = Vector3.new(0.05, radius * 1.6, radius * 1.6) }, Enum.EasingStyle.Sine)
	task.delay(1, function()
		if pool.Parent then
			fade(pool, 0.8)
		end
		if sheen.Parent then
			fade(sheen, 0.6)
		end
	end)
	CombatFx.burst(floor + Vector3.new(0, 0.5 * k, 0), palette.Main, "Drips", 1 + radius / 6)
end

function ElementFx.erupt(floor: Vector3, radius: number, element: any)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	if name then
		ERUPT[name](floor, radius, palette, k)
	else
		-- Plain energy: a flash dome and sparks.
		local dome =
			part(Vector3.one * radius * 0.4, CFrame.new(floor), color:Lerp(WHITE, 0.4), 0.15, Enum.PartType.Ball)
		fade(dome, 0.35, { Size = Vector3.one * radius * 2 })
		CombatFx.burst(floor + Vector3.new(0, 1 * k, 0), color, "Sparks", 1.5 + radius / 8)
	end
	-- Every blast: a shockwave out along the ground, a scorch, a shake.
	shockwave(floor, radius, color:Lerp(WHITE, 0.35))
	CombatVfx.scorch(floor, radius, color)
	CombatFx.burst(floor + Vector3.new(0, 0.5 * k, 0), Color3.fromRGB(110, 100, 92), "Shards", 1.2)
	CombatFx.flash(floor + Vector3.new(0, 3 * k, 0), color, 8, radius * 3, 0.45)
	shakeNear(floor, radius, 0.05)
end

-- The ground that stays dangerous --------------------------------------------------------------------

function ElementFx.field(floor: Vector3, radius: number, seconds: number, element: any)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	local ground = disc(
		floor + Vector3.new(0, 0.04, 0),
		radius * 0.4,
		if palette then palette.Ground else color:Lerp(BLACK, 0.6),
		if name == "Frost" then 0.25 else 0.3,
		if name == "Frost" then Enum.Material.Ice else nil
	)
	tween(ground, 0.3, { Size = Vector3.new(0.06, radius * 2, radius * 2) }, Enum.EasingStyle.Sine)
	local edge = ring(floor + Vector3.new(0, 0.08, 0), radius, color, 0.3, 0.2 * math.max(k, 0.6))
	CombatFx.burst(floor + Vector3.new(0, 0.5, 0), color, if name == "Frost" then "Frost" else "Smoke", 1 + radius / 8)
	task.spawn(FxSize.keep(function()
		local stop = os.clock() + seconds
		local beat = 0
		while os.clock() < stop and ground.Parent do
			beat += 1
			local at = spotIn(floor, radius * 0.92)
			local pulse = 0.25 + 0.2 * (0.5 + 0.5 * math.sin(os.clock() * 5))
			for _, bar in edge do
				bar.Transparency = pulse
			end
			if not busy() then
				if name == "Fire" then
					-- Flames licking up all over, embers drifting.
					flame(
						at + Vector3.new(0, 0.4 * k, 0),
						(1.5 + math.random()) * k,
						(1.8 + math.random() * 1.4) * k,
						0.5,
						palette
					)
					local other = spotIn(floor, radius * 0.92)
					flame(
						other + Vector3.new(0, 0.3 * k, 0),
						(1 + math.random() * 0.6) * k,
						(1.2 + math.random()) * k,
						0.4,
						palette
					)
					if beat % 2 == 0 then
						CombatFx.burst(at + Vector3.new(0, 0.5, 0), palette.Main, "Embers", 0.4)
					end
				elseif name == "Frost" then
					-- Frost mist, glitter, and now and then a spike popping up.
					CombatFx.burst(at + Vector3.new(0, 0.4, 0), palette.Core, "Frost", 0.3)
					if beat % 2 == 0 then
						spike(
							at,
							(jitter(0.5) + Vector3.new(0, 1, 0)).Unit,
							(1.3 + math.random() * 1.2) * k,
							0.45 * k,
							0.5,
							palette
						)
					end
					if beat % 2 == 0 then
						CombatFx.burst(at + Vector3.new(0, 0.3, 0), palette.Main, "Smoke", 0.4)
					end
				elseif name == "Shock" then
					-- Arcs leaping between points on the ground.
					local other = spotIn(floor, radius * 0.92)
					CombatVfx.lightning(
						at + Vector3.new(0, 0.2, 0),
						other + Vector3.new(0, 0.2, 0),
						if beat % 2 == 0 then palette.Main else palette.Deep
					)
				elseif name == "Poison" then
					-- Bubbles rising and popping, fumes curling up.
					local bubble = part(Vector3.one * 0.6 * k, CFrame.new(at), palette.Core, 0.2, Enum.PartType.Ball)
					fade(
						bubble,
						0.55,
						{ Size = Vector3.one * 1.6 * k, CFrame = CFrame.new(at + Vector3.new(0, 0.9 * k, 0)) },
						Enum.EasingStyle.Sine
					)
					local other = spotIn(floor, radius * 0.92)
					local small = part(Vector3.one * 0.35 * k, CFrame.new(other), palette.Main, 0.3, Enum.PartType.Ball)
					fade(
						small,
						0.4,
						{ Size = Vector3.one * 0.9 * k, CFrame = CFrame.new(other + Vector3.new(0, 0.5 * k, 0)) },
						Enum.EasingStyle.Sine
					)
					if beat % 2 == 0 then
						CombatFx.burst(at + Vector3.new(0, 0.4, 0), palette.Main, "Smoke", 0.55)
					end
				else
					CombatFx.burst(at + Vector3.new(0, 0.4, 0), color, "Smoke", 0.5)
				end
			end
			task.wait(if name == "Shock" then 0.09 else 0.13)
		end
		fade(ground, 0.4)
		for _, bar in edge do
			if bar.Parent then
				fade(bar, 0.3)
			end
		end
	end))
end

-- A heavy blow's landing -------------------------------------------------------------------------------

function ElementFx.stomp(floor: Vector3, radius: number, element: any)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	shockwave(floor, radius, Color3.fromRGB(196, 186, 176), 0.35)
	CombatFx.burst(floor + Vector3.new(0, 0.4 * k, 0), Color3.fromRGB(120, 110, 100), "Shards", 0.8)
	if name == "Fire" then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			flame(
				floor + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.8 + Vector3.new(0, 0.3 * k, 0),
				1.1 * k,
				1.2 * k,
				0.35,
				palette
			)
		end
		CombatFx.burst(floor + Vector3.new(0, 0.5 * k, 0), palette.Main, "Embers", 0.8)
	elseif name == "Frost" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2 + 0.3
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			spike(floor + out * radius * 0.7, (out * 0.6 + Vector3.new(0, 1, 0)).Unit, 1.3 * k, 0.4 * k, 0.3, palette)
		end
		CombatFx.burst(floor + Vector3.new(0, 0.5 * k, 0), palette.Main, "Frost", 0.8)
	elseif name == "Shock" then
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2 + math.random()
			CombatVfx.lightning(
				floor + Vector3.new(0, 0.2, 0),
				floor + Vector3.new(math.cos(a) * radius, 0.2, math.sin(a) * radius),
				palette.Main
			)
		end
	elseif name == "Poison" then
		droplets(floor + Vector3.new(0, 0.2, 0), 8, radius, 1.5 * k, palette, k)
		CombatFx.burst(floor + Vector3.new(0, 0.4 * k, 0), palette.Main, "Smoke", 0.6)
	else
		CombatFx.burst(floor + Vector3.new(0, 0.5 * k, 0), color, "Sparks", 0.8)
	end
	CombatFx.flash(floor + Vector3.new(0, 2 * k, 0), color, 4, radius * 2 + 6, 0.25)
	shakeNear(floor, radius, 0.025)
end

-- A creature's shot ------------------------------------------------------------------------------

-- Where a shot lands: the element bursting there.
local function splash(at: Vector3, name: string?, palette, color: Color3, k: number)
	if name == "Fire" then
		local ball = part(Vector3.one * 0.6 * k, CFrame.new(at), palette.Core, 0, Enum.PartType.Ball)
		fade(ball, 0.35, { Size = Vector3.one * 3 * k, Color = palette.Deep })
		for _ = 1, 3 do
			flame(at + jitter(1.2 * k), (0.9 + math.random() * 0.6) * k, 1.1 * k, 0.35, palette)
		end
		CombatFx.burst(at, palette.Main, "Embers", 0.8)
	elseif name == "Frost" then
		for _ = 1, 5 do
			local out = jitter(1) + Vector3.new(0, 0.3, 0)
			if out.Magnitude > 0.05 then
				spike(at, out.Unit, (0.9 + math.random()) * k, 0.25 * k, 0.25, palette)
			end
		end
		CombatFx.burst(at, palette.Main, "Frost", 0.8)
	elseif name == "Shock" then
		for _ = 1, 3 do
			local out = jitter(1)
			if out.Magnitude > 0.05 then
				CombatVfx.lightning(at, at + out.Unit * 2.5 * k, palette.Main)
			end
		end
	elseif name == "Poison" then
		droplets(at, 8, 2.5 * k, 1.2 * k, palette, k)
		CombatFx.burst(at, palette.Main, "Smoke", 0.6)
	else
		CombatFx.burst(at, color, "Sparks", 0.8)
	end
	CombatFx.flash(at, color, 4, 12, 0.25)
end

function ElementFx.bolt(from: Vector3, to: Vector3, element: any)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	local distance = (to - from).Magnitude
	if distance < 0.5 or distance ~= distance or distance > 600 then
		return
	end
	if name == "Shock" then
		CombatVfx.lightning(from, to, palette.Main)
		splash(to, name, palette, color, k)
		return
	end
	local travel = math.clamp(distance / (if name == "Poison" then 60 else 95), 0.08, 0.5)
	local landed = FxSize.keep(function()
		splash(to, name, palette, color, k)
	end)
	if name == "Frost" then
		-- An ice lance, point first, glittering in its wake.
		local lance = part(
			Vector3.new(0.55 * k, 0.55 * k, 3.4 * k),
			aim(from, to - from),
			palette.Core,
			0.1,
			nil,
			Enum.Material.Glass
		)
		lance.Reflectance = 0.4
		local glow = part(Vector3.new(0.22 * k, 0.22 * k, 3.9 * k), aim(from, to - from), palette.Main, 0)
		tween(lance, travel, { CFrame = aim(to, to - from) }, Enum.EasingStyle.Linear)
		tween(glow, travel, { CFrame = aim(to, to - from) }, Enum.EasingStyle.Linear)
		for i = 1, 4 do
			task.delay(
				travel * i / 5,
				FxSize.keep(function()
					CombatFx.burst(from:Lerp(to, i / 5), palette.Core, "Frost", 0.3)
				end)
			)
		end
		task.delay(travel, function()
			lance:Destroy()
			glow:Destroy()
			landed()
		end)
		return
	end
	-- A fireball (flame pouring off it), or a glob of acid lobbed in an arc.
	local head = part(
		Vector3.one * (if name == "Fire" then 1.7 else 1.3) * k,
		CFrame.new(from),
		if palette then palette.Main else color,
		0.15,
		Enum.PartType.Ball
	)
	local core =
		part(Vector3.one * 0.8 * k, CFrame.new(from), if palette then palette.Core else WHITE, 0, Enum.PartType.Ball)
	local lift = if name == "Poison" then math.clamp(distance * 0.2, 0.8, 6) else 0
	local steps = math.clamp(math.floor(travel / 0.03), 3, 16)
	for i = 1, steps - 1 do -- (the last: where it lands)
		task.delay(
			travel * i / steps,
			FxSize.keep(function()
				local t = i / steps
				local at = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * lift, 0)
				if head.Parent then
					head.CFrame, core.CFrame = CFrame.new(at), CFrame.new(at)
				end
				-- (what it leaves in its wake)
				do
					if name == "Fire" then
						flame(at, 1.3 * k, 0.8 * k, 0.3, palette)
					elseif name == "Poison" then
						local drop = part(Vector3.one * 0.35 * k, CFrame.new(at), palette.Main, 0.1, Enum.PartType.Ball)
						fade(drop, 0.3, { CFrame = CFrame.new(at - Vector3.new(0, 1.5 * k, 0)) })
					else
						CombatFx.burst(at, color, "Sparks", 0.3)
					end
				end
			end)
		)
	end
	task.delay(travel, function()
		head:Destroy()
		core:Destroy()
		landed()
	end)
end

-- A spine shot straight at `to`, point first: a pale quill in a glow of its
-- element, a streak behind it, and a small splash of the element.
function ElementFx.spine(from: Vector3, to: Vector3, element: any)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	local distance = (to - from).Magnitude
	if distance < 0.5 or distance ~= distance or distance > 600 then
		return
	end
	local travel = math.clamp(distance / 110, 0.05, 0.3)
	local dir = to - from
	local quill =
		part(Vector3.new(0.22 * k, 0.22 * k, 1.8 * k), aim(from, dir), if palette then palette.Core else WHITE, 0)
	local glow = part(Vector3.new(0.5 * k, 0.5 * k, 2.4 * k), aim(from, dir), color, 0.45)
	local streak = part(Vector3.new(0.12 * k, 0.12 * k, 0.1), aim(from, dir), color, 0.3)
	tween(quill, travel, { CFrame = aim(to, dir) }, Enum.EasingStyle.Linear)
	tween(glow, travel, { CFrame = aim(to, dir) }, Enum.EasingStyle.Linear)
	-- (the streak stretches out behind it, then thins away)
	tween(
		streak,
		travel,
		{ CFrame = aim(from:Lerp(to, 0.6), dir), Size = Vector3.new(0.12 * k, 0.12 * k, distance * 0.7) },
		Enum.EasingStyle.Linear
	)
	task.delay(
		travel,
		FxSize.keep(function()
			quill:Destroy()
			glow:Destroy()
			if streak.Parent then
				fade(
					streak,
					0.12,
					{ Size = Vector3.new(0.02, 0.02, distance * 0.3), CFrame = aim(from:Lerp(to, 0.85), dir) }
				)
			end
			-- Stuck where it hit, glowing, then gone; its element bursting there.
			local stuck = part(
				Vector3.new(0.2 * k, 0.2 * k, 1.2 * k),
				aim(to - dir.Unit * 0.4 * k, dir),
				if palette then palette.Core else WHITE,
				0
			)
			task.delay(0.25, function()
				if stuck.Parent then
					fade(stuck, 0.25)
				end
			end)
			CombatFx.burst(
				to,
				color,
				if name == "Fire"
					then "Embers"
					elseif name == "Frost" then "Frost"
					elseif name == "Poison" then "Drips"
					else "Sparks",
				0.5
			)
			if name == "Shock" then
				local out = jitter(1)
				if out.Magnitude > 0.05 then
					CombatVfx.lightning(to, to + out.Unit * 1.6 * k, palette.Main)
				end
			end
		end)
	)
end

-- A bomb arcing over to `to` in `seconds` (the blast it makes is erupt's).
function ElementFx.lob(from: Vector3, to: Vector3, element: any, seconds: number?)
	local name = ElementFx.elementOf(element)
	local palette = name and ElementFx.Palettes[name]
	local color = if palette then palette.Main elseif typeof(element) == "Color3" then element else WHITE
	local k = FxSize.get()
	local travel = math.clamp(seconds or 0.6, 0.15, 2)
	local distance = (to - from).Magnitude
	if distance ~= distance or distance > 600 then
		return
	end
	local height = math.clamp(distance * 0.35, 2 * k, 14)
	local bomb = part(
		Vector3.one * 0.9 * k,
		CFrame.new(from),
		Color3.fromRGB(46, 48, 56),
		0,
		Enum.PartType.Ball,
		Enum.Material.Metal
	)
	local glow = part(Vector3.one * 0.45 * k, CFrame.new(from), color, 0, Enum.PartType.Ball)
	local steps = math.clamp(math.floor(travel / 0.03), 5, 30)
	for i = 1, steps - 1 do -- (the last: where it lands)
		task.delay(
			travel * i / steps,
			FxSize.keep(function()
				local t = i / steps
				local at = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
				if bomb.Parent then
					bomb.CFrame = CFrame.new(at) * CFrame.Angles(t * 9, t * 5, 0)
					glow.CFrame = CFrame.new(at + Vector3.new(0, 0.35 * k, 0))
				end
				if i % 2 == 0 then
					-- The fuse fizzing as it flies.
					CombatFx.burst(
						at + Vector3.new(0, 0.4 * k, 0),
						if palette then palette.Core else color,
						"Sparks",
						0.25
					)
				end
			end)
		)
	end
	task.delay(travel, function()
		bomb:Destroy()
		glow:Destroy()
	end)
end

return ElementFx
