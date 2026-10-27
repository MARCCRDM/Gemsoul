-- Equipment selection and the station gem exchange. No crafting or salvage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local TestAdmin = require(script.Parent.TestAdmin)
local Equipment = require(script.Parent.Equipment)
local AutoEquip = require(ReplicatedStorage.Shared.AutoEquip)
local UpgradeRecommendations = require(ReplicatedStorage.Shared.UpgradeRecommendations)
local Enchanting = require(script.Parent.Enchanting)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Nearby = require(script.Parent.Nearby)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Shop = require(script.Parent.Shop)

local RANGE = 40 -- studs from Hilde or Borin
-- Who buys gems: Tamsin at the town's Market, Ilsa in the Saga Shelter.
local BUYERS = { "Market", "GemBuyer" }
local reply = Shop.reply

local Forge = {}
local Combat = require(game:GetService("ReplicatedStorage").Shared.Combat)

-- Checks a list of gem ids from the client: all distinct and all yours.
local function pickGems(player: Player, ids: any): { any }?
	if typeof(ids) ~= "table" or #ids == 0 or #ids > Config.MaxGems then
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

local function gearFor(classId: string?, kind: any, gearId: any)
	if not classId or typeof(gearId) ~= "string" then
		return nil
	end
	return if typeof(kind) == "string" then Classes.gear(classId, kind, gearId) else nil
end

-- Tamsin at the Market buys stones for coins (less than Hilde's Marks).
local function marketSell(player: Player, ids: any)
	if not Nearby.vendor(player, BUYERS, RANGE) then
		return reply(false, "Ilsa buys gems at the GEM BUYER desk in the Gem Gallery.")
	end
	local gems = pickGems(player, ids)
	if not gems then
		return reply(false, "Those gems aren't in your pouch.")
	end
	local total = 0
	for _, gem in gems do
		total += Crafting.marketPrice(gem)
		PlayerData.removeGem(player, gem.Id)
	end
	PlayerData.addCoins(player, total)
	PlayerData.milestone(player, "Sold")
	Progress.addXP(player, "Sell")
	return reply(true, string.format("Sold %d gem%s for %d coins.", #gems, if #gems == 1 then "" else "s", total))
end

-- Every spare Common (or Uncommon) sold in one tap, at the shop's rate:
-- the loose ones no loadout names (GemInventory.spare). Mining is mostly
-- Commons; this turns a session's into coins for the player market.
local SPARE = { Common = true, Uncommon = true }
local function sellSpare(player: Player, tier: any)
	if not Nearby.vendor(player, BUYERS, RANGE) then
		return reply(false, "Ilsa buys gems at the GEM BUYER desk in the Gem Gallery.")
	end
	local profile = PlayerData.get(player)
	if typeof(tier) ~= "string" or not SPARE[tier] or not profile then
		return reply(false, "Pick Commons or Uncommons to sell.")
	end
	local gems = GemInventory.spare(profile, tier)
	local label = GemConfig.TierLabels[tier] or tier
	if #gems == 0 then
		return reply(false, string.format("No spare %ss to sell.", label))
	end
	local ids, total = {}, 0
	for _, gem in gems do
		ids[gem.Id] = true
		total += Crafting.marketPrice(gem)
	end
	local sold = PlayerData.removeGems(player, ids)
	PlayerData.addCoins(player, total)
	PlayerData.milestone(player, "Sold")
	Progress.addXP(player, "Sell")
	return reply(
		true,
		string.format("Sold %d %s%s for %d coins.", sold, label, if sold == 1 then "" else "s", total),
		{ Sold = sold, Coins = total }
	)
end

local function equipGear(player: Player, kind: any, gearId: any)
	if not Combat.canChangeBuild(player) then return reply(false, "Change equipment in the Outpost.") end
	local profile = PlayerData.get(player)
	local weapon = profile and Classes.weapon(profile.Character.Class, profile.Character.Weapon)
	if kind == "Shields" and weapon and Classes.TwoHanded[weapon.WeaponType] then
		return reply(false, "Both hand slots are occupied. Equip a one-handed weapon to use a shield.")
	end
	local gear = gearFor(profile and profile.Character.Class, kind, gearId)
	if not gear or not PlayerData.equipGear(player, kind, gearId) then
		return reply(false, "Recover that equipment in the mine or trade for it.")
	end
	return reply(true, "Equipped " .. Crafting.gearName(gear.Name, profile.Owned[kind][gearId]) .. ".")
end

-- AUTO EQUIP (Shared.AutoEquip): the gear you own that fits the mode best,
-- the weapon first, then the gems (Vey's rule, as socketing by hand).
local function autoEquip(player: Player, mode: any)
	if not AutoEquip.valid(mode) then
		return reply(false, "Pick how to equip: Best, Balanced or an element.")
	end
	if not Combat.canChangeBuild(player) then
		return reply(false, "Change equipment in the Outpost.")
	end
	local profile = PlayerData.get(player)
	if not profile or not profile.Character then
		return reply(false, "Your equipment is still loading.")
	end
	local plan = AutoEquip.plan(profile, mode)
	local label = AutoEquip.label(mode)
	if plan.Changes == 0 then
		return reply(true, string.format("Already your %s build: nothing to change.", label), { Pieces = 0, Gems = 0 })
	end
	local pieces, gems = 0, 0
	for _, step in plan.Gear do
		if PlayerData.equipGear(player, Slots.Definitions[step.Slot].Kind, step.Id) then
			pieces += 1
		end
	end
	local enchant = Enchanting.canEnchant(player)
	if enchant then
		for _, step in plan.Gems do
			if PlayerData.socketGem(player, step.Gem, step.Slot) then
				gems += 1
			end
		end
	end
	-- Your rarest skins of each kind, too (ownership checked again here).
	local looks = 0
	for _, step in plan.Looks do
		local cosmetic = Cosmetics.get(step.Id)
		if cosmetic and cosmetic.Kind == step.Kind and profile.Cosmetics.Owned[step.Id] then
			PlayerData.setCosmetic(player, step.Kind, step.Id)
			looks += 1
		end
	end
	if pieces == 0 and gems == 0 and looks == 0 then
		return reply(
			false,
			if not enchant
				then "Visit Vey at the Arcanum (east road) to change enchantments."
				else "Couldn't change your equipment. Try again."
		)
	end
	local now = AutoEquip.rating(profile.Character)
	local message = string.format("%s build on: %d gear and %d gems changed. Rating %d.", label, pieces, gems, math.floor(now + 0.5))
	if looks > 0 then
		message ..= string.format("\nWearing your best skins (%d).", looks)
	end
	if not enchant and #plan.Gems > 0 then
		message ..= "\nVisit Vey at the Arcanum (east road) to change enchantments."
	end
	return reply(true, message, { Pieces = pieces, Gems = gems, Looks = looks, Rating = now })
end

local function upgradeSurges(player: Player)
	if not Combat.canChangeBuild(player) then
		return reply(false, "Change surges in the Outpost.")
	end
	local profile = PlayerData.get(player)
	if not profile or not profile.Character then
		return reply(false, "Your equipment is still loading.")
	end
	if not Enchanting.canEnchant(player) then
		return reply(false, "Visit Vey at the Arcanum (east road) to change enchantments.")
	end
	-- Recompute from server-owned inventory; never accept a client's suggested gems.
	local plan = UpgradeRecommendations.surges(profile)
	local count = 0
	for _, step in plan.Gems do
		if PlayerData.socketGem(player, step.Gem, step.Slot) then count += 1 end
	end
	if plan.Changes > 0 and count == 0 then
		return reply(false, "Couldn't upgrade your surges. Try again.")
	end
	return reply(true, if count > 0 then string.format("%d surge sockets upgraded. Existing elements and moves kept.", count)
		else "No stronger gems for your current moves.", { Gems = count })
end

local lastRegeneration: { [Player]: number } = {}
local function regenerateEquipment(player: Player)
	if not TestAdmin.allowed(player.UserId) then
		return reply(false, "This test tool is restricted to the test admin.")
	end
	local profile = PlayerData.get(player)
	local class = profile and Classes.List[profile.Character.Class]
	if not class then
		return reply(false, "Choose your character first.")
	end
	local now = os.clock()
	if lastRegeneration[player] and now - lastRegeneration[player] < 3 then
		return reply(false, "Wait three seconds before regenerating again.")
	end
	lastRegeneration[player] = now
	local rng = Random.new()
	profile.Character.RandomLoadoutVersion = nil
	-- Existing equipment and socketed gems stay owned; select a new six-item roll.
	GearRolls.grant(profile, class, rng)
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local id = profile.Character[slot]
		local gear = Classes.gear(profile.Character.Class, kind, id)
		local roll = GearRolls.roll(rng, gear.RarityTier, gear)
		-- Preserve the weighted visor rules used by normal starter generation.
		local previous = profile.Character.GearRolls[kind][id]
		roll.MatrixVisor = previous.MatrixVisor
		profile.Character.GearRolls[kind][id] = roll
	end
	PlayerData.sync(player)
	Equipment.apply(player)
	return reply(true, "Test loadout regenerated: six new equipment rolls.")
end

function Forge.start()
	Shop.register("AdminRegenerateEquipment", regenerateEquipment)
	Players.PlayerRemoving:Connect(function(player)
		lastRegeneration[player] = nil
	end)
	Shop.register("SellGems", marketSell) -- legacy sale requests also pay coins
	Shop.register("EquipGear", equipGear)
	Shop.register("AutoEquip", autoEquip)
	Shop.register("UpgradeSurges", upgradeSurges)
	Shop.register("MarketSell", marketSell)
	Shop.register("SellSpare", sellSpare)
end

return Forge
