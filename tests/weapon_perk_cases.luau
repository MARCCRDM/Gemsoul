-- The Forge's weapons in real CombatServer fights: their own pace and reach,
-- and their perks (Shared.WeaponForge). Chance-based perks aren't rolled here
-- (math.random is pinned); everything else is.
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function forge(kind, rarity)
	return "Forge" .. kind .. rarity
end
local attacker, ha, ra, la = makePlayer(701, arena + Vector3.new(6, 0, 8), nil)
local target, ht, rt, lt = makePlayer(702, arena + Vector3.new(6, 0, 4), nil)
local function reset()
	ha.Health, ht.Health = 1000, 1000
	CombatServer.reset(attacker)
	CombatServer.reset(target)
	now += 5
end
-- One blow from `weaponId` on the target; returns the damage it took.
local function hit(weaponId, targetHealth)
	la.Weapon = weaponId
	reset()
	ht.Health = targetHealth or 1000
	local before = ht.Health
	CombatServer._attack(attacker, rt.Position, false)
	return before - ht.Health
end

-- Pace and reach: every kind fights its own way.
for _, weapon in WeaponForge.Catalog do
	local rules = Actions.forWeapon({}, weapon, Classes.effects({ Class = "Warrior", Weapon = weapon.Id }))
	local expected = weapon.Attack.Rate / (1 + (weapon.Passive.Effect.AttackSpeed or 0))
	check(math.abs(rules.BasicCooldown - expected) < 1e-6, weapon.Id .. " doesn't swing at its own pace")
end
check(hit(forge("Cleaver", 1)) > 0, "A Forge cleaver didn't hit")
rt.Position = ra.Position + Vector3.new(0, 0, -9)
check(hit(forge("Lance", 1)) > 0, "A lance didn't reach 9 studs")
check(hit(forge("Cleaver", 1)) == 0, "A cleaver reached as far as a lance")
rt.Position = ra.Position + Vector3.new(0, 0, -4)

-- Executioner (+40% under 35% health) against a plain hit.
local plain = hit(forge("Cleaver", 5), 1000)
local finishing = hit(forge("Cleaver", 5), 300)
check(math.abs(finishing / plain - 1.4) < 0.02, "Executioner bonus wrong: " .. finishing / plain)
-- Opening Cut (+30% at full health).
local opener = hit(forge("Cleaver", 4), 1000)
local later = hit(forge("Cleaver", 4), 800)
check(math.abs(opener / later - 1.3) < 0.02, "Opening Cut bonus wrong: " .. opener / later)
-- Gladiator (+18% against players).
local gladiator = hit(forge("Greataxe", 4), 1000)
local axe = hit(forge("Greataxe", 1), 1000)
check(math.abs(gladiator / axe - 1.18) < 0.02, "Gladiator bonus wrong: " .. gladiator / axe)
-- Bloodrage (+25% while you're under half health).
la.Weapon = forge("Greataxe", 3)
local calm = hit(forge("Greataxe", 3), 1000)
reset()
ha.Health = 400
CombatServer._attack(attacker, rt.Position, false)
check(math.abs((1000 - ht.Health) / calm - 1.25) < 0.02, "Bloodrage bonus wrong")
-- Shieldcrusher (+35% on a blocking foe), measured before the guard's cut.
local crusher = hit(forge("Warhammer", 2), 1000)
check(crusher > 0, "Shieldcrusher missed")

-- Siphon Edge: heals 5% of the damage dealt.
la.Weapon = forge("Cleaver", 1)
reset()
ha.Health = 500
CombatServer._attack(attacker, rt.Position, false)
local dealt = 1000 - ht.Health
check(math.abs((ha.Health - 500) - dealt * 0.05) < 0.01, "Siphon Edge didn't heal 5%")
-- Second Wind: each hit restores 6% Stamina (after the swing's own cost).
la.Weapon = forge("Cleaver", 2)
reset()
local st = CombatServer._state(attacker)
st.Resources.Stamina = 50
CombatServer._attack(attacker, rt.Position, false)
local cost = Actions.swingCost(Classes.weapon("Warrior", la.Weapon), false)
check(math.abs(st.Resources.Stamina - (50 - cost + 6)) < 0.01, "Second Wind didn't restore 6% Stamina")
-- Conductor: each hit restores 4% Charge. (No surge gem here, so Charge
-- starts the swing at 0.)
la.Weapon = forge("Lance", 1)
reset()
st = CombatServer._state(attacker)
CombatServer._attack(attacker, rt.Position, false)
check(math.abs(st.Resources.Charge - 4) < 1e-6, "Conductor didn't restore 4% Charge: " .. st.Resources.Charge)
-- Victor's Feast: a kill heals 15% of max health.
la.Weapon = forge("Cleaver", 3)
reset()
ha.Health, ht.Health = 500, 1
CombatServer._attack(attacker, rt.Position, false)
check(ht.Health <= 0 and math.abs(ha.Health - 650) < 0.01, "Victor's Feast didn't heal on a kill")
-- Piercer: the target takes 12% more damage for 5s.
la.Weapon = forge("Lance", 4)
reset()
CombatServer._attack(attacker, rt.Position, false)
check(
	math.abs(CrowdControl.debuff(CombatServer._state(target).CC, "Vulnerable", now) - 0.12) < 1e-6,
	"Piercer didn't make the target vulnerable"
)
-- Frost Tip: slows a player 20% for 2s.
la.Weapon = forge("Lance", 2)
reset()
CombatServer._attack(attacker, rt.Position, false)
local slowed = CombatServer._state(target)
check(slowed.Slow == 0.2 and slowed.SlowUntil > now, "Frost Tip didn't slow a player")
-- Serrated: bleeds 25% of the hit over 3 seconds.
la.Weapon = forge("TwinBlades", 4)
reset()
CombatServer._attack(attacker, rt.Position, false)
local bleed = CombatServer._state(target).Dots[attacker]
dealt = 1000 - ht.Health
check(bleed and math.abs(bleed.Damage * 3 - dealt * 0.25) < 0.01, "Serrated didn't bleed 25%")
-- Retribution: a melee attacker takes 15% of their hit back.
la.Weapon, lt.Weapon = forge("Cleaver", 1), forge("Warhammer", 3)
reset()
ha.Health = 1000
CombatServer._attack(attacker, rt.Position, false)
dealt = 1000 - ht.Health
check(ha.Health < 1000 and ha.Health > 1000 - dealt * 0.15 - 1, "Retribution didn't hit back")
lt.Weapon = "MatrixSwords1"
-- Titan Hide: 12% less damage taken.
local soft = hit(forge("Cleaver", 1), 1000)
lt.Weapon = forge("Greataxe", 5)
local hard = hit(forge("Cleaver", 1), 1000)
check(math.abs(hard / soft - 0.88) < 0.02, "Titan Hide didn't cut damage 12%")
lt.Weapon = "MatrixSwords1"

-- Two-handed weapons leave no hand for a shield.
local shieldId = Classes.get("Warrior").Shields[1].Id
for _, kind in { "TwinBlades", "Greataxe", "Warhammer", "Lance" } do
	check(Classes.heldShield({ Class = "Warrior", Weapon = forge(kind, 3), Shield = shieldId }) == nil, kind .. " kept a shield")
end
check(Classes.heldShield({ Class = "Warrior", Weapon = forge("Cleaver", 3), Shield = shieldId }) ~= nil, "A one-handed cleaver lost its shield")
check(Classes.heldShield({ Class = "Warrior", Weapon = "MatrixSwords1", Shield = shieldId }) ~= nil, "Sword and board lost its shield")
check(Classes.heldShield(nil) == nil, "No loadout should mean no shield")

print("PASS: " .. checks .. " Forge weapon checks (pace, reach, executes, openers, bloodrage, lifesteal, resources, kills, vulnerability, slows, bleeds, thorns, armor)")

-- An occupied offhand must contribute neither hidden ratings nor passive/gem effects.
for _,kind in {"TwinBlades","Lance","Greataxe","Warhammer"} do
 local full={Class="Warrior",Weapon=forge(kind,3),Shield=shieldId,ShieldQuality=4,
 ShieldGem={Element="Fire",Tier="Legendary",Size=10,Clarity=10,Cut=10},
 GearRolls={Shields={[shieldId]={Rarity=5,Stats={Defense=200},Affixes={{Id="ThermalDamage",Bonus=.5}}}}}}
 local empty=table.clone(full);empty.Shield=nil;empty.ShieldGem=nil;empty.ShieldQuality=nil
 local actual,expected=Classes.ratings(full),Classes.ratings(empty)
 for stat,r in actual do check(r.Base==expected[stat].Base and r.Bonus==expected[stat].Bonus,kind.." inherited shield ratings") end
 local k,without=CombatServer.kitFor(full,{}),CombatServer.kitFor(empty,{})
 check(k.Defense.Resistance==without.Defense.Resistance and k.Defense.Shield==without.Defense.Shield,"Inactive shield gem affected defense")
 check(k.Effects.Ward==without.Effects.Ward,"Inactive shield passive applied")
 check(k.Loadout.Shield==nil and full.Shield==shieldId,"Shield must be inactive without deleting saved gear")
 check(k.Rules.BlockReduction==.3 and k.Rules.BlockPvPReduction==.25 and k.Rules.BlockArc==90,"Weapon block used shield mitigation")
 local weapon=Classes.weapon("Warrior",full.Weapon)
 local dps=weapon.Attack.Damage/weapon.Attack.Rate
 check(dps>30 and dps<34,"Two-hand sustained base DPS outside intended range")
 local attrs={WeaponBlock=true,CombatWeaponType=kind,GuardUntil=101}
 local guard=RivalPose.pose(attrs,100.05)
 check(guard.RightShoulder[1]>1 and guard.LeftShoulder[1]>1,"Weapon guard failed to raise both arms")
 attrs.BlockedAt=100
 check(RivalPose.pose(attrs,100.05).RightShoulder[1]<guard.RightShoulder[1],"Weapon guard did not recoil")
 check(RivalPose.pose(attrs,102).RightShoulder[1]<1,"Weapon guard failed to recover")
 full.Weapon=forge("Cleaver",3)
 check(Classes.activeLoadout(full).Shield==shieldId,"Returning to one hand failed to restore shield")
end
print("PASS: two-hand offhand exclusion, damage budgets, guard, recoil, recovery and saved-shield restoration")
