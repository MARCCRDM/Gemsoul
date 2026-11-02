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
	  [      CONTINUE INTRO ROUNDS      ]   starts by itself after AutoNext
	  [   GO TO LOBBY  ][ FIRST DUNGEON ]   seconds (in the Arena)

	Three ways on: the next round, the lobby (the Outpost: the set waits, PLAY
	carries on), or the campaign's first dungeon (Client FirstDungeonUI; for
	those it's open to: FirstDungeonUI.allowed). A loss: KNOCKED DOWN, the
	piece still to win in grey, the next try is easier, TRY AGAIN. The whole
	set: SET COMPLETE, the coins, TO THE FIRST DUNGEON (or the lobby).

	  IntroRoundsUI.start()   once (Lobby.client)
	  IntroRoundsUI.busy()    true while a card is up or on its way: what
	                          comes after (leaving the Arena, the kaiju roll)
	                          waits for it, so they play one after another
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
IntroRoundsUI.AutoNext = 5 -- seconds before the next round starts by itself (in the Arena)

local W, H, PAD = 460, 496, 22 -- (px: the card, before scaling)
local HERO_Y = 104 -- (the piece's centre)
local TRACK_Y = 262 -- (the set's nodes' centres)
local WELL_Y = 318
local NODE = 34
local TILE_W, TILE_H, TILE_GAP = 84, 108, 8 -- (the roll's strip)
IntroRoundsUI.RollSeconds = 3.2 -- the strip's spin, fast to stopped

local GOLD, INK, FADED, DUSK = Gilt.Gold, Gilt.Ink, Gilt.Faded, Gilt.Dusk
local STEEL = Gilt.Brass
local RED = Gilt.Red
local TEAL = Color3.fromRGB(58, 203, 233)
local ROT = Color3.fromRGB(150, 236, 84) -- (the first dungeon's)
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
local pending = 0 -- (cards on their way: an event in, its card not up yet)
local queued = {} -- (the intro dungeon's cards waiting their turn: its boss pays three at once)

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

	-- The roll: a strip of pieces running past a marker (fading out at its
	-- ends), in the piece's place till it stops on yours.
	local strip = new("CanvasGroup", {
		Name = "Roll",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, HERO_Y - TILE_H / 2),
		Size = UDim2.fromOffset(W - PAD * 2, TILE_H),
		Visible = false,
		ZIndex = 5,
	}, panel)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.22, 0),
			NumberSequenceKeypoint.new(0.78, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, strip)
	ui.Strip = strip
	ui.Track = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, TILE_H) }, strip)
	-- (the marker: an amber line through the middle, a point above and below)
	local marker = new("Frame", { Name = "Marker", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, HERO_Y), Size = UDim2.fromOffset(TILE_W + 10, TILE_H + 16), Visible = false, ZIndex = 7 }, panel)
	local frameEdge = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -16), ZIndex = 7 }, marker)
	UiKit.round(frameEdge, 10)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.1 }, frameEdge)
	for _, top in { true, false } do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, if top then 0 else 1, if top then 6 else -6),
			Size = UDim2.fromOffset(9, 9),
			Rotation = 45,
			BackgroundColor3 = GOLD,
			ZIndex = 8,
		}, marker)
	end
	ui.Marker = marker

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

	-- The buttons: the next round across, the lobby and the first dungeon
	-- under it; each with a line under its words.
	local function subline(button: TextButton, color: Color3): TextLabel
		local main = button:FindFirstChild("Words") :: TextLabel?
		if main then
			main.Position = UDim2.fromOffset(0, -7)
		end
		local l = words(button, 10, color, BOLD)
		l.Name = "Sub"
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 0.5, 11)
		l.Size = UDim2.new(1, -16, 0, 14)
		l.ZIndex = 3
		return l
	end
	ui.Go = Gilt.button(panel, "CONTINUE INTRO ROUNDS", true, 1, nil, 52, 16)
	ui.Go.Name = "Next"
	ui.Go:SetAttribute("UiSound", "Confirm")
	ui.GoSub = subline(ui.Go, Color3.fromRGB(92, 52, 8))
	ui.Leave = Gilt.button(panel, "GO TO LOBBY", false, 2, nil, 48, 14)
	ui.Leave.Name = "Leave"
	ui.Leave.Font = BLACK
	ui.Leave:SetAttribute("UiSound", "Click")
	ui.LeaveSub = subline(ui.Leave, FADED)
	ui.Dungeon = Gilt.button(panel, "FIRST DUNGEON", false, 3, nil, 48, 14)
	ui.Dungeon.Name = "Dungeon"
	ui.Dungeon.Font = BLACK
	ui.Dungeon:SetAttribute("UiSound", "Confirm")
	ui.DungeonSub = subline(ui.Dungeon, ROT)
	ui.DungeonSub.Text = Lang.translate("The Rot Beachhead")
	-- (the rot's green: a tint over its face, its rim)
	local tint = new("Frame", {
		Name = "Tint",
		BackgroundColor3 = ROT,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, ui.Dungeon)
	UiKit.round(tint, 8)
	local rim = ui.Dungeon:FindFirstChildOfClass("UIStroke")
	if rim then
		rim.Color = ROT
	end
	pcall(IronUi.juice, ui.Go)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UiKit.onTopbar(function()
		if gui.Enabled then
			fit()
		end
	end)
	fit()
end

-- The buttons: the main one across, then the lobby and the first dungeon
-- side by side (or whichever shows, across).
local function placeButtons(withLeave: boolean, withDungeon: boolean)
	local full = W - PAD * 2
	local half = (full - 10) / 2
	local y2 = H - PAD - 48
	local y1 = if withLeave or withDungeon then y2 - 8 - 52 else H - PAD - 52
	ui.Go.Position, ui.Go.Size = UDim2.fromOffset(PAD, y1), UDim2.fromOffset(full, 52)
	ui.Leave.Visible, ui.Dungeon.Visible = withLeave, withDungeon
	if withLeave and withDungeon then
		ui.Leave.Position, ui.Leave.Size = UDim2.fromOffset(PAD, y2), UDim2.fromOffset(half, 48)
		ui.Dungeon.Position, ui.Dungeon.Size = UDim2.fromOffset(PAD + half + 10, y2), UDim2.fromOffset(half, 48)
	elseif withLeave then
		ui.Leave.Position, ui.Leave.Size = UDim2.fromOffset(PAD, y2), UDim2.fromOffset(full, 48)
	elseif withDungeon then
		ui.Dungeon.Position, ui.Dungeon.Size = UDim2.fromOffset(PAD, y2), UDim2.fromOffset(full, 48)
	end
end

-- Whether the first dungeon's on offer to this player.
local function dungeonOpen(): boolean
	local ok, open = pcall(function()
		return require(script.Parent.FirstDungeonUI).allowed()
	end)
	return ok and open == true
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

-- One piece on the strip: its icon in its rarity's colour, its name.
local function rollTile(i: number, entry, slot: string)
	local color = rarityColor(entry.Rarity)
	local tile = new("Frame", {
		Name = "Tile" .. i,
		Position = UDim2.fromOffset((i - 1) * (TILE_W + TILE_GAP), 0),
		Size = UDim2.fromOffset(TILE_W, TILE_H),
		BackgroundColor3 = color:Lerp(Gilt.Deep, 0.8),
	}, ui.Track)
	UiKit.round(tile, 8)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.25 }, tile)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.35) }, tile)
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 56) }, tile)
	icon(art, slot, color, 42)
	local name = words(tile, 10, INK, BOLD)
	name.Text = entry.Name or "?"
	name.Position = UDim2.fromOffset(5, 64)
	name.Size = UDim2.new(1, -10, 0, 26)
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.None
	name.TextYAlignment = Enum.TextYAlignment.Top
	name:SetAttribute("NoTranslate", true)
	local rarity = words(tile, 8, color, BLACK)
	rarity.Text = Lang.translate(string.upper(entry.Rarity or ""))
	rarity.Position = UDim2.fromOffset(5, 92)
	rarity.Size = UDim2.new(1, -10, 0, 10)
	return tile
end

-- The roll: the strip runs past the marker, fast then slowing (each piece
-- that passes ticks, its name under it), and stops on yours.
local function spin(piece, list, land: number, mine: number): boolean
	for _, child in ui.Track:GetChildren() do
		child:Destroy()
	end
	local tiles = {}
	for i, entry in list do
		tiles[i] = rollTile(i, entry, piece.Slot)
	end
	ui.Hero.Visible = false
	ui.Strip.Visible, ui.Marker.Visible = true, true
	local step = TILE_W + TILE_GAP
	local centre = (W - PAD * 2) / 2 - TILE_W / 2
	-- (it starts a few pieces in, and lands a touch off the middle of its tile)
	local from, to = step * 2, (land - 1) * step + (math.random() - 0.5) * TILE_W * 0.5
	local started = os.clock()
	local last = 0
	while true do
		if mine ~= shown then
			return false
		end
		local t = math.clamp((os.clock() - started) / IntroRoundsUI.RollSeconds, 0, 1)
		local eased = 1 - (1 - t) ^ 4
		local at = from + (to - from) * eased
		ui.Track.Position = UDim2.fromOffset(centre - at, 0)
		local index = math.clamp(math.floor(at / step + 0.5) + 1, 1, #list)
		if index ~= last then
			last = index
			local entry = list[index]
			ui.Name.Text = entry.Name or ""
			ui.Name.TextColor3 = rarityColor(entry.Rarity)
			UiSound.play("Tab")
		end
		if t >= 1 then
			break
		end
		task.wait()
	end
	-- (settles dead centre on yours, which lights up)
	ui.Track.Position = UDim2.fromOffset(centre - (land - 1) * step, 0)
	local won = tiles[land]
	if won then
		local edge = won:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Thickness, edge.Transparency = 3, 0
		end
	end
	task.wait(0.55)
	if mine ~= shown then
		return false
	end
	ui.Strip.Visible, ui.Marker.Visible = false, false
	ui.Hero.Visible = true
	return true
end

-- The piece rolling in: the strip (the server's Reel), or without one a
-- quick reel of rarities; then it lands, in 3D.
local function reel(piece, mine: number)
	if type(piece) ~= "table" then
		return
	end
	ui.Sub.Text = ""
	local list = current and current.Piece == piece and current.Reel
	local land = current and current.ReelLand
	if type(list) == "table" and #list > 1 and type(land) == "number" and list[land] then
		if not spin(piece, list, land, mine) then
			return
		end
	else
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
local function countdown(base: string, sub: string, mine: number)
	ui.Go.Text = Lang.translate(base)
	ui.GoSub.Text = sub
	if not inArena() then
		return
	end
	for left = IntroRoundsUI.AutoNext, 1, -1 do
		if mine ~= shown then
			return
		end
		ui.GoSub.Text = sub .. "  ·  " .. Lang.translate("starts in") .. " " .. left
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
	-- In the intro dungeon: the next card, or on (out, the set done: with
	-- the clear's rewards, Server.Dungeons' FirstDungeonDone).
	if current.Where == "Dungeon" then
		local done = current.View and current.View.Done
		hide()
		if #queued > 0 then
			IntroRoundsUI.showNext()
		elseif done then
			busy = true
			task.spawn(function()
				GemClient.request("FirstDungeonDone")
				busy = false
			end)
		end
		return
	end
	-- The dungeon path's last 1v1 won: the kaiju roll, then the dungeon.
	if current.Next == "Dungeon" then
		IntroRoundsUI.toDungeon()
		return
	end
	if current.View and current.View.Done then
		if dungeonOpen() then
			IntroRoundsUI.toDungeon()
			return
		end
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
		if result and result.Ok and result.Dungeon then
			-- (the dungeon's next: Server.IntroRoundsServer)
			if mine == shown then
				hide()
			end
			IntroRoundsUI.toDungeon()
			return
		end
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
				ui.Go.Text = Lang.translate("CONTINUE INTRO ROUNDS")
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

-- FIRST DUNGEON: out of the rounds (the set waits), then the Rot
-- Beachhead's screens and in (Client FirstDungeonUI).
function IntroRoundsUI.toDungeon()
	if busy then
		return
	end
	busy = true
	hide()
	task.spawn(function()
		GemClient.request("IntroRoundLeave")
		busy = false
		local ok, problem = pcall(function()
			return require(script.Parent.FirstDungeonUI).play()
		end)
		if not ok then
			warn("[IntroRounds] first dungeon: " .. tostring(problem))
		end
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
	-- (a roll cut short by this card: its strip goes)
	ui.Strip.Visible, ui.Marker.Visible, ui.Hero.Visible = false, false, true
	if event.Phase ~= "Lost" then
		previews()
	end
	ui.Extra.Text = ""
	ui.Go:SetAttribute("Auto", nil)
	local nextRival = view.Next
	drawSlots(view, if view.Done then nil else nextRival.Slot)
	local arena = inArena()
	local dungeon = dungeonOpen()
	ui.Leave.Text = Lang.translate(if arena then "GO TO LOBBY" else "LATER")
	ui.LeaveSub.Text = Lang.translate(if arena then "Mine & gear up · come back anytime" else "Carry on from PLAY anytime")
	if event.Where == "Dungeon" then
		-- A piece won in the intro dungeon: its roll, and one way on.
		kicker(if view.Done then "STARTER SET COMPLETE" else string.format("PIECE %d OF %d", event.Round, view.Count), GOLD)
		if view.Done then
			ui.WellCaption.Text = string.format("+%d", event.Coins or IntroRounds.SetCoins)
			ui.WellCaption.TextSize = 15
			ui.WellMain.Text = ""
			ui.WellNote.Text = Lang.translate("coins  ·  wins can now roll Rare or better")
		else
			ui.WellCaption.Text = Lang.translate(if (event.More or 0) > 0 then "AND" else "NEXT")
			ui.WellCaption.TextSize = 10
			ui.WellMain.Text = if (event.More or 0) > 0
				then string.format(Lang.translate("%d more pieces"), event.More)
				else Lang.translate("Tung Tung Tung Sahur")
			ui.WellNote.Text = Lang.translate(if (event.More or 0) > 0 then "from the boss" else "THE NEST")
		end
		ui.Prize.Visible, ui.PrizeIcon.Visible = false, false
		ui.Go.Text = Lang.translate(if (event.More or 0) > 0 then "NEXT PIECE" elseif view.Done then "TO THE LOBBY" else "ON TO THE BOSS")
		ui.GoSub.Text = Lang.translate(if (event.More or 0) > 0 then "Roll it" elseif view.Done then "Your set's complete" else "Follow the beam to the nest")
		placeButtons(false, false)
		if event.Gem then
			ui.Extra.Text = Lang.translate(string.format(if event.Auto and (event.Auto.Gems or 0) > 0 then "+ %s gem, socketed for you" else "+ %s gem, in your pouch", event.Gem.Name))
		end
		task.spawn(reel, event.Piece, mine)
	elseif event.Phase == "Lost" then
		kicker(string.format("ROUND %d OF %d  ·  KNOCKED DOWN", event.Round, view.Count), RED)
		hero(nextRival.Slot, LOCKED, true)
		ui.Name.Text = Lang.translate("So close!")
		ui.Name.TextColor3 = INK
		ui.Sub.Text = Lang.translate("Your next try at this round is easier")
		nextUp("REMATCH", nextRival)
		placeButtons(true, dungeon)
		task.spawn(countdown, "TRY AGAIN", Lang.translate("Easier this time"), mine)
	elseif view.Done then
		kicker("STARTER SET COMPLETE", GOLD)
		ui.WellCaption.Text = string.format("+%d", event.Coins or IntroRounds.SetCoins)
		ui.WellCaption.TextSize = 15
		ui.WellMain.Text = ""
		ui.WellNote.Text = Lang.translate("coins  ·  wins can now roll Rare or better")
		ui.Prize.Visible, ui.PrizeIcon.Visible = false, false
		if dungeon then
			ui.Go.Text = Lang.translate("TO THE FIRST DUNGEON")
			ui.GoSub.Text = Lang.translate("The Rot Beachhead · your kaiju fight with you")
			ui.Leave.Text = Lang.translate("GO TO LOBBY")
			ui.LeaveSub.Text = Lang.translate("Mine & gear up · the dungeon waits")
		else
			ui.Go.Text = Lang.translate("GO TO LOBBY")
			ui.GoSub.Text = Lang.translate("Mine & gear up")
		end
		placeButtons(dungeon, false)
		task.spawn(reel, event.Piece, mine)
	else
		kicker(string.format("ROUND %d OF %d  WON", event.Round, view.Count), GOLD)
		if event.Next == "Dungeon" then
			-- (the dungeon path's last 1v1: the kaiju roll and the dungeon next)
			ui.WellCaption.Text = Lang.translate("NEXT")
			ui.WellCaption.TextSize = 10
			ui.WellMain.Text = Lang.translate("Your kaiju, then the dungeon")
			ui.WellNote.Text = Lang.translate("Tung Tung Tung Sahur waits")
			ui.Prize.Visible, ui.PrizeIcon.Visible = false, false
			placeButtons(true, false)
		else
			nextUp("NEXT", nextRival)
			placeButtons(true, dungeon)
		end
		if event.Gem then
			ui.Extra.Text = Lang.translate(string.format(if event.Auto and (event.Auto.Gems or 0) > 0 then "+ %s gem, socketed for you" else "+ %s gem, in your pouch", event.Gem.Name))
		elseif event.Auto and (event.Auto.Gems or 0) > 0 then
			ui.Extra.Text = Lang.translate("Gems moved to your best sockets")
		end
		task.spawn(function()
			reel(event.Piece, mine)
			if event.Next == "Dungeon" then
				countdown("CONTINUE", Lang.translate("Your kaiju, then the dungeon"), mine)
			else
				countdown("CONTINUE INTRO ROUNDS", string.format(Lang.translate("Round %d of %d"), event.Round + 1, view.Count), mine)
			end
		end)
	end
	fit()
	scale.Scale = fitScale * 0.9
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = fitScale }):Play()
end

function IntroRoundsUI.busy(): boolean
	return pending > 0 or #queued > 0 or (gui ~= nil and gui.Enabled)
end

-- The intro dungeon's next waiting card.
function IntroRoundsUI.showNext()
	local event = table.remove(queued, 1)
	if event then
		show(event)
	end
end

local started = false
function IntroRoundsUI.start()
	if started then
		return
	end
	started = true
	build()
	ui.Go.Activated:Connect(IntroRoundsUI.next)
	ui.Dungeon.Activated:Connect(IntroRoundsUI.toDungeon)
	ui.Leave.Activated:Connect(function()
		if current and current.View and current.View.Done then
			-- (the set's done: GO TO LOBBY beside TO THE FIRST DUNGEON)
			if busy then
				return
			end
			busy = true
			hide()
			task.spawn(function()
				GemClient.request("IntroRoundLeave")
				busy = false
			end)
			return
		end
		if current and current.Phase ~= "Lost" and not inArena() then
			hide() -- (LATER: out in the Outpost already)
			return
		end
		leave()
	end)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Social").OnClientEvent:Connect(function(kind: string, event: any)
		if kind == "IntroRound" and type(event) == "table" and event.Where == "Dungeon" then
			-- (the intro dungeon's: one after another, NEXT PIECE between them)
			table.insert(queued, event)
			if #queued == 1 and not gui.Enabled then
				pending += 1
				task.delay(1, function()
					pending -= 1
					if not gui.Enabled then
						IntroRoundsUI.showNext()
					end
				end)
			end
			return
		end
		if kind == "IntroRound" and type(event) == "table" then
			-- (after a queued match's result card, which has the screen for EndPause)
			pending += 1
			task.delay(if inArena() then 1.2 else 4.5, function()
				pending -= 1
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
