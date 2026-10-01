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
		Cut: 1-10,       -- natural facet quality, rolled at discovery
		CutMethod: "Natural" | "Starter" | "Crate",
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
	EnchantmentXPGranted: boolean?,
	Source: string,
	Found: number,
}

export type Shade = { Tier: string, Name: string, Color: Color3, Color2: Color3?, Prismatic: boolean? }

local GemConfig = {}
-- Retain saved element keys while presenting space-tech affinities everywhere.
GemConfig.ElementLabels = { Fire = "Thermal", Frost = "Cryo", Shock = "Ion", Poison = "Radiation" }
function GemConfig.elementName(element: string): string
	return GemConfig.ElementLabels[element] or element
end

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
	Fire = "Superheats targets, dealing damage over time.",
	Frost = "Chills enemies, slowing them down.",
	Shock = "Arcs to a second nearby enemy.",
	Poison = "Irradiates targets, reducing their damage output.",
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

-- Natural facet quality: 1-10, rolled at recovery. Diamond cut is the only shape.

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
	return state .. GemConfig.shade(gem).Name .. " (" .. GemConfig.elementName(gem.Element) .. ")"
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
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Irradiated" },
	Armor = { Fire = "Heat Shield", Frost = "Cryo Shield", Shock = "Ion Shield", Poison = "Radiation Shield" },
}

-- The numbers behind an enchantment, used by combat:
--   Weapon  Fire: Burn (damage over 3s)   Frost: Slow (fraction, 2s)
--           Shock: Arc (share of each hit to a nearby enemy)
--           Poison: Weaken (enemies deal this much less, 4s)
--   Armor   Resist (fraction less damage from that element)
function GemConfig.enchantValues(gem: Gem, slot: string): { [string]: number }
	slot = if slot == "Weapon" then "Weapon" else "Armor"
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
	slot = if slot == "Weapon" then "Weapon" else "Armor"
	local name = GemConfig.EnchantNames[slot] and GemConfig.EnchantNames[slot][gem.Element] or "Enchanted"
	local v = GemConfig.enchantValues(gem, slot)
	if slot == "Armor" then
		return name,
			string.format(
				"Take %d%% less %s damage",
				math.floor(v.Resist * 100 + 0.5),
				GemConfig.elementName(gem.Element)
			)
	end
	local text = if v.Burn
		then string.format("Hits burn for %d damage over 3s", v.Burn)
		elseif v.Slow then string.format("Hits slow enemies by %d%% for 2s", math.floor(v.Slow * 100 + 0.5))
		elseif v.Arc then string.format("%d%% of each hit arcs to a nearby enemy", math.floor(v.Arc * 100 + 0.5))
		else string.format("Irradiated enemies deal %d%% less damage for 4s", math.floor(v.Weaken * 100 + 0.5))
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
	slot = if slot == "Weapon" then "Weapon" else "Armor"
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
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Irradiated" },
	Armor = {
		Fire = "of Thermal Shielding",
		Frost = "of Cryo Insulation",
		Shock = "of Ion Shielding",
		Poison = "of Radiation Containment",
	},
}

function GemConfig.itemName(baseName: string, gem: Gem?, slot: string): string
	slot = if slot == "Weapon" then "Weapon" else "Armor"
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
