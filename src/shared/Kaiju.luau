--[[
	Mini kaiju: small creatures that roam the Outpost, fight beside you,
	and can be tamed. See docs/kaiju.md.

	Three species, each in four elements (Fire, Frost, Shock and Poison in
	the data; Thermal, Cryo, Ion and Corrosive on screen):
	  Bulwark    an armoured brute on two legs: slow, heavy blows
	  Razorback  a spined runner: quick, light, fragile
	  Carapace   a low shell on four legs: the hardest to wear down

	Every kaiju carries its Gemsoul: a gem of its element, rolled like any
	gem (rarity, Size, Clarity, Cut), whose only working move is its E
	ability. The kaiju casts it in a fight. A kaiju killed (or lost in the
	arena) leaves its Gemsoul behind as a gem anyone can socket; only its E
	works there too.

	Taming: bring a wild kaiju to half health or less WITHOUT killing it, then
	try your luck (tameChance): the lower its health, the better. Hits on a
	wild kaiju land anywhere from 60% to 140% (Spread), so a big hit can end
	the tame; hit it with its own element (75%, ElementMatchup) to go gently.

	Levels 1-30 from kills and from feeding it stones (feedExp): rarer stones
	keep their worth as it grows, a stone of the element that beats it gives
	half, one of its own element a quarter more.

	Pure data and logic, for the server, the client and tests.
]]
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local GemTraits = require(script.Parent.GemTraits)
local ElementMatchup = require(script.Parent.ElementMatchup)

local Kaiju = {}

Kaiju.Elements = { "Fire", "Frost", "Shock", "Poison" }
Kaiju.Order = { "Bulwark", "Razorback", "Carapace" }

-- Level 1 stats (at a Common Gemsoul). Guard: the share of each blow it shrugs off.
Kaiju.Species = {
	Bulwark = {
		Id = "Bulwark",
		Name = "Bulwark",
		Role = "Brute",
		Blurb = "An armoured brute on two legs. Slow, and every blow lands heavy.",
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
		Role = "Runner",
		Blurb = "A spined runner. Quick light bites, but it can't take a beating.",
		Health = 160,
		Damage = 11,
		Rate = 0.8,
		Speed = 20,
		Reach = 5.5,
		Guard = 0,
	},
	Carapace = {
		Id = "Carapace",
		Name = "Carapace",
		Role = "Shell",
		Blurb = "A low shell on four legs. The hardest of the three to wear down.",
		Health = 300,
		Damage = 13,
		Rate = 1.3,
		Speed = 10,
		Reach = 5.5,
		Guard = 0.25,
	},
}

Kaiju.MaxLevel = 30
Kaiju.Growth = 0.08 -- each level adds this share of the level-1 stats
-- A finer Gemsoul makes a stronger kaiju (and a stronger E).
Kaiju.SoulBonus = { Common = 1, Uncommon = 1.05, Rare = 1.1, UltraRare = 1.15, Legendary = 1.2 }

-- Its E ability: cast every this many seconds in a fight, for this many of
-- its blows (times its Gemsoul's output, GemTraits.Output).
Kaiju.AbilityEvery = 9
Kaiju.AbilityPower = 2.6
-- The E abilities a Gemsoul rolls, by element: the ones you see land (bolts,
-- blasts, storms, waves), never a dash or a "while ready" bonus.
Kaiju.Abilities = {
	Fire = { "E_EmberLance", "E_Supernova", "E_SolarFlare", "E_FlameTornado" },
	Frost = { "E_CryoLance", "E_AbsoluteZero", "E_Hailstorm" },
	Shock = { "E_IonSpark", "E_ChainLightning", "E_ThunderPylon", "E_StormCall", "E_IonCannon" },
	Poison = { "E_AcidSpray", "E_ToxicCloud", "E_ArmorMelt", "E_ToxicTide", "E_Maneater" },
}

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
}

-- How big they stand in the world (KaijuModels are about four studs tall at
-- 1): yours at your knee, a wild one near your height, the vein guardian
-- over you.
Kaiju.Scale = { Pet = 0.55, Wild = 0.9, Guardian = 1.2 }

-- Your kaiju beside you: it takes on creatures within Engage studs of you,
-- runs back past Leash, and is put back beside you past Teleport.
Kaiju.Follow = { Engage = 28, Leash = 45, Teleport = 90, Gap = 5 }

-- Your team: one kaiju to start; a second slot opens when one of yours
-- reaches level 10, a third at level 20.
Kaiju.SlotLevels = { 1, 10, 20 }

-- Knocked out in a fight: back in its Gemsoul, ready again after this long.
Kaiju.KnockoutSeconds = 45
Kaiju.RecallSeconds = 4 -- recalled: it stays out of the fight this long
Kaiju.Regen = 0.03 -- share of its health back each second while it isn't fighting

-- Wild kaiju in the Outpost.
Kaiju.Wild = {
	Max = 4, -- roaming at once (and the guarded Rift Vein's guardian: Shared.Frontier.Guardian)
	Pack = 2, -- of them to a pack, sharing a den out in the frontier
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
-- A hit on a wild kaiju lands anywhere in this range of its usual damage.
Kaiju.Spread = { 0.6, 1.4 }

-- Moon bugs: they come through rifts round players out past the core
-- (Shared.Frontier), to kite and fight. A little EXP for your kaiju, a few
-- coins. Leash: how far from its rift one chases.
Kaiju.Bug = {
	Health = 60,
	Damage = 4,
	Rate = 1.4,
	Speed = 13,
	Reach = 4.5,
	Aggro = 22,
	Exp = 10,
	Coins = 2,
	DailyCoins = 300,
	Scale = 0.55,
	Leash = 120,
	Draw = 30, -- studs: a kaiju out this close draws a critter onto itself (its prey's first)
}

-- Feeding: a stone's EXP by its rarity, in full until the kaiju passes
-- FeedFull, then half for ten levels, then a quarter.
Kaiju.FeedExp = { Common = 20, Uncommon = 45, Rare = 100, UltraRare = 220, Legendary = 500 }
Kaiju.FeedFull = { Common = 10, Uncommon = 15, Rare = 20, UltraRare = 25, Legendary = math.huge }
Kaiju.FeedWeak = 0.5 -- a stone of the element that beats it
Kaiju.FeedSame = 1.25 -- a stone of its own element

-- A starter kaiju for everyone, the first time they reach the Outpost: a
-- random kind, in a random element, with a Gemsoul rolled like a mined gem.
Kaiju.StarterLevel = 1

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

-- EXP from one level to the next.
function Kaiju.expToNext(level: number): number
	if level >= Kaiju.MaxLevel then
		return math.huge
	end
	return math.floor(80 * level ^ 1.5)
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
	return 40 + 12 * math.max(1, level)
end

-- EXP a kaiju gets from eating a stone.
function Kaiju.feedExp(gem, record): number
	if type(gem) ~= "table" or not record then
		return 0
	end
	local base = Kaiju.FeedExp[gem.Tier] or Kaiju.FeedExp.Common
	local full = Kaiju.FeedFull[gem.Tier] or Kaiju.FeedFull.Common
	local level = record.Level or 1
	local falloff = if level <= full then 1 elseif level <= full + 10 then 0.5 else 0.25
	local element = 1
	if gem.Element == ElementMatchup.weakTo(record.Element) then
		element = Kaiju.FeedWeak
	elseif gem.Element == record.Element then
		element = Kaiju.FeedSame
	end
	return math.floor(base * falloff * element)
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

-- A Gemsoul for a kaiju of an element: rolled like any gem, its E ability
-- one of its element's (Kaiju.Abilities). `opts` = { Luck, Id, Time, Species }.
function Kaiju.rollSoul(rng, element: string, opts)
	local rolled = GemRoller.roll(rng, opts.Luck or 0)
	GemRoller.setElement(rolled, element)
	local lane = Kaiju.Abilities[element]
	if lane then
		rolled.Traits.Ability = lane[rng:NextInteger(1, #lane)]
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

-- The damage of a kaiju's E: its blow times AbilityPower, times its
-- Gemsoul's output (rarity, GemTraits.Output) and a little more for a
-- bigger stone (Size), times the move's share (Kaiju.AbilityPlans).
function Kaiju.abilityDamage(damage: number, gem, abilityId: string?): number
	local plan = abilityId and Kaiju.AbilityPlans[abilityId]
	local size = (math.clamp((gem and gem.Size) or 1, 1, 10) - 1) / 9
	return damage * Kaiju.AbilityPower * GemTraits.output(gem) * (1 + 0.2 * size) * (plan and plan.Mult or 1)
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
-- Active = id (the one out), Next = the next id's number, Bugs = { Day, Coins } }.
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
-- or nil if the roster is full. The first one becomes the one out.
function Kaiju.add(roster, speciesId: string, soul, level: number?)
	if Kaiju.count(roster) >= Kaiju.MaxOwned or not Kaiju.Species[speciesId] then
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

-- The kaiju out with you (nil if none).
function Kaiju.active(roster)
	return roster and roster.Active and roster.List[roster.Active] or nil
end

-- A stable display name, with the game's name for its element: "Cryo Razorback".
function Kaiju.title(record): string
	local s = Kaiju.Species[record.Species]
	local element = GemConfig.ElementLabels[record.Element or ""] or record.Element or ""
	return string.format("%s %s", element, s and s.Name or "Kaiju")
end

return Kaiju
