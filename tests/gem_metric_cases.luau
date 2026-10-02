-- Gemstone Metric & Design Directive v3.0: metrics, PvP, affixes, economy and crowd control.
local metricChecks = 0
local function expect(value, message)
	assert(value, message)
	metricChecks += 1
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local function hasLine(lines, text)
	for _, line in lines do
		if string.find(line.Text, text, 1, true) then
			return true
		end
	end
	return false
end

-- The approved tooltip: Size 8 / Clarity 6 / Cut 10 Thermal weapon gem.
local flawless = { Id = "f", Element = "Fire", Tier = "Rare", Size = 8, Clarity = 6, Cut = 10 }
local burn = GemConfig.stats(flawless, "Weapon")
expect(near(burn.BurnDamage, 12) and near(burn.BurnDuration, 2.4) and near(burn.IgniteChance, 0.10), "Thermal numbers")
local burnLines = GemConfig.lines(flawless, "Weapon")
expect(hasLine(burnLines, "+12 Thermal damage per tick"), "Tooltip damage line")
expect(hasLine(burnLines, "Burns for 2.4s"), "Tooltip duration line")
expect(hasLine(burnLines, "10% critical burn chance"), "Tooltip precision line")
expect(GemConfig.title(flawless) == "Flawless Thermal Gem", "Grade title")
expect(GemConfig.potency == nil, "Combat potency must be gone")
for _, line in burnLines do
	expect(not string.find(string.lower(line.Text), "potency", 1, true), "Potency in a combat tooltip")
end

-- Every offensive and defensive formula from the tables.
local g = { Id = "g", Tier = "Common", Size = 10, Clarity = 10, Cut = 10 }
local function stats(element, slot, pvp)
	g.Element = element
	return GemConfig.stats(g, slot, { PvP = pvp })
end
local frost = stats("Frost", "Weapon")
expect(near(frost.SlowAmount, 0.20) and near(frost.SlowDuration, 5) and near(frost.FreezeChance, 0.08), "Cryo offense")
local poison = stats("Poison", "Weapon")
expect(
	near(poison.ArmorShred, 0.15) and near(poison.DebuffDuration, 5) and near(poison.VulnerableChance, 0.05),
	"Corrosive offense"
)
local ion = stats("Shock", "Weapon")
expect(near(ion.ArcDamage, 12) and ion.ChainLength == 5 and near(ion.StunChance, 0.05), "Ion offense")
expect(stats("Fire", "Armor").ShieldAmount == 20 and near(stats("Fire", "Helmet").CooldownCut, 2), "Heat shield")
expect(
	near(stats("Frost", "Boots").ShieldDuration, 10) and near(stats("Frost", "Boots").Resistance, 0.05),
	"Cryo shield"
)
expect(stats("Poison", "Shield").CleanseRate == 10 and near(stats("Poison", "Shield").AuraShred, 0.05), "Rad shield")
expect(
	near(stats("Shock", "Gloves").RechargeRate, 0.20) and near(stats("Shock", "Gloves").DeflectChance, 0.05),
	"Ion shield"
)
g.Clarity = 1
expect(stats("Shock", "Weapon").ChainLength == 1, "Ion always arcs once")
g.Clarity = 10

-- PvP multipliers and caps.
expect(near(stats("Fire", "Weapon", true).BurnDamage, 7.5), "PvP burn x0.5")
expect(near(stats("Fire", "Weapon", true).HealingReduction, 0.30), "Grievous Wounds")
expect(near(stats("Frost", "Weapon", true).SlowAmount, 0.15), "PvP slow x0.75")
expect(near(stats("Frost", "Weapon", true).FreezeChance, 0.048), "PvP freeze x0.6")
expect(stats("Frost", "Weapon", true).FreezeSeconds <= 0.5, "PvP freeze capped at 0.5s")
expect(near(stats("Poison", "Weapon", true).ArmorShred, 0.075), "PvP shred x0.5")
expect(stats("Poison", "Weapon", true).VulnerableAmount <= 0.20, "PvP vulnerability cap")
local ionPvp = stats("Shock", "Weapon", true)
expect(near(ionPvp.ArcDamage, 9.6) and ionPvp.ChainLength == 1 and ionPvp.StunChance == 0, "PvP Ion: no chain, no stun")
expect(ionPvp.ExecuteThreshold > 0, "PvP Ion keeps execute")
expect(hasLine(GemConfig.lines(g, "Weapon", { PvP = true }), "Stun replaced by Execute"), "PvP tooltip tag")

-- Economy: Value = Base Tier Value x (Size x 10 + Clarity x 5 + Cut x 15), scaled.
local ultra = { Id = "u", Element = "Shock", Tier = "UltraRare", Size = 8, Clarity = 6, Cut = 10 }
expect(ExpeditionEconomy.gemPotency(ultra) == 260, "Economy potency")
expect(GemConfig.value(ultra) == math.floor(120 * 260 * ExpeditionEconomy.GemValueScale + 0.5), "Value formula")
local cutHeavy = { Id = "c", Element = "Fire", Tier = "Common", Size = 1, Clarity = 1, Cut = 10 }
local sizeHeavy = { Id = "s", Element = "Fire", Tier = "Common", Size = 10, Clarity = 1, Cut = 1 }
expect(GemConfig.value(cutHeavy) > GemConfig.value(sizeHeavy), "Cut is the most valuable grade")

-- Palette: Thermal red, Cryo blue, Corrosive green, Ion yellow, for every shade.
local function hue(color)
	local r, g2, b = color.R, color.G, color.B
	local max, min = math.max(r, g2, b), math.min(r, g2, b)
	if max == min then
		return 0
	end
	local d = max - min
	local h = if max == r then ((g2 - b) / d) % 6 elseif max == g2 then (b - r) / d + 2 else (r - g2) / d + 4
	return h * 60
end
for element, range in { Fire = { -25, 20 }, Frost = { 190, 240 }, Poison = { 75, 160 }, Shock = { 40, 60 } } do
	for _, shade in GemConfig.Shades[element] do
		local h = hue(shade.Color)
		if h > 300 then
			h -= 360
		end
		expect(h >= range[1] and h <= range[2], element .. " shade off-palette: " .. shade.Name)
	end
	local h = hue(GemConfig.ElementColors[element])
	if h > 300 then
		h -= 360
	end
	expect(h >= range[1] and h <= range[2], element .. " badge off-palette")
end
expect(
	GemConfig.elementName("Poison") == "Corrosive" and GemConfig.elementKey("Corrosive") == "Poison",
	"Corrosive naming"
)

-- Affixes: elemental only, 1/2/3 on Rare/Ultra/Legendary at the right ranges.
expect(#GemConfig.Affixes == 25, "Affix pool size")
for _, affix in GemConfig.Affixes do
	expect(GemConfig.ElementLabels[affix.Element] ~= nil, "Affix without element")
	expect(affix.Stat ~= "Health" and affix.Stat ~= "Power" and affix.Stat ~= "Defense", "Raw-stat affix")
end
local rng = Random.new(77)
local ranges = { [3] = { 0.05, 0.10 }, [4] = { 0.10, 0.15 }, [5] = { 0.15, 0.20 } }
for rarity = 1, 5 do
	for _ = 1, 400 do
		local affixes = ArmorFamilies.rollAffixes(rarity, rng)
		expect(#affixes == ({ 0, 0, 1, 2, 3 })[rarity], "Affix count for rarity " .. rarity)
		local seen = {}
		for _, affix in affixes do
			expect(not seen[affix.Id] and GemConfig.AffixById[affix.Id], "Duplicate or unknown affix")
			seen[affix.Id] = true
			expect(affix.Bonus >= ranges[rarity][1] - 1e-9 and affix.Bonus <= ranges[rarity][2] + 1e-9, "Affix range")
		end
	end
end
for _, entries in ArmorFamilies.Catalog do
	for _, item in entries do
		expect((item.AffixTable ~= nil) == (item.RarityTier >= 3), "AffixTable only on Rare+")
	end
end
local boosted = GemConfig.stats(flawless, "Weapon", { Affinity = { FireOffenseBurnDuration = 0.15 } })
expect(near(boosted.BurnDuration, 2.76) and near(boosted.BurnDamage, 12), "Affinity boosts one stat")
local wrongElement = GemConfig.stats(flawless, "Weapon", { Affinity = { FrostOffenseSlowDuration = 0.2 } })
expect(near(wrongElement.BurnDuration, 2.4), "Affinity of another element leaks")
expect(
	GemConfig.affixText("FrostOffenseFreezeChance", 0.10) == "Cryo Affinity: +10% Freeze Chance",
	"Approved affix tooltip"
)

-- Rolls: new Rare+ armor gets affixes; weapons never; saved rolls backfill once.
local legendary = ArmorFamilies.ById.ArmorJuggernautArmor5
local roll = GearRolls.roll(Random.new(5), legendary.RarityTier, legendary)
expect(#roll.Affixes == 3 and roll.AffixVersion == 1, "Legendary chest affixes")
local weapon = ExpandedTraits.Catalog.Weapons[1]
expect(GearRolls.roll(Random.new(5), 5, weapon).Affixes == nil, "Weapons never roll affixes")
local saved = {
	Owned = { Armors = { ArmorJuggernautArmor4 = 1 } },
	Character = { GearRolls = { Armors = { ArmorJuggernautArmor4 = { Rarity = 4, Stats = {} } } } },
}
for _, kind in Slots.Kinds do
	saved.Owned[kind] = saved.Owned[kind] or {}
end
GearRolls.ensure(saved, Random.new(9))
local backfilled = saved.Character.GearRolls.Armors.ArmorJuggernautArmor4
expect(#backfilled.Affixes == 2, "Saved Ultra Rare roll backfilled")
local first = backfilled.Affixes[1].Id
GearRolls.ensure(saved, Random.new(10))
expect(backfilled.Affixes[1].Id == first, "Backfill rerolled existing affixes")
saved.Character.Armor = "ArmorJuggernautArmor4"
local totals = Classes.affinities(saved.Character)
expect(near(totals[first], backfilled.Affixes[1].Bonus), "Equipped affinities")

-- Diminishing returns: 100% / 50% / 25% / immune inside 10s, reset after.
local tracker = CrowdControl.new()
expect(CrowdControl.ApplyCC(tracker, 1.5, 0, false) == 1.5, "PvE CC untouched")
expect(near(CrowdControl.ApplyCC(tracker, 1.5, 0, true), 0.5), "1st PvP CC capped")
expect(near(CrowdControl.ApplyCC(tracker, 1.5, 2, true), 0.25), "2nd CC 50%")
expect(near(CrowdControl.ApplyCC(tracker, 1.5, 4, true), 0.125), "3rd CC 25%")
expect(CrowdControl.ApplyCC(tracker, 1.5, 6, true) == 0, "4th CC immune")
expect(CrowdControl.ApplyCC(tracker, 1.5, 13, true) == 0, "Still immune within 10s of the last landed CC")
expect(near(CrowdControl.ApplyCC(tracker, 1.5, 14.1, true), 0.5), "DR reset after 10s")

-- Anti-heal: 30% + 20%, capped at 50%, 4 seconds, refreshes without stacking.
CrowdControl.applyHealCut(tracker, "GrievousWounds", 0)
expect(near(CrowdControl.healingMultiplier(tracker, 1), 0.7), "Grievous Wounds 30%")
CrowdControl.applyHealCut(tracker, "MortalStrike", 1)
expect(near(CrowdControl.healingMultiplier(tracker, 2), 0.5), "Combined cap 50%")
CrowdControl.applyHealCut(tracker, "GrievousWounds", 3)
expect(near(CrowdControl.healingMultiplier(tracker, 6), 0.7), "Refresh keeps 4s, Mortal Strike expired")
expect(CrowdControl.healingMultiplier(tracker, 7.5) == 1, "Healing cut expires")

-- PvP debuffs: capped at 30%, strongest source wins.
tracker = CrowdControl.new()
expect(near(CrowdControl.applyDebuff(tracker, "Slow", 0.5, 2, 0, true), 0.30), "PvP debuff cap")
expect(near(CrowdControl.applyDebuff(tracker, "Slow", 0.1, 2, 1, true), 0.30), "PvP debuffs don't stack")
expect(CrowdControl.cleanse(tracker, 1.5) == "Slow" and CrowdControl.debuff(tracker, "Slow", 1.6) == 0, "Cleanse")

print("PASS: " .. metricChecks .. " gem directive checks (metrics, PvP, palette, value, affixes, DR, anti-heal)")
