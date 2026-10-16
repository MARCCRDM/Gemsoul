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
	  Probe      PROBE-7, the crashed probe: buy picks, open the Market.
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
local PickaxeLooks = require(ReplicatedStorage.Shared.PickaxeLooks)
local Spar = require(ReplicatedStorage.Shared.Spar)
local ChallengeChooser = require(script.Parent.ChallengeChooser)
local ChargeMeter = require(script.Parent.ChargeMeter)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local LoadingFlow = require(script.Parent.LoadingFlow)
local LotterySound = require(script.Parent.LotterySound)
local MobileLayout = require(script.Parent.MobileLayout)
local MiningReveal = require(script.Parent.MiningWorldReveal)
local PickImpacts = require(script.Parent.PickImpacts)
-- Driving the Motor Pool's machines (runs on its own once loaded).
require(script.Parent.VehicleDrive)
local Scenes = require(script.Parent.Scenes)
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
local finds = { Gems = 0, Coins = 0, Gear = 0, Rocks = 0 }
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
	findsLabel.Text = string.format(
		"This trip: %d gem%s · %d coins · %d gear",
		finds.Gems,
		if finds.Gems == 1 then "" else "s",
		finds.Coins,
		finds.Gear
	)
	recordLabel.Text = string.format("%d rocks mined", state.Rocks or 0)
end

-- Rock labels -------------------------------------------------------------------------------------

local labels: { [Model]: { Gui: BillboardGui, Fill: Frame, Name: TextLabel, Claim: TextLabel, Light: PointLight?, Base: number } } =
	{}
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
	local gui = new("BillboardGui", {
		Size = UDim2.fromOffset(150, 40),
		StudsOffsetWorldSpace = Vector3.new(0, spec.Scale * 1.15 + 1.5, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		AlwaysOnTop = false,
	}, body)
	local name = text(gui, spec.Name, 13, sizeColor(size), IronUi.Bold, 0, 0, 150, 16, Enum.TextXAlignment.Center)
	name.TextStrokeTransparency = 0.3
	local bar = new("Frame", {
		Position = UDim2.fromOffset(25, 18),
		Size = UDim2.fromOffset(100, 6),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		BackgroundTransparency = 0.2,
	}, gui)
	UiKit.round(bar, 3)
	local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = sizeColor(size) }, bar)
	UiKit.round(barFill, 3)
	local claim =
		text(gui, "", 11, Color3.fromRGB(255, 220, 140), IronUi.Bold, 0, 26, 150, 14, Enum.TextXAlignment.Center)
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

-- Personal totals/logging only; the server broadcasts the shared world lottery.
function OutpostScene.reveal(loot, at: Vector3?)
	if loot.Tutorial then return end
	local found = {}
	if loot.Gem then table.insert(found, "[" .. (loot.Text or GemConfig.displayName(loot.Gem)) .. "]") end
	if loot.Gear then table.insert(found, "[" .. tostring(loot.Gear) .. "]") end
	if loot.Coins then table.insert(found, loot.Coins .. " coins") end
	if #found > 0 then
		require(script.Parent.ChatFrame).loot("You receive loot: " .. table.concat(found, ", "))
	end
	finds.Gems += if loot.Gem then 1 else 0
	finds.Coins += loot.Coins or 0
	finds.Gear += if loot.Gear then 1 else 0
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
	local seat = humanoid and humanoid.SeatPart
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
			refreshHud()
		end
		if not result.Ok then
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.NoPick then P.Bad else nil)
			end
			if result.NoPick then
				OutpostScene.openProbe()
			end
			return
		end
		if result.PickBroke then
			UiKit.toast(
				if result.PickBroke == Rules.Picks.Survey.Name
					then "Free pick out of charge! +1 swing every "
						.. Rules.FreeSwingSeconds // 60
						.. " min, or buy a pick at PROBE-7."
					else "Your " .. result.PickBroke .. " broke! Get another at PROBE-7.",
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

local probe = IronUi.window("ProbeExchange", 12, 760, 430, "🛰", Color3.fromRGB(80, 200, 255))
probe.Title.Text = "PROBE-7 EXCHANGE"
probe.Subtitle.Text = "A survey probe that crashed here years ago, rewired into the outpost's trading post."
probe.Close.Activated:Connect(function()
	probe.Gui.Enabled = false
end)
local probeBody = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 84),
	Size = UDim2.new(1, -40, 1, -104),
}, probe.Panel)
local function drawProbe()
	probeBody:ClearAllChildren()
	probeCharge = nil
	if not state then
		return
	end
	for i, id in Rules.PickOrder do
		local spec = Rules.Picks[id]
		local owned = state.Picks[id] or 0
		local box = new("Frame", {
			Position = UDim2.fromOffset((i - 1) * 244, 0),
			Size = UDim2.fromOffset(230, 250),
			BackgroundColor3 = Color3.fromRGB(20, 26, 42),
		}, probeBody)
		UiKit.round(box, 8)
		new(
			"UIStroke",
			{ Color = spec.Color, Transparency = if state.Active == id then 0 else 0.6, Thickness = 2 },
			box
		)
		text(box, spec.Name, 20, spec.Color, IronUi.Heading, 14, 12, 210, 24)
		text(
			box,
			if spec.Price > 0
				then string.format("%d swings", spec.Swings)
				else string.format("%d swings · recharges", spec.Swings),
			14,
			Color3.new(1, 1, 1),
			IronUi.Bold,
			14,
			44,
			210,
			18
		)
		text(
			box,
			if spec.Power > 1 then "Chips 2 layers a swing" else "Chips 1 layer a swing",
			13,
			Color3.fromRGB(200, 214, 235),
			IronUi.Body,
			14,
			66,
			210,
			16
		)
		text(
			box,
			string.format("Crit chance +%d%%", math.floor(spec.Crit * 100 + 0.5)),
			13,
			Color3.fromRGB(200, 214, 235),
			IronUi.Body,
			14,
			86,
			210,
			16
		)
		text(
			box,
			if spec.Price == 0
				then string.format("Free · +1 swing every %d min", Rules.FreeSwingSeconds // 60)
				elseif owned > 0 then string.format("You have: %d swings", owned)
				else "You have none",
			13,
			if owned > 0 then P.Good else Color3.fromRGB(150, 160, 180),
			IronUi.Bold,
			14,
			112,
			210,
			16
		)
		if spec.Price > 0 then
			local buy = IronUi.gemButton(box, string.format("BUY  %d COINS", spec.Price), spec.Color, function()
				task.spawn(function()
					local result = GemClient.request("OutpostBuyPick", id)
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
			end)
			buy.Position, buy.Size = UDim2.fromOffset(14, 150), UDim2.fromOffset(202, 38)
		else
			probeCharge = ChargeMeter.new(box, 14, 144, 202)
		end
		if owned > 0 and state.Active ~= id then
			local equip = IronUi.gemButton(box, "TAKE IN HAND", Color3.fromRGB(110, 120, 140), function()
				task.spawn(function()
					local result = GemClient.request("OutpostEquipPick", id)
					if result.State then
						state = result.State
						refreshHud()
						drawProbe()
					end
				end)
			end)
			equip.Position, equip.Size = UDim2.fromOffset(14, 198), UDim2.fromOffset(202, 36)
		elseif state.Active == id then
			text(box, "IN HAND", 14, spec.Color, IronUi.Bold, 14, 206, 210, 20)
		end
	end
	local market = IronUi.gemButton(probeBody, "OPEN THE MARKET  ·  BUY, SELL & TRADE", P.Gold, function()
		probe.Gui.Enabled = false
		require(script.Parent.MarketBoardUI).open()
	end)
	market.Position, market.Size = UDim2.fromOffset(0, 266), UDim2.fromOffset(720, 44)
end
function OutpostScene.openProbe()
	probe.Gui.Enabled = true
	probe.Fit()
	drawProbe()
	refreshCharge()
end

-- Prompts: rocks, the Probe, the gate, other miners -----------------------------------------------------

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
end)

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
	elseif kind == "Spar" or kind == "Duel" or kind == "Party" then
		local target = prompt:GetAttribute("TargetUserId")
		if target == player.UserId then
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
			return
		end
		if kind == "Duel" then
			local other = Players:GetPlayerByUserId(target)
			ChallengeChooser.open(target, other and other.DisplayName)
			return
		end
		task.spawn(function()
			local result = GemClient.request("PartyInvite", target)
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
			end
		end)
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
	finds = { Gems = 0, Coins = 0, Gear = 0, Rocks = 0 }
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
RunService.RenderStepped:Connect(function()
	if not active then
		return
	end
	local site = workspace:FindFirstChild("SagaOutpost")
	local ring = site and site:FindFirstChild("Probe") and site.Probe:FindFirstChild("ProbeRing")
	if ring and ring:IsA("BasePart") then
		ring.CFrame = ring.CFrame * CFrame.Angles(0.004, 0, 0)
	end
end)

return OutpostScene
