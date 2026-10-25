-- lune run tests/sword_feel_cases.luau <repo>
-- How a blow you land feels (client SwordFeel) and the flash on what it
-- hits (HitFlash): the swing stops dead longer for a heavy, a crit, a kill
-- and each step of a combo (never past the cap); your view jars with the
-- cut, down with a chop; a blow on a guard stops short, rings off it and
-- jolts back at you, with no flash; a flash comes on near-solid and fades.
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

local function load(path, env)
	return luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = path, environment = env })()
end
local SwordFeel = load("src/client/Modules/SwordFeel.luau")
local HitFlash = load(
	"src/client/Modules/HitFlash.luau",
	setmetatable({ game = { GetService = function() return {} end }, Color3 = roblox.Color3 }, { __index = _G })
)

local light = SwordFeel.tune({}, "Right")
local heavy = SwordFeel.tune({ Heavy = true }, "Right")
local crit = SwordFeel.tune({ Crit = true }, "Right")
local kill = SwordFeel.tune({ Kill = true }, "Right")
local blocked = SwordFeel.tune({ Blocked = true }, "Right")

-- The stop.
check(light.Stop > 0.04 and light.Stop < 0.1, "A cut's stop isn't a beat")
check(heavy.Stop > light.Stop, "A heavy doesn't bite deeper")
check(crit.Stop > light.Stop and kill.Stop > crit.Stop, "A crit or a kill doesn't land harder")
local last = 0
for combo = 1, 4 do
	local feel = SwordFeel.tune({ Combo = combo }, "Right")
	check(feel.Stop > last, "A combo doesn't build: step " .. combo)
	last = feel.Stop
end
local most = SwordFeel.tune({ Heavy = true, Crit = true, Kill = true, Combo = 9 }, "Left")
check(most.Stop <= SwordFeel.Stop.Most, "A stop past the cap")
check(blocked.Stop < light.Stop, "A blow on a guard holds as long as a cut")

-- The jar of your view: with the cut, down with a chop, harder for a crit.
check(light.Cut.X < 0 and SwordFeel.tune({}, "Left").Cut.X > 0, "The cut doesn't cross the way the swing goes")
check(heavy.Cut.Y < -0.9 and heavy.Pitch < light.Pitch, "A heavy doesn't chop down")
check(math.abs(light.Yaw + SwordFeel.tune({}, "Left").Yaw) < 1e-9 and light.Yaw ~= 0, "The two sides don't mirror")
check(math.abs(crit.Pitch) > math.abs(light.Pitch) and math.abs(kill.Pitch) > math.abs(crit.Pitch), "A crit or a kill doesn't jar harder")
check(math.abs(most.Pitch) < 0.1 and most.KickFor < 0.5, "A wild jar")

-- A guard: it rings off, jolts you back, and nothing flashes.
check(blocked.Sound == "Deflect" and blocked.Flash == 0 and blocked.Pitch > 0, "A blow on a guard doesn't ring off it")
check(light.Sound == "Contact" and heavy.Sound == "HeavyContact" and kill.Sound == "HeavyContact", "The wrong thud")
check(heavy.Power > light.Power and crit.Power > light.Power and light.Flash > 0, "The spark doesn't grow")
check(SwordFeel.tune({ Combo = 3 }, "Right").SoundPitch > light.SoundPitch, "The thud doesn't climb with the combo")
check(heavy.Rumble > light.Rumble and light.Rumble > blocked.Rumble, "The rumble isn't by the blow")
check(SwordFeel.tune(nil, nil).Stop == light.Stop, "No info isn't a plain cut")

-- The flash: near-solid at once, fading, gone; a stronger one holds longer.
check(HitFlash.fill(1, 0) < 0.5, "A flash doesn't come on")
local prev = -1
for i = 0, 10 do
	local fill = HitFlash.fill(1, i * 0.015)
	check(fill >= prev, "A flash doesn't fade out")
	prev = fill
end
check(HitFlash.fill(1, 1) == 1 and HitFlash.fill(1, -0.1) == 1, "A flash outside its time shows")
check(HitFlash.fill(1.5, 0) < HitFlash.fill(1, 0), "A strong flash isn't brighter")
check(HitFlash.fill(1.5, HitFlash.Seconds * 1.25) < 1 and HitFlash.fill(1, HitFlash.Seconds * 1.25) == 1, "A strong flash doesn't hold longer")

print(string.format("PASS: %d sword feel checks (hit stop, the jar, guards, sparks, sounds, rumble, the hit flash)", checks))
