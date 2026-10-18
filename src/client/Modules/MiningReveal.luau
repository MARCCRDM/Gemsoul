-- The lobby's gem find: one round display rolls through gems (the same
-- circle reel as the starter lottery) and lands on yours; its rarity, name,
-- element and stats sit beside it, the stats as bars that fill once it lands.
-- Outcomes have already been awarded by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local GemArt = require(script.Parent.GemArt)
local IronUi = require(script.Parent.IronUi)
local LotterySound = require(script.Parent.LotterySound)
local UiKit = require(script.Parent.UiKit)

local Reveal = {}
local new = IronUi.new
local INK = Color3.fromRGB(9, 17, 27)
local WHITE = Color3.fromRGB(241, 249, 255)
local DIM = Color3.fromRGB(155, 177, 199)
local WIDTH, HEIGHT = 660, 342
local WELL, CELL = 196, 150 -- the round display, and one gem on its reel
local CX, CY = 152, 166 -- the display's centre on the card
local INFO = 300 -- where the right-hand column starts
local GOLD = Color3.fromRGB(255, 206, 92)
local SEGMENTS = 10
local queue = {}
local current = nil
local generation = 0

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

local function burst(parent, rank, color)
	-- One bounded burst; high rarity adds rays and a second expanding ring.
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

local function show(loot, token)
	local gem = loot.Gem
	local rank = GemConfig.TierRank[gem.Tier] or 1
	local winningColor = GemConfig.TierColors[gem.Tier] or WHITE
	local gui = UiKit.gui("MiningGemRoll", 20)
	gui.IgnoreGuiInset = false
	local anchor = panel(gui, "ResponsiveBoard", 0, 0, WIDTH, HEIGHT, INK)
	anchor.BackgroundTransparency = 1
	anchor.AnchorPoint, anchor.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.49)
	local fit = new("UIScale", {}, anchor)
	local function resize()
		local size = gui.AbsoluteSize
		fit.Scale = math.max(0.1, math.min(1, (size.X - 24) / WIDTH, (size.Y - 32) / HEIGHT))
	end
	local resizeConnection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local card = new("CanvasGroup", {
		Name = "GemRarityRoller",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		GroupTransparency = 0,
		Active = true,
		ClipsDescendants = true,
	}, anchor)
	UiKit.round(card, 18)
	-- A CanvasGroup gradient would tint every gem and label after compositing.
	-- Keep the rarity lighting on its own background layer.
	local backdrop = panel(card, "RarityBackdrop", 0, 0, WIDTH, HEIGHT, WHITE, 1)
	local paint = new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(INK, INK),
		Offset = Vector2.new(-0.25, 0),
	}, backdrop)
	local edge = new("UIStroke", { Color = DIM, Thickness = 2, Transparency = 0.2 }, card)
	local accent = panel(card, "RarityAccent", 0, 0, WIDTH, 3, DIM)
	local divider = panel(card, "ColumnRule", INFO - 22, 28, 1, HEIGHT - 56, DIM)
	divider.BackgroundTransparency = 0.8

	-- The display: a soft glow, a ring of light that sweeps round it while it
	-- rolls, and the round window the gems roll through.
	local glow = panel(card, "DisplayGlow", CX, CY, WELL + 64, WELL + 64, DIM, 2)
	glow.AnchorPoint, glow.BackgroundTransparency = Vector2.new(0.5, 0.5), 0.9
	UiKit.round(glow, 400)
	local halo = panel(card, "DisplayHalo", CX, CY, WELL + 26, WELL + 26, INK, 3)
	halo.AnchorPoint, halo.BackgroundTransparency = Vector2.new(0.5, 0.5), 1
	UiKit.round(halo, 400)
	local haloEdge = new("UIStroke", { Color = WHITE, Thickness = 3 }, halo)
	local sweep = new("UIGradient", {
		Rotation = 0,
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
	-- (Never put a gradient on the CanvasGroup itself: it would tint the gem.
	-- The window's colour is its own layer, under the gems.)
	local backdrop = panel(well, "WindowColour", 0, 0, WELL, WELL, WHITE, 4)
	local wellPaint = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(INK, INK) }, backdrop)
	-- A pool of light behind the stone, in its rarity colour, so it shines.
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
		local art = panel(cell, "Stone", (WELL - 132) / 2, (CELL - 132) / 2, 132, 132, INK, 5)
		art.BackgroundTransparency = 1
		slots[i] = { Frame = cell, Art = art }
	end
	-- Depth: the window darkens toward its top and bottom, so gems roll in
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
	-- The rarity under the display, changing as each gem rolls past.
	local pill = panel(card, "TierPill", CX - 70, CY + WELL / 2 + 18, 140, 26, INK, 5)
	UiKit.round(pill, 13)
	local pillEdge = new("UIStroke", { Color = DIM, Thickness = 1.5 }, pill)
	local pillText = label(pill, "", 0, 0, 140, 26, 12, DIM)
	pillText.TextXAlignment = Enum.TextXAlignment.Center

	-- The right-hand column.
	local heading = label(card, "ROLLING YOUR GEM", INFO, 22, 200, 18, 13, DIM)
	local action = new("TextButton", {
		Name = "RevealOrContinue",
		Text = "REVEAL  ›",
		Font = IronUi.Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		BackgroundColor3 = Color3.fromRGB(36, 52, 69),
		Position = UDim2.fromOffset(WIDTH - 24 - 126, 16),
		Size = UDim2.fromOffset(126, 36),
		ZIndex = 8,
	}, card)
	UiKit.round(action, 8)
	local actionEdge = new("UIStroke", { Color = DIM, Thickness = 1.5, Transparency = 0.3 }, action)
	local skip, dismiss, landed = false, false, false
	action.Activated:Connect(function()
		if landed then
			dismiss = true
		else
			skip = true
		end
	end)
	current = {
		Gui = gui,
		Destroy = function()
			resizeConnection:Disconnect()
			gui:Destroy()
		end,
	}
	local live = function()
		return token == generation and gui.Parent ~= nil
	end
	local status = label(card, "", INFO, 52, 336, 40, 34, DIM)
	local detail = label(card, "", INFO, 94, 336, 24, 19)
	local dot = panel(card, "ElementDot", INFO, 128, 10, 10, DIM, 5)
	UiKit.round(dot, 5)
	dot.BackgroundTransparency = 1
	local element = label(card, "", INFO + 16, 123, 300, 20, 13, DIM)
	-- Size, clarity and cut: ten segments each.
	local bars = {}
	for row, key in { "Size", "Clarity", "Cut" } do
		local y = 158 + (row - 1) * 30
		label(card, string.upper(key), INFO, y, 70, 16, 11, DIM)
		local segments = {}
		for i = 1, SEGMENTS do
			local segment =
				panel(card, "StatSegment", INFO + 74 + (i - 1) * 21, y + 2, 17, 12, Color3.fromRGB(32, 45, 60), 5)
			UiKit.round(segment, 3)
			segments[i] = segment
		end
		local value = label(card, "", INFO + 74 + SEGMENTS * 21 + 8, y, 46, 16, 13, DIM)
		bars[key] = { Segments = segments, Value = value, Shown = -1 }
	end
	local valueCaption = label(card, "VALUE", INFO, 254, 70, 16, 11, DIM)
	valueCaption.TextYAlignment = Enum.TextYAlignment.Center
	local worth = label(card, "", INFO + 74, 248, 260, 28, 22, GOLD)
	local progress = panel(card, "RollProgress", INFO, 288, WIDTH - 24 - INFO, 2, Color3.fromRGB(42, 57, 72))
	local fill = panel(progress, "Fill", 0, 0, 0, 2, DIM)
	local footer = label(card, "", INFO, 300, WIDTH - 24 - INFO, 20, 12, DIM)
	local effects = panel(card, "Celebration", 0, 0, WIDTH, HEIGHT, INK, 6)
	effects.BackgroundTransparency = 1

	local function showBar(key, amount, color)
		local bar = bars[key]
		amount = math.clamp(math.floor(amount or 0), 0, SEGMENTS)
		if bar.Shown == amount and bar.Color == color then
			return
		end
		bar.Shown, bar.Color = amount, color
		for i, segment in bar.Segments do
			segment.BackgroundColor3 = if i <= amount then color else Color3.fromRGB(32, 45, 60)
		end
		bar.Value.Text = amount .. "/10"
		bar.Value.TextColor3 = if amount >= SEGMENTS then GOLD else WHITE
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
	-- Only five reel cells are alive. Five templates are built once and recycled,
	-- instead of constructing a viewport for every entry in the long strip.
	local templates = Instance.new("Folder")
	local views = {}
	local rng = Random.new()
	for i, tier in GemConfig.TierOrder do
		local preview = {
			Id = "mining-preview-" .. tier,
			Tier = tier,
			Element = GemConfig.Elements[(i - 1) % #GemConfig.Elements + 1],
			Size = 6,
			Clarity = 7,
			Cut = 6,
		}
		views[tier] = GemArt.viewport(templates, preview, false)
	end
	views.Winner = GemArt.viewport(templates, gem, true) -- (every facet)
	gui.Destroying:Once(function()
		templates:Destroy()
	end)
	-- The strip: rarities rolled like real finds, each with its own stats for
	-- the bars to flicker through, and the awarded gem at the target.
	local sequence, teases = {}, {}
	local target = 23
	local function grade()
		return 2 + math.floor(rng:NextNumber() * 8)
	end
	for i = 0, target + 3 do
		sequence[i] = GemRoller.rollRarity(rng, 0, GemRoller.MiningWeights)
		teases[i] = { Size = grade(), Clarity = grade(), Cut = grade() }
	end
	sequence[target] = gem.Tier
	local lastIndex = -1
	local function render(position, strength)
		local center = math.floor(position + 0.5)
		for index = center - 2, center + 2 do
			local slot = slots[index % #slots + 1]
			local tier = sequence[index] or "Common"
			if slot.Index ~= index then
				slot.Index = index
				slot.Art:ClearAllChildren()
				local view = (if index == target then views.Winner else views[tier]):Clone()
				view.CurrentCamera = view:FindFirstChildOfClass("Camera")
				-- Bright, white light: a gem should glitter, not sulk.
				view.Ambient = Color3.fromRGB(235, 235, 245)
				view.LightColor = Color3.new(1, 1, 1)
				view.ZIndex, view.Parent = 5, slot.Art
			end
			-- The strip rolls downward: later gems come in from the top.
			slot.Frame.Position = UDim2.fromOffset(0, (WELL - CELL) / 2 + (position - index) * CELL)
		end
		if lastIndex ~= center then
			lastIndex = center
			local tier = sequence[center] or "Common"
			palette(tier, strength)
			local tease = teases[center] or teases[0]
			local color = (GemConfig.TierColors[tier] or WHITE):Lerp(INK, 0.35)
			-- The big rarity name and the value flick through each gem as it
			-- rolls past, dimmed, like a slot machine's window.
			status.Text = string.upper(GemConfig.TierLabels[tier] or tier)
			status.TextColor3 = color
			local value = GemConfig.value({
				Tier = tier,
				Element = gem.Element,
				Size = tease.Size,
				Clarity = tease.Clarity,
				Cut = tease.Cut,
			})
			worth.Text = "≈ " .. commas(value) .. " coins"
			worth.TextColor3 = GOLD:Lerp(INK, 0.45)
			for key, bar in bars do
				showBar(key, tease[key], color)
				bar.Value.TextColor3 = DIM
			end
			LotterySound.tick(strength)
		end
	end
	local duration = 2.15 + rank * 0.12
	local started = os.clock()
	while live() and not skip do
		local p = math.clamp((os.clock() - started) / duration, 0, 1)
		render(2 + (target - 2) * (1 - (1 - p) ^ 3), p)
		fill.Size = UDim2.new(p, 0, 1, 0)
		sweep.Rotation = (os.clock() - started) * (540 - 380 * p)
		if p >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if not live() then
		return
	end
	render(target, 1)
	landed = true
	palette(gem.Tier, rank / 5)
	fill.Size = UDim2.fromScale(1, 1)
	heading.Text = if rank == 5 then "LEGENDARY DISCOVERY" elseif rank >= 3 then "RARE FIND" else "GEM DISCOVERED"
	heading.TextColor3 = winningColor
	status.Text = string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier)
	status.TextColor3 = winningColor
	status.TextSize = if rank >= 4 then 36 else 32
	detail.Text = GemConfig.shade(gem).Name
	local elementColor = GemConfig.ElementColors[gem.Element] or WHITE
	dot.BackgroundColor3, dot.BackgroundTransparency = elementColor, 0
	element.Text = string.upper(GemConfig.elementName(gem.Element))
	element.TextColor3 = elementColor
	worth.Text = "≈ " .. commas(GemConfig.value(gem)) .. " coins"
	worth.TextColor3 = GOLD
	for _, bar in bars do
		bar.Shown = -1
		for _, segment in bar.Segments do
			segment.BackgroundColor3 = Color3.fromRGB(32, 45, 60)
		end
		bar.Value.Text = ""
	end
	local extras = { "Added to your gem inventory" }
	if loot.Coins then
		table.insert(extras, "+" .. loot.Coins .. " coins")
	end
	if loot.Gear then
		table.insert(extras, tostring(loot.Gear))
	end
	footer.Text = table.concat(extras, "  ·  ")
	footer.TextTruncate = Enum.TextTruncate.AtEnd
	action.Text = "CONTINUE  ›"
	LotterySound.reveal(rank)
	burst(effects, rank, winningColor)
	-- Landed: the light behind it swells, and a few glints twinkle on it.
	spot.BackgroundTransparency, core.BackgroundTransparency = 0.6, 0.62
	local glints = {}
	for i, at in { { 0.36, 0.34 }, { 0.66, 0.42 }, { 0.46, 0.66 } } do
		local glint = panel(well, "Glint", WELL * at[1], WELL * at[2], 10, 10, WHITE, 6)
		glint.AnchorPoint, glint.Rotation, glint.BackgroundTransparency = Vector2.new(0.5, 0.5), 45, 1
		glints[i] = glint
	end
	-- The gem lands: a flash in the window and a punch of the whole display.
	flash.BackgroundTransparency = 0.25
	tween(flash, 0.45, { BackgroundTransparency = 1 })
	punch.Scale = 1.12
	tween(punch, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Rare finds earn their own light rays without washing out the text.
	if rank >= 3 then
		for i = 1, rank * 3 do
			local ray = panel(effects, "RarityRay", CX, CY, 3, WELL / 2 + 24 + rank * 8, winningColor, 3)
			ray.AnchorPoint = Vector2.new(0.5, 1)
			ray.Rotation = i * 360 / (rank * 3)
			ray.BackgroundTransparency = 0.5
			tween(ray, 1.3, { BackgroundTransparency = 1 })
		end
	end
	-- Then the stats fill in, one segment at a time, row after row.
	local stats = { Size = gem.Size, Clarity = gem.Clarity, Cut = gem.Cut or 0 }
	started = os.clock()
	while live() and not dismiss do
		local t = os.clock() - started
		for row, key in { "Size", "Clarity", "Cut" } do
			local shown = math.clamp(math.floor((t - 0.25 - (row - 1) * 0.18) / 0.04), 0, stats[key])
			if shown ~= bars[key].Shown then
				showBar(key, shown, winningColor)
				if shown > 0 then
					LotterySound.tick(shown / SEGMENTS)
				end
			end
		end
		sweep.Rotation = t * 40
		for i, glint in glints do
			local pulse = math.abs(math.sin(t * (2.2 + i * 0.7) + i * 1.9))
			glint.BackgroundTransparency = 1 - pulse * 0.9
			glint.Size = UDim2.fromOffset(4 + pulse * 9, 4 + pulse * 9)
		end
		local hold = if #queue > 0 then 1.5 else 2.6 + rank * 0.2
		if t >= hold then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if not live() then
		return
	end
	tween(card, 0.18, { GroupTransparency = 1 })
	task.wait(0.18)
end

function Reveal.push(loot)
	if not loot.Gem then
		return
	end
	table.insert(queue, loot)
	if current then
		return
	end
	-- Mark the worker before spawning so simultaneous drops cannot start two reels.
	current = {}
	local token = generation
	task.spawn(function()
		while token == generation and #queue > 0 do
			local nextLoot = table.remove(queue, 1)
			local ok, err = pcall(show, nextLoot, token)
			if token ~= generation then
				return
			end
			if current and current.Destroy then
				current.Destroy()
			end
			current = {}
			if not ok then
				warn("Mining reveal: " .. tostring(err))
			end
		end
		if token == generation then
			current = nil
		end
	end)
end

function Reveal.close()
	generation += 1
	table.clear(queue)
	if current and current.Destroy then
		current.Destroy()
	end
	current = nil
end

return Reveal
