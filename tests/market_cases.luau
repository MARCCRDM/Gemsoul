-- The Market board: the real MarketBoard and Shared.Market on stand-in
-- players, profiles and saving, with the in-server board. Checks that items
-- leave the bag while listed, sales and trades settle once, races lose
-- cleanly, and no item is ever duplicated or lost.
-- Run: lune run tests/market_cases.luau <repo root>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local now = 100000
local fakeOs = setmetatable({
	time = function()
		return now
	end,
	clock = function()
		return now
	end,
}, { __index = os })

local function signal()
	local fns = {}
	return {
		Connect = function(_, fn)
			table.insert(fns, fn)
		end,
		Fire = function(_, ...)
			for _, fn in fns do
				fn(...)
			end
		end,
	}
end

local spawned = setmetatable({}, { __mode = "k" })
local fakeTask = {
	-- Waits park a spawned thread (the settle loop; nothing here resumes
	-- it) and pass at once on the test's own thread.
	wait = function(s)
		if spawned[coroutine.running()] then
			return coroutine.yield()
		end
		return s or 0.03
	end,
	spawn = function(fn, ...)
		local thread = coroutine.create(fn)
		spawned[thread] = true
		local ok, problem = coroutine.resume(thread, ...)
		assert(ok, problem)
	end,
}

local function load(path, env)
	local src = fs.readFile(ROOT .. "/" .. path)
	env.script = env.script or { Parent = {} }
	local base = {
		require = function(m)
			return m
		end,
		task = fakeTask,
		os = fakeOs,
		math = math,
		table = table,
		string = string,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		type = type,
		typeof = type,
		tostring = tostring,
		tonumber = tonumber,
		pcall = pcall,
		error = error,
		select = select,
		warn = function() end,
		print = print,
		setmetatable = setmetatable,
		Enum = { SortDirection = { Ascending = 1 } },
	}
	for k, v in env do
		base[k] = v
	end
	return luau.load(src, { debugName = path, environment = base })()
end

local Slots = load("src/shared/EquipmentSlots.luau", {})
local Rules = load("src/shared/Market.luau", { script = { Parent = { EquipmentSlots = Slots } } })
local Config = {
	MaxGems = 10,
	MaxGear = 12,
	Features = { Market = true },
	Playtest = { FreshStart = false },
}

-- Players and profiles.
local players, byId = {}, {}
local removing = signal()
local guid = 0
local function newPlayer(id, name)
	local p = { UserId = id, DisplayName = name, Name = name }
	table.insert(players, p)
	byId[id] = p
	return p
end
local Players = {
	GetPlayerByUserId = function(_, id)
		return byId[id]
	end,
	GetPlayers = function()
		return players
	end,
	PlayerRemoving = removing,
	PlayerAdded = signal(),
}
local services = {
	Players = Players,
	ReplicatedStorage = { Shared = { Config = Config, Market = Rules } },
	HttpService = {
		GenerateGUID = function()
			guid += 1
			return string.format("%08d-guid-%04d", guid, guid)
		end,
	},
	MemoryStoreService = {
		GetSortedMap = function()
			error("no memory stores in tests")
		end,
	},
	MessagingService = {
		PublishAsync = function() end,
		SubscribeAsync = function() end,
	},
}
local game = {
	GetService = function(_, name)
		return services[name]
	end,
}

local profiles, saveWorks, canTrade, notes = {}, true, {}, {}
local PlayerData = {
	get = function(p)
		return profiles[p]
	end,
	canTrade = function(p)
		return canTrade[p] ~= false
	end,
	save = function()
		return saveWorks
	end,
	sync = function() end,
	augmentsChanged = function() end,
	milestone = function() end,
 training = function() end,
}
local handlers = {}
local Shop = {
	register = function(name, fn)
		handlers[name] = fn
	end,
	reply = function(ok, message, extra)
		local r = extra or {}
		r.Ok, r.Message = ok, message
		return r
	end,
}
local Remotes = {
	Notify = {
		FireClient = function(_, p, message)
			notes[p] = notes[p] or {}
			table.insert(notes[p], message)
		end,
	},
}
local MarketBoard = load("src/server/Systems/MarketBoard.luau", {
	game = game,
	script = {
		Parent = {
			PlayerData = PlayerData,
			Remotes = Remotes,
			Shop = Shop,
			Equipment = {
				marketPreviews = function()
					return true
				end,
			},
		},
	},
})
MarketBoard.start()

local function gem(id, tier, cut)
	return { Id = id, Element = "Fire", Tier = tier or "Common", Cut = cut }
end
local function profile(coins)
	return {
		Coins = coins,
		Gems = {},
		Owned = { Weapons = {}, Armors = {}, Helmets = {}, Gloves = {}, Boots = {}, Shields = {} },
		Character = {
			Weapon = "W0",
			GearRolls = { Weapons = {} },
			ItemGems = { Weapon = {} },
		},
	}
end

local ann, bob, cat = newPlayer(1, "Ann"), newPlayer(2, "Bob"), newPlayer(3, "Cat")
profiles[ann], profiles[bob], profiles[cat] = profile(500), profile(1000), profile(1000)
table.insert(profiles[ann].Gems, gem("ruby", "Rare", 3))
table.insert(profiles[ann].Gems, gem("pebble"))
profiles[ann].Owned.Weapons.W0 = 1 -- worn
profiles[ann].Owned.Weapons.W7 = 3
profiles[ann].Character.GearRolls.Weapons.W7 = { Rarity = 4, Stats = { Power = 9 } }
profiles[ann].Character.ItemGems.Weapon.W7 = gem("socketed", "Uncommon", 2)
table.insert(profiles[bob].Gems, gem("sapphire", "Uncommon", 1))
table.insert(profiles[cat].Gems, gem("emerald", "Legendary", 4))
profiles[cat].Owned.Weapons.W9 = 2

local function call(p, action, ...)
	now += 1
	return handlers[action](p, ...)
end
local function has(p, id)
	for _, g in profiles[p].Gems do
		if g.Id == id then
			return true
		end
	end
	return false
end
local function escrowCount(p)
	local n = 0
	for _ in profiles[p].Market and profiles[p].Market.Escrow or {} do
		n += 1
	end
	return n
end
-- Every gem id is in exactly one player's hands (bag, socket, gear or
-- escrow), and the number of pieces of each gear model never changes.
local function census()
	local seen = {}
	for _, p in players do
		local prof, mine = profiles[p], {}
		local function gemAt(g)
			if type(g) == "table" and g.Id then
				mine[g.Id] = true
			end
		end
		local function gear(model)
			model = Slots.model(model)
			seen["gear:" .. model] = (seen["gear:" .. model] or 0) + 1
		end
		for _, g in prof.Gems do
			gemAt(g)
		end
		for _, entry in prof.Market and prof.Market.Escrow or {} do
			if entry.Item.Kind == "Gem" then
				gemAt(entry.Item.Gem)
			else
				gear(entry.Item.Id)
				gemAt(entry.Item.Gem)
			end
		end
		for key, value in prof.Character do
			if type(key) == "string" and string.sub(key, -3) == "Gem" then
				gemAt(value)
			end
		end
		for _, list in prof.Character.ItemGems or {} do
			for _, g in list do
				gemAt(g)
			end
		end
		for _, owned in prof.Owned do
			for key in owned do
				gear(key)
			end
		end
		for id in mine do
			check(not seen[id], "gem duplicated: " .. id)
			seen[id] = true
		end
	end
	return seen
end
local everything = census()
local function conserved(where)
	local seen = census()
	for id, v in everything do
		check(seen[id] == v, where .. ": item lost or changed: " .. id)
	end
	for id in seen do
		check(everything[id] ~= nil, where .. ": item appeared: " .. id)
	end
end

-- 1. Listing a gem for coins: it leaves the bag and waits in escrow.
local r = call(ann, "MarketList", "Gem", nil, "ruby", "Sell", 200)
check(r.Ok, "list ruby: " .. tostring(r.Message))
check(not has(ann, "ruby"), "a listed gem leaves the bag")
check(escrowCount(ann) == 1, "the listed gem is in escrow")
local board = call(cat, "MarketBrowse").Listings
check(#board == 1 and board[1].Price == 200 and board[1].SellerName == "Ann", "the board shows the listing")
local rubyListing = board[1].Id
conserved("after listing")

-- Bad listings.
check(not call(ann, "MarketList", "Gem", nil, "ruby", "Sell", 50).Ok, "can't list a gem twice")
check(not call(ann, "MarketList", "Gear", "Weapon", "W0", "Sell", 50).Ok, "can't list worn gear")
check(not call(ann, "MarketList", "Gem", nil, "pebble", "Sell", 0).Ok, "price must be at least 1")
check(not call(ann, "MarketList", "Gem", nil, "pebble", "Sell", 1.5).Ok, "price must be whole")
check(not call(ann, "MarketList", "Gem", nil, "nope", "Sell", 5).Ok, "can't list what you don't have")
check(has(ann, "pebble"), "refused listings leave the bag alone")

-- 2. Buying: own listing refused, too poor refused, then a real sale.
check(not call(ann, "MarketBuy", rubyListing).Ok, "can't buy your own listing")
profiles[bob].Coins = 150
check(not call(bob, "MarketBuy", rubyListing).Ok and profiles[bob].Coins == 150, "too poor: refused, coins kept")
profiles[bob].Coins = 1000
r = call(bob, "MarketBuy", rubyListing)
check(r.Ok, "bob buys the ruby: " .. tostring(r.Message))
check(has(bob, "ruby") and profiles[bob].Coins == 800, "bob has the ruby and paid 200")
-- Ann was settled straight away (same server): paid minus tax, escrow empty.
check(profiles[ann].Coins == 500 + Rules.payout(200) and escrowCount(ann) == 0, "ann paid out once, after tax")
check(Rules.payout(200) == 190, "5% tax")
MarketBoard.reconcile(ann)
check(profiles[ann].Coins == 690, "settling again pays nothing more")
-- A late second buyer loses cleanly.
r = call(cat, "MarketBuy", rubyListing)
check(not r.Ok and profiles[cat].Coins == 1000, "second buyer: refused, coins kept")
conserved("after the sale")

-- 3. Gear for coins, carrying its roll and socketed gem; cancel brings it home.
r = call(ann, "MarketList", "Gear", "Weapon", "W7", "Sell", 300)
check(r.Ok, "list W7")
check(profiles[ann].Owned.Weapons.W7 == nil and profiles[ann].Character.ItemGems.Weapon.W7 == nil, "gear leaves")
local w7 = call(cat, "MarketBrowse").Listings[1]
check(w7.Item.Roll.Rarity == 4 and w7.Item.Gem == nil, "the roll travels with the gear, the gem doesn't")
check(has(ann, "socketed"), "listing gear put its gem back in the seller's bag")
r = call(ann, "MarketCancel", w7.Id)
check(r.Ok and profiles[ann].Owned.Weapons.W7 == 3, "cancel: the gear is back")
check(profiles[ann].Character.GearRolls.Weapons.W7.Rarity == 4, "cancel: its roll is back")
check(
	profiles[ann].Character.ItemGems.Weapon.W7 == nil and has(ann, "socketed"),
	"cancel: gear empty, gem stays in the bag"
)
check(not call(bob, "MarketBuy", w7.Id).Ok, "a cancelled listing can't be bought")
check(#call(bob, "MarketBrowse").Listings == 0, "the board is empty again")
conserved("after cancel")

-- 4. Trade: Ann wants gems for W7; Cat offers gear (refused), then a gem;
-- Bob offers a gem too. Ann accepts Cat's; Bob's comes home.
r = call(ann, "MarketList", "Gear", "Weapon", "W7", "Trade", "Gems")
check(r.Ok, "list W7 for trade")
local trade = call(cat, "MarketBrowse").Listings[1]
check(trade.Mode == "Trade" and trade.Want == "Gems", "trade listing on the board")
check(not call(cat, "MarketBuy", trade.Id).Ok, "trade listings can't be bought for coins")
check(not call(cat, "MarketOffer", trade.Id, "Gear", "Weapon", "W9").Ok, "offer must fit the want")
check(profiles[cat].Owned.Weapons.W9 == 2, "a refused offer stays in the bag")
r = call(cat, "MarketOffer", trade.Id, "Gem", nil, "emerald")
check(r.Ok and not has(cat, "emerald"), "cat's offer goes into escrow")
check(not call(cat, "MarketOffer", trade.Id, "Gem", nil, "emerald").Ok, "one offer per listing")
r = call(bob, "MarketOffer", trade.Id, "Gem", nil, "sapphire")
check(r.Ok and not has(bob, "sapphire"), "bob's offer goes into escrow")
trade = call(ann, "MarketBrowse").Listings[1]
check(#trade.Offers == 2, "both offers on the listing")
conserved("with offers out")
local catOffer
for _, o in trade.Offers do
	if o.FromName == "Cat" then
		catOffer = o.Id
	end
end
check(not call(bob, "MarketAccept", trade.Id, catOffer).Ok, "only the seller accepts")
r = call(ann, "MarketAccept", trade.Id, catOffer)
check(r.Ok and has(ann, "emerald"), "ann gets the emerald")
check(profiles[cat].Owned.Weapons.W7 == 3 and escrowCount(cat) == 0, "cat got W7 (settled at once)")
check(profiles[cat].Character.ItemGems.Weapon.W7 == nil, "W7 arrived with an empty socket")
check(has(ann, "socketed"), "W7's old gem stayed with ann")
check(has(bob, "sapphire") and escrowCount(bob) == 0, "bob's offer came home")
check(not call(bob, "MarketWithdraw", trade.Id).Ok, "nothing left to withdraw")
conserved("after the trade")

-- 5. Withdraw and decline.
-- A socketed gem can be listed: it comes out of its socket (one put in
-- Cat's spare W7 here).
profiles[cat].Character.ItemGems.Weapon.W7 = gem("spare", "Uncommon", 2)
everything = census() -- (a gem added by hand)
r = call(cat, "MarketList", "Gem", nil, "spare", "Trade", "Any")
check(r.Ok, "a socketed gem can be listed: " .. tostring(r.Message))
check(profiles[cat].Character.ItemGems.Weapon.W7 == nil and profiles[cat].Owned.Weapons.W7 == 3, "gem out, gear kept")
local sock = call(ann, "MarketBrowse").Listings
for _, row in sock do
	if row.Item.Kind == "Gem" and row.Item.Gem.Id == "spare" then
		check(call(cat, "MarketCancel", row.Id).Ok, "cancel the socketed gem listing")
	end
end
check(has(cat, "spare"), "cancelled: the gem comes home to the bag")
-- Gems on Q/E/R (surge sockets) and in worn gear list too.
profiles[cat].Character.Surge1Gem = gem("onq", "Rare", 2)
profiles[cat].Character.Weapon = "W9"
profiles[cat].Character.WeaponGem = gem("worn", "Common", 1)
profiles[cat].Character.ItemGems.Weapon.W9 = profiles[cat].Character.WeaponGem
everything = census() -- (two gems added by hand)
check(call(cat, "MarketList", "Gem", nil, "onq", "Sell", 7).Ok, "a gem on Q can be listed")
check(profiles[cat].Character.Surge1Gem == nil, "it left the Q socket")
check(call(cat, "MarketList", "Gem", nil, "worn", "Sell", 7).Ok, "a gem in worn gear can be listed")
check(profiles[cat].Character.WeaponGem == nil and profiles[cat].Character.ItemGems.Weapon.W9 == nil, "socket emptied")
for _, row in call(cat, "MarketBrowse").Listings do
	if row.Seller == 3 then
		call(cat, "MarketCancel", row.Id)
	end
end
check(has(cat, "onq") and has(cat, "worn"), "both home in the bag")
r = call(bob, "MarketList", "Gem", nil, "sapphire", "Trade", "Any")
check(r.Ok, "bob lists sapphire for trade")
local sap = call(cat, "MarketBrowse").Listings[1]
check(call(cat, "MarketOffer", sap.Id, "Gem", nil, "ruby").Ok == false, "cat has no ruby")
check(call(ann, "MarketOffer", sap.Id, "Gem", nil, "pebble").Ok, "ann offers pebble")
check(call(ann, "MarketWithdraw", sap.Id).Ok and has(ann, "pebble"), "withdraw brings it home")
check(call(ann, "MarketOffer", sap.Id, "Gem", nil, "pebble").Ok, "ann offers again")
sap = call(bob, "MarketBrowse").Listings[1]
check(call(bob, "MarketDecline", sap.Id, sap.Offers[1].Id).Ok, "bob declines")
check(has(ann, "pebble") and escrowCount(ann) == 0, "declined: pebble home (settled at once)")
conserved("after decline")

-- 6. Expiry: the listing ends unsold and comes home; nobody can buy it.
now += Rules.ListingSeconds + 5
check(#call(cat, "MarketBrowse").Listings == 0, "expired listings leave the board")
check(not call(cat, "MarketOffer", sap.Id, "Gem", nil, "emerald").Ok, "can't offer on an expired listing")
MarketBoard.reconcile(bob)
check(has(bob, "sapphire") and escrowCount(bob) == 0, "expired: sapphire home")
conserved("after expiry")

-- 7. Saving down: nothing goes up and the item stays.
saveWorks = false
r = call(ann, "MarketList", "Gem", nil, "pebble", "Sell", 10)
check(not r.Ok and has(ann, "pebble") and escrowCount(ann) == 0, "no save, no listing")
saveWorks = true
canTrade[ann] = false
check(not call(ann, "MarketList", "Gem", nil, "pebble", "Sell", 10).Ok, "no working save: refused")
Config.Playtest.FreshStart = true
check(call(ann, "MarketList", "Gem", nil, "pebble", "Sell", 10).Ok, "practice mode (fresh start) works")
Config.Playtest.FreshStart = false
canTrade[ann] = nil
conserved("at the end")

-- 8. Copies: buying a model you already own gives you a second copy.
profiles[bob].Owned.Weapons.W9 = 1
profiles[bob].Character.GearRolls.Weapons.W9 = { Rarity = 1 }
profiles[cat].Character.Weapon = "W0"
profiles[cat].Owned.Weapons.W0 = 1
profiles[cat].Character.GearRolls.Weapons.W9 = { Rarity = 3 }
everything = census() -- (gear added by hand)
r = call(cat, "MarketList", "Gear", "Weapon", "W9", "Sell", 40)
check(r.Ok, "list W9: " .. tostring(r.Message))
local w9
for _, row in call(bob, "MarketBrowse").Listings do
	if row.Item.Id == "W9" then
		w9 = row
	end
end
r = call(bob, "MarketBuy", w9.Id)
check(r.Ok, "bob buys a model he already owns: " .. tostring(r.Message))
check(
	profiles[bob].Owned.Weapons.W9 == 1 and profiles[bob].Owned.Weapons["W9#2"] == 2,
	"his first copy stays, the new one is W9#2"
)
check(profiles[bob].Character.GearRolls.Weapons["W9#2"] ~= nil, "the copy keeps its own roll")
conserved("after buying a copy")
-- And a copy can be listed and bought back by someone who has the model.
r = call(bob, "MarketList", "Gear", "Weapon", "W9#2", "Sell", 40)
check(r.Ok, "list the copy")
for _, row in call(cat, "MarketBrowse").Listings do
	if row.Item.Id == "W9#2" then
		check(call(cat, "MarketBuy", row.Id).Ok, "cat buys it back")
	end
end
check(profiles[cat].Owned.Weapons.W9 == 2, "it arrives as W9 when the key is free")
conserved("after the copy came back")

-- 9. Limits.
for i = 1, Rules.MaxListings + 1 do
	table.insert(profiles[cat].Gems, gem("lot" .. i))
end
everything = census()
local listed = 0
for i = 1, Rules.MaxListings + 1 do
	if call(cat, "MarketList", "Gem", nil, "lot" .. i, "Sell", 5).Ok then
		listed += 1
	end
end
check(listed == Rules.MaxListings, "listing cap")
conserved("after the cap")

-- 11. Audit: a board we can make misbehave the way MemoryStores can.
local function fakeBoard()
	local rows, hooks = {}, {}
	local b = { Shared = true, Hooks = hooks, Rows = rows }
	function b.get(id)
		local row = rows[id]
		return row and Rules.copy(row)
	end
	function b.update(id, fn)
		if hooks.failBefore then
			hooks.failBefore = nil
			error("board unavailable")
		end
		if hooks.retry then
			-- MemoryStores may run a transform on a stale copy, then again.
			local interfere = hooks.retry
			hooks.retry = nil
			fn(rows[id] and Rules.copy(rows[id]))
			interfere(id)
		end
		local result = fn(rows[id] and Rules.copy(rows[id]))
		if result ~= nil then
			rows[id] = Rules.copy(result)
		end
		if hooks.failAfter then
			hooks.failAfter = nil
			error("board unavailable (after writing)")
		end
		return result
	end
	function b.remove(id)
		rows[id] = nil
	end
	function b.range(count)
		local ids = {}
		for id in rows do
			table.insert(ids, id)
		end
		table.sort(ids)
		local out = {}
		for i = 1, math.min(count, #ids) do
			table.insert(out, Rules.copy(rows[ids[i]]))
		end
		return out
	end
	return b
end
local fb = fakeBoard()
MarketBoard.useBoard(fb)
for _, p in players do
	MarketBoard.reconcile(p) -- (the old board's listings come home)
end
everything = census()
local dan = newPlayer(4, "Dan")
profiles[dan] = profile(1000)
table.insert(profiles[dan].Gems, gem("opal", "Rare", 4))
table.insert(profiles[dan].Gems, gem("jade", "Uncommon", 2))
profiles[ann].Coins, profiles[bob].Coins = 1000, 1000
everything = census()
local function listingOf(itemId)
	for id, row in fb.Rows do
		if row.Item.Kind == "Gem" and row.Item.Gem.Id == itemId and row.State == "Open" then
			return id
		end
	end
	return nil
end

-- 11a. A buyer who loses on the transform's second run is not told they won.
check(call(dan, "MarketList", "Gem", nil, "opal", "Sell", 100).Ok, "dan lists opal")
local opal = listingOf("opal")
fb.Hooks.retry = function(id)
	fb.Rows[id].State = "Sold"
	fb.Rows[id].Buyer, fb.Rows[id].BuyerName = 3, "Cat"
end
r = call(bob, "MarketBuy", opal)
check(not r.Ok, "the buyer who lost the race is refused")
check(profiles[bob].Coins == 1000 and not has(bob, "opal"), "...keeps his coins, gets no copy")
fb.Rows[opal].State, fb.Rows[opal].Buyer = "Open", nil -- (undo the stand-in buyer)

-- 11b. The server goes quiet before the sale is written: coins come back.
fb.Hooks.failBefore = true
r = call(bob, "MarketBuy", opal)
check(not r.Ok and profiles[bob].Coins == 900, "no answer: the coins wait in escrow")
MarketBoard.reconcile(bob)
check(profiles[bob].Coins == 1000 and not has(bob, "opal"), "settling up returns the coins")
check(escrowCount(bob) == 0, "nothing left in escrow")

-- 11c. ...after the sale is written: the item arrives on settling up.
fb.Hooks.failAfter = true
r = call(bob, "MarketBuy", opal)
check(not r.Ok and profiles[bob].Coins == 900 and not has(bob, "opal"), "no answer: coins held, no item yet")
MarketBoard.reconcile(bob)
check(has(bob, "opal") and profiles[bob].Coins == 900, "settling up delivers the item, paid once")
MarketBoard.reconcile(dan)
check(profiles[dan].Coins == 1000 + Rules.payout(100), "the seller is paid once")
conserved("after a buy the server didn't finish")

-- 11d. An offer on a listing that expires: once the offerer settles, the
-- seller can't accept it any more (no copy of the item).
check(call(dan, "MarketList", "Gem", nil, "jade", "Trade", "Any").Ok, "dan lists jade for trade")
local jade = listingOf("jade")
table.insert(profiles[ann].Gems, gem("amber", "Common", 1))
everything = census()
check(call(ann, "MarketOffer", jade, "Gem", nil, "amber").Ok, "ann offers amber")
local offerId = fb.Rows[jade].Offers[1].Id
now += Rules.ListingSeconds + 10
MarketBoard.reconcile(ann)
check(has(ann, "amber") and escrowCount(ann) == 0, "expired: ann's amber comes home")
check(fb.Rows[jade] == nil, "the expired listing left the board")
r = call(dan, "MarketAccept", jade, offerId)
check(not r.Ok and not has(dan, "amber"), "the seller can't accept after the offer came home")
MarketBoard.reconcile(dan)
check(has(dan, "jade"), "...and his jade comes home too")
conserved("after an expired trade listing")

-- 11e. Accepting right before expiry still works (and only once).
check(call(dan, "MarketList", "Gem", nil, "jade", "Trade", "Any").Ok, "dan lists jade again")
jade = listingOf("jade")
check(call(ann, "MarketOffer", jade, "Gem", nil, "amber").Ok, "ann offers amber again")
offerId = fb.Rows[jade].Offers[1].Id
check(call(dan, "MarketAccept", jade, offerId).Ok and has(dan, "amber"), "accepted in time")
check(not call(dan, "MarketAccept", jade, offerId).Ok, "not twice")
MarketBoard.reconcile(ann)
check(has(ann, "jade") and not has(ann, "amber"), "ann got jade")
conserved("after an accepted trade")

-- 12. A busy board: hundreds of settled rows don't hide an older open listing.
do
	local map, data = {}, {}
	function map:GetAsync(k)
		return data[k] and Rules.copy(data[k])
	end
	function map:UpdateAsync(k, fn)
		local v = fn(data[k] and Rules.copy(data[k]))
		if v ~= nil then
			data[k] = Rules.copy(v)
		end
		return v
	end
	function map:RemoveAsync(k)
		data[k] = nil
	end
	function map:GetRangeAsync(_, count, after)
		local keys = {}
		for k in data do
			if not after or k > after then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		local out = {}
		for i = 1, math.min(count, #keys) do
			table.insert(out, { key = keys[i], value = Rules.copy(data[keys[i]]) })
		end
		return out
	end
	local handlers2 = {}
	local Shop2 = {
		register = function(name, fn)
			handlers2[name] = fn
		end,
		reply = Shop.reply,
	}
	local services2 = table.clone(services)
	services2.MemoryStoreService = {
		GetSortedMap = function()
			return map
		end,
	}
	local Board2 = load("src/server/Systems/MarketBoard.luau", {
		game = {
			GetService = function(_, n)
				return services2[n]
			end,
		},
		script = {
			Parent = {
				PlayerData = PlayerData,
				Remotes = Remotes,
				Shop = Shop2,
				Equipment = {
					marketPreviews = function()
						return true, 0
					end,
				},
			},
		},
	})
	Board2.start()
	data["9000000000_old"] = {
		Id = "9000000000_old",
		State = "Open",
		Expires = now + 3600,
		Mode = "Sell",
		Price = 5,
		Seller = 9,
		Item = { Kind = "Gem", Gem = gem("old") },
		Offers = {},
	}
	for i = 1, 250 do
		local k = string.format("%010d_s%03d", 100 + i, i)
		data[k] = {
			Id = k,
			State = "Sold",
			Expires = now + 3600,
			Mode = "Sell",
			Price = 1,
			Seller = 9,
			Item = { Kind = "Gem", Gem = gem("s" .. i) },
			Offers = {},
		}
	end
	now += 5
	local seen = false
	for _, row in handlers2.MarketBrowse(ann).Listings do
		seen = seen or row.Id == "9000000000_old"
	end
	check(seen, "an open listing behind 250 settled rows is still on the board")
end

-- 13. Finished listings leave the board; what's owed waits in mailboxes.
local function openRows()
	local n, total = 0, 0
	for _, row in fb.Rows do
		total += 1
		if row.State == "Open" then
			n += 1
		end
	end
	return n, total
end
for _, p in players do
	MarketBoard.reconcile(p)
end
local open0, total0 = openRows()
check(open0 == total0, "only open listings are on the board")
-- 13a. A seller who's offline when it sells is paid when they're back.
table.insert(profiles[dan].Gems, gem("pearl", "Rare", 3))
everything = census()
check(call(dan, "MarketList", "Gem", nil, "pearl", "Sell", 60).Ok, "dan lists pearl")
local pearl = listingOf("pearl")
local danCoins = profiles[dan].Coins
table.remove(players, table.find(players, dan))
byId[4] = nil -- (dan logs off)
check(call(bob, "MarketBuy", pearl).Ok and has(bob, "pearl"), "bob buys pearl while dan is away")
check(fb.Rows[pearl] == nil, "the sale left the board at once")
table.insert(players, dan)
byId[4] = dan -- (dan is back)
MarketBoard.reconcile(dan)
check(profiles[dan].Coins == danCoins + Rules.payout(60) and escrowCount(dan) == 0, "dan is paid from his mailbox")
MarketBoard.reconcile(dan)
check(profiles[dan].Coins == danCoins + Rules.payout(60), "...once")
conserved("after an offline sale")
-- 13b. Cancelling a listing that already sold (and left the board) doesn't
-- bring the item back: the mailbox says it sold.
table.insert(profiles[dan].Gems, gem("ruby2", "Rare", 3))
everything = census()
check(call(dan, "MarketList", "Gem", nil, "ruby2", "Sell", 70).Ok, "dan lists ruby2")
local ruby2 = listingOf("ruby2")
table.remove(players, table.find(players, dan))
byId[4] = nil
check(call(bob, "MarketBuy", ruby2).Ok, "bob buys ruby2")
table.insert(players, dan)
byId[4] = dan
danCoins = profiles[dan].Coins
r = call(dan, "MarketCancel", ruby2)
check(not r.Ok and not has(dan, "ruby2"), "too late to cancel: no copy comes back")
check(profiles[dan].Coins == danCoins + Rules.payout(70), "...and dan is paid instead")
conserved("after cancelling a sold listing")
-- 13c. Withdrawing an offer that was already accepted doesn't bring it back.
table.insert(profiles[dan].Gems, gem("onyx", "Rare", 3))
table.insert(profiles[ann].Gems, gem("topaz", "Rare", 3))
everything = census()
check(call(dan, "MarketList", "Gem", nil, "onyx", "Trade", "Any").Ok, "dan lists onyx for trade")
local onyx = listingOf("onyx")
check(call(ann, "MarketOffer", onyx, "Gem", nil, "topaz").Ok, "ann offers topaz")
local topazOffer = fb.Rows[onyx].Offers[1].Id
table.remove(players, table.find(players, ann))
byId[1] = nil -- (ann is away when dan accepts)
check(call(dan, "MarketAccept", onyx, topazOffer).Ok and has(dan, "topaz"), "dan accepts topaz")
check(fb.Rows[onyx] == nil, "the trade left the board")
table.insert(players, ann)
byId[1] = ann
r = call(ann, "MarketWithdraw", onyx)
check(not has(ann, "topaz") and has(ann, "onyx"), "too late to withdraw: ann gets onyx, not topaz back")
check(escrowCount(ann) == 0, "nothing left in ann's escrow")
conserved("after withdrawing an accepted offer")
local open1, total1 = openRows()
check(open1 == total1, "still only open listings on the board")

-- 10. Face to face (Shared.EquipmentTrade): swapping two copies of one model.
local Trade = load("src/shared/EquipmentTrade.luau", { script = { Parent = { EquipmentSlots = Slots } } })
local function owner(weapon, roll)
	return {
		Owned = { Weapons = { [weapon] = 2, W1 = 1 } },
		Character = {
			Weapon = "W1",
			GearRolls = { Weapons = { [weapon] = roll, W1 = {} } },
			ItemGems = { Weapon = {} },
		},
	}
end
local pa, pb = owner("Saber", { Rarity = 5 }), owner("Saber", { Rarity = 1 })
pb.Owned.Weapons["Saber#2"] = 3
pb.Character.GearRolls.Weapons["Saber#2"] = { Rarity = 2 }
local left, right = Trade.item(pa, "Weapon", "Saber"), Trade.item(pb, "Weapon", "Saber#2")
local ok, message = Trade.exchange(pa, pb, left, right)
check(ok, "same-model trade allowed: " .. tostring(message))
check(pa.Owned.Weapons.Saber == 3 and pa.Character.GearRolls.Weapons.Saber.Rarity == 2, "A got B's copy")
check(pb.Owned.Weapons.Saber == 2 and pb.Owned.Weapons["Saber#2"] == 2, "B keeps his Saber and gets A's as Saber#2")
check(pb.Character.GearRolls.Weapons["Saber#2"].Rarity == 5, "with its own roll")
check(Slots.model("Saber#2") == "Saber" and Slots.model("Saber") == "Saber", "model of a key")
check(Slots.freeKey({ Saber = 1, ["Saber#2"] = 1 }, "Saber#2") == "Saber#3", "next free key")

print(
	("PASS: %d Market checks (escrow, sales, tax, races, trades, offers, cancel, expiry, saving, limits, no dupes)"):format(
		checks
	)
)
