-- lune run tests/arena_streak_cases.luau <repo>
-- Rewards (Shared.RewardRoll) and Ranked win streaks (Shared.ArenaStreak,
-- Systems/ArenaStreaks): every reward two pieces of gear, keep one, the
-- other to the Market from a vault with your commission; rarer the more
-- 1v1 you play; win rewards, streak milestones, boss caches.
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
local RewardRoll = shared("RewardRoll")

-- The milestones ------------------------------------------------------------------------
local wins = {}
local floorTier = 0
for i, m in Rules.Milestones do
	table.insert(wins, m.Wins)
	check(m.Quality >= 1 and m.Quality <= 4, m.Wins .. " has a bad gear quality")
	check(m.Coins > 0 and m.Name, m.Wins .. " is incomplete")
	local floor = Rules.floor(m)
	check(RewardRoll.Tier[floor] >= RewardRoll.Tier.Rare and RewardRoll.Tier[floor] >= floorTier, m.Wins .. "'s floor drops")
	floorTier = RewardRoll.Tier[floor]
	if i > 1 then
		local before = Rules.Milestones[i - 1]
		check(m.Wins > before.Wins and m.Coins > before.Coins and m.Quality >= before.Quality, m.Wins .. " is no better than the one before")
	end
	if m.Title then
		local title = Cosmetics.get(m.Title)
		check(title and title.Kind == "Title" and title.Exclusive == "Ranked" and title.How, m.Wins .. "'s title isn't a Ranked exclusive")
	end
end
check(table.concat(wins, ",") == "10,20,30,40,50,60,70,80,90,100,150,200", "The milestones aren't 10 ... 100, 150, 200")
check(
	Rules.floor(Rules.get(10)) == "Rare" and Rules.floor(Rules.get(40)) == "Rare" and Rules.floor(Rules.get(50)) == "UltraRare"
		and Rules.floor(Rules.get(100)) == "UltraRare" and Rules.floor(Rules.get(150)) == "Legendary" and Rules.floor(Rules.get(200)) == "Legendary",
	"A milestone's floor is off (Rare, Ultra-Rare from 50, Legendary from 150)"
)
check(#Rules.reached(9, 10) == 1 and Rules.reached(9, 10)[1].Wins == 10, "Reaching 10 didn't count")
check(#Rules.reached(10, 11) == 0 and #Rules.reached(0, 9) == 0, "A milestone counted twice or early")
check(Rules.next(0).Wins == 10 and Rules.next(10).Wins == 20 and Rules.next(100).Wins == 150 and Rules.next(200) == nil, "next() is off")
check(not Rules.counts({ StreakLastBeaten = 5 }, 5) and Rules.counts({ StreakLastBeaten = 5 }, 6), "The same foe twice running counted")
check(Rules.GearOffered == 2 and Rules.Picks == 1 and RewardRoll.Offered == 2 and RewardRoll.Picks == 1, "A reward isn't a pick of 1 from 2")
check(Rules.LegacyPicks == 3, "An old six-piece cache isn't still a pick of 3")
check(Rules.Commission == 0.25 and Rules.commission(10000) == 2500 and Rules.commission(15001) == 3750, "The commission isn't 25%")
-- Every rarity priced, each above the one below at every quality.
for i, name in RewardRoll.Rarities do
	local prices = Rules.VaultGear[name]
	check(prices and #prices == 4 and Rules.VaultGemFloor[name], name .. " has no Market price")
	check(Rules.vaultPrice({ Kind = "Gear", Quality = 4 }, nil, name) == prices[4], name .. " gear's Market price is off")
	for q = 2, 4 do
		check(prices[q] > prices[q - 1], name .. "'s prices don't rise with quality")
	end
	if i > 1 then
		check(prices[1] > Rules.VaultGear[RewardRoll.Rarities[i - 1]][4], name .. " isn't priced above the rarity below")
	end
end
check(
	Rules.vaultPrice({ Kind = "Gem", Gem = { Tier = "Rare" } }, 100) == Rules.VaultGemFloor.Rare
		and Rules.vaultPrice({ Kind = "Gem" }, 10000, "Rare") == 30000,
	"A gem's Market price is off"
)

-- The ladder (Shared.RewardRoll) ------------------------------------------------------------------
local lastMean, lastPlays = 0, -1
for i, band in RewardRoll.Bands do
	check(band.Plays > lastPlays and band.Name, "Band " .. i .. " is out of order")
	lastPlays = band.Plays
	local total = 0
	for _, name in RewardRoll.Rarities do
		total += band.Odds[name]
	end
	check(total == 100, band.Name .. "'s odds don't add to 100")
	local shares, sum, mean = RewardRoll.odds(band.Plays), 0, 0
	for _, name in RewardRoll.Rarities do
		sum += shares[name]
		mean += shares[name] * RewardRoll.Tier[name]
	end
	check(math.abs(sum - 1) < 1e-9, band.Name .. "'s shares don't add to 1")
	check(mean > lastMean, band.Name .. " rolls no rarer than the band below")
	lastMean = mean
	if i > 1 then
		local below = RewardRoll.Bands[i - 1].Odds
		check(band.Odds.Legendary >= below.Legendary and band.Odds.Common <= below.Common, band.Name .. "'s Legendary odds fell or Common rose")
	end
	local at, index, nextBand = RewardRoll.band(band.Plays)
	check(at == band and index == i and nextBand == RewardRoll.Bands[i + 1], band.Name .. " isn't where its plays put you")
	if band.Plays > 0 then
		check(RewardRoll.band(band.Plays - 1) == RewardRoll.Bands[i - 1], "One play short of " .. band.Name .. " is already in it")
	end
end
check(RewardRoll.Bands[1].Odds.Legendary == 0 and RewardRoll.Bands[#RewardRoll.Bands].Odds.Common == 0, "The ladder's ends are off")
-- A floor folds what's under it up into it.
do
	local raw, folded = RewardRoll.Bands[1].Odds, RewardRoll.odds(0, "Rare")
	check(folded.Common == 0 and folded.Uncommon == 0, "A Rare floor still rolls Common or Uncommon")
	check(math.abs(folded.Rare - (raw.Common + raw.Uncommon + raw.Rare) / 100) < 1e-9, "A Rare floor doesn't fold the commons up into Rare")
	check(math.abs(folded.UltraRare - raw.UltraRare / 100) < 1e-9, "A floor changed the odds above it")
	check(RewardRoll.rarity(0, nil, 0) == "Common" and RewardRoll.rarity(0, "Rare", 0) == "Rare", "The lowest roll isn't the floor")
	check(RewardRoll.rarity(0, nil, 1) == "UltraRare" and RewardRoll.rarity(400, nil, 1) == "Legendary", "The top roll isn't the rarest possible")
	check(RewardRoll.rarity(500, "Legendary", 0.3) == "Legendary", "A Legendary floor rolled under it")
	local rng = { NextNumber = function() return 0.5 end }
	check(#RewardRoll.rarities(0, nil, rng) == 2 and #RewardRoll.rarities(0, nil, rng, 6) == 6, "rarities() rolls the wrong count")
end
do
	local record = { Solo = 4 }
	check(RewardRoll.plays(nil) == 0 and RewardRoll.plays({}) == 0 and RewardRoll.plays(record) == 4, "Plays don't start from the 1v1 wins")
	RewardRoll.count(record)
	RewardRoll.count(record)
	check(record.OneVOne == 6 and RewardRoll.plays(record) == 6, "A 1v1 played didn't count")
	check(RewardRoll.pays({}, 5) and RewardRoll.pays({ RewardLastBeaten = 4 }, 5) and not RewardRoll.pays({ RewardLastBeaten = 5 }, 5), "pays() is off")
	check(not RewardRoll.pays(nil, 5), "A win with no record paid")
	check(RewardRoll.quality("Common") == 1 and RewardRoll.quality("Legendary") == 4 and RewardRoll.quality("Common", 3) == 3, "quality() is off")
	-- (a fair roll: a Rookie's rolls are mostly Common/Uncommon, a Legend's never)
	math.randomseed(11)
	local rnd = { NextNumber = function() return math.random() end }
	local low, high = 0, 0
	for _ = 1, 400 do
		for _, r in RewardRoll.rarities(0, nil, rnd) do
			low += if RewardRoll.Tier[r] <= 2 then 1 else 0
		end
		for _, r in RewardRoll.rarities(400, nil, rnd) do
			high += if RewardRoll.Tier[r] <= 2 then 1 else 0
		end
	end
	check(low > 500 and high == 0, "The ladder's rolls don't follow its odds")
end

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
local handlers, fired, vaulted, nextGem, previewCalls, notified = {}, {}, {}, 0, {}, {}
local stubs = {
	PlayerData = {
		get = function(p) return if p == player then profile else nil end,
		newGemId = function() nextGem += 1; return "gem" .. nextGem end,
		addCoins = function(_, n) profile.Coins += n end,
		sync = function() end,
	},
	Remotes = {
		Social = { FireClient = function(_, _, kind, data) table.insert(fired, { kind, data }) end },
		Notify = { FireClient = function(_, _, message) table.insert(notified, message) end },
	},
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
for _, name in { "ArenaStreak", "ArmorFamilies", "BossLoot", "RewardRoll", "Config", "Cosmetics", "DungeonRules", "ExpandedItemTraits", "GearRolls", "GemConfig", "GemRoller", "Market", "Season", "EquipmentSlots" } do
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
-- A reward's pieces: two of gear, none free, each the rarity it says, at
-- least `floor`, its quality at least its rarity's. Returns the rarities.
local function checkReward(c, floor, what)
	check(#c.Items == Rules.GearOffered and c.Picks == Rules.Picks, what .. " isn't two pieces to keep one of")
	local tiers = {}
	for _, entry in c.Items do
		check(not entry.Free and entry.Item.Kind == "Gear", what .. " has a free piece or a gem")
		check(gearTier[entry.Item.Id] == Rules.GearTier[entry.Rarity], what .. "'s gear isn't the rarity it says")
		check(RewardRoll.Tier[entry.Rarity] >= RewardRoll.Tier[floor or "Common"], what .. " rolled under its floor " .. tostring(floor))
		check(entry.Item.Quality >= RewardRoll.quality(entry.Rarity) and entry.Item.Slot, what .. "'s gear is malformed")
		check(type(entry.Item.Roll) == "table" and entry.Item.Roll.Rarity == gearTier[entry.Item.Id], what .. "'s gear has no look rolled at its tier")
		table.insert(tiers, entry.Rarity)
	end
	return tiers
end
local function gearIdsOf(c)
	local ids = {}
	for _, entry in c.Items do
		if not entry.Free then
			table.insert(ids, entry.OfferId)
		end
	end
	return ids
end

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
checkReward(cache, "Rare", "The 10-win cache")
check(cache.Plays == 0, "The cache doesn't say the plays it was rolled at")
-- Its 3D previews are asked for as group "A", one per piece, keyed "<cache>/<offer>".
local previewReply = handlers.StreakPreviews(player)
local call = previewCalls[#previewCalls]
check(previewReply.Ok and call and call[1] == "A", "The cache's 3D previews weren't asked for")
local asked = 0
for tag, payload in call[2] do
	asked += 1
	local offer = string.match(tag, "^" .. cache.Id .. "/(.+)$")
	check(offer and payload.Kind == "Gear", "A preview isn't keyed <cache>/<offer>")
end
check(asked == Rules.GearOffered, "Not every piece of gear got a preview")

-- A loss ends it; a new streak to 10 the same season pays nothing more.
check(Server.onRankedResult(player, false, 300) == 0, "A loss didn't end the streak")
for i = 1, 10 do
	Server.onRankedResult(player, true, 400 + i)
end
check(profile.Duel.RankedStreak == 10 and #profile.Duel.StreakCaches == 1, "The 10-win cache paid twice in a season")
check(profile.Duel.BestRankedStreak == 10, "The best streak wasn't kept")

-- The list: your ladder (plays, band, the next, odds) and the cache, one to keep.
profile.Duel.OneVOne = 12
local view = handlers.StreakCaches(player)
check(view.Ok and #view.Caches == 1 and view.Streak == 10 and view.Next == 20, "The cache list is wrong")
check(view.Caches[1].Picks == 1 and #view.Caches[1].Items == 2, "The cache list doesn't say pick one of two")
check(view.Plays == 12 and view.Band == "Regular" and view.NextBand and view.NextBand.Name == "Veteran" and view.NextBand.Plays == 25, "The list's ladder is off")
check(view.Odds and math.abs(view.Odds.Rare - 0.2) < 1e-9, "The list's odds aren't the band's")

-- Claiming: exactly one; the other goes to the Vault with your commission on it.
local gearIds = gearIdsOf(cache)
check(not handlers.StreakClaim(player, cache.Id, {}).Ok, "Claimed with no pick")
check(not handlers.StreakClaim(player, cache.Id, { gearIds[1], gearIds[2] }).Ok, "Claimed both pieces")
check(not handlers.StreakClaim(player, "nope", { gearIds[1] }).Ok, "Claimed a cache that isn't there")
local result = handlers.StreakClaim(player, cache.Id, { gearIds[2] })
check(result.Ok, "A fair claim failed: " .. tostring(result.Message))
check(string.find(result.Message, "The other went to the Market", 1, true) and string.find(result.Message, "25% of its sale", 1, true), "The claim message is off: " .. tostring(result.Message))
local gearOwned = 0
for _, list in profile.Owned do
	for _ in list do
		gearOwned += 1
	end
end
check(gearOwned == 1 and #profile.Gems == 0, "The kept piece didn't arrive (or something else did)")
check(#vaulted == 1, "The other piece didn't go to the Market")
do
	local v = vaulted[1]
	local item = v[1]
	check(item.Kind == "Gear" and item.Id == cache.Items[1].Item.Id, "The wrong piece went to the Market")
	check(v[2] == Rules.vaultPrice(item, nil, cache.Items[1].Rarity) and string.find(v[3], Rules.VaultName, 1, true), "A Vault listing is mispriced or unlabelled")
	check(type(v[4]) == "table" and v[4].UserId == player.UserId and v[4].Rate == Rules.Commission, "A Vault listing carries no commission for you")
end
check(#profile.Duel.StreakCaches == 0 and not handlers.StreakClaim(player, cache.Id, { gearIds[1] }).Ok, "A cache could be claimed twice")

-- Up to 100: Ultra-Rare at least, the title, the coins; 200: Legendary.
for _, at in { 100, 200 } do
	profile.Duel.StreakPaid = {}
	profile.Duel.RankedStreak = at - 1
	profile.Duel.StreakLastBeaten = nil
	local coins = profile.Coins
	Server.onRankedResult(player, true, 900 + at)
	local m = Rules.get(at)
	local big = profile.Duel.StreakCaches[#profile.Duel.StreakCaches]
	check(big and big.Wins == at and profile.Coins == coins + m.Coins, "The " .. at .. "-win cache didn't come or pay")
	checkReward(big, Rules.floor(m), "The " .. at .. "-win cache")
	check(profile.Cosmetics.Owned[m.Title], "The " .. at .. "-win title wasn't given")
end
table.clear(profile.Duel.StreakCaches)

-- Every rarity has gear to roll, and every roll: two pieces, a sword at
-- most (the standard ones only), so the other is armour or a shield.
do
	local weaponType = {}
	for _, w in shared("ExpandedItemTraits").Catalog.Weapons do
		weaponType[w.Id] = w.WeaponType
	end
	local seenSword = false
	for _, a in RewardRoll.Rarities do
		for _, b in RewardRoll.Rarities do
			for _ = 1, 6 do
				local c = Server.rollCache({ Wins = 0, Name = "Test", Gear = { a, b }, Plays = 0 })
				checkReward(c, "Common", a .. "+" .. b .. " roll")
				check(c.Items[1].Rarity == a and c.Items[2].Rarity == b, "A roll's pieces aren't the rarities rolled")
				local weapons = 0
				for _, entry in c.Items do
					if entry.Item.Slot == "Weapon" then
						weapons += 1
						seenSword = true
						check(weaponType[entry.Item.Id] == "Sword", "A roll handed out a weapon that isn't a sword: " .. entry.Item.Id)
					end
				end
				check(weapons <= Rules.MaxWeapons, "A roll handed out two swords")
				check(c.Items[1].Item.Id ~= c.Items[2].Item.Id, "A roll handed out the same piece twice")
			end
		end
	end
	check(seenSword, "No roll ever handed out a sword")
end

-- Win rewards: every 1v1 you win, two pieces by your plays.
do
	local before = #fired
	profile.Duel.OneVOne = 0
	local w = Server.winReward(player, 50)
	check(w and w.Kind == "Win" and w.Name == "Win Reward" and string.match(w.Id, "^win%d+_"), "A win didn't open a win reward")
	checkReward(w, "Common", "A win reward")
	check(fired[#fired][1] == "WinReward" and fired[#fired][2].Id == w.Id and #fired == before + 1, "Not told of the win reward")
	check(profile.Duel.RewardLastBeaten == 50, "The foe beaten wasn't kept")
	check(Server.winReward(player, 50) == nil, "Beating the same player twice running paid")
	local w2 = Server.winReward(player, 51)
	check(w2 and w2.Id ~= w.Id, "Another foe's win didn't pay")
	-- Claimed: one kept, the other up from the Arena Vault, labelled a win reward.
	local vaultedBefore = #vaulted
	local claimed = handlers.StreakClaim(player, w.Id, { gearIdsOf(w)[1] })
	check(claimed.Ok and #vaulted == vaultedBefore + 1, "A win reward couldn't be claimed")
	check(string.find(vaulted[#vaulted][3], "win reward", 1, true) and string.find(vaulted[#vaulted][3], Rules.VaultName, 1, true), "A win reward's leftover isn't labelled")
	-- At most RewardRoll.Waiting wait; past it, none (and you're told) until you claim.
	table.clear(profile.Duel.StreakCaches)
	for i = 1, RewardRoll.Waiting do
		check(Server.winReward(player, 1000 + i), "Win reward " .. i .. " didn't come")
	end
	check(Server.winReward(player, 2000) == nil and #profile.Duel.StreakCaches == RewardRoll.Waiting, "More win rewards waited than the cap")
	check(#notified > 0 and string.find(notified[#notified], "claim", 1, true), "Not told the win rewards are full")
	table.remove(profile.Duel.StreakCaches, 1)
	check(Server.winReward(player, 2001), "Claiming one didn't make room")
	-- The more you've played, the rarer: at 400 plays, never under Rare.
	table.clear(profile.Duel.StreakCaches)
	profile.Duel.OneVOne = 400
	for i = 1, 30 do
		local c = Server.winReward(player, 3000 + i)
		checkReward(c, "Rare", "A Legend's win reward")
		check(c.Plays == 400, "A win reward doesn't say its plays")
		table.remove(profile.Duel.StreakCaches)
	end
	profile.Duel.OneVOne = 0
end

-- A cache saved before (six pieces of gear, free gems, keep three) still
-- lists and claims as it was.
do
	local legacy = Server.rollCache({ Wins = 10, Name = "Old", Gear = { "Rare", "Rare", "Rare", "Rare", "Rare", "UltraRare" } })
	legacy.Picks, legacy.Id = nil, "legacy1"
	table.insert(legacy.Items, 1, { Item = { Kind = "Gem", Gem = { Id = "oldgem", Tier = "Rare" } }, Name = "Gem", Rarity = "Rare", Free = true })
	for i, entry in legacy.Items do
		entry.OfferId = tostring(i)
	end
	profile.Duel.StreakCaches = { legacy }
	profile.Gems = {}
	local listed = handlers.StreakCaches(player).Caches[1]
	check(listed.Picks == Rules.LegacyPicks, "An old cache doesn't list as keep three")
	local ids = gearIdsOf(legacy)
	check(not handlers.StreakClaim(player, legacy.Id, { ids[1] }).Ok, "An old cache claimed with one pick")
	local vaultedBefore = #vaulted
	local ok = handlers.StreakClaim(player, legacy.Id, { ids[1], ids[2], ids[3] })
	check(ok.Ok and #vaulted == vaultedBefore + 3 and #profile.Gems == 1, "An old cache didn't claim three and vault three")
	check(string.find(ok.Message, "The other 3", 1, true) and string.find(ok.Message, "each sale", 1, true), "An old cache's claim message is off")
end

-- DEV test caches: test admins only; first in line; no coins, no title,
-- nothing marked paid; a new one replaces the last; leftovers vaulted like
-- any roll's.
profile.Gems = {}
local outsider = { UserId = 8, DisplayName = "Not Admin", SetAttribute = function() end }
check(not handlers.DevStreakCache(outsider, 10).Ok, "A non-admin rolled a test cache")
check(not handlers.DevStreakCache(player, 15).Ok and not handlers.DevStreakCache(player, "x").Ok, "A test cache rolled for no milestone")
local coinsBefore, paidBefore = profile.Coins, profile.Duel.StreakPaid
profile.Cosmetics.Owned.TitleStreak30 = nil
local realCount = #profile.Duel.StreakCaches
for _, at in { 10, 20, 30, 40, 50, 150 } do
	local reply = handlers.DevStreakCache(player, at)
	check(reply.Ok and reply.Caches[1].Wins == at and reply.Caches[1].Dev, "The " .. at .. "-win test cache isn't first in line")
	checkReward(profile.Duel.StreakCaches[1], Rules.floor(Rules.get(at)), "The " .. at .. "-win test cache")
	check(#profile.Duel.StreakCaches == realCount + 1, "Test caches piled up")
end
local firstId = profile.Duel.StreakCaches[1].Id
check(handlers.DevStreakCache(player, 10).Caches[1].Id ~= firstId, "Two test caches shared an id (the roll wouldn't replay)")
check(profile.Coins == coinsBefore and profile.Duel.StreakPaid == paidBefore and not profile.Cosmetics.Owned.TitleStreak30, "A test cache paid out")
local dev = profile.Duel.StreakCaches[1]
local vaultedBefore = #vaulted
local devClaim = handlers.StreakClaim(player, dev.Id, { gearIdsOf(dev)[1] })
check(devClaim.Ok, "A test cache couldn't be claimed")
check(#vaulted == vaultedBefore + 1, "A test cache's leftover didn't go to the Market")
check(#profile.Duel.StreakCaches == realCount, "The claimed test cache stayed")

-- Boss caches (Shared.BossLoot, ArenaStreaks.bossCache): two pieces of gear
-- to keep one of, at least its threat's floor and quality, FocusCount of
-- them its favourite kind; the other up on the Market from the Rift Vault.
do
	local BossLoot = shared("BossLoot")
	local Bosses = shared("DungeonRules").Bosses
	local Slots = shared("EquipmentSlots")
	profile.Gems = {}
	local ids = {}
	for t = 2, #BossLoot.Threats do
		check(RewardRoll.Tier[BossLoot.Threats[t].Floor] > RewardRoll.Tier[BossLoot.Threats[t - 1].Floor], "Threat " .. t .. "'s floor isn't higher")
	end
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
			checkReward(c, rules.Floor, boss.Id .. "'s cache")
			local focus, weapons = 0, 0
			for _, entry in c.Items do
				local kind = Slots.Definitions[entry.Item.Slot].Kind
				focus += if kind == boss.Loot then 1 else 0
				weapons += if kind == "Weapons" then 1 else 0
				check(entry.Item.Quality >= rules.Quality, boss.Id .. "'s cache gear is under its threat's quality")
			end
			check(focus >= BossLoot.FocusCount, boss.Id .. "'s cache doesn't favour its " .. boss.Loot)
			check(weapons <= Rules.MaxWeapons, boss.Id .. "'s cache has too many swords")
			table.remove(profile.Duel.StreakCaches)
		end
	end
	-- On the list it says whose it is; claimed, one arrives, the other goes
	-- up from the Rift Vault with your cut.
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
	check(listed and listed.Kind == "Boss" and listed.Boss == boss.Name and listed.Source == "Dungeon" and listed.Picks == 1, "The cache list doesn't show the boss cache")
	check(listed.Threat == c.Threat and listed.Element == boss.Element and listed.Focus == boss.Loot, "The cache list loses the boss's threat or element")
	local before = #vaulted
	local claimed = handlers.StreakClaim(player, c.Id, { gearIdsOf(c)[1] })
	check(claimed.Ok and string.find(claimed.Message, BossLoot.VaultName, 1, true), "A boss cache's claim doesn't name the Rift Vault")
	check(#profile.Gems == 0 and #vaulted == before + 1, "A boss cache's leftover didn't go to the Market (or a gem came)")
	local v = vaulted[#vaulted]
	check(string.find(v[3], BossLoot.VaultName, 1, true) and string.find(v[3], boss.Name, 1, true), "A boss cache's leftover isn't labelled the Rift Vault's")
	check(v[4].UserId == player.UserId and v[4].Rate == Rules.Commission, "A boss cache's leftover carries no commission")
	-- DEV test boss caches: admins only, a real threat, first in line, one
	-- at a time, and no "BossCache" word (the DEV panel opens it itself).
	check(not handlers.DevBossCache(outsider, 2).Ok, "A non-admin rolled a test boss cache")
	check(not handlers.DevBossCache(player, 4).Ok and not handlers.DevBossCache(player, "x").Ok, "A test boss cache for no threat")
	local real = #profile.Duel.StreakCaches
	for threat = 1, 3 do
		local firedBefore = #fired
		local reply = handlers.DevBossCache(player, threat)
		check(reply.Ok and reply.Caches[1].Dev and reply.Caches[1].Kind == "Boss" and reply.Caches[1].Threat == threat, "The threat " .. threat .. " test boss cache isn't first in line")
		checkReward(profile.Duel.StreakCaches[1], BossLoot.Threats[threat].Floor, "The threat " .. threat .. " test boss cache")
		check(#profile.Duel.StreakCaches == real + 1, "Test boss caches piled up")
		check(#fired == firedBefore, "A test boss cache was announced")
	end
end

print(string.format("PASS: %d reward checks (two pieces keep one, the 1v1 ladder, win rewards, streak milestones 10-200, boss caches, Vault with commission, old caches, DEV caches)", checks))
