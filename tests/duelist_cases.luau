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
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.6) == "Dodge", "Rival ignored a charging swing (dodge)")
check(DuelistBrain.decide(view({ FoeCasting = true }), 0.6) == "Dodge", "Rival ignored a surge wind-up")
check(DuelistBrain.decide(view({ FoeRecovering = true, NextAttack = 20 }), 0.9) == "Punish", "Rival missed an opening")
check(DuelistBrain.decide(view({ Distance = 4, NextSurge = 0, FoeVulnerable = true }), 0.9) == "Surge", "Rival wasted a stunned target")
check(DuelistBrain.decide(view({ Distance = 4, NextSurge = 0, FoeBlocking = true }), 0.9) == "Surge", "Rival let a turtle hide")
check(DuelistBrain.decide(view({ Distance = 12, NextLunge = 0 }), 0.9) == "Lunge", "Rival never lunged in")
check(DuelistBrain.decide(view({ HealthRatio = 0.2, NextRetreat = 0, FoeLow = true }), 0.5) ~= "Retreat", "Rival retreated from a low foe")
check(DuelistBrain.decide(view({ FoeCharging = true, NextDefense = 20 }), 0.1) ~= "Guard", "Rival guarded on every swing")
check(DuelistBrain.decide(view({ Distance = 15, NextSurge = 0 }), 0.5) == "Surge", "Rival never cast from range")
check(DuelistBrain.decide(view({ Distance = 3, NextSurge = 0 }), 0.5) ~= "Surge", "Rival cast its surge point-blank")
check(DuelistBrain.decide(view({ Distance = 15 }), 0.5) == "Approach", "Rival did not close in")
check(DuelistBrain.decide(view({ HealthRatio = 0.2, NextRetreat = 0 }), 0.5) == "Retreat", "Hurt rival never backed off")
check(DuelistBrain.decide(view(), 0.5) == "Light", "Rival in reach did not swing")
check(DuelistBrain.decide(view(), 0.1) == "Heavy", "Rival never used a heavy blow")
check(DuelistBrain.decide(view({ FoeLow = true }), 0.5) == "Light", "Rival did not press a low foe")
check(DuelistBrain.decide(view({ FoeBlocking = true }), 0.6) == "Heavy", "Raised guard did not invite a heavy")
check(DuelistBrain.decide(view({ NextAttack = 20 }), 0.5) == "Strafe", "Rival stood still between attacks")
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
-- Its body language: wind-up, strike, then back to a ready stance.
local swing = { ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = 1 }
local windup = RivalPose.pose(swing, 100.25)
local strike, snap = RivalPose.pose(swing, 100.35)
local after = RivalPose.pose(swing, 101.5)
check(windup.RightShoulder[1] > 1.5, "Slash wind-up did not raise the sword arm")
check(strike.RightShoulder[3] < 0 and snap >= 25, "Slash did not whip across")
check(after.RightShoulder[1] < 1 and after.Waist == nil, "Rival stayed frozen after a slash")
local mirrored = RivalPose.pose({ ActionKind = "Slash", ActionStart = 100, ActionAt = 100.3, ActionSide = -1 }, 100.35)
check(mirrored.RightShoulder[3] > 0, "Combo swings did not alternate")
local heavy = RivalPose.pose({ ActionKind = "Heavy", ActionStart = 100, ActionAt = 100.75 }, 100.6)
check(heavy.LeftShoulder[1] > 2.5 and heavy.RightShoulder[1] > 2.5, "Heavy wind-up was not overhead")
check(RivalPose.pose({ ActionKind = "Nova", ActionStart = 100, ActionAt = 100.9 }, 100.95).RightKnee[1] < 0, "Blast did not slam down")
check(RivalPose.pose({ ActionKind = "Bolt", ActionStart = 100, ActionAt = 100.45 }, 100.5).RightElbow[1] < 0.3, "Bolt did not thrust the arm")
check(RivalPose.pose({ ActionKind = "Buff", ActionStart = 100, ActionAt = 100.15 }, 100.4).LeftShoulder[3] < -1, "Buff did not spread the arms")
check(RivalPose.pose({ ActionKind = "Dodge", ActionStart = 100, ActionAt = 100 }, 100.2).RightKnee[1] < -1, "Dodge did not tuck")
check(RivalPose.pose({ ActionKind = "Stagger", ActionStart = 100, ActionAt = 100 }, 100.2).Waist[1] > 0.3, "Stagger did not rock back")
check(RivalPose.pose({ GuardUntil = 101 }, 100.5).RightElbow[1] > 1.5, "Guard did not raise the forearms")
check(RivalPose.pose({ GuardUntil = 101 }, 101.5).Waist == nil, "Guard pose stuck after it dropped")
check(RivalPose.pose({ ActionKind = "Bogus", ActionStart = 100, ActionAt = 100 }, 100).RightShoulder ~= nil, "Unknown action broke the pose")
-- Health recovery is the same for everyone: none mid-fight in the Arena.
check(HealthRegen.amount(50, 100, true, 60, 1) == 0, "Player healed during an Arena fight")
check(HealthRegen.amount(50, 100, false, 2, 1) == 0, "Player healed right after taking damage")
check(HealthRegen.amount(50, 100, false, 6, 1) == 1, "Player never recovered out of combat")
check(HealthRegen.amount(99.5, 100, false, 6, 1) == 0.5, "Recovery overfilled health")
check(HealthRegen.amount(0, 100, false, 60, 1) == 0, "A fallen player recovered")
print("PASS: " .. checks .. " Duelist checks (health recovery, decisions, reads, punishes, lunges, three-surge choice, maneuvers, guard, dodge, heavy vs guard, poses)")
