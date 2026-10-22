-- How you level up (Shared.Levelling): a rock's XP falling off the more you
-- mine and coming back with rest; a win's XP as a share of your level, by
-- the foe's level against yours, less for the same player again; the
-- shares in order (bosses over duels over rivals); levelling from wins
-- outpacing mining past the first few levels; and every source wired to it
-- (mining to your level alone, never your kaiju). Run by tests/run_levelling.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local Levelling = luau.load(fs.readFile(ROOT .. "/src/shared/Levelling.luau"), { debugName = "Levelling" })()
local Season = luau.load(fs.readFile(ROOT .. "/src/shared/Season.luau"), { debugName = "Season" })()

-- Your level's curve (Shared.AugmentTree.xpToNext), as it's written there.
local tree = fs.readFile(ROOT .. "/src/shared/AugmentTree.luau")
check(tree:find("return 150 + 60 * n + 6 * n * n", 1, true) ~= nil, "The level curve changed: update need() here")
local function need(level)
	local n = math.max(0, level - 1)
	return 150 + 60 * n + 6 * n * n
end

-- Mining ---------------------------------------------------------------------------------------

local rule = Levelling.Mine
check(Levelling.mineXP(0) == rule.Base and rule.Base == Season.XP.Mine, "A first rock isn't the Season's rock")
check(Levelling.mineXP(rule.Half) == math.floor(rule.Base / 2 + 0.5), "Half as much after Half rocks")
local last, total = math.huge, 0
for mined = 0, 129 do
	local xp = Levelling.mineXP(mined)
	check(xp <= last and xp >= rule.Floor, "A rock was worth more than the one before it")
	last, total = xp, total + xp
end
-- A full charge (about 130 rocks) is a few hundred XP, not 130 first rocks' worth.
check(total >= 300 and total <= 500, "A full charge of rocks came to " .. total)
check(Levelling.mineXP(1e6) == rule.Floor, "Mining forever went under the least")
for _, bad in { -5, 0 / 0, math.huge, "x" :: any, nil :: any } do
	local xp = Levelling.mineXP(bad)
	check(xp >= rule.Floor and xp <= rule.Base, "A bad count gave " .. tostring(xp))
end
-- Rest: what you've mined lately halves every Rest seconds.
check(math.abs(Levelling.rested(100, rule.Rest) - 50) < 1e-6, "Didn't halve over Rest")
check(math.abs(Levelling.rested(100, rule.Rest * 3) - 12.5) < 1e-6, "Didn't halve thrice over three Rests")
check(Levelling.rested(100, 0) == 100 and Levelling.rested(100, -60) == 100, "Rested backwards")
check(Levelling.rested(0 / 0, 10) == 0 and Levelling.rested(nil, 10) == 0, "A bad count wasn't nothing")
-- Mining on and on (a rock every 12 s) settles at the least.
do
	local mined, xp = 0, 0
	for _ = 1, 2000 do
		xp = Levelling.mineXP(mined)
		mined = Levelling.rested(mined + 1, 12)
	end
	check(xp <= rule.Floor + 1, "Mining on and on still pays " .. xp .. " a rock")
end

-- Wins -----------------------------------------------------------------------------------------

check(Levelling.gap(10, 10) == 1, "A foe at your level isn't even")
check(math.abs(Levelling.gap(10, 15) - 2) < 0.02, "Five over isn't about double")
check(math.abs(Levelling.gap(10, 5) - 0.5) < 0.01, "Five under isn't about half")
check(Levelling.gap(1, 50) == Levelling.Gap.Max and Levelling.gap(50, 1) == Levelling.Gap.Min, "Not kept between Min and Max")
for level = 1, 40 do
	for foe = 1, 40 do
		check(Levelling.gap(level, foe + 1) >= Levelling.gap(level, foe), "A higher foe worth less")
	end
end
check(Levelling.gap(10, nil) == 1 and Levelling.gap(10, 0 / 0) == 1, "A foe of no level isn't even")

-- The shares: bosses most, then a dungeon, a duel, a kaiju battle and a raid
-- wave, an arena rival; least for playing.
local S = Levelling.Share
check(
	S.RiftBoss > S.DungeonBoss
		and S.DungeonBoss > S.DuelWin
		and S.DuelWin > S.KaijuWin
		and S.KaijuWin >= S.RaidWave
		and S.RaidWave > S.Rival
		and S.Rival > S.DuelPlay
		and S.DuelPlay > S.KaijuPlay
		and S.KaijuPlay > 0,
	"The shares are out of order"
)
check(S.RiftBoss < 1, "One boss is worth a whole level")
for kind, share in S do
	for level = 1, 60 do
		local at = Levelling.winXP(kind, level, level, need(level))
		check(math.abs(at - share * need(level)) <= 0.5 + 1e-9, kind .. " at your level isn't its share at " .. level)
		check(Levelling.winXP(kind, level, level + 3, need(level)) > at, kind .. ": a higher foe isn't worth more")
		check(Levelling.winXP(kind, level, level - 3, need(level)) <= at, kind .. ": a lower foe is worth more")
		check(Levelling.winXP(kind, level, level, need(level)) >= 1, kind .. " is worth nothing")
	end
end
-- The same player again: half, then a quarter.
do
	local full = Levelling.winXP("DuelWin", 10, 10, need(10))
	check(math.abs(Levelling.winXP("DuelWin", 10, 10, need(10), 1) - full / 2) <= 1, "Again isn't half")
	check(math.abs(Levelling.winXP("DuelWin", 10, 10, need(10), 2) - full / 4) <= 1, "A third time isn't a quarter")
	check(Levelling.winXP("DuelWin", 10, 10, need(10), 40) == 1, "Farming one player went to nothing, not the least")
end
check(Levelling.winXP("Spoofed", 10, 10, need(10)) == 0, "An unknown win paid")
check(
	Levelling.winXP("RiftBoss", 10, 10, math.huge) == 0 and Levelling.winXP("RiftBoss", 10, 10, 0 / 0) == 0,
	"A maxed level (or a bad one) took XP"
)

-- Bosses and players level you, not rocks: from level 8 on, a Rift boss at
-- your level is worth more than a full charge, and a duel won against
-- someone five over you too; by level 20, a full charge is under a fifth of
-- a level.
for level = 8, 60 do
	check(Levelling.winXP("RiftBoss", level, level, need(level)) > total, "A full charge beats a Rift boss at " .. level)
	check(Levelling.winXP("DuelWin", level, level + 5, need(level)) > total, "A full charge beats a hard duel at " .. level)
end
check(total < need(20) / 5, "A full charge is still a fifth of a level at 20")
-- (A brand-new miner levels a little by mining: the first level in a few dozen rocks.)
do
	local mined, xp, rocks = 0, 0, 0
	while xp < need(1) do
		xp += Levelling.mineXP(mined)
		mined += 1
		rocks += 1
	end
	check(rocks >= 15 and rocks <= 40, "The first level took " .. rocks .. " rocks")
end

-- Wired ------------------------------------------------------------------------------------------

local function source(path)
	return fs.readFile(ROOT .. "/" .. path)
end
local server = "src/server/Systems/"
local progress = source(server .. "Progress.luau")
check(
	progress:find("local Levelling = require(ReplicatedStorage.Shared.Levelling)", 1, true)
		and progress:find("function Progress.won(", 1, true)
		and progress:find("function Progress.mined(", 1, true)
		and progress:find("Levelling.rested(lately.Mined", 1, true),
	"Progress doesn't level you by Shared.Levelling"
)
-- Every rock goes through Progress.mined: the Outpost's, the old nodes', an expedition's wall.
for _, name in { "OutpostServer", "Mining", "MineWall" } do
	local text = source(server .. name .. ".luau")
	check(text:find("Progress.mined(player)", 1, true) ~= nil, name .. "'s rocks don't go through Progress.mined")
	check(text:find('Progress.addXP(player, "Mine")', 1, true) == nil, name .. " still pays a rock's flat XP")
end
-- Your kaiju get nothing for your rocks.
check(source(server .. "KaijuServer.luau"):find("function KaijuServer.mined", 1, true) == nil, "Kaiju still level as you mine")
check(source("src/server/Main.server.luau"):find("onRockMined", 1, true) == nil, "A rock still reaches your kaiju")
check(source("src/shared/Kaiju.luau"):find("MineExp", 1, true) == nil, "Kaiju still have rock EXP")
-- Every win goes by the foe's level.
local wins = {
	{ "Duels", 'Progress.won(member, result, levels[if t == 1 then 2 else 1], result, foe)' },
	{ "Duelist", 'Progress.won(member, "RaidWave", bossLevel, "SlayBrute")' },
	{ "Duelist", 'Progress.won(owner, "Rival", Progress.levelOf(owner), "SlayBrute")' },
	{ "Dungeons", 'Progress.won(p, "DungeonBoss", squadLevel, "SlayBrute")' },
	{ "RiftServer", 'Progress.won(player, "RiftBoss", bossLevel, "SlayBrute")' },
	{ "KaijuBattles", 'Progress.won(player, if result == "Win" then "KaijuWin" else "KaijuPlay", Progress.levelOf(foe), nil, foe)' },
}
for _, entry in wins do
	check(source(server .. entry[1] .. ".luau"):find(entry[2], 1, true) ~= nil, entry[1] .. " doesn't pay a win by the foe's level")
end
check(
	source(server .. "RiftServer.luau"):find("local bossLevel = run.BossLevel or RiftRun.bossLevel(levelsOf(run), run.Boss)", 1, true) ~= nil,
	"The Rift's win doesn't go by its boss's level"
)

print(string.format("PASS: %d levelling checks (rocks falling off and resting, wins by the foe's level, the same player again, shares, bosses over mining, wiring)", checks))
