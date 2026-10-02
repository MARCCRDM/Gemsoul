local count = 0
local function check(value, message) count += 1; assert(value, message) end
local function close(a, b) return math.abs(a - b) < 0.00001 end
local profile = { Season = { XP = 0 } }
local data = Tree.initialize(profile)
check(data.Points == 3 and data.Spent == 0, "Starting point budget")
check(Tree.isLearned(profile, "HydraulicSlam") and not Tree.isLearned(profile, "ThermalBurst"), "Starter nodes")
check(not Tree.isLearned(profile, "ServoFlurry"), "Non-starter unlocked automatically")
check(#Tree.available(profile, "RigManeuvers") == 1 and Tree.Nodes.ThermalBurst == nil, "HUD exposes locked techniques or surges still in the tree")
check(not Tree.learn(profile, "BreachHammer"), "Skipped prerequisite")
check(not Tree.learn(profile, {}) and not Tree.learn(profile, "spoofed"), "Invalid unlock IDs")
check(Tree.learn(profile, "ServoFlurry") and profile.Augments.Points == 2, "Point purchase")
check(not Tree.learn(profile, "ServoFlurry") and profile.Augments.Points == 2, "Duplicate purchase spent points")
-- Blades-style tiers: Tier II opens at Augment Level 3, Tier III at 6.
check(not Tree.learn(profile, "StimDodge") and profile.Augments.Points == 2, "Tier II opened before level 3")
check(not Tree.learn(profile, "ArmorPiercer"), "Insufficient point purchase")
check(Tree.addXP(profile, 149) == 0 and profile.Augments.Points == 2, "XP below point boundary")
check(Tree.addXP(profile, 1) == 1 and profile.Augments.Points == 3 and profile.Augments.Level == 2, "Point boundary award")
check(Tree.addXP(profile, 150) == 1 and profile.Augments.Level == 3, "Level 3 boundary")
check(Tree.learn(profile, "StimDodge") and profile.Augments.Points == 3, "Linked branch unlock")
check(not Tree.learn(profile, "ArmorPiercer") and profile.Augments.Points == 3, "Tier III opened before level 6")
check(Tree.addXP(profile, 450) == 3 and profile.Augments.Level == 6, "Level 6 boundary")
check(Tree.learn(profile, "ArmorPiercer") and profile.Augments.Points == 4, "Capstone purchase")
-- Ranks: II costs the tier, III one more; never past III; never on a locked node.
check(Tree.upgrade(profile, "ServoFlurry") and Tree.rank(profile, "ServoFlurry") == 2 and profile.Augments.Points == 3, "Rank II cost")
check(Tree.upgrade(profile, "ServoFlurry") and Tree.rank(profile, "ServoFlurry") == 3 and profile.Augments.Points == 1, "Rank III cost")
check(not Tree.upgrade(profile, "ServoFlurry") and profile.Augments.Points == 1, "Rank past the maximum")
check(not Tree.upgrade(profile, "BreachHammer") and not Tree.upgrade(profile, "spoofed"), "Upgraded a locked or unknown node")
check(not Tree.upgrade(profile, "ArmorPiercer"), "Rank II without the points")
local reloaded = { Augments = { XP = profile.Augments.XP, Unlocked = table.clone(profile.Augments.Unlocked), Ranks = table.clone(profile.Augments.Ranks), Points = 999 } }
data = Tree.initialize(reloaded)
check(data.Points == 1 and data.Unlocked.ArmorPiercer and data.Ranks.ServoFlurry == 3, "Reload or forged points invalid")
check(Tree.respec(reloaded) and reloaded.Augments.Points == 8 and reloaded.Augments.Spent == 0, "Point refund")
check(reloaded.Augments.XP == 750 and not reloaded.Augments.Unlocked.ArmorPiercer and Tree.rank(reloaded, "ServoFlurry") == 0, "Reset lost XP or retained paid node")
check(Tree.respec(reloaded) and reloaded.Augments.Points == 8, "Repeated reset minted points")
local forged = Tree.initialize({ Augments = { XP = 0, Unlocked = { ServoFlurry = true }, Ranks = { ServoFlurry = 99, HydraulicSlam = 3, BreachHammer = 3 } } })
check(forged.Points >= 0 and forged.Spent <= forged.Earned and forged.Ranks.ServoFlurry <= 3 and not forged.Ranks.BreachHammer, "Forged ranks minted power")
local corrupt = { Augments = { XP = 0/0, Points = 999999, Unlocked = { spoofed = true, ArmorPiercer = true, ServoFlurry = "true" } } }
data = Tree.initialize(corrupt)
check(data.XP == 0 and data.Points == 3 and not data.Unlocked.spoofed and not data.Unlocked.ArmorPiercer, "Corrupt save sanitization")
local complete = { Augments = { XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint, Unlocked = {} } }
Tree.initialize(complete)
local total, seen = 0, {}
for _, branch in Tree.Branches do
	check(#Tree.Order[branch] == ({ RigManeuvers = 8, SurgeAmplifiers = 5, PassiveAugments = 10 })[branch], "Branch node count")
	for _, id in Tree.Order[branch] do
		local n = Tree.Nodes[id]
		local columns = if Tree.Columns[branch] then #Tree.Columns[branch] else 4
		check(not seen[id] and n.Branch == branch and n.Tier >= 1 and n.Tier <= #Tree.TierLevels and n.Column >= 1 and n.Column <= columns, "Invalid node placement")
		check(not n.Parent or seen[n.Parent], "Cyclic or out-of-order dependency")
		for _, other in n.Requires and n.Requires.Any or {} do check(seen[other], "Out-of-order requirement") end
		check(n.MaxRank == (if id == "ElementalMastery" or id == "ArcaneResonance" then 1 else 3), "Rank cap")
		seen[id] = true
		total += n.Cost
		if not n.Free then check(Tree.learn(complete, id), "Complete tree cannot be purchased") end
	end
end
check(total == Tree.UnlockPoints and complete.Augments.Points == 0 and complete.Augments.Spent == Tree.UnlockPoints, "Whole-tree point budget")
local rankBudget = Tree.MaxPoints - Tree.UnlockPoints
check(Tree.addXP(complete, 100000) == rankBudget and complete.Augments.Points == rankBudget, "Rank budget beyond unlocks")
check(Tree.addXP(complete, 100000) == 0 and complete.Augments.Level == Tree.MaxLevel, "Point cap bypass")
check(Tree.addXP(complete, math.huge) == 0 and Tree.addXP(complete, -100) == 0, "Invalid XP accepted")
local effects = Tree.effects(complete)
check(effects.Mobility == 0.05 and effects.StaminaRegen == 0.15 and effects.ChargeRegen == 0.15 and effects.Thermal == 0.1, "Passive effects missing")
check(effects.Corrosive == 0.1 and effects.Ion == 0.1 and effects.Cryo == 0.1 and effects.Harmony == 0.1, "Overcharge or Harmony perks missing")
-- Elemental Harmony needs any two Overcharges, and the Master tier opens at level 10.
local harmony = { Augments = { XP = 100000, Unlocked = { ChargeRecycler = true, CleaverCalibration = true, ThermalOvercharge = true } } }
Tree.initialize(harmony)
check(not Tree.learn(harmony, "ElementalHarmony"), "Harmony with one Overcharge")
check(Tree.learn(harmony, "IonOvercharge") and Tree.learn(harmony, "ElementalHarmony"), "Harmony with two Overcharges")
local young = { Augments = { XP = (Tree.TierLevels[4] - 2) * Tree.XPPerPoint, Unlocked = { SurgePower = true, ElementalMastery = true } } }
Tree.initialize(young)
check(young.Augments.Level == Tree.TierLevels[4] - 1 and young.Augments.Unlocked.ElementalMastery and not Tree.learn(young, "ArcaneResonance"), "Master tier opened early")
check(not Tree.upgrade(young, "ElementalMastery"), "Single-rank node ranked up")
-- Surge Amplifiers feed every equipped surge.
local amps = Tree.effects(complete)
check(close(amps.SurgePower, 0.1) and close(amps.SurgeEfficiency, 0.1) and close(amps.SurgeDuration, 0.1) and close(amps.ElementalMastery, 0.15) and close(amps.ArcaneResonance, 0.2), "Surge Amplifier effects")
check(close(Tree.weaponMultiplier(effects, { Look = "FrontierSword", Attack = { Kind = "Melee" } }), 1.05), "Blade calibration")
check(close(Tree.weaponMultiplier(effects, { Look = "Cleaver", Attack = { Kind = "Melee" } }), 1.05), "Cleaver calibration")
check(Tree.weaponMultiplier(effects, { Look = "CleanSidearm", Attack = { Kind = "Shot" } }) == 1, "Sword augment boosted pistol")
check(Tree.weaponMultiplier(effects, { Look = "Hammer", Attack = { Kind = "Melee" } }) == 1, "Unclassified weapon boosted")
check(Tree.upgrade(complete, "MobilityAugment") and Tree.upgrade(complete, "MobilityAugment") and close(Tree.effects(complete).Mobility, 0.15), "Passive ranks stack their bonus")
check(Tree.upgrade(complete, "HydraulicSlam") and Tree.upgrade(complete, "HydraulicSlam"), "Starter node ranks")
local slam = Tree.techStats(complete, "HydraulicSlam")
check(close(slam.Damage, 1.8 * 1.2) and close(slam.Cost, 30 * 0.84) and close(Tech.Catalog.HydraulicSlam.Damage, 1.8), "Rank III technology scaling or catalog mutated")

-- Real unlock handlers and live combat: purchases are authoritative and build changes are safe.
local source, hs, rs, loadout = makePlayer(30, Vector3.zero, nil)
local victim, hv, rv, targetLoadout = makePlayer(31, arena + Vector3.new(0, 0, -5), nil)
local syncCount = 0
PlayerData.augmentsChanged = function() syncCount += 1 end
AugmentSystem.start()
local reply = registered.LearnAugment(source, "ServoFlurry")
check(reply.Ok and Tree.isLearned(profiles[source], "ServoFlurry") and syncCount == 1, "Learn handler did not persist or sync")
check(not registered.LearnAugment(source, "ServoFlurry").Ok and syncCount == 1, "Duplicate request persisted twice")
source:SetAttribute("CombatSession", "PvP")
check(not registered.LearnAugment(source, "KineticRam").Ok and not registered.ResetAugments(source).Ok, "Build changed during arena combat")
source:SetAttribute("CombatSession", nil)
source:SetAttribute("Expedition", true)
check(not registered.ResetAugments(source).Ok, "Build changed during expedition")
source:SetAttribute("Expedition", nil)
rs.Position = arena
check(not registered.ResetAugments(source).Ok, "World combat area allowed reset")
rs.Position = Vector3.zero
check(registered.ResetAugments(source).Ok and not Tree.isLearned(profiles[source], "ServoFlurry"), "Reset handler did not revoke action")
rs.Position = arena
local stamina = CombatServer._state(source).Resources.Stamina
check(not CombatServer._technology(source, "ServoFlurry", rv.Position) and CombatServer._state(source).Resources.Stamina == stamina and hv.Health == 1000, "Locked action remote bypass")

for _, other in playerList do other:SetAttribute("PvPEnabled", false) end
source:SetAttribute("PvPEnabled", true); victim:SetAttribute("PvPEnabled", true)
local progress = Tree.initialize(profiles[source])
progress.XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint
Tree.initialize(profiles[source])
for _, branch in Tree.Branches do
	for _, id in Tree.Order[branch] do
		if not Tree.Nodes[id].Free then Tree.learn(profiles[source], id) end
	end
end
CombatServer.reset(source); CombatServer.reset(victim)
now += 10
local damage = Classes.weapon("Warrior", loadout.Weapon).Attack.Damage * Combat.powerMult(Classes.ratings(loadout).Power.Base) * Combat.defenseMult(Classes.ratings(targetLoadout).Defense.Base)
check(CombatServer._attack(source, rv.Position, false) and close(1000 - hv.Health, damage * 1.05), "Live blade augment damage")
local st = CombatServer._state(source)
loadout.WeaponGem = { Element = "Fire", Size = 4, Clarity = 5, Cut = 5 }
st.Resources.Stamina, st.Resources.Charge, st.ResourceAt = 50, 50, now
now += 0.5; CombatServer._tick(0.5)
check(close(st.Resources.Stamina, 56.9) and close(st.Resources.Charge, 54.025), "Live recyclers did not change regeneration")
local expectedSpeed = Classes.walkSpeed(Classes.ratings(loadout).Speed.Base + Classes.ratings(loadout).Speed.Bonus) * 1.05
check(close(hs.WalkSpeed, expectedSpeed), "Live mobility augment did not change movement")
now += 2
hv.Health = 1000
loadout.SurgeGems = { Q = { Id = "amp", Element = "Fire", Tier = "Rare", SurgeTier = 1, SurgeRank = 1, Size = 4, Clarity = 5, Cut = 0 } }
check(CombatServer._technology(source, nil, rv.Position, "Q") and close(1000 - hv.Health, damage * 1.12 * 1.1 * 1.25), "Live Thermal surge with Overcharge, Surge Power and Elemental Mastery")
loadout.SurgeGems = nil
now += 2
hv.Health = 1000
CombatServer._state(victim).Dots = {}
check(CombatServer._attack(source, rv.Position, false), "Augmented Thermal weapon attack refused")
check(close(1000 - hv.Health, damage * 1.05 * 1.1), "Live Thermal weapon multiplier")
local metrics = GemConfig.actionValues(loadout.WeaponGem, "Basic", { Affinity = Classes.affinities(loadout), PvP = true })
check(close(CombatServer._state(victim).Dots[source].Damage, metrics.Burn * 1.1), "Live Thermal burn multiplier")
local trainee = makePlayer(40, Vector3.zero, nil)
profiles[trainee].Season, profiles[trainee].Boosts = { XP = 0 }, { XPUntil = 1000 }
Tree.initialize(profiles[trainee])
os.time = function() return 100 end
local synced = 0
PlayerData.sync = function() synced += 1 end
Remotes.Notify = { FireClient = function(_, player, message) table.insert(messages, { Player = player, Message = message }) end }
Progress.addXP(trainee, "Mine", 10)
check(profiles[trainee].Augments.XP == 150 and profiles[trainee].Augments.Points == 4 and profiles[trainee].Season.XP == 300, "Mining XP did not award point or XP boost affected tree budget")
check(synced == 1, "Progress award did not sync saved profile")
profiles[trainee].Boosts.XPUntil = 0
Progress.addXP(trainee, "Mine", 10)
check(profiles[trainee].Augments.XP == 300 and profiles[trainee].Augments.Points == 5 and synced == 2, "Second earned point duplicated or missing")
Progress.addXP(trainee, "Unknown")
check(profiles[trainee].Augments.XP == 300 and synced == 2, "Unknown XP reason awarded points")
print("PASS: " .. count .. " Augment Tree checks (18-node graph, migration, points, prerequisites, refunds, authority and live passive effects)")
