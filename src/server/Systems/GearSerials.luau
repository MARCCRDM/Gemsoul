--[[
	Who found a piece of gear first, and (for Ultra Rare and Legendary) its
	number among every one of that item ever found, across all servers:
	"#12  ·  Found by Marc". Written into the item's roll, so it travels with
	it through trades.

	  GearSerials.stamp(player, kind, gearId)  call when a player first finds
	      an item; numbers it in the background (a DataStore counter)
]]
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local PlayerData = require(script.Parent.PlayerData)

local GearSerials = {}

local store = nil
local function counters()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("Gear_Serials_v1")
		end)
		store = if ok then result else false
	end
	return store or nil
end

function GearSerials.stamp(player: Player, kind: string, gearId: string)
	local profile = PlayerData.get(player)
	local rolls = profile and profile.Character.GearRolls and profile.Character.GearRolls[kind]
	local roll = rolls and rolls[gearId]
	if not roll or roll.Serial then
		return
	end
	-- (PlayerData may have stamped the owner already when the find synced.)
	roll.FoundBy = roll.FoundBy or player.DisplayName
	roll.FoundById = roll.FoundById or player.UserId
	roll.FoundAt = roll.FoundAt or os.time()
	if (roll.Rarity or 1) < GearRolls.SerialFrom then
		PlayerData.sync(player)
		return
	end
	task.spawn(function()
		local counter = counters()
		local ok, serial = false, nil
		if counter then
			ok, serial = pcall(counter.IncrementAsync, counter, gearId, 1)
		end
		if ok and type(serial) == "number" then
			roll.Serial = serial
		end
		if player.Parent then
			PlayerData.sync(player)
		end
	end)
end

return GearSerials
