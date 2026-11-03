-- lune run tests/rival_surges_cases.luau <repo>
-- A new miner's intro rivals (Duelist.showcaseSurges) cast the starter kit's
-- showcase moves, as the player's do: a Q from their surge gem element's
-- Offense, an E from its Ability on the other two, each one cast as itself
-- (Kaiju.AbilityPlans: the leaps, storms, cannons and blasts), none twice.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end
local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local env = setmetatable({
		Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum,
		NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		UDim2 = roblox.UDim2,
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		game = { GetService = function()
			return setmetatable({}, { __index = function() return function() end end })
		end },
		require = function(m) return load(m) end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	return cache[name]
end
local GemTraits, Tech, Kaiju = load("GemTraits"), load("CombatTechnology"), load("Kaiju")

-- Duelist.showcaseSurges, from Duelist's own source.
local source = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
local from = source:find("function Duelist.showcaseSurges", 1, true)
check(from ~= nil, "No Duelist.showcaseSurges")
local to = source:find("\nend\n", from, true)
local Duelist = {}
local chunk = luau.load(source:sub(from, to + 4) .. "return Duelist", {
	debugName = "showcaseSurges",
	environment = setmetatable({
		Duelist = Duelist,
		KaijuShared = Kaiju,
		ReplicatedStorage = { Shared = { GemTraits = "GemTraits" } },
		require = function(m) return load(m) end,
	}, { __index = _G }),
})
chunk()

-- Every mix of elements on the three surge gems, every pick.
local elements = { "Fire", "Frost", "Shock", "Poison" }
-- (a seeded pick: lune has no Random)
local state = 7
local function pick(n)
	state = (state * 1103515245 + 12345) % 2147483648
	return (state // 65536) % n + 1
end
local seen = {}
for _, a in elements do
	for _, b in elements do
		for _, c in elements do
			for _ = 1, 6 do
				local loadout = {}
				for slot, element in { a, b, c } do
					-- (what a rival rolls today: a plain surge of its element)
					loadout["Surge" .. slot .. "Gem"] = {
						Element = element, Tier = "Uncommon", Surge = "ThermalBurst", SurgeTier = 1, SurgeRank = 1,
						Size = 5, Clarity = 5, Cut = 6,
					}
				end
				local set = Duelist.showcaseSurges(loadout, pick)
				check(#set == 3, "Not all three surges showcase moves: " .. a .. b .. c)
				for slot = 1, 3 do
					local gem = loadout["Surge" .. slot .. "Gem"]
					local lane = if slot == 1 then "Offense" else "Ability"
					check(table.find(GemTraits.Intro[gem.Element][lane], gem.Surge) ~= nil, "Surge " .. slot .. " not its element's " .. lane .. ": " .. gem.Surge)
					check(Kaiju.AbilityPlans[gem.Surge] ~= nil, "Not cast as itself: " .. gem.Surge)
					check(Tech.surgeOf(gem) == gem.Surge, "The gem doesn't carry it: " .. gem.Surge)
					local stats = Tech.surgeStats(gem)
					check(stats and stats.Name and (stats.Damage or 0) > 0, "No numbers for " .. gem.Surge)
					seen[gem.Surge] = true
				end
				check(set[1] ~= set[2] and set[2] ~= set[3] and set[1] ~= set[3], "The same move twice")
			end
		end
	end
end
-- Each element's showcase E's and Q's all come up.
for _, element in elements do
	for _, lane in { "Offense", "Ability" } do
		for _, id in GemTraits.Intro[element][lane] do
			if Kaiju.AbilityPlans[id] then
				check(seen[id], "Never rolled: " .. id)
			end
		end
	end
end
-- No surge gems (the tutorial's bare rival): nothing changes.
check(#Duelist.showcaseSurges({}, function() return 1 end) == 0, "Surges out of nothing")

-- Wired: an intro round's rival, or the very first fight's.
do
	local at = source:find("function spawnRival", 1, true)
	local body = source:sub(at, source:find("\nend\n", at, true))
	check(
		body:find("if introRound or (not raid and not encounter and session == \"Training\" and duelsPlayed(owner) == 0) then", 1, true) ~= nil
			and body:find("Duelist.showcaseSurges(loadout", 1, true) ~= nil,
		"Intro rivals aren't given the showcase moves"
	)
	-- (before its surges are read off the gems)
	check(body:find("Duelist.showcaseSurges(loadout", 1, true) < body:find('loadout["Surge" .. slot .. "Gem"]', 1, true), "Set after its surges were read")
end
-- And it casts them: whenever one's ready and you're in reach (close in
-- too), never held back for Charge, a little apart and a little softer.
check(source:find("loadout.Showcase = true", 1, true) ~= nil and source:find("Showcase = loadout.Showcase == true", 1, true) ~= nil, "An intro rival isn't marked to show its surges off")
check(source:find("if duel.Showcase and choice ~= \"Stagger\" and choice ~= \"Surge\" and now >= duel.NextSurge and distance <= Brain.SurgeRange then", 1, true) ~= nil, "An intro rival still only surges from range")
check(source:find("if duel.Showcase then\n\t\t\tcost = 0", 1, true) ~= nil, "An intro rival's surges are held back for Charge")
print(string.format("PASS: %d intro rival surge checks (a Q and two E's of the starter kit's showcase moves, each cast as itself)", checks))
process.exit(0)
