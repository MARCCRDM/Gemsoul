--[[
	The GUIDE window: how to play, a page a topic (Shared.GameGuide). It
	opens from the lobby's GUIDE tile (on a computer and on a phone), and
	from a step's GO in the Tasks window, on that step's page.

	On a computer: the pages down the left, the page on the right, its tips
	two to a row, each with the key it's about. On a phone: the pages as a
	row of chips along the top, the same tips under them, the phone's own
	buttons in place of the keys. PREV and NEXT page through it like a
	booklet; OPEN TASKS at the bottom goes to the step-by-step path.

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

local new = IronUi.new
local GOLD = Color3.fromRGB(255, 207, 103)
local TEXT = Color3.fromRGB(240, 246, 255)
local MUTED = Color3.fromRGB(169, 188, 207)
local PANEL = Color3.fromRGB(12, 19, 30)
local RAIL = Color3.fromRGB(16, 25, 38)
local CARD = Color3.fromRGB(21, 32, 46)
local CHIP = Color3.fromRGB(27, 41, 56)
local KEY = Color3.fromRGB(36, 30, 18)
local INK = Color3.fromRGB(15, 23, 34)

GameGuide.closeFor(Config.Features or {})

local GuideUI = {}

local gui = UiKit.gui("TipGuide", 26)
gui.Enabled = false

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextSize = size,
		TextColor3 = color or MUTED,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end
local function stroke(parent: Instance, color: Color3, transparency: number?)
	return new("UIStroke", { Color = color, Thickness = 1, Transparency = transparency or 0 }, parent)
end
-- How wide some words are as the player reads them (maybe in Spanish).
local function textWidth(text: string, size: number, font: Enum.Font): number
	text = Lang.translate(text)
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100))
	end)
	return if ok and typeof(bounds) == "Vector2" then bounds.X else #text * size * 0.7
end

-- The window, over a shade that closes it when tapped.
local shade = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, gui)
local panel = new("TextButton", { -- (a button, so taps inside don't reach the shade)
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, shade)
UiKit.round(panel, 14)
stroke(panel, Color3.fromRGB(94, 132, 162), 0.5)
local scale = new("UIScale", {}, panel)
local topLine = new(
	"Frame",
	{ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 0, 2), BackgroundColor3 = GOLD, BorderSizePixel = 0 },
	panel
)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, topLine)

-- The pages: a rail down the left (computer) or a row of chips (phone).
local rail = new("Frame", { BackgroundColor3 = RAIL, BorderSizePixel = 0 }, panel)
UiKit.round(rail, 12)
local railTitle = label(rail, "GUIDE", 22, GOLD, Enum.Font.GothamBlack)
local railSub = label(rail, "How to play Saga Miners", 11, MUTED)
local pages = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local pagesList = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, pages)

-- The page: its title, its line, its tips.
local title = label(panel, "", 26, TEXT, Enum.Font.GothamBlack)
local blurb = label(panel, "", 13, MUTED)
blurb.TextWrapped = true
local tips = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = GOLD,
}, panel)
local grid =
	new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, CellPadding = UDim2.fromOffset(10, 10) }, tips)

local close = new(
	"TextButton",
	{ AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = CHIP, BorderSizePixel = 0, Text = "" },
	panel
)
IronUi.cross(close, 13, TEXT)
UiKit.round(close, 999)
stroke(close, MUTED, 0.8)

-- Along the bottom: OPEN TASKS, then PREV and NEXT.
local function footButton(text: string, primary: boolean): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if primary then GOLD else CHIP,
		BorderSizePixel = 0,
		Text = text,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = if primary then INK else TEXT,
		AutoButtonColor = true,
	}, panel)
	UiKit.round(b, 999)
	if not primary then
		stroke(b, Color3.fromRGB(60, 84, 104), 0.3)
	end
	IronUi.juice(b, 1.03, 0.97)
	return b
end
local tasksButton = footButton("OPEN TASKS", false)
local prev = footButton("‹  PREV", false)
local nextButton = footButton("NEXT  ›", true)
local pageCount = label(panel, "", 12, MUTED, Enum.Font.GothamBold)
pageCount.TextXAlignment = Enum.TextXAlignment.Center

local current = 1
local phone = false
local pageButtons = {}
local render -- (below)

for i, section in GameGuide.Sections do
	local b = new("TextButton", {
		BackgroundColor3 = CHIP,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = i,
		AutoButtonColor = false,
	}, pages)
	UiKit.round(b, 10)
	local number = label(b, tostring(i), 12, GOLD, Enum.Font.GothamBlack)
	number.Name = "Number"
	number.TextXAlignment = Enum.TextXAlignment.Center
	number.BackgroundTransparency, number.BackgroundColor3 = 0, KEY
	UiKit.round(number, 999)
	local name = label(b, section.Title, 13, TEXT, Enum.Font.GothamBold)
	name.Name = "Name"
	name.TextTruncate = Enum.TextTruncate.AtEnd
	b.Activated:Connect(function()
		current = i
		render()
		tips.CanvasPosition = Vector2.zero
	end)
	pageButtons[i] = b
end

-- One tip: its key (or a number), its title and its words.
local function tipCard(i: number, tip)
	local card = new("Frame", { BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i }, tips)
	UiKit.round(card, 12)
	stroke(card, Color3.fromRGB(52, 72, 92), 0.45)
	local keyText = if phone then tip.Phone else tip.Key
	if keyText == nil and tip.Key ~= nil and phone then
		keyText = tip.Key
	end
	local badgeW = if keyText then math.max(46, textWidth(keyText, 13, Enum.Font.GothamBlack) + 22) else 40
	local badge = new("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(badgeW, if keyText then 34 else 40),
		BackgroundColor3 = KEY,
		BorderSizePixel = 0,
	}, card)
	UiKit.round(badge, if keyText then 8 else 999)
	stroke(badge, GOLD, 0.35)
	-- (A key cap: a lighter lip along its bottom.)
	if keyText then
		new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 3, 1, -2),
			Size = UDim2.new(1, -6, 0, 3),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
		}, badge)
	end
	local cap = label(badge, keyText or tostring(i), if keyText then 13 else 16, GOLD, Enum.Font.GothamBlack)
	cap.Size, cap.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	if keyText and not phone then
		cap:SetAttribute("NoTranslate", true) -- (a key's name; a phone's button names are words)
	end
	local left = 14 + badgeW + 12
	local head = label(card, tip.Title, 15, TEXT, Enum.Font.GothamBold)
	head.Position, head.Size = UDim2.fromOffset(left, 12), UDim2.new(1, -left - 12, 0, 20)
	head.TextTruncate = Enum.TextTruncate.AtEnd
	local words = label(card, tip.Text, 12, MUTED)
	words.TextWrapped, words.TextYAlignment = true, Enum.TextYAlignment.Top
	words.Position, words.Size = UDim2.fromOffset(left, 36), UDim2.new(1, -left - 12, 1, -42)
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
	local width = math.min(if short then 900 else 920, screen.X - (if short then 20 else 60))
	local height = math.min(if short then 620 else 600, screen.Y - (if short then 16 else 60))
	panel.Size = UDim2.fromOffset(width, height)
	local room, at = UiKit.clearTopbar(screen, Vector2.new(width, height))
	scale.Scale, panel.Position = room, at
	local pad = if short then 12 else 18
	local closeSize = if short then 34 else 40
	close.Size = UDim2.fromOffset(closeSize, closeSize)
	close.Position = UDim2.new(1, -pad + 4, 0, pad - 4)
	local footH = if short then 34 else 40
	local contentX, contentY
	if short then
		-- A phone: the pages a row of chips along the top, after GUIDE.
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad, pad), UDim2.fromOffset(92, 36)
		railTitle.Position, railTitle.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -12, 1, 0)
		railTitle.TextSize = 18
		railSub.Visible = false
		pages.Position = UDim2.fromOffset(pad + 100, pad)
		pages.Size = UDim2.new(1, -pad * 2 - 100 - closeSize - 8, 0, 36)
		pages.ScrollingDirection = Enum.ScrollingDirection.X
		pages.AutomaticCanvasSize = Enum.AutomaticSize.X
		pagesList.FillDirection = Enum.FillDirection.Horizontal
		pagesList.VerticalAlignment = Enum.VerticalAlignment.Center
		for i, b in pageButtons do
			local name = b:FindFirstChild("Name") :: TextLabel
			local number = b:FindFirstChild("Number") :: TextLabel
			local w = math.ceil(textWidth(GameGuide.Sections[i].Title, 12, Enum.Font.GothamBold)) + 44
			b.Size = UDim2.fromOffset(w, 32)
			number.Position, number.Size = UDim2.fromOffset(6, 6), UDim2.fromOffset(20, 20)
			number.TextSize = 11
			name.Position, name.Size = UDim2.fromOffset(32, 0), UDim2.new(1, -36, 1, 0)
			name.TextSize = 12
		end
		contentX, contentY = pad, pad + 44
	else
		-- A computer: the pages down a rail on the left.
		local railW = 220
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad, pad), UDim2.new(0, railW, 1, -pad * 2)
		railTitle.Position, railTitle.Size = UDim2.fromOffset(16, 12), UDim2.new(1, -24, 0, 30)
		railTitle.TextSize = 24
		railSub.Visible = true
		railSub.Position, railSub.Size = UDim2.fromOffset(16, 42), UDim2.new(1, -24, 0, 16)
		pages.Position = UDim2.fromOffset(pad + 8, pad + 70)
		pages.Size = UDim2.new(0, railW - 16, 1, -pad * 2 - 80)
		pages.ScrollingDirection = Enum.ScrollingDirection.Y
		pages.AutomaticCanvasSize = Enum.AutomaticSize.Y
		pagesList.FillDirection = Enum.FillDirection.Vertical
		pagesList.VerticalAlignment = Enum.VerticalAlignment.Top
		for _, b in pageButtons do
			local name = b:FindFirstChild("Name") :: TextLabel
			local number = b:FindFirstChild("Number") :: TextLabel
			b.Size = UDim2.new(1, 0, 0, 40)
			number.Position, number.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(24, 24)
			number.TextSize = 12
			name.Position, name.Size = UDim2.fromOffset(42, 0), UDim2.new(1, -48, 1, 0)
			name.TextSize = 13
		end
		contentX, contentY = pad + railW + 18, pad + 4
	end
	-- The page: title and line, then the tips, then the bottom row.
	title.TextSize = if short then 20 else 28
	title.Position = UDim2.fromOffset(contentX, contentY)
	title.Size = UDim2.new(1, -contentX - pad - (if short then 0 else closeSize + 8), 0, if short then 24 else 34)
	blurb.TextSize = if short then 12 else 13
	blurb.Position = UDim2.fromOffset(contentX, contentY + (if short then 24 else 36))
	blurb.Size = UDim2.new(1, -contentX - pad, 0, 18)
	local tipsY = contentY + (if short then 48 else 64)
	tips.Position = UDim2.fromOffset(contentX, tipsY)
	tips.Size = UDim2.new(1, -contentX - pad + 6, 1, -tipsY - pad - footH - 10)
	local listW = width - contentX - pad
	local columns = if listW >= 520 then 2 else 1
	grid.CellSize = UDim2.new(1 / columns, -(10 * (columns - 1)) / columns - 6, 0, if short then 86 else 96)
	-- Bottom row: OPEN TASKS at the left, PREV / page / NEXT at the right.
	local footY = UDim2.new(0, 0, 1, -pad - footH)
	tasksButton.Position = UDim2.new(0, contentX, 1, -pad - footH)
	tasksButton.Size = UDim2.fromOffset(math.ceil(textWidth("OPEN TASKS", 13, Enum.Font.GothamBold)) + 34, footH)
	local buttonW = if short then 96 else 116
	nextButton.Position = UDim2.new(1, -pad - buttonW, footY.Y.Scale, footY.Y.Offset)
	nextButton.Size = UDim2.fromOffset(buttonW, footH)
	pageCount.Position = UDim2.new(1, -pad - buttonW - 64, footY.Y.Scale, footY.Y.Offset)
	pageCount.Size = UDim2.fromOffset(60, footH)
	prev.Position = UDim2.new(1, -pad - buttonW * 2 - 72, footY.Y.Scale, footY.Y.Offset)
	prev.Size = UDim2.fromOffset(buttonW, footH)
end

-- The words and cards, for the page we're on.
render = function()
	local section = GameGuide.Sections[current]
	if not section then
		return
	end
	title.Text = section.Title
	blurb.Text = section.Blurb
	for _, child in tips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, tip in section.Tips do
		if phone and tip.Phone == false then
			continue -- (a computer's key with nothing like it on a phone)
		end
		shown += 1
		tipCard(shown, tip)
	end
	for i, b in pageButtons do
		local on = i == current
		b.BackgroundTransparency = if on then 0 else (if phone then 0 else 1)
		b.BackgroundColor3 = if on then GOLD else CHIP
		local name = b:FindFirstChild("Name") :: TextLabel
		local number = b:FindFirstChild("Number") :: TextLabel
		name.TextColor3 = if on then INK else TEXT
		number.BackgroundColor3 = if on then INK else KEY
	end
	pageCount.Text = string.format("%d / %d", current, #GameGuide.Sections)
	prev.Visible = current > 1
	nextButton.Text = if current < #GameGuide.Sections then "NEXT  ›" else "DONE"
	-- (The page's chip kept in view on a phone.)
	if phone then
		local b = pageButtons[current]
		if b then
			local x = b.AbsolutePosition.X - pages.AbsolutePosition.X + pages.CanvasPosition.X
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
