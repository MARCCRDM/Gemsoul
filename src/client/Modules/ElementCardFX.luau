--[[
	Elemental frames: a socketed gem's element frames its card. The inside
	of the card stays clean; the element lives in a band around the border.

	  The frame   a glowing band on every edge with the element flowing
	              along it, a soft inner glow, heavy corner brackets, and a
	              bright light running round the rim
	  Thermal     flames lick up off the frame, thickest along the bottom
	  Cryo        ice shards grow inward from the frame and twinkle; a cold
	              glint travels round it
	  Ion         lightning crackles along a stretch of the frame and jumps
	              to the next; sparks pop at the corners
	  Corrosive   ooze drips from the top edge and bubbles along the bottom

	Built once per card (create), only moved and recoloured each frame
	(update), so a full inventory makes no new instances.

	  ElementCardFX.create(card, gemWell) -> effect
	  ElementCardFX.update(effect, element?, time)   nil element hides it
]]
local FX = {}

local BAND = 4 -- frame thickness (px)
local GLOW = 10 -- inner glow depth (px)
local BITS = 22 -- flames / shards / drips / sparks per card
local BOLT = 12 -- lightning segments

local THEMES = {
	Fire = {
		Hot = Color3.fromRGB(255, 232, 150),
		Mid = Color3.fromRGB(255, 120, 36),
		Deep = Color3.fromRGB(170, 34, 10),
		Spin = 120,
		Flow = 0.9,
	},
	Frost = {
		Hot = Color3.fromRGB(240, 252, 255),
		Mid = Color3.fromRGB(120, 210, 255),
		Deep = Color3.fromRGB(34, 96, 180),
		Spin = 45,
		Flow = 0.25,
	},
	Shock = {
		Hot = Color3.fromRGB(255, 252, 220),
		Mid = Color3.fromRGB(255, 222, 70),
		Deep = Color3.fromRGB(160, 116, 10),
		Spin = 260,
		Flow = 2.2,
	},
	Poison = {
		Hot = Color3.fromRGB(214, 255, 170),
		Mid = Color3.fromRGB(70, 220, 110),
		Deep = Color3.fromRGB(16, 92, 48),
		Spin = 60,
		Flow = 0.4,
	},
}
FX.Themes = THEMES

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

local function piece(name: string, parent: Instance, props)
	local frame = make("Frame", {
		Name = name,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 8,
		Active = false,
	}, parent)
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

-- The four edges: where each sits and which way its gradient runs.
local EDGES = {
	Top = { Pos = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, BAND), Rotation = 0, GlowRotation = 90 },
	Bottom = {
		Pos = UDim2.new(0, 0, 1, -BAND),
		Size = UDim2.new(1, 0, 0, BAND),
		Rotation = 180,
		GlowRotation = -90,
	},
	Left = { Pos = UDim2.fromScale(0, 0), Size = UDim2.new(0, BAND, 1, 0), Rotation = 90, GlowRotation = 0 },
	Right = {
		Pos = UDim2.new(1, -BAND, 0, 0),
		Size = UDim2.new(0, BAND, 1, 0),
		Rotation = -90,
		GlowRotation = 180,
	},
}

function FX.create(card: GuiObject, _gemWell: GuiObject?)
	-- Everything sits above the card's content but only along its border.
	local layer = make("Frame", {
		Name = "ElementalFrame",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 8,
		Visible = false,
		Active = false,
	}, card)

	local edges = {}
	for name, spec in EDGES do
		-- A soft glow bleeding inward from the edge.
		local glow = piece("Glow" .. name, layer, {
			Position = spec.Pos,
			Size = if name == "Top" or name == "Bottom" then UDim2.new(1, 0, 0, GLOW) else UDim2.new(0, GLOW, 1, 0),
		})
		if name == "Bottom" then
			glow.Position = UDim2.new(0, 0, 1, -GLOW)
		elseif name == "Right" then
			glow.Position = UDim2.new(1, -GLOW, 0, 0)
		end
		local glowGradient = make("UIGradient", { Rotation = spec.GlowRotation }, glow)
		-- The band itself, the element flowing along it.
		local band = piece("Band" .. name, layer, { Position = spec.Pos, Size = spec.Size })
		local bandGradient = make("UIGradient", { Rotation = spec.Rotation }, band)
		edges[name] = { Band = band, BandGradient = bandGradient, Glow = glow, GlowGradient = glowGradient }
	end

	-- Corner brackets: an L of two thick bars at each corner.
	local corners = {}
	for i, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local x, y = corner[1], corner[2]
		local across = piece("CornerH", layer, {
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(18, BAND + 2),
		})
		local down = piece("CornerV", layer, {
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(BAND + 2, 18),
		})
		corners[i] = { across, down }
	end

	-- Flames, shards, drips or sparks living on the frame.
	local bits = {}
	for i = 1, BITS do
		local bit = piece("Bit", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
		bits[i] = { Frame = bit, Corner = make("UICorner", { CornerRadius = UDim.new(1, 0) }, bit) }
	end

	local bolt = {}
	for i = 1, BOLT do
		local segment = piece("Bolt", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, segment)
		bolt[i] = segment
	end

	-- The rim: a bright head with a fading tail chasing round the outside.
	local rim = make("Frame", {
		Name = "ElementalRim",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Visible = false,
		Active = false,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, rim)
	local rimStroke = make("UIStroke", {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
	}, rim)
	local rimGradient = make("UIGradient", {}, rimStroke)

	return {
		Card = card,
		Layer = layer,
		Edges = edges,
		Corners = corners,
		Bits = bits,
		Bolt = bolt,
		Rim = rim,
		RimStroke = rimStroke,
		RimGradient = rimGradient,
		Element = nil,
		BoltSeed = 0,
		BoltUntil = 0,
		NextBolt = 0,
	}
end

local function paint(effect, theme, element: string)
	local hot, mid, deep = theme.Hot, theme.Mid, theme.Deep
	-- Bands: the element in waves, so flowing it along reads as motion.
	local wave = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep),
		ColorSequenceKeypoint.new(0.2, mid),
		ColorSequenceKeypoint.new(0.35, hot),
		ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(0.7, deep),
		ColorSequenceKeypoint.new(0.85, mid),
		ColorSequenceKeypoint.new(1, deep),
	})
	for _, edge in effect.Edges do
		edge.BandGradient.Color = wave
		edge.GlowGradient.Color = ColorSequence.new(mid)
		edge.GlowGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	for _, pair in effect.Corners do
		for _, bar in pair do
			bar.BackgroundColor3 = hot
		end
	end
	for i, bit in effect.Bits do
		local diamond = element == "Frost"
		bit.Corner.CornerRadius = if diamond then UDim.new(0, 1) else UDim.new(1, 0)
		bit.Frame.Rotation = if diamond then 45 else 0
		bit.Frame.BackgroundColor3 = if seeded(i, 3) > 0.5 then hot else mid
	end
	for _, segment in effect.Bolt do
		segment.Visible = false
	end
	effect.RimGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep),
		ColorSequenceKeypoint.new(0.44, mid),
		ColorSequenceKeypoint.new(0.5, hot),
		ColorSequenceKeypoint.new(0.56, mid),
		ColorSequenceKeypoint.new(1, deep),
	})
	effect.RimGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
end

-- A point on the frame's centre line, `d` px clockwise from the top-left.
-- Also returns the inward direction there.
local function around(d: number, w: number, h: number, inset: number): (Vector2, Vector2)
	local perimeter = 2 * (w + h)
	d = d % perimeter
	if d < w then
		return Vector2.new(d, inset), Vector2.new(0, 1)
	end
	d -= w
	if d < h then
		return Vector2.new(w - inset, d), Vector2.new(-1, 0)
	end
	d -= h
	if d < w then
		return Vector2.new(w - d, h - inset), Vector2.new(0, -1)
	end
	d -= w
	return Vector2.new(inset, h - d), Vector2.new(1, 0)
end

local function line(segment: Frame, a: Vector2, b: Vector2, width: number, color: Color3, alpha: number)
	local delta = b - a
	segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	segment.Size = UDim2.fromOffset(delta.Magnitude + width * 0.5, width)
	segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	segment.BackgroundColor3 = color
	segment.BackgroundTransparency = 1 - alpha
	segment.Visible = true
end

local function place(bit, at: Vector2, size: number, alpha: number)
	bit.Frame.Position = UDim2.fromOffset(at.X, at.Y)
	bit.Frame.Size = UDim2.fromOffset(size, size)
	bit.Frame.BackgroundTransparency = 1 - alpha
	bit.Frame.Visible = alpha > 0.02
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
	local perimeter = 2 * (w + h)

	-- The element flows round the frame; the glow breathes.
	local flow = (t * theme.Flow) % 2 - 1
	local breathe = 0.5 + 0.5 * math.sin(t * (if element == "Fire" then 3.4 else 1.7))
	for name, edge in effect.Edges do
		edge.BandGradient.Offset = if name == "Top" or name == "Bottom"
			then Vector2.new(flow, 0)
			else Vector2.new(0, flow)
		edge.Band.BackgroundTransparency = 0.05
		edge.Glow.BackgroundTransparency = 0.35 - 0.25 * breathe
	end
	-- Fire burns hottest along the bottom.
	effect.Edges.Bottom.Glow.Size = UDim2.new(1, 0, 0, if element == "Fire" then GLOW + 6 * breathe else GLOW)
	effect.Edges.Bottom.Glow.Position = UDim2.new(0, 0, 1, -effect.Edges.Bottom.Glow.Size.Y.Offset)

	-- The rim light chases round; Ion stutters like a live wire.
	local spin = (t * theme.Spin) % 360
	if element == "Shock" and math.floor(t * 12) % 7 == 0 then
		spin += 140
	end
	effect.RimGradient.Rotation = spin
	effect.RimStroke.Transparency = if element == "Shock" then 0.05 + 0.4 * seeded(math.floor(t * 20), 5) else 0.1

	-- Corner brackets pulse.
	for _, pair in effect.Corners do
		for _, bar in pair do
			bar.BackgroundTransparency = 0.15 * (1 - breathe)
		end
	end

	local bits = effect.Bits
	if element == "Fire" then
		-- Flames lick inward off the frame, more along the bottom.
		for i, bit in bits do
			local period = 0.9 + seeded(i, 1) * 0.9
			local phase = (t / period + seeded(i, 2)) % 1
			local d = if i <= 10 then w + h + seeded(i, 6) * w else seeded(i, 6) * perimeter
			local at, inward = around(d, w, h, BAND)
			local rise = phase * (5 + seeded(i, 7) * 9)
			local sway = math.sin(phase * 8 + i) * 2
			local p = at + inward * rise + Vector2.new(inward.Y, inward.X) * sway
			bit.Frame.BackgroundColor3 = theme.Hot:Lerp(theme.Mid, phase)
			place(bit, p, (3.5 + seeded(i, 8) * 2.5) * (1 - phase * 0.7), 0.95 * (1 - phase))
		end
	elseif element == "Frost" then
		-- Ice shards stand on the frame pointing inward and twinkle.
		for i, bit in bits do
			local d = (i - 0.5) / BITS * perimeter + seeded(i, 6) * 8
			local at, inward = around(d, w, h, BAND)
			local length = 2.5 + seeded(i, 7) * 3.5
			local twinkle = 0.5 + 0.5 * math.sin(t * 3 + i * 1.9)
			place(bit, at + inward * length * 0.6, length, 0.45 + 0.5 * twinkle)
			bit.Frame.Rotation = 45 + math.sin(t * 0.8 + i) * 8
		end
	elseif element == "Shock" then
		-- Sparks pop round the corners and along the frame.
		for i, bit in bits do
			local slot = math.floor(t * 4 + seeded(i, 2) * 4)
			local on = seeded(slot * 31 + i, 3) > 0.55
			local d = seeded(slot * 5 + i, 6) * perimeter
			local at, inward = around(d, w, h, BAND / 2)
			local jitter = (seeded(slot + i, 8) - 0.5) * 6
			place(
				bit,
				at + inward * (2 + seeded(slot, i) * 5) + Vector2.new(inward.Y, inward.X) * jitter,
				2.5,
				if on then 1 else 0
			)
		end
	else
		-- Ooze drips from the top edge; bubbles pop along the bottom.
		for i, bit in bits do
			if i <= 12 then
				local period = 2.4 + seeded(i, 1) * 2
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.05 + seeded(i, 6) * 0.9) * w
				local drop = phase * phase * (10 + seeded(i, 7) * 10)
				place(bit, Vector2.new(x, BAND + drop), 3 + (1 - phase) * 2, 0.9 * (1 - phase))
			else
				local period = 1.6 + seeded(i, 1) * 1.6
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.04 + seeded(i, 6) * 0.92) * w
				place(bit, Vector2.new(x, h - BAND - phase * 9), 2 + phase * 5, if phase > 0.85 then 0.3 else 0.75)
			end
		end
	end

	-- Ion: a bolt crackles along a stretch of the frame, then jumps.
	if element == "Shock" then
		if t >= effect.BoltUntil and t >= effect.NextBolt then
			effect.BoltSeed += 1
			effect.BoltUntil = t + 0.22
			effect.NextBolt = t + 0.35 + seeded(effect.BoltSeed, 9) * 0.7
		end
		if t < effect.BoltUntil then
			local seed = effect.BoltSeed
			local start = seeded(seed, 1) * perimeter
			local length = 50 + seeded(seed, 2) * 70
			local flicker = if math.floor(t * 40) % 2 == 0 then 1 else 0.6
			local previous = nil
			for i = 0, BOLT do
				local at, inward = around(start + length * i / BOLT, w, h, BAND / 2)
				local p = at + inward * (seeded(seed * 17 + i, 4) * 6)
				if previous then
					line(effect.Bolt[i], previous, p, 1.8, theme.Hot, 0.95 * flicker)
				end
				previous = p
			end
		else
			for _, segment in effect.Bolt do
				segment.Visible = false
			end
		end
	end
end

return FX
