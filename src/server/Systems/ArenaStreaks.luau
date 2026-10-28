--[[
	Rewards (Shared.RewardRoll): every one is two pieces of gear rolled; you
	keep one, the other goes up on the Market from a vault with your cut of
	its sale. How rare they are goes by how much you've played 1v1 (the
	ladder: RewardRoll.Bands), at least the reward's floor. They come from
	every 1v1 win (ArenaStreaks.winReward: a WIN REWARD), Ranked win
	streaks (Arena Caches, below) and bosses beaten (boss caches, below).
	A cache saved before this (six pieces, keep three; free gems) still
	opens and claims as it was.

	Ranked win streaks and their Arena Caches (Shared.ArenaStreak has the
	milestones and rules).

	Duels calls ArenaStreaks.onRankedResult after every Ranked 1v1. A win
	adds to the streak (not over the same player twice running), a loss
	ends it. Reaching a milestone pays its coins and title at once and opens
	an Arena Cache: free gems and six pieces of Rare and Ultra-Rare gear,
	rolled now and saved with the player (profile.Duel.StreakCaches), to
	claim whenever they like. A cache's weapons are only the standard swords
	(ExpandedItemTraits.rollable: no guns, hammers, axes, lances), one at
	most, so the leftovers always hold armor. Claiming gives every gem and the
	ArenaStreak.Picks pieces of gear chosen; the other gear goes up on the
	Market from the Arena Vault (MarketBoard.vaultList), with a commission
	for the player on each sale (paid through the Market's mailbox). A
	leftover the Market couldn't take right then waits (Duel.VaultPending)
	and goes up later.

	A boss beaten (the Rift's, a pathway dungeon's) gives everyone who
	fought it a boss cache the same way (ArenaStreaks.bossCache, Shared.
	BossLoot): the boss's gem and its threat's free gems, of its element,
	and six pieces of gear to keep three of, two of them its favourite kind.
	Its leftovers go up from the Rift Vault, with the same commission.

	Requests (Remotes.Request):
	  "StreakCaches"                     -> { Caches, Streak, Best, Next }
	  "StreakClaim", cacheId, { offerId, ... }   keep these (gear), vault the rest
	  "DevBossCache", threat             (test admins) a test boss cache
	The Social remote tells the player:
	  "StreakReward", { Wins, Name, Coins, Title }   a cache just opened
	  "BossCache", { Id, Boss, Source }              a boss cache just opened
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local BossLoot = require(ReplicatedStorage.Shared.BossLoot)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Market = require(ReplicatedStorage.Shared.Market)
local RewardRoll = require(ReplicatedStorage.Shared.RewardRoll)
local Season = require(ReplicatedStorage.Shared.Season)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemGenerator = require(script.Parent.GemGenerator)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local ArenaStreaks = {}

local rng = Random.new()

-- Every piece of gear of one RarityTier a roll can hand out: { Kind, Id,
-- Name } (swords, shields and armor; ExpandedItemTraits.rollable).
local function gearOfTier(tier: number)
	local pool = {}
	local function scan(kind: string, list)
		for _, gear in list or {} do
			if type(gear) == "table" and gear.RarityTier == tier and ExpandedTraits.rollable(gear) then
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
-- when the milestone says so, and of `element` when there's one (a boss's).
local function rollGem(rarity: string, flawless: boolean?, element: string?)
	local gem = GemGenerator.generate(rng, "MiningStore", {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Rarity = rarity,
		Home = element,
		Bias = if element then 1 else nil,
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
-- or Ultra-Rare (ArenaStreak.rarities), no piece of gear twice, and at most
-- ArenaStreak.MaxWeapons swords (so whatever you keep, armor is left over
-- for the Market). A boss's (BossLoot.spec) also has its own gem first
-- (m.FreeGems), its gems of its element (m.Element), and m.FocusCount of
-- its gear its favourite kind (m.Focus; a sword boss's two swords).
-- A reward's (m.Gear: its rarities, RewardRoll.rarities) has no free gems:
-- its pieces at those rarities, each at least its rarity's quality.
function ArenaStreaks.rollCache(m)
	local gemTiers, gearTiers = ArenaStreak.rarities(m)
	if m.Gear then
		gemTiers, gearTiers = {}, m.Gear
	end
	local items = {}
	for _, gem in m.FreeGems or {} do
		table.insert(items, {
			Item = { Kind = "Gem", Gem = gem },
			Name = GemConfig.displayName(gem),
			Rarity = gem.Tier,
			Free = true,
		})
	end
	for _, rarity in gemTiers do
		local gem = rollGem(rarity, m.Flawless, m.Element)
		table.insert(items, {
			Item = { Kind = "Gem", Gem = gem },
			Name = GemConfig.displayName(gem),
			Rarity = rarity,
			Free = true, -- (yours: not one of the picks)
		})
	end
	local decks, focusDecks, used = {}, {}, {}
	local weapons = 0
	local focusLeft = if m.Focus then m.FocusCount or 0 else 0
	local maxWeapons = if m.Focus == "Weapons"
		then math.max(ArenaStreak.MaxWeapons, focusLeft)
		else ArenaStreak.MaxWeapons
	-- The next piece off `deck`: none twice, no sword past the cap.
	local function draw(deck)
		local piece = table.remove(deck)
		while piece and (used[piece.Id] or (piece.Kind == "Weapons" and weapons >= maxWeapons)) do
			piece = table.remove(deck)
		end
		return piece
	end
	for _, rarity in gearTiers do
		if not decks[rarity] then
			GEAR_POOLS[rarity] = GEAR_POOLS[rarity] or gearOfTier(ArenaStreak.GearTier[rarity])
			decks[rarity] = shuffled(GEAR_POOLS[rarity])
		end
		local piece = nil
		if focusLeft > 0 then
			if not focusDecks[rarity] then
				local only = {}
				for _, candidate in GEAR_POOLS[rarity] do
					if candidate.Kind == m.Focus then
						table.insert(only, candidate)
					end
				end
				focusDecks[rarity] = shuffled(only)
			end
			piece = draw(focusDecks[rarity])
			if piece then
				focusLeft -= 1
			end
		end
		piece = piece or draw(decks[rarity])
		if piece then
			used[piece.Id] = true
			if piece.Kind == "Weapons" then
				weapons += 1
			end
			table.insert(items, {
				-- (its look rolled now, at its own tier as the Forge does, so the
				-- 3D preview is exactly the piece you'll get)
				Item = {
					Kind = "Gear",
					Slot = Slots.ByKind[piece.Kind],
					Id = piece.Id,
					Quality = if m.Gear then RewardRoll.quality(rarity, m.Quality) else m.Quality,
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
		Picks = if m.Gear then RewardRoll.Picks else nil,
		Plays = m.Plays,
	}
end

-- A reward's two rarities for `duel` (its 1v1s played), at least `floor`.
local function rolled(duel, floor: string?)
	local plays = RewardRoll.plays(duel)
	return RewardRoll.rarities(plays, floor, rng), plays
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

local bossRolls = 0 -- (so every boss cache has its own id)

-- A boss cache from `boss` (a Shared.DungeonRules.Bosses entry), beaten in
-- `source` ("Rift", "Dungeon"), with `gem` (Dungeons.bossGem) its own free
-- gem.
local function rollBossCache(boss, _gem, source: string?, duel)
	local m = BossLoot.spec(boss)
	m.Gear, m.Plays = rolled(duel, m.Floor)
	local cache = ArenaStreaks.rollCache(m)
	bossRolls += 1
	cache.Id = string.format("boss%d_%s_%d", bossRolls, tostring(boss.Id), os.time())
	cache.Kind = "Boss"
	cache.Boss, cache.BossId = boss.Name, boss.Id
	cache.Threat = BossLoot.threat(boss)
	cache.Source = source
	cache.Element, cache.Focus = boss.Element, boss.Loot
	return cache
end

-- `player` beat `boss`: their boss cache, saved with their other caches to
-- claim whenever they like (the client opens it when it comes in).
function ArenaStreaks.bossCache(player: Player, boss, gem, source: string?)
	local duel = record(player)
	if not duel or type(boss) ~= "table" then
		return nil
	end
	local cache = rollBossCache(boss, gem, source, duel)
	table.insert(duel.StreakCaches, cache)
	Remotes.Social:FireClient(player, "BossCache", { Id = cache.Id, Boss = boss.Name, Source = source })
	-- And one kaiju roll for beating it (KaijuServer.grantBossRoll; required
	-- here, as KaijuServer's chain comes back round to this module).
	require(script.Parent.KaijuServer).grantBossRoll(player)
	return cache
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
	local spec = table.clone(m)
	spec.Gear, spec.Plays = rolled(duel, ArenaStreak.floor(m))
	table.insert(duel.StreakCaches, ArenaStreaks.rollCache(spec))
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

-- A 1v1 won (queued, Ranked or Casual) over `opponentId`: its WIN REWARD,
-- two pieces rolled by how much you've played 1v1, to claim whenever you
-- like (the client opens it after the match). Not over the same player
-- twice running, and not past RewardRoll.Waiting unclaimed. (Duels counts
-- the match played first: RewardRoll.count.)
function ArenaStreaks.winReward(player: Player, opponentId: number?)
	local duel = record(player)
	if not duel or not RewardRoll.pays(duel, opponentId) then
		return nil
	end
	local waiting = 0
	for _, cache in duel.StreakCaches do
		if cache.Kind == "Win" then
			waiting += 1
		end
	end
	if waiting >= RewardRoll.Waiting then
		Remotes.Notify:FireClient(
			player,
			string.format("%d win rewards are waiting: claim some to get more.", waiting)
		)
		return nil
	end
	duel.RewardLastBeaten = opponentId
	local gear, plays = rolled(duel)
	local cache = ArenaStreaks.rollCache({ Wins = 0, Name = "Win Reward", Gear = gear, Plays = plays })
	duel.WinRewards = (duel.WinRewards or 0) + 1
	cache.Id = string.format("win%d_%d", duel.WinRewards, os.time())
	cache.Kind = "Win"
	table.insert(duel.StreakCaches, cache)
	Remotes.Social:FireClient(player, "WinReward", { Id = cache.Id })
	return cache
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
			Picks = cache.Picks or ArenaStreak.LegacyPicks,
			Plays = cache.Plays,
			Dev = cache.Dev,
			Kind = cache.Kind,
			Boss = cache.Boss,
			Threat = cache.Threat,
			Source = cache.Source,
			Element = cache.Element,
			Focus = cache.Focus,
		})
	end
	local nextUp = ArenaStreak.next(duel.RankedStreak)
	-- Where you are on the rewards' ladder (RewardRoll): your 1v1s played,
	-- your band, the next one, and your odds.
	local plays = RewardRoll.plays(duel)
	local band, _, nextBand = RewardRoll.band(plays)
	return {
		Caches = caches,
		Streak = duel.RankedStreak,
		Best = duel.BestRankedStreak,
		Next = nextUp and nextUp.Wins,
		Plays = plays,
		Band = band.Name,
		NextBand = nextBand and { Name = nextBand.Name, Plays = nextBand.Plays },
		Odds = RewardRoll.odds(plays),
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
	local want = math.min(cache.Picks or ArenaStreak.LegacyPicks, offered)
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
			table.insert(leftovers, {
				Item = entry.Item,
				Wins = cache.Wins,
				Rarity = entry.Rarity,
				Label = if cache.Kind == "Boss"
					then string.format("%s · %s's %s cache", BossLoot.VaultName, player.DisplayName, cache.Boss or "boss")
					elseif cache.Kind == "Win" then string.format("%s · %s's win reward", ArenaStreak.VaultName, player.DisplayName)
					else nil,
			})
		end
	end
	table.remove(duel.StreakCaches, index)
	pcall(GearRolls.ensure, profile, rng)
	PlayerData.sync(player)
	-- Every roll's leftovers go up on the Market (a DEV test cache's too).
	task.spawn(vault, player, duel, leftovers)
	return Shop.reply(
		true,
		string.format(
			"Claimed! %s went to the Market from the %s: you get %d%% of %s.",
			if #leftovers == 1 then "The other" else string.format("The other %d", #leftovers),
			if cache.Kind == "Boss" then BossLoot.VaultName else ArenaStreak.VaultName,
			math.floor(ArenaStreak.Commission * 100 + 0.5),
			if #leftovers == 1 then "its sale" else "each sale"
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
-- nothing marked paid; its leftovers go up on the Market like any roll's. One
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
	local spec = table.clone(m)
	spec.Gear, spec.Plays = rolled(duel, ArenaStreak.floor(m))
	local cache = ArenaStreaks.rollCache(spec)
	devRolls += 1
	cache.Id, cache.Dev = string.format("dev%d_%s", devRolls, cache.Id), true
	table.insert(duel.StreakCaches, 1, cache)
	return Shop.reply(true, string.format("Rolled a %d-win test cache (%s).", m.Wins, m.Name), view(duel))
end

-- DEV (test admins): a test boss cache from a boss of `threat` (1-3), its
-- gem and all, first in line. Like devCache, one test cache at a time.
function ArenaStreaks.devBossCache(player: Player, threat: any)
	local TestAdmin = require(script.Parent.TestAdmin)
	if not TestAdmin.allowed(player.UserId) then
		return Shop.reply(false, "This test tool is restricted to the test admin.")
	end
	local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
	local bosses = {}
	for _, boss in DungeonRules.Bosses do
		if BossLoot.threat(boss) == tonumber(threat) then
			table.insert(bosses, boss)
		end
	end
	if #bosses == 0 then
		return Shop.reply(false, "No boss at that threat.")
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
	local boss = bosses[rng:NextInteger(1, #bosses)]
	local Dungeons = require(script.Parent.Dungeons)
	local cache = rollBossCache(boss, Dungeons.bossGem(boss.Element, 4), "Dev", duel)
	devRolls += 1
	cache.Id, cache.Dev = string.format("dev%d_%s", devRolls, cache.Id), true
	table.insert(duel.StreakCaches, 1, cache)
	return Shop.reply(
		true,
		string.format("Rolled a test boss cache (%s, threat %s).", boss.Name, BossLoot.numeral(cache.Threat)),
		view(duel)
	)
end

function ArenaStreaks.start()
	Shop.register("StreakCaches", ArenaStreaks.caches)
	Shop.register("StreakClaim", ArenaStreaks.claim)
	Shop.register("DevStreakCache", ArenaStreaks.devCache)
	Shop.register("DevBossCache", ArenaStreaks.devBossCache)
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
