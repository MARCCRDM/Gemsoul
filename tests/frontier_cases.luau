-- lune run tests/frontier_cases.luau <repo>
-- The Outpost's frontier (Shared.Frontier): the bands, the outcrops (natural
-- seams, bigger further out, lone rocks and stepping stones between, a rich
-- ground field), the Rift Veins (sites round the walls, six rocks each,
-- far apart, where one moves next, compass points), richer rocks outward
-- (Shared.Outpost.Zones: the same mix everywhere, more luck), mining noise and incursions, stirring the
-- frontier up (it builds with swings, settles when you stop, and brings more, higher-levelled critters), fair shares,
-- critter levels and EXP, where rifts open (wandering ones too), their
-- timeline, their ragged, lopsided tears, and the HUD's banners and arrows
-- (no noise ring).
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
-- only, the same mix everywhere (bigger rocks out there would only cost
-- more swings per gem), with much more luck the further out.
local lastLuck = -1
for _, zone in { "Common", "Fringe", "Edge", "Vein" } do
	local spec = Outpost.Zones[zone]
	check(spec, zone .. " isn't a zone")
	for size in spec.Weights do
		check(size == "Pebble" or size == "Boulder", zone .. " grows a " .. size .. " in the lobby")
	end
	check(spec.Weights.Pebble == Outpost.Zones.Common.Weights.Pebble, zone .. "'s mix isn't the core's")
	check(spec.Weights.Boulder == Outpost.Zones.Common.Weights.Boulder, zone .. "'s mix isn't the core's")
	check((spec.Luck or 0) > lastLuck, zone .. " isn't richer than the zone inside it")
	lastLuck = spec.Luck or 0
end
local zones = Outpost.Zones
check(zones.Fringe.Luck == 0.2 and zones.Edge.Luck == 0.4 and zones.Vein.Luck == 0.75, "The luck steps")
check(Frontier.zoneOf(10) == "Common" and Frontier.zoneOf(200) == "Fringe", "Zones by distance")
check(Frontier.zoneOf(350) == "Edge" and Frontier.zoneOf(350, true) == "Vein", "The edge and its veins")
for band, spec in Frontier.Bands do
	local distance = if band == "Core" then 0 elseif band == "Fringe" then 200 else 350
	local zone = Outpost.Zones[if band == "Guarded" then "Guarded" else Frontier.zoneOf(distance, band == "Vein")]
	check(spec.Luck == (zone.Luck or 0), band .. "'s luck isn't its zone's")
end
-- The guarded vein: luckier still (+35% on a vein's), the same mix.
check(math.abs(zones.Guarded.Luck - zones.Vein.Luck - 0.35) < 1e-9, "The guarded vein isn't +35% on a vein")
check(zones.Guarded.Weights.Pebble == zones.Common.Weights.Pebble, "The guarded vein's mix isn't the core's")
check(Frontier.Veins.Guarded >= 1 and Frontier.Veins.Guarded <= Frontier.Veins.Count, "No vein is guarded")
local guardian = Frontier.Guardian
check(guardian.Levels[1] == 16 and guardian.Levels[2] == 20 and guardian.Wake == 3, "The guardian's levels and waking")
check(Frontier.Coins.Guardian == 40, "The guardian's coins")

-- Outcrops ----------------------------------------------------------------------------------------------
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
local function clearOfTheOutpost(p)
	if toRoad(p) < 14 then
		return false
	end
	for _, b in buildings do
		if (p - b[1]).Magnitude < b[2] then
			return false
		end
	end
	return true
end
local rng = Random.new(7)
-- The rich ground: soft, between 0 and 1, varying across the quarry.
local rich = Frontier.field(Random.new(3))
local low, high = 1, 0
for x = -400, 400, 40 do
	for z = -400, 400, 40 do
		local v = rich(Vector3.new(x, 0, z))
		check(v >= 0 and v <= 1, "The rich ground out of range")
		low, high = math.min(low, v), math.max(high, v)
	end
end
check(high - low > 0.5, "The ground is as rich everywhere")
local kept, outer, inner, grew = 0, {}, {}, {}
for seed = 1, 6 do
	local crops, lone = Frontier.outcrops(Random.new(seed * 11))
	local count = Frontier.Outcrop.Count
	check(#crops >= count - 2 and #crops <= count, "Not about 46 outcrops: " .. #crops)
	local rocks = 0
	for i, crop in crops do
		check(#crop.Rocks >= 2 and #crop.Rocks <= 5, "An outcrop of " .. #crop.Rocks)
		local r = flat(crop.Middle)
		check(r >= Frontier.Outcrop.From - 0.01 and r <= Frontier.Outcrop.To + 0.01, "An outcrop out of the frontier")
		for j = i + 1, #crops do
			local gap = (crop.Middle - crops[j].Middle).Magnitude
			check(gap >= Frontier.Outcrop.Apart - 0.01, "Two outcrops on top of each other")
		end
		-- A seam: its rocks in a line along its grain, a step or so apart.
		local along = Vector3.new(math.cos(crop.Grain), 0, math.sin(crop.Grain))
		for k, p in crop.Rocks do
			local inside = flat(p) <= Frontier.Outcrop.To + 0.01 and flat(p) < Frontier.Rim
			check(p.Y == 0 and inside, "A rock past the walls")
			local off = (p - crop.Middle) - along * (p - crop.Middle):Dot(along)
			check(off.Magnitude < 4, "An outcrop's rock off its grain")
			if k > 1 then
				local step = (p - crop.Rocks[k - 1]).Magnitude
				check(step > 12 and step < 17 or step > 22, "An outcrop's rocks " .. step .. " apart")
			end
			rocks += 1
			if clearOfTheOutpost(p) then
				kept += 1
			end
		end
		table.insert(if r > 330 then outer else inner, #crop.Rocks)
	end
	-- Lone rocks between: about 15% of the frontier's, a few at the spokes'
	-- mouths leading out of the core (beside the road, not on it).
	local stones = 0
	for _, p in lone do
		local r = flat(p)
		check(r >= Frontier.Outcrop.From - 0.01 and r <= Frontier.Outcrop.To + 0.01, "A lone rock out of place")
		for _, a in Frontier.Spokes do
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local along = p:Dot(out)
			local off = (p - out * along).Magnitude
			if along > Frontier.Core and along < Frontier.Core + 35 and off >= 19.9 and off <= 30.1 then
				stones += 1
			end
		end
		if clearOfTheOutpost(p) then
			kept += 1
		end
	end
	local share = #lone / (#lone + rocks)
	check(share > 0.1 and share < 0.2, "Lone rocks aren't about 15%: " .. share)
	check(stones >= Frontier.Outcrop.Stones, "No stepping stones out of the core")
	table.insert(grew, #lone + rocks)
end
local function mean(list)
	local sum = 0
	for _, v in list do
		sum += v
	end
	return sum / math.max(1, #list)
end
check(mean(outer) > mean(inner) + 0.4, "Outcrops aren't bigger further out")
-- About as many rocks as the six trails had (the same budget), after the
-- roads and buildings take theirs.
check(kept / 6 >= 95 and kept / 6 <= 140, "Not about the frontier's number of rocks: " .. kept / 6)
check(#Frontier.outcrops(Random.new(5)) == #Frontier.outcrops(Random.new(5)), "Outcrops differ from one seed")

-- Rift Veins -----------------------------------------------------------------------------------------------
local sites = Frontier.veinSites(rng)
check(#sites == Frontier.Veins.Sites, "Not every vein site")
for i, angle in sites do
	local rocks, scar = Frontier.veinAt(angle, rng)
	check(#rocks == Frontier.Veins.Rocks, "A vein without its six rocks")
	check(flat(scar) >= Frontier.Rim and flat(scar) < 440, "A vein's rift isn't by the walls")
	for k, p in rocks do
		check(flat(p) < Frontier.Rim and flat(p) > Frontier.EdgeFrom, "A vein rock out of the edge")
		check((p - scar).Magnitude < 45, "A vein rock far from its rift")
		for j = k + 1, #rocks do
			check((p - rocks[j]).Magnitude >= 11.5, "Vein rocks on top of each other")
		end
	end
	if i > 1 then
		check(Frontier.apart(angle, sites[i - 1]) > 0.2, "Two vein sites together")
	end
end
check(math.abs(Frontier.apart(0.1, math.pi * 2 - 0.1) - 0.2) < 1e-9, "Angles apart across east")
check(math.abs(Frontier.apart(0, math.pi) - math.pi) < 1e-9, "Opposite angles")
-- Three far apart, and where one goes next: away from the other two, never
-- a site that's taken.
local taken, angles = {}, {}
for _ = 1, Frontier.Veins.Count do
	local index = Frontier.pickSite(sites, taken, angles, rng)
	check(index ~= nil, "No room for three veins")
	for _, other in angles do
		check(Frontier.apart(sites[index], other) >= Frontier.Veins.Apart, "Two veins together")
	end
	taken[index] = true
	table.insert(angles, sites[index])
end
for _ = 1, 50 do
	local index = Frontier.pickSite(sites, taken, { angles[2], angles[3] }, rng)
	check(index and not taken[index], "A vein moved onto a taken site")
	check(
		Frontier.apart(sites[index], angles[2]) >= Frontier.Veins.Apart
			and Frontier.apart(sites[index], angles[3]) >= Frontier.Veins.Apart,
		"A vein moved next to another"
	)
end
local all = {}
for i in sites do
	all[i] = true
end
check(Frontier.pickSite(sites, all, {}, rng) == nil, "A site found with every one taken")
check(Frontier.compass(0) == "east" and Frontier.compass(math.pi / 2) == "south", "The compass")
check(Frontier.compass(math.pi * 1.5) == "north", "The compass's north")
check(Frontier.compass(-math.pi / 4) == "north-east", "The compass's north-east")

-- Mining noise and incursions -----------------------------------------------------------------------------
-- (An encounter at 1: swings make it, the edge's more; a second out there a
-- little; the core nothing.)
check(Frontier.noise(0.3, "Core", 10, 60) == 0.3, "The core makes noise")
local function swingsTo(band, roll)
	local noise, swings = 0, 0
	while noise < 1 and swings < 500 do
		noise = Frontier.noise(noise, band, 1, 0, roll)
		swings += 1
	end
	return swings
end
check(swingsTo("Fringe", 0.5) >= 30 and swingsTo("Fringe", 0.5) <= 40, "Not about 1 in 35 swings in the fringe")
check(swingsTo("Edge", 0.5) >= 15 and swingsTo("Edge", 0.5) <= 20, "Not about 1 in 17 swings at the edge")
check(swingsTo("Fringe", 0) > swingsTo("Fringe", 1), "Each swing's share doesn't vary")
local function secondsIdle(band)
	local noise, t = 0, 0
	while noise < 1 and t < 3600 do
		noise = Frontier.noise(noise, band, 0, 1)
		t += 1
	end
	return t
end
check(math.abs(secondsIdle("Fringe") - 420) <= 2 and math.abs(secondsIdle("Edge") - 180) <= 2, "The idle trickle")
check(Frontier.noise(0, "Edge", 3, 0, 0.5) > Frontier.noise(0, "Edge", 1, 0, 0.5) * 2.9, "A mech's strike of 3 swings")
check(Frontier.incursion("Core", 0.5) == 0, "Critters in the core")
for roll = 0, 0.99, 0.01 do
	local fringe, edge = Frontier.incursion("Fringe", roll), Frontier.incursion("Edge", roll)
	-- (A swarm: three or four in the fringe, five or six at the edge.)
	check(fringe >= 3 and fringe <= 4 and fringe <= Frontier.Caps.Fringe, "A fringe incursion's size")
	check(edge >= 5 and edge <= 6 and edge <= Frontier.Caps.Edge, "An edge incursion's size")
end
check(Frontier.Caps.Edge > Frontier.Caps.Fringe and Frontier.Caps.Server >= Frontier.Caps.Edge * 3, "The caps")
check(Frontier.Boost.Edge.Health > 1 and Frontier.Boost.Edge.Exp > 1, "Edge critters aren't worth more")
-- A fair share of the Outpost's: the band's cap with few out there, a
-- slice of the Outpost's with many, never none.
check(Frontier.share(Frontier.Caps.Edge, 1) == Frontier.Caps.Edge, "One player's share isn't the band's cap")
check(Frontier.share(Frontier.Caps.Edge, 6) == math.floor(Frontier.Caps.Server / 6), "Six out there don't get a sixth each")
check(Frontier.share(Frontier.Caps.Edge, 30) == 1, "A crowd left someone with none")

-- Stirring it up: the longer you mine, the harder it pushes back ------------------------------------------
local D = Frontier.Disturbance
local function swingsToStir(band, to)
	local stir, swings = 0, 0
	while stir < to and swings < 5000 do
		stir = Frontier.stir(stir, band, 1)
		swings += 1
	end
	return swings
end
check(Frontier.stir(0.4, "Core", 50) == 0.4, "Swinging in the core stirred it up")
check(math.abs(swingsToStir("Fringe", 1) - 400) <= 1, "Not about 400 swings to stir the fringe up")
check(math.abs(swingsToStir("Edge", 1) - 250) <= 1, "Not about 250 swings to stir the edge up")
check(Frontier.stir(0.9, "Edge", 500) == 1, "Stirred past full")
check(math.abs(Frontier.stir(0, "Edge", 3) - 3 * D.PerSwing.Edge) < 1e-9, "A mech's strike of 3 swings")
-- It holds while you keep at it, settles once you stop (only the seconds
-- past the rest), and faster back in the core.
check(Frontier.settle(0.6, "Edge", 0.5, 3) == 0.6, "It settled mid-mining")
check(Frontier.settle(0.6, "Fringe", 0.5, D.Rest - 0.1) == 0.6, "It settled before the rest was up")
check(
	math.abs(Frontier.settle(0.6, "Fringe", 1, D.Rest + 0.25) - (0.6 - D.Fade * 0.25)) < 1e-9,
	"Only the seconds past the rest"
)
check(
	math.abs(Frontier.settle(0.6, "Edge", 1, D.Rest + 10) - (0.6 - D.Fade)) < 1e-9,
	"It didn't settle once you stopped"
)
check(math.abs(Frontier.settle(0.6, "Core", 1, 0) - (0.6 - D.CoreFade)) < 1e-9, "The core didn't settle it at once")
check(Frontier.settle(0.01, "Core", 10, 0) == 0 and Frontier.settle(0.01, "Edge", 10, 999) == 0, "Settled past calm")
local function secondsToSettle(band)
	local stir, t = 1, 0
	while stir > 0 and t < 3600 do
		stir = Frontier.settle(stir, band, 0.5, D.Rest + t)
		t += 0.5
	end
	return t
end
check(math.abs(secondsToSettle("Fringe") - 1 / D.Fade) <= 1, "Not about two minutes to settle out there")
check(math.abs(secondsToSettle("Core") - 1 / D.CoreFade) <= 1, "Not about half a minute to settle in the core")
check(1 / D.CoreFade < 1 / D.Fade, "The core doesn't settle it sooner")
-- Its stages, in order.
check(Frontier.stage(0) == 1 and Frontier.stage(nil) == 1 and Frontier.stage(1) == #D.Stages, "The stages' ends")
local lastAt, lastExtra, lastCap = -1, -1, -1
for i, stage in D.Stages do
	check(stage.At > lastAt and stage.Extra >= lastExtra and stage.Cap >= lastCap, "Stage " .. i .. " out of order")
	check(Frontier.stage(stage.At) == i, "Stage " .. i .. " doesn't start at its At")
	check(i == 1 or Frontier.stage(stage.At - 0.001) == i - 1, "Stage " .. i .. " starts early")
	check(type(stage.Name) == "string" and #stage.Name > 0, "Stage " .. i .. " has no name")
	lastAt, lastExtra, lastCap = stage.At, stage.Extra, stage.Cap
end
local _, top = Frontier.stage(1)
check(top.Extra >= 2 and top.Cap >= 2, "Swarming isn't much harder")
-- Stirred up: encounters sooner (twice as often, full), more critters at
-- once and more allowed round you (never in the core), higher-levelled.
local function swingsToStirred(band, stir)
	local noise, swings = 0, 0
	while noise < 1 and swings < 500 do
		noise = Frontier.noise(noise, band, 1, 0, 0.5, stir)
		swings += 1
	end
	return swings
end
check(swingsToStirred("Fringe", 0) == swingsTo("Fringe", 0.5), "A calm frontier's noise changed")
check(
	math.abs(swingsToStirred("Fringe", 1) - swingsTo("Fringe", 0.5) / 2) <= 1,
	"Full, encounters aren't twice as often"
)
check(swingsToStirred("Edge", 0.5) < swingsTo("Edge", 0.5), "Stirred up, swings aren't louder")
check(Frontier.noise(0.2, "Core", 10, 60, 0.5, 1) == 0.2, "A stirred-up core made noise")
check(
	Frontier.noise(0, "Edge", 0, 10, nil, 1) == Frontier.noise(0, "Edge", 0, 10),
	"Standing about stirred up got louder"
)
for roll = 0, 0.99, 0.05 do
	for i, stage in D.Stages do
		check(
			Frontier.incursion("Fringe", roll, stage.At) == Frontier.incursion("Fringe", roll) + stage.Extra,
			"Fringe at stage " .. i
		)
		check(
			Frontier.incursion("Edge", roll, stage.At) == Frontier.incursion("Edge", roll) + stage.Extra,
			"Edge at stage " .. i
		)
		check(Frontier.incursion("Core", roll, stage.At) == 0, "Critters in a stirred-up core")
	end
	check(Frontier.incursion("Edge", roll, 1) <= Frontier.capFor("Edge", 1), "A swarming encounter past its cap")
	check(
		Frontier.incursion("Fringe", roll, 1) <= Frontier.capFor("Fringe", 1),
		"A swarming fringe encounter past its cap"
	)
end
check(
	Frontier.capFor("Fringe") == Frontier.Caps.Fringe and Frontier.capFor("Edge", 0.1) == Frontier.Caps.Edge,
	"A calm cap"
)
check(Frontier.capFor("Edge", 1) == Frontier.Caps.Edge + top.Cap, "A swarming cap")
check(Frontier.capFor("Core", 1) == 0, "Critters allowed in the core")
check(Frontier.capFor("Edge", 1) * 2 <= Frontier.Caps.Server, "Two swarming miners fill the Outpost")
check(
	Frontier.critterLevel("Fringe", nil, 0) == 1 and Frontier.critterLevel("Fringe", nil, 1) == 1 + D.Levels,
	"Levels when stirred"
)
check(Frontier.critterLevel("Edge", nil, 0.5) == 9 + math.floor(D.Levels / 2), "Halfway, half the levels")
check(Frontier.critterLevel("Edge", nil, 7) == 9 + D.Levels, "More than full stirred")

-- Critters by band: levels, EXP, coins -----------------------------------------------------------------------
for _ = 1, 100 do
	local fringe, edge = Frontier.critterLevel("Fringe", rng), Frontier.critterLevel("Edge", rng)
	check(fringe >= 1 and fringe <= 4, "A fringe critter's level")
	check(edge >= 9 and edge <= 13, "An edge critter's level")
end
-- (One of a swarm: a swarm's worth about what one critter was.)
check(Frontier.critterExp(1, "Fringe", 0) == 2, "A level-1 critter's EXP")
check(Frontier.critterExp(10, "Fringe", 0) == 7, "A level-10 critter's EXP")
check(Frontier.critterExp(10, "Edge", 0) == 10, "An edge critter isn't worth half again")
check(Frontier.critterExp(10, "Edge", Frontier.Exp.Daily) == 2, "No quarter after the day's critters")
-- A swarm trickles in: a critter out of each tear, the tears a second or
-- more apart, never all at once; a wandering rift's critters out one by one.
local swarm = Frontier.Swarm
check(swarm.PerRift == 1 and swarm.Last > swarm.Stagger and swarm.Out >= 0.5, "The swarm's timing")
check(swarm.Every[1] >= 1 and swarm.Every[2] >= swarm.Every[1], "A swarm's tears open too close together")
for _ = 1, 50 do
	local times = Frontier.trickle(6, rng)
	check(#times == 6 and times[1] == 0, "A swarm's first tear waits")
	for i = 2, 6 do
		local gap = times[i] - times[i - 1]
		check(gap >= swarm.Every[1] - 1e-9 and gap <= swarm.Every[2] + 1e-9, "Tears not a second or so apart: " .. gap)
	end
end
check(#Frontier.trickle(0, rng) == 0 and Frontier.trickle(1).Count == nil, "A swarm of none")
check(Frontier.critterExp(1, "Fringe", 999) >= 1, "A critter worth nothing")
check(Frontier.Coins.Edge > Frontier.Coins.Fringe and Frontier.Coins.Guardian > Frontier.Coins.Edge, "Coins by band")
check(Frontier.Bonk.Share > 0 and Frontier.Bonk.Share < 0.2 and Frontier.Bonk.Offer < Frontier.Bonk.Reach, "The bonk")
check(Frontier.Rift.Hop >= 1.5, "Under a second and a half's warning before a critter hops out")

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
-- Well apart: a tear opens Rift.Apart studs or more from those still open
-- round them (three at most at once: Swarm.Every apart, each gone in under
-- four seconds); crowded, as far from them as it can.
check(Frontier.Rift.Apart >= 14 and Frontier.Rift.Near >= 16, "Tears too close together")
local life = Frontier.Rift.Hop + Frontier.Rift.Linger + Frontier.Rift.Close
check(math.ceil(life / Frontier.Swarm.Every[1]) <= 4, "More than three of a swarm's tears open at once")
for _ = 1, 300 do
	local open = {}
	for _ = 1, 3 do
		local spot = Frontier.riftSpot(player, east * 16, center, rng, open)
		for _, other in open do
			check(flat(spot - other) >= Frontier.Rift.Apart - 0.01, "A tear opened on top of another")
		end
		local away = spot - player
		check(
			flat(away) >= Frontier.Rift.Near - 0.01 and flat(away) <= Frontier.Rift.Far + 0.01,
			"A spaced tear too near or far"
		)
		table.insert(open, spot)
	end
end
-- And a swarm's tears spread out over the whole swarm: a new one keeps
-- clear of those already sealed too, where it can (not opening where one
-- just shut), though the open ones come first.
do
	local close, encounters = 0, 300
	for _ = 1, encounters do
		local times, tears = Frontier.trickle(6, rng), {}
		for i, at in times do
			local open, sealed = {}, {}
			for _, tear in tears do
				table.insert(if tear.At + life > at then open else sealed, tear.Spot)
			end
			local spot = Frontier.riftSpot(player, east * 16, center, rng, open, sealed)
			if #open < 3 then
				for _, other in open do
					check(flat(spot - other) >= Frontier.Rift.Apart - 0.01, "A swarm's tear opened on an open one")
				end
			end
			if i == 2 then
				check(flat(spot - tears[1].Spot) >= Frontier.Rift.Apart - 0.01, "A swarm's second tear by its first")
			end
			tears[i] = { Spot = spot, At = at }
		end
		local nearest = math.huge
		for i = 1, #tears do
			for j = i + 1, #tears do
				nearest = math.min(nearest, flat(tears[i].Spot - tears[j].Spot))
			end
		end
		close += nearest
	end
	check(close / encounters >= 10, "A swarm's tears bunch up over the swarm: " .. close / encounters)
end
-- Only on ground the server can use (`usable`: here, not on a stack of
-- containers in front of them), even when that's the emptiest spot about.
do
	local function onStack(p)
		return p.X > player.X + 12 and p.X < player.X + 26 and math.abs(p.Z - player.Z) < 5
	end
	local function usable(p)
		return not onStack(p)
	end
	for _ = 1, 300 do
		local tears = {}
		for _ = 1, 6 do
			local spot = Frontier.riftSpot(player, east * 16, center, rng, tears, tears, usable)
			check(spot ~= nil and not onStack(spot), "A tear opened on ground the server can't use")
			table.insert(tears, spot)
		end
	end
	check(Frontier.riftSpot(player, east * 16, center, rng, nil, nil, function()
		return false
	end) == nil, "A tear opened where nothing was usable")
end
local crowd = {}
for a = 0, 35 do
	local angle = math.rad(a * 10)
	for _, r in { 16, 22, 28 } do
		table.insert(crowd, player + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r)
	end
end
check(Frontier.riftSpot(player, east * 16, center, rng, crowd) ~= nil, "No tear where it's crowded")
-- Wandering rifts: Near to Far from whoever they're tied to, any way round,
-- never in the core or the walls.
local ways = {}
for _ = 1, 200 do
	local spot = Frontier.wanderSpot(player, center, rng)
	local away = flat(spot - player)
	local r = Frontier.distance(spot, center)
	check(r >= Frontier.Core - 0.01 and r <= Frontier.Rim + 0.01, "A wandering rift in the core or the walls")
	check(away <= Frontier.Wander.Far + 0.01, "A wandering rift too far off")
	if r > Frontier.Core + 1 and r < Frontier.Rim - 1 then
		check(away >= Frontier.Wander.Near - 0.01, "A wandering rift too close")
	end
	ways[if spot.X > player.X then "east" else "west"] = true
end
check(ways.east and ways.west, "Wandering rifts only open one way")
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
local lingering = Frontier.timeline(100, 4)
check(lingering.CloseAt - lingering.HopAt == 4 and lingering.HopAt == life.HopAt, "A wandering rift doesn't linger")

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
		return { Shared = { Frontier = "Frontier", Outpost = "Outpost" } }
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

-- The Loop: four biomes round the core, about a quarter each between the
-- four spokes (due north, east, south, west), their borders swaying off
-- them further out, each weak to the one before it going round clockwise;
-- out there their element comes up more, and their own ground.
;(function()
	local Beats = shared("ElementMatchup").Beats
	check(#Frontier.Biomes == 4 and #Frontier.Spokes == 4, "Not four biomes between four spokes")
	local north, east, south, west = Frontier.Spokes[1], Frontier.Spokes[2], Frontier.Spokes[3], Frontier.Spokes[4]
	check(math.sin(north) < -0.99 and math.cos(east) > 0.99 and math.sin(south) > 0.99 and math.cos(west) < -0.99, "The spokes aren't due north, east, south and west")
	local elements, names = {}, {}
	for i, biome in Frontier.Biomes do
		elements[biome.Element] = true
		names[biome.Id] = true
		check(Frontier.biomeOf(biome.Angle) == biome, biome.Id .. " isn't its own middle's")
		local before = Frontier.Biomes[(i - 2) % 4 + 1]
		check(Beats[before.Element] == biome.Element, biome.Id .. " isn't weak to the biome before it")
		check(biome.Name and biome.Material, biome.Id .. " is missing its name or look")
		-- (No sign and no banner names it: the ground says where you are.)
		check(biome.Label == nil and biome.Line == nil, biome.Id .. " still has a sign or a banner line")
		check(biome.Glow and biome.Tint and biome.Ambient and biome.Fog and biome.Ground and biome.Stone, biome.Id .. " is missing a colour")
		local ground = biome.Terrain
		check(ground and ground.Main and ground.Second and ground.Main ~= ground.Second, biome.Id .. " has no ground of its own")
		check(Frontier.Ground.Colors[ground.Main] and Frontier.Ground.Colors[ground.Second], biome.Id .. "'s ground has no colour")
		-- (Its quarter is the one between two spokes, its middle between them.)
		for _, a in Frontier.Spokes do
			check(Frontier.apart(a, biome.Angle) > math.pi / 4 - 1e-6, biome.Id .. " sits on a spoke")
		end
	end
	check(elements.Fire and elements.Frost and elements.Shock and elements.Poison, "Not one biome per element")
	check(names.Ashfall and names.Rimefrost and names.Stormglass and names.Blightwood, "The biomes' names")
	-- North-east Ashfall (Thermal), then clockwise Rimefrost, Stormglass, Blightwood.
	local function at(angle, r)
		return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
	end
	check(Frontier.biomeAt(at(-math.pi / 4, 250)).Id == "Ashfall", "North-east isn't Ashfall")
	check(Frontier.biomeAt(at(math.pi / 4, 250)).Id == "Rimefrost", "South-east isn't Rimefrost")
	check(Frontier.biomeAt(at(3 * math.pi / 4, 250)).Id == "Stormglass", "South-west isn't Stormglass")
	check(Frontier.biomeAt(at(-3 * math.pi / 4, 250)).Id == "Blightwood", "North-west isn't Blightwood")
	check(Frontier.biomeAt(at(0.4, Frontier.Core - 1)) == nil and Frontier.biomeAt(Vector3.zero) == nil, "A biome in the core")
	check(Frontier.biomeAt(at(0.4, Frontier.Core + 1)) ~= nil, "No biome just out of the core")
	-- The borders: on the spokes at their mouths,
	-- swaying off them further out, each its own way (no two alike, so the
	-- biomes aren't mirror images), never into the next biome's middle.
	local ground = Frontier.Ground
	local swayed = {}
	for k, spoke in Frontier.Spokes do
		check(math.abs(Frontier.border(k, Frontier.Core + ground.Calm[1]) - spoke) < 1e-9, "Border " .. k .. " off its spoke at the mouth")
		local most = 0
		for r = Frontier.Core, ground.Reach, 4 do
			local off = math.abs(Frontier.border(k, r) - spoke)
			most = math.max(most, off)
			check(off < math.pi / 4 - 0.15, "Border " .. k .. " swings into a biome's middle")
		end
		check(most > math.rad(6), "Border " .. k .. " runs straight down its spoke")
		swayed[k] = Frontier.border(k, 380) - spoke
	end
	for k = 2, #swayed do
		check(math.abs(swayed[k] - swayed[1]) > 0.02, "Borders " .. k .. " and 1 sway alike")
	end
	-- Crossing a border changes biome; on one, the look's an even mix, and
	-- a seam's width either side it's all one biome's again.
	for k in Frontier.Spokes do
		for _, r in { 220, 300, 380 } do
			local b = Frontier.border(k, r)
			local left, right = Frontier.biomeAt(at(b - 0.03, r)), Frontier.biomeAt(at(b + 0.03, r))
			check(left ~= right and right == Frontier.Biomes[k], "No change of biome across border " .. k)
			local weights = Frontier.biomeMix(at(b, r))
			local sum, halves = 0, 0
			for _, w in weights do
				sum += w
				if math.abs(w - 0.5) < 1e-4 then -- (Vector3's floats: a hair off the line)
					halves += 1
				end
			end
			check(math.abs(sum - 1) < 1e-6 and halves == 2, "Not an even mix on border " .. k)
			local beyond = (ground.Seam[2] + 1) / r
			check(Frontier.biomeMix(at(b + beyond, r))[k] == 1, "A seam wider than Seam on border " .. k)
		end
	end
	-- The ground (Roblox terrain): the core's regolith in the core, each
	-- biome's own deep in it, both neighbours' in blotches across a seam,
	-- the land flat in the core and never higher than the biome's Height.
	do
		local rng = Random.new(31)
		local function isHub(material)
			return material == ground.Hub.Main or material == ground.Hub.Second
		end
		for _, p in { { 0, 0 }, { 60, -40 }, { -90, 70 }, { 30, 110 } } do
			local material, whose, rise = Frontier.ground(p[1], p[2])
			check(isHub(material) and whose == 0 and rise == 0, "The core isn't regolith, flat")
		end
		for index, biome in Frontier.Biomes do
			local own, mains, seconds = 0, 0, 0
			for _ = 1, 400 do
				local a = biome.Angle + rng:NextNumber(-0.25, 0.25)
				local r = rng:NextNumber(Frontier.Core + 60, ground.Reach - 10)
				local x, z = math.cos(a) * r, math.sin(a) * r
				local material, whose, rise = Frontier.ground(x, z)
				check(rise >= 0 and rise <= biome.Terrain.Height + 1e-9, biome.Id .. "'s land too high")
				if Frontier.biomeMix(at(a, r))[index] == 1 then
					check(whose == index, "Another's ground deep in " .. biome.Id)
					own += 1
					if material == biome.Terrain.Main then
						mains += 1
					elseif material == biome.Terrain.Second then
						seconds += 1
					end
				end
			end
			check(own > 200 and mains > own * 0.35 and seconds > own * 0.12, biome.Id .. "'s ground isn't its two materials: " .. mains .. "/" .. seconds)
			-- Across its start border, both its ground and the one before's.
			local before = (index - 2) % #Frontier.Biomes + 1
			local seen = {}
			for _ = 1, 300 do
				local r = rng:NextNumber(Frontier.Core + 80, ground.Reach - 20)
				local b = Frontier.border(index, r)
				local _, whose = Frontier.ground(math.cos(b + rng:NextNumber(-0.04, 0.04)) * r, math.sin(b + rng:NextNumber(-0.04, 0.04)) * r)
				seen[whose] = true
			end
			check(seen[index] and seen[before], "No mixing across " .. biome.Id .. "'s border")
		end
		local a1, b1, c1 = Frontier.ground(123.4, -321.5)
		local a2, b2, c2 = Frontier.ground(123.4, -321.5)
		check(a1 == a2 and b1 == b2 and c1 == c2, "The ground isn't the same twice")
	end
	for _, biome in Frontier.Biomes do
		local weights, inward = Frontier.biomeMix(at(biome.Angle, 300))
		check(math.abs(weights[table.find(Frontier.Biomes, biome)] - 1) < 1e-6 and inward == 1, biome.Id .. "'s middle isn't all its own")
	end
	local _, deep = Frontier.biomeMix(at(1, Frontier.Core - Frontier.Biome.Blend))
	local _, edge = Frontier.biomeMix(at(1, Frontier.Core))
	check(deep == 0 and math.abs(edge - 0.5) < 1e-6, "The look doesn't come in at the core's edge")
	-- An element out there: its own Bias of the time, the rest alike; in the core, any alike.
	local rng = Random.new(77)
	for _, biome in Frontier.Biomes do
		local counts, n = {}, 20000
		for _ = 1, n do
			local e = Frontier.pickElement(biome.Element, rng)
			counts[e] = (counts[e] or 0) + 1
		end
		check(math.abs(counts[biome.Element] / n - Frontier.Biome.Bias) < 0.015, biome.Id .. "'s element isn't " .. Frontier.Biome.Bias)
		for e, c in counts do
			if e ~= biome.Element then
				check(math.abs(c / n - (1 - Frontier.Biome.Bias) / 3) < 0.015, "The others aren't alike in " .. biome.Id)
			end
		end
	end
	local plain, n = {}, 20000
	for _ = 1, n do
		local e = Frontier.pickElement(nil, rng)
		plain[e] = (plain[e] or 0) + 1
	end
	for _, e in { "Fire", "Frost", "Shock", "Poison" } do
		check(math.abs(plain[e] / n - 0.25) < 0.015, "The core's elements aren't alike: " .. e)
	end
	-- A mined gem leans the same way (GemRoller.roll with a home); without one, as before.
	local GemRoller = shared("GemRoller")
	local mined = {}
	for _ = 1, 8000 do
		local gem = GemRoller.roll(rng, 0, nil, GemRoller.MiningWeights, "Frost", Frontier.Biome.Bias)
		mined[gem.Element] = (mined[gem.Element] or 0) + 1
	end
	check(math.abs(mined.Frost / 8000 - Frontier.Biome.Bias) < 0.02, "Gems mined in Rimefrost aren't mostly Cryo")
	check(GemRoller.roll(Random.new(5), 0).Element == GemRoller.roll(Random.new(5), 0).Element, "A plain roll isn't what it was")
end)()

-- No title card as you cross into a band or a biome (THE FRINGE, STORMGLASS
-- and the rest): the ground, the light and the critters say where you are.
-- The Rift Vein news is still a banner.
local FrontierHud = client("FrontierHud")
check(FrontierHud.Lines == nil and FrontierHud.biomeLines == nil, "The zones still have title cards")
do
	local hud = fs.readFile(ROOT .. "/src/client/Modules/FrontierHud.luau")
	check(
		hud:find('GetAttributeChangedSignal("FrontierBand")', 1, true) == nil
			and hud:find('GetAttributeChangedSignal("FrontierBiome")', 1, true) == nil,
		"Crossing into a band or a biome still shows a banner"
	)
	check(hud:find('showLines({ "RIFT VEIN", news }', 1, true) ~= nil, "The Rift Vein news lost its banner")
	local world = fs.readFile(ROOT .. "/src/server/World/OutpostWorld.luau")
	check(world:find("crossroads", 1, true) == nil and world:find("biome.Label", 1, true) == nil, "The biome signs are back by the roads")
end
-- The noise ring and stirred-up meter are off the HUD (the screen stays
-- the game's); each stage past calm still has its note.
check(FrontierHud.lit == nil and FrontierHud.stirRow == nil, "The noise ring is back on the HUD")
do
	local tint, ambient = roblox.Color3.fromRGB(248, 250, 255), roblox.Color3.fromRGB(150, 156, 176)
	local function near(a, b)
		return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
	end
	local haze = roblox.Color3.fromRGB(86, 92, 110)
	local inT, inA, inF = FrontierHud.biomeLight(Vector3.new(20, 0, 10), tint, ambient, haze)
	check(near(inT, tint) and near(inA, ambient) and near(inF, haze), "The core's light and fog aren't the Outpost's")
	for _, biome in Frontier.Biomes do
		local t, a, f =
			FrontierHud.biomeLight(Vector3.new(math.cos(biome.Angle) * 300, 0, math.sin(biome.Angle) * 300), tint, ambient, haze)
		check(near(t, biome.Tint) and near(a, biome.Ambient) and near(f, biome.Fog), biome.Id .. "'s light or fog isn't its own")
	end
	local first, second = Frontier.Biomes[1], Frontier.Biomes[2]
	local b = Frontier.border(2, 300)
	local t, _, f = FrontierHud.biomeLight(Vector3.new(math.cos(b) * 300, 0, math.sin(b) * 300), tint, ambient, haze)
	check(near(t, first.Tint:Lerp(second.Tint, 0.5)) and near(f, first.Fog:Lerp(second.Fog, 0.5)), "The light across a border isn't half and half")
end
for i in Frontier.Disturbance.Stages do
	check(i == 1 or Frontier.Disturbance.Notes[i] ~= nil, "Nobody's told of stage " .. i)
end
-- Arrows for rifts off screen: on the screen's edge, pointing at it.
local screen = Vector2.new(1000, 600)
local at, angle = FrontierHud.edge(screen, Vector2.new(3000, 300), 40)
check(
	math.abs(at.X - 960) < 0.01 and math.abs(at.Y - 300) < 0.01 and math.abs(angle) < 1e-6,
	"An arrow off to the right"
)
at, angle = FrontierHud.edge(screen, Vector2.new(500, -900), 40)
check(math.abs(at.Y - 40) < 0.01 and math.abs(angle + math.pi / 2) < 1e-6, "An arrow above")
at = FrontierHud.edge(screen, Vector2.new(-5000, 5000), 40)
check(at.X >= 39.9 and at.X <= 960.1 and at.Y >= 39.9 and at.Y <= 560.1, "An arrow off the screen")
-- The wild kaiju sighting: the nearest within reach, across the ground.
local spots = { Vector3.new(100, 0, 0), Vector3.new(0, 50, 40), Vector3.new(-300, 0, 0) }
local index, studs = FrontierHud.nearest(spots, Vector3.zero, FrontierHud.Sighting)
check(index == 2 and math.abs(studs - 40) < 1e-6, "The sighting isn't the nearest wild kaiju")
check(FrontierHud.nearest(spots, Vector3.new(-1000, 0, 0), FrontierHud.Sighting) == nil, "A sighting past its reach")
check(FrontierHud.nearest({}, Vector3.zero, 100) == nil, "A sighting with none about")
-- Gem raids: more critters stirred up, the haul newest first and only
-- what's still loose, a snatcher's rift off away from you, and one that
-- waits for it.
;
(function()
	local Raid = Frontier.Raid
	check(Frontier.raidSize(0) == Raid.Size and Frontier.raidSize(1) == Raid.Size + Raid.StirBonus, "Raid sizes")
	check(Frontier.raidSize(1) > Frontier.raidSize(0), "Stirred up, no bigger a raid")
	local haul = { { Id = "a" }, { Id = "b" }, { Id = "c" }, { Id = "d" } }
	local picked = Frontier.haulPick(haul, { a = true, b = true, d = true }, 2)
	check(#picked == 2 and picked[1] == "d" and picked[2] == "b", "Not the newest loose gems first")
	check(#Frontier.haulPick(haul, {}, 3) == 0, "Took a gem no longer loose")
	check(#Frontier.haulPick({}, { a = true }, 3) == 0, "Took from an empty haul")
	local middle = Vector3.new(0, 0, 0)
	local rng = Random.new(5)
	for _ = 1, 40 do
		local from = Vector3.new(220, 3, 10)
		local player = Vector3.new(215, 3, 10)
		local spot = Frontier.escapeSpot(from, player, middle, rng)
		local away = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z)
		check(away.Magnitude >= Raid.Carry.Away[1] * 0.5, "A snatcher's rift right where it stood")
		check(away.Unit:Dot(Vector3.new(1, 0, 0)) > 0, "A snatcher's rift back toward the player")
		local out = Frontier.distance(spot, middle)
		check(out >= Frontier.Core - 0.01 and out <= Frontier.Rim + 0.01, "A snatcher's rift outside the frontier")
	end
	local life = Frontier.timeline(100, 1.5, Raid.Carry.Wait)
	check(life.HopAt - life.OpenAt == Raid.Carry.Wait and life.CloseAt - life.HopAt == 1.5, "A rift that waits")
	check(Frontier.timeline(100).HopAt - 100 == Frontier.Rift.Hop, "A rift's usual wait changed")
end)()

-- Robbed while down: one robber for each gem there's to take (Crew at
-- most, one at least, less those already coming); their tears round you,
-- spread out; over once it's all taken (or nothing found), Settle later,
-- or when Hold runs out.
;(function()
	local Rob = Frontier.Rob
	check(Frontier.robCrew(0, 0) == 1, "Nobody comes to find nothing")
	check(Frontier.robCrew(2, 0) == 2 and Frontier.robCrew(2, 1) == 1 and Frontier.robCrew(2, 3) == 0, "Robbers for two gems")
	check(Frontier.robCrew(10, 0) == Rob.Crew, "More robbers than a crew")
	local rng = Random.new(8)
	for count = 1, Rob.Crew do
		for _ = 1, 30 do
			local at = Vector3.new(200, 3, -40)
			local spots = Frontier.robSpots(at, count, rng)
			check(#spots == count, "Not a tear for each robber")
			for i, spot in spots do
				local d = Vector3.new(spot.X - at.X, 0, spot.Z - at.Z).Magnitude
				check(d >= Rob.Out[1] - 1e-6 and d <= Rob.Out[2] + 1e-6, "A robber's tear off its ring: " .. d)
				check(spot.Y == at.Y, "A robber's tear off the floor")
				for j = i + 1, #spots do
					check((spot - spots[j]).Magnitude > 4, "Two robbers' tears on top of each other")
				end
			end
		end
	end
	local robbery = { EndAt = 100, Taken = 0, Max = 2 }
	check(not Frontier.robOver(robbery, 10), "Over before anything happened")
	robbery.Taken, robbery.LastAt = 1, 10
	check(not Frontier.robOver(robbery, 30), "Over with a gem still to take")
	robbery.Taken, robbery.LastAt = 2, 40
	check(not Frontier.robOver(robbery, 40 + Rob.Settle - 0.1), "Over the moment the last was taken")
	check(Frontier.robOver(robbery, 40 + Rob.Settle), "Not over once it settled")
	check(Frontier.robOver({ EndAt = 100, Taken = 0, Max = 3, Empty = true, LastAt = 5 }, 5 + Rob.Settle), "Not over with nothing found")
	check(Frontier.robOver({ EndAt = 100, Taken = 0, Max = 3 }, 100), "Not over when its time ran out")
end)()

print(
	string.format(
		"PASS: %d frontier checks (bands, the biomes, their swaying borders and their ground, the spokes, outcrops, veins, noise, stirring it up, shares, critters, rifts, tears, the HUD, gem raids, robbed while down)",
		checks
	)
)
