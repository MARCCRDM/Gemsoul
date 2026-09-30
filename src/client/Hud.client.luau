--[[
	The hub: big round menu buttons down the left (Character, Abilities,
	Gems, Party) and round buttons top-right (Shop, Season Path, Top
	Players) beside your coins, Guild Marks and gem count.

	Keys: C character, K abilities, G gems, P party, B shop, J season,
	L top players. New players see the Welcome Bundle once the intro ends.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local AbilitiesUI = require(script.Parent.Modules.AbilitiesUI)
local CharacterUI = require(script.Parent.Modules.CharacterUI)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local PartyUI = require(script.Parent.Modules.PartyUI)
local SeasonUI = require(script.Parent.Modules.SeasonUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
local TopPlayersUI = require(script.Parent.Modules.TopPlayersUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text = IronUi.new, IronUi.text

-- The hub replaces Roblox's player list (coins, Marks and gems show here;
-- players are listed in the Party window).
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)

local gui = UiKit.gui("Hud", 1)

-- A round button with an icon, a caption and a key hint.
local function roundButton(
	parent: Instance,
	icon: string,
	caption: string,
	key: string,
	color: Color3,
	size: number,
	onClick: () -> ()
): TextButton
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size + 16, size + (if caption ~= "" then 20 else 0)),
	}, parent)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
	}, holder)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.4 }, b)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140)),
	}, b)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = icon,
		TextSize = math.floor(size * 0.48),
		Font = BOLD,
		TextColor3 = Color3.new(1, 1, 1),
	}, b)
	if key ~= "" then
		local hint = new("TextLabel", {
			BackgroundColor3 = P.Frame,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(18, 18),
			Text = key,
			Font = BOLD,
			TextSize = 11,
			TextColor3 = P.Gold,
		}, b)
		local hintCorner = Instance.new("UICorner")
		hintCorner.CornerRadius = UDim.new(0.5, 0)
		hintCorner.Parent = hint
	end
	if caption ~= "" then
		local label = text(holder, caption, 13, Color3.new(1, 1, 1), BOLD)
		label.Position = UDim2.fromOffset(0, size + 2)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextStrokeTransparency = 0.4
	end
	-- A little bounce when pressed.
	local scale = new("UIScale", {}, b)
	b.Activated:Connect(function()
		scale.Scale = 0.88
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		onClick()
	end)
	return b
end

-- Left: the main menu.
local left = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.56, 0),
	Size = UDim2.fromOffset(90, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, gui)
UiKit.list(left, 6)
local TEAL = Color3.fromRGB(30, 110, 120)
local menu = {
	{ "🛡️", "Character", "C", CharacterUI.toggle },
	{ "⚔️", "Abilities", "K", AbilitiesUI.toggle },
	{ "💎", "Gems", "G", InventoryUI.toggle },
	{ "👥", "Party", "P", PartyUI.toggle },
}
for i, item in menu do
	local b = roundButton(left, item[1], item[2], item[3], TEAL, 60, item[4])
	b.Parent.LayoutOrder = i
end

-- Top right: currencies and the shop, season and leaderboard.
local right = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 8),
	Size = UDim2.fromOffset(0, 58),
	AutomaticSize = Enum.AutomaticSize.X,
}, gui)
UiKit.list(right, 8, true).VerticalAlignment = Enum.VerticalAlignment.Top

local function pill(order: number): TextLabel
	local label = new("TextLabel", {
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Font = BOLD,
		TextSize = 14,
		TextColor3 = P.Gold,
		LayoutOrder = order,
	}, right)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, label)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, label)
	return label
end
local coins = pill(1)
local marks = pill(2)
local gems = pill(3)
local PURPLE = Color3.fromRGB(120, 60, 160)
local corner = {
	{ "⭐", "J", PURPLE, SeasonUI.toggle },
	{ "🏆", "L", PURPLE, TopPlayersUI.toggle },
	{ "🛒", "B", Color3.fromRGB(200, 80, 150), ShopUI.toggle },
}
for i, item in corner do
	local b = roundButton(right, item[1], "", item[2], item[3], 46, item[4])
	b.Parent.LayoutOrder = 3 + i
end

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
	coins.Text = "💰 " .. commas(profile.Coins or 0)
	marks.Text = "🎖️ " .. commas(profile.Marks or 0)
	gems.Text = "💎 " .. tostring(#(profile.Gems or {}))
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

-- Keys (C and K are bound by the character and combat scripts).
local KEYS = {
	G = InventoryUI.toggle,
	P = PartyUI.toggle,
	B = ShopUI.toggle,
	J = SeasonUI.toggle,
	L = TopPlayersUI.toggle,
}
ContextActionService:BindAction("GemsoulHub", function(_, state, inputObject)
	if state == Enum.UserInputState.Begin and not introOpen() then
		local action = KEYS[inputObject.KeyCode.Name]
		if action then
			action()
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G, Enum.KeyCode.P, Enum.KeyCode.B, Enum.KeyCode.J, Enum.KeyCode.L)
