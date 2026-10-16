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
	  LobbyFeed.setCompact(on)    phone layout
	  LobbyFeed.push(icon, text, color?)   adds a line (rich text)
	  LobbyFeed.welcome()         shows the banner if there's a reward to show
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local IronUi = require(script.Parent.IronUi)
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
	-- (The Tasks button steps aside while it's up: TrainingRewards.client.)
	root:SetAttribute("WelcomeOpen", true)
	local shade = new("TextButton", {
		Name = "Welcome",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, root)
	local banner = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 236),
		BackgroundColor3 = Color3.fromRGB(16, 20, 32),
		ZIndex = 41,
	}, shade)
	UiKit.round(banner, 16)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.25 }, banner)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 200), Color3.fromRGB(150, 140, 170)),
	}, banner)
	local scale = new("UIScale", { Scale = 0.8 }, banner)
	local screen = root.AbsoluteSize
	local fit = math.min(1, (screen.X - 24) / 400, (screen.Y - 24) / 236)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit })
		:Play()
	local function line(value: string, size: number, color: Color3, y: number, height: number, font: Enum.Font?)
		local l = new("TextLabel", {
			BackgroundTransparency = 1,
			RichText = true,
			Text = value,
			TextSize = size,
			Font = font or IronUi.Heading,
			TextColor3 = color,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			ZIndex = 42,
		}, banner)
		return l
	end
	local first = streak <= 1
	line(if first then "WELCOME, MINER" else "WELCOME BACK", 13, P.Dim, 16, 18)
	line(if first then "DAILY REWARD" else string.format("DAY %d STREAK", streak), 24, P.Text, 36, 30)
	local amount = line(string.format("+%d ◆", reward), 40, GOLD, 70, 46)
	IronUi.outline(amount, 2, Color3.fromRGB(60, 34, 0))
	-- The week, today lit.
	local dots = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(7 * 30 - 6, 22),
		ZIndex = 42,
	}, banner)
	for i = 1, Config.DailyStreakMax do
		local today = i == math.min(streak, Config.DailyStreakMax)
		local done = i <= streak
		local dot = new("TextLabel", {
			BackgroundColor3 = if today
				then GOLD
				elseif done then Color3.fromRGB(44, 128, 82)
				else Color3.fromRGB(40, 50, 66),
			Text = if done and not today then "✓" else tostring(i),
			TextSize = 12,
			Font = IronUi.Heading,
			TextColor3 = if today then Color3.fromRGB(40, 24, 0) else Color3.new(1, 1, 1),
			Position = UDim2.fromOffset((i - 1) * 30, 0),
			Size = UDim2.fromOffset(24, 22),
			ZIndex = 43,
		}, dots)
		UiKit.round(dot, 6)
	end
	local tomorrow = Config.DailyRewardBase
		+ Config.DailyRewardPerStreak * (math.min(streak + 1, Config.DailyStreakMax) - 1)
	line(
		string.format('Come back tomorrow for <font color="#FFCA5B"><b>+%d ◆</b></font>', tomorrow),
		13,
		P.Text,
		154,
		18,
		IronUi.Body
	)
	line("3 new daily challenges are waiting", 12, Color3.fromRGB(186, 140, 255), 174, 16, IronUi.Heading)
	local go = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196),
		Size = UDim2.fromOffset(150, 30),
		Text = "LET'S GO",
		TextSize = 14,
		Font = IronUi.Heading,
		TextColor3 = Color3.fromRGB(30, 20, 4),
		BackgroundColor3 = GOLD,
		AutoButtonColor = false,
		ZIndex = 42,
	}, banner)
	UiKit.round(go, 8)
	IronUi.juice(go)
	local closing = false
	local function close()
		if closing then
			return
		end
		closing = true
		root:SetAttribute("WelcomeOpen", nil)
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = fit * 0.9 }):Play()
		local fade = TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			shade:Destroy()
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

function LobbyFeed.setCompact(on: boolean)
	compact = on
	if stack then
		stack.Size = UDim2.fromOffset(if compact then 300 else 380, 3 * 30)
	end
end

LobbyFeed._onMiningRoll = onMiningRoll
LobbyFeed._onSocial = onSocial

return LobbyFeed
