--[[
	The Market board, across every server: listings for coins or for trade
	offers (see Shared.Market for the rules and how items move).

	Open listings live in a MemoryStore sorted map, so every server sees the
	same board and a sale is one atomic update (two buyers can never both
	win). The item itself waits in escrow in its owner's saved profile.

	When a listing ends it leaves the board: what each player is owed ("sold
	for 100", "your offer was taken: here's the item") goes to their mailbox
	in a DataStore first (durable, no expiry), and only then is the row
	removed, so the board (whose size Roblox caps by players online) holds
	just what's for sale. A finished row stays only if that bookkeeping
	couldn't finish (a crash); it expires after a week.

	Each player's escrow is settled ("reconcile") when they join, every few
	seconds while they have something up, and right after anything happens
	to their listing (another server nudges them through MessagingService):
	from the row while it's there, else from their mailbox. A settled entry
	leaves escrow in the same profile change that pays out or hands the item
	over, so it can only happen once.

	Requests (Remotes.Request):
	  "MarketBrowse"                         -> { Listings }
	  "MarketList", kind, slot, id, mode, price/want
	        mode "Sell" with a coin price, or "Trade" with a want id
	  "MarketCancel", listingId
	  "MarketBuy", listingId
	  "MarketOffer", listingId, kind, slot, id
	  "MarketWithdraw", listingId
	  "MarketAccept", listingId, offerId
	  "MarketDecline", listingId, offerId
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Market)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)
local Equipment = require(script.Parent.Equipment)

local MarketBoard = {}

local KEEP_SETTLED = 7 * 24 * 3600 -- a finished row left behind by a crash (normally removed at once)
-- (Config.MarketVersion: a new number starts an empty board and mailboxes.)
local VERSION = tostring(Config.MarketVersion or 1)
local TOPIC = "MarketBoard_v" .. VERSION

-- The board -------------------------------------------------------------------

-- In-server board: Studio without API access, and the tests.
local function localBoard()
	local rows = {}
	local board = {}
	function board.get(id)
		local row = rows[id]
		return row and Rules.copy(row)
	end
	function board.update(id, fn)
		local new = fn(rows[id] and Rules.copy(rows[id]))
		if new ~= nil then
			rows[id] = Rules.copy(new)
		end
		return new
	end
	function board.remove(id)
		rows[id] = nil
	end
	function board.range(count)
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
	board.Shared = false
	return board
end

local function memoryBoard()
	local ok, map = pcall(function()
		return game:GetService("MemoryStoreService"):GetSortedMap("MarketBoard_v" .. VERSION)
	end)
	if not ok or not map then
		return nil
	end
	-- One probe: Studio without API access can't reach MemoryStores.
	if not pcall(map.GetAsync, map, "probe") then
		return nil
	end
	local board = {}
	local function ttl(row)
		if row and row.State == "Open" then
			return math.clamp(row.Expires - os.time() + 7 * 24 * 3600, 60, KEEP_SETTLED)
		end
		return KEEP_SETTLED
	end
	function board.get(id)
		local done, value = pcall(map.GetAsync, map, id)
		if not done then
			error("board unavailable")
		end
		return value
	end
	function board.update(id, fn)
		local result = nil
		local done, problem = pcall(function()
			map:UpdateAsync(id, function(old)
				result = fn(old)
				return result
			end, ttl({ State = "Open", Expires = os.time() + Rules.ListingSeconds }))
		end)
		if not done then
			warn("[MarketBoard] update failed: " .. tostring(problem))
			error("board unavailable")
		end
		-- Settled rows keep the longest life (an extra write to stretch it).
		if result and result.State ~= "Open" then
			pcall(function()
				map:UpdateAsync(id, function(old)
					return old
				end, ttl(result))
			end)
		end
		return result
	end
	-- Pages through the board, newest first (settled rows stay for weeks, so
	-- the first page alone could hide older open listings).
	function board.range(count)
		local out, after = {}, nil
		while #out < count do
			local done, items =
				pcall(map.GetRangeAsync, map, Enum.SortDirection.Ascending, math.min(200, count - #out), after)
			if not done then
				error("board unavailable")
			end
			for _, item in items do
				table.insert(out, item.value)
			end
			if #items < 200 then
				break
			end
			after = items[#items].key
		end
		return out
	end
	function board.remove(id)
		pcall(map.RemoveAsync, map, id)
	end
	board.Shared = true
	return board
end

local board = nil
local function getBoard()
	if not board then
		board = memoryBoard() or localBoard()
		if not board.Shared then
			warn("[MarketBoard] MemoryStores unavailable: the board is this server only.")
		end
	end
	return board
end

-- Lets the tests (or a later swap) use another board.
function MarketBoard.useBoard(b)
	board = b
end

-- Mailboxes -------------------------------------------------------------------

-- What a player is owed from listings that ended, by listing id:
--   { Kind = "Sold", Price, BuyerName }          (their listing sold)
--   { Kind = "Traded", Item, FromName }          (they accepted an offer)
--   { Kind = "Accepted", OfferId, Item, SellerName }  (their offer was taken)
--   { Kind = "Bought", Item }                    (their purchase)
local function localMail()
	local boxes = {}
	local m = { Shared = false }
	function m.add(userId, listingId, note)
		boxes[userId] = boxes[userId] or {}
		boxes[userId][listingId] = Rules.copy(note)
		return true
	end
	function m.read(userId)
		return Rules.copy(boxes[userId] or {})
	end
	function m.remove(userId, ids)
		for _, id in ids do
			if boxes[userId] then
				boxes[userId][id] = nil
			end
		end
		return true
	end
	return m
end

local function dataMail()
	local ok, store = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("MarketMail_v" .. VERSION)
	end)
	if not ok or not store then
		return nil
	end
	if not pcall(store.GetAsync, store, "probe") then
		return nil -- (Studio without API access)
	end
	local m = { Shared = true }
	function m.add(userId, listingId, note)
		return (
			pcall(store.UpdateAsync, store, "mail_" .. userId, function(box)
				box = box or {}
				box[listingId] = note
				return box
			end)
		)
	end
	function m.read(userId)
		local done, box = pcall(store.GetAsync, store, "mail_" .. userId)
		if not done then
			error("mailbox unavailable")
		end
		return box or {}
	end
	function m.remove(userId, ids)
		return (
			pcall(store.UpdateAsync, store, "mail_" .. userId, function(box)
				box = box or {}
				for _, id in ids do
					box[id] = nil
				end
				return box
			end)
		)
	end
	return m
end

local mail = nil
local function getMail()
	if not mail then
		mail = dataMail() or localMail()
	end
	return mail
end
function MarketBoard.useMail(m)
	mail = m
end

-- Newest first: ids sort by time left to the year 2286, then a random tail.
local function newId(): string
	return string.format("%010d", 9999999999 - os.time()) .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
end

-- Nudges -----------------------------------------------------------------------

local reconcile -- forward
local function nudge(userId: number?)
	if not userId then
		return
	end
	local here = Players:GetPlayerByUserId(userId)
	if here then
		task.spawn(reconcile, here)
		return
	end
	task.spawn(function()
		pcall(function()
			game:GetService("MessagingService"):PublishAsync(TOPIC, userId)
		end)
	end)
end

local function tell(userId: number?, message: string)
	local here = userId and Players:GetPlayerByUserId(userId)
	if here then
		Remotes.Notify:FireClient(here, message)
	end
end

-- Per-player turns: an action and a settle-up never run at once.
local turns: { [Player]: boolean } = {}
local function withTurn(player: Player, fn)
	local waited = 0
	while turns[player] and waited < 8 do
		waited += task.wait(0.1)
	end
	if turns[player] then
		return Shop.reply(false, "The Market is busy with your last request. Try again.")
	end
	turns[player] = true
	local ok, result = pcall(fn)
	turns[player] = nil
	if not ok then
		warn("[MarketBoard] " .. tostring(result))
		return Shop.reply(false, "The Market can't be reached right now. Nothing changed hands.")
	end
	return result
end

-- Practice mode (Playtest.FreshStart): nothing is saved, so the market runs
-- without saving; otherwise a player whose save isn't working can't use it.
local function practice(): boolean
	return Config.Playtest ~= nil and Config.Playtest.FreshStart == true
end
local function mayTrade(player: Player): boolean
	return practice() or PlayerData.canTrade(player)
end
-- Saves before the item goes up on the board, so a crash can't leave it
-- both listed and still in the bag.
local function persist(player: Player): boolean
	if practice() then
		return true
	end
	for _ = 1, 3 do
		if PlayerData.save(player) then
			return true
		end
		task.wait(1)
	end
	return false
end

local function name(payloadOwner: Player): string
	return payloadOwner.DisplayName
end

local function finishChange(player: Player)
	-- (a gem may have left a socket, or worn gear changed: refresh the character)
	PlayerData.augmentsChanged(player)
	if not practice() then
		task.spawn(PlayerData.save, player)
	end
end

-- Takes a finished listing off the board: first every other party gets a
-- mailbox note of what they're owed, then the row goes. (The caller has
-- already saved its own side.) If a note can't be written the row stays,
-- and everyone settles from it as before.
local function finalize(row, selfId: number?)
	local m = getMail()
	local ok = true
	local function send(userId, note)
		if userId and userId ~= selfId then
			ok = m.add(userId, row.Id, note) and ok
		end
	end
	if row.State == "Sold" then
		send(row.Seller, { Kind = "Sold", Price = row.Price, BuyerName = row.BuyerName, At = os.time() })
		send(row.Buyer, { Kind = "Bought", Item = row.Item, At = os.time() })
	elseif row.State == "Traded" then
		local accepted = nil
		for _, offer in row.Offers or {} do
			if offer.Id == row.Accepted then
				accepted = offer
			end
		end
		if not accepted then
			return false
		end
		send(row.Seller, { Kind = "Traded", Item = accepted.Item, FromName = accepted.FromName, At = os.time() })
		send(
			accepted.From,
			{ Kind = "Accepted", OfferId = accepted.Id, Item = row.Item, SellerName = row.SellerName, At = os.time() }
		)
	end
	-- (Cancelled and expired rows need no notes: whatever is in escrow for
	-- them simply goes home.)
	if ok then
		getBoard().remove(row.Id)
	end
	return ok
end

-- Settling up ------------------------------------------------------------------

-- Settles one player's escrow against the board (or, for listings no
-- longer on it, their mailbox): pays out sales, takes in accepted trades and
-- purchases, hands back what's no longer up.
local prunedThisSession: { [Player]: boolean } = {}
local function settle(player: Player)
	local profile = PlayerData.get(player)
	local escrow = profile and profile.Market and profile.Market.Escrow or {}
	local firstLook = not prunedThisSession[player]
	if next(escrow) == nil and not firstLook then
		return
	end
	local b = getBoard()
	local box = nil -- the mailbox, read only when needed
	local function mailbox()
		if box == nil then
			box = getMail().read(player.UserId)
		end
		return box
	end
	local changed, notes, finished, consumed = false, {}, {}, {}
	local function closeIfExpired(row, listingId)
		if row and row.State == "Open" and os.time() >= row.Expires then
			return b.update(listingId, function(old)
				if old and old.State == "Open" and os.time() >= old.Expires then
					old.State = "Expired"
				end
				return old
			end)
		end
		return row
	end
	for entryId, entry in escrow do
		local listingId = entry.Listing
		local row = b.get(listingId)
		local note = nil
		if not row then
			note = mailbox()[listingId]
			if note then
				table.insert(consumed, listingId)
			end
		end
		local home, got, coins, message = false, nil, 0, nil
		if entry.Role == "Sell" then
			row = closeIfExpired(row, listingId)
			if row and row.Seller ~= player.UserId then
				home = true
			elseif row and row.State == "Open" then
				continue
			elseif (row and row.State == "Sold") or (not row and note and note.Kind == "Sold") then
				local price = if row then row.Price else note.Price
				coins = Rules.payout(price)
				message = string.format(
					"Sold to %s for %d coins (+%d after tax).",
					(if row then row.BuyerName else note.BuyerName) or "a player",
					price,
					coins
				)
			elseif row and row.State == "Traded" then
				for _, offer in row.Offers or {} do
					if offer.Id == row.Accepted then
						got = offer.Item
						message = "Trade complete: you got " .. (offer.FromName or "their") .. "'s item."
					end
				end
				if not got then
					continue -- (a malformed row: leave it for now)
				end
			elseif not row and note and note.Kind == "Traded" then
				got = note.Item
				message = "Trade complete: you got " .. (note.FromName or "their") .. "'s item."
			else
				home = true
			end
		elseif entry.Role == "Offer" then
			-- Close an expired listing first (atomically), so it can't be
			-- accepted after this offer's item has come home.
			row = closeIfExpired(row, listingId)
			local mine = nil
			for _, offer in row and row.Offers or {} do
				if offer.Id == entry.OfferId then
					mine = offer
				end
			end
			if row and row.State == "Traded" and row.Accepted == entry.OfferId then
				got = row.Item
			elseif not row and note and note.Kind == "Accepted" and note.OfferId == entry.OfferId then
				got = note.Item
			elseif row and row.State == "Open" and mine then
				continue
			else
				home = true
			end
			if got then
				message = ((if row then row.SellerName else note.SellerName) or "The seller")
					.. " accepted your offer. Trade complete!"
			end
		elseif entry.Role == "Buy" then
			-- A purchase the server didn't get to finish (a crash): the item
			-- if the claim went through, else the coins back.
			if row and row.State == "Sold" and row.Buyer == player.UserId then
				got = row.Item
			elseif not row and note and note.Kind == "Bought" then
				got = note.Item
			else
				coins = entry.Price or 0
				message = "A purchase didn't go through: your coins are back."
			end
			if got then
				message = "Your purchase arrived: it's in your bag."
			end
		end
		if home then
			got = entry.Item
			message = if entry.Role == "Sell"
				then "A listing ended unsold: the item is back in your bag."
				else "An offer wasn't taken: your item is back in your bag."
		end
		if got then
			Rules.give(profile, got, Config.MaxGems, true)
		end
		profile.Coins += coins
		escrow[entryId] = nil
		changed = true
		if message then
			table.insert(notes, message)
		end
		-- A finished row this player settled from: take it off the board once
		-- they're saved (finalize, below).
		if row and row.State ~= "Open" then
			finished[row.Id] = row
		end
	end
	-- Notes nobody is waiting on any more (already settled from the row, or
	-- from before a rejoin) are cleared the first time we look each session.
	if firstLook then
		prunedThisSession[player] = true
		local ok, all = pcall(mailbox)
		if ok then
			for listingId in all do
				local wanted = escrow["s_" .. listingId] or escrow["o_" .. listingId] or escrow["b_" .. listingId]
				if not wanted and not table.find(consumed, listingId) then
					table.insert(consumed, listingId)
				end
			end
		end
	end
	if changed then
		finishChange(player)
		for _, message in notes do
			Remotes.Notify:FireClient(player, message)
		end
	end
	if next(finished) and persist(player) then
		for _, row in finished do
			finalize(row, player.UserId)
		end
	end
	if #consumed > 0 and (not changed or practice() or persist(player)) then
		getMail().remove(player.UserId, consumed)
	end
end

function reconcile(player: Player)
	if turns[player] or not PlayerData.get(player) then
		return
	end
	turns[player] = true
	local ok, problem = pcall(settle, player)
	turns[player] = nil
	if not ok then
		warn("[MarketBoard] settle failed: " .. tostring(problem))
	end
end
MarketBoard.reconcile = reconcile

-- Requests ---------------------------------------------------------------------

local browseCache, browseAt = nil, -math.huge
local function browse()
	if browseCache and os.clock() - browseAt < 3 then
		return browseCache
	end
	local rows = getBoard().range(1000)
	local open = {}
	for _, row in rows do
		if row.State == "Open" and os.time() < row.Expires then
			table.insert(open, row)
		end
	end
	browseCache, browseAt = open, os.clock()
	return open
end
local function invalidate()
	browseCache = nil
end

local handlers = {}

-- 3D pictures of the gear on the board and of offers on your listings
-- (Equipment.marketPreviews: "Slot|M:<listing>" and "Slot|M:<listing>:<offer>").
function handlers.MarketPreviews(player: Player)
	local items, count = {}, 0
	local function add(tag, payload)
		if payload and payload.Kind == "Gear" and count < 40 then
			items[tag] = payload
			count += 1
		end
	end
	for _, row in browse() do
		add(row.Id, row.Item)
		if row.Seller == player.UserId then
			for _, offer in row.Offers or {} do
				add(row.Id .. ":" .. offer.Id, offer.Item)
			end
		end
	end
	local done, built = Equipment.marketPreviews(player, items)
	return Shop.reply(true, "", { Done = done, Built = built or 0 })
end

function handlers.MarketBrowse(player: Player)
	local rows = require(script.Parent.Intro).tutorialStock(player) or browse()
	return Shop.reply(true, "", { Listings = rows, Shared = getBoard().Shared, Now = os.time() })
end

function handlers.MarketList(player: Player, kind, slot, id, mode, value)
	local profile = PlayerData.get(player)
	if mode ~= "Sell" and mode ~= "Trade" then
		return Shop.reply(false, "Choose to sell or to trade.")
	end
	if mode == "Sell" and not Rules.validPrice(value) then
		return Shop.reply(false, "Set a price from " .. Rules.MinPrice .. " to " .. Rules.MaxPrice .. " coins.")
	end
	if mode == "Trade" and not Rules.WantLabels[value] then
		value = "Any"
	end
	if Rules.count(profile, "Sell") >= Rules.MaxListings then
		return Shop.reply(false, "You can have " .. Rules.MaxListings .. " listings up at once.")
	end
	local why = Rules.whyNot(profile, kind, slot, id)
	if why then
		return Shop.reply(false, why)
	end
	local listingId = newId()
	local payload = Rules.take(profile, kind, slot, id)
	local entryId = "s_" .. listingId
	Rules.escrow(profile)[entryId] = { Role = "Sell", Listing = listingId, Item = payload, At = os.time() }
	if not persist(player) then
		-- Never went up: straight back to the bag.
		Rules.escrow(profile)[entryId] = nil
		Rules.give(profile, payload, Config.MaxGems, true)
		finishChange(player)
		return Shop.reply(false, "Your save couldn't be reached, so nothing was listed.")
	end
	local row = {
		Id = listingId,
		Seller = player.UserId,
		SellerName = name(player),
		Mode = mode,
		Price = if mode == "Sell" then value else nil,
		Want = if mode == "Trade" then value else nil,
		Item = payload,
		Created = os.time(),
		Expires = os.time() + Rules.ListingSeconds,
		State = "Open",
		Offers = {},
	}
	local ok = pcall(getBoard().update, listingId, function()
		return row
	end)
	if not ok then
		Rules.escrow(profile)[entryId] = nil
		Rules.give(profile, payload, Config.MaxGems, true)
		finishChange(player)
		return Shop.reply(false, "The Market can't be reached right now. Your item is back in your bag.")
	end
	invalidate()
	finishChange(player)
	return Shop.reply(
		true,
		if mode == "Sell"
			then string.format("Listed for %d coins. It's out of your bag until it sells or you cancel.", value)
			else "Listed for trade. Offers will show under My Listings."
	)
end

function handlers.MarketCancel(player: Player, listingId)
	local profile = PlayerData.get(player)
	local entryId = "s_" .. tostring(listingId)
	local entry = Rules.escrow(profile)[entryId]
	if not entry then
		return Shop.reply(false, "That listing isn't yours.")
	end
	local row = getBoard().update(listingId, function(old)
		if old and old.State == "Open" and old.Seller == player.UserId then
			old.State = "Cancelled"
		end
		return old
	end)
	if not row or (row.State ~= "Cancelled" and row.State ~= "Expired") then
		-- Off the board already, or it sold / traded just now: settle what
		-- really happened (the mailbox knows) instead.
		settle(player)
		invalidate()
		local still = Rules.escrow(profile)[entryId]
		return Shop.reply(
			false,
			if still then "Try again in a moment." else "That listing already ended (see your messages)."
		)
	end
	Rules.escrow(profile)[entryId] = nil
	Rules.give(profile, entry.Item, Config.MaxGems, true)
	invalidate()
	finishChange(player)
	getBoard().remove(listingId) -- (offers on it simply go home)
	for _, offer in row.Offers or {} do
		nudge(offer.From)
	end
	return Shop.reply(true, "Listing cancelled. The item is back in your bag.")
end

function handlers.MarketBuy(player: Player, listingId)
 if type(listingId) == "string" and string.sub(listingId, 1, 9) == "Tutorial:" then
  return require(script.Parent.Intro).tutorialBuy(player, listingId)
 end
	local profile = PlayerData.get(player)
	if typeof(listingId) ~= "string" then
		return Shop.reply(false, "Pick a listing.")
	end
	local b = getBoard()
	local row = b.get(listingId)
	if not row or row.State ~= "Open" or os.time() >= row.Expires or row.Mode ~= "Sell" then
		invalidate()
		return Shop.reply(false, "That listing is gone.")
	end
	if row.Seller == player.UserId then
		return Shop.reply(false, "That's your own listing.")
	end
	if profile.Coins < row.Price then
		return Shop.reply(false, string.format("You need %d coins.", row.Price))
	end
	local why = Rules.cantReceive(profile, row.Item, Config.MaxGems, Config.MaxGear)
	if why then
		return Shop.reply(false, why)
	end
	-- The coins wait in escrow (saved) while the claim runs: if the server
	-- stops mid-way, settling up delivers the item or gives the coins back.
	local escrow = Rules.escrow(profile)
	local entryId = "b_" .. listingId
	if escrow[entryId] then
		return Shop.reply(false, "That purchase is already going through.")
	end
	profile.Coins -= row.Price
	escrow[entryId] = { Role = "Buy", Listing = listingId, Price = row.Price, At = os.time() }
	local function refund(message)
		escrow[entryId] = nil
		profile.Coins += row.Price
		finishChange(player)
		invalidate()
		return Shop.reply(false, message)
	end
	if not persist(player) then
		return refund("Your save couldn't be reached, so nothing was bought.")
	end
	local won = false
	local reached, claimed = pcall(b.update, listingId, function(old)
		won = false
		if old and old.State == "Open" and os.time() < old.Expires and old.Price == row.Price then
			old.State = "Sold"
			old.Buyer = player.UserId
			old.BuyerName = name(player)
			old.SoldAt = os.time()
			won = true
		end
		return old
	end)
	if not reached then
		-- Unknown whether it went through: settling up (in a few seconds)
		-- finds out and delivers the item or returns the coins.
		finishChange(player)
		return Shop.reply(
			false,
			"The Market didn't answer. If the purchase went through it arrives shortly; if not, your coins come back."
		)
	end
	if not won or not claimed then
		return refund("Someone else bought it first. Your coins weren't spent.")
	end
	escrow[entryId] = nil
	Rules.give(profile, claimed.Item, Config.MaxGems, true)
	PlayerData.milestone(player, "Traded")
	invalidate()
	finishChange(player)
	-- Saved with the item, the sale comes off the board (the seller's
	-- payout waits in their mailbox).
	if persist(player) then
		finalize(claimed, player.UserId)
	end
	nudge(claimed.Seller)
	for _, offer in claimed.Offers or {} do
		nudge(offer.From)
	end
	tell(claimed.Seller, string.format("%s bought your listing for %d coins.", name(player), claimed.Price))
	return Shop.reply(true, string.format("Bought for %d coins. It's in your bag.", claimed.Price))
end

function handlers.MarketOffer(player: Player, listingId, kind, slot, id)
	local profile = PlayerData.get(player)
	if typeof(listingId) ~= "string" then
		return Shop.reply(false, "Pick a listing.")
	end
	local b = getBoard()
	local row = b.get(listingId)
	if not row or row.State ~= "Open" or os.time() >= row.Expires or row.Mode ~= "Trade" then
		invalidate()
		return Shop.reply(false, "That listing is gone.")
	end
	if row.Seller == player.UserId then
		return Shop.reply(false, "That's your own listing.")
	end
	if Rules.escrow(profile)["o_" .. listingId] then
		return Shop.reply(false, "You already have an offer on this. Withdraw it to offer something else.")
	end
	if Rules.count(profile, "Offer") >= Rules.MaxOffersOut then
		return Shop.reply(false, "You can have " .. Rules.MaxOffersOut .. " offers out at once.")
	end
	if #(row.Offers or {}) >= Rules.MaxOffers then
		return Shop.reply(false, "That listing has all the offers it can take.")
	end
	local why = Rules.whyNot(profile, kind, slot, id)
		or Rules.cantReceive(profile, row.Item, Config.MaxGems, Config.MaxGear)
	if why then
		return Shop.reply(false, why)
	end
	local preview = Rules.take(Rules.copy(profile), kind, slot, id)
	if not Rules.fits(row.Want, preview) then
		return Shop.reply(
			false,
			"They're after " .. string.lower(Rules.WantLabels[row.Want] or "something else") .. "."
		)
	end
	local payload = Rules.take(profile, kind, slot, id)
	local offerId = string.sub(HttpService:GenerateGUID(false), 1, 12)
	local entryId = "o_" .. listingId
	Rules.escrow(profile)[entryId] =
		{ Role = "Offer", Listing = listingId, OfferId = offerId, Item = payload, At = os.time() }
	local function undo(message)
		Rules.escrow(profile)[entryId] = nil
		Rules.give(profile, payload, Config.MaxGems, true)
		finishChange(player)
		return Shop.reply(false, message)
	end
	if not persist(player) then
		return undo("Your save couldn't be reached, so no offer was made.")
	end
	local added = false
	local ok, updated = pcall(b.update, listingId, function(old)
		added = false
		if old and old.State == "Open" and os.time() < old.Expires and #(old.Offers or {}) < Rules.MaxOffers then
			old.Offers = old.Offers or {}
			table.insert(
				old.Offers,
				{ Id = offerId, From = player.UserId, FromName = name(player), Item = payload, At = os.time() }
			)
			added = true
		end
		return old
	end)
	if not ok or not added then
		return undo("That listing just closed. Your item is back in your bag.")
	end
	invalidate()
	finishChange(player)
	tell(updated.Seller, name(player) .. " made an offer on your listing. See My Listings.")
	return Shop.reply(true, "Offer sent. Your item waits in escrow until they answer.")
end

function handlers.MarketWithdraw(player: Player, listingId)
	local profile = PlayerData.get(player)
	local entryId = "o_" .. tostring(listingId)
	local entry = Rules.escrow(profile)[entryId]
	if not entry then
		return Shop.reply(false, "No offer of yours there.")
	end
	local removed = false
	local row = getBoard().update(listingId, function(old)
		removed = false
		if old and old.State == "Open" then
			for i, offer in old.Offers or {} do
				if offer.Id == entry.OfferId then
					table.remove(old.Offers, i)
					removed = true
					break
				end
			end
		end
		return old
	end)
	if not removed then
		-- Accepted, closed or off the board: settle what really happened
		-- (it may have been accepted: the mailbox knows).
		settle(player)
		invalidate()
		if Rules.escrow(profile)[entryId] then
			return Shop.reply(false, "Try again in a moment.")
		end
		return Shop.reply(true, "That listing already ended (see your messages).")
	end
	Rules.escrow(profile)[entryId] = nil
	Rules.give(profile, entry.Item, Config.MaxGems, true)
	invalidate()
	finishChange(player)
	return Shop.reply(true, "Offer withdrawn. Your item is back in your bag.")
end

function handlers.MarketAccept(player: Player, listingId, offerId)
	local profile = PlayerData.get(player)
	local entryId = "s_" .. tostring(listingId)
	local entry = Rules.escrow(profile)[entryId]
	if not entry or typeof(offerId) ~= "string" then
		return Shop.reply(false, "That listing isn't yours.")
	end
	local b = getBoard()
	local row = b.get(listingId)
	local offer = nil
	for _, o in row and row.Offers or {} do
		if o.Id == offerId then
			offer = o
		end
	end
	if not row or row.State ~= "Open" or os.time() >= row.Expires or not offer then
		return Shop.reply(false, "That offer is gone (or the listing has ended).")
	end
	local why = Rules.cantReceive(profile, offer.Item, Config.MaxGems, Config.MaxGear)
	if why then
		return Shop.reply(false, why)
	end
	local won = false
	local done = b.update(listingId, function(old)
		won = false
		if old and old.State == "Open" and os.time() < old.Expires and old.Seller == player.UserId then
			for _, o in old.Offers or {} do
				if o.Id == offerId then
					old.State = "Traded"
					old.Accepted = offerId
					old.Buyer = o.From
					old.BuyerName = o.FromName
					won = true
				end
			end
		end
		return old
	end)
	if not won or not done then
		return Shop.reply(false, "That offer is gone.")
	end
	Rules.escrow(profile)[entryId] = nil
	Rules.give(profile, offer.Item, Config.MaxGems, true)
	PlayerData.milestone(player, "Traded")
	invalidate()
	finishChange(player)
	-- Saved with the offered item, the trade comes off the board (the
	-- offerer's new item waits in their mailbox; other offers go home).
	if persist(player) then
		finalize(done, player.UserId)
	end
	for _, o in done.Offers or {} do
		nudge(o.From)
	end
	return Shop.reply(true, "Trade accepted! " .. (offer.FromName or "Their") .. "'s item is in your bag.")
end

function handlers.MarketDecline(player: Player, listingId, offerId)
	local profile = PlayerData.get(player)
	if not Rules.escrow(profile)["s_" .. tostring(listingId)] then
		return Shop.reply(false, "That listing isn't yours.")
	end
	local from = nil
	getBoard().update(listingId, function(old)
		from = nil
		if old and old.State == "Open" and old.Seller == player.UserId then
			for i, o in old.Offers or {} do
				if o.Id == offerId then
					from = o.From
					table.remove(old.Offers, i)
					break
				end
			end
		end
		return old
	end)
	invalidate()
	nudge(from)
	return Shop.reply(true, "Offer declined. Their item goes back to them.")
end

function MarketBoard.start()
	local closed = Config.Features and Config.Features.Market == false
	for action, handler in handlers do
		Shop.register(action, function(player, ...)
			if closed then
				return Shop.reply(false, "The Market is closed for this playtest.")
			end
			if action ~= "MarketBrowse" and action ~= "MarketPreviews" and not mayTrade(player) then
				return Shop.reply(false, "The Market needs your save to be working. Rejoin and try again.")
			end
			-- Looking (and building pictures) changes nothing: no turn needed.
			if action == "MarketBrowse" or action == "MarketPreviews" then
				return handler(player, ...)
			end
			local args = table.pack(...)
			return withTurn(player, function()
				return handler(player, table.unpack(args, 1, args.n))
			end)
		end)
	end
	-- Other servers nudge us when something happened to a player here.
	task.spawn(function()
		pcall(function()
			game:GetService("MessagingService"):SubscribeAsync(TOPIC, function(message)
				local here = Players:GetPlayerByUserId(tonumber(message.Data) or 0)
				if here then
					reconcile(here)
				end
			end)
		end)
	end)
	-- And settle everyone with something in escrow every few seconds.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local profile = PlayerData.get(player)
				if profile and profile.Market and next(profile.Market.Escrow or {}) then
					task.spawn(reconcile, player)
				end
			end
		end
	end)
	-- A first settle when someone joins (escrow, and old mailbox notes).
	Players.PlayerAdded:Connect(function(player)
		for _ = 1, 30 do
			if PlayerData.get(player) or not player.Parent then
				break
			end
			task.wait(1)
		end
		reconcile(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		turns[player] = nil
		prunedThisSession[player] = nil
	end)
end

return MarketBoard
