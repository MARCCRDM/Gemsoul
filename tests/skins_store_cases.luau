-- lune run tests/skins_store_cases.luau <repo>
-- Skins and selling: the cosmetics catalog (every skin, suit and pickaxe can
-- be drawn, every Robux item has a product slot, exclusives are never sold),
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
local KINDS = { Trim = true, Back = true, Skin = true, Suit = true, Pick = true, Title = true }
local skins, suits, titles, picks = 0, 0, 0, 0
local impacts = fs.readFile(ROOT .. "/src/client/Modules/PickImpacts.luau")
local pickaxeSource = fs.readFile(ROOT .. "/src/shared/PickaxeLooks.luau")
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
	elseif cosmetic.Kind == "Pick" then
		picks += 1
		local impact = string.match(pickaxeSource, "LOOKS%." .. id .. " = {%s*Impact = \"(%w+)\"")
		check(impact, id .. " has no pickaxe model (PickaxeLooks)")
		check(string.find(impacts, "function LOOKS." .. impact .. "(", 1, true), id .. "'s hit (" .. tostring(impact) .. ") isn't drawn")
	elseif cosmetic.Kind == "Title" then
		titles += 1
	elseif cosmetic.Kind == "Back" then
		check(cosmetic.Look and string.find(equipment, "BACKS." .. cosmetic.Look .. " =", 1, true), id .. " can't be built")
	end
end
check(skins >= 8 and suits >= 6 and titles >= 3 and picks >= 9, "The catalog is thinner than planned")
-- Every product slot buys something real.
for key in Store.RobuxProducts do
	local real = Store.bundle(key) or Store.kitsOf(key) or (Cosmetics.get(key) and Cosmetics.get(key).Robux)
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
	MinerRoster = { Count = 3 },
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
check(profile.Coins >= Store.StarterPack.Contents.Coins and profile.Cosmetics.Owned.PickBone and profile.Cosmetics.Owned.SkinMolten, "The Starter Pack's coins and looks are missing")
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
check(Cosmetics.coinPrice(Cosmetics.get("SkinCrusader")) == nil, "Exclusives must never have a coin price")

-- Bundles, squad kits and The Vault -----------------------------------------------------------
-- Every bundle holds real looks, costs less than its looks one by one, and
-- never sells power (gems, crates).
for _, key in { "Welcome", "Rustbucket", "Brainrot", "Circuit", "DeepSpace", "SolarForge", "Royal", "Vault", "StarterPack" } do
	local reward = Store.contents(key)
	check(reward ~= nil, key .. " has no contents")
	for _, id in reward.Cosmetics or {} do
		check(Cosmetics.get(id), key .. " gives an unknown cosmetic: " .. id)
	end
	check(not (reward :: any).Crates and not reward.Stones and not reward.CutGems, key .. " sells random loot or power")
	check(Store.savings(key) > 0, key .. " isn't cheaper than its looks one by one")
end
-- The Vault holds every look sold on its own.
local vault = Store.contents("Vault")
for id, cosmetic in Cosmetics.List do
	if cosmetic.Robux then
		check(table.find(vault.Cosmetics, id), "The Vault is missing " .. id)
	end
end
check(table.find(vault.Cosmetics, "TitleCollector") and not table.find(vault.Cosmetics, "SuitIgnition"), "The Vault's exclusives are wrong")
-- Kits: every choice of one, two or three has a product and the ladder's price.
local kitIds = {}
for _, kit in Store.Kits do
	table.insert(kitIds, kit.Id)
end
check(Store.kitKey({ kitIds[3], kitIds[1] }) == Store.kitKey({ kitIds[1], kitIds[3] }), "A kit choice's key depends on the order picked")
check(Store.kitKey({}) == nil and Store.kitKey({ "Nope" }) == nil, "A bad kit choice made a key")
local choices = 0
for mask = 1, 2 ^ #kitIds - 1 do
	local pick = {}
	for i, id in kitIds do
		if bit32.band(mask, 2 ^ (i - 1)) ~= 0 then
			table.insert(pick, id)
		end
	end
	local key = Store.kitKey(pick)
	choices += 1
	check(key and Store.RobuxProducts[key] ~= nil, "No product for kits " .. table.concat(pick, "+"))
	check(Store.robuxPrice(key) == Store.KitPrices[#pick], key .. " isn't priced on the ladder")
	check(#(Store.kitsOf(key) or {}) == #pick, key .. " doesn't read back as its kits")
	check(Store.savings(key) > 0, key .. " saves nothing")
end
check(choices == 7, "Three kits should make seven choices")
check(table.find(Store.contents(Store.kitKey(kitIds)).Cosmetics, "TitleSquad"), "All three kits don't add the squad title")
check(not table.find(Store.contents(Store.kitKey({ kitIds[1] })).Cosmetics, "TitleSquad"), "One kit gives the squad title")
-- Who can buy what.
local T0 = 1000000
check(Store.canBuy("Welcome", { FirstJoin = T0 }, T0 + 60), "A new player can't buy the Welcome Kit")
check(not Store.canBuy("Welcome", { FirstJoin = T0 }, T0 + Store.WelcomeHours * 3600 + 1), "The Welcome Kit outlived its day")
check(not Store.canBuy("Welcome", { FirstJoin = T0, WelcomeBought = true }, T0 + 60), "The Welcome Kit sold twice")
check(not Store.canBuy("StarterPack", {}, T0), "The Starter Pack sold before it was offered")
check(Store.canBuy("StarterPack", { StarterOfferAt = T0 }, T0 + 60), "The Starter Pack can't be bought on offer")
check(not Store.canBuy("Vault", { VaultBought = true }, T0), "The Vault sold twice")
check(not Store.canBuy("SkinPlasma", { Cosmetics = { Owned = { SkinPlasma = true } } }, T0), "A look you own can be bought")
check(Store.canBuy("Brainrot", { Cosmetics = { Owned = { SkinBonk = true } } }, T0), "A bundle you own part of can't be bought")
check(not Store.canBuy("Brainrot", { Cosmetics = { Owned = { SkinBonk = true, SkinBanana = true } } }, T0), "A bundle you own all of can be bought")
check(not Store.canBuy("SeasonPremium", { Season = { Premium = true } }, T0), "Season premium sold twice")
-- Crates in old saves become coins.
local old = { Coins = 5, Crates = { GeodeCrate = 2, MasterworkCrate = 1, Junk = 3 } }
check(Store.refundCrates(old) == 2 * 250 + 800 and old.Coins == 5 + 1300 and next(old.Crates) == nil, "Old crates weren't refunded at cost")
check(Store.refundCrates(old) == 0 and old.Coins == 1305, "Crates were refunded twice")

-- Paid: squad kits dress one miner each, starting with the one you play.
freshProfile()
profile.Miners = { Active = 2, Slots = { { Character = {} }, { Character = {} }, { Character = {} } } }
check(buy(Store.kitKey(kitIds)) == Granted, "The squad bundle wasn't granted")
for _, id in Store.contents(Store.kitKey(kitIds)).Cosmetics do
	check(profile.Cosmetics.Owned[id], "The squad bundle didn't give " .. id)
end
local firstSuit = Store.Kits[1].Contents.Cosmetics[1]
check(profile.Cosmetics.Suit == firstSuit, "The first kit isn't on the miner you're playing")
check(profile.Miners.Slots[3].Character.Wardrobe.Suit == Store.Kits[2].Contents.Cosmetics[1], "The second kit isn't on the next miner")
check(profile.Miners.Slots[1].Character.Wardrobe.Suit == Store.Kits[3].Contents.Cosmetics[1], "The third kit didn't wrap round to miner 1")
-- A bundle with a look you own: that look becomes coins.
freshProfile()
profile.Cosmetics.Owned.SkinBonk = true
check(buy("Brainrot") == Granted and profile.Coins == Store.DuplicateRefund and profile.Cosmetics.Owned.SkinBanana, "An owned look in a bundle wasn't refunded")
-- The Vault: everything, once.
freshProfile()
check(buy("Vault") == Granted and profile.VaultBought and profile.Cosmetics.Owned.TitleCollector and profile.Coins >= 10000, "The Vault wasn't granted")
check(profile.Cosmetics.Suit == nil, "The Vault changed your look")
-- Welcome Kit marks itself bought.
freshProfile()
check(buy("Welcome") == Granted and profile.WelcomeBought and profile.Cosmetics.Owned.SuitCamo, "The Welcome Kit wasn't granted")
-- Testing: any product for coins, through the same grant; not twice.
if Config.TestCosmeticPrice then
	freshProfile()
	profile.Coins = 1000
	local r1 = handlers.BuyProduct(thePlayer, "DeepSpace")
	check(r1.Ok and profile.Cosmetics.Owned.SuitNebula and profile.Coins == 1000 - Config.TestCosmeticPrice, "A bundle couldn't be test-bought for coins")
	check(not handlers.BuyProduct(thePlayer, "DeepSpace").Ok, "A bundle you own all of was bought again")
	check(not handlers.BuyProduct(thePlayer, "Nope").Ok and not handlers.BuyProduct(thePlayer, 42).Ok, "Junk was bought")
	profile.Coins = 0
	check(not handlers.BuyProduct(thePlayer, "Circuit").Ok, "A bundle was bought with no coins")
end
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
local SEAM_FX = { Pulse = true, Shift = true, Flicker = true, Rainbow = true }
-- Clean finishes only: no gritty textures (fabric weave, rust, concrete, stone).
local SUIT_MATERIALS = { SmoothPlastic = true, Metal = true, Foil = true, Glass = true, Neon = true }
local GRITTY = {
	Fabric = true,
	CorrodedMetal = true,
	Concrete = true,
	Slate = true,
	Basalt = true,
	Marble = true,
	Rock = true,
	DiamondPlate = true,
	Granite = true,
}
local defaults, earnedHow, animated = 0, true, 0
for id, cosmetic in Cosmetics.List do
	local palette = cosmetic.Palette
	if palette then
		check(palette.Pattern == nil or PATTERNS[palette.Pattern], id .. " has an unknown pattern")
		check(
			(palette.Accent == nil) == (palette.Pattern == nil),
			id .. " has an accent with no pattern, or the reverse"
		)
		check(
			not (palette.Seams and cosmetic.Kind ~= "Suit" and cosmetic.Kind ~= "Skin"),
			id .. " asks for seams but isn't a suit or a skin"
		)
		check(
			not ((palette.Blade or palette.Edge) and cosmetic.Kind ~= "Skin"),
			id .. " styles a blade but isn't a skin"
		)
		-- The neon look: every suit is outlined, every skin has a glowing
		-- edge (or, the Brainrot shapes, neon bands in their SeamColor).
		if cosmetic.Kind == "Suit" then
			check(palette.Seams == true, id .. " has no neon seams")
		elseif cosmetic.Kind == "Skin" then
			check(palette.Edge == true or (cosmetic.Look ~= nil and palette.SeamColor ~= nil), id .. " has no neon edge")
		end
		check(palette.SeamFx == nil or SEAM_FX[palette.SeamFx], id .. " has an unknown SeamFx")
		for _, field in { "PlateMaterial", "UnderMaterial", "AccentMaterial", "BladeMaterial" } do
			local material = palette[field]
			if material then
				local name = material.Name
				if cosmetic.Kind == "Suit" then
					check(SUIT_MATERIALS[name], id .. "'s " .. field .. " is a textured finish (" .. name .. ")")
				else
					check(not GRITTY[name], id .. "'s " .. field .. " is a gritty texture (" .. name .. ")")
				end
			end
		end
		check(
			palette.SeamWidth == nil
				or (type(palette.SeamWidth) == "number" and palette.SeamWidth > 0 and palette.SeamWidth <= 0.06),
			id .. "'s SeamWidth is out of range"
		)
		check(palette.SeamColor == nil or typeof(palette.SeamColor) == "Color3", id .. "'s SeamColor isn't a colour")
		if palette.SeamFx then
			animated += 1
		end
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
	-- Nothing is out of reach: a look is sold, earned (an exclusive), or
	-- (trims and back pieces) a bundle extra or a Season Path reward.
	if Cosmetics.isMinerKind(cosmetic.Kind) or cosmetic.Kind == "Title" then
		check(cosmetic.Robux or cosmetic.Exclusive, id .. " can't be had any way (not sold, not earned)")
	elseif not cosmetic.Exclusive then
		local found = false
		local function look(reward)
			found = found or (reward and table.find(reward.Cosmetics or {}, id) ~= nil)
		end
		for _, bundle in Store.Bundles do
			look(bundle.Contents)
		end
		for _, kit in Store.Kits do
			look(kit.Contents)
		end
		look(Store.StarterPack.Contents)
		for level = 1, Season.MaxLevel do
			look(Season.reward(level))
			look(Season.premiumReward(level))
		end
		check(found, id .. " isn't in any bundle or on the Season Path")
	end
	check(cosmetic.Price == nil, id .. " still has a coin price: nothing is sold for coins")
	check((cosmetic :: any).Crate == nil, id .. " still names a crate")
end
check(defaults == 2, "Every miner should start with one skin and one suit")
check(earnedHow, "An earned look doesn't say how it's earned")
check(animated >= 15, "Too few looks have animated seams (" .. animated .. ")")

-- Animated seams (SeamVisibility.fxColor) -------------------------------------------------
do
	local stub = setmetatable({}, { __index = function(t, k) return t end })
	local SeamVisibility = luau.load(fs.readFile(ROOT .. "/src/client/Modules/SeamVisibility.luau"), {
		debugName = "SeamVisibility",
		environment = setmetatable({
			Color3 = roblox.Color3,
			Enum = roblox.Enum,
			game = { GetService = function() return { Shared = { Tags = stub } } end },
			script = stub,
			require = function() return {} end,
		}, { __index = _G }),
	})()
	local fxColor = SeamVisibility.fxColor
	local a, b = roblox.Color3.fromRGB(255, 184, 40), roblox.Color3.fromRGB(230, 40, 56)
	local function near(x, y)
		return math.abs(x.R - y.R) + math.abs(x.G - y.G) + math.abs(x.B - y.B) < 0.03
	end
	local function valid(c)
		return c.R >= 0 and c.R <= 1 and c.G >= 0 and c.G <= 1 and c.B >= 0 and c.B <= 1
	end
	check(fxColor("None", a, b, 3, 0) == a and fxColor("Odd", a, b, 1, 2) == a, "A still seam changed colour")
	-- Shift swings all the way from the seam colour to the glow and back.
	local sawA, sawB = false, false
	for step = 0, 260 do
		local c = fxColor("Shift", a, b, step / 100, 0)
		check(valid(c), "Shift made an impossible colour")
		sawA = sawA or near(c, a)
		sawB = sawB or near(c, b)
	end
	check(sawA and sawB, "Shift didn't reach both of its colours")
	-- Pulse breathes: dimmer and brighter than half-way, the same hue.
	local low, high = math.huge, -math.huge
	for step = 0, 180 do
		local c = fxColor("Pulse", a, b, step / 100, 0)
		check(valid(c), "Pulse made an impossible colour")
		local _, _, v = c:ToHSV()
		low, high = math.min(low, v), math.max(high, v)
	end
	check(high - low > 0.3, "Pulse doesn't breathe")
	-- Flicker crackles: mostly the seam colour, with flashes of the glow.
	local flashes, steady = 0, 0
	for step = 0, 600 do
		local c = fxColor("Flicker", a, b, step / 60, 3)
		check(valid(c), "Flicker made an impossible colour")
		if near(c, b:Lerp(roblox.Color3.new(1, 1, 1), 0.5)) then
			flashes += 1
		else
			steady += 1
		end
	end
	check(flashes > 0 and steady > flashes * 3, "Flicker should be mostly steady with sharp flashes")
	-- Rainbow runs through every hue, staying bright.
	local hues = {}
	for step = 0, 100 do
		local c = fxColor("Rainbow", a, b, step * 0.06, 0)
		local h, sat, v = c:ToHSV()
		check(sat >= 0.6 and v >= 0.85, "Rainbow went dull")
		hues[math.floor(h * 6) % 6] = true
	end
	for sixth = 0, 5 do
		check(hues[sixth], "Rainbow skipped a hue")
	end
	-- Two boxes of one suit don't flash in lockstep.
	check(not near(fxColor("Shift", a, b, 1, 0), fxColor("Shift", a, b, 1, 5)), "Seeds don't stagger the seams")
end
for _, level in { 15, 25 } do
	for _, id in Season.reward(level).Cosmetics or {} do
		check(Cosmetics.get(id), "Free track level " .. level .. " gives an unknown cosmetic")
	end
end
check(
	table.find(Season.reward(15).Cosmetics, "SkinCrater") and table.find(Season.reward(25).Cosmetics, "SuitMoonDust"),
	"The Season 1 free-track looks are missing"
)

-- Each miner wears its own suit and skin -----------------------------------------------
do
	local Roster = shared("MinerRoster")
	local cosmetics = {
		Owned = { SuitNeon = true, SuitIgnition = true, SkinMolten = true },
		Suit = "SuitNeon",
		Skin = "SkinMolten",
		Title = "TitleLunar",
	}
	local profile = { Character = { Weapon = "A" }, Cosmetics = cosmetics, Augments = {} }
	Roster.initialize(profile, function(index)
		return { Weapon = "Starter" .. index }, {}
	end)
	local function switch(index)
		Cosmetics.leaveMiner(profile.Cosmetics, profile.Character)
		check(Roster.switch(profile, index), "Couldn't switch to miner " .. index)
		Cosmetics.joinMiner(profile.Cosmetics, profile.Character)
	end
	-- An older save: miner 2 has never had a wardrobe, so it starts in the current look.
	switch(2)
	check(cosmetics.Suit == "SuitNeon" and cosmetics.Skin == "SkinMolten", "A miner new to wardrobes lost the current look")
	-- Miner 2 changes its suit and takes its skin off (as PlayerData.setCosmetic does).
	cosmetics.Suit, profile.Character.Wardrobe.Suit = "SuitIgnition", "SuitIgnition"
	cosmetics.Skin, profile.Character.Wardrobe.Skin = nil, nil
	switch(1)
	check(cosmetics.Suit == "SuitNeon" and cosmetics.Skin == "SkinMolten", "Miner 1 didn't get its own look back")
	check(cosmetics.Title == "TitleLunar", "A title should stay with the account")
	switch(2)
	check(cosmetics.Suit == "SuitIgnition" and cosmetics.Skin == nil, "Miner 2 didn't keep its own look")
	-- A look you no longer own comes off when its miner comes back.
	cosmetics.Owned.SuitNeon = nil
	switch(1)
	check(cosmetics.Suit == nil and cosmetics.Skin == "SkinMolten", "A look no longer owned was put back on")
	local other = Cosmetics.forMiner(cosmetics, profile.Miners.Slots[2].Character)
	check(
		other.Suit == "SuitIgnition" and other.Skin == nil and other.Title == "TitleLunar",
		"forMiner shows the wrong look for another miner"
	)
end

-- Each miner holds its own pickaxe too --------------------------------------------------
do
	local cosmetics = { Owned = { PickMagma = true, PickBone = true }, Pick = "PickMagma" }
	local one = { Weapon = "A" }
	local two = { Weapon = "B", Wardrobe = { Pick = "PickBone" } }
	Cosmetics.leaveMiner(cosmetics, one)
	check(one.Wardrobe and one.Wardrobe.Pick == "PickMagma", "A miner leaving didn't keep its pickaxe")
	Cosmetics.joinMiner(cosmetics, two)
	check(cosmetics.Pick == "PickBone", "A miner arriving didn't take up its own pickaxe")
	Cosmetics.joinMiner(cosmetics, one)
	check(cosmetics.Pick == "PickMagma", "Miner 1 didn't get its pickaxe back")
	check(Cosmetics.forMiner(cosmetics, two).Pick == "PickBone", "forMiner shows the wrong pickaxe")
	check(Cosmetics.coinPrice(Cosmetics.get("PickMagma")) == Cosmetics.coinPrice(Cosmetics.get("SkinMolten")), "Picks don't take the test price")
end

-- Every pickaxe builds, in one piece ------------------------------------------------------
do
	local tagged = {}
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				check(name == "CollectionService", "PickaxeLooks wants an unexpected service")
				return {
					AddTag = function(_, instance, tag)
						tagged[instance] = tag
					end,
				}
			end,
		},
		Instance = roblox.Instance,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Enum = roblox.Enum,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		script = { Parent = parent },
		require = function(name)
			return shared(name)
		end,
	}, { __index = _G })
	local PickaxeLooks = luau.load(pickaxeSource, { debugName = "PickaxeLooks", environment = env })()
	local Tags = shared("Tags")
	local function inspect(name, parts, tip, model, frame)
		check(#parts >= 6, name .. " is barely a pickaxe (" .. #parts .. " parts)")
		check(tip and tip.Name == "PickTip" and tip.Parent == model, name .. " has no tip")
		for _, part in parts do
			check(part.Parent == model and not part.CanCollide and part.Massless and not part.CanQuery, name .. " has a part that gets in the way")
			-- Held in a hand: nothing reaches past the head (about 3 studs up
			-- the haft, 2.5 along the spike).
			local at = frame:PointToObjectSpace(part.CFrame.Position)
			check(at.Y > -0.6 and at.Y < 3.6 and math.abs(at.Z) < 2.6 and math.abs(at.X) < 1, name .. " has a part out at " .. tostring(at))
		end
	end
	for id, cosmetic in Cosmetics.List do
		if cosmetic.Kind == "Pick" then
			local model = roblox.Instance.new("Model")
			local frame = roblox.CFrame.new(10, 5, -3) * roblox.CFrame.Angles(0.4, 1.1, -0.2)
			local parts, tip = PickaxeLooks.build(model, frame, id)
			inspect(id, parts, tip, model, frame)
			local wedges, glows, trails = 0, 0, 0
			for _, part in parts do
				check(part.Anchored, id .. " stands on its own but has a loose part")
				wedges += if part:IsA("WedgePart") then 1 else 0
				glows += if part:FindFirstChildOfClass("PointLight") or part:FindFirstChildOfClass("ParticleEmitter") then 1 else 0
			end
			trails += if tip:FindFirstChild("PickTrail") then 1 else 0
			check(wedges >= 2, id .. " has no tapered blade")
			check(glows >= 1 or id == "PickBone", id .. " has no light or particles")
			check(trails == 1, id .. " leaves no streak through a swing")
			-- In a hand: every part welded to it, none anchored.
			local hand = roblox.Instance.new("Part")
			local held = roblox.Instance.new("Model")
			local inHand = PickaxeLooks.build(held, frame, id, nil, hand)
			for _, part in inHand do
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				check(not part.Anchored and weld and weld.Part0 == hand and weld.Part1 == part, id .. " isn't welded to the hand")
			end
		end
	end
	local prism = 0
	for _, tag in tagged do
		check(tag == Tags.Prismatic, "A pickaxe part has an unknown tag")
		prism += 1
	end
	check(prism >= 3, "Prism Shard doesn't shimmer")
	-- No skin (or one you can't have): the tier's own pick, glowing if bright.
	local model = roblox.Instance.new("Model")
	local parts, tip = PickaxeLooks.build(model, roblox.CFrame.new(), "NotAPick", roblox.Color3.fromRGB(255, 0, 0), nil, true)
	inspect("The standard pick", parts, tip, model, roblox.CFrame.new())
	local lit, tinted = false, 0
	for _, part in parts do
		lit = lit or part:FindFirstChildOfClass("PointLight") ~= nil
		tinted += if part.Color == roblox.Color3.fromRGB(255, 0, 0) then 1 else 0
	end
	check(tinted >= 3, "The standard pick isn't in its tier's colour")
	check(lit, "A bright pick doesn't glow")
end

print(string.format("PASS: %d skins & selling checks (%d skins, %d suits, %d picks, %d titles, %d with animated seams; receipts once each, starter pack, season premium, codes)", checks, skins, suits, picks, titles, animated))
