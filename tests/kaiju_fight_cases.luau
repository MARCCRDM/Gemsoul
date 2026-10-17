-- lune run tests/kaiju_fight_cases.luau <repo>
-- How a kaiju fights (Shared.KaijuFight): each kind's own blows and
-- timings, the brain's distances scaled to its size, guard and parry,
-- heavies breaking a guard, hops, what a foe reads off it, and the
-- duellist's brain (Shared.DuelistBrain) choosing its moves.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Fight = shared("KaijuFight")
local Brain = shared("DuelistBrain")
local Kaiju = shared("Kaiju")

-- Styles -----------------------------------------------------------------------------------------
local names = {}
for _, id in Kaiju.Order do
	local style = Fight.style(id)
	check(style == Fight.Styles[id], id .. " has no style")
	for _, kind in { "Light", "Heavy", "Punish", "Lunge" } do
		local name = style.Names[kind]
		check(type(name) == "string" and not names[name], id .. ": " .. kind .. " has no name of its own")
		names[name] = true
	end
	check(style.Combo >= 2 and style.ComboChance > 0 and style.ComboGap > 0.2, id .. ": no combos")
	check(style.GuardMult > 0 and style.GuardMult < 1, id .. ": an odd guard")
end
local bulwark, razorback, carapace = Fight.Styles.Bulwark, Fight.Styles.Razorback, Fight.Styles.Carapace
check(Fight.style("Nobody") == bulwark, "An unknown kind fights as nothing")
-- The runner is the quickest, the brute the slowest and heaviest, the shell the hardest to get through.
check(Fight.windup(razorback, "Light") < Fight.windup(carapace, "Light"), "The runner isn't the quickest")
check(Fight.windup(carapace, "Light") < Fight.windup(bulwark, "Light"), "The brute isn't the slowest")
check(bulwark.Heavy > carapace.Heavy and carapace.Heavy > razorback.Heavy, "The brute's heavy isn't the heaviest")
check(razorback.Combo > bulwark.Combo, "The runner's combos aren't the longest")
check(carapace.GuardMult < bulwark.GuardMult and bulwark.GuardMult < razorback.GuardMult, "The shell guards no better")
check(razorback.Hop > bulwark.Hop and bulwark.Hop > carapace.Hop, "The runner hops no further")

-- Wind-ups: the brain's, times its kind's; an E's are the brain's own.
check(math.abs(Fight.windup(bulwark, "Heavy") - Brain.Windup.Heavy * 1.15) < 1e-9, "A heavy's wind-up isn't scaled")
check(Fight.windup(razorback, "Bolt") == Brain.Windup.Bolt, "An E's wind-up is scaled")
check(Fight.windup(razorback, "Heavy") > 0.5, "A heavy is too quick to see coming")
-- Blows: a heavy its kind's share, a pounce a little more, a combo's third harder.
check(Fight.blow(bulwark, "Heavy") == 2 and Fight.blow(razorback, "Heavy") == 1.6, "A heavy's share")
check(Fight.blow(bulwark, "Light", 1) == 1 and Fight.blow(bulwark, "Light", 2) == 1, "A light blow's share")
check(Fight.blow(razorback, "Light", 3) == Fight.Finisher, "A combo's third doesn't land harder")
check(Fight.blow(bulwark, "Lunge") > 1, "A pounce lands no harder")

-- Reach: its kind's, at its size.
check(math.abs(Fight.reach(6, 0.55) - 3.3) < 1e-9, "Reach isn't scaled to its size")
-- E wind-ups: a ring round itself is a Nova (time to get out), anything else a Bolt.
for id, plan in Kaiju.AbilityPlans do
	local kind = Fight.surgeKind(plan)
	check(kind == (if plan.Shape == "Nova" then "Nova" else "Bolt"), id .. " winds up as " .. kind)
end

-- Guard and parry ------------------------------------------------------------------------------------
local function fighter(species)
	return Fight.new(species, { StunUntil = 0, SlowUntil = 0 }, 3.3, 1)
end
local f = fighter("Carapace")
local b = f.Body
check(Fight.raiseGuard(f, 100, 1.6), "A guard didn't go up")
check(b.GuardUntil == 101.6 and b.GuardMult == carapace.GuardMult and b.GuardRaisedAt == 100, "The guard's state")
check(Fight.guarding(b, 101) and not Fight.guarding(b, 102), "The guard's time")
check(not Fight.raiseGuard(f, 100.5, 2) and b.GuardUntil == 102.5, "Keeping it up isn't raising it again")
-- A light blow just as it goes up: parried, once.
local outcome, share = Fight.resolve(b, false, 100.1)
check(outcome == "Parried" and share == 0 and b.BlockedAt == 100.1, "A blow as it raised its guard isn't parried")
outcome, share = Fight.resolve(b, false, 100.15)
check(outcome == "Guarded" and share == carapace.GuardMult, "A guard parried twice")
-- Later in the guard: blocked, and a blow it can answer.
outcome, share = Fight.resolve(b, false, 101)
check(outcome == "Guarded" and share == carapace.GuardMult and b.BlockedAt == 101, "A blocked blow")
-- An E on its guard: blocked, but nothing to answer.
outcome, share = Fight.resolve(b, nil, 101.2)
check(outcome == "Guarded" and b.BlockedAt == 101, "An E on a guard")
check(not Fight.parries(b, nil, 101.2), "An E was parried")
-- A heavy breaks it: in full, it reels, and the guard can't go up for a while.
outcome, share = Fight.resolve(b, true, 101.5)
check(outcome == "Broken" and share == 1, "A heavy didn't break the guard")
check(not Fight.guarding(b, 101.5) and b.StunUntil == 101.5 + Fight.BreakStagger, "A broken guard stays up")
check(not Fight.raiseGuard(f, 101.8, 1) and not Fight.guarding(b, 101.8), "A broken guard went straight back up")
-- Back up after the break; a fresh raise parries again only after HighBlockEvery.
check(Fight.raiseGuard(f, 102.5, 1), "The guard didn't go back up")
check(b.GuardRaisedAt == 102.5 and not b.ParrySpent, "A raise after a while doesn't parry")
Fight.dropGuard(f, 102.6)
check(not Fight.guarding(b, 102.6), "The guard didn't drop")
check(Fight.raiseGuard(f, 102.8, 1) and b.GuardRaisedAt == 102.5, "Raising it over and over parries every time")
check(Fight.resolve(b, false, 102.85) == "Guarded", "A guard raised again at once parried")
-- Mid-hop: nothing lands; with no guard, everything does.
b.DodgeUntil = 103.3
check(Fight.resolve(b, true, 103.1) == "Dodged", "A hop doesn't dodge")
Fight.dropGuard(f, 103.4)
check(Fight.resolve(b, true, 103.4) == "Hit", "A blow on an open kaiju")

-- What a foe reads ------------------------------------------------------------------------------------
local g = fighter("Razorback")
local read = Fight.read(g, 200, 1)
check(not read.Charging and not read.Busy and read.Swings == 0 and not read.Low, "An idle kaiju looks busy")
g.Action = { Kind = "Light", At = 200.3, Hits = 1 }
read = Fight.read(g, 200.1, 1)
check(not read.Charging and read.Busy, "A light blow shows as a charge (or not at all)")
g.Action = { Kind = "Heavy", At = 200.8, Hits = 1 }
read = Fight.read(g, 200.1, 1)
check(read.Charging and read.Heavy, "A heavy's wind-up isn't seen")
g.Action = { Kind = "Surge", At = 200.8 }
read = Fight.read(g, 200.1, 0.2)
check(read.Casting and not read.Charging and read.Low, "An E's wind-up isn't seen")
g.Action = nil
g.SwingTimes = { 197, 199, 200.4 }
g.RecoverUntil = 200.4 + Fight.Recover
read = Fight.read(g, 200.5, 1)
check(read.Swings == 2 and read.LastSwing == 200.4 and read.Recovering, "Its last blows")
check(not Fight.read(g, 201, 1).Recovering, "Still recovering long after")
g.Body.StunUntil = 202
check(Fight.read(g, 201, 1).Vulnerable, "A stunned kaiju isn't open")

-- The brain's view and choices ------------------------------------------------------------------------
local function quiet()
	return {
		Charging = false,
		Heavy = false,
		LastSwing = nil,
		Swings = 0,
		Casting = false,
		Blocking = false,
		Recovering = false,
		Vulnerable = false,
		Low = false,
		Busy = true,
	}
end
local h = fighter("Bulwark")
h.NextSurge = math.huge
local view = Fight.view(h, quiet(), 300, 3.3, 1)
check(math.abs(view.Distance - Brain.Reach) < 1e-9, "At its reach, the brain doesn't see its reach")
check(not view.FoeIdle and view.FarFor == 0, "A busy foe close by")
-- Out of reach a while: it pounces (once the gap's been held).
view = Fight.view(h, quiet(), 300, 6, 1)
check(view.Distance > Brain.Reach + 2 and view.FarFor == 0, "Out of reach")
check(Fight.decide(h, view, 0.5) ~= "Lunge", "A pounce as its opener")
view = Fight.view(h, quiet(), 300.01 + Brain.LungeAfter, 6, 1)
check(view.FarFor >= Brain.LungeAfter and Fight.decide(h, view, 0.5) == "Lunge", "No pounce on a gap held")
-- An idle foe: it presses the attack.
local idle = quiet()
idle.Busy = false
Fight.view(h, idle, 310, 3, 1)
view = Fight.view(h, idle, 310.01 + Brain.IdleAfter, 3, 1)
check(view.FoeIdle, "An idle foe isn't seen as idle")
-- A heavy coming in reach: it hops aside (most of the time) and waits a beat before reacting again.
local heavy = quiet()
heavy.Charging, heavy.Heavy = true, true
h.NextDefense = 0
view = Fight.view(h, heavy, 320, 3, 1)
check(Fight.decide(h, view, 0.1) == "Dodge", "It stands in the way of a heavy")
check(h.NextDefense == 320.45, "No beat before it reacts again")
-- Its foe open after a blow: a counter.
local open = quiet()
open.Recovering = true
h.NextDefense = 999
view = Fight.view(h, open, 330, 3, 1)
check(Fight.decide(h, view, 0.5) == "Punish", "It doesn't punish an opening")
-- Just blocked a blow: a riposte, once per block.
h.Body.BlockedAt = 340
view = Fight.view(h, quiet(), 340.2, 3, 1)
check(view.JustBlocked and Fight.decide(h, view, 0.2) == "Riposte", "It doesn't answer a blocked blow")
h.RiposteFor = 340
check(not Fight.view(h, quiet(), 340.2, 3, 1).JustBlocked, "It answers the same block twice")
-- Its E: from range when ready.
h.NextSurge = 0
view = Fight.view(h, quiet(), 350, 9, 1)
check(Fight.decide(h, view, 0.5) == "Surge", "It doesn't cast its E from range")
-- Stunned: it reels.
h.Body.StunUntil = 361
check(Fight.decide(h, Fight.view(h, quiet(), 360, 3, 1), 0.5) == "Stagger", "A stunned kaiju acts")

print(string.format("PASS: %d kaiju fight checks (styles, wind-ups, guard, parry, reads, the brain)", checks))
