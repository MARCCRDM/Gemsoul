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
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local LotterySound = require(script.Parent.LotterySound)
local Scenes = require(script.Parent.Scenes)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local OutpostScene = {}

local NODE_TAG = "OutpostNode"
local active, busy = false, false
local state = nil -- picks and record, from the server
local finds = { Gems = 0, Coins = 0, Gear = 0, Rocks = 0 }
local nextSwing = 0
local hiddenDashboard: ScreenGui? = nil

local RARITY_NAMES = { "COMMON", "UNCOMMON", "RARE", "ULTRA-RARE", "LEGENDARY" }
local RARITY_COLORS = {
	GemConfig.TierColors.Common,
	GemConfig.TierColors.Uncommon,
	GemConfig.TierColors.Rare,
	GemConfig.TierColors.UltraRare,
	GemConfig.TierColors.Legendary,
}

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
hud.IgnoreGuiInset = true
hud.Enabled = false
local card = new("Frame", {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.fromOffset(300, 196),
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
text(card, "SAGA OUTPOST", 22, P.Gold, IronUi.Heading, 14, 10, 270, 26)
text(
	card,
	"Lunar basin · mine, trade at PROBE-7, duel",
	11,
	Color3.fromRGB(170, 190, 215),
	IronUi.Body,
	14,
	36,
	280,
	14
)
local pickName = text(card, "Survey Pick", 15, Color3.new(1, 1, 1), IronUi.Bold, 14, 58, 200, 18)
local pickSwings = text(card, "60 swings", 13, P.Gold, IronUi.Bold, 186, 58, 100, 18, Enum.TextXAlignment.Right)
local track = new("Frame", {
	Position = UDim2.fromOffset(14, 80),
	Size = UDim2.fromOffset(272, 8),
	BackgroundColor3 = Color3.fromRGB(34, 40, 56),
}, card)
UiKit.round(track, 4)
local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Gold }, track)
UiKit.round(fill, 4)
local findsLabel = text(card, "", 13, Color3.fromRGB(215, 228, 245), IronUi.Bold, 14, 96, 272, 18)
local recordLabel = text(card, "", 11, Color3.fromRGB(150, 170, 195), IronUi.Body, 14, 116, 272, 14)
local buttons = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 142),
	Size = UDim2.fromOffset(272, 40),
}, card)
UiKit.list(buttons, 8, true)
local hint = text(
	hud,
	"E / click a rock to mine  ·  G at a miner to duel  ·  F to invite  ·  E at PROBE-7 to trade",
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
hint.Position = UDim2.new(0.5, 0, 1, -18)
hint.TextStrokeTransparency = 0.4

local function refreshHud()
	if not state then
		return
	end
	local id = state.Active
	local spec = Rules.Picks[id] or Rules.Picks.Survey
	local left = state.Picks[id] or 0
	pickName.Text = spec.Name .. (if spec.Power > 1 then "  ×" .. spec.Power else "")
	pickSwings.Text = if left > 0 then left .. " swings" else "BROKEN"
	pickSwings.TextColor3 = if left > 0 then P.Gold else Color3.fromRGB(255, 90, 90)
	fill.Size = UDim2.fromScale(math.clamp(left / spec.Swings, 0, 1), 1)
	fill.BackgroundColor3 = if left / spec.Swings > 0.3 then spec.Color else Color3.fromRGB(255, 110, 90)
	findsLabel.Text = string.format(
		"This trip: %d gem%s · %d coins · %d gear",
		finds.Gems,
		if finds.Gems == 1 then "" else "s",
		finds.Coins,
		finds.Gear
	)
	recordLabel.Text = string.format(
		"%d rocks mined all-time · free pick refills in %dh",
		state.Rocks or 0,
		math.ceil((state.FreeIn or 0) / 3600)
	)
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
	chips(at, color, if mine then 6 + math.floor(tension * 6) else 3, 14 + tension * 10)
	flash(at, color, 2 + tension * 3, 0.25)
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
reveal.IgnoreGuiInset = true
local revealCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 172),
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
local revealToken = 0

-- In the world: the gem rises out of the rubble in a beam of its colour.
local function worldReveal(at: Vector3, color: Color3, rank: number)
	local gem = Instance.new("Part")
	gem.Anchored, gem.CanCollide, gem.CanQuery, gem.CanTouch = true, false, false, false
	gem.Material = Enum.Material.Neon
	gem.Color = color
	gem.Size = Vector3.new(1.2, 1.8, 1.2)
	gem.CFrame = CFrame.new(at)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.8, 1.4, 0.8)
	mesh.Parent = gem
	gem.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 14 + rank * 4, 2 + rank
	light.Parent = gem
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Size = Vector3.new(60, 0.3 + rank * 0.25, 0.3 + rank * 0.25)
	beam.CFrame = CFrame.new(at + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	local t0 = os.clock()
	local spin
	spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if not gem.Parent then
			spin:Disconnect()
			return
		end
		gem.CFrame = CFrame.new(at + Vector3.new(0, math.min(t, 0.8) * 5 + math.sin(t * 3) * 0.2, 0))
			* CFrame.Angles(0, t * 4, 0)
	end)
	tween(
		beam,
		2.6,
		{ Transparency = 1, Size = Vector3.new(60, 0.05, 0.05) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(2.4, function()
		tween(gem, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(gem, 3)
	Debris:AddItem(beam, 3)
end

-- On screen: a reel runs through the rarities, slows, and lands on yours.
function OutpostScene.reveal(loot, at: Vector3?)
	revealToken += 1
	local token = revealToken
	local rank = if loot.Gem then GemConfig.TierRank[loot.Gem.Tier] or 1 else 0
	local color = if rank > 0 then RARITY_COLORS[rank] else P.Gold
	if at then
		worldReveal(at + Vector3.new(0, 1, 0), color, math.max(rank, 1))
	end
	revealCard.Visible = true
	revealCard.BackgroundTransparency = 0.05
	revealScale.Scale = 0.85
	tween(revealScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	gemLabel.Text, extraLabel.Text = "", ""
	local extras = {}
	if loot.Coins then
		table.insert(extras, "+" .. loot.Coins .. " coins")
	end
	if loot.Gear then
		table.insert(extras, "⚙ " .. tostring(loot.Gear))
	end
	if loot.Full then
		table.insert(extras, "Gem pouch full: sell or socket gems!")
	end
	task.spawn(function()
		if rank > 0 then
			-- Spin: fast at first, slowing, ticking higher as it slows.
			local steps = 14 + rank * 2
			for i = 1, steps do
				if token ~= revealToken then
					return
				end
				local show = ((i - 1) % 5) + 1
				if i == steps then
					show = rank
				end
				reelLabel.Text = RARITY_NAMES[show]
				reelLabel.TextColor3 = RARITY_COLORS[show]
				revealStroke.Color = RARITY_COLORS[show]
				local rise = i / steps
				sound(PING, 1.2 + rise * 0.9, 0.12 + rise * 0.18)
				task.wait(0.03 + rise * rise * 0.12)
			end
			LotterySound.reveal(rank)
			sound(PING, 1, 0.5)
			sound(PING, 1.5, 0.4, nil, 0.08)
			if rank >= 3 then
				sound(PING, 2, 0.4, nil, 0.16)
			end
			revealScale.Scale = 1.15
			tween(revealScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			gemLabel.Text = loot.Text or "Gem"
			gemLabel.TextColor3 = GemConfig.ElementColors[loot.Gem.Element] or Color3.new(1, 1, 1)
			finds.Gems += 1
		else
			reelLabel.Text = if loot.Gear then "SALVAGE!" else "COIN CACHE"
			reelLabel.TextColor3 = P.Gold
			revealStroke.Color = P.Gold
			sound(PING, 1.5, 0.35)
			sound(PING, 2, 0.3, nil, 0.06)
		end
		extraLabel.Text = table.concat(extras, "   ·   ")
		finds.Coins += loot.Coins or 0
		finds.Gear += if loot.Gear then 1 else 0
		finds.Rocks += 1
		refreshHud()
		task.wait(if rank >= 4 then 3.4 else 2.4)
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

local function nearestRock(): Model?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in CollectionService:GetTagged(NODE_TAG) do
		local body = model.PrimaryPart
		if body and model:GetAttribute("Popped") == nil then
			local spec = Rules.Sizes[model:GetAttribute("Size") or "Pebble"] or Rules.Sizes.Pebble
			local d = (body.Position - root.Position).Magnitude
			if d <= Rules.Reach + spec.Scale / 2 and d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

function OutpostScene.swing(nodeId: number?)
	if not active or player:GetAttribute("CombatSession") then
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
	nextSwing = now + Rules.SwingCooldown + 0.05
	-- Face the rock.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local body = model.PrimaryPart
	if root and body then
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
			UiKit.toast("Your " .. result.PickBroke .. " broke! Get another at PROBE-7.", P.Bad)
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
		text(box, string.format("%d swings", spec.Swings), 14, Color3.new(1, 1, 1), IronUi.Bold, 14, 44, 210, 18)
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
			if owned > 0 then string.format("You have: %d swings", owned) else "You have none",
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
			text(box, "Free: issued every day", 13, P.Gold, IronUi.Bold, 14, 160, 210, 18)
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
	local market = IronUi.gemButton(probeBody, "OPEN THE MARKET  ·  TRADE GEAR", P.Gold, function()
		probe.Gui.Enabled = false
		require(script.Parent.TradeUI).open()
	end)
	market.Position, market.Size = UDim2.fromOffset(0, 266), UDim2.fromOffset(720, 44)
end
function OutpostScene.openProbe()
	probe.Gui.Enabled = true
	probe.Fit()
	drawProbe()
end

-- Prompts: rocks, the Probe, the gate, other miners -----------------------------------------------------

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
	elseif kind == "Duel" or kind == "Party" then
		local target = prompt:GetAttribute("TargetUserId")
		if target == player.UserId then
			return
		end
		task.spawn(function()
			local result = GemClient.request(if kind == "Duel" then "DuelChallenge" else "PartyInvite", target)
			if result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
			end
		end)
	end
end)
-- Your own duel/party prompts aren't for you.
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
	if processed or not active or player:GetAttribute("CombatSession") then
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
	Scenes.spaceLighting()
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
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
	setWalking(false)
	if hiddenDashboard then
		hiddenDashboard.Enabled = true
		hiddenDashboard = nil
	end
end

function OutpostScene.enter()
	if busy or active then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("OutpostEnter")
		busy = false
		if not result.Ok then
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

-- HUD buttons.
for _, spec in
	{
		{ "LEAVE", Color3.fromRGB(170, 70, 70), OutpostScene.leave },
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
