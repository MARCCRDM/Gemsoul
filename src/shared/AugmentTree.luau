--[[
	Persistent, server-owned build progression, laid out like an Elder Scrolls:
	Blades skill sheet. UI and server share one node graph.

	  Augment Level  1 + XP / 150; every level also earns an Augment Point
	  Tiers          Novice opens at level 1, Apprentice at 3, Adept at 6 and
	                 Master at 10
	  Ranks          most nodes have ranks I-III (Elemental Mastery and
	                 Arcane Resonance have one); rank I learns it (its tier's
	                 cost), rank II costs its tier in points, rank III one more
	  Rank effects   maneuvers hit harder, cost less, recover faster and last
	                 longer; perks and amplifiers add their bonus again

	Branches: Rig Maneuvers (physical abilities), Surge Amplifiers (boost the
	gem surges equipped in the Surge Array) and Passive Augments. Gem Surges
	themselves are not learned here: they come from gems (GemRoller).
	Learning every node at rank I costs Tree.UnlockPoints; the rest of the
	budget (up to Tree.MaxPoints) goes into ranks.
]]
local Tech = require(script.Parent.CombatTechnology)
local Tree = {}
Tree.StartingPoints, Tree.XPPerPoint = 3, 150
Tree.MaxRank = 3
-- Tiers, Elder Scrolls style: the level each opens at.
Tree.TierNames = { "Novice", "Apprentice", "Adept", "Master" }
Tree.TierLevels = { 1, 3, 6, 10 }
Tree.TierCosts = { 1, 1, 2, 3 } -- points to learn a node of each tier
-- Per rank above I.
Tree.RankScaling = { Damage = 0.10, Cost = -0.08, Recovery = -0.05, Duration = 0.15, Heal = 0.25 }
Tree.Branches = { "RigManeuvers", "SurgeAmplifiers", "PassiveAugments" }
Tree.BranchNames =
	{ RigManeuvers = "Rig Maneuvers", SurgeAmplifiers = "Surge Amplifiers", PassiveAugments = "Passive Augments" }

-- Columns per branch.
-- Passive Augments has none: each tier's perks sit centred in a row.
Tree.Columns = {
	RigManeuvers = { { Name = "Strikes" }, { Name = "Tactics" }, { Name = "Counters" } },
	SurgeAmplifiers = { { Name = "Power" }, { Name = "Flow" } },
}

-- { id, tier, column, parent? }. Listed tier by tier, so parents come first.
local layout = {
	RigManeuvers = {
		{ "HydraulicSlam", 1, 1 },
		{ "ServoFlurry", 1, 2, "HydraulicSlam" },
		{ "KineticRam", 2, 1, "HydraulicSlam" },
		{ "StimDodge", 2, 2, "ServoFlurry" },
		{ "BreachHammer", 3, 1, "KineticRam" },
		{ "ArmorPiercer", 3, 2, "StimDodge" },
		{ "SeismicBreaker", 4, 1, "BreachHammer" },
		{ "TremorSlam", 4, 2, "ArmorPiercer" },
		{ "PneumaticJab", 2, 3, "ServoFlurry" },
		{ "ThrusterLeap", 3, 3, "PneumaticJab" },
		{ "RiposteStance", 4, 3, "ThrusterLeap" },
	},
	-- Gem Surges come from the gems in the Surge Array (Q, E, R); this branch
	-- only strengthens whatever surges are equipped.
	SurgeAmplifiers = {
		{ "SurgePower", 1, 1 },
		{ "SurgeEfficiency", 1, 2 },
		{ "SurgeDuration", 2, 2, "SurgeEfficiency" },
		{ "ElementalMastery", 3, 1, "SurgePower" },
		{ "ArcaneResonance", 4, 1, "ElementalMastery" },
	},
	PassiveAugments = {
		{ "BladeCalibration", 1, 1 },
		{ "CleaverCalibration", 1, 2 },
		{ "MobilityAugment", 1, 3 },
		{ "ChargeRecycler", 2, 1, "CleaverCalibration" },
		{ "StaminaRecycler", 2, 2, "MobilityAugment" },
		{ "ThermalOvercharge", 3, 1, "ChargeRecycler" },
		{ "CorrosiveOvercharge", 3, 2, "ChargeRecycler" },
		{ "IonOvercharge", 3, 3, "ChargeRecycler" },
		{ "CryoOvercharge", 3, 4, "ChargeRecycler" },
		{ "ElementalHarmony", 4, 1 },
	},
}
-- Free starters: learned from the start at rank I.
local FREE = { HydraulicSlam = true }
-- Single-rank nodes (everything else ranks I-III).
local SINGLE_RANK = { ElementalMastery = true, ArcaneResonance = true }
-- Elemental Harmony asks for any two Overcharges instead of one parent.
local REQUIRES = {
	ElementalHarmony = {
		Any = { "ThermalOvercharge", "CorrosiveOvercharge", "IonOvercharge", "CryoOvercharge" },
		Count = 2,
	},
}

local passiveDefinitions = {
	SurgePower = {
		Name = "Surge Power",
		Description = "+10% / +20% / +30% damage for every equipped surge.",
		Effect = "SurgePower",
		Amount = 0.10,
		Icon = "💠",
	},
	SurgeEfficiency = {
		Name = "Surge Efficiency",
		Description = "-10% / -20% / -30% surge cooldown.",
		Effect = "SurgeEfficiency",
		Amount = 0.10,
		Icon = "⏱",
	},
	SurgeDuration = {
		Name = "Surge Duration",
		Description = "+10% / +20% / +30% surge duration: burns, slows, freezes, shred and clouds.",
		Effect = "SurgeDuration",
		Amount = 0.10,
		Icon = "⏳",
	},
	ElementalMastery = {
		Name = "Elemental Mastery",
		Description = "All surges deal +15% damage.",
		Effect = "ElementalMastery",
		Amount = 0.15,
		Icon = "🌐",
	},
	ArcaneResonance = {
		Name = "Arcane Resonance",
		Description = "20% chance that a surge triggers a second time for free.",
		Effect = "ArcaneResonance",
		Amount = 0.20,
		Icon = "✨",
	},
	BladeCalibration = {
		Name = "Blade Calibration",
		Description = "+5% damage with swords, blades and knives per rank.",
		Effect = "Slashing",
		Amount = 0.05,
		Icon = "⚔",
	},
	CleaverCalibration = {
		Name = "Cleaver Calibration",
		Description = "+5% damage with axes and cleavers per rank.",
		Effect = "Cleaving",
		Amount = 0.05,
		Icon = "⚒",
	},
	MobilityAugment = {
		Name = "Mobility Augment",
		Description = "+5% movement speed per rank.",
		Effect = "Mobility",
		Amount = 0.05,
		Icon = "🥾",
	},
	ChargeRecycler = {
		Name = "Charge Recycler",
		Description = "+15% Charge regeneration per rank while a gem is socketed.",
		Effect = "ChargeRegen",
		Amount = 0.15,
		Icon = "🔋",
	},
	StaminaRecycler = {
		Name = "Stamina Recycler",
		Description = "+15% Stamina regeneration per rank.",
		Effect = "StaminaRegen",
		Amount = 0.15,
		Icon = "✊",
	},
	ThermalOvercharge = {
		Name = "Thermal Overcharge",
		Description = "+10% / +20% / +30% Thermal weapon, surge and burn damage.",
		Effect = "Thermal",
		Amount = 0.10,
		Icon = "🔥",
		Element = "Fire",
	},
	CorrosiveOvercharge = {
		Name = "Corrosive Overcharge",
		Description = "+10% / +20% / +30% Corrosive surge damage.",
		Effect = "Corrosive",
		Amount = 0.10,
		Icon = "☣",
		Element = "Poison",
	},
	IonOvercharge = {
		Name = "Ion Overcharge",
		Description = "+10% / +20% / +30% Ion surge damage.",
		Effect = "Ion",
		Amount = 0.10,
		Icon = "⚡",
		Element = "Shock",
	},
	CryoOvercharge = {
		Name = "Cryo Overcharge",
		Description = "+10% / +20% / +30% Cryo surge damage.",
		Effect = "Cryo",
		Amount = 0.10,
		Icon = "❄",
		Element = "Frost",
	},
	ElementalHarmony = {
		Name = "Elemental Harmony",
		Description = "Deal damage of one element and your other elements hit +10% / +20% / +30% harder for 5 seconds.",
		Effect = "Harmony",
		Amount = 0.10,
		Icon = "✦",
	},
}

Tree.Order, Tree.Nodes = {}, {}
Tree.UnlockPoints = 0
for _, branch in Tree.Branches do
	Tree.Order[branch] = {}
	for _, entry in layout[branch] do
		local id, tier, column, parent = entry[1], entry[2], entry[3], entry[4]
		local d = passiveDefinitions[id] or Tech.Catalog[id]
		local node = {
			Id = id,
			Name = d.Name,
			Description = d.Description,
			Icon = d.Icon,
			Element = d.Element,
			Effect = d.Effect,
			Amount = d.Amount,
			Branch = branch,
			Tier = tier,
			Column = column,
			Parent = parent,
			Requires = REQUIRES[id],
			Free = FREE[id] == true,
			MaxRank = if SINGLE_RANK[id] then 1 else Tree.MaxRank,
			Cost = if FREE[id] then 0 else Tree.TierCosts[tier],
		}
		Tree.Nodes[id] = node
		table.insert(Tree.Order[branch], id)
		Tree.UnlockPoints += node.Cost
	end
end
-- Learning every node at rank I costs UnlockPoints; the rest of the budget
-- goes into ranks II and III, so a full build is a choice of what to master.
Tree.MaxPoints = Tree.UnlockPoints + 47

-- Is a node's prerequisite (one parent, or "any N of" a set) met?
function Tree.prerequisiteMet(unlocked, id: string): boolean
	local n = Tree.Nodes[id]
	if not n then
		return false
	end
	if n.Parent and not unlocked[n.Parent] then
		return false
	end
	if n.Requires then
		local have = 0
		for _, other in n.Requires.Any do
			if unlocked[other] then
				have += 1
			end
		end
		return have >= n.Requires.Count
	end
	return true
end
function Tree.prerequisiteText(id: string): string?
	local n = Tree.Nodes[id]
	if not n then
		return nil
	end
	if n.Parent then
		return "Learn " .. Tree.Nodes[n.Parent].Name
	end
	if n.Requires then
		return string.format("Learn any %d Overcharges", n.Requires.Count)
	end
	return nil
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
	local unlocked = { HydraulicSlam = true }
	local ranks = { HydraulicSlam = 1 }
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
					and Tree.prerequisiteMet(unlocked, id)
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
				for rank = 2, math.clamp(math.floor(wanted), 1, Tree.Nodes[id].MaxRank) do
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
	if not Tree.prerequisiteMet(data.Unlocked, id) then
		return false, (Tree.prerequisiteText(id) or "Learn its prerequisite") .. " first."
	end
	if data.Level < Tree.tierLevel(id) then
		return false, string.format("%s tier opens at Augment Level %d.", Tree.TierNames[n.Tier], Tree.tierLevel(id))
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
	if rank >= n.MaxRank then
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
	-- Perks and Surge Amplifiers both add their bonus per rank.
	for _, branch in { "PassiveAugments", "SurgeAmplifiers" } do
		for _, id in Tree.Order[branch] do
			local rank = Tree.rank(profile, id)
			if rank > 0 then
				local n = Tree.Nodes[id]
				effects[n.Effect] = n.Amount * rank
			end
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
		if stats.Cooldown then
			stats.Cooldown *= 1 + s.Recovery * steps
		end
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
