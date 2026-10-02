-- Weapon/Armor remain the saved keys for pistol/chest for backward compatibility.
local Slots = {}
Slots.Order = { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" }
Slots.Definitions = {
	Weapon = { Kind = "Weapons", Label = "Weapon" },
	Armor = { Kind = "Armors", Label = "Chest Suit" },
	Helmet = { Kind = "Helmets", Label = "Helmet" },
	Gloves = { Kind = "Gloves", Label = "Gloves" },
	Boots = { Kind = "Boots", Label = "Boots" },
	Shield = { Kind = "Shields", Label = "Shield" },
}
Slots.Kinds = { "Weapons", "Shields", "Helmets", "Armors", "Gloves", "Boots" }
Slots.ByKind =
	{ Weapons = "Weapon", Shields = "Shield", Helmets = "Helmet", Armors = "Armor", Gloves = "Gloves", Boots = "Boots" }
Slots.Catalog = {}
local variants = {
	{ "Scrap", "SuitScrap", "Utility", 1 },
	{ "Survey", "SuitZeroG", "Mobility", 2 },
	{ "Containment", "SuitThermal", "Survival", 3 },
	{ "Crusader", "SuitCrusader", "Defensive", 4 },
}
for _, slot in { "Helmet", "Gloves", "Boots", "Shield" } do
	local list = {}
	for i, variant in variants do
		local mods = {}
		local passive = { Name = "Utility", Text = "Standard expedition equipment.", Effect = {} }
		if i > 1 then
			if slot == "Boots" then
				passive =
					{ Name = "Magnetic Stride", Text = "+" .. (i - 1) .. " walk speed.", Effect = { SpeedAdd = i - 1 } }
			elseif slot == "Helmet" then
				passive = {
					Name = "Targeting Array",
					Text = "Rig Maneuvers and Gem Surges recharge " .. (i * 2) .. "% faster.",
					Effect = { CooldownMult = 1 - i * 0.02 },
				}
			elseif slot == "Gloves" then
				mods.Power = i * 2
				passive = { Name = "Emitter Stabilizer", Text = "+" .. (i * 2) .. " power rating.", Effect = {} }
			else
				passive = {
					Name = "Barrier Capacitor",
					Text = "Periodically absorb " .. (12 + i * 4) .. " damage.",
					Effect = { Ward = 12 + i * 4 },
				}
			end
		elseif slot == "Shield" then
			passive = { Name = "Barrier Capacitor", Text = "Periodically absorb 20 damage.", Effect = { Ward = 20 } }
		end
		table.insert(list, {
			Id = variant[1] .. slot,
			Name = variant[1] .. " " .. slot,
			Style = variant[3],
			Tier = variant[4],
			Look = variant[2],
			Mods = mods,
			Passive = passive,
		})
	end
	Slots.Catalog[Slots.Definitions[slot].Kind] = list
end
function Slots.effectSlot(slot: string): string
	return if slot == "Weapon" then "Weapon" else "Armor"
end
function Slots.initialize(profile)
	local c = profile.Character
	c.ItemGems = c.ItemGems or {}
	profile.Owned = profile.Owned or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		profile.Owned[kind] = profile.Owned[kind] or {}
		if slot ~= "Weapon" and slot ~= "Armor" and c.Class then
			local id = c[slot] or Slots.Catalog[kind][1].Id
			c[slot] = id
			profile.Owned[kind][id] = profile.Owned[kind][id] or 1
			c[slot .. "Quality"] = profile.Owned[kind][id]
		end
		c.ItemGems[slot] = c.ItemGems[slot] or {}
		if c[slot] and c[slot .. "Gem"] then
			c.ItemGems[slot][c[slot]] = c[slot .. "Gem"]
		end
	end
end
return Slots
