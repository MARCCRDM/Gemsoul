--[[
	The window between the rounds of a Ranked 1v1 (Systems/Duels' pivot):
	the round's result and the score, WHAT HIT YOU (the damage you took this
	round by element, else their gear's elements, Shared.CounterGear), and
	YOUR NEXT ROUND: the round's loser picks KEEP MY GEAR or AUTO COUNTER
	(the armor answer to what hit them: each change listed, and what it does
	to the damage you take), the winner just gets READY. A tap on an option
	marks it (it's worn if the window runs out on it); LOCK IN locks it.

	One panel, in the middle, scaled to fit (phones included, clear of
	Roblox's buttons). Flat: no glow, no gradients, a thin rule under the
	header that runs down with the time left.

	  RoundPivot.mount(parent)       build it once (SocialUI's overlay)
	  RoundPivot.show(info)          a "Round" { Phase = "Pivot" } payload
	  RoundPivot.theyLocked()        the other side locked in
	  RoundPivot.hide()
	  RoundPivot.visible() -> bool
	  RoundPivot.tick(now)           the timer (server time)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local RoundPivot = {}

local P = IronUi.Colors
local BOLD, HEADING, BODY = IronUi.Bold, IronUi.Heading, IronUi.Body
local new = IronUi.new

local W, H = 600, 344 -- (px: the panel, before scaling)
local PAD = 18
local LEFT_W = 236 -- (px: WHAT HIT YOU)
local RIGHT_X = PAD + LEFT_W + 22
local RIGHT_W = W - RIGHT_X - PAD
local BODY_Y = 78
local FOOT_Y = H - 50

local PLAIN = Color3.fromRGB(120, 132, 156) -- (hits with no element)
local CHOSEN = Color3.fromRGB(30, 36, 56)

local panel, scale, ui
local state = { Ends = 0, Span = 1, Locked = false, Pick = nil, Info = nil }

local function label(parent, value: string, size: number, color: Color3, font: Enum.Font?, x: number, y: number, w: number, h: number)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or BOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	return l
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function elementName(element: string?): string
	return if element then GemConfig.elementName(element) else ""
end

local function percent(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

-- (clear of Roblox's buttons at the top of a phone's screen)
local function fit()
	local parent: any = panel and panel.Parent
	local screen = parent and parent.AbsoluteSize
	if screen and screen.X > 0 then
		local s = math.min(1, (screen.X - 24) / W, (screen.Y - 24) / H)
		local room, at = UiKit.clearTopbar(screen, Vector2.new(W, H) * s)
		scale.Scale = s * room
		panel.Position = at
	end
end

function RoundPivot.mount(parent: Instance)
	if panel then
		return
	end
	panel = new("Frame", {
		Name = "RoundPivot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.04,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		Visible = false,
	}, parent)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.45 }, panel)
	scale = new("UIScale", {}, panel)
	ui = {}
	-- Header: the round and its result on the left, the score on the right.
	ui.Accent = new("Frame", { BackgroundColor3 = P.Gold, Position = UDim2.fromOffset(PAD, 18), Size = UDim2.fromOffset(4, 38) }, panel)
	UiKit.round(ui.Accent, 2)
	ui.Round = label(panel, "", 11, P.Dim, BOLD, PAD + 14, 16, 200, 14)
	ui.Result = label(panel, "", 26, P.Text, HEADING, PAD + 13, 30, 260, 28)
	ui.Score = label(panel, "", 26, P.Text, HEADING, W - PAD - 180, 16, 180, 28)
	ui.Score.TextXAlignment = Enum.TextXAlignment.Right
	ui.Sub = label(panel, "", 11, P.Dim, BOLD, W - PAD - 220, 44, 220, 14)
	ui.Sub.TextXAlignment = Enum.TextXAlignment.Right
	-- The rule under the header runs down with the time left.
	local rule = new("Frame", {
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(PAD, 66),
		Size = UDim2.fromOffset(W - PAD * 2, 2),
	}, panel)
	ui.Time = new("Frame", { BackgroundColor3 = P.Gold, Size = UDim2.fromScale(1, 1) }, rule)
	-- WHAT HIT YOU
	label(panel, "WHAT HIT YOU", 10, P.Dim, BOLD, PAD, BODY_Y, 150, 14)
	ui.Source = label(panel, "", 10, P.Dim, BOLD, PAD + LEFT_W - 110, BODY_Y, 110, 14)
	ui.Source.TextXAlignment = Enum.TextXAlignment.Right
	ui.Hits = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, BODY_Y + 22),
		Size = UDim2.fromOffset(LEFT_W, 150),
	}, panel)
	ui.Tip = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = "",
		TextSize = 11,
		TextColor3 = P.Dim,
		Font = BODY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(PAD, FOOT_Y - 40),
		Size = UDim2.fromOffset(LEFT_W, 30),
	}, panel)
	new("Frame", {
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.7,
		Position = UDim2.fromOffset(RIGHT_X - 11, BODY_Y),
		Size = UDim2.fromOffset(1, FOOT_Y - BODY_Y - 12),
	}, panel)
	-- YOUR NEXT ROUND
	label(panel, "YOUR NEXT ROUND", 10, P.Dim, BOLD, RIGHT_X, BODY_Y, RIGHT_W, 14)
	ui.Options = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(RIGHT_X, BODY_Y + 22),
		Size = UDim2.fromOffset(RIGHT_W, FOOT_Y - BODY_Y - 34),
	}, panel)
	-- Footer: the opponent, then LOCK IN.
	ui.Status = label(panel, "", 11, P.Dim, BOLD, PAD, FOOT_Y + 8, 300, 20)
	ui.Lock = new("TextButton", {
		Name = "LockIn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(W - PAD, FOOT_Y),
		Size = UDim2.fromOffset(150, 34),
		Text = "LOCK IN",
		TextSize = 14,
		Font = HEADING,
		TextColor3 = P.Frame,
		BackgroundColor3 = P.Gold,
		AutoButtonColor = true,
	}, panel)
	UiKit.round(ui.Lock, 6)
	ui.Lock.Activated:Connect(function()
		if state.Locked or not state.Info then
			return
		end
		state.Locked = true
		RoundPivot.draw()
		local pick = state.Pick
		task.spawn(function()
			local response = GemClient.request("DuelPivot", pick)
			if not response or not response.Ok then
				state.Locked = false
				ui.Status.Text = response and response.Message or "Couldn't lock in. Try again."
				RoundPivot.draw()
			end
		end)
	end)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UiKit.onTopbar(fit)
end

-- One element's line: its name and share, and a bar of that share.
local function hitRow(y: number, name: string, share: number, color: Color3, note: string?, noteColor: Color3?)
	label(ui.Hits, name, 12, color, BOLD, 0, y, 92, 16)
	local value = label(ui.Hits, percent(share), 12, P.Text, BOLD, LEFT_W - 60, y, 60, 16)
	value.TextXAlignment = Enum.TextXAlignment.Right
	if note then
		local tag = label(ui.Hits, note, 10, noteColor or P.Bad, BOLD, LEFT_W - 140, y, 76, 16)
		tag.TextXAlignment = Enum.TextXAlignment.Right
	end
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		Position = UDim2.fromOffset(0, y + 19),
		Size = UDim2.fromOffset(LEFT_W, 5),
	}, ui.Hits)
	UiKit.round(track, 2)
	local fill = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(math.clamp(share, 0.02, 1), 1),
	}, track)
	UiKit.round(fill, 2)
end

local function drawHits(info)
	IronUi.clear(ui.Hits)
	local threat = info.Threat or {}
	local shares = threat.Shares or {}
	ui.Source.Text = if threat.Source == "Taken" then "THIS ROUND" elseif threat.Source == "Gear" then "THEIR GEAR" else ""
	-- (What each element did to you, when the counter was worked out for you.)
	local mult = {}
	for _, line in info.Counter and info.Counter.Lines or {} do
		mult[line.Element] = line.Before
	end
	local plain = if threat.Source == "Taken" then threat.Plain or 0 else 0
	local elemental = 1 - plain
	local y = 0
	for i, entry in shares do
		if i > 4 then
			break
		end
		local m = mult[entry.Element]
		local note = if m and m > 1.001 then "WEAK · " .. percent(m) elseif m and m < 0.999 then "RESIST · " .. percent(m) else nil
		hitRow(
			y,
			string.upper(elementName(entry.Element)),
			entry.Share * elemental,
			GemConfig.ElementColors[entry.Element] or P.Text,
			note,
			if m and m < 0.999 then P.Good else P.Bad
		)
		y += 34
	end
	if plain > 0.005 then
		hitRow(y, "NO ELEMENT", plain, PLAIN)
		y += 34
	end
	if y == 0 then
		local none = label(ui.Hits, "No hits landed on you this round.", 12, P.Dim, BODY, 0, 0, LEFT_W, 16)
		none.TextTruncate = Enum.TextTruncate.None
	end
	ui.Tip.Text = if threat.TheirMain and threat.TheirWeak
		then string.format(
			"Their armor is mostly %s: %s hits it for 125%%.",
			elementName(threat.TheirMain),
			elementName(threat.TheirWeak)
		)
		else ""
end

-- An option: a radio row (title over a line), marked or not.
local function option(y: number, key: any, title: string, sub: string, enabled: boolean, accent: Color3?)
	local chosen = state.Pick == key
	local row = new("TextButton", {
		Name = "Option",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if chosen then CHOSEN else P.Inset,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(RIGHT_W, 46),
	}, ui.Options)
	UiKit.round(row, 6)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if chosen then P.Gold else P.Edge,
		Thickness = if chosen then 1.5 else 1,
		Transparency = if chosen then 0 elseif enabled then 0.55 else 0.8,
	}, row)
	local dot = new("Frame", {
		BackgroundColor3 = if chosen then P.Gold else P.Frame,
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(14, 14),
	}, row)
	UiKit.round(dot, 7)
	new("UIStroke", { Color = if chosen then P.Gold else P.Edge, Thickness = 1.5 }, dot)
	local head = label(row, title, 13, if enabled then (accent or P.Text) else P.Dim, HEADING, 36, 6, RIGHT_W - 44, 18)
	head.TextTransparency = if enabled then 0 else 0.3
	local line = label(row, sub, 11, P.Dim, BODY, 36, 24, RIGHT_W - 44, 16)
	line.TextTransparency = if enabled then 0 else 0.25
	row.Activated:Connect(function()
		if not enabled or state.Locked or state.Pick == key then
			return
		end
		state.Pick = key
		RoundPivot.draw()
		-- (Marked, not locked: worn if the window runs out on it.)
		task.spawn(GemClient.request, "DuelPivot", key, true)
	end)
	return row
end

-- What the counter changes, a line each.
local function changes(y: number, plan)
	local lines = {}
	for _, step in plan.Gear or {} do
		table.insert(lines, { Slot = step.Slot, Text = (step.FromName or "—") .. "  →  " .. (step.Name or "") })
	end
	for _, step in plan.Gems or {} do
		local from = if step.From then elementName(step.From) .. " gem" else "empty"
		table.insert(lines, { Slot = step.Slot, Text = from .. "  →  " .. elementName(step.Element) .. " gem", Color = GemConfig.ElementColors[step.Element] })
	end
	for i, line in lines do
		if i > 4 then
			label(ui.Options, string.format("+%d more", #lines - 4), 11, P.Dim, BODY, 0, y, RIGHT_W, 16)
			y += 17
			break
		end
		local def = Slots.Definitions[line.Slot]
		label(ui.Options, string.upper(def and def.Label or line.Slot), 10, P.Dim, BOLD, 0, y, 74, 16)
		label(ui.Options, line.Text, 11, line.Color or P.Text, BOLD, 78, y, RIGHT_W - 78, 16)
		y += 17
	end
	label(ui.Options, "Your sword and your Q, E and R stay as they are.", 10, P.Dim, BODY, 0, y + 2, RIGHT_W, 14)
end

function RoundPivot.draw()
	local info = state.Info
	if not info then
		return
	end
	IronUi.clear(ui.Options)
	local counter = info.Counter
	local loser = info.Winner ~= "You"
	if not loser then
		-- The round's winner keeps their gear: READY only.
		local card = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.fromOffset(RIGHT_W, 64) }, ui.Options)
		UiKit.round(card, 6)
		label(card, "YOU KEEP YOUR GEAR", 13, P.Text, HEADING, 14, 10, RIGHT_W - 28, 18)
		local line = label(card, "You took the round. They may counter what hit them.", 11, P.Dim, BODY, 14, 30, RIGHT_W - 28, 28)
		line.TextWrapped, line.TextYAlignment, line.TextTruncate = true, Enum.TextYAlignment.Top, Enum.TextTruncate.None
	else
		local y = 0
		option(y, "Keep", "KEEP MY GEAR", "Go again exactly as you are", true)
		y += 54
		local can = info.CanCounter == true and counter ~= nil
		local top = counter and counter.Lines and counter.Lines[1]
		local sub
		if can and top then
			sub = string.format(
				"%s damage on you: %s → %s",
				elementName(top.Element),
				percent(top.Before),
				percent(top.After)
			)
		else
			sub = counter and counter.Note or "Nothing to counter this round."
		end
		local title = if counter and counter.Element
			then "AUTO COUNTER  ·  " .. string.upper(elementName(counter.Element))
			else "AUTO COUNTER"
		option(y, "Counter", title, sub, can)
		y += 54
		-- The roster on: the loser may switch miners too.
		local roster = GemClient.Profile and GemClient.Profile.Miners
		if info.CanSwap and MinerRoster.Enabled and roster then
			for index = 1, MinerRoster.Count do
				local miner = roster.Slots[index]
				if miner and index ~= roster.Active then
					local level = Tree.level(miner.Augments and miner.Augments.XP or 0)
					option(y, index, string.format("MINER %d  ·  LV %d", index, level), "Switch to this miner", true)
					y += 54
				end
			end
		end
		if state.Pick == "Counter" and can then
			changes(y + 2, counter)
		end
	end
	ui.Lock.Text = if state.Locked then "LOCKED IN" elseif loser then "LOCK IN" else "READY"
	ui.Lock.BackgroundColor3 = if state.Locked then P.Slot else P.Gold
	ui.Lock.TextColor3 = if state.Locked then P.Dim else P.Frame
	ui.Lock.AutoButtonColor = not state.Locked
end

function RoundPivot.show(info)
	if not panel then
		return
	end
	state.Info, state.Locked, state.Pick = info, false, "Keep"
	state.Ends = info.Ends or 0
	state.Span = math.max(1, (info.Ends or 0) - workspace:GetServerTimeNow())
	local color = if info.Winner == "You" then P.Good elseif info.Winner == "Them" then P.Bad else P.Dim
	ui.Accent.BackgroundColor3, ui.Time.BackgroundColor3 = color, color
	ui.Round.Text = string.format("ROUND %d", info.Round or 1)
	ui.Result.Text = if info.Winner == "You" then "WON" elseif info.Winner == "Them" then "LOST" else "DRAW"
	ui.Result.TextColor3 = color
	local wins = info.Wins or { Mine = 0, Theirs = 0 }
	ui.Score.Text = string.format("%d  –  %d", wins.Mine, wins.Theirs)
	ui.Status.Text = if info.Winner == "You" then "Opponent: choosing…" else "Opponent: getting ready…"
	drawHits(info)
	RoundPivot.draw()
	RoundPivot.tick(workspace:GetServerTimeNow())
	fit()
	panel.Visible = true
end

function RoundPivot.theyLocked()
	if ui then
		ui.Status.Text = "Opponent: LOCKED IN"
	end
end

function RoundPivot.hide()
	if panel then
		panel.Visible = false
	end
	state.Info = nil
end

function RoundPivot.visible(): boolean
	return panel ~= nil and panel.Visible
end

function RoundPivot.tick(now: number)
	if not panel or not panel.Visible then
		return
	end
	local left = state.Ends - now
	ui.Sub.Text = string.format("FIRST TO %d  ·  NEXT ROUND %s", Matchmaking.Rounds.ToWin, clock(left))
	ui.Time.Size = UDim2.fromScale(math.clamp(left / state.Span, 0, 1), 1)
end

return RoundPivot
