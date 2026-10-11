--[[
	Elemental cards: a socketed gem's element shows as clean energy round
	its card, not clutter on it. Character comes from colour and motion.

	  Border    a crisp edge in the element's colour with a bright charge
	            racing round it (two charges for Ion)
	  Aura      two soft rings outside the edge, breathing with the element
	  Corners   hot L-brackets at the four corners
	  Pool      energy pooling faintly along the card's lower edge
	  Sheen     a light sweep across the card every few seconds
	  Socket    a ring round the gem well, pulsing

	  Thermal     warm, fast charge; the aura flickers like a fire
	  Cryo        icy white, slow; a frequent cold glint sweeps across
	  Ion         two charges racing; the aura stutters, the edge flashes
	  Corrosive   toxic green, slow and heavy; the aura oozes

	Built once per card (create), only recoloured and moved each frame
	(update), so a full inventory makes no new instances.

	  ElementCardFX.create(card, gemWell) -> effect
	  ElementCardFX.update(effect, element?, time)   nil element hides it
]]
local FX = {}

local THEMES = {
	Fire = {
		Hot = Color3.fromRGB(255, 232, 160),
		Mid = Color3.fromRGB(255, 120, 30),
		Deep = Color3.fromRGB(170, 34, 10),
		Spin = 170, -- degrees per second of the charge round the edge
		Sheen = 5, -- seconds between light sweeps
	},
	Frost = {
		Hot = Color3.fromRGB(245, 253, 255),
		Mid = Color3.fromRGB(120, 210, 255),
		Deep = Color3.fromRGB(30, 90, 180),
		Spin = 55,
		Sheen = 3,
	},
	Shock = {
		Hot = Color3.fromRGB(255, 252, 220),
		Mid = Color3.fromRGB(255, 216, 60),
		Deep = Color3.fromRGB(160, 110, 0),
		Spin = 420,
		Sheen = 4,
	},
	Poison = {
		Hot = Color3.fromRGB(210, 255, 160),
		Mid = Color3.fromRGB(70, 220, 100),
		Deep = Color3.fromRGB(16, 90, 40),
		Spin = 70,
		Sheen = 6,
	},
}
FX.Themes = THEMES

local function make(class: string, props, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function seeded(i: number, salt: number): number
	local x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
	return x - math.floor(x)
end

-- A frame round the card, `grow` px outside it, carrying only a stroke.
local function ring(card: GuiObject, grow: number, z: number, thickness: number): (Frame, UIStroke)
	local frame = make("Frame", {
		Name = "ElementalRing",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-grow, -grow),
		Size = UDim2.new(1, grow * 2, 1, grow * 2),
		ZIndex = z,
		Active = false,
		Visible = false,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8 + grow) }, frame)
	local stroke = make("UIStroke", {
		Thickness = thickness,
		Color = Color3.new(1, 1, 1),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	return frame, stroke
end

function FX.create(card: GuiObject, gemWell: GuiObject?)
	local shown = {}

	-- The aura: two soft rings outside the edge.
	local aura = {}
	for i, grow in { 3, 7 } do
		local frame, stroke = ring(card, grow, 6, if i == 1 then 3 else 4)
		aura[i] = stroke
		table.insert(shown, frame)
	end

	-- The border, with the charge racing round it.
	local borderFrame, border = ring(card, 0, 12, 2)
	local charge = make("UIGradient", {}, border)
	table.insert(shown, borderFrame)

	-- Hot corner brackets.
	local corners = {}
	for _, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local x, y = corner[1], corner[2]
		for _, size in { Vector2.new(16, 3), Vector2.new(3, 16) } do
			local arm = make("Frame", {
				Name = "ElementalCorner",
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(x, y),
				Position = UDim2.new(x, if x == 0 then -1 else 1, y, if y == 0 then -1 else 1),
				Size = UDim2.fromOffset(size.X, size.Y),
				ZIndex = 13,
				Visible = false,
			}, card)
			table.insert(corners, arm)
			table.insert(shown, arm)
		end
	end

	-- Energy pooling along the lower edge, under the card's text.
	local pool = make("Frame", {
		Name = "ElementalPool",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Visible = false,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, pool)
	local poolGradient = make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
	}, pool)
	table.insert(shown, pool)

	-- The sheen: a soft diagonal band of light sliding across.
	local sheen = make("Frame", {
		Name = "ElementalSheen",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Visible = false,
		Active = false,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, sheen)
	local sheenGradient = make("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.78),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
	}, sheen)
	table.insert(shown, sheen)

	-- A ring round the gem well.
	local socket = nil
	if gemWell then
		local frame
		frame, socket = ring(gemWell, 3, (gemWell.ZIndex or 1) + 1, 2)
		table.insert(shown, frame)
	end

	return {
		Shown = shown,
		Aura = aura,
		Border = border,
		Charge = charge,
		Corners = corners,
		Pool = pool,
		PoolGradient = poolGradient,
		Sheen = sheen,
		SheenGradient = sheenGradient,
		Socket = socket,
		Element = nil,
		Visible = false,
	}
end

local function paint(effect, theme, element: string)
	local hot, mid, deep = theme.Hot, theme.Mid, theme.Deep
	-- The charge: a short bright streak on a dimmer edge (Ion: two).
	local keys = if element == "Shock"
		then {
			ColorSequenceKeypoint.new(0, deep),
			ColorSequenceKeypoint.new(0.18, mid),
			ColorSequenceKeypoint.new(0.24, hot),
			ColorSequenceKeypoint.new(0.3, mid),
			ColorSequenceKeypoint.new(0.5, deep),
			ColorSequenceKeypoint.new(0.68, mid),
			ColorSequenceKeypoint.new(0.74, hot),
			ColorSequenceKeypoint.new(0.8, mid),
			ColorSequenceKeypoint.new(1, deep),
		}
		else {
			ColorSequenceKeypoint.new(0, deep),
			ColorSequenceKeypoint.new(0.35, mid),
			ColorSequenceKeypoint.new(0.5, hot),
			ColorSequenceKeypoint.new(0.65, mid),
			ColorSequenceKeypoint.new(1, deep),
		}
	effect.Charge.Color = ColorSequence.new(keys)
	for _, stroke in effect.Aura do
		stroke.Color = mid
	end
	for _, arm in effect.Corners do
		arm.BackgroundColor3 = hot
	end
	effect.Pool.BackgroundColor3 = mid
	effect.Sheen.BackgroundColor3 = hot
	if effect.Socket then
		effect.Socket.Color = mid
	end
end

local function show(effect, on: boolean)
	if effect.Visible == on then
		return
	end
	effect.Visible = on
	for _, object in effect.Shown do
		object.Visible = on
	end
end

function FX.update(effect, element: string?, time: number)
	local theme = element and THEMES[element]
	show(effect, theme ~= nil)
	if not theme then
		effect.Element = nil
		return
	end
	if effect.Element ~= element then
		effect.Element = element
		paint(effect, theme, element :: string)
	end
	local t = time

	-- How the energy lives: a fire flickers, ice holds, a live wire
	-- stutters, acid oozes.
	local life
	if element == "Fire" then
		life = 0.55 + 0.25 * math.sin(t * 7.3) + 0.2 * math.sin(t * 13.1 + 1.7)
	elseif element == "Frost" then
		life = 0.6 + 0.15 * math.sin(t * 1.1)
	elseif element == "Shock" then
		life = 0.3 + 0.7 * seeded(math.floor(t * 16), 7)
	else
		life = 0.5 + 0.45 * math.sin(t * 1.6) ^ 3
	end
	life = math.clamp(life, 0, 1)

	effect.Charge.Rotation = (t * theme.Spin) % 360
	-- Ion: now and then the whole edge flashes white-hot.
	local flash = element == "Shock" and seeded(math.floor(t * 6), 11) > 0.85
	effect.Border.Thickness = if flash then 3 else 2
	effect.Border.Transparency = 0
	for i, stroke in effect.Aura do
		stroke.Transparency = math.clamp(0.45 + i * 0.2 - 0.3 * life, 0, 1)
	end
	for _, arm in effect.Corners do
		arm.BackgroundTransparency = 0.25 - 0.25 * life
	end
	effect.Pool.BackgroundTransparency = 0.55 - 0.25 * life
	if effect.Socket then
		effect.Socket.Transparency = 0.6 - 0.5 * life
	end

	-- The sheen slides across, then rests until the next sweep.
	local cycle = (t % theme.Sheen) / 0.9
	effect.SheenGradient.Offset = Vector2.new(if cycle < 1 then -1 + cycle * 2 else 1, 0)
	effect.Sheen.BackgroundTransparency = if cycle < 1 then 0 else 1
end

return FX
