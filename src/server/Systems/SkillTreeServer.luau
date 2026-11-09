--[[
	The skill tree's requests (Shared.SkillTree), on the saved loadout
	(profile.Character.Skills):

	  SkillLearn(id)          learn a move (points, its tier's level, the
	                          tier above it in that branch)
	  SkillEquip(key, id)     put a learned move on Q, E or R
	  SkillReset()            back to your element's tier 1 (points back)
	  SkillChoose(element)    a save from before the tree: choose an element
	                          (its tier 1 learned and on your keys; your gems
	                          power them from then on). Once.

	None of them mid-fight or on an expedition (Combat.canChangeBuild).
	Your level is the Augment level (Shared.AugmentTree, the lobby card's).

	  SkillTreeServer.start()
	  SkillTreeServer.handle(player, request, ...) -> reply   (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTree = require(ReplicatedStorage.Shared.SkillTree)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Combat = require(ReplicatedStorage.Shared.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local SkillTreeServer = {}

local function levelOf(profile): number
	return Tree.level(profile and profile.Augments and profile.Augments.XP or 0)
end

function SkillTreeServer.handle(player: Player, request: string, a: any, b: any)
	local profile = PlayerData.get(player)
	if not profile or not profile.Character then
		return Shop.reply(false, "Your profile is still loading.")
	end
	if not Combat.canChangeBuild(player) then
		return Shop.reply(false, "You can't change your skills during a fight or an expedition.")
	end
	local c = profile.Character
	if request == "Choose" then
		if c.Skills then
			return Shop.reply(false, "Your element is already chosen.")
		end
		if type(a) ~= "string" or not SkillTree.Trees[a] then
			return Shop.reply(false, "Choose one of the four elements.")
		end
		c.Skills = SkillTree.start(a)
	else
		local skills = SkillTree.clean(c.Skills)
		if not skills then
			return Shop.reply(false, "Choose your element first.")
		end
		c.Skills = skills
		local ok, why = true, nil
		if request == "Learn" then
			if type(a) ~= "string" then
				return Shop.reply(false, "That isn't on the tree.")
			end
			ok, why = SkillTree.learn(skills, a, levelOf(profile))
		elseif request == "Equip" then
			if type(a) ~= "string" or type(b) ~= "string" then
				return Shop.reply(false, "That move doesn't go there.")
			end
			ok, why = SkillTree.equip(skills, a, b)
		elseif request == "Reset" then
			c.Skills = SkillTree.reset(skills)
		else
			return Shop.reply(false, "Unknown request.")
		end
		if not ok then
			return Shop.reply(false, why or "Can't do that.")
		end
	end
	PlayerData.augmentsChanged(player) -- (sync, and the fight kit rebuilt)
	return Shop.reply(true, "", { Skills = c.Skills })
end

function SkillTreeServer.start()
	Shop.register("SkillLearn", function(player, id)
		return SkillTreeServer.handle(player, "Learn", id)
	end)
	Shop.register("SkillEquip", function(player, key, id)
		return SkillTreeServer.handle(player, "Equip", key, id)
	end)
	Shop.register("SkillReset", function(player)
		return SkillTreeServer.handle(player, "Reset")
	end)
	Shop.register("SkillChoose", function(player, element)
		return SkillTreeServer.handle(player, "Choose", element)
	end)
end

return SkillTreeServer
