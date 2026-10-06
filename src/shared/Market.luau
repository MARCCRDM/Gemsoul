--[[
	The Market board: players leave gear or gems up for coins or for trade
	offers, and other players (on any server) buy them or make offers.

	A listed item leaves its owner's bag at once and waits in escrow (the
	owner's profile, Market.Escrow) until it sells, is traded, or comes back
	(cancelled, expired). An offered item waits in the offerer's escrow the
	same way. So nothing can be sold twice, or used while it's up for sale.

	These are the shared rules and the plain-table item moves; the server's
	MarketBoard does the selling and the client's MarketBoardUI the screens.

	An item on the move (a "payload"):
	  { Kind = "Gem", Gem = <gem> }
	  { Kind = "Gear", Slot = "Weapon", Id = <gear id>, Quality, Roll, Gem? }
]]
local Slots = require(script.Parent.EquipmentSlots)

local Market = {}

Market.MaxListings = 6 -- open listings per player
Market.MaxOffers = 8 -- offers waiting on one trade listing
Market.MaxOffersOut = 6 -- offers a player has out at once
Market.ListingSeconds = 48 * 3600
Market.MinPrice = 1
Market.MaxPrice = 10000000
Market.Tax = 0.05 -- taken from the seller's coins on a sale (an economy drain)
-- What a trade listing is after, picked from a list (no free text).
Market.Wants = {
	{ Id = "Any", Label = "Any offer" },
	{ Id = "Gear", Label = "Gear" },
	{ Id = "Gems", Label = "Gems" },
	{ Id = "Rare", Label = "Rare or better" },
}
Market.WantLabels = {}
for _, want in Market.Wants do
	Market.WantLabels[want.Id] = want.Label
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
Market.copy = copy

function Market.payout(price: number): number
	return math.max(0, price - math.floor(price * Market.Tax + 0.5))
end

function Market.validPrice(price: any): boolean
	return type(price) == "number"
		and price == price
		and price == math.floor(price)
		and price >= Market.MinPrice
		and price <= Market.MaxPrice
end

function Market.escrow(profile)
	profile.Market = profile.Market or {}
	profile.Market.Escrow = profile.Market.Escrow or {}
	return profile.Market.Escrow
end

-- Counts a player's escrow entries of one role ("Sell" or "Offer").
function Market.count(profile, role: string): number
	local n = 0
	for _, entry in profile.Market and profile.Market.Escrow or {} do
		if entry.Role == role then
			n += 1
		end
	end
	return n
end

local function gemIndex(profile, id)
	for i, gem in profile.Gems or {} do
		if gem.Id == id then
			return i
		end
	end
	return nil
end

-- Where a gem is: "Bag" (index), "Socket" (a worn piece's or a Q/E/R surge
-- socket: the Character key), or "Spare" (in a spare piece: slot, gear key).
local function findGem(profile, id)
	local i = gemIndex(profile, id)
	if i then
		return "Bag", i
	end
	local c = profile.Character or {}
	for _, slot in Slots.SurgeOrder do
		local gem = c[slot .. "Gem"]
		if type(gem) == "table" and gem.Id == id then
			return "Socket", slot
		end
	end
	for _, slot in Slots.Order do
		local gem = c[slot .. "Gem"]
		if type(gem) == "table" and gem.Id == id then
			return "Socket", slot
		end
		for key, spare in c.ItemGems and c.ItemGems[slot] or {} do
			if type(spare) == "table" and spare.Id == id and key ~= c[slot] then
				return "Spare", slot, key
			end
		end
	end
	return nil
end
Market.findGem = findGem

local function gearKind(slot)
	local def = Slots.Definitions[slot]
	return def and def.Kind
end

-- Why an item can't be listed or offered, or nil when it can.
function Market.whyNot(profile, kind: any, slot: any, id: any): string?
	if type(id) ~= "string" then
		return "Pick an item."
	end
	if kind == "Gem" then
		return if findGem(profile, id) then nil else "You don't have that gem."
	elseif kind == "Gear" then
		local gearType = gearKind(slot)
		if not gearType then
			return "Pick an item."
		end
		if not (profile.Owned[gearType] and profile.Owned[gearType][id]) then
			return "You don't own that item."
		end
		if profile.Character[slot] == id then
			return "Take it off first: you can't sell what you're wearing."
		end
		return nil
	end
	return "Pick an item."
end

-- Takes an item out of the profile and returns it as a payload (or nil and
-- why not).
function Market.take(profile, kind: any, slot: any, id: any)
	local why = Market.whyNot(profile, kind, slot, id)
	if why then
		return nil, why
	end
	if kind == "Gem" then
		-- Socketed gems come out of their socket.
		local where, a, b = findGem(profile, id)
		local c = profile.Character
		local gem
		if where == "Bag" then
			gem = table.remove(profile.Gems, a)
		elseif where == "Socket" then
			gem = c[a .. "Gem"]
			c[a .. "Gem"] = nil
			if c.ItemGems and c.ItemGems[a] and c[a] ~= nil then
				c.ItemGems[a][c[a]] = nil
			end
		else
			gem = c.ItemGems[a][b]
			c.ItemGems[a][b] = nil
		end
		return { Kind = "Gem", Gem = gem }
	end
	local gearType = gearKind(slot)
	local c = profile.Character
	local payload = {
		Kind = "Gear",
		Slot = slot,
		Id = id,
		Quality = profile.Owned[gearType][id],
		Roll = copy(c.GearRolls and c.GearRolls[gearType] and c.GearRolls[gearType][id]),
		Gem = copy(c.ItemGems and c.ItemGems[slot] and c.ItemGems[slot][id]),
	}
	profile.Owned[gearType][id] = nil
	if c.GearRolls and c.GearRolls[gearType] then
		c.GearRolls[gearType][id] = nil
	end
	if c.ItemGems and c.ItemGems[slot] then
		c.ItemGems[slot][id] = nil
	end
	return payload
end

-- Why the profile can't take this payload in, or nil when it can.
function Market.cantReceive(profile, payload, maxGems: number, maxGear: number?): string?
	if type(payload) ~= "table" then
		return "That item is gone."
	end
	if payload.Kind == "Gem" then
		if type(payload.Gem) ~= "table" then
			return "That item is gone."
		end
		if #(profile.Gems or {}) >= maxGems then
			return "Your gem bag is full."
		end
		if findGem(profile, payload.Gem.Id) then
			return "You already have that gem."
		end
		return nil
	elseif payload.Kind == "Gear" then
		local gearType = gearKind(payload.Slot)
		if not gearType then
			return "That item is gone."
		end
		if Slots.gearCount(profile) >= (maxGear or math.huge) then
			return "Your gear bag is full."
		end
		return nil
	end
	return "That item is gone."
end

-- Puts a payload into the profile. `force` skips the bag-size limit (an
-- item coming home from escrow always fits back).
function Market.give(profile, payload, maxGems: number, force: boolean?): boolean
	local why = Market.cantReceive(profile, payload, if force then math.huge else maxGems)
	if why then
		return false
	end
	if payload.Kind == "Gem" then
		profile.Gems = profile.Gems or {}
		table.insert(profile.Gems, copy(payload.Gem))
		return true
	end
	local gearType = gearKind(payload.Slot)
	local c = profile.Character
	profile.Owned[gearType] = profile.Owned[gearType] or {}
	-- Its own key: another copy of a model you have is "Model#2" (Slots.freeKey).
	local key = Slots.freeKey(profile.Owned[gearType], payload.Id)
	profile.Owned[gearType][key] = payload.Quality or 1
	c.GearRolls = c.GearRolls or {}
	c.GearRolls[gearType] = c.GearRolls[gearType] or {}
	c.GearRolls[gearType][key] = copy(payload.Roll)
	c.ItemGems = c.ItemGems or {}
	c.ItemGems[payload.Slot] = c.ItemGems[payload.Slot] or {}
	c.ItemGems[payload.Slot][key] = copy(payload.Gem)
	return true
end

-- Which bag tab an item belongs to: "Gear", "Gems" or "Powers" (cut gems,
-- whose surge can go on Q E R).
function Market.tab(payload): string
	if payload.Kind == "Gear" then
		return "Gear"
	end
	return if payload.Gem and payload.Gem.Cut then "Powers" else "Gems"
end

-- Rarity rank 1..5 for sorting and the "Rare or better" want.
local GEM_RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
function Market.rank(payload): number
	if payload.Kind == "Gem" then
		return GEM_RANK[payload.Gem and payload.Gem.Tier] or 1
	end
	return payload.Roll and payload.Roll.Rarity or 1
end

-- Whether an offered payload fits what a trade listing wants.
function Market.fits(want: string?, payload): boolean
	if want == "Gear" then
		return payload.Kind == "Gear"
	elseif want == "Gems" then
		return payload.Kind == "Gem"
	elseif want == "Rare" then
		return Market.rank(payload) >= 3
	end
	return true
end

return Market
