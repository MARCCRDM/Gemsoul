-- Equipment selection and the station gem exchange. No crafting or salvage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local TestAdmin = require(script.Parent.TestAdmin)
local Equipment = require(script.Parent.Equipment)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Nearby = require(script.Parent.Nearby)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Shop = require(script.Parent.Shop)

local RANGE = 40 -- studs from Hilde or Borin
local reply = Shop.reply

local Forge = {}

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

local function gearFor(classId: string?, kind: any, gearId: any)
	if not classId or typeof(gearId) ~= "string" then
		return nil
	end
	return if typeof(kind) == "string" then Classes.gear(classId, kind, gearId) else nil
end

-- Tamsin at the Market buys stones for coins (less than Hilde's Marks).
local function marketSell(player: Player, ids: any)
	if not Nearby.vendor(player, { "Market" }, RANGE) then
		return reply(false, "Tamsin trades at the Market in the town square.")
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

local function equipGear(player: Player, kind: any, gearId: any)
	local profile = PlayerData.get(player)
	local gear = gearFor(profile and profile.Character.Class, kind, gearId)
	if not gear or not PlayerData.equipGear(player, kind, gearId) then
		return reply(false, "Recover that equipment in the mine or trade for it.")
	end
	return reply(true, "Equipped " .. Crafting.gearName(gear.Name, profile.Owned[kind][gearId]) .. ".")
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
		local roll = GearRolls.roll(rng, gear.RarityTier)
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
	Shop.register("MarketSell", marketSell)
end

return Forge
