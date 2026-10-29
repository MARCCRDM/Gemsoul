--[[
	Tasks: the learning path (Shared.TrainingRewards): chapters of steps that
	teach the game, each paying coins once, and today's three challenges
	(Shared.DailyChallenges). What's done and what's paid is the server's;
	this window only shows it.

	It reads like a path, not a list: the chapters down the left (on a phone
	a row of chips along the top), TODAY first; the chapter's own page on the
	right, its NEXT STEP up top in a gold card with a GO button that takes
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

local GOLD = Color3.fromRGB(255, 207, 103)
local MUTED = Color3.fromRGB(169, 188, 207)
local GREEN = Color3.fromRGB(108, 229, 177)
local TEXT = Color3.fromRGB(240, 246, 255)
local PANEL = Color3.fromRGB(12, 19, 30)
local RAIL = Color3.fromRGB(16, 25, 38)
local CARD = Color3.fromRGB(21, 32, 46)
local CHIP = Color3.fromRGB(27, 41, 56)
local TRACK = Color3.fromRGB(40, 53, 69)
local INK = Color3.fromRGB(15, 23, 34)
local PURPLE = Color3.fromRGB(186, 140, 255)
local EDGE = Color3.fromRGB(52, 72, 92)
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
		TextColor3 = color or MUTED,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function stroke(parent: Instance, color: Color3, transparency: number?)
	return new("UIStroke", { Color = color, Thickness = 1, Transparency = transparency or 0 }, parent)
end
local function bar(parent: Instance, color: Color3)
	local back = new("Frame", { BackgroundColor3 = TRACK }, parent)
	UiKit.round(back, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, back)
	UiKit.round(fill, 3)
	return back, fill
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
	BackgroundColor3 = PANEL,
	Text = "",
	AutoButtonColor = false,
}, shade)
UiKit.round(panel, 14)
stroke(panel, Color3.fromRGB(94, 132, 162), 0.5)
local topLine =
	new("Frame", { Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 0), BackgroundColor3 = GOLD }, panel)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, topLine)

-- The header: TASKS, how many are done, the bar, the close.
local heading = label(panel, "TASKS", 24, TEXT, Enum.Font.GothamBlack)
heading.TextTruncate = Enum.TextTruncate.None
local count = label(panel, "", 12, GOLD, Enum.Font.GothamBold)
local overallBack, overallFill = bar(panel, GOLD)
local kicker = label(panel, "Your path through the game. Every step pays coins, once.", 12, MUTED)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = CHIP,
	Text = "",
}, panel)
IronUi.cross(close, 13, TEXT)
UiKit.round(close, 999)
stroke(close, MUTED, 0.8)

-- The chapters: a rail down the left, or a row of chips on a phone.
local chapter = "Basics"
local refresh, list -- (below)
local rail = new("Frame", { BackgroundColor3 = RAIL }, panel)
UiKit.round(rail, 12)
local railList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local railLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, railList)
local chapterButtons = {}
local function chapterButton(id: string, order: number)
	local b = new("TextButton", {
		BackgroundColor3 = CHIP,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = false,
	}, railList)
	UiKit.round(b, 10)
	-- Its mark: the chapter's number, a tick when it's done, a dot for TODAY.
	local mark = new("Frame", { BackgroundColor3 = TRACK }, b)
	UiKit.round(mark, 999)
	local number = label(mark, if id == "Today" then "" else tostring(order), 11, TEXT, Enum.Font.GothamBlack)
	number.Size, number.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	number:SetAttribute("NoTranslate", true)
	local ticks = tick(mark, INK)
	local name = label(b, CHAPTER_NAMES[id] or string.upper(id), 13, TEXT, Enum.Font.GothamBold)
	local progress = label(b, "", 11, MUTED, Enum.Font.GothamBold)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress:SetAttribute("NoTranslate", true)
	b.Activated:Connect(function()
		chapter = id
		refresh()
		list.CanvasPosition = Vector2.zero
	end)
	chapterButtons[id] = { Button = b, Mark = mark, Number = number, Ticks = ticks, Name = name, Progress = progress }
end
chapterButton("Today", 0)
for i, c in chapters do
	chapterButton(c.Id, i)
end

-- The chapter's page: its name, its line, how far along it is.
local chapterTitle = label(panel, "", 22, TEXT, Enum.Font.GothamBlack)
local chapterBlurb = label(panel, "", 12, MUTED)
local chapterCount = label(panel, "", 12, GOLD, Enum.Font.GothamBold)
chapterCount.TextXAlignment = Enum.TextXAlignment.Right
chapterCount:SetAttribute("NoTranslate", true)

-- NEXT STEP: the one to do now, in gold, with its GO.
local hero = new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 33, 17) }, panel)
UiKit.round(hero, 12)
stroke(hero, GOLD, 0.25)
local heroTag = label(hero, "NEXT STEP", 11, GOLD, Enum.Font.GothamBlack)
local heroTitle = label(hero, "", 18, TEXT, Enum.Font.GothamBlack)
local heroHint = label(hero, "", 12, Color3.fromRGB(225, 214, 190))
heroHint.TextWrapped, heroHint.TextYAlignment, heroHint.TextTruncate =
	true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
local heroBack, heroFill = bar(hero, GOLD)
local heroCount = label(hero, "", 11, GOLD, Enum.Font.GothamBold)
heroCount:SetAttribute("NoTranslate", true)
local heroReward = label(hero, "", 15, GOLD, Enum.Font.GothamBlack)
heroReward.TextXAlignment = Enum.TextXAlignment.Right
heroReward:SetAttribute("NoTranslate", true) -- (Lang.format puts it in Spanish)
local go = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = GOLD,
	Text = "GO",
	TextSize = 16,
	Font = Enum.Font.GothamBlack,
	TextColor3 = INK,
	AutoButtonColor = true,
}, hero)
UiKit.round(go, 999)
IronUi.juice(go, 1.04, 0.96)
local heroStep -- (the step the gold card shows)

-- The steps.
list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = GOLD,
}, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, list)
local allDone = label(panel, "Chapter complete! Every step here is done and paid.", 13, GREEN, Enum.Font.GothamBold)
allDone.TextXAlignment = Enum.TextXAlignment.Center

local rows = {}
local function makeRow(id: string, chapterId: string, index: number, name: string, hint: string, coins: number)
	local row = new("Frame", { BackgroundColor3 = CARD, LayoutOrder = index, Visible = false }, list)
	UiKit.round(row, 10)
	local outline = stroke(row, EDGE, 0.45)
	local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = TRACK }, row)
	UiKit.round(mark, 999)
	local number = label(mark, tostring(index), 12, TEXT, Enum.Font.GothamBlack)
	number.Size, number.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	number:SetAttribute("NoTranslate", true)
	local ticks = tick(mark, INK)
	local title = label(row, name, 14, TEXT, Enum.Font.GothamBold)
	local words = label(row, hint, 11, MUTED)
	local status = label(row, "", 11, MUTED, Enum.Font.GothamBold)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status:SetAttribute("NoTranslate", true)
	local reward = label(row, "+" .. coins, 14, GOLD, Enum.Font.GothamBlack)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward:SetAttribute("NoTranslate", true)
	local unit = label(row, "COINS", 8, GOLD, Enum.Font.GothamBold)
	unit.TextXAlignment = Enum.TextXAlignment.Right
	rows[id] = {
		Chapter = chapterId,
		Frame = row,
		Outline = outline,
		Mark = mark,
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
	local width = math.max(300, math.min(if phone then 900 else 860, screen.X - (if phone then 20 else 48)))
	local height = math.max(260, math.min(if phone then 640 else 620, screen.Y - (if phone then 12 else 48)))
	panel.Size = UDim2.fromOffset(width, height)
	local pad = if phone then 12 else 18

	-- Header: one row on a phone (title, count, bar, close), title over the
	-- bar on a big screen.
	local closeSize = if phone then 34 else 40
	close.Size = UDim2.fromOffset(closeSize, closeSize)
	close.Position = UDim2.new(1, -pad + 4, 0, if phone then 6 else 12)
	heading.TextSize = if phone then 20 else 26
	local headingW = textWidth("TASKS", heading.TextSize, heading.Font) + 10
	heading.Position, heading.Size = UDim2.fromOffset(pad, if phone then 8 else 14), UDim2.fromOffset(headingW, 28)
	local headerH
	if phone then
		count.Position, count.Size = UDim2.fromOffset(pad + headingW + 8, 8), UDim2.fromOffset(110, 28)
		local barX = pad + headingW + 8 + 112
		overallBack.Position = UDim2.fromOffset(barX, 19)
		overallBack.Size = UDim2.new(1, -barX - pad - closeSize - 4, 0, 6)
		kicker.Visible = false
		headerH = 44
	else
		count.Position, count.Size = UDim2.fromOffset(pad + headingW + 12, 18), UDim2.fromOffset(160, 24)
		overallBack.Position, overallBack.Size = UDim2.fromOffset(pad, 50), UDim2.new(1, -pad * 2 - closeSize - 8, 0, 6)
		kicker.Visible = true
		kicker.Position, kicker.Size = UDim2.fromOffset(pad, 62), UDim2.new(1, -pad * 2, 0, 18)
		headerH = 88
	end

	-- The chapters: a rail on the left (computer) or a row of chips (phone).
	local contentX, contentY
	if phone then
		rail.Visible = false
		railList.Position, railList.Size = UDim2.fromOffset(pad, headerH), UDim2.new(1, -pad * 2, 0, 34)
		railList.ScrollingDirection = Enum.ScrollingDirection.X
		railList.AutomaticCanvasSize = Enum.AutomaticSize.X
		railLayout.FillDirection = Enum.FillDirection.Horizontal
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		for id, c in chapterButtons do
			local w = math.ceil(textWidth(CHAPTER_NAMES[id] or id, 12, Enum.Font.GothamBold)) + 74
			c.Button.Size = UDim2.fromOffset(w, 30)
			c.Mark.Position, c.Mark.Size = UDim2.fromOffset(5, 5), UDim2.fromOffset(20, 20)
			c.Name.TextSize = 12
			c.Name.Position, c.Name.Size = UDim2.fromOffset(30, 0), UDim2.new(1, -66, 1, 0)
			c.Progress.Position, c.Progress.Size = UDim2.new(1, -38, 0, 0), UDim2.fromOffset(32, 30)
		end
		contentX, contentY = pad, headerH + 42
	else
		local railW = 200
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad, headerH), UDim2.new(0, railW, 1, -headerH - pad)
		railList.Position = UDim2.fromOffset(pad + 6, headerH + 8)
		railList.Size = UDim2.new(0, railW - 12, 1, -headerH - pad - 16)
		railList.ScrollingDirection = Enum.ScrollingDirection.Y
		railList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		railLayout.FillDirection = Enum.FillDirection.Vertical
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		for _, c in chapterButtons do
			c.Button.Size = UDim2.new(1, 0, 0, 38)
			c.Mark.Position, c.Mark.Size = UDim2.fromOffset(8, 7), UDim2.fromOffset(24, 24)
			c.Name.TextSize = 13
			c.Name.Position, c.Name.Size = UDim2.fromOffset(40, 0), UDim2.new(1, -86, 1, 0)
			c.Progress.Position, c.Progress.Size = UDim2.new(1, -46, 0, 0), UDim2.fromOffset(38, 38)
		end
		contentX, contentY = pad + railW + 16, headerH
	end
	local contentW = width - contentX - pad

	-- The chapter's name and line, its count at the right.
	chapterTitle.TextSize = if phone then 17 else 22
	chapterTitle.Position = UDim2.fromOffset(contentX, contentY)
	chapterTitle.Size = UDim2.fromOffset(contentW - 90, if phone then 22 else 28)
	chapterCount.Position = UDim2.fromOffset(contentX + contentW - 90, contentY)
	chapterCount.Size = UDim2.fromOffset(90, if phone then 22 else 28)
	chapterBlurb.Position = UDim2.fromOffset(contentX, contentY + (if phone then 22 else 28))
	chapterBlurb.Size = UDim2.fromOffset(contentW, 16)
	local heroY = contentY + (if phone then 42 else 52)

	-- NEXT STEP: tag and title, the how under them, then its bar; reward and
	-- GO at the right.
	local heroH = if phone then 92 else 112
	hero.Position, hero.Size = UDim2.fromOffset(contentX, heroY), UDim2.fromOffset(contentW, heroH)
	local goW, goH = if phone then 76 else 96, if phone then 34 else 40
	go.Size, go.Position = UDim2.fromOffset(goW, goH), UDim2.new(1, -12, 1, -12)
	go.TextSize = if phone then 15 else 17
	local textW = contentW - goW - 40
	heroTag.Position, heroTag.Size = UDim2.fromOffset(14, 10), UDim2.fromOffset(textW, 14)
	heroTitle.TextSize = if phone then 15 else 19
	heroTitle.Position, heroTitle.Size = UDim2.fromOffset(14, 24), UDim2.fromOffset(textW, if phone then 20 else 24)
	heroHint.TextSize = if phone then 11 else 12
	heroHint.Position = UDim2.fromOffset(14, if phone then 45 else 52)
	heroHint.Size = UDim2.fromOffset(textW, if phone then 28 else 34)
	local barW = math.max(40, textW - 60)
	heroBack.Position, heroBack.Size = UDim2.new(0, 14, 1, -14), UDim2.fromOffset(barW, 5)
	heroCount.Position, heroCount.Size = UDim2.new(0, 14 + barW + 8, 1, -21), UDim2.fromOffset(52, 14)
	heroReward.Position, heroReward.Size = UDim2.new(1, -12 - 140, 0, 10), UDim2.fromOffset(140, 20)
	allDone.Position, allDone.Size = UDim2.fromOffset(contentX, heroY + 10), UDim2.fromOffset(contentW, 40)
	content = { X = contentX, Y = contentY, W = contentW, HeroY = heroY, HeroH = heroH, Bottom = height - pad }

	-- The steps' rows.
	local rowH = if phone then 54 else 60
	for _, r in rows do
		r.Frame.Size = UDim2.new(1, -8, 0, rowH)
		local markSize = if phone then 26 else 30
		r.Mark.Position, r.Mark.Size = UDim2.new(0, 10, 0.5, 0), UDim2.fromOffset(markSize, markSize)
		local left = 10 + markSize + 10
		r.Title.TextSize = if phone then 13 else 14
		r.Title.Position, r.Title.Size = UDim2.fromOffset(left, if phone then 8 else 10), UDim2.new(1, -left - 150, 0, 18)
		r.Hint.TextSize = if phone then 10 else 11
		r.Hint.Position, r.Hint.Size = UDim2.fromOffset(left, if phone then 28 else 31), UDim2.new(1, -left - 150, 0, 16)
		r.Status.Position, r.Status.Size = UDim2.new(1, -140, 0, 0), UDim2.new(0, 56, 1, 0)
		r.Reward.Position, r.Reward.Size = UDim2.new(1, -78, 0, if phone then 10 else 12), UDim2.fromOffset(66, 18)
		r.Unit.Position, r.Unit.Size = UDim2.new(1, -78, 0, if phone then 28 else 31), UDim2.fromOffset(66, 12)
	end
end

-- The list sits under the gold card when there's one, else just under the
-- chapter's name.
local function placeList(underHero: boolean)
	local y = if underHero then content.HeroY + content.HeroH + 10 else content.HeroY + (if allDone.Visible then 56 else 0)
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

-- A step's row: done (ticked, green, PAID), next (gold) or still to come.
local function paint(r, complete: boolean, isNext: boolean, progress: number, goal: number)
	r.Mark.BackgroundColor3 = if complete then GREEN elseif isNext then GOLD else TRACK
	r.Number.Visible = not complete
	r.Number.TextColor3 = if isNext then INK else TEXT
	for _, t in r.Ticks do
		t.Visible = complete
	end
	r.Status.Text = if complete or goal <= 1 then "" else progress .. " / " .. goal
	r.Title.TextColor3 = if complete then MUTED else TEXT
	r.Outline.Color = if complete then GREEN elseif isNext then GOLD else EDGE
	r.Outline.Transparency = if complete then 0.75 elseif isNext then 0.3 else 0.45
	r.Frame.BackgroundTransparency = if complete then 0.35 else 0
	r.Unit.Text = if complete then "PAID" else "COINS"
	r.Reward.TextColor3 = if complete then GREEN else GOLD
	r.Unit.TextColor3 = r.Reward.TextColor3
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
	count.Text = string.format("%d / %d DONE", done, total)
	overallFill.Size = UDim2.fromScale(if total > 0 then done / total else 0, 1)

	-- The chapters' marks and counts.
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
		b.Progress.TextColor3 = if complete then GREEN else MUTED
		b.Mark.BackgroundColor3 = if complete then GREEN else TRACK
		b.Number.Visible = not complete
		for _, t in b.Ticks do
			t.Visible = complete
		end
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
	todayButton.Progress.Text = todayDone .. "/" .. #today
	todayButton.Progress.TextColor3 = if #today > 0 and todayDone == #today then GREEN else PURPLE
	todayButton.Mark.BackgroundColor3 = PURPLE
	for id, b in chapterButtons do
		local on = id == chapter
		b.Button.BackgroundTransparency = if on then 0 else (if phone then 0 else 1)
		b.Button.BackgroundColor3 = if on then Color3.fromRGB(44, 58, 76) else CHIP
		b.Name.TextColor3 = if on then GOLD else TEXT
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
				r.Title.Text, r.Hint.Text, r.Reward.Text = item.Name, item.Hint, "+" .. item.Coins
				paint(r, complete, first == i, math.min(item.Goal, item.Count or 0), item.Goal)
			end
		end
		local bonus = rows.DailyBonus
		local bonusPaid = type(view) == "table" and view.BonusDone == true
		bonus.Frame.Visible = #today > 0
		bonus.Reward.Text = "+" .. (if type(view) == "table" and view.Bonus then view.Bonus else Daily.Bonus)
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
			heroReward.Text = Lang.format("+{1} COINS", heroStep.Coins)
			heroFill.Size = UDim2.fromScale(progress / math.max(1, heroStep.Goal), 1)
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
