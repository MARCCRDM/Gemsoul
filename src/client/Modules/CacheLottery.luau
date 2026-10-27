--[[
	CacheLottery: an Arena Cache's roll, as a grid where every piece rolls at
	once. Each card has its own round reel (the mining find's display, see
	MiningReveal, made small). They all spin together, slow as their turn
	comes, and land one by one, the free gems first, then the gear:
	  - a gem's reel rolls through gems of every rarity, like a real find,
	    and lands on yours;
	  - a piece of gear's reel rolls through the cache's own armor and
	    weapons (3D, from the server's previews) and lands on it.
	The card (StreakRewards) shows what rolls past and fills in the stats on
	landing. Every outcome is the server's; nothing here picks or rerolls.

	  CacheLottery.window(frame) -> window     a round reel filling `frame`
	  CacheLottery.gemView(gem), CacheLottery.gearView(entry, tag)
	                                           a piece's own picture (static)
	  CacheLottery.new(cache, { Ready })       a roll for a cache:
	    lot.add(window, entry, { Center = fn(option), Land = fn(own) })
	    lot.run(live, skipped)                 yields until all have landed
	    lot.destroy()
	  CacheLottery.gearLines(item) -> stats, passive?, affixes
	  CacheLottery.gearDetails(item) -> { { Text, Color, Kind } }
	                                         everything it carries, spelled out
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local ArmorSignatures = require(ReplicatedStorage.Shared.ArmorSignatures)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearArt = require(script.Parent.GearArt)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local LotterySound = require(script.Parent.LotterySound)
local UiKit = require(script.Parent.UiKit)

local CacheLottery = {}
local new = IronUi.new
local INK = Color3.fromRGB(9, 17, 27)
local WHITE = Color3.fromRGB(241, 249, 255)
local DIM = Color3.fromRGB(155, 177, 199)
local GOLD = Color3.fromRGB(255, 206, 92)
local FIRST_LAND = 1.5 -- (s: when the first reel lands)
local STAGGER = 0.4 -- (s: between landings)
local SPEED = 9 -- (cells a second the reels average)

local function tween(object, duration, goal, style)
	TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), goal):Play()
end

-- A piece of gear's lines: its stat rolls, its passive and how many affixes
-- it carries (as the Market shows them).
function CacheLottery.gearLines(item)
	local roll = item.Roll
	local stats = {}
	for _, stat in { "Health", "Power", "Defense", "Speed" } do
		if roll and roll.Stats and roll.Stats[stat] then
			table.insert(stats, "+" .. roll.Stats[stat] .. " " .. stat)
		end
	end
	local passive, affixes = nil, 0
	local def = Slots.Definitions[item.Slot]
	local profile = GemClient.Profile
	local class = profile and profile.Character and profile.Character.Class or "Warrior"
	local ok, gear = pcall(Classes.gear, class, def and def.Kind, item.Id)
	if ok and gear and gear.Passive and gear.Passive.Name and gear.Passive.Name ~= "" then
		passive = gear.Passive.Name
	end
	for _ in roll and roll.Affixes or {} do
		affixes += 1
	end
	return table.concat(stats, "  ·  "), passive, affixes
end

-- Everything a piece of gear carries, a line each, as the inventory spells
-- it out: every stat it rolled; an armor piece's set (its family, and what
-- two or more of it worn give you: the old "Armor Identity" line only said
-- "wear matching pieces"), or a weapon's perk; its signature; each
-- elemental affix with its bonus, in its element's colour.
local STAT_ORDER = { "Health", "Power", "Defense", "Speed", "Critical", "Cooldown" }
local PERCENT = {
	Critical = true,
	Cooldown = true,
	DamageReduction = true,
	HealingReceived = true,
	ThreatGeneration = true,
	DamageAfterDodge = true,
}
local function amount(stat: string, value: number): string
	local shown = if PERCENT[stat] then value * 100 else value
	return string.format("+%g%s %s", math.floor(shown * 100 + 0.5) / 100, if PERCENT[stat] then "%" else "", stat)
end
function CacheLottery.gearDetails(item)
	local roll = item.Roll
	local lines = {}
	local stats = {}
	for _, stat in STAT_ORDER do
		local value = roll and roll.Stats and roll.Stats[stat]
		if value and value ~= 0 then
			table.insert(stats, amount(stat, value))
		end
	end
	table.insert(lines, {
		Text = if #stats > 0 then table.concat(stats, "  ·  ") else "Base stats",
		Color = Color3.fromRGB(120, 230, 150),
		Kind = "Stats",
	})
	local armor = ArmorFamilies.ById[item.Id]
	if armor and armor.ArmorFamily then
		local family = armor.ArmorFamily
		local two = (ArmorFamilies.Sets[family] or {})[2] or {}
		local bonus = {}
		for _, stat in STAT_ORDER do
			if two[stat] then
				table.insert(bonus, amount(stat, two[stat]))
			end
		end
		local moves = string.gsub(ArmorFamilies.EnhancementText[family] or "", "^2%+ pieces: ", "")
		table.insert(lines, {
			Text = string.format(
				"◆ %s set: wear 2+ %s pieces for %s; %s More at 4 and 6.",
				family,
				family,
				table.concat(bonus, ", "),
				moves
			),
			Color = Color3.fromRGB(236, 222, 182),
			Kind = "Set",
		})
	else
		local def = Slots.Definitions[item.Slot]
		local profile = GemClient.Profile
		local class = profile and profile.Character and profile.Character.Class or "Warrior"
		local ok, gear = pcall(Classes.gear, class, def and def.Kind, item.Id)
		local passive = ok and gear and gear.Passive
		if passive and passive.Name and passive.Name ~= "" then
			table.insert(lines, {
				Text = "◆ " .. passive.Name .. (if passive.Text and passive.Text ~= "" then ": " .. passive.Text else ""),
				Color = GOLD,
				Kind = "Perk",
			})
		end
	end
	if roll and roll.Signature then
		local ok, name, text = pcall(ArmorSignatures.describe, roll, nil)
		if ok and name ~= "" then
			-- (◆, not ✦: Roblox's fonts draw ✦ as an empty box)
			table.insert(lines, { Text = "◆ " .. name .. ": " .. text, Color = GOLD, Kind = "Signature" })
		end
	end
	for _, affix in roll and roll.Affixes or {} do
		local def = GemConfig.AffixById[affix.Id]
		if def then
			table.insert(lines, {
				Text = GemConfig.affixText(affix.Id, affix.Bonus),
				Color = GemConfig.ElementColors[def.Element] or Color3.fromRGB(140, 200, 255),
				Kind = "Affix",
			})
		end
	end
	return lines
end

-- A gem in 3D, every facet.
function CacheLottery.gemView(gem, parent: Instance?): Instance
	local view = GemArt.viewport(parent or Instance.new("Folder"), gem, true)
	view.Ambient = Color3.fromRGB(235, 235, 245)
	view.LightColor = Color3.new(1, 1, 1)
	return view
end

-- A piece of gear in 3D: the server's preview of it ("Slot|A:<tag>",
-- ArenaStreaks.previews). While that isn't built, its drawn silhouette in
-- its rarity's colour, and `flat` is true.
function CacheLottery.gearView(entry, tag: string, parent: Instance?): (Instance, boolean)
	local view = new("ViewportFrame", {
		Name = "GearView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(205, 210, 225),
		LightColor = Color3.fromRGB(255, 240, 215),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, parent)
	local ok, drawn = pcall(GearArt.draw, view, entry.Item.Slot, "A:" .. tag, false)
	if ok and drawn then
		return view, false
	end
	view:Destroy()
	local holder =
		new("Frame", { Name = "GearShape", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local inner = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 36),
	}, holder)
	new("UIScale", { Scale = 1.7 }, inner)
	pcall(GearArt.icon, inner, entry.Item.Slot, {}, GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD)
	return holder, true
end

-- A copy of a picture for one reel (a viewport's camera comes with it).
local function copyOf(view: Instance): Instance
	local copy = view:Clone()
	if copy:IsA("ViewportFrame") then
		copy.CurrentCamera = copy:FindFirstChildOfClass("Camera")
	end
	return copy
end

-- A round reel window filling `frame` (square): a ring in the rarity's
-- colour, a pool of light, and three cells the pieces roll through,
-- downward, darker at the top and bottom.
function CacheLottery.window(frame: GuiObject)
	local d = if frame.Size.X.Offset > 0 then frame.Size.X.Offset else frame.AbsoluteSize.X
	local inner = d - 6
	local cellH = math.floor(inner * 0.74)
	local artSize = math.floor(inner * 0.7)
	local holder =
		new("Frame", { Name = "ReelWindow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, frame)
	local punch = new("UIScale", { Scale = 1 }, holder)
	local glow = new("Frame", {
		BackgroundColor3 = DIM,
		BackgroundTransparency = 0.88,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		ZIndex = 1,
	}, holder)
	UiKit.round(glow, d)
	local ring = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
	UiKit.round(ring, d)
	local ringEdge = new("UIStroke", { Color = DIM, Thickness = 2 }, ring)
	local well = new("CanvasGroup", {
		Name = "RollerWindow",
		BackgroundColor3 = Color3.fromRGB(14, 24, 36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(inner, inner),
		ClipsDescendants = true,
		ZIndex = 3,
	}, holder)
	UiKit.round(well, d)
	-- (The window's colour is its own layer: a gradient on the CanvasGroup
	-- would tint the piece.)
	local back = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, well)
	local backPaint = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(INK, INK) }, back)
	local spot = new("Frame", {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		ZIndex = 2,
	}, well)
	UiKit.round(spot, d)
	local slots = {}
	for i = 1, 3 do
		local cell = new("Frame", {
			Name = "ReelCell",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(inner, cellH),
			ZIndex = 3,
		}, well)
		local art = new("Frame", {
			Name = "Piece",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(artSize, artSize),
			ZIndex = 3,
		}, cell)
		slots[i] = { Frame = cell, Art = art }
	end
	local depth = new("Frame", { BackgroundColor3 = INK, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, well)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(0.78, 1),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
	}, depth)
	local flash = new(
		"Frame",
		{ BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 },
		well
	)

	local win = { Holder = holder }
	local sequence, own, target = {}, nil, 0
	-- Puts `view` in a cell, taking it from wherever it was.
	local function put(slot, view)
		if slot.View and slot.View ~= view and slot.View.Parent == slot.Art then
			slot.View.Parent = nil
		end
		slot.View = view
		if view then
			view.Parent = slot.Art
		end
	end
	local function place(slot, index, position)
		slot.Frame.Position = UDim2.new(0, 0, 0.5, -cellH / 2 + (position - index) * cellH)
	end

	-- The window's colours for a rarity (brighter once landed).
	function win.paint(tier: string, landed: boolean?)
		local color = GemConfig.TierColors[tier] or WHITE
		ringEdge.Color = color
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = if landed then 0.75 else 0.88
		backPaint.Color = ColorSequence.new(color:Lerp(INK, 0.55), color:Lerp(INK, 0.85))
		spot.BackgroundColor3 = color:Lerp(WHITE, 0.35)
		spot.BackgroundTransparency = if landed then 0.62 else 0.8
	end

	-- The strip: `options` ({ View, Tier, Name }, at least four) in a
	-- random order, `mine` at `stop`. A piece never shows twice within two
	-- cells of itself (each picture is one instance, moved between cells),
	-- nor next to the stop. `pick(avoid)` may choose an option instead.
	function win.load(options, mine, stop: number, rng, pick)
		own, target = mine, stop
		table.clear(sequence)
		for i = 0, stop + 2 do
			if i == stop then
				sequence[i] = mine
				continue
			end
			local avoid = { [sequence[i - 1] or false] = true, [sequence[i - 2] or false] = true }
			if math.abs(i - stop) <= 2 then
				avoid[mine] = true
			end
			local choice = pick and pick(avoid)
			if not choice or avoid[choice] then
				local allowed = {}
				for _, option in options do
					if not avoid[option] then
						table.insert(allowed, option)
					end
				end
				choice = allowed[rng:NextInteger(1, #allowed)]
			end
			sequence[i] = choice
		end
		for _, slot in slots do
			slot.Index = nil
		end
	end

	-- Rolls the strip to `position` (in cells); the option now in the
	-- middle when that changed.
	function win.render(position: number)
		local center = math.floor(position + 0.5)
		for index = center - 1, center + 1 do
			local slot = slots[index % #slots + 1]
			if slot.Index ~= index then
				slot.Index = index
				local option = sequence[index]
				put(slot, option and option.View)
			end
			place(slot, index, position)
		end
		if win.Center ~= center then
			win.Center = center
			return sequence[center]
		end
		return nil
	end

	-- One piece, still, in the middle (a cache opened again, or a piece
	-- whose 3D preview arrived after it landed). The old one goes.
	function win.still(view: Instance)
		for i, slot in slots do
			if slot.View and slot.View ~= view then
				slot.View:Destroy()
			end
			slot.View, slot.Index = nil, nil
			if i == 1 then
				put(slot, view)
				place(slot, 0, 0)
			end
		end
	end

	-- The landing: a flash in the window and a punch of the display, with a
	-- ring that spreads from it for the rarer pieces.
	function win.land(tier: string)
		local rank = GemConfig.TierRank[tier] or 3
		local color = GemConfig.TierColors[tier] or WHITE
		win.paint(tier, true)
		flash.BackgroundTransparency = if rank >= 4 then 0.15 else 0.35
		tween(flash, 0.45, { BackgroundTransparency = 1 })
		punch.Scale = if rank >= 4 then 1.18 else 1.1
		tween(punch, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		local burst = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			ZIndex = 6,
		}, holder)
		UiKit.round(burst, d * 2)
		local edge = new("UIStroke", { Color = color, Thickness = if rank >= 4 then 3 else 2 }, burst)
		tween(burst, 0.6, { Size = UDim2.fromScale(1.5, 1.5) })
		tween(edge, 0.6, { Transparency = 1 })
		task.delay(0.65, function()
			burst:Destroy()
		end)
	end

	win.paint("Common")
	return win
end

-- A roll of `cache`'s pieces. Templates (one picture per gem rarity and
-- per piece of gear) are built once and copied into each reel.
function CacheLottery.new(cache, options)
	options = options or {}
	local lot = {}
	local rng = Random.new()
	local folder = Instance.new("Folder")
	local reels = {}
	local gemTemplates = nil
	local gearTemplates = nil

	-- One gem of each rarity for a reel, each in any of the four elements
	-- (every element turns up at every rarity, as in real finds); each
	-- rarity's art in each element is built once and copied.
	local function gems()
		gemTemplates = gemTemplates or {}
		local list = {}
		for _, tier in GemConfig.TierOrder do
			local element = GemConfig.Elements[rng:NextInteger(1, #GemConfig.Elements)]
			local key = tier .. "/" .. element
			if not gemTemplates[key] then
				local shade = GemConfig.shade({ Element = element, Tier = tier })
				gemTemplates[key] = {
					View = CacheLottery.gemView({
						Id = "cache-preview-" .. key,
						Tier = tier,
						Element = element,
						Size = 6,
						Clarity = 7,
						Cut = 6,
					}, folder),
					Tier = tier,
					Name = shade and shade.Name or GemConfig.TierLabels[tier] or tier,
				}
			end
			table.insert(list, gemTemplates[key])
		end
		return list
	end
	-- (Built when the gear's turn comes, so the reels roll its 3D previews.)
	local function gear()
		if gearTemplates then
			return gearTemplates
		end
		gearTemplates = {}
		for _, entry in cache.Items or {} do
			if entry.Item.Kind == "Gear" then
				local view, flat = CacheLottery.gearView(entry, cache.Id .. "/" .. entry.OfferId, folder)
				local def = Slots.Definitions[entry.Item.Slot]
				table.insert(gearTemplates, {
					Key = entry.OfferId,
					View = view,
					Flat = flat,
					Tier = entry.Rarity or "Rare",
					Name = entry.Name or "",
					Label = def and def.Label or entry.Item.Slot or "Gear",
					Quality = entry.Item.Quality,
				})
			end
		end
		return gearTemplates
	end

	-- Copies of the templates for one reel (at least four, so the strip
	-- never has to repeat a picture close by); `mine` is its own piece.
	local function optionsFor(entry)
		local list, mine = {}, nil
		if entry.Item.Kind == "Gem" then
			for _, template in gems() do
				local option = table.clone(template)
				option.View = copyOf(template.View)
				option.Grades = {
					Size = rng:NextInteger(2, 9),
					Clarity = rng:NextInteger(2, 9),
					Cut = rng:NextInteger(2, 9),
				}
				table.insert(list, option)
			end
			mine = { View = CacheLottery.gemView(entry.Item.Gem), Tier = entry.Item.Gem.Tier, Name = entry.Name }
		else
			for _, template in gear() do
				local option = table.clone(template)
				option.View = copyOf(template.View)
				table.insert(list, option)
				if template.Key == entry.OfferId then
					mine = option
				end
			end
			if not mine then
				local view, flat = CacheLottery.gearView(entry, cache.Id .. "/" .. entry.OfferId)
				mine = { View = view, Flat = flat, Tier = entry.Rarity or "Rare", Name = entry.Name or "" }
			end
		end
		local count = #list
		while #list < 4 and count > 0 do
			local again = table.clone(list[(#list - 1) % count + 1])
			again.View = copyOf(again.View)
			table.insert(list, again)
		end
		return list, mine
	end

	-- A card's reel: its window, its piece, and its hooks (Center, as a
	-- piece rolls past; Land, once it's on its own).
	function lot.add(window, entry, hooks)
		table.insert(reels, { Win = window, Entry = entry, Hooks = hooks or {} })
	end

	local function begin(reel, startAt: number, landAt: number)
		local list, mine = optionsFor(reel.Entry)
		reel.Options, reel.Own = list, mine
		reel.StartAt, reel.LandAt = startAt, landAt
		reel.Target = math.max(8, math.floor((landAt - startAt) * SPEED) + 2)
		local pick = nil
		if reel.Entry.Item.Kind == "Gem" then
			-- (rarities rolled like real finds)
			local byTier = {}
			for _, option in list do
				byTier[option.Tier] = byTier[option.Tier] or option
			end
			pick = function()
				return byTier[GemRoller.rollRarity(rng)]
			end
		end
		reel.Win.load(list, mine, reel.Target, rng, pick)
		reel.Spinning = true
	end
	local function land(reel, quiet: boolean?)
		reel.Spinning, reel.Landed = false, true
		reel.Win.render(reel.Target)
		reel.Win.land(reel.Own.Tier)
		-- Only its own piece stays; the rest of its strip goes.
		for _, option in reel.Options do
			if option ~= reel.Own then
				option.View:Destroy()
			end
		end
		reel.Options = nil
		if not quiet then
			LotterySound.reveal(GemConfig.TierRank[reel.Own.Tier] or 3)
		end
		if reel.Hooks.Land then
			reel.Hooks.Land(reel.Own)
		end
	end

	-- Spins every reel at once and lands them in turn: the gems first (from
	-- FIRST_LAND, STAGGER apart), then the gear, which waits for its 3D
	-- previews (Ready(), 3 s at most from the start). skipped() lands them
	-- all at once. Returns when all have landed, or live() goes false.
	function lot.run(live: () -> boolean, skipped: () -> boolean)
		local started = os.clock()
		local gemReels, gearReels = {}, {}
		for _, reel in reels do
			table.insert(if reel.Entry.Item.Kind == "Gem" then gemReels else gearReels, reel)
		end
		local nextLand = FIRST_LAND
		for _, reel in gemReels do
			begin(reel, 0, nextLand)
			nextLand += STAGGER
		end
		local gearPlanned = #gearReels == 0
		local lastTick, landedCount = 0, 0
		while live() do
			local now = os.clock() - started
			local skip = skipped()
			if not gearPlanned and (skip or now >= 3 or not options.Ready or options.Ready()) then
				gearPlanned = true
				local at = math.max(now + FIRST_LAND, nextLand)
				for _, reel in gearReels do
					begin(reel, now, at)
					at += STAGGER
				end
			end
			local rolled, loudest = false, 0
			for _, reel in reels do
				if reel.Spinning then
					if skip or now >= reel.LandAt then
						land(reel, skip)
						landedCount += 1
						loudest = math.max(loudest, GemConfig.TierRank[reel.Own.Tier] or 3)
					else
						local p = math.clamp((now - reel.StartAt) / (reel.LandAt - reel.StartAt), 0, 1)
						local option = reel.Win.render(1 + (reel.Target - 1) * (1 - (1 - p) ^ 3))
						if option and reel.Hooks.Center then
							reel.Hooks.Center(option)
							rolled = true
						end
					end
				end
			end
			if skip and loudest > 0 then
				LotterySound.reveal(loudest) -- (one for the lot)
			end
			if rolled and now - lastTick >= 0.06 then
				lastTick = now
				LotterySound.tick(landedCount / math.max(1, #reels))
			end
			if landedCount >= #reels then
				return
			end
			RunService.RenderStepped:Wait()
		end
	end

	function lot.destroy()
		for _, reel in reels do
			for _, option in reel.Options or {} do
				option.View:Destroy()
			end
			if reel.Own and not reel.Landed then
				reel.Own.View:Destroy() -- (a roll cut short: its piece never landed)
			end
			reel.Options = nil
		end
		folder:Destroy()
	end

	return lot
end

return CacheLottery
