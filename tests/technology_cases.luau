local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function close(a, b)
	return math.abs(a - b) < 0.00001
end
local source, hs, rs, loadout = makePlayer(20, arena, nil)
local victim, hv, rv, defense = makePlayer(21, arena + Vector3.new(0, 0, -5), nil)
local progress = Tree.initialize(profiles[source])
progress.XP = (Tree.UnlockPoints - Tree.StartingPoints) * Tree.XPPerPoint
for _, id in Tree.Order.RigManeuvers do
	progress.Unlocked[id] = true
end
Tree.initialize(profiles[source])
loadout.Shield = "ArmorProspectorShield1"
local expected = Classes.weapon("Warrior", loadout.Weapon).Attack.Damage
	* Combat.powerMult(Classes.ratings(loadout).Power.Base)
	* Combat.defenseMult(Classes.ratings(defense).Defense.Base)
local function reset()
	now += 20
	CombatServer.reset(source)
	CombatServer.reset(victim)
	hs.Health, hv.Health = 1000, 1000
	loadout.WeaponGem, loadout.ArmorGem = nil, nil
	loadout.Surge1Gem, loadout.Surge2Gem, loadout.Surge3Gem = nil, nil, nil
	wallBlocks = false
	local st = CombatServer._state(source)
	-- A fight starts part-charged; the checks below measure each spend from full.
	st.Resources.Charge = Tech.Resources.Charge.Max
	return st
end
local function fire(id)
	return CombatServer._technology(source, id, rv.Position)
end
-- Gem Surges: the gem in a Surge Array slot (Q, E, R) decides the ability.
local function surgeGem(element, tier, rank, extra)
	local gem = {
		Id = "g" .. element .. tier,
		Element = element,
		Tier = "Rare",
		SurgeTier = tier,
		SurgeRank = rank or 1,
		Size = 4,
		Clarity = 5,
		Cut = 0,
	}
	for key, value in extra or {} do
		gem[key] = value
	end
	loadout.Surge1Gem = gem
	return gem
end
local function cast(key)
	return CombatServer._technology(source, nil, rv.Position, key or "Q")
end
-- Every ability lands when its cast completes (Actions.castTime), as the rival's do.
local function land(seconds)
	now += seconds
	CombatServer._tick(seconds)
end
local MOVE = Actions.CastTime.Move
-- The socketed surge's own cast time.
local function landSurge()
	land(Actions.castTime(Tech.surgeStats(loadout.Surge1Gem)))
end
check(#Tech.Order.RigManeuvers == #Tree.Order.RigManeuvers, "Kit catalog parity")
for _, id in Tech.Order.RigManeuvers do
	check(Tech.Catalog[id] ~= nil, "Missing kit entry")
end
for element, list in Tech.Surges do
	check(#list == 4, "Four surge tiers per element")
	for _, id in list do
		check(
			Tech.Catalog[id] and Tech.Catalog[id].Element == element and Tech.Catalog[id].Resource == "Charge",
			"Surge catalog entry " .. id
		)
	end
end
local st = reset()
st.Resources.Stamina = Tech.Catalog.HydraulicSlam.Cost - 1
check(
	not fire("HydraulicSlam") and st.Resources.Stamina == Tech.Catalog.HydraulicSlam.Cost - 1,
	"Insufficient Stamina consumed"
)
st.Resources.Stamina = 100
check(
	fire("HydraulicSlam") and st.Resources.Stamina == 100 - Tech.Catalog.HydraulicSlam.Cost and hv.Health == 1000,
	"Hydraulic Slam cost/cast"
)
land(MOVE)
check(close(1000 - hv.Health, expected * Tech.Catalog.HydraulicSlam.Damage), "Hydraulic Slam damage")
check(not fire("ServoFlurry"), "Technique recovery bypass")
st = reset()
check(
	fire("ServoFlurry") and #st.Pending == 2 and st.Resources.Stamina == 100 - Tech.Catalog.ServoFlurry.Cost,
	"Servo Flurry first strike/cost"
)
land(MOVE)
check(
	close(1000 - hv.Health, expected * Tech.Catalog.ServoFlurry.Damage) and #st.Pending == 1,
	"Servo Flurry first hit"
)
land(0.2)
check(
	close(1000 - hv.Health, expected * 2 * Tech.Catalog.ServoFlurry.Damage) and #st.Pending == 0,
	"Servo Flurry second hit"
)
-- Real cooldowns: after the short lockout another ability is free, but the
-- same one waits for its own cooldown.
now += 1
CombatServer._tick(1)
check(not fire("ServoFlurry"), "Servo Flurry ignored its cooldown")
check(fire("KineticRam"), "Lockout outlasted the recovery")
st = reset()
-- Blinded: blows go wide.
st.Blind, st.BlindUntil = 1, now + 5
check(fire("HydraulicSlam"), "Blinded slam refused")
land(MOVE)
check(hv.Health == 1000, "A blinded strike landed")
st = reset()
-- A Static Shell stuns whoever hits its owner; a Burning Ward burns them.
local guardState = CombatServer._state(victim)
guardState.SurgeWardUntil, guardState.SurgeWardKind, guardState.SurgeWardStun, guardState.SurgeWardNext =
	now + 5, "Stun", 0.6, 0
check(fire("HydraulicSlam"), "Slam refused")
land(MOVE)
check(st.StunUntil > now, "Static Shell didn't shock the attacker")
st = reset()
guardState = CombatServer._state(victim)
guardState.SurgeWardUntil, guardState.SurgeWardKind, guardState.SurgeWardPower, guardState.SurgeWardNext =
	now + 5, "Burn", 5, 0
check(fire("HydraulicSlam"), "Slam refused")
land(MOVE)
check(st.Dots[victim] ~= nil, "Burning Ward didn't burn the attacker")
st = reset()
-- Pneumatic Jab: cancels a surge being cast and locks the caster's surges.
local foe = CombatServer._state(victim)
foe.Pending =
	{ { Definition = { Resource = "Charge", Damage = 1, Name = "Test Bolt" }, Aim = rs.Position, At = now + 5 } }
check(fire("PneumaticJab"), "Pneumatic Jab refused")
land(MOVE)
check(#foe.Pending == 0 and foe.SilenceUntil > now, "Pneumatic Jab didn't interrupt the cast")
st = reset()
check(fire("PneumaticJab"), "Pneumatic Jab refused")
land(MOVE)
check(hv.Health < 1000 and CombatServer._state(victim).SilenceUntil == 0, "A jab on no cast still locked surges")
-- Thruster Leap: airborne toward the aim, the blow lands on touchdown.
st = reset()
check(fire("ThrusterLeap") and st.DodgeMove ~= nil and st.DodgeMove.Kind == "Leap", "Thruster Leap didn't leap")
check(hv.Health == 1000, "Thruster Leap hit before landing")
land(0.45)
check(close(1000 - hv.Health, expected * Tech.Catalog.ThrusterLeap.Damage), "Thruster Leap landing")
-- Riposte Stance: the blow is turned aside, its attacker staggered and struck back.
st = reset()
foe = CombatServer._state(victim)
foe.RiposteUntil, foe.RiposteDamage = now + 1, 50
check(fire("HydraulicSlam"), "Slam refused")
land(MOVE)
check(
	hv.Health == 1000 and st.StunUntil > now and hs.Health < 1000 and foe.RiposteUntil == 0,
	"Riposte didn't turn the blow aside"
)
-- Element combos (Shared.ElementCombos), pure and live.
check(ElementCombos.check({ Heavy = true }, { Frozen = true }) == "Shatter", "Shatter rule")
check(ElementCombos.check({ Element = "Fire" }, { Shredded = true }) == "Combustion", "Combustion rule")
check(ElementCombos.check({ Element = "Shock" }, { Slowed = true }) == "Superconduct", "Superconduct rule")
check(
	ElementCombos.check({ Element = "Frost" }, { Frozen = true, Shredded = true, Slowed = true }) == nil,
	"A combo with no trigger"
)
st = reset()
foe = CombatServer._state(victim)
foe.StunKind, foe.StunUntil = "Frozen", now + 3
check(fire("HydraulicSlam"), "Slam refused")
land(MOVE)
check(
	close(1000 - hv.Health, expected * Tech.Catalog.HydraulicSlam.Damage * ElementCombos.List.Shatter.Mult)
		and foe.StunUntil <= now,
	"Shatter: heavy on Frozen"
)
st = reset()
st = reset()
check(
	fire("BreachHammer") and hv.Health == 1000 and st.Resources.Stamina == 100 - Tech.Catalog.BreachHammer.Cost,
	"Breach Hammer wind-up"
)
CombatServer._input(source, "CancelTech")
now += 1.1
CombatServer._tick(1.1)
check(hv.Health == 1000, "Cancelled wind-up hit")
st = reset()
check(fire("BreachHammer"), "Breach Hammer refused")
now += 1.1
CombatServer._tick(1.1)
check(close(1000 - hv.Health, expected * Tech.Catalog.BreachHammer.Damage), "Breach Hammer damage")
st = reset()
loadout.Shield = nil
check(not fire("KineticRam"), "Kinetic Ram without shield")
loadout.Shield = "ArmorProspectorShield1"
check(fire("KineticRam") and st.Resources.Stamina == 100 - Tech.Catalog.KineticRam.Cost, "Kinetic Ram cost")
land(MOVE)
check(
	close(1000 - hv.Health, expected * Tech.Catalog.KineticRam.Damage) and CombatServer._state(victim).StunUntil > now,
	"Kinetic Ram damage/stagger"
)
st = reset()
CombatServer._block(victim, true, rs.Position)
check(fire("ArmorPiercer"), "Armor Piercer refused")
land(MOVE)
check(close(1000 - hv.Health, expected * Tech.Catalog.ArmorPiercer.Damage), "Armor Piercer blocked")
check(CombatServer._state(victim).Sunder > 0, "Armor Piercer shred missing")
check(victim:GetAttribute("Blocking"), "Armor Piercer destroyed guard instead of bypassing")
st = reset()
hs.Health = 500
check(
	fire("StimDodge")
		and st.Resources.Stamina == 85
		and hs.Health == 500 + 1000 * Tech.Catalog.StimDodge.Heal
		and st.DodgeMove ~= nil,
	"Stim Dodge heal/movement/cost"
)
st = reset()
st.Resources.Stamina = 14
check(not CombatServer._dodge(source, Vector3.new(0, 0, -1)), "Free ordinary dodge")
st = reset()
check(not cast("Q") and st.Resources.Charge == 100, "Empty surge slot consumed Charge")
-- The Charge economy: a fight starts part-full; surges can't follow each other
-- faster than the lockout, however short their own recovery.
CombatServer.reset(source)
check(CombatServer._state(source).Resources.Charge == Tech.Resources.Charge.Start, "A fight starts at Charge.Start")
st = reset()
surgeGem("Shock", 1, 3, { Clarity = 10 })
check(cast("Q") and st.NextTech - now >= Tech.SurgeLockout - 1e-6, "Surge lockout floor")
st = reset()
check(not fire("ThermalBurst"), "Surge cast as a learned technique")
surgeGem("Fire", 1)
check(not cast("E"), "Surge from an empty slot")
check(
	cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.ThermalBurst.Cost and hv.Health == 1000,
	"Thermal Burst cost/cast"
)
landSurge()
check(hv.Health < 1000, "Thermal Burst damage")
check(CombatServer._state(victim).Dots[source] ~= nil, "Thermal Burst burn missing")
check(not cast("Q"), "Surge slot cooldown bypass")
st = reset()
surgeGem("Frost", 1)
check(cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.CryoLance.Cost, "Cryo Lance cost")
landSurge()
check(hv.Health < 1000, "Cryo Lance damage")
check(CombatServer._state(victim).StunUntil > now, "Cryo Lance freeze missing")
st = reset()
surgeGem("Frost", 3)
check(cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.CryoShield.Cost, "Cryo Shield cost")
landSurge()
check(st.Shield == 42, "Cryo Shield barrier")
st = reset()
surgeGem("Frost", 2)
check(
	cast("Q") and close(st.Resources.Charge, 100 - Tech.Catalog.CryoStream.Cost * 0.25) and st.Channel == nil,
	"Stream opening quarter-second cost"
)
landSurge()
check(st.Channel ~= nil and hv.Health < 1000, "Stream did not open after its cast")
local health = hv.Health
local charge = st.Resources.Charge
now += 0.25
check(cast("Q"), "Stream refresh refused")
CombatServer._tick(0.25)
check(
	hv.Health < health
		and close(
			st.Resources.Charge,
			math.min(Tech.Resources.Charge.Max, charge + 0.25 * Tech.Resources.Charge.Regen)
				- Tech.Catalog.CryoStream.Cost * 0.25
		),
	"Stream pulse billing or damage"
)
check(not CombatServer._attack(source, rv.Position, false), "Attacked during channel")
CombatServer._input(source, "CancelTech")
health = hv.Health
now += 0.3
CombatServer._tick(0.3)
check(st.Channel == nil and hv.Health == health, "Released stream continued")
st = reset()
surgeGem("Frost", 2)
cast("Q")
landSurge()
now += 0.6
CombatServer._tick(0.6)
check(st.Channel == nil, "Lost stream release packet stuck channel")
st = reset()
surgeGem("Frost", 2)
check(cast("Q"), "Cryo Stream refused")
landSurge()
check(st.Channel ~= nil and hv.Health < 1000, "Cryo Stream channel")
loadout.Surge1Gem = nil
health = hv.Health
now += 0.25
CombatServer._tick(0.25)
check(st.Channel == nil and hv.Health == health, "Stream kept firing after its gem left the slot")
st = reset()
surgeGem("Fire", 1)
st.Resources.Stamina, st.Resources.Charge = 50, 50
now += 0.5
CombatServer._tick(0.5)
check(
	close(st.Resources.Stamina, 50 + 0.5 * Tech.Resources.Stamina.Regen)
		and close(st.Resources.Charge, 50 + 0.5 * Tech.Resources.Charge.Regen),
	"Resource regeneration"
)
loadout.Surge1Gem = nil
now += 0.1
CombatServer._tick(0.1)
check(st.Resources.Charge == 0, "Unsocketed rig retained Charge")
st = reset()
surgeGem("Fire", 1)
victim:SetAttribute("PvPEnabled", false)
check(cast("Q"), "Surge refused")
landSurge()
check(hv.Health == 1000, "Surge hit training visitor")
victim:SetAttribute("PvPEnabled", true)
st = reset()
surgeGem("Frost", 1)
wallBlocks = true
check(cast("Q"), "Surge refused")
landSurge()
check(hv.Health == 1000, "Surge ignored wall")
-- Every element's ability tiers.
st = reset()
surgeGem("Fire", 2)
check(cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.EmberLance.Cost, "Ember Lance cost")
landSurge()
check(hv.Health < 1000, "Ember Lance bolt")
local lance = 1000 - hv.Health
st = reset()
surgeGem("Fire", 1)
cast("Q")
landSurge()
check(
	close(lance / (1000 - hv.Health), Tech.Catalog.EmberLance.Damage / Tech.Catalog.ThermalBurst.Damage),
	"Ember Lance against Thermal Burst"
)
st = reset()
surgeGem("Fire", 3)
check(
	cast("Q") and hv.Health == 1000 and #st.Pending == 1 and st.Resources.Charge == 100 - Tech.Catalog.SolarFlare.Cost,
	"Solar Flare wind-up"
)
now += 0.65
CombatServer._tick(0.65)
check(hv.Health < 1000, "Solar Flare blast missing")
check(CombatServer._state(victim).BlindUntil > now, "Solar Flare didn't blind")
st = reset()
surgeGem("Fire", 4)
check(cast("Q") and hv.Health == 1000 and #st.Pending == 1, "Supernova wind-up")
now += 1.25
CombatServer._tick(1.25)
check(hv.Health < 1000, "Supernova blast missing")
check(st.SurgeWardUntil > now and st.SurgeWardKind == "Burn" and st.Shield > 0, "Supernova's Burning Ward missing")
-- Resonance surges: no element, carried by any gem.
st = reset()
surgeGem("Poison", 2, 1, { Surge = "EnergySiphon" })
check(cast("Q"), "Energy Siphon refused")
landSurge()
check(st.SiphonUntil > now and st.SiphonCapacity == Tech.Catalog.EnergySiphon.Absorb, "Energy Siphon field")
st = reset()
surgeGem("Shock", 3, 1, { Surge = "ResonanceEcho" })
check(cast("Q"), "Resonance Echo refused")
landSurge()
check(st.EchoUntil > now + Tech.Catalog.ResonanceEcho.Duration, "Resonance Echo duration")
st = reset()
surgeGem("Poison", 1)
check(cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.AcidSpray.Cost, "Acid Spray cost")
landSurge()
check(hv.Health < 1000, "Acid Spray cone damage")
check(
	CombatServer._state(victim).Sunder > 0 and CombatServer._state(victim).SunderUntil > now,
	"Acid Spray shred missing"
)
st = reset()
surgeGem("Poison", 3)
check(cast("Q"), "Toxic Cloud refused")
landSurge()
check(#st.Zones == 1, "Toxic Cloud pool missing")
local cloudHealth = hv.Health
hs.Health = 500
now += 1.05
CombatServer._tick(1.05)
check(hv.Health < cloudHealth, "Toxic Cloud did not tick")
check(hs.Health > 500, "Toxic Cloud's leech didn't heal")
now += 8
CombatServer._tick(8)
check(#st.Zones == 0, "Toxic Cloud never cleared")
st = reset()
surgeGem("Shock", 2)
check(cast("Q"), "Static Field refused")
landSurge()
check(hv.Health < 1000 and CombatServer._state(victim).StunUntil > now, "Static Field self-centred stun")
check(st.SurgeWardUntil > now and st.SurgeWardKind == "Stun", "Static Field's Static Shell missing")
st = reset()
surgeGem("Shock", 4)
hv.Health = 120
check(cast("Q"), "Overload refused")
landSurge()
check(hv.Health == 0, "Overload execute below 20%")
check(Tech.Catalog.ChainLightning.Chain == 3, "Chain Lightning bounces")
-- Gem metrics and rank: Size = damage, Clarity = duration, rank = power and cost.
st = reset()
hv.Health = 1000
surgeGem("Shock", 1)
check(cast("Q") and st.Resources.Charge == 100 - Tech.Catalog.IonSpark.Cost, "Ion Spark cost")
landSurge()
check(hv.Health < 1000, "Ion Spark damage")
local plain = 1000 - hv.Health
st = reset()
surgeGem("Shock", 1, 3)
check(cast("Q") and close(st.Resources.Charge, 100 - Tech.Catalog.IonSpark.Cost * 0.84), "Rank III surge cost")
landSurge()
check(close((1000 - hv.Health) / plain, 1.5), "Rank III surge power")
st = reset()
surgeGem("Shock", 1, 1, { Size = 10 })
check(cast("Q"), "Surge refused")
landSurge()
check(close((1000 - hv.Health) / plain, 1.3 / 1.12), "Gem Size damage")
local clear = Tech.surgeStats({ Id = "f", Element = "Frost", SurgeTier = 1, SurgeRank = 1, Clarity = 10 })
local cloudy = Tech.surgeStats({ Id = "f", Element = "Frost", SurgeTier = 1, SurgeRank = 1, Clarity = 1 })
check(
	close(clear.Stun, Tech.Catalog.CryoLance.Stun * 1.4)
		and close(cloudy.Stun, Tech.Catalog.CryoLance.Stun * 1.04)
		and clear.Recovery < cloudy.Recovery
		and clear.Range > cloudy.Range,
	"Gem Clarity duration, recovery and reach"
)
local stats = Tech.surgeStats(
	{ Id = "x", Element = "Poison", Tier = "Rare", SurgeTier = 2, SurgeRank = 1, Size = 5, Clarity = 5, Cut = 10 },
	{ SurgePower = 0.2, SurgeEfficiency = 0.3, ArcaneResonance = 0.2 }
)
check(
	stats.Id == "ArmorMelt"
		and close(stats.Crit, 0.05)
		and close(stats.Damage, Tech.Catalog.ArmorMelt.Damage * 1.2)
		and close(stats.Recovery, Tech.Catalog.ArmorMelt.Recovery * 0.9 * 0.7)
		and close(stats.Cooldown, Tech.Catalog.ArmorMelt.Cooldown * 0.9 * 0.7)
		and close(stats.Shred, 0.35)
		and stats.Echo == 0.2,
	"Surge Amplifiers and Cut"
)
-- The directive's worked examples.
stats = Tech.surgeStats({
	Id = "c",
	Element = "Poison",
	Tier = "Rare",
	SurgeTier = 3,
	SurgeRank = 1,
	Size = 7,
	Clarity = 6,
	Cut = 5,
})
check(
	stats.Id == "ToxicCloud"
		and close(stats.Cloud.Duration, 8)
		and close(stats.Cloud.Shred, 0.125)
		and close(stats.Shred, 0.125),
	"Toxic Cloud Clarity/Cut example"
)
stats = Tech.surgeStats({
	Id = "n",
	Element = "Fire",
	Tier = "Legendary",
	SurgeTier = 4,
	SurgeRank = 3,
	Size = 10,
	Clarity = 8,
	Cut = 9,
})
check(
	stats.Id == "Supernova"
		and close(stats.Damage, Tech.Catalog.Supernova.Damage * 1.5)
		and close(stats.Recovery, Tech.Catalog.Supernova.Recovery * 0.8 * 0.84)
		and close(stats.Cooldown, Tech.Catalog.Supernova.Cooldown * 0.8 * 0.84),
	"Supernova Rank III example"
)
-- Every element climbs: each tier's cooldown at least the last one's, and
-- every ability's cooldown at least its lockout.
for element, list in Tech.Surges do
	for tier = 2, #list do
		check(
			Tech.Catalog[list[tier]].Cooldown >= Tech.Catalog[list[tier - 1]].Cooldown,
			element .. " tier " .. tier .. " cooldown below the tier before"
		)
	end
end
for id, entry in Tech.Catalog do
	check((entry.Cooldown or 0) >= entry.Recovery, id .. " cooldown shorter than its lockout")
end
local lines = Tech.surgeLines({
	Id = "u",
	Element = "Fire",
	Tier = "Uncommon",
	SurgeTier = 2,
	SurgeRank = 1,
	Size = 5,
	Clarity = 6,
	Cut = 4,
})
check(
	lines[1] == "Surge: Ember Lance (Rank I · Apprentice surge)"
		and lines[2] == string.format("%d%% base damage", math.floor(Tech.Catalog.EmberLance.Damage * 100 + 0.5))
		and lines[3] == "Size 5 (+15% damage)"
		and lines[5] == "Cut 4 (2% crit chance)"
		and lines[6] == "Sockets into any Surge Slot.",
	"Gem surge tooltip"
)
-- GemRoller: rarity bands, ranks, metrics and the Resonance share.
-- (The combat doubles pin math.random, so this uses its own generator.)
local seed = 7
local function nextNumber()
	-- Park-Miller stays exactly representable in Luau doubles.
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local rng = {
	NextInteger = function(_, a, b)
		return a + math.floor(nextNumber() * (b - a + 1))
	end,
	NextNumber = nextNumber,
}
local counts, resonance, middle, bad = {}, 0, 0, nil
local combos, legendaryOne = {}, false
for _ = 1, 20000 do
	local g = GemRoller.roll(rng, 0)
	local rules = GemRoller.ByRarity[g.Tier]
	counts[g.Tier] = (counts[g.Tier] or 0) + 1
	combos[g.SurgeTier .. ":" .. g.SurgeRank] = true
	legendaryOne = legendaryOne or (g.Tier == "Legendary" and g.SurgeRank == 1)
	if not table.find(rules.Tiers, g.SurgeTier) or not table.find(rules.Ranks, g.SurgeRank) then
		bad = "tier/rank outside its rarity"
	end
	for _, metric in { g.Size, g.Clarity, g.Cut } do
		if metric < rules.Metrics[1] or metric > rules.Metrics[2] then
			bad = "metric outside its rarity band"
		end
	end
	local surge = Tech.Catalog[g.Surge]
	if not surge or Tech.surgeOf(g) ~= g.Surge then
		bad = "no castable surge"
	elseif g.SurgeTier == 2 or g.SurgeTier == 3 then
		middle += 1
		resonance += if surge.Element == nil then 1 else 0
	elseif surge.Element ~= g.Element then
		bad = "Novice/Master gem rolled off-element"
	end
end
check(bad == nil, "GemRoller: " .. tostring(bad))
check(
	math.abs((counts.Common or 0) / 20000 - 0.40) < 0.03 and math.abs((counts.Legendary or 0) / 20000 - 0.05) < 0.01,
	"Rarity weights 40/25/20/10/5"
)
check(math.abs(resonance / middle - GemRoller.ResonanceChance) < 0.02, "Resonance share")
local everyCombo = true
for tier = 1, 4 do
	for rank = 1, 3 do
		everyCombo = everyCombo and combos[tier .. ":" .. rank] == true
	end
end
check(everyCombo, "Every surge tier rolls at every rank (I-III)")
check(not legendaryOne and GemRoller.ByRarity.Legendary.Metrics[1] == 8, "Legendary never Rank I")
-- Overcharge perks multiply their element's surges.
for _, id in { "CleaverCalibration", "ChargeRecycler", "IonOvercharge" } do
	profiles[source].Augments.Unlocked[id] = true
end
Tree.initialize(profiles[source])
check(Tree.effects(profiles[source]).Ion == 0.1, "Ion Overcharge not learned")
st = reset()
surgeGem("Shock", 1)
check(cast("Q"), "Surge refused")
landSurge()
local boosted = 1000 - hv.Health
check(boosted and close(boosted / plain, 1.1), "Ion Overcharge multiplier")
st = reset()
check(not CombatServer._technology(source, "spoofed", rv.Position), "Unknown technique accepted")
check(
	not CombatServer._technology(source, "HydraulicSlam", Vector3.new(0 / 0, 0, 0)),
	"Nonfinite technique aim accepted"
)
CombatServer._input(source, "Surge", "HydraulicSlam", rv.Position)
CombatServer._input(source, "RigManeuver", "ThermalBurst", rv.Position)
check(hv.Health == 1000, "Mismatched action category accepted")
rs.Position = Vector3.zero
check(not fire("HydraulicSlam"), "Town technique accepted")
check(Tech.hasGem({ Surge2Gem = { Element = "Frost" } }, "Frost"), "Dedicated capacitor does not enable its element")
check(not Tech.hasGem({ Surge1Gem = { Element = "Fire" } }, "Shock"), "Capacitor enabled unrelated element")
check(Tech.hasGem({ Surge3Gem = { Element = "Poison" } }), "Capacitor did not enable Charge regen")
rs.Position = arena
st = reset()
loadout.Surge3Gem = { Id = "cap", Element = "Fire", Size = 4, Clarity = 5, Cut = 5 }
check(CombatServer._technology(source, nil, rv.Position, "R"), "Live Surge refused from its R capacitor")
land(Actions.castTime(Tech.surgeStats(loadout.Surge3Gem)))
check(hv.Health < 1000, "Live Surge did not draw from its R capacitor")
loadout.Surge3Gem = nil

-- Expansion: every new surge goes through the production server, not a catalog-only check.
check(#Tech.Order.GemSurges == 36 and #Tech.NewSurges == 18, "Gem surge roster was not doubled")
check(#Tech.Order.RigManeuvers == 11 and #Tree.Order.RigManeuvers == 11, "Maneuver scope changed")
local rolled = {}
for _ = 1, 50000 do
	local gem = GemRoller.roll(rng, 0)
	rolled[gem.Surge] = true
end
for _, id in Tech.NewSurges do
	local d = Tech.Catalog[id]
	check(rolled[id], "New surge cannot drop: " .. id)
	st = reset()
	rs.Position, rv.Position = arena, arena + Vector3.new(0, 0, -5)
	hs.Health = 500
	local tier = if d.Element
		then table.find(Tech.SurgeVariants[d.Element], id)
		else (if id == "NullPrism" then 3 else 2)
	local gem = surgeGem(d.Element or "Shock", tier, 1, { Surge = id })
	local stats = Tech.surgeStats(gem)
	st.Resources.Charge = stats.Cost - 0.01
	check(not cast(), "Insufficient Charge accepted: " .. id)
	st.Resources.Charge = 100
	check(cast() and close(st.Resources.Charge, 100 - stats.Cost), "Charge cost: " .. id)
	check(hv.Health == 1000, "Damage preceded cast release: " .. id)
	check(source.Character:GetAttribute("ActionKind") == d.Animation, "Replicated animation: " .. id)
	landSurge()
	check(hv.Health < 1000, "No server damage: " .. id)
	if d.Slow then
		check(CombatServer._state(victim).SlowUntil > now, "Missing slow: " .. id)
	end
	if d.Shred then
		check(CombatServer._state(victim).SunderUntil > now, "Missing shred: " .. id)
	end
	if d.Leech then
		check(hs.Health > 500, "Missing leech: " .. id)
	end
	if d.Cloud then
		check(st.Zones and #st.Zones > 0, "Missing pool: " .. id)
	end
	check(not cast(), "Cooldown bypass: " .. id)
	st = reset()
	surgeGem(d.Element or "Shock", tier, 1, { Surge = id })
	wallBlocks = true
	check(cast(), "Cast rejected before wall check: " .. id)
	landSurge()
	check(hv.Health == 1000, "New surge hit through wall: " .. id)
	wallBlocks = false
	if d.Element then
		GemRoller.setElement(gem, "Frost")
		check(gem.Surge == Tech.SurgeVariants.Frost[tier], "Element conversion lost variant: " .. id)
	else
		GemRoller.setElement(gem, "Fire")
		check(gem.Surge == id, "Resonance changed with element: " .. id)
	end
	local a = { ActionKind = d.Animation, ActionStart = 100, ActionAt = 101 }
	local windup = RivalPose.pose(a, 100.8, true)
	local release = RivalPose.pose(a, 101.08, true)
	check(
		windup.RightShoulder and release.RightShoulder and windup.RightShoulder[1] ~= release.RightShoulder[1],
		"Static/missing pose: " .. id
	)
	check(RivalPose.pose(a, 103, true).RightShoulder == nil, "Pose did not recover: " .. id)
end
st = reset()
-- Abilities show painted icons (SurgeIcons), not text glyphs.
for id, def in Tech.Catalog do
	check(def.Icon == nil, "Text glyph left on ability: " .. id)
end
print(
	"PASS: "
		.. checks
		.. " live technology/resource checks including every new gem surge, drops, animations, costs, walls and cooldowns"
)
