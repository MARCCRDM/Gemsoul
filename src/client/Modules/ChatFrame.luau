-- The chat frame: a classic MMO chat box on the dashboard and at the Outpost.
-- Tabs (All, Trade, Party, LFG, Whispers, Loot) with unread counts, channel
-- colours, slash commands (/2 trade, /w name, /r, /roll, /invite, /duel ...),
-- click a line to whisper, invite, duel or trade its sender, item links in
-- [brackets], one-tap LFG posts, and loot/system lines. Messages go through
-- TextChatService, so Roblox filters them.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local ChatRules = require(ReplicatedStorage.Shared.ChatRules)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local TradeUI = require(script.Parent.TradeUI)
local UiKit = require(script.Parent.UiKit)

local ChatFrame = {}
local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local BOLD, BODY = IronUi.Bold, IronUi.Body
local GOLD = Color3.fromRGB(232, 168, 52)
local LINK = Color3.fromRGB(255, 160, 40)

local WIDTH, HEIGHT = 440, 240
local KEEP = 200 -- lines remembered
local IDLE_FADE = 10 -- seconds before the background fades back

-- State.
type Entry = { Channel: string, Text: string, From: number?, Order: number }
local entries: { Entry } = {}
local order = 0
local activeTab = "All"
local speaking = "General" -- the channel the input types into
local whisperTarget: { UserId: number, Name: string }? = nil
local lastWhisperFrom: { UserId: number, Name: string }? = nil
local unread: { [string]: number } = {}
local partyChannel: string? = nil
local whisperChannels: { [number]: string } = {} -- partner UserId -> channel name
local lastActivity = 0
local collapsed = false
local autoCollapsed = false -- folded by itself over the dashboard

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end
local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
-- [Item names] in a message stand out like item links.
local function linkify(value: string): string
	return (string.gsub(value, "%[([^%]]+)%]", '<b><font color="' .. hex(LINK) .. '">[%1]</font></b>'))
end

-- The frame -------------------------------------------------------------------------------

local gui = UiKit.gui("ChatFrame", 5)
gui.Enabled = false
local frame = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -6),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundColor3 = Color3.fromRGB(6, 8, 16),
	BackgroundTransparency = 0.45,
}, gui)
UiKit.round(frame, 8)
local frameStroke = new("UIStroke", { Color = P.Edge, Transparency = 0.6 }, frame)

local tabsRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(6, 4),
	Size = UDim2.new(1, -40, 0, 24),
}, frame)
UiKit.list(tabsRow, 3, true)

local collapse = new("TextButton", {
	Text = "–",
	TextSize = 18,
	Font = BOLD,
	TextColor3 = P.Dim,
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.3,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -6, 0, 4),
	Size = UDim2.fromOffset(26, 22),
	AutoButtonColor = false,
}, frame)
UiKit.round(collapse, 5)

local log = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 32),
	Size = UDim2.new(1, -12, 1, -70),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = P.Edge,
}, frame)
local logList = UiKit.list(log, 1)
logList.VerticalAlignment = Enum.VerticalAlignment.Bottom

-- One-tap Looking For Group posts (shown on the LFG tab).
local lfgRow = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 8, 1, -38),
	Size = UDim2.new(1, -16, 0, 24),
	Visible = false,
}, frame)
UiKit.list(lfgRow, 4, true)

local inputRow = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.35,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, -6),
	Size = UDim2.new(1, -12, 0, 28),
}, frame)
UiKit.round(inputRow, 6)
local inputStroke = new("UIStroke", { Color = P.Edge, Transparency = 0.5 }, inputRow)
local channelButton = new("TextButton", {
	Text = "",
	TextSize = 13,
	Font = BOLD,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.fromOffset(92, 28),
	TextXAlignment = Enum.TextXAlignment.Left,
	AutoButtonColor = false,
}, inputRow)
local input = new("TextBox", {
	Text = "",
	PlaceholderText = "Press Enter to chat  ·  /help",
	PlaceholderColor3 = Color3.fromRGB(120, 130, 150),
	TextSize = 14,
	Font = BODY,
	TextColor3 = P.Text,
	BackgroundTransparency = 1,
	ClearTextOnFocus = false,
	Position = UDim2.fromOffset(102, 0),
	Size = UDim2.new(1, -164, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, inputRow)
local function iconButton(value, x, tip)
	local b = new("TextButton", {
		Text = value,
		TextSize = 14,
		Font = BOLD,
		TextColor3 = P.Dim,
		BackgroundColor3 = P.Inset,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(26, 22),
		AutoButtonColor = false,
	}, inputRow)
	UiKit.round(b, 5)
	b:SetAttribute("Tip", tip)
	IronUi.highlight(b)
	return b
end
local linkButton = iconButton("[ ]", -34, "Link an item")
local sendButton = iconButton("↵", -4, "Send")

-- Lines ----------------------------------------------------------------------------------

local function channelOf(id: string)
	return ChatRules.Channels[id] or ChatRules.Channels.System
end

local function tabShows(tabId: string, channel: string): boolean
	for _, tab in ChatRules.Tabs do
		if tab.Id == tabId then
			return tab.Shows[channel] == true
		end
	end
	return false
end

local openMenu -- forward

local function lineButton(entry: Entry)
	local b = new("TextButton", {
		Text = entry.Text,
		RichText = true,
		TextSize = 14,
		Font = BODY,
		TextColor3 = channelOf(entry.Channel).Color,
		TextStrokeTransparency = 0.55,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = entry.Order,
	}, log)
	if entry.From and entry.From ~= player.UserId then
		b.Activated:Connect(function()
			openMenu(entry.From)
		end)
	end
	return b
end

local function scrollToEnd()
	task.defer(function()
		log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteSize.Y))
	end)
end

local drawTabs -- forward

local function redraw()
	for _, child in log:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, entry in entries do
		if tabShows(activeTab, entry.Channel) then
			lineButton(entry)
			shown += 1
		end
	end
	if shown == 0 then
		local hint = activeTab == "Whisper" and "Click a name in chat or type /w name to whisper."
			or activeTab == "Party" and "Party chat: only your party sees this. /p to talk here."
			or activeTab == "Trade" and "Trade chat: post what you're buying and selling. Link items with [ ]."
			or activeTab == "LFG" and "Looking for group: tap a quick post below or type /3."
			or activeTab == "Loot" and "Your finds and rare server drops show up here."
			or "Welcome! Press Enter to chat, /help for commands."
		lineButton({ Channel = "System", Text = "<i>" .. hint .. "</i>", Order = 0 })
	end
	scrollToEnd()
end

-- Adds a line. `text` is already rich text; `from` is the speaker's UserId.
local function push(channel: string, text: string, from: number?)
	order += 1
	local entry = { Channel = channel, Text = text, From = from, Order = order }
	table.insert(entries, entry)
	while #entries > KEEP do
		table.remove(entries, 1)
	end
	if tabShows(activeTab, channel) then
		-- The empty-tab hint goes once there's a real line.
		for _, child in log:GetChildren() do
			if child:IsA("TextButton") and child.LayoutOrder == 0 then
				child:Destroy()
			end
		end
		lineButton(entry)
		local lines = {}
		for _, child in log:GetChildren() do
			if child:IsA("TextButton") then
				table.insert(lines, child)
			end
		end
		if #lines > 120 then
			table.sort(lines, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			lines[1]:Destroy()
		end
		scrollToEnd()
	end
	-- Unread counts on the other tabs (player talk and loot, not system noise).
	if channel ~= "System" then
		for _, tab in ChatRules.Tabs do
			if tab.Id ~= activeTab and tab.Shows[channel] and tab.Id ~= "All" then
				unread[tab.Id] = (unread[tab.Id] or 0) + 1
			end
		end
		if drawTabs then
			drawTabs()
		end
	end
	lastActivity = os.clock()
end

local function systemLine(text: string)
	push("System", escape(text))
end

function ChatFrame.system(text: string)
	systemLine(text)
end
function ChatFrame.loot(text: string)
	push("Loot", linkify(escape(text)))
end

-- Tabs and the channel the input speaks in ----------------------------------------------

local function setSpeaking(channel: string)
	if channel ~= "Whisper" then
		whisperTarget = nil
	end
	speaking = channel
	local def = channelOf(channel)
	channelButton.TextColor3 = def.Color
	channelButton.Text = if channel == "Whisper" and whisperTarget
		then "To " .. whisperTarget.Name .. ":"
		else "[" .. def.Label .. "]"
	inputStroke.Color = def.Color
end

drawTabs = function()
	for _, child in tabsRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, tab in ChatRules.Tabs do
		local on = tab.Id == activeTab
		local count = unread[tab.Id] or 0
		local value = tab.Label .. (if count > 0 then " " .. math.min(count, 99) else "")
		local width = 16 + #value * 7
		local b = new("TextButton", {
			Text = value,
			TextSize = 11,
			Font = BOLD,
			TextColor3 = if on
				then GOLD
				elseif count > 0 and tab.Id == "Whisper" then ChatRules.Channels.Whisper.Color
				elseif count > 0 then P.Text
				else P.Dim,
			BackgroundColor3 = if on then Color3.fromRGB(40, 32, 18) else Color3.fromRGB(14, 16, 28),
			BackgroundTransparency = if on then 0.1 else 0.35,
			Size = UDim2.fromOffset(width, 22),
			LayoutOrder = i,
			AutoButtonColor = false,
		}, tabsRow)
		UiKit.round(b, 5)
		if on then
			new("UIStroke", { Color = GOLD, Transparency = 0.35 }, b)
		end
		b:SetAttribute("UiSound", "Tab")
		b.Activated:Connect(function()
			activeTab = tab.Id
			unread[tab.Id] = nil
			if collapsed then
				ChatFrame.setCollapsed(false)
			end
			-- Typing follows the tab (a whisper keeps its target).
			local speak = ChatRules.TabSpeaks[tab.Id]
			if speak == "Whisper" then
				local who = whisperTarget or lastWhisperFrom
				if who then
					whisperTarget = who
					setSpeaking("Whisper")
				end
			elseif speak then
				setSpeaking(speak)
			end
			lfgRow.Visible = activeTab == "LFG" and not collapsed
			log.Size = UDim2.new(1, -12, 1, if lfgRow.Visible then -98 else -70)
			drawTabs()
			redraw()
		end)
	end
end

function ChatFrame.setCollapsed(value: boolean)
	collapsed = value
	if not value then
		autoCollapsed = false
		lastActivity = os.clock()
	end
	log.Visible = not value
	inputRow.Visible = not value
	lfgRow.Visible = not value and activeTab == "LFG"
	frame.Size = UDim2.fromOffset(WIDTH, if value then 32 else HEIGHT)
	collapse.Text = if value then "+" else "–"
	if not value then
		redraw()
	end
end
collapse.Activated:Connect(function()
	ChatFrame.setCollapsed(not collapsed)
end)

-- Sending --------------------------------------------------------------------------------

local function textChannel(name: string?, wait: number?): TextChannel?
	if not name then
		return nil
	end
	local deadline = os.clock() + (wait or 0)
	repeat
		local found = TextChatService:FindFirstChild(name, true)
		if found and found:IsA("TextChannel") then
			return found
		end
		if os.clock() < deadline then
			task.wait(0.1)
		end
	until os.clock() >= deadline
	return nil
end

local function sendTo(channel: TextChannel?, text: string, failure: string)
	if not channel then
		systemLine(failure)
		return
	end
	task.spawn(function()
		local ok = pcall(channel.SendAsync, channel, text)
		if not ok then
			systemLine("Couldn't send that message.")
		end
	end)
end

local function channelName(id: string): string?
	if id == "General" then
		return "RBXGeneral"
	elseif id == "Party" then
		return partyChannel
	end
	return ChatRules.TextChannels[id]
end

local function whisper(target, text: string)
	local partnerName = target.Name or target.DisplayName
	whisperTarget = { UserId = target.UserId, Name = partnerName }
	setSpeaking("Whisper")
	if text == "" then
		return
	end
	task.spawn(function()
		local name = whisperChannels[target.UserId]
		if not name then
			local result = GemClient.request("ChatWhisper", target.UserId)
			if not result.Ok then
				if result.Message ~= "" then
					systemLine(result.Message)
				end
				return
			end
			name = result.Channel
			whisperChannels[target.UserId] = name
		end
		sendTo(textChannel(name, 3), text, "Couldn't reach " .. partnerName .. ".")
	end)
end

local function findPlayer(name: string)
	local found, problem = ChatRules.findPlayer(name, Players:GetPlayers())
	if not found then
		systemLine(problem or "Nobody by that name.")
	elseif found == player then
		systemLine("That's you!")
		return nil
	end
	return found
end

local function act(action: string, userId: number)
	task.spawn(function()
		local result = GemClient.request(action, userId)
		if result.Message and result.Message ~= "" then
			systemLine(result.Message)
		end
	end)
end

local function run(line: string)
	local command = ChatRules.parse(line, speaking)
	if not command then
		return
	end
	local kind = command.Kind
	if kind == "Send" then
		if command.Channel == "Whisper" then
			if whisperTarget then
				whisper(whisperTarget, command.Text)
			else
				systemLine("Whisper who? Click a name or type /w name.")
			end
			return
		end
		setSpeaking(command.Channel)
		if command.Channel == "Party" and not partyChannel then
			systemLine("You aren't in a party. Invite someone with /invite name.")
			return
		end
		sendTo(textChannel(channelName(command.Channel)), command.Text, "That channel isn't ready yet.")
	elseif kind == "Switch" then
		setSpeaking(command.Channel)
	elseif kind == "Whisper" then
		local target = findPlayer(command.Target)
		if target then
			whisper({ UserId = target.UserId, Name = target.DisplayName }, command.Text)
		end
	elseif kind == "Reply" then
		if lastWhisperFrom then
			whisper(lastWhisperFrom, command.Text)
		else
			systemLine("Nobody has whispered you yet.")
		end
	elseif kind == "Roll" then
		task.spawn(GemClient.request, "ChatRoll", command.Max)
	elseif kind == "Invite" or kind == "Duel" then
		local target = findPlayer(command.Target)
		if target then
			act(if kind == "Invite" then "PartyInvite" else "DuelChallenge", target.UserId)
		end
	elseif kind == "Trade" then
		local target = command.Target and findPlayer(command.Target)
		if target then
			TradeUI.openWith(target.UserId)
		elseif not command.Target then
			TradeUI.open()
		end
	elseif kind == "Help" then
		for _, help in ChatRules.Help do
			systemLine(help)
		end
	elseif kind == "Who" then
		local names = {}
		for _, p in Players:GetPlayers() do
			table.insert(names, p.DisplayName)
		end
		table.sort(names)
		systemLine(string.format("Miners here (%d): %s", #names, table.concat(names, ", ")))
	elseif kind == "Clear" then
		local keep = {}
		for _, entry in entries do
			if not tabShows(activeTab, entry.Channel) then
				table.insert(keep, entry)
			end
		end
		entries = keep
		redraw()
	elseif kind == "Error" then
		systemLine(command.Message)
	end
end

local function submit()
	local line = input.Text
	input.Text = ""
	run(line)
end
input.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
	lastActivity = os.clock()
end)
sendButton.Activated:Connect(submit)

-- Clicking the channel label cycles through the channels you can speak in.
local CYCLE = { "General", "Trade", "LFG", "Party" }
channelButton.Activated:Connect(function()
	local at = table.find(CYCLE, speaking) or 0
	setSpeaking(CYCLE[at % #CYCLE + 1])
end)

-- Quick LFG posts.
for i, post in ChatRules.LfgPosts do
	local b = new("TextButton", {
		Text = post[1],
		TextSize = 11,
		Font = BOLD,
		TextColor3 = ChatRules.Channels.LFG.Color,
		BackgroundColor3 = Color3.fromRGB(40, 24, 10),
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(72, 22),
		LayoutOrder = i,
		AutoButtonColor = false,
	}, lfgRow)
	UiKit.round(b, 11)
	new("UIStroke", { Color = ChatRules.Channels.LFG.Color, Transparency = 0.5 }, b)
	IronUi.highlight(b)
	b.Activated:Connect(function()
		sendTo(textChannel(channelName("LFG")), post[2], "The LFG channel isn't ready yet.")
	end)
end

-- Pop-ups: the name menu and the item link picker ---------------------------------------

local popup = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(10, 12, 22),
	Size = UDim2.fromOffset(170, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	ZIndex = 20,
}, gui)
UiKit.round(popup, 6)
new("UIStroke", { Color = GOLD, Transparency = 0.3 }, popup)
UiKit.pad(popup, 6)
UiKit.list(popup, 2)

local function closePopup()
	popup.Visible = false
end

local function popupItem(value: string, color: Color3, index: number, callback: (() -> ())?)
	local b = new(if callback then "TextButton" else "TextLabel", {
		Text = value,
		TextSize = 13,
		Font = if callback then BODY else BOLD,
		TextColor3 = color,
		BackgroundColor3 = P.Inset,
		BackgroundTransparency = if callback then 0.4 else 1,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = index,
		ZIndex = 21,
	}, popup)
	UiKit.round(b, 4)
	UiKit.pad(b, 6)
	if callback then
		b.AutoButtonColor = false
		IronUi.highlight(b)
		b.Activated:Connect(function()
			closePopup()
			callback()
		end)
	end
end

local function showPopupAt(position: Vector2)
	local screen = gui.AbsoluteSize
	popup.Visible = true
	task.defer(function()
		local size = popup.AbsoluteSize
		popup.Position = UDim2.fromOffset(
			math.clamp(position.X, 4, math.max(4, screen.X - size.X - 4)),
			math.clamp(position.Y - size.Y, 4, math.max(4, screen.Y - size.Y - 4))
		)
	end)
end

local function clearPopup()
	for _, child in popup:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

openMenu = function(userId: number)
	local other = Players:GetPlayerByUserId(userId)
	if not other then
		systemLine("They've left the server.")
		return
	end
	clearPopup()
	popupItem(other.DisplayName, GOLD, 1)
	popupItem("Whisper", ChatRules.Channels.Whisper.Color, 2, function()
		whisper({ UserId = other.UserId, Name = other.DisplayName }, "")
		input:CaptureFocus()
	end)
	popupItem("Invite to party", ChatRules.Channels.Party.Color, 3, function()
		act("PartyInvite", other.UserId)
	end)
	popupItem("Challenge to a duel", Color3.fromRGB(255, 120, 110), 4, function()
		act("DuelChallenge", other.UserId)
	end)
	popupItem("Trade", ChatRules.Channels.Trade.Color, 5, function()
		TradeUI.openWith(other.UserId)
	end)
	showPopupAt(UserInputService:GetMouseLocation())
end
ChatFrame.openMenu = openMenu

-- Your best gear, to drop an [Item Name] link into the message.
local function linkPicker()
	local profile = GemClient.Profile
	local loadout = profile and profile.Character
	if not loadout or not loadout.Class then
		return
	end
	local items = {}
	for _, slotName in Slots.Order do
		local kind = Slots.Definitions[slotName].Kind
		for id in profile.Owned and profile.Owned[kind] or {} do
			local gear = Classes.gear(loadout.Class, kind, id)
			if gear then
				local roll = GearRolls.get(loadout, slotName, id)
				table.insert(items, { Name = gear.Name, Rarity = if roll then roll.Rarity else 1 })
			end
		end
	end
	table.sort(items, function(a, b)
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		return a.Name < b.Name
	end)
	clearPopup()
	popupItem("LINK AN ITEM", GOLD, 0)
	for i = 1, math.min(#items, 8) do
		local item = items[i]
		local rarity = GearRolls.Rarities[item.Rarity] or GearRolls.Rarities[1]
		popupItem("[" .. item.Name .. "]", rarity.Color, i, function()
			input.Text = input.Text
				.. (if input.Text == "" or string.sub(input.Text, -1) == " " then "" else " ")
				.. "["
				.. item.Name
				.. "] "
			input:CaptureFocus()
			input.CursorPosition = #input.Text + 1
		end)
	end
	if #items == 0 then
		popupItem("No gear to link yet.", P.Dim, 1)
	end
	local at = linkButton.AbsolutePosition
	showPopupAt(Vector2.new(at.X - 150, at.Y - 4))
end
linkButton.Activated:Connect(linkPicker)

UserInputService.InputBegan:Connect(function(inputObject, processed)
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and popup.Visible then
		local at = inputObject.Position
		local p0, size = popup.AbsolutePosition, popup.AbsoluteSize
		if at.X < p0.X or at.Y < p0.Y or at.X > p0.X + size.X or at.Y > p0.Y + size.Y then
			task.defer(closePopup)
		end
	end
	if processed or not gui.Enabled or UserInputService:GetFocusedTextBox() then
		return
	end
	-- Enter opens the chat box; "/" opens it ready for a command.
	if inputObject.KeyCode == Enum.KeyCode.Return then
		if collapsed then
			ChatFrame.setCollapsed(false)
		end
		input:CaptureFocus()
	elseif inputObject.KeyCode == Enum.KeyCode.Slash then
		if collapsed then
			ChatFrame.setCollapsed(false)
		end
		input:CaptureFocus()
		task.defer(function()
			input.Text = "/"
			input.CursorPosition = 2
		end)
	end
end)

-- Incoming -------------------------------------------------------------------------------

local function nameTag(userId: number?, name: string): string
	local color = if userId == player.UserId then "#9BE7B7" else "#FFFFFF"
	return '<b><font color="' .. color .. '">[' .. escape(name) .. "]</font></b>"
end

TextChatService.MessageReceived:Connect(function(message)
	local channel = message.TextChannel
	local name = channel and channel.Name or ""
	local source = message.TextSource
	local fromId = source and source.UserId
	local speaker = fromId and Players:GetPlayerByUserId(fromId)
	local who = if speaker then speaker.DisplayName elseif source then source.Name else "?"
	local body = linkify(escape(message.Text))
	if name == "RBXSystem" then
		push("System", body)
		return
	end
	local whisperA, whisperB = string.match(name, "^Whisper_(%d+)_(%d+)$")
	if whisperA then
		local a, b = tonumber(whisperA), tonumber(whisperB)
		local partnerId = if a == player.UserId then b else a
		local partner = Players:GetPlayerByUserId(partnerId)
		local partnerName = if partner then partner.DisplayName else "?"
		whisperChannels[partnerId] = name
		if fromId == player.UserId then
			push("Whisper", "To " .. nameTag(partnerId, partnerName) .. ": " .. body, partnerId)
		else
			lastWhisperFrom = { UserId = partnerId, Name = partnerName }
			push("Whisper", nameTag(fromId, who) .. " whispers: " .. body, fromId)
		end
		return
	end
	local id = if name == "RBXGeneral"
		then "General"
		elseif name == ChatRules.TextChannels.Trade then "Trade"
		elseif name == ChatRules.TextChannels.LFG then "LFG"
		elseif partyChannel and name == partyChannel then "Party"
		else nil
	if not id then
		return
	end
	push(id, "[" .. channelOf(id).Label .. "] " .. nameTag(fromId, who) .. ": " .. body, fromId)
end)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Party").OnClientEvent:Connect(function(kind: string, a: any)
	if kind == "State" then
		local before = partyChannel
		partyChannel = a and a.Channel or nil
		if partyChannel and not before then
			systemLine("You joined a party. Type /p to talk to it.")
		elseif before and not partyChannel then
			systemLine("You left the party.")
			if speaking == "Party" then
				setSpeaking("General")
			end
		end
	end
end)
remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "Chat" and typeof(a) == "string" and typeof(b) == "string" then
		push(if ChatRules.Channels[a] then a else "System", linkify(escape(b)))
	elseif kind == "Feed" and typeof(a) == "string" then
		systemLine(a)
	end
end)
Players.PlayerAdded:Connect(function(other)
	systemLine(other.DisplayName .. " joined the server.")
end)
Players.PlayerRemoving:Connect(function(other)
	systemLine(other.DisplayName .. " left the server.")
	whisperChannels[other.UserId] = nil
end)

-- Where it shows -------------------------------------------------------------------------

-- On the dashboard and at the Outpost; elsewhere (arenas, dungeons) Roblox's
-- own chat window takes over, so chat is never lost.
-- Returns whether to show, and whether it's over the dashboard (busy screen)
-- rather than the 3D world.
local function wanted(): (boolean, boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui or playerGui:FindFirstChild("Intro") then
		return false, false
	end
	local dashboard = playerGui:FindFirstChild("Dashboard")
	local onDashboard = dashboard ~= nil and dashboard:IsA("ScreenGui") and dashboard.Enabled
	return onDashboard or player:GetAttribute("Outpost") == true, onDashboard
end

local function setDefaultChat(on: boolean)
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = on
		TextChatService.ChatInputBarConfiguration.Enabled = on
	end)
end

function ChatFrame.refresh()
	local show, onDashboard = wanted()
	if show ~= gui.Enabled then
		gui.Enabled = show
		setDefaultChat(not show)
		if not show then
			closePopup()
			input:ReleaseFocus()
		end
	end
	-- The background stays faint until you hover or chat, like the classic frame.
	if gui.Enabled then
		pcall(function()
			local inset = if gui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
			local mouse = UserInputService:GetMouseLocation() - inset
			local at, size = frame.AbsolutePosition, frame.AbsoluteSize
			if mouse.X >= at.X and mouse.Y >= at.Y and mouse.X <= at.X + size.X and mouse.Y <= at.Y + size.Y then
				lastActivity = os.clock()
			end
		end)
	end
	local active = os.clock() - lastActivity < IDLE_FADE or input:IsFocused()
	-- Over the busy dashboard it folds down to its tabs when idle and reads as
	-- a solid panel when open; in the world it stays open and see-through.
	if onDashboard and not active and not collapsed then
		ChatFrame.setCollapsed(true)
		autoCollapsed = true
	elseif not onDashboard and autoCollapsed then
		autoCollapsed = false
		ChatFrame.setCollapsed(false)
	end
	if onDashboard then
		frame.BackgroundTransparency = if active then 0.06 else 0.15
		frameStroke.Transparency = if active then 0.3 else 0.5
	else
		frame.BackgroundTransparency = if active then 0.35 else 0.7
		frameStroke.Transparency = if active then 0.45 else 0.85
	end
end

setSpeaking("General")
drawTabs()
redraw()
task.spawn(function()
	while true do
		-- One bad frame shouldn't stop the chat box from following the screens.
		pcall(ChatFrame.refresh)
		task.wait(0.25)
	end
end)

return ChatFrame
