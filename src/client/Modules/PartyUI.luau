--[[
	Parties [P]. The window shows your party's four slots (leader crown,
	class, ready tick) and everyone else in the server with an Invite button.
	At the bottom: Ready, Leave, and, for the leader, a rally point
	(Wilds, Arena, Quarry, Crafting Hall, Market) that draws a trail for
	every member.

	Out in the world: an invite popup (Accept / Decline), teammates' health
	at the top right, and a marker over each teammate's head.
	Party members share monster rewards when they fight nearby.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, button, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 900, 560
local MAX = 4
local RALLIES = {
	{ "Wilds", "Crystal Wilds" },
	{ "Arena", "Arena" },
	{ "Quarry", "Quarry" },
	{ "Quartermaster", "Crafting Hall" },
	{ "Market", "Market" },
}
local TEAL = Color3.fromRGB(60, 220, 190)

local PartyUI = {}

local state: { [string]: any }? = nil
local busy = false

local function run(action: string, ...: any)
	if busy then
		return
	end
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		busy = false
		PartyUI.refresh()
	end)
end

local function isLeader(): boolean
	return state ~= nil and state.Leader == player.UserId
end

local function myEntry()
	for _, member in (state and state.Members or {}) do
		if member.UserId == player.UserId then
			return member
		end
	end
	return nil
end

-- Window -----------------------------------------------------------------------------------------------

local window = IronUi.window("Party", 10, WIDTH, HEIGHT, "👥")
local gui, panel = window.Gui, window.Panel
window.Title.Text = "PARTY"
window.Subtitle.Text = "Up to 4. Fight together nearby and everyone gets the rewards."

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 80),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 104),
}, panel)

local function slotRow(parent: Instance, order: number, member)
	local row = box(parent, UDim2.new(), UDim2.new(1, 0, 0, 56), if member then P.Slot else P.Inset, 12)
	row.LayoutOrder = order
	local dot = IronUi.badge(
		row,
		if member then (if state and member.UserId == state.Leader then "👑" else "⚔️") else "+",
		36,
		if member then member.Color else Color3.fromRGB(60, 200, 110)
	)
	dot.Position = UDim2.fromOffset(10, 10)
	local name = text(row, if member then member.Name else "Invite a friend", 15, P.Text, BOLD)
	name.Position = UDim2.fromOffset(58, 8)
	name.Size = UDim2.new(1, -220, 0, 18)
	local sub = text(row, if member then member.Class else string.format("Empty slot %d", order), 12, P.Dim)
	sub.Position = UDim2.fromOffset(58, 30)
	sub.Size = UDim2.new(1, -220, 0, 16)
	if member then
		local ready =
			text(row, if member.Ready then "✓ READY" else "…", 13, if member.Ready then P.Good else P.Dim, BOLD)
		ready.AnchorPoint = Vector2.new(1, 0)
		ready.Position = UDim2.new(1, -90, 0, 18)
		ready.Size = UDim2.fromOffset(90, 20)
		ready.TextXAlignment = Enum.TextXAlignment.Right
		if isLeader() and member.UserId ~= player.UserId then
			local kick = button(row, "Kick", false, function()
				run("PartyKick", member.UserId)
			end)
			kick.AnchorPoint = Vector2.new(1, 0.5)
			kick.Position = UDim2.new(1, -10, 0.5, 0)
		end
	end
end

function PartyUI.refresh()
	if not gui.Enabled then
		return
	end
	clear(body)
	-- Left: the party card.
	local card = box(body, UDim2.new(), UDim2.new(0.56, 0, 1, -54), Color3.fromRGB(24, 32, 34), 14)
	UiKit.pad(card, 12)
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24) }, card)
	text(header, "👥  Party", 16, P.Text, BOLD).Size = UDim2.new(0.5, 0, 1, 0)
	local readyCount, count = 0, 0
	for _, member in (state and state.Members or {}) do
		count += 1
		if member.Ready then
			readyCount += 1
		end
	end
	local counter =
		text(header, string.format("✓ %d ready  •  %d/%d", readyCount, math.max(count, 1), MAX), 12, P.Good, BOLD)
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.fromScale(1, 0)
	counter.Size = UDim2.new(0.5, 0, 1, 0)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local slots = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
	}, card)
	UiKit.list(slots, 8)
	local members = if state
		then state.Members
		else { { UserId = player.UserId, Name = player.DisplayName, Class = "You", Color = P.Gold, Ready = false } }
	for i = 1, MAX do
		slotRow(slots, i, members[i])
	end

	-- Right: everyone else in the server.
	local list = box(body, UDim2.new(0.56, 14, 0, 0), UDim2.new(0.44, -14, 1, -54), P.Inset, 14)
	UiKit.pad(list, 12)
	UiKit.list(list, 6)
	text(list, "IN THIS SERVER", 13, P.Gold, BOLD)
	local inParty = {}
	for _, member in (state and state.Members or {}) do
		inParty[member.UserId] = true
	end
	local others = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and not inParty[other.UserId] then
			others += 1
			local row = new(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = others + 1 },
				list
			)
			local name = text(row, other.DisplayName, 14, P.Text, BOLD)
			name.Size = UDim2.new(1, -100, 1, 0)
			name.AutomaticSize = Enum.AutomaticSize.None
			name.TextYAlignment = Enum.TextYAlignment.Center
			if not state or isLeader() then
				local invite = button(row, "+ Invite", true, function()
					run("PartyInvite", other.UserId)
				end)
				invite.AnchorPoint = Vector2.new(1, 0.5)
				invite.Position = UDim2.new(1, 0, 0.5, 0)
			end
		end
	end
	if others == 0 then
		text(list, "No one else is here yet. Invite friends to your game on Roblox, then invite them here.", 12, P.Dim)
	end

	-- Bottom: ready, leave, rally.
	local actions = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
	}, body)
	UiKit.list(actions, 8, true)
	if state then
		local me = myEntry()
		local ready = me and me.Ready
		button(actions, if ready then "Not ready" else "✓ Ready", not ready, function()
			run("PartyReady", not ready)
		end)
		button(actions, "Leave", false, function()
			run("PartyLeave")
		end)
		if isLeader() then
			text(actions, "   RALLY:", 13, P.Gold, BOLD).AutomaticSize = Enum.AutomaticSize.XY
			for _, rally in RALLIES do
				local b = button(actions, rally[2], state.Rally == rally[1], function()
					run("PartyRally", if state and state.Rally == rally[1] then nil else rally[1])
				end)
				b.TextSize = 12
			end
		elseif state.Rally then
			text(actions, "   Rally point: " .. state.Rally, 13, TEAL, BOLD).AutomaticSize = Enum.AutomaticSize.XY
		end
	else
		text(actions, "Invite someone from the list to start a party.", 13, P.Dim).AutomaticSize = Enum.AutomaticSize.XY
	end
end

function PartyUI.open()
	gui.Enabled = true
	window.Fit()
	PartyUI.refresh()
end

function PartyUI.close()
	gui.Enabled = false
	clear(body)
end

function PartyUI.toggle()
	if gui.Enabled then
		PartyUI.close()
	else
		PartyUI.open()
	end
end

window.Close.Activated:Connect(PartyUI.close)
window.Shade.Activated:Connect(PartyUI.close)
Players.PlayerAdded:Connect(PartyUI.refresh)
Players.PlayerRemoving:Connect(function()
	task.defer(PartyUI.refresh)
end)

-- Invite popup -------------------------------------------------------------------------------------------

local popupGui = UiKit.gui("PartyInvite", 14)
local popup = IronUi.box(popupGui, UDim2.new(0.5, -180, 0, 90), UDim2.fromOffset(360, 110), P.Frame, 14)
popup.Visible = false
UiKit.pad(popup, 12)
local popupText = text(popup, "", 15, P.Text, BOLD)
local popupButtons = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
}, popup)
UiKit.list(popupButtons, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
local popupFrom: number? = nil

local function answer(accept: boolean)
	popup.Visible = false
	if popupFrom then
		run("PartyRespond", popupFrom, accept)
	end
	popupFrom = nil
end
button(popupButtons, "✓ Accept", true, function()
	answer(true)
end)
button(popupButtons, "Decline", false, function()
	answer(false)
end)

-- Teammates on the HUD, markers and the rally trail -------------------------------------------------------

local hudGui = UiKit.gui("PartyHud", 2)
local hudList = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 132),
	Size = UDim2.fromOffset(220, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, hudGui)
UiKit.list(hudList, 6)
local hudBars: { [number]: Frame } = {}

local markers: { [number]: BillboardGui } = {}

local rallyMarker = Instance.new("Part")
rallyMarker.Name = "RallyMarker"
rallyMarker.Anchored = true
rallyMarker.CanCollide = false
rallyMarker.CanQuery = false
rallyMarker.CanTouch = false
rallyMarker.Transparency = 1
rallyMarker.Size = Vector3.one
local rallyAttachment = Instance.new("Attachment")
rallyAttachment.Parent = rallyMarker
local rallyBeam = Instance.new("Beam")
rallyBeam.Attachment1 = rallyAttachment
rallyBeam.Color = ColorSequence.new(TEAL)
rallyBeam.Transparency = NumberSequence.new(0.3, 0.8)
rallyBeam.Width0, rallyBeam.Width1 = 0.4, 0.4
rallyBeam.FaceCamera = true
rallyBeam.LightEmission = 1
rallyBeam.Segments = 20
rallyBeam.CurveSize0, rallyBeam.CurveSize1 = 3, -3
rallyBeam.Enabled = false

local function landmark(name: string): Vector3?
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local position = landmarks and landmarks:GetAttribute(name)
	return if typeof(position) == "Vector3" then position else nil
end

local function rebuildHud()
	clear(hudList)
	table.clear(hudBars)
	for userId, marker in markers do
		marker:Destroy()
		markers[userId] = nil
	end
	if not state then
		rallyBeam.Enabled = false
		return
	end
	for _, member in state.Members do
		if member.UserId ~= player.UserId then
			local row = box(hudList, UDim2.new(), UDim2.new(1, 0, 0, 40), P.Frame, 10)
			UiKit.pad(row, 6)
			local name = text(
				row,
				(if member.UserId == state.Leader then "👑 " else "") .. member.Name,
				12,
				member.Color,
				BOLD
			)
			name.Size = UDim2.new(1, 0, 0, 14)
			local back = new("Frame", {
				BackgroundColor3 = Color3.fromRGB(40, 30, 30),
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 8),
			}, row)
			UiKit.round(back, 4)
			local fill =
				new("Frame", { BackgroundColor3 = Color3.fromRGB(200, 60, 60), Size = UDim2.fromScale(1, 1) }, back)
			UiKit.round(fill, 4)
			hudBars[member.UserId] = fill
		end
	end
	local spot = state.Rally and landmark(state.Rally)
	if spot then
		rallyMarker.Position = spot + Vector3.new(0, 3, 0)
		rallyMarker.Parent = workspace
	end
	rallyBeam.Enabled = spot ~= nil
end

local function attachBeam(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "RallyAttachment"
		attachment.Position = Vector3.new(0, -1, 0)
		attachment.Parent = root
		rallyBeam.Attachment0 = attachment
		rallyBeam.Parent = root
	end
end
if player.Character then
	task.spawn(attachBeam, player.Character)
end
player.CharacterAdded:Connect(attachBeam)

local timer = 0
RunService.Heartbeat:Connect(function(dt)
	timer += dt
	if timer < 0.25 or not state then
		return
	end
	timer = 0
	for _, member in state.Members do
		local other = Players:GetPlayerByUserId(member.UserId)
		local character = other and other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local fill = hudBars[member.UserId]
		if fill and humanoid then
			fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
		end
		-- A marker over each teammate's head.
		local head = character and character:FindFirstChild("Head")
		if
			other
			and other ~= player
			and head
			and (not markers[member.UserId] or markers[member.UserId].Parent ~= head)
		then
			if markers[member.UserId] then
				markers[member.UserId]:Destroy()
			end
			local board = new("BillboardGui", {
				Size = UDim2.fromOffset(140, 24),
				StudsOffset = Vector3.new(0, 3.2, 0),
				AlwaysOnTop = true,
				MaxDistance = 400,
			}, head)
			new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "◆ " .. member.Name,
				Font = BOLD,
				TextSize = 14,
				TextColor3 = TEAL,
				TextStrokeTransparency = 0.3,
			}, board)
			markers[member.UserId] = board
		end
	end
	-- Hide the trail once you've reached the rally point.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and state.Rally and rallyMarker.Parent then
		rallyBeam.Enabled = (rallyMarker.Position - root.Position).Magnitude > 20
	end
end)

-- Server events ---------------------------------------------------------------------------------------------

local partyEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Party") :: RemoteEvent
partyEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "State" then
		state = a
		rebuildHud()
		PartyUI.refresh()
	elseif kind == "Invite" then
		popupFrom = a
		popupText.Text = string.format("👥  %s invited you to their party.", tostring(b))
		popup.Visible = true
		task.delay(60, function()
			if popupFrom == a then
				popup.Visible = false
				popupFrom = nil
			end
		end)
	end
end)

return PartyUI
