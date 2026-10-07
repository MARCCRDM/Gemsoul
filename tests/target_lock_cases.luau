local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function c(id, distance, facing, visible, allowed, priority, engaged)
	return {
		Target = id,
		Distance = distance,
		Facing = facing or 1,
		Visible = visible ~= false,
		Allowed = allowed ~= false,
		Priority = priority,
		Engaged = engaged,
	}
end
local s = Rules.new()
check(Rules.update(s, { c("far", 20), c("near", 8) }, 0, false) == "near", "Nearest visible target not selected")
check(Rules.update(s, { c("far", 2), c("near", 8) }, 0.1, false) == "far", "A nearer enemy did not take the lock")
check(Rules.update(s, { c("far", 2), c("near", 3) }, 0.15, false) == "far", "Lock flickered to an enemy barely nearer")
check(Rules.update(s, { c("near", 8, 0.8) }, 0.2, false) == "near", "Normal tracking lost retained target")
check(Rules.update(s, { c("near", 8, -0.9) }, 0.3, true) == "near", "Turning away broke the lock")
check(Rules.update(s, { c("near", 8, 1, false) }, 0.4, false) == "near", "Brief cover broke the lock")
check(Rules.update(s, { c("near", 8, 1, false) }, 3.5, false) == "near", "Lock dropped inside the cover grace")
check(
	Rules.update(s, { c("near", 8, 1, false), c("other", 12) }, 4.5, false) == "other",
	"Lock held a target hidden too long"
)
s = Rules.new()
check(Rules.update(s, { c("off-axis", 2, 0.6), c("ahead", 10) }, 0, false) == "ahead", "Acquired outside forward cone")
s = Rules.new()
check(
	Rules.update(s, { c("friend", 1, 1, true, false), c("wall", 2, 1, false), c("far", 91), c("valid", 12) }, 0, false)
		== "valid",
	"Eligibility, walls or range bypassed"
)
check(Rules.update(s, { c("valid", 130) }, 0.1, false) == "valid", "Lock dropped inside keep range")
check(Rules.update(s, { c("valid", 141) }, 0.2, false) == nil, "Out-of-range lock retained")
s = Rules.new()
check(
	Rules.update(s, { c("left", 10, 0.95), c("center", 10, 1) }, 0, false) == "center",
	"Distance tie ignored central target"
)
check(Rules.update(s, {}, 0.1, false) == nil, "Removed target retained")
check(not Rules.valid(c("bad", 0), Rules.AcquireDot), "Zero-distance target accepted")
-- Your Arena rival: taken from any angle, and it wins the lock.
s = Rules.new()
check(
	Rules.update(s, { c("monster", 5), c("rival", 30, -0.5, true, true, true) }, 0, false) == "monster",
	"Nearest enemy not chosen over a farther rival"
)
s = Rules.new()
check(Rules.update(s, { c("monster", 5) }, 0, false) == "monster", "Monster not locked")
check(
	Rules.update(s, { c("monster", 5), c("rival", 30, 0.2, true, true, true) }, 0.1, false) == "monster",
	"A farther rival took the lock from the nearest enemy"
)
check(
	Rules.update(s, { c("monster", 9), c("rival", 3, 0.2, true, true, true) }, 0.2, false) == "rival",
	"A nearer rival did not take the lock"
)
s = Rules.new()
Rules.update(s, { c("monster", 5) }, 0, false)
check(
	Rules.update(s, { c("monster", 5), c("rival", 30, 0.2, true, false, true) }, 0.2, false) == "monster",
	"Dead or ineligible rival kept the lock"
)
-- The rival is never let go for distance or cover, only when it's gone.
s = Rules.new()
check(Rules.update(s, { c("rival", 30, 1, true, true, true) }, 0, false) == "rival", "Rival not locked")
check(
	Rules.update(s, { c("rival", 300, -1, false, true, true) }, 10, false) == "rival",
	"Rival lock broke from range or cover"
)
check(
	Rules.update(s, { c("rival", 300, -1, false, true, true) }, 60, false) == "rival",
	"Rival lock timed out behind cover"
)
check(Rules.update(s, { c("monster", 3) }, 61, false) == "monster", "Lock didn't move on after the rival left")
-- Whatever attacks you is locked at once, from any angle, if you have no target.
s = Rules.new()
check(
	Rules.update(s, { c("sniper", 80, -0.9, false, true, false, true) }, 0, false) == "sniper",
	"Attacker behind you not locked"
)
s = Rules.new()
check(Rules.update(s, { c("front", 10) }, 0, false) == "front", "Front target not locked")
check(
	Rules.update(s, { c("front", 10), c("other", 5, -1, true, true, false, true) }, 0.1, false) == "other",
	"A nearer attacker didn't take the lock"
)
check(
	Rules.update(s, { c("front", 10), c("other", 5, -1, false, true, false, false) }, 0.2, false) == "other",
	"Lock dropped its target behind cover"
)
s = Rules.new()
Rules.update(s, { c("front", 10) }, 0, false)
check(
	Rules.update(s, { c("front", 10), c("behind", 5, -1, false) }, 0.1, false) == "front",
	"Locked a hidden, non-attacking enemy behind you"
)
-- Switching: cycles left to right through targets within SwitchRange, and sticks.
local function b(id, distance, bearing, priority)
	local x = c(id, distance, 1, true, true, priority)
	x.Bearing = bearing
	return x
end
s = Rules.new()
local pack = { b("left", 6, -0.6), b("mid", 4, 0), b("right", 8, 0.5), b("far", 30, 0.1) }
check(Rules.update(s, pack, 0, false) == "mid", "Nearest target not locked first")
check(#Rules.switchable(pack) == 3, "Switching counted a target outside SwitchRange")
check(Rules.switch(s, pack) == "right", "Switch didn't move to the next target to the right")
check(Rules.update(s, pack, 0.1, false) == "right", "Switched target not kept")
check(Rules.switch(s, pack) == "left", "Switch didn't wrap around")
check(Rules.switch(s, pack) == "mid", "Switch didn't cycle back")
-- Picking from the target list: a holdable target is locked and pinned; a
-- far-off or disallowed one isn't.
do
	local p = Rules.new()
	local list = {
		{ Target = "near", Distance = 8, Allowed = true, Visible = true, Facing = 1, Bearing = 0 },
		{ Target = "far", Distance = Rules.RetainRange + 5, Allowed = true, Visible = true, Facing = 1, Bearing = 0 },
		{ Target = "ally", Distance = 6, Allowed = false, Visible = true, Facing = 1, Bearing = 0 },
	}
	check(Rules.pick(p, list, "near") == "near" and p.Pinned, "Picking a target didn't lock and pin it")
	check(Rules.pick(p, list, "far") == "near", "Picked a target out of range")
	check(Rules.pick(p, list, "ally") == "near", "Picked a target you can't fight")
	check(Rules.update(p, list, 1, false) == "near", "A picked target didn't hold")
end
check(Rules.switch(s, { b("far", 30, 0) }) == "mid", "Switch jumped to a target outside SwitchRange")
s = Rules.new()
local duel = { b("rival", 9, 0, true), b("add", 5, 0.4) }
check(Rules.update(s, duel, 0, false) == "add", "Nearest enemy not locked over the rival")
check(Rules.switch(s, duel) == "rival", "Couldn't switch to the rival")
check(Rules.update(s, duel, 0.1, false) == "rival", "A switched target didn't hold against a nearer enemy")
check(
	Rules.update(s, { b("rival", 9, 0, true) }, 0.2, false) == "rival",
	"Lock didn't return to the rival once the switched target was gone"
)
print(
	"PASS: " .. checks .. " nearest-enemy lock, rival hold, auto-engage, cover grace, range and target switching checks"
)
