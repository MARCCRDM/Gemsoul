-- Server-moved mechs (Server OutpostVehicles): the pilot's input moving the
-- anchored mech along the ground (up a kerb, down a drop, stopped by a rock,
-- a ledge, a gap and the crater rim), getting in and out, an abandoned mech
-- going home, and the diagnostics. The real module and drive maths, with
-- stand-ins for the seats and the world it moves through; run by
-- tests/run_outpost_vehicles.py with Lune or the bundled Luau runtime.
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

-- A part whose Position follows its CFrame, as a real one's does.
local function newPart(data)
	return setmetatable({}, {
		__index = function(_, k)
			if k == "Position" then
				return data.CFrame.Position
			end
			return data[k]
		end,
		__newindex = data,
	})
end

-- A mech as OutpostMachines builds one (at scale 1): the chassis at the
-- root with its bottom on the ground, and the hull from 1.6 studs up (what
-- it bumps into; the foot ball under it takes the kerbs).
local function makeMachine(kind, bay)
	local chassis = newPart({
		Name = "Chassis",
		Anchored = false,
		Size = R.Vector3.new(7.6, 12, 6.2),
		CFrame = bay * R.CFrame.new(0, 6.2, 0),
	})
	local hull = setmetatable({ Name = "Hull", Size = R.Vector3.new(7.6, 12 - 1.6, 6.2) }, {
		__index = function(_, k)
			if k == "CFrame" then
				return chassis.CFrame * R.CFrame.new(0, 0.8, 0)
			end
			return nil
		end,
	})
	local seat = {
		Occupant = nil,
		Children = {},
		Changed = signal(),
		ChildAdded = signal(),
		ChildRemoved = signal(),
		Kind = kind,
		Attributes = {},
	}
	function seat:SetAttribute(k, v)
		self.Attributes[k] = v
	end
	function seat:GetAttribute(k)
		return self.Attributes[k]
	end
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
	local model = { Name = kind, PrimaryPart = chassis, Seat = seat, Hull = hull, Attributes = {}, Sets = 0 }
	function model:FindFirstChild(name)
		return if name == "Seat" then self.Seat elseif name == "Hull" then self.Hull else nil
	end
	function model:GetAttribute(k)
		return self.Attributes[k]
	end
	function model:SetAttribute(k, v)
		self.Sets += 1
		self.Attributes[k] = v
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
	local player = { Name = name, Attributes = { Outpost = true }, Children = {} }
	function player:FindFirstChild(k)
		return self.Children[k]
	end
	function player:GetAttribute(k)
		return self.Attributes[k]
	end
	local humanoid = { Health = 100, SeatPart = nil }
	local character = { Player = player, Humanoid = humanoid }
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then self.Humanoid else nil
	end
	function character:FindFirstChild()
		return nil
	end
	humanoid.Parent = character
	player.Character = character
	return player, humanoid
end
local function getOut(seat, humanoid)
	seat.Occupant = nil
	humanoid.SeatPart = nil
	seat.Changed:Fire()
end

-- The world the mechs move through: the quarry floor at y = 0, with areas
-- raised, sunk or cut away, and rocks in the way. The module's own sweep and
-- floor (Blockcast and Raycast) are replaced with these.
local areas = {} -- { X = { min, max }, Z = { min, max }, Y = its height, or Cut = true: no floor }
local rocks = {} -- { Name, X, Z, Radius, Top }
local function inside(area, x, z)
	return x >= area.X[1] and x <= area.X[2] and z >= area.Z[1] and z <= area.Z[2]
end
-- Like a ray down from `top`: the highest surface at or below it (one it
-- starts inside doesn't count, as with a real ray).
local function surfaceAt(x, z, top)
	local best = if top >= 0 then 0 else nil
	for _, area in areas do
		if inside(area, x, z) and area.Cut then
			best = nil
		end
	end
	for _, area in areas do
		if inside(area, x, z) and area.Y and area.Y <= top and (best == nil or area.Y > best) then
			best = area.Y
		end
	end
	return best
end
local sweeps, lastSweep = 0, nil
local function sweep(_, from, size, direction)
	sweeps += 1
	lastSweep = { From = from, Size = size, Direction = direction }
	local start = from.Position
	local bottom = start.Y - size.Y / 2
	local reach = size.Z / 2 -- (the hull's front, near enough)
	local length = direction.Magnitude
	local ux, uz = direction.X / length, direction.Z / length
	local best, name = nil, nil
	for _, rock in rocks do
		-- (Lower than the hull's bottom, it passes under: the foot takes it.)
		if rock.Top > bottom then
			local dx, dz = rock.X - start.X, rock.Z - start.Z
			local r = rock.Radius + reach
			local b = dx * ux + dz * uz
			local c = dx * dx + dz * dz - r * r
			-- (A cast doesn't see what it starts inside.)
			if c > 0 and b * b - c >= 0 then
				local t = b - math.sqrt(b * b - c)
				if t >= 0 and t <= length and (best == nil or t < best) then
					best, name = t, rock.Name
				end
			end
		end
	end
	return best, name
end
local function floor(_, origin, length)
	local y = surfaceAt(origin.X, origin.Z, origin.Y)
	return if y and y >= origin.Y - length then y else nil
end

local clockNow = 1000
local warnings = {}
local Players = {}
function Players:GetPlayerFromCharacter(character)
	return character and character.Player
end
function Players:GetPlayers()
	return {}
end
local promptTriggered = signal()
local mechInput = { OnServerEvent = signal() }
local echoed = {}
local mechReport = {
	OnServerEvent = signal(),
	FireClient = function(_, player, detail)
		table.insert(echoed, { Player = player, Detail = detail })
	end,
}
local mechExit = { OnServerEvent = signal() }
local detached = 0
local notes = {}
local heartbeat = signal()
local Rules = load("src/shared/Outpost.luau", { CFrame = R.CFrame, Color3 = R.Color3 })
local modules = {
	Rules = { Module = Rules },
	Remotes = { Module = { MechInput = mechInput, MechReport = mechReport, MechExit = mechExit } },
	SeatExit = {
		Module = {
			detach = function(character, seat)
				detached += 1
				local hum = character:FindFirstChildOfClass("Humanoid")
				seat = seat or hum.SeatPart
				seat.Children.SeatWeld = nil
				getOut(seat, hum)
			end,
		},
	},
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
	ReplicatedStorage = {
		Shared = { Outpost = modules.Rules, Seating = { Module = load("src/shared/Seating.luau", {}) } },
	},
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
			SeatExit = modules.SeatExit,
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
Vehicles.sweep, Vehicles.floor = sweep, floor

local function near(a, b, within)
	return math.abs(a - b) <= (within or 1e-3)
end
local function same(a, b)
	return a ~= nil and b ~= nil and (a - b).Magnitude < 1e-6
end
local function yawOf(part)
	local _, yaw = part.CFrame:ToOrientation()
	return yaw
end

-- Boarding -------------------------------------------------------------------------------
local origin = Rules.Location.Position
local site = {
	Model = {},
	Parking = {
		{ Kind = "Hauler", CFrame = R.CFrame.new(origin.X, origin.Y, origin.Z) },
		{
			Kind = "Mole",
			CFrame = R.CFrame.new(origin.X + 40, origin.Y, origin.Z) * R.CFrame.Angles(0, math.rad(90), 0),
		},
	},
}
Vehicles.start(site)
local hauler, mole = Vehicles._machines[1], Vehicles._machines[2]
check(hauler and mole and #Vehicles._machines == 2, "Machines were not parked")
check(mechInput.OnServerEvent:Count() == 1 and heartbeat:Count() == 1, "Pilot input or the drive step isn't wired up")
check(mechReport.OnServerEvent:Count() == 1, "Stuck reports aren't wired up")
local chassis = hauler.Model.PrimaryPart
local moleChassis = mole.Model.PrimaryPart
check(chassis.Anchored and moleChassis.Anchored, "A parked mech isn't anchored (the server moves it)")
check(same(hauler.Model:GetAttribute("MechPosition"), chassis.Position), "A parked mech didn't say where it is")
check(
	near(mole.Yaw, math.rad(90)) and near(mole.Model:GetAttribute("MechMotion").X, math.rad(90)),
	"A parked mech lost its heading"
)
local prompt = hauler.Seat:FindFirstChild("DrivePrompt")
check(prompt and prompt:GetAttribute("PromptKind") == "Drive" and prompt.Enabled, "No Drive prompt on the seat")

-- A parked mech sends nothing: no attribute churn, frame after frame.
local sets = hauler.Model.Sets
for _ = 1, 30 do
	heartbeat:Fire(1 / 60)
end
check(hauler.Model.Sets == sets, "A parked mech kept re-sending where it is")

local pilot, pilotHum = makePlayer("Pilot")
promptTriggered:Fire(prompt, pilot)
check(hauler.Seat.Occupant == pilotHum and not prompt.Enabled, "The Drive prompt didn't seat the pilot")
check(pilot:FindFirstChild("PilotedMechSeat").Value == hauler.Seat, "Pilot has no replicated seat discovery reference")

-- Input moves it, with nothing from the client but the input.
local home = chassis.Position
mechInput.OnServerEvent:Fire(pilot, 1, 0)
local inputAt = hauler.InputAt
Vehicles.seated(hauler) -- SeatWeld notification following Occupant
check(
	hauler.Heard and hauler.Throttle == 1 and hauler.InputAt == inputAt,
	"Duplicate boarding event erased accepted input"
)
check(hauler.Seat:GetAttribute("MechInputThrottle") == 1, "Accepted input was not acknowledged")
heartbeat:Fire(1 / 60)
check(hauler.ServerDriving and chassis.Position.Z < home.Z, "The first frame of input didn't move the mech")
getOut(hauler.Seat, pilotHum)
check(pilot:FindFirstChild("PilotedMechSeat").Value == nil, "Seat discovery reference survived exit")
check(Vehicles.sit(pilot, hauler.Seat), "Couldn't get back in")

-- While a key is held the client re-sends it every 0.5 s (Client VehicleDrive).
local hold = nil
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
	end
end
-- Put a mech somewhere, standing still and facing `yaw` (as if it had driven there).
local function place(machine, x, z, yaw, y)
	machine.Model.PrimaryPart.CFrame = R.CFrame.new(x, (y or 0) + 6.2, z) * R.CFrame.Angles(0, yaw, 0)
	machine.Yaw, machine.Speed, machine.Fall = yaw, 0, 0
end

-- Driving --------------------------------------------------------------------------------
local start = chassis.Position
frames(10)
check(same(chassis.Position, start), "The mech moved without any input")
check(press(pilot, 1, 0), "The pilot's input was refused")
frames(60 * 4)
local spec = Rules.Machines.Hauler
check(near(hauler.Speed, spec.MaxSpeed), "The mech didn't reach top speed")
check(chassis.Position.Z < start.Z - 50, "The mech never got anywhere")
check(near(chassis.Position.X, start.X) and near(chassis.Position.Y, 6.2), "Driving straight on the flat wandered off")
check(chassis.Anchored, "Driving unanchored the mech")
check(same(hauler.Model:GetAttribute("MechPosition"), chassis.Position), "Clients weren't told where it is")
local motion = hauler.Model:GetAttribute("MechMotion")
check(
	near(motion.Y, spec.MaxSpeed) and hauler.Model:GetAttribute("MechBlocked") == nil,
	"Clients weren't told its speed"
)
-- It's the hull that's swept, from above the step height: not the chassis,
-- whose flat bottom would catch on every kerb.
check(sweeps > 0 and lastSweep ~= nil, "Nothing checked the way ahead")
check(near(lastSweep.From.Position.Y, chassis.Position.Y + 0.8), "The sweep didn't start from the hull")
check(near(lastSweep.Size.Y, 10.2, 0.01), "The sweep isn't the hull's size")
check(lastSweep.Direction.Unit:Dot(R.Vector3.new(0, 0, -1)) > 0.999, "The sweep looked the wrong way")

-- Steering, from where the mech actually points.
press(pilot, 0, 1)
frames(30)
check(hauler.Yaw < -0.2 and near(yawOf(chassis), hauler.Yaw), "Steering didn't turn the mech")
check(hauler.Model:GetAttribute("MechMotion").Z < 0, "Clients weren't told it's turning")

-- A rock: it stops short of it, says so, and turns away and goes on.
place(hauler, 0, 6900, 0)
rocks = { { Name = "Boulder", X = 0, Z = 6870, Radius = 4, Top = 8 } }
press(pilot, 1, 0)
frames(60 * 3)
check(
	near(chassis.Position.Z, 6870 + 4 + 3 + 0.4, 0.05),
	"Drove into the rock, or stopped short: " .. chassis.Position.Z
)
check(
	hauler.Blocked == "Boulder" and hauler.Model:GetAttribute("MechBlocked") == "Boulder",
	"Didn't say what's in the way"
)
check(hauler.Speed == 0 and hauler.Model:GetAttribute("MechMotion").Y == 0, "Kept pushing into the rock")
press(pilot, 0, 1)
frames(60 * 2)
press(pilot, 1, 0)
local stopped = chassis.Position
frames(60)
check((chassis.Position - stopped).Magnitude > 5 and hauler.Blocked == nil, "Couldn't drive away from the rock")
-- A rock low enough to step over isn't in the way.
place(hauler, 0, 6900, 0)
rocks = { { Name = "Pebble", X = 0, Z = 6880, Radius = 2, Top = 1 } }
frames(60 * 2)
check(chassis.Position.Z < 6878 and hauler.Blocked == nil, "A pebble stopped the mech")
rocks = {}

-- A kerb: it steps up. Off the far side: it drops, falling.
place(hauler, 0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6850, 6885 }, Y = 1.2 } }
frames(60 * 2)
local z = chassis.Position.Z
check(z < 6885 and z > 6850 and near(chassis.Position.Y, 7.4), "Didn't step up the kerb")
frames(60 * 2)
check(chassis.Position.Z < 6850 and near(chassis.Position.Y, 6.2) and hauler.Fall == 0, "Didn't step back down off it")
-- A ledge too high to step up: it stops at the foot of it.
place(hauler, 0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6850, 6885 }, Y = 1.8 } }
frames(60 * 2)
check(chassis.Position.Z > 6885 and chassis.Position.Z < 6890, "Climbed a ledge too high, or stopped short of it")
check(hauler.Blocked == "a ledge" and near(chassis.Position.Y, 6.2), "Didn't say a ledge was in the way")
-- A pit: it drives off the edge and falls in, under gravity.
place(hauler, 0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6800, 6890 }, Cut = true }, { X = { -50, 50 }, Z = { 6800, 6890 }, Y = -8 } }
local fell, lowest = false, math.huge
for _ = 1, 60 * 2 do
	frames(1)
	local y = chassis.Position.Y
	if y < 6.2 - 0.01 and y > -1.8 + 0.01 then
		fell = true
	end
	lowest = math.min(lowest, y)
end
check(fell and near(lowest, -1.8) and near(chassis.Position.Y, -1.8), "Didn't fall into the pit, or fell through it")
check(hauler.Fall == 0 and chassis.Position.Z < 6890, "Didn't land in the pit")
-- No ground at all: it won't go.
place(hauler, 0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6800, 6890 }, Cut = true } }
frames(60 * 2)
check(chassis.Position.Z > 6890 and hauler.Blocked == "no ground", "Drove off into nothing")
areas = {}
-- The crater rim.
place(hauler, origin.X, origin.Z - Rules.Radius - 30, 0)
frames(60 * 3)
local out = chassis.Position - origin
check(R.Vector3.new(out.X, 0, out.Z).Magnitude <= Rules.Radius + 40 + 0.01, "Drove out over the crater rim")
check(hauler.Blocked == "the crater rim", "Didn't say the rim is in the way")
place(hauler, 0, 6950, 0)
frames(5)
check(hauler.Blocked == nil, "Still blocked after driving away")

-- Input that stops arriving counts as let go.
hold = nil
frames(60 * 3)
check(hauler.Speed < 1, "A lost connection left the mech driving")
local resting = chassis.Position
frames(30)
check((chassis.Position - resting).Magnitude < 0.5, "A mech kept rolling with no input")
press(pilot, 1, 0)
frames(60)
check(hauler.Speed > 5, "Fresh input didn't drive again")

-- Only the pilot steers, and only with sane numbers.
local other = makePlayer("Other")
check(not Vehicles.input(other, -1, 0), "Someone on foot steered another player's mech")
for _, bad in { { 0 / 0, 0 }, { math.huge, 0 }, { 0, -math.huge }, { "1", 0 }, { nil, 0 }, { {}, 1 } } do
	check(not Vehicles.input(pilot, bad[1], bad[2]), "Bad input was accepted: " .. tostring(bad[1]))
end
check(hauler.Throttle == 1 and hauler.Steer == 0, "Bad input changed the controls")
check(Vehicles.input(pilot, 9, -9) and hauler.Throttle == 1 and hauler.Steer == -1, "Out-of-range input wasn't clamped")
Vehicles.input(pilot, 1, 0)

-- Busy elsewhere: the mech stops.
pilot.Attributes.CombatSession = "Duel"
press(pilot, 1, 0)
frames(60 * 3)
check(hauler.Speed < 1, "A pilot in a fight kept driving")
pilot.Attributes.CombatSession = nil

-- Reboarding picks up the actual heading, not an earlier ride's heading.
getOut(hauler.Seat, pilotHum)
chassis.CFrame = R.CFrame.new(chassis.Position) * R.CFrame.Angles(0, 1.2, 0)
Vehicles.sit(pilot, hauler.Seat)
press(pilot, 0, 0)
frames(1)
check(near(hauler.Yaw, 1.2, 0.05) and near(yawOf(chassis), 1.2, 0.05), "Reboarding snapped back to an old heading")

-- Getting out: it stops where it is, and the prompt comes back.
press(pilot, 1, 0)
frames(30)
getOut(hauler.Seat, pilotHum)
hold = nil
check(hauler.Speed == 0 and hauler.Model:GetAttribute("MechMotion").Y == 0, "An empty mech kept driving")
check(prompt.Enabled and chassis.Anchored, "An empty mech wasn't parked")
local parked = chassis.Position
frames(30)
check(same(chassis.Position, parked), "An empty mech moved")
check(not Vehicles.input(pilot, 1, 0), "Input from someone who got out was accepted")

-- A new pilot starts from rest, not from the last pilot's input.
local second, secondHum = makePlayer("Second")
promptTriggered:Fire(prompt, second)
check(
	hauler.Seat.Occupant == secondHum and hauler.Throttle == 0 and hauler.Steer == 0,
	"A new pilot inherited old input"
)
frames(30)
check(same(chassis.Position, parked), "A new pilot's mech moved on its own")
local idle = hauler.Model.Sets
frames(30)
check(hauler.Model.Sets == idle, "A mech standing still kept re-sending where it is")

-- Taken: the Drive prompt won't seat someone else, or anyone busy, and only
-- the seat's occupant steers it (a stale SeatPart is not enough).
check(not Vehicles.sit(pilot, hauler.Seat), "Two pilots in one seat")
local stale, staleHum = makePlayer("Stale")
staleHum.SeatPart = hauler.Seat
check(not Vehicles.input(stale, 1, 0) and hauler.Throttle == 0, "Someone who isn't the occupant steered the mech")
pilot.Attributes.Expedition = true
check(not Vehicles.sit(pilot, mole.Seat), "Boarded while on an expedition")
pilot.Attributes.Expedition = nil
check(Vehicles.sit(pilot, mole.Seat) and mole.Seat.Occupant == pilotHum, "Couldn't board the free mech")

-- The Mole drives the way it faces (90 degrees: -X), and if anything ever
-- unanchors it, it's anchored again.
local moleStart = moleChassis.Position
moleChassis.Anchored = false
press(pilot, 1, 0)
frames(60 * 2)
check(moleChassis.Anchored, "An unanchored mech wasn't anchored again")
check(
	moleChassis.Position.X < moleStart.X - 15 and near(moleChassis.Position.Z, moleStart.Z, 0.01),
	"The Mole didn't drive the way it faces"
)

-- Getting out mid-fall: it still lands.
place(mole, moleChassis.Position.X, moleChassis.Position.Z, mole.Yaw, 5)
mole.Fall = 0.1
getOut(mole.Seat, pilotHum)
hold = nil
frames(60)
check(near(moleChassis.Position.Y, 6.2) and mole.Fall == 0, "An empty mech hung in the air")

-- Abandoned away from its bay, it goes home; out of the world, at once.
local moleBay = mole.Bay.Position
Vehicles.tidy(clockNow + Rules.MachineResetSeconds - 5)
check((moleChassis.Position - moleBay).Magnitude > 12, "Went home too soon")
Vehicles.tidy(clockNow + Rules.MachineResetSeconds + 5)
check(
	near((moleChassis.Position - moleBay).Magnitude, 6.2, 0.01) and near(yawOf(moleChassis), math.rad(90)),
	"An abandoned mech didn't go home"
)
check(
	moleChassis.Anchored and same(mole.Model:GetAttribute("MechPosition"), moleChassis.Position),
	"Going home didn't tell the clients"
)
place(mole, moleBay.X, moleBay.Z, mole.Yaw, -100)
Vehicles.tidy(clockNow)
check(near(moleChassis.Position.Y, 6.2), "A mech out of the world stayed there")

-- Diagnostics --------------------------------------------------------------------------

-- A pilot whose client never starts driving is logged, once.
Vehicles.input(second, 0, 0) -- (the hauler's pilot says hello)
local quiet, quietHum = makePlayer("Quiet")
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
check(
	echoed[#echoed].Player == quiet and echoed[#echoed].Detail:find("anchored true", 1, true),
	"The silent pilot wasn't told the server's view"
)
frames(60 * 10)
check(#notes == before + 1, "The silent client was logged again")
getOut(mole.Seat, quietHum)

-- A client that says hello isn't.
check(Vehicles.sit(quiet, mole.Seat), "Couldn't reboard")
check(Vehicles.input(quiet, 0, 0), "The hello was refused")
frames(60 * 6)
check(#notes == before + 1, "A client that said hello was logged as silent")

-- A stuck report: logged with both sides' view, and for a moment the mech
-- drives through whatever it's wedged in.
place(mole, moleBay.X, moleBay.Z, math.rad(90))
rocks = { { Name = "Wedge", X = moleBay.X - 7.4, Z = moleBay.Z, Radius = 4, Top = 8 } }
press(quiet, 1, 0)
frames(60)
check(mole.Blocked == "Wedge" and near(moleChassis.Position.X, moleBay.X, 0.05), "The rock didn't stop the Mole")
check(not Vehicles.report(quiet, 5), "A report that isn't text was taken")
check(not Vehicles.report(other, "stuck"), "Someone on foot filed a stuck report")
before = #notes
mechReport.OnServerEvent:Fire(quiet, "input 1.00/0.00 from keys")
last = notes[#notes]
check(#notes == before + 1 and last.Message:find("won't move", 1, true), "The stuck report wasn't logged")
check(
	last.Detail:find("Client: input 1.00/0.00 from keys", 1, true) and last.Detail:find("blocked by Wedge", 1, true),
	"The log lacks the client's or the server's view"
)
check(
	echoed[#echoed].Player == quiet and echoed[#echoed].Detail:find("blocked by Wedge", 1, true),
	"Server view wasn't returned to the pilot"
)
check(warnings[#warnings]:find("won't move", 1, true) ~= nil, "The stuck report wasn't in the Output")
local sweepsBefore = sweeps
frames(60)
check(moleChassis.Position.X < moleBay.X - 5 and sweeps == sweepsBefore, "A stuck report didn't free the mech")
frames(60)
check(sweeps > sweepsBefore, "It never went back to checking the way ahead")
rocks = {}
check(Vehicles.report(quiet, "again") and Vehicles.report(quiet, "third"), "A second or third report was refused")
check(not Vehicles.report(quiet, "fourth"), "Took more than three reports in one ride")
getOut(mole.Seat, quietHum)
hold = nil

-- The next ride starts fresh, and may report again.
check(Vehicles.sit(quiet, mole.Seat), "Couldn't board again")
check(Vehicles.report(quiet, string.rep("x", 5000)), "A new ride couldn't report")
check(#notes[#notes].Detail < 1200, "A long report wasn't cut short")

check(not Vehicles.exit(other), "Non-pilot could exit another player's mech")
press(quiet, 1, 0)
frames(30)
mechExit.OnServerEvent:Fire(quiet)
check(detached == 1 and mole.Seat.Occupant == nil, "Jump did not detach the pilot on the server")
check(mole.Speed == 0 and mole.Model:GetAttribute("MechMotion").Y == 0, "Exiting kept the mech moving")
hold = nil

-- Seat.Occupant and Humanoid.SeatPart don't replicate, so the side that
-- didn't seat someone can see either one empty. The pilot is still found,
-- from whichever is there or from the seat weld itself (Shared.Seating).
getOut(hauler.Seat, secondHum)
local lone, loneHum = makePlayer("Lone")
check(Vehicles.sit(lone, hauler.Seat), "Couldn't board for the replication checks")
loneHum.SeatPart = nil -- (the seat's Occupant only)
check(press(lone, 1, 0), "Input refused with only the seat's Occupant to go on")
local from = chassis.Position
frames(60)
check((chassis.Position - from).Magnitude > 5, "Didn't drive with only the seat's Occupant")
-- The weld only: neither Occupant nor SeatPart.
local loneRoot = { Name = "HumanoidRootPart", Parent = lone.Character }
function lone.Character:FindFirstChild(name)
	return if name == "HumanoidRootPart" then loneRoot else nil
end
local weld = { Name = "SeatWeld", Part0 = hauler.Seat, Part1 = loneRoot }
function loneRoot:GetJoints()
	return if hauler.Seat.Children.SeatWeld then { weld } else {}
end
hauler.Seat.Children.SeatWeld = weld
hauler.Seat.Occupant = nil
check(press(lone, 1, 0), "Input refused with only the seat weld to go on")
from = chassis.Position
frames(60)
check((chassis.Position - from).Magnitude > 5 and hauler.ServerDriving, "Didn't drive with only the seat weld")
check(not Vehicles.sit(other, hauler.Seat), "Seated someone over a pilot only the weld shows")
check(Vehicles.report(lone, "weld only"), "A pilot only the weld shows couldn't report")
check(Vehicles.exit(lone) and detached == 2, "A pilot only the weld shows couldn't get out")
hold = nil
check(not Vehicles.input(lone, 1, 0), "Input taken after getting out")
from = chassis.Position
frames(30)
check(same(chassis.Position, from), "The mech kept going after its pilot got out")
-- A SeatWeld child can arrive before Part1, with no second child/Occupant event.
local delayed = makePlayer("Delayed")
local delayedRoot = { Parent = delayed.Character }
local delayedWeld = { Name = "SeatWeld", Part0 = hauler.Seat }
hauler.Seat.Children.SeatWeld = delayedWeld
hauler.Seat.ChildAdded:Fire(delayedWeld)
check(delayed:FindFirstChild("PilotedMechSeat") == nil, "Incomplete weld assigned a pilot")
delayedWeld.Part1 = delayedRoot
heartbeat:Fire(1 / 60)
check(delayed:FindFirstChild("PilotedMechSeat").Value == hauler.Seat, "Late weld endpoint never registered the pilot")
check(Vehicles.input(delayed, 1, 0), "Late weld pilot couldn't drive")
from = chassis.Position
heartbeat:Fire(1 / 60)
check(not same(chassis.Position, from), "Late weld registration erased input")
hauler.Seat.Children.SeatWeld = nil
heartbeat:Fire(1 / 60)
check(delayed:FindFirstChild("PilotedMechSeat").Value == nil, "Heartbeat left the late-weld pilot reference behind")
hauler.Seat.Children.SeatWeld = delayedWeld
check(Vehicles.input(delayed, 1, 0), "Input arriving before the boarding heartbeat was refused")
heartbeat:Fire(1 / 60)
check(hauler.Throttle == 1 and hauler.Heard, "Boarding reconciliation erased an early input")
print(
	"PASS: " .. checks .. " outpost vehicle checks (driving, kerbs, ledges, drops, rocks, the rim, seats, diagnostics)"
)
