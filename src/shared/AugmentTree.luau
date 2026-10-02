--[[
	Persistent, server-owned build progression, laid out like an Elder Scrolls:
	Blades skill sheet. UI and server share one node graph.

	  Augment Level  1 + XP / 150; every level also earns an Augment Point
	  Tiers          I opens at level 1, II at level 3, III at level 6
	  Ranks          every node has ranks I-III; rank I unlocks it (its Cost),
	                 rank II costs its tier in points, rank III one more
	  Rank effects   maneuvers and surges hit harder, cost less, recover
	                 faster and last longer; passives add their bonus again

	Unlocking every node at rank I costs exactly Tree.UnlockPoints (24); the
	rest of the budget (up to Tree.MaxPoints) goes into ranks, so a full
	build is a choice of what to master.
]]
local Tech = require(script.Parent.CombatTechnology)
local Tree = {}
Tree.StartingPoints, Tree.XPPerPoint, Tree.MaxPoints = 3, 150, 60
Tree.UnlockPoints = 24
Tree.MaxRank = 3
Tree.TierLevels = { 1, 3, 6 }
-- Per rank above I.
Tree.RankScaling = { Damage = 0.10, Cost = -0.08, Recovery = -0.05, Duration = 0.15, Heal = 0.25 }
Tree.Branches = { "RigManeuvers", "GemSurges", "PassiveAugments" }
Tree.BranchNames = { RigManeuvers = "Rig Maneuvers", GemSurges = "Gem Surges", PassiveAugments = "Passive Augments" }
Tree.Order = {
	RigManeuvers = { "HydraulicSlam", "ServoFlurry", "KineticRam", "StimDodge", "BreachHammer", "ArmorPiercer" },
	GemSurges = { "ThermalBurst", "EnergySiphon", "CryoLance", "CryoShield", "CryoStream", "ResonanceEcho" },
	PassiveAugments = {
		"BladeCalibration",
		"CleaverCalibration",
		"MobilityAugment",
		"ChargeRecycler",
		"StaminaRecycler",
		"ThermalOvercharge",
	},
}
Tree.Nodes = {}
local costs = { 0, 1, 1, 1, 2, 2 }
for _, branch in { "RigManeuvers", "GemSurges" } do
	local order = Tree.Order[branch]
	for index, id in order do
		local definition = Tech.Catalog[id]
		Tree.Nodes[id] = {
			Id = id,
			Name = definition.Name,
			Description = definition.Description,
			Icon = definition.Icon,
			Branch = branch,
			Tier = math.ceil(index / 2),
			Column = if index % 2 == 1 then 1 else 2,
			Cost = costs[index] + (if branch == "GemSurges" and index == 4 then 1 else 0),
			Parent = if index == 1 then nil elseif index == 2 then order[1] else order[index - 2],
			Free = index == 1,
		}
	end
end
local passiveDefinitions = {
	BladeCalibration = {
		Name = "Blade Calibration",
		Description = "+5% damage with swords, blades and knives.",
		Effect = "Slashing",
		Amount = 0.05,
		Icon = "⚔",
	},
	CleaverCalibration = {
		Name = "Cleaver Calibration",
		Description = "+5% damage with axes and cleavers.",
		Effect = "Cleaving",
		Amount = 0.05,
		Icon = "⚒",
	},
	MobilityAugment = {
		Name = "Mobility Augment",
		Description = "+5% movement speed.",
		Effect = "Mobility",
		Amount = 0.05,
		Icon = "🥾",
	},
	ChargeRecycler = {
		Name = "Charge Recycler",
		Description = "+15% Charge regeneration while a gem is socketed.",
		Effect = "ChargeRegen",
		Amount = 0.15,
		Icon = "⚡",
	},
	StaminaRecycler = {
		Name = "Stamina Recycler",
		Description = "+15% Stamina regeneration.",
		Effect = "StaminaRegen",
		Amount = 0.15,
		Icon = "✊",
	},
	ThermalOvercharge = {
		Name = "Thermal Overcharge",
		Description = "+10% Thermal weapon, surge and burn damage.",
		Effect = "Thermal",
		Amount = 0.10,
		Icon = "🔥",
	},
}
for index, id in Tree.Order.PassiveAugments do
	local d = passiveDefinitions[id]
	Tree.Nodes[id] = {
		Id = id,
		Name = d.Name,
		Description = d.Description,
		Icon = d.Icon,
		Effect = d.Effect,
		Amount = d.Amount,
		Branch = "PassiveAugments",
		Tier = math.ceil(index / 2),
		Column = if index % 2 == 1 then 1 else 2,
		Cost = if index <= 3 then 1 else 2,
		Parent = if index <= 2 then nil else Tree.Order.PassiveAugments[index - 2],
	}
end
local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end
local function earned(xp)
	return math.min(Tree.MaxPoints, Tree.StartingPoints + math.floor(xp / Tree.XPPerPoint))
end
Tree.MaxLevel = Tree.MaxPoints - Tree.StartingPoints + 1
function Tree.level(xp: number): number
	return math.min(Tree.MaxLevel, 1 + math.floor(math.max(0, xp) / Tree.XPPerPoint))
end
function Tree.tierLevel(id: string): number
	local n = Tree.Nodes[id]
	return if n then Tree.TierLevels[n.Tier] or 1 else math.huge
end
-- Points to take a node from rank-1 to `rank` (rank 1 = unlocking it).
function Tree.rankCost(id: string, rank: number): number
	local n = Tree.Nodes[id]
	if not n then
		return math.huge
	end
	return if rank <= 1 then n.Cost else n.Tier + rank - 2
end
function Tree.initialize(profile)
	local saved = if typeof(profile.Augments) == "table" then profile.Augments else nil
	local xp = if saved then saved.XP else profile.Season and profile.Season.XP or 0
	xp = if finite(xp) then math.clamp(math.floor(xp), 0, 100000000) else 0
	local unlocked = { HydraulicSlam = true, ThermalBurst = true }
	local ranks = { HydraulicSlam = 1, ThermalBurst = 1 }
	local source = saved and saved.Unlocked
	local savedRanks = if saved and typeof(saved.Ranks) == "table" then saved.Ranks else {}
	local spent, budget, level = 0, earned(xp), Tree.level(xp)
	-- Unlocks first (cheapest, tree order), then ranks; anything the level or
	-- budget can't cover is dropped, so a forged save can't mint power.
	if typeof(source) == "table" then
		for _, branch in Tree.Branches do
			for _, id in Tree.Order[branch] do
				local n = Tree.Nodes[id]
				if
					not n.Free
					and source[id] == true
					and (not n.Parent or unlocked[n.Parent])
					and level >= Tree.tierLevel(id)
					and spent + n.Cost <= budget
				then
					unlocked[id], ranks[id], spent = true, 1, spent + n.Cost
				end
			end
		end
	end
	for _, branch in Tree.Branches do
		for _, id in Tree.Order[branch] do
			local wanted = savedRanks[id]
			if unlocked[id] and finite(wanted) then
				for rank = 2, math.clamp(math.floor(wanted), 1, Tree.MaxRank) do
					local cost = Tree.rankCost(id, rank)
					if spent + cost > budget then
						break
					end
					ranks[id], spent = rank, spent + cost
				end
			end
		end
	end
	profile.Augments = {
		Version = 2,
		XP = xp,
		Level = level,
		Unlocked = unlocked,
		Ranks = ranks,
		Points = budget - spent,
		Earned = budget,
		Spent = spent,
	}
	return profile.Augments
end
function Tree.rank(profile, id): number
	local data = profile and profile.Augments
	if not data and profile then
		data = Tree.initialize(profile)
	end
	return if data and data.Unlocked[id] then (data.Ranks and data.Ranks[id] or 1) else 0
end
function Tree.isLearned(profile, id)
	local data = profile and profile.Augments
	if not data and profile then
		data = Tree.initialize(profile)
	end
	return Tree.Nodes[id] ~= nil and data ~= nil and data.Unlocked[id] == true
end
function Tree.learn(profile, id)
	local n = if typeof(id) == "string" then Tree.Nodes[id] else nil
	if not n then
		return false, "Unknown augment."
	end
	local data = Tree.initialize(profile)
	if data.Unlocked[id] then
		return false, "Already unlocked."
	end
	if n.Parent and not data.Unlocked[n.Parent] then
		return false, "Unlock " .. Tree.Nodes[n.Parent].Name .. " first."
	end
	if data.Level < Tree.tierLevel(id) then
		return false, string.format("Tier %d opens at Augment Level %d.", n.Tier, Tree.tierLevel(id))
	end
	if data.Points < n.Cost then
		return false, "Not enough Augment Points."
	end
	data.Unlocked[id], data.Points = true, data.Points - n.Cost
	data.Ranks[id] = 1
	data.Spent += n.Cost
	return true, "Unlocked " .. n.Name .. "."
end
-- Raises an unlocked node one rank.
function Tree.upgrade(profile, id)
	local n = if typeof(id) == "string" then Tree.Nodes[id] else nil
	if not n then
		return false, "Unknown augment."
	end
	local data = Tree.initialize(profile)
	if not data.Unlocked[id] then
		return false, "Unlock " .. n.Name .. " first."
	end
	local rank = data.Ranks[id] or 1
	if rank >= Tree.MaxRank then
		return false, n.Name .. " is already at its highest rank."
	end
	local cost = Tree.rankCost(id, rank + 1)
	if data.Points < cost then
		return false, "Not enough Augment Points."
	end
	data.Ranks[id] = rank + 1
	data.Points -= cost
	data.Spent += cost
	return true, string.format("%s raised to rank %d.", n.Name, rank + 1)
end
function Tree.respec(profile)
	local data = Tree.initialize(profile)
	profile.Augments = { XP = data.XP, Unlocked = {} }
	Tree.initialize(profile)
	return true, "Augments reset. Your points have been refunded."
end
function Tree.addXP(profile, amount)
	if not finite(amount) or amount <= 0 then
		return 0
	end
	local data = Tree.initialize(profile)
	local before = data.Earned
	data.XP = math.min(100000000, data.XP + math.floor(amount))
	data.Level = Tree.level(data.XP)
	data.Earned = earned(data.XP)
	data.Points = data.Earned - data.Spent
	return data.Earned - before
end
function Tree.available(profile, branch)
	local result = {}
	for _, id in Tech.Order[branch] or {} do
		if Tree.isLearned(profile, id) then
			table.insert(result, id)
		end
	end
	return result
end
function Tree.effects(profile)
	local effects = {}
	for _, id in Tree.Order.PassiveAugments do
		local rank = Tree.rank(profile, id)
		if rank > 0 then
			local n = Tree.Nodes[id]
			effects[n.Effect] = n.Amount * rank
		end
	end
	return effects
end
-- A technology's numbers at the rank the player owns (a copy; the catalog is untouched).
function Tree.scaled(definition, rank: number)
	local stats = table.clone(definition)
	local steps = math.max(0, (rank or 1) - 1)
	if steps == 0 then
		return stats
	end
	local s = Tree.RankScaling
	if stats.Damage then
		stats.Damage *= 1 + s.Damage * steps
	end
	if stats.Cost then
		stats.Cost *= 1 + s.Cost * steps
	end
	if stats.Recovery then
		stats.Recovery *= 1 + s.Recovery * steps
	end
	if stats.Duration then
		stats.Duration *= 1 + s.Duration * steps
	end
	if stats.Heal then
		stats.Heal *= 1 + s.Heal * steps
	end
	return stats
end
function Tree.techStats(profile, id)
	local definition = Tech.Catalog[id]
	return definition and Tree.scaled(definition, math.max(1, Tree.rank(profile, id)))
end
function Tree.weaponMultiplier(effects, weapon)
	if weapon.Attack.Kind ~= "Melee" then
		return 1
	end
	local look = string.lower(weapon.Look or "")
	if string.find(look, "axe") or string.find(look, "cleaver") then
		return 1 + (effects.Cleaving or 0)
	end
	if string.find(look, "sword") or string.find(look, "blade") or string.find(look, "kniv") then
		return 1 + (effects.Slashing or 0)
	end
	return 1
end
return Tree
