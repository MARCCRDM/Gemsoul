--[[
	Elemental card effects: a socketed gem's element lives in its card. The
	gem is the source: its energy glows out of the socket, washes the card,
	runs around the border as a travelling light, and each element has its
	own motion.

	  Thermal (Fire)       embers rise from the floor of the card, a heat glow
	                       breathes underneath, the border burns orange-gold
	  Cryo (Frost)         ice crystals drift down, a cold glint sweeps across
	                       now and then, the border creeps round slowly
	  Ion (Shock)          forked lightning snaps across the card, sparks
	                       blink along the edges, the border flickers like a
	                       live wire
	  Corrosive (Poison)   bubbles swell up from a toxic pool and pop, the
	                       pool rises and falls

	Everything is built once (create) and only moved and recoloured each
	frame (update), so a full inventory makes no new instances. The wash sits
	under the card's content; the border light sits on top.

	  ElementCardFX.create(card, gemWell) -> effect
	  ElementCardFX.update(effect, element?, time)   nil element hides it
]]
local FX = {}

local SPARKS = 14 -- particles per card
local BOLT_SEGMENTS = 9

-- Hand-tuned per element: Hot (white-hot core), Mid (the element), Deep
-- (shadow), border speed (degrees a second), the wash's strength (lower is
-- stronger) and how often a glint sweeps across (nil: never).
local THEMES = {
	Fire = {
		Hot = Color3.fromRGB(255, 226, 140),
		Mid = Color3.fromRGB(255, 118, 38),
		Deep = Color3.fromRGB(150, 30, 12),
		Spin = 110,
		Wash = 0.784,
		Pool = 0.55,
	},
	Frost = {
		Hot = Color3.fromRGB(236, 251, 255),
		Mid = Color3.fromRGB(120, 210, 255),
		Deep = Color3.fromRGB(30, 90, 170),
		Spin = 40,
		Wash = 0.76,
		Pool = 0.86,
		Glint = 3.6,
	},
	Shock = {
		Hot = Color3.fromRGB(255, 252, 214),
		Mid = Color3.fromRGB(255, 220, 70),
		Deep = Color3.fromRGB(150, 110, 10),
		Spin = 220,
		Wash = 0.7,
		Pool = 0.86,
		Glint = 2.2,
	},
	Poison = {
		Hot = Color3.fromRGB(214, 255, 170),
		Mid = Color3.fromRGB(70, 220, 110),
		Deep = Color3.fromRGB(18, 90, 50),
		Spin = 55,
		Wash = 0.75,
		Pool = 0.55,
	},
}
FX.Themes = THEMES

-- A stable 0-1 number per particle, so each keeps its own rhythm.
local function seeded(i: number, salt: number): number
	local x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
	return x - math.floor(x)
end

local function make(class: string, props, parent: Instance): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function fill(name: string, parent: Instance, props)
	local frame = make("Frame", {
		Name = name,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 0,
		Active = false,
	}, parent)
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function FX.create(card: GuiObject, gemWell: GuiObject?)
	-- Under the content: wash, pool, glow, glint, particles, lightning.
	local layer = make("Frame", {
		Name = "ElementalFX",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 0,
		Visible = false,
		Active = false,
	}, card)

	-- The element washing across the card, centred on the gem.
	local wash = fill("Wash", layer, { Size = UDim2.fromScale(1, 1) })
	local washGradient = make("UIGradient", {}, wash)

	-- A pool of colour along the floor of the card.
	local pool = fill("Pool", layer, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
	})
	local poolGradient = make("UIGradient", { Rotation = 90 }, pool)

	-- Behind the gem: a soft glow that breathes. UI gradients are straight,
	-- so a round soft glow is stacked rings, each faint, the core brightest.
	local glow = make("Frame", {
		Name = "GemGlow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 0,
	}, layer)
	local rings = {}
	for i, scale in { 1, 0.88, 0.76, 0.64, 0.52, 0.4, 0.29, 0.18 } do
		local ring = fill("Ring", glow, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		rings[i] = ring
	end

	-- A cold glint (or a charge pulse) that sweeps across the card.
	local glint = fill("Glint", layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 24, 2, 0),
		Rotation = 22,
		Visible = false,
	})
	local glintGradient = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, glint)

	local sparks = {}
	for i = 1, SPARKS do
		local spark = fill("Spark", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
		sparks[i] = { Frame = spark, Corner = make("UICorner", { CornerRadius = UDim.new(1, 0) }, spark) }
	end

	-- Lightning: a chain of short glowing segments, plus forks.
	local bolt = {}
	for i = 1, BOLT_SEGMENTS * 2 do
		local segment = fill("Bolt", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, segment)
		bolt[i] = segment
	end

	-- On top: the travelling border light.
	local rim = make("Frame", {
		Name = "ElementalRim",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Visible = false,
		Active = false,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, rim)
	local rimStroke = make("UIStroke", {
		Thickness = 1.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
	}, rim)
	local rimGradient = make("UIGradient", {}, rimStroke)

	return {
		Card = card,
		Gem = gemWell,
		Layer = layer,
		Rim = rim,
		RimStroke = rimStroke,
		RimGradient = rimGradient,
		WashGradient = washGradient,
		Pool = pool,
		PoolGradient = poolGradient,
		Glow = glow,
		Rings = rings,
		Glint = glint,
		Sparks = sparks,
		Bolt = bolt,
		Element = nil,
		NextBolt = 0,
		BoltUntil = 0,
		BoltSeed = 0,
	}
end

-- Colours change only when the element does.
local function paint(effect, theme, element: string)
	local hot, mid, deep = theme.Hot, theme.Mid, theme.Deep
	effect.WashGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep),
		ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(1, deep),
	})
	effect.WashGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.97),
		NumberSequenceKeypoint.new(0.3, theme.Wash + 0.15),
		NumberSequenceKeypoint.new(0.5, theme.Wash),
		NumberSequenceKeypoint.new(0.7, theme.Wash + 0.15),
		NumberSequenceKeypoint.new(1, 0.97),
	})
	-- (Top of the pool clear, the floor coloured.)
	effect.PoolGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, (1 + theme.Pool) / 2),
		NumberSequenceKeypoint.new(1, theme.Pool),
	})
	effect.PoolGradient.Color = ColorSequence.new(deep, mid)
	for i, ring in effect.Rings do
		ring.BackgroundColor3 = mid:Lerp(hot, (i - 1) / (#effect.Rings - 1))
	end
	effect.Glint.BackgroundColor3 = hot
	-- The border: a bright head with a fading tail chasing round the card.
	effect.RimGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep),
		ColorSequenceKeypoint.new(0.42, mid),
		ColorSequenceKeypoint.new(0.5, hot),
		ColorSequenceKeypoint.new(0.58, mid),
		ColorSequenceKeypoint.new(1, deep),
	})
	effect.RimGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	for i, spark in effect.Sparks do
		local diamond = element == "Frost" -- ice crystals
		spark.Corner.CornerRadius = if diamond then UDim.new(0, 1) else UDim.new(1, 0)
		spark.Frame.Rotation = if diamond then 45 else 0
		spark.Frame.BackgroundColor3 = if seeded(i, 3) > 0.5 then hot else mid
	end
	for _, segment in effect.Bolt do
		segment.Visible = false
	end
	effect.Glint.Visible = false
end

-- One lightning segment between two points (offsets).
local function line(segment: Frame, a: Vector2, b: Vector2, width: number, color: Color3, alpha: number)
	local delta = b - a
	segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	segment.Size = UDim2.fromOffset(delta.Magnitude + width * 0.5, width)
	segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	segment.BackgroundColor3 = color
	segment.BackgroundTransparency = 1 - alpha
	segment.Visible = true
end

local function hideBolt(effect)
	for _, segment in effect.Bolt do
		segment.Visible = false
	end
end

local function drawBolt(effect, theme, w: number, h: number, t: number)
	if t >= effect.BoltUntil then
		if t < effect.NextBolt then
			hideBolt(effect)
			return
		end
		-- A new strike, top edge to bottom edge, every 0.7-2 seconds.
		effect.BoltSeed += 1
		effect.BoltUntil = t + 0.16
		effect.NextBolt = t + 0.7 + seeded(effect.BoltSeed, 9) * 1.3
	end
	local seed = effect.BoltSeed
	local flicker = if math.floor(t * 40) % 2 == 0 then 1 else 0.6
	local from = Vector2.new(w * (0.06 + seeded(seed, 1) * 0.88), 0)
	local to = Vector2.new(w * (0.06 + seeded(seed, 2) * 0.88), h)
	local previous = from
	for i = 1, BOLT_SEGMENTS do
		local p = from:Lerp(to, i / BOLT_SEGMENTS)
		if i < BOLT_SEGMENTS then
			p += Vector2.new((seeded(seed * 13 + i, 4) - 0.5) * 22, 0)
		end
		line(effect.Bolt[i], previous, p, 2, theme.Hot, 0.9 * flicker)
		local fork = effect.Bolt[BOLT_SEGMENTS + i]
		if i == 3 or i == 6 then
			local tip = p + Vector2.new((seeded(seed, i) - 0.5) * 44, 10)
			line(fork, p, tip, 1.2, theme.Mid, 0.75 * flicker)
		else
			fork.Visible = false
		end
		previous = p
	end
end

-- Where the gem sits in the card, as 0-1 fractions (the middle if unknown).
local function gemCentre(effect, w: number, h: number): (number, number)
	local gem = effect.Gem
	if not gem or not gem.Parent then
		return 0.5, 0.5
	end
	local gx = gem.Position.X.Offset + gem.Size.X.Offset / 2
	local gy = gem.Position.Y.Offset + gem.Size.Y.Offset / 2
	local holder = gem.Parent
	if holder ~= effect.Card and holder:IsA("GuiObject") then
		-- A gem area inside a badge: add the badge's own place.
		gx += holder.Position.X.Offset
		gy += holder.Position.Y.Offset
	end
	if gx <= 0 or gy <= 0 then
		return 0.5, 0.5
	end
	return math.clamp(gx / w, 0.05, 0.95), math.clamp(gy / h, 0.1, 0.9)
end

function FX.update(effect, element: string?, time: number)
	local theme = element and THEMES[element]
	effect.Layer.Visible = theme ~= nil
	effect.Rim.Visible = theme ~= nil
	if not theme then
		effect.Element = nil
		return
	end
	if effect.Element ~= element then
		effect.Element = element
		paint(effect, theme, element :: string)
	end
	local card = effect.Card
	local w, h = card.Size.X.Offset, card.Size.Y.Offset
	if w <= 0 or h <= 0 then
		w, h = card.AbsoluteSize.X, card.AbsoluteSize.Y
	end
	if w <= 0 or h <= 0 then
		return
	end
	local t = time

	-- The border light chases round; Ion stutters like a live wire.
	local spin = (t * theme.Spin) % 360
	if element == "Shock" and math.floor(t * 12) % 7 == 0 then
		spin += 140
	end
	effect.RimGradient.Rotation = spin
	effect.RimStroke.Transparency = if element == "Shock" then 0.05 + 0.35 * seeded(math.floor(t * 20), 5) else 0.12

	-- The wash and glow centre on the gem; the glow breathes.
	local gemX, gemY = gemCentre(effect, w, h)
	effect.WashGradient.Offset = Vector2.new(gemX - 0.5 + math.sin(t * 0.7) * 0.05, 0)
	local breathe = 0.5 + 0.5 * math.sin(t * (if element == "Fire" then 3.2 else 1.6))
	local glowSize = math.min(w, h) * (1.1 + 0.18 * breathe)
	effect.Glow.Position = UDim2.fromOffset(gemX * w, gemY * h)
	effect.Glow.Size = UDim2.fromOffset(glowSize * 1.6, glowSize)
	for i, ring in effect.Rings do
		ring.BackgroundTransparency = 0.95 - 0.02 * breathe - (if i == #effect.Rings then 0.1 else 0)
	end

	if element == "Fire" then
		-- Embers rise from the floor, cooling from white-gold to orange.
		effect.Pool.Size = UDim2.fromScale(1, 0.42 + 0.08 * math.sin(t * 2.3))
		for i, spark in effect.Sparks do
			local f = spark.Frame
			local period = 1.4 + seeded(i, 1) * 1.4
			local phase = (t / period + seeded(i, 2)) % 1
			local x = (0.04 + seeded(i, 6) * 0.92) * w + math.sin(phase * 7 + i) * 5
			local size = 1.5 + seeded(i, 7) * 2.5 * (1 - phase * 0.6)
			f.Position = UDim2.fromOffset(x, h * (1.02 - phase * 1.05))
			f.Size = UDim2.fromOffset(size, size)
			f.BackgroundColor3 = theme.Hot:Lerp(theme.Mid, phase)
			f.BackgroundTransparency = 0.05 + 0.95 * phase * phase
			f.Visible = true
		end
	elseif element == "Frost" then
		-- Ice crystals drift down and twinkle.
		effect.Pool.Size = UDim2.fromScale(1, 0.32)
		for i, spark in effect.Sparks do
			local f = spark.Frame
			local period = 4 + seeded(i, 1) * 3
			local phase = (t / period + seeded(i, 2)) % 1
			local x = (0.03 + seeded(i, 6) * 0.94) * w + math.sin(t * 0.9 + i) * 4
			local size = 2 + seeded(i, 7) * 2.5
			f.Position = UDim2.fromOffset(x, h * (phase * 1.1 - 0.05))
			f.Size = UDim2.fromOffset(size, size)
			f.Rotation = 45 + t * 40 * (seeded(i, 8) - 0.5)
			local twinkle = 0.5 + 0.5 * math.sin(t * 5 + i * 2)
			f.BackgroundTransparency = 0.1 + 0.55 * (1 - twinkle) + 0.3 * phase
			f.Visible = true
		end
	elseif element == "Shock" then
		-- Lightning snaps across; sparks pop along the edges.
		effect.Pool.Size = UDim2.fromScale(1, 0.28)
		drawBolt(effect, theme, w, h, t)
		for i, spark in effect.Sparks do
			local f = spark.Frame
			local slot = math.floor(t * 3 + seeded(i, 2) * 3)
			local on = seeded(slot * 31 + i, 3) > 0.45
			local top = seeded(slot + i * 7, 4) > 0.5
			local size = 1.5 + seeded(i, 7) * 2
			f.Position = UDim2.fromOffset(
				seeded(slot * 5 + i, 6) * w,
				if top then seeded(slot + i, 8) * 8 else h - seeded(slot + i, 9) * 8
			)
			f.Size = UDim2.fromOffset(size, size)
			f.BackgroundTransparency = 0.05
			f.Visible = on
		end
	else
		-- Corrosive: bubbles swell as they rise from the pool, then pop.
		effect.Pool.Size = UDim2.fromScale(1, 0.48 + 0.06 * math.sin(t * 0.9))
		for i, spark in effect.Sparks do
			local f = spark.Frame
			local period = 2.2 + seeded(i, 1) * 2.2
			local phase = (t / period + seeded(i, 2)) % 1
			local x = (0.04 + seeded(i, 6) * 0.92) * w + math.sin(phase * 4 + i) * 3
			local size = 2 + phase * (3 + seeded(i, 7) * 5)
			f.Position = UDim2.fromOffset(x, h * (1.02 - phase * 0.6))
			f.Size = UDim2.fromOffset(size, size)
			f.BackgroundTransparency = if phase > 0.85 then 0.5 + (phase - 0.85) * 3.3 else 0.3 + 0.2 * phase
			f.Visible = true
		end
	end
	if element ~= "Shock" then
		hideBolt(effect)
	end

	-- Cryo's cold glint and Ion's charge pulse sweep across now and then.
	if theme.Glint then
		local progress = (t % theme.Glint) / 0.9
		effect.Glint.Visible = progress <= 1
		effect.Glint.Position = UDim2.fromOffset(-30 + progress * (w + 60), h / 2)
	end
end

return FX
