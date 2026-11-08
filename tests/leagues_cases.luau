-- lune run tests/leagues_cases.luau <repo>
-- Ranked leagues (Shared.Leagues): rating to rank and tier, the saved
-- league with its safety after a promotion, the season's track, the crests.
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
local env = setmetatable({ Color3 = roblox.Color3, Vector2 = roblox.Vector2 }, { __index = _G })
local Leagues = luau.load(fs.readFile(ROOT .. "/src/shared/Leagues.luau"), { debugName = "Leagues", environment = env })()

-- The ranges.
check(Leagues.info(Leagues.stepOf(1000)).Label == "COPPER III", "1000 isn't Copper III")
check(Leagues.info(Leagues.stepOf(999)).Label == "STONE I", "999 isn't Stone I")
check(Leagues.info(Leagues.stepOf(899)).Label == "STONE III", "899 isn't Stone III")
check(Leagues.info(Leagues.stepOf(1050)).Label == "COPPER II" and Leagues.info(Leagues.stepOf(1149)).Label == "COPPER I", "Copper's tiers")
check(Leagues.info(Leagues.stepOf(1150)).Label == "COBALT III", "1150 isn't Cobalt III")
check(Leagues.info(Leagues.stepOf(1599)).Label == "PRISM I", "1599 isn't Prism I")
check(Leagues.info(Leagues.stepOf(1600)).Label == "TITAN" and Leagues.info(16).Tier == nil, "Titan has tiers")
check(Leagues.info(Leagues.stepOf(5000)).Step == 16 and Leagues.stepOf(-50) == 1, "Out of range")
for step = 1, 16 do
	local i = Leagues.info(step)
	check(Leagues.stepOf(i.Floor) == step, "A tier's floor isn't in it: " .. step)
end
local frac, toNext = Leagues.progress(Leagues.stepOf(1062), 1062)
check(math.abs(frac - 0.24) < 0.001 and toNext == 38, "Progress through Copper II")
check(Leagues.softReset(1400) == 1200 and Leagues.softReset(800) == 900 and Leagues.softReset(1000) == 1000, "Soft reset")

-- The saved league: up, down, the safety after reaching a league.
local S = "Season 1"
local saved, change = Leagues.update(nil, 1016, S, 1000)
check(saved.Step == 4 and not change.Promoted and #change.Track == 0, "A first win in Copper III moved it")
saved, change = Leagues.update(saved, 1052, S)
check(saved.Step == 5 and change.Promoted and change.Track[1] == 5, "Copper II wasn't reached, or didn't pay")
saved, change = Leagues.update(saved, 1030, S)
check(saved.Step == 4 and change.Demoted and not change.Shielded, "Dropping a tier inside a league is shielded")
saved, change = Leagues.update(saved, 1160, S)
check(saved.Step == 7 and change.NewLeague and saved.Safe == Leagues.SafeMatches, "Reaching Cobalt didn't start the safety")
check(#change.Track == 2 and change.Track[1] == 6 and change.Track[2] == 7, "Skipping tiers didn't pay each once")
-- three matches safe from dropping out of Cobalt
for i = 1, Leagues.SafeMatches do
	saved, change = Leagues.update(saved, 1120, S)
	check(saved.Step == 7 and change.Shielded, "Dropped out of a league just reached (match " .. i .. ")")
end
saved, change = Leagues.update(saved, 1120, S)
check(saved.Step == 6 and change.Demoted and not change.Shielded, "Still safe after the safe matches")
-- back up: nothing paid twice this season
saved, change = Leagues.update(saved, 1170, S)
check(saved.Step == 7 and #change.Track == 0, "A step paid twice in a season")
-- a new season: the track pays again
saved, change = Leagues.update(saved, 1210, "Season 2")
check(saved.Step == 8 and #change.Track == 1 and change.Track[1] == 8, "A new season's track")
saved = Leagues.update({ Step = 7, Season = "Season 3" }, 1250, "Season 3")
check(saved.Step == 9, "Best defaults")
-- Titan
saved, change = Leagues.update({ Step = 15, Season = S, Best = 15 }, 1650, S)
check(saved.Step == 16 and change.NewLeague and change.Track[1] == 16 and Leagues.Track[16].Title, "Titan's reward")

-- The track and the crests.
check(Leagues.nextReward(4) == 5 and Leagues.nextReward(16) == nil, "Next reward")
for step = 5, 16 do
	check(Leagues.Track[step] and Leagues.Track[step].Coins > 0, "A tier with no reward: " .. step)
end
for step = 4, 15, 3 do
	check(Leagues.Track[step + 3].Cache ~= nil, "A new league with no cache: " .. step + 3)
end
local first, size = Leagues.crest(1)
local last = Leagues.crest(16)
check(first.X == 0 and first.Y == 0 and size.X == 256 and last.X == 768 and last.Y == 768, "Crest cells")
check(fs.isFile(ROOT .. "/assets/images/crests/crests.png"), "No crest image")
check(fs.readFile(ROOT .. "/src/shared/Leagues.luau"):find("Sheet = %d+, %-%- crests%.png"), "The crest image has no id line")

print("PASS: " .. checks .. " league checks (ranges, tiers, the saved league, safety after a promotion, the season's track, crests)")
