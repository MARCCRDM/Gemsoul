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
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Art = require(script.Parent.Modules.LotteryArt)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
local UiSound = require(script.Parent.Modules.UiSound)
while not GemClient.Profile do
	GemClient.Changed:Wait()
end
if GemClient.Profile.Intro and GemClient.Profile.Intro.Done then
	return
end
local new = IronUi.new
local C = {
	Ink = Color3.fromRGB(8, 12, 19),
	Panel = Color3.fromRGB(20, 27, 37),
	Edge = Color3.fromRGB(108, 89, 62),
	Text = Color3.fromRGB(241, 244, 250),
	Dim = Color3.fromRGB(144, 164, 187),
	Cyan = Color3.fromRGB(94, 206, 221),
	Gold = Color3.fromRGB(224, 177, 98),
}
local gui = UiKit.gui("Intro", 15)
-- Full bleed: the starfield runs under the Roblox top bar too.
gui.IgnoreGuiInset = true
local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 25, Color = ColorSequence.new(C.Ink, Color3.fromRGB(23, 25, 48)) }, back)
local function frame(parent, props)
	props.BorderSizePixel = 0
	return new("Frame", props, parent)
end
local function label(parent, value, size, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		Font = Enum.Font.GothamBold,
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
local function metalTrim(parent, gold)
	local inset =
		frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8) })
	UiKit.round(inset, 4)
	new("UIStroke", { Color = gold, Thickness = 1, Transparency = 0.72 }, inset)
	for _, x in { 0, 1 } do
		for _, y in { 0, 1 } do
			local stud = frame(parent, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(x, if x == 0 then 9 else -9, y, if y == 0 then 9 else -9),
				Size = UDim2.fromOffset(4, 4),
				Rotation = 45,
				BackgroundColor3 = gold,
			})
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(gold, Color3.fromRGB(58, 44, 31)) }, stud)
		end
	end
end
-- Bounded, quiet points of light; no imported imagery or fullscreen flashes.
for i = 1, 36 do
	local x = ((i * 43) % 101) / 100
	local y = ((i * 29) % 97) / 96
	frame(back, {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(if i % 4 == 0 then 3 else 1, if i % 4 == 0 then 3 else 1),
		BackgroundColor3 = C.Cyan,
		BackgroundTransparency = 0.65,
	})
end
local panel = frame(back, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 18),
	Size = UDim2.new(1, -32, 1, -84),
})
new("UISizeConstraint", { MaxSize = Vector2.new(1280, 920) }, panel)
local brand = label(panel, "S A G A  /  M I N E R S", 11, C.Cyan)
brand.Position, brand.Size = UDim2.fromOffset(0, 0), UDim2.new(0.7, 0, 0, 20)
local chapter = label(panel, "01 / 03", 11, C.Gold)
chapter.TextXAlignment = Enum.TextXAlignment.Right
chapter.Position, chapter.Size = UDim2.new(1, -100, 0, 0), UDim2.fromOffset(100, 20)
local title = label(panel, "YOUR LEGEND BEGINS", 36)
title.Position, title.Size = UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 44)
title.Font = Enum.Font.Garamond
local subtitle = label(panel, "A full loadout. Nine gemstones. A build that starts with you.", 13, C.Dim)
subtitle.Position, subtitle.Size = UDim2.fromOffset(0, 72), UDim2.new(1, 0, 0, 24)
local body = frame(panel, { BackgroundTransparency = 1 })
local hero = frame(body, { BackgroundColor3 = C.Panel, ClipsDescendants = true })
UiKit.round(hero, 6)
local heroStroke = new("UIStroke", { Color = C.Edge, Thickness = 2 }, hero)
new(
	"UIGradient",
	{ Rotation = 65, Color = ColorSequence.new(Color3.fromRGB(19, 43, 57), Color3.fromRGB(15, 20, 37)) },
	hero
)
metalTrim(hero, C.Gold)
local ring = frame(hero, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.76, 0.76),
	BackgroundTransparency = 1,
})
new("UIAspectRatioConstraint", { AspectRatio = 1 }, ring)
UiKit.round(ring, 999)
local ringStroke = new("UIStroke", { Color = C.Cyan, Thickness = 1, Transparency = 0.78 }, ring)
local inner = frame(ring, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.82, 0.82),
	BackgroundTransparency = 1,
})
UiKit.round(inner, 999)
new("UIStroke", { Color = C.Cyan, Thickness = 1, Transparency = 0.9 }, inner)
local orbitMarks = {}
for index = 1, 24 do
	local angle = index * math.pi / 12
	local mark = frame(ring, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.49, 0.5 + math.cos(angle) * 0.49),
		Size = UDim2.fromOffset(if index % 3 == 0 then 4 else 2, if index % 3 == 0 then 12 else 5),
		Rotation = -math.deg(angle),
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0.4,
	})
	table.insert(orbitMarks, mark)
end
local crest = frame(hero, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(172, 40),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.12,
	ZIndex = 6,
})
UiKit.round(crest, 3)
local crestStroke = new("UIStroke", { Color = C.Gold, Thickness = 1, Transparency = 0.25 }, crest)
local crestTitle = label(crest, "SEALED RELIQUARY", 12, C.Gold)
crestTitle.TextXAlignment = Enum.TextXAlignment.Center
crestTitle.Position, crestTitle.Size = UDim2.fromOffset(0, 3), UDim2.new(1, 0, 0, 21)
crestTitle.ZIndex = 7
local rarityPips = {}
for index = 1, 5 do
	local pip = frame(crest, {
		Position = UDim2.new(0.5, (index - 3) * 12 - 2, 0, 29),
		Size = UDim2.fromOffset(4, 4),
		Rotation = 45,
		BackgroundColor3 = C.Edge,
		ZIndex = 7,
	})
	table.insert(rarityPips, pip)
end
local heroKicker = label(hero, "YOUR LAUNCH CAPSULE", 10, C.Cyan)
heroKicker.Position, heroKicker.Size = UDim2.fromOffset(18, 14), UDim2.new(1, -214, 0, 18)
heroKicker.ZIndex = 5
local heroArt = frame(hero, { BackgroundTransparency = 1, ZIndex = 2 })
local heroName = label(hero, "A NEW WARRIOR AWAKENS", 24)
heroName.Font = Enum.Font.Garamond
heroName.ZIndex = 5
local heroMeta = label(hero, "6 EQUIPMENT PIECES  /  9 GEMSTONES", 11, C.Cyan)
heroMeta.ZIndex = 5
local scan =
	frame(hero, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Cyan, BackgroundTransparency = 0.8, ZIndex = 4 })
local rack = frame(body, { BackgroundTransparency = 1 })
local rackTitle = label(rack, "LAUNCH MANIFEST", 11, C.Dim)
rackTitle.Size = UDim2.new(0.75, 0, 0, 24)
local counter = label(rack, "00 / 06", 11, C.Cyan)
counter.TextXAlignment = Enum.TextXAlignment.Right
counter.Position, counter.Size = UDim2.fromScale(0.75, 0), UDim2.new(0.25, 0, 0, 24)
local stage = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 1, -34),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.Edge,
	CanvasSize = UDim2.new(),
}, rack)
local rail = frame(rack, {
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = C.Edge,
	BackgroundTransparency = 0.6,
})
local railFill = frame(rail, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold })
local grid =
	new("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, stage)
local footer = frame(panel, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 100),
})
local primary = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 0, 0, 50),
	Text = "IGNITE THE LOTTERY",
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextColor3 = C.Ink,
	BackgroundColor3 = C.Gold,
	AutoButtonColor = false,
}, footer)
UiKit.round(primary, 4)
metalTrim(primary, Color3.fromRGB(255, 233, 178))
new("UISizeConstraint", { MaxSize = Vector2.new(440, 50) }, primary)
new(
	"UIGradient",
	{ Rotation = 10, Color = ColorSequence.new(Color3.fromRGB(255, 221, 153), Color3.fromRGB(237, 165, 77)) },
	primary
)
local buttonStroke = new("UIStroke", {
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = Color3.fromRGB(255, 226, 172),
	Thickness = 1,
	Transparency = 0.2,
}, primary)
local skip = new("TextButton", {
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(0.68, 0, 0, 44),
	Text = "Skip reveal · keep all rewards",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.Dim,
	BackgroundTransparency = 1,
}, footer)
local motion = new("TextButton", {
	Position = UDim2.new(0.68, 0, 0, 56),
	Size = UDim2.new(0.32, 0, 0, 44),
	Text = "Motion: full",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = C.Dim,
	BackgroundTransparency = 1,
}, footer)
local cards, connections = {}, {}
local phase, reward, busy, spin, calm, closed = "Welcome", nil, false, nil, false, false
local heroRecord, heroStart = Art.show(heroArt, nil, nil, C.Cyan, true), os.clock()
local horizontal = false
local function listen(signal, fn)
	table.insert(connections, signal:Connect(fn))
end
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
	local header = if short then 70 elseif w < 650 then 84 else 108
	local bodyHeight = math.max(80, h - header - 112)
	title.TextSize = if w < 500 then 25 elseif short then 28 else 38
	title.Position, title.Size = UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, if short then 36 else 44)
	subtitle.Visible = not short
	subtitle.Position = UDim2.fromOffset(0, if w < 650 then 60 else 72)
	body.Position, body.Size = UDim2.fromOffset(0, header), UDim2.new(1, 0, 0, bodyHeight)
	local portrait = w < 650 and h > w
	horizontal = portrait or bodyHeight < 300
	if portrait then
		local heroHeight = math.max(100, bodyHeight - 136)
		hero.Position, hero.Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, heroHeight)
		rack.Position, rack.Size =
			UDim2.fromOffset(0, heroHeight + 10), UDim2.new(1, 0, 0, bodyHeight - heroHeight - 10)
	else
		hero.Position, hero.Size = UDim2.fromOffset(0, 0), UDim2.new(0.53, -8, 1, 0)
		rack.Position, rack.Size = UDim2.new(0.53, 10, 0, 0), UDim2.new(0.47, -10, 1, 0)
	end
	heroKicker.Visible = not portrait and not short
	crest.Visible = not portrait and not short
	heroArt.Position, heroArt.Size =
		UDim2.fromOffset(8, if portrait or short then 4 else 25),
		UDim2.new(1, -16, 1, if portrait or short then -57 else -86)
	heroName.Position, heroName.Size =
		UDim2.new(0, 18, 1, if portrait or short then -49 else -56), UDim2.new(1, -36, 0, 30)
	heroName.TextSize = if portrait or short then 21 else 30
	heroMeta.Position, heroMeta.Size = UDim2.new(0, 18, 1, -25), UDim2.new(1, -36, 0, 18)
	local rows = if phase == "Gems" then 3 else 2
	if horizontal then
		grid.FillDirection, grid.FillDirectionMaxCells = Enum.FillDirection.Vertical, 1
		grid.CellSize = UDim2.fromOffset(118, math.max(90, stage.AbsoluteSize.Y - 5))
		stage.AutomaticCanvasSize, stage.ScrollingDirection = Enum.AutomaticSize.X, Enum.ScrollingDirection.X
	else
		grid.FillDirection, grid.FillDirectionMaxCells = Enum.FillDirection.Horizontal, 3
		grid.CellSize = UDim2.new(1 / 3, -6, 0, math.max(112, (stage.AbsoluteSize.Y - (rows - 1) * 8) / rows))
		stage.AutomaticCanvasSize, stage.ScrollingDirection = Enum.AutomaticSize.Y, Enum.ScrollingDirection.Y
	end
end
local function describe(entry, isGem)
	if isGem then
		local gem = entry.Gem
		local detail = (GemConfig.ElementLabels[gem.Element] or gem.Element) .. " / CUT " .. gem.Cut
		-- A surge capacitor gem: name the ability it casts.
		local surge = SURGE_KEYS[entry.Slot] and Tech.surgeStats(gem)
		if surge then
			detail ..= string.format("  /  %s (%s)", surge.Name, Tech.TierNames[surge.Tier] or "")
		end
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
local function spotlight(card, celebrate)
	if not card.Stopped then
		return
	end
	local name, color, rarity, detail = describe(card.Entry, phase == "Gems")
	heroName.Text, heroMeta.Text = name, rarity:upper() .. "  /  " .. detail:upper()
	heroKicker.Text = slotName(card.Entry.Slot):upper()
	local rank = ({ Common = 1, Uncommon = 2, Rare = 3, ["Ultra Rare"] = 4, ["Ultra-Rare"] = 4, Legendary = 5 })[rarity]
		or 1
	crestTitle.Text, crestTitle.TextColor3, crestStroke.Color = rarity:upper(), color, color
	for index, pip in rarityPips do
		pip.BackgroundColor3 = if index <= rank then color else C.Edge
	end
	for _, mark in orbitMarks do
		mark.BackgroundColor3 = color
		mark.BackgroundTransparency = if rank >= 3 then 0.25 else 0.6
	end
	heroKicker.TextColor3, heroMeta.TextColor3 = color, color
	heroStroke.Color, ringStroke.Color = color, color
	heroRecord = Art.show(heroArt, if phase == "Gems" then card.Entry.Gem else nil, card.Entry.Slot, color, false)
	heroStart = os.clock()
	for _, other in cards do
		other.Stroke.Thickness = if other == card then 2 else 1
	end
	if celebrate then
		if not calm then
			heroRecord.Camera.FieldOfView = 44
			tween(heroRecord.Camera, 0.55, { FieldOfView = 34 }, Enum.EasingStyle.Back)
		end
		local major = card.Index == #cards
		burst(color, major, rank)
		UiSound.play(
			if major or rank >= 4
				then "Reward"
				elseif rank == 3 then "Enchant"
				elseif rank == 2 then "Confirm"
				else "Equip"
		)
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
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, stage)
		UiKit.round(cell, 4)
		metalTrim(cell, C.Edge)
		new(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(41, 51, 62), Color3.fromRGB(13, 19, 29)) },
			cell
		)
		local stroke = new(
			"UIStroke",
			{ ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.Edge, Transparency = 0.25, Thickness = 1 },
			cell
		)
		local slot = label(cell, slotName(entry.Slot):upper(), 10, C.Dim)
		slot.Position, slot.Size = UDim2.fromOffset(15, 5), UDim2.new(1, -30, 0, 18)
		local art = frame(
			cell,
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 1, -57) }
		)
		local reel = frame(art, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true })
		local tape = frame(reel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120) })
		local lines = {}
		for line = 1, 4 do
			local txt = label(
				tape,
				if phase == "Welcome" then "SEALED / " .. string.format("%02d", index) else "SCANNING…",
				11,
				if line == 2 then C.Cyan else C.Edge
			)
			txt.Position, txt.Size = UDim2.fromOffset(0, (line - 1) * 30), UDim2.new(1, 0, 0, 30)
			txt.TextXAlignment = Enum.TextXAlignment.Center
			table.insert(lines, txt)
		end
		frame(reel, {
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Cyan,
			BackgroundTransparency = 0.75,
		})
		local name = label(cell, "AWAITING RELEASE", 10, C.Dim)
		name.Position, name.Size = UDim2.new(0, 9, 1, -31), UDim2.new(1, -18, 0, 16)
		local band =
			frame(cell, { Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.Edge })
		local pip = label(cell, string.format("%02d", index), 9, C.Edge)
		pip.TextXAlignment = Enum.TextXAlignment.Right
		pip.Position, pip.Size = UDim2.new(1, -30, 1, -15), UDim2.fromOffset(20, 12)
		local card = {
			Frame = cell,
			Stroke = stroke,
			Art = art,
			Reel = reel,
			Tape = tape,
			Lines = lines,
			Name = name,
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
	card.Name.Text, card.Name.TextColor3 = rarity:upper(), color
	card.Band.BackgroundColor3, card.Stroke.Color = color, color
	card.Frame.BackgroundColor3 = C.Panel:Lerp(color, 0.1)
	card.Record = Art.show(card.Art, if phase == "Gems" then card.Entry.Gem else nil, card.Entry.Slot, color, false)
	card.Frame:SetAttribute("RewardName", name)
	spotlight(card, true)
	local position = card.Frame.AbsolutePosition - stage.AbsolutePosition + stage.CanvasPosition
	if horizontal then
		stage.CanvasPosition =
			Vector2.new(math.max(0, position.X - (stage.AbsoluteSize.X - card.Frame.AbsoluteSize.X) * 0.5), 0)
	else
		stage.CanvasPosition =
			Vector2.new(0, math.max(0, position.Y + card.Frame.AbsoluteSize.Y - stage.AbsoluteSize.Y))
	end
end
local function animate(entries, isGem)
	phase = if isGem then "Gems" else "Armor"
	createCards(entries)
	counter.Text = string.format("00 / %02d", #entries)
	railFill.Size = UDim2.fromScale(0, 1)
	crestTitle.Text = "BREAKING THE SEAL"
	crestTitle.TextColor3, crestStroke.Color = C.Gold, C.Gold
	for _, pip in rarityPips do
		pip.BackgroundColor3 = C.Edge
	end
	heroRecord = Art.show(heroArt, nil, nil, if isGem then C.Gold else C.Cyan, true)
	heroStart = os.clock()
	heroName.Text = if isGem then "CHARGING THE CORE" else "ASSEMBLING YOUR DESTINY"
	heroMeta.Text = "EVERY REEL IS LIVE"
	heroKicker.Text = if isGem then "GEMSTONE RESONANCE CHAMBER" else "EQUIPMENT RELEASE SEQUENCE"
	title.Text = if isGem then "POWER, UNEARTHED." else "YOUR LOADOUT. REVEALED."
	subtitle.Text = if isGem
		then "Nine gemstones. Every socket gets its spark."
		else "Boots first. Helmet last. Every piece is yours."
	chapter.Text = if isGem then "02 / 03" else "01 / 03"
	rackTitle.Text = if isGem then "GEMSTONE MANIFEST" else "EQUIPMENT MANIFEST"
	spin = { Start = os.clock(), NextSound = 0, Count = 0 }
	for index, card in cards do
		card.StopAt = (if isGem then 1.8 + index * 0.6 else 2 + index * 0.85) + (if index == #cards then 0.65 else 0)
	end
	primary.Text, primary.Active = "REVEAL IN PROGRESS…", false
	primary.BackgroundColor3 = Color3.fromRGB(166, 164, 158)
end
local function close()
	if closed then
		return
	end
	closed = true
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
	primary.Text = "ATTUNING YOUR LOADOUT…"
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
	UiSound.play("Reward")
	UiKit.toast("Your journey begins. All nine gem sockets are ready.", C.Cyan)
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
		ring.Rotation = (now * 5) % 360
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
		card.Tape.Position = UDim2.new(0, 0, 0, if calm then 0 else -card.Shift * 30)
		if elapsed >= card.NextTick then
			card.NextTick = elapsed + interval
			for _, line in card.Lines do
				if phase == "Gems" then
					local element = GemConfig.Elements[math.random(1, #GemConfig.Elements)]
					line.Text = (GemConfig.ElementLabels[element] or element):upper()
					line.TextColor3 = GemConfig.ElementColors[element]:Lerp(C.Dim, 0.3)
				else
					local catalog =
						Classes.get(GemClient.Profile.Character.Class)[Slots.Definitions[card.Entry.Slot].Kind]
					line.Text = catalog[math.random(1, #catalog)].Name:upper()
					line.TextColor3 = if card == nextCard then C.Cyan else C.Dim
				end
			end
		end
		card.Stroke.Color = if card == nextCard then C.Cyan else C.Edge
		card.Stroke.Transparency = if card == nextCard then 0.1 else 0.5
		card.Name.Text = if card == nextCard
			then (if remaining < 0.9 then "LOCKING IN…" else "NEXT TO REVEAL")
			else "ROLLING"
		if remaining <= 0 then
			card.Stopped = true
			spin.Count += 1
			showCard(card)
			counter.Text = string.format("%02d / %02d", spin.Count, #cards)
			tween(railFill, 0.28, { Size = UDim2.fromScale(spin.Count / #cards, 1) })
		end
	end
	if nextCard and elapsed >= spin.NextSound then
		spin.NextSound = elapsed + (if nextCard.StopAt - elapsed < 1 then 0.24 else 0.11)
		UiSound.play("Hover")
	end
	if spin.Count == #cards then
		spin = nil
		primary.Active = true
		primary.BackgroundColor3 = C.Gold
		primary.Text = if phase == "Armor" then "UNEARTH MY NINE GEMSTONES" else "ATTUNE & BEGIN YOUR SAGA"
		title.Text = if phase == "Armor" then "BUILT FOR YOUR JOURNEY." else "YOUR SAGA STARTS NOW."
		subtitle.Text = if phase == "Armor"
			then "Inspect any piece. Your gemstones are next."
			else "Six enchanted sockets. Three Gem Surges ready on Q · E · R."
		if phase == "Gems" then
			chapter.Text = "03 / 03"
		end
		heroKicker.Text = "COLLECTION COMPLETE  /  SELECT ANY REWARD"
	end
end)
listen(primary.Activated, function()
	if busy or spin or closed then
		return
	end
	if phase == "Welcome" then
		busy = true
		primary.Text = "OPENING YOUR CAPSULE…"
		local result = GemClient.request("PrepareStarterLottery")
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
	end
end)
listen(primary.MouseLeave, function()
	tween(buttonStroke, 0.15, { Thickness = 1, Transparency = 0.2 })
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
