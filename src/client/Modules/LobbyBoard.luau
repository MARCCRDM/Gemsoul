--[[
	The lobby's board: the column of cards on the right.

	  DAILY STREAK      the week of growing rewards, and what tomorrow pays
	  DAILY CHALLENGES  today's three (Shared.DailyChallenges), their
	                    progress and coins, the all-three bonus, and when new
	                    ones arrive
	  NEXT UNLOCK       only while a mode is still locked
	  NEXT TASK         the next Tasks step with its hint; tapping it opens
	                    the Tasks window

	On a phone (compact) there's room for one card: the next task while the
	player is still learning (the first two Tasks pages), the challenges after.

	  LobbyBoard.mount(gui)        builds it in the lobby's ScreenGui
	  LobbyBoard.setCompact(on)    phone layout
	  LobbyBoard.setHidden(on)     out of the way (the PLAY menu is open)
	  LobbyBoard.refresh()         redraw from GemClient.Profile
	  LobbyBoard.Frame             the column (LobbyUI places it)
	  -> LobbyBoard.layout() returns the column's height (0: nothing to show)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.DailyChallenges)
local Training = require(ReplicatedStorage.Shared.TrainingRewards)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local LobbyBoard = {}

local WIDE, NARROW = 224, 212
local PANEL = Color3.fromRGB(14, 19, 29)
local EDGE = Color3.fromRGB(72, 88, 112)
local TRACK = Color3.fromRGB(40, 52, 70)
local GOLD = Color3.fromRGB(255, 202, 91)
local VIOLET = Color3.fromRGB(186, 140, 255)
local CYAN = Color3.fromRGB(103, 218, 232)
local DONE = Color3.fromRGB(78, 214, 146)

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
	UiKit.round(track, 3)
	local fill = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	UiKit.round(fill, 3)
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

-- A card: a dark glass panel, a coloured edge, a title and a note on the right.
local function card(name: string, order: number, accent: Color3, title: string)
	local frame = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(WIDE, 60),
	}, column)
	UiKit.round(frame, 10)
	new("UIStroke", { Color = EDGE, Thickness = 1, Transparency = 0.45 }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 205, 215)),
	}, frame)
	local edge = new("Frame", {
		Name = "Edge",
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(0, 3, 0, 18),
	}, frame)
	UiKit.round(edge, 2)
	local heading = label(frame, title, 11, accent)
	heading.Name = "Title"
	heading.Position, heading.Size = UDim2.fromOffset(14, 10), UDim2.new(1, -100, 0, 22)
	local note = label(frame, "", 11, P.Text, IronUi.Heading, Enum.TextXAlignment.Right)
	note.Name = "Note"
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position, note.Size = UDim2.new(1, -12, 0, 10), UDim2.fromOffset(78, 22)
	note.RichText = true
	return frame, note, heading
end

-- Daily streak ----------------------------------------------------------------------------------

local function buildStreak()
	local frame, note = card("Streak", 1, GOLD, "DAILY STREAK")
	local dots = {}
	for i = 1, Config.DailyStreakMax do
		local dot = new("Frame", {
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14 + (i - 1) * 28, 38),
			Size = UDim2.fromOffset(24, 20),
		}, frame)
		UiKit.round(dot, 5)
		local day = label(dot, tostring(i), 11, P.Dim, IronUi.Heading, Enum.TextXAlignment.Center)
		day.Size = UDim2.fromScale(1, 1)
		dots[i] = { Dot = dot, Label = day }
	end
	local footer = label(frame, "", 11, P.Dim, IronUi.Body)
	footer.RichText = true
	footer.Position, footer.Size = UDim2.fromOffset(14, 64), UDim2.new(1, -28, 0, 16)
	cards.Streak = {
		Frame = frame,
		Height = function()
			return 88
		end,
	}
	refreshers.Streak = function(profile)
		local streak = math.clamp((profile.Daily or {}).Streak or 0, 0, Config.DailyStreakMax)
		note.Text = if streak > 0 then "DAY " .. streak else ""
		for i, entry in dots do
			local done = i <= streak
			local nextDay = i == streak + 1
			entry.Dot.BackgroundColor3 = if done
				then Color3.fromRGB(44, 128, 82)
				elseif nextDay then Color3.fromRGB(226, 156, 44)
				else TRACK
			entry.Label.TextColor3 = if done or nextDay then Color3.new(1, 1, 1) else P.Dim
			entry.Label.Text = if done then "✓" else tostring(i)
		end
		local tomorrow = Config.DailyRewardBase
			+ Config.DailyRewardPerStreak * (math.min(streak + 1, Config.DailyStreakMax) - 1)
		footer.Text = string.format('Tomorrow  <font color="#FFCA5B"><b>+%d ◆</b></font>', tomorrow)
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
	local frame, note, heading = card("Challenges", 2, VIOLET, "DAILY CHALLENGES")
	local rows = {}
	for i = 1, 3 do
		local row = new("Frame", { Name = "Row" .. i, BackgroundTransparency = 1 }, frame)
		local check = new("Frame", {
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 1),
			Size = UDim2.fromOffset(18, 18),
		}, row)
		UiKit.round(check, 9)
		local tick = label(check, "", 11, Color3.fromRGB(10, 30, 20), IronUi.Heading, Enum.TextXAlignment.Center)
		tick.Size = UDim2.fromScale(1, 1)
		local name = label(row, "", 12, P.Text)
		name.Position = UDim2.fromOffset(40, 0)
		local reward = label(row, "", 11, GOLD, IronUi.Heading, Enum.TextXAlignment.Right)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position, reward.Size = UDim2.new(1, -12, 0, 0), UDim2.fromOffset(56, 20)
		local hint = label(row, "", 10, P.Dim, IronUi.Body)
		hint.Position = UDim2.fromOffset(40, 18)
		local track, fill = bar(row, VIOLET)
		local count = label(row, "", 10, P.Text, IronUi.Heading, Enum.TextXAlignment.Right)
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
	local bonus = label(frame, "", 11, P.Dim, IronUi.Heading)
	bonus.RichText = true
	local done = {}
	local drawn = false
	local function rowHeight()
		return if compact then 30 else 48
	end
	local function place()
		local h = rowHeight()
		local width = if compact then NARROW else WIDE
		for i, entry in rows do
			entry.Row.Position, entry.Row.Size = UDim2.fromOffset(0, 38 + (i - 1) * h), UDim2.new(1, 0, 0, h)
			entry.Name.Size = UDim2.new(1, -110, 0, 20)
			entry.Hint.Visible = not compact
			entry.Hint.Size = UDim2.new(1, -54, 0, 14)
			local barY = if compact then 22 else 38
			entry.Track.Position, entry.Track.Size = UDim2.fromOffset(40, barY), UDim2.fromOffset(width - 40 - 52, 4)
			entry.Count.Position, entry.Count.Size = UDim2.new(1, -12, 0, barY - 5), UDim2.fromOffset(40, 14)
		end
		bonus.Position, bonus.Size = UDim2.fromOffset(14, 40 + 3 * h), UDim2.new(1, -28, 0, 18)
	end
	cards.Challenges = {
		Frame = frame,
		Height = function()
			return 40 + 3 * rowHeight() + 26
		end,
		Place = place,
	}
	refreshers.Challenges = function(profile)
		local view = profile.Challenges
		if not (type(view) == "table" and type(view.List) == "table" and #view.List > 0) then
			return false
		end
		place()
		heading.Text = if compact then "CHALLENGES" else "DAILY CHALLENGES"
		local allDone = view.BonusDone == true
		note.Text = if allDone then '<font color="#4ED692">ALL DONE ✓</font>' else "↻ " .. untilReset()
		for i, entry in rows do
			local item = view.List[i]
			entry.Row.Visible = item ~= nil
			if item then
				local finished = item.Done == true
				entry.Name.Text = item.Name
				entry.Name.TextColor3 = if finished then P.Dim else P.Text
				entry.Hint.Text = item.Hint
				entry.Reward.Text = if finished then "PAID" else "+" .. item.Coins .. " ◆"
				entry.Reward.TextColor3 = if finished then DONE else GOLD
				entry.Count.Text = math.min(item.Count, item.Goal) .. "/" .. item.Goal
				entry.Check.BackgroundColor3 = if finished then DONE else TRACK
				entry.Tick.Text = if finished then "✓" else ""
				entry.Fill.BackgroundColor3 = if finished then DONE else VIOLET
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
					}, entry.Row)
					UiKit.round(flash, 6)
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
			then string.format('<font color="#4ED692">BONUS PAID  +%d ◆</font>', view.Bonus or Daily.Bonus)
			else string.format('ALL THREE  <font color="#FFCA5B">+%d ◆ BONUS</font>', view.Bonus or Daily.Bonus)
		drawn = true
		return true
	end
end

-- Next unlock (while a mode is locked) ------------------------------------------------------------

LobbyBoard.unlock = nil :: { Name: string, Left: number }?

local function buildUnlock()
	local frame, note = card("Unlock", 3, GOLD, "NEXT UNLOCK")
	local name = label(frame, "", 12, P.Text)
	name.Position, name.Size = UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 18)
	cards.Unlock = {
		Frame = frame,
		Height = function()
			return 60
		end,
	}
	refreshers.Unlock = function()
		local unlock = LobbyBoard.unlock
		if unlock then
			name.Text = string.upper(unlock.Name)
			note.Text = string.format("%d DUEL%s", unlock.Left, if unlock.Left == 1 then "" else "S")
		end
		return unlock ~= nil
	end
end

-- Next task -------------------------------------------------------------------------------------------

local function openTasks()
	local tasks = player.PlayerGui:FindFirstChild("TrainingRewards")
	local open = tasks and tasks:FindFirstChild("OpenTasks")
	if open and open:IsA("BindableEvent") then
		open:Fire()
	end
end

local learning = false -- still on the first Tasks pages (the phone shows the task then)

local function buildTask()
	local frame, note = card("NextTask", 4, CYAN, "NEXT TASK")
	local name = label(frame, "", 13, P.Text)
	name.Position, name.Size = UDim2.fromOffset(14, 32), UDim2.new(1, -28, 0, 18)
	local hint = label(frame, "", 11, P.Dim, IronUi.Body)
	hint.TextWrapped, hint.TextTruncate = true, Enum.TextTruncate.None
	hint.TextYAlignment = Enum.TextYAlignment.Top
	hint.Position, hint.Size = UDim2.fromOffset(14, 52), UDim2.new(1, -28, 0, 40)
	local track, fill = bar(frame, CYAN)
	track.Position, track.Size = UDim2.fromOffset(14, 96), UDim2.new(1, -72, 0, 5)
	local count = label(frame, "", 10, P.Text, IronUi.Heading, Enum.TextXAlignment.Right)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position, count.Size = UDim2.new(1, -12, 0, 90), UDim2.fromOffset(44, 16)
	frame.Activated:Connect(openTasks)
	IronUi.juice(frame, 1.02, 0.98)
	cards.NextTask = {
		Frame = frame,
		Height = function()
			return 112
		end,
	}
	local drawn = false
	refreshers.NextTask = function(profile)
		local state = profile.TrainingRewards or {}
		local paid = state.Paid or {}
		local nextTask = Training.nextTask(paid)
		local page = Training.currentPage(paid)
		learning = page == "Mining" or page == "Equipment"
		if nextTask then
			local progress = math.min(nextTask.Goal, (state.Counts or {})[nextTask.Event] or 0)
			name.Text = nextTask.Name
			hint.Text = nextTask.Hint
			note.Text = '<font color="#FFCA5B">+' .. nextTask.Coins .. " ◆</font>"
			count.Text = progress .. "/" .. nextTask.Goal
			setFill(fill, progress / nextTask.Goal, drawn)
			drawn = true
		end
		return nextTask ~= nil
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
	Training.closeFor(Config.Features or {})
	buildStreak()
	buildChallenges()
	buildUnlock()
	buildTask()
	GemClient.Changed:Connect(LobbyBoard.refresh)
	GemClient.ChallengesChanged:Connect(LobbyBoard.refresh)
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
	if on ~= compact then
		compact = on
		LobbyBoard.refresh() -- (the cards draw differently on a phone)
	end
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
	local width = if compact then NARROW else WIDE
	-- One card on a phone: the next task while learning, the challenges after.
	local phoneCard = if learning and has.NextTask then "NextTask" else "Challenges"
	local height, shown = 0, 0
	for key, entry in cards do
		local frame = entry.Frame
		frame.Visible = has[key] == true and (not compact or key == phoneCard)
		if entry.Place then
			entry.Place()
		end
		frame.Size = UDim2.fromOffset(width, entry.Height())
		if frame.Visible then
			height += entry.Height()
			shown += 1
		end
	end
	height += math.max(0, shown - 1) * 8
	column.Size = UDim2.fromOffset(width, math.max(height, 1))
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
