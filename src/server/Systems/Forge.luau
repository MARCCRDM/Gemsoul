--[[
	Borin's forge at the Craft & Cut workshop. Request actions:
	  "BuyMaterial", materialId, count      buy crafting materials
	  "SellGems", { gemId }                 60% of each gem's value in coins
	  "SalvageGems", { gemId }              break gems into Gem Shards
	  "Craft", kind, gearId                 make a piece, or raise its quality
	  "EquipGear", kind, gearId             wear gear you own (anywhere)
	kind is "Weapons" or "Armors". Everything except equipping needs you at
	the workshop. Costs come from shared/Crafting.luau.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Nearby = require(script.Parent.Nearby)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local RANGE = 40 -- studs from Borin or Ilsa
local MAX_BUY = 50
local reply = Shop.reply

local Forge = {}

local function atWorkshop(player: Player): boolean
	return Nearby.vendor(player, { "Forge", "Crafting" }, RANGE)
end
local AWAY = "Visit Borin's forge at Craft & Cut (north road)."

local function buyMaterial(player: Player, materialId: any, count: any)
	local material = typeof(materialId) == "string" and Crafting.Materials[materialId]
	if not material or not material.Price then
		return reply(false, "Borin doesn't sell that.")
	end
	if typeof(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > MAX_BUY then
		return reply(false, "Buy between 1 and " .. MAX_BUY .. " at a time.")
	end
	if not atWorkshop(player) then
		return reply(false, AWAY)
	end
	local profile = PlayerData.get(player)
	if not profile or not PlayerData.spendCoins(player, material.Price * count) then
		return reply(false, string.format("You need %d coins for that.", material.Price * count))
	end
	profile.Materials[materialId] = (profile.Materials[materialId] or 0) + count
	PlayerData.sync(player)
	return reply(true, string.format("Bought %d %s.", count, material.Name))
end

-- Checks a list of gem ids from the client: all distinct and all yours.
local function pickGems(player: Player, ids: any): { any }?
	if typeof(ids) ~= "table" or #ids == 0 or #ids > 200 then
		return nil
	end
	local seen, gems = {}, {}
	for _, id in ids do
		if typeof(id) ~= "string" or seen[id] then
			return nil
		end
		seen[id] = true
		local gem = PlayerData.findGem(player, id)
		if not gem then
			return nil
		end
		table.insert(gems, gem)
	end
	return gems
end

local function sellGems(player: Player, ids: any)
	if not atWorkshop(player) then
		return reply(false, AWAY)
	end
	local gems = pickGems(player, ids)
	if not gems then
		return reply(false, "Those gems aren't in your pouch.")
	end
	local total = 0
	for _, gem in gems do
		total += Crafting.sellPrice(gem)
		PlayerData.removeGem(player, gem.Id)
	end
	PlayerData.addCoins(player, total)
	return reply(true, string.format("Sold %d gem%s for %d coins.", #gems, if #gems == 1 then "" else "s", total))
end

local function salvageGems(player: Player, ids: any)
	if not atWorkshop(player) then
		return reply(false, AWAY)
	end
	local gems = pickGems(player, ids)
	local profile = PlayerData.get(player)
	if not gems or not profile then
		return reply(false, "Those gems aren't in your pouch.")
	end
	local shards = 0
	for _, gem in gems do
		shards += Crafting.salvageShards(gem)
		PlayerData.removeGem(player, gem.Id)
	end
	profile.Materials.Shards = (profile.Materials.Shards or 0) + shards
	PlayerData.sync(player)
	return reply(
		true,
		string.format("Salvaged %d gem%s into %d Gem Shards.", #gems, if #gems == 1 then "" else "s", shards)
	)
end

local function gearFor(classId: string?, kind: any, gearId: any)
	if not classId or typeof(gearId) ~= "string" then
		return nil
	end
	if kind == "Weapons" then
		return Classes.weapon(classId, gearId)
	elseif kind == "Armors" then
		return Classes.armor(classId, gearId)
	end
	return nil
end

local function craft(player: Player, kind: any, gearId: any)
	local profile = PlayerData.get(player)
	local classId = profile and profile.Character.Class
	local gear = gearFor(classId, kind, gearId)
	if not profile or not gear then
		return reply(false, "Your class can't craft that.")
	end
	if not atWorkshop(player) then
		return reply(false, AWAY)
	end
	local current = profile.Owned[kind][gearId] or 0
	if current >= Crafting.MaxQuality then
		return reply(false, gear.Name .. " is already Masterwork.")
	end
	local target = current + 1
	local recipe = Crafting.recipe(classId, kind, target) :: Crafting.Recipe
	-- Check everything before taking anything.
	for id, need in recipe.Materials do
		local have = profile.Materials[id] or 0
		if have < need then
			return reply(false, string.format("You need %d more %s.", need - have, Crafting.Materials[id].Name))
		end
	end
	if profile.Coins < recipe.Coins then
		return reply(false, string.format("You need %d coins.", recipe.Coins))
	end
	PlayerData.spendCoins(player, recipe.Coins)
	for id, need in recipe.Materials do
		profile.Materials[id] -= need
	end
	PlayerData.setGearQuality(player, kind, gearId, target)
	local name = Crafting.gearName(gear.Name, target)
	return reply(
		true,
		if current == 0
			then "Forged a " .. name .. "! Equip it from the forge or your character screen."
			else "Upgraded to " .. name .. "!",
		{ Quality = target }
	)
end

local function equipGear(player: Player, kind: any, gearId: any)
	local profile = PlayerData.get(player)
	local gear = gearFor(profile and profile.Character.Class, kind, gearId)
	if not gear or not PlayerData.equipGear(player, kind, gearId) then
		return reply(false, "You don't own that yet. Craft it at Borin's forge.")
	end
	return reply(true, "Equipped " .. Crafting.gearName(gear.Name, profile.Owned[kind][gearId]) .. ".")
end

function Forge.start()
	Shop.register("BuyMaterial", buyMaterial)
	Shop.register("SellGems", sellGems)
	Shop.register("SalvageGems", salvageGems)
	Shop.register("Craft", craft)
	Shop.register("EquipGear", equipGear)
end

return Forge
