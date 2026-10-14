--[[
	Ranked win streaks and their Arena Caches (Shared.ArenaStreak has the
	milestones and rules).

	Duels calls ArenaStreaks.onRankedResult after every Ranked 1v1. A win
	adds to the streak (not over the same player twice running), a loss
	ends it. Reaching a milestone pays its coins and title at once and opens
	an Arena Cache: Legendary gems and gear, rolled now and saved with the
	player (profile.Duel.StreakCaches), to claim whenever they like.
	Claiming keeps ArenaStreak.Picks of them; the rest go up on the Market
	from the Arena Vault (MarketBoard.vaultList). A leftover the Market
	couldn't take right then waits (Duel.VaultPending) and goes up later.

	Requests (Remotes.Request):
	  "StreakCaches"                     -> { Caches, Streak, Best, Next }
	  "StreakClaim", cacheId, { offerId, ... }   keep these, vault the rest
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
local LEGENDARY = 5 -- gear RarityTier
local GEM_TIER = "Legendary"

-- Every Legendary piece of gear: { Kind, Id, Name }.
local function legendaryGear()
	local pool = {}
	local function scan(kind: string, list)
		for _, gear in list or {} do
			if type(gear) == "table" and gear.RarityTier == LEGENDARY then
				table.insert(pool, { Kind = kind, Id = gear.Id, Name = gear.Name })
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
local GEAR_POOL = nil

-- A Legendary gem, Flawless (every metric 10, the surge at its top rank)
-- when the milestone says so.
local function rollGem(flawless: boolean?)
	local gem = GemGenerator.generate(rng, "MiningStore", {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Rarity = GEM_TIER,
	})
	if flawless then
		gem.Size, gem.Clarity, gem.Cut = 10, 10, 10
		gem.SurgeRank = 3
		gem.Flawless = true
	end
	return gem
end

-- The cache for milestone `m`: about half gems, half gear (no piece twice).
function ArenaStreaks.rollCache(m)
	GEAR_POOL = GEAR_POOL or legendaryGear()
	local gems, gear = ArenaStreak.split(m.Choices)
	local items = {}
	for _ = 1, gems do
		local gem = rollGem(m.Flawless)
		table.insert(items, {
			Item = { Kind = "Gem", Gem = gem },
			Name = GemConfig.displayName(gem),
		})
	end
	local order = {}
	for i = 1, #GEAR_POOL do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for n = 1, math.min(gear, #order) do
		local piece = GEAR_POOL[order[n]]
		table.insert(items, {
			Item = { Kind = "Gear", Slot = Slots.ByKind[piece.Kind], Id = piece.Id, Quality = m.Quality },
			Name = piece.Name,
		})
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
		local price = entry.Price or ArenaStreak.vaultPrice(item, worth)
		local label = entry.Label
			or string.format("%s · %s's %d-win cache", ArenaStreak.VaultName, player.DisplayName, entry.Wins or 0)
		local ok = MarketBoard.vaultList(item, price, label)
		if not ok then
			table.insert(waiting, { Item = item, Price = price, Label = label, Wins = entry.Wins })
		end
	end
	duel.VaultPending = if #waiting > 0 then waiting else nil
end

local function view(duel)
	local caches = {}
	for _, cache in duel.StreakCaches do
		local items = {}
		for _, entry in cache.Items do
			table.insert(items, { OfferId = entry.OfferId, Name = entry.Name, Item = entry.Item })
		end
		table.insert(
			caches,
			{ Id = cache.Id, Wins = cache.Wins, Name = cache.Name, Items = items, Picks = ArenaStreak.Picks }
		)
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
	local want = math.min(ArenaStreak.Picks, #cache.Items)
	if type(picks) ~= "table" then
		return Shop.reply(false, string.format("Pick %d to keep.", want))
	end
	local chosen, count = {}, 0
	for _, id in picks do
		if type(id) == "string" and not chosen[id] then
			for _, entry in cache.Items do
				if entry.OfferId == id then
					chosen[id] = entry
					count += 1
				end
			end
		end
	end
	if count ~= want then
		return Shop.reply(false, string.format("Pick %d to keep.", want))
	end
	-- Room for them all first, so nothing's half given.
	local gems, gear = 0, 0
	for _, entry in chosen do
		if entry.Item.Kind == "Gem" then
			gems += 1
		else
			gear += 1
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
		if chosen[entry.OfferId] then
			Market.give(profile, entry.Item, math.huge, true)
		else
			table.insert(leftovers, { Item = entry.Item, Wins = cache.Wins })
		end
	end
	table.remove(duel.StreakCaches, index)
	pcall(GearRolls.ensure, profile, rng)
	PlayerData.sync(player)
	task.spawn(vault, player, duel, leftovers)
	return Shop.reply(
		true,
		string.format("Claimed! The other %d went to the Market from the %s.", #leftovers, ArenaStreak.VaultName),
		view(duel)
	)
end

function ArenaStreaks.start()
	Shop.register("StreakCaches", ArenaStreaks.caches)
	Shop.register("StreakClaim", ArenaStreaks.claim)
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
