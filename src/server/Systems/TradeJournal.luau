-- Write-ahead equipment trade records. A committed exchange replays once per
-- profile after reconnect, until a saved checkpoint removes its pending index.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Logic = require(ReplicatedStorage.Shared.EquipmentTrade)
local Journal = {}
local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DataStoreName .. "_EquipmentTrades")
if not ok then
	store = nil
end
local function transactionKey(id)
	return "trade_" .. id
end
local function userKey(id)
	return "pending_" .. id
end
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
function Journal.commit(id, aId, bId, left, right, equippedA, equippedB, validate)
	if not store then
		return false, "unavailable"
	end
	local record = {
		A = aId,
		B = bId,
		Left = copy(left),
		Right = copy(right),
		EquippedA = equippedA,
		EquippedB = equippedB,
		Committed = false,
	}
	local prepared = pcall(function()
		store:SetAsync(transactionKey(id), record)
		for _, userId in { aId, bId } do
			store:UpdateAsync(userKey(userId), function(index)
				local entries = index or {}
				if not table.find(entries, id) then
					table.insert(entries, id)
				end
				return entries
			end)
		end
	end)
	if not prepared then
		return false, "unavailable"
	end
	if not validate() then
		return false, "changed"
	end
	-- Recovery aborts unfinished records using UpdateAsync too. Its CAS barrier
	-- prevents a departed player's old request from committing after they rejoin.
	local committed, result = pcall(store.UpdateAsync, store, transactionKey(id), function(current)
		if not current or current.Aborted then
			return nil
		end
		current.Committed = true
		return current
	end)
	if not committed then
		return false, "uncertain"
	end
	return result ~= nil and result.Committed == true, "cancelled"
end
function Journal.mark(profile, id)
	profile.AppliedEquipmentTrades = profile.AppliedEquipmentTrades or {}
	profile.AppliedEquipmentTrades[id] = true
end
function Journal.recover(userId, profile)
	if not store then
		return false
	end
	local readable, entries = pcall(store.GetAsync, store, userKey(userId))
	if not readable then
		return false
	end
	for _, id in entries or {} do
		if profile.AppliedEquipmentTrades and profile.AppliedEquipmentTrades[id] then
			continue
		end
		local resolved, record = pcall(store.UpdateAsync, store, transactionKey(id), function(current)
			if not current then
				return nil
			end
			if not current.Committed then
				current.Aborted = true
			end
			return current
		end)
		if not resolved then
			return false
		end
		if record and record.Committed then
			if record.A ~= userId and record.B ~= userId then
				return false
			end
			local outgoing = if record.A == userId then record.Left else record.Right
			local incoming = if record.A == userId then record.Right else record.Left
			local wasEquipped = if record.A == userId then record.EquippedA else record.EquippedB
			local slot = outgoing.Slot
			local def = Slots.Definitions[slot]
			if not def or incoming.Slot ~= slot then
				return false
			end
			local c, kind = profile.Character, def.Kind
			profile.Owned[kind] = profile.Owned[kind] or {}
			c.GearRolls = c.GearRolls or {}
			c.GearRolls[kind] = c.GearRolls[kind] or {}
			c.ItemGems = c.ItemGems or {}
			c.ItemGems[slot] = c.ItemGems[slot] or {}
			profile.Owned[kind][outgoing.Id] = nil
			c.GearRolls[kind][outgoing.Id] = nil
			c.ItemGems[slot][outgoing.Id] = nil
			-- (As in EquipmentTrade.exchange: your gem stays with you, in your bag.)
			Logic.keepGem(profile, outgoing.Gem)
			-- A copy of a model they already own gets its own key (Slots.freeKey).
			local key = Slots.freeKey(profile.Owned[kind], incoming.Id)
			profile.Owned[kind][key] = incoming.Quality
			c.GearRolls[kind][key] = copy(incoming.Roll)
			c.ItemGems[slot][key] = nil
			if wasEquipped or c[slot] == outgoing.Id then
				c[slot] = key
				c[slot .. "Quality"] = incoming.Quality
				c[slot .. "Gem"] = nil
			end
		end
		Journal.mark(profile, id)
	end
	return true
end
function Journal.checkpoint(userId, applied)
	if not store then
		return
	end
	-- Only ids present before the completed profile save may leave the index.
	pcall(store.UpdateAsync, store, userKey(userId), function(index)
		if not index then
			return nil
		end
		local remaining = {}
		for _, id in index do
			if not applied[id] then
				table.insert(remaining, id)
			end
		end
		return remaining
	end)
end
return Journal
