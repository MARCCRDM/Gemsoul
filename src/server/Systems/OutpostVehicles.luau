-- The Outpost's machines: parks them in their Motor Pool bays, seats a
-- driver from the Drive prompt, hands the driver's client the physics (it
-- steers through the chassis constraints, see Client VehicleDrive), and sends
-- abandoned machines home. Driving only: they don't mine or carry anything.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local OutpostMachines = require(script.Parent.Parent.World.OutpostMachines)

local OutpostVehicles = {}

type Machine = { Kind: string, Bay: CFrame, Model: Model, Seat: VehicleSeat, LastUsed: number }
local machines: { Machine } = {}
local bySeat: { [Instance]: Machine } = {}
local folder: Instance? = nil

local function stop(machine: Machine)
	local chassis = machine.Model.PrimaryPart :: BasePart
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
	if drive then
		drive.PlaneVelocity = Vector2.zero
	end
	if steer then
		local _, yaw = chassis.CFrame:ToOrientation()
		steer.CFrame = CFrame.Angles(0, yaw, 0)
	end
end

-- Who simulates it: the driver (so it handles with no lag), else the server.
local function owner(machine: Machine, player: Player?)
	for _, part in { machine.Model.PrimaryPart, machine.Model:FindFirstChild("DrillHub") } do
		if part and part:IsA("BasePart") then
			pcall(part.SetNetworkOwner, part, player)
		end
	end
	local motor = machine.Model:FindFirstChild("DrillMotor", true) :: HingeConstraint?
	if motor then
		motor.AngularVelocity = if player then 8 else 1.5
	end
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
	machine.LastUsed = os.clock()
end

local function driverOf(machine: Machine): Player?
	local humanoid = machine.Seat.Occupant
	return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function spawnMachine(kind: string, bay: CFrame)
	local model = OutpostMachines.build(kind, bay)
	model.Parent = folder
	local seat = model:FindFirstChild("Seat") :: VehicleSeat
	local machine = { Kind = kind, Bay = bay, Model = model, Seat = seat, LastUsed = os.clock() }
	table.insert(machines, machine)

	local spec = Rules.Machines[kind]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = spec.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = if kind == "Skipper" then 10 else 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Drive")
	prompt.Parent = seat
	bySeat[seat] = machine

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local driver = driverOf(machine)
		prompt.Enabled = driver == nil
		if not driver then
			stop(machine)
		end
		owner(machine, driver)
		machine.LastUsed = os.clock()
	end)
	return machine
end

-- The Drive prompt: into the driver's seat, if it's free and you're on foot.
function OutpostVehicles.sit(player: Player, seat: Instance): boolean
	local machine = bySeat[seat]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not machine or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart or machine.Seat.Occupant then
		return false
	end
	if not player:GetAttribute("Outpost") then
		return false
	end
	machine.Seat:Sit(humanoid)
	return true
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

return OutpostVehicles
