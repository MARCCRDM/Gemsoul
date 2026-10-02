-- Armor defines the build. IDs remain stable; old items stay saved-compatible.
local Armor = {}
Armor.Version = 1
Armor.FullSetPieces = 6 -- five armor pieces plus a matching weapon
Armor.Slots = { "Helmet", "Armor", "Gloves", "Boots", "Shield" }
Armor.Order = { "Prospector", "Skirmisher", "Juggernaut" }
Armor.Budgets = { 10, 15, 22, 30, 40 }
Armor.ModifierSlots = { 0, 0, 1, 2, 3 }
Armor.Weights = { 40, 25, 20, 10, 5 }
Armor.Costs = { Health = 1, Power = 1, Defense = 1, Speed = 2, Critical = 2, Cooldown = 2 }
Armor.Values = { Health = 5, Power = 1, Defense = 1, Speed = 0.5, Critical = 0.005, Cooldown = 0.005 }
Armor.Stats = { "Health", "Power", "Defense", "Speed", "Critical", "Cooldown" }
Armor.Enhancements = {
	Prospector = { BasicDamage = 1.10, Knockback = 1.15, DodgeCooldown = 0.85, BlockWidth = 1.20 },
	Skirmisher = { AttackSpeed = 1.15, HeavyCrit = 0.20, DodgeDistance = 1.25, Deflect = true },
	Juggernaut = {
		Stagger = 0.10,
		HeavyDamage = 1.25,
		DodgeDistance = 0.80,
		Invincible = 0.75,
		BlockReduction = 0.65,
		BlockPvPReduction = 0.50,
	},
}
Armor.EnhancementText = {
	Prospector = "2+ pieces: Attack +10% damage; Heavy +15% knockback; Dodge -15% cooldown; Block +20% width.",
	Skirmisher = "2+ pieces: Attack +15% speed; Heavy +20% critical chance; Dodge +25% distance; Block deflects light projectiles.",
	Juggernaut = "2+ pieces: Attack +10% stagger chance; Heavy +25% damage; Dodge 12 studs / 0.75s PvE immunity; Block 65% PvE / 50% PvP reduction.",
}
Armor.Families = {
	Prospector = {
		Look = "UtilityMiner",
		Description = "Balanced sustain and self-sufficient mining",
		Primary = { Helmet = "Health", Armor = "Health", Gloves = "Power", Boots = "Speed", Shield = "Defense" },
		PreferredWeapon = "Sword",
		Gem = "Corrosive",
		Color = Color3.fromRGB(218, 159, 76),
	},
	Skirmisher = {
		Look = "FrontierRanger",
		Description = "Mobile scout with critical burst",
		Primary = { Helmet = "Speed", Armor = "Power", Gloves = "Critical", Boots = "Speed", Shield = "Defense" },
		PreferredWeapon = "Pistol",
		Gem = "Ion",
		Color = Color3.fromRGB(72, 174, 186),
	},
	Juggernaut = {
		Look = "HeavyVanguard",
		Description = "Armored defense and battlefield control",
		Primary = { Helmet = "Health", Armor = "Health", Gloves = "Power", Boots = "Health", Shield = "Defense" },
		PreferredWeapon = "Sword",
		Gem = "Thermal",
		Color = Color3.fromRGB(104, 139, 189),
	},
}
-- Highest unlocked tier replaces lower tiers; bonuses are not added together.
Armor.Sets = {
	Prospector = {
		[2] = { Health = 10, Power = 1 },
		[4] = { Health = 20, Power = 2, Cooldown = 0.05 },
		[6] = { Health = 30, Power = 3, Cooldown = 0.10, HealingReceived = 0.05 },
	},
	Skirmisher = {
		[2] = { Speed = 0.5, Critical = 0.02 },
		[4] = { Speed = 1, Critical = 0.04, Cooldown = 0.05 },
		[6] = { Speed = 1.5, Critical = 0.08, Cooldown = 0.10, DamageAfterDodge = 0.10 },
	},
	Juggernaut = {
		[2] = { Health = 15, Defense = 1 },
		[4] = { Health = 25, Defense = 2, DamageReduction = 0.05 },
		[6] = { Health = 40, Defense = 4, DamageReduction = 0.10, ThreatGeneration = 0.15 },
	},
}
Armor.DepthWeights = {
	{ 80, 20, 0, 0, 0 },
	{ 50, 40, 10, 0, 0 },
	{ 20, 50, 25, 5, 0 },
	{ 0, 30, 50, 18, 2 },
	{ 0, 10, 40, 40, 10 },
}
Armor.Catalog, Armor.ById = {}, {}
local kinds = { Helmet = "Helmets", Armor = "Armors", Gloves = "Gloves", Boots = "Boots", Shield = "Shields" }
local suffixes = { Helmet = "Helm", Armor = "Rig", Gloves = "Grips", Boots = "Greaves", Shield = "Shield" }
local common = {
	Prospector = {
		"Zero-G Standard Helm",
		"Zero-G Bulk Suit",
		"Reinforced Grips",
		"Mag-Lock Greaves",
		"Titanium Breach Shield",
	},
	Skirmisher = {
		"Frontier Scout Helm",
		"Frontier Scout Rig",
		"Scout Trigger Grips",
		"Scout Striders",
		"Scout Deflector Shield",
	},
	Juggernaut = {
		"Vanguard Guard Helm",
		"Vanguard Guard Rig",
		"Guard Gauntlets",
		"Guard Sabatons",
		"Guard Bulwark Shield",
	},
}
local prefixes = {
	Prospector = { "", "Reinforced Miner", "Surveyor's", "Prospector Elite", "Prospector Prime" },
	Skirmisher = { "", "Recon", "Pathfinder's", "Skirmisher Elite", "Skirmisher Prime" },
	Juggernaut = { "", "Reinforced Vanguard", "Bastion's", "Juggernaut Elite", "Juggernaut Prime" },
}
for familyIndex, family in Armor.Order do
	for slotIndex, slot in Armor.Slots do
		local kind = kinds[slot]
		Armor.Catalog[kind] = Armor.Catalog[kind] or {}
		for rarity = 1, 5 do
			local id = "Armor" .. family .. slot .. rarity
			local item = {
				Id = id,
				Name = if rarity == 1
					then common[family][slotIndex]
					else prefixes[family][rarity] .. " " .. suffixes[slot],
				Tier = rarity,
				RarityTier = rarity,
				StartPool = true,
				ArmorFamily = family,
				AssetFamily = Armor.Families[family].Look,
				Look = Armor.Families[family].Look,
				Style = family,
				Mods = {},
				Budget = Armor.Budgets[rarity],
				PrimaryStat = Armor.Families[family].Primary[slot],
				ModifierSlots = Armor.ModifierSlots[rarity],
				HelmetDesign = (familyIndex - 1) * 5 + rarity,
				Description = Armor.Families[family].Description,
				Passive = {
					Name = "Armor Identity",
					Text = "Wear matching " .. family .. " pieces for set bonuses.",
					Effect = {},
				},
			}
			Armor.ById[id] = item
			table.insert(Armor.Catalog[kind], item)
		end
	end
end
function Armor.rollStats(item, rng)
	local slots = item.ModifierSlots
	local modifierBudget = if slots == 0 then 0 elseif slots == 1 then 6 elseif slots == 2 then 8 else 12
	local primaryBudget = item.Budget - modifierBudget
	local cost = Armor.Costs[item.PrimaryStat]
	-- Odd speed/critical budgets spend the remaining point on Power.
	local points = math.floor(primaryBudget / cost)
	local stats = { [item.PrimaryStat] = points * Armor.Values[item.PrimaryStat] }
	local allocations = { [item.PrimaryStat] = points }
	if primaryBudget % cost > 0 then
		stats.Power = (stats.Power or 0) + 1
		allocations.Power = (allocations.Power or 0) + 1
	end
	local available = {}
	for _, stat in Armor.Stats do
		if stat ~= item.PrimaryStat and not allocations[stat] then
			table.insert(available, stat)
		end
	end
	local modifiers = {}
	for _ = 1, slots do
		local stat = table.remove(available, rng:NextInteger(1, #available))
		local spent = modifierBudget / slots
		local amount = spent / Armor.Costs[stat]
		stats[stat] = (stats[stat] or 0) + amount * Armor.Values[stat]
		allocations[stat] = amount
		table.insert(modifiers, stat)
	end
	return stats, allocations, modifiers
end
function Armor.pick(catalog, rng, depth)
	local weights = if depth then Armor.DepthWeights[math.clamp(math.ceil(depth / 2), 1, 5)] else Armor.Weights
	local pick = rng:NextNumber(0, 100)
	local rarity = 5
	for i, weight in weights do
		pick -= weight
		if weight > 0 and pick < 0 then
			rarity = i
			break
		end
	end
	local choices = {}
	for _, item in catalog do
		if item.ArmorFamily and item.RarityTier == rarity then
			table.insert(choices, item)
		end
	end
	return if #choices > 0 then choices[rng:NextInteger(1, #choices)] else nil
end
function Armor.setState(loadout, resolve)
	local counts, bonuses, active = {}, {}, {}
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local gear = resolve(slot, loadout[slot])
		local family = gear and gear.ArmorFamily
		if family then
			counts[family] = (counts[family] or 0) + 1
		end
	end
	for _, family in Armor.Order do
		local count = counts[family] or 0
		local tier = if count >= Armor.FullSetPieces then 6 elseif count >= 4 then 4 elseif count >= 2 then 2 else 0
		active[family] = { Count = count, Tier = tier }
		for stat, amount in Armor.Sets[family][tier] or {} do
			bonuses[stat] = (bonuses[stat] or 0) + amount
		end
	end
	return { Counts = counts, Bonuses = bonuses, Active = active }
end
return Armor
