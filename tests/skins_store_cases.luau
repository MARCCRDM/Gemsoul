-- lune run tests/skins_store_cases.luau <repo>
-- Skins and selling: the cosmetics catalog (every skin and suit can be
-- drawn, every Robux item has a product slot, exclusives are never sold),
-- Robux receipts (granted once per purchase, each kind of product), the
-- Season premium track, the Starter Pack window, and promo codes (once each,
-- expiry, junk, brute force).
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

-- Shared modules, loaded with a `require` that resolves script.Parent.X.
local loaded = {}
local sharedEnv
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = sharedEnv })()
	end
	return loaded[name]
end
local parent = setmetatable({}, { __index = function(_, k) return k end })
sharedEnv = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	UDim2 = roblox.UDim2,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
	script = { Parent = parent },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Cosmetics = shared("Cosmetics")
local Store = shared("Store")
local Season = shared("Season")
local Referrals = shared("Referrals")
local FreeRewards = shared("FreeRewards")

-- Catalog -----------------------------------------------------------------------------
local equipment = fs.readFile(ROOT .. "/src/server/Systems/Equipment.luau")
local KINDS = { Trim = true, Back = true, Skin = true, Suit = true, Title = true }
local skins, suits, titles = 0, 0, 0
for id, cosmetic in Cosmetics.List do
	check(cosmetic.Id == id, id .. " has the wrong Id")
	check(KINDS[cosmetic.Kind], id .. " has an unknown kind")
	check(Cosmetics.SourceText ~= nil and (not cosmetic.Exclusive or Cosmetics.SourceText[cosmetic.Exclusive]), id .. " has an unknown source")
	check(not (cosmetic.Exclusive and (cosmetic.Robux or cosmetic.Price)), id .. " is exclusive but sold")
	check(not (cosmetic.Robux and cosmetic.Price), id .. " is sold for both coins and Robux")
	if cosmetic.Robux then
		check(Store.RobuxProducts[id] ~= nil, id .. " is sold for Robux but has no product slot")
		check(Store.robuxPrice(id) == cosmetic.Robux, id .. "'s Robux price doesn't show")
	end
	if cosmetic.Kind == "Skin" then
		skins += 1
		local drawn = (cosmetic.Look and string.find(equipment, "SKINS." .. cosmetic.Look .. " =", 1, true)) or cosmetic.Palette
		check(drawn, id .. " can't be drawn on a weapon")
	elseif cosmetic.Kind == "Suit" then
		suits += 1
		check(cosmetic.Palette and cosmetic.Palette.Plate and cosmetic.Palette.Glow and cosmetic.Palette.Under, id .. " has no palette")
	elseif cosmetic.Kind == "Title" then
		titles += 1
	elseif cosmetic.Kind == "Back" then
		check(cosmetic.Look and string.find(equipment, "BACKS." .. cosmetic.Look .. " =", 1, true), id .. " can't be built")
	end
end
check(skins >= 8 and suits >= 6 and titles >= 3, "The catalog is thinner than planned")
-- Every product slot buys something real.
for key in Store.RobuxProducts do
	local real = Store.bundle(key) or Store.Crates[key] or (Cosmetics.get(key) and Cosmetics.get(key).Robux)
		or key == "StarterPack" or key == "SeasonPremium"
	check(real, key .. " is a product slot for nothing")
	check(Store.robuxPrice(key), key .. " has no Robux price")
end
-- Shop order: on sale first, exclusives after.
local ordered = Cosmetics.ofKind("Skin")
local seenExclusive = false
for _, id in ordered do
	if Cosmetics.List[id].Exclusive then
		seenExclusive = true
	else
		check(not seenExclusive, "A skin on sale comes after an exclusive")
	end
end
-- Rewards point at real cosmetics.
for _, tier in Referrals.Tiers do
	check(Cosmetics.get(tier.Reward) and Cosmetics.get(tier.Reward).Exclusive == "Invite", tier.Reward .. " isn't an invite exclusive")
end
check(Cosmetics.get(FreeRewards.Group.Reward).Exclusive == "Group", "The group reward isn't a group exclusive")
check(Cosmetics.get(FreeRewards.Streak.Reward).Exclusive == "Streak", "The streak reward isn't a streak exclusive")
for level, reward in Season.Premium do
	check(level >= 1 and level <= Season.MaxLevel, "A premium reward is off the path")
	for _, id in reward.Cosmetics or {} do
		check(Cosmetics.get(id), "Premium level " .. level .. " gives an unknown cosmetic")
	end
end
for _, id in Store.StarterPack.Contents.Cosmetics do
	check(Cosmetics.get(id), "The Starter Pack gives an unknown cosmetic")
end
check(Cosmetics.get(Store.StarterPack.Contents.Cosmetics[1]).Exclusive == "Starter", "The Starter Pack's suit is sold elsewhere")

-- Codes and the streak (rules) ----------------------------------------------------------
check(FreeRewards.normalizeCode(" launch! ") == "LAUNCH", "A code typed loosely wasn't read")
check(FreeRewards.normalizeCode("") == nil and FreeRewards.normalizeCode(42) == nil, "Junk read as a code")
check(FreeRewards.normalizeCode(string.rep("A", 40)) == nil, "An overlong code was read")
check(not FreeRewards.streakEarned(6) and FreeRewards.streakEarned(7), "The streak threshold is wrong")
check(not FreeRewards.groupEnabled(), "The group reward is on with no group id")

-- The Starter Pack's window ----------------------------------------------------------------
check(not Store.starterOpen(nil, false, 1000), "Open before it was offered")
check(Store.starterOpen(1000, false, 1000 + 3600), "Closed during its window")
check(not Store.starterOpen(1000, true, 1001), "Still on offer once bought")
check(not Store.starterOpen(1000, false, 1000 + Store.StarterPack.Hours * 3600 + 1), "Open after its window")

-- Receipts, with fakes ---------------------------------------------------------------------
local profile
local function freshProfile()
	profile = {
		Coins = 0,
		Crates = {},
		Cosmetics = { Owned = {} },
		Season = { XP = 0, Claimed = {} },
		Boosts = { XPUntil = 0 },
		FirstJoin = 0,
	}
end
freshProfile()
local thePlayer = { UserId = 7 }
local handlers = {}
local saves = 0
local stubs = {
	Cosmetics = Cosmetics,
	ExpeditionEconomy = { legacyCredits = function() return 0 end },
	Season = Season,
	Store = Store,
	GemGenerator = { generate = function() return {} end },
	Gems = {
		award = function() return true end,
		random = function() return { NextInteger = function(_, a) return a end } end,
	},
	PlayerData = {
		get = function(player)
			return if player == thePlayer then profile else nil
		end,
		sync = function() end,
		newGemId = function() return "g" end,
		addGem = function() return true end,
		save = function()
			saves += 1
		end,
		setCosmetic = function(_, kind, id)
			profile.Cosmetics[kind] = id
		end,
		spendCoins = function(_, n)
			if profile.Coins < n then
				return false
			end
			profile.Coins -= n
			return true
		end,
	},
	Shop = {
		register = function(name, fn)
			handlers[name] = fn
		end,
		reply = function(ok, message, extra)
			local r = extra or {}
			r.Ok, r.Message = ok, message
			return r
		end,
	},
}
local Granted, NotYet = "PurchaseGranted", "NotProcessedYet"
local receiptFn = nil
local serverEnv = setmetatable({
	Enum = setmetatable({ ProductPurchaseDecision = { PurchaseGranted = Granted, NotProcessedYet = NotYet } }, { __index = roblox.Enum }),
	Color3 = roblox.Color3,
	game = {
		GetService = function(_, name)
			if name == "MarketplaceService" then
				return setmetatable({}, { __newindex = function(_, k, v)
					if k == "ProcessReceipt" then
						receiptFn = v
					end
				end })
			elseif name == "Players" then
				return {
					GetPlayerByUserId = function(_, id)
						return if id == 7 then thePlayer else nil
					end,
					GetPlayers = function()
						return {}
					end,
					PlayerAdded = { Connect = function() end },
					PlayerRemoving = { Connect = function() end },
				}
			end
			return { Shared = parent }
		end,
	},
	script = { Parent = parent },
	require = function(name)
		return stubs[name]
	end,
	os = setmetatable({ clock = function() return 1000 end }, { __index = os }),
	task = { wait = function() return 0.5 end, spawn = function(fn, ...) fn(...) end },
}, { __index = _G })
-- Switch every product on, with ids 1001, 1002, ...
local keys, ids = {}, {}
for key in Store.RobuxProducts do
	table.insert(keys, key)
end
table.sort(keys)
for i, key in keys do
	Store.RobuxProducts[key] = 1000 + i
	ids[key] = 1000 + i
end
local StoreServer = luau.load(fs.readFile(ROOT .. "/src/server/Systems/StoreServer.luau"), { debugName = "StoreServer", environment = serverEnv })()
stubs.StoreServer = StoreServer
StoreServer.start()
check(receiptFn ~= nil, "Receipts aren't handled with products on")
local purchase = 0
local function buy(key, purchaseId)
	purchase += 1
	return receiptFn({ PlayerId = 7, ProductId = ids[key], PurchaseId = purchaseId or ("p" .. purchase) })
end
-- A weapon skin: yours, and on.
check(buy("SkinPlasma", "a1") == Granted, "A skin purchase wasn't granted")
check(profile.Cosmetics.Owned.SkinPlasma and profile.Cosmetics.Skin == "SkinPlasma", "The bought skin isn't owned and worn")
check(saves >= 1, "A paid purchase wasn't saved at once")
-- The same receipt again (Roblox retries): granted, not given twice.
profile.Cosmetics.Owned.SkinPlasma = nil
check(buy("SkinPlasma", "a1") == Granted and not profile.Cosmetics.Owned.SkinPlasma, "A retried receipt was granted twice")
-- A suit.
check(buy("SuitRoyal") == Granted and profile.Cosmetics.Suit == "SuitRoyal", "A suit purchase wasn't worn")
-- The Starter Pack: its contents, its suit on, and it's marked bought.
check(buy("StarterPack") == Granted, "The Starter Pack wasn't granted")
check(profile.StarterBought and profile.Cosmetics.Owned.SuitIgnition and profile.Cosmetics.Suit == "SuitIgnition", "The Starter Pack's suit isn't owned and worn")
check(profile.Coins >= Store.StarterPack.Contents.Coins and profile.Crates.GeodeCrate == Store.StarterPack.Contents.Crates.GeodeCrate, "The Starter Pack's coins and caches are missing")
-- A product that isn't ours, or a player who isn't here: not yet.
check(receiptFn({ PlayerId = 7, ProductId = 999999, PurchaseId = "x" }) == NotYet, "An unknown product was granted")
check(receiptFn({ PlayerId = 8, ProductId = ids.SkinVoid, PurchaseId = "y" }) == NotYet, "A purchase with nobody here was granted")
-- Season premium: unlocks the track; claiming gives both rewards.
check(buy("SeasonPremium") == Granted and profile.Season.Premium == true, "Season premium wasn't unlocked")
profile.Season.XP = 100000
local claimed = handlers.ClaimSeason(thePlayer, "all")
check(claimed.Ok, "Claiming the season failed")
check(profile.Cosmetics.Owned.SuitLunar and profile.Cosmetics.Owned.SkinLunar and profile.Cosmetics.Owned.TitleLunar, "The premium track's cosmetics weren't given")
check(not handlers.ClaimSeason(thePlayer, "all").Ok, "The season paid out twice")
-- Equipping the new kinds.
check(handlers.EquipCosmetic(thePlayer, "Title", "TitleLunar").Ok and profile.Cosmetics.Title == "TitleLunar", "A title can't be worn")
check(not handlers.EquipCosmetic(thePlayer, "Suit", "SuitNeon").Ok, "A suit you don't own was worn")
-- Testing prices: any skin or suit for a few coins, worn straight away.
local Config = shared("Config")
if Config.TestCosmeticPrice then
	check(Cosmetics.coinPrice(Cosmetics.get("SuitNeon")) == Config.TestCosmeticPrice, "Suits have no testing price")
	profile.Coins += 100
	local before = profile.Coins
	check(handlers.BuyCosmetic(thePlayer, "SuitNeon").Ok and profile.Cosmetics.Owned.SuitNeon, "A suit couldn't be bought for coins while testing")
	check(profile.Coins == before - Config.TestCosmeticPrice and profile.Cosmetics.Suit == "SuitNeon", "A coin-bought suit wasn't charged or worn")
	check(not handlers.BuyCosmetic(thePlayer, "SuitNeon").Ok, "A suit was bought twice")
end
check(Cosmetics.coinPrice(Cosmetics.get("TitleLunar")) == nil, "Titles must never have a coin price")
-- The Starter Pack goes on offer once.
freshProfile()
local offer = handlers.StarterOffer(thePlayer)
check(offer.Ok and offer.OfferedAt ~= nil, "The Starter Pack wasn't put on offer")
local first = profile.StarterOfferAt
handlers.StarterOffer(thePlayer)
check(profile.StarterOfferAt == first, "The offer's clock restarted")

-- Promo codes, with the real code list ---------------------------------------------------------
freshProfile()
stubs.Codes = luau.load(fs.readFile(ROOT .. "/src/server/Systems/Codes.luau"), { debugName = "Codes" })()
stubs.FreeRewards = FreeRewards
stubs.Referrals = Referrals
local clock = 1000
serverEnv.os = setmetatable({ clock = function() return clock end, time = os.time }, { __index = os })
local Free = luau.load(fs.readFile(ROOT .. "/src/server/Systems/FreeRewards.luau"), { debugName = "FreeRewards.server", environment = serverEnv })()
Free.start()
local code = next(stubs.Codes.List)
local result = handlers.RedeemCode(thePlayer, string.lower(code) .. " ")
check(result.Ok, "A real code (typed loosely) didn't redeem: " .. tostring(result.Message))
clock += 3
check(not handlers.RedeemCode(thePlayer, code).Ok, "A code redeemed twice")
clock += 3
check(not handlers.RedeemCode(thePlayer, "NOTACODE").Ok, "A made-up code redeemed")
check(not handlers.RedeemCode(thePlayer, "LAUNCH").Ok, "Tries 1 second apart weren't slowed down")
clock += 3
stubs.Codes.List.OLDCODE = { Reward = { Coins = 5 }, Expires = os.time() - 10 }
check(not handlers.RedeemCode(thePlayer, "OLDCODE").Ok, "An expired code redeemed")
clock += 3
local launch = handlers.RedeemCode(thePlayer, "LAUNCH")
check(launch.Ok == (code ~= "LAUNCH") or code == "LAUNCH", "LAUNCH didn't redeem")
check(profile.Cosmetics.Owned.TitleFounder and profile.Cosmetics.Title == "TitleFounder", "A code's title wasn't given and worn")
-- The group: off with no id set.
check(not handlers.CheckGroup(thePlayer).Ok, "The group reward paid out with no group set")
local state = handlers.FreeRewards(thePlayer)
check(state.Ok and state.Group.Enabled == false and #state.Invites.Tiers == #Referrals.Tiers and state.Streak.Days == 7, "The Free tab's state is incomplete")

-- The full collection's designs -------------------------------------------------------------
local PATTERNS = { Camo = true, Stripes = true, Trim = true }
local defaults, earnedHow = 0, true
for id, cosmetic in Cosmetics.List do
	local palette = cosmetic.Palette
	if palette then
		check(palette.Pattern == nil or PATTERNS[palette.Pattern], id .. " has an unknown pattern")
		check(
			(palette.Accent == nil) == (palette.Pattern == nil),
			id .. " has an accent with no pattern, or the reverse"
		)
		check(not (palette.Seams and cosmetic.Kind ~= "Suit"), id .. " asks for seams but isn't a suit")
		check(
			not ((palette.Blade or palette.Edge) and cosmetic.Kind ~= "Skin"),
			id .. " styles a blade but isn't a skin"
		)
	end
	if cosmetic.Exclusive == "Default" then
		defaults += 1
	end
	local earned = cosmetic.Exclusive == "Achievement"
		or cosmetic.Exclusive == "Ranked"
		or cosmetic.Exclusive == "Raid"
		or cosmetic.Exclusive == "Mining"
	if earned and not cosmetic.How then
		earnedHow = false
	end
	-- Loot drops from a crate that rolls its rarity.
	local loot = (cosmetic.Kind == "Skin" or cosmetic.Kind == "Suit")
		and not cosmetic.Exclusive
		and not cosmetic.Robux
		and not cosmetic.Price
	if loot then
		check(table.find(StoreServer.Loot, id), id .. " is loot but in no crate's pool")
		local drops = false
		for crateId, crate in Store.Crates do
			if cosmetic.Crate == nil or cosmetic.Crate == crateId then
				for _, roll in crate.Rolls do
					drops = drops or roll.Cosmetic == cosmetic.Rarity
				end
			end
		end
		check(drops, id .. " is loot but no crate rolls a " .. cosmetic.Rarity)
	end
	check(cosmetic.Crate == nil or Store.Crates[cosmetic.Crate], id .. " names a crate that doesn't exist")
end
check(defaults == 2, "Every miner should start with one skin and one suit")
check(earnedHow, "An earned look doesn't say how it's earned")
for _, level in { 15, 25 } do
	for _, id in Season.reward(level).Cosmetics or {} do
		check(Cosmetics.get(id), "Free track level " .. level .. " gives an unknown cosmetic")
	end
end
check(
	table.find(Season.reward(15).Cosmetics, "SkinCrater") and table.find(Season.reward(25).Cosmetics, "SuitMoonDust"),
	"The Season 1 free-track looks are missing"
)

print(string.format("PASS: %d skins & selling checks (%d skins, %d suits, %d titles; receipts once each, starter pack, season premium, codes)", checks, skins, suits, titles))
