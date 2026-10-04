--[[
	Rolls a mined gem, in order (Ability System v3.0):
	  1. Element   25% each: Thermal (Fire), Cryo (Frost), Corrosive (Poison), Ion (Shock)
	  2. Rarity    40% Common, 25% Uncommon, 20% Rare, 10% Ultra Rare, 5% Legendary
	  3. Tier      the Gem Surge it carries: Novice (1) to Master (4), by rarity
	  4. Surge     the element's surge at that tier; an Apprentice or Adept gem
	               may carry a Resonance surge instead (no element needed)
	  5. Rank      I-III, by rarity
	  6. Metrics   Size, Clarity and Cut, 1-10, in a band set by rarity

	Pure logic (pass in a Random), shared so the client can show the same
	numbers. Saved gems keep their existing keys: `Tier` is the rarity name
	("Common" … "Legendary"); the surge is `Surge` (its id), `SurgeTier` and
	`SurgeRank`.

	Gems saved before surges existed get theirs from a seed of their id, so the
	server and every client agree without a migration (GemRoller.surge).
]]
local GemRoller = {}

GemRoller.Elements = { "Fire", "Frost", "Poison", "Shock" }

GemRoller.Rarities = {
	{ Name = "Common", Weight = 40 },
	{ Name = "Uncommon", Weight = 25 },
	{ Name = "Rare", Weight = 20 },
	{ Name = "UltraRare", Weight = 10 },
	{ Name = "Legendary", Weight = 5 },
}

-- What each rarity can carry: surge tiers, surge ranks and the 1-10 band its
-- metrics roll in (low grades in the band are likelier).
GemRoller.ByRarity = {
	Common = { Tiers = { 1 }, Ranks = { 1 }, Metrics = { 1, 4 } },
	Uncommon = { Tiers = { 1, 2 }, Ranks = { 1, 2 }, Metrics = { 2, 6 } },
	Rare = { Tiers = { 2, 3 }, Ranks = { 2, 3 }, Metrics = { 4, 8 } },
	UltraRare = { Tiers = { 3, 4 }, Ranks = { 3 }, Metrics = { 6, 10 } },
	Legendary = { Tiers = { 4 }, Ranks = { 3 }, Metrics = { 8, 10 } },
}

-- Each element's surge at each tier (ids in CombatTechnology's catalog).
GemRoller.TierNames = { "Novice", "Apprentice", "Adept", "Master" }
GemRoller.Surges = {
	Fire = { "ThermalBurst", "EmberLance", "SolarFlare", "Supernova" },
	Frost = { "CryoLance", "CryoStream", "CryoShield", "AbsoluteZero" },
	Poison = { "AcidSpray", "ArmorMelt", "ToxicCloud", "BioCorrosion" },
	Shock = { "IonSpark", "StaticField", "ChainLightning", "Overload" },
}
-- Resonance surges have no element: an Apprentice or Adept gem of any element
-- carries one instead of its own surge this often.
GemRoller.Resonance = { [2] = "EnergySiphon", [3] = "ResonanceEcho" }
GemRoller.SurgeVariants = {
	Fire = { "CinderDrill", "FurnaceCrescent", "MagmaFault", "SolarExecution" },
	Frost = { "FrostNeedle", "GlacierFan", "PermafrostSpire", "ShatterCrown" },
	Poison = { "CausticDart", "VitriolSweep", "LeechBloom", "Dissolution" },
	Shock = { "ArcNeedle", "CircuitCleave", "ThunderPylon", "Railstorm" },
}
GemRoller.ResonanceVariants = { [2] = "ResonantReaver", [3] = "NullPrism" }
GemRoller.ResonanceChance = 0.12

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- A grade in [low, high], each step up a little less likely than the last.
local function grade(rng, band): number
	local low, high = band[1], band[2]
	local total, weights = 0, {}
	for value = low, high do
		local weight = 1 / (1 + (value - low) * 0.35)
		weights[value] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for value = low, high do
		roll -= weights[value]
		if roll <= 0 then
			return value
		end
	end
	return high
end

-- Rarity weights, nudged toward the rarer end by luck (0 = baseline, 1 = very lucky).
function GemRoller.rarityWeights(luck: number?): { number }
	local weights = {}
	for i, rarity in GemRoller.Rarities do
		weights[i] = rarity.Weight * (1 + (luck or 0) * (i - 1) * 0.75)
	end
	return weights
end

function GemRoller.rollRarity(rng, luck: number?): string
	local weights = GemRoller.rarityWeights(luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for i, weight in weights do
		roll -= weight
		if roll <= 0 then
			return GemRoller.Rarities[i].Name
		end
	end
	return GemRoller.Rarities[#GemRoller.Rarities].Name
end

-- The rolls, as saved gem fields.
function GemRoller.roll(rng, luck: number?)
	local element = pick(rng, GemRoller.Elements)
	local rarity = GemRoller.rollRarity(rng, luck)
	local rules = GemRoller.ByRarity[rarity]
	local tier = pick(rng, rules.Tiers)
	local alternate = rng:NextNumber() < 0.5
	local surge = (if alternate then GemRoller.SurgeVariants else GemRoller.Surges)[element][tier]
	if GemRoller.Resonance[tier] and rng:NextNumber() < GemRoller.ResonanceChance then
		surge = (if alternate then GemRoller.ResonanceVariants else GemRoller.Resonance)[tier]
	end
	return {
		Element = element,
		Tier = rarity,
		Surge = surge,
		SurgeTier = tier,
		SurgeRank = pick(rng, rules.Ranks),
		Size = grade(rng, rules.Metrics),
		Clarity = grade(rng, rules.Metrics),
		Cut = grade(rng, rules.Metrics),
	}
end

-- Gives a rolled gem a different element, with that element's surge at the
-- same tier (a Resonance surge has no element and stays).
function GemRoller.setElement(gem, element: string)
	local oldVariants = GemRoller.SurgeVariants[gem.Element]
	local alternate = oldVariants and oldVariants[gem.SurgeTier] == gem.Surge
	local surges = (if alternate then GemRoller.SurgeVariants else GemRoller.Surges)[element]
	if
		surges
		and gem.SurgeTier
		and gem.Surge ~= GemRoller.Resonance[gem.SurgeTier]
		and gem.Surge ~= GemRoller.ResonanceVariants[gem.SurgeTier]
	then
		gem.Surge = surges[gem.SurgeTier] or gem.Surge
	end
	gem.Element = element
	return gem
end

-- The surge a gem carries: its saved roll, or one seeded from its id.
function GemRoller.surge(gem): (number, number)
	if gem.SurgeTier and gem.SurgeRank then
		return math.clamp(gem.SurgeTier, 1, 4), math.clamp(gem.SurgeRank, 1, 3)
	end
	local rules = GemRoller.ByRarity[gem.Tier] or GemRoller.ByRarity.Common
	local seed = 17
	for i = 1, #(gem.Id or "") do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	local tier = rules.Tiers[seed % #rules.Tiers + 1]
	local rank = rules.Ranks[(seed // 7) % #rules.Ranks + 1]
	return tier, rank
end

return GemRoller
