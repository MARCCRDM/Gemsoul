-- The skill tree (Shared.SkillTree): its four trees, the rules for
-- learning and equipping, the move each key fires (CombatTechnology.surgeGem)
-- with the gem powering it (+affinity), and the server's requests
-- (Server.SkillTreeServer). Run by tests/run_skill_tree.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local env = setmetatable({
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		script = { Parent = setmetatable({}, { __index = function(_, key)
			return key
		end }) },
		require = function(module)
			return load(module)
		end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { environment = env, debugName = name })()
	return cache[name]
end
local SkillTree = load("SkillTree")
local GemTraits = load("GemTraits")
local Tech = load("CombatTechnology")
local KEYS = { "Q", "E", "R" }

-- The trees: four elements, a branch per key, four tiers, every move real,
-- in its own element and lane, and every one of the element's moves on it once.
local seen = {}
for _, element in SkillTree.Elements do
	local tree = SkillTree.Trees[element]
	check(tree ~= nil, element .. " has no tree")
	for _, key in KEYS do
		local lane = SkillTree.Lanes[key]
		local tiers = tree[lane]
		check(#tiers == 4, element .. " " .. lane .. " isn't four tiers")
		check(#tiers[1] == 1 and #tiers[4] == 1, element .. " " .. lane .. " should start on one move and end on one capstone")
		for tier, ids in tiers do
			check(#ids >= 1 and #ids <= 3, element .. " " .. lane .. " tier " .. tier .. " has " .. #ids .. " moves")
			for _, id in ids do
				check(GemTraits.Moves[id] ~= nil, id .. " isn't a real move")
				local place = GemTraits.Index[id]
				check(place and place.Element == element and place.Lane == lane, id .. " is in the wrong tree or branch")
				check(not seen[id], id .. " is on the tree twice")
				seen[id] = true
				local e, l, t = SkillTree.where(id)
				check(e == element and l == lane and t == tier, id .. "'s place is wrong")
			end
		end
	end
	for lane, ids in GemTraits.Matrix[element] do
		for _, id in ids do
			check(seen[id], id .. " (" .. element .. " " .. lane .. ") isn't on any tree")
		end
	end
end
-- The tier-1 moves (the starting surges).
local FIRST = {
	Fire = { Q = "Q_CinderCleave", E = "E_EmberLance", R = "R_HeatShield" },
	Frost = { Q = "Q_FrostNeedle", E = "E_CryoLance", R = "R_FrozenWall" },
	Shock = { Q = "Q_ArcNeedle", E = "E_IonSpark", R = "R_IonShield" },
	Poison = { Q = "Q_BreachCut", E = "E_AcidSpray", R = "R_RadShield" },
}
for element, want in FIRST do
	local first = SkillTree.first(element)
	for _, key in KEYS do
		check(first[key] == want[key], element .. " " .. key .. " starts on " .. tostring(first[key]))
	end
end
check(SkillTree.first("Water") == nil and SkillTree.start("Water") == nil, "A tree for an element that isn't one")

-- A new save: its element's tier 1 learned and on its keys, nothing spent.
local skills = SkillTree.start("Fire")
check(skills.Element == "Fire" and SkillTree.spent(skills) == 0, "Tier 1 of your own tree isn't free")
for _, key in KEYS do
	check(skills.Moves[key] == FIRST.Fire[key] and skills.Learned[FIRST.Fire[key]], key .. " isn't on its tier-1 move")
end
check(SkillTree.points(1) == 0 and SkillTree.points(3) == 2 and SkillTree.points(10) == 9, "Points aren't one a level after the first")

-- Learning: the tier's level, the tier above in the branch, the points.
local ok, why = SkillTree.canLearn(skills, "Q_FurnaceCrescent", 2)
check(not ok and why == "Opens at level 3.", "Tier 2 learned before level 3: " .. tostring(why))
ok = SkillTree.learn(skills, "Q_FurnaceCrescent", 3)
check(ok and skills.Learned.Q_FurnaceCrescent, "Couldn't learn a tier-2 move at level 3")
check(skills.Moves.Q == "Q_FurnaceCrescent", "A deeper move learned didn't go on its key")
check(SkillTree.spent(skills) == 1 and SkillTree.left(skills, 3) == 1, "Tier 2 should cost a point")
ok, why = SkillTree.canLearn(skills, "Q_MagmaFault", 6)
check(ok, "Tier 3 refused with tier 2 learned: " .. tostring(why))
ok, why = SkillTree.canLearn(skills, "E_SolarFlare", 6)
check(not ok and string.find(why or "", "above", 1, true), "Tier 3 learned with nothing above it in its branch")
ok, why = SkillTree.canLearn(skills, "Q_MeteorLeap", 10)
check(not ok, "A capstone learned with no tier 3 above it")
ok, why = SkillTree.canLearn(skills, "Q_CinderDrill", 3)
check(ok, "The other tier-2 move refused: " .. tostring(why))
SkillTree.learn(skills, "Q_CinderDrill", 3)
ok, why = SkillTree.canLearn(skills, "E_HeatHaze", 3)
check(not ok and string.find(why or "", "point", 1, true), "Learned with no points left")
check(not SkillTree.learn(skills, "Q_CinderDrill", 3), "Learned twice")
check(not SkillTree.learn(skills, "Nope", 30), "Learned something not on the tree")
-- Another tree's tier 1 costs a point.
check(SkillTree.cost(skills, "R_FrozenWall") == 1 and SkillTree.cost(skills, "R_HeatShield") == 0, "Another tree's tier 1 should cost a point")
ok = SkillTree.learn(skills, "R_FrozenWall", 5)
check(ok and skills.Moves.R == "R_HeatShield", "A tier-1 move of another tree took a key over a move as deep")
-- A whole branch: 1 + 2 + 3 points past tier 1, the capstone at level 10.
do
	local s = SkillTree.start("Frost")
	for _, id in { "E_CryoStream", "E_Hailstorm", "E_AbsoluteZero" } do
		check(SkillTree.learn(s, id, 10), "Couldn't learn " .. id .. " at level 10")
	end
	check(SkillTree.spent(s) == 6 and s.Moves.E == "E_AbsoluteZero", "The E branch to its capstone should cost 6 and put it on E")
end

-- Equipping: learned moves, on their own key only.
check(SkillTree.equip(skills, "Q", "Q_CinderDrill") and skills.Moves.Q == "Q_CinderDrill", "Couldn't swap Q to another learned move")
check(not SkillTree.equip(skills, "E", "Q_CinderDrill"), "A Q move went on E")
check(not SkillTree.equip(skills, "E", "E_Supernova"), "An unlearned move was equipped")
check(SkillTree.equip(skills, "R", "R_FrozenWall") and skills.Moves.R == "R_FrozenWall", "A learned move from another tree wouldn't go on its key")
-- Reset: back to the element's tier 1, nothing spent.
local reset = SkillTree.reset(skills)
check(reset.Element == "Fire" and SkillTree.spent(reset) == 0 and reset.Moves.Q == FIRST.Fire.Q and not reset.Learned.Q_CinderDrill, "Reset didn't go back to tier 1")

-- A saved record made safe.
check(SkillTree.clean(nil) == nil and SkillTree.clean({ Element = "Mud" }) == nil, "A bad record wasn't refused")
local cleaned = SkillTree.clean({ Element = "Poison", Learned = { Q_Dissolution = "yes", Fake = true }, Moves = { Q = "E_AcidSpray", E = "E_ToxicTide", R = 4 } })
check(cleaned.Learned.Q_BreachCut and not cleaned.Learned.Fake and not cleaned.Learned.Q_Dissolution, "Cleaning kept junk or lost tier 1")
check(cleaned.Moves.Q == "Q_BreachCut" and cleaned.Moves.E == "E_AcidSpray" and cleaned.Moves.R == "R_RadShield", "Cleaning kept a move on the wrong key or one not learned")

-- What a key fires: the tree's move, powered by that socket's gem; with no
-- tree saved, the gem's own; with no gem, nothing.
local function gem(element, tier)
	return { Id = element .. tier, Element = element, Tier = tier, Size = 1, Clarity = 1, Cut = 1 }
end
local loadout = { WeaponGem = gem("Fire", "Common"), ArmorGem = gem("Frost", "Rare"), ShieldGem = nil, Shield = "Buckler" }
local own = Tech.surgeGem(loadout, "Q")
check(own and own.Surge == GemTraits.traitFor(loadout.WeaponGem, "Q") and not own.Skill, "Without a tree, Q isn't the gem's own move")
loadout.Skills = SkillTree.start("Fire")
local q = Tech.surgeGem(loadout, "Q")
check(q and q.Surge == "Q_CinderCleave" and q.Skill and q.SourceId == "FireCommon", "Q doesn't fire the tree's move from the sword's gem")
check(Tech.surgeGem(loadout, "R") == nil, "R fired with no gem in the shield")
local e = Tech.surgeGem(loadout, "E")
check(e and e.Surge == "E_EmberLance" and e.Element == "Frost", "E doesn't fire the tree's move from the chest's gem")
-- Affinity: a gem of the move's own element adds 10% (never in ranked).
local matched = GemTraits.stats("E_EmberLance", GemTraits.project(gem("Fire", "Rare"), "E", "E_EmberLance"))
local off = GemTraits.stats("E_EmberLance", GemTraits.project(gem("Frost", "Rare"), "E", "E_EmberLance"))
check(matched.Affinity and not off.Affinity, "Affinity marked on the wrong gem")
check(math.abs(matched.Output / off.Output - (1 + SkillTree.Affinity)) < 1e-6, "Affinity isn't +10%")
check(math.abs(SkillTree.Affinity - GemTraits.Affinity) < 1e-9, "The tree and the gems disagree on affinity")
local ranked = GemTraits.stats("E_EmberLance", GemTraits.project(gem("Fire", "Rare"), "E", "E_EmberLance"), true)
check(not ranked.Affinity and ranked.Output == GemTraits.NormalizedOutput, "Affinity counted in ranked")
local legacy = GemTraits.stats(GemTraits.traitFor(gem("Fire", "Rare"), "E"), GemTraits.project(gem("Fire", "Rare"), "E"))
check(not legacy.Affinity, "A gem's own move (no tree) got the tree's affinity")
-- A move the tree doesn't have learned, or on the wrong key: the gem's own.
loadout.Skills = { Element = "Fire", Learned = {}, Moves = { Q = "Q_MeteorLeap" } }
check(Tech.surgeGem(loadout, "Q").Surge == GemTraits.traitFor(loadout.WeaponGem, "Q"), "An unlearned move fired")
loadout.Skills = { Element = "Fire", Learned = { E_EmberLance = true }, Moves = { Q = "E_EmberLance" } }
check(not Tech.surgeGem(loadout, "Q").Skill, "An E move fired on Q")

-- The server's requests (Server.SkillTreeServer), on a stand-in profile.
do
	local profile = { Character = { WeaponGem = gem("Fire", "Common") }, Augments = { XP = 0 } }
	local synced = 0
	local busy = false
	local AugmentTree = { level = function(xp) return 1 + math.floor(xp / 100) end }
	local stubs = {
		SkillTree = SkillTree,
		AugmentTree = AugmentTree,
		Combat = { canChangeBuild = function() return not busy end },
		PlayerData = { get = function() return profile end, augmentsChanged = function() synced += 1 end },
		Shop = { reply = function(okay, message, extra) local r = extra or {}; r.Ok, r.Message = okay, message; return r end, register = function() end },
	}
	local env = setmetatable({
		game = { GetService = function() return { Shared = setmetatable({}, { __index = function(_, k) return k end }) } end },
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(x) return stubs[x] or error("no stub " .. tostring(x)) end,
	}, { __index = _G })
	local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/SkillTreeServer.luau"), { environment = env, debugName = "SkillTreeServer" })()
	local player = {}
	check(not Server.handle(player, "Learn", "Q_FurnaceCrescent").Ok, "Learned with no element chosen")
	check(not Server.handle(player, "Choose", "Mud").Ok, "Chose an element that isn't one")
	local chose = Server.handle(player, "Choose", "Frost")
	check(chose.Ok and profile.Character.Skills.Element == "Frost" and synced == 1, "An old save couldn't choose its element")
	check(not Server.handle(player, "Choose", "Fire").Ok, "Chose an element twice")
	check(not Server.handle(player, "Learn", "Q_GlacierFan").Ok, "Learned tier 2 at level 1")
	profile.Augments.XP = 500 -- (level 6: 5 points)
	check(Server.handle(player, "Learn", "Q_GlacierFan").Ok and profile.Character.Skills.Learned.Q_GlacierFan, "Couldn't learn with the points and the level")
	check(Server.handle(player, "Equip", "Q", "Q_FrostNeedle").Ok and profile.Character.Skills.Moves.Q == "Q_FrostNeedle", "Couldn't equip a learned move")
	check(not Server.handle(player, "Equip", "E", "Q_FrostNeedle").Ok, "Equipped a Q move on E")
	busy = true
	check(not Server.handle(player, "Learn", "Q_PermafrostSpire").Ok, "Changed skills mid-fight")
	busy = false
	check(Server.handle(player, "Reset").Ok and not profile.Character.Skills.Learned.Q_GlacierFan, "Reset didn't take it back")
	check(not Server.handle(player, "Hax").Ok, "An unknown request went through")
end

print("PASS: " .. checks .. " skill tree checks (four trees, the starting moves, learning, equipping, reset, saved records, what each key fires, affinity, the server's requests)")
