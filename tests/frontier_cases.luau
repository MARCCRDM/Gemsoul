-- lune run tests/frontier_cases.luau <repo>
-- The Outpost's frontier (Shared.Frontier): the bands, the candy trails
-- (out to the walls, clear of the roads and buildings, rocks evenly
-- spaced, crumbs between, a Rift Vein at each end), richer rocks outward
-- (Shared.Outpost.Zones), pressure and incursions, where rifts open, their
-- timeline, and their ragged, lopsided tears.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local Vector3, Vector2 = roblox.Vector3, roblox.Vector2
-- (Lune has no Random: a small seeded one with the same methods.)
local Random = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = roblox.CFrame,
	Random = Random,
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Frontier = shared("Frontier")
local Outpost = shared("Outpost")
local flat = function(v)
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Bands -----------------------------------------------------------------------------------------
check(Frontier.band(0) == "Core" and Frontier.band(Frontier.Core - 1) == "Core", "The middle isn't the core")
check(Frontier.band(Frontier.Core) == "Fringe" and Frontier.band(Frontier.EdgeFrom - 1) == "Fringe", "The fringe")
check(Frontier.band(Frontier.EdgeFrom) == "Edge" and Frontier.band(1000) == "Edge", "The edge")
check(Frontier.distance(Vector3.new(3, 50, 4), Vector3.new(0, 0, 0)) == 5, "Distance counts height")
-- Richer outward: every zone a lobby rock grows in is chunks and boulders
-- only, with more boulders and more luck the further out.
local lastBoulders, lastLuck = -1, -1
for _, zone in { "Common", "Fringe", "Edge", "Vein" } do
	local spec = Outpost.Zones[zone]
	check(spec, zone .. " isn't a zone")
	for size in spec.Weights do
		check(size == "Pebble" or size == "Boulder", zone .. " grows a " .. size .. " in the lobby")
	end
	local boulders = spec.Weights.Boulder / (spec.Weights.Boulder + spec.Weights.Pebble)
	check(boulders > lastBoulders and (spec.Luck or 0) > lastLuck, zone .. " isn't richer than the zone inside it")
	lastBoulders, lastLuck = boulders, spec.Luck or 0
end
check(Frontier.zoneOf(10) == "Common" and Frontier.zoneOf(200) == "Fringe", "Zones by distance")
check(Frontier.zoneOf(350) == "Edge" and Frontier.zoneOf(350, true) == "Vein", "The edge and its veins")
for band, spec in Frontier.Bands do
	local distance = if band == "Core" then 0 elseif band == "Fringe" then 200 else 350
	local zone = Outpost.Zones[Frontier.zoneOf(distance, band == "Vein")]
	check(spec.Luck == (zone.Luck or 0), band .. "'s luck isn't its zone's")
end

-- Candy trails ---------------------------------------------------------------------------------------
-- (The Outpost's roads, outpost, pad and motor pool, as OutpostWorld builds them.)
local roads = {}
for i = 0, 5 do
	local a = i / 6 * math.pi * 2 + math.rad(30)
	table.insert(
		roads,
		{ Vector3.new(math.cos(a) * 60, 0, math.sin(a) * 60), Vector3.new(math.cos(a) * 420, 0, math.sin(a) * 420) }
	)
end
local function toRoad(p)
	local best = math.huge
	for _, line in roads do
		local a, b = line[1], line[2]
		local t = math.clamp((p - a):Dot(b - a) / (b - a):Dot(b - a), 0, 1)
		best = math.min(best, (a + (b - a) * t - p).Magnitude)
	end
	return best
end
local buildings = {
	{ Vector3.new(0, 0, -110), 60, "the outpost" },
	{ Vector3.new(0, 0, 70), 40, "the landing pad" },
	{ Vector3.new(0, 0, 150), 84, "the motor pool" },
}
local rng = Random.new(7)
local total = 0
local ends = {}
for index = 1, #Frontier.TrailAngles do
	local points = Frontier.trail(index, rng)
	check(#points >= 16, "Trail " .. index .. " is too short: " .. #points)
	total += #points
	check(math.abs(flat(points[1]) - Frontier.TrailFrom) < 4, "Trail " .. index .. " doesn't start at the core")
	check(flat(points[#points]) > Frontier.TrailTo - 20, "Trail " .. index .. " doesn't reach the walls")
	local inBand = {}
	for i, p in points do
		check(p.Y == 0 and flat(p) < Frontier.Rim, "A trail rock past the walls")
		inBand[Frontier.band(flat(p))] = true
		if i > 1 then
			local step = (p - points[i - 1]).Magnitude
			check(step > 11 and step < 23, string.format("Trail %d: rocks %.1f apart", index, step))
			check(flat(p) > flat(points[i - 1]), "Trail " .. index .. " doubles back")
		end
		check(toRoad(p) > 15, string.format("Trail %d rock on a road (%.1f)", index, toRoad(p)))
		for _, b in buildings do
			check((p - b[1]).Magnitude > b[2], string.format("Trail %d runs through %s", index, b[3]))
		end
		-- It leads somewhere: never far off its heading.
		local heading = math.rad(Frontier.TrailAngles[index])
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local off = (p - dir * p:Dot(dir)).Magnitude
		check(off < Frontier.TrailSway + 4, "Trail " .. index .. " wanders off")
		-- Crumbs between this rock and the next.
		local nextPoint = points[i + 1]
		if nextPoint then
			local crumbs = Frontier.crumbs(p, nextPoint, rng)
			check(#crumbs >= 1, "No crumbs between two rocks")
			for _, c in crumbs do
				check((c - p).Magnitude > 2 and (c - nextPoint).Magnitude > 2, "A crumb under a rock")
			end
		end
	end
	check(inBand.Core and inBand.Fringe and inBand.Edge, "Trail " .. index .. " doesn't cross every band")
	-- Its end: a Rift Vein of rocks round a dormant scar, by the walls.
	local vein, scar = Frontier.vein(points[#points], rng)
	check(#vein == Frontier.VeinRocks, "A vein without its rocks")
	for i, v in vein do
		check(flat(v) > flat(points[#points]) and flat(v) < Frontier.Rim, "A vein rock out of place")
		check((v - points[#points]).Magnitude > 12, "A vein rock on the last trail rock")
		for j = i + 1, #vein do
			check((v - vein[j]).Magnitude > 12, "Vein rocks on top of each other")
		end
		check((v - scar).Magnitude < 30, "A vein rock far from its scar")
	end
	check(flat(scar) >= Frontier.Rim and flat(scar) < 440, "The scar isn't by the walls")
	table.insert(ends, scar)
end
check(total >= 100, "Too few trail rocks: " .. total)
for i, a in ends do
	for j = i + 1, #ends do
		check((a - ends[j]).Magnitude > 150, "Two trails end together")
	end
end
check(#Frontier.crumbs(Vector3.zero, Vector3.new(60, 0, 0), rng) == 0, "Crumbs across a big gap")

-- Pressure and incursions --------------------------------------------------------------------------------
check(Frontier.pressure(5, "Core", false, 1) == 5 - Frontier.Pressure.Drain, "The core doesn't drain it")
check(Frontier.pressure(0.5, "Core", true, 1) == 0, "Drained below nothing")
local function secondsTo(band, outward)
	local heat, t = 0, 0
	while heat < Frontier.Pressure.Threshold and t < 100 do
		heat = Frontier.pressure(heat, band, outward, 0.5)
		t += 0.5
	end
	return t
end
check(secondsTo("Edge", false) < secondsTo("Fringe", false), "The edge isn't busier than the fringe")
check(secondsTo("Fringe", true) < secondsTo("Fringe", false), "Heading out doesn't draw them sooner")
check(secondsTo("Fringe", false) <= 15 and secondsTo("Edge", true) >= 3, "Rifts too rare or too often")
check(Frontier.incursion("Core", 0.5) == 0, "Critters in the core")
for roll = 0, 0.99, 0.01 do
	local fringe, edge = Frontier.incursion("Fringe", roll), Frontier.incursion("Edge", roll)
	check(fringe >= 1 and fringe <= Frontier.Caps.Fringe, "A fringe incursion's size")
	check(edge >= 2 and edge <= 3 and edge <= Frontier.Caps.Edge, "An edge incursion's size")
end
check(Frontier.Caps.Edge > Frontier.Caps.Fringe and Frontier.Caps.Server >= Frontier.Caps.Edge * 3, "The caps")
check(Frontier.Boost.Edge.Health > 1 and Frontier.Boost.Edge.Exp > 1, "Edge critters aren't worth more")

-- Where rifts open ----------------------------------------------------------------------------------------
local center = Vector3.new(0, 0, 7000)
local player = center + Vector3.new(220, 3, 0)
local east = Vector3.new(1, 0, 0)
for _ = 1, 200 do
	local spot = Frontier.riftSpot(player, east * 16, center, rng)
	local away = spot - player
	check(spot.Y == player.Y, "A rift at another height")
	check(flat(away) >= Frontier.Rift.Near - 0.01 and flat(away) <= Frontier.Rift.Far + 0.01, "A rift too near or far")
	local angle = math.acos(math.clamp(Vector3.new(away.X, 0, away.Z).Unit:Dot(east), -1, 1))
	check(angle <= Frontier.Rift.Spread + 0.01, "A rift behind a player heading out")
end
-- Standing still: outward. Never inside the core or past the walls.
for _ = 1, 100 do
	local spot = Frontier.riftSpot(center + Vector3.new(0, 0, -155), Vector3.zero, center, rng)
	local r = Frontier.distance(spot, center)
	check(r >= Frontier.Core - 0.01 and r <= Frontier.Rim + 0.01, "A rift in the core")
	local spotFar = Frontier.riftSpot(center + Vector3.new(420, 0, 0), east, center, rng)
	check(Frontier.distance(spotFar, center) <= Frontier.Rim + 0.01, "A rift in the walls")
end

-- A rift's life ----------------------------------------------------------------------------------------------
local life = Frontier.timeline(100)
check(life.OpenAt == 100 and life.HopAt > life.OpenAt + Frontier.Rift.Open - 0.2, "The critter hops out of a shut rift")
check(life.CloseAt > life.HopAt and life.EndAt > life.CloseAt, "The timeline's order")
check(Frontier.openness(life, 99) == 0 and Frontier.openness(life, life.EndAt) == 0, "Open outside its life")
local last = 0
for t = 100, 100 + Frontier.Rift.Open, 0.05 do
	local open = Frontier.openness(life, t)
	check(open >= last, "It doesn't open steadily")
	last = open
end
check(Frontier.openness(life, life.HopAt) == 1, "Not open when the critter hops")
last = 1
for t = life.CloseAt, life.EndAt - 0.01, 0.05 do
	local open = Frontier.openness(life, t)
	check(open <= last, "It doesn't seal steadily")
	last = open
end
check(last < 0.2, "It never seals")

-- The tear: ragged, lopsided, never the same twice -----------------------------------------------------------
local function widths(shape)
	local list = {}
	for i = 1, #shape.Spine do
		table.insert(list, { shape.Spine[i].X - shape.Left[i].X, shape.Right[i].X - shape.Spine[i].X })
	end
	return list
end
local a, b = Frontier.tear(11, 6), Frontier.tear(11, 6)
check(a.Tilt == b.Tilt and a.Left[3] == b.Left[3], "The same seed tears differently")
local c = Frontier.tear(12, 6)
check(c.Left[3] ~= a.Left[3] or c.Tilt ~= a.Tilt, "Two seeds tear the same")
for seed = 1, 60 do
	local shape = Frontier.tear(seed, 6)
	local w = widths(shape)
	check(#shape.Spine == #shape.Left and #shape.Left == #shape.Right and #shape.Spine >= 6, "A tear's rows")
	check(w[1][1] + w[1][2] < 0.01 and w[#w][1] + w[#w][2] < 0.01, "A tear with blunt ends")
	local lopsided, wide = false, 0
	for i = 2, #w - 1 do
		check(w[i][1] >= 0 and w[i][2] >= 0, "A tear's lips cross")
		lopsided = lopsided or math.abs(w[i][1] - w[i][2]) > 0.15
		wide = math.max(wide, w[i][1] + w[i][2])
	end
	check(lopsided, "A symmetrical tear (seed " .. seed .. ")")
	check(wide > 1 and wide < 6, "A tear too thin or too wide")
	check(math.abs(shape.Spine[1].Y - 3) < 0.01 and math.abs(shape.Spine[#shape.Spine].Y + 3) < 0.01, "Its height")
	check(#shape.Branches >= 2 and #shape.Branches <= 4, "Its hairline cracks")
	check(math.abs(shape.Tilt) <= 0.35, "It leans too far")
end

-- Drawing a tear (the client's RiftTear: every piece from its shape) --------------------------------------
local clientEnv = setmetatable(table.clone(env), getmetatable(env))
clientEnv.game = {
	GetService = function()
		return { Shared = { Frontier = "Frontier" } }
	end,
}
clientEnv.Enum = roblox.Enum
clientEnv.script = { Parent = {} }
local function client(name)
	return luau.load(
		fs.readFile(ROOT .. "/src/client/Modules/" .. name .. ".luau"),
		{ debugName = name, environment = clientEnv }
	)()
end
local RiftTear = client("RiftTear")
local CFrame = roblox.CFrame
for seed = 1, 20 do
	local shape = Frontier.tear(seed * 31, 6)
	local plane = CFrame.new(10, 4, 20) * CFrame.Angles(0, 0.7, shape.Tilt)
	local shut = RiftTear.pieces(shape, 0, plane, 1)
	local half = RiftTear.pieces(shape, 0.5, plane, 1)
	local open = RiftTear.pieces(shape, 1, plane, 1)
	check(
		#shut == #open and #half == #open and #open == (#shape.Spine - 1) * 4 + #shape.Branches,
		"A tear's pieces change in number"
	)
	for _, piece in shut do
		check(piece.Transparency == 1, "A shut tear shows")
	end
	local voidHalf, voidOpen = 0, 0
	for k, piece in open do
		local at = plane:PointToObjectSpace(piece.CFrame.Position)
		check(math.abs(at.Z) <= 0.1, "A piece off the tear's plane")
		check(math.abs(at.Y) <= 3 + 0.6 and math.abs(at.X) <= 6, "A piece outside the tear")
		if k % 4 == 3 and k <= (#shape.Spine - 1) * 4 then
			check(piece.Transparency < 0.2, "The other side doesn't show through")
			voidOpen += piece.Size.X
			voidHalf += half[k].Size.X
		end
	end
	check(voidHalf < voidOpen * 0.7, "It doesn't open wider")
	-- Its lips are lit, and the same shape draws the same.
	check(open[1].Transparency == 0 and open[1].Color ~= open[3].Color, "Its lips aren't lit")
	check(RiftTear.pieces(shape, 1, plane, 1)[5].CFrame == open[5].CFrame, "The same tear draws differently")
end
local lips = RiftTear.layout(Frontier.tear(5, 6), 0)
check(lips.Left[3] == lips.Right[3], "A shut tear's lips apart")

-- The banners as you cross between bands.
local FrontierHud = client("FrontierHud")
for _, band in Frontier.BandOrder do
	local lines = FrontierHud.Lines[band]
	check(lines and #lines[1] > 0 and #lines[2] > 0 and lines[1] == string.upper(lines[1]), band .. " has no banner")
end

print(
	string.format("PASS: %d frontier checks (bands, candy trails, veins, pressure, rifts, tears, drawing them)", checks)
)
