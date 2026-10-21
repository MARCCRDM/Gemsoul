--[[
	The kaiju starter roll (KaijuServer; see docs/kaiju.md): the three kaiju
	you start with, rolled on the same screen as the intro's gem roll
	(Intro.client, revealMoves). Each kaiju has a tall card, and the card's
	window is a reel: kaiju of every kind and element run down past it, each
	on a glow of a Gemsoul rarity at the real odds (GemRoller), the one going
	by named under the window in its rarity's colour, until it stops on
	yours. It lands with a flash in its Gemsoul's rarity and drops onto its
	spot, then its E move rises out of it, ready. Under it go its name, its
	kind, its health, damage and speed, what it's like, and its three moves
	with their icons (E now, Q at level 5, R at level 10). The first stops,
	then the next, then the last; click to land them all at once. START
	claims them; the server keeps the roll till then, so leaving doesn't
	reroll it.

	  KaijuRoll.play(after)   the roll you're owed, then after() (at once if
	                          there's none): in the intro after the gem roll,
	                          and once in the Outpost for a player from before
	  KaijuRoll.showing()     true while it's up
	  KaijuRoll.Frame         how a kaiju is framed in its window: the camera
	                          round it, by its size (Side, Up, Back, Aim; Fov)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local CardFX = require(script.Parent.ElementCardFX)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local LotterySound = require(script.Parent.LotterySound)
local SurgeIcons = require(script.Parent.SurgeIcons)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new

local KaijuRoll = {}

-- The intro's launch-screen palette.
local C = {
	Ink = Color3.fromRGB(7, 10, 17),
	Panel = Color3.fromRGB(15, 21, 31),
	Card = Color3.fromRGB(18, 25, 36),
	Line = Color3.fromRGB(44, 58, 76),
	Text = Color3.fromRGB(240, 244, 250),
	Dim = Color3.fromRGB(138, 156, 178),
	Faint = Color3.fromRGB(78, 94, 114),
	Gold = Color3.fromRGB(240, 186, 92),
	Good = Color3.fromRGB(90, 220, 150),
	Night = Color3.fromRGB(16, 22, 42),
}
local RANKS = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
-- The gem roll's sizes (px), with a window wide enough for a kaiju: the
-- board, a card and the step to the next, the window and one kaiju on the
-- reel (a short (phone) screen's window and reel are shorter, and it skips
-- what the kaiju is like, so the cards scale up).
local BOARD_W, CARD_W, STEP = 900, 284, 300
local WIN_W, WIN_H, CELL = 236, 176, 136
local SHORT_WIN_H, SHORT_CELL = 148, 116
local WIN_Y = 74 -- the window's top, in its card
local TOP = 84 -- the cards' top, on the board
local ROUND = 26 -- the window's corners
local AUTO = 20 -- seconds till START goes on its own
KaijuRoll.Frame = { Side = 0.92, Up = 0.3, Back = 1.12, Aim = 0.02, Fov = 36 }

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or C.Gold
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	return new("Frame", props, parent)
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or C.Text,
		Font = font or Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 45,
	}, parent)
end

local function tween(object: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local playing = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	playing:Play()
	return playing
end

local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	}, parent)
end

-- A physical key, as on the gem roll's cards: a darker base under a raised
-- cap. Returns it, and a function that recolours it.
local function keycap(parent: Instance, key: string, color: Color3, size: number)
	local base = frame(
		parent,
		{ BackgroundColor3 = color:Lerp(C.Ink, 0.55), Size = UDim2.fromOffset(size, size + 6), ZIndex = 45 }
	)
	UiKit.round(base, 9)
	local cap = frame(base, { BackgroundColor3 = color, Size = UDim2.fromOffset(size, size), ZIndex = 46 })
	UiKit.round(cap, 9)
	local shine = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(C.Text, 0.35), color) }, cap)
	local glyph = label(cap, key, math.floor(size * 0.58), C.Ink, Enum.Font.GothamBlack)
	glyph.Size, glyph.TextXAlignment, glyph.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 47
	return base,
		function(to: Color3)
			base.BackgroundColor3, cap.BackgroundColor3 = to:Lerp(C.Ink, 0.55), to
			shine.Color = ColorSequence.new(to:Lerp(C.Text, 0.35), to)
		end
end

-- A glow of a Gemsoul rarity behind a kaiju on the reel: stronger the rarer.
local GLOW = { Common = 0.9, Uncommon = 0.86, Rare = 0.8, UltraRare = 0.74, Legendary = 0.66 }
local GLOW_SIZES = { 0.86, 0.56 }
local function rarityGlow(parent: Instance, tier: string, size: number): { Frame }
	local color = GemConfig.TierColors[tier] or C.Line
	local discs = {}
	for i, scale in GLOW_SIZES do
		local disc = frame(parent, {
			Name = "RarityGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(size * scale), math.floor(size * scale)),
			BackgroundColor3 = color,
			BackgroundTransparency = (GLOW[tier] or 0.9) + (i - 1) * 0.04,
			ZIndex = 45,
		})
		UiKit.round(disc, 999)
		discs[i] = disc
	end
	return discs
end

-- A kaiju in a view the window's size, framed by KaijuRoll.Frame from its
-- front quarter (the camera set by its size).
local function stage(species: string, element: string, width: number, height: number)
	local model = KaijuModels.forPortrait(KaijuModels.build(species, element))
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y * 1.25, size.Z)
	local f = KaijuRoll.Frame
	local view = new("ViewportFrame", {
		Name = "KaijuView",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Ambient = KaijuModels.Portrait.Ambient,
		LightColor = KaijuModels.Portrait.LightColor,
		LightDirection = KaijuModels.Portrait.LightDirection,
		ZIndex = 46,
	})
	view:SetAttribute("Kaiju", species .. "/" .. element)
	local camera = Instance.new("Camera")
	camera.FieldOfView = f.Fov
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(reach * f.Side, reach * f.Up, -reach * f.Back),
		cf.Position + Vector3.new(0, reach * f.Aim, 0)
	)
	camera.Parent = view
	view.CurrentCamera = camera
	model.Parent = view
	return { View = view, Model = model, Center = cf.Position, Rest = model:GetPivot(), Reach = reach }
end

-- Turned by `angle` about its middle, `lift` studs up.
local function pose(staged, angle: number, lift: number?)
	local center = CFrame.new(staged.Center)
	staged.Model:PivotTo(
		CFrame.new(0, lift or 0, 0) * center * CFrame.Angles(0, angle, 0) * center:Inverse() * staged.Rest
	)
end

local function moveName(id: string?): string
	local move = Kaiju.moveInfo(id)
	return if move then move.Name else "?"
end

local gui: ScreenGui? = nil

function KaijuRoll.showing(): boolean
	return gui ~= nil and gui.Parent ~= nil
end

function KaijuRoll.play(after: (() -> ())?)
	local function done()
		if after then
			after()
		end
	end
	if KaijuRoll.showing() then
		done()
		return
	end
	-- The backdrop first (the screen behind it isn't for seeing), then the roll.
	local screen = UiKit.gui("KaijuRoll", 60)
	screen.IgnoreGuiInset = false
	gui = screen
	-- (Under Roblox's top bar too: the board starts below it.)
	new("Frame", {
		Name = "TopBand",
		Position = UDim2.fromOffset(0, -120),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = C.Ink,
	}, screen)
	local shade = new("TextButton", {
		Name = "Shade",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, screen)
	local result = GemClient.request("KaijuRoll")
	local rolls = if result.Ok and type(result.Rolls) == "table" then result.Rolls else {}
	if #rolls == 0 then
		screen:Destroy()
		gui = nil
		done()
		return
	end

	local connections = {}
	local function close()
		for _, connection in connections do
			connection:Disconnect()
		end
		screen:Destroy()
		gui = nil
	end

	-- The gem roll's arena: night flooding up from below, a few stars, two
	-- spotlights crossing overhead, and the stands in rings round a floor lit
	-- in the colours of the kaiju's elements.
	local flood = frame(
		shade,
		{ BackgroundColor3 = C.Night, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40 }
	)
	new("UIGradient", {
		Rotation = 270,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.55, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, flood)
	tween(flood, 0.6, { BackgroundTransparency = 0 })
	for i = 1, 18 do
		frame(shade, {
			Position = UDim2.fromScale(((i * 37) % 97) / 96, ((i * 23) % 41) / 100),
			Size = UDim2.fromOffset(if i % 4 == 0 then 2 else 1, if i % 4 == 0 then 2 else 1),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = if i % 4 == 0 then 0.5 else 0.72,
			ZIndex = 40,
		})
	end
	for _, side in { -1, 1 } do
		local beam = frame(shade, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5 + side * 0.34, -0.12),
			Size = UDim2.fromScale(0.07, 1.3),
			Rotation = side * 24,
			BackgroundColor3 = C.Gold:Lerp(C.Text, 0.6),
			BackgroundTransparency = 1,
			ZIndex = 40,
		})
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.88),
				NumberSequenceKeypoint.new(0.7, 0.97),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, beam)
		tween(beam, 0.8, { BackgroundTransparency = 0 })
	end
	local floorGlow = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.04),
		Size = UDim2.fromScale(0.9, 0.34),
		BackgroundColor3 = C.Text,
		BackgroundTransparency = 1,
		ZIndex = 40,
	})
	UiKit.round(floorGlow, 999)
	local floorColors = {}
	for i, entry in rolls do
		table.insert(
			floorColors,
			ColorSequenceKeypoint.new((i - 1) / math.max(1, #rolls - 1), elementColor(entry.Element))
		)
	end
	if #floorColors == 1 then
		table.insert(floorColors, ColorSequenceKeypoint.new(1, floorColors[1].Value))
	end
	new("UIGradient", {
		Color = ColorSequence.new(floorColors),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
	}, floorGlow)
	tween(floorGlow, 0.8, { BackgroundTransparency = 0 })
	for i, spec in { { 1.5, 0.62, 0.8 }, { 1.18, 0.46, 0.72 }, { 0.9, 0.32, 0.6 } } do
		local stand = frame(shade, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1.04),
			Size = UDim2.fromScale(spec[1], spec[2]),
			BackgroundTransparency = 1,
			ZIndex = 40,
		})
		UiKit.round(stand, 999)
		local edge = stroke(stand, C.Gold, 1, 2)
		task.delay(0.15 * i, function()
			if edge.Parent then
				tween(edge, 0.6, { Transparency = spec[3] })
			end
		end)
	end

	-- Everything sits on one board, scaled to fit the screen. A short (phone)
	-- screen's cards are shorter (a shorter window, without what the kaiju is
	-- like) and drop the headline, so they come out bigger.
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	local short = viewport ~= nil and viewport.Y > 0 and viewport.Y < 480
	local winH = if short then SHORT_WIN_H else WIN_H
	local cell = if short then SHORT_CELL else CELL
	-- (Down a card: the rarity under the window, the name, its stats, what
	-- it's like, its moves.)
	local captionY = WIN_Y + winH + 32
	local nameY = captionY + 20
	local statsY = nameY + 32
	local aboutY = statsY + 20
	local movesY = if short then statsY + 22 else aboutY + 34
	local cardH = movesY + 3 * 20 + 14
	local goY = TOP + cardH + 14
	local boardH = goY + 56
	local board = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BOARD_W, boardH),
		BackgroundTransparency = 1,
		ZIndex = 41,
	})
	local fitScale = new("UIScale", { Scale = 1 }, board)
	local kicker = label(board, "STARTER ROLL  ·  YOUR KAIJU", 14, C.Gold, Enum.Font.GothamBlack)
	kicker.TextXAlignment, kicker.ZIndex = Enum.TextXAlignment.Center, 42
	kicker.Size = UDim2.new(1, 0, 0, 18)
	local title = label(board, "ROLLING YOUR KAIJU", 40, C.Text, Enum.Font.GothamBlack)
	title.TextXAlignment, title.ZIndex = Enum.TextXAlignment.Center, 42
	title.Position, title.Size = UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 46)
	-- (A short screen drops the headline, and the cards move up into its place.)
	local function fit()
		local size = shade.AbsoluteSize - Vector2.new(24, 16)
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local low = size.Y < 480
		kicker.Visible, title.Visible = not low, not low
		local scale = math.min(1.1, size.X / (BOARD_W + 40), size.Y / (if low then boardH - TOP + 10 else boardH + 20))
		fitScale.Scale = scale
		board.Position = UDim2.new(0.5, 0, 0.5, if low then -TOP / 2 * scale else 0)
	end
	fit()
	table.insert(connections, shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))

	-- The cards ----------------------------------------------------------------------------------
	local rng = Random.new()
	local cards, effects = {}, {}
	local left0 = (BOARD_W - (#rolls * STEP - (STEP - CARD_W))) / 2
	for index, entry in rolls do
		local species = Kaiju.species(entry.Species)
		local soul = entry.Soul
		local tier = (soul and soul.Tier) or "Common"
		local element = entry.Element
		local color = elementColor(element)
		local tierColor = GemConfig.TierColors[tier] or C.Text
		local x = left0 + (index - 1) * STEP
		local card = frame(board, {
			Name = "KaijuRollCard",
			Position = UDim2.fromOffset(x, TOP + 40),
			Size = UDim2.fromOffset(CARD_W, cardH),
			BackgroundColor3 = C.Card,
			BackgroundTransparency = 1,
			ZIndex = 42,
		})
		UiKit.round(card, 12)
		local cardGradient =
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Gold:Lerp(C.Card, 0.86), C.Ink) }, card)
		local edge = stroke(card, C.Gold, 0.75, 1)
		local punch = new("UIScale", { Scale = 1 }, card)
		task.delay(0.1 + index * 0.09, function()
			if card.Parent then
				tween(
					card,
					0.35,
					{ Position = UDim2.fromOffset(x, TOP), BackgroundTransparency = 0 },
					Enum.EasingStyle.Back
				)
			end
		end)

		-- Header: which kaiju, and (once it's out) its kind and level.
		local cap, recolor = keycap(card, tostring(index), C.Gold, 44)
		cap.Position = UDim2.fromOffset(16, 14)
		local which = label(card, string.format("KAIJU %d", index), 18, C.Gold, Enum.Font.GothamBlack)
		which.Position, which.Size = UDim2.fromOffset(72, 16), UDim2.new(1, -84, 0, 22)
		local kind = label(card, "ROLLING", 11, C.Dim, Enum.Font.GothamBold)
		kind.Position, kind.Size = UDim2.fromOffset(72, 40), UDim2.new(1, -84, 0, 14)

		-- The reel's window: a clipped frame with rounded corners (3D views
		-- don't draw inside a CanvasGroup), its stage behind the reel: the
		-- night, a pool of light on the floor and, once yours is out, its
		-- element's sparks rising.
		local well = frame(card, {
			Name = "ReelWindow",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, WIN_Y),
			Size = UDim2.fromOffset(WIN_W, winH),
			BackgroundColor3 = C.Ink,
			ClipsDescendants = true,
			ZIndex = 44,
		})
		UiKit.round(well, ROUND)
		local wellEdge = stroke(well, C.Gold, 0.6, 2)
		local back = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 44 })
		UiKit.round(back, ROUND)
		local backdrop =
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Line:Lerp(C.Ink, 0.5), C.Ink) }, back)
		local pool = frame(well, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.84),
			Size = UDim2.fromScale(0.95, 0.2),
			BackgroundColor3 = C.Line,
			BackgroundTransparency = 0.75,
			ZIndex = 44,
		})
		UiKit.round(pool, 999)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, pool)

		-- The strip runs downward and stops with cell 2, yours, in the middle
		-- of the window (cell 0 sits above it for the spring-back). The others
		-- take turns among three other kaiju, so the three in sight are never
		-- the same one twice; each lies on a glow of a rarity rolled at the odds.
		local decoys, used = {}, { [entry.Species .. "/" .. element] = true }
		for _ = 1, 60 do
			if #decoys >= 3 then
				break
			end
			local s = Kaiju.Order[rng:NextInteger(1, #Kaiju.Order)]
			local e = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
			if not used[s .. "/" .. e] then
				used[s .. "/" .. e] = true
				table.insert(decoys, { Species = s, Element = e })
			end
		end
		local count = 14 + index * 5
		local strip =
			frame(well, { BackgroundTransparency = 1, Size = UDim2.fromOffset(WIN_W, cell * count), ZIndex = 45 })
		local symbols, cells, glows = {}, {}, {}
		for n = 0, count do
			local slot = frame(strip, {
				Name = "ReelCell",
				Position = UDim2.fromOffset(0, (n - 1) * cell),
				Size = UDim2.fromOffset(WIN_W, cell),
				BackgroundTransparency = 1,
				ZIndex = 45,
			})
			cells[n] = slot
			local pick = if n == 2 then { Species = entry.Species, Element = element } else decoys[n % #decoys + 1]
			if pick then
				local rolled = if n == 2 then tier else GemRoller.rollRarity(rng)
				local discs = rarityGlow(slot, rolled, cell)
				if n == 2 then
					glows = discs
				end
				symbols[n] = { Key = pick.Species .. "/" .. pick.Element, Pick = pick, Tier = rolled }
			end
		end
		local function stripY(n: number): number
			return winH / 2 - cell / 2 - (n - 1) * cell
		end
		strip.Position = UDim2.fromOffset(0, stripY(count))
		-- Each kaiju on the reel is built once, before the spin (yours and the
		-- three others), and its view moves to whichever cell in sight shows it.
		local staged = {}
		for _, pick in { { Species = entry.Species, Element = element }, decoys[1], decoys[2], decoys[3] } do
			if pick and not staged[pick.Species .. "/" .. pick.Element] then
				staged[pick.Species .. "/" .. pick.Element] = stage(pick.Species, pick.Element, WIN_W, winH)
			end
		end
		local mine = staged[entry.Species .. "/" .. element]
		-- Depth: the window darkens toward its top and bottom.
		local depth = frame(well, { BackgroundColor3 = C.Ink, Size = UDim2.fromScale(1, 1), ZIndex = 47 })
		UiKit.round(depth, ROUND)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.25, 1),
				NumberSequenceKeypoint.new(0.75, 1),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}, depth)
		local sparks = {}
		for i = 1, 9 do
			local spark = frame(well, {
				Name = "Spark",
				Size = UDim2.fromOffset(if i % 3 == 0 then 4 else 3, if i % 3 == 0 then 4 else 3),
				BackgroundColor3 = color:Lerp(C.Text, if i % 2 == 0 then 0.5 else 0.1),
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = 48,
			})
			UiKit.round(spark, 2)
			sparks[i] = spark
		end
		local flash = frame(well, {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 48,
		})
		UiKit.round(flash, ROUND)

		-- Its E move's badge, rising out of it once it's down.
		local eMove = Kaiju.moveInfo((Kaiju.kitMove(entry.Species, "E", Kaiju.StarterLevel)))
		local badge = frame(card, {
			Name = "MoveBadge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, WIN_Y + winH / 2),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = C.Ink,
			Visible = false,
			ZIndex = 49,
		})
		UiKit.round(badge, 12)
		stroke(badge, color, 0, 3)
		local badgeScale = new("UIScale", { Scale = 0.2 }, badge)
		local art = frame(badge, {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = C.Ink,
			ZIndex = 50,
		})
		UiKit.round(art, 9)
		local drewArt, artDrawn = pcall(SurgeIcons.apply, art, eMove, color)
		if not (drewArt and artDrawn) then
			local word = label(art, "E", 26, color, Enum.Font.GothamBlack)
			word.Size, word.TextXAlignment, word.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 51
		end

		-- Under the window: the one going past, then yours; then its name,
		-- its stats, what it's like and its moves.
		local caption = label(card, "", 12, C.Faint, Enum.Font.GothamBlack)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.Position, caption.Size = UDim2.fromOffset(12, captionY), UDim2.new(1, -24, 0, 16)
		local name = label(card, "? ? ?", 24, C.Faint, Enum.Font.GothamBlack)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextScaled, name.TextTruncate = true, Enum.TextTruncate.None
		new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 14 }, name)
		name.Position, name.Size = UDim2.fromOffset(12, nameY), UDim2.new(1, -24, 0, 30)
		local startStats = Kaiju.stats(entry.Species, Kaiju.StarterLevel, tier)
		local stats = label(card, "", 12, color, Enum.Font.GothamBlack)
		stats.TextXAlignment = Enum.TextXAlignment.Center
		stats.Position, stats.Size = UDim2.fromOffset(12, statsY), UDim2.new(1, -24, 0, 16)
		local about = label(card, "", 12, C.Dim, Enum.Font.GothamMedium)
		about.TextXAlignment, about.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Top
		about.TextWrapped = true
		about.Position, about.Size = UDim2.fromOffset(16, aboutY), UDim2.new(1, -32, 0, 30)
		about.Visible = not short
		local moves = frame(card, {
			Name = "Moves",
			Position = UDim2.fromOffset(16, movesY),
			Size = UDim2.new(1, -32, 0, 3 * 20),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 45,
		})
		UiKit.list(moves, 2)
		-- (Till it's out, three blank move slots wait where its moves go.)
		local pending = frame(card, {
			Name = "Pending",
			Position = UDim2.fromOffset(16, movesY),
			Size = UDim2.new(1, -32, 0, 3 * 20),
			BackgroundTransparency = 1,
			ZIndex = 45,
		})
		UiKit.list(pending, 2)
		for order, key in { "E", "Q", "R" } do
			local row = frame(pending, {
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundColor3 = C.Panel,
				BackgroundTransparency = 0.4,
				ZIndex = 45,
			})
			UiKit.round(row, 6)
			local letter = label(row, key, 11, C.Faint, Enum.Font.GothamBlack)
			letter.Position, letter.Size, letter.ZIndex = UDim2.fromOffset(24, 0), UDim2.new(0, 12, 1, 0), 46
			local word = label(row, "? ? ?", 11, C.Faint, Enum.Font.GothamBlack)
			word.Position, word.Size, word.ZIndex = UDim2.fromOffset(38, 0), UDim2.new(1, -96, 1, 0), 46
		end
		for order, key in { "E", "Q", "R" } do
			local id, awake = Kaiju.kitMove(entry.Species, key, Kaiju.StarterLevel)
			local row = frame(moves, {
				Name = "Move" .. key,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundColor3 = if awake then color:Lerp(C.Ink, 0.8) else C.Panel,
				ZIndex = 45,
			})
			UiKit.round(row, 6)
			-- (The move's icon, dimmed while it sleeps; its key beside it.)
			local chip = frame(row, {
				Position = UDim2.fromOffset(2, 1),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = if awake then color else C.Ink,
				ZIndex = 46,
			})
			UiKit.round(chip, 4)
			local move = Kaiju.moveInfo(id)
			local fine, iconed = pcall(SurgeIcons.apply, chip, move, color)
			if fine and iconed then
				pcall(SurgeIcons.dim, chip, not awake)
			end
			local letter = label(row, key, 11, if awake then color else C.Faint, Enum.Font.GothamBlack)
			letter.Position, letter.Size, letter.ZIndex = UDim2.fromOffset(24, 0), UDim2.new(0, 12, 1, 0), 46
			local word =
				label(row, string.upper(moveName(id)), 11, if awake then C.Text else C.Dim, Enum.Font.GothamBlack)
			word.Position, word.Size, word.ZIndex = UDim2.fromOffset(38, 0), UDim2.new(1, -96, 1, 0), 46
			local note = label(
				row,
				if awake then "READY" else string.format("LV %d", Kaiju.MoveLevels[key] or 1),
				10,
				if awake then C.Good else C.Faint,
				Enum.Font.GothamBlack
			)
			note.AnchorPoint, note.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
			note.Position, note.Size, note.ZIndex = UDim2.new(1, -8, 0, 0), UDim2.new(0, 56, 1, 0), 46
		end

		local effect = { Effect = CardFX.create(card), Element = element, Live = false }
		CardFX.update(effect.Effect, nil, 0)
		table.insert(effects, effect)

		local item = {
			Phase = "Sealed",
			Strip = strip,
			Symbols = symbols,
			Cells = cells,
			Staged = staged,
			Mine = mine,
			Final = stripY(2),
			Caption = caption,
			WellEdge = wellEdge,
			Sparks = sparks,
			Glows = glows,
		}
		-- Beat 1: it stops on yours, with a flash in its Gemsoul's rarity,
		-- and drops onto its spot.
		function item.open(quick: boolean)
			if item.Phase ~= "Sealed" then
				return
			end
			item.Phase = "Out"
			item.Spinning = false
			if item.Spin then
				item.Spin:Cancel()
			end
			strip.Position = UDim2.fromOffset(0, item.Final)
			-- Only yours stays in the window, on a stage of its element.
			for n, slot in cells do
				slot.Visible = n == 2
			end
			for key, s in staged do
				if s ~= mine then
					s.View:Destroy()
					staged[key] = nil
				end
			end
			mine.View.Parent = cells[2]
			item.LandedAt = os.clock()
			backdrop.Color = ColorSequence.new(color:Lerp(C.Ink, 0.62), C.Ink)
			pool.BackgroundColor3, pool.BackgroundTransparency = color, 0.5
			wellEdge.Color, wellEdge.Transparency = tierColor, 0
			flash.BackgroundTransparency = 0
			tween(flash, 0.4, { BackgroundTransparency = 1 })
			punch.Scale = 1.07
			tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			caption.Text = string.format(
				"%s GEMSOUL  ·  %s",
				string.upper(GemConfig.elementName(element)),
				string.upper(GemConfig.TierLabels[tier] or tier)
			)
			caption.TextColor3 = tierColor
			recolor(color)
			which.TextColor3 = color
			kind.Text = string.format("%s  ·  LV %d", string.upper(species and species.Role or ""), Kaiju.StarterLevel)
			if not quick then
				LotterySound.play("Lock")
			end
		end
		-- Beat 2: its E move rises out of it, and the card fills in.
		function item.reveal(quick: boolean)
			if item.Phase == "Ready" then
				return
			end
			item.open(true)
			item.Phase = "Ready"
			badge.Visible = eMove ~= nil
			local final = UDim2.new(0.5, 0, 0, WIN_Y + winH - 4)
			if quick then
				badge.Position, badgeScale.Scale = final, 1
			else
				tween(badge, 0.4, { Position = final }, Enum.EasingStyle.Back)
				tween(badgeScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				LotterySound.reveal(RANKS[tier] or 1)
			end
			caption.Position = UDim2.fromOffset(12, captionY + 4)
			name.Text, name.TextColor3 = string.upper(Kaiju.title(entry)), C.Text
			stats.Text = if startStats
				then string.format(
					"%d HP   ·   %d DMG   ·   %d SPD",
					math.floor(startStats.Health + 0.5),
					math.floor(startStats.Damage + 0.5),
					math.floor(startStats.Speed + 0.5)
				)
				else ""
			about.Text = species and species.Blurb or ""
			moves.Visible, pending.Visible = true, false
			for _, spark in sparks do
				spark.Visible = true
			end
			edge.Color, edge.Transparency, edge.Thickness = color, 0.1, 2
			cardGradient.Color = ColorSequence.new(color:Lerp(C.Card, 0.82), C.Ink)
			effect.Live = true
		end
		cards[index] = item
	end

	-- The call to action, once every kaiju is out: START. It starts on its
	-- own too, the bar along its foot filling till then.
	local go = new("TextButton", {
		Name = "Start",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, goY),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = C.Gold,
		Text = "START   ›",
		TextColor3 = C.Ink,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = true,
		Visible = false,
		ZIndex = 44,
	}, board)
	UiKit.round(go, 10)
	local goScale = new("UIScale", { Scale = 0.6 }, go)
	local fill = frame(go, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -5),
		Size = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.55,
		ZIndex = 45,
	})

	-- Starting: they're yours, and on to whatever's next.
	local claiming, claimed = false, false
	local function claim()
		if claiming or claimed then
			return
		end
		claiming = true
		go.Text = "STARTING…"
		local reply = GemClient.request("KaijuRollClaim")
		claiming = false
		if not screen.Parent then
			return
		end
		if not reply.Ok then
			go.Text = "START   ›"
			UiKit.toast(reply.Message or "Couldn't reach the server. Try again.")
			return
		end
		claimed = true
		LotterySound.play("Attune")
		close()
		done()
	end
	local finished = false
	local function allOut()
		if finished then
			return
		end
		finished = true
		title.Text = "YOUR KAIJU ARE LOCKED IN"
		LotterySound.play("Attune")
		go.Visible = true
		tween(goScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(fill, AUTO, { Size = UDim2.new(1, -20, 0, 4) }, Enum.EasingStyle.Linear)
		task.delay(AUTO, function()
			if screen.Parent then
				claim()
			end
		end)
	end

	-- Each frame: the kaiju in a window turn as they pass (the three in sight
	-- are the built ones, moved to their cells), the one passing is named
	-- under it in its rarity's colour, and each that passes clicks. Once
	-- yours is down it sways on the spot facing you, its rarity's glow
	-- breathing and its element's sparks rising.
	local born = os.clock()
	local lastTick = 0
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local t = now - born
			for _, item in cards do
				if item.Phase == "Sealed" then
					local middle = math.floor((winH / 2 - item.Strip.Position.Y.Offset) / cell + 1)
					if middle ~= item.LastCell then
						item.LastCell = middle
						if now - lastTick > 0.06 and item.Spinning then
							lastTick = now
							LotterySound.play("Tick")
						end
						local passing = item.Symbols[middle]
						if passing then
							local tierColor = GemConfig.TierColors[passing.Tier] or C.Dim
							item.Caption.Text = string.format(
								"%s  ·  %s",
								string.upper(Kaiju.title(passing.Pick)),
								string.upper(GemConfig.TierLabels[passing.Tier] or passing.Tier)
							)
							item.Caption.TextColor3 = tierColor
							item.WellEdge.Color = tierColor
						end
						-- (Each built kaiju into the cell in sight that shows it.)
						local placed = {}
						for n = middle - 1, middle + 1 do
							local symbol = item.Symbols[n]
							local s = symbol and item.Staged[symbol.Key]
							if s then
								s.View.Parent = item.Cells[n]
								s.Cell = n
								placed[s] = true
							end
						end
						for _, s in item.Staged do
							if not placed[s] then
								s.View.Parent = nil
							end
						end
					end
					for _, s in item.Staged do
						if s.View.Parent then
							pose(s, t * 1.6 + (s.Cell or 0) * 0.9)
						end
					end
				else
					-- (Dropped from a little above, a settle, then a slow sway and breath.)
					local since = now - item.LandedAt
					local drop = math.clamp(since / 0.32, 0, 1)
					local reach = item.Mine.Reach
					pose(
						item.Mine,
						math.sin(since * 0.9) * 0.45,
						reach * 0.22 * (1 - drop) ^ 3 + math.sin(since * 2.2) * reach * 0.008
					)
					if item.Phase == "Ready" then
						local breath = 1 + math.sin(since * 2.4) * 0.05
						for i, disc in item.Glows do
							local size = math.floor(cell * GLOW_SIZES[i] * breath)
							disc.Size = UDim2.fromOffset(size, size)
						end
						for i, spark in item.Sparks do
							local phase = (since * 0.32 + i / #item.Sparks) % 1
							spark.Position = UDim2.fromScale(0.12 + ((i * 37) % 76) / 100, 0.92 - phase * 0.82)
							spark.BackgroundTransparency = 0.15 + phase * 0.85
						end
					end
				end
			end
			for _, effect in effects do
				if effect.Live then
					CardFX.update(effect.Effect, effect.Element, t)
				end
			end
		end)
	)

	-- All three spin; the first stops, then the next, then the last, each on
	-- yours, which lands and lets its E move out.
	for index, item in cards do
		local spin = 1.2 + (index - 1) * 0.7
		task.delay(0.4, function()
			if screen.Parent and item.Phase == "Sealed" then
				item.Spinning = true
				-- Runs just past yours, then springs back onto it.
				item.Spin = tween(
					item.Strip,
					spin,
					{ Position = UDim2.fromOffset(0, item.Final + math.floor(cell * 0.25)) },
					Enum.EasingStyle.Quart
				)
				task.delay(spin, function()
					if item.Phase == "Sealed" then
						item.Spin = tween(
							item.Strip,
							0.18,
							{ Position = UDim2.fromOffset(0, item.Final) },
							Enum.EasingStyle.Back
						)
					end
				end)
			end
		end)
		local openAt = 0.4 + spin + 0.18
		task.delay(openAt, function()
			if screen.Parent then
				item.open(false)
			end
		end)
		task.delay(openAt + 0.5, function()
			if screen.Parent then
				item.reveal(false)
				if index == #cards then
					task.delay(0.35, allOut)
				end
			end
		end)
	end
	-- Click during the roll: they all land at once.
	table.insert(
		connections,
		shade.Activated:Connect(function()
			if finished then
				return
			end
			for _, item in cards do
				item.reveal(true)
			end
			LotterySound.play("Lock")
			allOut()
		end)
	)
	table.insert(
		connections,
		go.Activated:Connect(function()
			task.spawn(claim)
		end)
	)
	table.insert(
		connections,
		screen.Destroying:Connect(function()
			gui = nil
		end)
	)
end

return KaijuRoll
