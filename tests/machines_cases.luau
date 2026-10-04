-- The Outpost's machines: how each is put together (one sliding chassis,
-- welded massless bodywork, a seat, the Drive/Steer constraints, the Mole's
-- spinning drill) and the driving maths (Shared.Outpost.drive). Uses lune's
-- roblox library. Run by tests/run_machines.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local function load(path, env)
	local source = fs.readFile(ROOT .. "/" .. path)
	return luau.load(source, { debugName = path, environment = setmetatable(env or {}, { __index = _G }) })()
end

local Rules = load("src/shared/Outpost.luau", { CFrame = R.CFrame, Color3 = R.Color3 })
local Machines = load("src/server/World/OutpostMachines.luau", {
	Instance = R.Instance,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	Enum = R.Enum,
	PhysicalProperties = R.PhysicalProperties,
})

-- Driving --------------------------------------------------------------------------------
local hauler, mole, skipper = Rules.Machines.Hauler, Rules.Machines.Mole, Rules.Machines.Skipper
local speed, yaw = 0, 0
for _ = 1, 600 do
	speed, yaw = Rules.drive(hauler, speed, yaw, 1, 0, 1 / 60)
end
check(math.abs(speed - hauler.MaxSpeed) < 1e-6 and yaw == 0, "Full throttle didn't reach top speed straight ahead")
local before = speed
speed = Rules.drive(hauler, speed, yaw, 0, 0, 0.5)
check(speed < before and speed > 0, "Letting go didn't slow it down")
local s1 = Rules.drive(hauler, 20, 0, 0, 0, 0.1)
local s2 = Rules.drive(hauler, 0, 0, 1, 0, 0.1)
check(math.abs((20 - s1) - 2 * s2) < 1e-6, "Braking isn't twice as strong as accelerating")
speed = 0
for _ = 1, 600 do
	speed = Rules.drive(hauler, speed, 0, -1, 0, 1 / 60)
end
check(math.abs(speed + hauler.MaxSpeed * Rules.ReverseShare) < 1e-6, "Reverse isn't limited")
local _, still = Rules.drive(hauler, 0, 0, 0, 1, 1)
check(still == 0, "A wheeled machine turned on the spot")
local _, spun = Rules.drive(mole, 0, 0, 0, 1, 1)
check(spun < 0, "A tracked machine couldn't turn on the spot")
local _, right = Rules.drive(skipper, 30, 0, 1, 1, 0.1)
local _, backRight = Rules.drive(skipper, -20, 0, -1, 1, 0.1)
check(right < 0 and backRight > 0, "Steering doesn't flip when backing up")
local _, slow = Rules.drive(skipper, 2, 0, 0, 1, 0.1)
local _, fast = Rules.drive(skipper, 30, 0, 0, 1, 0.1)
check(math.abs(slow) < math.abs(fast), "Wheels steer as hard at a crawl as at speed")
check(skipper.MaxSpeed > hauler.MaxSpeed and hauler.MaxSpeed > Rules.Machines.Digger.MaxSpeed, "Machine speeds out of order")
for _, kind in Rules.MachineOrder do
	check(Rules.Machines[kind] ~= nil, "Machine order lists a missing machine")
end

-- Building -------------------------------------------------------------------------------
local at = R.CFrame.new(100, 0, 200) * R.CFrame.Angles(0, math.rad(30), 0)
for _, kind in Rules.MachineOrder do
	local model = Machines.build(kind, at)
	local chassis = model:FindFirstChild("Chassis")
	check(chassis and model.PrimaryPart == chassis, kind .. " has no chassis")
	check(chassis.CanCollide and chassis.Transparency == 1 and not chassis.Anchored, kind .. "'s chassis can't slide")
	local bottom = chassis.CFrame.Position.Y - chassis.Size.Y / 2
	check(bottom > 0 and bottom < 0.5, kind .. " isn't standing on the ground")
	local seat = model:FindFirstChild("Seat")
	check(seat and seat.ClassName == "VehicleSeat" and seat:GetAttribute("OutpostMachine") == kind, kind .. " has no seat")
	check(not seat.CanTouch and seat.MaxSpeed == 0 and seat.Torque == 0, kind .. "'s seat would take over the driving")
	local drive, steer = chassis:FindFirstChild("Drive"), chassis:FindFirstChild("Steer")
	check(drive and drive.ClassName == "LinearVelocity" and drive.VelocityConstraintMode == R.Enum.VelocityConstraintMode.Plane, kind .. " has no planar Drive")
	check(drive.PrimaryTangentAxis == R.Vector3.new(1, 0, 0) and drive.SecondaryTangentAxis == R.Vector3.new(0, 0, 1), kind .. "'s Drive isn't horizontal")
	check(steer and steer.ClassName == "AlignOrientation" and steer.Mode == R.Enum.OrientationAlignmentMode.OneAttachment, kind .. " has no Steer")
	local _, wantYaw = at:ToOrientation()
	local _, gotYaw = steer.CFrame:ToOrientation()
	check(math.abs(wantYaw - gotYaw) < 1e-4, kind .. " would swing round when it spawns")
	-- Every other part is welded on, massless and non-colliding (the drill to its hub).
	local hub = model:FindFirstChild("DrillHub")
	for _, d in model:GetDescendants() do
		if d.ClassName == "WeldConstraint" then
			check(d.Part0 == chassis or d.Part0 == hub, kind .. " has a weld to the wrong part")
		end
	end
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= chassis and d ~= hub then
			parts += 1
			local weld = d:FindFirstChildOfClass("WeldConstraint")
			check(weld ~= nil and weld.Part1 == d, kind .. ": " .. d.Name .. " isn't welded on")
			check(d.Massless and not d.Anchored, kind .. ": " .. d.Name .. " has weight or is anchored")
			check(not d.CanCollide or d == seat, kind .. ": " .. d.Name .. " collides")
		end
	end
	check(parts > 20, kind .. " is too plain (" .. parts .. " parts)")
	if kind == "Mole" then
		local motor = model:FindFirstChild("DrillMotor", true)
		check(hub and not hub.Massless and motor and motor.ActuatorType == R.Enum.ActuatorType.Motor, "The Mole's drill can't spin")
		check(motor.Attachment0.Parent == chassis and motor.Attachment1.Parent == hub, "The drill isn't hinged to the chassis")
	else
		check(hub == nil, kind .. " has a drill")
	end
end

print("PASS: " .. checks .. " machine checks (driving maths, chassis, seats, constraints, welds, the spinning drill)")
