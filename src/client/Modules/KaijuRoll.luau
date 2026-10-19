--[[
	The kaiju starter roll (KaijuServer; see docs/kaiju.md): a full-screen
	reveal of the three kaiju you start with, like the intro's gem roll. A
	card for each, its stage a reel of kaiju (every kind, every element)
	turning past under a spotlight and slowing till it lands on yours: a
	flash in its Gemsoul's rarity, then its name and kind, its health,
	damage and speed (bars against the toughest, hardest-hitting and
	quickest of the kinds), and its three moves with their icons (E from the
	start, Q at level 5, R at level 10). Click to land them all at once. MEET
	YOUR TEAM claims them, and they're your team; the server keeps the roll
	till then, so leaving doesn't reroll it.

	  KaijuRoll.play(after)   the roll you're owed, then after() (at once if
	                          there's none): in the intro after the gem roll,
	                          and once in the Outpost for a player from before
	  KaijuRoll.showing()     true while it's up
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
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
}
local RANKS = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local BOARD_W, BOARD_H = 900, 650
local CARD_W, CARD_H, GAP = 284, 470, 16
local VIEW_H = 200
local SHORT_VIEW_H = 150 -- the stage on a short (phone) screen, so the cards scale up
local LANDS = { 2.1, 3.0, 3.9 } -- seconds till each card lands
local AUTO = 20 -- seconds till MEET YOUR TEAM goes on its own
local DECOYS = 3 -- other kaiju on each reel

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or C.Gold
end

-- The most any kind starts with (at the best Gemsoul), for the stat bars.
local TOP_STATS = { Health = 1, Damage = 1, Speed = 1 }
for id in Kaiju.Species do
	local stats = Kaiju.stats(id, Kaiju.StarterLevel, "Legendary")
	for key in TOP_STATS do
		TOP_STATS[key] = math.max(TOP_STATS[key], stats[key])
	end
end
local STAT_ROWS = { { "Health", "HEALTH" }, { "Damage", "DAMAGE" }, { "Speed", "SPEED" } }

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
		ZIndex = 3,
	}, parent)
end

local function tween(object: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		:Play()
end

local function stroke(parent: Instance, color: Color3, transparency: number?, thickness: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	}, parent)
end

-- A kaiju for a card's window: built once, framed from the front quarter,
-- turned about its own middle.
local function stage(species: string, element: string)
	local model = KaijuModels.build(species, element)
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y * 1.25, size.Z)
	return {
		Model = model,
		Center = cf.Position,
		Rest = model:GetPivot(),
		Camera = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.95, reach * 0.42, -reach * 1.3), cf.Position),
		Species = species,
		Element = element,
	}
end

local function turn(staged, angle: number)
	local center = CFrame.new(staged.Center)
	staged.Model:PivotTo(center * CFrame.Angles(0, angle, 0) * center:Inverse() * staged.Rest)
end

local function moveName(id: string?): string
	local move = id and GemTraits.Moves[id]
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
	}, screen)
	new("UIGradient", { Rotation = 115, Color = ColorSequence.new(C.Ink, Color3.fromRGB(16, 22, 42)) }, shade)
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
		LotterySound.hum(false)
		screen:Destroy()
		gui = nil
	end

	-- Stars, and a glow on the floor in the colour of each kaiju's element.
	for i = 1, 22 do
		frame(shade, {
			Position = UDim2.fromScale(((i * 37) % 97) / 96, ((i * 23) % 47) / 100),
			Size = UDim2.fromOffset(if i % 4 == 0 then 2 else 1, if i % 4 == 0 then 2 else 1),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = if i % 4 == 0 then 0.5 else 0.72,
		})
	end
	local floorGlow = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.05),
		Size = UDim2.fromScale(1.1, 0.4),
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 1,
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
			NumberSequenceKeypoint.new(0, 0.95),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	}, floorGlow)
	tween(floorGlow, 0.8, { BackgroundTransparency = 0 })

	-- Everything sits on one board, scaled to fit the screen (a short one's
	-- stages lower, so the cards come out bigger).
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	local stageH = if viewport and viewport.Y > 0 and viewport.Y < 480 then SHORT_VIEW_H else VIEW_H
	local cardH, boardH = CARD_H - (VIEW_H - stageH), BOARD_H - (VIEW_H - stageH)
	local board = frame(shade, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BOARD_W, boardH),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	local fitScale = new("UIScale", { Scale = 1 }, board)
	local kicker = label(board, "STARTER ROLL  ·  YOUR KAIJU", 14, C.Gold, Enum.Font.GothamBlack)
	kicker.TextXAlignment = Enum.TextXAlignment.Center
	kicker.Size = UDim2.new(1, 0, 0, 18)
	local title = label(board, "ROLLING YOUR KAIJU", 40, C.Text, Enum.Font.GothamBlack)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position, title.Size = UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 46)
	local subtitle = label(
		board,
		if #rolls >= Kaiju.StarterTeam
			then "Three kaiju to fight beside you, each with its own Gemsoul."
			else "Your team grows to three: each kaiju comes with its own Gemsoul.",
		15,
		C.Dim,
		Enum.Font.GothamMedium
	)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.Position, subtitle.Size = UDim2.fromOffset(0, 68), UDim2.new(1, 0, 0, 20)
	local TOP = 100 -- where the cards start
	-- Short (phone) screens drop the headline, so the cards get the height.
	local function fit()
		local size = shade.AbsoluteSize - Vector2.new(24, 16)
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local short = size.Y < 480
		kicker.Visible, title.Visible, subtitle.Visible = not short, not short, not short
		local scale =
			math.min(1.1, size.X / (BOARD_W + 40), size.Y / (if short then boardH - TOP + 16 else boardH + 30))
		fitScale.Scale = scale
		board.Position = UDim2.new(0.5, 0, 0.5, if short then -(TOP - 8) / 2 * scale else 0)
	end
	fit()
	table.insert(connections, shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))

	-- The cards ----------------------------------------------------------------------------------
	local rng = Random.new()
	local cards = {}
	local width = #rolls * CARD_W + (#rolls - 1) * GAP
	local left0 = (BOARD_W - width) / 2
	for index, entry in rolls do
		local species = Kaiju.species(entry.Species)
		local soul = entry.Soul
		local tier = (soul and soul.Tier) or "Common"
		local color = elementColor(entry.Element)
		local tierColor = GemConfig.TierColors[tier] or C.Text
		local x = left0 + (index - 1) * (CARD_W + GAP)
		local card = frame(board, {
			Name = "KaijuRollCard",
			Position = UDim2.fromOffset(x, TOP + 40),
			Size = UDim2.fromOffset(CARD_W, cardH),
			BackgroundColor3 = C.Card,
			BackgroundTransparency = 1,
			ZIndex = 2,
		})
		UiKit.round(card, 14)
		local cardGradient =
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Line:Lerp(C.Card, 0.5), C.Ink) }, card)
		local edge = stroke(card, C.Line, 0.4, 1)
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

		-- Header: which one it is, and (once it lands) its Gemsoul's rarity.
		local number = label(card, string.format("KAIJU %d", index), 12, C.Faint, Enum.Font.GothamBlack)
		number.Position, number.Size = UDim2.fromOffset(16, 14), UDim2.new(0.4, 0, 0, 18)
		local pill = frame(card, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(150, 22),
			BackgroundColor3 = tierColor:Lerp(C.Ink, 0.7),
			Visible = false,
			ZIndex = 3,
		})
		UiKit.round(pill, 11)
		stroke(pill, tierColor, 0.2, 1)
		local pillText = label(
			pill,
			string.upper(GemConfig.TierLabels[tier] or tier) .. " GEMSOUL",
			11,
			tierColor,
			Enum.Font.GothamBlack
		)
		pillText.Size, pillText.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
		pillText.ZIndex = 4

		-- The stage: a spotlit backdrop in the element passing by, a glowing
		-- floor under the kaiju, and its element named in the corner.
		local window = frame(card, {
			Name = "Window",
			Position = UDim2.fromOffset(12, 40),
			Size = UDim2.new(1, -24, 0, stageH),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			ZIndex = 3,
		})
		UiKit.round(window, 12)
		local backdrop = new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(C.Line:Lerp(C.Ink, 0.4), C.Ink),
		}, window)
		local windowEdge = stroke(window, C.Line, 0.3, 2)
		local glow = frame(window, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.95),
			BackgroundColor3 = C.Line,
			BackgroundTransparency = 0.85,
			ZIndex = 3,
		})
		UiKit.round(glow, 999)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, glow)
		-- (The floor it stands on: a pool of light and its bright core.)
		local fadeEnds = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		local floorPool = frame(window, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.9, 0.16),
			BackgroundColor3 = C.Line,
			BackgroundTransparency = 0.7,
			ZIndex = 3,
		})
		UiKit.round(floorPool, 999)
		new("UIGradient", { Transparency = fadeEnds }, floorPool)
		local floorCore = frame(window, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.5, 0.06),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = 0.85,
			ZIndex = 3,
		})
		UiKit.round(floorCore, 999)
		new("UIGradient", { Transparency = fadeEnds }, floorCore)
		local elementPill = frame(window, {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(86, 18),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.3,
			Visible = false,
			ZIndex = 6,
		})
		UiKit.round(elementPill, 9)
		local elementText = label(
			elementPill,
			string.upper(GemConfig.ElementLabels[entry.Element] or entry.Element or ""),
			10,
			color,
			Enum.Font.GothamBlack
		)
		elementText.Size, elementText.TextXAlignment, elementText.ZIndex =
			UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 7
		local view = new("ViewportFrame", {
			Name = "KaijuView",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(150, 156, 176),
			LightColor = Color3.fromRGB(255, 246, 232),
			LightDirection = Vector3.new(-0.5, -0.8, 0.7),
			ZIndex = 4,
		}, window)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 38
		camera.Parent = view
		view.CurrentCamera = camera
		local flash = frame(window, {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
		})
		UiKit.round(flash, 12)

		-- Under the stage: the one going past, then yours.
		local name = label(card, "", 22, C.Dim, Enum.Font.GothamBlack)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position, name.Size = UDim2.fromOffset(12, 48 + stageH), UDim2.new(1, -24, 0, 26)
		UiKit.fit(name)
		local tag = label(card, "", 12, C.Faint, Enum.Font.GothamBold)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.Position, tag.Size = UDim2.fromOffset(12, 74 + stageH), UDim2.new(1, -24, 0, 16)

		-- Its health, damage and speed: bars against the best of the kinds.
		local statsBox = frame(card, {
			Position = UDim2.fromOffset(16, 98 + stageH),
			Size = UDim2.new(1, -32, 0, 56),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 3,
		})
		local startStats = Kaiju.stats(entry.Species, Kaiju.StarterLevel, tier)
		local statFills = {}
		for row, stat in STAT_ROWS do
			local y = (row - 1) * 19
			local word = label(statsBox, stat[2], 10, C.Dim, Enum.Font.GothamBlack)
			word.Position, word.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(64, 16)
			local back = frame(statsBox, {
				Position = UDim2.fromOffset(66, y + 5),
				Size = UDim2.new(1, -112, 0, 6),
				BackgroundColor3 = C.Panel,
				ZIndex = 3,
			})
			UiKit.round(back, 3)
			local fill = frame(back, {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = color,
				ZIndex = 4,
			})
			UiKit.round(fill, 3)
			local value = startStats and startStats[stat[1]] or 0
			local number = label(statsBox, tostring(math.floor(value + 0.5)), 12, C.Text, Enum.Font.GothamBlack)
			number.AnchorPoint, number.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
			number.Position, number.Size = UDim2.new(1, 0, 0, y), UDim2.fromOffset(42, 16)
			statFills[row] = { Fill = fill, Share = math.clamp(value / TOP_STATS[stat[1]], 0.08, 1) }
		end

		-- Its moves, from its Gemsoul, with their icons: E now, Q and R as it levels.
		local moves = frame(card, {
			Position = UDim2.fromOffset(12, 160 + stageH),
			Size = UDim2.new(1, -24, 0, 98),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 3,
		})
		UiKit.list(moves, 4)
		for order, key in { "E", "Q", "R" } do
			local id, awake = Kaiju.move(soul, key, Kaiju.StarterLevel)
			local row = frame(moves, {
				Name = "Move" .. key,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = if awake then color:Lerp(C.Ink, 0.78) else C.Panel,
				ZIndex = 3,
			})
			UiKit.round(row, 8)
			stroke(row, if awake then color else C.Line, if awake then 0.45 else 0.2, 1)
			-- (The move's icon, its key on the corner; the key alone till the icons load.)
			local chip = frame(row, {
				Position = UDim2.fromOffset(4, 3),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = if awake then color else C.Ink,
				ZIndex = 4,
			})
			UiKit.round(chip, 6)
			if not awake then
				stroke(chip, C.Faint, 0, 1)
			end
			local letter = label(chip, key, 13, if awake then C.Ink else C.Faint, Enum.Font.GothamBlack)
			letter.Size, letter.TextXAlignment, letter.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 5
			local move = id and GemTraits.Moves[id]
			local ok, drawn = pcall(SurgeIcons.apply, chip, move, color)
			if ok and drawn then
				pcall(SurgeIcons.dim, chip, not awake)
				local badge = frame(chip, {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 3, 1, 3),
					Size = UDim2.fromOffset(13, 13),
					BackgroundColor3 = if awake then color else C.Ink,
					ZIndex = 6,
				})
				UiKit.round(badge, 4)
				local small = label(badge, key, 9, if awake then C.Ink else C.Faint, Enum.Font.GothamBlack)
				small.Size, small.TextXAlignment, small.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 7
				letter.Visible = false
			end
			local word = label(row, moveName(id), 13, if awake then C.Text else C.Dim, Enum.Font.GothamBold)
			word.Position, word.Size, word.ZIndex = UDim2.fromOffset(36, 0), UDim2.new(1, -100, 1, 0), 4
			local note = label(
				row,
				if awake then "READY" else string.format("LV %d", Kaiju.MoveLevels[key] or 1),
				11,
				if awake then C.Good else C.Faint,
				Enum.Font.GothamBlack
			)
			note.AnchorPoint, note.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
			note.Position, note.Size, note.ZIndex = UDim2.new(1, -10, 0, 0), UDim2.new(0, 60, 1, 0), 4
		end

		-- The reel: other kaiju (none the same as yours), built as they're needed.
		local decoys = {}
		local used = { [entry.Species .. entry.Element] = true }
		for _ = 1, 40 do
			if #decoys >= DECOYS then
				break
			end
			local s = Kaiju.Order[rng:NextInteger(1, #Kaiju.Order)]
			local e = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
			if not used[s .. e] then
				used[s .. e] = true
				table.insert(decoys, { Species = s, Element = e })
			end
		end
		-- (Yours is built now, so landing on it doesn't stall a frame.)
		local staged = { [entry.Species .. entry.Element] = stage(entry.Species, entry.Element) }
		local item = {
			Index = index,
			Entry = entry,
			Card = card,
			View = view,
			Camera = camera,
			Glow = glow,
			Name = name,
			Decoys = decoys,
			Step = 0,
			NextStep = 0,
			LandAt = LANDS[index] or (LANDS[#LANDS] + (index - #LANDS) * 0.9),
			Landed = false,
		}
		function item.show(species: string, element: string)
			local key = species .. element
			local s = staged[key]
			if not s then
				s = stage(species, element)
				staged[key] = s
			end
			if item.Shown and item.Shown ~= s then
				item.Shown.Model.Parent = nil
			end
			item.Shown = s
			s.Model.Parent = view
			camera.CFrame = s.Camera
			-- (The stage takes on the element passing by.)
			local tint = elementColor(element)
			glow.BackgroundColor3 = tint
			floorPool.BackgroundColor3 = tint
			backdrop.Color = ColorSequence.new(tint:Lerp(C.Ink, 0.84), C.Ink)
		end
		function item.land(quick: boolean)
			if item.Landed then
				return
			end
			item.Landed = true
			item.show(entry.Species, entry.Element)
			for key, s in staged do
				if key ~= entry.Species .. entry.Element then
					s.Model:Destroy()
					staged[key] = nil
				end
			end
			item.LandedAt = os.clock()
			glow.BackgroundTransparency = 0.7
			floorPool.BackgroundTransparency = 0.45
			floorCore.BackgroundTransparency = 0.55
			elementPill.Visible = true
			windowEdge.Color, windowEdge.Transparency = tierColor, 0
			edge.Color, edge.Transparency, edge.Thickness = color, 0.1, 2
			cardGradient.Color = ColorSequence.new(color:Lerp(C.Card, 0.8), C.Ink)
			flash.BackgroundTransparency = 0
			tween(flash, 0.45, { BackgroundTransparency = 1 })
			punch.Scale = 1.06
			tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			pill.Visible = true
			name.Text = string.upper(Kaiju.title(entry))
			name.TextColor3 = color:Lerp(C.Text, 0.2)
			tag.Text = string.format("%s  ·  LV %d", string.upper(species and species.Role or ""), Kaiju.StarterLevel)
			tag.TextColor3 = C.Dim
			statsBox.Visible = true
			for row, stat in statFills do
				stat.Fill.Size = UDim2.fromScale(0, 1)
				tween(stat.Fill, if quick then 0.2 else 0.5 + row * 0.12, { Size = UDim2.fromScale(stat.Share, 1) })
			end
			moves.Visible = true
			if not quick then
				LotterySound.play("Lock")
				LotterySound.reveal(RANKS[tier] or 1)
			end
		end
		cards[index] = item
	end

	-- The call to action, once they're all out.
	local go = new("TextButton", {
		Name = "MeetTeam",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP + cardH + 18),
		Size = UDim2.fromOffset(320, 50),
		BackgroundColor3 = C.Gold,
		Text = "MEET YOUR TEAM   ›",
		TextColor3 = C.Ink,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = true,
		Visible = false,
		ZIndex = 3,
	}, board)
	UiKit.round(go, 10)
	local goScale = new("UIScale", { Scale = 0.6 }, go)
	local fill = frame(go, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -5),
		Size = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.55,
		ZIndex = 4,
	})
	local hint = label(board, "Click to skip", 12, C.Faint, Enum.Font.GothamMedium)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.Position, hint.Size = UDim2.fromOffset(0, TOP + cardH + 30), UDim2.new(1, 0, 0, 16)

	-- Claiming: they join you, and on to whatever's next.
	local claiming, claimed = false, false
	local function claim()
		if claiming or claimed then
			return
		end
		claiming = true
		go.Text = "CALLING THEM…"
		local reply = GemClient.request("KaijuRollClaim")
		claiming = false
		if not screen.Parent then
			return
		end
		if not reply.Ok then
			go.Text = "MEET YOUR TEAM   ›"
			UiKit.toast(reply.Message or "Couldn't reach the server. Try again.")
			return
		end
		claimed = true
		LotterySound.play("Attune")
		close()
		done()
	end
	local function countdown(left: number)
		if claimed or claiming or not screen.Parent then
			return
		end
		if left <= 0 then
			task.spawn(claim)
			return
		end
		go.Text = string.format("MEET YOUR TEAM IN %d   ›", left)
		task.delay(1, function()
			countdown(left - 1)
		end)
	end
	local finished = false
	local function allOut()
		if finished then
			return
		end
		finished = true
		title.Text = "MEET YOUR TEAM"
		subtitle.Text = string.format(
			"E is ready now; Q wakes at level %d, R at level %d. They grow by fighting beside you and as you mine.",
			Kaiju.MoveLevels.Q,
			Kaiju.MoveLevels.R
		)
		hint.Visible = false
		LotterySound.hum(false)
		go.Visible = true
		tween(goScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(fill, AUTO, { Size = UDim2.new(1, -20, 0, 4) }, Enum.EasingStyle.Linear)
		countdown(AUTO)
	end

	-- The spin: each reel steps through its kaiju, slower and slower, then
	-- lands on yours; the first, then the next, then the last.
	local born = os.clock()
	LotterySound.play("SealBreak")
	LotterySound.hum(true, 0)
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local t = os.clock() - born
			local landed = 0
			for _, item in cards do
				if item.Landed then
					landed += 1
					-- Yours sways on the spot, facing you.
					turn(item.Shown, math.sin((os.clock() - item.LandedAt) * 0.9) * 0.45)
				elseif t >= item.LandAt then
					item.land(false)
					landed += 1
					LotterySound.hum(true, landed / #cards)
				elseif t >= item.NextStep and t > 0.35 then
					-- (Quick at first, slowing as it nears its stop.)
					local near = math.clamp(t / item.LandAt, 0, 1)
					item.NextStep = t + 0.07 + 0.42 * near ^ 3
					item.Step += 1
					local pick = item.Decoys[(item.Step - 1) % math.max(1, #item.Decoys) + 1]
					if pick then
						item.show(pick.Species, pick.Element)
						item.Name.Text = string.upper(Kaiju.title(pick))
						item.Name.TextColor3 = elementColor(pick.Element):Lerp(C.Faint, 0.35)
					end
					LotterySound.tick(near)
				end
				if not item.Landed and item.Shown then
					turn(item.Shown, t * 2.4 + item.Index)
				end
			end
			if landed == #cards then
				allOut()
			end
		end)
	)
	-- Click during the roll: they all land at once.
	table.insert(
		connections,
		shade.Activated:Connect(function()
			if finished then
				return
			end
			for _, item in cards do
				item.land(true)
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
