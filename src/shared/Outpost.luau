--[[
	Saga Outpost: the shared mining basin on the moon. Everyone in the
	server mines the same rocks, sees each other, trades at the Probe and
	challenges each other to duels. The rules, shared by the server (which
	decides everything) and the client (which shows it).

	Rocks come in four sizes. Bigger ones take more hits, hide better finds
	and take longer to grow back once mined out (like ore nodes in an MMO).
	Every swing spends one of your pick's swings. The free Survey Pick
	regains a swing every FreeSwingSeconds (up to its full 60), so there's a
	little mining every time you come back; refills (more swings, on top of
	those) are bought at the Probe.

	  Outpost.Sizes / Outpost.SizeOrder      the rocks
	  Outpost.Picks / Outpost.PickOrder      the pick (the free Survey Pick)
	  Outpost.Refills / Outpost.RefillOrder  the swings PROBE-7 sells
	  Outpost.legacySwings(picks)            swings for picks a save still
	                                         holds from when the Probe sold them
	  Outpost.rollSize(roll, zone?)          a new rock's size (a ring's mix), 0 <= roll < 1
	  Outpost.damage(pick, crit)             how many layers a swing chips
	  Outpost.tension(hp, maxHp)             0 (fresh) .. 1 (about to pop): how
	                                         loud and high the hit sound rings
	  Outpost.claimHolder(node, userId, now) may this player hit this rock?
	                                         (its first hitter keeps it a while)
	  Outpost.refillSurvey(swings, since, now) the free pick's swings regained
	                                         since `since` -> swings, since
	  Outpost.Machines / Outpost.MachineOrder   the big machines anyone can drive
	                                         (just for getting around: no tools)
	  Outpost.Secrets / Outpost.SecretOrder  the hidden Easter eggs
	  Outpost.drive(spec, speed, yaw, throttle, steer, dt) -> speed, yaw
	                                         one step of a machine's driving
]]
local Outpost = {}

-- The original moon quarry, with haul roads and a drivable Motor Pool.
Outpost.Location = CFrame.new(0, 0, 7000)
Outpost.Radius = 440 -- quarry rim; recovery allows the surrounding benches
Outpost.NodeCount = 210 -- rocks out at once (every spot: the field round the middle, the candy trails and their veins)
Outpost.FieldNodeCount = 0 -- this lobby uses the common quarry sites
Outpost.ClaimSeconds = 8 -- a rock stays with its first hitter this long after each swing
Outpost.Reach = 11 -- studs from the rock you can swing from
Outpost.SwingCooldown = 0.32
Outpost.CritChance = 0.15

-- Rocks, smallest to rarest. Every rock pays exactly one gem when it pops
-- (a Common at worst): no coins, no gear. `Depth` is how deep a wall of the
-- old mine this matches, for that gem's luck; a Geode adds `Luck` on top.
Outpost.Sizes = {
	Pebble = {
		Name = "Regolith Chunk",
		Hp = 4,
		Respawn = 20,
		Weight = 44,
		Scale = 3.6,
		Depth = 2,
	},
	Boulder = {
		Name = "Crystal Boulder",
		Hp = 7,
		Respawn = 35,
		Weight = 34,
		Scale = 6,
		Depth = 5,
	},
	Monolith = {
		Name = "Saga Monolith",
		Hp = 11,
		Respawn = 60,
		Weight = 17,
		Scale = 8.5,
		Depth = 9,
	},
	Geode = {
		Name = "Star Geode",
		Hp = 16,
		Respawn = 120,
		Weight = 5,
		Scale = 7,
		Depth = 14,
		Luck = 0.35, -- on top of its depth
	},
}
Outpost.SizeOrder = { "Pebble", "Boulder", "Monolith", "Geode" }

-- The pick: its full charge, layers per swing, extra crit chance. Tag and
-- Blurb are what PROBE-7 says about it.
Outpost.Picks = {
	Survey = {
		Name = "Survey Pick",
		Tag = "FREE",
		Blurb = "Recharges itself while you're away.",
		Swings = 60,
		Power = 1,
		Crit = 0,
		Price = 0,
		Color = Color3.fromRGB(176, 150, 120),
	},
}
Outpost.PickOrder = { "Survey" }

-- What PROBE-7 sells: swings for your pick, on top of its free charge (they
-- go first; it recharges again once it's back under its full 60).
Outpost.Refills = {
	Refill = {
		Name = "Swing Refill",
		Tag = "REFILL",
		Blurb = "A full charge, on top of yours.",
		Swings = 60,
		Price = 300,
		Color = Color3.fromRGB(58, 203, 233),
	},
	Mega = {
		Name = "Mega Refill",
		Tag = "MEGA",
		Blurb = "200 swings, 20% cheaper each.",
		Swings = 200,
		Price = 800,
		Color = Color3.fromRGB(255, 202, 91),
	},
}
Outpost.RefillOrder = { "Refill", "Mega" }

-- The Probe used to sell better picks. A save that still holds one gets its
-- swings as extra swings instead (a Plasma Drill's at its 1.5 power).
Outpost.LegacyPicks = { Titan = 1, Plasma = 1.5 }
function Outpost.legacySwings(picks: { [string]: number }): number
	local swings = 0
	for id, power in Outpost.LegacyPicks do
		swings += math.floor((picks[id] or 0) * power)
	end
	return swings
end

-- Only basic chunks/boulders spawn in the lobby, including every respawn.
-- Retain the deeper definitions for other content and saved references.
-- Out along the candy trails (Shared.Frontier) the boulders grow commoner
-- and every gem rolls luckier (`Luck`, on top of the rock's own): the
-- further out, the richer, and a trail's end (its Rift Vein) the richest.
Outpost.Zones = {
	Field = { Name = "Corundum Meadow", Weights = { Pebble = 68, Boulder = 32 } },
	Common = { Name = "Common Field", Weights = { Pebble = 62, Boulder = 38 } },
	Fringe = { Name = "The Fringe", Weights = { Pebble = 50, Boulder = 50 }, Luck = 0.08 },
	Edge = { Name = "The Edge", Weights = { Pebble = 35, Boulder = 65 }, Luck = 0.16 },
	Vein = { Name = "Rift Vein", Weights = { Pebble = 15, Boulder = 85 }, Luck = 0.25 },
	Deep = { Name = "Deep Vein", Weights = { Boulder = 58, Monolith = 42 } },
	Crystal = { Name = "Crystal Crown", Weights = { Monolith = 68, Geode = 32 } },
}
Outpost.ZoneOrder = { "Common", "Fringe", "Edge", "Vein" }

-- A rock size from a 0..1 roll: the zone's mix, or every size's own Weight.
function Outpost.rollSize(roll: number, zone: string?): string
	local mix = zone and Outpost.Zones[zone] and Outpost.Zones[zone].Weights
	local function weight(id: string): number
		return if mix then mix[id] or 0 else Outpost.Sizes[id].Weight
	end
	local total = 0
	for _, id in Outpost.SizeOrder do
		total += weight(id)
	end
	local pick = roll * total
	for _, id in Outpost.SizeOrder do
		pick -= weight(id)
		if pick < 0 then
			return id
		end
	end
	return Outpost.SizeOrder[1]
end

-- Big machines parked at the Motor Pool. Anyone can hop in and drive; they
-- don't dig or haul, they're for crossing the quarry (and showing off).
-- Speeds in studs a second, Turn in radians a second at full lock.
-- All exosuits can pivot in place. Stable IDs preserve the Motor Pool bays.
Outpost.Machines = {
	Hauler = {
		Name = "Atlas Hauler Mech",
		Blurb = "Heavy cargo exosuit",
		MaxSpeed = 26,
		Accel = 12,
		Turn = 0.9,
		Tracked = true,
		Mine = { Strikes = 4, Cooldown = 0.75 },
	},
	Mole = {
		Name = "Mole Drill Mech",
		Blurb = "Arm-mounted drilling frame",
		MaxSpeed = 24,
		Accel = 12,
		Turn = 1.1,
		Tracked = true,
		Mine = { Strikes = 3, Cooldown = 0.45 },
	},
	Digger = {
		Name = "Forge Utility Mech",
		Blurb = "Industrial claw exosuit",
		MaxSpeed = 22,
		Accel = 10,
		Turn = 1.2,
		Tracked = true,
		Mine = { Strikes = 3, Cooldown = 0.55 },
	},
	Skipper = {
		Name = "Scout Pathfinder Mech",
		Blurb = "Light exploration frame",
		MaxSpeed = 36,
		Accel = 20,
		Turn = 1.6,
		Tracked = true,
		Mine = { Strikes = 2, Cooldown = 0.42 },
	},
}
Outpost.MachineOrder = { "Hauler", "Mole", "Digger", "Skipper" }

-- Mechs mine too, from the cockpit. A strike lands Strikes swings' worth of
-- your pick at once and spends that many swings (fewer if that's all you
-- have left), so a swing's energy digs the same either way: a mech just
-- hits harder and sooner (Cooldown: seconds between strikes).
Outpost.MechReach = 14 -- flat studs from a rock's middle a mech can strike from
function Outpost.mechStrikes(machineId: string?, swingsLeft: number): number
	local spec = machineId and Outpost.Machines[machineId]
	local mine = spec and spec.Mine
	return if mine then math.max(0, math.min(mine.Strikes, swingsLeft)) else 0
end
Outpost.ReverseShare = 0.4 -- top speed backing up, as a share of forward
Outpost.MachineResetSeconds = 90 -- an abandoned machine drives itself home after this

-- One step of driving. Throttle and steer are -1..1 (the seat's input).
-- Returns the new speed and heading (yaw, radians).
function Outpost.drive(spec, speed: number, yaw: number, throttle: number, steer: number, dt: number): (number, number)
	local top = if throttle >= 0 then spec.MaxSpeed else spec.MaxSpeed * Outpost.ReverseShare
	local want = throttle * top
	-- Accelerate towards the wanted speed; brake twice as hard as you speed up.
	local rate = if math.abs(want) < math.abs(speed) or want * speed < 0 then spec.Accel * 2 else spec.Accel
	local step = math.clamp(want - speed, -rate * dt, rate * dt)
	speed += step
	-- Pivot-capable frames turn in place; legacy wheeled specs retain speed-based steering.
	local grip = if spec.Tracked then 1 else math.clamp(math.abs(speed) / 8, 0, 1)
	local direction = if speed < -0.5 and not spec.Tracked then -1 else 1
	yaw -= steer * spec.Turn * grip * direction * dt
	return speed, yaw
end

-- Easter eggs hidden around the quarry. Each pays once per player.
Outpost.SecretReward = 75
Outpost.SecretBonus = 500 -- for finding every one
Outpost.Secrets = {
	Monolith = {
		Name = "The Black Monolith",
		Lore = "It hums when you touch it. Something was watching this moon long before Saga arrived.",
	},
	Duck = {
		Name = "Commander Quackers",
		Lore = "A rubber duck, perfectly preserved. Nobody at the outpost will admit it's theirs.",
	},
	Bomber = {
		Name = "The Croc Bomber Wreck",
		Lore = "Black box, last entry: 'Snout stuck in the throttle again. Going down. Tell the crew-' ... static.",
	},
	Skeleton = {
		Name = "Ancient Moon Beast",
		Lore = "Ribs taller than a hauler. Whatever this was, it mined with its teeth.",
	},
	Shrine = {
		Name = "Sahur's Shrine",
		Lore = "Tung. Tung. Tung. Someone keeps leaving fresh offerings. On the moon.",
	},
	Footprint = {
		Name = "The First Footprint",
		Lore = "The plaque reads: 'One small step for a miner. One giant haul for minerkind.'",
	},
}
Outpost.SecretOrder = { "Monolith", "Duck", "Bomber", "Skeleton", "Shrine", "Footprint" }

function Outpost.damage(pickId: string, crit: boolean): number
	local pick = Outpost.Picks[pickId] or Outpost.Picks.Survey
	return pick.Power * (if crit then 2 else 1)
end

function Outpost.tension(hp: number, maxHp: number): number
	if maxHp <= 0 then
		return 1
	end
	return math.clamp(1 - hp / maxHp, 0, 1)
end

-- `node`: { ClaimedBy: number?, ClaimUntil: number? }. True when this player
-- may swing at it now.
function Outpost.claimHolder(node, userId: number, now: number): boolean
	return node.ClaimedBy == nil or node.ClaimedBy == userId or now >= (node.ClaimUntil or 0)
end

-- The free Survey Pick regains one swing this often, up to its full Swings.
Outpost.FreeSwingSeconds = 120
function Outpost.refillSurvey(swings: number, since: number, now: number): (number, number)
	local full = Outpost.Picks.Survey.Swings
	if swings >= full then
		return swings, now -- full: the clock waits until a swing is spent
	end
	local gained = math.floor((now - since) / Outpost.FreeSwingSeconds)
	if gained <= 0 then
		return swings, since
	end
	local total = math.min(full, swings + gained)
	return total, if total >= full then now else since + gained * Outpost.FreeSwingSeconds
end

-- The free pick as a charge at `now`: swings, seconds until the next one
-- (nil when full) and the progress toward it (0..1, 1 when full).
function Outpost.surveyCharge(swings: number, since: number, now: number): (number, number?, number)
	local full = Outpost.Picks.Survey.Swings
	local charged, from = Outpost.refillSurvey(swings, since, now)
	if charged >= full then
		return charged, nil, 1
	end
	local into = math.clamp(now - from, 0, Outpost.FreeSwingSeconds)
	return charged, math.max(0, math.ceil(Outpost.FreeSwingSeconds - into)), into / Outpost.FreeSwingSeconds
end

-- "1:42" (or "1:59:36") for a countdown in seconds.
function Outpost.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Outpost
