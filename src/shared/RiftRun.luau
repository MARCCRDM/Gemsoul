--[[
	The Rift (docs/rift.md): a Rift Vein's gate opens on the critters' own
	world, a walled pathway of caves open to a burning sky. Its rules, with
	no Roblox services (Server.RiftServer runs a trip, Server.RiftWorld
	builds the path, Client.RiftClient shows it).

	  The way    a landing, then Rooms caves one after another, then the
	             throne cave, joined by passages on a grid (layout: the
	             pathway dungeon's, a path that never touches itself).
	             Walled all round: there's nowhere to fall.
	  A cave     its own pack: brainrot critters (Foes by cave, PerRunner
	             more for each runner past the first; a ranged one only at
	             the back, Kaiju.wave) and, from cave Elite.From, now and
	             then a big one among them (Elite), led by the pathway
	             dungeon's regular fighters (Fighters: armed and armoured
	             to their gear tier). The pack comes through tears in the
	             cave's floor as you walk in, a tear at a time (Portal:
	             the critters first, then their leaders). Your kaiju take
	             the critters; you take the leaders. A wall of fire bars
	             the way on until the cave's cleared; cleared, everyone in
	             finds a Cache (a gem, luckier further in).
	  The boss   one of the ten brainrot bosses (DungeonRules.Bosses) at
	             random, as a Colossus: the pathway dungeon's boss fighter,
	             with Boss.Health times its health (more with more
	             runners). At each of Boss.Adds (shares of its health left)
	             it tears the ground open and Boss.AddCount critters and
	             Boss.AddFighters fighters come through. Beaten: its loot
	             (Loot: claim, roll or pass, as in the pathway dungeon: a
	             gem of its element, Ultra Rare at gear tier 4, Legendary
	             at 5) and Reward for everyone still in, then the way home
	             opens (Exit seconds, then through it you go).
	  Levels     the critters come at the runners' kaiju's level (the
	             average of their leads), Level.Base over it in the first
	             cave and PerRoom more each cave; the boss's critters
	             Level.Boss over the last cave's.
	  Healing    each cave (the throne cave too) has Heal.PerCave healing
	             crystals by its walls: green rocks you mine with your pick
	             (1 swaps your kit for it) for health, never gems. Each
	             swing heals you Heal.Swing of your health; broken open
	             (Heal.Hp swings), Heal.Pop more, and your kaiju out
	             Heal.Kaiju of theirs. It grows back Heal.Regrow seconds
	             later (healSpots: where they stand).
	  Falling    knocked out on the way, the critters rob you (Rob.Share of
	             the gems you've found in here, at least one): the cave's
	             come for you, more through tears if too few are near,
	             each grabbing one and running; then you're thrown back to
	             base with a report of what they took (Shared.Frontier.Rob,
	             Server.Robbery). Knocked out at the boss, you choose:
	             invite a friend, RESTORE (your health and your kaiju's
	             team, for Restore.Coins, Grow times more each time in a
	             trip) or back to base with what you found. Nothing chosen
	             in Fallen seconds: back to base. (Through the floor
	             somehow, Fall.Below studs under it: back in the last cave
	             you reached.)
	  Together   it's built for a party: up to Party runners, joining
	             through any gate while their party's trip is still on the
	             way. Going in alone, you're warned (RiftRun.solo).
]]
local DungeonRules = require(script.Parent.DungeonRules)
local Kaiju = require(script.Parent.Kaiju)

local RiftRun = {}

RiftRun.Rooms = 4
RiftRun.Party = 4
RiftRun.Foes = { 3, 4, 4, 5 }
RiftRun.PerRunner = 1
RiftRun.Elite = { From = 2, Chance = 0.6, Scale = 1, Health = 4, Damage = 1.5, Reach = 1.6 }
RiftRun.Fighters = { Count = { 1, 1, 2, 2 }, PerRunner = 0.5, Tier = { 1, 2, 2, 3 }, Health = 1.5 }
RiftRun.Level = { Base = 2, PerRoom = 1, Boss = 3, Max = 30 }
RiftRun.Boss = {
	Health = 1.8,
	PerRunner = 0.5,
	Adds = { 0.66, 0.33 },
	AddCount = 3,
	AddFighters = 1,
	AddTier = 3,
}
RiftRun.Cache = { Luck = 0.12, PerRoom = 0.06 }
RiftRun.Reward = { Coins = 300, PerRoom = 40, Luck = 0.6, Exp = 120 }
RiftRun.Loot = { Seconds = 30 }
RiftRun.Rob = { Share = 0.5 }
RiftRun.Heal = { PerCave = 2, Hp = 5, Swing = 0.07, Pop = 0.25, Kaiju = 0.35, Regrow = 40, Reach = 10, Inset = 15 }
RiftRun.Restore = { Coins = 150, Grow = 2 }
RiftRun.Fallen = 60
RiftRun.Fall = { Below = 20 }
RiftRun.Exit = 20
-- Every foe comes through a tear of its own: Every seconds apart, each tear
-- Apart studs or more from the pack's others and Clear from any runner,
-- inside Share of the cave's radius; it leaps out Hop studs a second at
-- the runners. A leader's tear stands Leader studs tall, the boss's Boss (a
-- critter's is the Outpost's size, Shared.Frontier.Rift).
RiftRun.Portal = { Every = 0.45, Apart = 9, Clear = 9, Share = 0.6, Hop = 18, Leader = 10, Boss = 16 }

-- How many critters come at cave `room` (1..Rooms) for `runners` runners.
function RiftRun.foeCount(room: number, runners: number): number
	local base = RiftRun.Foes[math.clamp(room, 1, #RiftRun.Foes)]
	return base + math.floor((math.max(1, runners) - 1) * RiftRun.PerRunner + 0.5)
end

-- How many of the pathway dungeon's fighters stand in cave `room`.
function RiftRun.fighterCount(room: number, runners: number): number
	local rule = RiftRun.Fighters
	local base = rule.Count[math.clamp(room, 1, #rule.Count)]
	return base + math.floor((math.max(1, runners) - 1) * rule.PerRunner)
end

-- Their gear tier (1..5, DungeonLoadout) in cave `room`.
function RiftRun.fighterTier(room: number): number
	local tiers = RiftRun.Fighters.Tier
	return tiers[math.clamp(room, 1, #tiers)]
end

-- Cave `room`'s critters: { { Critter = roster id, Elite = boolean } }, a
-- ranged one only at the back (Kaiju.wave), and from Elite.From on, now
-- and then the first of them a big one. `rng` has NextInteger and NextNumber.
function RiftRun.pickFoes(room: number, runners: number, rng): { { Critter: string, Elite: boolean } }
	local pack = {}
	for _, id in Kaiju.wave(RiftRun.foeCount(room, runners), rng) do
		table.insert(pack, { Critter = id, Elite = false })
	end
	if room >= RiftRun.Elite.From and rng:NextNumber() < RiftRun.Elite.Chance then
		for _, foe in pack do
			if not Kaiju.isRanged(foe.Critter) then
				foe.Elite = true
				break
			end
		end
	end
	return pack
end

-- Cave `room`'s fighters: one of the pathway dungeon's roster (its element
-- and moves: DungeonRules.Roster) for the whole cave.
function RiftRun.pickFighters(room: number, runners: number, rng): { any }
	local spec = DungeonRules.Roster[rng:NextInteger(1, #DungeonRules.Roster)]
	local list = {}
	for _ = 1, RiftRun.fighterCount(room, runners) do
		table.insert(list, spec)
	end
	return list
end

-- Where a pack's `count` tears open on a cave's floor (`center`, `radius`):
-- spread out (Portal.Apart) and clear of the runners standing at `avoid`
-- (Portal.Clear), the best of a few tries when the cave's crowded. `rng` has
-- NextNumber.
-- Where a cave's healing crystals stand: toward `count` of its four corners
-- (a `size`-wide square round `center`), Heal.Inset studs in from its walls:
-- clear of the braziers in the corners and the passages in the middle of
-- each wall. `rng` has NextInteger.
function RiftRun.healSpots(center: Vector3, size: number, count: number, rng): { Vector3 }
	local half = size / 2 - RiftRun.Heal.Inset
	local corners = {
		Vector3.new(half, 0, half),
		Vector3.new(-half, 0, half),
		Vector3.new(half, 0, -half),
		Vector3.new(-half, 0, -half),
	}
	for i = #corners, 2, -1 do
		local j = rng:NextInteger(1, i)
		corners[i], corners[j] = corners[j], corners[i]
	end
	local spots = {}
	for i = 1, math.min(count, #corners) do
		table.insert(spots, center + corners[i])
	end
	return spots
end

function RiftRun.portalSpots(center: Vector3, radius: number, count: number, avoid: { Vector3 }, rng): { Vector3 }
	local rule = RiftRun.Portal
	local function apart(p: Vector3, q: Vector3): number
		return Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
	end
	local spots = {}
	for _ = 1, count do
		local best, bestRoom = nil, -math.huge
		for _ = 1, 24 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = radius * rule.Share * math.sqrt(rng:NextNumber(0.05, 1))
			local spot = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			-- (How much room it has, the tightest of its rules.)
			local room = math.huge
			for _, other in spots do
				room = math.min(room, apart(spot, other) - rule.Apart)
			end
			for _, runner in avoid do
				room = math.min(room, apart(spot, runner) - rule.Clear)
			end
			if room > bestRoom then
				best, bestRoom = spot, room
			end
			if room >= 0 then
				break
			end
		end
		table.insert(spots, best :: Vector3)
	end
	return spots
end

-- The critters' level in cave `room` (Rooms + 1: the boss's), for runners
-- whose lead kaiju are at `levels` (none: level 1).
function RiftRun.level(levels: { number }, room: number): number
	local sum = 0
	for _, level in levels do
		sum += level
	end
	local base = if #levels > 0 then math.floor(sum / #levels + 0.5) else 1
	local rule = RiftRun.Level
	local level = base + rule.Base + rule.PerRoom * (math.min(room, RiftRun.Rooms) - 1)
	if room > RiftRun.Rooms then
		level += rule.Boss
	end
	return math.clamp(level, 1, rule.Max)
end

-- One of the ten brainrot bosses, at random.
function RiftRun.pickBoss(rng)
	return DungeonRules.Bosses[rng:NextInteger(1, #DungeonRules.Bosses)]
end

-- The boss's health, times a Colossus's, for `runners` runners.
function RiftRun.bossHealth(runners: number): number
	local rule = RiftRun.Boss
	return rule.Health * (1 + rule.PerRunner * (math.max(1, runners) - 1))
end

-- The boss's gear tier: 4 alone (its gem Ultra Rare), 4 or 5 for a party.
function RiftRun.bossTier(runners: number, rng): number
	return if runners <= 1 then 4 else rng:NextInteger(4, 5)
end

-- Which of Boss.Adds the boss has just come down past (its health `share`
-- left, 0..1), not counting the ones in `done`; nil if none.
function RiftRun.addsDue(share: number, done: { [number]: boolean }): number?
	for i, at in RiftRun.Boss.Adds do
		if not done[i] and share <= at then
			return i
		end
	end
	return nil
end

-- A cleared cave's cache: how lucky its gem is.
function RiftRun.cacheLuck(room: number): number
	return RiftRun.Cache.Luck + RiftRun.Cache.PerRoom * (math.max(1, room) - 1)
end

-- What beating the boss pays in coins, `rooms` cleared on the way.
function RiftRun.rewardCoins(rooms: number): number
	return RiftRun.Reward.Coins + RiftRun.Reward.PerRoom * rooms
end

-- How many of the `found` gems the critters take off you when you fall.
function RiftRun.robCount(found: number): number
	if found <= 0 then
		return 0
	end
	return math.clamp(math.ceil(found * RiftRun.Rob.Share), 1, found)
end

-- What RESTORE costs after `used` restores this trip.
function RiftRun.restoreCost(used: number): number
	return math.floor(RiftRun.Restore.Coins * RiftRun.Restore.Grow ^ math.max(0, used) + 0.5)
end

-- Going in alone (warned: it's built for a party).
function RiftRun.solo(runners: number): boolean
	return runners <= 1
end

-- The way through: Rooms + 2 cells on a grid ({ X, Z }), the landing first
-- and the throne cave last, each the next one's neighbour, and never one
-- beside an earlier one but its own (the pathway dungeon's rule: the path
-- doesn't touch itself). The first step is always +Z, so the landing faces
-- the way in.
local STEPS = { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }
function RiftRun.layout(rng): { { X: number, Z: number } }
	local cells = { { X = 0, Z = 0 } }
	local used = { ["0:0"] = true }
	for i = 2, RiftRun.Rooms + 2 do
		local previous = cells[i - 1]
		local free = {}
		for _, d in if i == 2 then { STEPS[1] } else STEPS do
			local x, z = previous.X + d[1], previous.Z + d[2]
			local clear = not used[x .. ":" .. z]
			for _, side in STEPS do
				local ax, az = x + side[1], z + side[2]
				if used[ax .. ":" .. az] and (ax ~= previous.X or az ~= previous.Z) then
					clear = false
				end
			end
			if clear then
				table.insert(free, { X = x, Z = z })
			end
		end
		-- (A path this short always has a free way on.)
		assert(#free > 0, "The Rift's path has no way on")
		local cell = free[rng:NextInteger(1, #free)]
		used[cell.X .. ":" .. cell.Z] = true
		table.insert(cells, cell)
	end
	return cells
end

return RiftRun
