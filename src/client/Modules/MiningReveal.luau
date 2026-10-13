-- The lobby's rarity reel, using the same sliding-strip treatment and native
-- GemArt as the starter roller. Outcomes have already been awarded by the server.
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
local WIDTH, HEIGHT, WELL, CELL = 660, 342, 612, 124
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
		local spark =
			panel(parent, "RaritySpark", WIDTH / 2, 119, 3 + rank, 3 + rank, if i % 3 == 0 then WHITE else color, 7)
		spark.Rotation = 45
		tween(spark, 0.75 + rank * 0.06, {
			Position = UDim2.fromOffset(WIDTH / 2 + math.cos(a) * (105 + rank * 17), 119 + math.sin(a) * 79),
			BackgroundTransparency = 1,
			Rotation = 135,
		})
	end
	for i = 1, if rank >= 4 then 2 else 1 do
		local ring = panel(parent, "RarityRing", WIDTH / 2, 119, 32, 32, color, 6)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		UiKit.round(ring, 200)
		local edge = new("UIStroke", { Color = color, Thickness = if rank >= 4 then 2 else 1 }, ring)
		tween(ring, 0.7 + i * 0.16, { Size = UDim2.fromOffset(130 + i * 38, 130 + i * 38) })
		tween(edge, 0.7 + i * 0.16, { Transparency = 1 })
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
	UiKit.round(card, 16)
	-- A CanvasGroup gradient would tint every gem and label after compositing.
	-- Keep the rarity lighting on its own background layer.
	local backdrop = panel(card, "RarityBackdrop", 0, 0, WIDTH, HEIGHT, WHITE, 1)
	local paint = new("UIGradient", { Rotation = 115, Color = ColorSequence.new(INK, INK) }, backdrop)
	local edge = new("UIStroke", { Color = DIM, Thickness = 2, Transparency = 0.25 }, card)
	local accent = panel(card, "RarityAccent", 24, 0, WELL, 3, DIM)
	local heading = label(card, "GEM DISCOVERED", 24, 16, 310, 22, 15)
	local action = new("TextButton", {
		Name = "RevealOrContinue",
		Text = "REVEAL  ›",
		Font = IronUi.Bold,
		TextSize = 13,
		TextColor3 = WHITE,
		BackgroundColor3 = Color3.fromRGB(36, 52, 69),
		Position = UDim2.fromOffset(510, 10),
		Size = UDim2.fromOffset(126, 38),
		ZIndex = 8,
	}, card)
	UiKit.round(action, 8)
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
	local well = panel(card, "RollerWindow", 24, 56, WELL, 128, INK, 3)
	well.ClipsDescendants = true
	UiKit.round(well, 10)
	local slots = {}
	for i = 1, 7 do
		local tile = panel(well, "ReelCell", 0, 8, CELL - 8, 112, Color3.fromRGB(20, 32, 46), 3)
		UiKit.round(tile, 8)
		local art = panel(tile, "Stone", 18, 2, 80, 80, INK, 4)
		art.BackgroundTransparency = 1
		local name = label(tile, "", 0, 85, CELL - 8, 16, 10)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local stripe = panel(tile, "TierStripe", 12, 107, CELL - 32, 2, DIM, 4)
		slots[i] = { Frame = tile, Art = art, Name = name, Stripe = stripe }
	end
	-- Fixed selection window and top/bottom pointers; the content moves underneath.
	local selection = panel(well, "SelectedGem", (WELL - CELL) / 2, 5, CELL, 118, INK, 6)
	selection.BackgroundTransparency = 1
	UiKit.round(selection, 9)
	local selectionEdge = new("UIStroke", { Color = WHITE, Thickness = 2 }, selection)
	for _, y in { 1, 123 } do
		local pointer = panel(well, "SelectionPointer", WELL / 2 - 4, y, 8, 8, WHITE, 7)
		pointer.Rotation = 45
	end
	local status = label(card, "ROLLING YOUR GEM", 24, 197, 612, 29, 25, DIM)
	status.TextXAlignment = Enum.TextXAlignment.Center
	local detail = label(card, "", 28, 232, 604, 26, 17)
	detail.TextXAlignment = Enum.TextXAlignment.Center
	local metrics = label(card, "", 24, 266, 612, 20, 12, DIM)
	metrics.TextXAlignment = Enum.TextXAlignment.Center
	local footer = label(card, "", 24, 303, 612, 20, 12, DIM)
	footer.TextXAlignment = Enum.TextXAlignment.Center
	local progress = panel(card, "RollProgress", 24, 291, WELL, 2, Color3.fromRGB(42, 57, 72))
	local fill = panel(progress, "Fill", 0, 0, 0, 2, DIM)
	local effects = panel(card, "Celebration", 0, 0, WIDTH, HEIGHT, INK, 6)
	effects.BackgroundTransparency = 1
	local function palette(tier, strength)
		local color = GemConfig.TierColors[tier] or WHITE
		edge.Color, accent.BackgroundColor3, selectionEdge.Color, fill.BackgroundColor3 = color, color, color, color
		paint.Color = ColorSequence.new(color:Lerp(INK, 0.92 - strength * 0.22), INK)
		status.TextColor3 = color
	end
	-- Only seven reel cells are alive. Five templates are built once and recycled,
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
	views.Winner = GemArt.viewport(templates, gem, false)
	gui.Destroying:Once(function()
		templates:Destroy()
	end)
	local sequence = {}
	local target = 23
	for i = 0, target + 4 do
		sequence[i] = GemRoller.rollRarity(rng)
	end
	sequence[target] = gem.Tier
	local lastIndex = -1
	local function render(position, strength)
		local center = math.floor(position + 0.5)
		for index = center - 3, center + 3 do
			local slot = slots[index % #slots + 1]
			local tier = sequence[index] or "Common"
			if slot.Index ~= index then
				slot.Index = index
				slot.Art:ClearAllChildren()
				local view = (if index == target then views.Winner else views[tier]):Clone()
				view.CurrentCamera = view:FindFirstChildOfClass("Camera")
				view.ZIndex, view.Parent = 4, slot.Art
				slot.Name.Text = string.upper(GemConfig.TierLabels[tier] or tier)
				slot.Name.TextColor3 = GemConfig.TierColors[tier] or WHITE
				slot.Stripe.BackgroundColor3 = slot.Name.TextColor3
			end
			slot.Frame.Position = UDim2.fromOffset(WELL / 2 + (index - position) * CELL - (CELL - 8) / 2, 8)
		end
		if lastIndex ~= center then
			lastIndex = center
			palette(sequence[center] or "Common", strength)
			LotterySound.tick(strength)
		end
	end
	local duration = 2.15 + rank * 0.12
	local started = os.clock()
	while live() and not skip do
		local p = math.clamp((os.clock() - started) / duration, 0, 1)
		render(3 + (target - 3) * (1 - (1 - p) ^ 3), p)
		fill.Size = UDim2.new(p, 0, 1, 0)
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
	status.Text = string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier)
	status.TextSize = if rank >= 4 then 32 else 28
	detail.Text = GemConfig.shade(gem).Name .. "  ·  " .. GemConfig.elementName(gem.Element)
	metrics.Text = string.format(
		"SIZE %d/10     CLARITY %d/10     CUT %d/10     ·     VALUE ~%d COINS",
		gem.Size,
		gem.Clarity,
		gem.Cut or 0,
		GemConfig.value(gem)
	)
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
	-- Rare finds earn their own light rays without washing out the text.
	if rank >= 3 then
		for i = 1, rank * 2 do
			local ray = panel(effects, "RarityRay", WIDTH / 2, 119, 2, 32 + rank * 8, winningColor, 6)
			ray.AnchorPoint = Vector2.new(0.5, 1.8)
			ray.Rotation = i * 360 / (rank * 2)
			ray.BackgroundTransparency = 0.55
			tween(ray, 1.1, { BackgroundTransparency = 1 })
		end
	end
	started = os.clock()
	while live() and not dismiss do
		local hold = if #queue > 0 then 1.5 else 2.6 + rank * 0.2
		if os.clock() - started >= hold then
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
