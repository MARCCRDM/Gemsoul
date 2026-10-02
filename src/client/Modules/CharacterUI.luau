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
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemArt = require(script.Parent.GemArt)
local SurgeArrayUI = require(script.Parent.SurgeArrayUI)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

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

-- Draws one item's parts in a viewport, framed for a thumbnail. `anchorOf`
-- names the body part a piece is worn on; `placeOf` gives its CFrame
-- relative to the wearer.
local function frameGear(
	view: ViewportFrame,
	key: string,
	parts: { BasePart },
	anchorOf: (BasePart) -> string,
	placeOf: (BasePart) -> CFrame
)
	view:ClearAllChildren()
	local world = new("WorldModel", {}, view)
	local model = new("Model", {}, world)
	for _, part in parts do
		if part.Transparency >= 1 then
			continue
		end
		local anchorName = anchorOf(part)
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
		clone.CFrame = placeOf(part)
		clone.Parent = model
	end
	if #model:GetChildren() > 0 then
		local frame, size = model:GetBoundingBox()
		local camera = new("Camera", { FieldOfView = 30 }, view)
		-- Shields and guns (held pointing forward) read best from the side.
		local sideways = key == "Shield" or (key == "Weapon" and size.Z > size.Y)
		local direction = if sideways then Vector3.new(1, 0.15, -0.1).Unit else Vector3.new(0.22, 0.1, -1).Unit
		local distance = math.max(size.X, size.Y, size.Z) * 2.3 + 0.2
		camera.CFrame = CFrame.lookAt(frame.Position + direction * distance, frame.Position)
		view.CurrentCamera = camera
		return true
	end
	return false
end

-- 3D previews of spare items arrive from the server in a hidden ScreenGui.
local function previewStore(): Instance?
	return player:FindFirstChildOfClass("PlayerGui")
		and (player:FindFirstChildOfClass("PlayerGui") :: PlayerGui):FindFirstChild("GearPreviews")
end

local function previewFor(slotName: string, id: string): Instance?
	local store = previewStore()
	return store and store:FindFirstChild(slotName .. "|" .. id)
end

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

local statsBox = box(panel, UDim2.fromOffset(592, 330), UDim2.fromOffset(384, 168), P.Inset)
local statsCard = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 1, -14),
}, statsBox)

-- Backpack and inspector ------------------------------------------------------

local invTitle = text(panel, "", 13, P.Dim, BOLD)
invTitle.Position = UDim2.fromOffset(996, 82)
invTitle.Size = UDim2.fromOffset(380, 18)

local gridBox = box(panel, UDim2.fromOffset(992, 104), UDim2.fromOffset(384, 190), Color3.fromRGB(10, 9, 8))
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

-- Spare equipment uses the existing saved ownership records; worn items stay above.
local equipmentTitle = text(panel, "EQUIPMENT INVENTORY", 13, P.Gold, BOLD)
equipmentTitle.Position = UDim2.fromOffset(996, 306)
equipmentTitle.Size = UDim2.fromOffset(380, 18)
local equipmentBox = box(panel, UDim2.fromOffset(992, 328), UDim2.fromOffset(384, 170), P.Frame)
local equipmentGrid = new("ScrollingFrame", {
	Name = "StoredEquipment",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = P.Edge,
}, equipmentBox)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(116, 108),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, equipmentGrid)
local equipmentEmpty =
	text(equipmentBox, "No spare equipment yet.\nRecover loot in the Moon Mine or visit the Market.", 13, P.Dim)
equipmentEmpty.Position = UDim2.fromOffset(20, 38)
equipmentEmpty.Size = UDim2.new(1, -40, 0, 70)
equipmentEmpty.AutomaticSize = Enum.AutomaticSize.None
equipmentEmpty.TextXAlignment = Enum.TextXAlignment.Center
equipmentEmpty.ZIndex = 3

local tooltip = box(panel, UDim2.fromOffset(592, 82), UDim2.fromOffset(384, 240), P.Inset)
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
		local id = Tech.surgeOf(gem)
		local surge = id and Tech.Catalog[id]
		local gist = text(
			info,
			elementGist(gem.Element) .. "." .. (if surge then " Casts " .. surge.Name .. " as a Gem Surge." else ""),
			12,
			P.Text
		)
		gist.AutomaticSize = Enum.AutomaticSize.None
		gist.Position, gist.Size = UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 58)
		gist.TextYAlignment = Enum.TextYAlignment.Top
		text(
			tipBody,
			string.format(
				"Sells for %d coins  ·  %s",
				GemConfig.value(gem),
				if gem.Cut then "ready to socket" else "rough"
			),
			12,
			P.Dim
		)
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
	text(
		tipBody,
		string.format("%s   |   %s   |   Sells for %d coins", state, GemConfig.shade(gem).Name, GemConfig.value(gem)),
		12,
		P.Text
	)
	local color = GemConfig.ElementColors[gem.Element]
	-- The surge this gem casts from a Surge Array slot.
	local surge = Tech.surgeLines(gem)
	if #surge > 0 then
		text(tipBody, string.upper(surge[1]), 12, P.Gold, BOLD)
		text(tipBody, table.concat(surge, "  ·  ", 2), 12, P.Text)
	end
	local affinity = wornAffinities()
	for _, section in { { "Weapon", "IN A WEAPON" }, { "Armor", "IN ARMOR OR SHIELD" } } do
		local name = GemConfig.enchantment(gem, section[1])
		text(tipBody, string.format("%s  ·  %s", section[2], string.upper(name)), 12, color, BOLD)
		effectRows(tipBody, gem, section[1], color, affinity)
		if section[1] == "Weapon" then
			-- PvP tag: the reduced numbers a player target feels.
			local pvp = {}
			for _, line in GemConfig.lines(gem, "Weapon", { Affinity = affinity, PvP = true }) do
				table.insert(pvp, line.Text)
			end
			text(tipBody, "PVP  ·  " .. table.concat(pvp, "  ·  "), 11, P.Dim)
		end
	end
	for id, bonus in affinity do
		local affix = GemConfig.AffixById[id]
		if affix and affix.Element == gem.Element then
			text(tipBody, "Boosted by your armor  ·  " .. GemConfig.affixText(id, bonus), 12, color)
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
	local parts, anchorOf, placeOf = {}, nil, nil
	local character = player.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	local source = if worn then equipment and equipment:FindFirstChild(slotName) else previewFor(slotName, id)
	if source then
		for _, part in source:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	if worn and character then
		local origin = character:GetPivot()
		anchorOf = function(part)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			local anchor = weld and weld.Part0
			return if anchor then anchor.Name else ""
		end
		placeOf = function(part)
			return origin:ToObjectSpace(part.CFrame)
		end
	else
		anchorOf = function(part)
			return part:GetAttribute("Anchor") or ""
		end
		placeOf = function(part)
			return part.CFrame
		end
	end
	if #parts == 0 or not frameGear(view, slotName, parts, anchorOf, placeOf) then
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
	tooltip.Size = UDim2.fromOffset(384, 240)
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
				else SuitTraits.forSuit(player.UserId, loadout.Helmet)
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
				"No other " .. string.lower(slotLabel) .. " yet. Recover gear in the Moon Mine or the Market.",
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
		text(tipBody, "INSPECT", 18, P.Gold, BOLD)
		-- Nothing selected: three quick steps instead of a block of text.
		for i, step in
			{
				{ "Select anything", "Click a gem or an item to see its stats here." },
				{ "Enchant your gear", "Drag a gem onto an equipped item (hold it first on touch)." },
				{ "Power your surges", "Socket gems in the Surge Array on Q · E · R  [L]." },
			}
		do
			local row = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, -6, 0, 50) }, tipBody)
			UiKit.round(row, 8)
			local chip = new("TextLabel", {
				Text = tostring(i),
				TextSize = 14,
				Font = BOLD,
				TextColor3 = P.Inset,
				BackgroundColor3 = P.Gold,
				Position = UDim2.fromOffset(10, 13),
				Size = UDim2.fromOffset(24, 24),
			}, row)
			UiKit.round(chip, 12)
			local title = text(row, step[1], 14, P.Text, BOLD)
			title.Position, title.Size = UDim2.fromOffset(46, 6), UDim2.new(1, -54, 0, 18)
			local line = text(row, step[2], 12, P.Dim)
			line.Position, line.Size = UDim2.fromOffset(46, 26), UDim2.new(1, -54, 0, 18)
		end
		if hint ~= "" then
			text(tipBody, (string.gsub(hint, "^%s+", "")), 12, P.Dim)
		end
		return
	end
	gemLines(gem)
	detailsButton()
	if gem.Cut then
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
function drawTooltip()
	drawTooltipContent()
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
	-- The gem's headline effect (its Size line), e.g. "Heat Shield absorbs 16 damage".
	local headline = gem and GemConfig.lines(gem, slotName, { Affinity = wornAffinities() })[1]
	ui.Bonus.Text = if headline then headline.Text else ""
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
local function statTile(parent: Instance, name: string, rating: Classes.Rating, x: number, y: number)
	local color = STAT_COLORS[name] or P.Teal
	local total = rating.Base + rating.Bonus
	local gemColor = if rating.Element then GemConfig.ElementColors[rating.Element] else P.Good
	local tile = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(176, 50),
	}, parent)
	UiKit.round(tile, 6)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(color:Lerp(P.Frame, 0.78), P.Frame) }, tile)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.6 }, tile)
	statIcon(tile, name, color)
	local caption = text(tile, string.upper(name), 11, color:Lerp(Color3.new(1, 1, 1), 0.35), BOLD)
	caption.AutomaticSize = Enum.AutomaticSize.None
	caption.Position = UDim2.fromOffset(48, 5)
	caption.Size = UDim2.fromOffset(80, 13)
	local number = text(tile, tostring(total), 22, Color3.new(1, 1, 1), IronUi.Heading)
	number.AutomaticSize = Enum.AutomaticSize.None
	number.Position = UDim2.fromOffset(48, 17)
	number.Size = UDim2.fromOffset(70, 22)
	if rating.Bonus > 0 then
		local pill = new("TextLabel", {
			BackgroundColor3 = gemColor,
			BackgroundTransparency = 0.78,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 7),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = "◆ +" .. rating.Bonus,
			Font = BOLD,
			TextSize = 12,
			TextColor3 = gemColor:Lerp(Color3.new(1, 1, 1), 0.3),
		}, tile)
		UiKit.round(pill, 9)
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, pill)
	end
	local track = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 36, 52),
		Position = UDim2.fromOffset(48, 40),
		Size = UDim2.new(1, -56, 0, 5),
	}, tile)
	UiKit.round(track, 3)
	local baseShare = math.min(1, rating.Base / RATING_MAX)
	local base = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(baseShare, 1) }, track)
	UiKit.round(base, 3)
	if rating.Bonus > 0 then
		local extra = new("Frame", {
			BackgroundColor3 = gemColor,
			Position = UDim2.fromScale(baseShare, 0),
			Size = UDim2.fromScale(math.min(1, total / RATING_MAX) - baseShare, 1),
		}, track)
		UiKit.round(extra, 3)
	end
	return total
end

-- A small labelled chip for the footer.
local function footChip(parent: Instance, value: string, color: Color3, order: number): TextLabel
	local chip = new("TextLabel", {
		BackgroundColor3 = P.Frame,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		Text = value,
		Font = BOLD,
		TextSize = 12,
		TextColor3 = color,
		LayoutOrder = order,
	}, parent)
	UiKit.round(chip, 11)
	new(
		"UIStroke",
		{ Color = color, Thickness = 1, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		chip
	)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip)
	return chip
end

local function drawStats(loadout, class)
	clear(statsCard)
	local head = text(statsCard, "COMBAT RATINGS", 13, P.Gold, BOLD)
	head.AutomaticSize = Enum.AutomaticSize.None
	head.Size = UDim2.fromOffset(200, 18)
	head.TextYAlignment = Enum.TextYAlignment.Center
	if not class then
		return
	end
	local ratings = Classes.ratings(loadout)
	local power = 0
	for i, name in Classes.StatNames do
		local column, row = (i - 1) % 2, (i - 1) // 2
		power += statTile(statsCard, name, ratings[name], column * 184, 24 + row * 56)
	end
	-- Power: the four ratings together, one number to compare loadouts by.
	local badge = new("Frame", {
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.82,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -2),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
	}, statsCard)
	UiKit.round(badge, 11)
	new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.4 }, badge)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, badge)
	UiKit.list(badge, 6, true)
	local caption = text(badge, "POWER", 11, P.Gold, BOLD)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromOffset(0, 22)
	caption.LayoutOrder = 1
	local score = text(badge, tostring(power), 16, Color3.new(1, 1, 1), IronUi.Heading)
	score.AutomaticSize = Enum.AutomaticSize.X
	score.Size = UDim2.fromOffset(0, 22)
	score.LayoutOrder = 2
	-- Footer: what the ratings mean, and how many gems are attuned.
	local foot = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, 22),
	}, statsCard)
	UiKit.list(foot, 6, true)
	footChip(
		foot,
		string.format("%d MAX HP", Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)),
		P.Emerald,
		1
	)
	footChip(
		foot,
		string.format("%.1f SPEED", Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus)),
		P.Amethyst,
		2
	)
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
	footChip(
		foot,
		if attuned > 0 then string.format("◆ %d / %d ATTUNED", attuned, #Slots.Order) else "NO GEMS ATTUNED",
		color,
		3
	)
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

local function drawGrid(profile)
	local gems = table.clone(profile.Gems)
	table.sort(gems, function(a, b)
		return GemConfig.value(a) > GemConfig.value(b)
	end)
	invTitle.Text = string.format("GEM BACKPACK   %d / %d", #gems, Config.MaxGems)
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
			local grade = text(cell, "Q" .. tostring(gem.Cut or 0), 11, P.Gold, BOLD)
			grade.Position = UDim2.fromOffset(3, CELL - 13)
			grade.ZIndex = 3
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
-- Lightweight category silhouettes keep a large reserve bag cheap to render.
local function equipmentIcon(parent, slotName, gear, color)
	local icon = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(28, 26) },
		parent
	)
	local function part(x, y, w, h, angle)
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = angle or 0,
		}, icon)
	end
	if slotName == "Helmet" then
		part(4, 3, 20, 19)
		part(7, 22, 14, 3)
		new(
			"Frame",
			{ BackgroundColor3 = P.Frame, Position = UDim2.fromOffset(7, 9), Size = UDim2.fromOffset(14, 6) },
			icon
		)
	elseif slotName == "Armor" then
		part(7, 7, 15, 17)
		part(1, 4, 8, 9, 12)
		part(21, 4, 7, 9, -12)
	elseif slotName == "Gloves" then
		part(7, 9, 14, 14)
		part(7, 3, 4, 10)
		part(13, 2, 4, 10)
		part(19, 4, 3, 10)
		part(2, 12, 6, 8, -20)
	elseif slotName == "Boots" then
		part(6, 3, 11, 17)
		part(6, 18, 19, 7)
	elseif slotName == "Shield" then
		part(5, 3, 19, 14)
		part(8, 13, 13, 11, 45)
	elseif gear.Look == "FrontierSword" then
		part(12, 0, 5, 18)
		part(6, 17, 17, 3)
		part(12, 20, 5, 6)
	else
		part(3, 6, 23, 8)
		part(7, 13, 8, 12, 12)
	end
end

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
	local items = storedEquipment(profile)
	equipmentTitle.Text = string.format("EQUIPMENT INVENTORY   %d STORED", #items)
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
	local sets = Classes.setState(loadout).Active
	subtitle.Text = string.format(
		"Warrior · Prospector %d/6 · Skirmisher %d/6 · Juggernaut %d/6",
		sets.Prospector.Count,
		sets.Skirmisher.Count,
		sets.Juggernaut.Count
	)
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
	drawEquipmentInventory(profile)
	requestPreviews(profile)
	drawTooltip()
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
