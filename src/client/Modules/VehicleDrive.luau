-- Pilot your mech. The server makes you a mech's pilot (your MechPilot
-- attribute: Shared.MechPilot) and welds you into its cockpit; this screen
-- drives it, so it answers your keys at once. Each frame: the speed and
-- heading from your input (Shared.Outpost.drive), then the move over the
-- ground (MechPilot.move: walls, kerbs, drops, the rim), then the mech is put
-- there, you with it. About 15 times a second it tells the server where it
-- is (MechMove); the server checks it and passes it on to everyone else.
-- Space (or jump) gets you out. On a touch screen it has a stick of its own
-- (bottom left), so a phone never waits on Roblox's controls. Drive it into a
-- rock and it mines it (VehicleDrive.shoving, Shared.WalkMine).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local MechPilot = require(ReplicatedStorage.Shared.MechPilot)
local WalkMine = require(ReplicatedStorage.Shared.WalkMine)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local UiKit = require(script.Parent.UiKit)

task.spawn(function() require(script.Parent.MechAnimation) end)

local VehicleDrive = {}
local player = Players.LocalPlayer

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
	MovingSince: number, -- (this stretch of moving began: the server can't have answered before)
	Reported: boolean,
	ToldDeaf: boolean,
	-- Pushing into something.
	PushedFor: number,
	ThroughUntil: number,
	Hinted: boolean,
	-- What its hull last stopped against, and the rock it's shoving (and when).
	Hit: Instance?,
	Shoving: Model?,
	ShovedAt: number,
	-- Your body, and its auto-jump from before (off while you pilot).
	Humanoid: any,
	AutoJump: boolean?,
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

-- What the pilot is asking for, -1..1 each: the keys, else the drive stick
-- (a touch screen), else the controls' move vector (a gamepad, Roblox's
-- thumbstick).
local controlModule = nil
local loadingControls, controlsRetryAt = false, 0
local function moveVector(): Vector3?
	if not controlModule and not loadingControls and os.clock() >= controlsRetryAt then
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			return nil
		end
		loadingControls = true
		-- Requiring PlayerModule can yield during startup. Never suspend the
		-- driving (or the keys) while it loads, and try again if it fails:
		-- once, it used to leave a phone's thumbstick dead for the session.
		task.spawn(function()
			local ok, found = pcall(function() return require(module):GetControls() end)
			if ok and found then
				controlModule = found
			else
				controlsRetryAt = os.clock() + 2
			end
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
-- The drive stick, on a touch screen (built with the HUD, below): how far
-- it's pushed, -1..1 each way (screen up is negative Y).
local STICK_DEAD = 0.15
local stickValue = Vector2.zero
-- Also says where the input came from: "keys", "touch", "controls" or "none".
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
	if stickValue.Magnitude > STICK_DEAD then
		return math.clamp(-stickValue.Y, -1, 1), math.clamp(stickValue.X, -1, 1), "touch"
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
		-- (With the surface it met, so ground it can walk up doesn't stop it.)
		Sweep = function(from: CFrame, size: Vector3, direction: Vector3): (number?, string?, Vector3?, Vector3?)
			local ok, hit = pcall(workspace.Blockcast, workspace, from, size, direction, d.Params)
			if ok and hit then
				d.Hit = hit.Instance
				return hit.Distance, hit.Instance.Name, hit.Normal, hit.Position
			end
			return nil, nil, nil, nil
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
		-- (A few ms of slack: four frames at 60 a second can add up to a hair
		-- under SEND_EVERY.)
		if moving and now - d.SentAt < SEND_EVERY - 0.005 then
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

-- How long it's been moving with no answer from the server (counted from
-- the start of this stretch of moving: standing still, nothing is sent, so
-- nothing comes back).
local function unanswered(d: Driving, now: number): number
	return now - math.max(d.HeardAt, d.MovingSince)
end

-- Moving, and the server hasn't answered for a while.
local function deaf(d: Driving, now: number): boolean
	return d.MovedAt ~= nil and now - d.MovedAt < DEAF_AFTER and unanswered(d, now) > DEAF_AFTER
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

-- On screen, only HOP OUT (a tap gets you out on any screen), where PLAY
-- sits on a phone (it's hidden while you pilot: LobbyUI), and on a touch
-- screen the drive stick. No speed card: it was in the way, and the mech
-- shows how fast it's going.
local gui = UiKit.gui("DriveHud", 7) -- (over the lobby HUD)
gui.Enabled = false
local hopOutButton = IronUi.new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -MobileLayout.Drive.Bottom),
	Size = UDim2.fromOffset(MobileLayout.Drive.W, MobileLayout.Drive.H),
	BackgroundColor3 = Color3.fromRGB(242, 182, 36),
	Text = "HOP OUT",
	TextSize = 15,
	TextColor3 = Color3.fromRGB(10, 12, 20),
	Font = IronUi.Bold,
	AutoButtonColor = true,
}, gui)
UiKit.round(hopOutButton, 8)

-- The drive stick: bottom left, where your thumb already is
-- (MobileLayout.Stick). Driving on a phone used to go only through Roblox's
-- thumbstick, which a scene can switch off and which loads late. Touch it and
-- drag: up drives forward, down backs up, sideways turns. Built the first
-- time you pilot on a touch screen.
local stick: { Base: any, Knob: any, Touch: any }? = nil
local function releaseStick()
	stickValue = Vector2.zero
	if stick then
		stick.Touch = nil
		stick.Knob.Position = UDim2.fromScale(0.5, 0.5)
	end
end
local function pushStick(input)
	local s = stick
	if not s then
		return
	end
	local reach = MobileLayout.Stick.Size / 2
	local centre = s.Base.AbsolutePosition + s.Base.AbsoluteSize / 2
	local offset = Vector2.new(input.Position.X, input.Position.Y) - centre
	if offset.Magnitude > reach then
		offset = offset.Unit * reach
	end
	stickValue = offset / reach
	s.Knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
end
local function buildStick()
	if stick or not UserInputService.TouchEnabled then
		return
	end
	local layout = MobileLayout.Stick
	-- (A button, so a touch on it is the stick's: not the camera's, nor
	-- Roblox's thumbstick's.)
	local base = IronUi.new("TextButton", {
		Name = "DriveStick",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, layout.Left, 1, -layout.Bottom),
		Size = UDim2.fromOffset(layout.Size, layout.Size),
		BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
	}, gui)
	UiKit.round(base, layout.Size / 2)
	IronUi.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, -- (the ring, not the button's text)
		Color = Color3.fromRGB(242, 182, 36),
		Transparency = 0.35,
		Thickness = 2,
	}, base)
	local knob = IronUi.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(layout.Knob, layout.Knob),
		BackgroundColor3 = Color3.fromRGB(242, 182, 36),
		BackgroundTransparency = 0.1,
		Active = false,
	}, base)
	UiKit.round(knob, layout.Knob / 2)
	stick = { Base = base, Knob = knob, Touch = nil }
	base.InputBegan:Connect(function(input)
		local s = stick
		if s and s.Touch == nil and input.UserInputType == Enum.UserInputType.Touch then
			s.Touch = input
			pushStick(input)
		end
	end)
end
UserInputService.InputChanged:Connect(function(input)
	if stick and input == stick.Touch then
		pushStick(input)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if stick and input == stick.Touch then
		releaseStick()
	end
end)

-- (With a keyboard, the button names the key too.)
local function hopOutText(): string
	if UserInputService.KeyboardEnabled then
		return "HOP OUT  ·  SPACE"
	end
	return "HOP OUT"
end

local function finish()
	local d = driving
	driving = nil
	gui.Enabled = false
	releaseStick()
	if not d then
		return
	end
	for _, connection in d.Connections do
		connection:Disconnect()
	end
	if d.Humanoid and d.AutoJump ~= nil then
		pcall(function()
			d.Humanoid.AutoJumpEnabled = d.AutoJump
		end)
	end
	-- (Not over the combat camera's zoom.)
	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMinZoomDistance = d.Zoom[1]
		player.CameraMaxZoomDistance = d.Zoom[2]
	end
end

-- A menu over the screen hides HOP OUT (and the stick), nothing more: it never
-- takes your controls or the way out. (It used to do both. StreakRewards was
-- on this list, and its screen is always on, only its button hidden, so in
-- the lobby every mech sat still and nobody could get out.) Track instances,
-- so closing one of several overlays does not bring the button back.
local blockingScreens = {
	Dashboard = true,
	Shop = true,
	Season = true,
	AugmentTree = true,
	SurgeArray = true,
	Social = true,
	ProbeExchange = true,
	WelcomeBundle = true,
	Intro = true,
	Tutorial = true,
	MarketBoard = true,
	ChallengeChooser = true,
	Character = true,
	Combat = true,
	Mine = true,
	Party = true,
	Referral = true,
	TopPlayers = true,
	EquipmentTrade = true,
}
local openScreens, screenConnections = {}, {}
local function menuOpen(): boolean
	return next(openScreens) ~= nil or GuiService.MenuIsOpen
end
local function refreshHud()
	gui.Enabled = driving ~= nil and not blocked() and not menuOpen()
	if not gui.Enabled and stick and stick.Touch then
		releaseStick()
	end
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
		MovingSince = 0,
		Reported = false,
		ToldDeaf = false,
		PushedFor = 0,
		ThroughUntil = 0,
		Hinted = false,
		Hit = nil,
		Shoving = nil,
		ShovedAt = 0,
		Humanoid = nil,
		AutoJump = nil,
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
	hopOutButton.Text = hopOutText()
	buildStick()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.Sit = true -- (the pose)
		end)
		-- No auto-jump in the cockpit. On a phone it can jump you at the
		-- mech's own bodywork as you push the stick, and a jump is the way
		-- out (or, at least, stands you up out of the pose).
		d.Humanoid = humanoid
		pcall(function()
			d.AutoJump = humanoid.AutoJumpEnabled
			humanoid.AutoJumpEnabled = false
		end)
	end
	refreshHud()
end

-- The server not hearing you is worth knowing (others can't see you move):
-- said once a ride.
local function hud(d: Driving, now: number)
	if deaf(d, now) and not d.ToldDeaf then
		d.ToldDeaf = true
		UiKit.toast("The server isn't answering: others can't see you move.")
	end
end

-- The rock a part belongs to, if it's one (Server.OutpostServer's tag).
local function rockOf(part: Instance?): Model?
	local at = part
	while at and at ~= workspace do
		if at:IsA("Model") and CollectionService:HasTag(at, "OutpostNode") then
			return at
		end
		at = at.Parent
	end
	return nil
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
	local throttle, steer, source = pilotInput()
	local m = d.Mech
	local before = m.Yaw
	local speed, yaw = Rules.drive(d.Spec, m.Speed, m.Yaw, throttle, steer, dt)
	m.Through = now < d.ThroughUntil
	d.Hit = nil
	local blockedBy = MechPilot.move(m, d.World, speed * dt, yaw, dt)
	m.Speed = if blockedBy then 0 else speed
	d.Turn = if dt > 0 then (m.Yaw - before) / dt else 0
	-- Driving into a rock: shoving it, which mines it (Client.OutpostScene).
	local rock = if blockedBy and throttle >= WalkMine.Push then rockOf(d.Hit) else nil
	if rock then
		d.Shoving, d.ShovedAt = rock, now
	end
	-- Pushing into something a moment: then through it, for a moment. (Not
	-- a rock it's mining: it stays against that till it breaks.)
	if blockedBy and math.abs(throttle) >= 0.5 and not (rock and d.Spec.Mine) then
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
		if not d.MovedAt or now - d.MovedAt > SEND_EVERY * 2 then
			d.MovingSince = now
		end
		d.MovedAt = now
	end
	send(d)
	if deaf(d, now) and unanswered(d, now) > DEAF_AFTER * 2 then
		report(d, source)
	end
	hud(d, now)
	refreshHud()
end

function VehicleDrive.isDriving(): boolean
	return driving ~= nil
end

-- The rock you're driving it into, while you are (Shared.WalkMine).
function VehicleDrive.shoving(): Model?
	local d = driving
	if d and d.Shoving and d.Shoving.Parent and os.clock() - d.ShovedAt <= WalkMine.Shove then
		return d.Shoving
	end
	return nil
end

-- Out: Space, jump (the phone's button too) or HOP OUT. Whenever you're a
-- pilot, whatever else is on the screen, even before driving starts.
local leftAt = -math.huge
function VehicleDrive.hopOut(): boolean
	if not MechPilot.of(player) or UserInputService:GetFocusedTextBox() then
		return false
	end
	local now = os.clock()
	local leave = remote("MechExit")
	if not leave or now - leftAt < 0.3 then
		return false
	end
	leftAt = now
	leave:FireServer()
	return true
end
UserInputService.JumpRequest:Connect(VehicleDrive.hopOut)
hopOutButton.Activated:Connect(VehicleDrive.hopOut)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		VehicleDrive.hopOut()
	end
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
