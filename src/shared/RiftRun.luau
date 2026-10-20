--[[
	The Rift (docs/rift.md): a Rift Vein's gate opens on the critters' own
	world, a burning pathway of islands over a sea of lava. Its rules, with
	no Roblox services (Server.RiftServer runs a trip, Server.RiftWorld
	builds the path, Client.RiftClient shows it).

	  A trip     Rooms islands one after another, each with its own pack of
	             brainrot critters (Foes by room, PerRunner more for each
	             runner past the first; a ranged one only at the back,
	             Kaiju.wave) and, from room Elite.From, now and then a big
	             one among them (Elite). A wall of fire bars the way on
	             until the island's cleared; cleared, everyone in finds a
	             Cache (a gem, luckier further in). Then the boss, one of
	             the ten brainrot bosses (DungeonRules.Bosses) at random,
	             on its own island: big and tough (Boss: tougher with more
	             runners), and at each of Boss.Adds (shares of its health
	             left) it tears the ground open and Boss.AddCount critters
	             come through. Beaten: Reward for everyone still in, and
	             the way home opens (Exit seconds, then through it you go).
	  Levels     the critters come at the runners' kaiju's level (the
	             average of their leads), Level.Base over it in the first
	             room and PerRoom more each room; the boss Level.Boss over
	             the last room's.
	  Falling    knocked out on the path, the critters rob you (Rob.Share
	             of the gems you've found in here, at least one) and you're
	             thrown back to base. Knocked out at the boss, you choose:
	             invite a friend, RESTORE (your health and your kaiju's
	             team, for Restore.Coins, Grow times more each time in a
	             trip) or back to base with what you found. Nothing chosen
	             in Fallen seconds: back to base. Off the path into the
	             lava (Fall.Below studs under it): back on the last island
	             you reached, Fall.Hurt of your health gone.
	  Together   it's built for a party: up to Party runners, joining
	             through any gate while their party's trip is still on the
	             path. Going in alone, you're warned (RiftRun.solo).
]]
local DungeonRules = require(script.Parent.DungeonRules)
local Kaiju = require(script.Parent.Kaiju)

local RiftRun = {}

RiftRun.Rooms = 4
RiftRun.Party = 4
RiftRun.Foes = { 3, 4, 5, 6 }
RiftRun.PerRunner = 1.5
RiftRun.Elite = { From = 2, Chance = 0.6, Scale = 1, Health = 4, Damage = 1.5, Reach = 1.6 }
RiftRun.Level = { Base = 2, PerRoom = 1, Boss = 3, Max = 30 }
RiftRun.Boss = {
	Scale = 1.7,
	Health = 40,
	Damage = 2.6,
	Reach = 2.4,
	PerRunner = 0.6,
	Adds = { 0.66, 0.33 },
	AddCount = 3,
}
RiftRun.Cache = { Luck = 0.12, PerRoom = 0.06 }
RiftRun.Reward = { Coins = 300, PerRoom = 40, Luck = 0.6, Exp = 120 }
RiftRun.Rob = { Share = 0.5 }
RiftRun.Restore = { Coins = 150, Grow = 2 }
RiftRun.Fallen = 60
RiftRun.Fall = { Below = 30, Hurt = 0.15 }
RiftRun.Exit = 25

-- How many critters come at room `room` (1..Rooms) for `runners` runners.
function RiftRun.foeCount(room: number, runners: number): number
	local base = RiftRun.Foes[math.clamp(room, 1, #RiftRun.Foes)]
	return base + math.floor((math.max(1, runners) - 1) * RiftRun.PerRunner + 0.5)
end

-- Room `room`'s pack: { { Critter = roster id, Elite = boolean } }, a
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

-- The critters' level in room `room` (Rooms + 1: the boss), for runners
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

-- The boss's health times its kind's, for `runners` runners.
function RiftRun.bossHealth(runners: number): number
	local rule = RiftRun.Boss
	return rule.Health * (1 + rule.PerRunner * (math.max(1, runners) - 1))
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

-- A cleared room's cache: how lucky its gem is.
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

return RiftRun
