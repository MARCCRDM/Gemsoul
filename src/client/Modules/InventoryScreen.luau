--[[
	The Inventory (dashboard): two panels and a bar.

	  Left (stays put)   who you are, your six ratings, your armor and weapon
	                     loadouts (Shared.GearPresets, three slots each), the
	                     six worn pieces with their gem sockets, and the Surge
	                     Array (Q / E / R)
	  Right (changes)    OVERVIEW  what you picked: stats, gem, what equipping
	                               it changes, and its buttons
	                     ARMOR     spare gear, filtered by slot
	                     GEMS      your gems; drag one onto a matching socket
	  Bottom             the other screens (Surge Array, Augment Tree, Season,
	                     Market, Store) and Back to Lobby

	Drag a gem onto a worn piece (socket it) or a Q / E / R key (put its
	surge on that key); drag spare gear onto its slot (equip it). The server
	checks every move.

	  InventoryScreen.mount(parent, hostGui, position)
	  InventoryScreen.refresh()
	  InventoryScreen.cancelDrag()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local InventoryScreen = {}

-- Look ------------------------------------------------------------------------------------------------

InventoryScreen.Colors = {
	Panel = Color3.fromRGB(23, 18, 40),
	PanelEdge = Color3.fromRGB(47, 39, 80),
	Card = Color3.fromRGB(31, 25, 54),
	CardHover = Color3.fromRGB(40, 33, 68),
	Track = Color3.fromRGB(44, 37, 69),
	TabBar = Color3.fromRGB(17, 13, 31),
	TabOn = Color3.fromRGB(44, 36, 71),
	TabEdge = Color3.fromRGB(75, 63, 122),
	Text = Color3.fromRGB(242, 238, 252),
	Dim = Color3.fromRGB(143, 134, 173),
	Faint = Color3.fromRGB(88, 80, 118),
	Gold = Color3.fromRGB(255, 200, 61),
	Good = Color3.fromRGB(62, 224, 122),
	Bad = Color3.fromRGB(255, 92, 110),
	Accent = Color3.fromRGB(168, 120, 255),
	Pink = Color3.fromRGB(255, 111, 174),
}
local C = InventoryScreen.Colors
local STAT = {
	Health = Color3.fromRGB(62, 224, 122),
	Power = Color3.fromRGB(255, 138, 61),
	Defense = Color3.fromRGB(79, 163, 255),
	Speed = Color3.fromRGB(169, 139, 255),
	Rating = Color3.fromRGB(255, 200, 61),
	Attuned = Color3.fromRGB(255, 79, 139),
}
local RARITY = {
	Color3.fromRGB(122, 116, 150), -- Common
	Color3.fromRGB(62, 207, 110), -- Uncommon
	Color3.fromRGB(79, 141, 255), -- Rare
	Color3.fromRGB(163, 91, 255), -- Ultra Rare
	Color3.fromRGB(255, 159, 46), -- Legendary
}
local GEM_RARITY = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local SLOT_ICON =
	{ Helmet = "⛑️", Armor = "🦺", Gloves = "🧤", Boots = "🥾", Weapon = "⚔️", Shield = "🛡️" }
local SLOT_LABEL =
	{ Helmet = "HELMET", Armor = "CHEST", Gloves = "GLOVES", Boots = "BOOTS", Weapon = "WEAPON", Shield = "SHIELD" }
local ELEMENT_ICON = { Fire = "🔥", Frost = "❄️", Shock = "⚡", Poison = "☣️" }
local ELEMENT_COLOR = {
	Fire = Color3.fromRGB(255, 122, 61),
	Frost = Color3.fromRGB(110, 200, 255),
	Shock = Color3.fromRGB(255, 214, 72),
	Poison = Color3.fromRGB(120, 230, 110),
}
local BLACK, BOLD, BODY = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium

local W, H = 1400, 530
local LEFT_W, RIGHT_X, PANEL_H = 810, 826, 480

local function round(object: GuiObject, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end
local function stroke(object: GuiObject, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end
local function label(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or BOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function at(object: GuiObject, x: number, y: number, w: number, h: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
	return object
end
local function box(parent: Instance, color: Color3, radius: number): Frame
	local frame = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
	round(frame, radius)
	return frame
end
local function button(parent: Instance, caption: string, fill: Color3, textColor: Color3, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = caption,
		TextSize = 12,
		Font = BOLD,
		TextColor3 = textColor,
		BackgroundColor3 = fill,
		AutoButtonColor = true,
	}, parent)
	round(b, 8)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end
local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end
local function whole(value: number): string
	return tostring(math.floor(value + 0.5))
end

-- Requests ---------------------------------------------------------------------------------------------

local function request(action: string, ...)
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then C.Good else C.Bad)
		end
	end)
end

-- Data helpers -----------------------------------------------------------------------------------------

local function profileNow()
	return GemClient.Profile
end
local function loadoutNow()
	local profile = profileNow()
	return profile and profile.Character or {}
end
local function gearOf(loadout, slot: string, id: string?)
	local gearId = id or loadout[slot]
	return gearId and loadout.Class and Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, gearId) or nil
end
local function rarityOf(loadout, slot: string, id: string?): number
	local roll = GearRolls.get(loadout, slot, id)
	return if roll then roll.Rarity else 1
end
local function rarityName(rarity: number): string
	local entry = GearRolls.Rarities[rarity]
	return string.upper(entry and entry.Name or "Common")
end
local function gemRarity(gem): number
	return GEM_RARITY[gem.Tier] or 1
end
local function gemName(gem): string
	if gem.Cut then
		local surge = Tech.surgeStats(gem)
		if surge then
			return surge.Name
		end
	end
	return GemConfig.displayName(gem)
end
local function statText(stat: string, amount: number): string
	if stat == "Critical" or stat == "Cooldown" then
		return string.format("+%s%% %s", whole(amount * 100), stat)
	end
	return string.format("+%s %s", whole(amount), stat)
end

-- Root ---------------------------------------------------------------------------------------------------

local root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H) })
local hostGui: ScreenGui? = nil

local function panel(x: number, y: number, w: number, h: number): Frame
	local frame = box(root, Color3.new(1, 1, 1), 16)
	at(frame, x, y, w, h)
	stroke(frame, C.PanelEdge, 1)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(29, 23, 50), C.Panel),
	}, frame)
	return frame
end
local left = panel(0, 0, LEFT_W, PANEL_H)
local right = panel(RIGHT_X, 0, W - RIGHT_X, PANEL_H)

-- Selection and drag state.
type Pick = { Kind: string, Slot: string?, Id: string?, Gem: any?, Key: string? }
local selection: Pick? = nil
local tab = "Overview"
local armorFilter = "All"
local dropTargets: { { Frame: GuiObject, Accepts: (any) -> boolean, Drop: (any) -> (), Stroke: UIStroke?, Base: Color3? } } =
	{}
local drag: { Item: any, Start: Vector2, Active: boolean, Touch: boolean, Ghost: Frame? }? = nil
local suppressClickUntil = 0
local draw -- (below): redraws everything

-- Picking on the left shows it in OVERVIEW; picking in a bag highlights it
-- there, and picking it again opens OVERVIEW.
local function samePick(a: Pick?, b: Pick?): boolean
	if a == nil or b == nil or a.Kind ~= b.Kind then
		return false
	end
	if a.Kind == "Gem" then
		return a.Gem.Id == (b.Gem :: any).Id
	end
	return a.Slot == b.Slot and a.Id == b.Id and a.Key == b.Key
end
local function select(pick: Pick?, fromBag: boolean?)
	local again = samePick(selection, pick)
	selection = pick
	if not fromBag or again then
		tab = "Overview"
	end
	draw()
end

-- Left: profile and ratings -------------------------------------------------------------------------

local avatar = box(left, Color3.new(1, 1, 1), 14)
at(avatar, 20, 18, 58, 58)
new("UIGradient", {
	Rotation = 45,
	Color = ColorSequence.new(Color3.fromRGB(123, 92, 255), Color3.fromRGB(176, 98, 255)),
}, avatar)
local avatarIcon = label(avatar, "🛡️", 30, C.Text)
avatarIcon.Size = UDim2.fromScale(1, 1)
avatarIcon.TextXAlignment = Enum.TextXAlignment.Center
local nameLabel = at(label(left, "", 26, C.Text, BLACK), 92, 18, 520, 32)
local subtitle = at(label(left, "", 12, C.Dim, BOLD), 92, 50, 600, 18)
subtitle.RichText = true

local statTiles = {}
for i, name in { "Health", "Power", "Defense", "Speed", "Rating", "Attuned" } do
	local tile = box(left, C.Card, 12)
	at(tile, 20 + (i - 1) * 130, 92, 120, 64)
	stroke(tile, C.PanelEdge, 1)
	at(label(tile, string.upper(name), 10, STAT[name], BOLD), 12, 8, 100, 14)
	local value = at(label(tile, "0", 22, STAT[name], BLACK), 12, 22, 100, 26)
	local track = box(tile, C.Track, 2)
	at(track, 12, 52, 96, 4)
	local fill = box(track, STAT[name], 2)
	fill.Size = UDim2.fromScale(0, 1)
	statTiles[name] = { Value = value, Fill = fill }
end

-- Left: the 3 x 3 grid -------------------------------------------------------------------------------------

local GRID_X, GRID_Y, CELL_W, CELL_H, GAP = 20, 172, 250, 92, 10
local function cellAt(column: number, row: number): Frame
	local cell = box(left, C.Card, 12)
	at(cell, GRID_X + (column - 1) * (CELL_W + GAP), GRID_Y + (row - 1) * (CELL_H + GAP), CELL_W, CELL_H)
	return cell
end

-- Loadout pickers (Shared.GearPresets): pick a slot, then WEAR or SAVE.
local chosenSlot = { Armor = 1, Weapon = 1 }
local pickers = {}
local function loadoutPicker(part: string, column: number)
	local cell = cellAt(column, 1)
	cell.BackgroundTransparency = 0.35
	stroke(cell, C.PanelEdge, 1)
	at(label(cell, string.upper(GearPresets.Parts[part].Label) .. " LOADOUT", 10, C.Dim, BOLD), 14, 8, 220, 14)
	local chips = {}
	for slot = 1, GearPresets.Count do
		local chip = new("TextButton", {
			Text = tostring(slot),
			TextSize = 14,
			Font = BLACK,
			AutoButtonColor = true,
		}, cell)
		at(chip, 14 + (slot - 1) * 44, 28, 38, 32)
		round(chip, 8)
		local edge = stroke(chip, C.PanelEdge, 1.5)
		chip:SetAttribute("UiSound", "Click")
		chip.Activated:Connect(function()
			chosenSlot[part] = slot
			draw()
		end)
		chips[slot] = { Button = chip, Stroke = edge }
	end
	local wear = button(cell, "WEAR", C.Accent, C.Text, function()
		request("PresetApply", part, chosenSlot[part])
	end)
	at(wear, 150, 28, 42, 32)
	local save = button(cell, "SAVE", C.TabOn, C.Text, function()
		request("PresetSave", part, chosenSlot[part])
	end)
	at(save, 196, 28, 42, 32)
	stroke(save, C.TabEdge, 1)
	local hint = at(label(cell, "", 10, C.Dim, BODY), 14, 66, 222, 16)
	pickers[part] = { Chips = chips, Wear = wear, Hint = hint }
end
loadoutPicker("Armor", 1)
loadoutPicker("Weapon", 3)

-- The worn pieces.
local wornCards = {}
local function wornCard(slot: string, column: number, row: number)
	local cell = cellAt(column, row)
	cell.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient carries the colour
	local edge = stroke(cell, RARITY[1], 1.5)
	local glow = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.Card, C.Card),
	}, cell)
	local hit =
		new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, cell)
	hit:SetAttribute("UiSound", "Click")
	at(label(cell, SLOT_LABEL[slot], 10, C.Dim, BOLD), 14, 8, 160, 14)
	local icon = at(label(cell, SLOT_ICON[slot], 24, C.Text), 14, 28, 36, 36)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local name = at(label(cell, "", 13, C.Text, BOLD), 58, 30, 180, 18)
	local rarity = at(label(cell, "", 10, C.Dim, BOLD), 58, 52, 180, 14)
	local socket = box(cell, C.TabBar, 6)
	at(socket, CELL_W - 34, 8, 24, 24)
	local socketEdge = stroke(socket, C.PanelEdge, 1.2)
	local socketIcon = label(socket, "+", 12, C.Faint, BOLD)
	socketIcon.Size = UDim2.fromScale(1, 1)
	socketIcon.TextXAlignment = Enum.TextXAlignment.Center
	hit.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			select({ Kind = "Worn", Slot = slot })
		end
	end)
	wornCards[slot] = {
		Cell = cell,
		Stroke = edge,
		Glow = glow,
		Name = name,
		Rarity = rarity,
		Socket = socket,
		SocketEdge = socketEdge,
		SocketIcon = socketIcon,
	}
	table.insert(dropTargets, {
		Frame = cell,
		Stroke = edge,
		Accepts = function(item)
			return (item.Kind == "Gem" and item.Gem.Cut ~= nil) or (item.Kind == "Spare" and item.Slot == slot)
		end,
		Drop = function(item)
			if item.Kind == "Gem" then
				request("SocketGem", item.Gem.Id, slot)
			else
				request("EquipGear", Slots.Definitions[slot].Kind, item.Id)
			end
		end,
	})
end
wornCard("Helmet", 2, 1)
wornCard("Weapon", 1, 2)
wornCard("Armor", 2, 2)
wornCard("Shield", 3, 2)
wornCard("Gloves", 1, 3)
wornCard("Boots", 2, 3)

-- The Surge Array: Q / E / R keys.
local surgeCell = cellAt(3, 3)
stroke(surgeCell, C.PanelEdge, 1)
at(label(surgeCell, "SURGE ARRAY", 10, C.Dim, BOLD), 14, 8, 160, 14)
local surgeKeys = {}
for i, key in { "Q", "E", "R" } do
	local keyBox = new("TextButton", { Text = "", BackgroundColor3 = C.TabBar, AutoButtonColor = true }, surgeCell)
	at(keyBox, 14 + (i - 1) * 76, 28, 68, 54)
	round(keyBox, 8)
	keyBox:SetAttribute("UiSound", "Click")
	local edge = stroke(keyBox, C.PanelEdge, 1.5)
	local letter = at(label(keyBox, key, 16, C.Text, BLACK), 0, 6, 68, 20)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	local name = at(label(keyBox, "", 9, C.Dim, BOLD), 4, 30, 60, 16)
	name.TextXAlignment = Enum.TextXAlignment.Center
	keyBox.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			select({ Kind = "Key", Key = key })
		end
	end)
	surgeKeys[key] = { Box = keyBox, Stroke = edge, Name = name, Letter = letter }
	table.insert(dropTargets, {
		Frame = keyBox,
		Stroke = edge,
		Accepts = function(item)
			return item.Kind == "Gem" and item.Gem.Cut ~= nil
		end,
		Drop = function(item)
			request("SocketSurge", item.Gem.Id, key)
		end,
	})
end

-- Right: tabs and pages ------------------------------------------------------------------------------------

local RIGHT_W = W - RIGHT_X
local tabBar = box(right, C.TabBar, 12)
at(tabBar, 16, 16, RIGHT_W - 32, 42)
local tabButtons = {}
for i, id in { "Overview", "Armor", "Gems" } do
	local b = new("TextButton", {
		Text = string.upper(id),
		TextSize = 12,
		Font = BOLD,
		AutoButtonColor = false,
		BackgroundColor3 = C.TabOn,
	}, tabBar)
	local width = (RIGHT_W - 32 - 16) / 3
	at(b, 4 + (i - 1) * (width + 4), 4, width, 34)
	round(b, 9)
	b:SetAttribute("UiSound", "Tab")
	local edge = stroke(b, C.TabEdge, 1)
	b.Activated:Connect(function()
		tab = id
		draw()
	end)
	tabButtons[id] = { Button = b, Stroke = edge }
end
local page = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true }, right)
at(page, 16, 68, RIGHT_W - 32, PANEL_H - 68 - 40)
local footerLine = box(right, C.PanelEdge, 0)
at(footerLine, 16, PANEL_H - 38, RIGHT_W - 32, 1)
local footer = at(label(right, "", 10, C.Dim, BOLD), 16, PANEL_H - 32, RIGHT_W - 32, 20)
footer.TextXAlignment = Enum.TextXAlignment.Center

local function scroller(parent: Instance, y: number): ScrollingFrame
	local frame = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.TabEdge,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 1, -y),
	}, parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 88),
		CellPadding = UDim2.fromOffset(9, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	new(
		"UIPadding",
		{ PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1) },
		frame
	)
	return frame
end

-- Dragging -----------------------------------------------------------------------------------------------

local function targetAt(point: Vector2, item)
	for _, target in dropTargets do
		local frame = target.Frame
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		if
			frame.Visible
			and target.Accepts(item)
			and point.X >= p.X
			and point.Y >= p.Y
			and point.X < p.X + s.X
			and point.Y < p.Y + s.Y
		then
			return target
		end
	end
	return nil
end
local function lightTargets(item)
	for _, target in dropTargets do
		if target.Stroke then
			if target.Base == nil then
				target.Base = target.Stroke.Color
			end
			local ok = item ~= nil and target.Accepts(item)
			target.Stroke.Color = if ok then C.Gold else target.Base :: Color3
			target.Stroke.Thickness = if ok then 2.5 else 1.5
		end
	end
	if item == nil then
		for _, target in dropTargets do
			target.Base = nil
		end
	end
end
function InventoryScreen.cancelDrag()
	if drag and drag.Ghost then
		drag.Ghost:Destroy()
	end
	drag = nil
	lightTargets(nil)
	draw()
end
local function pointOf(input: InputObject, touch: boolean): Vector2
	return if touch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
end
local function startDrag(item, input: InputObject)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and not touch then
		return
	end
	drag = { Item = item, Start = pointOf(input, touch), Active = false, Touch = touch }
end
UserInputService.InputChanged:Connect(function(input)
	local current = drag
	if not current then
		return
	end
	local moving = input.UserInputType == Enum.UserInputType.MouseMovement
		or (current.Touch and input.UserInputType == Enum.UserInputType.Touch)
	if not moving then
		return
	end
	local point = pointOf(input, current.Touch)
	if not current.Active then
		if (point - current.Start).Magnitude < 8 then
			return
		end
		current.Active = true
		local ghost = box(hostGui or root, C.CardHover, 10)
		ghost.Size = UDim2.fromOffset(150, 40)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.ZIndex = 50
		stroke(ghost, C.Gold, 2)
		local caption = current.Item.Kind == "Gem" and gemName(current.Item.Gem)
			or "Equip " .. SLOT_LABEL[current.Item.Slot]
		local text = label(ghost, caption, 12, C.Text, BOLD)
		text.Size = UDim2.fromScale(1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.ZIndex = 51
		current.Ghost = ghost
		lightTargets(current.Item)
	end
	if current.Ghost then
		current.Ghost.Position = UDim2.fromOffset(point.X, point.Y - (if current.Touch then 40 else 0))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local current = drag
	if not current then
		return
	end
	local ending = input.UserInputType == Enum.UserInputType.MouseButton1
		or (current.Touch and input.UserInputType == Enum.UserInputType.Touch)
	if not ending then
		return
	end
	drag = nil
	if current.Ghost then
		current.Ghost:Destroy()
	end
	lightTargets(nil)
	if current.Active then
		suppressClickUntil = os.clock() + 0.25
		local target = targetAt(pointOf(input, current.Touch), current.Item)
		if target then
			target.Drop(current.Item)
		elseif current.Item.Kind == "Gem" and current.Item.Gem.Cut == nil then
			UiKit.toast("Cut this gem before it can be socketed.", C.Bad)
		end
	end
end)

-- Right: cards for the bags --------------------------------------------------------------------------

local function itemCard(
	parent: Instance,
	order: number,
	icon: string,
	title: string,
	rarity: number,
	tag: string,
	tagColor: Color3,
	onClick: () -> (),
	dragItem
)
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.Card,
		LayoutOrder = order,
	}, parent)
	round(card, 12)
	card:SetAttribute("UiSound", "Click")
	local color = RARITY[rarity] or RARITY[1]
	stroke(card, color, 1.5, 0.15)
	local glyph = at(label(card, icon, 20, C.Text), 12, 10, 28, 26)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	at(label(card, title, 12, color:Lerp(C.Text, 0.35), BOLD), 12, 42, 146, 16)
	at(label(card, rarityName(rarity), 9, color, BOLD), 12, 62, 146, 14)
	local badge = new("TextLabel", {
		Text = tag,
		TextSize = 9,
		Font = BOLD,
		TextColor3 = tagColor,
		BackgroundColor3 = C.TabBar,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
	}, card)
	round(badge, 5)
	stroke(badge, tagColor, 1, 0.4)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, badge)
	card.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			onClick()
		end
	end)
	if dragItem then
		card.InputBegan:Connect(function(input)
			startDrag(dragItem, input)
		end)
	end
	if selection and dragItem then
		local same = (selection.Kind == "Gem" and dragItem.Kind == "Gem" and selection.Gem.Id == dragItem.Gem.Id)
			or (selection.Kind == "Spare" and dragItem.Kind == "Spare" and selection.Id == dragItem.Id)
		if same then
			stroke(card, C.Gold, 2.5)
		end
	end
	return card
end

local function emptyNote(parent: Instance, text: string)
	local note = label(parent, text, 13, C.Dim, BOLD)
	note.Size = UDim2.new(1, 0, 0, 80)
	note.Position = UDim2.fromOffset(0, 60)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextWrapped = true
end

-- GEMS: every gem in the pouch, best first.
local function drawGems()
	local profile = profileNow()
	local gems = table.clone(profile and profile.Gems or {})
	table.sort(gems, function(a, b)
		local ra, rb = gemRarity(a), gemRarity(b)
		if ra ~= rb then
			return ra > rb
		end
		if (a.Cut ~= nil) ~= (b.Cut ~= nil) then
			return a.Cut ~= nil
		end
		return (a.Element or "") < (b.Element or "")
	end)
	local grid = scroller(page, 0)
	if #gems == 0 then
		emptyNote(page, "No gems yet.\nMine rocks at the Outpost to find some.")
	end
	for order, gem in gems do
		local element = gem.Element or "Fire"
		local tag = if gem.Cut then string.upper(GemConfig.elementName(element)) else "ROUGH"
		itemCard(
			grid,
			order,
			ELEMENT_ICON[element] or "◆",
			gemName(gem),
			gemRarity(gem),
			tag,
			if gem.Cut then ELEMENT_COLOR[element] or C.Text else C.Faint,
			function()
				select({ Kind = "Gem", Gem = gem }, true)
			end,
			{ Kind = "Gem", Gem = gem }
		)
	end
	footer.Text = if selection and selection.Kind == "Gem"
		then string.upper(gemName(selection.Gem)) .. "  ·  TAP AGAIN FOR DETAILS, OR DRAG IT ONTO A SOCKET"
		else "DRAG A GEM ONTO A GEAR SOCKET OR A Q · E · R KEY"
end

-- ARMOR: spare gear, filtered by slot.
local FILTERS = {
	{ "All", "ALL" },
	{ "Helmet", "HEAD" },
	{ "Armor", "BODY" },
	{ "Gloves", "HANDS" },
	{ "Boots", "FEET" },
	{ "Weapon", "WEAPON" },
	{ "Shield", "SHIELD" },
}
local function drawArmor()
	local profile = profileNow()
	local loadout = loadoutNow()
	local chips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, page)
	UiKit.list(chips, 6, true)
	for i, filter in FILTERS do
		local on = armorFilter == filter[1]
		local chip = new("TextButton", {
			Text = filter[2],
			TextSize = 10,
			Font = BOLD,
			TextColor3 = if on then C.TabBar else C.Dim,
			BackgroundColor3 = if on then C.Gold else C.TabBar,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
		}, chips)
		round(chip, 13)
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chip)
		chip.Activated:Connect(function()
			armorFilter = filter[1]
			draw()
		end)
	end
	local grid = scroller(page, 36)
	local items = {}
	for order, slot in Slots.Order do
		if armorFilter == "All" or armorFilter == slot then
			local kind = Slots.Definitions[slot].Kind
			for id in (profile and profile.Owned and profile.Owned[kind]) or {} do
				local gear = gearOf(loadout, slot, id)
				if gear and id ~= loadout[slot] then
					table.insert(
						items,
						{ Slot = slot, Id = id, Gear = gear, Rarity = rarityOf(loadout, slot, id), Order = order }
					)
				end
			end
		end
	end
	table.sort(items, function(a, b)
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		if a.Order ~= b.Order then
			return a.Order < b.Order
		end
		return a.Id < b.Id
	end)
	if #items == 0 then
		emptyNote(page, "No spare gear here.\nRecover more in the mine or trade for it.")
	end
	for order, item in items do
		itemCard(
			grid,
			order,
			SLOT_ICON[item.Slot],
			item.Gear.Name,
			item.Rarity,
			SLOT_LABEL[item.Slot],
			C.Dim,
			function()
				select({ Kind = "Spare", Slot = item.Slot, Id = item.Id }, true)
			end,
			{ Kind = "Spare", Slot = item.Slot, Id = item.Id }
		)
	end
	footer.Text = if selection and selection.Kind == "Spare"
		then "TAP AGAIN TO COMPARE AND EQUIP, OR DRAG IT ONTO ITS SLOT"
		else "DRAG SPARE GEAR ONTO ITS SLOT, OR PICK IT TO COMPARE"
end

-- OVERVIEW: what's picked, or a summary.
local function line(parent: Instance, order: number, value: string, size: number, color: Color3, font: Enum.Font?)
	local l = label(parent, value, size, color, font or BODY)
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	l.LayoutOrder = order
	return l
end
local function chipRow(parent: Instance, order: number, chips: { any })
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = order,
	}, parent)
	UiKit.list(row, 6, true)
	for i, chip in chips do
		local item = chip :: any
		local tag = new("TextLabel", {
			Text = item[1],
			TextSize = 11,
			Font = BOLD,
			TextColor3 = item[2],
			BackgroundColor3 = C.TabBar,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
		}, row)
		round(tag, 6)
		stroke(tag, item[2], 1, 0.5)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tag)
	end
	return row
end
local function actions(parent: Instance, order: number, list: { { any } })
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = order,
	}, parent)
	UiKit.list(row, 8, true)
	for i, spec in list do
		local b = button(row, spec[1], spec[2], spec[3] or C.Text, spec[4])
		b.Size = UDim2.fromOffset(spec[5] or 150, 36)
		b.LayoutOrder = i
		b.TextSize = 13
	end
end
local function header(parent: Instance, icon: string, title: string, sub: string, color: Color3)
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 0 }, parent)
	local tile = box(top, C.Card, 12)
	at(tile, 0, 0, 64, 64)
	stroke(tile, color, 1.5)
	local glyph = label(tile, icon, 30, C.Text)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	at(label(top, title, 18, color:Lerp(C.Text, 0.3), BLACK), 78, 6, 440, 26)
	at(label(top, sub, 11, color, BOLD), 78, 36, 440, 18)
end
local function ratingDelta(loadout, slot: string, id: string)
	local before = Classes.ratings(loadout)
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	local quality = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
	trial[slot .. "Quality"] = quality
	trial[slot .. "Gem"] = (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]) or nil
	local after = Classes.ratings(trial)
	local chips = {}
	for _, stat in Classes.StatNames do
		local d = (after[stat].Base + after[stat].Bonus) - (before[stat].Base + before[stat].Bonus)
		if math.abs(d) >= 0.5 then
			table.insert(
				chips,
				{ string.format("%s %s%s", stat, if d > 0 then "+" else "", whole(d)), if d > 0 then C.Good else C.Bad }
			)
		end
	end
	if #chips == 0 then
		table.insert(chips, { "No rating change", C.Dim })
	end
	return chips
end
local function drawOverview()
	local loadout = loadoutNow()
	local holder = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.TabEdge,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 1),
	}, page)
	local list = UiKit.list(holder, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	new("UIPadding", { PaddingRight = UDim.new(0, 8) }, holder)
	local pick = selection
	footer.Text = "PICK A PIECE, A GEM OR A SURGE KEY TO SEE IT HERE"
	if pick and (pick.Kind == "Worn" or pick.Kind == "Spare") then
		local slot = pick.Slot :: string
		local id = if pick.Kind == "Spare" then pick.Id else loadout[slot]
		local gear = gearOf(loadout, slot, id)
		if not gear then
			selection = nil
			clear(page)
			return drawOverview()
		end
		local rarity = rarityOf(loadout, slot, id)
		local color = RARITY[rarity]
		local gem = if pick.Kind == "Worn"
			then loadout[slot .. "Gem"]
			else (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id])
		header(
			holder,
			SLOT_ICON[slot],
			GemConfig.itemName(gear.Name, gem, slot),
			string.format(
				"%s  ·  %s%s",
				rarityName(rarity),
				SLOT_LABEL[slot],
				if pick.Kind == "Spare" then "  ·  SPARE" else "  ·  WORN"
			),
			color
		)
		local roll = GearRolls.get(loadout, slot, id)
		local stats = {}
		for stat, amount in roll and roll.Stats or {} do
			table.insert(stats, { statText(stat, amount), C.Text })
		end
		table.sort(stats, function(a, b)
			return a[1] < b[1]
		end)
		if #stats > 0 then
			line(holder, 1, "ROLLED STATS", 10, C.Dim, BOLD)
			chipRow(holder, 2, stats)
		end
		local passive = gear.Passive
		if passive and passive.Text then
			line(holder, 3, string.upper(passive.Name or "PASSIVE"), 10, C.Dim, BOLD)
			line(holder, 4, passive.Text, 12, C.Text)
		end
		line(holder, 5, "GEM SOCKET", 10, C.Dim, BOLD)
		if gem then
			local name, effect = GemConfig.enchantment(gem, slot)
			line(
				holder,
				6,
				string.format("%s %s: %s", ELEMENT_ICON[gem.Element] or "◆", name, effect),
				12,
				ELEMENT_COLOR[gem.Element] or C.Text,
				BOLD
			)
		else
			line(holder, 6, "Empty. Drag a cut gem from GEMS onto this piece.", 12, C.Dim)
		end
		if pick.Kind == "Spare" then
			line(holder, 7, "IF EQUIPPED", 10, C.Dim, BOLD)
			chipRow(holder, 8, ratingDelta(loadout, slot, id :: string))
			actions(holder, 9, {
				{
					"EQUIP",
					C.Accent,
					C.Text,
					function()
						request("EquipGear", Slots.Definitions[slot].Kind, id)
					end,
				},
			})
		elseif gem then
			actions(holder, 9, {
				{
					"REMOVE GEM",
					C.TabOn,
					C.Text,
					function()
						request("UnsocketGem", slot)
					end,
				},
			})
		end
		return
	end
	if pick and pick.Kind == "Gem" then
		local gem = pick.Gem
		local element = gem.Element or "Fire"
		local color = ELEMENT_COLOR[element] or C.Text
		header(
			holder,
			ELEMENT_ICON[element] or "◆",
			gemName(gem),
			string.format(
				"%s  ·  %s%s",
				rarityName(gemRarity(gem)),
				string.upper(GemConfig.elementName(element)),
				if gem.Cut then "" else "  ·  ROUGH"
			),
			color
		)
		chipRow(holder, 1, {
			{ "Size " .. tostring(gem.Size or "?"), C.Text },
			{ "Clarity " .. tostring(gem.Clarity or "?"), C.Text },
			{ "Cut " .. (if gem.Cut then tostring(gem.Cut) else "rough"), if gem.Cut then C.Text else C.Dim },
		})
		local surge = gem.Cut and Tech.surgeStats(gem)
		if surge then
			line(holder, 2, "SURGE  ·  " .. string.upper(surge.Name), 10, C.Dim, BOLD)
			line(holder, 3, surge.Description or "", 12, C.Text)
			chipRow(holder, 4, {
				{ string.format("%s %s", whole(surge.Cost or 0), surge.Resource or "Charge"), C.Accent },
				{ string.format("%ss cooldown", whole(surge.Cooldown or 0)), C.Dim },
			})
			actions(holder, 5, {
				{
					"PUT ON Q",
					C.TabOn,
					C.Text,
					function()
						request("SocketSurge", gem.Id, "Q")
					end,
					100,
				},
				{
					"PUT ON E",
					C.TabOn,
					C.Text,
					function()
						request("SocketSurge", gem.Id, "E")
					end,
					100,
				},
				{
					"PUT ON R",
					C.TabOn,
					C.Text,
					function()
						request("SocketSurge", gem.Id, "R")
					end,
					100,
				},
			})
			line(holder, 6, "Or drag it onto a gear socket to enchant that piece.", 11, C.Dim)
		else
			line(holder, 2, "A rough gem: cut it before it can be socketed.", 12, C.Dim)
		end
		return
	end
	if pick and pick.Kind == "Key" then
		local key = pick.Key :: string
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		if gem and surge then
			local color = ELEMENT_COLOR[gem.Element] or C.Text
			header(
				holder,
				ELEMENT_ICON[gem.Element] or "◆",
				surge.Name,
				"ON KEY " .. key .. "  ·  " .. rarityName(gemRarity(gem)),
				color
			)
			line(holder, 1, surge.Description or "", 12, C.Text)
			chipRow(holder, 2, {
				{ string.format("%s %s", whole(surge.Cost or 0), surge.Resource or "Charge"), C.Accent },
				{ string.format("%ss cooldown", whole(surge.Cooldown or 0)), C.Dim },
			})
			actions(holder, 3, {
				{
					"REMOVE FROM " .. key,
					C.TabOn,
					C.Text,
					function()
						request("UnsocketSurge", key)
					end,
				},
			})
		else
			header(holder, "⌨️", "Key " .. key .. " is empty", "SURGE ARRAY", C.Dim)
			line(holder, 1, "Drag a cut gem from GEMS onto this key to cast its surge with " .. key .. ".", 12, C.Dim)
		end
		return
	end
	-- Nothing picked: the build at a glance.
	local class = loadout.Class and Classes.get(loadout.Class)
	header(holder, "🛡️", class and class.Name or "Miner", "YOUR BUILD", C.Accent)
	local sets = {}
	local active = loadout.Class and Classes.setState(loadout).Active or {}
	for _, family in ArmorFamilies.Order do
		local state = active[family]
		if state and state.Count > 0 then
			table.insert(sets, { string.format("%s %d/6", family, state.Count), C.Gold })
		end
	end
	line(holder, 1, "ARMOR SETS", 10, C.Dim, BOLD)
	chipRow(holder, 2, if #sets > 0 then sets else { { "None yet", C.Dim } })
	local keys = {}
	for _, key in { "Q", "E", "R" } do
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		table.insert(keys, {
			key .. "  " .. (if surge then surge.Name else "Empty"),
			if gem then ELEMENT_COLOR[gem.Element] or C.Text else C.Dim,
		})
	end
	line(holder, 3, "SURGES", 10, C.Dim, BOLD)
	chipRow(holder, 4, keys)
	line(holder, 5, "HOW IT WORKS", 10, C.Dim, BOLD)
	line(
		holder,
		6,
		"Save what you wear into an ARMOR or WEAPON loadout (pick 1-3, then SAVE). WEAR switches in one tap, here or between Ranked rounds.",
		12,
		C.Text
	)
	line(
		holder,
		7,
		"Drag gems onto gear sockets or Q · E · R keys. Changing gear enchantments needs Vey at the Arcanum.",
		12,
		C.Dim
	)
end

-- Bottom bar -----------------------------------------------------------------------------------------------

local bar = new("Frame", { BackgroundTransparency = 1 }, root)
at(bar, 0, PANEL_H + 10, W, 40)
local barList = UiKit.list(bar, 8, true)
barList.VerticalAlignment = Enum.VerticalAlignment.Center
local function barButton(order: number, caption: string, active: boolean, onClick: () -> ())
	local b = new("TextButton", {
		Text = caption,
		TextSize = 12,
		Font = BOLD,
		TextColor3 = if active then C.Text else C.Dim,
		BackgroundColor3 = if active then C.TabOn else C.Panel,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
	}, bar)
	round(b, 10)
	stroke(b, if active then C.TabEdge else C.PanelEdge, 1)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, b)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end
local function openModule(name: string, method: string)
	return function()
		InventoryScreen.cancelDrag()
		local module = require(script.Parent:FindFirstChild(name) :: ModuleScript) :: any
		module[method]()
	end
end
barButton(1, "🎒  INVENTORY", true, function()
	select(nil)
end)
barButton(2, "⚡  SURGE ARRAY  [L]", false, openModule("SurgeArrayUI", "toggle"))
barButton(3, "🌳  AUGMENT TREE  [K]", false, openModule("AugmentTreeUI", "toggle"))
barButton(4, "🏅  SEASON  [J]", false, openModule("SeasonUI", "toggle"))
barButton(5, "⇄  MARKET", false, openModule("MarketBoardUI", "open"))
barButton(6, "🛒  STORE", false, openModule("ShopUI", "toggle"))
local backButton = new("TextButton", {
	Text = "⚔  BACK TO LOBBY",
	TextSize = 14,
	Font = BLACK,
	TextColor3 = C.Text,
	BackgroundColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, PANEL_H + 10),
	Size = UDim2.fromOffset(210, 40),
}, root)
round(backButton, 10)
new("UIGradient", {
	Rotation = 0,
	Color = ColorSequence.new(Color3.fromRGB(200, 107, 255), C.Pink),
}, backButton)
backButton:SetAttribute("UiSound", "Back")
backButton.Activated:Connect(function()
	InventoryScreen.cancelDrag()
	local LobbyUI = require(script.Parent.LobbyUI) :: any
	if LobbyUI.closeDashboard then
		LobbyUI.closeDashboard()
	end
end)

-- Drawing --------------------------------------------------------------------------------------------------

local function drawLeft()
	local profile = profileNow()
	local loadout = loadoutNow()
	nameLabel.Text = string.upper(player.DisplayName)
	local class = loadout.Class and Classes.get(loadout.Class)
	local best, bestCount = nil, 0
	local active = loadout.Class and Classes.setState(loadout).Active or {}
	for _, family in ArmorFamilies.Order do
		local state = active[family]
		if state and state.Count > bestCount then
			best, bestCount = family, state.Count
		end
	end
	subtitle.Text = string.upper(class and class.Name or "Miner")
		.. (
			if best
				then string.format('  ·  <font color="#ffc83d">%s %d/6</font>', string.upper(best), bestCount)
				else ""
		)

	-- Ratings.
	local ratings = loadout.Class and Classes.ratings(loadout)
	local total = 0
	for _, name in Classes.StatNames do
		local value = if ratings then ratings[name].Base + ratings[name].Bonus else 0
		total += value
		statTiles[name].Value.Text = whole(value)
		statTiles[name].Fill.Size = UDim2.fromScale(math.clamp(value / 140, 0, 1), 1)
	end
	statTiles.Rating.Value.Text = whole(total)
	statTiles.Rating.Fill.Size = UDim2.fromScale(math.clamp(total / 560, 0, 1), 1)
	local attuned = 0
	for _, slot in Slots.Order do
		if loadout[slot .. "Gem"] then
			attuned += 1
		end
	end
	statTiles.Attuned.Value.Text = string.format("%d/%d", attuned, #Slots.Order)
	statTiles.Attuned.Fill.Size = UDim2.fromScale(attuned / #Slots.Order, 1)

	-- Loadouts.
	local presets = GearPresets.clean(profile and profile.Presets)
	for part, picker in pickers do
		local chosen = chosenSlot[part]
		for slot, chip in picker.Chips do
			local preset = presets[part][slot]
			local worn = preset ~= nil and GearPresets.matches(loadout, preset)
			local isChosen = slot == chosen
			chip.Button.BackgroundColor3 = if worn then C.Gold elseif isChosen then C.TabOn else C.TabBar
			chip.Button.TextColor3 = if worn then C.TabBar elseif preset then C.Text else C.Faint
			chip.Stroke.Color = if isChosen then C.Accent elseif preset then C.TabEdge else C.PanelEdge
			chip.Stroke.Thickness = if isChosen then 2 else 1.2
		end
		local preset = presets[part][chosen]
		picker.Hint.Text = if preset
			then string.format("%d · %s · %s", chosen, preset.Name, GearPresets.label(preset))
			else string.format("%d · empty: SAVE stores what you wear", chosen)
		picker.Wear.AutoButtonColor = preset ~= nil
		picker.Wear.BackgroundTransparency = if preset then 0 else 0.6
	end

	-- Worn pieces.
	for slot, card in wornCards do
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = RARITY[rarity]
		local picked = selection and selection.Kind == "Worn" and selection.Slot == slot
		card.Name.Text = if gear then GemConfig.itemName(gear.Name, gem, slot) else "Empty"
		card.Name.TextColor3 = if gear and rarity > 1 then color:Lerp(C.Text, 0.25) else C.Text
		card.Rarity.Text = if gear then rarityName(rarity) else ""
		card.Rarity.TextColor3 = color
		if slot == "Shield" and gear and not Classes.heldShield(loadout) then
			card.Rarity.Text = "STOWED · TWO-HANDED"
			card.Rarity.TextColor3 = C.Dim
		end
		card.Stroke.Color = if picked then C.Gold else color
		card.Stroke.Thickness = if picked then 2.5 else (if rarity >= 3 then 2 else 1.5)
		card.Glow.Color = ColorSequence.new(if rarity >= 2 then C.Card:Lerp(color, 0.12) else C.Card, C.Card)
		if gem then
			local tint = ELEMENT_COLOR[gem.Element] or C.Text
			card.SocketIcon.Text = "◆"
			card.SocketIcon.TextColor3 = tint
			card.SocketEdge.Color = tint
		else
			card.SocketIcon.Text = "+"
			card.SocketIcon.TextColor3 = C.Faint
			card.SocketEdge.Color = C.PanelEdge
		end
	end

	-- Surge keys.
	for key, ui in surgeKeys do
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then ELEMENT_COLOR[gem.Element] or C.Text else C.PanelEdge
		local picked = selection and selection.Kind == "Key" and selection.Key == key
		ui.Stroke.Color = if picked then C.Gold else tint
		ui.Stroke.Thickness = if picked then 2.5 else 1.5
		ui.Name.Text = if surge then surge.Name else "empty"
		ui.Name.TextColor3 = if gem then tint else C.Faint
		ui.Letter.TextColor3 = if gem then C.Text else C.Faint
	end
end

local function drawRight()
	clear(page)
	for id, ui in tabButtons do
		local on = id == tab
		ui.Button.BackgroundTransparency = if on then 0 else 1
		ui.Button.TextColor3 = if on then C.Text else C.Dim
		ui.Stroke.Transparency = if on then 0 else 1
	end
	if tab == "Gems" then
		drawGems()
	elseif tab == "Armor" then
		drawArmor()
	else
		drawOverview()
	end
end

function draw()
	if drag and drag.Active then
		return -- don't rebuild under a drag
	end
	if not profileNow() then
		return
	end
	drawLeft()
	drawRight()
end

function InventoryScreen.refresh()
	draw()
end

function InventoryScreen.mount(parent: GuiObject, host: ScreenGui, position: UDim2)
	hostGui = host
	root.Position = position
	root.Parent = parent
	host:GetPropertyChangedSignal("Enabled"):Connect(function()
		if host.Enabled then
			draw()
		else
			InventoryScreen.cancelDrag()
		end
	end)
	draw()
end

GemClient.Changed:Connect(function()
	-- A pick that no longer exists (equipped, socketed, sold) goes back to the overview.
	local profile = profileNow()
	if selection and selection.Kind == "Gem" and profile then
		local still = false
		for _, gem in profile.Gems or {} do
			if gem.Id == selection.Gem.Id then
				still = true
			end
		end
		if not still then
			selection = nil
		end
	elseif selection and selection.Kind == "Spare" then
		local loadout = loadoutNow()
		if loadout[selection.Slot :: string] == selection.Id then
			selection = { Kind = "Worn", Slot = selection.Slot }
		end
	end
	if root.Parent then
		draw()
	end
end)

return InventoryScreen
