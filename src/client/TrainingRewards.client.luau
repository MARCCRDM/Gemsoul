--[[
	Tasks: the learning path (Shared.TrainingRewards): chapters of steps that
	teach the game, each paying coins once, and today's three challenges
	(Shared.DailyChallenges). What's done and what's paid is the server's;
	this window only shows it.

	It reads like the Outpost's work-order board, not a list of cards:
	graphite, one amber accent, condensed Oswald capitals for names and
	numbers, steps as ruled lines. The chapters down the left (on a phone a
	row of tabs along the top), TODAY first; the chapter's own page on the
	right, its NEXT STEP up top as a work order with a GO button that takes
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

-- Graphite and one amber: what's next is amber, what's done goes quiet.
local AMBER = Color3.fromRGB(255, 184, 64)
local AMBER_LIP = Color3.fromRGB(176, 112, 26) -- (the GO plate's lower edge)
local TEXT = Color3.fromRGB(236, 232, 224)
local MUTED = Color3.fromRGB(152, 149, 142)
local FAINT = Color3.fromRGB(98, 98, 102)
local PANEL = Color3.fromRGB(17, 18, 21)
local RAISED = Color3.fromRGB(25, 26, 30)
local NEXT_ROW = Color3.fromRGB(31, 27, 20)
local LINE = Color3.fromRGB(42, 44, 50)
local INK = Color3.fromRGB(20, 16, 10)
local DISPLAY = Enum.Font.Oswald -- (names and numbers)
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
	local back = new("Frame", { BackgroundColor3 = LINE }, parent)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, back)
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
UiKit.round(panel, 6)
stroke(panel, LINE)

-- The header: TASKS and how many of them are done; under it a rule that is
-- also the whole path's progress (amber as far as you've come).
local heading = label(panel, "TASKS", 34, TEXT, DISPLAY)
heading.TextTruncate = Enum.TextTruncate.None
local count = label(panel, "", 20, FAINT, DISPLAY)
count:SetAttribute("NoTranslate", true)
local overallBack, overallFill = bar(panel, AMBER)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = RAISED,
	BackgroundTransparency = 1,
	Text = "",
}, panel)
IronUi.cross(close, 14, MUTED)

-- The chapters: a rail down the left, or a row of chips on a phone.
local chapter = "Basics"
local refresh, list -- (below)
local rail = new("Frame", { BackgroundColor3 = LINE }, panel) -- (the rule between the rail and the page)
local railList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local railLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, railList)
local chapterButtons = {}
local function chapterButton(id: string, order: number)
	local b = new("TextButton", {
		BackgroundColor3 = RAISED,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = false,
	}, railList)
	UiKit.round(b, 3)
	-- On: an amber edge (at the left in the rail, under the name as a tab).
	local mark = new("Frame", { BackgroundColor3 = AMBER, Visible = false }, b)
	-- Done: a quiet tick where the count was.
	local tickBox = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1 }, b)
	local ticks = tick(tickBox, MUTED)
	local name = label(b, CHAPTER_NAMES[id] or string.upper(id), 18, TEXT, DISPLAY)
	local progress = label(b, "", 13, FAINT, Enum.Font.GothamMedium)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress:SetAttribute("NoTranslate", true)
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
local chapterTitle = label(panel, "", 28, TEXT, DISPLAY)
local chapterBlurb = label(panel, "", 13, MUTED)
local chapterCount = label(panel, "", 18, FAINT, DISPLAY)
chapterCount.TextXAlignment = Enum.TextXAlignment.Right
chapterCount:SetAttribute("NoTranslate", true)

-- NEXT STEP: the one to do now, as a work order: an amber edge, its name
-- big, how to do it, its progress as notches; the coins and a GO plate at
-- the right.
local hero = new("Frame", { BackgroundColor3 = RAISED }, panel)
UiKit.round(hero, 4)
local heroEdge = new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = AMBER }, hero)
UiKit.round(heroEdge, 2)
local heroTag = label(hero, "NEXT STEP", 11, AMBER, Enum.Font.GothamBold)
local heroTitle = label(hero, "", 24, TEXT, DISPLAY)
local heroHint = label(hero, "", 13, MUTED)
heroHint.TextWrapped, heroHint.TextYAlignment, heroHint.TextTruncate =
	true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
-- Progress: a notch a count (up to ten), else a thin bar.
local notches = new("Frame", { BackgroundTransparency = 1 }, hero)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, notches)
local heroBack, heroFill = bar(hero, AMBER)
local heroCount = label(hero, "", 12, MUTED, Enum.Font.GothamMedium)
heroCount:SetAttribute("NoTranslate", true)
local heroReward = label(hero, "", 30, AMBER, DISPLAY)
heroReward.TextXAlignment = Enum.TextXAlignment.Right
heroReward:SetAttribute("NoTranslate", true)
local heroUnit = label(hero, "COINS", 10, MUTED, Enum.Font.GothamBold)
heroUnit.TextXAlignment = Enum.TextXAlignment.Right
-- GO: a stamped plate, its darker lip under it.
local goLip = new("Frame", { AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = AMBER_LIP }, hero)
UiKit.round(goLip, 3)
local go = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = AMBER,
	Text = "GO",
	TextSize = 20,
	Font = DISPLAY,
	TextColor3 = INK,
	AutoButtonColor = true,
}, hero)
UiKit.round(go, 3)
IronUi.juice(go, 1.03, 0.97)
local heroStep -- (the step the work order shows)
local function setNotches(progress: number, goal: number, width: number)
	for _, n in notches:GetChildren() do
		if n:IsA("Frame") then
			n:Destroy()
		end
	end
	-- (A one-off step has nothing to count.)
	local counted = goal > 1
	local useNotches = counted and goal <= 10
	notches.Visible, heroBack.Visible, heroCount.Visible = useNotches, counted and not useNotches, counted
	local used = width
	if useNotches then
		local w = math.clamp(math.floor((width - 3 * (goal - 1)) / goal), 8, 26)
		used = w * goal + 3 * (goal - 1)
		for i = 1, goal do
			new("Frame", {
				Size = UDim2.fromOffset(w, 6),
				LayoutOrder = i,
				BackgroundColor3 = if i <= progress then AMBER else LINE,
			}, notches)
		end
	else
		heroFill.Size = UDim2.fromScale(progress / math.max(1, goal), 1)
	end
	heroCount.Position = UDim2.new(0, notches.Position.X.Offset + used + 10, heroCount.Position.Y.Scale, heroCount.Position.Y.Offset)
end

-- The steps.
list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = FAINT,
}, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }, list)
local allDone = label(panel, "Chapter complete! Every step here is done and paid.", 14, MUTED, Enum.Font.GothamMedium)
allDone.TextXAlignment = Enum.TextXAlignment.Center

local rows = {}
local function makeRow(id: string, chapterId: string, index: number, name: string, hint: string, coins: number)
	-- A ruled line, not a card: the step's number, its name and how, the
	-- coins at the right; the rule under it.
	local row = new("Frame", { BackgroundColor3 = NEXT_ROW, BackgroundTransparency = 1, LayoutOrder = index, Visible = false }, list)
	UiKit.round(row, 3)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = LINE,
	}, row)
	local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, row)
	local number = label(mark, string.format("%02d", index), 20, FAINT, DISPLAY)
	number.Size = UDim2.fromScale(1, 1)
	number:SetAttribute("NoTranslate", true)
	local ticks = tick(mark, FAINT)
	local title = label(row, name, 15, TEXT, Enum.Font.GothamBold)
	local words = label(row, hint, 12, MUTED)
	local status = label(row, "", 12, MUTED, Enum.Font.GothamMedium)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status:SetAttribute("NoTranslate", true)
	local reward = label(row, "+" .. coins, 20, AMBER, DISPLAY)
	reward:SetAttribute("Coins", "+" .. coins)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward:SetAttribute("NoTranslate", true)
	local unit = label(row, "COINS", 9, FAINT, Enum.Font.GothamBold)
	unit.TextXAlignment = Enum.TextXAlignment.Right
	rows[id] = {
		Chapter = chapterId,
		Frame = row,
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
local heroNotchW = 200
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
	local pad = if phone then 14 else 24

	-- Header: TASKS and its count on one line, the progress rule under them.
	local closeSize = if phone then 34 else 38
	close.Size = UDim2.fromOffset(closeSize, closeSize)
	close.Position = UDim2.new(1, -pad + 10, 0, if phone then 6 else 14)
	heading.TextSize = if phone then 24 else 34
	local headingH = if phone then 30 else 42
	local headingY = if phone then 6 else 12
	local headingW = textWidth("TASKS", heading.TextSize, heading.Font) + 12
	heading.Position, heading.Size = UDim2.fromOffset(pad, headingY), UDim2.fromOffset(headingW, headingH)
	count.TextSize = if phone then 16 else 20
	count.Position = UDim2.fromOffset(pad + headingW, headingY + (if phone then 4 else 8))
	count.Size = UDim2.fromOffset(120, headingH - (if phone then 4 else 8))
	local ruleY = headingY + headingH + (if phone then 4 else 8)
	overallBack.Position, overallBack.Size = UDim2.fromOffset(pad, ruleY), UDim2.new(1, -pad * 2, 0, 2)
	local headerH = ruleY + (if phone then 8 else 18)

	-- The chapters: a rail on the left (computer) or a row of tabs (phone).
	local contentX, contentY
	if phone then
		rail.Visible = false
		railList.Position, railList.Size = UDim2.fromOffset(pad, headerH), UDim2.new(1, -pad * 2, 0, 34)
		railList.ScrollingDirection = Enum.ScrollingDirection.X
		railList.AutomaticCanvasSize = Enum.AutomaticSize.X
		railLayout.FillDirection = Enum.FillDirection.Horizontal
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		railLayout.Padding = UDim.new(0, 24)
		for id, c in chapterButtons do
			-- (The count right after its own name, so it never reads as the
			-- next tab's.)
			local nameW = math.ceil(textWidth(CHAPTER_NAMES[id] or id, 15, DISPLAY))
			c.Button.Size = UDim2.fromOffset(nameW + 32, 32)
			c.Name.TextSize = 15
			c.Name.Position, c.Name.Size = UDim2.fromOffset(0, 0), UDim2.new(0, nameW + 4, 1, -4)
			c.Progress.TextSize = 10
			c.Progress.TextXAlignment = Enum.TextXAlignment.Left
			c.Progress.Position, c.Progress.Size = UDim2.fromOffset(nameW + 6, 1), UDim2.new(0, 26, 1, -4)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(0, nameW + 22, 0.5, -2), UDim2.fromOffset(16, 16)
			-- On: an amber underline.
			c.Mark.Position, c.Mark.Size = UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2)
		end
		contentX, contentY = pad, headerH + 44
	else
		local railW = 196
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad + railW + 12, headerH), UDim2.new(0, 1, 1, -headerH - pad)
		railList.Position = UDim2.fromOffset(pad - 10, headerH)
		railList.Size = UDim2.new(0, railW + 10, 1, -headerH - pad)
		railList.ScrollingDirection = Enum.ScrollingDirection.Y
		railList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		railLayout.FillDirection = Enum.FillDirection.Vertical
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		railLayout.Padding = UDim.new(0, 2)
		for id, c in chapterButtons do
			-- (TODAY sits apart from the chapters, a gap under it.)
			c.Button.Size = UDim2.new(1, 0, 0, if id == "Today" then 52 else 40)
			c.Name.TextSize = 18
			c.Name.Position, c.Name.Size = UDim2.fromOffset(18, 0), UDim2.new(1, -70, 0, 40)
			c.Progress.TextSize = 13
			c.Progress.TextXAlignment = Enum.TextXAlignment.Right
			c.Progress.Position, c.Progress.Size = UDim2.new(1, -52, 0, 0), UDim2.fromOffset(42, 40)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(1, -10, 0, 20), UDim2.fromOffset(18, 18)
			-- On: an amber edge at the left.
			c.Mark.Position, c.Mark.Size = UDim2.fromOffset(0, 8), UDim2.fromOffset(3, 24)
		end
		contentX, contentY = pad + railW + 34, headerH
	end
	local contentW = width - contentX - pad

	-- The chapter's name and line, its count at the right.
	chapterTitle.TextSize = if phone then 20 else 28
	local titleH = if phone then 24 else 34
	chapterTitle.Position = UDim2.fromOffset(contentX, contentY - (if phone then 0 else 4))
	chapterTitle.Size = UDim2.fromOffset(contentW - 100, titleH)
	chapterCount.TextSize = if phone then 15 else 18
	chapterCount.Position = UDim2.fromOffset(contentX + contentW - 100, contentY)
	chapterCount.Size = UDim2.fromOffset(100, titleH - 4)
	chapterBlurb.TextSize = if phone then 12 else 13
	chapterBlurb.Position = UDim2.fromOffset(contentX, contentY + titleH - (if phone then 2 else 4))
	chapterBlurb.Size = UDim2.fromOffset(contentW, 18)
	local heroY = contentY + titleH + (if phone then 22 else 28)

	-- NEXT STEP: tag and name, the how under them, then its notches; the coins
	-- and the GO plate at the right.
	local heroH = if phone then 108 else 140
	hero.Position, hero.Size = UDim2.fromOffset(contentX, heroY), UDim2.fromOffset(contentW, heroH)
	local goW, goH = if phone then 84 else 112, if phone then 36 else 42
	go.Size, go.Position = UDim2.fromOffset(goW, goH), UDim2.new(1, -16, 1, -18)
	goLip.Size, goLip.Position = UDim2.fromOffset(goW, goH), UDim2.new(1, -16, 1, -14)
	go.TextSize = if phone then 18 else 21
	local left = if phone then 16 else 22
	local textW = contentW - goW - left - 32
	heroTag.Position, heroTag.Size = UDim2.fromOffset(left, if phone then 10 else 14), UDim2.fromOffset(textW, 14)
	heroTitle.TextSize = if phone then 19 else 24
	heroTitle.Position = UDim2.fromOffset(left, if phone then 24 else 28)
	heroTitle.Size = UDim2.fromOffset(textW, if phone then 24 else 30)
	heroHint.TextSize = if phone then 12 else 13
	heroHint.Position = UDim2.fromOffset(left, if phone then 52 else 66)
	heroHint.Size = UDim2.fromOffset(textW, if phone then 30 else 34)
	local barW = math.max(40, math.min(260, textW - 60))
	notches.Position, notches.Size = UDim2.new(0, left, 1, if phone then -18 else -24), UDim2.fromOffset(barW, 8)
	heroBack.Position, heroBack.Size = UDim2.new(0, left, 1, if phone then -16 else -22), UDim2.fromOffset(barW, 4)
	heroNotchW = barW
	heroCount.Position, heroCount.Size = UDim2.new(0, left + barW + 10, 1, if phone then -22 else -28), UDim2.fromOffset(60, 16)
	heroReward.TextSize = if phone then 24 else 30
	heroReward.Position = UDim2.new(1, -16 - 160, 0, if phone then 6 else 10)
	heroReward.Size = UDim2.fromOffset(160, if phone then 28 else 36)
	heroUnit.Position = UDim2.new(1, -16 - 160, 0, if phone then 33 else 44)
	heroUnit.Size = UDim2.fromOffset(160, 12)
	allDone.Position, allDone.Size = UDim2.fromOffset(contentX, heroY + 10), UDim2.fromOffset(contentW, 40)
	content = { X = contentX, Y = contentY, W = contentW, HeroY = heroY, HeroH = heroH, Bottom = height - pad }

	-- The steps' lines.
	local rowH = if phone then 54 else 62
	for _, r in rows do
		r.Frame.Size = UDim2.new(1, -6, 0, rowH)
		local markW = if phone then 30 else 38
		r.Mark.Position, r.Mark.Size = UDim2.new(0, 8, 0.5, 0), UDim2.fromOffset(markW, if phone then 24 else 28)
		r.Number.TextSize = if phone then 17 else 20
		local textLeft = 8 + markW + 8
		r.Title.TextSize = if phone then 14 else 15
		r.Title.Position, r.Title.Size = UDim2.fromOffset(textLeft, if phone then 9 else 11), UDim2.new(1, -textLeft - 150, 0, 20)
		r.Hint.TextSize = if phone then 11 else 12
		r.Hint.Position, r.Hint.Size = UDim2.fromOffset(textLeft, if phone then 29 else 33), UDim2.new(1, -textLeft - 150, 0, 16)
		r.Status.Position, r.Status.Size = UDim2.new(1, -144, 0, 0), UDim2.new(0, 56, 1, 0)
		r.Reward.TextSize = if phone then 17 else 20
		r.Reward.Position, r.Reward.Size = UDim2.new(1, -86, 0, if phone then 7 else 9), UDim2.fromOffset(74, 24)
		r.Unit.Position, r.Unit.Size = UDim2.new(1, -86, 0, if phone then 31 else 35), UDim2.fromOffset(74, 12)
	end
end

-- The list sits under the gold card when there's one, else just under the
-- chapter's name.
local function placeList(underHero: boolean)
	local y = if underHero then content.HeroY + content.HeroH + 14 else content.HeroY + (if allDone.Visible then 56 else 0)
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

-- A step's line: done (a quiet tick, PAID), next (amber, a warm wash) or
-- still to come.
local function paint(r, complete: boolean, isNext: boolean, progress: number, goal: number)
	r.Number.Visible = not complete
	r.Number.TextColor3 = if isNext then AMBER else FAINT
	for _, t in r.Ticks do
		t.Visible = complete
	end
	r.Frame.BackgroundTransparency = if isNext then 0 else 1
	r.Status.Text = if complete or goal <= 1 then "" else progress .. " / " .. goal
	r.Title.TextColor3 = if complete then MUTED else TEXT
	r.Hint.TextColor3 = if complete then FAINT else MUTED
	r.Reward.Text = if complete then "PAID" else r.Reward:GetAttribute("Coins") or r.Reward.Text
	r.Reward.TextColor3 = if complete then FAINT else AMBER
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
		UiKit.toast(Lang.translate("Find a rock nearby and swing at it."), AMBER)
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
	count.Text = string.format("%d / %d", done, total)
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
		b.Name.TextColor3 = if on then AMBER elseif b.Name:GetAttribute("Complete") then FAINT else TEXT
		b.Progress.TextColor3 = if on then MUTED else FAINT
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
			setNotches(progress, heroStep.Goal, heroNotchW)
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
