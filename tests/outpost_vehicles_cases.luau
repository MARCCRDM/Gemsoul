-- The Outpost's machines on the server (Server OutpostVehicles): boarding from
-- the Drive prompt, handing the pilot the physics, and the fallback when that
-- hand-over doesn't take: the server drives the machine itself from the
-- pilot's MechInput, until the hand-over is retried and succeeds. Real
-- module and driving maths (Shared.Outpost), with stand-in seats, players and
-- physics. Run by tests/run_outpost_vehicles.py (needs lune).
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

local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
		Count = function()
			return #listeners
		end,
	}
end

-- Stand-ins ------------------------------------------------------------------------------
local function newInstance(class)
	local data = { ClassName = class, Attributes = {}, Enabled = true, Children = {} }
	local proxy = {}
	function data.SetAttribute(_, k, v)
		data.Attributes[k] = v
	end
	function data.GetAttribute(_, k)
		return data.Attributes[k]
	end
	return setmetatable(proxy, {
		__index = data,
		__newindex = function(_, k, v)
			data[k] = v
			if k == "Parent" and type(v) == "table" and v.Children and data.Name then
				v.Children[data.Name] = proxy
			end
		end,
	})
end

local NO_OWNER = "Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts."
local function makeMachine(kind, bay)
	local chassis = {
		Anchored = false,
		Size = R.Vector3.new(7.6, 12, 6.2),
		CFrame = bay,
		AssemblyLinearVelocity = R.Vector3.zero,
		AssemblyAngularVelocity = R.Vector3.zero,
		Owner = nil,
		OwnerError = nil,
		Claims = 0,
		Name = "Chassis",
		-- Other parts joined to it (see joinPart).
		Joined = {},
	}
	chassis.Drive = { PlaneVelocity = R.Vector2.zero }
	chassis.Steer = { CFrame = R.CFrame.identity }
	function chassis:FindFirstChild(name)
		return if name == "Drive" then self.Drive elseif name == "Steer" then self.Steer else nil
	end
	function chassis:SetNetworkOwner(player)
		self.Claims += 1
		if self.OwnerError then
			error(self.OwnerError)
		end
		self.Owner = player
	end
	function chassis:GetNetworkOwner()
		return self.Owner
	end
	function chassis:GetConnectedParts(recursive)
		assert(recursive == true, "Wanted the whole assembly")
		local parts = { self }
		for _, part in self.Joined do
			table.insert(parts, part)
		end
		return parts
	end
	function chassis:GetFullName()
		return "Workspace.Outpost.Machines." .. kind .. ".Chassis"
	end
	local seat = { Occupant = nil, Children = {}, Changed = signal(), Kind = kind }
	function seat:FindFirstChild(name)
		return self.Children[name]
	end
	function seat:GetPropertyChangedSignal(name)
		assert(name == "Occupant", "Unexpected seat property " .. tostring(name))
		return self.Changed
	end
	function seat:Sit(humanoid)
		self.Occupant = humanoid
		humanoid.SeatPart = self
		self.Changed:Fire()
	end
	local model = { PrimaryPart = chassis, Seat = seat }
	function model:FindFirstChild(name)
		return if name == "Seat" then self.Seat else nil
	end
	function chassis:IsDescendantOf(ancestor)
		return ancestor == model
	end
	function model:PivotTo(cf)
		chassis.CFrame = cf
	end
	return model
end

local function makePlayer(name)
	local player = { Name = name, Attributes = { Outpost = true } }
	function player:GetAttribute(k)
		return self.Attributes[k]
	end
	local humanoid = { Health = 100, SeatPart = nil }
	local character = { Player = player, Humanoid = humanoid }
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then self.Humanoid else nil
	end
	humanoid.Parent = character
	player.Character = character
	-- The body's root part, for the anchoring checks.
	local root = { Name = "HumanoidRootPart", Anchored = false }
	function root:IsDescendantOf(ancestor)
		return ancestor == character
	end
	function root:GetFullName()
		return "Workspace." .. name .. ".HumanoidRootPart"
	end
	player.Root = root
	return player, humanoid
end
-- A part welded into a machine's assembly (anchored or not).
local function joinPart(machine, part)
	table.insert(machine.Model.PrimaryPart.Joined, part)
end
local function getOut(seat, humanoid)
	seat.Occupant = nil
	humanoid.SeatPart = nil
	seat.Changed:Fire()
end

local clockNow = 1000
local warnings = {}
local Players = {}
function Players:GetPlayerFromCharacter(character)
	return character and character.Player
end
local promptTriggered = signal()
local mechInput = { OnServerEvent = signal() }
local mechReport = { OnServerEvent = signal() }
local notes = {}
local function handovers()
	local found = {}
	for _, line in warnings do
		if line:find("couldn't hand", 1, true) then
			table.insert(found, line)
		end
	end
	return found
end
local heartbeat = signal()
local Rules = load("src/shared/Outpost.luau", { CFrame = R.CFrame, Color3 = R.Color3 })
local modules = {
	Rules = { Module = Rules },
	Remotes = { Module = { MechInput = mechInput, MechReport = mechReport } },
	Feedback = {
		Module = {
			note = function(side, message, detail)
				table.insert(notes, { Side = side, Message = message, Detail = detail })
			end,
		},
	},
	Machines = { Module = { build = makeMachine } },
}
local services = {
	Players = Players,
	CollectionService = { AddTag = function() end },
	ProximityPromptService = { PromptTriggered = promptTriggered },
	ReplicatedStorage = { Shared = { Outpost = modules.Rules } },
	RunService = { Heartbeat = heartbeat },
}
local Vehicles = load("src/server/Systems/OutpostVehicles.luau", {
	game = {
		GetService = function(_, name)
			return assert(services[name], "No stand-in for " .. name)
		end,
	},
	script = {
		Parent = {
			Remotes = modules.Remotes,
			Feedback = modules.Feedback,
			Parent = { World = { OutpostMachines = modules.Machines } },
		},
	},
	require = function(target)
		return assert(target.Module, "Unexpected require")
	end,
	Instance = { new = newInstance },
	Enum = R.Enum,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	os = setmetatable({
		clock = function()
			return clockNow
		end,
	}, { __index = os }),
	task = { spawn = function() end, wait = function() end },
	warn = function(...)
		table.insert(warnings, table.concat({ ... }, " "))
	end,
})

-- Boarding -------------------------------------------------------------------------------
local site = {
	Model = {},
	Parking = {
		{ Kind = "Hauler", CFrame = R.CFrame.new(0, 0, 7000) },
		{ Kind = "Mole", CFrame = R.CFrame.new(40, 0, 7000) * R.CFrame.Angles(0, math.rad(90), 0) },
	},
}
Vehicles.start(site)
local hauler, mole = Vehicles._machines[1], Vehicles._machines[2]
check(hauler and mole and #Vehicles._machines == 2, "Machines were not parked")
check(mechInput.OnServerEvent:Count() == 1 and heartbeat:Count() == 1, "Pilot input or the drive step isn't wired up")
check(mechReport.OnServerEvent:Count() == 1, "Stuck reports aren't wired up")
local prompt = hauler.Seat:FindFirstChild("DrivePrompt")
check(prompt and prompt:GetAttribute("PromptKind") == "Drive" and prompt.Enabled, "No Drive prompt on the seat")

local pilot, pilotHum = makePlayer("Pilot")
promptTriggered:Fire(prompt, pilot)
local chassis = hauler.Model.PrimaryPart
check(hauler.Seat.Occupant == pilotHum and not prompt.Enabled, "The Drive prompt didn't seat the pilot")
check(chassis.Owner == pilot, "The pilot wasn't handed the physics")
check(#handovers() == 0, "A clean hand-over warned")

-- With the pilot's client in charge, the server stays out of it.
mechInput.OnServerEvent:Fire(pilot, 1, 0)
for _ = 1, 30 do
	clockNow += 1 / 60
	heartbeat:Fire(1 / 60)
end
check(chassis.Drive.PlaneVelocity == R.Vector2.zero, "The server fought the pilot's client for the controls")
check(not hauler.ServerDriving, "The server thought it was driving a client-owned machine")

-- Physics follow the drive constraint, unless something blocks the way.
-- While a key is held the client re-sends it every 0.5 s (Client VehicleDrive).
local blockedBy, hold = nil, nil
local function press(player, throttle, steer)
	hold = { player, throttle, steer }
	return Vehicles.input(player, throttle, steer)
end
local sinceSend = 0
local function frames(n, dt)
	dt = dt or 1 / 60
	for _ = 1, n do
		clockNow += dt
		sinceSend += dt
		if hold and sinceSend >= 0.5 then
			sinceSend = 0
			Vehicles.input(hold[1], hold[2], hold[3])
		end
		heartbeat:Fire(dt)
		for _, machine in Vehicles._machines do
			local c = machine.Model.PrimaryPart
			local pv = c.Drive.PlaneVelocity
			c.AssemblyLinearVelocity = if blockedBy == machine then R.Vector3.zero else R.Vector3.new(pv.X, 0, pv.Y)
			local _, yaw = c.Steer.CFrame:ToOrientation()
			c.CFrame = R.CFrame.new(c.CFrame.Position + c.AssemblyLinearVelocity * dt) * R.CFrame.Angles(0, yaw, 0)
		end
	end
end

-- The hand-over fails: the server drives instead, and says why, once.
getOut(hauler.Seat, pilotHum)
check(chassis.Owner == nil and prompt.Enabled, "Getting out didn't give the machine back to the server")
chassis.OwnerError, chassis.Claims = NO_OWNER, 0
promptTriggered:Fire(prompt, pilot)
check(hauler.Seat.Occupant == pilotHum, "Couldn't reboard")
check(
	#handovers() == 1 and handovers()[1]:find("[Mech]", 1, true) and handovers()[1]:find("Pilot", 1, true),
	"No warning when the hand-over failed"
)
check(handovers()[1]:find("Anchored", 1, true) ~= nil, "The warning didn't say why")
frames(10)
check(chassis.Drive.PlaneVelocity == R.Vector2.zero, "The server drove without any input")
check(press(pilot, 1, 0), "The pilot's input was refused")
frames(60 * 4)
local pv = chassis.Drive.PlaneVelocity
check(
	math.abs(pv.X) < 1e-3 and math.abs(pv.Y + Rules.Machines.Hauler.MaxSpeed) < 1e-3,
	"Server-side driving didn't reach top speed straight ahead"
)
check(chassis.CFrame.Position.Z < 7000 - 40, "The machine never moved")
check(#handovers() == 1, "Retrying the hand-over warned again")
check(chassis.Claims >= 3, "The hand-over was never retried")

-- Steering, from where the machine actually points.
press(pilot, 0, 1)
frames(30)
local _, yaw = chassis.Steer.CFrame:ToOrientation()
check(yaw < -0.2, "Server-side steering didn't turn the machine")

-- Walls: no shoving at full speed into a rock.
press(pilot, 1, 0)
blockedBy = hauler
frames(30)
check(chassis.Drive.PlaneVelocity.Magnitude <= 10 + 1e-3, "Kept shoving into a wall")
blockedBy = nil

-- Input that stops arriving counts as let go.
hold = nil
frames(60 * 3)
check(chassis.Drive.PlaneVelocity.Magnitude < 1, "A lost connection left the machine driving")
press(pilot, 1, 0)
frames(60)
check(chassis.Drive.PlaneVelocity.Magnitude > 5, "Fresh input didn't drive again")

-- Only the pilot steers, and only with sane numbers.
local other = makePlayer("Other")
check(not Vehicles.input(other, -1, 0), "Someone on foot steered another player's machine")
for _, bad in { { 0 / 0, 0 }, { math.huge, 0 }, { 0, -math.huge }, { "1", 0 }, { nil, 0 }, { {}, 1 } } do
	check(not Vehicles.input(pilot, bad[1], bad[2]), "Bad input was accepted: " .. tostring(bad[1]))
end
check(hauler.Throttle == 1 and hauler.Steer == 0, "Bad input changed the controls")
check(Vehicles.input(pilot, 9, -9) and hauler.Throttle == 1 and hauler.Steer == -1, "Out-of-range input wasn't clamped")
Vehicles.input(pilot, 1, 0)

-- Busy elsewhere: the machine stops.
pilot.Attributes.CombatSession = "Duel"
press(pilot, 1, 0)
frames(60 * 3)
check(chassis.Drive.PlaneVelocity.Magnitude < 1, "A pilot in a fight kept driving")
pilot.Attributes.CombatSession = nil

-- Turning in place while client-driven, then losing the physics: the server
-- carries on from the current heading, not the one it was boarded at.
chassis.OwnerError = nil
frames(60 * 3)
check(chassis.Owner == pilot and not hauler.ServerDriving, "A retried hand-over didn't take")
local velocity = chassis.Drive.PlaneVelocity
frames(30)
check(chassis.Drive.PlaneVelocity == velocity, "The server kept driving after the hand-over took")
chassis.CFrame = R.CFrame.new(chassis.CFrame.Position) * R.CFrame.Angles(0, 1.2, 0)
chassis.Owner = nil
chassis.OwnerError = NO_OWNER
press(pilot, 0, 0)
frames(1)
local _, carried = chassis.Steer.CFrame:ToOrientation()
check(math.abs(carried - 1.2) < 0.05, "The server snapped the machine back to an old heading")

-- Getting out: it stops, the prompt comes back, the server holds the physics.
press(pilot, 1, 0)
frames(30)
chassis.OwnerError = nil
getOut(hauler.Seat, pilotHum)
hold = nil
check(chassis.Drive.PlaneVelocity == R.Vector2.zero, "An empty machine kept driving")
check(prompt.Enabled and chassis.Owner == nil, "An empty machine wasn't handed back")
frames(30)
check(chassis.Drive.PlaneVelocity == R.Vector2.zero, "The server drove an empty machine")
check(not Vehicles.input(pilot, 1, 0), "Input from someone who got out was accepted")

-- A new pilot starts from rest, not from the last pilot's input.
local second, secondHum = makePlayer("Second")
chassis.OwnerError = NO_OWNER
promptTriggered:Fire(prompt, second)
check(
	hauler.Seat.Occupant == secondHum and hauler.Throttle == 0 and hauler.Steer == 0,
	"A new pilot inherited old input"
)
frames(30)
check(chassis.Drive.PlaneVelocity == R.Vector2.zero, "A new pilot's machine moved on its own")
check(#handovers() == 2 and handovers()[2]:find("Second", 1, true), "The new pilot's failed hand-over didn't warn")

-- Taken: the Drive prompt won't seat someone else, or anyone busy, and only
-- the seat's occupant steers it (a stale SeatPart is not enough).
local moleHum
check(not Vehicles.sit(pilot, hauler.Seat), "Two pilots in one seat")
local stale, staleHum = makePlayer("Stale")
staleHum.SeatPart = hauler.Seat
check(not Vehicles.input(stale, 1, 0) and hauler.Throttle == 0, "Someone who isn't the occupant steered the machine")
pilot.Attributes.Expedition = true
check(not Vehicles.sit(pilot, mole.Seat), "Boarded while on an expedition")
pilot.Attributes.Expedition = nil
check(Vehicles.sit(pilot, mole.Seat), "Couldn't board the free machine")
moleHum = pilotHum
check(
	mole.Seat.Occupant == moleHum and mole.Model.PrimaryPart.Owner == pilot,
	"Second machine wasn't handed to its pilot"
)

-- An anchored machine (mid reset) isn't driven.
mole.Model.PrimaryPart.Anchored = true
mole.Model.PrimaryPart.Owner = nil
Vehicles.input(pilot, 1, 0)
frames(30)
check(mole.Model.PrimaryPart.Drive.PlaneVelocity == R.Vector2.zero, "The server drove an anchored machine")

-- Diagnostics --------------------------------------------------------------------------

-- A pilot whose client never starts driving is logged, once.
mole.Model.PrimaryPart.Anchored = false
getOut(mole.Seat, pilotHum)
hold = nil
Vehicles.input(second, 0, 0) -- (the hauler's pilot says hello)
local quiet, quietHum = makePlayer("Quiet")
local moleChassis = mole.Model.PrimaryPart
check(Vehicles.sit(quiet, mole.Seat), "Couldn't board for the silent check")
local before = #notes
frames(60 * 4)
check(#notes == before, "Logged a silent client too soon")
frames(60 * 2)
local last = notes[#notes]
check(
	#notes == before + 1 and last.Message:find("no word", 1, true) and last.Detail:find("Quiet", 1, true),
	"A client that never started driving wasn't logged"
)
check(warnings[#warnings]:find("Quiet", 1, true) ~= nil, "The silent client wasn't in the Output")
frames(60 * 10)
check(#notes == before + 1, "The silent client was logged again")
getOut(mole.Seat, quietHum)

-- A client that says hello isn't.
check(Vehicles.sit(quiet, mole.Seat), "Couldn't reboard")
check(Vehicles.input(quiet, 0, 0), "The hello was refused")
frames(60 * 6)
check(#notes == before + 1, "A client that said hello was logged as silent")

-- A stuck report: the server frees what's anchored in the mech or the pilot
-- (nothing else), takes the physics, drives, and logs both sides' view.
quiet.Root.Anchored = true
joinPart(mole, quiet.Root)
local boulder = { Name = "Boulder", Anchored = true }
function boulder:IsDescendantOf()
	return false
end
function boulder:GetFullName()
	return "Workspace.Boulder"
end
joinPart(mole, boulder)
check(moleChassis.Owner == quiet, "The pilot didn't hold the physics before the report")
check(not Vehicles.report(quiet, 5), "A report that isn't text was taken")
check(not Vehicles.report(other, "stuck"), "Someone on foot filed a stuck report")
before = #notes
mechReport.OnServerEvent:Fire(quiet, "input 1.00/0.00 from keys")
last = notes[#notes]
check(#notes == before + 1 and last.Message:find("won't move", 1, true), "The stuck report wasn't logged")
check(
	last.Detail:find("Client: input 1.00/0.00 from keys", 1, true) and last.Detail:find("physics pilot", 1, true),
	"The log lacks the client's or the server's view"
)
check(
	last.Detail:find("Workspace.Quiet.HumanoidRootPart", 1, true) and last.Detail:find("Workspace.Boulder", 1, true),
	"The log didn't list what was anchored"
)
check(
	not quiet.Root.Anchored and last.Detail:find("unanchored HumanoidRootPart", 1, true),
	"The pilot's anchored body wasn't freed"
)
check(boulder.Anchored, "Unanchored something that isn't the mech's or the pilot's")
check(
	moleChassis.Owner == nil and mole.ServerOnly and last.Detail:find("physics moved to the server", 1, true),
	"The server didn't take the physics back"
)
check(warnings[#warnings]:find("won't move", 1, true) ~= nil, "The stuck report wasn't in the Output")
press(quiet, 1, 0)
frames(60 * 5)
check(moleChassis.Owner == nil, "The physics went back to the pilot mid-ride")
check(moleChassis.Drive.PlaneVelocity.Magnitude > 10, "The server didn't drive after taking over")
moleChassis.Owner = quiet -- (if the physics ever drifts back to the pilot's client)
frames(5)
check(mole.ServerDriving and moleChassis.Owner == quiet, "The server let go of a mech it took over")
moleChassis.Owner = nil
check(Vehicles.report(quiet, "again"), "A second report was refused")
check(notes[#notes].Detail:find("nothing left to try", 1, true) ~= nil, "A second report claimed to fix something")
check(Vehicles.report(quiet, "third"), "A third report was refused")
check(not Vehicles.report(quiet, "fourth"), "Took more than three reports in one ride")
local long = string.rep("x", 5000)
getOut(mole.Seat, quietHum)
hold = nil

-- The next ride starts fresh: the pilot gets the physics, and may report again.
check(
	Vehicles.sit(quiet, mole.Seat) and moleChassis.Owner == quiet and not mole.ServerOnly,
	"A new ride didn't hand the physics to the pilot again"
)
check(Vehicles.report(quiet, long), "A new ride couldn't report")
check(#notes[#notes].Detail < 1200, "A long report wasn't cut short")

print("PASS: " .. checks .. " outpost vehicle checks")
