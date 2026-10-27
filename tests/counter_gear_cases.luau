-- lune run tests/counter_gear_cases.luau <repo>
-- COUNTER between Ranked rounds (Shared.CounterGear): what hurt you, and
-- the armor-only answer from what you own.
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

local AutoEquip = shared("AutoEquip")
local Classes = shared("Classes")
local GearRolls = shared("GearRolls")
local GemConfig = shared("GemConfig")
local GemInventory = shared("GemInventory")
local Slots = shared("EquipmentSlots")

local function newProfile()
	local profile = {
		Character = {
			Class = "Warrior",
			Weapon = "MatrixSwords1",
			Shield = "ScrapShield",
			Helmet = "ScrapHelmet",
			Armor = "PaddedJack",
			Gloves = "ScrapGloves",
			Boots = "ScrapBoots",
			ItemGems = {},
		},
		Owned = {
			Weapons = { MatrixSwords1 = 1, MatrixSwords6 = 1, ForgeGreataxe5 = 1, ForgeCleaver3 = 1 },
			Shields = { ScrapShield = 1, CrusaderShield = 1, ArmorJuggernautShield4 = 1 },
			Helmets = { ScrapHelmet = 1, CrusaderHelmet = 1, ArmorSkirmisherHelmet5 = 1, ArmorProspectorHelmet3 = 1 },
			Armors = { PaddedJack = 1, IronPlate = 1, ArmorJuggernautArmor5 = 1, ArmorSkirmisherArmor4 = 1 },
			Gloves = { ScrapGloves = 1, ArmorSkirmisherGloves5 = 1, ArmorJuggernautGloves2 = 1 },
			Boots = { ScrapBoots = 1, ArmorProspectorBoots5 = 1, ArmorJuggernautBoots3 = 1 },
		},
		Gems = {},
	}
	for _, slot in Slots.Order do
		profile.Character.ItemGems[slot] = {}
	end
	GearRolls.ensure(profile, Random.new(7))
	return profile
end

local function totalOf(loadout): number
	local r = Classes.ratings(loadout)
	local sum = 0
	for _, stat in Classes.StatNames do
		sum += r[stat].Base + r[stat].Bonus
	end
	return sum
end

-- What the server does with a plan (PlayerData.equipGear: the slot's gem
-- stays in the slot; PlayerData.socketGem: the old gem back to the pouch).
local function apply(profile, plan)
	local c = profile.Character
	for _, step in plan.Gear do
		local slot, id = step.Slot, step.Id
		local gems = c.ItemGems[slot]
		local held = c[slot .. "Gem"]
		if c[slot] then
			gems[c[slot]] = nil
		end
		c[slot] = id
		if held then
			gems[id] = held
		end
		c[slot .. "Gem"] = gems[id]
		c[slot .. "Quality"] = profile.Owned[Slots.Definitions[slot].Kind][id]
	end
	for _, step in plan.Gems do
		local gem
		for i, g in profile.Gems do
			if g.Id == step.Gem then
				gem = table.remove(profile.Gems, i)
				break
			end
		end
		assert(gem, "socketing a gem that isn't in the pouch: " .. step.Gem)
		if c[step.Slot .. "Gem"] then
			table.insert(profile.Gems, c[step.Slot .. "Gem"])
		end
		c[step.Slot .. "Gem"] = gem
		c.ItemGems[step.Slot][c[step.Slot]] = gem
	end
end


local CounterGear = shared("CounterGear")
local ElementMatchup = shared("ElementMatchup")

local function gem(id, element, grade)
	return { Id = id, Element = element, Tier = "Rare", Size = grade, Clarity = grade, Cut = grade }
end
-- A fighter in Cryo armor: Cryo gems in every armor socket, so Thermal
-- (which beats Cryo) hits them for 125%.
local function cryoFighter()
	local profile = newProfile()
	local c = profile.Character
	-- (No affixes on any roll: each case sets the ones it tests.)
	for _, rolls in c.GearRolls do
		for _, roll in rolls do
			roll.Affixes = {}
		end
	end
	c.WeaponGem = gem("w", "Shock", 6)
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		c[slot .. "Gem"] = gem("c" .. slot, "Frost", 6)
		c.ItemGems[slot][c[slot]] = c[slot .. "Gem"]
	end
	return profile
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- What hurt you: the round's damage by element, else their gear ------------------------------
do
	local threat = CounterGear.threat({ Fire = 60, Shock = 20, None = 20 }, nil)
	check(threat.Source == "Taken" and #threat.Shares == 2, "The damage taken wasn't read")
	check(threat.Shares[1].Element == "Fire" and near(threat.Shares[1].Share, 0.75), "Thermal isn't 75% of the elemental damage")
	check(near(threat.Shares[2].Share, 0.25) and near(threat.Plain, 0.2), "The rest isn't split right")
	local foe = { WeaponGem = gem("a", "Fire", 5), ArmorGem = gem("b", "Shock", 5), ShieldGem = gem("c", "Fire", 5) }
	local guess = CounterGear.threat({ None = 40 }, foe)
	check(guess.Source == "Gear" and guess.Shares[1].Element == "Fire" and near(guess.Shares[1].Share, 0.8), "Their gear wasn't read (sword 3, chest 1, shield 1)")
	check(guess.TheirMain == "Shock" and guess.TheirWeak == ElementMatchup.weakTo("Shock"), "Their armor's weakness isn't named")
	local none = CounterGear.threat({}, { WeaponGem = nil })
	check(none.Source == nil and #none.Shares == 0, "A gemless foe left a threat")
	local plan = CounterGear.plan(cryoFighter(), none)
	check(plan.Changes == 0 and plan.Note ~= nil, "Nothing to resist, yet a plan")
end

-- The counter: resist gems in the helmet, gloves and boots, never Q/E/R -----------------------
do
	local profile = cryoFighter()
	for i, grade in { 9, 8, 7, 3 } do
		table.insert(profile.Gems, gem("f" .. i, "Fire", grade))
	end
	table.insert(profile.Gems, gem("p1", "Poison", 9))
	local threat = CounterGear.threat({ Fire = 100 }, nil)
	local before = CounterGear.expected(profile.Character, threat)
	check(near(before, ElementMatchup.against("Fire", ElementMatchup.profile(profile.Character))) and before > 1.2, "A Cryo build isn't weak to Thermal")
	local plan = CounterGear.plan(profile, threat)
	check(plan.Element == "Fire" and #plan.Gems == 3, "The counter didn't fill the three free sockets: " .. #plan.Gems)
	local pouch = {}
	for _, g in GemInventory.available(profile) do
		pouch[g.Id] = true
	end
	local used = {}
	for _, step in plan.Gems do
		check(table.find(CounterGear.GemSlots, step.Slot) ~= nil, "The counter touched a Q/E/R socket: " .. step.Slot)
		check(step.Element == "Fire" and pouch[step.Gem] and not used[step.Gem], "The counter used a gem it can't")
		check(step.Gem ~= "f4", "A rough gem went in before a finer one")
		check(step.From == "Frost", "The step doesn't say what it replaces")
		used[step.Gem] = true
	end
	check(plan.After < plan.Before - 0.2 and near(plan.Before, before), "The counter didn't cut Thermal by much")
	check(plan.Lines[1].Element == "Fire" and plan.Lines[1].Before > 1.2 and plan.Lines[1].After < 1, "The Thermal line isn't before/after")
	local q, e, r = profile.Character.WeaponGem, profile.Character.ArmorGem, profile.Character.ShieldGem
	apply(profile, plan)
	check(profile.Character.WeaponGem == q and profile.Character.ArmorGem == e and profile.Character.ShieldGem == r, "Q, E or R moved")
	check(near(CounterGear.expected(profile.Character, threat), plan.After), "Worn, it doesn't do what it said")
	check(CounterGear.plan(profile, threat).Changes == 0, "Countering again had more to do")
end

-- Two elements: never weak to the other one ---------------------------------------------------
do
	local profile = cryoFighter()
	for i = 1, 3 do
		table.insert(profile.Gems, gem("f" .. i, "Fire", 9))
	end
	-- Poison beats Fire: an all-Thermal armor would be weak to it.
	local threat = CounterGear.threat({ Fire = 50, Poison = 50 }, nil)
	local plan = CounterGear.plan(profile, threat)
	check(plan.After <= plan.Before + 1e-6, "The counter made the mix worse")
	for _, line in plan.Lines do
		check(line.After <= 1.25 + 1e-6, "A line went past weak")
	end
end

-- No gems of it in the pouch: says so ---------------------------------------------------------
do
	local profile = cryoFighter()
	table.insert(profile.Gems, gem("s1", "Shock", 9))
	local plan = CounterGear.plan(profile, CounterGear.threat({ Fire = 10 }, nil))
	check(plan.Note and plan.Note:find("Thermal", 1, true) ~= nil, "No Thermal gems, and no word of it: " .. tostring(plan.Note))
end

-- Pieces: one with a Defense affix of what hurt you, if it's not much weaker ------------------
do
	local profile = cryoFighter()
	local affix
	for _, a in GemConfig.Affixes do
		if a.Element == "Fire" and a.Side == "Defense" then
			affix = a.Id
			break
		end
	end
	check(affix ~= nil, "No Thermal Defense affix to test with")
	local threat = CounterGear.threat({ Fire = 100 }, nil)
	-- Every helmet you own, the same affix on the strongest other one.
	local current, best, bestRating = profile.Character.Helmet, nil, -1
	for id in profile.Owned.Helmets do
		if id ~= current then
			local trial = table.clone(profile.Character)
			trial.Helmet = id
			trial.HelmetQuality = 1
			local value = AutoEquip.rating(trial)
			if value > bestRating then
				best, bestRating = id, value
			end
		end
	end
	profile.Character.GearRolls.Helmets[best].Affixes = { { Id = affix, Bonus = 0.15 } }
	local plan = CounterGear.plan(profile, threat)
	local swapped
	for _, step in plan.Gear do
		if step.Slot == "Helmet" then
			swapped = step
		end
	end
	check(swapped and swapped.Id == best and swapped.Affix > 0, "The Thermal-affix helmet wasn't put on")
	-- A piece far weaker than yours isn't, affix or not.
	profile = cryoFighter()
	local worst, worstRating = nil, math.huge
	for id in profile.Owned.Helmets do
		local trial = table.clone(profile.Character)
		trial.Helmet = id
		trial.HelmetQuality = 1
		local value = AutoEquip.rating(trial)
		if value < worstRating then
			worst, worstRating = id, value
		end
	end
	profile.Character.Helmet = best
	profile.Character.ItemGems.Helmet[best] = profile.Character.HelmetGem
	profile.Character.GearRolls.Helmets[worst].Affixes = { { Id = affix, Bonus = 0.15 } }
	if worstRating < AutoEquip.rating(profile.Character) * CounterGear.RatingFloor then
		for _, step in CounterGear.plan(profile, threat).Gear do
			check(step.Id ~= worst, "A much weaker piece went on for its affix")
		end
	end
end

print("PASS: " .. checks .. " counter checks (what hurt you, from the round or their gear; resist gems in the free sockets, finest first; Q/E/R untouched; never weak to the mix; affix pieces within the rating floor; says why when there's nothing)")
