--[[
	Your mini kaiju on screen (KaijuServer and KaijuWilds run them; see
	docs/kaiju.md). Only in the Outpost.

	  The team strip  your team out, a tile each, the lead first (edged in
	                  gold): its portrait (the model itself), level, health,
	                  and dots for its Q, E and R, lit when ready (hollow
	                  while asleep); knocked out, when it's back. RECALL (all
	                  of them back to you for a moment) and HUNT (your kit out
	                  to fight beside them; 1 or HUNT again puts it away).
	                  Tap a tile for the panel on that kaiju. Computer:
	                  bottom left. Phone: under your level and coins, and at
	                  the top right while you hunt (the fight's foe list has
	                  the top left then).
	  TAME            beside the strip when a wild kaiju near you is down to
	                  half its health (it glows gold then: KaijuTaming): the
	                  chance now, and the tries left. It casts the tame
	                  (KaijuTaming's bar), hidden while that's under way.
	  Challenge       a wild kaiju's prompt (hold E beside it): it leaves you
	                  and your kaiju alone till you start on it, here or by
	                  hitting it while you hunt.
	  The panel       every kaiju you have: your team first (all of them
	                  fight; the first leads), then the ones at home. The one
	                  picked in full (stats, its Gemsoul's rarity, its moves
	                  and when Q and R wake) and what you can do with it:
	                  LEAD (to the front), SEND OUT (one from home, in place
	                  of one of the team you pick), FEED: stones from your
	                  pouch with the EXP each gives it (Shared.Kaiju.feedExp).
	  The roll        a player still owed starter kaiju (from before the
	                  roll, say) gets the roll here, once (KaijuRoll).
	  Wild nameplates the server's health bar over wild kaiju and moon bugs
	                  while you aren't hunting (FoeBars draws them while you are).

	  KaijuHud.start()     once, from Lobby.client
	  KaijuHud.open(id?)   the panel, on kaiju `id` (else your lead)
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local Spar = require(ReplicatedStorage.Shared.Spar)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local KaijuRoll = require(script.Parent.KaijuRoll)
local KaijuTaming = require(script.Parent.KaijuTaming)
local ChatFeed = require(script.Parent.ChatFeed)
local LoadingFlow = require(script.Parent.LoadingFlow)
local MobileLayout = require(script.Parent.MobileLayout)
local OutpostScene = require(script.Parent.OutpostScene)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuHud = {}

local INK = Color3.fromRGB(10, 12, 22)
local HEALTH = Color3.fromRGB(96, 214, 120)
local EXP = Color3.fromRGB(176, 132, 255)
local TILE_BACK = Color3.fromRGB(20, 24, 38)
local TAME_RANGE = Kaiju.Tame.Range
local KEYS = { "Q", "E", "R" }
local KEY_EVERY = { Q = Kaiju.QEvery, E = Kaiju.AbilityEvery, R = Kaiju.REvery }
local CAST_AT = { Q = "KaijuQAt", E = "KaijuAbilityAt", R = "KaijuRAt" }

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or P.Gold
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or IronUi.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function bar(parent: Instance, color: Color3): (Frame, Frame)
	local back = new("Frame", { BackgroundColor3 = Color3.fromRGB(28, 32, 46) }, parent)
	UiKit.round(back, 3)
	local fill = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) }, back)
	UiKit.round(fill, 3)
	return back, fill
end

local function smallButton(parent: Instance, text: string, color: Color3): TextButton
	local b = new("TextButton", {
		Text = text,
		TextSize = 12,
		Font = IronUi.Heading,
		TextColor3 = P.Text,
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(INK, 0.55),
	}, parent)
	UiKit.round(b, 6)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.35 }, b)
	return b
end

local function viewport(parent: Instance, props: { [string]: any }): ViewportFrame
	props.BackgroundColor3 = props.BackgroundColor3 or TILE_BACK
	props.Ambient = Color3.fromRGB(170, 170, 185)
	props.LightColor = Color3.new(1, 1, 1)
	props.LightDirection = Vector3.new(-0.4, -1, 0.6)
	return new("ViewportFrame", props, parent)
end

-- Portraits: each kaiju's model is built once per place it's shown (`key`)
-- and kept, so redrawing the panel doesn't rebuild a dozen models.
local built: { [string]: { Look: string, Model: Model } } = {}
local function modelFor(key: string, record): Model
	local look = record.Species .. "/" .. record.Element
	local entry = built[key]
	if entry and entry.Look == look then
		return entry.Model
	end
	if entry then
		entry.Model:Destroy()
	end
	local model = KaijuModels.build(record.Species, record.Element)
	built[key] = { Look = look, Model = model }
	return model
end

-- A model in a ViewportFrame, framed from the front quarter (the one there
-- before is put aside, not destroyed: it's kept for next time).
local function portrait(frame: ViewportFrame, model: Model?)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") and child ~= model then
			child.Parent = nil
		elseif child:IsA("Camera") then
			child:Destroy()
		end
	end
	if not model then
		return
	end
	model.Parent = frame
	local camera = Instance.new("Camera")
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.9, reach * 0.35, -reach * 1.25), cf.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
end

local function roster()
	local profile = GemClient.Profile
	return profile and profile.Kaiju
end

-- Your kaiju out in the world, by id.
local function petModels(): { [string]: Model }
	local out = {}
	local folder = workspace:FindFirstChild("Kaiju")
	for _, model in if folder then folder:GetChildren() else {} do
		local id = model:GetAttribute("KaijuId")
		if model:GetAttribute("KaijuOwner") == player.UserId and type(id) == "string" then
			out[id] = model
		end
	end
	return out
end

-- Seconds till a knocked-out kaiju is back (0 if it isn't down).
local function downFor(id: string): number
	local back = player:GetAttribute("KaijuDown_" .. id)
	return if type(back) == "number" then math.max(0, back - workspace:GetServerTimeNow()) else 0
end

local function healthShare(model: Model?): number
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return if humanoid then math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1) else 1
end

local function expShare(level: number, exp: number): number
	local need = Kaiju.expToNext(level)
	return if need == math.huge then 1 else math.clamp(exp / need, 0, 1)
end

-- The team strip -------------------------------------------------------------------------------------------

local gui = UiKit.gui("KaijuHud", 6)
gui.Enabled = false

local card = new("Frame", {
	Name = "KaijuCard",
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.12,
	Size = UDim2.fromOffset(300, 62),
}, gui)
UiKit.round(card, 10)
new("UIStroke", { Color = P.Edge, Thickness = 1.2, Transparency = 0.2 }, card)

local tiles = {}
for slot = 1, #Kaiju.SlotLevels do
	local button = new("TextButton", {
		Name = "KaijuTile" .. slot,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = TILE_BACK,
		Visible = false,
	}, card)
	UiKit.round(button, 8)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, button)
	local view = viewport(button, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	-- Its level, top left.
	local levelBack = new("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(30, 13),
		ZIndex = 3,
	}, button)
	UiKit.round(levelBack, 4)
	local level = label(levelBack, "", 9, P.Text, IronUi.Bold)
	level.Size, level.TextXAlignment, level.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
	-- Q, E and R, down the right edge.
	local dots = {}
	for i, key in KEYS do
		local dot = new("Frame", {
			Name = "Key" .. key,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4 + (i - 1) * 9),
			Size = UDim2.fromOffset(7, 7),
			BackgroundColor3 = P.Gold,
			ZIndex = 3,
		}, button)
		UiKit.round(dot, 4)
		dots[key] = { Frame = dot, Stroke = new("UIStroke", { Color = P.Gold, Thickness = 1 }, dot) }
	end
	local healthBack, healthFill = bar(button, HEALTH)
	healthBack.AnchorPoint = Vector2.new(0, 1)
	healthBack.Position, healthBack.Size = UDim2.new(0, 4, 1, -4), UDim2.new(1, -8, 0, 4)
	healthBack.ZIndex, healthFill.ZIndex = 3, 3
	-- Knocked out: a veil with when it's back.
	local veil = new("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
	}, button)
	UiKit.round(veil, 8)
	local veilText = label(veil, "", 10, P.Bad:Lerp(P.Text, 0.3), IronUi.Bold)
	veilText.Size, veilText.TextXAlignment, veilText.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 6
	local tile = {
		Slot = slot,
		Button = button,
		Edge = edge,
		View = view,
		Level = level,
		Dots = dots,
		HealthFill = healthFill,
		Veil = veil,
		VeilText = veilText,
		Id = nil :: string?,
		Look = nil :: string?,
	}
	tiles[slot] = tile
	button.Activated:Connect(function()
		KaijuHud.open(tile.Id)
	end)
end

local recall = smallButton(card, "RECALL", Color3.fromRGB(120, 200, 255))
recall.AnchorPoint = Vector2.new(1, 0)
recall.Position, recall.Size = UDim2.new(1, -6, 0, 6), UDim2.fromOffset(68, 22)
local hunt = smallButton(card, "HUNT", Color3.fromRGB(255, 92, 76))
hunt.AnchorPoint = Vector2.new(1, 1)
hunt.Position, hunt.Size = UDim2.new(1, -6, 1, -6), UDim2.fromOffset(68, 22)

-- TAME: beside the strip, when there's a wild kaiju to tame.
local tame = new("TextButton", {
	Name = "Tame",
	Text = "",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(70, 52, 14),
	Size = UDim2.fromOffset(104, 60),
	Visible = false,
}, gui)
UiKit.round(tame, 10)
new("UIStroke", { Color = P.Gold, Thickness = 2 }, tame)
local tameTitle = label(tame, "TAME", 18, P.Gold, Enum.Font.GothamBlack)
tameTitle.Position, tameTitle.Size = UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 22)
tameTitle.TextXAlignment = Enum.TextXAlignment.Center
local tameOdds = label(tame, "", 11, P.Text, IronUi.Bold)
tameOdds.Position, tameOdds.Size = UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 13)
tameOdds.TextXAlignment = Enum.TextXAlignment.Center
local tameTries = label(tame, "", 10, P.Dim, IronUi.Body)
tameTries.Position, tameTries.Size = UDim2.fromOffset(0, 43), UDim2.new(1, 0, 0, 12)
tameTries.TextXAlignment = Enum.TextXAlignment.Center

-- Where the strip and TAME go: see the header.
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	local phone = UiKit.short()
	local hunting = Spar.hunting(player)
	-- (Beside the chat box's CHAT button on a small keyboard screen, while it's on.)
	local spot = MobileLayout.kaiju(UserInputService.KeyboardEnabled and not ChatFeed.Enabled)
	local w, h = if phone then spot.W else 300, if phone then spot.H else 62
	card.Size = UDim2.fromOffset(w, h)
	tame.Size = UDim2.fromOffset(if phone then spot.TameW else 104, h)
	local x, y
	if not phone then
		x, y = 24, screen.Y - 24 - h
		tame.Position = UDim2.fromOffset(x, y - h - 8)
	elseif hunting then
		x, y = screen.X - 12 - w, 12
		tame.Position = UDim2.fromOffset(screen.X - 12 - tame.Size.X.Offset, y + h + 6)
	else
		x, y = spot.X, spot.Y
		tame.Position = UDim2.fromOffset(spot.TameX, y)
	end
	card.Position = UDim2.fromOffset(x, y)
	-- The tiles share what RECALL and HUNT leave.
	local buttonW, gap = 68, if phone then 4 else 6
	local th = h - 10
	local tw = math.min(math.floor(th * 1.25), math.floor((w - 10 - buttonW - 8 - gap * (#tiles - 1)) / #tiles))
	for slot, tile in tiles do
		tile.Button.Position = UDim2.fromOffset(5 + (slot - 1) * (tw + gap), 5)
		tile.Button.Size = UDim2.fromOffset(tw, th)
	end
	recall.Size = UDim2.fromOffset(buttonW, if phone then 20 else 22)
	hunt.Size = recall.Size
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
player:GetAttributeChangedSignal("Hunt"):Connect(layout)

local function drawTile(tile, record, model: Model?, lead: boolean)
	tile.Id = record.Id
	local color = elementColor(record.Element)
	local look = record.Id .. "/" .. record.Species .. "/" .. record.Element
	if tile.Look ~= look then
		tile.Look = look
		portrait(tile.View, modelFor("hud:" .. tile.Slot, record))
	end
	tile.Edge.Color = if lead then P.Gold else color:Lerp(P.Edge, 0.35)
	tile.Edge.Thickness = if lead then 2 else 1.5
	local level = (model and model:GetAttribute("KaijuLevel")) or record.Level
	tile.Level.Text = string.format("Lv %d", level)
	local share = healthShare(model)
	tile.HealthFill.Size = UDim2.fromScale(share, 1)
	tile.HealthFill.BackgroundColor3 = if share < 0.3 then P.Bad else HEALTH
	-- Q, E and R: lit when ready, faint while recharging, hollow asleep.
	local now = workspace:GetServerTimeNow()
	for key, dot in tile.Dots do
		local _, awake = Kaiju.move(record.Soul, key, level)
		local at = model and model:GetAttribute(CAST_AT[key])
		local ready = awake and model ~= nil and (type(at) ~= "number" or now - at >= KEY_EVERY[key])
		dot.Frame.BackgroundColor3, dot.Stroke.Color = color, color
		dot.Frame.BackgroundTransparency = if ready then 0 elseif awake then 0.65 else 1
		dot.Stroke.Transparency = if awake then 0 else 0.45
	end
	local wait = downFor(record.Id)
	tile.Veil.Visible = wait > 0
	if wait > 0 then
		tile.VeilText.Text = string.format("KO %ds", math.ceil(wait))
	end
end

-- The panel -------------------------------------------------------------------------------------------------------

local W, H = 800, 480
local window = IronUi.window("KaijuPanel", 11, W, H, "K", P.Gold)
window.Title.Text = "YOUR KAIJU"
window.Subtitle.Text = "Your team fights beside you in the Outpost. Pick one to see it."
window.Close.Activated:Connect(function()
	window.Gui.Enabled = false
end)
window.Shade.Activated:Connect(function()
	window.Gui.Enabled = false
end)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 78),
	Size = UDim2.new(1, -40, 1, -96),
}, window.Panel)

-- Left: every kaiju you have, your team first.
local LIST_W = 256
local listFrame = new("ScrollingFrame", {
	Name = "KaijuList",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, LIST_W, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, body)
UiKit.list(listFrame, 6)

-- Right: the one picked, or feeding it.
local right = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(LIST_W + 14, 0),
	Size = UDim2.new(1, -(LIST_W + 14), 1, 0),
}, body)
local tabRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, right)
UiKit.list(tabRow, 8, true)

local detail = new("Frame", {
	Name = "Detail",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
}, right)
local heroView = viewport(detail, { Size = UDim2.fromOffset(168, 168) })
UiKit.round(heroView, 10)
local heroEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.2 }, heroView)
local heroGlow = new("UIGradient", { Rotation = 90 }, heroView)
local info = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(180, 0),
	Size = UDim2.new(1, -180, 0, 168),
}, detail)
local heroName = label(info, "", 20, P.Text, Enum.Font.GothamBlack)
heroName.Size = UDim2.new(1, 0, 0, 24)
UiKit.fit(heroName)
local heroTag = label(info, "", 11, P.Dim, IronUi.Bold)
heroTag.Position, heroTag.Size = UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 14)
local pill = new("Frame", {
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.fromOffset(150, 20),
	BackgroundColor3 = INK,
}, info)
UiKit.round(pill, 10)
local pillEdge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.2 }, pill)
local pillText = label(pill, "", 10, P.Text, Enum.Font.GothamBlack)
pillText.Size, pillText.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
local heroBlurb = label(info, "", 11, P.Dim, IronUi.Body)
heroBlurb.Position, heroBlurb.Size = UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 28)
heroBlurb.TextWrapped = true
heroBlurb.TextYAlignment = Enum.TextYAlignment.Top
-- Health, damage, speed.
local statRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.new(1, 0, 0, 40),
}, info)
UiKit.list(statRow, 8, true)
local statValues = {}
for order, name in { "HEALTH", "DAMAGE", "SPEED" } do
	local chip = new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = P.Inset,
		Size = UDim2.new(1 / 3, -6, 1, 0),
	}, statRow)
	UiKit.round(chip, 8)
	local value = label(chip, "", 16, P.Text, Enum.Font.GothamBlack)
	value.Position, value.Size = UDim2.fromOffset(10, 3), UDim2.new(1, -16, 0, 20)
	local word = label(chip, name, 9, P.Dim, IronUi.Bold)
	word.Position, word.Size = UDim2.fromOffset(10, 23), UDim2.new(1, -16, 0, 12)
	statValues[order] = value
end
local expText = label(info, "", 11, P.Dim, IronUi.Bold)
expText.Position, expText.Size = UDim2.fromOffset(0, 148), UDim2.new(1, 0, 0, 12)
local expBack, expFill = bar(info, EXP)
expBack.Position, expBack.Size = UDim2.fromOffset(0, 162), UDim2.new(1, 0, 0, 6)

-- Its moves, from its Gemsoul: E from the start, Q and R as it levels.
local moveBox = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 178),
	Size = UDim2.new(1, 0, 0, 116),
}, detail)
UiKit.list(moveBox, 4)
local moveRows = {}
for order, key in { "E", "Q", "R" } do
	local row = new("Frame", {
		Name = "Move" .. key,
		LayoutOrder = order,
		BackgroundColor3 = P.Inset,
		Size = UDim2.new(1, 0, 0, 36),
	}, moveBox)
	UiKit.round(row, 8)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.6 }, row)
	local chip = new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = P.Gold,
	}, row)
	UiKit.round(chip, 6)
	local chipEdge = new("UIStroke", { Color = P.Dim, Thickness = 1, Transparency = 1 }, chip)
	local letter = label(chip, key, 13, INK, Enum.Font.GothamBlack)
	letter.Size, letter.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	local name = label(row, "", 13, P.Text, IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(38, 3), UDim2.new(1, -144, 0, 16)
	local about = label(row, "", 10, P.Dim, IronUi.Body)
	about.Position, about.Size = UDim2.fromOffset(38, 19), UDim2.new(1, -144, 0, 13)
	local state = label(row, "", 10, P.Good, Enum.Font.GothamBlack)
	state.AnchorPoint, state.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	state.Position, state.Size = UDim2.new(1, -10, 0, 0), UDim2.new(0, 100, 1, 0)
	moveRows[key] = {
		Frame = row,
		Edge = edge,
		Chip = chip,
		ChipEdge = chipEdge,
		Letter = letter,
		Name = name,
		About = about,
		State = state,
	}
end

-- What you can do with it.
local actionBar = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 40),
}, detail)
local actionText = label(actionBar, "", 11, P.Dim, IronUi.Body)
actionText.Size = UDim2.new(1, 0, 1, 0)
actionText.TextWrapped = true
local actionButtons = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(1, 1),
}, actionBar)
local actionList = UiKit.list(actionButtons, 6, true)
actionList.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- Feeding the one picked.
local feedPane = new("Frame", {
	Name = "Feed",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	Visible = false,
}, right)
local feedHead = label(feedPane, "", 12, P.Text, IronUi.Bold)
feedHead.Size = UDim2.new(1, 0, 0, 18)
local feedList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 1, -82),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, feedPane)
UiKit.list(feedList, 6)
local footer = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 50),
}, feedPane)
local footerText = label(footer, "", 11, P.Dim, IronUi.Body)
footerText.Size = UDim2.new(1, -150, 1, 0)
footerText.TextWrapped = true
local feedButton = smallButton(footer, "FEED", P.Good)
feedButton.AnchorPoint = Vector2.new(1, 0.5)
feedButton.Position, feedButton.Size = UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(130, 38)
feedButton.TextSize = 15
-- One tap picks a mouthful of spare Commons (what mining mostly pays).
local commonsButton = smallButton(footer, "PICK COMMONS", P.Teal)
commonsButton.AnchorPoint = Vector2.new(1, 0.5)
commonsButton.Position, commonsButton.Size = UDim2.new(1, -140, 0.5, 0), UDim2.fromOffset(122, 38)

local tab = "Details"
local selected: string? = nil
local swapping = false -- choosing who a kaiju from home goes out in place of
local picked: { [string]: boolean } = {}
local tabButtons = {}
local rowLive = {} -- [id] = the bits of its row that change while you look
local drawPanel

for order, entry in { { "Details", "DETAILS" }, { "Feed", "FEED" } } do
	local b = smallButton(tabRow, entry[2], P.Gold)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(120, 28)
	b.Activated:Connect(function()
		tab = entry[1]
		swapping = false
		table.clear(picked)
		drawPanel()
	end)
	tabButtons[entry[1]] = b
end

local function moveName(id: string?): string
	local move = id and GemTraits.Moves[id]
	return if move then move.Name else "?"
end

-- The stones it would eat, best EXP first, with what each gives.
local function stonesFor(record)
	local list = {}
	for _, gem in (GemClient.Profile and GemClient.Profile.Gems) or {} do
		table.insert(list, { Gem = gem, Exp = Kaiju.feedExp(gem, record) })
	end
	table.sort(list, function(a, b)
		return if a.Exp ~= b.Exp then a.Exp > b.Exp else (a.Gem.Id < b.Gem.Id)
	end)
	return list
end

-- Actions ----------------------------------------------------------------------------------------------------------

local busy = false
local function act(fn: () -> ())
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = pcall(fn)
		busy = false
		if not ok then
			warn("[KaijuHud]", err)
		end
	end)
end

local function say(result)
	if result and result.Message and result.Message ~= "" then
		UiKit.toast(result.Message, if result.Ok then P.Good else P.Gold)
	end
end

-- The panel's list ------------------------------------------------------------------------------------------------

local function clearList()
	-- (The rows' models are kept for next time.)
	for key, entry in built do
		if string.sub(key, 1, 4) == "row:" then
			entry.Model.Parent = nil
		end
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(rowLive)
end

local function heading(order: number, text: string, note: string)
	local frame = new("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 18),
	}, listFrame)
	local title = label(frame, text, 11, P.Gold, Enum.Font.GothamBlack)
	title.Size = UDim2.fromScale(0.6, 1)
	local side = label(frame, note, 10, P.Dim, IronUi.Bold)
	side.AnchorPoint, side.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	side.Position, side.Size = UDim2.fromScale(1, 0), UDim2.fromScale(0.5, 1)
end

-- What a row says under its name: its level and where it is.
local function rowStatus(record, slot: number?): (string, Color3)
	local wait = downFor(record.Id)
	if slot and wait > 0 then
		return string.format("Lv %d  ·  KO, back in %ds", record.Level, math.ceil(wait)), P.Bad:Lerp(P.Text, 0.3)
	elseif slot == 1 then
		return string.format("Lv %d  ·  LEADS", record.Level), P.Gold
	elseif slot then
		return string.format("Lv %d  ·  OUT", record.Level), P.Good
	end
	return string.format("Lv %d  ·  AT HOME", record.Level), P.Dim
end

local function kaijuRow(order: number, record, slot: number?, models)
	local color = elementColor(record.Element)
	local chosen = record.Id == selected
	local row = new("TextButton", {
		Name = "Kaiju_" .. record.Id,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if chosen then color:Lerp(INK, 0.72) else P.Inset,
		Size = UDim2.new(1, -8, 0, 58),
	}, listFrame)
	UiKit.round(row, 8)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = if chosen then 0 else 1 }, row)
	local view = viewport(row, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(46, 46) })
	UiKit.round(view, 8)
	portrait(view, modelFor("row:" .. record.Id, record))
	if slot then
		-- Its place in the team: 1 leads.
		local badge = new("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = if slot == 1 then P.Gold else P.Slot,
			ZIndex = 3,
		}, row)
		UiKit.round(badge, 8)
		local n = label(badge, tostring(slot), 10, if slot == 1 then INK else P.Text, Enum.Font.GothamBlack)
		n.Size, n.TextXAlignment, n.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
	end
	local name = label(row, Kaiju.title(record), 13, color:Lerp(P.Text, 0.35), IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(60, 6), UDim2.new(1, -66, 0, 16)
	local statusText, statusColor = rowStatus(record, slot)
	local status = label(row, statusText, 10, statusColor, IronUi.Bold)
	status.Position, status.Size = UDim2.fromOffset(60, 23), UDim2.new(1, -66, 0, 13)
	local live = { Record = record, Slot = slot, Status = status }
	if slot then
		local back, fill = bar(row, HEALTH)
		back.Position, back.Size = UDim2.fromOffset(60, 40), UDim2.new(1, -72, 0, 5)
		fill.Size = UDim2.fromScale(healthShare(models[record.Id]), 1)
		live.Health = fill
	end
	local expBar, expBarFill = bar(row, EXP)
	expBar.Position, expBar.Size = UDim2.fromOffset(60, if slot then 48 else 42), UDim2.new(1, -72, 0, 3)
	expBarFill.Size = UDim2.fromScale(expShare(record.Level, record.Exp or 0), 1)
	rowLive[record.Id] = live
	row.Activated:Connect(function()
		selected = record.Id
		swapping = false
		drawPanel()
	end)
end

local function drawList(data, team: { string })
	clearList()
	local models = petModels()
	local inTeam = {}
	heading(1, "YOUR TEAM", string.format("%d OUT", #team))
	for slot, id in team do
		inTeam[id] = slot
		kaijuRow(1 + slot, data.List[id], slot, models)
	end
	local home = {}
	for id, record in (data and data.List) or {} do
		if not inTeam[id] then
			table.insert(home, record)
		end
	end
	table.sort(home, function(a, b)
		return if a.Level ~= b.Level then a.Level > b.Level else a.Id < b.Id
	end)
	if #home > 0 then
		heading(20, "AT HOME", tostring(#home))
	end
	for i, record in home do
		kaijuRow(20 + i, record, nil, models)
	end
	local note = label(
		listFrame,
		string.format(
			"%d of %d kaiju kept. Tame more in the far quarry: wear one down to half health without killing it.",
			Kaiju.count(data),
			Kaiju.MaxOwned
		),
		10,
		P.Dim,
		IronUi.Body
	)
	note.LayoutOrder = 99
	note.Size = UDim2.new(1, -8, 0, 40)
	note.TextWrapped = true
	note.TextYAlignment = Enum.TextYAlignment.Top
	-- (Prune the models of kaiju you no longer have.)
	for key, entry in built do
		local id = string.match(key, "^row:(.+)$")
		if id and not (data and data.List[id]) then
			entry.Model:Destroy()
			built[key] = nil
		end
	end
end

-- The rows' health and knockouts, as they change.
local function liveRows()
	local models = petModels()
	for id, live in rowLive do
		if live.Health then
			live.Health.Size = UDim2.fromScale(healthShare(models[id]), 1)
		end
		local text, color = rowStatus(live.Record, live.Slot)
		live.Status.Text, live.Status.TextColor3 = text, color
	end
end

-- The one picked ---------------------------------------------------------------------------------------------------

local function actionButton(order: number, text: string, color: Color3, width: number, onClick: () -> ())
	local b = smallButton(actionButtons, text, color)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(width, 34)
	b.Activated:Connect(onClick)
	return b
end

local function drawActions(data, record, team: { string })
	for _, child in actionButtons:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local slot = table.find(team, record.Id)
	if swapping and not slot then
		-- SEND OUT: in place of which of the team?
		actionText.Text = "In place of:"
		actionText.Size = UDim2.new(0, 80, 1, 0)
		for i, id in team do
			local other = data.List[id]
			local species = other and Kaiju.species(other.Species)
			actionButton(
				i,
				string.upper(species and species.Name or id),
				elementColor(other and other.Element),
				100,
				function()
					local ids = table.clone(team)
					ids[i] = record.Id
					act(function()
						local result = GemClient.request("KaijuTeam", ids)
						say(result)
						if result and result.Ok then
							swapping = false
						end
					end)
				end
			)
		end
		actionButton(9, "CANCEL", P.Edge, 80, function()
			swapping = false
			drawPanel()
		end)
		return
	end
	actionText.Size = UDim2.new(1, -240, 1, 0)
	if slot == 1 then
		actionText.Text = "Leads your team: the first to fight."
	elseif slot then
		actionText.Text = string.format("Out with you, in place %d of your team.", slot)
		actionButton(1, "LEAD", P.Gold, 100, function()
			act(function()
				say(GemClient.request("KaijuActive", record.Id))
			end)
		end)
	else
		actionText.Text = "At home: send it out in place of one of your team."
		actionButton(1, "SEND OUT", P.Teal, 100, function()
			swapping = true
			drawPanel()
		end)
	end
	actionButton(2, "FEED", P.Good, 100, function()
		tab = "Feed"
		table.clear(picked)
		drawPanel()
	end)
end

local function drawDetail(data, record, team: { string })
	local color = elementColor(record.Element)
	local species = Kaiju.species(record.Species)
	local soul = record.Soul
	local tier = (soul and soul.Tier) or "Common"
	local tierColor = GemConfig.TierColors[tier] or P.Text
	local slot = table.find(team, record.Id)
	portrait(heroView, modelFor("hero", record))
	heroEdge.Color = color
	heroGlow.Color = ColorSequence.new(color:Lerp(INK, 0.55), INK)
	heroName.Text = string.upper(Kaiju.title(record))
	heroName.TextColor3 = color:Lerp(P.Text, 0.25)
	heroTag.Text = string.format(
		"%s  ·  LEVEL %d  ·  %s",
		string.upper(species and species.Role or ""),
		record.Level,
		if slot == 1 then "LEADS" elseif slot then "OUT" else "AT HOME"
	)
	pillText.Text = string.upper(GemConfig.TierLabels[tier] or tier) .. " GEMSOUL"
	pillText.TextColor3, pillEdge.Color = tierColor, tierColor
	pill.BackgroundColor3 = tierColor:Lerp(INK, 0.75)
	heroBlurb.Text = if species then species.Blurb else ""
	local stats = Kaiju.stats(record.Species, record.Level, tier)
	if stats then
		statValues[1].Text = tostring(math.floor(stats.Health + 0.5))
		statValues[2].Text = tostring(math.floor(stats.Damage + 0.5))
		statValues[3].Text = tostring(math.floor(stats.Speed + 0.5))
	end
	local need = Kaiju.expToNext(record.Level)
	expText.Text = if need == math.huge
		then string.format("EXP %d / MAX", record.Exp or 0)
		else string.format("EXP %d / %d", record.Exp or 0, need)
	expFill.Size = UDim2.fromScale(expShare(record.Level, record.Exp or 0), 1)
	for key, row in moveRows do
		local id, awake = Kaiju.move(soul, key, record.Level)
		local move = id and GemTraits.Moves[id]
		row.Name.Text = moveName(id)
		row.Name.TextColor3 = if awake then P.Text else P.Dim
		row.About.Text = move and move.Description or ""
		row.Chip.BackgroundColor3 = if awake then color else INK
		row.ChipEdge.Transparency = if awake then 1 else 0
		row.Letter.TextColor3 = if awake then INK else P.Dim
		row.Edge.Color = if awake then color else P.Edge
		row.Edge.Transparency = if awake then 0.45 else 0.7
		row.Frame.BackgroundColor3 = if awake then color:Lerp(INK, 0.82) else P.Inset
		row.State.Text = if awake then "READY" else string.format("WAKES AT LV %d", Kaiju.MoveLevels[key] or 1)
		row.State.TextSize = if awake then 10 else 9
		row.State.TextColor3 = if awake then P.Good else P.Dim
	end
	drawActions(data, record, team)
end

local function drawFeed(record)
	for _, child in feedList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	feedHead.Text = string.format("Feeding %s  ·  Lv %d", Kaiju.title(record), record.Level)
	feedHead.TextColor3 = elementColor(record.Element):Lerp(P.Text, 0.35)
	commonsButton.Visible = #GemInventory.spare(GemClient.Profile, "Common") > 0
	footerText.Size = UDim2.new(1, if commonsButton.Visible then -272 else -140, 1, 0)
	local total, count = 0, 0
	for _, entry in stonesFor(record) do
		local gem, exp = entry.Gem, entry.Exp
		local chosen = picked[gem.Id] == true
		if chosen then
			total += exp
			count += 1
		end
		local frame = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, -8, 0, 38) }, feedList)
		UiKit.round(frame, 8)
		local b = new("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, frame)
		local tick = new("Frame", {
			BackgroundColor3 = if chosen then P.Good else Color3.fromRGB(28, 32, 46),
			Position = UDim2.fromOffset(10, 11),
			Size = UDim2.fromOffset(16, 16),
		}, frame)
		UiKit.round(tick, 4)
		local name = label(frame, GemConfig.displayName(gem), 13, elementColor(gem.Element))
		name.Position, name.Size = UDim2.fromOffset(36, 0), UDim2.new(1, -130, 1, 0)
		local worth = label(frame, string.format("+%d EXP", exp), 13, if exp > 0 then P.Gold else P.Dim)
		worth.AnchorPoint = Vector2.new(1, 0)
		worth.Position, worth.Size = UDim2.new(1, -12, 0, 0), UDim2.new(0, 90, 1, 0)
		worth.TextXAlignment = Enum.TextXAlignment.Right
		b.Activated:Connect(function()
			picked[gem.Id] = not picked[gem.Id] or nil
			drawPanel()
		end)
	end
	footerText.Text = if count > 0
		then string.format("%d stone%s: +%d EXP", count, if count == 1 then "" else "s", total)
		elseif commonsButton.Visible then "Pick stones to feed it, or a mouthful of Commons."
		else "Pick stones to feed it. Rarer ones keep their worth as it grows; its weakness element gives half."
end

function drawPanel()
	local data = roster()
	local team = Kaiju.teamIds(data)
	if not (selected and data and data.List[selected]) then
		selected = team[1]
	end
	local record = selected and data.List[selected]
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then P.Gold:Lerp(INK, 0.3) else P.Gold:Lerp(INK, 0.75)
	end
	drawList(data, team)
	detail.Visible = tab == "Details" and record ~= nil
	feedPane.Visible = tab == "Feed" and record ~= nil
	if not record then
		portrait(heroView, nil)
		return
	end
	if tab == "Feed" then
		drawFeed(record)
	else
		drawDetail(data, record, team)
	end
end

commonsButton.Activated:Connect(function()
	table.clear(picked)
	for i, gem in GemInventory.spare(GemClient.Profile, "Common") do
		if i > Kaiju.FeedBatch then
			break
		end
		picked[gem.Id] = true
	end
	drawPanel()
end)

feedButton.Activated:Connect(function()
	local ids = {}
	for id in picked do
		table.insert(ids, id)
	end
	local target = selected
	if #ids == 0 or not target then
		return
	end
	act(function()
		local result = GemClient.request("KaijuFeed", ids, target)
		say(result)
		if result and result.Ok then
			table.clear(picked)
		end
	end)
end)

function KaijuHud.open(id: string?)
	tab = "Details"
	swapping = false
	table.clear(picked)
	selected = id
	drawPanel()
	window.Gui.Enabled = true
end

GemClient.Changed:Connect(function()
	if window.Gui.Enabled then
		-- (The pouch or the roster changed: what's picked may be gone.)
		local gems = {}
		for _, gem in (GemClient.Profile and GemClient.Profile.Gems) or {} do
			gems[gem.Id] = true
		end
		for id in picked do
			if not gems[id] then
				picked[id] = nil
			end
		end
		drawPanel()
	end
end)

-- The strip, the roll and TAME --------------------------------------------------------------------------------------

-- The wild kaiju you could try to tame now: the weakest near you.
local function tameTarget(): (Model?, number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then
		return nil, 0
	end
	local best, bestChance = nil, 0
	for _, model in enemies:GetChildren() do
		if model:IsA("Model") and KaijuTaming.ready(model) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local body = model.PrimaryPart
			if humanoid and body and (body.CFrame.Position - root.CFrame.Position).Magnitude <= TAME_RANGE then
				local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
				if chance > bestChance then
					best, bestChance = model, chance
				end
			end
		end
	end
	return best, bestChance
end

local tameModel: Model? = nil
local wantShown = false
local rollTried = false

local function refresh()
	local profile = GemClient.Profile
	local data = profile and profile.Kaiju
	local team = Kaiju.teamIds(data)
	local inOutpost = OutpostScene.isActive() and player:GetAttribute("Outpost") == true
	local blocked = player.PlayerGui:FindFirstChild("Intro") ~= nil
		or KaijuRoll.showing()
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	local menu = dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled
	-- The starter roll, once, for a player still owed it.
	if not rollTried and inOutpost and not blocked and not menu and Kaiju.rollsOwed(profile) > 0 then
		if not LoadingFlow.active() then
			rollTried = true
			task.spawn(KaijuRoll.play)
		end
	end
	if window.Gui.Enabled then
		liveRows()
	end
	wantShown = #team > 0 and inOutpost and not blocked and not menu
	gui.Enabled = wantShown
	if not wantShown then
		return
	end
	local models = petModels()
	for slot, tile in tiles do
		local id = team[slot]
		local record = id and data.List[id]
		tile.Button.Visible = record ~= nil
		if record then
			drawTile(tile, record, models[id], slot == 1)
		end
	end
	hunt.Text = if Spar.hunting(player) then "STOP" else "HUNT"
	recall.Visible = next(models) ~= nil
	-- TAME.
	local target, chance = tameTarget()
	tameModel = target
	tame.Visible = target ~= nil and not KaijuTaming.casting()
	if target then
		tameOdds.Text = string.format("%d%% chance", math.floor(chance * 100 + 0.5))
		local left = Kaiju.TameTries - (target:GetAttribute("KaijuTries") or 0)
		tameTries.Text = string.format("%d tr%s left", left, if left == 1 then "y" else "ies")
	end
end

-- Wild nameplates: the server's own bar while you're not hunting.
local function wildPlates()
	local enemies = workspace:FindFirstChild("Enemies")
	local show = not Spar.hunting(player) and wantShown
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:GetAttribute("KaijuWild") or model:GetAttribute("MoonBug") then
			local root = model.PrimaryPart
			local board = root and root:FindFirstChild("HealthBar")
			if board and board:IsA("BillboardGui") and board.Enabled ~= show then
				board.Enabled = show
			end
		end
	end
end

recall.Activated:Connect(function()
	act(function()
		say(GemClient.request("KaijuRecall"))
	end)
end)
hunt.Activated:Connect(function()
	act(function()
		say(GemClient.request("Hunt", not Spar.hunting(player)))
	end)
end)
-- A wild kaiju's Challenge prompt: your kaiju go in (KaijuWilds).
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt:GetAttribute("PromptKind") ~= "KaijuChallenge" then
		return
	end
	local model = prompt.Parent and prompt.Parent.Parent
	act(function()
		say(GemClient.request("KaijuChallenge", model))
	end)
end)
tame.Activated:Connect(function()
	local target = tameModel
	if not target then
		return
	end
	act(function()
		local result = GemClient.request("KaijuTame", target)
		if result and result.Casting then
			-- The cast is on: its bar shows how it goes (KaijuTaming).
			KaijuTaming.cast(target, result.Chance or 0, result.Seconds or Kaiju.Tame.Cast)
			tame.Visible = false
		else
			say(result)
		end
	end)
end)

local started = false
function KaijuHud.start()
	if started then
		return
	end
	started = true
	KaijuTaming.start()
	layout()
	local ok, err = pcall(refresh)
	if not ok then
		warn("[KaijuHud]", err)
	end
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + 0.2
		local ok, err = pcall(refresh)
		if not ok then
			warn("[KaijuHud]", err)
		end
		pcall(wildPlates)
	end)
end

return KaijuHud
