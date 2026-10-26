--[[
	The lobby feels lived in:

	  OUTPOST LIVE   a short feed at the top of the screen: Rare-or-better
	                 gems as they're mined (Remotes.MiningRoll), duel results
	                 (Social "Feed") and miners joining the server. Three
	                 lines at most, each gone after a few seconds.
	  Welcome back   the first time the lobby shows in a session, a banner
	                 for the daily reward the server just paid (the player's
	                 DailyReward and DailyStreak attributes): the streak, the
	                 coins, tomorrow's reward, and today's challenges.

	  LobbyFeed.mount(gui)        builds both in the lobby's ScreenGui
	  LobbyFeed.setCompact(on, span?)  phone layout, fitted to the gap it's
	                                   given ({ X, W }) between the corners;
	                                   there, the feed steps aside while
	                                   your loot card has the top middle
	                                   (MobileLayout.claimTop)
	  LobbyFeed.push(icon, text, color?)   adds a line (rich text)
	  LobbyFeed.welcome()         shows the banner if there's a reward to show
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local LobbyFeed = {}

local LIFETIME, MAX_LINES = 7, 3
local GOLD = Color3.fromRGB(255, 202, 91)

local root: ScreenGui
local stack: Frame
local compact = false
local lines = {}
local pushed = 0

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function tierName(tier: string): string
	return (string.gsub(tier, "(%l)(%u)", "%1 %2"))
end

local function drop(entry)
	local index = table.find(lines, entry)
	if index then
		table.remove(lines, index)
	end
	if entry.Frame.Parent then
		local fade = TweenService:Create(entry.Frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		for _, child in entry.Frame:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end
		fade.Completed:Connect(function()
			entry.Frame:Destroy()
		end)
		fade:Play()
	end
end

function LobbyFeed.push(icon: string, text: string, color: Color3?)
	if not stack or not root.Enabled then
		return
	end
	local accent = color or P.Teal
	pushed += 1
	local frame = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 22),
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = pushed,
	}, stack)
	UiKit.round(frame, 13)
	new("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.55 }, frame)
	local badge = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = icon,
		TextSize = 13,
		Font = IronUi.Heading,
		TextColor3 = accent,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(18, 26),
	}, frame)
	badge.Name = "Icon"
	local words = new("TextLabel", {
		BackgroundTransparency = 1,
		RichText = true,
		Text = text,
		TextSize = 12,
		Font = IronUi.Body,
		TextColor3 = P.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -40, 1, 0),
	}, frame)
	words.Name = "Words"
	local scale = new("UIScale", { Scale = 0.85 }, frame)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	local entry = { Frame = frame }
	table.insert(lines, entry)
	while #lines > MAX_LINES do
		drop(lines[1])
	end
	task.delay(LIFETIME, function()
		drop(entry)
	end)
end

-- What comes in -------------------------------------------------------------------------------------

local function onMiningRoll(packet)
	if type(packet) ~= "table" or type(packet.Gem) ~= "table" then
		return
	end
	local tier = packet.Gem.Tier
	local rank = GemConfig.TierRank[tier] or 0
	if rank < 3 then
		return
	end
	local color = GemConfig.TierColors[tier] or P.Text
	local who = if packet.MinerId == player.UserId then "You" else escape(tostring(packet.MinerName or "A miner"))
	local element = GemConfig.elementName(tostring(packet.Gem.Element))
	LobbyFeed.push(
		"◆",
		string.format(
			'<b>%s</b> found a <font color="%s"><b>%s</b></font> %s gem',
			who,
			hex(color),
			tierName(tier),
			escape(element)
		),
		color
	)
end

local function onSocial(kind, text)
	if kind == "Feed" and type(text) == "string" then
		local plain = string.gsub(text, "^⚔%s*", "")
		LobbyFeed.push("⚔", escape(plain), Color3.fromRGB(240, 110, 110))
	end
end

-- The welcome banner ------------------------------------------------------------------------------

local shownWelcome = false

function LobbyFeed.welcome()
	if shownWelcome or not root or not root.Enabled then
		return
	end
	local reward = player:GetAttribute("DailyReward")
	local streak = player:GetAttribute("DailyStreak")
	if type(reward) ~= "number" or type(streak) ~= "number" then
		return
	end
	shownWelcome = true
	-- (The Tasks window stays shut while it's up: TrainingRewards.client.)
	root:SetAttribute("WelcomeOpen", true)
	-- Its own layer, over the whole HUD (the kaiju card, FIGHT, the toasts'
	-- neighbours): it dims everything under it, not just the lobby's.
	local layer = UiKit.gui("Welcome", 45)
	layer.IgnoreGuiInset = true
	local shade = new("TextButton", {
		Name = "Welcome",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, layer)
	-- The week's track: every day's coins, today lit, the days behind ticked,
	-- and day 7 holding (it pays the same every day after, while the streak
	-- lasts). A missed day starts it again at day 1 (PlayerData.claimDaily).
	local W, H, PAD = 500, 318, 22
	local banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Color3.fromRGB(14, 18, 30),
		ZIndex = 41,
	}, shade)
	UiKit.round(banner, 14)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.45 }, banner)
	-- A thin gold light along the top edge.
	local accent = new("Frame", {
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -48, 0, 2),
		BackgroundColor3 = GOLD,
		ZIndex = 42,
	}, banner)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, accent)
	local scale = new("UIScale", { Scale = 0.8 }, banner)
	-- Fitted to the whole screen, and clear of Roblox's buttons and DEV up
	-- in the top bar's strip (the layer draws over it).
	local fit, open = 1, false
	local function place()
		local screen = layer.AbsoluteSize
		if screen.Y <= 0 then
			screen = root.AbsoluteSize
		end
		local s = math.min(1, (screen.X - 24) / W, (screen.Y - 24) / H)
		local room, at = UiKit.clearTopbar(screen, Vector2.new(W * s, H * s))
		fit = s * room
		banner.Position = at
		if open then
			scale.Scale = fit
		end
	end
	place()
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local stopTopbar = UiKit.onTopbar(place)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit })
		:Play()
	open = true
	local function line(
		parent: Instance,
		value: string,
		size: number,
		color: Color3,
		font: Enum.Font,
		x: number,
		y: number,
		w: number,
		h: number,
		align: Enum.TextXAlignment?
	): TextLabel
		return new("TextLabel", {
			BackgroundTransparency = 1,
			RichText = true,
			Text = value,
			TextSize = size,
			Font = font,
			TextColor3 = color,
			TextXAlignment = align or Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			ZIndex = 43,
		}, parent)
	end
	local gold = "FFCA5B" -- (GOLD)
	local maxDay = Config.DailyStreakMax
	local day = math.clamp(streak, 1, maxDay)
	local function coins(d: number): number
		return Config.DailyRewardBase + Config.DailyRewardPerStreak * (math.min(d, maxDay) - 1)
	end
	-- Header: what this is and who it's for, the streak on the right.
	local first = streak <= 1
	line(banner, "DAILY REWARD", 22, P.Text, IronUi.Heading, PAD, 18, 300, 26)
	line(
		banner,
		string.format(if first then "Welcome, %s" else "Welcome back, %s", escape(player.DisplayName)),
		13,
		P.Dim,
		IronUi.Body,
		PAD,
		44,
		300,
		18
	)
	local pill = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 20),
		Size = UDim2.fromOffset(128, 24),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.88,
		Text = if streak <= 1 then "NEW STREAK" else string.format("DAY %d STREAK", streak),
		TextSize = 11,
		Font = IronUi.Heading,
		TextColor3 = GOLD,
		ZIndex = 43,
	}, banner)
	UiKit.round(pill, 12)
	new(
		"UIStroke",
		{ Color = GOLD, Thickness = 1, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		pill
	)
	-- The track.
	local TILE_W, LAST_W, TILE_H, GAP = 56, 72, 86, 6
	local trackW = TILE_W * (maxDay - 1) + LAST_W + GAP * (maxDay - 1)
	local x, y0 = math.floor((W - trackW) / 2), 80
	local todayTile: Frame? = nil
	for i = 1, maxDay do
		local last = i == maxDay
		local claimed, today, nextDay = i < day, i == day, i == day + 1
		local w = if last then LAST_W else TILE_W
		local tile = new("Frame", {
			Name = "Day" .. i,
			Position = UDim2.fromOffset(x, if today then y0 - 4 else y0),
			Size = UDim2.fromOffset(w, TILE_H),
			BackgroundColor3 = if today
				then Color3.fromRGB(67, 58, 43) -- (gold, mostly the panel's navy)
				elseif claimed then Color3.fromRGB(20, 34, 32)
				elseif last then Color3.fromRGB(38, 36, 36)
				else Color3.fromRGB(26, 31, 48),
			ZIndex = 42,
		}, banner)
		UiKit.round(tile, 9)
		new("UIStroke", {
			Color = if today then GOLD elseif nextDay then P.Teal elseif last then GOLD else P.Edge,
			Thickness = if today then 2 else 1,
			Transparency = if today then 0 elseif nextDay then 0.45 elseif last then 0.6 else 0.75,
		}, tile)
		local labelColor = if today then GOLD elseif claimed then Color3.fromRGB(110, 150, 130) else P.Dim
		line(
			tile,
			if last then string.format("DAY %d+", i) else string.format("DAY %d", i),
			9,
			labelColor,
			IronUi.Heading,
			0,
			8,
			w,
			12,
			Enum.TextXAlignment.Center
		)
		local coin =
			line(tile, "◆", if last then 24 else 20, GOLD, IronUi.Heading, 0, 24, w, 28, Enum.TextXAlignment.Center)
		coin.TextTransparency = if claimed then 0.6 elseif today or last then 0 else 0.3
		line(
			tile,
			tostring(coins(i)),
			if today then 15 else 13,
			if today then P.Text elseif claimed then Color3.fromRGB(110, 150, 130) else Color3.fromRGB(212, 222, 236),
			IronUi.Heading,
			0,
			56,
			w,
			18,
			Enum.TextXAlignment.Center
		)
		if claimed then
			-- A tick on the corner of each day already collected.
			local tick = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = P.Good,
				Text = "✓",
				TextSize = 10,
				Font = IronUi.Heading,
				TextColor3 = Color3.fromRGB(8, 30, 18),
				ZIndex = 44,
			}, tile)
			UiKit.round(tick, 8)
		end
		if today then
			todayTile = tile
			local tag = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.fromOffset(52, 16),
				BackgroundColor3 = GOLD,
				Text = "TODAY",
				TextSize = 9,
				Font = IronUi.Heading,
				TextColor3 = Color3.fromRGB(40, 24, 0),
				ZIndex = 44,
			}, tile)
			UiKit.round(tag, 8)
		end
		x += w + GAP
	end
	-- Today's tile pops as the banner lands.
	if todayTile then
		local pop = new("UIScale", { Scale = 1.15 }, todayTile)
		TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.2), {
			Scale = 1,
		}):Play()
	end
	-- What tomorrow pays (from day 7 on, the same every day), and the catch.
	line(
		banner,
		if day >= maxDay
			then string.format('Every day from now on: <font color="#%s"><b>+%d ◆</b></font>', gold, coins(maxDay))
			else string.format(
				'Come back tomorrow for <font color="#%s"><b>+%d ◆</b></font>',
				gold,
				coins(day + 1)
			),
		13,
		P.Text,
		IronUi.Body,
		0,
		184,
		W,
		18,
		Enum.TextXAlignment.Center
	)
	line(
		banner,
		"Miss a day and the streak starts again at day 1.",
		11,
		P.Dim,
		IronUi.Body,
		0,
		203,
		W,
		14,
		Enum.TextXAlignment.Center
	)
	new("Frame", {
		Position = UDim2.fromOffset(PAD, 230),
		Size = UDim2.new(1, -PAD * 2, 0, 1),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.6,
		ZIndex = 42,
	}, banner)
	-- What you got today, the challenges waiting, and on we go.
	local amount = line(banner, string.format("+%d ◆", reward), 26, GOLD, IronUi.Heading, PAD, 244, 116, 32)
	IronUi.outline(amount, 1.5, Color3.fromRGB(60, 34, 0))
	local xp = new("TextLabel", {
		Position = UDim2.fromOffset(PAD + 120, 249),
		Size = UDim2.fromOffset(142, 22),
		BackgroundColor3 = P.Teal,
		BackgroundTransparency = 0.86,
		Text = string.format("+%d SEASON XP", Season.XP.Daily),
		TextSize = 11,
		Font = IronUi.Heading,
		TextColor3 = P.Teal,
		ZIndex = 43,
	}, banner)
	UiKit.round(xp, 11)
	line(
		banner,
		"3 new daily challenges are waiting",
		11,
		Color3.fromRGB(186, 140, 255),
		IronUi.Heading,
		PAD,
		282,
		260,
		16
	)
	local go = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 250),
		Size = UDim2.fromOffset(148, 42),
		Text = "CONTINUE",
		TextSize = 15,
		Font = IronUi.Heading,
		TextColor3 = Color3.fromRGB(30, 20, 4),
		BackgroundColor3 = GOLD,
		AutoButtonColor = false,
		ZIndex = 43,
	}, banner)
	UiKit.round(go, 10)
	IronUi.juice(go)
	local closing = false
	local function close()
		if closing then
			return
		end
		closing = true
		root:SetAttribute("WelcomeOpen", nil)
		open = false
		stopTopbar()
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = fit * 0.9 }):Play()
		local fade = TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			layer:Destroy()
		end)
		fade:Play()
		banner.Visible = false
	end
	go.Activated:Connect(close)
	shade.Activated:Connect(close)
	task.delay(8, close)
	pcall(function()
		require(script.Parent.UiSound).play("Reward")
	end)
end

-- Setup ----------------------------------------------------------------------------------------------

function LobbyFeed.mount(gui: ScreenGui)
	root = gui
	stack = new("Frame", {
		Name = "Live",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 3 * 30),
		BackgroundTransparency = 1,
	}, gui)
	UiKit.list(stack, 4, false)
	MobileLayout.onTop(function()
		stack.Visible = not (compact and MobileLayout.topClaimed())
	end)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local roll = remotes and remotes:FindFirstChild("MiningRoll")
	if roll and roll:IsA("RemoteEvent") then
		roll.OnClientEvent:Connect(onMiningRoll)
	end
	local social = remotes and remotes:FindFirstChild("Social")
	if social and social:IsA("RemoteEvent") then
		social.OnClientEvent:Connect(onSocial)
	end
	Players.PlayerAdded:Connect(function(other)
		LobbyFeed.push("✦", string.format("<b>%s</b> joined the game", escape(other.DisplayName)), P.Teal)
	end)
	return stack
end

-- `span` (a phone's) is the gap the feed fits in, between the pick card and
-- the board: { X = its left edge, W = its width }.
function LobbyFeed.setCompact(on: boolean, span: { X: number, W: number }?)
	compact = on
	if stack then
		local width = if compact then 300 else 380
		if span then
			width = math.min(width, math.max(160, span.W))
			stack.Position = UDim2.new(0, span.X + span.W / 2, 0, 12)
		else
			stack.Position = UDim2.new(0.5, 0, 0, 12)
		end
		stack.Size = UDim2.fromOffset(width, 3 * 30)
		stack.Visible = not (compact and MobileLayout.topClaimed())
	end
end

LobbyFeed._onMiningRoll = onMiningRoll
LobbyFeed._onSocial = onSocial

return LobbyFeed
