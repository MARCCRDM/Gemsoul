--[[
	The hub. Left: a big hero button over a grid of chunky menu tiles. In
	menu-only mode (Shared/Config) that's MINE (M) over Cut (X), Craft (F),
	Sell (V), Gems (G), Character (C) and Shop (B); otherwise SHOP over
	Character, RigManeuvers, Gems and Party. Top right: gold-edged bars
	for coins (with a + that opens the Shop), Guild Marks and gems, and
	pills for the Season Path and Top Players.

	Keys: C character, K rig maneuvers, G gems, P party, B shop, J season,
	L top players. New players see the Welcome Bundle once the intro ends.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)

local CombatGuide = require(script.Parent.Modules.CombatGuide)
local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local ForgeUI = require(script.Parent.Modules.ForgeUI)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local PartyUI = require(script.Parent.Modules.PartyUI)
local SeasonUI = require(script.Parent.Modules.SeasonUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
local TopPlayersUI = require(script.Parent.Modules.TopPlayersUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD = IronUi.Bold
local new = IronUi.new

-- The hub replaces Roblox's player list (coins, Marks and gems show here;
-- players are listed in the Party window).
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)

-- Menu-only mode uses the full-screen dashboard (Dashboard.client) instead.
if Config.MenuOnly then
	return
end

local gui = UiKit.gui("Hud", 1)

-- A little key hint chip on a button's corner.
local function keyHint(parent: Instance, key: string)
	local hint = new("TextLabel", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = P.Gold,
		Text = key,
		Font = IronUi.Chunky,
		TextSize = 13,
		TextColor3 = P.Ink,
		ZIndex = 4,
	}, parent)
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0.5, 0)
	hintCorner.Parent = hint
	new("UIStroke", { Color = P.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, hint)
end

-- A big emoji that breaks out of its button.
local function bigIcon(face: Frame, icon: string, size: number, position: UDim2, rotation: number?): TextLabel
	return new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		Text = icon,
		TextSize = size,
		Font = BOLD,
		TextColor3 = Color3.new(1, 1, 1),
		Rotation = rotation or 0,
	}, face)
end

-- A square menu tile: a slate slab, a big icon popping out of the top and
-- the name along the bottom.
local TILE = Color3.fromRGB(92, 84, 118)
local function tile(parent: Instance, icon: string, caption: string, key: string, onClick: () -> ()): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = TILE,
		Rim = Color3.fromRGB(186, 178, 210),
		Size = UDim2.fromOffset(84, 90),
		Radius = 14,
		Lip = 6,
		Stripes = "None",
		Dots = true,
	})
	b.Name = caption
	bigIcon(face, icon, 48, UDim2.new(0.5, 0, 0.3, -6), -6)
	local label = IronUi.text(face, string.upper(caption), 12, Color3.new(1, 1, 1), IronUi.Chunky)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextWrapped = false
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -4)
	label.Size = UDim2.new(1, 4, 0, 16)
	label.TextXAlignment = Enum.TextXAlignment.Center
	keyHint(b, key)
	b.Activated:Connect(onClick)
	return b
end

-- Left: a big hero button over a grid of menu tiles. In menu-only mode the
-- hero is the Mine (with today's free walls on a badge) and the grid holds
-- everything else; otherwise it's the Shop over the combat menu.
local MENU_ONLY = Config.MenuOnly
local left = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.56, 0),
	Size = UDim2.fromOffset(180, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, gui)
UiKit.list(left, 12)

local heroColor = if MENU_ONLY then Color3.fromRGB(240, 140, 40) else Color3.fromRGB(255, 196, 30)
local heroButton, heroFace = IronUi.chunk(left, {
	Color = heroColor,
	Rim = if MENU_ONLY then Color3.fromRGB(255, 214, 150) else Color3.fromRGB(255, 240, 160),
	Size = UDim2.fromOffset(180, 84),
	Radius = 16,
	Lip = 7,
	Stripes = "Broad",
})
heroButton.Name = if MENU_ONLY then "Mine" else "Shop"
heroButton.LayoutOrder = 1
bigIcon(heroFace, if MENU_ONLY then "⛏️" else "🛒", 52, UDim2.new(0.5, 0, 0.3, -8), -8)
local heroLabel = IronUi.title(heroFace, if MENU_ONLY then "MINE" else "SHOP", 32)
heroLabel.AutomaticSize = Enum.AutomaticSize.None
heroLabel.AnchorPoint = Vector2.new(0.5, 1)
heroLabel.Position = UDim2.new(0.5, 0, 1, 0)
heroLabel.Size = UDim2.new(1, 0, 0, 34)
heroLabel.TextXAlignment = Enum.TextXAlignment.Center
IronUi.shine(heroFace, 3)
keyHint(heroButton, if MENU_ONLY then "M" else "B")
heroButton.Activated:Connect(function()
	if MENU_ONLY then
		MineUI.toggle()
	else
		ShopUI.toggle()
	end
end)
-- Free walls left today, on a red badge (menu-only).
local freeBadge = new("TextLabel", {
	Name = "FreeBadge",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, -4, 0, 2),
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(230, 50, 60),
	Text = "",
	Font = IronUi.Chunky,
	TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1),
	Rotation = -10,
	Visible = false,
	ZIndex = 5,
}, heroButton)
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0.5, 0)
badgeCorner.Parent = freeBadge
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, freeBadge)
IronUi.outline(freeBadge, 2)
-- The hero gently bobs so the eye goes there first.
IronUi.animate(heroButton, function(t)
	heroButton.Rotation = math.sin(t * 2.2) * 1.2
end)

local menu = if MENU_ONLY
	then {
		{ "⇄", "Trade", "T", TradeUI.open },
		{
			"⚒️",
			"Equipment",
			"C",
			function()
				CharacterUI.open()
			end,
		},
		{
			"💰",
			"Sell",
			"V",
			function()
				ForgeUI.open("Sell", true)
			end,
		},
		{ "💎", "Gems", "G", InventoryUI.toggle },
		{ "🛡️", "Character", "C", CharacterUI.toggle },
		{ "🛒", "Shop", "B", ShopUI.toggle },
	}
	else {
		{ "🛡️", "Character", "C", CharacterUI.toggle },
		{ "⚔️", "Combat", "K", CombatGuide.toggle },
		{ "💎", "Gems", "G", InventoryUI.toggle },
		{ "👥", "Party", "P", PartyUI.toggle },
	}
local rows = math.ceil(#menu / 2)
local grid = new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(180, rows * 90 + (rows - 1) * 12),
	LayoutOrder = 2,
}, left)
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(84, 90)
gridLayout.CellPadding = UDim2.fromOffset(12, 12)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
for i, item in menu do
	tile(grid, item[1], item[2], item[3], item[4]).LayoutOrder = i
end

-- Top right: currency bars, then the Season Path and Top Players pills.
local right = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
}, gui)
UiKit.list(right, 10).HorizontalAlignment = Enum.HorizontalAlignment.Right
local bars = new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 1,
}, right)
UiKit.list(bars, 34, true)

-- A currency bar: a dark gold-edged bar with a big round icon overlapping
-- its left end, the amount in chunky outlined numbers, and an optional
-- green + button.
local function currencyBar(order: number, icon: string, coin: Color3, width: number, onPlus: (() -> ())?): TextLabel
	local bar = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(width, 38),
		LayoutOrder = order,
	}, bars)
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar
	new("UIStroke", { Color = P.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 14, 30)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(46, 38, 64)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 76, 110)),
		}),
	}, bar)
	-- The coin: a round gold-rimmed badge sitting over the bar's left end.
	local disc = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, bar)
	local discCorner = Instance.new("UICorner")
	discCorner.CornerRadius = UDim.new(0.5, 0)
	discCorner.Parent = disc
	new("UIStroke", { Color = P.Ink, Thickness = 3 }, disc)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(IronUi.lighter(coin, 0.45), IronUi.darker(coin, 0.3)),
	}, disc)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = icon,
		TextSize = 28,
		Font = BOLD,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, disc)
	local amount = IronUi.text(bar, "0", 22, Color3.new(1, 1, 1), IronUi.Chunky)
	amount.AutomaticSize = Enum.AutomaticSize.None
	amount.Position = UDim2.fromOffset(32, 0)
	amount.Size = UDim2.new(1, if onPlus then -70 else -42, 1, 0)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextYAlignment = Enum.TextYAlignment.Center
	amount.TextWrapped = false
	amount.TextScaled = false
	if onPlus then
		local plus, plusFace = IronUi.chunk(bar, {
			Color = Color3.fromRGB(60, 200, 90),
			Size = UDim2.fromOffset(32, 32),
			Radius = 9,
			Lip = 4,
			Stripes = "None",
		})
		plus.Name = "Plus"
		plus.AnchorPoint = Vector2.new(1, 0.5)
		plus.Position = UDim2.new(1, -3, 0.5, 0)
		IronUi.label(plus, plusFace, "+", 24, IronUi.Heading)
		plus.Activated:Connect(onPlus)
	end
	return amount
end
local coins = currencyBar(1, "💰", Color3.fromRGB(255, 190, 40), 188, function()
	ShopUI.open("Bundles")
end)
local marks = currencyBar(2, "🎖️", Color3.fromRGB(90, 150, 255), 140)
local gems = currencyBar(3, "💎", Color3.fromRGB(180, 90, 255), 110)

-- Season Path and Top Players: coloured pills with the icon breaking out
-- of the left end.
local pills = new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
}, right)
UiKit.list(pills, 12, true)
local function pillButton(order: number, icon: string, caption: string, key: string, color: Color3, onClick: () -> ())
	local b, face = IronUi.chunk(pills, {
		Color = color,
		Size = UDim2.fromOffset(150, 48),
		Radius = 12,
		Lip = 6,
		Dots = true,
	})
	b.Name = caption
	b.LayoutOrder = order
	bigIcon(face, icon, 40, UDim2.new(0, 12, 0.5, -4), -10)
	local label = IronUi.text(face, caption, 20, Color3.new(1, 1, 1), IronUi.Chunky)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = UDim2.fromOffset(38, 0)
	label.Size = UDim2.new(1, -44, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	keyHint(b, key)
	b.Activated:Connect(onClick)
end
pillButton(1, "⭐", "season", "J", Color3.fromRGB(150, 70, 230), SeasonUI.toggle)
pillButton(2, "🏆", "top", "L", Color3.fromRGB(50, 110, 240), TopPlayersUI.toggle)

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

local function refresh(profile)
	coins.Text = commas(profile.Coins or 0)
	marks.Text = "LV " .. tostring(Season.levelFor(profile.Season.XP))
	gems.Text = tostring(#(profile.Gems or {}))
	-- Free walls left today, on the Mine button.
	local quota = profile.Quota
	if MENU_ONLY and quota then
		local daily = profile.DailyQuota or Config.DailyQuota
		local weekly = profile.WeeklyQuota or Config.WeeklyQuota
		local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
		freeBadge.Visible = free > 0
		freeBadge.Text = free .. " FREE"
	end
end
GemClient.Changed:Connect(refresh)
if GemClient.Profile then
	refresh(GemClient.Profile)
end

-- Hide the hub while the intro is on screen.
local function introOpen(): boolean
	return player.PlayerGui:FindFirstChild("Intro") ~= nil
end
gui.Enabled = not introOpen()

-- New players: offer the Welcome Bundle once the intro is done.
local welcomed = false
local function maybeWelcome()
	local profile = GemClient.Profile
	if welcomed or introOpen() or not profile or not profile.Intro or not profile.Intro.Done then
		return
	end
	welcomed = true
	task.delay(3, ShopUI.showWelcome)
end
player.PlayerGui.ChildRemoved:Connect(function(child)
	if child.Name == "Intro" then
		gui.Enabled = true
		maybeWelcome()
	end
end)
GemClient.Changed:Connect(maybeWelcome)
task.defer(maybeWelcome)

-- Keys (C is bound by the character screen, K by combat).
local KEYS = {
	G = InventoryUI.toggle,
	B = ShopUI.toggle,
	J = SeasonUI.toggle,
	L = TopPlayersUI.toggle,
}
if MENU_ONLY then
	KEYS.M = MineUI.toggle
	KEYS.T = TradeUI.open
	KEYS.C = function()
		CharacterUI.open()
	end
	KEYS.V = function()
		ForgeUI.open("Sell", true)
	end
else
	KEYS.P = PartyUI.toggle
end
ContextActionService:BindAction(
	"GemsoulHub",
	function(_, state, inputObject)
		if state == Enum.UserInputState.Begin and not introOpen() then
			local action = KEYS[inputObject.KeyCode.Name]
			if action then
				action()
			end
		end
		return Enum.ContextActionResult.Pass
	end,
	false,
	Enum.KeyCode.G,
	Enum.KeyCode.P,
	Enum.KeyCode.B,
	Enum.KeyCode.J,
	Enum.KeyCode.L,
	Enum.KeyCode.M,
	Enum.KeyCode.T,
	Enum.KeyCode.C,
	Enum.KeyCode.V
)
