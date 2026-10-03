-- Saga Miners command deck: live equipment, sockets and backpack alongside
-- expeditions, the Market, and clearly marked future social spaces.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
if not Config.MenuOnly then
	return
end

local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineScene = require(script.Parent.Modules.MineScene)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local SurgeArrayUI = require(script.Parent.Modules.SurgeArrayUI)
local SeasonUI = require(script.Parent.Modules.SeasonUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
local SocialUI = require(script.Parent.Modules.SocialUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors
local CHUNKY = IronUi.Chunky
local LIGHT = P.Dim

local function launch(action)
	CharacterUI.cancelDrag()
	action()
end
local W, H = 1432, 720

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
		ColorSequenceKeypoint.new(0, Color3.fromRGB(19, 23, 38)),
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
	TextTransparency = 0.95,
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

-- The layout is designed at 1432x720 (wide and short, to suit landscape
-- screens) and scaled to fit the screen, below
-- Roblox's own top bar (its menu buttons sit in the top-left corner).
local TOPBAR = 54
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
	-- Small inset brackets give the panels depth without surrounding text with glow.
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local bracket = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = corner,
			Position = UDim2.new(corner.X, if corner.X == 0 then 5 else -5, corner.Y, if corner.Y == 0 then 5 else -5),
			Size = UDim2.fromOffset(10, 10),
		}, frame)
		for _, size in { Vector2.new(10, 1), Vector2.new(1, 10) } do
			new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = tint,
				BackgroundTransparency = 0.55,
				AnchorPoint = corner,
				Position = UDim2.fromScale(corner.X, corner.Y),
				Size = UDim2.fromOffset(size.X, size.Y),
			}, bracket)
		end
	end
	return frame
end

local function label(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local t = text(parent, value, size, color or Color3.new(1, 1, 1), font or IronUi.Body)
	t.AutomaticSize = Enum.AutomaticSize.None
	t.TextTruncate = Enum.TextTruncate.AtEnd
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
	chip.Visible = UserInputService.KeyboardEnabled
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

-- Header ----------------------------------------------------------------------------------------------------

local logo = IronUi.badge(root, "◆", 44, P.Gold)
logo.Position = UDim2.fromOffset(18, 8)
logo.Rotation = 0
local title = IronUi.wordmark(root)
place(title, 76, 4, 400, 40)
local hello = label(root, "", 13, P.Gold, IronUi.Bold)
place(hello, 77, 40, 400, 18)
local readiness = label(root, "LOADOUT", 11, P.Dim, IronUi.Bold)
place(readiness, 500, 10, 230, 16)
local readinessValue = label(root, "Syncing equipment…", 14, P.Text, IronUi.Body)
place(readinessValue, 500, 30, 270, 22)

local wallet = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromOffset(W - 16, 6),
	Size = UDim2.fromOffset(0, 48),
	AutomaticSize = Enum.AutomaticSize.X,
}, root)
UiKit.list(wallet, 10, true)
local function pill(order: number, caption: string, color: Color3, width: number): (Frame, TextLabel)
	local frame = new("Frame", {
		BackgroundColor3 = P.Frame,
		Size = UDim2.fromOffset(width, 44),
		LayoutOrder = order,
	}, wallet)
	UiKit.round(frame, 6)
	new("UIStroke", { Color = IronUi.mute(color), Thickness = 1, Transparency = 0.45 }, frame)
	local ic = label(frame, caption, 12, color, IronUi.Bold)
	place(ic, 12, 6, width - 24, 12)
	local value = label(frame, "0", 21, Color3.new(1, 1, 1), IronUi.Heading)
	place(value, 12, 18, width - 24, 21)
	value.TextXAlignment = Enum.TextXAlignment.Left
	return frame, value
end
local _, coinsValue = pill(1, "COINS", P.Gold, 160)
-- The Season level doubles as the way into the Season Path.
local seasonFrame, marksValue = pill(2, "SEASON", P.Teal, 170)
local seasonTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.new(0, 12, 1, -4),
	Size = UDim2.new(1, -24, 0, 2),
}, seasonFrame)
UiKit.round(seasonTrack, 2)
local seasonFill = new("Frame", { BackgroundColor3 = P.Teal, Size = UDim2.fromScale(0, 1) }, seasonTrack)
UiKit.round(seasonFill, 2)
local seasonAlert = label(seasonFrame, "", 12, Color3.new(1, 1, 1), IronUi.Bold)
seasonAlert.BackgroundTransparency = 0
seasonAlert.BackgroundColor3 = P.Bad
seasonAlert.AnchorPoint = Vector2.new(0.5, 0.5)
seasonAlert.Position = UDim2.new(1, -2, 0, 2)
seasonAlert.Size = UDim2.fromOffset(20, 20)
seasonAlert.TextXAlignment = Enum.TextXAlignment.Center
seasonAlert.ZIndex = 4
seasonAlert.Visible = false
UiKit.round(seasonAlert, 10)
local seasonHit = new("TextButton", {
	Text = "",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 5,
}, seasonFrame)
seasonHit:SetAttribute("UiSound", "Open")
IronUi.highlight(seasonHit, seasonFrame)
seasonHit.Activated:Connect(function()
	launch(SeasonUI.toggle)
end)
local shopButton = IronUi.gemButton(wallet, "Supply Depot  [B]", P.Amethyst, function()
	launch(ShopUI.toggle)
end)
shopButton.LayoutOrder = 3
shopButton.Size = UDim2.fromOffset(0, 44)
shopButton.TextSize = 17
-- Who's here: the count of players in the server opens Social.
local onlineFrame, onlineValue = pill(4, "ONLINE  [P]", P.Good, 130)
local onlineHit = new("TextButton", {
	Text = "",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 5,
}, onlineFrame)
onlineHit:SetAttribute("UiSound", "Open")
IronUi.highlight(onlineHit, onlineFrame)
onlineHit.Activated:Connect(function()
	launch(SocialUI.open)
end)
local function countOnline()
	onlineValue.Text = tostring(#Players:GetPlayers())
end
-- The build, so playtest reports name it (Config.Playtest.Build).
if Config.Playtest and Config.Playtest.Build then
	local buildTag =
		text(gui, Config.Playtest.Build .. "   ·   Feedback & invites in Social [P]", 11, P.Dim, IronUi.Bold)
	buildTag.AutomaticSize = Enum.AutomaticSize.None
	buildTag.AnchorPoint, buildTag.Position = Vector2.new(0, 1), UDim2.new(0, 12, 1, -6)
	buildTag.Size = UDim2.fromOffset(520, 14)
	buildTag.TextTransparency = 0.25
end
countOnline()
Players.PlayerAdded:Connect(countOnline)
Players.PlayerRemoving:Connect(function()
	task.defer(countOnline)
end)

-- Mission strip: the Moon Mine, the Market and what's coming ------------------------------------------------

local STRIP_Y, STRIP_H = 66, 110

local mine = panel(root, 16, STRIP_Y, 630, STRIP_H, Color3.fromRGB(230, 130, 40))
local sector = label(mine, "LUNAR FRONTIER", 11, P.Gold, IronUi.Bold)
place(sector, 20, 12, 200, 14)
local mineTitle = label(mine, "MOON MINE", 26, P.Text, IronUi.Heading)
place(mineTitle, 18, 28, 240, 32)
local mineLine1 = label(mine, "", 14, P.Text, IronUi.Body)
place(mineLine1, 20, 64, 250, 20)
local mineLine2 = label(mine, "", 12, P.Dim, IronUi.Body)
place(mineLine2, 20, 84, 250, 18)
local allowanceTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(20, 104),
	Size = UDim2.fromOffset(236, 3),
}, mine)
UiKit.round(allowanceTrack, 2)
local allowanceFill = new("Frame", {
	BackgroundColor3 = P.Gold,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(0, 1),
}, allowanceTrack)
UiKit.round(allowanceFill, 2)
-- A small lit moon between the details and the button.
local moon = new("Frame", {
	Position = UDim2.fromOffset(266, 17),
	Size = UDim2.fromOffset(76, 76),
	BackgroundColor3 = Color3.fromRGB(53, 88, 130),
}, mine)
UiKit.round(moon, 38)
new("UIStroke", { Color = P.Teal, Thickness = 2, Transparency = 0.25 }, moon)
local lunarView = new("ViewportFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Ambient = Color3.fromRGB(54, 71, 100),
	LightColor = Color3.fromRGB(203, 229, 255),
	LightDirection = Vector3.new(-1, -0.4, -0.7),
}, moon)
UiKit.round(lunarView, 38)
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
local digButton = bigButton(mine, "BEGIN EXPEDITION", Color3.fromRGB(255, 167, 46), function()
	-- Expeditions are on foot: off to the mining site.
	launch(MineScene.begin)
end)
digButton.AnchorPoint = Vector2.new(1, 0.5)
digButton.Position = UDim2.new(1, -54, 0.5, 0)
digButton.Size = UDim2.fromOffset(0, 50)
digButton.TextSize = 19
IronUi.shine(digButton, 6)
local digHint = keyChip(mine, "M")
digHint.AnchorPoint = Vector2.new(1, 0.5)
digHint.Position = UDim2.new(1, -16, 0.5, 0)

-- Market keeps the existing player-to-player trade system.
local market = panel(root, 658, STRIP_Y, 300, STRIP_H, P.Gold)
local marketIcon = IronUi.emblem(market, "Trade", P.Gold, 34)
marketIcon.Position = UDim2.fromOffset(18, 14)
local marketTitle = label(market, "MARKET", 21, P.Text, IronUi.Heading)
place(marketTitle, 60, 16, 120, 30)
local marketCopy = label(market, "Swap gear with other miners. Both confirm.", 12, LIGHT, IronUi.Body)
place(marketCopy, 20, 56, 150, 40)
marketCopy.TextWrapped = true
marketCopy.TextYAlignment = Enum.TextYAlignment.Top
local marketButton = IronUi.gemButton(market, "OPEN  [T]", P.Gold, function()
	launch(TradeUI.open)
end)
marketButton.AnchorPoint = Vector2.new(1, 0.5)
marketButton.Position = UDim2.new(1, -18, 0.5, 0)
marketButton.Size = UDim2.fromOffset(0, 42)
marketButton.TextSize = 15

-- Activities switched off in Config.Features: dimmed under a CLOSED tag.
do
	local features = Config.Features or {}
	local function closed(frame: Frame)
		local veil = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(6, 8, 14),
			BackgroundTransparency = 0.06,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
		}, frame)
		UiKit.round(veil, 6)
		local tag = label(veil, "CLOSED", 22, P.Text, IronUi.Heading)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.ZIndex = 51
		tag.Position = UDim2.fromOffset(0, 30)
		tag.Size = UDim2.new(1, 0, 0, 28)
		local why = label(veil, "Off for this playtest. Try the Arena!", 13, P.Dim, IronUi.Body)
		why.TextXAlignment = Enum.TextXAlignment.Center
		why.ZIndex = 51
		why.Position = UDim2.fromOffset(0, 62)
		why.Size = UDim2.new(1, 0, 0, 18)
	end
	if features.Mining == false then
		closed(mine)
	end
	if features.Market == false then
		closed(market)
	end
end

-- Training and explicit PvP sessions share the Arena; training visitors are protected.
local social = panel(root, 970, STRIP_Y, W - 986, STRIP_H, P.Teal)
local socialTitle = label(social, "COMBAT ARENA", 19, P.Text, IronUi.Heading)
place(socialTitle, 20, 14, 240, 28)
local socialCopy = label(social, "Train, fight the rival, or duel other players.", 12, LIGHT, IronUi.Body)
place(socialCopy, 20, 44, 270, 18)
socialCopy.TextWrapped = true
socialCopy.TextYAlignment = Enum.TextYAlignment.Top
-- The Surge Array at a glance: the three gem sockets. Click to open the loadout.
local surgeStrip = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 8),
	Size = UDim2.fromOffset(126, 56),
}, social)
local surgeSockets = {}
for i, key in { "Q", "E", "R" } do
	local circle = new("Frame", {
		BackgroundColor3 = P.Inset,
		Position = UDim2.fromOffset((i - 1) * 46, 0),
		Size = UDim2.fromOffset(34, 34),
	}, surgeStrip)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, circle)
	local ring = new("UIStroke", { Color = LIGHT, Thickness = 2, Transparency = 0.4 }, circle)
	local glyph = label(circle, "+", 15, LIGHT, IronUi.Bold)
	glyph.Size, glyph.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	glyph.TextYAlignment = Enum.TextYAlignment.Center
	-- The key, centred under its socket.
	local keyLabel = label(surgeStrip, key, 10, P.Gold, IronUi.Bold)
	place(keyLabel, (i - 1) * 46, 38, 34, 12)
	keyLabel.TextXAlignment = Enum.TextXAlignment.Center
	surgeSockets[key] = { Ring = ring, Glyph = glyph }
end
surgeStrip.Activated:Connect(function()
	launch(SurgeArrayUI.open)
end)
local function arenaButton(caption, color, x, w, onClick)
	local b = IronUi.gemButton(social, caption, color, onClick)
	b.Position, b.Size, b.TextSize = UDim2.fromOffset(x, 70), UDim2.fromOffset(w, 32), 12
	return b
end
arenaButton("TRAIN", P.Teal, 16, 60, function()
	launch(function()
		ArenaScene.enter(false)
	end)
end)
arenaButton("RIVAL", P.Amethyst, 82, 62, function()
	launch(function()
		ArenaScene.enter(true)
	end)
end)
-- Real players: the rated 1v1 queue, and Social for parties, 2v2 and chat.
arenaButton("1v1 QUEUE", P.Gold, 150, 96, function()
	launch(SocialUI.findDuel)
end)
arenaButton("SOCIAL [P]", P.Good, 252, 96, function()
	launch(SocialUI.open)
end)
arenaButton("TREE [K]", P.Teal, 354, 76, function()
	launch(AugmentTreeUI.open)
end)

-- The armory fills the rest: equipment, sockets, stats, backpack and spare gear.
CharacterUI.mount(root, gui, UDim2.fromOffset(16, STRIP_Y + STRIP_H + 12))

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

local function refresh(profile)
	if not profile then
		return
	end
	hello.Text = "EXPEDITION COMMAND  /  " .. string.upper(player.DisplayName)
	coinsValue.Text = commas(profile.Coins or 0)
	local seasonData = profile.Season or { XP = 0, Claimed = {} }
	local level, into, need = Season.levelFor(seasonData.XP or 0)
	marksValue.Text = "LV " .. level
	seasonFill.Size = UDim2.fromScale(if level >= Season.MaxLevel then 1 else math.clamp(into / need, 0, 1), 1)
	local unclaimed = 0
	for l = 1, level do
		if not (seasonData.Claimed or {})[tostring(l)] then
			unclaimed += 1
		end
	end
	seasonAlert.Visible = unclaimed > 0
	seasonAlert.Text = if unclaimed > 9 then "9+" else tostring(unclaimed)
	local equipped, surges = 0, 0
	local loadout = profile.Character or {}
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" } do
		if loadout[slot] then
			equipped += 1
		end
	end
	for _, key in { "Q", "E", "R" } do
		if Tech.surgeGem(loadout, key) then
			surges += 1
		end
	end
	readinessValue.Text = string.format("%d/6 equipped   ·   %d/3 surges", equipped, surges)
	readinessValue.TextColor3 = if equipped == 6 and surges == 3 then P.Teal else P.Gold
	local quota = profile.Quota or {}
	local daily = profile.DailyQuota or Config.DailyQuota
	local weekly = profile.WeeklyQuota or Config.WeeklyQuota
	local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
	allowanceFill.Size = UDim2.fromScale(math.clamp(free / math.max(1, daily), 0, 1), 1)
	allowanceFill.BackgroundColor3 = if free > 0 then P.Gold else P.Dim
	mineLine1.Text = if free > 0
		then string.format("%d of %d free walls left today", free, daily)
		else "Free walls used up today"
	local best = profile.Stats and profile.Stats.BestDepth or 0
	mineLine2.Text = if best > 0 then "Deepest shaft: depth " .. best else "Dig deeper for rarer finds"
	for key, socket in surgeSockets do
		local gem = Tech.surgeGem(profile.Character, key)
		local definition = gem and Tech.surgeStats(gem)
		local color = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else LIGHT
		socket.Ring.Color, socket.Ring.Transparency = color, if gem then 0 else 0.4
		socket.Glyph.Text, socket.Glyph.TextColor3 = if definition then definition.Icon or "◆" else "+", color
	end
end
GemClient.Changed:Connect(refresh)
if GemClient.Profile then
	refresh(GemClient.Profile)
end

-- Keep the entire dashboard, including its embedded armory, behind the intro.
local function introOpen(): boolean
	return player.PlayerGui:FindFirstChild("Intro") ~= nil
end
-- One rule for showing the dashboard: never over the intro, an Arena session
-- or an expedition (each of those has its own full-screen view).
local function syncVisibility()
	gui.Enabled = not introOpen() and player:GetAttribute("CombatSession") == nil and not MineScene.isActive()
end
syncVisibility()
player:GetAttributeChangedSignal("CombatSession"):Connect(syncVisibility)
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
		syncVisibility()
		CharacterUI.open()
		maybeWelcome()
	end
end)
GemClient.Changed:Connect(maybeWelcome)
task.defer(maybeWelcome)

-- Equipment and enchantment are on the dashboard; only destinations need shortcuts.
local KEYS = {
	K = AugmentTreeUI.toggle,
	L = SurgeArrayUI.toggle,
	M = MineScene.begin,
	T = TradeUI.open,
	B = ShopUI.toggle,
	J = SeasonUI.toggle,
	P = SocialUI.toggle,
}
ContextActionService:BindAction(
	"GemsoulDashboard",
	function(_, state, inputObject)
		if state == Enum.UserInputState.Begin and gui.Enabled and not introOpen() then
			local action = KEYS[inputObject.KeyCode.Name]
			if action then
				launch(action)
			end
		end
		return Enum.ContextActionResult.Pass
	end,
	false,
	Enum.KeyCode.K,
	Enum.KeyCode.L,
	Enum.KeyCode.M,
	Enum.KeyCode.T,
	Enum.KeyCode.B,
	Enum.KeyCode.J,
	Enum.KeyCode.P
)
