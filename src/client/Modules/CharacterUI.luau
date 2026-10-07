--[[
 Classic RPG armory: equipped item models surround a character silhouette,
 a compact gemstone backpack sits beneath it, and an inspector handles
 comparisons and attunement. Equipment and gem sockets are separate targets.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local SuitTraits = require(ReplicatedStorage.Shared.SuitTraits)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Season = require(ReplicatedStorage.Shared.Season)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GearPresets = require(ReplicatedStorage.Shared.GearPresets)
local GemArt = require(script.Parent.GemArt)
local GearArt = require(script.Parent.GearArt)
local SurgeArrayUI = require(script.Parent.SurgeArrayUI)
local AugmentTreeUI = require(script.Parent.AugmentTreeUI)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local SurgeIcons = require(script.Parent.SurgeIcons)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, actionButton, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 1400, 520
local CELL, GAP, COLUMNS = 54, 6, 6

local CharacterUI = {}

type Selection =
	{ Kind: "Gem", Gem: any }
	| { Kind: "Socket", Slot: string }
	| { Kind: "Gear", Slot: string }
	| { Kind: "Inventory", Slot: string, Id: string }
local selection: Selection? = nil
local atVey = false
local suppressClickUntil = 0
local enchantPending = false

-- Screen -------------------------------------------------------------------------------

local window = IronUi.window("Character", 8, WIDTH, HEIGHT, "🛡️")
local gui, panel, scale, fit = window.Gui, window.Panel, window.Scale, window.Fit
local title, subtitle = window.Title, window.Subtitle
local embedded = false

-- Equipment board -----------------------------------------------------------------

local doll = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 82),
	Size = UDim2.fromOffset(552, 416),
}, panel)

-- The gradient sits on a frame behind the viewport: on the viewport itself
-- it would tint the avatar too.
local avatarBack = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(552, 416),
}, doll)
UiKit.round(avatarBack, 3)
new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, avatarBack)
new(
	"UIGradient",
	{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(35, 36, 43), Color3.fromRGB(12, 14, 22)) },
	avatarBack
)
-- Engraved corners and sparse seams frame the equipment board.
for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
	local cornerFrame = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = corner,
		Position = UDim2.new(corner.X, if corner.X == 0 then 7 else -7, corner.Y, if corner.Y == 0 then 7 else -7),
		Size = UDim2.fromOffset(22, 22),
	}, avatarBack)
	new("Frame", {
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromOffset(22, 2),
		Position = UDim2.fromScale(0, corner.Y),
	}, cornerFrame)
	new("Frame", {
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromOffset(2, 22),
		Position = UDim2.fromScale(corner.X, 0),
	}, cornerFrame)
end
local avatar = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(200, 196, 190),
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(-0.3, -0.8, -1),
	Size = UDim2.fromScale(1, 1),
}, avatarBack)
local avatarWorld = new("WorldModel", {}, avatar)
local avatarCamera = new("Camera", { FieldOfView = 30 }, avatar)
avatar.CurrentCamera = avatarCamera
avatarCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1, -13.5), Vector3.new(0, 0.5, 0))
local avatarModel: Model? = nil
local onAvatarChanged: (() -> ())? = nil -- redraws the portrait card (set below)
local equipmentSlots = {}
local refreshItemArt: (() -> ())? = nil

local function refreshAvatar()
	local character = player.Character
	if not character or not gui.Enabled then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.Transparency = math.max(d.Transparency, 0.78)
			d.Color = Color3.fromRGB(63, 71, 85)
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if avatarModel then
		avatarModel:Destroy()
	end
	avatarModel = copy
	copy:PivotTo(CFrame.new())
	copy.Parent = avatarWorld
	if refreshItemArt then
		refreshItemArt()
	end
	if onAvatarChanged then
		onAvatarChanged()
	end
end

-- An equipment slot (a tall bevelled box) with its gem socket beneath.
type Slot = {
	Box: Frame,
	Art: ViewportFrame,
	Name: TextLabel,
	Style: TextLabel,
	Bonus: TextLabel,
	Socket: TextButton,
	DropTarget: Frame,
	Caption: TextLabel,
	Shown: string?, -- id of the gem drawn in the socket
}
local function slot(x: number, y: number, label: string, socketName: string): Slot
	local holder = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(124, 136) },
		doll
	)
	local head = text(holder, label, 12, P.Dim, BOLD)
	head.TextXAlignment = Enum.TextXAlignment.Center
	local item = box(holder, UDim2.fromOffset(0, 16), UDim2.fromOffset(124, 96), Color3.fromRGB(30, 22, 30), 2)
	local art = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.fromOffset(114, 50),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, item)
	local name = text(item, "", 12, P.Text, BOLD)
	name.Position = UDim2.fromOffset(4, 54)
	name.Size = UDim2.fromOffset(116, 28)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Center
	local style = text(item, "", 11, P.Dim, BOLD)
	style.Position = UDim2.fromOffset(4, 82)
	style.Size = UDim2.fromOffset(116, 12)
	style.AutomaticSize = Enum.AutomaticSize.None
	style.TextXAlignment = Enum.TextXAlignment.Center
	local bonus = text(item, "", 10, P.Dim)
	bonus.Visible = false
	local hit = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(124, 96),
		ZIndex = 5,
	}, holder)
	IronUi.highlight(hit, item)
	hit.Activated:Connect(function()
		if os.clock() < suppressClickUntil then
			return
		end
		selection = { Kind = "Gear", Slot = socketName }
		CharacterUI.refresh()
	end)
	local socket = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = P.Frame,
		Position = UDim2.fromOffset(0, 114),
		Size = UDim2.fromOffset(22, 22),
	}, holder)
	UiKit.round(socket, 5)
	new("UIStroke", { Name = "Ring", Color = P.Edge, Thickness = 1 }, socket)
	IronUi.highlight(socket)
	local caption = text(holder, "", 11, P.Dim)
	caption.Position = UDim2.fromOffset(28, 117)
	caption.Size = UDim2.fromOffset(96, 16)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	socket.Activated:Connect(function()
		if os.clock() < suppressClickUntil then
			return
		end
		selection = { Kind = "Socket", Slot = socketName }
		CharacterUI.refresh()
	end)
	local dropTarget = new("Frame", {
		Name = "GemDropTarget",
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.87,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(124, 120),
		ZIndex = 8,
		Visible = false,
		Active = false,
	}, holder)
	UiKit.round(dropTarget, 3)
	new("UIStroke", { Color = P.Gold, Thickness = 2 }, dropTarget)
	return {
		Box = item,
		Art = art,
		Name = name,
		Style = style,
		Bonus = bonus,
		Socket = socket,
		Caption = caption,
		DropTarget = dropTarget,
	}
end
-- Physical equipment placement follows the silhouette, like a classic RPG paper doll.
local slotPositions = {
	Helmet = Vector2.new(214, 4),
	Armor = Vector2.new(214, 140),
	Boots = Vector2.new(214, 276),
	Weapon = Vector2.new(22, 72),
	Gloves = Vector2.new(22, 248),
	Shield = Vector2.new(406, 72),
}
for _, key in Slots.Order do
	local at = slotPositions[key]
	equipmentSlots[key] = slot(at.X, at.Y, string.upper(Slots.Definitions[key].Label), key)
end
local boardHint = new("TextButton", {
	Text = "SURGE ARRAY\nQ · E · R  [L]",
	TextSize = 12,
	Font = BOLD,
	TextColor3 = P.Teal,
	BackgroundColor3 = P.Inset,
}, doll)
UiKit.round(boardHint, 8)
boardHint.Activated:Connect(SurgeArrayUI.open)
boardHint.Position = UDim2.fromOffset(406, 290)
boardHint.Size = UDim2.fromOffset(124, 46)
boardHint.TextXAlignment = Enum.TextXAlignment.Center
boardHint.AutomaticSize = Enum.AutomaticSize.None
boardHint.TextWrapped = true
-- The Augment Tree (skills and surge boosts), under it.
local treeHint = boardHint:Clone()
treeHint.Text = "AUGMENT TREE\nSKILLS  [K]"
treeHint.TextColor3 = P.Gold
treeHint.Position = UDim2.fromOffset(406, 342)
treeHint.Parent = doll
treeHint.Activated:Connect(AugmentTreeUI.open)
for _, hint in { boardHint, treeHint } do
	new("UIStroke", {
		Color = hint.TextColor3,
		Thickness = 1,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, hint)
	IronUi.highlight(hint)
end

local frameGear, previewFor, equipmentIcon = GearArt.frame, GearArt.preview, GearArt.icon

refreshItemArt = function()
	local character = player.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	if not character or not equipment then
		return
	end
	local origin = character:GetPivot()
	for key, ui in equipmentSlots do
		ui.Art:ClearAllChildren()
		local source = equipment:FindFirstChild(key)
		if source then
			local parts = {}
			for _, part in source:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
			frameGear(ui.Art, key, parts, function(part)
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				local anchor = weld and weld.Part0
				return if anchor then anchor.Name else ""
			end, function(part)
				return origin:ToObjectSpace(part.CFrame)
			end)
		end
	end
end

-- Combat ratings: a slim strip across the header, beside the name.
local statsBox = box(panel, UDim2.fromOffset(508, 11), UDim2.fromOffset(868, 54), P.Inset)
local statsCard = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 1, -12),
}, statsBox)

-- Backpack and inspector ------------------------------------------------------

-- The bag: one panel, three views picked from a row of tabs, each with a
-- row of quick filters under it and a line saying what the view is for.
--   GEAR    spare equipment                       filter by slot
--   GEMS    gems, to socket into gear              filter by element
--   POWERS  the surge each gem carries, for Q E R  filter by element
local BAG_X, BAG_W = 992, 384
local BAG_TOP, BAG_BOTTOM = 166, 498
local BAG_TABS = {
	{
		Id = "Equipment",
		Label = "GEAR",
		Color = P.Gold,
		Caption = "Spare gear. Pick a piece to compare it with what you wear.",
	},
	{
		Id = "Gems",
		Label = "GEMS",
		Color = P.Teal,
		Caption = "Socket a gem into your gear for its stats and element resist.",
	},
	{
		Id = "Powers",
		Label = "POWERS",
		Color = P.Amethyst,
		Caption = "Every gem carries a surge power. Slot up to three on Q · E · R.",
	},
}
local BAG_FILTERS = {
	Equipment = {
		{ "All", "ALL" },
		{ "Helmet", "HEAD" },
		{ "Armor", "BODY" },
		{ "Gloves", "HANDS" },
		{ "Boots", "FEET" },
		{ "Weapon", "WEAPON" },
		{ "Shield", "SHIELD" },
	},
	Gems = {
		{ "All", "ALL" },
		{ "Fire", "THERMAL" },
		{ "Frost", "CRYO" },
		{ "Shock", "ION" },
		{ "Poison", "CORROSIVE" },
	},
}
BAG_FILTERS.Powers = BAG_FILTERS.Gems
local bagFilter = { Equipment = "All", Gems = "All", Powers = "All" }

local function bagBox(fill: Color3): Frame
	return box(panel, UDim2.fromOffset(BAG_X, BAG_TOP), UDim2.fromOffset(BAG_W, BAG_BOTTOM - BAG_TOP), fill)
end
local function bagScroll(parent: Instance, name: string?): ScrollingFrame
	return new("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = P.Edge,
	}, parent)
end
local function bagEmpty(parent: Instance): TextLabel
	local l = text(parent, "", 13, P.Dim)
	l.Position = UDim2.fromOffset(20, 40)
	l.Size = UDim2.new(1, -40, 0, 70)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.ZIndex = 3
	return l
end

local gridBox = bagBox(Color3.fromRGB(10, 9, 8))
local grid = bagScroll(gridBox)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(CELL, CELL),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
local gemsEmpty = bagEmpty(gridBox)

-- Spare equipment uses the existing saved ownership records; worn items stay on the board.
local equipmentBox = bagBox(P.Frame)
local equipmentGrid = bagScroll(equipmentBox, "StoredEquipment")
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(116, 108),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, equipmentGrid)
local equipmentEmpty = bagEmpty(equipmentBox)

-- Powers: the surge on each gem, as a list (what it is matters more than the stone).
local powerBox = bagBox(P.Frame)
local powerList = bagScroll(powerBox, "PowerList")
UiKit.list(powerList, 6)
local powersEmpty = bagEmpty(powerBox)

-- The tab row: a segmented control with a count on each tab.
local tabBar = new("Frame", {
	BackgroundColor3 = P.Frame,
	Position = UDim2.fromOffset(BAG_X, 82),
	Size = UDim2.fromOffset(BAG_W, 34),
}, panel)
UiKit.round(tabBar, 8)
new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.5 }, tabBar)
local tabButtons: { [string]: { Button: TextButton, Name: TextLabel, Count: TextLabel, Stroke: UIStroke } } = {}
local filterRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(BAG_X, 122),
	Size = UDim2.fromOffset(BAG_W, 22),
}, panel)
local filterLayout = UiKit.list(filterRow, 4, true)
filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
local bagCaption = text(panel, "", 11, P.Dim)
bagCaption.AutomaticSize = Enum.AutomaticSize.None
bagCaption.Position, bagCaption.Size = UDim2.fromOffset(BAG_X + 2, 148), UDim2.fromOffset(BAG_W - 4, 14)
bagCaption.TextTruncate = Enum.TextTruncate.AtEnd

local bagTab = "Equipment"
local lastPick = nil
local redrawBag: () -> () = function() end -- set once the views can draw

local function tabSpec(id: string)
	for _, spec in BAG_TABS do
		if spec.Id == id then
			return spec
		end
	end
	return BAG_TABS[1]
end

local function drawFilters()
	clear(filterRow)
	local spec = tabSpec(bagTab)
	for order, entry in BAG_FILTERS[bagTab] do
		local key, label = entry[1], entry[2]
		local on = bagFilter[bagTab] == key
		local tint = GemConfig.ElementColors[key] or spec.Color
		local chip = new("TextButton", {
			Text = label,
			TextSize = 10,
			Font = BOLD,
			AutoButtonColor = false,
			TextColor3 = if on then P.Frame else tint:Lerp(P.Text, 0.35),
			BackgroundColor3 = if on then tint else P.Slot,
			BackgroundTransparency = if on then 0.05 else 0.2,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
		}, filterRow)
		UiKit.round(chip, 11)
		new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip)
		new("UIStroke", {
			Color = tint,
			Thickness = 1,
			Transparency = if on then 1 else 0.6,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, chip)
		chip:SetAttribute("UiSound", "Tab")
		chip.Activated:Connect(function()
			if bagFilter[bagTab] ~= key then
				bagFilter[bagTab] = key
				drawFilters()
				redrawBag()
			end
		end)
	end
end

local function showBag(tab: string)
	bagTab = tab
	gridBox.Visible = tab == "Gems"
	equipmentBox.Visible = tab == "Equipment"
	powerBox.Visible = tab == "Powers"
	for id, ui in tabButtons do
		local spec = tabSpec(id)
		local on = id == tab
		ui.Button.BackgroundColor3 = spec.Color
		ui.Button.BackgroundTransparency = if on then 0.78 else 1
		ui.Stroke.Transparency = if on then 0.1 else 1
		ui.Name.TextColor3 = if on then spec.Color else P.Dim
		ui.Count.TextColor3 = if on then P.Text else P.Dim
	end
	bagCaption.Text = tabSpec(tab).Caption
	drawFilters()
	redrawBag()
end

for i, spec in BAG_TABS do
	local w = (BAG_W - 8 - 8) / 3
	local b = new("TextButton", {
		Name = spec.Label .. "Tab",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4 + (i - 1) * (w + 4), 4),
		Size = UDim2.fromOffset(w, 26),
	}, tabBar)
	UiKit.round(b, 6)
	local stroke = new("UIStroke", { Color = spec.Color, Thickness = 1.5, Transparency = 1 }, b)
	local name = text(b, spec.Label, 13, P.Dim, IronUi.Heading)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.new(0.62, 0, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Right
	local count = text(b, "", 11, P.Dim, BOLD)
	count.AutomaticSize = Enum.AutomaticSize.None
	count.Position, count.Size = UDim2.new(0.62, 6, 0, 0), UDim2.new(0.38, -6, 1, 0)
	count.TextXAlignment = Enum.TextXAlignment.Left
	b:SetAttribute("UiSound", "Tab")
	b.Activated:Connect(function()
		showBag(spec.Id)
	end)
	tabButtons[spec.Id] = { Button = b, Name = name, Count = count, Stroke = stroke }
end
local function setTabCount(id: string, count: number)
	local ui = tabButtons[id]
	if ui then
		ui.Count.Text = tostring(count)
	end
end
showBag("Equipment")

-- Item details get the whole middle column.
local tooltip = box(panel, UDim2.fromOffset(592, 82), UDim2.fromOffset(384, 416), P.Inset)
local tooltipStroke = tooltip:FindFirstChildOfClass("UIStroke") :: UIStroke
UiKit.pad(tooltip, 12)
local tipArt = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(58, 58) }, tooltip)
local tipBody = new("ScrollingFrame", {
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(66, 0),
	Size = UDim2.new(1, -66, 1, -72),
}, tooltip)
UiKit.list(tipBody, 3)
local tipActions = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 64),
}, tooltip)
new("UIGridLayout", {
	CellSize = UDim2.new(1 / 3, -6, 0, 28),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tipActions)

-- Drawing --------------------------------------------------------------------------------

local function socketed(slotName: string)
	local character = GemClient.Profile and GemClient.Profile.Character
	return character and character[slotName .. "Gem"]
end

local function request(action: string, ...)
	local enchanting = action == "SocketGem" or action == "UnsocketGem"
	if enchanting and enchantPending then
		return
	end
	if enchanting then
		enchantPending = true
	end
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if enchanting then
			enchantPending = false
		end
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
	end)
end

local regenerate = actionButton(panel, "REGENERATE LOADOUT", false, function()
	request("AdminRegenerateEquipment")
end)
regenerate.Position = UDim2.fromOffset(520, 14)
regenerate.Size = UDim2.fromOffset(190, 40)
regenerate.Visible = false
local regenerateGems = actionButton(panel, "REROLL 3 GEMS", false, function()
	request("AdminRegenerateGems")
end)
regenerateGems.Position = UDim2.fromOffset(720, 14)
regenerateGems.Size = UDim2.fromOffset(180, 40)
regenerateGems.Visible = false

-- Elemental affinities from the armor you're wearing boost your gems.
local function wornAffinities(): { [string]: number }
	local profile = GemClient.Profile
	return if profile and profile.Character then Classes.affinities(profile.Character) else {}
end

-- A gem's concrete effects in one slot, each tagged with the grade behind it:
-- "+12 Thermal damage per tick (Size 8)".
local function effectRows(parent: Instance, gem, slotName: string, color: Color3, affinity)
	for _, line in GemConfig.lines(gem, slotName, { Affinity = affinity }) do
		local tag = if line.Metric then string.format("  (%s %d)", line.Metric, line.Grade or 0) else ""
		local row = text(parent, line.Text .. tag, 12, P.Text)
		row.TextColor3 = if line.Metric == "Size"
			then P.Text
			elseif line.Metric == "Clarity" then P.Text:Lerp(P.Teal, 0.35)
			else P.Text:Lerp(color, 0.35)
	end
end

local gemViewAngles = { Id = "", Spin = 0.6, Tilt = 0 }

local function gemMetric(parent: Instance, label: string, value: number?, color: Color3, y: number)
	local row = new("Frame", {
		Name = label .. "Metric",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 32),
	}, parent)
	local caption = text(row, label, 11, P.Dim, BOLD)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.Size = UDim2.new(1, -55, 0, 16)
	local grade = text(row, if value then tostring(value) .. " / 10" else "ROUGH", 11, color, BOLD)
	grade.AutomaticSize = Enum.AutomaticSize.None
	grade.Position = UDim2.new(1, -55, 0, 0)
	grade.Size = UDim2.fromOffset(55, 16)
	grade.TextXAlignment = Enum.TextXAlignment.Right
	for i = 1, 10 do
		local segment = new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if value and i <= value then color else P.Slot,
			Position = UDim2.new((i - 1) / 10, 0, 0, 20),
			Size = UDim2.new(0.1, -2, 0, 7),
		}, row)
		UiKit.round(segment, 2)
	end
end

-- Simple view first: one overall score and one short sentence. Everything
-- else sits behind MORE DETAILS (reset whenever the selection changes).
local showDetails, detailsKey = false, nil
local drawTooltip
local QUALITY_WORDS = { "Flawed", "Flawed", "Flawed", "Fair", "Fair", "Fine", "Fine", "Superb", "Superb", "Flawless" }
local function summary(value: string)
	local line = text(tipBody, value, 13, P.Text)
	line.Size = UDim2.new(1, -8, 0, 0)
	return line
end
local function detailsButton()
	local b = new("TextButton", {
		Text = if showDetails then "HIDE DETAILS  –" else "MORE DETAILS  +",
		TextSize = 12,
		Font = BOLD,
		TextColor3 = P.Teal,
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, -8, 0, 30),
	}, tipBody)
	UiKit.round(b, 6)
	new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.55 }, b)
	b.Activated:Connect(function()
		showDetails = not showDetails
		drawTooltip()
	end)
end
-- A gem's overall quality: the average of its graded metrics, 1-10.
local function gemQuality(gem): number
	local total, count = 0, 0
	for _, value in { gem.Size, gem.Clarity, gem.Cut } do
		if value then
			total += value
			count += 1
		end
	end
	return if count > 0 then math.clamp(math.floor(total / count + 0.5), 1, 10) else 1
end
-- What a gem's element does, in a few words ("Raw damage and anti-heal").
local function elementGist(element: string): string
	local effect = GemConfig.ElementEffects[element] or ""
	return (string.match(effect, "^([^:]+)") or effect)
end

-- The gem card's sections: a panel with a header in the section's colour,
-- then one row per stat (what it does, and the grade that drives it).
local function cardSection(title: string, color: Color3): Frame
	local section = new("Frame", {
		BackgroundColor3 = color:Lerp(P.Frame, 0.88),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, tipBody)
	UiKit.round(section, 8)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.6 }, section)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 8),
	}, section)
	UiKit.list(section, 3)
	text(section, title, 12, color, BOLD).LayoutOrder = 0
	return section
end
local function statRow(section: Instance, value: string, grade: string?, color: Color3?, size: number?)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #section:GetChildren(),
	}, section)
	local label = text(row, value, size or 12, color or P.Text)
	label.Size = UDim2.new(1, if grade then -84 else 0, 0, 0)
	if grade then
		local tag = text(row, grade, 10, P.Dim, BOLD)
		tag.AutomaticSize = Enum.AutomaticSize.None
		tag.AnchorPoint, tag.Position, tag.Size = Vector2.new(1, 0), UDim2.new(1, 0, 0, 1), UDim2.fromOffset(82, 14)
		tag.TextXAlignment = Enum.TextXAlignment.Right
	end
	return row
end
local function gradeTag(metric: string?, value: number?): string?
	return if metric and value
		then string.format("%s %d", string.upper(GemConfig.MetricLabels[metric] or metric), value)
		else nil
end

local function gemLines(gem)
	local tierColor = GemConfig.TierColors[gem.Tier]
	-- Focus the center column on the selected stone. Gear selections restore
	-- the compact inspector and combat ratings below it.
	tooltip.Size = UDim2.fromOffset(384, 416)
	statsBox.Visible = false
	tipArt.Visible = false
	tipBody.Position = UDim2.fromOffset(0, 0)
	tipBody.Size = UDim2.new(1, 0, 1, -72)
	local hero = new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, if showDetails then 204 else 168) },
		tipBody
	)
	local stage = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(17, 27, 40),
		Size = UDim2.fromOffset(156, 166),
		ClipsDescendants = true,
	}, hero)
	UiKit.round(stage, 8)
	new("UIStroke", { Color = tierColor, Transparency = 0.5, Thickness = 1 }, stage)
	GemArt.backdrop(stage)
	if gemViewAngles.Id ~= gem.Id then
		gemViewAngles.Id, gemViewAngles.Spin, gemViewAngles.Tilt = gem.Id, 0.6, 0
	end
	local _, viewControls = GemArt.inspectorViewport(stage, gem, gemViewAngles)
	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.new(1, -166, 0, 166),
	}, hero)
	local gemNameLabel = text(info, GemConfig.title(gem), 18, tierColor, BOLD)
	gemNameLabel.AutomaticSize = Enum.AutomaticSize.None
	gemNameLabel.Size = UDim2.new(1, 0, 0, 42)
	gemNameLabel.TextYAlignment = Enum.TextYAlignment.Top
	local state = if not gem.Cut then "ROUGH" elseif gem.Cut >= 10 then "GEM MINT" else "CUT " .. gem.Cut
	local badge = text(
		info,
		string.format(
			"%s %s",
			string.upper(GemConfig.TierLabels[gem.Tier]),
			string.upper(GemConfig.elementName(gem.Element))
		),
		12,
		GemConfig.ElementColors[gem.Element],
		BOLD
	)
	badge.AutomaticSize = Enum.AutomaticSize.None
	badge.Position = UDim2.fromOffset(0, 43)
	badge.Size = UDim2.new(1, 0, 0, 24)
	badge.TextSize = 10
	if not showDetails then
		local quality = gemQuality(gem)
		gemMetric(info, "QUALITY  ·  " .. string.upper(QUALITY_WORDS[quality]), quality, tierColor, 68)
		local gist = text(info, elementGist(gem.Element) .. ".", 12, P.Text)
		gist.AutomaticSize = Enum.AutomaticSize.None
		gist.Position, gist.Size = UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 34)
		gist.TextYAlignment = Enum.TextYAlignment.Top
		local worth = text(
			info,
			string.format("Worth %d coins", GemConfig.value(gem))
				.. (if gem.MinedBy then "  ·  Mined by " .. gem.MinedBy else ""),
			11,
			P.Gold,
			BOLD
		)
		worth.TextTruncate = Enum.TextTruncate.AtEnd
		worth.AutomaticSize = Enum.AutomaticSize.None
		worth.Position, worth.Size = UDim2.fromOffset(0, 142), UDim2.new(1, 0, 0, 16)
		local surge = gem.Cut and Tech.surgeStats(gem)
		-- Three metric tiles: the grade and what it does for this gem.
		local tiles = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 48) }, tipBody)
		new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 48),
			CellPadding = UDim2.fromOffset(6, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, tiles)
		for order, metric in
			{
				{ "SIZE", gem.Size, tierColor, string.format("+%d%% damage", (gem.Size or 0) * 3) },
				{
					"CLARITY",
					gem.Clarity,
					P.Teal,
					if surge
						then string.format("%.1fs cooldown", surge.Cooldown or surge.Recovery)
						else "longer effects",
				},
				{
					"CUT",
					gem.Cut,
					P.Gold,
					if gem.Cut then string.format("%g%% crit", (gem.Cut or 0) * 0.5) else "uncut",
				},
			}
		do
			local tile = new("Frame", { BackgroundColor3 = P.Frame, LayoutOrder = order }, tiles)
			UiKit.round(tile, 6)
			new("UIStroke", { Color = metric[3], Thickness = 1, Transparency = 0.6 }, tile)
			local caption = text(tile, metric[1], 10, P.Dim, BOLD)
			caption.AutomaticSize, caption.Position, caption.Size =
				Enum.AutomaticSize.None, UDim2.fromOffset(8, 4), UDim2.new(0.5, 0, 0, 12)
			local value = text(tile, if metric[2] then tostring(metric[2]) else "–", 18, metric[3], BOLD)
			value.AutomaticSize, value.Position, value.Size =
				Enum.AutomaticSize.None, UDim2.new(0.5, 0, 0, 2), UDim2.new(0.5, -8, 0, 20)
			value.TextXAlignment = Enum.TextXAlignment.Right
			local effect = text(tile, metric[4], 10, P.Text)
			effect.AutomaticSize, effect.TextWrapped, effect.TextTruncate =
				Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			effect.Position, effect.Size = UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 16)
		end
		-- The surge this gem casts from a Surge Array slot.
		if surge then
			local color = GemConfig.ElementColors[gem.Element] or P.Gold
			local card = new("Frame", { BackgroundColor3 = P.Frame, Size = UDim2.new(1, -8, 0, 44) }, tipBody)
			UiKit.round(card, 6)
			new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5 }, card)
			local icon = text(card, "◆", 20, color, BOLD)
			icon.AutomaticSize, icon.Position, icon.Size =
				Enum.AutomaticSize.None, UDim2.fromOffset(5, 6), UDim2.fromOffset(32, 32)
			icon.TextXAlignment, icon.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
			SurgeIcons.apply(icon, surge, color)
			local title = text(
				card,
				-- The surge and its power (rank); its tier names the ability.
				string.format("%s  ·  RANK %s", string.upper(surge.Name), ({ "I", "II", "III" })[surge.Rank] or "I"),
				11,
				color,
				BOLD
			)
			title.AutomaticSize, title.TextWrapped, title.TextTruncate =
				Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			title.Position, title.Size = UDim2.fromOffset(42, 6), UDim2.new(1, -50, 0, 14)
			local parts = { (Tech.TierNames[surge.Tier] or "") .. " surge" }
			if surge.Damage then
				table.insert(parts, string.format("%d%% damage", math.floor(surge.Damage * 100 + 0.5)))
			elseif surge.Duration then
				table.insert(parts, string.format("%gs effect", math.floor(surge.Duration * 10 + 0.5) / 10))
			end
			table.insert(
				parts,
				string.format(
					"%g Charge%s",
					math.floor(surge.Cost * 10 + 0.5) / 10,
					if surge.PerSecond then "/s" else ""
				)
			)
			table.insert(parts, string.format("%.1fs cooldown", surge.Cooldown or surge.Recovery))
			local line = text(card, table.concat(parts, "  ·  "), 11, P.Text)
			line.AutomaticSize, line.TextWrapped, line.TextTruncate =
				Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			line.Position, line.Size = UDim2.fromOffset(42, 23), UDim2.new(1, -50, 0, 14)
		end
		-- What it does as an enchant, one line per side.
		for _, side in { { "Weapon", "IN A WEAPON" }, { "Armor", "IN ARMOR" } } do
			local name, effect = GemConfig.enchantment(gem, side[1])
			local line = text(tipBody, string.format("%s  ·  %s:  %s", side[2], name, effect), 11, P.Dim)
			line.AutomaticSize, line.TextWrapped, line.TextTruncate =
				Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
			line.Size = UDim2.new(1, -8, 0, 15)
		end
		local weak = ElementMatchup.weakTo(gem.Element)
		local resist = text(
			tipBody,
			string.format(
				"ARMOR RESIST  ·  %s %d%% per piece  ·  weak to %s",
				GemConfig.elementName(gem.Element),
				math.floor(ElementMatchup.gemResist(gem) * 100 + 0.5),
				if weak then GemConfig.elementName(weak) else "none"
			),
			11,
			P.Dim
		)
		resist.AutomaticSize, resist.TextWrapped, resist.TextTruncate =
			Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
		resist.Size = UDim2.new(1, -8, 0, 15)
		return
	end
	gemMetric(info, "SIZE  ·  MAGNITUDE", gem.Size, tierColor, 68)
	gemMetric(info, "CLARITY  ·  DURATION", gem.Clarity, P.Teal, 100)
	gemMetric(info, "CUT  ·  PRECISION", gem.Cut, P.Gold, 132)
	local controls = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 174),
		Size = UDim2.new(1, 0, 0, 28),
	}, hero)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -5, 0, 28),
		CellPadding = UDim2.fromOffset(6, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, controls)
	for i, control in
		{
			{
				Label = "LEFT",
				Run = function()
					viewControls.Rotate(-math.pi / 6)
				end,
			},
			{
				Label = "RIGHT",
				Run = function()
					viewControls.Rotate(math.pi / 6)
				end,
			},
			{ Label = "TILT", Run = viewControls.Tilt },
			{ Label = "RESET", Run = viewControls.Reset },
		}
	do
		local button = actionButton(controls, control.Label, false, control.Run)
		button.LayoutOrder = i
	end
	local color = GemConfig.ElementColors[gem.Element]
	-- At a glance: its cut, its shade and what it sells for.
	local facts = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 22) }, tipBody)
	UiKit.list(facts, 6, true)
	for order, fact in
		{
			{ state, P.Text },
			{ GemConfig.shade(gem).Name, color },
			{ string.format("Sells for %d coins", GemConfig.value(gem)), P.Gold },
		}
	do
		local chip = text(facts, fact[1], 11, fact[2], BOLD)
		chip.AutomaticSize, chip.Size, chip.LayoutOrder = Enum.AutomaticSize.X, UDim2.fromOffset(0, 22), order
		chip.BackgroundColor3, chip.BackgroundTransparency = fact[2], 0.86
		chip.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.round(chip, 5)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)
	end
	-- The surge it casts from a Surge Array slot.
	local surge = gem.Cut and Tech.surgeStats(gem)
	if surge then
		local section = cardSection(
			string.format(
				"SURGE  ·  %s  ·  RANK %s",
				string.upper(surge.Name),
				({ "I", "II", "III" })[surge.Rank] or "I"
			),
			P.Gold
		)
		statRow(
			section,
			string.format(
				"%s surge  ·  rank %d of 3 (each rank: more damage, faster, cheaper)",
				Tech.TierNames[surge.Tier] or "",
				surge.Rank or 1
			),
			nil,
			P.Dim,
			11
		)
		if surge.Damage then
			statRow(section, string.format("%d%% base damage", math.floor(surge.Damage * 100 + 0.5)))
			statRow(section, string.format("+%d%% damage", (gem.Size or 0) * 3), gradeTag("Size", gem.Size))
		else
			statRow(section, string.format("%gs effect", math.floor(surge.Duration * 10 + 0.5) / 10))
		end
		statRow(section, string.format("%.1fs recovery", surge.Recovery), gradeTag("Clarity", gem.Clarity))
		statRow(section, string.format("%g%% crit chance", surge.Crit * 100), gradeTag("Cut", gem.Cut))
		statRow(section, "Sockets into any Surge Slot", nil, P.Dim, 11)
	end
	local affinity = wornAffinities()
	-- In a weapon: what its hits add.
	local weaponName = GemConfig.enchantment(gem, "Weapon")
	local weapon = cardSection("IN A WEAPON  ·  " .. string.upper(weaponName), color)
	for _, line in GemConfig.lines(gem, "Weapon", { Affinity = affinity }) do
		statRow(weapon, line.Text, gradeTag(line.Metric, line.Grade))
	end
	local pvp = {}
	for _, line in GemConfig.lines(gem, "Weapon", { Affinity = affinity, PvP = true }) do
		table.insert(pvp, line.Text)
	end
	statRow(weapon, "Against players: " .. table.concat(pvp, "  ·  "), nil, P.Dim, 11)
	-- In armor or a shield: its defence, and the element it resists.
	local armorName = GemConfig.enchantment(gem, "Armor")
	local armor = cardSection("IN ARMOR OR SHIELD  ·  " .. string.upper(armorName), color)
	for _, line in GemConfig.lines(gem, "Armor", { Affinity = affinity }) do
		statRow(armor, line.Text, gradeTag(line.Metric, line.Grade))
	end
	local element = GemConfig.elementName(gem.Element)
	statRow(
		armor,
		string.format(
			"Resists %s: take %d%% less %s damage",
			element,
			math.floor(ElementMatchup.gemResist(gem) * 100 + 0.5),
			element
		),
		"EACH PIECE",
		P.Good
	)
	local weak = ElementMatchup.weakTo(gem.Element)
	if weak then
		statRow(
			armor,
			string.format(
				"If %s is your main armor element, %s hits you for %d%%",
				element,
				GemConfig.elementName(weak),
				math.floor(ElementMatchup.Weak * 100 + 0.5)
			),
			nil,
			P.Bad:Lerp(P.Text, 0.25)
		)
	end
	-- What the armor you're wearing resists right now.
	local worn = ElementMatchup.profile(GemClient.Profile and GemClient.Profile.Character)
	local parts = {}
	for _, name in GemConfig.Elements do
		local share = worn.Resist[name]
		if share and share > 0 then
			table.insert(parts, string.format("%s %d%%", GemConfig.elementName(name), math.floor(share * 100 + 0.5)))
		end
	end
	local weakNow = worn.Main and ElementMatchup.weakTo(worn.Main)
	statRow(
		armor,
		string.format(
			"Your armor now: %s%s  (max %d%% each)",
			if #parts > 0 then table.concat(parts, ", ") else "no resistances",
			if weakNow then "  ·  weak to " .. GemConfig.elementName(weakNow) else "",
			math.floor(ElementMatchup.Cap * 100 + 0.5)
		),
		nil,
		P.Dim,
		11
	)
	for id, bonus in affinity do
		local affix = GemConfig.AffixById[id]
		if affix and affix.Element == gem.Element then
			statRow(armor, "Boosted by your armor  ·  " .. GemConfig.affixText(id, bonus), nil, color, 11)
		end
	end
	tooltipStroke.Color = tierColor
end

-- An item's signature: its working effect, or what's planned for it.
local function signatureLine(gear)
	if gear.ProposedBuff and not gear.BuffReady then
		text(tipBody, "Signature (coming soon): " .. gear.ProposedBuff, 12, P.Dim)
	elseif gear.Passive and gear.Passive.Text ~= "" then
		text(tipBody, gear.Passive.Name .. ": " .. gear.Passive.Text, 13, P.Gold)
	end
end

-- A small rounded chip of text, e.g. "+3 Defense".
local function chipLabel(parent: Instance, value: string, color: Color3, order: number?): TextLabel
	local chip = new("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Text = value,
		Font = BOLD,
		TextSize = 12,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25),
		LayoutOrder = order or 0,
	}, parent)
	UiKit.round(chip, 4)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, chip)
	return chip
end

-- The top of the inspector for one item: the item in 3D, its name, rarity and
-- stats; under it the gem in its socket with what the gem adds.
local function itemCard(slotName: string, id: string, gear, roll, gem, worn: boolean)
	local rarity = GearRolls.Rarities[if roll then roll.Rarity else 1]
	tooltipStroke.Color = rarity.Color

	local hero = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 84) }, tipBody)
	local stage = new("Frame", {
		BackgroundColor3 = rarity.Color:Lerp(P.Frame, 0.85),
		Size = UDim2.fromOffset(104, 84),
		ClipsDescendants = true,
	}, hero)
	UiKit.round(stage, 6)
	new("UIStroke", { Color = rarity.Color, Thickness = 1, Transparency = 0.45 }, stage)
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, stage)
	-- Worn items come from the avatar's gear; spare ones from the server's previews.
	if not GearArt.draw(view, slotName, id, worn) then
		local hint = text(stage, "3D preview\nloading", 11, P.Dim, BOLD)
		hint.AutomaticSize = Enum.AutomaticSize.None
		hint.Size = UDim2.fromScale(1, 1)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.TextYAlignment = Enum.TextYAlignment.Center
	end

	local info = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(114, 0),
		Size = UDim2.new(1, -114, 1, 0),
	}, hero)
	local where = text(
		info,
		(if worn then "EQUIPPED " else "SPARE ") .. string.upper(Slots.Definitions[slotName].Label),
		11,
		P.Dim,
		BOLD
	)
	where.AutomaticSize = Enum.AutomaticSize.None
	where.Size = UDim2.new(1, 0, 0, 14)
	local name = text(info, gear.Name, 17, rarity.Color, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Position = UDim2.fromOffset(0, 14)
	name.Size = UDim2.new(1, 0, 0, 38)
	name.TextYAlignment = Enum.TextYAlignment.Top
	local chips = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 30),
	}, info)
	local flow = UiKit.list(chips, 4, true)
	flow.Wraps = true
	chipLabel(chips, rarity.Name, rarity.Color, 0)
	local stats, score, best = {}, 0, nil
	for stat, amount in roll and roll.Stats or {} do
		local percent = stat == "Critical" or stat == "Cooldown"
		table.insert(stats, { stat, amount, percent })
		local points = if percent then amount * 100 else amount
		score += points
		if not best or points > best[2] then
			best = { stat, points }
		end
	end
	table.sort(stats, function(a, b)
		return a[1] < b[1]
	end)
	-- One overall number up front; the stat-by-stat list is in the details.
	chipLabel(chips, string.format("GEAR SCORE %d", math.floor(score + 0.5)), P.Gold, 1)
	local slotWord = string.lower(Slots.Definitions[slotName].Label)
	summary(
		string.format("%s %s", rarity.Name, slotWord)
			.. (if best then " built for " .. best[1] .. "." else ".")
			.. (
				if gem
					then " Enchanted with " .. GemConfig.elementName(gem.Element) .. ": " .. string.lower(
						elementGist(gem.Element)
					) .. "."
					else " Its gem socket is empty."
			)
	)
	-- The socket: the gem and what it adds, or an invitation to fill it.
	local socket = new("Frame", {
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, -8, 0, if gem then 66 else 46),
	}, tipBody)
	UiKit.round(socket, 6)
	local gemColor = if gem then GemConfig.ElementColors[gem.Element] or P.Teal else P.Edge
	new("UIStroke", { Color = gemColor, Thickness = 1, Transparency = if gem then 0.35 else 0.6 }, socket)
	local well = new("Frame", {
		BackgroundColor3 = gemColor:Lerp(P.Frame, 0.8),
		Position = UDim2.fromOffset(6, if gem then 8 else 4),
		Size = UDim2.fromOffset(if gem then 50 else 38, if gem then 50 else 38),
	}, socket)
	UiKit.round(well, if gem then 25 else 19)
	if gem then
		-- The gem in this piece: name, one quality bar and what it adds.
		GemArt.viewport(well, gem, false)
		local gemName, effect = GemConfig.enchantment(gem, slotName)
		local title = text(socket, string.format("%s  ·  %s", GemConfig.shade(gem).Name, gemName), 13, gemColor, BOLD)
		title.AutomaticSize = Enum.AutomaticSize.None
		title.Position = UDim2.fromOffset(66, 5)
		title.Size = UDim2.new(1, -72, 0, 16)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		local quality = gemQuality(gem)
		local grade = text(
			socket,
			string.format(
				"%s %s  ·  QUALITY %d/10 %s",
				string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier),
				string.upper(GemConfig.elementName(gem.Element)),
				quality,
				string.upper(QUALITY_WORDS[quality])
			),
			10,
			P.Dim,
			BOLD
		)
		grade.AutomaticSize = Enum.AutomaticSize.None
		grade.Position = UDim2.fromOffset(66, 22)
		grade.Size = UDim2.new(1, -72, 0, 12)
		grade.TextTruncate = Enum.TextTruncate.AtEnd
		for i = 1, 10 do
			local segment = new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = if i <= quality then gemColor else P.Slot,
				Position = UDim2.fromOffset(66 + (i - 1) * 14, 37),
				Size = UDim2.fromOffset(12, 5),
			}, socket)
			UiKit.round(segment, 2)
		end
		local adds = text(socket, effect, 12, P.Text)
		adds.AutomaticSize = Enum.AutomaticSize.None
		adds.Position = UDim2.fromOffset(66, 46)
		adds.Size = UDim2.new(1, -72, 0, 16)
		adds.TextTruncate = Enum.TextTruncate.AtEnd
		adds.TextWrapped = false
	else
		local ring = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
			Rotation = 45,
		}, well)
		UiKit.round(ring, 3)
		new("UIStroke", { Color = P.Dim, Thickness = 1.5, Transparency = 0.3 }, ring)
		local title = text(socket, "EMPTY GEM SOCKET", 12, P.Dim, BOLD)
		title.AutomaticSize = Enum.AutomaticSize.None
		title.Position = UDim2.fromOffset(54, 7)
		title.Size = UDim2.new(1, -60, 0, 16)
		local hint = text(
			socket,
			if worn then "Drag a gem from your backpack onto this item." else "Equip it, then drag a gem onto it.",
			12,
			P.Text
		)
		hint.AutomaticSize = Enum.AutomaticSize.None
		hint.Position = UDim2.fromOffset(54, 25)
		hint.Size = UDim2.new(1, -60, 0, 16)
		hint.TextTruncate = Enum.TextTruncate.AtEnd
	end
	if not showDetails then
		return
	end
	-- Every rolled stat, spelled out.
	local parts = {}
	for _, entry in stats do
		table.insert(
			parts,
			if entry[3]
				then string.format("+%g%% %s", entry[2] * 100, entry[1])
				else string.format("+%g %s", entry[2], entry[1])
		)
	end
	if #parts > 0 then
		text(tipBody, "STATS  ·  " .. table.concat(parts, "  ·  "), 12, P.Gold, BOLD)
	end

	-- Elemental affinities this piece rolled, in their element's colour.
	for _, affix in roll and roll.Affixes or {} do
		local def = GemConfig.AffixById[affix.Id]
		if def then
			text(tipBody, GemConfig.affixText(affix.Id, affix.Bonus), 13, GemConfig.ElementColors[def.Element], BOLD)
		end
	end

	if gem then
		effectRows(tipBody, gem, slotName, GemConfig.ElementColors[gem.Element] or P.Teal, wornAffinities())
	end
	if gear.ArmorFamily then
		local state = Classes.setState(GemClient.Profile.Character).Active[gear.ArmorFamily]
		text(
			tipBody,
			string.format("%s · %d/6 equipped · %d-piece bonus active", gear.ArmorFamily, state.Count, state.Tier),
			12,
			P.Teal
		)
		if roll and roll.Budget then
			text(
				tipBody,
				string.format("%d stat points · %d modifiers", roll.Budget, #(roll.Modifiers or {})),
				12,
				P.Dim
			)
		end
	end
	if gear.ArmorFamily then
		text(tipBody, ArmorFamilies.EnhancementText[gear.ArmorFamily], 12, P.Dim)
	end
	signatureLine(gear)
	-- A Forge weapon: how it fights.
	if gear.Forge and gear.Attack then
		text(
			tipBody,
			string.format(
				"%s  ·  %.2fs swings  ·  %g reach  ·  %d° arc",
				gear.Blurb or "",
				gear.Attack.Rate,
				gear.Attack.Range,
				gear.Attack.Arc or 90
			),
			12,
			P.Dim
		)
	end
	-- What makes this one its own: finish, Prismatic, serial, finder.
	if roll then
		text(tipBody, GearRolls.identity(roll), 12, if roll.Prismatic then P.Gold else P.Teal, BOLD)
	end
end

local function drawTooltipContent()
	local key = if selection
		then selection.Kind .. ":" .. tostring(selection.Slot or "") .. ":" .. tostring(
			selection.Id or (selection.Gem and selection.Gem.Id) or ""
		)
		else nil
	if key ~= detailsKey then
		detailsKey, showDetails = key, false
	end
	-- Nothing picked: the portrait, loadout and the how-it-works guide fill the column.
	tooltip.Size = UDim2.fromOffset(384, if selection == nil then 416 else 240)
	statsBox.Visible = true
	local showArt = selection ~= nil and (selection.Kind == "Gem" or selection.Kind == "Socket")
	tipArt.Visible = showArt
	tipBody.Position = UDim2.fromOffset(if showArt then 66 else 0, 0)
	tipBody.Size = UDim2.new(1, if showArt then -66 else 0, 1, -72)
	clear(tipBody)
	clear(tipActions)
	clear(tipArt)
	tooltipStroke.Color = P.Edge
	local hint = if atVey or Config.MenuOnly then "" else "  Sockets can be changed at Vey's Arcanum (east road)."

	if selection and selection.Kind == "Inventory" then
		local slotName, id = selection.Slot, selection.Id
		local kind = Slots.Definitions[slotName].Kind
		local profile = GemClient.Profile
		local loadout = profile and profile.Character or {}
		local quality = profile and profile.Owned and profile.Owned[kind] and profile.Owned[kind][id]
		local gear = loadout.Class and Classes.gear(loadout.Class, kind, id)
		if not quality or not gear then
			text(tipBody, "ITEM UNAVAILABLE", 18, P.Dim, BOLD)
			text(tipBody, "This item is no longer in your inventory.", 13, P.Dim)
			return
		end
		local roll = GearRolls.get(loadout, slotName, id)
		local gem = loadout.ItemGems and loadout.ItemGems[slotName] and loadout.ItemGems[slotName][id]
		itemCard(slotName, id, gear, roll, gem, loadout[slotName] == id)
		if loadout[slotName] == id then
			text(tipActions, "EQUIPPED", 13, P.Gold, BOLD)
		else
			local candidate = table.clone(loadout)
			candidate[slotName], candidate[slotName .. "Quality"], candidate[slotName .. "Gem"] = id, quality, gem
			local before, after = Classes.ratings(loadout), Classes.ratings(candidate)
			-- Only what would change: green up, red down.
			local changes = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -8, 0, 22),
			}, tipBody)
			UiKit.list(changes, 5, true)
			local lead = text(changes, "IF EQUIPPED", 11, P.Dim, BOLD)
			lead.AutomaticSize = Enum.AutomaticSize.X
			lead.Size = UDim2.fromOffset(0, 22)
			lead.TextYAlignment = Enum.TextYAlignment.Center
			lead.LayoutOrder = 0
			local any = false
			for i, stat in Classes.StatNames do
				local delta = after[stat].Base + after[stat].Bonus - before[stat].Base - before[stat].Bonus
				if delta ~= 0 then
					any = true
					chipLabel(changes, string.format("%s %+d", stat, delta), if delta > 0 then P.Good else P.Bad, i)
				end
			end
			if not any then
				chipLabel(changes, "No stat change", P.Dim, 1)
			end
			actionButton(tipActions, "EQUIP", true, function()
				request("EquipGear", kind, id)
			end)
		end
		detailsButton()
		return
	end

	if selection and selection.Kind == "Gear" then
		local slotName = selection.Slot
		local kind = Slots.Definitions[slotName].Kind
		local profile = GemClient.Profile
		local loadout = profile and profile.Character or {}
		local owned = profile and profile.Owned and profile.Owned[kind] or {}
		local slotLabel = Slots.Definitions[slotName].Label
		local equippedItem = Classes.gear(loadout.Class, kind, loadout[slotName])
		local roll = GearRolls.get(loadout, slotName)
		if equippedItem then
			itemCard(slotName, loadout[slotName], equippedItem, roll, loadout[slotName .. "Gem"], true)
		end
		if equippedItem then
			detailsButton()
		end
		if showDetails and slotName == "Helmet" and loadout.Helmet then
			local traits = if roll
				then GearRolls.appearance(roll)
				else SuitTraits.forSuit(player.UserId, Slots.model(loadout.Helmet))
			text(
				tipBody,
				traits.HelmetName
					.. " • "
					.. traits.HelmetRarity
					.. (if traits.VisorName then "  ·  Visor: " .. traits.VisorName else ""),
				12,
				P.Teal
			)
		end
		local others = {}
		for _, gear in (loadout.Class and Classes.List[loadout.Class] or {})[kind] or {} do
			if owned[gear.Id] and loadout[slotName] ~= gear.Id then
				table.insert(others, gear)
			end
		end
		if #others == 0 then
			text(
				tipBody,
				"No other " .. string.lower(slotLabel) .. " yet. Win duels and dungeons, or trade at PROBE-7.",
				12,
				P.Dim
			)
			return
		end
		for _, gear in others do
			local otherRoll = GearRolls.get(loadout, slotName, gear.Id)
			local otherRarity = GearRolls.Rarities[if otherRoll then otherRoll.Rarity else 1]
			-- Inset from the right so the button clears the scroll bar.
			local row = new("Frame", {
				BackgroundColor3 = P.Frame,
				BackgroundTransparency = 0.3,
				Size = UDim2.new(1, -8, 0, 34),
			}, tipBody)
			UiKit.round(row, 4)
			local name = text(row, gear.Name, 13, otherRarity.Color, BOLD)
			name.AutomaticSize = Enum.AutomaticSize.None
			name.Position = UDim2.fromOffset(8, 2)
			name.Size = UDim2.new(1, -100, 0, 16)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local sub = text(row, "SWAP IN  ·  " .. string.upper(otherRarity.Name), 11, P.Gold, BOLD)
			sub.AutomaticSize = Enum.AutomaticSize.None
			sub.Position = UDim2.fromOffset(8, 18)
			sub.Size = UDim2.new(1, -100, 0, 13)
			local b = actionButton(row, "EQUIP", false, function()
				request("EquipGear", kind, gear.Id)
			end)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -4, 0.5, 0)
			b.Size = UDim2.fromOffset(80, 28)
		end
		return
	end

	if selection and selection.Kind == "Socket" then
		local slotName = selection.Slot
		local gem = socketed(slotName)
		if gem then
			gemLines(gem)
			detailsButton()
			actionButton(tipActions, "REMOVE GEM", false, function()
				request("UnsocketGem", slotName)
			end)
		else
			text(tipBody, string.upper(slotName) .. " SOCKET", 18, P.Gold, BOLD)
			text(
				tipBody,
				"Drag a gem here from your backpack to enchant your " .. string.lower(slotName) .. "." .. hint,
				13,
				P.Dim
			)
		end
		return
	end

	local gem = selection and selection.Kind == "Gem" and selection.Gem
	if not gem then
		-- Nothing selected: the character's portrait card.
		local profile = GemClient.Profile
		local loadout = profile and profile.Character or {}
		local card = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(17, 27, 40),
			Size = UDim2.new(1, -6, 0, 138),
			ClipsDescendants = true,
		}, tipBody)
		UiKit.round(card, 8)
		new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.6 }, card)
		-- The portrait sits in its own lit alcove on the left.
		local alcove = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 38, 56),
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(0, 146, 1, -16),
			ClipsDescendants = true,
		}, card)
		UiKit.round(alcove, 6)
		new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.7 }, alcove)
		GemArt.backdrop(alcove)
		local view = new("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2, -- above the backdrop's glow
			Ambient = Color3.fromRGB(150, 160, 185),
			LightColor = Color3.fromRGB(255, 240, 215),
			LightDirection = Vector3.new(-0.5, -0.8, 0.6),
		}, alcove)
		local world = new("WorldModel", {}, view)
		local camera = new("Camera", { FieldOfView = 26 }, view)
		view.CurrentCamera = camera
		local character = player.Character
		if character then
			pcall(function()
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
				-- A head-and-shoulders shot, facing the camera.
				local head = copy:FindFirstChild("Head")
				local focus
				if head and head:IsA("BasePart") then
					focus = head.Position - Vector3.new(0, 0.9, 0)
				else
					local box, size = copy:GetBoundingBox()
					focus = box.Position + Vector3.new(0, size.Y * 0.2, 0)
				end
				camera.CFrame = CFrame.lookAt(focus + Vector3.new(1.2, 0.5, -8.5), focus)
			end)
		end
		local info = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(164, 14),
			Size = UDim2.new(1, -176, 1, -28),
		}, card)
		-- (Your name is in the header above; the card leads with your class.)
		local class = loadout.Class and Classes.get(loadout.Class)
		local classLabel = text(info, string.upper(class and class.Name or "Miner"), 16, P.Teal, BOLD)
		classLabel.AutomaticSize = Enum.AutomaticSize.None
		classLabel.Position, classLabel.Size = UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 20)
		-- Overall gear score: every rolled stat on the six worn pieces.
		local score = 0
		for _, slotName in Slots.Order do
			local roll = loadout[slotName] and GearRolls.get(loadout, slotName)
			for stat, amount in roll and roll.Stats or {} do
				score += if stat == "Critical" or stat == "Cooldown" then amount * 100 else amount
			end
		end
		local scoreLabel = text(info, "GEAR SCORE", 10, P.Dim, BOLD)
		scoreLabel.AutomaticSize = Enum.AutomaticSize.None
		scoreLabel.Position, scoreLabel.Size = UDim2.fromOffset(0, 46), UDim2.new(1, 0, 0, 12)
		local scoreValue = text(info, tostring(math.floor(score + 0.5)), 26, P.Gold, BOLD)
		scoreValue.AutomaticSize = Enum.AutomaticSize.None
		scoreValue.Position, scoreValue.Size = UDim2.fromOffset(0, 58), UDim2.new(1, 0, 0, 30)
		-- Armor set progress, best set first.
		local sets = {}
		local active = loadout.Class and Classes.setState(loadout).Active or {}
		for _, family in ArmorFamilies.Order do
			local state = active[family]
			if state and state.Count > 0 then
				table.insert(sets, { family, state.Count })
			end
		end
		table.sort(sets, function(a, b)
			return a[2] > b[2]
		end)
		local setLines = {}
		for i = 1, math.min(2, #sets) do
			table.insert(setLines, string.format("%s  %d/6", sets[i][1], sets[i][2]))
		end
		local setLabel = text(
			info,
			"SETS  ·  " .. (if #setLines > 0 then table.concat(setLines, "  ·  ") else "none yet"),
			10,
			P.Text
		)
		setLabel.AutomaticSize = Enum.AutomaticSize.None
		setLabel.Position, setLabel.Size = UDim2.fromOffset(0, 88), UDim2.new(1, 0, 0, 26)
		setLabel.TextWrapped = true
		setLabel.TextYAlignment = Enum.TextYAlignment.Top
		-- Below the portrait: the combat loadout and a few records, three per row.
		local function gridRow(title: string, cells)
			local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 22) }, tipBody)
			local lead = text(row, title, 10, P.Dim, BOLD)
			lead.AutomaticSize, lead.Position, lead.Size =
				Enum.AutomaticSize.None, UDim2.fromOffset(0, 0), UDim2.fromOffset(70, 22)
			lead.TextYAlignment = Enum.TextYAlignment.Center
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(72, 0),
				Size = UDim2.new(1, -72, 1, 0),
			}, row)
			new("UIGridLayout", {
				CellSize = UDim2.new(1 / 3, -4, 0, 20),
				CellPadding = UDim2.fromOffset(4, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, holder)
			for order, cell in cells do
				local chip = new("TextLabel", {
					Text = cell[1],
					TextSize = 10,
					Font = BOLD,
					TextColor3 = cell[2],
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundColor3 = cell[2],
					BackgroundTransparency = 0.84,
					LayoutOrder = order,
				}, holder)
				UiKit.round(chip, 4)
				new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, chip)
			end
		end
		local surgeCells = {}
		for _, key in { "Q", "E", "R" } do
			local gem = Tech.surgeGem(loadout, key)
			local surge = gem and Tech.surgeStats(gem)
			table.insert(surgeCells, {
				key .. "  " .. (if surge then surge.Name else "Empty"),
				if gem then GemConfig.ElementColors[gem.Element] or P.Gold else P.Dim,
			})
		end
		gridRow("SURGES", surgeCells)
		local maneuverCells = {}
		for i, id in loadout.Maneuvers or Tech.DefaultManeuvers do
			local definition = Tech.Catalog[id]
			local learned = profile ~= nil and Tree.isLearned(profile, id)
			table.insert(maneuverCells, {
				i .. "  " .. (if definition then definition.Name else id),
				if learned then Tech.Resources.Stamina.Color else P.Dim,
			})
		end
		gridRow("MANEUVERS", maneuverCells)
		local augmentLevel = Tree.level(profile and profile.Augments and profile.Augments.XP or 0)
		local seasonLevel = Season.levelFor(profile and profile.Season and profile.Season.XP or 0)
		gridRow("PROGRESS", {
			{ "Augment Lv " .. augmentLevel, P.Gold },
			{ "Season Lv " .. seasonLevel, P.Teal },
			{ (profile and profile.Duel and profile.Duel.Wins or 0) .. " duel wins", P.Text },
		})
		-- Gear presets (Shared.GearPresets): save what you wear, wear a saved
		-- setup in one tap. Ranked switches between rounds use these.
		local presetBox = new("Frame", {
			BackgroundColor3 = P.Frame,
			BackgroundTransparency = 0.2,
			Size = UDim2.new(1, -8, 0, 122),
			LayoutOrder = 100,
		}, tipBody)
		UiKit.round(presetBox, 6)
		UiKit.pad(presetBox, 8)
		UiKit.list(presetBox, 6)
		local presetTitle = text(presetBox, "PRESETS  ·  tap a name to rename", 10, P.Dim, BOLD)
		presetTitle.LayoutOrder = 0
		local presets = GearPresets.clean(profile and (profile :: any).Presets)
		for index = 1, GearPresets.Count do
			local preset = presets[index]
			local worn = preset ~= nil and GearPresets.matches(loadout, preset)
			local line = new("Frame", {
				BackgroundColor3 = if worn then P.Gold else P.Inset,
				BackgroundTransparency = if worn then 0.82 else 0.3,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = index,
			}, presetBox)
			UiKit.round(line, 4)
			local tag = text(line, tostring(index), 11, P.Frame, BOLD)
			tag.AutomaticSize = Enum.AutomaticSize.None
			tag.BackgroundTransparency, tag.BackgroundColor3 = 0, if preset then P.Gold else P.Dim
			tag.Size = UDim2.fromOffset(22, 24)
			tag.TextXAlignment = Enum.TextXAlignment.Center
			UiKit.round(tag, 4)
			local name = new("TextBox", {
				Text = if preset then preset.Name else "Empty",
				PlaceholderText = "Preset " .. index,
				ClearTextOnFocus = false,
				TextEditable = preset ~= nil,
				TextSize = 12,
				Font = BOLD,
				TextColor3 = if preset then P.Text else P.Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -196, 1, 0),
			}, line)
			name.FocusLost:Connect(function()
				if preset and name.Text ~= preset.Name then
					request("PresetRename", index, name.Text)
				end
			end)
			local summary = text(
				line,
				if worn then "WORN" elseif preset then GearPresets.label(preset) else "",
				10,
				if worn then P.Gold else P.Dim,
				BOLD
			)
			summary.AutomaticSize = Enum.AutomaticSize.None
			summary.AnchorPoint = Vector2.new(1, 0)
			summary.Position, summary.Size = UDim2.new(1, -112, 0, 0), UDim2.fromOffset(92, 24)
			summary.TextXAlignment = Enum.TextXAlignment.Right
			local function small(label: string, x: number, color: Color3, enabled: boolean, onClick: () -> ())
				local b = new("TextButton", {
					Text = label,
					TextSize = 10,
					Font = BOLD,
					TextColor3 = if enabled then P.Frame else P.Dim,
					BackgroundColor3 = color,
					BackgroundTransparency = if enabled then 0 else 0.75,
					AutoButtonColor = enabled,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(50, 18),
				}, line)
				UiKit.round(b, 4)
				if enabled then
					b.Activated:Connect(onClick)
				end
			end
			small("WEAR", -58, P.Gold, preset ~= nil and not worn, function()
				request("PresetApply", index)
			end)
			small("SAVE", -4, P.Teal, true, function()
				request("PresetSave", index)
			end)
		end
		if hint ~= "" then
			text(tipBody, (string.gsub(hint, "^%s+", "")), 12, P.Dim)
		end
		return
	end
	gemLines(gem)
	detailsButton()
	local loadout = GemClient.Profile and GemClient.Profile.Character or {}
	local onKey = nil
	for _, key in { "Q", "E", "R" } do
		local keyed = Tech.surgeGem(loadout, key)
		if keyed and keyed.Id == gem.Id then
			onKey = key
		end
	end
	if gem.Cut and onKey then
		-- On a key already: take it off, or open the Surge Array.
		actionButton(tipActions, "REMOVE FROM " .. onKey, false, function()
			selection = nil
			request("UnsocketSurge", onKey)
		end)
		actionButton(tipActions, "SURGE ARRAY", true, function()
			SurgeArrayUI.open()
		end)
	elseif gem.Cut and bagTab == "Powers" then
		-- Powers: put its surge on a key.
		for _, key in { "Q", "E", "R" } do
			actionButton(tipActions, "SET ON " .. key, true, function()
				request("SocketSurge", gem.Id, key)
			end)
		end
	elseif gem.Cut then
		for _, key in Slots.Order do
			local b = actionButton(tipActions, string.upper(Slots.Definitions[key].Label), true, function()
				request("SocketGem", gem.Id, key)
			end)
			b.TextSize = 11
		end
	else
		text(tipActions, "Gem data is unavailable. Rejoin to refresh your saved equipment.", 13, P.Dim).Size =
			UDim2.new(1, 0, 1, 0)
	end
end

-- The inspector body takes the whole panel unless there are action buttons.
-- Back from an item to the overview card (stats, loadout, presets).
local overview = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 4, 0, -4),
	Size = UDim2.fromOffset(96, 22),
	Text = "◂ OVERVIEW",
	TextSize = 11,
	Font = BOLD,
	TextColor3 = P.Frame,
	BackgroundColor3 = P.Gold,
	Visible = false,
	ZIndex = 5,
}, tooltip)
UiKit.round(overview, 4)
overview.Activated:Connect(function()
	selection = nil
	drawTooltip()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape and not processed and selection ~= nil and gui.Enabled then
		selection = nil
		drawTooltip()
	end
end)

function drawTooltip()
	drawTooltipContent()
	overview.Visible = selection ~= nil
	local hasActions = false
	for _, child in tipActions:GetChildren() do
		if child:IsA("GuiObject") then
			hasActions = true
			break
		end
	end
	-- Size the action area to its rows of buttons (three per row).
	local buttons = 0
	for _, child in tipActions:GetChildren() do
		if child:IsA("GuiObject") then
			buttons += 1
		end
	end
	local rows = math.ceil(buttons / 3)
	local actionHeight = if rows > 0 then rows * 34 - 6 else 0
	tipActions.Size = UDim2.new(1, 0, 0, actionHeight)
	tipBody.Size =
		UDim2.new(tipBody.Size.X.Scale, tipBody.Size.X.Offset, 1, if hasActions then -(actionHeight + 8) else 0)
	tipActions.Visible = hasActions
end
-- The portrait card re-draws once the character (re)loads.
onAvatarChanged = function()
	if selection == nil then
		drawTooltip()
	end
end

local function drawSlot(ui: Slot, slotName: string, gear, class, quality: number?)
	local gem = socketed(slotName)
	-- Enchanted gear is named for its gem, Diablo style, and glows its colour.
	ui.Name.Text = if gear then Crafting.gearName(GemConfig.itemName(gear.Name, gem, slotName), quality) else "Empty"
	ui.Name.TextColor3 = if gem then GemConfig.ElementColors[gem.Element] else P.Text
	local loadout = GemClient.Profile and GemClient.Profile.Character or {}
	local roll = GearRolls.get(loadout, slotName)
	ui.Style.Text = if roll
		then string.upper(GearRolls.Rarities[roll.Rarity].Name)
		else (if gear then string.upper(gear.Style) else "")
	ui.Style.TextColor3 = if roll then GearRolls.Rarities[roll.Rarity].Color else Crafting.Qualities[quality or 1].Color
	-- The weapon occupies both hand slots; the saved shield contributes nothing.
	if slotName == "Shield" and gear and not Classes.heldShield(loadout) then
		ui.Style.Text = "STOWED · 2H"
		ui.Style.TextColor3 = P.Dim
	end
	-- The gem's headline effect (its Size line), e.g. "Heat Shield absorbs 16 damage".
	local headline = gem and GemConfig.lines(gem, slotName, { Affinity = wornAffinities() })[1]
	ui.Bonus.Text = if slotName == "Shield" and not Classes.heldShield(loadout)
		then "Shield and gem inactive while both hands are occupied"
		else if headline then headline.Text else ""
	ui.Bonus.TextColor3 = if gem then GemConfig.ElementColors[gem.Element] else P.Dim
	local stroke = ui.Box:FindFirstChildOfClass("UIStroke") :: UIStroke
	-- The tile glows in its element's colour (its gem's, else the weapon
	-- gem's), stronger and with a thicker edge the rarer the item is.
	local tier = if roll then roll.Rarity else 1
	local glowGem = gem or loadout.WeaponGem
	local glow = if gear and glowGem then GemConfig.ElementColors[glowGem.Element] else nil
	local base = ui.Box:GetAttribute("BaseColor")
	if typeof(base) ~= "Color3" then
		base = ui.Box.BackgroundColor3
		ui.Box:SetAttribute("BaseColor", base)
	end
	ui.Box.BackgroundColor3 = if glow and tier > 1 then base:Lerp(glow, 0.04 + 0.04 * tier) else base
	local rarityColor = if roll then GearRolls.Rarities[roll.Rarity].Color elseif class then class.Color else P.Edge
	stroke.Color = if glow and tier >= 3 then rarityColor:Lerp(glow, 0.45) else rarityColor
	local selectedGear = selection ~= nil and selection.Kind == "Gear" and selection.Slot == slotName
	if selectedGear then
		stroke.Color = P.Gold
	end
	stroke.Thickness = if selectedGear or gem then 2.5 else 1.1 + 0.35 * tier
	local ring = ui.Socket:FindFirstChild("Ring") :: UIStroke
	local shown = if gem then gem.Id else ""
	local redraw = ui.Shown ~= shown
	ui.Shown = shown
	if redraw then
		clear(ui.Socket)
	end
	local chosen = selection and selection.Kind == "Socket" and selection.Slot == slotName
	if gem then
		if redraw then
			GemArt.viewport(ui.Socket, gem, false)
		end
		ring.Color = GemConfig.TierColors[gem.Tier]
		ui.Caption.Text = (GemConfig.enchantment(gem, slotName))
		ui.Caption.TextColor3 = GemConfig.ElementColors[gem.Element]
	else
		if redraw then
			local plus = text(ui.Socket, "+", 18, P.Edge, BOLD)
			plus.Size = UDim2.fromScale(1, 1)
			plus.AutomaticSize = Enum.AutomaticSize.None
			plus.TextXAlignment = Enum.TextXAlignment.Center
		end
		ring.Color = P.Edge
		ui.Caption.Text = "UNATTUNED"
		ui.Caption.TextColor3 = P.Dim
	end
	ring.Thickness = if chosen then 2 else 1
	if chosen then
		ring.Color = P.Gold
	end
end

local RATING_MAX = 140 -- a full bar
local STAT_COLORS = { Health = P.Emerald, Power = P.Gold, Defense = P.Teal, Speed = P.Amethyst }

-- A small drawn icon for each rating: a cross, a bolt, a shield, chevrons.
local function statIcon(parent: Instance, name: string, color: Color3)
	local badge = new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(9, 10),
		Size = UDim2.fromOffset(30, 30),
	}, parent)
	UiKit.round(badge, 15)
	badge.Position = UDim2.fromOffset(9, 9)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.2 }, badge)
	local function bar(x: number, y: number, w: number, h: number, rotation: number?)
		local b = new("Frame", {
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation or 0,
		}, badge)
		UiKit.round(b, 1)
		return b
	end
	if name == "Health" then
		bar(15, 15, 14, 4)
		bar(15, 15, 4, 14)
	elseif name == "Power" then
		bar(17, 10, 4, 10, 25)
		bar(15, 15, 10, 3, 0)
		bar(13, 20, 4, 10, 25)
	elseif name == "Defense" then
		local top = bar(15, 12, 14, 10)
		UiKit.round(top, 3)
		bar(15, 18, 9, 9, 45)
	else
		for _, x in { 11, 18 } do
			bar(x, 12, 3, 8, -40)
			bar(x, 18, 3, 8, 40)
		end
	end
end

-- One rating: icon, name, a big number, what gems add, and a two-part bar.
-- Ratings show as whole numbers (the maths behind them can be fractional).
local function whole(value: number): string
	return tostring(math.floor(value + 0.5))
end

-- One compact rating tile for the header strip: icon, name (with a hint),
-- the number, any gem bonus, and a bar.
local function statTile(parent: Instance, name: string, rating: Classes.Rating, x: number, hint: string?)
	local color = STAT_COLORS[name] or P.Teal
	local total = rating.Base + rating.Bonus
	local gemColor = if rating.Element then GemConfig.ElementColors[rating.Element] else P.Good
	local tile = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(152, 42),
	}, parent)
	UiKit.round(tile, 6)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(color:Lerp(P.Frame, 0.78), P.Frame) }, tile)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.6 }, tile)
	statIcon(tile, name, color)
	local icon = tile:FindFirstChildWhichIsA("Frame")
	if icon then
		icon.Position = UDim2.fromOffset(6, 6)
	end
	local caption = text(
		tile,
		string.upper(name) .. (if hint then "  " .. hint else ""),
		10,
		color:Lerp(Color3.new(1, 1, 1), 0.35),
		BOLD
	)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.Position = UDim2.fromOffset(42, 3)
	caption.Size = UDim2.fromOffset(104, 12)
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	local number = text(tile, whole(total), 18, Color3.new(1, 1, 1), IronUi.Heading)
	number.AutomaticSize = Enum.AutomaticSize.None
	number.Position = UDim2.fromOffset(42, 15)
	number.Size = UDim2.fromOffset(56, 18)
	if rating.Bonus > 0 then
		local pill = new("TextLabel", {
			BackgroundColor3 = gemColor,
			BackgroundTransparency = 0.78,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 16),
			Size = UDim2.fromOffset(0, 15),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = "◆ +" .. whole(rating.Bonus),
			Font = BOLD,
			TextSize = 10,
			TextColor3 = gemColor:Lerp(Color3.new(1, 1, 1), 0.3),
		}, tile)
		UiKit.round(pill, 8)
		new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, pill)
	end
	local track = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 36, 52),
		Position = UDim2.fromOffset(42, 35),
		Size = UDim2.new(1, -48, 0, 3),
	}, tile)
	UiKit.round(track, 2)
	local baseShare = math.min(1, rating.Base / RATING_MAX)
	local base = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(baseShare, 1) }, track)
	UiKit.round(base, 2)
	if rating.Bonus > 0 then
		local extra = new("Frame", {
			BackgroundColor3 = gemColor,
			Position = UDim2.fromScale(baseShare, 0),
			Size = UDim2.fromScale(math.min(1, total / RATING_MAX) - baseShare, 1),
		}, track)
		UiKit.round(extra, 2)
	end
	return total
end

local function drawStats(loadout, class)
	clear(statsCard)
	if not class then
		return
	end
	local ratings = Classes.ratings(loadout)
	local hints = {
		Health = whole(Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)) .. " HP",
		Speed = string.format("%.1f", Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus)),
	}
	local power = 0
	for i, name in Classes.StatNames do
		power += statTile(statsCard, name, ratings[name], (i - 1) * 158, hints[name])
	end
	-- The four ratings together: one number to compare loadouts by.
	local badge = new("Frame", {
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.84,
		Position = UDim2.fromOffset(4 * 158, 0),
		Size = UDim2.fromOffset(112, 42),
	}, statsCard)
	UiKit.round(badge, 6)
	new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.4 }, badge)
	local caption = text(badge, "TOTAL RATING", 10, P.Gold, BOLD)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.Position = UDim2.fromOffset(0, 3)
	caption.Size = UDim2.fromOffset(112, 12)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local score = text(badge, whole(power), 22, Color3.new(1, 1, 1), IronUi.Heading)
	score.AutomaticSize = Enum.AutomaticSize.None
	score.Position = UDim2.fromOffset(0, 15)
	score.Size = UDim2.fromOffset(112, 24)
	score.TextXAlignment = Enum.TextXAlignment.Center
	-- Gems attuned to the worn gear.
	local attuned, color = 0, P.Dim
	for _, slotName in Slots.Order do
		local gem = socketed(slotName)
		if gem then
			attuned += 1
			if color == P.Dim then
				color = GemConfig.ElementColors[gem.Element] or P.Text
			end
		end
	end
	local chip = new("Frame", {
		BackgroundColor3 = P.Frame,
		Position = UDim2.fromOffset(4 * 158 + 120, 0),
		Size = UDim2.fromOffset(104, 42),
	}, statsCard)
	UiKit.round(chip, 6)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5 }, chip)
	local top = text(chip, string.format("◆ %d / %d", attuned, #Slots.Order), 16, color, IronUi.Heading)
	top.AutomaticSize = Enum.AutomaticSize.None
	top.Position = UDim2.fromOffset(0, 4)
	top.Size = UDim2.fromOffset(104, 20)
	top.TextXAlignment = Enum.TextXAlignment.Center
	local bottom = text(chip, "GEMS ATTUNED", 9, P.Dim, BOLD)
	bottom.AutomaticSize = Enum.AutomaticSize.None
	bottom.Position = UDim2.fromOffset(0, 25)
	bottom.Size = UDim2.fromOffset(104, 12)
	bottom.TextXAlignment = Enum.TextXAlignment.Center
end

-- Gem dragging ---------------------------------------------------------------------------
-- IgnoreGuiInset is true; screen input and AbsolutePosition share pixel coordinates.
-- The ghost lives outside the scaled panel so it tracks the pointer at every resolution.
local drag = nil
local dragGhost = new("Frame", {
	Name = "DraggedGem",
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.15,
	Size = UDim2.fromOffset(58, 58),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
	Active = false,
	ZIndex = 100,
}, gui)
UiKit.round(dragGhost, 5)
new("UIStroke", { Color = P.Gold, Thickness = 2 }, dragGhost)
local dragHint = text(dragGhost, "", 12, P.Gold, BOLD)
dragHint.Position = UDim2.fromOffset(-91, 66)
dragHint.Size = UDim2.fromOffset(240, 44)
dragHint.AutomaticSize = Enum.AutomaticSize.None
dragHint.TextXAlignment = Enum.TextXAlignment.Center
dragHint.ZIndex = 102

local function ownedGem(id)
	for _, gem in (GemClient.Profile and GemClient.Profile.Gems) or {} do
		if gem.Id == id then
			return gem
		end
	end
	return nil
end

local function dropTargetAt(point)
	local loadout = GemClient.Profile and GemClient.Profile.Character or {}
	for _, key in Slots.Order do
		local target = equipmentSlots[key].DropTarget
		local at, size = target.AbsolutePosition, target.AbsoluteSize
		if
			loadout[key]
			and point.X >= at.X
			and point.Y >= at.Y
			and point.X < at.X + size.X
			and point.Y < at.Y + size.Y
		then
			return key
		end
	end
	return nil
end

local function cancelDrag()
	local previous = drag
	drag = nil
	if previous and previous.Active then
		grid.ScrollingEnabled = previous.ScrollingEnabled
		suppressClickUntil = os.clock() + 0.2
	end
	dragGhost.Visible = false
	local art = dragGhost:FindFirstChildOfClass("ViewportFrame")
	if art then
		art:Destroy()
	end
	for _, ui in equipmentSlots do
		ui.DropTarget.Visible = false
	end
	boardHint.Text = "SURGE ARRAY\nQ · E · R  [L]"
end

local function moveDrag(point)
	local current = drag
	if not current then
		return
	end
	if not gui.Enabled or not current.Cell.Parent or not ownedGem(current.Gem.Id) then
		cancelDrag()
		return
	end
	current.Point = point
	if not current.Active then
		if (point - current.Start).Magnitude < 8 then
			return
		end
		-- A swipe scrolls the backpack; hold first to pick up a gem on touch.
		if current.Touch and os.clock() - current.Began < 0.25 then
			cancelDrag()
			return
		end
		current.Active = true
		current.ScrollingEnabled = grid.ScrollingEnabled
		grid.ScrollingEnabled = false
		local art = GemArt.viewport(dragGhost, current.Gem, false)
		art.ZIndex = 101
		dragGhost.Visible = true
		boardHint.Text = "DROP GEM\nTO ENCHANT"
	end
	local target = dropTargetAt(point)
	current.Target = target
	dragGhost.Position = UDim2.fromOffset(point.X, point.Y - (if current.Touch then 45 else 0))
	for key, ui in equipmentSlots do
		local loadout = GemClient.Profile and GemClient.Profile.Character or {}
		ui.DropTarget.Visible = loadout[key] ~= nil
		ui.DropTarget.BackgroundTransparency = if key == target then 0.65 else 0.93
		local stroke = ui.DropTarget:FindFirstChildOfClass("UIStroke")
		stroke.Color = if key == target then P.Gold else P.Teal
		stroke.Thickness = if key == target then 3 else 1
	end
	if target then
		dragHint.Text = "ENCHANT "
			.. string.upper(Slots.Definitions[target].Label)
			.. (if socketed(target) then "\nOld gem returns to backpack" else "\nRelease to bind gem")
	else
		dragHint.Text = "Drop on equipment to enchant"
	end
end

local function beginDrag(cell, gem, input)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if drag or enchantPending or not gui.Enabled or not gem.Cut or not ownedGem(gem.Id) then
		return
	end
	local point = if touch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
	drag = {
		Cell = cell,
		Gem = gem,
		Input = input,
		Touch = touch,
		Start = point,
		Point = point,
		Began = os.clock(),
		Active = false,
	}
end

UserInputService.InputChanged:Connect(function(input)
	if not drag then
		return
	end
	if drag.Touch then
		if input == drag.Input then
			moveDrag(Vector2.new(input.Position.X, input.Position.Y))
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		moveDrag(UserInputService:GetMouseLocation())
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local current = drag
	if not current then
		return
	end
	if
		(current.Touch and input ~= current.Input)
		or (not current.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1)
	then
		return
	end
	if input.UserInputState == Enum.UserInputState.Cancel then
		cancelDrag()
		return
	end
	local point = if current.Touch
		then Vector2.new(input.Position.X, input.Position.Y)
		else UserInputService:GetMouseLocation()
	-- Only a gesture that crossed the drag threshold can submit an enchantment.
	local target = if current.Active and gui.Enabled then dropTargetAt(point) else nil
	local gem = ownedGem(current.Gem.Id)
	cancelDrag()
	if target and gem and gem.Cut then
		selection = { Kind = "Socket", Slot = target }
		request("SocketGem", gem.Id, target)
		CharacterUI.refresh()
	end
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape then
		cancelDrag()
	end
end)
UserInputService.WindowFocusReleased:Connect(cancelDrag)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not gui.Enabled then
		cancelDrag()
	end
end)

-- Stones are 3D models, so only build the ones scrolled into view.
local pending: { [Frame]: any } = {}
local function buildVisible()
	local top = grid.AbsolutePosition.Y - CELL
	local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y + CELL
	for cell, gem in pending do
		if not cell.Parent then
			pending[cell] = nil
		elseif cell.AbsolutePosition.Y < bottom and cell.AbsolutePosition.Y + CELL > top then
			pending[cell] = nil
			GemArt.viewport(cell, gem, false)
		end
	end
end

-- Cells are rebuilt only when the gems themselves change; picking a gem
-- just moves the highlight, so its 3D stones aren't built again.
local gridKey = ""
local cellsById: { [string]: { Cell: TextButton, Stroke: UIStroke, Gem: any } } = {}

local function highlight()
	for id, entry in cellsById do
		local chosen = selection ~= nil and selection.Kind == "Gem" and selection.Gem.Id == id
		entry.Cell.BackgroundColor3 = if chosen then Color3.fromRGB(52, 44, 32) else P.Slot
		entry.Stroke.Color = if chosen then P.Gold else GemConfig.TierColors[entry.Gem.Tier]
		entry.Stroke.Thickness = if chosen then 2.5 else 1.2
		entry.Stroke.Transparency = if chosen then 0 else 0.35
	end
end

-- The pouch's gems that pass the element filter, best first.
local function filteredGems(profile, filter: string)
	local gems = {}
	for _, gem in profile.Gems do
		if filter == "All" or gem.Element == filter then
			table.insert(gems, gem)
		end
	end
	table.sort(gems, function(a, b)
		return GemConfig.value(a) > GemConfig.value(b)
	end)
	return gems
end

local function drawGrid(profile)
	local filter = bagFilter.Gems
	local gems = filteredGems(profile, filter)
	setTabCount("Gems", #profile.Gems)
	tabButtons.Gems.Count.Text = string.format("%d/%d", #profile.Gems, Config.MaxGems)
	gemsEmpty.Text = if #profile.Gems == 0
		then "No gems yet.\nMine rocks at the Outpost to find some."
		elseif #gems == 0 then string.format("No %s gems in your bag.", GemConfig.ElementLabels[filter] or filter)
		else ""
	gemsEmpty.Visible = #gems == 0
	local ids = { filter }
	for i, gem in gems do
		ids[i] = gem.Id .. ":" .. tostring(gem.Cut)
	end
	local key = table.concat(ids, ",")
	if key == gridKey then
		highlight()
		return
	end
	gridKey = key
	cancelDrag()
	clear(grid)
	table.clear(pending)
	table.clear(cellsById)
	-- Empty cells fill out the grid so it always reads as a bag.
	local cells = if #gems == 0 then 0 else math.max(#gems, COLUMNS * 5)
	cells = math.ceil(cells / COLUMNS) * COLUMNS
	for i = 1, cells do
		local gem = gems[i]
		local cell = new("TextButton", {
			Text = "",
			AutoButtonColor = gem ~= nil,
			BackgroundColor3 = P.Slot,
			LayoutOrder = i,
		}, grid)
		UiKit.round(cell, 1)
		local stroke = new("UIStroke", {
			Color = Color3.fromRGB(44, 38, 30),
			Thickness = 1.2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, cell)
		if gem then
			local grade = text(cell, "Q" .. tostring(gem.Cut or 0), 11, P.Gold, BOLD)
			grade.Position = UDim2.fromOffset(3, CELL - 13)
			grade.ZIndex = 3
			-- Its element at a glance, top right.
			local pip = new("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = GemConfig.ElementColors[gem.Element] or P.Dim,
				ZIndex = 3,
			}, cell)
			UiKit.round(pip, 4)
			new("UIStroke", { Color = P.Frame, Thickness = 1 }, pip)
			if not gem.Cut then
				local rough = text(cell, "R", 11, P.Dim, BOLD)
				rough.Position = UDim2.fromOffset(4, 2)
				rough.ZIndex = 3
			end
			pending[cell] = gem
			cellsById[gem.Id] = { Cell = cell, Stroke = stroke, Gem = gem }
			cell.InputBegan:Connect(function(input)
				beginDrag(cell, gem, input)
			end)
			cell.Activated:Connect(function()
				if os.clock() < suppressClickUntil or (drag and drag.Active) then
					return
				end
				selection = { Kind = "Gem", Gem = gem }
				CharacterUI.refresh()
			end)
		end
	end
	highlight()
	task.defer(buildVisible)
end

-- Stored equipment data ---------------------------------------------------------------
local function storedEquipment(profile)
	local loadout = profile.Character or {}
	-- Picking a socket or a gem opens the Gems tab (once per pick).
	local pick = selection and (selection.Kind == "Socket" or selection.Kind == "Gem") and selection or nil
	local fresh = pick ~= nil and pick ~= lastPick
	lastPick = pick
	if fresh and bagTab == "Equipment" then
		showBag("Gems")
	end
	local items = {}
	for order, slotName in Slots.Order do
		local kind = Slots.Definitions[slotName].Kind
		for id, quality in (profile.Owned and profile.Owned[kind]) or {} do
			local gear = loadout.Class and Classes.gear(loadout.Class, kind, id)
			if gear and id ~= loadout[slotName] then
				local roll = GearRolls.get(loadout, slotName, id)
				table.insert(items, {
					Id = id,
					Slot = slotName,
					Order = order,
					Gear = gear,
					Quality = quality,
					Rarity = if roll then roll.Rarity else 1,
					Gem = loadout.ItemGems and loadout.ItemGems[slotName] and loadout.ItemGems[slotName][id],
				})
			end
		end
	end
	table.sort(items, function(a, b)
		if a.Order ~= b.Order then
			return a.Order < b.Order
		end
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		return a.Id < b.Id
	end)
	return items
end

-- Stored equipment drawing ------------------------------------------------------------
-- Ask the server for previews when the spare items change (or on opening).
local previewSignature = ""
local previewPending = false
local previewRetries = 0
local function requestPreviews(profile, force: boolean?)
	local parts = {}
	for _, item in storedEquipment(profile) do
		local gem = item.Gem
		table.insert(
			parts,
			string.format(
				"%s|%s|%d|%d|%s",
				item.Slot,
				item.Id,
				item.Quality or 1,
				item.Rarity,
				gem and gem.Element or "-"
			)
		)
	end
	local signature = table.concat(parts, ",")
	if previewPending or (signature == previewSignature and not force) then
		return
	end
	previewSignature = signature
	previewPending = true
	task.spawn(function()
		local result = GemClient.request("GearPreviews")
		previewPending = false
		if result.Ok and result.Done then
			previewRetries = 0
		else
			-- Busy or rate limited: try again shortly (a few times).
			previewSignature = ""
			previewRetries += 1
			if previewRetries <= 5 then
				task.delay(2, function()
					if GemClient.Profile then
						requestPreviews(GemClient.Profile)
					end
				end)
			end
		end
	end)
end

local function drawEquipmentInventory(profile)
	local all = storedEquipment(profile)
	local filter = bagFilter.Equipment
	local items = {}
	for _, item in all do
		if filter == "All" or item.Slot == filter then
			table.insert(items, item)
		end
	end
	setTabCount("Equipment", #all)
	equipmentEmpty.Text = if #all == 0
		then "No spare gear yet.\nWin duels and dungeons, or trade at PROBE-7."
		else string.format(
			"No spare %s.",
			string.lower(Slots.Definitions[filter] and Slots.Definitions[filter].Label or filter)
		)
	equipmentEmpty.Visible = #items == 0
	local scrollPosition = equipmentGrid.CanvasPosition
	clear(equipmentGrid)
	for index, item in items do
		local color = GearRolls.Rarities[item.Rarity].Color
		local selected = selection
			and selection.Kind == "Inventory"
			and selection.Id == item.Id
			and selection.Slot == item.Slot
		local card = new(
			"TextButton",
			{ Text = "", AutoButtonColor = false, BackgroundColor3 = P.Slot, LayoutOrder = index },
			equipmentGrid
		)
		UiKit.round(card, 3)
		new("UIStroke", {
			Color = if selected then P.Gold else color,
			Thickness = if selected then 2.5 else 1,
			Transparency = if selected then 0 else 0.35,
		}, card)
		-- The item itself, in 3D (built by the server); the drawn silhouette
		-- stands in until the preview arrives.
		local stage = new("Frame", {
			BackgroundColor3 = color:Lerp(P.Frame, 0.82),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(108, 60),
			ClipsDescendants = true,
		}, card)
		UiKit.round(stage, 2)
		local view = new("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(185, 190, 210),
			LightColor = Color3.fromRGB(255, 235, 201),
			LightDirection = Vector3.new(-0.4, -1, -0.6),
		}, stage)
		local preview = previewFor(item.Slot, item.Id)
		local drawn = false
		if preview then
			local parts = {}
			for _, part in preview:GetChildren() do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
			drawn = frameGear(view, item.Slot, parts, function(part)
				return part:GetAttribute("Anchor") or ""
			end, function(part)
				return part.CFrame
			end)
		end
		if not drawn then
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(38, 34),
			}, stage)
			equipmentIcon(holder, item.Slot, item.Gear, color)
		end
		local category = text(stage, string.upper(Slots.Definitions[item.Slot].Label), 10, color, BOLD)
		category.Position = UDim2.fromOffset(5, 3)
		category.Size = UDim2.fromOffset(90, 13)
		category.AutomaticSize = Enum.AutomaticSize.None
		category.ZIndex = 3
		local name = text(card, item.Gear.Name, 12, P.Text, BOLD)
		name.Position = UDim2.fromOffset(6, 67)
		name.Size = UDim2.fromOffset(104, 22)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local rarity = text(card, string.upper(GearRolls.Rarities[item.Rarity].Name), 10, color, BOLD)
		rarity.Position = UDim2.fromOffset(6, 89)
		rarity.Size = UDim2.fromOffset(104, 13)
		rarity.AutomaticSize = Enum.AutomaticSize.None
		if item.Gem then
			local marker = text(card, "◆", 10, GemConfig.ElementColors[item.Gem.Element], BOLD)
			marker.Position = UDim2.fromOffset(98, 6)
			marker.Size = UDim2.fromOffset(12, 12)
			marker.AutomaticSize = Enum.AutomaticSize.None
			marker.ZIndex = 4
		end
		IronUi.highlight(card)
		card.Activated:Connect(function()
			if os.clock() < suppressClickUntil or (drag and drag.Active) then
				return
			end
			selection = { Kind = "Inventory", Slot = item.Slot, Id = item.Id }
			CharacterUI.refresh()
		end)
	end
	equipmentGrid.CanvasPosition = scrollPosition
end

-- Powers ------------------------------------------------------------------------------
-- The surge on each gem, as a list: the three on your keys first, then your
-- bag's, strongest first. Picking one shows it; Q / E / R put it on a key.
local ROMAN = { "I", "II", "III" }
local function powerRow(order: number, gem, keyName: string?, onClick: () -> ())
	local surge = gem and Tech.surgeStats(gem)
	local tint = gem and GemConfig.ElementColors[gem.Element] or P.Dim
	local chosen = gem ~= nil and selection ~= nil and selection.Kind == "Gem" and selection.Gem.Id == gem.Id
	local row = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if chosen then Color3.fromRGB(44, 36, 58) else P.Slot,
		Size = UDim2.new(1, -8, 0, 48),
		LayoutOrder = order,
	}, powerList)
	UiKit.round(row, 6)
	new("UIStroke", {
		Color = if chosen then P.Gold elseif gem then GemConfig.TierColors[gem.Tier] or P.Edge else P.Edge,
		Thickness = if chosen then 2 else 1,
		Transparency = if chosen then 0 else 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, row)
	local x = 8
	if keyName then
		local key = text(row, keyName, 14, P.Frame, IronUi.Heading)
		key.AutomaticSize = Enum.AutomaticSize.None
		key.BackgroundTransparency, key.BackgroundColor3 = 0, P.Gold
		key.Position, key.Size = UDim2.fromOffset(x, 12), UDim2.fromOffset(24, 24)
		key.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.round(key, 5)
		x += 32
	end
	local icon = new("Frame", {
		BackgroundColor3 = tint:Lerp(P.Frame, 0.7),
		Position = UDim2.fromOffset(x, 6),
		Size = UDim2.fromOffset(36, 36),
	}, row)
	UiKit.round(icon, 18)
	new("UIStroke", { Color = tint, Thickness = 1.5, Transparency = if gem then 0.1 else 0.6 }, icon)
	local glyph = text(icon, if surge then "◆" else "+", 16, tint, BOLD)
	glyph.AutomaticSize = Enum.AutomaticSize.None
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	if surge then
		SurgeIcons.apply(glyph, surge)
	end
	x += 46
	local name = text(row, if surge then surge.Name else "Empty", 14, if surge then P.Text else P.Dim, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Position, name.Size = UDim2.fromOffset(x, 6), UDim2.new(1, -x - 84, 0, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local detail = text(
		row,
		if surge
			then string.format("%s · Rank %s", Tech.TierNames[surge.Tier] or "", ROMAN[surge.Rank] or "I")
			else "Pick a power below, then press " .. (keyName or "Q"),
		11,
		if surge then P.Dim else P.Dim,
		IronUi.Body
	)
	detail.AutomaticSize = Enum.AutomaticSize.None
	detail.Position, detail.Size = UDim2.fromOffset(x, 25), UDim2.new(1, -x - 84, 0, 16)
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	if gem then
		local element = text(row, string.upper(GemConfig.ElementLabels[gem.Element] or gem.Element), 10, tint, BOLD)
		element.AutomaticSize = Enum.AutomaticSize.None
		element.AnchorPoint = Vector2.new(1, 0)
		element.Position, element.Size = UDim2.new(1, -10, 0, 8), UDim2.fromOffset(80, 14)
		element.TextXAlignment = Enum.TextXAlignment.Right
		local rarity = text(
			row,
			string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier),
			10,
			GemConfig.TierColors[gem.Tier] or P.Dim,
			BOLD
		)
		rarity.AutomaticSize = Enum.AutomaticSize.None
		rarity.AnchorPoint = Vector2.new(1, 0)
		rarity.Position, rarity.Size = UDim2.new(1, -10, 0, 26), UDim2.fromOffset(80, 14)
		rarity.TextXAlignment = Enum.TextXAlignment.Right
	end
	IronUi.highlight(row)
	row.Activated:Connect(onClick)
	return row
end

local function powerHeading(order: number, caption: string)
	local l = text(powerList, caption, 11, P.Gold, BOLD)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.Size = UDim2.new(1, -8, 0, 16)
	l.LayoutOrder = order
	return l
end

local function drawPowers(profile)
	local scrollPosition = powerList.CanvasPosition
	clear(powerList)
	setTabCount("Powers", #profile.Gems)
	if bagTab ~= "Powers" then
		return
	end
	local loadout = profile.Character or {}
	powerHeading(1, "ON YOUR KEYS")
	for i, key in { "Q", "E", "R" } do
		local gem = Tech.surgeGem(loadout, key)
		powerRow(1 + i, gem, key, function()
			if gem then
				selection = { Kind = "Gem", Gem = gem }
				CharacterUI.refresh()
			else
				SurgeArrayUI.open()
			end
		end)
	end
	local gems = filteredGems(profile, bagFilter.Powers)
	table.sort(gems, function(a, b)
		local _, ta, ra = Tech.surgeOf(a)
		local _, tb, rb = Tech.surgeOf(b)
		if ta ~= tb then
			return ta > tb
		end
		if ra ~= rb then
			return ra > rb
		end
		return GemConfig.value(a) > GemConfig.value(b)
	end)
	powerHeading(10, string.format("IN YOUR BAG  ·  %d", #gems))
	for i, gem in gems do
		powerRow(10 + i, gem, nil, function()
			selection = { Kind = "Gem", Gem = gem }
			CharacterUI.refresh()
		end)
	end
	powersEmpty.Visible = #gems == 0
	powersEmpty.Position = UDim2.fromOffset(20, 236)
	powersEmpty.Text = if #profile.Gems == 0
		then "No gems yet. Every gem you mine carries a power."
		else string.format("No %s powers in your bag.", GemConfig.ElementLabels[bagFilter.Powers] or "")
	powerList.CanvasPosition = scrollPosition
end

function CharacterUI.refresh()
	local profile = GemClient.Profile
	-- Owner tools live in the DEV panel (DungeonPlaytest), not the header.
	regenerate.Visible = false
	regenerateGems.Visible = false
	if not profile or not gui.Enabled then
		return
	end
	local loadout = profile.Character or {}
	local class = loadout.Class and Classes.List[loadout.Class]
	title.Text = string.upper(player.DisplayName)
	local sets = Classes.setState(loadout).Active
	local best, bestCount = nil, 0
	for _, family in ArmorFamilies.Order do
		local state = sets[family]
		if state and state.Count > bestCount then
			best, bestCount = family, state.Count
		end
	end
	subtitle.Text = (if class then class.Name else "Miner")
		.. (if best then string.format("  ·  %s set %d/6", best, bestCount) else "")
	subtitle.TextColor3 = if class then class.Color else P.Dim

	-- Keep the selected gem only while it's still in the pouch (or on a key).
	if selection and selection.Kind == "Gem" then
		local still = nil
		for _, gem in profile.Gems do
			if gem.Id == selection.Gem.Id then
				still = gem
			end
		end
		for _, key in { "Q", "E", "R" } do
			local keyed = Tech.surgeGem(profile.Character or {}, key)
			if keyed and keyed.Id == selection.Gem.Id then
				still = keyed
			end
		end
		selection = if still then { Kind = "Gem", Gem = still } else nil
	end

	for _, key in Slots.Order do
		drawSlot(
			equipmentSlots[key],
			key,
			loadout.Class and Classes.gear(loadout.Class, Slots.Definitions[key].Kind, loadout[key]),
			class,
			loadout[key .. "Quality"]
		)
	end
	drawStats(loadout, class)
	drawGrid(profile)
	drawEquipmentInventory(profile)
	drawPowers(profile)
	requestPreviews(profile)
	drawTooltip()
end

-- A tab or filter change redraws just the bag.
redrawBag = function()
	local profile = GemClient.Profile
	if profile and gui.Enabled then
		drawGrid(profile)
		drawEquipmentInventory(profile)
		drawPowers(profile)
	end
end

-- Redraw the spare items as their 3D previews arrive (a burst becomes one redraw).
local previewRedraw = false
local function previewsChanged()
	if previewRedraw then
		return
	end
	previewRedraw = true
	task.delay(0.2, function()
		previewRedraw = false
		if gui.Enabled and GemClient.Profile then
			drawEquipmentInventory(GemClient.Profile)
		end
	end)
end
local function watchPreviews(store: Instance)
	store.ChildAdded:Connect(previewsChanged)
	store.ChildRemoved:Connect(previewsChanged)
	previewsChanged()
end
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("GearPreviews") then
	watchPreviews(playerGui:FindFirstChild("GearPreviews") :: Instance)
end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "GearPreviews" then
		watchPreviews(child)
	end
end)

-- Opening and closing ----------------------------------------------------------------------

type Options = { AtVey: boolean? }

-- Dock into the dashboard without duplicating item models, inventory or input handlers.
-- The modal's scale is detached because the dashboard supplies its own scale.
function CharacterUI.mount(parent: GuiObject, hostGui: ScreenGui, position: UDim2)
	if embedded then
		return
	end
	cancelDrag()
	window.Gui.Enabled = false
	embedded = true
	scale.Parent = nil
	panel.AnchorPoint = Vector2.zero
	panel.Position = position
	panel.Parent = parent
	window.Close.Visible = false
	window.Shade.Visible = false
	gui = hostGui
	dragGhost.Parent = hostGui
	title.Size = UDim2.fromOffset(420, 32)
	subtitle.Size = UDim2.fromOffset(420, 16)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.AutomaticSize = Enum.AutomaticSize.None
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			refreshAvatar()
			CharacterUI.refresh()
		else
			cancelDrag()
		end
	end)
	refreshAvatar()
	CharacterUI.refresh()
end

CharacterUI.cancelDrag = cancelDrag

function CharacterUI.open(options: Options?)
	if embedded then
		if gui.Enabled then
			refreshAvatar()
			CharacterUI.refresh()
		end
		return
	end
	atVey = options ~= nil and options.AtVey == true
	selection = nil
	previewSignature = ""
	gui.Enabled = true
	fit()
	refreshAvatar()
	CharacterUI.refresh()
	scale.Scale *= 0.94
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = scale.Scale / 0.94,
	}):Play()
end

function CharacterUI.close()
	cancelDrag()
	if embedded then
		return
	end
	gui.Enabled = false
	-- Rebuild the grid next time, so unbuilt stones still get drawn.
	gridKey = ""
	table.clear(pending)
	if avatarModel then
		avatarModel:Destroy()
		avatarModel = nil
	end
end

function CharacterUI.toggle()
	if embedded then
		CharacterUI.open()
		return
	end
	if gui.Enabled then
		CharacterUI.close()
	else
		CharacterUI.open()
	end
end

window.Close.Activated:Connect(CharacterUI.close)
window.Shade.Activated:Connect(function()
	if os.clock() >= suppressClickUntil and not (drag and drag.Active) then
		CharacterUI.close()
	end
end)
grid:GetPropertyChangedSignal("CanvasPosition"):Connect(buildVisible)
GemClient.Changed:Connect(CharacterUI.refresh)

-- The server rebuilds gear when sockets change; copy the avatar again.
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "GemsoulGear" then
			task.wait(0.1)
			refreshAvatar()
		end
	end)
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

if not Config.MenuOnly then
	ContextActionService:BindAction("GemsoulCharacter", function(_, state)
		-- Not while the new-player intro is still open.
		if state == Enum.UserInputState.Begin and not player.PlayerGui:FindFirstChild("Intro") then
			CharacterUI.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C)
end

return CharacterUI
