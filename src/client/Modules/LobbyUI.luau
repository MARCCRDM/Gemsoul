--[[
	The lobby (the Saga Outpost): compact Play and Inventory controls on the
	left, a two-column utility menu, level and coins, plus one small panel
	on the right for the daily streak, the next mode to unlock and the next
	task, a REPORT A BUG button by the TASKS button, and the PLAY menu that
	picks what to play. On a phone: PLAY alone at the bottom centre with icon
	buttons under it, level and coins at the top left, the next task as one
	slim strip, and no bug button (SOCIAL has the form).

	  PRACTICE  1v1 Practice    a rival miner, coins on a win (always open)
	            Squad Dungeon   three miners, a dungeon and its boss (not
	                            while Config.Features.Dungeons is off: then
	                            1v1 Practice takes its space)
	  RANKED    1v1 Ranked      real players, rating on the line

	Modes unlock as you play duels (Unlocks). The Inventory opens the full
	dashboard over the lobby, with a BACK TO LOBBY button to close it.

	  LobbyUI.setVisible(on)  Lobby.client shows it while you're in the lobby
	  LobbyUI.dashboardOpen() true while the dashboard is open over the lobby
	  LobbyUI.Unlocks         duels needed for each mode
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local LobbyUI = {}
LobbyUI.Unlocks = { Dungeon = 3, Casual = 3, Ranked = 10 }
-- Squad dungeons can be switched off for a test or the beta (Config.Features).
LobbyUI.DungeonsOpen = not (Config.Features and Config.Features.Dungeons == false)
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
	local emblem, kicker, title
	if big then
		-- Tall card: the emblem up top, the words at the bottom, centred.
		local center = Enum.TextXAlignment.Center
		emblem = IronUi.emblem(b, spec.Emblem, spec.Color, 120)
		emblem.Position = UDim2.fromOffset((spec.W - 120) / 2, 80)
		kicker = UiKit.fit(
			place(text(b, spec.Kicker, 22, spec.Color, IronUi.Heading), 12, spec.H - 150, spec.W - 24, 26, center)
		)
		UiKit.fit(place(text(b, spec.Title, 40, P.Text, IronUi.Heading), 12, spec.H - 122, spec.W - 24, 50, center))
		local sub = place(text(b, spec.Sub, 14, P.Dim, IronUi.Body), 20, spec.H - 66, spec.W - 40, 40, center)
		sub.TextWrapped = true
	else
		-- Wide card: the emblem on the left, the words beside it.
		local left = Enum.TextXAlignment.Left
		emblem = IronUi.emblem(b, spec.Emblem, spec.Color, 72)
		emblem.Position = UDim2.fromOffset(26, (spec.H - 72) / 2)
		kicker = UiKit.fit(place(text(b, spec.Kicker, 15, spec.Color, IronUi.Heading), 122, 30, spec.W - 140, 20, left))
		title = UiKit.fit(place(text(b, spec.Title, 29, P.Text, IronUi.Heading), 122, 52, spec.W - 140, 40, left))
		local sub = place(text(b, spec.Sub, 13, P.Dim, IronUi.Body), 122, 98, spec.W - 140, 32, left)
		sub.TextWrapped = true
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
		-- (The one-line words take the room too, so they keep their size.)
		kicker.Size += UDim2.fromOffset(96, 0)
		title.Size += UDim2.fromOffset(96, 0)
	end
	-- What a win pays, in a corner; for the player queues, who's searching
	-- right now (their DuelQueue attribute), bottom right.
	if spec.Reward then
		local chip = text(b, spec.Reward, 12, P.Gold, IronUi.Heading)
		-- (Top right on a tall card; on a wide one the words have the top.)
		chip.AnchorPoint = if big then Vector2.new(1, 0) else Vector2.new(0, 1)
		chip.Position = if big then UDim2.new(1, -12, 0, 12) else UDim2.new(0, 14, 1, -10)
		chip.Size = UDim2.fromOffset(104, 24)
		chip.BackgroundColor3, chip.BackgroundTransparency = Color3.fromRGB(8, 10, 16), 0.2
		chip.TextStrokeTransparency, chip.ZIndex = 1, 23
		UiKit.round(chip, 12)
	end
	local live = nil
	if spec.Queue then
		live = text(b, "", 12, P.Dim, IronUi.Heading)
		live.AnchorPoint = Vector2.new(1, 1)
		live.Position, live.Size = UDim2.new(1, -14, 1, -12), UDim2.fromOffset(150, 20)
		live.TextXAlignment, live.ZIndex = Enum.TextXAlignment.Right, 23
		live.RichText = true
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
	table.insert(cards, { Spec = spec, Veil = veil, Lock = lock, Kicker = kicker, Live = live })
	return b
end

card({
	Title = "1v1 PRACTICE",
	Art = "Duel",
	Kicker = "VS A RIVAL",
	Sub = "Warm up against a rival miner with their own random kit. Coins on a win.",
	Emblem = "Equipment",
	Color = P.Gold,
	Reward = string.format("WIN +%d ◆", Matchmaking.RivalWinCoins),
	X = 0,
	Y = 60,
	W = if LobbyUI.DungeonsOpen then 340 else 782,
	H = 500,
	Go = function()
		require(script.Parent.ArenaScene).enter(true)
	end,
})
if LobbyUI.DungeonsOpen then
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
end
-- Player modes: both fight on even stats (Shared.PvPRules), stacked.
card({
	Title = "1v1 CASUAL",
	Art = "Casual",
	Kicker = "EVEN STATS · NO RATING",
	Sub = "Real players, same base stats. Just for the fight.",
	Emblem = "Equipment",
	Color = P.Teal,
	Reward = string.format("WIN +%d ◆", PvPRules.Kinds.Casual.Rewards.Win),
	Queue = "casual",
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
	Reward = string.format("WIN +%d ◆", PvPRules.Kinds.Ranked.Rewards.Win),
	Queue = "1v1",
	X = 830,
	Y = 320,
	W = 290,
	H = 240,
	Unlock = "Ranked",
	Go = function()
		run("DuelQueue", "1v1")
	end,
})

-- (The round X every window closes with: IronUi.window, the Store.)
local close = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(44, 44),
	Text = "",
	BackgroundColor3 = Color3.fromRGB(20, 25, 37),
	AutoButtonColor = true,
	ZIndex = 22,
}, stage)
IronUi.cross(close, 16, P.Text)
UiKit.round(close, 22)
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.82 }, close)
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
		if entry.Live then
			local searching = 0
			for _, other in Players:GetPlayers() do
				if other:GetAttribute("DuelQueue") == entry.Spec.Queue then
					searching += 1
				end
			end
			entry.Live.Text = if searching > 0
				then string.format('<font color="#4ED692">●</font> %d SEARCHING NOW', searching)
				else "QUEUE OPEN"
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
-- In a mech, the driving card has the bottom of a phone's screen, where PLAY
-- sits (Client VehicleDrive).
local function pilotingChanged()
	play.Visible = player:GetAttribute("MechPilot") == nil
end
player:GetAttributeChangedSignal("MechPilot"):Connect(pilotingChanged)
pilotingChanged()
-- Under PLAY: who's around (or the modes, alone in a server).
local playSub = text(play, "PRACTICE  ·  CASUAL  ·  RANKED", 10, Color3.fromRGB(92, 56, 8), IronUi.Heading)
playSub.TextStrokeTransparency = 1
IronUi.shine(play, 3.5)
IronUi.juice(play)
play.Activated:Connect(LobbyUI.openPicker)
local modes = text(
	bar,
	if LobbyUI.DungeonsOpen then "1v1 PRACTICE  ·  DUNGEON  ·  RANKED" else "1v1 PRACTICE  ·  CASUAL  ·  RANKED",
	11,
	P.Text,
	IronUi.Heading
)
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

-- Your card under the stack: level, name, coins and the XP to the next level.
local status = new("Frame", {
	Size = UDim2.fromOffset(STACK_W, 54),
	BackgroundColor3 = Color3.fromRGB(12, 16, 24),
	BackgroundTransparency = 0.12,
}, bar)
UiKit.round(status, 8)
new("UIStroke", { Color = Color3.fromRGB(64, 78, 98), Thickness = 1, Transparency = 0.3 }, status)
local levelBadge = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(38, 38),
}, status)
UiKit.round(levelBadge, 19)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM) }, levelBadge)
new("UIStroke", { Color = Color3.fromRGB(255, 240, 200), Thickness = 1.5 }, levelBadge)
local levelLabel = text(levelBadge, "1", 16, Color3.fromRGB(40, 24, 0), IronUi.Heading)
levelLabel.Size = UDim2.fromScale(1, 1)
levelLabel.TextStrokeTransparency = 1
local nameLabel = text(status, "", 13, P.Text, IronUi.Heading, Enum.TextXAlignment.Left)
nameLabel:SetAttribute("NoTranslate", true) -- (a player's name)
nameLabel.Position, nameLabel.Size = UDim2.fromOffset(54, 7), UDim2.new(1, -140, 0, 18)
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
local coinsLabel = text(status, "0", 13, P.Gold, IronUi.Heading, Enum.TextXAlignment.Right)
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position, coinsLabel.Size = UDim2.new(1, -9, 0, 7), UDim2.fromOffset(84, 18)
local levelTrack = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(34, 44, 58),
	Position = UDim2.fromOffset(54, 30),
	Size = UDim2.new(1, -63, 0, 6),
}, status)
UiKit.round(levelTrack, 3)
local levelFill = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = GOLD_BOTTOM,
	Size = UDim2.fromScale(0, 1),
}, levelTrack)
UiKit.round(levelFill, 3)
local xpLabel = text(status, "", 10, P.Dim, IronUi.Body, Enum.TextXAlignment.Left)
xpLabel.Position, xpLabel.Size = UDim2.fromOffset(54, 37), UDim2.new(1, -63, 0, 14)
xpLabel.TextStrokeTransparency = 1

-- On a phone: level and coins in a pill at the top left, under the pick
-- card (MobileLayout.wallet).
local walletPill = new("Frame", {
	Name = "Wallet",
	BackgroundColor3 = Color3.fromRGB(12, 16, 24),
	BackgroundTransparency = 0.15,
	Size = UDim2.fromOffset(150, 30),
	Visible = false,
}, gui)
UiKit.round(walletPill, 15)
new("UIStroke", { Color = Color3.fromRGB(64, 78, 98), Thickness = 1, Transparency = 0.3 }, walletPill)
local walletText = text(walletPill, "", 12, P.Text, IronUi.Heading)
walletText.RichText = true
walletText.Size = UDim2.fromScale(1, 1)
walletText.TextStrokeTransparency = 1

local function formatCoins(coins: number): string
	return (tostring(math.floor(coins)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- The right side: daily streak, daily challenges, next unlock, next task
-- (Modules/LobbyBoard); the live feed and the welcome banner (Modules/LobbyFeed).
local LobbyBoard = require(script.Parent.LobbyBoard)
local LobbyFeed = require(script.Parent.LobbyFeed)
local board = LobbyBoard.mount(gui)
LobbyFeed.mount(gui)

-- The next mode you're working toward (while modes unlock with duels): the
-- board asks as it redraws.
LobbyBoard.unlock = function(profile)
	local duels = played()
	local first = if LobbyUI.DungeonsOpen then "Dungeon & Casual" else "Casual 1v1"
	for _, entry in { { first, LobbyUI.Unlocks.Casual }, { "Ranked 1v1", LobbyUI.Unlocks.Ranked } } do
		if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled
			and not (profile.Tutorial and profile.Tutorial.Done) and duels < entry[2] then
			return { Name = entry[1], Left = entry[2] - duels }
		end
	end
	return nil
end

-- Level, XP and coins (redrawn while the lobby is up, and as it shows).
local function refreshNews()
	local profile = GemClient.Profile
	if not profile or not gui.Enabled then
		return
	end
	local Tree = require(game:GetService("ReplicatedStorage").Shared.AugmentTree)
	local xp = math.max(0, profile.Augments and profile.Augments.XP or 0)
	local level = Tree.level(xp)
	levelLabel.Text = tostring(level)
	nameLabel.Text = player.DisplayName
	local maxed = level >= Tree.MaxLevel
	local into = xp % Tree.XPPerPoint
	levelFill.Size = UDim2.fromScale(if maxed then 1 else math.clamp(into / Tree.XPPerPoint, 0, 1), 1)
	xpLabel.Text = if maxed
		then "MAX LEVEL"
		else string.format("%d / %d XP to level %d", into, Tree.XPPerPoint, level + 1)
	coinsLabel.Text = "◆ " .. formatCoins(profile.Coins or 0)
	walletText.Text =
		string.format('LV %d  <font color="#FFCA5B">◆ %s</font>', level, formatCoins(profile.Coins or 0))
end
GemClient.Changed:Connect(refreshNews)
gui:GetPropertyChangedSignal("Enabled"):Connect(refreshNews)
task.defer(refreshNews)

-- Who's around: miners in the server, and how many are searching for a
-- 1v1 or fighting one (their DuelQueue and MatchId attributes).
local function crowd()
	local online, searching, fighting = 0, 0, 0
	for _, other in Players:GetPlayers() do
		online += 1
		if other:GetAttribute("DuelQueue") then
			searching += 1
		elseif other:GetAttribute("MatchId") then
			fighting += 1
		end
	end
	return online, searching, fighting
end
LobbyUI.crowd = crowd
local function refreshCrowd()
	local online, searching = crowd()
	if searching > 0 then
		playSub.Text = string.format("● %d ONLINE  ·  %d SEARCHING", online, searching)
	else
		playSub.Text = if online > 1
			then string.format("● %d MINERS ONLINE", online)
			else "PRACTICE  ·  CASUAL  ·  RANKED"
	end
end
Players.PlayerAdded:Connect(refreshCrowd)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshCrowd)
end)
task.spawn(function()
	while true do
		if gui.Enabled then
			refreshCrowd()
			if picker.Visible then
				refreshCards() -- (the queues' live counts)
			end
		end
		task.wait(2)
	end
end)

-- REPORT A BUG, beside the TASKS button (top right): the feedback form
-- (Social), which sends the build and where you were with it. Not on a
-- phone, where the corner is kept clear: SOCIAL has the same form there
-- (its Feedback button). Its words are a label of their own, so the
-- gradient doesn't tint them dark.
local bug = new("TextButton", {
	Name = "ReportBug",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -156, 0, 12),
	Size = UDim2.fromOffset(132, 40),
	BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient carries the colour
	AutoButtonColor = false,
	Text = "",
}, gui)
UiKit.round(bug, 8)
new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.55 }, bug)
new(
	"UIGradient",
	{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(58, 44, 26), Color3.fromRGB(30, 22, 14)) },
	bug
)
local bugLabel = text(bug, "🐞 REPORT A BUG", 12, Color3.fromRGB(255, 226, 170), IronUi.Heading)
bugLabel.Size = UDim2.fromScale(1, 1)
bugLabel.TextStrokeTransparency = 1
IronUi.juice(bug)
bug.Activated:Connect(function()
	require(script.Parent.SocialUI).feedback()
end)

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
	walletPill.Visible = mobile and not picker.Visible
	-- The board under TASKS on the right; the live feed at the top centre (on
	-- a phone, in the gap between the pick card and the board).
	LobbyBoard.setCompact(mobile)
	local card = MobileLayout.card()
	local gapLeft = card.X + card.W + 8
	local gapRight = size.X - 16 - board.Size.X.Offset - 8
	LobbyFeed.setCompact(mobile, if mobile then { X = gapLeft, W = gapRight - gapLeft } else nil)
	-- (On a phone, its one strip tucks in under the small TASKS button.)
	board.Position = UDim2.new(1, -16, 0, if mobile then MobileLayout.board(size).Y else 64)
	LobbyBoard.setHidden(picker.Visible)
	bug.Visible = not picker.Visible and not mobile
	if mobile then
		local compact = MobileLayout.dock(size, #buttons)
		local width, gap, tileHeight = compact.W, compact.Gap, compact.TileHeight
		local tilesTop = compact.PlayHeight + gap
		bar.AnchorPoint, bar.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -MobileLayout.Margin)
		bar.Size = UDim2.fromOffset(width, tilesTop + tileHeight)
		play.AnchorPoint = Vector2.new(0.5, 0)
		play.Position = UDim2.new(0.5, 0, 0, 0)
		play.Size = UDim2.fromOffset(compact.PlayWidth, compact.PlayHeight)
		playCaption.TextSize = 20
		playCaption.Position, playCaption.Size = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1)
		playSub.Visible = false
		-- Level and coins up at the top left; nothing either side of PLAY.
		local wallet = MobileLayout.wallet()
		walletPill.AnchorPoint, walletPill.Position = Vector2.zero, UDim2.fromOffset(wallet.X, wallet.Y)
		walletPill.Size = UDim2.fromOffset(wallet.W, wallet.H)
		tiles.AnchorPoint, tiles.Position = Vector2.new(0, 0), UDim2.fromOffset(0, tilesTop)
		tiles.Size = UDim2.fromOffset(width, tileHeight)
		local tileWidth = math.floor((width - gap * math.max(0, #buttons - 1)) / math.max(1, #buttons))
		-- Each tile: its icon, and its name small under it.
		for i, button in buttons do
			button.Position, button.Size = UDim2.fromOffset((i - 1) * (tileWidth + gap), 0), UDim2.fromOffset(tileWidth, tileHeight)
			for _, child in button:GetChildren() do
				if child.Name == "NavLabel" then
					child.Visible, child.TextSize, child.TextScaled = true, 9, true
					child.AnchorPoint, child.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -4)
					child.Size, child.TextXAlignment = UDim2.new(1, -6, 0, 11), Enum.TextXAlignment.Center
				elseif child.Name == "NavIcon" then
					child.Visible = true
					child.AnchorPoint, child.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 5)
					child.Size = UDim2.fromOffset(tileHeight - 22, tileHeight - 22)
				elseif child:IsA("GuiObject") then child.Visible = false end
			end
		end
		return
	end
	local width, gap, utilityHeight = STACK_W, 4, 32
	local utilityWidth = (width - gap) / 2
	bar.AnchorPoint, bar.Position = Vector2.zero, UDim2.fromOffset(16, 54)
	play.AnchorPoint, play.Position = Vector2.zero, UDim2.fromOffset(0, 0)
	play.Size, playCaption.TextSize = UDim2.fromOffset(width, 56), 26
	playCaption.Position, playCaption.Size = UDim2.fromOffset(0, 5), UDim2.new(1, 0, 0, 30)
	playSub.Visible = true
	playSub.Position, playSub.Size = UDim2.fromOffset(0, 35), UDim2.new(1, 0, 0, 14)
	local top = 62
	tiles.AnchorPoint, tiles.Position = Vector2.zero, UDim2.fromOffset(0, top)
	local utility = 0
	for _, button in buttons do
		local primary = button.Name == "INVENTORY"
		if primary then
			button.Position, button.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(width, 40)
		else
			button.Position = UDim2.fromOffset((utility % 2) * (utilityWidth + gap), 44 + math.floor(utility / 2) * (utilityHeight + gap))
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
				child.AnchorPoint = Vector2.new(0, 0.5)
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
	status.Position, status.Size = UDim2.fromOffset(0, top + tilesHeight + 8), UDim2.fromOffset(width, 54)
	bar.Size = UDim2.fromOffset(width, top + tilesHeight + 8 + 54)
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
	Text = "‹  BACK TO LOBBY",
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
	if on then
		refreshCrowd()
		-- The welcome banner, once the lobby has settled (Modules/LobbyFeed).
		task.delay(1.5, function()
			if wanted and not dashboardShown then
				LobbyFeed.welcome()
			end
		end)
	end
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
