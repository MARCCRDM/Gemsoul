--[[
	Tasks: the learning path (Shared.TrainingRewards): chapters of steps that
	teach the game, each paying coins once, and today's three challenges
	(Shared.DailyChallenges). What's done and what's paid is the server's;
	this window only shows it.

	It's the Rift terminal: a field log on dark glass, cyan light along its
	edges and corner brackets, a double frame, Sarpanch for names and
	numbers, Titillium for the words. The chapters down the left (on a phone
	a row of tabs along the top), the open one lit magenta; TODAY first. The
	chapter's page on the right: its NEXT OBJECTIVE up top (magenta, its
	count as segments, the coins in gold and a cyan GO that takes you where
	the step happens: out to the rocks, the Inventory, the PLAY menu, the
	Market, or the GUIDE's page on it), then every step in order, numbered,
	ticked off in cyan as they're done. It opens on the first chapter with
	steps left. Everything is frames, gradients and strokes (no images).

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

-- The terminal's light: cyan for the frame and what's done, magenta for
-- what's open now, gold for coins, on dark glass.
local GLASS_TOP = Color3.fromRGB(16, 36, 46)
local GLASS_BOTTOM = Color3.fromRGB(5, 12, 19)
local CYAN = Color3.fromRGB(54, 241, 205)
local CYAN_LIT = Color3.fromRGB(150, 255, 236)
local PINK = Color3.fromRGB(255, 79, 216)
local GOLD = Color3.fromRGB(255, 216, 77)
local TEXT = Color3.fromRGB(232, 246, 250)
local DIM = Color3.fromRGB(127, 179, 196)
local FAINT = Color3.fromRGB(79, 132, 150)
local LINE = Color3.fromRGB(29, 67, 82)
local INK = Color3.fromRGB(4, 14, 20)
local TITLE = Enum.Font.Michroma -- (the window's name)
local HEAD = Enum.Font.Sarpanch -- (names and numbers)
local BODY = Enum.Font.TitilliumWeb -- (the words)
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
		Font = font or BODY,
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
-- Light along a line: bright at one end, gone by the other.
local function fade(object: GuiObject, from: number, to: number, rotation: number?)
	return new("UIGradient", {
		Rotation = rotation or 0,
		Transparency = NumberSequence.new(from, to),
	}, object)
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
		local across = new("Frame", common, parent)
		across.Size = UDim2.fromOffset(length, t)
		local down = new("Frame", common, parent)
		down.Size = UDim2.fromOffset(t, math.floor(length * 0.62))
	end
end
-- A bar of segments (a step's count, the path's progress).
local function segments(parent: Instance, n: number, w: number, h: number, gap: number): { Frame }
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(n * (w + gap), h) }, parent)
	local cells = {}
	for i = 1, n do
		local cell = new("Frame", {
			Position = UDim2.fromOffset((i - 1) * (w + gap), 0),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = LINE,
		}, row)
		table.insert(cells, cell)
	end
	return cells, row
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
	BackgroundTransparency = 0.03,
	Text = "",
	AutoButtonColor = false,
}, shade)
UiKit.round(panel, 4)
new("UIGradient", { Rotation = 100, Color = ColorSequence.new(GLASS_TOP, GLASS_BOTTOM) }, panel)
stroke(panel, CYAN, 0.78)
-- The double frame: a second hairline just inside the first.
local inner = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 1, -12),
}, panel)
UiKit.round(inner, 2)
stroke(inner, LINE, 0.1)
-- Light falling from the top of the glass.
local sheen = new("Frame", { BackgroundColor3 = CYAN, Size = UDim2.new(1, 0, 0, 66) }, panel)
UiKit.round(sheen, 4)
fade(sheen, 0.93, 1, 90)
for _, corner in { "TL", "TR", "BL", "BR" } do
	bracket(panel, corner, CYAN, 54, 2)
end

-- The header: TASKS (lit cyan), the log line and the path as segments, a
-- rule with a lit end and a diamond, the close.
local heading = label(panel, "TASKS", 26, CYAN, TITLE)
heading.TextTruncate = Enum.TextTruncate.None
new("UIStroke", { Color = CYAN, Transparency = 0.8, Thickness = 2 }, heading)
local count = label(panel, "", 13, DIM, BODY)
count:SetAttribute("NoTranslate", true) -- (Lang.format puts it in Spanish)
local pathCells, pathRow = segments(panel, math.min(#objectives, 30), 9, 4, 2)
local rule = new("Frame", { BackgroundColor3 = LINE }, panel)
local ruleLit = new("Frame", { BackgroundColor3 = CYAN, Size = UDim2.fromOffset(110, 1) }, rule)
fade(ruleLit, 0, 1)
local ruleStud = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(7, 7),
	Rotation = 45,
	BackgroundColor3 = CYAN,
}, rule)
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

-- The chapters: down the left (computer) or a row of tabs (phone).
local chapter = "Basics"
local refresh, list -- (below)
local rail = new("Frame", { BackgroundColor3 = LINE }, panel) -- (the rule between the chapters and the page)
local railList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 0,
}, panel)
local railLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }, railList)
local chapterButtons = {}
local function chapterButton(id: string, order: number)
	local b = new("TextButton", {
		BackgroundColor3 = CYAN,
		BackgroundTransparency = 0,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = false,
	}, railList)
	local wash = fade(b, 0.9, 1)
	b:SetAttribute("UiSound", "Tab")
	local edge = new("Frame", { BackgroundColor3 = LINE, Size = UDim2.new(0, 2, 1, 0) }, b)
	-- Open: a magenta edge (at the left, or under a tab) with its glow.
	local mark = new("Frame", { BackgroundColor3 = PINK, Visible = false }, b)
	local markGlow = new("Frame", { BackgroundColor3 = PINK, BackgroundTransparency = 0.75, Visible = false }, b)
	-- Done: a cyan tick where the count was.
	local tickBox = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1 }, b)
	local ticks = tick(tickBox, CYAN)
	local name = label(b, CHAPTER_NAMES[id] or string.upper(id), 15, DIM, HEAD)
	local progress = label(b, "", 12, FAINT, BODY)
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
	chapterButtons[id] = {
		Button = b,
		Wash = wash,
		Edge = edge,
		Mark = mark,
		MarkGlow = markGlow,
		TickBox = tickBox,
		Ticks = ticks,
		Name = name,
		Progress = progress,
	}
end
chapterButton("Today", 0)
for i, c in chapters do
	chapterButton(c.Id, i)
end

-- The chapter's page: its name, its line, how far along it is.
local chapterTitle = label(panel, "", 22, TEXT, HEAD)
local chapterBlurb = label(panel, "", 14, DIM, BODY)
local chapterCount = label(panel, "", 14, FAINT, HEAD)
chapterCount.TextXAlignment = Enum.TextXAlignment.Right
chapterCount:SetAttribute("NoTranslate", true)

-- NEXT OBJECTIVE: magenta glass with brackets, its name and how, its count
-- as segments; the coins in gold and the cyan GO at the right.
local hero = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1 }, panel)
new("UIGradient", {
	Rotation = 20,
	Color = ColorSequence.new(Color3.fromRGB(44, 14, 46), Color3.fromRGB(8, 30, 38)),
}, hero)
stroke(hero, PINK, 0.55)
bracket(hero, "TL", PINK, 22, 2)
bracket(hero, "BR", CYAN, 22, 2)
local heroTag = label(hero, "NEXT OBJECTIVE", 12, PINK, HEAD)
local heroTitle = label(hero, "", 26, TEXT, HEAD)
local heroHint = label(hero, "", 14, DIM, BODY)
heroHint.TextWrapped, heroHint.TextYAlignment, heroHint.TextTruncate =
	true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
local heroSegs = new("Frame", { BackgroundTransparency = 1 }, hero)
local heroCount = label(hero, "", 13, DIM, BODY)
heroCount:SetAttribute("NoTranslate", true)
local heroReward = label(hero, "", 30, GOLD, HEAD)
heroReward.TextXAlignment = Enum.TextXAlignment.Right
heroReward:SetAttribute("NoTranslate", true)
new("UIStroke", { Color = GOLD, Transparency = 0.82, Thickness = 2 }, heroReward)
local heroUnit = label(hero, "COINS", 11, FAINT, HEAD)
heroUnit.TextXAlignment = Enum.TextXAlignment.Right
-- GO: lit cyan glass, dark words, a glow round it and light along its top.
local go = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "GO",
	TextSize = 22,
	Font = HEAD,
	TextColor3 = INK,
	AutoButtonColor = false,
}, hero)
UiKit.round(go, 2)
local goShade = new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(96, 244, 214), Color3.fromRGB(14, 150, 132)),
}, go)
local goGlow = stroke(go, CYAN, 0.55, 3)
new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.35,
	Position = UDim2.fromOffset(4, 1),
	Size = UDim2.new(1, -8, 0, 1),
}, go)
go:SetAttribute("UiSound", "Confirm")
go.MouseEnter:Connect(function()
	goShade.Color = ColorSequence.new(Color3.fromRGB(150, 255, 234), Color3.fromRGB(30, 190, 166))
	goGlow.Transparency = 0.25
end)
go.MouseLeave:Connect(function()
	goShade.Color = ColorSequence.new(Color3.fromRGB(96, 244, 214), Color3.fromRGB(14, 150, 132))
	goGlow.Transparency = 0.55
end)
IronUi.juice(go, 1.04, 0.96)
local heroStep -- (the step the card shows)
local heroCells = {}
local heroSegW = 240
-- The step's count as segments, lit as far as you've come (one cell a count
-- up to ten; past ten each cell is a tenth). A one-off step shows none.
local function setProgress(progress: number, goal: number)
	for _, c in heroCells do
		c:Destroy()
	end
	table.clear(heroCells)
	local counted = goal > 1
	heroSegs.Visible, heroCount.Visible = counted, counted
	if not counted then
		return
	end
	local n = math.min(goal, 10)
	local lit = math.floor(progress / goal * n + 1e-6)
	local w = math.clamp(math.floor((heroSegW - 4 * (n - 1)) / n), 10, 38)
	for i = 1, n do
		local on = i <= lit
		if on then
			local glow = new("Frame", {
				Position = UDim2.fromOffset((i - 1) * (w + 4) - 2, -2),
				Size = UDim2.fromOffset(w + 4, 11),
				BackgroundColor3 = CYAN,
				BackgroundTransparency = 0.8,
			}, heroSegs)
			table.insert(heroCells, glow)
		end
		local cell = new("Frame", {
			Position = UDim2.fromOffset((i - 1) * (w + 4), 0),
			Size = UDim2.fromOffset(w, 7),
			BackgroundColor3 = if on then CYAN else LINE,
		}, heroSegs)
		table.insert(heroCells, cell)
	end
	heroCount.Position = UDim2.new(0, heroSegs.Position.X.Offset + n * (w + 4) + 8, heroCount.Position.Y.Scale, heroCount.Position.Y.Offset)
end

-- The steps.
list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = CYAN,
}, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, list)
local allDone = label(panel, "Chapter complete! Every step here is done and paid.", 16, CYAN, HEAD)
allDone.TextXAlignment = Enum.TextXAlignment.Center

local rows = {}
local function makeRow(id: string, chapterId: string, index: number, name: string, hint: string, coins: number)
	-- A line of the log: its number, its name and how, the coins at the
	-- right; a rule under it.
	local row = new("Frame", {
		BackgroundColor3 = PINK,
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Visible = false,
	}, list)
	local wash = fade(row, 0.88, 1)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = LINE,
	}, row)
	local edge = new("Frame", { BackgroundColor3 = PINK, Size = UDim2.new(0, 2, 1, -1), Visible = false }, row)
	local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, row)
	local number = label(mark, string.format("%02d", index), 17, FAINT, HEAD)
	number.Size = UDim2.fromScale(1, 1)
	number:SetAttribute("NoTranslate", true)
	local ticks = tick(mark, CYAN)
	local title = label(row, name, 16, TEXT, BODY)
	local words = label(row, hint, 13, FAINT, BODY)
	local status = label(row, "", 13, DIM, BODY)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status:SetAttribute("NoTranslate", true)
	local reward = label(row, "+" .. coins, 19, GOLD, HEAD)
	reward:SetAttribute("Coins", "+" .. coins)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward:SetAttribute("NoTranslate", true)
	rows[id] = {
		Chapter = chapterId,
		Frame = row,
		Wash = wash,
		Edge = edge,
		Mark = mark,
		Number = number,
		Ticks = ticks,
		Title = title,
		Hint = words,
		Status = status,
		Reward = reward,
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
	local width = math.max(300, math.min(if phone then 900 else 900, screen.X - (if phone then 20 else 48)))
	local height = math.max(260, math.min(if phone then 640 else 600, screen.Y - (if phone then 12 else 48)))
	panel.Size = UDim2.fromOffset(width, height)
	local pad = if phone then 16 else 28

	-- Header: TASKS, the log line and the path's segments beside it, the
	-- rule under them, the close at the right.
	local head = if phone then 50 else 66
	heading.TextSize = if phone then 20 else 26
	local headingW = textWidth("TASKS", heading.TextSize, heading.Font) + 14
	heading.Position, heading.Size = UDim2.fromOffset(pad, if phone then 10 else 16), UDim2.fromOffset(headingW, 34)
	local metaX = pad + headingW + (if phone then 10 else 24)
	count.Position, count.Size = UDim2.fromOffset(metaX, if phone then 10 else 18), UDim2.fromOffset(260, 16)
	pathRow.Position = UDim2.fromOffset(metaX, if phone then 30 else 40)
	rule.Position, rule.Size = UDim2.fromOffset(pad, head), UDim2.new(1, -pad * 2, 0, 1)
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -pad, 0, (head - 34) / 2)

	-- The chapters.
	local contentX, contentY
	if phone then
		rail.Visible = false
		railList.Position, railList.Size = UDim2.fromOffset(pad, head + 6), UDim2.new(1, -pad * 2, 0, 34)
		railList.ScrollingDirection = Enum.ScrollingDirection.X
		railList.AutomaticCanvasSize = Enum.AutomaticSize.X
		railLayout.FillDirection = Enum.FillDirection.Horizontal
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		railLayout.Padding = UDim.new(0, 16)
		for id, c in chapterButtons do
			-- (The count right after its own name, so it never reads as the
			-- next tab's.)
			local nameW = math.ceil(textWidth(CHAPTER_NAMES[id] or id, 13, HEAD))
			c.Button.Size = UDim2.fromOffset(nameW + 30, 32)
			c.Button.BackgroundTransparency = 1
			c.Edge.Visible = false
			c.Name.TextSize = 13
			c.Name.Position, c.Name.Size = UDim2.fromOffset(0, 0), UDim2.new(0, nameW + 4, 1, -4)
			c.Progress.TextSize = 10
			c.Progress.TextXAlignment = Enum.TextXAlignment.Left
			c.Progress.Position, c.Progress.Size = UDim2.fromOffset(nameW + 6, 1), UDim2.new(0, 24, 1, -4)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(0, nameW + 20, 0.5, -2), UDim2.fromOffset(14, 14)
			c.Mark.Position, c.Mark.Size = UDim2.new(0, 0, 1, -2), UDim2.new(0, nameW, 0, 2)
			c.MarkGlow.Position, c.MarkGlow.Size = UDim2.new(0, -2, 1, -4), UDim2.new(0, nameW + 4, 0, 6)
		end
		contentX, contentY = pad, head + 50
	else
		local railW = 184
		rail.Visible = true
		rail.Position, rail.Size = UDim2.fromOffset(pad + railW + 14, head + 16), UDim2.new(0, 1, 1, -head - 16 - pad)
		railList.Position = UDim2.fromOffset(pad, head + 16)
		railList.Size = UDim2.new(0, railW, 1, -head - 16 - pad)
		railList.ScrollingDirection = Enum.ScrollingDirection.Y
		railList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		railLayout.FillDirection = Enum.FillDirection.Vertical
		railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		railLayout.Padding = UDim.new(0, 5)
		for id, c in chapterButtons do
			-- (TODAY sits a little apart from the chapters.)
			c.Button.Size = UDim2.new(1, 0, 0, if id == "Today" then 44 else 36)
			c.Button.BackgroundTransparency = 0
			c.Edge.Visible = true
			c.Name.TextSize = 15
			c.Name.Position, c.Name.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -60, 0, 36)
			c.Progress.TextSize = 12
			c.Progress.TextXAlignment = Enum.TextXAlignment.Right
			c.Progress.Position, c.Progress.Size = UDim2.new(1, -50, 0, 0), UDim2.fromOffset(42, 36)
			c.TickBox.Position, c.TickBox.Size = UDim2.new(1, -8, 0, 18), UDim2.fromOffset(16, 16)
			c.Mark.Position, c.Mark.Size = UDim2.fromOffset(0, 0), UDim2.new(0, 3, 0, 36)
			c.MarkGlow.Position, c.MarkGlow.Size = UDim2.fromOffset(0, 0), UDim2.new(0, 8, 0, 36)
		end
		contentX, contentY = pad + railW + 34, head + 16
	end
	local contentW = width - contentX - pad

	-- The chapter's name and line, its count at the right.
	chapterTitle.TextSize = if phone then 17 else 22
	local titleH = if phone then 20 else 26
	chapterTitle.Position = UDim2.fromOffset(contentX, contentY)
	chapterTitle.Size = UDim2.fromOffset(contentW - 90, titleH)
	chapterCount.Position = UDim2.fromOffset(contentX + contentW - 90, contentY)
	chapterCount.Size = UDim2.fromOffset(90, titleH)
	chapterBlurb.TextSize = if phone then 12 else 14
	chapterBlurb.Position = UDim2.fromOffset(contentX, contentY + titleH)
	chapterBlurb.Size = UDim2.fromOffset(contentW, 18)
	local heroY = contentY + titleH + (if phone then 24 else 30)

	-- NEXT OBJECTIVE: tag, name, how, segments; the coins and GO at the right.
	local heroH = if phone then 104 else 128
	hero.Position, hero.Size = UDim2.fromOffset(contentX, heroY), UDim2.fromOffset(contentW, heroH)
	local goW, goH = if phone then 90 else 120, if phone then 36 else 44
	go.Size, go.Position = UDim2.fromOffset(goW, goH), UDim2.new(1, -16, 1, -16)
	go.TextSize = if phone then 19 else 22
	local left = if phone then 16 else 20
	local textW = contentW - goW - left - 34
	heroTag.Position, heroTag.Size = UDim2.fromOffset(left, if phone then 10 else 14), UDim2.fromOffset(textW, 14)
	heroTitle.TextSize = if phone then 20 else 26
	heroTitle.Position, heroTitle.Size = UDim2.fromOffset(left, if phone then 24 else 29), UDim2.fromOffset(textW, if phone then 24 else 30)
	heroHint.TextSize = if phone then 12 else 14
	heroHint.Position, heroHint.Size = UDim2.fromOffset(left, if phone then 50 else 62), UDim2.fromOffset(textW, 34)
	heroSegW = math.max(60, math.min(240, textW - 70))
	heroSegs.Position, heroSegs.Size = UDim2.new(0, left, 1, if phone then -20 else -24), UDim2.fromOffset(heroSegW, 8)
	heroCount.Position, heroCount.Size = UDim2.new(0, left + heroSegW + 8, 1, if phone then -26 else -30), UDim2.fromOffset(60, 18)
	heroReward.TextSize = if phone then 24 else 30
	heroReward.Position, heroReward.Size = UDim2.new(1, -18 - 160, 0, if phone then 8 else 10), UDim2.fromOffset(160, if phone then 28 else 34)
	heroUnit.Position, heroUnit.Size = UDim2.new(1, -18 - 160, 0, if phone then 34 else 43), UDim2.fromOffset(160, 12)
	allDone.Position, allDone.Size = UDim2.fromOffset(contentX, heroY + 10), UDim2.fromOffset(contentW, 40)
	content = { X = contentX, Y = contentY, W = contentW, HeroY = heroY, HeroH = heroH, Bottom = height - pad }

	-- The log's lines.
	local rowH = if phone then 50 else 56
	for _, r in rows do
		r.Frame.Size = UDim2.new(1, -6, 0, rowH)
		local markW = if phone then 28 else 34
		r.Mark.Position, r.Mark.Size = UDim2.new(0, 12, 0.5, 0), UDim2.fromOffset(markW, 24)
		local textLeft = 12 + markW + 10
		r.Title.TextSize = if phone then 14 else 16
		r.Title.Position, r.Title.Size = UDim2.fromOffset(textLeft, if phone then 7 else 9), UDim2.new(1, -textLeft - 150, 0, 20)
		r.Hint.TextSize = if phone then 11 else 13
		r.Hint.Position, r.Hint.Size = UDim2.fromOffset(textLeft, if phone then 27 else 30), UDim2.new(1, -textLeft - 150, 0, 16)
		r.Status.Position, r.Status.Size = UDim2.new(1, -140, 0, 0), UDim2.new(0, 56, 1, 0)
		r.Reward.TextSize = if phone then 17 else 19
		r.Reward.Position, r.Reward.Size = UDim2.new(1, -80, 0, 0), UDim2.new(0, 68, 1, 0)
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

-- A line of the log: done (a cyan tick, PAID), open now (magenta: its
-- number, an edge and a wash) or still to come.
local function paint(r, complete: boolean, isNext: boolean, progress: number, goal: number)
	r.Number.Visible = not complete
	r.Number.TextColor3 = if isNext then PINK else FAINT
	for _, t in r.Ticks do
		t.Visible = complete
	end
	r.Edge.Visible = isNext
	r.Frame.BackgroundTransparency = if isNext then 0 else 1
	r.Status.Text = if complete or goal <= 1 then "" else progress .. " / " .. goal
	r.Title.TextColor3 = if complete then FAINT else TEXT
	r.Hint.TextColor3 = if complete then Color3.fromRGB(56, 96, 110) else FAINT
	r.Reward.Text = if complete then "PAID" else r.Reward:GetAttribute("Coins") or r.Reward.Text
	r.Reward.TextSize = if complete then 14 else 19
	r.Reward.TextColor3 = if complete then CYAN else GOLD
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
		UiKit.toast(Lang.translate("Find a rock nearby and swing at it."), CYAN)
	elseif where == "Kennel" then
		UiKit.toast(Lang.translate("Wren is at the Kaiju Kennel, by the pen's gate in the Outpost."), CYAN)
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
	count.Text = Lang.format("FIELD LOG  ·  {1} / {2} COMPLETE", done, total)
	local cells = #pathCells
	for i, cell in pathCells do
		cell.BackgroundColor3 = if total > 0 and i <= math.floor(done / total * cells + 1e-6) then CYAN else LINE
	end

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
		b.Mark.Visible, b.MarkGlow.Visible = on, on
		b.Wash.Transparency = NumberSequence.new(if on then 0.8 else 0.92, 1)
		b.Button.BackgroundColor3 = if on then PINK else CYAN
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
