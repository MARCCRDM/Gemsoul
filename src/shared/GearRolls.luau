-- Serializable item rolls. Only the server creates them; clients read saved results.
local Slots = require(script.Parent.EquipmentSlots)
local ExpandedTraits = require(script.Parent.ExpandedItemTraits)
local ArmorFamilies = require(script.Parent.ArmorFamilies)
local GearRolls = {}
GearRolls.Rarities = {
	{ Name = "Common", Weight = 40, Color = Color3.fromRGB(205, 216, 225) },
	{ Name = "Uncommon", Weight = 25, Color = Color3.fromRGB(96, 211, 143) },
	{ Name = "Rare", Weight = 20, Color = Color3.fromRGB(89, 163, 248) },
	{ Name = "Ultra Rare", Weight = 10, Color = Color3.fromRGB(184, 115, 237) },
	{ Name = "Legendary", Weight = 5, Color = Color3.fromRGB(242, 172, 74) },
}
local colors = {
	Color3.fromRGB(225, 146, 60),
	Color3.fromRGB(196, 215, 228),
	Color3.fromRGB(61, 168, 182),
	Color3.fromRGB(145, 111, 192),
	Color3.fromRGB(211, 176, 84),
}
local visors = {
	Color3.fromRGB(80, 211, 247),
	Color3.fromRGB(240, 160, 68),
	Color3.fromRGB(129, 154, 248),
	Color3.fromRGB(237, 102, 198),
	Color3.fromRGB(100, 235, 174),
}
-- Rare+ armor carries Elemental Affinity Affixes. Saved rolls from before
-- affixes get theirs once (AffixVersion); weapons never roll them.
GearRolls.AffixVersion = 1
function GearRolls.addAffixes(roll, rng, gear)
	if roll.AffixVersion then
		return
	end
	roll.Affixes = ArmorFamilies.rollAffixes(roll.Rarity, rng, gear and gear.AffixTable)
	roll.AffixVersion = GearRolls.AffixVersion
end
function GearRolls.roll(rng, fixedRarity, gear)
	local pick, rarity = rng:NextInteger(1, 100), 1
	for i, entry in GearRolls.Rarities do
		pick -= entry.Weight
		if pick <= 0 then
			rarity = i
			break
		end
	end
	rarity = fixedRarity or rarity
	local stats = {}
	local names = { "Health", "Power", "Defense", "Speed" }
	for _ = 1, if rarity >= 3 then 2 else 1 do
		local index = rng:NextInteger(1, #names)
		local name = table.remove(names, index)
		stats[name] = rng:NextInteger(2, 4) * rarity
	end
	local roll = {
		Rarity = rarity,
		Stats = stats,
		Helmet = rng:NextInteger(1, 5),
		Visor = rng:NextInteger(1, 5),
		Finish = rng:NextInteger(1, 5),
		Variant = rng:NextInteger(1, 4),
	}
	if gear and ArmorFamilies.ById[gear.Id] then
		roll.Stats, roll.Points, roll.Modifiers = ArmorFamilies.rollStats(gear, rng)
		roll.ArmorBudgetVersion = ArmorFamilies.Version
		roll.Budget = gear.Budget
	end
	if gear and not gear.Attack and not gear.WeaponType then
		GearRolls.addAffixes(roll, rng, gear)
	end
	return roll
end
function GearRolls.get(loadout, slot, id)
	local kind = Slots.Definitions[slot].Kind
	return loadout.GearRolls and loadout.GearRolls[kind] and loadout.GearRolls[kind][id or loadout[slot]]
end
function GearRolls.appearance(roll)
	return {
		Rarity = roll.Rarity,
		Helmet = roll.Helmet,
		HelmetName = "Variant " .. roll.Helmet,
		HelmetRarity = GearRolls.Rarities[roll.Rarity].Name,
		VisorColor = if roll.MatrixVisor
			then (ExpandedTraits.Visors[roll.MatrixVisor] or {}).Color or visors[roll.Visor]
			else visors[roll.Visor],
		FinishColor = colors[roll.Finish],
		Variant = roll.Variant,
		VisorName = if roll.MatrixVisor then ExpandedTraits.Visors[roll.MatrixVisor].Name else nil,
	}
end
function GearRolls.ensure(profile, rng)
	local c = profile.Character
	c.GearRolls = c.GearRolls or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		c.GearRolls[kind] = c.GearRolls[kind] or {}
		for id in profile.Owned[kind] or {} do
			if not c.GearRolls[kind][id] then
				local fixedRarity, item
				for _, gear in ExpandedTraits.Catalog[kind] or {} do
					if gear.Id == id then
						fixedRarity = gear.RarityTier
						item = gear
						break
					end
				end
				if not item then
					for _, gear in ExpandedTraits.LegacyCatalog[kind] or {} do
						if gear.Id == id then
							fixedRarity, item = gear.RarityTier, gear
							break
						end
					end
				end
				local roll = GearRolls.roll(rng, fixedRarity, item)
				if fixedRarity then
					local visor = ExpandedTraits.pick(ExpandedTraits.Visors, rng)
					roll.MatrixVisor = visor.Index
				end
				c.GearRolls[kind][id] = roll
			end
			if kind ~= "Weapons" then
				GearRolls.addAffixes(c.GearRolls[kind][id], rng, ArmorFamilies.ById[id])
			end
		end
	end
end
function GearRolls.grant(profile, class, rng)
	Slots.initialize(profile)
	local c = profile.Character
	if c.RandomLoadoutVersion == 1 then
		GearRolls.ensure(profile, rng)
		return false
	end
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local catalog = class[kind]
		-- Retire the fixed basic starter; independently roll every equipment category.
		local gear = (if kind ~= "Weapons" then ArmorFamilies.pick(catalog, rng) else ExpandedTraits.pick(catalog, rng))
		if not gear then
			-- Fallback: any item that can be handed out (never a disabled pistol).
			local pool = {}
			for _, item in catalog do
				if ExpandedTraits.obtainable(item) then
					table.insert(pool, item)
				end
			end
			pool = if #pool > 0 then pool else catalog
			gear = pool[rng:NextInteger(if #pool > 1 then 2 else 1, #pool)]
		end
		if c[slot] and c[slot .. "Gem"] then
			c.ItemGems[slot][c[slot]] = c[slot .. "Gem"]
		end
		profile.Owned[kind][gear.Id] = profile.Owned[kind][gear.Id] or 1
		c[slot] = gear.Id
		c[slot .. "Quality"] = profile.Owned[kind][gear.Id]
		c[slot .. "Gem"] = c.ItemGems[slot][gear.Id]
	end
	GearRolls.ensure(profile, rng)
	c.RandomLoadoutVersion = 1
	return true
end
return GearRolls
