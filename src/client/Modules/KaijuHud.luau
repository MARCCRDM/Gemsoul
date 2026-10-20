--[[
	Your mini kaiju on screen (KaijuServer and KaijuWilds run them; see
	docs/kaiju.md). Only in the Outpost.

	  The team strip  your team out, a tile each, the lead first (edged in
	                  gold): its portrait (the model itself), level, health,
	                  and dots for its Q, E and R, lit when ready (hollow
	                  while asleep); knocked out, DOWN and when it's back by
	                  itself (tap it to revive it now). AUTO HEAL at
	                  its end: a Common, how many you have spare, and ON or
	                  OFF; on, your spare Commons heal the team by themselves
	                  (Shared.Kaiju.AutoHeal, KaijuServer). Tap a tile for
	                  the panel on that kaiju. Computer:
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
	                  of one of the team you pick), HEAL (REVIVE when it's
	                  down). Its Gemsoul's gem sits on its portrait.
	  REVIVE          one knocked out: gems don't bring it back. When it's
	                  back by itself (Shared.Kaiju.reviveIn, at half
	                  health), and REVIVE for Robux (the KaijuRevive
	                  product; coins while testing) or COUPON (a Revive
	                  coupon from inviting friends, Shared.Coupons): every
	                  one of yours that's down, back now.
	  HEAL            its health now and after, then your gems in stacks (a
	                  card for each rarity and element, the stone itself, how
	                  many, what each heals: its own element double, its
	                  weakness half; Shared.Kaiju.infusePlan). Opened, your
	                  spare Commons are picked already, as many as bring it
	                  to full (Kaiju.healPick): one tap of HEAL. Tap a card
	                  for one more of it, - for one less; CLEAR, AUTO PICK.
	                  Not while your team out is in a fight (the server's
	                  KaijuDanger: Shared.Kaiju.Danger): IN A FIGHT then.
	  The roll        a player still owed starter kaiju (from before the
	                  roll, say) gets the roll here, once (KaijuRoll).
	  No nameplates  nothing over a creature's head (yours, others', wild
	                  kaiju, moon bugs): its body shows its health, an
	                  outline in its health's colour, a wild kaiju's always
	                  and through rocks (BodyHealth, handed every creature
	                  this finds).

	  KaijuHud.start()     once, from Lobby.client
	  KaijuHud.open(id?, tab?)   the panel, on kaiju `id` (else your lead),
	                       on "Details" or "Heal"
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Coupons = require(ReplicatedStorage.Shared.Coupons)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Store = require(ReplicatedStorage.Shared.Store)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local KaijuRoll = require(script.Parent.KaijuRoll)
local KaijuTaming = require(script.Parent.KaijuTaming)
local ChatFeed = require(script.Parent.ChatFeed)
local LoadingFlow = require(script.Parent.LoadingFlow)
local MobileLayout = require(script.Parent.MobileLayout)
local BodyHealth = require(script.Parent.BodyHealth)
local OutpostScene = require(script.Parent.OutpostScene)
local SurgeIcons = require(script.Parent.SurgeIcons)
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
	-- (Lit for a portrait: KaijuModels.Portrait.)
	local look = KaijuModels.Portrait
	props.Ambient, props.LightColor, props.LightDirection = look.Ambient, look.LightColor, look.LightDirection
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
	local model = KaijuModels.forPortrait(KaijuModels.build(record.Species, record.Element))
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

-- Its health, 0 to 1: the body's while it's out, its kept health at home
-- (it never heals on its own), none while it's down.
local function healthShare(record, model: Model?): number
	if record and record.Down then
		return 0
	end
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	end
	if not record then
		return 1
	end
	local now, most = Kaiju.health(record)
	return math.clamp(now / math.max(1, most), 0, 1)
end

-- Its record with its health as it is right now: the body's while it's
-- out (the record you're sent catches up only now and then), else kept.
local function liveRecord(record)
	local model = record and not record.Down and petModels()[record.Id]
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return record
	end
	local live = table.clone(record)
	local _, most = Kaiju.health(record)
	live.Health = most * math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	return live
end

-- "1:05": how long till one knocked out is back by itself (Kaiju.reviveIn).
local function reviveClock(record): string
	local left = math.ceil(Kaiju.reviveIn(record, workspace:GetServerTimeNow()))
	return string.format("%d:%02d", left // 60, left % 60)
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
	-- Knocked out: a veil, DOWN and when it's back by itself.
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
		local data = roster()
		local record = data and tile.Id and data.List[tile.Id]
		KaijuHud.open(tile.Id, if record and record.Down then "Heal" else nil)
	end)
end

-- AUTO HEAL, at the strip's end: on, your spare Common gems, then your
-- spare Uncommons, heal the team by themselves (Shared.Kaiju.AutoHeal,
-- KaijuServer). It shows the gem it takes next and how many you have
-- spare; a tap switches it.
local autoButton = new("TextButton", {
	Name = "AutoHeal",
	Text = "",
	AutoButtonColor = true,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.fromOffset(72, 52),
	BackgroundColor3 = TILE_BACK,
}, card)
UiKit.round(autoButton, 8)
local autoEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, autoButton)
local autoGem = new("Frame", { Name = "Gem", BackgroundTransparency = 1 }, autoButton)
local autoCount = label(autoButton, "", 12, P.Text, IronUi.Bold)
local autoTitle = label(autoButton, "AUTO HEAL", 9, P.Dim, IronUi.Bold)
autoTitle.TextXAlignment = Enum.TextXAlignment.Center
local autoState = label(autoButton, "OFF", 13, P.Dim, Enum.Font.GothamBlack)
autoState.TextXAlignment = Enum.TextXAlignment.Center
local autoWant: boolean? = nil -- (switched here, till the roster says so)
local autoArt: string? = nil

-- CATCH: beside the strip, when there's a wild kaiju to catch.
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
local tameTitle = label(tame, "CATCH", 18, P.Gold, Enum.Font.GothamBlack)
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
	-- The tiles share what AUTO HEAL leaves.
	local buttonW, gap = if phone then 62 else 72, if phone then 4 else 6
	local th = h - 10
	local tw = math.min(math.floor(th * 1.25), math.floor((w - 10 - buttonW - 8 - gap * (#tiles - 1)) / #tiles))
	for slot, tile in tiles do
		tile.Button.Position = UDim2.fromOffset(5 + (slot - 1) * (tw + gap), 5)
		tile.Button.Size = UDim2.fromOffset(tw, th)
	end
	-- AUTO HEAL: a Common and how many you have spare, then its name, ON or OFF.
	local gemSize, gemY = if phone then 13 else 18, if phone then 3 else 4
	autoButton.Size = UDim2.fromOffset(buttonW, th)
	autoGem.Position, autoGem.Size = UDim2.fromOffset(6, gemY), UDim2.fromOffset(gemSize, gemSize)
	autoCount.Position, autoCount.Size = UDim2.fromOffset(9 + gemSize, gemY), UDim2.new(1, -13 - gemSize, 0, gemSize)
	autoCount.TextSize = if phone then 11 else 12
	autoTitle.Position = UDim2.fromOffset(0, gemY + gemSize + 1)
	autoTitle.Size, autoTitle.TextSize = UDim2.new(1, 0, 0, if phone then 9 else 11), if phone then 8 else 9
	local stateH = if phone then 11 else 14
	autoState.Position = UDim2.new(0, 0, 1, -(if phone then 2 else 3) - stateH)
	autoState.Size, autoState.TextSize = UDim2.new(1, 0, 0, stateH), if phone then 11 else 13
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
player:GetAttributeChangedSignal("Hunt"):Connect(layout)

-- Your spare Commons, then Uncommons (what AUTO HEAL uses, in that order:
-- Kaiju.autoHealPick): loose, never one a saved loadout names, never a
-- Gemsoul.
local spareCommons = {}
local function countCommons()
	local list = {}
	for _, tier in Kaiju.AutoHeal.Tiers do
		for _, gem in GemInventory.spare(GemClient.Profile, tier) do
			if not Kaiju.isSoul(gem) then
				table.insert(list, gem)
			end
		end
	end
	spareCommons = list
end

-- AUTO HEAL as it stands: ON (green) or OFF, and the gem it takes next (a
-- Common of the lead's element, those heal it double; an Uncommon once
-- the Commons are gone) with how many you have spare.
local function drawAuto(lead)
	local on = Kaiju.autoHealOn(roster())
	if autoWant ~= nil and autoWant ~= on then
		on = autoWant
	else
		autoWant = nil
	end
	autoButton.BackgroundColor3 = if on then P.Good:Lerp(INK, 0.72) else TILE_BACK
	autoEdge.Color = if on then P.Good else P.Edge
	autoState.Text = if on then "ON" else "OFF"
	autoState.TextColor3 = if on then P.Good else P.Dim
	autoTitle.TextColor3 = if on then P.Text else P.Dim
	autoCount.Text = "×" .. #spareCommons
	autoCount.TextColor3 = if #spareCommons > 0 then P.Text else P.Bad:Lerp(P.Text, 0.3)
	local element = (lead and lead.Element) or "Fire"
	local sample = nil
	local first = spareCommons[1] and spareCommons[1].Tier
	for _, gem in spareCommons do
		if gem.Element == element and gem.Tier == first then
			sample = gem
			break
		end
	end
	sample = sample
		or spareCommons[1]
		or {
			Id = "AutoHeal" .. element,
			Element = element,
			Tier = Kaiju.AutoHeal.Tiers[1],
			Size = 6,
			Clarity = 6,
			Cut = 5,
		}
	if autoArt ~= sample.Id then
		autoArt = sample.Id
		for _, child in autoGem:GetChildren() do
			child:Destroy()
		end
		pcall(GemArt.viewport, autoGem, sample, false)
	end
end

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
	local share = healthShare(record, model)
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
	tile.Veil.Visible = record.Down == true
	if record.Down then
		tile.VeilText.Text = "DOWN " .. reviveClock(record)
	end
end

-- The panel -------------------------------------------------------------------------------------------------------

-- (On a phone on its side, a window of its own, drawn near full size: the
-- one picked scrolls, and HEAL's gems take the width.)
local SHORT = UiKit.short()
local W, H = if SHORT then 860 else 800, if SHORT then 340 else 480
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
	Position = UDim2.fromOffset(if SHORT then 12 else 20, if SHORT then 70 else 78),
	Size = UDim2.new(1, if SHORT then -24 else -40, 1, if SHORT then -78 else -96),
}, window.Panel)

-- Left: every kaiju you have, your team first.
local LIST_W = if SHORT then 214 else 256
local listFrame = new("ScrollingFrame", {
	Name = "KaijuList",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, LIST_W, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, body)
UiKit.list(listFrame, 6)

-- Right: the one picked, or healing it.
local right = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(LIST_W + 14, 0),
	Size = UDim2.new(1, -(LIST_W + 14), 1, 0),
}, body)
local tabRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, right)
UiKit.list(tabRow, 8, true)

local detail = new(if SHORT then "ScrollingFrame" else "Frame", {
	Name = "Detail",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
}, right)
if SHORT then
	detail.CanvasSize = UDim2.fromOffset(0, 362)
	detail.ScrollBarThickness = 4
	detail.ScrollingDirection = Enum.ScrollingDirection.Y
end
local heroView = viewport(detail, { Size = UDim2.fromOffset(168, 168) })
UiKit.round(heroView, 10)
local heroEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.2 }, heroView)
local heroGlow = new("UIGradient", { Rotation = 90 }, heroView)
-- Its Gemsoul (the gem it lives in), on the portrait's corner, edged in its rarity.
local soulBadge = new("Frame", {
	Name = "Gemsoul",
	Position = UDim2.fromOffset(168 - 58, 168 - 58),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.15,
	ZIndex = 3,
}, detail)
UiKit.round(soulBadge, 26)
local soulEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, soulBadge)
local soulArt: string? = nil
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
	-- (Over the move's icon, when it has one: its key on the corner.)
	local badge = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 3, 1, 3),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = P.Gold,
		Visible = false,
		ZIndex = 3,
	}, chip)
	UiKit.round(badge, 4)
	local badgeLetter = label(badge, key, 9, INK, Enum.Font.GothamBlack)
	badgeLetter.Size, badgeLetter.TextXAlignment, badgeLetter.ZIndex =
		UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
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
		Badge = badge,
		BadgeLetter = badgeLetter,
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
if SHORT then
	-- (At the foot of what scrolls.)
	actionBar.AnchorPoint, actionBar.Position = Vector2.zero, UDim2.fromOffset(0, 362 - 40)
end
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

-- Healing the one picked: gems from your pouch heal it, or bring it back
-- when it's down. Its health now and after at the top, your gems in stacks
-- below, HEAL at the bottom.
local healPane = new("Frame", {
	Name = "Heal",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	Visible = false,
}, right)
local HEAD_H = if SHORT then 46 else 58
local healHead = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, 0, 0, HEAD_H) }, healPane)
UiKit.round(healHead, 10)
local healName = label(healHead, "", 14, P.Text, IronUi.Bold)
healName.Position, healName.Size = UDim2.fromOffset(12, if SHORT then 4 else 7), UDim2.new(1, -184, 0, 18)
local healNumbers = label(healHead, "", 12, P.Text, IronUi.Bold)
healNumbers.AnchorPoint, healNumbers.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
healNumbers.Position, healNumbers.Size = UDim2.new(1, -12, 0, if SHORT then 4 else 7), UDim2.fromOffset(170, 18)
local healBack = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	Position = UDim2.fromOffset(12, if SHORT then 25 else 32),
	Size = UDim2.new(1, -24, 0, if SHORT then 14 else 16),
}, healHead)
UiKit.round(healBack, 8)
-- (After the heal, lighter, under its health now.)
local healAfter = new("Frame", { BackgroundColor3 = HEALTH, BackgroundTransparency = 0.55 }, healBack)
UiKit.round(healAfter, 8)
local healNow = new("Frame", { BackgroundColor3 = HEALTH }, healBack)
UiKit.round(healNow, 8)
local healBarText = label(healBack, "", 10, P.Text, Enum.Font.GothamBlack)
healBarText.Size, healBarText.TextXAlignment, healBarText.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 3
-- Whether AUTO HEAL is on.
local healHint = label(healPane, "", if SHORT then 11 else 10, P.Dim, IronUi.Bold)
healHint.Position, healHint.Size = UDim2.fromOffset(2, HEAD_H + 4), UDim2.new(1, -4, 0, 14)
-- Your gems, a card for each rarity and element.
local CARD_W, CARD_H = if SHORT then 141 else 150, 84
local stacksY, footH = HEAD_H + 22, if SHORT then 44 else 48
local stackList = new("ScrollingFrame", {
	Name = "GemStacks",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, stacksY),
	Size = UDim2.new(1, 0, 1, -stacksY - footH - 4),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, healPane)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(CARD_W, CARD_H),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, stackList)
local healFoot = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, footH),
}, healPane)
local healSummary = label(healFoot, "", 13, P.Text, IronUi.Bold)
healSummary.Position, healSummary.Size = UDim2.fromOffset(2, 5), UDim2.new(1, -276, 0, 18)
local healNote = label(healFoot, "", 10, P.Dim, IronUi.Body)
healNote.Position, healNote.Size = UDim2.fromOffset(2, 23), UDim2.new(1, -276, 0, 24)
healNote.TextWrapped, healNote.TextYAlignment = true, Enum.TextYAlignment.Top
local healButton = smallButton(healFoot, "HEAL", P.Good)
healButton.AnchorPoint = Vector2.new(1, 0.5)
healButton.Position, healButton.Size = UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(150, 40)
healButton.TextSize = 16
local resetButton = smallButton(healFoot, "CLEAR", P.Edge)
resetButton.AnchorPoint = Vector2.new(1, 0.5)
resetButton.Position, resetButton.Size = UDim2.new(1, -158, 0.5, 0), UDim2.fromOffset(106, 40)
-- Knocked out: no gems bring it back, so in their place when it's back by
-- itself, and how to bring it back now (REVIVE and COUPON, below).
local reviveCard = new("Frame", {
	Name = "Revive",
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(0, stacksY),
	Size = UDim2.new(1, 0, 1, -stacksY - footH - 4),
	Visible = false,
}, healPane)
UiKit.round(reviveCard, 10)
new("UIStroke", { Color = P.Bad:Lerp(P.Edge, 0.45), Thickness = 1.5 }, reviveCard)
local function centred(text: string, size: number, color: Color3, font: Enum.Font, y: number, h: number): TextLabel
	local l = label(reviveCard, text, size, color, font)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Position, l.Size = UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, h)
	return l
end
local reviveCaption = centred("BACK BY ITSELF IN", 11, P.Dim, IronUi.Bold, if SHORT then 7 else 36, 14)
local reviveTime = centred("", if SHORT then 32 else 46, P.Text, Enum.Font.GothamBlack, if SHORT then 20 else 54, if SHORT then 36 else 54)
local reviveLine = centred("", 12, P.Text, IronUi.Bold, if SHORT then 58 else 118, 16)
local reviveCoupon = centred("", 11, P.Gold, IronUi.Bold, if SHORT then 78 else 144, 16)

local tab = "Details"
local selected: string? = nil
local swapping = false -- choosing who a kaiju from home goes out in place of
-- HEAL's picks: how many of each stack. Made for you (pickFresh, a new
-- kaiju, or its health changed while you hadn't touched them), else yours.
local pickCounts: { [string]: number } = {}
local pickFresh, pickFor, pickSig, manual = true, nil :: string?, nil :: string?, false
local healChosen, healReady = {}, false
local tabButtons = {}
local rowLive = {} -- [id] = the bits of its row that change while you look
local drawPanel

for order, entry in { { "Details", "DETAILS" }, { "Heal", "HEAL" } } do
	local b = smallButton(tabRow, entry[2], P.Gold)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(120, 28)
	b.Activated:Connect(function()
		tab = entry[1]
		swapping = false
		pickFresh = true
		drawPanel()
	end)
	tabButtons[entry[1]] = b
end

local function moveName(id: string?): string
	local move = id and GemTraits.Moves[id]
	return if move then move.Name else "?"
end

-- Your gems for a heal, in stacks: one for each rarity and element (they
-- heal alike), the cheapest first (Commons, then rarer), its own element
-- first in each rarity. Never one on your gear, never a Gemsoul. In each
-- stack the spare ones first (none a saved loadout names), then the least
-- valuable, so a heal spends what you'd miss least.
local TIER_RANK = {}
for rank, tier in GemConfig.TierOrder do
	TIER_RANK[tier] = rank
end
local function stackKey(gem): string
	return (gem.Tier or "Common") .. "/" .. tostring(gem.Element)
end
local function healStacks(record)
	local profile = GemClient.Profile
	local spare = {}
	for _, tier in GemConfig.TierOrder do
		for _, gem in GemInventory.spare(profile, tier) do
			spare[gem.Id] = true
		end
	end
	local stacks, byKey = {}, {}
	for _, gem in GemInventory.available(profile) do
		if not Kaiju.isSoul(gem) then
			local key = stackKey(gem)
			local stack = byKey[key]
			if not stack then
				stack = {
					Key = key,
					Tier = gem.Tier or "Common",
					Element = gem.Element,
					Power = Kaiju.infusePower(gem, record),
					Gems = {},
				}
				byKey[key] = stack
				table.insert(stacks, stack)
			end
			table.insert(stack.Gems, gem)
		end
	end
	local worth = {}
	for _, stack in stacks do
		for _, gem in stack.Gems do
			local ok, value = pcall(GemConfig.value, gem)
			worth[gem] = if ok and type(value) == "number" then value else 0
		end
		table.sort(stack.Gems, function(a, b)
			if (spare[a.Id] == true) ~= (spare[b.Id] == true) then
				return spare[a.Id] == true
			end
			if worth[a] ~= worth[b] then
				return worth[a] < worth[b]
			end
			return a.Id < b.Id
		end)
	end
	table.sort(stacks, function(a, b)
		local ra, rb = TIER_RANK[a.Tier] or 0, TIER_RANK[b.Tier] or 0
		if ra ~= rb then
			return ra < rb
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return tostring(a.Element) < tostring(b.Element)
	end)
	return stacks
end

local function totalPicked(): number
	local n = 0
	for _, count in pickCounts do
		n += count
	end
	return n
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
	if record.Down then
		return string.format("Lv %d  ·  DOWN: REVIVE IT", record.Level), P.Bad:Lerp(P.Text, 0.3)
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
	-- Its health, out or at home (kept: it never heals on its own).
	local back, fill = bar(row, HEALTH)
	back.Position, back.Size = UDim2.fromOffset(60, 40), UDim2.new(1, -72, 0, 5)
	fill.Size = UDim2.fromScale(healthShare(record, models[record.Id]), 1)
	live.Health = fill
	local expBar, expBarFill = bar(row, EXP)
	expBar.Position, expBar.Size = UDim2.fromOffset(60, 48), UDim2.new(1, -72, 0, 3)
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
			"%d of %d kaiju kept. Catch more in the far quarry: wear one down to half health without killing it.",
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
			live.Health.Size = UDim2.fromScale(healthShare(live.Record, models[id]), 1)
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
	if record.Down then
		actionText.Text = string.format("Knocked out: back by itself in %s, or revive it now.", reviveClock(record))
	end
	actionButton(2, if record.Down then "REVIVE" else "HEAL", if record.Down then P.Bad else P.Good, 100, function()
		tab = "Heal"
		pickFresh = true
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
		if record.Down then "DOWN" elseif slot == 1 then "LEADS" elseif slot then "OUT" else "AT HOME"
	)
	pillText.Text = string.upper(GemConfig.TierLabels[tier] or tier) .. " GEMSOUL"
	pillText.TextColor3, pillEdge.Color = tierColor, tierColor
	pill.BackgroundColor3 = tierColor:Lerp(INK, 0.75)
	soulBadge.Visible = soul ~= nil
	soulEdge.Color = tierColor
	local soulKey = soul and (soul.Id or record.Id) or nil
	if soulArt ~= soulKey then
		soulArt = soulKey
		for _, child in soulBadge:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		if soul then
			pcall(GemArt.viewport, soulBadge, soul, true)
		end
	end
	heroBlurb.Text = if species then species.Blurb else ""
	local stats = Kaiju.stats(record.Species, record.Level, tier)
	if stats then
		-- (Its health as it is: kept, out or home, none while it's down.)
		local most = math.floor(stats.Health + 0.5)
		local now = math.floor(healthShare(record, petModels()[record.Id]) * most + 0.5)
		statValues[1].Text = if now < most then string.format("%d/%d", now, most) else tostring(most)
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
		-- Its icon (hollow and greyed while it sleeps), the key on its corner.
		local ok, drawn = pcall(SurgeIcons.apply, row.Chip, move, color)
		drawn = ok and drawn
		if drawn then
			pcall(SurgeIcons.dim, row.Chip, not awake)
		end
		row.Letter.Visible = not drawn
		row.Badge.Visible = drawn
		row.Badge.BackgroundColor3 = if awake then color else INK
		row.BadgeLetter.TextColor3 = if awake then INK else P.Dim
		row.Edge.Color = if awake then color else P.Edge
		row.Edge.Transparency = if awake then 0.45 else 0.7
		row.Frame.BackgroundColor3 = if awake then color:Lerp(INK, 0.82) else P.Inset
		row.State.Text = if awake then "READY" else string.format("WAKES AT LV %d", Kaiju.MoveLevels[key] or 1)
		row.State.TextSize = if awake then 10 else 9
		row.State.TextColor3 = if awake then P.Good else P.Dim
	end
	drawActions(data, record, team)
end

-- A stack's card in HEAL (kept between draws: its gem is a 3D view).
local stackCards: { [string]: any } = {}
local function stackCard(key: string)
	local entry = stackCards[key]
	if entry then
		return entry
	end
	local b = new("TextButton", {
		Name = "Gems_" .. key,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = P.Inset,
	}, stackList)
	UiKit.round(b, 10)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.25 }, b)
	local art = new("Frame", {
		Name = "Gem",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(46, 46),
	}, b)
	local have = label(b, "", 12, P.Text, IronUi.Bold)
	have.AnchorPoint, have.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	have.Position, have.Size = UDim2.new(1, -8, 0, 5), UDim2.fromOffset(60, 15)
	local gain = label(b, "", 17, HEALTH, Enum.Font.GothamBlack)
	gain.AnchorPoint, gain.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	gain.Position, gain.Size = UDim2.new(1, -8, 0, 20), UDim2.fromOffset(70, 20)
	local each = label(b, "EACH", 9, P.Dim, IronUi.Bold)
	each.AnchorPoint, each.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	each.Position, each.Size = UDim2.new(1, -8, 0, 40), UDim2.fromOffset(80, 11)
	local kind = label(b, "", 10, P.Dim, IronUi.Bold)
	kind.Position, kind.Size = UDim2.fromOffset(8, 53), UDim2.new(1, -16, 0, 12)
	local pill = new("Frame", {
		BackgroundColor3 = P.Good,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.fromOffset(70, 15),
		Visible = false,
	}, b)
	UiKit.round(pill, 7)
	local pillLabel = label(pill, "", 9, INK, Enum.Font.GothamBlack)
	pillLabel.Size, pillLabel.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	local minus = smallButton(b, "-", P.Bad)
	minus.Name = "Less"
	minus.AnchorPoint = Vector2.new(1, 0)
	minus.Position, minus.Size = UDim2.new(1, -8, 0, 64), UDim2.fromOffset(30, 18)
	minus.TextSize = 15
	minus.Visible = false
	entry = {
		Button = b,
		Edge = edge,
		Art = art,
		ArtId = nil :: string?,
		Have = have,
		Gain = gain,
		Each = each,
		Kind = kind,
		Pill = pill,
		PillLabel = pillLabel,
		Minus = minus,
		Stack = nil :: any,
	}
	b.Activated:Connect(function()
		local stack = entry.Stack
		local n = pickCounts[key] or 0
		if stack and n < #stack.Gems and totalPicked() < Kaiju.Infuse.Batch then
			pickCounts[key] = n + 1
			manual = true
			drawPanel()
		end
	end)
	minus.Activated:Connect(function()
		local n = pickCounts[key] or 0
		if n > 0 then
			pickCounts[key] = if n > 1 then n - 1 else nil
			manual = true
			drawPanel()
		end
	end)
	stackCards[key] = entry
	return entry
end

local function drawHeal(record)
	record = liveRecord(record)
	local down = record.Down == true
	local now, most = Kaiju.health(record)
	local full = not down and now >= most - 0.5
	local stacks = healStacks(record)
	-- Picked for you: your spare Commons, as many as bring it to full (or
	-- back, if it's down: Kaiju.healPick). Again whenever its health changes,
	-- unless you've picked your own.
	local sig = record.Id .. (if down then "/down" else "/" .. math.floor(now))
	local suggested = Kaiju.healPick(record, spareCommons, true)
	if pickFresh or pickFor ~= record.Id or (pickSig ~= sig and not manual) then
		pickFresh, pickFor, pickSig, manual = false, record.Id, sig, false
		table.clear(pickCounts)
		for _, gem in suggested do
			local key = stackKey(gem)
			pickCounts[key] = (pickCounts[key] or 0) + 1
		end
	end
	if full then
		table.clear(pickCounts)
	end
	-- The cards, in order, and what's picked of each.
	local seen, chosen = {}, {}
	for order, stack in stacks do
		seen[stack.Key] = true
		local n = math.min(pickCounts[stack.Key] or 0, #stack.Gems)
		pickCounts[stack.Key] = if n > 0 then n else nil
		for i = 1, n do
			table.insert(chosen, stack.Gems[i])
		end
		local c = stackCard(stack.Key)
		c.Stack = stack
		c.Button.LayoutOrder = order
		local shown = stack.Gems[1]
		if c.ArtId ~= shown.Id then
			c.ArtId = shown.Id
			for _, child in c.Art:GetChildren() do
				child:Destroy()
			end
			pcall(GemArt.viewport, c.Art, shown, false)
		end
		c.Have.Text = "×" .. #stack.Gems
		local base = Kaiju.Infuse.Power[stack.Tier] or Kaiju.Infuse.Power.Common
		c.Gain.Text = if down
			then string.format("+%g", stack.Power)
			else string.format("+%d%%", math.floor(stack.Power * Kaiju.Infuse.Mend * 100 + 0.5))
		c.Gain.TextColor3 = if stack.Power > base then P.Gold elseif stack.Power < base then P.Dim else HEALTH
		c.Each.Text = if down then "POWER EACH" else "EACH"
		c.Kind.Text = string.upper(
			GemConfig.elementName(stack.Element) .. " · " .. (GemConfig.TierLabels[stack.Tier] or stack.Tier)
		)
		c.Kind.TextColor3 = (GemConfig.TierColors[stack.Tier] or P.Dim):Lerp(P.Text, 0.15)
		c.Pill.Visible, c.Minus.Visible = n > 0, n > 0
		c.PillLabel.Text = string.format("%d PICKED", n)
		c.Edge.Color = if n > 0 then P.Good else elementColor(stack.Element):Lerp(P.Edge, 0.5)
		c.Edge.Thickness = if n > 0 then 2 else 1.5
		c.Button.BackgroundColor3 = if n > 0 then P.Good:Lerp(INK, 0.8) else P.Inset
	end
	for key, c in stackCards do
		if not seen[key] then
			c.Button:Destroy()
			stackCards[key] = nil
		end
	end
	for key in pickCounts do
		if not seen[key] then
			pickCounts[key] = nil
		end
	end
	-- The strongest first, so the heal spends the fewest.
	table.sort(chosen, function(a, b)
		local pa, pb = Kaiju.infusePower(a, record), Kaiju.infusePower(b, record)
		return if pa ~= pb then pa > pb else a.Id < b.Id
	end)
	local plan = Kaiju.infusePlan(record, chosen)
	local share = math.floor(plan.Health / math.max(1, most) * 100 + 0.5)
	-- (Out beside you in a fight: no healing till it's over, KaijuDanger.)
	local fighting = not down and player:GetAttribute("KaijuDanger") == true and petModels()[record.Id] ~= nil
	stackList.Visible, reviveCard.Visible = not down, down
	-- The head: its name, its health now and (lighter) after.
	healName.Text = string.format("%s  ·  LV %d", string.upper(Kaiju.title(record)), record.Level)
	healName.TextColor3 = elementColor(record.Element):Lerp(P.Text, 0.3)
	if down then
		local wait = Kaiju.reviveSeconds(record)
		local left = Kaiju.reviveIn(record, workspace:GetServerTimeNow())
		healNumbers.Text = "KNOCKED OUT"
		healNumbers.TextColor3 = P.Bad:Lerp(P.Text, 0.3)
		healNow.Size = UDim2.fromScale(0, 1)
		healAfter.Size = UDim2.fromScale(math.clamp(1 - left / math.max(1, wait), 0, 1), 1)
		healAfter.BackgroundColor3 = P.Gold
		healBarText.Text = "BACK IN " .. reviveClock(record)
	else
		healNumbers.Text = string.format("%d / %d HEALTH", math.floor(now + 0.5), most)
		healNumbers.TextColor3 = P.Text
		healNow.Size = UDim2.fromScale(math.clamp(now / math.max(1, most), 0, 1), 1)
		healNow.BackgroundColor3 = if now / math.max(1, most) < 0.3 then P.Bad else HEALTH
		healAfter.Size = UDim2.fromScale(math.clamp(plan.Health / math.max(1, most), 0, 1), 1)
		healAfter.BackgroundColor3 = HEALTH
		healBarText.Text = ""
	end
	local on = Kaiju.autoHealOn(roster())
	healHint.Text = if down
		then "Gems and AUTO HEAL don't bring back one that's knocked out."
		elseif on then "AUTO HEAL is on: your spare Commons, then Uncommons, heal your team between fights."
		else "Switch on AUTO HEAL by your team and your spare Commons, then Uncommons, heal them by themselves."
	healHint.TextColor3 = if on and not down then P.Good else P.Dim
	if down then
		-- Knocked out: back by itself, or REVIVE (Robux) or COUPON now.
		local coupons = Coupons.count(GemClient.Profile, "Revive")
		local onSale = (Store.RobuxProducts.KaijuRevive or 0) ~= 0 or Store.testPrice("KaijuRevive") ~= nil
		reviveTime.Text = reviveClock(record)
		reviveLine.Text = string.format(
			"It comes back weak, at %d%% health: heal it with gems.",
			math.floor(Kaiju.Revive.Health * 100 + 0.5)
		)
		reviveCoupon.Text = if coupons > 0
			then string.format("You have %d Revive coupon%s: COUPON brings it back free.", coupons, if coupons == 1 then "" else "s")
			else "Invite a friend: a free Revive coupon for each one who joins."
		healSummary.Text = "Knocked out"
		healNote.Text = "Revive now: every one of yours that's down, back at once, at half health."
		healReady = onSale
		healChosen = {}
		healButton.Text = if onSale then "REVIVE  ·  R$ " .. tostring(Store.robuxPrice("KaijuRevive") or 0) else "COMING SOON"
		healButton.AutoButtonColor = onSale
		healButton.BackgroundColor3 = P.Gold:Lerp(INK, if onSale then 0.3 else 0.78)
		healButton.TextColor3 = if onSale then P.Text else P.Dim
		resetButton.Text = string.format("COUPON ×%d", coupons)
		resetButton.Visible = coupons > 0
		return
	end
	-- Under the gems: what the heal does, and HEAL.
	if #stacks == 0 then
		healSummary.Text = "No gems in your pouch"
		healNote.Text = "Mine some: every rock pays a gem."
	elseif full then
		healSummary.Text = "Full health"
		healNote.Text = "Nothing to heal."
	elseif #chosen == 0 then
		healSummary.Text = "Tap your gems to pick them"
		healNote.Text = "A gem of its own element heals double, its weakness half."
	else
		healSummary.Text = string.format(
			"%s  ·  %s %d%%",
			if #plan.Used < #chosen
				then string.format("%d of %d gems", #plan.Used, #chosen)
				else string.format("%d gem%s", #plan.Used, if #plan.Used == 1 then "" else "s"),
			"heals to",
			share
		)
		healNote.Text = if manual
			then "A gem of its own element heals double, its weakness half."
			else "Picked for you from your spare Commons. Tap a gem for one more, - for one less."
	end
	if fighting and not full then
		healNote.Text = "In a fight: get clear of the critters to heal."
	end
	healReady = not full and #chosen > 0 and not fighting
	healChosen = chosen
	healButton.Text = if full then "FULL" elseif fighting then "IN A FIGHT" else "HEAL"
	healButton.AutoButtonColor = healReady
	healButton.BackgroundColor3 = P.Good:Lerp(INK, if healReady then 0.3 else 0.78)
	healButton.TextColor3 = if healReady then P.Text else P.Dim
	resetButton.Text = if next(pickCounts) then "CLEAR" else "AUTO PICK"
	resetButton.Visible = #stacks > 0 and not full and (next(pickCounts) ~= nil or #suggested > 0)
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
	healPane.Visible = tab == "Heal" and record ~= nil
	if not record then
		portrait(heroView, nil)
		return
	end
	if tab == "Heal" then
		drawHeal(record)
	else
		drawDetail(data, record, team)
	end
end

-- Your knocked-out kaiju back now: Roblox's purchase prompt for the
-- KaijuRevive product (the revive comes with the receipt: StoreServer), or
-- coins while testing (the store's BuyProduct).
local function buyRevive()
	local productId = Store.RobuxProducts.KaijuRevive or 0
	if productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, productId)
		return
	end
	if not Store.testPrice("KaijuRevive") then
		UiKit.toast("Coming soon: revives aren't on sale yet.", P.Dim)
		return
	end
	act(function()
		say(GemClient.request("BuyProduct", "KaijuRevive"))
	end)
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if purchased and userId == player.UserId and Store.productKey(productId) == "KaijuRevive" then
		-- (The receipt lands a moment after the prompt closes.)
		task.delay(1, function()
			UiKit.toast("Your kaiju are back on their feet!", P.Good)
		end)
	end
end)

local function selectedDown(): boolean
	local data = roster()
	local record = selected and data and data.List[selected]
	return record ~= nil and record.Down == true
end

resetButton.Activated:Connect(function()
	if selectedDown() then
		act(function()
			say(GemClient.request("UseCoupon", "Revive"))
		end)
		return
	end
	if next(pickCounts) then
		table.clear(pickCounts)
		manual = true
	else
		pickFresh = true
	end
	drawPanel()
end)

healButton.Activated:Connect(function()
	local target = selected
	if selectedDown() then
		if healReady then
			buyRevive()
		end
		return
	end
	if not healReady or #healChosen == 0 or not target then
		return
	end
	local ids = {}
	for _, gem in healChosen do
		table.insert(ids, gem.Id)
	end
	act(function()
		local result = GemClient.request("KaijuInfuse", ids, target)
		say(result)
		if result and result.Ok then
			pickFresh = true
			if window.Gui.Enabled then
				drawPanel()
			end
		end
	end)
end)

function KaijuHud.open(id: string?, onTab: string?)
	tab = if onTab == "Heal" or onTab == "Infuse" then "Heal" else "Details"
	swapping = false
	pickFresh = true
	selected = id
	drawPanel()
	window.Gui.Enabled = true
end

-- In a fight or out of it (KaijuDanger): HEAL follows.
player:GetAttributeChangedSignal("KaijuDanger"):Connect(function()
	if window.Gui.Enabled and tab == "Heal" then
		drawPanel()
	end
end)

-- The revive countdown, while it's on screen.
local function tickRevive()
	if not (window.Gui.Enabled and reviveCard.Visible and healPane.Visible) then
		return
	end
	local data = roster()
	local record = selected and data and data.List[selected]
	if record and record.Down then
		reviveTime.Text = reviveClock(record)
		healBarText.Text = "BACK IN " .. reviveClock(record)
		local left = Kaiju.reviveIn(record, workspace:GetServerTimeNow())
		healAfter.Size = UDim2.fromScale(math.clamp(1 - left / math.max(1, Kaiju.reviveSeconds(record)), 0, 1), 1)
	end
end

countCommons()
GemClient.Changed:Connect(function()
	countCommons()
	if window.Gui.Enabled then
		-- (The pouch or the roster changed: HEAL's picks are trimmed to what's left.)
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
	drawAuto(team[1] and data.List[team[1]])
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

-- Creatures show their health on their bodies (BodyHealth): wild kaiju
-- and moon bugs (the server's HealthBar over them stays off), and every
-- kaiju out.
local function bodies()
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:IsA("Model") and (model:GetAttribute("KaijuWild") or model:GetAttribute("MoonBug")) then
			BodyHealth.watch(model)
		end
	end
	local kaiju = workspace:FindFirstChild("Kaiju")
	for _, model in if kaiju then kaiju:GetChildren() else {} do
		if model:IsA("Model") then
			BodyHealth.watch(model)
		end
	end
end

autoButton.Activated:Connect(function()
	local data = roster()
	if not data or busy then
		return
	end
	local want = not (if autoWant ~= nil then autoWant else Kaiju.autoHealOn(data))
	autoWant = want
	pcall(refresh)
	act(function()
		local result = GemClient.request("KaijuAutoHeal", want)
		say(result)
		if not (result and result.Ok) then
			autoWant = nil -- (as it was)
		end
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
	BodyHealth.start()
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
		pcall(bodies)
		pcall(tickRevive)
	end)
end

return KaijuHud
