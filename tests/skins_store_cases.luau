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
local KINDS = { Trim = true, Back = true, Skin = true, Shield = true, Suit = true, Pick = true, Visor = true, Helmet = true, Title = true }
local skins, suits, titles, picks, visors, helmets = 0, 0, 0, 0, 0, 0
local helmetSource = fs.readFile(ROOT .. "/src/server/Systems/HelmetLooks.luau")
-- Visors: what each rarity promises.
local VISOR_FX = { Pulse = true, Shift = true, Flicker = true, Rainbow = true, Scan = true, Aurora = true }
local ELEMENTS = { Fire = true, Frost = true, Shock = true, Poison = true }
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
	elseif cosmetic.Kind == "Visor" then
		visors += 1
		local v = cosmetic.Visor
		check(v ~= nil and typeof(v.Color) == "Color3", id .. " has no lens colour")
		v = v or {}
		check(v.Material == "Glass" or v.Material == "Neon", id .. " has an unknown lens material")
		check(v.Fx == nil or VISOR_FX[v.Fx], id .. " has an unknown visor effect")
		check(v.Element == nil or ELEMENTS[v.Element], id .. " has an unknown element")
		check(v.Glow == nil or typeof(v.Glow) == "Color3", id .. "'s Glow isn't a colour")
		check(v.Third == nil or typeof(v.Third) == "Color3", id .. "'s Third isn't a colour")
		check(v.Reflect == nil or (v.Reflect >= 0 and v.Reflect <= 1), id .. "'s Reflect is out of range")
		check(
			v.Bands == nil or (v.Bands == math.floor(v.Bands) and v.Bands >= 3 and v.Bands <= 15),
			id .. " has a bad band count"
		)
		check(v.Fx ~= "Scan" or (v.Glow ~= nil and v.Bands ~= nil), id .. " scans with no sweep colour or no bands")
		check(v.Fx ~= "Aurora" or (v.Glow ~= nil and v.Third ~= nil), id .. " is an Aurora without three colours")
		check(v.Fx ~= "Shift" and v.Fx ~= "Flicker" or v.Glow ~= nil, id .. " swings to no second colour")
		check(
			v.Material ~= "Glass" or (v.Fx == nil and v.Element == nil),
			id .. " is glass but moves (lit lenses move)"
		)
		local rank = ({ Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 })[cosmetic.Rarity]
		check(rank ~= nil, id .. " has an unknown rarity")
		if rank == 1 then
			check(v.Material == "Glass", id .. " is Common but lit (Commons are tinted glass)")
		elseif rank == 3 then
			check(v.Fx ~= nil, id .. " is Rare but doesn't move")
		elseif rank == 4 then
			check(v.Fx ~= nil and v.Element ~= nil, id .. " is Ultra Rare but has no element")
		elseif rank == 5 then
			check(
				(v.Fx == "Rainbow" or v.Fx == "Aurora") and (v.Bands or 0) >= 5 and v.Rim == true,
				id .. " is Legendary but not a framed, banded, many-coloured lens"
			)
		end
	elseif cosmetic.Kind == "Helmet" then
		helmets += 1
		check(
			cosmetic.Look and string.find(helmetSource, "DESIGNS." .. cosmetic.Look .. " = function", 1, true),
			id .. " has no helmet design (HelmetLooks)"
		)
		check(cosmetic.Robux ~= nil, id .. " isn't sold")
	elseif cosmetic.Kind == "Title" then
		titles += 1
	elseif cosmetic.Kind == "Back" then
		check(cosmetic.Look and string.find(equipment, "BACKS." .. cosmetic.Look .. " =", 1, true), id .. " can't be built")
	end
end
check(
	skins >= 8 and suits >= 6 and titles >= 3 and picks >= 9 and visors >= 15 and helmets >= 12,
	"The catalog is thinner than planned"
)
-- Helmets: every design is sold (once), with a tab of its own, each miner's own.
for design in string.gmatch(helmetSource, "DESIGNS%.(%w+) = function") do
	local sold = 0
	for _, cosmetic in Cosmetics.List do
		if cosmetic.Kind == "Helmet" and cosmetic.Look == design then
			sold += 1
		end
	end
	check(sold == 1, "Helmet design " .. design .. " is sold " .. sold .. " times")
end
check(Store.TabKinds.Helmets == "Helmet" and table.find(Store.Tabs, "Helmets"), "Helmets have no Store tab")
check(Cosmetics.isMinerKind("Helmet"), "A helmet isn't each miner's own")
-- Visors: one of every element, a tab of their own, all in the Vault.
local elements = {}
for id, cosmetic in Cosmetics.List do
	if cosmetic.Kind == "Visor" and cosmetic.Visor and cosmetic.Visor.Element then
		elements[cosmetic.Visor.Element] = true
	end
end
for element in ELEMENTS do
	check(elements[element], "No visor carries " .. element)
end
check(Store.TabKinds.Visors == "Visor" and table.find(Store.Tabs, "Visors"), "Visors have no Store tab")
check(Cosmetics.isMinerKind("Visor"), "A visor isn't each miner's own")
local vault = Store.bundle("Vault")
for _, id in Cosmetics.ofKind("Visor") do
	if Cosmetics.List[id].Robux then
		check(table.find(vault.Contents.Cosmetics, id), id .. " is sold but not in The Vault")
	end
end
-- A Rift RESTORE at each price it's asked at, its product at that price.
do
	local RiftRun = shared("RiftRun")
	for downs = 1, 6 do
		local robux = RiftRun.restoreRobux(downs)
		local key = Store.RiftRestores[robux]
		check(key and Store.RobuxProducts[key] ~= nil and Store.RobuxPrices[key] == robux, "No RESTORE product at R$ " .. robux)
	end
end
-- Every product slot buys something real.
for key in Store.RobuxProducts do
	local real = Store.bundle(key) or Store.kitsOf(key) or (Cosmetics.get(key) and Cosmetics.get(key).Robux)
		or key == "StarterPack" or key == "SeasonPremium" or Store.refill(key) or key == "KaijuRevive" or Store.isRiftRestore(key)
		or (Store.contents(key) or {}).KaijuSale ~= nil -- (the Kennel's: KaijuServer.saleGrant)
		or Store.coinPack(key) ~= nil -- (a coin pack's coins: Client CoinShop)
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
local failSave = false -- (a save that fails: the receipt waits for Roblox to ask again)
-- (Analytics: the purchases and tagged coins sent.)
local analyticsPurchases, analyticsCoins = {}, {}
local stubs = {
	Analytics = {
		purchased = function(_, key)
			table.insert(analyticsPurchases, key)
		end,
		coins = function(_, delta, reason)
			table.insert(analyticsCoins, { Delta = delta, Reason = reason })
		end,
		event = function() end,
	},
	Cosmetics = Cosmetics,
	MinerRoster = { Count = 3, Enabled = true },
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
			return not failSave
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
		-- (Server Shop.short: short of coins, how many more)
		short = function(_player, cost, message)
			return { Ok = false, Message = message, CoinsShort = cost }
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
-- A save that fails: not granted yet, so Roblox asks again; asked again once
-- saving works, it's granted (and not given twice).
failSave = true
check(buy("SkinCamo", "f1") == NotYet, "A purchase counted as granted though its save failed")
failSave = false
check(buy("SkinCamo", "f1") == Granted, "A purchase asked about again after a failed save wasn't granted")
-- Asked again while saving still fails: still waiting (granted once, never
-- counted done before it's saved).
failSave = true
check(buy("SkinCopper", "f2") == NotYet and profile.Cosmetics.Owned.SkinCopper, "A purchase whose save failed wasn't held in memory")
check(buy("SkinCopper", "f2") == NotYet, "A purchase asked about again counted as done though it still wasn't saved")
failSave = false
check(buy("SkinCopper", "f2") == Granted, "A purchase wasn't done once its save went through")
-- A session that doesn't save (its save didn't load, or another server took
-- it): nothing granted, so nothing lost when they leave; granted in the
-- next session that saves.
stubs.PlayerData.keeps = function()
	return false
end
check(buy("SkinGlacier", "k1") == NotYet and not profile.Cosmetics.Owned.SkinGlacier, "A purchase was granted in a session that doesn't save")
stubs.PlayerData.keeps = function()
	return true
end
check(buy("SkinGlacier", "k1") == Granted and profile.Cosmetics.Owned.SkinGlacier, "A held purchase wasn't granted in a session that saves")
stubs.PlayerData.keeps = nil
-- The same receipt again (Roblox retries): granted, not given twice.
profile.Cosmetics.Owned.SkinPlasma = nil
check(buy("SkinPlasma", "a1") == Granted and not profile.Cosmetics.Owned.SkinPlasma, "A retried receipt was granted twice")
-- A suit.
check(buy("SuitRoyal") == Granted and profile.Cosmetics.Suit == "SuitRoyal", "A suit purchase wasn't worn")
-- The Starter Pack: its contents, its suit on, and it's marked bought.
check(buy("StarterPack") == Granted, "The Starter Pack wasn't granted")
check(profile.StarterBought and profile.Cosmetics.Owned.SuitIgnition and profile.Cosmetics.Suit == "SuitIgnition", "The Starter Pack's suit isn't owned and worn")
check(profile.Coins >= Store.StarterPack.Contents.Coins and profile.Cosmetics.Owned.PickBone and profile.Cosmetics.Owned.SkinMolten, "The Starter Pack's coins and looks are missing")
-- A swing refill (PROBE-7's, for Robux): its swings on the pick, once per
-- receipt; with no Outpost to put them on, not granted (so not charged).
do
	local refill = Store.refill("SwingRefill")
	check(refill and Store.robuxPrice("SwingRefill") == refill.Robux, "The Swing Refill has no Robux price")
	check(Store.contents("SwingMega").Swings == Store.refill("SwingMega").Swings, "The Mega Refill grants no swings")
	check(Store.productName("SwingRefill") == refill.Name, "The Swing Refill has no name")
	local added = 0
	StoreServer.addSwings = nil
	check(buy("SwingRefill", "r0") == NotYet and added == 0, "A refill was granted with nowhere to put its swings")
	StoreServer.addSwings = function(who, swings)
		check(who == thePlayer, "A refill's swings went to someone else")
		added += swings
		return true
	end
	check(buy("SwingRefill", "r1") == Granted and added == refill.Swings, "A refill's swings didn't land")
	check(buy("SwingRefill", "r1") == Granted and added == refill.Swings, "A retried refill receipt added swings twice")
	check(buy("SwingMega", "r2") == Granted and added == refill.Swings + Store.refill("SwingMega").Swings, "Refills don't stack")
	check(Store.canBuy("SwingRefill", profile, os.time()), "A refill can only be bought once")
end
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

-- Bundles and The Vault -----------------------------------------------------------------------
-- Every bundle holds real looks, costs less than its looks one by one, and
-- never sells power (gems, crates).
local onSale = { "StarterPack" }
for _, bundle in Store.Bundles do
	if bundle.Section ~= "Retired" then
		table.insert(onSale, bundle.Id)
	end
end
for _, key in onSale do
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
-- Player bundles: one whole look each (a suit, a weapon skin, a helmet, a
-- visor and a pickaxe, one of each), a product slot and a price, and a name
-- no other product has (tools/create_dev_products.py finds products by name).
local productNames = {}
for key in Store.RobuxProducts do
	local name = Store.productName(key)
	productNames[name] = (productNames[name] or 0) + 1
end
local looks = 0
for _, bundle in Store.Bundles do
	if bundle.Section == "Look" then
		looks += 1
		local kinds = {}
		for _, id in bundle.Contents.Cosmetics or {} do
			local kind = Cosmetics.get(id).Kind
			kinds[kind] = (kinds[kind] or 0) + 1
		end
		for _, kind in { "Suit", "Skin", "Helmet", "Visor", "Pick" } do
			check(kinds[kind] == 1, bundle.Id .. " should hold exactly one " .. kind)
		end
		check(Store.RobuxProducts[bundle.Id] ~= nil and Store.RobuxPrices[bundle.Id], bundle.Id .. " has no product slot or price")
		check(productNames[bundle.Name] == 1, bundle.Name .. " shares its name with another product")
		check(Store.savings(bundle.Id) >= 40, bundle.Id .. " saves too little (" .. Store.savings(bundle.Id) .. "%)")
		check(not Store.retired(bundle.Id), bundle.Id .. " reads as retired")
	end
end
check(looks >= 6, "Too few player bundles")
-- No longer sold: the launch collections and the squad kits. Never offered,
-- never in a "save with a bundle" note, but a purchase still going through
-- is granted.
for _, key in { "Rustbucket", "Brainrot", "Circuit", "DeepSpace", "SolarForge", "KitProspector", "KitProspectorSkirmisherJuggernaut" } do
	check(Store.retired(key) and Store.contents(key) ~= nil, key .. " isn't retired, or can't be granted")
	check(not Store.canBuy(key, {}, 0), key .. " can still be bought")
end
for id in Cosmetics.List do
	for _, key in Store.bundlesWith(id) do
		check(not Store.retired(key), id .. "'s bundle deal is one no longer sold: " .. key)
	end
end
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
do
	local all = {}
	for _, id in Store.bundle("NeonRush").Contents.Cosmetics do
		all[id] = true
	end
	check(Store.canBuy("NeonRush", { Cosmetics = { Owned = { SuitNeon = true } } }, T0), "A bundle you own part of can't be bought")
	check(not Store.canBuy("NeonRush", { Cosmetics = { Owned = all } }, T0), "A bundle you own all of can be bought")
end
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
-- One miner (Config.Features.MinerRoster off): it wears the first kit, the
-- others wait in the Wardrobe, and the resting miners in an old save keep their looks.
stubs.MinerRoster.Count, stubs.MinerRoster.Enabled = 1, false
freshProfile()
profile.Miners = { Active = 2, Slots = { { Character = {} }, { Character = {} }, { Character = {} } } }
check(buy(Store.kitKey(kitIds)) == Granted, "The squad bundle wasn't granted with one miner")
for _, id in Store.contents(Store.kitKey(kitIds)).Cosmetics do
	check(profile.Cosmetics.Owned[id], "The one-miner squad bundle didn't give " .. id)
end
check(profile.Cosmetics.Suit == firstSuit, "One miner isn't wearing the first kit")
check(
	profile.Miners.Slots[1].Character.Wardrobe == nil and profile.Miners.Slots[3].Character.Wardrobe == nil,
	"A resting miner was dressed"
)
stubs.MinerRoster.Count, stubs.MinerRoster.Enabled = 3, true
-- A bundle with a look you own: that look becomes coins.
freshProfile()
profile.Cosmetics.Owned.SkinCircuit = true
check(buy("NeonRush") == Granted and profile.Coins == Store.DuplicateRefund and profile.Cosmetics.Owned.SuitNeon, "An owned look in a bundle wasn't refunded")
-- A player bundle puts the whole look on.
for _, id in Store.bundle("NeonRush").Contents.Cosmetics do
	local kind = Cosmetics.get(id).Kind
	check(profile.Cosmetics[kind] == id, "A player bundle didn't put on its " .. kind)
end
-- A retired bundle still going through is granted.
freshProfile()
check(buy("Brainrot") == Granted and profile.Cosmetics.Owned.SkinBanana, "A retired bundle's purchase wasn't granted")
-- The Vault: everything, once.
freshProfile()
check(buy("Vault") == Granted and profile.VaultBought and profile.Cosmetics.Owned.TitleCollector and profile.Coins >= 10000, "The Vault wasn't granted")
check(profile.Cosmetics.Suit == nil, "The Vault changed your look")
-- Welcome Kit marks itself bought.
freshProfile()
check(buy("Welcome") == Granted and profile.WelcomeBought and profile.Cosmetics.Owned.SuitCamo, "The Welcome Kit wasn't granted")
-- Coin packs: 10k, 25k, 50k and 100k coins for Robux, each cheaper a coin
-- than the last, in a window of their own (Client CoinShop).
check(#Store.CoinPacks == 4 and Store.CoinPacks[1].Coins == 10000 and Store.CoinPacks[1].Robux == 1000, "10,000 coins aren't R$ 1,000")
local lastRate = math.huge
for i, pack in Store.CoinPacks do
	check(pack.Coins == ({ 10000, 25000, 50000, 100000 })[i], "Coin pack " .. i .. " holds the wrong coins")
	check(Store.robuxPrice(pack.Key) == pack.Robux and Store.RobuxProducts[pack.Key] ~= nil, pack.Key .. " has no product or price")
	check(pack.Robux / pack.Coins < lastRate, pack.Key .. " isn't a better deal than the pack before it")
	lastRate = pack.Robux / pack.Coins
	check(Store.coinPack(pack.Key) == pack and Store.contents(pack.Key).Coins == pack.Coins, pack.Key .. " doesn't hold its coins")
	check(Store.productName(pack.Key) == Store.commas(pack.Coins) .. " Coins", pack.Key .. " is misnamed")
	check(Store.canBuy(pack.Key, { Coins = 10 ^ 9 }, os.time()), pack.Key .. " can't be bought")
	check((Store.coinSaving(pack) > 0) == (i > 1), pack.Key .. "'s saving is wrong")
end
check(Store.coinSaving(Store.CoinPacks[4]) == 25, "100,000 coins don't save a quarter")
check(Store.coinPack("Vault") == nil and Store.coinPack(nil) == nil, "Not a coin pack, called one")
check(
	Store.coinPackFor(1).Key == "Coins10k"
		and Store.coinPackFor(10001).Key == "Coins25k"
		and Store.coinPackFor(60000).Key == "Coins100k"
		and Store.coinPackFor(10 ^ 9).Key == "Coins100k",
	"The pack marked for a shortfall doesn't cover it"
)
check(Store.commas(1234567) == "1,234,567" and Store.commas(999) == "999" and Store.commas(-2500) == "-2,500", "Coins are written wrong")
-- Bought: the coins, nothing worn, as often as you like.
freshProfile()
local coinsBefore = profile.Coins
check(buy("Coins25k") == Granted and profile.Coins == coinsBefore + 25000, "A coin pack's coins weren't granted")
check(buy("Coins25k") == Granted and profile.Coins == coinsBefore + 50000, "A second coin pack wasn't granted")
check(profile.Cosmetics.Suit == nil and profile.Cosmetics.Skin == nil, "A coin pack changed your look")
-- Testing: any product for coins, through the same grant; not twice.
if Config.TestCosmeticPrice then
	freshProfile()
	profile.Coins = 1000
	local r1 = handlers.BuyProduct(thePlayer, "DeepSpaceExplorer")
	check(r1.Ok and profile.Cosmetics.Owned.SuitNebula and profile.Coins == 1000 - Config.TestCosmeticPrice, "A bundle couldn't be test-bought for coins")
	check(not handlers.BuyProduct(thePlayer, "DeepSpaceExplorer").Ok, "A bundle you own all of was bought again")
	check(not handlers.BuyProduct(thePlayer, "DeepSpace").Ok, "A retired bundle was test-bought")
	check(not handlers.BuyProduct(thePlayer, "Nope").Ok and not handlers.BuyProduct(thePlayer, 42).Ok, "Junk was bought")
	profile.Coins = 0
	local poor = handlers.BuyProduct(thePlayer, "StormCaller")
	check(not poor.Ok, "A bundle was bought with no coins")
	check(poor.CoinsShort == Config.TestCosmeticPrice, "Short of coins didn't say how many (for the coin packs)")
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
local code
for name, entry in stubs.Codes.List do
	if not entry.For then
		code = name
		break
	end
end
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
-- A gift: only for the players it names (by username, any case, or UserId).
clock += 3
check(not handlers.RedeemCode(thePlayer, "REAPERGIFT113").Ok, "A gift code redeemed for someone it isn't for")
check(not profile.Cosmetics.Owned.HelmetGrimReaper, "A gift's cosmetics went to someone else")
thePlayer.Name, thePlayer.DisplayName = "someone_else", "KinGreen113" -- (chat shows the display name)
clock += 3
local gift = handlers.RedeemCode(thePlayer, "reapergift113")
check(gift.Ok, "The gift didn't redeem for kingreen113: " .. tostring(gift.Message))
for _, id in { "SuitStealth", "SkinVoid", "HelmetGrimReaper", "VisorTwilight", "PickVoid" } do
	check(profile.Cosmetics.Owned[id], "The Reaper gift didn't give " .. id)
end
check(profile.Cosmetics.Helmet == "HelmetGrimReaper", "The Reaper gift's hood wasn't put on")
thePlayer.Name, thePlayer.DisplayName = nil, nil
check(stubs.Codes.allowed({ For = { "kingreen113" } }, { Name = "KINGREEN113", DisplayName = "x" }), "A gift by username")
check(stubs.Codes.allowed({ For = { 42 } }, { UserId = 42 }) and not stubs.Codes.allowed({ For = { 42 } }, { UserId = 7 }), "A gift by UserId")
local Bundle = Store.bundle("ReaperHarvest")
check(Bundle and table.concat(Bundle.Contents.Cosmetics, ",") == table.concat(stubs.Codes.List.REAPERGIFT113.Reward.Cosmetics, ","), "The Reaper gift isn't the whole Reaper's Harvest bundle")
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
check(defaults == 3, "Every miner should start with one skin, one suit and one visor")
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
	-- Scan (visors): one bright bar crossing a dim lens, band by band (seed
	-- 0-10 is where a band sits), to the far side and back.
	local lens, bar = roblox.Color3.fromRGB(110, 10, 18), roblox.Color3.fromRGB(255, 70, 40)
	local litAt = {}
	for step = 0, 280 do
		local t = step / 100
		local brightest, at = -1, nil
		for band = 0, 10 do
			local c = fxColor("Scan", lens, bar, t, band)
			check(valid(c), "Scan made an impossible colour")
			local _, _, v = c:ToHSV()
			if v > brightest then
				brightest, at = v, band
			end
		end
		litAt[at] = true
		local lit, dark = 0, 0
		for band = 0, 10 do
			if near(fxColor("Scan", lens, bar, t, band), bar) then
				lit += 1
			elseif not near(fxColor("Scan", lens, bar, t, band), bar:Lerp(lens, 0.3)) then
				dark += 1
			end
		end
		check(lit <= 2 and dark >= 6, "Scan should light one bar across a dim lens")
	end
	check(litAt[0] and litAt[5] and litAt[10], "Scan's bar doesn't cross the whole lens")
	-- Aurora (visors): through all three colours, round the colour wheel, never grey.
	local teal, green, violet =
		roblox.Color3.fromRGB(30, 236, 200), roblox.Color3.fromRGB(110, 255, 100), roblox.Color3.fromRGB(170, 84, 255)
	local reached = {}
	for step = 0, 450 do
		local c = fxColor("Aurora", teal, green, step / 100, 0, violet)
		check(valid(c), "Aurora made an impossible colour")
		local _, sat = c:ToHSV()
		check(sat >= 0.5, "Aurora went grey between its colours")
		for name, stop in { Teal = teal, Green = green, Violet = violet } do
			if near(c, stop) then
				reached[name] = true
			end
		end
	end
	check(reached.Teal and reached.Green and reached.Violet, "Aurora didn't reach all three of its colours")
	-- Blue to gold (Supernova's turn) goes round the wheel, not through grey.
	local gold, blue = roblox.Color3.fromRGB(255, 186, 30), roblox.Color3.fromRGB(60, 150, 255)
	for step = 0, 450 do
		local _, sat = fxColor("Aurora", gold, roblox.Color3.fromRGB(255, 50, 170), step / 100, 0, blue):ToHSV()
		check(sat >= 0.5, "Supernova's colours went grey between them")
	end
	check(
		not near(fxColor("Aurora", teal, green, 2, 0, violet), fxColor("Aurora", teal, green, 2, 10, violet)),
		"Aurora's bands all show one colour (no flow across the lens)"
	)
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
	-- (Switching needs the roster on; the beta's Config turns it off.)
	local was = Roster.Enabled
	Roster.configure(true)
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
	Roster.configure(was)
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

print(string.format("PASS: %d skins & selling checks (%d skins, %d suits, %d picks, %d visors, %d helmets, %d titles, %d with animated seams; receipts once each, starter pack, season premium, codes)", checks, skins, suits, picks, visors, helmets, titles, animated))
