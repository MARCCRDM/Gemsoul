local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function close(a, b) return math.abs(a - b) < 0.00001 end
local source, hs, rs, loadout = makePlayer(20, arena, nil)
local victim, hv, rv, defense = makePlayer(21, arena + Vector3.new(0, 0, -5), nil)
local progress = Tree.initialize(profiles[source])
progress.XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint
for _, group in { "RigManeuvers", "GemSurges" } do
 for _, id in Tree.Order[group] do progress.Unlocked[id] = true end
end
Tree.initialize(profiles[source])
loadout.Shield = "ArmorProspectorShield1"
local expected = Classes.weapon("Warrior", loadout.Weapon).Attack.Damage * Combat.powerMult(Classes.ratings(loadout).Power.Base) * Combat.defenseMult(Classes.ratings(defense).Defense.Base)
local function reset()
	now += 20
	CombatServer.reset(source); CombatServer.reset(victim)
	hs.Health, hv.Health = 1000, 1000
	loadout.WeaponGem, loadout.ArmorGem = nil, nil
	wallBlocks = false
	return CombatServer._state(source)
end
local function fire(id) return CombatServer._technology(source, id, rv.Position) end
for _, group in { "RigManeuvers", "GemSurges" } do
	check(#Tech.Order[group] == #Tree.Order[group], "Kit catalog parity")
	for _, id in Tech.Order[group] do check(Tech.Catalog[id] ~= nil, "Missing kit entry") end
end
local st = reset()
st.Resources.Stamina = 29
check(not fire("HydraulicSlam") and st.Resources.Stamina == 29, "Insufficient Stamina consumed")
st.Resources.Stamina = 100
check(fire("HydraulicSlam") and st.Resources.Stamina == 70, "Hydraulic Slam cost")
check(close(1000 - hv.Health, expected * 1.8), "Hydraulic Slam damage")
check(not fire("ServoFlurry"), "Technique recovery bypass")
st = reset()
check(fire("ServoFlurry") and #st.Pending == 1 and st.Resources.Stamina == 80, "Servo Flurry first strike/cost")
check(close(1000 - hv.Health, expected * 0.7), "Servo Flurry first hit")
now += 0.2; CombatServer._tick(0.2)
check(close(1000 - hv.Health, expected * 1.4) and #st.Pending == 0, "Servo Flurry second hit")
st = reset()
check(fire("BreachHammer") and hv.Health == 1000 and st.Resources.Stamina == 60, "Breach Hammer wind-up")
CombatServer._input(source, "CancelTech")
now += 1.1; CombatServer._tick(1.1)
check(hv.Health == 1000, "Cancelled wind-up hit")
st = reset()
check(fire("BreachHammer"), "Breach Hammer refused")
now += 1.1; CombatServer._tick(1.1)
check(close(1000 - hv.Health, expected * 2.5), "Breach Hammer damage")
st = reset()
loadout.Shield = nil
check(not fire("KineticRam"), "Kinetic Ram without shield")
loadout.Shield = "ArmorProspectorShield1"
check(fire("KineticRam") and st.Resources.Stamina == 75, "Kinetic Ram cost")
check(close(1000 - hv.Health, expected * 1.2) and CombatServer._state(victim).StunUntil > now, "Kinetic Ram damage/stagger")
st = reset()
CombatServer._block(victim, true, rs.Position)
check(fire("ArmorPiercer") and close(1000 - hv.Health, expected), "Armor Piercer blocked")
check(victim:GetAttribute("Blocking"), "Armor Piercer destroyed guard instead of bypassing")
st = reset()
hs.Health = 500
check(fire("StimDodge") and st.Resources.Stamina == 85 and hs.Health == 600 and st.DodgeMove ~= nil, "Stim Dodge heal/movement/cost")
st = reset()
st.Resources.Stamina = 14
check(not CombatServer._dodge(source, Vector3.new(0, 0, -1)), "Free ordinary dodge")
st = reset()
check(not fire("ThermalBurst") and st.Resources.Charge == 100, "Surge without gem consumed Charge")
loadout.WeaponGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
check(not fire("ThermalBurst"), "Wrong element powered surge")
loadout.WeaponGem.Element = "Fire"
check(fire("ThermalBurst") and st.Resources.Charge == 75 and hv.Health < 1000, "Thermal Burst cost/damage")
check(CombatServer._state(victim).Dots[source] ~= nil, "Thermal Burst burn missing")
st = reset()
loadout.ArmorGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
check(fire("CryoLance") and st.Resources.Charge == 75 and hv.Health < 1000, "Armor socket did not power Cryo Lance")
check(CombatServer._state(victim).StunUntil > now, "Cryo Lance stun missing")
st = reset()
loadout.WeaponGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
check(fire("CryoShield") and st.Resources.Charge == 70 and st.Shield == 42, "Cryo Shield cost/barrier")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
check(fire("EnergySiphon") and st.Resources.Charge == 80, "Energy Siphon cost")
local before = hs.Health
CombatServer.hurt(source, 20, "Fire", { Root = { Position = rv.Position } })
check(hs.Health == before and st.Resources.Charge > 80 and st.SiphonCapacity < 40, "Siphon absorption/conversion")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
check(fire("ResonanceEcho") and st.Resources.Charge == 60, "Resonance Echo cost")
loadout.WeaponGem = nil -- isolate duplicate weapon damage from elemental procs
now += 1.1
check(CombatServer._attack(source, rv.Position, false) and close(1000 - hv.Health, expected * 2 * Actions.resolve(Classes.setState(loadout).Counts, "Sword", 0).BasicDamage), "Resonance Echo duplicate damage")
st = reset()
loadout.WeaponGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
check(fire("CryoStream") and close(st.Resources.Charge, 96.25) and st.Channel ~= nil, "Stream opening quarter-second cost")
local health = hv.Health
now += 0.25
check(fire("CryoStream"), "Stream refresh refused")
CombatServer._tick(0.25)
check(hv.Health < health and close(st.Resources.Charge, 94.25), "Stream pulse billing or damage")
check(not CombatServer._attack(source, rv.Position, false), "Attacked during channel")
CombatServer._input(source, "CancelTech")
health = hv.Health
now += 0.3; CombatServer._tick(0.3)
check(st.Channel == nil and hv.Health == health, "Released stream continued")
st = reset()
loadout.WeaponGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
fire("CryoStream")
now += 0.6; CombatServer._tick(0.6)
check(st.Channel == nil, "Lost stream release packet stuck channel")
st = reset()
loadout.WeaponGem = { Element = "Fire", Size = 4, Clarity = 5, Cut = 5 }
st.Resources.Stamina, st.Resources.Charge = 50, 50
now += 0.5; CombatServer._tick(0.5)
check(close(st.Resources.Stamina, 56) and close(st.Resources.Charge, 53.5), "Resource regeneration")
loadout.WeaponGem = nil
now += 0.1; CombatServer._tick(0.1)
check(st.Resources.Charge == 0, "Unsocketed rig retained Charge")
st = reset()
loadout.WeaponGem = { Element = "Fire", Size = 4, Clarity = 5, Cut = 5 }
victim:SetAttribute("PvPEnabled", false)
check(fire("ThermalBurst") and hv.Health == 1000, "Surge hit training visitor")
victim:SetAttribute("PvPEnabled", true)
st = reset()
loadout.WeaponGem = { Element = "Frost", Size = 4, Clarity = 5, Cut = 5 }
wallBlocks = true
check(fire("CryoLance") and hv.Health == 1000, "Surge ignored wall")
-- New elemental surges: each needs its own gem, and does its own job.
st = reset()
check(not fire("AcidSpray"), "Corrosive surge without a Corrosive gem")
loadout.WeaponGem = { Element = "Poison", Size = 4, Clarity = 5, Cut = 5 }
check(fire("AcidSpray") and st.Resources.Charge == 80 and hv.Health < 1000, "Acid Spray cost/cone damage")
check(CombatServer._state(victim).Sunder > 0 and CombatServer._state(victim).SunderUntil > now, "Acid Spray shred missing")
st = reset()
loadout.WeaponGem = { Element = "Poison", Size = 4, Clarity = 5, Cut = 5 }
check(fire("ToxicCloud") and #st.Zones == 1, "Toxic Cloud pool missing")
local cloudHealth = hv.Health
now += 1.05; CombatServer._tick(1.05)
check(hv.Health < cloudHealth, "Toxic Cloud did not tick")
now += 6; CombatServer._tick(6)
check(#st.Zones == 0, "Toxic Cloud never cleared")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
check(fire("StaticField") and hv.Health < 1000 and CombatServer._state(victim).StunUntil > now, "Static Field self-centred stun")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
hv.Health = 120
check(fire("Overload") and hv.Health == 0, "Overload execute below 20%")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
hv.Health = 1000
check(fire("IonSpark") and st.Resources.Charge == 85 and hv.Health < 1000, "Ion Spark cost/damage")
-- Overcharge perks multiply their element's surges.
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
check(fire("IonSpark"), "Ion Spark refused")
local plain = 1000 - hv.Health
for _, id in { "CleaverCalibration", "ChargeRecycler", "IonOvercharge" } do
	profiles[source].Augments.Unlocked[id] = true
end
Tree.initialize(profiles[source])
check(Tree.effects(profiles[source]).Ion == 0.1, "Ion Overcharge not learned")
st = reset()
loadout.WeaponGem = { Element = "Shock", Size = 4, Clarity = 5, Cut = 5 }
local boosted = fire("IonSpark") and (1000 - hv.Health)
check(boosted and close(boosted / plain, 1.1), "Ion Overcharge multiplier")
st = reset()
check(not CombatServer._technology(source, "spoofed", rv.Position), "Unknown technique accepted")
check(not CombatServer._technology(source, "HydraulicSlam", Vector3.new(0/0, 0, 0)), "Nonfinite technique aim accepted")
CombatServer._input(source, "GemSurge", "HydraulicSlam", rv.Position)
check(hv.Health == 1000, "Mismatched action category accepted")
rs.Position = Vector3.zero
check(not fire("HydraulicSlam"), "Town technique accepted")
check(Tech.hasGem({Surge2Gem={Element="Frost"}},"Frost"),"Dedicated capacitor does not enable its element")
check(not Tech.hasGem({Surge1Gem={Element="Fire"}},"Shock"),"Capacitor enabled unrelated element")
check(Tech.hasGem({Surge3Gem={Element="Poison"}}),"Capacitor did not enable Charge regen")
rs.Position = arena
st = reset()
loadout.WeaponGem = nil
loadout.Surge1Gem = {Element="Fire",Size=4,Clarity=5,Cut=5}
check(fire("ThermalBurst") and hv.Health<1000,"Live Surge did not draw from dedicated capacitor")
loadout.Surge1Gem = nil
print("PASS: " .. checks .. " live technology/resource checks (all actions incl. Corrosive/Ion surges, clouds, execute, Overcharge, costs, sockets, channels, wind-ups, PvP and walls)")
