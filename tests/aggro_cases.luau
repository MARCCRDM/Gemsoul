local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function c(key, threat, distance, inReach, health)
	return {
		Key = key,
		Threat = threat,
		Distance = distance or 5,
		InReach = inReach ~= false,
		HealthRatio = health or 1,
	}
end
-- Biggest threat wins a fresh target; nobody hurt it yet: the nearest.
local s = Aggro.new()
check(Aggro.choose(s, { c("near", 0, 3), c("far", 0, 20, false) }, 0) == "near", "No threat: nearest not chosen")
s = Aggro.new()
check(Aggro.choose(s, { c("tank", 50, 3), c("dps", 120, 20, false) }, 0) == "dps", "Most damage not chosen")
-- Held briefly, then overtaken only by the margin (10% in reach, 30% at range).
s = Aggro.new()
check(Aggro.choose(s, { c("a", 100), c("b", 50) }, 0) == "a", "Top threat not taken")
check(Aggro.choose(s, { c("a", 100), c("b", 200) }, 1) == "a", "Switched inside the hold")
check(Aggro.choose(s, { c("a", 100), c("b", 105) }, 2) == "a", "Switched under the 10% margin")
check(Aggro.choose(s, { c("a", 100), c("b", 115) }, 2.1) == "b", "Melee player 15% ahead didn't take it")
s = Aggro.new()
Aggro.choose(s, { c("a", 100) }, 0)
check(Aggro.choose(s, { c("a", 100), c("b", 125, 30, false) }, 2) == "a", "Ranged player took it under 30%")
check(Aggro.choose(s, { c("a", 100), c("b", 135, 30, false) }, 2.1) == "b", "Ranged player 35% ahead didn't take it")
-- Smelling blood: a player under 25% health counts 1.3x.
s = Aggro.new()
Aggro.choose(s, { c("a", 100) }, 0)
check(Aggro.choose(s, { c("a", 100), c("weak", 90, 5, true, 0.2) }, 2) == "weak", "Didn't turn on a weakened player")
-- Target lost: the next biggest threat at once.
check(Aggro.choose(s, { c("a", 100), c("b", 20) }, 2.2) == "a", "Lost target not replaced by top threat")
-- Out of reach too long: the nearest it can hit.
s = Aggro.new()
Aggro.choose(s, { c("kiter", 300, 30, false), c("close", 10, 4) }, 0)
check(Aggro.choose(s, { c("kiter", 300, 30, false), c("close", 10, 4) }, 2) == "kiter", "Gave up on a target too soon")
check(
	Aggro.choose(s, { c("kiter", 300, 30, false), c("close", 10, 4) }, 4.1) == "close",
	"Kept chasing an unreachable target"
)
-- Threat fades once a player stops attacking; adding refreshes it.
local threat, at = {}, {}
Aggro.add(threat, at, "a", 100, 0)
Aggro.add(threat, at, "b", 100, 9)
Aggro.fade(threat, at, 1, 10)
check(threat.a < 100 and threat.b == 100, "Fading hit the wrong player")
for t = 11, 80 do
	Aggro.fade(threat, at, 1, t)
end
check(threat.a == nil, "Old threat never faded away")
check(Aggro.choose(Aggro.new(), {}, 0) == nil, "Picked someone with no candidates")
print("PASS: " .. checks .. " aggro checks (most damage, overtake margins, hold, low health, unreachable, fading)")
