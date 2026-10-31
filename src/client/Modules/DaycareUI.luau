--[[
	The Kaiju Daycare's window (Shared.Daycare; its desk in the pen:
	Client.DaycarePen; the server: Server.DaycareServer).

	  Left    IN THE DAYCARE (n / Slots): each of yours boarded, its level
	          then and now, TRAINING with the time left or STORED, what it
	          costs to collect it now, and COLLECT
	  Right   BOARD A KAIJU: your kaiju at home (not the team out, nor your
	          support); pick one, then STORE or TRAIN (and for how long),
	          what it'll cost (and what level it'll get to), and BOARD

	  DaycareUI.open()
	  DaycareUI.project(level, hours) -> level, fee   a training stay, worked
	                     out ahead (pure: Daycare.result)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Daycare = require(ReplicatedStorage.Shared.Daycare)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local DaycareUI = {}

local P = IronUi.Colors
local new = IronUi.new
local W, H = 780, 470
local LEFT_W = 330
local GOLD = Color3.fromRGB(242, 196, 92)
local TRAIN = Color3.fromRGB(120, 230, 140)
local STORE = Color3.fromRGB(120, 190, 255)
local CARD = Color3.fromRGB(18, 23, 34)
local INK = Color3.fromRGB(10, 13, 20)

-- A training stay of `hours` for a kaiju of `level`: where it gets to and
-- what it costs (its training alone: kept after, it's the STORE rate).
function DaycareUI.project(level: number, hours: number): (number, number)
	local result = Daycare.result({ Mode = "Train", Hours = hours, At = 0, Record = { Level = level, Exp = 0 } }, hours * 3600)
	return result.Level, result.Fee
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			return s
		end
	end
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, seconds % 60)
end

local function line(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font, x, y, w, h): TextLabel
	local label = IronUi.text(parent, value, size, color, font)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end

local function button(parent: Instance, text: string, color: Color3, x, y, w, h, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = text,
		Font = IronUi.Heading,
		TextSize = 13,
		TextColor3 = INK,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(b, 8)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end

local ui: { [string]: any } = {}
local state = { Data = nil :: any, FetchedAt = 0, Pick = nil :: string?, Mode = "Train", Hours = 4, Busy = false, Asked = 0, Can = false }

local draw -- (forward)

local function fetch()
	state.Asked += 1
	local mine = state.Asked
	task.spawn(function()
		local result = GemClient.request("DaycareState")
		if mine ~= state.Asked or not ui.Window.Gui.Enabled then
			return
		end
		if result and result.Ok then
			state.Data, state.FetchedAt = result, os.clock()
		else
			UiKit.toast(result and result.Message or "The Daycare isn't answering.", P.Gold)
		end
		draw()
	end)
end

local function act(request: string, ...)
	if state.Busy then
		return
	end
	state.Busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(request, table.unpack(args, 1, args.n))
		state.Busy = false
		if result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then P.Good else P.Gold)
		end
		if result and result.Ok then
			state.Pick = nil
		end
		fetch()
	end)
end

local function build()
	local w = IronUi.window("KaijuDaycare", 12, W, H, "⌂", TRAIN)
	w.Title.Text = "KAIJU DAYCARE"
	w.Subtitle.Text = "Store a kaiju safely, or have it trained. You pay when you collect it."
	w.Close.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	w.Shade.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	ui.Window = w
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 1, -94) }, w.Panel)
	-- Left: yours in the Daycare.
	ui.LeftHead = line(body, "IN THE DAYCARE", 12, P.Dim, IronUi.Bold, 0, 0, LEFT_W, 16)
	ui.Entries = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(0, LEFT_W, 1, -48),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, body)
	UiKit.list(ui.Entries, 8)
	ui.Coins = line(body, "", 12, GOLD, IronUi.Bold, 0, H - 94 - 20, LEFT_W, 16)
	-- Right: board one.
	local rx, rw = LEFT_W + 20, W - 40 - LEFT_W - 20
	line(body, "BOARD A KAIJU", 12, P.Dim, IronUi.Bold, rx, 0, rw, 16)
	ui.Home = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(rx, 22),
		Size = UDim2.fromOffset(rw, 150),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, body)
	UiKit.list(ui.Home, 6)
	local y = 182
	ui.StoreButton = button(body, "STORE", STORE, rx, y, (rw - 10) / 2, 34, function()
		state.Mode = "Store"
		draw()
	end)
	ui.TrainButton = button(body, "TRAIN", TRAIN, rx + (rw - 10) / 2 + 10, y, (rw - 10) / 2, 34, function()
		state.Mode = "Train"
		draw()
	end)
	ui.Stays = {}
	local chipW = (rw - 3 * 8) / 4
	for i, hours in Daycare.Stays do
		ui.Stays[hours] = button(body, hours .. " H", P.Edge, rx + (i - 1) * (chipW + 8), y + 44, chipW, 28, function()
			state.Hours = hours
			draw()
		end)
	end
	ui.Quote = line(body, "", 14, P.Text, IronUi.Bold, rx, y + 82, rw, 20)
	ui.Quote.TextWrapped = true
	ui.Note = line(body, "", 12, P.Dim, IronUi.Body, rx, y + 104, rw, 34)
	ui.Note.TextWrapped = true
	ui.Board = button(body, "BOARD", GOLD, rx + rw - 160, H - 94 - 40, 160, 38, function()
		if state.Pick and state.Can then
			act("DaycareBoard", state.Pick, state.Mode, if state.Mode == "Train" then state.Hours else nil)
		end
	end)
	ui.Board.TextSize = 15
	-- (the time left ticks down while it's open)
	RunService.Heartbeat:Connect(function()
		if not w.Gui.Enabled or not state.Data then
			return
		end
		local since = os.clock() - state.FetchedAt
		for _, row in ui.Ticking or {} do
			if row.Left > 0 then
				row.Label.Text = "TRAINING  ·  " .. clock(row.Left - since) .. " left"
			end
		end
	end)
	return w
end

local function entryCard(entry, coins: number)
	local card = new("Frame", { BackgroundColor3 = CARD, Size = UDim2.new(1, -8, 0, 92) }, ui.Entries)
	UiKit.round(card, 10)
	local element = GemConfig.ElementColors[entry.Element] or P.Text
	new("UIStroke", { Color = element, Thickness = 1, Transparency = 0.6 }, card)
	local name = line(card, entry.Name, 15, element:Lerp(P.Text, 0.3), IronUi.Heading, 12, 8, LEFT_W - 40, 18)
	name:SetAttribute("NoTranslate", true)
	local levels = if entry.Level > entry.From
		then string.format("Lv %d  →  Lv %d", entry.From, entry.Level)
		else string.format("Lv %d", entry.Level)
	line(card, levels, 12, if entry.Level > entry.From then TRAIN else P.Dim, IronUi.Bold, 12, 28, 140, 16)
	local training = entry.Mode == "Train" and not entry.Done
	local status = line(card, if training then "TRAINING  ·  " .. clock(entry.Left) .. " left" else "STORED", 11, if training then TRAIN else STORE, IronUi.Bold, 12, 46, LEFT_W - 40, 14)
	if training then
		table.insert(ui.Ticking, { Label = status, Left = entry.Left })
	end
	local fee = line(card, "Fee now: " .. commas(entry.Fee) .. " coins", 12, if coins >= entry.Fee then GOLD else P.Bad, IronUi.Bold, 12, 66, 190, 16)
	fee:SetAttribute("NoTranslate", nil)
	button(card, "COLLECT", GOLD, LEFT_W - 8 - 12 - 104, 50, 104, 32, function()
		act("DaycareCollect", entry.Key)
	end)
end

local function homeRow(kaiju)
	local picked = state.Pick == kaiju.Id
	local element = GemConfig.ElementColors[kaiju.Element] or P.Text
	local row = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = if picked then element:Lerp(CARD, 0.7) else CARD,
		Size = UDim2.new(1, -8, 0, 34),
	}, ui.Home)
	UiKit.round(row, 8)
	new("UIStroke", { Color = element, Thickness = if picked then 2 else 1, Transparency = if picked then 0 else 0.7 }, row)
	local name = line(row, kaiju.Name, 13, element:Lerp(P.Text, 0.3), IronUi.Bold, 12, 8, 220, 18)
	name:SetAttribute("NoTranslate", true)
	local level = line(row, "Lv " .. kaiju.Level .. (if kaiju.Down then "  ·  DOWN" else ""), 12, P.Dim, IronUi.Bold, 240, 8, 120, 18)
	level.TextXAlignment = Enum.TextXAlignment.Right
	level.Position = UDim2.new(1, -132, 0, 8)
	row.Activated:Connect(function()
		state.Pick = kaiju.Id
		draw()
	end)
end

draw = function()
	local data = state.Data
	if not data or not ui.Window then
		return
	end
	for _, holder in { ui.Entries, ui.Home } do
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	ui.Ticking = {}
	ui.LeftHead.Text = string.format("IN THE DAYCARE  ·  %d / %d", #data.Entries, data.Slots)
	ui.Coins.Text = "You have " .. commas(data.Coins or 0) .. " coins"
	for _, entry in data.Entries do
		entryCard(entry, data.Coins or 0)
	end
	if #data.Entries == 0 then
		line(ui.Entries, "None of yours here yet. Board one on the right.", 12, P.Dim, IronUi.Body, 0, 0, LEFT_W - 8, 18)
	end
	local picked
	for _, kaiju in data.Home do
		homeRow(kaiju)
		if kaiju.Id == state.Pick then
			picked = kaiju
		end
	end
	if #data.Home == 0 then
		line(ui.Home, "No kaiju at home: the team that's out and your support can't go in.", 12, P.Dim, IronUi.Body, 0, 0, 380, 18)
	end
	if not picked then
		state.Pick = nil
	end
	-- Store or train, and for how long.
	ui.StoreButton.BackgroundTransparency = if state.Mode == "Store" then 0 else 0.7
	ui.TrainButton.BackgroundTransparency = if state.Mode == "Train" then 0 else 0.7
	for hours, chip in ui.Stays do
		chip.Visible = state.Mode == "Train"
		chip.BackgroundColor3 = if state.Hours == hours then TRAIN else P.Edge
	end
	local full = #data.Entries >= data.Slots
	if not picked then
		ui.Quote.Text = if full then "The Daycare is full: collect one first." else "Pick a kaiju to board."
		ui.Note.Text = string.format("STORE: %d coins an hour (at most %s). TRAIN: from %d coins an hour, up to level %d.", Daycare.Store.PerHour, commas(Daycare.Store.Max), Daycare.trainRate(1), Daycare.Train.Cap)
	elseif state.Mode == "Train" then
		if picked.Level >= Daycare.Train.Cap then
			ui.Quote.Text = string.format("Level %d already: it can only be stored.", picked.Level)
			ui.Note.Text = string.format("The Daycare trains kaiju up to level %d.", Daycare.Train.Cap)
		else
			local level, fee = DaycareUI.project(picked.Level, state.Hours)
			ui.Quote.Text = string.format("Lv %d  →  Lv %d  ·  %s coins", picked.Level, level, commas(fee))
			ui.Note.Text = string.format("%d coins an hour while it trains, paid when you collect it. Left after that, it's kept at %d coins an hour.", Daycare.trainRate(picked.Level), Daycare.Store.PerHour)
		end
	else
		ui.Quote.Text = string.format("%d coins an hour  ·  at most %s", Daycare.Store.PerHour, commas(Daycare.Store.Max))
		ui.Note.Text = "Kept safe, out of your roster (it doesn't count toward your kaiju limit). Paid when you collect it."
	end
	local can = picked ~= nil and not full and not picked.Down and not (state.Mode == "Train" and picked.Level >= Daycare.Train.Cap)
	state.Can = can
	ui.Board.Active, ui.Board.AutoButtonColor = can, can
	ui.Board.BackgroundTransparency = if can then 0 else 0.6
	ui.Board.Text = if state.Mode == "Train" then "TRAIN" else "STORE"
end

function DaycareUI.open()
	local w = ui.Window or build()
	w.Gui.Enabled = true
	fetch()
end

return DaycareUI
