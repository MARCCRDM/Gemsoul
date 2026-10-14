--[[
	The Shop, crates, cosmetics and the Season Path. Request actions:
	  "BuyBundle", id              coins for a bundle (Welcome: new players, once)
	  "BuyCosmetic", id            coins for a trim or back piece
	  "BuyCrate", id, count?       coins for 1, 5 or 10 crates (bulk is cheaper)
	  "OpenCrate", id, count?      open up to 10 of your crates; returns each result
	  "EquipCosmetic", kind, id?   wear a trim / back piece / weapon skin / suit / title you own
	                               (nil takes it off)
	  "ClaimSeason", level|"all"   claim Season Path rewards you've reached (and
	                               the premium track's, if unlocked)
	  "StarterOffer"               puts the Starter Pack on offer (once, after a win)
	Robux: when an id is set in Store.RobuxProducts, buying that Developer
	Product grants its bundle, crate, cosmetic, Starter Pack or Season premium
	(ProcessReceipt below), once per purchase.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Economy = require(ReplicatedStorage.Shared.ExpeditionEconomy)
local Season = require(ReplicatedStorage.Shared.Season)
local Store = require(ReplicatedStorage.Shared.Store)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local StoreServer = {}

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
	if reward.Coins then
		profile.Coins += reward.Coins
		add(string.format("%d coins", reward.Coins))
	end
	local legacy = Economy.legacyCredits(reward.Marks, reward.Materials)
	if legacy > 0 then
		profile.Coins += legacy
		add(string.format("%d legacy salvage credits", legacy))
	end
	for id, count in reward.Crates or {} do
		if Store.Crates[id] then
			profile.Crates[id] = (profile.Crates[id] or 0) + count
			add(string.format("%d %s", count, Store.Crates[id].Name))
		end
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

local function welcomeOpen(profile): boolean
	return profile.FirstJoin > 0
		and not profile.WelcomeBought
		and os.time() < profile.FirstJoin + Store.WelcomeHours * 3600
end

local function buyBundle(player: Player, id: any)
	local bundle = Store.bundle(id)
	local profile = PlayerData.get(player)
	if not bundle or not profile then
		return reply(false, "That bundle isn't for sale.")
	end
	if bundle.NewPlayersOnly and not welcomeOpen(profile) then
		return reply(false, "The Welcome Bundle is only for new players, once.")
	end
	if not PlayerData.spendCoins(player, bundle.Price) then
		return reply(false, string.format("You need %d coins.", bundle.Price))
	end
	if bundle.NewPlayersOnly then
		profile.WelcomeBought = true
	end
	local lines = StoreServer.grant(player, bundle.Contents)
	return reply(true, bundle.Name .. ": " .. table.concat(lines, ", "), { Lines = lines })
end

local function buyCosmetic(player: Player, id: any)
	local cosmetic = Cosmetics.get(id)
	local profile = PlayerData.get(player)
	local price = cosmetic and Cosmetics.coinPrice(cosmetic)
	if not cosmetic or not price or not profile then
		return reply(false, "That isn't for sale.")
	end
	if profile.Cosmetics.Owned[cosmetic.Id] then
		return reply(false, "You already own " .. cosmetic.Name .. ".")
	end
	if not PlayerData.spendCoins(player, price) then
		return reply(false, string.format("You need %d coins.", price))
	end
	profile.Cosmetics.Owned[cosmetic.Id] = true
	-- A skin, suit or pick goes straight on, as a Robux purchase does.
	if Cosmetics.isMinerKind(cosmetic.Kind) then
		PlayerData.setCosmetic(player, cosmetic.Kind, cosmetic.Id)
		PlayerData.sync(player)
		return reply(true, "Unlocked " .. cosmetic.Name .. " and put it on!")
	end
	PlayerData.sync(player)
	return reply(true, "Unlocked " .. cosmetic.Name .. "! Equip it from the Shop.")
end

local function buyCrate(player: Player, id: any, count: any)
	local crate = typeof(id) == "string" and Store.Crates[id]
	local profile = PlayerData.get(player)
	local amount = if count == nil then 1 else count
	local price = crate and Store.cratePrice(crate, amount)
	if not crate or not profile or not price then
		return reply(false, "That crate isn't for sale.")
	end
	if not PlayerData.spendCoins(player, price) then
		return reply(false, string.format("You need %d coins.", price))
	end
	profile.Crates[crate.Id] = (profile.Crates[crate.Id] or 0) + amount
	PlayerData.sync(player)
	return reply(true, string.format("Bought %d %s%s.", amount, crate.Name, if amount == 1 then "" else "s"))
end

-- A random cosmetic of `rarity` you don't own yet, from `crateId`'s pool:
-- the trims and back pieces in Cosmetics.Order, plus the loot skins, suits
-- and picks (never sold, never exclusive) for this crate or any crate. Nil
-- if you own them all.
local LOOT = table.clone(Cosmetics.Order)
for _, kind in Cosmetics.MinerKinds do
	for _, id in Cosmetics.ofKind(kind) do
		local cosmetic = Cosmetics.List[id]
		if not cosmetic.Exclusive and not cosmetic.Robux and not cosmetic.Price then
			table.insert(LOOT, id)
		end
	end
end
local function unownedOf(profile, rarity: string, crateId: string?): string?
	local choices = {}
	for _, id in LOOT do
		local cosmetic = Cosmetics.List[id]
		local here = cosmetic.Crate == nil or cosmetic.Crate == crateId
		if cosmetic.Rarity == rarity and here and not profile.Cosmetics.Owned[id] then
			table.insert(choices, id)
		end
	end
	return if #choices > 0 then choices[Gems.random():NextInteger(1, #choices)] else nil
end
StoreServer.Loot = LOOT

-- Opens one crate: rolls, grants, and describes the result for the reveal.
local function openOne(player: Player, profile, crate: Store.Crate)
	profile.Crates[crate.Id] -= 1
	local total = 0
	for _, roll in crate.Rolls do
		total += roll.Weight
	end
	local pick = Gems.random():NextNumber(0, total)
	local chosen = crate.Rolls[#crate.Rolls]
	for _, roll in crate.Rolls do
		pick -= roll.Weight
		if pick <= 0 then
			chosen = roll
			break
		end
	end
	local reward: Store.Reward = chosen.Reward or {}
	local rarity = "Common"
	if chosen.Cosmetic then
		rarity = chosen.Cosmetic
		local cosmeticId = unownedOf(profile, chosen.Cosmetic, crate.Id)
		reward = if cosmeticId then { Cosmetics = { cosmeticId } } else { Coins = Store.DuplicateRefund * 2 }
	elseif reward.CutGems or reward.Marks then
		rarity = "Uncommon"
	end
	return {
		Lines = StoreServer.grant(player, reward),
		Rarity = rarity,
		Cosmetic = reward.Cosmetics and reward.Cosmetics[1],
		Kind = if reward.Cosmetics
			then "Cosmetic"
			elseif reward.CutGems then "CutGems"
			elseif reward.Stones then "Stones"
			elseif reward.Marks then "Marks"
			elseif reward.Materials then "Materials"
			else "Coins",
		Odds = math.max(1, math.floor(total / chosen.Weight * 10 + 0.5) / 10), -- "1 in N"
	}
end

-- Opens `count` crates (1-10). Returns every result for the reveal.
local function openCrate(player: Player, id: any, count: any)
	local crate = typeof(id) == "string" and Store.Crates[id]
	local profile = PlayerData.get(player)
	if not crate or not profile then
		return reply(false, "Unknown crate.")
	end
	local amount = if typeof(count) == "number" then math.clamp(math.floor(count), 1, 10) else 1
	local have = profile.Crates[crate.Id] or 0
	if have < 1 then
		return reply(false, "You don't have a " .. crate.Name .. ". Buy one in the Shop.")
	end
	amount = math.min(amount, have)
	local results = {}
	for _ = 1, amount do
		table.insert(results, openOne(player, profile, crate))
	end
	local first = results[1]
	return reply(true, crate.Name .. ": " .. table.concat(first.Lines, ", "), {
		Results = results,
		-- The first result, for callers that only show one.
		Lines = first.Lines,
		Rarity = first.Rarity,
		Cosmetic = first.Cosmetic,
	})
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

-- What a Robux product grants (Store.RobuxProducts key). Returns false for
-- a key it doesn't know.
function StoreServer.grantProduct(player: Player, key: string): boolean
	local profile = PlayerData.get(player) :: any
	if not profile then
		return false
	end
	local bundle = Store.bundle(key)
	local cosmetic = Cosmetics.get(key)
	if bundle then
		if bundle.NewPlayersOnly then
			profile.WelcomeBought = true
		end
		StoreServer.grant(player, bundle.Contents)
	elseif Store.Crates[key] then
		StoreServer.grant(player, { Crates = { [key] = 1 } })
	elseif cosmetic and cosmetic.Robux then
		-- Bought: yours, and on straight away.
		profile.Cosmetics.Owned[cosmetic.Id] = true
		PlayerData.setCosmetic(player, cosmetic.Kind, cosmetic.Id)
	elseif key == "StarterPack" then
		profile.StarterBought = true
		StoreServer.grant(player, Store.StarterPack.Contents)
		local suit = Store.StarterPack.Contents.Cosmetics and Store.StarterPack.Contents.Cosmetics[1]
		if suit and Cosmetics.get(suit) then
			PlayerData.setCosmetic(player, Cosmetics.get(suit).Kind, suit)
		end
	elseif key == "SeasonPremium" then
		profile.Season.Premium = true
	else
		return false
	end
	PlayerData.sync(player)
	return true
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
	profile.Receipts = profile.Receipts or {}
	local id = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, id) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not StoreServer.grantProduct(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, id)
	while #profile.Receipts > 200 do
		table.remove(profile.Receipts, 1)
	end
	-- Saved now, so a crash can't lose a paid purchase.
	if PlayerData.save then
		pcall(PlayerData.save, player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function StoreServer.start()
	Shop.register("BuyBundle", buyBundle)
	Shop.register("BuyCosmetic", buyCosmetic)
	Shop.register("BuyCrate", buyCrate)
	Shop.register("OpenCrate", openCrate)
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
