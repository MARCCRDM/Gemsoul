--[[
	The gem pouch: every gem with its colour, element, rarity, size, clarity,
	cut and value. Also used as a picker, e.g. to choose a stone to cut:

	InventoryUI.open({
		Title = "Choose a stone to cut",
		Filter = function(gem) return gem.Cut == nil end,
		ActionText = "Cut",
		OnPick = function(gem) ... end,
	})
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)

local K = UiKit.Colors

type Options = {
	Title: string?,
	Filter: ((any) -> boolean)?,
	ActionText: string?,
	OnPick: ((any) -> ())?,
	Empty: string?,
}

local InventoryUI = {}

local gui = UiKit.gui("GemPouch", 5)
gui.Enabled = false

local panel = UiKit.panel(gui)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.92, 0.78)
UiKit.pad(panel, 14)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(640, 620)
limit.Parent = panel

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 56)
header.Parent = panel

local title = UiKit.text(header, "GEM POUCH", 22, K.Accent, Enum.Font.Arcade)
title.Size = UDim2.new(1, -50, 0, 26)
title.AutomaticSize = Enum.AutomaticSize.None

local summary = UiKit.text(header, "", 16, K.Dim)
summary.Position = UDim2.fromOffset(0, 30)
summary.Size = UDim2.new(1, -50, 0, 22)
summary.AutomaticSize = Enum.AutomaticSize.None

local closeButton = UiKit.button(header, "X", K.Bad, function()
	InventoryUI.close()
end)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(1, 0)

local scroller = Instance.new("ScrollingFrame")
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Position = UDim2.fromOffset(0, 64)
scroller.Size = UDim2.new(1, 0, 1, -64)
scroller.CanvasSize = UDim2.new()
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.ScrollBarThickness = 6
scroller.Parent = panel
UiKit.list(scroller, 6)

local current: Options? = nil

local function gemRow(gem, order: number, options: Options)
	local shade = GemConfig.shade(gem)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundColor3 = K.Row
	row.Size = UDim2.new(1, -8, 0, 64)
	row.Parent = scroller
	UiKit.round(row, 6)

	local chip = UiKit.swatch(row, shade, 26)
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.fromOffset(28, 32)

	local hasAction = options.OnPick ~= nil
	local textWidth = if hasAction then -170 else -150

	local name = UiKit.text(row, GemConfig.displayName(gem), 17)
	name.Position = UDim2.fromOffset(56, 8)
	name.Size = UDim2.new(1, textWidth, 0, 20)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false

	local cut = if gem.Cut then (if gem.Cut >= 10 then "10 GEM MINT" else tostring(gem.Cut)) else "rough"
	local stats = UiKit.text(
		row,
		string.format("%s  |  Size %d  Clarity %d  Cut %s", GemConfig.TierLabels[gem.Tier], gem.Size, gem.Clarity, cut),
		14,
		GemConfig.TierColors[gem.Tier]
	)
	stats.Position = UDim2.fromOffset(56, 34)
	stats.Size = UDim2.new(1, textWidth, 0, 18)
	stats.AutomaticSize = Enum.AutomaticSize.None
	stats.TextTruncate = Enum.TextTruncate.AtEnd
	stats.TextWrapped = false

	local value = UiKit.text(row, string.format("%d coins", GemConfig.value(gem)), 16, K.Gold)
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, if hasAction then -84 else -12, 0.5, 0)
	value.Size = UDim2.fromOffset(90, 20)
	value.AutomaticSize = Enum.AutomaticSize.None
	value.TextXAlignment = Enum.TextXAlignment.Right

	if options.OnPick then
		local pick = options.OnPick
		local button = UiKit.button(row, options.ActionText or "Pick", K.Accent, function()
			InventoryUI.close()
			pick(gem)
		end)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)
	end
end

local function render()
	local options = current
	if not options then
		return
	end
	for _, child in scroller:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local profile = GemClient.Profile
	title.Text = string.upper(options.Title or "Gem Pouch")
	if not profile then
		summary.Text = "Loading..."
		return
	end
	local quota = profile.Quota
	summary.Text = string.format(
		"%d coins  |  %d gems  |  free mines: %d/%d today, %d/%d this week",
		profile.Coins,
		#profile.Gems,
		math.max(0, profile.DailyQuota - quota.UsedToday),
		profile.DailyQuota,
		math.max(0, profile.WeeklyQuota - quota.UsedThisWeek),
		profile.WeeklyQuota
	)

	local gems = {}
	for _, gem in profile.Gems do
		if not options.Filter or options.Filter(gem) then
			table.insert(gems, gem)
		end
	end
	table.sort(gems, function(a, b)
		return GemConfig.value(a) > GemConfig.value(b)
	end)
	for i, gem in gems do
		gemRow(gem, i, options)
	end
	if #gems == 0 then
		UiKit.text(scroller, options.Empty or "No gems yet. Mine some in the quarry up the north road!", 17, K.Dim)
	end
end

function InventoryUI.open(options: Options?)
	current = options or {}
	render()
	gui.Enabled = true
end

function InventoryUI.close()
	current = nil
	gui.Enabled = false
end

function InventoryUI.toggle()
	if gui.Enabled then
		InventoryUI.close()
	else
		InventoryUI.open()
	end
end

GemClient.Changed:Connect(render)

return InventoryUI
