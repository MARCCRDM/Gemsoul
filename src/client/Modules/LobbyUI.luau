--[[
	The lobby (the Saga Outpost): the command column on the left (PLAY, then
	one gunmetal panel of places to go: INVENTORY across it, a two-column
	grid under it, TASKS among it with a count of what's still to do; every
	icon in the one steel, lit amber on hover), your card under it (level,
	name, coins, XP) and your health under that; one small panel on the
	right for the daily streak, the day's challenges and the next mode to
	unlock, a REPORT A BUG button at the top right, and the PLAY menu that
	picks what to play. On a phone: a row of icon tiles at the bottom
	centre, PLAY the first (a green tile; the big PLAY bar goes), INVENTORY
	yellow after it, TASKS one of them, no RANKS; level and coins at the top
	left with your health under them, and nothing on the right: no board
	(the challenges are the Tasks window's DAILY page) and no bug button
	(SOCIAL has the form).

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
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
local BodyHealth = require(script.Parent.BodyHealth)
local CoinShop = require(script.Parent.CoinShop)
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
-- Casual has none: it shows your own miner, in 3D, in the suit you wear
-- (casualScene), so no two cards share a picture.
LobbyUI.Art = {
	Duel = 104755259743768,
	Dungeon = 85958638729400,
	Ranked = 108455735818338,
}

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
		-- (on a phone, clear of the capture buttons Roblox puts at the right edge)
		local margin = if UserInputService.TouchEnabled then 150 else 32
		stageScale.Scale = math.min(1, (screen.X - margin) / 1120, (screen.Y - 24) / 612)
		stage.Position = UDim2.new(0.5, 0, 0.5, 26 * stageScale.Scale)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStage)

local function heading(value, color, x, align)
	local l = text(stage, value, 34, color, IronUi.Heading, align)
	l.Position, l.Size, l.ZIndex = UDim2.fromOffset(x, 0), UDim2.fromOffset(420, 44), 21
	return l
end
-- The title, plain, and a line under it: the cards say the rest.
do
	local title = heading("PLAY", P.Text, 0, Enum.TextXAlignment.Left)
	title.TextSize, title.TextStrokeTransparency = 30, 1
	title.Size = UDim2.fromOffset(420, 36)
	local line = text(stage, "Pick a mode. Every win pays.", 13, P.Dim, IronUi.Body, Enum.TextXAlignment.Left)
	line.Position, line.Size, line.ZIndex = UDim2.fromOffset(0, 34), UDim2.fromOffset(420, 18), 21
	line.TextStrokeTransparency = 1
end
-- Auto queue (Shared.AutoQueue): on call for 1v1s while you're in the
-- lobby, asked when a queue needs an opponent. The player's
-- DuelAuto attribute says where it stands; the switch asks the server.
local AutoQueue = require(game:GetService("ReplicatedStorage").Shared.AutoQueue)
local autoButton = new("TextButton", {
	Position = UDim2.fromOffset(1120 - 220, 2),
	Size = UDim2.fromOffset(220, 30),
	Text = "",
	BackgroundColor3 = Color3.fromRGB(20, 25, 37),
	AutoButtonColor = true,
	ZIndex = 21,
}, stage)
UiKit.round(autoButton, 16)
local autoRim = new("UIStroke", { Color = GREEN, Thickness = 1.5 }, autoButton)
local autoLabel = text(autoButton, "", 13, P.Text, IronUi.Heading)
autoLabel.Size, autoLabel.ZIndex = UDim2.fromScale(1, 1), 22
autoLabel.TextStrokeTransparency = 1
local autoSub = text(stage, "", 10, P.Dim, IronUi.Heading, Enum.TextXAlignment.Right)
autoSub.Position, autoSub.Size, autoSub.ZIndex = UDim2.fromOffset(1120 - 340, 36), UDim2.fromOffset(340, 16), 21
autoSub.TextStrokeTransparency = 1
local function autoOn(): boolean
	local value = player:GetAttribute("DuelAuto")
	return if value == nil then AutoQueue.Default else value == true
end
local function refreshAuto()
	local on = autoOn()
	autoLabel.Text = if on then "MATCH INVITES: ON" else "MATCH INVITES: OFF"
	autoLabel.TextColor3 = if on then GREEN else P.Dim
	autoRim.Color = if on then GREEN else Color3.fromRGB(70, 80, 96)
	autoSub.Text = if on
		then "JOIN ONLY WHEN YOU ACCEPT AN INVITATION"
		else "LOBBY MATCH INVITATIONS ARE MUTED"
end
autoButton.Activated:Connect(function()
	run("DuelAuto", not autoOn())
end)
player:GetAttributeChangedSignal("DuelAuto"):Connect(refreshAuto)
refreshAuto()

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
	local artId = spec.Art and LobbyUI.Art[spec.Art] or 0
	-- (A scene is the card's art drawn in the game: Casual's blades.)
	local hasArt = artId ~= 0 or spec.Scene ~= nil
	if spec.Scene then
		spec.Scene(b)
	end
	if hasArt then
		if artId ~= 0 then
			local art = new("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. artId,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 21,
			}, b)
			UiKit.round(art, 10)
		end
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
		-- Tall card: the emblem up top, the words at the foot, from the left
		-- (the queue's count has the bottom right).
		local left = Enum.TextXAlignment.Left
		emblem = IronUi.emblem(b, spec.Emblem, spec.Color, 120)
		emblem.Position = UDim2.fromOffset((spec.W - 120) / 2, 80)
		kicker = UiKit.fit(place(text(b, spec.Kicker, 16, spec.Color, IronUi.Heading), 30, spec.H - 146, spec.W - 60, 22, left))
		UiKit.fit(place(text(b, spec.Title, 44, P.Text, IronUi.Heading), 28, spec.H - 124, spec.W - 60, 52, left))
		local sub = place(text(b, spec.Sub, 14, P.Dim, IronUi.Body), 30, spec.H - 66, spec.W - 250, 40, left)
		sub.TextWrapped = true
		sub.TextYAlignment = Enum.TextYAlignment.Top
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
	emblem.Visible = not hasArt
	if hasArt and not big then
		-- Words where the emblem was.
		for _, child in b:GetChildren() do
			if child:IsA("TextLabel") then
				child.Position -= UDim2.fromOffset(96, 0)
			end
		end
		-- (The one-line words take the room too, so they keep their size.)
		kicker.Size += UDim2.fromOffset(96, 0)
		title.Size += UDim2.fromOffset(96, 0)
		-- (A scene stands on the right: the words keep to its left.)
		if spec.Scene then
			for _, child in b:GetChildren() do
				if child:IsA("TextLabel") then
					child.Size = UDim2.fromOffset(math.min(child.Size.X.Offset, spec.W - 26 - 128), child.Size.Y.Offset)
				end
			end
		end
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

-- Ranked first, the big card where the eye lands; Casual and Practice
-- stacked beside it; the Bounty Board a bar along the bottom. Casual and
-- Ranked fight on your current stats (Shared.PvPRules: full progression).
card({
	Title = "1v1 RANKED",
	Art = "Ranked",
	Kicker = "RATING 1000",
	Sub = "First to 2 rounds, on your current stats. Swap presets between rounds. Rating on the line.",
	Emblem = "Equipment",
	Color = RED,
	Reward = string.format("WIN +%d ◆", PvPRules.Kinds.Ranked.Rewards.Win),
	Queue = "1v1",
	X = 0,
	Y = 60,
	W = if LobbyUI.DungeonsOpen then 340 else 782,
	H = 440,
	Unlock = "Ranked",
	Go = function()
		run("DuelQueue", "1v1")
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
		H = 440,
		Unlock = "Dungeon",
		Go = function()
			run("DungeonFind")
		end,
	})
end
-- Casual's picture: two blades crossed in a teal glow, drawn flat on the
-- right of the card, clear of the words.
local function casualScene(b: GuiObject)
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -72, 0.47, 0),
		Size = UDim2.fromOffset(124, 124),
		BackgroundColor3 = P.Teal,
		BackgroundTransparency = 0.84,
		ZIndex = 20,
	}, b)
	UiKit.round(glow, 999)
	new("UIStroke", { Color = P.Teal, Thickness = 1.5, Transparency = 0.55 }, glow)
	local STEEL, GRIP = Color3.fromRGB(214, 226, 236), Color3.fromRGB(40, 48, 64)
	for _, tilt in { -42, 42 } do
		-- (a sword stood on its pommel, tip up, turned about its middle)
		local sword = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -72, 0.47, 0),
			Size = UDim2.fromOffset(16, 118),
			BackgroundTransparency = 1,
			Rotation = tilt,
			ZIndex = 21,
		}, b)
		local function piece(x, y, w, h, color, z)
			return new("Frame", {
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = z or 21,
			}, sword)
		end
		piece(5, 4, 6, 74, STEEL)
		local tip = piece(5, 1, 6, 6, STEEL)
		tip.Rotation = 45
		piece(7, 8, 2, 64, P.Teal, 22)
		UiKit.round(piece(-8, 76, 32, 6, P.Teal), 3)
		piece(5, 82, 6, 26, GRIP)
		UiKit.round(piece(3, 107, 10, 10, P.Teal), 999)
	end
end
card({
	Title = "1v1 CASUAL",
	Scene = casualScene,
	Kicker = "NO RATING",
	Sub = "Real players, your current stats. Just for the fight.",
	Emblem = "Equipment",
	Color = P.Teal,
	Reward = string.format("WIN +%d ◆", PvPRules.Kinds.Casual.Rewards.Win),
	Queue = "casual",
	X = 830,
	Y = 60,
	W = 290,
	H = 210,
	Unlock = "Casual",
	Go = function()
		run("DuelQueue", "casual")
	end,
})
card({
	Title = "1v1 PRACTICE",
	Art = "Duel",
	Kicker = "VS A RIVAL",
	Sub = "A rival miner with their own random kit. Coins on a win.",
	Emblem = "Equipment",
	Color = P.Gold,
	Reward = string.format("WIN +%d ◆", Matchmaking.RivalWinCoins),
	X = 830,
	Y = 290,
	W = 290,
	H = 210,
	Go = function()
		require(script.Parent.ArenaScene).enter(true)
	end,
})

-- The Bounty Board (Client.RiftClient: every Rift boss, alone or with your
-- party), a bar along the bottom: the same board as Brutus's counter.
do
	local EMBER = Color3.fromRGB(255, 150, 60)
	local bounty = new("TextButton", {
		Name = "Bounty",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 516),
		Size = UDim2.fromOffset(1120, 44),
		BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient carries the colour
		ZIndex = 21,
	}, stage)
	UiKit.round(bounty, 10)
	-- (dark, like the cards, with an ember edge on the left: not a slab of orange)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(EMBER:Lerp(CARD, 0.8), CARD) }, bounty)
	local rim = new("UIStroke", { Color = EMBER, Thickness = 1.5, Transparency = 0.55 }, bounty)
	local edge = new("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(0, 4, 1, -16),
		BackgroundColor3 = EMBER,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, bounty)
	UiKit.round(edge, 2)
	local name = text(bounty, "BOUNTY BOARD", 20, P.Text, IronUi.Heading)
	name.Position, name.Size, name.ZIndex = UDim2.fromOffset(20, 0), UDim2.fromOffset(220, 44), 22
	name.TextXAlignment = Enum.TextXAlignment.Left
	local what = text(bounty, "RIFT BOSSES  ·  ALONE OR WITH YOUR PARTY", 13, EMBER, IronUi.Heading)
	what.Position, what.Size, what.ZIndex = UDim2.fromOffset(240, 0), UDim2.fromOffset(600, 44), 22
	what.TextXAlignment = Enum.TextXAlignment.Left
	local go = text(bounty, "OPEN  ›", 16, EMBER, IronUi.Heading)
	go.AnchorPoint = Vector2.new(1, 0)
	go.Position, go.Size, go.ZIndex = UDim2.new(1, -20, 0, 0), UDim2.fromOffset(120, 44), 22
	go.TextXAlignment = Enum.TextXAlignment.Right
	bounty.MouseEnter:Connect(function()
		rim.Thickness, rim.Transparency = 2, 0.1
	end)
	bounty.MouseLeave:Connect(function()
		rim.Thickness, rim.Transparency = 1.5, 0.55
	end)
	bounty.Activated:Connect(function()
		LobbyUI.closePicker()
		require(script.Parent.RiftClient).openGate("Bounty")
	end)
end

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
-- While the PLAY menu is up the HUD over the world stands down (KaijuHud's
-- card and team keys, the HYPERBEAM button, SparKit's FIGHT): it sat on top.
picker:GetPropertyChangedSignal("Visible"):Connect(function()
	player:SetAttribute("MenuOpen", if picker.Visible then true else nil)
end)

-- The command stack (left) -------------------------------------------------------------------------
-- PLAY first, where the eye starts; then one panel of places to go; then
-- your card and your health. The right side shows what's happening (daily
-- streak, next unlock). On a phone the stack shrinks to thumb-sized tiles.
--
-- One look throughout: gunmetal plates with a hairline of light along the
-- top, a thin rim that lights amber when you point at it, every icon in
-- the same steel (INVENTORY's in amber, the one place to go first). PLAY
-- is the only coloured thing: a struck amber plate, no shine sweeping it.
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(240, 178, 64), Color3.fromRGB(190, 118, 26)
local GOLD_RIM = Color3.fromRGB(255, 222, 150)
local GOLD_INK = Color3.fromRGB(36, 20, 2)
local FACE_TOP, FACE_BOTTOM = Color3.fromRGB(40, 47, 60), Color3.fromRGB(26, 31, 41)
local RIM = Color3.fromRGB(70, 80, 96)
local ICON = Color3.fromRGB(164, 178, 200) -- every place's icon (INVENTORY's is amber)
local PANEL = Color3.fromRGB(11, 14, 20)
local STACK_W = 204
local PAD = 6 -- inside the panel

-- A hairline of light along the top edge of a plate.
local function lip(parent: GuiObject, transparency: number?)
	return new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = transparency or 0.86,
		Position = UDim2.fromOffset(3, 1),
		Size = UDim2.new(1, -6, 0, 1),
		ZIndex = 2,
	}, parent)
end

-- Its rim lights amber while you point at it.
local function hoverRim(button: GuiButton, rim: UIStroke, base: Color3, lit: Color3)
	button.MouseEnter:Connect(function()
		rim.Color = lit
	end)
	button.MouseLeave:Connect(function()
		rim.Color = base
	end)
end

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
UiKit.round(play, 4)
local playRim = new("UIStroke", { Color = Color3.fromRGB(70, 42, 8), Thickness = 1.5 }, play)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM) }, play)
lip(play, 0.45).BackgroundColor3 = GOLD_RIM
local playCaption = text(play, "PLAY", 30, GOLD_INK, Enum.Font.GothamBlack)
playCaption.Size = UDim2.fromScale(1, 1)
playCaption.TextStrokeTransparency = 1
hoverRim(play, playRim, Color3.fromRGB(70, 42, 8), GOLD_RIM)
-- In a mech, its HOP OUT button takes PLAY's place at the bottom of a
-- phone's screen (Client VehicleDrive). On a phone PLAY is a tile of its
-- own at the start of the row instead (playTile, fitDock).
local phoneDock = false
local function pilotingChanged()
	play.Visible = player:GetAttribute("MechPilot") == nil and not phoneDock
end
player:GetAttributeChangedSignal("MechPilot"):Connect(pilotingChanged)
pilotingChanged()
-- Under PLAY: who's around (or what it opens, alone in a server).
local playSub = text(play, "SELECT A MODE", 10, Color3.fromRGB(78, 46, 6), IronUi.Heading)
playSub.TextStrokeTransparency = 1
IronUi.juice(play, 1.015, 0.98)
play.Activated:Connect(LobbyUI.openPicker)
local modes = text(
	bar,
	if LobbyUI.DungeonsOpen then "1v1 RANKED, DUNGEON, PRACTICE" else "1v1 RANKED, CASUAL, PRACTICE",
	11,
	P.Text,
	IronUi.Heading
)
modes.Position, modes.Size = UDim2.fromOffset(0, 70), UDim2.fromOffset(STACK_W, 20)
modes.BackgroundColor3, modes.BackgroundTransparency = Color3.fromRGB(10, 14, 20), 0.25
UiKit.round(modes, 4)

-- The panel the places to go sit in (on a phone, only the tiles show).
local tiles = new("Frame", {
	Name = "Places",
	Position = UDim2.fromOffset(0, 96),
	Size = UDim2.fromOffset(STACK_W, 320),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.18,
}, bar)
UiKit.round(tiles, 5)
local panelRim = new("UIStroke", { Color = Color3.fromRGB(58, 66, 80), Thickness = 1, Transparency = 0.2 }, tiles)
-- Positions are explicit so Inventory can span both utility columns.

-- One place to go: a gunmetal plate, its icon in steel, its name.
local function tile(label: string, emblem: string, color: Color3, onClick: () -> ())
	local b = new("TextButton", {
		Size = UDim2.fromOffset(STACK_W, 46),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = #tiles:GetChildren(),
	}, tiles)
	UiKit.round(b, 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(FACE_TOP, FACE_BOTTOM) }, b)
	local rim = new("UIStroke", { Color = RIM, Thickness = 1 }, b)
	lip(b)
	hoverRim(b, rim, RIM, P.Gold:Lerp(RIM, 0.25))
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
	name.TextStrokeTransparency = 1
	local chevron = text(b, "›", 22, P.Dim, IronUi.Heading)
	chevron.Name = "NavChevron"
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -12, 0.5, 0)
	chevron.Size = UDim2.fromOffset(16, 24)
	chevron.TextStrokeTransparency = 1
	IronUi.juice(b, 1.015, 0.98)
	b.Activated:Connect(onClick)
	b.Name = label
	return b
end

-- A stack button by its label (the tutorial points at INVENTORY).
function LobbyUI.tile(label: string): GuiButton?
	return tiles:FindFirstChild(label) :: GuiButton?
end

-- Your card under the stack: level, name, coins and the XP to the next
-- level; your health under it.
local status = new("Frame", {
	Size = UDim2.fromOffset(STACK_W, 54),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.12,
}, bar)
UiKit.round(status, 5)
new("UIStroke", { Color = Color3.fromRGB(58, 66, 80), Thickness = 1, Transparency = 0.2 }, status)
local levelBadge = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(22, 26, 34),
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(38, 38),
}, status)
UiKit.round(levelBadge, 19)
new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, levelBadge)
local levelLabel = text(levelBadge, "1", 16, P.Gold, IronUi.Heading)
levelLabel.Size = UDim2.fromScale(1, 1)
levelLabel.TextStrokeTransparency = 1
local nameLabel = text(status, "", 13, P.Text, IronUi.Heading, Enum.TextXAlignment.Left)
nameLabel:SetAttribute("NoTranslate", true) -- (a player's name)
nameLabel.Position, nameLabel.Size = UDim2.fromOffset(54, 7), UDim2.new(1, -140, 0, 18)
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.TextStrokeTransparency = 1
local coinsLabel = text(status, "0", 13, P.Gold, IronUi.Heading, Enum.TextXAlignment.Right)
coinsLabel.AnchorPoint = Vector2.new(1, 0)
coinsLabel.Position, coinsLabel.Size = UDim2.new(1, -9, 0, 7), UDim2.fromOffset(84, 18)
coinsLabel.TextStrokeTransparency = 1
-- (your coins open the coin packs: Client CoinShop)
CoinShop.hook(coinsLabel)
local levelTrack = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = Color3.fromRGB(34, 40, 52),
	Position = UDim2.fromOffset(54, 30),
	Size = UDim2.new(1, -63, 0, 5),
}, status)
UiKit.round(levelTrack, 2)
local levelFill = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = GOLD_TOP,
	Size = UDim2.fromScale(0, 1),
}, levelTrack)
UiKit.round(levelFill, 2)
local xpLabel = text(status, "", 10, P.Dim, IronUi.Body, Enum.TextXAlignment.Left)
xpLabel.Position, xpLabel.Size = UDim2.fromOffset(54, 37), UDim2.new(1, -63, 0, 14)
xpLabel.TextStrokeTransparency = 1

-- Your health, under your card (and, on a phone, under the wallet): a bar
-- in the colour your body's outline would be (green, amber, red: Client
-- BodyHealth), and the numbers.
local function healthBar(parent: Instance, name: string): { Frame: Frame, Fill: Frame, Value: TextLabel, Label: TextLabel }
	local frame = new("Frame", {
		Name = name,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromOffset(STACK_W, 24),
	}, parent)
	UiKit.round(frame, 5)
	new("UIStroke", { Color = Color3.fromRGB(58, 66, 80), Thickness = 1, Transparency = 0.2 }, frame)
	local label = text(frame, "HEALTH", 10, P.Dim, IronUi.Heading, Enum.TextXAlignment.Left)
	label.Position, label.Size = UDim2.fromOffset(9, 0), UDim2.new(0, 52, 1, 0)
	label.TextStrokeTransparency = 1
	local track = new("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(34, 40, 52),
		Position = UDim2.new(0, 62, 0.5, -3),
		Size = UDim2.new(1, -136, 0, 6),
	}, frame)
	UiKit.round(track, 3)
	local fill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = BodyHealth.Outline.Good,
		Size = UDim2.fromScale(1, 1),
	}, track)
	UiKit.round(fill, 3)
	local value = text(frame, "100 / 100", 11, P.Text, IronUi.Heading, Enum.TextXAlignment.Right)
	value:SetAttribute("NoTranslate", true)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position, value.Size = UDim2.new(1, -9, 0, 0), UDim2.new(0, 66, 1, 0)
	value.TextStrokeTransparency = 1
	return { Frame = frame, Fill = fill, Value = value, Label = label }
end
local health = healthBar(bar, "Health")

-- On a phone: level and coins in a pill at the top right, your health
-- under it (MobileLayout.wallet, health).
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
CoinShop.hook(walletPill)
local phoneHealth = healthBar(gui, "PhoneHealth")
phoneHealth.Frame.Visible = false
phoneHealth.Label.Text = "HP"
phoneHealth.Label.Size = UDim2.new(0, 24, 1, 0)
phoneHealth.Frame:FindFirstChild("Track").Position = UDim2.new(0, 30, 0.5, -3)
phoneHealth.Frame:FindFirstChild("Track").Size = UDim2.new(1, -96, 0, 6)
phoneHealth.Value.Size = UDim2.new(0, 58, 1, 0)

-- Your health as it is now, on both bars (redrawn as it changes).
local function showHealth()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now, most = 100, 100
	if humanoid then
		now, most = math.max(0, humanoid.Health), math.max(1, humanoid.MaxHealth)
	end
	local share = math.clamp(now / most, 0, 1)
	for _, meter in { health, phoneHealth } do
		meter.Fill.Size = UDim2.fromScale(share, 1)
		meter.Fill.BackgroundColor3 = BodyHealth.outlineColor(share)
		meter.Value.Text = string.format("%d / %d", math.ceil(now), math.floor(most))
	end
end
local healthWatch: RBXScriptConnection? = nil
local function watchHealth(character: Model?)
	if healthWatch then
		healthWatch:Disconnect()
		healthWatch = nil
	end
	local humanoid = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5))
	if humanoid and humanoid:IsA("Humanoid") then
		healthWatch = humanoid.HealthChanged:Connect(showHealth)
	end
	showHealth()
end
player.CharacterAdded:Connect(watchHealth)
task.defer(watchHealth, player.Character)

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
	local into, need = Tree.progress(xp)
	levelFill.Size = UDim2.fromScale(if maxed then 1 else math.clamp(into / need, 0, 1), 1)
	xpLabel.Text = if maxed
		then "MAX LEVEL"
		else string.format("%d / %d XP to level %d", into, need, level + 1)
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
		playSub.Text = string.format("%d ONLINE, %d SEARCHING", online, searching)
	else
		playSub.Text = if online > 1 then string.format("%d MINERS ONLINE", online) else "SELECT A MODE"
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

-- REPORT A BUG, at the top right: the feedback form
-- (Social), which sends the build and where you were with it. Not on a
-- phone, where the corner is kept clear: SOCIAL has the same form there
-- (its Feedback button). Its words are a label of their own, so the
-- gradient doesn't tint them dark.
local bug = new("TextButton", {
	Name = "ReportBug",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
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

local inventoryLook -- (below: INVENTORY yellow on a phone)
local function fitDock()
	local size = gui.AbsoluteSize
	local mobile = UiKit.handheld(size)
	-- (On a phone: PLAY a green tile first, no RANKS; on a computer the
	-- other way round.)
	local buttons = {}
	for _, button in tiles:GetChildren() do
		if button:IsA("TextButton") then
			button.Visible = not button:GetAttribute(if mobile then "DeskOnly" else "PhoneOnly")
			if button.Visible then table.insert(buttons, button) end
		end
	end
	table.sort(buttons, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	phoneDock = mobile
	pilotingChanged()
	if inventoryLook then
		inventoryLook(mobile)
	end
	modes.Visible = false
	status.Visible = not mobile
	health.Frame.Visible = not mobile
	walletPill.Visible = mobile and not picker.Visible
	phoneHealth.Frame.Visible = mobile and not picker.Visible
	-- (The places' panel shows on a desktop; on a phone, the tiles alone.)
	tiles.BackgroundTransparency = if mobile then 1 else 0.18
	panelRim.Enabled = not mobile
	-- The board under REPORT A BUG on the right (not on a phone); the live
	-- feed at the top centre (on a phone, between your kaiju's card and the
	-- toasts' place: MobileLayout.topGap).
	LobbyBoard.setCompact(mobile)
	LobbyFeed.setCompact(mobile, if mobile then MobileLayout.topGap(size) else nil)
	board.Position = UDim2.new(1, -16, 0, 64)
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
		-- Level and coins up at the top right; nothing either side of PLAY.
		local wallet = MobileLayout.wallet(size)
		walletPill.AnchorPoint, walletPill.Position = Vector2.zero, UDim2.fromOffset(wallet.X, wallet.Y)
		walletPill.Size = UDim2.fromOffset(wallet.W, wallet.H)
		-- Your health just under it, as wide.
		local hp = MobileLayout.health(size)
		phoneHealth.Frame.Position = UDim2.fromOffset(hp.X, hp.Y)
		phoneHealth.Frame.Size = UDim2.fromOffset(hp.W, hp.H)
		tiles.AnchorPoint, tiles.Position = Vector2.new(0, 0), UDim2.fromOffset(0, tilesTop)
		tiles.Size = UDim2.fromOffset(width, tileHeight)
		local tileWidth = math.floor((width - gap * math.max(0, #buttons - 1)) / math.max(1, #buttons))
		-- Each tile: its icon, and its name small under it.
		for i, button in buttons do
			button.Position, button.Size = UDim2.fromOffset((i - 1) * (tileWidth + gap), 0), UDim2.fromOffset(tileWidth, tileHeight)
			for _, child in button:GetChildren() do
				if child.Name == "NavLabel" then
					child.Visible, child.TextSize, child.TextScaled = true, 9, true
					-- (All the same size: no larger than 9, smaller only to fit.)
					local most = child:FindFirstChildOfClass("UITextSizeConstraint")
						or new("UITextSizeConstraint", {}, child)
					most.MaxTextSize = 9
					child.AnchorPoint, child.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -4)
					child.Size, child.TextXAlignment = UDim2.new(1, -6, 0, 11), Enum.TextXAlignment.Center
				elseif child.Name == "NavIcon" then
					child.Visible = true
					child.AnchorPoint, child.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 5)
					child.Size = UDim2.fromOffset(tileHeight - 22, tileHeight - 22)
				elseif child.Name == "NavBadge" then
					child.AnchorPoint, child.Position = Vector2.new(1, 0), UDim2.new(1, -3, 0, 3)
				elseif child.Name == "Lip" or child.Name == "PlayCaption" then
					child.Visible = true
				elseif child:IsA("GuiObject") then child.Visible = false end
			end
		end
		return
	end
	local width, gap, utilityHeight = STACK_W, 4, 34
	local inner = width - PAD * 2
	local utilityWidth = (inner - gap) / 2
	bar.AnchorPoint, bar.Position = Vector2.zero, UDim2.fromOffset(16, 54)
	play.AnchorPoint, play.Position = Vector2.zero, UDim2.fromOffset(0, 0)
	play.Size, playCaption.TextSize = UDim2.fromOffset(width, 58), 28
	playCaption.Position, playCaption.Size = UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 30)
	playSub.Visible = true
	playSub.Position, playSub.Size = UDim2.fromOffset(0, 36), UDim2.new(1, 0, 0, 14)
	local top = 64
	tiles.AnchorPoint, tiles.Position = Vector2.zero, UDim2.fromOffset(0, top)
	local utility = 0
	for _, button in buttons do
		local primary = button.Name == "INVENTORY"
		if primary then
			button.Position, button.Size = UDim2.fromOffset(PAD, PAD), UDim2.fromOffset(inner, 40)
		else
			button.Position = UDim2.fromOffset(
				PAD + (utility % 2) * (utilityWidth + gap),
				PAD + 40 + gap + math.floor(utility / 2) * (utilityHeight + gap)
			)
			button.Size = UDim2.fromOffset(utilityWidth, utilityHeight)
			utility += 1
		end
		for _, child in button:GetChildren() do
			if child.Name == "NavLabel" then
				child.Visible, child.TextScaled, child.TextSize = true, false, if primary then 14 else 11
				local most = child:FindFirstChildOfClass("UITextSizeConstraint")
				if most then
					most:Destroy()
				end
				child.AnchorPoint = Vector2.new(0, 0.5)
				child.Position = if primary then UDim2.new(0, 40, 0.5, 0) else UDim2.new(0, 29, 0.5, 0)
				child.Size = if primary then UDim2.new(1, -64, 0, 20) else UDim2.new(1, -33, 0, 20)
				child.TextXAlignment = Enum.TextXAlignment.Left
			elseif child.Name == "NavIcon" then
				child.Visible = true
				child.AnchorPoint = Vector2.new(0, 0.5)
				local size = if primary then 22 else 15
				child.Size, child.Position = UDim2.fromOffset(size, size), UDim2.new(0, if primary then 10 else 8, 0.5, 0)
			elseif child.Name == "NavChevron" then child.Visible = primary
			elseif child.Name == "NavBadge" then
				-- (At the corner, clear of the name.)
				child.AnchorPoint, child.Position = Vector2.new(0.5, 0.5), UDim2.new(1, -5, 0, 2)
			end
		end
	end
	local tilesHeight = PAD * 2 + 40 + math.ceil(utility / 2) * (utilityHeight + gap)
	tiles.Size = UDim2.fromOffset(width, tilesHeight)
	local below = top + tilesHeight + 6
	status.Position, status.Size = UDim2.fromOffset(0, below), UDim2.fromOffset(width, 54)
	health.Frame.Position, health.Frame.Size = UDim2.fromOffset(0, below + 58), UDim2.fromOffset(width, 24)
	bar.Size = UDim2.fromOffset(width, below + 58 + 24)
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

local inventoryTile = tile("INVENTORY", "Pack", P.Gold, function()
	showDashboard(true)
end)
local UpgradeHints = require(script.Parent.UpgradeHints)
UpgradeHints.bind(inventoryTile, function(hints) return hints.Any end, P.Gold)
local function inventoryUpgradeLabel(hints)
	local chevron = inventoryTile:FindFirstChild("NavChevron")
	if chevron then
		chevron.Text = if hints.Any then "↑" else "›"
		chevron.TextColor3 = if hints.Any then P.Gold else P.Dim
	end
end
UpgradeHints.Changed:Connect(inventoryUpgradeLabel)
inventoryUpgradeLabel(UpgradeHints.Current)
-- STORE (the Store: kaiju, bundles, skins, suits, helmets, visors,
-- pickaxes), right after INVENTORY (third on a phone, after PLAY), blue.
local SKINS_TOP, SKINS_BOTTOM = Color3.fromRGB(86, 156, 255), Color3.fromRGB(34, 92, 214)
local SKINS_EDGE = Color3.fromRGB(10, 34, 92)
local skinsTile = tile("STORE", "Coins", Color3.new(1, 1, 1), function()
	require(script.Parent.ShopUI).toggle()
end)
do
	local face = skinsTile:FindFirstChildOfClass("UIGradient")
	if face then
		face.Color = ColorSequence.new(SKINS_TOP, SKINS_BOTTOM)
	end
	local rim = skinsTile:FindFirstChildOfClass("UIStroke")
	if rim then
		rim.Color = SKINS_EDGE
		skinsTile.MouseLeave:Connect(function()
			rim.Color = SKINS_EDGE
		end)
	end
	local chevron = skinsTile:FindFirstChild("NavChevron")
	if chevron and chevron:IsA("TextLabel") then
		chevron.TextColor3 = Color3.fromRGB(220, 234, 255)
	end
end
-- Tasks and today's challenges: the Tasks window (TrainingRewards.client),
-- with how many are still to do on the tile. (Nothing of them sits on the
-- play screen.)
local tasksTile = tile("TASKS", "Tasks", ICON, function()
	local tasks = player.PlayerGui:FindFirstChild("TrainingRewards")
	local open = tasks and tasks:FindFirstChild("OpenTasks")
	if open and open:IsA("BindableEvent") then
		open:Fire()
	end
end)
local tasksBadge = new("Frame", {
	Name = "NavBadge",
	BackgroundColor3 = P.Gold,
	Size = UDim2.fromOffset(18, 16),
	Visible = false,
	ZIndex = 3,
}, tasksTile)
UiKit.round(tasksBadge, 8)
new("UIStroke", { Color = PANEL, Thickness = 1.5 }, tasksBadge)
local tasksCount = text(tasksBadge, "", 10, Color3.fromRGB(40, 24, 0), IronUi.Heading)
tasksCount.Size, tasksCount.TextStrokeTransparency, tasksCount.ZIndex = UDim2.fromScale(1, 1), 1, 3
tasksCount:SetAttribute("NoTranslate", true)
task.spawn(function()
	local tasks = player:WaitForChild("PlayerGui"):WaitForChild("TrainingRewards", 60)
	if not tasks then
		return
	end
	local function count()
		local open = tasks:GetAttribute("Open")
		open = if type(open) == "number" then open else 0
		tasksCount.Text = if open > 9 then "9+" else tostring(open)
		tasksBadge.Size = UDim2.fromOffset(if open > 9 then 24 else 18, 16)
		tasksBadge.Visible = open > 0
	end
	tasks:GetAttributeChangedSignal("Open"):Connect(count)
	count()
end)
tile("MARKET", "Market", ICON, function()
	require(script.Parent.MarketBoardUI).open()
end)
tile("RANKS", "Ranks", ICON, function()
	require(script.Parent.TopPlayersUI).toggle()
end):SetAttribute("DeskOnly", true) -- (not on a phone)
tile("SOCIAL", "Social", ICON, function()
	require(script.Parent.SocialUI).toggle()
end)
-- Bring a friend: Kindred Edge and the friend ladder (Modules/ReferralUI).
tile("INVITE", "Invite", ICON, function()
	require(script.Parent.ReferralUI).toggle()
end)

-- On a phone, PLAY is the first tile of the row, green, its word across it
-- (the big amber PLAY over the tiles goes; its place stays for HOP OUT and
-- the kit switch beside it). It opens the modes, as PLAY does.
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(88, 212, 118), Color3.fromRGB(32, 146, 70)
local GREEN_EDGE = Color3.fromRGB(12, 66, 32)
local playTile = new("TextButton", {
	Name = "PLAY",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(1, 1, 1),
	LayoutOrder = -1,
	Visible = false,
}, tiles)
playTile:SetAttribute("PhoneOnly", true)
UiKit.round(playTile, 3)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GREEN_TOP, GREEN_BOTTOM) }, playTile)
local playTileRim = new("UIStroke", { Color = GREEN_EDGE, Thickness = 1.5 }, playTile)
lip(playTile, 0.45)
local playWord = text(playTile, "PLAY", 17, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
playWord.Name = "PlayCaption"
playWord.Size = UDim2.fromScale(1, 1)
playWord.TextStrokeColor3, playWord.TextStrokeTransparency = GREEN_EDGE, 0.35
hoverRim(playTile, playTileRim, GREEN_EDGE, Color3.fromRGB(200, 255, 214))
IronUi.juice(playTile, 1.015, 0.98)
playTile.Activated:Connect(LobbyUI.openPicker)

-- INVENTORY on a phone: yellow, like the old PLAY plate, its pack and name
-- in dark ink (on a computer the steel plate, the pack in amber).
local inventoryFace = inventoryTile:FindFirstChildOfClass("UIGradient")
local inventoryRim = inventoryTile:FindFirstChildOfClass("UIStroke")
local inventoryYellow: boolean? = nil
function inventoryLook(yellow: boolean)
	if inventoryYellow == yellow then
		return
	end
	inventoryYellow = yellow
	if inventoryFace then
		inventoryFace.Color = if yellow
			then ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
			else ColorSequence.new(FACE_TOP, FACE_BOTTOM)
	end
	if inventoryRim then
		inventoryRim.Color = if yellow then Color3.fromRGB(70, 42, 8) else RIM
	end
	local ink = if yellow then GOLD_INK else P.Gold
	local name = inventoryTile:FindFirstChild("NavLabel")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if yellow then GOLD_INK else P.Text
	end
	local icon = inventoryTile:FindFirstChild("NavIcon")
	for _, piece in if icon then icon:GetDescendants() else {} do
		if piece:IsA("UIStroke") then
			piece.Color = ink
		elseif piece:IsA("Frame") and piece.BackgroundTransparency < 1 then
			piece.BackgroundColor3 = ink
		end
	end
end

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
-- Called into a match from the lobby (Shared.AutoQueue): the menus come down.
player:GetAttributeChangedSignal("MatchId"):Connect(function()
	if player:GetAttribute("MatchId") then
		LobbyUI.closePicker()
		LobbyUI.closeDashboard()
	end
end)
player:GetAttributeChangedSignal("DuelRating"):Connect(refreshCards)

return LobbyUI
