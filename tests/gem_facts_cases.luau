-- lune run tests/gem_facts_cases.luau <repo>
-- A gem's whole list (Shared.GemFacts, the Market's listing): every element
-- and rarity, cut and rough. The three moves are the gem's own (Q, E, R),
-- the grades, weapon and armor effects, resist, value and origin are all
-- there, a rough stone shows no Precision effects, and every line but the
-- gem's name reads in Spanish with no {1} left over.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
-- (Lune has no Random: a small seeded one with the same methods)
local Random = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
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
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
env = setmetatable({
	Random = Random,
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	NumberRange = roblox.NumberRange,
	game = {
		GetService = function()
			return {
				Shared = names,
				FindFirstChild = function()
					return nil
				end,
			}
		end,
	},
	script = { Parent = names },
	require = shared,
}, { __index = _G })


local CombatTechnology = shared("CombatTechnology")
local ElementMatchup = shared("ElementMatchup")
local GemConfig = shared("GemConfig")
local GemFacts = shared("GemFacts")
local GemTraits = shared("GemTraits")
local Lang = shared("Lang")

local function find(lines, kind, pattern)
	for _, line in lines do
		if line.Kind == kind and (pattern == nil or string.find(line.Text, pattern, 1, true)) then
			return line
		end
	end
	return nil
end

local gems = 0
for _, element in GemConfig.Elements do
	for _, tier in GemConfig.TierOrder do
		for _, cut in { 7, false } do
			gems += 1
			local gem = {
				Id = "G-" .. element .. tier .. tostring(cut),
				Element = element,
				Tier = tier,
				Size = 6,
				Clarity = 5,
				Cut = if cut then cut else nil,
				Source = "MiningNode",
				Found = 1761500000,
				MinedBy = "Tester",
			}
			local lines = GemFacts.lines(gem)
			local name = GemConfig.displayName(gem)
			check(lines[1].Kind == "Name" and lines[1].Text == name, name .. ": the name comes first")
			check(find(lines, "Sub", GemConfig.elementName(element)) ~= nil, name .. ": no element line")
			check(find(lines, "Sub", "Tier level") ~= nil, name .. ": no tier level")
			-- The three moves are the gem's own, one per key, with their numbers.
			local keys = {}
			for _, line in lines do
				if line.Kind == "Move" then
					local id = GemTraits.traitFor(gem, line.Key)
					check(id and string.find(line.Text, CombatTechnology.Catalog[id].Name, 1, true), name .. ": wrong move on " .. tostring(line.Key))
					check(string.find(line.Text, GemFacts.Sockets[line.Key], 1, true) ~= nil, name .. ": move without its socket")
					keys[line.Key] = true
				end
			end
			check(keys.Q and keys.E and keys.R, name .. ": missing a key's move")
			check(find(lines, "Stats", "Charge") or find(lines, "Stats", "Stamina"), name .. ": no move numbers")
			-- Grades, effects, resist, value, origin.
			for _, metric in GemConfig.MetricOrder do
				check(find(lines, "Grade", GemConfig.MetricLabels[metric]) ~= nil, name .. ": no " .. metric .. " grade")
			end
			check(find(lines, "Head", "IN A WEAPON") and find(lines, "Head", "IN ARMOR"), name .. ": no weapon or armor effects")
			local resist = find(lines, "Effect", "Resists")
			check(resist ~= nil, name .. ": no resist line")
			local percent = tonumber(string.match(resist.Text, "Resists ([%d%.]+)%%"))
			check(percent and math.abs(percent - ElementMatchup.gemResist(gem) * 100) <= 0.06, name .. ": resist is off")
			local total = find(lines, "Total")
			local value = tostring(math.floor(GemConfig.worth(gem).Value + 0.5))
			value = string.reverse((string.gsub(string.reverse(value), "(%d%d%d)(%d)", "%1,%2")))
			check(total and string.find(total.Text, "= " .. value .. " coins", 1, true), name .. ": value is off")
			check(find(lines, "Note", "Mined by Tester") ~= nil, name .. ": no miner")
			check(find(lines, "Note", "Dug from the mine") ~= nil, name .. ": no origin")
			if not cut then
				check(find(lines, "Note", "Rough") ~= nil, name .. ": a rough stone doesn't say so")
				check(find(lines, "Effect", "Precision") == nil, name .. ": a rough stone shows Precision effects")
			end
			-- Spanish: every line but the name translates, with nothing left unfilled.
			Lang.setLocale("es-mx")
			for _, line in lines do
				local es = Lang.translate(line.Text)
				if line.Kind ~= "Name" then
					check(es ~= line.Text, name .. ": no Spanish for " .. line.Text)
				end
				check(not string.find(es, "{", 1, true), name .. ": unfilled Spanish for " .. line.Text .. " -> " .. es)
			end
			Lang.setLocale("en-us")
		end
	end
end
print(string.format("PASS: %d checks on %d gems (every element and rarity, cut and rough): moves, grades, effects, resist, value, origin, Spanish", checks, gems))
