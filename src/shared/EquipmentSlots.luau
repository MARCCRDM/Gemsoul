-- Weapon/Armor remain the saved keys for pistol/chest for backward compatibility.
local Slots = {}
Slots.SurgeOrder = { "Surge1", "Surge2", "Surge3" }
Slots.SurgeDefinitions =
	{ Surge1 = { Label = "Gem Surge 1" }, Surge2 = { Label = "Gem Surge 2" }, Surge3 = { Label = "Gem Surge 3" } }
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

-- Gear copies: a player can own several of one model. The first copy is
-- keyed by the model id ("ScrapHelmet"), more copies by "ScrapHelmet#2",
-- "#3"... Everything that looks a model up goes through Slots.model(key).
function Slots.model(key: any): any
	if type(key) ~= "string" then
		return key
	end
	return string.match(key, "^([^#]+)#") or key
end
-- The key a new copy of `model` gets in one owned list (model id -> quality).
function Slots.freeKey(owned: { [string]: any }, model: string): string
	model = Slots.model(model)
	if owned[model] == nil then
		return model
	end
	local n = 2
	while owned[model .. "#" .. n] ~= nil do
		n += 1
	end
	return model .. "#" .. n
end
-- How many pieces of gear a profile holds (all slots, worn included).
function Slots.gearCount(profile): number
	local n = 0
	for _, kind in Slots.Kinds do
		for _ in profile.Owned and profile.Owned[kind] or {} do
			n += 1
		end
	end
	return n
end
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
