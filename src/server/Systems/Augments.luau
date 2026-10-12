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
		PlayerData.training(player,"EquipSurge")
		local profile = PlayerData.get(player)
		if profile and Tech.Traits.active(profile.Character) then
			local trait = Tech.Catalog[Tech.Traits.traitFor(gem, key) or ""]
			return Shop.reply(
				true,
				string.format("%s ready on %s.", if trait then trait.Name else "Your move", key),
				{ Gem = gem }
			)
		end
		local id, tier, rank = Tech.surgeOf(gem)
		local surge = id and Tech.Catalog[id]
		return Shop.reply(
			true,
			string.format("%s ready on %s (tier %d, rank %d).", surge and surge.Name or "Surge", key, tier, rank),
			{ Gem = gem }
		)
	end)
	-- The triad's DEV switch: back to the classic surge array, or on to Q / E / R.
	Shop.register("DevAbilities", function(player, mode)
		local TestAdmin = require(script.Parent.TestAdmin)
		if not TestAdmin.allowed(player.UserId) then
			return Shop.reply(false, "This test tool is restricted to the test admin.")
		end
		if mode ~= "Classic" and mode ~= "Triad" then
			return Shop.reply(false, "Pick Classic or Triad.")
		end
		if not canChange(player) then
			return Shop.reply(false, "Not during a fight or an expedition.")
		end
		PlayerData.setLegacySurges(player, mode == "Classic")
		return Shop.reply(
			true,
			if mode == "Classic"
				then "Classic surges: Q, E and R read the three surge sockets."
				else "The triad: Q is your sword's gem, E your core gem, R your shield's."
		)
	end)
	-- Reforge: reroll one trait of a gem (in the pouch or socketed).
	Shop.register("ReforgeTrait", function(player, gemId, lane)
		local profile = PlayerData.get(player)
		if not profile or typeof(gemId) ~= "string" or not Tech.Traits.LaneNames[lane] then
			return Shop.reply(false, "Pick a gem and a trait.")
		end
		if not canChange(player) then
			return Shop.reply(false, "Not during a fight or an expedition.")
		end
		local gem = PlayerData.findGem(player, gemId)
		if not gem then
			for key, value in profile.Character do
				if type(value) == "table" and value.Id == gemId and string.sub(key, -3) == "Gem" then
					gem = value
				end
			end
		end
		if not gem or not Tech.Traits.Matrix[gem.Element or ""] then
			return Shop.reply(false, "That gem can't be reforged.")
		end
		local coins, marks = Tech.Traits.reforgeCost(gem)
		if profile.Coins < coins or profile.Marks < marks then
			return Shop.reply(false, string.format("Reforging costs %d coins and %d Guild Marks.", coins, marks))
		end
		PlayerData.spendCoins(player, coins)
		PlayerData.spendMarks(player, marks)
		local id = Tech.Traits.reforge(gem, lane, Random.new():NextNumber())
		PlayerData.sync(player)
		local move = id and Tech.Catalog[id]
		return Shop.reply(true, string.format("Reforged: %s is now %s.", lane, move and move.Name or "?"), { Gem = gem, Trait = id })
	end)
	-- The "what's new" card about the triad has been read.
	Shop.register("TriadSeen", function(player)
		local profile = PlayerData.get(player)
		if profile then
			(profile :: any).TriadSeen = true;
			(profile :: any).TriadNotice = nil
			PlayerData.sync(player)
		end
		return Shop.reply(true, "")
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
