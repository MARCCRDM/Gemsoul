--[[
	Another player's gear, to look at (Client.GearInspect: GEAR on the card
	beside a miner near you). What they wear: each of the six pieces, its
	rarity, its rolled stats and the gem in its socket, their gear score and
	level. Read only, and only theirs as worn: nothing spare, nothing saved.

	  "InspectGear", userId -> { Name, Level, Score, Class, Pieces = { {
	      Slot, Label, Name?, Rarity?, Stats = { { Stat, Amount } }, Perk?,
	      Gem = { Name, Element, Tier }? } } }
	  GearInspect.summary(profile) -> the same, for a profile (pure-ish)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local GearInspect = {}

GearInspect.Every = 0.75 -- seconds between looks, a player

-- What a profile wears, for someone else to see.
function GearInspect.summary(profile)
	local loadout = Classes.activeLoadout(profile and profile.Character or {}) or {}
	local pieces = {}
	for _, slot in Slots.Order do
		local def = Slots.Definitions[slot]
		local id = loadout[slot]
		local gear = id and Classes.gear(loadout.Class, def.Kind, id)
		local roll = id and GearRolls.get(loadout, slot)
		local stats = {}
		for stat, amount in roll and roll.Stats or {} do
			if type(amount) == "number" then
				table.insert(stats, { Stat = stat, Amount = amount })
			end
		end
		table.sort(stats, function(a, b)
			return a.Stat < b.Stat
		end)
		local gem = loadout[slot .. "Gem"]
		local rarity = roll and GearRolls.Rarities[roll.Rarity]
		table.insert(pieces, {
			Slot = slot,
			Label = def.Label,
			Name = gear and gear.Name or nil,
			Rarity = rarity and rarity.Name or nil,
			Stats = stats,
			Perk = gear and type(gear.Passive) == "table" and gear.Passive.Name or nil,
			Gem = if type(gem) == "table"
				then { Name = GemConfig.displayName(gem), Element = gem.Element, Tier = gem.Tier }
				else nil,
		})
	end
	local class = Classes.List[loadout.Class]
	return {
		Score = GearRolls.gearScore(loadout),
		Class = class and class.Name or nil,
		Pieces = pieces,
	}
end

local lastLook: { [Player]: number } = {}
local function inspect(player: Player, userId: any)
	local now = os.clock()
	if now - (lastLook[player] or 0) < GearInspect.Every then
		return Shop.reply(false, "One moment.")
	end
	lastLook[player] = now
	local other = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not other then
		return Shop.reply(false, "They're not in this server any more.")
	end
	local profile = PlayerData.get(other)
	if not profile then
		return Shop.reply(false, "Their gear is still loading.")
	end
	local summary = GearInspect.summary(profile)
	summary.Name = other.DisplayName
	summary.UserId = other.UserId
	summary.Level = other:GetAttribute("MinerLevel")
	return Shop.reply(true, "", summary)
end

local started = false
function GearInspect.start()
	if started then
		return
	end
	started = true
	Shop.register("InspectGear", inspect)
	Players.PlayerRemoving:Connect(function(player)
		lastLook[player] = nil
	end)
end

return GearInspect
