-- The Inventory: your character, worn gear and sockets, loadouts, and the
-- bags (Modules/InventoryScreen). Opened from the lobby's INVENTORY tile, over
-- the Outpost; everything else (play, store, ranks, social) lives in the lobby.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Season = require(ReplicatedStorage.Shared.Season)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
if not Config.MenuOnly then
	return
end

local InventoryScreen = require(script.Parent.Modules.InventoryScreen)
-- These run on their own once loaded (chat, trades, the Outpost, the
-- Arena and Social), whether or not the Inventory shows them.
require(script.Parent.Modules.ChatFrame)
require(script.Parent.Modules.TradeUI)
require(script.Parent.Modules.OutpostScene)
require(script.Parent.Modules.ArenaScene)
require(script.Parent.Modules.SocialUI)
local OutpostRules = require(ReplicatedStorage.Shared.Outpost)
local ChargeMeter = require(script.Parent.Modules.ChargeMeter)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local MineScene = require(script.Parent.Modules.MineScene)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local SurgeArrayUI = require(script.Parent.Modules.SurgeArrayUI)
local SeasonUI = require(script.Parent.Modules.SeasonUI)
local ShopUI = require(script.Parent.Modules.ShopUI)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new, text = IronUi.new, IronUi.text
local P = IronUi.Colors

local function launch(action)
	InventoryScreen.cancelDrag()
	action()
end
local W, H = 1432, 606

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
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 17, 44)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(11, 8, 22)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 14, 38)),
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
		BackgroundColor3 = Color3.fromRGB(220, 210, 255),
		BackgroundTransparency = 0.8,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(x, y),
	}, backdrop)
	if i % 7 == 0 then
		new("Frame", {
			BackgroundColor3 = Color3.fromRGB(220, 210, 255),
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(-3, 1),
			Size = UDim2.fromOffset(10, 2),
		}, star)
		new("Frame", {
			BackgroundColor3 = Color3.fromRGB(220, 210, 255),
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(1, -3),
			Size = UDim2.fromOffset(2, 10),
		}, star)
	end
end
-- The layout is designed at 1432x720 (wide and short, to suit landscape
-- screens) and scaled to fit the screen, below
-- Roblox's own top bar (its menu buttons sit in the top-left corner).
local TOPBAR = 54
-- A strip along the bottom stays clear for the chat bar (left) and the
-- owner's DEV button (right), so neither covers the panels.
local BOTTOM = 44
local safe = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, TOPBAR),
	Size = UDim2.new(1, 0, 1, -TOPBAR - BOTTOM),
}, gui)
local root = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
}, safe)
local fitScale = new("UIScale", {}, root)
local buildTag: TextLabel? = nil
local function fit()
	local screen = gui.AbsoluteSize
	-- Phones (a short landscape screen): no bottom strip (no build tag, and
	-- the DEV button sits up top), so the panels can be bigger.
	local phone = screen.Y > 0 and screen.Y < 500
	local bottom = if phone then 6 else BOTTOM
	safe.Size = UDim2.new(1, 0, 1, -TOPBAR - bottom)
	if buildTag then
		buildTag.Visible = not phone
	end
	if screen.X > 0 and screen.Y > TOPBAR + bottom then
		fitScale.Scale = math.min(screen.X / W, (screen.Y - TOPBAR - bottom) / H)
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

-- Header ----------------------------------------------------------------------------------------------------

local logo = IronUi.badge(root, "◆", 44, P.Gold)
logo.Position = UDim2.fromOffset(18, 8)
logo.Rotation = 0
local title = IronUi.wordmark(root)
place(title, 76, 4, 400, 40)
local hello = label(root, "", 13, InventoryScreen.Colors.Accent, IronUi.Bold)
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
		BackgroundColor3 = InventoryScreen.Colors.Panel,
		Size = UDim2.fromOffset(width, 44),
		LayoutOrder = order,
	}, wallet)
	UiKit.round(frame, 12)
	new("UIStroke", { Color = InventoryScreen.Colors.PanelEdge, Thickness = 1 }, frame)
	local ic = label(frame, caption, 12, color, IronUi.Bold)
	place(ic, 12, 6, width - 24, 12)
	local value = label(frame, "0", 21, Color3.new(1, 1, 1), IronUi.Heading)
	place(value, 12, 18, width - 24, 21)
	value.TextXAlignment = Enum.TextXAlignment.Left
	return frame, value
end
-- The free pick's charge (it refills while you're away; see ChargeMeter).
local pickFrame, pickValue = pill(0, "FREE PICK", ChargeMeter.Charging, 136)
local pickTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.new(0, 12, 1, -4),
	Size = UDim2.new(1, -24, 0, 2),
}, pickFrame)
UiKit.round(pickTrack, 2)
local pickFill = new("Frame", { BackgroundColor3 = ChargeMeter.Charging, Size = UDim2.fromScale(1, 1) }, pickTrack)
UiKit.round(pickFill, 2)
local pickCaption = pickFrame:FindFirstChildWhichIsA("TextLabel")
local _, coinsValue = pill(1, "COINS", P.Gold, 136)
-- The Season level doubles as the way into the Season Path.
local seasonFrame, marksValue = pill(2, "SEASON", P.Teal, 150)
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
-- The build, so playtest reports name it (Config.Playtest.Build).
if Config.Playtest and Config.Playtest.Build then
	local tag = text(gui, Config.Playtest.Build .. "   ·   Feedback in Social", 11, P.Dim, IronUi.Bold)
	tag.AutomaticSize = Enum.AutomaticSize.None
	-- Bottom centre: the chat bar has the left corner, the DEV button the right.
	tag.AnchorPoint, tag.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -15)
	tag.Size = UDim2.fromOffset(520, 14)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextTransparency = 0.25
	buildTag = tag
	fit()
end

-- The Inventory fills the rest: loadout on the left, bags on the right.
InventoryScreen.mount(root, gui, UDim2.fromOffset(16, 66))

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

-- The free pick's charge, ticking below.
local function refreshMining(profile)
	local outpost = profile.Outpost
	local charged, nextIn = ChargeMeter.read(outpost and outpost.Picks, outpost and outpost.SurveyAt)
	local color = if nextIn then ChargeMeter.Charging else ChargeMeter.Charged
	pickValue.Text = string.format("%d/%d", charged, ChargeMeter.Full)
	pickValue.TextColor3 = if charged > 0 then Color3.new(1, 1, 1) else P.Bad
	if pickCaption then
		pickCaption.Text = if nextIn then "FREE PICK  +" .. OutpostRules.clock(nextIn) else "FREE PICK  FULL"
		pickCaption.TextColor3 = color
	end
	pickFill.Size = UDim2.fromScale(math.clamp(charged / ChargeMeter.Full, 0, 1), 1)
	pickFill.BackgroundColor3 = color
end
task.spawn(function()
	while true do
		task.wait(1)
		if GemClient.Profile then
			refreshMining(GemClient.Profile)
		end
	end
end)

local function refresh(profile)
	if not profile then
		return
	end
	hello.Text = "INVENTORY  /  " .. string.upper(player.DisplayName)
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
	readinessValue.Text = string.format("%d/6 gear   ·   %d/3 powers on keys", equipped, surges)
	readinessValue.TextColor3 = if equipped == 6 and surges == 3 then P.Teal else P.Gold
	refreshMining(profile)
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
player.PlayerGui.ChildRemoved:Connect(function(child)
	if child.Name == "Intro" then
		syncVisibility()
		InventoryScreen.refresh()
	end
end)

-- Shortcuts for the Inventory's own windows.
local KEYS = {
	K = AugmentTreeUI.toggle,
	L = SurgeArrayUI.toggle,
	J = SeasonUI.toggle,
}
ContextActionService:BindAction("GemsoulDashboard", function(_, state, inputObject)
	if state == Enum.UserInputState.Begin and gui.Enabled and not introOpen() then
		local action = KEYS[inputObject.KeyCode.Name]
		if action then
			launch(action)
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.K, Enum.KeyCode.L, Enum.KeyCode.J)
