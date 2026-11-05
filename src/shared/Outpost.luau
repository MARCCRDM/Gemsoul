--[[
	Saga Outpost: the shared mining basin on the moon. Everyone in the
	server mines the same rocks, sees each other, trades at the Market and
	challenges each other to duels. The rules, shared by the server (which
	decides everything) and the client (which shows it).

	Rocks come in four sizes. Bigger ones take more hits, hide better finds
	and take longer to grow back once mined out (like ore nodes in an MMO).
	Every swing spends one of your pick's swings. The free Survey Pick
	holds a long session's mining (its full 600: your kaiju fights and
	levels beside you while you mine) and regains a swing every
	FreeSwingSeconds, full again in two hours; refills (more swings, on top
	of those) are bought from Garrick, the mining foreman, for Robux. Bought
	swings sit in their own bank (picks.Extra) and stack on the charge: the
	free ones are spent first, so it keeps regaining underneath them.

	  Outpost.Sizes / Outpost.SizeOrder      the rocks
	  Outpost.Picks / Outpost.PickOrder      the pick (the free Survey Pick)
	  Outpost.Refills / Outpost.RefillOrder  the swing refills (Robux:
	                                         each a Shared.Store product)
	  Outpost.legacySwings(picks)            swings for picks a save still
	                                         holds from when picks were sold
	  Outpost.rollSize(roll, zone?)          a new rock's size (a ring's mix), 0 <= roll < 1
	  Outpost.damage(pick, crit)             how many layers a swing chips
	  Outpost.tension(hp, maxHp)             0 (fresh) .. 1 (about to pop): how
	                                         loud and high the hit sound rings
	  Outpost.claimHolder(node, userId, now) may this player hit this rock?
	                                         (its first hitter keeps it a while)
	  Outpost.refillSurvey(swings, since, now) the free pick's swings regained
	                                         since `since` -> swings, since
	  Outpost.surveySwings(picks)            free + bought swings, all you can swing
	  Outpost.spendSurvey(picks, n)          spend n: the free charge first, then
	                                         the bought bank
	  Outpost.Machines / Outpost.MachineOrder   the big machines anyone can drive
	                                         (just for getting around: no tools)
	  Outpost.Secrets / Outpost.SecretOrder  the hidden Easter eggs
	  Outpost.drive(spec, speed, yaw, throttle, steer, dt) -> speed, yaw
	                                         one step of a machine's driving
]]
local Outpost = {}

-- Free healing boulders, round the welcome field first and then out across
-- the quarry, at least Apart studs from each other; no coins or gems.
Outpost.Heal = { Count = 8, Apart = 38, Hp = 5, Swing = 0.07, Pop = 0.25, Kaiju = 0.35, Regrow = 40 }
-- The "Tap to mine" label over the rock in reach: on foot only while you're
-- learning, your first Training stones (profile.Stats.GemsMined); after that
-- the rocks' glow points the way and you mine as in any game: tap or click
-- to swing at the rock in reach, or walk into it. In a mech it always shows.
Outpost.MineButton = { Training = 15 } -- gems mined before the "Click to mine" label goes (it's for learning)
-- Pointing the way to the rocks (Client MineCue): the Max nearest within
-- Glow studs of you (MechGlow in a mech, measured flat) glow with a soft
-- outline, the one in reach brightest, with its label over it: only for
-- your first Training gems, on foot or in a mech (the glow stays).
Outpost.MineCue = { Glow = 42, MechGlow = 70, Max = 6, Every = 0.1 }

-- The original moon quarry, with haul roads and the Shelter in the middle (its garage holds the mechs).
Outpost.Location = CFrame.new(0, 0, 7000)
-- The Shelter stands on landing legs, its floor ShelterLift studs over the
-- quarry's, with ramps ShelterRamp studs long down from its doors (Server
-- OutpostWorld: gentle enough for a mech to climb, Shared.MechPilot). Its
-- frame, Location lifted that far, is where the client mounts its life
-- (Client.ShelterLife, Client.StoreDisplays).
Outpost.ShelterLift = 8
-- Where the Shelter stands, from the quarry's middle (studs, on the floor),
-- and how far it's turned (ShelterTurn, radians). Everything built round
-- it, the Kaiju Arena's hall under it and its life on the client follow
-- (Outpost.shelterFrame). In the settlement it's the Market & Gear, south-
-- east of the mining field (Settlement.Market), turned so its main door
-- faces the Crystal Heart, the garage's bays at its back. (A CFrame's
-- Position: no Vector3 needed to load these rules.)
local MARKET_ANGLE, MARKET_R = math.rad(40), 255
Outpost.ShelterOffset = CFrame.new(math.cos(MARKET_ANGLE) * MARKET_R, 0, math.sin(MARKET_ANGLE) * MARKET_R).Position
-- (its door, its +Z, turned to face the middle)
Outpost.ShelterTurn = math.atan2(-math.cos(MARKET_ANGLE), -math.sin(MARKET_ANGLE))
function Outpost.shelterFrame(): CFrame
	return Outpost.Location * CFrame.new(Outpost.ShelterOffset) * CFrame.Angles(0, Outpost.ShelterTurn, 0)
end

--[[
	The settlement: the crater's middle, walled, safe (Shared.Frontier.Core
	reaches the wall). Studs from the middle, angles in degrees (0 east, 90
	south, 270 north), offsets in the quarry's frame (Outpost.Location).

	  middle      the mining field (Field) round the Crystal Heart (Heart)
	  Ring        the walkway round the field (open onto the Arrival Plaza:
	              RingGap degrees either side of south); Walks wind
	              through the field from it to the plaza
	  north       the pod terraces: Tiers of pads (Pad: each pad's apothem,
	              an octagon), their stairs facing the Heart, a Terrace
	              walkway between the tiers and one down from each pad;
	              no pad within RoadGap degrees of the north road
	  south       the Arrival Plaza (Plaza: an octagon, the shuttle's pad
	              in the middle), the Grand Arena past it (Stages, the ARENA
	              arch at its way in); the Intro Ring south-west of it; the
	              DUNGEON arch by the walkway to the Market
	  south-west  the Kaiju Habitat (the Daycare: Shared.Daycare.Pen)
	  south-east  the Market & Gear: the Shelter (ShelterOffset)
	  Wall        round it all, open at the four spokes (GateWidth studs)

	  Outpost.padSpots() -> { { Offset: Vector3, Angle: number, Tier: number } }
	                     every pad, tier by tier, round from the west
	  Outpost.doorstepSpots() -> { Vector3 }   rocks at the pods' doorsteps
	  Outpost.place(angle, r) -> Vector3       an offset from an angle and a radius
]]
Outpost.Settlement = {
	Wall = 345,
	WallHeight = 7,
	GateWidth = 30,
	Field = 135,
	Heart = 16,
	Ring = 160,
	RingGap = 8,
	Plaza = { X = 0, Z = 200, Apothem = 40 },
	-- Arena Row: open rings on the ground (Server.PrivateArenas builds them:
	-- no walls, the fight's seen and sees out). Intro and practice fights
	-- take one when it's free. The Grand Arena by the plaza, the ARENA arch
	-- at its way in; the Intro Ring south-west.
	-- (in the order fights take them: the Intro Ring first)
	Stages = {
		{ Name = "IntroRing", X = -150, Z = 245 },
		{ Name = "GrandArena", X = 0, Z = 290 },
	},
	StageReach = 36, -- studs: a ring's kerb, lamps and fence, round its middle
	-- (x, z points: from the ring round the Heart to the plaza; one in to the Heart)
	Walks = {
		{ { -131, -92 }, { -78, -36 }, { -66, 56 }, { -26, 124 }, { 0, 164 } },
		{ { 131, -92 }, { 78, -36 }, { 66, 56 }, { 26, 124 }, { 0, 164 } },
		{ { 0, -160 }, { -8, -96 }, { 0, -44 } },
		-- (and from the plaza out to the Kaiju Habitat, the Intro Ring and the
		-- Market's side ramp, past the DUNGEON arch)
		{ { -36, 204 }, { -128, 168 }, { -196, 104 } },
		{ { -36, 212 }, { -95, 204 }, { -150, 196 } },
		{ { 36, 210 }, { 80, 238 }, { 122, 280 } },
	},
	Tiers = {
		{ R = 245, Count = 25, From = 186, To = 354 },
		{ R = 292, Count = 28, From = 189, To = 351 },
	},
	Terrace = 268,
	Pad = 12,
	RoadGap = 6,
	Doorstep = { R = { 196, 206, 214 } }, -- (rocks between the inner pads: Outpost.doorstepSpots)
	Daycare = { Angle = 160, R = 255 },
	Market = { Angle = 40, R = 255 },
	Arena = { Angle = 90, R = 244 }, -- (the Grand Arena's way in, off the plaza)
	Dungeon = { Angle = 74.05, R = 262 }, -- (by the walkway to the Market)
	Enchanter = { Angle = 62, R = 150 },
}
function Outpost.place(angle: number, r: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end
function Outpost.padSpots(): { { Offset: Vector3, Angle: number, Tier: number } }
	local rules = Outpost.Settlement
	local list = {}
	for tier, row in rules.Tiers do
		for i = 0, row.Count - 1 do
			local angle = row.From + i * (row.To - row.From) / (row.Count - 1)
			if math.abs(angle - 270) >= rules.RoadGap then
				table.insert(list, { Offset = Outpost.place(angle, row.R), Angle = angle, Tier = tier })
			end
		end
	end
	return list
end
-- (between the inner pads, where their walkways don't run, a little in
-- and out by turns)
function Outpost.doorstepSpots(): { Vector3 }
	local rules = Outpost.Settlement.Doorstep
	local row = Outpost.Settlement.Tiers[1]
	local step = (row.To - row.From) / (row.Count - 1)
	local list, k = {}, 0
	for i = 0, row.Count - 2 do
		local angle = row.From + (i + 0.5) * step
		if math.abs(angle - 270) >= Outpost.Settlement.RoadGap + 2 then
			for _, r in { rules.R[1 + k % #rules.R], rules.R[1 + (k + 1) % #rules.R] } do
				table.insert(list, Outpost.place(angle, r))
			end
			k += 1
		end
	end
	return list
end
Outpost.ShelterRamp = 40
Outpost.Radius = 550 -- quarry rim; recovery allows the surrounding benches
-- Where the world ends for now: the invisible walls round the quarry
-- (Server OutpostWorld), and the dome over them that says the expansion's
-- coming (Client.EdgeDome).
Outpost.Edge = Outpost.Radius + 34
Outpost.NodeCount = 330 -- room for the expanded quarry's seams, welcome field and Rift Veins
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
-- Blurb are what the refills window says about it.
Outpost.Picks = {
	Survey = {
		Name = "Survey Pick",
		Tag = "FREE",
		Blurb = "Recharges itself while you're away.",
		Swings = 600,
		Power = 1,
		Crit = 0,
		Price = 0,
		Color = Color3.fromRGB(176, 150, 120),
	},
}
Outpost.PickOrder = { "Survey" }

-- The swing refills Garrick sells, for Robux: swings for your pick, on top of its free
-- charge (they go first; it recharges again once it's back under its full
-- charge). Each is a Developer Product, its Product key in Shared.Store
-- (Store.RobuxProducts has the ids).
Outpost.Refills = {
	Refill = {
		Name = "Swing Refill",
		Tag = "REFILL",
		Blurb = "A full charge, on top of yours.",
		Swings = 600,
		Robux = 100,
		Product = "SwingRefill",
		Color = Color3.fromRGB(58, 203, 233),
	},
	Mega = {
		Name = "Mega Refill",
		Tag = "MEGA",
		Blurb = "2,000 swings, 32% cheaper each.",
		Swings = 2000,
		Robux = 225,
		Product = "SwingMega",
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
-- Out in the frontier (Shared.Frontier) every gem rolls luckier (`Luck`,
-- on top of the rock's own; Frontier.Bands has the same): the further out,
-- the richer, a Rift Vein the richest (the guarded one more so). The rock
-- mix stays the same out there (bigger rocks out there only cost more
-- swings for the same gem).
Outpost.Zones = {
	Field = { Name = "Corundum Meadow", Weights = { Pebble = 68, Boulder = 32 } },
	Common = { Name = "Common Field", Weights = { Pebble = 62, Boulder = 38 } },
	Fringe = { Name = "The Fringe", Weights = { Pebble = 62, Boulder = 38 }, Luck = 0.2 },
	Edge = { Name = "The Edge", Weights = { Pebble = 62, Boulder = 38 }, Luck = 0.4 },
	Vein = { Name = "Rift Vein", Weights = { Pebble = 62, Boulder = 38 }, Luck = 0.75 },
	Guarded = { Name = "Guarded Rift Vein", Weights = { Pebble = 62, Boulder = 38 }, Luck = 1.1 },
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

-- Big machines parked in the Shelter's garage. Anyone can hop in and drive; they
-- don't dig or haul, they're for crossing the quarry (and showing off).
-- Speeds in studs a second, Turn in radians a second at full lock.
-- All exosuits can pivot in place. Stable IDs preserve the garage bays.
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

-- The free Survey Pick regains one swing this often, up to its full Swings
-- (600 of them: full again in four hours).
Outpost.FreeSwingSeconds = 24
-- How often it regains one, in words: "24 s" (or "2 min").
function Outpost.rechargeEvery(): string
	local every = Outpost.FreeSwingSeconds
	return if every % 60 == 0 then string.format("%d min", every // 60) else string.format("%d s", every)
end
-- About how many swings a rock takes (the field's mix of chunks and
-- boulders, crits included): what a charge or a refill comes to in rocks.
Outpost.SwingsPerRock = 4.6
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

-- Every swing you hold for the free pick: its charge plus the bought bank.
function Outpost.surveySwings(picks: { [string]: number }): number
	return (picks.Survey or 0) + (picks.Extra or 0)
end

-- Spend `n` swings: the free charge first (so it keeps regaining under the
-- bought ones), then the bought bank.
function Outpost.spendSurvey(picks: { [string]: number }, n: number)
	local free = math.min(picks.Survey or 0, n)
	picks.Survey = (picks.Survey or 0) - free
	picks.Extra = math.max(0, (picks.Extra or 0) - (n - free))
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
