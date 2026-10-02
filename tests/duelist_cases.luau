-- The PvP Duelist: its decisions (Shared.DuelistBrain) and how its hits meet a guard.
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local base = {
	Now = 10, Distance = 4, HealthRatio = 1, Stunned = false, FoeCharging = false, FoeBlocking = false,
	NextAttack = 0, NextSurge = 99, NextDefense = 0, NextRetreat = 99,
}
local function view(changes)
	local v = table.clone(base)
	for key, value in changes or {} do v[key] = value end
	return v
end
check(DuelistBrain.decide(view({ Stunned = true }), 0.1) == "Stagger", "Stunned rival acted")
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.1) == "Guard", "Rival ignored a charging swing (guard)")
check(DuelistBrain.decide(view({ FoeCharging = true }), 0.6) == "Dodge", "Rival ignored a charging swing (dodge)")
check(DuelistBrain.decide(view({ FoeCharging = true, NextDefense = 20 }), 0.1) ~= "Guard", "Rival guarded on every swing")
check(DuelistBrain.decide(view({ Distance = 15, NextSurge = 0 }), 0.5) == "Surge", "Rival never cast from range")
check(DuelistBrain.decide(view({ Distance = 3, NextSurge = 0 }), 0.5) ~= "Surge", "Rival cast its surge point-blank")
check(DuelistBrain.decide(view({ Distance = 15 }), 0.5) == "Approach", "Rival did not close in")
check(DuelistBrain.decide(view({ HealthRatio = 0.2, NextRetreat = 0 }), 0.5) == "Retreat", "Hurt rival never backed off")
check(DuelistBrain.decide(view(), 0.5) == "Light", "Rival in reach did not swing")
check(DuelistBrain.decide(view(), 0.1) == "Heavy", "Rival never used a heavy blow")
check(DuelistBrain.decide(view({ FoeBlocking = true }), 0.6) == "Heavy", "Raised guard did not invite a heavy")
check(DuelistBrain.decide(view({ NextAttack = 20 }), 0.5) == "Strafe", "Rival stood still between attacks")
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
print("PASS: " .. checks .. " Duelist checks (decisions, guard, dodge, surge range, retreat, heavy vs guard)")
