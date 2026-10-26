--[[
	Mini kaiju: small creatures that roam the Outpost, fight beside you,
	and can be tamed. See docs/kaiju.md.

	Four species, each in four elements (Fire, Frost, Shock and Poison in
	the data; Thermal, Cryo, Ion and Corrosive on screen):
	  Bulwark    a warrior: an armoured brute on two legs, slow, heavy blows
	  Razorback  ranged: a spined runner that shoots, quick, light, fragile
	  Carapace   a tank: a low shell on four legs, the hardest to wear down
	  Scythe     an assassin: a lean mantis with blade arms, the quickest
	             blows and the least health
	(Their roles in a battle, and each role's own moves: Shared.KaijuRoles.)
	And the roster's 28 more (Shared.KaijuRoster: Emberjaw, Stormwing,
	Ironhide... each with its own role and moves, two of them new: Breaker
	and Warden). A new player's starter roll is of the first four only
	(Starters); the rest are caught out in the frontier (Habitat, wildKinds).

	Every kaiju carries its enchant (record.Soul, the gem it lives in): born
	with one of its element, rolled like any gem (rarity, Size, Clarity,
	Cut), it gives the kaiju its element, and a finer one makes it stronger
	(SoulBonus). Only a gem of its own element can enchant it (canSocket:
	a Cryo kaiju takes Cryo gems, never Thermal ones); the one it had goes
	back to the pouch. A kaiju fights with its kind's own moves (kitMoves):
	its E from the start, its Q from level 5, its R from level 10
	(MoveLevels). Enchanted with its own element it's attuned (attuned): its
	blows and moves hit Attuned.Power harder (recordStats), and beside them
	it casts its gem surge (recordSurge): its enchant's E, every
	GemSurge.Every seconds, harder the finer the gem. (An enchant of another
	element, from before enchants had to match, still makes it stronger by
	its rarity, with no surge, till you change it.) The enchant's three
	moves (move, moves) are the gem's: a kaiju killed (or lost in the
	arena) leaves its enchant behind as a gem anyone can socket, its Q, E
	and R working in a sword, a chest and a shield (its E the surge the
	kaiju cast). enchanted(record, gem) is how it would stand with another.

	Names: you can name a kaiju (record.Name, cleanName's rules, filtered by
	Roblox on the server); nameOf is its name, or its kind's title
	("Cryo Razorback") when it has none.

	Taming: bring a wild kaiju to half health or less WITHOUT killing it (it
	glows gold when it's ready), then cast your tame (Tame.Cast seconds of
	holding it, struggling, in your gem's light; broken if you're hit or
	stray past Tame.Break) and try your luck (tameChance): the lower its
	health, the better. Hits on a
	wild kaiju land anywhere from 60% to 140% (Spread), so a big hit can end
	the tame; hit it with its own element (75%, ElementMatchup) to go gently.

	Levels 1-30 from fighting: kills, a Rift's boss, kaiju battles (never
	from your mining: your rocks level you, not it). It never heals on its own:
	its health is kept, out and home, until you heal it with gems
	(infusePlan: a gem of its own element worth double, one of the element
	that beats it half), and only out of danger (Danger). Gems never give
	EXP. healPick picks the gems for a heal; AutoHeal, switched on, heals
	your team with your spare Commons by itself, then your spare Uncommons
	once the Commons run out (autoHealPick). One knocked out comes back by
	itself once its revive time is up (Revive, reviveSeconds), weak, to be
	healed with gems; or at once, and stronger, for Robux or a Revive
	coupon. Gems don't revive it.

	Pure data and logic, for the server, the client and tests.
]]
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local GemTraits = require(script.Parent.GemTraits)
local ElementMatchup = require(script.Parent.ElementMatchup)
local KaijuRoles = require(script.Parent.KaijuRoles)
local KaijuRoster = require(script.Parent.KaijuRoster)

local Kaiju = {}

Kaiju.Elements = { "Fire", "Frost", "Shock", "Poison" }
-- The first four: a new player's starter roll is of these (starterPicks).
Kaiju.Starters = { "Bulwark", "Razorback", "Carapace", "Scythe" }
-- Every kind, the first four first, then the roster's (Shared.KaijuRoster).
Kaiju.Order = table.clone(Kaiju.Starters)
for _, id in KaijuRoster.Order do
	table.insert(Kaiju.Order, id)
end

-- Level 1 stats (at a Common Gemsoul). Guard: the share of each blow it shrugs off.
Kaiju.Species = {
	Bulwark = {
		Id = "Bulwark",
		Name = "Bulwark",
		Role = "Warrior", -- (its role in a battle: Shared.KaijuRoles)
		Blurb = "A warrior: an armoured brute on two legs. It fights up close, and every blow lands heavy.",
		Health = 240,
		Damage = 20,
		Rate = 1.6,
		Speed = 12,
		Reach = 6,
		Guard = 0.1,
	},
	Razorback = {
		Id = "Razorback",
		Name = "Razorback",
		Role = "Ranged",
		Blurb = "Ranged: a spined runner that shoots its spines from the back. It can't take a beating.",
		Health = 190,
		Damage = 11,
		Rate = 0.8,
		Speed = 20,
		Reach = 5.5,
		Guard = 0,
	},
	Carapace = {
		Id = "Carapace",
		Name = "Carapace",
		Role = "Tank",
		Blurb = "A tank: a low shell on four legs. It holds the front and takes the hits.",
		Health = 300,
		Damage = 13,
		Rate = 1.3,
		Speed = 10,
		Reach = 5.5,
		Guard = 0.25,
	},
	Scythe = {
		Id = "Scythe",
		Name = "Scythe",
		Role = "Assassin",
		Blurb = "An assassin: a lean mantis with blades for arms. It leaps over the front line onto their ranged kaiju. It can't take a beating.",
		Health = 170,
		Damage = 15,
		Rate = 0.9,
		Speed = 18,
		Reach = 5,
		Guard = 0.05,
	},
}
-- The roster's kinds (each in all four elements, as the first four).
for id, kind in KaijuRoster.Kinds do
	Kaiju.Species[id] = {
		Id = id,
		Name = kind.Name,
		Role = kind.Role,
		Blurb = kind.Blurb,
		Health = kind.Health,
		Damage = kind.Damage,
		Rate = kind.Rate,
		Speed = kind.Speed,
		Reach = kind.Reach,
		Guard = kind.Guard,
		Habitat = kind.Habitat,
		Voice = kind.Voice,
	}
end

-- The wild kinds out in the frontier's `band` ("Fringe" or "Edge"; "Vein":
-- the guarded Rift Vein's guardian): the first four and the roster's of
-- Fringe anywhere out there, the roster's of Edge only at the Edge, the
-- roster's of Vein only as the guardian (Shared.KaijuRoster's Habitat).
-- Curated wild encounters; ownership, starters and existing pets are unaffected.
Kaiju.WildRoster = {
	Emberjaw = true, Stormwing = true, Sickleclaw = true, Mossback = true,
	Hulkshell = true, Drillhorn = true, Triskull = true, Brightsteel = true,
	Dreadcrown = true, Bladebrow = true, Starspine = true,
}
function Kaiju.wildKinds(band: string?): { string }
	local out = {}
	for _, id in Kaiju.Order do
		local habitat = Kaiju.Species[id].Habitat or "Fringe"
		local fits = if band == "Vein"
			then habitat == "Vein"
			else habitat == "Fringe" or (habitat == "Edge" and band == "Edge")
		if fits and Kaiju.WildRoster[id] then
			table.insert(out, id)
		end
	end
	return out
end

Kaiju.MaxLevel = 30
Kaiju.Growth = 0.08 -- each level adds this share of the level-1 stats
-- A finer Gemsoul makes a stronger kaiju (and a stronger E).
Kaiju.SoulBonus = { Common = 1, Uncommon = 1.05, Rare = 1.1, UltraRare = 1.15, Legendary = 1.2 }

-- Its E (its kind's own): cast every this many seconds in a fight
-- (KaijuFighter). AbilityPower: a Gemsoul's E's whole cast, its gem surge,
-- in its blows (times its Gemsoul's output, GemTraits.Output); its kind's
-- own moves carry their own Power (Shared.KaijuRoles).
Kaiju.AbilityEvery = 9
Kaiju.AbilityPower = 2.6
-- Its Gemsoul's three moves wake as it levels: E from the start, Q from
-- level 5, R from level 10.
Kaiju.MoveLevels = { Q = 5, E = 1, R = 10 }
-- Q, its strike: in place of a blow, every this many seconds, for this many
-- of its blows. R, its defense: when it's down to RWhen of its health or a
-- heavy blow (or a cast) is coming its way, at most every REvery seconds.
-- Power: its R's own hits (a ring's burn, an aura's ticks), in its blows.
Kaiju.QEvery = 7
Kaiju.QPower = 1.6
Kaiju.REvery = 14
Kaiju.RWhen = 0.6
Kaiju.RPower = 1
-- Its gem surge (gemSurge, its Gemsoul's E): cast every Every seconds in a
-- fight, the first First seconds in (after its own E has opened),
-- for AbilityPower of its blows (Kaiju.abilityDamage: times its Gemsoul's
-- output, so a Legendary's hits much harder than a Common's). From level 1.
Kaiju.GemSurge = { Every = 14, First = 6 }
-- The moves a Gemsoul rolls, by element and lane (GemTraits.SoulMoves).
-- Abilities: its E's, the ones you see land (bolts, blasts, storms,
-- waves), never a dash or a "while ready" bonus.
Kaiju.Moves = GemTraits.SoulMoves
Kaiju.Abilities = {}
for element, lanes in GemTraits.SoulMoves do
	Kaiju.Abilities[element] = lanes.Ability
end

-- How each E lands when a kaiju casts it (KaijuServer). Shape:
--   Bolt   a shot at its foe          Blast  an area on its foe (after Delay)
--   Nova   an area round itself       Line   a sweep from it through its foe
--   Field  a lasting area on its foe  Chain  a bolt that leaps to Hits foes
--   Storm  Hits bolts on its foe      Pylon  a turret by it, zapping its foe
-- Mult: a share of the E's damage (the whole cast, however many hits).
-- Status: what it leaves (Burn, Slow, Freeze, Stun, Blind, Poison,
-- Vulnerable). Show: the move's own look (MoveVfx), for the big ones.
Kaiju.AbilityPlans = {
	E_EmberLance = { Shape = "Bolt", Mult = 1, Status = "Burn" },
	E_Supernova = { Shape = "Blast", Radius = 10, Delay = 1, Mult = 1.4, Status = "Burn", Show = "Supernova" },
	E_SolarFlare = { Shape = "Nova", Radius = 8, Mult = 0.6, Status = "Blind" },
	E_FlameTornado = { Shape = "Line", Length = 22, Width = 6, Mult = 1.2, Status = "Burn", Show = "FlameTornado" },
	E_CryoLance = { Shape = "Bolt", Mult = 0.9, Status = "Slow" },
	E_AbsoluteZero = { Shape = "Blast", Radius = 10, Delay = 1, Mult = 1, Status = "Freeze", Show = "AbsoluteZero" },
	E_Hailstorm = { Shape = "Field", Radius = 8, Duration = 3, Mult = 1.2, Status = "Slow", Show = "Hailstorm" },
	E_IonSpark = { Shape = "Bolt", Mult = 0.9, Status = "Stun" },
	E_ChainLightning = { Shape = "Chain", Radius = 14, Hits = 4, Mult = 1.2 },
	E_ThunderPylon = { Shape = "Pylon", Radius = 14, Duration = 4, Mult = 1.2 },
	E_StormCall = { Shape = "Storm", Radius = 9, Hits = 5, Mult = 1.4, Status = "Stun", Show = "StormCall" },
	E_IonCannon = { Shape = "Line", Length = 30, Width = 4, Mult = 1.4, Status = "Stun", Show = "IonCannon" },
	E_AcidSpray = { Shape = "Nova", Radius = 7, Mult = 0.8, Status = "Poison" },
	E_ToxicCloud = { Shape = "Field", Radius = 8, Duration = 5, Mult = 1.2, Status = "Poison" },
	E_ArmorMelt = { Shape = "Bolt", Mult = 0.8, Status = "Vulnerable" },
	E_ToxicTide = { Shape = "Line", Length = 24, Width = 8, Mult = 1.2, Status = "Poison", Show = "ToxicTide" },
	E_Maneater = { Shape = "Blast", Radius = 5, Delay = 0.4, Mult = 1.4, Status = "Stun", Show = "Maneater" },

	-- Q, its strike (the same shapes as an E, quicker and closer in).
	Q_FurnaceCrescent = { Shape = "Line", Length = 9, Width = 6, Mult = 1, Status = "Burn" },
	Q_MagmaFault = { Shape = "Line", Length = 16, Width = 4, Mult = 1, Status = "Burn" },
	Q_MeteorLeap = { Shape = "Blast", Radius = 6, Delay = 0.5, Mult = 1.2, Status = "Burn" },
	Q_GlacierFan = { Shape = "Line", Length = 10, Width = 6, Mult = 0.9, Status = "Slow" },
	Q_PermafrostSpire = { Shape = "Blast", Radius = 4, Delay = 0.4, Mult = 1, Status = "Freeze" },
	Q_FrostChakram = { Shape = "Line", Length = 18, Width = 3, Mult = 1, Status = "Slow" },
	Q_CircuitCleave = { Shape = "Chain", Radius = 10, Hits = 3, Mult = 1 },
	Q_ThunderDash = { Shape = "Line", Length = 14, Width = 4, Mult = 1.1, Status = "Stun" },
	Q_Skybreaker = { Shape = "Blast", Radius = 4, Delay = 0.6, Mult = 1.3, Status = "Stun" },
	Q_CausticDart = { Shape = "Bolt", Mult = 0.9, Status = "Poison" },
	Q_VitriolSweep = { Shape = "Line", Length = 9, Width = 6, Mult = 1, Status = "Vulnerable" },
	Q_ToxicFlask = { Shape = "Blast", Radius = 6, Delay = 0.5, Mult = 1, Status = "Poison" },

	-- R, its defense. Shell: soaks Absorb of its health for Duration. Ward:
	-- takes Reduce less for Duration. Mend: heals Heal of its health over
	-- Duration (Cleanse: shakes off burns, poisons, slows and blinds).
	-- Aura: every second, hits foes within Radius with Mult of its R power
	-- (and its Status). Burst: when the shell breaks or runs out, a ring of
	-- Radius round it (Mult, Status). A Nova is a ring at once.
	R_HeatShield = { Shape = "Shell", Absorb = 0.18, Duration = 4, Aura = { Radius = 5, Mult = 0.15, Status = "Burn" } },
	R_Cauterize = { Shape = "Mend", Heal = 0.15, Duration = 3, Cleanse = true },
	R_RingOfFire = { Shape = "Nova", Radius = 7, Mult = 0.8, Status = "Burn" },
	R_IceArmor = { Shape = "Ward", Reduce = 0.25, Duration = 5 },
	R_GlacialBulwark = {
		Shape = "Shell",
		Absorb = 0.22,
		Duration = 5,
		Burst = { Radius = 8, Mult = 0.4, Status = "Slow" },
	},
	R_IcePillar = { Shape = "Shell", Absorb = 1, Duration = 1.5, Burst = { Radius = 8, Mult = 0.3, Status = "Slow" } },
	R_IonShield = { Shape = "Shell", Absorb = 0.15, Duration = 6 },
	R_Capacitor = { Shape = "Shell", Absorb = 0.18, Duration = 4, Recharge = 3 },
	R_TeslaFence = { Shape = "Nova", Radius = 7, Mult = 0.6, Status = "Stun" },
	R_RadShield = { Shape = "Shell", Absorb = 0.18, Duration = 5, Cleanse = true },
	R_BioRegrowth = { Shape = "Mend", Heal = 0.3, Duration = 6 },
	R_ToxicMantle = { Shape = "Ward", Reduce = 0.1, Duration = 5, Aura = { Radius = 5, Mult = 0.2, Status = "Poison" } },
}
-- The roles' own moves (Shared.KaijuRoles: a tank's, a warrior's, a
-- shooter's, an assassin's), cast the same way.
for id, move in KaijuRoles.Moves do
	Kaiju.AbilityPlans[id] = move.Plan
end

-- How big they stand in the world (KaijuModels are about four studs tall at
-- 1): yours at your knee, a wild one near your height, the vein guardian
-- over you.
Kaiju.Scale = { Pet = 0.55, Wild = 0.9, Guardian = 1.2 }
-- How big one stands next to you (1: a player), at a scale: a model is
-- about four studs tall at 1 to your five. Its moves land that big (a pet's
-- blast under half the size of yours: KaijuAbilities), and all it draws is
-- drawn, sounds and shakes your screen that big (the client's FxSize).
Kaiju.Height = 0.8
function Kaiju.size(scale: number): number
	return scale * Kaiju.Height
end

-- Your kaiju beside you: it takes on creatures within Engage studs of you,
-- runs back past Leash, and is put back beside you past Teleport. One in a
-- fight sees it through, though: walk off to mine and it stays on its foe
-- (and on whatever comes at it there) till the foe is down, unless you get
-- Battle studs away (then it gives up and comes back to you).
Kaiju.Follow = { Engage = 28, Leash = 45, Battle = 150, Teleport = 90, Gap = 5 }

-- Jumping after you: when you jump (your root rising faster than Rise studs
-- a second, from under Settle), the team following you jumps too, follow
-- the leader: the one at the head of your line (nearest where you jumped)
-- First seconds after you, then each one behind it Stagger seconds after
-- the one before (in line, so no gap for an empty slot), each Height studs
-- up and not again within Rest. One fighting stays at it and isn't counted.
Kaiju.Hop = { Rise = 24, Settle = 8, First = 0.14, Stagger = 0.26, Height = 6, Rest = 0.6 }

-- Whether you've just jumped: rising fast now from not rising before.
function Kaiju.leapt(before: number?, rise: number): boolean
	return rise >= Kaiju.Hop.Rise and (before == nil or before < Kaiju.Hop.Settle)
end

-- How long after you the one `place`th in your line jumps (1 = the head).
function Kaiju.hopDelay(place: number): number
	return Kaiju.Hop.First + (place - 1) * Kaiju.Hop.Stagger
end

-- Your line for a jump: `distances` (one per kaiju, how far it is from where
-- you jumped) -> the order they go in, nearest first (ties by team slot,
-- `slots`). Returns the indices into `distances` in jumping order.
function Kaiju.hopLine(distances: { number }, slots: { number }?): { number }
	local order = {}
	for i in distances do
		table.insert(order, i)
	end
	table.sort(order, function(a, b)
		if math.abs(distances[a] - distances[b]) > 0.5 then
			return distances[a] < distances[b]
		end
		return (slots and slots[a] or a) < (slots and slots[b] or b)
	end)
	return order
end

-- Fighting as a team (Shared.Squad): your kaiju share out the creatures (each
-- its own while there are enough), flank one they share, and keep Space
-- studs apart (a critter BugSpace from another); a creature after you counts
-- OwnerThreat studs nearer, a swarm's ranged one (it bombs from the back)
-- Bomber studs nearer, and one nearly done for (under a quarter of its
-- health) Finish studs nearer: they dive the bomber and finish one off.
Kaiju.Squad = { Space = 5, BugSpace = 3.5, OwnerThreat = 10, Bomber = 8, Finish = 5 }

-- Your team: the kaiju out with you at once. The beta opens all three
-- slots from the start (the plan: a second when one of yours reaches level
-- 10, a third at 20).
Kaiju.SlotLevels = { 1, 1, 1 }
-- Where each of the team walks with you: studs to your right (left when
-- negative) and behind you (negative: ahead). They lead the way: the first
-- well out in front, the other two side by side behind it, and the
-- fourth, the support's (SupportSlot), in the middle of the three.
Kaiju.TeamSpots = { { 0, -16 }, { 5, -10 }, { -5, -10 }, { 0, -12.5 } }
-- Leading, they read where you're going: on the move (faster than Moving
-- studs a second) they face the way you're heading, not the way you look,
-- and walk where you'll be Seconds from now (no further than Max ahead).
Kaiju.Lead = { Moving = 3, Seconds = 0.8, Max = 14 }

-- Where the one in `slot` walks: you at `position`, looking along `look`,
-- moving at `velocity` (Lead).
function Kaiju.leadSpot(position: Vector3, look: Vector3, velocity: Vector3?, slot: number): Vector3
	local spot = Kaiju.TeamSpots[slot] or Kaiju.TeamSpots[1]
	local lead = Kaiju.Lead
	local moving = if velocity then Vector3.new(velocity.X, 0, velocity.Z) else Vector3.new(0, 0, 0)
	local heading = Vector3.new(look.X, 0, look.Z)
	local ahead = position
	if moving.Magnitude > lead.Moving then
		heading = moving.Unit
		ahead = position + moving.Unit * math.min(moving.Magnitude * lead.Seconds, lead.Max)
	end
	heading = if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 0, -1)
	local right = heading:Cross(Vector3.new(0, 1, 0))
	return ahead + right * spot[1] - heading * spot[2]
end

-- The support slot: a fourth kaiju out beside the three, for a support kind
-- only (KaijuRoles' Warden role, called SUPPORT: Moonmoth, Skyjelly). It
-- floats in the middle of the three, ahead of you, mends you and your team and wards them
-- (KaijuServer's support pulse); a support kind never takes one of the
-- three fighting slots. Everyone gets StarterSupport once (supportOwed):
-- a new player with the starter roll, everyone else on their next visit.
Kaiju.SupportRole = "Warden"
Kaiju.SupportSlot = 4
Kaiju.StarterSupport = { Species = "Skyjelly", Element = "Shock" }
Kaiju.SupportVersion = 1
-- Its pulse: only while you're in a fight (in danger: Kaiju.Danger; out of
-- one it mends nobody, that's for gems), it reads the health of you and
-- every one of the team within Radius studs of it, each and on average,
-- and casts what that calls for (Kaiju.supportChoice), never just because
-- a move is ready:
--   BigMend  one of you under Critical, or the average under LowAverage
--   Mend     one of you under Hurt, two or more under Worn, or the average
--            under Average
--   Ward     with foes about: one of you under WardOne, or the average
--            under WardAverage (someone's taking the hits)
--   Strike   nobody needs it: a foe in StrikeRange of it gets its attack
-- each no sooner than Every[that] seconds after its last (Every stays the
-- Mend's, the rules' old name).
Kaiju.SupportPulse = {
	Every = 6,
	Radius = 24,
	Critical = 0.35,
	LowAverage = 0.5,
	Hurt = 0.55,
	Worn = 0.75,
	Average = 0.75,
	WardOne = 0.8,
	WardAverage = 0.9,
	StrikeRange = 30,
	Gaps = { Mend = 6, BigMend = 18, Ward = 9, Strike = 2.5 },
}

-- What the support casts now (nil: nothing called for). `view`:
--   Healths  { share }  you and the team in its reach, each 0..1
--   Foes     number     foes in its StrikeRange
--   Ready    { Mend?, BigMend?, Ward?, Strike? }  which it has and can cast
function Kaiju.supportChoice(view): string?
	local rules = Kaiju.SupportPulse
	local healths, ready = view.Healths or {}, view.Ready or {}
	local lowest, total, worn = 1, 0, 0
	for _, share in healths do
		lowest = math.min(lowest, share)
		total += share
		if share < rules.Worn then
			worn += 1
		end
	end
	local average = if #healths > 0 then total / #healths else 1
	if (lowest < rules.Critical or average < rules.LowAverage) and ready.BigMend then
		return "BigMend"
	end
	local hurt = lowest < rules.Hurt or worn >= 2 or average < rules.Average
	if hurt and ready.Mend then
		return "Mend"
	end
	local foes = (view.Foes or 0) > 0
	if foes and (lowest < rules.WardOne or average < rules.WardAverage) and ready.Ward then
		return "Ward"
	end
	if foes and not hurt and ready.Strike then
		return "Strike"
	end
	return nil
end

-- Whether a kind is a support kind (it goes in the support slot).
function Kaiju.isSupport(species: string?): boolean
	local s = species and Kaiju.Species[species]
	return s ~= nil and s.Role == Kaiju.SupportRole
end

-- Its health is kept (record.Health) and never comes back on its own.
-- Knocked out in a fight (record.Down), it's back in its Gemsoul, down,
-- until stones revive it (Kaiju.Infuse).
Kaiju.RecallSeconds = 4 -- recalled: it stays out of the fight this long

-- Wild kaiju in the Outpost.
Kaiju.Wild = {
	Max = 12, -- six roaming pairs across the expanded quarry, plus the vein guardian
	Pack = 2, -- of them to a pack, sharing a den out in the frontier
	Apart = 90, -- studs between dens
	-- Claimed patches: most packs den beside an outcrop (Shared.Frontier.Outcrop)
	-- and guard it. Share of new packs that do (the rest roam free); Link:
	-- rocks this many steps apart (Outcrop.Step) are one seam, all of it
	-- theirs; Den studs off the seam's middle; Radius: any other rock this
	-- close to the den is theirs too; Wake: the swing at their rocks they
	-- come for you on (they stir at the first, growl at the next); Luck:
	-- their rocks roll gems this much luckier while they hold the patch.
	Claim = { Share = 0.75, Link = 1.35, Den = { 10, 14 }, Radius = 32, Wake = 3, Luck = 0.08 },
	Defend = 40, -- studs: start on one and its packmate this close joins in
	Respawn = 90, -- seconds after one is killed or tamed
	Return = 20, -- seconds after one burrows away (another comes up elsewhere)
	Lifetime = 600, -- one nobody fights burrows back after about this long (each its own: 70% to 150%)
	Aggro = 26, -- notices fighters this close
	Leash = 70,
	LevelSpread = 2, -- within this many levels of the strongest kaiju near it
	Health = 1.5, -- tougher than a kaiju of yours at its level: it takes two to bring down
	FarFromSpawn = 140, -- studs: they roam the quarry, not the landing pad
}

-- A wild kaiju's day, when nobody's fighting it: it wanders round its
-- pack's den (Range studs), stopping to sniff the ground, look about, lie
-- down or roar now and then (Moods: how likely each is next, Times: how
-- long, in seconds), ambling at Amble of its speed. Every Every seconds the
-- den moves on Drift studs, so a pack wanders the quarry over time. Someone
-- coming within Notice studs makes it stop and look at them (a roar at most
-- every Growl seconds). The guardian keeps to a short beat in front of its
-- vein, napping now and then (Guard).
Kaiju.Roam = {
	Range = 34,
	Amble = 0.45,
	Drift = { 20, 30 },
	Every = { 60, 120 },
	Notice = 22,
	Growl = 25,
	Moods = { Walk = 45, Sniff = 20, Look = 15, Rest = 12, Roar = 8 },
	Times = { Walk = { 6, 12 }, Sniff = { 2.5, 5 }, Look = { 2, 4 }, Rest = { 8, 16 }, Roar = { 1.6, 1.6 } },
	-- Your kaiju, with you standing about After seconds: it potters round
	-- you (Range studs), and is up and after you as soon as you move on.
	Pet = {
		After = 3,
		Range = 6,
		Moods = { Walk = 30, Sniff = 25, Look = 25, Rest = 20 },
		Times = { Walk = { 3, 6 }, Sniff = { 2.5, 5 }, Look = { 2, 4 }, Rest = { 6, 14 } },
	},
	Guard = {
		Range = 16,
		Moods = { Walk = 45, Look = 20, Sniff = 10, Sleep = 25 },
		Times = { Walk = { 5, 9 }, Look = { 2, 4 }, Sniff = { 2.5, 5 }, Sleep = { 8, 16 } },
	},
}

-- The next mood from `moods` (weights by name) for `roll` (0..1): names in
-- order, so the same roll always gives the same mood.
function Kaiju.mood(moods: { [string]: number }, roll: number): string
	local names, total = {}, 0
	for name, weight in moods do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local at = math.clamp(roll, 0, 0.999999) * total
	for _, name in names do
		at -= moods[name]
		if at < 0 then
			return name
		end
	end
	return names[#names]
end
-- Taming. Below TameFrom of its health you can try; the chance climbs as it
-- weakens (points between are a straight line). TameTries failed tries and it
-- burrows away. Each try is a TameCooldown apart.
Kaiju.TameFrom = 0.5
Kaiju.TameCurve = {
	{ 0.5, 0.05 },
	{ 0.3, 0.15 },
	{ 0.15, 0.35 },
	{ 0.05, 0.6 },
	{ 0, 0.8 },
}
Kaiju.TameTries = 3
Kaiju.TameCooldown = 2
-- The tame is a cast: Cast seconds holding it in your gem's light (it's held
-- still, struggling, and nothing can hurt it meanwhile); it breaks if you're
-- hit or stray past Break studs. Range: how close you start it from. The
-- roll comes at its end.
Kaiju.Tame = { Cast = 2.5, Range = 30, Break = 38 }
-- A hit on a wild kaiju lands anywhere in this range of its usual damage.
Kaiju.Spread = { 0.6, 1.4 }

-- Moon bugs: they come through rifts round players out past the core
-- (Shared.Frontier), to kite and fight. They come in swarms, three to six
-- at a time and more when it's stirred up, so each one alone is weak: a
-- small bite, little health. A little EXP for your kaiju, a coin. Leash:
-- how far from its rift one chases.
Kaiju.Bug = {
	Health = 30,
	Damage = 1.6,
	Rate = 1.4,
	Speed = 13,
	Reach = 4.5,
	Aggro = 22,
	Exp = 4,
	Coins = 1,
	DailyCoins = 300,
	Scale = 0.55,
	Size = 0.55, -- next to you (its rig is your size at scale 1: Kaiju.size)
	Leash = 120,
	Draw = 30, -- studs: a kaiju out this close draws a critter onto itself (its prey's first)
	-- In a fight (KaijuWilds): a bite comes after BiteWindup, then it hops
	-- HopBack studs out and circles Recover seconds before it comes in again;
	-- a blow it sees coming (a kaiju on it winding one up) it hops clear of,
	-- by chance (Dodge, or its kind's own), at most once every DodgeEvery
	-- seconds, untouchable for DodgeFor.
	BiteWindup = 0.3,
	HopBack = 5,
	Recover = 0.7,
	Dodge = 0.3,
	DodgeEvery = 2.5,
	DodgeFor = 0.45,
	-- A swarm pounces together: once at least Rush.Min of its fighters are
	-- on one foe, every Rush.Every seconds (a range) they all leap in at
	-- once from up to Rush.Leap studs out, within Rush.Window seconds,
	-- whether they'd got their breath back or not.
	Rush = { Min = 3, Every = { 4, 7 }, Window = 0.6, Leap = 8 },
	-- Below Skittish of its health one turns wary: it circles wider, takes
	-- Wary times as long to come back in, and hops clear more (WaryDodge
	-- more of a chance).
	Skittish = 0.35,
	Wary = 1.8,
	WaryDodge = 0.25,
	-- On its own on a foe that's facing it, it works round toward its
	-- back, up to Flank radians a step.
	Flank = math.rad(40),
}

-- Each critter's own move (KaijuWilds), after a wind-up named on its cast
-- bar, every Every seconds once its foe is within Range (and past Min):
--   Slam    a blow brought down: Radius round its feet, Heavy breaks a guard
--   Dash    straight through its foe, up to Length, hitting within Width
--   Burst   a cloud round it (Radius) that lingers (Linger seconds)
--   Bombs   Count bombs lobbed round its foe (within Spread), each landing
--           after Flight where its foe was: keep moving
-- Mult: a share of its bite. Status: what it leaves. Dodge: its own chance
-- to hop clear. Ranged: it never bites; it keeps Keep studs off, lobbing
-- (Lob: a bomb every Every seconds, the same way), and one closing in past
-- Flee it jets back from (every FleeEvery seconds at most). It never comes
-- alone, and comes through last (Kaiju.wave).
Kaiju.BugMoves = {
	Sahur = {
		Name = "Bat Slam",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 0.9,
		Radius = 6,
		Mult = 2.2,
		Heavy = true,
		Status = "Burn",
		Every = 7,
		Range = 5,
	},
	Tralalero = {
		Name = "Shark Dash",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.5,
		Length = 16,
		Width = 3.5,
		Mult = 1.8,
		Status = "Slow",
		Every = 6,
		Min = 4,
		Range = 16,
		Dodge = 0.55,
	},
	Patapim = {
		Name = "Spore Burst",
		Shape = "Burst",
		Pose = "Nova",
		Windup = 0.8,
		Radius = 7,
		Mult = 1.3,
		Status = "Poison",
		Linger = 3,
		Every = 8,
		Range = 6,
	},
	Crocodilo = {
		Name = "Carpet Bomb",
		Shape = "Bombs",
		Pose = "Bolt",
		Windup = 0.7,
		Count = 3,
		Spread = 5,
		Radius = 3.5,
		Flight = 0.6,
		Mult = 1.2,
		Status = "Stun",
		Every = 9,
		Range = 24,
		Ranged = true,
		Keep = 14,
		Flee = 8,
		FleeEvery = 2,
		Lob = { Every = 2.2, Windup = 0.45, Flight = 0.55, Radius = 3, Mult = 1 },
	},
	-- The Rift's bosses (Shared.RiftRun, DungeonRules.Bosses): the same
	-- three kinds of move, each its own, at a boss's size.
	Gattini = {
		Name = "Twin Pounce",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.6,
		Length = 26,
		Width = 7,
		Mult = 2,
		Status = "Stun",
		Every = 6,
		Min = 6,
		Range = 26,
		Dodge = 0.4,
	},
	Drago = {
		Name = "Firebomb Dive",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 1,
		Radius = 13,
		Mult = 2.4,
		Heavy = true,
		Status = "Burn",
		Every = 7,
		Range = 10,
	},
	Paperotti = {
		Name = "Quack Squall",
		Shape = "Burst",
		Pose = "Nova",
		Windup = 0.9,
		Radius = 14,
		Mult = 1.5,
		Status = "Slow",
		Linger = 3,
		Every = 8,
		Range = 12,
	},
	Ranocchio = {
		Name = "Bog Leap",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 0.9,
		Radius = 12,
		Mult = 2.2,
		Heavy = true,
		Status = "Poison",
		Every = 7,
		Range = 10,
	},
	Chimpanzini = {
		Name = "Banana Smash",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 0.9,
		Radius = 12,
		Mult = 2.3,
		Heavy = true,
		Status = "Stun",
		Every = 7,
		Range = 10,
	},
	SahurTrio = {
		Name = "Triple Bat Slam",
		Shape = "Slam",
		Pose = "Heavy",
		Windup = 1,
		Radius = 13,
		Mult = 2.5,
		Heavy = true,
		Status = "Burn",
		Every = 7,
		Range = 10,
	},
	TralaleroTwin = {
		Name = "Twin Shark Dash",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.6,
		Length = 28,
		Width = 7,
		Mult = 2,
		Status = "Slow",
		Every = 6,
		Min = 6,
		Range = 28,
		Dodge = 0.4,
	},
	PatapimTrio = {
		Name = "Spore Storm",
		Shape = "Burst",
		Pose = "Nova",
		Windup = 0.9,
		Radius = 15,
		Mult = 1.5,
		Status = "Poison",
		Linger = 4,
		Every = 8,
		Range = 12,
	},
	Frigo = {
		Name = "Freezer Blast",
		Shape = "Burst",
		Pose = "Nova",
		Windup = 0.9,
		Radius = 14,
		Mult = 1.6,
		Status = "Slow",
		Linger = 3,
		Every = 8,
		Range = 12,
	},
	Cappuccino = {
		Name = "Knife Flurry",
		Shape = "Dash",
		Pose = "Lunge",
		Windup = 0.5,
		Length = 24,
		Width = 6,
		Mult = 2.1,
		Status = "Burn",
		Every = 5,
		Min = 6,
		Range = 24,
		Dodge = 0.5,
	},
}
-- The critters, as DungeonRules.Roster has them.
Kaiju.Critters = { "Sahur", "Tralalero", "Patapim", "Crocodilo" }
-- A swarm's make-up (Kaiju.wave): one of at least Ranged.Min critters has
-- a ranged one at its back (Ranged.Chance of the time), one more for every
-- Ranged.Every.
Kaiju.Swarm = { Ranged = { Min = 3, Every = 5, Chance = 0.7 } }

-- Whether critter `id` fights from range (never alone, and last).
function Kaiju.isRanged(id: string?): boolean
	local move = Kaiju.BugMoves[id or ""]
	return move ~= nil and move.Ranged == true
end

-- What comes through for an encounter of `count` (a list of critter ids,
-- in the order they come): the fighters first, any ranged ones last (and
-- never on their own). `rng` has NextInteger and NextNumber. `home` (a
-- critter id: the kind a biome's own, Shared.Frontier) leans it: a fighter
-- is `home` `bias` of the time; a ranged `home` comes along more often
-- (whenever there are two or more, about `bias` / 2 of them).
function Kaiju.wave(count: number, rng, home: string?, bias: number?): { string }
	local melee, ranged = {}, {}
	for _, id in Kaiju.Critters do
		table.insert(if Kaiju.isRanged(id) then ranged else melee, id)
	end
	local rules = Kaiju.Swarm.Ranged
	local shots = 0
	local homeRanged = home ~= nil and table.find(ranged, home) ~= nil
	local homeMelee = home ~= nil and table.find(melee, home) ~= nil
	if homeRanged then
		if count >= 2 then
			shots = math.max(1, math.floor(count * (bias or 0) / 2 + 0.5))
		end
	elseif #ranged > 0 and count >= rules.Min and rng:NextNumber() < rules.Chance then
		shots = math.max(1, math.floor(count / rules.Every))
	end
	local others = {}
	for _, id in melee do
		if id ~= home then
			table.insert(others, id)
		end
	end
	local wave = {}
	for _ = 1, count - shots do
		if homeMelee and rng:NextNumber() < (bias or 0) then
			table.insert(wave, home :: string)
		elseif homeMelee then
			table.insert(wave, others[rng:NextInteger(1, #others)])
		else
			table.insert(wave, melee[rng:NextInteger(1, #melee)])
		end
	end
	for _ = 1, shots do
		table.insert(wave, if homeRanged then home :: string else ranged[rng:NextInteger(1, #ranged)])
	end
	return wave
end

-- Healing (KaijuServer's "KaijuInfuse"): gems from your pouch heal a
-- kaiju, never EXP. A gem's power by its rarity (Power), Same times for
-- one of the kaiju's own element, Weak times for one of the element that
-- beats it; each point of power heals Mend of its health. Common and
-- Uncommon power is doubled at level one, divided by 1 + .05*(level-1)
-- as the kaiju grows. Higher rarities retain their full power.
-- Batch: gems it takes in one go.
-- One knocked out takes none (Revive).
Kaiju.Infuse = {
	Power = { Common = 1, Uncommon = 2, Rare = 4, UltraRare = 8, Legendary = 16 },
	Same = 2,
	Weak = 0.5,
	Mend = 0.075,
	LowTierBoost = 2,
	LowTierLevelDecay = 0.05,
	Batch = 25,
}

-- Knocked out: back by itself once Base seconds, and PerLevel more a level,
-- have gone by (record.DownUntil, the server's clock: it counts while
-- you're away), but weak, at Health of its health: heal it with gems
-- before it fights again. Or at once, at Bought of its health: Robux (the
-- "KaijuRevive" product, Shared.Store: every one of yours that's down) or
-- a Revive coupon (Shared.Coupons).
Kaiju.Revive = { Base = 60, PerLevel = 8, Health = 0.15, Bought = 0.5 }

-- How long one knocked out at its level stays down.
function Kaiju.reviveSeconds(record): number
	local revive = Kaiju.Revive
	return revive.Base + revive.PerLevel * math.max(1, record and record.Level or 1)
end

-- Seconds until one knocked out is back by itself (0: up, or due now).
function Kaiju.reviveIn(record, now: number): number
	if not record or not record.Down then
		return 0
	end
	local untilTime = tonumber(record.DownUntil)
	if not untilTime then
		return 0 -- (down before revive times: due now)
	end
	return math.max(0, untilTime - now)
end

-- Healing with gems waits until you're out of danger (KaijuServer): none of
-- your team out has fought for Calm seconds, and no creature they'd fight
-- is within Radius of you. The support mends only while you're in it.
Kaiju.Danger = { Calm = 4, Radius = 45 }

-- The starter roll: everyone starts with a team of StarterTeam kaiju,
-- rolled in the intro: each a random kind in a random element, with a
-- Gemsoul rolled like a mined gem, never the same kind and element twice (or
-- as one already yours); the ones rolled become your team. A player who
-- took an older roll (RollVersion: one that only topped up kaiju from
-- before) is owed one full roll of StarterTeam, once, in the Outpost. A
-- roll left unclaimed is given anyway after RollGrace seconds there.
Kaiju.StarterLevel = 1
Kaiju.StarterTeam = 3
Kaiju.RollVersion = 2
Kaiju.RollGrace = 90

-- The 1v1 kaiju arena (phase 2): every match is for keeps.
Kaiju.Arena = {
	MinLevel = 5, -- a kaiju fights there from this level
	LevelGap = 3, -- only against kaiju within this many levels
	RematchHours = 6, -- the same two players can't stake again this soon
}

function Kaiju.species(id: string?)
	return id and Kaiju.Species[id] or nil
end

-- Its stats at a level, with its Gemsoul's rarity.
function Kaiju.stats(speciesId: string, level: number, rarity: string?)
	local s = Kaiju.Species[speciesId]
	if not s then
		return nil
	end
	level = math.clamp(math.floor(level or 1), 1, Kaiju.MaxLevel)
	local grow = (1 + Kaiju.Growth * (level - 1)) * (Kaiju.SoulBonus[rarity or "Common"] or 1)
	return {
		Health = math.floor(s.Health * grow + 0.5),
		Damage = math.floor(s.Damage * grow * 10 + 0.5) / 10,
		Rate = s.Rate,
		Speed = s.Speed,
		Reach = s.Reach,
		Guard = s.Guard,
	}
end

-- EXP from one level to the next: a steep climb (a level is earned over
-- a session or two of fighting, not a few minutes).
Kaiju.ExpCurve = { Base = 110, Power = 1.65 }
function Kaiju.expToNext(level: number): number
	if level >= Kaiju.MaxLevel then
		return math.huge
	end
	return math.floor(Kaiju.ExpCurve.Base * level ^ Kaiju.ExpCurve.Power)
end

-- Adds EXP to a kaiju record ({ Level, Exp }); returns the levels gained.
function Kaiju.addExp(record, amount: number): number
	if amount <= 0 or record.Level >= Kaiju.MaxLevel then
		return 0
	end
	record.Exp = (record.Exp or 0) + math.floor(amount)
	local gained = 0
	while record.Level < Kaiju.MaxLevel and record.Exp >= Kaiju.expToNext(record.Level) do
		record.Exp -= Kaiju.expToNext(record.Level)
		record.Level += 1
		gained += 1
	end
	if record.Level >= Kaiju.MaxLevel then
		record.Exp = 0
	end
	return gained
end

-- EXP for killing a wild kaiju of a level (a moon bug: Kaiju.Bug.Exp).
function Kaiju.killExp(level: number): number
	return 26 + 8 * math.max(1, level)
end

-- Its health: { now, most } (record.Health is kept; never hurt, it's
-- full; knocked out, none).
function Kaiju.health(record): (number, number)
	local stats = record and Kaiju.recordStats(record)
	local most = if stats then stats.Health else 1
	if not record or record.Down then
		return 0, most
	end
	return math.clamp(tonumber(record.Health) or most, 0, most), most
end

-- A stone's power infused into a kaiju (Kaiju.Infuse).
function Kaiju.infusePower(gem, record): number
	if type(gem) ~= "table" or not record then
		return 0
	end
	local infuse = Kaiju.Infuse
	local power = infuse.Power[gem.Tier] or infuse.Power.Common
	if gem.Tier == "Common" or gem.Tier == "Uncommon" then
		local level = math.max(1, tonumber(record.Level) or 1)
		power *= infuse.LowTierBoost / (1 + (level - 1) * infuse.LowTierLevelDecay)
	end
	if gem.Element == record.Element then
		power *= infuse.Same
	elseif gem.Element == ElementMatchup.weakTo(record.Element) then
		power *= infuse.Weak
	end
	return power
end

-- What healing a kaiju with `gems` (in the order given) does: only the
-- gems it needs are used, until it's full. One knocked out takes none.
-- { Used = { gem }, Power, Health, Most }.
function Kaiju.infusePlan(record, gems: { any })
	local health, most = Kaiju.health(record)
	local mend = most * Kaiju.Infuse.Mend
	local plan = { Used = {}, Power = 0, Health = health, Most = most }
	if not record or record.Down then
		return plan
	end
	for i = 1, #gems do
		if health >= most then
			break
		end
		local power = Kaiju.infusePower(gems[i], record)
		table.insert(plan.Used, gems[i])
		plan.Power += power
		health += power * mend
	end
	plan.Health = math.min(most, health)
	return plan
end

-- Auto heal (KaijuServer's "KaijuAutoHeal", the HUD's AUTO HEAL): on, your
-- spare gems of Tiers heal your team by themselves, once you're out of
-- danger (Danger): your Commons first, and your Uncommons only once the
-- Commons have run out (autoHealPick). Never a rarer gem, never one a saved
-- loadout names, never a Gemsoul. At most one round every Every seconds,
-- and never a gem that would go to waste (healPick). It doesn't revive
-- (Revive). On by default; an explicit preference is kept in the roster
-- (AutoHeal).
Kaiju.AutoHeal = { Tiers = { "Common", "Uncommon" }, Every = 1.5, Default = true }

function Kaiju.autoHealOn(roster): boolean
	if roster and roster.AutoHeal ~= nil then
		return roster.AutoHeal == true
	end
	return Kaiju.AutoHeal.Default
end

-- Called back (roster.Away): the team is put away in its Gemsouls, none of
-- it out, till you deploy it again; and it deploys only out of danger
-- (Kaiju.Danger).
function Kaiju.away(roster): boolean
	return roster ~= nil and roster.Away == true
end

-- The gems to heal a kaiju with, out of `gems`: the strongest first (its
-- own element), never a Gemsoul, at most Infuse.Batch; with `toFull`, on
-- until it's full (the last may give more than it needs), else only gems
-- that fit (none wasted). None for one knocked out.
function Kaiju.healPick(record, gems: { any }, toFull: boolean?): { any }
	local list = {}
	for _, gem in gems do
		if type(gem) == "table" and not Kaiju.isSoul(gem) then
			table.insert(list, gem)
		end
	end
	table.sort(list, function(a, b)
		local pa, pb = Kaiju.infusePower(a, record), Kaiju.infusePower(b, record)
		if pa ~= pb then
			return pa > pb
		end
		return tostring(a.Id) < tostring(b.Id)
	end)
	local chosen = {}
	if not record or record.Down then
		return chosen
	end
	local health, most = Kaiju.health(record)
	local mend = most * Kaiju.Infuse.Mend
	for i = 1, #list do
		if health >= most - 1e-6 or #chosen >= Kaiju.Infuse.Batch then
			break
		end
		local gain = Kaiju.infusePower(list[i], record) * mend
		if toFull or health + gain <= most + 1e-6 then
			table.insert(chosen, list[i])
			health += gain
		end
	end
	return chosen
end

-- The gems auto heal takes to mend a kaiju, out of `pools` (your spare
-- gems by tier, { Common = {...}, Uncommon = {...} }): from the first of
-- AutoHeal.Tiers, and from the next only once every gem of the one before
-- is used, so an Uncommon goes only when the Commons are gone. None wasted
-- (healPick), at most Infuse.Batch, none for one knocked out.
function Kaiju.autoHealPick(record, pools: { [string]: { any } }): { any }
	local chosen = {}
	if not record or record.Down then
		return chosen
	end
	local health, most = Kaiju.health(record)
	local probe = table.clone(record)
	for _, tier in Kaiju.AutoHeal.Tiers do
		local pool = {}
		for _, gem in pools[tier] or {} do
			if type(gem) == "table" and not Kaiju.isSoul(gem) then
				table.insert(pool, gem)
			end
		end
		probe.Health = health
		local picked = Kaiju.healPick(probe, pool, false)
		for _, gem in picked do
			if #chosen >= Kaiju.Infuse.Batch then
				return chosen
			end
			table.insert(chosen, gem)
			health += Kaiju.infusePower(gem, record) * most * Kaiju.Infuse.Mend
		end
		if #picked < #pool then
			break -- (some of these are left: none of the next yet)
		end
	end
	return chosen
end

-- The chance a tame works with the wild kaiju at this health.
function Kaiju.tameChance(health: number, maxHealth: number): number
	if health <= 0 or maxHealth <= 0 then
		return 0
	end
	local share = health / maxHealth
	if share > Kaiju.TameFrom then
		return 0
	end
	local curve = Kaiju.TameCurve
	for i = 1, #curve - 1 do
		local hi, lo = curve[i], curve[i + 1]
		if share <= hi[1] and share >= lo[1] then
			local t = (hi[1] - share) / (hi[1] - lo[1])
			return hi[2] + (lo[2] - hi[2]) * t
		end
	end
	return curve[#curve][2]
end

-- A hit's spread on a wild kaiju (a Random, or math.random).
function Kaiju.spread(rng): number
	local roll = if rng then rng:NextNumber() else math.random()
	return Kaiju.Spread[1] + (Kaiju.Spread[2] - Kaiju.Spread[1]) * roll
end

-- How many kaiju a player can have out, from their best kaiju's level.
function Kaiju.slots(roster): number
	local best = 0
	for _, record in (roster and roster.List) or {} do
		best = math.max(best, record.Level or 1)
	end
	local count = 1
	for i, level in Kaiju.SlotLevels do
		if best >= level then
			count = i
		end
	end
	return count
end

-- Gemsouls --------------------------------------------------------------------------------------

function Kaiju.isSoul(gem): boolean
	return type(gem) == "table" and type(gem.Soul) == "table" and gem.Soul.Kind == "Kaiju"
end

-- A Gemsoul for a kaiju of an element: rolled like any gem, its three
-- moves its element's that a kaiju can cast (Kaiju.Moves). `opts` = { Luck,
-- Id, Time, Species }.
function Kaiju.rollSoul(rng, element: string, opts)
	local rolled = GemRoller.roll(rng, opts.Luck or 0)
	GemRoller.setElement(rolled, element)
	local lanes = Kaiju.Moves[element]
	if lanes then
		rolled.Traits = rolled.Traits or {}
		-- (E first, as before, so a seed rolls the same E.)
		for _, lane in { "Ability", "Offense", "Defense" } do
			rolled.Traits[lane] = lanes[lane][rng:NextInteger(1, #lanes[lane])]
		end
	end
	return {
		Id = opts.Id,
		Element = element,
		Tier = rolled.Tier,
		Surge = rolled.Surge,
		Traits = rolled.Traits,
		SurgeTier = rolled.SurgeTier,
		SurgeRank = rolled.SurgeRank,
		Size = rolled.Size,
		Clarity = rolled.Clarity,
		Cut = rolled.Cut,
		CutMethod = "Natural",
		Source = "Kaiju",
		Found = opts.Time,
		Soul = { Kind = "Kaiju", Species = opts.Species },
	}
end

-- The damage of a kaiju's move: its blow times its key's power (an E's
-- AbilityPower, a Q's QPower, an R's RPower), times its Gemsoul's output
-- (rarity, GemTraits.Output) and a little more for a bigger stone (Size),
-- times the move's share (Kaiju.AbilityPlans).
function Kaiju.abilityDamage(damage: number, gem, abilityId: string?): number
	local plan = abilityId and Kaiju.AbilityPlans[abilityId]
	local size = (math.clamp((gem and gem.Size) or 1, 1, 10) - 1) / 9
	local key = abilityId and string.sub(abilityId, 1, 2)
	local power = if plan and plan.Power
		then plan.Power
		elseif key == "Q_" then Kaiju.QPower
		elseif key == "R_" then Kaiju.RPower
		else Kaiju.AbilityPower
	return damage * power * GemTraits.output(gem) * (1 + 0.2 * size) * (plan and plan.Mult or 1)
end

-- A wild kaiju's level: near the strongest kaiju out with the players
-- around (`levels`), within Wild.LevelSpread; level 1 to 3 with none.
function Kaiju.wildLevel(levels: { number }, rng): number
	local best = 0
	for _, level in levels do
		best = math.max(best, level)
	end
	local spread = Kaiju.Wild.LevelSpread
	local roll = if rng then rng:NextInteger(-spread, spread) else math.random(-spread, spread)
	if best <= 0 then
		return math.clamp(2 + roll, 1, 3)
	end
	return math.clamp(best + roll, 1, Kaiju.MaxLevel)
end

-- The damage a kaiju takes from a blow of `element`: its own element 75%,
-- its weakness 125% (ElementMatchup), less its kind's Guard.
function Kaiju.taken(speciesId: string, kaijuElement: string?, element: string?): (number, string?)
	local mult, tag = ElementMatchup.versus(element, kaijuElement)
	local s = Kaiju.Species[speciesId]
	return mult * (1 - (s and s.Guard or 0)), tag
end

-- Daily coin cap for moon bugs: coins still to earn today.
function Kaiju.bugCoins(record, day: number): number
	if not record or record.Day ~= day then
		return Kaiju.Bug.DailyCoins
	end
	return math.max(0, Kaiju.Bug.DailyCoins - (record.Coins or 0))
end

-- The E ability its Gemsoul carries.
function Kaiju.ability(gem): string?
	return Kaiju.isSoul(gem) and GemTraits.traitFor(gem, "E") or nil
end

-- Its gem surge: its Gemsoul's E, cast beside its own moves (GemSurge). A
-- Gemsoul it was born with is always its kaiju's element (rollSoul), so the
-- surge is too. (A kaiju's own, with any gem socketed: recordSurge.)
function Kaiju.gemSurge(gem): string?
	local id = Kaiju.ability(gem)
	return if id and Kaiju.AbilityPlans[id] then id else nil
end

-- Attuned: a kaiju's Gemsoul of its own element. Its blows and its own
-- moves hit Power times harder, and it casts its gem surge.
Kaiju.Attuned = { Power = 1.15 }

function Kaiju.attuned(record): boolean
	local soul = record and record.Soul
	return type(soul) == "table" and soul.Element ~= nil and soul.Element == record.Element
end

-- Its stats as it stands: its kind's at its level, by its Gemsoul's rarity,
-- its damage Attuned.Power more when attuned.
function Kaiju.recordStats(record)
	if not record then
		return nil
	end
	local stats = Kaiju.stats(record.Species, record.Level, record.Soul and record.Soul.Tier)
	if stats and Kaiju.attuned(record) then
		stats.Damage = math.floor(stats.Damage * Kaiju.Attuned.Power * 10 + 0.5) / 10
	end
	return stats
end

-- Its gem surge, attuned only: its Gemsoul's E, or, a mined gem's E being
-- one a kaiju can't cast (a dash, a "while ready" bonus), its element's
-- first (Kaiju.Abilities).
function Kaiju.recordSurge(record): string?
	if not Kaiju.attuned(record) then
		return nil
	end
	local id = GemTraits.traitFor(record.Soul, "E")
	if id and Kaiju.AbilityPlans[id] then
		return id
	end
	for _, ability in Kaiju.Abilities[record.Element] or {} do
		if Kaiju.AbilityPlans[ability] then
			return ability
		end
	end
	return nil
end

-- Whether `gem` (a gem from the pouch) can enchant `record`, and why not:
-- only a gem of its own element (any rarity).
function Kaiju.canSocket(record, gem): (boolean, string?)
	if not record then
		return false, "That kaiju isn't yours."
	end
	if type(gem) ~= "table" or type(gem.Element) ~= "string" or type(gem.Tier) ~= "string" then
		return false, "That gem isn't in your pouch."
	end
	if record.Soul and record.Soul.Id ~= nil and record.Soul.Id == gem.Id then
		return false, "That's its enchant already."
	end
	if gem.Element ~= record.Element then
		local own = GemConfig.ElementLabels[record.Element or ""] or tostring(record.Element)
		local a = Kaiju.article(own)
		return false, string.format("Only %s %s gem can enchant %s %s kaiju.", a, own, a, own)
	end
	return true
end

-- "a" or "an" before a word ("an Ion gem").
function Kaiju.article(word: string): string
	return if string.find(word, "^[AEIOUaeiou]") then "an" else "a"
end

-- How `record` would stand enchanted with `gem`: { Stats, Surge, Tier,
-- Attuned } (recordStats and recordSurge of it with that gem in).
function Kaiju.enchanted(record, gem)
	if not record then
		return nil
	end
	local trial = table.clone(record)
	trial.Soul = gem
	return {
		Stats = Kaiju.recordStats(trial),
		Surge = Kaiju.recordSurge(trial),
		Tier = gem and gem.Tier or "Common",
		Attuned = Kaiju.attuned(trial),
	}
end

-- The move its Gemsoul gives `key` (Q, E or R), and whether a kaiju of
-- `level` has it awake yet (MoveLevels).
function Kaiju.move(gem, key: string, level: number?): (string?, boolean)
	local id = if Kaiju.isSoul(gem) then GemTraits.traitFor(gem, key) else nil
	return id, id ~= nil and (level or 1) >= (Kaiju.MoveLevels[key] or math.huge)
end

-- A move's name, description and icon: a role's own (Shared.KaijuRoles)
-- or a gem's (GemTraits.Moves).
function Kaiju.moveInfo(id: string?)
	if not id then
		return nil
	end
	return KaijuRoles.Moves[id] or GemTraits.Moves[id]
end

-- A kaiju's own moves: its role's (Shared.KaijuRoles: a tank's, a
-- warrior's, a shooter's, an assassin's), E from the start, Q from level 5,
-- R from level 10. (Its Gemsoul's moves, Kaiju.move, are the gem's: for
-- whoever sockets it.)
function Kaiju.kitMove(speciesId: string?, key: string, level: number?): (string?, boolean)
	return KaijuRoles.move(speciesId, key, level)
end

-- Its own moves awake at `level`: { Q, E, R } (nil while asleep).
function Kaiju.kitMoves(speciesId: string?, level: number?): { [string]: string }
	local out = {}
	for _, key in { "Q", "E", "R" } do
		local id, awake = KaijuRoles.move(speciesId, key, level)
		if awake then
			out[key] = id
		end
	end
	return out
end

-- Its role (Shared.KaijuRoles.Roles: Name, Blurb).
function Kaiju.role(speciesId: string?)
	return KaijuRoles.Roles[KaijuRoles.of(speciesId)]
end

-- Its moves awake at `level`: { Q, E, R } (nil while asleep).
function Kaiju.moves(gem, level: number?): { [string]: string }
	local out = {}
	for _, key in { "Q", "E", "R" } do
		local id, awake = Kaiju.move(gem, key, level)
		if awake then
			out[key] = id
		end
	end
	return out
end

-- A new kaiju record.
function Kaiju.new(id: string, speciesId: string, soul, level: number?)
	return {
		Id = id,
		Species = speciesId,
		Element = soul.Element,
		Level = math.clamp(level or 1, 1, Kaiju.MaxLevel),
		Exp = 0,
		Soul = soul,
	}
end

-- The kaiju you own --------------------------------------------------------------------------

Kaiju.MaxOwned = 12 -- kaiju one player can keep

-- A profile's roster, made if it has none: { List = { [id] = record },
-- Team = { id } (the ones out, Kaiju.teamIds), Active = id (its lead), Next =
-- the next id's number, Bugs = { Day, Coins } }.
function Kaiju.roster(profile)
	local roster = profile.Kaiju
	if type(roster) ~= "table" then
		roster = { List = {}, Next = 1 }
		profile.Kaiju = roster
	end
	roster.List = roster.List or {}
	roster.Next = roster.Next or 1
	return roster
end

function Kaiju.count(roster): number
	local n = 0
	for _ in (roster and roster.List) or {} do
		n += 1
	end
	return n
end

-- Adds a kaiju (given its kind, Gemsoul and level) and returns its record,
-- or nil if the roster is full (`over`: one past full, for the starter
-- support). The first one becomes the one out.
function Kaiju.add(roster, speciesId: string, soul, level: number?, over: boolean?)
	if Kaiju.count(roster) >= Kaiju.MaxOwned + (if over then 1 else 0) or not Kaiju.Species[speciesId] then
		return nil
	end
	local id = "k" .. roster.Next
	roster.Next += 1
	local record = Kaiju.new(id, speciesId, soul, level)
	roster.List[id] = record
	if not roster.Active or not roster.List[roster.Active] then
		roster.Active = id
	end
	return record
end

-- The number in a kaiju's id ("k12" -> 12), for "oldest first".
local function idNumber(id: string): number
	return tonumber(string.match(id, "%d+")) or 0
end

-- Your team out, as ids in order (the first is its lead): kaiju you own,
-- each once, as many as your slots, the ones you put out (roster.Team, else
-- the one out from before) first; empty slots fill with your best others
-- (on their feet, highest level, then oldest). One of the team knocked out
-- keeps its place (it's down, not out) until you revive or replace it.
function Kaiju.teamIds(roster): { string }
	local out, seen = {}, {}
	if not roster or type(roster.List) ~= "table" then
		return out
	end
	local slots = Kaiju.slots(roster)
	local function take(id)
		if
			#out < slots
			and type(id) == "string"
			and roster.List[id]
			and not seen[id]
			and not Kaiju.isSupport(roster.List[id].Species) -- (its own slot: supportId)
		then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for _, id in (if type(roster.Team) == "table" then roster.Team else {}) do
		take(id)
	end
	take(roster.Active)
	local rest = {}
	for id in roster.List do
		if not seen[id] then
			table.insert(rest, id)
		end
	end
	table.sort(rest, function(a, b)
		local ra, rb = roster.List[a], roster.List[b]
		if (ra.Down == true) ~= (rb.Down == true) then
			return not ra.Down -- (one knocked out fills a place last)
		end
		if (ra.Level or 1) ~= (rb.Level or 1) then
			return (ra.Level or 1) > (rb.Level or 1)
		end
		return idNumber(a) < idNumber(b)
	end)
	for _, id in rest do
		take(id)
	end
	return out
end

-- Your team out, as records in order.
function Kaiju.team(roster): { any }
	local out = {}
	for _, id in Kaiju.teamIds(roster) do
		table.insert(out, roster.List[id])
	end
	return out
end

-- Puts `ids` out (as Kaiju.teamIds tidies them); the first leads.
function Kaiju.setTeam(roster, ids: { string })
	roster.Team = ids
	roster.Team = Kaiju.teamIds(roster)
	roster.Active = roster.Team[1]
end

function Kaiju.inTeam(roster, id: string): boolean
	return table.find(Kaiju.teamIds(roster), id) ~= nil
end

-- The kaiju leading your team (nil if none).
function Kaiju.active(roster)
	local id = Kaiju.teamIds(roster)[1]
	return if id then roster.List[id] else nil
end

-- Your support out (an id, nil if you own no support kind): the one you
-- put there (roster.Support), else your best (on its feet, highest level,
-- then oldest). One knocked out keeps the slot, down, like the team's.
function Kaiju.supportId(roster): string?
	if not roster or type(roster.List) ~= "table" then
		return nil
	end
	local chosen = roster.Support
	if type(chosen) == "string" and roster.List[chosen] and Kaiju.isSupport(roster.List[chosen].Species) then
		return chosen
	end
	local best, bestRecord = nil, nil
	for id, record in roster.List do
		if Kaiju.isSupport(record.Species) then
			local better = best == nil
			if not better then
				if (record.Down == true) ~= (bestRecord.Down == true) then
					better = not record.Down
				elseif (record.Level or 1) ~= (bestRecord.Level or 1) then
					better = (record.Level or 1) > (bestRecord.Level or 1)
				else
					better = idNumber(id) < idNumber(best)
				end
			end
			if better then
				best, bestRecord = id, record
			end
		end
	end
	return best
end

-- Everyone out: the team in order, then the support (in SupportSlot).
-- Returns the ids and, for each, its slot.
function Kaiju.squadIds(roster): ({ string }, { [string]: number })
	local ids, slots = Kaiju.teamIds(roster), {}
	for slot, id in ids do
		slots[id] = slot
	end
	local support = Kaiju.supportId(roster)
	if support then
		table.insert(ids, support)
		slots[support] = Kaiju.SupportSlot
	end
	return ids, slots
end

-- Puts `id` (a support kind of yours) in the support slot. False if it isn't one.
function Kaiju.setSupport(roster, id: string): boolean
	local record = roster and roster.List and roster.List[id]
	if not record or not Kaiju.isSupport(record.Species) then
		return false
	end
	roster.Support = id
	return true
end

-- Whether a profile is still owed the starter support (StarterSupport,
-- once per SupportVersion): not before its starter roll is taken (that
-- gives it), and not to one who already has that kind.
function Kaiju.supportOwed(profile): boolean
	if not profile or profile.KaijuSupport == Kaiju.SupportVersion or Kaiju.rollsOwed(profile) > 0 then
		return false
	end
	for _, record in (profile.Kaiju and profile.Kaiju.List) or {} do
		if record.Species == Kaiju.StarterSupport.Species then
			return false
		end
	end
	return true
end

-- How many starter kaiju a profile still has to roll: a full StarterTeam
-- until it's taken this version's roll (RollVersion), as many as it has
-- room for.
function Kaiju.rollsOwed(profile): number
	if not profile or profile.KaijuRolled == Kaiju.RollVersion then
		return 0
	end
	return math.max(0, math.min(Kaiju.StarterTeam, Kaiju.MaxOwned - Kaiju.count(profile.Kaiju)))
end

-- Kinds (of the first four, Starters) and elements for `count` starter
-- rolls: none the same as another or as one of `taken` (records already
-- owned).
function Kaiju.starterPicks(rng, count: number, taken: { any }?): { { Species: string, Element: string } }
	local used = {}
	for _, record in taken or {} do
		used[tostring(record.Species) .. tostring(record.Element)] = true
	end
	local out = {}
	for _ = 1, count do
		local species, element
		for _ = 1, 30 do
			species = Kaiju.Starters[rng:NextInteger(1, #Kaiju.Starters)]
			element = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
			if not used[species .. element] then
				break
			end
		end
		used[species .. element] = true
		table.insert(out, { Species = species, Element = element })
	end
	return out
end

-- A stable display name, with the game's name for its element: "Cryo Razorback".
function Kaiju.title(record): string
	local s = Kaiju.Species[record.Species]
	local element = GemConfig.ElementLabels[record.Element or ""] or record.Element or ""
	return string.format("%s %s", element, s and s.Name or "Kaiju")
end

-- Names ---------------------------------------------------------------------------------------------

-- A kaiju's name: up to NameMax letters (accented ones too), numbers,
-- spaces, - ' and ., with a letter in it. One rename every NameEvery
-- seconds (each goes through Roblox's filter).
Kaiju.NameMax = 16
Kaiju.NameEvery = 2

-- `text` tidied into a name (its spaces trimmed and single), and why not
-- if it can't be one. "" (or only spaces) is no name: back to its title.
function Kaiju.cleanName(text: any): (string?, string?)
	if type(text) ~= "string" then
		return nil, "That isn't a name."
	end
	local name = string.gsub(string.gsub(text, "%s+", " "), "^ ", "")
	name = string.gsub(name, " $", "")
	if name == "" then
		return "", nil
	end
	-- (Accented letters, á or ñ, count as letters: UTF-8's Latin-1 ones.)
	local plain = string.gsub(name, "\195[\128-\191]", "a")
	if string.find(plain, "[^%w '%-%.]") then
		return nil, "Letters, numbers, spaces, - ' and . only."
	end
	if #plain > Kaiju.NameMax then
		return nil, string.format("Up to %d letters.", Kaiju.NameMax)
	end
	if not string.find(plain, "%a") then
		return nil, "Put a letter in it."
	end
	return name, nil
end

-- What to call it: its name, or its kind's title ("Cryo Razorback").
function Kaiju.nameOf(record): string
	if not record then
		return "Kaiju"
	end
	local name = record.Name
	if type(name) == "string" and name ~= "" then
		return name
	end
	return Kaiju.title(record)
end

return Kaiju
