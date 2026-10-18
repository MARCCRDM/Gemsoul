--[[
	The Outpost's frontier (pure, for the server, the client and tests): how
	far out you are, what grows out there, and the rifts that tear open
	around you. See docs/frontier.md.

	The quarry is three bands round its middle:
	  Core    the outpost, the landing pad and the field round them (inside
	          Core studs): safe, no rifts, the plainest rocks
	  Fringe  out to EdgeFrom: rifts start tearing open round you, and the
	          rocks run richer (Bands.Fringe.Luck on every gem they pay)
	  Edge    out to the walls: rifts open often and more critters come
	          through at once; the richest rocks

	Candy trails: TrailAngles runs of rocks lead out from the core to the
	walls, a rock every TrailStep studs and glowing crumbs between them, the
	crystals warming from cyan to gold to rose the further out they grow.
	Each ends in a Rift Vein (VeinRocks rocks, the richest of all) round a
	dormant rift scar. Rocks grow back where they were, so a trail stays a
	trail.

	Rifts: every critter comes through a rift of its own, a ragged tear in
	the air (never the same shape twice). It opens and crackles for a
	moment first (Rift.Hop: the warning), the critter hops out at whoever
	drew it, the tear lingers (Rift.Linger) and seals (Rift.Close). Rifts
	come two ways, only round players out past the core:
	  Mining noise   every swing out there makes noise (Noise.Swing: more at
	                 the edge), and a little more trickles in each second
	                 you're out there (Noise.Idle). Full, an encounter:
	                 critters tear through near you (Frontier.incursion).
	  Wandering      every so often the frontier tears open by itself
	                 (Wander), 35 to 70 studs from someone out there: a few
	                 critters roam that patch for about a minute, going for
	                 whoever comes close. Go round it, or bring your kaiju.
	A critter's level comes from where it came through (Levels: the edge's
	are a real step up), and so do its EXP and coins (Frontier.critterExp,
	Coins). Clearing a wandering rift leaves everyone who helped Rift
	Charged (Charged: luckier gems for a while). A pickaxe can bonk a
	critter (Bonk) so a miner without a kaiju isn't helpless.

	  Frontier.distance(position, center) -> studs across the ground
	  Frontier.band(distance) -> "Core" | "Fringe" | "Edge"
	  Frontier.zoneOf(distance, vein?) -> a Shared.Outpost.Zones id
	  Frontier.trail(index, rng) -> { Vector3 }   a trail's rock spots (offsets from the middle)
	  Frontier.vein(last, rng) -> { Vector3 }, Vector3   its Rift Vein's rocks, and its scar
	  Frontier.crumbs(a, b, rng) -> { Vector3 }   glowing crumbs between two rocks
	  Frontier.noise(noise, band, swings, seconds, roll?) -> noise   (an encounter at 1)
	  Frontier.incursion(band, roll) -> critters at once
	  Frontier.share(cap, playersOut) -> critters at once round one player
	  Frontier.critterLevel(band, rng) -> level
	  Frontier.critterExp(level, band, today) -> EXP for a kaiju that fought it
	  Frontier.riftSpot(position, facing, center, rng) -> Vector3   where a rift opens
	  Frontier.wanderSpot(position, center, rng) -> Vector3   where a wandering rift opens
	  Frontier.timeline(at, linger?) -> { OpenAt, HopAt, CloseAt, EndAt }
	  Frontier.openness(timeline, now) -> 0..1   how wide a tear is
	  Frontier.tear(seed, height) -> shape   a tear's ragged outline
]]
local Frontier = {}

Frontier.Core = 150 -- studs from the middle: inside, no rifts
Frontier.EdgeFrom = 300
Frontier.Rim = 428 -- the furthest out a rock or a rift goes (the walls start at 440)
Frontier.Safe = 12 -- critters give up on prey this far inside the core

local CYAN = Color3.fromRGB(110, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 90)
local ROSE = Color3.fromRGB(255, 120, 190)
local RIFT = Color3.fromRGB(215, 90, 255)

-- Each band's name, its crystals' colour, and the luck its rocks add.
Frontier.Bands = {
	Core = { Name = "Outpost Core", Color = CYAN, Luck = 0 },
	Fringe = { Name = "The Fringe", Color = GOLD, Luck = 0.08 },
	Edge = { Name = "The Edge", Color = ROSE, Luck = 0.16 },
	Vein = { Name = "Rift Vein", Color = RIFT, Luck = 0.25 },
}
Frontier.BandOrder = { "Core", "Fringe", "Edge" }
Frontier.RiftColor = RIFT

-- Candy trails: their headings round the middle (degrees: 0 east, 90
-- south), between the haul roads and clear of the motor pool (south) and
-- the outpost (north).
Frontier.TrailAngles = { 0, 50, 130, 180, 230, 310 }
Frontier.TrailFrom, Frontier.TrailTo = 80, 400
Frontier.TrailStep = 17 -- studs between rocks on a trail
Frontier.TrailSway = 14 -- studs a trail wanders either side
Frontier.CrumbStep = 7 -- studs between crumbs (a crumb or two between rocks)
Frontier.VeinRocks = 4

-- Rifts: seconds it takes to open, until the critter hops out (it
-- crackles all that while: the warning), then lingers and seals; how tall
-- (studs); and where round a player it opens (studs away, and how far
-- either side of where they face).
Frontier.Rift = {
	Open = 0.55,
	Hop = 1.5,
	Linger = 1.8,
	Close = 0.45,
	Height = { 4.5, 7.5 },
	Near = 14,
	Far = 24,
	Spread = math.rad(100),
}
-- Mining noise: what a swing out in a band adds (an encounter at 1: about
-- 1 in 35 swings in the fringe, 1 in 17 at the edge, each swing's share
-- anywhere from 60% to 140% so they don't come like clockwork), and what a
-- second out there adds, mining or not (about one every 7 minutes in the
-- fringe, 3 at the edge). After an encounter it starts again from a little
-- (Restart), and the next can't come for Gap seconds.
Frontier.Noise = {
	Swing = { Fringe = 1 / 35, Edge = 1 / 17 },
	Idle = { Fringe = 1 / 420, Edge = 1 / 180 },
	Spread = { 0.6, 1.4 },
	Restart = 0.12,
	Gap = 8,
}
-- Critters at once round one player (more stay away), and in the whole
-- Outpost, shared fairly between those out there. (Each is a whole
-- brainrot body: dozens at once made the Outpost lag.)
Frontier.Caps = { Fringe = 2, Edge = 3, Server = 12 }
-- A critter with no one to fight this long slips back through a rift; none
-- stays longer than Life seconds.
Frontier.Leave, Frontier.Life = 4, 90
-- Its level by where it came through: the edge's are for a kaiju of about
-- level 8 and up.
Frontier.Levels = { Fringe = { 1, 4 }, Edge = { 9, 13 } }
-- Critters from the edge are tougher, and worth more.
Frontier.Boost = { Fringe = { Health = 1, Damage = 1, Exp = 1 }, Edge = { Health = 1.25, Damage = 1.2, Exp = 1.5 } }
-- EXP for each kaiju that fought one: Base + PerLevel x its level (times
-- its band's Boost.Exp); a quarter after Daily critters a day.
Frontier.Exp = { Base = 6, PerLevel = 2, Daily = 60, After = 0.25 }
-- Coins to whoever did the most to one, by band (a day's cap: Shared.Kaiju.Bug.DailyCoins).
Frontier.Coins = { Fringe = 2, Edge = 4, Guardian = 40 }
-- Wandering rifts: one every Every seconds or so somewhere out there, at
-- most Max critters out of them at once (of the Server cap), Near to Far
-- studs from whoever it's tied to. Its critters roam Roam studs round it
-- for Life seconds, going for anyone who comes within Notice; it seals
-- empty if its player is further than Seal studs off when they'd hop out.
Frontier.Wander = { Every = { 40, 80 }, Max = 3, Near = 35, Far = 70, Roam = 26, Notice = 30, Life = 60, Seal = 110 }
-- Clearing a wandering rift: everyone who helped is Rift Charged, gems
-- this much luckier for Seconds.
Frontier.Charged = { Luck = 0.1, Seconds = 60 }
-- The pickaxe on a critter: Share of its health, every Cooldown seconds,
-- knocked Knock studs back; from Reach studs (the client offers it at
-- Offer). It costs no swings.
Frontier.Bonk = { Share = 0.12, Cooldown = 0.6, Knock = 10, Reach = 8, Offer = 6 }

function Frontier.distance(position: Vector3, center: Vector3): number
	return Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
end

function Frontier.band(distance: number): string
	if distance < Frontier.Core then
		return "Core"
	elseif distance < Frontier.EdgeFrom then
		return "Fringe"
	end
	return "Edge"
end

-- The rock mix and luck for a spot (Shared.Outpost.Zones ids).
function Frontier.zoneOf(distance: number, vein: boolean?): string
	if vein then
		return "Vein"
	end
	local band = Frontier.band(distance)
	return if band == "Core" then "Common" else band
end

-- Trail `index`'s rock spots, from the core out to the walls: offsets from
-- the middle (Y 0), a rock every TrailStep studs or so, wandering.
function Frontier.trail(index: number, rng): { Vector3 }
	local base = math.rad(Frontier.TrailAngles[index] or 0)
	local wave = rng:NextNumber(55, 90)
	local phase = rng:NextNumber(0, math.pi * 2)
	local points = {}
	local r = Frontier.TrailFrom
	while r <= Frontier.TrailTo do
		-- (Its sway grows from nothing near the core, so it starts clear of the roads.)
		local sway = math.min(Frontier.TrailSway, (r - Frontier.TrailFrom) * 0.25 + 4)
		local a = base + sway * math.sin(r / wave + phase) / r
		local across = Vector3.new(-math.sin(a), 0, math.cos(a)) * rng:NextNumber(-2.5, 2.5)
		table.insert(points, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r) + across)
		r += Frontier.TrailStep * rng:NextNumber(0.88, 1.08)
	end
	return points
end

-- A trail's end: its Rift Vein's rocks, fanned round the last stretch, and
-- the dormant rift scar they guard (between them and the wall).
function Frontier.vein(last: Vector3, rng): ({ Vector3 }, Vector3)
	local out = Vector3.new(last.X, 0, last.Z).Unit
	local side = Vector3.new(-out.Z, 0, out.X)
	local scar = out * (Frontier.Rim + 2)
	local rocks = {}
	for i = 1, Frontier.VeinRocks do
		local t = (i - (Frontier.VeinRocks + 1) / 2) / Frontier.VeinRocks
		local p = out * (Frontier.Rim - 9 - math.abs(t) * 12 + rng:NextNumber(-1.5, 1.5)) + side * (t * 58)
		table.insert(rocks, p)
	end
	return rocks, scar
end

-- The glowing crumbs between two rocks of a trail (none across a big gap).
function Frontier.crumbs(a: Vector3, b: Vector3, rng): { Vector3 }
	local gap = b - a
	local length = Vector3.new(gap.X, 0, gap.Z).Magnitude
	local list = {}
	if length > Frontier.TrailStep * 2.4 or length < 0.1 then
		return list
	end
	local count = math.max(1, math.floor(length / Frontier.CrumbStep) - 1)
	local across = Vector3.new(-gap.Z, 0, gap.X).Unit
	for i = 1, count do
		local t = i / (count + 1)
		table.insert(list, a + gap * t + across * rng:NextNumber(-0.9, 0.9))
	end
	return list
end

-- A player's mining noise after `swings` swings and `seconds` seconds out
-- in `band` (the core adds nothing). `roll` (0..1) sets each swing's share
-- within Noise.Spread.
function Frontier.noise(noise: number, band: string, swings: number, seconds: number, roll: number?): number
	local swing, idle = Frontier.Noise.Swing[band], Frontier.Noise.Idle[band]
	if not swing then
		return noise
	end
	local spread = Frontier.Noise.Spread
	local share = spread[1] + (spread[2] - spread[1]) * (roll or 0.5)
	return noise + swing * swings * share + idle * seconds
end

-- Critters at once round one player: their band's cap, or a fair share of
-- the Outpost's when many are out there (never less than one).
function Frontier.share(cap: number, playersOut: number): number
	return math.min(cap, math.max(1, math.floor(Frontier.Caps.Server / math.max(1, playersOut))))
end

-- A critter's level, by where it came through.
function Frontier.critterLevel(band: string, rng): number
	local range = Frontier.Levels[band] or Frontier.Levels.Fringe
	return if rng then rng:NextInteger(range[1], range[2]) else range[1]
end

-- EXP for a kaiju that fought a critter of `level` from `band`, its owner
-- having had `today` critters' EXP already today.
function Frontier.critterExp(level: number, band: string?, today: number?): number
	local e = Frontier.Exp
	local boost = Frontier.Boost[band or ""] or Frontier.Boost.Fringe
	local exp = (e.Base + e.PerLevel * math.max(1, level)) * boost.Exp
	if (today or 0) >= e.Daily then
		exp *= e.After
	end
	return math.max(1, math.floor(exp + 0.5))
end

-- How many critters come through at once (`roll` in [0, 1)).
function Frontier.incursion(band: string, roll: number): number
	if band == "Edge" then
		return if roll < 0.6 then 2 else 3
	elseif band == "Fringe" then
		return if roll < 0.75 then 1 else 2
	end
	return 0
end

-- Where a rift opens round a player at `position` facing `facing` (a flat
-- direction, or zero: then outward): near where they look, inside the walls
-- and outside the core. Returns a point at their height.
function Frontier.riftSpot(position: Vector3, facing: Vector3, center: Vector3, rng): Vector3
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	end
	local angle = if flat.Magnitude > 0.01 then math.atan2(flat.Z, flat.X) else rng:NextNumber(0, math.pi * 2)
	angle += rng:NextNumber(-Frontier.Rift.Spread, Frontier.Rift.Spread)
	local reach = rng:NextNumber(Frontier.Rift.Near, Frontier.Rift.Far)
	return Frontier.inFrontier(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach, center, position.Y)
end

-- A point brought inside the frontier (out of the core, inside the walls), at height `y`.
function Frontier.inFrontier(spot: Vector3, center: Vector3, y: number): Vector3
	local offset = Vector3.new(spot.X - center.X, 0, spot.Z - center.Z)
	local r = math.clamp(offset.Magnitude, Frontier.Core, Frontier.Rim)
	offset = if offset.Magnitude > 0.01 then offset.Unit * r else Vector3.new(r, 0, 0)
	return Vector3.new(center.X + offset.X, y, center.Z + offset.Z)
end

-- Where a wandering rift opens: Wander.Near to Far studs from someone out
-- there at `position`, any way round, inside the frontier.
function Frontier.wanderSpot(position: Vector3, center: Vector3, rng): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local reach = rng:NextNumber(Frontier.Wander.Near, Frontier.Wander.Far)
	return Frontier.inFrontier(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach, center, position.Y)
end

-- A rift opening at `at` (server time): when it's open, the critter hops,
-- it starts to seal, and it's gone. `linger`: seconds it stays open after
-- the hop (Rift.Linger unless given).
function Frontier.timeline(at: number, linger: number?)
	local rift = Frontier.Rift
	local stay = linger or rift.Linger
	return {
		OpenAt = at,
		HopAt = at + rift.Hop,
		CloseAt = at + rift.Hop + stay,
		EndAt = at + rift.Hop + stay + rift.Close,
	}
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

-- How wide the tear is at `now`: 0 shut, 1 wide open.
function Frontier.openness(timeline, now: number): number
	if now < timeline.OpenAt or now >= timeline.EndAt then
		return 0
	elseif now < timeline.OpenAt + Frontier.Rift.Open then
		return ease((now - timeline.OpenAt) / Frontier.Rift.Open)
	elseif now < timeline.CloseAt then
		return 1
	end
	return 1 - ease((now - timeline.CloseAt) / math.max(timeline.EndAt - timeline.CloseAt, 0.01))
end

-- A tear's ragged outline, from its seed: in its own plane (X across, Y up,
-- studs, centred on 0), never symmetrical. Returns {
--   Spine = { Vector2 }   the crack it opens along, top to bottom
--   Left, Right = { Vector2 }   its two lips, wide open (pointed at both ends)
--   Branches = { { Vector2, Vector2, Row, Left } }   hairline cracks running
--              off its lips (from a lip's point in that row, on that side)
--   Tilt   radians it leans, Height }
function Frontier.tear(seed: number, height: number)
	local rng = Random.new(seed)
	local rows = 8
	local spine, left, right = {}, {}, {}
	local x = 0
	local widest = height * rng:NextNumber(0.45, 0.62)
	for i = 0, rows - 1 do
		local t = i / (rows - 1)
		local y = height / 2 - t * height + (if i > 0 and i < rows - 1 then rng:NextNumber(-0.06, 0.06) * height else 0)
		if i > 0 then
			x += rng:NextNumber(-0.42, 0.42) * height / rows
		end
		table.insert(spine, Vector2.new(x, y))
		-- Wide in the middle, pointed at the ends, and lopsided: each lip
		-- takes its own share of the width, row by row.
		local width = if i == 0 or i == rows - 1
			then 0
			else widest * math.sin(t * math.pi) ^ 0.8 * rng:NextNumber(0.55, 1.25)
		local share = rng:NextNumber(0.25, 0.75)
		table.insert(left, Vector2.new(x - width * share, y + rng:NextNumber(-0.04, 0.04) * height))
		table.insert(right, Vector2.new(x + width * (1 - share), y + rng:NextNumber(-0.04, 0.04) * height))
	end
	local branches = {}
	for _ = 1, rng:NextInteger(2, 4) do
		local row = rng:NextInteger(2, rows - 1)
		local onLeft = rng:NextNumber() < 0.5
		local from = if onLeft then left[row] else right[row]
		local angle = (if onLeft then math.pi else 0) + rng:NextNumber(-0.9, 0.9)
		local length = height * rng:NextNumber(0.12, 0.3)
		table.insert(
			branches,
			{ from, from + Vector2.new(math.cos(angle), math.sin(angle)) * length, Row = row, Left = onLeft }
		)
	end
	return {
		Spine = spine,
		Left = left,
		Right = right,
		Branches = branches,
		Tilt = rng:NextNumber(-0.35, 0.35),
		Height = height,
	}
end

return Frontier
