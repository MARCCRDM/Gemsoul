-- lune run tests/first_steps_cases.luau <repo>
-- A new miner's first steps (Shared.FirstSteps): which card shows, in order,
-- for whom, and that it's gone once they're through.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local IntroRounds = luau.load(fs.readFile(ROOT .. "/src/shared/IntroRounds.luau"))()
local FirstSteps = luau.load(fs.readFile(ROOT .. "/src/shared/FirstSteps.luau"), {
	environment = setmetatable({
		script = { Parent = { IntroRounds = "IntroRounds" } },
		require = function()
			return IntroRounds
		end,
	}, { __index = _G }),
})()

local function profile(counts, funnel, done)
	return {
		Intro = { Done = if done == nil then true else done },
		TrainingRewards = { Counts = counts or {} },
		Funnel = funnel,
		IntroRounds = { Won = 6, Losses = 0, Pieces = {} }, -- (their intro set won: the rounds' own checks are below)
	}
end
local function id(p, extra)
	local step, index, total = FirstSteps.current(FirstSteps.view(p, extra))
	check(total == #FirstSteps.Steps, "Total isn't the step count")
	return step and step.Id, index
end

-- Every step has what its card shows.
for _, step in FirstSteps.Steps do
	check(type(step.Id) == "string" and step.Title ~= "" and step.Line ~= "" and step.Button ~= "", "A step is missing its words")
	check(#step.Title <= 26, "Title too long for a phone: " .. step.Title)
end

-- Not for players from before the funnel, nor before the intro's done.
check(id(profile({}, nil)) == nil, "Coached an old account")
check(id(profile({}, {}, false)) == nil, "Coached during the intro")
check(id(nil) == nil, "Coached with no profile")

-- In order: mine, socket, surge, duel.
local open = { SocketOpen = true, SurgeOpen = true }
check(id(profile({}, {}), open) == "Mine", "Didn't start with mining")
check(id(profile({ Mine = 1, MineGem = 1 }, {}), open) == "Socket", "Socket not next after the first gem")
check(id(profile({ Mine = 1, MineGem = 1, Enchant = 1 }, {}), open) == "Surge", "Surge not next after socketing")
check(id(profile({ Mine = 1, Enchant = 1, EquipSurge = 1 }, {}), open) == "Duel", "Duel not last")
local _, index = id(profile({ Mine = 1, Enchant = 1, EquipSurge = 1 }, {}), open)
check(index == 4, "Duel isn't step 4")

-- The funnel's own record counts too (a step logged before the counts).
check(id(profile({}, { ["First rock"] = true }), open) == "Socket", "Funnel's First rock not counted")
check(id(profile({ Mine = 1 }, { Socketed = true }), open) == "Surge", "Funnel's Socketed not counted")

-- Socket and Surge wait for something to put in.
check(id(profile({ Mine = 1 }, {}), { SocketOpen = false, SurgeOpen = true }) == "Surge", "Asked to socket with nothing to socket")
check(id(profile({ Mine = 1 }, {}), { SocketOpen = false, SurgeOpen = false }) == "Duel", "Asked for a surge with nothing better")

-- Done: two duels played (the attribute or the funnel), and it's gone for good.
check(id(profile({ Mine = 1, Enchant = 1, EquipSurge = 1 }, {}), { Duels = 2 }) == nil, "Still coaching after a second duel")
check(id(profile({}, { ["Second duel"] = true }), open) == nil, "Still coaching after the funnel's Second duel")
check(id(profile({ Mine = 1, Enchant = 1, EquipSurge = 1 }, {}), { Duels = 1 }) == "Duel", "One duel (the first fight) ended it")

-- While their intro set isn't won (the first dungeon taken after round 3),
-- finishing it comes first, whatever else is left (and it's not over at two
-- duels): its button, FIGHT, is the way back to it.
local rounds = profile({ Mine = 1, Enchant = 1, EquipSurge = 1 }, {})
rounds.IntroRounds = { Won = 3, Losses = 0, Pieces = {} }
local step, index = FirstSteps.current(FirstSteps.view(rounds, { Duels = 3 }))
check(step and step.Id == "Rounds" and index == 1 and step.Button == "FIGHT", "Didn't send them back for their intro set")
check(FirstSteps.view(rounds).Round == 4, "The round to win isn't the next one")
local fresh = profile({}, {})
fresh.IntroRounds = { Won = 3, Losses = 0, Pieces = {} }
check(FirstSteps.current(FirstSteps.view(fresh, open)).Id == "Rounds", "Finishing the intro fights isn't first")
check(string.find(FirstSteps.Rounds.Line, "gem", 1, true) ~= nil, "The step doesn't say what all six pay")
rounds.IntroRounds.Won = IntroRounds.Count
check(FirstSteps.current(FirstSteps.view(rounds, { Duels = 3 })) == nil, "Still coaching once the set's won and they've dueled")

print(string.format("PASS: %d first steps checks", checks))
