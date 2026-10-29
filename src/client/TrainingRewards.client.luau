--[[
	Tasks: the learning path (Shared.TrainingRewards): chapters of steps that
	teach the game, each paying coins once, and today's three challenges
	(Shared.DailyChallenges). What's done and what's paid is the server's;
	this window only shows it.

	It wears the game's window look (the Store's, Client GiltUi): a navy
	sheen with an amber bar along the top, the amber diamond and title,
	recessed wells, cards fading down, glossy amber for the button that
	matters. The chapters down the left in a well (on a phone a row of tabs
	along the top, the picked one underlined in amber), TODAY first; the
	chapter's own page on the right, its NEXT STEP up top with a GO button that takes
	you where the step happens (out to the rocks, the Inventory, the PLAY
	menu, the Market, or the GUIDE's page on it), then every step of the
	chapter in order, numbered, ticked off as they're done. It opens on the
	first chapter with steps left.

	It opens from the lobby menu's TASKS tile (LobbyUI fires its OpenTasks
	event) and the GUIDE's OPEN TASKS: nothing of it sits on the play screen.
	Layout runs only when the screen changes size or the window opens; words
	and bars only when the profile changes.

	ScreenGui "TrainingRewards", with the BlocksMiningHud attribute while open
	(OutpostScene and VehicleDrive step aside for it), and Open: how many
	steps and today's challenges are still to do (the menu tile's badge).
]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Config = require(RS.Shared.Config)
local Daily = require(RS.Shared.DailyChallenges)
local Lang = require(RS.Shared.Lang)
local Rules = require(RS.Shared.TrainingRewards)
local Tutorial = require(RS.Shared.Tutorial)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local player = Players.LocalPlayer

-- The game's window colours (the Store's: Client ShopUI, GiltUi).
local WINDOW = Color3.fromRGB(26, 33, 54)
local WINDOW_MID = Color3.fromRGB(15, 20, 33)
local WINDOW_LOW = Color3.fromRGB(7, 10, 18)
local SURFACE = Color3.fromRGB(22, 29, 47)
local SURFACE_LOW = Color3.fromRGB(13, 17, 30)
local RAISED = Color3.fromRGB(36, 46, 72)
local WELL = Color3.fromRGB(11, 15, 27)
local STEEL = Color3.fromRGB(62, 76, 108)
local TEXT = Color3.fromRGB(240, 243, 250)
local DIM = Color3.fromRGB(152, 164, 190)
local FAINT = Color3.fromRGB(100, 112, 140)
local GOLD = Color3.fromRGB(255, 196, 64)
local BUY_TEXT = Color3.fromRGB(34, 18, 2)
local GOOD = Color3.fromRGB(96, 226, 150)
local BLACK, BOLD, MEDIUM = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium
-- Glossy amber (the Store's buy button), at rest and under the mouse.
local AMBER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 222, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 184, 52)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 130, 24)),
})
local AMBER_LIT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 202, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(252, 148, 36)),
})
-- What each chapter is called on screen (TODAY: the day's challenges).
local CHAPTER_NAMES = {
	Today = "TODAY",
	Basics = "BASICS",
	Gear = "GEAR",
	Fight = "FIGHT",
	Kaiju = "KAIJU",
	Explore = "EXPLORE",
	PvP = "1V1",
	PvE = "DUNGEONS",
	Market = "MARKET",
	Discoveries = "DISCOVERIES",
}

-- Steps for switched-off activities sit out (Config.Features).
Rules.closeFor(Config.Features or {})
local chapters = {} -- { Id, Steps = { objective } }
for _, page in Rules.Pages do
	if Rules.Closed[page] then
		continue
	end
	local steps = {}
	for _, o in Rules.Objectives do
		if Rules.pageOf(o) == page and Rules.listed(o) then
			table.insert(steps, o)
		end
	end
	if #steps > 0 then
		table.insert(chapters, { Id = page, Steps = steps })
	end
end
local objectives = {}
for _, c in chapters do
	for _, o in c.Steps do
		table.insert(objectives, o)
	end
end

local function new(kind: string, props, parent: Instance?)
	local o = Instance.new(kind)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or DIM,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
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
-- A bar in a recessed track.
local function bar(parent: Instance, color: Color3)
	local back = new("Frame", { BackgroundColor3 = WELL }, parent)
	UiKit.round(back, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, back)
	UiKit.round(fill, 3)
	return back, fill
end
-- A card's face: navy fading down, a steel hairline (the Store's cards).
local function face(card: GuiObject, tint: Color3?, amount: number?, edge: Color3?, edgeAlpha: number?): UIStroke
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(SURFACE:Lerp(tint or SURFACE, amount or 0), SURFACE_LOW),
	}, card)
	return stroke(card, edge or STEEL, edgeAlpha or 0.45)
end
-- A short bar of colour along a card's top edge, brightest in its middle.
local function topBar(card: GuiObject, tint: Color3, inset: number, thick: number?): Frame
	local b = new("Frame", {
		Name = "TopBar",
		BackgroundColor3 = tint,
		Position = UDim2.fromOffset(inset, 0),
		Size = UDim2.new(1, -inset * 2, 0, thick or 2),
	}, card)
	UiKit.round(b, 2)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, b)
	return b
end
-- How wide some words are as the player reads them, maybe in Spanish
-- (Roblox's own measure; a fair guess without it).
local function textWidth(text: string, size: number, font: Enum.Font): number
	text = Lang.translate(text)
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(1000, 100))
	end)
	return if ok and typeof(bounds) == "Vector2" then bounds.X else #text * size * 0.7
end
-- A tick drawn from two bars (Gotham's check mark shows as a box in game).
local function tick(parent: GuiObject, color: Color3): { Frame }
	local short = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.56),
		Size = UDim2.new(0.3, 0, 0, 2),
		Rotation = 45,
		BackgroundColor3 = color,
		Visible = false,
	}, parent)
	local long = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.47),
		Size = UDim2.new(0.5, 0, 0, 2),
		Rotation = -50,
		BackgroundColor3 = color,
		Visible = false,
	}, parent)
	return { short, long }
end

local gui = new("ScreenGui", {
	Name = "TrainingRewards",
	ResetOnSpawn = false,
	DisplayOrder = 25,
	Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

-- The window, over a dark shade that closes it when tapped.
local shade = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.25,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
}, gui)
shade:GetPropertyChangedSignal("Visible"):Connect(function()
	gui:SetAttribute("BlocksMiningHud", shade.Visible)
end)
local panel = new("TextButton", { -- (a button, so taps inside don't reach the shade)
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "",
	AutoButtonColor = false,
}, shade)
UiKit.round(panel, 16)
stroke(panel, STEEL, 0, 1.5)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WINDOW),
		ColorSequenceKeypoint.new(0.3, WINDOW_MID),
		ColorSequenceKeypoint.new(1, WINDOW_LOW),
	}),
}, panel)
topBar(panel, GOLD, 24, 3)

-- The header: the amber diamond and TASKS (lit from above), how many steps
-- are done under it with the path's bar, a steel rule, the close.
local mark = new("Frame", { BackgroundColor3 = GOLD, Rotation = 45, Size = UDim2.fromOffset(10, 10) }, panel)
UiKit.round(mark, 2)
local heading = label(panel, "TASKS", 22, Color3.new(1, 1, 1), BLACK)
heading.TextTruncate = Enum.TextTruncate.None
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(255, 232, 150), Color3.fromRGB(255, 172, 44)),
}, heading)
local count = label(panel, "", 10, FAINT, BOLD)
count:SetAttribute("NoTranslate", true) -- (Lang.format puts it in Spanish)
local overallBack, overallFill = bar(panel, GOLD)
local headerRule = new("Frame", { BackgroundColor3 = STEEL, BackgroundTransparency = 0.35 }, panel)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = SURFACE,
	Text = "",
	AutoButtonColor = false,
}, panel)
UiKit.round(close, 18)
stroke(close, STEEL, 0.2)
local closeBars = IronUi.cross(close, 14, DIM)
close:SetAttribute("UiSound", "Back")
close.MouseEnter:Connect(function()
	for _, b in closeBars do
		b.BackgroundColor3 = TEXT
	end
end)
close.MouseLeave:Connect(function()
	for _, b in closeBars do
		b.BackgroundColor3 = DIM
	end
end)

-- The chapters: down the left in a recessed well, or a row of tabs on a phone.
local chapter = "Basics"
local refresh, list -- (below)
local rail = new("Frame", { BackgroundColor3 = WELL }, panel)
UiKit.round(rail, 12)
stroke(rail, STEEL, 0.25)
local railList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local railLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, railList)
local chapterButtons = {}
local function chapterButton(id: string, order: number)
	local b = new("TextButton", {
		BackgroundColor3 = RAISED,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = false,
	}, railList)
	UiKit.round(b, 8)
	b:SetAttribute("UiSound", "Tab")
	-- Picked: an amber edge at its left (rail) or under it (tab).
	local mark = new("Frame", { BackgroundColor3 = GOLD, Visible = false }, b)
	UiKit.round(mark, 2)
	-- Done: a green tick where the count was.
	local tickBox = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1 }, b)
	local ticks = tick(tickBox, GOOD)
	local name = label(b, CHAPTER_NAMES[id] or string.upper(id), 14, DIM, BOLD)
	local progress = label(b, "", 12, FAINT, BOLD)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress:SetAttribute("NoTranslate", true)
	b.MouseEnter:Connect(function()
		name.TextColor3 = TEXT
	end)
	b.MouseLeave:Connect(function()
		name.TextColor3 = if id == chapter then TEXT else DIM
	end)
	b.Activated:Connect(function()
		chapter = id
		refresh()
		list.CanvasPosition = Vector2.zero
	end)
	chapterButtons[id] = { Button = b, Mark = mark, TickBox = tickBox, Ticks = ticks, Name = name, Progress = progress }
end
chapterButton("Today", 0)
for i, c in chapters do
	chapterButton(c.Id, i)
end

-- The chapter's page: its name, its line, how far along it is.
local chapterTitle = label(panel, "", 20, TEXT, BLACK)
local chapterBlurb = label(panel, "", 12, DIM)
local chapterCount = label(panel, "", 12, FAINT, BOLD)
chapterCount.TextXAlignment = Enum.TextXAlignment.Right
chapterCount:SetAttribute("NoTranslate", true)

-- NEXT STEP: the one to do now, on a card warmed with amber (an amber bar
-- along its top): its name, how, its bar; the coins and a glossy GO.
local hero = new("Frame", {}, panel)
UiKit.round(hero, 12)
face(hero, GOLD, 0.14, GOLD, 0.55)
topBar(hero, GOLD, 18, 2)
local heroTag = label(hero, "NEXT STEP", 11, GOLD, BLACK)
local heroTitle = label(hero, "", 18, TEXT, BLACK)
local heroHint = label(hero, "", 12, DIM)
heroHint.TextWrapped, heroHint.TextYAlignment, heroHint.TextTruncate =
	true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
local heroBack, heroFill = bar(hero, GOLD)
local heroCount = label(hero, "", 11, DIM, BOLD)
heroCount:SetAttribute("NoTranslate", true)
local heroReward = label(hero, "", 24, GOLD, BLACK)
heroReward.TextXAlignment = Enum.TextXAlignment.Right
heroReward:SetAttribute("NoTranslate", true)
local heroUnit = label(hero, "COINS", 9, FAINT, BOLD)
heroUnit.TextXAlignment = Enum.TextXAlignment.Right
-- GO: the Store's buy button (amber over white, dark words, a shine on top).
local go = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "GO",
	TextSize = 16,
	Font = BLACK,
	TextColor3 = BUY_TEXT,
	AutoButtonColor = false,
}, hero)
UiKit.round(go, 10)
local goShade = new("UIGradient", { Rotation = 90, Color = AMBER }, go)
stroke(go, Color3.fromRGB(255, 236, 170), 0.4, 1.5)
new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.45,
	Position = UDim2.fromOffset(8, 1),
	Size = UDim2.new(1, -16, 0, 1),
}, go)
go:SetAttribute("UiSound", "Confirm")
go.MouseEnter:Connect(function()
	goShade.Color = AMBER_LIT
end)
go.MouseLeave:Connect(function()
	goShade.Color = AMBER
end)
IronUi.juice(go, 1.04, 0.96)
local heroStep -- (the step the card shows)
-- The step's bar and count (a one-off step has nothing to count).
local function setProgress(progress: number, goal: number)
	local counted = goal > 1
	heroBack.Visible, heroCount.Visible = counted, counted
	heroFill.Size = UDim2.fromScale(progress / math.max(1, goal), 1)
end

-- The steps.
list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = STEEL,
}, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, list)
local allDone = label(panel, "Chapter complete! Every step here is done and paid.", 13, GOOD, BOLD)
allDone.TextXAlignment = Enum.TextXAlignment.Center

local rows = {}
local function makeRow(id: string, chapterId: string, index: number, name: string, hint: string, coins: number)
	-- A card: its number in a round well, its name and how, the coins at
	-- the right.
	local row = new("Frame", { LayoutOrder = index, Visible = false }, list)
	UiKit.round(row, 10)
	local outline = face(row)
	local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = WELL }, row)
	UiKit.round(mark, 999)
	local markRim = stroke(mark, STEEL, 0.2)
	local number = label(mark, tostring(index), 12, DIM, BLACK)
	number.Size, number.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	number:SetAttribute("NoTranslate", true)
	local ticks = tick(mark, GOOD)
	local title = label(row, name, 14, TEXT, BOLD)
	local words = label(row, hint, 11, DIM)
	local status = label(row, "", 11, DIM, BOLD)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status:SetAttribute("NoTranslate", true)
	local reward = label(row, "+" .. coins, 16, GOLD, BLACK)
	reward:SetAttribute("Coins", "+" .. coins)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward:SetAttribute("NoTranslate", true)
	local unit = label(row, "COINS", 9, FAINT, BOLD)
	unit.TextXAlignment = Enum.TextXAlignment.Right
	rows[id] = {
		Chapter = chapterId,
		Frame = row,
		Outline = outline,
		Mark = mark,
		MarkRim = markRim,
		Number = number,
		Ticks = ticks,
		Title = title,
		Hint = words,
		Status = status,
		Reward = reward,
		Unit = unit,
	}
end
for _, c in chapters do
	for i, o in c.Steps do
		makeRow(o.Id, c.Id, i, o.Name, o.Hint, o.Coins)
	end
end
-- Today's three challenges and their bonus (their words come with the day's
-- challenges).
for i = 1, 3 do
	makeRow("Daily" .. i, "Today", i, "", "", 0)
end
makeRow("DailyBonus", "Today", 4, "All three today", "Finish today's three challenges for a bonus.", Daily.Bonus)

-- Where everything goes, for this screen.
local laidOut = Vector2.zero
local phone = false
local content = { X = 0, Y = 0, W = 0, HeroY = 0, HeroH = 0, Bottom = 0 }
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	laidOut = screen
	phone = UiKit.handheld(screen) or screen.Y < 500
	local width = math.max(300, math.min(if phone then 900 else 880, screen.X - (if phone then 20 else 48)))
	local height = math.max(260, math.min(if phone then 640 else 620, screen.Y - (if phone then 12 else 48)))
	panel.Size = UDim2.fromOffset(width, height)
	local pad = if phone then 14 else 22

	-- Header (as the Store's): the diamond, TASKS, how many done and the
	-- path's bar under it; the close at the right; a steel rule under it all.
	local head = if phone then 50 else 64
	mark.Position = UDim2.fromOffset(pad + 4, if phone then 16 else 22)
	heading.TextSize = if phone then 18 else 22
	local headingX = pad + 22
	local headingW = textWidth("TASKS", heading.TextSize, heading.Font) + 8
	heading.Position, heading.Size = UDim2.fromOffset(headingX, if phone then 8 else 12), UDim2.fromOffset(headingW, 26)
	count.Position, count.Size = UDim2.fromOffset(headingX, if phone then 32 else 38), UDim2.fromOffset(110, 12)
	overallBack.Position = UDim2.fromOffset(headingX + 112, if phone then 35 else 41)
	overallBack.Size = UDim2.fromOffset(if phone then 90 else 140, 5)
	headerRule.Position, headerRule.Size = UDim2.fromOffset(0, head), UDim2.new(1, 0, 0, 1)
	close.Size = UDim2.fromOffset(36, 36)
	close.Position = UDim2.new(1, -pad, 0, (head - 36) / 2)

	-- The chapters: a well down the left (computer) or a row of tabs (phone).
	local contentX, contentY
	if phone then
		rail.Visible = false
		railList.Position, railList.Size = UDim2.fromOffset(pad, head + 6), UDim2.new(1, -pad * 2, 0, 36)
		railList.ScrollingDirection = Enum.ScrollingDirection.X
		railList.AutomaticCanvasSize = Enum.AutomaticSize.X
		railLayout.FillDirection = Enum.FillDirection.Horizontal
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		railLayout.Padding = UDim.new(0, 18)
		for id, c in chapterButtons do
			-- (The count right after its own name, so it never reads as the
			-- next tab's.)
			local nameW = math.ceil(textWidth(CHAPTER_NAMES[id] or id, 13, BOLD))
			c.Button.Size = UDim2.fromOffset(nameW + 32, 34)
			c.Name.TextSize = 13
			c.Name.Position, c.Name.Size = UDim2.fromOffset(0, 0), UDim2.new(0, nameW + 4, 1, -4)
			c.Progress.TextSize = 10
			c.Progress.TextXAlignment = Enum.TextXAlignment.Left
			c.Progress.Position, c.Progress.Size = UDim2.fromOffset(nameW + 6, 1), UDim2.new(0, 26, 1, -4)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(0, nameW + 22, 0.5, -2), UDim2.fromOffset(16, 16)
			-- Picked: an amber underline.
			c.Mark.Position, c.Mark.Size = UDim2.new(0, 0, 1, -3), UDim2.new(0, nameW, 0, 3)
		end
		contentX, contentY = pad, head + 50
	else
		local railW = 190
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad, head + 16), UDim2.new(0, railW, 1, -head - 16 - pad)
		railList.Position = UDim2.fromOffset(pad + 8, head + 24)
		railList.Size = UDim2.new(0, railW - 16, 1, -head - 32 - pad)
		railList.ScrollingDirection = Enum.ScrollingDirection.Y
		railList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		railLayout.FillDirection = Enum.FillDirection.Vertical
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		railLayout.Padding = UDim.new(0, 4)
		for id, c in chapterButtons do
			-- (TODAY sits a little apart from the chapters.)
			c.Button.Size = UDim2.new(1, 0, 0, if id == "Today" then 46 else 38)
			c.Name.TextSize = 14
			c.Name.Position, c.Name.Size = UDim2.fromOffset(16, 0), UDim2.new(1, -64, 0, 38)
			c.Progress.TextSize = 12
			c.Progress.TextXAlignment = Enum.TextXAlignment.Right
			c.Progress.Position, c.Progress.Size = UDim2.new(1, -50, 0, 0), UDim2.fromOffset(40, 38)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(1, -10, 0, 19), UDim2.fromOffset(18, 18)
			-- Picked: an amber edge at the left.
			c.Mark.Position, c.Mark.Size = UDim2.fromOffset(4, 9), UDim2.fromOffset(4, 20)
		end
		contentX, contentY = pad + railW + 18, head + 16
	end
	local contentW = width - contentX - pad

	-- The chapter's name and line, its count at the right.
	chapterTitle.TextSize = if phone then 16 else 20
	local titleH = if phone then 20 else 26
	chapterTitle.Position = UDim2.fromOffset(contentX, contentY)
	chapterTitle.Size = UDim2.fromOffset(contentW - 90, titleH)
	chapterCount.Position = UDim2.fromOffset(contentX + contentW - 90, contentY)
	chapterCount.Size = UDim2.fromOffset(90, titleH)
	chapterBlurb.Position = UDim2.fromOffset(contentX, contentY + titleH)
	chapterBlurb.Size = UDim2.fromOffset(contentW, 16)
	local heroY = contentY + titleH + (if phone then 22 else 26)

	-- NEXT STEP: tag and name, the how under them, then its bar; the coins
	-- and GO at the right.
	local heroH = if phone then 100 else 120
	hero.Position, hero.Size = UDim2.fromOffset(contentX, heroY), UDim2.fromOffset(contentW, heroH)
	local goW, goH = if phone then 84 else 108, if phone then 36 else 42
	go.Size, go.Position = UDim2.fromOffset(goW, goH), UDim2.new(1, -14, 1, -14)
	go.TextSize = if phone then 15 else 17
	local left = if phone then 14 else 18
	local textW = contentW - goW - left - 30
	heroTag.Position, heroTag.Size = UDim2.fromOffset(left, if phone then 10 else 14), UDim2.fromOffset(textW, 14)
	heroTitle.TextSize = if phone then 16 else 18
	heroTitle.Position, heroTitle.Size = UDim2.fromOffset(left, if phone then 25 else 30), UDim2.fromOffset(textW, 22)
	heroHint.TextSize = if phone then 11 else 12
	heroHint.Position, heroHint.Size = UDim2.fromOffset(left, if phone then 48 else 56), UDim2.fromOffset(textW, 30)
	local barW = math.max(40, math.min(240, textW - 60))
	heroBack.Position, heroBack.Size = UDim2.new(0, left, 1, if phone then -16 else -20), UDim2.fromOffset(barW, 6)
	heroCount.Position, heroCount.Size = UDim2.new(0, left + barW + 10, 1, if phone then -21 else -25), UDim2.fromOffset(60, 16)
	heroReward.TextSize = if phone then 20 else 24
	heroReward.Position, heroReward.Size = UDim2.new(1, -14 - 160, 0, if phone then 8 else 12), UDim2.fromOffset(160, 26)
	heroUnit.Position, heroUnit.Size = UDim2.new(1, -14 - 160, 0, if phone then 33 else 38), UDim2.fromOffset(160, 11)
	allDone.Position, allDone.Size = UDim2.fromOffset(contentX, heroY + 10), UDim2.fromOffset(contentW, 40)
	content = { X = contentX, Y = contentY, W = contentW, HeroY = heroY, HeroH = heroH, Bottom = height - pad }

	-- The steps' cards.
	local rowH = if phone then 54 else 60
	for _, r in rows do
		r.Frame.Size = UDim2.new(1, -8, 0, rowH)
		local markSize = if phone then 26 else 30
		r.Mark.Position, r.Mark.Size = UDim2.new(0, 12, 0.5, 0), UDim2.fromOffset(markSize, markSize)
		local textLeft = 12 + markSize + 12
		r.Title.TextSize = if phone then 13 else 14
		r.Title.Position, r.Title.Size = UDim2.fromOffset(textLeft, if phone then 9 else 11), UDim2.new(1, -textLeft - 150, 0, 18)
		r.Hint.TextSize = if phone then 10 else 11
		r.Hint.Position, r.Hint.Size = UDim2.fromOffset(textLeft, if phone then 28 else 31), UDim2.new(1, -textLeft - 150, 0, 16)
		r.Status.Position, r.Status.Size = UDim2.new(1, -140, 0, 0), UDim2.new(0, 56, 1, 0)
		r.Reward.Position, r.Reward.Size = UDim2.new(1, -80, 0, if phone then 9 else 11), UDim2.fromOffset(66, 20)
		r.Unit.Position, r.Unit.Size = UDim2.new(1, -80, 0, if phone then 29 else 32), UDim2.fromOffset(66, 11)
	end
end

-- The list sits under the gold card when there's one, else just under the
-- chapter's name.
local function placeList(underHero: boolean)
	local y = if underHero then content.HeroY + content.HeroH + 12 else content.HeroY + (if allDone.Visible then 56 else 0)
	list.Position = UDim2.fromOffset(content.X, y)
	list.Size = UDim2.fromOffset(content.W + 6, math.max(40, content.Bottom - y))
end

-- What's still to do: steps not yet paid, and today's challenges not yet done.
local function stillOpen(): number
	local p = GemClient.Profile
	local paid = p and p.TrainingRewards and p.TrainingRewards.Paid or {}
	local done = 0
	for _, o in objectives do
		if paid[o.Id] == true then
			done += 1
		end
	end
	local open = #objectives - done
	local view = p and p.Challenges
	if type(view) == "table" and type(view.List) == "table" then
		for _, item in view.List do
			if item.Done ~= true then
				open += 1
			end
		end
	end
	return open
end

-- How long today's challenges have left.
local function untilReset(): string
	local left = 86400 - os.time() % 86400
	local hours, minutes = left // 3600, (left % 3600) // 60
	return if hours > 0 then string.format("%dh %02dm", hours, minutes) else string.format("%dm", math.max(1, minutes))
end

-- A step's card: done (a green tick, PAID), next (an amber rim, its number
-- on amber) or still to come.
local function paint(r, complete: boolean, isNext: boolean, progress: number, goal: number)
	r.Mark.BackgroundColor3 = if isNext then GOLD else WELL
	r.MarkRim.Color = if complete then GOOD elseif isNext then GOLD else STEEL
	r.MarkRim.Transparency = if complete then 0.4 else 0.2
	r.Number.Visible = not complete
	r.Number.TextColor3 = if isNext then BUY_TEXT else DIM
	for _, t in r.Ticks do
		t.Visible = complete
	end
	r.Outline.Color = if isNext then GOLD else STEEL
	r.Outline.Transparency = if isNext then 0.35 elseif complete then 0.7 else 0.45
	r.Frame.BackgroundTransparency = if complete then 0.35 else 0
	r.Status.Text = if complete or goal <= 1 then "" else progress .. " / " .. goal
	r.Title.TextColor3 = if complete then DIM else TEXT
	r.Hint.TextColor3 = if complete then FAINT else DIM
	r.Reward.Text = if complete then "PAID" else r.Reward:GetAttribute("Coins") or r.Reward.Text
	r.Reward.TextSize = if complete then 13 else 16
	r.Reward.TextColor3 = if complete then GOOD else GOLD
	r.Unit.Visible = not complete
end

-- Where a step's GO takes you (its Go: Shared.TrainingRewards).
local function goTo(where: string?)
	shade.Visible = false
	if type(where) ~= "string" then
		return
	end
	local section = string.match(where, "^Guide:(.+)$")
	if section then
		require(script.Parent.Modules.GuideUI).open(section)
	elseif where == "Inventory" then
		require(script.Parent.Modules.LobbyUI).openDashboard()
	elseif where == "Play" then
		require(script.Parent.Modules.LobbyUI).openPicker()
	elseif where == "Market" then
		require(script.Parent.Modules.MarketBoardUI).open()
	elseif where == "Mine" then
		UiKit.toast(Lang.translate("Find a rock nearby and swing at it."), GOLD)
	end
end
go.Activated:Connect(function()
	if heroStep then
		goTo(heroStep.Go)
	end
end)

-- The words and bars, from the profile.
refresh = function()
	local p = GemClient.Profile
	local state = p and p.TrainingRewards or {}
	local paid, counts = state.Paid or {}, state.Counts or {}
	local done = 0
	for _, o in objectives do
		if paid[o.Id] == true then
			done += 1
		end
	end
	local total = #objectives
	count.Text = Lang.format("{1} / {2} DONE", done, total)
	overallFill.Size = UDim2.fromScale(if total > 0 then done / total else 0, 1)

	-- The chapters: their counts, a quiet tick once they're done.
	for _, c in chapters do
		local finished = 0
		for _, o in c.Steps do
			if paid[o.Id] == true then
				finished += 1
			end
		end
		local b = chapterButtons[c.Id]
		local complete = finished == #c.Steps
		b.Progress.Text = finished .. "/" .. #c.Steps
		b.Progress.Visible = not complete
		for _, t in b.Ticks do
			t.Visible = complete
		end
		b.Name:SetAttribute("Complete", complete)
	end
	local view = p and p.Challenges
	local today = if type(view) == "table" and type(view.List) == "table" then view.List else {}
	local todayDone = 0
	for _, item in today do
		if item.Done == true then
			todayDone += 1
		end
	end
	local todayButton = chapterButtons.Today
	local todayComplete = #today > 0 and todayDone == #today
	todayButton.Progress.Text = todayDone .. "/" .. #today
	todayButton.Progress.Visible = not todayComplete
	for _, t in todayButton.Ticks do
		t.Visible = todayComplete
	end
	todayButton.Name:SetAttribute("Complete", todayComplete)
	for id, b in chapterButtons do
		local on = id == chapter
		b.Mark.Visible = on
		b.Button.BackgroundTransparency = if on and not phone then 0 else 1
		b.Name.TextColor3 = if on then TEXT else DIM
		b.Progress.TextColor3 = if on then DIM else FAINT
	end

	-- The page.
	for _, r in rows do
		r.Frame.Visible = r.Chapter == chapter
	end
	heroStep = nil
	if chapter == "Today" then
		chapterTitle.Text = "TODAY"
		chapterBlurb.Text = "Three new challenges every day, and a bonus for all three."
		chapterCount.Text = untilReset()
		local first = nil
		for i = 1, 3 do
			local r, item = rows["Daily" .. i], today[i]
			r.Frame.Visible = item ~= nil
			if item then
				local complete = item.Done == true
				if not complete and not first then
					first = i
				end
				r.Title.Text, r.Hint.Text = item.Name, item.Hint
				r.Reward:SetAttribute("Coins", "+" .. item.Coins)
				paint(r, complete, first == i, math.min(item.Goal, item.Count or 0), item.Goal)
			end
		end
		local bonus = rows.DailyBonus
		local bonusPaid = type(view) == "table" and view.BonusDone == true
		bonus.Frame.Visible = #today > 0
		bonus.Reward:SetAttribute("Coins", "+" .. (if type(view) == "table" and view.Bonus then view.Bonus else Daily.Bonus))
		paint(bonus, bonusPaid, false, todayDone, math.max(1, #today))
		hero.Visible = false
		allDone.Visible = false
		placeList(false)
	else
		local c = chapters[1]
		for _, entry in chapters do
			if entry.Id == chapter then
				c = entry
			end
		end
		chapterTitle.Text = CHAPTER_NAMES[c.Id] or string.upper(c.Id)
		chapterBlurb.Text = Rules.Blurbs[c.Id] or ""
		local finished = 0
		for _, o in c.Steps do
			if paid[o.Id] == true then
				finished += 1
			end
		end
		chapterCount.Text = finished .. " / " .. #c.Steps
		for _, o in c.Steps do
			local complete = paid[o.Id] == true
			if not complete and not heroStep then
				heroStep = o
			end
			paint(rows[o.Id], complete, heroStep == o, math.min(o.Goal, counts[o.Event] or 0), o.Goal)
		end
		-- NEXT STEP: the chapter's first step left (none: the chapter's done).
		hero.Visible = heroStep ~= nil
		allDone.Visible = heroStep == nil
		if heroStep then
			local progress = math.min(heroStep.Goal, counts[heroStep.Event] or 0)
			heroTitle.Text, heroHint.Text = heroStep.Name, heroStep.Hint
			heroReward.Text = "+" .. heroStep.Coins
			setProgress(progress, heroStep.Goal)
			heroCount.Text = progress .. " / " .. heroStep.Goal
			go.Text = if heroStep.Go == "Mine"
				then "MINE"
				elseif string.match(heroStep.Go or "", "^Guide:") then "HOW?"
				else "GO"
		end
		placeList(heroStep ~= nil)
	end
	gui:SetAttribute("Open", stillOpen())
end

-- While the window is shut only the menu tile's count can change: the rows
-- are redrawn when it opens (every sync redrawing them was a waste).
local function refreshCount()
	gui:SetAttribute("Open", stillOpen())
end

-- Opening: on the first chapter with steps left (Shared.TrainingRewards).
local function open()
	local p = GemClient.Profile
	local paid = p and p.TrainingRewards and p.TrainingRewards.Paid or {}
	chapter = Rules.currentPage(paid) or "Today"
	if gui.AbsoluteSize ~= laidOut then
		layout()
	end
	refresh()
	list.CanvasPosition = Vector2.zero
	shade.Visible = true
end
-- The lobby menu's TASKS tile opens it: fire OpenTasks.
local openEvent = new("BindableEvent", { Name = "OpenTasks" }, gui)
openEvent.Event:Connect(function()
	if gui.Enabled then
		open()
	end
end)
close.Activated:Connect(function()
	shade.Visible = false
end)
shade.Activated:Connect(function()
	shade.Visible = false
end)
local function changed()
	if shade.Visible then
		refresh()
	else
		refreshCount()
	end
end
GemClient.Changed:Connect(changed)
GemClient.ChallengesChanged:Connect(changed)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if gui.Enabled then
		layout()
		if shade.Visible then
			refresh()
		end
	end
end)

-- Shown only in the Outpost, outside fights, spars, the tutorial and menus.
local function wanted(): boolean
	local p = GemClient.Profile
	if not p or player:GetAttribute("Outpost") ~= true then
		return false
	end
	if Tutorial.Enabled and not (p.Intro ~= nil and p.Intro.Done) then
		return false
	end
	if player:GetAttribute("CombatSession") or player:GetAttribute("Spar") then
		return false
	end
	local playerGui = player.PlayerGui
	local dashboard = playerGui:FindFirstChild("Dashboard")
	local lobby = playerGui:FindFirstChild("LobbyHud")
	return playerGui:FindFirstChild("Tutorial") == nil
		and not (dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled)
		and not (lobby and (lobby:GetAttribute("ModePickerOpen") or lobby:GetAttribute("WelcomeOpen")))
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local want = wanted()
	if want ~= gui.Enabled then
		gui.Enabled = want
		if not want then
			shade.Visible = false
		elseif gui.AbsoluteSize ~= laidOut then
			layout()
		end
	end
end)
layout()
refresh()
