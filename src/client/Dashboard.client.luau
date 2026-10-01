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
local MineUI = require(script.Parent.Modules.MineUI)
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
local W, H = 1440, 820

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

-- The layout is designed at 1440x820 and scaled to fit the screen, below
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
	launch(ShopUI.toggle)
end)
shopButton.LayoutOrder = 3
shopButton.Size = UDim2.fromOffset(0, 46)

-- The armory is the dashboard, not a second modal or a duplicate inventory.
CharacterUI.mount(root, gui, UDim2.fromOffset(16, 84))

-- Mission rail ---------------------------------------------------------------------------
local TOP, MID_X, MID_W = 84, 1032, 392
local mine = panel(root, MID_X, TOP, MID_W, 250, Color3.fromRGB(230, 130, 40))
local mineTitle = IronUi.title(mine, "MOON MINE", 28, P.Text)
mineTitle.AutomaticSize = Enum.AutomaticSize.None
local sector = label(mine, "L U N A R   F R O N T I E R", 10, P.Gold)
place(sector, 24, 14, 260, 14)
place(mineTitle, 22, 30, 300, 36)
local mineLine1 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine1, 22, 76, 220, 22)
local mineLine2 = label(mine, "", 17, Color3.new(1, 1, 1), CHUNKY)
place(mineLine2, 22, 104, 218, 22)
local mineLine3 =
	label(mine, "Recover charged gems and lost equipment. Push deeper for rarer finds.", 14, P.Dim, CHUNKY)
place(mineLine3, 22, 134, 218, 42)
mineLine3.TextWrapped = true
mineLine3.TextYAlignment = Enum.TextYAlignment.Top
-- A quiet lunar illustration made from native UI geometry.
local moon = new("Frame", {
	Position = UDim2.fromOffset(272, 82),
	Size = UDim2.fromOffset(92, 92),
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
for _, spec in { { 110, 0.6 }, { 132, 0.83 } } do
	local orbit = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(318, 128),
		Size = UDim2.fromOffset(spec[1], spec[1]),
	}, mine)
	UiKit.round(orbit, spec[1] / 2)
	new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = spec[2] }, orbit)
end
local crystal = new("Frame", {
	Position = UDim2.fromOffset(276, 153),
	Size = UDim2.fromOffset(26, 26),
	Rotation = 45,
	BackgroundColor3 = P.Teal,
	BorderSizePixel = 0,
}, mine)
UiKit.round(crystal, 5)
new("UIStroke", { Color = Color3.fromRGB(159, 255, 255), Thickness = 2, Transparency = 0.2 }, crystal)
IronUi.animate(crystal, function(t)
	crystal.Position = UDim2.fromOffset(276, 153 + math.sin(t * 1.5) * 5)
	crystal.Rotation = 45 + math.sin(t) * 8
end)
new("UIGradient", { Rotation = 45, Color = ColorSequence.new(P.Teal, P.Emerald) }, crystal)
local digButton = bigButton(mine, "BEGIN EXPEDITION", Color3.fromRGB(255, 167, 46), function()
	launch(MineUI.open)
end)
digButton.Position = UDim2.fromOffset(22, 190)
digButton.Size = UDim2.fromOffset(0, 44)
digButton.TextSize = 19
IronUi.shine(digButton, 6)
local digHint = keyChip(digButton, "M")
digHint.AnchorPoint = Vector2.new(0, 0.5)
digHint.Position = UDim2.new(1, 10, 0.5, 0)
local freeBadge = label(mine, "", 12, Color3.new(1, 1, 1), CHUNKY)
freeBadge.BackgroundTransparency = 0
freeBadge.BackgroundColor3 = Color3.fromRGB(18, 93, 79)
freeBadge.AnchorPoint = Vector2.new(1, 0)
place(freeBadge, 0, 0, 102, 26)
freeBadge.AnchorPoint = Vector2.new(1, 0)
freeBadge.Position = UDim2.new(1, -16, 0, 16)
freeBadge.Rotation = 0
freeBadge.TextXAlignment = Enum.TextXAlignment.Center
freeBadge.TextYAlignment = Enum.TextYAlignment.Center
UiKit.round(freeBadge, 15)

-- Market retains the existing player-to-player trade system.
local market = panel(root, 1032, 348, 392, 138, P.Gold)
local marketIcon = IronUi.emblem(market, "Trade", P.Gold, 38)
marketIcon.Position = UDim2.fromOffset(18, 18)
local marketTitle = label(market, "MARKET", 21, P.Text, IronUi.Heading)
place(marketTitle, 66, 18, 220, 28)
keyChip(market, "T")
local marketCopy =
	label(market, "Exchange equipment with other miners. Both players confirm every trade.", 13, LIGHT, IronUi.Body)
place(marketCopy, 20, 52, 350, 34)
local marketButton = IronUi.gemButton(market, "OPEN MARKET", P.Gold, function()
	launch(TradeUI.open)
end)
marketButton.Position = UDim2.fromOffset(20, 94)
marketButton.Size = UDim2.fromOffset(0, 32)
marketButton.TextSize = 13

-- Social spaces are honest placeholders: no simulated messages or working inputs.
local function comingSoon(parent)
	local badge = label(parent, "COMING SOON", 10, P.Dim, IronUi.Bold)
	badge.TextXAlignment = Enum.TextXAlignment.Right
	place(badge, 250, 20, 122, 20)
end
local chat = panel(root, 1032, 500, 392, 170, P.Teal)
local chatTitle = label(chat, "GLOBAL CHAT", 18, P.Text, IronUi.Heading)
place(chatTitle, 20, 18, 220, 26)
comingSoon(chat)
local comms = label(chat, "STATION COMMS / OFFLINE", 10, P.Teal, IronUi.Bold)
place(comms, 20, 54, 352, 18)
local chatCopy =
	label(chat, "A place to share discoveries and meet other miners across the stars.", 13, LIGHT, IronUi.Body)
place(chatCopy, 20, 78, 350, 38)
local inputPlaceholder = IronUi.box(chat, UDim2.fromOffset(20, 126), UDim2.fromOffset(352, 28), P.Frame, 4)
local inputText = label(inputPlaceholder, "Messaging unavailable in this build", 11, P.Dim, IronUi.Body)
place(inputText, 10, 5, 332, 20)

local party = panel(root, 1032, 684, 392, 120, P.Amethyst)
local partyTitle = label(party, "PARTY", 18, P.Text, IronUi.Heading)
place(partyTitle, 20, 16, 200, 26)
comingSoon(party)
local partyCopy = label(
	party,
	"Your next expedition crew starts here. Invites and party management are on the way.",
	13,
	LIGHT,
	IronUi.Body
)
place(partyCopy, 20, 51, 350, 49)

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
	marksValue.Text = tostring(Season.levelFor(profile.Season and profile.Season.XP or 0))
	local quota = profile.Quota or {}
	local daily = profile.DailyQuota or Config.DailyQuota
	local weekly = profile.WeeklyQuota or Config.WeeklyQuota
	local free = math.max(0, math.min(daily - (quota.UsedToday or 0), weekly - (quota.UsedThisWeek or 0)))
	mineLine1.Text = string.format("Daily entries  %d / %d", free, daily)
	local best = profile.Stats and profile.Stats.BestDepth or 0
	mineLine2.Text = if best > 0 then "Deepest shaft  " .. best else "Deeper shafts. Rarer finds."
	freeBadge.Visible = true
	freeBadge.Text = if free > 0 then free .. " free entries" else "Quota used"
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
local KEYS = { M = MineUI.toggle, T = TradeUI.open, B = ShopUI.toggle }
ContextActionService:BindAction("GemsoulDashboard", function(_, state, inputObject)
	if state == Enum.UserInputState.Begin and gui.Enabled and not introOpen() then
		local action = KEYS[inputObject.KeyCode.Name]
		if action then
			launch(action)
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.M, Enum.KeyCode.T, Enum.KeyCode.B)
