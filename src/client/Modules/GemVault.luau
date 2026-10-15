--[[
	GemVault: available gems in one window, opened from the Inventory's
	GEMS button.

	  Left    loose gems, filtered by element and sorted by rarity or value.
	          Drag a cut stone out of this window to enchant equipment.
	  Right   the picked gem: a turning 3D stone, rarity, element, where it
	          sits, Size / Clarity / Cut as bars, and its value.
	  Tree    the gem's three moves (Shared.GemTraits): the gem branches into
	          Q (sword), E (core) and R (shield), and each branch shows every
	          move that element can roll for that key, with this gem's lit,
	          the odds under each, and a signature ★. Tap a move for what it
	          does at this gem's numbers. This view only inspects existing moves.

	Drawn on the Inventory's 1600 x 840 canvas, so it scales with it.
	  GemVault.open(canvas)   GemVault.close()   GemVault.isOpen()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local SurgeIcons = require(script.Parent.SurgeIcons)

local Traits = Tech.Traits
local new = IronUi.new

local GemVault = {}

local C = {
	Ink = Color3.fromRGB(5, 7, 12),
	Panel = Color3.fromRGB(12, 16, 25),
	Card = Color3.fromRGB(19, 25, 37),
	Text = Color3.fromRGB(238, 242, 247),
	Dim = Color3.fromRGB(139, 155, 177),
	Faint = Color3.fromRGB(74, 90, 112),
	Line = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(242, 189, 94),
	Good = Color3.fromRGB(95, 208, 138),
	Bad = Color3.fromRGB(255, 122, 107),
	Empty = Color3.fromRGB(32, 42, 58),
}
local HEAVY, HEADING, MEDIUM = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium
local KEYS = { "Q", "E", "R" }
local KEY_COLORS = {
	Q = Color3.fromRGB(255, 138, 92),
	E = Color3.fromRGB(122, 196, 255),
	R = Color3.fromRGB(120, 230, 170),
}
local KEY_LANE = { Q = "OFFENSE", E = "ABILITY", R = "DEFENSE" }
local KEY_SOCKET = { Q = "SWORD", E = "CORE", R = "SHIELD" }
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }
local RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

-- The window is drawn at this size, in the middle of the 1600 x 840 canvas.
local CANVAS_W, CANVAS_H = 1600, 840
local WIN_W, WIN_H = 1360, 720
local LIST_W = 452
local CELL_W, CELL_H = 104, 128

local state = {
	Filter = "All",
	Sort = "Rarity",
	Selected = nil :: string?,
	Move = nil :: string?, -- the move whose details are showing
}
local ui: { [string]: any } = {}
local spin: RBXScriptConnection? = nil
local changed: RBXScriptConnection? = nil

-- Small builders ------------------------------------------------------------------------------------------

local function round(object: GuiObject, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local function stroke(object: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	transparency: number?
): Frame
	return new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
end

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	font: Enum.Font,
	x: number,
	y: number,
	w: number,
	h: number
): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
end

local function button(parent: Instance, value: string, x: number, y: number, w: number, h: number): TextButton
	local b = new("TextButton", {
		Text = value,
		TextSize = 12,
		Font = HEADING,
		TextColor3 = C.Dim,
		AutoButtonColor = false,
		BackgroundColor3 = C.Card,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	round(b, 8)
	b:SetAttribute("UiSound", "Click")
	return b
end

local function commas(n: number): string
	local value = tostring(math.floor(n + 0.5))
	while true do
		local swapped, count = string.gsub(value, "^(-?%d+)(%d%d%d)", "%1,%2")
		value = swapped
		if count == 0 then
			return value
		end
	end
end

-- The gems ------------------------------------------------------------------------------------------------

type Entry = { Gem: any, Where: string }

-- Socketed gems are inspected on equipment, never offered as loose stones.
local function allGems(): { Entry }
	local list = {}
	for _, gem in GemInventory.available(GemClient.Profile) do
		table.insert(list, { Gem = gem, Where = "POUCH" })
	end
	return list
end

local function shown(): { Entry }
	local out = {}
	for _, entry in allGems() do
		if state.Filter == "All" or entry.Gem.Element == state.Filter then
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a, b)
		local ka = if state.Sort == "Value"
			then GemConfig.value(a.Gem)
			else (RANK[a.Gem.Tier] or 0) * 1e6 + GemConfig.value(a.Gem)
		local kb = if state.Sort == "Value"
			then GemConfig.value(b.Gem)
			else (RANK[b.Gem.Tier] or 0) * 1e6 + GemConfig.value(b.Gem)
		if ka ~= kb then
			return ka > kb
		end
		return tostring(a.Gem.Id) < tostring(b.Gem.Id)
	end)
	return out
end

local function gemName(gem): string
	local ok, shade = pcall(GemConfig.shade, gem)
	return if ok and shade then shade.Name else "Gem"
end

local function elementName(element: string?): string
	return string.upper(element and GemConfig.elementName(element) or "?")
end

-- Drawing --------------------------------------------------------------------------------------------------

local draw -- (forward)

local function drawList(entries: { Entry })
	local grid = ui.Grid
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, entry in entries do
		local gem = entry.Gem
		local tier = GemConfig.TierColors[gem.Tier] or C.Dim
		local picked = gem.Id == state.Selected
		local cell = new("TextButton", {
			Name = "GemCell",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if picked then tier:Lerp(C.Card, 0.78) else C.Card,
			LayoutOrder = i,
		}, grid)
		round(cell, 10)
		stroke(cell, if picked then C.Gold else tier, if picked then 2 else 1, if picked then 0 else 0.7)
		box(cell, tier, 10, 0, CELL_W - 20, 3)
		local art = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(CELL_W - 24, CELL_W - 24),
		}, cell)
		pcall(GemArt.viewport, art, gem, false)
		local name = text(cell, gemName(gem), 11, C.Text, HEADING, 4, CELL_W - 12, CELL_W - 8, 14)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local where = text(
			cell,
			if gem.Cut ~= nil then "DRAG TO ENCHANT" else "UNCUT",
			9,
			if entry.Where == "POUCH" then C.Faint else C.Gold,
			HEADING,
			4,
			CELL_W + 4,
			CELL_W - 8,
			12
		)
		where.TextXAlignment = Enum.TextXAlignment.Center
		cell:SetAttribute("UiSound", "Click")
		cell.InputBegan:Connect(function(input)
			if ui.BeginDrag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				ui.BeginDrag(gem, input)
			end
		end)
		cell.Activated:Connect(function()
			state.Selected, state.Move = gem.Id, nil
			draw()
		end)
	end
	ui.Empty.Visible = #entries == 0
end

-- Ten segments for a 1-10 grade.
local function bar(parent: Instance, label: string, value: number, color: Color3, y: number)
	text(parent, label, 11, C.Dim, HEADING, 0, y, 70, 16)
	for i = 1, 10 do
		local segment = box(parent, if i <= value then color else C.Empty, 74 + (i - 1) * 19, y + 2, 15, 12)
		round(segment, 3)
	end
	local amount =
		text(parent, value .. "/10", 12, if value >= 10 then C.Gold else C.Text, HEADING, 74 + 10 * 19 + 6, y, 44, 16)
	amount.TextXAlignment = Enum.TextXAlignment.Right
end

local function line(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, transparency: number?)
	return box(parent, color, x, y, w, h, transparency)
end

-- The move tree: the gem, a spine, and a branch per key.
local function drawTree(parent: Frame, gem)
	local traits = Traits.traitsOf(gem)
	local rowH, top = 102, 30
	local nodeX, nodeY, node = 0, top + rowH * 1.5 - 34, 68
	-- The gem at the root.
	local root = box(parent, C.Card, nodeX, nodeY, node, node)
	round(root, node / 2)
	stroke(root, GemConfig.ElementColors[gem.Element] or C.Dim, 2, 0.2)
	local rootArt = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(node - 12, node - 12) },
		root
	)
	pcall(GemArt.viewport, rootArt, gem, false)
	-- The spine the three branches hang from.
	local spineX = nodeX + node + 26
	line(parent, C.Line, nodeX + node, nodeY + node / 2 - 1, 26, 2, 0.75)
	line(parent, C.Line, spineX, top + rowH / 2 - 1, 2, rowH * 2 + 2, 0.75)
	if not traits then
		text(parent, "This stone has no moves to show.", 13, C.Dim, MEDIUM, spineX + 24, top + rowH, 400, 20)
		return
	end
	for row, key in KEYS do
		local lane = Traits.Lanes[key]
		local color = KEY_COLORS[key]
		local y = top + (row - 1) * rowH
		local mid = y + rowH / 2
		line(parent, color, spineX, mid - 1, 22, 2, 0.35)
		-- The key: its badge and its job.
		local badge = box(parent, color, spineX + 22, mid - 16, 32, 32)
		round(badge, 8)
		local letter = text(badge, key, 16, C.Ink, HEAVY, 0, 0, 32, 32)
		letter.TextXAlignment = Enum.TextXAlignment.Center
		text(parent, KEY_LANE[key], 10, color, HEAVY, spineX + 62, mid - 14, 74, 13)
		text(parent, KEY_SOCKET[key], 9, C.Dim, HEADING, spineX + 62, mid + 1, 74, 12)
		-- Every move this element can roll for the key, along the branch.
		local ids = (Traits.Matrix[gem.Element] or {})[lane] or {}
		local odds = Traits.odds(gem.Element, lane)
		local mine = traits[lane]
		local startX, tile, gap = spineX + 136, 56, 9
		line(parent, color, spineX + 128, mid - 1, 8 + #ids * (tile + gap), 2, 0.8)
		for i, id in ids do
			local move = Tech.Catalog[id]
			local lit = id == mine
			local x = startX + (i - 1) * (tile + gap)
			local cell = new("TextButton", {
				Name = "Move",
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = if lit then color:Lerp(C.Ink, 0.55) else C.Card,
				Position = UDim2.fromOffset(x, mid - tile / 2 - 12),
				Size = UDim2.fromOffset(tile, tile),
			}, parent)
			round(cell, 12)
			stroke(
				cell,
				if state.Move == id then C.Gold elseif lit then color else C.Line,
				if lit or state.Move == id then 2 else 1,
				if lit or state.Move == id then 0 else 0.88
			)
			local glyph = text(
				cell,
				if move then string.upper(string.sub(move.Name, 1, 2)) else "?",
				18,
				if lit then C.Text else C.Faint,
				HEAVY,
				0,
				0,
				tile,
				tile
			)
			glyph.TextXAlignment = Enum.TextXAlignment.Center
			if move then
				pcall(SurgeIcons.apply, glyph, move, color)
			end
			if not lit then
				-- The ones this gem didn't roll sit back.
				local veil = box(cell, C.Ink, 0, 0, tile, tile, 0.45)
				round(veil, 12)
				veil.ZIndex = 3
			end
			local caption = text(
				parent,
				(move and move.Name or id) .. (if move and move.Rare then " ★" else ""),
				9,
				if lit then C.Text else C.Dim,
				HEADING,
				x - 4,
				mid + tile / 2 - 9,
				tile + 8,
				12
			)
			caption.TextXAlignment = Enum.TextXAlignment.Center
			caption.TextTruncate = Enum.TextTruncate.AtEnd
			local chance = text(
				parent,
				string.format("%d%%", math.floor((odds[id] or 0) * 100 + 0.5)),
				9,
				if lit then color else C.Faint,
				MEDIUM,
				x,
				mid + tile / 2 + 3,
				tile,
				12
			)
			chance.TextXAlignment = Enum.TextXAlignment.Center
			cell:SetAttribute("UiSound", "Tab")
			cell.Activated:Connect(function()
				state.Move = id
				draw()
			end)
		end
	end
end

-- What a move does at this gem's numbers.
local function drawMove(gem)
	local id = state.Move
	local move = id and Tech.Catalog[id]
	if not move then
		ui.MoveName.Text = "TAP A MOVE"
		ui.MoveName.TextColor3 = C.Faint
		ui.MoveText.Text =
			"Lit moves belong to this stone. The others show what another stone of this element can roll."
		return
	end
	local stats = Traits.stats(id, gem)
	local key = Traits.KeyOfLane[move.Lane or ""] or "Q"
	ui.MoveName.Text = string.upper(move.Name) .. "  ·  " .. string.upper(Traits.typeOf(id))
	ui.MoveName.TextColor3 = KEY_COLORS[key]
	local words = move.Description or ""
	if stats then
		words ..= '  <font color="#' .. C.Text:ToHex() .. '">At this gem: ' .. Traits.summary(stats) .. ".</font>"
	end
	if move.Flourish and move.Flourish.Text then
		words ..= '  <font color="#' .. C.Gold:ToHex() .. '">Legendary: ' .. move.Flourish.Text .. "</font>"
	end
	ui.MoveText.Text = words
end

draw = function()
	if not ui.Window then
		return
	end
	local entries = shown()
	-- Keep a gem picked: the last one, else the first on show.
	local selected = nil
	for _, entry in entries do
		if entry.Gem.Id == state.Selected then
			selected = entry
		end
	end
	if not selected then
		selected = entries[1]
		state.Selected = selected and selected.Gem.Id
	end
	for name, chip in ui.Filters do
		local on = state.Filter == name
		chip.TextColor3 = if on
			then C.Ink
			else (if name == "All" then C.Dim else GemConfig.ElementColors[name] or C.Dim)
		chip.BackgroundColor3 = if on
			then (if name == "All" then C.Text else GemConfig.ElementColors[name] or C.Text)
			else C.Card
	end
	ui.SortButton.Text = "SORT: " .. string.upper(state.Sort)
	local total = #allGems()
	ui.Count.Text = string.format("%d AVAILABLE STONES", total)
	ui.Empty.Text = if total == 0 then "No loose stones. Equipped stones stay on your gear." else "No available stones of this element."
	drawList(entries)
	-- The detail.
	local detail = ui.Detail
	for _, child in detail:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Keep" then
			child:Destroy()
		end
	end
	if spin then
		spin:Disconnect()
		spin = nil
	end
	ui.MoveCard.Visible = selected ~= nil
	if not selected then
		local none = text(detail, if total == 0 then "Mine more stones, or remove one from your equipment." else "Choose another element to see your available stones.", 16, C.Dim, MEDIUM, 0, 120, 700, 48)
		none.TextWrapped = true
		none.TextXAlignment = Enum.TextXAlignment.Left
		return
	end
	local gem = selected.Gem
	local tier = GemConfig.TierColors[gem.Tier] or C.Dim
	local element = GemConfig.ElementColors[gem.Element] or C.Text
	-- The stone, turning.
	local stage = box(detail, C.Card, 0, 0, 170, 170)
	round(stage, 85)
	stroke(stage, tier, 2, 0.25)
	local glow = box(stage, tier, 0, 0, 170, 170, 0.88)
	round(glow, 85)
	local holder = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(142, 142) },
		stage
	)
	local ok, viewport = pcall(GemArt.viewport, holder, gem, true)
	local model = ok and viewport and viewport:FindFirstChildOfClass("Model")
	if model then
		local started = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			model:PivotTo(GemArt.pose(gem, 0.6 + (os.clock() - started) * 0.7))
		end)
	end
	-- Who it is.
	text(detail, string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier or ""), 12, tier, HEAVY, 194, 0, 300, 16)
	text(detail, gemName(gem), 30, C.Text, HEAVY, 194, 16, 520, 36)
	local dot = box(detail, element, 194, 60, 10, 10)
	round(dot, 5)
	text(
		detail,
		elementName(gem.Element) .. (if gem.Cut then "" else "  ·  ROUGH, CUT IT TO USE"),
		12,
		element,
		HEADING,
		210,
		56,
		360,
		18
	)
	local whereWords = if gem.Cut ~= nil then "Drag onto equipment or Q / E / R to enchant." else "Cut this stone before enchanting equipment."
	text(detail, whereWords, 12, C.Dim, MEDIUM, 194, 76, 360, 18)
	-- Its grades and worth.
	local grades = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(194, 102), Size = UDim2.fromOffset(330, 80) },
		detail
	)
	bar(grades, "SIZE", gem.Size or 0, tier, 0)
	bar(grades, "CLARITY", gem.Clarity or 0, tier, 26)
	bar(grades, "CUT", gem.Cut or 0, tier, 52)
	text(detail, "VALUE", 11, C.Dim, HEADING, 580, 104, 120, 16)
	text(detail, "≈ " .. commas(GemConfig.value(gem)), 26, C.Gold, HEAVY, 580, 120, 240, 32)
	text(detail, "coins", 11, C.Dim, MEDIUM, 580, 152, 120, 14)
	-- The tree.
	text(detail, "MOVE TREE", 12, C.Text, HEAVY, 0, 190, 200, 16)
	text(
		detail,
		"One move per key, rolled from the gem's element. ★ = signature, half the odds.",
		11,
		C.Faint,
		MEDIUM,
		104,
		190,
		600,
		16
	)
	local tree = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 206),
		Size = UDim2.fromOffset(WIN_W - LIST_W - 88, 330),
	}, detail)
	drawTree(tree, gem)
	drawMove(gem)
end

-- Building ---------------------------------------------------------------------------------------------------

local function build(canvas: Instance)
	local scrim = new("TextButton", {
		Name = "GemVault",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		-- Past the canvas's edges, so letterboxed screens dim too.
		Position = UDim2.fromOffset(-400, -200),
		Size = UDim2.fromOffset(CANVAS_W + 800, CANVAS_H + 400),
		ZIndex = 40,
	}, canvas)
	local window = box(scrim, C.Panel, 400 + (CANVAS_W - WIN_W) / 2, 200 + (CANVAS_H - WIN_H) / 2, WIN_W, WIN_H)
	window.Active = true
	round(window, 18)
	stroke(window, C.Line, 1, 0.85)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(18, 24, 37), Color3.fromRGB(9, 12, 19)),
	}, window)
	ui.Window = window
	-- Header.
	text(window, "GEMS", 28, C.Text, HEAVY, 28, 20, 140, 34)
	ui.Count = text(window, "", 11, C.Dim, HEADING, 124, 32, 260, 16)
	ui.Filters = {}
	local fx = 400
	for _, name in { "All", table.unpack(ELEMENTS) } do
		local label = if name == "All" then "ALL" else elementName(name)
		local chip = button(window, label, fx, 22, if name == "All" then 56 else 104, 30)
		chip.TextSize = 11
		ui.Filters[name] = chip
		chip.Activated:Connect(function()
			state.Filter = name
			draw()
		end)
		fx += (if name == "All" then 56 else 104) + 8
	end
	ui.SortButton = button(window, "SORT: RARITY", fx + 12, 22, 136, 30)
	ui.SortButton.TextSize = 11
	ui.SortButton.Activated:Connect(function()
		state.Sort = if state.Sort == "Rarity" then "Value" else "Rarity"
		draw()
	end)
	local close = button(window, "✕", WIN_W - 58, 18, 38, 38)
	close.TextSize = 18
	close.TextColor3 = C.Text
	close:SetAttribute("UiSound", "Back")
	close.Activated:Connect(function()
		GemVault.close()
	end)
	box(window, C.Line, 24, 70, WIN_W - 48, 1, 0.92)
	-- The list.
	local list = new("ScrollingFrame", {
		Name = "GemList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24, 86),
		Size = UDim2.fromOffset(LIST_W, WIN_H - 110),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
	}, window)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL_W, CELL_H),
		CellPadding = UDim2.fromOffset(9, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, list)
	ui.Grid = list
	ui.Empty = text(window, "No gems of that element.", 13, C.Faint, MEDIUM, 28, 100, 300, 20)
	ui.Empty.Size = UDim2.fromOffset(LIST_W - 24, 56)
	ui.Empty.TextWrapped = true
	box(window, C.Line, LIST_W + 40, 86, 1, WIN_H - 110, 0.92)
	-- The detail.
	local detail = new("Frame", {
		Name = "GemDetail",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LIST_W + 64, 86),
		Size = UDim2.fromOffset(WIN_W - LIST_W - 88, WIN_H - 110),
	}, window)
	ui.Detail = detail
	-- The move card along the bottom (kept between redraws).
	local card = box(detail, C.Card, 0, WIN_H - 110 - 70, WIN_W - LIST_W - 88, 64)
	card.Name = "Keep"
	round(card, 12)
	stroke(card, C.Line, 1, 0.9)
	ui.MoveCard = card
	ui.MoveName = text(card, "", 12, C.Faint, HEAVY, 16, 10, 600, 16)
	ui.MoveText = text(card, "", 12, C.Dim, MEDIUM, 16, 28, WIN_W - LIST_W - 88 - 32, 32)
	ui.MoveText.TextWrapped = true
	ui.MoveText.RichText = true
	ui.MoveText.TextYAlignment = Enum.TextYAlignment.Top
	ui.Note = text(window, "", 12, C.Good, HEADING, LIST_W + 64, WIN_H - 22, 600, 16)
	ui.Note.Name = "Note"
	return scrim
end

function GemVault.isOpen(): boolean
	return ui.Root ~= nil and ui.Root.Parent ~= nil
end

function GemVault.open(canvas: Instance, gemId: string?, beginDrag: any?)
	if GemVault.isOpen() then
		GemVault.close()
	end
	state.Selected = gemId or state.Selected
	state.Move = nil
	ui = {}
	ui.BeginDrag = beginDrag
	ui.Root = build(canvas)
	changed = GemClient.Changed:Connect(function()
		if GemVault.isOpen() then
			draw()
		end
	end)
	draw()
end

function GemVault.close()
	if spin then
		spin:Disconnect()
		spin = nil
	end
	if changed then
		changed:Disconnect()
		changed = nil
	end
	if ui.Root then
		ui.Root:Destroy()
	end
	ui = {}
end

-- For tests: what's on show.
function GemVault.entries(): { Entry }
	return shown()
end

return GemVault
