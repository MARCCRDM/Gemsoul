--[[
	Saga Outpost: the shared mining basin on the moon. Everyone in the
	server mines the same rocks, sees each other, trades at the Probe and
	challenges each other to duels. The rules, shared by the server (which
	decides everything) and the client (which shows it).

	Rocks come in four sizes. Bigger ones take more hits, hide better finds
	and take longer to grow back once mined out (like ore nodes in an MMO).
	Swinging wears your pick: every swing costs one point of durability, and
	a pick at zero breaks. The free Survey Pick regains a swing every
	FreeSwingSeconds (up to its full 60), so there's a little mining every
	time you come back; better picks are bought at the Probe.

	  Outpost.Sizes / Outpost.SizeOrder      the rocks
	  Outpost.Picks / Outpost.PickOrder      the picks
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

-- Where the Skyport is in the world (its centre, on the ground): a compact
-- floating island, with rocks growing on three mining rings.
Outpost.Location = CFrame.new(0, 0, 7000)
Outpost.Radius = 112 -- the island's walkable radius
Outpost.NodeCount = 34 -- rocks out at once, across the three rings
Outpost.ClaimSeconds = 8 -- a rock stays with its first hitter this long after each swing
Outpost.Reach = 11 -- studs from the rock you can swing from
Outpost.SwingCooldown = 0.32
Outpost.CritChance = 0.15

-- Rocks, smallest to rarest. `Depth` is how deep a wall of the old mine
-- this matches, for gem luck and gear finds.
Outpost.Sizes = {
	Pebble = {
		Name = "Regolith Chunk",
		Hp = 4,
		Respawn = 20,
		Weight = 44,
		Scale = 3.6,
		Depth = 2,
		Gem = 0.35,
		CoinChance = 0.3,
		Coins = { 2, 6 },
		Gear = 0.04,
	},
	Boulder = {
		Name = "Crystal Boulder",
		Hp = 7,
		Respawn = 35,
		Weight = 34,
		Scale = 6,
		Depth = 5,
		Gem = 0.55,
		CoinChance = 0.4,
		Coins = { 4, 10 },
		Gear = 0.1,
	},
	Monolith = {
		Name = "Saga Monolith",
		Hp = 11,
		Respawn = 60,
		Weight = 17,
		Scale = 8.5,
		Depth = 9,
		Gem = 0.75,
		CoinChance = 0.5,
		Coins = { 8, 18 },
		Gear = 0.2,
	},
	Geode = {
		Name = "Star Geode",
		Hp = 16,
		Respawn = 120,
		Weight = 5,
		Scale = 7,
		Depth = 14,
		Gem = 1,
		CoinChance = 1,
		Coins = { 20, 45 },
		Gear = 0.4,
		Luck = 0.35, -- on top of its depth
	},
}
Outpost.SizeOrder = { "Pebble", "Boulder", "Monolith", "Geode" }

-- Picks: swings before they break, layers per swing, extra crit chance.
Outpost.Picks = {
	Survey = {
		Name = "Survey Pick",
		Swings = 60,
		Power = 1,
		Crit = 0,
		Price = 0,
		Color = Color3.fromRGB(176, 150, 120),
	},
	Titan = {
		Name = "Titan Pick",
		Swings = 160,
		Power = 1,
		Crit = 0.08,
		Price = 900,
		Color = Color3.fromRGB(150, 196, 225),
	},
	Plasma = {
		Name = "Plasma Drill",
		Swings = 250,
		Power = 1.5,
		Crit = 0.12,
		Price = 2400,
		Color = Color3.fromRGB(255, 120, 230),
	},
}
Outpost.PickOrder = { "Survey", "Titan", "Plasma" }

-- The mining rings: each grows its own mix of rocks (size weights).
Outpost.Zones = {
	Common = { Name = "Common Field", Weights = { Pebble = 62, Boulder = 38 } },
	Deep = { Name = "Deep Vein", Weights = { Boulder = 58, Monolith = 42 } },
	Crystal = { Name = "Crystal Crown", Weights = { Monolith = 68, Geode = 32 } },
}
Outpost.ZoneOrder = { "Common", "Deep", "Crystal" }

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
-- Tracked machines can turn on the spot.
Outpost.Machines = {
	Hauler = { Name = "HX-9 Hauler", Blurb = "Six-wheel dump truck", MaxSpeed = 46, Accel = 16, Turn = 0.9 },
	Mole = {
		Name = "Mole Drill Crawler",
		Blurb = "Tracked rock drill",
		MaxSpeed = 30,
		Accel = 12,
		Turn = 1.1,
		Tracked = true,
	},
	Digger = {
		Name = "EX-4 Digger",
		Blurb = "Tracked excavator",
		MaxSpeed = 24,
		Accel = 10,
		Turn = 1.2,
		Tracked = true,
	},
	Skipper = { Name = "Skipper Rover", Blurb = "Fast moon buggy", MaxSpeed = 72, Accel = 34, Turn = 1.9 },
}
Outpost.MachineOrder = { "Hauler", "Mole", "Digger", "Skipper" }
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
	-- Wheels steer with speed (and the other way backing up); tracks turn on the spot.
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
