--[[
	Tasks: optional objectives that pay coins (Shared.TrainingRewards). What's
	done and what's paid is the server's; this window only shows it.

	It lays itself out from the screen it's on. On a phone in landscape the
	header is one row (title, progress, close), the filters one row (the
	categories scroll sideways, the To do / Done / All switch sits at the
	right) and the tasks come two to a row, so several show at once. A big
	screen also gets the kicker and the footer. Layout runs only when the
	screen changes size or the window opens; words and bars only when the
	profile changes.

	It opens from the lobby menu's TASKS tile (LobbyUI fires its OpenTasks
	event): nothing of it sits on the play screen. The day's three challenges
	(Shared.DailyChallenges) and their all-three bonus are its DAILY page, so
	a phone's screen keeps no strip for them either.

	ScreenGui "TrainingRewards", with the BlocksMiningHud attribute while open
	(OutpostScene and VehicleDrive step aside for it), and Open: how many
	tasks and today's challenges are still to do (the menu tile's badge).
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
local CYAN = Color3.fromRGB(103, 218, 232)
local TEXT = Color3.fromRGB(240, 246, 255)
local PANEL = Color3.fromRGB(12, 19, 30)
local CARD = Color3.fromRGB(21, 32, 46)
local CHIP = Color3.fromRGB(27, 41, 56)
local TRACK = Color3.fromRGB(40, 53, 69)
local CATEGORY_COLORS = {
	Daily = Color3.fromRGB(186, 140, 255),
	Mining = GOLD,
	Equipment = Color3.fromRGB(159, 171, 255),
	Combat = Color3.fromRGB(255, 146, 119),
	PvP = Color3.fromRGB(243, 151, 207),
	PvE = Color3.fromRGB(113, 218, 168),
	Market = CYAN,
}
-- Tasks for switched-off activities sit out (Config.Features).
Rules.closeFor(Config.Features or {})
local CATEGORIES = { "All", "Daily" }
for _, name in { "Mining", "Equipment", "Combat", "PvP", "PvE", "Market" } do
	if not Rules.Closed[name] then
		table.insert(CATEGORIES, name)
	end
end
local objectives = {}
for _, o in Rules.Objectives do
	if Rules.listed(o) then
		table.insert(objectives, o)
	end
end
local FILTERS = { { Id = "Active", Text = "To do" }, { Id = "Completed", Text = "Done" }, { Id = "All", Text = "All" } }

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

local heading = label(panel, "TASKS", 24, TEXT, Enum.Font.GothamBold)
heading.TextTruncate = Enum.TextTruncate.None
local count = label(panel, "", 12, GOLD, Enum.Font.GothamBold)
local overallBack, overallFill = bar(panel, GOLD)
local kicker = label(panel, "Learn the game, earn coins. They never expire.", 12, MUTED)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = CHIP,
	Text = "",
}, panel)
IronUi.cross(close, 13, TEXT)
UiKit.round(close, 999)
stroke(close, MUTED, 0.8)

-- Filters: categories (scrolling sideways) and the To do / Done / All switch.
local category, filter = "All", "Active"
local refresh, list -- (below)
local categories = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 0,
}, panel)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, categories)
local chips = {}
for i, name in CATEGORIES do
	local chip = new("TextButton", {
		BackgroundColor3 = CHIP,
		Text = name,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = MUTED,
		LayoutOrder = i,
		AutoButtonColor = true,
	}, categories)
	UiKit.round(chip, 999)
	chip.Activated:Connect(function()
		category = name
		refresh()
		list.CanvasPosition = Vector2.zero
	end)
	chips[name] = chip
end
local switch = new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 26, 38) }, panel)
UiKit.round(switch, 999)
stroke(switch, Color3.fromRGB(60, 84, 104), 0.4)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 2),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, switch)
new("UIPadding", {
	PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 3),
	PaddingTop = UDim.new(0, 3),
	PaddingBottom = UDim.new(0, 3),
}, switch)
local segments = {}
for i, f in FILTERS do
	local segment = new("TextButton", {
		Size = UDim2.new(1 / #FILTERS, -2, 1, 0),
		BackgroundColor3 = CHIP,
		BackgroundTransparency = 1,
		Text = f.Text,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = MUTED,
		LayoutOrder = i,
	}, switch)
	UiKit.round(segment, 999)
	segment.Activated:Connect(function()
		filter = f.Id
		refresh()
		list.CanvasPosition = Vector2.zero
	end)
	segments[f.Id] = segment
end

-- The tasks.
list = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = CYAN,
}, panel)
local grid = new("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)
local empty = label(panel, "Nothing here. Try another category or filter.", 13, MUTED)
empty.TextXAlignment = Enum.TextXAlignment.Center
local footer = label(panel, "Rewards arrive by themselves as you play. No expiry.", 11, MUTED)
footer.TextXAlignment = Enum.TextXAlignment.Center

local cards = {}
local function makeCard(id: string, index: number, category: string, name: string, hint: string, coins: number)
	local accent = CATEGORY_COLORS[category] or GOLD
	local card = new("Frame", { BackgroundColor3 = CARD, LayoutOrder = index }, list)
	UiKit.round(card, 10)
	local outline = stroke(card, accent, 0.85)
	local stripe = new(
		"Frame",
		{ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(0, 3, 1, -24), BackgroundColor3 = accent },
		card
	)
	UiKit.round(stripe, 2)
	local tag = label(card, string.upper(category), 10, accent, Enum.Font.GothamBold)
	local title = label(card, name, 15, TEXT, Enum.Font.GothamBold)
	local words = label(card, hint, 11, MUTED)
	words.TextWrapped, words.TextYAlignment = true, Enum.TextYAlignment.Top
	local reward =
		new("Frame", { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(50, 43, 28) }, card)
	UiKit.round(reward, 8)
	local rewardEdge = stroke(reward, GOLD, 0.75)
	local amount = label(reward, "+" .. coins, 15, GOLD, Enum.Font.GothamBold)
	amount.TextXAlignment, amount.Position, amount.Size =
		Enum.TextXAlignment.Center, UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0.6, 0)
	local unit = label(reward, "COINS", 8, GOLD, Enum.Font.GothamBold)
	unit.TextXAlignment, unit.Position, unit.Size =
		Enum.TextXAlignment.Center, UDim2.new(0, 0, 0.58, 0), UDim2.new(1, 0, 0.36, 0)
	local track, fill = bar(card, CYAN)
	local status = label(card, "", 10, MUTED, Enum.Font.GothamBold)
	status.TextXAlignment = Enum.TextXAlignment.Right
	cards[id] = {
		Index = index,
		Frame = card,
		Outline = outline,
		Tag = tag,
		Title = title,
		Hint = words,
		Reward = reward,
		RewardEdge = rewardEdge,
		Amount = amount,
		Unit = unit,
		Track = track,
		Fill = fill,
		Status = status,
		Accent = accent,
	}
end
for i, o in objectives do
	makeCard(o.Id, i, o.Category, o.Name, o.Hint, o.Coins)
end
-- Today's three challenges and their bonus lead the list (their words come
-- with the day's challenges).
for i = 1, 3 do
	makeCard("Daily" .. i, i - 10, "Daily", "", "", 0)
end
makeCard("DailyBonus", -6, "Daily", "All three today", "Finish today's three challenges for a bonus.", Daily.Bonus)

-- Where everything goes, for this screen.
local laidOut = Vector2.zero
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	laidOut = screen
	local short = screen.Y < 500
	local width = math.max(280, math.min(if short then 900 else 780, screen.X - (if short then 20 else 48)))
	local height = math.max(240, math.min(640, screen.Y - (if short then 12 else 48)))
	panel.Size = UDim2.fromOffset(width, height)
	local pad = if short then 12 else 20

	-- Header: one row on a phone, title over progress on a big screen.
	local closeSize = if short then 34 else 40
	close.Size = UDim2.fromOffset(closeSize, closeSize)
	close.Position = UDim2.new(1, -pad + 4, 0, if short then 6 else 12)
	heading.TextSize = if short then 20 else 26
	local headingW = textWidth("TASKS", heading.TextSize, heading.Font) + 10
	heading.Position, heading.Size = UDim2.fromOffset(pad, if short then 8 else 14), UDim2.fromOffset(headingW, 28)
	local headerH
	if short then
		count.Position, count.Size = UDim2.fromOffset(pad + headingW + 10, 8), UDim2.fromOffset(110, 28)
		local barX = pad + headingW + 10 + 112
		overallBack.Position = UDim2.fromOffset(barX, 19)
		overallBack.Size = UDim2.new(1, -barX - pad - closeSize - 4, 0, 6)
		kicker.Visible = false
		headerH = 44
	else
		count.Position, count.Size = UDim2.fromOffset(pad + headingW + 12, 18), UDim2.fromOffset(160, 24)
		overallBack.Position, overallBack.Size = UDim2.fromOffset(pad, 52), UDim2.new(1, -pad * 2 - closeSize - 8, 0, 6)
		kicker.Visible = true
		kicker.Position, kicker.Size = UDim2.fromOffset(pad, 64), UDim2.new(1, -pad * 2, 0, 18)
		headerH = 90
	end

	-- Filters: on a phone one row, the switch at the right; on a big screen
	-- the categories get the whole width and the switch a row of its own.
	local rowY = headerH
	local rowH = if short then 32 else 36
	local switchW = if short then 186 else 222
	if short then
		switch.Position, switch.Size = UDim2.new(1, -pad - switchW, 0, rowY), UDim2.fromOffset(switchW, rowH)
		categories.Position, categories.Size =
			UDim2.fromOffset(pad, rowY), UDim2.new(1, -pad * 2 - switchW - 10, 0, rowH)
	else
		categories.Position, categories.Size = UDim2.fromOffset(pad, rowY), UDim2.new(1, -pad * 2, 0, rowH)
		rowY += rowH + 8
		switch.Position, switch.Size = UDim2.fromOffset(pad, rowY), UDim2.fromOffset(switchW, rowH)
	end
	for name, chip in chips do
		chip.TextSize = if short then 12 else 13
		chip.Size =
			UDim2.new(0, math.ceil(textWidth(name, chip.TextSize, chip.Font)) + (if short then 22 else 28), 1, -4)
	end
	for _, segment in segments do
		segment.TextSize = if short then 11 else 12
	end

	-- The list: everything below, two to a row when there's width.
	local listY = rowY + rowH + (if short then 8 else 12)
	local footerH = if short then 0 else 28
	footer.Visible = not short
	footer.Position, footer.Size = UDim2.new(0, pad, 1, -footerH), UDim2.new(1, -pad * 2, 0, 18)
	list.Position, list.Size = UDim2.fromOffset(pad, listY), UDim2.new(1, -pad * 2 + 6, 1, -listY - pad - footerH + 4)
	empty.Position, empty.Size = UDim2.fromOffset(pad, listY + 20), UDim2.new(1, -pad * 2, 0, 24)
	local listWidth = width - pad * 2
	local columns = if listWidth >= 560 then 2 else 1
	local cardH = if short then 96 else 112
	grid.CellSize = UDim2.new(1 / columns, -(8 * (columns - 1)) / columns - 6, 0, cardH)

	-- Inside each card: tag, title, hint, then the bar and its count.
	for _, c in cards do
		c.Tag.Position, c.Tag.Size = UDim2.fromOffset(14, 8), UDim2.new(1, -96, 0, 14)
		c.Title.TextSize = if short then 14 else 16
		c.Title.Position, c.Title.Size = UDim2.fromOffset(14, 22), UDim2.new(1, -96, 0, 20)
		c.Hint.TextSize = if short then 11 else 12
		c.Hint.Position, c.Hint.Size = UDim2.fromOffset(14, 44), UDim2.new(1, -24, 1, -44 - 24)
		c.Reward.Position, c.Reward.Size = UDim2.new(1, -10, 0, 10), UDim2.fromOffset(if short then 60 else 68, 36)
		c.Track.Position, c.Track.Size = UDim2.new(0, 14, 1, -14), UDim2.new(1, -96, 0, 5)
		c.Status.Position, c.Status.Size = UDim2.new(1, -78, 1, -21), UDim2.fromOffset(68, 14)
	end
end

-- What's still to do: tasks not yet paid, and today's challenges not yet done.
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

-- A card's state: done (paid, green) or how far along it is.
local function paint(c, complete: boolean, progress: number, goal: number)
	c.Status.Text = if complete then "DONE" else progress .. " / " .. goal
	c.Status.TextColor3 = if complete then GREEN else MUTED
	c.Fill.Size = UDim2.fromScale(if complete then 1 else progress / math.max(1, goal), 1)
	c.Fill.BackgroundColor3 = if complete then GREEN else CYAN
	c.Outline.Color = if complete then GREEN else c.Accent
	c.Outline.Transparency = if complete then 0.7 else 0.85
	c.Unit.Text = if complete then "PAID" else "COINS"
	c.Amount.TextColor3 = if complete then GREEN else GOLD
	c.Unit.TextColor3 = c.Amount.TextColor3
	c.RewardEdge.Color = c.Amount.TextColor3
	c.Reward.BackgroundColor3 = if complete then Color3.fromRGB(24, 48, 40) else Color3.fromRGB(50, 43, 28)
	-- Done ones sink to the bottom of "All".
	c.Frame.LayoutOrder = (if complete then 1000 else 0) + c.Index
end

-- How long today's challenges have left.
local function untilReset(): string
	local left = 86400 - os.time() % 86400
	local hours, minutes = left // 3600, (left % 3600) // 60
	return if hours > 0 then string.format("%dh %02dm", hours, minutes) else string.format("%dm", math.max(1, minutes))
end

-- The words and bars, from the profile.
refresh = function()
	local p = GemClient.Profile
	local state = p and p.TrainingRewards or {}
	local paid, counts = state.Paid or {}, state.Counts or {}
	local done, shown = 0, 0
	local function show(c, inCategory: boolean, complete: boolean)
		c.Frame.Visible = inCategory and (filter == "All" or (filter == "Completed") == complete)
		if c.Frame.Visible then
			shown += 1
		end
	end
	for _, o in objectives do
		local c = cards[o.Id]
		local complete = paid[o.Id] == true
		if complete then
			done += 1
		end
		show(c, category == "All" or category == o.Category, complete)
		paint(c, complete, math.min(o.Goal, counts[o.Event] or 0), o.Goal)
	end
	-- Today's challenges, then the bonus for all three.
	local view = p and p.Challenges
	local today = if type(view) == "table" and type(view.List) == "table" then view.List else {}
	local daily = category == "All" or category == "Daily"
	local finished = 0
	for i = 1, 3 do
		local c, item = cards["Daily" .. i], today[i]
		local complete = item ~= nil and item.Done == true
		show(c, item ~= nil and daily, complete)
		if item then
			finished += if complete then 1 else 0
			c.Title.Text, c.Hint.Text, c.Amount.Text = item.Name, item.Hint, "+" .. item.Coins
			c.Tag.Text = "DAILY  ·  " .. untilReset()
			paint(c, complete, math.min(item.Goal, item.Count or 0), item.Goal)
		end
	end
	local bonus = cards.DailyBonus
	local bonusPaid = type(view) == "table" and view.BonusDone == true
	show(bonus, #today > 0 and daily, bonusPaid)
	bonus.Amount.Text = "+" .. (if type(view) == "table" and view.Bonus then view.Bonus else Daily.Bonus)
	paint(bonus, bonusPaid, finished, math.max(1, #today))
	local total = #objectives
	count.Text = string.format("%d / %d DONE", done, total)
	overallFill.Size = UDim2.fromScale(if total > 0 then done / total else 0, 1)
	empty.Visible = shown == 0
	empty.Text = if done == total and filter == "Active"
		then "Every task is done, and every reward paid. Nice work."
		else "Nothing here. Try another category or filter."
	for name, chip in chips do
		local on = category == name
		chip.BackgroundColor3 = if on then GOLD else CHIP
		chip.TextColor3 = if on then Color3.fromRGB(15, 23, 34) else MUTED
	end
	for id, segment in segments do
		local on = filter == id
		segment.BackgroundTransparency = if on then 0 else 1
		segment.BackgroundColor3 = if on then Color3.fromRGB(35, 65, 78) else CHIP
		segment.TextColor3 = if on then CYAN else MUTED
	end
	gui:SetAttribute("Open", stillOpen())
end

-- While the window is shut only the menu tile's count can change: the cards
-- are redrawn when it opens (every sync redrawing them was a waste).
local function refreshCount()
	gui:SetAttribute("Open", stillOpen())
end

-- Opening: on the first page with something left to do (Shared.TrainingRewards).
local function open()
	local p = GemClient.Profile
	local paid = p and p.TrainingRewards and p.TrainingRewards.Paid or {}
	local page = Rules.currentPage(paid)
	category = if page and CATEGORY_COLORS[page] then page else "All"
	filter = "Active"
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
