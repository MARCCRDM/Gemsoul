--[[
	The lobby (the Saga Outpost): a command stack on the left (a big gold
	PLAY, then one button each for the Inventory, Market, Store, Ranks,
	Social and Invite, then your level and coins), what's happening on the
	right (your daily streak and the next mode to unlock), and the PLAY menu
	that picks what to play:

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
		local left = if not require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled
			then 0
			elseif GemClient.Profile and GemClient.Profile.Tutorial and GemClient.Profile.Tutorial.Done then 0
			else need - played()
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
	Sub = "First to 2 rounds. Swap presets between rounds. Rating on the line.",
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
		local left = if not require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled
			then 0
			elseif GemClient.Profile and GemClient.Profile.Tutorial and GemClient.Profile.Tutorial.Done then 0
			else need - count
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

-- The command stack (left) -------------------------------------------------------------------------
-- PLAY first, where the eye starts; then one big button per place to go;
-- then your level and coins. The right side shows what's happening (daily
-- streak, next unlock). On a phone the stack shrinks to thumb-sized rows.
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 214, 120), Color3.fromRGB(226, 156, 44)
local STEEL = Color3.fromRGB(24, 31, 42)
local STACK_W = 196

bar = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 24, 0.5, 0),
	Size = UDim2.fromOffset(STACK_W, 520),
	BackgroundTransparency = 1,
}, gui)
local tag = text(bar, "", 15, P.Text, IronUi.Heading)
tag.Visible = false
local play = new("TextButton", {
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(STACK_W, 66),
	Text = "",
	BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient carries the colour
	AutoButtonColor = false,
}, bar)
UiKit.round(play, 6)
new("UIStroke", { Color = Color3.fromRGB(255, 240, 200), Thickness = 2 }, play)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM) }, play)
local playCaption = text(play, "PLAY", 30, Color3.fromRGB(28, 18, 4), IronUi.Heading)
playCaption.Size = UDim2.fromScale(1, 1)
playCaption.TextStrokeTransparency = 1
IronUi.juice(play)
play.Activated:Connect(LobbyUI.openPicker)
local modes = text(bar, "1v1 PRACTICE  ·  DUNGEON  ·  RANKED", 11, P.Text, IronUi.Heading)
modes.Position, modes.Size = UDim2.fromOffset(0, 70), UDim2.fromOffset(STACK_W, 20)
modes.BackgroundColor3, modes.BackgroundTransparency = Color3.fromRGB(10, 14, 20), 0.25
UiKit.round(modes, 4)

local tiles = new("Frame", {
	Position = UDim2.fromOffset(0, 96),
	Size = UDim2.fromOffset(STACK_W, 320),
	BackgroundTransparency = 1,
}, bar)
-- Positions are explicit so Inventory can span both utility columns.

-- One row of the stack: a gunmetal plate, an emblem, the name, and a bright
-- edge in its colour on the left.
local function tile(label: string, emblem: string, color: Color3, onClick: () -> ())
	local b = new("TextButton", {
		Size = UDim2.fromOffset(STACK_W, 46),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = #tiles:GetChildren(),
	}, tiles)
	UiKit.round(b, 5)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(42, 52, 66), STEEL),
	}, b)
	new("UIStroke", { Color = Color3.fromRGB(70, 82, 98), Thickness = 1.2 }, b)
	local edge = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Size = UDim2.new(0, 4, 1, -10),
		Position = UDim2.fromOffset(0, 5),
	}, b)
	edge.Name = "Edge"
	local icon = IronUi.emblem(b, emblem, color, 28)
	icon.Name = "NavIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	local name = text(b, label, 17, P.Text, IronUi.Heading)
	name.Name = "NavLabel"
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 54, 0.5, 0)
	name.Size = UDim2.new(1, -64, 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local chevron = text(b, "›", 22, P.Dim, IronUi.Heading)
	chevron.Name = "NavChevron"
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -12, 0.5, 0)
	chevron.Size = UDim2.fromOffset(16, 24)
	IronUi.juice(b)
	b.Activated:Connect(onClick)
	b.Name = label
	return b
end

-- A stack button by its label (the tutorial points at INVENTORY).
function LobbyUI.tile(label: string): GuiButton?
	return tiles:FindFirstChild(label) :: GuiButton?
end

-- Level and coins under the stack.
local status = new("Frame", {
	Size = UDim2.fromOffset(STACK_W, 34),
	BackgroundColor3 = Color3.fromRGB(10, 14, 20),
	BackgroundTransparency = 0.15,
}, bar)
UiKit.round(status, 5)
new("UIStroke", { Color = Color3.fromRGB(52, 64, 80), Thickness = 1 }, status)
local levelLabel = text(status, "LEVEL 1", 13, P.Text, IronUi.Heading)
levelLabel.Position, levelLabel.Size = UDim2.fromOffset(10, 0), UDim2.fromOffset(70, 34)
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
local levelTrack = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(30, 38, 50),
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 84, 0.5, 0),
	Size = UDim2.new(1, -194, 0, 6),
}, status)
UiKit.round(levelTrack, 3)
local levelFill = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = GOLD_BOTTOM,
	Size = UDim2.fromScale(0, 1),
}, levelTrack)
UiKit.round(levelFill, 3)
local coinsLabel = text(status, "0", 13, P.Gold, IronUi.Heading)
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position, coinsLabel.Size = UDim2.new(1, -10, 0, 0), UDim2.fromOffset(100, 34)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right

-- What's happening (right): your daily streak and the next mode to unlock.
local news = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 64),
	Size = UDim2.fromOffset(208, 120),
	BackgroundColor3 = STEEL,
	BackgroundTransparency = 0.12,
}, gui)
UiKit.round(news, 8)
new("UIStroke", { Color = Color3.fromRGB(70, 82, 98), Thickness = 1, Transparency = 0.45 }, news)
UiKit.list(news, 0, false)
local function newsPanel(order: number, height: number)
	local panel = new("Frame", {
		Size = UDim2.fromOffset(208, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, news)

	return panel
end
local dailyPanel = newsPanel(1, 64)
local dailyTitle = text(dailyPanel, "DAILY REWARD", 11, P.Gold, IronUi.Heading)
dailyTitle.Position, dailyTitle.Size = UDim2.fromOffset(12, 8), UDim2.fromOffset(184, 14)
dailyTitle.TextXAlignment = Enum.TextXAlignment.Left
local dailyText = text(dailyPanel, "", 11, P.Text, IronUi.Heading)
dailyText.Position, dailyText.Size = UDim2.fromOffset(12, 24), UDim2.fromOffset(184, 14)
dailyText.TextXAlignment = Enum.TextXAlignment.Left
local streakDots = {}
for i = 1, 7 do
	local dot = new("Frame", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12 + (i - 1) * 27, 43),
		Size = UDim2.fromOffset(22, 16),
		BackgroundColor3 = Color3.fromRGB(30, 38, 50),
	}, dailyPanel)
	UiKit.round(dot, 4)
	local day = text(dot, tostring(i), 11, P.Dim, IronUi.Heading)
	day.Size = UDim2.fromScale(1, 1)
	streakDots[i] = { Dot = dot, Label = day }
end
local unlockPanel = newsPanel(2, 56)
new("Frame", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 0, 1),
	BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(65, 77, 94), BackgroundTransparency = 0.5 }, unlockPanel)
local unlockTitle = text(unlockPanel, "NEXT UNLOCK", 10, P.Gold, IronUi.Heading)
unlockTitle.Position, unlockTitle.Size = UDim2.fromOffset(12, 8), UDim2.fromOffset(184, 14)
unlockTitle.TextXAlignment = Enum.TextXAlignment.Left
local unlockText = text(unlockPanel, "", 12, P.Text, IronUi.Heading)
unlockText.Position, unlockText.Size = UDim2.fromOffset(12, 23), UDim2.fromOffset(184, 16)
unlockText.TextXAlignment = Enum.TextXAlignment.Left
local unlockHint = text(unlockPanel, "", 10, P.Dim, IronUi.Body)
unlockHint.Position, unlockHint.Size = UDim2.fromOffset(12, 40), UDim2.fromOffset(184, 14)
unlockHint.TextXAlignment = Enum.TextXAlignment.Left
unlockHint.TextYAlignment = Enum.TextYAlignment.Top
unlockHint.TextWrapped = true

local function refreshNews()
	local profile = GemClient.Profile
	if not profile then
		return
	end
	-- Level and coins.
	local Tree = require(game:GetService("ReplicatedStorage").Shared.AugmentTree)
	local xp = profile.Augments and profile.Augments.XP or 0
	local level = Tree.level(xp)
	levelLabel.Text = "LEVEL " .. level
	local maxed = level >= Tree.MaxLevel
	local progress = if maxed then 1 else (math.max(0, xp) % Tree.XPPerPoint) / Tree.XPPerPoint
	levelFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	local coins = math.floor(profile.Coins or 0)
	local formatted = tostring(coins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	coinsLabel.Text = "◆ " .. formatted
	-- Daily streak (Config: a week of growing rewards).
	local daily = profile.Daily or {}
	local streak = math.clamp(daily.Streak or 0, 0, 7)
	dailyText.Text = if streak > 0
		then string.format("Day %d / 7 · next reward tomorrow", streak)
		else "Return daily to grow your rewards"
	for i, entry in streakDots do
		local done = i <= streak
		entry.Dot.BackgroundColor3 = if done
			then Color3.fromRGB(46, 120, 76)
			elseif i == streak + 1 then GOLD_BOTTOM
			else Color3.fromRGB(30, 38, 50)
		entry.Label.TextColor3 = if done or i == streak + 1 then Color3.new(1, 1, 1) else P.Dim
		entry.Label.Text = if done then "✓" else tostring(i)
	end
	-- The next mode you're working toward.
	local duels = played()
	local nextName, need = nil, nil
	for _, entry in { { "Dungeon & Casual", LobbyUI.Unlocks.Dungeon }, { "Ranked 1v1", LobbyUI.Unlocks.Ranked } } do
		if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled
			and not (profile.Tutorial and profile.Tutorial.Done) and duels < entry[2] then
			nextName, need = entry[1], entry[2]
			break
		end
	end
	if nextName then
		unlockTitle.Text = "NEXT UNLOCK"
		unlockText.Text = string.upper(nextName)
		unlockHint.Text = string.format(
			"%d more duel%s to unlock",
			need - duels,
			if need - duels == 1 then "" else "s"
		)
	else
		unlockTitle.Text = "ARENA"
		unlockText.Text = "ALL MODES OPEN"
		unlockHint.Text = "Choose your next match with Play"
	end
end
GemClient.Changed:Connect(refreshNews)
task.defer(refreshNews)

local function fitDock()
	local size = gui.AbsoluteSize
	local mobile = game:GetService("UserInputService").TouchEnabled or size.Y < 540
	local buttons = {}
	for _, button in tiles:GetChildren() do
		if button:IsA("TextButton") then table.insert(buttons, button) end
	end
	table.sort(buttons, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	modes.Visible = false
	status.Visible = not mobile
	news.Visible = not mobile and not picker.Visible
	if mobile then
		local compact = MobileLayout.dock(size, #buttons)
		local width, gap, tileHeight = compact.W, compact.Gap, compact.TileHeight
		bar.AnchorPoint, bar.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12)
		bar.Size = UDim2.fromOffset(width, 52 + tileHeight)
		play.AnchorPoint = Vector2.new(0.5, 0)
		play.Position, play.Size = UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(math.min(220, width), 44)
		playCaption.TextSize = 22
		tiles.AnchorPoint, tiles.Position = Vector2.new(0, 0), UDim2.fromOffset(0, 52)
		tiles.Size = UDim2.fromOffset(width, tileHeight)
		local tileWidth = math.floor((width - gap * math.max(0, #buttons - 1)) / math.max(1, #buttons))
		for i, button in buttons do
			button.Position, button.Size = UDim2.fromOffset((i - 1) * (tileWidth + gap), 0), UDim2.fromOffset(tileWidth, tileHeight)
			for _, child in button:GetChildren() do
				if child.Name == "NavLabel" then
					child.TextSize, child.TextScaled = 11, true
					child.AnchorPoint, child.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
					child.Size, child.TextXAlignment = UDim2.new(1, -6, 0, 14), Enum.TextXAlignment.Center
				elseif child:IsA("GuiObject") then child.Visible = false end
			end
		end
		return
	end
	local width, gap, utilityHeight = STACK_W, 6, 36
	local utilityWidth = (width - gap) / 2
	bar.AnchorPoint, bar.Position = Vector2.new(0, 1), UDim2.new(0, 16, 1, -20)
	play.AnchorPoint, play.Position = Vector2.zero, UDim2.fromOffset(0, 0)
	play.Size, playCaption.TextSize = UDim2.fromOffset(width, 46), 23
	tiles.AnchorPoint, tiles.Position = Vector2.zero, UDim2.fromOffset(0, 54)
	local utility = 0
	for _, button in buttons do
		local primary = button.Name == "INVENTORY"
		if primary then
			button.Position, button.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(width, 40)
		else
			button.Position = UDim2.fromOffset((utility % 2) * (utilityWidth + gap), 46 + math.floor(utility / 2) * (utilityHeight + gap))
			button.Size = UDim2.fromOffset(utilityWidth, utilityHeight)
			utility += 1
		end
		for _, child in button:GetChildren() do
			if child.Name == "NavLabel" then
				child.Visible, child.TextScaled, child.TextSize = true, false, if primary then 14 else 11
				child.AnchorPoint = Vector2.new(if primary then 0 else 0.5, 0.5)
				child.Position = if primary then UDim2.new(0, 40, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
				child.Size = if primary then UDim2.new(1, -64, 0, 20) else UDim2.new(1, -10, 0, 20)
				child.TextXAlignment = if primary then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			elseif child.Name == "NavIcon" then
				child.Visible = primary
				child.Size, child.Position = UDim2.fromOffset(22, 22), UDim2.new(0, 10, 0.5, 0)
			elseif child.Name == "NavChevron" then child.Visible = primary
			elseif child.Name == "Edge" then
				child.Visible = true
				child.Size = UDim2.new(0, 2, 1, -14)
				child.Position = UDim2.fromOffset(0, 7)
			end
		end
	end
	local tilesHeight = 40 + math.ceil(utility / 2) * (utilityHeight + gap)
	tiles.Size = UDim2.fromOffset(width, tilesHeight)
	status.Position, status.Size = UDim2.fromOffset(0, 54 + tilesHeight + 8), UDim2.fromOffset(width, 28)
	levelLabel.TextSize, coinsLabel.TextSize = 11, 11
	levelLabel.Position, levelLabel.Size = UDim2.fromOffset(8, 0), UDim2.fromOffset(56, 28)
	levelTrack.Position, levelTrack.Size = UDim2.new(0, 65, 0.5, 0), UDim2.new(1, -151, 0, 4)
	coinsLabel.Position, coinsLabel.Size = UDim2.new(1, -8, 0, 0), UDim2.fromOffset(78, 28)
	bar.Size = UDim2.fromOffset(width, 54 + tilesHeight + 8 + 28)
	news.Position = UDim2.new(1, -16, 0, 64)
end
picker:GetPropertyChangedSignal("Visible"):Connect(function()
	gui:SetAttribute("ModePickerOpen", picker.Visible)
	fitDock()
end)
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
-- The Inventory has its own Back to Lobby (Modules/InventoryScreen).
back.Visible = false
function LobbyUI.closeDashboard()
	showDashboard(false)
end

tile("INVENTORY", "Equipment", P.Gold, function()
	showDashboard(true)
end)
tile("MARKET", "Market", P.Gold, function()
	require(script.Parent.MarketBoardUI).open()
end)
tile("STORE", "Coins", P.Amethyst, function()
	require(script.Parent.ShopUI).toggle()
end)
tile("RANKS", "Ranks", RED, function()
	require(script.Parent.TopPlayersUI).toggle()
end)
tile("SOCIAL", "Social", P.Teal, function()
	require(script.Parent.SocialUI).toggle()
end)
-- Bring a friend: Kindred Edge and the friend ladder (Modules/ReferralUI).
tile("INVITE", "Invite", Color3.fromRGB(60, 210, 240), function()
	require(script.Parent.ReferralUI).toggle()
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
