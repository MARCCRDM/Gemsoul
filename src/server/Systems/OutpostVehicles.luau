-- The Outpost's machines: parks them in their Motor Pool bays, seats a
-- driver from the Drive prompt, hands the driver's client the physics (it
-- steers through the chassis constraints, see Client VehicleDrive), and sends
-- abandoned machines home. Driving only: they don't mine or carry anything.
-- Until the hand-over takes, the server drives the machine itself from the
-- pilot's input (MechInput), so a seated pilot is never stuck.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local Remotes = require(script.Parent.Remotes)
local OutpostMachines = require(script.Parent.Parent.World.OutpostMachines)

local OutpostVehicles = {}

-- Seconds before a held input that stops arriving counts as let go.
local INPUT_TIMEOUT = 1.5
-- Seconds between tries to hand a machine's physics to its driver.
local CLAIM_RETRY = 2

type Machine = {
	Kind: string,
	Bay: CFrame,
	Model: Model,
	Seat: VehicleSeat,
	LastUsed: number,
	-- The pilot's latest input, and the server's own drive state.
	Throttle: number,
	Steer: number,
	InputAt: number,
	Speed: number,
	Yaw: number,
	ServerDriving: boolean,
	NextClaim: number,
	Warned: boolean,
}
local machines: { Machine } = {}
local bySeat: { [Instance]: Machine } = {}
local folder: Instance? = nil

local function yawOf(part: BasePart): number
	local _, yaw = part.CFrame:ToOrientation()
	return yaw
end

local function stop(machine: Machine)
	local chassis = machine.Model.PrimaryPart :: BasePart
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
	if drive then
		drive.PlaneVelocity = Vector2.zero
	end
	if steer then
		steer.CFrame = CFrame.Angles(0, yawOf(chassis), 0)
	end
end

-- Who simulates it: the driver (so it handles with no lag), else the server.
local function owner(machine: Machine, player: Player?)
	local chassis = machine.Model.PrimaryPart
	if not chassis then
		return
	end
	local ok, problem = pcall(chassis.SetNetworkOwner, chassis, player)
	if not ok and player and not machine.Warned then
		machine.Warned = true
		warn(
			string.format(
				"[Mech] %s: couldn't hand its physics to %s, the server drives it instead: %s",
				machine.Kind,
				player.Name,
				tostring(problem)
			)
		)
	end
end

local function driverOwns(machine: Machine, driver: Player): boolean
	local chassis = machine.Model.PrimaryPart
	if not chassis then
		return false
	end
	local ok, current = pcall(chassis.GetNetworkOwner, chassis)
	return ok and current == driver
end

-- Back to its bay, parked straight.
local function reset(machine: Machine)
	local chassis = machine.Model.PrimaryPart :: BasePart
	chassis.Anchored = true
	local size = chassis.Size
	machine.Model:PivotTo(machine.Bay * CFrame.new(0, size.Y / 2 + 0.2, 0))
	stop(machine)
	local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
	if steer then
		local _, yaw = machine.Bay:ToOrientation()
		steer.CFrame = CFrame.Angles(0, yaw, 0)
	end
	chassis.Anchored = false
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
	machine.LastUsed = os.clock()
end

local function driverOf(machine: Machine): Player?
	local humanoid = machine.Seat.Occupant
	return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
end

-- Outside the Outpost, or busy elsewhere: no driving.
local function busy(player: Player): boolean
	return not player:GetAttribute("Outpost")
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("ArenaDropPreparing") ~= nil
		or player:GetAttribute("ArenaDropUntil") ~= nil
		or player:GetAttribute("Expedition") ~= nil
end

local function spawnMachine(kind: string, bay: CFrame)
	local model = OutpostMachines.build(kind, bay)
	model.Parent = folder
	CollectionService:AddTag(model, "OutpostMech")
	local seat = model:FindFirstChild("Seat") :: VehicleSeat
	local machine: Machine = {
		Kind = kind,
		Bay = bay,
		Model = model,
		Seat = seat,
		LastUsed = os.clock(),
		Throttle = 0,
		Steer = 0,
		InputAt = 0,
		Speed = 0,
		Yaw = 0,
		ServerDriving = false,
		NextClaim = 0,
		Warned = false,
	}
	table.insert(machines, machine)

	local spec = Rules.Machines[kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Pilot"
	prompt.ObjectText = spec.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 18 -- reachable from the ground below the cockpit
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Drive")
	prompt.Parent = seat
	bySeat[seat] = machine

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		OutpostVehicles.seated(machine)
	end)
	return machine
end

-- A pilot got in or out: fresh input, and the physics to whoever drives.
function OutpostVehicles.seated(machine: Machine)
	local driver = driverOf(machine)
	local prompt = machine.Seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = driver == nil
	end
	machine.Throttle, machine.Steer, machine.InputAt, machine.Speed = 0, 0, 0, 0
	machine.ServerDriving, machine.Warned = false, false
	-- The seat weld can still be settling: try again shortly if it didn't take.
	machine.NextClaim = os.clock() + 0.5
	if not driver then
		stop(machine)
	end
	owner(machine, driver)
	machine.LastUsed = os.clock()
end

-- The Drive prompt: into the driver's seat, if it's free and you're on foot.
function OutpostVehicles.sit(player: Player, seat: Instance): boolean
	local machine = bySeat[seat]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not machine or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or machine.Seat.Occupant then
		return false
	end
	if busy(player) then
		return false
	end
	machine.Seat:Sit(humanoid)
	return true
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- MechInput: only the pilot of a machine steers it, within -1..1.
function OutpostVehicles.input(player: Player, throttle: any, steer: any, now: number?): boolean
	if not finite(throttle) or not finite(steer) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local machine = seat and bySeat[seat]
	if not machine or machine.Seat.Occupant ~= humanoid then
		return false
	end
	machine.Throttle, machine.Steer = math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
	machine.InputAt = now or os.clock()
	return true
end

-- One frame: drive every piloted machine whose physics the server still holds.
function OutpostVehicles.step(dt: number, now: number?)
	local clock = now or os.clock()
	for _, machine in machines do
		local driver = driverOf(machine)
		local chassis = machine.Model.PrimaryPart
		if not driver or not chassis or chassis.Anchored then
			machine.ServerDriving = false
			continue
		end
		if driverOwns(machine, driver) then
			-- The pilot's client drives it (Client VehicleDrive).
			machine.ServerDriving = false
			continue
		end
		if clock >= machine.NextClaim then
			machine.NextClaim = clock + CLAIM_RETRY
			owner(machine, driver)
		end
		local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
		local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
		local spec = Rules.Machines[machine.Kind]
		if not drive or not steer or not spec then
			continue
		end
		local v = chassis.AssemblyLinearVelocity
		if not machine.ServerDriving then
			-- Pick up where the client left it, not where it was boarded.
			machine.ServerDriving = true
			machine.Yaw = yawOf(chassis)
			machine.Speed = v:Dot(CFrame.Angles(0, machine.Yaw, 0).LookVector)
		end
		local fresh = clock - machine.InputAt <= INPUT_TIMEOUT
		local throttle = if fresh and not busy(driver) then machine.Throttle else 0
		local turn = if fresh and not busy(driver) then machine.Steer else 0
		local speed, yaw = Rules.drive(spec, machine.Speed, machine.Yaw, throttle, turn, dt)
		-- Don't keep shoving at full speed into a wall or a rock.
		local actual = Vector2.new(v.X, v.Z).Magnitude
		if math.abs(speed) > actual + 10 then
			speed = math.sign(speed) * (actual + 10)
		end
		machine.Speed, machine.Yaw = speed, yaw
		local heading = CFrame.Angles(0, yaw, 0)
		local forward = heading.LookVector
		drive.PlaneVelocity = Vector2.new(forward.X * speed, forward.Z * speed)
		steer.CFrame = heading
	end
end

function OutpostVehicles.start(site)
	local holder = Instance.new("Folder")
	holder.Name = "Machines"
	holder.Parent = site.Model
	folder = holder
	for _, bay in site.Parking do
		spawnMachine(bay.Kind, bay.CFrame)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("PromptKind") == "Drive" and prompt.Parent then
			OutpostVehicles.sit(player, prompt.Parent)
		end
	end)
	Remotes.MechInput.OnServerEvent:Connect(function(player, throttle, steer)
		OutpostVehicles.input(player, throttle, steer)
	end)
	RunService.Heartbeat:Connect(function(dt)
		OutpostVehicles.step(dt)
	end)
	-- Abandoned machines drive themselves home; anything that falls out of the
	-- world comes straight back.
	task.spawn(function()
		while true do
			task.wait(5)
			OutpostVehicles.tidy(os.clock())
		end
	end)
end

function OutpostVehicles.tidy(now: number)
	for _, machine in machines do
		local chassis = machine.Model.PrimaryPart
		if not chassis then
			continue
		end
		if driverOf(machine) then
			machine.LastUsed = now
			continue
		end
		local fell = chassis.CFrame.Position.Y < Rules.Location.Position.Y - 40
		local away = (chassis.CFrame.Position - machine.Bay.Position).Magnitude > 12
		if fell or (away and now - machine.LastUsed > Rules.MachineResetSeconds) then
			reset(machine)
		end
	end
end

-- For tests.
OutpostVehicles._machines = machines
OutpostVehicles._reset = reset
OutpostVehicles._spawn = spawnMachine
OutpostVehicles._bySeat = bySeat

return OutpostVehicles
