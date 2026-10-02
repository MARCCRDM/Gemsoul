local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function close(a, b) return math.abs(a - b) < 0.00001 end
local source, hs, rs, loadout = makePlayer(20, arena, nil)
local victim, hv, rv, defense = makePlayer(21, arena + Vector3.new(0, 0, -5), nil)
local progress = Tree.initialize(profiles[source])
progress.XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint
for _, id in Tree.Order.RigManeuvers do progress.Unlocked[id] = true end
Tree.initialize(profiles[source])
loadout.Shield = "ArmorProspectorShield1"
local expected = Classes.weapon("Warrior", loadout.Weapon).Attack.Damage * Combat.powerMult(Classes.ratings(loadout).Power.Base) * Combat.defenseMult(Classes.ratings(defense).Defense.Base)
local function reset()
	now += 20
	CombatServer.reset(source); CombatServer.reset(victim)
	hs.Health, hv.Health = 1000, 1000
	loadout.WeaponGem, loadout.ArmorGem = nil, nil
	loadout.Surge1Gem, loadout.Surge2Gem, loadout.Surge3Gem = nil, nil, nil
	wallBlocks = false
	return CombatServer._state(source)
end
local function fire(id) return CombatServer._technology(source, id, rv.Position) end
-- Gem Surges: the gem in a Surge Array slot (Q, E, R) decides the ability.
local function surgeGem(element, tier, rank, extra)
	local gem = { Id = "g" .. element .. tier, Element = element, Tier = "Rare", SurgeTier = tier, SurgeRank = rank or 1, Size = 4, Clarity = 5, Cut = 0 }
	for key, value in extra or {} do gem[key] = value end
	loadout.Surge1Gem = gem
	return gem
end
local function cast(key) return CombatServer._technology(source, nil, rv.Position, key or "Q") end
check(#Tech.Order.RigManeuvers == #Tree.Order.RigManeuvers, "Kit catalog parity")
for _, id in Tech.Order.RigManeuvers do check(Tech.Catalog[id] ~= nil, "Missing kit entry") end
for element, list in Tech.Surges do
	check(#list == 4, "Four surge tiers per element")
	for _, id in list do check(Tech.Catalog[id] and Tech.Catalog[id].Element == element and Tech.Catalog[id].Resource == "Charge", "Surge catalog entry " .. id) end
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
check(not cast("Q") and st.Resources.Charge == 100, "Empty surge slot consumed Charge")
check(not fire("ThermalBurst"), "Surge cast as a learned technique")
surgeGem("Fire", 1)
check(not cast("E"), "Surge from an empty slot")
check(cast("Q") and st.Resources.Charge == 75 and hv.Health < 1000, "Thermal Burst cost/damage")
check(CombatServer._state(victim).Dots[source] ~= nil, "Thermal Burst burn missing")
check(not cast("Q"), "Surge slot cooldown bypass")
st = reset()
surgeGem("Frost", 1)
check(cast("Q") and st.Resources.Charge == 75 and hv.Health < 1000, "Cryo Lance cost/damage")
check(CombatServer._state(victim).SlowUntil > now, "Cryo Lance slow missing")
st = reset()
surgeGem("Frost", 3)
check(cast("Q") and st.Resources.Charge == 70 and st.Shield == 42, "Cryo Shield cost/barrier")
st = reset()
surgeGem("Frost", 2)
check(cast("Q") and close(st.Resources.Charge, 96.25) and st.Channel ~= nil, "Stream opening quarter-second cost")
local health = hv.Health
now += 0.25
check(cast("Q"), "Stream refresh refused")
CombatServer._tick(0.25)
check(hv.Health < health and close(st.Resources.Charge, 94.25), "Stream pulse billing or damage")
check(not CombatServer._attack(source, rv.Position, false), "Attacked during channel")
CombatServer._input(source, "CancelTech")
health = hv.Health
now += 0.3; CombatServer._tick(0.3)
check(st.Channel == nil and hv.Health == health, "Released stream continued")
st = reset()
surgeGem("Frost", 2)
cast("Q")
now += 0.6; CombatServer._tick(0.6)
check(st.Channel == nil, "Lost stream release packet stuck channel")
st = reset()
surgeGem("Fire", 2)
check(cast("Q") and st.Channel ~= nil and hv.Health < 1000, "Thermal Beam channel")
loadout.Surge1Gem = nil
health = hv.Health
now += 0.25; CombatServer._tick(0.25)
check(st.Channel == nil and hv.Health == health, "Beam kept firing after its gem left the slot")
st = reset()
surgeGem("Fire", 1)
st.Resources.Stamina, st.Resources.Charge = 50, 50
now += 0.5; CombatServer._tick(0.5)
check(close(st.Resources.Stamina, 56) and close(st.Resources.Charge, 53.5), "Resource regeneration")
loadout.Surge1Gem = nil
now += 0.1; CombatServer._tick(0.1)
check(st.Resources.Charge == 0, "Unsocketed rig retained Charge")
st = reset()
surgeGem("Fire", 1)
victim:SetAttribute("PvPEnabled", false)
check(cast("Q") and hv.Health == 1000, "Surge hit training visitor")
victim:SetAttribute("PvPEnabled", true)
st = reset()
surgeGem("Frost", 1)
wallBlocks = true
check(cast("Q") and hv.Health == 1000, "Surge ignored wall")
-- Every element's ability tiers.
st = reset()
surgeGem("Fire", 3)
check(cast("Q") and hv.Health < 1000 and st.Resources.Charge == 65, "Thermal Wave ring")
st = reset()
surgeGem("Fire", 4)
check(cast("Q") and hv.Health == 1000 and #st.Pending == 1, "Thermal Cataclysm wind-up")
now += 1.25; CombatServer._tick(1.25)
check(hv.Health < 1000 and #st.Zones == 1, "Thermal Cataclysm blast or burning field missing")
st = reset()
surgeGem("Poison", 1)
check(cast("Q") and st.Resources.Charge == 80 and hv.Health < 1000, "Acid Spray cost/cone damage")
check(CombatServer._state(victim).Sunder > 0 and CombatServer._state(victim).SunderUntil > now, "Acid Spray shred missing")
st = reset()
surgeGem("Poison", 3)
check(cast("Q") and #st.Zones == 1, "Toxic Cloud pool missing")
local cloudHealth = hv.Health
now += 1.05; CombatServer._tick(1.05)
check(hv.Health < cloudHealth, "Toxic Cloud did not tick")
now += 8; CombatServer._tick(8)
check(#st.Zones == 0, "Toxic Cloud never cleared")
st = reset()
surgeGem("Shock", 2)
check(cast("Q") and hv.Health < 1000 and CombatServer._state(victim).StunUntil > now, "Static Field self-centred stun")
st = reset()
surgeGem("Shock", 4)
hv.Health = 120
check(cast("Q") and hv.Health == 0, "Overload execute below 20%")
check(Tech.Catalog.ChainLightning.Chain == 5, "Chain Lightning bounces")
-- Gem metrics and rank: Size = damage, Clarity = duration, rank = power and cost.
st = reset()
hv.Health = 1000
surgeGem("Shock", 1)
check(cast("Q") and st.Resources.Charge == 85 and hv.Health < 1000, "Ion Spark cost/damage")
local plain = 1000 - hv.Health
st = reset()
surgeGem("Shock", 1, 3)
check(cast("Q") and close((1000 - hv.Health) / plain, 1.3) and close(st.Resources.Charge, 100 - 15 * 0.84), "Rank III surge power/cost")
st = reset()
surgeGem("Shock", 1, 1, { Size = 10 })
check(cast("Q") and close((1000 - hv.Health) / plain, 1.3 / 1.12), "Gem Size damage")
st = reset()
surgeGem("Frost", 1, 1, { Clarity = 10 })
cast("Q")
local longSlow = CombatServer._state(victim).SlowUntil - now
st = reset()
surgeGem("Frost", 1, 1, { Clarity = 1 })
cast("Q")
check(longSlow > CombatServer._state(victim).SlowUntil - now, "Gem Clarity duration")
local stats = Tech.surgeStats({ Id = "x", Element = "Poison", Tier = "Rare", SurgeTier = 2, SurgeRank = 1, Size = 5, Clarity = 5, Cut = 10 }, { SurgePower = 0.2, SurgeEfficiency = 0.3, ArcaneResonance = 0.2 })
check(stats.Id == "ArmorMelt" and close(stats.Crit, 0.2) and close(stats.Damage, 0.6 * 1.2) and close(stats.Recovery, 1.5 * 0.7) and stats.Echo == 0.2, "Surge Amplifiers and Cut")
-- Overcharge perks multiply their element's surges.
for _, id in { "CleaverCalibration", "ChargeRecycler", "IonOvercharge" } do
	profiles[source].Augments.Unlocked[id] = true
end
Tree.initialize(profiles[source])
check(Tree.effects(profiles[source]).Ion == 0.1, "Ion Overcharge not learned")
st = reset()
surgeGem("Shock", 1)
local boosted = cast("Q") and (1000 - hv.Health)
check(boosted and close(boosted / plain, 1.1), "Ion Overcharge multiplier")
st = reset()
check(not CombatServer._technology(source, "spoofed", rv.Position), "Unknown technique accepted")
check(not CombatServer._technology(source, "HydraulicSlam", Vector3.new(0/0, 0, 0)), "Nonfinite technique aim accepted")
CombatServer._input(source, "Surge", "HydraulicSlam", rv.Position)
CombatServer._input(source, "RigManeuver", "ThermalBurst", rv.Position)
check(hv.Health == 1000, "Mismatched action category accepted")
rs.Position = Vector3.zero
check(not fire("HydraulicSlam"), "Town technique accepted")
check(Tech.hasGem({Surge2Gem={Element="Frost"}},"Frost"),"Dedicated capacitor does not enable its element")
check(not Tech.hasGem({Surge1Gem={Element="Fire"}},"Shock"),"Capacitor enabled unrelated element")
check(Tech.hasGem({Surge3Gem={Element="Poison"}}),"Capacitor did not enable Charge regen")
rs.Position = arena
st = reset()
loadout.Surge3Gem = {Id="cap",Element="Fire",Size=4,Clarity=5,Cut=5}
check(CombatServer._technology(source, nil, rv.Position, "R") and hv.Health<1000,"Live Surge did not draw from its R capacitor")
loadout.Surge3Gem = nil
print("PASS: " .. checks .. " live technology/resource checks (maneuvers, all 16 gem surges by slot, gem metrics, ranks, amplifiers, Overcharge, channels, wind-ups, PvP and walls)")
