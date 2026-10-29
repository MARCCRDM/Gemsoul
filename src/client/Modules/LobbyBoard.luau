--[[
	The lobby's board: the column of cards on the right.

	  DAILY STREAK      the week of growing rewards, and what tomorrow pays
	  DAILY CHALLENGES  today's three (Shared.DailyChallenges), their
	                    progress and coins, the all-three bonus, and when new
	                    ones arrive
	  NEXT UNLOCK       only while a mode is still locked

	Each card is folded to a row: its title, one line of what matters
	(tomorrow's reward, the next challenge) and a thin bar. Tapping the
	streak or the challenges opens that card (one at a time; tap again to
	fold it). Tasks aren't on it: they open from the menu's TASKS tile.

	On a phone (compact) it's off the screen, which stays the game's: the
	challenges are the Tasks window's DAILY page there.

	  LobbyBoard.mount(gui)        builds it in the lobby's ScreenGui
	  LobbyBoard.setCompact(on)    phone (the board steps off the screen)
	  LobbyBoard.setHidden(on)     out of the way (the PLAY menu is open)
	  LobbyBoard.refresh()         redraw from GemClient.Profile (it redraws
	                               itself as the profile changes, while the
	                               lobby is on screen, and on showing it)
	  LobbyBoard.unlock            the mode being unlocked, or a function of
	                               the profile that says it (LobbyUI's)
	  LobbyBoard.Frame             the column (LobbyUI places it)
	  -> LobbyBoard.layout() returns the column's height (0: nothing to show)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.DailyChallenges)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new

local LobbyBoard = {}

local WIDE = 224
-- The Tasks window's look: graphite, one amber, Oswald for names and
-- numbers; what's done goes quiet instead of lighting up green.
local PANEL = Color3.fromRGB(17, 18, 21)
local RAISED = Color3.fromRGB(27, 28, 33)
local EDGE = Color3.fromRGB(42, 44, 50)
local TRACK = Color3.fromRGB(42, 44, 50)
local GOLD = Color3.fromRGB(255, 184, 64)
local GOLD_WASH = Color3.fromRGB(46, 36, 18)
local VIOLET = GOLD -- (one accent: the challenges are amber too)
local TEXT = Color3.fromRGB(236, 232, 224)
local MUTED = Color3.fromRGB(152, 149, 142)
local DONE = Color3.fromRGB(98, 98, 102) -- (done: faint, not green)
local DISPLAY = Enum.Font.Oswald

local column: Frame
local compact = false
local hidden = false
local cards = {} -- name -> { Frame, Height = function, Place = function? }
local refreshers = {} -- name -> function(profile): boolean (has something to show)
local has = {} -- name -> boolean, from the last refresh

local function label(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	font: Enum.Font?,
	align: Enum.TextXAlignment?
)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or IronUi.Heading,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function bar(parent: Instance, color: Color3)
	local track = new("Frame", { BackgroundColor3 = TRACK, BorderSizePixel = 0 }, parent)
	local fill = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	return track, fill
end

local function setFill(fill: Frame, share: number, animate: boolean)
	local target = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	if animate and fill.Size ~= target then
		TweenService
			:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target })
			:Play()
	else
		fill.Size = target
	end
end

-- How tall a card is folded to a row.
local ROW = 48
-- The card open (nil: all folded).
local expanded: string? = nil
local function mode(key: string): string
	return if expanded == key then "open" else "folded"
end

-- A card: a graphite plate, an amber edge, a title and a note on the right.
local function card(name: string, order: number, accent: Color3, title: string)
	local frame = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.06,
		LayoutOrder = order,
		Size = UDim2.fromOffset(WIDE, 60),
	}, column)
	UiKit.round(frame, 4)
	new("UIStroke", { Color = EDGE, Thickness = 1 }, frame)
	local edge = new("Frame", {
		Name = "Edge",
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(0, 3, 0, 18),
	}, frame)
	local heading = label(frame, title, 15, TEXT, DISPLAY)
	heading.Name = "Title"
	heading.Position, heading.Size = UDim2.fromOffset(14, 10), UDim2.new(1, -100, 0, 22)
	local note = label(frame, "", 14, MUTED, DISPLAY, Enum.TextXAlignment.Right)
	note.Name = "Note"
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position, note.Size = UDim2.new(1, -12, 0, 10), UDim2.fromOffset(78, 22)
	note.RichText = true
	-- (A "›" turned to point down or up: the font has no ▾ or ▴, they showed as
	-- empty boxes.)
	local chevron = label(frame, "›", 13, MUTED, IronUi.Heading, Enum.TextXAlignment.Center)
	chevron.Name = "Chevron"
	chevron.AnchorPoint = Vector2.new(1, 0)
	chevron.Size = UDim2.fromOffset(14, 22)
	return frame, note, heading, edge, chevron
end

-- The title row for a mode: the title, the note (left of the chevron), the
-- coloured edge and the chevron (down while folded, up while open).
local function placeTop(m: string, heading, note, edge, chevron)
	local y = if m == "open" then 10 else 5
	heading.Position, heading.Size = UDim2.fromOffset(14, y), UDim2.new(1, -96, 0, 22)
	note.Position = UDim2.new(1, -28, 0, y)
	edge.Position = UDim2.fromOffset(0, if m == "open" then 12 else 15)
	chevron.Position = UDim2.new(1, -8, 0, y)
	chevron.Rotation = if m == "open" then -90 else 90
end

-- Tapping a folded card opens it (and folds the one that was open).
local function toggle(frame: TextButton, key: string)
	IronUi.juice(frame, 1.02, 0.98)
	frame.Activated:Connect(function()
		expanded = if expanded == key then nil else key
		LobbyBoard.refresh()
		LobbyBoard.layout()
	end)
end

-- Daily streak ----------------------------------------------------------------------------------

-- A day's coins, short enough for its tile: 750, 1K, 1.25K, 2.25K.
local function shortCoins(n: number): string
	if n < 1000 then
		return tostring(n)
	end
	local text = string.format("%.2f", n / 1000):gsub("0+$", ""):gsub("%.$", "")
	return text .. "K"
end

local function dayCoins(day: number): number
	return Config.DailyRewardBase + Config.DailyRewardPerStreak * (math.min(day, Config.DailyStreakMax) - 1)
end

-- Open, the week as a reward track: a square plate a day with its coins
-- (collected ones go quiet with a tick, the next one has an amber rim), the
-- last one wide on an amber wash, the week's top prize. Four on the first row, the rest on the second.
local TILE, TILE_GAP = 46, 4
local function buildStreak()
	local frame, note, heading, edge, chevron = card("Streak", 1, GOLD, "DAILY STREAK")
	local tiles = {}
	for i = 1, Config.DailyStreakMax do
		local last = i == Config.DailyStreakMax
		local row, col = if i <= 4 then 0 else 1, if i <= 4 then i - 1 else i - 5
		local tile = new("Frame", {
			Name = "Day" .. i,
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14 + col * (TILE + TILE_GAP), 38 + row * (TILE + TILE_GAP)),
			Size = UDim2.fromOffset(if last then TILE * 2 + TILE_GAP else TILE, TILE),
		}, frame)
		UiKit.round(tile, 3)
		local rim = new("UIStroke", { Color = EDGE, Thickness = 1, Transparency = 1 }, tile)
		local day = label(tile, if last then "DAY " .. i .. "+" else "DAY " .. i, 8, MUTED, IronUi.Heading, Enum.TextXAlignment.Center)
		day.Position, day.Size = UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 10)
		local amount = label(tile, "", if last then 19 else 16, TEXT, DISPLAY, Enum.TextXAlignment.Center)
		amount.Position, amount.Size = UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 20)
		local coin = label(tile, "◆", 8, GOLD, IronUi.Heading, Enum.TextXAlignment.Center)
		coin.Position, coin.Size = UDim2.fromOffset(0, 33), UDim2.new(1, 0, 0, 9)
		tiles[i] = { Tile = tile, Rim = rim, Day = day, Amount = amount, Coin = coin, Last = last }
	end
	local footer = label(frame, "", 11, MUTED, IronUi.Body)
	footer.RichText = true
	-- Folded: what tomorrow pays, over the week as a bar.
	local week, weekFill = bar(frame, GOLD)
	week.Position, week.Size = UDim2.fromOffset(14, 41), UDim2.new(1, -28, 0, 3)
	local trackH = 2 * TILE + TILE_GAP
	local function place()
		local m = mode("Streak")
		placeTop(m, heading, note, edge, chevron)
		for _, entry in tiles do
			entry.Tile.Visible = m == "open"
		end
		week.Visible = m ~= "open"
		footer.Position = UDim2.fromOffset(14, if m == "open" then 38 + trackH + 6 else 21)
		footer.Size = UDim2.new(1, -28, 0, 16)
	end
	toggle(frame, "Streak")
	cards.Streak = {
		Frame = frame,
		Height = function()
			return if mode("Streak") == "open" then 38 + trackH + 30 else ROW
		end,
		Place = place,
	}
	refreshers.Streak = function(profile)
		local streak = math.clamp((profile.Daily or {}).Streak or 0, 0, Config.DailyStreakMax)
		setFill(weekFill, streak / Config.DailyStreakMax, false)
		note.Text = if streak > 0 then "DAY " .. streak else ""
		for i, entry in tiles do
			local done = i <= streak
			local nextDay = i == streak + 1
			entry.Tile.BackgroundColor3 = if done
				then PANEL
				elseif entry.Last or nextDay then GOLD_WASH
				else RAISED
			entry.Rim.Color = GOLD
			entry.Rim.Transparency = if nextDay then 0 else 1
			entry.Rim.Thickness = if nextDay then 1.5 else 1
			entry.Amount.Text = if done then "✓" else shortCoins(dayCoins(i))
			entry.Amount.TextColor3 = if done then DONE elseif nextDay or entry.Last then GOLD else TEXT
			entry.Day.TextColor3 = if done then DONE elseif nextDay then GOLD else MUTED
			entry.Coin.Visible = not done
		end
		footer.Text = string.format(
			'Tomorrow  <font color="#FFB840"><b>+%d ◆</b></font>',
			dayCoins(streak + 1)
		)
		return true
	end
end

-- Daily challenges ------------------------------------------------------------------------------

local function untilReset(): string
	local left = 86400 - os.time() % 86400
	local hours, minutes = left // 3600, (left % 3600) // 60
	return if hours > 0 then string.format("%dh %02dm", hours, minutes) else string.format("%dm", math.max(1, minutes))
end

local function buildChallenges()
	local frame, note, heading, edge, chevron = card("Challenges", 2, VIOLET, "DAILY CHALLENGES")
	local rows = {}
	for i = 1, 3 do
		local row = new("Frame", { Name = "Row" .. i, BackgroundTransparency = 1 }, frame)
		local check = new("Frame", {
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 1),
			Size = UDim2.fromOffset(18, 18),
		}, row)
		UiKit.round(check, 3)
		local tick = label(check, "", 11, MUTED, IronUi.Heading, Enum.TextXAlignment.Center)
		tick.Size = UDim2.fromScale(1, 1)
		local name = label(row, "", 12, TEXT)
		name.Position = UDim2.fromOffset(40, 0)
		local reward = label(row, "", 14, GOLD, DISPLAY, Enum.TextXAlignment.Right)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position, reward.Size = UDim2.new(1, -12, 0, 0), UDim2.fromOffset(56, 20)
		local hint = label(row, "", 10, MUTED, IronUi.Body)
		hint.Position = UDim2.fromOffset(40, 18)
		local track, fill = bar(row, VIOLET)
		local count = label(row, "", 10, MUTED, IronUi.Heading, Enum.TextXAlignment.Right)
		count.AnchorPoint = Vector2.new(1, 0)
		rows[i] = {
			Row = row,
			Check = check,
			Tick = tick,
			Name = name,
			Reward = reward,
			Hint = hint,
			Track = track,
			Fill = fill,
			Count = count,
		}
	end
	local bonus = label(frame, "", 11, MUTED, IronUi.Heading)
	bonus.RichText = true
	-- Folded: the next challenge still to do, over its
	-- bar (its count goes by the reward, so the name stays a string the
	-- Spanish table knows).
	local line = label(frame, "", 12, TEXT)
	local lineTrack, lineFill = bar(frame, VIOLET)
	local figure = label(frame, "", 11, MUTED, IronUi.Heading, Enum.TextXAlignment.Right)
	figure.RichText = true
	figure.AnchorPoint = Vector2.new(1, 0)
	figure.Position, figure.Size = UDim2.new(1, -12, 0, 21), UDim2.fromOffset(90, 16)
	local done = {}
	local drawn = false
	local function rowHeight()
		return 48
	end
	local function place()
		local h = rowHeight()
		local m = mode("Challenges")
		placeTop(m, heading, note, edge, chevron)
		bonus.Visible = m == "open"
		line.Visible, lineTrack.Visible, figure.Visible = m ~= "open", m ~= "open", m == "folded"
		line.Position, line.Size = UDim2.fromOffset(14, 21), UDim2.new(1, -110, 0, 16)
		lineTrack.Position, lineTrack.Size = UDim2.fromOffset(14, 41), UDim2.new(1, -28, 0, 3)
		for i, entry in rows do
			entry.Row.Position, entry.Row.Size = UDim2.fromOffset(0, 38 + (i - 1) * h), UDim2.new(1, 0, 0, h)
			entry.Name.Size = UDim2.new(1, -110, 0, 20)
			entry.Hint.Size = UDim2.new(1, -54, 0, 14)
			entry.Track.Position, entry.Track.Size = UDim2.fromOffset(40, 38), UDim2.fromOffset(WIDE - 40 - 52, 4)
			entry.Count.Position, entry.Count.Size = UDim2.new(1, -12, 0, 33), UDim2.fromOffset(40, 14)
		end
		bonus.Position, bonus.Size = UDim2.fromOffset(14, 40 + 3 * h), UDim2.new(1, -28, 0, 18)
	end
	cards.Challenges = {
		Frame = frame,
		Height = function()
			local m = mode("Challenges")
			return if m == "open" then 40 + 3 * rowHeight() + 26 else ROW
		end,
		Place = place,
	}
	toggle(frame, "Challenges")
	refreshers.Challenges = function(profile)
		local view = profile.Challenges
		if not (type(view) == "table" and type(view.List) == "table" and #view.List > 0) then
			return false
		end
		place()
		heading.Text = "DAILY CHALLENGES"
		local allDone = view.BonusDone == true
		-- (The time left on today's three; the ↻ it led with showed as a box.)
		note.Text = if allDone then '<font color="#9A9890">ALL DONE ✓</font>' else untilReset()
		local nextUp = nil
		for _, item in view.List do
			if item.Done ~= true then
				nextUp = item
				break
			end
		end
		figure.Text = ""
		if nextUp then
			line.Text = nextUp.Name
			figure.Text = string.format(
				'%d/%d  <font color="#FFB840">+%d ◆</font>',
				math.min(nextUp.Count, nextUp.Goal),
				nextUp.Goal,
				nextUp.Coins
			)
			setFill(lineFill, nextUp.Count / nextUp.Goal, drawn)
		else
			line.Text = "Today's challenges done"
			setFill(lineFill, 1, drawn)
		end
		local open = mode("Challenges") == "open"
		for i, entry in rows do
			local item = view.List[i]
			entry.Row.Visible = item ~= nil and open
			if item then
				local finished = item.Done == true
				entry.Name.Text = item.Name
				entry.Name.TextColor3 = if finished then MUTED else TEXT
				entry.Hint.Text = item.Hint
				entry.Reward.Text = if finished then "PAID" else "+" .. item.Coins .. " ◆"
				entry.Reward.TextColor3 = if finished then DONE else GOLD
				entry.Count.Text = math.min(item.Count, item.Goal) .. "/" .. item.Goal
				entry.Check.BackgroundColor3 = TRACK
				entry.Tick.Text = if finished then "✓" else ""
				entry.Fill.BackgroundColor3 = if finished then MUTED else VIOLET
				setFill(entry.Fill, item.Count / item.Goal, drawn)
				-- Just finished: a flash of gold over the row.
				local key = (view.Day or 0) .. ":" .. item.Id
				if finished and drawn and not done[key] then
					local flash = new("Frame", {
						BackgroundColor3 = GOLD,
						BackgroundTransparency = 0.55,
						BorderSizePixel = 0,
						Size = UDim2.new(1, -16, 1, 0),
						Position = UDim2.fromOffset(8, 0),
					}, if open then entry.Row else frame)
					UiKit.round(flash, 3)
					local fade = TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 })
					fade.Completed:Connect(function()
						flash:Destroy()
					end)
					fade:Play()
				end
				done[key] = finished
			end
		end
		bonus.Text = if allDone
			then string.format('<font color="#9A9890">BONUS PAID  +%d ◆</font>', view.Bonus or Daily.Bonus)
			else string.format('ALL THREE  <font color="#FFB840">+%d ◆ BONUS</font>', view.Bonus or Daily.Bonus)
		drawn = true
		return true
	end
end

-- Next unlock (while a mode is locked) ------------------------------------------------------------

type Unlock = { Name: string, Left: number }
LobbyBoard.unlock = nil :: (Unlock | (profile: any) -> Unlock?)?

local function buildUnlock()
	local frame, note, heading, edge, chevron = card("Unlock", 3, GOLD, "NEXT UNLOCK")
	local name = label(frame, "", 12, TEXT)
	name.Position, name.Size = UDim2.fromOffset(14, 21), UDim2.new(1, -28, 0, 18)
	cards.Unlock = {
		Frame = frame,
		Height = function()
			return ROW
		end,
		Place = function()
			placeTop(mode("Unlock"), heading, note, edge, chevron)
			chevron.Visible = false -- (nothing to open)
			note.Position = UDim2.new(1, -12, 0, 5)
		end,
	}
	refreshers.Unlock = function(profile)
		local unlock = LobbyBoard.unlock
		if type(unlock) == "function" then
			unlock = unlock(profile)
		end
		if unlock then
			name.Text = string.upper(unlock.Name)
			note.Text = string.format("%d DUEL%s", unlock.Left, if unlock.Left == 1 then "" else "S")
		end
		return unlock ~= nil
	end
end

-- The column ------------------------------------------------------------------------------------------

function LobbyBoard.mount(gui: ScreenGui)
	column = new("Frame", {
		Name = "Board",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDE, 400),
	}, gui)
	LobbyBoard.Frame = column
	UiKit.list(column, 8, false)
	buildStreak()
	buildChallenges()
	buildUnlock()
	-- Redrawn as the profile changes while the lobby is up, and as it shows
	-- (a fight syncs the profile and counts challenges with nothing to see).
	local function changed()
		if gui.Enabled then
			LobbyBoard.refresh()
		end
	end
	GemClient.Changed:Connect(changed)
	GemClient.ChallengesChanged:Connect(changed)
	gui:GetPropertyChangedSignal("Enabled"):Connect(changed)
	-- The reset countdown ticks over while the lobby is up.
	task.spawn(function()
		while column.Parent do
			task.wait(20)
			if gui.Enabled and GemClient.Profile then
				LobbyBoard.refresh()
			end
		end
	end)
	task.defer(LobbyBoard.refresh)
	return column
end

function LobbyBoard.setCompact(on: boolean)
	compact = on
	LobbyBoard.layout()
end

-- Out of the way (the PLAY menu is open).
function LobbyBoard.setHidden(on: boolean)
	hidden = on
	LobbyBoard.layout()
end

-- Sizes and shows the cards; returns the column's height (0 = nothing).
function LobbyBoard.layout(): number
	if not column then
		return 0
	end
	-- (Nothing on a phone: the screen there is the game's.)
	if compact then
		column.Visible = false
		return 0
	end
	local height, shown = 0, 0
	for key, entry in cards do
		local frame = entry.Frame
		frame.Visible = has[key] == true
		if entry.Place then
			entry.Place()
		end
		frame.Size = UDim2.fromOffset(WIDE, entry.Height())
		if frame.Visible then
			height += entry.Height()
			shown += 1
		end
	end
	height += math.max(0, shown - 1) * 8
	column.Size = UDim2.fromOffset(WIDE, math.max(height, 1))
	column.Visible = height > 0 and not hidden
	return height
end

function LobbyBoard.refresh()
	local profile = GemClient.Profile
	if not profile or not column then
		return
	end
	-- Whether each card has something to say (layout decides if it shows).
	for key, refresh in refreshers do
		has[key] = refresh(profile) == true
	end
	LobbyBoard.layout()
end

return LobbyBoard
