--[[
	The Kaiju Kennel: the pen on the Shelter's stage (Server OutpostWorld
	builds it; Client KaijuKennel draws who lives in it), where the rarest
	kinds of kaiju wander about, and the Kaiju of the Day on its display in
	front of the gate.

	Everything here is worked out from the day and the server's clock, so
	every player sees the same kaiju in the same places doing the same
	things, with nothing sent from the server.

	  Kennel.day(now) -> number            the day (UTC) `now` falls in
	  Kennel.special(day) -> { Species, Element }
	      the Kaiju of the Day: one of the rarest batch (Kaiju.batch 1),
	      a different kind each day
	  Kennel.residents(day) -> { { Species, Element } }
	      who's in the pen today: Count of the rarest batch, never the
	      Kaiju of the Day
	  Kennel.state(index, count, now) -> { Position, Yaw, Speed, Mood, MoodAt }
	      resident `index` (of `count`) at server time `now`, in the
	      Shelter's frame: walking from spot to spot in its own wedge of
	      the pen (so two never walk into each other), or stopped there,
	      sniffing the ground, looking about, lying down, asleep, or a roar
]]
local Kaiju = require(script.Parent.Kaiju)
local KaijuRoster = require(script.Parent.KaijuRoster)

local Kennel = {}

-- The pen: the floor of the stage in the Shelter's hall (its middle, in
-- the Shelter's frame) and how far out from it the kaiju walk. The fence
-- stands at Fence; the Kaiju of the Day's display at Display, in front of
-- the gate. Both face the garage (-Z): players come into the hall through
-- the barrier from there, the gate and Wren the first things they see.
Kennel.Pen = { Middle = Vector3.new(0, 2.35, 18), Inner = 4.5, Outer = 8.6, Fence = 11.6 }
Kennel.Display = Vector3.new(0, 0.86, 2.5)
Kennel.Count = 6 -- kaiju in the pen
Kennel.Scale = 0.75 -- their size (a pet is Kaiju.Scale.Pet, a wild one Wild)
Kennel.DaySeconds = 86400

-- Their day: each spell lasts Spell seconds, and a resident walks to a
-- new spot in one spell in Walk of them (Mood weights for the rest). A
-- walk takes it Speed studs a second, never longer than the spell, and
-- it turns to face the way it's going over Turn seconds.
Kennel.Spell = 4.5
Kennel.Walk = 0.7
Kennel.Speed = 3.2
Kennel.Turn = 0.6
Kennel.Moods = { Sniff = 3, Look = 3, Rest = 2, Sleep = 1, Roar = 1 }

-- A number from 0 to 1 made from its parts, the same everywhere (no
-- Random: every client must agree, and it's cheap).
-- (Each step mixes with shifts and XOR as well as multiplying: with
-- multiplying alone, two hashes differing only in their last part came out
-- in step with each other.)
local function mix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 48271) % 2147483647
	h = bit32.bxor(h, bit32.rshift(h, 11))
	return (h * 16807) % 2147483647
end
local function hash(...): number
	local h = 2166136
	for _, part in { ... } do
		local text = tostring(part)
		for i = 1, #text do
			h = mix((h * 31 + string.byte(text, i)) % 2147483647)
		end
		h = mix(h)
	end
	return mix(h) / 2147483647
end
Kennel.hash = hash

function Kennel.day(now: number): number
	return math.floor(now / Kennel.DaySeconds)
end

-- The rarest batch's kinds, in the roster's order.
local function rarest(): { string }
	local kinds = {}
	for _, id in KaijuRoster.Order do
		if Kaiju.batch(id) == 1 and Kaiju.Species[id] and not Kaiju.Benched[id] then
			table.insert(kinds, id)
		end
	end
	return kinds
end

local function elementFor(day: number, salt: string): string
	local elements = Kaiju.Elements
	return elements[math.floor(hash(day, salt, "element") * #elements) + 1]
end

function Kennel.special(day: number): { Species: string, Element: string }
	-- (never a support kind: those are only caught)
	local kinds = {}
	for _, id in rarest() do
		if not Kaiju.isSupport(id) then
			table.insert(kinds, id)
		end
	end
	-- (Each day steps through the batch in a shuffled order, so the same
	-- kind doesn't come back for a month.)
	local order = table.clone(kinds)
	table.sort(order, function(a, b)
		return hash("special", a) < hash("special", b)
	end)
	return { Species = order[day % #order + 1], Element = elementFor(day, "special") }
end

function Kennel.residents(day: number): { { Species: string, Element: string } }
	local special = Kennel.special(day).Species
	local kinds = {}
	for _, id in rarest() do
		if id ~= special then
			table.insert(kinds, id)
		end
	end
	table.sort(kinds, function(a, b)
		return hash(day, "pen", a) < hash(day, "pen", b)
	end)
	local out = {}
	for i = 1, math.min(Kennel.Count, #kinds) do
		table.insert(out, { Species = kinds[i], Element = elementFor(day, kinds[i]) })
	end
	return out
end

-- Resident `index`'s spot `n`, somewhere in its own wedge of the pen:
-- in turn nearer the middle and nearer the fence, so each walk crosses it.
local function spot(index: number, count: number, n: number): Vector3
	local pen = Kennel.Pen
	local wedge = math.pi * 2 / count
	local a = (index - 1 + 0.15 + hash(index, n, "a") * 0.7) * wedge
	local half = (pen.Outer - pen.Inner) / 2
	local r = pen.Inner + (n % 2) * half + hash(index, n, "r") * half
	return pen.Middle + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function walks(index: number, n: number): boolean
	return hash(index, n, "walk") < Kennel.Walk
end

-- The last spell, `n` or before, it walked in (looking back no further
-- than a dozen: past that, as if it walked in the dozenth).
local function lastWalk(index: number, n: number): number
	for back = 0, 11 do
		if walks(index, n - back) then
			return n - back
		end
	end
	return n - 12
end

-- Where it stood at the end of spell `n`, and the way it last walked
-- (from where it stood before that walk).
local function rest(index: number, count: number, n: number): (Vector3, Vector3)
	local k = lastWalk(index, n)
	local to = spot(index, count, k)
	local from = spot(index, count, lastWalk(index, k - 1))
	local way = (to - from) * Vector3.new(1, 0, 1)
	return to, if way.Magnitude > 0.01 then way.Unit else (Kennel.Pen.Middle - to).Unit
end

local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

local function mood(index: number, n: number): string
	local total = 0
	for _, weight in Kennel.Moods do
		total += weight
	end
	local roll = hash(index, n, "mood") * total
	for _, name in { "Sniff", "Look", "Rest", "Sleep", "Roar" } do
		roll -= Kennel.Moods[name]
		if roll <= 0 then
			return name
		end
	end
	return "Look"
end

function Kennel.state(index: number, count: number, now: number)
	local spell = Kennel.Spell
	-- (Each resident's spells start at its own moment, so they don't all
	-- set off at once.)
	local t = now + hash(index, "offset") * spell
	local n = math.floor(t / spell)
	local into = t - n * spell
	local start = now - into
	local from, look = rest(index, count, n - 1)
	if walks(index, n) then
		local to = spot(index, count, n)
		local way = (to - from) * Vector3.new(1, 0, 1)
		local length = way.Magnitude
		local speed = math.max(Kennel.Speed, length / (spell - 1))
		local took = length / speed
		local newLook = if length > 0.01 then way.Unit else look
		-- (It turns to face the way first, then sets off.)
		local turned = math.clamp(into / Kennel.Turn, 0, 1)
		local yaw0, yaw1 = yawOf(look), yawOf(newLook)
		local d = (yaw1 - yaw0 + math.pi) % (math.pi * 2) - math.pi
		local moving = into - Kennel.Turn
		if moving <= 0 then
			return { Position = from, Yaw = yaw0 + d * turned, Speed = 0, Mood = nil, MoodAt = start }
		elseif moving < took then
			return { Position = from + way * (moving / took), Yaw = yaw1, Speed = speed, Mood = nil, MoodAt = start }
		end
		return { Position = to, Yaw = yaw1, Speed = 0, Mood = "Look", MoodAt = start + Kennel.Turn + took }
	end
	return { Position = from, Yaw = yawOf(look), Speed = 0, Mood = mood(index, n), MoodAt = start }
end

return Kennel
