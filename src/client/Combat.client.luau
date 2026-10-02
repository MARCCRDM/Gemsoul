-- First-person timed attacks, alternating sides, reactive guard and universal dodge.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local CombatGuide = require(script.Parent.Modules.CombatGuide)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local FirstPerson = require(script.Parent.Modules.FirstPersonCombat)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
if Config.MenuOnly and not Config.CombatEnabled then
	return
end
local player = Players.LocalPlayer
local input = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatInput")
local fxEvent = ReplicatedStorage.Remotes:WaitForChild("CombatFx")
local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text
local cooldowns = {}
local attackSide, nextSide, cursorFree = "Right", "Right", false
local feedbackUntil = 0
local guideWasOpen = false
local attackTouch, blockTouch, surgeTouch
local beamHeld, nextBeamUpdate = false, 0
local selected = { RigManeuvers = 1, GemSurges = 1 }
local techCooldowns = {}
local holding, blockHeld, chargeStarted, nextAttack, nextBlockUpdate = false, false, 0, 0, 0
local gui = UiKit.gui("CombatHud", 5)
local hud = new("Frame", {
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.fromOffset(280, 118),
}, gui)
UiKit.round(hud, 12)
local hp = text(hud, "", 12, P.Text, IronUi.Bold)
hp.Position = UDim2.fromOffset(12, 8)
hp.Size = UDim2.new(1, -24, 0, 22)
local hint = text(hud, "Alternate sides; release when gold", 11, P.Dim)
hint.Position = UDim2.fromOffset(12, 88)
hint.Size = UDim2.new(1, -24, 0, 28)
hint.TextWrapped = true
local row =
	new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) }, gui)
local healthTrack = new("Frame", {
	BackgroundColor3 = P.Dim,
	BackgroundTransparency = 0.6,
	Position = UDim2.fromOffset(12, 30),
	Size = UDim2.new(1, -24, 0, 5),
}, hud)
local healthFill = new(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(198, 62, 73), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
	healthTrack
)
local resourceBars = {}
for index, id in { "Stamina", "Charge" } do
	local label = text(hud, id:upper(), 9, Tech.Resources[id].Color, IronUi.Bold)
	label.Position, label.Size = UDim2.fromOffset(12, 36 + (index - 1) * 25), UDim2.new(1, -24, 0, 15)
	local track = new("Frame", {
		BackgroundColor3 = P.Dim,
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(12, 52 + (index - 1) * 25),
		Size = UDim2.new(1, -24, 0, 5),
	}, hud)
	local fill = new(
		"Frame",
		{ BackgroundColor3 = Tech.Resources[id].Color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) },
		track
	)
	resourceBars[id] = { Label = label, Fill = fill }
end
local reticle = text(gui, "+", 24, P.Text, IronUi.Bold)
reticle.AnchorPoint, reticle.Position, reticle.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(40, 40)
reticle.TextXAlignment = Enum.TextXAlignment.Center
local chargeTrack = new("Frame", {
	BackgroundColor3 = P.Inset,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 30),
	Size = UDim2.fromOffset(160, 8),
	Visible = false,
}, gui)
UiKit.round(chargeTrack, 4)
local chargeFill =
	new("Frame", { BackgroundColor3 = P.Gold, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, chargeTrack)
local targetCard = new("Frame", {
	BackgroundColor3 = P.Inset,
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(260, 56),
	Visible = false,
}, gui)
UiKit.round(targetCard, 10)
local targetName = text(targetCard, "", 13, P.Gold, IronUi.Bold)
targetName.Position, targetName.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 22)
targetName.TextXAlignment = Enum.TextXAlignment.Center
local targetTrack = new(
	"Frame",
	{ BackgroundColor3 = P.Dim, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 8) },
	targetCard
)
local targetFill = new(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(198, 62, 73), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
	targetTrack
)
local controlsHint =
	text(gui, "LMB Attack | Q/E Side | RMB Guard | Space Dodge | R Rig | F Surge | Z/X Cycle | Tab Cursor", 11, P.Text)
controlsHint.AnchorPoint, controlsHint.Position, controlsHint.Size =
	Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8), UDim2.new(1, -20, 0, 22)
controlsHint.TextXAlignment = Enum.TextXAlignment.Center
local cursorModal =
	new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = false }, gui)
local slots = {}
local function rootPart()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function canFight()
	local root = rootPart()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid
		and humanoid.Health > 0
		and root
		and not player.PlayerGui:FindFirstChild("Intro")
		and Combat.canFight(root.Position)
		and (not Config.MenuOnly or ArenaScene.isActive())
end
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimedHit()
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	aimParams.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("CombatFx"), camera }
	return workspace:Raycast(ray.Origin, ray.Direction * 500, aimParams), ray
end
local function aimPoint()
	local hit, ray = aimedHit()
	return if hit then hit.Position else ray.Origin + ray.Direction * 120
end
local function face(aim)
	local root = rootPart()
	if root then
		local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end
local function rules()
	local loadout = GemClient.Profile and GemClient.Profile.Character
	if not loadout then
		return Actions.resolve({}, "Sword", 0)
	end
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	local effects = Classes.effects(loadout)
	return Actions.resolve(
		Classes.setState(loadout).Counts,
		if weapon and weapon.Attack.Kind == "Melee" then "Sword" else "Pistol",
		1 - (effects.CooldownMult or 1)
	)
end
local function beginAttack(side)
	if beamHeld then
		return
	end
	if cursorFree or not canFight() or blockHeld or holding or os.clock() < nextAttack then
		return
	end
	holding, chargeStarted = true, os.clock()
	attackSide = side or nextSide
	input:FireServer("BeginAttack", attackSide)
end
local function releaseAttack()
	if not holding then
		return
	end
	holding = false
	if not canFight() then
		input:FireServer("CancelAttack")
		return
	end
	local aim = aimPoint()
	face(aim)
	local heavy = Actions.charge(os.clock() - chargeStarted).Heavy
	nextSide = if attackSide == "Right" then "Left" else "Right"
	nextAttack = os.clock() + (if heavy then rules().HeavyCooldown else rules().BasicCooldown)
	input:FireServer("ReleaseAttack", aim)
end
local function setBlock(held)
	if held and (cursorFree or not canFight()) then
		return
	end
	blockHeld = held
	if held then
		beamHeld = false
		input:FireServer("CancelTech")
		holding = false
		input:FireServer("CancelAttack")
	end
	local aim = aimPoint()
	if held then
		face(aim)
	end
	input:FireServer("Block", held, aim)
	nextBlockUpdate = os.clock() + 0.15
end
local function dodge()
	if cursorFree or not canFight() then
		return
	end
	local cd = cooldowns.Dodge
	if cd and os.clock() < cd.Ready then
		return
	end
	holding = false
	blockHeld = false
	beamHeld = false
	input:FireServer("CancelTech")
	input:FireServer("CancelAttack")
	input:FireServer("Block", false)
	local root = rootPart()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	input:FireServer(
		"Dodge",
		if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector
	)
end
local techButtons = {}
local function selectedTech(group)
	local available = Tree.available(GemClient.Profile, group)
	selected[group] = math.clamp(selected[group], 1, math.max(1, #available))
	return available[selected[group]] or Tech.Order[group][1]
end
local function triggerTech(group)
	if cursorFree or not canFight() or holding or blockHeld then
		return
	end
	local id = selectedTech(group)
	if os.clock() < (techCooldowns[id] or 0) then
		return
	end
	local definition = Tech.Catalog[id]
	if definition.PerSecond then
		beamHeld, nextBeamUpdate = true, os.clock() + 0.2
	end
	input:FireServer(if group == "RigManeuvers" then "RigManeuver" else "GemSurge", id, aimPoint())
end
local function stopBeam()
	if beamHeld then
		beamHeld = false
		input:FireServer("CancelTech")
	end
end
for index, group in { "RigManeuvers", "GemSurges" } do
	local button = new("TextButton", {
		BackgroundColor3 = P.Inset,
		BackgroundTransparency = 0.15,
		TextColor3 = P.Text,
		TextSize = 11,
		TextWrapped = true,
		Size = UDim2.fromOffset(142, 58),
		Position = UDim2.fromOffset(12, 82 + (index - 1) * 66),
	}, gui)
	UiKit.round(button, 10)
	local cycle = new("TextButton", {
		BackgroundColor3 = P.Inset,
		TextColor3 = P.Gold,
		Text = ">",
		TextSize = 20,
		Size = UDim2.fromOffset(28, 40),
		Position = UDim2.fromOffset(158, 91 + (index - 1) * 66),
	}, gui)
	UiKit.round(cycle, 8)
	cycle.Activated:Connect(function()
		stopBeam()
		local available = Tree.available(GemClient.Profile, group)
		selected[group] = selected[group] % math.max(1, #available) + 1
	end)
	techButtons[group] = button
	if group == "GemSurges" then
		button.InputBegan:Connect(function(obj)
			if
				obj.UserInputType == Enum.UserInputType.Touch
				or obj.UserInputType == Enum.UserInputType.MouseButton1
			then
				if obj.UserInputType == Enum.UserInputType.Touch then
					surgeTouch = obj
				end
				triggerTech(group)
			end
		end)
		button.InputEnded:Connect(function(obj)
			if
				obj.UserInputType == Enum.UserInputType.Touch
				or obj.UserInputType == Enum.UserInputType.MouseButton1
			then
				stopBeam()
			end
		end)
	else
		button.Activated:Connect(function()
			triggerTech(group)
		end)
	end
end
local function makeSlot(id, label, key, position)
	local button, faceBox = IronUi.chunk(
		row,
		{ Color = Color3.fromRGB(52, 46, 70), Size = UDim2.fromOffset(80, 70), Radius = 35, Lip = 4, Stripes = "None" }
	)
	button.AnchorPoint, button.Position = Vector2.new(0.5, 1), position
	local name = text(faceBox, label, 12, P.Text, IronUi.Bold)
	name.Position = UDim2.fromOffset(4, 28)
	name.Size = UDim2.new(1, -8, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local keyLabel = text(faceBox, key, 10, P.Gold)
	keyLabel.Position = UDim2.fromOffset(6, 4)
	local timer = text(faceBox, "", 18, P.Gold, IronUi.Bold)
	timer.Position = UDim2.fromOffset(4, 18)
	timer.Size = UDim2.new(1, -8, 0, 25)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	slots[id] = { Button = button, Name = name, Timer = timer }
	return button
end
local attackButton = makeSlot("Basic", "LEFT", "Q / HOLD", UDim2.new(0, 56, 1, -32))
local heavyButton = makeSlot("Heavy", "RIGHT", "E / HOLD", UDim2.new(1, -56, 1, -32))
local dodgeButton = makeSlot("Dodge", "DODGE", "SPACE", UDim2.new(1, -56, 1, -210))
local blockButton = makeSlot("Block", "GUARD", "HOLD RMB", UDim2.new(0.5, 0, 1, -32))
local function pressInput(obj)
	return obj.UserInputType == Enum.UserInputType.MouseButton1 or obj.UserInputType == Enum.UserInputType.Touch
end
attackButton.InputBegan:Connect(function(obj)
	if pressInput(obj) and not holding then
		attackTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		beginAttack("Left")
	end
end)
attackButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		releaseAttack()
	end
end)
heavyButton.InputBegan:Connect(function(obj)
	if pressInput(obj) and not holding then
		attackTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		beginAttack("Right")
	end
end)
heavyButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		releaseAttack()
	end
end)
dodgeButton.Activated:Connect(dodge)
blockButton.InputBegan:Connect(function(obj)
	if pressInput(obj) then
		blockTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		setBlock(true)
	end
end)
blockButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		setBlock(false)
	end
end)
local leave = IronUi.gemButton(gui, "LEAVE ARENA", P.Gold, ArenaScene.leave)
leave.AnchorPoint = Vector2.new(1, 0)
leave.Position = UDim2.new(1, -12, 0, 82)
leave.Size = UDim2.fromOffset(160, 38)
local function cancel()
	attackTouch, blockTouch, surgeTouch = nil, nil, nil
	beamHeld = false
	input:FireServer("CancelTech")
	holding = false
	blockHeld = false
	input:FireServer("CancelAttack")
	input:FireServer("Block", false)
end
local function toggleGuide()
	cancel()
	AugmentTreeUI.close()
	CombatGuide.toggle()
	cursorFree = CombatGuide.isOpen()
	FirstPerson.setCursorFree(cursorFree)
end
local function toggleTree()
	cancel()
	CombatGuide.close()
	AugmentTreeUI.toggle()
	cursorFree = AugmentTreeUI.isOpen()
	FirstPerson.setCursorFree(cursorFree)
end
local treeButton = new("TextButton", {
	Text = "AUGMENT TREE · K",
	TextSize = 12,
	TextColor3 = P.Gold,
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(12, 214),
	Size = UDim2.fromOffset(142, 30),
}, gui)
UiKit.round(treeButton, 8)
treeButton.Activated:Connect(toggleTree)
local guideButton = new("TextButton", {
	Text = "?",
	TextSize = 22,
	TextColor3 = P.Gold,
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(12, 16),
	Size = UDim2.fromOffset(38, 40),
}, gui)
UiKit.round(guideButton, 10)
guideButton.Activated:Connect(toggleGuide)
ContextActionService:BindActionAtPriority("CombatAugmentTree", function(_, state)
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		toggleTree()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.K)
UserInputService.InputBegan:Connect(function(obj, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if obj.KeyCode == Enum.KeyCode.R then
		triggerTech("RigManeuvers")
	elseif obj.KeyCode == Enum.KeyCode.F then
		triggerTech("GemSurges")
	elseif obj.KeyCode == Enum.KeyCode.Z or obj.KeyCode == Enum.KeyCode.X then
		stopBeam()
		local group = if obj.KeyCode == Enum.KeyCode.Z then "RigManeuvers" else "GemSurges"
		local available = Tree.available(GemClient.Profile, group)
		selected[group] = selected[group] % math.max(1, #available) + 1
	elseif obj.KeyCode == Enum.KeyCode.Q then
		beginAttack("Left")
	elseif obj.KeyCode == Enum.KeyCode.E then
		beginAttack("Right")
	elseif obj.UserInputType == Enum.UserInputType.MouseButton1 then
		beginAttack()
	elseif obj.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(true)
	end
end)
UserInputService.InputEnded:Connect(function(obj)
	if obj == surgeTouch or obj.KeyCode == Enum.KeyCode.F then
		surgeTouch = nil
		stopBeam()
	end
	if obj == attackTouch then
		attackTouch = nil
		releaseAttack()
	end
	if obj == blockTouch then
		blockTouch = nil
		setBlock(false)
	end
	if
		obj.UserInputType == Enum.UserInputType.MouseButton1
		or obj.KeyCode == Enum.KeyCode.Q
		or obj.KeyCode == Enum.KeyCode.E
	then
		releaseAttack()
	elseif obj.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(false)
	end
end)
ContextActionService:BindActionAtPriority("CombatCursor", function(_, state)
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		cancel()
		if CombatGuide.isOpen() or AugmentTreeUI.isOpen() then
			CombatGuide.close()
			AugmentTreeUI.close()
			cursorFree = false
		else
			cursorFree = not cursorFree
		end
		FirstPerson.setCursorFree(cursorFree)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Tab)
UserInputService.WindowFocusReleased:Connect(cancel)
ContextActionService:BindActionAtPriority("UniversalDodge", function(_, state)
	if not canFight() or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		dodge()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space)
player.CharacterAdded:Connect(function()
	cancel()
	FirstPerson.stop()
	cursorFree = false
	cooldowns, techCooldowns = {}, {}
	nextAttack = 0
end)
player:GetAttributeChangedSignal("CombatSession"):Connect(function()
	cancel()
	FirstPerson.stop()
	cursorFree = false
	cooldowns, techCooldowns = {}, {}
	nextAttack = 0
end)
local lastActive = false
RunService.RenderStepped:Connect(function()
	local fight = canFight() == true
	gui.Enabled = fight
	leave.Visible = ArenaScene.isActive()
	if not fight then
		if lastActive then
			cancel()
			FirstPerson.stop()
			CombatGuide.close()
			AugmentTreeUI.close()
			guideWasOpen = false
			cursorFree = false
		end
		lastActive = false
		return
	end
	FirstPerson.start()
	local guideOpen = CombatGuide.isOpen() or AugmentTreeUI.isOpen()
	if guideOpen ~= guideWasOpen then
		cursorFree = guideOpen
		FirstPerson.setCursorFree(cursorFree)
	end
	guideWasOpen = guideOpen
	lastActive = true
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	if viewport.Y < 430 and viewport.X >= 600 then
		hud.AnchorPoint, hud.Position, hud.Size =
			Vector2.new(1, 0), UDim2.new(1, -12, 0, 140), UDim2.fromOffset(220, 118)
		dodgeButton.Position = UDim2.new(1, -56, 0, 80)
		leave.Position = UDim2.new(1, -12, 0, 88)
	else
		hud.AnchorPoint, hud.Position, hud.Size =
			Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -120), UDim2.fromOffset(280, 118)
		dodgeButton.Position = UDim2.new(1, -56, 1, if viewport.X < 500 then -270 else -116)
		leave.Position = UDim2.new(1, -12, 0, if viewport.X < 400 then 218 else 82)
	end
	local scale = math.min(1, math.max(0.65, (viewport.X - 20) / 280))
	local sizing = hud:FindFirstChildOfClass("UIScale")
	if not sizing then
		sizing = new("UIScale", {}, hud)
	end
	sizing.Scale = scale
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
		hp.Text = string.format(
			"HEALTH %d / %d · SHIELD %d",
			math.ceil(humanoid.Health),
			math.ceil(humanoid.MaxHealth),
			player:GetAttribute("Shield") or 0
		)
	end
	for id, bar in resourceBars do
		local amount, maximum = player:GetAttribute(id) or 0, player:GetAttribute("Max" .. id) or 100
		bar.Label.Text = string.format("%s  %d / %d", id:upper(), math.floor(amount), maximum)
		bar.Fill.Size = UDim2.fromScale(math.clamp(amount / math.max(1, maximum), 0, 1), 1)
	end
	for group, button in techButtons do
		local id = selectedTech(group)
		local definition = Tech.Catalog[id]
		local remaining = math.max(0, (techCooldowns[id] or 0) - os.clock())
		local loadout = GemClient.Profile and GemClient.Profile.Character
		local available = definition.Resource ~= "Charge" or (loadout and Tech.hasGem(loadout, definition.Element))
		button.TextColor3 = if available then P.Text else P.Dim
		button.Text = string.format(
			"%s %s\n%s · %d %s%s",
			definition.Icon,
			definition.Name,
			if group == "RigManeuvers" then "R · RIG MANEUVER" else "F · GEM SURGE",
			definition.Cost,
			definition.Resource,
			if not available
				then " · socket gem"
				elseif remaining > 0 then string.format(" · %.1fs", remaining)
				elseif definition.PerSecond then "/s · HOLD"
				else ""
		)
	end
	if beamHeld and os.clock() >= nextBeamUpdate then
		input:FireServer("GemSurge", "CryoStream", aimPoint())
		nextBeamUpdate = os.clock() + 0.2
	end
	local now = os.clock()
	chargeTrack.Visible = holding
	local elapsed = if holding then now - chargeStarted else 0
	local charged = Actions.charge(elapsed)
	chargeFill.Size = UDim2.fromScale(math.clamp(elapsed / Actions.PerfectAt, 0, 1), 1)
	chargeFill.BackgroundColor3 = if charged.Stage == "OVERCHARGED"
		then Color3.fromRGB(233, 70, 70)
		elseif charged.Perfect then P.Gold
		else Color3.fromRGB(83, 174, 204)
	reticle.TextColor3 = if holding then chargeFill.BackgroundColor3 elseif blockHeld then P.Gold else P.Text
	if holding then
		hint.Text = if charged.Perfect
			then "RELEASE! PERFECT WINDOW"
			elseif charged.Stage == "OVERCHARGED" then "OVERCHARGED - damage reduced"
			else attackSide:upper() .. " - RELEASE ON GOLD"
	elseif now > feedbackUntil then
		hint.Text = if cursorFree
			then "Tab to return to combat"
			elseif blockHeld then "GUARD UP"
			else "Alternate LEFT / RIGHT for combos"
	end
	if holding and elapsed > 3 then
		cancel()
	end
	FirstPerson.setPose(blockHeld, elapsed / Actions.PerfectAt)
	controlsHint.Visible = not UserInputService.TouchEnabled
	cursorModal.Modal = cursorFree
	local hit = aimedHit()
	local target = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	local enemyHumanoid = target and target:FindFirstChildOfClass("Humanoid")
	targetCard.Visible = enemyHumanoid ~= nil and enemyHumanoid.Health > 0 and target ~= player.Character
	if targetCard.Visible then
		local opponent = Players:GetPlayerFromCharacter(target)
		targetName.Text = string.format(
			"%s - %d / %d",
			if opponent then opponent.DisplayName else target.Name,
			math.ceil(enemyHumanoid.Health),
			math.ceil(enemyHumanoid.MaxHealth)
		)
		targetFill.Size =
			UDim2.fromScale(math.clamp(enemyHumanoid.Health / math.max(1, enemyHumanoid.MaxHealth), 0, 1), 1)
	end
	if blockHeld and now >= nextBlockUpdate then
		local aim = aimPoint()
		face(aim)
		input:FireServer("Block", true, aim)
		nextBlockUpdate = now + 0.15
	end
	for id, slot in slots do
		local cd = cooldowns[id]
		local remaining = if cd then math.max(0, cd.Ready - now) else 0
		if id == "Basic" or id == "Heavy" then
			remaining = math.max(0, nextAttack - now)
		end
		slot.Timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
	end
	slots.Block.Name.Text = if player:GetAttribute("Blocking") then "GUARD UP" else "GUARD"
end)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "CombatFx"
fxFolder.Parent = workspace

local function effectPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.CFrame = cframe
	part.Parent = fxFolder
	return part
end

local function fade(part: BasePart, seconds: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, seconds + 0.05)
end

-- A flat ring on the ground: a thin disc (cylinders lie along X).
local function ring(center: Vector3, radius: number, color: Color3, transparency: number): Part
	local disc = effectPart(
		Vector3.new(0.2, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
	disc.Transparency = transparency
	return disc
end

local function floorUnder(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder, player.Character :: Instance }
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position + Vector3.new(0, 0.15, 0) else position
end

local numbers = 0
local function damageNumber(position: Vector3, amount: number, crit: boolean, color: Color3?)
	if numbers > 40 then
		return -- plenty on screen already
	end
	numbers += 1
	local anchor =
		effectPart(Vector3.one * 0.1, CFrame.new(position + Vector3.new(math.random() - 0.5, 0, 0)), Color3.new())
	anchor.Transparency = 1
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(90, 40),
		AlwaysOnTop = true,
		MaxDistance = 120,
		StudsOffset = Vector3.zero,
	}, anchor)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		Text = tostring(amount) .. (if crit then "!" else ""),
		TextSize = if crit then 30 else 20,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
	}, board)
	TweenService:Create(board, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		numbers -= 1
		anchor:Destroy()
	end)
end

local handlers = {}
function handlers.TechStatus(message)
	hint.Text, feedbackUntil = message, os.clock() + 1
end
function handlers.TechCooldown(id, duration)
	techCooldowns[id] = os.clock() + duration
	nextAttack = math.max(nextAttack, os.clock() + duration)
	if Tech.Catalog[id].Resource == "Stamina" then
		FirstPerson.swing("Right")
	end
end
function handlers.TechPulse(_who, from, to, color, radius)
	local distance = (to - from).Magnitude
	if distance > 0.1 then
		local beam = effectPart(Vector3.new(0.16, 0.16, distance), CFrame.lookAt((from + to) / 2, to), color)
		fade(beam, 0.2)
	end
	if radius > 0 then
		for _, axis in { CFrame.new(), CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(0, 0, math.pi / 2) } do
			local pulse = effectPart(
				Vector3.new(0.15, radius * 2, radius * 2),
				CFrame.new(to) * axis,
				color,
				Enum.PartType.Cylinder
			)
			pulse.Transparency = 0.75
			fade(pulse, 0.35, pulse.Size * 1.25)
		end
	end
end
function handlers.TechField(who, color)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local panel = effectPart(
			Vector3.new(0.12, 1.5, 0.6),
			CFrame.new(root.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -1.5),
			color
		)
		panel.Transparency = 0.4
		fade(panel, 0.5)
	end
end
function handlers.HighBlock()
	hint.Text, feedbackUntil = "HIGH BLOCK - COUNTER!", os.clock() + 1
end
function handlers.Parried(seconds)
	cancel()
	nextAttack = math.max(nextAttack, os.clock() + seconds)
	hint.Text, feedbackUntil = "PARRIED", os.clock() + 0.9
end
function handlers.AttackTiming(stage, side, combo)
	hint.Text = stage .. (if combo > 1 then " - COMBO x" .. combo else "")
	feedbackUntil = os.clock() + 0.9
	FirstPerson.swing(side)
end

function handlers.Damage(position: Vector3, amount: number, crit: boolean, color: Color3?)
	damageNumber(position, amount, crit, color)
end

-- A fan of glowing blades across the swing's arc.
function handlers.Swing(
	_who: Player,
	origin: Vector3,
	direction: Vector3,
	range: number,
	arc: number,
	color: Color3,
	big: boolean
)
	local blades = math.clamp(math.floor(arc / 25), 2, 7)
	local base = math.atan2(-direction.X, -direction.Z)
	for i = 0, blades - 1 do
		local t = if blades > 1 then i / (blades - 1) - 0.5 else 0
		local angle = base + math.rad(arc) * t
		local reach = range * 0.6
		local cf = CFrame.new(origin + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -reach)
		local blade = effectPart(Vector3.new(if big then 0.5 else 0.3, 0.12, range * 0.6), cf, color)
		blade.Transparency = 0.2
		fade(blade, 0.22)
	end
end

function handlers.Shot(_who: Player, from: Vector3, to: Vector3, color: Color3, look: string?)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local isArrow = look == "Longbow"
		or look == "Shortbow"
		or look == "Crossbow"
		or look == "Knives"
		or look == "PowerShot"
	local size = if isArrow then Vector3.new(0.15, 0.15, 2) else Vector3.one * 0.8
	local bolt =
		effectPart(size, CFrame.lookAt(from, to), color, if isArrow then Enum.PartType.Block else Enum.PartType.Ball)
	local travel = math.clamp(distance / 140, 0.05, 0.5)
	TweenService
		:Create(
			bolt,
			TweenInfo.new(travel, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.lookAt(to, to + (to - from).Unit) }
		)
		:Play()
	task.delay(travel, function()
		fade(bolt, 0.15, bolt.Size * 1.8)
	end)
end

function handlers.Nova(center: Vector3, radius: number, color: Color3, delay: number)
	local floor = floorUnder(center)
	if delay and delay > 0 then
		-- Warning circle, then the blast.
		local warn = ring(floor, radius, Color3.fromRGB(255, 60, 40), 0.7)
		task.delay(delay, function()
			warn:Destroy()
			local blast = ring(floor, 1, color, 0.1)
			fade(blast, 0.45, Vector3.new(0.2, radius * 2, radius * 2))
			local pillar = effectPart(Vector3.new(2, 40, 2), CFrame.new(floor + Vector3.new(0, 20, 0)), color)
			fade(pillar, 0.4, Vector3.new(radius, 40, radius))
		end)
		return
	end
	local blast = ring(floor, 1, color, 0.2)
	fade(blast, 0.4, Vector3.new(0.2, radius * 2, radius * 2))
end

function handlers.Zone(center: Vector3, radius: number, duration: number, color: Color3)
	local floor = floorUnder(center)
	local disc = ring(floor, radius, color, 0.75)
	local edge = ring(floor + Vector3.new(0, 0.05, 0), radius, color, 0.4)
	edge.Size = Vector3.new(0.1, radius * 2, radius * 2)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and disc.Parent do
			-- Falling streaks: arrows raining, sparks, whatever the class throws.
			local offset = Vector3.new((math.random() - 0.5) * radius * 1.6, 0, (math.random() - 0.5) * radius * 1.6)
			local streak =
				effectPart(Vector3.new(0.15, 3, 0.15), CFrame.new(floor + offset + Vector3.new(0, 12, 0)), color)
			TweenService:Create(streak, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(floor + offset + Vector3.new(0, 1.5, 0)),
			}):Play()
			Debris:AddItem(streak, 0.35)
			task.wait(0.08)
		end
		fade(disc, 0.3)
		fade(edge, 0.3)
	end)
end

function handlers.Buff(who: Player, color: Color3)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local halo = ring(root.Position - Vector3.new(0, 2.5, 0), 2, color, 0.2)
		fade(halo, 0.6, Vector3.new(0.2, 9, 9))
	end
end

function handlers.Arc(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	local bolt = effectPart(Vector3.new(0.2, 0.2, distance), CFrame.lookAt((from + to) / 2, to), color)
	fade(bolt, 0.2)
end

function handlers.Death(position: Vector3, color: Color3?)
	for _ = 1, 8 do
		local shard = effectPart(
			Vector3.new(0.5, 0.9, 0.5),
			CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			color or Color3.new(1, 1, 1)
		)
		local fling = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * 6
		TweenService:Create(shard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = shard.CFrame + fling,
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, 0.65)
	end
end

function handlers.EnemySwing(from: Vector3, to: Vector3, color: Color3)
	local mid = from:Lerp(to, 0.7)
	local slash =
		effectPart(Vector3.new(2.5, 0.15, 0.5), CFrame.lookAt(mid, to) * CFrame.Angles(0, 0, math.rad(35)), color)
	fade(slash, 0.25)
end

function handlers.Cooldown(id, seconds)
	cooldowns[id] = { Ready = os.clock() + seconds, Total = seconds }
	if id == "Basic" or id == "Heavy" then
		nextAttack = os.clock() + seconds
	end
end
function handlers.BlockBroken(seconds)
	blockHeld = false
	cooldowns.Block = { Ready = os.clock() + seconds, Total = seconds }
	UiKit.toast("Guard broken!", P.Gold)
end
function handlers.BlockSpark(position, broken)
	local spark = ring(position, if broken then 2 else 1, if broken then Color3.fromRGB(255, 160, 50) else P.Teal, 0.2)
	fade(spark, 0.2, Vector3.new(0.1, 6, 6))
end
function handlers.BlockRaise(who)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local plate = effectPart(Vector3.new(2.4, 2.5, 0.1), root.CFrame * CFrame.new(0, 0, -2), P.Teal)
		plate.Transparency = 0.6
		fade(plate, 0.2)
	end
end
function handlers.BlockGem(who, element)
	local colors = {
		Fire = Color3.fromRGB(255, 100, 55),
		Frost = Color3.fromRGB(90, 195, 255),
		Poison = Color3.fromRGB(100, 230, 130),
		Shock = Color3.fromRGB(255, 230, 80),
	}
	handlers.Buff(who, colors[element] or P.Teal)
end
function handlers.DodgeRoll(who, origin, direction, distance, afterimage)
	local color = if afterimage then Color3.fromRGB(80, 225, 255) else P.Gold
	for i = 0, 4 do
		task.delay(i * 0.05, function()
			local cf = CFrame.lookAt(origin + direction * distance * i / 4, origin + direction * (distance * i / 4 + 1))
			local ghost =
				effectPart(if afterimage then Vector3.new(1.4, 2.6, 0.4) else Vector3.new(1.8, 0.15, 1), cf, color)
			ghost.Transparency = 0.55
			fade(ghost, 0.25)
		end)
	end
	if who == player then
		holding = false
	end
end
fxEvent.OnClientEvent:Connect(function(kind, ...)
	local handler = handlers[kind]
	if handler then
		handler(...)
	end
end)
