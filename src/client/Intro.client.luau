--[[
	The new-player intro: two screens.
	  1  Welcome, and your first dig: a free wall in the Mine with your first
	     stone in it (the Mine window opens on top).
	  2  "You're a miner!": your first stone and three free starter gems,
	     then into the dashboard.
	You play as a Warrior (Config.OnlyClass); the server sets it up.
	Leaving part-way picks up where you left off.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local HEADING, CHUNKY = IronUi.Heading, IronUi.Chunky
local LIGHT = Color3.fromRGB(236, 230, 250)

-- Wait for the profile, and only run for players who haven't finished.
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end

local gui = new("ScreenGui", {
	Name = "Intro",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 15,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

-- Full-screen background, like the dashboard's.
local backdrop = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1) }, gui)
new("UIGradient", {
	Rotation = 110,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 26, 84)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(22, 16, 44)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 32, 52)),
	}),
}, backdrop)

-- One centred card, scaled to fit the screen.
local W, H = 860, 560
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, gui)
UiKit.round(card, 22)
new("UIStroke", { Color = P.Gold, Thickness = 5 }, card)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(44, 32, 66), P.Frame) }, card)
local cardScale = new("UIScale", {}, card)
local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 then
		cardScale.Scale = math.min(1, (screen.X - 40) / W, (screen.Y - 40) / H)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
local badge = IronUi.badge(card, "💎", 110)
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(0.5, 0, 0, 0)
badge.ZIndex = 5
for _, child in badge:GetDescendants() do
	if child:IsA("GuiObject") then
		child.ZIndex = 6
	end
end
IronUi.animate(badge, function(t)
	badge.Rotation = math.sin(t * 1.5) * 8
end)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(40, 70),
	Size = UDim2.new(1, -80, 1, -110),
}, card)
local list = UiKit.list(body, 14)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center

local busy = false

local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local pop = badge:FindFirstChild("Pop") or new("UIScale", { Name = "Pop" }, badge)
	pop.Scale = 0.8
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function line(value: string, size: number, color: Color3, font: Enum.Font, order: number): TextLabel
	local label = text(body, value, size, color, font)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = order
	return label
end

local function firstStone()
	for _, gem in GemClient.Profile.Gems or {} do
		if gem.Source == "FirstStone" then
			return gem
		end
	end
	return nil
end

-- A small rarity card for a gem.
local function gemCard(parent: Instance, gem, order: number, caption: string?)
	local tier = GemConfig.TierColors[gem.Tier] or P.Dim
	local c = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(160, 190),
		LayoutOrder = order,
	}, parent)
	UiKit.round(c, 16)
	new("UIStroke", { Color = tier, Thickness = 4 }, c)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tier:Lerp(Color3.new(0, 0, 0), 0.35), tier:Lerp(Color3.new(0, 0, 0), 0.8)),
	}, c)
	local ribbon =
		text(c, caption or string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier), 13, Color3.new(1, 1, 1), CHUNKY)
	ribbon.AutomaticSize = Enum.AutomaticSize.None
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0)
	ribbon.Size = UDim2.fromOffset(120, 26)
	ribbon.BackgroundTransparency = 0
	ribbon.BackgroundColor3 = tier
	ribbon.TextXAlignment = Enum.TextXAlignment.Center
	ribbon.TextYAlignment = Enum.TextYAlignment.Center
	UiKit.round(ribbon, 9)
	local swatch = UiKit.swatch(c, GemConfig.shade(gem), 64)
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.new(0.5, 0, 0, 30)
	local name = text(c, GemConfig.shade(gem).Name, 16, Color3.new(1, 1, 1), HEADING)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Position = UDim2.fromOffset(6, 110)
	name.Size = UDim2.new(1, -12, 0, 36)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local state = if gem.Cut then "Cut " .. gem.Cut else "Rough"
	local info = text(c, string.format("%s  •  💰 %d", state, GemConfig.value(gem)), 13, LIGHT, CHUNKY)
	info.AutomaticSize = Enum.AutomaticSize.None
	info.Position = UDim2.fromOffset(6, 154)
	info.Size = UDim2.new(1, -12, 0, 18)
	info.TextXAlignment = Enum.TextXAlignment.Center
	local pop = new("UIScale", { Scale = 0.3 }, c)
	task.delay(0.12 * order, function()
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	return c
end

local showReady: () -> ()

-- Screen 1: welcome and the first dig.
local function showWelcome()
	clear()
	local title = line("GEMSOUL", 84, P.Gold, HEADING, 1)
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Thickness = 5
	end
	line("Dig up gems. Cut them. Forge them into legendary gear.", 22, Color3.new(1, 1, 1), CHUNKY, 2)
	line(
		"Gems grow in the rock under the kingdom. Glinting rocks hide them:\nswing your pickaxe and break one out!",
		17,
		LIGHT,
		CHUNKY,
		3
	)
	local spacer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 20), LayoutOrder = 4 }, body)
	spacer.Name = "Spacer"
	local dig
	dig = IronUi.gemButton(body, "⛏️  START DIGGING", Color3.fromRGB(255, 150, 30), function()
		if busy then
			return
		end
		busy = true
		gui.Enabled = false
		MineUI.tutorial()
		gui.Enabled = true
		-- If the dig couldn't start, a practice stone instead.
		if not firstStone() and not GemClient.Profile.Intro.FirstStone then
			GemClient.request("FirstStone")
		end
		busy = false
		if firstStone() then
			showReady()
		end
	end)
	dig.LayoutOrder = 5
	dig.Size = UDim2.fromOffset(0, 70)
	dig.TextSize = 30
	IronUi.animate(dig, function(t)
		dig.Rotation = math.sin(t * 6) * 2
	end)
end

-- Screen 2: your gems, then into the game.
function showReady()
	clear()
	line("YOU'RE A MINER!", 50, Color3.new(1, 1, 1), HEADING, 1)
	line("Your first stone, plus three cut gems to get you started.", 18, LIGHT, CHUNKY, 2)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 206),
		LayoutOrder = 3,
	}, body)
	local rowList = UiKit.list(row, 16, true)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local stone = firstStone()
	if stone then
		gemCard(row, stone, 1, "YOUR FIRST")
	end
	local function enter()
		gui:Destroy()
		UiKit.toast("Welcome to Gemsoul! Press M or click DIG to mine.", P.Gold)
	end
	local starters = {}
	for _, gem in GemClient.Profile.Gems or {} do
		if gem.Source == "StarterSpin" then
			table.insert(starters, gem)
		end
	end
	for i, gem in starters do
		gemCard(row, gem, i + 1)
	end
	-- One button: claim the starter gems (they pop in), then enter.
	local claimed = GemClient.Profile.Intro.Done == true
	local button
	button = IronUi.gemButton(
		body,
		if claimed then "ENTER GEMSOUL  ▶" else "🎁  CLAIM 3 FREE GEMS",
		if claimed then P.Emerald else Color3.fromRGB(255, 150, 30),
		function()
			if busy then
				return
			end
			if claimed then
				enter()
				return
			end
			busy = true
			task.spawn(function()
				local result = GemClient.request("QuickStart")
				busy = false
				if not result.Ok then
					UiKit.toast(result.Message, P.Bad)
					return
				end
				claimed = true
				for i, gem in result.Gems or {} do
					gemCard(row, gem, i + 1)
				end
				button.Text = "ENTER GEMSOUL  ▶"
			end)
		end
	)
	button.LayoutOrder = 5
	button.Size = UDim2.fromOffset(0, 64)
	button.TextSize = 26
end

if firstStone() then
	showReady()
else
	showWelcome()
end
