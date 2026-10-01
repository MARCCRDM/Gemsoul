--[[
	The dashboard: the whole game on one screen (menu-only mode).
	  Left    your hero: the warrior wearing their gear, weapon and armor
	          with their gem sockets, and stats
	  Middle  the Mine (the big one), Trade, Enchant, Equipment and Sell
	  Right   your inventory: gems and recovered equipment
	Every card opens its own window on top (Mine, Exchange, Character,
	gem pouch). Keys: M mine, T trade, E enchant, C equipment, V sell, G gems,
	B shop.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
if not Config.MenuOnly then
	return
end

local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local ForgeUI = require(script.Parent.Modules.ForgeUI)
local GemArt = require(script.Parent.Modules.GemArt)
local GemClient = require(script.Parent.Modules.GemClient)
local InventoryUI = require(script.Parent.Modules.InventoryUI)
local IronUi = require(script.Parent.Modules.IronUi)
local MineUI = require(script.Parent.Modules.MineUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local HEADING, CHUNKY = IronUi.Heading, IronUi.Chunky
local LIGHT = P.Dim
local W, H = 1280, 720

pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)

local gui = UiKit.gui("Dashboard", 1)
gui.IgnoreGuiInset = true

-- Background: deep space over the whole screen, thin enough that the moon
-- base (see MenuCamera) shows through behind the panels.
local backdrop = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)
new("UIGradient", {
	Rotation = 110,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 17, 49)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 8, 19)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 22, 36)),
	}),
}, backdrop)
local pattern = new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Text = string.rep(string.rep("·        ", 30) .. "\n", 30),
	TextSize = 14,
	LineHeight = 2,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 0.88,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, backdrop)
pattern.ClipsDescendants = true
-- Sparse pixel stars; fixed placement avoids moving noise behind readable panels.
local stars = Random.new(7319)
for i = 1, 42 do
	local x, y = stars:NextNumber(), stars:NextNumber()
	local size = if i % 7 == 0 then 4 else 2
	local star = new("Frame", {
		BackgroundColor3 = if i % 3 == 0 then P.Amethyst else P.Teal,
		BackgroundTransparency = 0.65,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(x, y),
	}, backdrop)
	if i % 7 == 0 then
		new("Frame", {
			BackgroundColor3 = P.Teal,
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(-3, 1),
			Size = UDim2.fromOffset(10, 2),
		}, star)
		new("Frame", {
			BackgroundColor3 = P.Teal,
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(1, -3),
			Size = UDim2.fromOffset(2, 10),
		}, star)
	end
end
-- Large atmospheric arcs frame the layout without competing with its text.
for i, spec in { { 0.08, 0.24, 560, P.Amethyst }, { 0.93, 0.8, 720, P.Teal } } do
	local arc = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(spec[1], spec[2]),
		Size = UDim2.fromOffset(spec[3], spec[3]),
	}, backdrop)
	UiKit.round(arc, spec[3] / 2)
	new("UIStroke", { Color = spec[4], Thickness = 2, Transparency = 0.84 }, arc)
	local glint = new(
		"Frame",
		{ BackgroundColor3 = spec[4], Size = UDim2.fromOffset(8, 8), Position = UDim2.fromScale(0.5, 0), Rotation = 45 },
		arc
	)
	UiKit.round(glint, 2)
	IronUi.animate(arc, function(t)
		arc.Rotation = t * (if i == 1 then 3 else -2)
	end)
end

-- The layout is designed at 1280x720 and scaled to fit the screen, below
-- Roblox's own top bar (its menu buttons sit in the top-left corner).
local TOPBAR = 78
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
	local shadow = new("Frame", {
		Position = UDim2.fromOffset(x + 3, y + 6),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
	}, parent)
	UiKit.round(shadow, 6)
	local frame = new("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	UiKit.round(frame, 6)
	new("UIStroke", { Color = tint:Lerp(P.Edge, 0.55), Thickness = 1, Transparency = 0.35 }, frame)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tint:Lerp(P.Inset, 0.78), P.Inset),
	}, frame)
	local rail = new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.15,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 0, 2),
	}, frame)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.35, 0),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	}, rail)
	new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.82,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(2, 32),
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
		BackgroundColor3 = P.Slot,
		Text = key,
		Font = CHUNKY,
		TextSize = 15,
		TextColor3 = P.Dim,
		ZIndex = 6,
	}, parent)
	UiKit.round(chip, 4)
	new(
		"UIStroke",
		{ Color = P.Edge, Transparency = 0.5, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		chip
	)
	return chip
end

local function bigButton(parent: Instance, caption: string, color: Color3, onClick: () -> ()): TextButton
	local b = IronUi.gemButton(parent, caption, color, onClick)
	b.Size = UDim2.fromOffset(0, 52)
	b.TextSize = 22
	return b
end

-- Top bar ---------------------------------------------------------------------------------------------------

local logo = IronUi.badge(root, "◆", 48, P.Gold)
logo.Position = UDim2.fromOffset(20, 14)
logo.Rotation = 0
local title = IronUi.wordmark(root)
place(title, 84, 10, 400, 40)
local hello = label(root, "", 12, P.Gold)
place(hello, 85, 48, 400, 18)

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
	new("UIStroke", { Color = IronUi.mute(color), Thickness = 1, Transparency = 0.55 }, frame)
	local ic = label(frame, icon, 11, color, Enum.Font.Gotham)
	place(ic, 10, 6, 54, 32)
	ic.TextXAlignment = Enum.TextXAlignment.Center
	local value = label(frame, "0", 20, Color3.new(1, 1, 1), CHUNKY)
	place(value, 66, 0, 72, 44)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextYAlignment = Enum.TextYAlignment.Center
	return value
end
local coinsValue = pill(1, "COINS", P.Gold)
local marksValue = pill(2, "LEVEL", P.Teal)
local shopButton = IronUi.gemButton(wallet, "Supply Depot", P.Amethyst, function()
	ShopUI.toggle()
end)
shopButton.LayoutOrder = 3
shopButton.Size = UDim2.fromOffset(0, 46)

-- Left: the hero --------------------------------------------------------------------------------------------

local TOP = 84
local hero = panel(root, 16, TOP, 360, H - TOP - 16, Color3.fromRGB(50, 110, 170))
local heroTitle = IronUi.title(hero, "Saga Miner", 24)
heroTitle.AutomaticSize = Enum.AutomaticSize.None
place(heroTitle, 18, 14, 324, 32)
local heroSub = label(hero, "Melee damage", 14, LIGHT)
place(heroSub, 20, 48, 320, 18)

local stage = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.fromOffset(328, 250),
	ClipsDescendants = true,
}, hero)
UiKit.round(stage, 4)
for _, spec in { { 10, 10, 1, 1 }, { 308, 10, -1, 1 }, { 10, 232, 1, -1 }, { 308, 232, -1, -1 } } do
	new("Frame", {
		BackgroundColor3 = P.Teal,
		Position = UDim2.fromOffset(spec[1], spec[2]),
		Size = UDim2.fromOffset(10, 2),
		ZIndex = 3,
	}, stage)
	new("Frame", {
		BackgroundColor3 = P.Teal,
		Position = UDim2.fromOffset(
			spec[1] + (if spec[3] == -1 then 8 else 0),
			spec[2] + (if spec[4] == -1 then -8 else 0)
		),
		Size = UDim2.fromOffset(2, 10),
		ZIndex = 3,
	}, stage)
end
new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.3 }, stage)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(21, 61, 83), P.Frame),
}, stage)
local glow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(210, 210),
	BackgroundColor3 = P.Teal,
	BackgroundTransparency = 0.82,
}, stage)
UiKit.round(glow, 105)
IronUi.orbit(stage, P.Teal, 226)
local stageCaption = label(stage, "W A R R I O R   /   M I N E R", 9, P.Teal)
place(stageCaption, 12, 12, 304, 14)
stageCaption.TextXAlignment = Enum.TextXAlignment.Center
stageCaption.ZIndex = 3
local avatar = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(100, 124, 150),
	LightColor = Color3.fromRGB(214, 244, 255),
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
type GearSlot = { Name: TextLabel, Quality: TextLabel, Gem: TextLabel, Dot: Frame, Rail: Frame }
local function gearSlot(x: number, y: number, caption: string): GearSlot
	local card = IronUi.box(hero, UDim2.fromOffset(x, y), UDim2.fromOffset(160, 36), P.Frame, 6)
	local rail = new(
		"Frame",
		{ BackgroundColor3 = P.Edge, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(0, 2, 1, -10) },
		card
	)
	local hit = new(
		"TextButton",
		{ Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 },
		card
	)
	IronUi.highlight(hit, card)
	hit.Activated:Connect(function()
		CharacterUI.open()
	end)
	local head = label(card, caption, 9, P.Dim)
	place(head, 8, 2, 136, 11)
	local name = label(card, "", 11, P.Text)
	place(name, 8, 14, 128, 18)
	name.Font = IronUi.Bold
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	local quality = label(card, "", 10, P.Dim)
	quality.Visible = false
	local gem = label(card, "", 10, P.Dim)
	gem.Visible = false
	local dot = new("Frame", {
		Position = UDim2.fromOffset(145, 17),
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = P.Slot,
		Rotation = 45,
	}, card)
	return { Name = name, Quality = quality, Gem = gem, Dot = dot, Rail = rail }
end
local gearSlots = {}
for i, key in { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" } do
	gearSlots[key] = gearSlot(
		if i % 2 == 1 then 16 else 184,
		334 + math.floor((i - 1) / 2) * 40,
		string.upper(Slots.Definitions[key].Label)
	)
end

-- Stats: four chunky bars.
local statsBox = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 462),
	Size = UDim2.fromOffset(324, 84),
}, hero)
UiKit.list(statsBox, 4)
local statBars = {}
local STAT_COLORS = { Health = P.Emerald, Power = P.Gold, Defense = P.Teal, Speed = P.Amethyst }
local STAT_LABELS = { Health = "VITALITY", Power = "FIREPOWER", Defense = "ARMOR", Speed = "MOBILITY" }
for i, name in Classes.StatNames do
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i }, statsBox)
	local caption = label(row, STAT_LABELS[name], 10, LIGHT, IronUi.Bold)
	place(caption, 0, 0, 80, 18)
	local track = new("Frame", {
		BackgroundColor3 = P.Frame,
		Position = UDim2.fromOffset(84, 5),
		Size = UDim2.fromOffset(192, 8),
		ClipsDescendants = true,
	}, row)
	UiKit.round(track, 2)
	local fill = new("Frame", { BackgroundColor3 = STAT_COLORS[name], Size = UDim2.fromScale(0, 1) }, track)
	UiKit.round(fill, 2)
	new("UIGradient", { Color = ColorSequence.new(STAT_COLORS[name]:Lerp(P.Frame, 0.35), STAT_COLORS[name]) }, fill)
	local number = label(row, "0", 12, STAT_COLORS[name], IronUi.Bold)
	place(number, 282, 0, 42, 18)
	number.TextXAlignment = Enum.TextXAlignment.Right
	statBars[name] = { Fill = fill, Number = number }
end

local gearButton = bigButton(hero, "OPEN ARMORY", P.Teal, function()
	CharacterUI.open()
end)
gearButton.AnchorPoint = Vector2.new(0.5, 1)
gearButton.Position = UDim2.new(0.5, 0, 1, -16)

-- Middle: the Mine and the workshops ------------------------------------------------------------------------

local MID_X, MID_W = 392, 480
local mine = panel(root, MID_X, TOP, MID_W, 250, Color3.fromRGB(230, 130, 40))
local mineTitle = IronUi.title(mine, "MOON MINE", 30, P.Text)
mineTitle.AutomaticSize = Enum.AutomaticSize.None
local sector = label(mine, "L U N A R   F R O N T I E R", 10, P.Gold)
place(sector, 24, 14, 260, 14)
place(mineTitle, 22, 30, 300, 36)
local mineLine1 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine1, 24, 70, 280, 22)
local mineLine2 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine2, 24, 96, 280, 22)
local mineLine3 = label(
	mine,
	"Break lunar rock. Recover charged stones and lost equipment. Push deeper for rarer finds.",
	14,
	P.Dim,
	CHUNKY
)
place(mineLine3, 24, 124, 260, 40)
mineLine3.TextWrapped = true
mineLine3.TextYAlignment = Enum.TextYAlignment.Top
-- A quiet lunar illustration made from native UI geometry.
local moon = new("Frame", {
	Position = UDim2.fromOffset(326, 74),
	Size = UDim2.fromOffset(124, 124),
	BackgroundColor3 = Color3.fromRGB(53, 88, 130),
	BorderSizePixel = 0,
}, mine)
UiKit.round(moon, 62)
new("UIStroke", { Color = P.Teal, Thickness = 2, Transparency = 0.25 }, moon)
-- Lit planetary preview, rather than a flat placeholder moon icon.
local lunarView = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Ambient = Color3.fromRGB(54, 71, 100),
	LightColor = Color3.fromRGB(203, 229, 255),
	LightDirection = Vector3.new(-1, -0.4, -0.7),
}, moon)
UiKit.round(lunarView, 62)
local lunarWorld = new("WorldModel", {}, lunarView)
local lunarModel = new("Model", {}, lunarWorld)
new("Part", {
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(5, 5, 5),
	Anchored = true,
	Color = Color3.fromRGB(101, 124, 155),
	Material = Enum.Material.Slate,
}, lunarModel)
for _, spec in { { -0.8, 0.7, -2.05, 0.9 }, { 0.85, -0.3, -2.15, 0.65 }, { -0.6, -1.1, -1.9, 0.55 } } do
	new("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(spec[4], spec[4], spec[4] * 0.2),
		Position = Vector3.new(spec[1], spec[2], spec[3]),
		Anchored = true,
		Color = Color3.fromRGB(40, 55, 77),
		Material = Enum.Material.Slate,
	}, lunarModel)
end
local lunarCamera = new("Camera", { FieldOfView = 38 }, lunarView)
lunarCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -9), Vector3.zero)
lunarView.CurrentCamera = lunarCamera
IronUi.animate(lunarView, function(t)
	lunarModel:PivotTo(CFrame.Angles(0, math.sin(t * 0.18) * 0.18, -0.12))
end)
for _, spec in { { 148, 0.6 }, { 176, 0.83 } } do
	local orbit = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(388, 136),
		Size = UDim2.fromOffset(spec[1], spec[1]),
	}, mine)
	UiKit.round(orbit, spec[1] / 2)
	new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = spec[2] }, orbit)
end
local crystal = new("Frame", {
	Position = UDim2.fromOffset(338, 158),
	Size = UDim2.fromOffset(36, 36),
	Rotation = 45,
	BackgroundColor3 = P.Teal,
	BorderSizePixel = 0,
}, mine)
UiKit.round(crystal, 5)
new("UIStroke", { Color = Color3.fromRGB(159, 255, 255), Thickness = 2, Transparency = 0.2 }, crystal)
IronUi.animate(crystal, function(t)
	crystal.Position = UDim2.fromOffset(338, 158 + math.sin(t * 1.5) * 5)
	crystal.Rotation = 45 + math.sin(t) * 8
end)
new("UIGradient", { Rotation = 45, Color = ColorSequence.new(P.Teal, P.Emerald) }, crystal)
local digButton = bigButton(mine, "BEGIN EXPEDITION", Color3.fromRGB(255, 167, 46), function()
	MineUI.open()
end)
digButton.Position = UDim2.fromOffset(22, 180)
digButton.Size = UDim2.fromOffset(0, 54)
digButton.TextSize = 19
IronUi.shine(digButton, 6)
local digHint = keyChip(digButton, "M")
digHint.AnchorPoint = Vector2.new(0, 0.5)
digHint.Position = UDim2.new(1, 10, 0.5, 0)
local freeBadge = label(mine, "", 16, Color3.new(1, 1, 1), CHUNKY)
freeBadge.BackgroundTransparency = 0
freeBadge.BackgroundColor3 = Color3.fromRGB(18, 93, 79)
freeBadge.AnchorPoint = Vector2.new(1, 0)
place(freeBadge, 0, 0, 120, 30)
freeBadge.AnchorPoint = Vector2.new(1, 0)
freeBadge.Position = UDim2.new(1, -16, 0, 16)
freeBadge.Rotation = 0
freeBadge.TextXAlignment = Enum.TextXAlignment.Center
freeBadge.TextYAlignment = Enum.TextYAlignment.Center
UiKit.round(freeBadge, 15)

-- The four workshop cards, two by two.
type Card = { Frame: Frame, Line: TextLabel }
local function workshop(
	x: number,
	y: number,
	_icon: string,
	name: string,
	key: string,
	color: Color3,
	button: string,
	onClick: () -> ()
): Card
	local card = panel(root, x, y, 234, 175, color)
	local medallion = new("Frame", {
		BackgroundColor3 = color:Lerp(P.Frame, 0.55),
		Position = UDim2.fromOffset(14, 16),
		Size = UDim2.fromOffset(38, 38),
	}, card)
	UiKit.round(medallion, 10)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.2 }, medallion)
	local emblem = IronUi.emblem(medallion, name, color, 32)
	emblem.Position = UDim2.fromOffset(3, 3)
	-- A large, low-contrast emblem makes each service feel illustrated.
	local watermark = IronUi.emblem(card, name, color, 86)
	watermark.Position = UDim2.fromOffset(135, 78)
	for _, piece in watermark:GetDescendants() do
		if piece:IsA("Frame") then
			piece.BackgroundTransparency = math.max(piece.BackgroundTransparency, 0.94)
		elseif piece:IsA("UIStroke") then
			piece.Transparency = 0.94
		end
	end
	local head = IronUi.title(card, string.upper(name), 17)
	head.AutomaticSize = Enum.AutomaticSize.None
	place(head, 60, 22, 124, 28)
	local line = label(card, "", 13, LIGHT, IronUi.Body)
	place(line, 16, 68, 204, 44)
	line.TextWrapped = true
	line.TextYAlignment = Enum.TextYAlignment.Top
	local b = IronUi.gemButton(card, button, color, onClick)
	b.TextSize = 13
	b.Size = UDim2.fromOffset(198, 38)
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 16, 1, -14)
	keyChip(card, key)
	return { Frame = card, Line = line }
end
local ROW1, ROW2 = TOP + 262, TOP + 262 + 187
local craftCard = workshop(MID_X, ROW1, "⇄", "Trade", "T", Color3.fromRGB(245, 133, 76), "Trade equipment", function()
	TradeUI.open()
end)
local enchantCard = workshop(
	MID_X + 246,
	ROW1,
	"✦",
	"Enchant",
	"E",
	Color3.fromRGB(170, 89, 255),
	"Attune gems",
	function()
		CharacterUI.open()
	end
)
local cutCard = workshop(MID_X, ROW2, "◇", "Equipment", "C", Color3.fromRGB(39, 187, 244), "Open armory", function()
	CharacterUI.open()
end)
local sellCard = workshop(
	MID_X + 246,
	ROW2,
	"◎",
	"Exchange",
	"V",
	Color3.fromRGB(255, 194, 57),
	"Sell stones",
	function()
		ForgeUI.open("Sell", true)
	end
)

-- Right: inventory ------------------------------------------------------------------------------------------

local INV_X = 888
local inventory = panel(root, INV_X, TOP, W - INV_X - 16, H - TOP - 16, Color3.fromRGB(60, 90, 150))
local invTitle = IronUi.title(inventory, "VAULT", 24)
invTitle.AutomaticSize = Enum.AutomaticSize.None
place(invTitle, 18, 16, 130, 32)
local invCount = label(inventory, "", 14, LIGHT, CHUNKY)
place(invCount, 20, 48, 200, 18)
local pouchButton = IronUi.button(inventory, "Inspect [G]", false, function()
	InventoryUI.open()
end)
pouchButton.AnchorPoint = Vector2.new(1, 0)
pouchButton.Position = UDim2.new(1, -14, 0, 16)

local gemsHead = label(inventory, "RECOVERED SAGA STONES", 12, P.Gold, CHUNKY)
place(gemsHead, 18, 76, 200, 18)
local gemGrid = new("ScrollingFrame", {
	BackgroundColor3 = P.Frame,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(14, 98),
	Size = UDim2.new(1, -28, 0, 330),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = P.Edge,
}, inventory)
UiKit.round(gemGrid, 6)
new("UIStroke", { Color = P.Edge, Transparency = 0.65, Thickness = 1 }, gemGrid)
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

local matsHead = label(inventory, "EQUIPMENT COLLECTION", 12, P.Gold, CHUNKY)
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
	UiKit.round(card, 6)
	new(
		"UIStroke",
		{ Color = tier, Transparency = 0.2, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		card
	)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(tier:Lerp(P.Slot, 0.6), P.Frame),
	}, card)
	new("Frame", { BackgroundColor3 = tier, Position = UDim2.new(0, 10, 1, -3), Size = UDim2.new(1, -20, 0, 2) }, card)
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
	local worth = label(card, commas(GemConfig.value(gem)) .. " coins", 13, Color3.new(1, 1, 1), CHUNKY)
	place(worth, 4, 70, 90, 18)
	worth.TextXAlignment = Enum.TextXAlignment.Center
	IronUi.juice(card, 1.02, 0.99)
	IronUi.highlight(card)
	if gem.Tier == "UltraRare" then
		IronUi.shine(card, 6)
	end
	card.Activated:Connect(function()
		InventoryUI.open({ InitialGemId = gem.Id })
	end)
end

local MATERIAL_ORDER = { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" }

local function refresh(profile)
	if not profile then
		return
	end
	hello.Text = "EXPEDITION COMMAND  /  " .. string.upper(player.DisplayName)
	coinsValue.Text = commas(profile.Coins or 0)
	marksValue.Text = tostring(Season.levelFor(profile.Season.XP))

	-- Hero.
	local character = profile.Character or {}
	local class = Classes.get(character.Class or Config.OnlyClass or "Warrior")
	if class then
		heroTitle.Text = class.Name
		heroSub.Text = "FRONTIER OPERATIVE  /  " .. string.upper(player.DisplayName)
		for _, key in Slots.Order do
			local roll = GearRolls.get(character, key)
			local rarity = GearRolls.Rarities[if roll then roll.Rarity else 1]
			gearSlots[key].Rail.BackgroundColor3 = rarity.Color
			gearSlots[key].Name.TextColor3 = rarity.Color
			drawGear(
				gearSlots[key],
				Classes.gear(class.Id, Slots.Definitions[key].Kind, character[key]),
				character[key .. "Quality"],
				character[key .. "Gem"]
			)
		end
		local ratings = Classes.ratings(character)
		for name, bar in statBars do
			local rating = ratings[name]
			local total = rating.Base + rating.Bonus
			bar.Fill.Size = UDim2.fromScale(math.clamp(total / 150, 0, 1), 1)
			bar.Number.Text = tostring(math.floor(total + 0.5))
		end
	end

	-- The Mine.
	local quota = profile.Quota or {}
	local daily = profile.DailyQuota or Config.DailyQuota
	local weekly = profile.WeeklyQuota or Config.WeeklyQuota
	local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
	mineLine1.Text = string.format("Daily entries  %d / %d", free, daily)
	local best = profile.Stats and profile.Stats.BestDepth or 0
	mineLine2.Text = if best > 0 then "Deepest shaft  " .. best else "Deeper shafts. Rarer discoveries."
	freeBadge.Visible = free > 0
	freeBadge.Text = free .. " free entries"

	-- Expedition services.
	local cut = #(profile.Gems or {})
	craftCard.Line.Text = "Trade recovered gear with other operatives. Both players approve the exchange."
	enchantCard.Line.Text = if cut > 0
		then string.format("%d gems ready to socket into any of your six items.", cut)
		else "Mine naturally cut gems to enchant your equipment."
	cutCard.Line.Text = "Compare equipment, swap your loadout and attune all six sockets."

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
		local row = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = P.Frame,
			LayoutOrder = i,
		}, matsGrid)
		row.Activated:Connect(function()
			CharacterUI.open()
		end)
		UiKit.round(row, 10)
		new("UIStroke", { Color = P.Edge, Transparency = 0.55, Thickness = 1 }, row)
		IronUi.highlight(row)
		local swatch = new("Frame", {
			BackgroundColor3 = P.Teal,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 17),
			Size = UDim2.fromOffset(8, 8),
		}, row)
		UiKit.round(swatch, 4)
		local name = label(row, Slots.Definitions[id].Label, 13, LIGHT, CHUNKY)
		place(name, 30, 3, 130, 16)
		local ownedCount = 0
		for _ in (profile.Owned or {})[Slots.Definitions[id].Kind] or {} do
			ownedCount += 1
		end
		local count = label(row, tostring(ownedCount) .. " owned", 14, Color3.new(1, 1, 1), HEADING)
		place(count, 30, 19, 125, 21)
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
player.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Intro" then
		gui.Enabled = false
	end
end)
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
	T = function()
		TradeUI.open()
	end,
	E = function()
		CharacterUI.open()
	end,
	C = CharacterUI.open,
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
	Enum.KeyCode.T,
	Enum.KeyCode.E,
	Enum.KeyCode.C,
	Enum.KeyCode.V,
	Enum.KeyCode.G,
	Enum.KeyCode.B
)
