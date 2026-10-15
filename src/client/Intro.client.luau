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
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local FastStart = require(ReplicatedStorage.Shared.FastStart)
if not Tutorial.Enabled and not FastStart.Enabled then return end
local Art = require(script.Parent.Modules.LotteryArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local LotterySound = require(script.Parent.Modules.LotterySound)
local Icons = require(script.Parent.Modules.SurgeIcons)
local CardFX = require(script.Parent.Modules.ElementCardFX)
local LoadingFlow = require(script.Parent.Modules.LoadingFlow)
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
-- The tutorial (Shared.Tutorial) replaces the starter picker: the server
-- hands out the kit and Tutorial.client takes it from here.
if Tutorial.Enabled then
	-- Retried until the server has the profile (a slow load must not strand you).
	for attempt = 1, 20 do
		if GemClient.request("TutorialBegin").Ok then
			break
		end
		task.wait(math.min(attempt, 3))
	end
	return
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
local panelLimit = new("UISizeConstraint", { MaxSize = Vector2.new(1200, 880) }, panel)
-- Wide, short phones: the panel stops at about twice its height, so cards
-- and buttons aren't stretched across the whole screen.
local function capPanel()
	local h = back.AbsoluteSize.Y
	if h > 0 then
		panelLimit.MaxSize = Vector2.new(math.clamp(h * 2.05, 560, 1200), 880)
	end
end
capPanel()
back:GetPropertyChangedSignal("AbsoluteSize"):Connect(capPanel)
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
	Text = "BEGIN MY SAGA",
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
local backStep = ghost("‹   Back to styles", 0)
backStep.Visible = false
local motion = ghost("Motion: full", 1)
local cards, connections = {}, {}
local phase, reward, busy, spin, calm, closed = "Welcome", nil, false, nil, false, false
local heroRecord, heroStart = Art.show(heroArt, nil, nil, C.Cyan, true), os.clock()
local horizontal = false
local function listen(signal, fn)
	table.insert(connections, signal:Connect(fn))
end
local savedKit = GemClient.Profile.Intro and GemClient.Profile.Intro.Lottery
local chosenStyle = savedKit and savedKit.Style or "Prospector"
-- Only a previously committed kit restores an element. New choices start empty.
local chosenElement: string? = savedKit and savedKit.Element or nil
if savedKit then primary.Text = "CLAIM MY STARTER KIT" end
-- Choose armor and element independently, then review the starter kit.
local choices = frame(body, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, ZIndex = 20 })
local STYLES = {
	{
		Id = "Prospector",
		Color = GemConfig.ElementColors.Poison, -- card accent only
		Role = "BALANCED  ·  SUSTAIN",
		-- A quick read of the style (ArmorFamilies: Primary stats per piece
		-- and set bonuses), out of 5.
		Profile = { Health = 4, Power = 4, Defense = 3, Speed = 3 },
		Tip = "Trade blows and outlast them. Steady damage, quick to recover.",
		Lines = { "Health and Power on every piece", "Set: +Health, +Power, faster cooldowns", "2+ pieces: +10% attack damage" },
	},
	{
		Id = "Skirmisher",
		Color = GemConfig.ElementColors.Shock, -- card accent only
		Role = "MOBILE  ·  CRITICAL",
		Profile = { Health = 2, Power = 4, Defense = 2, Speed = 5 },
		Tip = "Strike, dodge, strike again. Speed and crits win the race.",
		Lines = { "Speed and Critical chance", "Set: +Speed, +Crit, faster cooldowns", "2+ pieces: +15% attack speed" },
	},
	{
		Id = "Juggernaut",
		Color = GemConfig.ElementColors.Fire, -- card accent only
		Role = "HEAVY  ·  DEFENSIVE",
		Profile = { Health = 5, Power = 3, Defense = 5, Speed = 2 },
		Tip = "Hold the line. Block their best, then punish with heavy hits.",
		Lines = { "Health and Defense", "Set: +Health, +Defense, less damage taken", "2+ pieces: +25% heavy damage" },
	},
}
-- Each style's key art (assets/images/intro/style_*.png, rendered by
-- tools/make_style_cards.py from the game's own fighters). 0 = not uploaded
-- yet: the card shows its crest and text only.
local STYLE_ART = { Prospector = 72266295660132, Skirmisher = 84192854197420, Juggernaut = 76447015122752 }
local ELEMENTS = {
	Fire = "Burn and burst",
	Frost = "Slow, freeze and shield",
	Shock = "Stun and chain",
	Poison = "Shred armor, wear them down",
}
-- What each key can roll: { Q, E, R } lists of move ids (one each once a
-- saved kit has rolled them).
local function surgePools(element)
	if savedKit and savedKit.Element == element and type(savedKit.Moves) == "table" then
		return { { savedKit.Moves[1] }, { savedKit.Moves[2] }, { savedKit.Moves[3] } }
	end
	return Lottery.starterPools(element)
end
local function moveName(id)
	return Tech.Catalog[id] and Tech.Catalog[id].Name or id
end
-- "Furnace Crescent or Magma Fault".
local function surgeNames(element)
	local names = {}
	for _, pool in surgePools(element) do
		local list = {}
		for _, id in pool do
			table.insert(list, moveName(id))
		end
		table.insert(names, table.concat(list, " or "))
	end
	return names
end
local function text(parent, value, size, color, font, props)
	local l = label(parent, value, size, color, font)
	l.ZIndex = 22
	for key, v in props or {} do
		l[key] = v
	end
	return l
end
-- Every piece has a full layout and a compact one (short phone screens):
-- fit() switches them with layoutChoices.
-- Rich (tall screens): extra detail fills the cards and rows.
local relayout, compactMode, richMode = {}, false, false
-- The fast start's two screens: "Style" (three cards), then "Element"
-- (four independent element cards with their Q / E / R move pools).
local pickStep = if savedKit then "Element" else "Style"
local function place(apply)
	table.insert(relayout, apply)
	apply(false, false)
end
local function heading(parent, number, value, step)
	local h = text(parent, number .. "  " .. value, 13, C.Dim, Enum.Font.GothamBold)
	h.TextXAlignment = Enum.TextXAlignment.Left
	place(function(compact)
		h.Visible = pickStep == step
		h.TextSize = if compact then 11 else 13
		h.Position, h.Size = UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, if compact then 16 else 20)
	end)
end
heading(choices, "1 / 2", "FIGHTING STYLE  ·  the armor you start in, with a sword and shield", "Style")
heading(choices, "2 / 2", "ELEMENT  ·  compare the moves, then choose your powers", "Element")

local styleButtons, elementButtons = {}, {}
local refreshChoices -- (below)
-- (The launch button has its own row under the body: nothing to leave.)
local CTA_ROOM = 0
local styleArea = frame(choices, { BackgroundTransparency = 1, ZIndex = 21 })
place(function(compact)
	local top, bottom = if compact then 20 else 28, if compact then 36 else 52
	styleArea.Visible = pickStep == "Style"
	styleArea.Position = UDim2.fromOffset(0, top)
	styleArea.Size = UDim2.new(1, 0, 1, -top - bottom - CTA_ROOM)
end)
for i, style in STYLES do
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Card,
		Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 5, 0, 0),
		Size = UDim2.new(1 / 3, -7, 1, 0),
		ZIndex = 21,
		ClipsDescendants = true,
	}, styleArea)
	card.Name = style.Id
	UiKit.round(card, 10)
	local edge = new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	frame(card, { BackgroundColor3 = style.Color, Size = UDim2.new(1, 0, 0, 4), ZIndex = 22 })
	-- The fighter's key art leads the card when it's uploaded; until then a
	-- crest does, and the text sits higher.
	local artId = STYLE_ART[style.Id] or 0
	local Y0 = if artId ~= 0 then 112 else 0
	local STEP = if artId ~= 0 then 28 else 34
	local art = new("ImageLabel", {
		BackgroundColor3 = C.Ink,
		Image = if artId ~= 0 then "rbxassetid://" .. artId else "",
		ScaleType = Enum.ScaleType.Crop,
		Visible = artId ~= 0,
		ZIndex = 22,
	}, card)
	art.Name = "StyleArt"
	UiKit.round(art, 8)
	new("UIStroke", { Color = style.Color, Thickness = 1, Transparency = 0.4 }, art)
	-- A crest: the family's initial in a diamond of its colour.
	local crest = frame(card, {
		AnchorPoint = Vector2.new(0.5, 0),
		Rotation = 45,
		BackgroundColor3 = style.Color:Lerp(C.Ink, 0.55),
		ZIndex = 22,
		Visible = artId == 0,
	})
	UiKit.round(crest, 8)
	new("UIStroke", { Color = style.Color, Thickness = 2 }, crest)
	local initial = text(card, string.sub(style.Id, 1, 1), 26, style.Color, Enum.Font.GothamBlack)
	initial.AnchorPoint = Vector2.new(0.5, 0)
	initial.TextXAlignment = Enum.TextXAlignment.Center
	initial.Visible = artId == 0
	local name = text(card, string.upper(style.Id), 18, C.Text, Enum.Font.GothamBlack)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local role = text(card, style.Role, 10, style.Color, Enum.Font.GothamBold)
	role.TextXAlignment = Enum.TextXAlignment.Center
	local divider = frame(card, { BackgroundColor3 = C.Line, ZIndex = 22 })
	local perks = {}
	for _, value in style.Lines do
		local dot = text(card, "◆", 8, style.Color, Enum.Font.GothamBold)
		local row = text(card, value, 11, C.Dim, Enum.Font.GothamMedium, { TextWrapped = true })
		row.TextYAlignment = Enum.TextYAlignment.Top
		table.insert(perks, { dot, row })
	end
	local kit = text(card, "Helmet · Chest · Gloves · Boots\nShield · Sword", 10, C.Faint, Enum.Font.GothamMedium)
	kit.AnchorPoint = Vector2.new(0.5, 1)
	kit.TextXAlignment, kit.TextWrapped = Enum.TextXAlignment.Center, true
	local pick = text(card, "SELECTED", 10, C.Ink, Enum.Font.GothamBlack)
	pick.AnchorPoint, pick.Position, pick.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(92, 20)
	-- Rich extras: the armor profile and how it plays.
	local extras = frame(card, { BackgroundTransparency = 1, ZIndex = 22 })
	local profileTitle = text(extras, "STYLE PROFILE", 9, C.Dim, Enum.Font.GothamBold)
	profileTitle.Position, profileTitle.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -28, 0, 12)
	for index, stat in { "Health", "Power", "Defense", "Speed" } do
		local y = 16 + (index - 1) * 17
		local statName = text(extras, string.upper(stat), 9, C.Dim, Enum.Font.GothamBold)
		statName.Position, statName.Size = UDim2.fromOffset(14, y), UDim2.fromOffset(62, 12)
		for pip = 1, 5 do
			local lit = pip <= (style.Profile[stat] or 0)
			frame(extras, {
				BackgroundColor3 = if lit then style.Color else C.Line,
				BackgroundTransparency = if lit then 0 else 0.3,
				Position = UDim2.new((pip - 1) / 5 * 0.62, 78, 0, y + 2),
				Size = UDim2.new(0.62 / 5, -3, 0, 8),
				ZIndex = 23,
			})
		end
	end
	local gemLine = text(
		extras,
		"PAIR WITH ANY ELEMENT",
		9,
		C.Dim,
		Enum.Font.GothamBold,
		{ RichText = true }
	)
	gemLine.Position, gemLine.Size = UDim2.fromOffset(14, 90), UDim2.new(1, -28, 0, 14)
	local tip = text(extras, style.Tip, 11, C.Text, Enum.Font.GothamMedium, { TextWrapped = true })
	tip.Position, tip.Size = UDim2.fromOffset(14, 110), UDim2.new(1, -28, 0, 30)
	tip.TextYAlignment = Enum.TextYAlignment.Top
	-- Full: art (or crest) up top, then name, role and the perks. Compact:
	-- the art fills the card above the name and role; the perks go.
	place(function(compact, rich)
		local Y0 = if artId ~= 0 then (if rich then 152 else 112) else 0
		if compact then
			art.Position, art.Size = UDim2.fromOffset(6, 8), UDim2.new(1, -12, 1, -52)
			crest.Position, crest.Size = UDim2.new(0.5, 0, 0.5, -42), UDim2.fromOffset(34, 34)
			initial.Position, initial.Size, initial.TextSize = UDim2.new(0.5, 0, 0.5, -38), UDim2.fromOffset(40, 28), 18
			name.Position, name.Size, name.TextSize = UDim2.new(0, 0, 1, -42), UDim2.new(1, 0, 0, 18), 14
			role.Position, role.Size, role.TextSize = UDim2.new(0, 0, 1, -22), UDim2.new(1, 0, 0, 12), 9
		else
			art.Position, art.Size = UDim2.fromOffset(8, 12), UDim2.new(1, -16, 0, if rich then 216 else 176)
			crest.Position, crest.Size = UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(46, 46)
			initial.Position, initial.Size, initial.TextSize = UDim2.new(0.5, 0, 0, 27), UDim2.fromOffset(60, 36), 26
			name.Position, name.Size, name.TextSize = UDim2.fromOffset(0, 86 + Y0), UDim2.new(1, 0, 0, 22), 18
			role.Position, role.Size, role.TextSize = UDim2.fromOffset(0, 110 + Y0), UDim2.new(1, 0, 0, 14), 10
		end
		divider.Visible = not compact
		divider.Position, divider.Size = UDim2.new(0, 14, 0, 132 + Y0), UDim2.new(1, -28, 0, 1)
		for line, pair in perks do
			pair[1].Visible, pair[2].Visible = not compact, not compact
			pair[1].Position, pair[1].Size = UDim2.new(0, 14, 0, 144 + Y0 + (line - 1) * STEP), UDim2.fromOffset(10, 14)
			pair[2].Position, pair[2].Size = UDim2.new(0, 28, 0, 142 + Y0 + (line - 1) * STEP), UDim2.new(1, -40, 0, 30)
		end
		kit.Visible = artId == 0 and not compact and not rich -- (the art shows the kit)
		kit.Position, kit.Size = UDim2.new(0.5, 0, 1, -40), UDim2.new(1, -24, 0, 28)
		extras.Visible = rich
		extras.Position = UDim2.fromOffset(0, 142 + Y0 + 2 * STEP + 40)
		extras.Size = UDim2.new(1, 0, 0, 144)
	end)
	pick.BackgroundTransparency, pick.BackgroundColor3 = 0, style.Color
	pick.TextXAlignment = Enum.TextXAlignment.Center
	UiKit.round(pick, 10)
	styleButtons[style.Id] = { Button = card, Stroke = edge, Name = name, Pick = pick, Color = style.Color, Art = art }
	listen(card.Activated, function()
		if not savedKit and not busy then
			chosenStyle = style.Id
			refreshChoices()
		end
	end)
end

-- The four elements, sized to fit the space rather than scroll: side by side
-- when the screen is wide (Q, E and R then line up across them, to compare),
-- two by two when it's tall, and each card shrinks to its space (smaller
-- gem and type, shorter move rows, the extra lines dropped) before the list
-- ever has to scroll (only on very small portrait screens).
local elementArea = new("ScrollingFrame", {
	Name = "ElementChoices",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 21,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Edge,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ClipsDescendants = true,
}, choices)
local elementOrder = { "Fire", "Frost", "Shock", "Poison" }
local CARD_TALL = 300 -- a card at its fullest
local CARD_MIN_H, CARD_MIN_W = 160, 145 -- the least a card can show its moves in

-- Lay one element card out inside w x h.
local function layoutCard(card, w: number, h: number)
	local roomy = h >= 280
	local header = math.clamp(math.floor(h * 0.27), 44, 82)
	local narrow = w < 200
	local gem = if narrow then 26 else math.clamp(header - 18, 30, 62)
	card.Disc.Position, card.Disc.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(gem, gem)
	card.Holder.Position, card.Holder.Size = UDim2.fromOffset(9, 9), UDim2.fromOffset(gem + 6, gem + 6)
	local textX = gem + (if narrow then 16 else 24)
	local showDescription = header >= 60
	-- The name as big as its line allows (Gotham Black runs ~0.8 em a letter).
	local nameRoom = w - textX - (if narrow then 22 else 34)
	card.Name.TextSize =
		math.clamp(math.floor(nameRoom / (#card.Name.Text * 0.8)), 10, if header >= 60 then 19 else 15)
	card.Name.Position = UDim2.fromOffset(textX, if showDescription then 13 else math.floor((header - 20) / 2) + 2)
	card.Name.Size = UDim2.new(1, -textX - (if narrow then 22 else 34), 0, 24)
	card.Description.Visible = showDescription
	card.Description.Position, card.Description.Size =
		UDim2.fromOffset(textX, 39), UDim2.new(1, -textX - 12, 0, math.max(16, header - 42))
	card.Marker.Position = UDim2.new(1, if narrow then -26 else -34, 0, if narrow then 6 else 10)
	-- Strong / weak: its own line when there's room, else under the name.
	local matchup = if roomy then 18 else 0
	card.Matchup.Visible = roomy or not showDescription
	card.Matchup.TextSize = if roomy then 11 else 10
	card.Matchup.Text = if roomy or w >= 300 then card.MatchFull else card.MatchShort
	if roomy then
		card.Matchup.Position, card.Matchup.Size = UDim2.fromOffset(14, header + 2), UDim2.new(1, -28, 0, 16)
	else
		card.Matchup.Position, card.Matchup.Size = UDim2.fromOffset(textX, header - 18), UDim2.new(1, -textX - 6, 0, 14)
		card.Matchup.TextSize = if narrow then 9 else 10
	end
	local tag = if roomy then 26 else 0
	card.Tag.Visible = roomy
	card.Tag.Position, card.Tag.Size = UDim2.new(0, 14, 1, -tag - 4), UDim2.new(1, -28, 0, tag)
	-- The Q / E / R rows share what's left.
	local top = header + matchup + (if roomy then 8 else 4)
	local gap = if h >= 240 then 6 else 4
	local rowH = math.clamp(math.floor((h - top - tag - 10 - gap * 2) / 3), 30, 58)
	-- Narrow cards stack a key's two moves, one per line.
	local optionW = (w - 56) / 2
	local stacked = optionW < 100 and rowH >= 38
	local lineH = if stacked then math.floor(rowH / 2) else rowH
	local iconSize = if stacked then math.clamp(lineH - 4, 14, 22) else math.clamp(rowH - 12, 22, 38)
	local nameSize = if stacked
		then math.clamp(math.floor((w - 63 - iconSize) / (card.Longest * 0.62)), 8, 10)
		elseif w >= 280 and rowH >= 50 then 12
		elseif w >= 260 and rowH >= 40 then 11
		elseif w >= 230 then 10
		else 9
	for index, row in card.Rows do
		row.Chip.Position = UDim2.fromOffset(10, top + (index - 1) * (rowH + gap))
		row.Chip.Size = UDim2.new(1, -20, 0, rowH)
		row.Key.Position, row.Key.Size = UDim2.fromOffset(4, if rowH >= 40 then 4 else 2), UDim2.fromOffset(24, 18)
		row.Role.Visible = rowH >= 38
		row.Role.Position, row.Role.Size = UDim2.fromOffset(0, rowH - 16), UDim2.fromOffset(32, 10)
		row.Options.Position, row.Options.Size = UDim2.fromOffset(32, 0), UDim2.new(1, -36, 1, 0)
		local count = #row.Cells
		for option, cell in row.Cells do
			if stacked then
				cell.Frame.Position = UDim2.new(0, 0, (option - 1) / count, 0)
				cell.Frame.Size = UDim2.fromScale(1, 1 / count)
			else
				cell.Frame.Position = UDim2.fromScale((option - 1) / count, 0)
				cell.Frame.Size = UDim2.fromScale(1 / count, 1)
			end
			cell.Icon.Position = UDim2.fromOffset(0, math.floor((lineH - iconSize) / 2))
			cell.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
			cell.Name.TextSize = nameSize
			cell.Name.TextWrapped = not stacked
			cell.Name.Position, cell.Name.Size = UDim2.fromOffset(iconSize + 5, 1), UDim2.new(1, -iconSize - 7, 1, -2)
		end
	end
end

local function layoutElements()
	local width, height = elementArea.AbsoluteSize.X, elementArea.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	local gap, inset = 10, 2
	-- Every arrangement's card size; the first that fits wins.
	local function size(columns)
		local rows = math.ceil(#elementOrder / columns)
		return math.floor((width - inset * 2 - gap * (columns - 1)) / columns),
			math.floor((height - inset * 2 - gap * (rows - 1)) / rows)
	end
	local w4, h4 = size(4)
	local w2, h2 = size(2)
	local columns, cardW, cardH, scroll
	if w2 >= 380 and h2 >= 250 then
		columns, cardW, cardH = 2, w2, math.min(h2, CARD_TALL + 20) -- (tall screens: two by two)
	elseif w4 >= CARD_MIN_W and h4 >= CARD_MIN_H then
		columns, cardW, cardH = 4, w4, math.min(h4, CARD_TALL + 40) -- (wide: side by side)
	elseif w2 >= CARD_MIN_W and h2 >= CARD_MIN_H then
		columns, cardW, cardH = 2, w2, h2
	else
		-- Very small (portrait phones): one column, scrolling.
		local w1 = width - inset * 2 - 8
		columns, cardW, cardH, scroll = 1, w1, CARD_TALL, true
	end
	local rows = math.ceil(#elementOrder / columns)
	local used = rows * cardH + (rows - 1) * gap
	-- Centred in the space when there's height to spare.
	local y0 = if scroll then inset else inset + math.max(0, math.floor((height - inset * 2 - used) / 2))
	for i, element in elementOrder do
		local card = elementButtons[element]
		if card then
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			card.Button.Position = UDim2.fromOffset(inset + col * (cardW + gap), y0 + row * (cardH + gap))
			card.Button.Size = UDim2.fromOffset(cardW, cardH)
			layoutCard(card, cardW, cardH)
		end
	end
	elementArea.CanvasSize = if scroll then UDim2.fromOffset(0, inset * 2 + used) else UDim2.new()
	elementArea.ScrollBarThickness = if scroll then 4 else 0
end
place(function(compact)
	local top, bottom = if compact then 20 else 26, if compact then 42 else 56
	elementArea.Visible = pickStep == "Element"
	elementArea.Position = UDim2.fromOffset(0, top)
	elementArea.Size = UDim2.new(1, 0, 1, -top - bottom)
	layoutElements()
end)
listen(elementArea:GetPropertyChangedSignal("AbsoluteSize"), layoutElements)
for _, element in elementOrder do
	local color = GemConfig.ElementColors[element]
	local row = new("TextButton", {
		Name = element,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Card,
		ZIndex = 21,
		ClipsDescendants = true,
	}, elementArea)
	UiKit.round(row, 14)
	local edge = stroke(row, C.Line, 0, 1)
	new("UIGradient", { Rotation = 120, Color = ColorSequence.new(C.Text, color:Lerp(C.Text, 0.78)) }, row)
	local bar = frame(row, {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 22,
	})
	local disc = frame(row, { BackgroundColor3 = color, BackgroundTransparency = 0.86, ZIndex = 22 })
	UiKit.round(disc, 16)
	stroke(disc, color, 0.65, 1)
	local holder = frame(row, { BackgroundTransparency = 1, ZIndex = 23 })
	Art.show(
		holder,
		{ Id = "starter-" .. element, Element = element, Tier = "Common", Size = 3, Clarity = 5, Cut = 5 },
		nil,
		color,
		false
	)
	local nameLabel = text(row, string.upper(GemConfig.elementName(element)), 19, color, Enum.Font.GothamBlack)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	local description = text(row, ELEMENTS[element], 12, C.Text, Enum.Font.GothamMedium, { TextWrapped = true })
	description.TextXAlignment, description.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	local marker = text(row, "○", 20, C.Dim, Enum.Font.GothamBold, {
		Size = UDim2.fromOffset(24, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local beats, weak = ElementMatchup.Beats[element], ElementMatchup.weakTo(element)
	local matchup = text(
		row,
		string.format("Strong vs %s  /  Weak vs %s", GemConfig.elementName(beats), GemConfig.elementName(weak)),
		11,
		C.Dim,
		Enum.Font.GothamMedium
	)
	matchup.TextXAlignment = Enum.TextXAlignment.Left
	local pools = surgePools(element)
	local surgeLabels, rows = {}, {}
	local longest = 8 -- (letters in its longest move name)
	for _, pool in pools do
		for _, id in pool do
			longest = math.max(longest, #moveName(id))
		end
	end
	for index, pool in pools do
		local chip = frame(row, { BackgroundColor3 = C.Ink, BackgroundTransparency = 0.12, ZIndex = 22 })
		UiKit.round(chip, 8)
		local keyLabel = text(chip, ({ "Q", "E", "R" })[index], 15, color, Enum.Font.GothamBlack, {
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local role = text(chip, ({ "STRIKE", "ABILITY", "GUARD" })[index], 7, C.Dim, Enum.Font.GothamBold, {
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local options = frame(chip, { BackgroundTransparency = 1, ZIndex = 23 })
		local cells = {}
		for option, id in pool do
			local move = Tech.Catalog[id]
			local cell = frame(options, {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale((option - 1) / #pool, 0),
				Size = UDim2.fromScale(1 / #pool, 1),
				ZIndex = 23,
			})
			local icon = text(cell, "◆", 16, color, Enum.Font.GothamBold, { ZIndex = 24 })
			UiKit.round(icon, 6)
			if move then
				Icons.apply(icon, move, color)
			end
			local name = text(cell, moveName(id), 11, C.Dim, Enum.Font.GothamMedium, { TextWrapped = true })
			name.TextXAlignment = Enum.TextXAlignment.Left
			table.insert(surgeLabels, name)
			table.insert(cells, { Frame = cell, Icon = icon, Name = name })
		end
		table.insert(rows, { Chip = chip, Key = keyLabel, Role = role, Options = options, Cells = cells })
	end
	local tag = text(row, "", 10, C.Dim, Enum.Font.GothamBold, { TextWrapped = true })
	elementButtons[element] = {
		Button = row,
		Stroke = edge,
		Surges = surgeLabels,
		Bar = bar,
		Disc = disc,
		Holder = holder,
		Name = nameLabel,
		Description = description,
		Matchup = matchup,
		MatchFull = matchup.Text,
		Longest = longest,
		MatchShort = string.format("▲ %s   ▼ %s", GemConfig.elementName(beats), GemConfig.elementName(weak)),
		Rows = rows,
		Color = color,
		Tag = tag,
		Marker = marker,
	}
	listen(row.Activated, function()
		if not savedKit and not busy then
			chosenElement = element
			refreshChoices()
		end
	end)
end
layoutElements()

-- What you're about to get.
local summary = frame(choices, { BackgroundColor3 = C.Panel, ZIndex = 21, ClipsDescendants = true })
UiKit.round(summary, 8)
local summaryEdge = new("UIStroke", { Color = C.Line, Thickness = 1 }, summary)
local summaryText = text(summary, "", 13, C.Text, Enum.Font.GothamBold, { RichText = true })
summaryText.TextXAlignment = Enum.TextXAlignment.Left
summaryText.TextWrapped = true
place(function(compact)
	local height = if compact then 36 else 48
	summary.Position, summary.Size = UDim2.new(0, 0, 1, -height - CTA_ROOM), UDim2.new(1, 0, 0, height)
	summaryText.TextSize = if compact then 11 else 13
	summaryText.Position = UDim2.fromOffset(if compact then 10 else 16, 0)
	summaryText.Size = UDim2.new(1, if compact then -20 else -32, 1, 0)
end)
local function layoutChoices(compact, rich)
	rich = rich and not compact
	if compact == compactMode and rich == richMode then
		return
	end
	compactMode, richMode = compact, rich
	for _, apply in relayout do
		apply(compact, rich)
	end
	refreshChoices()
end

local function hex(color)
	return string.format("#%02x%02x%02x", color.R * 255, color.G * 255, color.B * 255)
end
function refreshChoices()
	local styleColor = C.Gold
	for id, card in styleButtons do
		local on = id == chosenStyle
		card.Stroke.Color = if on then card.Color else C.Line
		card.Button.BackgroundColor3 = if on then C.Card:Lerp(card.Color, 0.14) else C.Card
		card.Name.TextColor3 = if on then C.Text else C.Dim
		card.Pick.Visible = on and not compactMode -- (compact: the glowing border says it)
		card.Art.ImageTransparency = if on then 0 else 0.4
		card.Stroke.Thickness = if on then 3 else 1
		if on then
			styleColor = card.Color
		end
	end
	local elementColor = C.Cyan
	for id, row in elementButtons do
		local on = id == chosenElement
		row.Stroke.Color = if on then row.Color else C.Line
		row.Stroke.Thickness = if on then 2.5 else 1
		row.Button.BackgroundColor3 = if on then C.Card:Lerp(row.Color, 0.14) else C.Card
		for _, label in row.Surges do
			label.TextColor3 = if on then C.Text else C.Dim
		end
		row.Bar.BackgroundTransparency = if on then 0 else 0.7
		row.Disc.BackgroundTransparency = if on then 0.6 else 0.86
		row.Tag.Text = if on then "SELECTED  ·  " .. (if savedKit then "YOUR SAVED KIT" else "ONE MOVE PER KEY, ROLLED WHEN EQUIPPED") else "CHOOSE ELEMENT  ·  ONE MOVE PER KEY"
		row.Tag.TextColor3 = if on then row.Color else C.Dim
		row.Marker.Text = if on then "✓" else "○"
		row.Marker.TextColor3 = if on then row.Color else C.Dim
		if on then
			elementColor = row.Color
		end
	end
	summaryEdge.Color = styleColor:Lerp(elementColor, 0.5)
	-- This screen's words and button.
	if not reward then
		title.Text = if pickStep == "Style" then "HOW DO YOU FIGHT?" else "PICK YOUR ELEMENT"
		subtitle.Text = if pickStep == "Style"
			then "Your style is the armor you start in. You can wear any set later."
			else "Any armor. Any element. Choose the powers for your Q / E / R moves."
		if not busy then
			primary.Text = if pickStep == "Style" then "NEXT  ·  ELEMENT   ›" elseif chosenElement then "EQUIP & FIGHT" else "CHOOSE AN ELEMENT"
			local ready = pickStep == "Style" or chosenElement ~= nil
			primary.Active, primary.Selectable = ready, ready
			primary.BackgroundColor3 = if ready then C.Gold else C.Line
			primary.TextColor3 = if ready then C.Ink else C.Dim
		end
		backStep.Visible = pickStep == "Element" and not savedKit
	end
	if not chosenElement then
		summaryText.Text = string.format('<font color="#8a9cb2">YOUR KIT</font>   %s armor + sword &amp; shield   ·   Choose any element next', string.upper(chosenStyle))
		return
	end
	local names = surgeNames(chosenElement)
	summaryText.Text = string.format(
		'<font color="#8a9cb2">YOUR KIT</font>   <font color="%s">%s</font> armor  +  sword & shield   ·   <font color="%s">%s</font>  %s',
		hex(styleColor),
		string.upper(chosenStyle),
		hex(elementColor),
		string.upper(GemConfig.elementName(chosenElement)),
		if #names ~= 3 then ""
			elseif string.find(table.concat(names), " or ", 1, true) then "Q · E · R: one of two each, rolled as you equip"
			else string.format("Q %s  ·  E %s  ·  R %s", names[1], names[2], names[3])
	)
end
local function setPickStep(step: string)
	pickStep = step
	for _, apply in relayout do
		apply(compactMode, richMode)
	end
	refreshChoices()
end
listen(backStep.Activated, function()
	if not busy then
		setPickStep("Style")
	end
end)
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
	primary.Size = UDim2.new(if oneRow then 0.36 else 1, 0, 0, if oneRow then 44 else 52)
	for _, b in { skip, motion, backStep } do
		b.Position = UDim2.new(b.AnchorPoint.X, 0, 0, if oneRow then 8 else 64)
	end
	backStep.Size = UDim2.fromOffset(if oneRow then math.min(168, w * 0.26) else 214, 28)
	skip.Size = UDim2.fromOffset(if oneRow then math.min(168, w * 0.26) else math.min(214, w * 0.58), 28)
	skip.Text = if oneRow then "Skip · keep rewards" else "Skip reveal · keep all rewards"
	local bodyHeight = math.max(80, h - header - (if oneRow then 54 else 108))
	title.TextSize = if w < 420 then 20 elseif w < 500 then 24 elseif short then 20 else 34
	title.Position, title.Size =
		UDim2.fromOffset(0, if short then 18 else 24), UDim2.new(1, 0, 0, if short then 26 else 42)
	subtitle.Visible = not short
	brand.Visible = not short -- (short screens: the title takes its line)
	subtitle.Position = UDim2.fromOffset(0, if narrow then 62 else 70)
	-- (No reveal steps any more: you pick your kit and go.)
	stepper.Visible = false
	motion.Visible = false
	body.Position, body.Size = UDim2.fromOffset(0, header), UDim2.new(1, 0, 0, bodyHeight)
	-- Short screens (phones): the compact picker.
	layoutChoices(bodyHeight < 420, bodyHeight >= 560)
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
	-- The loading screen takes over at once (LoadingFlow): the inventory and
	-- the world behind the intro aren't for seeing, only where it goes next
	-- (your first fight's drop, or the Outpost).
	gui:SetAttribute("Closing", true)
	LoadingFlow.hold("Intro", { Instant = true, Destination = LoadingFlow.home })
	gui:Destroy()
end
-- The roll: a full-screen reveal of the kit. Each key is a tall card, and
-- its circle is a reel of gems, every rarity flashing past (named under the
-- circle as it goes), until it stops on your gem, the real stone going into
-- that socket. Only then does the gem give up its surge: the move's icon
-- rises out of it, with its name. Q, then E, then R. Click to skip ahead.
local KEYS = {
	{ Key = "Q", Color = Color3.fromRGB(255, 138, 92), Slot = "SWORD", Gem = "SWORD GEM", Pays = "CHARGE" },
	{ Key = "E", Color = Color3.fromRGB(122, 196, 255), Slot = "CORE", Gem = "CORE GEM", Pays = "CHARGE" },
	{ Key = "R", Color = Color3.fromRGB(120, 230, 170), Slot = "DEFENSE", Gem = "SHIELD GEM", Pays = "STAMINA" },
}
local WELL = 156 -- (px: the circle, the reel's window)
local CELL = 108 -- (px: one symbol on the reel)
local function keycap(parent, key, color, size)
	-- A physical key: a darker base under a raised cap.
	local base = frame(parent, { BackgroundColor3 = color:Lerp(C.Ink, 0.55), Size = UDim2.fromOffset(size, size + 6), ZIndex = 45 })
	UiKit.round(base, 9)
	local cap = frame(base, { BackgroundColor3 = color, Size = UDim2.fromOffset(size, size), ZIndex = 46 })
	UiKit.round(cap, 9)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color) }, cap)
	local glyph = label(cap, key, math.floor(size * 0.58), C.Ink, Enum.Font.GothamBlack)
	glyph.TextXAlignment, glyph.ZIndex = Enum.TextXAlignment.Center, 47
	return base
end
-- The reel rolls like a normal gem roll of your element: every rarity at the
-- usual odds, each in its own shade (Thermal: Ember Red up to Starfire
-- Ruby). The gems nearest the stop, the ones you watch as it slows, are 3D;
-- the ones that blur past further up are drawn flat (in the same shades) to
-- keep it light.
local REEL_TIERS = { Common = 40, Uncommon = 28, Rare = 18, UltraRare = 9, Legendary = 5 }
local function reelTier(rng)
	local roll = rng:NextNumber(0, 100)
	for _, tier in { "Legendary", "UltraRare", "Rare", "Uncommon" } do
		roll -= REEL_TIERS[tier]
		if roll < 0 then
			return tier
		end
	end
	return "Common"
end
local REEL_3D = 10 -- (cells 0 to this, nearest the stop, are 3D)
local function shadeOf(element, tier)
	for _, shade in GemConfig.Shades[element] or {} do
		if shade.Tier == tier then
			return shade
		end
	end
	return nil
end
local function reelGem(parent, color, tier)
	local white = Color3.new(1, 1, 1)
	local gem = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.floor(CELL * 0.52), math.floor(CELL * 0.52)),
		BackgroundColor3 = white,
		Rotation = 45,
		ZIndex = 46,
	})
	UiKit.round(gem, 6)
	new("UIGradient", {
		Rotation = -45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(white, 0.55)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, color:Lerp(C.Ink, 0.55)),
		}),
	}, gem)
	stroke(gem, GemConfig.TierColors[tier] or C.Line, 0, 3)
	local facet = frame(gem, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		BackgroundColor3 = color:Lerp(white, 0.35),
		BackgroundTransparency = 0.25,
		ZIndex = 46,
	})
	UiKit.round(facet, 3)
	local glint = frame(gem, {
		Position = UDim2.fromScale(0.14, 0.14),
		Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = white,
		BackgroundTransparency = 0.2,
		ZIndex = 46,
	})
	UiKit.round(glint, 2)
	return gem
end
local function revealMoves(kit, after)
	local moves = Lottery.starterMoves(kit.Element, kit)
	local element = kit.Element
	local color = GemConfig.ElementColors[element] or C.Gold
	local theme = CardFX.Themes[element]
	local deep = if theme then theme.Deep else C.Panel
	local elementName = string.upper(GemConfig.elementName(element))
	local rng = Random.new()

	local shade = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 40,
	}, gui)
	tween(shade, 0.3, { BackgroundTransparency = 0 })
	-- The element floods up from below.
	local flood = frame(shade, { BackgroundColor3 = deep, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40 })
	new("UIGradient", {
		Rotation = 270,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.55, 0.9), NumberSequenceKeypoint.new(1, 1) }),
	}, flood)
	tween(flood, 0.6, { BackgroundTransparency = 0 })

	-- Everything sits on one board, scaled to fit the screen.
	local board = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 590),
		BackgroundTransparency = 1,
		ZIndex = 41,
	})
	local fitScale = new("UIScale", { Scale = 1 }, board)

	local kicker = label(board, elementName .. "  ·  STARTER ROLL", 14, color, Enum.Font.GothamBlack)
	kicker.TextXAlignment, kicker.ZIndex = Enum.TextXAlignment.Center, 42
	kicker.Position, kicker.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18)
	local title = label(board, "ROLLING YOUR GEMS", 40, C.Text, Enum.Font.GothamBlack)
	title.TextXAlignment, title.ZIndex = Enum.TextXAlignment.Center, 42
	title.Position, title.Size = UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 46)
	-- Scaled to fit the screen. Short (phone) screens drop the headline, so
	-- the cards (y 84 down) get the height and stay readable.
	local function fitBoard()
		local size = shade.AbsoluteSize - Vector2.new(24, 16)
		if size.X > 0 and size.Y > 0 then
			local short = size.Y < 480
			kicker.Visible, title.Visible = not short, not short
			local scale = math.min(1.1, size.X / 940, size.Y / (if short then 526 else 630))
			fitScale.Scale = scale
			board.Position = UDim2.new(0.5, 0, 0.5, if short then -42 * scale else 0)
		end
	end
	fitBoard()
	listen(shade:GetPropertyChangedSignal("AbsoluteSize"), fitBoard)

	local cards, effects = {}, {}
	for index, spec in KEYS do
		local id = moves[index]
		local move = Tech.Catalog[id]
		local gem = kit.Gems and kit.Gems[index] and kit.Gems[index].Gem
			or { Id = "starter-" .. element .. index, Element = element, Tier = "Common", Size = 1, Clarity = 1, Cut = 1 }
		local x = (index - 1) * 300
		local card = frame(board, {
			Position = UDim2.fromOffset(x + 4, 84 + 40),
			Size = UDim2.fromOffset(284, 426),
			BackgroundColor3 = C.Card,
			BackgroundTransparency = 1,
			ZIndex = 42,
		})
		UiKit.round(card, 12)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(spec.Color:Lerp(C.Card, 0.82), C.Ink) }, card)
		local edge = stroke(card, spec.Color, 0.75, 1)
		local punch = new("UIScale", { Scale = 1 }, card)
		task.delay(0.1 + index * 0.09, function()
			tween(card, 0.35, { Position = UDim2.fromOffset(x + 4, 84), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
		end)

		-- Header: the key, which slot it fires from, what it pays.
		local cap = keycap(card, spec.Key, spec.Color, 44)
		cap.Position = UDim2.fromOffset(16, 14)
		local slot = label(card, spec.Slot, 18, spec.Color, Enum.Font.GothamBlack)
		slot.Position, slot.Size, slot.ZIndex = UDim2.fromOffset(72, 16), UDim2.new(1, -84, 0, 22), 45
		local pays = label(card, "PAYS " .. spec.Pays, 11, C.Dim, Enum.Font.GothamBold)
		pays.Position, pays.Size, pays.ZIndex = UDim2.fromOffset(72, 40), UDim2.new(1, -84, 0, 14), 45

		-- The circle: a round reel window (a CanvasGroup clips to its corner).
		local well = new("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 74 + WELL / 2),
			Size = UDim2.fromOffset(WELL, WELL),
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 44,
		}, card)
		UiKit.round(well, WELL)
		local wellEdge = stroke(well, spec.Color, 0.6, 2)
		local back = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 44 })
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(C.Ink, 0.6), C.Ink),
		}, back)
		-- The strip runs downward and stops with cell 2, your gem, in the
		-- middle of the circle. (Cell 0 sits above it for the spring-back.)
		local count = 20 + index * 7
		local strip = frame(well, { BackgroundTransparency = 1, Size = UDim2.fromOffset(WELL, CELL * count), ZIndex = 45 })
		local symbols, cells, record, shadeNames, reelRecords = {}, {}, nil, {}, {}
		for n = 0, count do
			local cell = frame(strip, {
				Position = UDim2.fromOffset(0, (n - 1) * CELL),
				Size = UDim2.fromOffset(WELL, CELL),
				BackgroundTransparency = 1,
				ZIndex = 45,
			})
			cells[n] = cell
			if n == 2 then
				local holder = frame(cell, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(CELL + 12, CELL + 12),
					BackgroundTransparency = 1,
					ZIndex = 46,
				})
				record = Art.show(holder, gem, nil, color, false)
				symbols[n] = "Gem"
			else
				-- Gems of every rarity roll past, each in its own shade of
				-- the element; what's inside stays hidden.
				local tier = reelTier(rng)
				local look = shadeOf(element, tier)
				if n <= REEL_3D then
					local holder = frame(cell, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(CELL, CELL),
						BackgroundTransparency = 1,
						ZIndex = 46,
					})
					local size = rng:NextInteger(3, 9)
					local ok, passing = pcall(Art.show, holder, {
						Id = "reel-" .. index .. "-" .. n,
						Element = element,
						Tier = tier,
						Size = size,
						Clarity = rng:NextInteger(3, 9),
						Cut = rng:NextInteger(3, 9),
					}, nil, color, false)
					if ok and passing then
						table.insert(reelRecords, passing)
					else
						holder:Destroy()
						reelGem(cell, if look then look.Color else color, tier)
					end
				else
					reelGem(cell, if look then look.Color else color, tier)
				end
				symbols[n] = tier
				shadeNames[n] = look and look.Name
			end
		end
		local function stripY(n)
			return WELL / 2 - CELL / 2 - (n - 1) * CELL
		end
		strip.Position = UDim2.fromOffset(0, stripY(count))
		-- Depth: the circle darkens toward its top and bottom.
		local depth = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 47 })
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.25, 1),
				NumberSequenceKeypoint.new(0.75, 1),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}, depth)
		local flash = frame(well, { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 48 })

		-- The surge badge: the move's icon, rising out of the gem.
		local badge = frame(card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 74 + WELL / 2),
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = C.Ink,
			Visible = false,
			ZIndex = 49,
		})
		UiKit.round(badge, 12)
		stroke(badge, spec.Color, 0, 3)
		local badgeScale = new("UIScale", { Scale = 0.2 }, badge)
		local art = frame(badge, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = C.Ink, ZIndex = 50 })
		UiKit.round(art, 9)
		if not Icons.apply(art, move) then
			local word = label(art, string.upper(string.sub(move and move.Name or id, 1, 2)), 26, spec.Color, Enum.Font.GothamBlack)
			word.TextXAlignment, word.ZIndex = Enum.TextXAlignment.Center, 51
		end

		-- Under the well: what's inside, the two candidates while it shakes.
		local caption = label(card, spec.Gem, 12, C.Faint, Enum.Font.GothamBlack)
		caption.TextXAlignment, caption.ZIndex = Enum.TextXAlignment.Center, 45
		caption.Position, caption.Size = UDim2.fromOffset(12, 270), UDim2.new(1, -24, 0, 16)
		local rows = {}
		-- Once the surge is out: its name, cost, what it does.
		local name = label(card, "", 24, C.Text, Enum.Font.GothamBlack)
		name.TextXAlignment, name.ZIndex = Enum.TextXAlignment.Center, 45
		name.TextScaled, name.TextTruncate = true, Enum.TextTruncate.None
		new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 14 }, name)
		name.Position, name.Size = UDim2.fromOffset(12, 290), UDim2.new(1, -24, 0, 30)
		local stats = label(card, "", 12, spec.Color, Enum.Font.GothamBlack)
		stats.TextXAlignment, stats.ZIndex = Enum.TextXAlignment.Center, 45
		stats.Position, stats.Size = UDim2.fromOffset(12, 322), UDim2.new(1, -24, 0, 16)
		local about = label(card, "", 13, C.Dim, Enum.Font.GothamMedium)
		about.TextXAlignment, about.TextYAlignment, about.ZIndex = Enum.TextXAlignment.Center, Enum.TextYAlignment.Top, 45
		about.TextWrapped, about.TextTruncate = true, Enum.TextTruncate.AtEnd
		about.Position, about.Size = UDim2.fromOffset(18, 344), UDim2.new(1, -36, 0, 48)

		local effect = CardFX.create(card)
		CardFX.update(effect, nil, 0)
		table.insert(effects, effect)

		local entry = {
			Phase = "Sealed",
			Record = record,
			Rows = rows,
			Color = spec.Color,
			Strip = strip,
			Symbols = symbols,
			ShadeNames = shadeNames,
			ReelRecords = reelRecords,
			Final = stripY(2),
			LastCell = nil,
			Caption = caption,
			GemWord = spec.Gem,
		}
		-- Beat 1: the capsule bursts and the gem is out.
		function entry.open(quick)
			if entry.Phase ~= "Sealed" then
				return
			end
			entry.Phase = "Gem"
			strip.Position = UDim2.fromOffset(0, entry.Final)
			-- Only the gem stays in the circle.
			for n, cell in cells do
				cell.Visible = n == 2
			end
			flash.BackgroundTransparency = 0
			tween(flash, 0.4, { BackgroundTransparency = 1 })
			punch.Scale = 1.07
			tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			wellEdge.Transparency = 0
			caption.Text, caption.TextColor3 = elementName .. " " .. spec.Gem .. "  ·  " .. string.upper(gem.Tier or "Common"), color
			for _, row in rows do
				local on = row.Id == id
				row.Frame.BackgroundColor3 = if on then spec.Color:Lerp(C.Ink, 0.55) else C.Panel
				row.Edge.Color = if on then spec.Color else C.Line
				row.Words.TextColor3 = if on then C.Text else C.Faint
			end
			if not quick then
				LotterySound.play("Lock")
			end
		end
		-- Beat 2: the gem gives up its surge.
		function entry.surge(quick)
			if entry.Phase == "Surge" then
				return
			end
			entry.open(true)
			entry.Phase = "Surge"
			badge.Visible = true
			local final = UDim2.new(0.5, 0, 0, 74 + WELL - 6)
			if quick then
				badge.Position, badgeScale.Scale = final, 1
			else
				tween(badge, 0.4, { Position = final }, Enum.EasingStyle.Back)
				tween(badgeScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				LotterySound.play("Reveal" .. math.clamp(index + 1, 1, 5))
			end
			caption.Position = UDim2.fromOffset(12, 74 + WELL + 34)
			for _, row in rows do
				row.Frame.Visible = false
			end
			name.Text = string.upper(move and move.Name or id)
			stats.Text = if move then string.format("%d %s   ·   %dS COOLDOWN", move.Cost or 0, spec.Pays, move.Cooldown or 0) else ""
			about.Text = move and move.Description or ""
			edge.Color, edge.Transparency, edge.Thickness = spec.Color, 0.1, 2
			effects[index].Live = true
		end
		cards[index] = entry
	end

	-- The CTA, once every gem has given up its surge.
	local go = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 530),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = C.Gold,
		Text = "TO THE FIGHT   ›",
		TextColor3 = C.Ink,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = true,
		ZIndex = 44,
		Visible = false,
	}, board)
	UiKit.round(go, 10)
	local goScale = new("UIScale", { Scale = 0.6 }, go)

	local born = os.clock()
	local lastTick = 0
	local live = RunService.RenderStepped:Connect(function()
		local t = os.clock() - born
		-- Spinning: the move in the middle of the circle lights its row, and
		-- each one that passes clicks.
		local now = os.clock()
		for _, entry in cards do
			if entry.Phase == "Sealed" then
				local y = entry.Strip.Position.Y.Offset
				local middle = math.floor((WELL / 2 - y) / CELL + 1)
				if middle ~= entry.LastCell then
					entry.LastCell = middle
					if now - lastTick > 0.06 and entry.Spinning then
						lastTick = now
						LotterySound.play("Tick")
					end
				end
				-- Under the circle: the rarity of the gem going past.
				local showing = entry.Symbols[middle]
				local tierColor = GemConfig.TierColors[showing]
				-- (by the gem's own name: "SOLAR GARNET  ·  ULTRA-RARE")
				local shadeName = entry.ShadeNames[middle]
				if tierColor and middle ~= entry.Shown then
					entry.Shown = middle
					local tierName = string.upper(GemConfig.TierLabels[showing] or showing)
					entry.Caption.Text = if shadeName
						then string.upper(shadeName) .. "  ·  " .. tierName
						else tierName .. "  ·  " .. entry.GemWord
					entry.Caption.TextColor3 = tierColor
				end
				-- The 3D gems turn as they pass, like yours.
				for i, passing in entry.ReelRecords do
					Art.pose(passing, t + i * 0.7, false)
				end
			end
			Art.pose(entry.Record, t, false)
		end
		for _, effect in effects do
			if effect.Live then
				CardFX.update(effect, element, t)
			end
		end
	end)

	local finished = false
	local function allOut()
		if finished then
			return
		end
		finished = true
		title.Text = "YOUR KIT IS LOCKED IN"
		LotterySound.play("Attune")
		go.Visible = true
		tween(goScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	-- All three spin; Q stops first, then E, then R, each on its gem, which
	-- cracks and lets its surge out.
	for index, entry in cards do
		local spin = 1.2 + (index - 1) * 0.7
		task.delay(0.4, function()
			if shade.Parent and entry.Phase == "Sealed" then
				entry.Spinning = true
				-- Runs just past the gem, then springs back onto it.
				tween(entry.Strip, spin, { Position = UDim2.fromOffset(0, entry.Final + math.floor(CELL * 0.25)) }, Enum.EasingStyle.Quart)
				task.delay(spin, function()
					if entry.Phase == "Sealed" then
						tween(entry.Strip, 0.18, { Position = UDim2.fromOffset(0, entry.Final) }, Enum.EasingStyle.Back)
					end
				end)
			end
		end)
		local openAt = 0.4 + spin + 0.18
		task.delay(openAt, function()
			if shade.Parent then
				entry.open(false)
			end
		end)
		task.delay(openAt + 0.5, function()
			if shade.Parent then
				entry.surge(false)
				if index == #cards then
					task.delay(0.35, allOut)
				end
			end
		end)
	end
	-- Click during the roll: every gem cracks at once.
	listen(shade.Activated, function()
		if finished then
			return
		end
		for _, entry in cards do
			entry.surge(true)
		end
		LotterySound.play("Lock")
		allOut()
	end)
	local done = false
	listen(go.Activated, function()
		if done then
			return
		end
		done = true
		live:Disconnect()
		shade:Destroy()
		after()
	end)
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
	if phase == "Welcome" and pickStep == "Style" then
		setPickStep("Element")
		return
	end
	if phase == "Welcome" then
		if not chosenElement then
			refreshChoices()
			return
		end
		busy = true
		primary.Text = "EQUIPPING YOUR KIT…"
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
		-- No lottery: you chose the kit, so it's claimed straight away and
		-- you're in.
		reward = result.Lottery
		primary.Text = "BEGIN MY SAGA" -- (what a failed claim falls back to)
		if reward and reward.Element then
			busy = true
			revealMoves(reward, function()
				busy = false
				finish()
			end)
		else
			finish()
		end
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
	if not busy and not spin and primary.Active then
		tween(buttonStroke, 0.15, { Thickness = 2, Transparency = 0 })
		tween(primary, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 205, 120) })
	end
end)
listen(primary.MouseLeave, function()
	if not primary.Active then return end
	tween(buttonStroke, 0.15, { Thickness = 1, Transparency = if spin then 0.8 else 0.45 })
	if not spin then
		tween(primary, 0.15, { BackgroundColor3 = C.Gold })
	end
end)
listen(UserInputService.InputBegan, function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Space and phase ~= "Welcome" then
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
