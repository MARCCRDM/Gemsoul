--[[
	Saga Outpost on the client: walking the shared mining basin with
	everyone else (OutpostServer decides everything; this shows it).

	  Mining     walk up to a rock and press E (or click / tap). Every swing
	             rings a lottery chime that climbs and swells as the rock
	             nears popping; chips fly and its crystals glow brighter.
	             The pop bursts the rock open and the find is revealed like a
	             lottery: a gem rises in a beam of its rarity's colour while
	             a reel spins through the rarities and lands on yours.
	  Others     you see and hear their swings too (quieter), and their pops.
	  Probe      PROBE-7, the crashed probe: buy refills, open the Market.
	  Gate       the Arena Uplink opens Social (1v1 queue, raids, rival).
	  Players    G at another miner challenges them to a duel, F invites
	             them to your party.

	  OutpostScene.enter() / leave() / isActive()
]]
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Rules = require(ReplicatedStorage.Shared.Outpost)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local PickaxeLooks = require(ReplicatedStorage.Shared.PickaxeLooks)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Seating = require(ReplicatedStorage.Shared.Seating)
local ChallengeChooser = require(script.Parent.ChallengeChooser)
local PlayerCard = require(script.Parent.PlayerCard)
local ChargeMeter = require(script.Parent.ChargeMeter)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local LoadingFlow = require(script.Parent.LoadingFlow)
local LotterySound = require(script.Parent.LotterySound)
local MobileLayout = require(script.Parent.MobileLayout)
local MinerLoot = require(script.Parent.MinerLoot)
local MiningReveal = require(script.Parent.MiningWorldReveal)
local PickImpacts = require(script.Parent.PickImpacts)
local ProbeLayout = require(script.Parent.ProbeLayout)
-- Driving the Motor Pool's machines (runs on its own once loaded).
require(script.Parent.VehicleDrive)
local Scenes = require(script.Parent.Scenes)
local SkyRift = require(script.Parent.SkyRift)
local RiftTear = require(script.Parent.RiftTear)
local FrontierHud = require(script.Parent.FrontierHud)
local ThirdPerson = require(script.Parent.ThirdPerson)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local OutpostScene = {}

local NODE_TAG = "OutpostNode"
local active, busy = false, false
local state = nil -- picks and record, from the server
local probeCharge = nil -- the free pick's meter at PROBE-7, while drawn
local finds = { Gems = 0, Rocks = 0 }
local nextSwing = 0
local hiddenDashboard: ScreenGui? = nil

local function tween(
	object: Instance,
	seconds: number,
	goal,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Sound ---------------------------------------------------------------------------------------------

local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local CLANG = "rbxasset://sounds/unsheath.wav"
local function sound(id: string, speed: number, volume: number, at: Vector3?, delay: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	if at then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		s.RollOffMaxDistance = 90
		s.RollOffMinDistance = 8
		s.Parent = holder
		Debris:AddItem(holder, 3)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 3)
	end
	if delay and delay > 0 then
		task.delay(delay, function()
			s:Play()
		end)
	else
		s:Play()
	end
end

-- One swing: the pick's thud, then a lottery chime that climbs a scale and
-- swells as the rock nears popping (tension 0..1); right before it pops a
-- second, higher chime and a shimmer join in. `mine`: your own swing (full
-- volume); others' are heard in the world, quieter.
local SCALE = { 1, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2 }
function OutpostScene.hitSound(tension: number, crit: boolean, mine: boolean, at: Vector3?)
	local loud = if mine then 1 else 0.45
	local where = if mine then nil else at
	sound(THUD, 0.9 + math.random() * 0.15, 0.32 * loud, where)
	sound(CLANG, 1.6 + tension * 0.4, 0.06 * loud, where)
	local note = SCALE[math.clamp(math.floor(tension * (#SCALE - 1)) + 1, 1, #SCALE)]
	local volume = (0.22 + tension * 0.6) * loud
	sound(PING, note * 0.9, volume, where)
	if tension >= 0.6 then
		sound(PING, note * 1.34, volume * 0.7, where, 0.05)
	end
	if tension >= 0.8 then
		for i = 1, 3 do
			sound(PING, note * (1.5 + i * 0.25), volume * 0.4, where, 0.04 + i * 0.045)
		end
	end
	if crit then
		sound(PING, 2.4, 0.5 * loud, where, 0.02)
		sound(THUD, 0.6, 0.35 * loud, where)
	end
end

-- HUD ---------------------------------------------------------------------------------------------

local hud = UiKit.gui("OutpostHud", 5)
hud.IgnoreGuiInset = false
hud.Enabled = false
local card = new("Frame", {
	Name = "PickStatus",
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(300, 44),
	BackgroundColor3 = Color3.fromRGB(14, 18, 30),
	BackgroundTransparency = 0.12,
}, hud)
UiKit.round(card, 8)
new("UIStroke", { Color = Color3.fromRGB(110, 220, 255), Transparency = 0.5, Thickness = 1.5 }, card)
local function text(parent, value, size, color, font, x, y, w, h, align)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or IronUi.Body,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	return l
end
local pickName = text(card, "Survey Pick", 13, P.Text, IronUi.Bold, 14, 8, 152, 18)
local pickSwings = text(card, "60 swings", 12, P.Gold, IronUi.Bold, 168, 8, 88, 18, Enum.TextXAlignment.Right)
local expandLabel = text(card, "+", 20, P.Dim, IronUi.Bold, 264, 5, 24, 24, Enum.TextXAlignment.Center)
local togglePick = new("TextButton", {
	Name = "TogglePickDetails", Text = "", BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 44), ZIndex = 5,
}, card)
togglePick:SetAttribute("UiSound", "Tab")
local track = new("Frame", {
	Position = UDim2.fromOffset(14, 30),
	Size = UDim2.fromOffset(272, 8),
	BackgroundColor3 = Color3.fromRGB(34, 40, 56),
}, card)
UiKit.round(track, 4)
local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Gold }, track)
UiKit.round(fill, 4)
-- The free pick's charge, always shown (with the free pick in hand it is
-- the pick's bar too).
local charge = ChargeMeter.new(card, 14, 46, 272)
charge.Frame.Visible = false
local findsLabel = text(card, "", 13, Color3.fromRGB(215, 228, 245), IronUi.Bold, 14, 144, 272, 18)
local recordLabel = text(card, "", 11, Color3.fromRGB(150, 170, 195), IronUi.Body, 14, 164, 272, 14)
local buttons = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 188),
	Size = UDim2.fromOffset(272, 40),
}, card)
UiKit.list(buttons, 8, true)
local hint = text(
	hud,
	"Click to mine  ·  Z spar  ·  G duel  ·  F invite  ·  E trade at PROBE-7",
	14,
	Color3.fromRGB(230, 238, 250),
	IronUi.Bold,
	0,
	0,
	900,
	22,
	Enum.TextXAlignment.Center
)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 210, 1, -18)
hint.TextSize = 12
hint.Size = UDim2.new(1, -500, 0, 32)
hint.TextWrapped = true
hint.TextStrokeTransparency = 0.4

-- Keep the field clear; navigation lives in the lobby dock and world prompts.
findsLabel.Visible, recordLabel.Visible, buttons.Visible = false, false, false
hint.Visible = not UserInputService.TouchEnabled
-- On a phone the card is drawn smaller (it sat over a third of the screen),
-- with the CHAT button just under it (MobileLayout), and it steps
-- aside while the chat is open over that corner.
local cardScale = new("UIScale", { Scale = 1 }, card)
local expanded = false
local collapseAt = 0
local blockingScreens = {
	Dashboard = true, Shop = true, Season = true, AugmentTree = true,
	SurgeArray = true, Social = true, ProbeExchange = true, WelcomeBundle = true,
	Intro = true, Tutorial = true, MarketBoard = true,
}
local openScreens = {}
local miningPrompts = {}
local function fitOutpostHud()
	local size = hud.AbsoluteSize
	local mobile = UserInputService.TouchEnabled or size.Y < 540
	-- (A fight or a spar has the screen: the pick card and mining prompts go.)
	local blocked = next(openScreens) ~= nil or Spar.fighting(player)
		or (mobile and player:GetAttribute("ChatOpen") == true)
	if blocked or not hud.Enabled then expanded = false end
	card.Size = UDim2.fromOffset(300, if expanded then 100 elseif mobile then 64 else 44)
	togglePick.Size = UDim2.fromScale(1, 1)
	track.Position = UDim2.fromOffset(14, if mobile and not expanded then 48 else 30)
	-- Keep the contents at their designed width; scale the whole card on narrow screens.
	cardScale.Scale = math.min(if mobile then MobileLayout.CardScale elseif expanded then 1 else 0.78, math.max(0.1, (size.X - 24) / 300))
	card.Visible = not blocked
	for _, promptGui in miningPrompts do
		promptGui.Enabled = not blocked and hud.Enabled
	end
	PlayerCard.setBlocked(blocked or not hud.Enabled)
	MinerLoot.setBlocked(blocked or not hud.Enabled)
	hint.Visible = not blocked and not mobile
	charge.Frame.Visible = expanded
	track.Visible = not expanded or (state ~= nil and state.Active ~= "Survey")
	expandLabel.Text = if expanded then "−" else "+"
end
togglePick.Activated:Connect(function()
	expanded = not expanded
	collapseAt = os.clock() + 8
	fitOutpostHud()
end)
-- Watch ScreenGui state directly: opening Inventory must hide the world HUD
-- immediately, even though the player is still physically in the Outpost.
local function watchScreen(screen)
	if not screen:IsA("ScreenGui") or (not blockingScreens[screen.Name] and screen.Name ~= "TrainingRewards") then return end
	local function update()
		local modal = screen.Name ~= "TrainingRewards" or screen:GetAttribute("BlocksMiningHud") == true
		openScreens[screen] = if screen.Parent and screen.Enabled and modal then true else nil
		fitOutpostHud()
	end
	local connection = screen:GetPropertyChangedSignal("Enabled"):Connect(update)
	local modalConnection = screen:GetAttributeChangedSignal("BlocksMiningHud"):Connect(update)
	screen.Destroying:Once(function()
		connection:Disconnect()
		modalConnection:Disconnect()
		openScreens[screen] = nil
		fitOutpostHud()
	end)
	update()
end
player.PlayerGui.ChildAdded:Connect(watchScreen)
for _, screen in player.PlayerGui:GetChildren() do watchScreen(screen) end
hud:GetPropertyChangedSignal("Enabled"):Connect(fitOutpostHud)
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitOutpostHud)
player:GetAttributeChangedSignal("ChatOpen"):Connect(fitOutpostHud)
player:GetAttributeChangedSignal("CombatSession"):Connect(fitOutpostHud)
player:GetAttributeChangedSignal("Spar"):Connect(fitOutpostHud)
fitOutpostHud()

-- The free pick's charge ticks up between server updates.
local function refreshCharge()
	if not state then
		return
	end
	local swings, nextIn, progress = ChargeMeter.read(state.Picks, state.SurveyAt)
	charge.set(swings, nextIn, progress)
	if probeCharge then
		probeCharge.set(swings, nextIn, progress)
	end
	if state.Active == "Survey" then
		pickSwings.Text = if swings > 0 then swings .. " swings" else "RECHARGING"
		pickSwings.TextColor3 = if swings > 0 then ChargeMeter.Charging else P.Bad
		fill.Size = UDim2.fromScale(math.clamp(swings / ChargeMeter.Full, 0, 1), 1)
		fill.BackgroundColor3 = if nextIn then ChargeMeter.Charging else ChargeMeter.Charged
	end
end

local function refreshHud()
	if not state then
		return
	end
	local id = state.Active
	local spec = Rules.Picks[id] or Rules.Picks.Survey
	local left = state.Picks[id] or 0
	local free = id == "Survey"
	pickName.Text = spec.Name .. (if free then "  · FREE" elseif spec.Power > 1 then "  ×" .. spec.Power else "")
	pickSwings.Text = if left > 0 then left .. " swings" else "BROKEN"
	pickSwings.TextColor3 = if left > 0 then P.Gold else Color3.fromRGB(255, 90, 90)
	-- A bought pick wears out; the free one is the charge meter below.
	track.Visible = not expanded or not free
	fill.Size = UDim2.fromScale(math.clamp(left / spec.Swings, 0, 1), 1)
	fill.BackgroundColor3 = if left / spec.Swings > 0.3 then spec.Color else Color3.fromRGB(255, 110, 90)
	refreshCharge()
	findsLabel.Text = string.format("This trip: %d gem%s", finds.Gems, if finds.Gems == 1 then "" else "s")
	recordLabel.Text = string.format("%d rocks mined", state.Rocks or 0)
end

-- Rock labels -------------------------------------------------------------------------------------

local labels: { [Model]: { Gui: BillboardGui, Fill: Frame, Name: TextLabel, Claim: TextLabel, Light: PointLight?, Base: number } } =
	{}
-- A whole rock's name only shows up close; one being mined shows from
-- further off, so you can see who's on it.
local LABEL_NEAR, LABEL_MINED = 24, 60
local function sizeColor(size: string): Color3
	return ({
		Pebble = Color3.fromRGB(200, 205, 215),
		Boulder = Color3.fromRGB(110, 220, 255),
		Monolith = Color3.fromRGB(255, 190, 90),
		Geode = Color3.fromRGB(215, 130, 255),
	})[size] or Color3.new(1, 1, 1)
end
local function refreshLabel(model: Model)
	local entry = labels[model]
	if not entry then
		return
	end
	local hp, max = model:GetAttribute("Hp") or 1, model:GetAttribute("MaxHp") or 1
	entry.Fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
	entry.Gui.MaxDistance = if hp < max then LABEL_MINED else LABEL_NEAR
	local claimed = model:GetAttribute("ClaimedBy")
	local who = claimed and Players:GetPlayerByUserId(claimed)
	entry.Claim.Text = if who and hp < max then "⛏ " .. who.DisplayName else ""
	if entry.Light then
		-- Crystals blaze brighter as it nears popping.
		entry.Light.Brightness = entry.Base * (1 + Rules.tension(hp, max) * 2.5)
	end
end
local function labelRock(model: Model)
	local body = model.PrimaryPart or model:FindFirstChild("Body") :: BasePart?
	if not body or labels[model] then
		return
	end
	local size = model:GetAttribute("Size") or "Pebble"
	local spec = Rules.Sizes[size] or Rules.Sizes.Pebble
	-- Out along the candy trails: where it grows, and the luck that adds.
	local zone = model:GetAttribute("Zone")
	local band = zone and Frontier.Bands[zone]
	local top = if band then 13 else 0
	local gui = new("BillboardGui", {
		Size = UDim2.fromOffset(150, 40 + top),
		StudsOffsetWorldSpace = Vector3.new(0, spec.Scale * 1.15 + 1.5, 0),
		MaxDistance = LABEL_NEAR,
		LightInfluence = 0,
		AlwaysOnTop = false,
	}, body)
	if band then
		local tag = text(
			gui,
			string.format("%s  ·  +%d%% LUCK", string.upper(band.Name), math.floor(band.Luck * 100 + 0.5)),
			10,
			band.Color,
			IronUi.Bold,
			0,
			0,
			150,
			12,
			Enum.TextXAlignment.Center
		)
		tag.TextStrokeTransparency = 0.3
	end
	local name = text(gui, spec.Name, 13, sizeColor(size), IronUi.Bold, 0, top, 150, 16, Enum.TextXAlignment.Center)
	name.TextStrokeTransparency = 0.3
	local bar = new("Frame", {
		Position = UDim2.fromOffset(25, 18 + top),
		Size = UDim2.fromOffset(100, 6),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		BackgroundTransparency = 0.2,
	}, gui)
	UiKit.round(bar, 3)
	local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = sizeColor(size) }, bar)
	UiKit.round(barFill, 3)
	local claim =
		text(gui, "", 11, Color3.fromRGB(255, 220, 140), IronUi.Bold, 0, 26 + top, 150, 14, Enum.TextXAlignment.Center)
	claim.TextStrokeTransparency = 0.3
	local light = body:FindFirstChildOfClass("PointLight")
	labels[model] =
		{ Gui = gui, Fill = barFill, Name = name, Claim = claim, Light = light, Base = light and light.Brightness or 1 }
	refreshLabel(model)
end

-- Hit and pop effects ---------------------------------------------------------------------------

local function chips(at: Vector3, color: Color3, count: number, speed: number)
	for _ = 1, count do
		local chip = Instance.new("Part")
		chip.Size = Vector3.one * (0.2 + math.random() * 0.35)
		chip.Color = color
		chip.Material = if math.random() < 0.4 then Enum.Material.Neon else Enum.Material.Slate
		chip.CanCollide, chip.CanQuery, chip.CanTouch = false, false, false
		chip.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chip.Parent = workspace
		chip.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * speed,
			speed * (0.5 + math.random() * 0.6),
			(math.random() - 0.5) * speed
		)
		chip.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		tween(chip, 1.1, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chip, 1.2)
	end
end
local function flash(at: Vector3, color: Color3, size: number, seconds: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one * size * 0.3
	ball.Position = at
	ball.Transparency = 0.1
	ball.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, size * 4, 3
	light.Parent = ball
	tween(ball, seconds, { Size = Vector3.one * size, Transparency = 1 })
	tween(light, seconds, { Brightness = 0 })
	Debris:AddItem(ball, seconds + 0.1)
end
-- A quick shudder of the rock (local only; snaps back).
local shaking: { [Model]: boolean } = {}
local function shake(model: Model, strength: number)
	if shaking[model] then
		return
	end
	shaking[model] = true
	local home = model:GetPivot()
	task.spawn(function()
		for i = 1, 5 do
			if not model.Parent then
				break
			end
			local k = strength * (1 - i / 6)
			model:PivotTo(home * CFrame.new((math.random() - 0.5) * k, 0, (math.random() - 0.5) * k))
			task.wait(0.025)
		end
		if model.Parent then
			model:PivotTo(home)
		end
		shaking[model] = nil
	end)
end
local function crystalColor(model: Model): Color3
	for _, d in model:GetChildren() do
		if d.Name == "Crystal" and d:IsA("BasePart") then
			return d.Color
		end
	end
	return Color3.fromRGB(110, 220, 255)
end
local function cameraKick(strength: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
	tween(humanoid, 0.18, { CameraOffset = Vector3.zero })
end
local function floatText(at: Vector3, value: string, color: Color3, size: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = at
	holder.Parent = workspace
	local gui =
		new("BillboardGui", { Size = UDim2.fromOffset(240, 50), AlwaysOnTop = true, LightInfluence = 0 }, holder)
	local label = text(gui, value, size, color, IronUi.Heading, 0, 0, 240, 50, Enum.TextXAlignment.Center)
	label.TextStrokeTransparency = 0.2
	tween(holder, 1.1, { Position = at + Vector3.new(0, 4, 0) })
	tween(
		label,
		1.1,
		{ TextTransparency = 1, TextStrokeTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	Debris:AddItem(holder, 1.2)
end

-- Every swing on any rock (from its attributes): sound, chips, shudder, glow.
local lastHp: { [Model]: number } = {}
local function onRockHit(model: Model)
	local hp, max = model:GetAttribute("Hp") or 0, model:GetAttribute("MaxHp") or 1
	local before = lastHp[model]
	lastHp[model] = hp
	refreshLabel(model)
	if before == nil or hp >= before then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	local mine = model:GetAttribute("LastHitBy") == player.UserId
	local crit = model:GetAttribute("LastCrit") == true
	local tension = Rules.tension(hp, max)
	local at = body.Position + Vector3.new(0, body.Size.Y * 0.3, 0)
	local color = crystalColor(model)
	if active then
		OutpostScene.hitSound(tension, crit, mine, at)
	end
	-- The hitter's pickaxe skin lands its own way (PickImpacts); a plain
	-- pick, just chips and a flash of the rock's crystal.
	local hitter = Players:GetPlayerByUserId(model:GetAttribute("LastHitBy") or 0)
	local character = hitter and hitter.Character
	local pick = character and character:FindFirstChild("OutpostPick")
	local look = pick and PickaxeLooks.Looks[pick:GetAttribute("PickSkin") or ""]
	local hitterRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = hitterRoot and hitterRoot.Position
	local themed = look ~= nil and PickImpacts.play(look.Impact, at, from, tension, crit, if mine then 1 else 0.5)
	chips(at, color, if themed then 2 elseif mine then 6 + math.floor(tension * 6) else 3, 14 + tension * 10)
	if not themed then
		flash(at, color, 2 + tension * 3, 0.25)
	end
	shake(model, 0.25 + tension * 0.5)
	if mine then
		cameraKick(0.15 + tension * 0.25 + (if crit then 0.35 else 0))
		if crit then
			floatText(at + Vector3.new(0, 2, 0), "CRIT!", Color3.fromRGB(255, 214, 90), 30)
		end
	end
end

-- A rock bursts open: a flash dome, shards everywhere.
local function onRockPopped(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local at = body.Position
	local color = crystalColor(model)
	local size = Rules.Sizes[model:GetAttribute("Size") or "Pebble"] or Rules.Sizes.Pebble
	flash(at, color, size.Scale * 2.6, 0.55)
	flash(at, Color3.new(1, 1, 1), size.Scale * 1.2, 0.2)
	chips(at, color, 22, 30)
	chips(at, Color3.fromRGB(110, 106, 116), 14, 22)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			tween(part, 0.35, { Transparency = 1, Size = part.Size * 0.4 })
		end
	end
	if active and (body.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 90 then
		LotterySound.play("SealBreak", 1.1, if model:GetAttribute("Popped") == player.UserId then 1 else 0.4)
	end
end

local function watchRock(model: Instance)
	if not model:IsA("Model") then
		return
	end
	labelRock(model)
	lastHp[model] = model:GetAttribute("Hp")
	model:GetAttributeChangedSignal("Hp"):Connect(function()
		onRockHit(model)
	end)
	model:GetAttributeChangedSignal("ClaimedBy"):Connect(function()
		refreshLabel(model)
	end)
	model:GetAttributeChangedSignal("Popped"):Connect(function()
		onRockPopped(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			labels[model], lastHp[model], shaking[model] = nil, nil, nil
		end
	end)
end

-- The reveal: a lottery for every find ----------------------------------------------------------

local reveal = UiKit.gui("OutpostReveal", 20)
reveal.IgnoreGuiInset = false
local revealCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(420, 150),
	BackgroundColor3 = Color3.fromRGB(12, 14, 24),
	BackgroundTransparency = 0.05,
	Visible = false,
}, reveal)
UiKit.round(revealCard, 10)
local revealStroke = new("UIStroke", { Thickness = 3, Color = P.Gold }, revealCard)
local revealScale = new("UIScale", {}, revealCard)
local reelLabel =
	text(revealCard, "", 34, Color3.new(1, 1, 1), IronUi.Heading, 0, 14, 420, 44, Enum.TextXAlignment.Center)
local gemLabel = text(revealCard, "", 18, Color3.new(1, 1, 1), IronUi.Bold, 0, 64, 420, 24, Enum.TextXAlignment.Center)
local extraLabel =
	text(revealCard, "", 14, Color3.fromRGB(210, 222, 240), IronUi.Bold, 0, 94, 420, 40, Enum.TextXAlignment.Center)
extraLabel.TextWrapped = true
local rewardArt = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 34),
	Size = UDim2.fromOffset(104, 104),
	ClipsDescendants = true,
}, revealCard)
local rewardFit = new("UIScale", {}, reveal)
local function fitReward()
	local size = reveal.AbsoluteSize
	rewardFit.Scale = math.min(1, math.max(0.1, (size.X - 32) / 420), math.max(0.1, (size.Y - 100) / 200))
end
reveal:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitReward)
fitReward()
local revealToken = 0

-- Your loot card (MinerLoot), chat and totals. Other players see the find
-- over your head: the server broadcasts it (MiningWorldReveal).
function OutpostScene.reveal(loot, at: Vector3?)
	if loot.Tutorial then return end
	MinerLoot.push(loot)
	-- (every rock pays one gem: no coins, no gear)
	if loot.Gem then
		local name = loot.Text or GemConfig.displayName(loot.Gem)
		require(script.Parent.ChatFrame).loot("You receive loot: [" .. name .. "]")
	end
	finds.Gems += if loot.Gem then 1 else 0
	finds.Rocks += 1
	refreshHud()
	if loot.Gem then
		revealToken += 1
		revealCard.Visible = false
	end
	if loot.Full then UiKit.toast("Gem pouch full: sell or socket gems!", P.Bad) end
end

-- A secret found: the reveal card, in mystery purple, with its story.
local SECRET = Color3.fromRGB(190, 120, 255)
function OutpostScene.showSecret(secret)
	revealToken += 1
	local token = revealToken
	rewardArt.Visible = false
	reelLabel.Position, reelLabel.Size = UDim2.fromOffset(0, 14), UDim2.fromOffset(420, 44)
	gemLabel.Position, gemLabel.Size = UDim2.fromOffset(0, 64), UDim2.fromOffset(420, 24)
	revealCard.Visible = true
	revealCard.BackgroundTransparency = 0.05
	-- Taller than a loot card, for the story.
	revealCard.Size = UDim2.fromOffset(420, 200)
	extraLabel.Size = UDim2.fromOffset(400, 96)
	extraLabel.Position = UDim2.fromOffset(10, 94)
	revealStroke.Color = SECRET
	reelLabel.Text = if secret.New then "SECRET FOUND!" else "SECRET"
	reelLabel.TextColor3 = SECRET
	gemLabel.Text = string.format("%s  (%d/%d)", secret.Name, secret.Found, secret.Total)
	gemLabel.TextColor3 = Color3.new(1, 1, 1)
	local reward = if secret.New
		then "+" .. (secret.Coins + secret.Bonus) .. " coins" .. (if secret.Bonus > 0
			then "  ·  EVERY SECRET FOUND!"
			else "")
		else "Already found"
	extraLabel.Text = secret.Lore .. "\n" .. reward
	revealScale.Scale = 0.8
	tween(revealScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if secret.New then
		LotterySound.reveal(if secret.Bonus > 0 then 5 else 4)
		require(script.Parent.ChatFrame).loot(
			"You found a secret: [" .. secret.Name .. "] +" .. (secret.Coins + secret.Bonus) .. " coins"
		)
	else
		sound(PING, 1.5, 0.35)
	end
	task.delay(6, function()
		if token == revealToken then
			tween(revealCard, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			if token == revealToken then
				revealCard.Visible = false
			end
		end
	end)
end

-- Mining -----------------------------------------------------------------------------------------------

-- The mech you're piloting, if it can mine (Outpost.Machines, Mine): its
-- spec. Nil on foot; false in a seat that can't.
local function pilotedMech(): any
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = Seating.seatOf(humanoid)
	if not seat then
		return nil
	end
	local machine = Rules.Machines[seat:GetAttribute("OutpostMachine") or ""]
	return if machine and machine.Mine then machine else false
end

local function nearestRock(): Model?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local mech = pilotedMech()
	local best, bestDistance = nil, math.huge
	for _, model in CollectionService:GetTagged(NODE_TAG) do
		local body = model.PrimaryPart
		if body and model:GetAttribute("Popped") == nil then
			local spec = Rules.Sizes[model:GetAttribute("Size") or "Pebble"] or Rules.Sizes.Pebble
			local apart = body.Position - root.Position
			-- (a mech reaches further, measured flat: its cockpit sits high)
			local d = if mech then Vector3.new(apart.X, 0, apart.Z).Magnitude else apart.Magnitude
			if d <= (if mech then Rules.MechReach else Rules.Reach) + spec.Scale / 2 and d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

function OutpostScene.swing(nodeId: number?)
	-- (Not with your combat kit out: 1 puts it away.)
	if not active or Spar.fighting(player) or next(openScreens) ~= nil then
		return
	end
	-- On foot, or from a mech's cockpit; not from any other seat.
	local mech = pilotedMech()
	if mech == false then
		return
	end
	local now = os.clock()
	if now < nextSwing then
		return
	end
	local model = nil
	if nodeId then
		for _, m in CollectionService:GetTagged(NODE_TAG) do
			if m:GetAttribute("NodeId") == nodeId then
				model = m
			end
		end
	else
		model = nearestRock()
	end
	if not model then
		return
	end
	nextSwing = now + (if mech then mech.Mine.Cooldown else Rules.SwingCooldown) + 0.05
	-- Face the rock (on foot: a mech turns as you drive it).
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local body = model.PrimaryPart
	if root and body and not mech then
		local look = Vector3.new(body.Position.X, root.Position.Y, body.Position.Z)
		if (look - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end
	local id = model:GetAttribute("NodeId")
	local at = body and body.Position
	task.spawn(function()
		local result = GemClient.request("OutpostHit", id)
		if result.State then
			state = result.State
			-- (The server only sends the whole profile when a rock pops: keep
			-- the copy's picks current for the screens that read them.)
			local profile = GemClient.Profile
			if profile and profile.Outpost then
				profile.Outpost.Picks, profile.Outpost.Active = state.Picks, state.Active
				profile.Outpost.SurveyAt = state.SurveyAt
			end
			refreshHud()
		end
		if not result.Ok then
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.NoPick or result.PouchFull then P.Bad else nil)
			end
			if result.NoPick then
				OutpostScene.openProbe()
			end
			return
		end
		if result.PickBroke then
			UiKit.toast(
				"Free pick out of charge! +1 swing every "
					.. Rules.FreeSwingSeconds // 60
					.. " min, or buy a refill at PROBE-7.",
				P.Bad
			)
			sound(CLANG, 0.6, 0.6)
			sound(THUD, 0.5, 0.5)
		end
		if result.Loot then
			OutpostScene.reveal(result.Loot, at)
		end
	end)
end

-- The Probe: picks and the Market ---------------------------------------------------------------------

--[[
	PROBE-7's window: your pick (the free Survey Pick in 3D, its charge
	live), then the refills PROBE-7 sells (Shared.Outpost.Refills: swings on
	top of that charge, what each costs, what you'll have after, and BUY or
	how many coins you're short), your coins in the corner, and the player
	market below.

	On a short screen (a phone on its side) the window is as wide as the
	screen and the cards are shorter, so the words stay full size. Where
	everything sits, and what you're short of a price, is ProbeLayout.
]]
local PROBE_SUBTITLE = "A survey probe that crashed here years ago, rewired into the outpost's trading post."
local CARD_TOP = Color3.fromRGB(14, 18, 28)
local TRACK = Color3.fromRGB(30, 36, 52)

local probe =
	IronUi.window("ProbeExchange", 12, ProbeLayout.Desk.W, ProbeLayout.Desk.H, "🛰", Color3.fromRGB(80, 200, 255))
probe.Title.Text = "PROBE-7 EXCHANGE"
probe.Subtitle.Text = PROBE_SUBTITLE
UiKit.fit(probe.Subtitle)
probe.Close.Activated:Connect(function()
	probe.Gui.Enabled = false
end)
-- Your coins, beside the close button.
local wallet = new("Frame", {
	Name = "Wallet",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -64, 0, 18),
	Size = UDim2.fromOffset(132, 32),
	BackgroundColor3 = Color3.fromRGB(20, 25, 37),
	ZIndex = 5,
}, probe.Panel)
UiKit.round(wallet, 16)
new("UIStroke", { Color = P.Gold, Transparency = 0.6, Thickness = 1 }, wallet)
local walletLabel = text(wallet, "◆ 0", 15, P.Gold, IronUi.Heading, 0, 0, 132, 32, Enum.TextXAlignment.Center)
walletLabel.ZIndex = 6
local probeBody = new("Frame", { Name = "Body", BackgroundTransparency = 1 }, probe.Panel)
local probeCoins: number? = nil -- what the cards were drawn with

local function coins(): number
	return GemClient.Profile and GemClient.Profile.Coins or 0
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- A pick in 3D, as PROBE-7 shows it: in its tier's own colour (a skin is
-- looks only), leaning across the card, head and spike side on.
local function pickView(parent: GuiObject, id: string, spec, size: number)
	local view = new("ViewportFrame", {
		Name = "PickView",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 1.5, size),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 152, 168),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 3,
	}, parent)
	view:SetAttribute("Pick", id)
	local model = Instance.new("Model")
	PickaxeLooks.build(model, CFrame.Angles(math.rad(-48), 0, 0), nil, spec.Color, nil, spec.Power > 1)
	model.Parent = view
	local box, extent = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local yaw, pitch = math.rad(100), math.rad(12)
	local reach = math.max(extent.X, extent.Y, extent.Z) * 1.75 + 0.3
	local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	camera.CFrame = CFrame.lookAt(box.Position + offset * reach, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

-- A slab button without the side stripe; greyed out when it can't be used.
local function probeButton(
	parent: GuiObject,
	label: string,
	color: Color3,
	on: boolean,
	x: number,
	y: number,
	w: number,
	h: number,
	size: number,
	onClick: () -> ()
)
	local b, face = IronUi.chunk(parent, {
		Color = if on then color else P.Slot,
		Rim = if on then color else P.Edge,
		Size = UDim2.fromOffset(w, h),
		Radius = 10,
		Lip = 4,
		Stripes = "None",
	})
	b.Position = UDim2.fromOffset(x, y)
	b.ZIndex = 4
	local words = UiKit.fit(IronUi.label(b, face, label, size, IronUi.Heading))
	words.TextColor3 = if on then Color3.new(1, 1, 1) else P.Dim
	b:SetAttribute("UiSound", if on then "Confirm" else "Back")
	b.Activated:Connect(onClick)
	return b
end

-- A small pill on the art: the pick's tier, or IN HAND / OWNED.
local function pill(parent: GuiObject, value: string, color: Color3, filled: boolean, right: boolean, size: number)
	local w = math.ceil(utf8.len(value) * size * 0.72) + 16
	local tag = new("Frame", {
		AnchorPoint = Vector2.new(if right then 1 else 0, 0),
		Position = UDim2.new(if right then 1 else 0, if right then -8 else 8, 0, 8),
		Size = UDim2.fromOffset(w, size + 10),
		BackgroundColor3 = if filled then color else Color3.fromRGB(10, 13, 22),
		BackgroundTransparency = if filled then 0 else 0.25,
		ZIndex = 5,
	}, parent)
	UiKit.round(tag, 8)
	new("UIStroke", { Color = color, Transparency = if filled then 1 else 0.35, Thickness = 1 }, tag)
	local words = UiKit.fit(
		text(
			tag,
			value,
			size,
			if filled then Color3.fromRGB(10, 13, 22) else color,
			IronUi.Heading,
			6,
			0,
			w - 12,
			size + 10,
			Enum.TextXAlignment.Center
		)
	)
	words.ZIndex = 6
	return tag
end

-- One row: a name, a bar (when there's one to show), a value.
local function statRow(card: GuiObject, L, y: number, label: string, value: string, share: number?, color: Color3)
	local phone = L.Phone
	local labelW, valueW = if phone then 50 else 58, if phone then 40 else 46
	if share == nil then
		labelW, valueW = if phone then 72 else 84, L.CardW - 24 - (if phone then 72 else 84)
	end
	local name = UiKit.fit(text(card, label, if phone then 10 else 11, P.Dim, IronUi.Bold, 12, y, labelW, L.Row))
	name.ZIndex = 3
	if share ~= nil then
		local bar = new("Frame", {
			Position = UDim2.fromOffset(12 + labelW, y + math.floor(L.Row / 2) - 2),
			Size = UDim2.fromOffset(L.CardW - 24 - labelW - valueW - 8, 5),
			BackgroundColor3 = TRACK,
			ZIndex = 3,
		}, card)
		UiKit.round(bar, 3)
		if share > 0 then
			local fillBar = new("Frame", {
				Size = UDim2.fromScale(math.clamp(share, 0.04, 1), 1),
				BackgroundColor3 = color,
				ZIndex = 4,
			}, bar)
			UiKit.round(fillBar, 3)
		end
	end
	local amount = UiKit.fit(
		text(
			card,
			value,
			if phone then 12 else 13,
			P.Text,
			IronUi.Heading,
			L.CardW - 12 - valueW,
			y,
			valueW,
			L.Row,
			Enum.TextXAlignment.Right
		)
	)
	amount.ZIndex = 3
end

local drawProbe
local function buyRefill(id: string)
	task.spawn(function()
		local result = GemClient.request("OutpostBuyRefill", id)
		UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
		if result.State then
			state = result.State
			refreshHud()
			drawProbe()
		end
		if result.Ok then
			sound(PING, 1.5, 0.4)
			sound(PING, 2, 0.35, nil, 0.08)
		end
	end)
end

-- A card's frame, tinted in `color`, and its art well (a soft glow, rings
-- fading out; on the pick's, a shadow for it to stand over).
local function probeCard(L, index: number, name: string, color: Color3, lit: boolean, pedestal: boolean)
	local card = new("Frame", {
		Name = name,
		Position = UDim2.fromOffset((index - 1) * (L.CardW + L.Gap), 0),
		Size = UDim2.fromOffset(L.CardW, L.CardH),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
	}, probeBody)
	UiKit.round(card, 12)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(CARD_TOP, 0.84), CARD_TOP:Lerp(Color3.new(), 0.3)),
	}, card)
	new("UIStroke", {
		Color = if lit then color else color:Lerp(P.Edge, 0.5),
		Transparency = if lit then 0 else 0.45,
		Thickness = if lit then 2 else 1,
	}, card)
	local art = new("Frame", { Name = "Art", Size = UDim2.new(1, 0, 0, L.ArtH), BackgroundTransparency = 1 }, card)
	-- (the wash fading down is a layer of its own, so what's drawn on the art
	-- stays crisp)
	local wash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		ZIndex = 2,
	}, art)
	UiKit.round(wash, 12)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, wash)
	for ring, share in { 1.25, 0.9, 0.55 } do
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(L.ArtH * share, L.ArtH * share),
			BackgroundColor3 = color,
			BackgroundTransparency = (if lit then 0.9 else 0.93) - ring * 0.012,
			ZIndex = 2,
		}, art)
		UiKit.round(glow, L.ArtH)
	end
	if pedestal then
		local shadow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.fromOffset(L.ArtH * 0.9, math.max(4, L.ArtH * 0.07)),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.6,
			ZIndex = 2,
		}, art)
		UiKit.round(shadow, L.ArtH)
	end
	return card, art
end

-- A card's name and (on a desktop) its line.
local function cardTitle(card: GuiObject, L, name: string, blurb: string, color: Color3)
	local phone = L.Phone
	local title = UiKit.fit(
		text(
			card,
			name,
			if phone then 17 else 21,
			color:Lerp(Color3.new(1, 1, 1), 0.25),
			Enum.Font.GothamBlack,
			12,
			L.NameY,
			L.CardW - 24,
			if phone then 20 else 24
		)
	)
	title.ZIndex = 3
	if not phone then
		local line = UiKit.fit(text(card, blurb, 12, P.Dim, IronUi.Body, 12, L.NameY + 25, L.CardW - 24, 16))
		line.ZIndex = 3
	end
end

-- A card's footer: a line (what, how many), a bar, and under them the button.
local function cardFooter(card: GuiObject, L)
	local phone = L.Phone
	local y, width = L.FootY, L.CardW - 24
	local info = UiKit.fit(text(card, "", if phone then 11 else 12, P.Dim, IronUi.Bold, 12, y, width - 70, 14))
	local count = text(
		card,
		"",
		if phone then 12 else 13,
		P.Text,
		IronUi.Heading,
		L.CardW - 12 - 90,
		y - 1,
		90,
		16,
		Enum.TextXAlignment.Right
	)
	info.ZIndex, count.ZIndex = 3, 3
	local track = new("Frame", {
		Position = UDim2.fromOffset(12, y + 18),
		Size = UDim2.fromOffset(width, 6),
		BackgroundColor3 = TRACK,
		ClipsDescendants = true,
		ZIndex = 3,
	}, card)
	UiKit.round(track, 3)
	return info, count, track, y + 30
end

-- Your pick: the free Survey Pick and its charge, live (refreshCharge).
local function pickCard(L)
	local id = Rules.PickOrder[1]
	local spec = Rules.Picks[id]
	local phone = L.Phone
	local swings = ChargeMeter.read(state.Picks, state.SurveyAt)
	local card, art = probeCard(L, 1, "Pick" .. id, spec.Color, true, true)
	pickView(art, id, spec, L.ArtH)
	pill(art, spec.Tag or "", spec.Color, false, false, if phone then 9 else 10)
	pill(art, "IN HAND", spec.Color, true, true, if phone then 9 else 10)
	cardTitle(card, L, spec.Name, spec.Blurb or "", spec.Color)
	local y = L.StatsY
	statRow(card, L, y, "FULL CHARGE", spec.Swings .. " swings", nil, spec.Color)
	statRow(
		card,
		L,
		y + L.Row,
		"RECHARGE",
		string.format("+1 every %d min", Rules.FreeSwingSeconds // 60),
		nil,
		spec.Color
	)
	local extra = math.max(0, swings - ChargeMeter.Full)
	statRow(card, L, y + L.Row * 2, "EXTRA", if extra > 0 then "+" .. commas(extra) else "none", nil, spec.Color)

	local info, count, track, buttonY = cardFooter(card, L)
	local fillBar = new("Frame", { Size = UDim2.fromScale(0, 1), ZIndex = 4 }, track)
	UiKit.round(fillBar, 3)
	local next =
		new("Frame", { BackgroundColor3 = ChargeMeter.Charging, BackgroundTransparency = 0.55, ZIndex = 4 }, track)
	local status = text(
		card,
		"",
		if phone then 11 else 12,
		P.Dim,
		IronUi.Body,
		12,
		buttonY,
		L.CardW - 24,
		L.ButtonH,
		Enum.TextXAlignment.Center
	)
	status.TextWrapped = true
	status.ZIndex = 3
	probeCharge = {
		set = function(now: number, nextIn: number?, progress: number)
			local full = nextIn == nil
			local color = if full then ChargeMeter.Charged else ChargeMeter.Charging
			info.Text = if full then "⚡ CHARGED" else "⚡ CHARGING"
			info.TextColor3 = color
			count.Text = ChargeMeter.count(now)
			count.TextColor3 = if now > 0 then P.Text else P.Bad
			local share = math.clamp(now / ChargeMeter.Full, 0, 1)
			fillBar.Size = UDim2.fromScale(share, 1)
			fillBar.BackgroundColor3 = color
			next.Visible = not full
			next.Position = UDim2.fromScale(share, 0)
			next.Size = UDim2.fromScale(math.clamp(progress, 0, 1) / ChargeMeter.Full, 1)
			status.Text = ChargeMeter.status(now, nextIn)
			status.TextColor3 = if full then ChargeMeter.Charged else P.Dim
		end,
	}
end

-- A refill PROBE-7 sells: its swings in big figures, what each costs, what
-- you'll have after, and BUY (or how many coins you're short).
local function refillCard(L, index: number, id: string)
	local refill = Rules.Refills[id]
	local phone = L.Phone
	local card, art = probeCard(L, index, "Refill" .. id, refill.Color, false, false)
	-- The art: the swings it adds, glowing.
	local figure = UiKit.fit(
		text(
			art,
			"⚡+" .. refill.Swings,
			math.floor(L.ArtH * 0.4),
			refill.Color:Lerp(Color3.new(1, 1, 1), 0.2),
			Enum.Font.GothamBlack,
			0,
			math.floor(L.ArtH * 0.18),
			L.CardW,
			math.floor(L.ArtH * 0.46),
			Enum.TextXAlignment.Center
		)
	)
	figure.ZIndex = 3
	if not phone then
		local unit = text(
			art,
			"SWINGS",
			11,
			refill.Color,
			IronUi.Heading,
			0,
			math.floor(L.ArtH * 0.64),
			L.CardW,
			14,
			Enum.TextXAlignment.Center
		)
		unit.ZIndex = 3
	end
	pill(art, refill.Tag or "", refill.Color, false, false, if phone then 9 else 10)
	-- (a phone's art is too short for a second tag: the saving goes in EACH)
	local save = ProbeLayout.saving(refill, Rules.Refills[Rules.RefillOrder[1]])
	if save > 0 and not phone then
		pill(art, string.format("SAVE %d%%", save), refill.Color, true, true, 10)
	end
	cardTitle(card, L, refill.Name, refill.Blurb or "", refill.Color)
	local swings = ChargeMeter.read(state.Picks, state.SurveyAt)
	local after = swings + refill.Swings
	local y = L.StatsY
	statRow(card, L, y, "SWINGS", "+" .. refill.Swings, nil, refill.Color)
	local each = refill.Price / refill.Swings
	statRow(
		card,
		L,
		y + L.Row,
		"EACH",
		"◆ "
			.. (if each % 1 == 0 then tostring(math.floor(each)) else string.format("%.1f", each))
			.. (if save > 0 and phone then string.format(" · -%d%%", save) else ""),
		nil,
		refill.Color
	)
	statRow(card, L, y + L.Row * 2, "YOU'LL HAVE", commas(after) .. " swings", nil, refill.Color)

	-- The bar: what you have, and what this adds on top.
	local info, count, track, buttonY = cardFooter(card, L)
	info.Text = "PRICE"
	count.Text = "◆ " .. commas(refill.Price)
	count.TextColor3 = P.Gold
	local have = new("Frame", {
		Size = UDim2.fromScale(math.clamp(swings / after, 0, 1), 1),
		BackgroundColor3 = P.Dim,
		BackgroundTransparency = 0.45,
		ZIndex = 4,
	}, track)
	UiKit.round(have, 3)
	local adds = new("Frame", {
		Position = UDim2.fromScale(math.clamp(swings / after, 0, 1), 0),
		Size = UDim2.fromScale(math.clamp(refill.Swings / after, 0, 1), 1),
		BackgroundColor3 = refill.Color,
		ZIndex = 4,
	}, track)
	UiKit.round(adds, 3)
	local short = ProbeLayout.short(refill.Price, coins())
	probeButton(
		card,
		if short <= 0 then "BUY" else string.format("NEED ◆ %s MORE", commas(short)),
		refill.Color,
		short <= 0,
		12,
		buttonY,
		L.CardW - 24,
		L.ButtonH,
		if phone then 13 else 15,
		function()
			if short <= 0 then
				buyRefill(id)
			else
				UiKit.toast(string.format("You need %s more coins.", commas(short)), P.Bad)
			end
		end
	)
end

-- The player market, under the picks.
local function marketBanner(L)
	local phone = L.Phone
	local w, h = L.W - L.Side * 2, L.MarketH
	local banner = new("TextButton", {
		Name = "Market",
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, L.CardH + L.Gap),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, probeBody)
	UiKit.round(banner, 12)
	new("UIGradient", {
		Color = ColorSequence.new(P.Gold:Lerp(CARD_TOP, 0.8), CARD_TOP),
	}, banner)
	new("UIStroke", { Color = P.Gold, Transparency = 0.55, Thickness = 1 }, banner)
	IronUi.highlight(banner)
	local open = function()
		probe.Gui.Enabled = false
		require(script.Parent.MarketBoardUI).open()
	end
	banner.Activated:Connect(open)
	local chip = if phone then 28 else 38
	local icon = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(chip, chip),
		BackgroundColor3 = P.Gold:Lerp(CARD_TOP, 0.65),
		ZIndex = 2,
	}, banner)
	UiKit.round(icon, chip)
	new("UIStroke", { Color = P.Gold, Transparency = 0.4, Thickness = 1 }, icon)
	local glyph =
		text(icon, "🤝", if phone then 14 else 19, P.Text, IronUi.Body, 0, 0, chip, chip, Enum.TextXAlignment.Center)
	glyph.ZIndex = 3
	local buttonW, buttonH = if phone then 112 else 156, if phone then 30 else 38
	local left = 10 + chip + 10
	local room = w - left - buttonW - 20
	local title = text(
		banner,
		"PLAYER MARKET",
		if phone then 13 else 15,
		P.Gold,
		Enum.Font.GothamBlack,
		left,
		if phone then 4 else 9,
		room,
		if phone then 16 else 20
	)
	title.ZIndex = 2
	local sub = text(
		banner,
		"Buy, sell and trade gems and gear with other miners.",
		if phone then 11 else 12,
		P.Dim,
		IronUi.Body,
		left,
		if phone then 21 else 30,
		room,
		15
	)
	sub.ZIndex = 2
	probeButton(
		banner,
		"OPEN MARKET",
		P.Gold,
		true,
		w - buttonW - 10,
		math.floor((h - buttonH) / 2),
		buttonW,
		buttonH,
		if phone then 12 else 15,
		open
	)
end

function drawProbe()
	probeBody:ClearAllChildren()
	probeCharge = nil
	if not state then
		return
	end
	local screen = probe.Gui.AbsoluteSize
	local L = ProbeLayout.design(screen.X, screen.Y)
	local phone = L.Phone
	probe.Resize(L.W, L.H)
	probe.Subtitle.Text = if phone then "Refills, and the player market." else PROBE_SUBTITLE
	probe.Subtitle.Size = UDim2.new(0, L.W - 69 - 64 - 132 - 16, 0, 16)
	probeBody.Position = UDim2.fromOffset(L.Side, L.Top)
	probeBody.Size = UDim2.new(1, -L.Side * 2, 1, -L.Top)
	probeCoins = coins()
	walletLabel.Text = "◆ " .. commas(probeCoins)
	pickCard(L)
	for i, id in Rules.RefillOrder do
		refillCard(L, i + 1, id)
	end
	marketBanner(L)
	refreshCharge()
end
-- Coins changed while it's open (a sale, a payout): redraw what you can afford.
GemClient.Changed:Connect(function()
	if probe.Gui.Enabled and probeCoins ~= coins() then
		drawProbe()
	end
end)
-- A phone turned, a window resized: the design for the new screen.
probe.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if probe.Gui.Enabled then
		drawProbe()
	end
end)
function OutpostScene.openProbe()
	probe.Gui.Enabled = true
	drawProbe()
end

-- Prompts: rocks, the Probe, the gate, other miners -----------------------------------------------------

local SOCIAL_KINDS = { Spar = true, Duel = true, Party = true }

-- Another miner's Duel, Spar and Party: one card beside them (PlayerCard).
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if SOCIAL_KINDS[prompt:GetAttribute("PromptKind")] then
		PlayerCard.shown(prompt, inputType)
	end
end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if SOCIAL_KINDS[prompt:GetAttribute("PromptKind")] then
		PlayerCard.holding(prompt, true)
	end
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if SOCIAL_KINDS[prompt:GetAttribute("PromptKind")] then
		PlayerCard.holding(prompt, false)
	end
end)

-- A small, clickable instruction instead of Roblox's large E + rock-name panel.
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt:GetAttribute("PromptKind") ~= "Mine" then return end
	if miningPrompts[prompt] then miningPrompts[prompt]:Destroy() end
	local promptGui = new("BillboardGui", {
		Name = "ClickToMine", Adornee = prompt.Parent, AlwaysOnTop = true, Active = true,
		Size = UDim2.fromOffset(144, 36), StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0),
		Enabled = hud.Enabled and next(openScreens) == nil,
	}, player.PlayerGui)
	miningPrompts[prompt] = promptGui
	local instruction = if inputType == Enum.ProximityPromptInputType.Touch then "Tap to mine"
		elseif inputType == Enum.ProximityPromptInputType.Gamepad then "X to mine"
		else "Click to mine"
	local button = new("TextButton", {
		Text = instruction, Font = IronUi.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(230, 248, 255), Active = true,
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 25, 34), BackgroundTransparency = 0.12,
	}, promptGui)
	UiKit.round(button, 9)
	new("UIStroke", { Color = Color3.fromRGB(118, 211, 230), Transparency = 0.45 }, button)
	button.Activated:Connect(function() OutpostScene.swing(prompt:GetAttribute("NodeId")) end)
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	local promptGui = miningPrompts[prompt]
	if promptGui then promptGui:Destroy(); miningPrompts[prompt] = nil end
	PlayerCard.hidden(prompt)
end)

-- Duel, Spar or Party on another miner: from their prompt's key, or a
-- click or tap on their card.
local function socialAction(kind: string, target: number)
	if not active or target == player.UserId then
		return
	end
	if kind == "Spar" then
		-- A friendly spar: they get a card to accept (Shared.Spar).
		task.spawn(function()
			local result = GemClient.request("SparAsk", target)
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
			end
		end)
	elseif kind == "Duel" then
		local other = Players:GetPlayerByUserId(target)
		ChallengeChooser.open(target, other and other.DisplayName)
	elseif kind == "Party" then
		task.spawn(function()
			local result = GemClient.request("PartyInvite", target)
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
			end
		end)
	end
end
PlayerCard.onAction(socialAction)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or not active then
		return
	end
	local kind = prompt:GetAttribute("PromptKind")
	if kind == "Mine" then
		OutpostScene.swing(prompt:GetAttribute("NodeId"))
	elseif kind == "Probe" then
		OutpostScene.openProbe()
	elseif kind == "Gate" then
		require(script.Parent.SocialUI).open()
	elseif kind == "Secret" then
		task.spawn(function()
			local result = GemClient.request("OutpostSecret", prompt:GetAttribute("SecretId"))
			if result.Ok and result.Secret then
				if result.State then
					state = result.State
					refreshHud()
				end
				OutpostScene.showSecret(result.Secret)
			elseif result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, P.Bad)
			end
		end)
	elseif SOCIAL_KINDS[kind] then
		socialAction(kind, prompt:GetAttribute("TargetUserId"))
	end
end)
-- Your own spar/duel/party prompts aren't for you.
local function hideOwnPrompts(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local function hide(child: Instance)
		if child:IsA("ProximityPrompt") and child:GetAttribute("TargetUserId") == player.UserId then
			child.Enabled = false
		end
	end
	for _, child in root:GetChildren() do
		hide(child)
	end
	root.ChildAdded:Connect(hide)
end
if player.Character then
	task.spawn(hideOwnPrompts, player.Character)
end
player.CharacterAdded:Connect(hideOwnPrompts)

-- Click / tap a rock to swing at the nearest one in reach.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not active or Spar.fighting(player) then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		OutpostScene.swing(nil)
	end
end)

-- Entering and leaving -------------------------------------------------------------------------------------

local function setWalking(on: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return
	end
	pcall(function()
		local controls = require(module):GetControls()
		if on then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function showWorld()
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	if dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled then
		dashboard.Enabled = false
		hiddenDashboard = dashboard
	end
	Scenes.outpostLighting()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
	ThirdPerson.enter(if typeof(spawn) == "CFrame" then spawn else nil)
	setWalking(true)
	hud.Enabled = player:GetAttribute("CombatSession") == nil
end

local function enterScene(result)
	state = result.State
	finds = { Gems = 0, Rocks = 0 }
	active = true
	showWorld()
	refreshHud()
	UiKit.toast("Welcome to Saga Outpost. Rocks grow back after they're mined out.", P.Gold)
end

local function exitScene()
	if not active then
		return
	end
	active = false
	hud.Enabled = false
	probe.Gui.Enabled = false
	revealCard.Visible = false
	revealToken += 1
	MiningReveal.close()
	MinerLoot.close()
	fitOutpostHud()
	setWalking(false)
	ThirdPerson.exit()
	if hiddenDashboard then
		hiddenDashboard.Enabled = true
		hiddenDashboard = nil
	end
end

-- The loading screen up over the trip (LoadingFlow), before you're moved:
-- down once you're standing in the basin with it loaded round you.
local function goingIn()
	local cover = LoadingFlow.hold("Outpost", {
		FadeIn = 0.25,
		Destination = function()
			local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
			local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
			return if typeof(spawn) == "CFrame" then spawn.Position else nil
		end,
	})
	LoadingFlow.waitCovered(1)
	return cover
end

function OutpostScene.enter()
	if busy or active then
		return
	end
	busy = true
	task.spawn(function()
		local cover = goingIn()
		local result = GemClient.request("OutpostEnter")
		busy = false
		if not result.Ok then
			cover.cancel()
			UiKit.toast(result.Message, P.Bad)
			return
		end
		enterScene(result)
	end)
end

function OutpostScene.leave()
	if busy or not active then
		return
	end
	busy = true
	task.spawn(function()
		GemClient.request("OutpostLeave")
		busy = false
		exitScene()
	end)
end

function OutpostScene.isActive(): boolean
	return active
end

-- Never stranded: puts you back in the basin if anything knocked you out of
-- it (the scene closed, or the server no longer has you there). `respawn`
-- also walks you back to the spawn when you're already in (UNSTUCK).
local lastEnsure = 0
function OutpostScene.ensure(respawn: boolean?)
	if busy or os.clock() - lastEnsure < 2 then
		return
	end
	if active and player:GetAttribute("Outpost") and not respawn then
		return
	end
	lastEnsure = os.clock()
	busy = true
	task.spawn(function()
		local cover = goingIn()
		local result = GemClient.request("OutpostEnter")
		busy = false
		if not result.Ok then
			cover.cancel()
			if respawn then
				UiKit.toast(result.Message, P.Bad)
			end
			return
		end
		if active then
			state = result.State or state
			showWorld()
			refreshHud()
		else
			enterScene(result)
		end
	end)
end

-- HUD buttons.
for _, spec in
	{
		-- Stuck behind a rock or off a ledge? Back to the Outpost spawn.
		{
			"UNSTUCK",
			Color3.fromRGB(170, 120, 70),
			function()
				OutpostScene.ensure(true)
			end,
		},
		{
			"SOCIAL",
			P.Teal,
			function()
				require(script.Parent.SocialUI).open()
			end,
		},
		{
			"PROBE",
			Color3.fromRGB(80, 200, 255),
			function()
				UiKit.toast("Walk to PROBE-7 (the crashed probe, east side) and press E.", P.Gold)
			end,
		},
	}
do
	local b = IronUi.gemButton(buttons, spec[1], spec[2], spec[3])
	b.Size = UDim2.fromOffset(84, 36)
	b.TextSize = 13
end

-- A finished duel (or a respawn) brings you back: show the world again.
player:GetAttributeChangedSignal("CombatSession"):Connect(function()
	if active then
		task.defer(function()
			if player:GetAttribute("CombatSession") == nil and player:GetAttribute("Outpost") then
				showWorld()
			else
				hud.Enabled = false
				MiningReveal.close()
				MinerLoot.close()
				fitOutpostHud()
			end
		end)
	end
end)
player:GetAttributeChangedSignal("Outpost"):Connect(function()
	if active and not player:GetAttribute("Outpost") then
		exitScene()
	end
end)

-- Rocks, as they grow; the Probe's ring turning; beacons blinking.
for _, model in CollectionService:GetTagged(NODE_TAG) do
	watchRock(model)
end
CollectionService:GetInstanceAddedSignal(NODE_TAG):Connect(watchRock)
task.spawn(function()
	while true do
		task.wait(1)
		if active then
			refreshCharge()
			if expanded and os.clock() >= collapseAt then
				expanded = false
				fitOutpostHud()
			end
		end
	end
end)
-- The frontier: rifts tearing open out past the core, and a banner as you
-- cross from band to band.
RiftTear.start()
FrontierHud.start()
RunService.RenderStepped:Connect(function(dt)
	-- The rift in the sky shows only while you're here.
	if active then
		SkyRift.mount(Rules.Location)
	end
	SkyRift.show(active)
	if not active then
		return
	end
	SkyRift.step(dt)
	RiftTear.step(workspace:GetServerTimeNow())
	local site = workspace:FindFirstChild("SagaOutpost")
	local ring = site and site:FindFirstChild("Probe") and site.Probe:FindFirstChild("ProbeRing")
	if ring and ring:IsA("BasePart") then
		ring.CFrame = ring.CFrame * CFrame.Angles(0.004, 0, 0)
	end
end)

return OutpostScene
