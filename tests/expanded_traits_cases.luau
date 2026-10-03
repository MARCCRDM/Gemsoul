-- Weighted starting-pool coverage and executable equipment contracts.
local draws, counts = 0, {}
for kind, catalog in ExpandedTraits.Catalog do
	assert(#catalog == (if kind == "Weapons" then 20 + #WeaponForge.Catalog else 15), "Unexpected catalog size for " .. kind)
	local seen, rarityCounts = {}, { 0, 0, 0, 0, 0 }
	local rng = Random.new(9231)
	for _ = 1, 10000 do
		local item = ExpandedTraits.pick(catalog, rng)
		assert(item and item.StartPool, "Draw escaped the expanded pool")
		seen[item.Id] = true
		rarityCounts[item.RarityTier] += 1
		draws += 1
	end
	for _, item in catalog do
		if item.StartPool and ExpandedTraits.obtainable(item) then
			assert(seen[item.Id], "Starting draw never reached " .. item.Id)
		else
			-- Pistols are switched off, and the older swords retired: never drawn.
			assert(not seen[item.Id], "A retired weapon was drawn: " .. item.Id)
		end
		assert(Classes.gear("Warrior", kind, item.Id) == item, "Catalog identity differs")
		if kind == "Weapons" then
			assert(
				(
					item.Attack.Kind == "Shot"
					or (item.Attack.Kind == "Melee" and item.Attack.Range <= 10 and item.Attack.Combo == 3)
				)
					and item.Attack.Rate > 0
					and item.Attack.Damage > 0,
				"Sword attack contract invalid"
			)
		end
	end
	for rarity, expected in ExpandedTraits.Weights do
		assert(math.abs(rarityCounts[rarity] / 100 - expected) < 2, "Rarity weights drifted")
	end
	counts[kind] = rarityCounts
end
-- The Forge: 25 weapons, five kinds in five rarities, each with its own perk.
assert(#WeaponForge.Catalog == 25, "The Forge should hold 25 weapons")
local perkKeys, kinds = {}, {}
for _, weapon in WeaponForge.Catalog do
	assert(weapon.StartPool and ExpandedTraits.obtainable(weapon), weapon.Id .. " can't be found")
	assert(weapon.Look == "Forge" .. weapon.WeaponType, weapon.Id .. " lost its look")
	assert(weapon.ArmorFamily ~= nil, weapon.Id .. " has no set family")
	local key, value = next(weapon.Passive.Effect)
	assert(key and WeaponForge.Perks[key] and value > 0, weapon.Id .. " has no working perk")
	assert(not perkKeys[key], "Two weapons share the perk " .. key)
	perkKeys[key] = true
	assert(string.find(weapon.Passive.Text, "%d+%%") ~= nil, weapon.Id .. "'s perk doesn't say how much")
	kinds[weapon.WeaponType] = (kinds[weapon.WeaponType] or 0) + 1
	-- Every kind deals about the same damage per second.
	local dps = weapon.Attack.Damage / weapon.Attack.Rate
	assert(dps > 25 and dps < 30, weapon.Id .. " is out of line: " .. dps .. " damage per second")
end
for _, kind in WeaponForge.Types do
	assert(kinds[kind.Id] == 5, kind.Id .. " doesn't come in five rarities")
end
-- Visible rolls: every finish and visor has a name; about 1 in 100 rolls is
-- Prismatic; the identity line names finish, Prismatic, serial and finder.
local prismatic, prng = 0, Random.new(4242)
for _ = 1, 20000 do
	local roll = GearRolls.roll(prng)
	local look = GearRolls.appearance(roll)
	assert(look.FinishName and look.VisorName, "A roll's finish or visor has no name")
	if roll.Prismatic then
		prismatic += 1
	end
end
assert(prismatic > 120 and prismatic < 290, "Prismatic isn't about 1 in 100: " .. prismatic .. " of 20000")
local identity = GearRolls.identity({ Finish = 5, Prismatic = true, Serial = 12, FoundBy = "Marc" })
assert(identity == "Solar Gold finish  ·  ✦ PRISMATIC  ·  #12  ·  Found by Marc", "Identity line wrong: " .. identity)
assert(GearRolls.identity({ Finish = 1 }) == "Ember Copper finish", "A plain roll's identity line wrong")
local visorSeen = {}
local visorRng = Random.new(59123)
for _ = 1, 10000 do
	visorSeen[ExpandedTraits.pick(ExpandedTraits.Visors, visorRng).Index] = true
end
for i = 1, 10 do
	assert(visorSeen[i], "Visor unreachable")
end
local seedProfile = { Character = { Class = "Warrior" }, Owned = {}, Gems = {} }
GearRolls.grant(seedProfile, Classes.get("Warrior"), Random.new(312))
for _, slot in Slots.Order do
	local item = Classes.gear("Warrior", Slots.Definitions[slot].Kind, seedProfile.Character[slot])
	local roll = GearRolls.get(seedProfile.Character, slot)
	assert(item.StartPool and roll.Rarity == item.RarityTier, "Item rarity disagrees with persisted roll")
	assert(GearRolls.appearance(roll).VisorName, "Visor identity missing")
end
local previous = seedProfile.Character.Weapon
assert(not GearRolls.grant(seedProfile, Classes.get("Warrior"), Random.new(434)), "Rejoining rerolled equipment")
assert(seedProfile.Character.Weapon == previous, "Rejoining changed saved item")
print(
	"PASS: 60,000 weighted starter draws; every obtainable item and 10 visors reachable; 25 Forge weapons with 25 different perks; named finishes, 1-in-100 Prismatic; attack contracts and saved rarity valid"
)

local rapid = Classes.gear("Warrior", "Weapons", "MatrixWeapons6")
assert(rapid.Attack.Rate == 0.36 and rapid.Attack.Damage == 9.9, "Pistol rapid-fire tradeoff drifted")

local B = EquipmentBalance
assert(B.passiveDamageMultiplier(0.5, 0.6) == 0.8, "Combined passive budget exceeded")
assert(math.abs(B.passiveDamageMultiplier(0.9, 0.05) - 0.855) < 0.00001, "Below-cap mitigation changed")
assert(B.passiveDamageMultiplier(nil, 0) == 1, "Unmodified damage changed")
assert(B.cooldownMultiplier(0.1) == 0.4 and B.cooldownMultiplier(0.9) == 0.9, "Cooldown cap failed")
assert(B.criticalChance(10000, 1) == 0.75, "Critical chance exceeded 10%")
assert(B.criticalChance(0, 0) == 0.05, "Base critical chance changed")
assert(B.hazardResistance(1) == 0.6 and B.hazardResistance(-1) == 0, "Hazard immunity slipped through")
local gates = {}
assert(B.consumeUtility(gates, "Reflection", 100), "First reflection denied")
assert(not B.consumeUtility(gates, "Reflection", 124.99), "Reflection cooldown bypassed")
assert(B.consumeUtility(gates, "Reflection", 125), "Reflection boundary denied")
assert(B.consumeUtility(gates, "PhaseDodge", 100), "Independent utility denied")
assert(not B.consumeUtility(gates, "PhaseDodge", 129.99), "Phase cooldown bypassed")
assert(B.consumeUtility(gates, "PhaseDodge", 130), "Phase boundary denied")
assert(not B.consumeUtility(gates, "Unknown", 200), "Unknown utility authorized")
-- Force stacked real catalog effects to exercise aggregation, then restore them.
local helmet = Classes.gear("Warrior", "Helmets", "MatrixHelmets1")
local gloves = Classes.gear("Warrior", "Gloves", "MatrixGloves1")
local oldHelmet, oldGloves = helmet.Passive.Effect, gloves.Passive.Effect
helmet.Passive.Effect = { TakenMult = 0.6, CooldownMult = 0.6, CritAdd = 0.08 }
gloves.Passive.Effect = { TakenMult = 0.6, CooldownMult = 0.6, CritAdd = 0.08 }
local capped = Classes.effects({ Class = "Warrior", Helmet = helmet.Id, Gloves = gloves.Id })
assert(capped.TakenMult == 0.8 and capped.CooldownMult == 0.4 and capped.CritAdd == 0.16, "Loadout caps not applied")
helmet.Passive.Effect, gloves.Passive.Effect = oldHelmet, oldGloves
print("PASS: passive budget stacking, critical cap, hazard resistance and shared utility cooldown boundaries")

assert(ExpandedTraits.LegacyCatalog.Boots[9].PlannedHazardResistance == 0.6, "Thermal resistance policy missing")
assert(ExpandedTraits.LegacyCatalog.Gloves[7].PlannedHazardResistance == 0.6, "Corrosive resistance policy missing")
assert(ExpandedTraits.LegacyCatalog.Boots[10].InternalCooldown == 30, "Phase utility budget missing")
assert(ExpandedTraits.Visors[10].InternalCooldown == 30, "First hit budget missing")
assert(ExpandedTraits.LegacyCatalog.Shields[5].InternalCooldown == 25, "Reflection budget missing")

for _, isR15 in { false, true } do
	for _, look in { "UtilityMiner", "FrontierRanger", "HeavyVanguard" } do
		local before = built
		ArmorKits.build(
			{},
			rig(isR15),
			look,
			Color3.fromRGB(72, 207, 226),
			4,
			{ VisorColor = Color3.fromRGB(72, 207, 226), FinishColor = Color3.fromRGB(200, 100, 50), Variant = 4 }
		)
		assert(built - before >= 25 and built - before <= 110, "Frontier family part budget violated")
		for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
			local start = built
			ArmorKits.build({}, rig(isR15), look, Color3.fromRGB(72, 207, 226), 1, nil, slot)
			assert(built > start, "Clean equipment slot has no geometry")
		end
	end
end
assert(Classes.gear("Warrior", "Weapons", "MatrixSwords6").Look == "FrontierSword", "Sword model not connected")
print("PASS: simplified families build on R6/R15, all four armor slots, at most 110 parts per family")

for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
	local previous = 0
	for rarity = 1, 5 do
		local before = built
		ArmorKits.build({}, rig(false), "FrontierRanger", Color3.fromRGB(72, 207, 226), 1, {
			Rarity = rarity,
			Helmet = 1,
			VisorColor = Color3.fromRGB(72, 207, 226),
			FinishColor = Color3.fromRGB(90, 100, 120),
		}, slot)
		local count = built - before
		assert(count > previous, "Each rarity must add visible details to " .. slot)
		previous = count
	end
end
assert(GearRolls.appearance({ Rarity = 5, Helmet = 1, Visor = 1, Finish = 1, Variant = 1 }).Rarity == 5)
print("PASS: every armor slot gains geometry at each rarity; saved rarity reaches rendering")

-- Named helmets must remain distinct even when their saved cosmetic rolls match.
for _, isR15 in { false, true } do
	local signatures = {}
	for _, item in ExpandedTraits.Catalog.Helmets do
		local before = #builtParts
		ArmorKits.build({}, rig(isR15), item.Look, Color3.fromRGB(72, 207, 226), 1, {
			Rarity = item.RarityTier,
			Helmet = 1,
			VisorColor = Color3.fromRGB(72, 207, 226),
			FinishColor = Color3.fromRGB(90, 100, 120),
		}, "Helmet", item.Id)
		local geometry = {}
		for i = before + 1, #builtParts do
			local part = builtParts[i]
			table.insert(
				geometry,
				string.format("%s:%.4f:%.4f:%.4f", part.ClassName, part.Size.X, part.Size.Y, part.Size.Z)
			)
		end
		local signature = table.concat(geometry, "|")
		assert(not signatures[signature], "Named helmets share geometry: " .. item.Id)
		signatures[signature] = true
		assert(#geometry <= 80, "Helmet exceeds geometry budget: " .. item.Id)
	end
end
print("PASS: all fifteen new helmets have distinct geometry on R6/R15 with identical saved rolls")

for _, builder in { FrontierAssets.sidearm, FrontierAssets.sword, FrontierAssets.shield } do
	local previous = 0
	for rarity = 1, 5 do
		local before = built
		builder(
			{},
			{ CFrame = CFrame.identity },
			CFrame.identity,
			rarity,
			Color3.fromRGB(72, 207, 226),
			Color3.fromRGB(72, 117, 129)
		)
		local count = built - before
		assert(count > previous and count < 50, "Weapon/shield detail must increase within budget")
		for i = #builtParts - count + 1, #builtParts do
			local part = builtParts[i]
			assert(
				part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,
				"Decorative equipment must not affect physics or targeting"
			)
		end
		previous = count
	end
end
for _, weapon in Classes.List.Warrior.Weapons do
	if weapon.WeaponType == nil then
		-- Migrated Wizard/Archer/Tank items retain their original weapon models.
		assert(weapon.Attack)
	elseif weapon.WeaponType == "Sword" then
		assert(weapon.Attack.Kind == "Melee" and weapon.Look == "FrontierSword")
	elseif weapon.Forge then
		assert(weapon.Attack.Kind == "Melee" and weapon.Look == "Forge" .. weapon.WeaponType, "Forge weapon lost its look")
	else
		assert(weapon.Attack.Kind == "Shot" and weapon.Look == "CleanSidearm", "Original pistol changed")
	end
end
print("PASS: five pistol/sword/shield rarity models, valid geometry and physics, saved weapon compatibility")

for _, isR15 in { false, true } do
	for _, look in { "UtilityMiner", "FrontierRanger", "HeavyVanguard" } do
		for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
			local previous = 0
			for rarity = 1, 5 do
				local before = built
				ArmorKits.build({}, rig(isR15), look, Color3.fromRGB(72, 207, 226), 1, {
					Rarity = rarity,
					Helmet = 1,
					VisorColor = Color3.fromRGB(72, 207, 226),
					FinishColor = Color3.fromRGB(90, 100, 120),
				}, slot)
				local count = built - before
				assert(count > previous and count <= 100, "Armor detail progression or slot budget violated")
				previous = count
			end
		end
	end
end
print("PASS: all suit families and armor slots gain detail at each rarity on R6/R15 within slot budgets")
-- Pistols switched off: no starter kit or rolled loadout hands one out.
assert(not ExpandedTraits.PistolsObtainable, "Pistols should be switched off for now")
local warrior = Classes.get("Warrior")
assert(Classes.starterWeapon(warrior).WeaponType ~= "Pistol", "Starter weapon is a pistol")
local pistolRng = Random.new(77)
for _ = 1, 400 do
	local profile = { Character = { Class = "Warrior", Weapon = Classes.starterWeapon(warrior).Id, Armor = warrior.Armors[1].Id }, Owned = {} }
	Slots.initialize(profile)
	GearRolls.grant(profile, warrior, pistolRng)
	local weapon = Classes.weapon("Warrior", profile.Character.Weapon)
	assert(weapon and weapon.WeaponType ~= "Pistol", "A rolled loadout got a pistol: " .. tostring(profile.Character.Weapon))
end
print("PASS: pistols switched off: never drawn, rolled or given as the starter weapon")
