--[[
	The dashboard: the whole game on one screen (menu-only mode).
	  Left    your hero: the warrior wearing their gear, weapon and armor
	          with their gem sockets, and stats
	  Middle  the Mine (the big one), Craft, Enchant, Cut and Sell
	  Right   your inventory: gems and materials
	Every card opens its own window on top (Mine, Crafting Hall, Character,
	gem pouch). Keys: M mine, F craft, E enchant, X cut, V sell, G gems,
	B shop.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
if not Config.MenuOnly then
	return
end

local CharacterUI = require(script.Parent.Modules.CharacterUI)
local CutFlow = require(script.Parent.Modules.CutFlow)
local ForgeUI = require(script.Parent.Modules.ForgeUI)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local ShopArt = require(script.Parent.Modules.ShopArt)
local ShopUI = require(script.Parent.Modules.ShopUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local HEADING, CHUNKY = IronUi.Heading, IronUi.Chunky
local INK = P.Ink
local LIGHT = Color3.fromRGB(214, 208, 196)
local W, H = 1280, 720

pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

local gui = UiKit.gui("Dashboard", 1)
gui.IgnoreGuiInset = true

-- Background: covers the whole screen (there's no world behind it).
local backdrop = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1) }, gui)
new("UIGradient", {
	Rotation = 110,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 38, 44)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 20, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 26)),
	}),
}, backdrop)
local pattern = new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = string.rep(string.rep("◆      ", 40) .. "\n", 30),
	TextSize = 14,
	LineHeight = 2,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 0.94,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, backdrop)
pattern.ClipsDescendants = true

-- The layout is designed at 1280x720 and scaled to fit the screen, below
-- Roblox's own top bar (its menu buttons sit in the top-left corner).
local TOPBAR = 58
local safe = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, TOPBAR),
	Size = UDim2.new(1, 0, 1, -TOPBAR),
}, gui)
local root = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
}, safe)
local fitScale = new("UIScale", {}, root)
local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 and screen.Y > TOPBAR then
		fitScale.Scale = math.min(screen.X / W, (screen.Y - TOPBAR) / H)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- Shared pieces ---------------------------------------------------------------------------------------------

local function panel(parent: Instance, x: number, y: number, w: number, h: number, tint: Color3): Frame
	local frame = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	UiKit.round(frame, 8)
	new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.15 }, frame)
	-- Dark iron, with just a hint of the panel's colour at the top.
	local muted = IronUi.mute(tint)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(muted:Lerp(P.Frame, 0.6), muted:Lerp(P.Frame, 0.9)),
	}, frame)
	-- A thin gold rule along the top edge.
	new("Frame", {
		BackgroundColor3 = P.Gold,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 1),
	}, frame)
	return frame
end

local function label(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local t = text(parent, value, size, color or Color3.new(1, 1, 1), font or CHUNKY)
	t.AutomaticSize = Enum.AutomaticSize.None
	return t
end

local function place(object: GuiObject, x: number, y: number, w: number, h: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
end

-- A little gold key-hint chip (e.g. "M"), on a button's corner.
local function keyChip(parent: Instance, key: string): TextLabel
	local chip = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = P.Gold,
		Text = key,
		Font = CHUNKY,
		TextSize = 15,
		TextColor3 = INK,
		ZIndex = 6,
	}, parent)
	UiKit.round(chip, 4)
	new("UIStroke", { Color = INK, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
	return chip
end

local function bigButton(parent: Instance, caption: string, color: Color3, onClick: () -> ()): TextButton
	local b = IronUi.gemButton(parent, caption, color, onClick)
	b.Size = UDim2.fromOffset(0, 52)
	b.TextSize = 22
	return b
end

-- Top bar ---------------------------------------------------------------------------------------------------

local logo = IronUi.badge(root, "💎", 64)
logo.Position = UDim2.fromOffset(16, 8)
logo.Rotation = 0
local title = IronUi.title(root, "GEMSOUL", 40, P.Gold)
title.AutomaticSize = Enum.AutomaticSize.None
place(title, 92, 14, 300, 44)
local hello = label(root, "", 15, LIGHT)
place(hello, 94, 52, 400, 18)

local wallet = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(W - 16, 14),
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
}, root)
UiKit.list(wallet, 12, true)
local function pill(order: number, icon: string, color: Color3): TextLabel
	local frame = new("Frame", {
		BackgroundColor3 = P.Frame,
		Size = UDim2.fromOffset(150, 44),
		LayoutOrder = order,
	}, wallet)
	UiKit.round(frame, 6)
	new("UIStroke", { Color = IronUi.mute(color), Thickness = 1.5 }, frame)
	local ic = label(frame, icon, 24, Color3.new(1, 1, 1), Enum.Font.Gotham)
	place(ic, 10, 6, 32, 32)
	ic.TextXAlignment = Enum.TextXAlignment.Center
	local value = label(frame, "0", 20, Color3.new(1, 1, 1), CHUNKY)
	place(value, 44, 0, 94, 44)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextYAlignment = Enum.TextYAlignment.Center
	return value
end
local coinsValue = pill(1, "💰", P.Gold)
local marksValue = pill(2, "🎖️", Color3.fromRGB(90, 150, 255))
local shopButton = IronUi.gemButton(wallet, "🛒  SHOP", Color3.fromRGB(230, 70, 150), function()
	ShopUI.toggle()
end)
shopButton.LayoutOrder = 3
shopButton.Size = UDim2.fromOffset(0, 46)

-- Left: the hero --------------------------------------------------------------------------------------------

local TOP = 84
local hero = panel(root, 16, TOP, 360, H - TOP - 16, Color3.fromRGB(130, 70, 60))
local heroTitle = IronUi.title(hero, "WARRIOR", 28)
heroTitle.AutomaticSize = Enum.AutomaticSize.None
place(heroTitle, 18, 16, 324, 32)
local heroSub = label(hero, "Melee damage", 14, LIGHT)
place(heroSub, 20, 48, 320, 18)

local stage = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.fromOffset(328, 250),
	ClipsDescendants = true,
}, hero)
UiKit.round(stage, 6)
new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.3 }, stage)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(62, 60, 66), Color3.fromRGB(16, 16, 20)),
}, stage)
local glow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(210, 210),
	BackgroundColor3 = Color3.fromRGB(255, 226, 180),
	BackgroundTransparency = 0.9,
}, stage)
UiKit.round(glow, 105)
local avatar = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(128, 128, 140),
	LightColor = Color3.fromRGB(255, 238, 214),
	LightDirection = Vector3.new(-0.5, -0.7, 0.8),
	Size = UDim2.fromScale(1, 1),
}, stage)
local avatarWorld = new("WorldModel", {}, avatar)
local avatarCamera = new("Camera", { FieldOfView = 30 }, avatar)
avatar.CurrentCamera = avatarCamera
avatarCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1.4, -12), Vector3.new(0, 0.4, 0))
local avatarModel: Model? = nil

local function refreshAvatar()
	local character = player.Character
	if not character then
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
-- The hero turns gently side to side.
IronUi.animate(avatar, function(t)
	if avatarModel and avatarModel.Parent then
		avatarModel:PivotTo(CFrame.Angles(0, math.sin(t * 0.6) * 0.6, 0))
	end
end)
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "GemsoulGear" then
			task.wait(0.1)
			refreshAvatar()
		end
	end)
	task.delay(1, refreshAvatar)
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- Weapon and armor slots, each with its gem socket.
type GearSlot = { Name: TextLabel, Quality: TextLabel, Gem: TextLabel, Dot: Frame }
local function gearSlot(x: number, caption: string): GearSlot
	local card = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 22, 40),
		Position = UDim2.fromOffset(x, 334),
		Size = UDim2.fromOffset(160, 118),
	}, hero)
	UiKit.round(card, 12)
	new("UIStroke", { Color = INK, Thickness = 2 }, card)
	local head = label(card, caption, 12, P.Dim, CHUNKY)
	place(head, 10, 6, 140, 14)
	local name = label(card, "", 16, Color3.new(1, 1, 1), CHUNKY)
	place(name, 10, 22, 140, 40)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	local quality = label(card, "", 13, Color3.new(1, 1, 1), CHUNKY)
	place(quality, 10, 62, 140, 16)
	local dot = new("Frame", {
		Position = UDim2.fromOffset(10, 88),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(60, 52, 76),
		Rotation = 45,
	}, card)
	UiKit.round(dot, 4)
	new("UIStroke", { Color = INK, Thickness = 2 }, dot)
	local gem = label(card, "", 12, LIGHT, CHUNKY)
	place(gem, 38, 86, 118, 24)
	gem.TextWrapped = true
	gem.TextYAlignment = Enum.TextYAlignment.Center
	return { Name = name, Quality = quality, Gem = gem, Dot = dot }
end
local weaponSlot = gearSlot(16, "WEAPON")
local armorSlot = gearSlot(184, "ARMOR")

-- Stats: four chunky bars.
local statsBox = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 462),
	Size = UDim2.fromOffset(324, 84),
}, hero)
UiKit.list(statsBox, 4)
local statBars: { [string]: { Frame } } = {}
for i, name in Classes.StatNames do
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i }, statsBox)
	local caption = label(row, string.upper(name), 12, LIGHT, CHUNKY)
	place(caption, 0, 0, 80, 18)
	local cells = {}
	for n = 1, 5 do
		local cell = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(40, 34, 56),
			Position = UDim2.fromOffset(84 + (n - 1) * 48, 3),
			Size = UDim2.fromOffset(44, 12),
		}, row)
		UiKit.round(cell, 6)
		new("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
		cells[n] = cell
	end
	statBars[name] = cells
end

local gearButton = bigButton(hero, "⚔️  GEAR & ENCHANT", Color3.fromRGB(200, 90, 60), function()
	CharacterUI.open()
end)
gearButton.AnchorPoint = Vector2.new(0.5, 1)
gearButton.Position = UDim2.new(0.5, 0, 1, -16)

-- Middle: the Mine and the workshops ------------------------------------------------------------------------

local MID_X, MID_W = 392, 480
local mine = panel(root, MID_X, TOP, MID_W, 250, Color3.fromRGB(230, 130, 40))
local mineTitle = IronUi.title(mine, "THE MINE", 40)
mineTitle.AutomaticSize = Enum.AutomaticSize.None
place(mineTitle, 22, 18, 300, 44)
local mineLine1 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine1, 24, 70, 280, 22)
local mineLine2 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine2, 24, 96, 280, 22)
local mineLine3 =
	label(mine, "Glinting rocks hide gems. Deeper walls hold rarer ones!", 14, Color3.fromRGB(255, 236, 210), CHUNKY)
place(mineLine3, 24, 124, 260, 40)
mineLine3.TextWrapped = true
mineLine3.TextYAlignment = Enum.TextYAlignment.Top
-- A few decorative rocks with glints.
for i, spec in { { 330, 40, 90, "✦" }, { 400, 110, 64, "" }, { 318, 140, 70, "◆" } } do
	local rock = new("Frame", {
		Position = UDim2.fromOffset(spec[1], spec[2]),
		Size = UDim2.fromOffset(spec[3], spec[3]),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Rotation = (i - 2) * 8,
	}, mine)
	UiKit.round(rock, math.floor(spec[3] * 0.3))
	new("UIStroke", { Color = INK, Thickness = 3 }, rock)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(160, 146, 134), Color3.fromRGB(84, 74, 70)),
	}, rock)
	if spec[4] ~= "" then
		local mark = label(
			rock,
			spec[4],
			math.floor(spec[3] * 0.4),
			if spec[4] == "✦" then Color3.fromRGB(190, 250, 255) else Color3.fromRGB(200, 205, 215),
			CHUNKY
		)
		mark.Size = UDim2.fromScale(1, 1)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
		if spec[4] == "✦" then
			IronUi.animate(mark, function(t)
				mark.Rotation = t * 50
				mark.TextTransparency = 0.5 - (math.sin(t * 3) + 1) / 4
			end)
		end
	end
end
local digButton = bigButton(mine, "⛏️  DIG!", P.Emerald, function()
	MineUI.open()
end)
digButton.Position = UDim2.fromOffset(22, 180)
digButton.Size = UDim2.fromOffset(0, 54)
digButton.TextSize = 26
local digHint = keyChip(digButton, "M")
digHint.AnchorPoint = Vector2.new(0.5, 0.5)
digHint.Position = UDim2.new(1, -4, 0, 4)
local freeBadge = label(mine, "", 16, Color3.new(1, 1, 1), CHUNKY)
freeBadge.BackgroundTransparency = 0
freeBadge.BackgroundColor3 = Color3.fromRGB(168, 64, 56)
freeBadge.AnchorPoint = Vector2.new(1, 0)
place(freeBadge, 0, 0, 120, 30)
freeBadge.AnchorPoint = Vector2.new(1, 0)
freeBadge.Position = UDim2.new(1, -16, 0, 16)
freeBadge.Rotation = 6
freeBadge.TextXAlignment = Enum.TextXAlignment.Center
freeBadge.TextYAlignment = Enum.TextYAlignment.Center
UiKit.round(freeBadge, 15)

-- The four workshop cards, two by two.
type Card = { Frame: Frame, Line: TextLabel }
local function workshop(
	x: number,
	y: number,
	icon: string,
	name: string,
	key: string,
	color: Color3,
	button: string,
	onClick: () -> ()
): Card
	local card = panel(root, x, y, 234, 175, color)
	local ic = label(card, icon, 40, Color3.new(1, 1, 1), Enum.Font.Gotham)
	place(ic, 14, 14, 48, 48)
	ic.Rotation = 0
	local head = IronUi.title(card, name, 24)
	head.AutomaticSize = Enum.AutomaticSize.None
	place(head, 70, 22, 150, 28)
	local line = label(card, "", 13, LIGHT, IronUi.Body)
	place(line, 16, 68, 204, 44)
	line.TextWrapped = true
	line.TextYAlignment = Enum.TextYAlignment.Top
	local b = IronUi.button(card, button, true, onClick)
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 16, 1, -14)
	keyChip(card, key)
	return { Frame = card, Line = line }
end
local ROW1, ROW2 = TOP + 262, TOP + 262 + 187
local craftCard = workshop(MID_X, ROW1, "⚒️", "CRAFT", "F", Color3.fromRGB(160, 100, 60), "Forge gear", function()
	ForgeUI.open("Craft")
end)
local enchantCard = workshop(
	MID_X + 246,
	ROW1,
	"✨",
	"ENCHANT",
	"E",
	Color3.fromRGB(140, 70, 220),
	"Set gems",
	function()
		CharacterUI.open()
	end
)
local cutCard = workshop(MID_X, ROW2, "✂️", "CUT", "X", Color3.fromRGB(40, 150, 210), "Cut a stone", function()
	CutFlow.open()
end)
local sellCard = workshop(
	MID_X + 246,
	ROW2,
	"💰",
	"SELL",
	"V",
	Color3.fromRGB(220, 170, 30),
	"Sell stones",
	function()
		ForgeUI.open("Sell", true)
	end
)

-- Right: inventory ------------------------------------------------------------------------------------------

local INV_X = 888
local inventory = panel(root, INV_X, TOP, W - INV_X - 16, H - TOP - 16, Color3.fromRGB(60, 90, 150))
local invTitle = IronUi.title(inventory, "INVENTORY", 28)
invTitle.AutomaticSize = Enum.AutomaticSize.None
place(invTitle, 18, 16, 240, 32)
local invCount = label(inventory, "", 14, LIGHT, CHUNKY)
place(invCount, 20, 48, 200, 18)
local pouchButton = IronUi.button(inventory, "Open pouch (G)", false, function()
	InventoryUI.open()
end)
pouchButton.AnchorPoint = Vector2.new(1, 0)
pouchButton.Position = UDim2.new(1, -14, 0, 16)

local gemsHead = label(inventory, "GEMS", 15, P.Gold, CHUNKY)
place(gemsHead, 18, 76, 200, 18)
local gemGrid = new("ScrollingFrame", {
	BackgroundColor3 = Color3.fromRGB(18, 14, 28),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(14, 98),
	Size = UDim2.new(1, -28, 0, 330),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = P.Gold,
}, inventory)
UiKit.round(gemGrid, 12)
UiKit.pad(gemGrid, 8)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(98, 98),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gemGrid)
local gemsEmpty = label(inventory, "No gems yet. Dig some up in the Mine!", 15, LIGHT, CHUNKY)
place(gemsEmpty, 24, 200, 300, 40)
gemsEmpty.TextWrapped = true
gemsEmpty.TextXAlignment = Enum.TextXAlignment.Center

local matsHead = label(inventory, "MATERIALS", 15, P.Gold, CHUNKY)
place(matsHead, 18, 440, 200, 18)
local matsGrid = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 462),
	Size = UDim2.new(1, -28, 0, 150),
}, inventory)
new("UIGridLayout", {
	CellSize = UDim2.new(0.5, -4, 0, 44),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, matsGrid)

-- Filling it in ---------------------------------------------------------------------------------------------

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

local function drawGear(slot: GearSlot, gear, quality: number?, gem)
	local q = Crafting.Qualities[quality or 1] or Crafting.Qualities[1]
	slot.Name.Text = if gear then gear.Name else "-"
	slot.Quality.Text = q.Name
	slot.Quality.TextColor3 = q.Color
	if gem then
		local shade = GemConfig.shade(gem)
		slot.Dot.BackgroundColor3 = shade.Color
		slot.Gem.Text = shade.Name
		slot.Gem.TextColor3 = GemConfig.ElementColors[gem.Element] or LIGHT
	else
		slot.Dot.BackgroundColor3 = Color3.fromRGB(60, 52, 76)
		slot.Gem.Text = "Empty socket"
		slot.Gem.TextColor3 = P.Dim
	end
end

local function gemCard(gem, order: number)
	local tier = GemConfig.TierColors[gem.Tier] or P.Dim
	local card = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
	}, gemGrid)
	UiKit.round(card, 12)
	new("UIStroke", { Color = tier, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tier:Lerp(Color3.new(0, 0, 0), 0.45), tier:Lerp(Color3.new(0, 0, 0), 0.8)),
	}, card)
	-- The stone itself, in 3D.
	local gemStage = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(60, 52),
	}, card)
	GemArt.viewport(gemStage, gem, false)
	local state = if gem.Cut then "CUT " .. gem.Cut else "ROUGH"
	local tag = label(card, state, 11, if gem.Cut then P.Gold else LIGHT, CHUNKY)
	place(tag, 4, 52, 90, 14)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	local worth = label(card, "💰 " .. commas(GemConfig.value(gem)), 13, Color3.new(1, 1, 1), CHUNKY)
	place(worth, 4, 70, 90, 18)
	worth.TextXAlignment = Enum.TextXAlignment.Center
	IronUi.juice(card, 1.06, 0.95)
	IronUi.highlight(card)
	card.Activated:Connect(function()
		InventoryUI.open()
	end)
end

local MATERIAL_ORDER = { "Iron", "Timber", "Leather", "Cloth", "Mithril", "Shards" }

local function refresh(profile)
	if not profile then
		return
	end
	hello.Text = "Welcome back, " .. player.DisplayName
	coinsValue.Text = commas(profile.Coins or 0)
	marksValue.Text = commas(profile.Marks or 0)

	-- Hero.
	local character = profile.Character or {}
	local class = Classes.get(character.Class or Config.OnlyClass or "Warrior")
	if class then
		heroTitle.Text = string.upper(class.Name)
		heroSub.Text = class.Role .. "  •  " .. player.DisplayName
		drawGear(weaponSlot, Classes.weapon(class.Id, character.Weapon), character.WeaponQuality, character.WeaponGem)
		drawGear(armorSlot, Classes.armor(class.Id, character.Armor), character.ArmorQuality, character.ArmorGem)
		local stats = Classes.stats(class.Id, character.Weapon, character.Armor)
		for name, cells in statBars do
			for n, cell in cells do
				cell.BackgroundColor3 = if n <= (stats[name] or 0) then IronUi.mute(class.Color) else P.Slot
			end
		end
	end

	-- The Mine.
	local quota = profile.Quota or {}
	local daily = profile.DailyQuota or Config.DailyQuota
	local weekly = profile.WeeklyQuota or Config.WeeklyQuota
	local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
	mineLine1.Text = string.format("🎟️  Free walls today: %d / %d", free, daily)
	local best = profile.Stats and profile.Stats.BestDepth or 0
	mineLine2.Text = if best > 0 then "⬇️  Deepest dig: depth " .. best else "⬇️  Dig deeper for rarer gems"
	freeBadge.Visible = free > 0
	freeBadge.Text = free .. " FREE"

	-- Workshops.
	local rough, cut = 0, 0
	for _, gem in profile.Gems or {} do
		if gem.Cut then
			cut += 1
		else
			rough += 1
		end
	end
	local weapon = class and Classes.weapon(class.Id, character.Weapon)
	local nextQuality = Crafting.Qualities[(character.WeaponQuality or 1) + 1]
	-- Point at the next armor set up the ladder first, then weapon upgrades.
	local owned = profile.Owned and profile.Owned.Armors or {}
	local nextArmor = nil
	for _, armor in class and class.Armors or {} do
		if not owned[armor.Id] then
			nextArmor = armor
			break
		end
	end
	craftCard.Line.Text = if nextArmor
		then string.format("Forge better armor: the %s.", nextArmor.Name)
		elseif weapon and nextQuality then string.format("Upgrade your %s to %s.", weapon.Name, nextQuality.Name)
		else "Buy materials and forge new gear."
	enchantCard.Line.Text = if character.WeaponGem and character.ArmorGem
		then "Both sockets are filled. Swap in better gems any time."
		elseif cut > 0 then string.format("You have %d cut gem%s ready to set.", cut, if cut == 1 then "" else "s")
		else "Cut a gem first, then set it into your gear."
	cutCard.Line.Text = if rough > 0
		then string.format(
			"%d rough stone%s to cut. A good cut is worth far more!",
			rough,
			if rough == 1 then "" else "s"
		)
		else "No rough stones. Dig some up in the Mine."
	sellCard.Line.Text =
		string.format("%d gems in your pouch. Sell the ones you don't need for coins.", #(profile.Gems or {}))

	-- Inventory: newest gems first.
	invCount.Text = string.format("%d / %d gems", #(profile.Gems or {}), Config.MaxGems)
	for _, child in gemGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local gems = table.clone(profile.Gems or {})
	table.sort(gems, function(a, b)
		return (a.Found or 0) > (b.Found or 0)
	end)
	for i, gem in gems do
		if i > 60 then
			break
		end
		gemCard(gem, i)
	end
	gemsEmpty.Visible = #gems == 0

	for _, child in matsGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, id in MATERIAL_ORDER do
		local material = Crafting.Materials[id]
		local row = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 20, 36),
			LayoutOrder = i,
		}, matsGrid)
		UiKit.round(row, 10)
		new("UIStroke", { Color = if material then material.Color else P.Dim, Thickness = 1.5 }, row)
		local icon = label(row, ShopArt.MaterialIcons[id] or "⛓️", 20, Color3.new(1, 1, 1), Enum.Font.Gotham)
		place(icon, 6, 8, 28, 28)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(row, id, 13, LIGHT, CHUNKY)
		place(name, 38, 4, 90, 18)
		local count = label(row, "x" .. tostring((profile.Materials or {})[id] or 0), 18, Color3.new(1, 1, 1), HEADING)
		place(count, 38, 20, 100, 22)
	end
end

local pending = false
GemClient.Changed:Connect(function(profile)
	-- Several changes can arrive at once; redraw once per frame.
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		refresh(GemClient.Profile or profile)
	end)
end)
if GemClient.Profile then
	refresh(GemClient.Profile)
end

-- Hidden while the intro is on screen; the Welcome Bundle is offered after.
local function introOpen(): boolean
	return player.PlayerGui:FindFirstChild("Intro") ~= nil
end
gui.Enabled = not introOpen()
local welcomed = false
local function maybeWelcome()
	local profile = GemClient.Profile
	if welcomed or introOpen() or not profile or not profile.Intro or not profile.Intro.Done then
		return
	end
	welcomed = true
	task.delay(3, ShopUI.showWelcome)
end
player.PlayerGui.ChildRemoved:Connect(function(child)
	if child.Name == "Intro" then
		gui.Enabled = true
		refreshAvatar()
		maybeWelcome()
	end
end)
GemClient.Changed:Connect(maybeWelcome)
task.defer(maybeWelcome)

-- Keys.
local KEYS = {
	M = MineUI.toggle,
	F = function()
		ForgeUI.open("Craft")
	end,
	E = function()
		CharacterUI.open()
	end,
	X = CutFlow.open,
	V = function()
		ForgeUI.open("Sell", true)
	end,
	G = InventoryUI.toggle,
	B = ShopUI.toggle,
}
ContextActionService:BindAction(
	"GemsoulDashboard",
	function(_, state, inputObject)
		if state == Enum.UserInputState.Begin and not introOpen() then
			local action = KEYS[inputObject.KeyCode.Name]
			if action then
				action()
			end
		end
		return Enum.ContextActionResult.Pass
	end,
	false,
	Enum.KeyCode.M,
	Enum.KeyCode.F,
	Enum.KeyCode.E,
	Enum.KeyCode.X,
	Enum.KeyCode.V,
	Enum.KeyCode.G,
	Enum.KeyCode.B
)
