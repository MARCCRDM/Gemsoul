-- Mechs over the Outpost's terrain (Shared.MechPilot.move): the biomes'
-- ground (Shared.Frontier.ground, as Server.OutpostWorld lays it: 4-stud
-- terrain cells, smoothed) walked over without getting stuck, every mech,
-- every way, up its steepest slopes and down them keeping to the ground,
-- on a slow phone's frames too. A wall, a cliff and a rock on it still stop
-- it. And the old way (the hull stopped by any ground that rose under its
-- front) got stuck on the same ground. A stand-in terrain: its hull sweep
-- finds the ground's surface (its normal, and where), and counts ground it
-- starts in as a hit (stricter than Roblox's); a ray down from inside the
-- ground finds nothing (as Roblox's). Run by tests/run_mech_terrain.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."
local Vector3, CFrame = R.Vector3, R.CFrame

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local function load(path, env)
	local source = fs.readFile(ROOT .. "/" .. path)
	return luau.load(source, { debugName = path, environment = setmetatable(env or {}, { __index = _G }) })()
end
local game = {
	GetService = function()
		return {
			GetTagged = function()
				return {}
			end,
		}
	end,
}
local MechPilot = load("src/shared/MechPilot.luau", { game = game, CFrame = CFrame, Vector3 = Vector3 })
local Rules = load("src/shared/Outpost.luau", { CFrame = CFrame, Color3 = R.Color3 })
local Frontier = load("src/shared/Frontier.luau", { Color3 = R.Color3, Vector3 = Vector3, CFrame = CFrame })

-- The ground: Frontier's rise at each 4-stud cell's middle, smoothed
-- between them (terrain's voxels), with nothing standing to flatten it (the
-- worst case). Cells are made as they're asked for.
local CELL = Frontier.Ground.Cell
local cells = {}
local function cellHeight(i, k)
	local key = i * 100000 + k
	local h = cells[key]
	if h == nil then
		local _, _, rise = Frontier.ground((i + 0.5) * CELL, (k + 0.5) * CELL)
		h = rise
		cells[key] = h
	end
	return h
end
local extra = {} -- { { X, Z, Radius, Top } } (a cliff, a box: walls)
local function ground(x, z)
	local fx, fz = x / CELL - 0.5, z / CELL - 0.5
	local i, k = math.floor(fx), math.floor(fz)
	local u, v = fx - i, fz - k
	local h00, h10, h01, h11 = cellHeight(i, k), cellHeight(i + 1, k), cellHeight(i, k + 1), cellHeight(i + 1, k + 1)
	return (h00 * (1 - u) + h10 * u) * (1 - v) + (h01 * (1 - u) + h11 * u) * v
end
local function normalAt(x, z)
	local e = 0.25
	local dx = (ground(x + e, z) - ground(x - e, z)) / (2 * e)
	local dz = (ground(x, z + e) - ground(x, z - e)) / (2 * e)
	return Vector3.new(-dx, 1, -dz).Unit
end

-- The hull swept: the first point along the way where the ground (or a
-- wall) comes up into its underside, sampled across it.
local sweeps = 0
local world = {
	Sweep = function(from, size, direction)
		sweeps += 1
		local length = direction.Magnitude
		local unit = direction / length
		local bottom = from.Position.Y - size.Y / 2
		local samples = {}
		for _, sx in { -0.5, -0.25, 0, 0.25, 0.5 } do
			for _, sz in { -0.5, -0.25, 0, 0.25, 0.5 } do
				table.insert(samples, from:PointToWorldSpace(Vector3.new(sx * size.X, -size.Y / 2, sz * size.Z)))
			end
		end
		local t = 0
		while t <= length + 1e-6 do
			for _, s in samples do
				local p = s + unit * t
				for _, wall in extra do
					local gap = Vector3.new(p.X - wall.X, 0, p.Z - wall.Z).Magnitude
					if gap <= wall.Radius and bottom < wall.Top then
						local out = Vector3.new(p.X - wall.X, 0, p.Z - wall.Z)
						return t, wall.Name, (if out.Magnitude > 1e-6 then out.Unit else -unit), Vector3.new(p.X, bottom, p.Z)
					end
				end
				local h = ground(p.X, p.Z)
				if h > bottom then
					return t, "Terrain", normalAt(p.X, p.Z), Vector3.new(p.X, h, p.Z)
				end
			end
			t += 0.05
		end
		return nil
	end,
	Floor = function(at, length)
		local h = ground(at.X, at.Z)
		for _, wall in extra do
			if Vector3.new(at.X - wall.X, 0, at.Z - wall.Z).Magnitude <= wall.Radius then
				h = math.max(h, wall.Top)
			end
		end
		-- (From inside the ground, a ray down finds nothing.)
		if h > at.Y or h < at.Y - length then
			return nil
		end
		return h
	end,
	Gravity = 196.2,
}

-- A mech of a kind, as the server builds it: chassis 12 tall, hull from
-- Lift up, at its scale.
local SCALES = { Hauler = 1, Mole = 1, Digger = 0.95, Skipper = 0.86 }
local function mechOf(kind, x, z, yaw)
	local scale = SCALES[kind]
	local chassisSize = Vector3.new(7.6, 12, 6.2) * scale
	local hover = chassisSize.Y / 2 + 0.2
	local lift = MechPilot.Lift * scale
	return {
		Kind = kind,
		Position = Vector3.new(x, ground(x, z) + hover, z),
		Yaw = yaw,
		Speed = 0,
		Fall = 0,
		Lift = lift,
		Scale = scale,
		Hover = hover,
		HullOffset = CFrame.new(0, lift / 2, 0),
		HullSize = Vector3.new(7.6, 12 - MechPilot.Lift, 6.2) * scale - Vector3.new(0.2, 0.2, 0.2),
		Through = false,
	}
end

-- Driving it ahead `seconds` at full throttle, `fps` frames a second (and
-- steering `steer`): where it got, what stopped it, and the most it stood
-- still in a row, how high off the ground it ever rode and how deep it sank.
local function drive(m, seconds, fps, steer)
	local spec = Rules.Machines[m.Kind]
	local dt = 1 / (fps or 60)
	local result = { Blocked = {}, Stall = 0, Air = 0, Sink = 0, Travel = 0 }
	local still = 0
	for _ = 1, math.floor(seconds / dt) do
		local before = m.Position
		local speed, yaw = Rules.drive(spec, m.Speed, m.Yaw, 1, steer or 0, dt)
		local blocked = MechPilot.move(m, world, speed * dt, yaw, dt)
		m.Speed = if blocked then 0 else speed
		if blocked then
			result.Blocked[blocked] = (result.Blocked[blocked] or 0) + 1
		end
		local moved = Vector3.new(m.Position.X - before.X, 0, m.Position.Z - before.Z).Magnitude
		result.Travel += moved
		still = if moved < 1e-3 then still + dt else 0
		result.Stall = math.max(result.Stall, still)
		local off = m.Position.Y - m.Hover - ground(m.Position.X, m.Position.Z)
		result.Air = math.max(result.Air, off)
		result.Sink = math.max(result.Sink, -off)
	end
	return result
end
local function blockedBy(result)
	local list = {}
	for what, n in result.Blocked do
		table.insert(list, what .. " x" .. n)
	end
	return table.concat(list, ", ")
end

-- The steepest ground there is, out in each biome.
local steepest = {}
for index, biome in Frontier.Biomes do
	local best, bestAt = 0, nil
	for r = Frontier.Core + 40, 400, 6 do
		for da = -0.6, 0.6, 0.03 do
			local a = biome.Angle + da
			local x, z = math.cos(a) * r, math.sin(a) * r
			local g = (ground(x + 1, z) - ground(x - 1, z)) ^ 2 + (ground(x, z + 1) - ground(x, z - 1)) ^ 2
			g = math.sqrt(g) / 2
			if g > best then
				best, bestAt = g, Vector3.new(x, 0, z)
			end
		end
	end
	steepest[index] = { At = bestAt, Grade = best, Biome = biome.Id }
end
local steepestOfAll = 0
for _, s in steepest do
	steepestOfAll = math.max(steepestOfAll, s.Grade)
end
check(steepestOfAll > 0.6, "No steep ground to test on: " .. steepestOfAll)
check(steepestOfAll < MechPilot.Grade, "The biomes' ground is steeper than a mech walks: " .. steepestOfAll)

-- Every mech, eight ways through each biome's steepest spot (starting 30
-- studs back): it walks on through, never stopped, never standing still,
-- on the ground the whole way (riding the slope, never hopping off it).
local runs = 0
for _, kind in Rules.MachineOrder do
	for _, spot in steepest do
		for way = 0, 7 do
			local yaw = way * math.pi / 4
			local look = CFrame.Angles(0, yaw, 0).LookVector
			local start = spot.At - look * 30
			local m = mechOf(kind, start.X, start.Z, yaw)
			local result = drive(m, 3)
			runs += 1
			check(
				next(result.Blocked) == nil,
				string.format("%s stuck in %s heading %d: %s", kind, spot.Biome, way * 45, blockedBy(result))
			)
			check(result.Stall < 0.05, kind .. " stood still in " .. spot.Biome .. ": " .. result.Stall .. " s")
			check(
				result.Travel > Rules.Machines[kind].MaxSpeed * 3 * 0.6,
				string.format("%s barely moved in %s: %.1f studs", kind, spot.Biome, result.Travel)
			)
			check(result.Air < 0.35, string.format("%s rode off the ground in %s: %.2f studs", kind, spot.Biome, result.Air))
			check(result.Sink < 1e-3, kind .. " sank into the ground in " .. spot.Biome)
		end
	end
end

-- A long wander across each biome, steering as it goes.
for index, biome in Frontier.Biomes do
	local a = biome.Angle
	local start = Vector3.new(math.cos(a), 0, math.sin(a)) * (Frontier.Core + 60)
	local m = mechOf("Hauler", start.X, start.Z, -a - math.pi / 2)
	local total = { Travel = 0, Stall = 0 }
	for leg = 1, 6 do
		local result = drive(m, 2, 60, if leg % 2 == 0 then 0.6 else -0.4)
		check(next(result.Blocked) == nil, "Stuck wandering " .. biome.Id .. ": " .. blockedBy(result))
		total.Travel += result.Travel
		total.Stall = math.max(total.Stall, result.Stall)
	end
	check(total.Travel > 200 and total.Stall < 0.05, "Wandering " .. biome.Id .. " didn't get far: " .. total.Travel)
end

-- A slow phone (10 frames a second): the long moves up the steepest slope
-- are taken in strides, so the slope never reads as a ledge.
for _, spot in steepest do
	for way = 0, 7, 2 do
		local yaw = way * math.pi / 4
		local start = spot.At - CFrame.Angles(0, yaw, 0).LookVector * 30
		local m = mechOf("Skipper", start.X, start.Z, yaw)
		local result = drive(m, 3, 10)
		check(next(result.Blocked) == nil, "A slow phone's mech stuck in " .. spot.Biome .. ": " .. blockedBy(result))
		check(result.Air < 0.6, "A slow phone's mech hopped off the ground in " .. spot.Biome)
	end
end

-- Still stopped by what's really in the way: a rock (its sides upright) on
-- the slope, and a cliff too steep to walk.
do
	local spot = steepest[1].At
	local m = mechOf("Mole", spot.X, spot.Z + 30, 0)
	extra = { { Name = "Rock", X = spot.X, Z = spot.Z + 10, Radius = 3, Top = ground(spot.X, spot.Z + 10) + 6 } }
	local result = drive(m, 3)
	check(result.Blocked.Rock ~= nil, "Walked through a rock on the slope")
	check(m.Position.Z > spot.Z + 10 + 3, "Got past the rock")
	extra = {}
end
do
	-- (A stand-in ground: flat, then a cliff face 70 degrees steep, 8 high.)
	local saved = ground
	ground = function(x, z)
		local into = 7000 - z
		return math.clamp(into * math.tan(math.rad(70)), 0, 8)
	end
	normalAt = function(x, z)
		local into = 7000 - z
		if into > 0 and into * math.tan(math.rad(70)) < 8 then
			return Vector3.new(0, math.cos(math.rad(70)), math.sin(math.rad(70)))
		end
		return Vector3.new(0, 1, 0)
	end
	local m = mechOf("Hauler", 0, 7030, 0)
	local result = drive(m, 3)
	check(next(result.Blocked) ~= nil and m.Position.Z > 7000, "Walked up a cliff too steep to walk")
	-- A slope just walkable (55 degrees, 3 high): up it goes.
	ground = function(x, z)
		return math.clamp((7000 - z) * math.tan(math.rad(55)), 0, 3)
	end
	normalAt = function(x, z)
		local into = 7000 - z
		if into > 0 and into * math.tan(math.rad(55)) < 3 then
			return Vector3.new(0, math.cos(math.rad(55)), math.sin(math.rad(55)))
		end
		return Vector3.new(0, 1, 0)
	end
	m = mechOf("Hauler", 0, 7030, 0)
	result = drive(m, 3)
	check(next(result.Blocked) == nil and m.Position.Z < 6980, "Didn't walk up a slope of 55 degrees: " .. blockedBy(result))
	check(math.abs(m.Position.Y - m.Hover - 3) < 1e-3, "Not up on top of the slope")
	ground = saved
	normalAt = function(x, z)
		local e = 0.25
		local dx = (ground(x + e, z) - ground(x - e, z)) / (2 * e)
		local dz = (ground(x, z + e) - ground(x, z - e)) / (2 * e)
		return Vector3.new(-dx, 1, -dz).Unit
	end
end

-- The old way: any ground rising under the hull's front stopped it. On the
-- same ground it got stuck (so the tests above would have caught it).
do
	local walkable = MechPilot.Walkable
	MechPilot.Walkable = 2 -- (nothing's ground it walks over)
	local stuck = 0
	for _, spot in steepest do
		for way = 0, 7 do
			local yaw = way * math.pi / 4
			local start = spot.At - CFrame.Angles(0, yaw, 0).LookVector * 30
			local m = mechOf("Hauler", start.X, start.Z, yaw)
			if next(drive(m, 3).Blocked) ~= nil then
				stuck += 1
			end
		end
	end
	MechPilot.Walkable = walkable
	check(stuck >= 8, "The old way didn't get stuck on this ground (" .. stuck .. " of 32): the test isn't testing")
	print(string.format("(the old way got stuck on %d of 32 runs through the steepest spots)", stuck))
end

print(
	string.format(
		"PASS: %d mech terrain checks (%d runs through each biome's steepest ground, every mech, eight ways; long wanders; a slow phone; a rock and a cliff still stop it; steepest %.2f)",
		checks,
		runs,
		steepestOfAll
	)
)
