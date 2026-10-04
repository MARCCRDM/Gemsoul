-- Driving the Outpost's machines. While you sit in one, your client owns its
-- physics and steers it every frame through the chassis constraints (Drive:
-- horizontal velocity, Steer: heading), using the seat's throttle and steer
-- (WASD, arrow keys, a gamepad stick or the mobile thumbstick). Jump to get
-- out. A small card shows the machine, its speed and the controls, and the
-- camera pulls back to fit the big ones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

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
}
local driving: Driving? = nil

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
local unit = IronUi.text(card, "KM/H", 10, P.Dim, IronUi.Bold)
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
		return "Thumbstick to drive  ·  Jump to hop out"
	end
	return "W/S drive  ·  A/D steer  ·  SPACE to hop out"
end

local function finish()
	local d = driving
	driving = nil
	gui.Enabled = false
	if not d then
		return
	end
	-- Leave it standing still (the server takes it back from here).
	pcall(function()
		d.Drive.PlaneVelocity = Vector2.zero
	end)
	player.CameraMinZoomDistance = d.Zoom[1]
	player.CameraMaxZoomDistance = d.Zoom[2]
end

local function begin(seat: VehicleSeat, humanoid: Humanoid)
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
	}
	-- Pull the camera back to fit the machine.
	local fit = math.max(14, chassis.Size.Z * 1.15)
	player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, fit * 2)
	player.CameraMinZoomDistance = fit
	title.Text = string.upper(spec.Name)
	blurb.Text = spec.Blurb
	controls.Text = controlText()
	gui.Enabled = true
end

-- One frame of driving.
function VehicleDrive.step(dt: number)
	local d = driving
	if not d then
		return
	end
	if not d.Seat.Parent or d.Seat.Occupant ~= d.Humanoid then
		finish()
		return
	end
	local speed, yaw = Rules.drive(d.Spec, d.Speed, d.Yaw, d.Seat.ThrottleFloat, d.Seat.SteerFloat, dt)
	-- Don't keep shoving at full speed into a wall or a rock.
	local v = d.Chassis.AssemblyLinearVelocity
	local actual = Vector2.new(v.X, v.Z).Magnitude
	if math.abs(speed) > actual + 10 then
		speed = math.sign(speed) * (actual + 10)
	end
	d.Speed, d.Yaw = speed, yaw
	local heading = CFrame.Angles(0, yaw, 0)
	local forward = heading.LookVector
	d.Drive.PlaneVelocity = Vector2.new(forward.X * speed, forward.Z * speed)
	d.Steer.CFrame = heading
	speedLabel.Text = tostring(math.floor(math.abs(speed) + 0.5))
	fill.Size = UDim2.fromScale(math.clamp(math.abs(speed) / d.Spec.MaxSpeed, 0, 1), 1)
end

function VehicleDrive.isDriving(): boolean
	return driving ~= nil
end

local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Seated:Connect(function(seated: boolean, seat: Instance?)
		if seated and seat and seat:IsA("VehicleSeat") and seat:GetAttribute("OutpostMachine") then
			begin(seat, humanoid)
		else
			finish()
		end
	end)
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
