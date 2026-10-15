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
local TweenService = game:GetService("TweenService")

local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GearArt = require(script.Parent.GearArt)
local InventoryPose = require(script.Parent.InventoryPose)
local SurgeIcons = require(script.Parent.SurgeIcons)
local ElementCardFX = require(script.Parent.ElementCardFX)
local StatRadar = require(script.Parent.StatRadar)
local StageBackdrop = require(script.Parent.StageBackdrop)
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
	Panel = Color3.fromRGB(13, 13, 18),
	PanelEdge = Color3.fromRGB(42, 42, 56),
	Card = Color3.fromRGB(20, 20, 29),
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
local PERK_SHORT = {
	ChargeGain = "Charge from sword hits", Countercharge = "Charge on timed block",
	Conductor = "More hit Charge; slower stamina regen", Momentum = "Bonus Charge every third sword hit",
	Recycler = "Hits trigger Charge regeneration", LifeSteal = "Life steal on sword damage",
	Barrier = "Barrier after timed block", Riposte = "Bonus sword hit after timed block",
	StaminaRefund = "Stamina refund on successful dodge", Pursuit = "Speed boost after heavy sword hit",
	GuardEfficiency = "Guard efficiency",
}
local HEADING, BOLD, BODY = IronUi.Heading, IronUi.Bold, IronUi.Body

local W, H = 1400, 638
local ROSTER_H = 0
-- The stash on the right is the gear column's twin: same width, same height.
local LEFT_W, RIGHT_X, PANEL_H = 810, 1400 - 18 - 300, 588

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
	-- Retired: the screen reads cleaner without corner ornaments.
	if true then
		return
	end
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
 if gem.Role == "Core" then return GemConfig.elementName(gem.Element) .. " Core" end
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
local showTip, hideTip -- (below) item tooltips on hover
local hostGui: ScreenGui? = nil

local function panel(x: number, y: number, w: number, h: number, _accent: Color3): Frame
	-- A flat surface with a hairline edge.
	local frame = box(root, C.Panel, 10)
	at(frame, x, y, w, h)
	stroke(frame, C.PanelEdge, 1, 0.35)
	return frame
end
local left = panel(0, ROSTER_H, LEFT_W, PANEL_H, P.Gold)
local right = panel(RIGHT_X, ROSTER_H, W - RIGHT_X, PANEL_H, P.Teal)
local inventoryModal = new("Frame", {
	Name = "InventoryPicker", BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1), ZIndex = 50, Visible = false,
}, root)
local modalDismiss = new("TextButton", {
	Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 1,
}, inventoryModal)
-- The inventory is docked on the right, always open: no dimmer behind it.
right.Parent = inventoryModal
right.ZIndex = 2
modalDismiss.Visible = false

-- Selection and drag state.
type Pick = { Kind: string, Slot: string?, Id: string?, Gem: any?, Key: string? }
local selection: Pick? = nil
local tab = "Gems"
local armorFilter = "All"
local gemFilter = "All"
local contextSlot: string? = nil
local contextKey: string? = nil
local stashOpen = false -- the drawer opened on its own (not for a slot or key)
local previewVersion = 0
local dropTargets: { any } = {}
local drag: { Item: any, Start: Vector2, Active: boolean, Touch: boolean, Ghost: Frame? }? = nil
local suppressClickUntil = 0
local draw -- (below): redraws everything
local radarStats = nil -- the build in numbers, for the stat radar

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

local COL_W, CARD_H, ROW_GAP = 300, 91, 9
local BODY_Y = 44
local LEFT_COL, MID_X, RIGHT_COL = 18, 330, LEFT_W - 18 - COL_W
local MID_W = 300
local STAGE_H = 236

local nameLabel = at(label(left, "", 16, C.Text, HEADING), 20, 8, 420, 26)
local subtitle = at(label(left, "", 11, C.Dim, BOLD), 800, 10, 570, 20)
subtitle.TextXAlignment = Enum.TextXAlignment.Right
subtitle.RichText = true

-- The stage: your fighter, full height, on a lit plinth.
local portrait = box(left, P.Frame, 6)
portrait.BackgroundColor3 = Color3.new(1, 1, 1)
at(portrait, MID_X, BODY_Y, MID_W, STAGE_H)
stroke(portrait, C.PanelEdge, 1)
portrait.ClipsDescendants = true
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(24, 43, 53), Color3.fromRGB(8, 14, 21)),
}, portrait)
-- A war-hangar bay behind the three miners (animated with the card effects).
local stageBackdrop = StageBackdrop.create(portrait)
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
	-- The fan below renders the three authoritative miner mannequins.
	portraitView.Visible = false
	return
end

local function renderMiner(view: ViewportFrame, source: Model, loadout)
	view:ClearAllChildren()
	local world = new("WorldModel", {}, view)
	local copy = source:Clone()
	copy.Parent = world
	copy:PivotTo(CFrame.new())
	-- (Animated skins move here as they do on you. Required here: this
	-- module has no locals to spare.)
	require(script.Parent.LiveLooks).watch(copy)
	local armor = loadout and ArmorFamilies.ById[loadout.Armor]
	InventoryPose.apply(copy, armor and armor.ArmorFamily)
	local bounds, size = copy:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30 }, view)
	local distance = math.max(size.Y * 0.65, size.X * 0.9) / math.tan(math.rad(15))
	camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(distance * 0.08, size.Y * 0.03, -distance), bounds.Position)
	view.CurrentCamera = camera
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
local RADAR_AXIS = { Health = 1, Power = 2, Speed = 3, Defense = 6 }
local radar = nil -- the stat radar (built in drawRight)
local radarRating: TextLabel? = nil
local function flashStat(name: string, value: number)
	local before = lastStat[name]
	lastStat[name] = value
	local tile = statTiles[name]
	if before == nil or math.abs(value - before) < 0.5 or not tile then
		return
	end
	local gain = value - before
	local color = if gain > 0 then P.Good else P.Bad
	local text = string.format("%s%d", if gain > 0 then "+" else "", math.floor(gain + 0.5))
	-- The stats live on the radar now: flash the value there.
	local axis = RADAR_AXIS[name]
	if radar and axis then
		StatRadar.flash(radar, axis, text, color)
	elseif name == "Rating" and radarRating then
		radarRating.TextColor3 = color
		game:GetService("TweenService"):Create(radarRating, TweenInfo.new(1.1), { TextColor3 = P.Gold }):Play()
	end
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

-- Whole-character roster: each card selects one miner and their progression.
local minerCards = {}
local rosterHeader = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, portrait)
local MINER_W = (W - 24) / 3
for index = 1, MinerRoster.Count do
	local button = new("TextButton", { Text = "", BackgroundColor3 = C.Card }, rosterHeader)
	at(button, (index - 1) * (MINER_W + 12), 0, MINER_W, 76)
	round(button, 8)
	local edge = stroke(button, C.PanelEdge, 1.5)
	local art = new("Frame", { BackgroundTransparency = 1 }, button)
	at(art, 8, 7, 62, 62)
	local name = at(label(button, "MINER " .. index, 17, C.Text, HEADING), 82, 10, 200, 22)
	local status = at(label(button, "LEVEL 1", 12, C.Dim, BOLD), 82, 38, 270, 18)
	local state = at(label(button, "SELECT", 11, C.Dim, BOLD), MINER_W - 88, 13, 78, 18)
	state.TextXAlignment = Enum.TextXAlignment.Right
	button:SetAttribute("UiSound", "Tab")
	button.Activated:Connect(function()
		InventoryScreen.cancelDrag()
		selection = nil
		request("MinerSelect", index)
	end)
	minerCards[index] = { Button = button, Edge = edge, Name = name, Status = status, State = state, Art = art }
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundTransparency = 1
	edge.Transparency = 1
	art.Position, art.Size = UDim2.fromScale(0, 0), UDim2.new(1, 0, 1, -48)
	name.Position, name.Size = UDim2.new(0, 0, 1, -46), UDim2.new(1, 0, 0, 20)
	name.TextXAlignment = Enum.TextXAlignment.Center
	status.Position, status.Size = UDim2.new(0, 0, 1, -24), UDim2.new(1, 0, 0, 18)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextSize = 10
	state.Visible = false
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(160, 165, 185), LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.5, -0.8, -0.6),
	}, art)
	minerCards[index].View = view
end

-- The worn pieces.
local wornCards = {}
local function wornCard(slot: string, column: number, row: number)
	local cell = cellAt(column, row)
	cell.ClipsDescendants = true
	cell.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient carries the colour
	local edge = stroke(cell, rarityColor(1), 1.5)
	local glow = new("UIGradient", { Rotation = 0, Color = ColorSequence.new(C.Card, C.Card) }, cell)
	local hit =
		new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, cell)
	hit:SetAttribute("UiSound", "Click")
	local metadata = at(label(cell, SLOT_LABEL[slot], 9, C.Dim, BOLD), 10, 4, CELL_W - 20, 12)
	metadata.TextTruncate = Enum.TextTruncate.AtEnd
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
	-- Tap a slot to open its window (ARMOR / GEMS, filtered to this slot).
	-- It opens where the slot needs work: an empty slot on ARMOR, a piece
	-- with an empty socket on GEMS, a full slot on ARMOR to swap the piece.
	hit.Activated:Connect(function()
		if os.clock() >= suppressClickUntil then
			local loadout = loadoutNow()
			selection = nil
			contextSlot, contextKey = slot, nil
			armorFilter, gemFilter = slot, "All"
			tab = if loadout[slot] ~= nil and loadout[slot .. "Gem"] == nil then "Gems" else "Armor"
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
	cell:SetAttribute("TutorialSocket", slot)
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
		Socket = socket,
		Metadata = metadata,
	}
	hit.MouseEnter:Connect(function()
		wornCards[slot].Hovered = true
		showTip({ Kind = "Worn", Slot = slot }, cell)
		draw()
	end)
	hit.MouseLeave:Connect(function()
		hideTip()
		wornCards[slot].Hovered = false
		draw()
	end)
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

-- The Armory: gear flanks the miner, worn-side by side. Head, chest and
-- hands on the left; sword, shield and feet on the right.
local ARMORY_ROW = { Helmet = 1, Armor = 2, Gloves = 3, Boots = 4, Weapon = 5, Shield = 6 }
for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" } do
	local card = wornCards[slot]
	at(card.Cell, 18, BODY_Y + (ARMORY_ROW[slot] - 1) * 88, CELL_W, 84)
	card.Cell:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
	card.Rail = box(card.Cell, C.PanelEdge, 0)
	at(card.Rail, 0, 0, 3, 84)
	at(card.Metadata, 12, 5, CELL_W - 92, 11)
	card.Badge = box(card.Cell, C.Track, 4)
	at(card.Badge, CELL_W - 77, 5, 66, 13)
	card.Rarity.Parent = card.Badge
	at(card.Rarity, 2, 0, 62, 13)
	card.Rarity.TextSize = 8
	card.Rarity.TextXAlignment = Enum.TextXAlignment.Center
	card.Rarity.TextTruncate = Enum.TextTruncate.AtEnd
	-- Display mounts stay behind the previews when their contents refresh.
	card.GearWell = box(card.Cell, Color3.fromRGB(10, 20, 29), 5)
	at(card.GearWell, 10, 32, 78, 35)
	card.GearEdge = stroke(card.GearWell, C.PanelEdge, 1, 0.3)
	new("UIGradient", { Rotation = 100, Color = ColorSequence.new(Color3.fromRGB(190, 220, 235), Color3.fromRGB(80, 100, 125)) }, card.GearWell)
	card.Art.Parent = card.GearWell
	at(card.Art, 11, -1, 56, 36)
	card.Art.BackgroundTransparency = 1
	at(card.Name, 10, 17, CELL_W - 20, 14)
	card.Name.TextSize = 11
	card.Name.TextWrapped = false
	card.Name.TextTruncate = Enum.TextTruncate.AtEnd
	card.Name.TextYAlignment = Enum.TextYAlignment.Top
	card.Rarity.Visible = true
	card.Socket.Visible = false
	for _, x in { 98, 198 } do
		local divider = box(card.Cell, C.PanelEdge, 0)
		at(divider, x, 36, 1, 27)
		divider.BackgroundTransparency = 0.45
	end
	card.GemWell = box(card.Cell, C.Track, 5)
	at(card.GemWell, 113, 32, 70, 25)
	card.GemEdge = stroke(card.GemWell, C.PanelEdge, 1, 0.5)
	card.FX = ElementCardFX.create(card.Cell, card.GemWell)
	card.GemArt = new("Frame", { BackgroundTransparency = 1 }, card.Cell)
	at(card.GemArt, 123, 28, 50, 32)
	card.GemLabel = at(label(card.Cell, "NO GEM", 8, C.Faint, BOLD), 106, 58, 84, 10)
	card.GemLabel.TextXAlignment = Enum.TextXAlignment.Center
	card.GemLabel.BackgroundTransparency = 0.8
	round(card.GemLabel, 3)
	card.EmptyGem = at(label(card.GemArt, "+", 22, C.Faint, BOLD), 0, 0, 42, 36)
	card.EmptyGem.TextXAlignment = Enum.TextXAlignment.Center
	local statWell = box(card.Cell, Color3.fromRGB(10, 18, 25), 5)
	at(statWell, 203, 32, 87, 35)
	at(label(card.Cell, "ITEM STATS", 8, C.Dim, BOLD), 209, 33, 78, 11)
	card.Stats = at(label(card.Cell, "—", 12, C.Text, BOLD), 206, 44, 84, 24)
	local perkStrip = box(card.Cell, Color3.fromRGB(42, 35, 22), 0)
	at(perkStrip, 3, 69, CELL_W - 3, 15)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 233, 171), Color3.fromRGB(130, 151, 178)), Rotation = 0 }, perkStrip)
	local perkMarker = box(perkStrip, C.Gold, 2)
	at(perkMarker, 8, 6, 4, 4)
	card.Trait = at(label(perkStrip, "", 9, C.Gold, BOLD), 18, 1, CELL_W - 30, 13)
	card.Trait.TextTruncate = Enum.TextTruncate.AtEnd
	card.Stats.TextYAlignment = Enum.TextYAlignment.Top
	card.Stats.TextWrapped = false
	card.Stats.TextTruncate = Enum.TextTruncate.AtEnd
	-- Full equipment details remain in the contextual EQUIPPED tab.
	for _, child in card.Cell:GetChildren() do
		if child:IsA("TextButton") and child.Text == "DETAILS" then child.Visible = false end
	end
end

-- The Surge Array: Q / E / R keys, each showing its gem.
local surgeCell = box(left, P.Frame, 4)
at(surgeCell, RIGHT_COL, BODY_Y + 2 * (CARD_H + ROW_GAP), CELL_W, 2 * CARD_H + ROW_GAP)
stroke(surgeCell, C.PanelEdge, 1)
brackets(surgeCell, P.Teal, 8, 4)
at(label(surgeCell, "SURGES · SELECT TO CHANGE", 10, C.Dim, BOLD), 12, 5, 280, 14)
local KEY_W = math.floor((CELL_W - 24 - 2 * 6) / 3)
local surgeKeys = {}
for i, key in { "Q", "E", "R" } do
	local keyBox = new("TextButton", { Text = "", BackgroundColor3 = C.Card, AutoButtonColor = true }, surgeCell)
	at(keyBox, 12 + (i - 1) * (KEY_W + 6), 28, KEY_W, 2 * CARD_H + ROW_GAP - 40)
	round(keyBox, 4)
	keyBox:SetAttribute("UiSound", "Click")
 keyBox:SetAttribute("TutorialSocket", key)
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
			selection = nil
			contextSlot, contextKey = nil, key
			tab, gemFilter = "Gems", "All"
			draw()
		end
	end)
	surgeKeys[key] = { Box = keyBox, Stroke = edge, Name = name, Letter = letter, Art = art, Shown = "" }
	surgeKeys[key].Info = at(label(keyBox, "", 10, C.Dim, BODY), 10, 60, 160, 30)
	local icon = label(keyBox, "+", 22, C.Dim, BOLD)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	surgeKeys[key].Icon = icon
	local description = label(keyBox, "", 10, C.Text, BODY)
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextTruncate = Enum.TextTruncate.AtEnd
	surgeKeys[key].Description = description
	local ui = surgeKeys[key]
	keyBox.BackgroundColor3 = Color3.new(1, 1, 1)
	keyBox.AutoButtonColor = false
	keyBox.ClipsDescendants = true
	keyBox:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
	ui.Glow = new("UIGradient", { Rotation = 110, Color = ColorSequence.new(C.Card, C.Panel) }, keyBox)
	ui.Rail = box(keyBox, C.Accent, 0)
	ui.Rail.Position, ui.Rail.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 2)
	ui.IconMount = box(keyBox, Color3.fromRGB(7, 15, 24), 6)
	ui.IconEdge = stroke(ui.IconMount, C.PanelEdge, 1)
	ui.Icon.Parent = ui.IconMount
	ui.Icon.Position, ui.Icon.Size = UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -6)
	ui.GemBadge = box(keyBox, C.Track, 4)
	local gemFXArea = new("Frame", { BackgroundTransparency = 1 }, ui.GemBadge)
	at(gemFXArea, 2, 0, 28, 22)
	ui.FX = ElementCardFX.create(keyBox, gemFXArea)
	ui.Art.Parent = ui.GemBadge
	ui.Element = label(ui.GemBadge, "", 8, C.Dim, BOLD)
	ui.Element.TextTruncate = Enum.TextTruncate.AtEnd
	ui.KeyBadge = box(keyBox, C.Track, 4)
	ui.Letter.Parent = ui.KeyBadge
	ui.Charge = box(keyBox, Color3.fromRGB(14, 30, 39), 4)
	ui.ChargeText = label(ui.Charge, "", 10, C.Accent, BOLD)
	ui.Cooldown = box(keyBox, Color3.fromRGB(24, 29, 40), 4)
	ui.CooldownText = label(ui.Cooldown, "", 10, C.Text, BOLD)
	for _, text in { ui.ChargeText, ui.CooldownText } do
		text.Size = UDim2.fromScale(1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Center
	end
	ui.Info.Visible = false
	ui.Name.TextSize = 12
	ui.Name.TextWrapped = false
	ui.Name.TextTruncate = Enum.TextTruncate.AtEnd
	keyBox.MouseEnter:Connect(function() ui.Hovered = true; draw() end)
	keyBox.MouseLeave:Connect(function() ui.Hovered = false; draw() end)
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
local setSummary = at(label(left, "", 11, C.Gold, BODY), MID_X, 534, 782, 42)
setSummary.TextWrapped = true
setSummary.TextYAlignment = Enum.TextYAlignment.Top
local scouting = box(left, Color3.fromRGB(12, 23, 33), 6)
at(scouting, 1130, 426, 252, 150)
stroke(scouting, C.Accent, 1, 0.65)
at(label(scouting, "OPPONENT SCOUTING", 11, C.Accent, BOLD), 10, 9, 232, 16)
local scoutReveal = at(label(scouting, "", 10, C.Text, BODY), 10, 29, 232, 34)
local scoutMix = at(label(scouting, "", 10, C.Dim, BODY), 10, 65, 232, 32)
local scoutTip = at(label(scouting, "", 10, C.Gold, BODY), 10, 100, 232, 44)
for _, text in { scoutReveal, scoutMix, scoutTip } do
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top
end

local RIGHT_W = W - RIGHT_X - 18
local tabHolder = new("Frame", { BackgroundTransparency = 1 }, right)
at(tabHolder, 16, 48, RIGHT_W - 32, 38)
local contextTitle = at(label(right, "SHARED STASH", 14, C.Text, HEADING), 16, 10, RIGHT_W - 100, 28)
local contextClose = new("TextButton", { Text = "BACK", Font = BOLD, TextSize = 11, TextColor3 = C.Dim, BackgroundColor3 = C.Card }, right)
at(contextClose, RIGHT_W - 118, 10, 60, 28)
contextTitle.Size = UDim2.fromOffset(RIGHT_W - 70, 28)
round(contextClose, 4)
contextClose.Activated:Connect(function()
	if selection then
		selection = nil
		draw()
		return
	end
	contextSlot, contextKey, selection = nil, nil, nil
	tab, armorFilter = "Gems", "All"
	draw()
end)
local function closeInventoryPicker()
	InventoryScreen.cancelDrag()
	contextSlot, contextKey, selection, stashOpen = nil, nil, nil, false
	tab, armorFilter = "Gems", "All"
	draw()
end
modalDismiss.Activated:Connect(closeInventoryPicker)
-- Opens the stash drawer on its own (gems and armor, no slot picked).
local stashButton = new("TextButton", {
	Text = "GEMS & ARMOR  ▸",
	TextSize = 11,
	Font = HEADING,
	TextColor3 = C.Text,
	BackgroundColor3 = C.Card,
	BackgroundTransparency = 0.1,
	AutoButtonColor = true,
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(150, 28),
	ZIndex = 8,
}, left)
round(stashButton, 14)
stroke(stashButton, P.Teal, 1, 0.3)
stashButton:SetAttribute("UiSound", "Open")
stashButton.Activated:Connect(function()
	stashOpen = true
	tab = "Gems"
	draw()
end)
local pickerClose = new("TextButton", {
	Text = "X", Font = BOLD, TextSize = 12, TextColor3 = C.Text, BackgroundColor3 = C.Card,
}, right)
at(pickerClose, RIGHT_W - 50, 10, 34, 28)
round(pickerClose, 4)
pickerClose.Activated:Connect(function()
	-- One close: a picked item first, then the slot, back to the stash.
	if selection then
		selection = nil
		draw()
	else
		closeInventoryPicker()
	end
end)
UserInputService.InputBegan:Connect(function(input)
	if hostGui and hostGui.Enabled and inventoryModal.Visible
		and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		closeInventoryPicker()
	end
end)
local page = new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true }, right)
at(page, 16, 94, RIGHT_W - 32, PANEL_H - 94 - 40)
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
		CellSize = UDim2.new(0.5, -6, 0, 96), -- two compact cards per row
		CellPadding = UDim2.fromOffset(6, 6),
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
	-- A dark plate lit from its top-left in the rarity's colour, a rarity
	-- strip along the top, the item in a glowing well, and (for a gem) its
	-- Size / Clarity / Cut as three small bars.
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		ClipsDescendants = true,
	}, parent)
	round(card, 8)
	card.BackgroundColor3 = C.Card
	card:SetAttribute("UiSound", "Click")
	local selected = selection ~= nil and samePick(selection, dragItem)
	local edge = stroke(card, if selected then C.Gold else C.PanelEdge, if selected then 1.5 else 1, if selected then 0 else 0.45)
	card.MouseEnter:Connect(function()
		showTip(dragItem, card)
		if not selected then
			edge.Color, edge.Transparency = color, 0.3
		end
	end)
	card.MouseLeave:Connect(function()
		hideTip()
		if not selected then
			edge.Color, edge.Transparency = C.PanelEdge, 0.45
		end
	end)
	-- The well: a dark socket with the tag's colour glowing up from below.
	local well = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, card)
	at(well, 7, 8, 42, 42)
	round(well, 21)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(P.Frame, P.Frame:Lerp(tagColor, 0.22)),
	}, well)
	local art = new("Frame", { BackgroundTransparency = 1 }, well)
	at(art, 2, 2, 38, 38)
	paint(art)
	local name = label(card, title, 11, C.Text, BOLD)
	name.Position, name.Size = UDim2.fromOffset(7, 54), UDim2.new(1, -14, 0, 14)
	local rarity = label(card, sub, 8, color, BOLD)
	rarity.Position, rarity.Size = UDim2.fromOffset(7, 68), UDim2.new(1, -60, 0, 10)
	local gem = dragItem and dragItem.Gem
	if gem and gem.Cut then
		local bars = new("Frame", { BackgroundTransparency = 1 }, card)
		bars.Position, bars.Size = UDim2.fromOffset(7, 81), UDim2.new(1, -14, 0, 9)
		for i, stat in { { "S", gem.Size }, { "C", gem.Clarity }, { "X", gem.Cut } } do
			local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1 / 3, -4, 1, 0), Position = UDim2.new((i - 1) / 3, 0, 0, 0) }, bars)
			local letter = label(cell, stat[1] .. " " .. tostring(stat[2] or "-"), 8, C.Dim, BOLD)
			letter.Size = UDim2.fromOffset(22, 9)
			local track = box(cell, C.Track, 2)
			track.Position, track.Size = UDim2.new(0, 24, 0.5, -1.5), UDim2.new(1, -24, 0, 3)
			local fill = box(track, tagColor, 2)
			fill.Size = UDim2.fromScale(math.clamp((tonumber(stat[2]) or 0) / 10, 0.05, 1), 1)
		end
	end
	-- The element (or slot): a small tinted pill in the top-right corner.
	local badge = new("TextLabel", {
		Text = tag,
		TextSize = 8,
		Font = BOLD,
		TextColor3 = tagColor:Lerp(C.Dim, 0.2),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -9, 0, 9),
		Size = UDim2.fromOffset(0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
	}, card)
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
	local chips = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, page)
	new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -4, 0, 21),
		CellPadding = UDim2.fromOffset(6, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	for i, entry in entries do
		local on = current == entry[1]
		local tint = entry[3] or P.Gold
		local chip = new("TextButton", {
			Text = entry[2],
			TextSize = 10,
			Font = BOLD,
			TextColor3 = if on then C.Text else tint:Lerp(C.Dim, 0.5),
			BackgroundColor3 = tint,
			BackgroundTransparency = if on then 0.78 else 1,
			LayoutOrder = i,
		}, chips)
		round(chip, 6)
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
		if keep and (not contextKey or (gem.Cut ~= nil and Tech.surgeStats(gem) ~= nil)) then
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
 local tutorial = profile and profile.Tutorial
 if require(ReplicatedStorage.Shared.Tutorial).Enabled and tutorial and not tutorial.Done then
  local teaching = {}
  for _, gem in gems do
   if (tutorial.GemIds and tutorial.GemIds[gem.Element] == gem.Id) or (not tutorial.GemIds and gem.Role == "Core") then
    table.insert(teaching, gem)
   end
  end
  if #teaching > 0 then gems = teaching end
 end
	return gems
end
local function gemsKey(): string
	local parts = { "Gems", gemFilter, pickKey(), contextSlot or "", contextKey or "" }
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
	local grid = scroller(page, 54)
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
		local gemCard = bagCard(
			grid,
			order,
			gemName(gem),
			tierColor,
			rarityName(gemRarity(gem)),
			if gem.Role == "Core" then "ENCHANT GEAR" elseif gem.Role == "Surge" then "ACTIVE ABILITY" elseif gem.Cut then string.upper(GemConfig.elementName(gem.Element)) else "ROUGH",
			if gem.Cut then gemColor(gem) else C.Faint,
			function(art)
				gemArt(art, gem)
			end,
			function()
				select({ Kind = "Gem", Gem = gem })
			end,
			{ Kind = "Gem", Gem = gem }
		)
  gemCard:SetAttribute("TutorialGem", gem.Element)
  gemCard:SetAttribute("TutorialGemId", gem.Id)
	end
	footer.Text = if contextKey then "CHOOSE A GEM TO EQUIP ITS SURGE ON " .. contextKey
		elseif contextSlot then "CHOOSE A GEM TO ENCHANT YOUR " .. SLOT_LABEL[contextSlot]
		elseif selection and selection.Kind == "Gem"
		then string.upper(gemName(selection.Gem)) .. "  ·  TAP FOR DETAILS, OR DRAG IT ONTO A SOCKET"
		else "TAP A GEM, OR DRAG IT ONTO GEAR"
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
			if gear and id ~= loadout[slot] and not MinerRoster.owner(profile, slot, id) then
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
	filterRow(if contextSlot then { { contextSlot, SLOT_LABEL[contextSlot] } } else FILTERS, armorFilter, function(id)
		armorFilter = id
		draw()
	end)
	local grid = scroller(page, 54)
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
					if gain > 0 then "▲ +" .. gain .. " RATING" elseif gain < 0 then "▼ " .. gain .. " RATING" else "= SAME",
					9,
					if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim,
					BOLD
				),
				7,
				80,
				64,
				11
			)
			local equip = new("TextButton", {
				Text = "EQUIP",
				TextSize = 10,
				Font = HEADING,
				TextColor3 = P.Frame,
				BackgroundColor3 = if gain > 0 then C.Good else P.Gold,
				AutoButtonColor = true,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -6),
				Size = UDim2.fromOffset(48, 20),
			}, card)
			round(equip, 4)
			equip:SetAttribute("UiSound", "Confirm")
			equip.Activated:Connect(function()
				request("EquipGear", Slots.Definitions[item.Slot].Kind, item.Id)
				-- A fresh piece with an empty socket: straight on to its gem.
				if contextSlot == item.Slot and loadoutNow()[item.Slot .. "Gem"] == nil then
					tab, selection = "Gems", nil
					draw()
				end
			end)
		end
	end
	if shown == 0 then
		emptyNote(
			page,
			if armorFilter == "All"
				then "Your shared stash is empty.\nGear worn by your other miners stays with them."
				else "No other "
					.. string.lower(SLOT_LABEL[armorFilter] or "gear")
					.. " to swap in yet.\nRecover more in the mine or trade for it."
		)
	end
	local worn = armorFilter ~= "All" and gearOf(loadout, armorFilter)
	footer.Text = if armorFilter ~= "All"
		then string.format(
			"WEARING %s",
			string.upper(worn and worn.Name or "NOTHING")
		)
		else "EQUIP TO PUT A PIECE ON"
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

-- Item tooltips ------------------------------------------------------------------------------------------
-- Hover any piece or gem for its full card, the way an RPG shows loot: the
-- name in its quality colour, what it is, its stats, its perk, its gem, its
-- set (bonuses you have lit, the rest dim), and for a spare piece how it
-- compares with what you wear.

do -- (scoped: the module is near Luau's 200-local limit)
local TIP_W = 290
local function titled(text: string): string
	return (string.gsub(string.lower(text), "(%a)([%w]*)", function(first, rest)
		return string.upper(first) .. rest
	end))
end
local tip = new("Frame", {
	Name = "ItemTooltip",
	BackgroundColor3 = Color3.fromRGB(10, 14, 21),
	BackgroundTransparency = 0.04,
	Size = UDim2.fromOffset(TIP_W, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 90,
	Visible = false,
	Active = false,
}, root)
round(tip, 6)
local tipEdge = stroke(tip, C.PanelEdge, 1.5, 0)
new("UIPadding", {
	PaddingLeft = UDim.new(0, 14),
	PaddingRight = UDim.new(0, 14),
	PaddingTop = UDim.new(0, 11),
	PaddingBottom = UDim.new(0, 12),
}, tip)
local tipList = UiKit.list(tip, 3)
tipList.SortOrder = Enum.SortOrder.LayoutOrder
local tipOrder = 0
local function tipLine(text: string, size: number, color: Color3, font: Enum.Font?, gap: number?)
	tipOrder += 1
	if gap then
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, gap), LayoutOrder = tipOrder, ZIndex = 90 }, tip)
		tipOrder += 1
	end
	local l = label(tip, text, size, color, font or BODY)
	-- Height from a width estimate (one line per newline, wrapped by length).
	local plain = string.gsub(text, "<[^>]+>", "")
	local perLine = math.max(8, math.floor((TIP_W - 28) / (size * 0.55)))
	local lines = 0
	for part in string.gmatch(plain .. "\n", "([^\n]*)\n") do
		lines += math.max(1, math.ceil(#part / perLine))
	end
	l.Size = UDim2.new(1, 0, 0, math.ceil(lines * size * 1.22))
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	l.RichText = true
	l.LayoutOrder = tipOrder
	l.ZIndex = 91
	return l
end
local function tipRule()
	tipOrder += 1
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = C.PanelEdge,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = tipOrder,
		ZIndex = 91,
	}, tip)
end
local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

local function tipGear(slot: string, id: string?, worn: boolean)
	local loadout = loadoutNow()
	local gear = gearOf(loadout, slot, id)
	if not gear then
		tipLine("Empty " .. string.lower(SLOT_LABEL[slot]), 15, C.Dim, HEADING)
		tipLine("Click to pick one.", 11, C.Faint)
		return C.PanelEdge
	end
	id = id or loadout[slot]
	local rarity = rarityOf(loadout, slot, id)
	local color = rarityColor(rarity)
	local gem = if worn then loadout[slot .. "Gem"] else (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id])
	local family = ArmorFamilies.ById[id :: string]
	tipLine(gear.Name, 16, color, HEADING)
	tipLine(
		string.format("%s %s%s", titled(rarityName(rarity)), titled(SLOT_LABEL[slot]), if family then "  ·  " .. family.ArmorFamily .. " set" else ""),
		11,
		C.Dim,
		BOLD
	)
	local roll = GearRolls.get(loadout, slot, id)
	local stats = {}
	for stat, amount in roll and roll.Stats or {} do
		table.insert(stats, statText(stat, amount))
	end
	table.sort(stats)
	if #stats > 0 then
		tipLine(table.concat(stats, "\n"), 15, C.Good, HEADING, 4)
	end
	if not worn then
		local gain = ratingGain(loadout, slot, id :: string)
		tipLine(
			if gain > 0 then string.format("▲ +%d rating over what you wear", gain)
				elseif gain < 0 then string.format("▼ %d rating against what you wear", gain)
				else "Same rating as what you wear",
			11,
			if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim,
			BOLD
		)
	end
	-- The perk.
	local signature = ArmorSignatures.resolve(roll, gem)
	if signature then
		local d = signature.Definition
		local function fmt(v: number): string
			return if d.Percent then string.format("%.1f%%", v * 100) else string.format("%.1f %s", v, d.Unit or "")
		end
		tipRule()
		tipLine(d.Name, 13, P.Gold, BOLD, 2)
		tipLine(d.Trigger .. "  <b>" .. fmt(signature.Value) .. "</b>", 12, C.Text)
	elseif gear.Passive and gear.Passive.Text then
		tipRule()
		tipLine(gear.Passive.Name or "Perk", 13, P.Gold, BOLD, 2)
		tipLine(gear.Passive.Text, 12, C.Text)
	end
	-- The gem.
	if gem then
		local parts = {}
		for _, l in GemConfig.lines(gem, slot) do
			table.insert(parts, l.Text)
		end
		tipLine(string.format('<font color="%s">◆ %s</font>', hex(gemColor(gem)), gemName(gem)), 13, C.Text, BOLD, 4)
		if #parts > 0 then
			tipLine(table.concat(parts, "\n"), 11, gemColor(gem):Lerp(C.Text, 0.35))
		end
	else
		tipLine("◇ Empty socket", 12, C.Faint, BOLD, 4)
	end
	-- The set: bonuses you have, bright; the rest, dim.
	if family and ArmorFamilies.Sets[family.ArmorFamily] then
		local state = loadout.Class and Classes.setState(loadout).Active[family.ArmorFamily]
		local count = state and state.Count or 0
		tipRule()
		tipLine(string.format("%s set  (%d/6)", family.ArmorFamily, count), 12, P.Gold:Lerp(C.Text, 0.2), BOLD, 2)
		for _, tier in { 2, 4, 6 } do
			local bonus = ArmorFamilies.Sets[family.ArmorFamily][tier]
			if bonus then
				local on = count >= tier
				tipLine(string.format("(%d) %s", tier, setBonusText(bonus)), 11, if on then C.Good else C.Faint)
			end
		end
	end
	tipLine(if worn then "Click to inspect  ·  drop a piece or gem on it" else "Click to try it on  ·  drag onto its slot", 10, C.Faint, BOLD, 4)
	return color
end

local function tipGem(gem)
	local color = gemColor(gem)
	tipLine(gemName(gem), 16, color, HEADING)
	tipLine(
		string.format("%s %s gem", titled(rarityName(gemRarity(gem))), GemConfig.elementName(gem.Element)),
		11,
		C.Dim,
		BOLD
	)
	if not gem.Cut then
		tipLine("Rough: cut it before it can be socketed.", 12, C.Faint, nil, 4)
		return color
	end
	tipLine(string.format("Size %s   ·   Clarity %s   ·   Cut %s", tostring(gem.Size), tostring(gem.Clarity), tostring(gem.Cut)), 12, C.Text, BOLD, 4)
	for _, use in { { "In armor", "Armor" }, { "In a weapon", "Weapon" } } do
		local parts = {}
		for _, l in GemConfig.lines(gem, use[2]) do
			table.insert(parts, l.Text)
		end
		if #parts > 0 then
			tipRule()
			tipLine(use[1], 12, P.Gold, BOLD, 2)
			tipLine(table.concat(parts, "\n"), 11, color:Lerp(C.Text, 0.4))
		end
	end
	local surge = Tech.surgeStats(gem)
	if surge then
		tipRule()
		tipLine("On Q / E / R  ·  " .. surge.Name, 12, P.Gold, BOLD, 2)
		tipLine(surge.Description or "", 11, C.Text)
		tipLine(string.format("%s Charge  ·  %ss cooldown", whole(surge.Cost or 0), whole(surge.Cooldown or 0)), 11, C.Dim, BOLD)
	end
	tipLine(if contextSlot then "Click to try it on " .. string.lower(SLOT_LABEL[contextSlot]) else "Click for details  ·  drag onto a slot", 10, C.Faint, BOLD, 4)
	return color
end

local tipAnchor: GuiObject? = nil
showTip = function(item, anchor: GuiObject)
	if drag and drag.Active then
		return
	end
	for _, child in tip:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	tipOrder = 0
	local color = C.PanelEdge
	if item.Kind == "Worn" then
		color = tipGear(item.Slot, nil, true)
	elseif item.Kind == "Spare" then
		color = tipGear(item.Slot, item.Id, false)
	elseif item.Kind == "Gem" then
		color = tipGem(item.Gem)
	else
		return
	end
	tipEdge.Color = color
	tipAnchor = anchor
	-- Beside the item, on whichever side has room, kept on screen.
	local scale = if root.Size.X.Offset > 0 then root.AbsoluteSize.X / root.Size.X.Offset else 1
	local a = (anchor.AbsolutePosition - root.AbsolutePosition) / scale
	local size = anchor.AbsoluteSize / scale
	local x = a.X + size.X + 10
	if x + TIP_W > W - 8 then
		x = a.X - TIP_W - 10
	end
	-- Low on the screen it grows upward from the item's foot instead.
	local low = a.Y + size.Y / 2 > H / 2
	tip.AnchorPoint = Vector2.new(0, if low then 1 else 0)
	tip.Position = UDim2.fromOffset(math.max(8, x), if low then math.min(H - 8, a.Y + size.Y) else math.max(8, a.Y))
	tip.Visible = true
end
hideTip = function()
	tipAnchor = nil
	tip.Visible = false
end
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
			line(holder, 1, "ITEM STATS · GENERATED ON THIS PIECE", 10, C.Dim, BOLD)
			chipRow(holder, 2, stats)
		end
		local signatureName, signatureText = ArmorSignatures.describe(roll, gem)
		if signatureName ~= "" then
			line(holder, 3, "SIGNATURE - " .. string.upper(signatureName), 10, C.Gold, BOLD)
			line(holder, 4, signatureText, 12, C.Text)
			local affinities = {}
			for _, affix in roll.Affixes or {} do
				table.insert(affinities, GemConfig.affixText(affix.Id, affix.Bonus))
			end
			if #affinities > 0 then
				line(holder, 4, table.concat(affinities, " / "), 11, C.Dim)
			end
		end
		local passive = if signatureName == "" then gear.Passive else nil
		if passive and passive.Text then
			line(holder, 3, string.upper(passive.Name or "PASSIVE"), 10, C.Dim, BOLD)
			line(holder, 4, passive.Text, 12, C.Text)
		end
		line(holder, 5, if gem then "GEM SOCKET  ·  " .. string.upper(gemName(gem)) else "GEM SOCKET", 10, if gem then gemColor(gem) else C.Dim, BOLD)
		if gem then
			local name, effect = GemConfig.enchantment(gem, slot)
			if signatureName ~= "" then
				name, effect = "Signature enchantment", signatureText
			end
			line(holder, 6, string.format("%s: %s", name, effect), 12, gemColor(gem), BOLD)
		else
			line(holder, 6, "Empty. Pick a gem on the right, or drag one onto this piece.", 12, C.Dim)
		end
		local pickGem = {
			if gem then "CHANGE GEM" else "ADD GEM",
			gem == nil,
			function()
				selection = nil
				contextSlot, contextKey = slot, nil
				tab, gemFilter = "Gems", "All"
				draw()
			end,
		}
		local swapPiece = {
			"SWAP",
			false,
			function()
				selection = nil
				contextSlot, contextKey = slot, nil
				tab, armorFilter = "Armor", slot
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
				pickGem,
				swapPiece,
				{
					"REMOVE",
					false,
					function()
						request("UnsocketGem", slot)
					end,
				},
			})
		else
			actions(holder, 9, { pickGem, swapPiece })
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
		if gem.Cut and (contextSlot or contextKey) then
			local targetSlot, targetKey = contextSlot, contextKey
			actions(holder, 0, {
				{ if targetKey then "EQUIP ON " .. targetKey else "ENCHANT " .. SLOT_LABEL[targetSlot], true, function()
					if targetKey then request("SocketSurge", gem.Id, targetKey)
					else request("SocketGem", gem.Id, targetSlot) end
					selection = nil
					draw()
				end },
			})
		end
		-- Choosing for a worn piece: what the gem does there, nothing else.
		if gem.Cut and contextSlot then
			local name, effect = GemConfig.enchantment(gem, contextSlot)
			local kind = ArmorSignatures.Slots[contextSlot]
			local roll = kind and loadout.GearRolls and loadout.GearRolls[kind] and loadout.GearRolls[kind][loadout[contextSlot]]
			local signatureName, signatureEffect = ArmorSignatures.describe(roll, gem)
			if signatureName ~= "" then
				name, effect = signatureName, signatureEffect
			else
				-- No signature to boost: list what Size, Clarity and Cut give here.
				local parts = {}
				for _, l in GemConfig.lines(gem, contextSlot) do
					table.insert(parts, l.Text)
				end
				if #parts > 0 then
					effect = table.concat(parts, "\n")
				end
			end
			line(holder, 2, "ON YOUR " .. SLOT_LABEL[contextSlot], 10, color, BOLD)
			line(holder, 3, name, 14, C.Text, BOLD)
			line(holder, 4, effect, 12, C.Text)
			local old = loadout[contextSlot .. "Gem"]
			line(
				holder,
				6,
				if old
					then "Replaces " .. gemName(old) .. " (it returns to your stash)."
					else "This socket is empty: enchanting it is pure gain.",
				11,
				C.Dim
			)
			return true
		end
		if surge then
			line(holder, 2, "SURGE  ·  " .. string.upper(surge.Name), 10, C.Dim, BOLD)
			line(holder, 3, surge.Description or "", 12, C.Text)
			chipRow(holder, 4, {
				{ string.format("%s %s", whole(surge.Cost or 0), surge.Resource or "Charge"), C.Accent },
				{ string.format("%ss cooldown", whole(surge.Cooldown or 0)), C.Dim },
			})
			if contextSlot or contextKey then
				if contextSlot then
					local name, effect = GemConfig.enchantment(gem, contextSlot)
					local kind = ArmorSignatures.Slots[contextSlot]
					local roll = kind and loadout.GearRolls and loadout.GearRolls[kind] and loadout.GearRolls[kind][loadout[contextSlot]]
					local signatureName, signatureEffect = ArmorSignatures.describe(roll, gem)
					if signatureName ~= "" then name, effect = signatureName, signatureEffect end
					line(holder, 5, "ENCHANTMENT / " .. SLOT_LABEL[contextSlot], 10, C.Accent, BOLD)
					line(holder, 6, name .. ": " .. effect, 12, C.Text)
				end
				line(holder, 8, "A gem occupies one slot. Replaced gems return to your stash.", 11, C.Dim)
				return true
			end
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
	Position = UDim2.new(0.5, 0, 0, ROSTER_H + 16 + PANEL_H / 2),
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
	-- Details now open in the stash panel on the right, so the miner and
	-- the gear stay in view; the popup stays shut.
	shade.Visible = false
	if true then
		return
	end
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
at(bar, 0, ROSTER_H + PANEL_H + 4, W - 230, 38)
new("UIScale", { Scale = 0.74 }, bar)
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
				-- The stash, opened or closed.
				selection = nil
				tab = "Gems"
				stashOpen = not (stashOpen or contextSlot ~= nil or contextKey ~= nil)
				if not stashOpen then
					contextSlot, contextKey = nil, nil
				end
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
	-- Flat text tabs; the current screen is bright with a gold underline.
	local b = new("TextButton", {
		Text = string.gsub(spec[1], "%s+%[", "  ["),
		TextSize = 17,
		Font = HEADING,
		TextColor3 = if spec[2] then C.Text else C.Dim,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
		LayoutOrder = order,
	}, bar)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, b)
	b:SetAttribute("UiSound", "Click")
	b.MouseEnter:Connect(function()
		b.TextColor3 = C.Text
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = if spec[2] then C.Text else C.Dim
	end)
	b.Activated:Connect(spec[3])
	if spec[2] then
		new("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.Gold, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, -28, 0, 2) }, b)
	end
end
local backButton = chunkButton(root, "BACK TO LOBBY", P.Gold, UDim2.fromOffset(160, 34), function()
	InventoryScreen.cancelDrag()
	local LobbyUI = require(script.Parent.LobbyUI) :: any
	if LobbyUI.closeDashboard then
		LobbyUI.closeDashboard()
	end
end)
backButton.AnchorPoint = Vector2.new(1, 0)
backButton.Position = UDim2.new(1, 0, 0, ROSTER_H + PANEL_H + 6)
backButton:SetAttribute("UiSound", "Back")
backButton:SetAttribute("TutorialSocket", "CloseInventory")

-- Drawing --------------------------------------------------------------------------------------------------

local function drawLeft()
	local profile = profileNow()
	local loadout = loadoutNow()
	local counts, names, mix = {}, {}, {}
	for _, slots in { GearPresets.GearSlots, GearPresets.SurgeSlots } do
		for _, slot in slots do
			local gem = loadout[slot .. "Gem"]
			if gem and gem.Element then counts[gem.Element] = (counts[gem.Element] or 0) + 1 end
		end
	end
	local most, leaders, dominant = 0, 0, nil
	for _, element in GearPresets.elements(loadout) do
		local name = string.upper(GemConfig.elementName(element))
		table.insert(names, name)
		table.insert(mix, name .. " ×" .. counts[element])
		if counts[element] > most then most, leaders, dominant = counts[element], 1, name
		elseif counts[element] == most then leaders += 1 end
	end
	scoutReveal.Text = if #names > 0 then "Revealed after a round: " .. table.concat(names, " · ") else "No equipped elements to reveal."
	scoutMix.Text = if #mix > 0 then "Your mix (gear + Surges): " .. table.concat(mix, " · ") else "Equip gems to shape this miner's elemental mix."
	scoutTip.Text = (if dominant and leaders == 1 then "Your mix leans " .. dominant .. ". " else "Your mix has no single leading element. ")
		.. "After a loss, swap miners between rounds to adapt. Counts are private."
	nameLabel.Text = "MINER " .. tostring(profile and profile.Miners and profile.Miners.Active or 1)
	nameLabel.Text ..= "  /  " .. string.upper(player.DisplayName)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Size = UDim2.fromOffset(LEFT_W - 40, 32)
	local class = loadout.Class and Classes.get(loadout.Class)
	local best, bestCount = nil, 0
	local active = loadout.Class and Classes.setState(loadout).Active or {}
	local setLines = {}
	for _, family in ArmorFamilies.Order do
		local state = active[family]
		if state and state.Count >= 2 then
			local tier = if state.Count >= 6 then 6 elseif state.Count >= 4 then 4 else 2
			table.insert(setLines, string.format("%s %d/6 · %s", family, state.Count, setBonusText(ArmorFamilies.Sets[family][tier])))
		end
		if state and state.Count > bestCount then
			best, bestCount = family, state.Count
		end
	end
	setSummary.Text = if #setLines > 0 then table.concat(setLines, "\n") else "Mix armor to shape your build. Set bonuses start at two matching pieces."
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
	-- The radar's numbers (drawn in drawRight).
	radarStats = { Total = total, Attuned = attuned, Set = bestCount or 0 }
	for _, name in Classes.StatNames do
		radarStats[name] = if ratings then ratings[name].Base + ratings[name].Bonus else 0
	end

	local roster = profile and profile.Miners
	for index, card in minerCards do
		local miner = roster and roster.Slots[index]
		local on = roster and roster.Active == index
		card.Button.BackgroundColor3 = if on then P.Gold:Lerp(P.Frame, 0.8) else C.Card
		card.Edge.Color = if on then P.Gold else C.PanelEdge
		card.Name.TextColor3 = if on then P.Gold else C.Text
		local level = Tree.level(miner and miner.Augments and miner.Augments.XP or 0)
		local c = if on then loadout else miner and miner.Character or {}
		local powers = 0
		for _, key in Slots.SurgeOrder do if c[key .. "Gem"] then powers += 1 end end
		card.Status.Text = string.format("LV %d  ·  %d/3 SURGES", level, powers)
		-- The header already names the active miner; only the others are labelled.
		card.Name.Visible = not on
		card.Status.Visible = not on
		card.State.Text = if on then "ACTIVE" else "SELECT"
		card.State.TextColor3 = if on then P.Gold else C.Dim
		local store = player.PlayerGui:FindFirstChild("MinerPreviews")
		local source = store and store:FindFirstChild(tostring(index))
		if source and source:IsA("Model") and card.Source ~= source then
			card.Source = source
			renderMiner(card.View, source, c)
		end
		local position = ((roster and roster.Active or 1) - index + 1) % 3
		if card.Position ~= position then
			local first = card.Position == nil
			card.Position = position
			if card.Tween then card.Tween:Cancel() end
			-- The Armory: your active miner fills the stage; the other two wait
			-- in the top corners, a tap away.
			local goal = {
				Position = UDim2.fromScale(({ [0] = 0.07, [1] = 0.5, [2] = 0.93 })[position], if on then 0.53 else 0.21),
				-- The active miner keeps one size as the stage widens or narrows.
				Size = if on then UDim2.new(0, 440, 1, 0) else UDim2.fromScale(0.11, 0.4),
			}
			card.Button.ZIndex = if on then 3 else 2
			card.Tween = TweenService:Create(card.Button, TweenInfo.new(if first then 0 else 0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
			card.Tween:Play()
			TweenService:Create(card.View, TweenInfo.new(0.4), { ImageTransparency = if on then 0 else 0.5 }):Play()
		end
		card.Status.TextColor3 = if on then P.Gold else C.Dim
	end

	-- Worn pieces (art redrawn only when the piece or its gem changes).
	for slot, card in wornCards do
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = rarityColor(rarity)
		local picked = (selection and selection.Kind == "Worn" and selection.Slot == slot)
			or contextSlot == slot
		card.Name.Text = if gear then gear.Name else "Empty"
		local roll = GearRolls.get(loadout, slot)
		local family = gear and ArmorFamilies.ById[loadout[slot]]
		card.Metadata.Text = SLOT_LABEL[slot] .. (if family then " / " .. string.upper(family.ArmorFamily) else " / EQUIPPED")
		local signature = ArmorSignatures.resolve(roll, gem)
		if signature then
			card.Trait.Text = PERK_SHORT[signature.Id] or signature.Definition.Name
		elseif gear and gear.Passive then
			card.Trait.Text = gear.Passive.Text or gear.Passive.Name or ""
		elseif gem then
			local enchantName = GemConfig.enchantment(gem, slot)
			card.Trait.Text = "Enchantment · " .. enchantName
		else
			card.Trait.Text = "Empty socket · add a gem to enchant"
		end
		local stats = {}
		for stat, amount in roll and roll.Stats or {} do
			table.insert(stats, { Name = stat, Amount = amount })
		end
		table.sort(stats, function(a, b)
			if math.abs(a.Amount) ~= math.abs(b.Amount) then return math.abs(a.Amount) > math.abs(b.Amount) end
			return a.Name < b.Name
		end)
		local lines = {}
		for index = 1, math.min(2, #stats) do
			table.insert(lines, statText(stats[index].Name, stats[index].Amount))
		end
		if #stats > 2 then lines[2] = "+" .. tostring(#stats - 1) .. " more" end
		card.Stats.Text = if #lines > 0 then table.concat(lines, "\n") else "—"
		local gemKey = if gem then gem.Id .. ":" .. tostring(gem.Cut) else "empty"
		if card.GemKey ~= gemKey then
			card.GemKey = gemKey
			-- Keep the empty marker separate from the reusable gem viewport.
			clear(card.GemArt)
			if gem then
				gemArt(card.GemArt, gem)
			else
				local empty = at(label(card.GemArt, "+", 22, C.Faint, BOLD), 0, 0, 42, 36)
				empty.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
		card.GemLabel.Text = if gem then string.upper(GemConfig.elementName(gem.Element)) else "NO GEM"
		card.GemLabel.TextColor3 = if gem then gemColor(gem) else C.Faint
		card.Element = gem and gem.Element
		card.GemLabel.BackgroundColor3 = if gem then gemColor(gem) else C.PanelEdge
		card.GearEdge.Color = color:Lerp(C.PanelEdge, 0.55)
		card.Stats.TextColor3 = if stats[1] then STAT[stats[1].Name] or C.Text else C.Dim
		card.GemWell.BackgroundColor3 = if gem then C.Track:Lerp(gemColor(gem), 0.12) else C.Track
		card.GemEdge.Color = if gem then gemColor(gem) else C.PanelEdge
		card.Rail.BackgroundColor3 = if picked then C.Gold else color:Lerp(C.PanelEdge, 0.2)
		card.Badge.BackgroundColor3 = C.Track:Lerp(color, 0.12)
		card.Name.TextColor3 = if gear and rarity > 1 then color:Lerp(C.Text, 0.3) else C.Text
		card.Rarity.Text = if gear then rarityName(rarity) else ""
		card.Rarity.TextColor3 = color
		if slot == "Shield" and gear and not Classes.heldShield(loadout) then
			card.Rarity.Text = "STOWED · TWO-HANDED"
			card.Rarity.TextColor3 = C.Dim
		end
		card.Stroke.Color = if picked then C.Gold elseif card.Hovered then color:Lerp(Color3.new(1, 1, 1), 0.25) else C.PanelEdge:Lerp(color, 0.65)
		card.Stroke.Thickness = if picked then 2 else 1
		local targetTint = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 42, 56):Lerp(color, if card.Hovered then 0.18 else 0.06)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 25, 35)),
			ColorSequenceKeypoint.new(1, C.Card),
		})
		card.Glow.Color = targetTint
		local shown = (loadout[slot] or "") .. "|" .. (if gem then gem.Id else "")
		if card.Shown ~= nil and card.Shown ~= shown then
			-- Something changed in this slot: a gold flash says it took.
			local flash = new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = P.Gold,
				BackgroundTransparency = 0.55,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 20,
			}, card.Cell)
			round(flash, 8)
			TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			task.delay(0.75, function()
				flash:Destroy()
			end)
		end
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
		ui.ElementFX = gem and gem.Element
		local picked = contextKey == key or (selection and selection.Kind == "Key" and selection.Key == key)
		ui.Stroke.Color = if picked then C.Gold elseif ui.Hovered then tint else C.PanelEdge:Lerp(tint, 0.3)
		ui.Stroke.Thickness = if picked then 2 else 1
		ui.Rail.BackgroundColor3 = tint
		ui.IconEdge.Color = tint:Lerp(C.PanelEdge, 0.4)
		ui.Glow.Color = ColorSequence.new(Color3.fromRGB(22, 34, 48):Lerp(tint, if ui.Hovered then 0.18 else 0.08), C.Panel)
		ui.Element.Text = if gem then string.upper(GemConfig.elementName(gem.Element)) .. " · " .. rarityName(gemRarity(gem)) else "NO GEM EQUIPPED"
		ui.Element.TextColor3 = if gem then tint:Lerp(C.Text, 0.4) else C.Dim
		ui.GemBadge.BackgroundColor3 = C.Track:Lerp(tint, 0.12)
		ui.ChargeText.Text = if surge then whole(surge.Cost or 0) .. " CHARGE" else "— CHARGE"
		ui.CooldownText.Text = if surge then whole(surge.Cooldown or 0) .. "s COOLDOWN" else "— COOLDOWN"
		ui.Name.Text = if surge then surge.Name else "Add a surge gem"
		-- An empty key is one clean prompt, not a row of dashes.
		ui.GemBadge.Visible = gem ~= nil
		ui.Charge.Visible = surge ~= nil
		ui.Cooldown.Visible = surge ~= nil
		ui.Icon.Text = if surge then "◆" else "+"
		SurgeIcons.apply(ui.Icon, surge, tint)
		ui.Description.Text = if surge then surge.Description or "Select for ability details." else "Choose a gem to equip its ability on " .. key .. "."
		ui.Info.Text = if surge then string.format("%s Charge · %ss cooldown", whole(surge.Cost or 0), whole(surge.Cooldown or 0)) else "Select a gem to equip"
		ui.Name.TextColor3 = if gem then C.Text else C.Dim
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
	contextTitle.Text = if contextKey then "SURGE / " .. contextKey elseif contextSlot then "LOADOUT / " .. SLOT_LABEL[contextSlot] else "SHARED STASH"
	local worn = loadoutNow()
	local key = string.format("%s|%d|%d|%s|%s|%s|%s", tab, spare, gems, contextSlot or "", contextKey or "",
		tostring(contextSlot and worn[contextSlot]), tostring(contextSlot and worn[contextSlot .. "Gem"]))
	if key == tabsKey then
		return
	end
	tabsKey = key
	clear(tabHolder)
	-- Two tabs only. With a slot picked, a dot marks the one it still needs.
	local entries = if contextKey then { { "Gems", "SURGE GEMS" } }
		elseif contextSlot then {
			{ "Gems", "GEMS" },
			{ "Armor", "ARMOR" },
		}
		else { { "Gems", "GEMS " .. gems }, { "Armor", "ARMOR " .. spare } }
	-- Flat text tabs; the active one is bright with a gold underline.
	local width = math.floor((RIGHT_W - 32) / #entries)
	for index, entry in entries do
		local on = entry[1] == tab
		local b = new("TextButton", {
			Text = entry[2],
			TextSize = 13,
			Font = HEADING,
			TextColor3 = if on then C.Text else C.Dim,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((index - 1) * width, 0),
			Size = UDim2.fromOffset(width, 32),
		}, tabHolder)
		b:SetAttribute("UiSound", "Tab")
		b.Activated:Connect(function()
			tab = entry[1]
			selection = nil
			draw()
		end)
		new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if on then P.Gold else C.PanelEdge,
			BackgroundTransparency = if on then 0 else 0.4,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, if on then 2 else 1),
		}, b)
	end
end

-- A bag page is rebuilt only when what it shows changes, and keeps its
-- scroll position when it is.

local slotPanel: Frame? = nil
local slotPanelKey = ""
local buildSlotPanel, fillSlotPanel
-- Picking a replacement for the open slot: compare it in the slot window.
local function comparing(): boolean
	local pick = selection
	return contextSlot ~= nil
		and pick ~= nil
		and ((pick.Kind == "Gem" and pick.Gem.Cut ~= nil) or (pick.Kind == "Spare" and pick.Slot == contextSlot))
end

-- The slot window: the picked piece and its gem as two big sockets side by
-- side (tap one to browse replacements, or drop one from the drawer onto
-- it), the piece's stats, and its perk with what the gem adds.
do -- (scoped: the module is near Luau's 200-local limit)
local panelUi = nil
buildSlotPanel = function()
	slotPanel = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 10, Visible = false }, left)
	round(slotPanel :: Frame, 12)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 29, 42), Color3.fromRGB(13, 19, 29)) }, slotPanel)
	local edge = stroke(slotPanel :: Frame, C.PanelEdge, 1, 0.2)
	local ui = { Edge = edge }
	local function z(object)
		object.ZIndex = 11
		for _, d in object:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 11
			end
		end
		return object
	end
	ui.Title = z(label(slotPanel, "", 10, C.Dim, BOLD))
	ui.Title.Position, ui.Title.Size = UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 14)
	ui.Title.TextXAlignment = Enum.TextXAlignment.Center
	-- One socket: a big square well, a name, a sub line and a detail line.
	local function socket(xScale: number, onTap: () -> ())
		local column = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(xScale, 0, 0, 30), Size = UDim2.new(0.5, -16, 0, 176), ZIndex = 11 }, slotPanel)
		local well = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(100, 100),
			ZIndex = 11,
		}, column)
		round(well, 14)
		local tint = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(P.Frame, P.Frame) }, well)
		local wellEdge = stroke(well, C.PanelEdge, 1.5, 0)
		well:SetAttribute("UiSound", "Click")
		well.Activated:Connect(function()
			if os.clock() >= suppressClickUntil then
				onTap()
			end
		end)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), ZIndex = 12 }, well)
		local empty = label(well, "+", 34, C.Faint, HEADING)
		empty.Size, empty.ZIndex = UDim2.fromScale(1, 1), 12
		empty.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(column, "", 13, C.Text, BOLD)
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(0, 106), UDim2.new(1, 0, 0, 18), 11
		name.TextXAlignment = Enum.TextXAlignment.Center
		local sub = label(column, "", 9, C.Dim, BOLD)
		sub.Position, sub.Size, sub.ZIndex = UDim2.fromOffset(0, 124), UDim2.new(1, 0, 0, 12), 11
		sub.TextXAlignment = Enum.TextXAlignment.Center
		local detail = label(column, "", 11, C.Text, BOLD)
		detail.Position, detail.Size, detail.ZIndex = UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 30), 11
		detail.TextXAlignment = Enum.TextXAlignment.Center
		detail.TextWrapped = true
		return { Well = well, Tint = tint, Edge = wellEdge, Art = art, Empty = empty, Name = name, Sub = sub, Detail = detail }
	end
	ui.Armor = socket(0.27, function()
		selection = nil
		tab, armorFilter = "Armor", contextSlot or "All"
		draw()
	end)
	ui.Gem = socket(0.73, function()
		selection = nil
		tab, gemFilter = "Gems", "All"
		draw()
	end)
	-- The link between them: the gem powers the piece.
	ui.Link = z(label(slotPanel, "◆", 18, C.Faint, HEADING))
	ui.Link.AnchorPoint, ui.Link.Position, ui.Link.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 80), UDim2.fromOffset(30, 30)
	ui.Link.TextXAlignment = Enum.TextXAlignment.Center
	-- The perk band.
	local band = new("Frame", { BackgroundColor3 = C.Card, Position = UDim2.new(0, 14, 0, 208), Size = UDim2.new(1, -28, 0, 86), ZIndex = 11 }, slotPanel)
	round(band, 8)
	ui.PerkName = label(band, "", 10, P.Gold, BOLD)
	ui.PerkName.Position, ui.PerkName.Size, ui.PerkName.ZIndex = UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14), 12
	ui.PerkText = label(band, "", 11, C.Text, BODY)
	ui.PerkText.Position, ui.PerkText.Size, ui.PerkText.ZIndex = UDim2.fromOffset(12, 21), UDim2.new(1, -24, 0, 28), 12
	ui.PerkText.TextWrapped = true
	ui.PerkText.TextYAlignment = Enum.TextYAlignment.Top
	ui.PerkValue = label(band, "", 13, C.Good, HEADING)
	ui.PerkValue.Position, ui.PerkValue.Size, ui.PerkValue.ZIndex = UDim2.fromOffset(12, 50), UDim2.new(1, -24, 0, 30), 12
	ui.PerkValue.RichText = true
	ui.PerkValue.TextWrapped = true
	ui.PerkValue.TextTruncate = Enum.TextTruncate.None
	ui.PerkValue.TextYAlignment = Enum.TextYAlignment.Top
	ui.PerkNote = label(band, "", 9, C.Dim, BOLD)
	ui.PerkNote.AnchorPoint = Vector2.new(1, 0)
	ui.PerkNote.Position, ui.PerkNote.Size, ui.PerkNote.ZIndex = UDim2.new(1, -12, 0, 7), UDim2.new(0.5, 0, 0, 12), 12
	ui.PerkNote.TextXAlignment = Enum.TextXAlignment.Right
	-- The foot: a hint, and REMOVE GEM when there's one to remove.
	ui.Hint = z(label(slotPanel, "TAP A SOCKET, OR DRAG FROM THE RIGHT ONTO ONE", 9, C.Faint, BOLD))
	ui.Hint.Position, ui.Hint.Size = UDim2.new(0, 18, 1, -26), UDim2.new(1, -150, 0, 14)
	ui.Remove = new("TextButton", {
		Text = "REMOVE GEM",
		TextSize = 10,
		Font = HEADING,
		TextColor3 = C.Text,
		BackgroundColor3 = C.Card,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -10),
		Size = UDim2.fromOffset(110, 24),
		ZIndex = 11,
	}, slotPanel)
	round(ui.Remove, 6)
	stroke(ui.Remove, C.PanelEdge, 1)
	ui.Remove:SetAttribute("UiSound", "Back")
	-- Comparing a replacement: confirm it, or keep what's on.
	ui.Confirm = new("TextButton", {
		Text = "EQUIP",
		TextSize = 12,
		Font = HEADING,
		TextColor3 = P.Frame,
		BackgroundColor3 = P.Gold,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -10),
		Size = UDim2.fromOffset(150, 26),
		ZIndex = 11,
		Visible = false,
	}, slotPanel)
	round(ui.Confirm, 6)
	ui.Confirm:SetAttribute("UiSound", "Confirm")
	ui.Cancel = new("TextButton", {
		Text = "KEEP CURRENT",
		TextSize = 10,
		Font = HEADING,
		TextColor3 = C.Dim,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -172, 1, -10),
		Size = UDim2.fromOffset(110, 26),
		ZIndex = 11,
		Visible = false,
	}, slotPanel)
	ui.Cancel:SetAttribute("UiSound", "Back")
	ui.Cancel.Activated:Connect(function()
		selection = nil
		draw()
	end)
	ui.Confirm.Activated:Connect(function()
		local pick = selection
		if not pick or not contextSlot then
			return
		end
		if pick.Kind == "Gem" then
			request("SocketGem", pick.Gem.Id, contextSlot)
		elseif pick.Kind == "Spare" then
			request("EquipGear", Slots.Definitions[pick.Slot].Kind, pick.Id)
		end
		selection = nil
		draw()
	end)
	ui.Remove.Activated:Connect(function()
		if contextSlot then
			request("UnsocketGem", contextSlot)
		end
	end)
	-- Both sockets take drops from the drawer.
	table.insert(dropTargets, {
		Frame = ui.Armor.Well,
		Stroke = ui.Armor.Edge,
		Accepts = function(item)
			return slotPanel ~= nil and slotPanel.Visible and item.Kind == "Spare" and item.Slot == contextSlot
		end,
		Drop = function(item)
			request("EquipGear", Slots.Definitions[item.Slot].Kind, item.Id)
		end,
	})
	table.insert(dropTargets, {
		Frame = ui.Gem.Well,
		Stroke = ui.Gem.Edge,
		Accepts = function(item)
			return slotPanel ~= nil and slotPanel.Visible and contextSlot ~= nil and item.Kind == "Gem" and item.Gem.Cut ~= nil
		end,
		Drop = function(item)
			request("SocketGem", item.Gem.Id, contextSlot)
		end,
	})
	panelUi = ui
end

fillSlotPanel = function(slot: string, pick)
	local loadout = loadoutNow()
	local wornId = loadout[slot]
	local wornGem = loadout[slot .. "Gem"]
	-- A replacement picked in the drawer is shown in place, against what's on.
	local newPiece = pick and pick.Kind == "Spare" and pick.Slot == slot and pick.Id or nil
	local newGem = pick and pick.Kind == "Gem" and pick.Gem or nil
	local id = newPiece or wornId
	local gem = if newGem
		then newGem
		elseif newPiece then (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][newPiece])
		else wornGem
	local key = string.format("%s|%s|%s|%s|%d", slot, tostring(id), tostring(gem and gem.Id), pickKey(), previewVersion)
	if key == slotPanelKey then
		return
	end
	slotPanelKey = key
	local ui = panelUi
	local comparing = newPiece ~= nil or newGem ~= nil
	local gear = gearOf(loadout, slot, id)
	local rarity = if gear then rarityOf(loadout, slot, id) else 1
	local color = rarityColor(rarity)
	ui.Title.Text = if newPiece then SLOT_LABEL[slot] .. "  ·  TRY ON"
		elseif newGem then SLOT_LABEL[slot] .. "  ·  TRY THIS GEM"
		else SLOT_LABEL[slot] .. "  ·  EQUIPPED"
	ui.Title.TextColor3 = if comparing then P.Gold else C.Dim
	-- The piece.
	clear(ui.Armor.Art)
	ui.Armor.Empty.Visible = gear == nil
	ui.Armor.Tint.Color = ColorSequence.new(P.Frame, P.Frame:Lerp(color, 0.3))
	ui.Armor.Edge.Color = if newPiece then P.Gold elseif gear then color else C.PanelEdge
	if gear then
		gearArt(ui.Armor.Art, slot, id, newPiece == nil, color)
	end
	ui.Armor.Name.Text = if gear then gear.Name else "No " .. string.lower(SLOT_LABEL[slot])
	if newPiece then
		local gain = ratingGain(loadout, slot, newPiece)
		local worn = gearOf(loadout, slot)
		ui.Armor.Sub.Text = (if gain > 0 then "▲ +" .. gain elseif gain < 0 then "▼ " .. gain else "=") .. " RATING  ·  NOW " .. string.upper(worn and worn.Name or "EMPTY")
		ui.Armor.Sub.TextColor3 = if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim
	else
		ui.Armor.Sub.Text = if gear then string.upper(rarityName(rarity)) .. "  ·  TAP TO SWAP" else "TAP TO PICK ONE"
		ui.Armor.Sub.TextColor3 = if gear then color else C.Dim
	end
	local roll = GearRolls.get(loadout, slot, id)
	local stats = {}
	for stat, amount in roll and roll.Stats or {} do
		table.insert(stats, statText(stat, amount))
	end
	table.sort(stats)
	ui.Armor.Detail.Text = table.concat(stats, "   ")
	ui.Armor.Detail.TextColor3 = C.Good
	-- The gem.
	clear(ui.Gem.Art)
	ui.Gem.Empty.Visible = gem == nil
	local gColor = if gem then gemColor(gem) else C.PanelEdge
	ui.Gem.Tint.Color = ColorSequence.new(P.Frame, P.Frame:Lerp(gColor, if gem then 0.45 else 0))
	ui.Gem.Edge.Color = if newGem then P.Gold else gColor
	if gem then
		gemArt(ui.Gem.Art, gem)
	end
	ui.Gem.Name.Text = if gem then gemName(gem) else "Empty socket"
	if newGem then
		ui.Gem.Sub.Text = if wornGem then "REPLACES " .. string.upper(gemName(wornGem)) else "INTO THE EMPTY SOCKET"
		ui.Gem.Sub.TextColor3 = P.Gold
	else
		ui.Gem.Sub.Text = if gem
			then string.upper(GemConfig.elementName(gem.Element)) .. "  ·  " .. string.upper(rarityName(gemRarity(gem))) .. "  ·  TAP TO CHANGE"
			else "TAP TO ADD A GEM"
		ui.Gem.Sub.TextColor3 = if gem then gColor else C.Dim
	end
	ui.Gem.Detail.Text = if gem then string.format("SIZE %s  ·  CLARITY %s  ·  CUT %s", tostring(gem.Size or "-"), tostring(gem.Clarity or "-"), tostring(gem.Cut or "-")) else "Enchanting is pure gain"
	ui.Gem.Detail.TextColor3 = if gem then C.Dim else C.Faint
	if newPiece then
		-- Gems live in their piece: say where the current one goes.
		ui.Gem.Sub.Text = if gem then "THIS PIECE'S GEM" else "THIS PIECE HAS NO GEM"
		ui.Gem.Sub.TextColor3 = C.Dim
		local worn = gearOf(loadout, slot)
		if wornGem and worn then
			ui.Gem.Detail.Text = gemName(wornGem) .. " stays on " .. worn.Name
			ui.Gem.Detail.TextColor3 = C.Dim
		end
	end
	ui.Link.TextColor3 = if gem then gColor else C.Faint
	-- The foot: confirm a replacement, or remove the gem that's on.
	ui.Remove.Visible = not comparing and wornGem ~= nil
	ui.Confirm.Visible = comparing
	ui.Cancel.Visible = comparing
	ui.Confirm.Text = if newGem then "ENCHANT " .. SLOT_LABEL[slot] else "EQUIP " .. string.upper(gear and gear.Name or "")
	ui.Hint.Visible = not comparing
	-- The perk, with what the gem adds to it (when comparing: now -> then).
	local signature = ArmorSignatures.resolve(roll, gem)
	if signature then
		local d = signature.Definition
		local function fmt(v: number): string
			return if d.Percent then string.format("%.1f%%", v * 100) else string.format("%.1f %s", v, d.Unit or "")
		end
		ui.PerkName.Text = "PERK  ·  " .. string.upper(d.Name)
		ui.PerkValue.TextSize = 14
		ui.PerkText.Text = d.Trigger
		local current = ArmorSignatures.resolve(GearRolls.get(loadout, slot), wornGem)
		if comparing and current and current.Id == signature.Id then
			local better = signature.Value >= current.Value - 1e-6
			ui.PerkValue.Text = string.format('NOW %s  →  <font color="#%s">%s</font>', fmt(current.Value), (if better then C.Good else C.Bad):ToHex(), fmt(signature.Value))
			ui.PerkNote.Text = if better then "STRONGER" else "WEAKER"
		elseif gem and signature.Value > signature.Base + 1e-6 then
			ui.PerkValue.Text = string.format('%s  →  <font color="#%s">%s</font>', fmt(signature.Base), gColor:ToHex(), fmt(signature.Value))
			ui.PerkNote.Text = "ENCHANTED BY " .. string.upper(gemName(gem))
		else
			ui.PerkValue.Text = fmt(signature.Base)
			ui.PerkNote.Text = "ADD A GEM TO STRENGTHEN IT"
		end
	else
		local passive = gear and gear.Passive
		ui.PerkName.Text = if passive then "PERK  ·  " .. string.upper(passive.Name or "PASSIVE") else "PERK"
		ui.PerkValue.TextSize = 11
		ui.PerkText.Text = if passive and passive.Text then passive.Text else "No perk on this piece."
		if gem then
			local parts = {}
			for _, l in GemConfig.lines(gem, slot) do
				table.insert(parts, l.Text)
			end
			ui.PerkValue.Text = string.format('<font color="#%s">%s</font>', gColor:ToHex(), table.concat(parts, "  ·  "))
			ui.PerkNote.Text = if newGem then "WITH " .. string.upper(gemName(gem)) else "ENCHANTED BY " .. string.upper(gemName(gem))
		else
			ui.PerkValue.Text = ""
			ui.PerkNote.Text = "ADD A GEM TO ENCHANT IT"
		end
	end
end

end
local pageKey, pageTab = "", ""
local statCard: Frame? = nil
local statChips: Frame? = nil
local statChipValues: { [string]: TextLabel } = {}
local radarShown = false
local lastOpen = nil -- the drawer's last state, for its slide
local TILE = 76
local TILE_SIDE = { Helmet = { 1, 1 }, Armor = { 1, 2 }, Gloves = { 1, 3 }, Weapon = { 2, 1 }, Shield = { 2, 2 }, Boots = { 2, 3 } }
-- { key, caption, width, colour }
local STAT_CHIPS = {
	{ "Total", "RATING", 108, P.Gold },
	{ "Health", "HP", 84, STAT.Health },
	{ "Power", "PWR", 84, STAT.Power },
	{ "Defense", "DEF", 84, STAT.Defense },
	{ "Speed", "SPD", 84, STAT.Speed },
	{ "Set", "SET", 78, P.Gold },
}
local function drawRight()
 local profile = profileNow()
 if require(ReplicatedStorage.Shared.Tutorial).Enabled and profile and profile.Tutorial and not profile.Tutorial.Done and profile.Tutorial.Step <= 8 then
  tab, gemFilter = "Gems", "All"
  stashOpen = true
 end
	if tab == "Overview" then
		tab = "Gems"
	end
	inventoryModal.Visible = true
	-- The Armory: the miner owns the screen. Gear is six small tiles beside
	-- the body; tapping one slides the drawer (the stash) in from the right,
	-- and the stage makes room for it. Closed, the screen stays calm.
	local open = contextSlot ~= nil or contextKey ~= nil or selection ~= nil or stashOpen
	local drawerH = PANEL_H - BODY_Y
	right.Visible = true
	right.Size = UDim2.fromOffset(RIGHT_W, drawerH)
	local drawerAt = UDim2.fromOffset(if open then RIGHT_X else W + 24, ROSTER_H + BODY_Y)
	at(page, 12, 94, RIGHT_W - 24, drawerH - 94 - 40)
	at(footerLine, 12, drawerH - 38, RIGHT_W - 24, 1)
	at(footer, 12, drawerH - 32, RIGHT_W - 24, 20)
	footer.TextWrapped = false
	footer.TextTruncate = Enum.TextTruncate.AtEnd
	contextClose.Visible = false
	pickerClose.Visible = true
	local stageLeft = 18
	local stageWidth = (if open then RIGHT_X - 12 else W - 18) - stageLeft
	left.Size = UDim2.fromOffset(W, PANEL_H)
	local stageH, surgeH = 422, 96
	local stageSize = UDim2.fromOffset(stageWidth, stageH)
	if open ~= lastOpen then
		local first = lastOpen == nil
		lastOpen = open
		local info = TweenInfo.new(if first then 0 else 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(right, info, { Position = drawerAt }):Play()
		TweenService:Create(portrait, info, { Size = stageSize }):Play()
	end
	portrait.Position = UDim2.fromOffset(stageLeft, BODY_Y)
	-- The set count is a chip now (SET); the header names the set.
	stageTag.Visible = false
	at(surgeCell, stageLeft, BODY_Y + stageH + 6, stageWidth, surgeH)
	at(setSummary, stageLeft, BODY_Y + stageH + surgeH + 8, stageWidth, 20)
	scouting.Visible = false
	stashButton.Visible = not open
	stashButton.Position = UDim2.fromOffset(stageLeft + stageWidth - 12, BODY_Y + 12)

	-- The gear tiles: three a side, close to the body.
	local centre = stageLeft + stageWidth / 2
	local reach = math.min(270, stageWidth * 0.25)
	local loadout = loadoutNow()
	local spares = spareItems()
	for slot, card in wornCards do
		local side = TILE_SIDE[slot]
		local x = if side[1] == 1 then centre - reach - TILE else centre + reach
		local y = BODY_Y + 70 + (side[2] - 1) * (TILE + 34)
		local target = UDim2.fromOffset(x, y)
		if card.TileAt ~= target then
			card.TileAt = target
			TweenService:Create(card.Cell, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = target }):Play()
		end
		if not card.Compact then
			card.Compact = true
			card.Cell.Size = UDim2.fromOffset(TILE, TILE)
			card.Cell.ZIndex = 4
			for _, child in card.Cell:GetChildren() do
				if child:IsA("GuiObject") then
					local keep = child == card.GearWell
						or child == card.Socket
						or (child:IsA("TextButton") and child.Text == "")
						or string.sub(child.Name, 1, 9) == "Elemental"
					if not keep then
						child.Visible = false
					end
				end
			end
			at(card.GearWell, 5, 5, TILE - 10, TILE - 10)
			at(card.Art, 4, 4, TILE - 18, TILE - 18)
			card.Socket.Visible = true
			-- The gem as a diamond in the corner (empty: a dashed outline).
			card.Socket.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Socket.Position = UDim2.new(1, -14, 1, -14)
			card.Socket.Size = UDim2.fromOffset(13, 13)
			card.Socket.Rotation = 45
			card.TileLabel = label(left, SLOT_LABEL[slot], 9, C.Dim, BOLD)
			card.TileLabel.TextXAlignment = Enum.TextXAlignment.Center
			card.Upgrade = label(left, "▲", 12, C.Good, HEADING)
			card.Upgrade.TextXAlignment = Enum.TextXAlignment.Center
			card.Upgrade.ZIndex = 6
		end
		card.SocketIcon.Visible = false
		local gem = loadout[slot .. "Gem"]
		card.Socket.BackgroundColor3 = if gem then gemColor(gem) else P.Frame
		card.SocketEdge.Color = if gem then gemColor(gem):Lerp(Color3.new(1, 1, 1), 0.4) else C.Faint
		card.TileLabel.Position = UDim2.fromOffset(x - 10, y + TILE + 3)
		card.TileLabel.Size = UDim2.fromOffset(TILE + 20, 12)
		card.TileLabel.TextColor3 = if contextSlot == slot then P.Gold else C.Dim
		-- A better piece waiting in the stash: a green arrow on the tile.
		local better = false
		for _, item in spares do
			if item.Slot == slot and ratingGain(loadout, slot, item.Id) > 0 then
				better = true
				break
			end
		end
		card.Upgrade.Visible = better
		card.Upgrade.Position = UDim2.fromOffset(x + TILE - 14, y - 4)
		card.Upgrade.Size = UDim2.fromOffset(18, 16)
	end

	-- The picked slot's review window, centred between the gear tiles: what
	-- it is, its gem and perk, and the buttons to change them (the drawer
	-- lists the replacements).
	if not slotPanel then
		buildSlotPanel()
	end
	local reviewing = contextSlot ~= nil and (selection == nil or comparing())
	slotPanel.Visible = reviewing
	if reviewing then
		at(slotPanel, centre - reach + 8, BODY_Y + 52, 2 * reach - 16, stageH - 88)
		fillSlotPanel(contextSlot :: string, if comparing() then selection else nil)
	else
		slotPanelKey = ""
	end

	-- Q/E/R: icon, name, gem and costs; the description is in its details.
	local surgeWidth = (stageWidth - 40) / 3
	for index, key in { "Q", "E", "R" } do
		local ui = surgeKeys[key]
		at(ui.Box, 12 + (index - 1) * (surgeWidth + 8), 22, surgeWidth, 66)
		at(ui.KeyBadge, surgeWidth - 25, 5, 20, 20)
		at(ui.Letter, 0, 0, 20, 20)
		at(ui.IconMount, 7, 9, 48, 48)
		at(ui.Name, 62, 5, surgeWidth - 92, 18)
		at(ui.GemBadge, 62, 25, math.min(220, surgeWidth - 70), 18)
		at(ui.Art, 2, 0, 24, 18)
		at(ui.Element, 29, 0, math.min(220, surgeWidth - 70) - 33, 18)
		ui.Description.Visible = false
		local chipWidth = math.min(110, (surgeWidth - 76) / 2)
		at(ui.Charge, 62, 47, chipWidth, 14)
		at(ui.Cooldown, 66 + chipWidth, 47, chipWidth, 14)
		ui.Name.TextXAlignment = Enum.TextXAlignment.Left
		at(ui.Info, 62, 47, surgeWidth - 70, 14)
		ui.Info.TextWrapped = false
	end

	-- Stats: chips across the top of the stage; RATING opens the radar.
	if not statCard then
		statCard = box(left, C.Card, 8)
		stroke(statCard, C.PanelEdge, 1)
		statCard.BackgroundTransparency = 0.1
		statCard.ZIndex = 8
		for _, tile in statTiles do
			tile.Tile.Visible = false
		end
		local caption = label(statCard, "BUILD", 9, C.Dim, BOLD)
		at(caption, 10, 6, 80, 14)
		caption.ZIndex = 9
		radarRating = label(statCard, "0", 15, P.Gold, HEADING)
		at(radarRating :: TextLabel, 60, 3, 130, 20)
		radarRating.TextXAlignment = Enum.TextXAlignment.Right
		radarRating.ZIndex = 9
		radar = StatRadar.create(statCard, {
			{ Name = "HEALTH", Color = STAT.Health },
			{ Name = "POWER", Color = STAT.Power },
			{ Name = "SPEED", Color = STAT.Speed },
			{ Name = "SET", Color = P.Gold },
			{ Name = "ATTUNED", Color = STAT.Attuned },
			{ Name = "DEFENSE", Color = STAT.Defense },
		}, 46, P.Teal)
		radar.Frame.Position = UDim2.fromOffset(100 - 46, 30 + 28)
		-- One quiet strip of numbers, divided by hairlines.
		statChips = new("Frame", { BackgroundColor3 = C.Card, BackgroundTransparency = 0.1, ZIndex = 8, AutomaticSize = Enum.AutomaticSize.X }, left)
		round(statChips :: Frame, 8)
		stroke(statChips :: Frame, C.PanelEdge, 1, 0.45)
		local list = UiKit.list(statChips, 0, true)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		for order, spec in STAT_CHIPS do
			local chip = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(spec[3], 30),
				LayoutOrder = order,
				ZIndex = 8,
			}, statChips)
			if order > 1 then
				new("Frame", { BorderSizePixel = 0, BackgroundColor3 = C.PanelEdge, BackgroundTransparency = 0.3, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(1, 14), ZIndex = 9 }, chip)
			end
			local name = label(chip, spec[2], 9, spec[4]:Lerp(C.Dim, 0.25), BOLD)
			at(name, 12, 0, 44, 30)
			name.ZIndex = 9
			local value = label(chip, "0", 13, C.Text, HEADING)
			at(value, 12, 0, spec[3] - 24, 30)
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.ZIndex = 9
			statChipValues[spec[1]] = value
			if spec[1] == "Total" then
				chip:SetAttribute("UiSound", "Click")
				chip.Activated:Connect(function()
					radarShown = not radarShown
					draw()
				end)
			end
		end
	end
	statChips.Position = UDim2.fromOffset(stageLeft + 12, BODY_Y + 12)
	statChips.Size = UDim2.fromOffset(0, 30)
	local cardH = 204
	statCard.Visible = radarShown
	at(statCard, stageLeft + 12, BODY_Y + 44, 200, cardH)
	if radarStats then
		local s = radarStats
		for key, value in statChipValues do
			value.Text = if key == "Set" then s.Set .. "/6" else whole(s[key] or 0)
		end
		local scale = math.max(150, s.Health, s.Power, s.Defense, s.Speed) * 1.05
		StatRadar.set(radar, {
			s.Health / scale,
			s.Power / scale,
			s.Speed / scale,
			s.Set / 6,
			s.Attuned / #Slots.Order,
			s.Defense / scale,
		}, {
			whole(s.Health),
			whole(s.Power),
			whole(s.Speed),
			s.Set .. "/6",
			s.Attuned .. "/" .. #Slots.Order,
			whole(s.Defense),
		})
		;(radarRating :: TextLabel).Text = whole(s.Total)
		if radar.Current[1] == 0 then
			StatRadar.step(radar, 10) -- the first time, straight to the shape
		end
	end
	drawTabs()
	local key = if tab == "Gems" then gemsKey() elseif tab == "Armor" then armorKey() else nil
	if key ~= nil and key == pageKey and pageTab == tab then
		return
	end
	local old = page:FindFirstChildWhichIsA("ScrollingFrame", true)
	local keep = if old and pageTab == tab then old.CanvasPosition else nil
	pageKey, pageTab = key or "", tab
	clear(page)
	if selection and not comparing() and not drawOverview(page, selection) then
		selection = nil
	end
	if selection and not comparing() then
		footer.Text = "✕ TO GO BACK"
	elseif tab == "Gems" then
		drawGems()
	elseif tab == "Armor" then
		drawArmor()
	else
		drawOverview(page, if contextSlot then { Kind = "Worn", Slot = contextSlot } elseif contextKey then { Kind = "Key", Key = contextKey } else nil)
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
local rosterSignature, rosterRequest = "", false
local function visible(): boolean
	return hostGui ~= nil and hostGui.Enabled
end
local fxElapsed = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	if not visible() then return end
	fxElapsed += dt
	if fxElapsed < 1 / 30 then return end
	fxElapsed = 0
	local now = os.clock()
	for _, card in wornCards do ElementCardFX.update(card.FX, card.Element, now) end
	for _, ui in surgeKeys do ElementCardFX.update(ui.FX, ui.ElementFX, now) end
	StageBackdrop.update(stageBackdrop, now)
	if radar then StatRadar.step(radar, 1 / 30) end
	-- An empty socket on a worn piece breathes gold: the next thing to do.
	local worn = loadoutNow()
	local pulse = 0.5 + 0.5 * math.sin(now * 4)
	for slot, card in wornCards do
		if card.Compact and worn[slot] and not worn[slot .. "Gem"] then
			card.SocketEdge.Color = P.Gold
			card.SocketEdge.Transparency = 0.6 - 0.6 * pulse
			card.SocketEdge.Thickness = 1.5
		end
	end
end)
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
		local profile = profileNow()
		local signature = game:GetService("HttpService"):JSONEncode({ profile.Miners, profile.Character })
		if not rosterRequest and signature ~= rosterSignature then
			rosterRequest = true
			rosterSignature = signature
			task.spawn(function()
				local ok, result = pcall(GemClient.request, "MinerPreviews")
				rosterRequest = false
				if not ok or not result or not result.Ok then rosterSignature = "" end
			end)
		end
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
local function watchMiners(store: Instance)
	local queued = false
	local function changed()
		if queued then return end
		queued = true
		task.delay(0.15, function()
			queued = false
			for _, card in minerCards do card.Source = nil end
			draw()
		end)
	end
	store.DescendantAdded:Connect(changed)
	store.ChildRemoved:Connect(changed)
	changed()
end
if playerGui:FindFirstChild("MinerPreviews") then watchMiners(playerGui.MinerPreviews) end
local function watchPreviews(store: Instance)
	store.ChildAdded:Connect(previewsChanged)
end
if playerGui:FindFirstChild("GearPreviews") then
	watchPreviews(playerGui:FindFirstChild("GearPreviews") :: Instance)
end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "MinerPreviews" then watchMiners(child) end
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
