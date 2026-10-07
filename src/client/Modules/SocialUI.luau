--[[
	Social [P]: everything multiplayer, from the menu.

	  The window   players in the server (level, duel rating, what they're
	               doing; invite to your party, challenge to a duel), your
	               party (slots, ready, leave, kick), the Arena (your rating
	               and record; find a 1v1, queue your party for 2v2, the
	               computer rival, training) and chat (Server and Party
	               channels, through TextChatService so it's filtered).
	  Popups       party invites and duel challenges (Accept / Decline), on
	               any screen; a "searching" banner while queued.
	  Duel overlay the face-off (who's on which side, a countdown), FIGHT!,
	               the time left, and the result (rating change, coins).
	  Playtests    Invite friends (Roblox's invite prompt), Feedback (a bug or
	               idea, sent with the build; owners also read everyone's
	               reports and the most frequent errors there), and client
	               script errors forwarded to the server automatically.

	The server: Party (Remotes.Party) and Duels (Remotes.Social).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local SocialService = game:GetService("SocialService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
local ArenaScene = require(script.Parent.ArenaScene)
local ChallengeChooser = require(script.Parent.ChallengeChooser)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new, text, box, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.clear

local WIDTH, HEIGHT = 1060, 600
local MAX_PARTY = 4
local CHAT_LINES = 80

local SocialUI = {}

-- State from the server.
local party = nil -- { Leader, Members = { { UserId, Name, Class, Ready } }, Channel }
local queued = nil -- { Mode, Since, Waiting }
local match = nil -- { Mode, Ranked, StartsAt, Ends, Team, Teams }
local chatTab = "Server"
local chat = { Server = {}, Party = {} }
local busy = false

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function run(action: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		end
		busy = false
		SocialUI.refresh()
	end)
end

local function record()
	local profile = GemClient.Profile
	return profile and profile.Duel or { Rating = Matchmaking.StartRating, Wins = 0, Losses = 0, Streak = 0 }
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- What someone is doing, from their public attributes.
local function statusOf(other: Player): (string, Color3)
	if other:GetAttribute("MatchId") then
		return "In a duel", P.Bad
	elseif other:GetAttribute("DuelQueue") then
		return "Searching " .. tostring(other:GetAttribute("DuelQueue")), P.Gold
	elseif other:GetAttribute("CombatSession") then
		return "In the Arena", P.Teal
	elseif other:GetAttribute("Expedition") then
		return "Mining", P.Dim
	end
	return "In the menu", P.Good
end

local function isLeader(): boolean
	return party ~= nil and party.Leader == player.UserId
end

local function inParty(userId: number): boolean
	for _, member in (party and party.Members or {}) do
		if member.UserId == userId then
			return true
		end
	end
	return false
end

-- A small flat button for rows and cards.
local function chip(parent: Instance, caption: string, color: Color3, onClick: () -> (), width: number?)
	local b = new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(P.Frame, 0.55),
		Size = UDim2.fromOffset(width or 74, 28),
		Text = caption,
		TextColor3 = P.Text,
		TextSize = 13,
		Font = BOLD,
	}, parent)
	UiKit.round(b, 7)
	new(
		"UIStroke",
		{ Color = color, Thickness = 1.2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		b
	)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end

local function heading(parent: Instance, caption: string, color: Color3?)
	local label = text(parent, caption, 13, color or P.Gold, BOLD)
	label.Size, label.AutomaticSize = UDim2.new(1, 0, 0, 18), Enum.AutomaticSize.None
	return label
end

-- The window -------------------------------------------------------------------

local window = IronUi.window("Social", 11, WIDTH, HEIGHT, "👥", P.Teal)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "SOCIAL"
window.Subtitle.Text = "Party up, chat, and duel other miners in the Arena."

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 82),
	Size = UDim2.fromOffset(WIDTH - 40, HEIGHT - 102),
}, panel)
local COLUMN = (WIDTH - 40 - 24) / 3

-- Column 1: players in the server.
local playersCard = box(body, UDim2.new(), UDim2.fromOffset(COLUMN, HEIGHT - 102), P.Inset, 12)
local playersTitle = heading(playersCard, "IN THIS SERVER")
playersTitle.Position = UDim2.fromOffset(14, 10)
local playerList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 34),
	Size = UDim2.new(1, -20, 1, -44),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = P.Edge,
}, playersCard)
UiKit.list(playerList, 6)

-- Column 2: party (top) and Arena (bottom).
local partyCard = box(body, UDim2.fromOffset(COLUMN + 12, 0), UDim2.fromOffset(COLUMN, 250), P.Inset, 12)
local arenaCard =
	box(body, UDim2.fromOffset(COLUMN + 12, 262), UDim2.fromOffset(COLUMN, HEIGHT - 102 - 262), P.Inset, 12)

-- Column 3: chat.
local chatCard = box(body, UDim2.fromOffset(2 * (COLUMN + 12), 0), UDim2.fromOffset(COLUMN, HEIGHT - 102), P.Inset, 12)
local chatTabs = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 0, 30),
}, chatCard)
UiKit.list(chatTabs, 6, true)
local chatLog = new("ScrollingFrame", {
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 44),
	Size = UDim2.new(1, -20, 1, -96),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = P.Edge,
}, chatCard)
UiKit.round(chatLog, 8)
UiKit.pad(chatLog, 8)
UiKit.list(chatLog, 4)
local chatInput = new("TextBox", {
	BackgroundColor3 = P.Frame,
	Position = UDim2.new(0, 10, 1, -44),
	Size = UDim2.new(1, -96, 0, 34),
	ClearTextOnFocus = false,
	PlaceholderText = "Say something…",
	PlaceholderColor3 = P.Dim,
	Text = "",
	TextColor3 = P.Text,
	TextSize = 14,
	Font = IronUi.Body,
	TextXAlignment = Enum.TextXAlignment.Left,
}, chatCard)
UiKit.round(chatInput, 8)
UiKit.pad(chatInput, 8)
new("UIStroke", { Color = P.Edge, Transparency = 0.4 }, chatInput)

local function channelFor(tab: string): TextChannel?
	local name = if tab == "Party" then (party and party.Channel) else "RBXGeneral"
	local found = name and TextChatService:FindFirstChild(name, true)
	return if found and found:IsA("TextChannel") then found else nil
end

local function send()
	local message = chatInput.Text
	if string.gsub(message, "%s", "") == "" then
		return
	end
	local channel = channelFor(chatTab)
	if not channel then
		UiKit.toast(if chatTab == "Party" then "Join a party to use party chat." else "Chat isn't ready yet.", P.Bad)
		return
	end
	chatInput.Text = ""
	task.spawn(function()
		local ok = pcall(channel.SendAsync, channel, message)
		if not ok then
			UiKit.toast("Couldn't send that message.", P.Bad)
		end
	end)
end
local sendButton = chip(chatCard, "SEND", P.Teal, send, 70)
sendButton.AnchorPoint = Vector2.new(1, 1)
sendButton.Position = UDim2.new(1, -10, 1, -10)
sendButton.Size = UDim2.fromOffset(70, 34)
chatInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		send()
	end
end)

local function drawChat()
	clear(chatLog)
	for i, line in chat[chatTab] do
		local label = text(chatLog, line, 13, P.Text)
		label.RichText = true
		label.LayoutOrder = i
	end
	if #chat[chatTab] == 0 then
		local hint = text(
			chatLog,
			if chatTab == "Party" then "Party chat: only your party sees this." else "Say hello to the server.",
			13,
			P.Dim
		)
		hint.LayoutOrder = 1
	end
	task.defer(function()
		chatLog.CanvasPosition = Vector2.new(0, math.max(0, chatLog.AbsoluteCanvasSize.Y - chatLog.AbsoluteSize.Y))
	end)
end

local function drawChatTabs()
	clear(chatTabs)
	for _, tab in { "Server", "Party" } do
		local on = tab == chatTab
		local b = chip(chatTabs, string.upper(tab), if on then P.Teal else P.Edge, function()
			chatTab = tab
			drawChatTabs()
			drawChat()
		end, 90)
		b.BackgroundColor3 = if on then P.Teal:Lerp(P.Frame, 0.35) else P.Frame
	end
end

local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function addLine(tab: string, line: string)
	local lines = chat[tab]
	table.insert(lines, line)
	while #lines > CHAT_LINES do
		table.remove(lines, 1)
	end
	if gui.Enabled and tab == chatTab then
		drawChat()
	end
end

-- Every message the client can see arrives here (filtered by Roblox).
TextChatService.MessageReceived:Connect(function(message)
	local channel = message.TextChannel
	local name = channel and channel.Name
	local tab = if name == "RBXGeneral" then "Server" elseif party and name == party.Channel then "Party" else nil
	if not tab then
		return
	end
	local source = message.TextSource
	local who = source and Players:GetPlayerByUserId(source.UserId)
	local color = if who == player then "#5ACB96" elseif tab == "Party" then "#3ACBE9" else "#FFCA5B"
	addLine(
		tab,
		string.format(
			'<b><font color="%s">%s</font></b>  %s',
			color,
			escape(if who then who.DisplayName else "?"),
			escape(message.Text)
		)
	)
end)

-- A system line (duel results, party news) in a chat tab.
local function notice(tab: string, line: string)
	addLine(tab, '<font color="#B1C1D8"><i>' .. escape(line) .. "</i></font>")
end

-- Players column.
local function drawPlayers()
	clear(playerList)
	local others = Players:GetPlayers()
	table.sort(others, function(a, b)
		if a == player or b == player then
			return a == player
		end
		return a.DisplayName < b.DisplayName
	end)
	playersTitle.Text = string.format("IN THIS SERVER  ·  %d", #others)
	for i, other in others do
		local row = new("Frame", {
			BackgroundColor3 = if other == player then P.Slot else P.Frame,
			BackgroundTransparency = 0.2,
			Size = UDim2.new(1, -6, 0, 62),
			LayoutOrder = i,
		}, playerList)
		UiKit.round(row, 8)
		local status, statusColor = statusOf(other)
		local initial = IronUi.badge(row, string.upper(string.sub(other.DisplayName, 1, 1)), 34, statusColor)
		initial.Position = UDim2.fromOffset(8, 14)
		local name = text(row, other.DisplayName .. (if other == player then "  (you)" else ""), 14, P.Text, BOLD)
		name.AutomaticSize, name.TextTruncate = Enum.AutomaticSize.None, Enum.TextTruncate.AtEnd
		name.Position, name.Size = UDim2.fromOffset(50, 7), UDim2.new(1, -140, 0, 18)
		local level = other:GetAttribute("SeasonLevel")
		local rating = other:GetAttribute("DuelRating")
		local facts = text(
			row,
			string.format(
				"LV %s  ·  ⚔ %s",
				if level then tostring(level) else "–",
				if rating then tostring(rating) else "–"
			),
			12,
			P.Dim,
			BOLD
		)
		facts.AutomaticSize = Enum.AutomaticSize.None
		facts.Position, facts.Size = UDim2.fromOffset(50, 26), UDim2.new(1, -140, 0, 15)
		local doing = text(row, status, 12, statusColor)
		doing.AutomaticSize = Enum.AutomaticSize.None
		doing.Position, doing.Size = UDim2.fromOffset(50, 42), UDim2.new(1, -140, 0, 15)
		if other ~= player then
			local free = not other:GetAttribute("MatchId") and not other:GetAttribute("Expedition")
			if not inParty(other.UserId) and (party == nil or isLeader()) and other:GetAttribute("PartyId") == nil then
				local invite = chip(row, "+ Party", P.Teal, function()
					run("PartyInvite", other.UserId)
				end, 76)
				invite.Position = UDim2.new(1, -84, 0, 4)
			end
			local duel = chip(row, "⚔ Duel", P.Gold, function()
				ChallengeChooser.open(other.UserId, other.DisplayName)
			end, 76)
			duel.Position = UDim2.new(1, -84, 0, 32)
			duel.Active, duel.AutoButtonColor = free, free
			duel.TextTransparency = if free then 0 else 0.5
		end
	end
end

-- Party card.
local function drawParty()
	clear(partyCard)
	local title = heading(partyCard, "RAID SQUAD")
	title.Position = UDim2.fromOffset(14, 10)
	local count = if party then #party.Members else 1
	local tally = text(partyCard, string.format("%d/%d", count, math.max(3, count)), 12, P.Dim, BOLD)
	tally.AutomaticSize, tally.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Right
	tally.Position, tally.Size = UDim2.new(1, -74, 0, 10), UDim2.fromOffset(60, 18)
	local members = if party
		then party.Members
		else { { UserId = player.UserId, Name = player.DisplayName, Class = "Solo", Ready = false } }
	for i = 1, math.max(3, count) do
		local member = members[i]
		local slot = new("Frame", {
			BackgroundColor3 = if member then P.Slot else P.Frame,
			BackgroundTransparency = if member then 0.1 else 0.5,
			Position = UDim2.fromOffset(10, 34 + (i - 1) * 40),
			Size = UDim2.new(1, -20, 0, 34),
		}, partyCard)
		UiKit.round(slot, 7)
		local crown = if member and party and member.UserId == party.Leader then "👑 " else ""
		local name = text(
			slot,
			if member then crown .. member.Name else "Open teammate slot",
			13,
			if member then P.Text else P.Dim,
			if member then BOLD else IronUi.Body
		)
		name.AutomaticSize, name.TextTruncate = Enum.AutomaticSize.None, Enum.TextTruncate.AtEnd
		name.Position, name.Size = UDim2.fromOffset(10, 8), UDim2.new(1, -110, 0, 18)
		if not member then
			local invite = chip(slot, "Invite friend", P.Teal, function()
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end, 96)
			invite.Position = UDim2.new(1, -102, 0, 3)
		end
		if member and party then
			local ready = text(
				slot,
				if member.Ready then "✓ READY" else "…",
				12,
				if member.Ready then P.Good else P.Dim,
				BOLD
			)
			ready.AutomaticSize, ready.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Right
			ready.Position, ready.Size = UDim2.new(1, -118, 0, 9), UDim2.fromOffset(76, 16)
			if isLeader() and member.UserId ~= player.UserId then
				local kick = chip(slot, "✕", P.Bad, function()
					run("PartyKick", member.UserId)
				end, 30)
				kick.Position, kick.Size = UDim2.new(1, -36, 0, 4), UDim2.fromOffset(30, 26)
			end
		end
	end
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 1, -44),
		Size = UDim2.new(1, -20, 0, 34),
	}, partyCard)
	UiKit.list(actions, 8, true)
	if party then
		local me = nil
		for _, member in party.Members do
			if member.UserId == player.UserId then
				me = member
			end
		end
		local ready = me and me.Ready
		chip(actions, if ready then "Not ready" else "✓ Ready", P.Good, function()
			run("PartyReady", not ready)
		end, 96)
		chip(actions, "Leave party", P.Bad, function()
			run("PartyLeave")
		end, 110)
	else
		local hint = text(actions, "Invite friends above, then use + Party when they join.", 12, P.Dim)
		hint.Size = UDim2.new(1, 0, 1, 0)
	end
end

-- Arena card.
local function drawArena()
	clear(arenaCard)
	local title = heading(arenaCard, "⚔  ARENA DUELS")
	title.Position = UDim2.fromOffset(14, 10)
	local mine = record()
	local rating = text(arenaCard, tostring(mine.Rating), 30, P.Gold, HEADING)
	rating.AutomaticSize = Enum.AutomaticSize.None
	rating.Position, rating.Size = UDim2.fromOffset(14, 32), UDim2.fromOffset(110, 34)
	local facts = text(
		arenaCard,
		string.format(
			"RATING\n%d wins  ·  %d losses%s",
			mine.Wins,
			mine.Losses,
			if (mine.Streak or 0) >= 2 then string.format("  ·  🔥%d streak", mine.Streak) else ""
		),
		12,
		P.Dim,
		BOLD
	)
	facts.AutomaticSize = Enum.AutomaticSize.None
	facts.Position, facts.Size = UDim2.fromOffset(122, 34), UDim2.new(1, -136, 0, 32)
	local rows = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 78),
		Size = UDim2.new(1, -20, 1, -86),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, arenaCard)
	UiKit.list(rows, 8)
	if queued then
		local spec = Matchmaking.Modes[queued.Mode]
		local status = text(
			rows,
			string.format(
				"🔎 Searching for a %s…  %s\n%d searching in this server",
				spec and spec.Name or queued.Mode,
				clock(serverNow() - (queued.Since or serverNow())),
				queued.Waiting or 1
			),
			13,
			P.Gold,
			BOLD
		)
		status.LayoutOrder = 1
		local cancel = chip(rows, "Cancel search", P.Bad, function()
			run("DuelCancel")
		end, 150)
		cancel.LayoutOrder = 2
		return
	end
	local line = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 }, rows)
	UiKit.list(line, 8, true)
	local find = chip(line, "FIND 1v1", P.Gold, function()
		run("DuelQueue", "1v1")
	end, 120)
	find.Size = UDim2.fromOffset(120, 36)
	local pair = party ~= nil and #party.Members == 2
	local team = chip(line, "QUEUE 2v2", if pair and isLeader() then P.Teal else P.Edge, function()
		run("DuelQueue", "2v2")
	end, 120)
	team.Size = UDim2.fromOffset(120, 36)
	local note = text(
		rows,
		if pair and isLeader()
			then "Your party of two can queue 2v2."
			elseif pair then "Your party leader queues 2v2."
			else "2v2 needs a party of exactly two.",
		12,
		P.Dim
	)
	note.LayoutOrder = 2
	local practice = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 3 }, rows)
	UiKit.list(practice, 8, true)
	chip(practice, "VS RIVAL", P.Amethyst, function()
		SocialUI.close()
		ArenaScene.enter(true)
	end, 100)
	chip(practice, "TRAIN", P.Teal, function()
		SocialUI.close()
		ArenaScene.enter(false)
	end, 80)
	local raiders = if party then #party.Members else 1
	chip(
		practice,
		string.format("DUNGEON %d/%d", raiders, Matchmaking.Raid.Min),
		if raiders >= Matchmaking.Raid.Min and isLeader() then Color3.fromRGB(222, 86, 72) else P.Edge,
		SocialUI.raid,
		100
	)
	local rule = text(rows, "Raid squad: you + 2 teammates. Random search fills this server.", 12, P.Dim)
	rule.LayoutOrder = 4
	local raidActions =
		new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 5 }, rows)
	UiKit.list(raidActions, 8, true)
	local searching = player:GetAttribute("DungeonQueue") == true
	chip(
		raidActions,
		if searching then "CANCEL SEARCH" else "FILL RANDOM",
		if searching then P.Bad else P.Teal,
		function()
			run(if searching then "DungeonCancel" else "DungeonFind")
		end,
		145
	)
	chip(raidActions, "START PARTY", P.Gold, function()
		run("PartyDungeon")
	end, 125)
	if searching then
		local waiting = text(rows, "Searching this server... Full squads deploy automatically.", 12, P.Gold)
		waiting.LayoutOrder = 6
	end
end

-- One click from the dashboard: straight into the 1v1 queue.
function SocialUI.findDuel()
	run("DuelQueue", "1v1")
end

-- Your party (the server's last "State"), or nil when you're solo; fires
-- PartyChanged whenever it changes.
SocialUI.PartyChanged = Instance.new("BindableEvent")
function SocialUI.party()
	return party
end

-- The leader starts a Party Raid (three or more against a raid boss).
function SocialUI.raid()
	SocialUI.open()
end

function SocialUI.refresh()
	if not gui.Enabled then
		return
	end
	drawPlayers()
	drawParty()
	drawArena()
	drawChatTabs()
	drawChat()
end

function SocialUI.open()
	gui.Enabled = true
	window.Fit()
	SocialUI.refresh()
end

function SocialUI.close()
	gui.Enabled = false
end

function SocialUI.toggle()
	if gui.Enabled then
		SocialUI.close()
	else
		SocialUI.open()
	end
end

window.Close.Activated:Connect(SocialUI.close)
window.Shade.Activated:Connect(SocialUI.close)

-- Playtest tools: invite friends, feedback (and, for owners, reports) -----------

local function inviteFriends()
	task.spawn(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and can then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			UiKit.toast("Invites aren't available here (try the published game).", P.Bad)
		end
	end)
end

local tools = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -78, 0, 36),
	Size = UDim2.fromOffset(420, 34),
}, panel)
local toolsList = UiKit.list(tools, 8, true)
toolsList.HorizontalAlignment = Enum.HorizontalAlignment.Right
toolsList.VerticalAlignment = Enum.VerticalAlignment.Center
local buildLabel = text(tools, Config.Playtest and Config.Playtest.Build or "", 11, P.Dim, BOLD)
buildLabel.AutomaticSize, buildLabel.Size = Enum.AutomaticSize.X, UDim2.fromOffset(0, 34)
buildLabel.TextYAlignment = Enum.TextYAlignment.Center
local feedbackButton = chip(tools, "🐞 Feedback", P.Gold, function()
	SocialUI.feedback()
end, 110)
feedbackButton.Size = UDim2.fromOffset(110, 32)
local inviteButton = chip(tools, "✉ Invite friends", P.Good, inviteFriends, 130)
inviteButton.Size = UDim2.fromOffset(130, 32)

-- The feedback sheet, over the window.
local sheet = new("Frame", {
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0,
	Position = UDim2.fromOffset(20, 82),
	Size = UDim2.fromOffset(WIDTH - 40, HEIGHT - 102),
	Visible = false,
	ZIndex = 20,
}, panel)
UiKit.round(sheet, 12)
new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, sheet)
local sheetBody = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.new(1, -40, 1, -32),
	ZIndex = 20,
}, sheet)
local feedbackKind = "Bug"

local function zify(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 21
		end
	end
end

local function showForm()
	clear(sheetBody)
	local title = heading(sheetBody, "🐞  SEND FEEDBACK")
	title.TextSize = 16
	local note = text(
		sheetBody,
		"Tell the developer what broke or what you'd love to see. Your report includes the build ("
			.. (Config.Playtest and Config.Playtest.Build or "dev")
			.. ") and where you were.",
		13,
		P.Dim
	)
	note.Position = UDim2.fromOffset(0, 26)
	local kinds = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 32) },
		sheetBody
	)
	UiKit.list(kinds, 8, true)
	for _, kind in { "Bug", "Idea" } do
		local on = kind == feedbackKind
		local b = chip(
			kinds,
			if kind == "Bug" then "🐞 Bug" else "💡 Idea",
			if on then P.Gold else P.Edge,
			function()
				feedbackKind = kind
				showForm()
			end,
			100
		)
		b.BackgroundColor3 = if on then P.Gold:Lerp(P.Frame, 0.4) else P.Frame
	end
	local input = new("TextBox", {
		BackgroundColor3 = P.Inset,
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 1, -170),
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		PlaceholderText = if feedbackKind == "Bug"
			then "What happened, and what were you doing? (e.g. queued 1v1, my opponent left, I got stuck in the Arena)"
			else "What would make the game better?",
		PlaceholderColor3 = P.Dim,
		Text = "",
		TextColor3 = P.Text,
		TextSize = 15,
		Font = IronUi.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, sheetBody)
	UiKit.round(input, 8)
	UiKit.pad(input, 10)
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
	}, sheetBody)
	UiKit.list(actions, 8, true)
	local sendFeedback = chip(actions, "Send", P.Good, function()
		local message = input.Text
		task.spawn(function()
			local result = GemClient.request("SendFeedback", feedbackKind, message)
			UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
			if result.Ok then
				sheet.Visible = false
			end
		end)
	end, 110)
	sendFeedback.Size = UDim2.fromOffset(110, 38)
	local back = chip(actions, "Close", P.Edge, function()
		sheet.Visible = false
	end, 90)
	back.Size = UDim2.fromOffset(90, 38)
	local reports = chip(actions, "📋 Reports (owners)", P.Teal, function()
		SocialUI.reports()
	end, 170)
	reports.Size = UDim2.fromOffset(170, 38)
	zify(sheetBody)
end

local function ago(time: number): string
	local seconds = math.max(0, os.time() - (time or 0))
	if seconds < 3600 then
		return string.format("%dm ago", seconds // 60)
	elseif seconds < 86400 then
		return string.format("%dh ago", seconds // 3600)
	end
	return string.format("%dd ago", seconds // 86400)
end

function SocialUI.reports()
	task.spawn(function()
		local result = GemClient.request("ReadReports")
		if not result.Ok then
			UiKit.toast(result.Message or "Only owners can read reports.", P.Bad)
			return
		end
		clear(sheetBody)
		local title = heading(sheetBody, "📋  PLAYTEST REPORTS")
		title.TextSize = 16
		local close = chip(sheetBody, "Back", P.Edge, showForm, 80)
		close.AnchorPoint, close.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
		for column, spec in { { "FEEDBACK", result.Feedback or {} }, { "MOST FREQUENT ERRORS", result.Errors or {} } } do
			local list = new("ScrollingFrame", {
				BackgroundColor3 = P.Inset,
				BorderSizePixel = 0,
				Position = UDim2.new((column - 1) * 0.5, if column == 1 then 0 else 8, 0, 36),
				Size = UDim2.new(0.5, -8, 1, -36),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
			}, sheetBody)
			UiKit.round(list, 8)
			UiKit.pad(list, 10)
			UiKit.list(list, 8)
			heading(list, spec[1] .. "  ·  " .. #spec[2]).LayoutOrder = 0
			for i, entry in spec[2] do
				local line = if column == 1
					then string.format(
						"<b>%s %s</b>  ·  %s  ·  %s  ·  %s\n%s",
						if entry.Kind == "Bug" then "🐞" else "💡",
						escape(entry.Name or "?"),
						escape(entry.Where or ""),
						escape(entry.Build or ""),
						ago(entry.Time),
						escape(entry.Text or "")
					)
					else string.format(
						'<b>×%d  %s</b>  ·  %s  ·  %s\n%s\n<font color="#B1C1D8">%s</font>',
						entry.Count or 1,
						escape(entry.Side or ""),
						escape(entry.Build or ""),
						ago(entry.Last),
						escape(entry.Message or ""),
						escape(string.sub(entry.Trace or "", 1, 200))
					)
				local label = text(list, line, 12, P.Text)
				label.RichText, label.LayoutOrder = true, i
			end
			if #spec[2] == 0 then
				text(list, "Nothing yet.", 12, P.Dim).LayoutOrder = 1
			end
		end
		zify(sheetBody)
		sheet.Visible = true
	end)
end

function SocialUI.feedback()
	if not gui.Enabled then
		SocialUI.open()
	end
	showForm()
	sheet.Visible = true
end

-- Client script errors go to the server's report log (a few a minute at most).
do
	local sent = {}
	ScriptContext.Error:Connect(function(message, trace)
		local now = os.clock()
		while sent[1] and now - sent[1] > 60 do
			table.remove(sent, 1)
		end
		if #sent < 5 then
			table.insert(sent, now)
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			local report = folder and folder:FindFirstChild("Report")
			if report then
				report:FireServer("Error", string.sub(tostring(message), 1, 300), string.sub(tostring(trace), 1, 600))
			end
		end
	end)
end

-- Popups and the searching banner -----------------------------------------------------

local popups = UiKit.gui("SocialPopups", 22)
local stack = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.55, 0),
	Size = UDim2.fromOffset(330, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, popups)
UiKit.list(stack, 8)

-- A card with Accept / Decline that times out.
local function prompt(
	icon: string,
	title: string,
	line: string,
	seconds: number,
	accent: Color3,
	onAnswer: (boolean) -> ()
)
	local card = new("Frame", {
		BackgroundColor3 = P.Frame,
		Size = UDim2.fromOffset(330, 108),
	}, stack)
	UiKit.round(card, 10)
	new("UIStroke", { Color = accent, Thickness = 1.5 }, card)
	local badge = IronUi.badge(card, icon, 40, accent)
	badge.Position = UDim2.fromOffset(12, 12)
	local head = text(card, title, 15, P.Text, HEADING)
	head.AutomaticSize = Enum.AutomaticSize.None
	head.Position, head.Size = UDim2.fromOffset(62, 10), UDim2.new(1, -72, 0, 20)
	local sub = text(card, line, 12, P.Dim)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.Position, sub.Size = UDim2.fromOffset(62, 32), UDim2.new(1, -72, 0, 30)
	local track = new("Frame", {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -3),
		Size = UDim2.new(1, 0, 0, 3),
	}, card)
	TweenService:Create(track, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
	local answered = false
	local function answer(accept: boolean)
		if answered then
			return
		end
		answered = true
		card:Destroy()
		onAnswer(accept)
	end
	local yes = chip(card, "Accept", P.Good, function()
		answer(true)
	end, 100)
	yes.Position = UDim2.fromOffset(62, 68)
	local no = chip(card, "Decline", P.Bad, function()
		answer(false)
	end, 100)
	no.Position = UDim2.fromOffset(170, 68)
	task.delay(seconds, function()
		if not answered then
			answered = true
			card:Destroy()
		end
	end)
end

local banner = new("TextButton", {
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = P.Frame,
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(540, 40),
	Text = "",
	Visible = false,
}, popups)
UiKit.round(banner, 20)
new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, banner)
local bannerText = text(banner, "", 14, P.Gold, BOLD)
bannerText.AutomaticSize = Enum.AutomaticSize.None
bannerText.Position, bannerText.Size = UDim2.fromOffset(18, 0), UDim2.new(1, -120, 1, 0)
bannerText.TextYAlignment = Enum.TextYAlignment.Center
local bannerCancel = chip(banner, "CANCEL", P.Bad, function()
	run("DuelCancel")
end, 86)
bannerCancel.AnchorPoint = Vector2.new(1, 0.5)
bannerCancel.Position = UDim2.new(1, -8, 0.5, 0)
banner.Activated:Connect(SocialUI.open)

-- The duel overlay ----------------------------------------------------------------

local overlay = UiKit.gui("DuelOverlay", 30)
overlay.IgnoreGuiInset = true
local faceoff = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.15,
	Position = UDim2.new(0.5, 0, 0.16, 0),
	Size = UDim2.fromOffset(560, 150),
	Visible = false,
}, overlay)
UiKit.round(faceoff, 12)
new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, faceoff)
local faceKind = text(faceoff, "", 14, P.Gold, BOLD)
faceKind.AutomaticSize, faceKind.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
faceKind.Position, faceKind.Size = UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 18)
local faceLeft = text(faceoff, "", 20, P.Teal, HEADING)
faceLeft.AutomaticSize, faceLeft.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Right
faceLeft.Position, faceLeft.Size = UDim2.fromOffset(16, 40), UDim2.new(0.5, -60, 0, 50)
local faceVs = text(faceoff, "VS", 22, P.Text, HEADING)
faceVs.AutomaticSize, faceVs.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
faceVs.Position, faceVs.Size = UDim2.new(0.5, -40, 0, 48), UDim2.fromOffset(80, 30)
local faceRight = text(faceoff, "", 20, P.Bad, HEADING)
faceRight.AutomaticSize, faceRight.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Left
faceRight.Position, faceRight.Size = UDim2.new(0.5, 44, 0, 40), UDim2.new(0.5, -60, 0, 50)
local faceCount = text(faceoff, "", 34, P.Gold, HEADING)
faceCount.AutomaticSize, faceCount.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
faceCount.Position, faceCount.Size = UDim2.new(0, 0, 1, -50), UDim2.new(1, 0, 0, 40)
local fightTimer = text(overlay, "", 18, P.Gold, HEADING)
fightTimer.AutomaticSize, fightTimer.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
fightTimer.AnchorPoint = Vector2.new(0.5, 0)
fightTimer.Position, fightTimer.Size = UDim2.new(0.5, 0, 0, 92), UDim2.fromOffset(240, 24)
fightTimer.TextStrokeTransparency = 0.4
fightTimer.Visible = false
local result = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.1,
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(460, 190),
	Visible = false,
}, overlay)
UiKit.round(result, 14)
local resultStroke = new("UIStroke", { Color = P.Gold, Thickness = 2 }, result)
local resultTitle = text(result, "", 40, P.Gold, HEADING)
resultTitle.AutomaticSize, resultTitle.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
resultTitle.Position, resultTitle.Size = UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 46)
local resultLine = text(result, "", 15, P.Text, BOLD)
resultLine.AutomaticSize, resultLine.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
resultLine.Position, resultLine.Size = UDim2.fromOffset(16, 72), UDim2.new(1, -32, 0, 44)
local resultFoot = text(result, "Returning to the menu…", 12, P.Dim)
resultFoot.AutomaticSize, resultFoot.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
resultFoot.Position, resultFoot.Size = UDim2.new(0, 0, 1, -34), UDim2.new(1, 0, 0, 18)

local function names(list): string
	local out = {}
	for _, entry in list or {} do
		table.insert(out, string.format("%s (%d)", entry.Name, entry.Rating or 0))
	end
	return table.concat(out, "\n")
end

local function showFaceoff(info)
	match = info
	result.Visible = false
	local mine, theirs = info.Teams[info.Team], info.Teams[if info.Team == 1 then 2 else 1]
	-- What the fight counts (Shared.PvPRules): the kind, then its stats.
	local rules = info.Rules
	local kind = if info.Ranked
		then "RANKED 1V1"
		elseif rules and rules.Name then string.upper(rules.Name)
		else "FRIENDLY " .. string.upper(info.Mode)
	faceKind.Text = if rules and rules.Label then kind .. "  ·  " .. rules.Label else kind
	faceLeft.Text, faceRight.Text = names(mine), names(theirs)
	faceoff.Visible = true
end

local function showResult(info)
	match = nil
	faceoff.Visible, fightTimer.Visible = false, false
	local color = if info.Draw then P.Dim elseif info.Won then P.Good else P.Bad
	resultTitle.Text = if info.Draw then "DRAW" elseif info.Won then "VICTORY" else "DEFEAT"
	resultTitle.TextColor3, resultStroke.Color = color, color
	local why = if info.Reason == "Time"
		then "Time's up  ·  "
		elseif info.Reason == "Left" or info.Reason == "Forfeit" then "Forfeit  ·  "
		else ""
	local change = if info.Ranked
		then string.format("Rating %d (%s%d)", info.Rating, if info.Delta >= 0 then "+" else "", info.Delta)
		else string.format(
			"%s (unrated)",
			if info.Rules and info.Rules.Name then info.Rules.Name else "Friendly duel"
		)
	resultLine.Text = string.format("%svs %s\n%s  ·  +%d coins", why, info.Opponents or "?", change, info.Coins or 0)
	result.Visible = true
	task.delay(Matchmaking.EndPause + 0.5, function()
		if not match then
			result.Visible = false
		end
	end)
end

-- Every frame: the countdown, the fight timer, the searching banner.
local nextRedraw = 0
game:GetService("RunService").RenderStepped:Connect(function()
	local now = serverNow()
	if match then
		local left = match.StartsAt - now
		if left > 0 then
			faceCount.Text = tostring(math.ceil(left))
		elseif left > -1 then
			faceCount.Text = "FIGHT!"
		else
			faceoff.Visible = false
		end
		fightTimer.Visible = left <= 0
		fightTimer.Text = "⚔ " .. clock(match.Ends - now)
	end
	banner.Visible = queued ~= nil
	if queued then
		local spec = Matchmaking.Modes[queued.Mode]
		bannerText.Text = string.format(
			"🔎  SEARCHING %s  ·  %s  ·  %d in queue",
			string.upper(spec and spec.Name or queued.Mode),
			clock(now - (queued.Since or now)),
			queued.Waiting or 1
		)
	end
	-- The window's live bits (queue time, statuses) redraw twice a second.
	if gui.Enabled and os.clock() >= nextRedraw then
		nextRedraw = os.clock() + 0.5
		drawArena()
	end
end)

-- Server events -------------------------------------------------------------------

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Party").OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "State" then
		local had = party
		party = a
		if party and not had then
			notice("Party", "You're in a party. Messages here go to your party only.")
		elseif had and not party then
			notice("Party", "You left the party.")
			if chatTab == "Party" then
				chatTab = "Server"
			end
		end
		SocialUI.PartyChanged:Fire(party)
		SocialUI.refresh()
	elseif kind == "Invite" then
		prompt("👥", "Party invite", b .. " invited you to their party.", 60, P.Teal, function(accept)
			run("PartyRespond", a, accept)
		end)
	end
end)
remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
	if kind == "Queue" then
		queued = a
		SocialUI.refresh()
	elseif kind == "Challenge" then
		prompt(
			"⚔",
			"Duel challenge",
			string.format(
				"%s (rating %d) challenges you to a 1v1 on %s.",
				b,
				c or 0,
				string.lower(PvPRules.label(PvPRules.profile("Challenge", d)))
			),
			Matchmaking.ChallengeSeconds,
			P.Gold,
			function(accept)
				run("DuelRespond", a, accept)
			end
		)
	elseif kind == "Match" then
		queued = nil
		SocialUI.close()
		showFaceoff(a)
	elseif kind == "Fight" then
		UiKit.toast("FIGHT!", P.Gold)
	elseif kind == "MatchEnd" then
		showResult(a)
		SocialUI.refresh()
	elseif kind == "Feed" then
		notice("Server", a)
	end
end)
Players.PlayerAdded:Connect(function(other)
	notice("Server", other.DisplayName .. " joined the server.")
	SocialUI.refresh()
end)
Players.PlayerRemoving:Connect(function(other)
	notice("Server", other.DisplayName .. " left the server.")
	task.defer(SocialUI.refresh)
end)
GemClient.Changed:Connect(function()
	if gui.Enabled then
		drawArena()
	end
end)

player:GetAttributeChangedSignal("DungeonQueue"):Connect(function()
	SocialUI.refresh()
end)
player:GetAttributeChangedSignal("DungeonId"):Connect(function()
	if player:GetAttribute("DungeonId") then
		SocialUI.close()
	end
end)
return SocialUI
