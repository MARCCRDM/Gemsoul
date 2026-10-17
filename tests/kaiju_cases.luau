-- lune run tests/kaiju_cases.luau <repo>
-- Mini kaiju rules (Shared.Kaiju): stats by level and Gemsoul, the EXP curve
-- and its cap, feeding (rarity falloff by level, weakness and own element),
-- the tame chance curve, the hit spread, team slots, and Gemsouls (rolled in
-- the kaiju's element, an E ability of that element, and only the E wakes).
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

local Kaiju = shared("Kaiju")
local GemTraits = shared("GemTraits")
local ElementMatchup = shared("ElementMatchup")

-- Species and stats ------------------------------------------------------------------------
check(#Kaiju.Order == 3 and #Kaiju.Elements == 4, "Three species in four elements")
local seen = {}
for _, id in Kaiju.Order do
	local s = Kaiju.Species[id]
	check(s and s.Id == id and s.Name and s.Blurb, id .. " isn't described")
	local key = s.Health .. "/" .. s.Speed
	check(not seen[key], id .. " plays like another species")
	seen[key] = true
	local one, ten = Kaiju.stats(id, 1, "Common"), Kaiju.stats(id, 10, "Common")
	check(ten.Health > one.Health and ten.Damage > one.Damage, id .. " doesn't grow with level")
	local legendary = Kaiju.stats(id, 10, "Legendary")
	check(legendary.Health > ten.Health, id .. ": a finer Gemsoul isn't stronger")
	check(Kaiju.stats(id, 99).Health == Kaiju.stats(id, Kaiju.MaxLevel).Health, id .. " grows past the cap")
end
check(Kaiju.Species.Razorback.Speed > Kaiju.Species.Bulwark.Speed, "The runner isn't the quick one")
check(Kaiju.Species.Carapace.Guard > Kaiju.Species.Bulwark.Guard, "The shell isn't the hardest")

-- EXP --------------------------------------------------------------------------------------
for level = 1, Kaiju.MaxLevel - 2 do
	check(Kaiju.expToNext(level + 1) > Kaiju.expToNext(level), "The EXP curve isn't rising at " .. level)
end
check(Kaiju.expToNext(Kaiju.MaxLevel) == math.huge, "EXP past the cap")
local record = { Level = 1, Exp = 0, Element = "Fire" }
check(
	Kaiju.addExp(record, Kaiju.expToNext(1)) == 1 and record.Level == 2 and record.Exp == 0,
	"A level's worth didn't level it"
)
check(Kaiju.addExp(record, 1e9) > 0 and record.Level == Kaiju.MaxLevel and record.Exp == 0, "No cap on levels")
check(Kaiju.addExp(record, 100) == 0 and record.Level == Kaiju.MaxLevel, "EXP added past the cap")
check(
	Kaiju.killExp(10) > Kaiju.killExp(1) and Kaiju.killExp(1) > Kaiju.Bug.Exp,
	"A kaiju kill isn't worth more than a bug"
)

-- Feeding ----------------------------------------------------------------------------------
local function feed(tier, element, level, kaijuElement)
	return Kaiju.feedExp({ Tier = tier, Element = element }, { Level = level, Element = kaijuElement or "Fire" })
end
check(feed("Common", "Shock", 5) == Kaiju.FeedExp.Common, "A common stone isn't worth its full EXP early on")
check(feed("Common", "Shock", 15) == Kaiju.FeedExp.Common // 2, "A common stone isn't halved past level 10")
check(feed("Common", "Shock", 25) == Kaiju.FeedExp.Common // 4, "A common stone isn't a quarter past level 20")
check(feed("Legendary", "Shock", 30) == Kaiju.FeedExp.Legendary, "A legendary stone lost its worth")
check(feed("Rare", "Shock", 25) == Kaiju.FeedExp.Rare // 2, "A rare stone isn't halved past level 20")
local weak = ElementMatchup.weakTo("Fire")
check(weak and weak ~= "Fire", "Fire has no weakness")
check(feed("Rare", weak, 5) == math.floor(Kaiju.FeedExp.Rare * Kaiju.FeedWeak), "Its weakness element isn't halved")
check(feed("Rare", "Fire", 5) == math.floor(Kaiju.FeedExp.Rare * Kaiju.FeedSame), "Its own element isn't a bonus")
check(
	feed("Common", weak, 25) < feed("Common", "Shock", 25) and feed("Common", weak, 25) > 0,
	"A weak common stone on a high kaiju isn't the least (but some)"
)
for _, tier in { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" } do
	for level = 1, Kaiju.MaxLevel - 1 do
		check(feed(tier, "Shock", level + 1) <= feed(tier, "Shock", level), tier .. " grows worth with level")
	end
end
check(Kaiju.feedExp(nil, { Level = 1 }) == 0, "Feeding nothing gave EXP")

-- Taming -----------------------------------------------------------------------------------
check(Kaiju.tameChance(60, 100) == 0 and Kaiju.tameChance(51, 100) == 0, "Tameable above half health")
check(Kaiju.tameChance(0, 100) == 0, "A dead kaiju can be tamed")
check(math.abs(Kaiju.tameChance(50, 100) - 0.05) < 1e-9, "5% at half health")
check(math.abs(Kaiju.tameChance(30, 100) - 0.15) < 1e-9, "15% at 30%")
check(math.abs(Kaiju.tameChance(15, 100) - 0.35) < 1e-9, "35% at 15%")
check(math.abs(Kaiju.tameChance(5, 100) - 0.6) < 1e-9, "60% at 5%")
check(Kaiju.tameChance(1, 1000) > 0.75 and Kaiju.tameChance(1, 1000) <= 0.8, "Near 80% at 1 HP")
local last = -1
for hp = 50, 1, -1 do
	local chance = Kaiju.tameChance(hp, 100)
	check(chance >= last, "The tame chance fell as health fell, at " .. hp)
	last = chance
end
local lo, hi = math.huge, -math.huge
local rng = Random.new(4)
for _ = 1, 2000 do
	local s = Kaiju.spread(rng)
	lo, hi = math.min(lo, s), math.max(hi, s)
end
check(lo >= 0.6 and hi <= 1.4 and lo < 0.65 and hi > 1.35, "Hits don't spread 60%-140%")

-- Team slots -------------------------------------------------------------------------------
check(Kaiju.slots(nil) == 1 and Kaiju.slots({ List = {} }) == 1, "No starting slot")
check(Kaiju.slots({ List = { a = { Level = 9 } } }) == 1, "A second slot before level 10")
check(Kaiju.slots({ List = { a = { Level = 3 }, b = { Level = 10 } } }) == 2, "No second slot at level 10")
check(Kaiju.slots({ List = { a = { Level = 30 } } }) == 3, "More than three slots, or none at 20")

-- Gemsouls ---------------------------------------------------------------------------------
for _, element in Kaiju.Elements do
	for seed = 1, 25 do
		local soul = Kaiju.rollSoul(Random.new(seed), element, { Id = "s" .. seed, Time = 1, Species = "Razorback" })
		check(soul.Element == element, "A Gemsoul rolled in the wrong element")
		check(Kaiju.isSoul(soul) and soul.Soul.Species == "Razorback", "Not marked as a kaiju's Gemsoul")
		local ability = Kaiju.ability(soul)
		check(ability and table.find(Kaiju.Abilities[element], ability), "Its E isn't one a kaiju casts")
		check(GemTraits.traitFor(soul, "Q") == nil and GemTraits.traitFor(soul, "R") == nil, "A Gemsoul woke Q or R")
		check(GemTraits.traitFor(soul, "E") == ability, "A Gemsoul's E doesn't work")
		check(soul.Tier and soul.Size and soul.Clarity and soul.Cut, "A Gemsoul isn't a whole gem")
	end
end
for element, list in Kaiju.Abilities do
	check(#list >= 3, element .. ": too few kaiju abilities")
	for _, id in list do
		check(table.find(GemTraits.Matrix[element].Ability, id), id .. " isn't one of " .. element .. "'s E moves")
		local move = GemTraits.Moves[id]
		check(move and not string.find(move.Description, "while ready"), id .. " is a passive")
	end
end
local plain = { Id = "plain", Element = "Fire", Tier = "Rare" }
check(not Kaiju.isSoul(plain) and GemTraits.traitFor(plain, "Q") ~= nil, "A plain gem lost its Q")
local kaiju =
	Kaiju.new("k1", "Bulwark", Kaiju.rollSoul(Random.new(9), "Frost", { Id = "s", Time = 1, Species = "Bulwark" }))
check(kaiju.Element == "Frost" and kaiju.Level == 1 and Kaiju.title(kaiju) == "Frost Bulwark", "A new kaiju is wrong")

print(string.format("PASS: %d kaiju rule checks (stats, EXP, feeding, taming, spread, slots, Gemsouls)", checks))
