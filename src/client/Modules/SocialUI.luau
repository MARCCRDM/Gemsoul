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
	               the time left, and the result (rating change, coins; a
	               queued 1v1's arena tournament run and the swings it
	               restored: Shared.SwingRestore).
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
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
-- Squad dungeons and raids switched off (Config.Features): their buttons go.
local dungeonsOpen = not (Config.Features and Config.Features.Dungeons == false)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
local Spar = require(ReplicatedStorage.Shared.Spar)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Referrals = require(ReplicatedStorage.Shared.Referrals)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local ArenaScene = require(script.Parent.ArenaScene)
local ChallengeChooser = require(script.Parent.ChallengeChooser)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new, text, box, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.clear

-- Layout. On a computer, three columns: the miners in this server (left),
-- your party and the Arena (middle), your friends and chat (right). On a
-- phone on its side (SHORT), a window of its own, drawn near full size: one
-- section at a time, picked from tabs in the header.
local SHORT = UiKit.short()
local WIDTH, HEIGHT = if SHORT then 860 else 1060, if SHORT then 340 else 600
local BODY_Y = if SHORT then 72 else 82
local BODY_H = HEIGHT - BODY_Y - (if SHORT then 8 else 20)
local MINERS_W, MIDDLE_W = 440, 280
local PARTY_H = 232
local MAX_PARTY = 4 -- (Systems/Party)
local CHAT_LINES = 80
-- A Roblox headshot by user id (Studio's stand-in players have none).
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local SPAR = Color3.fromRGB(255, 120, 80)
-- Short names for the queues (Matchmaking.Modes), for status lines.
local QUEUE_NAMES = { ["1v1"] = "Ranked", casual = "Casual", ["2v2"] = "2v2" }
-- Text and buttons a size up on a phone.
local ROW_H = if SHORT then 66 else 60
local BUTTON_W, BUTTON_H = if SHORT then 78 else 58, if SHORT then 34 else 28

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

-- What someone is doing, from their public attributes, the most pressing
-- first.
local function statusOf(other: Player): (string, Color3)
	local queue = other:GetAttribute("DuelQueue")
	local band = other:GetAttribute("FrontierBand")
	local zone = if type(band) == "string" then Frontier.Bands[band] else nil
	if other:GetAttribute("MatchId") then
		return "In a duel", P.Bad
	elseif queue then
		return "Queued for " .. (QUEUE_NAMES[queue] or tostring(queue)), P.Gold
	elseif other:GetAttribute("DungeonId") then
		return "In a dungeon", P.Bad
	elseif other:GetAttribute("SparWith") then
		return "Sparring", SPAR
	elseif other:GetAttribute("CombatSession") then
		return "In the Arena", P.Teal
	elseif other:GetAttribute("MechPilot") then
		return "Driving a mech", P.Teal
	elseif other:GetAttribute("Hunt") then
		return "Hunting critters", SPAR
	elseif other:GetAttribute("Expedition") then
		return "On an expedition", P.Dim
	elseif zone and band ~= "Core" then
		return "Mining: " .. zone.Name, zone.Color
	elseif other:GetAttribute("Outpost") then
		return "At the Outpost", P.Good
	end
	return "In the menu", P.Dim
end

-- Free to be challenged: not in a duel or a dungeon, or away on an expedition.
local function free(other: Player): boolean
	return not other:GetAttribute("MatchId")
		and not other:GetAttribute("DungeonId")
		and not other:GetAttribute("Expedition")
end

-- Their miner level (the Augment Tree's, PlayerData), if it's out yet.
local function levelOf(other: Player): number?
	local level = other:GetAttribute("MinerLevel")
	return if type(level) == "number" then level else nil
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
window.Subtitle.Text = "Who's here, your party, your friends and the Arena."
if SHORT then
	-- (a phone: the tabs take the subtitle's place in the header)
	window.Subtitle.Visible = false
	window.Title.Position = UDim2.fromOffset(68, 21)
	window.Title.Size = UDim2.fromOffset(104, 26)
end

local BODY_X = if SHORT then 12 else 20
local BODY_W = WIDTH - 2 * BODY_X
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(BODY_X, BODY_Y),
	Size = UDim2.fromOffset(BODY_W, BODY_H),
}, panel)

-- The sections, each a card. A computer shows the miners, the party and the
-- Arena side by side, with friends and chat sharing the right column under
-- two tabs; a phone shows one section at a time.
local SECTIONS = { "Miners", "Party", "Arena", "Friends", "Chat" }
local section: { [string]: Frame } = {}
local phoneTab = "Miners"
local sideTab = "Friends"
local tabBar: Frame
if SHORT then
	for _, name in SECTIONS do
		section[name] = box(body, UDim2.new(), UDim2.fromScale(1, 1), P.Inset, 12)
	end
	tabBar = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(176, 34),
		Size = UDim2.fromOffset(420, 34),
	}, panel)
else
	section.Miners = box(body, UDim2.new(), UDim2.fromOffset(MINERS_W, BODY_H), P.Inset, 12)
	section.Party = box(body, UDim2.fromOffset(MINERS_W + 12, 0), UDim2.fromOffset(MIDDLE_W, PARTY_H), P.Inset, 12)
	section.Arena = box(
		body,
		UDim2.fromOffset(MINERS_W + 12, PARTY_H + 12),
		UDim2.fromOffset(MIDDLE_W, BODY_H - PARTY_H - 12),
		P.Inset,
		12
	)
	local sideX = MINERS_W + MIDDLE_W + 24
	local side = box(body, UDim2.fromOffset(sideX, 0), UDim2.fromOffset(BODY_W - sideX, BODY_H), P.Inset, 12)
	for _, name in { "Friends", "Chat" } do
		section[name] = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
		}, side)
	end
	tabBar = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 30),
	}, side)
end
UiKit.list(tabBar, 6, true)
local TAB_NAMES = { Miners = "MINERS", Party = "PARTY", Arena = "ARENA", Friends = "FRIENDS", Chat = "CHAT" }

-- Friends ---------------------------------------------------------------------

-- Your Roblox friends who are online (Player:GetFriendsOnline), fetched when
-- the window opens and kept for half a minute; nil until the first answer.
local friends: { any }? = nil
local friendIds: { [number]: boolean } = {}
local friendsAt = -math.huge
local fetchingFriends = false
local function fetchFriends(force: boolean?)
	if fetchingFriends or (not force and os.clock() - friendsAt < 30) then
		return
	end
	fetchingFriends = true
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		fetchingFriends = false
		friendsAt = os.clock()
		friends = if ok and type(list) == "table" then list else {}
		table.clear(friendIds)
		for _, friend in friends :: { any } do
			if type(friend.VisitorId) == "number" then
				friendIds[friend.VisitorId] = true
			end
		end
		if gui.Enabled then
			SocialUI.refresh()
		end
	end)
end

-- Roblox's invite prompt: everyone, or one friend.
local function inviteFriends(userId: number?)
	task.spawn(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not (ok and can) then
			UiKit.toast("Invites aren't available here (try the published game).", P.Bad)
			return
		end
		local options = nil
		if userId then
			pcall(function()
				options = Instance.new("ExperienceInviteOptions")
				options.InviteUser = userId
			end)
		end
		if options then
			pcall(SocialService.PromptGameInvite, SocialService, player, options)
		else
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	end)
end

-- Small pieces ----------------------------------------------------------------

-- Text safe inside rich text (names, chat).
local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- A round avatar: the player's Roblox headshot over the first letter of
-- their name, ringed in `ring` (what they're doing).
local function avatar(parent: Instance, userId: number, name: string, size: number, ring: Color3): Frame
	local holder = new("Frame", { BackgroundColor3 = P.Slot, Size = UDim2.fromOffset(size, size) }, parent)
	UiKit.round(holder, size // 2)
	new("UIStroke", { Color = ring, Thickness = 2, Transparency = 0.1 }, holder)
	local letter = text(holder, string.upper(string.sub(name, 1, 1)), math.floor(size * 0.45), P.Text, BOLD)
	letter.AutomaticSize, letter.Size = Enum.AutomaticSize.None, UDim2.fromScale(1, 1)
	letter.TextXAlignment, letter.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
	if userId > 0 then
		local face = new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = string.format(HEADSHOT, userId),
		}, holder)
		UiKit.round(face, size // 2)
	end
	return holder
end

-- One line of text at a fixed place and size.
local function line(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?, x: number, y: number, w: UDim, h: number): TextLabel
	local label = text(parent, value, size, color, font)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.new(w.Scale, w.Offset, 0, h)
	return label
end

-- A row action: a small button. Off, it's dimmed and says why when pressed.
local function action(parent: Instance, caption: string, color: Color3, why: string?, onClick: () -> (), width: number?)
	local b = chip(parent, caption, if why then P.Edge else color, function()
		if why then
			UiKit.toast(why, P.Gold)
		else
			onClick()
		end
	end, width or BUTTON_W)
	b.TextSize = if SHORT then 13 else 12
	b.Size = UDim2.fromOffset(width or BUTTON_W, BUTTON_H)
	if why then
		b.TextTransparency = 0.45
		b.BackgroundColor3 = P.Frame
	end
	return b
end

-- A mode in the Arena card: a title and a line under it. Off, the line is
-- `short` and pressing it says `why` in full.
local function modeButton(
	parent: Instance,
	title: string,
	sub: string,
	color: Color3,
	why: string?,
	onClick: () -> (),
	short: string?
)
	local on = why == nil
	local b = new("TextButton", {
		AutoButtonColor = on,
		BackgroundColor3 = if on then color:Lerp(P.Frame, 0.62) else P.Frame,
		Text = "",
	}, parent)
	UiKit.round(b, 9)
	new("UIStroke", {
		Color = if on then color else P.Edge,
		Thickness = 1.2,
		Transparency = if on then 0.15 else 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	local big = if SHORT then 15 else 13
	line(b, title, big, if on then P.Text else P.Dim, BOLD, 10, if SHORT then 10 else 6, UDim.new(1, -16), big + 4)
	line(
		b,
		if on then sub else short or why :: string,
		if SHORT then 12 else 10,
		if on then color:Lerp(P.Text, 0.45) else P.Dim,
		IronUi.Body,
		10,
		if SHORT then 32 else 24,
		UDim.new(1, -16),
		if SHORT then 16 else 14
	)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(function()
		if why then
			UiKit.toast(why, P.Gold)
		else
			onClick()
		end
	end)
	return b
end

local function fill(parent: Instance, y: number, bottom: number): ScrollingFrame
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 1, -(y + bottom)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = P.Edge,
	}, parent)
	UiKit.list(list, 6)
	return list
end

-- Miners here -------------------------------------------------------------------

local minersTitle = heading(section.Miners, "MINERS HERE")
minersTitle.Position, minersTitle.Size = UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 18)
local minersList = fill(section.Miners, 34, 10)

-- Why you can't do something with `other` right now (nil: you can).
local function partyWhy(other: Player): string?
	if inParty(other.UserId) then
		return other.DisplayName .. " is in your party."
	elseif other:GetAttribute("PartyId") ~= nil then
		return other.DisplayName .. " is in another party."
	elseif party and not isLeader() then
		return "Only your party leader can invite."
	elseif party and #party.Members >= MAX_PARTY then
		return "Your party is full."
	end
	return nil
end
local function duelWhy(other: Player): string?
	if not free(other) then
		return other.DisplayName .. " is busy: " .. string.lower((statusOf(other))) .. "."
	elseif not free(player) then
		return "Finish what you're doing first."
	end
	return nil
end
local function tradeWhy(other: Player): string?
	if Config.Features and Config.Features.Market == false then
		return "Trading is closed for this playtest."
	elseif other:GetAttribute("MatchId") or player:GetAttribute("MatchId") then
		return "No trading during a duel."
	end
	return nil
end

-- You first, then your party, then friends, then everyone else by name.
local function rank(other: Player): number
	return if other == player then 0 elseif inParty(other.UserId) then 1 elseif friendIds[other.UserId] then 2 else 3
end

local function drawMiners()
	clear(minersList)
	local everyone = Players:GetPlayers()
	table.sort(everyone, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return a.DisplayName < b.DisplayName
	end)
	minersTitle.Text = string.format("MINERS HERE  ·  %d", #everyone)
	for i, other in everyone do
		local me = other == player
		local row = new("Frame", {
			BackgroundColor3 = if me then P.Slot else P.Frame,
			BackgroundTransparency = 0.15,
			Size = UDim2.new(1, -6, 0, ROW_H),
			LayoutOrder = i,
		}, minersList)
		UiKit.round(row, 10)
		local status, statusColor = statusOf(other)
		local face = if SHORT then 46 else 42
		avatar(row, other.UserId, other.DisplayName, face, statusColor).Position =
			UDim2.fromOffset(9, (ROW_H - face) // 2)
		local buttonsW = if me then 0 else 3 * BUTTON_W + 2 * 4
		local textW = UDim.new(1, -(62 + buttonsW + 16))
		local small = if SHORT then 13 else 12
		line(row, other.DisplayName, if SHORT then 16 else 15, P.Text, BOLD, 62, 6, textW, 19)
		local facts = {}
		-- (one tag at most: you, then your party, then a friend)
		if me then
			table.insert(facts, '<font color="#5ADC96">YOU</font>')
		elseif inParty(other.UserId) then
			table.insert(facts, '<font color="#3ACBE9">PARTY</font>')
		elseif friendIds[other.UserId] then
			table.insert(facts, '<font color="#FFCA5B">FRIEND</font>')
		end
		local level = levelOf(other)
		local rating = other:GetAttribute("DuelRating")
		table.insert(facts, "LV " .. (if level then tostring(level) else "–"))
		table.insert(facts, "⚔ " .. (if rating then tostring(rating) else "–"))
		local factLine = line(row, table.concat(facts, "  ·  "), small, P.Dim, BOLD, 62, 26, textW, small + 3)
		factLine.RichText = true
		line(row, "● " .. status, small, statusColor, IronUi.Body, 62, if SHORT then 44 else 41, textW, small + 3)
		if not me then
			local actions = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(buttonsW, BUTTON_H),
			}, row)
			UiKit.list(actions, 4, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
			action(actions, "+ PARTY", P.Teal, partyWhy(other), function()
				run("PartyInvite", other.UserId)
			end)
			action(actions, "⚔ DUEL", P.Gold, duelWhy(other), function()
				ChallengeChooser.open(other.UserId, other.DisplayName)
			end)
			action(actions, "TRADE", P.Good, tradeWhy(other), function()
				SocialUI.close()
				require(script.Parent.TradeUI).openWith(other.UserId)
			end)
		end
	end
end

-- Party -----------------------------------------------------------------------------

local function drawParty(frame: Frame)
	clear(frame)
	local count = if party then #party.Members else 1
	heading(frame, if dungeonsOpen then "RAID SQUAD" else "PARTY").Position = UDim2.fromOffset(14, 10)
	local tally = line(frame, string.format("%d / %d", count, MAX_PARTY), 12, P.Dim, BOLD, 0, 10, UDim.new(0, 60), 18)
	tally.AnchorPoint, tally.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 10)
	tally.TextXAlignment = Enum.TextXAlignment.Right
	-- (a phone: the slots on the left, what to do on the right)
	local slotsW = if SHORT then UDim.new(0, 500) else UDim.new(1, -20)
	local members = if party
		then party.Members
		else { { UserId = player.UserId, Name = player.DisplayName, Ready = false } }
	for i = 1, MAX_PARTY do
		local member = members[i]
		local slot = new("Frame", {
			BackgroundColor3 = if member then P.Slot else P.Frame,
			BackgroundTransparency = if member then 0.1 else 0.5,
			Position = UDim2.fromOffset(10, 34 + (i - 1) * (if SHORT then 44 else 38)),
			Size = UDim2.new(slotsW.Scale, slotsW.Offset, 0, if SHORT then 38 else 32),
		}, frame)
		UiKit.round(slot, 8)
		if not member then
			line(slot, "Open slot", if SHORT then 14 else 12, P.Dim, IronUi.Body, 12, if SHORT then 10 else 8, UDim.new(1, -110), 18)
			local invite = chip(slot, "+ INVITE", P.Teal, function()
				inviteFriends()
			end, 84)
			invite.TextSize, invite.Size = 12, UDim2.fromOffset(84, 24)
			invite.AnchorPoint, invite.Position = Vector2.new(1, 0.5), UDim2.new(1, -4, 0.5, 0)
			continue
		end
		local other = Players:GetPlayerByUserId(member.UserId)
		avatar(slot, member.UserId, member.Name, 24, P.Teal).Position = UDim2.fromOffset(4, 4)
		local level = other and levelOf(other)
		local leader = party ~= nil and member.UserId == party.Leader
		local who = line(
			slot,
			-- (the leader in gold; a phone has room to say so too)
			(if leader then '<font color="#FFCA5B">' .. escape(member.Name) .. "</font>" else escape(member.Name))
				.. (if level then string.format('  <font color="#B1C1D8">LV %d</font>', level) else "")
				.. (if leader and SHORT then '  <font color="#FFCA5B">LEADER</font>' else ""),
			if SHORT then 15 else 13,
			P.Text,
			BOLD,
			36,
			if SHORT then 10 else 8,
			UDim.new(1, -118),
			18
		)
		who.RichText = true
		if party then
			local ready = line(
				slot,
				if member.Ready then "✓ READY" else "NOT READY",
				11,
				if member.Ready then P.Good else P.Dim,
				BOLD,
				0,
				9,
				UDim.new(0, 76),
				14
			)
			ready.TextXAlignment = Enum.TextXAlignment.Right
			ready.AnchorPoint = Vector2.new(1, 0)
			ready.Position = UDim2.new(1, if isLeader() and member.UserId ~= player.UserId then -40 else -10, 0, 9)
			if isLeader() and member.UserId ~= player.UserId then
				local kick = chip(slot, "", P.Bad, function()
					run("PartyKick", member.UserId)
				end, 28)
				kick.AnchorPoint, kick.Position, kick.Size = Vector2.new(1, 0.5), UDim2.new(1, -4, 0.5, 0), UDim2.fromOffset(28, 24)
				IronUi.cross(kick, 10, P.Text)
			end
		end
	end
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		Position = if SHORT then UDim2.fromOffset(530, 34) else UDim2.new(0, 10, 1, -42),
		Size = if SHORT then UDim2.new(1, -544, 1, -44) else UDim2.new(1, -20, 0, 34),
	}, frame)
	UiKit.list(actions, 8, not SHORT)
	local hint = if party
		then "A party of two can queue 2v2 in the Arena. Party chat is in CHAT."
		else "Press + PARTY on a miner to team up, or invite a friend into the game."
	if SHORT or not party then
		local tip = text(actions, hint, if SHORT then 14 else 12, P.Dim)
		tip.LayoutOrder = if SHORT then 0 else 9
		if not SHORT then
			tip.Size = UDim2.new(1, 0, 1, 0)
			tip.AutomaticSize = Enum.AutomaticSize.None
		end
	end
	if party then
		local me = nil
		for _, member in party.Members do
			if member.UserId == player.UserId then
				me = member
			end
		end
		local ready = me and me.Ready
		chip(actions, if ready then "NOT READY" else "✓ READY", P.Good, function()
			run("PartyReady", not ready)
		end, 110).LayoutOrder = 1
		chip(actions, "LEAVE PARTY", P.Bad, function()
			run("PartyLeave")
		end, 120).LayoutOrder = 2
	end
end

-- Arena -----------------------------------------------------------------------------

-- Duels to play before each mode opens, as on the PLAY menu (LobbyUI.Unlocks).
local UNLOCKS = { Casual = 3, Ranked = 10 }
local function lockedWhy(mode: string, title: string): (string?, string?)
	local need = UNLOCKS[mode] or 0
	local profile = GemClient.Profile
	if not Tutorial.Enabled or (profile and profile.Tutorial and profile.Tutorial.Done) then
		return nil
	end
	local played = player:GetAttribute("DuelsPlayed")
	if type(played) ~= "number" then
		played = profile and profile.Duel and profile.Duel.Played or 0
	end
	local left = need - played
	if left <= 0 then
		return nil
	end
	local plural = if left == 1 then "" else "s"
	return string.format("Play %d more duel%s to unlock %s.", left, plural, title),
		string.format("Locked: %d more duel%s", left, plural)
end

-- The search line while queued, kept so its clock ticks (every frame, below).
local searchLine: TextLabel? = nil
local function searchText(): string
	local spec = queued and Matchmaking.Modes[queued.Mode]
	return string.format(
		"Searching for %s…  %s\n%d searching in this server",
		spec and spec.Name or (queued and queued.Mode or ""),
		clock(serverNow() - (queued and queued.Since or serverNow())),
		queued and queued.Waiting or 1
	)
end

local function drawArena(frame: Frame)
	clear(frame)
	searchLine = nil
	heading(frame, "⚔  ARENA").Position = UDim2.fromOffset(14, 10)
	local mine = record()
	-- Your rating and record: on the left of a phone, above the modes elsewhere.
	local rating = line(frame, tostring(mine.Rating), 30, P.Gold, HEADING, 14, 32, UDim.new(0, 120), 34)
	rating.TextTruncate = Enum.TextTruncate.None
	local streak = if (mine.Streak or 0) >= 2 then string.format("  ·  🔥 %d", mine.Streak) else ""
	line(frame, "RANKED RATING", 10, P.Dim, BOLD, 14, 68, UDim.new(0, 200), 13)
	line(frame, string.format("%d W  ·  %d L%s", mine.Wins, mine.Losses, streak), 12, P.Text, BOLD, 14, 82, UDim.new(0, 220), 15)
	if SHORT then
		-- Who's searching right now, as on the PLAY menu.
		line(frame, "SEARCHING NOW", 10, P.Dim, BOLD, 14, 118, UDim.new(0, 200), 13)
		for i, queue in { "1v1", "casual", "2v2" } do
			local searching = 0
			for _, other in Players:GetPlayers() do
				if other:GetAttribute("DuelQueue") == queue then
					searching += 1
				end
			end
			line(
				frame,
				string.format("● %s  ·  %d", Matchmaking.Modes[queue].Name, searching),
				13,
				if searching > 0 then P.Good else P.Dim,
				BOLD,
				14,
				116 + i * 22,
				UDim.new(0, 220),
				17
			)
		end
	end
	local grid = new("Frame", {
		BackgroundTransparency = 1,
		Position = if SHORT then UDim2.fromOffset(250, 34) else UDim2.fromOffset(10, 104),
		Size = if SHORT then UDim2.new(1, -262, 1, -44) else UDim2.new(1, -20, 1, -114),
	}, frame)
	if queued then
		local status = text(grid, searchText(), 13, P.Gold, BOLD)
		status.Position = UDim2.fromOffset(4, 4)
		searchLine = status
		local cancel = chip(grid, "CANCEL SEARCH", P.Bad, function()
			run("DuelCancel")
		end, 150)
		cancel.Position, cancel.Size = UDim2.fromOffset(4, 48), UDim2.fromOffset(150, 34)
		return
	end
	new("UIGridLayout", {
		CellSize = if SHORT then UDim2.new(0.5, -4, 0, 62) else UDim2.new(0.5, -4, 0, 42),
		CellPadding = UDim2.fromOffset(8, if SHORT then 8 else 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local pair = party ~= nil and #party.Members == 2
	local rankedWhy, rankedShort = lockedWhy("Ranked", "Ranked 1v1")
	modeButton(grid, "RANKED 1v1", "Best of 3 · rated", P.Bad, rankedWhy, function()
		run("DuelQueue", "1v1")
	end, rankedShort).LayoutOrder = 1
	local casualWhy, casualShort = lockedWhy("Casual", "Casual 1v1")
	modeButton(grid, "CASUAL 1v1", "Even stats · unrated", P.Teal, casualWhy, function()
		run("DuelQueue", "casual")
	end, casualShort).LayoutOrder = 2
	modeButton(
		grid,
		"2v2 PARTY",
		"You and a teammate",
		P.Amethyst,
		if not pair then "2v2 needs a party of exactly two." elseif not isLeader() then "Your party leader queues 2v2." else nil,
		function()
			run("DuelQueue", "2v2")
		end,
		if not pair then "Needs a party of 2" else "Leader queues"
	).LayoutOrder = 3
	modeButton(grid, "VS RIVAL", string.format("Practice · +%d ◆", Matchmaking.RivalWinCoins), P.Gold, nil, function()
		SocialUI.close()
		ArenaScene.enter(true)
	end).LayoutOrder = 4
	modeButton(grid, "TRAINING", "No risk", P.Good, nil, function()
		SocialUI.close()
		ArenaScene.enter(false)
	end).LayoutOrder = 5
	if dungeonsOpen then
		local raiders = if party then #party.Members else 1
		local searching = player:GetAttribute("DungeonQueue") == true
		modeButton(
			grid,
			if searching then "CANCEL DUNGEON" else "DUNGEON",
			string.format("Squad %d/%d · fills from the server", raiders, Matchmaking.Raid.Min),
			Color3.fromRGB(222, 86, 72),
			nil,
			function()
				if searching then
					run("DungeonCancel")
				elseif party and raiders >= Matchmaking.Raid.Min and isLeader() then
					run("PartyDungeon")
				else
					run("DungeonFind")
				end
			end
		).LayoutOrder = 6
	else
		modeButton(grid, "ALL MODES", "PLAY menu", P.Edge:Lerp(P.Text, 0.3), nil, function()
			SocialUI.close()
			pcall(function()
				require(script.Parent.LobbyUI).openPicker()
			end)
		end).LayoutOrder = 6
	end
end

-- Friends ------------------------------------------------------------------------------

local friendsTitle = heading(section.Friends, "FRIENDS ONLINE")
friendsTitle.Position, friendsTitle.Size = UDim2.fromOffset(14, if SHORT then 10 else 2), UDim2.new(1, -28, 0, 18)
-- (a phone: the list on the left, bringing a friend on the right)
local REFER_H, REFER_W = 74, 250
local friendsList = fill(section.Friends, if SHORT then 34 else 26, if SHORT then 10 else REFER_H + 18)
if SHORT then
	friendsList.Size = UDim2.new(1, -(REFER_W + 30), 1, -44)
end
local refer = new("Frame", {
	BackgroundColor3 = P.Frame,
	AnchorPoint = if SHORT then Vector2.new(1, 0) else Vector2.new(0, 1),
	Position = if SHORT then UDim2.new(1, -10, 0, 34) else UDim2.new(0, 10, 1, -10),
	Size = if SHORT then UDim2.fromOffset(REFER_W, 150) else UDim2.new(1, -20, 0, REFER_H),
}, section.Friends)
UiKit.round(refer, 10)
new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.6 }, refer)

local function drawFriends()
	clear(friendsList)
	clear(refer)
	-- Bring a friend: the referral ladder (Shared.Referrals, Modules/ReferralUI).
	local profile = GemClient.Profile
	local joined = profile and profile.Referrals and profile.Referrals.Count or 0
	local nextTier = Referrals.nextTier(joined)
	line(refer, "BRING A FRIEND", if SHORT then 13 else 11, P.Gold, BOLD, 12, 9, UDim.new(1, if SHORT then -24 else -120), 16)
	local ladder = line(
		refer,
		if nextTier
			then string.format(
				"%d joined  ·  %d more for the next reward",
				joined,
				nextTier.Friends - joined
			)
			else string.format("%d joined  ·  every reward unlocked", joined),
		if SHORT then 13 else 12,
		P.Text,
		IronUi.Body,
		12,
		if SHORT then 30 else 26,
		UDim.new(1, if SHORT then -24 else -120),
		if SHORT then 36 else 30
	)
	ladder.TextWrapped = true
	ladder.TextTruncate = Enum.TextTruncate.None
	local rewards = chip(refer, "REWARDS", P.Gold, function()
		SocialUI.close()
		require(script.Parent.ReferralUI).open()
	end, 96)
	rewards.TextSize, rewards.Size = 12, UDim2.fromOffset(if SHORT then 110 else 96, if SHORT then 34 else 26)
	rewards.AnchorPoint = if SHORT then Vector2.new(0, 1) else Vector2.new(1, 0)
	rewards.Position = if SHORT then UDim2.new(0, 12, 1, -10) else UDim2.new(1, -10, 0, 8)
	local invite = chip(refer, "✉ INVITE", P.Good, function()
		inviteFriends()
	end, 96)
	invite.TextSize, invite.Size = 12, UDim2.fromOffset(if SHORT then 110 else 96, if SHORT then 34 else 26)
	invite.AnchorPoint, invite.Position = Vector2.new(1, 1), UDim2.new(1, -10, 1, if SHORT then -10 else -8)

	if friends == nil then
		friendsTitle.Text = "FRIENDS ONLINE"
		text(friendsList, "Looking for your friends…", 13, P.Dim).LayoutOrder = 1
		return
	end
	local list = friends :: { any }
	friendsTitle.Text = string.format("FRIENDS ONLINE  ·  %d", #list)
	if #list == 0 then
		text(friendsList, "None of your Roblox friends are online right now. Invite one below!", 13, P.Dim).LayoutOrder =
			1
		return
	end
	-- In this server first, then in another server of this game, then online.
	local function where(friend): number
		if Players:GetPlayerByUserId(friend.VisitorId) then
			return 0
		elseif friend.PlaceId == game.PlaceId and friend.GameId and friend.GameId ~= game.JobId then
			return 1
		end
		return 2
	end
	table.sort(list, function(a, b)
		local wa, wb = where(a), where(b)
		if wa ~= wb then
			return wa < wb
		end
		return tostring(a.DisplayName or a.UserName) < tostring(b.DisplayName or b.UserName)
	end)
	for i, friend in list do
		local name = tostring(friend.DisplayName or friend.UserName or "Friend")
		local spot = where(friend)
		local here = Players:GetPlayerByUserId(friend.VisitorId)
		local status, color = "Online", P.Dim
		if here then
			status, color = statusOf(here)
		elseif spot == 1 then
			status, color = "In another server", P.Teal
		elseif type(friend.LastLocation) == "string" and friend.LastLocation ~= "" then
			status = friend.LastLocation
		end
		local row = new("Frame", {
			BackgroundColor3 = P.Frame,
			BackgroundTransparency = 0.15,
			Size = UDim2.new(1, -6, 0, 46),
			LayoutOrder = i,
		}, friendsList)
		UiKit.round(row, 9)
		avatar(row, friend.VisitorId, name, 32, if spot == 2 then P.Edge else color).Position = UDim2.fromOffset(7, 7)
		line(row, name, 13, P.Text, BOLD, 48, 6, UDim.new(1, -134), 17)
		line(row, "● " .. status, 11, color, IronUi.Body, 48, 24, UDim.new(1, -134), 14)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(78, 28),
		}, row)
		UiKit.list(holder, 0, true).HorizontalAlignment = Enum.HorizontalAlignment.Right
		if here then
			action(holder, "+ PARTY", P.Teal, partyWhy(here), function()
				run("PartyInvite", here.UserId)
			end, 76)
		elseif spot == 1 then
			action(holder, "JOIN", P.Good, nil, function()
				local ok = pcall(
					TeleportService.TeleportToPlaceInstance,
					TeleportService,
					friend.PlaceId,
					friend.GameId,
					player
				)
				UiKit.toast(if ok then "Joining " .. name .. "…" else "Couldn't join " .. name .. ".", if ok then P.Gold else P.Bad)
			end, 76)
		else
			action(holder, "INVITE", P.Gold, nil, function()
				inviteFriends(friend.VisitorId)
			end, 76)
		end
	end
end

-- Chat ------------------------------------------------------------------------------------

local chatTabs = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, if SHORT then 8 else 0),
	Size = UDim2.new(1, -20, 0, 30),
}, section.Chat)
UiKit.list(chatTabs, 6, true)
local chatTop = if SHORT then 44 else 36
local chatLog = new("ScrollingFrame", {
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, chatTop),
	Size = UDim2.new(1, -20, 1, -(chatTop + 52)),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = P.Edge,
}, section.Chat)
UiKit.round(chatLog, 8)
chatLog:SetAttribute("NoTranslate", true) -- (players' words stay as they wrote them)
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
}, section.Chat)
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
local sendButton = chip(section.Chat, "SEND", P.Teal, send, 70)
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
	for i, entry in chat[chatTab] do
		local label = text(chatLog, entry, 13, P.Text)
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

-- Roblox's own notices arrive as rich text (fonts, an icon): just the words.
local function plain(value: string): string
	local stripped = string.gsub(value, "<font[^<>]-[Ii]cons[^<>]->[^<>]-</font>", "")
	stripped = string.gsub(stripped, "<[^<>]->", "")
	stripped = string.gsub(stripped, "&lt;", "<")
	stripped = string.gsub(stripped, "&gt;", ">")
	stripped = string.gsub(stripped, "&quot;", '"')
	stripped = string.gsub(stripped, "&apos;", "'")
	stripped = string.gsub(stripped, "&amp;", "&")
	return (string.gsub(stripped, "^%s+", ""))
end

local function addLine(tab: string, entry: string)
	local lines = chat[tab]
	table.insert(lines, entry)
	while #lines > CHAT_LINES do
		table.remove(lines, 1)
	end
	if gui.Enabled and tab == chatTab then
		drawChat()
	end
end

-- A system line (duel results, party news, Roblox's notices) in a chat tab.
local function notice(tab: string, entry: string)
	addLine(tab, '<font color="#B1C1D8"><i>' .. escape(entry) .. "</i></font>")
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
	if not source then
		local words = plain(message.Text or "")
		if words ~= "" then
			notice(tab, words)
		end
		return
	end
	local color = if who == player then "#5ACB96" elseif tab == "Party" then "#3ACBE9" else "#FFCA5B"
	addLine(
		tab,
		string.format(
			'<b><font color="%s">%s</font></b>  %s',
			color,
			escape(if who then who.DisplayName else "Someone"),
			escape(message.Text)
		)
	)
end)

-- Tabs ------------------------------------------------------------------------------------

local function showSections()
	for name, frame in section do
		frame.Visible = if SHORT
			then name == phoneTab
			elseif name == "Friends" or name == "Chat" then name == sideTab
			else true
	end
end

local function drawTabs()
	clear(tabBar)
	local names = if SHORT then SECTIONS else { "Friends", "Chat" }
	for i, name in names do
		local on = if SHORT then name == phoneTab else name == sideTab
		local caption = TAB_NAMES[name]
		if name == "Party" and party then
			caption ..= string.format(" %d", #party.Members)
		elseif name == "Friends" and friends and #(friends :: { any }) > 0 then
			caption ..= string.format(" %d", #(friends :: { any }))
		end
		local b = chip(tabBar, caption, if on then P.Teal else P.Edge, function()
			if SHORT then
				phoneTab = name
			else
				sideTab = name
			end
			SocialUI.refresh()
		end, if SHORT then 80 else 104)
		b.LayoutOrder = i
		b.TextSize = if SHORT then 13 else 12
		b.Size = UDim2.fromOffset(if SHORT then 80 else 104, if SHORT then 34 else 30)
		b.BackgroundColor3 = if on then P.Teal:Lerp(P.Frame, 0.35) else P.Frame
		b.TextColor3 = if on then P.Text else P.Dim
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
	drawTabs()
	showSections()
	drawMiners()
	drawParty(section.Party)
	drawArena(section.Arena)
	drawFriends()
	drawChatTabs()
	drawChat()
end

-- Open, on a section if you name one ("Miners", "Party", "Arena", "Friends"
-- or "Chat"; a computer always shows the first three).
function SocialUI.open(which: string?)
	if which and section[which] then
		if SHORT then
			phoneTab = which
		elseif which == "Friends" or which == "Chat" then
			sideTab = which
		end
	end
	gui.Enabled = true
	window.Fit()
	fetchFriends()
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

-- In the header: the build and Feedback, and Invite friends (on a phone, two
-- round buttons beside the close button).
local tools = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -66, 0, 34),
	Size = UDim2.fromOffset(if SHORT then 84 else 420, 36),
}, panel)
local toolsList = UiKit.list(tools, 8, true)
toolsList.HorizontalAlignment = Enum.HorizontalAlignment.Right
toolsList.VerticalAlignment = Enum.VerticalAlignment.Center
if SHORT then
	for _, spec in { { "🐞", P.Gold, function()
		SocialUI.feedback()
	end }, { "✉", P.Good, function()
		inviteFriends()
	end } } do
		local b = chip(tools, spec[1], spec[2], spec[3], 36)
		b.Size, b.TextSize = UDim2.fromOffset(36, 36), 16
		UiKit.round(b, 18)
	end
else
	local buildLabel = text(tools, Config.Playtest and Config.Playtest.Build or "", 11, P.Dim, BOLD)
	buildLabel.AutomaticSize, buildLabel.Size = Enum.AutomaticSize.X, UDim2.fromOffset(0, 34)
	buildLabel.TextYAlignment = Enum.TextYAlignment.Center
	local feedbackButton = chip(tools, "🐞 Feedback", P.Gold, function()
		SocialUI.feedback()
	end, 110)
	feedbackButton.Size = UDim2.fromOffset(110, 32)
	local inviteButton = chip(tools, "✉ Invite friends", P.Good, function()
		inviteFriends()
	end, 130)
	inviteButton.Size = UDim2.fromOffset(130, 32)
end

-- The feedback sheet, over the window.
local sheet = new("Frame", {
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0,
	Position = if SHORT then UDim2.fromOffset(12, 8) else UDim2.fromOffset(20, 82),
	Size = if SHORT then UDim2.fromOffset(WIDTH - 24, HEIGHT - 16) else UDim2.fromOffset(WIDTH - 40, HEIGHT - 102),
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

-- A card with Accept / Decline that times out. Returns a function that
-- takes it down unanswered (the offer was withdrawn).
local function prompt(
	icon: string,
	title: string,
	line: string,
	seconds: number,
	accent: Color3,
	onAnswer: (boolean) -> ()
): () -> ()
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
	local function dismiss()
		if not answered then
			answered = true
			card:Destroy()
		end
	end
	task.delay(seconds, dismiss)
	return dismiss
end

-- Open spar requests, by who asked: their card's dismiss. Once you're
-- sparring, the rest come down (the server has dropped them).
local sparCards: { [number]: () -> () } = {}
Players.LocalPlayer:GetAttributeChangedSignal("Spar"):Connect(function()
	if Spar.sparring(Players.LocalPlayer) then
		for from, dismiss in sparCards do
			dismiss()
			sparCards[from] = nil
		end
	end
end)

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
-- A queued 1v1's arena tournament (Shared.SwingRestore): a pip for each of
-- its ten wins, this run's lit, the ones that restore swings marked with
-- their share, and what this one restored.
local tourney = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 122),
	Size = UDim2.new(1, -32, 0, 48),
	Visible = false,
}, result)
local pipRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16) }, tourney)
UiKit.list(pipRow, 5, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
local pips = {}
for i = 1, SwingRestore.Tournament do
	local share = SwingRestore.Streak[i]
	local pip = new("Frame", {
		BackgroundColor3 = P.Inset,
		LayoutOrder = i,
		Size = UDim2.fromOffset(if share then 38 else 24, 16),
	}, pipRow)
	UiKit.round(pip, 8)
	local stroke = new("UIStroke", { Color = if share then P.Gold else P.Edge, Thickness = 1.5 }, pip)
	local tag = text(pip, if share then string.format("%d%%", math.floor(share * 100 + 0.5)) else "", 10, P.Text, BOLD)
	tag.AutomaticSize, tag.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
	tag.Size = UDim2.fromScale(1, 1)
	pips[i] = { Frame = pip, Stroke = stroke }
end
local tourneyLine = text(tourney, "", 13, P.Gold, BOLD)
tourneyLine.AutomaticSize, tourneyLine.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
tourneyLine.Position, tourneyLine.Size = UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 20)
local resultFoot = text(result, "Returning to the menu…", 12, P.Dim)
resultFoot.AutomaticSize, resultFoot.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
resultFoot.Position, resultFoot.Size = UDim2.new(0, 0, 1, -34), UDim2.new(1, 0, 0, 18)

-- The pivot window between Ranked rounds: the round's result, what the
-- opponent fought with (scouting), and your presets to lock one in.
local pivotPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.08,
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(620, 370),
	Visible = false,
}, overlay)
UiKit.round(pivotPanel, 14)
local pivotStroke = new("UIStroke", { Color = P.Gold, Thickness = 2 }, pivotPanel)
local pivotScale = new("UIScale", {}, pivotPanel)
local function pivotLabel(value, size, color, font, y, h)
	local l = text(pivotPanel, value, size, color, font)
	l.AutomaticSize, l.TextXAlignment = Enum.AutomaticSize.None, Enum.TextXAlignment.Center
	l.Position, l.Size = UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, h)
	return l
end
local pivotTitle = pivotLabel("", 30, P.Gold, HEADING, 14, 36)
local pivotScore = pivotLabel("", 15, P.Text, BOLD, 52, 20)
local pivotTimer = pivotLabel("", 13, P.Dim, BOLD, 74, 18)
pivotLabel("THEY FOUGHT WITH", 11, P.Dim, BOLD, 102, 14)
local scoutRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 120),
	Size = UDim2.new(1, -32, 0, 26),
}, pivotPanel)
local scoutList = UiKit.list(scoutRow, 8, true)
scoutList.HorizontalAlignment = Enum.HorizontalAlignment.Center
local counterLabel = pivotLabel("COUNTER-PICK  ·  the round loser may switch miners", 12, P.Dim, BOLD, 160, 18)
local pickRow = new("Frame", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 194),
	Size = UDim2.new(1, -32, 0, 64),
}, pivotPanel)
UiKit.list(pickRow, 8, true)
local lockButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 276),
	Size = UDim2.fromOffset(200, 34),
	Text = "LOCK IN",
	TextSize = 15,
	Font = HEADING,
	TextColor3 = P.Frame,
	BackgroundColor3 = P.Gold,
}, pivotPanel)
UiKit.round(lockButton, 8)
local pivotStatus = pivotLabel("", 13, P.Text, BOLD, 318, 18)
local pivotTheirs = pivotLabel("", 12, P.Dim, BOLD, 340, 16)
-- One miner (the roster off): nothing to pick. The break shows the round,
-- what they fought with and READY, in a shorter panel.
if not MinerRoster.Enabled then
	counterLabel.Visible, pickRow.Visible = false, false
	lockButton.Position = UDim2.new(0.5, 0, 0, 170)
	pivotStatus.Position, pivotTheirs.Position = UDim2.fromOffset(16, 212), UDim2.fromOffset(16, 234)
	pivotPanel.Size = UDim2.fromOffset(620, 266)
end
local pivotEnds = 0
local pivotLocked = false
local picked = nil
local canSwap = false

-- (clear of Roblox's buttons at the top of a phone's screen)
local function fitPivot()
	local screen = overlay.AbsoluteSize
	if screen.X > 0 then
		local size = pivotPanel.Size
		local s = math.min(1, (screen.X - 24) / size.X.Offset, (screen.Y - 24) / size.Y.Offset)
		local room, at = UiKit.clearTopbar(screen, Vector2.new(size.X.Offset, size.Y.Offset) * s)
		pivotScale.Scale = s * room
		pivotPanel.Position = at
	end
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPivot)
UiKit.onTopbar(fitPivot)

local drawPicks
function drawPicks()
	clear(pickRow)
	local profile = GemClient.Profile
	local roster = profile and profile.Miners
	for index = 1, if MinerRoster.Enabled then MinerRoster.Count else 0 do
		local miner = roster and roster.Slots[index]
		local selected = picked == index
		local enabled = miner ~= nil and (canSwap or index == roster.Active) and not pivotLocked
		local level = Tree.level(miner and miner.Augments and miner.Augments.XP or 0)
		local button = new("TextButton", {
			Text = string.format("MINER %d · LV %d\n%s", index, level, if selected then "SELECTED" elseif enabled then "COUNTER-PICK" else "LOCKED"),
			TextSize = 13, Font = BOLD, Size = UDim2.fromOffset(184, 62),
			TextColor3 = if selected then P.Frame elseif enabled then P.Text else P.Dim,
			BackgroundColor3 = if selected then P.Gold else P.Inset,
			AutoButtonColor = enabled, LayoutOrder = index,
		}, pickRow)
		UiKit.round(button, 8)
		button.Activated:Connect(function()
			if enabled then picked = index; drawPicks() end
		end)
	end
	lockButton.Text = if pivotLocked then "LOCKED IN" else "READY"
	lockButton.AutoButtonColor = not pivotLocked
end
lockButton.Activated:Connect(function()
	if pivotLocked then return end
	pivotLocked = true
	drawPicks()
	local choice = picked
	task.spawn(function()
		local response = GemClient.request("DuelPivot", choice)
		pivotStatus.Text = response.Message or ""
		if not response.Ok then pivotLocked = false; drawPicks() end
	end)
end)

local function showPivot(info)
	faceoff.Visible, fightTimer.Visible, result.Visible = false, false, false
	if match then
		match.Score = info.Wins
		match.Round = info.Round
	end
	local color = if info.Winner == "You" then P.Good elseif info.Winner == "Them" then P.Bad else P.Dim
	pivotTitle.Text = string.format(
		"ROUND %d  ·  %s",
		info.Round,
		if info.Winner == "You" then "WON" elseif info.Winner == "Them" then "LOST" else "DRAW"
	)
	pivotTitle.TextColor3, pivotStroke.Color = color, color
	pivotScore.Text = string.format(
		"You %d  –  %d Them  ·  first to %d",
		info.Wins.Mine,
		info.Wins.Theirs,
		Matchmaking.Rounds.ToWin
	)
	clear(scoutRow)
	for order, element in info.Scout or {} do
		local tint = GemConfig.ElementColors[element] or P.Text
		local tag = text(scoutRow, string.upper(GemConfig.elementName(element)), 12, tint, BOLD)
		tag.AutomaticSize = Enum.AutomaticSize.None
		tag.Size, tag.LayoutOrder = UDim2.fromOffset(104, 26), order
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.BackgroundColor3, tag.BackgroundTransparency = tint, 0.82
		UiKit.round(tag, 6)
	end
	if not info.Scout or #info.Scout == 0 then
		local none = text(scoutRow, "No elements: no gems in their gear", 12, P.Dim, BOLD)
		none.AutomaticSize = Enum.AutomaticSize.None
		none.Size = UDim2.fromOffset(300, 26)
		none.TextXAlignment = Enum.TextXAlignment.Center
	end
	pivotEnds = info.Ends
	pivotLocked = false
	picked = GemClient.Profile and GemClient.Profile.Miners and GemClient.Profile.Miners.Active or 1
	canSwap = info.CanSwap == true
	pivotStatus.Text = if not MinerRoster.Enabled
		then "Next round soon. Press READY when you are."
		elseif canSwap then "Choose a miner to counter their build, or keep your current miner."
		else "Round won. Keep your miner; your opponent may counter-pick."
	pivotStatus.TextColor3 = P.Text
	pivotTheirs.Text = if MinerRoster.Enabled then "Opponent: choosing…" else "Opponent: getting ready…"
	drawPicks()
	fitPivot()
	pivotPanel.Visible = true
end

-- Both locked: the picks, then the next round's face-off.
local function showReveal(info)
	pivotPanel.Visible = false
	if not match then
		return
	end
	match.Score, match.Round = info.Wins, info.Round
	match.StartsAt, match.Ends = info.StartsAt, info.Ends
	local function picked(list)
		local out = {}
		for _, entry in list or {} do
			table.insert(out, entry.Name .. "\n" .. (if entry.Preset then "→ " .. entry.Preset else "kept setup"))
		end
		return table.concat(out, "\n")
	end
	faceKind.Text = string.format("ROUND %d  ·  YOU %d – %d THEM", info.Round, info.Wins.Mine, info.Wins.Theirs)
	faceLeft.Text, faceRight.Text = picked(info.Picks.Mine), picked(info.Picks.Theirs)
	faceoff.Visible = true
end

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
	if info.Rounds then
		info.Score, info.Round = { Mine = 0, Theirs = 0 }, 1
		faceKind.Text ..= string.format("  ·  FIRST TO %d", info.Rounds.ToWin)
	end
	pivotPanel.Visible = false
	faceoff.Visible = true
end

local function showResult(info)
	match = nil
	faceoff.Visible, fightTimer.Visible, pivotPanel.Visible = false, false, false
	local color = if info.Draw then P.Dim elseif info.Won then P.Good else P.Bad
	resultTitle.Text = if info.Draw then "DRAW" elseif info.Won then "VICTORY" else "DEFEAT"
	resultTitle.TextColor3, resultStroke.Color = color, color
	local why = if info.Reason == "Time"
		then "Time's up  ·  "
		elseif info.Reason == "Left" or info.Reason == "Forfeit" then "Forfeit  ·  "
		else ""
	local rounds = if info.Rounds
		then string.format("Rounds %d – %d  ·  ", info.Rounds.Mine, info.Rounds.Theirs)
		else ""
	local change = if info.Ranked
		then string.format("Rating %d (%s%d)", info.Rating, if info.Delta >= 0 then "+" else "", info.Delta)
		else string.format(
			"%s (unrated)",
			if info.Rules and info.Rules.Name then info.Rules.Name else "Friendly duel"
		)
	resultLine.Text =
		string.format("%s%svs %s\n%s  ·  +%d coins", why, rounds, info.Opponents or "?", change, info.Coins or 0)
	-- The arena tournament: this run's wins, and the swings it restored.
	local t = info.Tournament
	tourney.Visible = t ~= nil
	result.Size = UDim2.fromOffset(460, if t then 224 else 190)
	if t then
		local wins = t.Win
		for i, pip in pips do
			local share = SwingRestore.Streak[i]
			pip.Frame.BackgroundColor3 = if i <= wins then (if share then P.Gold else P.Good) else P.Inset
			pip.Frame.BackgroundTransparency = if i <= wins then 0.1 else 0.3
		end
		local nextShare = string.format("%d%%", math.floor((t.NextShare or 0) * 100 + 0.5))
		tourneyLine.TextColor3 = if t.Champion then P.Gold elseif t.Swings > 0 then P.Good else P.Text
		tourneyLine.Text = if t.Champion
			then string.format("TOURNAMENT WON!  ·  +%d swings restored", t.Swings)
			elseif t.Swings > 0 then string.format("Tournament win %d / %d  ·  +%d swings restored", t.Win, t.Of, t.Swings)
			elseif t.Share > 0 then string.format("Tournament win %d / %d  ·  your swings are full", t.Win, t.Of)
			elseif info.Won and not t.Counted then "Same opponent twice running: this win doesn't count"
			elseif info.Won then string.format("Tournament win %d / %d  ·  win %d restores %s swings", t.Win, t.Of, t.NextAt, nextShare)
			else string.format("Tournament run over  ·  your next win restores %s swings", nextShare)
	end
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
		fightTimer.Visible = left <= 0 and not pivotPanel.Visible
		fightTimer.Text = if match.Score
			then string.format(
				"R%d  ·  %d – %d  ·  ⚔ %s",
				match.Round or 1,
				match.Score.Mine,
				match.Score.Theirs,
				clock(match.Ends - now)
			)
			else "⚔ " .. clock(match.Ends - now)
	end
	if pivotPanel.Visible then
		pivotTimer.Text = string.format("Next round in %s", clock(pivotEnds - now))
	end
	-- (not over the Social window: its Arena section shows the search)
	banner.Visible = queued ~= nil and not gui.Enabled
	if queued and searchLine and searchLine.Parent then
		searchLine.Text = searchText()
	end
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
	elseif kind == "SparAsk" and type(a) == "number" then
		-- Someone near you asks for a friendly spar in the lobby (Shared.Spar).
		if sparCards[a] then
			sparCards[a]()
		end
		local from = a
		sparCards[from] = prompt(
			"⚔",
			"Spar request",
			string.format("%s wants a friendly spar. Nothing is lost, win or lose.", tostring(b)),
			if type(c) == "number" then c else Spar.AskSeconds,
			Color3.fromRGB(255, 92, 76),
			function(accept)
				sparCards[from] = nil
				task.spawn(function()
					local result = GemClient.request("SparRespond", from, accept)
					if result.Message and result.Message ~= "" then
						UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
					end
				end)
			end
		)
	elseif kind == "SparAskOver" and type(a) == "number" then
		-- They're sparring with someone else now, busy, or gone.
		if sparCards[a] then
			sparCards[a]()
			sparCards[a] = nil
		end
	elseif kind == "Match" then
		queued = nil
		SocialUI.close()
		showFaceoff(a)
	elseif kind == "Fight" then
		UiKit.toast("FIGHT!", P.Gold)
	elseif kind == "Round" then
		if a.Phase == "Pivot" then
			showPivot(a)
		elseif a.Phase == "Locked" then
			if match and a.Team ~= match.Team then
				pivotTheirs.Text = "Opponent: LOCKED IN"
			end
		elseif a.Phase == "Reveal" then
			showReveal(a)
		end
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
		drawArena(section.Arena)
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
