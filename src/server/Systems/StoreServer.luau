--[[
	The store, cosmetics and the Season Path. Request actions:
	  "BuyProduct", key            while testing (Config.TestCosmeticPrice):
	                               buy any product for coins, through the same
	                               grant as a Robux purchase
	  "BuyCosmetic", id            the same, for one look (the Wardrobe's BUY)
	  "EquipCosmetic", kind, id?   wear a trim / back piece / weapon skin / suit /
	                               pickaxe / title you own (nil takes it off)
	  "ClaimSeason", level|"all"   claim Season Path rewards you've reached (and
	                               the premium track's, if unlocked)
	  "StarterOffer"               puts the Starter Pack on offer (once, after a win)
	Robux: when an id is set in Store.RobuxProducts, buying that Developer
	Product grants it (ProcessReceipt below), once per purchase: a look, a
	bundle, squad kits, the Starter Pack, the Season premium track, a
	swing refill's swings (StoreServer.addSwings: OutpostServer's) or a
	kaiju revive (StoreServer.reviveKaiju: KaijuServer.reviveAll; with none
	down by then, a Revive coupon, Shared.Coupons), a Kennel sale
	(StoreServer.kaijuSale: KaijuServer.saleGrant) or a coin pack's coins
	(Store.CoinPacks).

	What you buy goes on: a look you buy is worn at once; a bundle puts its
	first suit, skin and pickaxe on the miner you're playing; squad kits go
	one per miner, starting with this one (Store.Kits). The Vault leaves
	your looks as they are.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Coupons = require(ReplicatedStorage.Shared.Coupons)
local Economy = require(ReplicatedStorage.Shared.ExpeditionEconomy)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local Season = require(ReplicatedStorage.Shared.Season)
local Store = require(ReplicatedStorage.Shared.Store)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local StoreServer = {}
-- Puts swings on a player's free pick (a refill: OutpostServer.addSwings,
-- wired in by Main); false when it can't (no Outpost).
StoreServer.addSwings = nil :: ((Player, number) -> boolean)?
-- Brings back every kaiju of a player's that's knocked out (a revive:
-- KaijuServer.reviveAll, wired in by Main); how many came back.
StoreServer.reviveKaiju = nil :: ((Player) -> number)?
-- Down at a Rift boss: back on your feet there, kaiju and all
-- (RiftServer.restoreBought, wired in by Main); false when not down.
StoreServer.riftRestore = nil :: ((Player) -> boolean)?
-- The Kennel's sales (KaijuServer.saleGrant, wired in by Main): the Kaiju
-- of the Day or the Starter Rare Roll; false when it can't be given now.
StoreServer.kaijuSale = nil :: ((Player, string) -> (boolean, { string }?))?

local function cosmeticName(id: string): string
	local cosmetic = Cosmetics.get(id)
	return if cosmetic then cosmetic.Name else id
end

-- Gives a Store.Reward. Returns the lines to show the player.
function StoreServer.grant(player: Player, reward: Store.Reward): { string }
	local profile = PlayerData.get(player)
	if not profile then
		return {}
	end
	local lines = {}
	local function add(line: string)
		table.insert(lines, line)
	end
	for _, id in reward.Cosmetics or {} do
		if Cosmetics.get(id) then
			if profile.Cosmetics.Owned[id] then
				profile.Coins += Store.DuplicateRefund
				add(string.format("%s (already owned: +%d coins)", cosmeticName(id), Store.DuplicateRefund))
			else
				profile.Cosmetics.Owned[id] = true
				add(cosmeticName(id))
			end
		end
	end
	local coins = reward.Coins or 0
	-- (Old rewards may still name crates: those are coins now.)
	for id, count in (reward :: any).Crates or {} do
		coins += (Store.CrateRefund[id] or 0) * count
	end
	if coins > 0 then
		profile.Coins += coins
		add(string.format("%d coins", coins))
	end
	local legacy = Economy.legacyCredits(reward.Marks, reward.Materials)
	if legacy > 0 then
		profile.Coins += legacy
		add(string.format("%d legacy salvage credits", legacy))
	end
	if reward.XPBoostMinutes then
		profile.Boosts.XPUntil = math.max(os.time(), profile.Boosts.XPUntil or 0) + reward.XPBoostMinutes * 60
		add(string.format("2x XP for %d minutes", reward.XPBoostMinutes))
	end
	for _ = 1, reward.Stones or 0 do
		if Gems.award(player, "MiningStore") then
			add("an enchant-ready gem")
		end
	end
	for _ = 1, reward.CutGems or 0 do
		local gem = GemGenerator.generate(Gems.random(), "MiningStore", {
			Id = PlayerData.newGemId(),
			Time = os.time(),
			Luck = 0.3,
		})
		gem.Cut = Gems.random():NextInteger(6, 8)
		gem.CutMethod = "Crate"
		if PlayerData.addGem(player, gem) then
			add("a cut gem")
		end
	end
	PlayerData.sync(player)
	return lines
end

-- Puts a look on miner `index` (the one you're playing, or one resting in
-- the roster: it wears it when you switch to it).
local function dressMiner(player: Player, profile, index: number, ids: { string })
	local roster = profile.Miners
	local active = not roster or index == roster.Active
	for _, id in ids do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and Cosmetics.isMinerKind(cosmetic.Kind) and profile.Cosmetics.Owned[id] then
			if active then
				PlayerData.setCosmetic(player, cosmetic.Kind, id)
			else
				local slot = roster.Slots[index]
				local character = slot and slot.Character
				if character then
					character.Wardrobe = character.Wardrobe or {}
					character.Wardrobe[cosmetic.Kind] = id
				end
			end
		end
	end
end

-- The first suit, skin and pickaxe in a list.
local function firstLook(ids: { string }): { string }
	local look, taken = {}, {}
	for _, id in ids do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and Cosmetics.isMinerKind(cosmetic.Kind) and not taken[cosmetic.Kind] then
			taken[cosmetic.Kind] = true
			table.insert(look, id)
		end
	end
	return look
end

-- What a product grants (a Store.RobuxProducts key). Returns false for a
-- key it doesn't know, else true and the lines to show.
function StoreServer.grantProduct(player: Player, key: string): (boolean, { string }?)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return false
	end
	if key == "SeasonPremium" then
		profile.Season.Premium = true
		PlayerData.sync(player)
		return true, { "the Season Path's premium track" }
	end
	-- A refill: swings on the pick (not granted, so not paid for, without).
	local refill = Store.refill(key)
	if refill then
		local added = StoreServer.addSwings ~= nil and StoreServer.addSwings(player, refill.Swings)
		return added, if added then { string.format("%d swings", refill.Swings) } else nil
	end
	-- A kaiju revive: every one of yours that's down, back now. Paid for
	-- with none down (it came back by itself while the purchase went
	-- through): a Revive coupon for next time instead.
	if key == "KaijuRevive" then
		local revived = if StoreServer.reviveKaiju then StoreServer.reviveKaiju(player) else 0
		if revived > 0 then
			return true, { if revived == 1 then "your kaiju back on its feet" else string.format("%d kaiju back on their feet", revived) }
		end
		Coupons.add(profile, "Revive", 1)
		PlayerData.sync(player)
		return true, { "a Kaiju Revive coupon (none of yours was down)" }
	end
	-- A Rift RESTORE: back on your feet at the boss. Paid for once you're
	-- no longer down (the time ran out while it went through): kept for the
	-- next time you're down there, used by RESTORE without paying again.
	if key == "RiftRestore" then
		if StoreServer.riftRestore and StoreServer.riftRestore(player) then
			return true, { "back on your feet, kaiju and all" }
		end
		profile.RiftRestores = (profile.RiftRestores or 0) + 1
		PlayerData.sync(player)
		return true, { "a Rift RESTORE, kept for the next time you're down" }
	end
	-- A coin pack: its coins, nothing to put on.
	local pack = Store.coinPack(key)
	if pack then
		return true, StoreServer.grant(player, { Coins = pack.Coins })
	end
	local reward = Store.contents(key)
	if not reward then
		return false
	end
	-- A Kennel sale: a kaiju, or a rare roll to play (KaijuServer).
	if reward.KaijuSale then
		if not StoreServer.kaijuSale then
			return false
		end
		return StoreServer.kaijuSale(player, reward.KaijuSale)
	end
	local lines = StoreServer.grant(player, reward)
	local bundle = Store.bundle(key)
	if bundle and bundle.NewPlayersOnly then
		profile.WelcomeBought = true
	end
	if bundle and bundle.Once then
		profile[bundle.Once] = true
	end
	if key == "StarterPack" then
		profile.StarterBought = true
	end
	-- Put it on.
	local active = profile.Miners and profile.Miners.Active or 1
	local kits = Store.kitsOf(key)
	if kits then
		-- One per miner from this one; with one miner it wears the first kit
		-- and the rest wait in the Wardrobe.
		for i, kit in kits do
			if i <= MinerRoster.Count then
				local index = if MinerRoster.Enabled then (active - 1 + i - 1) % MinerRoster.Count + 1 else active
				dressMiner(player, profile, index, firstLook(kit.Contents.Cosmetics or {}))
			end
		end
	elseif key ~= "Vault" then
		dressMiner(player, profile, active, firstLook(reward.Cosmetics or {}))
	end
	PlayerData.sync(player)
	return true, lines
end

-- Testing: buy a product for coins (Store.testPrice), through the same
-- grant as Robux.
local function buyProduct(player: Player, key: any)
	local profile = PlayerData.get(player)
	if typeof(key) ~= "string" or not profile then
		return reply(false, "That isn't for sale.")
	end
	local price = Store.testPrice(key)
	if not price then
		return reply(false, if Store.robuxPrice(key) then "Buy it with Robux in the store." else "That isn't for sale.")
	end
	local ok, why = Store.canBuy(key, profile, os.time())
	if not ok then
		return reply(false, why or "That isn't for sale.")
	end
	if not PlayerData.spendCoins(player, price) then
		return Shop.short(player, price, string.format("You need %d coins.", price))
	end
	local granted, lines = StoreServer.grantProduct(player, key)
	if not granted then
		-- (A refill with no Outpost to put its swings on: the coins come back.)
		PlayerData.addCoins(player, price)
		return reply(false, "That didn't go through. Try again in a moment.")
	end
	return reply(true, Store.productName(key) .. " is yours!", { Key = key, Lines = lines or {} })
end

local function buyCosmetic(player: Player, id: any)
	if not Cosmetics.get(id) then
		return reply(false, "That isn't for sale.")
	end
	return buyProduct(player, id)
end

local function equipCosmetic(player: Player, kind: any, id: any)
	local profile = PlayerData.get(player)
	if not profile or (kind ~= "Trim" and kind ~= "Back" and kind ~= "Title" and not Cosmetics.isMinerKind(kind)) then
		return reply(false, "Pick something to wear.")
	end
	if id ~= nil then
		local cosmetic = Cosmetics.get(id)
		if not cosmetic or cosmetic.Kind ~= kind or not profile.Cosmetics.Owned[id] then
			return reply(false, "You don't own that yet.")
		end
	end
	PlayerData.setCosmetic(player, kind, id)
	return reply(true, if id then "Equipped " .. cosmeticName(id) .. "." else "Removed.")
end

local function claimSeason(player: Player, which: any)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Try again in a moment.")
	end
	local level = Season.levelFor(profile.Season.XP)
	local targets = {}
	if which == "all" then
		for l = 1, level do
			table.insert(targets, l)
		end
	elseif typeof(which) == "number" and which == math.floor(which) and which >= 1 and which <= level then
		targets = { which }
	else
		return reply(false, "Reach that level first.")
	end
	local season = profile.Season :: any
	season.PremiumClaimed = season.PremiumClaimed or {}
	local lines = {}
	for _, l in targets do
		local key = tostring(l)
		if not season.Claimed[key] then
			season.Claimed[key] = true
			for _, line in StoreServer.grant(player, Season.reward(l)) do
				table.insert(lines, line)
			end
		end
		-- The premium track's reward at this level, if you've unlocked it.
		local premium = Season.premiumReward(l)
		if season.Premium and premium and not season.PremiumClaimed[key] then
			season.PremiumClaimed[key] = true
			for _, line in StoreServer.grant(player, premium) do
				table.insert(lines, line)
			end
		end
	end
	if #lines == 0 then
		return reply(false, "Nothing new to claim.")
	end
	return reply(true, "Season rewards: " .. table.concat(lines, ", "), { Lines = lines })
end

-- The Starter Pack goes on offer the first time the client shows it (after
-- your first win); it stays on offer for Store.StarterPack.Hours.
local function starterOffer(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return reply(false, "Try again in a moment.")
	end
	if not profile.StarterOfferAt and not profile.StarterBought then
		profile.StarterOfferAt = os.time()
		PlayerData.sync(player)
	end
	return reply(true, "", { OfferedAt = profile.StarterOfferAt, Bought = profile.StarterBought == true })
end

-- Robux purchases (only for products switched on in Store.RobuxProducts).
-- Roblox can deliver a receipt more than once: each purchase is granted
-- once, by its PurchaseId (the last 200 are kept on the profile).
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and PlayerData.get(player) :: any
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = Store.productKey(receipt.ProductId)
	if not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Saved now, so a crash can't lose a paid purchase. (A session that
	-- never saves, the Playtest fresh start, counts as saved.)
	local persists = PlayerData.save ~= nil and (not PlayerData.mayPersist or PlayerData.mayPersist(player))
	local function saved(): boolean
		if not persists then
			return true
		end
		local ok, done = pcall(PlayerData.save, player)
		return ok and done == true
	end
	-- A session whose save didn't load (or that another server took over)
	-- never saves: granted here, it'd be gone when they leave. It waits for
	-- one that saves (Roblox asks again when they next join).
	if persists and PlayerData.keeps and not PlayerData.keeps(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Receipts = profile.Receipts or {}
	local id = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, id) then
		-- Granted before: done only once that's saved too (its save may have
		-- failed then), never granted twice.
		return if saved()
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not StoreServer.grantProduct(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, id)
	while #profile.Receipts > 200 do
		table.remove(profile.Receipts, 1)
	end
	-- Not saved (a failed save, or one already under way): Roblox asks again
	-- later, and the receipt kept above makes that a save, not a second grant.
	if not saved() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function StoreServer.start()
	Shop.register("BuyProduct", buyProduct)
	Shop.register("BuyCosmetic", buyCosmetic)
	Shop.register("EquipCosmetic", equipCosmetic)
	Shop.register("ClaimSeason", claimSeason)
	Shop.register("StarterOffer", starterOffer)
	local anyRobux = false
	for _, id in Store.RobuxProducts do
		anyRobux = anyRobux or id ~= 0
	end
	if anyRobux then
		MarketplaceService.ProcessReceipt = processReceipt
	end
end

return StoreServer
