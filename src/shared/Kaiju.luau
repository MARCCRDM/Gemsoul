--[[
	Mini kaiju: knee-high creatures that roam the Outpost, fight beside you,
	and can be tamed. See docs/kaiju.md.

	Three species, each in four elements:
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

-- Your team: one kaiju to start; a second slot opens when one of yours
-- reaches level 10, a third at level 20.
Kaiju.SlotLevels = { 1, 10, 20 }

-- Knocked out in a fight: back in its Gemsoul, ready again after this long.
Kaiju.KnockoutSeconds = 45
Kaiju.RecallSeconds = 4 -- recalled: it stays out of the fight this long
Kaiju.Regen = 0.03 -- share of its health back each second while it isn't fighting

-- Wild kaiju in the Outpost.
Kaiju.Wild = {
	Max = 3, -- out at once
	Respawn = 90, -- seconds after one is killed, tamed or burrows away
	Lifetime = 600, -- one nobody fights burrows back after this long
	Aggro = 26, -- notices fighters this close
	Leash = 70,
	LevelSpread = 2, -- within this many levels of the strongest kaiju near it
}
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

-- Moon bugs: swarms to kite. A little EXP for your kaiju, a few coins.
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
	Swarms = 4, -- swarms out at once
	SwarmSize = { 3, 5 },
	Respawn = 40,
}

-- Feeding: a stone's EXP by its rarity, in full until the kaiju passes
-- FeedFull, then half for ten levels, then a quarter.
Kaiju.FeedExp = { Common = 20, Uncommon = 45, Rare = 100, UltraRare = 220, Legendary = 500 }
Kaiju.FeedFull = { Common = 10, Uncommon = 15, Rare = 20, UltraRare = 25, Legendary = math.huge }
Kaiju.FeedWeak = 0.5 -- a stone of the element that beats it
Kaiju.FeedSame = 1.25 -- a stone of its own element

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

-- A stable display name: "Frost Razorback".
function Kaiju.title(record): string
	local s = Kaiju.Species[record.Species]
	return string.format("%s %s", record.Element or "", s and s.Name or "Kaiju")
end

return Kaiju
