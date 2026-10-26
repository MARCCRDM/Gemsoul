--[[
	The team's HYPERBEAM (KaijuBeamServer runs it; Client.KaijuBeamHud is its
	button, Client.KaijuBeamFx the show): every kaiju you have out builds up
	mana, and once all of them are full you can call the blast. They leap into
	formation round you (Formation: a V either side of you, the support hung
	up behind), all face where you aim, each pours its element into one
	point in front of you (their cast's charge-up at their mouths) and the
	beam fires from it: a long, wide blast that hits every creature in it,
	a few pulses over a second and a half. Pure rules (numbers and plain
	vectors), shared so the client shows what the server does. Into
	formation they leap, one after another, and roar together once they're
	all down (Leap).

	Mana (Mana): out of a fight a kaiju gains Trickle a second (so it fills
	while you mine, with or without a fight), in one Fight a second more,
	and Hit for every blow of its that lands (Heavy times that for a heavy).
	Each of its Q / E / R costs Cast. SAVE CHARGE (your switch, kept on your
	profile): your kaiju fight with blows alone, casting none of their moves,
	and gain Save times as fast; the support's heals still go out.

	  KaijuBeam.gain(mana, amount, saving) -> mana     clamped to 0..Max
	  KaijuBeam.spend(mana) -> mana                    a Q / E / R's cost
	  KaijuBeam.team(manas) -> ready, least            all full? and the
	                                                   emptiest, 0..1
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
	                                                   right; +Back: behind)
	  KaijuBeam.focus() -> ahead, up                   where their streams
	                                                   meet, and the beam
	                                                   starts
	  KaijuBeam.hits(ox, oz, dx, dz, px, pz, radius) -> boolean   a creature
	                                                   at p (radius r) in the
	                                                   beam from o along d
	  KaijuBeam.aim(dx, dz, foes) -> dx, dz            your aim, turned onto
	                                                   the nearest creature
	                                                   in Assist of it
	  KaijuBeam.damage(damages) -> number              each pulse, on each
	                                                   creature in the beam
]]
local KaijuBeam = {}

KaijuBeam.Mana = {
	Max = 100,
	Trickle = 0.6, -- a second, out of a fight (about three minutes from empty)
	Fight = 0.3, -- a second more, in one
	Hit = 2.4, -- a blow of its that lands
	Heavy = 1.6, -- times that for a heavy
	Cast = 8, -- a Q, E or R
	Save = 1.6, -- times as fast, saving its charge
}

-- The blast, in seconds and studs: gathering into formation, the charge
-- (their streams pouring into the focus), the beam, and a beat to recover.
KaijuBeam.Beam = {
	Gather = 1.8,
	Charge = 1.5,
	Fire = 1.5,
	Recover = 0.6,
	Length = 90,
	Width = 10,
	Pulses = 6,
	Power = 7, -- the team's Damage, added up, times this over the whole beam
	Reach = 60, -- creatures this near count for the aim assist
	Assist = math.rad(35), -- this far off your aim, it turns onto them
	Focus = 7, -- the focus this far ahead of you
	FocusUp = 3, -- and this high
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

-- Their places, in a V either side of you facing your aim: the first on
-- your right, the next on your left, then further out and back; the
-- support hung up behind you.
KaijuBeam.Formation = {
	{ Side = 4.5, Back = 1.2, Up = 0 },
	{ Side = -4.5, Back = 1.2, Up = 0 },
	{ Side = 8.5, Back = 3.4, Up = 0 },
	{ Side = -8.5, Back = 3.4, Up = 0 },
}
KaijuBeam.Support = { Side = 0, Back = 5, Up = 5 }

function KaijuBeam.gain(mana: number?, amount: number, saving: boolean?): number
	local rules = KaijuBeam.Mana
	local scaled = if saving and amount > 0 then amount * rules.Save else amount
	return math.clamp((tonumber(mana) or 0) + scaled, 0, rules.Max)
end

function KaijuBeam.spend(mana: number?): number
	return math.max(0, (tonumber(mana) or 0) - KaijuBeam.Mana.Cast)
end

-- All full (and at least one)? And the emptiest of them, 0..1.
function KaijuBeam.team(manas: { number }): (boolean, number)
	local least = math.huge
	for _, mana in manas do
		least = math.min(least, tonumber(mana) or 0)
	end
	if least == math.huge then
		return false, 0
	end
	local max = KaijuBeam.Mana.Max
	return least >= max, math.clamp(least / max, 0, 1)
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
			spot = { Side = side * (4.5 + (rank - 1) * 4), Back = 1.2 + (rank - 1) * 2.2, Up = 0 }
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
