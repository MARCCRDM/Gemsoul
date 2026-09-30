--[[
	The Crafting Hall screen (Hilde's exchange and Borin's forge), in three
	tabs. Everything here is paid in Guild Marks, earned by selling stones:
	  CRAFT      your class's weapons and armor: craft new pieces, upgrade
	             their quality (Standard > Fine > Superior > Masterwork) and
	             equip them. "Buy missing" tops up materials in one click.
	  MATERIALS  buy iron, timber, leather, cloth and mithril.
	  SELL STONES  pick gems you don't want, then sell them for Marks or
	             salvage them into Gem Shards (asks you to confirm).
	The server checks everything and that you're at the workshop.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, button, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 1000, 620
local CELL, GAP = 52, 6
local KINDS = { "Weapons", "Armors" }
local SLOT_KEY = { Weapons = "Weapon", Armors = "Armor" }

local ForgeUI = {}

local window = IronUi.window("Forge", 9, WIDTH, HEIGHT)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "CRAFTING HALL"

local tab = "Craft"
-- "Hall" (Hilde and Borin, Guild Marks) or "Market" (Tamsin, coins; selling only).
local mode = "Hall"
local busy = false
local chosen: { Kind: string, Id: string }? = nil -- CRAFT tab selection
local picked: { [string]: boolean } = {} -- SELL tab selection
local confirming: string? = nil -- "Sell" or "Salvage" awaiting a second click

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

-- Runs server requests one after another (the server wants a short gap).
local function run(steps: { { any } }, after: (() -> ())?)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		for i, step in steps do
			if i > 1 then
				task.wait(0.25)
			end
			local result = GemClient.request(table.unpack(step))
			UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
			if not result.Ok then
				break
			end
		end
		busy = false
		if after then
			after()
		end
	end)
end

-- Tabs and the material strip -------------------------------------------------------------

local tabBar = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 74),
	Size = UDim2.fromOffset(460, 34),
}, panel)
UiKit.list(tabBar, 8, true)

local strip = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 22),
	Size = UDim2.fromOffset(560, 20),
}, panel)
UiKit.list(strip, 12, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
local marksLabel = text(panel, "", 16, P.Gold, BOLD)
marksLabel.AnchorPoint = Vector2.new(1, 0)
marksLabel.Position = UDim2.new(1, -24, 0, 50)
marksLabel.Size = UDim2.fromOffset(300, 20)
marksLabel.TextXAlignment = Enum.TextXAlignment.Right
window.Close.Position = UDim2.new(1, -16, 0, 80)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 122),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 146),
}, panel)

local function have(id: string): number
	local materials = GemClient.Profile and GemClient.Profile.Materials
	return materials and materials[id] or 0
end

local function swatch(parent: Instance, material: Crafting.Material, size: number): Frame
	local chip = new("Frame", {
		BackgroundColor3 = material.Color,
		Size = UDim2.fromOffset(size, size),
		Rotation = if material.Id == "Shards" then 45 else 0,
	}, parent)
	UiKit.round(chip, if material.Id == "Shards" then 2 else 3)
	return chip
end

local function drawStrip()
	clear(strip)
	for i, id in Crafting.MaterialOrder do
		local material = Crafting.Materials[id]
		local item = new("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			LayoutOrder = i,
		}, strip)
		UiKit.list(item, 5, true)
		swatch(item, material, 12)
		local count = text(item, string.format("%s %d", id, have(id)), 13, P.Text, BOLD)
		count.AutomaticSize = Enum.AutomaticSize.XY
		count.Size = UDim2.fromOffset(0, 0)
		count.TextWrapped = false
	end
	local profile = GemClient.Profile
	strip.Visible = mode == "Hall"
	marksLabel.Text = if mode == "Market"
		then commas(profile and profile.Coins or 0) .. " COINS"
		else commas(profile and profile.Marks or 0) .. " GUILD MARKS"
end

-- CRAFT tab --------------------------------------------------------------------------------

local function ownedQuality(kind: string, id: string): number?
	local owned = GemClient.Profile and GemClient.Profile.Owned
	return owned and owned[kind] and owned[kind][id]
end

local function equipped(kind: string, id: string): boolean
	local character = GemClient.Profile and GemClient.Profile.Character
	return character ~= nil and character[SLOT_KEY[kind]] == id
end

local function bonusText(bonus: { [string]: number }): string
	local parts = {}
	for _, stat in Classes.StatNames do
		if bonus[stat] then
			table.insert(parts, string.format("+%d %s", bonus[stat], stat))
		end
	end
	return if #parts > 0 then table.concat(parts, "  ") else "no bonus"
end

local function gearRow(parent: Instance, kind: string, gear, order: number, class)
	local quality = ownedQuality(kind, gear.Id)
	local selected = chosen ~= nil and chosen.Kind == kind and chosen.Id == gear.Id
	local row = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if selected then Color3.fromRGB(52, 44, 32) else P.Slot,
		Size = UDim2.new(1, 0, 0, 58),
		LayoutOrder = order,
	}, parent)
	UiKit.round(row, 6)
	new("UIStroke", {
		Color = if selected then P.Gold elseif quality then Crafting.Qualities[quality].Color else P.Edge,
		Thickness = if selected then 2 else 1,
		Transparency = if quality or selected then 0 else 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, row)
	UiKit.pad(row, 10)
	UiKit.list(row, 2)
	local name = text(
		row,
		Crafting.gearName(gear.Name, quality),
		16,
		if quality then Crafting.Qualities[quality].Color else P.Dim,
		BOLD
	)
	name.LayoutOrder = 1
	local status = if equipped(kind, gear.Id) then "EQUIPPED" elseif quality then "OWNED" else "NOT FORGED YET"
	local sub = text(
		row,
		string.upper(gear.Style) .. "   |   " .. status,
		11,
		if equipped(kind, gear.Id) then class.Color else P.Dim,
		BOLD
	)
	sub.LayoutOrder = 2
	row.Activated:Connect(function()
		chosen = { Kind = kind, Id = gear.Id }
		confirming = nil
		ForgeUI.refresh()
	end)
end

local function recipeRow(parent: Instance, material: Crafting.Material, need: number, order: number)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = order }, parent)
	UiKit.list(row, 8, true)
	swatch(row, material, 14)
	local got = have(material.Id)
	local label = text(
		row,
		string.format("%s   %d / %d", material.Name, got, need),
		14,
		if got >= need then P.Good else P.Bad,
		BOLD
	)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Size = UDim2.new(1, -30, 1, 0)
end

local function drawCraft()
	local profile = GemClient.Profile
	local classId = profile and profile.Character and profile.Character.Class
	local class = classId and Classes.List[classId]
	if not class then
		text(body, "Choose a class first.", 16, P.Dim)
		return
	end
	window.Subtitle.Text = string.format("%s gear  |  quality: Standard > Fine > Superior > Masterwork", class.Name)
	if not chosen then
		chosen = { Kind = "Weapons", Id = profile.Character.Weapon or class.Weapons[1].Id }
	end

	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(420, HEIGHT - 146),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = P.Edge,
	}, body)
	UiKit.list(list, 6)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, list)
	local order = 0
	for _, kind in KINDS do
		order += 1
		text(list, if kind == "Weapons" then "WEAPONS" else "ARMOR", 12, P.Gold, BOLD).LayoutOrder = order
		for _, gear in class[kind] do
			order += 1
			gearRow(list, kind, gear, order, class)
		end
	end

	-- Detail and recipe for the selected piece.
	local kind, id = (chosen :: any).Kind, (chosen :: any).Id
	local gear = if kind == "Weapons" then Classes.weapon(classId, id) else Classes.armor(classId, id)
	if not gear then
		return
	end
	local quality = ownedQuality(kind, id)
	local detail = box(body, UDim2.fromOffset(440, 0), UDim2.new(1, -440, 1, 0), P.Inset)
	UiKit.pad(detail, 16)
	local info = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44) }, detail)
	UiKit.list(info, 6)
	text(
		info,
		Crafting.gearName(gear.Name, quality),
		22,
		if quality then Crafting.Qualities[quality].Color else P.Text,
		BOLD
	)
	text(info, string.upper(gear.Style) .. "   " .. gear.Description, 13, P.Dim)

	-- Quality ladder: one pip per quality, lit up to the current one.
	local ladder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, info)
	UiKit.list(ladder, 6, true)
	for q, info_ in Crafting.Qualities do
		local pip = new("TextLabel", {
			BackgroundColor3 = if quality and q <= quality then info_.Color else P.Slot,
			Text = info_.Name,
			Font = BOLD,
			TextSize = 11,
			TextColor3 = if quality and q <= quality then Color3.fromRGB(20, 16, 10) else P.Dim,
			Size = UDim2.new(0.25, -5, 1, 0),
		}, ladder)
		UiKit.round(pip, 4)
	end

	local now = Crafting.qualityBonus(kind, quality or 1)
	text(
		info,
		if quality then string.format("Now: %s", bonusText(now)) else "You don't own this yet.",
		14,
		P.Text,
		BOLD
	)
	local target = (quality or 0) + 1
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 34),
	}, detail)
	UiKit.list(actions, 8, true)

	if target <= Crafting.MaxQuality then
		local next_ = Crafting.Qualities[target]
		text(
			info,
			string.format(
				"%s %s: %s",
				if quality then "Upgrade to" else "Forge as",
				next_.Name,
				bonusText(Crafting.qualityBonus(kind, target))
			),
			14,
			next_.Color,
			BOLD
		)
		local recipe = Crafting.recipe(classId, kind, target) :: Crafting.Recipe
		text(info, "NEEDS", 12, P.Gold, BOLD)
		local r = 0
		for _, matId in Crafting.MaterialOrder do
			local need = recipe.Materials[matId]
			if need then
				r += 1
				recipeRow(info, Crafting.Materials[matId], need, 100 + r)
			end
		end
		local marks = profile.Marks or 0
		local feeLine = text(
			info,
			string.format("Forge fee  %s / %s Marks", commas(marks), commas(recipe.Marks)),
			14,
			if marks >= recipe.Marks then P.Good else P.Bad,
			BOLD
		)
		feeLine.LayoutOrder = 200

		button(actions, if quality then "UPGRADE TO " .. string.upper(next_.Name) else "FORGE IT", true, function()
			run({ { "Craft", kind, id } }, ForgeUI.refresh)
		end)
		-- Buy whatever buyable materials are short, in one go.
		local missing, cost = {}, 0
		for matId, need in recipe.Materials do
			local material = Crafting.Materials[matId]
			local short = need - have(matId)
			if short > 0 and material.Price then
				table.insert(missing, { "BuyMaterial", matId, math.min(short, 50) })
				cost += short * material.Price
			end
		end
		if #missing > 0 then
			button(actions, string.format("BUY MISSING (%d Marks)", cost), false, function()
				run(missing, ForgeUI.refresh)
			end)
		end
	else
		text(info, "Masterwork: the finest Borin can make.", 14, Crafting.Qualities[Crafting.MaxQuality].Color, BOLD)
	end
	if quality and not equipped(kind, id) then
		button(actions, "EQUIP", false, function()
			run({ { "EquipGear", kind, id } }, ForgeUI.refresh)
		end)
	end
end

-- MATERIALS tab ----------------------------------------------------------------------------

local function drawMaterials()
	window.Subtitle.Text = "Hilde's materials, paid in Guild Marks. Gem Shards come from salvaging stones."
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -10, 0.5, -8),
		CellPadding = UDim2.fromOffset(14, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, id in Crafting.MaterialOrder do
		local material = Crafting.Materials[id]
		local card = box(grid, UDim2.new(), UDim2.new(), P.Inset)
		card.LayoutOrder = i
		UiKit.pad(card, 14)
		local info = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -40) }, card)
		UiKit.list(info, 6)
		local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, info)
		UiKit.list(head, 10, true)
		swatch(head, material, 20)
		local name = text(head, material.Name, 17, P.Text, BOLD)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Size = UDim2.new(1, -30, 1, 0)
		text(info, material.Description, 13, P.Dim)
		text(info, string.format("You have %d", have(id)), 14, P.Text, BOLD)
		text(
			info,
			if material.Price then string.format("%d Marks each", material.Price) else "Not for sale",
			14,
			P.Gold,
			BOLD
		)
		local actions = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
		}, card)
		UiKit.list(actions, 6, true)
		if material.Price then
			for _, count in { 1, 5, 10 } do
				button(actions, "BUY " .. count, count == 1, function()
					run({ { "BuyMaterial", id, count } }, ForgeUI.refresh)
				end)
			end
		else
			button(actions, "SALVAGE GEMS", false, function()
				tab = "Sell"
				ForgeUI.refresh()
			end)
		end
	end
end

-- SELL tab ---------------------------------------------------------------------------------

local function sortedGems(): { any }
	local gems = table.clone(GemClient.Profile and GemClient.Profile.Gems or {})
	table.sort(gems, function(a, b)
		return GemConfig.value(a) < GemConfig.value(b)
	end)
	return gems
end

-- The grid is rebuilt only when the gems change; picking a gem just
-- re-marks its cell and redraws the summary, so the 3D stones stay put.
local sellKey = ""
local sellCells: { [string]: { Cell: TextButton, Stroke: UIStroke, Mark: TextLabel, Gem: any } } = {}
local sellSide: Frame? = nil

local function markCells()
	for id, entry in sellCells do
		local isPicked = picked[id] == true
		entry.Cell.BackgroundColor3 = if isPicked then Color3.fromRGB(70, 30, 26) else P.Slot
		entry.Stroke.Color = if isPicked then P.Bad else GemConfig.TierColors[entry.Gem.Tier]
		entry.Stroke.Thickness = if isPicked then 2.5 else 1.2
		entry.Stroke.Transparency = if isPicked then 0 else 0.35
		entry.Mark.Visible = isPicked
	end
end

local drawSellSide: (gems: { any }) -> ()

local function buildSellGrid(gems: { any })
	clear(body)
	table.clear(sellCells)
	local gridBox = box(body, UDim2.new(), UDim2.fromOffset(560, HEIGHT - 146), Color3.fromRGB(10, 9, 8))
	local grid = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = P.Edge,
	}, gridBox)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	if #gems == 0 then
		text(grid, "Your pouch is empty.", 14, P.Dim)
	end
	local order = {}
	for i, gem in gems do
		local cell = new("TextButton", { Text = "", BackgroundColor3 = P.Slot, LayoutOrder = i }, grid)
		UiKit.round(cell, 4)
		local stroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
		if not gem.Cut then
			local rough = text(cell, "R", 10, P.Dim, BOLD)
			rough.Position = UDim2.fromOffset(4, 2)
			rough.ZIndex = 3
		end
		local mark = text(cell, "X", 12, P.Bad, BOLD)
		mark.AnchorPoint = Vector2.new(1, 0)
		mark.Position = UDim2.new(1, -4, 0, 2)
		mark.Size = UDim2.fromOffset(12, 12)
		mark.ZIndex = 3
		cell.Activated:Connect(function()
			picked[gem.Id] = if picked[gem.Id] then nil else true
			confirming = nil
			markCells()
			drawSellSide(gems)
		end)
		sellCells[gem.Id] = { Cell = cell, Stroke = stroke, Mark = mark, Gem = gem }
		table.insert(order, cell)
	end
	-- Stones are 3D; build them a few per frame so opening stays smooth.
	task.spawn(function()
		for i, cell in order do
			if not cell.Parent then
				return
			end
			GemArt.viewport(cell, gems[i], false)
			if i % 12 == 0 then
				task.wait()
			end
		end
	end)
end

function drawSellSide(gems: { any })
	if sellSide then
		sellSide:Destroy()
	end
	local side = box(body, UDim2.fromOffset(576, 0), UDim2.new(1, -576, 1, 0), P.Inset)
	sellSide = side
	UiKit.pad(side, 16)
	local info = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -130) }, side)
	UiKit.list(info, 8)
	local count, marks, shards = 0, 0, 0
	local selected = {}
	for _, gem in gems do
		if picked[gem.Id] then
			count += 1
			marks += if mode == "Market" then Crafting.marketPrice(gem) else Crafting.sellPrice(gem)
			shards += Crafting.salvageShards(gem)
			table.insert(selected, gem.Id)
		end
	end
	text(info, string.format("%d GEM%s SELECTED", count, if count == 1 then "" else "S"), 20, P.Gold, IronUi.Heading)
	text(info, "Click gems to pick them. Socketed gems stay safe in your gear.", 13, P.Dim)
	if mode == "Market" then
		text(info, string.format("Sell for  %s coins", commas(marks)), 18, P.Gold, BOLD)
		text(info, "Hilde at the Crafting Hall pays more, in Guild Marks for crafting.", 12, P.Dim)
	else
		text(info, string.format("Sell for  %s Guild Marks", commas(marks)), 18, P.Gold, BOLD)
		text(info, string.format("or salvage into  %d Gem Shards", shards), 18, Crafting.Materials.Shards.Color, BOLD)
		text(info, "Shards are needed for Masterwork gear.", 12, P.Dim)
	end

	local quick = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -84),
		Size = UDim2.new(1, 0, 0, 34),
	}, side)
	UiKit.list(quick, 6, true)
	local function pickWhere(test: ((any) -> boolean)?)
		if not test then
			table.clear(picked)
		end
		for _, gem in gems do
			if test and test(gem) then
				picked[gem.Id] = true
			end
		end
		confirming = nil
		markCells()
		drawSellSide(gems)
	end
	button(quick, "ALL ROUGH", false, function()
		pickWhere(function(gem)
			return gem.Cut == nil
		end)
	end)
	button(quick, "ALL COMMON", false, function()
		pickWhere(function(gem)
			return gem.Tier == "Common"
		end)
	end)
	button(quick, "CLEAR", false, function()
		pickWhere(nil)
	end)

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 34),
	}, side)
	UiKit.list(actions, 8, true)
	if count == 0 then
		return
	end
	-- Selling can't be undone, so each action asks once more.
	for _, action in if mode == "Market" then { "Sell" } else { "Sell", "Salvage" } do
		local label = if confirming == action
			then "CONFIRM " .. string.upper(action) .. "?"
			elseif action == "Sell" then string.format("SELL (%s)", commas(marks))
			else string.format("SALVAGE (%d)", shards)
		local b = button(actions, label, action == "Sell", function()
			if confirming ~= action then
				confirming = action
				drawSellSide(gems)
				return
			end
			confirming = nil
			local ids = table.clone(selected)
			table.clear(picked)
			local request = if action == "Salvage"
				then "SalvageGems"
				elseif mode == "Market" then "MarketSell"
				else "SellGems"
			run({ { request, ids } }, ForgeUI.refresh)
		end)
		if confirming == action then
			b.BackgroundColor3 = P.Bad
			b.TextColor3 = Color3.new(1, 1, 1)
		end
	end
end

local function drawSell()
	window.Subtitle.Text = if mode == "Market"
		then "Tamsin buys stones for coins at half their value."
		else "Hilde pays 60% of a stone's value in Guild Marks, or salvages it into Gem Shards."
	local gems = sortedGems()
	local present, ids = {}, {}
	for i, gem in gems do
		present[gem.Id] = true
		ids[i] = gem.Id
	end
	-- Forget picks for gems that are gone.
	for id in picked do
		if not present[id] then
			picked[id] = nil
		end
	end
	local key = table.concat(ids, ",")
	if key ~= sellKey then
		sellKey = key
		buildSellGrid(gems)
	end
	markCells()
	drawSellSide(gems)
end

-- Drawing and opening -----------------------------------------------------------------------

local TABS = { { "Craft", "CRAFT" }, { "Materials", "MATERIALS" }, { "Sell", "SELL STONES" } }
local DRAW = { Craft = drawCraft, Materials = drawMaterials, Sell = drawSell }

function ForgeUI.refresh()
	if not gui.Enabled or not GemClient.Profile then
		return
	end
	clear(tabBar)
	window.Title.Text = if mode == "Market" then "TAMSIN'S STALL" else "CRAFTING HALL"
	for i, entry in if mode == "Market" then { TABS[3] } else TABS do
		local b = button(tabBar, entry[2], entry[1] == tab, function()
			tab = entry[1]
			confirming = nil
			ForgeUI.refresh()
		end)
		b.LayoutOrder = i
	end
	drawStrip()
	-- The sell grid keeps itself (see drawSell); everything else redraws.
	if tab ~= "Sell" then
		sellKey = ""
		sellSide = nil
		clear(body)
	end
	DRAW[tab]()
end

-- `which` is the tab; `market` opens Tamsin's coin sale instead of the hall.
function ForgeUI.open(which: string?, market: boolean?)
	mode = if market then "Market" else "Hall"
	tab = if market then "Sell" else which or "Craft"
	sellKey = ""
	sellSide = nil
	clear(body)
	chosen = nil
	confirming = nil
	table.clear(picked)
	gui.Enabled = true
	window.Fit()
	ForgeUI.refresh()
	local target = window.Scale.Scale
	window.Scale.Scale = target * 0.94
	TweenService:Create(window.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = target,
	}):Play()
end

function ForgeUI.close()
	gui.Enabled = false
	sellKey = ""
	sellSide = nil
	clear(body)
end

window.Close.Activated:Connect(ForgeUI.close)
window.Shade.Activated:Connect(ForgeUI.close)
-- The profile changes after every purchase or sale; redraw unless mid-request
-- (the request's own callback redraws when it's done).
GemClient.Changed:Connect(function()
	if gui.Enabled and not busy then
		ForgeUI.refresh()
	end
end)

return ForgeUI
