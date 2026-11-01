--[[
	ANALYTICS: the Owners' window on the game's own event log (Server
	AnalyticsPanel, Shared.AnalyticsReport). A button beside DEV (only for
	players the server marks AnalyticsOwner) opens it:

	  [ THIS SERVER | TODAY | 7 DAYS ]                 loading 34 / 120 logs
	  PLAYERS  NEW  AVG SESSION  PEAK ONLINE  ROBUX  DAY-1 RETURN
	  PLAYERS HERE NOW (this server: who, how long, how far into onboarding)
	  ONBOARDING FUNNEL              INTRO ROUNDS
	  DEVICES        COINS IN        COINS OUT
	  DUELS          TOP EVENTS      COUNTRIES

	THIS SERVER is instant (this server since it started); TODAY and 7 DAYS
	come from every server's saved log, read a few at a time, so they fill
	in while the window's open (it asks every PollEvery seconds till all's
	in). Bars are one hue, their numbers in the text's colours; the funnel's
	biggest drop is called out in amber.

	  AnalyticsUI.start()   once (Lobby.client)
	  AnalyticsUI.open(range?)
	  AnalyticsUI.commas(n) -> string, AnalyticsUI.minutes(m) -> string   (pure)

	PLAYERS HERE NOW's last column: COUNTED / NOT COUNTED, a tap to leave a
	test account out of the numbers (Server.DevAccounts); the Owners' and
	DEV-reset accounts are always out (DEV · NOT COUNTED).
]]
local Players = game:GetService("Players")

local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local AnalyticsUI = {}

AnalyticsUI.PollEvery = 2 -- seconds, while a range is loading
AnalyticsUI.RefreshEvery = 15 -- seconds, once it's in (THIS SERVER: live)

local new = IronUi.new
local player = Players.LocalPlayer

local W, H = 880, 600
local PAD = 20
local CW = W - PAD * 2 - 8 -- (the scrolling body's width, its bar aside)
local GAP = 14
local ROW = 22

local INK, FADED, DUSK, GOLD = Gilt.Ink, Gilt.Faded, Gilt.Dusk, Gilt.Gold
local BAR = Color3.fromRGB(58, 160, 233) -- one hue for every magnitude
local TRACK = Color3.fromRGB(24, 31, 50)
local WELL = Gilt.Well
local EDGE = Gilt.Brass

local RANGES = {
	{ Id = "Server", Label = "THIS SERVER" },
	{ Id = "Today", Label = "TODAY" },
	{ Id = "Week", Label = "7 DAYS" },
}

function AnalyticsUI.commas(n: number?): string
	if n == nil then
		return "—"
	end
	local whole = math.floor(n + 0.5)
	local s = tostring(math.abs(whole))
	while true do
		local replaced, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			break
		end
	end
	return (if whole < 0 then "-" else "") .. s
end

function AnalyticsUI.minutes(m: number?): string
	if m == nil then
		return "—"
	end
	if m < 1 then
		return string.format("%ds", math.floor(m * 60 + 0.5))
	end
	if m < 60 then
		return string.format("%.1fm", m)
	end
	return string.format("%dh %02dm", math.floor(m / 60), math.floor(m % 60))
end

local window: any = nil
local ui: any = {}
local range = "Server"
local token = 0 -- (each request's number: a late answer for another tab is dropped)
local polling = false

local function words(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Gilt.Serif,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A section: a well with its heading; rows go in its Body.
local function section(parent: Instance, title: string, width: number, height: number, order: number)
	local box = new("Frame", { Size = UDim2.fromOffset(width, height), LayoutOrder = order }, parent)
	Gilt.well(box)
	local tick = new("Frame", { BackgroundColor3 = GOLD, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(3, 11) }, box)
	UiKit.round(tick, 2)
	local heading = words(box, title, 11, GOLD, Gilt.Display)
	heading.Position = UDim2.fromOffset(24, 11)
	heading.Size = UDim2.new(1, -38, 0, 16)
	local note = words(box, "", 10, DUSK)
	note.Position = UDim2.fromOffset(24, 11)
	note.Size = UDim2.new(1, -38, 0, 16)
	note.TextXAlignment = Enum.TextXAlignment.Right
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 1, -44) }, box)
	return { Box = box, Body = body, Note = note, Width = width - 28 }
end

local function empty(sec, text: string?)
	clear(sec.Body)
	local l = words(sec.Body, text or "Nothing yet.", 12, DUSK)
	l.Size = UDim2.new(1, 0, 0, ROW)
end

-- Rows of bars: a label, a bar of `value` against the biggest, its number,
-- and an optional note after it. items: { { Name, Value, Note?, Hot? } }
local function bars(sec, items, labelW: number?, max: number?)
	clear(sec.Body)
	if #items == 0 then
		empty(sec)
		return
	end
	local lw = labelW or 110
	local top = max or 0
	if not max then
		for _, item in items do
			top = math.max(top, item.Value)
		end
	end
	local noted = false
	for _, item in items do
		noted = noted or (item.Note ~= nil and item.Note ~= "")
	end
	local numberW = if noted then 96 else 48
	local trackW = sec.Width - lw - numberW - 12
	for i, item in items do
		local y = (i - 1) * ROW
		local name = words(sec.Body, item.Name, 11, if item.Hot then GOLD else FADED)
		name.Position = UDim2.fromOffset(0, y)
		name.Size = UDim2.fromOffset(lw - 6, ROW - 4)
		local track = new("Frame", { BackgroundColor3 = TRACK, Position = UDim2.fromOffset(lw, y + 5), Size = UDim2.fromOffset(trackW, 8) }, sec.Body)
		UiKit.round(track, 3)
		local share = if top > 0 then math.clamp(item.Value / top, 0, 1) else 0
		if share > 0 then
			local fill = new("Frame", { BackgroundColor3 = BAR, Size = UDim2.new(share, 0, 1, 0) }, track)
			UiKit.round(fill, 3)
		end
		local value = words(sec.Body, AnalyticsUI.commas(item.Value), 11, INK, Gilt.Display)
		value.Position = UDim2.fromOffset(lw + trackW + 8, y)
		value.Size = UDim2.fromOffset(40, ROW - 4)
		value.TextXAlignment = Enum.TextXAlignment.Right
		if item.Note then
			local note = words(sec.Body, item.Note, 10, if item.Hot then GOLD else DUSK)
			note.Position = UDim2.fromOffset(lw + trackW + 52, y)
			note.Size = UDim2.fromOffset(numberW - 40, ROW - 4)
		end
	end
end

-- A tile: a caption over a big number, a note under it.
local function tile(parent: Instance, order: number)
	local box = new("Frame", { Size = UDim2.fromOffset(0, 74), LayoutOrder = order }, parent)
	Gilt.well(box)
	local caption = words(box, "", 10, FADED)
	caption.Position = UDim2.fromOffset(12, 10)
	caption.Size = UDim2.new(1, -20, 0, 14)
	local value = words(box, "", 24, INK, Gilt.Display)
	value.Position = UDim2.fromOffset(12, 26)
	value.Size = UDim2.new(1, -20, 0, 28)
	local note = words(box, "", 10, DUSK)
	note.Position = UDim2.fromOffset(12, 54)
	note.Size = UDim2.new(1, -20, 0, 14)
	return { Box = box, Caption = caption, Value = value, Note = note }
end

local function row(parent: Instance, height: number, order: number): Frame
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CW, height), LayoutOrder = order }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }, f)
	return f
end

local function build()
	window = IronUi.window("Analytics", 60, W, H, "📊", GOLD)
	window.Gui:SetAttribute("NoTranslate", true) -- (an owner's tool: English)
	window.Title.Text = "ANALYTICS"
	window.Subtitle.Text = "The game's own event log"
	window.Close.Activated:Connect(function()
		window.Gui.Enabled = false
	end)
	window.Shade.Activated:Connect(function()
		window.Gui.Enabled = false
	end)
	local panel = window.Panel
	-- The range: three tabs, and how far its loading's got.
	ui.Tabs = {}
	for i, r in RANGES do
		local b = Gilt.button(panel, r.Label, false, i, nil, 30, 12)
		b.Position = UDim2.fromOffset(PAD + (i - 1) * 124, 82)
		b.Size = UDim2.fromOffset(116, 30)
		b.Activated:Connect(function()
			AnalyticsUI.open(r.Id)
		end)
		local mark = new("Frame", { BackgroundColor3 = GOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3), Size = UDim2.new(1, -24, 0, 2), Visible = false }, b)
		UiKit.round(mark, 1)
		ui.Tabs[r.Id] = { Button = b, Mark = mark }
	end
	ui.Status = words(panel, "", 11, FADED)
	ui.Status.Position = UDim2.fromOffset(PAD + 3 * 124 + 10, 82)
	ui.Status.Size = UDim2.fromOffset(W - PAD * 2 - 3 * 124 - 10, 30)
	ui.Status.TextXAlignment = Enum.TextXAlignment.Right

	local scroll = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 126),
		Size = UDim2.fromOffset(W - PAD * 2, H - 126 - 16),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = EDGE,
	}, panel)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP) }, scroll)

	-- The tiles.
	local tiles = row(scroll, 74, 1)
	ui.Tiles = {}
	local tileW = math.floor((CW - GAP * 5) / 6)
	for i = 1, 6 do
		local t = tile(tiles, i)
		t.Box.Size = UDim2.fromOffset(tileW, 74)
		ui.Tiles[i] = t
	end
	-- Who's here (THIS SERVER only).
	ui.HereRow = row(scroll, 60, 2)
	ui.Here = section(ui.HereRow, "PLAYERS HERE NOW", CW, 60, 1)
	-- The funnel and the rounds.
	local half = math.floor((CW - GAP) / 2)
	local h1 = 36 + 12 * ROW + 8
	local r1 = row(scroll, h1, 3)
	ui.Funnel = section(r1, "ONBOARDING FUNNEL", half, h1, 1)
	ui.Rounds = section(r1, "INTRO ROUNDS FUNNEL", half, h1, 2)
	local third = math.floor((CW - GAP * 2) / 3)
	local h2 = 36 + 8 * ROW + 8
	local r2 = row(scroll, h2, 4)
	ui.Devices = section(r2, "DEVICES", third, h2, 1)
	ui.Sources = section(r2, "COINS IN", third, h2, 2)
	ui.Sinks = section(r2, "COINS OUT", third, h2, 3)
	local r3 = row(scroll, h2, 5)
	ui.Duels = section(r3, "DUELS", third, h2, 1)
	ui.Events = section(r3, "TOP EVENTS", third, h2, 2)
	ui.Countries = section(r3, "COUNTRIES", third, h2, 3)
	local r4 = row(scroll, h2, 6)
	ui.Products = section(r4, "ROBUX BY PRODUCT", half, h2, 1)
	ui.Sessions = section(r4, "SESSION LENGTHS", half, h2, 2)
end

local function setTile(i: number, caption: string, value: string, note: string?)
	local t = ui.Tiles[i]
	t.Caption.Text, t.Value.Text, t.Note.Text = caption, value, note or ""
end

local function drawHere(list)
	local show = type(list) == "table"
	ui.HereRow.Visible = show
	if not show then
		return
	end
	local sec = ui.Here
	clear(sec.Body)
	local height = 36 + (math.max(1, #list) + 1) * ROW + 8
	ui.HereRow.Size = UDim2.fromOffset(CW, height)
	sec.Box.Size = UDim2.fromOffset(CW, height)
	sec.Note.Text = #list .. " here"
	if #list == 0 then
		empty(sec, "Nobody.")
		return
	end
	local columns = { { "PLAYER", 0, 180 }, { "IN FOR", 190, 60 }, { "LEVEL", 255, 45 }, { "ONBOARDING", 305, 180 }, { "INTRO ROUNDS", 490, 90 }, { "NOW", 585, 85 }, { "IN THE NUMBERS", 675, 125 } }
	for _, col in columns do
		local h = words(sec.Body, col[1], 9, DUSK)
		h.Position = UDim2.fromOffset(col[2], 0)
		h.Size = UDim2.fromOffset(col[3], 14)
	end
	for i, p in list do
		local y = i * ROW
		local cells = {
			{ (p.Name or "?") .. (if p.User and p.User ~= p.Name then "  @" .. p.User else ""), INK },
			{ if p.Minutes then AnalyticsUI.minutes(p.Minutes) else "—", FADED },
			{ if p.Level then "Lv " .. tostring(p.Level) else "—", FADED },
			{ if p.New then (if p.StepName then string.format("%d · %s", p.Step, p.StepName) else "joined") else "returning", if p.New then INK else DUSK },
			{ if p.Rounds then string.format("%d / 6 won", p.Rounds) else "—", if p.Rounds then INK else DUSK },
			{ if p.Where then tostring(p.Where) else "Outpost", FADED },
		}
		for c, cell in cells do
			local col = columns[c]
			local l = words(sec.Body, cell[1], 11, cell[2], if c == 1 then Gilt.Display else nil)
			l.Position = UDim2.fromOffset(col[2], y)
			l.Size = UDim2.fromOffset(col[3], ROW - 4)
		end
		-- Counted in the numbers, or left out (a test account): a dev account
		-- (an Owner, a Tester, NoAnalytics, or a DEV reset's) always is.
		local col = columns[7]
		if p.Listed then
			local l = words(sec.Body, "DEV · NOT COUNTED", 10, DUSK, Gilt.Display)
			l.Position = UDim2.fromOffset(col[2], y)
			l.Size = UDim2.fromOffset(col[3], ROW - 4)
		elseif p.UserId then
			local excluded = p.Excluded == true
			local toggle = new("TextButton", {
				Name = "Counted",
				Position = UDim2.fromOffset(col[2], y),
				Size = UDim2.fromOffset(col[3] - 6, ROW - 4),
				BackgroundColor3 = if excluded then TRACK else BAR:Lerp(TRACK, 0.55),
				Font = Gilt.Display,
				TextSize = 10,
				TextColor3 = if excluded then DUSK else INK,
				Text = if excluded then "NOT COUNTED" else "COUNTED",
				AutoButtonColor = true,
			}, sec.Body)
			UiKit.round(toggle, 4)
			toggle.Activated:Connect(function()
				toggle.Text = "…"
				task.spawn(function()
					local answer = GemClient.request("AnalyticsExclude", p.UserId, not excluded)
					if answer and answer.Message and answer.Message ~= "" then
						UiKit.toast(answer.Message, if answer.Ok then GOLD else Gilt.Red)
					end
					if AnalyticsUI.refresh then
						AnalyticsUI.refresh()
					end
				end)
			end)
		end
	end
end

local function draw(answer)
	local report = answer.Report
	-- The status line.
	local loading = answer.Loading
	if answer.Problem then
		ui.Status.Text = answer.Problem
		ui.Status.TextColor3 = Gilt.Red
	elseif loading and (loading.Busy or loading.Done < loading.Total) then
		ui.Status.Text = string.format("Reading the saved logs…  %d / %d", loading.Done, loading.Total)
		ui.Status.TextColor3 = GOLD
	elseif answer.Range == "Server" then
		ui.Status.Text = string.format("Server %s · up %s · live", tostring(answer.Server or "?"), AnalyticsUI.minutes(((answer.Now or 0) - (answer.Since or 0)) / 60))
		ui.Status.TextColor3 = FADED
	else
		ui.Status.Text = string.format("%d logs · %s rows · up to 5 minutes behind", loading and loading.Total or 0, AnalyticsUI.commas(report and report.Rows or 0))
		ui.Status.TextColor3 = FADED
	end
	drawHere(if answer.Range == "Server" then answer.Here else nil)
	if not report then
		for i = 1, 6 do
			setTile(i, "", "…")
		end
		return
	end
	-- The tiles.
	setTile(1, "PLAYERS", AnalyticsUI.commas(report.Players), string.format("%s sessions", AnalyticsUI.commas(report.Sessions)))
	setTile(2, "NEW PLAYERS", AnalyticsUI.commas(report.New), string.format("%s returning", AnalyticsUI.commas(report.Returning)))
	setTile(3, "AVG SESSION", AnalyticsUI.minutes(report.AvgSession), "median " .. AnalyticsUI.minutes(report.MedianSession))
	setTile(4, "PEAK ONLINE", AnalyticsUI.commas(report.PeakOnline), if answer.Range == "Server" then "this server" else "all servers")
	setTile(5, "ROBUX", AnalyticsUI.commas(report.Revenue), string.format("%d payers · %d buys", report.Payers, report.Purchases))
	local d1 = report.D1
	setTile(6, "DAY-1 RETURN", if d1 then string.format("%.0f%%", d1.Pct or 0) else "—", if d1 then string.format("%d of %d new", d1.Back, d1.Cohort) else "needs 2+ days (7 DAYS)")
	-- A funnel: each step's players, the drop from the step before; its
	-- biggest drop in amber.
	local function funnelBars(sec, steps, labelW: number, numbered: boolean)
		local worst, worstAt = 0, nil
		for i, step in steps do
			if i > 1 and (step.Drop or 0) > worst then
				worst, worstAt = step.Drop, i
			end
		end
		local items = {}
		for i, step in steps do
			table.insert(items, {
				Name = if numbered then string.format("%d  %s", step.Step, step.Name) else step.Name,
				Value = step.Users,
				Note = if i == 1 then "" else string.format("-%s%%", tostring(step.Drop or 0)),
				Hot = i == worstAt and worst > 0,
			})
		end
		bars(sec, items, labelW)
		sec.Note.Text = if worstAt then "biggest drop in amber" else ""
	end
	funnelBars(ui.Funnel, report.Funnel, 140, true)
	-- The intro rounds: each round's start and win (Analytics' IntroRounds
	-- funnel); before it was sent, the rounds' wins and losses.
	local intro = report.Funnels and report.Funnels.IntroRounds
	if intro and #intro > 0 then
		funnelBars(ui.Rounds, intro, 120, false)
	else
		local rounds = {}
		for _, rd in report.Rounds do
			table.insert(rounds, {
				Name = string.format("%d  %s", rd.Round, rd.Slot or ""),
				Value = rd.Won,
				Note = string.format("%d lost", rd.Lost) .. (if rd.Rare > 0 then string.format(" · %d rare", rd.Rare) else ""),
			})
		end
		bars(ui.Rounds, rounds, 110)
		ui.Rounds.Note.Text = "players who won each round"
	end
	local function named(list)
		local out = {}
		for _, item in list do
			table.insert(out, { Name = item.Name, Value = item.Value })
		end
		return out
	end
	bars(ui.Devices, named(report.Devices), 80)
	bars(ui.Sources, named(report.Sources), 90)
	bars(ui.Sinks, named(report.Sinks), 90)
	local duels = {}
	for _, d in report.Duels do
		local played = d.Wins + d.Losses
		table.insert(duels, { Name = d.Name, Value = played, Note = if played > 0 then string.format("%d%% won", math.floor(100 * d.Wins / played + 0.5)) else "" })
	end
	bars(ui.Duels, duels, 80)
	bars(ui.Events, named(report.Events), 110)
	bars(ui.Countries, named(report.Countries), 50)
	bars(ui.Products, named(report.Products), 140)
	-- How long sessions last.
	bars(ui.Sessions, named(report.Lengths or {}), 80)
	ui.Sessions.Note.Text = "sessions that ended"
end

local function ask()
	token += 1
	local mine = token
	local which = range
	task.spawn(function()
		local answer = GemClient.request("AnalyticsReport", which)
		if mine ~= token or not window then
			return
		end
		if not (answer and answer.Ok) then
			ui.Status.Text = tostring(answer and answer.Message or "Couldn't get the numbers.")
			ui.Status.TextColor3 = Gilt.Red
			return
		end
		draw(answer)
		ui.Loading = answer.Loading
	end)
end

AnalyticsUI.refresh = ask

local function poll()
	if polling then
		return
	end
	polling = true
	task.spawn(function()
		local last = os.clock()
		while window and window.Gui.Enabled do
			local loading = ui.Loading
			local filling = range ~= "Server" and loading ~= nil and (loading.Busy or loading.Done < loading.Total)
			local every = if filling then AnalyticsUI.PollEvery else AnalyticsUI.RefreshEvery
			if os.clock() - last >= every then
				last = os.clock()
				ask()
			end
			task.wait(0.5)
		end
		polling = false
	end)
end

function AnalyticsUI.open(which: string?)
	if not window then
		build()
	end
	range = which or range
	for id, tab in ui.Tabs do
		local on = id == range
		tab.Button.TextColor3 = if on then GOLD else FADED
		tab.Mark.Visible = on
	end
	ui.Loading = nil
	ui.Status.Text = "…"
	ui.Status.TextColor3 = FADED
	window.Gui.Enabled = true
	ask()
	poll()
end

-- The button, beside DEV (bottom right).
local function button()
	local gui = UiKit.gui("AnalyticsButton", 120)
	gui:SetAttribute("NoTranslate", true)
	local b = new("TextButton", {
		Name = "Analytics",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -96, 1, -8),
		Size = UDim2.fromOffset(92, 28),
		BackgroundColor3 = Color3.fromRGB(39, 61, 79),
		TextColor3 = Color3.fromRGB(255, 210, 126),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Text = "ANALYTICS",
		AutoButtonColor = true,
	}, gui)
	UiKit.round(b, 6)
	b.Activated:Connect(function()
		if window and window.Gui.Enabled then
			window.Gui.Enabled = false
		else
			AnalyticsUI.open()
		end
	end)
end

local started = false
function AnalyticsUI.start()
	if started then
		return
	end
	started = true
	-- (the server says who's an owner, and checks every request again)
	task.spawn(function()
		while player:GetAttribute("AnalyticsOwner") == nil do
			player:GetAttributeChangedSignal("AnalyticsOwner"):Wait()
		end
		if player:GetAttribute("AnalyticsOwner") == true then
			button()
		end
	end)
end

return AnalyticsUI
