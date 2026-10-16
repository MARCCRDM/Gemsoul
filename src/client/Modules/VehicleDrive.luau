-- Send pilot input to the server, which owns and moves every mech. The client
-- handles controls, camera and HUD, without competing writes to constraints.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

task.spawn(function() require(script.Parent.MechAnimation) end)

local VehicleDrive = {}
local player = Players.LocalPlayer
local P = IronUi.Colors

type Driving = {
	Seat: VehicleSeat,
	Humanoid: Humanoid,
	Chassis: BasePart,
	Drive: LinearVelocity,
	Steer: AlignOrientation,
	Spec: any,
	Speed: number,
	Yaw: number,
	Zoom: { number },
	-- Watching for a mech that won't budge (see stuck below).
	Start: Vector3,
	StuckFor: number,
	Reports: number,
}
local driving: Driving? = nil
local function blocked(): boolean
	return not player:GetAttribute("Outpost")
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("ArenaDropPreparing") ~= nil
		or player:GetAttribute("ArenaDropUntil") ~= nil
		or player:GetAttribute("Expedition") ~= nil
end

-- What the pilot is asking for, -1..1 each. The seat's floats come from the
-- default controls; when they stay at 0 (the controls can be switched off or
-- slow to notice the seat), the move vector or the keys themselves stand in.
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
		-- driving heartbeat (or keyboard fallback) while it initializes.
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
-- Also says where the input came from: "seat", "controls", "keys" or "none".
local function pilotInput(seat: VehicleSeat): (number, number, string)
	if UserInputService:GetFocusedTextBox() then return 0, 0, "none" end
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	local source = "seat"
	if throttle == 0 and steer == 0 then
		source = "none"
		local K = Enum.KeyCode
		if held(K.W, K.Up, K.S, K.Down, K.A, K.Left, K.D, K.Right) then
			throttle = (if held(K.W, K.Up) then 1 else 0) - (if held(K.S, K.Down) then 1 else 0)
			steer = (if held(K.D, K.Right) then 1 else 0) - (if held(K.A, K.Left) then 1 else 0)
			if throttle ~= 0 or steer ~= 0 then
				source = "keys"
			end
		else
			local move = moveVector()
			if move and move.Magnitude > 0.05 then
				throttle, steer, source = -move.Z, move.X, "controls"
			end
		end
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1), source
end

-- The same input goes to the server, which drives the machine itself while
-- it still holds the physics (see Server OutpostVehicles).
local function remote(name: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild(name) :: RemoteEvent?
end
local sentThrottle, sentSteer, sentAt = 0, 0, 0
local function tellServer(throttle: number, steer: number, force: boolean?)
	local now = os.clock()
	local changed = math.abs(throttle - sentThrottle) >= 0.05 or math.abs(steer - sentSteer) >= 0.05
	local stale = (throttle ~= 0 or steer ~= 0) and now - sentAt >= 0.5
	if not changed and not stale and not force then
		return
	end
	-- A sweeping stick changes every frame: at most 10 a second, but letting go
	-- goes out at once.
	if not force and not stale and now - sentAt < 0.1
		and (sentThrottle ~= 0 or sentSteer ~= 0) and (throttle ~= 0 or steer ~= 0) then
		return
	end
	local input = remote("MechInput")
	if input then
		input:FireServer(throttle, steer)
		sentThrottle, sentSteer, sentAt = throttle, steer, now
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
	tellServer(0, 0, true)
	-- A delayed Seated(false) must not overwrite the combat camera's zoom.
	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMinZoomDistance = d.Zoom[1]
		player.CameraMaxZoomDistance = d.Zoom[2]
	end
end

-- Menus own the screen even while the character remains seated in a mech.
-- Track instances, so closing one of several overlays does not reveal the HUD.
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
	local hidden = menuOpen()
	gui.Enabled = driving ~= nil and driving.Seat.Parent ~= nil
		and driving.Seat.Occupant == driving.Humanoid and not blocked() and not hidden
	if driving and hidden then
		driving.Speed = 0
		tellServer(0, 0)
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

local function begin(seat: VehicleSeat, humanoid: Humanoid)
	if blocked() then finish(); return end
	if driving and driving.Seat == seat and driving.Humanoid == humanoid then return end
	-- Seated and Occupant can arrive in separate replication updates.
	if not seat.Parent or seat.Occupant ~= humanoid then return end
	local kind = seat:GetAttribute("OutpostMachine")
	local spec = Rules.Machines[kind]
	local chassis = seat.Parent and seat.Parent:FindFirstChild("Chassis") :: BasePart?
	local drive = chassis and chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis and chassis:FindFirstChild("Steer") :: AlignOrientation?
	if not spec or not chassis or not drive or not steer then
		return
	end
	local _, yaw = chassis.CFrame:ToOrientation()
	driving = {
		Seat = seat,
		Humanoid = humanoid,
		Chassis = chassis,
		Drive = drive,
		Steer = steer,
		Spec = spec,
		Speed = 0,
		Yaw = yaw,
		Zoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance },
		Start = chassis.Position,
		StuckFor = 0,
		Reports = 0,
	}
	-- Tell the server this client is piloting (it watches for one that isn't).
	tellServer(0, 0, true)
	-- Pull the camera back to fit the machine.
	local fit = seat.Parent:GetAttribute("CameraFit") or math.max(14, chassis.Size.Z * 1.15)
	player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, fit * 2)
	player.CameraMinZoomDistance = fit
	title.Text = string.upper(spec.Name)
	blurb.Text = spec.Blurb
	controls.Text = controlText()
	refreshHud()
end

local function resumeSeat()
	if driving or blocked() then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat:GetAttribute("OutpostMachine") then
		begin(seat, humanoid)
	end
end

-- A mech that won't budge: held input for 2 s and it never left the spot it
-- was boarded at. Say what this client sees (Output and Feedback > Reports,
-- via the server) and ask the server to take over (Server OutpostVehicles).
local function anchoredIn(part: BasePart): string
	local found = {}
	local ok, parts = pcall(part.GetConnectedParts, part, true)
	for _, connected in if ok then parts else {} do
		if connected.Anchored then
			table.insert(found, connected:GetFullName())
			if #found >= 3 then
				break
			end
		end
	end
	return if #found > 0 then table.concat(found, ", ") else "none"
end
local function reportStuck(d: Driving, throttle: number, steer: number, source: string)
	local c = d.Chassis
	local v, pv = c.AssemblyLinearVelocity, d.Drive.PlaneVelocity
	local root = c.AssemblyRootPart
	local text = string.format(
		"input %.2f/%.2f from %s (seat %.2f/%.2f), speed %.1f, drive (%.1f, %.1f) on=%s, steer on=%s, "
			.. "receiveAge %.2f, root %s, mass %.0f, anchored: %s",
		throttle,
		steer,
		source,
		d.Seat.ThrottleFloat,
		d.Seat.SteerFloat,
		Vector2.new(v.X, v.Z).Magnitude,
		pv.X,
		pv.Y,
		tostring(d.Drive.Enabled),
		tostring(d.Steer.Enabled),
		c.ReceiveAge,
		if root then root.Name else "?",
		c.AssemblyMass,
		anchoredIn(c)
	)
	warn("[Mech] Won't move (client): " .. text)
	local report = remote("MechReport")
	if report then
		report:FireServer(text)
	end
	UiKit.toast("Your mech seems stuck. Checking its movement and sending a report.")
end
local function watchStuck(d: Driving, throttle: number, steer: number, source: string, dt: number)
	local c = d.Chassis
	local v = c.AssemblyLinearVelocity
	local moving = Vector2.new(v.X, v.Z).Magnitude >= 1.5 or math.abs(c.AssemblyAngularVelocity.Y) >= 0.2
	local pushing = math.abs(throttle) >= 0.5 or math.abs(steer) >= 0.5
	local home = (c.Position - d.Start).Magnitude < 4
	if not (pushing and home and not moving) then
		d.StuckFor = 0
		return
	end
	d.StuckFor += dt
	if d.StuckFor >= 2 and d.Reports < 2 then
		-- (Give the server's takeover a few seconds before asking again.)
		d.StuckFor, d.Reports = -3, d.Reports + 1
		reportStuck(d, throttle, steer, source)
	end
end

-- One frame of driving.
function VehicleDrive.step(dt: number)
	-- Recover missed boarding events and delayed chassis/constraint replication.
	-- Only the local character is inspected, with no world or UI scans.
	if not driving then resumeSeat() end
	local d = driving
	if not d then
		return
	end
	if blocked() or not d.Seat.Parent or d.Seat.Occupant ~= d.Humanoid then
		finish()
		return
	end
	if menuOpen() then
		refreshHud()
		return
	end
	local throttle, steer, source = pilotInput(d.Seat)
	tellServer(throttle, steer)
	watchStuck(d, throttle, steer, source, dt)
	local v = d.Chassis.AssemblyLinearVelocity
	local actual = Vector2.new(v.X, v.Z).Magnitude
	d.Speed = actual
	speedLabel.Text = tostring(math.floor(actual + 0.5))
	fill.Size = UDim2.fromScale(math.clamp(actual / d.Spec.MaxSpeed, 0, 1), 1)
end

function VehicleDrive.isDriving(): boolean
	return driving ~= nil
end

local function refreshSession()
	if blocked() then
		finish()
	else
		resumeSeat()
	end
end
for _, attribute in { "Outpost", "CombatSession", "ArenaDropPreparing", "ArenaDropUntil", "Expedition" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshSession)
end

local playerGui = player:WaitForChild("PlayerGui")
playerGui.ChildAdded:Connect(watchScreen)
playerGui.ChildRemoved:Connect(unwatchScreen)
for _, screen in playerGui:GetChildren() do watchScreen(screen) end
GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(refreshHud)

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Seated:Connect(function(seated: boolean, seat: Instance?)
		if character ~= player.Character then return end
		if seated and seat and seat:IsA("VehicleSeat") and seat:GetAttribute("OutpostMachine") then
			begin(seat, humanoid)
		else
			finish()
		end
	end)
	resumeSeat()
end

if player.Character then
	task.spawn(watch, player.Character)
end
player.CharacterAdded:Connect(function(character)
	finish()
	watch(character)
end)
RunService.Heartbeat:Connect(VehicleDrive.step)

return VehicleDrive
