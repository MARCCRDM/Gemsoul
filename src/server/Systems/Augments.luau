local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Combat = require(ReplicatedStorage.Shared.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local Augments = {}
local function canChange(player)
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight(root.Position)
end
function Augments.start()
	Shop.register("LearnAugment", function(player, id)
		local profile = PlayerData.get(player)
		if not profile then
			return Shop.reply(false, "Profile unavailable.")
		end
		if not canChange(player) then
			return Shop.reply(false, "Return to the dashboard or town to change augments.")
		end
		local ok, message = Tree.learn(profile, id)
		if ok then
			PlayerData.augmentsChanged(player)
		end
		return Shop.reply(ok, message, { Augments = profile.Augments })
	end)
	Shop.register("ResetAugments", function(player)
		local profile = PlayerData.get(player)
		if not profile then
			return Shop.reply(false, "Profile unavailable.")
		end
		if not canChange(player) then
			return Shop.reply(false, "Return to the dashboard or town to change augments.")
		end
		local ok, message = Tree.respec(profile)
		PlayerData.augmentsChanged(player)
		return Shop.reply(ok, message, { Augments = profile.Augments })
	end)
end
return Augments
