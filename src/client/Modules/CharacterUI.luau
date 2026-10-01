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
local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local SuitTraits = require(ReplicatedStorage.Shared.SuitTraits)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, actionButton, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 1000, 720
local CELL, GAP, COLUMNS = 52, 6, 16

local CharacterUI = {}

type Selection = { Kind: "Gem", Gem: any } | { Kind: "Socket", Slot: string } | { Kind: "Gear", Slot: string }
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
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(112, 128) },
		doll
	)
	local head = text(holder, label, 11, P.Dim, BOLD)
	head.TextXAlignment = Enum.TextXAlignment.Center
	local item = box(holder, UDim2.fromOffset(0, 16), UDim2.fromOffset(112, 88), Color3.fromRGB(30, 22, 30), 2)
	local art = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.fromOffset(102, 52),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, item)
	local name = text(item, "", 10, P.Text, BOLD)
	name.Position = UDim2.fromOffset(5, 56)
	name.Size = UDim2.fromOffset(102, 22)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextXAlignment = Enum.TextXAlignment.Center
	local style = text(item, "", 9, P.Dim)
	style.Position = UDim2.fromOffset(5, 76)
	style.Size = UDim2.fromOffset(102, 11)
	style.AutomaticSize = Enum.AutomaticSize.None
	style.TextXAlignment = Enum.TextXAlignment.Center
	local bonus = text(item, "", 10, P.Dim)
	bonus.Visible = false
	local hit = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(112, 88),
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
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.fromOffset(22, 22),
	}, holder)
	UiKit.round(socket, 5)
	new("UIStroke", { Name = "Ring", Color = P.Edge, Thickness = 1 }, socket)
	IronUi.highlight(socket)
	local caption = text(holder, "", 9, P.Dim)
	caption.Position = UDim2.fromOffset(28, 109)
	caption.Size = UDim2.fromOffset(82, 16)
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
		Size = UDim2.fromOffset(112, 112),
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
	Helmet = Vector2.new(220, 8),
	Armor = Vector2.new(220, 142),
	Boots = Vector2.new(220, 276),
	Weapon = Vector2.new(28, 82),
	Gloves = Vector2.new(28, 250),
	Shield = Vector2.new(412, 82),
}
for _, key in Slots.Order do
	local at = slotPositions[key]
	equipmentSlots[key] = slot(at.X, at.Y, string.upper(Slots.Definitions[key].Label), key)
end
local boardHint = text(doll, "SELECT GEAR\nTO COMPARE", 10, P.Dim, BOLD)
boardHint.Position = UDim2.fromOffset(411, 285)
boardHint.Size = UDim2.fromOffset(112, 46)
boardHint.TextXAlignment = Enum.TextXAlignment.Center
boardHint.AutomaticSize = Enum.AutomaticSize.None

refreshItemArt = function()
	local character = player.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	if not character or not equipment then
		return
	end
	for key, ui in equipmentSlots do
		ui.Art:ClearAllChildren()
		local source = equipment:FindFirstChild(key)
		if source then
			local world = new("WorldModel", {}, ui.Art)
			local model = new("Model", {}, world)
			for _, part in source:GetDescendants() do
				if not part:IsA("BasePart") or part.Transparency >= 1 then
					continue
				end
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				local anchor = weld and weld.Part0
				local anchorName = anchor and anchor.Name or ""
				-- Show one glove/boot and just the chest assembly, keeping thumbnails readable.
				if (key == "Gloves" or key == "Boots") and string.find(anchorName, "Right") then
					continue
				end
				if key == "Armor" and (string.find(anchorName, "Arm") or string.find(anchorName, "Leg")) then
					continue
				end
				local clone = part:Clone()
				for _, child in clone:GetChildren() do
					child:Destroy()
				end
				clone.Anchored = true
				clone.CFrame = character:GetPivot():ToObjectSpace(part.CFrame)
				clone.Parent = model
			end
			if #model:GetChildren() > 0 then
				local frame, size = model:GetBoundingBox()
				local camera = new("Camera", { FieldOfView = 30 }, ui.Art)
				local direction = if key == "Shield"
					then Vector3.new(1, 0.15, -0.1).Unit
					else Vector3.new(0.22, 0.1, -1).Unit
				local distance = math.max(size.X, size.Y, size.Z) * 2.3 + 0.2
				camera.CFrame = CFrame.lookAt(frame.Position + direction * distance, frame.Position)
				ui.Art.CurrentCamera = camera
			end
		end
	end
end

local statsBox = box(panel, UDim2.fromOffset(592, 340), UDim2.fromOffset(384, 158), P.Inset)
UiKit.pad(statsBox, 12)
local statsList = new("ScrollingFrame", {
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 2,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Size = UDim2.new(0.42, 0, 1, 0),
}, statsBox)
UiKit.list(statsList, 4)
local enchantList = new("ScrollingFrame", {
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Position = UDim2.new(0.46, 0, 0, 0),
	Size = UDim2.new(0.54, 0, 1, 0),
}, statsBox)
UiKit.list(enchantList, 5)

-- Backpack and inspector ------------------------------------------------------

local invTitle = text(panel, "", 13, P.Dim, BOLD)
invTitle.Position = UDim2.fromOffset(28, 516)
invTitle.Size = UDim2.fromOffset(940, 18)

local gridBox = box(panel, UDim2.fromOffset(24, 538), UDim2.fromOffset(952, 158), Color3.fromRGB(10, 9, 8))
local grid = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
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

local tooltip = box(panel, UDim2.fromOffset(592, 82), UDim2.fromOffset(384, 244), P.Inset)
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

local function bonusText(gem, slotName: string): string
	local parts = {}
	local bonuses = GemConfig.statBonuses(gem, slotName)
	for _, stat in Classes.StatNames do
		if bonuses[stat] then
			table.insert(parts, string.format("+%d %s", bonuses[stat], stat))
		end
	end
	return table.concat(parts, "  ")
end

local function gemLines(gem)
	local tierColor = GemConfig.TierColors[gem.Tier]
	text(tipBody, GemConfig.shade(gem).Name, 18, tierColor, BOLD)
	local state = if not gem.Cut then "ROUGH" elseif gem.Cut >= 10 then "GEM MINT" else "CUT " .. gem.Cut
	text(
		tipBody,
		string.format(
			"%s %s  |  %s",
			string.upper(GemConfig.TierLabels[gem.Tier]),
			string.upper(GemConfig.elementName(gem.Element)),
			state
		),
		12,
		GemConfig.ElementColors[gem.Element],
		BOLD
	)
	text(
		tipBody,
		string.format(
			"Size %d   Clarity %d   Cut %s   |   Potency %d   |   %d coins",
			gem.Size,
			gem.Clarity,
			if gem.Cut then tostring(gem.Cut) else "-",
			GemConfig.potency(gem),
			GemConfig.value(gem)
		),
		12,
		P.Text
	)
	for _, slotName in Slots.Order do
		local name, effect = GemConfig.enchantment(gem, slotName)
		local heading = text(tipBody, string.format("IN %s: %s", string.upper(slotName), name), 12, P.Gold, BOLD)
		heading.TextColor3 = GemConfig.ElementColors[gem.Element]
		text(tipBody, string.format("%s.  %s", effect, bonusText(gem, slotName)), 12, P.Dim)
	end
	GemArt.viewport(tipArt, gem, true)
	tooltipStroke.Color = tierColor
end

local function drawTooltip()
	local showArt = selection ~= nil and selection.Kind ~= "Gear"
	tipArt.Visible = showArt
	tipBody.Position = UDim2.fromOffset(if showArt then 66 else 0, 0)
	tipBody.Size = UDim2.new(1, if showArt then -66 else 0, 1, -72)
	clear(tipBody)
	clear(tipActions)
	clear(tipArt)
	tooltipStroke.Color = P.Edge
	local hint = if atVey or Config.MenuOnly then "" else "  Sockets can be changed at Vey's Arcanum (east road)."

	if selection and selection.Kind == "Gear" then
		local slotName = selection.Slot
		local kind = Slots.Definitions[slotName].Kind
		local profile = GemClient.Profile
		local loadout = profile and profile.Character or {}
		local owned = profile and profile.Owned and profile.Owned[kind] or {}
		text(tipBody, "EQUIPPED " .. string.upper(Slots.Definitions[slotName].Label), 18, P.Gold, BOLD)
		local equippedItem = Classes.gear(loadout.Class, kind, loadout[slotName])
		if equippedItem then
			text(tipBody, equippedItem.Passive.Name .. ": " .. equippedItem.Passive.Text, 12, P.Gold)
			if equippedItem.ProposedBuff and not equippedItem.BuffReady then
				text(tipBody, "Planned signature: " .. equippedItem.ProposedBuff, 11, P.Dim)
			end
		end
		if slotName == "Helmet" and loadout.Helmet then
			local helmetRoll = GearRolls.get(loadout, "Helmet")
			local traits = if helmetRoll
				then GearRolls.appearance(helmetRoll)
				else SuitTraits.forSuit(player.UserId, loadout.Helmet)
			text(tipBody, traits.HelmetName .. " • " .. traits.HelmetRarity, 11, P.Dim)
			if traits.VisorName then
				text(tipBody, "Visor: " .. traits.VisorName .. " (cosmetic)", 11, P.Teal)
			end
		end
		local roll = GearRolls.get(loadout, slotName)
		if roll then
			local bonuses = {}
			for stat, amount in roll.Stats do
				table.insert(bonuses, "+" .. amount .. " " .. stat)
			end
			table.sort(bonuses)
			text(
				tipBody,
				GearRolls.Rarities[roll.Rarity].Name .. " • " .. table.concat(bonuses, ", "),
				12,
				GearRolls.Rarities[roll.Rarity].Color
			)
		end
		local any = false
		for _, gear in (loadout.Class and Classes.List[loadout.Class] or {})[kind] or {} do
			local quality = owned[gear.Id]
			if quality then
				any = true
				local isOn = loadout[slotName] == gear.Id
				local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, tipBody)
				local label = text(
					row,
					Crafting.gearName(gear.Name, quality) .. "  (" .. string.lower(gear.Style) .. ")",
					13,
					Crafting.Qualities[quality].Color,
					BOLD
				)
				label.AutomaticSize = Enum.AutomaticSize.None
				label.Size = UDim2.new(1, -96, 1, 0)
				label.TextYAlignment = Enum.TextYAlignment.Center
				if isOn then
					local tag = text(row, "EQUIPPED", 11, P.Dim, BOLD)
					tag.AutomaticSize = Enum.AutomaticSize.None
					tag.Position = UDim2.new(1, -90, 0, 0)
					tag.Size = UDim2.new(0, 90, 1, 0)
					tag.TextYAlignment = Enum.TextYAlignment.Center
				else
					local b = actionButton(row, "EQUIP", false, function()
						request("EquipGear", kind, gear.Id)
					end)
					b.AnchorPoint = Vector2.new(1, 0)
					b.Position = UDim2.new(1, 0, 0, 0)
					b.Size = UDim2.fromOffset(0, 28)
				end
			end
		end
		if not any then
			text(tipBody, "No reserve equipment. Recover gear on lunar expeditions.", 13, P.Dim)
		end
		text(tipBody, "Recover equipment in Moon Mine caches or visit the Market [T].", 12, P.Dim)
		return
	end

	if selection and selection.Kind == "Socket" then
		local slotName = selection.Slot
		local gem = socketed(slotName)
		if gem then
			gemLines(gem)
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
		text(tipBody, "INSPECT", 18, P.Gold, BOLD)
		text(
			tipBody,
			"Drag a gem onto any equipped item or its socket to enchant it. On touch, hold the gem briefly before dragging. You can also select a gem and use the slot buttons."
				.. hint,
			13,
			P.Dim
		)
		return
	end
	gemLines(gem)
	if gem.Cut then
		for _, key in Slots.Order do
			local b = actionButton(tipActions, string.upper(Slots.Definitions[key].Label), true, function()
				request("SocketGem", gem.Id, key)
			end)
			b.TextSize = 11
		end
	else
		text(tipActions, "Gem data is unavailable. Rejoin to refresh your saved equipment.", 12, P.Dim).Size =
			UDim2.new(1, 0, 1, 0)
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
	ui.Bonus.Text = if gem then (string.gsub(bonusText(gem, slotName), "  ", "\n")) else ""
	ui.Bonus.TextColor3 = if gem then GemConfig.ElementColors[gem.Element] else P.Dim
	local stroke = ui.Box:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if roll then GearRolls.Rarities[roll.Rarity].Color elseif class then class.Color else P.Edge
	local selectedGear = selection ~= nil and selection.Kind == "Gear" and selection.Slot == slotName
	if selectedGear then
		stroke.Color = P.Gold
	end
	stroke.Thickness = if selectedGear or gem then 2.5 else 1.5
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

local function statRow(name: string, rating: Classes.Rating, color: Color3)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18) }, statsList)
	local caption = text(row, string.upper(name), 11, P.Dim, BOLD)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.Size = UDim2.new(0, 60, 1, 0)
	local total = rating.Base + rating.Bonus
	local bonusColor = if rating.Element then GemConfig.ElementColors[rating.Element] else P.Good
	local number = text(row, tostring(total), 13, if rating.Bonus > 0 then bonusColor else P.Text, BOLD)
	number.AutomaticSize = Enum.AutomaticSize.None
	number.Position = UDim2.fromOffset(60, 0)
	number.Size = UDim2.new(0, 30, 1, 0)
	local track = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(46, 40, 34),
		Position = UDim2.fromOffset(94, 5),
		Size = UDim2.new(1, -94, 0, 8),
	}, row)
	UiKit.round(track, 3)
	local base = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(math.min(1, rating.Base / RATING_MAX), 1),
	}, track)
	UiKit.round(base, 3)
	if rating.Bonus > 0 then
		local extra = new("Frame", {
			BackgroundColor3 = bonusColor,
			Position = UDim2.fromScale(math.min(1, rating.Base / RATING_MAX), 0),
			Size = UDim2.fromScale(math.min(1, total / RATING_MAX) - math.min(1, rating.Base / RATING_MAX), 1),
		}, track)
		UiKit.round(extra, 3)
	end
end

local function drawStats(loadout, class)
	clear(statsList)
	clear(enchantList)
	text(statsList, "COMBAT RATINGS", 12, P.Gold, BOLD)
	if class then
		local ratings = Classes.ratings(loadout)
		for _, name in Classes.StatNames do
			statRow(name, ratings[name], class.Color)
		end
		text(
			statsList,
			string.format(
				"Max health %d  |  Walk speed %.1f",
				Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus),
				Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus)
			),
			11,
			P.Text,
			BOLD
		)
		text(statsList, class.Resource, 11, P.Dim)
	end
	text(enchantList, "ACTIVE ATTUNEMENTS", 12, P.Gold, BOLD)
	local any = false
	for _, slotName in Slots.Order do
		local gem = socketed(slotName)
		if gem then
			any = true
			local name, effect = GemConfig.enchantment(gem, slotName)
			local color = GemConfig.ElementColors[gem.Element]
			text(enchantList, string.format("%s  (%s)", name, string.lower(slotName)), 13, color, BOLD)
			text(enchantList, effect .. ".  " .. bonusText(gem, slotName), 11, P.Text)
		end
	end
	if not any then
		text(enchantList, "Each equipment item has its own gem socket.", 12, P.Dim)
	end
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
	boardHint.Text = "SELECT GEAR\nTO COMPARE"
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

local function drawGrid(profile)
	local gems = table.clone(profile.Gems)
	table.sort(gems, function(a, b)
		return GemConfig.value(a) > GemConfig.value(b)
	end)
	invTitle.Text = string.format("GEM BACKPACK   %d / %d   |   %d COINS", #gems, Config.MaxGems, profile.Coins)
	local ids = {}
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
	local cells = math.max(#gems, COLUMNS * 3)
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
			local grade = text(cell, "Q" .. tostring(gem.Cut or 0), 9, P.Gold, BOLD)
			grade.Position = UDim2.fromOffset(3, CELL - 13)
			grade.ZIndex = 3
			if not gem.Cut then
				local rough = text(cell, "R", 10, P.Dim, BOLD)
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

function CharacterUI.refresh()
	local profile = GemClient.Profile
	regenerate.Visible = profile ~= nil and profile.CanRegenerateEquipment == true
	regenerateGems.Visible = regenerate.Visible
	if not profile or not gui.Enabled then
		return
	end
	local loadout = profile.Character or {}
	local class = loadout.Class and Classes.List[loadout.Class]
	title.Text = string.upper(player.DisplayName)
	subtitle.Text = if class then string.format("%s  |  %s", class.Name, class.Role) else "No class chosen"
	subtitle.TextColor3 = if class then class.Color else P.Dim

	-- Keep the selected gem only while it's still in the pouch.
	if selection and selection.Kind == "Gem" then
		local still = nil
		for _, gem in profile.Gems do
			if gem.Id == selection.Gem.Id then
				still = gem
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
	drawTooltip()
end

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
