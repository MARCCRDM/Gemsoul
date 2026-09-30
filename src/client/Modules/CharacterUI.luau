--[[
	The character screen, Diablo style: your avatar in the middle with the
	weapon and armor slots on either side, each with a gem socket beneath
	it; stats and active enchantments below; and a grid inventory of every
	gem on the right. Click a gem or a socket to inspect it in the tooltip
	box; from there gems go into sockets and back out again.

	Opens with [C] or the HUD button. Talking to Vey at the Arcanum opens it
	too; sockets can only be changed near Vey (the server checks).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local HEADING = Enum.Font.Arcade
local BODY = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold

-- Dark iron and old gold.
local P = {
	Frame = Color3.fromRGB(14, 13, 12),
	Inset = Color3.fromRGB(22, 20, 18),
	Slot = Color3.fromRGB(28, 25, 22),
	Edge = Color3.fromRGB(92, 72, 44),
	Gold = Color3.fromRGB(214, 170, 92),
	Text = Color3.fromRGB(226, 218, 200),
	Dim = Color3.fromRGB(150, 140, 122),
	Good = Color3.fromRGB(120, 220, 120),
	Bad = Color3.fromRGB(235, 90, 80),
}

local WIDTH, HEIGHT = 1000, 620
local CELL, GAP, COLUMNS = 52, 6, 8

local CharacterUI = {}

type Selection = { Kind: "Gem", Gem: any } | { Kind: "Socket", Slot: string }
local selection: Selection? = nil
local atVey = false

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function text(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or BODY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, parent)
end

-- A bevelled box: dark fill, bronze edge, lighter at the top.
local function box(parent: Instance, position: UDim2, size: UDim2, fill: Color3?, radius: number?): Frame
	local frame = new("Frame", { BackgroundColor3 = fill or P.Inset, Position = position, Size = size }, parent)
	UiKit.round(frame, radius or 6)
	new("UIStroke", { Color = P.Edge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
	}, frame)
	return frame
end

local function actionButton(parent: Instance, label: string, primary: boolean, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = if primary then P.Gold else P.Slot,
		Text = label,
		Font = BOLD,
		TextSize = 14,
		TextColor3 = if primary then Color3.fromRGB(24, 18, 10) else P.Text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
	}, parent)
	UiKit.round(b, 6)
	new("UIStroke", { Color = P.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, b)
	b.Activated:Connect(onClick)
	return b
end

-- Screen -------------------------------------------------------------------------------

local gui = UiKit.gui("Character", 8)
gui.Enabled = false
gui.IgnoreGuiInset = true

local shade = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1),
}, gui)

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundColor3 = P.Frame,
}, gui)
UiKit.round(panel, 10)
new("UIStroke", { Color = P.Gold, Thickness = 2.5 }, panel)
local scale = new("UIScale", {}, panel)
local function fit()
	local screen = gui.AbsoluteSize
	scale.Scale = math.min(1, (screen.X - 24) / WIDTH, (screen.Y - 24) / HEIGHT)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

local title = text(panel, "", 24, P.Gold, HEADING)
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(0.5, 0, 0, 26)
local subtitle = text(panel, "", 14, P.Dim, BOLD)
subtitle.Position = UDim2.fromOffset(24, 44)
subtitle.Size = UDim2.new(0.5, 0, 0, 18)

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 14),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = P.Slot,
	Text = "X",
	Font = BOLD,
	TextSize = 18,
	TextColor3 = P.Gold,
}, panel)
UiKit.round(closeButton, 6)
new("UIStroke", { Color = P.Edge, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, closeButton)

-- Left: the paper doll -----------------------------------------------------------------

local doll = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 76),
	Size = UDim2.fromOffset(470, 330),
}, panel)

-- The gradient sits on a frame behind the viewport: on the viewport itself
-- it would tint the avatar too.
local avatarBack = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(122, 0),
	Size = UDim2.fromOffset(226, 330),
}, doll)
UiKit.round(avatarBack, 8)
new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, avatarBack)
new(
	"UIGradient",
	{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(96, 84, 68), Color3.fromRGB(22, 19, 16)) },
	avatarBack
)
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
avatarCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, -11), Vector3.new(0, 0.6, 0))
local avatarModel: Model? = nil

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
end

-- An equipment slot (a tall bevelled box) with its gem socket beneath.
type Slot = {
	Box: Frame,
	Name: TextLabel,
	Style: TextLabel,
	Bonus: TextLabel,
	Socket: TextButton,
	Caption: TextLabel,
	Shown: string?, -- id of the gem drawn in the socket
}
local function slot(x: number, label: string, socketName: string): Slot
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(110, 330),
	}, doll)
	text(holder, label, 12, P.Dim, BOLD).TextXAlignment = Enum.TextXAlignment.Center
	local item = box(holder, UDim2.fromOffset(0, 20), UDim2.fromOffset(110, 150), P.Slot)
	UiKit.pad(item, 8)
	local list = UiKit.list(item, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = text(item, "", 15, P.Text, BOLD)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local style = text(item, "", 11, P.Dim, BOLD)
	style.TextXAlignment = Enum.TextXAlignment.Center
	local bonus = text(item, "", 11, P.Dim, BOLD)
	bonus.TextXAlignment = Enum.TextXAlignment.Center

	local socketLabel = text(holder, "GEM SOCKET", 11, P.Dim, BOLD)
	socketLabel.Position = UDim2.fromOffset(0, 184)
	socketLabel.TextXAlignment = Enum.TextXAlignment.Center
	local socket = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 9, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 204),
		Size = UDim2.fromOffset(78, 78),
	}, holder)
	UiKit.round(socket, 39)
	new("UIStroke", { Name = "Ring", Color = P.Edge, Thickness = 3 }, socket)
	local caption = text(holder, "", 11, P.Dim, BOLD)
	caption.Position = UDim2.fromOffset(0, 290)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	socket.Activated:Connect(function()
		selection = { Kind = "Socket", Slot = socketName }
		CharacterUI.refresh()
	end)
	return { Box = item, Name = name, Style = style, Bonus = bonus, Socket = socket, Caption = caption }
end

local weaponSlot = slot(0, "WEAPON", "Weapon")
local armorSlot = slot(360, "ARMOR", "Armor")

local statsBox = box(panel, UDim2.fromOffset(24, 420), UDim2.fromOffset(470, 176), P.Inset)
UiKit.pad(statsBox, 12)
local statsList = new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.42, 0, 1, 0),
}, statsBox)
UiKit.list(statsList, 4)
local enchantList = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0.46, 0, 0, 0),
	Size = UDim2.new(0.54, 0, 1, 0),
}, statsBox)
UiKit.list(enchantList, 5)

-- Right: inventory grid and tooltip ------------------------------------------------------

local invTitle = text(panel, "", 13, P.Dim, BOLD)
invTitle.Position = UDim2.fromOffset(510, 76)
invTitle.Size = UDim2.fromOffset(466, 18)

local gridBox = box(panel, UDim2.fromOffset(506, 98), UDim2.fromOffset(470, 256), Color3.fromRGB(10, 9, 8))
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

local tooltip = box(panel, UDim2.fromOffset(506, 366), UDim2.fromOffset(470, 230), P.Inset)
local tooltipStroke = tooltip:FindFirstChildOfClass("UIStroke") :: UIStroke
UiKit.pad(tooltip, 12)
local tipArt = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 96) }, tooltip)
local tipBody = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(106, 0),
	Size = UDim2.new(1, -106, 1, -42),
}, tooltip)
UiKit.list(tipBody, 3)
local tipActions = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
}, tooltip)
UiKit.list(tipActions, 8, true)

-- Drawing --------------------------------------------------------------------------------

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		-- Keep layouts, corners, outlines and padding.
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

local function socketed(slotName: string)
	local character = GemClient.Profile and GemClient.Profile.Character
	return character and character[slotName .. "Gem"]
end

local function request(action: string, ...)
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
	end)
end

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
		string.format("%s %s  |  %s", string.upper(GemConfig.TierLabels[gem.Tier]), string.upper(gem.Element), state),
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
	for _, slotName in { "Weapon", "Armor" } do
		local name, effect = GemConfig.enchantment(gem, slotName)
		local heading = text(tipBody, string.format("IN %s: %s", string.upper(slotName), name), 12, P.Gold, BOLD)
		heading.TextColor3 = GemConfig.ElementColors[gem.Element]
		text(tipBody, string.format("%s.  %s", effect, bonusText(gem, slotName)), 12, P.Dim)
	end
	GemArt.viewport(tipArt, gem, true)
	tooltipStroke.Color = tierColor
end

local function drawTooltip()
	clear(tipBody)
	clear(tipActions)
	clear(tipArt)
	tooltipStroke.Color = P.Edge
	local hint = if atVey then "" else "  Sockets can be changed at Vey's Arcanum (east road)."

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
				"Empty. Pick a cut gem from your inventory to bind its element to your "
					.. string.lower(slotName)
					.. "."
					.. hint,
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
			"Click a gem to inspect it, or a socket to see its enchantment. Weapon gems add their element to your hits; armor gems ward you against it."
				.. hint,
			13,
			P.Dim
		)
		return
	end
	gemLines(gem)
	if gem.Cut then
		actionButton(tipActions, "SOCKET IN WEAPON", true, function()
			request("SocketGem", gem.Id, "Weapon")
		end)
		actionButton(tipActions, "SOCKET IN ARMOR", true, function()
			request("SocketGem", gem.Id, "Armor")
		end)
	else
		text(tipActions, "Rough stones must be cut first. Ilsa cuts them at Craft & Cut.", 12, P.Dim).Size =
			UDim2.new(1, 0, 1, 0)
	end
end

local function drawSlot(ui: Slot, slotName: string, gear, class)
	local gem = socketed(slotName)
	-- Enchanted gear is named for its gem, Diablo style, and glows its colour.
	ui.Name.Text = if gear then GemConfig.itemName(gear.Name, gem, slotName) else "Empty"
	ui.Name.TextColor3 = if gem then GemConfig.ElementColors[gem.Element] else P.Text
	ui.Style.Text = if gear then string.upper(gear.Style) else ""
	ui.Bonus.Text = if gem then (string.gsub(bonusText(gem, slotName), "  ", "\n")) else ""
	ui.Bonus.TextColor3 = if gem then GemConfig.ElementColors[gem.Element] else P.Dim
	local stroke = ui.Box:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if gem then GemConfig.ElementColors[gem.Element] elseif class then class.Color else P.Edge
	stroke.Thickness = if gem then 2.5 else 1.5
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
			local plus = text(ui.Socket, "+", 30, P.Edge, BOLD)
			plus.Size = UDim2.fromScale(1, 1)
			plus.AutomaticSize = Enum.AutomaticSize.None
			plus.TextXAlignment = Enum.TextXAlignment.Center
		end
		ring.Color = P.Edge
		ui.Caption.Text = "EMPTY"
		ui.Caption.TextColor3 = P.Dim
	end
	ring.Thickness = if chosen then 4 else 3
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
	text(statsList, "ATTRIBUTES", 12, P.Gold, BOLD)
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
	text(enchantList, "ENCHANTMENTS", 12, P.Gold, BOLD)
	local any = false
	for _, slotName in { "Weapon", "Armor" } do
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
		text(enchantList, "None yet. Socket cut gems into your weapon and armor.", 12, P.Dim)
	end
end

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
	invTitle.Text = string.format("INVENTORY   %d / %d GEMS   |   %d COINS", #gems, Config.MaxGems, profile.Coins)
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
	clear(grid)
	table.clear(pending)
	table.clear(cellsById)
	-- Empty cells fill out the grid so it always reads as a bag.
	local cells = math.max(#gems, COLUMNS * 4)
	cells = math.ceil(cells / COLUMNS) * COLUMNS
	for i = 1, cells do
		local gem = gems[i]
		local cell = new("TextButton", {
			Text = "",
			AutoButtonColor = gem ~= nil,
			BackgroundColor3 = P.Slot,
			LayoutOrder = i,
		}, grid)
		UiKit.round(cell, 4)
		local stroke = new("UIStroke", {
			Color = Color3.fromRGB(44, 38, 30),
			Thickness = 1.2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, cell)
		if gem then
			if not gem.Cut then
				local rough = text(cell, "R", 10, P.Dim, BOLD)
				rough.Position = UDim2.fromOffset(4, 2)
				rough.ZIndex = 3
			end
			pending[cell] = gem
			cellsById[gem.Id] = { Cell = cell, Stroke = stroke, Gem = gem }
			cell.Activated:Connect(function()
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

	drawSlot(weaponSlot, "Weapon", loadout.Class and Classes.weapon(loadout.Class, loadout.Weapon), class)
	drawSlot(armorSlot, "Armor", loadout.Class and Classes.armor(loadout.Class, loadout.Armor), class)
	drawStats(loadout, class)
	drawGrid(profile)
	drawTooltip()
end

-- Opening and closing ----------------------------------------------------------------------

type Options = { AtVey: boolean? }

function CharacterUI.open(options: Options?)
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
	if gui.Enabled then
		CharacterUI.close()
	else
		CharacterUI.open()
	end
end

closeButton.Activated:Connect(CharacterUI.close)
shade.Activated:Connect(CharacterUI.close)
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

RunService.RenderStepped:Connect(function()
	if avatarModel and gui.Enabled then
		avatarModel:PivotTo(CFrame.Angles(0, math.sin(os.clock() * 0.5) * 0.6, 0))
	end
end)

ContextActionService:BindAction("GemsoulCharacter", function(_, state)
	-- Not while the new-player intro is still open.
	if state == Enum.UserInputState.Begin and not player.PlayerGui:FindFirstChild("Intro") then
		CharacterUI.toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.C)

return CharacterUI
