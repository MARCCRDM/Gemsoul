--[[
	Elemental frames: a socketed gem's element is an armoured frame round
	its card. Heavy gunmetal with a bevel, bolted corner plates and vents;
	the element is raw energy showing through a channel cut into the metal
	and venting off it. The inside of the card stays clean.

	  Thermal     molten channel, sparks and slag thrown off the bottom edge
	  Cryo        frozen channel, ice spikes jutting in off the metal, a
	              cold glint racing round
	  Ion         live channel, lightning arcing along the frame
	  Corrosive   acid channel, sludge dripping off the top edge

	Built once per card (create), only moved and recoloured each frame
	(update), so a full inventory makes no new instances.

	  ElementCardFX.create(card, gemWell) -> effect
	  ElementCardFX.update(effect, element?, time)   nil element hides it
]]
local FX = {}

local BAND = 7 -- metal frame thickness (px)
local OUT = 4 -- how much of it sits outside the card's edge (px)
local CHANNEL = 2 -- energy channel cut into it (px)
local PLATE = 24 -- corner bracket arm length (px)
local BITS = 30 -- sparks / spikes / drips per card (half the signature, half the drift)
local BOLT = 12 -- lightning segments per arc (two arcs at once)

local TAPER = NumberSequence.new(1, 0)
local SOLID = NumberSequence.new(0)
local STEEL_LIGHT = Color3.fromRGB(150, 158, 172)
local STEEL = Color3.fromRGB(78, 85, 98)
local STEEL_DARK = Color3.fromRGB(26, 29, 36)
local RIVET = Color3.fromRGB(196, 202, 212)

local THEMES = {
	Fire = {
		Hot = Color3.fromRGB(255, 236, 170),
		Mid = Color3.fromRGB(255, 110, 24),
		Deep = Color3.fromRGB(150, 24, 6),
		Flow = 0.8,
		Pulse = 3.2,
	},
	Frost = {
		Hot = Color3.fromRGB(240, 252, 255),
		Mid = Color3.fromRGB(110, 205, 255),
		Deep = Color3.fromRGB(26, 80, 170),
		Flow = 0.25,
		Pulse = 1.2,
	},
	Shock = {
		Hot = Color3.fromRGB(255, 252, 225),
		Mid = Color3.fromRGB(255, 214, 50),
		Deep = Color3.fromRGB(150, 100, 0),
		Flow = 2.4,
		Pulse = 9,
	},
	Poison = {
		Hot = Color3.fromRGB(205, 255, 150),
		Mid = Color3.fromRGB(60, 215, 95),
		Deep = Color3.fromRGB(12, 80, 36),
		Flow = 0.35,
		Pulse = 1.6,
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

local function piece(name: string, parent: Instance, props, z: number?)
	local frame = make("Frame", {
		Name = name,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z or 8,
		Active = false,
	}, parent)
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

-- A bar along one edge, `inset` px in from it and `thick` px thick.
local function edgeBar(edge: string, inset: number, thick: number): (UDim2, UDim2)
	if edge == "Top" then
		return UDim2.fromOffset(0, inset), UDim2.new(1, 0, 0, thick)
	elseif edge == "Bottom" then
		return UDim2.new(0, 0, 1, -inset - thick), UDim2.new(1, 0, 0, thick)
	elseif edge == "Left" then
		return UDim2.fromOffset(inset, 0), UDim2.new(0, thick, 1, 0)
	end
	return UDim2.new(1, -inset - thick, 0, 0), UDim2.new(0, thick, 1, 0)
end

-- Gradient rotation that lights the metal from the outer edge in.
local BEVEL = { Top = 90, Bottom = -90, Left = 0, Right = 180 }
local ALONG = { Top = 0, Bottom = 180, Left = 90, Right = -90 }

function FX.create(card: GuiObject, _gemWell: GuiObject?)
	local layer = make("Frame", {
		Name = "ElementalFrame",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-OUT, -OUT),
		Size = UDim2.new(1, OUT * 2, 1, OUT * 2),
		ClipsDescendants = false,
		ZIndex = 8,
		Visible = false,
		Active = false,
	}, card)

	-- An aura round the card: soft rings of the element's light outside the
	-- frame, breathing.
	local aura = {}
	for i = 1, 3 do
		local ring = make("Frame", {
			Name = "ElementalAura",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-OUT - i * 2, -OUT - i * 2),
			Size = UDim2.new(1, (OUT + i * 2) * 2, 1, (OUT + i * 2) * 2),
			ZIndex = 7,
			Active = false,
		}, layer)
		make("UICorner", { CornerRadius = UDim.new(0, 6 + i * 2) }, ring)
		aura[i] = make("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, ring)
	end

	local edges = {}
	for name in BEVEL do
		-- Energy bleeding inward off the frame.
		local glowPos, glowSize = edgeBar(name, BAND, 16)
		local glow = piece("Glow" .. name, layer, { Position = glowPos, Size = glowSize })
		local glowGradient = make("UIGradient", { Rotation = BEVEL[name] }, glow)
		-- The metal: lit on the outside, dark on the inside.
		local metalPos, metalSize = edgeBar(name, 0, BAND)
		local metal = piece("Metal" .. name, layer, { Position = metalPos, Size = metalSize })
		make("UIGradient", {
			Rotation = BEVEL[name],
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, STEEL_LIGHT),
				ColorSequenceKeypoint.new(0.35, STEEL),
				ColorSequenceKeypoint.new(1, STEEL_DARK),
			}),
		}, metal)
		-- The channel cut into the metal, energy flowing along it.
		local channelPos, channelSize = edgeBar(name, math.floor((BAND - CHANNEL) / 2), CHANNEL)
		local channel = piece("Channel" .. name, layer, { Position = channelPos, Size = channelSize }, 9)
		local channelGradient = make("UIGradient", { Rotation = ALONG[name] }, channel)
		edges[name] = { Glow = glow, GlowGradient = glowGradient, Channel = channel, ChannelGradient = channelGradient }
	end

	-- Vents: three slots in the top and bottom rails, glowing inside.
	local vents = {}
	for _, edge in { "Top", "Bottom" } do
		for i = -1, 1 do
			local vent = piece("Vent", layer, {
				AnchorPoint = Vector2.new(0.5, if edge == "Top" then 0 else 1),
				Position = UDim2.new(0.5, i * 16, if edge == "Top" then 0 else 1, if edge == "Top" then 1 else -1),
				Size = UDim2.fromOffset(10, BAND - 2),
				BackgroundColor3 = STEEL_DARK,
			}, 9)
			local core = piece("VentCore", vent, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -2, 1, -2),
			}, 10)
			table.insert(vents, core)
		end
	end

	-- Corner brackets: heavy L-shaped armour (staying on the frame, clear of
	-- the card's text), a rivet in the corner and a hot notch at the tip.
	local corners = {}
	for i, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local x, y = corner[1], corner[2]
		local arms = {}
		for _, size in { Vector2.new(PLATE, BAND + 3), Vector2.new(BAND + 3, PLATE) } do
			local arm = piece("Bracket", layer, {
				AnchorPoint = Vector2.new(x, y),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromOffset(size.X, size.Y),
			}, 10)
			make("UIGradient", {
				Rotation = if size.X > size.Y then (if y == 0 then 90 else -90) else (if x == 0 then 0 else 180),
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, STEEL_LIGHT),
					ColorSequenceKeypoint.new(0.5, STEEL),
					ColorSequenceKeypoint.new(1, STEEL_DARK),
				}),
			}, arm)
			table.insert(arms, arm)
		end
		-- The notch: a short hot slash across the corner's tip.
		local notch = piece("Notch", layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, if x == 0 then 6 else -6, y, if y == 0 then 6 else -6),
			Size = UDim2.fromOffset(9, 2),
			Rotation = if x == y then -45 else 45,
		}, 12)
		local rivet = piece("Rivet", layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, if x == 0 then PLATE - 5 else 5 - PLATE, y, if y == 0 then 5 else -5),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = RIVET,
		}, 12)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, rivet)
		local rivet2 = rivet:Clone()
		rivet2.Position = UDim2.new(x, if x == 0 then 5 else -5, y, if y == 0 then PLATE - 5 else 5 - PLATE)
		rivet2.Parent = layer
		corners[i] = { Arms = arms, Notch = notch }
	end

	local bits = {}
	for i = 1, BITS do
		local bit = piece("Bit", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false }, 9)
		-- Flames taper: bright at the root, gone at the tip.
		local taper = make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0),
		}, bit)
		bits[i] = { Frame = bit, Corner = make("UICorner", { CornerRadius = UDim.new(0, 1) }, bit), Taper = taper }
	end

	local bolt = {}
	for i = 1, BOLT * 2 do
		bolt[i] = piece("Bolt", layer, { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false }, 11)
	end

	-- The outer edge: a hard dark rim with a hot glint racing round it.
	local rim = make("Frame", {
		Name = "ElementalRim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-OUT, -OUT),
		Size = UDim2.new(1, OUT * 2, 1, OUT * 2),
		ZIndex = 13,
		Visible = false,
		Active = false,
	}, card)
	local rimStroke = make("UIStroke", {
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
	}, rim)
	local rimGradient = make("UIGradient", {}, rimStroke)

	return {
		Card = card,
		Layer = layer,
		Edges = edges,
		Vents = vents,
		Corners = corners,
		Bits = bits,
		Bolt = bolt,
		Aura = aura,
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
	-- The channel: hot pulses travelling through the element.
	local surge = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep),
		ColorSequenceKeypoint.new(0.15, mid),
		ColorSequenceKeypoint.new(0.25, hot),
		ColorSequenceKeypoint.new(0.35, mid),
		ColorSequenceKeypoint.new(0.6, deep),
		ColorSequenceKeypoint.new(0.75, mid),
		ColorSequenceKeypoint.new(0.85, hot),
		ColorSequenceKeypoint.new(1, deep),
	})
	for _, edge in effect.Edges do
		edge.ChannelGradient.Color = surge
		edge.GlowGradient.Color = ColorSequence.new(mid)
		edge.GlowGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.4, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	for _, vent in effect.Vents do
		vent.BackgroundColor3 = mid
	end
	for _, ring in effect.Aura do
		ring.Color = mid
	end
	for _, corner in effect.Corners do
		corner.Notch.BackgroundColor3 = hot
	end
	for i, bit in effect.Bits do
		bit.Frame.BackgroundColor3 = if seeded(i, 3) > 0.4 then hot else mid
		bit.Corner.CornerRadius = if element == "Poison" or i > BITS / 2 then UDim.new(1, 0) else UDim.new(0, 1)
		bit.Frame.Rotation = 0
		bit.Taper.Transparency = SOLID
	end
	for _, segment in effect.Bolt do
		segment.Visible = false
	end
	-- Mostly dark steel; a short hot glint chases round.
	effect.RimGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, STEEL_DARK),
		ColorSequenceKeypoint.new(0.46, mid),
		ColorSequenceKeypoint.new(0.5, hot),
		ColorSequenceKeypoint.new(0.54, mid),
		ColorSequenceKeypoint.new(1, STEEL_DARK),
	})
end

-- A point on the frame `d` px clockwise from the top-left, `inset` px in,
-- and the inward direction there.
local function around(d: number, w: number, h: number, inset: number): (Vector2, Vector2)
	d = d % (2 * (w + h))
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
	w, h = w + OUT * 2, h + OUT * 2
	local t = time
	local perimeter = 2 * (w + h)

	-- Energy surges through the channel; the glow and vents throb with it.
	local flow = (t * theme.Flow) % 2 - 1
	local throb = 0.5 + 0.5 * math.sin(t * theme.Pulse)
	if element == "Shock" then
		throb = seeded(math.floor(t * 18), 7) -- a live wire doesn't breathe, it stutters
	end
	for name, edge in effect.Edges do
		edge.ChannelGradient.Offset = if name == "Top" or name == "Bottom"
			then Vector2.new(flow, 0)
			else Vector2.new(0, flow)
		edge.Glow.BackgroundTransparency = 0.3 - 0.25 * throb
	end
	for i, ring in effect.Aura do
		ring.Transparency = 0.35 + i * 0.18 - 0.25 * throb
	end
	for _, vent in effect.Vents do
		vent.BackgroundTransparency = 0.35 - 0.35 * throb
	end
	for _, corner in effect.Corners do
		corner.Notch.BackgroundTransparency = 0.3 - 0.3 * throb
	end
	effect.RimGradient.Rotation = (t * (if element == "Shock" then 300 else 140)) % 360
	effect.RimStroke.Transparency = 0.05

	local bits = effect.Bits
	local half = BITS / 2
	for i, bit in bits do
		local f = bit.Frame
		local main = i <= half
		if element == "Fire" then
			if main then
				-- Flame tongues licking up off the bottom rail, flickering.
				local x = (i - 0.5) / half * w
				local flick = 0.5 + 0.5 * math.sin(t * (9 + seeded(i, 1) * 6) + i * 2.1)
				local tall = 6 + seeded(i, 7) * 6 + flick * 6
				f.Position = UDim2.fromOffset(x, h - BAND - tall / 2 + 2)
				f.Size = UDim2.fromOffset(3 + seeded(i, 6) * 2, tall)
				bit.Taper.Transparency = SOLID
				f.Rotation = math.sin(t * 3 + i) * 8
				f.BackgroundColor3 = theme.Mid:Lerp(theme.Hot, flick * 0.6)
				f.BackgroundTransparency = 0.1 + 0.3 * (1 - flick)
				bit.Corner.CornerRadius = UDim.new(1, 0)
			else
				bit.Taper.Transparency = SOLID
				-- Embers rising the height of the card and drifting.
				local period = 1.6 + seeded(i, 1) * 1.6
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.05 + seeded(i, 6) * 0.9) * w + math.sin(t * 2 + i) * 6
				f.Position = UDim2.fromOffset(x, h - BAND - phase * h * 0.9)
				f.Size = UDim2.fromOffset(2.5, 2.5)
				f.Rotation = 0
				f.BackgroundColor3 = theme.Hot:Lerp(theme.Mid, phase)
				f.BackgroundTransparency = phase ^ 1.3
			end
			f.Visible = true
		elseif element == "Frost" then
			if main then
				-- Ice shards jutting in off the metal, catching the light.
				local d = (i - 0.5) / half * perimeter + seeded(i, 6) * 10
				local at, inward = around(d, w, h, BAND)
				local length = 7 + seeded(i, 7) * 10
				local p = at + inward * (length / 2)
				f.Position = UDim2.fromOffset(p.X, p.Y)
				f.Size = if inward.X == 0 then UDim2.fromOffset(3, length) else UDim2.fromOffset(length, 3)
				f.Rotation = (seeded(i, 8) - 0.5) * 30
				local glint = 0.5 + 0.5 * math.sin(t * 2.5 + i * 1.7)
				f.BackgroundColor3 = theme.Mid:Lerp(theme.Hot, glint)
				f.BackgroundTransparency = 0.35 - 0.3 * glint
			else
				-- Snow drifting down across the card.
				local period = 4 + seeded(i, 1) * 4
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.05 + seeded(i, 6) * 0.9) * w + math.sin(t * 1.2 + i) * 8
				f.Position = UDim2.fromOffset(x, BAND + phase * (h - BAND * 2))
				f.Size = UDim2.fromOffset(2.5, 2.5)
				f.Rotation = 0
				f.BackgroundColor3 = theme.Hot
				f.BackgroundTransparency = 0.2 + 0.7 * math.abs(phase - 0.5) * 2
			end
			f.Visible = true
		elseif element == "Shock" then
			-- Sparks spitting off the frame where the current jumps.
			local slot = math.floor(t * 8 + seeded(i, 2) * 6)
			local on = seeded(slot * 31 + i, 3) > (if main then 0.5 else 0.75)
			local at, inward = around(seeded(slot * 5 + i, 6) * perimeter, w, h, BAND)
			local p = at + inward * (2 + seeded(slot, i) * (if main then 8 else 20))
			f.Position = UDim2.fromOffset(p.X, p.Y)
			f.Size = if main then UDim2.fromOffset(3, 3) else UDim2.fromOffset(2, 6)
			f.Rotation = seeded(slot, i + 3) * 180
			f.BackgroundColor3 = theme.Hot
			f.BackgroundTransparency = 0
			f.Visible = on
		else
			if main then
				-- Sludge drips off the top rail and stretches as it falls.
				local period = 2 + seeded(i, 1) * 2
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.05 + seeded(i, 6) * 0.9) * w
				local fall = phase * phase * (18 + seeded(i, 7) * 22)
				f.Position = UDim2.fromOffset(x, BAND + fall)
				f.Size = UDim2.fromOffset(4.5, 4.5 + 7 * phase)
				f.BackgroundTransparency = 0.05 + 0.85 * phase ^ 2
			else
				-- Toxic bubbles rising off the bottom rail, swelling, popping.
				local period = 1.8 + seeded(i, 1) * 1.8
				local phase = (t / period + seeded(i, 2)) % 1
				local x = (0.05 + seeded(i, 6) * 0.9) * w + math.sin(t * 2 + i) * 3
				local size = 3 + phase * 5
				f.Position = UDim2.fromOffset(x, h - BAND - phase * 26)
				f.Size = UDim2.fromOffset(size, size)
				f.BackgroundColor3 = theme.Hot:Lerp(theme.Mid, 0.4)
				f.BackgroundTransparency = 0.3 + 0.65 * phase ^ 3
			end
			f.Rotation = 0
			f.Visible = true
		end
	end

	-- Ion: arcs crackle along a stretch of the frame, then jump.
	if element == "Shock" then
		if t >= effect.BoltUntil and t >= effect.NextBolt then
			effect.BoltSeed += 1
			effect.BoltUntil = t + 0.2
			effect.NextBolt = t + 0.3 + seeded(effect.BoltSeed, 9) * 0.6
		end
		if t < effect.BoltUntil then
			local flicker = if math.floor(t * 40) % 2 == 0 then 1 else 0.55
			for arc = 0, 1 do
				local seed = effect.BoltSeed * 3 + arc
				local start = seeded(seed, 1) * perimeter
				local length = 80 + seeded(seed, 2) * 120
				local previous = nil
				for i = 0, BOLT do
					local at, inward = around(start + length * i / BOLT, w, h, BAND / 2)
					local p = at + inward * (seeded(seed * 17 + i, 4) * 12)
					if previous then
						line(effect.Bolt[arc * BOLT + i], previous, p, if arc == 0 then 2.5 else 1.5, theme.Hot, 0.95 * flicker)
					end
					previous = p
				end
			end
		else
			for _, segment in effect.Bolt do
				segment.Visible = false
			end
		end
	end
end

return FX
