-- Cosmetic broadcast only. OutpostServer awards loot before calling this.
local Remotes = require(script.Parent.Remotes)
local MiningRolls = {}
local serial = 0

function MiningRolls.publish(player, position, loot)
	if not loot or loot.Tutorial then return end
	serial += 1
	-- Share only the discovery, never the player's inventory or saved progression.
	local gem = nil
	if loot.Gem then
		gem = {}
		for _, key in { "Id", "Tier", "Element", "Size", "Clarity", "Cut" } do
			gem[key] = loot.Gem[key]
		end
	end
	Remotes.MiningRoll:FireAllClients({
		Id = serial,
		Seed = serial * 7919 % 2147483647,
		StartedAt = workspace:GetServerTimeNow(),
		Position = position,
		MinerId = player.UserId,
		MinerName = player.DisplayName,
		NodeName = loot.Name or "Mining rock",
		Gem = gem,
		Coins = loot.Coins,
		Gear = loot.Gear,
		Full = loot.Full == true,
	})
end
return MiningRolls
