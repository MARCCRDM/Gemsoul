-- Your own finds, as a card above the bottom of the screen. (Other players
-- see them over your head instead: MiningWorldReveal.)
--
-- A gem rolls through a reel and lands with a flash. Beside it go its
-- rarity, element, name and worth, and Size, Clarity and Cut as bars that
-- fill once it lands. Finds that come quickly stack (LootStack):
-- - the newest gem is the card;
-- - the ones before it fold into one-line rows above it;
-- - every rock pays a gem, so the only find without one (a full pouch) is a
--   row straight away.
--
-- In a mech it sits above the driving card (MobileLayout.Drive).
--
--   MinerLoot.push(loot)        the server's loot for a rock you mined
--   MinerLoot.setBlocked(on)    a menu or a fight has the screen: hide
--   MinerLoot.close()           leaving the Outpost: clear everything
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local GemArt = require(script.Parent.GemArt)
local IronUi = require(script.Parent.IronUi)
local LootStack = require(script.Parent.LootStack)
local LotterySound = require(script.Parent.LotterySound)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

local MinerLoot = {}
local new = IronUi.new
local P = IronUi.Colors
local PANEL = Color3.fromRGB(12, 17, 28)
local TRACK = Color3.fromRGB(34, 42, 60)
local GOLD = Color3.fromRGB(255, 202, 91)
local CARD_W, CARD_H, ROW_H, GAP = 360, 124, 30, 6
local WORTH_W = 66 -- "≈ 12,500 ◆"
local WELL, CELL = 100, 84 -- the reel's window, and one gem on it
local TARGET = 14 -- the reel position the found gem sits at
local SEGMENTS = 10
local STATS = { "Size", "Clarity", "Cut" }

local gui: ScreenGui? = nil
local holder: Frame
local fitScale: UIScale
local stack = LootStack.new()
local cardUi = nil
local rows = {}
local connection: RBXScriptConnection? = nil
local views = nil -- a viewport per rarity, cloned onto the reel
local maxRows = 3
local blocked = false

local function clock(): number
	return os.clock()
end

local function tween(object: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
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

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	align: Enum.TextXAlignment?
): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		RichText = true,
		Text = value,
		TextSize = size,
		Font = IronUi.Heading,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 4,
	}, parent)
end

local function tierLabel(tier: string): string
	return string.upper(GemConfig.TierLabels[tier] or tier)
end

-- Where everything sits: the card at the bottom, rows above it (newest
-- first). On a phone or a tablet it sits above the lobby's dock (PLAY and
-- its tiles: MobileLayout.dock); a short screen keeps one row.
local function fit()
	if not gui then
		return
	end
	local size = gui.AbsoluteSize
	local mobile = UserInputService.TouchEnabled or (size.Y > 0 and size.Y < 540)
	local short = size.Y > 0 and size.Y < 500
	maxRows = if short then 1 else 3
	fitScale.Scale = if short then 0.86 else 1
	-- (In a mech: above its driving card, bottom middle.)
	local drive = MobileLayout.Drive
	local piloting = Players.LocalPlayer:GetAttribute("MechPilot") ~= nil
	local up = if piloting then drive.Bottom + drive.H + 10 elseif mobile then 104 else 64
	holder.Position = UDim2.new(0.5, 0, 1, -up)
end
Players.LocalPlayer:GetAttributeChangedSignal("MechPilot"):Connect(function()
	fit()
end)

local function rowTop(index: number): number
	local bottom = if cardUi then -GAP else CARD_H
	return bottom - ROW_H - (index - 1) * (ROW_H + GAP)
end

local function layout()
	for index, item in stack.Rows do
		local row = rows[item.Id]
		if row then
			tween(row.Frame, 0.22, { Position = UDim2.fromOffset(0, rowTop(index)) })
		end
	end
end

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	gui = UiKit.gui("MinerLoot", 7)
	gui.IgnoreGuiInset = false
	gui.Enabled = not blocked
	holder = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
	}, gui)
	fitScale = new("UIScale", { Scale = 1 }, holder)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- Rows ----------------------------------------------------------------------------------------------

local function buildRow(item)
	local loot, gem = item.Loot, item.Loot.Gem
	local color = if gem then GemConfig.TierColors[gem.Tier] or P.Text else GOLD
	local frame = new("Frame", {
		Name = "LootRow",
		Position = UDim2.fromOffset(0, CARD_H - ROW_H),
		Size = UDim2.fromOffset(CARD_W, ROW_H),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		ZIndex = 2,
	}, holder)
	UiKit.round(frame, 8)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.65 }, frame)
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color,
		Rotation = 45,
		ZIndex = 3,
	}, frame)
	UiKit.round(dot, 2)
	local left, right
	if gem then
		left = string.format(
			'<font color="#%s">%s</font>  %s',
			color:ToHex(),
			tierLabel(gem.Tier),
			GemConfig.shade(gem).Name
		)
		right = string.format("≈ %s ◆", commas(GemConfig.value(gem)))
	else
		left, right = if loot.Full then "Gem pouch full" else "Rock mined", ""
	end
	text(frame, left, 12, if loot.Full and not gem then P.Bad else P.Text, 28, 0, CARD_W - 120, ROW_H)
	text(frame, right, 12, GOLD, CARD_W - 96, 0, 84, ROW_H, Enum.TextXAlignment.Right)
	return { Frame = frame }
end

local function dropRow(row)
	local frame = row.Frame
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.25, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, 0.25, { Transparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, 0.25, { BackgroundTransparency = 1 })
		end
	end
	tween(frame, 0.25, { BackgroundTransparency = 1 }).Completed:Connect(function()
		frame:Destroy()
	end)
end

-- The card ------------------------------------------------------------------------------------------

local function rarityViews()
	if views then
		return views
	end
	views = { Folder = Instance.new("Folder") }
	for i, tier in GemConfig.TierOrder do
		views[tier] = GemArt.viewport(views.Folder, {
			Id = "loot-preview-" .. tier,
			Tier = tier,
			Element = GemConfig.Elements[(i - 1) % #GemConfig.Elements + 1],
			Size = 6,
			Clarity = 7,
			Cut = 6,
		}, false)
	end
	return views
end

local function buildCard(item)
	local loot, gem = item.Loot, item.Loot.Gem
	local frame = new("Frame", {
		Name = "LootCard",
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		ZIndex = 2,
	}, holder)
	UiKit.round(frame, 12)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.45 }, frame)
	-- (once it lands, the card takes a wash of the gem's rarity from the left)
	local wash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, frame)
	UiKit.round(wash, 12)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wash)
	local accent = new("Frame", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 0, 2),
		BackgroundColor3 = P.Edge,
		ZIndex = 3,
	}, frame)
	-- The window: a glow behind it, the reel in it, a flash when it lands.
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(12 + WELL / 2, 12 + WELL / 2),
		Size = UDim2.fromOffset(WELL + 14, WELL + 14),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.92,
		ZIndex = 2,
	}, frame)
	UiKit.round(glow, 999)
	local well = new("Frame", {
		Name = "Reel",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(WELL, WELL),
		BackgroundColor3 = Color3.fromRGB(18, 26, 40),
		ClipsDescendants = true,
		ZIndex = 3,
	}, frame)
	UiKit.round(well, 10)
	local wellEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.3 }, well)
	local punch = new("UIScale", { Scale = 1 }, well)
	local spot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.85,
		ZIndex = 3,
	}, well)
	UiKit.round(spot, 999)
	local cells = {}
	for i = 1, 5 do
		local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(WELL, CELL), ZIndex = 4 }, well)
		local art = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((WELL - 76) / 2, (CELL - 76) / 2),
			Size = UDim2.fromOffset(76, 76),
			ZIndex = 4,
		}, cell)
		cells[i] = { Frame = cell, Art = art }
	end
	-- (gems roll in and out of the light: the window darkens at top and bottom)
	local depth = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = PANEL, ZIndex = 5 }, well)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(0.78, 1),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
	}, depth)
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, well)
	-- The words, and the chart.
	local x = 12 + WELL + 14
	local w = CARD_W - x - 12
	local header = text(frame, "", 10, P.Dim, x, 12, w, 14) -- (narrows for the worth once it lands)
	local worth = text(frame, "", 12, GOLD, x + w - WORTH_W, 11, WORTH_W, 16, Enum.TextXAlignment.Right)
	local name = text(frame, "", 16, P.Text, x, 28, w, 22)
	local bars = {}
	for row, key in STATS do
		local y = 58 + (row - 1) * 20
		text(frame, string.upper(key), 9, P.Dim, x, y, 52, 14)
		local segments = {}
		for i = 1, SEGMENTS do
			local segment = new("Frame", {
				Position = UDim2.fromOffset(x + 54 + (i - 1) * 13, y + 3),
				Size = UDim2.fromOffset(11, 8),
				BackgroundColor3 = TRACK,
				ZIndex = 4,
			}, frame)
			UiKit.round(segment, 2)
			segments[i] = segment
		end
		local value = text(frame, "", 11, P.Text, x + 54 + SEGMENTS * 13 + 2, y, w - 54 - SEGMENTS * 13 - 2, 14)
		bars[key] = { Segments = segments, Value = value, Shown = -1 }
	end
	-- The reel: rarities rolled like real finds (with made-up stats for the
	-- bars to flicker through), and the found gem at TARGET.
	local rng = Random.new()
	local sequence, teases = {}, {}
	for i = 0, TARGET + 3 do
		sequence[i] = GemRoller.rollRarity(rng, 0, GemRoller.MiningWeights)
		teases[i] = { Size = rng:NextInteger(2, 9), Clarity = rng:NextInteger(2, 9), Cut = rng:NextInteger(2, 9) }
	end
	sequence[TARGET] = gem.Tier
	local folder = Instance.new("Folder")
	local winner = GemArt.viewport(folder, gem, true)
	frame.Destroying:Once(function()
		folder:Destroy()
	end)
	local ui = {
		Item = item,
		Frame = frame,
		Edge = edge,
		Wash = wash,
		Accent = accent,
		Glow = glow,
		WellEdge = wellEdge,
		Punch = punch,
		Spot = spot,
		Cells = cells,
		Flash = flash,
		Header = header,
		Worth = worth,
		Name = name,
		Bars = bars,
		Width = w,
		Sequence = sequence,
		Teases = teases,
		Winner = winner,
		Index = -1,
	}
	header.Text = "ROLLING  ·  " .. string.upper(loot.Name or "")
	return ui
end

local function paint(ui, color: Color3)
	ui.Edge.Color, ui.Accent.BackgroundColor3, ui.Glow.BackgroundColor3 = color, color, color
	ui.WellEdge.Color, ui.Spot.BackgroundColor3 = color, color:Lerp(Color3.new(1, 1, 1), 0.35)
end

-- `amount` segments lit; `final`: the gem's own number, shown beside it.
local function showBar(ui, key: string, amount: number, color: Color3, final: boolean)
	local bar = ui.Bars[key]
	amount = math.clamp(math.floor(amount), 0, SEGMENTS)
	if bar.Shown == amount and bar.Final == final then
		return
	end
	bar.Shown, bar.Final = amount, final
	for i, segment in bar.Segments do
		segment.BackgroundColor3 = if i <= amount then color else TRACK
	end
	bar.Value.Text = if final then tostring(amount) else ""
	bar.Value.TextColor3 = if amount >= SEGMENTS then GOLD else P.Text
end

-- The reel at `position` (fractional: TARGET is the found gem).
local function roll(ui, position: number, strength: number)
	local center = math.floor(position + 0.5)
	for index = center - 2, center + 2 do
		local cell = ui.Cells[index % #ui.Cells + 1]
		if cell.Index ~= index then
			cell.Index = index
			cell.Art:ClearAllChildren()
			local source = if index == TARGET then ui.Winner else rarityViews()[ui.Sequence[index] or "Common"]
			local view = source:Clone()
			view.CurrentCamera = view:FindFirstChildOfClass("Camera")
			view.Ambient, view.LightColor = Color3.fromRGB(235, 235, 245), Color3.new(1, 1, 1)
			view.ZIndex, view.Parent = 4, cell.Art
		end
		-- (later gems come in from the top)
		cell.Frame.Position = UDim2.fromOffset(0, (WELL - CELL) / 2 + (position - index) * CELL)
	end
	if ui.Index ~= center then
		ui.Index = center
		local tier = ui.Sequence[center] or "Common"
		local color = GemConfig.TierColors[tier] or P.Text
		paint(ui, color)
		ui.Name.Text = tierLabel(tier)
		ui.Name.TextColor3 = color:Lerp(PANEL, 0.25)
		local tease = ui.Teases[center] or ui.Teases[0]
		for _, key in STATS do
			showBar(ui, key, tease[key], color:Lerp(PANEL, 0.45), false)
		end
		if not blocked then -- (silent while a menu or a fight has the screen)
			LotterySound.tick(strength)
		end
	end
end

local function burst(ui, rank: number, color: Color3)
	local cx, cy = 12 + WELL / 2, 12 + WELL / 2
	for i = 1, 4 + rank * 3 do
		local angle = i * math.pi * 2 / (4 + rank * 3)
		local spark = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(3 + rank, 3 + rank),
			BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			Rotation = 45,
			ZIndex = 7,
		}, ui.Frame)
		local reach = 58 + rank * 8
		tween(spark, 0.6 + rank * 0.05, {
			Position = UDim2.fromOffset(cx + math.cos(angle) * reach, cy + math.sin(angle) * reach),
			BackgroundTransparency = 1,
			Rotation = 135,
		}).Completed:Connect(function()
			spark:Destroy()
		end)
	end
end

local function land(ui)
	local item = ui.Item
	local gem = item.Loot.Gem
	local color = GemConfig.TierColors[gem.Tier] or P.Text
	roll(ui, TARGET, 1)
	ui.Landed = true
	paint(ui, color)
	local element = GemConfig.ElementColors[gem.Element] or P.Text
	ui.Header.Text = string.format(
		'<font color="#%s">%s</font>  ·  <font color="#%s">%s</font>',
		color:ToHex(),
		tierLabel(gem.Tier),
		element:ToHex(),
		string.upper(GemConfig.elementName(gem.Element))
	)
	ui.Header.Size = UDim2.fromOffset(ui.Width - WORTH_W - 4, 14)
	ui.Name.Text = GemConfig.shade(gem).Name
	ui.Name.TextColor3 = P.Text
	ui.Worth.Text = string.format("≈ %s ◆", commas(GemConfig.value(gem)))
	for _, key in STATS do
		showBar(ui, key, 0, color, false)
	end
	-- The gem lands: a flash in the window, a punch, light swelling behind it.
	ui.Flash.BackgroundTransparency = 0.3
	tween(ui.Flash, 0.4, { BackgroundTransparency = 1 })
	ui.Punch.Scale = 1.12
	tween(ui.Punch, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	ui.Spot.BackgroundTransparency = 0.68
	ui.Glow.BackgroundTransparency = 0.82
	ui.Wash.BackgroundColor3 = color
	tween(ui.Wash, 0.5, { BackgroundTransparency = 0.84 - item.Rank * 0.02 })
	burst(ui, item.Rank, color)
	if not blocked then
		LotterySound.reveal(item.Rank)
	end
end

-- One frame of the card: rolling, or landed (the stats fill, the gem turns).
local function draw(ui, now: number)
	local item = ui.Item
	if LootStack.phase(item, now) == "Rolling" then
		local p = math.clamp((now - item.At) / (item.LandAt - item.At), 0, 1)
		roll(ui, 2 + (TARGET - 2) * (1 - (1 - p) ^ 3), p)
		return
	end
	if not ui.Landed then
		land(ui)
	end
	local gem = item.Loot.Gem
	local color = GemConfig.TierColors[gem.Tier] or P.Text
	local t = now - item.LandAt
	for row, key in STATS do
		local target = gem[key] or 0
		local amount = math.min(target, math.floor((t - 0.15 - (row - 1) * 0.15) / 0.04))
		showBar(ui, key, amount, color, amount >= target)
	end
	local model = ui.Winner:FindFirstChildOfClass("Model")
	local shown = ui.Cells[TARGET % #ui.Cells + 1].Art:FindFirstChildOfClass("ViewportFrame")
	local live = shown and shown:FindFirstChildOfClass("Model") or model
	if live then
		live:PivotTo(CFrame.new(0, math.sin(t * 2.4) * 0.08, 0) * GemArt.pose(gem, 0.6 + t * 1.2))
	end
end

-- Keeping the screen in step with the stack ---------------------------------------------------------

local step

local function sync()
	if cardUi and cardUi.Item ~= stack.Card then
		cardUi.Frame:Destroy()
		cardUi = nil
	end
	if stack.Card and not cardUi then
		cardUi = buildCard(stack.Card)
	end
	local keep = {}
	for _, item in stack.Rows do
		keep[item.Id] = true
		if not rows[item.Id] then
			rows[item.Id] = buildRow(item)
		end
	end
	for id, row in rows do
		if not keep[id] then
			dropRow(row)
			rows[id] = nil
		end
	end
	layout()
	if (cardUi or next(rows)) and not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

function step()
	local now = clock()
	if LootStack.update(stack, now, maxRows) then
		sync()
	end
	if cardUi then
		draw(cardUi, now)
	end
	if not cardUi and next(rows) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

function MinerLoot.push(loot)
	ensureGui()
	if LootStack.push(stack, loot, clock(), maxRows) then
		sync()
		step()
	end
end

function MinerLoot.setBlocked(on: boolean)
	blocked = on
	if gui then
		gui.Enabled = not on
	end
end

function MinerLoot.close()
	stack = LootStack.new()
	if cardUi then
		cardUi.Frame:Destroy()
		cardUi = nil
	end
	for id, row in rows do
		row.Frame:Destroy()
		rows[id] = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

-- For tests: what's on show.
function MinerLoot.shown()
	return { Card = cardUi and cardUi.Item, Rows = table.clone(stack.Rows) }
end

return MinerLoot
