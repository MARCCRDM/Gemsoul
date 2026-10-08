--[[
	The first-time tutorial (Shared.Tutorial; the server checks every beat
	and hands out the rewards, see Systems/Intro): one prompt at a time, at
	most two lines, a SKIP button from the first second.

	  Mine     five crystals in front of the Outpost spawn, only on your
	           screen; each drops a scripted gem with a pop
	  Sockets  open the Inventory, put a gem in your chest, sword and shield
	           (each socket flashes the stat it raised), Ember Lance on Q
	  Close    close the Inventory: the tutorial carries on from there
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local ArmorSignatures = require(ReplicatedStorage.Shared.ArmorSignatures)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local SurgeIcons = require(script.Parent.Modules.SurgeIcons)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local LobbyUI = require(script.Parent.Modules.LobbyUI)
local OutpostScene = require(script.Parent.Modules.OutpostScene)
local UiKit = require(script.Parent.Modules.UiKit)

if not Tutorial.Enabled then
	return
end

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local GOLD = Color3.fromRGB(255, 202, 91)
local CRYSTAL = Color3.fromRGB(90, 230, 255)

while not GemClient.Profile do
	GemClient.Changed:Wait()
end

local function state()
	return GemClient.Profile and GemClient.Profile.Tutorial
end
local function finished(): boolean
	local s = state()
	local intro = GemClient.Profile and GemClient.Profile.Intro
	return (s ~= nil and s.Done == true) or (s == nil and intro ~= nil and intro.Done == true)
end
local function current()
	local s = state()
	return if s and not s.Done then Tutorial.Beats[s.Step] else nil
end

-- Wait for the kit (Intro.client asks for it) and for the Outpost.
while not (state() and GemClient.Profile.Intro.Done) do
	if finished() then
		return
	end
	GemClient.Changed:Wait()
end
if finished() then
	return
end
while not OutpostScene.isActive() do
	task.wait(0.3)
end

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The prompt bar ---------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "Tutorial",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 60,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local bar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.fromOffset(460, 62),
	BackgroundColor3 = Color3.fromRGB(10, 14, 24),
	BackgroundTransparency = 0.08,
}, gui)
UiKit.round(bar, 12)
new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.15 }, bar)
local promptScale = new("UIScale", { Scale = 1 }, bar)
local promptLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 6),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "",
	TextSize = 22,
	Font = IronUi.Heading,
	TextColor3 = P.Text,
	TextWrapped = true,
}, bar)
-- One dot per beat: where you are.
local dots = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(#Tutorial.Beats * 16, 8),
}, bar)
UiKit.list(dots, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
local dotFrames = {}
for i = 1, #Tutorial.Beats do
	local dot = new("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = P.Dim, LayoutOrder = i }, dots)
	UiKit.round(dot, 4)
	dotFrames[i] = dot
end

local skip = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(96, 34),
	Text = "SKIP  ▸▸",
	TextSize = 14,
	Font = IronUi.Heading,
	TextColor3 = P.Text,
	BackgroundColor3 = Color3.fromRGB(22, 28, 42),
	BackgroundTransparency = 0.1,
}, gui)
UiKit.round(skip, 8)
new("UIStroke", { Color = P.Edge, Thickness = 1 }, skip)

local function fit()
	local width = gui.AbsoluteSize.X
	bar.Size = UDim2.fromOffset(math.min(460, width - 140), 62)
	promptLabel.TextSize = if width < 700 then 18 else 22
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
task.defer(fit)

local shownText = nil
local function say(text: string)
	if text == shownText then
		return
	end
	shownText = text
	promptLabel.Text = text
	promptScale.Scale = 0.88
	TweenService:Create(promptScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- A gold pulse around whatever the current beat wants you to press.
local pulse: UIStroke? = nil
local function point(target: GuiObject?)
	if pulse and (not target or pulse.Parent ~= target) then
		pulse:Destroy()
		pulse = nil
	end
	if target and not pulse then
		pulse = new("UIStroke", { Name = "TutorialPulse", Color = GOLD, Thickness = 3 }, target)
		local tween = TweenService:Create(
			pulse :: UIStroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.8 }
		)
		tween:Play()
	end
end

-- The crystals -----------------------------------------------------------------------------
local rocks = new("Folder", { Name = "TutorialRocks" }, workspace)

local function spawnFrame(): CFrame?
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
	return if typeof(spawn) == "CFrame" then spawn else nil
end

local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rocks, player.Character }
	local hit = workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position else at
end

local mining = false
local function mined()
	local s = state()
	return if s then s.Mined or 0 else 0
end
local function rockSaid()
	local left = #Tutorial.Gems - mined()
	say(
		if mined() == 0
			then (if touch then Tutorial.ById.Mine.Mobile else Tutorial.ById.Mine.Prompt)
			else string.format("Mine %d more.", left)
	)
end

local function buildRock(index: number, at: Vector3)
	local model = new("Model", { Name = "TutorialRock" .. index })
	local base = new("Part", {
		Name = "Base",
		Anchored = true,
		CanCollide = true,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4.2, 3.2, 4.2),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(78, 74, 88),
		CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)),
	}, model)
	model.PrimaryPart = base
	local shards = {}
	for i, tilt in { { 0, 0 }, { 25, 70 }, { -22, 200 }, { 18, 300 } } do
		local height = if i == 1 then 3.4 else 2.2
		local shard = new("Part", {
			Name = "Shard",
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(0.8, height, 0.8),
			Material = Enum.Material.Neon,
			Color = CRYSTAL,
			CFrame = CFrame.new(at + Vector3.new(0, 2.4, 0))
				* CFrame.Angles(0, math.rad(tilt[2]), math.rad(tilt[1]))
				* CFrame.new(0, height / 2 - 0.4, 0)
				* CFrame.Angles(0, math.rad(45), 0),
		}, model)
		table.insert(shards, shard)
	end
	new("PointLight", { Color = CRYSTAL, Range = 12, Brightness = 2 }, base)
	-- Pulse, so it reads as "go here".
	for _, shard in shards do
		TweenService:Create(
			shard,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.35 }
		):Play()
	end
	local prompt = new("ProximityPrompt", {
		ActionText = "Mine",
		ObjectText = "Crystal",
		HoldDuration = Config.MineHoldSeconds or 1,
		KeyboardKeyCode = Enum.KeyCode.E,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
	}, base)
	prompt.Triggered:Connect(function()
		if mining then
			return
		end
		mining = true
		pcall(OutpostScene.swing)
		local result = GemClient.request("TutorialMine", index)
		mining = false
		if result.Ok then
			if result.Gem then
				OutpostScene.reveal({ Gem = result.Gem, Tutorial = true }, base.Position)
			end
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1, Size = part.Size * 0.4 }):Play()
				end
			end
			task.delay(0.35, function()
				model:Destroy()
			end)
		elseif result.Message then
			UiKit.toast(result.Message, P.Bad)
		end
	end)
	model.Parent = rocks
end

local function placeRocks()
	local spawn = spawnFrame()
	if not spawn then
		return
	end
	local done = state() and state().Rocks or {}
	for index, offset in Tutorial.Rocks do
		if not done[tostring(index)] and not rocks:FindFirstChild("TutorialRock" .. index) then
			buildRock(index, ground((spawn * CFrame.new(offset)).Position))
		end
	end
end

-- The beats --------------------------------------------------------------------------------
local closing = false
local function finish(message: string?)
	if closing then
		return
	end
	closing = true
	point(nil)
	rocks:Destroy()
	if message then
		UiKit.toast(message, GOLD)
	end
	TweenService:Create(bar, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	task.delay(0.3, function()
		gui:Destroy()
	end)
end

local stepping = false
local lastSocketBeat = nil
local function tryStep(beatId: string)
	if stepping then
		return
	end
	stepping = true
	task.spawn(function()
		GemClient.request("TutorialStep", beatId)
		stepping = false
	end)
end

local action = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(280, 54),
	BackgroundColor3 = GOLD,
	TextColor3 = P.Background or Color3.new(0, 0, 0),
	Font = IronUi.Heading,
	TextSize = 22,
	Text = "",
	Visible = false,
}, gui)
UiKit.round(action, 12)
local preview = new("Frame", {Visible=false, BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,1), Position=UDim2.new(0.5,0,1,-30), Size=UDim2.fromOffset(156,64)}, gui)
local previewKeys = {}
for i, key in {"Q", "E"} do
 local icon = new("TextLabel", {Size=UDim2.fromOffset(60,60), Position=UDim2.fromOffset((i-1)*82,0), Text=key, BackgroundColor3=Color3.fromRGB(12,20,30)}, preview)
 UiKit.round(icon,10)
 new("TextLabel", {Size=UDim2.fromOffset(20,20), Text=key, TextSize=16, Font=IronUi.Heading, BackgroundColor3=GOLD, ZIndex=4}, icon)
 previewKeys[key] = icon
end
local pad
local queueBusy = false
local function queue()
	if queueBusy then
		return
	end
	queueBusy = true
	task.spawn(function()
		say("Rival Match — Tutorial. Nothing is lost.")
		local result = GemClient.request("TutorialQueue")
		if result.Ok and result.Waiting then
			task.wait(3)
			result = GemClient.request("TutorialQueue")
		end
		if not result.Ok then
			UiKit.toast(result.Message or "Try the pad again.")
		end
		queueBusy = false
	end)
end
local function marketOpen()
	local screen = player.PlayerGui:FindFirstChild("MarketBoard")
	return screen ~= nil and screen.Enabled
end
action.Activated:Connect(function()
	local beat = current()
	if not beat then
		return
	end
	if beat.Id == "Return" then
		local fade = new(
			"Frame",
			{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 100 },
			gui
		)
		TweenService:Create(fade, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		task.wait(0.2)
		GemClient.request("ArenaLeave")
		OutpostScene.ensure()
		TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function()
			fade:Destroy()
		end)
	elseif beat.Id == "OpenMarket" then
		require(script.Parent.Modules.MarketBoardUI).open()
	elseif beat.Id == "Play" then
		tryStep("Play")
		LobbyUI.openPicker()
	end
end)

local function update()
 preview.Visible = false
	if closing then
		return
	end
	if finished() then
		finish("You’re ready. Go!")
		return
	end
	local beat = current()
	if not beat then
		return
	end
	action.Visible = beat.Id == "Return" or beat.Id == "OpenMarket" or beat.Id == "Play"
	action.Text = if beat.Id == "Return"
		then "RETURN TO OUTPOST"
		elseif beat.Id == "OpenMarket" then "OPEN MARKET"
		else "▶ PLAY"
	bar.Visible = beat.Id ~= "Fight" or player:GetAttribute("CombatSession") == nil
	if pad then
		pad.Transparency = if beat.Id == "Queue"
				or (beat.Id == "Fight" and not player:GetAttribute("CombatSession"))
			then 0.2
			else 1
	end
	for i, dot in dotFrames do
		dot.BackgroundColor3 = if i < beat.Index then P.Good elseif i == beat.Index then GOLD else P.Dim
	end
	local text = if touch then beat.Mobile or beat.Prompt else beat.Prompt
	if beat.Id == "Mine" then
		placeRocks()
		rockSaid()
		point(nil)
		return
	end
	if not queueBusy then
		say(text)
	end
	local open = LobbyUI.dashboardOpen()
 preview.Visible = not open and player:GetAttribute("CombatSession") == nil and (beat.Id == "Queue" or beat.Id == "Fight")
 if preview.Visible then
  for i, key in {"Q", "E"} do
   local gem = GemClient.Profile.Character["Surge" .. i .. "Gem"]
   if gem then SurgeIcons.apply(previewKeys[key], Tech.surgeStats(gem), GemConfig.ElementColors[gem.Element]) end
  end
 end
	if beat.Id == "Queue" or (beat.Id == "Fight" and not player:GetAttribute("CombatSession")) then
		point(nil)
		if not pad and spawnFrame() then
			local at = ground((spawnFrame() * CFrame.new(0, 0, -10)).Position)
			pad = new(
				"Part",
				{
					Name = "TutorialRivalPad",
					Anchored = true,
					CanCollide = false,
					Material = Enum.Material.Neon,
					Color = GOLD,
					Size = Vector3.new(7, 0.2, 7),
					Position = at + Vector3.new(0, 0.15, 0),
				},
				rocks
			)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if
			pad
			and root
			and (Vector3.new(root.Position.X, pad.Position.Y, root.Position.Z) - pad.Position).Magnitude < 4
		then
			queue()
		end
	elseif beat.Id == "Fight" then
		point(nil)
	elseif beat.Id == "Return" then
		point(nil)
		if not player:GetAttribute("CombatSession") and OutpostScene.isActive() then
			tryStep(beat.Id)
		end
	elseif beat.Id == "OpenMarket" then
		point(nil)
		if marketOpen() then
			tryStep(beat.Id)
		end
	elseif beat.Id == "Buy" then
		point(nil)
	elseif beat.Id == "CloseMarket" then
		point(nil)
		if not marketOpen() then
			tryStep(beat.Id)
		end
	elseif beat.Id == "Play" then
		point(action)
	elseif beat.Id == "OpenInventory" then
		point(LobbyUI.tile("INVENTORY"))
		if open then
			tryStep(beat.Id)
		end
	elseif beat.Id == "CloseInventory" then
		point(nil)
		if not open then
			tryStep(beat.Id)
		end
	else
		local wanted = (
			{ SocketArmor = "Armor", SocketWeapon = "Weapon", SocketShield = "Shield", SurgeQ = "Q", SurgeE = "E" }
		)[beat.Id]
		local target
		if wanted then
			for _, object in player.PlayerGui:GetDescendants() do
				if object:IsA("GuiObject") and object:GetAttribute("TutorialSocket") == wanted then
					target = object
					break
				end
			end
		end
		point(target)
		-- A socket beat: ticked off the moment the profile shows it.
		if Tutorial.met(GemClient.Profile, beat.Id) then
			if lastSocketBeat ~= beat.Id then
				lastSocketBeat = beat.Id
				local slot = if beat.Id == "SocketArmor"
					then "Armor"
					elseif beat.Id == "SocketShield" then "Shield"
					else nil
				if slot then
					local c = GemClient.Profile.Character
					local kind = ArmorSignatures.Slots[slot]
					local roll = c.GearRolls and c.GearRolls[kind] and c.GearRolls[kind][c[slot]]
					local name, effect = ArmorSignatures.describe(roll, c[slot .. "Gem"])
					if name ~= "" then
						UiKit.toast(name .. ": " .. effect, P.Good)
					end
				end
			end
			tryStep(beat.Id)
		end
	end
end

skip.Activated:Connect(function()
	skip.Active = false
	local result = GemClient.request("TutorialSkip")
	if result.Ok then
		finish(nil)
	else
		skip.Active = true
	end
end)

GemClient.Changed:Connect(update)
-- Opening and closing the Inventory doesn't change the profile: check often.
task.spawn(function()
	while not closing do
		update()
		task.wait(0.25)
	end
end)
update()
