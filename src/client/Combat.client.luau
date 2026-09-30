--[[
	Combat on the client: controls, the hotbar and every effect you see.

	Controls (only outside town, or in the Arena):
	  Left click (hold to keep swinging)   basic attack with your weapon
	  Q / E / R                            your three chosen abilities
	  F                                    your class ultimate
	  K                                    choose abilities (AbilitiesUI)
	The hotbar buttons work too, for touch screens.

	The server decides every hit; this script sends what you pressed and
	where you aimed, moves your character for dashes, and draws swings,
	shots, blasts, zones and floating damage numbers.
]]
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local AbilitiesUI = require(script.Parent.Modules.AbilitiesUI)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local input = remotes:WaitForChild("CombatInput") :: RemoteEvent
local fxEvent = remotes:WaitForChild("CombatFx") :: RemoteEvent

local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text
local BOLD = IronUi.Bold

local cooldowns: { [string]: { Ready: number, Total: number } } = {}
local rateBuff = { Mult = 1, Until = 0 }
local nextAttack = 0
local holding = false

-- What the player has equipped ------------------------------------------------------------------

local function loadout()
	local profile = GemClient.Profile
	local character = profile and profile.Character
	local class = character and Classes.get(character.Class)
	if not class then
		return nil
	end
	local weapon = Classes.weapon(class.Id, character.Weapon)
	return {
		Class = class,
		Weapon = weapon,
		Slots = Classes.loadout(class.Id, character.Abilities),
		Ultimate = class.Ultimate,
	}
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function introOpen(): boolean
	return player.PlayerGui:FindFirstChild("Intro") ~= nil
end

local function canFight(): boolean
	local root = rootPart()
	return root ~= nil and not introOpen() and Combat.canFight(root.Position)
end

-- Where the mouse points in the world (or straight ahead on touch screens).
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimPoint(): Vector3
	local root = rootPart()
	local fallback = if root then root.Position + root.CFrame.LookVector * 30 else Vector3.zero
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return fallback
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	aimParams.FilterDescendantsInstances =
		{ player.Character :: Instance, workspace:FindFirstChild("CombatFx") :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, aimParams)
	return if hit then hit.Position else ray.Origin + ray.Direction * 120
end

-- Turn to face where you're attacking.
local function face(target: Vector3)
	local root = rootPart()
	if root then
		local flat = Vector3.new(target.X, root.Position.Y, target.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

-- Actions -----------------------------------------------------------------------------------------

local function tryAttack()
	local kit = loadout()
	if not kit or not kit.Weapon or not kit.Weapon.Attack or not canFight() then
		return
	end
	local now = os.clock()
	if now < nextAttack then
		return
	end
	local rate = kit.Weapon.Attack.Rate * (if now < rateBuff.Until then rateBuff.Mult else 1)
	nextAttack = now + rate
	local aim = aimPoint()
	face(aim)
	input:FireServer("Attack", aim)
end

local function tryAbility(slot: number)
	local kit = loadout()
	if not kit then
		return
	end
	if not canFight() then
		UiKit.toast("You can't fight in town. Head to the Arena or out the south gate.", UiKit.Colors.Dim)
		return
	end
	local ability = if slot == 4 then kit.Ultimate else kit.Slots[slot]
	local cd = ability and cooldowns[ability.Id]
	if not ability or (cd and os.clock() < cd.Ready) then
		return
	end
	local aim = aimPoint()
	face(aim)
	input:FireServer("Ability", slot, aim)
end

-- HUD -------------------------------------------------------------------------------------------------

local gui = UiKit.gui("CombatHud", 3)
local hud = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(392, 110),
	BackgroundTransparency = 1,
}, gui)

local function bar(y: number, color: Color3): (Frame, TextLabel)
	local back = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 16, 14),
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 14),
	}, hud)
	UiKit.round(back, 7)
	new("UIStroke", { Color = P.Ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, back)
	local fill = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) }, back)
	UiKit.round(fill, 7)
	-- A glossy top half on the fill.
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 190, 190)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
		}),
	}, fill)
	local label = text(back, "", 11, Color3.new(1, 1, 1), IronUi.Chunky)
	label.Size = UDim2.fromScale(1, 1)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 3
	return fill, label
end
local healthFill, healthLabel = bar(0, Color3.fromRGB(200, 50, 50))
local shieldFill = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(180, 220, 255),
	BackgroundTransparency = 0.3,
	Size = UDim2.fromScale(0, 1),
	ZIndex = 2,
}, healthFill.Parent)
UiKit.round(shieldFill, 7)
local resourceFill, resourceLabel = bar(18, Color3.fromRGB(70, 130, 255))

local slots = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 0, 68),
}, hud)
UiKit.list(slots, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center

local zoneLabel = text(gui, "", 13, P.Gold, BOLD)
zoneLabel.AnchorPoint = Vector2.new(0.5, 1)
zoneLabel.Position = UDim2.new(0.5, 0, 1, -128)
zoneLabel.Size = UDim2.fromOffset(420, 18)
zoneLabel.TextXAlignment = Enum.TextXAlignment.Center
zoneLabel.TextStrokeTransparency = 0.5

type Slot = {
	Button: TextButton,
	Name: TextLabel,
	Shade: Frame,
	Timer: TextLabel,
	Stroke: UIStroke,
	Rim: Frame,
	Face: Frame,
	Ability: any?,
}
local slotUi: { Slot } = {}

local function makeSlot(order: number, key: string, onPress: () -> ()): Slot
	-- A chunky slab; its rim takes the class colour.
	local button, slab = IronUi.chunk(slots, {
		Color = Color3.fromRGB(52, 46, 70),
		Size = UDim2.fromOffset(64, 68),
		Radius = 12,
		Lip = 5,
		Stripes = "None",
	})
	button.LayoutOrder = order
	local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
	local rim = slab.Parent :: Frame
	local keyLabel = text(slab, key, 12, P.Gold, IronUi.Chunky)
	keyLabel.Position = UDim2.fromOffset(5, 3)
	keyLabel.Size = UDim2.fromOffset(40, 14)
	keyLabel.AutomaticSize = Enum.AutomaticSize.None
	keyLabel.ZIndex = 4
	local name = text(slab, "", 11, Color3.new(1, 1, 1), IronUi.Chunky)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -4)
	name.Size = UDim2.new(1, -6, 0, 28)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Bottom
	name.ZIndex = 4
	local shade = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 5,
	}, slab)
	UiKit.round(shade, 9)
	local timer = text(slab, "", 20, Color3.new(1, 1, 1), IronUi.Heading)
	timer.Size = UDim2.fromScale(1, 1)
	timer.AutomaticSize = Enum.AutomaticSize.None
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.ZIndex = 6
	button.Activated:Connect(onPress)
	return { Button = button, Name = name, Shade = shade, Timer = timer, Stroke = stroke, Rim = rim, Face = slab }
end

slotUi[0] = makeSlot(0, "CLICK", tryAttack)
for i, key in Classes.AbilityKeys do
	slotUi[i] = makeSlot(i, key, function()
		tryAbility(i)
	end)
end
slotUi[4] = makeSlot(4, Classes.UltimateKey, function()
	tryAbility(4)
end)
local abilitiesButton = IronUi.button(slots, "K", false, AbilitiesUI.toggle)
abilitiesButton.LayoutOrder = 5
abilitiesButton.Size = UDim2.fromOffset(0, 68)

local function refreshSlots()
	local kit = loadout()
	gui.Enabled = kit ~= nil and not introOpen()
	if not kit then
		return
	end
	local weapon = kit.Weapon
	slotUi[0].Name.Text = if weapon then weapon.Name:gsub("^Iron ", "") else "Attack"
	slotUi[0].Rim.BackgroundColor3 = kit.Class.Color
	for i = 1, 3 do
		local ability = kit.Slots[i]
		slotUi[i].Ability = ability
		slotUi[i].Name.Text = if ability then ability.Name else ""
		slotUi[i].Rim.BackgroundColor3 = kit.Class.Color
	end
	slotUi[4].Ability = kit.Ultimate
	slotUi[4].Name.Text = kit.Ultimate.Name
	slotUi[4].Rim.BackgroundColor3 = P.Gold
	slotUi[4].Stroke.Thickness = 4
	resourceFill.BackgroundColor3 = Combat.ResourceColors[kit.Class.ResourceId] or resourceFill.BackgroundColor3
end
GemClient.Changed:Connect(refreshSlots)
player.PlayerGui.ChildRemoved:Connect(function(child)
	if child.Name == "Intro" then
		task.defer(refreshSlots)
	end
end)
refreshSlots()

-- Bars, cooldowns and the zone hint, every frame.
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local now = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		healthLabel.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		local shield = player:GetAttribute("Shield") or 0
		shieldFill.Size = UDim2.fromScale(math.clamp(shield / humanoid.MaxHealth, 0, 1), 1)
	end
	local resource = player:GetAttribute("Resource") or 0
	local max = player:GetAttribute("ResourceMax") or 100
	resourceFill.Size = UDim2.fromScale(math.clamp(resource / max, 0, 1), 1)
	resourceLabel.Text = string.format("%s %d / %d", player:GetAttribute("ResourceKind") or "", resource, max)
	for i = 1, 4 do
		local ui = slotUi[i]
		local ability = ui.Ability
		local cd = ability and cooldowns[ability.Id]
		local left = if cd then cd.Ready - now else 0
		if left > 0 then
			ui.Shade.Size = UDim2.fromScale(1, left / cd.Total)
			ui.Timer.Text = if left >= 1 then tostring(math.ceil(left)) else string.format("%.1f", left)
		else
			ui.Shade.Size = UDim2.fromScale(1, 0)
			ui.Timer.Text = ""
		end
		-- Dim what you can't afford yet.
		local short = ability and (ability.Cost or 0) > resource
		ui.Name.TextTransparency = if short then 0.55 else 0
	end
	local fight = canFight()
	zoneLabel.Text = if fight then "" else "TOWN: fighting is off. Arena (west road) or the Crystal Wilds (south gate)."
	for i = 0, 4 do
		local fade = if fight then 0 else 0.5
		slotUi[i].Button.BackgroundTransparency = fade
		slotUi[i].Rim.BackgroundTransparency = fade
		slotUi[i].Face.BackgroundTransparency = fade
	end
	if holding and fight then
		tryAttack()
	end
end)

-- Input --------------------------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(inputObject, processed)
	if processed then
		return
	end
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		tryAttack()
	end
end)
UserInputService.InputEnded:Connect(function(inputObject)
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
	end
end)

local KEYS = { Q = 1, E = 2, R = 3, F = 4 }
ContextActionService:BindAction("GemsoulAbilities", function(_, state, inputObject)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	-- In town, E still talks to shopkeepers.
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	local slot = KEYS[inputObject.KeyCode.Name]
	if slot then
		tryAbility(slot)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.F)

ContextActionService:BindAction("GemsoulAbilityPicker", function(_, state)
	if state == Enum.UserInputState.Begin and not introOpen() then
		AbilitiesUI.toggle()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.K)

-- Effects ---------------------------------------------------------------------------------------------------

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

-- Just for the caster --------------------------------------------------------------------------------------

function handlers.Cooldown(abilityId: string, seconds: number)
	cooldowns[abilityId] = { Ready = os.clock() + seconds, Total = seconds }
	local kit = loadout()
	local ability = kit and Classes.ability(kit.Class.Id, abilityId)
	if ability and ability.RateMult then
		rateBuff = { Mult = ability.RateMult, Until = os.clock() + (ability.Duration or 0) }
	end
end

function handlers.NoResource()
	local kind = player:GetAttribute("ResourceKind") or "resource"
	resourceFill.BackgroundColor3 = Color3.new(1, 1, 1)
	task.delay(0.12, refreshSlots)
	UiKit.toast("Not enough " .. kind .. ".", UiKit.Colors.Bad)
end

-- Dashes, rolls and blinks move your own character (the server hits around
-- where you land).
function handlers.Dash(distance: number, backward: boolean, teleport: boolean, aim: Vector3)
	local root = rootPart()
	if not root then
		return
	end
	local direction = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	direction = if direction.Magnitude > 0.1 then direction.Unit else root.CFrame.LookVector
	if backward then
		direction = -direction
	end
	-- Stop short of walls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, fxFolder }
	local hit = workspace:Raycast(root.Position, direction * distance, params)
	local travel = if hit then math.max(0, (hit.Position - root.Position).Magnitude - 2) else distance
	if teleport then
		local flash = ring(root.Position - Vector3.new(0, 2.5, 0), 1.5, Color3.fromRGB(170, 120, 255), 0.2)
		fade(flash, 0.4, Vector3.new(0.2, 6, 6))
		root.CFrame = root.CFrame + direction * travel
		return
	end
	local seconds = 0.25
	local speed = travel / seconds
	local stop = os.clock() + seconds
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() >= stop or not root.Parent then
			connection:Disconnect()
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			return
		end
		root.AssemblyLinearVelocity = direction * speed + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	end)
end

fxEvent.OnClientEvent:Connect(function(kind: string, ...)
	local handler = handlers[kind]
	if handler then
		handler(...)
	end
end)
