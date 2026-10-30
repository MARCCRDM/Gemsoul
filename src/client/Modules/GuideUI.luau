--[[
	The GUIDE window: how to play, a page a topic (Shared.GameGuide). It
	opens from the lobby's GUIDE tile (on a computer and on a phone), and
	from a step's GO in the Tasks window, on that step's page.

	It's the Tasks window's Rift terminal, as a field manual: dark glass,
	cyan light along its edges and corner brackets, a double frame, Michroma
	for its name, Sarpanch for names and numbers, Titillium for the words.
	On a computer: the pages down the left, numbered 01 to 08, the open one
	lit magenta; the page on the right, SECTION 04 over its name and line,
	then its tips as manual entries two to a row, each with the key it's
	about on a terminal key cap (or its number). On a phone: the pages as a
	row of tabs along the top, the same entries one to a row, the phone's
	own buttons in place of the keys. PREV and NEXT page through it like a
	booklet; OPEN TASKS at the bottom goes to the step-by-step path.
	Everything is frames, gradients and strokes (no images).

	ScreenGui "TipGuide" (one of UiKit.Covers: what sits over the play view
	steps aside while it's up).

	  GuideUI.open(id?)   on page `id` (Shared.GameGuide's Id), else where it was
	  GuideUI.close()
	  GuideUI.toggle()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameGuide = require(ReplicatedStorage.Shared.GameGuide)
local Lang = require(ReplicatedStorage.Shared.Lang)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

-- The terminal's light (as Tasks): cyan for the frame and the keys, magenta
-- for the page you're on, on dark glass.
local GLASS_TOP = Color3.fromRGB(16, 36, 46)
local GLASS_BOTTOM = Color3.fromRGB(5, 12, 19)
local CYAN = Color3.fromRGB(54, 241, 205)
local CYAN_LIT = Color3.fromRGB(150, 255, 236)
local PINK = Color3.fromRGB(255, 79, 216)
local TEXT = Color3.fromRGB(232, 246, 250)
local DIM = Color3.fromRGB(127, 179, 196)
local FAINT = Color3.fromRGB(79, 132, 150)
local LINE = Color3.fromRGB(29, 67, 82)
local INK = Color3.fromRGB(4, 14, 20)
local TITLE = Enum.Font.Michroma -- (the window's name)
local HEAD = Enum.Font.Sarpanch -- (names, numbers and keys)
local BODY = Enum.Font.TitilliumWeb -- (the words)

GameGuide.closeFor(Config.Features or {})

local GuideUI = {}

local gui = UiKit.gui("TipGuide", 26)
gui.Enabled = false

local function new(kind: string, props, parent: Instance?)
	local o = Instance.new(kind)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end
local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or DIM,
		Font = font or BODY,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end
-- Light along a line: bright at one end, gone by the other.
local function fade(object: GuiObject, from: number, to: number, rotation: number?)
	return new("UIGradient", { Rotation = rotation or 0, Transparency = NumberSequence.new(from, to) }, object)
end
-- A corner bracket: two bars meeting at `corner` ("TL", "TR", "BL", "BR"),
-- with a soft glow (a wider, fainter copy under them).
local function bracket(parent: GuiObject, corner: string, color: Color3, length: number, thick: number)
	local x = if corner == "TL" or corner == "BL" then 0 else 1
	local y = if corner == "TL" or corner == "TR" then 0 else 1
	for _, glow in { true, false } do
		local t = if glow then thick + 4 else thick
		local inset = if glow then -2 else 0
		local common = {
			AnchorPoint = Vector2.new(x, y),
			Position = UDim2.new(x, if x == 0 then inset else -inset, y, if y == 0 then inset else -inset),
			BackgroundColor3 = color,
			BackgroundTransparency = if glow then 0.82 else 0,
			ZIndex = 4,
		}
		new("Frame", common, parent).Size = UDim2.fromOffset(length, t)
		new("Frame", common, parent).Size = UDim2.fromOffset(t, math.floor(length * 0.62))
	end
end
-- How wide some words are as the player reads them (maybe in Spanish).
local function textWidth(text: string, size: number, font: Enum.Font): number
	text = Lang.translate(text)
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100))
	end)
	return if ok and typeof(bounds) == "Vector2" then bounds.X else #text * size * 0.7
end
-- How tall some wrapped words are at `width` (Roblox's own measure; a fair
-- guess without it).
local function textHeight(text: string, size: number, font: Enum.Font, width: number): number
	text = Lang.translate(text)
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(width, 1000))
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.Y
	end
	return math.ceil(#text * size * 0.5 / math.max(width, 1)) * size * 1.25
end
local function two(n: number): string
	return string.format("%02d", n)
end

-- The window, over a shade that closes it when tapped.
local shade = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.25,
	Text = "",
	AutoButtonColor = false,
}, gui)
local panel = new("TextButton", { -- (a button, so taps inside don't reach the shade)
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.03,
	Text = "",
	AutoButtonColor = false,
}, shade)
UiKit.round(panel, 4)
new("UIGradient", { Rotation = 100, Color = ColorSequence.new(GLASS_TOP, GLASS_BOTTOM) }, panel)
stroke(panel, CYAN, 0.78)
local scale = new("UIScale", {}, panel)
-- The double frame: a second hairline just inside the first.
local inner = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12) }, panel)
UiKit.round(inner, 2)
stroke(inner, LINE, 0.1)
-- Light falling from the top of the glass.
local sheen = new("Frame", { BackgroundColor3 = CYAN, Size = UDim2.new(1, 0, 0, 66) }, panel)
UiKit.round(sheen, 4)
fade(sheen, 0.93, 1, 90)
for _, corner in { "TL", "TR", "BL", "BR" } do
	bracket(panel, corner, CYAN, 54, 2)
end

-- GUIDE (lit cyan) and FIELD MANUAL; the rule between the pages and the page.
local heading = label(panel, "GUIDE", 24, CYAN, TITLE)
heading.TextTruncate = Enum.TextTruncate.None
new("UIStroke", { Color = CYAN, Transparency = 0.8, Thickness = 2 }, heading)
local manual = label(panel, "FIELD MANUAL", 12, FAINT, HEAD)
local divider = new("Frame", { BackgroundColor3 = LINE }, panel)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.3,
	Text = "",
	AutoButtonColor = false,
}, panel)
UiKit.round(close, 2)
local closeRim = stroke(close, CYAN, 0.35, 1.5)
local closeBars = IronUi.cross(close, 14, CYAN)
close:SetAttribute("UiSound", "Back")
close.MouseEnter:Connect(function()
	closeRim.Transparency = 0
	for _, b in closeBars do
		b.BackgroundColor3 = CYAN_LIT
	end
end)
close.MouseLeave:Connect(function()
	closeRim.Transparency = 0.35
	for _, b in closeBars do
		b.BackgroundColor3 = CYAN
	end
end)

-- The pages: down the left (computer) or a row of tabs (phone).
local pages = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local pagesList = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, pages)

-- The page: SECTION 04, its name and where it is in the book, its line, a
-- rule with a lit end and a diamond, then its entries.
local sectionTag = label(panel, "", 12, PINK, HEAD)
local title = label(panel, "", 26, TEXT, HEAD)
local pageCount = label(panel, "", 14, FAINT, HEAD)
pageCount.TextXAlignment = Enum.TextXAlignment.Right
pageCount:SetAttribute("NoTranslate", true)
local blurb = label(panel, "", 15, DIM, BODY)
local rule = new("Frame", { BackgroundColor3 = LINE }, panel)
local ruleLit = new("Frame", { BackgroundColor3 = CYAN, Size = UDim2.fromOffset(110, 1) }, rule)
fade(ruleLit, 0, 1)
new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(7, 7),
	Rotation = 45,
	BackgroundColor3 = CYAN,
}, rule)
local tips = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = CYAN,
}, panel)
local grid = new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellPadding = UDim2.fromOffset(14, 10) }, tips)

-- Along the bottom, over a hairline: OPEN TASKS, then PREV, the page and NEXT.
local footRule = new("Frame", { BackgroundColor3 = LINE }, panel)
-- A ghost button (cyan rim, cyan words), or NEXT: lit cyan glass, dark words.
local function footButton(text: string, lit: boolean): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if lit then Color3.new(1, 1, 1) else INK,
		BackgroundTransparency = if lit then 0 else 0.35,
		Text = text,
		TextSize = 16,
		Font = HEAD,
		TextColor3 = if lit then INK else CYAN,
		AutoButtonColor = false,
	}, panel)
	UiKit.round(b, 2)
	if lit then
		local shine = new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(96, 244, 214), Color3.fromRGB(14, 150, 132)),
		}, b)
		local glow = stroke(b, CYAN, 0.55, 3)
		new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.new(1, -8, 0, 1),
		}, b)
		b:SetAttribute("UiSound", "Confirm")
		b.MouseEnter:Connect(function()
			shine.Color = ColorSequence.new(Color3.fromRGB(150, 255, 234), Color3.fromRGB(30, 190, 166))
			glow.Transparency = 0.25
		end)
		b.MouseLeave:Connect(function()
			shine.Color = ColorSequence.new(Color3.fromRGB(96, 244, 214), Color3.fromRGB(14, 150, 132))
			glow.Transparency = 0.55
		end)
	else
		local rim = stroke(b, CYAN, 0.55, 1)
		b.MouseEnter:Connect(function()
			rim.Transparency, b.TextColor3 = 0.1, CYAN_LIT
		end)
		b.MouseLeave:Connect(function()
			rim.Transparency, b.TextColor3 = 0.55, CYAN
		end)
	end
	IronUi.juice(b, 1.03, 0.97)
	return b
end
local tasksButton = footButton("OPEN TASKS", false)
local prev = footButton("‹  PREV", false)
local nextButton = footButton("NEXT  ›", true)
local footCount = label(panel, "", 14, FAINT, HEAD)
footCount.TextXAlignment = Enum.TextXAlignment.Center
footCount:SetAttribute("NoTranslate", true)

local current = 1
local phone = false
local columns, cellW = 2, 300 -- (the entries' grid, as laid out)
local pageButtons = {}
local render -- (below)

for i, section in GameGuide.Sections do
	local b = new("TextButton", {
		BackgroundColor3 = CYAN,
		Text = "",
		LayoutOrder = i,
		AutoButtonColor = false,
	}, pages)
	b:SetAttribute("UiSound", "Tab")
	local wash = fade(b, 0.9, 1)
	local edge = new("Frame", { Name = "Edge", BackgroundColor3 = LINE }, b)
	-- Open: a magenta edge (at the left, or under a tab) with its glow.
	local mark = new("Frame", { Name = "Mark", BackgroundColor3 = PINK, Visible = false }, b)
	local markGlow = new("Frame", { Name = "MarkGlow", BackgroundColor3 = PINK, BackgroundTransparency = 0.75, Visible = false }, b)
	local number = label(b, two(i), 13, FAINT, HEAD)
	number.Name = "Number"
	number:SetAttribute("NoTranslate", true)
	local name = label(b, section.Title, 15, DIM, HEAD)
	name.Name = "Name"
	b.MouseEnter:Connect(function()
		name.TextColor3 = TEXT
	end)
	b.MouseLeave:Connect(function()
		name.TextColor3 = if i == current then TEXT else DIM
	end)
	b.Activated:Connect(function()
		current = i
		render()
		tips.CanvasPosition = Vector2.zero
	end)
	pageButtons[i] = { Button = b, Wash = wash, Edge = edge, Mark = mark, MarkGlow = markGlow, Number = number, Name = name }
end

-- The key a tip shows on this screen (a phone's button, else the key), or nil.
local function keyOf(tip): string?
	local keyText = if phone then tip.Phone else tip.Key
	if keyText == nil and tip.Key ~= nil and phone then
		keyText = tip.Key
	end
	return if keyText == false then nil else keyText
end
local function capHeight(): number
	return if phone then 30 else 34
end
-- How wide a key's cap is.
local function capWidth(keyText: string?): number
	local h = capHeight()
	return if keyText then math.max(h + 6, math.ceil(textWidth(keyText, 15, HEAD)) + 20) else h
end

-- One entry: its key on a terminal cap (or its number), its name and words,
-- over a hairline with a lit end. `column`: the page's widest cap, so every
-- entry's words start in line.
local function tipCard(i: number, tip, column: number)
	local card = new("Frame", {
		BackgroundColor3 = CYAN,
		BackgroundTransparency = 0,
		LayoutOrder = i,
	}, tips)
	fade(card, 0.955, 1, 0)
	local top = new("Frame", { BackgroundColor3 = LINE, Size = UDim2.new(1, 0, 0, 1) }, card)
	local lit = new("Frame", { BackgroundColor3 = CYAN, Size = UDim2.fromOffset(36, 1) }, top)
	fade(lit, 0.2, 1)
	local keyText = keyOf(tip)
	local capH, capW = capHeight(), capWidth(keyText)
	local cap = new("Frame", {
		Name = "Key",
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(capW, capH),
		BackgroundColor3 = INK,
		BackgroundTransparency = if keyText then 0.1 else 0.5,
	}, card)
	UiKit.round(cap, 2)
	stroke(cap, if keyText then CYAN else LINE, if keyText then 0.35 else 0)
	if keyText then
		-- (A key cap: a lit lip along its bottom.)
		new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 3, 1, -2),
			Size = UDim2.new(1, -6, 0, 2),
			BackgroundColor3 = CYAN,
			BackgroundTransparency = 0.55,
		}, cap)
	end
	local capText = label(cap, keyText or two(i), 15, if keyText then CYAN else FAINT, HEAD)
	capText.Size, capText.TextXAlignment, capText.TextTruncate = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, Enum.TextTruncate.None
	if not keyText or not phone then
		capText:SetAttribute("NoTranslate", true) -- (a key's name, or a number; a phone's buttons are words)
	end
	local left = 10 + column + 12
	local head = label(card, tip.Title, 17, TEXT, HEAD)
	head.Position, head.Size = UDim2.fromOffset(left, 9), UDim2.new(1, -left - 10, 0, 22)
	local words = label(card, tip.Text, 14, DIM, BODY)
	words.TextWrapped, words.TextTruncate, words.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
	words.Position, words.Size = UDim2.fromOffset(left, 32), UDim2.new(1, -left - 10, 1, -36)
	return card
end

-- Where everything goes, for this screen.
local laidOut = Vector2.zero
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	laidOut = screen
	phone = UiKit.handheld(screen)
	local short = phone or screen.Y < 560
	local width = math.min(if short then 900 else 940, screen.X - (if short then 20 else 60))
	local height = math.min(if short then 620 else 600, screen.Y - (if short then 16 else 60))
	panel.Size = UDim2.fromOffset(width, height)
	local room, at = UiKit.clearTopbar(screen, Vector2.new(width, height))
	scale.Scale, panel.Position = room, at
	local pad = if short then 14 else 22
	local closeSize = if short then 32 else 36
	close.Size = UDim2.fromOffset(closeSize, closeSize)
	close.Position = UDim2.new(1, -pad + 4, 0, pad - 6)
	local footH = if short then 34 else 40
	local contentX, contentY
	if short then
		-- A phone: GUIDE, then the pages as a row of tabs along the top.
		heading.TextSize = 18
		heading.Position, heading.Size = UDim2.fromOffset(pad, pad - 2), UDim2.fromOffset(96, 30)
		manual.Visible = false
		local tabsX = pad + 104
		pages.Position = UDim2.fromOffset(tabsX, pad - 2)
		pages.Size = UDim2.new(1, -tabsX - pad - closeSize - 8, 0, 32)
		pages.ScrollingDirection = Enum.ScrollingDirection.X
		pages.AutomaticCanvasSize = Enum.AutomaticSize.X
		pagesList.FillDirection = Enum.FillDirection.Horizontal
		pagesList.VerticalAlignment = Enum.VerticalAlignment.Center
		for i, p in pageButtons do
			local w = math.ceil(textWidth(GameGuide.Sections[i].Title, 13, HEAD)) + 42
			p.Button.Size = UDim2.fromOffset(w, 30)
			p.Wash.Rotation = 90
			p.Edge.Position, p.Edge.Size = UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1)
			p.Mark.Position, p.Mark.Size = UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2)
			p.MarkGlow.Position, p.MarkGlow.Size = UDim2.new(0, 0, 1, -5), UDim2.new(1, 0, 0, 5)
			p.Number.Position, p.Number.Size, p.Number.TextSize = UDim2.fromOffset(6, 0), UDim2.new(0, 20, 1, 0), 11
			p.Name.Position, p.Name.Size, p.Name.TextSize = UDim2.fromOffset(28, 0), UDim2.new(1, -30, 1, 0), 13
		end
		divider.Position, divider.Size = UDim2.fromOffset(pad, pad + 36), UDim2.new(1, -pad * 2, 0, 1)
		contentX, contentY = pad, pad + 44
	else
		-- A computer: GUIDE and FIELD MANUAL over the pages down the left.
		local railW = 214
		heading.TextSize = 24
		heading.Position, heading.Size = UDim2.fromOffset(pad + 4, pad + 2), UDim2.fromOffset(railW, 32)
		manual.Visible = true
		manual.Position, manual.Size = UDim2.fromOffset(pad + 6, pad + 34), UDim2.fromOffset(railW, 16)
		pages.Position = UDim2.fromOffset(pad, pad + 66)
		pages.Size = UDim2.new(0, railW, 1, -pad * 2 - 66)
		pages.ScrollingDirection = Enum.ScrollingDirection.Y
		pages.AutomaticCanvasSize = Enum.AutomaticSize.Y
		pagesList.FillDirection = Enum.FillDirection.Vertical
		pagesList.VerticalAlignment = Enum.VerticalAlignment.Top
		for _, p in pageButtons do
			p.Button.Size = UDim2.new(1, 0, 0, 38)
			p.Wash.Rotation = 0
			p.Edge.Position, p.Edge.Size = UDim2.new(), UDim2.new(0, 2, 1, 0)
			p.Mark.Position, p.Mark.Size = UDim2.new(), UDim2.new(0, 3, 1, 0)
			p.MarkGlow.Position, p.MarkGlow.Size = UDim2.new(), UDim2.new(0, 8, 1, 0)
			p.Number.Position, p.Number.Size, p.Number.TextSize = UDim2.fromOffset(14, 0), UDim2.new(0, 26, 1, 0), 13
			p.Name.Position, p.Name.Size, p.Name.TextSize = UDim2.fromOffset(44, 0), UDim2.new(1, -48, 1, 0), 15
		end
		divider.Position, divider.Size = UDim2.fromOffset(pad + railW + 16, pad), UDim2.new(0, 1, 1, -pad * 2)
		contentX, contentY = pad + railW + 34, pad + 2
	end
	-- The page: SECTION, its name and the count, its line, the rule, the entries.
	local right = pad + (if short then 0 else closeSize + 10)
	sectionTag.Visible = not short
	sectionTag.Position, sectionTag.Size = UDim2.fromOffset(contentX, contentY), UDim2.new(0, 160, 0, 16)
	local titleY = contentY + (if short then 0 else 16)
	title.TextSize = if short then 20 else 28
	title.Position = UDim2.fromOffset(contentX, titleY)
	title.Size = UDim2.new(1, -contentX - right - 70, 0, if short then 24 else 32)
	pageCount.Visible = not short
	pageCount.Position = UDim2.new(1, -right - 64, 0, titleY)
	pageCount.Size = UDim2.fromOffset(60, 32)
	local blurbY = titleY + (if short then 24 else 34)
	blurb.TextSize = if short then 13 else 15
	blurb.Position, blurb.Size = UDim2.fromOffset(contentX, blurbY), UDim2.new(1, -contentX - pad, 0, 20)
	local ruleY = blurbY + (if short then 24 else 30)
	rule.Position, rule.Size = UDim2.fromOffset(contentX + 4, ruleY), UDim2.new(1, -contentX - pad - 4, 0, 1)
	local tipsY = ruleY + (if short then 10 else 14)
	tips.Position = UDim2.fromOffset(contentX, tipsY)
	tips.Size = UDim2.new(1, -contentX - pad + 6, 1, -tipsY - pad - footH - 18)
	local listW = width - contentX - pad
	columns = if listW >= 520 then 2 else 1
	cellW = math.floor((listW - 14 * (columns - 1)) / columns) - 6
	grid.CellPadding = UDim2.fromOffset(14, if short then 6 else 8)
	-- Bottom row, over its hairline: OPEN TASKS at the left, PREV / page / NEXT at the right.
	local footY = -pad - footH
	footRule.Position, footRule.Size = UDim2.new(0, contentX, 1, footY - 10), UDim2.new(1, -contentX - pad, 0, 1)
	tasksButton.Position = UDim2.new(0, contentX, 1, footY)
	tasksButton.Size = UDim2.fromOffset(math.ceil(textWidth("OPEN TASKS", 16, HEAD)) + 34, footH)
	local buttonW = if short then 96 else 120
	nextButton.Position = UDim2.new(1, -pad - buttonW, 1, footY)
	nextButton.Size = UDim2.fromOffset(buttonW, footH)
	footCount.Position = UDim2.new(1, -pad - buttonW - 66, 1, footY)
	footCount.Size = UDim2.fromOffset(62, footH)
	prev.Position = UDim2.new(1, -pad - buttonW * 2 - 74, 1, footY)
	prev.Size = UDim2.fromOffset(buttonW, footH)
end

-- The words and entries, for the page we're on.
render = function()
	local section = GameGuide.Sections[current]
	if not section then
		return
	end
	sectionTag.Text = "SECTION " .. two(current)
	title.Text = section.Title
	blurb.Text = section.Blurb
	local count = two(current) .. " / " .. two(#GameGuide.Sections)
	pageCount.Text, footCount.Text = count, count
	for _, child in tips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local listed = {}
	for _, tip in section.Tips do
		if phone and tip.Phone == false then
			continue -- (a computer's key with nothing like it on a phone)
		end
		table.insert(listed, tip)
	end
	local column = 0
	for _, tip in listed do
		column = math.max(column, capWidth(keyOf(tip)))
	end
	-- Every entry as tall as the page's longest words need (two lines: 70).
	local tall = 70
	for _, tip in listed do
		local words = textHeight(tip.Text, 14, BODY, cellW - (10 + column + 12) - 10)
		tall = math.max(tall, math.ceil(32 + words + 8))
	end
	grid.CellSize = UDim2.new(1 / columns, -(14 * (columns - 1)) / columns - 6, 0, math.min(tall, 110))
	for i, tip in listed do
		tipCard(i, tip, column)
	end
	for i, p in pageButtons do
		local on = i == current
		p.Button.BackgroundTransparency = if on then 0 else 1
		p.Mark.Visible, p.MarkGlow.Visible = on, on
		p.Edge.Visible = not on
		p.Name.TextColor3 = if on then TEXT else DIM
		p.Number.TextColor3 = if on then PINK else FAINT
	end
	prev.Visible = current > 1
	nextButton.Text = if current < #GameGuide.Sections then "NEXT  ›" else "DONE"
	-- (The page's tab kept in view on a phone.)
	if phone then
		local p = pageButtons[current]
		if p then
			local x = p.Button.AbsolutePosition.X - pages.AbsolutePosition.X + pages.CanvasPosition.X
			pages.CanvasPosition = Vector2.new(math.max(0, x - 40), 0)
		end
	end
end

function GuideUI.open(id: string?)
	if id then
		for i, section in GameGuide.Sections do
			if section.Id == id then
				current = i
			end
		end
	end
	gui.Enabled = true
	if gui.AbsoluteSize ~= laidOut then
		layout()
	end
	render()
	tips.CanvasPosition = Vector2.zero
end

function GuideUI.close()
	gui.Enabled = false
end

function GuideUI.toggle()
	if gui.Enabled then
		GuideUI.close()
	else
		GuideUI.open()
	end
end

close.Activated:Connect(GuideUI.close)
shade.Activated:Connect(GuideUI.close)
prev.Activated:Connect(function()
	current = math.max(1, current - 1)
	render()
	tips.CanvasPosition = Vector2.zero
end)
nextButton.Activated:Connect(function()
	if current >= #GameGuide.Sections then
		GuideUI.close()
		return
	end
	current += 1
	render()
	tips.CanvasPosition = Vector2.zero
end)
-- The step-by-step path: the Tasks window (TrainingRewards.client).
tasksButton.Activated:Connect(function()
	GuideUI.close()
	local tasks = gui.Parent and gui.Parent:FindFirstChild("TrainingRewards")
	local open = tasks and tasks:FindFirstChild("OpenTasks")
	if open and open:IsA("BindableEvent") then
		open:Fire()
	end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if gui.Enabled then
		layout()
		render()
	end
end)
UiKit.onTopbar(function()
	if gui.Enabled then
		layout()
	end
end)

return GuideUI
