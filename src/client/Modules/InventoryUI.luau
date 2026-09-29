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
local UiKit = require(script.Parent.UiKit)

local K = UiKit.Colors
local HEADING = Enum.Font.Arcade
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
		BackgroundTransparency = 0.82,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = order,
	}, parent)
	UiKit.round(frame, 12)
	new("UIStroke", { Color = color, Transparency = 0.4, Thickness = 1 }, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, frame)
	local text_ = label(frame, text, 12, color, BOLD)
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

local panel = UiKit.panel(gui)
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
local title = label(header, "GEM POUCH", 24, K.Accent, HEADING)
title.Size = UDim2.new(0.5, 0, 0, 28)
local subtitle = label(header, "", 14, K.Dim)
subtitle.Position = UDim2.fromOffset(0, 32)
subtitle.Size = UDim2.new(0.5, 0, 0, 18)
subtitle.TextTruncate = Enum.TextTruncate.AtEnd

local pills = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -48, 0, 4),
	Size = UDim2.new(0.5, 0, 0, 52),
}, header)
local pillLayout = UiKit.list(pills, 6, true)
pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
pillLayout.Wraps = true

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 2),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = K.Row,
	Text = "X",
	Font = BOLD,
	TextSize = 18,
	TextColor3 = K.Bad,
}, header)
UiKit.round(closeButton, 18)

-- Toolbar: filter tabs on the left, sort tabs on the right.
local toolbar = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 76),
	Size = UDim2.new(1, -32, 0, 30),
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
	Position = UDim2.fromOffset(16, 116),
	Size = UDim2.new(1, -32, 1, -130),
}, panel)
local grid = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = K.Accent,
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
	BackgroundColor3 = Color3.fromRGB(14, 22, 20),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 286, 1, 0),
}, body)
UiKit.round(detail, 10)
local detailStroke = new("UIStroke", { Color = K.Accent, Transparency = 0.5, Thickness = 1.5 }, detail)

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

local backButton = new("TextButton", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(74, 28),
	BackgroundColor3 = K.Row,
	Text = "< Back",
	Font = BOLD,
	TextSize = 14,
	TextColor3 = K.Text,
	ZIndex = 5,
	Visible = false,
}, detail)
UiKit.round(backButton, 14)

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
			BackgroundColor3 = if value and i <= value then color else Color3.fromRGB(40, 50, 48),
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
		detailStroke.Color = K.Accent
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

	local name = label(info, shade.Name, 18, K.Text, BOLD)
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

	local value = label(info, commas(GemConfig.value(gem)) .. " coins", 22, K.Gold, BOLD)
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
		local button = new("TextButton", {
			BackgroundColor3 = K.Accent,
			Size = UDim2.new(1, 0, 0, 40),
			Text = string.upper(options.ActionText or "Choose"),
			Font = BOLD,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(6, 20, 24),
			LayoutOrder = 9,
		}, info)
		UiKit.round(button, 8)
		button.Activated:Connect(function()
			InventoryUI.close()
			pick(gem)
		end)
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
	local button = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
	}, grid)
	UiKit.round(button, 10)
	-- Neutral card so the stone's own colour stands out; rarity shows in the
	-- border and the label.
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(38, 44, 52), Color3.fromRGB(20, 24, 30)),
	}, button)
	local stroke = new("UIStroke", {
		Color = tierColor,
		Transparency = if selected then 0 else 0.55,
		Thickness = if selected then 3 else 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	if gem.Tier == "UltraRare" then
		-- A shimmer running around the border.
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0
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
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(92, 72),
	}, button)
	GemArt.backdrop(stage)
	pending[stage] = gem

	local rarityText = if gem.Tier == "UltraRare" then "ULTRA" else string.upper(GemConfig.TierLabels[gem.Tier])
	local rarity = label(button, rarityText, 10, tierColor, BOLD)
	rarity.AnchorPoint = Vector2.new(1, 0)
	rarity.Position = UDim2.new(1, -8, 0, 6)
	rarity.Size = UDim2.new(0.6, 0, 0, 12)
	rarity.TextXAlignment = Enum.TextXAlignment.Right

	local state = if not gem.Cut then "ROUGH" elseif gem.Cut >= 10 then "MINT" else "CUT " .. gem.Cut
	local tag = label(button, state, 10, if gem.Cut then K.Gold else K.Dim, BOLD)
	tag.Position = UDim2.fromOffset(8, 6)
	tag.Size = UDim2.new(1, -16, 0, 12)

	local name = label(button, shade.Name, 12, K.Text, BOLD)
	name.Position = UDim2.fromOffset(6, 92)
	name.Size = UDim2.new(1, -12, 0, 30)
	name.TextWrapped = true
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local value = label(button, commas(GemConfig.value(gem)), 13, K.Gold, BOLD)
	value.Position = UDim2.new(0, 6, 1, -22)
	value.Size = UDim2.new(1, -12, 0, 16)
	value.TextXAlignment = Enum.TextXAlignment.Center

	if gem.Tier ~= "UltraRare" and not selected then
		button.MouseEnter:Connect(function()
			stroke.Transparency = 0.15
		end)
		button.MouseLeave:Connect(function()
			stroke.Transparency = 0.55
		end)
	end
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
		local tab = new("TextButton", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			BackgroundColor3 = if on then K.Accent else K.Row,
			Text = name,
			Font = BOLD,
			TextSize = 13,
			TextColor3 = if on then Color3.fromRGB(6, 20, 24) else K.Text,
			LayoutOrder = i,
		}, parent)
		UiKit.round(tab, 14)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, tab)
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
	pill(pills, string.format("%d / %d GEMS", #profile.Gems, Config.MaxGems), K.Accent, 2)
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
