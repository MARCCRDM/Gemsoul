--[[
	Ranked win streaks and their Arena Caches (Shared.ArenaStreak has the
	milestones and rules).

	Duels calls ArenaStreaks.onRankedResult after every Ranked 1v1. A win
	adds to the streak (not over the same player twice running), a loss
	ends it. Reaching a milestone pays its coins and title at once and opens
	an Arena Cache: free gems and six pieces of Rare and Ultra-Rare gear,
	rolled now and saved with the player (profile.Duel.StreakCaches), to
	claim whenever they like. Claiming gives every gem and the
	ArenaStreak.Picks pieces of gear chosen; the other gear goes up on the
	Market from the Arena Vault (MarketBoard.vaultList), with a commission
	for the player on each sale (paid through the Market's mailbox). A
	leftover the Market couldn't take right then waits (Duel.VaultPending)
	and goes up later.

	Requests (Remotes.Request):
	  "StreakCaches"                     -> { Caches, Streak, Best, Next }
	  "StreakClaim", cacheId, { offerId, ... }   keep these (gear), vault the rest
	The Social remote tells the player:
	  "StreakReward", { Wins, Name, Coins, Title }   a cache just opened
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Market = require(ReplicatedStorage.Shared.Market)
local Season = require(ReplicatedStorage.Shared.Season)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemGenerator = require(script.Parent.GemGenerator)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local ArenaStreaks = {}

local rng = Random.new()

-- Every piece of gear of one RarityTier: { Kind, Id, Name }.
local function gearOfTier(tier: number)
	local pool = {}
	local function scan(kind: string, list)
		for _, gear in list or {} do
			if type(gear) == "table" and gear.RarityTier == tier then
				table.insert(pool, { Kind = kind, Id = gear.Id, Name = gear.Name, Def = gear })
			end
		end
	end
	scan("Weapons", ExpandedTraits.Catalog.Weapons)
	for _, kind in Slots.Kinds do
		if kind ~= "Weapons" then
			scan(kind, ArmorFamilies.Catalog[kind])
		end
	end
	table.sort(pool, function(a, b)
		return a.Id < b.Id
	end)
	return pool
end
local GEAR_POOLS = {} -- rarity name -> its gear

-- A gem of `rarity`, Flawless (every metric 10, the surge at its top rank)
-- when the milestone says so.
local function rollGem(rarity: string, flawless: boolean?)
	local gem = GemGenerator.generate(rng, "MiningStore", {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Rarity = rarity,
	})
	if flawless then
		gem.Size, gem.Clarity, gem.Cut = 10, 10, 10
		gem.SurgeRank = 3
		gem.Flawless = true
	end
	return gem
end

-- `pool` in a random order.
local function shuffled(pool)
	local order = table.clone(pool)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

-- The cache for milestone `m`: about half gems, half gear, each piece Rare
-- or Ultra-Rare (ArenaStreak.rarities), no piece of gear twice.
function ArenaStreaks.rollCache(m)
	local gemTiers, gearTiers = ArenaStreak.rarities(m)
	local items = {}
	for _, rarity in gemTiers do
		local gem = rollGem(rarity, m.Flawless)
		table.insert(items, {
			Item = { Kind = "Gem", Gem = gem },
			Name = GemConfig.displayName(gem),
			Rarity = rarity,
			Free = true, -- (yours: not one of the picks)
		})
	end
	local decks = {}
	for _, rarity in gearTiers do
		if not decks[rarity] then
			GEAR_POOLS[rarity] = GEAR_POOLS[rarity] or gearOfTier(ArenaStreak.GearTier[rarity])
			decks[rarity] = shuffled(GEAR_POOLS[rarity])
		end
		local piece = table.remove(decks[rarity])
		if piece then
			table.insert(items, {
				-- (its look rolled now, at its own tier as the Forge does, so the
				-- 3D preview is exactly the piece you'll get)
				Item = {
					Kind = "Gear",
					Slot = Slots.ByKind[piece.Kind],
					Id = piece.Id,
					Quality = m.Quality,
					Roll = GearRolls.roll(rng, piece.Def.RarityTier, piece.Def),
				},
				Name = piece.Name,
				Rarity = rarity,
			})
		end
	end
	for i, entry in items do
		entry.OfferId = tostring(i)
	end
	return {
		Id = tostring(m.Wins) .. "_" .. tostring(os.time()),
		Wins = m.Wins,
		Name = m.Name,
		Items = items,
		At = os.time(),
	}
end

local function seasonKey(): string
	return Season.Name or "Season"
end

local function record(player: Player)
	local profile = PlayerData.get(player)
	local duel = profile and (profile :: any).Duel
	if not duel then
		return nil, profile
	end
	duel.RankedStreak = duel.RankedStreak or 0
	duel.BestRankedStreak = duel.BestRankedStreak or 0
	duel.StreakCaches = duel.StreakCaches or {}
	duel.StreakPaid = duel.StreakPaid or {}
	return duel, profile
end

-- A milestone reached: coins and title now, the cache to claim.
local function reward(player: Player, duel, profile, m)
	local paid = duel.StreakPaid[seasonKey()] or {}
	duel.StreakPaid[seasonKey()] = paid
	if paid[tostring(m.Wins)] then
		return -- (this season's already paid out)
	end
	paid[tostring(m.Wins)] = true
	if m.Coins and m.Coins > 0 then
		PlayerData.addCoins(player, m.Coins)
	end
	local title = m.Title and Cosmetics.get(m.Title)
	if title then
		profile.Cosmetics.Owned[title.Id] = true
	end
	table.insert(duel.StreakCaches, ArenaStreaks.rollCache(m))
	Remotes.Social:FireClient(player, "StreakReward", {
		Wins = m.Wins,
		Name = m.Name,
		Coins = m.Coins,
		Title = title and title.Name,
	})
	pcall(function()
		require(script.Parent.ChatChannels).announce(
			"Loot",
			string.format(
				"🏆 %s won %d Ranked matches in a row: %s!",
				player.DisplayName,
				m.Wins,
				string.upper(m.Name)
			)
		)
	end)
end

-- After a Ranked 1v1: `won`, against `opponentId`. Returns the streak now.
function ArenaStreaks.onRankedResult(player: Player, won: boolean, opponentId: number?): number
	local duel, profile = record(player)
	if not duel then
		return 0
	end
	if not won then
		duel.RankedStreak = 0
		duel.StreakLastBeaten = nil
		return 0
	end
	if not ArenaStreak.counts(duel, opponentId) then
		return duel.RankedStreak
	end
	local before = duel.RankedStreak
	duel.RankedStreak = before + 1
	duel.StreakLastBeaten = opponentId
	duel.BestRankedStreak = math.max(duel.BestRankedStreak, duel.RankedStreak)
	player:SetAttribute("RankedStreak", duel.RankedStreak)
	for _, m in ArenaStreak.reached(before, duel.RankedStreak) do
		reward(player, duel, profile, m)
	end
	return duel.RankedStreak
end

-- Leftovers onto the Market; any it couldn't take wait for next time.
local function vault(player: Player, duel, leftovers)
	local MarketBoard = require(script.Parent.MarketBoard)
	local waiting = {}
	for _, entry in leftovers do
		local item = entry.Item
		local worth = if item.Kind == "Gem" then GemConfig.value(item.Gem) else nil
		local price = entry.Price or ArenaStreak.vaultPrice(item, worth, entry.Rarity)
		local label = entry.Label
			or string.format("%s · %s's %d-win cache", ArenaStreak.VaultName, player.DisplayName, entry.Wins or 0)
		-- (your cut of the sale, paid through the Market's mailbox)
		local commission = { UserId = player.UserId, Rate = ArenaStreak.Commission }
		local ok = MarketBoard.vaultList(item, price, label, commission)
		if not ok then
			table.insert(
				waiting,
				{ Item = item, Price = price, Label = label, Wins = entry.Wins, Rarity = entry.Rarity }
			)
		end
	end
	duel.VaultPending = if #waiting > 0 then waiting else nil
end

local function view(duel)
	local caches = {}
	for _, cache in duel.StreakCaches do
		local items = {}
		for _, entry in cache.Items do
			table.insert(items, {
				OfferId = entry.OfferId,
				Name = entry.Name,
				Item = entry.Item,
				Rarity = entry.Rarity,
				Free = entry.Free,
			})
		end
		table.insert(caches, {
			Id = cache.Id,
			Wins = cache.Wins,
			Name = cache.Name,
			Items = items,
			Picks = ArenaStreak.Picks,
			Dev = cache.Dev,
		})
	end
	local nextUp = ArenaStreak.next(duel.RankedStreak)
	return {
		Caches = caches,
		Streak = duel.RankedStreak,
		Best = duel.BestRankedStreak,
		Next = nextUp and nextUp.Wins,
	}
end

function ArenaStreaks.caches(player: Player)
	local duel = record(player)
	if not duel then
		return Shop.reply(false, "Your data is still loading.")
	end
	return Shop.reply(true, "", view(duel))
end

function ArenaStreaks.claim(player: Player, cacheId: any, picks: any)
	local duel, profile = record(player)
	if not duel then
		return Shop.reply(false, "Your data is still loading.")
	end
	local index, cache = nil, nil
	for i, c in duel.StreakCaches do
		if c.Id == cacheId then
			index, cache = i, c
		end
	end
	if not cache then
		return Shop.reply(false, "That cache is already claimed.")
	end
	-- The picks are gear only (the gems are all yours anyway).
	local offered = 0
	for _, entry in cache.Items do
		if not entry.Free then
			offered += 1
		end
	end
	local want = math.min(ArenaStreak.Picks, offered)
	if type(picks) ~= "table" then
		return Shop.reply(false, string.format("Pick %d to keep.", want))
	end
	local chosen, count = {}, 0
	for _, id in picks do
		if type(id) == "string" and not chosen[id] then
			for _, entry in cache.Items do
				if entry.OfferId == id and not entry.Free then
					chosen[id] = entry
					count += 1
				end
			end
		end
	end
	if count ~= want then
		return Shop.reply(false, string.format("Pick %d to keep.", want))
	end
	-- Room for them all first (the picks and every free gem), so nothing's
	-- half given.
	local gems, gear = 0, 0
	for _, entry in cache.Items do
		if entry.Free or chosen[entry.OfferId] then
			if entry.Item.Kind == "Gem" then
				gems += 1
			else
				gear += 1
			end
		end
	end
	if #(profile.Gems or {}) + gems > (Config.MaxGems or math.huge) then
		return Shop.reply(false, "Your gem bag is full. Make room first.")
	end
	if Slots.gearCount(profile) + gear > (Config.MaxGear or math.huge) then
		return Shop.reply(false, "Your gear bag is full. Make room first.")
	end
	local leftovers = {}
	for _, entry in cache.Items do
		if entry.Free or chosen[entry.OfferId] then
			Market.give(profile, entry.Item, math.huge, true)
		else
			table.insert(leftovers, { Item = entry.Item, Wins = cache.Wins, Rarity = entry.Rarity })
		end
	end
	table.remove(duel.StreakCaches, index)
	pcall(GearRolls.ensure, profile, rng)
	PlayerData.sync(player)
	if cache.Dev then
		-- (a DEV test cache: the picks and gems are yours, the rest never reach
		-- the Market)
		return Shop.reply(
			true,
			string.format("DEV cache claimed. The other %d were dropped (test only).", #leftovers),
			view(duel)
		)
	end
	task.spawn(vault, player, duel, leftovers)
	return Shop.reply(
		true,
		string.format(
			"Claimed! The other %d went to the Market from the %s: you get %d%% of each sale.",
			#leftovers,
			ArenaStreak.VaultName,
			math.floor(ArenaStreak.Commission * 100 + 0.5)
		),
		view(duel)
	)
end

-- 3D pictures of every cache's gear (Equipment.groupPreviews, group "A":
-- "Slot|A:<cacheId>/<offerId>", drawn by GearArt.draw). Built on the
-- server's mannequin like the Market's; Done is false while it's busy.
function ArenaStreaks.previews(player: Player)
	local duel = record(player)
	if not duel then
		return Shop.reply(false, "Your data is still loading.")
	end
	local items = {}
	for _, cache in duel.StreakCaches do
		for _, entry in cache.Items do
			if entry.Item.Kind == "Gear" then
				items[cache.Id .. "/" .. entry.OfferId] = entry.Item
			end
		end
	end
	local Equipment = require(script.Parent.Equipment)
	local done, built = Equipment.groupPreviews(player, "A", items)
	return Shop.reply(true, "", { Done = done, Built = built or 0 })
end

local devRolls = 0 -- (so each test cache has its own id, and rolls afresh)

-- DEV (test admins): roll a test cache for the milestone at `wins` and put
-- it first in line, to see the roll and try claiming. No coins, no title,
-- nothing marked paid, and its leftovers never go up on the Market. One
-- test cache at a time (a new one replaces the last).
function ArenaStreaks.devCache(player: Player, wins: any)
	local TestAdmin = require(script.Parent.TestAdmin)
	if not TestAdmin.allowed(player.UserId) then
		return Shop.reply(false, "This test tool is restricted to the test admin.")
	end
	local m = ArenaStreak.get(tonumber(wins))
	if not m then
		return Shop.reply(false, "No milestone at that streak.")
	end
	local duel = record(player)
	if not duel then
		return Shop.reply(false, "Your data is still loading.")
	end
	for i = #duel.StreakCaches, 1, -1 do
		if duel.StreakCaches[i].Dev then
			table.remove(duel.StreakCaches, i)
		end
	end
	local cache = ArenaStreaks.rollCache(m)
	devRolls += 1
	cache.Id, cache.Dev = string.format("dev%d_%s", devRolls, cache.Id), true
	table.insert(duel.StreakCaches, 1, cache)
	return Shop.reply(true, string.format("Rolled a %d-win test cache (%s).", m.Wins, m.Name), view(duel))
end

function ArenaStreaks.start()
	Shop.register("StreakCaches", ArenaStreaks.caches)
	Shop.register("StreakClaim", ArenaStreaks.claim)
	Shop.register("DevStreakCache", ArenaStreaks.devCache)
	Shop.register("StreakPreviews", ArenaStreaks.previews)
	-- On joining: the streak on show, and any leftovers still to vault.
	local function joined(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if PlayerData.get(player) or not player.Parent then
					break
				end
				task.wait(1)
			end
			local duel = record(player)
			if not duel then
				return
			end
			player:SetAttribute("RankedStreak", duel.RankedStreak)
			if duel.VaultPending then
				vault(player, duel, duel.VaultPending)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
end

return ArenaStreaks
