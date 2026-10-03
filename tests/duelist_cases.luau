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
print("PASS: " .. checks .. " Duelist checks (hop and roll, dodgeable bolts, combat log lines and details, server log, status effects, health recovery, decisions, reads, punishes, lunges, three-surge choice, maneuvers, guard, dodge, heavy vs guard, poses)")
