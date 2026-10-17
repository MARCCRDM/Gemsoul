-- Cosmetic broadcast only. OutpostServer awards loot before calling this.
local Remotes = require(script.Parent.Remotes)
local MiningRolls = {}
local serial = 0

function MiningRolls.publish(player, position, loot)
	if not loot or loot.Tutorial then return end
	serial += 1
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
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
		MinerPosition = head and head.Position or position,
		MinerId = player.UserId,
		MinerName = player.DisplayName,
		NodeName = loot.Name or "Mining rock",
		Gem = gem,
		Full = loot.Full == true,
	})
end
return MiningRolls
