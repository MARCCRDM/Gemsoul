--[[
	Expeditions on foot (menu-only mode). "Begin Expedition" sends your miner
	to the mining site (Shared/MiningSite, built by the server) where you
	walk up to the rocks of your wall and mine them.

	  Rocks       one per tile of your wall, at the foot of the crystal face.
	              Glinting crystal = gems, ore flecks = salvage credits, gold =
	              a lucky rock. Pips over each rock show the hits left.
	  Mining      walk up and press E (or tap the prompt). Your weapon is put
	              away and the space pickaxe comes out for the swing; a moment
	              after you stop, the weapon comes back.
	  HUD         depth, swings left and what you've found, with Descend and
	              Return to base.
	The server decides everything (MineWall: ExpeditionStart, MineHit,
	MineDescend, ExpeditionLeave); this only shows it.

	MineScene.begin()     start (or resume) an expedition
	MineScene.leave()     back to base
	MineScene.isActive()  for the menu camera
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Features = require(ReplicatedStorage.Shared.Config).Features or {}
local MiningSite = require(ReplicatedStorage.Shared.MiningSite)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local Scenes = require(script.Parent.Scenes)
local ThirdPerson = require(script.Parent.ThirdPerson)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local MineScene = {}

local SWING_TIME = 0.42 -- one pickaxe swing
local IMPACT_AT = 0.2 -- when the pick hits the rock
local PICK_HOLD = 1.3 -- seconds the pickaxe stays out after a swing
local COOLDOWN = 0.36
local ROCK = Color3.fromRGB(118, 112, 122)
local CRYSTAL = Color3.fromRGB(110, 225, 255)
local GOLD = Color3.fromRGB(255, 196, 70)

local active = false
local busy = false
local layout = MiningSite.layout(MiningSite.Location)
local wall = nil -- the server's view of the current wall
local quota = nil
local rockFolder: Folder? = nil
local rocks: { [number]: { Body: BasePart, Model: Model, Pips: TextLabel } } = {}
local found = { Gems = 0, Coins = 0, Gear = 0 }
local hiddenGui: ScreenGui? = nil

-- The pickaxe in the right hand, and the right shoulder that swings it.
local pickParts: { BasePart } = {}
local shoulder: Motor6D? = nil
local swingStart = -math.huge
local pickUntil = 0
local lastSwing = 0

function MineScene.isActive(): boolean
	-- (The Saga Outpost counts: you're out in the world either way.)
	return active or require(script.Parent.OutpostScene).isActive()
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function sound(id: string, speed: number, volume: number, parent: Instance?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = parent or workspace
	pcall(function()
		s:Play()
	end)
	task.delay(2, function()
		s:Destroy()
	end)
end

-- Walking: menu mode keeps the controls off; expeditions turn them on.
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

-- HUD ---------------------------------------------------------------------------------------------

local hud = UiKit.gui("Expedition", 5)
hud.IgnoreGuiInset = true
hud.Enabled = false
local hudScale = new("UIScale", {}, hud)
local function fitHud()
	local screen = hud.AbsoluteSize
	if screen.X > 0 then
		hudScale.Scale = math.clamp(math.min(screen.X / 1280, screen.Y / 720), 0.6, 1.3)
	end
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)

local function label(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local t = IronUi.text(parent, value, size, color, font or IronUi.Bold)
	t.AutomaticSize = Enum.AutomaticSize.None
	return t
end

-- Top: depth, swings left and what you've found.
local bar = new("Frame", {
	BackgroundColor3 = P.Frame,
	BackgroundTransparency = 0.12,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(640, 64),
}, hud)
UiKit.round(bar, 8)
new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.35 }, bar)
local sector = label(bar, "CRYSTAL CLIFF  ·  LUNAR FRONTIER", 10, P.Gold)
sector.Position = UDim2.fromOffset(16, 10)
sector.Size = UDim2.fromOffset(230, 12)
local depthText = label(bar, "DEPTH 1", 24, Color3.new(1, 1, 1), IronUi.Heading)
depthText.Position = UDim2.fromOffset(16, 24)
depthText.Size = UDim2.fromOffset(150, 30)
local swingsCaption = label(bar, "SWINGS LEFT", 10, P.Dim)
swingsCaption.Position = UDim2.fromOffset(262, 10)
swingsCaption.Size = UDim2.fromOffset(120, 12)
local swingsText = label(bar, "14", 24, Color3.new(1, 1, 1), IronUi.Heading)
swingsText.Position = UDim2.fromOffset(262, 24)
swingsText.Size = UDim2.fromOffset(50, 30)
local swingTrack = new("Frame", {
	BackgroundColor3 = P.Slot,
	Position = UDim2.fromOffset(314, 37),
	Size = UDim2.fromOffset(120, 6),
}, bar)
UiKit.round(swingTrack, 3)
local swingFill = new("Frame", { BackgroundColor3 = P.Gold, Size = UDim2.fromScale(1, 1) }, swingTrack)
UiKit.round(swingFill, 3)
local foundCaption = label(bar, "FOUND THIS TRIP", 10, P.Dim)
foundCaption.Position = UDim2.fromOffset(456, 10)
foundCaption.Size = UDim2.fromOffset(160, 12)
local foundText = label(bar, "Nothing yet", 15, Color3.new(1, 1, 1))
foundText.Position = UDim2.fromOffset(456, 26)
foundText.Size = UDim2.fromOffset(170, 26)
foundText.TextYAlignment = Enum.TextYAlignment.Center

-- Bottom right: the way down, and the way home.
local actions = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(0, 50),
	AutomaticSize = Enum.AutomaticSize.X,
}, hud)
UiKit.list(actions, 10, true)
local descendButton = IronUi.gemButton(actions, "DESCEND", Color3.fromRGB(230, 140, 40), function()
	MineScene.descend()
end)
descendButton.LayoutOrder = 1
local homeButton = IronUi.button(actions, "RETURN TO BASE", false, function()
	MineScene.leave()
end)
homeButton.LayoutOrder = 2
homeButton.Size = UDim2.fromOffset(0, 46)
local costNote = label(hud, "", 12, P.Dim)
costNote.AnchorPoint = Vector2.new(1, 1)
costNote.Position = UDim2.new(1, -24, 1, -76)
costNote.Size = UDim2.fromOffset(320, 16)
costNote.TextXAlignment = Enum.TextXAlignment.Right

-- Bottom centre: a hint until you've swung once, and banners.
local hint = label(hud, "Walk up to a rock and press E to mine it", 16, Color3.new(1, 1, 1))
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -96)
hint.Size = UDim2.fromOffset(600, 22)
hint.TextXAlignment = Enum.TextXAlignment.Center
new("UIStroke", { Color = P.Ink, Thickness = 2, Transparency = 0.2 }, hint)
local banner = label(hud, "", 32, P.Gold, IronUi.Heading)
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.36)
banner.Size = UDim2.fromOffset(1100, 44)
banner.TextXAlignment = Enum.TextXAlignment.Center
banner.TextTransparency = 1
new("UIStroke", { Color = P.Ink, Thickness = 3, Transparency = 0.1 }, banner)
local fade = new("Frame", {
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 50,
}, hud)

local function showBanner(message: string, color: Color3?)
	banner.Text = message
	banner.TextColor3 = color or P.Gold
	banner.TextTransparency = 0
	banner:FindFirstChildOfClass("UIStroke").Transparency = 0.1
	task.delay(1.6, function()
		if banner.Text == message then
			tween(banner, 0.5, { TextTransparency = 1 })
			tween(banner:FindFirstChildOfClass("UIStroke"), 0.5, { Transparency = 1 })
		end
	end)
end

local function refreshHud()
	if not wall then
		return
	end
	depthText.Text = "DEPTH " .. wall.Depth
	swingsText.Text = tostring(wall.Swings)
	local max = 14
	swingFill.Size = UDim2.fromScale(math.clamp(wall.Swings / max, 0, 1), 1)
	swingFill.BackgroundColor3 = if wall.Swings <= 3 then P.Bad else P.Gold
	local parts = {}
	if found.Gems > 0 then
		table.insert(parts, string.format("◆ %d gem%s", found.Gems, if found.Gems == 1 then "" else "s"))
	end
	if found.Coins > 0 then
		table.insert(parts, found.Coins .. " coins")
	end
	if found.Gear > 0 then
		table.insert(parts, found.Gear .. " gear")
	end
	foundText.Text = if #parts > 0 then table.concat(parts, "  ·  ") else "Nothing yet"
	local free = quota and quota.FreeLeft or 0
	costNote.Text = if free > 0
		then string.format("Next wall free (%d left today)", free)
		else string.format("Next wall costs %d coins", quota and quota.Price or 40)
	descendButton.Text = if wall.Swings <= 0 then "DESCEND  ▼" else "DESCEND"
end

-- Text that rises from a rock and fades.
local function floatText(at: Vector3, message: string, color: Color3, size: number?)
	local anchor = Scenes.part(workspace, CFrame.new(at), Vector3.one * 0.2, color, Enum.Material.Neon)
	anchor.Transparency = 1
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(260, 40),
		StudsOffset = Vector3.new(0, 1, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
	}, anchor)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = message,
		Font = IronUi.Heading,
		TextSize = size or 22,
		TextColor3 = color,
	}, board)
	new("UIStroke", { Color = P.Ink, Thickness = 2 }, t)
	tween(board, 1.2, { StudsOffset = Vector3.new(0, 4, 0) })
	task.delay(0.6, function()
		tween(t, 0.6, { TextTransparency = 1 })
	end)
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

-- Rocks ---------------------------------------------------------------------------------------------

local function pipText(hp: number, maxHp: number): string
	return string.rep("●", hp) .. string.rep("○", math.max(0, maxHp - hp))
end

-- One rock of the wall: a lumpy boulder, dressed by its hint, with a prompt.
local function makeRock(index: number, tile, spot: CFrame, depth: number)
	local m = new("Model", { Name = "Rock" .. index }, rockFolder)
	-- Deeper walls are darker, with more colour in the stone.
	local tint = ROCK:Lerp(Color3.fromRGB(70, 60, 90), math.clamp((depth - 1) / 10, 0, 0.7))
	local size = 3.2 + (tile.MaxHp or 2) * 0.25
	local body = Scenes.part(
		m,
		spot * CFrame.new(0, size * 0.36, 0),
		Vector3.new(size, size * 0.8, size * 0.9),
		tint,
		Enum.Material.Slate,
		"Sphere"
	)
	body.CanCollide = true
	body.CanQuery = true
	body.Name = "Body"
	for k = 1, 2 do
		local lump = Scenes.part(
			m,
			body.CFrame * CFrame.new((k == 1 and -1 or 1) * size * 0.3, -size * 0.12, (k - 1.5) * size * 0.25),
			Vector3.new(size * 0.55, size * 0.45, size * 0.6),
			tint:Lerp(Color3.new(0, 0, 0), 0.12),
			Enum.Material.Slate,
			"Sphere"
		)
		lump.CanCollide = true
	end
	local kind = "Rock"
	if tile.Hint == "Glint" then
		kind = "Crystal Rock"
		for k = 1, 3 do
			local shard = Scenes.part(
				m,
				body.CFrame
					* CFrame.Angles(math.rad(-25 + k * 15), math.rad(k * 110), math.rad(-20 + k * 12))
					* CFrame.new(0, size * 0.42, 0),
				Vector3.new(0.45, 1.2 + k * 0.2, 0.45),
				CRYSTAL,
				Enum.Material.Neon
			)
			shard.Transparency = 0.15
		end
		local sparkle = new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(CRYSTAL),
			Size = NumberSequence.new(0.3, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 4,
			Speed = NumberRange.new(0.5, 1.5),
			LightEmission = 1,
		}, body)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		new("PointLight", { Color = CRYSTAL, Range = 8, Brightness = 1.2 }, body)
	elseif tile.Hint == "Gold" then
		kind = "Golden Rock"
		for k = 1, 5 do
			Scenes.part(
				m,
				body.CFrame * CFrame.Angles(math.rad(k * 70), math.rad(k * 47), 0) * CFrame.new(0, size * 0.4, 0),
				Vector3.one * 0.45,
				GOLD,
				Enum.Material.Neon,
				"Ball"
			)
		end
		new("PointLight", { Color = GOLD, Range = 10, Brightness = 1.6 }, body)
	elseif tile.Hint == "Speck" then
		kind = "Ore Seam"
		local ore = tile.OreColor or Color3.fromRGB(200, 205, 215)
		for k = 1, 6 do
			Scenes.part(
				m,
				body.CFrame * CFrame.Angles(math.rad(k * 53), math.rad(k * 97), 0) * CFrame.new(0, size * 0.39, 0),
				Vector3.new(0.5, 0.25, 0.4),
				ore,
				Enum.Material.Metal
			)
		end
	end
	-- Hits left, floating over the rock.
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(120, 22),
		StudsOffset = Vector3.new(0, size * 0.75, 0),
		MaxDistance = 40,
		LightInfluence = 0,
	}, body)
	local pips = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = pipText(tile.Hp, tile.MaxHp),
		Font = IronUi.Bold,
		TextSize = 16,
		TextColor3 = if kind == "Golden Rock"
			then GOLD
			elseif kind == "Crystal Rock" then CRYSTAL
			else Color3.fromRGB(235, 235, 240),
	}, board)
	new("UIStroke", { Color = P.Ink, Thickness = 1.5 }, pips)
	local prompt = new("ProximityPrompt", {
		ActionText = "Mine",
		ObjectText = kind,
		KeyboardKeyCode = Enum.KeyCode.E,
		HoldDuration = 0,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
	}, body)
	prompt.Triggered:Connect(function()
		MineScene.swing(index)
	end)
	rocks[index] = { Body = body, Model = m, Pips = pips }
end

local function buildRocks()
	if rockFolder then
		rockFolder:Destroy()
	end
	table.clear(rocks)
	rockFolder = new("Folder", { Name = "ExpeditionRocks" }, workspace)
	if not wall then
		return
	end
	for index, tile in wall.Tiles do
		local spot = layout.RockSpots[index]
		if spot and tile.Hp > 0 then
			makeRock(index, tile, spot, wall.Depth)
		end
	end
end

-- A broken rock crumbles into pieces that roll and fade.
local function crumble(index: number)
	local rock = rocks[index]
	if not rock then
		return
	end
	rocks[index] = nil
	local center = rock.Body.CFrame.Position
	-- Collect first: destroying prompts/billboards mid-walk would invalidate the descendant list.
	local parts, extras = {}, {}
	for _, item in rock.Model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		elseif item:IsA("ProximityPrompt") or item:IsA("BillboardGui") or item:IsA("ParticleEmitter") then
			table.insert(extras, item)
		end
	end
	for _, item in extras do
		item:Destroy()
	end
	for _, part in parts do
		part.CanCollide = false
		local away = (part.CFrame.Position - center) + Vector3.new(0, 0.5, 0)
		if away.Magnitude < 0.01 then
			away = Vector3.new(0, 1, 0)
		end
		tween(part, 0.5, {
			Size = part.Size * 0.3,
			Position = part.CFrame.Position + away.Unit * 1.5 - Vector3.new(0, 0.8, 0),
			Transparency = 1,
		})
	end
	task.delay(0.6, function()
		rock.Model:Destroy()
	end)
end

-- The pickaxe ------------------------------------------------------------------------------------

local function weaponParts(): { BasePart }
	local list = {}
	local character = player.Character
	local gear = character and character:FindFirstChild("GemsoulGear")
	local weapon = gear and gear:FindFirstChild("Weapon")
	for _, d in (weapon and weapon:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Out for digging (weapon hidden on this screen), or put away.
local function holdPick(on: boolean)
	for _, part in pickParts do
		part.Transparency = if on then 0 else 1
	end
	for _, part in weaponParts() do
		part.LocalTransparencyModifier = if on then 1 else 0
	end
end

local function makePick()
	for _, part in pickParts do
		part:Destroy()
	end
	pickParts = {}
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand") :: BasePart?
	local upperArm = character and character:FindFirstChild("RightUpperArm")
	shoulder = upperArm and upperArm:FindFirstChild("RightShoulder") :: Motor6D?
	if hand then
		pickParts = Scenes.spacePickaxe(hand)
	end
	holdPick(false)
end

-- One swing at rock `index`.
function MineScene.swing(index: number)
	local rock = rocks[index]
	if not active or not wall or not rock then
		return
	end
	local now = os.clock()
	if now - lastSwing < COOLDOWN then
		return
	end
	if wall.Swings <= 0 then
		showBanner("OUT OF SWINGS", P.Bad)
		return
	end
	lastSwing = now
	hint.Visible = false
	-- Turn to the rock and swing.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = rock.Body.CFrame.Position
	if root then
		root.CFrame = CFrame.lookAt(root.CFrame.Position, Vector3.new(target.X, root.CFrame.Position.Y, target.Z))
	end
	if #pickParts == 0 then
		makePick()
	end
	holdPick(true)
	swingStart = now
	pickUntil = now + PICK_HOLD
	task.delay(IMPACT_AT, function()
		if not rock.Body.Parent then
			return
		end
		-- The hit: sparks, dust and a shake.
		local from = if root then Vector3.new(root.CFrame.Position.X, target.Y, root.CFrame.Position.Z) else target
		local face = target + (from - target).Unit * (rock.Body.Size.X * 0.45)
		for _ = 1, 7 do
			local spark = Scenes.part(workspace, CFrame.new(face), Vector3.one * 0.15, CRYSTAL, Enum.Material.Neon)
			local out = ((from - target).Unit + Vector3.new(
				math.random() - 0.5,
				math.random() * 0.8,
				math.random() - 0.5
			)).Unit
			tween(spark, 0.4, { Position = face + out * (1.5 + math.random() * 1.5), Transparency = 1 })
			task.delay(0.45, function()
				spark:Destroy()
			end)
		end
		for _ = 1, 3 do
			local dust = Scenes.part(
				workspace,
				CFrame.new(face),
				Vector3.one * 0.6,
				Color3.fromRGB(170, 166, 170),
				Enum.Material.SmoothPlastic,
				"Ball"
			)
			dust.Transparency = 0.4
			tween(dust, 0.7, {
				Position = face + Vector3.new(math.random() - 0.5, 0.6 + math.random(), math.random() - 0.5) * 1.5,
				Size = Vector3.one * 1.6,
				Transparency = 1,
			})
			task.delay(0.75, function()
				dust:Destroy()
			end)
		end
		local base = rock.Body.CFrame
		rock.Body.CFrame = base * CFrame.Angles(0.06, 0, 0.06)
		tween(rock.Body, 0.15, { CFrame = base })
		sound("rbxasset://sounds/swordhit.wav", 0.7 + math.random() * 0.15, 0.5, rock.Body)
	end)
	-- The server rolls the hit.
	task.spawn(function()
		local result = GemClient.request("MineHit", index)
		if not result.Ok then
			if result.Message ~= "" and result.Message ~= "Slow down!" then
				UiKit.toast(result.Message, P.Bad)
			end
			return
		end
		wall.Swings = result.Swings
		wall.Tiles[index] = result.Tile
		quota = result.Quota or quota
		task.wait(math.max(0, swingStart + IMPACT_AT - os.clock()))
		if result.Crit then
			floatText(target + Vector3.new(0, 2, 0), "CRIT!", Color3.fromRGB(255, 150, 40), 26)
		end
		local loot = result.Loot
		if loot then
			crumble(index)
			if loot.Kind == "Gem" and loot.Gem then
				found.Gems += 1
				local color = GemConfig.TierColors[loot.Gem.Tier] or CRYSTAL
				floatText(target + Vector3.new(0, 1.5, 0), "GEM!  " .. (loot.Text or ""), color, 24)
				require(script.Parent.OutpostScene).reveal(
					{ Gem = loot.Gem, Text = loot.Text, Coins = loot.Coins },
					nil
				)
				sound("rbxasset://sounds/electronicpingshort.wav", 1.2, 0.5)
			elseif loot.Kind == "Full" then
				floatText(target + Vector3.new(0, 1.5, 0), "POUCH FULL", P.Bad, 22)
			elseif loot.Kind ~= "Stone" then
				floatText(target + Vector3.new(0, 1.5, 0), loot.Text or "Found something", P.Gold, 20)
			else
				floatText(target + Vector3.new(0, 1.5, 0), "Rubble", P.Dim, 18)
			end
			found.Coins += loot.Coins or loot.Count or 0
			if loot.Gear then
				found.Gear += 1
				UiKit.toast("EQUIPMENT RECOVERED: " .. loot.Gear .. "! See it in your Armory.", P.Gold)
			end
		elseif rocks[index] then
			rocks[index].Pips.Text = pipText(result.Tile.Hp, result.Tile.MaxHp)
		end
		refreshHud()
		if wall.Swings <= 0 then
			task.delay(0.8, function()
				showBanner("OUT OF SWINGS  ·  DESCEND OR RETURN", P.Gold)
			end)
		end
	end)
end

-- Expedition flow ------------------------------------------------------------------------------------

local function enterScene(result)
	wall = result.Wall
	quota = result.Quota
	found = { Gems = 0, Coins = 0, Gear = 0 }
	active = true
	MiningSite.lighting()
	-- The dashboard's backdrop would cover the world; put it away while out.
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	if dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled then
		dashboard.Enabled = false
		hiddenGui = dashboard
	end
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	ThirdPerson.enter()
	setWalking(true)
	makePick()
	buildRocks()
	fitHud()
	hint.Visible = true
	hud.Enabled = true
	refreshHud()
	fade.BackgroundTransparency = 0
	tween(fade, 0.6, { BackgroundTransparency = 1 })
	showBanner("DEPTH " .. wall.Depth, P.Gold)
end

-- Back to the menu (after the server has moved us, or on respawn).
local function exitScene()
	if not active then
		return
	end
	active = false
	hud.Enabled = false
	if rockFolder then
		rockFolder:Destroy()
		rockFolder = nil
	end
	table.clear(rocks)
	holdPick(false)
	for _, part in pickParts do
		part:Destroy()
	end
	pickParts = {}
	shoulder = nil
	setWalking(false)
	ThirdPerson.exit()
	Scenes.spaceLighting()
	if hiddenGui then
		hiddenGui.Enabled = true
		hiddenGui = nil
	end
end

function MineScene.begin()
	if Features.Mining == false then
		UiKit.toast("The Moon Mine is closed for this playtest.", P.Bad)
		return
	end
	if busy or active then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("ExpeditionStart")
		busy = false
		if not result.Ok then
			UiKit.toast(result.Message, P.Bad)
			return
		end
		enterScene(result)
	end)
end

function MineScene.descend()
	if busy or not active then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("MineDescend")
		busy = false
		if not result.Ok then
			UiKit.toast(result.Message, P.Bad)
			quota = result.Quota or quota
			refreshHud()
			return
		end
		tween(fade, 0.25, { BackgroundTransparency = 0 })
		task.wait(0.3)
		wall = result.Wall
		quota = result.Quota or quota
		buildRocks()
		refreshHud()
		tween(fade, 0.5, { BackgroundTransparency = 1 })
		showBanner("DEPTH " .. wall.Depth, P.Gold)
		sound("rbxasset://sounds/electronicpingshort.wav", 0.8, 0.4)
	end)
end

function MineScene.leave()
	if busy or not active then
		return
	end
	busy = true
	task.spawn(function()
		tween(fade, 0.25, { BackgroundTransparency = 0 })
		local result = GemClient.request("ExpeditionLeave")
		busy = false
		task.wait(0.3)
		exitScene()
		fade.BackgroundTransparency = 1
		if result.Ok and (found.Gems > 0 or found.Coins > 0) then
			UiKit.toast(string.format("Expedition haul: %d gems, %d coins", found.Gems, found.Coins), P.Gold)
		end
	end)
end

-- Each frame: the swing, and putting the pickaxe away afterwards.
RunService.Stepped:Connect(function()
	if not active then
		return
	end
	local now = os.clock()
	local t = (now - swingStart) / SWING_TIME
	if shoulder and shoulder.Parent and t >= 0 and t < 1 then
		-- Wind up over the shoulder, strike down, recover.
		local angle
		if t < 0.35 then
			angle = 165 * (t / 0.35)
		elseif t < 0.6 then
			angle = 165 - 120 * ((t - 0.35) / 0.25)
		else
			angle = 45 * (1 - (t - 0.6) / 0.4)
		end
		shoulder.Transform = CFrame.Angles(math.rad(angle), 0, 0)
	end
	if now > pickUntil and #pickParts > 0 and pickParts[1].Transparency < 1 then
		holdPick(false)
	end
end)

-- Respawning ends the expedition (the server sends you back to base).
player.CharacterAdded:Connect(function()
	exitScene()
end)

return MineScene
