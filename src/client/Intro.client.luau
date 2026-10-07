-- Launch ceremony: server-owned outcomes, simultaneous reels, a spotlight for every reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Classes = require(ReplicatedStorage.Shared.Classes)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Lottery = require(ReplicatedStorage.Shared.StarterLottery)
local ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Art = require(script.Parent.Modules.LotteryArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local LotterySound = require(script.Parent.Modules.LotterySound)
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end
-- After the splash intro.
while game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Splash") do
	task.wait(0.1)
end
local new = IronUi.new
-- A clean launch screen: deep navy, one gold call to action, a cyan accent,
-- and each reward's rarity colour carrying the moment.
local C = {
	Ink = Color3.fromRGB(7, 10, 17),
	Panel = Color3.fromRGB(15, 21, 31),
	Card = Color3.fromRGB(18, 25, 36),
	Line = Color3.fromRGB(44, 58, 76),
	Edge = Color3.fromRGB(70, 86, 106),
	Text = Color3.fromRGB(240, 244, 250),
	Dim = Color3.fromRGB(138, 156, 178),
	Faint = Color3.fromRGB(78, 94, 114),
	Cyan = Color3.fromRGB(94, 206, 221),
	Gold = Color3.fromRGB(240, 186, 92),
}
local gui = UiKit.gui("Intro", 15)
-- Full bleed: the starfield runs under the Roblox top bar too.
gui.IgnoreGuiInset = false
local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 115, Color = ColorSequence.new(C.Ink, Color3.fromRGB(16, 22, 42)) }, back)
local function frame(parent, props)
	props.BorderSizePixel = 0
	return new("Frame", props, parent)
end
local function label(parent, value, size, color, font)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		Font = font or Enum.Font.GothamBold,
		TextColor3 = color or C.Text,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
	}, parent)
end
local function tween(object, seconds, props, style)
	TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		:Play()
end
local function stroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	}, parent)
end
-- A soft round glow: stacked discs, faintest outside.
local function halo(parent, position, scale, color)
	local discs = {}
	for i, spec in { { 1, 0.95 }, { 0.72, 0.93 }, { 0.46, 0.9 } } do
		local disc = frame(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(scale * spec[1], scale * spec[1]),
			BackgroundColor3 = color,
			BackgroundTransparency = spec[2],
			ZIndex = 1,
		})
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, disc)
		UiKit.round(disc, 999)
		discs[i] = disc
	end
	return discs
end
-- A few faint stars, no imported imagery or fullscreen flashes.
for i = 1, 28 do
	local x = ((i * 43) % 101) / 100
	local y = ((i * 29) % 97) / 96
	frame(back, {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(if i % 5 == 0 then 2 else 1, if i % 5 == 0 then 2 else 1),
		BackgroundColor3 = C.Text,
		BackgroundTransparency = if i % 5 == 0 then 0.55 else 0.75,
	})
end
local panel = frame(back, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1, -24, 1, -16),
})
new("UISizeConstraint", { MaxSize = Vector2.new(1200, 880) }, panel)
local brand = label(panel, "SAGA MINERS  ·  LAUNCH", 11, C.Cyan)
brand.Position, brand.Size = UDim2.fromOffset(0, 0), UDim2.new(0.5, 0, 0, 18)
-- The three steps of the launch, top right.
local STEPS = { "EQUIPMENT", "GEMSTONES", "BEGIN" }
local stepper = frame(panel, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(330, 18),
})
local steps = {}
for index, name in STEPS do
	local item = frame(stepper, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale((index - 1) / 3, 0),
		Size = UDim2.fromScale(1 / 3, 1),
	})
	local dot = frame(item, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.Faint,
	})
	UiKit.round(dot, 999)
	local text = label(item, string.format("%d  %s", index, name), 10, C.Faint)
	text.Position, text.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -14, 1, 0)
	steps[index] = { Dot = dot, Text = text }
end
local function setStep(active)
	for index, step in steps do
		local color = if index < active then C.Cyan elseif index == active then C.Gold else C.Faint
		step.Dot.BackgroundColor3, step.Text.TextColor3 = color, color
	end
end
setStep(1)
local title = label(panel, "YOUR LEGEND BEGINS", 34)
title.Position, title.Size = UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 42)
local subtitle =
	label(panel, "Choose your armor style and element. Change your build later.", 14, C.Dim, Enum.Font.Gotham)
subtitle.Position, subtitle.Size = UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 22)
local body = frame(panel, { BackgroundTransparency = 1 })
-- The spotlight: the latest reward, big.
local hero = frame(body, { BackgroundColor3 = C.Panel, ClipsDescendants = true })
UiKit.round(hero, 12)
local heroStroke = stroke(hero, C.Line, 0, 1)
new(
	"UIGradient",
	{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(19, 29, 43), Color3.fromRGB(11, 15, 24)) },
	hero
)
local heroHalo = halo(hero, UDim2.fromScale(0.5, 0.45), 0.8, C.Cyan)
local ring = frame(hero, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.62, 0.62),
	BackgroundTransparency = 1,
	ZIndex = 1,
})
new("UIAspectRatioConstraint", { AspectRatio = 1 }, ring)
UiKit.round(ring, 999)
local ringStroke = stroke(ring, C.Cyan, 0.8, 1)
-- One bright mote orbiting the ring.
local orbitMarks = {}
for index = 0, 1 do
	local mark = frame(ring, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, index),
		Size = UDim2.fromOffset(if index == 0 then 6 else 4, if index == 0 then 6 else 4),
		BackgroundColor3 = C.Cyan,
		BackgroundTransparency = if index == 0 then 0 else 0.5,
		ZIndex = 2,
	})
	UiKit.round(mark, 999)
	table.insert(orbitMarks, mark)
end
-- The rarity badge, top right: its name and five pips.
local crest = frame(hero, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(150, 30),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.25,
	ZIndex = 6,
})
UiKit.round(crest, 999)
local crestStroke = stroke(crest, C.Gold, 0.35, 1)
local crestTitle = label(crest, "SEALED", 11, C.Gold)
crestTitle.Position, crestTitle.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -66, 1, 0)
crestTitle.ZIndex = 7
local rarityPips = {}
for index = 1, 5 do
	local pip = frame(crest, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -60 + (index - 1) * 9, 0.5, 0),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = C.Line,
		ZIndex = 7,
	})
	UiKit.round(pip, 999)
	table.insert(rarityPips, pip)
end
local heroKicker = label(hero, "YOUR LAUNCH CAPSULE", 11, C.Cyan)
heroKicker.Position, heroKicker.Size = UDim2.fromOffset(20, 22), UDim2.new(1, -200, 0, 18)
heroKicker.ZIndex = 5
local heroArt = frame(hero, { BackgroundTransparency = 1, ZIndex = 2 })
local heroName = label(hero, "A NEW WARRIOR AWAKENS", 28)
heroName.ZIndex = 5
local heroMeta = label(hero, "6 EQUIPMENT PIECES  ·  3 STARTER GEMS", 12, C.Dim, Enum.Font.GothamMedium)
heroMeta.ZIndex = 5
local scan =
	frame(hero, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Cyan, BackgroundTransparency = 0.85, ZIndex = 4 })
-- The manifest: every reel, then every reward.
local rack = frame(body, { BackgroundTransparency = 1 })
local rackTitle = label(rack, "LAUNCH MANIFEST", 11, C.Dim)
rackTitle.Size = UDim2.new(0.7, 0, 0, 18)
local counter = label(rack, "0 / 6", 11, C.Cyan)
counter.TextXAlignment = Enum.TextXAlignment.Right
counter.Position, counter.Size = UDim2.fromScale(0.7, 0), UDim2.new(0.3, 0, 0, 18)
local rail = frame(rack, {
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = C.Line,
})
UiKit.round(rail, 999)
local railFill = frame(rail, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold })
UiKit.round(railFill, 999)
local stage = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.Edge,
	CanvasSize = UDim2.new(),
}, rack)
local grid =
	new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, stage)
local footer = frame(panel, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 96),
})
local primary = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 0, 0, 52),
	Text = "REVEAL MY STARTER KIT",
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextColor3 = C.Ink,
	BackgroundColor3 = C.Gold,
	AutoButtonColor = false,
}, footer)
UiKit.round(primary, 10)
new("UISizeConstraint", { MaxSize = Vector2.new(420, 52) }, primary)
new(
	"UIGradient",
	{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 214, 140), Color3.fromRGB(232, 162, 70)) },
	primary
)
local buttonStroke = stroke(primary, Color3.fromRGB(255, 232, 186), 0.45, 1)
-- Quiet secondary controls under the main button.
local function ghost(text, anchorX)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.new(anchorX, 0, 0, 64),
		Size = UDim2.fromOffset(if anchorX == 0 then 214 else 120, 28),
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = C.Dim,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
	}, footer)
	UiKit.round(b, 999)
	stroke(b, C.Line, 0, 1)
	return b
end
local skip = ghost("Skip reveal · keep all rewards", 0)
local motion = ghost("Motion: full", 1)
local cards, connections = {}, {}
local phase, reward, busy, spin, calm, closed = "Welcome", nil, false, nil, false, false
local heroRecord, heroStart = Art.show(heroArt, nil, nil, C.Cyan, true), os.clock()
local horizontal = false
local function listen(signal, fn)
	table.insert(connections, signal:Connect(fn))
end
local savedKit = GemClient.Profile.Intro and GemClient.Profile.Intro.Lottery
local chosenStyle, chosenElement = savedKit and savedKit.Style or "Prospector", savedKit and savedKit.Element or "Fire"
if savedKit then primary.Text = "CONTINUE MY SAVED REVEAL" end
local choices = frame(body, {Size=UDim2.fromScale(1,1), BackgroundColor3=C.Ink, ZIndex=20})
local function choiceHeading(text, y)
	local heading = label(choices, text, 14, C.Dim)
	heading.Position, heading.Size, heading.ZIndex = UDim2.fromScale(0, y), UDim2.fromScale(1, .1), 21
end
choiceHeading("1  ARMOR STYLE · Common sword, shield and full armor", 0)
choiceHeading("2  STARTER ELEMENT · Three beginner Surge gems", .43)
local styleButtons, elementButtons = {}, {}
local styleColors = {Prospector=C.Gold, Skirmisher=C.Cyan, Juggernaut=Color3.fromRGB(232,125,75)}
local function refreshChoices()
	for id, button in styleButtons do
		button.BackgroundColor3 = if id == chosenStyle then styleColors[id] else C.Card
		button.TextColor3 = if id == chosenStyle then C.Ink else C.Text
	end
	for id, button in elementButtons do
		button.BackgroundColor3 = if id == chosenElement then GemConfig.ElementColors[id] else C.Card
		button.TextColor3 = if id == chosenElement then C.Ink else C.Text
	end
end
for i, entry in {{"Prospector", "PROSPECTOR\nAmber · Balanced"}, {"Skirmisher", "SKIRMISHER\nTeal · Mobile"}, {"Juggernaut", "JUGGERNAUT\nHeavy · Defensive"}} do
	local button = new("TextButton", {Position=UDim2.fromScale((i-1)/3,.13), Size=UDim2.new(1/3,-8,.25,0), Text=entry[2], TextSize=16, TextWrapped=true, Font=Enum.Font.GothamBold, ZIndex=21}, choices)
	UiKit.round(button, 10)
	styleButtons[entry[1]] = button
	listen(button.Activated, function() if not savedKit and not busy then chosenStyle=entry[1]; refreshChoices() end end)
end
for i, element in {"Fire", "Frost", "Shock", "Poison"} do
	local button = new("TextButton", {Position=UDim2.fromScale((i-1)/4,.56), Size=UDim2.new(.25,-8,.2,0), Text=GemConfig.elementName(element), TextSize=15, Font=Enum.Font.GothamBold, ZIndex=21}, choices)
	UiKit.round(button, 10)
	elementButtons[element] = button
	listen(button.Activated, function() if not savedKit and not busy then chosenElement=element; refreshChoices() end end)
end
choiceHeading("Common starter gems · Any Surge on Q / E / R · Mine for new abilities and rarities", .83)
refreshChoices()
skip.Visible = false
local SURGE_KEYS = {}
for key, slot in Tech.SurgeSockets do
	SURGE_KEYS[slot] = key
end
local function slotName(slot)
	if SURGE_KEYS[slot] then
		return "Gem Surge  ·  " .. SURGE_KEYS[slot]
	end
	return (Slots.SurgeDefinitions[slot] or Slots.Definitions[slot]).Label
end
local function fit()
	local w, h = panel.AbsoluteSize.X, panel.AbsoluteSize.Y
	local short = h < 480
	local narrow = w < 650
	local header = if short then 48 elseif narrow then 92 else 106
	-- Short (phone) screens: the quiet buttons flank the main one in a single
	-- footer row, so the gems get the height.
	local oneRow = short and w >= 480
	footer.Size = UDim2.new(1, 0, 0, if oneRow then 48 else 96)
	primary.Size = UDim2.new(if oneRow then 0.4 else 1, 0, 0, if oneRow then 44 else 52)
	for _, b in { skip, motion } do
		b.Position = UDim2.new(b.AnchorPoint.X, 0, 0, if oneRow then 8 else 64)
	end
	skip.Size = UDim2.fromOffset(if oneRow then math.min(168, w * 0.28) else math.min(214, w * 0.58), 28)
	skip.Text = if oneRow then "Skip · keep rewards" else "Skip reveal · keep all rewards"
	local bodyHeight = math.max(80, h - header - (if oneRow then 54 else 108))
	title.TextSize = if w < 420 then 20 elseif w < 500 then 24 elseif short then 20 else 34
	title.Position, title.Size =
		UDim2.fromOffset(0, if short then 18 else 24), UDim2.new(1, 0, 0, if short then 26 else 42)
	subtitle.Visible = not short
	subtitle.Position = UDim2.fromOffset(0, if narrow then 62 else 70)
	stepper.Visible = w >= 560
	body.Position, body.Size = UDim2.fromOffset(0, header), UDim2.new(1, 0, 0, bodyHeight)
	local portrait = narrow and h > w
	horizontal = false
	if portrait then
		local heroHeight = math.max(100, bodyHeight * 0.32)
		hero.Position, hero.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, heroHeight)
		rack.Position, rack.Size =
			UDim2.fromOffset(0, heroHeight + 12), UDim2.new(1, 0, 0, bodyHeight - heroHeight - 12)
	else
		hero.Position, hero.Size = UDim2.fromOffset(0, 0), UDim2.new(if short then 0.34 else 0.42, -10, 1, 0)
		rack.Position, rack.Size =
			UDim2.new(if short then 0.34 else 0.42, 12, 0, 0), UDim2.new(if short then 0.66 else 0.58, -12, 1, 0)
	end
	stage.Position = UDim2.fromOffset(0, if short then 26 else 38)
	stage.Size = UDim2.new(1, 0, 1, if short then -26 else -38)
	local compact = portrait or short
	heroKicker.Visible = not compact
	crest.Visible = not compact
	heroArt.Position, heroArt.Size =
		UDim2.fromOffset(12, if compact then 6 else 46), UDim2.new(1, -24, 1, if compact then -62 else -128)
	heroName.Position, heroName.Size =
		UDim2.new(0, 20, 1, if compact then -52 else -70), UDim2.new(1, -40, 0, if compact then 26 else 34)
	heroName.TextSize = if compact then 14 else 28
	heroMeta.Position, heroMeta.Size = UDim2.new(0, 20, 1, if compact then -26 else -34), UDim2.new(1, -40, 0, 18)
	local rows = if phase == "Gems" then 3 else 2
	local cellHeight = math.max(1, (stage.AbsoluteSize.Y - (rows - 1) * 10 - 4) / rows)
	for _, card in cards do
		local tiny = cellHeight < 110
		card.Art.Position = UDim2.fromOffset(4, if tiny then 18 else 26)
		card.Art.Size = if tiny then UDim2.new(0.3, -4, 1, -22) else UDim2.new(1, -12, 1, -70)
		card.Name.Position = if tiny then UDim2.new(0.31, 2, 0, 19) else UDim2.new(0, 12, 1, -40)
		card.Name.Size = if tiny then UDim2.new(0.69, -6, 0, 14) else UDim2.new(1, -24, 0, 16)
		card.Name.TextSize = if tiny then 9 else 11
		card.Rarity.Position = if tiny then UDim2.new(0.31, 2, 1, -16) else UDim2.new(0, 12, 1, -22)
		card.Rarity.Size = if tiny then UDim2.new(0.69, -6, 0, 12) else UDim2.new(1, -24, 0, 13)
		card.Rarity.TextSize = if tiny then 8 else 10
	end
	if horizontal then
		grid.FillDirection, grid.FillDirectionMaxCells = Enum.FillDirection.Vertical, 1
		grid.CellSize = UDim2.fromOffset(124, math.max(84, stage.AbsoluteSize.Y - 5))
		stage.AutomaticCanvasSize, stage.ScrollingDirection = Enum.AutomaticSize.X, Enum.ScrollingDirection.X
	else
		grid.FillDirection, grid.FillDirectionMaxCells = Enum.FillDirection.Horizontal, 3
		grid.CellSize = UDim2.new(1 / 3, -7, 0, math.max(1, (stage.AbsoluteSize.Y - (rows - 1) * 10 - 4) / rows))
		stage.AutomaticCanvasSize, stage.ScrollingDirection = Enum.AutomaticSize.None, Enum.ScrollingDirection.Y
		stage.CanvasSize, stage.CanvasPosition = UDim2.new(), Vector2.zero
		stage.ScrollingEnabled = false
	end
end
-- The names a slot's reel flashes while it spins: only gear the lottery can
-- actually hand out (the starting pool, never a switched-off pistol), so the
-- reel never teases something you can't get.
local reelPools = {}
local function reelPool(kind: string)
	if not reelPools[kind] then
		local class = Classes.get(GemClient.Profile.Character.Class)
		local catalog = class and class[kind] or {}
		local pool = {}
		for _, item in catalog do
			if item.StartPool and ExpandedTraits.obtainable(item) then
				table.insert(pool, item)
			end
		end
		reelPools[kind] = if #pool > 0 then pool else catalog
	end
	return reelPools[kind]
end
local function describe(entry, isGem)
	if isGem then
		local gem = entry.Gem
		local element = GemConfig.ElementLabels[gem.Element] or gem.Element
		-- A surge gem names the power it casts; a gear gem its cut.
		local surge = SURGE_KEYS[entry.Slot] and Tech.surgeStats(gem)
		local detail = if surge
			then string.format("%s  ·  %s %s", element, surge.Name, Tech.rarityLabel(entry.Gem))
			else string.format("%s  ·  CUT %d", element, gem.Cut or 0)
		return GemConfig.shade(gem).Name,
			GemConfig.TierColors[gem.Tier],
			GemConfig.TierLabels[gem.Tier] or gem.Tier,
			detail
	end
	local c = GemClient.Profile.Character
	local kind = Slots.Definitions[entry.Slot].Kind
	local item = Classes.gear(c.Class, kind, entry.Id)
	local roll = c.GearRolls and c.GearRolls[kind] and c.GearRolls[kind][entry.Id]
	local rarity = GearRolls.Rarities[(roll and roll.Rarity) or 1]
	return if item then item.Name else entry.Id,
		rarity.Color,
		rarity.Name,
		if item then item.ArmorFamily or slotName(entry.Slot) else slotName(entry.Slot)
end
local function burst(color, major, rank)
	if calm then
		return
	end
	for i = 1, if major then 30 else 8 + (rank or 1) * 3 do
		local shard = frame(hero, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(if i % 3 == 0 then 3 else 2, if i % 3 == 0 then 12 else 4),
			BackgroundColor3 = color,
			Rotation = i * 31,
			ZIndex = 8,
		})
		local a = i * 2.4
		tween(shard, 0.7, {
			Position = UDim2.new(0.5, math.cos(a) * (70 + i * 2), 0.4, math.sin(a) * (45 + i * 2)),
			BackgroundTransparency = 1,
			Rotation = i * 50,
		})
		task.delay(0.75, function()
			shard:Destroy()
		end)
	end
end
local RANKS = { Common = 1, Uncommon = 2, Rare = 3, ["Ultra Rare"] = 4, ["Ultra-Rare"] = 4, Legendary = 5 }
local function paintHero(color, rank)
	for index, pip in rarityPips do
		pip.BackgroundColor3 = if index <= rank then color else C.Line
	end
	for _, mark in orbitMarks do
		mark.BackgroundColor3 = color
	end
	for _, disc in heroHalo do
		disc.BackgroundColor3 = color
	end
	heroStroke.Color, heroStroke.Transparency = color, if rank >= 3 then 0.2 else 0.5
	ringStroke.Color = color
end
local function spotlight(card, celebrate)
	if not card.Stopped then
		return
	end
	local name, color, rarity, detail = describe(card.Entry, phase == "Gems")
	heroName.Text, heroMeta.Text = name, rarity:upper() .. "  ·  " .. detail:upper()
	heroKicker.Text = slotName(card.Entry.Slot):upper()
	local rank = RANKS[rarity] or 1
	crestTitle.Text, crestTitle.TextColor3, crestStroke.Color = rarity:upper(), color, color
	heroKicker.TextColor3, heroMeta.TextColor3 = color, color:Lerp(C.Text, 0.35)
	paintHero(color, rank)
	heroRecord = Art.show(heroArt, if phase == "Gems" then card.Entry.Gem else nil, card.Entry.Slot, color, false)
	heroStart = os.clock()
	for _, other in cards do
		if other.Stopped then
			local _, otherColor = describe(other.Entry, phase == "Gems")
			other.Stroke.Color = otherColor
			other.Stroke.Thickness, other.Stroke.Transparency =
				if other == card then 2 else 1, if other == card then 0 else 0.55
		end
	end
	if celebrate then
		if not calm then
			heroRecord.Camera.FieldOfView = 44
			tween(heroRecord.Camera, 0.55, { FieldOfView = 34 }, Enum.EasingStyle.Back)
		end
		local major = card.Index == #cards
		burst(color, major, rank)
		-- The reel locks with a clamp, then the find rings out by rarity.
		LotterySound.play("Lock")
		task.delay(0.08, function()
			LotterySound.reveal(rank)
		end)
	end
end
local function createCards(entries)
	for _, card in cards do
		card.Frame:Destroy()
	end
	table.clear(cards)
	stage.CanvasPosition = Vector2.zero
	for index, entry in entries do
		local cell = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			BackgroundColor3 = C.Card,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, stage)
		UiKit.round(cell, 10)
		new(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(24, 33, 47), Color3.fromRGB(14, 19, 28)) },
			cell
		)
		local cardStroke = stroke(cell, C.Line, 0, 1)
		local slot = label(cell, slotName(entry.Slot):upper(), 10, C.Dim)
		slot.Position, slot.Size = UDim2.fromOffset(12, 9), UDim2.new(1, -44, 0, 14)
		local pip = label(cell, string.format("%02d", index), 10, C.Faint)
		pip.TextXAlignment = Enum.TextXAlignment.Right
		pip.Position, pip.Size = UDim2.new(1, -36, 0, 9), UDim2.fromOffset(24, 14)
		-- The art sits straight in the card (the reveal draws into it).
		local art = frame(
			cell,
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 26), Size = UDim2.new(1, -12, 1, -70) }
		)
		-- The reel: one name on the line, the ones before and after fading.
		local reel = frame(art, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true })
		local tape = frame(reel, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 78),
		})
		local lines = {}
		for line = 1, 3 do
			local txt = label(
				tape,
				if line == 2 then (if phase == "Welcome" then "SEALED" else "SCANNING…") else "",
				if line == 2 then 12 else 10,
				if line == 2 then C.Text else C.Faint
			)
			txt.Position, txt.Size = UDim2.fromOffset(0, (line - 1) * 26), UDim2.new(1, 0, 0, 26)
			txt.TextXAlignment = Enum.TextXAlignment.Center
			txt.TextTransparency = if line == 2 then 0 else 0.35
			table.insert(lines, txt)
		end
		-- The payline: two hairlines framing the middle name.
		for _, y in { -13, 13 } do
			frame(reel, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, y),
				Size = UDim2.new(0.7, 0, 0, 1),
				BackgroundColor3 = C.Cyan,
				BackgroundTransparency = 0.82,
			})
		end
		local name = label(cell, "AWAITING RELEASE", 11, C.Dim)
		name.Position, name.Size = UDim2.new(0, 12, 1, -40), UDim2.new(1, -24, 0, 16)
		local rarity = label(cell, "", 10, C.Faint)
		rarity.Position, rarity.Size = UDim2.new(0, 12, 1, -22), UDim2.new(1, -24, 0, 13)
		local band = frame(cell, {
			Position = UDim2.new(0, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = C.Line,
		})
		local card = {
			Frame = cell,
			Stroke = cardStroke,
			Art = art,
			Reel = reel,
			Tape = tape,
			Lines = lines,
			Name = name,
			Rarity = rarity,
			Band = band,
			Index = index,
			Entry = entry,
			Stopped = false,
			NextTick = 0,
			Shift = 0,
			Record = nil,
		}
		table.insert(cards, card)
		cell.Activated:Connect(function()
			spotlight(card, false)
		end)
		cell.MouseEnter:Connect(function()
			if card.Stopped then
				cell.BackgroundColor3 = C.Card:Lerp(C.Text, 0.05)
			end
		end)
		cell.MouseLeave:Connect(function()
			cell.BackgroundColor3 = C.Card
		end)
	end
	fit()
end
local placeholders = {}
for _, slot in Lottery.GearOrder do
	table.insert(placeholders, { Slot = slot })
end
createCards(placeholders)
local function showCard(card)
	local name, color, rarity = describe(card.Entry, phase == "Gems")
	card.Reel.Visible = false
	card.Name.Text, card.Name.TextColor3 = name, C.Text
	card.Rarity.Text, card.Rarity.TextColor3 = rarity:upper(), color
	card.Band.BackgroundColor3, card.Stroke.Color = color, color
	card.Record = Art.show(card.Art, if phase == "Gems" then card.Entry.Gem else nil, card.Entry.Slot, color, false)
	card.Frame:SetAttribute("RewardName", name)
	spotlight(card, true)
	local position = card.Frame.AbsolutePosition - stage.AbsolutePosition + stage.CanvasPosition
	stage.CanvasPosition = Vector2.zero
end
local function animate(entries, isGem)
	phase = if isGem then "Gems" else "Armor"
	createCards(entries)
	counter.Text = string.format("0 / %d", #entries)
	railFill.Size = UDim2.fromScale(0, 1)
	crestTitle.Text = "OPENING"
	crestTitle.TextColor3, crestStroke.Color = C.Gold, C.Gold
	paintHero(if isGem then C.Gold else C.Cyan, 0)
	heroRecord = Art.show(heroArt, nil, nil, if isGem then C.Gold else C.Cyan, true)
	heroStart = os.clock()
	heroName.Text = if isGem then "YOUR FIRST THREE SURGES" else "ASSEMBLING YOUR LOADOUT"
	heroMeta.Text = "YOUR CHOICES · YOUR STARTER KIT"
	heroMeta.TextColor3 = C.Dim
	heroKicker.Text = if isGem then "GEMSTONE RESONANCE" else "EQUIPMENT RELEASE"
	heroKicker.TextColor3 = C.Cyan
	title.Text = if isGem then "POWER, UNEARTHED." else "YOUR LOADOUT. REVEALED."
	subtitle.Text = if isGem
		then "Three Common Surges. Three flexible slots: Q / E / R."
		else "Boots first. Helmet last. Every piece is yours."
	setStep(if isGem then 2 else 1)
	rackTitle.Text = if isGem then "GEMSTONES" else "EQUIPMENT"
	spin = { Start = os.clock(), NextSound = 0, Count = 0 }
	-- The capsule's seal breaks and its reactor starts humming.
	LotterySound.play("SealBreak")
	LotterySound.hum(true, 0)
	for index, card in cards do
		card.StopAt = (if isGem then 1.8 + index * 0.6 else 2 + index * 0.85) + (if index == #cards then 0.65 else 0)
	end
	primary.Text, primary.Active = "REVEAL IN PROGRESS…", false
	primary.BackgroundColor3 = Color3.fromRGB(120, 118, 112)
	primary.TextColor3 = C.Text
	buttonStroke.Transparency = 0.8
end
local function close()
	if closed then
		return
	end
	closed = true
	LotterySound.stop() -- Stop delayed reveal layers too when skipping mid-spin.
	for _, connection in connections do
		connection:Disconnect()
	end
	gui:Destroy()
end
local function finish()
	if busy or closed then
		return
	end
	busy = true
	local previous = primary.Text
	primary.Text = "EQUIPPING YOUR LOADOUT…"
	local result = GemClient.request("FinishStarterLottery")
	if closed then
		return
	end
	busy = false
	if not result.Ok then
		primary.Text = previous
		UiKit.toast(result.Message)
		return
	end
	close()
	LotterySound.play("Attune")
end
listen(RunService.RenderStepped, function(dt)
	if closed then
		return
	end
	local now = os.clock()
	heroRecord.Opening = if spin and spin.Count == 0
		then math.clamp((now - spin.Start - cards[1].StopAt + 0.7) / 0.7, 0, 1)
		else 0
	Art.pose(heroRecord, now - heroStart, calm)
	if not calm then
		ring.Rotation = (now * 24) % 360
	end
	scan.Visible = not calm and spin ~= nil
	if scan.Visible then
		scan.Position = UDim2.fromScale(0, ((now * 0.35) % 0.7) + 0.05)
	end
	for _, card in cards do
		if card.Record then
			Art.pose(card.Record, 0, true)
		end
	end
	if not spin then
		return
	end
	local elapsed = now - spin.Start
	local nextCard = cards[spin.Count + 1]
	for _, card in cards do
		if card.Stopped then
			continue
		end
		local remaining = card.StopAt - elapsed
		local interval = if remaining < 0.9 then 0.12 + (0.9 - math.max(0, remaining)) * 0.22 else 0.055
		card.Shift = (card.Shift + dt / interval) % 1
		card.Tape.Position = UDim2.new(0, 0, 0.5, if calm then 0 else -card.Shift * 26)
		if elapsed >= card.NextTick then
			card.NextTick = elapsed + interval
			for index, line in card.Lines do
				local middle = index == 2
				if reward and reward.Version >= 2 then
					line.Text = (describe(card.Entry, phase == "Gems")):upper()
					line.TextColor3 = if middle then C.Cyan else C.Faint
				elseif phase == "Gems" then
					local element = GemConfig.Elements[math.random(1, #GemConfig.Elements)]
					line.Text = (GemConfig.ElementLabels[element] or element):upper()
					line.TextColor3 = GemConfig.ElementColors[element]:Lerp(C.Text, if middle then 0.15 else 0)
				else
					local pool = reelPool(Slots.Definitions[card.Entry.Slot].Kind)
					line.Text = if #pool > 0 then pool[math.random(1, #pool)].Name:upper() else ""
					line.TextColor3 = if middle then (if card == nextCard then C.Cyan else C.Text) else C.Faint
				end
			end
		end
		card.Stroke.Color = if card == nextCard then C.Cyan else C.Line
		card.Stroke.Thickness = if card == nextCard then 2 else 1
		card.Name.Text = if card == nextCard
			then (if remaining < 0.9 then "LOCKING IN…" else "NEXT TO REVEAL")
			else "ROLLING"
		card.Name.TextColor3 = if card == nextCard then C.Cyan else C.Dim
		if remaining <= 0 then
			card.Stopped = true
			spin.Count += 1
			showCard(card)
			counter.Text = string.format("%d / %d", spin.Count, #cards)
			tween(railFill, 0.28, { Size = UDim2.fromScale(spin.Count / #cards, 1) })
		end
	end
	if nextCard and elapsed >= spin.NextSound then
		-- Soft data blips as the next reel steps, climbing as it slows.
		local left = nextCard.StopAt - elapsed
		spin.NextSound = elapsed + (if left < 1 then 0.24 else 0.11)
		LotterySound.tick(1 - math.clamp(left, 0, 1.5) / 1.5)
		LotterySound.hum(true, spin.Count / #cards)
	end
	if spin.Count == #cards then
		spin = nil
		LotterySound.hum(false)
		primary.Active = true
		primary.BackgroundColor3 = C.Gold
		primary.TextColor3 = C.Ink
		buttonStroke.Transparency = 0.45
		primary.Text = if phase == "Armor" then "REVEAL MY STARTER GEMS" else "EQUIP & BEGIN YOUR SAGA"
		title.Text = if phase == "Armor" then "BUILT FOR YOUR JOURNEY." else "YOUR SAGA STARTS NOW."
		subtitle.Text = if phase == "Armor"
			then "Inspect any piece. Your gemstones are next."
			else "Q / E / R: three different Surges. Mine to expand your build."
		setStep(if phase == "Gems" then 3 else 2)
		heroKicker.Text = "COMPLETE  ·  SELECT ANY REWARD TO INSPECT"
	end
end)
listen(primary.Activated, function()
	if busy or spin or closed then
		return
	end
	if phase == "Welcome" then
		busy = true
		primary.Text = "OPENING YOUR CAPSULE…"
		local result = GemClient.request("PrepareStarterLottery", chosenStyle, chosenElement)
		if closed then
			return
		end
		busy = false
		if not result.Ok then
			primary.Text = "RETRY THE LAUNCH"
			UiKit.toast(result.Message)
			return
		end
		reward = result.Lottery
		choices.Visible = false
		skip.Visible = true
		animate(reward.Gear, false)
	elseif phase == "Armor" then
		animate(reward.Gems, true)
	else
		finish()
	end
end)
listen(skip.Activated, finish)
listen(motion.Activated, function()
	calm = not calm
	motion.Text = if calm then "Motion: calm" else "Motion: full"
end)
listen(primary.MouseEnter, function()
	if not busy and not spin then
		tween(buttonStroke, 0.15, { Thickness = 2, Transparency = 0 })
		tween(primary, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 205, 120) })
	end
end)
listen(primary.MouseLeave, function()
	tween(buttonStroke, 0.15, { Thickness = 1, Transparency = if spin then 0.8 else 0.45 })
	if not spin then
		tween(primary, 0.15, { BackgroundColor3 = C.Gold })
	end
end)
listen(UserInputService.InputBegan, function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Space then
		finish()
	end
end)
listen(panel:GetPropertyChangedSignal("AbsoluteSize"), fit)
listen(stage:GetPropertyChangedSignal("AbsoluteSize"), fit)
listen(gui.Destroying, function()
	if not closed then
		closed = true
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end)
fit()
