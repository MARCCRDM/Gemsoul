-- Non-yielding two-item exchange. Item rolls travel with the item; socketed
-- gems go back to their owner's bag (gear changes hands with an empty socket).
local Slots = require(script.Parent.EquipmentSlots)
local Trade = {}
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not equal(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
Trade.matches = equal
function Trade.item(profile, slot, id)
	local def = Slots.Definitions[slot]
	if not profile or not def or type(id) ~= "string" then
		return nil
	end
	local quality = profile.Owned[def.Kind] and profile.Owned[def.Kind][id]
	if not quality then
		return nil
	end
	local c = profile.Character
	local gem = if c[slot] == id then c[slot .. "Gem"] else c.ItemGems[slot][id]
	return copy({ Id = id, Slot = slot, Quality = quality, Roll = c.GearRolls[def.Kind][id], Gem = gem })
end
function Trade.validate(a, b, left, right)
	if a == b or not left or not right or left.Slot ~= right.Slot then
		return false, "Choose two items from the same equipment slot."
	end
	if not equal(Trade.item(a, left.Slot, left.Id), left) or not equal(Trade.item(b, right.Slot, right.Id), right) then
		return false, "An offered item changed. Start a new trade."
	end
	return true
end
-- Puts a gem that came out of traded gear into the profile's gem bag.
function Trade.keepGem(profile, gem)
	if type(gem) ~= "table" then
		return
	end
	profile.Gems = profile.Gems or {}
	for _, held in profile.Gems do
		if held.Id == gem.Id then
			return
		end
	end
	table.insert(profile.Gems, copy(gem))
end
function Trade.exchange(a, b, left, right)
	local valid, message = Trade.validate(a, b, left, right)
	if not valid then
		return false, message
	end
	local slot = left.Slot
	local kind = Slots.Definitions[slot].Kind
	-- Gear changes hands with an empty socket: each side's gem goes back to
	-- its own gem bag first.
	local function remove(profile, item)
		profile.Owned[kind][item.Id] = nil
		profile.Character.GearRolls[kind][item.Id] = nil
		profile.Character.ItemGems[slot][item.Id] = nil
		Trade.keepGem(profile, item.Gem)
	end
	local function receive(profile, outgoing, incoming)
		local c = profile.Character
		-- A copy of a model they already own gets its own key (Slots.freeKey).
		local key = Slots.freeKey(profile.Owned[kind], incoming.Id)
		profile.Owned[kind][key] = incoming.Quality
		c.GearRolls[kind][key] = incoming.Roll
		c.ItemGems[slot][key] = nil
		if c[slot] == outgoing.Id then
			c[slot] = key
			c[slot .. "Quality"] = incoming.Quality
			c[slot .. "Gem"] = nil
		end
	end
	remove(a, left)
	remove(b, right)
	receive(a, left, right)
	receive(b, right, left)
	return true, "Trade complete. Socketed gems went back to their owners' bags."
end
return Trade
