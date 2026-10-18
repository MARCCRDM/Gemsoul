-- The mechs, driven by the server. The pilot sends input; each frame the
-- server moves every piloted mech itself. A mech is anchored, never a physics
-- body: it's put where it should be, along the ground (stepping up kerbs,
-- dropping off ledges, stopped by walls and rocks), with the pilot riding in
-- its seat. So nothing depends on Roblox handing the physics to anyone, on
-- the constraints' solver, or on the pilot's humanoid: an anchored part always
-- goes where it's put. (Driving through physics, mechs that stood still were
-- reported again and again, and no cause was ever found from the logs.)
--
-- Clients draw a moving mech gliding between the server's steps from the
-- model's MechPosition and MechMotion (yaw, speed, turn rate) attributes
-- (MechAnimation); MechBlocked says something is in the way.
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
-- Seconds in the seat with no word from the pilot's client before it's logged.
local SILENT_AFTER = 5
-- Stuck reports taken from one pilot, per time in the seat.
local MAX_REPORTS = 3
-- Studs kept clear of a wall; the highest step a mech climbs (times its
-- scale: its foot rides up kerbs this tall, Server OutpostMachines); how far
-- below it looks for the ground.
local SKIN, LIFT, DROP = 0.4, 1.6, 60
-- Seconds a stuck report lets it drive through whatever it's wedged in.
local UNSTICK = 1.5

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
	-- Its size, for moving it along the ground: the highest step it climbs,
	-- how high its middle rides, and how fast it's falling off a ledge.
	Lift: number,
	Hover: number,
	Fall: number,
	Blocked: string?,
	UnstickUntil: number,
	-- Diagnostics: when the pilot sat down, whether their client has said
	-- anything since, stuck reports taken, and the server keeping the physics.
	BoardedAt: number,
	Heard: boolean,
	SilentLogged: boolean,
	Reports: number,
	Pilot: Player?,
}
local machines: { Machine } = {}
local bySeat: { [Instance]: Machine } = {}
local folder: Instance? = nil
OutpostVehicles.Gravity = 196.2 -- (workspace.Gravity, once started)

local function yawOf(part: BasePart): number
	local _, yaw = part.CFrame:ToOrientation()
	return yaw
end

-- Where it is and how it's moving, for every client to draw it gliding
-- between the server's steps (MechAnimation). Only sent when it changes.
local function publish(machine: Machine, turn: number)
	local chassis = machine.Model.PrimaryPart :: BasePart
	local position = chassis.Position
	local motion = Vector3.new(machine.Yaw, machine.Speed, turn)
	local model = machine.Model
	if model:GetAttribute("MechPosition") ~= position then
		model:SetAttribute("MechPosition", position)
	end
	if model:GetAttribute("MechMotion") ~= motion then
		model:SetAttribute("MechMotion", motion)
	end
	if model:GetAttribute("MechBlocked") ~= machine.Blocked then
		model:SetAttribute("MechBlocked", machine.Blocked)
	end
end

local function stop(machine: Machine)
	local chassis = machine.Model.PrimaryPart :: BasePart
	machine.Speed, machine.Blocked = 0, nil
	machine.Yaw = yawOf(chassis)
	publish(machine, 0)
end

-- Back to its bay, parked straight.
local function reset(machine: Machine)
	local chassis = machine.Model.PrimaryPart :: BasePart
	chassis.Anchored = true
	machine.Model:PivotTo(machine.Bay * CFrame.new(0, chassis.Size.Y / 2 + 0.2, 0))
	machine.Fall, machine.ServerDriving = 0, false
	stop(machine)
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
	-- Anchored for good: the server moves it (see the top of this file).
	local chassis = model.PrimaryPart :: BasePart
	chassis.Anchored = true
	model.Parent = folder
	CollectionService:AddTag(model, "OutpostMech")
	local seat = model:FindFirstChild("Seat") :: VehicleSeat
	local scale = model:GetAttribute("MechScale") or 1
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
		Yaw = yawOf(chassis),
		ServerDriving = false,
		Lift = LIFT * scale,
		Hover = chassis.Size.Y / 2 + 0.2,
		Fall = 0,
		Blocked = nil,
		UnstickUntil = 0,
		BoardedAt = 0,
		Heard = false,
		SilentLogged = false,
		Reports = 0,
	}
	table.insert(machines, machine)
	publish(machine, 0)

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

-- A pilot got in or out: fresh input, from rest.
function OutpostVehicles.seated(machine: Machine)
	local driver = driverOf(machine)
	local prompt = machine.Seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = driver == nil
	end
	-- Occupant and SeatWeld both notify us. The second notification must not
	-- erase input that arrived between them, or restart the silent-client timer.
	if machine.Pilot == driver then return end
	local previous = machine.Pilot
	machine.Pilot = driver
	if previous then
		local reference = previous:FindFirstChild("PilotedMechSeat")
		if reference and reference.Value == machine.Seat then reference.Value = nil end
	end
	if driver then
		-- Replicate an explicit discovery reference. On a remote client the
		-- humanoid's SeatPart and root's joint list can lag behind the seat weld.
		-- Clients still verify the occupant/weld before using this reference.
		local reference = driver:FindFirstChild("PilotedMechSeat")
		if not reference then
			reference = Instance.new("ObjectValue")
			reference.Name = "PilotedMechSeat"
			reference.Parent = driver
		end
		reference.Value = machine.Seat
	end
	machine.Seat:SetAttribute("MechInputThrottle", nil)
	machine.Seat:SetAttribute("MechInputSteer", nil)
	machine.Throttle, machine.Steer, machine.InputAt, machine.Speed = 0, 0, 0, 0
	machine.ServerDriving = false
	machine.BoardedAt, machine.Heard, machine.SilentLogged = os.clock(), false, false
	machine.Reports, machine.UnstickUntil = 0, 0
	stop(machine)
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
	if machine.Pilot ~= driverOf(machine) then OutpostVehicles.seated(machine) end
	machine.Throttle, machine.Steer = math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
	machine.InputAt = now or os.clock()
	machine.Heard = true
	machine.Seat:SetAttribute("MechInputThrottle", machine.Throttle)
	machine.Seat:SetAttribute("MechInputSteer", machine.Steer)
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

-- How it looks from here: where it is, the input, what's in the way.
local function serverView(machine: Machine, clock: number): string
	local chassis = machine.Model.PrimaryPart :: BasePart
	local at = chassis.Position
	return string.format(
		"at (%.0f, %.1f, %.0f), anchored %s, server driving %s, input %.2f/%.2f (%.1f s old), speed %.1f, blocked by %s",
		at.X,
		at.Y,
		at.Z,
		tostring(chassis.Anchored),
		tostring(machine.ServerDriving),
		machine.Throttle,
		machine.Steer,
		clock - machine.InputAt,
		machine.Speed,
		machine.Blocked or "nothing"
	)
end

-- MechReport: the pilot's client says its mech won't move. Logged with both
-- sides' view; for a moment it drives through whatever it's wedged in.
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
	local before = serverView(machine, clock)
	local chassis = machine.Model.PrimaryPart :: BasePart
	chassis.Anchored = true
	machine.UnstickUntil = clock + UNSTICK
	local done = "re-anchored, driving through obstacles for " .. UNSTICK .. " s"
	-- Echo the server view to this pilot's log, so a client log shows both.
	Remotes.MechReport:FireClient(player, "[Mech] Server: " .. before .. ". Done: " .. done)
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

-- What the mech bumps into: everything solid but itself, the players, and
-- the Outpost's creatures and rifts.
local function query(machine: Machine): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = { machine.Model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	for _, name in { "Enemies", "Kaiju", "Rifts", "RiftTears" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(skip, found)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- How far the mech's hull, swept from `from` along `direction`, gets before
-- it hits something (nil: nothing), and what it hit. (Replaced in tests.)
function OutpostVehicles.sweep(machine: Machine, from: CFrame, size: Vector3, direction: Vector3): (number?, string?)
	local hit = workspace:Blockcast(from, size, direction, query(machine))
	if hit then
		return hit.Distance, hit.Instance.Name
	end
	return nil, nil
end

-- The height of the ground under `origin`, looking down `length` studs.
function OutpostVehicles.floor(machine: Machine, origin: Vector3, length: number): number?
	local hit = workspace:Raycast(origin, Vector3.new(0, -length, 0), query(machine))
	return hit and hit.Position.Y
end

-- The hull to sweep: its box where it stands now.
local function hullOf(machine: Machine, chassis: BasePart): (CFrame, Vector3)
	local hull = machine.Model:FindFirstChild("Hull") :: BasePart?
	if hull then
		return hull.CFrame, hull.Size - Vector3.new(0.2, 0.2, 0.2)
	end
	local size = chassis.Size
	return chassis.CFrame * CFrame.new(0, machine.Lift / 2, 0), Vector3.new(size.X, size.Y - machine.Lift, size.Z)
end

-- One frame's move: `distance` studs along heading `yaw` (backwards if
-- negative), over the ground. Returns what stopped it, if anything.
local function travel(
	machine: Machine,
	chassis: BasePart,
	distance: number,
	yaw: number,
	dt: number,
	clock: number
): string?
	local here = chassis.Position
	local heading = CFrame.Angles(0, yaw, 0)
	local to = here
	local blocked: string? = nil
	if math.abs(distance) > 1e-4 then
		local along = heading.LookVector * math.sign(distance)
		local free = math.abs(distance)
		if clock >= machine.UnstickUntil then
			local from, size = hullOf(machine, chassis)
			local hit, what = OutpostVehicles.sweep(machine, from, size, along * (free + SKIN))
			if hit then
				free = math.clamp(hit - SKIN, 0, free)
				blocked = what or "something"
			end
		end
		to = here + along * free
		-- (Never out over the crater rim.)
		local offset = to - Rules.Location.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > Rules.Radius + 40 then
			to, blocked = here, "the crater rim"
		end
	end
	-- The ground there: a step it can climb, a drop it falls down, or neither.
	local foot = here.Y - machine.Hover
	local function groundAt(at: Vector3): number?
		local y = OutpostVehicles.floor(
			machine,
			Vector3.new(at.X, foot + machine.Lift + 0.5, at.Z),
			machine.Lift + 0.5 + DROP
		)
		return if y then y + machine.Hover else nil
	end
	local rest = groundAt(to)
	if to ~= here and (rest == nil or rest > here.Y + machine.Lift + 0.05) then
		to, blocked = here, if rest == nil then "no ground" else "a ledge"
		rest = groundAt(here)
	end
	local y = here.Y
	if rest and rest >= y then
		y, machine.Fall = rest, 0
	elseif rest then
		machine.Fall += OutpostVehicles.Gravity * dt
		y = math.max(rest, y - machine.Fall * dt)
		if y <= rest then
			machine.Fall = 0
		end
	end
	-- (Nothing changed, nothing set: nothing to send to the clients.)
	if to ~= here or y ~= here.Y or yaw ~= machine.Yaw then
		chassis.CFrame = CFrame.new(to.X, y, to.Z) * heading
	end
	return blocked
end

-- One frame: move every piloted mech (and let a dropped one land).
function OutpostVehicles.step(dt: number, now: number?)
	local clock = now or os.clock()
	for _, machine in machines do
		local driver = driverOf(machine)
		-- ChildAdded can fire before SeatWeld.Part1 arrives. Reconcile after
		-- replication settles instead of depending on another event.
		if machine.Pilot ~= driver then
			OutpostVehicles.seated(machine)
		end
		local chassis = machine.Model.PrimaryPart
		local spec = Rules.Machines[machine.Kind]
		if not chassis or not spec then
			continue
		end
		if not driver then
			machine.ServerDriving = false
			if machine.Fall > 0 then
				travel(machine, chassis, 0, machine.Yaw, dt, clock)
				publish(machine, 0)
			end
			continue
		end
		if not machine.Heard and not machine.SilentLogged and clock - machine.BoardedAt >= SILENT_AFTER then
			machine.SilentLogged = true
			Remotes.MechReport:FireClient(
				driver,
				"[Mech] No pilot input received after boarding. Server: " .. serverView(machine, clock)
			)
			note(
				"[Mech] no word from the pilot's client",
				string.format(
					"[Mech] %s: %s has sat in it for %d s and their client hasn't started driving "
						.. "(Client VehicleDrive never ran begin). Server: %s.",
					machine.Kind,
					driver.Name,
					SILENT_AFTER,
					serverView(machine, clock)
				)
			)
		end
		if not machine.ServerDriving then
			-- Pick up from where it stands, at rest.
			machine.ServerDriving = true
			machine.Yaw, machine.Speed = yawOf(chassis), 0
		end
		-- (Anchored for good; put back if anything ever lets go of it.)
		if not chassis.Anchored then
			chassis.Anchored = true
		end
		local fresh = clock - machine.InputAt <= INPUT_TIMEOUT and not busy(driver)
		local throttle = if fresh then machine.Throttle else 0
		local turn = if fresh then machine.Steer else 0
		local before = machine.Yaw
		local speed, yaw = Rules.drive(spec, machine.Speed, machine.Yaw, throttle, turn, dt)
		local blocked = travel(machine, chassis, speed * dt, yaw, dt, clock)
		-- Against a wall it stops (and starts again from rest when turned away).
		machine.Speed = if blocked then 0 else speed
		machine.Yaw, machine.Blocked = yaw, blocked
		publish(machine, if dt > 0 then (yaw - before) / dt else 0)
	end
end

function OutpostVehicles.start(site)
	local ok, gravity = pcall(function()
		return workspace.Gravity
	end)
	if ok and type(gravity) == "number" and gravity > 0 then
		OutpostVehicles.Gravity = gravity
	end
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
