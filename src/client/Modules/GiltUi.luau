--[[
	The gilt look (first the Bounty Board's, Client RiftClient; now the
	Kennel's sale too, Client KennelSale): what a fantasy MMO's dialog window
	looks like, not a toy's. Dark stone in a bronze border with a gold
	hairline inside it, serif words in old gold or warm ivory, sentence case,
	and colour kept for what it means.

	  Gilt.frame(holder, width, compact?) -> body   the framed window (its body a list)
	  Gilt.well(frame, edge?)        a recessed well
	  Gilt.stud(parent, size, at)    a gilt diamond
	  Gilt.rule(parent, both?)       a gilt hairline
	  Gilt.words(parent, text, size, color)   serif words
	  Gilt.heading(parent, text, order, small)   a section's heading
	  Gilt.button(parent, text, primary, order, onClick?, tall?, size?)
]]
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new

-- The look of a fantasy MMO's dialog window: a gilt frame
-- on dark stone, serif headings in old gold, words in sentence case, and
-- colour kept for what it means (the boss's element, a level's danger,
-- ready or not).
local Gilt = {
	Gold = Color3.fromRGB(228, 188, 100),
	Bright = Color3.fromRGB(255, 226, 150),
	Brass = Color3.fromRGB(140, 110, 60),
	Bronze = Color3.fromRGB(70, 50, 28),
	Stone = Color3.fromRGB(27, 22, 18),
	Deep = Color3.fromRGB(11, 9, 8),
	Well = Color3.fromRGB(16, 13, 11),
	Ink = Color3.fromRGB(236, 224, 200),
	Faded = Color3.fromRGB(162, 146, 118),
	Dusk = Color3.fromRGB(112, 100, 82),
	Green = Color3.fromRGB(124, 214, 98),
	Red = Color3.fromRGB(214, 92, 70),
	Serif = Enum.Font.Merriweather,
}

-- A recessed well: darker stone in a brass hairline.
function Gilt.well(frame: GuiObject, edge: Color3?): UIStroke
	frame.BackgroundColor3 = Gilt.Well
	UiKit.round(frame, 3)
	return new("UIStroke", {
		Color = edge or Gilt.Brass,
		Thickness = 1,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

-- A small gilt diamond: the frame's corners, a divider's middle.
function Gilt.stud(parent: Instance, size: number, at: UDim2): Frame
	local stud = new("Frame", {
		Name = "Stud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundColor3 = Gilt.Deep,
		ZIndex = 3,
	}, parent)
	new("UIStroke", { Color = Gilt.Gold, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stud)
	return stud
end

-- A gilt hairline: fading out to the right, or to both ends (`both`).
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
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			}),
	}, line)
	return line
end

-- Serif words (a heading, a name, a button's), with a thin dark edge.
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
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.55 }, label)
	return label
end

-- A section's heading: gold serif words over a gilt rule fading out.
function Gilt.heading(parent: Instance, label: string, order: number, small: boolean): TextLabel
	local row = new("Frame", {
		Name = "Heading",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 18 else 27),
		LayoutOrder = order,
	}, parent)
	local words = Gilt.words(row, label, if small then 12 else 16, Gilt.Gold)
	words.Size = UDim2.new(1, 0, 1, -3)
	local rule = Gilt.rule(row)
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	return words
end

-- A button: crimson in a gold rim for the one that matters (`primary`),
-- dark stone in brass for the rest. The rim brightens under the mouse.
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
		Font = Gilt.Serif,
		TextColor3 = if primary then Gilt.Bright else Gilt.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, tall or 40),
		LayoutOrder = order,
	}, parent)
	UiKit.round(b, 3)
	new("UIGradient", {
		Rotation = 90,
		Color = if primary
			then ColorSequence.new(Color3.fromRGB(158, 34, 22), Color3.fromRGB(82, 14, 10))
			else ColorSequence.new(Color3.fromRGB(56, 46, 36), Color3.fromRGB(28, 22, 17)),
	}, b)
	local rim = new("UIStroke", {
		Color = if primary then Gilt.Gold else Gilt.Brass,
		Thickness = if primary then 1.5 else 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	-- (its words lifted off the face: a soft shadow, never a dark outline)
	b.TextStrokeColor3, b.TextStrokeTransparency = Color3.new(0, 0, 0), 0.75
	-- (light catching its top edge)
	new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if primary then 0.8 else 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.new(1, -4, 0, 1),
	}, b)
	local rest = rim.Color
	b.MouseEnter:Connect(function()
		rim.Color = Gilt.Bright
	end)
	b.MouseLeave:Connect(function()
		rim.Color = rest
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- The gilt frame: dark stone in a bronze
-- border, a gold hairline inside it with a stud at each corner. Its body
-- (a list) to fill.
function Gilt.frame(holder: Instance, width: number, compact: boolean?): Frame
	local frame = new("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	UiKit.round(frame, 4)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 30, 23)),
			ColorSequenceKeypoint.new(0.3, Gilt.Stone),
			ColorSequenceKeypoint.new(1, Gilt.Deep),
		}),
	}, frame)
	new("UIStroke", { Color = Gilt.Bronze, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local rim = new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
	}, frame)
	UiKit.round(rim, 2)
	new("UIStroke", { Color = Gilt.Gold, Thickness = 1, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, rim)
	for _, corner in { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), UDim2.fromScale(1, 1) } do
		Gilt.stud(rim, 7, corner)
	end
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
