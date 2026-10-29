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
	                                   given ({ X, W }) between the corners
	                                   (none on most phones now: the top
	                                   left has your kaiju's card);
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
	-- The week's track: every day's coins, today lit gold, the days behind
	-- ticked, a rail joining them filled as far as today; day 7 holding (it
	-- pays the same every day after, while the streak lasts). A missed day
	-- starts it again at day 1 (PlayerData.claimDaily). No fanfare: it
	-- arrives quietly a little after you're in (LobbyUI.setVisible).
	local W, H, PAD = 520, 336, 24
	local banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 41,
	}, shade)
	UiKit.round(banner, 16)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(28, 32, 50), Color3.fromRGB(11, 13, 22)),
	}, banner)
	new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.55 }, banner)
	-- A warm light over the heading.
	local halo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -60),
		Size = UDim2.fromOffset(380, 150),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.82,
		ZIndex = 41,
	}, banner)
	UiKit.round(halo, 999)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, halo)
	local accent = new("Frame", {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -80, 0, 2),
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
	local scale = new("UIScale", { Scale = 0.85 }, banner)
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
	shade.BackgroundTransparency = 1
	TweenService:Create(shade, TweenInfo.new(0.4), { BackgroundTransparency = 0.5 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = fit })
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
	-- A coin, drawn: a gold disc, a darker rim inside it, a glint.
	local DEEP = Color3.fromRGB(206, 142, 40)
	local function coin(parent: Instance, cx: number, cy: number, d: number, faded: number?)
		local fade = faded or 0
		local disc = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(d, d),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = fade,
			ZIndex = 44,
		}, parent)
		UiKit.round(disc, 999)
		local inner = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			BackgroundColor3 = DEEP,
			BackgroundTransparency = fade,
			ZIndex = 45,
		}, disc)
		UiKit.round(inner, 999)
		local glint = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.36, 0.34),
			Size = UDim2.fromScale(0.22, 0.22),
			BackgroundColor3 = Color3.fromRGB(255, 240, 190),
			BackgroundTransparency = math.max(fade, 0.15),
			ZIndex = 46,
		}, disc)
		UiKit.round(glint, 999)
		return disc
	end
	local gold = "FFCA5B" -- (GOLD)
	local maxDay = Config.DailyStreakMax
	local day = math.clamp(streak, 1, maxDay)
	local function coins(d: number): number
		return Config.DailyRewardBase + Config.DailyRewardPerStreak * (math.min(d, maxDay) - 1)
	end
	-- Header: what this is, then who it's for and the streak, centred.
	local first = streak <= 1
	line(banner, "DAILY REWARD", 26, P.Text, IronUi.Heading, 0, 20, W, 30, Enum.TextXAlignment.Center)
	line(
		banner,
		string.format(
			'%s  ·  <font color="#%s"><b>%s</b></font>',
			string.format(if first then "Welcome, %s" else "Welcome back, %s", escape(player.DisplayName)),
			gold,
			if first then "A new streak" else string.format("Day %d streak", streak)
		),
		13,
		P.Dim,
		IronUi.Body,
		0,
		52,
		W,
		18,
		Enum.TextXAlignment.Center
	)
	-- The track, on a rail.
	local TILE_W, LAST_W, TILE_H, GAP = 58, 76, 92, 8
	local trackW = TILE_W * (maxDay - 1) + LAST_W + GAP * (maxDay - 1)
	local x0, y0 = math.floor((W - trackW) / 2), 92
	local function centre(i: number): number
		return x0 + (i - 1) * (TILE_W + GAP) + (if i == maxDay then LAST_W else TILE_W) / 2
	end
	local rail = new("Frame", {
		Position = UDim2.fromOffset(centre(1), y0 + TILE_H / 2 - 2),
		Size = UDim2.fromOffset(centre(maxDay) - centre(1), 4),
		BackgroundColor3 = Color3.fromRGB(40, 46, 68),
		BorderSizePixel = 0,
		ZIndex = 41,
	}, banner)
	UiKit.round(rail, 2)
	local filled = new("Frame", {
		Size = UDim2.fromOffset(centre(day) - centre(1), 4),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 41,
	}, rail)
	UiKit.round(filled, 2)
	local todayTile: Frame? = nil
	local x = x0
	for i = 1, maxDay do
		local last = i == maxDay
		local claimed, today = i < day, i == day
		local w = if last then LAST_W else TILE_W
		local tile = new("Frame", {
			Name = "Day" .. i,
			Position = UDim2.fromOffset(x, y0),
			Size = UDim2.fromOffset(w, TILE_H),
			BackgroundColor3 = if today
				then Color3.new(1, 1, 1)
				elseif claimed then Color3.fromRGB(22, 40, 36)
				elseif last then Color3.fromRGB(52, 42, 26)
				else Color3.fromRGB(28, 33, 52),
			ZIndex = 42,
		}, banner)
		UiKit.round(tile, 10)
		if today then
			-- (lit gold: a gradient on the tile itself, its words its children)
			new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromRGB(255, 218, 128), Color3.fromRGB(214, 150, 46)),
			}, tile)
		end
		new("UIStroke", {
			Color = if today then Color3.fromRGB(255, 236, 180) elseif claimed then P.Good elseif last then GOLD else P.Edge,
			Thickness = if today then 2 else 1,
			Transparency = if today then 0 elseif claimed then 0.6 elseif last then 0.45 else 0.7,
		}, tile)
		local ink = if today then Color3.fromRGB(64, 38, 4) elseif claimed then Color3.fromRGB(120, 168, 146) else P.Dim
		line(tile, if last then string.format("DAY %d+", i) else string.format("DAY %d", i), 10, ink, IronUi.Heading, 0, 8, w, 12, Enum.TextXAlignment.Center)
		if last then
			-- the week's last day a stack of them
			coin(tile, w / 2 - 9, 46, 20, if claimed then 0.55 else 0)
			coin(tile, w / 2 + 9, 46, 20, if claimed then 0.55 else 0)
			coin(tile, w / 2, 37, 22, if claimed then 0.55 else 0)
		else
			coin(tile, w / 2, 42, if today then 26 else 22, if claimed then 0.6 elseif today then 0 else 0.15)
		end
		line(
			tile,
			tostring(coins(i)),
			if today then 16 else 13,
			if today then Color3.fromRGB(44, 26, 0) elseif claimed then Color3.fromRGB(120, 168, 146) else Color3.fromRGB(218, 226, 240),
			IronUi.Heading,
			0,
			64,
			w,
			18,
			Enum.TextXAlignment.Center
		)
		if claimed then
			-- A tick on the corner of each day already collected.
			local tick = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = P.Good,
				Text = "✓",
				TextSize = 11,
				Font = IronUi.Heading,
				TextColor3 = Color3.fromRGB(8, 30, 18),
				ZIndex = 47,
			}, tile)
			UiKit.round(tick, 9)
		end
		if today then
			todayTile = tile
			-- its glow, breathing behind it
			local glow = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x + w / 2, y0 + TILE_H / 2),
				Size = UDim2.fromOffset(w + 18, TILE_H + 18),
				BackgroundColor3 = GOLD,
				BackgroundTransparency = 0.8,
				ZIndex = 41,
			}, banner)
			UiKit.round(glow, 16)
			TweenService:Create(
				glow,
				TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.92, Size = UDim2.fromOffset(w + 10, TILE_H + 10) }
			):Play()
			local tag = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.fromOffset(54, 17),
				BackgroundColor3 = Color3.fromRGB(44, 26, 0),
				Text = "TODAY",
				TextSize = 9,
				Font = IronUi.Heading,
				TextColor3 = GOLD,
				ZIndex = 47,
			}, tile)
			UiKit.round(tag, 8)
			new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tag)
		end
		x += w + GAP
	end
	-- Today's tile lands a beat after the banner.
	if todayTile then
		local pop = new("UIScale", { Scale = 1.12 }, todayTile)
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.25), {
			Scale = 1,
		}):Play()
	end
	-- What tomorrow pays (from day 7 on, the same every day), and the catch.
	line(
		banner,
		if day >= maxDay
			then string.format('Every day from now on: <font color="#%s"><b>+%d ◆</b></font>', gold, coins(maxDay))
			else string.format('Come back tomorrow for <font color="#%s"><b>+%d ◆</b></font>', gold, coins(day + 1)),
		14,
		P.Text,
		IronUi.Body,
		0,
		y0 + TILE_H + 20,
		W,
		18,
		Enum.TextXAlignment.Center
	)
	line(banner, "Miss a day and the streak starts again at day 1.", 11, P.Dim, IronUi.Body, 0, y0 + TILE_H + 40, W, 14, Enum.TextXAlignment.Center)
	-- What you got today, the season XP and challenges, and on we go: a
	-- tray along the foot.
	local tray = new("Frame", {
		Position = UDim2.fromOffset(PAD, H - 84),
		Size = UDim2.new(1, -PAD * 2, 0, 64),
		BackgroundColor3 = Color3.fromRGB(8, 10, 18),
		BackgroundTransparency = 0.25,
		ZIndex = 42,
	}, banner)
	UiKit.round(tray, 12)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.65 }, tray)
	coin(tray, 30, 32, 34)
	local amount = line(tray, string.format("+%s", tostring(reward)), 28, GOLD, IronUi.Heading, 56, 6, 150, 32)
	IronUi.outline(amount, 1.5, Color3.fromRGB(60, 34, 0))
	line(
		tray,
		string.format(
			'<font color="%s">+%d Season XP</font>  ·  <font color="%s">3 new daily challenges</font>',
			hex(P.Teal),
			Season.XP.Daily,
			hex(Color3.fromRGB(186, 140, 255))
		),
		11,
		P.Dim,
		IronUi.Heading,
		56,
		38,
		260,
		16
	)
	local go = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 44),
		Text = "CONTINUE",
		TextSize = 15,
		Font = IronUi.Heading,
		TextColor3 = Color3.fromRGB(36, 22, 2),
		BackgroundColor3 = GOLD,
		AutoButtonColor = false,
		ZIndex = 43,
	}, tray)
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
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = fit * 0.92 }):Play()
		local fade = TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			layer:Destroy()
		end)
		fade:Play()
		banner.Visible = false
	end
	go.Activated:Connect(close)
	shade.Activated:Connect(close)
	task.delay(12, close)
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
		stack.Visible = stack:GetAttribute("Narrow") ~= true and not (compact and MobileLayout.topClaimed())
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

-- `span` (a phone's) is the gap the feed fits in, between your kaiju's card
-- and the toasts' place (MobileLayout.topGap): { X = its left edge, W = its
-- width }.
function LobbyFeed.setCompact(on: boolean, span: { X: number, W: number }?)
	compact = on
	if stack then
		local width = if compact then 300 else 380
		-- (A phone too narrow for it between your kaiju's card and the
		-- toasts' place: no feed there.)
		local narrow = span ~= nil and span.W < 160
		if span then
			width = math.min(width, math.max(160, span.W))
			stack.Position = UDim2.new(0, span.X + span.W / 2, 0, 12)
		else
			stack.Position = UDim2.new(0.5, 0, 0, 12)
		end
		stack.Size = UDim2.fromOffset(width, 3 * 30)
		stack:SetAttribute("Narrow", narrow)
		stack.Visible = not narrow and not (compact and MobileLayout.topClaimed())
	end
end

LobbyFeed._onMiningRoll = onMiningRoll
LobbyFeed._onSocial = onSocial

return LobbyFeed
