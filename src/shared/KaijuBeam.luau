--[[
	The team's HYPERBEAM (KaijuBeamServer runs it; Client.KaijuBeamHud is its
	button, Client.KaijuBeamFx the show): your team builds up a charge of its
	own while it's out, and once it's full you can call the blast. It all
	happens in front of you, seen from your own view (no cinematic camera):
	they leap into formation in front of you (Formation: a V opening ahead
	of you, the support hung up over it), all face where you aim, each pours
	its element into one point ahead of them (their cast's charge-up at
	their mouths) and the beam fires from it: a long, wide blast that hits
	every creature in it, Pulses pulses over Fire seconds. It aims at the
	biggest threat first (threat: the toughest, and the ones already in a
	fight with you, bigger still), holds on it for Dwell of the blast, then
	swings smoothly onto each of the others in reach or in a fight with
	your team in turn (order, sweep, direction), never more than Swing off
	your aim. Pure rules (numbers and plain vectors), shared so the client
	shows what the server does. Into formation they leap, one after
	another, and roar together once they're all down (Leap).

	The charge (Charge): one meter for the whole team, its own, apart from
	anything a kaiju spends on its moves (their Q, E and R cost it nothing).
	With your team out it gains Trickle a second (so it fills while you
	mine), Fight a second more while any of them fights, and Hit for every
	blow of theirs that lands (Heavy times that for a heavy). It's a long
	charge: about five and a half minutes from empty following you about,
	a minute or so of steady fighting. SAVE CHARGE (your switch, kept on
	your profile): your kaiju fight with blows alone, casting none of their
	moves, and it fills Save times as fast; the support's heals still go
	out.

	  KaijuBeam.gain(charge, amount, saving) -> charge   clamped to 0..Max
	  KaijuBeam.ready(charge) -> ready, share             full? and how full, 0..1
	  KaijuBeam.timeline() -> { Charge, Fire, Stop, Done }   seconds from
	                                                   the call
	  KaijuBeam.phase(t) -> phase?, progress           "Gather" (leaping
	                                                   into formation),
	                                                   "Charge", "Fire",
	                                                   "Recover"; nil after
	  KaijuBeam.leap(i) -> takeoff, land               the `i`th into formation:
	                                                   its leap, seconds from
	                                                   the call
	  KaijuBeam.leapHeight(distance) -> studs          how high a leap that far
	  KaijuBeam.arc(p, height) -> along, up            a leap `p` of the way
	                                                   through
	  KaijuBeam.formation(fighters, support) -> spots  each kaiju's place,
	                                                   { Side, Back, Up } in
	                                                   studs from you, facing
	                                                   your aim (+Side: your
	                                                   right; +Back: behind,
	                                                   so negative is ahead)
	  KaijuBeam.focus() -> ahead, up                   where their streams
	                                                   meet, and the beam
	                                                   starts
	  KaijuBeam.hits(ox, oz, dx, dz, px, pz, radius) -> boolean   a creature
	                                                   at p (radius r) in the
	                                                   beam from o along d
	  KaijuBeam.aim(dx, dz, foes) -> dx, dz            your aim, turned onto
	                                                   the nearest creature
	                                                   in Assist of it
	  KaijuBeam.threat(foe) -> number                  how big a threat
	                                                   { Health, Engaged } is
	  KaijuBeam.order(foes, dx, dz) -> { index }       what the beam takes in
	                                                   turn: the biggest
	                                                   threat, then round
	                                                   the rest (Most of them)
	  KaijuBeam.sweep(p, n) -> i, j, blend             `p` of the way through
	                                                   the blast over `n`:
	                                                   from the `i`th onto
	                                                   the `j`th, `blend` there
	  KaijuBeam.direction(p, ox, oz, dx, dz, points) -> dx, dz   the beam's
	                                                   way from the focus
	                                                   (o) at `p`, swinging
	                                                   over `points` in order
	  KaijuBeam.damage(damages) -> number              each pulse, on each
	                                                   creature in the beam
]]
local KaijuBeam = {}

KaijuBeam.Charge = {
	Max = 100,
	Trickle = 0.3, -- a second, your team out (about five and a half minutes from empty)
	Fight = 0.15, -- a second more, while any of them fights
	Hit = 0.6, -- a blow of any of theirs that lands
	Heavy = 1.6, -- times that for a heavy
	Save = 1.6, -- times as fast, saving its charge
}

-- The blast, in seconds and studs: gathering into formation, the charge
-- (their streams pouring into the focus), the beam, and a beat to recover.
KaijuBeam.Beam = {
	Gather = 1.8,
	Charge = 1.2,
	Fire = 2.6,
	Recover = 0.5,
	Length = 90,
	Width = 10,
	Pulses = 13,
	Power = 7, -- the team's Damage, added up, times this over the whole beam
	Reach = 60, -- creatures this near are taken (and count for the aim assist)
	Assist = math.rad(35), -- this far off your aim, it turns onto them
	Focus = 16, -- the focus this far ahead of you
	FocusUp = 3, -- and this high
	Most = 5, -- creatures it swings onto, the biggest threat first
	Dwell = 0.4, -- the share of the blast it holds on the biggest threat
	Turn = 0.4, -- the share of each swing after that spent turning (the rest held)
	Swing = math.rad(80), -- never further than this off your aim
	Engaged = 1.5, -- a creature in a fight with you or your team: this much more a threat
}

-- Into formation: one after another (the V's first, then outwards, the
-- support last) each leaps from where it was to its place, Stagger apart,
-- Air seconds in the air, as high as a hop over its distance (Height plus
-- Rise a stud, up to Top); once they're all down, they roar together at Roar.
KaijuBeam.Leap = {
	Stagger = 0.16,
	Air = 0.62,
	Height = 3.5,
	Rise = 0.22,
	Top = 14,
	Roar = 1.25,
}

-- Their places, in a V opening ahead of you, facing your aim, wide of the
-- middle so your view down it stays clear: the first ahead on your right,
-- the next ahead on your left, then further out and nearer you; the
-- support hung up high over the V.
KaijuBeam.Formation = {
	{ Side = 8, Back = -7, Up = 0 },
	{ Side = -8, Back = -7, Up = 0 },
	{ Side = 13, Back = -3, Up = 0 },
	{ Side = -13, Back = -3, Up = 0 },
}
KaijuBeam.Support = { Side = 0, Back = -6, Up = 9 }

function KaijuBeam.gain(charge: number?, amount: number, saving: boolean?): number
	local rules = KaijuBeam.Charge
	local scaled = if saving and amount > 0 then amount * rules.Save else amount
	return math.clamp((tonumber(charge) or 0) + scaled, 0, rules.Max)
end

-- Full? And how full, 0..1.
function KaijuBeam.ready(charge: number?): (boolean, number)
	local max = KaijuBeam.Charge.Max
	local value = tonumber(charge) or 0
	return value >= max, math.clamp(value / max, 0, 1)
end

function KaijuBeam.timeline()
	local b = KaijuBeam.Beam
	local charge = b.Gather
	local fire = charge + b.Charge
	local stop = fire + b.Fire
	return { Charge = charge, Fire = fire, Stop = stop, Done = stop + b.Recover }
end

function KaijuBeam.phase(t: number): (string?, number)
	local b, at = KaijuBeam.Beam, KaijuBeam.timeline()
	if t < 0 then
		return nil, 0
	elseif t < at.Charge then
		return "Gather", t / b.Gather
	elseif t < at.Fire then
		return "Charge", (t - at.Charge) / b.Charge
	elseif t < at.Stop then
		return "Fire", (t - at.Fire) / b.Fire
	elseif t < at.Done then
		return "Recover", (t - at.Stop) / b.Recover
	end
	return nil, 1
end

-- `fighters` places in the V (beyond its four, further out still), then
-- the support's if `support`.
function KaijuBeam.formation(fighters: number, support: boolean?): { { Side: number, Back: number, Up: number } }
	local spots = {}
	for i = 1, fighters do
		local spot = KaijuBeam.Formation[i]
		if not spot then
			local rank = math.ceil(i / 2)
			local side = if i % 2 == 1 then 1 else -1
			spot = { Side = side * (8 + (rank - 1) * 5), Back = -7 + (rank - 1) * 4, Up = 0 }
		end
		table.insert(spots, table.clone(spot))
	end
	if support then
		table.insert(spots, table.clone(KaijuBeam.Support))
	end
	return spots
end

-- The `i`th to leap's take-off and landing, seconds from the call.
function KaijuBeam.leap(i: number): (number, number)
	local l = KaijuBeam.Leap
	local takeoff = math.max(0, i - 1) * l.Stagger
	return takeoff, takeoff + l.Air
end

-- How high a leap of `distance` studs goes.
function KaijuBeam.leapHeight(distance: number): number
	local l = KaijuBeam.Leap
	return math.min(l.Top, l.Height + math.max(0, distance) * l.Rise)
end

-- A leap `p` (0..1) of the way through: how far along it is (eased: it
-- springs off and settles in) and how high above the line from its start
-- to its place.
function KaijuBeam.arc(p: number, height: number): (number, number)
	p = math.clamp(p, 0, 1)
	local along = p * p * (3 - 2 * p)
	return along, 4 * height * p * (1 - p)
end

function KaijuBeam.focus(): (number, number)
	return KaijuBeam.Beam.Focus, KaijuBeam.Beam.FocusUp
end

-- Is a creature at (px, pz), `radius` studs round, in the beam: from the
-- focus at (ox, oz) along the unit (dx, dz), Length long and Width wide?
function KaijuBeam.hits(ox: number, oz: number, dx: number, dz: number, px: number, pz: number, radius: number?): boolean
	local b = KaijuBeam.Beam
	local r = radius or 0
	local rx, rz = px - ox, pz - oz
	local along = rx * dx + rz * dz
	if along < -r or along > b.Length + r then
		return false
	end
	local across = math.abs(rx * dz - rz * dx)
	return across <= b.Width / 2 + r
end

-- Your aim, turned onto the nearest creature within Assist of it (`foes`:
-- each { X, Z }, its offset from you); as it was if none.
function KaijuBeam.aim(dx: number, dz: number, foes: { { X: number, Z: number } }?): (number, number)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-4 then
		dx, dz, length = 0, -1, 1
	end
	dx, dz = dx / length, dz / length
	local best, bestX, bestZ = math.huge, dx, dz
	local reach, cone = KaijuBeam.Beam.Reach, math.cos(KaijuBeam.Beam.Assist)
	for _, foe in foes or {} do
		local d = math.sqrt(foe.X * foe.X + foe.Z * foe.Z)
		if d > 1e-3 and d <= reach and (foe.X * dx + foe.Z * dz) / d >= cone and d < best then
			best, bestX, bestZ = d, foe.X / d, foe.Z / d
		end
	end
	return bestX, bestZ
end

-- How big a threat a creature is: its health (the toughest first: a boss,
-- a wild kaiju over a critter), Engaged times that if it's in a fight with
-- you or your team.
function KaijuBeam.threat(foe): number
	local most = math.max(tonumber(foe.MaxHealth) or 0, tonumber(foe.Health) or 0, 1)
	return most * (if foe.Engaged then KaijuBeam.Beam.Engaged else 1)
end

local function heading(x: number, z: number): number
	return math.atan2(z, x)
end
local function between(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

-- What the beam takes, in turn (`foes`: each { X, Z, Health?, MaxHealth?,
-- Engaged? }, its offset from you): the biggest threat first, then from
-- each the nearest round from it, up to Most of them, never one further
-- than Swing off your aim (dx, dz). Indices into `foes`.
function KaijuBeam.order(foes: { any }, dx: number, dz: number): { number }
	local b = KaijuBeam.Beam
	local aim = heading(dx, dz)
	local left = {}
	for i, foe in foes do
		local x, z = tonumber(foe.X) or 0, tonumber(foe.Z) or 0
		if x * x + z * z > 1e-6 and math.abs(between(aim, heading(x, z))) <= b.Swing then
			table.insert(left, i)
		end
	end
	local order = {}
	if #left == 0 then
		return order
	end
	local best, bestAt = -math.huge, 1
	for at, i in left do
		local threat = KaijuBeam.threat(foes[i])
		if threat > best then
			best, bestAt = threat, at
		end
	end
	table.insert(order, table.remove(left, bestAt))
	while #left > 0 and #order < b.Most do
		local last = foes[order[#order]]
		local from = heading(last.X, last.Z)
		local near, nearAt = math.huge, 1
		for at, i in left do
			local off = math.abs(between(from, heading(foes[i].X, foes[i].Z)))
			if off < near then
				near, nearAt = off, at
			end
		end
		table.insert(order, table.remove(left, nearAt))
	end
	return order
end

-- `p` (0..1) of the way through the blast, over `n` taken in turn: from
-- the `i`th onto the `j`th, `blend` (eased) of the way. It holds on the
-- first for Dwell of it, then shares the rest out, each swing turning for
-- Turn of its share and holding on the next for the rest.
function KaijuBeam.sweep(p: number, n: number): (number, number, number)
	local b = KaijuBeam.Beam
	if n <= 1 or p <= b.Dwell then
		return 1, 1, 0
	end
	local legs = n - 1
	local s = math.clamp((p - b.Dwell) / (1 - b.Dwell), 0, 1) * legs
	local leg = math.min(legs, math.floor(s) + 1)
	local turn = math.clamp((s - (leg - 1)) / b.Turn, 0, 1)
	return leg, leg + 1, turn * turn * (3 - 2 * turn)
end

-- The beam's way (a unit dx, dz) from the focus at (ox, oz), `p` of the
-- way through the blast: swinging over `points` (each { X, Z }, where each
-- taken is, in turn) by sweep, never further than Swing off your aim
-- (dx, dz); your aim if there are none.
function KaijuBeam.direction(p: number, ox: number, oz: number, dx: number, dz: number, points: { any }?): (number, number)
	local n = if points then #points else 0
	if n == 0 then
		return dx, dz
	end
	local b = KaijuBeam.Beam
	local aim = heading(dx, dz)
	local function toward(point): number
		local x, z = (tonumber(point.X) or 0) - ox, (tonumber(point.Z) or 0) - oz
		if x * x + z * z < 1e-6 then
			return aim
		end
		return aim + math.clamp(between(aim, heading(x, z)), -b.Swing, b.Swing)
	end
	local i, j, blend = KaijuBeam.sweep(p, n)
	local from = toward((points :: any)[i])
	local angle = from + between(from, toward((points :: any)[j])) * blend
	return math.cos(angle), math.sin(angle)
end

-- Each pulse, on each creature in the beam: the team's Damage (each kaiju
-- out's), added up, times Power over the whole beam.
function KaijuBeam.damage(damages: { number }): number
	local total = 0
	for _, damage in damages do
		total += math.max(0, tonumber(damage) or 0)
	end
	local b = KaijuBeam.Beam
	return total * b.Power / b.Pulses
end

return KaijuBeam
