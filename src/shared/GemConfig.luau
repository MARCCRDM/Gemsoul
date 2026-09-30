--[[
	Gemstone definitions, from "GemSoul: Gemstone Property & Generation
	Architecture". Shared by the server (which generates and grades gems) and
	the client (which displays them).

	A gem is a plain table so it can be saved and sent to clients:
	{
		Id: string,
		Element: "Fire" | "Frost" | "Shock" | "Poison",
		Tier: "Common" | "Uncommon" | "Rare" | "UltraRare",
		Clarity: 1-10,   -- rolled on generation
		Size: 1-10,      -- rolled on generation
		Cut: 1-10?,      -- nil while the stone is still rough
		CutMethod: "Manual" | "AutoCut" | nil,
		Source: "MiningNode" | "MiningStore" | "PvEDrop" | "PvPWager",
		Found: number,   -- os.time() when generated
	}
]]

export type Gem = {
	Id: string,
	Element: string,
	Tier: string,
	Clarity: number,
	Size: number,
	Cut: number?,
	CutMethod: string?,
	Source: string,
	Found: number,
}

export type Shade = { Tier: string, Name: string, Color: Color3, Color2: Color3?, Prismatic: boolean? }

local GemConfig = {}

GemConfig.Elements = { "Fire", "Frost", "Shock", "Poison" }

-- Each element's colour tiers. Fire and Frost top out at Rare; Shock and
-- Poison top out at Ultra-Rare.
GemConfig.Shades = {
	Fire = {
		{ Tier = "Common", Name = "Pale Amber", Color = Color3.fromRGB(255, 196, 110) },
		{ Tier = "Uncommon", Name = "Vibrant Orange", Color = Color3.fromRGB(255, 118, 20) },
		{ Tier = "Rare", Name = "Deep Ruby Red", Color = Color3.fromRGB(176, 8, 40) },
	},
	Frost = {
		{ Tier = "Common", Name = "Quartz Clear", Color = Color3.fromRGB(224, 236, 242) },
		{ Tier = "Uncommon", Name = "Vivid Blue", Color = Color3.fromRGB(40, 140, 255) },
		{ Tier = "Rare", Name = "Deep Royal Sapphire Blue", Color = Color3.fromRGB(18, 40, 160) },
	},
	Shock = {
		{ Tier = "Common", Name = "Smoky Grey", Color = Color3.fromRGB(128, 128, 138) },
		{ Tier = "Uncommon", Name = "Bright Yellow", Color = Color3.fromRGB(255, 228, 40) },
		{
			Tier = "UltraRare",
			Name = "Intense Neon Green / Prismatic",
			Color = Color3.fromRGB(60, 255, 90),
			Prismatic = true,
		},
	},
	Poison = {
		{ Tier = "Common", Name = "Pale Lime", Color = Color3.fromRGB(200, 240, 140) },
		{ Tier = "Uncommon", Name = "Emerald Green", Color = Color3.fromRGB(20, 170, 80) },
		{
			Tier = "UltraRare",
			Name = "Blood Ruby / Deep Emerald Fusion",
			Color = Color3.fromRGB(140, 16, 56),
			Color2 = Color3.fromRGB(0, 110, 60),
		},
	},
} :: { [string]: { Shade } }

-- Relative chance of rolling each colour tier. Luck boosts the rarer tiers.
GemConfig.TierWeights = {
	Common = 70,
	Uncommon = 25,
	Rare = 5,
	UltraRare = 3,
}

GemConfig.TierLabels = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	UltraRare = "Ultra-Rare",
}

-- Badge colours for each element.
GemConfig.ElementColors = {
	Fire = Color3.fromRGB(255, 110, 50),
	Frost = Color3.fromRGB(120, 200, 255),
	Shock = Color3.fromRGB(255, 225, 60),
	Poison = Color3.fromRGB(130, 230, 90),
}

GemConfig.SourceLabels = {
	MiningNode = "Dug from the mine",
	MiningStore = "Bought at the Mining Store",
	PvEDrop = "Dropped by a monster",
	PvPWager = "Won in a PvP duel",
	StarterSpin = "Starter gem spin",
	FirstStone = "Your first stone, from the mine",
}

-- What a gem does when socketed into a weapon.
GemConfig.ElementEffects = {
	Fire = "Burns enemies, dealing damage over time.",
	Frost = "Chills enemies, slowing them down.",
	Shock = "Arcs to a second nearby enemy.",
	Poison = "Weakens enemies so they deal less damage.",
}

GemConfig.TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4 }

GemConfig.TierColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	UltraRare = Color3.fromRGB(255, 90, 220),
}

-- Clarity and size are graded 1-10. High grades are rarer: these are the
-- relative chances of grades 1..10.
GemConfig.GradeWeights = { 16, 16, 14, 12, 11, 9, 8, 6, 5, 3 }

-- How lucky each source is (0 = baseline, 1 = very lucky). Luck raises the
-- odds of rarer colour tiers and gives clarity/size a chance at a reroll.
GemConfig.SourceLuck = {
	MiningNode = 0,
	VipMiningNode = 0.5,
	MiningStore = 0.15,
	PvEDrop = 0.1, -- plus the monster's own bonus
	StarterSpin = 0.25,
	FirstStone = 0,
}

--[[
	Cut grades:
	  1-8  manual cutting minigame, by accuracy
	  9    manual mastery (every strike lands, high accuracy) or mid-tier auto-cut
	  10   "Gem Mint": a flawless manual cut or premium auto-cut
]]
GemConfig.Cutting = {
	Strikes = 3,
	MasteryAccuracy = 0.9, -- average accuracy needed for a 9
	PerfectAccuracy = 0.97, -- every strike at least this accurate for a 10
	-- The target zone shrinks as stones get bigger: bigger gems need more
	-- precision. Width is a fraction of the bar.
	ZoneWidthSmall = 0.3,
	ZoneWidthLarge = 0.12,
	-- Seconds for the marker to cross the bar; bigger stones move faster.
	SweepSecondsSmall = 1.4,
	SweepSecondsLarge = 0.8,
	SessionTimeout = 45,
}

GemConfig.AutoCut = {
	{ Tier = 1, Name = "Laser T1 (Basic)", Price = 40, MinCut = 5, MaxCut = 8 },
	{ Tier = 2, Name = "Laser T2 (Precision)", Price = 150, MinCut = 9, MaxCut = 9 },
	{ Tier = 3, Name = "Laser T3 (Premium)", Price = 400, MinCut = 10, MaxCut = 10 },
}

-- Base value in coins by colour tier, before size, clarity and cut.
GemConfig.TierValue = {
	Common = 10,
	Uncommon = 25,
	Rare = 60,
	UltraRare = 120,
}

function GemConfig.shade(gem: Gem): Shade
	for _, shade in GemConfig.Shades[gem.Element] do
		if shade.Tier == gem.Tier then
			return shade
		end
	end
	return GemConfig.Shades[gem.Element][1]
end

function GemConfig.displayName(gem: Gem): string
	local state = if gem.Cut then "" else "Rough "
	return state .. GemConfig.shade(gem).Name .. " (" .. gem.Element .. ")"
end

-- Target zone width and sweep time for cutting a stone of this size.
function GemConfig.cuttingDifficulty(size: number): (number, number)
	local t = (math.clamp(size, 1, 10) - 1) / 9
	local cutting = GemConfig.Cutting
	local zone = cutting.ZoneWidthSmall + (cutting.ZoneWidthLarge - cutting.ZoneWidthSmall) * t
	local sweep = cutting.SweepSecondsSmall + (cutting.SweepSecondsLarge - cutting.SweepSecondsSmall) * t
	return zone, sweep
end

-- Where the cutting marker is (0-1 across the bar) `t` seconds in. It
-- sweeps back and forth, taking `sweepSeconds` to cross once.
function GemConfig.markerPosition(t: number, sweepSeconds: number): number
	local phase = (t / sweepSeconds) % 2
	return if phase <= 1 then phase else 2 - phase
end

--[[
	How close each cutting strike landed to its target zone. `times` are
	seconds since the cut started. Returns accuracy 0-1 per strike
	(0 = outside the zone, 1 = dead centre). The server uses this to grade
	the cut; the client uses it to show feedback.
]]
function GemConfig.strikeAccuracy(
	times: { number },
	zoneCenters: { number },
	zoneWidth: number,
	sweepSeconds: number
): { number }
	local accuracies = {}
	for i, center in zoneCenters do
		local t = times[i]
		if typeof(t) ~= "number" or t ~= t or t < 0 then
			accuracies[i] = 0
		else
			local distance = math.abs(GemConfig.markerPosition(t, sweepSeconds) - center)
			accuracies[i] = math.max(0, 1 - distance / (zoneWidth / 2))
		end
	end
	return accuracies
end

--[[
	Coin value. Size scales value exponentially (each grade is worth ~45%
	more than the last), clarity scales it linearly, and a cut stone is worth
	far more than a rough one, with a bonus for Gem Mint (10).
]]
function GemConfig.value(gem: Gem): number
	local sizeFactor = 1.45 ^ (gem.Size - 1)
	local clarityFactor = 0.5 + gem.Clarity * 0.1
	local cutFactor = 0.5
	if gem.Cut then
		cutFactor = 0.6 + gem.Cut * 0.12
		if gem.Cut >= 10 then
			cutFactor *= 1.25
		end
	end
	return math.floor(GemConfig.TierValue[gem.Tier] * sizeFactor * clarityFactor * cutFactor + 0.5)
end

-- Enchanting strength a gem lends to gear, driven mostly by size.
function GemConfig.potency(gem: Gem): number
	return gem.Size * 10 + gem.Clarity * 3 + (gem.Cut or 0) * 2
end

-- What a socketed gem does. Weapon gems add their element to your hits;
-- armor gems ward you against that element. Numbers grow with potency.
GemConfig.EnchantNames = {
	Weapon = { Fire = "Burning", Frost = "Frostbite", Shock = "Arcing", Poison = "Venom" },
	Armor = { Fire = "Emberward", Frost = "Frostward", Shock = "Stormward", Poison = "Venomward" },
}

-- The numbers behind an enchantment, used by combat:
--   Weapon  Fire: Burn (damage over 3s)   Frost: Slow (fraction, 2s)
--           Shock: Arc (share of each hit to a nearby enemy)
--           Poison: Weaken (enemies deal this much less, 4s)
--   Armor   Resist (fraction less damage from that element)
function GemConfig.enchantValues(gem: Gem, slot: string): { [string]: number }
	local p = GemConfig.potency(gem)
	if slot == "Armor" then
		return { Resist = math.min(60, 10 + math.floor(p / 4)) / 100 }
	end
	if gem.Element == "Fire" then
		return { Burn = math.floor(p * 0.3 + 0.5) }
	elseif gem.Element == "Frost" then
		return { Slow = math.min(40, 10 + math.floor(p / 6)) / 100 }
	elseif gem.Element == "Shock" then
		return { Arc = math.min(60, 15 + math.floor(p / 4)) / 100 }
	end
	return { Weaken = math.min(25, 5 + math.floor(p / 10)) / 100 }
end

function GemConfig.enchantment(gem: Gem, slot: string): (string, string)
	local name = GemConfig.EnchantNames[slot] and GemConfig.EnchantNames[slot][gem.Element] or "Enchanted"
	local v = GemConfig.enchantValues(gem, slot)
	if slot == "Armor" then
		return name, string.format("Take %d%% less %s damage", math.floor(v.Resist * 100 + 0.5), gem.Element)
	end
	local text = if v.Burn
		then string.format("Hits burn for %d damage over 3s", v.Burn)
		elseif v.Slow then string.format("Hits slow enemies by %d%% for 2s", math.floor(v.Slow * 100 + 0.5))
		elseif v.Arc then string.format("%d%% of each hit arcs to a nearby enemy", math.floor(v.Arc * 100 + 0.5))
		else string.format("Poisoned enemies deal %d%% less damage for 4s", math.floor(v.Weaken * 100 + 0.5))
	return name, text
end

-- Stats a socketed gem adds, by slot and element: { stat, weight }. The
-- bonus is potency x weight / 4, so a big clear well-cut gem adds far more.
GemConfig.EnchantStats = {
	Weapon = {
		Fire = { { "Power", 1 } },
		Frost = { { "Power", 0.5 }, { "Defense", 0.4 } },
		Shock = { { "Speed", 0.7 }, { "Power", 0.4 } },
		Poison = { { "Power", 0.6 }, { "Health", 0.4 } },
	},
	Armor = {
		Fire = { { "Health", 0.6 }, { "Power", 0.4 } },
		Frost = { { "Defense", 1 } },
		Shock = { { "Speed", 0.8 }, { "Defense", 0.2 } },
		Poison = { { "Health", 1 } },
	},
}

function GemConfig.statBonuses(gem: Gem, slot: string): { [string]: number }
	local bonuses = {}
	local p = GemConfig.potency(gem)
	for _, entry in (GemConfig.EnchantStats[slot] or {})[gem.Element] or {} do
		bonuses[entry[1]] = math.floor(p * entry[2] / 4 + 0.5)
	end
	return bonuses
end

-- Enchanted gear takes a name from its gem: "Burning Longsword",
-- "Iron Plate of Embers".
GemConfig.ItemAffixes = {
	Weapon = { Fire = "Burning", Frost = "Frostbitten", Shock = "Thundering", Poison = "Venomous" },
	Armor = { Fire = "of Embers", Frost = "of the Glacier", Shock = "of Storms", Poison = "of the Viper" },
}

function GemConfig.itemName(baseName: string, gem: Gem?, slot: string): string
	if not gem then
		return baseName
	end
	local affix = GemConfig.ItemAffixes[slot] and GemConfig.ItemAffixes[slot][gem.Element]
	if not affix then
		return baseName
	end
	return if slot == "Armor" then baseName .. " " .. affix else affix .. " " .. baseName
end

return GemConfig
