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
	the air (never the same shape twice). It opens (Rift.Open), the critter
	hops out at whoever drew it (Rift.Hop), the tear lingers (Rift.Linger)
	and seals (Rift.Close). Rifts only open round a player out past the
	core: their pressure builds each second they're out there (faster at
	the edge, faster still heading outward), and when it's full, critters
	come through ahead of them.

	  Frontier.distance(position, center) -> studs across the ground
	  Frontier.band(distance) -> "Core" | "Fringe" | "Edge"
	  Frontier.zoneOf(distance, vein?) -> a Shared.Outpost.Zones id
	  Frontier.trail(index, rng) -> { Vector3 }   a trail's rock spots (offsets from the middle)
	  Frontier.vein(last, rng) -> { Vector3 }, Vector3   its Rift Vein's rocks, and its scar
	  Frontier.crumbs(a, b, rng) -> { Vector3 }   glowing crumbs between two rocks
	  Frontier.pressure(heat, band, outward, dt) -> heat
	  Frontier.incursion(band, roll) -> critters at once
	  Frontier.riftSpot(position, heading, center, rng) -> Vector3   where a rift opens
	  Frontier.timeline(at) -> { OpenAt, HopAt, CloseAt, EndAt }
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

-- Rifts: seconds it takes to open, until the critter hops out, then lingers
-- and seals; how tall (studs); and where round a player it opens (studs
-- ahead, and how far either side of their heading).
Frontier.Rift = {
	Open = 0.55,
	Hop = 0.7,
	Linger = 1.8,
	Close = 0.45,
	Height = { 4.5, 7.5 },
	Near = 14,
	Far = 24,
	Spread = math.rad(70),
}
-- Pressure: a second out in a band adds this; heading outward, times
-- Outward. At Threshold, an incursion (and it starts again from a little).
-- Back in the core it drains at Drain a second.
Frontier.Pressure = { Fringe = 0.8, Edge = 1.6, Outward = 1.6, Threshold = 10, Drain = 2 }
-- Critters at once round one player (more stay away), and in the whole Outpost.
Frontier.Caps = { Fringe = 3, Edge = 6, Server = 30 }
-- A critter with no one to fight this long slips back through a rift; none
-- stays longer than Life seconds.
Frontier.Leave, Frontier.Life = 4, 90
-- Critters from the edge are tougher, and worth more.
Frontier.Boost = { Fringe = { Health = 1, Damage = 1, Exp = 1 }, Edge = { Health = 1.25, Damage = 1.2, Exp = 1.5 } }

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

-- A player's pressure after `dt` seconds in `band` (heading outward or not).
function Frontier.pressure(heat: number, band: string, outward: boolean, dt: number): number
	local rate = Frontier.Pressure[band]
	if not rate then
		return math.max(0, heat - Frontier.Pressure.Drain * dt)
	end
	return heat + rate * dt * (if outward then Frontier.Pressure.Outward else 1)
end

-- How many critters come through at once (`roll` in [0, 1)).
function Frontier.incursion(band: string, roll: number): number
	if band == "Edge" then
		return if roll < 0.5 then 2 elseif roll < 0.85 then 3 else 4
	elseif band == "Fringe" then
		return if roll < 0.7 then 1 else 2
	end
	return 0
end

-- Where a rift opens round a player at `position` heading `heading` (a flat
-- direction, or zero standing still: then outward): ahead of them, inside
-- the walls and outside the core. Returns a point at their height.
function Frontier.riftSpot(position: Vector3, heading: Vector3, center: Vector3, rng): Vector3
	local flat = Vector3.new(heading.X, 0, heading.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	end
	local angle = if flat.Magnitude > 0.01 then math.atan2(flat.Z, flat.X) else rng:NextNumber(0, math.pi * 2)
	angle += rng:NextNumber(-Frontier.Rift.Spread, Frontier.Rift.Spread)
	local reach = rng:NextNumber(Frontier.Rift.Near, Frontier.Rift.Far)
	local spot = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach
	local offset = Vector3.new(spot.X - center.X, 0, spot.Z - center.Z)
	local r = math.clamp(offset.Magnitude, Frontier.Core, Frontier.Rim)
	offset = if offset.Magnitude > 0.01 then offset.Unit * r else Vector3.new(r, 0, 0)
	return Vector3.new(center.X + offset.X, position.Y, center.Z + offset.Z)
end

-- A rift opening at `at` (server time): when it's open, the critter hops,
-- it starts to seal, and it's gone.
function Frontier.timeline(at: number)
	local rift = Frontier.Rift
	return {
		OpenAt = at,
		HopAt = at + rift.Hop,
		CloseAt = at + rift.Hop + rift.Linger,
		EndAt = at + rift.Hop + rift.Linger + rift.Close,
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
