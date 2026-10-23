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
if not Tutorial.Enabled and not FastStart.Enabled then
	return
end
local Art = require(script.Parent.Modules.LotteryArt)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local LotterySound = require(script.Parent.Modules.LotterySound)
local Icons = require(script.Parent.Modules.SurgeIcons)
local CardFX = require(script.Parent.Modules.ElementCardFX)
local LoadingFlow = require(script.Parent.Modules.LoadingFlow)
local KaijuRoll = require(script.Parent.Modules.KaijuRoll)
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
gui.IgnoreGuiInset = false
-- The strip under Roblox's top bar is dark too (the screens below start
-- under it), or the sky shows through it: a planet above the launch screen.
new("Frame", {
	Name = "TopBand",
	Position = UDim2.fromOffset(0, -120),
	Size = UDim2.new(1, 0, 0, 120),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
}, gui)
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
-- While you choose, the screen takes the colour of your pick, rising faintly
-- from the bottom (see refreshChoices).
local ambient = frame(back, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromScale(1, 0.7),
	BackgroundColor3 = C.Cyan,
	Visible = false,
	ZIndex = 1,
})
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.84) }),
}, ambient)
local panel = frame(back, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1, -24, 1, -16),
	ZIndex = 2,
})
local panelLimit = new("UISizeConstraint", { MaxSize = Vector2.new(1200, 880) }, panel)
-- Wide, short phones: the panel stops at about two and a half times its
-- height, so cards and buttons aren't stretched across the whole screen, but
-- four element cards still fit side by side on a 360-point-tall phone.
local function capPanel()
	local h = back.AbsoluteSize.Y
	if h > 0 then
		panelLimit.MaxSize = Vector2.new(math.clamp(h * 2.45, 560, 1200), 880)
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
-- The picks move on by themselves (no CONTINUE): set once advance exists.
local pickAdvance: ((string) -> ())? = nil
local pickRetry = false -- the launch failed: the button's back, as a retry
local pickToken = 0 -- bumped by every tap; a stale auto-advance does nothing
-- Only a previously committed kit restores an element. New choices start empty.
local chosenElement: string? = savedKit and savedKit.Element or nil
if savedKit then
	primary.Text = "CLAIM MY STARTER KIT"
end
-- Choose armor and element independently, then review the starter kit.
local choices = frame(body, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 })
local STYLES = {
	{
		Id = "Prospector",
		Color = GemConfig.ElementColors.Poison, -- card accent only
		Role = "BALANCED",
		-- A quick read of the style (ArmorFamilies: Primary stats per piece
		-- and set bonuses), out of 5.
		Profile = { Health = 4, Power = 4, Defense = 3, Speed = 3 },
		Tip = "Trade blows and outlast them. Steady damage, quick to recover.",
		Bonus = "+10% attack damage",
	},
	{
		Id = "Skirmisher",
		Color = GemConfig.ElementColors.Shock, -- card accent only
		Role = "MOBILE",
		Profile = { Health = 2, Power = 4, Defense = 2, Speed = 5 },
		Tip = "Strike, dodge, strike again. Speed and crits win the race.",
		Bonus = "+15% attack speed",
	},
	{
		Id = "Juggernaut",
		Color = GemConfig.ElementColors.Fire, -- card accent only
		Role = "HEAVY",
		Profile = { Health = 5, Power = 3, Defense = 5, Speed = 2 },
		Tip = "Hold the line. Block their best, then punish with heavy hits.",
		Bonus = "+25% heavy damage",
	},
}
local STATS = { "Health", "Power", "Defense", "Speed" }
-- Each style's key art (assets/images/intro/style_*.png, rendered by
-- tools/make_style_cards.py from the game's own fighters). 0 = not uploaded
-- yet: the card shows its colour instead.
local STYLE_ART = { Prospector = 72266295660132, Skirmisher = 84192854197420, Juggernaut = 76447015122752 }
-- Each element in a few words, and what its hits do (Shared.StatusEffects).
-- Hit: the first strength, short enough for a phone's narrow card.
-- The moves themselves are a surprise: they're rolled as you equip.
local ELEMENTS = {
	Fire = {
		Blurb = "Burn and burst",
		Hit = "Burns every second",
		Strengths = { "Burns them every second", "Critical burns cut their healing" },
	},
	Frost = {
		Blurb = "Slow, freeze, shield",
		Hit = "Every hit slows",
		Strengths = { "Every hit slows them down", "Can freeze them solid", "Shields you from harm" },
	},
	Shock = {
		Blurb = "Stun and chain",
		Hit = "Chains to the next foe",
		Strengths = { "Arcs chain to the next enemy", "Can stun them in place" },
	},
	Poison = {
		Blurb = "Shred and wear down",
		Hit = "Shreds their armor",
		Strengths = { "Shreds their armor", "Can leave them vulnerable", "Cuts their healing" },
	},
}
local function text(parent, value, size, color, font, props)
	local l = label(parent, value, size, color, font)
	l.ZIndex = 22
	for key, v in props or {} do
		l[key] = v
	end
	return l
end
local function hex(color)
	return string.format("#%02x%02x%02x", color.R * 255, color.G * 255, color.B * 255)
end
-- A small rounded tag sized to its words (in any language).
local function tag(parent, value, color)
	local pill = frame(parent, {
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		ZIndex = 25,
	})
	UiKit.round(pill, 999)
	stroke(pill, color, 0.35, 1)
	new("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }, pill)
	local words = text(pill, value, 10, color, Enum.Font.GothamBold, { ZIndex = 26 })
	words.AutomaticSize, words.Size = Enum.AutomaticSize.X, UDim2.fromScale(0, 1)
	words.TextTruncate = Enum.TextTruncate.None
	return pill
end
-- The selected mark, top right: an empty ring, filled with a tick once chosen.
local function checkMark(parent)
	local ring = frame(parent, {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 26,
	})
	UiKit.round(ring, 999)
	local edge = stroke(ring, C.Edge, 0, 1.5)
	local tick = text(ring, "✓", 15, C.Ink, Enum.Font.GothamBlack, { ZIndex = 27, Visible = false })
	tick.TextXAlignment = Enum.TextXAlignment.Center
	return { Ring = ring, Edge = edge, Tick = tick }
end
local function setCheck(check, on, color)
	check.Ring.BackgroundColor3 = if on then color else C.Ink
	check.Ring.BackgroundTransparency = if on then 0 else 0.55
	check.Edge.Color = if on then color else C.Edge
	check.Edge.Transparency = if on then 0 else 0.35
	check.Tick.Visible = on
end
-- Every piece lays itself out from its own size: compactMode and richMode
-- (short and tall screens) only pick the words.
local relayout, compactMode, richMode = {}, false, false
local shortScreen = false -- (phones in landscape: the subtitle shares the title's row)
-- The fast start's two screens: "Style" (three fighters), then "Element"
-- (the four elements and what each is good at).
local pickStep = if savedKit then "Element" else "Style"
local function place(apply)
	table.insert(relayout, apply)
	apply(false, false)
end

local styleButtons, elementButtons = {}, {}
local refreshChoices -- (below)

-- Style: three tall fighter cards. Each leads with its key art, framed on
-- the fighter (a short card never cuts the head off), then its name, what it's
-- for, a quick read of its stats, and the bonus a two-piece set gives.
local styleArea = frame(choices, { BackgroundTransparency = 1, ZIndex = 21 })
local ART_ASPECT = 480 / 392 -- (the key art's shape)
-- Where each fighter's head is, down its art (0..1): kept a third of the way
-- down the window.
local ART_HEAD = { Prospector = 0.36, Skirmisher = 0.23, Juggernaut = 0.3 }
local function layoutStyleCard(card, w: number, h: number)
	local small = h < 360
	local pad = if small then 12 else 16
	-- The art: as wide as the card, the fighter's head in view.
	local artH = math.floor(h * (if small then 0.52 else 0.54))
	card.Window.Size = UDim2.new(1, 0, 0, artH)
	local imageH = math.max(artH, math.floor(w / ART_ASPECT))
	local imageW = math.max(w, math.floor(imageH * ART_ASPECT))
	local top = math.clamp(math.floor(card.Head * imageH - artH / 3), 0, imageH - artH)
	card.Art.Position = UDim2.fromOffset(math.floor((w - imageW) / 2), -top)
	card.Art.Size = UDim2.fromOffset(imageW, imageH)
	card.Role.Position = UDim2.fromOffset(pad - 4, pad - 4)
	card.Check.Ring.Position = UDim2.new(1, -(pad - 4), 0, pad - 4)
	-- The name sits on the art's fade, an accent bar under it.
	local nameH = if small then 24 else 34
	card.Name.TextSize = if small then 20 else math.clamp(math.floor(w / 12), 22, 30)
	card.Name.Position, card.Name.Size = UDim2.fromOffset(pad, artH - nameH + 2), UDim2.new(1, -pad * 2, 0, nameH)
	card.Bar.Position, card.Bar.Size = UDim2.fromOffset(pad, artH + 6), UDim2.fromOffset(if small then 22 else 30, 3)
	local y = artH + (if small then 16 else 20)
	local tipH = if small or w < 240 then 0 else 36
	card.Tip.Visible = tipH > 0
	card.Tip.Position, card.Tip.Size = UDim2.fromOffset(pad, y), UDim2.new(1, -pad * 2, 0, tipH)
	card.Tip.TextSize = if w >= 330 then 13 else 12
	y += tipH + (if tipH > 0 then 6 else 0)
	-- The set bonus along the bottom: what it is over what it gives.
	local bonusH = if small then 34 elseif h >= 400 then 46 else 40
	card.Strip.Position, card.Strip.Size = UDim2.new(0, 0, 1, -bonusH), UDim2.new(1, 0, 0, bonusH)
	card.BonusHead.Position = UDim2.fromOffset(pad, if small then 5 else 8)
	card.BonusHead.Size = UDim2.new(1, -pad * 2, 0, if small then 10 else 12)
	card.BonusValue.Position = UDim2.fromOffset(pad, if small then 16 else 21)
	card.BonusValue.Size = UDim2.new(1, -pad * 2, 0, if small then 14 else 17)
	card.BonusHeadLimit.MaxTextSize = if small then 8 else 10
	card.BonusValueLimit.MaxTextSize = if small then 12 elseif bonusH >= 46 then 14 else 13
	-- The stat bars share what's left between the words and the bonus.
	local rowH = math.clamp(math.floor((h - bonusH - y - (if small then 8 else 12)) / #STATS), 0, 22)
	local labelW = if w >= 300 then 80 else 72
	local barW = w - pad * 2 - labelW
	local segment = math.floor((barW + 4) / 5)
	for index, row in card.Stats do
		local show = rowH >= 11
		local rowY = y + (index - 1) * rowH
		row.Label.Visible = show
		row.Label.TextSize = if rowH >= 18 then 10 else 9
		row.Label.Position, row.Label.Size = UDim2.fromOffset(pad, rowY), UDim2.fromOffset(labelW, rowH)
		for pip, piece in row.Pips do
			piece.Visible = show
			piece.Position = UDim2.fromOffset(pad + labelW + (pip - 1) * segment, rowY + math.floor(rowH / 2) - 2)
			piece.Size = UDim2.fromOffset(segment - 4, 5)
		end
	end
end
-- The picked card's halo: two soft rings of its colour round it.
local function placeHalo(card)
	local position, size = card.Button.Position, card.Button.Size
	for i, ring in card.Halo do
		local grow = if i == 1 then 10 else 4
		ring.Position = UDim2.fromOffset(position.X.Offset - grow, position.Y.Offset - grow)
		ring.Size = UDim2.fromOffset(size.X.Offset + grow * 2, size.Y.Offset + grow * 2)
	end
end
local function layoutStyles()
	local width, height = styleArea.AbsoluteSize.X, styleArea.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	-- (a little room round the edge for the picked card's halo)
	local inset = 6
	local gap = if width < 700 then 10 else 16
	local cardW = math.floor((width - inset * 2 - gap * 2) / 3)
	local cardH = math.min(height - inset * 2, 560)
	local y0 = math.floor((height - cardH) / 2)
	for i, style in STYLES do
		local card = styleButtons[style.Id]
		if card then
			card.Button.Position = UDim2.fromOffset(inset + (i - 1) * (cardW + gap), y0)
			card.Button.Size = UDim2.fromOffset(cardW, cardH)
			layoutStyleCard(card, cardW, cardH)
			placeHalo(card)
		end
	end
end
place(function()
	styleArea.Visible = pickStep == "Style"
	styleArea.Position, styleArea.Size = UDim2.new(), UDim2.fromScale(1, 1)
	layoutStyles()
end)
listen(styleArea:GetPropertyChangedSignal("AbsoluteSize"), layoutStyles)
for _, style in STYLES do
	local halo = {}
	for i = 1, 2 do
		local ring = frame(styleArea, {
			BackgroundColor3 = style.Color,
			BackgroundTransparency = 1,
			ZIndex = 20,
		})
		UiKit.round(ring, if i == 1 then 20 else 15)
		halo[i] = ring
	end
	local card = new("TextButton", {
		Name = style.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Card,
		ZIndex = 21,
		ClipsDescendants = true,
	}, styleArea)
	UiKit.round(card, 12)
	local edge = stroke(card, C.Line, 0, 1)
	local pop = new("UIScale", { Scale = 1 }, card)
	-- The art's window: the edges and top darkened so the eye goes to the
	-- fighter, and fading into the card at the bottom, under the name.
	local window = frame(card, {
		Name = "ArtWindow",
		BackgroundColor3 = style.Color:Lerp(C.Ink, 0.82),
		ClipsDescendants = true,
		ZIndex = 22,
	})
	local artId = STYLE_ART[style.Id] or 0
	local art = new("ImageLabel", {
		Name = "StyleArt",
		BackgroundTransparency = 1,
		Image = if artId ~= 0 then "rbxassetid://" .. artId else "",
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 22,
	}, window)
	local sides = frame(window, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, ZIndex = 23 })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.24, 1),
			NumberSequenceKeypoint.new(0.76, 1),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
	}, sides)
	local shade = frame(window, { Size = UDim2.fromScale(1, 0.32), BackgroundColor3 = C.Ink, ZIndex = 23 })
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
	}, shade)
	local scrim = frame(window, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.56),
		BackgroundColor3 = C.Card,
		ZIndex = 23,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, scrim)
	-- A glassy light along the top edge.
	frame(card, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 0, 1),
		ZIndex = 24,
	})
	local role = tag(card, style.Role, style.Color)
	local check = checkMark(card)
	local name = text(card, string.upper(style.Id), 28, C.Text, Enum.Font.GothamBlack, { ZIndex = 25 })
	local bar = frame(card, { BackgroundColor3 = style.Color, ZIndex = 25 })
	UiKit.round(bar, 999)
	local tip = text(card, style.Tip, 13, C.Dim, Enum.Font.Gotham, { TextWrapped = true })
	tip.TextYAlignment = Enum.TextYAlignment.Top
	local stats = {}
	for _, stat in STATS do
		local statLabel = text(card, string.upper(stat), 10, C.Dim, Enum.Font.GothamBold)
		local pips = {}
		for pip = 1, 5 do
			local piece = frame(card, { BackgroundColor3 = C.Line, ZIndex = 23 })
			UiKit.round(piece, 999)
			pips[pip] = piece
		end
		table.insert(stats, { Label = statLabel, Pips = pips, Value = style.Profile[stat] or 0 })
	end
	-- The set bonus: a strip of its colour along the bottom, a hairline over it.
	local strip = frame(card, { Name = "BonusStrip", BackgroundColor3 = style.Color:Lerp(C.Card, 0.88), ZIndex = 22 })
	local hairline = frame(strip, { BackgroundColor3 = style.Color, Size = UDim2.new(1, 0, 0, 1), ZIndex = 23 })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, hairline)
	local bonusHead = text(strip, "2-PIECE BONUS", 10, C.Dim, Enum.Font.GothamBold, { ZIndex = 24 })
	bonusHead.TextScaled = true
	local bonusHeadLimit = new("UITextSizeConstraint", { MaxTextSize = 10, MinTextSize = 7 }, bonusHead)
	local bonusValue = text(strip, style.Bonus, 13, style.Color, Enum.Font.GothamBold, { ZIndex = 24 })
	bonusValue.TextScaled = true
	local bonusValueLimit = new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, bonusValue)
	local entry = {
		Button = card,
		Stroke = edge,
		Pop = pop,
		Halo = halo,
		Window = window,
		Art = art,
		Head = ART_HEAD[style.Id] or 0.3,
		Scrim = scrim,
		Role = role,
		Check = check,
		Name = name,
		Bar = bar,
		Tip = tip,
		Stats = stats,
		Strip = strip,
		BonusHead = bonusHead,
		BonusHeadLimit = bonusHeadLimit,
		BonusValue = bonusValue,
		BonusValueLimit = bonusValueLimit,
		Color = style.Color,
	}
	styleButtons[style.Id] = entry
	listen(card.Activated, function()
		if not savedKit and not busy then
			chosenStyle = style.Id
			refreshChoices()
			layoutStyles()
			-- (A beat to see it picked, then on to the element.)
			if pickAdvance then
				pickAdvance("Style")
			end
		end
	end)
	-- A pointer over it lifts its edge and its art.
	listen(card.MouseEnter, function()
		entry.Hover = true
		refreshChoices()
	end)
	listen(card.MouseLeave, function()
		entry.Hover = false
		refreshChoices()
	end)
end

-- Element: four cards, each the element's gem, what it's about and its
-- strengths, and which element it beats and which beats it. Side by side
-- when the screen is wide, two by two when it's tall, a scrolling column
-- only on very small portrait screens.
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
local CARD_TALL = 410 -- a card at its fullest
local CARD_MIN_H, CARD_MIN_W = 150, 150 -- (a card this short still fits gem, name and matchup)

-- Lay one element card out inside w x h: the gem on its stage on top (tall
-- cards) or at the left (wide ones), as big as the card allows, then as much
-- of the rest as fits. The matchup always shows, as two tiles along the
-- bottom: what it beats and what it's weak to.
local function layoutCard(card, w: number, h: number)
	local wide = w > h * 1.15
	local pad = if w < 200 then 10 else 16
	local narrow = w < 200
	-- What its hits do: one line each, as many as fit.
	local lineH = if narrow then 15 elseif w < 220 then 17 else 20
	local lineSize = if narrow then 10 elseif w < 220 then 11 else 12
	-- The matchup: two tiles side by side, or (too narrow for a long element
	-- name in half the card) two one-line rows, one over the other.
	local gap = if narrow then 4 else 6
	local tileW = math.floor((w - pad * 2 - gap) / 2)
	local stacked = tileW < 110
	local rowH = if h < 260 then 19 else 22
	local matchH = if stacked then rowH * 2 + gap elseif h < 260 then 32 else 40
	for i, tile in { card.Strong, card.Weak } do
		if stacked then
			tile.Frame.Position = UDim2.new(0, pad, 1, -pad - matchH + (i - 1) * (rowH + gap))
			tile.Frame.Size = UDim2.new(1, -pad * 2, 0, rowH)
			local tight = w < 170
			tile.HeadLimit.MaxTextSize = if tight then 8 else 9
			tile.NameLimit.MaxTextSize = if tight then 9 elseif narrow then 10 else 11
			tile.Name.Text = if tight then tile.Short else tile.Long
			tile.Head.TextXAlignment, tile.Name.TextXAlignment = Enum.TextXAlignment.Right, Enum.TextXAlignment.Left
			tile.Head.Position, tile.Head.Size = UDim2.new(), UDim2.new(0.44, 0, 1, 0)
			tile.Name.Position, tile.Name.Size = UDim2.new(0.44, 6, 0, 0), UDim2.new(0.56, -8, 1, 0)
		else
			local small = matchH < 36
			tile.Name.Text = tile.Long
			tile.Frame.Position = UDim2.new(0, pad + (i - 1) * (tileW + gap), 1, -pad - matchH)
			tile.Frame.Size = UDim2.fromOffset(tileW, matchH)
			tile.HeadLimit.MaxTextSize, tile.NameLimit.MaxTextSize = if small then 8 else 9, if small then 10 else 12
			tile.Head.TextXAlignment, tile.Name.TextXAlignment = Enum.TextXAlignment.Center, Enum.TextXAlignment.Center
			tile.Head.Position = UDim2.fromOffset(0, if small then 3 else 6)
			tile.Head.Size = UDim2.new(1, 0, 0, if small then 11 else 12)
			tile.Name.Position = UDim2.fromOffset(4, if small then 14 else 19)
			tile.Name.Size = UDim2.new(1, -8, 0, if small then 14 else 16)
		end
	end
	card.Check.Ring.Position = UDim2.new(1, -10, 0, 10)
	local bottom = h - pad - matchH - 8 -- the strengths end here
	local function placeLines(x: number, top: number, room: number): number
		local fit = math.max(0, math.floor(room / lineH))
		for index, pair in card.Lines do
			local show = index <= fit
			local y = top + (index - 1) * lineH
			pair[1].Visible, pair[2].Visible = show, show
			pair[1].Position, pair[1].Size = UDim2.fromOffset(x, y), UDim2.fromOffset(10, lineH)
			pair[2].Position, pair[2].Size = UDim2.fromOffset(x + 16, y), UDim2.new(1, -x - pad - 16, 0, lineH)
			pair.Limit.MaxTextSize, pair[2].TextWrapped = lineSize, false
			pair[2].Text = if narrow and index == 1 then card.Hit else pair.Full
		end
		return fit
	end
	-- The gem, its glow and ring round it, and its shadow under it.
	local function placeGem(x: number, y: number, gem: number)
		card.Holder.Position, card.Holder.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(gem, gem)
		local glow = gem + math.floor(gem * 0.18)
		card.Stage.Position = UDim2.fromOffset(x + math.floor((gem - glow) / 2), y + math.floor((gem - glow) / 2))
		card.Stage.Size = UDim2.fromOffset(glow, glow)
		local sw, sh = math.floor(gem * 0.5), math.max(4, math.floor(gem * 0.06))
		card.Shadow.Position = UDim2.fromOffset(x + math.floor((gem - sw) / 2), y + math.floor(gem * 0.84))
		card.Shadow.Size = UDim2.fromOffset(sw, sh)
	end
	if wide then
		-- Gem at the left, name and what it's about beside it, its hits under them.
		local gem = math.clamp(math.floor(bottom - pad), 56, 150)
		placeGem(pad, pad, gem)
		local x = pad + gem + 14
		card.Name.TextXAlignment, card.Blurb.TextXAlignment = Enum.TextXAlignment.Left, Enum.TextXAlignment.Left
		card.Name.TextSize = math.clamp(math.floor(gem * 0.24), 18, 28)
		card.Name.Position, card.Name.Size = UDim2.fromOffset(x, pad), UDim2.new(1, -x - 36, 0, 30)
		card.Blurb.TextSize = 13
		card.Blurb.Position, card.Blurb.Size = UDim2.fromOffset(x, pad + 30), UDim2.new(1, -x - pad, 0, 18)
		card.Divider.Position, card.Divider.Size = UDim2.fromOffset(x, pad + 52), UDim2.new(1, -x - pad, 0, 1)
		card.Divider.Visible = placeLines(x, pad + 58, bottom - pad - 58) > 0
		return
	end
	-- Tall: the gem leads, then the name, what it's about, and its hits.
	card.Name.TextXAlignment, card.Blurb.TextXAlignment = Enum.TextXAlignment.Center, Enum.TextXAlignment.Center
	local nameH = if narrow then 24 else 30
	local blurbH = if narrow then 15 else 18
	-- The gem takes what's left once the words have their lines of hits (more
	-- of them on taller cards), up to about half the card.
	local wanted = if h >= 380 then 3 elseif h >= 300 then 2 else 1
	local words = 6 + nameH + blurbH + 12 + lineH * wanted
	local cap = math.min(w - pad * 2 - 8, math.floor(h * 0.5), 200)
	local gem = math.clamp(bottom - pad - words, math.min(48, cap), math.max(cap, 1))
	placeGem(math.floor((w - gem) / 2), pad, gem)
	local y = pad + gem + 6
	card.Name.TextSize = math.clamp(math.floor(w / 9), 18, 28)
	card.Name.Position, card.Name.Size = UDim2.fromOffset(pad, y), UDim2.new(1, -pad * 2, 0, nameH)
	y += nameH
	card.Blurb.TextSize = if narrow then 11 else 13
	card.Blurb.Position, card.Blurb.Size = UDim2.fromOffset(pad, y), UDim2.new(1, -pad * 2, 0, blurbH)
	y += blurbH + 6
	-- A hairline under the blurb, fading out at its ends.
	card.Divider.Position, card.Divider.Size = UDim2.fromOffset(pad + 6, y), UDim2.new(1, -pad * 2 - 12, 0, 1)
	y += 6
	card.Divider.Visible = placeLines(pad + 2, y, bottom - y) > 0
end

local function layoutElements()
	local width, height = elementArea.AbsoluteSize.X, elementArea.AbsoluteSize.Y
	if width <= 0 or height <= 0 then
		return
	end
	local gap, inset = if width < 700 then 8 else 12, 4
	-- Every arrangement's card size; the first that fits wins.
	local function size(columns)
		local rows = math.ceil(#elementOrder / columns)
		return math.floor((width - inset * 2 - gap * (columns - 1)) / columns),
			math.floor((height - inset * 2 - gap * (rows - 1)) / rows)
	end
	local w4, h4 = size(4)
	local w2, h2 = size(2)
	local columns, cardW, cardH, scroll
	if w2 >= 380 and h2 >= 200 and w4 < 230 then
		columns, cardW, cardH = 2, w2, math.min(h2, 260) -- (tall screens: two by two)
	elseif w4 >= CARD_MIN_W and h4 >= CARD_MIN_H then
		columns, cardW, cardH = 4, w4, math.min(h4, CARD_TALL) -- (wide: side by side)
	elseif w2 >= CARD_MIN_W and h2 >= 150 then
		columns, cardW, cardH = 2, w2, h2
	else
		-- Very small (portrait phones): one column, scrolling.
		columns, cardW, cardH, scroll = 1, width - inset * 2 - 8, 200, true
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
place(function()
	elementArea.Visible = pickStep == "Element"
	elementArea.Position, elementArea.Size = UDim2.new(), UDim2.fromScale(1, 1)
	layoutElements()
end)
listen(elementArea:GetPropertyChangedSignal("AbsoluteSize"), layoutElements)
-- A matchup tile: "▲ BEATS" over the element it beats, or "▼ WEAK TO" over
-- the one that beats it, in that element's colour.
local function matchTile(parent, good: boolean, other: string)
	local tile = frame(parent, {
		BackgroundColor3 = if good then Color3.fromRGB(19, 38, 32) else Color3.fromRGB(42, 21, 27),
		ZIndex = 22,
	})
	UiKit.round(tile, 8)
	stroke(tile, if good then Color3.fromRGB(70, 150, 110) else Color3.fromRGB(165, 72, 84), 0.72, 1)
	local head = text(
		tile,
		string.format(
			'<font color="%s">%s</font>  %s',
			if good then "#6fe0a0" else "#ff7a7a",
			if good then "▲" else "▼",
			if good then "BEATS" else "WEAK TO"
		),
		9,
		C.Dim,
		Enum.Font.GothamBold,
		{ RichText = true, ZIndex = 23 }
	)
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.TextScaled = true
	local headLimit = new("UITextSizeConstraint", { MaxTextSize = 9, MinTextSize = 6 }, head)
	local shade = hex(GemConfig.ElementColors[other])
	local word = string.format('<font color="%s">%s</font>', shade, string.upper(GemConfig.elementName(other)))
	local long = string.format('<font color="%s">◆</font>  %s', shade, word)
	local name = text(tile, long, 12, C.Text, Enum.Font.GothamBlack, { RichText = true, ZIndex = 23 })
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextScaled = true
	local nameLimit = new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }, name)
	-- (Short: without the dot, for the narrowest cards. The limits are the
	-- sizes the layout picks: a longer translation shrinks a little instead.)
	return {
		Frame = tile,
		Head = head,
		Name = name,
		Long = long,
		Short = word,
		HeadLimit = headLimit,
		NameLimit = nameLimit,
	}
end
for _, element in elementOrder do
	local info = ELEMENTS[element]
	local color = GemConfig.ElementColors[element]
	local card = new("TextButton", {
		Name = element,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Card,
		ZIndex = 21,
		ClipsDescendants = true,
	}, elementArea)
	UiKit.round(card, 12)
	local edge = stroke(card, C.Line, 0, 1)
	-- A wash of its colour down from the top (stronger once picked), and a
	-- glassy light along the top edge.
	local wash = frame(card, { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), ZIndex = 21 })
	local washFade = new("UIGradient", { Rotation = 90 }, wash)
	frame(card, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 0, 1),
		ZIndex = 22,
	})
	-- The gem's stage: a soft glow, a ring (a spark runs round it once
	-- picked), and a shadow under the gem.
	local stage = frame(card, { BackgroundTransparency = 1, ZIndex = 22 })
	local glow = {}
	-- (five faint discs, one inside the other: brightest at the middle, with
	-- no hard rings)
	for _, scale in { 1, 0.86, 0.72, 0.58, 0.44 } do
		local disc = frame(stage, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.965,
			ZIndex = 22,
		})
		UiKit.round(disc, 999)
		table.insert(glow, { Disc = disc, Base = 0.965 })
	end
	local ring = frame(stage, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1,
		ZIndex = 22,
	})
	UiKit.round(ring, 999)
	local ringEdge = stroke(ring, color, 0.72, 1.5)
	local spark = frame(ring, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Visible = false,
		ZIndex = 23,
	})
	UiKit.round(spark, 999)
	local shadow = frame(card, { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 22 })
	UiKit.round(shadow, 999)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shadow)
	local holder = frame(card, { BackgroundTransparency = 1, ZIndex = 23 })
	local gem = { Id = "starter-" .. element, Element = element, Tier = "Common", Size = 3, Clarity = 5, Cut = 5 }
	local art = Art.show(holder, gem, nil, color, false)
	local check = checkMark(card)
	local nameLabel = text(card, string.upper(GemConfig.elementName(element)), 24, color, Enum.Font.GothamBlack)
	local blurb = text(card, info.Blurb, 13, C.Text, Enum.Font.GothamMedium)
	local divider = frame(card, { BackgroundColor3 = color:Lerp(C.Line, 0.6), ZIndex = 22, Visible = false })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, divider)
	local lines = {}
	for _, strength in info.Strengths do
		local mark = text(card, "◆", 8, color, Enum.Font.GothamBlack)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		local line = text(card, strength, 12, C.Dim, Enum.Font.GothamMedium)
		line.TextScaled = true
		local limit = new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }, line)
		table.insert(lines, { mark, line, Full = strength, Limit = limit })
	end
	local strong = matchTile(card, true, ElementMatchup.Beats[element])
	local weak = matchTile(card, false, ElementMatchup.weakTo(element))
	local entry = {
		Button = card,
		Stroke = edge,
		WashFade = washFade,
		Stage = stage,
		Glow = glow,
		Ring = ringEdge,
		Spark = spark,
		Shadow = shadow,
		Holder = holder,
		Check = check,
		Name = nameLabel,
		Blurb = blurb,
		Divider = divider,
		Lines = lines,
		Strong = strong,
		Weak = weak,
		Color = color,
		Gem = gem,
		Art = art,
		Hit = info.Hit,
		Phase = #elementOrder * 0.7 - (table.find(elementOrder, element) or 1) * 0.7,
	}
	elementButtons[element] = entry
	listen(card.Activated, function()
		if not savedKit and not busy then
			chosenElement = element
			refreshChoices()
			layoutElements()
			-- (A beat to see it picked, then the kit's equipped and rolled.)
			if pickAdvance then
				pickAdvance("Element")
			end
		end
	end)
	-- A pointer over it lifts its edge.
	listen(card.MouseEnter, function()
		entry.Hover = true
		refreshChoices()
	end)
	listen(card.MouseLeave, function()
		entry.Hover = false
		refreshChoices()
	end)
end
layoutElements()

-- The gems turn while you choose: the picked one quicker. (A gem's a few
-- dozen parts; 30 turns a second is smooth and keeps phones cool.)
local spinAt, spun = 0, 0
listen(RunService.RenderStepped, function(dt)
	spun += dt
	if spun < 1 / 30 then
		return
	end
	local step = spun
	spun = 0
	if closed or not gui.Enabled or not elementArea.Visible or pickStep ~= "Element" then
		return
	end
	spinAt += step
	for id, card in elementButtons do
		local model = card.Art and card.Art.Model
		if model and model.Parent then
			local speed = if id == chosenElement then 1.6 else 0.6
			card.Turn = (card.Turn or card.Phase) + step * speed
			model:PivotTo(GemArt.pose(card.Gem, card.Turn))
		end
	end
	-- The picked gem's spark, round its ring.
	local picked = chosenElement and elementButtons[chosenElement]
	if picked then
		local angle = spinAt * 1.4 - math.pi / 2
		picked.Spark.Position = UDim2.fromScale(0.5 + 0.5 * math.cos(angle), 0.5 + 0.5 * math.sin(angle))
	end
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

local poppedStyle = chosenStyle
function refreshChoices()
	-- The picked style glows and its art is at full light; the others step back
	-- (a pointer over one lifts it).
	for id, card in styleButtons do
		local on = id == chosenStyle
		local back = if on then C.Card:Lerp(card.Color, 0.08) else C.Card
		card.Stroke.Color = if on then card.Color elseif card.Hover then card.Color:Lerp(C.Edge, 0.5) else C.Line
		card.Stroke.Thickness = if on then 2 else 1
		card.Halo[1].BackgroundTransparency = if on then 0.93 else 1
		card.Halo[2].BackgroundTransparency = if on then 0.86 else 1
		card.Button.BackgroundColor3 = back
		card.Scrim.BackgroundColor3 = back
		card.Art.ImageColor3 = if on
			then Color3.new(1, 1, 1)
			elseif card.Hover then Color3.fromRGB(228, 230, 235)
			else Color3.fromRGB(178, 182, 192)
		card.Name.TextColor3 = if on then C.Text else C.Text:Lerp(C.Dim, 0.4)
		card.Bar.BackgroundTransparency = if on then 0 else 0.6
		card.Tip.TextColor3 = if on then C.Text:Lerp(C.Dim, 0.3) else C.Dim
		card.Strip.BackgroundColor3 = card.Color:Lerp(C.Card, if on then 0.84 else 0.93)
		card.BonusValue.TextColor3 = if on then card.Color else card.Color:Lerp(C.Dim, 0.45)
		setCheck(card.Check, on, card.Color)
		for _, row in card.Stats do
			row.Label.TextColor3 = if on then C.Text:Lerp(C.Dim, 0.4) else C.Dim
			for pip, piece in row.Pips do
				local lit = pip <= row.Value
				piece.BackgroundColor3 = if lit then card.Color else C.Line
				piece.BackgroundTransparency = if lit then (if on then 0 else 0.5) else 0.35
			end
		end
	end
	-- A new pick pops.
	if chosenStyle ~= poppedStyle then
		poppedStyle = chosenStyle
		local card = styleButtons[chosenStyle]
		if card then
			card.Pop.Scale = 1.035
			tween(card.Pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	-- The picked element lights up; once one is picked, the others step back.
	for id, card in elementButtons do
		local on = id == chosenElement
		local back = chosenElement ~= nil and not on
		card.Stroke.Color = if on then card.Color elseif card.Hover then card.Color:Lerp(C.Edge, 0.5) else C.Line
		card.Stroke.Thickness = if on then 2 else 1
		card.Button.BackgroundColor3 = if on then C.Card:Lerp(card.Color, 0.12) else C.Card
		card.WashFade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if on then 0.62 elseif back then 0.9 else 0.8),
			NumberSequenceKeypoint.new(0.6, if on then 0.94 else 0.98),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, glow in card.Glow do
			glow.Disc.BackgroundTransparency = if on
				then glow.Base - 0.02
				elseif back then glow.Base + 0.015
				else glow.Base
		end
		card.Ring.Transparency = if on then 0.2 elseif back then 0.9 else 0.72
		card.Spark.Visible = on
		card.Name.TextColor3 = if back then card.Color:Lerp(C.Dim, 0.45) else card.Color
		card.Blurb.TextColor3 = if back then C.Dim else C.Text
		if card.Art and card.Art.View then
			card.Art.View.ImageTransparency = if back then 0.35 else 0
		end
		for _, pair in card.Lines do
			pair[2].TextColor3 = if on then C.Text elseif back then C.Faint else C.Dim
		end
		setCheck(card.Check, on, card.Color)
	end
	-- The screen takes the colour of your pick (the style's, then the element's).
	local tint = if reward
		then nil
		elseif pickStep == "Element" then chosenElement and GemConfig.ElementColors[chosenElement]
		else styleButtons[chosenStyle] and styleButtons[chosenStyle].Color
	ambient.Visible = tint ~= nil
	if tint then
		tween(ambient, 0.35, { BackgroundColor3 = tint })
	end
	-- This screen's words and button.
	if not reward then
		-- (The reveal's panels wait underneath, out of sight.)
		hero.Visible, rack.Visible = false, false
		brand.Text = if pickStep == "Style" then "STEP 1 OF 2" else "STEP 2 OF 2"
		brand.TextColor3 = C.Gold
		title.Text = if pickStep == "Style" then "CHOOSE YOUR STYLE" else "CHOOSE YOUR ELEMENT"
		subtitle.Text = if pickStep == "Style"
			then (if shortScreen
				then "The armor you start in. You can wear any set later."
				else "The armor you start in, with a sword and shield. You can wear any set later.")
			elseif shortScreen then "Your gems and your Q, E and R moves use it. Each one beats another."
			else string.format(
				"%s armor is set. Your gems, and the Q, E and R moves they give you, take this element. Each one beats another.",
				chosenStyle
			)
		if not busy then
			-- (No CONTINUE: tapping a card moves on. The button only shows
			-- to retry a launch that failed.)
			-- (A saved kit can't be re-picked: its button walks it through.)
			local shown = pickRetry or savedKit ~= nil
			primary.Visible = shown
			primary.Text = if pickRetry then "RETRY THE LAUNCH"
				elseif pickStep == "Style" then "CONTINUE   ›"
				else "EQUIP & FIGHT"
			primary.Active, primary.Selectable = shown, shown
			primary.BackgroundColor3 = C.Gold
			primary.TextColor3 = C.Ink
		end
		backStep.Visible = pickStep == "Element" and not savedKit
	end
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
		pickToken += 1
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
	-- Short screens (phones): the subtitle shares the title's row, at its
	-- right, while you pick; the reveal that follows keeps the row for itself.
	local besideTitle = short and w >= 560
	title.Position, title.Size =
		UDim2.fromOffset(0, if short then 18 else 24),
		UDim2.new(if besideTitle then 0.46 else 1, 0, 0, if short then 26 else 42)
	subtitle.Visible = not short or (besideTitle and reward == nil)
	brand.Visible = not short -- (short screens: the title takes its line)
	if besideTitle then
		subtitle.Position, subtitle.Size = UDim2.new(0.46, 8, 0, 12), UDim2.new(0.54, -8, 0, 36)
		subtitle.TextXAlignment, subtitle.TextWrapped, subtitle.TextSize = Enum.TextXAlignment.Right, true, 12
	else
		subtitle.Position, subtitle.Size = UDim2.fromOffset(0, if narrow then 62 else 70), UDim2.new(1, 0, 0, 22)
		subtitle.TextXAlignment, subtitle.TextWrapped, subtitle.TextSize = Enum.TextXAlignment.Left, false, 14
	end
	if short ~= shortScreen then
		shortScreen = short
		refreshChoices()
	end
	-- (No reveal steps any more: you pick your kit and go.)
	stepper.Visible = false
	motion.Visible = false
	body.Position, body.Size = UDim2.fromOffset(0, header), UDim2.new(1, 0, 0, bodyHeight)
	-- Short screens (phones): the compact picker.
	layoutChoices(bodyHeight < 420, bodyHeight >= 560)
	layoutStyles()
	layoutElements()
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
	primary.Visible = true -- (hidden on the picks; the reveal's own button)
	hero.Visible, rack.Visible = true, true
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
	{ Key = "E", Color = Color3.fromRGB(122, 196, 255), Slot = "CHEST", Gem = "CHEST GEM", Pays = "CHARGE" },
	{ Key = "R", Color = Color3.fromRGB(120, 230, 170), Slot = "DEFENSE", Gem = "SHIELD GEM", Pays = "STAMINA" },
}
local WELL = 156 -- (px: the reel's window)
local CELL = 108 -- (px: one gem on the reel)
local WINDOW_ROUND = 26 -- (px: the window's corners)
local reelWindow -- (in revealMoves: the 3D gems in a reel's window)
local function keycap(parent, key, color, size)
	-- A physical key: a darker base under a raised cap.
	local base = frame(
		parent,
		{ BackgroundColor3 = color:Lerp(C.Ink, 0.55), Size = UDim2.fromOffset(size, size + 6), ZIndex = 45 }
	)
	UiKit.round(base, 9)
	local cap = frame(base, { BackgroundColor3 = color, Size = UDim2.fromOffset(size, size), ZIndex = 46 })
	UiKit.round(cap, 9)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color) }, cap)
	local glyph = label(cap, key, math.floor(size * 0.58), C.Ink, Enum.Font.GothamBlack)
	glyph.TextXAlignment, glyph.ZIndex = Enum.TextXAlignment.Center, 47
	return base
end
-- The reel rolls like a real gem roll of your element: every rarity at its
-- real odds (GemRoller), each gem in its own shade (Thermal: Ember Red up to
-- Starfire Ruby) on a glow of its rarity's colour. Only the gems in the window
-- are 3D: each reel keeps a few gem models per rarity and hands them to the
-- cells passing through (a gem is about a hundred parts; a fresh one for
-- every cell would be thousands).
local function shadeOf(element, tier)
	for _, shade in GemConfig.Shades[element] or {} do
		if shade.Tier == tier then
			return shade
		end
	end
	return nil
end
-- A glow of the rarity's colour behind a gem on the reel: stronger the rarer.
local GLOW = { Common = 0.9, Uncommon = 0.86, Rare = 0.8, UltraRare = 0.74, Legendary = 0.66 }
local function rarityGlow(cell, tier)
	local color = GemConfig.TierColors[tier] or C.Line
	for i, scale in { 0.86, 0.56 } do
		local disc = frame(cell, {
			Name = "RarityGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(CELL * scale), math.floor(CELL * scale)),
			BackgroundColor3 = color,
			BackgroundTransparency = (GLOW[tier] or 0.9) + (i - 1) * 0.04,
			ZIndex = 45,
		})
		UiKit.round(disc, 999)
	end
end
-- Seconds the locked-in kit stays up before it goes on to your kaiju by itself.
local AUTO_NEXT = 2 -- seconds to see the rolled kit before it moves on by itself
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
	local flood =
		frame(shade, { BackgroundColor3 = deep, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40 })
	new("UIGradient", {
		Rotation = 270,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.55, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, flood)
	tween(flood, 0.6, { BackgroundTransparency = 0 })
	-- The arena it leads to: the stands in rings of the element's colour round
	-- a lit floor, two spotlights crossing overhead, a few stars above.
	for i = 1, 18 do
		frame(shade, {
			Position = UDim2.fromScale(((i * 37) % 97) / 96, ((i * 23) % 41) / 100),
			Size = UDim2.fromOffset(if i % 4 == 0 then 2 else 1, if i % 4 == 0 then 2 else 1),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = if i % 4 == 0 then 0.5 else 0.72,
			ZIndex = 40,
		})
	end
	for _, side in { -1, 1 } do
		local beam = frame(shade, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5 + side * 0.34, -0.12),
			Size = UDim2.fromScale(0.07, 1.3),
			Rotation = side * 24,
			BackgroundColor3 = color:Lerp(C.Text, 0.6),
			BackgroundTransparency = 1,
			ZIndex = 40,
		})
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.88),
				NumberSequenceKeypoint.new(0.7, 0.97),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, beam)
		tween(beam, 0.8, { BackgroundTransparency = 0 })
	end
	local floor = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.04),
		Size = UDim2.fromScale(0.9, 0.34),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		ZIndex = 40,
	})
	UiKit.round(floor, 999)
	new("UIGradient", {
		Rotation = 270,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	}, floor)
	tween(floor, 0.8, { BackgroundTransparency = 0 })
	for i, spec in { { 1.5, 0.62, 0.8 }, { 1.18, 0.46, 0.72 }, { 0.9, 0.32, 0.6 } } do
		local stand = frame(shade, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1.04),
			Size = UDim2.fromScale(spec[1], spec[2]),
			BackgroundTransparency = 1,
			ZIndex = 40,
		})
		UiKit.round(stand, 999)
		local edge = stroke(stand, color, 1, 2)
		task.delay(0.15 * i, function()
			tween(edge, 0.6, { Transparency = spec[3] })
		end)
	end

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
			or {
				Id = "starter-" .. element .. index,
				Element = element,
				Tier = "Common",
				Size = 1,
				Clarity = 1,
				Cut = 1,
			}
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
			tween(
				card,
				0.35,
				{ Position = UDim2.fromOffset(x + 4, 84), BackgroundTransparency = 0 },
				Enum.EasingStyle.Back
			)
		end)

		-- Header: the key, which slot it fires from, what it pays.
		local cap = keycap(card, spec.Key, spec.Color, 44)
		cap.Position = UDim2.fromOffset(16, 14)
		local slot = label(card, spec.Slot, 18, spec.Color, Enum.Font.GothamBlack)
		slot.Position, slot.Size, slot.ZIndex = UDim2.fromOffset(72, 16), UDim2.new(1, -84, 0, 22), 45
		local pays = label(card, "PAYS " .. spec.Pays, 11, C.Dim, Enum.Font.GothamBold)
		pays.Position, pays.Size, pays.ZIndex = UDim2.fromOffset(72, 40), UDim2.new(1, -84, 0, 14), 45

		-- The reel's window: a clipped frame with rounded corners (3D gem
		-- views don't draw inside a CanvasGroup). The gems are narrower than
		-- the window, so they never reach its corners.
		local well = frame(card, {
			Name = "ReelWindow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 74 + WELL / 2),
			Size = UDim2.fromOffset(WELL, WELL),
			BackgroundColor3 = C.Ink,
			ClipsDescendants = true,
			ZIndex = 44,
		})
		UiKit.round(well, WINDOW_ROUND)
		local wellEdge = stroke(well, spec.Color, 0.6, 2)
		local back = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 44 })
		UiKit.round(back, WINDOW_ROUND)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(C.Ink, 0.6), C.Ink),
		}, back)
		-- The strip runs downward and stops with cell 2, your gem, in the
		-- middle of the circle. (Cell 0 sits above it for the spring-back.)
		local count = 20 + index * 7
		local strip =
			frame(well, { BackgroundTransparency = 1, Size = UDim2.fromOffset(WELL, CELL * count), ZIndex = 45 })
		local symbols, cells, record, shadeNames = {}, {}, nil, {}
		for n = 0, count do
			local cell = frame(strip, {
				Name = "ReelCell",
				Position = UDim2.fromOffset(0, (n - 1) * CELL),
				Size = UDim2.fromOffset(WELL, CELL),
				BackgroundTransparency = 1,
				ZIndex = 45,
			})
			cells[n] = cell
			if n == 2 then
				-- Yours (the server's roll): the reel stops on it.
				rarityGlow(cell, gem.Tier or "Common")
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
				-- Gems of every rarity roll past at their real odds, each in its
				-- own shade of the element.
				local tier = GemRoller.rollRarity(rng)
				local look = shadeOf(element, tier)
				rarityGlow(cell, tier)
				symbols[n] = tier
				shadeNames[n] = look and look.Name
			end
		end
		local function stripY(n)
			return WELL / 2 - CELL / 2 - (n - 1) * CELL
		end
		strip.Position = UDim2.fromOffset(0, stripY(count))
		-- Depth: the window darkens toward its top and bottom.
		local depth = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 47 })
		UiKit.round(depth, WINDOW_ROUND)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.25, 1),
				NumberSequenceKeypoint.new(0.75, 1),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}, depth)
		local flash = frame(well, {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 48,
		})
		UiKit.round(flash, WINDOW_ROUND)

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
		local art = frame(badge, {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = C.Ink,
			ZIndex = 50,
		})
		UiKit.round(art, 9)
		if not Icons.apply(art, move) then
			local word = label(
				art,
				string.upper(string.sub(move and move.Name or id, 1, 2)),
				26,
				spec.Color,
				Enum.Font.GothamBlack
			)
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
		about.TextXAlignment, about.TextYAlignment, about.ZIndex =
			Enum.TextXAlignment.Center, Enum.TextYAlignment.Top, 45
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
			Cells = cells,
			Shown = {}, -- cell -> { View, Model, Tier }: the 3D gems in the window
			Free = {}, -- rarity -> gem models not in use
			Views = {}, -- 3D views not in use
			WellEdge = wellEdge,
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
			-- Only the gem stays in the window, and its rarity lights the edge.
			for n, cell in cells do
				cell.Visible = n == 2
			end
			wellEdge.Color = GemConfig.TierColors[gem.Tier or "Common"] or spec.Color
			flash.BackgroundTransparency = 0
			tween(flash, 0.4, { BackgroundTransparency = 1 })
			punch.Scale = 1.07
			tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			wellEdge.Transparency = 0
			caption.Text, caption.TextColor3 =
				elementName .. " " .. spec.Gem .. "  ·  " .. string.upper(gem.Tier or "Common"), color
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
			stats.Text = if move
				then string.format("%d %s   ·   %dS COOLDOWN", move.Cost or 0, spec.Pays, move.Cooldown or 0)
				else ""
			about.Text = move and move.Description or ""
			edge.Color, edge.Transparency, edge.Thickness = spec.Color, 0.1, 2
			effects[index].Live = true
		end
		cards[index] = entry
	end

	-- Once every gem has given up its surge: what's next, and a bar filling
	-- under it till your kaiju roll. It isn't a button: the intro's one
	-- button is START, on the kaiju roll (KaijuRoll).
	local nextUp = label(board, "NEXT  ·  YOUR KAIJU", 15, C.Gold, Enum.Font.GothamBlack)
	nextUp.Name, nextUp.TextXAlignment, nextUp.ZIndex = "NextUp", Enum.TextXAlignment.Center, 44
	nextUp.Position, nextUp.Size, nextUp.Visible = UDim2.fromOffset(0, 540), UDim2.new(1, 0, 0, 20), false
	local track = frame(nextUp, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(220, 4),
		BackgroundColor3 = C.Line,
		ZIndex = 44,
	})
	UiKit.round(track, 2)

	-- The 3D gems in a reel's window (cells middle-1 to middle+1): each takes a
	-- free model of its rarity (built the first time one's short) and a free
	-- view; the ones that have left give theirs back.
	local reelGrades = { Size = 6, Clarity = 6, Cut = 6 }
	local function reelModel(entry, tier)
		local free = entry.Free[tier]
		if free and #free > 0 then
			return table.remove(free)
		end
		local model, radius = GemArt.model({
			Id = "starter-reel-" .. element .. "-" .. tier,
			Element = element,
			Tier = tier,
			Size = reelGrades.Size,
			Clarity = reelGrades.Clarity,
			Cut = reelGrades.Cut,
		}, false)
		entry.Radius = entry.Radius or radius
		return model
	end
	function reelWindow(entry, middle, t)
		for n, shown in entry.Shown do
			if n < middle - 1 or n > middle + 1 then
				shown.Model.Parent = nil
				entry.Free[shown.Tier] = entry.Free[shown.Tier] or {}
				table.insert(entry.Free[shown.Tier], shown.Model)
				shown.View.Parent = nil
				table.insert(entry.Views, shown.View)
				entry.Shown[n] = nil
			end
		end
		for n = middle - 1, middle + 1 do
			local tier, cell = entry.Symbols[n], entry.Cells[n]
			if n ~= 2 and cell and GemConfig.TierColors[tier] and not entry.Shown[n] then
				local model = reelModel(entry, tier)
				local view = table.remove(entry.Views)
				if not view then
					view = new("ViewportFrame", {
						Name = "ReelGem",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(CELL, CELL),
						BackgroundTransparency = 1,
						ZIndex = 46,
					})
					GemArt.setupViewport(view, GemArt.cardDistance(entry.Radius or 1))
				end
				model.Parent, view.Parent = view, cell
				entry.Shown[n] = { View = view, Model = model, Tier = tier }
			end
		end
		for n, shown in entry.Shown do
			shown.Model:PivotTo(GemArt.pose(reelGrades, t * 1.6 + n * 0.9))
		end
	end

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
				if tierColor and middle ~= entry.Middle then
					entry.Middle = middle
					local tierName = string.upper(GemConfig.TierLabels[showing] or showing)
					entry.Caption.Text = if shadeName
						then string.upper(shadeName) .. "  ·  " .. tierName
						else tierName .. "  ·  " .. entry.GemWord
					entry.Caption.TextColor3 = tierColor
					entry.WellEdge.Color = tierColor
				end
				-- The gems in the window are 3D, and turn as they pass.
				reelWindow(entry, middle, t)
			end
			Art.pose(entry.Record, t, false)
		end
		for _, effect in effects do
			if effect.Live then
				CardFX.update(effect, element, t)
			end
		end
	end)

	-- On to your kaiju: on its own a few seconds after the last gem, or at
	-- once on a click.
	local done = false
	local function proceed()
		if done then
			return
		end
		done = true
		live:Disconnect()
		shade:Destroy()
		after()
	end
	local fill = frame(track, {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Gold,
		ZIndex = 45,
	})
	UiKit.round(fill, 2)

	local finished, outAt = false, 0
	local function allOut()
		if finished then
			return
		end
		finished, outAt = true, os.clock()
		title.Text = "YOUR KIT IS LOCKED IN"
		LotterySound.play("Attune")
		nextUp.Visible = true
		tween(fill, AUTO_NEXT, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		task.delay(AUTO_NEXT, function()
			if shade.Parent then
				proceed()
			end
		end)
	end
	-- All three spin; Q stops first, then E, then R, each on its gem, which
	-- cracks and lets its surge out.
	for index, entry in cards do
		local spin = 1.2 + (index - 1) * 0.7
		task.delay(0.4, function()
			if shade.Parent and entry.Phase == "Sealed" then
				entry.Spinning = true
				-- Runs just past the gem, then springs back onto it.
				tween(
					entry.Strip,
					spin,
					{ Position = UDim2.fromOffset(0, entry.Final + math.floor(CELL * 0.25)) },
					Enum.EasingStyle.Quart
				)
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
	-- Click during the roll: every gem cracks at once. Once they're out, a
	-- click goes straight on to your kaiju (not the same double-click).
	listen(shade.Activated, function()
		if finished then
			if os.clock() - outAt > 0.6 then
				proceed()
			end
			return
		end
		for _, entry in cards do
			entry.surge(true)
		end
		LotterySound.play("Lock")
		allOut()
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
-- What the primary action does on each page. A tapped style or element
-- card calls it itself (pickAdvance): the picks have no CONTINUE button.
local function advance()
	if busy or spin or closed then
		return
	end
	if phase == "Welcome" and pickStep == "Style" then
		setPickStep("Element")
		-- The onboarding funnel's style step (Systems/Funnel).
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local funnel = remotes and remotes:FindFirstChild("Funnel")
		if funnel then
			funnel:FireServer("Style")
		end
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
			pickRetry = true
			primary.Visible = true
			primary.Text = "RETRY THE LAUNCH"
			UiKit.toast(result.Message)
			return
		end
		pickRetry = false
		-- No lottery: you chose the kit, so it's claimed straight away and
		-- you're in.
		reward = result.Lottery
		primary.Text = "BEGIN MY SAGA" -- (what a failed claim falls back to)
		if reward and reward.Element then
			busy = true
			revealMoves(reward, function()
				-- Then your kaiju: the starter roll (KaijuRoll), and on.
				KaijuRoll.play(function()
					busy = false
					finish()
				end)
			end)
		else
			finish()
		end
	elseif phase == "Armor" then
		animate(reward.Gems, true)
	else
		finish()
	end
end
listen(primary.Activated, advance)
pickAdvance = function(step: string)
	pickToken += 1
	local token = pickToken
	task.delay(0.45, function()
		-- (Still on that page, nothing else tapped since.)
		if token == pickToken and phase == "Welcome" and pickStep == step and not busy then
			advance()
		end
	end)
end
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
	if not primary.Active then
		return
	end
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
