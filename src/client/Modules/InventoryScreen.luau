local ArmorSignatures = require(game:GetService("ReplicatedStorage").Shared.ArmorSignatures)
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
-- Picking anything (a worn piece, a key, a bag item) opens its details in a
-- popup over the Inventory; closing it clears the pick.
local function select(pick: Pick?)
	selection = pick
	draw()
end

-- Left: a character sheet --------------------------------------------------------------------------------
-- Armor down the left, weapon / shield / surges down the right, and your
-- fighter in the middle with the ratings under them.

local COL_W, CARD_H, ROW_GAP = 230, 91, 9
local BODY_Y = 80
local LEFT_COL, MID_X, RIGHT_COL = 18, 260, LEFT_W - 18 - COL_W
local MID_W = RIGHT_COL - 10 - MID_X
local STAGE_H = 236

local nameLabel = at(label(left, "", 26, C.Text, HEADING), 20, 14, 420, 32)
local subtitle = at(label(left, "", 12, C.Dim, BOLD), 20, 48, 440, 18)
subtitle.RichText = true

-- The stage: your fighter, full height, on a lit plinth.
local portrait = box(left, P.Frame, 6)
at(portrait, MID_X, BODY_Y, MID_W, STAGE_H)
stroke(portrait, C.PanelEdge, 1)
portrait.ClipsDescendants = true
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(40, 33, 70), Color3.fromRGB(14, 12, 26)),
}, portrait)
brackets(portrait, P.Gold, 10, 5)
local plinth = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = P.Gold,
	BackgroundTransparency = 0.55,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(150, 3),
}, portrait)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, plinth)
local portraitView = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Ambient = Color3.fromRGB(150, 160, 185),
	LightColor = Color3.fromRGB(255, 240, 215),
	LightDirection = Vector3.new(-0.5, -0.8, 0.6),
}, portrait)
local stageTag = at(label(portrait, "", 10, P.Gold, BOLD), 12, 8, MID_W - 24, 14)
stageTag.TextXAlignment = Enum.TextXAlignment.Center

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
		-- The whole fighter, a little turned, filling the stage.
		local bounds, size = copy:GetBoundingBox()
		local focus = bounds.Position + Vector3.new(0, size.Y * 0.04, 0)
		local distance = (size.Y * 0.62) / math.tan(math.rad(camera.FieldOfView / 2))
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.3, size.Y * 0.08, -distance), focus)
	end)
end

local statTiles = {}
local TILE_GAP = 6
local TILE_W = math.floor((MID_W - 2 * TILE_GAP) / 3)
local TILE_H = math.floor((PANEL_H - 12 - BODY_Y - STAGE_H - 8 - TILE_GAP) / 2)
for i, name in { "Health", "Power", "Defense", "Speed", "Rating", "Attuned" } do
	local tile = box(left, C.Card, 4)
	local column, row = (i - 1) % 3, (i - 1) // 3
	at(tile, MID_X + column * (TILE_W + TILE_GAP), BODY_Y + STAGE_H + 8 + row * (TILE_H + TILE_GAP), TILE_W, TILE_H)
	stroke(tile, STAT[name]:Lerp(C.PanelEdge, 0.55), 1)
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = STAT[name],
		Size = UDim2.new(0, 2, 1, -16),
		Position = UDim2.fromOffset(0, 8),
	}, tile)
	at(label(tile, string.upper(name), 9, STAT[name]:Lerp(C.Text, 0.3), BOLD), 10, 6, TILE_W - 16, 12)
	local value = at(label(tile, "0", 20, C.Text, HEADING), 10, 19, TILE_W - 16, 22)
	local track = box(tile, C.Track, 2)
	at(track, 10, TILE_H - 9, TILE_W - 20, 3)
	local fill = box(track, STAT[name], 2)
	fill.Size = UDim2.fromScale(0, 1)
	-- What gems add on top (Health, Power, Defense, Speed).
	local bonus = at(label(tile, "", 9, P.Good, BOLD), TILE_W - 56, 23, 48, 14)
	bonus.TextXAlignment = Enum.TextXAlignment.Right
	statTiles[name] = { Value = value, Fill = fill, Bonus = bonus, Tile = tile }
end

-- Every change you make shows: a stat that goes up flashes green with its
-- gain for a second (down: red). The first draw only sets the baseline.
local lastStat: { [string]: number } = {}
local function flashStat(name: string, value: number)
	local before = lastStat[name]
	lastStat[name] = value
	local tile = statTiles[name]
	if before == nil or math.abs(value - before) < 0.5 or not tile then
		return
	end
	local gain = value - before
	local color = if gain > 0 then P.Good else P.Bad
	tile.Value.TextColor3 = color
	game:GetService("TweenService")
		:Create(tile.Value, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { TextColor3 = C.Text })
		:Play()
	local pop = at(
		label(
			tile.Tile,
			string.format("%s%d", if gain > 0 then "+" else "", math.floor(gain + 0.5)),
			14,
			color,
			HEADING
		),
		TILE_W - 64,
		4,
		56,
		16
	)
	pop.TextXAlignment = Enum.TextXAlignment.Right
	pop.ZIndex = 5
	game:GetService("TweenService")
		:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
			Position = pop.Position - UDim2.fromOffset(0, 8),
			TextTransparency = 1,
		})
		:Play()
	task.delay(1.2, function()
		pop:Destroy()
	end)
end

-- The two columns of slots.
local CELL_W = COL_W
local function cellAt(column: number, row: number): Frame
	local cell = box(left, C.Card, 4)
	at(cell, if column == 1 then LEFT_COL else RIGHT_COL, BODY_Y + (row - 1) * (CARD_H + ROW_GAP), CELL_W, CARD_H)
	return cell
end

-- Loadout tabs in the header: tap 1-3 to switch (an empty slot starts a
-- new loadout).
local pickers = {}
local function loadoutPicker(part: string, x: number)
	local cell = new("Frame", { BackgroundTransparency = 1 }, left)
	at(cell, x, 10, 150, 64)
	at(label(cell, string.upper(GearPresets.Parts[part].Label) .. " LOADOUT", 9, C.Dim, BOLD), 0, 0, 150, 12)
	local chips = {}
	for slot = 1, GearPresets.Count do
		local chip = new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.Card }, cell)
		at(chip, (slot - 1) * 50, 15, 46, 34)
		round(chip, 6)
		local edge = stroke(chip, C.PanelEdge, 1.5)
		local number = at(label(chip, tostring(slot), 15, C.Text, HEADING), 0, 2, 46, 18)
		number.TextXAlignment = Enum.TextXAlignment.Center
		local state = at(label(chip, "", 8, C.Dim, BOLD), 0, 19, 46, 12)
		state.TextXAlignment = Enum.TextXAlignment.Center
		chip:SetAttribute("UiSound", "Tab")
		chip.Activated:Connect(function()
			request("LoadoutSelect", part, slot)
		end)
		chips[slot] = { Button = chip, Stroke = edge, Number = number, State = state }
	end
	local hint = at(label(cell, "", 9, C.Faint, BODY), 0, 52, 150, 12)
	pickers[part] = { Chips = chips, Hint = hint }
end
loadoutPicker("Armor", LEFT_W - 18 - 150 - 168)
loadoutPicker("Weapon", LEFT_W - 18 - 150)

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
	local name = at(label(cell, "", 13, C.Text, BOLD), 82, 26, CELL_W - 92, 34)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Bottom
	local rarity = at(label(cell, "", 10, C.Dim, BOLD), 82, 62, CELL_W - 92, 14)
	local socket = box(cell, P.Frame, 12)
	at(socket, CELL_W - 30, 6, 22, 22)
	local socketEdge = stroke(socket, C.PanelEdge, 1.2)
	local socketIcon = label(socket, "+", 12, C.Faint, BOLD)
	socketIcon.Size = UDim2.fromScale(1, 1)
	socketIcon.TextXAlignment = Enum.TextXAlignment.Center
	-- Tap a piece to choose a replacement (the ARMOR tab, filtered to this
	-- slot); DETAILS opens its details.
	hit.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			selection = nil
			tab, armorFilter = "Armor", slot
			draw()
		end
	end)
	local details = new("TextButton", {
		Text = "DETAILS",
		TextSize = 9,
		Font = BOLD,
		TextColor3 = C.Dim,
		BackgroundColor3 = P.Frame,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(58, 18),
		ZIndex = 4,
	}, cell)
	round(details, 4)
	stroke(details, C.PanelEdge, 1)
	details:SetAttribute("UiSound", "Click")
	details.Activated:Connect(function()
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
wornCard("Helmet", 1, 1)
wornCard("Armor", 1, 2)
wornCard("Gloves", 1, 3)
wornCard("Boots", 1, 4)
wornCard("Weapon", 2, 1)
wornCard("Shield", 2, 2)

-- The Surge Array: Q / E / R keys, each showing its gem.
local surgeCell = box(left, P.Frame, 4)
at(surgeCell, RIGHT_COL, BODY_Y + 2 * (CARD_H + ROW_GAP), CELL_W, 2 * CARD_H + ROW_GAP)
stroke(surgeCell, C.PanelEdge, 1)
brackets(surgeCell, P.Teal, 8, 4)
at(label(surgeCell, "SURGE ARRAY", 10, C.Dim, BOLD), 12, 8, 160, 14)
local KEY_W = math.floor((CELL_W - 24 - 2 * 6) / 3)
local surgeKeys = {}
for i, key in { "Q", "E", "R" } do
	local keyBox = new("TextButton", { Text = "", BackgroundColor3 = C.Card, AutoButtonColor = true }, surgeCell)
	at(keyBox, 12 + (i - 1) * (KEY_W + 6), 28, KEY_W, 2 * CARD_H + ROW_GAP - 40)
	round(keyBox, 4)
	keyBox:SetAttribute("UiSound", "Click")
	local edge = stroke(keyBox, C.PanelEdge, 1.5)
	local art = new("Frame", { BackgroundTransparency = 1 }, keyBox)
	at(art, math.floor((KEY_W - 56) / 2), 28, 56, 56)
	local letter = at(label(keyBox, key, 16, C.Text, HEADING), 0, 4, KEY_W, 20)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	local name = at(label(keyBox, "", 10, C.Dim, BOLD), 4, 92, KEY_W - 8, 40)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
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
				select({ Kind = "Gem", Gem = gem })
			end,
			{ Kind = "Gem", Gem = gem }
		)
	end
	footer.Text = if selection and selection.Kind == "Gem"
		then string.upper(gemName(selection.Gem)) .. "  ·  TAP FOR DETAILS, OR DRAG IT ONTO A SOCKET"
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
-- How much your total rating changes if you put this piece on.
local function ratingGain(loadout, slot: string, id: string): number
	if not loadout.Class then
		return 0
	end
	local function total(l)
		local sum = 0
		local ratings = Classes.ratings(l)
		for _, stat in Classes.StatNames do
			sum += ratings[stat].Base + ratings[stat].Bonus
		end
		return sum
	end
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	trial[slot .. "Quality"] = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
	trial[slot .. "Gem"] = (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]) or nil
	local ok, gain = pcall(function()
		return total(trial) - total(loadout)
	end)
	return if ok then math.floor(gain + 0.5) else 0
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
	local loadout = loadoutNow()
	requestPreviews(all)
	local shown = 0
	for order, item in all do
		if armorFilter == "All" or armorFilter == item.Slot then
			shown += 1
			local color = rarityColor(item.Rarity)
			local card = bagCard(
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
					select({ Kind = "Spare", Slot = item.Slot, Id = item.Id })
				end,
				{ Kind = "Spare", Slot = item.Slot, Id = item.Id }
			)
			-- Better or worse than what you wear, and one tap to put it on.
			local gain = ratingGain(loadout, item.Slot, item.Id)
			local delta = at(
				label(
					card,
					if gain > 0 then "▲ +" .. gain elseif gain < 0 then "▼ " .. gain else "= 0",
					10,
					if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim,
					BOLD
				),
				66,
				66,
				40,
				18
			)
			delta.TextXAlignment = Enum.TextXAlignment.Center
			local equip = new("TextButton", {
				Text = "EQUIP",
				TextSize = 10,
				Font = HEADING,
				TextColor3 = P.Frame,
				BackgroundColor3 = if gain > 0 then C.Good else P.Gold,
				AutoButtonColor = true,
				Position = UDim2.fromOffset(110, 64),
				Size = UDim2.fromOffset(52, 22),
			}, card)
			round(equip, 4)
			equip:SetAttribute("UiSound", "Confirm")
			equip.Activated:Connect(function()
				request("EquipGear", Slots.Definitions[item.Slot].Kind, item.Id)
			end)
		end
	end
	if shown == 0 then
		emptyNote(
			page,
			if armorFilter == "All"
				then "No spare gear here.\nRecover more in the mine or trade for it."
				else "No other "
					.. string.lower(SLOT_LABEL[armorFilter] or "gear")
					.. " to swap in yet.\nRecover more in the mine or trade for it."
		)
	end
	local worn = armorFilter ~= "All" and gearOf(loadout, armorFilter)
	footer.Text = if armorFilter ~= "All"
		then string.format(
			"CHOOSING %s  ·  WEARING %s  ·  TAP EQUIP TO SWAP",
			SLOT_LABEL[armorFilter] or "",
			string.upper(worn and worn.Name or "NOTHING")
		)
		else "TAP EQUIP TO PUT A PIECE ON  ·  ▲ / ▼ = YOUR RATING CHANGE"
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
	local name = label(top, title, 18, color:Lerp(C.Text, 0.4), HEADING)
	name.Position, name.Size = UDim2.fromOffset(86, 10), UDim2.new(1, -86, 0, 26)
	local kind = label(top, sub, 11, color, BOLD)
	kind.Position, kind.Size = UDim2.fromOffset(86, 40), UDim2.new(1, -86, 0, 18)
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
-- Overview pieces: an armor set's progress and tiers, and a surge key.
local SET_STAT = {
	Health = "%s HP",
	Power = "%s Power",
	Defense = "%s Defense",
	Speed = "%s Speed",
	Critical = "%s%% crit",
	Cooldown = "%s%% cooldown",
	HealingReceived = "%s%% healing",
	DamageAfterDodge = "%s%% dmg after dodge",
	DamageReduction = "%s%% damage taken",
	ThreatGeneration = "%s%% threat",
}
local SET_PERCENT = {
	Critical = true,
	Cooldown = true,
	HealingReceived = true,
	DamageAfterDodge = true,
	DamageReduction = true,
	ThreatGeneration = true,
}
local function setBonusText(bonus): string
	local parts = {}
	for stat, amount in bonus do
		local shown = if SET_PERCENT[stat] then amount * 100 else amount
		local sign = if stat == "DamageReduction" or stat == "Cooldown" then "-" else "+"
		table.insert(
			parts,
			string.format(SET_STAT[stat] or ("%s " .. stat), sign .. tostring(math.floor(shown * 10 + 0.5) / 10))
		)
	end
	table.sort(parts)
	return table.concat(parts, "  ·  ")
end
local function setCard(parent: Instance, order: number, family: string, count: number, tier: number)
	local spec = ArmorFamilies.Families[family]
	local tint = spec and spec.Color or P.Gold
	local card = new("Frame", {
		BackgroundColor3 = C.Card,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	round(card, 4)
	stroke(card, tint:Lerp(C.PanelEdge, 0.4), 1)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, card)
	UiKit.list(card, 4).SortOrder = Enum.SortOrder.LayoutOrder
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0 }, card)
	at(label(top, string.upper(family), 13, tint, HEADING), 0, 0, 160, 18)
	-- Six pips, lit up to the pieces worn.
	for i = 1, 6 do
		local pip = box(top, if i <= count then tint else C.Track, 2)
		pip.AnchorPoint = Vector2.new(1, 0.5)
		pip.Position = UDim2.new(1, -(6 - i) * 14 - 34, 0.5, 0)
		pip.Size = UDim2.fromOffset(10, 6)
	end
	local tally = at(label(top, string.format("%d/6", count), 11, C.Text, BOLD), 0, 0, 30, 18)
	tally.AnchorPoint = Vector2.new(1, 0)
	tally.Position = UDim2.new(1, 0, 0, 0)
	tally.TextXAlignment = Enum.TextXAlignment.Right
	for index, need in { 2, 4, 6 } do
		local on = tier == need
		local reached = count >= need
		local row = label(
			card,
			string.format("%d  %s", need, setBonusText(ArmorFamilies.Sets[family][need] or {})),
			11,
			if on then C.Text elseif reached then C.Dim else C.Faint,
			if on then BOLD else BODY
		)
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.TextWrapped = true
		row.TextTruncate = Enum.TextTruncate.None
		row.LayoutOrder = index
		row.RichText = false
	end
	if count >= 2 and ArmorFamilies.EnhancementText[family] then
		local perk = line(card, 4, ArmorFamilies.EnhancementText[family], 10, tint:Lerp(C.Text, 0.35))
		perk.LayoutOrder = 4
	end
end
local function surgeRow(parent: Instance, order: number, key: string, gem)
	local surge = gem and Tech.surgeStats(gem)
	local tint = if gem then gemColor(gem) else C.PanelEdge
	local row = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.Card,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = order,
	}, parent)
	round(row, 4)
	stroke(row, tint, 1, if gem then 0.2 else 0.5)
	row:SetAttribute("UiSound", "Click")
	local letter = at(label(row, key, 16, if gem then C.Text else C.Faint, HEADING), 10, 0, 22, 46)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	local art = new("Frame", { BackgroundTransparency = 1 }, row)
	at(art, 38, 5, 36, 36)
	if gem then
		gemArt(art, gem)
	end
	at(
		label(row, if surge then surge.Name else "Empty", 13, if gem then tint:Lerp(C.Text, 0.3) else C.Faint, BOLD),
		84,
		6,
		260,
		18
	)
	at(
		label(
			row,
			if surge
				then string.format(
					"%s %s  ·  %ss cooldown",
					whole(surge.Cost or 0),
					surge.Resource or "Charge",
					whole(surge.Cooldown or 0)
				)
				else "Drag a cut gem here to cast its surge",
			10,
			C.Dim,
			BODY
		),
		84,
		24,
		300,
		16
	)
	row.Activated:Connect(function()
		select({ Kind = "Key", Key = key })
	end)
end

-- Draws `pick`'s details (or, with no pick, the build summary) into
-- `container`. False when the pick no longer exists.
local function drawOverview(container: Instance, pick: Pick?): boolean
	local loadout = loadoutNow()
	local holder = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.PanelEdge,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 1),
	}, container)
	local list = UiKit.list(holder, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, holder)
	if container == page then
		footer.Text = "TAP A PIECE, A GEM OR A SURGE KEY FOR ITS DETAILS"
	end
	if pick and (pick.Kind == "Worn" or pick.Kind == "Spare") then
		local slot = pick.Slot :: string
		local id = if pick.Kind == "Spare" then pick.Id else loadout[slot]
		local gear = gearOf(loadout, slot, id)
		if not gear then
			holder:Destroy()
			return false
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
		local signatureName, signatureText = ArmorSignatures.describe(roll, gem)
  if signatureName ~= "" then
   line(holder, 3, "SIGNATURE - " .. string.upper(signatureName), 10, C.Gold, BOLD)
   line(holder, 4, signatureText, 12, C.Text)
   local affinities = {}
   for _, affix in roll.Affixes or {} do table.insert(affinities, GemConfig.affixText(affix.Id, affix.Bonus)) end
   if #affinities > 0 then line(holder, 4, table.concat(affinities, " / "), 11, C.Dim) end
  end
  local passive = if signatureName == "" then gear.Passive else nil
		if passive and passive.Text then
			line(holder, 3, string.upper(passive.Name or "PASSIVE"), 10, C.Dim, BOLD)
			line(holder, 4, passive.Text, 12, C.Text)
		end
		line(holder, 5, "GEM SOCKET", 10, C.Dim, BOLD)
		if gem then
			local name, effect = GemConfig.enchantment(gem, slot)
			if signatureName ~= "" then name, effect = "Signature enchantment", signatureText end
			line(holder, 6, string.format("%s: %s", name, effect), 12, gemColor(gem), BOLD)
		else
			line(holder, 6, "Empty. Drag a cut gem from GEMS onto this piece.", 12, C.Dim)
		end
		local pickGem = {
			"PICK A GEM",
			false,
			function()
				selection = nil
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
		return true
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
			-- Or into a worn piece, one tap (no dragging needed).
			line(holder, 6, "SOCKET INTO GEAR", 10, C.Dim, BOLD)
			local sockets =
				new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 7 }, holder)
			new("UIGridLayout", {
				CellSize = UDim2.new(1 / 3, -6, 0, 28),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, sockets)
			for index, slot in Slots.Order do
				local worn = gearOf(loadout, slot)
				local taken = loadout[slot .. "Gem"] ~= nil
				local b = new("TextButton", {
					Text = SLOT_LABEL[slot] .. (if taken then " ◆" else ""),
					TextSize = 10,
					Font = BOLD,
					TextColor3 = if worn then C.Text else C.Faint,
					BackgroundColor3 = C.Card,
					AutoButtonColor = worn ~= nil,
					LayoutOrder = index,
				}, sockets)
				round(b, 4)
				stroke(b, if worn then color else C.PanelEdge, 1, 0.4)
				b:SetAttribute("UiSound", "Confirm")
				b.Activated:Connect(function()
					if worn then
						request("SocketGem", gem.Id, slot)
					end
				end)
			end
			line(holder, 8, "◆ = already holds a gem (it goes back to your pouch).", 10, C.Faint)
		else
			line(holder, 2, "A rough gem: cut it before it can be socketed.", 12, C.Dim)
		end
		return true
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
						selection = nil
						tab = "Gems"
						draw()
					end,
				},
			})
		end
		return true
	end
	-- Nothing picked: the build at a glance.
	local class = loadout.Class and Classes.get(loadout.Class)
	local state = if loadout.Class then Classes.setState(loadout) else { Active = {} }
	header(holder, class and class.Name or "Miner", "YOUR BUILD", P.Gold, emblem("Equipment", P.Gold))

	-- Armor sets: progress to 6, and what each tier gives (the highest
	-- reached replaces the lower ones).
	line(holder, 1, "ARMOR SETS", 10, C.Dim, BOLD)
	local shownSets = 0
	for index, family in ArmorFamilies.Order do
		local active = state.Active[family]
		local count = if active then active.Count else 0
		if count > 0 then
			shownSets += 1
			setCard(holder, 1 + index, family, count, active.Tier)
		end
	end
	if shownSets == 0 then
		line(holder, 2, "Wear matching pieces of one family (2 / 4 / 6) for set bonuses.", 12, C.Dim)
	end

	-- Surges on Q / E / R.
	line(holder, 10, "SURGE ARRAY", 10, C.Dim, BOLD)
	for index, key in { "Q", "E", "R" } do
		surgeRow(holder, 10 + index, key, Tech.surgeGem(loadout, key))
	end

	-- Gems in gear.
	local attuned, elements = 0, {}
	for _, slot in Slots.Order do
		local gem = loadout[slot .. "Gem"]
		if gem then
			attuned += 1
			elements[gem.Element] = (elements[gem.Element] or 0) + 1
		end
	end
	line(holder, 20, "GEAR GEMS", 10, C.Dim, BOLD)
	local chips =
		{ { string.format("%d / %d sockets attuned", attuned, #Slots.Order), if attuned > 0 then C.Text else C.Dim } }
	for _, element in GemConfig.Elements do
		if elements[element] then
			table.insert(chips, {
				string.format("%s ×%d", GemConfig.elementName(element), elements[element]),
				GemConfig.ElementColors[element],
			})
		end
	end
	chipRow(holder, 21, chips)
	line(holder, 22, "Tap any piece, key or gem for details. Drag gems onto sockets or Q · E · R.", 11, C.Faint)
	return true
end

-- Details popup: a smaller window over the Inventory for whatever you tap.
-- Tap outside it, the ✕ or Esc to close.
local POP_W, POP_H = 480, 420
local shade = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Position = UDim2.fromOffset(-16, -16),
	Size = UDim2.new(1, 32, 1, 32),
	ZIndex = 20,
	Visible = false,
}, root)
round(shade, 8)
shade:SetAttribute("UiSound", "Back")
-- (A button too, so taps on the window don't reach the shade.)
local popCard = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 16 + PANEL_H / 2),
	Size = UDim2.fromOffset(POP_W, POP_H),
}, shade)
round(popCard, 6)
stroke(popCard, P.Gold, 1.5)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(30, 24, 52), C.Panel) }, popCard)
brackets(popCard, P.Gold, 12, 6)
local popTitle = at(label(popCard, "DETAILS", 11, C.Dim, BOLD), 20, 12, POP_W - 80, 22)
local popBody = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true }, popCard)
popBody.Position, popBody.Size = UDim2.fromOffset(20, 42), UDim2.new(1, -32, 1, -58)
local function closeDetails()
	if selection then
		selection = nil
		draw()
	end
end
local popClose = new("TextButton", {
	Text = "✕",
	TextSize = 16,
	Font = HEADING,
	TextColor3 = C.Text,
	AutoButtonColor = true,
	BackgroundColor3 = P.Frame,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(30, 28),
}, popCard)
round(popClose, 5)
stroke(popClose, C.PanelEdge, 1)
popClose:SetAttribute("UiSound", "Back")
popClose.Activated:Connect(closeDetails)
shade.Activated:Connect(closeDetails)

local POP_TITLE = { Worn = "WORN GEAR", Spare = "SPARE GEAR", Gem = "GEM", Key = "SURGE KEY" }
local function drawPopup()
	clear(popBody)
	local pick = selection
	if pick and not drawOverview(popBody, pick) then
		selection = nil
		pick = nil
	end
	shade.Visible = pick ~= nil
	if not pick then
		return
	end
	popTitle.Text = POP_TITLE[pick.Kind] or "DETAILS"
	-- As tall as its contents (up to POP_H; longer ones scroll).
	local holder = popBody:FindFirstChildWhichIsA("ScrollingFrame")
	local layout = holder and holder:FindFirstChildWhichIsA("UIListLayout")
	if layout then
		local function fit()
			popCard.Size = UDim2.fromOffset(POP_W, math.clamp(layout.AbsoluteContentSize.Y + 72, 200, POP_H))
		end
		fit()
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	end
end
UserInputService.InputBegan:Connect(function(input)
	if
		shade.Visible
		and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB)
		and hostGui
		and hostGui.Enabled
	then
		closeDetails()
	end
end)

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
				selection = nil
				tab = "Overview"
				draw()
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
	stageTag.Text = if best
		then string.format("%s SET  ·  %d / 6", string.upper(best), bestCount)
		else "NO ARMOR SET YET"
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
		flashStat(name, value)
	end
	statTiles.Rating.Value.Text = whole(total)
	flashStat("Rating", total)
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
		picker.Hint.Text = string.format("On loadout %d  ·  autosaves", current)
	end

	-- Worn pieces (art redrawn only when the piece or its gem changes).
	for slot, card in wornCards do
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = rarityColor(rarity)
		local picked = (selection and selection.Kind == "Worn" and selection.Slot == slot)
			or (tab == "Armor" and armorFilter == slot)
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
		drawOverview(page, nil)
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
		drawPopup()
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
			-- Reopening starts without a popup.
			selection = nil
			shade.Visible = false
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
