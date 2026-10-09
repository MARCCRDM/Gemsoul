-- The PvP Duelist: its decisions (Shared.DuelistBrain) and how its hits meet a guard.
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local base = {
	Now = 10, Distance = 4, HealthRatio = 1, Stunned = false, FoeCharging = false, FoeCasting = false,
	FoeBlocking = false, FoeRecovering = false, FoeVulnerable = false, FoeLow = false,
	NextAttack = 0, NextSurge = 99, NextDefense = 0, NextRetreat = 99, NextLunge = 99,
}
local function view(changes)
	local v = table.clone(base)
	for key, value in changes or {} do v[key] = value end
	return v
end
check(DuelistBrain.decide(view({ Stunned = true }), 0.1) == "Stagger", "Stunned rival acted")
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.1) == "Guard", "Rival ignored a charging swing (guard)")
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.6) == "Guard", "Rival didn't block a quick swing")
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.9) == "Dodge", "Rival never sidestepped a quick swing")
check(DuelistBrain.decide(view({ FoeCharging = true, FoeHeavy = true }), 0.1) == "Dodge", "Rival blocked a guard-breaking heavy")
check(DuelistBrain.decide(view({ FoeAttacking = true, FoeAggressive = true }), 0.75) == "Guard", "Rival didn't turtle against a flurry")
check(DuelistBrain.decide(view({ FoeCharging = true, GuardBroken = true }), 0.1) == "Dodge", "Rival guarded with a broken guard")
check(DuelistBrain.decide(view({ JustBlocked = true }), 0.9) == "Riposte", "Rival didn't counter after a block")
-- Against an idle player it presses the attack instead of waiting.
check(DuelistBrain.decide(view({ NextAttack = 99, FoeIdle = true }), 0.1) == "Strafe", "Rival turtled against an idle player")
check(DuelistBrain.decide(view({ NextAttack = 99 }), 0.1) == "Guard", "Rival lost its guard between swings")
check(DuelistBrain.decide(view({ Distance = 12, FoeIdle = true }), 0.1) == "Approach", "Rival crept in behind its shield at an idle player")
check(DuelistBrain.decide(view({ FoeIdle = true }), 0.35) == "Heavy", "Rival didn't punish an idle player with heavies")
check(DuelistBrain.decide(view({ Distance = 4, NextSurge = 0, FoeIdle = true }), 0.5) == "Surge", "Rival saved its surges against an idle player")
check(DuelistBrain.decide(view({ SinceOffense = 2, FoeRecovering = false }), 0.9) == "Light", "Rival stalled without attacking")
check(DuelistBrain.decide(view({ JustBlocked = true, Guarding = true, FoeAttacking = true, NextDefense = 20 }), 0.9) == "Guard", "Rival always dropped its shield to counter mid-flurry")
check(DuelistBrain.decide(view({ JustBlocked = true, Guarding = true, FoeAttacking = true, NextDefense = 20 }), 0.5) == "Riposte", "Rival rarely countered after blocking")
check(DuelistBrain.decide(view({ Guarding = true, FoeAttacking = true, FoeRecovering = true, NextDefense = 20 }), 0.9) == "Guard", "Rival dropped its guard mid-flurry")
check(DuelistBrain.decide(view({ Guarding = true, FoeCharging = true, FoeHeavy = true }), 0.1) == "Dodge", "Rival held its guard against a heavy")
check(DuelistBrain.decide(view({ FoeRanged = true, FoeRecovering = true, NextAttack = 20, Distance = 15 }), 0.3) == "GuardAdvance", "Rival walked into gunfire without its shield")
check(DuelistBrain.decide(view({ FoeCasting = true }), 0.6) == "Dodge", "Rival ignored a surge wind-up")
check(DuelistBrain.decide(view({ FoeRecovering = true, NextAttack = 20 }), 0.9) == "Punish", "Rival missed an opening")
check(DuelistBrain.decide(view({ Distance = 4, NextSurge = 0, FoeVulnerable = true }), 0.9) == "Surge", "Rival wasted a stunned target")
check(DuelistBrain.decide(view({ Distance = 4, NextSurge = 0, FoeBlocking = true }), 0.9) == "Surge", "Rival let a turtle hide")
check(DuelistBrain.decide(view({ Distance = 12, NextLunge = 0 }), 0.9) == "Lunge", "Rival never lunged in")
check(DuelistBrain.decide(view({ HealthRatio = 0.2, NextRetreat = 0, FoeLow = true }), 0.5) ~= "Retreat", "Rival retreated from a low foe")
check(DuelistBrain.decide(view({ FoeCharging = true, NextDefense = 20 }), 0.1) ~= "Guard", "Rival guarded on every swing")
check(DuelistBrain.decide(view({ Distance = 15, NextSurge = 0 }), 0.5) == "Surge", "Rival never cast from range")
check(DuelistBrain.decide(view({ Distance = 3, NextSurge = 0 }), 0.5) ~= "Surge", "Rival cast its surge point-blank")
check(DuelistBrain.decide(view({ Distance = 30 }), 0.5) == "Approach", "Rival did not close in from far")
check(DuelistBrain.decide(view({ Distance = 15 }), 0.5) == "GuardAdvance", "Rival didn't advance behind its shield")
check(DuelistBrain.decide(view({ HealthRatio = 0.2, NextRetreat = 0 }), 0.5) == "Retreat", "Hurt rival never backed off")
check(DuelistBrain.decide(view(), 0.5) == "Light", "Rival in reach did not swing")
check(DuelistBrain.decide(view(), 0.1) == "Heavy", "Rival never used a heavy blow")
check(DuelistBrain.decide(view({ FoeLow = true }), 0.5) == "Light", "Rival did not press a low foe")
check(DuelistBrain.decide(view({ FoeBlocking = true }), 0.6) == "Heavy", "Raised guard did not invite a heavy")
check(DuelistBrain.decide(view({ NextAttack = 20 }), 0.9) == "Strafe", "Rival stood still between attacks")
check(DuelistBrain.decide(view({ NextAttack = 20 }), 0.3) == "Guard", "Rival stayed open between its attacks")
check(DuelistBrain.decide(view({ NextAttack = 20, Distance = 15 }), 0.3) ~= "Guard", "Rival turtled from across the arena")
-- Picking among its three surges.
local bolt = { Name = "Bolt", Kind = "Bolt", Power = 1.4, Next = 0 }
local blast = { Name = "Blast", Kind = "Nova", Radius = 7, Power = 1.3, Next = 0 }
local shield = { Name = "Shield", Kind = "Self", Power = 1, Next = 0 }
local ring = { Name = "Ring", Kind = "Nova", SelfCentered = true, Radius = 8, Power = 0.5, Next = 0 }
local array = { bolt, blast, shield }
check(DuelistBrain.pickSurge(array, 10, 15, view()) == bolt, "Rival did not bolt from range")
check(DuelistBrain.pickSurge(array, 10, 15, view({ FoeBlocking = true })) == blast, "Rival did not blast a turtling foe")
check(DuelistBrain.pickSurge({ shield }, 10, 15, view({ HealthRatio = 0.4 })) == shield, "Hurt rival never shielded")
check(DuelistBrain.pickSurge({ shield }, 10, 15, view()) == nil, "Healthy rival wasted a shield at range")
check(DuelistBrain.pickSurge({ ring }, 10, 15, view()) == nil, "Self-centred blast cast out of reach")
check(DuelistBrain.pickSurge({ ring }, 10, 5, view()) == ring, "Self-centred blast unused up close")
bolt.Next = 20
check(DuelistBrain.pickSurge({ bolt }, 10, 15, view()) == nil, "Surge used on cooldown")
-- Using its Rig Maneuvers (1, 2, 3) like a player.
local slam = { Id = "HydraulicSlam", Power = 1.8, Next = 0 }
local hammer = { Id = "BreachHammer", Power = 2.5, Windup = 1, Next = 0 }
local stim = { Id = "StimDodge", Power = 0, Next = 0 }
local ram = { Id = "KineticRam", Power = 1.2, Next = 0 }
local moves = { slam, hammer, stim, ram }
check(DuelistBrain.pickMove(moves, "Dodge", 10, 4, 0.9) == stim, "Rival dodged without its Stim Dodge")
check(DuelistBrain.pickMove(moves, "Lunge", 10, 12, 0.9) == ram, "Rival lunged without its Kinetic Ram")
check(DuelistBrain.pickMove(moves, "Light", 10, 4, 0.1) == slam, "Quick swing swapped for a slow wind-up")
check(DuelistBrain.pickMove(moves, "Heavy", 10, 4, 0.1) == hammer, "Heavy never used its strongest maneuver")
check(DuelistBrain.pickMove(moves, "Light", 10, 4, 0.9) == nil, "Rival used a maneuver on every swing")
-- The counters: a jab for a cast in reach, a leap to close in, a brace instead of a guard.
local jab = { Id = "PneumaticJab", Power = 0.6, Next = 0 }
local leap = { Id = "ThrusterLeap", Power = 1.1, Windup = 0.4, Next = 0 }
local riposte = { Id = "RiposteStance", Power = 0, Next = 0 }
local counters = { jab, leap, riposte, ram }
check(DuelistBrain.pickMove(counters, "Interrupt", 10, 4, 0.5) == jab, "Rival didn't jab a cast in reach")
check(DuelistBrain.pickMove(counters, "Interrupt", 10, 20, 0.5) == nil, "Rival jabbed a cast out of reach")
check(DuelistBrain.pickMove(counters, "Lunge", 10, 14, 0.9) == leap, "Rival closed in without its Thruster Leap")
check(DuelistBrain.pickMove(counters, "Guard", 10, 4, 0.1) == riposte, "Rival never braced in Riposte Stance")
check(DuelistBrain.pickMove(counters, "Guard", 10, 4, 0.9) == nil, "Rival braced instead of every guard")
check(DuelistBrain.pickMove(counters, "Light", 10, 4, 0.1) ~= jab and DuelistBrain.pickMove(counters, "Light", 10, 4, 0.1) ~= riposte, "Rival wasted a counter on a plain swing")
slam.Next, hammer.Next, ram.Next = 20, 20, 20
check(DuelistBrain.pickMove(moves, "Light", 10, 4, 0.1) == nil, "Maneuver used on cooldown")
-- Its blows meet the player's guard like any monster's: quick ones are
-- reduced, heavy ones break it.
local guardian, gh, gr = makePlayer(31, arena, nil)
local rival = { Root = { Position = gr.Position + Vector3.new(0, 0, -4) } }
now += 5
CombatServer._block(guardian, true, rival.Root.Position)
now += 0.5 -- past the parry window
local before = gh.Health
CombatServer.hurt(guardian, 100, nil, rival, false)
check(gh.Health > before - 100 and guardian:GetAttribute("Blocking") == true, "Guard did not reduce a rival's quick swing")
CombatServer._block(guardian, true, rival.Root.Position)
CombatServer.hurt(guardian, 100, nil, rival, true)
check(guardian:GetAttribute("Blocking") == false, "Rival's heavy blow did not break the guard")
-- Guard replication is immediate, not dependent on the next resource tick.
now += 5
CombatServer._block(guardian, true, rival.Root.Position)
check((guardian.Character:GetAttribute("GuardUntil") or 0) > workspace:GetServerTimeNow(), "Remote guard was not published immediately")
check(guardian.Character:GetAttribute("ActionKind") == nil, "A stale action survived raising guard")
CombatServer._block(guardian, false, rival.Root.Position)
check(guardian.Character:GetAttribute("GuardUntil") == 0, "Remote guard remained up after release")
-- Long held casts and charging poses must not mask an active shield.
for _, kind in { "Slash", "Heavy", "Bolt", "Nova" } do
 local guard = RivalPose.pose({ ActionKind=kind, ActionStart=100, ActionAt=103, ActionHold=105, GuardUntil=102 }, 101, true)
 check(guard.LeftShoulder[1] > 2 and guard.LeftShoulder[3] > 1, "Stale " .. kind .. " masked shield guard")
 check(guard.RightShoulder[1] < 0.5, "Guard did not lower the sword")
end
-- Its body language: wind-up, strike, then back to a ready stance.
local swing = { ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = 1 }
local windup = RivalPose.pose(swing, 100.25)
local strike, snap = RivalPose.pose(swing, 100.35)
local after = RivalPose.pose(swing, 101.5)
check(windup.Waist[2] < -0.4 and windup.RightElbow[1] > 1.5, "Slash wind-up did not coil the hips and cock the sword")
check(strike.Waist[2] > 0.4 and snap >= 25, "Slash did not whip across")
check(after.RightShoulder[1] < 1 and after.RightElbow[1] < 1, "Rival stayed frozen after a slash")
local mirrored = RivalPose.pose({ ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = -1 }, 100.35)
check(mirrored.Waist[2] < -0.4, "Combo swings did not alternate")
local heavy = RivalPose.pose({ ActionKind = "Heavy", ActionStart = 100, ActionAt = 100.75 }, 100.6)
check(heavy.RightShoulder[1] > 2, "Heavy wind-up was not overhead")
check(heavy.LeftShoulder[1] > 2 and heavy.LeftShoulder[3] > 1, "Heavy flung the shield away instead of keeping it up")
local twoHanded = RivalPose.pose({ ActionKind = "Heavy", ActionStart = 100, ActionAt = 100.75, WeaponBlock = true }, 100.6)
check(twoHanded.LeftShoulder[1] > 2.5 and twoHanded.RightShoulder[1] > 2.5, "Two-handed heavy wind-up was not overhead")
check(windup.LeftShoulder[1] > 2 and strike.LeftShoulder[1] > 2, "Slash let the shield drop from in front")
check(RivalPose.pose({ ActionKind = "Nova", ActionStart = 100, ActionAt = 100.9 }, 100.95).RightKnee[1] < 0, "Blast did not slam down")
-- A held beam keeps its cast pose while it pours, for the rival and players alike.
local beam = { ActionKind = "Bolt", ActionStart = 100, ActionAt = 100.4, ActionHold = 102 }
check(RivalPose.pose(beam, 101.5).RightShoulder[1] > 1.5 and RivalPose.pose(beam, 101.5, true).RightShoulder[1] > 1.5, "Beam pose not held")
beam.ActionHold = nil
check(RivalPose.pose(beam, 101.5, true).RightShoulder == nil or RivalPose.pose(beam, 101.5, true).RightShoulder[1] < 1.5, "Cast pose stuck after release")
check(RivalPose.pose({ ActionKind = "Bolt", ActionStart = 100, ActionAt = 100.45 }, 100.5).RightElbow[1] < 0.3, "Bolt did not thrust the arm")
check(RivalPose.pose({ ActionKind = "Buff", ActionStart = 100, ActionAt = 100.15 }, 100.4).LeftShoulder[1] > 1.5, "Buff did not raise the hands")
check(RivalPose.pose({ ActionKind = "Dodge", ActionStart = 100, ActionAt = 100 }, 100.2).RightKnee[1] < -1, "Dodge did not tuck")
check(RivalPose.pose({ ActionKind = "Stagger", ActionStart = 100, ActionAt = 100 }, 100.2).Waist[1] > 0.3, "Stagger did not rock back")
check(RivalPose.pose({ GuardUntil = 101 }, 100.5).LeftShoulder[1] > 2 and RivalPose.pose({ GuardUntil = 101 }, 100.5).LeftShoulder[3] > 1, "Guard did not raise the shield")
check(RivalPose.pose({ GuardUntil = 101 }, 101.5).LeftShoulder[1] < 1.5, "Guard pose stuck after it dropped")
check(RivalPose.pose({ ActionKind = "Bogus", ActionStart = 100, ActionAt = 100 }, 100).RightShoulder ~= nil, "Unknown action broke the pose")
-- Anticipation, overshoot, recovery and hit reactions.
local coil = RivalPose.pose(swing, 100.29)
check(coil.Waist[2] < windup.Waist[2], "Slash did not coil past its wind-up before release")
local snapped = RivalPose.pose(swing, 100.37)
check(snapped.Waist[2] > 0.75, "Slash did not overshoot its strike")
local recovering = RivalPose.pose(swing, 100.3 + 0.32 + 0.15)
check(recovering.Waist[2] > 0 and recovering.Waist[2] < 0.7, "Slash snapped back instead of recovering")
local stance1, stance2 = RivalPose.pose({}, 10), RivalPose.pose({}, 10.6)
check(stance1.Waist[1] ~= stance2.Waist[1], "Stance does not breathe")
check(RivalPose.pose({}, 10, true).Waist == nil, "A player's own idle was overridden")
local flinch = RivalPose.pose({ HurtAt = 100 }, 100.06, true)
check(flinch.Waist and flinch.Waist[1] > 0.2 and flinch.Neck[1] > 0.2, "Hit did not flinch")
check(RivalPose.pose({ HurtAt = 100 }, 100.5, true).Waist == nil, "Flinch did not fade")
local jolt = RivalPose.pose({ GuardUntil = 101, BlockedAt = 100 }, 100.05)
check(jolt.LeftShoulder[1] < RivalPose.pose({ GuardUntil = 101 }, 100.05).LeftShoulder[1], "Blocked blow did not jolt the shield")
-- Cast silhouettes brace their legs and recover; every style is finite across release.
for _, kind in { "Bolt", "Drill", "Sweep", "Nova", "Erupt", "Cross", "Buff" } do
 local attrs = { ActionKind=kind, ActionStart=100, ActionAt=100.7 }
 local coiled = RivalPose.pose(attrs, 100.65, true)
 check(coiled.RightKnee and coiled.RightKnee[1] < 0, kind .. " lacks a braced wind-up")
 for _, time in { 100, 100.35, 100.699, 100.7, 100.74, 100.82, 101, 101.4 } do
  local pose = RivalPose.pose(attrs, time, true)
  for _, angles in pose do
   for _, angle in angles do check(angle == angle and math.abs(angle) < 4, kind .. " has an invalid joint angle") end
  end
 end
 check(next((RivalPose.pose(attrs, 102, true))) == nil, kind .. " failed to return to idle")
end
-- Tung Tung shares the exact fighter attack/reaction timing, with a bat guard.
for _,kind in {"Slash","Heavy","Bolt","Nova","Buff","Dodge","Stagger"} do
 for _,offset in {0,.15,.29,.35,.6,.95,1.5} do
  local attrs={ActionKind=kind,ActionStart=100,ActionAt=100.3,ActionSide=-1}
  local normal,normalSpeed=RivalPose.pose(attrs,100+offset)
  attrs.CombatPoseProfile="SahurBat"
  local sahur,sahurSpeed=RivalPose.pose(attrs,100+offset)
  check(sahurSpeed==normalSpeed,"Sahur action response diverged from combat timing")
  for joint,angles in normal do
   for axis=1,3 do check(math.abs(sahur[joint][axis]-angles[axis])<1e-8,"Sahur attack diverged: "..kind.." / "..joint) end
  end
 end
end
local batGuard={CombatPoseProfile="SahurBat",GuardUntil=101}
local braced=RivalPose.pose(batGuard,100.05)
check(braced.RightShoulder[1]>1.2 and braced.RightShoulder[3]<-.4,"Sahur failed to brace his bat")
batGuard.BlockedAt=100
local batJolt=RivalPose.pose(batGuard,100.05)
check(batJolt.RightShoulder[1]<braced.RightShoulder[1],"Blocked blow did not recoil Sahur's bat")
check(RivalPose.pose(batGuard,102).RightShoulder[1]<1,"Sahur stayed in guard after expiry")
local sahurHurt=RivalPose.pose({CombatPoseProfile="SahurBat",HurtAt=100},100.06)
check(sahurHurt.Waist[1]>0.15,"Sahur timber body did not flinch")
-- Health recovery is the same for everyone: none mid-fight in the Arena.
check(HealthRegen.amount(50, 100, true, 60, 1) == 0, "Player healed during an Arena fight")
check(HealthRegen.amount(50, 100, false, 2, 1) == 0, "Player healed right after taking damage")
check(HealthRegen.amount(50, 100, false, 6, 1) == 1, "Player never recovered out of combat")
check(HealthRegen.amount(99.5, 100, false, 6, 1) == 0.5, "Recovery overfilled health")
check(HealthRegen.amount(0, 100, false, 60, 1) == 0, "A fallen player recovered")
-- Status effects: what a fighter is suffering from, shown like an RPG's.
local encoded = StatusEffects.encode({
	{ Id = "Slowed", Ends = 20, Value = 30 },
	{ Id = "Burning", Ends = 15, Value = 0 },
	{ Id = "Burning", Ends = 18, Value = 0 },
	{ Id = "Shielded", Ends = 12, Value = 24 },
	{ Id = "Stunned", Ends = 5, Value = 0 },
	{ Id = "Nonsense", Ends = 30, Value = 1 },
}, 10)
local decoded = StatusEffects.decode(encoded)
check(#decoded == 3, "Status list kept expired, unknown or repeated effects: " .. encoded)
check(decoded[1].Id == "Shielded" and decoded[2].Id == "Burning" and decoded[3].Id == "Slowed", "Statuses out of order: " .. encoded)
check(decoded[2].Ends == 18 and decoded[3].Value == 30, "Status timing or strength lost: " .. encoded)
check(StatusEffects.label("Slowed") == "Slowed (Cryo)" and StatusEffects.label("Burning") == "Burning (Thermal)", "Status labels missing their element")
check(StatusEffects.describe("Slowed", 30) == "Moves 30% slower.", "Status description wrong")
check(#StatusEffects.decode(nil) == 0 and #StatusEffects.decode("") == 0, "Empty status list broke decoding")
-- The rival's gem afflicts the player like a player's gem would, and the
-- player's status bar shows it.
local struck, sh = makePlayer(41, arena, nil)
local brute = { Alive = true, Root = { Position = arena } }
now += 30
CombatServer.enemyProc(struck, { Element = "Frost", Size = 5, Clarity = 5, Cut = 5 }, brute)
CombatServer.enemyProc(struck, { Element = "Fire", Size = 5, Clarity = 5, Cut = 5 }, brute)
CombatServer.enemyProc(struck, { Element = "Poison", Size = 5, Clarity = 5, Cut = 5 }, brute)
CombatServer._tick(0.1)
local shown = {}
for _, active in StatusEffects.decode(struck:GetAttribute("Statuses")) do
	shown[active.Id] = active
end
check(shown.Slowed and shown.Slowed.Value > 0, "Cryo hit did not show Slowed: " .. tostring(struck:GetAttribute("Statuses")))
check(shown.Burning ~= nil, "Thermal hit did not show Burning")
check(shown.ArmorShred ~= nil, "Corrosive hit did not show Armor Shred")
local before = sh.Health
now += 1.2
CombatServer._tick(1.2)
check(sh.Health < before, "A rival's burn never hurt the player")
brute.Alive = false
now += 0.1
CombatServer._tick(0.1)
check(not string.find(struck:GetAttribute("Statuses") or "", "Burning", 1, true), "Burn outlived the rival that set it")
-- The combat log: what hit you, with what, for how much, and how much your
-- guard and shields stopped.
local logged, lh, lr = makePlayer(51, arena, nil)
local kade = { Alive = true, Root = { Position = lr.Position + Vector3.new(0, 0, -4) }, Model = { Name = "Rival", GetAttribute = function(_, key) return if key == "RivalName" then "Kade Vorn" else nil end } }
local function lastLog(player)
	for i = #messages, 1, -1 do
		local m = messages[i]
		if m.Player == player and m[1] == "Log" then
			return m[2]
		end
	end
	return nil
end
now += 20
local previous = DamageLog.push("Heavy Blow", "Fire")
CombatServer.hurt(logged, 50, "Fire", kade, false)
DamageLog.pop(previous)
local entry = lastLog(logged)
check(entry ~= nil and entry.Dir == "In" and entry.Kind == "Hit", "A rival's hit was not logged")
check(entry.Who == "Kade Vorn" and entry.Ability == "Heavy Blow" and entry.Element == "Fire", "Log lost who or what hit you")
check(entry.Amount > 0 and entry.Amount <= 50, "Log amount wrong: " .. tostring(entry.Amount))
CombatServer._block(logged, true, kade.Root.Position)
now += 0.5
CombatServer.hurt(logged, 50, nil, kade, false)
entry = lastLog(logged)
check(entry.Blocked and entry.Blocked > 0, "Log did not show what the guard blocked")
CombatServer._block(logged, false, kade.Root.Position)
check(DamageLog.context() == nil, "Ability context leaked")
CombatServer.heal(logged, 10)
entry = lastLog(logged)
check(entry.Kind == "Heal" and entry.Amount > 0, "A heal was not logged")
-- The log's lines and the fight details.
local function plain(text) return (text:gsub("<[^>]+>", "")) end
check(plain(CombatLogUI.format({ Dir = "Out", Kind = "Hit", Who = "Kade Vorn", Ability = "Swing", Amount = 24, Crit = true })) == "Your Swing hits Kade Vorn for 24 (critical)", "Outgoing hit line wrong")
check(plain(CombatLogUI.format({ Dir = "In", Kind = "Hit", Who = "Kade Vorn", Ability = "Heavy Blow", Amount = 12, Blocked = 29, GuardBroken = true })) == "Kade Vorn's Heavy Blow hits you for 12 (29 blocked) GUARD BROKEN!", "Incoming hit line wrong")
check(plain(CombatLogUI.format({ Dir = "In", Kind = "Hit", Ability = "Burning", Amount = 6 })) == "Burning hits you for 6", "Burn tick line wrong")
check(plain(CombatLogUI.format({ Dir = "Foe", Kind = "Heal", Who = "Kade Vorn", Ability = "Energy Siphon", Amount = 50, Blocked = 22 })) == "Kade Vorn's Energy Siphon heals it for 50 (22 prevented)", "Rival heal line wrong")
check(plain(CombatLogUI.format({ Kind = "Status", Dir = "Foe", Who = "Kade Vorn", Status = "Slowed", Value = 30 })) == "Kade Vorn is Slowed (Cryo) 30%", "Status line wrong")
check(plain(CombatLogUI.format({ Dir = "Out", Kind = "Hit", Who = "A<b>", Amount = 1 })):find("A&lt;b&gt;", 1, true) ~= nil, "Names not escaped for RichText")
local fight = CombatLogUI.newStats(0)
CombatLogUI.tally(fight, { Dir = "Out", Kind = "Hit", Ability = "Swing", Amount = 20 }, 1)
CombatLogUI.tally(fight, { Dir = "Out", Kind = "Hit", Ability = "Swing", Amount = 40, Crit = true }, 2)
CombatLogUI.tally(fight, { Dir = "Out", Kind = "Hit", Ability = "Solar Flare", Amount = 90 }, 3)
CombatLogUI.tally(fight, { Dir = "In", Kind = "Hit", Who = "Kade", Ability = "Heavy Blow", Amount = 30, Blocked = 70, Absorbed = 10 }, 4)
CombatLogUI.tally(fight, { Dir = "In", Kind = "Dodge", Who = "Kade" }, 4)
CombatLogUI.tally(fight, { Dir = "Foe", Kind = "Heal", Amount = 15 }, 5)
local doneRows = CombatLogUI.rows(fight.Done)
check(fight.Done.Total == 150 and fight.Done.Hits == 3 and fight.Done.Crits == 1 and fight.Done.Biggest == 90, "Damage done tally wrong")
check(doneRows[1].Name == "Solar Flare" and math.abs(doneRows[1].Share - 0.6) < 1e-6 and doneRows[2].Total == 60, "Per-ability breakdown wrong")
check(fight.Taken.Total == 30 and fight.Taken.Blocked == 70 and fight.Taken.Absorbed == 10 and fight.Taken.Dodged == 1, "Damage taken tally wrong")
check(fight.FoeHealed == 15 and fight.Last == 5, "Healing or fight time not tracked")
-- Dodging like a fighting game: tap Space to hop, double-tap to roll.
check(Actions.dodgeKind(nil, 5) == "Hop" and Actions.dodgeKind(4.8, 5) == "Roll" and Actions.dodgeKind(4, 5) == "Hop", "Tap timing wrong")
check(Actions.validInput("Dodge", Vector3.new(1, 0, 0), "Hop") and Actions.validInput("Dodge", Vector3.new(1, 0, 0), "Roll") and not Actions.validInput("Dodge", Vector3.new(1, 0, 0), "Fly"), "Dodge kinds not validated")
local hopper, hh, hr = makePlayer(61, arena, nil)
now += 30
CombatServer._tick(0.1)
local hst = CombatServer._state(hopper)
CombatServer._dodge(hopper, Vector3.new(1, 0, 0), "Hop")
check(hst.DodgeKind == "Hop" and hst.DodgeMove and hst.DodgeMove.Kind == "Hop", "Tap did not hop")
check(Actions.invulnerable(hst.DodgeStarted, now + 0.2, { Invincible = 0.5, PvPInvincible = 0.3 }, false, "Hop"), "Hop had no dodge window")
check(not Actions.invulnerable(hst.DodgeStarted, now + 0.35, { Invincible = 0.5, PvPInvincible = 0.3 }, false, "Hop"), "Hop dodge window as long as a roll")
local hopStamina = hst.Resources.Stamina
now += 0.05
CombatServer._dodge(hopper, Vector3.new(1, 0, 0), "Roll")
check(hst.DodgeKind == "Roll" and hst.DodgeMove.Kind == "Roll", "Double tap did not chain the hop into a roll")
check(hst.Resources.Stamina < hopStamina, "Roll was free")
now += 0.05
CombatServer._dodge(hopper, Vector3.new(1, 0, 0), "Hop")
check(hst.DodgeMove.Kind == "Roll", "A hop cut a roll short")
now += 0.7
CombatServer._tick(0.7)
check(not CombatServer._dodge(hopper, Vector3.new(1, 0, 0), "Roll"), "Roll ignored its cooldown")
CombatServer._dodge(hopper, Vector3.new(1, 0, 0), "Hop")
check(hst.DodgeKind == "Hop" and hst.DodgeStarted == now, "Hop blocked by the roll's cooldown")
-- A bolt aimed where you stood misses once you've stepped aside.
check(DuelistBrain.boltHits(Vector3.new(0, 0, 0), Vector3.new(2, 3, 1)), "Bolt missed a player standing still")
check(not DuelistBrain.boltHits(Vector3.new(0, 0, 0), Vector3.new(6, 0, 0)), "Bolt hit a player who hopped aside")
check(DuelistBrain.Windup.Bolt >= 0.6, "Bolt too fast to react to")
-- The matchup: real numbers and both sides' strengths and weaknesses.
local m = Matchup.build(
	{ Name = "You", Health = 300, Hit = 20, Speed = 16, Element = "Frost", Surges = {}, Moves = { "HydraulicSlam" } },
	{ Name = "Kade", Health = 400, Hit = 30, Speed = 18, Element = "Fire",
		Surges = { { Id = "EnergySiphon", Name = "Energy Siphon", Kind = "Self" }, { Id = "SolarFlare", Name = "Solar Flare", Kind = "Bolt" } },
		Moves = { "StimDodge" } }
)
check(m.Rows[3].Stat == "Hits to win" and m.Rows[3].You == 20 and m.Rows[3].Foe == 10 and m.Rows[3].Better == "Foe", "Hits-to-win row wrong")
check(m.Rows[1].Better == "Foe" and m.Rows[4].Better == "Foe", "Better stat not marked")
local function anyFind(list, word) for _, line in list do if string.find(line, word, 1, true) then return true end end return false end
check(anyFind(m.FoeEdges, "Wins the trade") and anyFind(m.FoeEdges, "Tougher"), "Rival's edges missing: " .. table.concat(m.FoeEdges, " | "))
check(anyFind(m.FoeWeak, "Heals itself") and anyFind(m.FoeWeak, "Solar Flare"), "Rival's weaknesses missing: " .. table.concat(m.FoeWeak, " | "))
check(anyFind(m.YourEdges, "Cryo"), "Your element edge missing")
check(#m.YourWeak > 0 and #m.FoeEdges <= 4 and #m.FoeWeak <= 4, "Edge lists not capped or empty")
local thermal = Matchup.build({ Health = 300, Hit = 40, Speed = 20, Element = "Fire", Surges = {}, Moves = {} },
	{ Health = 250, Hit = 15, Speed = 18, Element = "Shock", Surges = { { Id = "EnergySiphon", Name = "Energy Siphon", Kind = "Self" } }, Moves = {} })
check(anyFind(thermal.YourEdges, "cuts its healing") and anyFind(thermal.YourEdges, "win the trade"), "Your edges missing: " .. table.concat(thermal.YourEdges, " | "))
check(anyFind(thermal.FoeWeak, "Fragile"), "Rival's low health not called out")
-- Ground blasts: wide, and harder the closer to the centre.
check(math.abs(Actions.blastRadius(7) - 11.2) < 1e-6 and Actions.blastRadius(3) == 9 and Actions.blastRadius(20) == 15, "Blast radius scaling")
do
	local scale, cc, seconds = Actions.blastFalloff(0, 12)
	check(scale == 1 and cc == "Stunned" and math.abs(seconds - 1.3) < 1e-6, "Blast centre: full damage and a stun")
	local s2, cc2, sec2 = Actions.blastFalloff(6, 12)
	check(s2 < scale and cc2 == "Staggered" and sec2 > 0.25 and sec2 < 0.55, "Blast middle: less damage, a stagger")
	local s3, cc3 = Actions.blastFalloff(11, 12)
	check(s3 < s2 and s3 >= Actions.Blast.EdgeDamage and cc3 == nil, "Blast edge: a graze, no stagger")
	local _, _, near = Actions.blastFalloff(1, 12)
	local _, _, far = Actions.blastFalloff(4, 12)
	check(near > far, "A stun nearer the centre lasts longer")
	check(StatusEffects.Catalog.Staggered ~= nil, "Staggered status missing")
end
print("PASS: " .. checks .. " Duelist checks (matchup, hop and roll, dodgeable bolts, combat log lines and details, server log, status effects, health recovery, decisions, reads, punishes, lunges, three-surge choice, maneuvers, guard, dodge, heavy vs guard, poses)")

-- Sword elbows bend as hinges instead of twisting a quarter-turn sideways.
do
 for _,kind in {"Slash","Heavy"} do
  for _,side in {-1,1} do
   for i=0,90 do
    local pose=RivalPose.pose({ActionKind=kind,ActionStart=100,ActionAt=100.35,ActionSide=side},100+i/60,true)
    local elbow=pose.RightElbow
    if elbow then
     check(math.abs(elbow[2])<0.01,"Sword elbow must not twist sideways")
     check(elbow[1]>-0.25 and elbow[1]<2.2,"Sword elbow exceeded its recovery range")
    end
   end
  end
 end
 local idle=RivalPose.pose({ActionKind="Slash",ActionStart=100,ActionAt=100.35},105,true)
 check(next(idle)==nil,"Expired combat pose must release the lobby body")
 print("PASS: sword hinge limits and lobby pose recovery")
end
