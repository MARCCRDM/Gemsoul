--[[
	Fighting together (see docs/kaiju.md, "Fighting as a team"): how a side
	shares out its foes and keeps out of its own way. Your kaiju team
	(KaijuServer), a rift's critters (KaijuWilds) and a wild pack all use it.

	  Squad.assign(fighters, foes, cost, capacity?) -> { [fighter]: foe }
	      Each fighter gets a foe, spread as evenly as can be. With at least
	      as many foes as fighters each takes its own (1v1s, the rest waiting
	      their turn: two kaiju on ten critters fight five each, one at a
	      time); with more fighters than foes they share them out (three on
	      two: two and one), so as foes fall the fighters collapse onto the
	      ones left. Cheapest pairs first: `cost(fighter, foe)` (its distance
	      less what keeps it there: Squad.cost), math.huge for a foe it
	      mustn't take. `capacity` (a number) caps any one foe's share.
	  Squad.cost(distance, current, threat) -> number
	      A pair's cost: the distance, less Stick for the foe it's already on
	      (no swapping back and forth) and Threat for one that's after it.
	  Squad.slots(center, positions) -> { Vector3 }
	      Where each of a group on one foe stands round it (unit directions
	      from `center`): evenly round the circle (two on opposite sides,
	      three a third of a turn apart), each keeping its side as near as it
	      can so they don't cross.
	  Squad.toward(from, to, maxAngle) -> Vector3
	      A unit direction turned from `from` toward `to` by at most
	      `maxAngle` (radians): walking round a foe to its slot, not through.
	  Squad.apart(at, others, space, seed?) -> Vector3
	      A push (flat; up to 1 stud per stud of `space`) away from any of
	      `others` (positions) closer than `space`; `seed` (its place, its
	      number) parts two right on top of each other different ways.
]]
local Squad = {}

Squad.Stick = 8 -- studs a fighter will go on with the foe it's on rather than swap
Squad.Threat = 6 -- studs a foe already after a fighter counts nearer

local TAU = math.pi * 2

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Squad.cost(distance: number, current: boolean?, threat: boolean?): number
	return distance - (if current then Squad.Stick else 0) - (if threat then Squad.Threat else 0)
end

function Squad.assign<F, E>(fighters: { F }, foes: { E }, cost: (F, E) -> number, capacity: number?): { [F]: E }
	local out = {}
	if #fighters == 0 or #foes == 0 then
		return out
	end
	local share = math.max(1, math.ceil(#fighters / #foes))
	if capacity then
		share = math.min(share, math.max(1, capacity))
	end
	local pairs = {}
	for i, fighter in fighters do
		for j, foe in foes do
			local c = cost(fighter, foe)
			if c < math.huge then
				table.insert(pairs, { c, i, j })
			end
		end
	end
	-- (Cheapest first; ties in the order given, so it's the same every time.)
	table.sort(pairs, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		elseif a[2] ~= b[2] then
			return a[2] < b[2]
		end
		return a[3] < b[3]
	end)
	local load = {}
	for _, pair in pairs do
		local fighter, foe = fighters[pair[2]], foes[pair[3]]
		if out[fighter] == nil and (load[foe] or 0) < share then
			out[fighter] = foe
			load[foe] = (load[foe] or 0) + 1
		end
	end
	-- A fighter whose foes are all taken up (the ones it may fight are full,
	-- or out of its reach for the rest) goes in after its cheapest anyway.
	if capacity == nil then
		for _, pair in pairs do
			local fighter = fighters[pair[2]]
			if out[fighter] == nil then
				out[fighter] = foes[pair[3]]
			end
		end
	end
	return out
end

local function angleOf(v: Vector3): number
	return math.atan2(v.Z, v.X)
end

function Squad.slots(center: Vector3, positions: { Vector3 }): { Vector3 }
	local count = #positions
	local out = table.create(count)
	if count == 0 then
		return out
	end
	local angles = table.create(count)
	for i, at in positions do
		local away = flat(at - center)
		angles[i] = if away.Magnitude > 0.05 then angleOf(away) else (i - 1) * TAU / count
	end
	if count == 1 then
		out[1] = Vector3.new(math.cos(angles[1]), 0, math.sin(angles[1]))
		return out
	end
	-- Round the circle in the order they stand, turned as little as can be:
	-- the circular mean of how far each is from its even place.
	local order = table.create(count)
	for i = 1, count do
		order[i] = i
	end
	table.sort(order, function(a, b)
		return if angles[a] ~= angles[b] then angles[a] < angles[b] else a < b
	end)
	local step = TAU / count
	local sx, sy = 0, 0
	for rank, i in order do
		local off = angles[i] - (rank - 1) * step
		sx += math.cos(off)
		sy += math.sin(off)
	end
	local base = if sx == 0 and sy == 0 then angles[order[1]] else math.atan2(sy, sx)
	for rank, i in order do
		local a = base + (rank - 1) * step
		out[i] = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	return out
end

function Squad.toward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	from, to = flat(from), flat(to)
	if from.Magnitude < 1e-3 then
		return if to.Magnitude < 1e-3 then Vector3.new(1, 0, 0) else to.Unit
	end
	from = from.Unit
	if to.Magnitude < 1e-3 then
		return from
	end
	to = to.Unit
	local a, b = angleOf(from), angleOf(to)
	local turn = (b - a + math.pi) % TAU - math.pi
	if math.abs(turn) <= maxAngle then
		return to
	end
	local c = a + math.sign(turn) * maxAngle
	return Vector3.new(math.cos(c), 0, math.sin(c))
end

function Squad.apart(at: Vector3, others: { Vector3 }, space: number, seed: number?): Vector3
	local push = Vector3.zero
	if space <= 0 then
		return push
	end
	for i, other in others do
		local away = flat(at - other)
		local d = away.Magnitude
		if d < space then
			-- (Right on top of each other: apart by which one it is.)
			local turn = (seed or 0) * TAU / 3 + i * 0.4
			local dir = if d > 0.05 then away / d else Vector3.new(math.cos(turn), 0, math.sin(turn))
			push += dir * (space - d)
		end
	end
	return push
end

return Squad
