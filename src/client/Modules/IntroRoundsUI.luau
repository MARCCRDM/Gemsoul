--[[
	The intro rounds' card (Shared.IntroRounds, Server.IntroRoundsServer):
	between rounds, over the Arena.

	  ROUND 2 OF 6 WON             the piece rolling in: a reel of rarities
	  Cryo-Edge Saber  · RARE      landing on yours, its name in its rarity's
	  SWORD  ·  EQUIPPED           colour, on you already
	  [■ ■ □ □ □ □]                the set: each slot lit as it's won
	  NEXT: SABLE, THE SHADOW      who's next, and what beating them pays
	  [ NEXT ROUND  10 ]  LEAVE    starts by itself after AutoNext seconds
	                               (in the Arena; from anywhere else, it waits)

	A loss: KNOCKED DOWN, the next try is easier, TRY AGAIN / LEAVE. The whole
	set: SET COMPLETE, the coins, TO THE OUTPOST.

	  IntroRoundsUI.start()   once (Lobby.client)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local Lang = require(ReplicatedStorage.Shared.Lang)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

local IntroRoundsUI = {}

local P = IronUi.Colors
local new = IronUi.new
local player = Players.LocalPlayer
IntroRoundsUI.AutoNext = 10 -- seconds before NEXT ROUND starts by itself (in the Arena)

local PANEL = Color3.fromRGB(14, 19, 34)
local PANEL_LOW = Color3.fromRGB(7, 9, 19)
local RED = Color3.fromRGB(240, 96, 88)

local function rarityColor(name: string?): Color3
	for _, rarity in GearRolls.Rarities do
		if rarity.Name == name then
			return rarity.Color
		end
	end
	return P.Dim
end

local gui: ScreenGui
local card: Frame
local scale: UIScale
local header: TextLabel
local pieceName: TextLabel
local pieceLine: TextLabel
local extra: TextLabel
local slotsRow: Frame
local nextLine: TextLabel
local goButton: TextButton
local leaveButton: TextButton
local shown = 0 -- (each show's number: an older countdown stops)
local current = nil -- the event on the card
local busy = false

local function label(parent, font, size, color, y, h)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, h),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	return l
end

local function build()
	gui = UiKit.gui("IntroRounds", 32)
	gui.Enabled = false
	card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 330),
		BackgroundColor3 = PANEL,
	}, gui)
	UiKit.round(card, 14)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(PANEL, PANEL_LOW) }, card)
	new("UIStroke", { Color = P.Gold, Thickness = 2, Transparency = 0.15 }, card)
	scale = new("UIScale", { Scale = 1 }, card)
	header = label(IronUi.Heading, 20, P.Gold, 16, 24)
	pieceName = label(IronUi.Heading, 24, P.Text, 52, 30)
	pieceName:SetAttribute("NoTranslate", true)
	pieceLine = label(IronUi.Bold, 13, P.Dim, 84, 18)
	extra = label(IronUi.Bold, 13, P.Teal, 104, 18)
	slotsRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 132), Size = UDim2.new(1, -32, 0, 52) }, card)
	local list = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, slotsRow)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	nextLine = label(IronUi.Bold, 14, P.Text, 196, 40)
	nextLine.TextWrapped = true
	nextLine.TextTruncate = Enum.TextTruncate.None
	goButton = new("TextButton", {
		Name = "Next",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, -70, 0, 252),
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = P.Gold,
		Font = IronUi.Heading,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = true,
	}, card)
	UiKit.round(goButton, 10)
	goButton:SetAttribute("UiSound", "Confirm")
	IronUi.juice(goButton)
	pcall(IronUi.shine, goButton, 3)
	leaveButton = new("TextButton", {
		Name = "Leave",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 130, 0, 252),
		Size = UDim2.fromOffset(140, 48),
		BackgroundColor3 = Color3.fromRGB(32, 38, 58),
		Font = IronUi.Heading,
		TextSize = 14,
		TextColor3 = P.Dim,
		AutoButtonColor = true,
	}, card)
	UiKit.round(leaveButton, 10)
	new("UIStroke", { Color = P.Edge, Thickness = 1 }, leaveButton)
	-- A phone: the card shrunk to the screen.
	local function fit()
		local screen = gui.AbsoluteSize
		if screen.Y > 0 then
			local s = math.min(1, (screen.Y - 24) / 330, (screen.X - 24) / 440)
			scale:SetAttribute("Fit", s)
			scale.Scale = s
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

local function fitScale(): number
	return scale:GetAttribute("Fit") or 1
end

local function hide()
	shown += 1
	gui.Enabled = false
	current = nil
end

-- The set: one tile a slot, lit in its piece's rarity once won.
local function drawSlots(view)
	for _, child in slotsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, slot in view.Slots do
		local won = slot.Piece ~= nil
		local color = if won then rarityColor(slot.Piece.Rarity) else Color3.fromRGB(40, 47, 70)
		local tile = new("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(62, 52),
			BackgroundColor3 = if won then color:Lerp(PANEL, 0.55) else Color3.fromRGB(20, 25, 41),
		}, slotsRow)
		UiKit.round(tile, 8)
		new("UIStroke", { Color = color, Thickness = if won then 2 else 1, Transparency = if won then 0 else 0.3 }, tile)
		local name = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 8),
			Font = IronUi.Heading,
			TextSize = 10,
			TextColor3 = if won then P.Text else P.Dim,
			Text = Lang.translate(slot.Name),
		}, tile)
		name.TextScaled = false
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 28),
			Font = IronUi.Heading,
			TextSize = 13,
			TextColor3 = if won then color else P.Dim,
			Text = if won then "✓" else tostring(i),
		}, tile)
	end
end

-- The piece's rarity rolling in: a quick reel of rarities, slowing, then its own.
local function reel(piece, mine: number)
	local names = { "COMMON", "UNCOMMON", "RARE", "UNCOMMON", "ULTRA RARE", "UNCOMMON", "RARE" }
	local steps = 14
	for i = 1, steps do
		if mine ~= shown then
			return
		end
		local pick = names[(i % #names) + 1]
		pieceName.Text = pick
		pieceName.TextColor3 = rarityColor(if pick == "ULTRA RARE" then "Ultra Rare" else string.sub(pick, 1, 1) .. string.lower(string.sub(pick, 2)))
		UiSound.play("Tab")
		task.wait(0.04 + i * 0.012)
	end
	if mine ~= shown then
		return
	end
	local color = rarityColor(piece.Rarity)
	pieceName.Text = piece.Name
	pieceName.TextColor3 = color
	pieceLine.Text = Lang.translate(string.format("%s  ·  %s  ·  EQUIPPED", string.upper(piece.Rarity), IntroRounds.SlotNames[piece.Slot] or piece.Slot))
	pieceLine.TextColor3 = color:Lerp(P.Text, 0.3)
	UiSound.play(if piece.Rarity == "Rare" then "Reward" else "Equip")
	scale.Scale = fitScale() * 1.06
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fitScale() }):Play()
end

local function inArena(): boolean
	return player:GetAttribute("CombatSession") == "Training"
end

-- NEXT ROUND counts down by itself in the Arena (nothing to wait for there).
local function countdown(base: string, mine: number)
	goButton.Text = Lang.translate(base)
	if not inArena() then
		return
	end
	for left = IntroRoundsUI.AutoNext, 1, -1 do
		if mine ~= shown then
			return
		end
		goButton.Text = Lang.translate(base) .. "  " .. left
		task.wait(1)
	end
	if mine == shown and gui.Enabled then
		goButton:SetAttribute("Auto", true)
		IntroRoundsUI.next()
	end
end

function IntroRoundsUI.next()
	if busy or not current then
		return
	end
	if current.View and current.View.Done then
		busy = true
		hide()
		task.spawn(function()
			GemClient.request("IntroRoundLeave")
			busy = false
		end)
		return
	end
	busy = true
	local mine = shown
	goButton.Text = Lang.translate("…")
	task.spawn(function()
		local result = GemClient.request("IntroRoundNext")
		busy = false
		if result and result.Ok then
			if mine == shown then
				hide()
			end
			if result.Real then
				UiKit.toast(Lang.translate(result.Message), P.Gold)
			end
		else
			UiKit.toast(Lang.translate(result and result.Message or "Couldn't start the round."), RED)
			if mine == shown then
				goButton.Text = Lang.translate("NEXT ROUND")
			end
		end
	end)
end

local function leave()
	if busy then
		return
	end
	busy = true
	hide()
	task.spawn(function()
		GemClient.request("IntroRoundLeave")
		busy = false
		UiKit.toast(Lang.translate("Your intro set waits for you: NEXT STEP or PLAY to carry on."), P.Gold)
	end)
end

local function show(event)
	shown += 1
	local mine = shown
	current = event
	local view = event.View
	if type(view) ~= "table" or type(view.Slots) ~= "table" then
		return
	end
	gui.Enabled = true
	extra.Text = ""
	drawSlots(view)
	local nextRival = view.Next
	if event.Phase == "Lost" then
		header.Text = Lang.translate(string.format("ROUND %d OF %d: KNOCKED DOWN", event.Round, view.Count))
		header.TextColor3 = RED
		pieceName.Text = Lang.translate("SO CLOSE!")
		pieceName.TextColor3 = P.Text
		pieceLine.Text = Lang.translate("Your next try at this round is easier.")
		pieceLine.TextColor3 = P.Dim
		nextLine.Text = Lang.translate(string.format("Beat %s, %s, to win your %s.", nextRival.Name, string.lower(nextRival.Title), IntroRounds.SlotNames[nextRival.Slot]))
		leaveButton.Visible = true
		leaveButton.Text = Lang.translate(if inArena() then "LEAVE ARENA" else "LATER")
		task.spawn(countdown, "TRY AGAIN", mine)
	elseif view.Done then
		header.Text = Lang.translate("SET COMPLETE!")
		header.TextColor3 = P.Gold
		nextLine.Text = Lang.translate(string.format("+%d coins. From now on every win rolls gear that can be Rare or better. Better gems are in the rocks.", event.Coins or IntroRounds.SetCoins))
		leaveButton.Visible = false
		goButton.Text = Lang.translate("TO THE OUTPOST")
		task.spawn(reel, event.Piece, mine)
	else
		header.Text = Lang.translate(string.format("ROUND %d OF %d WON!", event.Round, view.Count))
		header.TextColor3 = P.Gold
		nextLine.Text = Lang.translate(string.format("NEXT: %s, %s. Win your %s.", string.upper(nextRival.Name), nextRival.Title, IntroRounds.SlotNames[nextRival.Slot]))
		leaveButton.Visible = true
		leaveButton.Text = Lang.translate(if inArena() then "LEAVE ARENA" else "LATER")
		if event.Gem then
			extra.Text = Lang.translate(string.format("+ a gem: %s, socketed for you!", event.Gem.Name))
		elseif event.Auto and (event.Auto.Gems or 0) > 0 then
			extra.Text = Lang.translate("Your gems were moved to your best sockets.")
		end
		task.spawn(function()
			reel(event.Piece, mine)
			countdown("NEXT ROUND", mine)
		end)
	end
	scale.Scale = fitScale() * 0.85
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = fitScale() }):Play()
end

local started = false
function IntroRoundsUI.start()
	if started then
		return
	end
	started = true
	build()
	goButton.Activated:Connect(IntroRoundsUI.next)
	leaveButton.Activated:Connect(function()
		if current and current.Phase ~= "Lost" and not inArena() then
			hide() -- (LATER: out in the Outpost already)
			return
		end
		leave()
	end)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Social").OnClientEvent:Connect(function(kind: string, event: any)
		if kind == "IntroRound" and type(event) == "table" then
			-- (after a queued match's result card, which has the screen for EndPause)
			task.delay(if inArena() then 1.2 else 4.5, function()
				show(event)
			end)
		end
	end)
	-- Left the Arena some other way (the match moved them, a respawn): a card
	-- still up for the Arena goes.
	player:GetAttributeChangedSignal("MatchId"):Connect(function()
		if player:GetAttribute("MatchId") and gui.Enabled then
			hide()
		end
	end)
end

return IntroRoundsUI
