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
	check(m.Quality >= 1 and m.Quality <= 4, m.Wins .. " has a bad gear quality")
	check(m.Gems >= 1 and (m.GemTier == "Rare" or m.GemTier == "UltraRare"), m.Wins .. " gives no free gem")
	check(m.UltraRare >= 1 and m.UltraRare <= Rules.GearOffered, m.Wins .. " offers no Ultra-Rare gear")
	local gemTiers, gearTiers = Rules.rarities(m)
	check(#gemTiers == m.Gems and #gearTiers == Rules.GearOffered, m.Wins .. " offers the wrong number of pieces")
	local ultra = 0
	for _, tier in gearTiers do
		check(tier == "Rare" or tier == "UltraRare", m.Wins .. " offers gear that's neither Rare nor Ultra-Rare")
		ultra += if tier == "UltraRare" then 1 else 0
	end
	for _, tier in gemTiers do
		check(tier == m.GemTier, m.Wins .. "'s free gems aren't its gem rarity")
	end
	check(ultra == m.UltraRare, m.Wins .. "'s Ultra-Rare gear doesn't add up")
	check(m.Coins > 0 and m.Name, m.Wins .. " is incomplete")
	if i > 1 then
		local before = Rules.Milestones[i - 1]
		check(
			m.Wins > before.Wins
				and m.Gems >= before.Gems
				and m.UltraRare >= before.UltraRare
				and m.Coins > before.Coins
				and (m.GemTier == "UltraRare" or before.GemTier == "Rare"),
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
check(Rules.GearOffered == 6 and Rules.Picks == 3, "The gear isn't a pick of 3 from 6")
check(Rules.get(200).UltraRare == Rules.GearOffered, "200 wins isn't all Ultra-Rare gear")
check(Rules.Commission == 0.25 and Rules.commission(10000) == 2500 and Rules.commission(15001) == 3750, "The commission isn't 25%")
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
local handlers, fired, vaulted, nextGem, previewCalls = {}, {}, {}, 0, {}
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
	Equipment = { groupPreviews = function(_, group, items) previewCalls[#previewCalls + 1] = { group, items }; return true, 0 end },
	MarketBoard = { vaultList = function(item, price, label, commission) table.insert(vaulted, { item, price, label, commission }); return true end },
	ChatChannels = { announce = function() end },
	-- (The boss's gem: Dungeons.bossGem.)
	Dungeons = {
		bossGem = function(element, tier)
			nextGem += 1
			return { Id = "gem" .. nextGem, Element = element, Tier = if tier == 5 then "Legendary" else "UltraRare", Size = 6, Clarity = 6, Cut = 6, SurgeTier = 4, SurgeRank = 3, Source = "PvEDrop" }
		end,
	},
}
for _, name in { "ArenaStreak", "ArmorFamilies", "BossLoot", "Config", "Cosmetics", "DungeonRules", "ExpandedItemTraits", "GearRolls", "GemConfig", "GemRoller", "Market", "Season", "EquipmentSlots" } do
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
check(#cache.Items == Rules.Milestones[1].Gems + Rules.GearOffered, "The cache holds the wrong number of pieces")
for _, entry in cache.Items do
	check((entry.Free == true) == (entry.Item.Kind == "Gem"), "A cache's gems aren't the free pieces (or gear is)")
end
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
-- (counts: the gear's rarities; the gems are checked against their own)
local function cacheRarities(c)
	local counts, gems, gear = { Rare = 0, UltraRare = 0 }, 0, 0
	for _, entry in c.Items do
		local tier = entry.Rarity
		check(tier == "Rare" or tier == "UltraRare", "A cache piece isn't Rare or Ultra-Rare")
		if entry.Item.Kind ~= "Gem" then
			counts[tier] += 1
		end
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
-- Gear comes with its look rolled (at its own tier, as the Forge rolls), so
-- its 3D preview is the piece you get; the previews are asked for as group
-- "A", one per piece, keyed "<cache>/<offer>".
for _, entry in cache.Items do
	if entry.Item.Kind == "Gear" then
		local roll = entry.Item.Roll
		check(type(roll) == "table" and roll.Rarity == gearTier[entry.Item.Id], "A cache piece of gear has no look rolled at its tier")
	end
end
local previewReply = handlers.StreakPreviews(player)
local call = previewCalls[#previewCalls]
check(previewReply.Ok and call and call[1] == "A", "The cache's 3D previews weren't asked for")
local asked = 0
for tag, payload in call[2] do
	asked += 1
	local offer = string.match(tag, "^" .. cache.Id .. "/(.+)$")
	check(offer and payload.Kind == "Gear", "A preview isn't keyed <cache>/<offer>")
end
check(asked == gear, "Not every piece of gear got a preview")
for _, entry in cache.Items do
	if entry.Item.Kind == "Gear" then
		check(entry.Item.Quality == Rules.Milestones[1].Quality and entry.Item.Slot, "A cache piece of gear is malformed")
	end
end
check(gems == Rules.Milestones[1].Gems and gear == Rules.GearOffered, "The cache isn't its free gems and six pieces of gear")
check(counts.UltraRare == Rules.Milestones[1].UltraRare and counts.Rare == Rules.GearOffered - counts.UltraRare, "The 10-win cache's rarities are off")

-- A loss ends it; a new streak to 10 the same season pays nothing more.
check(Server.onRankedResult(player, false, 300) == 0, "A loss didn't end the streak")
for i = 1, 10 do
	Server.onRankedResult(player, true, 400 + i)
end
check(profile.Duel.RankedStreak == 10 and #profile.Duel.StreakCaches == 1, "The 10-win cache paid twice in a season")
check(profile.Duel.BestRankedStreak == 10, "The best streak wasn't kept")

-- Claiming: exactly three of the gear (the gems aren't picks: they're all
-- yours); they arrive with every gem; the other gear goes to the Vault with
-- your commission on it.
local view = handlers.StreakCaches(player)
check(view.Ok and #view.Caches == 1 and view.Streak == 10 and view.Next == 20, "The cache list is wrong")
local gearIds, gemIds = {}, {}
for _, entry in view.Caches[1].Items do
	table.insert(if entry.Free then gemIds else gearIds, entry.OfferId)
end
check(#gemIds == Rules.Milestones[1].Gems and #gearIds == Rules.GearOffered, "The cache list doesn't mark its free gems")
check(not handlers.StreakClaim(player, cache.Id, { gearIds[1] }).Ok, "Claimed with one pick")
check(not handlers.StreakClaim(player, cache.Id, { gearIds[1], gearIds[1], gearIds[1] }).Ok, "Claimed the same piece three times")
check(not handlers.StreakClaim(player, cache.Id, { gemIds[1], gearIds[1], gearIds[2] }).Ok, "A free gem counted as a pick")
check(not handlers.StreakClaim(player, "nope", { gearIds[1], gearIds[2], gearIds[3] }).Ok, "Claimed a cache that isn't there")
local keep = { gearIds[1], gearIds[3], gearIds[6] }
local result = handlers.StreakClaim(player, cache.Id, keep)
check(result.Ok, "A fair claim failed: " .. tostring(result.Message))
check(#profile.Gems == Rules.Milestones[1].Gems, "The free gems didn't all arrive")
local gearOwned = 0
for _, list in profile.Owned do
	for _ in list do
		gearOwned += 1
	end
end
check(gearOwned == Rules.Picks, "The kept gear didn't arrive")
check(#vaulted == Rules.GearOffered - Rules.Picks, "The leftovers didn't all go to the Market")
for _, v in vaulted do
	local item = v[1]
	local tier = if item.Kind == "Gem" then item.Gem.Tier else (if gearTier[item.Id] == 4 then "UltraRare" else "Rare")
	local floor = if item.Kind == "Gem" then Rules.VaultGemFloor[tier] else Rules.VaultGear[tier][item.Quality]
	check(v[2] >= floor and string.find(v[3], Rules.VaultName, 1, true), "A Vault listing is mispriced or unlabelled")
	check(item.Kind == "Gear", "A free gem went to the Market")
	local cut = v[4]
	check(type(cut) == "table" and cut.UserId == player.UserId and cut.Rate == Rules.Commission, "A Vault listing carries no commission for you")
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
check(big and big.Wins == 100 and #big.Items == Rules.get(100).Gems + Rules.GearOffered, "The 100-win cache is wrong")
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
check(#top.Items == Rules.get(200).Gems + Rules.GearOffered and topCounts.UltraRare == Rules.GearOffered, "The 200-win cache's gear isn't all Ultra-Rare")
-- A full gem bag stops the claim before anything moves.
local config = shared("Config")
local before = #vaulted
for i = 1, (config.MaxGems or 200) do
	profile.Gems[i] = { Id = "full" .. i }
end
local bigGear = {}
for _, entry in big.Items do
	if not entry.Free then
		table.insert(bigGear, entry.OfferId)
	end
end
check(
	not handlers.StreakClaim(player, big.Id, { bigGear[1], bigGear[2], bigGear[3] }).Ok and #vaulted == before,
	"Claimed into a full gem bag (the free gems need room too)"
)

-- Every roll's gear: swords (the standard ones) are the only weapons, one
-- at most, so the armor and shields always outnumber what you keep: some
-- armor is always left over for the Market. No guns, hammers, axes, lances.
do
	local weaponType = {}
	for _, w in shared("ExpandedItemTraits").Catalog.Weapons do
		weaponType[w.Id] = w.WeaponType
	end
	local seenSword = false
	for _, m in Rules.Milestones do
		for _ = 1, 25 do
			local c = Server.rollCache(m)
			local weapons, armor = 0, 0
			for _, entry in c.Items do
				if entry.Item.Kind == "Gear" then
					if entry.Item.Slot == "Weapon" then
						weapons += 1
						seenSword = true
						check(weaponType[entry.Item.Id] == "Sword", "A cache rolled a weapon that isn't a sword: " .. entry.Item.Id)
					else
						armor += 1
					end
				end
			end
			check(weapons <= Rules.MaxWeapons, "A cache rolled more than one sword")
			check(armor > Rules.Picks, "A cache could leave no armor over for the Market")
		end
	end
	check(seenSword, "No cache ever rolled a sword")
end

-- DEV test caches: test admins only; first in line; no coins, no title,
-- nothing marked paid; a new one replaces the last; leftovers vaulted like
-- any roll's.
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
	check(#reply.Caches[1].Items == m.Gems + Rules.GearOffered, "The " .. wins .. "-win test cache holds the wrong number of pieces")
	check(cacheRarities(profile.Duel.StreakCaches[1]).UltraRare == m.UltraRare, "The " .. wins .. "-win test cache has the wrong Ultra-Rares")
	check(#profile.Duel.StreakCaches == realCount + 1, "Test caches piled up")
end
local firstId = profile.Duel.StreakCaches[1].Id
check(handlers.DevStreakCache(player, 10).Caches[1].Id ~= firstId, "Two test caches shared an id (the roll wouldn't replay)")
check(profile.Coins == coinsBefore and profile.Duel.StreakPaid == paidBefore and not profile.Cosmetics.Owned.TitleStreak30, "A test cache paid out")
local dev = profile.Duel.StreakCaches[1]
local vaultedBefore = #vaulted
local devGear = {}
for _, entry in dev.Items do
	if not entry.Free then
		table.insert(devGear, entry.OfferId)
	end
end
local devClaim = handlers.StreakClaim(player, dev.Id, { devGear[1], devGear[2], devGear[3] })
check(devClaim.Ok and #profile.Gems == Rules.get(10).Gems, "A test cache couldn't be claimed")
check(#vaulted == vaultedBefore + Rules.GearOffered - Rules.Picks, "A test cache's leftovers didn't go to the Market")
check(#profile.Duel.StreakCaches == realCount, "The claimed test cache stayed")

-- Boss caches (Shared.BossLoot, ArenaStreaks.bossCache): the boss's own gem
-- first, free; its threat's free gems, of its element; six pieces of gear to
-- keep three of, Ultra Rare by its threat and FocusCount of them its
-- favourite kind; the rest up on the Market from the Rift Vault.
do
	local BossLoot = shared("BossLoot")
	local Bosses = shared("DungeonRules").Bosses
	local Slots = shared("EquipmentSlots")
	profile.Gems = {}
	local ids = {}
	for _, boss in Bosses do
		local rules = BossLoot.Threats[BossLoot.threat(boss)]
		for _ = 1, 8 do
			local gem = stubs.Dungeons.bossGem(boss.Element, 4)
			local before = #profile.Duel.StreakCaches
			local c = Server.bossCache(player, boss, gem, "Rift")
			check(c and #profile.Duel.StreakCaches == before + 1 and profile.Duel.StreakCaches[before + 1] == c, "A boss cache wasn't saved")
			check(not ids[c.Id], "Two boss caches shared an id")
			ids[c.Id] = true
			check(fired[#fired][1] == "BossCache" and fired[#fired][2].Id == c.Id and fired[#fired][2].Boss == boss.Name, "Not told of the boss cache")
			check(c.Kind == "Boss" and c.Boss == boss.Name and c.BossId == boss.Id and c.Source == "Rift", "A boss cache doesn't say whose it is")
			check(c.Threat == BossLoot.threat(boss) and c.Element == boss.Element and c.Focus == boss.Loot, "A boss cache's threat, element or favourite")
			check(c.Items[1].Free and c.Items[1].Item.Gem == gem and c.Items[1].Rarity == "UltraRare", "The boss's own gem isn't first, free")
			local free, gear, ultra, focus, weapons = 0, 0, 0, 0, 0
			for _, entry in c.Items do
				if entry.Free then
					free += 1
					check(entry.Item.Kind == "Gem" and entry.Item.Gem.Element == boss.Element, boss.Id .. "'s cache has a gem not of its element")
				else
					gear += 1
					local kind = Slots.Definitions[entry.Item.Slot].Kind
					focus += if kind == boss.Loot then 1 else 0
					weapons += if kind == "Weapons" then 1 else 0
					ultra += if entry.Rarity == "UltraRare" then 1 else 0
					check(gearTier[entry.Item.Id] == Rules.GearTier[entry.Rarity] and entry.Item.Quality == rules.Quality, "A boss cache's gear isn't the rarity or quality it says")
				end
			end
			check(free == 1 + rules.Gems, boss.Id .. "'s cache has the wrong free gems")
			check(gear == Rules.GearOffered and ultra == rules.UltraRare, boss.Id .. "'s cache has the wrong gear")
			check(focus >= BossLoot.FocusCount, boss.Id .. "'s cache doesn't favour its " .. boss.Loot)
			check(weapons <= (if boss.Loot == "Weapons" then BossLoot.FocusCount else Rules.MaxWeapons), boss.Id .. "'s cache has too many swords")
			table.remove(profile.Duel.StreakCaches)
		end
	end
	-- Higher threats are richer: more Ultra Rare gear, never fewer gems.
	for t = 2, #BossLoot.Threats do
		check(BossLoot.Threats[t].UltraRare > BossLoot.Threats[t - 1].UltraRare, "Threat " .. t .. " isn't richer")
	end
	-- On the list it says whose it is; claimed, three of its gear and every
	-- gem arrive, the rest go up from the Rift Vault with your cut.
	for _, list in profile.Owned do
		table.clear(list)
	end
	local boss = Bosses[1]
	local c = Server.bossCache(player, boss, stubs.Dungeons.bossGem(boss.Element, 5), "Dungeon")
	local listed
	for _, entry in handlers.StreakCaches(player).Caches do
		if entry.Id == c.Id then
			listed = entry
		end
	end
	check(listed and listed.Kind == "Boss" and listed.Boss == boss.Name and listed.Source == "Dungeon", "The cache list doesn't show the boss cache")
	check(listed.Threat == c.Threat and listed.Element == boss.Element and listed.Focus == boss.Loot, "The cache list loses the boss's threat or element")
	check(c.Items[1].Rarity == "Legendary", "A tier-5 boss's gem isn't Legendary")
	local pick = {}
	for _, entry in c.Items do
		if not entry.Free and #pick < Rules.Picks then
			table.insert(pick, entry.OfferId)
		end
	end
	local vaultedBefore = #vaulted
	local claimed = handlers.StreakClaim(player, c.Id, pick)
	check(claimed.Ok and string.find(claimed.Message, BossLoot.VaultName, 1, true), "A boss cache's claim doesn't name the Rift Vault")
	check(#profile.Gems == 1 + BossLoot.Threats[BossLoot.threat(boss)].Gems, "A boss cache's gems didn't all arrive")
	check(#vaulted == vaultedBefore + Rules.GearOffered - Rules.Picks, "A boss cache's leftovers didn't go to the Market")
	for i = vaultedBefore + 1, #vaulted do
		local v = vaulted[i]
		check(string.find(v[3], BossLoot.VaultName, 1, true) and string.find(v[3], boss.Name, 1, true), "A boss cache's leftover isn't labelled the Rift Vault's")
		check(v[4].UserId == player.UserId and v[4].Rate == Rules.Commission, "A boss cache's leftover carries no commission")
	end
	-- DEV test boss caches: admins only, a real threat, first in line, one
	-- at a time, and no "BossCache" word (the DEV panel opens it itself).
	profile.Gems = {}
	check(not handlers.DevBossCache(outsider, 2).Ok, "A non-admin rolled a test boss cache")
	check(not handlers.DevBossCache(player, 4).Ok and not handlers.DevBossCache(player, "x").Ok, "A test boss cache for no threat")
	local real = #profile.Duel.StreakCaches
	for threat = 1, 3 do
		local firedBefore = #fired
		local reply = handlers.DevBossCache(player, threat)
		check(reply.Ok and reply.Caches[1].Dev and reply.Caches[1].Kind == "Boss" and reply.Caches[1].Threat == threat, "The threat " .. threat .. " test boss cache isn't first in line")
		check(#profile.Duel.StreakCaches == real + 1, "Test boss caches piled up")
		check(#fired == firedBefore, "A test boss cache was announced")
	end
end

print(string.format("PASS: %d arena streak checks (milestones 10-200, free gems + pick 3 of 6 gear, claims, Arena Vault with commission, DEV test caches, boss caches by threat)", checks))
