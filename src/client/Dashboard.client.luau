-- Saga Miners command deck: live equipment, sockets and backpack alongside
-- expeditions, the Market, and clearly marked future social spaces.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
if not Config.MenuOnly then
	return
end

local CharacterUI = require(script.Parent.Modules.CharacterUI)
local TradeUI = require(script.Parent.Modules.TradeUI)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineScene = require(script.Parent.Modules.MineScene)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local SeasonUI = require(script.Parent.Modules.SeasonUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
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

-- Header ----------------------------------------------------------------------------------------------------

local logo = IronUi.badge(root, "◆", 44, P.Gold)
logo.Position = UDim2.fromOffset(18, 8)
logo.Rotation = 0
local title = IronUi.wordmark(root)
place(title, 76, 4, 400, 40)
local hello = label(root, "", 13, P.Gold, IronUi.Bold)
place(hello, 77, 40, 400, 18)

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
	place(ic, 12, 0, 70, 44)
	local value = label(frame, "0", 21, Color3.new(1, 1, 1), IronUi.Heading)
	place(value, 70, 0, width - 82, 44)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return frame, value
end
local _, coinsValue = pill(1, "COINS", P.Gold, 160)
-- The Season level doubles as the way into the Season Path.
local seasonFrame, marksValue = pill(2, "SEASON", P.Teal, 170)
local seasonTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.new(0, 12, 1, -9),
	Size = UDim2.new(1, -24, 0, 4),
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

-- Mission strip: the Moon Mine, the Market and what's coming ------------------------------------------------

local STRIP_Y, STRIP_H = 66, 110

local mine = panel(root, 16, STRIP_Y, 660, STRIP_H, Color3.fromRGB(230, 130, 40))
local sector = label(mine, "LUNAR FRONTIER", 11, P.Gold, IronUi.Bold)
place(sector, 20, 12, 200, 14)
local mineTitle = label(mine, "MOON MINE", 26, P.Text, IronUi.Heading)
place(mineTitle, 18, 28, 240, 32)
local mineLine1 = label(mine, "", 15, Color3.new(1, 1, 1), CHUNKY)
place(mineLine1, 20, 64, 250, 20)
local mineLine2 = label(mine, "", 14, P.Dim, CHUNKY)
place(mineLine2, 20, 84, 250, 18)
-- A small lit moon between the details and the button.
local moon = new("Frame", {
	Position = UDim2.fromOffset(282, 17),
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
local market = panel(root, 688, STRIP_Y, 380, STRIP_H, P.Gold)
local marketIcon = IronUi.emblem(market, "Trade", P.Gold, 34)
marketIcon.Position = UDim2.fromOffset(18, 14)
local marketTitle = label(market, "MARKET", 21, P.Text, IronUi.Heading)
place(marketTitle, 60, 16, 160, 30)
local marketCopy = label(market, "Swap gear with other miners. Both confirm.", 13, LIGHT, IronUi.Body)
place(marketCopy, 20, 56, 200, 36)
marketCopy.TextWrapped = true
marketCopy.TextYAlignment = Enum.TextYAlignment.Top
local marketButton = IronUi.gemButton(market, "OPEN  [T]", P.Gold, function()
	launch(TradeUI.open)
end)
marketButton.AnchorPoint = Vector2.new(1, 0.5)
marketButton.Position = UDim2.new(1, -18, 0.5, 0)
marketButton.Size = UDim2.fromOffset(0, 42)
marketButton.TextSize = 15

-- Social spaces are honest placeholders: no simulated messages or working inputs.
local social = panel(root, 1080, STRIP_Y, W - 1096, STRIP_H, P.Teal)
local socialTitle = label(social, "COMBAT ARENA", 19, P.Text, IronUi.Heading)
place(socialTitle, 20, 16, 200, 28)
local soon = label(social, "WARRIORS", 11, P.Teal, IronUi.Bold)
soon.BackgroundTransparency = 0.8
soon.BackgroundColor3 = P.Teal
soon.TextXAlignment = Enum.TextXAlignment.Center
soon.AnchorPoint = Vector2.new(1, 0)
place(soon, 0, 0, 104, 22)
soon.Position = UDim2.new(1, -16, 0, 18)
UiKit.round(soon, 4)
local socialCopy = label(social, "Four actions. Your armor defines the fight.", 12, LIGHT, IronUi.Body)
place(socialCopy, 20, 46, W - 1136, 20)
socialCopy.TextWrapped = true
socialCopy.TextYAlignment = Enum.TextYAlignment.Top
local training = IronUi.gemButton(social, "TRAIN", P.Teal, function()
	launch(function()
		ArenaScene.enter(false)
	end)
end)
training.Position = UDim2.fromOffset(20, 72)
training.Size = UDim2.fromOffset(114, 32)
local pvp = IronUi.gemButton(social, "PVP ARENA", P.Gold, function()
	launch(function()
		ArenaScene.enter(true)
	end)
end)
pvp.Position = UDim2.fromOffset(152, 72)
pvp.Size = UDim2.fromOffset(138, 32)

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
	local quota = profile.Quota or {}
	local daily = profile.DailyQuota or Config.DailyQuota
	local weekly = profile.WeeklyQuota or Config.WeeklyQuota
	local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
	mineLine1.Text = if free > 0
		then string.format("%d of %d free walls left today", free, daily)
		else "Free walls used up today"
	local best = profile.Stats and profile.Stats.BestDepth or 0
	mineLine2.Text = if best > 0 then "Deepest shaft: depth " .. best else "Dig deeper for rarer finds"
end
GemClient.Changed:Connect(refresh)
if GemClient.Profile then
	refresh(GemClient.Profile)
end

-- Keep the entire dashboard, including its embedded armory, behind the intro.
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
		CharacterUI.open()
		maybeWelcome()
	end
end)
GemClient.Changed:Connect(maybeWelcome)
task.defer(maybeWelcome)

-- Equipment and enchantment are on the dashboard; only destinations need shortcuts.
local KEYS = { M = MineScene.begin, T = TradeUI.open, B = ShopUI.toggle, J = SeasonUI.toggle }
ContextActionService:BindAction("GemsoulDashboard", function(_, state, inputObject)
	if state == Enum.UserInputState.Begin and gui.Enabled and not introOpen() then
		local action = KEYS[inputObject.KeyCode.Name]
		if action then
			launch(action)
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.M, Enum.KeyCode.T, Enum.KeyCode.B, Enum.KeyCode.J)
