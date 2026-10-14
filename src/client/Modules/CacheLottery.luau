--[[
	CacheLottery: an Arena Cache's roll, played like the mining find
	(MiningReveal): one round display rolls a reel and lands on each piece in
	turn, with its rarity, name and stats beside it.
	  - The free gems come first. The reel rolls through gems (every rarity,
	    like a real find) and lands on yours. Size, Clarity and Cut fill in
	    as bars, with the gem's worth.
	  - Then the gear, one piece at a time. The reel rolls through the
	    cache's own armor and weapons (3D, from the server's previews) and
	    lands on the piece. Its quality fills in as a bar, then its stat
	    rolls, passive and affixes, and what it sells for on the Market.
	A strip along the bottom fills as pieces land. REVEAL lands the piece now,
	NEXT moves on (pieces also move on by themselves), and SKIP ALL ends the
	roll. Every outcome is the server's; nothing here picks or rerolls.

	  CacheLottery.play(parent, cache, options)   yields until it's done
	    options.Ready() -> boolean   the gear's 3D previews exist
	                                 (it waits 3 s at most for them)
	  CacheLottery.gearLines(item) -> stats, passive?, affixes
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
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
local GREEN = Color3.fromRGB(120, 230, 150)
local BLUE = Color3.fromRGB(140, 200, 255)
local OFF = Color3.fromRGB(32, 45, 60) -- (an unlit bar segment)
local WIDTH, HEIGHT = 660, 396
local WELL, CELL = 196, 150 -- the round display, and one piece on its reel
local CX, CY = 152, 166 -- the display's centre on the card
local INFO = 300 -- where the right-hand column starts
local STRIP = 344 -- the strip of pieces along the bottom
local SEGMENTS = 10
local QUALITY = 4 -- (gear quality runs 1 to 4)
local TARGET = 23 -- the reel cell each roll stops on

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

local function tween(object, duration, goal, style)
	local t = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

local function label(parent, value, x, y, w, h, size, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = color or WHITE,
		Font = IronUi.Bold,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 5,
	}, parent)
end

local function panel(parent, name, x, y, w, h, color, z)
	return new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		ZIndex = z or 2,
	}, parent)
end

local function button(parent, name, text, x, y, w, h)
	local b = new("TextButton", {
		Name = name,
		Text = text,
		Font = IronUi.Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		BackgroundColor3 = Color3.fromRGB(36, 52, 69),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 8,
	}, parent)
	UiKit.round(b, 8)
	return b, new("UIStroke", { Color = DIM, Thickness = 1.5, Transparency = 0.3 }, b)
end

-- 1161 -> "1,161"
local function commas(n: number): string
	local text = tostring(math.floor(n + 0.5))
	while true do
		local swapped, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = swapped
		if count == 0 then
			return text
		end
	end
end

local function burst(parent, rank, color)
	-- One bounded burst; high rarity adds a second expanding ring.
	for i = 1, 4 + rank * 4 do
		local a = i * math.pi * 2 / (4 + rank * 4)
		local spark = panel(parent, "RaritySpark", CX, CY, 3 + rank, 3 + rank, if i % 3 == 0 then WHITE else color, 7)
		spark.Rotation = 45
		tween(spark, 0.75 + rank * 0.06, {
			Position = UDim2.fromOffset(CX + math.cos(a) * (118 + rank * 12), CY + math.sin(a) * (118 + rank * 12)),
			BackgroundTransparency = 1,
			Rotation = 135,
		})
	end
	for i = 1, if rank >= 4 then 2 else 1 do
		local ring = panel(parent, "RarityRing", CX, CY, 32, 32, color, 6)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		UiKit.round(ring, 200)
		local edge = new("UIStroke", { Color = color, Thickness = if rank >= 4 then 2 else 1 }, ring)
		tween(ring, 0.7 + i * 0.16, { Size = UDim2.fromOffset(WELL + 30 + i * 40, WELL + 30 + i * 40) })
		tween(edge, 0.7 + i * 0.16, { Transparency = 1 })
	end
	for i = 1, rank * 3 do
		local ray = panel(parent, "RarityRay", CX, CY, 3, WELL / 2 + 24 + rank * 8, color, 3)
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Rotation = i * 360 / (rank * 3)
		ray.BackgroundTransparency = 0.5
		tween(ray, 1.3, { BackgroundTransparency = 1 })
	end
end

-- The cache's gear as reel pictures: the 3D preview of each piece, or its
-- drawn silhouette in its rarity's colour while the preview isn't there.
local function gearTemplate(folder, entry, tag: string)
	local view = new("ViewportFrame", {
		Name = "GearView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(205, 210, 225),
		LightColor = Color3.fromRGB(255, 240, 215),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, folder)
	local ok, drawn = pcall(GearArt.draw, view, entry.Item.Slot, "A:" .. tag, false)
	if ok and drawn then
		return view
	end
	view:Destroy()
	local holder =
		new("Frame", { Name = "GearShape", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, folder)
	local inner = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 36),
	}, holder)
	new("UIScale", { Scale = 2.6 }, inner)
	pcall(GearArt.icon, inner, entry.Item.Slot, {}, GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD)
	return holder
end

function CacheLottery.play(parent: GuiObject, cache, options)
	options = options or {}
	-- The free gems first, then the gear, in the cache's order.
	local entries = {}
	for _, entry in cache.Items or {} do
		if entry.Free and entry.Item.Kind == "Gem" then
			table.insert(entries, entry)
		end
	end
	local gemCount = #entries
	for _, entry in cache.Items or {} do
		if not entry.Free and entry.Item.Kind == "Gear" then
			table.insert(entries, entry)
		end
	end
	local gearCount = #entries - gemCount
	if #entries == 0 then
		return
	end
	local opened = os.clock()
	local rng = Random.new()

	local anchor = panel(parent, "CacheLottery", 0, 0, WIDTH, HEIGHT, INK, 2)
	anchor.BackgroundTransparency = 1
	anchor.AnchorPoint, anchor.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	local fit = new("UIScale", {}, anchor)
	local function resize()
		local size = parent.AbsoluteSize
		if size.X > 0 then
			fit.Scale = math.max(0.1, math.min(1, (size.X - 24) / WIDTH, (size.Y - 32) / HEIGHT))
		end
	end
	local resizeConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local function live()
		return anchor.Parent ~= nil
	end
	local card = new("CanvasGroup", {
		Name = "CacheRoller",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		GroupTransparency = 0,
		Active = true,
		ClipsDescendants = true,
	}, anchor)
	UiKit.round(card, 18)
	-- (The rarity lighting is its own layer: a gradient on the CanvasGroup
	-- would tint every piece and label.)
	local backdrop = panel(card, "RarityBackdrop", 0, 0, WIDTH, HEIGHT, WHITE, 1)
	local paint = new("UIGradient", { Color = ColorSequence.new(INK, INK), Offset = Vector2.new(-0.25, 0) }, backdrop)
	local edge = new("UIStroke", { Color = DIM, Thickness = 2, Transparency = 0.2 }, card)
	local accent = panel(card, "RarityAccent", 0, 0, WIDTH, 3, DIM)
	local divider = panel(card, "ColumnRule", INFO - 22, 28, 1, STRIP - 48, DIM)
	divider.BackgroundTransparency = 0.8
	local kicker = label(
		card,
		string.format("%sARENA CACHE  ·  %d WINS", if cache.Dev then "DEV TEST  ·  " else "", cache.Wins or 0),
		24,
		18,
		240,
		16,
		11,
		GOLD
	)
	kicker.TextTruncate = Enum.TextTruncate.AtEnd

	-- The display: a soft glow, a ring of light that sweeps round it while
	-- it rolls, and the round window the pieces roll through.
	local glow = panel(card, "DisplayGlow", CX, CY, WELL + 64, WELL + 64, DIM, 2)
	glow.AnchorPoint, glow.BackgroundTransparency = Vector2.new(0.5, 0.5), 0.9
	UiKit.round(glow, 400)
	local halo = panel(card, "DisplayHalo", CX, CY, WELL + 26, WELL + 26, INK, 3)
	halo.AnchorPoint, halo.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
	UiKit.round(halo, 400)
	local haloEdge = new("UIStroke", { Color = WHITE, Thickness = 3 }, halo)
	local sweep = new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.85),
			NumberSequenceKeypoint.new(0.65, 0.85),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, haloEdge)
	local holder = panel(card, "DisplayHolder", CX, CY, WELL, WELL, INK, 4)
	holder.AnchorPoint, holder.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
	local punch = new("UIScale", { Scale = 1 }, holder)
	local well = new("CanvasGroup", {
		Name = "RollerWindow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(14, 24, 36),
		ClipsDescendants = true,
		ZIndex = 4,
	}, holder)
	UiKit.round(well, WELL)
	local wellEdge = new("UIStroke", { Color = DIM, Thickness = 2 }, well)
	local wellBack = panel(well, "WindowColour", 0, 0, WELL, WELL, WHITE, 4)
	local wellPaint = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(INK, INK) }, wellBack)
	-- A pool of light behind the piece, in its rarity colour.
	local spot = panel(well, "Spotlight", WELL / 2, WELL / 2, 156, 156, WHITE, 4)
	spot.AnchorPoint, spot.BackgroundTransparency = Vector2.new(0.5, 0.5), 0.78
	UiKit.round(spot, 200)
	local core = panel(well, "SpotCore", WELL / 2, WELL / 2, 92, 92, WHITE, 4)
	core.AnchorPoint, core.BackgroundTransparency = Vector2.new(0.5, 0.5), 0.8
	UiKit.round(core, 200)
	local slots = {}
	for i = 1, 5 do
		local cell = panel(well, "ReelCell", 0, 0, WELL, CELL, INK, 5)
		cell.BackgroundTransparency = 1
		local art = panel(cell, "Piece", (WELL - 140) / 2, (CELL - 132) / 2, 140, 132, INK, 5)
		art.BackgroundTransparency = 1
		slots[i] = { Frame = cell, Art = art }
	end
	-- Depth: the window darkens toward its top and bottom, so pieces roll in
	-- and out of the light.
	local depth = panel(well, "Depth", 0, 0, WELL, WELL, INK, 6)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.16, 1),
			NumberSequenceKeypoint.new(0.84, 1),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
	}, depth)
	local flash = panel(well, "LandFlash", 0, 0, WELL, WELL, WHITE, 7)
	flash.BackgroundTransparency = 1
	-- The rarity under the display, changing as each piece rolls past.
	local pill = panel(card, "TierPill", CX - 70, CY + WELL / 2 + 18, 140, 26, INK, 5)
	UiKit.round(pill, 13)
	local pillEdge = new("UIStroke", { Color = DIM, Thickness = 1.5 }, pill)
	local pillText = label(pill, "", 0, 0, 140, 26, 12, DIM)
	pillText.TextXAlignment = Enum.TextXAlignment.Center

	-- The right-hand column.
	local heading = label(card, "", INFO, 22, 200, 18, 13, DIM)
	local action, actionEdge = button(card, "RevealOrNext", "REVEAL  ›", WIDTH - 24 - 126, 16, 126, 36)
	local skip, advance, skipAll, landed = false, false, false, false
	action.Activated:Connect(function()
		if landed then
			advance = true
		else
			skip = true
		end
	end)
	local status = label(card, "", INFO, 52, 336, 40, 34, DIM)
	local detail = label(card, "", INFO, 94, 336, 24, 19)
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	local dot = panel(card, "KindDot", INFO, 128, 10, 10, DIM, 5)
	UiKit.round(dot, 5)
	dot.BackgroundTransparency = 1
	local kind = label(card, "", INFO + 16, 123, 300, 20, 13, DIM)
	-- Bars: a gem's Size, Clarity and Cut (ten segments each); a piece of
	-- gear's quality (four).
	local function bar(name, y, count, width)
		local caption = label(card, name, INFO, y, 70, 16, 11, DIM)
		local segments = {}
		for i = 1, count do
			local segment = panel(card, "StatSegment", INFO + 74 + (i - 1) * (width + 4), y + 2, width, 12, OFF, 5)
			UiKit.round(segment, 3)
			segments[i] = segment
		end
		local value = label(card, "", INFO + 74 + count * (width + 4) + 4, y, 46, 16, 13, DIM)
		return { Caption = caption, Segments = segments, Value = value, Shown = -1, Max = count }
	end
	local bars = {}
	for row, key in { "Size", "Clarity", "Cut" } do
		bars[key] = bar(string.upper(key), 158 + (row - 1) * 30, SEGMENTS, 17)
	end
	bars.Quality = bar("QUALITY", 158, QUALITY, 48)
	-- A piece of gear's lines, under its quality.
	local statLine = label(card, "", INFO, 186, WIDTH - 24 - INFO, 18, 14, GREEN)
	local passiveLine = label(card, "", INFO, 208, WIDTH - 24 - INFO, 16, 12, GOLD)
	local affixLine = label(card, "", INFO, 228, WIDTH - 24 - INFO, 16, 12, BLUE)
	for _, line in { statLine, passiveLine, affixLine } do
		line.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local valueCaption = label(card, "VALUE", INFO, 254, 70, 16, 11, DIM)
	local worth = label(card, "", INFO + 74, 248, 262, 28, 20, GOLD)
	local progress = panel(card, "RollProgress", INFO, 288, WIDTH - 24 - INFO, 2, Color3.fromRGB(42, 57, 72))
	local fill = panel(progress, "Fill", 0, 0, 0, 2, DIM)
	local footer = label(card, "", INFO, 296, WIDTH - 24 - INFO, 32, 12, DIM)
	footer.TextWrapped = true
	footer.TextYAlignment = Enum.TextYAlignment.Top
	local effects = panel(card, "Celebration", 0, 0, WIDTH, HEIGHT, INK, 6)
	effects.BackgroundTransparency = 1

	-- The strip: one chip per piece, lit as it lands; SKIP ALL beside it.
	local skipButton = button(card, "SkipAll", "SKIP ALL", WIDTH - 24 - 100, STRIP, 100, 30)
	skipButton.TextSize = 12
	skipButton.Activated:Connect(function()
		skipAll = true
	end)
	local stripWidth = WIDTH - 48 - 100 - 12
	local chipGap = 6
	local chipWidth = math.min(64, math.floor((stripWidth - (#entries - 1) * chipGap) / #entries))
	local chips = {}
	for i, entry in entries do
		local chip = panel(card, "PieceChip", 24 + (i - 1) * (chipWidth + chipGap), STRIP, chipWidth, 30, OFF, 5)
		UiKit.round(chip, 6)
		local stroke = new("UIStroke", { Color = DIM, Thickness = 1, Transparency = 0.6 }, chip)
		local short = if entry.Item.Kind == "Gem"
			then "GEM"
			else string.upper(
				string.match((Slots.Definitions[entry.Item.Slot] or {}).Label or entry.Item.Slot or "?", "^%S+") or "?"
			)
		local text = label(chip, short, 0, 0, chipWidth, 30, if chipWidth < 44 then 9 else 10, DIM)
		text.TextXAlignment = Enum.TextXAlignment.Center
		chips[i] = { Frame = chip, Stroke = stroke, Text = text }
	end
	local function lightChip(i, state)
		local chip = chips[i]
		local entry = entries[i]
		local color = GemConfig.TierColors[entry.Rarity or (entry.Item.Gem and entry.Item.Gem.Tier) or "Rare"] or GOLD
		if state == "current" then
			chip.Stroke.Color, chip.Stroke.Thickness, chip.Stroke.Transparency = WHITE, 2, 0
			chip.Text.TextColor3 = WHITE
		elseif state == "landed" then
			chip.Frame.BackgroundColor3 = color
			chip.Stroke.Color, chip.Stroke.Thickness, chip.Stroke.Transparency = color, 1, 0
			chip.Text.TextColor3 = INK
		end
	end

	local function showBar(key, amount, color)
		local b = bars[key]
		amount = math.clamp(math.floor(amount or 0), 0, b.Max)
		if b.Shown == amount and b.Color == color then
			return
		end
		b.Shown, b.Color = amount, color
		for i, segment in b.Segments do
			segment.BackgroundColor3 = if i <= amount then color else OFF
		end
		b.Value.Text = amount .. "/" .. b.Max
		b.Value.TextColor3 = if amount >= b.Max then GOLD else WHITE
	end
	local function clearBars()
		for _, b in bars do
			b.Shown, b.Color = -1, nil
			for _, segment in b.Segments do
				segment.BackgroundColor3 = OFF
			end
			b.Value.Text = ""
		end
	end
	-- Gem rows or gear rows, never both.
	local function layoutFor(isGem: boolean)
		for key, b in bars do
			local on = (key == "Quality") ~= isGem
			b.Caption.Visible, b.Value.Visible = on, on
			for _, segment in b.Segments do
				segment.Visible = on
			end
		end
		statLine.Visible, passiveLine.Visible, affixLine.Visible = not isGem, not isGem, not isGem
		valueCaption.Text = if isGem then "VALUE" else "MARKET"
	end
	local function palette(tier, strength)
		local color = GemConfig.TierColors[tier] or WHITE
		edge.Color, accent.BackgroundColor3, fill.BackgroundColor3 = color, color, color
		haloEdge.Color, wellEdge.Color, pillEdge.Color, pillText.TextColor3 = color, color, color, color
		glow.BackgroundColor3, divider.BackgroundColor3, actionEdge.Color = color, color, color
		paint.Color = ColorSequence.new(color:Lerp(INK, 0.9 - strength * 0.12), INK)
		wellPaint.Color = ColorSequence.new(color:Lerp(INK, 0.55), color:Lerp(INK, 0.85))
		spot.BackgroundColor3 = color:Lerp(WHITE, 0.35)
		core.BackgroundColor3 = color:Lerp(WHITE, 0.7)
		pillText.Text = string.upper(GemConfig.TierLabels[tier] or tier)
	end

	-- Reel pictures, built once and cloned into the five live cells.
	local templates = Instance.new("Folder")
	local gemViews, gemElements = {}, {}
	local offset = rng:NextInteger(0, #GemConfig.Elements - 1)
	for i, tier in GemConfig.TierOrder do
		local element = GemConfig.Elements[(i + offset - 1) % #GemConfig.Elements + 1]
		gemElements[tier] = element
		gemViews[tier] = GemArt.viewport(templates, {
			Id = "cache-preview-" .. tier,
			Tier = tier,
			Element = element,
			Size = 6,
			Clarity = 7,
			Cut = 6,
		}, false)
	end
	local gearViews = nil -- (built when the gear's turn comes, previews and all)
	local function cleanup()
		resizeConnection:Disconnect()
		templates:Destroy()
		if anchor.Parent then
			anchor:Destroy()
		end
	end

	local function place(slot, view)
		slot.Art:ClearAllChildren()
		local copy = view:Clone()
		if copy:IsA("ViewportFrame") then
			copy.CurrentCamera = copy:FindFirstChildOfClass("Camera")
		end
		copy.ZIndex, copy.Parent = 5, slot.Art
	end
	-- Rolls the reel from wherever it is to `TARGET`, easing out; each cell
	-- shows viewOf(index), and onCenter(index, p) runs as a new one passes
	-- the middle. Stops at once on REVEAL or SKIP ALL.
	local function roll(duration, viewOf, onCenter)
		for _, slot in slots do
			slot.Index = nil
		end
		local lastIndex = -1
		local function render(position, strength)
			local center = math.floor(position + 0.5)
			for index = center - 2, center + 2 do
				local slot = slots[index % #slots + 1]
				if slot.Index ~= index then
					slot.Index = index
					place(slot, viewOf(index))
				end
				-- (The strip rolls downward: later pieces come in from the top.)
				slot.Frame.Position = UDim2.fromOffset(0, (WELL - CELL) / 2 + (position - index) * CELL)
			end
			if lastIndex ~= center then
				lastIndex = center
				onCenter(center, strength)
				LotterySound.tick(strength)
			end
		end
		local started = os.clock()
		while live() and not skip and not skipAll do
			local p = math.clamp((os.clock() - started) / duration, 0, 1)
			render(2 + (TARGET - 2) * (1 - (1 - p) ^ 3), p)
			fill.Size = UDim2.new(p, 0, 1, 0)
			sweep.Rotation = (os.clock() - started) * (540 - 380 * p)
			if p >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if live() and not skipAll then
			render(TARGET, 1)
		end
	end
	-- The landing: a flash in the window, a punch of the display, a burst,
	-- and glints that twinkle while it holds.
	local function celebrate(rank, color)
		LotterySound.reveal(rank)
		burst(effects, rank, color)
		spot.BackgroundTransparency, core.BackgroundTransparency = 0.6, 0.62
		flash.BackgroundTransparency = 0.25
		tween(flash, 0.45, { BackgroundTransparency = 1 })
		punch.Scale = 1.12
		tween(punch, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		local glints = {}
		for i, at in { { 0.36, 0.34 }, { 0.66, 0.42 }, { 0.46, 0.66 } } do
			local glint = panel(well, "Glint", WELL * at[1], WELL * at[2], 10, 10, WHITE, 6)
			glint.AnchorPoint, glint.Rotation, glint.BackgroundTransparency = Vector2.new(0.5, 0.5), 45, 1
			glints[i] = glint
		end
		return glints
	end
	-- Holds a landed piece while reveal(t) fills its details in; moves on
	-- after `hold` seconds, on NEXT, or on SKIP ALL.
	local function holdOn(hold, glints, reveal)
		local started = os.clock()
		while live() and not advance and not skipAll do
			local t = os.clock() - started
			reveal(t)
			sweep.Rotation = t * 40
			for i, glint in glints do
				local pulse = math.abs(math.sin(t * (2.2 + i * 0.7) + i * 1.9))
				glint.BackgroundTransparency = 1 - pulse * 0.9
				glint.Size = UDim2.fromOffset(4 + pulse * 9, 4 + pulse * 9)
			end
			if t >= hold then
				break
			end
			RunService.RenderStepped:Wait()
		end
		for _, glint in glints do
			glint:Destroy()
		end
		if live() then
			reveal(math.huge) -- (all of it, however it moved on)
			effects:ClearAllChildren()
			spot.BackgroundTransparency, core.BackgroundTransparency = 0.78, 0.8
		end
	end

	local function rollGem(index, entry)
		local gem = entry.Item.Gem
		local rank = GemConfig.TierRank[gem.Tier] or 3
		local color = GemConfig.TierColors[gem.Tier] or WHITE
		layoutFor(true)
		heading.Text = string.format("FREE GEM  ·  %d OF %d", index, gemCount)
		heading.TextColor3 = Color3.fromRGB(110, 220, 140)
		footer.Text = "Rolling..."
		-- The strip: rarities rolled like real finds, each with stats for
		-- the bars to flicker through, and the awarded gem at the target.
		local sequence, teases = {}, {}
		local function grade()
			return 2 + math.floor(rng:NextNumber() * 8)
		end
		for i = 0, TARGET + 3 do
			sequence[i] = GemRoller.rollRarity(rng)
			teases[i] = { Size = grade(), Clarity = grade(), Cut = grade() }
		end
		sequence[TARGET] = gem.Tier
		local winner = GemArt.viewport(templates, gem, true) -- (every facet)
		roll(2.15 + rank * 0.12, function(i)
			local view = if i == TARGET then winner else gemViews[sequence[i] or "Common"]
			return view
		end, function(i, strength)
			local tier = sequence[i] or "Common"
			palette(tier, strength)
			local dim = (GemConfig.TierColors[tier] or WHITE):Lerp(INK, 0.35)
			status.Text, status.TextColor3, status.TextSize = string.upper(GemConfig.TierLabels[tier] or tier), dim, 32
			local shade = GemConfig.shade({ Element = gemElements[tier] or gem.Element, Tier = tier })
			detail.Text, detail.TextColor3 = shade and shade.Name or "", DIM
			local tease = teases[i] or teases[0]
			for key, value in tease do
				showBar(key, value, dim)
				bars[key].Value.TextColor3 = DIM
			end
			worth.Text = "≈ "
				.. commas(GemConfig.value({
					Tier = tier,
					Element = gem.Element,
					Size = tease.Size,
					Clarity = tease.Clarity,
					Cut = tease.Cut,
				}))
				.. " coins"
			worth.TextColor3 = GOLD:Lerp(INK, 0.45)
		end)
		if not live() or skipAll then
			return
		end
		landed = true
		action.Text = if index == #entries then "CONTINUE  ›" else "NEXT  ›"
		palette(gem.Tier, rank / 5)
		fill.Size = UDim2.fromScale(1, 1)
		heading.Text = string.format("FREE GEM  ·  %d OF %d  ·  YOURS", index, gemCount)
		status.Text, status.TextColor3 = string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier), color
		status.TextSize = if rank >= 4 then 36 else 32
		local shade = GemConfig.shade(gem)
		detail.Text, detail.TextColor3 = shade and shade.Name or entry.Name or "", WHITE
		local elementColor = GemConfig.ElementColors[gem.Element] or WHITE
		dot.BackgroundColor3, dot.BackgroundTransparency = elementColor, 0
		kind.Text, kind.TextColor3 = string.upper(GemConfig.elementName(gem.Element)), elementColor
		worth.Text, worth.TextColor3 = "≈ " .. commas(GemConfig.value(gem)) .. " coins", GOLD
		footer.Text = if gem.Flawless then "Flawless: every grade a 10. Free, it's yours." else "Free: it's yours."
		clearBars()
		local glints = celebrate(rank, color)
		-- The stats fill in, one segment at a time, row after row.
		local stats = { Size = gem.Size or 0, Clarity = gem.Clarity or 0, Cut = gem.Cut or 0 }
		holdOn(2.6 + rank * 0.2, glints, function(t)
			for row, key in { "Size", "Clarity", "Cut" } do
				local shown = math.clamp(math.floor((t - 0.25 - (row - 1) * 0.18) / 0.04), 0, stats[key])
				if shown ~= bars[key].Shown then
					showBar(key, shown, color)
					if shown > 0 and t < math.huge then
						LotterySound.tick(shown / SEGMENTS)
					end
				end
			end
		end)
	end

	local function rollGear(index, entry)
		local item = entry.Item
		local tier = entry.Rarity or "Rare"
		local rank = GemConfig.TierRank[tier] or 3
		local color = GemConfig.TierColors[tier] or WHITE
		local n = index - gemCount
		layoutFor(false)
		heading.Text = string.format("GEAR  ·  %d OF %d", n, gearCount)
		heading.TextColor3 = GOLD
		footer.Text = "Rolling..."
		-- The strip: the cache's own pieces (3D), and this one at the target.
		local others = {}
		for _, g in gearViews do
			table.insert(others, g)
		end
		local sequence = {}
		for i = 0, TARGET + 3 do
			sequence[i] = others[rng:NextInteger(1, #others)]
		end
		local mine = gearViews[entry.OfferId]
		sequence[TARGET] = mine
		roll(1.6 + rank * 0.1, function(i)
			return (sequence[i] or mine).View
		end, function(i, strength)
			local g = sequence[i] or mine
			palette(g.Tier, strength)
			local dim = (GemConfig.TierColors[g.Tier] or WHITE):Lerp(INK, 0.35)
			status.Text, status.TextColor3, status.TextSize =
				string.upper(GemConfig.TierLabels[g.Tier] or g.Tier), dim, 32
			detail.Text, detail.TextColor3 = g.Name, DIM
			dot.BackgroundColor3, dot.BackgroundTransparency = dim, 0
			kind.Text, kind.TextColor3 = string.upper(g.Label), DIM
			showBar("Quality", rng:NextInteger(1, QUALITY), dim)
			bars.Quality.Value.TextColor3 = DIM
			statLine.Text, passiveLine.Text, affixLine.Text = "· · ·", "", ""
			statLine.TextColor3 = DIM
			worth.Text, worth.TextColor3 = "≈ " .. commas(g.Price) .. " coins", GOLD:Lerp(INK, 0.45)
		end)
		if not live() or skipAll then
			return
		end
		landed = true
		action.Text = if index == #entries then "TO YOUR PICKS  ›" else "NEXT  ›"
		palette(tier, rank / 5)
		fill.Size = UDim2.fromScale(1, 1)
		status.Text, status.TextColor3 = string.upper(GemConfig.TierLabels[tier] or tier), color
		status.TextSize = if rank >= 4 then 36 else 32
		detail.Text, detail.TextColor3 = entry.Name or mine.Name, WHITE
		dot.BackgroundColor3 = color
		kind.Text, kind.TextColor3 = string.upper(mine.Label), color
		worth.Text, worth.TextColor3 = "≈ " .. commas(mine.Price) .. " coins", GOLD
		footer.Text = if cache.Dev
			then "Keep it, or it's dropped (a test roll)."
			else string.format(
				"Keep it, or it sells on the Market and you get %d%% (≈ %s coins).",
				math.floor(ArenaStreak.Commission * 100 + 0.5),
				commas(ArenaStreak.commission(mine.Price))
			)
		clearBars()
		statLine.Text, passiveLine.Text, affixLine.Text = "", "", ""
		statLine.TextColor3 = GREEN
		local stats, passive, affixes = CacheLottery.gearLines(item)
		local lines = {
			{ statLine, if stats ~= "" then stats else "Base stats" },
			{ passiveLine, if passive then "◆ " .. passive else "" },
			{
				affixLine,
				if affixes > 0
					then string.format("%d elemental affix%s", affixes, if affixes == 1 then "" else "es")
					else "",
			},
		}
		local quality = math.clamp(item.Quality or 1, 1, QUALITY)
		local glints = celebrate(rank, color)
		-- The quality fills in, then the lines appear one by one.
		holdOn(1.9 + rank * 0.15, glints, function(t)
			local shown = math.clamp(math.floor((t - 0.2) / 0.09), 0, quality)
			if shown ~= bars.Quality.Shown then
				showBar("Quality", shown, color)
				if shown > 0 and t < math.huge then
					LotterySound.tick(shown / QUALITY)
				end
			end
			for i, line in lines do
				if t >= 0.35 + i * 0.22 and line[1].Text ~= line[2] then
					line[1].Text = line[2]
				end
			end
		end)
	end

	for index, entry in entries do
		if not live() or skipAll then
			break
		end
		skip, advance, landed = false, false, false
		action.Text = "REVEAL  ›"
		lightChip(index, "current")
		dot.BackgroundTransparency, kind.Text = 1, ""
		statLine.Text, passiveLine.Text, affixLine.Text = "", "", ""
		if entry.Item.Kind == "Gem" then
			rollGem(index, entry)
		else
			if not gearViews then
				-- The gear's turn: wait for its 3D previews (3 s from the
				-- start at most; the gems usually cover it), then build the
				-- reel's pictures.
				heading.Text, heading.TextColor3 = "GEAR", GOLD
				footer.Text = "Bringing out the gear..."
				while live() and not skipAll and not (options.Ready and options.Ready()) do
					if os.clock() - opened >= 3 then
						break
					end
					RunService.RenderStepped:Wait()
				end
				if not live() or skipAll then
					break
				end
				gearViews = {}
				for _, e in entries do
					if e.Item.Kind == "Gear" then
						local tier = e.Rarity or "Rare"
						local def = Slots.Definitions[e.Item.Slot]
						gearViews[e.OfferId] = {
							View = gearTemplate(templates, e, cache.Id .. "/" .. e.OfferId),
							Tier = tier,
							Name = e.Name or "",
							Label = def and def.Label or e.Item.Slot or "Gear",
							Price = ArenaStreak.vaultPrice(e.Item, nil, tier),
						}
					end
				end
			end
			rollGear(index, entry)
		end
		if live() and landed then
			lightChip(index, "landed")
		end
	end
	if live() then
		tween(card, 0.18, { GroupTransparency = 1 })
		task.wait(0.18)
	end
	cleanup()
end

return CacheLottery
