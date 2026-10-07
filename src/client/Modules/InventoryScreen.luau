--[[
	The Inventory (dashboard): two panels and a bar, in the station's own look
	(IronUi colours and buttons, 3D item and gem art).

	  Left (stays put)   your portrait and six ratings, your ARMOR and WEAPON
	                     loadouts (Shared.GearPresets, three each), the six
	                     worn pieces with their gem sockets, and the Surge
	                     Array (Q / E / R)
	  Right (changes)    OVERVIEW  what you picked: stats, gem, what equipping
	                               it changes, and its buttons
	                     ARMOR     spare gear, filtered by slot
	                     GEMS      your gems; drag one onto a matching socket
	  Bottom             the other screens and Back to Lobby

	Loadouts are live: tap 1, 2 or 3 to switch to that loadout (an empty one
	starts from what you wear), and every change you make saves into the
	loadout you're on (Systems/Presets).

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
local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GearArt = require(script.Parent.GearArt)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new
local P = IronUi.Colors

local InventoryScreen = {}

-- Look: the station's palette (IronUi) -------------------------------------------------------------

InventoryScreen.Colors = {
	Panel = Color3.fromRGB(17, 14, 31),
	PanelEdge = Color3.fromRGB(64, 55, 92),
	Card = P.Inset,
	Track = P.Slot,
	TabBar = P.Frame,
	Text = P.Text,
	Dim = Color3.fromRGB(150, 160, 186),
	Faint = Color3.fromRGB(88, 82, 116),
	Gold = P.Gold,
	Good = P.Good,
	Bad = P.Bad,
	Accent = P.Teal,
}
local C = InventoryScreen.Colors
local STAT = {
	Health = P.Emerald,
	Power = P.Gold,
	Defense = P.Teal,
	Speed = P.Amethyst,
	Rating = P.Gold,
	Attuned = Color3.fromRGB(226, 128, 255),
}
local function rarityColor(rarity: number): Color3
	local entry = GearRolls.Rarities[rarity]
	return if entry then entry.Color else GearRolls.Rarities[1].Color
end
local GEM_RARITY = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local SLOT_LABEL =
	{ Helmet = "HELMET", Armor = "CHEST", Gloves = "GLOVES", Boots = "BOOTS", Weapon = "WEAPON", Shield = "SHIELD" }
local HEADING, BOLD, BODY = IronUi.Heading, IronUi.Bold, IronUi.Body

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
-- Small engraved corner ticks, as on the station's other panels.
local function brackets(frame: GuiObject, color: Color3, size: number, inset: number)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = corner,
			Position = UDim2.new(
				corner.X,
				if corner.X == 0 then inset else -inset,
				corner.Y,
				if corner.Y == 0 then inset else -inset
			),
			Size = UDim2.fromOffset(size, size),
		}, frame)
		for _, dims in { Vector2.new(size, 1), Vector2.new(1, size) } do
			new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = color,
				BackgroundTransparency = 0.35,
				AnchorPoint = corner,
				Position = UDim2.fromScale(corner.X, corner.Y),
				Size = UDim2.fromOffset(dims.X, dims.Y),
			}, holder)
		end
	end
end
-- An IronUi chunky button, sized by hand.
local function chunkButton(parent: Instance, caption: string, color: Color3, size: UDim2, onClick: () -> ()): TextButton
	local b, face = IronUi.chunk(parent, {
		Color = color,
		Rim = color,
		Size = size,
		Radius = 8,
		Lip = 4,
		Stripes = "None",
	})
	IronUi.label(b, face, caption, 13, HEADING)
	b.Activated:Connect(onClick)
	return b
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
local function gemColor(gem): Color3
	return GemConfig.ElementColors[gem.Element] or C.Text
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

-- Item art: a 3D thumbnail (worn pieces from the avatar, spare ones from
-- the server's previews), else the drawn silhouette.
local function gearArt(holder: Frame, slot: string, id: string, worn: boolean, color: Color3)
	clear(holder)
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 186, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -0.8, -0.6),
	}, holder)
	local ok, drawn = pcall(GearArt.draw, view, slot, id, worn)
	if not (ok and drawn) then
		view:Destroy()
		local gear = gearOf(loadoutNow(), slot, id)
		if gear then
			local icon = GearArt.icon(holder, slot, gear, color)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
		end
	end
end
local function gemArt(holder: Frame, gem)
	clear(holder)
	pcall(GemArt.viewport, holder, gem, false)
end

-- Root ---------------------------------------------------------------------------------------------------

local root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H) })
local hostGui: ScreenGui? = nil

local function panel(x: number, y: number, w: number, h: number, accent: Color3): Frame
	local frame = box(root, Color3.new(1, 1, 1), 6)
	at(frame, x, y, w, h)
	stroke(frame, C.PanelEdge, 1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(26, 21, 46), C.Panel) }, frame)
	local rail = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = accent,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -32, 0, 2),
	}, frame)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.4, 0),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
	}, rail)
	brackets(frame, accent, 12, 6)
	return frame
end
local left = panel(0, 0, LEFT_W, PANEL_H, P.Gold)
local right = panel(RIGHT_X, 0, W - RIGHT_X, PANEL_H, P.Teal)

-- Selection and drag state.
type Pick = { Kind: string, Slot: string?, Id: string?, Gem: any?, Key: string? }
local selection: Pick? = nil
local tab = "Overview"
local armorFilter = "All"
local gemFilter = "All"
local previewVersion = 0
local dropTargets: { any } = {}
local drag: { Item: any, Start: Vector2, Active: boolean, Touch: boolean, Ghost: Frame? }? = nil
local suppressClickUntil = 0
local draw -- (below): redraws everything

local function samePick(a: Pick?, b: Pick?): boolean
	if a == nil or b == nil or a.Kind ~= b.Kind then
		return false
	end
	if a.Kind == "Gem" then
		return a.Gem.Id == (b.Gem :: any).Id
	end
	return a.Slot == b.Slot and a.Id == b.Id and a.Key == b.Key
end
-- Picking on the left shows it in OVERVIEW; picking in a bag highlights it
-- there, and picking it again opens OVERVIEW.
local function select(pick: Pick?, fromBag: boolean?)
	local again = samePick(selection, pick)
	selection = pick
	if not fromBag or again then
		tab = "Overview"
	end
	draw()
end

-- Left: portrait and ratings -------------------------------------------------------------------------

local portrait = box(left, P.Frame, 6)
at(portrait, 20, 16, 62, 62)
stroke(portrait, P.Gold, 1.5)
portrait.ClipsDescendants = true
local portraitView = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Ambient = Color3.fromRGB(150, 160, 185),
	LightColor = Color3.fromRGB(255, 240, 215),
	LightDirection = Vector3.new(-0.5, -0.8, 0.6),
}, portrait)
local nameLabel = at(label(left, "", 26, C.Text, HEADING), 96, 16, 520, 32)
local subtitle = at(label(left, "", 12, C.Dim, BOLD), 96, 50, 600, 18)
subtitle.RichText = true

local function drawPortrait()
	portraitView:ClearAllChildren()
	local character = player.Character
	if not character then
		return
	end
	pcall(function()
		local world = new("WorldModel", {}, portraitView)
		local camera = new("Camera", { FieldOfView = 26 }, portraitView)
		portraitView.CurrentCamera = camera
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = false
		for _, d in copy:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		copy:PivotTo(CFrame.new())
		copy.Parent = world
		local head = copy:FindFirstChild("Head")
		local focus = if head and head:IsA("BasePart")
			then head.Position - Vector3.new(0, 0.4, 0)
			else Vector3.new(0, 1.5, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0.8, 0.3, -5.5), focus)
	end)
end

local statTiles = {}
for i, name in { "Health", "Power", "Defense", "Speed", "Rating", "Attuned" } do
	local tile = box(left, C.Card, 4)
	at(tile, 20 + (i - 1) * 130, 92, 120, 62)
	stroke(tile, STAT[name]:Lerp(C.PanelEdge, 0.55), 1)
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = STAT[name],
		Size = UDim2.new(0, 2, 1, -16),
		Position = UDim2.fromOffset(0, 8),
	}, tile)
	at(label(tile, string.upper(name), 10, STAT[name]:Lerp(C.Text, 0.3), BOLD), 12, 8, 100, 14)
	local value = at(label(tile, "0", 22, C.Text, HEADING), 12, 22, 100, 24)
	local track = box(tile, C.Track, 2)
	at(track, 12, 50, 96, 3)
	local fill = box(track, STAT[name], 2)
	fill.Size = UDim2.fromScale(0, 1)
	-- What gems add on top (Health, Power, Defense, Speed).
	local bonus = at(label(tile, "", 10, P.Good, BOLD), 60, 26, 52, 16)
	bonus.TextXAlignment = Enum.TextXAlignment.Right
	statTiles[name] = { Value = value, Fill = fill, Bonus = bonus }
end

-- Left: the 3 x 3 grid -------------------------------------------------------------------------------------

local GRID_X, GRID_Y, CELL_W, CELL_H, GAP = 20, 168, 250, 94, 10
local function cellAt(column: number, row: number): Frame
	local cell = box(left, C.Card, 4)
	at(cell, GRID_X + (column - 1) * (CELL_W + GAP), GRID_Y + (row - 1) * (CELL_H + GAP), CELL_W, CELL_H)
	return cell
end

-- Loadout tabs: tap 1-3 to switch (an empty slot starts a new loadout).
local pickers = {}
local function loadoutPicker(part: string, column: number)
	local cell = cellAt(column, 1)
	cell.BackgroundColor3 = P.Frame
	stroke(cell, C.PanelEdge, 1)
	brackets(cell, P.Gold, 8, 4)
	at(label(cell, string.upper(GearPresets.Parts[part].Label) .. " LOADOUT", 11, C.Dim, BOLD), 14, 8, 220, 14)
	local chips = {}
	for slot = 1, GearPresets.Count do
		local chip = new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.Card }, cell)
		at(chip, 14 + (slot - 1) * 76, 28, 68, 36)
		round(chip, 6)
		local edge = stroke(chip, C.PanelEdge, 1.5)
		local number = at(label(chip, tostring(slot), 16, C.Text, HEADING), 0, 2, 68, 20)
		number.TextXAlignment = Enum.TextXAlignment.Center
		local state = at(label(chip, "", 9, C.Dim, BOLD), 0, 20, 68, 12)
		state.TextXAlignment = Enum.TextXAlignment.Center
		chip:SetAttribute("UiSound", "Tab")
		chip.Activated:Connect(function()
			request("LoadoutSelect", part, slot)
		end)
		chips[slot] = { Button = chip, Stroke = edge, Number = number, State = state }
	end
	local hint = at(label(cell, "", 10, C.Dim, BODY), 14, 70, 222, 16)
	pickers[part] = { Chips = chips, Hint = hint }
end
loadoutPicker("Armor", 1)
loadoutPicker("Weapon", 3)

-- The worn pieces.
local wornCards = {}
local function wornCard(slot: string, column: number, row: number)
	local cell = cellAt(column, row)
	cell.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient carries the colour
	local edge = stroke(cell, rarityColor(1), 1.5)
	local glow = new("UIGradient", { Rotation = 0, Color = ColorSequence.new(C.Card, C.Card) }, cell)
	local hit =
		new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, cell)
	hit:SetAttribute("UiSound", "Click")
	at(label(cell, SLOT_LABEL[slot], 10, C.Dim, BOLD), 12, 6, 160, 14)
	local art = box(cell, P.Frame, 4)
	at(art, 10, 24, 62, 62)
	stroke(art, C.PanelEdge, 1, 0.3)
	-- Long names (with their gem's prefix) wrap onto a second line.
	local name = at(label(cell, "", 13, C.Text, BOLD), 82, 26, 156, 34)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Bottom
	local rarity = at(label(cell, "", 10, C.Dim, BOLD), 82, 62, 156, 14)
	local socket = box(cell, P.Frame, 12)
	at(socket, CELL_W - 30, 6, 22, 22)
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
		Art = art,
		Shown = "",
		Name = name,
		Rarity = rarity,
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

-- The Surge Array: Q / E / R keys, each showing its gem.
local surgeCell = cellAt(3, 3)
surgeCell.BackgroundColor3 = P.Frame
stroke(surgeCell, C.PanelEdge, 1)
at(label(surgeCell, "SURGE ARRAY", 10, C.Dim, BOLD), 12, 6, 160, 14)
local surgeKeys = {}
for i, key in { "Q", "E", "R" } do
	local keyBox = new("TextButton", { Text = "", BackgroundColor3 = C.Card, AutoButtonColor = true }, surgeCell)
	at(keyBox, 12 + (i - 1) * 77, 24, 71, 62)
	round(keyBox, 4)
	keyBox:SetAttribute("UiSound", "Click")
	local edge = stroke(keyBox, C.PanelEdge, 1.5)
	local art = new("Frame", { BackgroundTransparency = 1 }, keyBox)
	at(art, 18, 4, 36, 36)
	local letter = at(label(keyBox, key, 12, C.Text, HEADING), 4, 2, 20, 16)
	local name = at(label(keyBox, "", 9, C.Dim, BOLD), 3, 42, 65, 16)
	name.TextXAlignment = Enum.TextXAlignment.Center
	keyBox.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			select({ Kind = "Key", Key = key })
		end
	end)
	surgeKeys[key] = { Box = keyBox, Stroke = edge, Name = name, Letter = letter, Art = art, Shown = "" }
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
local tabHolder = new("Frame", { BackgroundTransparency = 1 }, right)
at(tabHolder, 16, 12, RIGHT_W - 32, 46)
local page = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true }, right)
at(page, 16, 66, RIGHT_W - 32, PANEL_H - 66 - 40)
local footerLine = box(right, C.PanelEdge, 0)
at(footerLine, 16, PANEL_H - 38, RIGHT_W - 32, 1)
local footer = at(label(right, "", 10, C.Dim, BOLD), 16, PANEL_H - 32, RIGHT_W - 32, 20)
footer.TextXAlignment = Enum.TextXAlignment.Center

local function scroller(parent: Instance, y: number): ScrollingFrame
	local frame = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.PanelEdge,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 1, -y),
	}, parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 92),
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
		if target.Base == nil then
			target.Base = target.Stroke.Color
			target.BaseThickness = target.Stroke.Thickness
		end
		local ok = item ~= nil and target.Accepts(item)
		target.Stroke.Color = if ok then C.Gold else target.Base
		target.Stroke.Thickness = if ok then 2.5 else target.BaseThickness
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
		local ghost = box(hostGui or root, C.Card, 6)
		ghost.Size = UDim2.fromOffset(160, 40)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.ZIndex = 50
		stroke(ghost, C.Gold, 2)
		local caption = if current.Item.Kind == "Gem"
			then gemName(current.Item.Gem)
			else "Equip " .. SLOT_LABEL[current.Item.Slot]
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
	if dirty then
		draw()
	end
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

local function bagCard(
	parent: Instance,
	order: number,
	title: string,
	color: Color3,
	sub: string,
	tag: string,
	tagColor: Color3,
	paint: (Frame) -> (),
	onClick: () -> (),
	dragItem
)
	local card =
		new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.Card, LayoutOrder = order }, parent)
	round(card, 4)
	card:SetAttribute("UiSound", "Click")
	local selected = selection ~= nil and samePick(selection, dragItem)
	stroke(card, if selected then C.Gold else color, if selected then 2.5 else 1.5, if selected then 0 else 0.2)
	local art = box(card, P.Frame, 4)
	at(art, 8, 8, 52, 52)
	paint(art)
	at(label(card, title, 12, color:Lerp(C.Text, 0.45), BOLD), 66, 12, 98, 30).TextWrapped = true
	at(label(card, sub, 9, color, BOLD), 66, 44, 98, 14)
	local badge = new("TextLabel", {
		Text = tag,
		TextSize = 9,
		Font = BOLD,
		TextColor3 = tagColor,
		BackgroundColor3 = P.Frame,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
	}, card)
	round(badge, 3)
	stroke(badge, tagColor, 1, 0.45)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, badge)
	card.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			onClick()
		end
	end)
	card.InputBegan:Connect(function(input)
		startDrag(dragItem, input)
	end)
	return card
end

local function emptyNote(parent: Instance, text: string)
	local note = label(parent, text, 13, C.Dim, BOLD)
	note.Size = UDim2.new(1, 0, 0, 80)
	note.Position = UDim2.fromOffset(0, 60)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextWrapped = true
end

-- A row of filter chips; `current` is lit gold.
local function filterRow(entries: { any }, current: string, onPick: (string) -> ())
	local chips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) }, page)
	UiKit.list(chips, 6, true)
	for i, entry in entries do
		local on = current == entry[1]
		local chip = new("TextButton", {
			Text = entry[2],
			TextSize = 10,
			Font = BOLD,
			TextColor3 = if on then P.Frame else (entry[3] or C.Dim),
			BackgroundColor3 = if on then P.Gold else C.Card,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
		}, chips)
		round(chip, 4)
		stroke(chip, if on then P.Gold else C.PanelEdge, 1)
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chip)
		chip:SetAttribute("UiSound", "Tab")
		chip.Activated:Connect(function()
			onPick(entry[1])
		end)
	end
end

local function pickKey(): string
	local pick = selection
	if not pick then
		return "-"
	end
	return pick.Kind .. ":" .. tostring(pick.Slot or pick.Key or pick.Id or (pick.Gem and pick.Gem.Id))
end

-- The pouch, best first, through the element filter.
local function shownGems()
	local profile = profileNow()
	local gems = {}
	for _, gem in profile and profile.Gems or {} do
		local keep = gemFilter == "All"
			or (gemFilter == "Rough" and gem.Cut == nil)
			or (gem.Cut ~= nil and gem.Element == gemFilter)
		if keep then
			table.insert(gems, gem)
		end
	end
	table.sort(gems, function(a, b)
		local ra, rb = gemRarity(a), gemRarity(b)
		if ra ~= rb then
			return ra > rb
		end
		if (a.Cut ~= nil) ~= (b.Cut ~= nil) then
			return a.Cut ~= nil
		end
		if (a.Element or "") ~= (b.Element or "") then
			return (a.Element or "") < (b.Element or "")
		end
		return a.Id < b.Id
	end)
	return gems
end
local function gemsKey(): string
	local parts = { "Gems", gemFilter, pickKey() }
	for _, gem in shownGems() do
		table.insert(parts, gem.Id .. ":" .. tostring(gem.Cut))
	end
	return table.concat(parts, ",")
end

-- GEMS: every gem in the pouch, best first.
local function drawGems()
	local profile = profileNow()
	local entries = { { "All", "ALL" } }
	for _, element in GemConfig.Elements do
		table.insert(
			entries,
			{ element, string.upper(GemConfig.elementName(element)), GemConfig.ElementColors[element] }
		)
	end
	table.insert(entries, { "Rough", "ROUGH" })
	filterRow(entries, gemFilter, function(id)
		gemFilter = id
		draw()
	end)
	local gems = shownGems()
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
	local grid = scroller(page, 36)
	if #gems == 0 then
		emptyNote(
			page,
			if profile and #(profile.Gems or {}) > 0
				then "No gems match this filter."
				else "No gems yet.\nMine rocks at the Outpost to find some."
		)
	end
	for order, gem in gems do
		local tierColor = GemConfig.TierColors[gem.Tier] or C.Text
		bagCard(
			grid,
			order,
			gemName(gem),
			tierColor,
			rarityName(gemRarity(gem)),
			if gem.Cut then string.upper(GemConfig.elementName(gem.Element)) else "ROUGH",
			if gem.Cut then gemColor(gem) else C.Faint,
			function(art)
				gemArt(art, gem)
			end,
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

-- ARMOR: spare gear, filtered by slot. Its 3D previews come from the server.
local FILTERS = {
	{ "All", "ALL" },
	{ "Helmet", "HEAD" },
	{ "Armor", "BODY" },
	{ "Gloves", "HANDS" },
	{ "Boots", "FEET" },
	{ "Weapon", "WEAPON" },
	{ "Shield", "SHIELD" },
}
local previewSignature, previewPending = "", false
local function requestPreviews(items)
	local parts = {}
	for _, item in items do
		table.insert(parts, item.Slot .. "|" .. item.Id .. "|" .. item.Rarity)
	end
	local signature = table.concat(parts, ",")
	if previewPending or signature == previewSignature then
		return
	end
	previewSignature, previewPending = signature, true
	task.spawn(function()
		local result = GemClient.request("GearPreviews")
		previewPending = false
		if not (result and result.Ok and result.Done) then
			previewSignature = "" -- busy: try again on the next draw
		end
	end)
end
local function spareItems()
	local profile = profileNow()
	local loadout = loadoutNow()
	local items = {}
	for order, slot in Slots.Order do
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
	table.sort(items, function(a, b)
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		if a.Order ~= b.Order then
			return a.Order < b.Order
		end
		return a.Id < b.Id
	end)
	return items
end
local function armorKey(): string
	local parts = { "Armor", armorFilter, pickKey(), tostring(previewVersion) }
	for _, item in spareItems() do
		table.insert(parts, item.Id .. ":" .. item.Rarity)
	end
	return table.concat(parts, ",")
end
local function drawArmor()
	filterRow(FILTERS, armorFilter, function(id)
		armorFilter = id
		draw()
	end)
	local grid = scroller(page, 36)
	local all = spareItems()
	requestPreviews(all)
	local shown = 0
	for order, item in all do
		if armorFilter == "All" or armorFilter == item.Slot then
			shown += 1
			local color = rarityColor(item.Rarity)
			bagCard(
				grid,
				order,
				item.Gear.Name,
				color,
				rarityName(item.Rarity),
				SLOT_LABEL[item.Slot],
				C.Dim,
				function(art)
					gearArt(art, item.Slot, item.Id, false, color)
				end,
				function()
					select({ Kind = "Spare", Slot = item.Slot, Id = item.Id }, true)
				end,
				{ Kind = "Spare", Slot = item.Slot, Id = item.Id }
			)
		end
	end
	if shown == 0 then
		emptyNote(page, "No spare gear here.\nRecover more in the mine or trade for it.")
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
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order }, parent)
	UiKit.list(row, 6, true)
	for i, chip in chips do
		local tag = new("TextLabel", {
			Text = chip[1],
			TextSize = 11,
			Font = BOLD,
			TextColor3 = chip[2],
			BackgroundColor3 = P.Frame,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
		}, row)
		round(tag, 4)
		stroke(tag, chip[2], 1, 0.5)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tag)
	end
	return row
end
local function actions(parent: Instance, order: number, list: { any })
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order }, parent)
	UiKit.list(row, 8, true)
	for i, spec in list do
		local b = IronUi.button(row, spec[1], spec[2], spec[3])
		b.LayoutOrder = i
	end
end
local function header(parent: Instance, title: string, sub: string, color: Color3, paint: (Frame) -> ())
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 0 }, parent)
	local tile = box(top, P.Frame, 4)
	at(tile, 0, 0, 72, 72)
	stroke(tile, color, 1.5)
	paint(tile)
	at(label(top, title, 18, color:Lerp(C.Text, 0.4), HEADING), 86, 10, 430, 26)
	at(label(top, sub, 11, color, BOLD), 86, 40, 430, 18)
end
local function emblem(kind: string, color: Color3)
	return function(tile: Frame)
		local e = IronUi.emblem(tile, kind, color, 48)
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		e.Position = UDim2.fromScale(0.5, 0.5)
	end
end
local function ratingDelta(loadout, slot: string, id: string)
	local before = Classes.ratings(loadout)
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	trial[slot .. "Quality"] = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
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
		ScrollBarImageColor3 = C.PanelEdge,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 1),
	}, page)
	local list = UiKit.list(holder, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, holder)
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
		local color = rarityColor(rarity)
		local gem = if pick.Kind == "Worn"
			then loadout[slot .. "Gem"]
			else (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id])
		header(
			holder,
			GemConfig.itemName(gear.Name, gem, slot),
			string.format(
				"%s  ·  %s  ·  %s",
				rarityName(rarity),
				SLOT_LABEL[slot],
				if pick.Kind == "Spare" then "SPARE" else "WORN"
			),
			color,
			function(tile)
				gearArt(tile, slot, id :: string, pick.Kind == "Worn", color)
			end
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
			line(holder, 6, string.format("%s: %s", name, effect), 12, gemColor(gem), BOLD)
		else
			line(holder, 6, "Empty. Drag a cut gem from GEMS onto this piece.", 12, C.Dim)
		end
		local pickGem = {
			"PICK A GEM",
			false,
			function()
				tab = "Gems"
				draw()
			end,
		}
		if pick.Kind == "Spare" then
			line(holder, 7, "IF EQUIPPED", 10, C.Dim, BOLD)
			chipRow(holder, 8, ratingDelta(loadout, slot, id :: string))
			actions(holder, 9, {
				{
					"EQUIP",
					true,
					function()
						request("EquipGear", Slots.Definitions[slot].Kind, id)
					end,
				},
			})
		elseif gem then
			actions(holder, 9, {
				{
					"REMOVE GEM",
					false,
					function()
						request("UnsocketGem", slot)
					end,
				},
				pickGem,
			})
		else
			actions(holder, 9, { pickGem })
		end
		return
	end
	if pick and pick.Kind == "Gem" then
		local gem = pick.Gem
		local color = gemColor(gem)
		header(
			holder,
			gemName(gem),
			string.format(
				"%s  ·  %s%s",
				rarityName(gemRarity(gem)),
				string.upper(GemConfig.elementName(gem.Element)),
				if gem.Cut then "" else "  ·  ROUGH"
			),
			color,
			function(tile)
				gemArt(tile, gem)
			end
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
			local keys = {}
			for _, key in { "Q", "E", "R" } do
				table.insert(keys, {
					"ON " .. key,
					false,
					function()
						request("SocketSurge", gem.Id, key)
					end,
				})
			end
			actions(holder, 5, keys)
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
			local color = gemColor(gem)
			header(holder, surge.Name, "ON KEY " .. key .. "  ·  " .. rarityName(gemRarity(gem)), color, function(tile)
				gemArt(tile, gem)
			end)
			line(holder, 1, surge.Description or "", 12, C.Text)
			chipRow(holder, 2, {
				{ string.format("%s %s", whole(surge.Cost or 0), surge.Resource or "Charge"), C.Accent },
				{ string.format("%ss cooldown", whole(surge.Cooldown or 0)), C.Dim },
			})
			actions(holder, 3, {
				{
					"REMOVE FROM " .. key,
					false,
					function()
						request("UnsocketSurge", key)
					end,
				},
			})
		else
			header(holder, "Key " .. key .. " is empty", "SURGE ARRAY", C.Dim, emblem("Enchant", C.Dim))
			line(holder, 1, "Drag a cut gem from GEMS onto this key to cast its surge with " .. key .. ".", 12, C.Dim)
			actions(holder, 2, {
				{
					"PICK A GEM",
					true,
					function()
						tab = "Gems"
						draw()
					end,
				},
			})
		end
		return
	end
	-- Nothing picked: the build at a glance.
	local class = loadout.Class and Classes.get(loadout.Class)
	header(holder, class and class.Name or "Miner", "YOUR BUILD", P.Gold, emblem("Equipment", P.Gold))
	local sets = {}
	local active = loadout.Class and Classes.setState(loadout).Active or {}
	for _, family in ArmorFamilies.Order do
		local state = active[family]
		if state and state.Count > 0 then
			table.insert(sets, { string.format("%s %d/6", family, state.Count), P.Gold })
		end
	end
	line(holder, 1, "ARMOR SETS", 10, C.Dim, BOLD)
	chipRow(holder, 2, if #sets > 0 then sets else { { "None yet", C.Dim } })
	local keys = {}
	for _, key in { "Q", "E", "R" } do
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		table.insert(
			keys,
			{ key .. "  " .. (if surge then surge.Name else "Empty"), if gem then gemColor(gem) else C.Dim }
		)
	end
	line(holder, 3, "SURGES", 10, C.Dim, BOLD)
	chipRow(holder, 4, keys)
	line(holder, 5, "LOADOUTS", 10, C.Dim, BOLD)
	line(
		holder,
		6,
		"Tap 1, 2 or 3 to switch loadouts. An empty one starts from what you wear; every change you make saves into the loadout you're on. Ranked swaps them between rounds.",
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
at(bar, 0, PANEL_H + 6, W - 230, 46)
local barList = UiKit.list(bar, 8, true)
barList.VerticalAlignment = Enum.VerticalAlignment.Center
local function openModule(name: string, method: string)
	return function()
		InventoryScreen.cancelDrag()
		local module = require(script.Parent:FindFirstChild(name) :: ModuleScript) :: any
		module[method]()
	end
end
for order, spec in
	{
		{
			"INVENTORY",
			true,
			function()
				select(nil)
			end,
		},
		{ "SURGE ARRAY  [L]", false, openModule("SurgeArrayUI", "toggle") },
		{ "AUGMENT TREE  [K]", false, openModule("AugmentTreeUI", "toggle") },
		{ "SEASON  [J]", false, openModule("SeasonUI", "toggle") },
		{ "MARKET", false, openModule("MarketBoardUI", "open") },
		{ "STORE", false, openModule("ShopUI", "toggle") },
	}
do
	local b = IronUi.button(bar, spec[1], spec[2], spec[3])
	b.LayoutOrder = order
end
local backButton = chunkButton(root, "BACK TO LOBBY", P.Gold, UDim2.fromOffset(210, 42), function()
	InventoryScreen.cancelDrag()
	local LobbyUI = require(script.Parent.LobbyUI) :: any
	if LobbyUI.closeDashboard then
		LobbyUI.closeDashboard()
	end
end)
backButton.AnchorPoint = Vector2.new(1, 0)
backButton.Position = UDim2.new(1, 0, 0, PANEL_H + 8)
backButton:SetAttribute("UiSound", "Back")

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
				then string.format('  ·  <font color="#ffca5b">%s %d/6</font>', string.upper(best), bestCount)
				else ""
		)

	-- Ratings.
	local ratings = loadout.Class and Classes.ratings(loadout)
	local total = 0
	for _, name in Classes.StatNames do
		local value = if ratings then ratings[name].Base + ratings[name].Bonus else 0
		total += value
		statTiles[name].Value.Text = whole(value)
		local bonus = if ratings then ratings[name].Bonus else 0
		statTiles[name].Bonus.Text = if bonus >= 0.5 then "◆ +" .. whole(bonus) else ""
		statTiles[name].Bonus.TextColor3 = if ratings and ratings[name].Element
			then GemConfig.ElementColors[ratings[name].Element] or P.Good
			else P.Good
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

	-- Loadouts: the active one glows gold.
	local presets = GearPresets.clean(profile and profile.Presets)
	for part, picker in pickers do
		local current = presets.Active[part]
		for slot, chip in picker.Chips do
			local saved = presets[part][slot] ~= nil
			local on = slot == current
			chip.Button.BackgroundColor3 = if on then P.Gold:Lerp(P.Frame, 0.72) else C.Card
			chip.Stroke.Color = if on then P.Gold else C.PanelEdge
			chip.Stroke.Thickness = if on then 2 else 1.2
			chip.Number.TextColor3 = if on then P.Gold elseif saved then C.Text else C.Faint
			chip.State.Text = if on then "ON" elseif saved then "SAVED" else "NEW"
			chip.State.TextColor3 = if on then P.Gold elseif saved then C.Dim else C.Faint
		end
		picker.Hint.Text = string.format("Loadout %d  ·  your changes save into it", current)
	end

	-- Worn pieces (art redrawn only when the piece or its gem changes).
	for slot, card in wornCards do
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = rarityColor(rarity)
		local picked = selection and selection.Kind == "Worn" and selection.Slot == slot
		card.Name.Text = if gear then GemConfig.itemName(gear.Name, gem, slot) else "Empty"
		card.Name.TextColor3 = if gear and rarity > 1 then color:Lerp(C.Text, 0.3) else C.Text
		card.Rarity.Text = if gear then rarityName(rarity) else ""
		card.Rarity.TextColor3 = color
		if slot == "Shield" and gear and not Classes.heldShield(loadout) then
			card.Rarity.Text = "STOWED · TWO-HANDED"
			card.Rarity.TextColor3 = C.Dim
		end
		card.Stroke.Color = if picked then C.Gold else color
		card.Stroke.Thickness = if picked then 2.5 else (if rarity >= 3 then 2 else 1.5)
		card.Glow.Color = ColorSequence.new(C.Card:Lerp(color, if rarity >= 2 then 0.16 else 0.04), C.Card)
		local shown = (loadout[slot] or "") .. "|" .. (if gem then gem.Id else "")
		if card.Shown ~= shown and loadout[slot] then
			card.Shown = shown
			gearArt(card.Art, slot, loadout[slot], true, color)
		end
		if gem then
			card.SocketIcon.Text = "◆"
			card.SocketIcon.TextColor3 = gemColor(gem)
			card.SocketEdge.Color = gemColor(gem)
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
		local tint = if gem then gemColor(gem) else C.PanelEdge
		local picked = selection and selection.Kind == "Key" and selection.Key == key
		ui.Stroke.Color = if picked then C.Gold else tint
		ui.Stroke.Thickness = if picked then 2.5 else 1.5
		ui.Name.Text = if surge then surge.Name else "empty"
		ui.Name.TextColor3 = if gem then tint else C.Faint
		ui.Letter.TextColor3 = if gem then C.Text else C.Faint
		local shown = if gem then gem.Id else ""
		if ui.Shown ~= shown then
			ui.Shown = shown
			clear(ui.Art)
			if gem then
				gemArt(ui.Art, gem)
			end
		end
	end
end

-- Tabs carry counts; they're rebuilt only when the tab or a count changes.
local tabsKey = ""
local function drawTabs()
	local profile = profileNow()
	local spare = #spareItems()
	local gems = #(profile and profile.Gems or {})
	local key = string.format("%s|%d|%d", tab, spare, gems)
	if key == tabsKey then
		return
	end
	tabsKey = key
	clear(tabHolder)
	IronUi.tabs(
		tabHolder,
		{
			{ "Overview", "OVERVIEW" },
			{ "Armor", string.format("ARMOR  %d", spare) },
			{ "Gems", string.format("GEMS  %d/%d", gems, Config.MaxGems) },
		},
		tab,
		function(id)
			tab = id
			draw()
		end
	)
end

-- A bag page is rebuilt only when what it shows changes, and keeps its
-- scroll position when it is.
local pageKey, pageTab = "", ""
local function drawRight()
	drawTabs()
	local key = if tab == "Gems" then gemsKey() elseif tab == "Armor" then armorKey() else nil
	if key ~= nil and key == pageKey and pageTab == tab then
		return
	end
	local old = page:FindFirstChildWhichIsA("ScrollingFrame", true)
	local keep = if old and pageTab == tab then old.CanvasPosition else nil
	pageKey, pageTab = key or "", tab
	clear(page)
	if tab == "Gems" then
		drawGems()
	elseif tab == "Armor" then
		drawArmor()
	else
		drawOverview()
	end
	local fresh = page:FindFirstChildWhichIsA("ScrollingFrame", true)
	if keep and fresh then
		task.defer(function()
			fresh.CanvasPosition = keep
		end)
	end
end

-- Draws are coalesced (a burst of profile updates is one redraw) and only
-- happen while the Inventory is on screen; otherwise it redraws on opening.
local drawQueued, dirty, portraitDirty = false, true, true
local function visible(): boolean
	return hostGui ~= nil and hostGui.Enabled
end
function draw()
	if drawQueued then
		return
	end
	drawQueued = true
	task.defer(function()
		drawQueued = false
		if (drag and drag.Active) or not visible() or not profileNow() then
			dirty = true
			return
		end
		dirty = false
		if portraitDirty then
			portraitDirty = false
			drawPortrait()
		end
		drawLeft()
		drawRight()
	end)
end

function InventoryScreen.refresh()
	draw()
end

-- The avatar's gear arrives a moment after a change: redraw the worn art and
-- the portrait then (a burst of changes is one redraw).
local artPending = false
local function gearChanged()
	if artPending then
		return
	end
	artPending = true
	task.delay(0.3, function()
		artPending = false
		for _, card in wornCards do
			card.Shown = ""
		end
		portraitDirty = true
		draw()
	end)
end
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "GemsoulGear" then
			gearChanged()
		end
	end)
	gearChanged()
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)
-- Spare-gear previews arrive in a hidden ScreenGui: redraw the ARMOR tab.
local previewRedraw = false
local function previewsChanged()
	if previewRedraw or tab ~= "Armor" then
		return
	end
	previewRedraw = true
	task.delay(0.3, function()
		previewRedraw = false
		previewVersion += 1
		if tab == "Armor" then
			draw()
		end
	end)
end
local playerGui = player:WaitForChild("PlayerGui")
local function watchPreviews(store: Instance)
	store.ChildAdded:Connect(previewsChanged)
end
if playerGui:FindFirstChild("GearPreviews") then
	watchPreviews(playerGui:FindFirstChild("GearPreviews") :: Instance)
end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "GearPreviews" then
		watchPreviews(child)
	end
end)

function InventoryScreen.mount(parent: GuiObject, host: ScreenGui, position: UDim2)
	hostGui = host
	root.Position = position
	root.Parent = parent
	host:GetPropertyChangedSignal("Enabled"):Connect(function()
		if host.Enabled then
			portraitDirty = true
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
