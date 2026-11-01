--[[
	The intro rounds' card (Shared.IntroRounds, Server.IntroRoundsServer):
	between rounds, over the Arena, in the windows' look (Client.GiltUi):
	deep navy, an amber bar along the top, amber for what matters.

	        ◆ ROUND 1 OF 6  WON ◆
	              ( ⚔ )              the piece itself (3D), in its rarity's glow: its
	         Impact Falchion          name rolls in through the rarities
	     UNCOMMON SWORD · EQUIPPED    and lands on its own
	  (⚔)──(⛨)──( )──( )──( )──( )    the set, each slot lit as it's won,
	                                  the next one ringed in amber
	  [ NEXT  Vera Coppercoil   SHIELD ]
	  [ NEXT ROUND  5 ]  [ LEAVE ARENA ]    starts by itself after AutoNext
	                                        seconds (in the Arena)

	A loss: KNOCKED DOWN, the piece still to win in grey, the next try is
	easier, TRY AGAIN / LEAVE. The whole set: SET COMPLETE, the coins, TO THE
	OUTPOST.

	  IntroRoundsUI.start()   once (Lobby.client)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
local Lang = require(ReplicatedStorage.Shared.Lang)
local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

local IntroRoundsUI = {}

local new = IronUi.new
local player = Players.LocalPlayer
IntroRoundsUI.AutoNext = 5 -- seconds before NEXT ROUND starts by itself (in the Arena)

local W, H, PAD = 460, 432, 22 -- (px: the card, before scaling)
local HERO_Y = 104 -- (the piece's centre)
local TRACK_Y = 262 -- (the set's nodes' centres)
local WELL_Y = 318
local NODE = 34

local GOLD, INK, FADED, DUSK = Gilt.Gold, Gilt.Ink, Gilt.Faded, Gilt.Dusk
local STEEL = Gilt.Brass
local RED = Gilt.Red
local TEAL = Color3.fromRGB(58, 203, 233)
local LOCKED = Color3.fromRGB(70, 82, 110) -- (a slot's icon, not won yet)
local BLACK = Gilt.Display
local BOLD = Gilt.Serif

-- (the gear's drawn icons; a letter stands in if they can't be drawn)
local GearArt = nil
pcall(function()
	GearArt = require(script.Parent.GearArt)
end)

local function rarityColor(name: string?): Color3
	for _, rarity in GearRolls.Rarities do
		if rarity.Name == name then
			return rarity.Color
		end
	end
	return FADED
end

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

local gui: ScreenGui
local panel: Frame
local scale: UIScale
local ui: any = {}
local shown = 0 -- (each show's number: an older countdown stops)
local current = nil -- the event on the card
local busy = false
local fitScale = 1

local function words(parent: Instance, size: number, color: Color3, font: Enum.Font): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = "",
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

-- Centred words, `h` tall, across the card at `y` (their middle).
local function line(size: number, color: Color3, font: Enum.Font, y: number, h: number): TextLabel
	local l = words(panel, size, color, font)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromOffset(W / 2, y)
	l.Size = UDim2.fromOffset(W - PAD * 2, h)
	return l
end

-- Words sized to themselves (in a row's list).
local function fitted(parent: Instance, size: number, color: Color3, font: Enum.Font, order: number): TextLabel
	local l = words(parent, size, color, font)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size + 6)
	l.TextTruncate = Enum.TextTruncate.None
	l.LayoutOrder = order
	return l
end

local function row(parent: Instance, align: Enum.HorizontalAlignment, gap: number)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	}, parent)
end

local function circle(parent: Instance, size: number, color: Color3, transparency: number, at: UDim2?): Frame
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
	}, parent)
	UiKit.round(f, size)
	return f
end

-- A slot's icon, about `size` px, in `color`, in the middle of `holder`.
local function icon(holder: Instance, slot: string, color: Color3, size: number)
	for _, child in holder:GetChildren() do
		if child.Name == "Icon" then
			child:Destroy()
		end
	end
	-- (GearArt draws in a 38 x 34 box, about 27 px across)
	local box = new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 34),
		ZIndex = 4,
	}, holder)
	new("UIScale", { Scale = size / 27 }, box)
	if not (GearArt and pcall(GearArt.icon, box, slot, {}, color)) then
		local stand = words(box, 16, color, BLACK)
		stand.Size = UDim2.fromScale(1, 1)
		stand.Text = string.sub(IntroRounds.SlotNames[slot] or slot, 1, 1)
	end
end

-- (in the middle, scaled to fit, clear of Roblox's buttons on a phone)
local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 and screen.Y > 0 then
		local s = math.min(1, (screen.X - 24) / W, (screen.Y - 24) / H)
		local room, at = UiKit.clearTopbar(screen, Vector2.new(W, H) * s)
		fitScale = s * room
		scale.Scale = fitScale
		panel.Position = at
	end
end

local function build()
	gui = UiKit.gui("IntroRounds", 32)
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	-- The card: deep navy with a cool sheen down it, a steel edge, the
	-- amber bar along the top (Gilt.frame's, at a fixed size).
	panel = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, gui)
	UiKit.round(panel, 14)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 36, 58)),
			ColorSequenceKeypoint.new(0.35, Gilt.Stone),
			ColorSequenceKeypoint.new(1, Gilt.Deep),
		}),
	}, panel)
	new("UIStroke", { Color = Gilt.Bronze, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
	local bar = new("Frame", { Name = "Rim", BackgroundColor3 = GOLD, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 0, 3) }, panel)
	UiKit.round(bar, 2)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, bar)
	scale = new("UIScale", { Scale = 1 }, panel)

	-- The kicker: ── ◆ ROUND 1 OF 6  WON ◆ ──
	local kicker = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 20), Size = UDim2.fromOffset(W - PAD * 2, 20) }, panel)
	row(kicker, Enum.HorizontalAlignment.Center, 8)
	ui.KickerParts = {}
	for i, part in { "RuleL", "StudL", "Text", "StudR", "RuleR" } do
		local f
		if part == "Text" then
			f = fitted(kicker, 13, GOLD, BLACK, i)
			ui.Kicker = f
		elseif string.sub(part, 1, 4) == "Stud" then
			local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(8, 8), LayoutOrder = i }, kicker)
			f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundColor3 = GOLD }, holder)
		else
			f = new("Frame", { BackgroundColor3 = GOLD, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 1), LayoutOrder = i }, kicker)
			new("UIGradient", {
				Transparency = NumberSequence.new(if part == "RuleL" then 1 else 0.2, if part == "RuleL" then 0.2 else 1),
			}, f)
		end
		ui.KickerParts[part] = f
	end

	-- The piece, in its rarity's glow, in a ring of ticks.
	local hero = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, HERO_Y), Size = UDim2.fromOffset(124, 124) }, panel)
	ui.Glow = { circle(hero, 124, GOLD, 0.93), circle(hero, 104, GOLD, 0.88), circle(hero, 92, Gilt.Deep, 0.35) }
	ui.Ring = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.35 }, ui.Glow[3])
	ui.Ticks = {}
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local tick = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * 53, 0.5, math.sin(angle) * 53),
			Size = UDim2.fromOffset(5, 1),
			Rotation = i * 30,
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.5,
		}, hero)
		table.insert(ui.Ticks, tick)
	end
	ui.Hero = hero
	ui.Mystery = words(hero, 30, FADED, BLACK)
	ui.Mystery.Size = UDim2.fromScale(1, 1)
	ui.Mystery.ZIndex = 5
	ui.Mystery.Text = "?"

	-- Its name, what it is, a gem with it.
	ui.Name = line(26, INK, BLACK, 182, 32)
	ui.Name:SetAttribute("NoTranslate", true)
	ui.Sub = line(11, FADED, BOLD, 206, 16)
	ui.Sub.RichText = true
	ui.Extra = line(11, TEAL, BOLD, 224, 16)

	-- The set: six nodes on a line.
	local count = IntroRounds.Count
	local span = W - PAD * 2 - 40
	local step = span / (count - 1)
	ui.Links, ui.Nodes = {}, {}
	for i = 1, count - 1 do
		local x = PAD + 20 + (i - 1) * step
		ui.Links[i] = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(x + NODE / 2 + 1, TRACK_Y),
			Size = UDim2.fromOffset(step - NODE - 2, 2),
			BackgroundColor3 = STEEL,
		}, panel)
	end
	for i = 1, count do
		local at = UDim2.fromOffset(PAD + 20 + (i - 1) * step, TRACK_Y)
		local halo = circle(panel, NODE + 12, GOLD, 1, at)
		local haloEdge = new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.7 }, halo)
		local node = circle(panel, NODE, Gilt.Well, 0, at)
		local edge = new("UIStroke", { Color = STEEL, Thickness = 1.5 }, node)
		local name = words(panel, 9, DUSK, BOLD)
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Position = at + UDim2.fromOffset(0, 30)
		name.Size = UDim2.fromOffset(step, 12)
		ui.Nodes[i] = { Node = node, Edge = edge, Halo = halo, HaloEdge = haloEdge, Name = name }
	end
	-- (the next one's halo breathes)
	pcall(function()
		for _, n in ui.Nodes do
			TweenService:Create(n.HaloEdge, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.15 }):Play()
		end
	end)

	-- Who's next (or the reward), in a well.
	local well = new("Frame", { Position = UDim2.fromOffset(PAD, WELL_Y), Size = UDim2.fromOffset(W - PAD * 2, 40) }, panel)
	Gilt.well(well)
	local left = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0) }, well)
	row(left, Enum.HorizontalAlignment.Left, 10)
	ui.WellCaption = fitted(left, 10, GOLD, BLACK, 1)
	ui.WellMain = fitted(left, 14, INK, BLACK, 2)
	ui.WellNote = fitted(left, 10, DUSK, BOLD, 3)
	local right = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -24, 1, 0) }, well)
	row(right, Enum.HorizontalAlignment.Right, 6)
	ui.Prize = fitted(right, 11, GOLD, BLACK, 1)
	ui.PrizeIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24), LayoutOrder = 2 }, right)

	-- The buttons.
	ui.Go = Gilt.button(panel, "NEXT ROUND", true, 1, nil, 44, 16)
	ui.Go.Name = "Next"
	ui.Go:SetAttribute("UiSound", "Confirm")
	ui.Leave = Gilt.button(panel, "LEAVE ARENA", false, 2, nil, 44, 13)
	ui.Leave.Name = "Leave"
	ui.Leave:SetAttribute("UiSound", "Click")
	pcall(IronUi.juice, ui.Go)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UiKit.onTopbar(function()
		if gui.Enabled then
			fit()
		end
	end)
	fit()
end

-- The buttons: NEXT wide with LEAVE beside it, or NEXT alone across.
local function placeButtons(withLeave: boolean)
	local y = H - PAD - 44
	ui.Leave.Visible = withLeave
	ui.Go.Position = UDim2.fromOffset(PAD, y)
	if withLeave then
		ui.Go.Size = UDim2.fromOffset(W - PAD * 2 - 140, 44)
		ui.Leave.Position = UDim2.fromOffset(W - PAD - 130, y)
		ui.Leave.Size = UDim2.fromOffset(130, 44)
	else
		ui.Go.Size = UDim2.fromOffset(W - PAD * 2, 44)
	end
end

local function hide()
	shown += 1
	gui.Enabled = false
	current = nil
end

-- The kicker, in `color`.
local function kicker(text: string, color: Color3)
	ui.Kicker.Text = Lang.translate(text)
	ui.Kicker.TextColor3 = color
	for name, part in ui.KickerParts do
		if name ~= "Text" then
			part.BackgroundColor3 = color
		end
	end
end

-- The piece's glow, ring and icon, in `color` (`dim`: a piece still to win).
local function hero(slot: string, color: Color3, dim: boolean?)
	ui.Glow[1].BackgroundColor3, ui.Glow[2].BackgroundColor3 = color, color
	ui.Glow[1].BackgroundTransparency = if dim then 0.97 else 0.9
	ui.Glow[2].BackgroundTransparency = if dim then 0.94 else 0.82
	ui.Ring.Color = color
	for _, tick in ui.Ticks do
		tick.BackgroundColor3 = color
	end
	if ui.Model then
		ui.Model:Destroy()
		ui.Model = nil
	end
	icon(ui.Glow[3], slot, if dim then LOCKED else color, 72)
	ui.Mystery.Visible = dim == true
end

-- The piece itself, in 3D, in place of its icon: the server's bare preview
-- of it (built on request, as the Inventory's are), or, while that's on its
-- way, the one you're wearing if it's this piece. The icon stays if neither
-- comes within a few seconds.
local function previews()
	task.spawn(function()
		for attempt = 1, 4 do
			local ok, result = pcall(GemClient.request, "GearPreviews")
			if ok and type(result) == "table" and result.Ok and result.Done then
				return
			end
			task.wait(0.4 * attempt)
		end
	end)
end
local function showModel(piece, mine: number)
	if not (GearArt and type(piece) == "table" and piece.Id) then
		return
	end
	for _ = 1, 16 do
		if mine ~= shown then
			return
		end
		local view = new("ViewportFrame", {
			Name = "Piece",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(112, 112),
			Ambient = Color3.fromRGB(190, 186, 200),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-0.4, -0.8, -0.6),
			ZIndex = 6,
		}, ui.Hero)
		local ok, drawn = pcall(GearArt.draw, view, piece.Slot, piece.Id, false)
		if not (ok and drawn) then
			local worn = GemClient.Profile and GemClient.Profile.Character
			if worn and worn[piece.Slot] == piece.Id then
				ok, drawn = pcall(GearArt.draw, view, piece.Slot, piece.Id, true)
			end
		end
		if ok and drawn and mine == shown then
			if ui.Model then
				ui.Model:Destroy()
			end
			ui.Model = view
			for _, child in ui.Glow[3]:GetChildren() do
				if child.Name == "Icon" then
					child:Destroy()
				end
			end
			return
		end
		view:Destroy()
		task.wait(0.25)
	end
end

-- The set: each node lit in its piece's rarity once won, the next one
-- ringed in amber.
local function drawSlots(view, nextSlot: string?)
	for i, slot in view.Slots do
		local n = ui.Nodes[i]
		if not n then
			continue
		end
		local piece = slot.Piece
		local isNext = not piece and slot.Slot == nextSlot
		local color = if piece then rarityColor(piece.Rarity) elseif isNext then GOLD else STEEL
		n.Node.BackgroundColor3 = if piece then color:Lerp(Gilt.Deep, 0.75) else Gilt.Well
		n.Edge.Color = color
		n.Edge.Transparency = if piece or isNext then 0 else 0.3
		n.Halo.Visible = isNext
		n.Name.Text = Lang.translate(slot.Name)
		n.Name.TextColor3 = if piece then INK elseif isNext then GOLD else DUSK
		icon(n.Node, slot.Slot, if piece or isNext then color else LOCKED, 20)
		local link = ui.Links[i]
		if link then
			local after = view.Slots[i + 1]
			local joined = piece ~= nil and after ~= nil and after.Piece ~= nil
			link.BackgroundColor3 = if joined then color else STEEL
			link.BackgroundTransparency = if joined then 0 else 0.45
		end
	end
end

-- The piece on the card: its name in its rarity's colour, what it is.
local function drawPiece(piece)
	local color = rarityColor(piece.Rarity)
	hero(piece.Slot, color)
	ui.Name.Text = piece.Name
	ui.Name.TextColor3 = color
	ui.Sub.Text = string.format(
		'<font color="%s">%s</font>  %s  ·  %s',
		hex(color),
		Lang.translate(string.upper(piece.Rarity)),
		Lang.translate(IntroRounds.SlotNames[piece.Slot] or string.upper(tostring(piece.Slot))),
		Lang.translate("EQUIPPED")
	)
end

-- The piece rolling in: a quick reel of rarities, slowing, then its own.
local function reel(piece, mine: number)
	if type(piece) ~= "table" then
		return
	end
	ui.Sub.Text = ""
	local names = { "Common", "Uncommon", "Rare", "Uncommon", "Ultra Rare", "Uncommon", "Rare" }
	for i = 1, 14 do
		if mine ~= shown then
			return
		end
		local pick = names[(i % #names) + 1]
		local color = rarityColor(pick)
		ui.Name.Text = Lang.translate(string.upper(pick))
		ui.Name.TextColor3 = color
		hero(piece.Slot, color)
		UiSound.play("Tab")
		task.wait(0.04 + i * 0.012)
	end
	if mine ~= shown then
		return
	end
	drawPiece(piece)
	task.spawn(showModel, piece, mine)
	UiSound.play(if piece.Rarity == "Rare" then "Reward" else "Equip")
	scale.Scale = fitScale * 1.04
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fitScale }):Play()
end

local function inArena(): boolean
	return player:GetAttribute("CombatSession") == "Training"
end

-- NEXT ROUND counts down by itself in the Arena (nothing to wait for
-- there).
local function countdown(base: string, mine: number)
	ui.Go.Text = Lang.translate(base)
	if not inArena() then
		return
	end
	for left = IntroRoundsUI.AutoNext, 1, -1 do
		if mine ~= shown then
			return
		end
		ui.Go.Text = Lang.translate(base) .. "  " .. left
		task.wait(1)
	end
	if mine == shown and gui.Enabled then
		ui.Go:SetAttribute("Auto", true)
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
	ui.Go.Text = Lang.translate("…")
	task.spawn(function()
		local result = GemClient.request("IntroRoundNext")
		busy = false
		if result and result.Ok then
			if mine == shown then
				hide()
			end
			if result.Real then
				UiKit.toast(Lang.translate(result.Message), GOLD)
			end
		else
			UiKit.toast(Lang.translate(result and result.Message or "Couldn't start the round."), RED)
			if mine == shown then
				ui.Go.Text = Lang.translate("NEXT ROUND")
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
		UiKit.toast(Lang.translate("Your intro set waits for you: NEXT STEP or PLAY to carry on."), GOLD)
	end)
end

-- Who's next, and the piece beating them wins.
local function nextUp(caption: string, rival)
	ui.WellCaption.Text = Lang.translate(caption)
	ui.WellCaption.TextSize = 10
	ui.WellMain.Text = rival.Name
	ui.WellMain:SetAttribute("NoTranslate", true) -- (a name)
	ui.WellNote.Text = Lang.translate(rival.Title)
	ui.Prize.Visible, ui.PrizeIcon.Visible = true, true
	ui.Prize.Text = Lang.translate(IntroRounds.SlotNames[rival.Slot] or "")
	icon(ui.PrizeIcon, rival.Slot, GOLD, 20)
end

local function show(event)
	local view = event.View
	if type(view) ~= "table" or type(view.Slots) ~= "table" then
		return
	end
	shown += 1
	local mine = shown
	current = event
	gui.Enabled = true
	if event.Phase ~= "Lost" then
		previews()
	end
	ui.Extra.Text = ""
	ui.Go:SetAttribute("Auto", nil)
	local nextRival = view.Next
	drawSlots(view, if view.Done then nil else nextRival.Slot)
	local leaveText = Lang.translate(if inArena() then "LEAVE ARENA" else "LATER")
	if event.Phase == "Lost" then
		kicker(string.format("ROUND %d OF %d  ·  KNOCKED DOWN", event.Round, view.Count), RED)
		hero(nextRival.Slot, LOCKED, true)
		ui.Name.Text = Lang.translate("So close!")
		ui.Name.TextColor3 = INK
		ui.Sub.Text = Lang.translate("Your next try at this round is easier")
		nextUp("REMATCH", nextRival)
		ui.Leave.Text = leaveText
		placeButtons(true)
		task.spawn(countdown, "TRY AGAIN", mine)
	elseif view.Done then
		kicker("STARTER SET COMPLETE", GOLD)
		ui.WellCaption.Text = string.format("+%d", event.Coins or IntroRounds.SetCoins)
		ui.WellCaption.TextSize = 15
		ui.WellMain.Text = ""
		ui.WellNote.Text = Lang.translate("coins  ·  wins can now roll Rare or better")
		ui.Prize.Visible, ui.PrizeIcon.Visible = false, false
		ui.Go.Text = Lang.translate("TO THE OUTPOST")
		placeButtons(false)
		task.spawn(reel, event.Piece, mine)
	else
		kicker(string.format("ROUND %d OF %d  WON", event.Round, view.Count), GOLD)
		nextUp("NEXT", nextRival)
		ui.Leave.Text = leaveText
		placeButtons(true)
		if event.Gem then
			ui.Extra.Text = Lang.translate(string.format("+ %s gem, socketed for you", event.Gem.Name))
		elseif event.Auto and (event.Auto.Gems or 0) > 0 then
			ui.Extra.Text = Lang.translate("Gems moved to your best sockets")
		end
		task.spawn(function()
			reel(event.Piece, mine)
			countdown("NEXT ROUND", mine)
		end)
	end
	fit()
	scale.Scale = fitScale * 0.9
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fitScale }):Play()
end

local started = false
function IntroRoundsUI.start()
	if started then
		return
	end
	started = true
	build()
	ui.Go.Activated:Connect(IntroRoundsUI.next)
	ui.Leave.Activated:Connect(function()
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
