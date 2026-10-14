-- lune run tests/fast_start_cases.luau <repo>
-- The fast start (Shared.FastStart): who sees the picker, the first fight's
-- hints, and the starter kit each choice gives.
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
local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local env = setmetatable({
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		script = { Parent = setmetatable({}, { __index = function(_, key)
			return key
		end }) },
		require = function(module)
			return load(module)
		end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { environment = env })()
	return cache[name]
end
local FastStart = load("FastStart")
local Lottery = load("StarterLottery")
local Traits = load("GemTraits")
local Tech = load("CombatTechnology")

-- Who sees it: brand-new saves only. An old save that's been playing
-- without finishing the intro is marked done (its gear is kept).
local old = { Version = 10, Intro = { Done = false } }
check(FastStart.migrate(old) == true and old.Intro.Done == true and old.Intro.Skipped == "FastStart", "An old unfinished save skips the fast start")
local finished = { Version = 10, Intro = { Done = true } }
check(FastStart.migrate(finished) == false and finished.Intro.Skipped == nil, "A finished save is left alone")
local fresh = { Version = FastStart.SaveVersion, Intro = { Done = false } }
check(FastStart.migrate(fresh) == false and fresh.Intro.Done == false, "A new save keeps its fast start")
local PlayerData = fs.readFile(ROOT .. "/src/server/Systems/PlayerData.luau")
check(string.find(PlayerData, "Version = FastStart.SaveVersion", 1, true) ~= nil, "New profiles start at the fast start's save version")

-- All styles can choose all four elements, without a recommended default.
check(FastStart.Recommended == nil, "Styles must not recommend or default an element")
for _, style in FastStart.Styles do
	check(table.find(Lottery.Styles, style) ~= nil, style .. " isn't a starter style")
	for _, element in FastStart.Elements do
		check(Lottery.validChoice(style, element), style .. " + " .. element .. " must be a valid kit")
	end
end
-- The picker shows what each key can roll; the kit gives one of those,
-- saved with it, on every stone.
for _, element in FastStart.Elements do
	local pools = Lottery.starterPools(element)
	check(#pools == 3, element .. " should have three keys")
	for index, pool in pools do
		local lane = ({ "Offense", "Ability", "Defense" })[index]
		check(#pool >= 1, element .. " " .. lane .. " has nothing to roll")
		if Traits.Enabled then
			check(#pool == 2, element .. " " .. lane .. " should roll one of two")
		end
		for _, id in pool do
			check(Tech.Catalog[id] ~= nil, id .. " isn't a real move")
			if Traits.Enabled then
				check(Traits.Index[id].Lane == lane and Traits.Index[id].Element == element, id .. " is on the wrong key")
			end
		end
	end
	for _, roll in { 1, 2 } do
		local profile = { Intro = {} }
		local kit = Lottery.prepareChoice(profile, "Juggernaut", element, function()
			return { Id = "g" }
		end, function(count)
			return math.min(roll, count)
		end)
		local moves = kit.Moves
		check(#moves == 3, element .. " kit didn't save its rolled moves")
		for index, id in moves do
			check(id == pools[index][math.min(roll, #pools[index])], element .. " rolled outside its pool")
		end
		local shown = Lottery.starterMoves(element, kit)
		check(shown[1] == moves[1] and shown[3] == moves[3], element .. " kit doesn't report what it rolled")
		if Traits.Enabled then
			for _, entry in kit.Gems do
				local t = entry.Gem.Traits
				check(t.Offense == moves[1] and t.Ability == moves[2] and t.Defense == moves[3], element .. " kit gems don't carry the rolled moves")
			end
		end
		-- Retrying never rerolls.
		check(Lottery.prepareChoice(profile, "Juggernaut", element, function() return { Id = "h" } end, function() return 1 end) == kit, element .. " kit rerolled on retry")
	end
end

-- The first fight's hints: one at a time, the threat first.
local idle = { FoeSlash = false, FoeHeavy = false, FoeGuard = false, Ready = {} }
local done = {}
check(FastStart.hint(idle, done) == "Swing", "It opens with how to swing")
check(FastStart.hint({ FoeHeavy = true, Ready = {} }, done) == "Dodge", "A Heavy Blow comes first: dodge")
check(FastStart.hint({ FoeSlash = true, Ready = {} }, done) == "Block", "A swing winding up: block")
check(FastStart.hint({ FoeGuard = true, Ready = {} }, done) == "Swing", "Heavy waits until a swing has landed")
FastStart.complete(done, "Hit")
check(done.Swing and FastStart.hint(idle, done) == nil, "A landed hit ticks off the swing")
check(FastStart.hint({ FoeGuard = true, Ready = {} }, done) == "Heavy", "A raised guard: throw a heavy")
check(FastStart.hint({ Ready = { E = true, R = true } }, done) == "E", "The first affordable key in order")
FastStart.complete(done, "Block")
check(FastStart.hint({ FoeSlash = true, Ready = {} }, done) == nil, "Block shows once")
local heavyFirst = {}
FastStart.complete(heavyFirst, "Heavy")
check(heavyFirst.Swing and heavyFirst.Heavy, "A heavy is a swing too")
for _, id in FastStart.Order do
	FastStart.complete(done, if id == "Swing" then "Hit" else id)
end
check(FastStart.finished(done), "Everything done: no more hints")
check(FastStart.hint({ FoeHeavy = true, FoeSlash = true, FoeGuard = true, Ready = { Q = true } }, done) == nil, "Nothing once done")

-- The words: keys or touch, with the move's name.
local line, why = FastStart.text("Q", false, { Q = "Cinder Cleave" })
check(line == "PRESS Q: CINDER CLEAVE" and #why > 0, "Q names its move: " .. line)
check(FastStart.text("Block", true) == "HOLD GUARD to block", "Touch wording for block")
check(FastStart.text("Swing", false) == "CLICK to swing your sword", "Keys wording for swing")
for _, id in FastStart.Order do
	local keys, reason = FastStart.text(id, false, {})
	local tap = FastStart.text(id, true, {})
	check(#keys > 0 and #tap > 0 and #reason > 0, id .. " needs words for keys and touch")
end

print("PASS: " .. checks .. " fast start checks (who sees it, the kit, the first fight's hints)")
