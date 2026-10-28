-- Your own finds, as a card in the bottom right of the screen (the top
-- right on a phone). (Other players see them over your head instead:
-- MiningWorldReveal.)
--
-- A gem rolls through a reel and lands with a flash. Beside it go its
-- rarity, element, name and worth, and Size, Clarity and Cut as bars that
-- fill once it lands. Finds that come quickly stack (LootStack):
-- - the newest gem is the card;
-- - the ones before it fold into one-line rows above it (two at most);
-- - every rock pays a gem, so the only find without one (a full pouch) is a
--   row straight away.
--
-- On a phone or a tablet it's slim and sits in the top right, under the
-- toast's place (MobileLayout.loot; lower while a toast wraps): the reel,
-- then the rarity, the gem's name and its worth one under another, no bars,
-- and one row under it, so the middle of the screen (you, your kaiju,
-- what's coming) and the dock stay clear; the live feed steps aside while
-- it's up (MobileLayout.claimTop). On a computer it's compact, in the
-- bottom right corner above the key hints, clear of the middle of the
-- screen, the RIFT CHARGED tag (FrontierHud) and a mech's HOP OUT; where a short
-- window leaves no room above it, its row waits until it's gone.
--
--   MinerLoot.push(loot)        the server's loot for a rock you mined
--   MinerLoot.setBlocked(on)    a menu or a fight has the screen: hide
--   MinerLoot.close()           leaving the Outpost: clear everything
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
local GAP = 6
-- The card's sizes: W x H, a row's height, the reel's window (Well) and one
-- gem on it (Cell, its art Art), the words' places, and whether the Size,
-- Clarity and Cut bars show (where: BarY, a bar every BarStep, its label
-- BarLabelW wide, segments SegW x SegH every SegStep). Desk (a computer) is
-- compact, for the corner; Slim (a phone) is as wide as fits up there.
local DESK = {
	Slim = false,
	W = 320,
	H = 108,
	Row = 26,
	Pad = 8,
	Well = 92,
	Cell = 80,
	Art = 72,
	Spot = 68,
	Bars = true,
	Gap = 10,
	HeaderY = 7,
	HeaderH = 14,
	Small = 11,
	WorthY = 6,
	WorthH = 14,
	WorthW = 58,
	Worth = 11,
	NameY = 23,
	NameH = 22,
	Name = 16,
	BarY = 49,
	BarStep = 17,
	BarLabelW = 48,
	BarText = 10,
	SegW = 8,
	SegH = 6,
	SegStep = 10,
	RowText = 11,
	RowWorthW = 72,
	WorthBelow = false,
}
local SLIM = {
	Slim = true,
	W = MobileLayout.Loot.W,
	H = MobileLayout.Loot.H,
	Row = MobileLayout.Loot.Row,
	Pad = 6,
	Well = 60,
	Cell = 56,
	Art = 50,
	Spot = 46,
	Bars = false,
	Gap = 8,
	HeaderY = 6,
	HeaderH = 14,
	Small = 11,
	WorthY = 49,
	WorthH = 16,
	WorthW = 54,
	Worth = 13,
	NameY = 24,
	NameH = 20,
	Name = 15,
	RowText = 11,
	RowWorthW = 60,
	WorthBelow = true, -- (a line of its own, under the name: the card's narrow)
}
local D = DESK -- (the sizes now: a card keeps the ones it was built with)
-- On a computer, the corner it sits in: Right and Bottom from the screen's
-- edges (above the key hints: OutpostScene), and rows above it no higher
-- than Below past the middle of the screen (well clear of the RIFT CHARGED
-- tag just under it: FrontierHud).
MinerLoot.Corner = { Right = 16, Bottom = 56, Below = 104 }
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
local views = nil -- a viewport per rarity and element, cloned onto the reel
local maxRows = 2
local rowsWait = false -- (no room for a row beside the card: it waits until the card's gone)
local blocked = false
local sync: () -> ()
local layout: () -> ()

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

-- The top is the loot card's while it (or its row) is up on a phone.
local function claim()
	MobileLayout.claimTop("MinerLoot", D.Slim and not blocked and (cardUi ~= nil or next(rows) ~= nil))
end

-- Built again at new sizes (a phone turned, a window resized): the stack
-- says what's on show, so nothing is lost.
local function rebuild()
	if cardUi then
		cardUi.Frame:Destroy()
		cardUi = nil
	end
	for id, row in rows do
		row.Frame:Destroy()
		rows[id] = nil
	end
	if sync and (stack.Card or #stack.Rows > 0) then
		sync()
	end
end

-- Where everything sits. On a computer: compact, in the bottom right corner
-- (MinerLoot.Corner), rows above it (newest first, as many as fit below the
-- RIFT CHARGED tag, two at most). On a phone or a tablet (touch, or a short
-- window): slim, in the top right under your health and teammates' rows
-- (MobileLayout.loot; under a toast there too), one row under it. Where no
-- row fits beside the card, it shows once the card's gone.
local function fit()
	if not gui then
		return
	end
	local size = gui.AbsoluteSize
	local mobile = UiKit.handheld(size)
	local spot = if mobile then MobileLayout.loot(size) else nil
	local dims = DESK
	if spot then
		dims = table.clone(SLIM)
		dims.W = spot.W
	end
	if dims.W ~= D.W or dims.H ~= D.H or dims.Slim ~= D.Slim then
		D = dims
		rebuild()
	end
	fitScale.Scale = 1
	holder.Size = UDim2.fromOffset(D.W, D.H)
	if spot then
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.fromOffset(spot.X, math.max(spot.Y, UiKit.toastBottom() + MobileLayout.Loot.Gap))
		maxRows, rowsWait = 1, not spot.RowsBelow
	else
		-- (Clear of a mech's HOP OUT, which is bottom middle.)
		local corner = MinerLoot.Corner
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -corner.Right, 1, -corner.Bottom)
		local room = (size.Y - corner.Bottom - D.H) - (size.Y / 2 + corner.Below)
		local fits = math.floor(room / (D.Row + GAP))
		maxRows, rowsWait = math.clamp(fits, 1, 2), fits < 1
	end
	layout()
	claim()
end

local function rowTop(index: number): number
	if D.Slim then
		-- (under the card, or where it was)
		local top = if cardUi then D.H + GAP else 0
		return top + (index - 1) * (D.Row + GAP)
	end
	local bottom = if cardUi then -GAP else D.H
	return bottom - D.Row - (index - 1) * (D.Row + GAP)
end

function layout()
	-- (No room for a row above the card, a short window's: the row waits
	-- while a card's up.)
	local hide = rowsWait and cardUi ~= nil
	for index, item in stack.Rows do
		local row = rows[item.Id]
		if row then
			row.Frame.Visible = not hide
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
		Size = UDim2.fromOffset(D.W, D.H),
		BackgroundTransparency = 1,
	}, gui)
	fitScale = new("UIScale", { Scale = 1 }, holder)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UiKit.onToastMoved(fit)
	MobileLayout.onParty(fit) -- (your teammates' rows above it come and go)
	fit()
end

-- Rows ----------------------------------------------------------------------------------------------

local function buildRow(item)
	local loot, gem = item.Loot, item.Loot.Gem
	local color = if gem then GemConfig.TierColors[gem.Tier] or P.Text else GOLD
	local frame = new("Frame", {
		Name = "LootRow",
		Position = UDim2.fromOffset(0, if D.Slim then rowTop(1) else D.H - D.Row),
		Size = UDim2.fromOffset(D.W, D.Row),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		ZIndex = 2,
	}, holder)
	UiKit.round(frame, 8)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.65 }, frame)
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, D.Pad, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = color,
		Rotation = 45,
		ZIndex = 3,
	}, frame)
	UiKit.round(dot, 2)
	local left, right
	if gem and D.Slim then
		-- (no room for the rarity's name: the name and the dot wear its colour)
		left = string.format('<font color="#%s">%s</font>', color:ToHex(), GemConfig.shade(gem).Name)
		right = string.format("≈ %s ◆", commas(GemConfig.value(gem)))
	elseif gem then
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
	local rightX = D.W - D.RowWorthW - D.Pad
	local leftX = D.Pad + 16
	text(frame, left, D.RowText, if loot.Full and not gem then P.Bad else P.Text, leftX, 0, rightX - leftX - 4, D.Row)
	text(frame, right, D.RowText, GOLD, rightX, 0, D.RowWorthW, D.Row, Enum.TextXAlignment.Right)
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

-- A reel gem's art: each rarity in each element, built the first time the
-- reel needs it (every element turns up at every rarity, as in real finds).
local function rarityView(tier: string, element: string)
	if not views then
		views = { Folder = Instance.new("Folder") }
	end
	local key = tier .. "/" .. element
	if not views[key] then
		views[key] = GemArt.viewport(views.Folder, {
			Id = "loot-preview-" .. key,
			Tier = tier,
			Element = element,
			Size = 6,
			Clarity = 7,
			Cut = 6,
		}, false)
	end
	return views[key]
end

local function buildCard(item)
	local loot, gem = item.Loot, item.Loot.Gem
	local d = D
	local frame = new("Frame", {
		Name = "LootCard",
		Size = UDim2.fromOffset(d.W, d.H),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		ZIndex = 2,
	}, holder)
	UiKit.round(frame, if d.Slim then 10 else 12)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.45 }, frame)
	-- (once it lands, the card takes a wash of the gem's rarity from the left)
	local wash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, frame)
	UiKit.round(wash, if d.Slim then 10 else 12)
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
		Position = UDim2.fromOffset(d.Pad + d.Well / 2, d.Pad + d.Well / 2),
		Size = UDim2.fromOffset(d.Well + d.Pad + 2, d.Well + d.Pad + 2),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.92,
		ZIndex = 2,
	}, frame)
	UiKit.round(glow, 999)
	local well = new("Frame", {
		Name = "Reel",
		Position = UDim2.fromOffset(d.Pad, d.Pad),
		Size = UDim2.fromOffset(d.Well, d.Well),
		BackgroundColor3 = Color3.fromRGB(18, 26, 40),
		ClipsDescendants = true,
		ZIndex = 3,
	}, frame)
	UiKit.round(well, if d.Slim then 8 else 10)
	local wellEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.3 }, well)
	local punch = new("UIScale", { Scale = 1 }, well)
	local spot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(d.Spot, d.Spot),
		BackgroundColor3 = P.Edge,
		BackgroundTransparency = 0.85,
		ZIndex = 3,
	}, well)
	UiKit.round(spot, 999)
	local cells = {}
	for i = 1, 5 do
		local cell =
			new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(d.Well, d.Cell), ZIndex = 4 }, well)
		local art = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((d.Well - d.Art) / 2, (d.Cell - d.Art) / 2),
			Size = UDim2.fromOffset(d.Art, d.Art),
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
	-- The words, and the chart (in full).
	local x = d.Pad + d.Well + d.Gap
	local w = d.W - x - d.Pad
	local header = text(frame, "", d.Small, P.Dim, x, d.HeaderY, w, d.HeaderH) -- (narrows for the worth once it lands)
	-- (slim, the worth is a line of its own under the name; else right of the rarity)
	local worthX, worthW = if d.WorthBelow then x else x + w - d.WorthW, if d.WorthBelow then w else d.WorthW
	local align = if d.WorthBelow then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	local worth = text(frame, "", d.Worth, GOLD, worthX, d.WorthY, worthW, d.WorthH, align)
	local name = text(frame, "", d.Name, P.Text, x, d.NameY, w, d.NameH)
	local bars = {}
	for row, key in if d.Bars then STATS else {} do
		local y = d.BarY + (row - 1) * d.BarStep
		local line = d.BarStep - 1
		text(frame, string.upper(key), d.BarText, P.Dim, x, y, d.BarLabelW, line)
		local segments = {}
		for i = 1, SEGMENTS do
			local segment = new("Frame", {
				Name = "Segment",
				Position = UDim2.fromOffset(x + d.BarLabelW + (i - 1) * d.SegStep, y + (line - d.SegH) / 2),
				Size = UDim2.fromOffset(d.SegW, d.SegH),
				BackgroundColor3 = TRACK,
				ZIndex = 4,
			}, frame)
			UiKit.round(segment, 2)
			segments[i] = segment
		end
		local after = d.BarLabelW + SEGMENTS * d.SegStep + 2
		local value = text(frame, "", d.BarText + 2, P.Text, x + after, y, w - after, line)
		bars[key] = { Segments = segments, Value = value, Shown = -1 }
	end
	-- The reel: rarities rolled like real finds (with made-up stats for the
	-- bars to flicker through), and the found gem at TARGET.
	local rng = Random.new()
	local sequence, elements, teases = {}, {}, {}
	for i = 0, TARGET + 3 do
		local passing = GemRoller.reelGem(rng, GemRoller.MiningWeights)
		sequence[i], elements[i] = passing.Tier, passing.Element
		teases[i] = { Size = rng:NextInteger(2, 9), Clarity = rng:NextInteger(2, 9), Cut = rng:NextInteger(2, 9) }
	end
	sequence[TARGET], elements[TARGET] = gem.Tier, gem.Element
	local folder = Instance.new("Folder")
	local winner = GemArt.viewport(folder, gem, true)
	frame.Destroying:Once(function()
		folder:Destroy()
	end)
	local ui = {
		Item = item,
		D = d,
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
		Elements = elements,
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
	if not bar then
		return -- (slim: no bars)
	end
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
			local source = if index == TARGET
				then ui.Winner
				else rarityView(ui.Sequence[index] or "Common", ui.Elements[index] or ui.Item.Loot.Gem.Element)
			local view = source:Clone()
			view.CurrentCamera = view:FindFirstChildOfClass("Camera")
			view.Ambient, view.LightColor = Color3.fromRGB(235, 235, 245), Color3.new(1, 1, 1)
			view.ZIndex, view.Parent = 4, cell.Art
		end
		-- (later gems come in from the top)
		cell.Frame.Position = UDim2.fromOffset(0, (ui.D.Well - ui.D.Cell) / 2 + (position - index) * ui.D.Cell)
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
	local d = ui.D
	local cx, cy = d.Pad + d.Well / 2, d.Pad + d.Well / 2
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
		local reach = (58 + rank * 8) * d.Well / 100
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
	-- (Room for the worth beside the rarity in full; slim, it's under the name.)
	if not ui.D.WorthBelow then
		ui.Header.Size = UDim2.fromOffset(ui.Width - ui.D.WorthW - 4, ui.D.HeaderH)
	end
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

function sync()
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
	claim()
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
	claim()
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
	claim()
end

-- For tests: what's on show.
function MinerLoot.shown()
	return { Card = cardUi and cardUi.Item, Rows = table.clone(stack.Rows) }
end

return MinerLoot
