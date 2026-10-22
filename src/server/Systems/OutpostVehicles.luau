-- The Outpost's mechs: parked in the Shelter's garage, one pilot each. No Roblox
-- seats: who sits in a seat doesn't replicate, and a seat's own controls,
-- camera and jump-to-leave all got in the way of driving.
--
--   Pilot (the prompt, E)   you become its pilot. Your MechPilot attribute is
--                           its MechId (Shared.MechPilot), its MechPilotId is
--                           your UserId, and a weld (PilotWeld) holds you in
--                           its cockpit.
--   MechMove(at, yaw, speed, turn)   from the pilot's screen, which drives the
--                           mech (Client VehicleDrive). Checked here: only from
--                           its pilot, no faster than it goes, inside the rim.
--                           Then its chassis is put there (anchored: it goes
--                           where it's put, pilot and all) and everyone is
--                           told (MechPosition, MechMotion) so their screens
--                           glide it (MechAnimation).
--   MechExit, or a fight, a match, an expedition, death or leaving: out you
--                           get, beside it (SeatExit lets go of you too).
--   MechReport(text)        the pilot's screen says something's wrong: logged,
--                           with the server's view.
-- An abandoned mech goes home after Outpost.MachineResetSeconds.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(ReplicatedStorage.Shared.Outpost)
local MechPilot = require(ReplicatedStorage.Shared.MechPilot)
local Remotes = require(script.Parent.Remotes)
local OutpostMachines = require(script.Parent.Parent.World.OutpostMachines)

local OutpostVehicles = {}

-- How close you must be to get in.
local BOARD_RANGE = 24
-- Seconds in the cockpit with no word from the pilot's screen before it's
-- logged, and before they're let out (their screen isn't driving: without
-- it there's no way to drive or get out).
local SILENT_AFTER, SILENT_RELEASE = 5, 12
-- Seconds without a move before it counts as stopped (for everyone's glide).
local STOPPED_AFTER = 1
-- Stuck reports taken from one pilot, per ride.
local MAX_REPORTS = 3
-- Where the pilot's body sits, from the cockpit's middle.
local SIT = CFrame.new(0, 2, 0)

type Machine = {
	Id: string,
	Kind: string,
	Bay: CFrame,
	Model: Model,
	Cockpit: BasePart,
	Prompt: ProximityPrompt,
	Pilot: Player?,
	Weld: Weld?,
	-- How its pilot last had it moving, and when.
	Yaw: number,
	Speed: number,
	Turn: number,
	MovedAt: number?,
	LastUsed: number,
	-- Diagnostics: when the pilot got in, whether that was logged as silent,
	-- and stuck reports taken.
	BoardedAt: number,
	SilentLogged: boolean,
	Reports: number,
}
local machines: { Machine } = {}
local folder: Instance? = nil

local function yawOf(part: BasePart): number
	local _, yaw = part.CFrame:ToOrientation()
	return yaw
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where it is and how it's moving, for every screen to glide it (only sent
-- when it changes).
local function publish(machine: Machine)
	local model = machine.Model
	local chassis = model.PrimaryPart :: BasePart
	local position = chassis.Position
	local motion = Vector3.new(machine.Yaw, machine.Speed, machine.Turn)
	if model:GetAttribute("MechPosition") ~= position then
		model:SetAttribute("MechPosition", position)
	end
	if model:GetAttribute("MechMotion") ~= motion then
		model:SetAttribute("MechMotion", motion)
	end
end

-- Outside the Outpost, busy elsewhere, or knocked down (a critter caught
-- them in the cockpit): no piloting.
local function busy(player: Player): boolean
	return not player:GetAttribute("Outpost")
		or player:GetAttribute("SparDown") ~= nil
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("ArenaDropPreparing") ~= nil
		or player:GetAttribute("ArenaDropUntil") ~= nil
		or player:GetAttribute("Expedition") ~= nil
end

local function machineOf(player: Player): Machine?
	for _, machine in machines do
		if machine.Pilot == player then
			return machine
		end
	end
	return nil
end
OutpostVehicles.machineOf = machineOf

-- To the Output, and kept with the playtest reports (Feedback > Reports).
local function note(message: string, detail: string)
	warn(detail)
	local ok, Feedback = pcall(require, script.Parent.Feedback)
	if ok and type(Feedback) == "table" and Feedback.note then
		pcall(Feedback.note, "Server", message, detail)
	end
end

-- How it looks from here.
local function serverView(machine: Machine, clock: number): string
	local at = (machine.Model.PrimaryPart :: BasePart).Position
	return string.format(
		"%s at (%.0f, %.1f, %.0f), pilot %s, last move %s, speed %.1f",
		machine.Id,
		at.X,
		at.Y,
		at.Z,
		if machine.Pilot then machine.Pilot.Name else "none",
		if machine.MovedAt then string.format("%.1f s ago", clock - machine.MovedAt) else "never",
		machine.Speed
	)
end

-- Getting in and out ----------------------------------------------------------------------

-- Out of the cockpit. `place`: stood beside it (not when something else is
-- moving them: SeatExit, a respawn).
local function release(machine: Machine, place: boolean?)
	local player = machine.Pilot
	machine.Pilot = nil
	-- (The weld goes first: moving them while welded would drag the mech.)
	if machine.Weld then
		machine.Weld:Destroy()
		machine.Weld = nil
	end
	for _, item in machine.Cockpit:GetChildren() do
		if item.Name == "PilotWeld" then
			item:Destroy()
		end
	end
	machine.Model:SetAttribute("MechPilotId", nil)
	machine.Prompt.Enabled = true
	machine.Speed, machine.Turn = 0, 0
	publish(machine)
	machine.LastUsed = os.clock()
	if not player then
		return
	end
	if player:GetAttribute("MechPilot") == machine.Id then
		player:SetAttribute("MechPilot", nil)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.GettingUp)
	end
	local root = rootOf(player)
	if place and character and root then
		-- Down beside its left leg, on the ground.
		local chassis = machine.Model.PrimaryPart :: BasePart
		local side = chassis.CFrame * CFrame.new(-(chassis.Size.X / 2 + 4), 0, 0)
		local base = chassis.Position.Y - chassis.Size.Y / 2
		character:PivotTo(CFrame.new(side.Position.X, base + 3, side.Position.Z) * CFrame.Angles(0, machine.Yaw, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end
OutpostVehicles.release = release

-- Into the cockpit: the Pilot prompt. Returns whether you're in.
function OutpostVehicles.board(player: Player, machine: Machine): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	if machine.Pilot or machineOf(player) or busy(player) then
		return false
	end
	if (root.Position - machine.Cockpit.Position).Magnitude > BOARD_RANGE then
		return false
	end
	humanoid.Sit = true -- (the pose)
	local weld = Instance.new("Weld")
	weld.Name = "PilotWeld"
	weld.Part0, weld.Part1 = machine.Cockpit, root
	weld.C0, weld.C1 = SIT, CFrame.identity
	weld.Parent = machine.Cockpit
	local now = os.clock()
	machine.Pilot, machine.Weld = player, weld
	machine.Yaw, machine.Speed, machine.Turn = yawOf(machine.Model.PrimaryPart :: BasePart), 0, 0
	machine.MovedAt, machine.BoardedAt, machine.SilentLogged, machine.Reports = nil, now, false, 0
	machine.LastUsed = now
	machine.Prompt.Enabled = false
	machine.Model:SetAttribute("MechPilotId", player.UserId)
	player:SetAttribute("MechPilot", machine.Id)
	publish(machine)
	print(string.format("[Mech] %s is piloting %s", player.Name, machine.Id))
	return true
end

function OutpostVehicles.exit(player: Player): boolean
	local machine = machineOf(player)
	if not machine then
		return false
	end
	release(machine, true)
	return true
end

-- Driving --------------------------------------------------------------------------------------

-- MechMove: where its pilot's screen has driven it. Only from its pilot, no
-- further than it could have gone since the last one, no higher than a step
-- and the steepest ground it walks over that far (MechPilot.Grade), inside
-- the rim.
function OutpostVehicles.move(player: Player, at: any, yaw: any, speed: any, turn: any, now: number?): boolean
	if typeof(at) ~= "Vector3" or not finite(at.X) or not finite(at.Y) or not finite(at.Z) then
		return false
	end
	if not finite(yaw) or not finite(speed) or not finite(turn) then
		return false
	end
	local machine = machineOf(player)
	local spec = machine and Rules.Machines[machine.Kind]
	if not machine or not spec or busy(player) then
		return false
	end
	local clock = now or os.clock()
	local chassis = machine.Model.PrimaryPart :: BasePart
	local here = chassis.Position
	-- (A little slack: moves can arrive bunched up.)
	local since = math.clamp(clock - (machine.MovedAt or clock - 0.1), 0.03, 1)
	local reach = spec.MaxSpeed * since * 1.5 + 2
	local offset = at - here
	local across = Vector3.new(offset.X, 0, offset.Z)
	if across.Magnitude > reach then
		across = across.Unit * reach
	end
	local scale = machine.Model:GetAttribute("MechScale") or 1
	local rise = math.clamp(offset.Y, -60, MechPilot.Lift * scale * 2 + 1 + across.Magnitude * MechPilot.Grade)
	local to = here + across + Vector3.new(0, rise, 0)
	local centre = Rules.Location.Position
	local out = Vector3.new(to.X - centre.X, 0, to.Z - centre.Z)
	local limit = Rules.Radius + 40
	if out.Magnitude > limit then
		out = out.Unit * limit
		to = Vector3.new(centre.X + out.X, to.Y, centre.Z + out.Z)
	end
	if to.Y < centre.Y - 40 then
		to = Vector3.new(to.X, here.Y, to.Z)
	end
	chassis.CFrame = CFrame.new(to) * CFrame.Angles(0, yaw, 0)
	machine.Yaw = yaw
	machine.Speed = math.clamp(speed, -spec.MaxSpeed, spec.MaxSpeed)
	machine.Turn = math.clamp(turn, -10, 10)
	machine.MovedAt, machine.LastUsed = clock, clock
	publish(machine)
	return true
end

-- MechReport: the pilot's screen says it won't move. Logged with both views.
function OutpostVehicles.report(player: Player, text: any, now: number?): boolean
	if type(text) ~= "string" then
		return false
	end
	local machine = machineOf(player)
	if not machine or machine.Reports >= MAX_REPORTS then
		return false
	end
	machine.Reports += 1
	local view = serverView(machine, now or os.clock())
	Remotes.MechReport:FireClient(player, "[Mech] Server: " .. view)
	note(
		"[Mech] " .. machine.Kind .. " won't move",
		string.format(
			"[Mech] %s won't move for %s. Client: %s. Server: %s.",
			machine.Kind,
			player.Name,
			string.sub(text, 1, 400),
			view
		)
	)
	return true
end

-- Each frame: let go of pilots who've gone, died, respawned, been taken
-- elsewhere or got busy; log a pilot whose screen never drives; a mech whose
-- pilot stopped sending moves has stopped.
function OutpostVehicles.step(now: number?)
	local clock = now or os.clock()
	for _, machine in machines do
		local player = machine.Pilot
		if not player then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(player)
		local weld = machine.Weld
		if
			player.Parent == nil
			or not humanoid
			or humanoid.Health <= 0
			or not root
			or not weld
			or weld.Parent == nil
			or weld.Part1 ~= root
			or player:GetAttribute("MechPilot") ~= machine.Id
		then
			release(machine, false)
			continue
		end
		if busy(player) then
			release(machine, true)
			continue
		end
		if not machine.MovedAt and not machine.SilentLogged and clock - machine.BoardedAt >= SILENT_AFTER then
			machine.SilentLogged = true
			Remotes.MechReport:FireClient(
				player,
				"[Mech] Server: no moves from your screen since you got in. " .. serverView(machine, clock)
			)
			note(
				"[Mech] no moves from the pilot's screen",
				string.format(
					"[Mech] %s: %s has sat in it for %d s and their screen hasn't moved it "
						.. "(Client VehicleDrive never started driving). Server: %s.",
					machine.Kind,
					player.Name,
					SILENT_AFTER,
					serverView(machine, clock)
				)
			)
		end
		if not machine.MovedAt and clock - machine.BoardedAt >= SILENT_RELEASE then
			Remotes.MechReport:FireClient(
				player,
				"[Mech] Server: your screen never started driving, so you've been let out."
			)
			warn(string.format("[Mech] %s: let %s out (their screen never drove it)", machine.Kind, player.Name))
			release(machine, true)
			continue
		end
		if
			machine.MovedAt
			and clock - machine.MovedAt > STOPPED_AFTER
			and (machine.Speed ~= 0 or machine.Turn ~= 0)
		then
			machine.Speed, machine.Turn = 0, 0
			publish(machine)
		end
	end
end

-- Parking -------------------------------------------------------------------------------------

-- Back to its bay, parked straight.
local function reset(machine: Machine)
	if machine.Pilot then
		release(machine, true)
	end
	local chassis = machine.Model.PrimaryPart :: BasePart
	chassis.Anchored = true
	machine.Model:PivotTo(machine.Bay * CFrame.new(0, chassis.Size.Y / 2 + 0.2, 0))
	machine.Yaw, machine.Speed, machine.Turn = yawOf(chassis), 0, 0
	publish(machine)
	machine.LastUsed = os.clock()
end

local function spawnMachine(kind: string, bay: CFrame, index: number): Machine
	local model = OutpostMachines.build(kind, bay)
	-- Anchored for good: it goes where it's put (see the top of this file).
	local chassis = model.PrimaryPart :: BasePart
	chassis.Anchored = true
	local id = kind .. index
	model:SetAttribute("MechId", id)
	model:SetAttribute("MechKind", kind)
	model.Parent = folder
	CollectionService:AddTag(model, MechPilot.Tag)
	local cockpit = model:FindFirstChild("Cockpit") :: BasePart
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
	prompt.Parent = cockpit
	local machine: Machine = {
		Id = id,
		Kind = kind,
		Bay = bay,
		Model = model,
		Cockpit = cockpit,
		Prompt = prompt,
		Pilot = nil,
		Weld = nil,
		Yaw = yawOf(chassis),
		Speed = 0,
		Turn = 0,
		MovedAt = nil,
		LastUsed = os.clock(),
		BoardedAt = 0,
		SilentLogged = false,
		Reports = 0,
	}
	table.insert(machines, machine)
	publish(machine)
	return machine
end

function OutpostVehicles.start(site)
	local holder = Instance.new("Folder")
	holder.Name = "Machines"
	holder.Parent = site.Model
	folder = holder
	for index, bay in site.Parking do
		local ok, err = pcall(spawnMachine, bay.Kind, bay.CFrame, index)
		if not ok then
			warn("[Mech] couldn't park a " .. tostring(bay.Kind) .. ": " .. tostring(err))
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("PromptKind") ~= "Drive" then
			return
		end
		for _, machine in machines do
			if machine.Prompt == prompt then
				OutpostVehicles.board(player, machine)
			end
		end
	end)
	Remotes.MechMove.OnServerEvent:Connect(function(player, at, yaw, speed, turn)
		OutpostVehicles.move(player, at, yaw, speed, turn)
	end)
	Remotes.MechReport.OnServerEvent:Connect(function(player, text)
		OutpostVehicles.report(player, text)
	end)
	Remotes.MechExit.OnServerEvent:Connect(OutpostVehicles.exit)
	Players.PlayerRemoving:Connect(function(player)
		local machine = machineOf(player)
		if machine then
			release(machine, false)
		end
	end)
	RunService.Heartbeat:Connect(function()
		OutpostVehicles.step()
	end)
	print(string.format("[Mech] %d mechs parked (no seats: the pilot's screen drives)", #machines))
	-- Abandoned machines go home; anything that falls out of the world
	-- comes straight back.
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
		if machine.Pilot then
			machine.LastUsed = now
			continue
		end
		local fell = chassis.Position.Y < Rules.Location.Position.Y - 40
		local away = (chassis.Position - machine.Bay.Position).Magnitude > 12
		if fell or (away and now - machine.LastUsed > Rules.MachineResetSeconds) then
			reset(machine)
		end
	end
end

-- For tests.
OutpostVehicles._machines = machines
OutpostVehicles._reset = reset
OutpostVehicles._spawn = spawnMachine

return OutpostVehicles
