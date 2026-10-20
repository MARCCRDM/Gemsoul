-- Shared.MechPilot: who pilots what (from attributes, no seats), and how a
-- mech moves over the ground (the pilot's screen runs this, Client
-- VehicleDrive): driving, steering, a rock, a pebble, a kerb, a ledge, a pit,
-- no ground loaded, the crater rim, pushing through, and up and down the
-- ramps to the Shelter's garage doors. A stand-in world; the
-- real drive maths (Shared.Outpost.drive). Run by tests/run_mech_pilot.py (lune).
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

local tagged = {}
local game = {
	GetService = function(_, name)
		assert(name == "CollectionService", "MechPilot wants " .. tostring(name))
		return {
			GetTagged = function(_, tag)
				return if tag == "OutpostMech" then tagged else {}
			end,
		}
	end,
}
local env = { game = game, CFrame = R.CFrame, Vector3 = R.Vector3 }
local MechPilot = load("src/shared/MechPilot.luau", env)
local Rules = load("src/shared/Outpost.luau", { CFrame = R.CFrame, Color3 = R.Color3 })

-- Who pilots what ------------------------------------------------------------------------------
local function mech(id, kind, at)
	local model = R.Instance.new("Model")
	model.Name = kind
	local chassis = R.Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = R.Vector3.new(7.6, 12, 6.2)
	chassis.CFrame = at * R.CFrame.new(0, 6.2, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis
	local hull = R.Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = R.Vector3.new(7.6, 12 - 1.6, 6.2)
	hull.CFrame = chassis.CFrame * R.CFrame.new(0, 0.8, 0)
	hull.Parent = model
	model:SetAttribute("MechId", id)
	model:SetAttribute("MechKind", kind)
	table.insert(tagged, model)
	return model
end
local origin = Rules.Location.Position
local hauler = mech("Hauler1", "Hauler", R.CFrame.new(origin) * R.CFrame.Angles(0, 0, 0))
local mole = mech("Mole3", "Mole", R.CFrame.new(origin + R.Vector3.new(40, 0, 0)) * R.CFrame.Angles(0, math.rad(90), 0))
local pilot = R.Instance.new("Folder") -- (a Player stand-in: only its attributes matter)
check(MechPilot.of(pilot) == nil and MechPilot.mech(pilot) == nil, "Someone on foot pilots something")
pilot:SetAttribute("MechPilot", "Mole3")
check(MechPilot.of(pilot) == "Mole3" and MechPilot.mech(pilot) == mole, "The pilot's mech wasn't found")
check(MechPilot.kind(MechPilot.mech(pilot)) == "Mole", "The pilot's mech kind wasn't read")
pilot:SetAttribute("MechPilot", "")
check(MechPilot.of(pilot) == nil, "An empty MechPilot counted as piloting")
pilot:SetAttribute("MechPilot", "Digger9")
check(MechPilot.of(pilot) == "Digger9" and MechPilot.mech(pilot) == nil, "A mech that isn't here was found")
check(MechPilot.find(nil) == nil and MechPilot.kind(nil) == nil, "Nothing found something")

-- Its state, from the model.
local state = MechPilot.state(hauler)
check(
	(state.Position - hauler.PrimaryPart.CFrame.Position).Magnitude < 1e-3 and math.abs(state.Yaw) < 1e-6,
	"Its state isn't where it stands"
)
check(math.abs(state.Hover - 6.2) < 1e-3 and math.abs(state.Lift - 1.6) < 1e-6, "Its ride height or step")
check((state.HullOffset.Position - R.Vector3.new(0, 0.8, 0)).Magnitude < 1e-3, "Its hull isn't where the hull is")
check(math.abs(state.HullSize.Y - 10.2) < 1e-3, "Its hull isn't the hull's size (less a little)")
local moleState = MechPilot.state(mole)
check(math.abs(moleState.Yaw - math.rad(90)) < 1e-4, "A turned mech's heading")
check(
	(moleState.HullOffset.Position - R.Vector3.new(0, 0.8, 0)).Magnitude < 1e-3,
	"A turned mech's hull offset turned with it"
)
check(
	(MechPilot.frame(moleState).Position - mole.PrimaryPart.CFrame.Position).Magnitude < 1e-3,
	"Its frame isn't where it stands"
)

-- The world it moves through: the quarry floor at y = 0, areas raised, sunk
-- or cut away, and rocks in the way.
local areas = {} -- { X = { min, max }, Z = { min, max }, Y = its height, or Cut = true, or Ramp = { From, To, Height } }
local rocks = {} -- { Name, X, Z, Radius, Top }
local function inside(area, x, z)
	return x >= area.X[1] and x <= area.X[2] and z >= area.Z[1] and z <= area.Z[2]
end
-- Like a ray down from `top`: the highest surface at or below it.
local function surfaceAt(x, z, top)
	local best = if top >= 0 then 0 else nil
	for _, area in areas do
		if inside(area, x, z) and area.Cut then
			best = nil
		end
	end
	for _, area in areas do
		local y = area.Y
		if area.Ramp then
			-- (a slope along z: nothing at From, Height at To)
			y = area.Ramp.Height * math.clamp((z - area.Ramp.From) / (area.Ramp.To - area.Ramp.From), 0, 1)
		end
		if inside(area, x, z) and y and y <= top and (best == nil or y > best) then
			best = y
		end
	end
	return best
end
local sweeps, lastSweep = 0, nil
local world = {
	Sweep = function(from, size, direction)
		sweeps += 1
		lastSweep = { From = from, Size = size, Direction = direction }
		local start = from.Position
		local bottom = start.Y - size.Y / 2
		local reach = size.Z / 2
		local length = direction.Magnitude
		local ux, uz = direction.X / length, direction.Z / length
		local best, name = nil, nil
		-- A ramp's slope rising into the hull's bottom (its leading edge,
		-- corner to corner, along the sweep).
		local across = R.Vector3.new(-uz, 0, ux) * (size.X / 2)
		for _, area in areas do
			if area.Ramp then
				for t = 0, length, 0.02 do
					local edge = start + R.Vector3.new(ux, 0, uz) * (t + reach)
					for _, corner in { edge - across, edge, edge + across } do
						local y = surfaceAt(corner.X, corner.Z, bottom + 100)
						if y and y > bottom and (best == nil or t < best) then
							best, name = t, "a ramp"
						end
					end
				end
			end
		end
		for _, rock in rocks do
			if rock.Top > bottom then
				local dx, dz = rock.X - start.X, rock.Z - start.Z
				local r = rock.Radius + reach
				local b = dx * ux + dz * uz
				local c = dx * dx + dz * dz - r * r
				if c > 0 and b * b - c >= 0 then
					local t = b - math.sqrt(b * b - c)
					if t >= 0 and t <= length and (best == nil or t < best) then
						best, name = t, rock.Name
					end
				end
			end
		end
		return best, name
	end,
	Floor = function(at, length)
		local y = surfaceAt(at.X, at.Z, at.Y)
		return if y and y >= at.Y - length then y else nil
	end,
	Rim = { Center = origin, Radius = Rules.Radius + 40 },
	Gravity = 196.2,
}

-- Driving, as the pilot's screen does each frame.
local spec = Rules.Machines.Hauler
local m = MechPilot.state(hauler)
local blocked = nil
local function frames(n, throttle, steer)
	for _ = 1, n do
		local dt = 1 / 60
		local speed, yaw = Rules.drive(spec, m.Speed, m.Yaw, throttle, steer, dt)
		blocked = MechPilot.move(m, world, speed * dt, yaw, dt)
		m.Speed = if blocked then 0 else speed
	end
end
local function place(x, z, yaw, y)
	m.Position, m.Yaw, m.Speed, m.Fall, m.Through = R.Vector3.new(x, (y or 0) + 6.2, z), yaw, 0, 0, false
end
local function near(a, b, within)
	return math.abs(a - b) <= (within or 1e-3)
end

local start = m.Position
frames(10, 0, 0)
check((m.Position - start).Magnitude < 1e-3, "It moved with no input: " .. (m.Position - start).Magnitude)
frames(60 * 4, 1, 0)
check(near(m.Speed, spec.MaxSpeed) and m.Position.Z < start.Z - 50, "It didn't drive forward at top speed")
check(near(m.Position.X, start.X) and near(m.Position.Y, 6.2), "Driving straight on the flat wandered off")
check(
	near(lastSweep.From.Position.Y, m.Position.Y + 0.8) and near(lastSweep.Size.Y, 10.2, 0.01),
	"It didn't sweep its hull"
)
check(lastSweep.Direction.Unit:Dot(R.Vector3.new(0, 0, -1)) > 0.999, "It swept the wrong way")
frames(30, 0, 1)
check(m.Yaw < -0.2, "Steering right didn't turn it right")
place(0, 6900, 0)
frames(60, -1, 0)
check(m.Position.Z > 6900 and m.Speed < 0, "It didn't back up")

-- A rock: it stops short, says so, turns away and goes on.
place(0, 6900, 0)
rocks = { { Name = "Boulder", X = 0, Z = 6870, Radius = 4, Top = 8 } }
frames(60 * 3, 1, 0)
check(near(m.Position.Z, 6870 + 4 + 3 + 0.4, 0.05), "Drove into the rock, or stopped short: " .. m.Position.Z)
check(blocked == "Boulder" and m.Speed == 0, "Didn't say what's in the way, or kept pushing")
frames(60 * 2, 0, 1)
local stopped = m.Position
frames(60, 1, 0)
check((m.Position - stopped).Magnitude > 5 and blocked == nil, "Couldn't drive away from the rock")
-- Pushing through (Through): the rock doesn't stop it.
place(0, 6900, 0)
frames(60 * 3, 1, 0)
m.Through = true
local wedged = m.Position
frames(30, 1, 0)
check(m.Position.Z < wedged.Z - 1 and blocked == nil, "Pushing through didn't get past the rock")
m.Through = false
-- A pebble lower than its hull isn't in the way.
place(0, 6900, 0)
rocks = { { Name = "Pebble", X = 0, Z = 6880, Radius = 2, Top = 1 } }
frames(60 * 2, 1, 0)
check(m.Position.Z < 6878 and blocked == nil, "A pebble stopped it")
rocks = {}

-- A kerb: up it goes, and down off the far side.
place(0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6850, 6885 }, Y = 1.2 } }
frames(60 * 2, 1, 0)
check(m.Position.Z < 6885 and m.Position.Z > 6850 and near(m.Position.Y, 7.4), "Didn't step up the kerb")
frames(60 * 2, 1, 0)
check(m.Position.Z < 6850 and near(m.Position.Y, 6.2) and m.Fall == 0, "Didn't step back down off it")
-- A ledge too high to step up: it stops at the foot of it.
place(0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6850, 6885 }, Y = 1.8 } }
frames(60 * 2, 1, 0)
check(
	m.Position.Z > 6885 and m.Position.Z < 6890 and blocked == "a ledge",
	"Climbed a ledge too high, or stopped short"
)
-- A pit: off the edge and down, under gravity.
place(0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6800, 6890 }, Cut = true }, { X = { -50, 50 }, Z = { 6800, 6890 }, Y = -8 } }
local fell, lowest = false, math.huge
for _ = 1, 60 * 2 do
	frames(1, 1, 0)
	if m.Position.Y < 6.2 - 0.01 and m.Position.Y > -1.8 + 0.01 then
		fell = true
	end
	lowest = math.min(lowest, m.Position.Y)
end
check(fell and near(lowest, -1.8) and near(m.Position.Y, -1.8) and m.Fall == 0, "Didn't fall into the pit and land")
-- No ground found (still loading in, say): it carries on at its height.
place(0, 6900, 0)
areas = { { X = { -50, 50 }, Z = { 6800, 6890 }, Cut = true } }
frames(60 * 2, 1, 0)
check(m.Position.Z < 6890 and near(m.Position.Y, 6.2) and blocked == nil, "No ground held it still, or dropped it")
areas = {}
-- The Shelter's ramps (Server OutpostWorld): up from the quarry floor to
-- its floor (ShelterLift up, on a slab 0.8 thick) over ShelterRamp studs,
-- then a landing and the garage floor beyond. A mech drives straight up,
-- up at an angle, and back down, never caught on the slope.
local rise, run = Rules.ShelterLift + 0.8, Rules.ShelterRamp
areas = {
	{ X = { -40, 40 }, Z = { 6880 - run, 6880 }, Ramp = { From = 6880, To = 6880 - run, Height = rise } },
	{ X = { -40, 40 }, Z = { 6700, 6880 - run }, Y = rise },
}
local function climb(seconds): boolean
	local caught = false
	for _ = 1, 60 * seconds do
		frames(1, 1, 0)
		caught = caught or blocked ~= nil
	end
	return caught
end
place(0, 6900, 0)
local caught = climb(4)
check(
	not caught and m.Position.Z < 6880 - run - 5,
	"Caught on the ramp up: " .. tostring(blocked) .. " at " .. m.Position.Z
)
check(near(m.Position.Y, rise + 6.2, 0.01), "Not up on the floor at the top of the ramp: " .. m.Position.Y)
place(-18, 6900, math.rad(-25))
caught = climb(4)
check(
	not caught and m.Position.Z < 6880 - run and near(m.Position.Y, rise + 6.2, 0.01),
	"Caught driving up the ramp at an angle"
)
place(0, 6800, math.pi, rise)
caught = climb(7)
check(
	not caught and m.Position.Z > 6890 and near(m.Position.Y, 6.2, 0.01) and m.Fall == 0,
	"Didn't drive back down the ramp: " .. tostring(blocked) .. " at " .. m.Position.Z .. ", " .. m.Position.Y
)
areas = {}
-- The crater rim.
place(origin.X, origin.Z - Rules.Radius - 30, 0)
frames(60 * 3, 1, 0)
local out = m.Position - origin
check(R.Vector3.new(out.X, 0, out.Z).Magnitude <= Rules.Radius + 40 + 0.01, "Drove out over the crater rim")
check(blocked == "the crater rim", "Didn't say the rim is in the way")

print(
	"PASS: "
		.. checks
		.. " mech pilot checks (who pilots what, driving, rocks, pushing through, kerbs, ledges, a pit, no ground, the Shelter's ramps, the rim)"
)
