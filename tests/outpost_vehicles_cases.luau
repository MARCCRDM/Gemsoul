-- The mechs on the server (Server OutpostVehicles), with no Roblox seats:
-- parking, getting in (the Pilot prompt: MechPilot on the player, a weld in
-- the cockpit), the pilot's screen's moves checked and passed on (only its
-- pilot, no faster than it goes, inside the rim), getting out and being let
-- go (leaving, dying, respawning, getting busy, SeatExit), going home, and
-- the diagnostics. Stand-ins for the world; run by
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
local function attributes(object)
	object.Attributes = object.Attributes or {}
	function object:SetAttribute(k, v)
		self.Attributes[k] = v
	end
	function object:GetAttribute(k)
		return self.Attributes[k]
	end
	return object
end

-- An instance: its children by Parent, and Destroy.
local function newInstance(class)
	local data = attributes({ ClassName = class, Enabled = true, Children = {}, Destroyed = false })
	local proxy = {}
	function data.GetChildren()
		local list = {}
		for child in data.Children do
			table.insert(list, child)
		end
		return list
	end
	function data.Destroy()
		data.Destroyed = true
		proxy.Parent = nil
	end
	return setmetatable(proxy, {
		__index = data,
		__newindex = function(_, k, v)
			if k == "Parent" then
				local old = data.Parent
				if type(old) == "table" and old.Children then
					old.Children[proxy] = nil
				end
				if type(v) == "table" and v.Children then
					v.Children[proxy] = true
				end
			end
			data[k] = v
		end,
	})
end

-- A part whose Position follows its CFrame.
local function newPart(fields)
	local part = newInstance("Part")
	for k, v in fields do
		part[k] = v
	end
	return setmetatable({}, {
		__index = function(_, k)
			if k == "Position" then
				return part.CFrame.Position
			end
			return part[k]
		end,
		__newindex = part,
	})
end

-- A mech as OutpostMachines builds one (at scale 1): the chassis at the root
-- with its bottom on the ground, and the cockpit up in its torso.
local built = {}
local function makeMachine(kind, bay)
	local model = attributes({ Name = kind, Pivots = 0 })
	local chassis = newPart({
		Name = "Chassis",
		Anchored = false,
		Size = R.Vector3.new(7.6, 12, 6.2),
		CFrame = bay * R.CFrame.new(0, 6.2, 0),
	})
	local cockpit = setmetatable({}, {
		__index = function(_, k)
			if k == "Position" then
				return (chassis.CFrame * R.CFrame.new(0, 5, 0)).Position
			end
			return chassis.__cockpit[k]
		end,
	})
	chassis.__cockpit = newInstance("Part")
	chassis.__cockpit.Name, chassis.__cockpit.Size = "Cockpit", R.Vector3.new(2, 1, 2)
	model.PrimaryPart, model.Cockpit = chassis, cockpit
	function model:FindFirstChild(name)
		return if name == "Cockpit" then cockpit else nil
	end
	function model:PivotTo(cf)
		self.Pivots += 1
		chassis.CFrame = cf
	end
	table.insert(built, model)
	return model
end

local userIds = 0
local players = {}
local function makePlayer(name)
	userIds += 1
	local player = attributes({ Name = name, UserId = userIds, Parent = "Players", Children = {} })
	player.Attributes.Outpost = true
	function player:FindFirstChild(k)
		return self.Children[k]
	end
	local function body()
		local humanoid = { Health = 100, Sit = false, States = {} }
		function humanoid:ChangeState(state)
			table.insert(self.States, state)
		end
		local root = newPart({ Name = "HumanoidRootPart", CFrame = R.CFrame.new(0, 3, 7000) })
		root.AssemblyLinearVelocity = R.Vector3.zero
		local character = { Player = player, Humanoid = humanoid, Root = root, Pivots = {} }
		function character:FindFirstChildOfClass(class)
			return if class == "Humanoid" then self.Humanoid else nil
		end
		function character:FindFirstChild(k)
			return if k == "HumanoidRootPart" then self.Root else nil
		end
		function character:PivotTo(cf)
			-- (What holds the body when it's moved: a weld still on would drag the mech.)
			table.insert(self.Pivots, { CFrame = cf, Welded = player.Welded and player.Welded.Parent ~= nil })
			root.CFrame = cf
		end
		humanoid.Parent = character
		player.Character = character
	end
	body()
	player.Respawn = body
	table.insert(players, player)
	return player
end
local function near(player, part, offset)
	player.Character.Root.CFrame = R.CFrame.new(part.Position + (offset or R.Vector3.new(4, -4, 0)))
end

local clockNow = 1000
local warnings, prints = {}, {}
local Players = { PlayerRemoving = signal() }
function Players:GetPlayerFromCharacter(character)
	return character and character.Player
end
function Players:GetPlayers()
	return players
end
local promptTriggered = signal()
local mechMove = { OnServerEvent = signal() }
local echoed = {}
local mechReport = {
	OnServerEvent = signal(),
	FireClient = function(_, player, detail)
		table.insert(echoed, { Player = player, Detail = detail })
	end,
}
local mechExit = { OnServerEvent = signal() }
local notes = {}
local heartbeat = signal()
local tags = {}
local Rules = load("src/shared/Outpost.luau", { CFrame = R.CFrame, Color3 = R.Color3 })
local collection = {
	AddTag = function(_, object, tag)
		tags[object] = tag
	end,
	GetTagged = function(_, tag)
		local list = {}
		for object, t in tags do
			if t == tag then
				table.insert(list, object)
			end
		end
		return list
	end,
}
local MechPilot = load("src/shared/MechPilot.luau", {
	game = {
		GetService = function()
			return collection
		end,
	},
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
})
local modules = {
	Rules = { Module = Rules },
	MechPilot = { Module = MechPilot },
	Remotes = { Module = { MechMove = mechMove, MechReport = mechReport, MechExit = mechExit } },
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
	CollectionService = collection,
	ProximityPromptService = { PromptTriggered = promptTriggered },
	ReplicatedStorage = { Shared = { Outpost = modules.Rules, MechPilot = modules.MechPilot } },
	RunService = { Heartbeat = heartbeat },
}
local welds = {}
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
	Instance = {
		new = function(class)
			local object = newInstance(class)
			if class == "Weld" then
				table.insert(welds, object)
			end
			return object
		end,
	},
	Enum = R.Enum,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	os = setmetatable({
		clock = function()
			return clockNow
		end,
	}, { __index = os }),
	task = { spawn = function() end, wait = function() end },
	warn = function(...)
		table.insert(warnings, table.concat({ ... }, " "))
	end,
	print = function(...)
		table.insert(prints, table.concat({ ... }, " "))
	end,
})

local function same(a, b)
	return a ~= nil and b ~= nil and (a - b).Magnitude < 1e-3
end
local function yawOf(part)
	local _, yaw = part.CFrame:ToOrientation()
	return yaw
end

-- Parking ------------------------------------------------------------------------------------------
local origin = Rules.Location.Position
local site = {
	Model = {},
	Parking = {
		{ Kind = "Hauler", CFrame = R.CFrame.new(origin) },
		{
			Kind = "Mole",
			CFrame = R.CFrame.new(origin + R.Vector3.new(40, 0, 0)) * R.CFrame.Angles(0, math.rad(90), 0),
		},
	},
}
Vehicles.start(site)
local hauler, mole = Vehicles._machines[1], Vehicles._machines[2]
check(hauler and mole and #Vehicles._machines == 2, "The mechs weren't parked")
check(
	mechMove.OnServerEvent:Count() == 1 and mechExit.OnServerEvent:Count() == 1,
	"Moves or getting out aren't wired up"
)
check(mechReport.OnServerEvent:Count() == 1 and heartbeat:Count() == 1, "Reports or the step aren't wired up")
check(prints[#prints]:find("2 mechs parked", 1, true) ~= nil, "Parking wasn't logged")
local chassis, moleChassis = hauler.Model.PrimaryPart, mole.Model.PrimaryPart
check(chassis.Anchored and moleChassis.Anchored, "A parked mech isn't anchored")
check(hauler.Id == "Hauler1" and mole.Id == "Mole2", "Mech ids")
check(
	hauler.Model:GetAttribute("MechId") == "Hauler1" and hauler.Model:GetAttribute("MechKind") == "Hauler",
	"A mech doesn't say what it is"
)
check(MechPilot.find("Mole2") == mole.Model, "A mech can't be found by its id")
check(same(hauler.Model:GetAttribute("MechPosition"), chassis.Position), "A parked mech didn't say where it is")
check(
	math.abs(mole.Model:GetAttribute("MechMotion").X - math.rad(90)) < 1e-4,
	"A parked mech didn't say which way it faces"
)
local prompt = hauler.Prompt
check(prompt.Parent == hauler.Model.Cockpit, "The Pilot prompt isn't on the cockpit")
check(
	prompt:GetAttribute("PromptKind") == "Drive" and prompt.ActionText == "Pilot" and prompt.Enabled,
	"No Pilot prompt"
)

-- Getting in -----------------------------------------------------------------------------------------
local pilot = makePlayer("Pilot")
near(pilot, hauler.Model.Cockpit)
promptTriggered:Fire(prompt, pilot)
local weld = hauler.Weld
check(pilot:GetAttribute("MechPilot") == "Hauler1", "The prompt didn't make them its pilot")
check(MechPilot.of(pilot) == "Hauler1" and MechPilot.mech(pilot) == hauler.Model, "MechPilot doesn't see the pilot")
check(hauler.Model:GetAttribute("MechPilotId") == pilot.UserId, "The mech doesn't say who pilots it")
check(weld and weld.ClassName == "Weld" and weld.Name == "PilotWeld", "No weld holds the pilot")
check(
	weld.Part1 == pilot.Character.Root and weld.Parent == hauler.Model.Cockpit,
	"The weld doesn't hold the pilot in the cockpit"
)
check(pilot.Character.Humanoid.Sit and not prompt.Enabled, "Not sat, or the prompt still shows")
check(Vehicles.machineOf(pilot) == hauler, "The server doesn't know who pilots what")
check(prints[#prints]:find("Pilot is piloting Hauler1", 1, true) ~= nil, "Getting in wasn't logged")
pilot.Welded = weld

-- Not in: someone else into a taken mech, the pilot into a second, someone
-- busy, too far, or dead.
local other = makePlayer("Other")
near(other, hauler.Model.Cockpit)
check(not Vehicles.board(other, hauler), "Two pilots in one mech")
near(pilot, mole.Model.Cockpit)
check(not Vehicles.board(pilot, mole), "One pilot in two mechs")
near(other, mole.Model.Cockpit)
other.Attributes.Expedition = true
check(not Vehicles.board(other, mole), "Got in while on an expedition")
other.Attributes.Expedition = nil
other.Attributes.Outpost = nil
check(not Vehicles.board(other, mole), "Got in outside the Outpost")
other.Attributes.Outpost = true
near(other, mole.Model.Cockpit, R.Vector3.new(60, 0, 0))
check(not Vehicles.board(other, mole), "Got in from 60 studs away")
near(other, mole.Model.Cockpit)
other.Character.Humanoid.Health = 0
check(not Vehicles.board(other, mole), "A dead player got in")
other.Character.Humanoid.Health = 100
check(other:GetAttribute("MechPilot") == nil and mole.Pilot == nil, "A refused boarding left something behind")

-- Moves from the pilot's screen -------------------------------------------------------------------------
local spec = Rules.Machines.Hauler
local start = chassis.Position
local function move(player, at, yaw, speed, turn, dt)
	clockNow += dt or 1 / 15
	return Vehicles.move(player, at, yaw, speed or 0, turn or 0, clockNow)
end
-- Hello (where it stands): accepted, nothing moves.
check(move(pilot, start, 0, 0, 0), "The pilot's hello was refused")
check(same(chassis.Position, start), "The hello moved it")
-- Forward: it goes where it's put, and everyone is told.
local ahead = start + R.Vector3.new(0, 0, -1.5)
check(move(pilot, ahead, 0, 22, 0), "A move forward was refused")
check(same(chassis.Position, ahead) and chassis.Anchored, "The mech didn't go where its pilot put it")
check(same(hauler.Model:GetAttribute("MechPosition"), ahead), "Others weren't told where it is")
local motion = hauler.Model:GetAttribute("MechMotion")
check(math.abs(motion.Y - 22) < 1e-6 and motion.X == 0 and motion.Z == 0, "Others weren't told how it moves")
-- Turning: its heading is what the pilot says.
check(move(pilot, ahead, -0.6, 0, -1.1), "A turn was refused")
check(math.abs(yawOf(chassis) + 0.6) < 1e-4 and hauler.Model:GetAttribute("MechMotion").Z < 0, "It didn't turn")
local acceptedAt = clockNow
-- Only from its pilot, with real numbers.
local held = chassis.Position
check(not move(other, held + R.Vector3.new(0, 0, -1), 0, 10, 0), "Someone else moved the mech")
for _, bad in
	{
		{ "far", 0, 0, 0 },
		{ R.Vector3.new(0 / 0, 0, 0), 0, 0, 0 },
		{ R.Vector3.new(math.huge, 0, 0), 0, 0, 0 },
		{ held, 0 / 0, 0, 0 },
		{ held, 0, math.huge, 0 },
		{ held, 0, 0, "1" },
	}
do
	check(
		not Vehicles.move(pilot, bad[1], bad[2], bad[3], bad[4], clockNow),
		"A bad move was taken: " .. tostring(bad[1])
	)
end
check(same(chassis.Position, held), "A refused move moved it")
-- No further than it could have gone: a jump of 200 studs is cut short.
check(move(pilot, held + R.Vector3.new(0, 0, -200), 0, 22, 0), "A long move was refused outright")
local since = clockNow - acceptedAt -- (since the last move it took)
local went = (chassis.Position - held).Magnitude
check(
	went <= spec.MaxSpeed * since * 1.5 + 2 + 1e-3 and went > 1,
	"A long move wasn't cut to what it could do: " .. went
)
-- A burst of moves arriving together still goes (a little slack).
held = chassis.Position
for _ = 1, 5 do
	move(pilot, chassis.Position + R.Vector3.new(0, 0, -1.6), 0, 22, 0, 0)
end
check((chassis.Position - held).Magnitude > 7, "Moves arriving together were cut short")
-- Up no more than a step or two at once; down a drop freely.
held = chassis.Position
move(pilot, held + R.Vector3.new(0, 30, 0), 0, 0, 0)
check(chassis.Position.Y - held.Y <= 1.6 * 2 + 1 + 1e-3, "It rose 30 studs at once")
held = chassis.Position
move(pilot, held + R.Vector3.new(0, -20, 0), 0, 0, 0)
check(math.abs(chassis.Position.Y - (held.Y - 20)) < 1e-3, "It couldn't drop")
move(pilot, held, 0, 0, 0)
-- Never out of the world: below it, or past the crater rim.
held = chassis.Position
move(pilot, R.Vector3.new(held.X, origin.Y - 100, held.Z), 0, 0, 0)
check(math.abs(chassis.Position.Y - held.Y) < 1e-3, "It went below the world")
local limit = Rules.Radius + 40
chassis.CFrame = R.CFrame.new(origin + R.Vector3.new(0, 6.2, -(limit - 1)))
move(pilot, origin + R.Vector3.new(0, 6.2, -(limit + 5)), 0, 22, 0, 0.5)
local out = chassis.Position - origin
check(R.Vector3.new(out.X, 0, out.Z).Magnitude <= limit + 1e-3, "It went out over the crater rim")
chassis.CFrame = R.CFrame.new(start)
-- Not faster than it goes, nor turning wildly.
move(pilot, start, 0, 500, 99)
motion = hauler.Model:GetAttribute("MechMotion")
check(motion.Y == spec.MaxSpeed and motion.Z == 10, "A wild speed or turn was passed on")
-- Moves stop coming: it has stopped, for everyone's glide.
clockNow += 1.5
Vehicles.step(clockNow)
check(hauler.Model:GetAttribute("MechMotion").Y == 0, "A mech whose moves stopped kept going on others' screens")

-- Diagnostics: a pilot whose screen never moves it is logged, once.
near(other, mole.Model.Cockpit)
check(Vehicles.board(other, mole), "Couldn't get into the Mole")
local before = #notes
clockNow += 4
Vehicles.step(clockNow)
check(#notes == before, "Logged a silent screen too soon")
clockNow += 2
Vehicles.step(clockNow)
local last = notes[#notes]
check(
	#notes == before + 1 and last.Message:find("no moves", 1, true) and last.Detail:find("Other", 1, true),
	"A silent screen wasn't logged"
)
check(echoed[#echoed].Player == other and echoed[#echoed].Detail:find("Mole2", 1, true), "The silent pilot wasn't told")
clockNow += 10
Vehicles.step(clockNow)
check(#notes == before + 1, "The silent screen was logged again")
-- A stuck report: logged with both sides' view, three a ride.
check(not Vehicles.report(other, 5), "A report that isn't text was taken")
check(not Vehicles.report(makePlayer("Walker"), "stuck"), "Someone on foot filed a report")
check(Vehicles.report(other, "server not answering"), "A report was refused")
last = notes[#notes]
check(
	last.Detail:find("Client: server not answering", 1, true) and last.Detail:find("Mole2 at", 1, true),
	"The report lacks a side"
)
check(
	Vehicles.report(other, "again") and Vehicles.report(other, string.rep("x", 5000)),
	"Second or third report refused"
)
check(#notes[#notes].Detail < 1200, "A long report wasn't cut short")
check(not Vehicles.report(other, "fourth"), "Took a fourth report in one ride")

-- Getting out ------------------------------------------------------------------------------------------
mechExit.OnServerEvent:Fire(pilot)
check(pilot:GetAttribute("MechPilot") == nil and hauler.Pilot == nil, "Getting out didn't let go")
check(weld.Destroyed and hauler.Weld == nil, "The weld stayed")
check(hauler.Model:GetAttribute("MechPilotId") == nil and prompt.Enabled, "The mech still says it's taken")
check(not pilot.Character.Humanoid.Sit, "Still sat down")
local pivot = pilot.Character.Pivots[#pilot.Character.Pivots]
check(pivot and not pivot.Welded, "Moved out while still welded (it would drag the mech)")
local beside = pivot.CFrame.Position - chassis.Position
check(R.Vector3.new(beside.X, 0, beside.Z).Magnitude > 5, "Not stood beside the mech")
check(not move(pilot, start, 0, 0, 0), "A move taken after getting out")
check(not Vehicles.exit(pilot), "Got out twice")

-- Let go when they leave, die, respawn, get busy, or something else lets go
-- of them (SeatExit), without being moved unless they got busy.
local function boarded(player, machine)
	near(player, machine.Model.Cockpit)
	assert(Vehicles.board(player, machine), "couldn't get in for a release check")
	player.Welded = machine.Weld
	return #player.Character.Pivots
end
local pivots = boarded(pilot, hauler)
pilot.Attributes.CombatSession = "Duel"
Vehicles.step(clockNow)
check(hauler.Pilot == nil and pilot:GetAttribute("MechPilot") == nil, "A pilot in a fight kept the mech")
check(#pilot.Character.Pivots == pivots + 1, "A pilot pulled into a fight wasn't put down beside it")
pilot.Attributes.CombatSession = nil

pivots = boarded(pilot, hauler)
hauler.Weld:Destroy() -- (SeatExit, before an arena move)
Vehicles.step(clockNow)
check(
	hauler.Pilot == nil and pilot:GetAttribute("MechPilot") == nil and prompt.Enabled,
	"A weld let go elsewhere kept the pilot"
)
check(#pilot.Character.Pivots == pivots, "Someone else's move was overridden")

boarded(pilot, hauler)
pilot:SetAttribute("MechPilot", nil)
Vehicles.step(clockNow)
check(hauler.Pilot == nil and hauler.Weld == nil, "A pilot cleared elsewhere kept the mech")

boarded(pilot, hauler)
pilot.Character.Humanoid.Health = 0
Vehicles.step(clockNow)
check(hauler.Pilot == nil, "A dead pilot kept the mech")

pilot.Respawn()
boarded(pilot, hauler)
pilot.Respawn() -- (a new body: the weld holds the old one)
Vehicles.step(clockNow)
check(hauler.Pilot == nil and hauler.Weld == nil, "A respawned pilot kept the mech")

boarded(pilot, hauler)
Players.PlayerRemoving:Fire(pilot)
check(hauler.Pilot == nil and prompt.Enabled, "A pilot who left kept the mech")
boarded(pilot, hauler)
pilot.Parent = nil
Vehicles.step(clockNow)
check(hauler.Pilot == nil, "A pilot no longer in the game kept the mech")
pilot.Parent = "Players"

-- SeatExit lets go of a pilot too (before an arena move).
local SeatExit = load("src/server/Systems/SeatExit.luau", {
	game = {
		GetService = function(_, name)
			return if name == "Players" then Players else {}
		end,
	},
	Enum = R.Enum,
	Vector3 = R.Vector3,
})
boarded(pilot, hauler)
local root = pilot.Character.Root
function root:GetJoints()
	return { hauler.Weld }
end
SeatExit.detach(pilot.Character)
check(hauler.Weld.Destroyed and pilot:GetAttribute("MechPilot") == nil, "SeatExit didn't let go of the pilot")
check(not pilot.Character.Humanoid.Sit, "SeatExit left the pilot sat down")
Vehicles.step(clockNow)
check(hauler.Pilot == nil and prompt.Enabled, "The mech didn't notice its pilot was taken")
root.GetJoints = nil

-- Going home -----------------------------------------------------------------------------------------
-- (The Mole's pilot gets out; the Hauler was left out past its bay.)
Vehicles.exit(other)
chassis.CFrame = R.CFrame.new(start + R.Vector3.new(0, 0, -80))
hauler.LastUsed = clockNow
Vehicles.tidy(clockNow + Rules.MachineResetSeconds - 5)
check((chassis.Position - hauler.Bay.Position).Magnitude > 12, "Went home too soon")
Vehicles.tidy(clockNow + Rules.MachineResetSeconds + 5)
check(
	math.abs((chassis.Position - hauler.Bay.Position).Magnitude - 6.2) < 0.01 and math.abs(yawOf(chassis)) < 1e-4,
	"An abandoned mech didn't go home"
)
check(same(hauler.Model:GetAttribute("MechPosition"), chassis.Position), "Going home didn't tell anyone")
-- A piloted one stays out; one out of the world comes back at once.
boarded(pilot, hauler)
chassis.CFrame = R.CFrame.new(start + R.Vector3.new(0, 0, -80))
Vehicles.tidy(clockNow + Rules.MachineResetSeconds * 3)
check(hauler.Pilot == pilot and (chassis.Position - hauler.Bay.Position).Magnitude > 12, "A piloted mech was sent home")
Vehicles.exit(pilot)
moleChassis.CFrame = R.CFrame.new(mole.Bay.Position + R.Vector3.new(0, -100, 0))
Vehicles.tidy(clockNow)
check(moleChassis.Position.Y > origin.Y, "A mech out of the world stayed there")
-- Sending one home with a pilot in it puts them down first.
boarded(pilot, hauler)
Vehicles._reset(hauler)
check(hauler.Pilot == nil and pilot:GetAttribute("MechPilot") == nil, "Sent home with its pilot welded in")

print(
	"PASS: "
		.. checks
		.. " outpost vehicle checks (parking, getting in, moves checked, getting out, letting go, going home, diagnostics)"
)
