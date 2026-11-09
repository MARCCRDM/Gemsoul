--[[
	The skill tree: where your Q, E and R moves come from. Gems no longer
	carry the moves; they power them. The gem in the sword's socket powers
	your Q, the chest's your E, the shield's your R (Shared.GemTraits.Sockets):
	its rarity sets how strong the move is, Size, Clarity and Cut as before,
	and a gem of the move's own element adds Affinity on top
	(GemTraits.stats). A key with no gem in its socket fires nothing.

	Four trees, one per element, each with a branch per key:

	  Q  Offense   the sword's special move
	  E  Ability   your elemental surge
	  R  Defense   survive pressure

	and four tiers down each branch (Trees: { tier 1, tier 2, tier 3,
	capstone }, each a list of move ids from Shared.GemTraits):

	  tier 1     one move, given free with the tree's element at the start
	  tier 2-3   a few to choose from: learn one (or more) to go deeper
	  capstone   the branch's last move

	A move is learned with skill points: one per level after the first
	(Shared.AugmentTree's level), Costs by tier, and its tier opens at
	Levels. A tier needs a move of the tier above it learned in the same
	branch. Branches of other trees can be learned too (a Fire Q with a
	Frost R): their first tier costs Costs[1] then. Equip any learned move
	on its own key (a Q move on Q only); swap freely out of a fight.

	Saved on the loadout (profile.Character.Skills, so every fight and
	screen that reads the loadout reads it):

	  { Element, Learned = { [id] = true }, Moves = { Q, E, R } }

	A loadout without it (a save from before, a bot, a kaiju) keeps the
	gems' own moves (GemTraits.traitsOf).

	  SkillTree.Enabled
	  SkillTree.Elements                         in the picker's order
	  SkillTree.Trees[element][lane]             { {T1}, {T2...}, {T3...}, {Cap} }
	  SkillTree.first(element) -> { Q, E, R }    the tree's tier-1 moves
	  SkillTree.start(element) -> skills         a new save's Skills
	  SkillTree.where(id) -> element, lane, tier the move's place
	  SkillTree.points(level) -> number          points earned by `level`
	  SkillTree.spent(skills) -> number          points spent
	  SkillTree.canLearn(skills, id, level) -> ok, why?
	  SkillTree.learn(skills, id, level) -> ok, why?
	  SkillTree.equip(skills, key, id) -> ok, why?
	  SkillTree.reset(skills) -> skills          back to its element's tier 1
	  SkillTree.move(loadout, key) -> id?        the move a key fires
	  SkillTree.clean(skills) -> skills?         a saved record made safe

	Pure data and rules, for the server, the client and tests.
]]
local SkillTree = {}

SkillTree.Enabled = true
SkillTree.Elements = { "Fire", "Frost", "Shock", "Poison" }
SkillTree.Keys = { "Q", "E", "R" }
SkillTree.Lanes = { Q = "Offense", E = "Ability", R = "Defense" }
SkillTree.KeyOfLane = { Offense = "Q", Ability = "E", Defense = "R" }
SkillTree.TierNames = { "Tier 1", "Tier 2", "Tier 3", "Capstone" }
SkillTree.Levels = { 1, 3, 6, 10 } -- the level each tier opens at
SkillTree.Costs = { 1, 1, 2, 3 } -- points to learn a move of each tier (tier 1 of your own tree is free)
SkillTree.Affinity = 0.10 -- a gem of the move's own element: +10% output

-- Each element's branches, tier by tier (Shared.GemTraits' moves).
SkillTree.Trees = {
	Fire = {
		Offense = { { "Q_CinderCleave" }, { "Q_FurnaceCrescent", "Q_CinderDrill" }, { "Q_MagmaFault", "Q_SolarExecution" }, { "Q_MeteorLeap" } },
		Ability = { { "E_EmberLance" }, { "E_HeatHaze", "E_ThermalBurst" }, { "E_SolarFlare", "E_FlameTornado" }, { "E_Supernova" } },
		Defense = { { "R_HeatShield" }, { "R_EmberGuard", "R_Cauterize" }, { "R_FireWall", "R_RingOfFire" }, { "R_PhoenixMantle" } },
	},
	Frost = {
		Offense = { { "Q_FrostNeedle" }, { "Q_GlacierFan", "Q_CryoEdge" }, { "Q_PermafrostSpire", "Q_FrostChakram" }, { "Q_ShatterCrown" } },
		Ability = { { "E_CryoLance" }, { "E_CryoStream", "E_GlacierRetreat" }, { "E_WintersHold", "E_Hailstorm" }, { "E_AbsoluteZero" } },
		Defense = { { "R_FrozenWall" }, { "R_IceArmor", "R_ColdResolve" }, { "R_GlacialBulwark", "R_FrostRiposte", "R_IcePillar" }, { "R_GlacierDome" } },
	},
	Shock = {
		Offense = { { "Q_ArcNeedle" }, { "Q_CircuitCleave", "Q_StaticBrand" }, { "Q_Railstorm", "Q_OverchargeStrike", "Q_ThunderDash" }, { "Q_Skybreaker" } },
		Ability = { { "E_IonSpark" }, { "E_VectorDash", "E_ChainLightning" }, { "E_ThunderPylon", "E_Overload", "E_StormCall" }, { "E_IonCannon" } },
		Defense = { { "R_IonShield" }, { "R_StaticCatch", "R_Capacitor" }, { "R_DeflectorField", "R_Grounding", "R_TeslaFence" }, { "R_HoloDecoy" } },
	},
	Poison = {
		Offense = { { "Q_BreachCut" }, { "Q_CausticDart", "Q_SappingEdge" }, { "Q_VitriolSweep", "Q_ViperLash", "Q_ToxicFlask" }, { "Q_Dissolution" } },
		Ability = { { "E_AcidSpray" }, { "E_SeepStep", "E_LeechBloom" }, { "E_ToxicCloud", "E_ArmorMelt", "E_ToxicTide" }, { "E_Maneater" } },
		Defense = { { "R_RadShield" }, { "R_PurgeShell", "R_BioRegrowth" }, { "R_CorrosionAura", "R_SporeWall", "R_AcidSlick" }, { "R_ToxicMantle" } },
	},
}

-- Where every move sits: [id] = { Element, Lane, Tier }.
local PLACE: { [string]: { Element: string, Lane: string, Tier: number } } = {}
for element, lanes in SkillTree.Trees do
	for lane, tiers in lanes do
		for tier, ids in tiers do
			for _, id in ids do
				PLACE[id] = { Element = element, Lane = lane, Tier = tier }
			end
		end
	end
end
SkillTree.Place = PLACE

function SkillTree.where(id: string): (string?, string?, number?)
	local p = PLACE[id]
	if not p then
		return nil, nil, nil
	end
	return p.Element, p.Lane, p.Tier
end

function SkillTree.first(element: string): { [string]: string }?
	local tree = SkillTree.Trees[element]
	if not tree then
		return nil
	end
	return { Q = tree.Offense[1][1], E = tree.Ability[1][1], R = tree.Defense[1][1] }
end

function SkillTree.start(element: string)
	local first = SkillTree.first(element)
	if not first then
		return nil
	end
	local learned = {}
	for _, id in first do
		learned[id] = true
	end
	return { Element = element, Learned = learned, Moves = table.clone(first) }
end

function SkillTree.points(level: number): number
	return math.max(0, math.floor(level or 1) - 1)
end

-- What learning `id` costs: its tier's cost, but a tier 1 of your own
-- element's tree is free (given at the start).
function SkillTree.cost(skills, id: string): number
	local p = PLACE[id]
	if not p then
		return 0
	end
	if p.Tier == 1 and skills and p.Element == skills.Element then
		return 0
	end
	return SkillTree.Costs[p.Tier] or 0
end

function SkillTree.spent(skills): number
	local total = 0
	for id in (skills and skills.Learned) or {} do
		total += SkillTree.cost(skills, id)
	end
	return total
end

function SkillTree.left(skills, level: number): number
	return SkillTree.points(level) - SkillTree.spent(skills)
end

-- Is a move of the tier above learned in the same branch?
local function above(skills, p): boolean
	if p.Tier <= 1 then
		return true
	end
	for _, id in SkillTree.Trees[p.Element][p.Lane][p.Tier - 1] do
		if skills.Learned[id] then
			return true
		end
	end
	return false
end

function SkillTree.canLearn(skills, id: string, level: number): (boolean, string?)
	local p = PLACE[id]
	if not skills or type(skills.Learned) ~= "table" then
		return false, "Choose your element first."
	end
	if not p then
		return false, "That isn't on the tree."
	end
	if skills.Learned[id] then
		return false, "Already learned."
	end
	local opens = SkillTree.Levels[p.Tier] or 1
	if (level or 1) < opens then
		return false, string.format("Opens at level %d.", opens)
	end
	if not above(skills, p) then
		return false, string.format("Learn a %s move above it first.", string.lower(SkillTree.TierNames[p.Tier - 1]))
	end
	local cost = SkillTree.cost(skills, id)
	if SkillTree.left(skills, level) < cost then
		return false, string.format("Needs %d skill point%s.", cost, if cost == 1 then "" else "s")
	end
	return true, nil
end

function SkillTree.learn(skills, id: string, level: number): (boolean, string?)
	local ok, why = SkillTree.canLearn(skills, id, level)
	if not ok then
		return false, why
	end
	skills.Learned[id] = true
	-- (a key with nothing better on it takes it at once: its first deeper move)
	local key = SkillTree.KeyOfLane[PLACE[id].Lane]
	local current = skills.Moves[key]
	local currentPlace = current and PLACE[current]
	if not currentPlace or currentPlace.Tier < PLACE[id].Tier then
		skills.Moves[key] = id
	end
	return true, nil
end

function SkillTree.equip(skills, key: string, id: string): (boolean, string?)
	if not skills or type(skills.Learned) ~= "table" then
		return false, "Choose your element first."
	end
	local p = PLACE[id]
	if not p or SkillTree.KeyOfLane[p.Lane] ~= key then
		return false, "That move doesn't go on " .. tostring(key) .. "."
	end
	if not skills.Learned[id] then
		return false, "Learn it first."
	end
	skills.Moves[key] = id
	return true, nil
end

function SkillTree.reset(skills)
	local element = skills and skills.Element
	return SkillTree.start(element) or skills
end

-- The move a key fires, from the loadout's Skills (nil: none saved, the
-- gem's own then).
function SkillTree.move(loadout, key: string): string?
	if not SkillTree.Enabled or type(loadout) ~= "table" then
		return nil
	end
	local skills = loadout.Skills
	if type(skills) ~= "table" or type(skills.Moves) ~= "table" or type(skills.Learned) ~= "table" then
		return nil
	end
	local id = skills.Moves[key]
	local p = type(id) == "string" and PLACE[id]
	if p and SkillTree.KeyOfLane[p.Lane] == key and skills.Learned[id] then
		return id
	end
	return nil
end

-- A saved record made safe: known element, only moves on the tree, each
-- key's move learned and on its own key, the element's tier 1 learned.
function SkillTree.clean(skills)
	if type(skills) ~= "table" or not SkillTree.Trees[skills.Element or ""] then
		return nil
	end
	local learned = {}
	for id, on in (if type(skills.Learned) == "table" then skills.Learned else {}) do
		if on == true and PLACE[id] then
			learned[id] = true
		end
	end
	local first = SkillTree.first(skills.Element) :: { [string]: string }
	for _, id in first do
		learned[id] = true
	end
	local moves = {}
	for _, key in SkillTree.Keys do
		local id = type(skills.Moves) == "table" and skills.Moves[key]
		local p = type(id) == "string" and PLACE[id]
		moves[key] = if p and SkillTree.KeyOfLane[p.Lane] == key and learned[id] then id else first[key]
	end
	return { Element = skills.Element, Learned = learned, Moves = moves }
end

return SkillTree
