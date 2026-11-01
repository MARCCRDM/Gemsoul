-- lune run tests/intro_rounds_cases.luau <repo>
-- Intro rounds (Shared.IntroRounds): who gets them, the slot each round pays,
-- the Rare odds and the last round's sure Rare, a loss easing the next try,
-- the ladder getting harder, and every rival's outfit being real cosmetics.
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
	if cache[name] then return cache[name] end
	local env = setmetatable({
		Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum,
		NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, UDim2 = roblox.UDim2,
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		game = { GetService = function() return setmetatable({}, { __index = function() return function() end end }) end },
		require = function(m) return load(m) end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { environment = env })()
	return cache[name]
end
local R = load("IntroRounds")
local Cosmetics = load("Cosmetics")
local Slots = load("EquipmentSlots")

-- The ladder's shape.
check(#R.Order == R.Count and #R.Rivals == R.Count, "Order and rivals aren't one per round")
local seen = {}
for _, slot in R.Order do
	check(Slots.Definitions[slot] ~= nil and not seen[slot], "Not six distinct gear slots: " .. slot)
	seen[slot] = true
	check(R.SlotNames[slot] ~= nil, "No name for " .. slot)
end
check(R.Order[1] == "Weapon", "The first piece isn't the sword")
for round = 2, R.Count do
	local a, b = R.difficulty(round - 1, 0), R.difficulty(round, 0)
	check(b.Damage > a.Damage and b.Rate < a.Rate and b.Health > a.Health, "Round " .. round .. " isn't harder than the last")
end
check(R.difficulty(R.Count, 0).Damage > 1 and R.difficulty(R.Count, 0).Damage <= 1.3, "The champion should outhit a full Arena rival, but not by much")
check(R.difficulty(1, 0).Damage <= 0.5 and R.difficulty(1, 0).Health < 1, "Round 1 should stay the soft first fight")
-- Outfits: real cosmetics, none exclusive, rarer as you climb.
local RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local best = 0
for round = 2, R.Count do
	local looks = R.looks(round)
	check(type(looks) == "table", "Round " .. round .. " has no outfit")
	local top = 0
	for kind, id in looks do
		local c = Cosmetics.get(id)
		check(c ~= nil, "Not a cosmetic: " .. tostring(id))
		check(c.Kind == kind, string.format("%s isn't a %s", id, kind))
		check(not c.Exclusive, "An exclusive on a rival: " .. id)
		top = math.max(top, RANK[c.Rarity] or 0)
	end
	check(top >= best, "Round " .. round .. "'s outfit is plainer than the last")
	best = top
end
check(best == 5, "The champion wears nothing Legendary")

-- Who: new accounts only (the funnel's), until the set's done.
check(R.state({}) == nil and not R.eligible({}), "An old account got intro rounds")
check(R.state(nil) == nil, "No profile made a state")
local profile = { Funnel = {} }
check(R.eligible(profile), "A new account has no intro rounds")
local state = R.state(profile)
check(profile.IntroRounds == state and R.round(state) == 1 and R.slot(1) == "Weapon", "Doesn't start at round 1, the sword")

-- A loss eases that round's next try; a win moves on and resets it.
local base = R.difficulty(2, 0)
R.won(state, "Uncommon")
R.lost(state); R.lost(state)
check(state.Losses == 2, "Losses not counted")
local eased = R.difficulty(R.round(state), state.Losses)
check(eased.Damage < base.Damage and eased.Rate > base.Rate and eased.Health < base.Health and not eased.Lunge, "Two losses didn't ease round 2")
check(R.difficulty(6, 50).Damage >= R.Ease.Floor and R.difficulty(6, 50).Health >= R.Ease.HealthFloor, "Eased under the floor")
check(R.won(state, "Uncommon") == 2 and state.Losses == 0 and R.round(state) == 3, "A win didn't pay round 2 and move on")

-- Rarity: Uncommon or Rare by the roll; the last round Rare if none came.
check(R.rarity(state, 0.99) == "Uncommon" and R.rarity(state, 0.01) == "Rare", "Rarity roll wrong")
R.won(state, "Uncommon"); R.won(state, "Uncommon"); R.won(state, "Uncommon")
check(R.round(state) == 6 and R.rarity(state, 0.99) == "Rare", "No sure Rare in the last round")
state.Rare = true
check(R.rarity(state, 0.99) == "Uncommon", "A second sure Rare after one came")
check(R.won(state, "Uncommon") == 6 and not R.eligible(profile), "Six wins didn't finish it")
check(R.won(state, "Rare") == 0 and state.Won == R.Count, "Won past the last round")
local view = R.view(state)
check(view.Done and #view.Slots == R.Count and view.Won == R.Count, "The view of a done set is wrong")

-- A saved state from an older build is cleaned up.
local odd = R.state({ IntroRounds = { Won = 99, Losses = -3, Pieces = "x" } })
check(odd.Won == R.Count and odd.Losses == 0 and type(odd.Pieces) == "table", "A bad saved state wasn't cleaned")

print(string.format("PASS: %d intro rounds checks", checks))
