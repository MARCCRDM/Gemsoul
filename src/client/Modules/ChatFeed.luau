--[[
	The chat, windowless: the server's lines stacking up from the bottom left
	corner, like a standard game's, with no box, no tabs and no background
	(the old MMO chat box, ChatFrame, is off for now: Config.Features.ChatBox).
	Each line stays a while and fades; press / (or click "Press / to chat")
	and the recent lines come back with a line to type in. Enter sends to
	everyone in the server (Roblox's General channel, so it's filtered);
	Escape or an empty line puts it away. Loot and system lines (ChatFrame's
	loot and system) come here too.

	Shown on a computer in the Outpost, over the world, above your kaiju's
	card and its TAME button (KaijuHud) and clear of the lobby's PLAY stack.
	On phones and tablets, and in fights and dungeons, Roblox's own chat
	takes over (its window and the top bar's chat button), as before.

	  ChatFeed.system(text)   a grey line (ChatFrame.system forwards here)
	  ChatFeed.loot(text)     a gold line (ChatFrame.loot forwards here)
	  ChatFeed.Shown()        is it up now
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

local ChatFeed = {}
local player = Players.LocalPlayer
local new = IronUi.new

-- On, while the MMO chat box is off.
ChatFeed.Enabled = not (Config.Features and Config.Features.ChatBox == true)
local handheld = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local WIDTH = 420
local LEFT = 24
-- Its bottom sits above the kaiju card (24 up: KaijuHud's computer layout,
-- MobileLayout.kaijuDesk), its team, buttons and HYPERBEAM.
local BOTTOM = 24 + MobileLayout.kaijuDesk(Vector2.zero).H + 12
-- Its top stays under the lobby's PLAY stack (LobbyUI: from 54 down, 272
-- tall on a computer).
local STACK_BOTTOM = 340
local MAX_HEIGHT = 230
local SHOWN = 10 -- lines on screen
local KEEP = 60 -- lines remembered
local LINGER = 22 -- seconds a line stays before it fades
local FADE = 1.2

local WHITE = Color3.fromRGB(240, 244, 250)
local GREY = Color3.fromRGB(170, 182, 198)
local GOLD = Color3.fromRGB(255, 205, 90)
-- Name colours, picked by name like Roblox's.
local NAME_COLORS = {
	Color3.fromRGB(253, 41, 67),
	Color3.fromRGB(1, 162, 255),
	Color3.fromRGB(2, 184, 87),
	Color3.fromRGB(170, 85, 255),
	Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(110, 230, 230),
}

local function escape(value: string): string
	return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end
-- Rich-text tags stripped, entities decoded (Roblox's own system lines come marked up).
local function plain(value: string): string
	local stripped = string.gsub(value, "<[^<>]->", "")
	stripped = string.gsub(stripped, "&lt;", "<")
	stripped = string.gsub(stripped, "&gt;", ">")
	stripped = string.gsub(stripped, "&quot;", '"')
	stripped = string.gsub(stripped, "&apos;", "'")
	stripped = string.gsub(stripped, "&amp;", "&")
	return (string.match(stripped, "^%s*(.-)%s*$"))
end
function ChatFeed.nameColor(name: string): Color3
	local sum = 0
	for i = 1, #name do
		sum += string.byte(name, i) * i
	end
	return NAME_COLORS[sum % #NAME_COLORS + 1]
end

-- The screen ---------------------------------------------------------------------------------------------

local gui = UiKit.gui("ChatFeed", 5)
gui.IgnoreGuiInset = false
gui.Enabled = false
local holder = new("Frame", {
	Name = "Feed",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, LEFT, 1, -BOTTOM),
	Size = UDim2.fromOffset(WIDTH, MAX_HEIGHT),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, gui)
local lines = new("Frame", {
	Name = "Lines",
	Size = UDim2.new(1, 0, 1, -24),
	BackgroundTransparency = 1,
}, holder)
lines:SetAttribute("NoTranslate", true) -- (players' words stay as they wrote them)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 2),
}, lines)
-- The line you type in (only while you're typing), or the hint to press /.
local input = new("TextBox", {
	Name = "Input",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundColor3 = Color3.fromRGB(8, 10, 16),
	BackgroundTransparency = 0.45,
	ClearTextOnFocus = false,
	Font = IronUi.Bold,
	TextSize = 14,
	TextColor3 = WHITE,
	PlaceholderText = "Say something…",
	PlaceholderColor3 = GREY,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Visible = false,
}, holder)
UiKit.round(input, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, input)
local hint = new("TextButton", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromOffset(180, 18), -- (room for the Spanish)
	BackgroundTransparency = 1,
	Font = IronUi.Bold,
	TextSize = 12,
	TextColor3 = GREY,
	TextTransparency = 0.35,
	TextStrokeTransparency = 0.6,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Press / to chat",
}, holder)

-- Lines ----------------------------------------------------------------------------------------------------

type Line = { Label: TextLabel, At: number }
local feed: { Line } = {}
local order = 0
local typing = false

local function add(markup: string)
	order += 1
	local label = new("TextLabel", {
		Name = "Line",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = IronUi.Bold,
		TextSize = 15,
		TextColor3 = WHITE,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Text = markup,
	}, lines)
	table.insert(feed, { Label = label, At = os.clock() })
	while #feed > KEEP do
		table.remove(feed, 1).Label:Destroy()
	end
end

-- (The lines skip the screen translator, so the game's own words are
-- translated here.)
function ChatFeed.system(text: string)
	add(string.format('<font color="%s"><i>%s</i></font>', hex(GREY), escape(Lang.translate(text))))
end
function ChatFeed.loot(text: string)
	add(string.format('<font color="%s">%s</font>', hex(GOLD), escape(text)))
end

-- What a line shows now: fresh ones in full, then fading; all of the recent
-- ones while you type.
local function paint()
	local now = os.clock()
	local first = math.max(1, #feed - SHOWN + 1)
	for i, line in feed do
		local shown = i >= first
		local alpha = 0
		if not typing then
			local age = now - line.At
			alpha = math.clamp((age - LINGER) / FADE, 0, 1)
		end
		line.Label.Visible = shown and alpha < 1
		line.Label.TextTransparency = alpha
		line.Label.TextStrokeTransparency = 0.35 + alpha * 0.65
	end
end

-- Sending -----------------------------------------------------------------------------------------------------

local function general(): TextChannel?
	local channels = TextChatService:FindFirstChild("TextChannels")
	local found = channels and channels:FindFirstChild("RBXGeneral")
	return if found and found:IsA("TextChannel") then found else nil
end

local function open()
	if typing or not gui.Enabled then
		return
	end
	typing = true
	input.Visible, hint.Visible = true, false
	input.Text = ""
	input:CaptureFocus()
	paint()
end

local function close()
	typing = false
	input.Visible, hint.Visible = false, true
	-- (Lines you just saw again linger a moment longer.)
	local now = os.clock()
	for _, line in feed do
		line.At = math.max(line.At, now - LINGER + 4)
	end
	paint()
end

input.FocusLost:Connect(function(enter: boolean)
	local text = string.match(input.Text, "^%s*(.-)%s*$") or ""
	input.Text = ""
	close()
	if not enter or text == "" then
		return
	end
	local channel = general()
	if not channel then
		ChatFeed.system("Chat isn't ready yet.")
		return
	end
	task.spawn(function()
		if not pcall(channel.SendAsync, channel, text) then
			ChatFeed.system("Couldn't send that message.")
		end
	end)
end)
hint.Activated:Connect(open)
UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
	if processed or not gui.Enabled then
		return
	end
	if io.KeyCode == Enum.KeyCode.Slash then
		-- (After this frame, so the / isn't typed in.)
		task.defer(open)
	end
end)

-- Receiving ---------------------------------------------------------------------------------------------------

TextChatService.MessageReceived:Connect(function(message)
	local channel = message.TextChannel
	local name = channel and channel.Name or ""
	local source = message.TextSource
	if name == "RBXSystem" or not source then
		local words = plain(message.Text or "")
		if words ~= "" then
			ChatFeed.system(words)
		end
		return
	end
	if name ~= "RBXGeneral" then
		return -- (the server's chat: not trade, party or whispers)
	end
	local speaker = Players:GetPlayerByUserId(source.UserId)
	local who = if speaker then speaker.DisplayName else source.Name
	local color = if source.UserId == player.UserId then Color3.fromRGB(155, 231, 183) else ChatFeed.nameColor(who)
	local said = escape(message.Text or "")
	add(string.format('<b><font color="%s">%s:</font></b> %s', hex(color), escape(who), said))
end)

-- Where it shows ----------------------------------------------------------------------------------------------

local function wanted(): (boolean, boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not ChatFeed.Enabled or handheld or not playerGui or playerGui:FindFirstChild("Intro") then
		return false, false
	end
	local dashboard = playerGui:FindFirstChild("Dashboard")
	local menu = dashboard ~= nil and dashboard:IsA("ScreenGui") and dashboard.Enabled
	local inOutpost = player:GetAttribute("Outpost") == true
	return inOutpost and not menu, menu
end

-- Roblox's own chat window: off while the feed is up (or a menu's over the
-- world), on everywhere else so chat is never lost.
local defaultOn: boolean? = nil
local function setDefaultChat(on: boolean)
	if defaultOn == on then
		return
	end
	defaultOn = on
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = on
		TextChatService.ChatInputBarConfiguration.Enabled = on
	end)
end

-- A computer: above the kaiju card, under the PLAY stack. A short screen
-- with a keyboard (the kaiju card is up under the coins there): the bottom
-- left corner, left of the lobby's dock.
local function fit()
	local size = gui.AbsoluteSize
	if size.Y <= 0 then
		return
	end
	if UiKit.short() then
		local dock = MobileLayout.dock(size, 5)
		local width = math.clamp(dock.X - LEFT - 12, 180, WIDTH)
		holder.Position = UDim2.new(0, 12, 1, -12)
		holder.Size = UDim2.fromOffset(width, math.floor(size.Y * 0.4))
		return
	end
	holder.Position = UDim2.new(0, LEFT, 1, -BOTTOM)
	holder.Size = UDim2.fromOffset(WIDTH, math.clamp(size.Y - BOTTOM - STACK_BOTTOM, 70, MAX_HEIGHT))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

function ChatFeed.Shown(): boolean
	return gui.Enabled
end

local function refresh()
	local show, menu = wanted()
	if gui.Enabled ~= show then
		gui.Enabled = show
		fit()
		if not show and typing then
			input:ReleaseFocus()
			close()
		end
	end
	if ChatFeed.Enabled then
		setDefaultChat(not show and not menu)
	end
	if show then
		paint()
	end
end

-- Speech bubbles over heads, for everyone.
pcall(function()
	TextChatService.BubbleChatConfiguration.Enabled = true
end)
task.spawn(function()
	while true do
		pcall(refresh)
		task.wait(0.25)
	end
end)

return ChatFeed
