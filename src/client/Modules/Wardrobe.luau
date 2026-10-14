--[[
	Wardrobe: your suits, weapon skins and pickaxes, opened from the Inventory's SKINS
	button. What you pick here is this miner's own look (each miner keeps its
	own; see Cosmetics.forMiner), and swaps in one tap.

	  Tabs    SUITS, WEAPON SKINS and PICKAXES, with how many of each you own.
	  Left    the picked look, turning in 3D: its name, rarity, what it is,
	          where it comes from, and WEAR (or TAKE OFF, or BUY while test
	          coin prices are on).
	  Right   STANDARD (your gear's own colours), everything you own, then
	          the ones still to get, dimmed, each saying where from.

	Drawn on the Inventory's 1600 x 840 canvas, so it scales with it.
	  Wardrobe.open(canvas, kind?)   Wardrobe.close()   Wardrobe.isOpen()
	  Wardrobe.tiles()  (for tests: the ids on show, "" for STANDARD)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local ShopArt = require(script.Parent.ShopArt)

local new = IronUi.new

local Wardrobe = {}

local C = {
	Ink = Color3.fromRGB(5, 7, 12),
	Panel = Color3.fromRGB(12, 16, 25),
	Card = Color3.fromRGB(19, 25, 37),
	Text = Color3.fromRGB(238, 242, 247),
	Dim = Color3.fromRGB(139, 155, 177),
	Faint = Color3.fromRGB(74, 90, 112),
	Line = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(242, 189, 94),
	Teal = Color3.fromRGB(86, 214, 214),
	Good = Color3.fromRGB(95, 208, 138),
	Bad = Color3.fromRGB(255, 122, 107),
	Accent = Color3.fromRGB(255, 120, 190),
}
local HEAVY, HEADING, MEDIUM = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium
local KINDS = { "Suit", "Skin", "Pick" }
local KIND_TITLE = { Suit = "SUITS", Skin = "WEAPON SKINS", Pick = "PICKAXES" }
local KIND_WIDTH = { Suit = 120, Skin = 180, Pick = 150 }
local KIND_STANDARD = {
	Suit = "Your armour in its own colours, as crafted.",
	Skin = "Your weapon in its own colours, as forged.",
	Pick = "Your pick as it came from the Probe, in its own colour.",
}
local RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

local CANVAS_W, CANVAS_H = 1600, 840
local WIN_W, WIN_H = 1360, 720
local STAGE_W = 440
local TILE_W, TILE_H = 152, 184

local state = {
	Kind = "Suit",
	Selected = nil :: string?, -- a cosmetic id, or "" for STANDARD
	Note = "",
	NoteGood = true,
	Busy = false,
}
local ui: { [string]: any } = {}
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

local function clearGui(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- The looks -----------------------------------------------------------------------------------------------

local function profile()
	return GemClient.Profile
end

local function owned(id: string): boolean
	local p = profile()
	return p ~= nil and p.Cosmetics ~= nil and p.Cosmetics.Owned ~= nil and p.Cosmetics.Owned[id] == true
end

local function worn(kind: string): string?
	local p = profile()
	return p and p.Cosmetics and p.Cosmetics[kind] or nil
end

-- Every look of a kind: what you own (rarest first), then what you don't.
local function looks(kind: string): ({ string }, { string })
	local mine, rest = {}, {}
	for _, id in Cosmetics.ofKind(kind) do
		table.insert(if owned(id) then mine else rest, id)
	end
	local function rarer(a: string, b: string): boolean
		local x, y = Cosmetics.List[a], Cosmetics.List[b]
		local rx, ry = RANK[x.Rarity] or 0, RANK[y.Rarity] or 0
		if rx ~= ry then
			return rx > ry
		end
		return x.Name < y.Name
	end
	table.sort(mine, rarer)
	return mine, rest
end

-- Drawing --------------------------------------------------------------------------------------------------

local draw -- (forward)

local function act(action: string, ...)
	if state.Busy then
		return
	end
	state.Busy = true
	local result = GemClient.request(action, ...)
	state.Busy = false
	state.Note, state.NoteGood = tostring(result.Message or ""), result.Ok == true
	if Wardrobe.isOpen() then
		draw()
	end
end

local function wear(id: string?)
	act("EquipCosmetic", state.Kind, id)
end

local function tile(parent: Instance, id: string, order: number)
	local cosmetic = if id == "" then nil else Cosmetics.get(id)
	local mine = id == "" or owned(id)
	local isWorn = (worn(state.Kind) or "") == id
	local picked = state.Selected == id
	local color = if cosmetic then Cosmetics.rarityColor(cosmetic) or C.Dim else C.Teal
	local cell = new("TextButton", {
		Name = if id == "" then "Standard" else id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if picked then color:Lerp(C.Card, 0.78) else C.Card,
		LayoutOrder = order,
	}, parent)
	cell:SetAttribute("Look", id)
	round(cell, 12)
	stroke(cell, if picked then C.Gold else color, if picked then 2 else 1, if picked then 0 else 0.7)
	box(cell, color, 12, 0, TILE_W - 24, 3)
	local stage = new("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(TILE_W - 20, TILE_W - 28),
		ClipsDescendants = true,
	}, cell)
	if cosmetic then
		ShopArt.icon(stage, "Cosmetic", id, 112)
	else
		local mark = text(stage, "◇", 54, C.Teal, HEAVY, 0, 0, TILE_W - 20, TILE_W - 28)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextTransparency = 0.35
	end
	local name = text(
		cell,
		if cosmetic then cosmetic.Name else "Standard",
		12,
		if mine then C.Text else C.Dim,
		HEADING,
		6,
		TILE_W - 14,
		TILE_W - 12,
		16
	)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local status = if isWorn
		then "WORN"
		elseif mine then if cosmetic then string.upper(Cosmetics.rarityName(cosmetic) or "") else "NO SKIN"
		else string.upper(Cosmetics.source(cosmetic :: any))
	local tag = text(
		cell,
		status,
		9,
		if isWorn then C.Gold elseif mine then color else C.Faint,
		HEADING,
		6,
		TILE_W + 4,
		TILE_W - 12,
		12
	)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextTruncate = Enum.TextTruncate.AtEnd
	if isWorn then
		local check = box(cell, C.Gold, TILE_W - 30, 10, 20, 20)
		check.Name = "WornMark"
		round(check, 10)
		local tick = text(check, "✓", 12, Color3.fromRGB(26, 18, 6), HEAVY, 0, 0, 20, 20)
		tick.TextXAlignment = Enum.TextXAlignment.Center
	end
	if not mine then
		-- Still to get: dimmed, with a lock.
		local veil = box(cell, C.Ink, 0, 0, TILE_W, TILE_H, 0.5)
		veil.Name = "Locked"
		round(veil, 12)
		local lock = text(cell, "🔒", 14, C.Dim, HEADING, 10, 8, 20, 20)
		lock.ZIndex = 10
	end
	cell:SetAttribute("UiSound", "Click")
	cell.Activated:Connect(function()
		state.Selected, state.Note = id, ""
		draw()
	end)
	return cell
end

local function section(parent: Instance, title: string, order: number)
	local head = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 26),
		LayoutOrder = order,
	}, parent)
	text(head, title, 11, C.Dim, HEADING, 2, 6, 500, 16)
	box(head, C.Line, 0, 25, 840, 1, 0.92)
	return head
end

local LIST_W = WIN_W - STAGE_W - 72
local PER_ROW = math.floor((LIST_W - 12 + 12) / (TILE_W + 12))

-- Sized for its tiles (rows of PER_ROW), so the sections stack cleanly.
local function grid(parent: Instance, order: number, count: number): Frame
	local rows = math.max(1, math.ceil(count / PER_ROW))
	local frame = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, rows * TILE_H + (rows - 1) * 12 + 2),
		LayoutOrder = order,
	}, parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE_W, TILE_H),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

local function drawTiles(mine: { string }, rest: { string })
	local list = ui.List
	clearGui(list)
	section(list, string.format("YOURS  ·  %d", #mine), 1)
	local yours = grid(list, 2, #mine + 1)
	yours.Name = "Owned"
	tile(yours, "", 0)
	for i, id in mine do
		tile(yours, id, i)
	end
	if #rest > 0 then
		section(list, string.format("STILL TO GET  ·  %d", #rest), 4)
		local more = grid(list, 5, #rest)
		more.Name = "NotOwned"
		for i, id in rest do
			tile(more, id, i)
		end
	end
	local height = 26 + 10 + (math.ceil((#mine + 1) / PER_ROW) * (TILE_H + 12))
	if #rest > 0 then
		height += 26 + 10 + math.ceil(#rest / PER_ROW) * (TILE_H + 12) + 10
	end
	list.CanvasSize = UDim2.fromOffset(0, height + 40)
	if #mine == 0 then
		local hint = new("TextLabel", {
			BackgroundTransparency = 1,
			Text = "None yet: get them in the Store, from crates and on the Season Path.",
			TextSize = 12,
			TextColor3 = C.Faint,
			Font = MEDIUM,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -12, 0, 18),
			LayoutOrder = 3,
		}, list)
		hint.Name = "Hint"
	end
end

local function drawStage()
	local stage = ui.Stage
	clearGui(stage)
	local id = state.Selected or ""
	local cosmetic = if id == "" then nil else Cosmetics.get(id)
	local color = if cosmetic then Cosmetics.rarityColor(cosmetic) or C.Dim else C.Teal
	-- The look, big and turning, over a glow in its rarity's colour.
	local glow = box(stage, color, 70, 40, 300, 300, 0.86)
	round(glow, 150)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
	}, glow)
	local view = new("Frame", {
		Name = "View",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 20),
		Size = UDim2.fromOffset(STAGE_W - 80, 340),
	}, stage)
	if cosmetic then
		ShopArt.icon(view, "Cosmetic", id, 320)
	else
		local mark = text(view, "◇", 120, C.Teal, HEAVY, 0, 0, STAGE_W - 80, 340)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextTransparency = 0.4
	end
	local mine = id == "" or owned(id)
	local isWorn = (worn(state.Kind) or "") == id
	text(stage, if cosmetic then cosmetic.Name else "Standard", 26, C.Text, HEAVY, 24, 372, STAGE_W - 48, 32).Name =
		"LookName"
	local rarity = if cosmetic then string.upper(Cosmetics.rarityName(cosmetic) or "") else "NO SKIN"
	local chip = text(stage, rarity, 11, color, HEADING, 24, 408, 200, 16)
	chip.Name = "Rarity"
	local about = text(
		stage,
		if cosmetic then cosmetic.Description or "" else KIND_STANDARD[state.Kind],
		13,
		C.Dim,
		MEDIUM,
		24,
		432,
		STAGE_W - 48,
		54
	)
	about.TextWrapped = true
	about.TextYAlignment = Enum.TextYAlignment.Top
	if cosmetic then
		local from = text(
			stage,
			"FROM  ·  " .. string.upper(Cosmetics.source(cosmetic)),
			10,
			C.Faint,
			HEADING,
			24,
			492,
			STAGE_W - 48,
			14
		)
		from.Name = "Source"
	end
	-- The one thing to do with it.
	local label, color2, run = nil, C.Teal, nil
	if isWorn and id ~= "" then
		label, color2, run = "TAKE OFF", Color3.fromRGB(110, 100, 130), function()
			wear(nil)
		end
	elseif isWorn then
		label = nil
	elseif mine then
		label, run = "WEAR", function()
			wear(if id == "" then nil else id)
		end
	elseif cosmetic and Cosmetics.coinPrice(cosmetic) then
		label, color2, run =
			string.format("BUY  ·  %d COINS", Cosmetics.coinPrice(cosmetic) :: number), C.Gold, function()
				act("BuyCosmetic", id)
			end
	end
	if isWorn then
		local on = text(stage, "✓  THIS MINER IS WEARING IT", 12, C.Gold, HEAVY, 24, 520, STAGE_W - 48, 18)
		on.Name = "WornNote"
	end
	if label then
		local action = new("TextButton", {
			Name = "Action",
			Text = label,
			TextSize = 15,
			Font = HEAVY,
			TextColor3 = Color3.fromRGB(14, 16, 22),
			AutoButtonColor = true,
			BackgroundColor3 = color2,
			Position = UDim2.fromOffset(24, if isWorn then 546 else 524),
			Size = UDim2.fromOffset(STAGE_W - 48, 46),
		}, stage)
		round(action, 10)
		action:SetAttribute("UiSound", "Confirm")
		action.Activated:Connect(run)
	elseif not mine then
		local how =
			text(stage, "Get it: " .. Cosmetics.source(cosmetic :: any), 13, C.Dim, HEADING, 24, 534, STAGE_W - 48, 20)
		how.Name = "HowToGet"
	end
end

function draw()
	if not ui.Root then
		return
	end
	local p = profile()
	local miner = p and p.Miners and p.Miners.Active or 1
	ui.Sub.Text = string.format("MINER %d  ·  EACH MINER WEARS ITS OWN LOOK", miner)
	for _, kind in KINDS do
		local mine = looks(kind)
		local tab = ui.Tabs[kind]
		local on = kind == state.Kind
		tab.Text = string.format("%s  %d", KIND_TITLE[kind], #mine)
		tab.TextColor3 = if on then Color3.fromRGB(14, 16, 22) else C.Dim
		tab.BackgroundColor3 = if on then C.Gold else C.Card
	end
	local mine, rest = looks(state.Kind)
	if state.Selected == nil then
		state.Selected = worn(state.Kind) or ""
	end
	drawTiles(mine, rest)
	drawStage()
	ui.Note.Text = state.Note
	ui.Note.TextColor3 = if state.NoteGood then C.Good else C.Bad
end

local function build(canvas: Instance)
	local scrim = new("TextButton", {
		Name = "Wardrobe",
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
	text(window, "WARDROBE", 28, C.Text, HEAVY, 28, 20, 220, 34)
	ui.Sub = text(window, "", 11, C.Dim, HEADING, 236, 32, 340, 16)
	ui.Tabs = {}
	local tx = 590
	for _, kind in KINDS do
		local w = KIND_WIDTH[kind]
		local tab = button(window, KIND_TITLE[kind], tx, 22, w, 32)
		tab.Name = kind .. "Tab"
		tab.Font = HEAVY
		ui.Tabs[kind] = tab
		tab.Activated:Connect(function()
			if state.Kind ~= kind then
				state.Kind, state.Selected, state.Note = kind, nil, ""
				draw()
			end
		end)
		tx += w + 8
	end
	local close = button(window, "✕", WIN_W - 58, 18, 38, 38)
	close.Name = "Close"
	close.TextSize = 18
	close.TextColor3 = C.Text
	close:SetAttribute("UiSound", "Back")
	close.Activated:Connect(function()
		Wardrobe.close()
	end)
	box(window, C.Line, 24, 70, WIN_W - 48, 1, 0.92)
	-- The picked look.
	local stage = box(window, C.Card, 24, 86, STAGE_W, WIN_H - 110, 0.35)
	stage.Name = "LookStage"
	round(stage, 14)
	stroke(stage, C.Line, 1, 0.9)
	ui.Stage = stage
	-- Every look.
	local list = new("ScrollingFrame", {
		Name = "Looks",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(STAGE_W + 48, 86),
		Size = UDim2.fromOffset(LIST_W, WIN_H - 110),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
	}, window)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, list)
	ui.List = list
	ui.Note = text(window, "", 12, C.Good, HEADING, 28, WIN_H - 22, 600, 16)
	ui.Note.Name = "Note"
	return scrim
end

function Wardrobe.isOpen(): boolean
	return ui.Root ~= nil and ui.Root.Parent ~= nil
end

function Wardrobe.open(canvas: Instance, kind: string?)
	if Wardrobe.isOpen() then
		Wardrobe.close()
	end
	if KIND_TITLE[kind or ""] then
		state.Kind = kind :: string
	end
	state.Selected, state.Note = nil, ""
	ui = {}
	ui.Root = build(canvas)
	changed = GemClient.Changed:Connect(function()
		if Wardrobe.isOpen() then
			draw()
		end
	end)
	draw()
end

function Wardrobe.close()
	if changed then
		changed:Disconnect()
		changed = nil
	end
	if ui.Root then
		ui.Root:Destroy()
	end
	ui = {}
end

-- For tests: the looks on show, in order ("" is STANDARD).
function Wardrobe.tiles(): { string }
	local out = {}
	local mine, rest = looks(state.Kind)
	table.insert(out, "")
	for _, id in mine do
		table.insert(out, id)
	end
	for _, id in rest do
		table.insert(out, id)
	end
	return out
end

return Wardrobe
