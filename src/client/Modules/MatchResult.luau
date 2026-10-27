--[[
	The card at the end of a 1v1 (Systems/Duels' "MatchEnd"), drawn like the
	window between its rounds (RoundPivot): flat, one accent in the result's
	colour, small captions over big figures, thin rules between the parts.

	  Header       RANKED 1V1 · FINAL over VICTORY / DEFEAT / DRAW, and the
	               rounds' score with who it was against on the right; the
	               rule under it runs down till you're sent back.
	  The figures  RATING (and the change), COINS (and any bonus), and how
	               it ended (rounds won, time's up, forfeit).
	  Tournament   a queued 1v1's arena tournament (Shared.SwingRestore):
	               ten segments, this run's wins lit, the wins that restore
	               swings marked with their share, and what this one did.
	  Win reward   a win's reward waiting (Shared.RewardRoll): pick one of
	               two pieces, it opens by itself; your rolls' band and the
	               next one.

	One panel in the middle, scaled to fit (phones included, clear of
	Roblox's buttons), every line sized to its words: nothing runs off.

	  MatchResult.mount(parent)     build it once (SocialUI's overlay)
	  MatchResult.show(info, seconds)   a "MatchEnd" payload; hides itself
	                                after `seconds`
	  MatchResult.hide()
	  MatchResult.visible() -> bool
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RewardRoll = require(ReplicatedStorage.Shared.RewardRoll)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local MatchResult = {}

local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new = IronUi.new

local W = 520 -- (px: the panel, before scaling)
local PAD = 20
local INNER = W - PAD * 2
local HEAD_H = 76 -- (the header, down to its rule)
local FIG_H = 76 -- (the figures' row)
local TOUR_H = 76 -- (the tournament)
local REWARD_H = 56 -- (the win reward)
local FOOT_H = 34

local panel, scale, ui
local state = { Until = 0, Span = 1, Height = 0, Token = 0, Shown = -1 }

local function label(parent, value: string, size: number, color: Color3, font: Enum.Font?, x: number, y: number, w: number, h: number)
	return new("TextLabel", {
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
end

local function rule(parent, y: number): Frame
	return new("Frame", {
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, y),
		Size = UDim2.fromOffset(INNER, 1),
	}, parent)
end

local function percent(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end

-- (clear of Roblox's buttons at the top of a phone's screen)
local function fit()
	local parent: any = panel and panel.Parent
	local screen = parent and parent.AbsoluteSize
	if screen and screen.X > 0 then
		local s = math.min(1, (screen.X - 24) / W, (screen.Y - 24) / state.Height)
		local room, at = UiKit.clearTopbar(screen, Vector2.new(W, state.Height) * s)
		scale.Scale = s * room
		panel.Position = at
	end
end

-- One of the figures: a caption over a big value, a small note under it.
local function figure(x: number, w: number)
	local cell = {}
	cell.Caption = label(panel, "", 10, P.Dim, BOLD, x, 0, w, 14)
	cell.Value = label(panel, "", 22, P.Text, HEADING, x, 0, w, 26)
	cell.Note = label(panel, "", 11, P.Dim, BOLD, x, 0, w, 14)
	cell.X = x
	return cell
end

local function placeFigure(cell, y: number)
	cell.Caption.Position = UDim2.fromOffset(cell.X, y)
	cell.Value.Position = UDim2.fromOffset(cell.X, y + 16)
	cell.Note.Position = UDim2.fromOffset(cell.X, y + 43)
end

function MatchResult.mount(parent: Instance)
	if panel then
		return
	end
	panel = new("Frame", {
		Name = "MatchResult",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.04,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, 300),
		Visible = false,
	}, parent)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.45 }, panel)
	scale = new("UIScale", {}, panel)
	ui = {}
	-- Header: the kind and the result on the left, the score on the right.
	ui.Accent = new("Frame", { BackgroundColor3 = P.Good, Position = UDim2.fromOffset(PAD, 18), Size = UDim2.fromOffset(4, 42) }, panel)
	UiKit.round(ui.Accent, 2)
	ui.Kind = label(panel, "", 11, P.Dim, BOLD, PAD + 14, 16, 260, 14)
	ui.Title = label(panel, "", 30, P.Good, HEADING, PAD + 13, 30, 280, 32)
	ui.Score = label(panel, "", 30, P.Text, HEADING, W - PAD - 160, 14, 160, 32)
	ui.Score.TextXAlignment = Enum.TextXAlignment.Right
	ui.Versus = label(panel, "", 12, P.Dim, BOLD, W - PAD - 230, 46, 230, 16)
	ui.Versus.TextXAlignment = Enum.TextXAlignment.Right
	-- The rule under the header runs down till you're sent back.
	local timeRule = rule(panel, HEAD_H - 2)
	timeRule.Size = UDim2.fromOffset(INNER, 2)
	ui.Time = new("Frame", { BackgroundColor3 = P.Good, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, timeRule)
	-- The figures, three across.
	local third = math.floor(INNER / 3)
	ui.Rating = figure(PAD, third - 12)
	ui.Coins = figure(PAD + third + 12, third - 12)
	ui.Ended = figure(PAD + third * 2 + 24, third - 24)
	ui.Rules = { rule(panel, 0), rule(panel, 0) }
	for _, r in ui.Rules do
		r.Size = UDim2.fromOffset(1, 40)
	end
	-- The tournament.
	ui.TourRule = rule(panel, 0)
	ui.TourCaption = label(panel, "ARENA TOURNAMENT", 10, P.Dim, BOLD, PAD, 0, 220, 14)
	ui.TourCount = label(panel, "", 10, P.Text, BOLD, W - PAD - 160, 0, 160, 14)
	ui.TourCount.TextXAlignment = Enum.TextXAlignment.Right
	ui.Track = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 0), Size = UDim2.fromOffset(INNER, 22) }, panel)
	ui.Segments = {}
	local gap = 4
	local segW = (INNER - gap * (SwingRestore.Tournament - 1)) / SwingRestore.Tournament
	for i = 1, SwingRestore.Tournament do
		local x = math.floor((i - 1) * (segW + gap))
		local seg = new("Frame", {
			BackgroundColor3 = P.Inset,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(math.floor(segW), 6),
		}, ui.Track)
		UiKit.round(seg, 3)
		local share = SwingRestore.Streak[i]
		local mark = nil
		if share then
			-- (a win that restores swings: its share under it)
			mark = label(ui.Track, percent(share), 9, P.Dim, BOLD, x, 9, math.floor(segW), 12)
			mark.TextXAlignment = Enum.TextXAlignment.Center
			mark.TextTruncate = Enum.TextTruncate.None
		end
		ui.Segments[i] = { Frame = seg, Mark = mark, Share = share }
	end
	ui.TourLine = label(panel, "", 12, P.Text, BOLD, PAD, 0, INNER, 16)
	-- The win reward.
	ui.RewardRule = rule(panel, 0)
	ui.Chip = new("Frame", { BackgroundColor3 = P.Gold, Position = UDim2.fromOffset(PAD, 0), Size = UDim2.fromOffset(94, 20) }, panel)
	UiKit.round(ui.Chip, 4)
	local chipText = label(ui.Chip, "WIN REWARD", 10, P.Ink, HEADING, 0, 0, 94, 20)
	chipText.TextXAlignment = Enum.TextXAlignment.Center
	chipText.TextTruncate = Enum.TextTruncate.None
	ui.RewardLine = label(panel, "", 12, P.Text, BOLD, PAD + 104, 0, INNER - 104, 20)
	ui.Ladder = label(panel, "", 11, P.Dim, BOLD, PAD, 0, INNER, 16)
	-- Foot.
	ui.Foot = label(panel, "", 11, P.Dim, BOLD, PAD, 0, INNER, 16)
	ui.Foot.TextXAlignment = Enum.TextXAlignment.Right
	panel:GetPropertyChangedSignal("Parent"):Connect(fit)
	local parentGui: any = parent
	pcall(function()
		parentGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if panel.Visible then
				fit()
			end
		end)
	end)
	UiKit.onTopbar(function()
		if panel.Visible then
			fit()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		local left = state.Until - os.clock()
		ui.Time.Size = UDim2.fromScale(math.clamp(left / state.Span, 0, 1), 1)
		-- (its words change once a second, not every frame)
		local whole = math.ceil(left - 0.5)
		if whole ~= state.Shown then
			state.Shown = whole
			ui.Foot.Text = if whole > 0 then string.format("Heading back in %d", whole) else "Heading back…"
		end
	end)
end

-- How it ended, in a word, and a note (Duels' reasons: Defeated, Time,
-- Forfeit, Left).
local function ended(info): (string, string)
	if info.Reason == "Left" or info.Reason == "Forfeit" then
		return "FORFEIT", if info.Won then "they gave up" else "you gave up"
	end
	if info.Reason == "Time" then
		return "TIME'S UP", if info.Draw then "dead even" else "more health left wins"
	end
	return "KNOCKOUT", if info.Rounds then "in the last round" else ""
end

function MatchResult.show(info, seconds: number)
	if not panel then
		return
	end
	local color = if info.Draw then P.Dim elseif info.Won then P.Good else P.Bad
	ui.Accent.BackgroundColor3, ui.Title.TextColor3, ui.Time.BackgroundColor3 = color, color, color
	ui.Title.Text = if info.Draw then "DRAW" elseif info.Won then "VICTORY" else "DEFEAT"
	local kind = if info.Ranked
		then "RANKED 1V1"
		elseif info.Rules and info.Rules.Name then string.upper(info.Rules.Name)
		else "FRIENDLY DUEL"
	ui.Kind.Text = kind .. "  ·  FINAL"
	local rounds = info.Rounds
	ui.Score.Text = if rounds then string.format("%d – %d", rounds.Mine, rounds.Theirs) else ""
	ui.Versus.Text = "vs " .. (info.Opponents or "?")
	ui.Versus.Position = UDim2.fromOffset(W - PAD - 230, if rounds then 46 else 30)
	ui.Versus:SetAttribute("NoTranslate", true) -- (a name)
	-- The figures.
	local y = HEAD_H + 12
	ui.Rating.Caption.Text = "RATING"
	if info.Ranked then
		ui.Rating.Value.Text = tostring(info.Rating or 0)
		local delta = info.Delta or 0
		ui.Rating.Note.Text = string.format("%s%d", if delta >= 0 then "+" else "", delta)
		ui.Rating.Note.TextColor3 = if delta > 0 then P.Good elseif delta < 0 then P.Bad else P.Dim
	else
		ui.Rating.Value.Text = "—"
		ui.Rating.Note.Text = "unrated"
		ui.Rating.Note.TextColor3 = P.Dim
	end
	ui.Coins.Caption.Text = "COINS"
	local bonus = (info.Bonus or 0) + (info.JoinBonus or 0)
	ui.Coins.Value.Text = string.format("+%d ◆", info.Coins or 0)
	ui.Coins.Note.Text = if (info.Bonus or 0) > 0
		then string.format("+%d fill-in", info.Bonus)
		elseif (info.JoinBonus or 0) > 0 then string.format("%d on joining", info.JoinBonus)
		else ""
	ui.Coins.Note.TextColor3 = if bonus > 0 then P.Gold else P.Dim
	ui.Ended.Caption.Text = "ENDED"
	ui.Ended.Value.Text, ui.Ended.Note.Text = ended(info)
	for _, cell in { ui.Rating, ui.Coins, ui.Ended } do
		placeFigure(cell, y)
	end
	local third = math.floor(INNER / 3)
	ui.Rules[1].Position = UDim2.fromOffset(PAD + third, y + 4)
	ui.Rules[2].Position = UDim2.fromOffset(PAD + third * 2 + 12, y + 4)
	y = HEAD_H + FIG_H
	-- The tournament.
	local t = info.Tournament
	for _, part in { ui.TourRule, ui.TourCaption, ui.TourCount, ui.Track, ui.TourLine } do
		part.Visible = t ~= nil
	end
	if t then
		ui.TourRule.Position = UDim2.fromOffset(PAD, y)
		ui.TourCaption.Position = UDim2.fromOffset(PAD, y + 12)
		ui.TourCount.Position = UDim2.fromOffset(W - PAD - 160, y + 12)
		ui.TourCount.Text = if t.Champion then "WON" else string.format("WIN %d / %d", t.Win, t.Of)
		ui.Track.Position = UDim2.fromOffset(PAD, y + 32)
		for i, seg in ui.Segments do
			local lit = i <= t.Win
			seg.Frame.BackgroundColor3 = if lit then (if seg.Share then P.Gold else P.Good) else P.Inset
			if seg.Mark then
				seg.Mark.TextColor3 = if lit then P.Gold else P.Dim
			end
		end
		local nextShare = percent(t.NextShare or 0)
		ui.TourLine.Position = UDim2.fromOffset(PAD, y + 54)
		ui.TourLine.TextColor3 = if t.Champion or t.Swings > 0 then P.Good else P.Text
		ui.TourLine.Text = if t.Champion
			then string.format("Tournament won  ·  +%d swings restored", t.Swings)
			elseif t.Swings > 0 then string.format("+%d swings restored", t.Swings)
			elseif t.Share > 0 then "Your swings are already full"
			elseif info.Won and not t.Counted then "Same opponent twice running: this win doesn't count"
			elseif info.Won then string.format("Win %d restores %s of your swings", t.NextAt, nextShare)
			else string.format("Run over  ·  your next win restores %s", nextShare)
		y += TOUR_H
	end
	-- The win reward and the rolls' band.
	local plays = info.Plays
	for _, part in { ui.RewardRule, ui.Chip, ui.RewardLine, ui.Ladder } do
		part.Visible = plays ~= nil
	end
	if plays then
		local band, _, nextBand = RewardRoll.band(plays)
		ui.RewardRule.Position = UDim2.fromOffset(PAD, y)
		ui.Chip.Visible = info.WinReward == true
		local text = if info.WinReward then "Pick one of two pieces: it opens in a moment" else ""
		ui.RewardLine.Text = text
		ui.RewardLine.Position = UDim2.fromOffset(PAD + 104, y + 12)
		ui.Chip.Position = UDim2.fromOffset(PAD, y + 12)
		ui.Ladder.Text = string.format("%s  ·  %d 1v1s played", string.upper(band.Name), plays)
			.. if nextBand then string.format("  ·  %s at %d: rarer rolls", string.upper(nextBand.Name), nextBand.Plays) else ""
		if info.WinReward then
			ui.Ladder.Position = UDim2.fromOffset(PAD, y + 36)
			y += REWARD_H
		else
			ui.Ladder.Position = UDim2.fromOffset(PAD, y + 12)
			y += REWARD_H - 22
		end
	end
	ui.Foot.Position = UDim2.fromOffset(PAD, y + 6)
	state.Height = y + FOOT_H
	panel.Size = UDim2.fromOffset(W, state.Height)
	state.Span = math.max(0.5, seconds)
	state.Until = os.clock() + state.Span
	state.Token += 1
	state.Shown = -1
	local token = state.Token
	panel.Visible = true
	fit()
	task.delay(state.Span, function()
		if state.Token == token then
			panel.Visible = false
		end
	end)
end

function MatchResult.hide()
	if panel then
		state.Token += 1
		panel.Visible = false
	end
end

function MatchResult.visible(): boolean
	return panel ~= nil and panel.Visible
end

return MatchResult
