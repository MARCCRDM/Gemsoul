-- lune run tests/kaiju_cases.luau <repo>
-- Mini kaiju rules (Shared.Kaiju): stats by level and Gemsoul, the EXP curve
-- and its cap, infusing (stones mend it and revive it: rarity, weakness and
-- own element; only what it needs; never EXP),
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

-- Infusing --------------------------------------------------------------------------------
-- A stone's power by rarity, double of its own element, half of the one
-- that beats it; it mends, never EXP; down, it takes its revive cost at
-- once and comes back at half; only the stones it needs are used.
local Infuse = Kaiju.Infuse
local function gem(tier, element, id)
	return { Id = id or tier, Tier = tier, Element = element }
end
local fireKaiju = { Species = "Bulwark", Element = "Fire", Level = 5, Exp = 0, Soul = { Tier = "Common" } }
local weak = ElementMatchup.weakTo("Fire")
check(weak and weak ~= "Fire", "Fire has no weakness")
local neutral = "Fire"
for _, element in Kaiju.Elements do
	if element ~= "Fire" and element ~= weak then
		neutral = element
	end
end
check(Kaiju.infusePower(gem("Common", neutral), fireKaiju) == Infuse.Power.Common, "A common isn't worth its power")
check(
	Kaiju.infusePower(gem("Rare", "Fire"), fireKaiju) == Infuse.Power.Rare * Infuse.Same,
	"Its own element isn't worth more"
)
check(
	Kaiju.infusePower(gem("Rare", weak), fireKaiju) == Infuse.Power.Rare * Infuse.Weak,
	"Its weakness isn't worth less"
)
check(Kaiju.infusePower(nil, fireKaiju) == 0, "Nothing has power")
local lastPower = 0
for _, tier in { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" } do
	check(Infuse.Power[tier] > lastPower, tier .. " isn't worth more than the rarity below")
	lastPower = Infuse.Power[tier]
end
-- Its health: kept, full if never hurt, none if down.
local _, most = Kaiju.health(fireKaiju)
check(
	select(1, Kaiju.health(fireKaiju)) == most and most == Kaiju.stats("Bulwark", 5, "Common").Health,
	"Never hurt isn't full"
)
fireKaiju.Health = 30
check(select(1, Kaiju.health(fireKaiju)) == 30, "Its kept health wasn't read")
-- Mending: as many stones as it needs, no more.
local stones = {}
for i = 1, 10 do
	stones[i] = gem("Common", neutral, "c" .. i)
end
fireKaiju.Health = most - most * Infuse.Mend * 2.5
local plan = Kaiju.infusePlan(fireKaiju, stones)
check(
	#plan.Used == 3 and plan.Health == most and not plan.Revived,
	"Mending 25% didn't take three commons: " .. #plan.Used
)
check(plan.Used[1] == stones[1] and plan.Used[3] == stones[3], "It didn't use the stones in the order given")
fireKaiju.Health = most
check(#Kaiju.infusePlan(fireKaiju, stones).Used == 0, "A whole kaiju took stones")
-- Down: its revive cost all at once, or nothing.
fireKaiju.Down, fireKaiju.Health = true, 0
local cost = Kaiju.reviveCost(fireKaiju)
check(cost == Infuse.Revive.Base + Infuse.Revive.PerLevel * 5, "The revive cost isn't by level")
check(Kaiju.reviveCost({ Level = 20 }) > cost, "A higher level isn't dearer to revive")
check(select(1, Kaiju.health(fireKaiju)) == 0, "Down isn't no health")
local few = {}
for i = 1, cost - 1 do
	few[i] = gem("Common", neutral, "f" .. i)
end
plan = Kaiju.infusePlan(fireKaiju, few)
check(
	not plan.Revived and #plan.Used == 0 and plan.Short == 1,
	"A revive one short used stones, or got the shortfall wrong"
)
local enough = table.clone(few)
table.insert(enough, gem("Common", neutral, "last"))
table.insert(enough, gem("Common", neutral, "spare"))
plan = Kaiju.infusePlan(fireKaiju, enough)
check(plan.Revived and #plan.Used == cost + 1, "Revived, the spare didn't mend it")
check(
	math.abs(plan.Health - (most * Infuse.Revive.Health + most * Infuse.Mend)) < 1e-6,
	"Not back at half (and the spare's mend)"
)
-- Its own element brings it back for half the stones; its weakness takes double.
local function batch(element, count)
	local list = {}
	for i = 1, count do
		list[i] = gem("Common", element, element .. i)
	end
	return list
end
local ownNeed, weakNeed = math.ceil(cost / Infuse.Same), math.ceil(cost / Infuse.Weak)
check(Kaiju.infusePlan(fireKaiju, batch("Fire", ownNeed)).Revived, "Its own element didn't halve the revive")
check(not Kaiju.infusePlan(fireKaiju, batch("Fire", ownNeed - 1)).Revived, "Revived with too few of its own")
check(Kaiju.infusePlan(fireKaiju, batch(weak, weakNeed)).Revived, "Its weakness: enough didn't revive")
check(not Kaiju.infusePlan(fireKaiju, batch(weak, weakNeed - 1)).Revived, "Its weakness didn't double the revive")
-- A revive costs far more than mending the same health.
check(cost > (Infuse.Revive.Health / Infuse.Mend) * 2, "A revive isn't much dearer than mending")
-- Down ones fill an empty place last.
local downRoster = {
	List = {
		k1 = { Id = "k1", Species = "Bulwark", Element = "Fire", Level = 9, Down = true },
		k2 = { Id = "k2", Species = "Bulwark", Element = "Frost", Level = 2 },
	},
	Next = 3,
}
Kaiju.SlotLevels = { 1 }
check(Kaiju.teamIds(downRoster)[1] == "k2", "One down filled the team before one on its feet")
Kaiju.SlotLevels = { 1, 1, 1 }

-- Taming -----------------------------------------------------------------------------------
check(Kaiju.tameChance(60, 100) == 0 and Kaiju.tameChance(51, 100) == 0, "Tameable above half health")
check(Kaiju.tameChance(0, 100) == 0, "A dead kaiju can be tamed")
-- The tame is a cast: a couple of seconds, broken a little past where it starts.
check(Kaiju.Tame.Cast >= 1.5 and Kaiju.Tame.Cast <= 4, "The tame's cast is too quick or too slow")
check(Kaiju.Tame.Break > Kaiju.Tame.Range, "A tame breaks before you're out of its range")
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
-- The beta opens all three from the start.
check(Kaiju.slots({ List = { a = { Level = 1 } } }) == 3, "The beta doesn't open three slots at once")
local betaSlots = Kaiju.SlotLevels
Kaiju.SlotLevels = { 1, 10, 20 } -- (the plan for later)
check(Kaiju.slots({ List = { a = { Level = 9 } } }) == 1, "A second slot before level 10")
check(Kaiju.slots({ List = { a = { Level = 3 }, b = { Level = 10 } } }) == 2, "No second slot at level 10")
check(Kaiju.slots({ List = { a = { Level = 30 } } }) == 3, "More than three slots, or none at 20")
Kaiju.SlotLevels = betaSlots
check(#Kaiju.TeamSpots >= #Kaiju.SlotLevels, "A team slot with nowhere to walk")

-- Gemsouls ---------------------------------------------------------------------------------
for _, element in Kaiju.Elements do
	for seed = 1, 25 do
		local soul = Kaiju.rollSoul(Random.new(seed), element, { Id = "s" .. seed, Time = 1, Species = "Razorback" })
		check(soul.Element == element, "A Gemsoul rolled in the wrong element")
		check(Kaiju.isSoul(soul) and soul.Soul.Species == "Razorback", "Not marked as a kaiju's Gemsoul")
		local ability = Kaiju.ability(soul)
		check(ability and table.find(Kaiju.Abilities[element], ability), "Its E isn't one a kaiju casts")
		-- One stone, three moves: a Q and an R a kaiju can cast too.
		local q, r = GemTraits.traitFor(soul, "Q"), GemTraits.traitFor(soul, "R")
		check(q and table.find(Kaiju.Moves[element].Offense, q), "A Gemsoul's Q isn't one a kaiju casts")
		check(r and table.find(Kaiju.Moves[element].Defense, r), "A Gemsoul's R isn't one a kaiju casts")
		check(GemTraits.traitFor(soul, "E") == ability, "A Gemsoul's E doesn't work")
		check(soul.Tier and soul.Size and soul.Clarity and soul.Cut, "A Gemsoul isn't a whole gem")
		-- Its moves wake as it levels: E at once, Q at 5, R at 10.
		local young, five, ten = Kaiju.moves(soul, 1), Kaiju.moves(soul, 5), Kaiju.moves(soul, 10)
		check(young.E == ability and young.Q == nil and young.R == nil, "A level 1 kaiju has more than its E")
		check(Kaiju.moves(soul, 4).Q == nil and five.Q == q and five.R == nil, "Q doesn't wake at level 5")
		check(Kaiju.moves(soul, 9).R == nil and ten.R == r and ten.Q == q and ten.E == ability, "R doesn't wake at level 10")
		local id, awake = Kaiju.move(soul, "R", 3)
		check(id == r and not awake, "A sleeping R isn't named, or is awake")
	end
end
check(Kaiju.MoveLevels.E == 1 and Kaiju.MoveLevels.Q == 5 and Kaiju.MoveLevels.R == 10, "The move levels aren't E 1, Q 5, R 10")
local lanesOf = { Offense = 0, Ability = 0, Defense = 0 }
for element, lanes in Kaiju.Moves do
	check(lanes.Ability == Kaiju.Abilities[element], element .. ": Abilities isn't the E lane")
	for lane, list in lanes do
		check(#list >= 3, element .. ": too few kaiju " .. lane .. " moves")
		lanesOf[lane] += #list
		for _, id in list do
			check(table.find(GemTraits.Matrix[element][lane], id), id .. " isn't one of " .. element .. "'s " .. lane .. " moves")
			local move = GemTraits.Moves[id]
			check(move and not string.find(move.Description, "while ready"), id .. " is a passive")
			check(Kaiju.AbilityPlans[id] ~= nil, id .. " has no plan for a kaiju to cast it")
		end
	end
end
check(lanesOf.Offense == 12 and lanesOf.Defense == 12, "Not three Q and three R moves per element")
-- Q and R plans: the shapes KaijuAbilities knows, and an R's numbers.
local shapes = { Bolt = 1, Blast = 1, Nova = 1, Line = 1, Field = 1, Chain = 1, Storm = 1, Pylon = 1, Shell = 1, Ward = 1, Mend = 1 }
for id, plan in Kaiju.AbilityPlans do
	check(shapes[plan.Shape], id .. ": an unknown shape " .. tostring(plan.Shape))
	if plan.Shape == "Shell" then
		check(plan.Absorb > 0 and plan.Absorb <= 1 and plan.Duration > 0, id .. ": a shell without an absorb or a time")
	elseif plan.Shape == "Ward" then
		check(plan.Reduce > 0 and plan.Reduce < 1 and plan.Duration > 0, id .. ": a ward without a cut or a time")
	elseif plan.Shape == "Mend" then
		check(plan.Heal > 0 and plan.Duration > 0, id .. ": a mend without a heal or a time")
	end
end
-- A Gemsoul saved before Q and R woke (its Q and R rolled from the whole
-- lane): seeded into the kaiju's own, the same everywhere.
local oldSoul = { Id = "old-soul", Element = "Fire", Tier = "Rare", Soul = { Kind = "Kaiju" },
	Traits = { Offense = "Q_CinderCleave", Ability = "E_Supernova", Defense = "R_PhoenixMantle" } }
local oq = GemTraits.traitFor(oldSoul, "Q")
check(table.find(Kaiju.Moves.Fire.Offense, oq) and oq == GemTraits.traitFor(table.clone(oldSoul), "Q"), "An old Gemsoul's Q isn't seeded into a kaiju's")
check(table.find(Kaiju.Moves.Fire.Defense, GemTraits.traitFor(oldSoul, "R")), "An old Gemsoul's R isn't seeded into a kaiju's")
check(GemTraits.traitFor(oldSoul, "E") == "E_Supernova", "An old Gemsoul lost its E")
-- Each key's power: a Q hits for QPower, an R's own hits for RPower.
check(math.abs(Kaiju.abilityDamage(10, oldSoul, "Q_MagmaFault") / Kaiju.abilityDamage(10, oldSoul, "E_Supernova")
	- (Kaiju.QPower * Kaiju.AbilityPlans.Q_MagmaFault.Mult) / (Kaiju.AbilityPower * Kaiju.AbilityPlans.E_Supernova.Mult)) < 1e-6, "A Q doesn't hit for QPower")
local plain = { Id = "plain", Element = "Fire", Tier = "Rare" }
check(not Kaiju.isSoul(plain) and GemTraits.traitFor(plain, "Q") ~= nil, "A plain gem lost its Q")
local kaiju =
	Kaiju.new("k1", "Bulwark", Kaiju.rollSoul(Random.new(9), "Frost", { Id = "s", Time = 1, Species = "Bulwark" }))
check(kaiju.Element == "Frost" and kaiju.Level == 1 and Kaiju.title(kaiju) == "Cryo Bulwark", "A new kaiju is wrong")

-- Your team --------------------------------------------------------------------------------
local function soulFor(element, id)
	return Kaiju.rollSoul(Random.new(#id), element, { Id = id, Time = 1, Species = "Razorback" })
end
local profile = {}
local roster = Kaiju.roster(profile)
check(#Kaiju.teamIds(roster) == 0 and Kaiju.active(roster) == nil, "A team out with no kaiju")
local k1 = Kaiju.add(roster, "Razorback", soulFor("Fire", "s1"))
local k2 = Kaiju.add(roster, "Bulwark", soulFor("Frost", "s2"))
local k3 = Kaiju.add(roster, "Carapace", soulFor("Shock", "s3"))
local k4 = Kaiju.add(roster, "Razorback", soulFor("Toxic", "s4"))
k4.Level = 7
local ids = Kaiju.teamIds(roster)
check(#ids == 3 and ids[1] == k1.Id, "The first kaiju doesn't lead a team of three")
check(ids[2] == k4.Id and ids[3] == k2.Id, "Empty slots don't fill highest level, then oldest")
check(Kaiju.inTeam(roster, k4.Id) and not Kaiju.inTeam(roster, k3.Id), "inTeam is wrong")
Kaiju.setTeam(roster, { k3.Id, k3.Id, "nope", k2.Id })
ids = Kaiju.teamIds(roster)
check(ids[1] == k3.Id and ids[2] == k2.Id and #ids == 3, "setTeam didn't keep its order (once each, owned)")
check(roster.Active == k3.Id and Kaiju.active(roster) == k3, "The lead isn't the first of the team")
check(#roster.Team == 3, "setTeam didn't tidy the team it saved")
roster.List[k3.Id] = nil
check(Kaiju.teamIds(roster)[1] == k2.Id and #Kaiju.teamIds(roster) == 3, "A kaiju gone kept its place")
check(#Kaiju.team(roster) == 3 and Kaiju.team(roster)[1] == k2, "Kaiju.team isn't the records in order")
-- One out from before (Active, no Team) still leads.
local before = { List = { k1 = { Id = "k1", Level = 9 }, k2 = { Id = "k2", Level = 2 } }, Active = "k2" }
check(Kaiju.teamIds(before)[1] == "k2" and Kaiju.teamIds(before)[2] == "k1", "The one out from before lost the lead")

-- The starter roll ---------------------------------------------------------------------------
check(Kaiju.StarterTeam == 3, "Beta players don't start with three kaiju")
check(Kaiju.rollsOwed({}) == 3 and Kaiju.rollsOwed(nil) == 0, "A new player isn't owed three")
-- Always a full roll of three: a player from before with one is owed
-- three, not two; one who took an older roll (a short top-up) is owed a
-- full one, once; never more than there's room for.
check(Kaiju.rollsOwed({ Kaiju = { List = { k1 = {} } } }) == 3, "A player from before with one isn't owed three")
check(
	Kaiju.rollsOwed({ KaijuRolled = true, Kaiju = { List = { a = {}, b = {}, c = {} } } }) == 3,
	"An older roll isn't owed a full one"
)
check(Kaiju.rollsOwed({ KaijuRolled = Kaiju.RollVersion }) == 0, "Owed again once rolled")
local crowded = { List = {} }
for i = 1, Kaiju.MaxOwned - 1 do
	crowded.List["k" .. i] = {}
end
check(Kaiju.rollsOwed({ Kaiju = crowded }) == 1, "Owed more than there's room for")
for seed = 1, 40 do
	local picks = Kaiju.starterPicks(Random.new(seed), 3, { { Species = "Bulwark", Element = "Fire" } })
	check(#picks == 3, "Not three starter picks")
	local used = { BulwarkFire = true }
	for _, pick in picks do
		check(Kaiju.Species[pick.Species] and table.find(Kaiju.Elements, pick.Element), "A starter pick isn't real")
		check(not used[pick.Species .. pick.Element], "A starter pick repeats a kind and element")
		used[pick.Species .. pick.Element] = true
	end
end

-- Fighting as a team (Shared.Squad) -----------------------------------------------------------
local Squad = shared("Squad")
local V3 = roblox.Vector3.new
local function unit(id, x, z)
	return { Id = id, At = V3(x, 0, z) }
end
local function byDistance(current, threat)
	return function(f, e)
		local d = (f.At - e.At).Magnitude
		return Squad.cost(d, current and current[f] == e, threat and threat[e] == f)
	end
end
local function loads(plan, foes)
	local n = {}
	for _, foe in foes do
		n[foe] = 0
	end
	for _, foe in plan do
		n[foe] += 1
	end
	return n
end
-- 2 on 3: each its own (1v1s); the third waits its turn.
local a, b = unit("a", 0, 0), unit("b", 10, 0)
local three = { unit("e1", 1, 3), unit("e2", 11, 3), unit("e3", 12, 5) }
local plan = Squad.assign({ a, b }, three, byDistance())
check(plan[a] == three[1] and plan[b] == three[2], "2 on 3: not 1v1 each, nearest first")
-- 2 on 10: they never double up while there are enough, so each works
-- through its own half (five each), one at a time.
local ten = {}
for i = 1, 5 do
	table.insert(ten, unit("l" .. i, -2 - i, i))
	table.insert(ten, unit("r" .. i, 12 + i, i))
end
local kills = { [a] = 0, [b] = 0 }
local left = table.clone(ten)
local current = {}
while #left > 0 do
	local p = Squad.assign({ a, b }, left, byDistance(current))
	check(#left < 2 or p[a] ~= p[b], "Two kaiju doubled up with foes to spare")
	current = p
	-- Whoever's foe falls first (a, then b, in turn).
	local fighter = if #left % 2 == 0 then a else b
	local foe = p[fighter] or p[a] or p[b]
	kills[fighter] += 1
	table.remove(left, table.find(left, foe))
	current[fighter] = nil
end
check(kills[a] == 5 and kills[b] == 5, "2 on 10 didn't come out five each")
-- 3 on 1: all on it.  3 on 2: two and one.
local c = unit("c", 5, -6)
local lone = { unit("x", 5, 5) }
plan = Squad.assign({ a, b, c }, lone, byDistance())
check(plan[a] == lone[1] and plan[b] == lone[1] and plan[c] == lone[1], "3 on 1: not all on it")
local two = { unit("y1", 0, 4), unit("y2", 10, 4) }
local n = loads(Squad.assign({ a, b, c }, two, byDistance()), two)
check((n[two[1]] == 2 and n[two[2]] == 1) or (n[two[1]] == 1 and n[two[2]] == 2), "3 on 2: not two and one")
-- The critters' side: 10 on 2 kaiju come out five each; 3 on 2, two and one.
local swarm = {}
for i = 1, 10 do
	table.insert(swarm, unit("bug" .. i, 5 + math.cos(i) * 8, math.sin(i) * 8))
end
n = loads(Squad.assign(swarm, { a, b }, byDistance()), { a, b })
check(n[a] == 5 and n[b] == 5, "10 critters on 2 kaiju: not five each")
n = loads(Squad.assign({ swarm[1], swarm[2], swarm[3] }, { a, b }, byDistance()), { a, b })
check(n[a] + n[b] == 3 and math.abs(n[a] - n[b]) == 1, "3 critters on 2 kaiju: not two and one")
-- It keeps the foe it's on unless another is well nearer; one after it counts nearer.
local near, far = unit("near", 0, 6), unit("far", 0, 9)
check(Squad.assign({ a }, { near, far }, byDistance({ [a] = far }))[a] == far, "Swapped for a foe barely nearer")
check(Squad.assign({ a }, { near, far }, byDistance(nil, { [far] = a }))[a] == far, "Ignored the foe after it")
check(
	Squad.assign({ a }, { unit("z", 0, 2), unit("z2", 0, 40) }, byDistance({ [a] = nil }))[a].Id == "z",
	"Not the nearest"
)
-- A foe it mustn't take (math.huge) it never gets; with a cap, the rest go without.
plan = Squad.assign({ a, b }, { near }, function(f, e)
	return if f == b then math.huge else 1
end)
check(plan[a] == near and plan[b] == nil, "Given a foe it mustn't take")
plan = Squad.assign({ a, b, c }, { near }, byDistance(), 2)
check(loads(plan, { near })[near] == 2 and next(plan) ~= nil, "A cap of two let three on")
check(
	next(Squad.assign({}, three, byDistance())) == nil and next(Squad.assign({ a }, {}, byDistance())) == nil,
	"Nothing to share"
)
-- Round a shared foe: two on opposite sides, three a third of a turn apart,
-- each keeping its side.
local center = V3(0, 0, 0)
local slots = Squad.slots(center, { V3(3, 0, 0.2), V3(3, 0, -0.2) })
check(slots[1]:Dot(slots[2]) < -0.99, "Two on one foe aren't on opposite sides")
slots = Squad.slots(center, { V3(4, 0, 1), V3(4, 0, 0), V3(4, 0, -1) })
for i = 1, 3 do
	for j = i + 1, 3 do
		check(math.abs(slots[i]:Dot(slots[j]) + 0.5) < 1e-6, "Three on one foe aren't a third of a turn apart")
	end
end
slots = Squad.slots(center, { V3(5, 0, 0), V3(0, 0, 5), V3(-5, 0, 0), V3(0, 0, -5) })
for i, at in { V3(5, 0, 0), V3(0, 0, 5), V3(-5, 0, 0), V3(0, 0, -5) } do
	check(slots[i]:Dot(at.Unit) > 0.999, "Spread already: a slot moved anyway")
end
check(
	#Squad.slots(center, {}) == 0 and Squad.slots(center, { V3(0, 0, 3) })[1]:Dot(V3(0, 0, 1)) > 0.999,
	"One alone moved"
)
-- Round its foe, not through it: a turn of at most maxAngle at a time.
local turned = Squad.toward(V3(1, 0, 0), V3(-1, 0, 0.01), math.rad(50))
check(math.abs(math.deg(math.acos(turned:Dot(V3(1, 0, 0)))) - 50) < 0.01, "Turned more than its step")
check(
	Squad.toward(V3(1, 0, 0), V3(1, 0, 0.2), math.rad(50)):Dot(V3(1, 0, 0.2).Unit) > 0.9999,
	"Didn't reach a near slot"
)
-- Apart: pushed off one too close, nothing from one far off.
local push = Squad.apart(V3(0, 0, 0), { V3(2, 0, 0) }, 5)
check(push.X < -2.9 and push.X > -3.1 and math.abs(push.Z) < 1e-6, "Not pushed off one too close")
check(Squad.apart(V3(0, 0, 0), { V3(8, 0, 0) }, 5).Magnitude == 0, "Pushed off one far away")
check(Squad.apart(V3(0, 0, 0), { V3(0, 0, 0) }, 5).Magnitude > 4, "Two on the same spot stay put")

-- How big each stands next to you (its moves and effects that big): yours
-- under half your size, a wild one smaller than you, the guardian about
-- your size, a critter about half.
local pet, wild, guard = Kaiju.size(Kaiju.Scale.Pet), Kaiju.size(Kaiju.Scale.Wild), Kaiju.size(Kaiju.Scale.Guardian)
check(pet < 0.5 and pet < wild and wild < guard and guard <= 1, "Kaiju sizes out of order")
check(Kaiju.Bug.Size > pet and Kaiju.Bug.Size < wild, "A critter isn't between a pet and a wild kaiju")
check(Kaiju.size(1) == Kaiju.Height, "A model at scale 1 isn't its height")
print(
	string.format(
		"PASS: %d kaiju rule checks (stats, EXP, infusing and revives, taming, spread, slots, Gemsouls, your team, the starter roll, fighting as a team, sizes)",
		checks
	)
)
