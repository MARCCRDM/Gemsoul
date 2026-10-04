-- Dungeon equipment uses the same catalog, armor budgets and gem effects as players.
local Classes = require(script.Parent.Classes)
local Slots = require(script.Parent.EquipmentSlots)
local GearRolls = require(script.Parent.GearRolls)
local GemRoller = require(script.Parent.GemRoller)
local Loadout = {}
Loadout.Families = { Fire = "Juggernaut", Frost = "Juggernaut", Poison = "Prospector", Shock = "Skirmisher" }
Loadout.Labels = { "Common", "Uncommon", "Rare", "Ultra Rare", "Legendary" }
function Loadout.apply(c, spec, rarity, rng)
	rarity = math.clamp(math.floor(rarity), 1, 5)
	local family = Loadout.Families[spec.Element]
	local catalog = Classes.get("Warrior")
	c.GearRolls = c.GearRolls or {}
	c.ItemGems = c.ItemGems or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local selected = nil
		for _, item in catalog[kind] do
			if item.ArmorFamily == family and (slot == "Weapon" or item.RarityTier == rarity) then
				if slot ~= "Weapon" or ((item.Attack.Kind == "Shot") == (spec.Shape == "Crocodile")) then
					selected = item
					if slot ~= "Weapon" or item.RarityTier == rarity then
						break
					end
				end
			end
		end
		assert(selected, "Missing dungeon equipment: " .. family .. " / " .. slot)
		c[slot] = selected.Id
		c[slot .. "Quality"] = 1
		c.GearRolls[kind] = c.GearRolls[kind] or {}
		c.GearRolls[kind][selected.Id] = GearRolls.roll(rng, rarity, selected)
	end
	local keys = {}
	for _, slot in Slots.Order do
		table.insert(keys, slot)
	end
	for _, slot in Slots.SurgeOrder do
		table.insert(keys, slot)
	end
	local tierName = GemRoller.Rarities[rarity].Name
	local rules = GemRoller.ByRarity[tierName]
	for i, slot in keys do
		local gem = c[slot .. "Gem"] or { Id = "dungeon-" .. slot, Source = "DungeonNPC", Found = 0, CutMethod = "Natural" }
		gem.Tier = tierName
		gem.Element = spec.Element
		-- Disjoint metric bands make each difficulty a measurable upgrade.
		for _, metric in { "Size", "Clarity", "Cut" } do
			gem[metric] = rng:NextInteger(rarity * 2, math.min(10, rarity * 2 + 1))
		end
		gem.SurgeTier = rules.Tiers[1 + (i - 1) % #rules.Tiers]
		gem.SurgeRank = rules.Ranks[#rules.Ranks]
		gem.Surge = GemRoller.Surges[spec.Element][gem.SurgeTier]
		c[slot .. "Gem"] = gem
		if Slots.Definitions[slot] then
			c.ItemGems[slot] = c.ItemGems[slot] or {}
			c.ItemGems[slot][c[slot]] = gem
		end
	end
	return family
end
return Loadout
