-- Pilot your mech. The server makes you a mech's pilot (your MechPilot
-- attribute: Shared.MechPilot) and welds you into its cockpit; this screen
-- drives it, so it answers your keys at once. Each frame: the speed and
-- heading from your input (Shared.Outpost.drive), then the move over the
-- ground (MechPilot.move: walls, kerbs, drops, the rim), then the mech is put
-- there, you with it. About 15 times a second it tells the server where it
-- is (MechMove); the server checks it and passes it on to everyone else.
-- Space (or jump) gets you out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local MechPilot = require(ReplicatedStorage.Shared.MechPilot)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

task.spawn(function() require(script.Parent.MechAnimation) end)

local VehicleDrive = {}
local player = Players.LocalPlayer
local P = IronUi.Colors

local SEND_EVERY = 1 / 15 -- seconds between moves sent while it's moving
-- Pushing into something this long, it goes through it for this long.
local UNSTICK_AFTER, UNSTICK_FOR = 1.5, 1
-- Moving, with no word back from the server this long: it isn't hearing you.
local DEAF_AFTER = 2

type Driving = {
	Id: string,
	Model: Model,
	Chassis: BasePart,
	Spec: any,
	Mech: any, -- MechPilot.state
	Turn: number,
	Zoom: { number },
	World: any,
	Params: RaycastParams?,
	ParamsAt: number,
	-- What it last told the server, and when the server last answered.
	SentAt: number,
	SentPosition: Vector3?,
	SentMoving: boolean,
	HeardAt: number,
	MovedAt: number?,
	Reported: boolean,
	-- Pushing into something.
	PushedFor: number,
	ThroughUntil: number,
	Hinted: boolean,
	Connections: { RBXScriptConnection },
}
local driving: Driving? = nil
local function blocked(): boolean
	return not player:GetAttribute("Outpost")
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("ArenaDropPreparing") ~= nil
		or player:GetAttribute("ArenaDropUntil") ~= nil
		or player:GetAttribute("Expedition") ~= nil
end

-- What the pilot is asking for, -1..1 each: the keys, else the controls'
-- move vector (a thumbstick, a gamepad).
local controlModule = nil
local loadingControls = false
local function moveVector(): Vector3?
	if controlModule == nil and not loadingControls then
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			return nil
		end
		loadingControls = true
		-- Requiring PlayerModule can yield during startup. Never suspend the
		-- driving (or the keys) while it loads.
		task.spawn(function()
			local ok, found = pcall(function() return require(module):GetControls() end)
			controlModule = if ok and found then found else false
			loadingControls = false
		end)
	end
	if not controlModule then
		return nil
	end
	local ok, move = pcall(controlModule.GetMoveVector, controlModule)
	return if ok and typeof(move) == "Vector3" then move else nil
end
local function held(...): boolean
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end
-- Also says where the input came from: "keys", "controls" or "none".
local function pilotInput(): (number, number, string)
	if UserInputService:GetFocusedTextBox() then return 0, 0, "none" end
	local K = Enum.KeyCode
	if held(K.W, K.Up, K.S, K.Down, K.A, K.Left, K.D, K.Right) then
		local throttle = (if held(K.W, K.Up) then 1 else 0) - (if held(K.S, K.Down) then 1 else 0)
		local steer = (if held(K.D, K.Right) then 1 else 0) - (if held(K.A, K.Left) then 1 else 0)
		if throttle ~= 0 or steer ~= 0 then
			return throttle, steer, "keys"
		end
	end
	local move = moveVector()
	if move and move.Magnitude > 0.05 then
		return math.clamp(-move.Z, -1, 1), math.clamp(move.X, -1, 1), "controls"
	end
	return 0, 0, "none"
end

local function remote(name: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild(name) :: RemoteEvent?
end

-- What the mech bumps into, seen from here: everything solid but itself,
-- the players, and the Outpost's creatures and rifts.
local function params(model: Model): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.RespectCanCollide = true
	local skip = { model }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	for _, name in { "Enemies", "Kaiju", "Rifts", "RiftTears" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(skip, found)
		end
	end
	p.FilterDescendantsInstances = skip
	return p
end
-- The world it moves through (MechPilot.move), from this screen. A cast that
-- fails counts as nothing there, so nothing ever holds the mech still.
function VehicleDrive.world(d: Driving)
	return {
		Sweep = function(from: CFrame, size: Vector3, direction: Vector3): (number?, string?)
			local ok, hit = pcall(workspace.Blockcast, workspace, from, size, direction, d.Params)
			if ok and hit then
				return hit.Distance, hit.Instance.Name
			end
			return nil, nil
		end,
		Floor = function(origin: Vector3, length: number): number?
			local ok, hit = pcall(workspace.Raycast, workspace, origin, Vector3.new(0, -length, 0), d.Params)
			return if ok and hit then hit.Position.Y else nil
		end,
		Rim = { Center = Rules.Location.Position, Radius = Rules.Radius + 40 },
		Gravity = workspace.Gravity,
	}
end

-- Tell the server where it is: while it moves, SEND_EVERY; stopping, at once.
local function send(d: Driving, force: boolean?)
	local m = d.Mech
	local now = os.clock()
	local moving = m.Speed ~= 0 or d.Turn ~= 0
	if not force then
		if moving and now - d.SentAt < SEND_EVERY then
			return
		end
		if not moving and not d.SentMoving then
			return
		end
	end
	local move = remote("MechMove")
	if move then
		move:FireServer(m.Position, m.Yaw, m.Speed, d.Turn)
		d.SentAt, d.SentPosition, d.SentMoving = now, m.Position, moving
	end
end

-- Moving, and the server hasn't answered for a while.
local function deaf(d: Driving, now: number): boolean
	return d.MovedAt ~= nil and now - d.MovedAt < DEAF_AFTER and now - d.HeardAt > DEAF_AFTER
end

local function report(d: Driving, source: string)
	if d.Reported then
		return
	end
	d.Reported = true
	local m = d.Mech
	local text = string.format(
		"driving %s from %s at (%.0f, %.1f, %.0f), speed %.1f, no word back from the server for %.1f s",
		d.Id,
		source,
		m.Position.X,
		m.Position.Y,
		m.Position.Z,
		m.Speed,
		os.clock() - d.HeardAt
	)
	warn("[Mech] Server isn't hearing this pilot: " .. text)
	local channel = remote("MechReport")
	if channel then
		channel:FireServer(text)
	end
end

-- The driving card.
local gui = UiKit.gui("DriveHud", 6)
gui.Enabled = false
local card = IronUi.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -44),
	Size = UDim2.fromOffset(340, 78),
	BackgroundColor3 = Color3.fromRGB(10, 12, 20),
	BackgroundTransparency = 0.15,
}, gui)
UiKit.round(card, 10)
IronUi.new("UIStroke", { Color = Color3.fromRGB(242, 182, 36), Transparency = 0.3, Thickness = 1.5 }, card)
local title = IronUi.text(card, "", 15, Color3.fromRGB(242, 182, 36), IronUi.Bold)
title.Position, title.Size = UDim2.fromOffset(14, 8), UDim2.fromOffset(220, 20)
local blurb = IronUi.text(card, "", 11, P.Dim, IronUi.Body)
blurb.Position, blurb.Size = UDim2.fromOffset(14, 27), UDim2.fromOffset(220, 14)
local speedLabel = IronUi.text(card, "0", 30, P.Text, IronUi.Heading)
speedLabel.AnchorPoint = Vector2.new(1, 0)
speedLabel.Position, speedLabel.Size = UDim2.new(1, -14, 0, 4), UDim2.fromOffset(100, 34)
speedLabel.TextXAlignment = Enum.TextXAlignment.Right
local unit = IronUi.text(card, "STUDS/S", 10, P.Dim, IronUi.Bold)
unit.AnchorPoint = Vector2.new(1, 0)
unit.Position, unit.Size = UDim2.new(1, -14, 0, 36), UDim2.fromOffset(60, 12)
unit.TextXAlignment = Enum.TextXAlignment.Right
local track = IronUi.new("Frame", {
	Position = UDim2.fromOffset(14, 47),
	Size = UDim2.new(1, -28, 0, 5),
	BackgroundColor3 = P.Inset,
}, card)
UiKit.round(track, 3)
local fill =
	IronUi.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(242, 182, 36) }, track)
UiKit.round(fill, 3)
local controls = IronUi.text(card, "", 11, P.Dim, IronUi.Bold)
controls.Position, controls.Size = UDim2.fromOffset(14, 57), UDim2.new(1, -28, 0, 14)

local function controlText(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Thumbstick to drive  |  Jump to hop out"
	end
	return "W/S drive  |  A/D steer  |  SPACE to hop out"
end

local function finish()
	local d = driving
	driving = nil
	gui.Enabled = false
	if not d then
		return
	end
	for _, connection in d.Connections do
		connection:Disconnect()
	end
	-- (Not over the combat camera's zoom.)
	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMinZoomDistance = d.Zoom[1]
		player.CameraMaxZoomDistance = d.Zoom[2]
	end
end

-- Menus own the screen even while you're in a mech. Track instances, so
-- closing one of several overlays does not reveal the HUD.
local blockingScreens = {
	Dashboard = true, Shop = true, Season = true, AugmentTree = true,
	SurgeArray = true, Social = true, ProbeExchange = true, WelcomeBundle = true,
	Intro = true, Tutorial = true, MarketBoard = true, ChallengeChooser = true,
	StreakRewards = true, Character = true, Combat = true, Mine = true,
	Party = true, Referral = true, TopPlayers = true, EquipmentTrade = true,
}
local openScreens, screenConnections = {}, {}
local function menuOpen(): boolean
	return next(openScreens) ~= nil or GuiService.MenuIsOpen
end
local function refreshHud()
	gui.Enabled = driving ~= nil and not blocked() and not menuOpen()
end
local function watchScreen(screen)
	if not screen:IsA("ScreenGui") or (not blockingScreens[screen.Name] and screen.Name ~= "TrainingRewards") then return end
	if screenConnections[screen] then return end
	local function update()
		local modal = screen.Name ~= "TrainingRewards" or screen:GetAttribute("BlocksMiningHud") == true
		openScreens[screen] = if screen.Parent and screen.Enabled and modal then true else nil
		refreshHud()
	end
	screenConnections[screen] = {
		screen:GetPropertyChangedSignal("Enabled"):Connect(update),
		screen:GetAttributeChangedSignal("BlocksMiningHud"):Connect(update),
	}
	update()
end
local function unwatchScreen(screen)
	for _, connection in screenConnections[screen] or {} do connection:Disconnect() end
	screenConnections[screen], openScreens[screen] = nil, nil
	refreshHud()
end

-- Start driving the mech `id`, once it's here.
local function begin(id: string)
	local model = MechPilot.find(id)
	local chassis = model and model.PrimaryPart
	local spec = Rules.Machines[MechPilot.kind(model) or ""]
	if not model or model.Parent == nil or not chassis or not spec then
		return
	end
	local now = os.clock()
	local d: Driving = {
		Id = id,
		Model = model,
		Chassis = chassis,
		Spec = spec,
		Mech = MechPilot.state(model),
		Turn = 0,
		Zoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance },
		World = nil,
		Params = params(model),
		ParamsAt = now,
		SentAt = 0,
		SentPosition = nil,
		SentMoving = false,
		HeardAt = now,
		MovedAt = nil,
		Reported = false,
		PushedFor = 0,
		ThroughUntil = 0,
		Hinted = false,
		Connections = {},
	}
	d.World = VehicleDrive.world(d)
	-- (Turning on the spot only changes MechMotion.)
	for _, name in { "MechPosition", "MechMotion" } do
		local connection = model:GetAttributeChangedSignal(name):Connect(function()
			d.HeardAt = os.clock()
		end)
		table.insert(d.Connections, connection)
	end
	driving = d
	-- Hello: the server knows this screen is driving (and logs one that isn't).
	send(d, true)
	print("[Mech] Piloting " .. id .. ": driving from this screen")
	local fit = model:GetAttribute("CameraFit") or math.max(14, chassis.Size.Z * 1.15)
	player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, fit * 2)
	player.CameraMinZoomDistance = fit
	title.Text = string.upper(spec.Name)
	blurb.Text = spec.Blurb
	controls.Text = controlText()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.Sit = true -- (the pose)
		end)
	end
	refreshHud()
end

local function hud(d: Driving, blockedBy: string?, now: number)
	local speed = math.abs(d.Mech.Speed)
	speedLabel.Text = tostring(math.floor(speed + 0.5))
	fill.Size = UDim2.fromScale(math.clamp(speed / d.Spec.MaxSpeed, 0, 1), 1)
	local line = if deaf(d, now)
		then "The server isn't answering: others can't see you move"
		elseif blockedBy then "Something's in the way"
		else d.Spec.Blurb
	if blurb.Text ~= line then
		blurb.Text = line
	end
end

-- One frame of driving (before the camera follows you).
function VehicleDrive.step(dt: number)
	local id = MechPilot.of(player)
	if not id or blocked() then
		finish()
		return
	end
	if driving and (driving.Id ~= id or driving.Model.Parent == nil) then
		finish()
	end
	if not driving then
		begin(id)
	end
	local d = driving
	if not d then
		return -- (its mech hasn't streamed in yet)
	end
	dt = math.clamp(dt, 0, 0.1)
	local now = os.clock()
	if now - d.ParamsAt > 1 then
		d.Params, d.ParamsAt = params(d.Model), now
	end
	local throttle, steer, source = 0, 0, "none"
	if not menuOpen() then
		throttle, steer, source = pilotInput()
	end
	local m = d.Mech
	local before = m.Yaw
	local speed, yaw = Rules.drive(d.Spec, m.Speed, m.Yaw, throttle, steer, dt)
	m.Through = now < d.ThroughUntil
	local blockedBy = MechPilot.move(m, d.World, speed * dt, yaw, dt)
	m.Speed = if blockedBy then 0 else speed
	d.Turn = if dt > 0 then (m.Yaw - before) / dt else 0
	-- Pushing into something a moment: then through it, for a moment.
	if blockedBy and math.abs(throttle) >= 0.5 then
		d.PushedFor += dt
		if d.PushedFor >= UNSTICK_AFTER then
			d.PushedFor, d.ThroughUntil = 0, now + UNSTICK_FOR
			if not d.Hinted then
				d.Hinted = true
				UiKit.toast("Something's in the way: pushing through.")
			end
		end
	else
		d.PushedFor = 0
	end
	d.Chassis.CFrame = MechPilot.frame(m)
	if m.Speed ~= 0 or d.Turn ~= 0 then
		d.MovedAt = now
	end
	send(d)
	if deaf(d, now) and now - d.HeardAt > DEAF_AFTER * 2 then
		report(d, source)
	end
	hud(d, blockedBy, now)
	refreshHud()
end

function VehicleDrive.isDriving(): boolean
	return driving ~= nil
end

UserInputService.JumpRequest:Connect(function()
	if not driving or blocked() or menuOpen() or UserInputService:GetFocusedTextBox() then return end
	local leave = remote("MechExit")
	if leave then leave:FireServer() end
end)

local function refreshSession()
	if blocked() or not MechPilot.of(player) then
		finish()
	end
end
for _, attribute in { "Outpost", "CombatSession", "ArenaDropPreparing", "ArenaDropUntil", "Expedition", "MechPilot" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshSession)
end

local playerGui = player:WaitForChild("PlayerGui")
playerGui.ChildAdded:Connect(watchScreen)
playerGui.ChildRemoved:Connect(unwatchScreen)
for _, screen in playerGui:GetChildren() do watchScreen(screen) end
GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(refreshHud)

player.CharacterAdded:Connect(finish)
RunService:BindToRenderStep("MechPilotDrive", Enum.RenderPriority.Camera.Value - 1, VehicleDrive.step)

return VehicleDrive
