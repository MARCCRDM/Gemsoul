-- Server-owned mech physics. The pilot sends input, and one controller sets
-- velocity/heading for every occupied machine. Seat weld creation can change
-- assembly ownership, so it is checked again after boarding and while driving.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local Seating = require(ReplicatedStorage.Shared.Seating)
local Remotes = require(script.Parent.Remotes)
local OutpostMachines = require(script.Parent.Parent.World.OutpostMachines)
local SeatExit = require(script.Parent.SeatExit)

local OutpostVehicles = {}

-- Seconds before a held input that stops arriving counts as let go.
local INPUT_TIMEOUT = 1.5
-- Seconds between ownership checks after the seat weld settles.
local CLAIM_RETRY = 2
-- Seconds in the seat with no word from the pilot's client before it's logged.
local SILENT_AFTER = 5
-- Stuck reports taken from one pilot, per time in the seat.
local MAX_REPORTS = 3

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
	-- Diagnostics: when the pilot sat down, whether their client has said
	-- anything since, stuck reports taken, and the server keeping the physics.
	BoardedAt: number,
	Heard: boolean,
	SilentLogged: boolean,
	Reports: number,
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

-- Always retain manual server ownership, including the seated character.
local function owner(machine: Machine)
	local chassis = machine.Model.PrimaryPart
	if not chassis then
		return
	end
	local ok, problem = pcall(chassis.SetNetworkOwner, chassis, nil)
	if not ok and not machine.Warned then
		machine.Warned = true
		warn(
			string.format(
				"[Mech] %s: couldn't claim server physics: %s",
				machine.Kind,
				tostring(problem)
			)
		)
	end
end

local function serverOwns(machine: Machine): boolean
	local chassis = machine.Model.PrimaryPart
	if not chassis then
		return false
	end
	local ok, current = pcall(chassis.GetNetworkOwner, chassis)
	return ok and current == nil
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
	owner(machine)
	machine.LastUsed = os.clock()
end

-- (Seating, not Seat.Occupant or Humanoid.SeatPart alone: neither replicates.)
local function driverOf(machine: Machine): Player?
	local humanoid = Seating.occupant(machine.Seat)
	return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
end

-- The machine `humanoid` sits in, if any (never one someone else sits in).
local function machineOf(humanoid: Humanoid?): Machine?
	if not humanoid then
		return nil
	end
	local seat = Seating.seatOf(humanoid)
	local machine = seat and bySeat[seat]
	if machine then
		local occupant = Seating.occupant(machine.Seat)
		return if occupant == nil or occupant == humanoid then machine else nil
	end
	for _, other in machines do
		if Seating.occupant(other.Seat) == humanoid then
			return other
		end
	end
	return nil
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
		BoardedAt = 0,
		Heard = false,
		SilentLogged = false,
		Reports = 0,
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
	-- (The weld coming and going says the same, wherever Occupant stays empty.)
	for _, changed in { seat.ChildAdded, seat.ChildRemoved } do
		changed:Connect(function(child)
			if child.Name == "SeatWeld" then
				OutpostVehicles.seated(machine)
			end
		end)
	end
	return machine
end

-- A pilot got in or out: fresh input, with physics still on the server.
function OutpostVehicles.seated(machine: Machine)
	local driver = driverOf(machine)
	local prompt = machine.Seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = driver == nil
	end
	machine.Throttle, machine.Steer, machine.InputAt, machine.Speed = 0, 0, 0, 0
	machine.ServerDriving, machine.Warned = false, false
	machine.BoardedAt, machine.Heard, machine.SilentLogged = os.clock(), false, false
	machine.Reports = 0
	-- The seat weld can still be settling: try again shortly if it didn't take.
	machine.NextClaim = os.clock() + 0.5
	stop(machine)
	owner(machine)
	machine.LastUsed = os.clock()
end

-- The Drive prompt: into the driver's seat, if it's free and you're on foot.
function OutpostVehicles.sit(player: Player, seat: Instance): boolean
	local machine = bySeat[seat]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not machine
		or not humanoid
		or humanoid.Health <= 0
		or Seating.seatOf(humanoid)
		or Seating.occupant(machine.Seat)
	then
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
	local machine = machineOf(character and character:FindFirstChildOfClass("Humanoid"))
	if not machine then
		return false
	end
	machine.Throttle, machine.Steer = math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
	machine.InputAt = now or os.clock()
	machine.Heard = true
	return true
end

function OutpostVehicles.exit(player: Player): boolean
	local character = player.Character
	local machine = machineOf(character and character:FindFirstChildOfClass("Humanoid"))
	if not machine then
		return false
	end
	machine.Throttle, machine.Steer, machine.Speed = 0, 0, 0
	stop(machine)
	SeatExit.detach(character, machine.Seat)
	return true
end

-- Diagnostics -----------------------------------------------------------------------------

-- To the Output, and kept with the playtest reports (Feedback > Reports).
local function note(message: string, detail: string)
	warn(detail)
	local ok, Feedback = pcall(require, script.Parent.Feedback)
	if ok and type(Feedback) == "table" and Feedback.note then
		pcall(Feedback.note, "Server", message, detail)
	end
end

local function anchoredParts(chassis: BasePart): { BasePart }
	local found = {}
	local ok, parts = pcall(chassis.GetConnectedParts, chassis, true)
	for _, part in if ok then parts else { chassis } do
		if part.Anchored then
			table.insert(found, part)
		end
	end
	return found
end

-- How it looks from here: who runs the physics, what's anchored, the input.
local function serverView(machine: Machine, driver: Player, clock: number): string
	local chassis = machine.Model.PrimaryPart :: BasePart
	local okOwner, current = pcall(chassis.GetNetworkOwner, chassis)
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
	local v = chassis.AssemblyLinearVelocity
	local pv = if drive then drive.PlaneVelocity else Vector2.zero
	local names = {}
	for _, part in anchoredParts(chassis) do
		table.insert(names, part:GetFullName())
	end
	return string.format(
		"physics %s, server driving %s, input %.2f/%.2f (%.1f s old), speed %.1f, drive (%.1f, %.1f), anchored: %s",
		if not okOwner
			then "unknown"
			elseif current == driver then "pilot"
			elseif current then "other player"
			else "server",
		tostring(machine.ServerDriving),
		machine.Throttle,
		machine.Steer,
		clock - machine.InputAt,
		Vector2.new(v.X, v.Z).Magnitude,
		pv.X,
		pv.Y,
		if #names > 0 then table.concat(names, ", ") else "none"
	)
end

-- Free anything anchored in the mech or the pilot, and keep the physics on
-- the server for the rest of this ride.
local function recover(machine: Machine, driver: Player): string
	local chassis = machine.Model.PrimaryPart :: BasePart
	local done = {}
	for _, part in anchoredParts(chassis) do
		local ours = part:IsDescendantOf(machine.Model)
			or (driver.Character ~= nil and part:IsDescendantOf(driver.Character))
		if ours then
			part.Anchored = false
			table.insert(done, "unanchored " .. part.Name)
		end
	end
	owner(machine)
	machine.ServerDriving = false -- resume from the actual heading after repair
	table.insert(done, "server physics reclaimed")
	return if #done > 0 then table.concat(done, ", ") else "nothing left to try"
end

-- MechReport: the pilot's client says its mech won't move.
function OutpostVehicles.report(player: Player, text: any, now: number?): boolean
	if type(text) ~= "string" then
		return false
	end
	local character = player.Character
	local machine = machineOf(character and character:FindFirstChildOfClass("Humanoid"))
	if not machine or machine.Reports >= MAX_REPORTS then
		return false
	end
	machine.Reports += 1
	local clock = now or os.clock()
	local before = serverView(machine, player, clock)
	local done = recover(machine, player)
	note(
		"[Mech] " .. machine.Kind .. " won't move",
		string.format(
			"[Mech] %s won't move for %s. Client: %s. Server: %s. Done: %s.",
			machine.Kind,
			player.Name,
			string.sub(text, 1, 400),
			before,
			done
		)
	)
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
		if not machine.Heard and not machine.SilentLogged and clock - machine.BoardedAt >= SILENT_AFTER then
			machine.SilentLogged = true
			note(
				"[Mech] no word from the pilot's client",
				string.format(
					"[Mech] %s: %s has sat in it for %d s and their client hasn't started driving "
						.. "(Client VehicleDrive never ran begin). Server: %s.",
					machine.Kind,
					driver.Name,
					SILENT_AFTER,
					serverView(machine, driver, clock)
				)
			)
		end
		if clock >= machine.NextClaim then
			machine.NextClaim = clock + CLAIM_RETRY
			if not serverOwns(machine) then owner(machine) end
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
	Remotes.MechReport.OnServerEvent:Connect(function(player, text)
		OutpostVehicles.report(player, text)
	end)
	Remotes.MechExit.OnServerEvent:Connect(OutpostVehicles.exit)
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
