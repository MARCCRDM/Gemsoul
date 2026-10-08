local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local Augments = {}
local function canChange(player)
	return Combat.canChangeBuild(player)
end
function Augments.start()
	Shop.register("LearnAugment", function(player, id)
		if
			not Tech.ManeuversEnabled
			and typeof(id) == "string"
			and Tree.Nodes[id]
			and Tree.Nodes[id].Branch == "RigManeuvers"
		then
			return Shop.reply(false, "Rig Maneuvers are retired. Choose a Surge or passive augment.")
		end
		local profile = PlayerData.get(player)
		if not profile then
			return Shop.reply(false, "Profile unavailable.")
		end
		if not canChange(player) then
			return Shop.reply(false, "You can't change augments during a fight or an expedition.")
		end
		local ok, message = Tree.learn(profile, id)
		if ok then
			PlayerData.augmentsChanged(player)
		end
		return Shop.reply(ok, message, { Augments = profile.Augments })
	end)
	-- Raise an unlocked node one rank (Blades-style rank II and III).
	Shop.register("UpgradeAugment", function(player, id)
		if
			not Tech.ManeuversEnabled
			and typeof(id) == "string"
			and Tree.Nodes[id]
			and Tree.Nodes[id].Branch == "RigManeuvers"
		then
			return Shop.reply(false, "Rig Maneuvers are retired. Choose a Surge or passive augment.")
		end
		local profile = PlayerData.get(player)
		if not profile then
			return Shop.reply(false, "Profile unavailable.")
		end
		if not canChange(player) then
			return Shop.reply(false, "You can't change augments during a fight or an expedition.")
		end
		local ok, message = Tree.upgrade(profile, id)
		if ok then
			PlayerData.augmentsChanged(player)
		end
		return Shop.reply(ok, message, { Augments = profile.Augments })
	end)
	-- The Surge Array (Q, E, R) and the Rig Maneuver keys (1, 2, 3).
	Shop.register("SocketSurge", function(player, gemId, key)
		if typeof(gemId) ~= "string" or typeof(key) ~= "string" or not PlayerData.SurgeKeys[key] then
			return Shop.reply(false, "Pick a gem and a surge slot.")
		end
		if not canChange(player) then
			return Shop.reply(false, "You can't change your surges during a fight or an expedition.")
		end
		local gem = PlayerData.socketSurge(player, gemId, key)
		if not gem then
			return Shop.reply(false, "Choose a cut gem with a different Surge ability. Q, E and R accept any Surge.")
		end
		local id, tier, rank = Tech.surgeOf(gem)
		local surge = id and Tech.Catalog[id]
		return Shop.reply(
			true,
			string.format("%s ready on %s (tier %d, rank %d).", surge and surge.Name or "Surge", key, tier, rank),
			{ Gem = gem }
		)
	end)
	Shop.register("UnsocketSurge", function(player, key)
		if typeof(key) ~= "string" or not PlayerData.SurgeKeys[key] then
			return Shop.reply(false, "Pick a surge slot.")
		end
		if not canChange(player) then
			return Shop.reply(false, "You can't change your surges during a fight or an expedition.")
		end
		local gem = PlayerData.unsocketSurge(player, key)
		if not gem then
			return Shop.reply(false, "Nothing to remove, or your pouch is full.")
		end
		return Shop.reply(true, "Gem back in your pouch.", { Gem = gem })
	end)
	Shop.register("EquipManeuver", function(player, slot, id)
		if not Tech.ManeuversEnabled then
			return Shop.reply(false, "Rig Maneuvers are retired. Equip gems on Q, E and R.")
		end
		local profile = PlayerData.get(player)
		if
			not profile
			or typeof(slot) ~= "number"
			or slot ~= math.floor(slot)
			or slot < 1
			or slot > Tech.ManeuverSlots
		then
			return Shop.reply(false, "Pick key 1, 2 or 3.")
		end
		local node = typeof(id) == "string" and Tree.Nodes[id]
		if not node or node.Branch ~= "RigManeuvers" then
			return Shop.reply(false, "Pick a Rig Maneuver.")
		end
		if not Tree.isLearned(profile, id) then
			return Shop.reply(false, "Learn " .. node.Name .. " in the Augment Tree first.")
		end
		PlayerData.setManeuver(player, slot, id)
		require(script.Parent.Presets).captureActive(player) -- the active weapon loadout keeps it
		PlayerData.sync(player)
		return Shop.reply(true, string.format("%s on key %d.", node.Name, slot))
	end)
	Shop.register("ResetAugments", function(player)
		local profile = PlayerData.get(player)
		if not profile then
			return Shop.reply(false, "Profile unavailable.")
		end
		if not canChange(player) then
			return Shop.reply(false, "You can't change augments during a fight or an expedition.")
		end
		local ok, message = Tree.respec(profile)
		PlayerData.augmentsChanged(player)
		return Shop.reply(ok, message, { Augments = profile.Augments })
	end)
end
return Augments
