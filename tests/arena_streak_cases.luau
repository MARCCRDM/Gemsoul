-- lune run tests/arena_streak_cases.luau <repo>
-- Ranked win streaks (Shared.ArenaStreak, Systems/ArenaStreaks): the
-- milestones, what counts, the Arena Caches (Rare and Ultra-Rare gems and gear),
-- claiming two and the rest going to the Market from the Arena Vault.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local sharedEnv
local function shared(name)
	if loaded[name] == nil then
		loaded[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = sharedEnv })()
	end
	return loaded[name]
end
local parent = setmetatable({}, { __index = function(_, k) return k end })
sharedEnv = setmetatable({
	Color3 = roblox.Color3, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, UDim2 = roblox.UDim2,
	CFrame = roblox.CFrame, Enum = roblox.Enum, script = { Parent = parent },
	require = function(name) return shared(name) end,
}, { __index = _G })

local Rules = shared("ArenaStreak")
local Cosmetics = shared("Cosmetics")

-- The milestones ------------------------------------------------------------------------
local wins = {}
for i, m in Rules.Milestones do
	table.insert(wins, m.Wins)
	check(m.Choices > Rules.Picks, m.Wins .. " offers no real choice")
	check(m.Quality >= 1 and m.Quality <= 4, m.Wins .. " has a bad gear quality")
	check(m.UltraRare >= 1 and m.UltraRare <= m.Choices, m.Wins .. " offers no Ultra-Rare piece")
	local gemTiers, gearTiers = Rules.rarities(m)
	local ultra = 0
	for _, list in { gemTiers, gearTiers } do
		for _, tier in list do
			check(tier == "Rare" or tier == "UltraRare", m.Wins .. " offers a piece that's neither Rare nor Ultra-Rare")
			ultra += if tier == "UltraRare" then 1 else 0
		end
	end
	check(#gemTiers + #gearTiers == m.Choices and ultra == m.UltraRare, m.Wins .. "'s rarities don't add up")
	check(m.Coins > 0 and m.Name, m.Wins .. " is incomplete")
	if i > 1 then
		local before = Rules.Milestones[i - 1]
		check(
			m.Wins > before.Wins and m.Choices >= before.Choices and m.UltraRare >= before.UltraRare and m.Coins > before.Coins,
			m.Wins .. " is no better than the one before"
		)
	end
	if m.Title then
		local title = Cosmetics.get(m.Title)
		check(title and title.Kind == "Title" and title.Exclusive == "Ranked" and title.How, m.Wins .. "'s title isn't a Ranked exclusive")
	end
end
check(table.concat(wins, ",") == "10,20,30,40,50,60,70,80,90,100,150,200", "The milestones aren't 10 ... 100, 150, 200")
check(#Rules.reached(9, 10) == 1 and Rules.reached(9, 10)[1].Wins == 10, "Reaching 10 didn't count")
check(#Rules.reached(10, 11) == 0 and #Rules.reached(0, 9) == 0, "A milestone counted twice or early")
check(Rules.next(0).Wins == 10 and Rules.next(10).Wins == 20 and Rules.next(100).Wins == 150 and Rules.next(200) == nil, "next() is off")
check(not Rules.counts({ StreakLastBeaten = 5 }, 5) and Rules.counts({ StreakLastBeaten = 5 }, 6), "The same foe twice running counted")
check(Rules.Milestones[#Rules.Milestones].UltraRare == Rules.Milestones[#Rules.Milestones].Choices, "200 wins isn't all Ultra-Rare")
check(
	Rules.vaultPrice({ Kind = "Gear", Quality = 4 }, nil, "UltraRare") == Rules.VaultGear.UltraRare[4]
		and Rules.vaultPrice({ Kind = "Gear", Quality = 1 }, nil, "Rare") == Rules.VaultGear.Rare[1],
	"Gear's Market price is off"
)
check(Rules.VaultGear.UltraRare[1] > Rules.VaultGear.Rare[1], "Ultra-Rare gear isn't priced above Rare")
check(
	Rules.vaultPrice({ Kind = "Gem", Gem = { Tier = "Rare" } }, 100) == Rules.VaultGemFloor.Rare
		and Rules.vaultPrice({ Kind = "Gem", Gem = { Tier = "UltraRare" } }, 100) == Rules.VaultGemFloor.UltraRare
		and Rules.vaultPrice({ Kind = "Gem" }, 10000, "Rare") == 30000,
	"A gem's Market price is off"
)

-- The server, with stand-ins ------------------------------------------------------------------
local player = { UserId = 7, DisplayName = "Kai", SetAttribute = function() end }
local profile = {
	Coins = 0,
	Gems = {},
	Owned = { Weapons = {}, Shields = {}, Helmets = {}, Armors = {}, Gloves = {}, Boots = {} },
	Character = { GearRolls = {}, ItemGems = {} },
	Cosmetics = { Owned = {} },
	Duel = { Rating = 1000, Wins = 0, Losses = 0, Streak = 0 },
}
local handlers, fired, vaulted, nextGem = {}, {}, {}, 0
local stubs = {
	PlayerData = {
		get = function(p) return if p == player then profile else nil end,
		newGemId = function() nextGem += 1; return "gem" .. nextGem end,
		addCoins = function(_, n) profile.Coins += n end,
		sync = function() end,
	},
	Remotes = { Social = { FireClient = function(_, _, kind, data) table.insert(fired, { kind, data }) end } },
	Shop = {
		register = function(name, fn) handlers[name] = fn end,
		reply = function(ok, message, extra)
			local r = extra or {}
			r.Ok, r.Message = ok, message
			return r
		end,
	},
	TestAdmin = { allowed = function(id) return id == 7 end },
	MarketBoard = { vaultList = function(item, price, label) table.insert(vaulted, { item, price, label }); return true end },
	ChatChannels = { announce = function() end },
}
for _, name in { "ArenaStreak", "ArmorFamilies", "Config", "Cosmetics", "ExpandedItemTraits", "GearRolls", "GemConfig", "GemRoller", "Market", "Season", "EquipmentSlots" } do
	stubs[name] = shared(name)
end
-- (Lune has no Roblox Random.)
FakeRandom = {
	new = function(seed)
		local r = {}
		math.randomseed(seed or 7)
		function r:NextNumber(a, b)
			a, b = a or 0, b or 1
			return a + math.random() * (b - a)
		end
		function r:NextInteger(a, b)
			return math.random(a, b)
		end
		return r
	end,
}
sharedEnv.Random = FakeRandom
local serverEnv = setmetatable({
	Color3 = roblox.Color3, Enum = roblox.Enum,
	game = { GetService = function(_, name)
		if name == "Players" then
			return { GetPlayers = function() return {} end, PlayerAdded = { Connect = function() end } }
		end
		return { Shared = parent }
	end },
	script = { Parent = parent },
	require = function(name) return stubs[name] end,
	task = { spawn = function(fn, ...) fn(...) end, wait = function() return 0 end, delay = function() end },
	Random = FakeRandom,
}, { __index = _G })
stubs.GemGenerator = luau.load(fs.readFile(ROOT .. "/src/server/Systems/GemGenerator.luau"), { debugName = "GemGenerator", environment = serverEnv })()
local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/ArenaStreaks.luau"), { debugName = "ArenaStreaks", environment = serverEnv })()
Server.start()
check(handlers.StreakCaches and handlers.StreakClaim, "The cache requests aren't registered")

-- Nine wins over alternating foes, then the same foe again (doesn't count), then the tenth.
for i = 1, 9 do
	Server.onRankedResult(player, true, 100 + i)
end
check(profile.Duel.RankedStreak == 9 and #profile.Duel.StreakCaches == 0, "Nine wins went wrong")
check(Server.onRankedResult(player, true, 109) == 9, "Beating the same player twice running counted")
check(Server.onRankedResult(player, true, 200) == 10, "The tenth win didn't count")
check(#profile.Duel.StreakCaches == 1 and profile.Coins == Rules.Milestones[1].Coins, "Ten wins didn't open a cache and pay")
check(fired[#fired][1] == "StreakReward" and fired[#fired][2].Wins == 10, "The player wasn't told about the cache")
local cache = profile.Duel.StreakCaches[1]
check(#cache.Items == Rules.Milestones[1].Choices, "The cache holds the wrong number of pieces")
-- Every gear Id's RarityTier, to check the pieces against.
local gearTier = {}
for _, w in shared("ExpandedItemTraits").Catalog.Weapons do
	gearTier[w.Id] = w.RarityTier
end
for _, list in shared("ArmorFamilies").Catalog do
	for _, piece in list do
		if type(piece) == "table" and piece.Id then
			gearTier[piece.Id] = piece.RarityTier
		end
	end
end
local function cacheRarities(c)
	local counts, gems, gear = { Rare = 0, UltraRare = 0 }, 0, 0
	for _, entry in c.Items do
		local tier = entry.Rarity
		check(tier == "Rare" or tier == "UltraRare", "A cache piece isn't Rare or Ultra-Rare")
		counts[tier] += 1
		if entry.Item.Kind == "Gem" then
			gems += 1
			check(entry.Item.Gem.Tier == tier, "A cache gem isn't the rarity it says")
		else
			gear += 1
			check(gearTier[entry.Item.Id] == Rules.GearTier[tier], "A cache piece of gear isn't the rarity it says")
		end
	end
	return counts, gems, gear
end
local counts, gems, gear = cacheRarities(cache)
for _, entry in cache.Items do
	if entry.Item.Kind == "Gear" then
		check(entry.Item.Quality == Rules.Milestones[1].Quality and entry.Item.Slot, "A cache piece of gear is malformed")
	end
end
check(gems >= 1 and gear >= 1, "The cache isn't gems and gear")
check(counts.UltraRare == Rules.Milestones[1].UltraRare and counts.Rare == Rules.Milestones[1].Choices - counts.UltraRare, "The 10-win cache's rarities are off")

-- A loss ends it; a new streak to 10 the same season pays nothing more.
check(Server.onRankedResult(player, false, 300) == 0, "A loss didn't end the streak")
for i = 1, 10 do
	Server.onRankedResult(player, true, 400 + i)
end
check(profile.Duel.RankedStreak == 10 and #profile.Duel.StreakCaches == 1, "The 10-win cache paid twice in a season")
check(profile.Duel.BestRankedStreak == 10, "The best streak wasn't kept")

-- Claiming: exactly two; they arrive; the rest go to the Vault.
local view = handlers.StreakCaches(player)
check(view.Ok and #view.Caches == 1 and view.Streak == 10 and view.Next == 20, "The cache list is wrong")
check(not handlers.StreakClaim(player, cache.Id, { "1" }).Ok, "Claimed with one pick")
check(not handlers.StreakClaim(player, cache.Id, { "1", "1" }).Ok, "Claimed the same piece twice")
check(not handlers.StreakClaim(player, "nope", { "1", "2" }).Ok, "Claimed a cache that isn't there")
local keep = { cache.Items[1].OfferId, cache.Items[#cache.Items].OfferId }
local result = handlers.StreakClaim(player, cache.Id, keep)
check(result.Ok, "A fair claim failed: " .. tostring(result.Message))
check(#profile.Gems == 1, "The kept gem didn't arrive")
local gearOwned = 0
for _, list in profile.Owned do
	for _ in list do
		gearOwned += 1
	end
end
check(gearOwned == 1, "The kept gear didn't arrive")
check(#vaulted == #cache.Items - 2, "The leftovers didn't all go to the Market")
for _, v in vaulted do
	local item = v[1]
	local tier = if item.Kind == "Gem" then item.Gem.Tier else (if gearTier[item.Id] == 4 then "UltraRare" else "Rare")
	local floor = if item.Kind == "Gem" then Rules.VaultGemFloor[tier] else Rules.VaultGear[tier][item.Quality]
	check(v[2] >= floor and string.find(v[3], Rules.VaultName, 1, true), "A Vault listing is mispriced or unlabelled")
	if item.Kind == "Gear" then
		check(v[2] == Rules.vaultPrice(item, nil, tier), "A Vault gear listing isn't priced for its rarity")
	end
end
check(#profile.Duel.StreakCaches == 0 and not handlers.StreakClaim(player, cache.Id, keep).Ok, "A cache could be claimed twice")

-- Up to 100: a Flawless gem, the title, the coins.
profile.Duel.StreakPaid = {}
profile.Duel.RankedStreak = 99
profile.Duel.StreakLastBeaten = nil
Server.onRankedResult(player, true, 999)
local big = profile.Duel.StreakCaches[1]
check(big and big.Wins == 100 and #big.Items == 8, "The 100-win cache is wrong")
for _, entry in big.Items do
	if entry.Item.Kind == "Gem" then
		local g = entry.Item.Gem
		check(g.Flawless and g.Size == 10 and g.Clarity == 10 and g.Cut == 10 and g.SurgeRank == 3, "A 100-win gem isn't Flawless")
	end
end
check(profile.Cosmetics.Owned.TitleStreak100, "The CENTURION title wasn't given")
local bigCounts = cacheRarities(big)
check(bigCounts.UltraRare == Rules.get(100).UltraRare, "The 100-win cache has the wrong number of Ultra-Rares")
-- 200: every piece Ultra-Rare.
local top = Server.rollCache(Rules.get(200))
local topCounts = cacheRarities(top)
check(#top.Items == 10 and topCounts.UltraRare == 10, "The 200-win cache isn't all Ultra-Rare")
-- A full gem bag stops the claim before anything moves.
local config = shared("Config")
local before = #vaulted
for i = 1, (config.MaxGems or 200) do
	profile.Gems[i] = { Id = "full" .. i }
end
local gemPick, gearPick
for _, entry in big.Items do
	if entry.Item.Kind == "Gem" then gemPick = gemPick or entry.OfferId else gearPick = gearPick or entry.OfferId end
end
check(not handlers.StreakClaim(player, big.Id, { gemPick, gearPick }).Ok and #vaulted == before, "Claimed into a full gem bag")

-- DEV test caches: test admins only; first in line; no coins, no title,
-- nothing marked paid; a new one replaces the last; leftovers never vaulted.
profile.Gems = {}
local outsider = { UserId = 8, DisplayName = "Not Admin", SetAttribute = function() end }
check(not handlers.DevStreakCache(outsider, 10).Ok, "A non-admin rolled a test cache")
check(not handlers.DevStreakCache(player, 15).Ok and not handlers.DevStreakCache(player, "x").Ok, "A test cache rolled for no milestone")
local coinsBefore, paidBefore = profile.Coins, profile.Duel.StreakPaid
local realCount = #profile.Duel.StreakCaches
for _, wins in { 10, 20, 30, 40, 50 } do
	local reply = handlers.DevStreakCache(player, wins)
	local m = Rules.get(wins)
	check(reply.Ok and reply.Caches[1].Wins == wins and reply.Caches[1].Dev, "The " .. wins .. "-win test cache isn't first in line")
	check(#reply.Caches[1].Items == m.Choices, "The " .. wins .. "-win test cache holds the wrong number of pieces")
	check(cacheRarities(profile.Duel.StreakCaches[1]).UltraRare == m.UltraRare, "The " .. wins .. "-win test cache has the wrong Ultra-Rares")
	check(#profile.Duel.StreakCaches == realCount + 1, "Test caches piled up")
end
local firstId = profile.Duel.StreakCaches[1].Id
check(handlers.DevStreakCache(player, 10).Caches[1].Id ~= firstId, "Two test caches shared an id (the roll wouldn't replay)")
check(profile.Coins == coinsBefore and profile.Duel.StreakPaid == paidBefore and not profile.Cosmetics.Owned.TitleStreak30, "A test cache paid out")
local dev = profile.Duel.StreakCaches[1]
local vaultedBefore = #vaulted
local devClaim = handlers.StreakClaim(player, dev.Id, { dev.Items[1].OfferId, dev.Items[#dev.Items].OfferId })
check(devClaim.Ok and #profile.Gems == 1, "A test cache couldn't be claimed")
check(#vaulted == vaultedBefore, "A test cache's leftovers went to the Market")
check(#profile.Duel.StreakCaches == realCount, "The claimed test cache stayed")

print(string.format("PASS: %d arena streak checks (milestones 10-200, Rare and Ultra-Rare caches, claims, Arena Vault, DEV test caches)", checks))
