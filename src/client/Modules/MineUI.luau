--[[
	The Mine: the menu's digging game. A cave wall of rocks; each click is a
	swing of the pickaxe. Rocks crack, shake and burst; glinting rocks hold
	gems, speckled ones ore, and some hide coin pouches. Out of swings?
	Descend to a deeper wall, where the gems get better.

	MineUI.open()        the mine from the menu
	MineUI.tutorial()    the intro's first dig (yields until you continue)
	MineUI.close(), MineUI.toggle()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Mine = require(ReplicatedStorage.Shared.Mine)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local ShopArt = require(script.Parent.ShopArt)
local UiKit = require(script.Parent.UiKit)

local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local CHUNKY, HEADING = IronUi.Chunky, IronUi.Heading
local INK = P.Ink
local EARTH = Color3.fromRGB(150, 96, 52)
local RARITY_NAMES = { Common = "COMMON", Uncommon = "UNCOMMON", Rare = "RARE", UltraRare = "ULTRA RARE" }

local MineUI = {}

local window = IronUi.window("Mine", 11, 1040, 600, "⛏️", EARTH)
window.Title.Text = "THE MINE"
local panel = window.Panel

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Sounds (Roblox's built-in sounds; silent if one is missing).
local function sound(id: string, speed: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = window.Gui
	pcall(function()
		s:Play()
	end)
	task.delay(2, function()
		s:Destroy()
	end)
end
local function clink(heavy: boolean)
	sound("rbxasset://sounds/swordhit.wav", if heavy then 0.55 else 0.75 + math.random() * 0.15, 0.35)
end
local function chime()
	sound("rbxasset://sounds/electronicpingshort.wav", 1.3, 0.4)
end

-- Layout --------------------------------------------------------------------------------------------------

local CELL, GAP = 96, 10
local WALL_W = Mine.Columns * CELL + (Mine.Columns - 1) * GAP
local WALL_H = Mine.Rows * CELL + (Mine.Rows - 1) * GAP

-- The cave: a dark earthy backdrop the rocks sit in.
local cave = new("Frame", {
	Position = UDim2.fromOffset(26, 86),
	Size = UDim2.fromOffset(WALL_W + 32, WALL_H + 76),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, panel)
UiKit.round(cave, 16)
new("UIStroke", { Color = INK, Thickness = 3 }, cave)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(70, 48, 36), Color3.fromRGB(24, 16, 14)),
}, cave)
local depthBanner = text(cave, "", 26, Color3.new(1, 1, 1), HEADING)
depthBanner.AutomaticSize = Enum.AutomaticSize.None
depthBanner.Position = UDim2.fromOffset(16, 10)
depthBanner.Size = UDim2.new(1, -32, 0, 30)
local depthHint = text(cave, "", 13, Color3.fromRGB(230, 210, 190), CHUNKY)
depthHint.AutomaticSize = Enum.AutomaticSize.None
depthHint.AnchorPoint = Vector2.new(1, 0)
depthHint.Position = UDim2.new(1, -16, 0, 16)
depthHint.Size = UDim2.fromOffset(360, 20)
depthHint.TextXAlignment = Enum.TextXAlignment.Right

local wallHolder = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(WALL_W, WALL_H),
}, cave)
local wallBase = wallHolder.Position

-- Messages over the wall ("Out of swings!", the start screen).
local overlay = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(10, 6, 8),
	BackgroundTransparency = 0.25,
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(WALL_W, WALL_H),
	Visible = false,
	ZIndex = 20,
}, cave)
UiKit.round(overlay, 14)
local overlayList = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, overlay)
local ol = UiKit.list(overlayList, 12)
ol.HorizontalAlignment = Enum.HorizontalAlignment.Center
ol.VerticalAlignment = Enum.VerticalAlignment.Center

-- Right side: swings, cost, loot tray and buttons.
local SIDE_X = 26 + WALL_W + 32 + 16
local side = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(SIDE_X, 86),
	Size = UDim2.new(1, -SIDE_X - 26, 0, WALL_H + 76),
}, panel)

local swingCard = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 96) }, side)
UiKit.round(swingCard, 14)
new("UIStroke", { Color = INK, Thickness = 3 }, swingCard)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(96, 70, 140), Color3.fromRGB(40, 28, 64)),
}, swingCard)
local swingIcon = text(swingCard, "⛏️", 44, Color3.new(1, 1, 1), Enum.Font.Gotham)
swingIcon.AutomaticSize = Enum.AutomaticSize.None
swingIcon.Position = UDim2.fromOffset(10, 12)
swingIcon.Size = UDim2.fromOffset(56, 56)
local swingCount = IronUi.title(swingCard, "0", 44)
swingCount.AutomaticSize = Enum.AutomaticSize.None
swingCount.Position = UDim2.fromOffset(72, 8)
swingCount.Size = UDim2.fromOffset(120, 48)
local swingCaption = text(swingCard, "SWINGS LEFT", 13, Color3.fromRGB(220, 210, 240), CHUNKY)
swingCaption.AutomaticSize = Enum.AutomaticSize.None
swingCaption.Position = UDim2.fromOffset(74, 54)
swingCaption.Size = UDim2.fromOffset(160, 16)
local swingBarBack = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(26, 18, 40),
	Position = UDim2.new(0, 12, 1, -18),
	Size = UDim2.new(1, -24, 0, 10),
}, swingCard)
UiKit.round(swingBarBack, 5)
local swingBar = new("Frame", { BackgroundColor3 = P.Gold, Size = UDim2.fromScale(1, 1) }, swingBarBack)
UiKit.round(swingBar, 5)

local costLine = text(side, "", 14, Color3.fromRGB(236, 230, 250), CHUNKY)
costLine.Position = UDim2.fromOffset(2, 106)

local trayTitle = text(side, "FOUND IN THIS WALL", 15, P.Gold, CHUNKY)
trayTitle.Position = UDim2.fromOffset(2, 138)
local tray = new("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(22, 16, 30),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 162),
	Size = UDim2.new(1, 0, 1, -162 - 128),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, side)
UiKit.round(tray, 12)
new("UIStroke", { Color = INK, Thickness = 2 }, tray)
UiKit.pad(tray, 8)
UiKit.list(tray, 6)

local buttons = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 116),
}, side)
UiKit.list(buttons, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center

-- State ---------------------------------------------------------------------------------------------------

type TileUi = {
	Button: TextButton,
	Rock: Frame,
	Cracks: { Frame },
	Pips: Frame,
	Hint: Frame,
	Broken: boolean,
}

local wall = nil -- the server's view of the current wall
local quota = nil
local tiles: { TileUi } = {}
local busy = false
local lastSwing = 0
local tutorialMode = false
local tutorialDone: BindableEvent? = nil
local tutorialFinished = false -- set before firing, so a finish before the wait isn't missed
local foundCount = 0

local function clearTray()
	for _, child in tray:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	foundCount = 0
end

local function lootIcon(loot): (string, Color3)
	if loot.Kind == "Gem" then
		return "💎", GemConfig.TierColors[loot.Rarity] or P.Gold
	elseif loot.Kind == "Ore" then
		local ore = Mine.Ores[loot.Material]
		return ShopArt.MaterialIcons[loot.Material] or "⛓️", if ore then ore.Color else EARTH
	elseif loot.Kind == "Coins" then
		return "💰", P.Gold
	elseif loot.Kind == "Full" then
		return "🎒", P.Bad
	end
	return "💨", Color3.fromRGB(140, 130, 120)
end

local function lootText(loot): string
	if loot.Kind == "Gem" then
		return loot.Text
			.. (if loot.Coins then string.format("  +%d coins", loot.Coins) else "")
			.. (if loot.Gear then "  +" .. loot.Gear else "")
	elseif loot.Count then
		return string.format("+%d %s", loot.Count, loot.Text)
	end
	return loot.Text
end

local function addToTray(loot)
	if loot.Kind == "Stone" then
		return
	end
	foundCount += 1
	local _, color = lootIcon(loot)
	local row = new("Frame", {
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55),
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = -foundCount, -- newest on top
	}, tray)
	UiKit.round(row, 8)
	new("UIStroke", { Color = color, Thickness = 1.5 }, row)
	local icon = lootIcon(loot)
	local label = text(row, icon .. "  " .. lootText(loot), 14, Color3.new(1, 1, 1), CHUNKY)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Position = UDim2.fromOffset(10, 0)
	label.Size = UDim2.new(1, -16, 1, 0)
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local pop = new("UIScale", { Scale = 0.6 }, row)
	tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- A word that floats up from a point and fades ("CRIT!", "+3 Iron").
local function floatWord(parent: GuiObject, word: string, color: Color3, size: number)
	local label = text(parent, word, size, color, HEADING)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.35)
	label.Size = UDim2.fromOffset(220, size + 8)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 30
	label.Rotation = math.random(-8, 8)
	tween(label, 0.9, { Position = UDim2.new(0.5, 0, 0.35, -60), TextTransparency = 1 })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, 0.9, { Transparency = 1 })
	end
	task.delay(0.95, function()
		label:Destroy()
	end)
end

-- Rock chips flying out of a hit.
local function dust(parent: GuiObject, color: Color3, amount: number)
	for _ = 1, amount do
		local chip = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.random(5, 10), math.random(5, 10)),
			BackgroundColor3 = color,
			Rotation = math.random(0, 90),
			ZIndex = 25,
		}, parent)
		UiKit.round(chip, 2)
		local angle = math.random() * math.pi * 2
		local distance = math.random(30, 70)
		tween(chip, 0.45, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance + 20),
			BackgroundTransparency = 1,
			Rotation = chip.Rotation + 180,
		})
		task.delay(0.5, function()
			chip:Destroy()
		end)
	end
end

local function shakeWall(strength: number)
	task.spawn(function()
		for i = 1, 6 do
			local fade = (6 - i) / 6
			wallHolder.Position = wallBase
				+ UDim2.fromOffset(math.random(-strength, strength) * fade, math.random(-strength, strength) * fade)
			task.wait(0.03)
		end
		wallHolder.Position = wallBase
	end)
end

-- Each rock has one UIScale, shared by its drop-in, hit punch and pop.
local function scaleOf(rock: Frame): UIScale
	return rock:FindFirstChildOfClass("UIScale") or new("UIScale", {}, rock)
end

-- One rock ------------------------------------------------------------------------------------------------

-- A pseudo-random but stable number for rock `i` (so rocks keep their look).
local function noise(i: number, k: number): number
	local x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - math.floor(x)
end

local ROCK_TOP = Color3.fromRGB(150, 138, 128)
local ROCK_BOTTOM = Color3.fromRGB(84, 74, 70)

local function drawPips(ui: TileUi, hp: number)
	for _, child in ui.Pips:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for n = 1, hp do
		local pip = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 240, 200),
			Size = UDim2.fromOffset(8, 8),
			LayoutOrder = n,
		}, ui.Pips)
		UiKit.round(pip, 4)
		new("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
	end
end

local function showCracks(ui: TileUi, hp: number, maxHp: number)
	local damage = 1 - hp / math.max(1, maxHp)
	local visible = math.ceil(damage * #ui.Cracks)
	for n, crack in ui.Cracks do
		crack.Visible = n <= visible
	end
end

local function makeTile(index: number, data): TileUi
	local col = (index - 1) % Mine.Columns
	local row = (index - 1) // Mine.Columns
	local button = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(col * (CELL + GAP), row * (CELL + GAP)),
		Size = UDim2.fromOffset(CELL, CELL),
	}, wallHolder)
	-- The rock: a lumpy rounded boulder with a lighter top.
	local rock = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.96),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = (noise(index, 1) - 0.5) * 10,
	}, button)
	UiKit.round(rock, 22 + math.floor(noise(index, 2) * 14))
	new("UIStroke", { Color = INK, Thickness = 3 }, rock)
	local tint = 0.85 + noise(index, 3) * 0.3
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(
			ROCK_TOP:Lerp(Color3.new(0, 0, 0), 1 - math.min(1, tint)),
			ROCK_BOTTOM:Lerp(Color3.new(0, 0, 0), 1 - math.min(1, tint))
		),
	}, rock)
	-- Facets: a couple of lighter and darker patches.
	for k = 1, 3 do
		local patch = new("Frame", {
			BackgroundColor3 = if k == 1 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
			BackgroundTransparency = if k == 1 then 0.8 else 0.82,
			Position = UDim2.fromScale(0.12 + noise(index, 10 + k) * 0.45, 0.1 + noise(index, 20 + k) * 0.5),
			Size = UDim2.fromScale(0.22 + noise(index, 30 + k) * 0.18, 0.16 + noise(index, 40 + k) * 0.14),
			Rotation = noise(index, 50 + k) * 60 - 30,
		}, rock)
		UiKit.round(patch, 10)
	end
	-- Hints: glints for gems (gold for lucky rocks), specks for ore.
	local hint = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, rock)
	if data.Hint == "Glint" or data.Hint == "Gold" then
		local gold = data.Hint == "Gold"
		for k = 1, if gold then 3 else 2 do
			local star = text(
				hint,
				if k == 1 then "✦" else "✧",
				if gold then 26 else 20,
				if gold then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(190, 250, 255),
				CHUNKY
			)
			star.AutomaticSize = Enum.AutomaticSize.None
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Position = UDim2.fromScale(0.25 + noise(index, 60 + k) * 0.5, 0.25 + noise(index, 70 + k) * 0.45)
			star.Size = UDim2.fromOffset(28, 28)
			star.TextXAlignment = Enum.TextXAlignment.Center
			star.ZIndex = 4
			local phase = noise(index, 80 + k) * 6
			IronUi.animate(star, function(t)
				local pulse = (math.sin(t * 3 + phase) + 1) / 2
				star.TextTransparency = 0.6 - pulse * 0.6
				star.Rotation = t * 40 + phase * 30
			end)
		end
		if gold then
			rock:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(150, 110, 20)
		end
	elseif data.Hint == "Speck" then
		local color = data.OreColor or Color3.fromRGB(200, 200, 210)
		for k = 1, 4 do
			local speck = new("Frame", {
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.22 + noise(index, 90 + k) * 0.56, 0.22 + noise(index, 100 + k) * 0.5),
				Size = UDim2.fromOffset(
					7 + math.floor(noise(index, 110 + k) * 6),
					7 + math.floor(noise(index, 120 + k) * 6)
				),
				Rotation = 45,
				ZIndex = 4,
			}, hint)
			new("UIStroke", { Color = INK, Thickness = 1.5 }, speck)
		end
	end
	-- Cracks, shown as the rock takes hits.
	local cracks = {}
	for k = 1, 4 do
		local crack = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(20, 12, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.3 + noise(index, 130 + k) * 0.4, 0.3 + noise(index, 140 + k) * 0.4),
			Size = UDim2.fromOffset(4, 22 + math.floor(noise(index, 150 + k) * 26)),
			Rotation = noise(index, 160 + k) * 180,
			Visible = false,
			ZIndex = 5,
		}, rock)
		UiKit.round(crack, 2)
		cracks[k] = crack
	end
	-- Layers left, as little pips along the bottom.
	local pips = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(80, 10),
		ZIndex = 6,
	}, rock)
	UiKit.list(pips, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local ui: TileUi = { Button = button, Rock = rock, Cracks = cracks, Pips = pips, Hint = hint, Broken = false }
	drawPips(ui, data.Hp)
	showCracks(ui, data.Hp, data.MaxHp)
	IronUi.juice(button, 1.06, 0.92)
	IronUi.highlight(button, rock)
	return ui
end

-- A broken rock: a dark hollow with what it held.
local function showHollow(ui: TileUi, loot)
	ui.Broken = true
	ui.Button.AutoButtonColor = false
	for _, child in ui.Rock:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	ui.Rock:FindFirstChildOfClass("UIGradient").Color =
		ColorSequence.new(Color3.fromRGB(34, 24, 22), Color3.fromRGB(14, 10, 10))
	local icon, color = lootIcon(loot or { Kind = "Stone" })
	if loot and loot.Kind ~= "Stone" then
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.6,
		}, ui.Rock)
		UiKit.round(glow, 40)
	end
	local label = text(ui.Rock, icon, 36, Color3.new(1, 1, 1), Enum.Font.Gotham)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(48, 48)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextTransparency = if loot and loot.Kind ~= "Stone" then 0 else 0.6
	local pop = scaleOf(ui.Rock)
	pop.Scale = 0.3
	tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- The gem pop-up over the wall ------------------------------------------------------------------------------

local function gemPopup(loot)
	local color = GemConfig.TierColors[loot.Rarity] or P.Gold
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 40,
	}, cave)
	UiKit.round(card, 18)
	new("UIStroke", { Color = color, Thickness = 5 }, card)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.8)),
	}, card)
	local ribbon = text(card, RARITY_NAMES[loot.Rarity] or "GEM", 18, Color3.new(1, 1, 1), CHUNKY)
	ribbon.AutomaticSize = Enum.AutomaticSize.None
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0)
	ribbon.Size = UDim2.fromOffset(170, 32)
	ribbon.BackgroundTransparency = 0
	ribbon.BackgroundColor3 = color
	ribbon.TextXAlignment = Enum.TextXAlignment.Center
	ribbon.TextYAlignment = Enum.TextYAlignment.Center
	ribbon.ZIndex = 42
	UiKit.round(ribbon, 10)
	local border = Instance.new("UIStroke")
	border.Color = INK
	border.Thickness = 3
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = ribbon
	local title = text(card, if loot.Lucky then "LUCKY STRIKE!" else "YOU FOUND A GEM!", 22, P.Gold, HEADING)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Position = UDim2.fromOffset(0, 24)
	title.Size = UDim2.new(1, 0, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 42
	local stage = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(160, 150),
		ZIndex = 41,
	}, card)
	if loot.Gem then
		pcall(GemArt.viewport, stage, loot.Gem, true)
	end
	local name = text(card, loot.Text, 22, Color3.new(1, 1, 1), HEADING)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Position = UDim2.fromOffset(8, 210)
	name.Size = UDim2.new(1, -16, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.ZIndex = 42
	local gem = loot.Gem
	local stats = text(
		card,
		if gem
			then string.format("Size %d  •  Clarity %d  •  💰 %d", gem.Size, gem.Clarity, GemConfig.value(gem))
			else "",
		15,
		Color3.fromRGB(240, 235, 250),
		CHUNKY
	)
	stats.AutomaticSize = Enum.AutomaticSize.None
	stats.Position = UDim2.fromOffset(8, 244)
	stats.Size = UDim2.new(1, -16, 0, 20)
	stats.TextXAlignment = Enum.TextXAlignment.Center
	stats.ZIndex = 42
	local hint = text(card, "click to keep digging", 12, Color3.fromRGB(220, 210, 230), CHUNKY)
	hint.AutomaticSize = Enum.AutomaticSize.None
	hint.Position = UDim2.fromOffset(0, 272)
	hint.Size = UDim2.new(1, 0, 0, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.ZIndex = 42
	local pop = new("UIScale", { Scale = 0.2 }, card)
	tween(pop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	chime()
	local closer = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 45,
	}, card)
	local function dismiss()
		if card.Parent then
			tween(pop, 0.15, { Scale = 0 })
			task.delay(0.16, function()
				card:Destroy()
			end)
		end
	end
	closer.Activated:Connect(dismiss)
	task.delay(if tutorialMode then 30 else 2.6, dismiss)
end

-- Drawing -------------------------------------------------------------------------------------------------

local drawButtons, refreshSide

local function drawWall()
	for _, child in wallHolder:GetChildren() do
		child:Destroy()
	end
	table.clear(tiles)
	if not wall then
		return
	end
	for index, data in wall.Tiles do
		local ui = makeTile(index, data)
		tiles[index] = ui
		if data.Hp <= 0 then
			showHollow(ui, data.Loot)
		end
		ui.Button.Activated:Connect(function()
			MineUI.swing(index)
		end)
		-- Rocks drop in one by one.
		local drop = scaleOf(ui.Rock)
		drop.Scale = 0
		task.delay(0.015 * index, function()
			tween(drop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

local function showOverlay(show: boolean)
	overlay.Visible = show
	for _, child in overlayList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function startScreen()
	showOverlay(true)
	local title = text(overlayList, "THE MINE", 48, P.Gold, HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 1
	local lines = {
		"Survey each rock face. You have " .. Mine.Swings .. " strikes to uncover its rewards.",
		"Glinting rock holds Saga Stones. Speckled deposits yield salvage.",
		"Finish the rock face, then descend. Deeper shafts offer rarer discoveries.",
	}
	for n, line in lines do
		local label = text(overlayList, line, 17, Color3.fromRGB(240, 230, 220), CHUNKY)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.LayoutOrder = 1 + n
	end
	local go = IronUi.gemButton(overlayList, "⛏️  START DIGGING", P.Emerald, function()
		MineUI.begin()
	end)
	go.LayoutOrder = 10
	go.Size = UDim2.fromOffset(0, 60)
	go.TextSize = 26
	if quota and quota.BestDepth and quota.BestDepth > 0 then
		local best = text(overlayList, "Your deepest dig: depth " .. quota.BestDepth, 15, P.Gold, CHUNKY)
		best.TextXAlignment = Enum.TextXAlignment.Center
		best.LayoutOrder = 11
	end
end

local function outOfSwings()
	showOverlay(true)
	local title = text(overlayList, "OUT OF SWINGS!", 44, Color3.new(1, 1, 1), HEADING)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 1
	local sub = text(overlayList, "Descend to a new wall: deeper rock holds rarer gems.", 18, P.Gold, CHUNKY)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.LayoutOrder = 2
	overlay.BackgroundTransparency = 1
	tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
end

function refreshSide()
	local swings = if wall then wall.Swings else 0
	local max = if wall and wall.Tutorial then Mine.TutorialSwings else Mine.Swings
	swingCount.Text = tostring(swings)
	tween(swingBar, 0.2, { Size = UDim2.fromScale(math.clamp(swings / max, 0, 1), 1) })
	swingBar.BackgroundColor3 = if swings <= 3 then P.Bad else P.Gold
	if wall then
		depthBanner.Text = if wall.Tutorial then "YOUR FIRST DIG" else "DEPTH " .. wall.Depth
		depthHint.Text = if wall.Tutorial
			then "Hit the glinting rock!"
			else string.format("Gem luck +%d%%", math.floor(Mine.luck(wall.Depth) * 100 + 0.5))
	else
		depthBanner.Text = "READY TO DIG"
		depthHint.Text = ""
	end
	if wall and wall.Tutorial then
		costLine.Text = "🎁 Your first wall is on the house!"
	elseif quota then
		costLine.Text = if quota.FreeLeft > 0
			then string.format("🎟️ Free walls today: %d / %d", quota.FreeLeft, quota.Daily)
			else string.format("Next wall: 💰 %d  (free walls reset daily)", quota.Price)
	end
	if quota then
		window.Subtitle.Text = string.format("Deepest dig: depth %d", quota.BestDepth or 0)
	end
	drawButtons()
end

function drawButtons()
	for _, child in buttons:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if tutorialMode then
		if wall and foundCount > 0 then
			local done = IronUi.gemButton(buttons, "CONTINUE  ►", P.Emerald, function()
				if tutorialDone then
					tutorialFinished = true
					tutorialDone:Fire()
				end
			end)
			done.Size = UDim2.fromOffset(0, 56)
			done.TextSize = 22
		end
		return
	end
	if not wall then
		return
	end
	local cost = if quota and quota.FreeLeft > 0
		then "free"
		else "💰 " .. tostring(quota and quota.Price or Mine.WallPrice)
	local descend = IronUi.gemButton(buttons, "⬇  DESCEND  (" .. cost .. ")", Color3.fromRGB(255, 170, 30), function()
		MineUI.descend()
	end)
	descend.Size = UDim2.fromOffset(0, 56)
	descend.TextSize = 20
	if wall.Swings <= 0 then
		IronUi.animate(descend, function(t)
			descend.Rotation = math.sin(t * 7) * 2.5
		end)
	end
	IronUi.button(buttons, "Leave the mine", false, function()
		MineUI.leave()
	end)
end

local function setWall(newWall, newQuota)
	wall = newWall
	quota = newQuota or quota
	clearTray()
	if wall then
		showOverlay(false)
		for _, t in wall.Tiles do
			if t.Loot then
				addToTray(t.Loot)
			end
		end
		drawWall()
		if wall.Swings <= 0 then
			outOfSwings()
		end
	else
		drawWall()
		startScreen()
	end
	refreshSide()
end

-- Actions -------------------------------------------------------------------------------------------------

local function request(action: string, ...: any)
	busy = true
	local result = GemClient.request(action, ...)
	busy = false
	return result
end

function MineUI.begin()
	if busy then
		return
	end
	local result = request("MineStart", tutorialMode)
	if not result.Ok then
		UiKit.toast(result.Message, P.Bad)
		quota = result.Quota or quota
		refreshSide()
		-- Never leave a new player stuck in the tutorial.
		if tutorialMode and tutorialDone then
			tutorialFinished = true
			tutorialDone:Fire()
		end
		return
	end
	setWall(result.Wall, result.Quota)
end

function MineUI.descend()
	if busy then
		return
	end
	local result = request("MineDescend")
	if not result.Ok then
		UiKit.toast(result.Message, P.Bad)
		quota = result.Quota or quota
		refreshSide()
		return
	end
	-- A quick dark flash: down we go.
	local flash = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
	}, cave)
	UiKit.round(flash, 16)
	tween(flash, 0.45, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		flash:Destroy()
	end)
	setWall(result.Wall, result.Quota)
	floatWord(cave, "DEPTH " .. result.Wall.Depth .. "!", P.Gold, 40)
end

function MineUI.leave()
	task.spawn(function()
		request("MineLeave")
		setWall(nil, quota)
	end)
end

function MineUI.swing(index: number)
	local ui = tiles[index]
	if not wall or not ui or ui.Broken or busy then
		return
	end
	if wall.Swings <= 0 then
		outOfSwings()
		return
	end
	-- The server takes one request at a time (about 5 a second).
	local now = os.clock()
	if now - lastSwing < 0.22 then
		return
	end
	lastSwing = now
	-- Feel it right away: shake, chips and a clink; the result follows.
	local punch = scaleOf(ui.Rock)
	punch.Scale = 0.88
	tween(punch, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local base = ui.Rock.Rotation
	ui.Rock.Rotation = base + (if math.random() < 0.5 then -6 else 6)
	tween(ui.Rock, 0.15, { Rotation = base })
	dust(ui.Button, Color3.fromRGB(170, 150, 130), 5)
	clink(false)
	task.spawn(function()
		local result = request("MineHit", index)
		if not result.Ok then
			if result.Message ~= "" then
				UiKit.toast(result.Message, P.Bad)
			end
			return
		end
		wall.Swings = result.Swings
		wall.Tiles[index] = result.Tile
		quota = result.Quota or quota
		if result.Crit then
			floatWord(ui.Button, "CRIT!", Color3.fromRGB(255, 150, 40), 26)
			shakeWall(4)
		end
		if result.Loot then
			local loot = result.Loot
			showHollow(ui, loot)
			dust(ui.Button, Color3.fromRGB(120, 105, 95), 10)
			clink(true)
			shakeWall(if loot.Kind == "Gem" then 8 else 3)
			local _, color = lootIcon(loot)
			if loot.Kind == "Gem" then
				floatWord(ui.Button, "GEM!", color, 30)
				gemPopup(loot)
			elseif loot.Kind ~= "Stone" then
				floatWord(ui.Button, lootText(loot), color, 18)
			end
			addToTray(loot)
			if loot.Gear then
				-- A lucky rock can hold the next armor set up the ladder.
				UiKit.toast(string.format("EQUIPMENT RECOVERED: %s! Wear it from Gear & Enchant.", loot.Gear), P.Gold)
			end
		else
			drawPips(ui, result.Tile.Hp)
			showCracks(ui, result.Tile.Hp, result.Tile.MaxHp)
		end
		if wall.Swings <= 0 and not tutorialMode then
			task.delay(0.6, outOfSwings)
		end
		refreshSide()
	end)
end

-- Opening -------------------------------------------------------------------------------------------------

function MineUI.open()
	tutorialMode = false
	window.Close.Visible = true
	window.Gui.Enabled = true
	task.spawn(function()
		local result = request("MineState")
		if result.Ok then
			setWall(result.Wall, result.Quota)
		end
	end)
end

function MineUI.close()
	window.Gui.Enabled = false
end

function MineUI.toggle()
	if window.Gui.Enabled then
		MineUI.close()
	else
		MineUI.open()
	end
end

-- The intro's first dig: a free wall with your first stone in it. Yields
-- until the player presses CONTINUE (or closes it).
function MineUI.tutorial()
	tutorialMode = true
	window.Close.Visible = false
	window.Gui.Enabled = true
	tutorialDone = Instance.new("BindableEvent")
	tutorialFinished = false
	setWall(nil, nil)
	showOverlay(false)
	MineUI.begin()
	if not tutorialFinished then
		tutorialDone.Event:Wait()
	end
	tutorialDone:Destroy()
	tutorialDone = nil
	tutorialMode = false
	window.Close.Visible = true
	window.Gui.Enabled = false
end

window.Close.Activated:Connect(MineUI.close)
window.Shade.Activated:Connect(function()
	if not tutorialMode then
		MineUI.close()
	end
end)
GemClient.Changed:Connect(function()
	if window.Gui.Enabled and not busy and quota and GemClient.Profile then
		refreshSide()
	end
end)

return MineUI
