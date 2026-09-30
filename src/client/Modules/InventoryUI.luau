--[[
	The gem pouch: a grid of gem cards tinted by rarity, and a detail panel
	with a spinning 3D model, rarity/element badges, stat bars and value.
	Also used as a picker, e.g. to choose a stone to cut:

	InventoryUI.open({
		Title = "Choose a stone to cut",
		Filter = function(gem) return gem.Cut == nil end,
		ActionText = "Cut this stone",
		OnPick = function(gem) ... end,
	})
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local K = UiKit.Colors
local P = IronUi.Colors
local HEADING = IronUi.Heading
local BODY = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold
local MAX_WIDTH = 880
local NARROW = 620 -- below this panel width the detail view covers the grid

type Options = {
	Title: string?,
	Filter: ((any) -> boolean)?,
	ActionText: string?,
	OnPick: ((any) -> ())?,
	Empty: string?,
}

local InventoryUI = {}

local current: Options? = nil
local selectedId: string? = nil
local filterTab = "All"
local sortKey = "Value"
local narrow = false
local detailOpen = false -- narrow screens show the detail view on its own

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or BODY,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 4),
	}, parent)
end

local function pill(parent: Instance, text: string, color: Color3, order: number): Frame
	local frame = new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.78,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		LayoutOrder = order,
	}, parent)
	UiKit.round(frame, 13)
	new("UIStroke", { Color = color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, frame)
	local text_ = label(frame, text, 13, Color3.new(1, 1, 1), IronUi.Chunky)
	IronUi.outline(text_, 2)
	text_.AutomaticSize = Enum.AutomaticSize.X
	text_.Size = UDim2.fromScale(0, 1)
	return frame
end

local function clearChildren(parent: Instance, keep: { [string]: boolean })
	for _, child in parent:GetChildren() do
		if not keep[child.ClassName] then
			child:Destroy()
		end
	end
end

-- Screen ------------------------------------------------------------------

local gui = UiKit.gui("GemPouch", 5)
gui.Enabled = false

local backdrop = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1),
}, gui)

-- The same crystal window as every other screen: gold rim, dark body,
-- a glossy gradient header bar.
local panel = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1) }, gui)
UiKit.round(panel, 16)
new("UIStroke", { Color = P.Gold, Thickness = 4 }, panel)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 26, 48), P.Frame) }, panel)
local headerBar = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(5, 5),
	Size = UDim2.new(1, -10, 0, 66),
}, panel)
UiKit.round(headerBar, 12)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, IronUi.lighter(P.Amethyst, 0.1)),
		ColorSequenceKeypoint.new(0.6, IronUi.darker(P.Amethyst, 0.25)),
		ColorSequenceKeypoint.new(1, IronUi.darker(P.Teal, 0.3)),
	}),
}, headerBar)
local headerGloss = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.82,
	Position = UDim2.fromOffset(8, 4),
	Size = UDim2.new(1, -16, 0, 10),
}, headerBar)
UiKit.round(headerGloss, 5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.86)
panel.ClipsDescendants = true
new("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, 600) }, panel)
local panelScale = new("UIScale", { Scale = 1 }, panel)

-- Header: title, balance pills, close.
local header = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 58),
}, panel)
local title = label(header, "GEM POUCH", 28, Color3.new(1, 1, 1), HEADING)
IronUi.outline(title, 3)
title.Size = UDim2.new(0.5, 0, 0, 30)
local subtitle = label(header, "", 13, Color3.fromRGB(240, 230, 255), BOLD)
subtitle.Position = UDim2.fromOffset(0, 32)
subtitle.Size = UDim2.new(0.5, 0, 0, 18)
subtitle.TextTruncate = Enum.TextTruncate.AtEnd

local pills = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -56, 0, 8),
	Size = UDim2.new(0.5, 0, 0, 52),
}, header)
local pillLayout = UiKit.list(pills, 6, true)
pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
pillLayout.Wraps = true

local closeButton, closeFace = IronUi.chunk(header, {
	Color = Color3.fromRGB(232, 58, 58),
	Size = UDim2.fromOffset(44, 44),
	Radius = 12,
	Lip = 5,
	Stripes = "None",
})
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 4, 0, 0)
IronUi.label(closeButton, closeFace, "X", 22, HEADING)

-- Toolbar: filter tabs on the left, sort tabs on the right.
local toolbar = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 80),
	Size = UDim2.new(1, -32, 0, 40),
}, panel)
local filters = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.42, 0, 1, 0) }, toolbar)
UiKit.list(filters, 6, true)
local sorts = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.58, 0, 1, 0),
}, toolbar)
UiKit.list(sorts, 6, true).HorizontalAlignment = Enum.HorizontalAlignment.Right

-- Body: the card grid and the detail panel.
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 130),
	Size = UDim2.new(1, -32, 1, -144),
}, panel)
local grid = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = P.Gold,
	Size = UDim2.new(1, -300, 1, 0),
}, body)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(112, 146),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, grid)

local emptyLabel = label(body, "", 15, K.Dim)
emptyLabel.Size = UDim2.new(1, -310, 0, 60)
emptyLabel.TextWrapped = true
emptyLabel.TextYAlignment = Enum.TextYAlignment.Top
emptyLabel.Visible = false

local detail = new("Frame", {
	BackgroundColor3 = P.Inset,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 286, 1, 0),
}, body)
UiKit.round(detail, 10)
local detailStroke = new("UIStroke", { Color = P.Gold, Thickness = 3 }, detail)

-- Close-up: a neutral studio backdrop with the stone in a viewport on top.
local stageFrame = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Size = UDim2.new(1, 0, 0, 180),
	ClipsDescendants = true,
}, detail)
UiKit.round(stageFrame, 10)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(74, 84, 100), Color3.fromRGB(16, 20, 26)),
}, stageFrame)
GemArt.backdrop(stageFrame)
local viewport = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,
}, stageFrame)
local viewportCamera = GemArt.setupViewport(viewport)

local info = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 186),
	Size = UDim2.new(1, 0, 1, -186),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, detail)
UiKit.pad(info, 12)
UiKit.list(info, 8)

local backButton, backFace = IronUi.chunk(detail, {
	Color = Color3.fromRGB(88, 80, 112),
	Rim = Color3.fromRGB(170, 162, 196),
	Size = UDim2.fromOffset(86, 36),
	Radius = 10,
	Lip = 4,
	Stripes = "None",
})
backButton.Position = UDim2.fromOffset(8, 8)
backButton.ZIndex = 5
backButton.Visible = false
IronUi.label(backButton, backFace, "< Back", 14)

-- Detail view -------------------------------------------------------------------

local spinning: Model? = nil
local spinningGem = nil

local function statBar(name: string, value: number?, color: Color3, order: number)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order }, info)
	local caption = label(row, name, 12, K.Dim, BOLD)
	caption.Size = UDim2.new(0, 64, 1, 0)
	local cells = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 4),
		Size = UDim2.new(1, -98, 0, 12),
	}, row)
	UiKit.list(cells, 3, true)
	for i = 1, 10 do
		local cell = new("Frame", {
			BackgroundColor3 = if value and i <= value then color else Color3.fromRGB(48, 42, 64),
			Size = UDim2.new(0.1, -3, 1, 0),
			LayoutOrder = i,
		}, cells)
		UiKit.round(cell, 3)
	end
	local number = label(row, if value then tostring(value) else "--", 14, K.Text, BOLD)
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.fromScale(1, 0)
	number.Size = UDim2.new(0, 28, 1, 0)
	number.TextXAlignment = Enum.TextXAlignment.Right
end

local function showDetail(gem)
	clearChildren(info, { UIPadding = true, UIListLayout = true })
	if spinning then
		spinning:Destroy()
		spinning = nil
		spinningGem = nil
	end
	if not gem then
		label(info, "Select a gem to see it up close.", 15, K.Dim).TextWrapped = true
		detailStroke.Color = P.Gold
		return
	end

	local shade = GemConfig.shade(gem)
	local tierColor = GemConfig.TierColors[gem.Tier]
	detailStroke.Color = tierColor

	local model, radius = GemArt.model(gem, true)
	viewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, GemArt.detailDistance(radius)), Vector3.zero)
	model:PivotTo(GemArt.pose(gem, 0))
	model.Parent = viewport
	spinning = model
	spinningGem = gem

	local name = label(info, shade.Name, 20, Color3.new(1, 1, 1), IronUi.Chunky)
	IronUi.outline(name, 2)
	name.TextWrapped = true
	name.AutomaticSize = Enum.AutomaticSize.Y
	name.LayoutOrder = 1

	local badges = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, info)
	UiKit.list(badges, 6, true).Wraps = true
	pill(badges, string.upper(GemConfig.TierLabels[gem.Tier]), tierColor, 1)
	pill(badges, string.upper(gem.Element), GemConfig.ElementColors[gem.Element], 2)
	local state = if not gem.Cut then "ROUGH" elseif gem.Cut >= 10 then "GEM MINT" else "CUT " .. gem.Cut
	pill(badges, state, if gem.Cut and gem.Cut >= 10 then K.Gold else K.Text, 3)

	statBar("SIZE", gem.Size, tierColor, 3)
	statBar("CLARITY", gem.Clarity, tierColor, 4)
	statBar("CUT", gem.Cut, K.Gold, 5)

	local value = label(info, "💰 " .. commas(GemConfig.value(gem)), 24, P.Gold, IronUi.Chunky)
	IronUi.outline(value, 2)
	value.LayoutOrder = 6
	if not gem.Cut then
		local asCut = table.clone(gem)
		asCut.Cut = 8
		local good = GemConfig.value(asCut)
		asCut.Cut = 10
		local mint = GemConfig.value(asCut)
		local hint = label(info, string.format("Cut to 8: %s  |  Gem Mint: %s", commas(good), commas(mint)), 12, K.Dim)
		hint.LayoutOrder = 7
	end
	local origin = GemConfig.SourceLabels[gem.Source] or gem.Source
	if gem.Found and gem.Found > 0 then
		origin ..= ", " .. DateTime.fromUnixTimestamp(gem.Found):FormatLocalTime("MMM D", "en-us")
	end
	local found = label(info, origin, 12, K.Dim)
	found.LayoutOrder = 8

	local options = current
	if options and options.OnPick then
		local pick = options.OnPick
		local button = IronUi.gemButton(info, string.upper(options.ActionText or "Choose"), P.Emerald, function()
			InventoryUI.close()
			pick(gem)
		end)
		button.AutomaticSize = Enum.AutomaticSize.None
		button.Size = UDim2.new(1, 0, 0, 50)
		button.LayoutOrder = 9
	end
end

-- Grid ------------------------------------------------------------------------

-- Card stages still waiting for their 3D stone.
local pending: { [Frame]: any } = {}

local function buildVisibleStones()
	local top = grid.AbsolutePosition.Y - 150
	local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y + 150
	for stage, gem in pending do
		if not stage.Parent then
			pending[stage] = nil
		elseif stage.AbsolutePosition.Y < bottom and stage.AbsolutePosition.Y + stage.AbsoluteSize.Y > top then
			pending[stage] = nil
			GemArt.viewport(stage, gem, false)
		end
	end
end

local SORTS = {
	Value = function(a, b)
		return GemConfig.value(a) > GemConfig.value(b)
	end,
	Rarity = function(a, b)
		local ra, rb = GemConfig.TierRank[a.Tier], GemConfig.TierRank[b.Tier]
		if ra ~= rb then
			return ra > rb
		end
		return GemConfig.value(a) > GemConfig.value(b)
	end,
	Size = function(a, b)
		if a.Size ~= b.Size then
			return a.Size > b.Size
		end
		return GemConfig.value(a) > GemConfig.value(b)
	end,
	Newest = function(a, b)
		return (a.Found or 0) > (b.Found or 0)
	end,
}

local FILTERS = {
	All = function()
		return true
	end,
	Rough = function(gem)
		return gem.Cut == nil
	end,
	Cut = function(gem)
		return gem.Cut ~= nil
	end,
}

local function card(gem, order: number)
	local shade = GemConfig.shade(gem)
	local tierColor = GemConfig.TierColors[gem.Tier]
	local selected = gem.Id == selectedId
	-- A dark slab so the stone's own colour stands out; rarity shows in the
	-- rim and the label, and the selected card gets a gold outline.
	local button, face = IronUi.chunk(grid, {
		Color = Color3.fromRGB(40, 36, 54),
		Rim = if selected then P.Gold else tierColor,
		Radius = 12,
		Lip = 5,
		Stripes = "None",
	})
	button.LayoutOrder = order
	local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
	if selected then
		stroke.Thickness = 4
	end
	if gem.Tier == "UltraRare" then
		-- A shimmer running around the outline.
		stroke.Color = Color3.new(1, 1, 1)
		local shimmer = new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, tierColor),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 230, 255)),
				ColorSequenceKeypoint.new(1, tierColor),
			}),
		}, stroke)
		TweenService:Create(shimmer, TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = 360,
		}):Play()
	end

	-- The 3D stone is built when the card first scrolls into view.
	local stage = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(92, 70),
	}, face)
	GemArt.backdrop(stage)
	pending[stage] = gem

	local rarityText = if gem.Tier == "UltraRare" then "ULTRA" else string.upper(GemConfig.TierLabels[gem.Tier])
	local rarity = label(face, rarityText, 10, tierColor, BOLD)
	rarity.AnchorPoint = Vector2.new(1, 0)
	rarity.Position = UDim2.new(1, -8, 0, 6)
	rarity.Size = UDim2.new(0.6, 0, 0, 12)
	rarity.TextXAlignment = Enum.TextXAlignment.Right

	local state = if not gem.Cut then "ROUGH" elseif gem.Cut >= 10 then "MINT" else "CUT " .. gem.Cut
	local tag = label(face, state, 10, if gem.Cut then K.Gold else K.Dim, BOLD)
	tag.Position = UDim2.fromOffset(8, 6)
	tag.Size = UDim2.new(1, -16, 0, 12)

	local name = label(face, shade.Name, 12, Color3.new(1, 1, 1), IronUi.Chunky)
	IronUi.outline(name, 1.5)
	name.Position = UDim2.fromOffset(4, 86)
	name.Size = UDim2.new(1, -8, 0, 30)
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local value = label(face, "💰 " .. commas(GemConfig.value(gem)), 13, P.Gold, IronUi.Chunky)
	IronUi.outline(value, 1.5)
	value.Position = UDim2.new(0, 6, 1, -20)
	value.Size = UDim2.new(1, -12, 0, 16)
	value.TextXAlignment = Enum.TextXAlignment.Center

	button.Activated:Connect(function()
		selectedId = gem.Id
		detailOpen = true
		InventoryUI.refresh()
	end)
end

local function tabs(parent: Instance, names: { string }, active: string, onPick: (string) -> ())
	clearChildren(parent, { UIListLayout = true })
	for i, name in names do
		local on = name == active
		local tab, face = IronUi.chunk(parent, {
			Color = if on then P.Amethyst else Color3.fromRGB(52, 46, 68),
			Rim = if on then Color3.fromRGB(214, 180, 255) else Color3.fromRGB(96, 88, 120),
			Size = UDim2.fromOffset(0, if on then 38 else 34),
			Radius = 10,
			Lip = if on then 5 else 4,
			PadX = 12,
			Stripes = if on then "Thin" else "None",
		})
		tab.LayoutOrder = i
		local text_ = IronUi.label(tab, face, name, 13)
		if not on then
			text_.TextColor3 = Color3.fromRGB(196, 186, 220)
		end
		tab.Activated:Connect(function()
			onPick(name)
		end)
	end
end

-- Wide screens show grid and detail side by side; narrow ones show one at a time.
local function layout()
	local width = math.min(gui.AbsoluteSize.X * 0.94, MAX_WIDTH)
	narrow = width < NARROW
	if narrow then
		grid.Size = UDim2.fromScale(1, 1)
		detail.Size = UDim2.fromScale(1, 1)
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		detail.Visible = detailOpen
		grid.Visible = not detailOpen
		backButton.Visible = true
	else
		grid.Size = UDim2.new(1, -300, 1, 0)
		detail.Size = UDim2.new(0, 286, 1, 0)
		emptyLabel.Size = UDim2.new(1, -310, 0, 60)
		detail.Visible = true
		grid.Visible = true
		backButton.Visible = false
	end
	pills.Visible = width >= 560
end

function InventoryUI.refresh()
	local options = current
	if not options then
		return
	end
	layout()
	title.Text = if options.OnPick then "CHOOSE A GEM" else "GEM POUCH"
	subtitle.Text = options.Title or "Your collection"

	clearChildren(pills, { UIListLayout = true })
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(pending)

	local profile = GemClient.Profile
	if not profile then
		emptyLabel.Text = "Loading..."
		emptyLabel.Visible = true
		showDetail(nil)
		return
	end
	local quota = profile.Quota
	pill(pills, commas(profile.Coins) .. " COINS", K.Gold, 1)
	pill(pills, string.format("%d / %d GEMS", #profile.Gems, Config.MaxGems), Color3.fromRGB(190, 120, 255), 2)
	pill(
		pills,
		string.format("FREE MINES %d/%d", math.max(0, profile.DailyQuota - quota.UsedToday), profile.DailyQuota),
		K.Text,
		3
	)

	if options.Filter then
		clearChildren(filters, { UIListLayout = true })
	else
		tabs(filters, { "All", "Rough", "Cut" }, filterTab, function(name)
			filterTab = name
			InventoryUI.refresh()
		end)
	end
	tabs(sorts, { "Value", "Rarity", "Size", "Newest" }, sortKey, function(name)
		sortKey = name
		InventoryUI.refresh()
	end)

	local gems = {}
	for _, gem in profile.Gems do
		local keep = if options.Filter then options.Filter(gem) else FILTERS[filterTab](gem)
		if keep then
			table.insert(gems, gem)
		end
	end
	table.sort(gems, SORTS[sortKey])

	-- Keep the selection if it's still listed; on wide screens default to the top gem.
	local selected = nil
	for _, gem in gems do
		if gem.Id == selectedId then
			selected = gem
		end
	end
	if not selected and not narrow then
		selected = gems[1]
	end
	selectedId = selected and selected.Id
	if not selected then
		detailOpen = false
		layout()
	end

	for i, gem in gems do
		card(gem, i)
	end
	emptyLabel.Visible = #gems == 0
	emptyLabel.Text = options.Empty or "No gems yet. Mine some in the quarry up the north road!"
	showDetail(selected)
	-- Positions settle after layout, so build the visible stones next frame.
	task.defer(buildVisibleStones)
end

function InventoryUI.open(options: Options?)
	current = options or {}
	selectedId = nil
	detailOpen = false
	filterTab = "All"
	gui.Enabled = true
	InventoryUI.refresh()
	panelScale.Scale = 0.94
	TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function InventoryUI.close()
	current = nil
	gui.Enabled = false
	table.clear(pending)
	if spinning then
		spinning:Destroy()
		spinning = nil
		spinningGem = nil
	end
end

function InventoryUI.toggle()
	if gui.Enabled then
		InventoryUI.close()
	else
		InventoryUI.open()
	end
end

closeButton.Activated:Connect(InventoryUI.close)
backdrop.Activated:Connect(InventoryUI.close)
backButton.Activated:Connect(function()
	detailOpen = false
	InventoryUI.refresh()
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if current then
		InventoryUI.refresh()
	end
end)
GemClient.Changed:Connect(function()
	if current then
		InventoryUI.refresh()
	end
end)

grid:GetPropertyChangedSignal("CanvasPosition"):Connect(buildVisibleStones)

RunService.RenderStepped:Connect(function()
	if spinning and spinningGem and gui.Enabled then
		spinning:PivotTo(GemArt.pose(spinningGem, os.clock() * 0.8))
	end
end)

return InventoryUI
