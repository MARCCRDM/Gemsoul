--[[
	The windows' look (the Bounty Board's, Client RiftClient; the Kennel's
	sale, Client KennelSale; the coin packs, Client CoinShop): a game's
	window, sharp and modern. Deep navy panels with a cool sheen down them,
	an amber bar along the top, bold clean words (headings in capitals),
	glossy amber for the button that matters, slate for the rest, and colour
	kept for what it means (the boss's element, a level's danger, ready or
	not). (The module keeps its old name, Gilt, and its old calls.)

	  Gilt.frame(holder, width, compact?) -> body   the framed window (its body a list)
	  Gilt.well(frame, edge?)        a recessed well
	  Gilt.stud(parent, size, at)    a small amber diamond
	  Gilt.rule(parent, both?)       an amber hairline
	  Gilt.words(parent, text, size, color)   bold words
	  Gilt.heading(parent, text, order, small)   a section's heading
	  Gilt.button(parent, text, primary, order, onClick?, tall?, size?)
]]
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new

local Gilt = {
	-- (the old names, the new colours: amber for gold, steel for brass)
	Gold = Color3.fromRGB(255, 196, 64),
	Bright = Color3.fromRGB(255, 226, 140),
	Brass = Color3.fromRGB(62, 76, 108),
	Bronze = Color3.fromRGB(40, 50, 76),
	Stone = Color3.fromRGB(18, 23, 37),
	Deep = Color3.fromRGB(8, 11, 20),
	Well = Color3.fromRGB(12, 16, 28),
	Ink = Color3.fromRGB(238, 242, 250),
	Faded = Color3.fromRGB(150, 162, 188),
	Dusk = Color3.fromRGB(98, 110, 138),
	Green = Color3.fromRGB(92, 228, 142),
	Red = Color3.fromRGB(255, 92, 92),
	-- (Serif was the old heading face; the words are Gotham now)
	Serif = Enum.Font.GothamBold,
	Display = Enum.Font.GothamBlack,
}

-- A recessed well: darker navy in a steel hairline.
function Gilt.well(frame: GuiObject, edge: Color3?): UIStroke
	frame.BackgroundColor3 = Gilt.Well
	UiKit.round(frame, 8)
	return new("UIStroke", {
		Color = edge or Gilt.Brass,
		Thickness = 1,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

-- A small amber diamond: a divider's middle.
function Gilt.stud(parent: Instance, size: number, at: UDim2): Frame
	local stud = new("Frame", {
		Name = "Stud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundColor3 = Gilt.Gold,
		ZIndex = 3,
	}, parent)
	return stud
end

-- An amber hairline: fading out to the right, or to both ends (`both`).
function Gilt.rule(parent: Instance, both: boolean?): Frame
	local line = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Gilt.Gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, parent)
	new("UIGradient", {
		Transparency = if both
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.6, 0.9),
				NumberSequenceKeypoint.new(1, 1),
			}),
	}, line)
	return line
end

-- Bold words (a heading, a name, a button's).
function Gilt.words(parent: Instance, value: string, size: number, color: Color3): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = Gilt.Serif,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, size + 6),
	}, parent)
	return label
end

-- A section's heading: an amber tick, the words in capitals, a hairline.
function Gilt.heading(parent: Instance, label: string, order: number, small: boolean): TextLabel
	local row = new("Frame", {
		Name = "Heading",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 18 else 24),
		LayoutOrder = order,
	}, parent)
	local tick = new("Frame", {
		Name = "Tick",
		BackgroundColor3 = Gilt.Gold,
		Position = UDim2.fromOffset(0, if small then 3 else 4),
		Size = UDim2.fromOffset(3, if small then 10 else 13),
	}, row)
	UiKit.round(tick, 2)
	local words = Gilt.words(row, string.upper(label), if small then 11 else 13, Gilt.Gold)
	words.Font = Gilt.Display
	words.Position = UDim2.fromOffset(10, 0)
	words.Size = UDim2.new(1, -10, 1, -3)
	words.TextYAlignment = Enum.TextYAlignment.Top
	local rule = Gilt.rule(row)
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	rule.BackgroundColor3 = Gilt.Brass
	return words
end

-- A button: glossy amber with dark words for the one that matters
-- (`primary`), slate in a steel rim for the rest; it brightens under the
-- mouse. Its colour is a face behind its words (a gradient on the button
-- itself would tint the words too): the button keeps its own Text,
-- TextColor3 and the rest to set, and its Words follow them.
function Gilt.button(
	parent: Instance,
	label: string,
	primary: boolean,
	order: number,
	onClick: (() -> ())?,
	tall: number?,
	size: number?
): TextButton
	local b = new("TextButton", {
		Name = "Button",
		Text = label,
		TextSize = size or 16,
		Font = if primary then Gilt.Display else Gilt.Serif,
		TextColor3 = if primary then Color3.fromRGB(34, 18, 2) else Gilt.Ink,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, tall or 40),
		LayoutOrder = order,
	}, parent)
	UiKit.round(b, 8)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, b)
	UiKit.round(face, 8)
	local rest = if primary
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 222, 110)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 184, 52)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 130, 24)),
		})
		else ColorSequence.new(Color3.fromRGB(44, 54, 80), Color3.fromRGB(26, 32, 50))
	local lit = if primary
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 202, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(252, 148, 36)),
		})
		else ColorSequence.new(Color3.fromRGB(58, 70, 102), Color3.fromRGB(34, 42, 64))
	local shade = new("UIGradient", { Rotation = 90, Color = rest }, face)
	local rim = new("UIStroke", {
		Color = if primary then Color3.fromRGB(255, 240, 180) else Gilt.Brass,
		Thickness = if primary then 1.5 else 1,
		Transparency = if primary then 0.35 else 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	-- (light catching its top edge)
	new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if primary then 0.55 else 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 0, 1),
		ZIndex = 2,
	}, b)
	local words = new("TextLabel", {
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, b)
	local function follow()
		words.Text, words.TextSize, words.Font = b.Text, b.TextSize, b.Font
		words.TextColor3, words.TextTruncate, words.RichText = b.TextColor3, b.TextTruncate, b.RichText
		words.TextXAlignment, words.TextWrapped, words.TextScaled = b.TextXAlignment, b.TextWrapped, b.TextScaled
	end
	follow()
	for _, property in { "Text", "TextSize", "Font", "TextColor3", "TextTruncate", "RichText", "TextXAlignment", "TextWrapped", "TextScaled" } do
		b:GetPropertyChangedSignal(property):Connect(follow)
	end
	-- (a button's words faded is its Words faded: its own stay hidden)
	b:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		if b.TextTransparency < 1 then
			words.TextTransparency = b.TextTransparency
			b.TextTransparency = 1
		end
	end)
	b.MouseEnter:Connect(function()
		shade.Color = lit
		rim.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		shade.Color = rest
		rim.Transparency = if primary then 0.35 else 0.1
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- The window: deep navy with a cool sheen down it, a steel edge, an amber
-- bar along the top glowing at its middle. Its body (a list) to fill.
function Gilt.frame(holder: Instance, width: number, compact: boolean?): Frame
	local frame = new("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	UiKit.round(frame, 14)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 36, 58)),
			ColorSequenceKeypoint.new(0.35, Gilt.Stone),
			ColorSequenceKeypoint.new(1, Gilt.Deep),
		}),
	}, frame)
	new("UIStroke", { Color = Gilt.Bronze, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	-- (the amber bar along the top, brightest at its middle)
	local bar = new("Frame", {
		Name = "Rim",
		BackgroundColor3 = Gilt.Gold,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 0, 3),
	}, frame)
	UiKit.round(bar, 2)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, bar)
	local body = new("Frame", {
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, frame)
	UiKit.pad(body, if compact then 8 else 20)
	UiKit.list(body, if compact then 4 else 10)
	return body
end

return Gilt
