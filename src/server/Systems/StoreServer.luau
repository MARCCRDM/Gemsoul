--[[
	The Shop, crates, cosmetics and the Season Path. Request actions:
	  "BuyBundle", id              coins for a bundle (Welcome: new players, once)
	  "BuyCosmetic", id            coins for a trim or back piece
	  "BuyCrate", id, count?       coins for 1, 5 or 10 crates (bulk is cheaper)
	  "OpenCrate", id, count?      open up to 10 of your crates; returns each result
	  "EquipCosmetic", kind, id?   wear a trim / back piece you own (nil takes it off)
	  "ClaimSeason", level|"all"   claim Season Path rewards you've reached
	Robux: when an id is set in Store.RobuxProducts, buying that Developer
	Product grants the same bundle or crate (ProcessReceipt below).
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
	if not cosmetic or not cosmetic.Price or not profile then
		return reply(false, "That isn't for sale.")
	end
	if profile.Cosmetics.Owned[cosmetic.Id] then
		return reply(false, "You already own " .. cosmetic.Name .. ".")
	end
	if not PlayerData.spendCoins(player, cosmetic.Price) then
		return reply(false, string.format("You need %d coins.", cosmetic.Price))
	end
	profile.Cosmetics.Owned[cosmetic.Id] = true
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

-- A random cosmetic of `rarity` you don't own yet (nil if you own them all).
local function unownedOf(profile, rarity: string): string?
	local choices = {}
	for _, id in Cosmetics.Order do
		local cosmetic = Cosmetics.List[id]
		if cosmetic.Rarity == rarity and not profile.Cosmetics.Owned[id] then
			table.insert(choices, id)
		end
	end
	return if #choices > 0 then choices[Gems.random():NextInteger(1, #choices)] else nil
end

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
		local cosmeticId = unownedOf(profile, chosen.Cosmetic)
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
	if not profile or (kind ~= "Trim" and kind ~= "Back") then
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
	local lines = {}
	for _, l in targets do
		local key = tostring(l)
		if not profile.Season.Claimed[key] then
			profile.Season.Claimed[key] = true
			for _, line in StoreServer.grant(player, Season.reward(l)) do
				table.insert(lines, line)
			end
		end
	end
	if #lines == 0 then
		return reply(false, "Nothing new to claim.")
	end
	return reply(true, "Season rewards: " .. table.concat(lines, ", "), { Lines = lines })
end

-- Robux purchases (only for products you've switched on in Store.RobuxProducts).
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not PlayerData.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for key, productId in Store.RobuxProducts do
		if productId ~= 0 and productId == receipt.ProductId then
			local bundle = Store.bundle(key)
			if bundle then
				if bundle.NewPlayersOnly then
					PlayerData.get(player).WelcomeBought = true
				end
				StoreServer.grant(player, bundle.Contents)
			elseif Store.Crates[key] then
				StoreServer.grant(player, { Crates = { [key] = 1 } })
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function StoreServer.start()
	Shop.register("BuyBundle", buyBundle)
	Shop.register("BuyCosmetic", buyCosmetic)
	Shop.register("BuyCrate", buyCrate)
	Shop.register("OpenCrate", openCrate)
	Shop.register("EquipCosmetic", equipCosmetic)
	Shop.register("ClaimSeason", claimSeason)
	local anyRobux = false
	for _, id in Store.RobuxProducts do
		anyRobux = anyRobux or id ~= 0
	end
	if anyRobux then
		MarketplaceService.ProcessReceipt = processReceipt
	end
end

return StoreServer
