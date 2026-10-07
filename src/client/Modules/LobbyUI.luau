--[[
	The lobby (the Saga Outpost): a big PLAY button at the bottom, tiles for
	your Inventory (the main dashboard), the Store, the Ranks and Social, and
	the PLAY menu that picks what to play:

	  PRACTICE  1v1 Practice    a rival miner, coins on a win (always open)
	            Squad Dungeon   three miners, a dungeon and its boss
	  RANKED    1v1 Ranked      real players, rating on the line

	Modes unlock as you play duels (Unlocks). The Inventory opens the full
	dashboard over the lobby, with a BACK TO LOBBY button to close it.

	  LobbyUI.setVisible(on)  Lobby.client shows it while you're in the lobby
	  LobbyUI.dashboardOpen() true while the dashboard is open over the lobby
	  LobbyUI.Unlocks         duels needed for each mode
]]
local Players = game:GetService("Players")

local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local LobbyUI = {}
LobbyUI.Unlocks = { Dungeon = 3, Casual = 3, Ranked = 10 }
-- Key art for each card (assets/images/lobby/*.png, painted by
-- tools/make_lobby_cards.py). 0 = not uploaded yet: the card shows its emblem.
-- Casual reuses the duel art (same fight, nothing on the line).
LobbyUI.Art = {
	Duel = 104755259743768,
	Dungeon = 85958638729400,
	Ranked = 108455735818338,
}
LobbyUI.Art.Casual = LobbyUI.Art.Duel

local GREEN = Color3.fromRGB(62, 220, 120)
local RED = Color3.fromRGB(232, 72, 72)
local CARD = Color3.fromRGB(16, 20, 32)

local gui = UiKit.gui("LobbyHud", 6)
gui.IgnoreGuiInset = false
gui.Enabled = false
-- Above the dashboard, so BACK TO LOBBY sits on top of it.
local top = UiKit.gui("LobbyTop", 30)
top.Enabled = false

local function text(parent, value, size, color, font, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or IronUi.Bold,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.55,
	}, parent)
end

local function played(): number
	local fromAttribute = player:GetAttribute("DuelsPlayed")
	if type(fromAttribute) == "number" then
		return fromAttribute
	end
	local profile = GemClient.Profile
	local record = profile and profile.Duel
	return if record then record.Played or 0 else 0
end

local function run(action: string, ...)
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if result and result.Message then
			UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
		end
	end)
end

local bar: Frame -- the bottom bar (below), hidden while the PLAY menu is open

-- The PLAY menu ---------------------------------------------------------------------------------

local picker = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 6, 12),
	BackgroundTransparency = 0.25,
	Visible = false,
	ZIndex = 20,
}, gui)
local stage = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1120, 560),
	BackgroundTransparency = 1,
	ZIndex = 20,
}, picker)
local stageScale = new("UIScale", {}, stage)
local function fitStage()
	local screen = gui.AbsoluteSize
	if screen.X > 0 then
		stageScale.Scale = math.min(1, (screen.X - 32) / 1120, (screen.Y - 24) / 612)
		stage.Position = UDim2.new(0.5, 0, 0.5, 26 * stageScale.Scale)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStage)

local function heading(value, color, x, align)
	local l = text(stage, value, 34, color, IronUi.Heading, align)
	l.Position, l.Size, l.ZIndex = UDim2.fromOffset(x, 0), UDim2.fromOffset(420, 44), 21
	return l
end
heading("PRACTICE", P.Text, 0, Enum.TextXAlignment.Left)
heading("VS PLAYERS", RED, 700, Enum.TextXAlignment.Right)
-- The divider between practice and the player modes.
new("Frame", {
	Position = UDim2.fromOffset(806, 60),
	Size = UDim2.fromOffset(2, 500),
	BackgroundColor3 = RED,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	ZIndex = 21,
}, stage)

local cards = {}
local function card(spec)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(spec.X, spec.Y),
		Size = UDim2.fromOffset(spec.W, spec.H),
		BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient carries the colour
		ZIndex = 21,
	}, stage)
	UiKit.round(b, 10)
	local stroke = new("UIStroke", { Color = spec.Color, Thickness = 2, Transparency = 0.2 }, b)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(spec.Color:Lerp(CARD, 0.62), CARD),
	}, b)
	local big = spec.H > 300
	local artId = LobbyUI.Art[spec.Art] or 0
	if artId ~= 0 then
		local art = new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. artId,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 21,
		}, b)
		UiKit.round(art, 10)
		-- A dark wash where the words sit: the bottom of a tall card, the
		-- left of a wide one.
		local shade = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(4, 6, 12),
			ZIndex = 22,
		}, b)
		UiKit.round(shade, 10)
		new("UIGradient", {
			Rotation = if big then 90 else 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if big then 1 else 0.1),
				NumberSequenceKeypoint.new(0.55, if big then 0.75 else 0.55),
				NumberSequenceKeypoint.new(1, if big then 0.1 else 1),
			}),
		}, shade)
	end
	local function place(label, x, y, w, h, align)
		label.Position, label.Size, label.ZIndex = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h), 23
		label.TextXAlignment = align
		return label
	end
	local emblem
	if big then
		-- Tall card: the emblem up top, the words at the bottom, centred.
		local center = Enum.TextXAlignment.Center
		emblem = IronUi.emblem(b, spec.Emblem, spec.Color, 120)
		emblem.Position = UDim2.fromOffset((spec.W - 120) / 2, 80)
		place(text(b, spec.Kicker, 22, spec.Color, IronUi.Heading), 12, spec.H - 150, spec.W - 24, 26, center)
		place(text(b, spec.Title, 40, P.Text, IronUi.Heading), 12, spec.H - 122, spec.W - 24, 50, center)
		local sub = place(text(b, spec.Sub, 14, P.Dim, IronUi.Body), 20, spec.H - 66, spec.W - 40, 40, center)
		sub.TextWrapped = true
	else
		-- Wide card: the emblem on the left, the words beside it.
		local left = Enum.TextXAlignment.Left
		emblem = IronUi.emblem(b, spec.Emblem, spec.Color, 72)
		emblem.Position = UDim2.fromOffset(26, (spec.H - 72) / 2)
		place(text(b, spec.Kicker, 15, spec.Color, IronUi.Heading), 122, 30, spec.W - 140, 20, left)
		place(text(b, spec.Title, 29, P.Text, IronUi.Heading), 122, 52, spec.W - 140, 40, left)
		local sub = place(text(b, spec.Sub, 13, P.Dim, IronUi.Body), 122, 98, spec.W - 140, 32, left)
		sub.TextWrapped = true
	end
	local kicker
	for _, child in b:GetChildren() do
		if child:IsA("TextLabel") and child.Text == spec.Kicker then
			kicker = child
		end
	end
	for _, d in emblem:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 23
		end
	end
	-- The art says it already.
	emblem.Visible = artId == 0
	if artId ~= 0 and not big then
		-- Words where the emblem was.
		for _, child in b:GetChildren() do
			if child:IsA("TextLabel") then
				child.Position -= UDim2.fromOffset(96, 0)
			end
		end
	end
	-- Locked: a dark veil with how many more duels open it.
	local veil = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 24,
	}, b)
	UiKit.round(veil, 10)
	local lock = text(veil, "", 18, P.Text, IronUi.Heading)
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.42)
	lock.Size = UDim2.new(1, -30, 0, 60)
	lock.TextWrapped = true
	lock.ZIndex = 25
	b.MouseEnter:Connect(function()
		stroke.Thickness, stroke.Transparency = 3, 0
	end)
	b.MouseLeave:Connect(function()
		stroke.Thickness, stroke.Transparency = 2, 0.2
	end)
	b.Activated:Connect(function()
		local need = spec.Unlock and LobbyUI.Unlocks[spec.Unlock] or 0
		local left = need - played()
		if left > 0 then
			UiKit.toast(
				string.format("Complete %d more duel%s to unlock %s.", left, if left == 1 then "" else "s", spec.Title),
				P.Gold
			)
			return
		end
		LobbyUI.closePicker()
		spec.Go()
	end)
	table.insert(cards, { Spec = spec, Veil = veil, Lock = lock, Kicker = kicker })
	return b
end

card({
	Title = "1v1 PRACTICE",
	Art = "Duel",
	Kicker = "VS A RIVAL",
	Sub = "Warm up against a rival miner with their own random kit. Coins on a win.",
	Emblem = "Equipment",
	Color = P.Gold,
	X = 0,
	Y = 60,
	W = 340,
	H = 500,
	Go = function()
		require(script.Parent.ArenaScene).enter(true)
	end,
})
card({
	Title = "SQUAD DUNGEON",
	Art = "Dungeon",
	Kicker = "THREE MINERS",
	Sub = "Clear the rooms and beat the boss together.",
	Emblem = "Enchant",
	Color = P.Amethyst,
	X = 362,
	Y = 60,
	W = 420,
	H = 500,
	Unlock = "Dungeon",
	Go = function()
		run("DungeonFind")
	end,
})
-- Player modes: both fight on even stats (Shared.PvPRules), stacked.
card({
	Title = "1v1 CASUAL",
	Art = "Casual",
	Kicker = "EVEN STATS · NO RATING",
	Sub = "Real players, same base stats. Just for the fight.",
	Emblem = "Equipment",
	Color = P.Teal,
	X = 830,
	Y = 60,
	W = 290,
	H = 240,
	Unlock = "Casual",
	Go = function()
		run("DuelQueue", "casual")
	end,
})
card({
	Title = "1v1 RANKED",
	Art = "Ranked",
	Kicker = "RATING 1000",
	Sub = "Even stats, gear capped at Ultra Rare. Rating on the line.",
	Emblem = "Equipment",
	Color = RED,
	X = 830,
	Y = 320,
	W = 290,
	H = 240,
	Unlock = "Ranked",
	Go = function()
		run("DuelQueue", "1v1")
	end,
})

local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(44, 44),
	Text = "✕",
	TextSize = 22,
	Font = IronUi.Heading,
	TextColor3 = P.Text,
	BackgroundColor3 = Color3.fromRGB(70, 20, 26),
	ZIndex = 22,
}, stage)
UiKit.round(close, 8)
new("UIStroke", { Color = RED, Thickness = 1.5 }, close)
close.Position = UDim2.new(1, 0, 0, -52)

local function refreshCards()
	local count = played()
	for _, entry in cards do
		local need = entry.Spec.Unlock and LobbyUI.Unlocks[entry.Spec.Unlock] or 0
		local left = need - count
		entry.Veil.Visible = left > 0
		entry.Lock.Text =
			string.format("LOCKED\nComplete %d more duel%s to unlock", left, if left == 1 then "" else "s")
		if entry.Spec.Unlock == "Ranked" then
			entry.Kicker.Text = string.format("RATING %d", player:GetAttribute("DuelRating") or 1000)
		end
	end
end

function LobbyUI.openPicker()
	refreshCards()
	fitStage()
	picker.Visible = true
	bar.Visible = false
end
function LobbyUI.closePicker()
	picker.Visible = false
	bar.Visible = true
end
close.Activated:Connect(LobbyUI.closePicker)

-- The bottom bar ------------------------------------------------------------------------------------

bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -44),
	Size = UDim2.fromOffset(420, 168),
	BackgroundTransparency = 1,
}, gui)
local tag = text(bar, "", 15, P.Text, IronUi.Heading)
tag.Visible = false
tag.AnchorPoint = Vector2.new(0.5, 0)
tag.Position = UDim2.new(0.5, 0, 0, 0)
tag.Size = UDim2.fromOffset(130, 26)
tag.BackgroundColor3, tag.BackgroundTransparency = RED, 0
UiKit.round(tag, 6)
local play = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 32),
	Size = UDim2.fromOffset(260, 58),
	Text = "",
	TextSize = 34,
	Font = IronUi.Heading,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient carries the colour
	AutoButtonColor = false,
}, bar)
UiKit.round(play, 10)
new("UIStroke", { Color = GREEN, Thickness = 3 }, play)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(58, 176, 104), Color3.fromRGB(22, 82, 52)),
}, play)
local playCaption = text(play, "PLAY", 24, Color3.new(1, 1, 1), IronUi.Heading)
playCaption.Size = UDim2.fromScale(1, 1)
playCaption.TextStrokeTransparency = 1
IronUi.juice(play)
play.Activated:Connect(LobbyUI.openPicker)

local tiles = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.fromOffset(420, 68),
	BackgroundTransparency = 1,
}, bar)
local tileList = UiKit.list(tiles, 10, true)
tileList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function tile(label: string, emblem: string, color: Color3, onClick: () -> ())
	local b = new("TextButton", {
		Size = UDim2.fromOffset(94, 68),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(14, 18, 30),
		BackgroundTransparency = 0.15,
	}, tiles)
	UiKit.round(b, 8)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.3 }, b)
	local icon = IronUi.emblem(b, emblem, color, 34)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 6)
	local name = text(b, label, 12, P.Text, IronUi.Heading)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -6)
	name.Size = UDim2.new(1, -6, 0, 16)
	IronUi.juice(b)
	b.Activated:Connect(onClick)
	return b
end

local function fitDock()
	local size = gui.AbsoluteSize
	local mobile = game:GetService("UserInputService").TouchEnabled or size.Y < 540
	local width = math.min(420, math.max(240, size.X - 180))
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	-- Every tile fits the bar's width, however many there are (five tiles in
	-- a width worked out for four spilled off to the sides). On a phone they're
	-- short buttons with the name in the middle (no emblem over an empty gap).
	local count = 0
	for _, button in tiles:GetChildren() do
		if button:IsA("TextButton") then
			count += 1
		end
	end
	local compact = MobileLayout.dock(size, count)
	if mobile then
		width = compact.W
	end
	local gap = if mobile then compact.Gap else 10
	local tileHeight = if mobile then compact.TileHeight else 68
	bar.Size = UDim2.fromOffset(width, 44 + 8 + tileHeight)
	play.Position, play.Size = UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(math.min(220, width), 44)
	tiles.Position, tiles.Size = UDim2.new(0.5, 0, 0, 52), UDim2.fromOffset(width, tileHeight)
	tileList.Padding = UDim.new(0, gap)
	local tileWidth = math.floor((width - gap * math.max(0, count - 1)) / math.max(1, count))
	for _, button in tiles:GetChildren() do
		if button:IsA("TextButton") then
			button.Size = UDim2.fromOffset(tileWidth, tileHeight)
			for _, child in button:GetChildren() do
				if child:IsA("TextLabel") then
					child.TextSize = if mobile then 11 else 12
					child.AnchorPoint = if mobile then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 1)
					child.Position = if mobile then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 1, -4)
				elseif child:IsA("GuiObject") then
					child.Visible = not mobile
				end
			end
		end
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitDock)
task.defer(fitDock)

-- Inventory: the full dashboard, over the lobby.
local dashboardShown = false
local back = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(220, 40),
	Text = "◂  BACK TO LOBBY",
	TextSize = 16,
	Font = IronUi.Heading,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(22, 52, 40),
}, top)
UiKit.round(back, 8)
new("UIStroke", { Color = GREEN, Thickness = 2 }, back)

local wanted = false -- whether the lobby HUD should be up (LobbyUI.setVisible)
local function showDashboard(on: boolean)
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	if dashboard and dashboard:IsA("ScreenGui") then
		dashboard.Enabled = on
	end
	dashboardShown = on and dashboard ~= nil
	top.Enabled = dashboardShown
	if dashboardShown then
		picker.Visible = false
	end
	gui.Enabled = wanted and not dashboardShown
end
back.Activated:Connect(function()
	showDashboard(false)
end)

tile("INVENTORY", "Equipment", P.Gold, function()
	showDashboard(true)
end)
tile("MARKET", "Trade", P.Gold, function()
	require(script.Parent.MarketBoardUI).open()
end)
tile("STORE", "Coins", P.Amethyst, function()
	require(script.Parent.ShopUI).toggle()
end)
tile("RANKS", "Enchant", RED, function()
	require(script.Parent.TopPlayersUI).toggle()
end)
tile("SOCIAL", "Trade", P.Teal, function()
	require(script.Parent.SocialUI).toggle()
end)

-- Public -----------------------------------------------------------------------------------------------

function LobbyUI.setVisible(on: boolean)
	wanted = on
	if not on then
		LobbyUI.closePicker()
		if dashboardShown then
			showDashboard(false)
		end
	end
	-- The dashboard has the screen while it's open; BACK TO LOBBY returns.
	gui.Enabled = on and not dashboardShown
end

-- Puts the lobby HUD back as it should be (after something else hid it).
function LobbyUI.refresh()
	gui.Enabled = wanted and not dashboardShown
end

function LobbyUI.dashboardOpen(): boolean
	return dashboardShown
end

player:GetAttributeChangedSignal("DuelsPlayed"):Connect(refreshCards)
player:GetAttributeChangedSignal("DuelRating"):Connect(refreshCards)

return LobbyUI
