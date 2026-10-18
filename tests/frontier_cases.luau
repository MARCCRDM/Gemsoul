-- lune run tests/frontier_cases.luau <repo>
-- The Outpost's frontier (Shared.Frontier): the bands, the outcrops (natural
-- seams, bigger further out, lone rocks and stepping stones between, a rich
-- ground field), the Rift Veins (sites round the walls, six rocks each,
-- far apart, where one moves next, compass points), richer rocks outward
-- (Shared.Outpost.Zones: the same mix everywhere, more luck), mining noise and incursions, fair shares,
-- critter levels and EXP, where rifts open (wandering ones too), their
-- timeline, their ragged, lopsided tears, and the HUD's noise ring and
-- arrows.
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
	-- Lone rocks between: about 15% of the frontier's, a few leading out of the core.
	local stones = 0
	for _, p in lone do
		local r = flat(p)
		check(r >= Frontier.Outcrop.From - 0.01 and r <= Frontier.Outcrop.To + 0.01, "A lone rock out of place")
		if flat(p) < Frontier.Core + 25 then
			stones += 1
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
	check(fringe >= 1 and fringe <= Frontier.Caps.Fringe, "A fringe incursion's size")
	check(edge >= 2 and edge <= 3 and edge <= Frontier.Caps.Edge, "An edge incursion's size")
end
check(Frontier.Caps.Edge > Frontier.Caps.Fringe and Frontier.Caps.Server >= Frontier.Caps.Edge * 3, "The caps")
check(Frontier.Boost.Edge.Health > 1 and Frontier.Boost.Edge.Exp > 1, "Edge critters aren't worth more")
-- A fair share of the Outpost's: the band's cap with few out there, a
-- slice of 12 with many, never none.
check(Frontier.share(Frontier.Caps.Edge, 1) == Frontier.Caps.Edge, "One player's share isn't the band's cap")
check(Frontier.share(Frontier.Caps.Edge, 6) == 2, "Six out there don't get two each")
check(Frontier.share(Frontier.Caps.Edge, 30) == 1, "A crowd left someone with none")

-- Critters by band: levels, EXP, coins -----------------------------------------------------------------------
for _ = 1, 100 do
	local fringe, edge = Frontier.critterLevel("Fringe", rng), Frontier.critterLevel("Edge", rng)
	check(fringe >= 1 and fringe <= 4, "A fringe critter's level")
	check(edge >= 9 and edge <= 13, "An edge critter's level")
end
check(Frontier.critterExp(1, "Fringe", 0) == 8, "A level-1 critter's EXP")
check(Frontier.critterExp(10, "Fringe", 0) == 26, "A level-10 critter's EXP")
check(Frontier.critterExp(10, "Edge", 0) == 39, "An edge critter isn't worth half again")
check(Frontier.critterExp(10, "Edge", Frontier.Exp.Daily) == 10, "No quarter after the day's critters")
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
-- The noise ring: twenty dots, in twentieths.
check(FrontierHud.lit(nil) == 0 and FrontierHud.lit(0.5) == 10 and FrontierHud.lit(1.4) == 20, "The noise ring's dots")
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

print(
	string.format(
		"PASS: %d frontier checks (bands, outcrops, veins, noise, shares, critters, rifts, tears, the HUD)",
		checks
	)
)
