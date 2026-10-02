local total, families = 0, {}
for kind, catalog in ArmorFamilies.Catalog do
	assert(#catalog == 15, "Every armor slot needs fifteen entries")
	for _, item in catalog do
		total += 1
		families[item.ArmorFamily] = (families[item.ArmorFamily] or 0) + 1
		for seed = 1, 30 do
			local stats, allocations, modifiers = ArmorFamilies.rollStats(item, Random.new(seed))
			local budget = 0
			for stat, points in allocations do
				budget += points * ArmorFamilies.Costs[stat]
				assert(stats[stat] == points * ArmorFamilies.Values[stat], "Point conversion differs")
			end
			assert(budget == item.Budget and #modifiers == item.ModifierSlots, "Budget mismatch")
		end
	end
end
assert(total == 75)
for _, count in families do
	assert(count == 25)
end
for _, family in ArmorFamilies.Order do
	local loadout = { Class = "Warrior" }
	for i, slot in ArmorFamilies.Slots do
		loadout[slot] = "Armor" .. family .. slot .. "5"
		local state = Classes.setState(loadout).Active[family]
		assert(state.Count == i and state.Tier == (if i >= 4 then 4 elseif i >= 2 then 2 else 0))
	end
	for _, weapon in ExpandedTraits.Catalog.Weapons do
		if weapon.ArmorFamily == family then
			loadout.Weapon = weapon.Id
			break
		end
	end
	local state = Classes.setState(loadout)
	assert(state.Active[family].Tier == 6)
	for stat, amount in ArmorFamilies.Sets[family][6] do
		assert(state.Bonuses[stat] == amount, "Set tiers must replace earlier tiers")
	end
end
for depth = 1, 10 do
	local weights = ArmorFamilies.DepthWeights[math.ceil(depth / 2)]
	local counts, rng = {}, Random.new(912 + depth)
	for _ = 1, 10000 do
		local item = ArmorFamilies.pick(ArmorFamilies.Catalog.Helmets, rng, depth)
		assert(weights[item.RarityTier] > 0, "Forbidden depth rarity")
		counts[item.RarityTier] = (counts[item.RarityTier] or 0) + 1
	end
	for rarity, expected in weights do
		assert(math.abs((counts[rarity] or 0) / 100 - expected) < 2)
	end
end
print("PASS: 75 armor entries, 2250 exact point budgets, matching-weapon six-piece sets and 100,000 depth drops")
