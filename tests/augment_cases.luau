local count = 0
local function check(value, message) count += 1; assert(value, message) end
local function close(a, b) return math.abs(a - b) < 0.00001 end
local profile = { Season = { XP = 0 } }
local data = Tree.initialize(profile)
check(data.Points == 3 and data.Spent == 0, "Starting point budget")
check(Tree.isLearned(profile, "HydraulicSlam") and Tree.isLearned(profile, "ThermalBurst"), "Starter nodes")
check(not Tree.isLearned(profile, "ServoFlurry"), "Non-starter unlocked automatically")
check(#Tree.available(profile, "RigManeuvers") == 1 and #Tree.available(profile, "GemSurges") == 1, "HUD exposes locked techniques")
check(not Tree.learn(profile, "BreachHammer"), "Skipped prerequisite")
check(not Tree.learn(profile, {}) and not Tree.learn(profile, "spoofed"), "Invalid unlock IDs")
check(Tree.learn(profile, "ServoFlurry") and profile.Augments.Points == 2, "Point purchase")
check(not Tree.learn(profile, "ServoFlurry") and profile.Augments.Points == 2, "Duplicate purchase spent points")
check(Tree.learn(profile, "StimDodge") and profile.Augments.Points == 1, "Linked branch unlock")
check(not Tree.learn(profile, "ArmorPiercer"), "Insufficient point purchase")
check(Tree.addXP(profile, 149) == 0 and profile.Augments.Points == 1, "XP below point boundary")
check(Tree.addXP(profile, 1) == 1 and profile.Augments.Points == 2, "Point boundary award")
check(Tree.learn(profile, "ArmorPiercer") and profile.Augments.Points == 0, "Capstone purchase")
local reloaded = { Augments = { XP = profile.Augments.XP, Unlocked = table.clone(profile.Augments.Unlocked), Points = 999 } }
data = Tree.initialize(reloaded)
check(data.Points == 0 and data.Unlocked.ArmorPiercer, "Reload or forged points invalid")
check(Tree.respec(reloaded) and reloaded.Augments.Points == 4 and reloaded.Augments.Spent == 0, "Point refund")
check(reloaded.Augments.XP == 150 and not reloaded.Augments.Unlocked.ArmorPiercer, "Reset lost XP or retained paid node")
check(Tree.respec(reloaded) and reloaded.Augments.Points == 4, "Repeated reset minted points")
local corrupt = { Augments = { XP = 0/0, Points = 999999, Unlocked = { spoofed = true, ArmorPiercer = true, ServoFlurry = "true" } } }
data = Tree.initialize(corrupt)
check(data.XP == 0 and data.Points == 3 and not data.Unlocked.spoofed and not data.Unlocked.ArmorPiercer, "Corrupt save sanitization")
local complete = { Augments = { XP = 3150, Unlocked = {} } }
Tree.initialize(complete)
local total, seen = 0, {}
for _, branch in Tree.Branches do
	check(#Tree.Order[branch] == 6, "Branch node count")
	for _, id in Tree.Order[branch] do
		local n = Tree.Nodes[id]
		check(not seen[id] and n.Branch == branch and n.Tier >= 1 and n.Tier <= 3 and (n.Column == 1 or n.Column == 2), "Invalid node placement")
		check(not n.Parent or seen[n.Parent], "Cyclic or out-of-order dependency")
		seen[id] = true
		total += n.Cost
		if not n.Free then check(Tree.learn(complete, id), "Complete tree cannot be purchased") end
	end
end
check(total == Tree.MaxPoints and complete.Augments.Points == 0 and complete.Augments.Spent == 24, "Whole-tree point budget")
check(Tree.addXP(complete, 100000) == 0 and complete.Augments.Points == 0, "Point cap bypass")
check(Tree.addXP(complete, math.huge) == 0 and Tree.addXP(complete, -100) == 0, "Invalid XP accepted")
local effects = Tree.effects(complete)
check(effects.Mobility == 0.05 and effects.StaminaRegen == 0.15 and effects.ChargeRegen == 0.15 and effects.Thermal == 0.1, "Passive effects missing")
check(close(Tree.weaponMultiplier(effects, { Look = "FrontierSword", Attack = { Kind = "Melee" } }), 1.05), "Blade calibration")
check(close(Tree.weaponMultiplier(effects, { Look = "Cleaver", Attack = { Kind = "Melee" } }), 1.05), "Cleaver calibration")
check(Tree.weaponMultiplier(effects, { Look = "CleanSidearm", Attack = { Kind = "Shot" } }) == 1, "Sword augment boosted pistol")
check(Tree.weaponMultiplier(effects, { Look = "Hammer", Attack = { Kind = "Melee" } }) == 1, "Unclassified weapon boosted")

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
progress.XP = 3150
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
check(CombatServer._technology(source, "ThermalBurst", rv.Position) and close(1000 - hv.Health, damage * 1.12 * 1.1), "Live Thermal augment surge damage")
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
