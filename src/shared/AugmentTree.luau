-- Persistent, server-owned build progression. UI and server share one node graph.
local Tech = require(script.Parent.CombatTechnology)
local Tree = {}
Tree.StartingPoints, Tree.XPPerPoint, Tree.MaxPoints = 3, 150, 24
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
function Tree.initialize(profile)
	local saved = if typeof(profile.Augments) == "table" then profile.Augments else nil
	local xp = if saved then saved.XP else profile.Season and profile.Season.XP or 0
	xp = if finite(xp) then math.clamp(math.floor(xp), 0, 100000000) else 0
	local unlocked = { HydraulicSlam = true, ThermalBurst = true }
	local source = saved and saved.Unlocked
	local spent, budget = 0, earned(xp)
	if typeof(source) == "table" then
		for _, branch in Tree.Branches do
			for _, id in Tree.Order[branch] do
				local n = Tree.Nodes[id]
				if
					not n.Free
					and source[id] == true
					and (not n.Parent or unlocked[n.Parent])
					and spent + n.Cost <= budget
				then
					unlocked[id], spent = true, spent + n.Cost
				end
			end
		end
	end
	profile.Augments =
		{ Version = 1, XP = xp, Unlocked = unlocked, Points = budget - spent, Earned = budget, Spent = spent }
	return profile.Augments
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
	if data.Points < n.Cost then
		return false, "Not enough Augment Points."
	end
	data.Unlocked[id], data.Points = true, data.Points - n.Cost
	data.Spent += n.Cost
	return true, "Unlocked " .. n.Name .. "."
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
		if Tree.isLearned(profile, id) then
			local n = Tree.Nodes[id]
			effects[n.Effect] = n.Amount
		end
	end
	return effects
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
