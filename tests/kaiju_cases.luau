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
check(#Kaiju.Order == 33 and #Kaiju.Elements == 4, "Thirty-three species in four elements")
check(#Kaiju.Starters == 4, "Not four starters")
for i, id in { "Bulwark", "Razorback", "Carapace", "Scythe" } do
	check(Kaiju.Starters[i] == id and Kaiju.Order[i] == id, "The starters aren't the first four")
end
local seen = {}
for _, id in Kaiju.Order do
	local s = Kaiju.Species[id]
	check(s and s.Id == id and s.Name and s.Blurb, id .. " isn't described")
	local key = s.Health .. "/" .. s.Speed .. "/" .. s.Damage .. "/" .. s.Rate
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
-- The assassin: the least health of the first four, and quicker blows and
-- feet than the front liners'.
local scythe = Kaiju.Species.Scythe
for _, id in Kaiju.Starters do
	local s = Kaiju.Species[id]
	check(id == "Scythe" or s.Health > scythe.Health, "The assassin isn't the frailest")
	check(
		id == "Scythe" or id == "Razorback" or (s.Rate > scythe.Rate and s.Speed < scythe.Speed),
		"The assassin is slower than a front liner"
	)
end
-- Over all 32, each role keeps its shape: every tank outlasts every
-- warrior, every warrior every assassin; every assassin outruns every tank
-- and warrior; a tank is the hardest to hurt, a warrior hits hardest.
local byRole = {}
for _, id in Kaiju.Order do
	local s = Kaiju.Species[id]
	byRole[s.Role] = byRole[s.Role] or {}
	table.insert(byRole[s.Role], s)
end
for _, role in { "Tank", "Warrior", "Ranged", "Assassin", "Breaker", "Warden" } do
	check(byRole[role] and #byRole[role] >= 1, "No " .. role)
end
local function every(a, b, test)
	for _, x in byRole[a] do
		for _, y in byRole[b] do
			if not test(x, y) then
				return false, x.Id .. " / " .. y.Id
			end
		end
	end
	return true
end
local function ok(a, b, test, message)
	local fine, who = every(a, b, test)
	check(fine, message .. " (" .. tostring(who) .. ")")
end
ok("Tank", "Warrior", function(x, y) return x.Health > y.Health end, "A warrior outlasts a tank")
ok("Warrior", "Assassin", function(x, y) return x.Health > y.Health end, "An assassin outlasts a warrior")
ok("Assassin", "Tank", function(x, y) return x.Speed > y.Speed end, "A tank outruns an assassin")
ok("Assassin", "Warrior", function(x, y) return x.Speed > y.Speed end, "A warrior outruns an assassin")
ok("Tank", "Ranged", function(x, y) return x.Guard > y.Guard end, "A ranged kaiju is harder to hurt than a tank")
ok("Warrior", "Ranged", function(x, y) return x.Damage > y.Damage end, "A ranged kaiju hits as hard as a warrior")
ok("Breaker", "Assassin", function(x, y) return x.Health > y.Health end, "A breaker is as frail as an assassin")

-- Wild kinds by habitat: the first four and the roster's Fringe kinds out
-- anywhere past the core, its Edge kinds only at the Edge, its Vein kinds
-- only as the guarded vein's guardian.
do
	local Roster = shared("KaijuRoster")
	local fringe, edge, vein = {}, {}, {}
	for _, id in Kaiju.wildKinds("Fringe") do
		fringe[id] = true
	end
	for _, id in Kaiju.wildKinds("Edge") do
		edge[id] = true
	end
	for _, id in Kaiju.wildKinds("Vein") do
		vein[id] = true
	end
	for _, id in Kaiju.Starters do
		check(not fringe[id] and not edge[id] and not vein[id], id .. " should remain owned/starter-only")
	end
	local counts = { Fringe = 0, Edge = 0, Vein = 0 }
	for _, id in Roster.Order do
		local habitat = Roster.Kinds[id].Habitat
		check(counts[habitat], id .. ": no habitat")
		counts[habitat] += 1
		check(fringe[id] == (Kaiju.WildRoster[id] and habitat == "Fringe" or nil), id .. ": wrong in the Fringe")
		check(edge[id] == (Kaiju.WildRoster[id] and habitat ~= "Vein" or nil), id .. ": wrong at the Edge")
		check(vein[id] == (Kaiju.WildRoster[id] and habitat == "Vein" or nil), id .. ": wrong as the guardian")
	end
	check(counts.Fringe >= 4 and counts.Edge >= 10 and counts.Vein >= 2, "The habitats are lopsided")
end

-- EXP --------------------------------------------------------------------------------------
for level = 1, Kaiju.MaxLevel - 2 do
	check(Kaiju.expToNext(level + 1) > Kaiju.expToNext(level), "The EXP curve isn't rising at " .. level)
end
-- Levelling is slow: level 10 takes thousands of EXP (a kill at 10 is about 100).
do
	local total = 0
	for level = 1, 9 do
		total += Kaiju.expToNext(level)
	end
	check(total >= 15000, "Level 10 comes too easily: " .. total .. " EXP")
	check(Kaiju.killExp(10) <= 110, "EXP comes too fast")
	-- Your rocks level you, not your kaiju (Shared.Levelling).
	check(Kaiju.mineExp == nil and Kaiju.MineExp == nil, "Kaiju still get EXP for your mining")
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
local Infuse = table.clone(Kaiju.Infuse)
-- Selection fixtures below use a level-five kaiju and common-gem units.
Infuse.Mend *= Kaiju.Infuse.LowTierBoost / (1 + 4 * Kaiju.Infuse.LowTierLevelDecay)
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
check(math.abs(Kaiju.infusePower(gem("Common", neutral), fireKaiju) * Kaiju.Infuse.Mend - 0.125) < 1e-8, "Level-five Common should heal 12.5%")
do
	for _, tier in { "Common", "Uncommon" } do
		local last = math.huge
		for _, level in { 1, 5, 10, 21, 40, 100 } do
			local probe = { Element = "Fire", Level = level }
			local power = Kaiju.infusePower(gem(tier, neutral), probe)
			check(power > 0 and power < last, "Low-tier healing must decline as level rises")
			check(Kaiju.infusePower(gem(tier, "Fire"), probe) == power * Infuse.Same, "Matching-element healing lost its bonus")
			last = power
		end
	end
	check(Kaiju.infusePower(gem("Common", neutral), { Element = "Fire", Level = 1 }) * Kaiju.Infuse.Mend == 0.15, "Starter Common healing")
	check(Kaiju.infusePower(gem("Uncommon", neutral), { Element = "Fire", Level = 1 }) * Kaiju.Infuse.Mend == 0.3, "Starter Uncommon healing")
end
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
	#plan.Used == 3 and plan.Health == most,
	"Mending 25% didn't take three commons: " .. #plan.Used
)
check(plan.Used[1] == stones[1] and plan.Used[3] == stones[3], "It didn't use the stones in the order given")
fireKaiju.Health = most
check(#Kaiju.infusePlan(fireKaiju, stones).Used == 0, "A whole kaiju took stones")
-- Down: gems don't bring it back. It's back by itself once its revive
-- time is up (longer the higher its level), or at once for Robux or a
-- coupon (the server).
fireKaiju.Down, fireKaiju.Health = true, 0
local wait = Kaiju.reviveSeconds(fireKaiju)
check(wait == Kaiju.Revive.Base + Kaiju.Revive.PerLevel * 5, "The revive wait isn't by level")
check(Kaiju.reviveSeconds({ Level = 20 }) > wait, "A higher level doesn't wait longer")
check(Kaiju.Revive.Health > 0 and Kaiju.Revive.Health <= 0.2, "Back by itself, it isn't weak")
check(Kaiju.Revive.Bought > Kaiju.Revive.Health and Kaiju.Revive.Bought <= 1, "Bought back isn't stronger")
check(select(1, Kaiju.health(fireKaiju)) == 0, "Down isn't no health")
local manyStones = {}
for i = 1, 200 do
	manyStones[i] = gem("Common", neutral, "f" .. i)
end
plan = Kaiju.infusePlan(fireKaiju, manyStones)
check(#plan.Used == 0 and plan.Power == 0 and plan.Health == 0, "Gems went into one that's down")
fireKaiju.DownUntil = 1000 + wait
check(Kaiju.reviveIn(fireKaiju, 1000) == wait, "The time left to its revive")
check(Kaiju.reviveIn(fireKaiju, 1000 + wait + 5) == 0, "Past its revive time, still waiting")
check(Kaiju.reviveIn({ Level = 3 }, 1000) == 0, "One that's up has a revive wait")
fireKaiju.DownUntil = nil
-- Danger: no healing in a fight (hit or hitting lately, or critters near).
check(Kaiju.Danger.Calm > 0 and Kaiju.Danger.Radius > 0, "The danger rules")
local function batch(element, count)
	local list = {}
	for i = 1, count do
		list[i] = gem("Common", element, element .. i)
	end
	return list
end
-- Picking the gems for a heal (healPick): the strongest first (its own
-- element), never a Gemsoul, none for one that's down; to full, or only
-- the ones that fit.
local mixed = { gem("Common", neutral, "n1"), gem("Common", weak, "w1"), gem("Common", "Fire", "o1"), gem("Common", neutral, "n2") }
local soulGem = gem("Common", "Fire", "soul")
soulGem.Soul = { Kind = "Kaiju" }
table.insert(mixed, soulGem)
fireKaiju.Down, fireKaiju.Health = nil, most - most * Infuse.Mend * 2.5
local picked = Kaiju.healPick(fireKaiju, mixed, false)
-- (25% short: its own element's 20%, then the 5% of its weakness's fits
-- where a plain one's 10% wouldn't.)
check(#picked == 2 and picked[1].Id == "o1" and picked[2].Id == "w1", "A heal didn't take its own element first, then only what fits")
picked = Kaiju.healPick(fireKaiju, mixed, true)
check(#picked == 2 and picked[1].Id == "o1" and picked[2].Id == "n1", "Healing to full didn't take the strongest to full")
for _, g in picked do
	check(g ~= soulGem, "A heal took a Gemsoul")
end
fireKaiju.Health = most
check(#Kaiju.healPick(fireKaiju, mixed, true) == 0, "A whole kaiju was picked gems")
fireKaiju.Down, fireKaiju.Health = true, 0
check(#Kaiju.healPick(fireKaiju, batch(neutral, 200), true) == 0, "One that's down was picked gems")
fireKaiju.Down, fireKaiju.Health = nil, nil
-- Auto heal: off till switched on, kept in the roster; Commons only.
check(Kaiju.autoHealOn({ List = {} }) and Kaiju.autoHealOn({ List = {}, AutoHeal = true }), "Auto heal must default on")
check(not Kaiju.autoHealOn({ AutoHeal = false }), "Explicit auto-heal opt-out must persist")
check(
	Kaiju.AutoHeal.Tiers[1] == "Common" and Kaiju.AutoHeal.Tiers[2] == "Uncommon" and #Kaiju.AutoHeal.Tiers == 2,
	"Auto heal doesn't take Commons, then Uncommons, and nothing rarer"
)
check(Kaiju.AutoHeal.Every > 0, "Auto heal's rules")
-- Auto heal's pick (autoHealPick): Commons first; an Uncommon only once
-- every spare Common is used; none wasted; none for one that's down.
fireKaiju.Down, fireKaiju.Health = nil, most - most * Infuse.Mend * 3.5
local pools = {
	Common = { gem("Common", neutral, "c1"), gem("Common", neutral, "c2") },
	Uncommon = { gem("Uncommon", neutral, "u1"), gem("Uncommon", neutral, "u2") },
}
picked = Kaiju.autoHealPick(fireKaiju, pools)
-- (35% short: both Commons mend 20%; the 15% left is too little for an
-- Uncommon's 20%, so none goes to waste.)
check(
	#picked == 2 and picked[1].Tier == "Common" and picked[2].Tier == "Common",
	"Auto heal didn't take the Commons first"
)
fireKaiju.Health = most - most * Infuse.Mend * 5
picked = Kaiju.autoHealPick(fireKaiju, pools)
check(
	#picked == 3 and picked[1].Tier == "Common" and picked[2].Tier == "Common" and picked[3].Tier == "Uncommon",
	"Out of Commons, auto heal didn't go on with an Uncommon"
)
pools.Common = {
	gem("Common", neutral, "c1"),
	gem("Common", neutral, "c2"),
	gem("Common", neutral, "c3"),
	gem("Common", neutral, "c4"),
}
fireKaiju.Health = most - most * Infuse.Mend * 2.5
picked = Kaiju.autoHealPick(fireKaiju, pools)
check(
	#picked == 2 and picked[1].Tier == "Common" and picked[2].Tier == "Common",
	"Auto heal took an Uncommon while Commons were left"
)
pools.Common = {}
fireKaiju.Health = most - most * Infuse.Mend * 1.5
picked = Kaiju.autoHealPick(fireKaiju, pools)
check(#picked == 0, "Auto heal wasted an Uncommon (20%) on 15% short")
fireKaiju.Health = most - most * Infuse.Mend * 4
picked = Kaiju.autoHealPick(fireKaiju, pools)
check(#picked == 2 and picked[1].Tier == "Uncommon", "No Commons at all, auto heal didn't take Uncommons")
fireKaiju.Down, fireKaiju.Health = true, 0
check(#Kaiju.autoHealPick(fireKaiju, pools) == 0, "Auto heal picked gems for one that's down")
fireKaiju.Down, fireKaiju.Health = nil, nil
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
-- (Taunt, Rally, Leap, Vault, Flurry and Vanish: the roles' own moves, Shared.KaijuRoles.)
local shapes = {
	Bolt = 1,
	Blast = 1,
	Nova = 1,
	Line = 1,
	Field = 1,
	Chain = 1,
	Storm = 1,
	Pylon = 1,
	Shell = 1,
	Ward = 1,
	Mend = 1,
	Taunt = 1,
	Rally = 1,
	Leap = 1,
	Vault = 1,
	Flurry = 1,
	Vanish = 1,
}
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
-- Its gem surge, beside its own moves: its Gemsoul's E, always of its
-- element (a Gemsoul is), with a way to cast it; none from a plain gem.
for _, element in Kaiju.Elements do
	for seed = 1, 24 do
		local soul = Kaiju.rollSoul(Random.new(seed), element, { Id = "g" .. seed, Time = 1, Species = "Emberjaw" })
		local id = Kaiju.gemSurge(soul)
		check(id ~= nil and id == Kaiju.ability(soul), element .. ": its gem surge isn't its Gemsoul's E")
		check(table.find(Kaiju.Moves[element].Ability, id) ~= nil, element .. ": its gem surge isn't its element's: " .. tostring(id))
		check(Kaiju.AbilityPlans[id] ~= nil, "No way to cast the gem surge " .. tostring(id))
	end
end
check(Kaiju.gemSurge(plain) == nil and Kaiju.gemSurge(nil) == nil, "A plain gem gave a gem surge")
check(Kaiju.GemSurge.Every > Kaiju.AbilityEvery and Kaiju.GemSurge.First > 0, "The gem surge's timing")
-- Only a gem of its own element can enchant it (canSocket): attuned, harder
-- hits (recordStats) and its gem surge (recordSurge, a mined gem's E it
-- can't cast giving way to its element's first). It keeps its element.
do
	local born = Kaiju.rollSoul(Random.new(5), "Frost", { Id = "s1", Time = 1, Species = "Bulwark" })
	local rec = Kaiju.new("k1", "Bulwark", born, 6)
	check(Kaiju.attuned(rec) and rec.Element == "Frost", "A kaiju isn't attuned to the enchant it was born with")
	local plainStats = Kaiju.stats("Bulwark", 6, born.Tier)
	local attunedStats = Kaiju.recordStats(rec)
	check(
		math.abs(attunedStats.Damage - math.floor(plainStats.Damage * Kaiju.Attuned.Power * 10 + 0.5) / 10) < 1e-9
			and attunedStats.Health == plainStats.Health,
		"Attuned: its damage isn't Attuned.Power more (or its health changed)"
	)
	check(Kaiju.recordSurge(rec) == Kaiju.gemSurge(born), "Attuned: its gem surge isn't its enchant's E")
	-- Another element's gem never goes in, whatever its rarity.
	for _, element in { "Fire", "Shock", "Poison" } do
		local ok, why = Kaiju.canSocket(rec, { Id = "m1", Element = element, Tier = "Legendary" })
		check(not ok and why == "Only a Cryo gem can enchant a Cryo kaiju.", element .. " enchanted a Cryo kaiju: " .. tostring(why))
	end
	check(Kaiju.canSocket(rec, { Id = "m3", Element = "Frost", Tier = "Common" }), "A Cryo gem can't enchant a Cryo kaiju")
	local ion = Kaiju.new("k5", "Razorback", Kaiju.rollSoul(Random.new(6), "Shock", { Id = "s5", Time = 1 }), 2)
	local _, ionWhy = Kaiju.canSocket(ion, { Id = "m5", Element = "Fire", Tier = "Rare" })
	check(ionWhy == "Only an Ion gem can enchant an Ion kaiju.", "Ion's refusal: " .. tostring(ionWhy))
	check(not Kaiju.canSocket(rec, born), "Its own enchant went in again")
	check(not Kaiju.canSocket(rec, { Id = "x" }) and not Kaiju.canSocket(nil, born), "A gem with no element, or no kaiju")
	-- How it'd stand with another (enchanted): a rarer gem of its element,
	-- stronger and still attuned; the record itself untouched.
	local legendGem = { Id = "m4", Element = "Frost", Tier = "Legendary" }
	local would = Kaiju.enchanted(rec, legendGem)
	check(would and would.Attuned and would.Tier == "Legendary", "enchanted: not attuned with its own element")
	check(would.Stats.Health == Kaiju.stats("Bulwark", 6, "Legendary").Health, "enchanted: not a Legendary's stats")
	check(would.Surge ~= nil and Kaiju.AbilityPlans[would.Surge] ~= nil, "enchanted: no surge it can cast")
	check(rec.Soul == born, "enchanted changed the kaiju itself")
	-- An old enchant of another element (from before they had to match):
	-- stronger by its rarity, never attuned, no surge, its element kept.
	rec.Soul = { Id = "m1", Element = "Fire", Tier = "Legendary" }
	check(not Kaiju.attuned(rec) and rec.Element == "Frost", "Another element's gem attuned it, or changed its element")
	check(Kaiju.recordSurge(rec) == nil, "Another element's gem gave a gem surge")
	local legendary = Kaiju.recordStats(rec)
	check(legendary.Damage == Kaiju.stats("Bulwark", 6, "Legendary").Damage, "Another element's gem: its rarity's stats")
	check(legendary.Health > plainStats.Health or born.Tier == "Legendary", "A Legendary gem didn't make it stronger")
	check(Kaiju.canSocket(rec, born), "Its own element couldn't take an old enchant's place")
	-- A mined gem of its element: attuned, and a surge it can cast.
	for _, element in Kaiju.Elements do
		local mined = { Id = "m2", Element = element, Tier = "Rare" }
		local own = Kaiju.new("k2", "Scythe", Kaiju.rollSoul(Random.new(9), element, { Id = "s2", Time = 1 }), 3)
		check(Kaiju.canSocket(own, mined), element .. ": a mined gem of its element can't enchant it")
		own.Soul = mined
		local id = Kaiju.recordSurge(own)
		check(Kaiju.attuned(own) and id ~= nil and Kaiju.AbilityPlans[id] ~= nil, element .. ": a mined gem of its element, no surge")
		check(table.find(Kaiju.Moves[element].Ability, id) ~= nil, element .. ": its surge isn't its element's")
	end
end
-- Names (cleanName, nameOf): letters (accented ones too), numbers, spaces,
-- - ' and ., up to NameMax, a letter in it; "" is no name.
do
	for text, want in {
		["Frosty"] = "Frosty",
		["  Big   Al  "] = "Big Al",
		["Pequeño"] = "Pequeño",
		["José María"] = "José María",
		["Zed-2"] = "Zed-2",
		["O'Malley"] = "O'Malley",
		["Dr. Bite"] = "Dr. Bite",
		[""] = "",
		["    "] = "",
	} do
		local got, why = Kaiju.cleanName(text)
		check(got == want, string.format("cleanName(%q) gave %q (%s)", text, tostring(got), tostring(why)))
	end
	for _, text in { "123", "a_b", "Thisnameiswaytoolong", "x😀", "<b>hi</b>", "@@@" } do
		local got, why = Kaiju.cleanName(text)
		check(got == nil and type(why) == "string", "cleanName took " .. text)
	end
	check(Kaiju.cleanName(nil) == nil and Kaiju.cleanName(7) == nil, "cleanName took a non-string")
	check(#Kaiju.cleanName(string.rep("a", Kaiju.NameMax)) == Kaiju.NameMax, "A name NameMax long refused")
	local named = Kaiju.new("k9", "Razorback", Kaiju.rollSoul(Random.new(3), "Frost", { Id = "n", Time = 1 }), 2)
	check(Kaiju.nameOf(named) == "Cryo Razorback", "No name: not its title")
	named.Name = "Frosty"
	check(Kaiju.nameOf(named) == "Frosty" and Kaiju.title(named) == "Cryo Razorback", "Its name isn't used, or replaced its title")
	named.Name = ""
	check(Kaiju.nameOf(named) == "Cryo Razorback" and Kaiju.nameOf(nil) == "Kaiju", "An empty name isn't its title")
end
-- A finer Gemsoul's surge hits harder (its output), as its stats are.
local legend = table.clone(oldSoul)
legend.Tier = "Legendary"
local common = table.clone(oldSoul)
common.Tier = "Common"
check(
	Kaiju.abilityDamage(10, legend, "E_Supernova") > Kaiju.abilityDamage(10, common, "E_Supernova") * 1.5,
	"A Legendary's gem surge isn't much harder than a Common's"
)
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
-- Moon bugs come as swarms (Kaiju.wave): weak alone, and the ranged one
-- (Crocodilo) never alone, always at the back.
do
	local roster = shared("DungeonRules").Roster
	check(#Kaiju.Critters == #roster, "The critters aren't the roster")
	for i, spec in roster do
		check(Kaiju.Critters[i] == spec.Id and Kaiju.BugMoves[spec.Id], "No critter " .. spec.Id)
	end
	check(Kaiju.isRanged("Crocodilo") and not Kaiju.isRanged("Sahur") and not Kaiju.isRanged(nil), "Who's ranged")
	local croc = Kaiju.BugMoves.Crocodilo
	check(croc.Keep > croc.Flee and croc.Range > croc.Keep, "The bomber can't keep its distance")
	check(Kaiju.Bug.Damage <= 2 and Kaiju.Bug.Health <= 40, "A critter is no weaker for coming in swarms")
	local r = Random.new(11)
	local withRanged, alone = 0, 0
	for _ = 1, 2000 do
		local count = r:NextInteger(1, 9)
		local wave = Kaiju.wave(count, r)
		check(#wave == count, "A swarm came the wrong size")
		local ranged, seenRanged = 0, false
		for _, id in wave do
			if Kaiju.isRanged(id) then
				ranged += 1
				seenRanged = true
			else
				check(not seenRanged, "A fighter came through after a ranged one")
			end
		end
		check(ranged < count, "A swarm of only ranged ones")
		check(count >= Kaiju.Swarm.Ranged.Min or ranged == 0, "A ranged one in a swarm too small for it")
		check(ranged <= math.max(1, math.floor(count / Kaiju.Swarm.Ranged.Every)), "Too many ranged ones")
		if ranged > 0 then
			withRanged += 1
		end
		if count == 1 then
			alone += 1
			check(not Kaiju.isRanged(wave[1]), "A ranged one came alone")
		end
	end
	check(withRanged > 200 and alone > 100, "No ranged ones at the back, or no lone critters, in 2000 swarms")
	-- In one of the Outpost's biomes (Shared.Frontier), its own kind leans
	-- the swarm: a fighter is its own `bias` of the time (the rest the other
	-- fighters alike); a ranged own kind comes along more often instead,
	-- still at the back and never alone.
	for _, home in { "Sahur", "Tralalero", "Patapim" } do
		local mine, fighters, others = 0, 0, {}
		for _ = 1, 3000 do
			for _, id in Kaiju.wave(r:NextInteger(1, 9), r, home, 0.6) do
				if not Kaiju.isRanged(id) then
					fighters += 1
					if id == home then
						mine += 1
					else
						others[id] = (others[id] or 0) + 1
					end
				end
			end
		end
		local share = mine / fighters
		check(share > 0.57 and share < 0.63, home .. "'s biome isn't mostly " .. home .. ": " .. share)
		for id, n in others do
			check(math.abs(n / (fighters - mine) - 0.5) < 0.04, "The other fighters aren't alike in " .. home .. "'s biome: " .. id)
		end
	end
	local bombers, lone = 0, 0
	for _ = 1, 2000 do
		local count = r:NextInteger(1, 9)
		local wave = Kaiju.wave(count, r, "Crocodilo", 0.6)
		local seenRanged, ranged = false, 0
		for _, id in wave do
			if Kaiju.isRanged(id) then
				ranged += 1
				seenRanged = true
			else
				check(not seenRanged, "A fighter after a ranged one, in the ranged one's biome")
			end
		end
		check(#wave == count and ranged < count, "A swarm of only bombers, or the wrong size")
		if count >= 2 then
			check(ranged >= 1, "No bomber in its own biome's swarm of " .. count)
			bombers += ranged / count
		else
			lone += 1
		end
	end
	check(bombers / (2000 - lone) > 0.25, "Bombers no more common in their own biome")
end

-- The support slot: a support kind never takes a fighting slot; the one in
-- the support slot is the one put there, else the best; it's out after the
-- team, in SupportSlot; the starter support is owed once, after the roll.
do
	local function soul(element, n)
		return Kaiju.rollSoul(Random.new(n), element, { Id = "ss" .. n, Time = 1 })
	end
	check(Kaiju.isSupport("Skyjelly") and Kaiju.isSupport("Moonmoth") and not Kaiju.isSupport("Bulwark"), "Who's a support")
	check(shared("KaijuRoles").Roles[Kaiju.SupportRole].Name == "SUPPORT", "The support role isn't called SUPPORT")
	local roster = { List = {}, Next = 1 }
	local jelly = Kaiju.add(roster, "Skyjelly", soul("Shock", 1), 1)
	local moth = Kaiju.add(roster, "Moonmoth", soul("Shock", 2), 4)
	for i, kind in { "Bulwark", "Razorback", "Carapace", "Scythe" } do
		Kaiju.add(roster, kind, soul("Fire", 10 + i), 1)
	end
	roster.Team = { jelly.Id, moth.Id }
	local team = Kaiju.teamIds(roster)
	check(#team == 3, "Not three fighters out")
	for _, id in team do
		check(not Kaiju.isSupport(roster.List[id].Species), "A support took a fighting slot")
	end
	check(Kaiju.supportId(roster) == moth.Id, "The best support isn't the one out")
	check(Kaiju.setSupport(roster, jelly.Id) and Kaiju.supportId(roster) == jelly.Id, "The chosen support isn't out")
	check(not Kaiju.setSupport(roster, team[1]), "A fighter went in the support slot")
	local squad, slots = Kaiju.squadIds(roster)
	check(#squad == 4 and squad[4] == jelly.Id and slots[jelly.Id] == Kaiju.SupportSlot, "The squad isn't team + support")
	check(Kaiju.TeamSpots[Kaiju.SupportSlot] ~= nil, "No spot for the support")
	check(Kaiju.supportId({ List = {}, Next = 1 }) == nil, "A support out of nowhere")
	-- Owed once, after the roll, unless you have the kind.
	local profile = { Kaiju = { List = {}, Next = 1 } }
	check(not Kaiju.supportOwed(profile), "The support owed before the roll")
	profile.KaijuRolled = Kaiju.RollVersion
	check(Kaiju.supportOwed(profile), "The support not owed after the roll")
	profile.KaijuSupport = Kaiju.SupportVersion
	check(not Kaiju.supportOwed(profile), "The support owed twice")
	-- One past a full roster, for the starter support only.
	local full = { List = {}, Next = 1 }
	for i = 1, Kaiju.MaxOwned do
		Kaiju.add(full, "Bulwark", soul("Fire", 100 + i), 1)
	end
	check(Kaiju.add(full, "Skyjelly", soul("Shock", 3), 1) == nil, "Past a full roster")
	check(Kaiju.add(full, "Skyjelly", soul("Shock", 3), 1, true) ~= nil, "The starter support refused on a full roster")
end

-- Follow the leader: your line jumps nearest first (ties by team slot), a
-- beat apart, the head of it a moment after you.
do
	local order = Kaiju.hopLine({ 9, 3, 6, 3.2 }, { 1, 2, 3, 4 })
	check(order[1] == 2 and order[2] == 4 and order[3] == 3 and order[4] == 1, "Your line doesn't jump nearest first")
	order = Kaiju.hopLine({ 5.8, 5.8 }, { 2, 1 })
	check(order[1] == 2, "A tie isn't broken by team slot")
	check(#Kaiju.hopLine({}) == 0, "An empty line")
	check(Kaiju.hopDelay(1) == Kaiju.Hop.First and Kaiju.hopDelay(1) > 0.08, "The head of your line jumps with you, not after")
	check(Kaiju.hopDelay(3) - Kaiju.hopDelay(2) >= 0.2, "The jumps blur together, not one after another")
	check(Kaiju.hopDelay(4) < 1.2, "The back of a full line jumps long after you")
end

-- The HYPERBEAM: mana in, a cast out, full to fire; its phases, the V, the
-- beam's reach, the aim assist and the damage.
do
	local Beam = shared("KaijuBeam")
	local M = Beam.Mana
	check(Beam.gain(nil, 5) == 5 and Beam.gain(M.Max - 1, 5) == M.Max and Beam.gain(2, -9) == 0, "Mana not clamped to 0..Max")
	check(math.abs(Beam.gain(0, 10, true) - 10 * M.Save) < 1e-9 and M.Save > 1, "SAVE CHARGE doesn't fill faster")
	check(Beam.gain(10, -4, true) == 6, "SAVE CHARGE scales what's taken off too")
	check(Beam.spend(M.Cast + 1) == 1 and Beam.spend(1) == 0, "A cast's cost")
	local ready, least = Beam.team({ M.Max, M.Max, M.Max })
	check(ready and least == 1, "A full team not ready")
	ready, least = Beam.team({ M.Max, M.Max / 2 })
	check(not ready and least == 0.5, "Ready with one half charged")
	ready, least = Beam.team({})
	check(not ready and least == 0, "Ready with nobody out")
	-- About three minutes from empty out of a fight; a fight fills it faster.
	local fill = M.Max / M.Trickle
	check(fill > 90 and fill < 300, "The trickle fills too fast or too slow")
	check(M.Hit * 20 < M.Max, "A handful of blows fill it")

	local at = Beam.timeline()
	check(at.Charge < at.Fire and at.Fire < at.Stop and at.Stop < at.Done and at.Done < 6, "The blast's timeline")
	check(Beam.phase(-0.1) == nil and Beam.phase(0) == "Gather" and Beam.phase(at.Charge) == "Charge", "The phases (start)")
	check(Beam.phase(at.Fire + 0.01) == "Fire" and Beam.phase(at.Stop) == "Recover" and Beam.phase(at.Done) == nil, "The phases (end)")
	local _, half = Beam.phase(at.Fire + Beam.Beam.Fire / 2)
	check(math.abs(half - 0.5) < 1e-9, "A phase's progress")

	local spots = Beam.formation(4, true)
	check(#spots == 5, "Four in the V and the support")
	for i = 1, 4, 2 do
		check(spots[i].Side == -spots[i + 1].Side and spots[i].Back == spots[i + 1].Back, "The V isn't even either side")
		check(spots[i].Side > 0, "The first of a pair not on your right")
	end
	check(spots[3].Back > spots[1].Back and math.abs(spots[3].Side) > math.abs(spots[1].Side), "The V doesn't open out behind")
	check(spots[5].Side == 0 and spots[5].Up > 0 and spots[5].Back > 0, "The support not hung up behind you")
	local many = Beam.formation(6)
	check(#many == 6 and many[5].Side > many[3].Side and many[6].Side == -many[5].Side, "Past the four, further out")
	spots[1].Side = 99
	check(Beam.Formation[1].Side ~= 99, "The V handed out to be changed")

	local ahead, up = Beam.focus()
	check(ahead > 0 and up > 0, "The focus not ahead of you and up")
	local L, W = Beam.Beam.Length, Beam.Beam.Width
	check(Beam.hits(0, 0, 0, -1, 0, -L / 2, 0), "Something in the middle of the beam missed")
	check(Beam.hits(0, 0, 0, -1, W / 2 - 0.1, -10, 0) and not Beam.hits(0, 0, 0, -1, W / 2 + 0.5, -10, 0), "The beam's width")
	check(Beam.hits(0, 0, 0, -1, W / 2 + 0.5, -10, 1), "A big creature at its edge missed")
	check(not Beam.hits(0, 0, 0, -1, 0, 3, 0) and not Beam.hits(0, 0, 0, -1, 0, -L - 2, 0), "Behind it or past its end hit")
	check(Beam.hits(0, 0, 1, 0, L - 1, 0, 0) and not Beam.hits(0, 0, 1, 0, 0, -10, 0), "Aimed another way")

	local dx, dz = Beam.aim(0, -2, {})
	check(dx == 0 and dz == -1, "No one about, the aim isn't left as it was")
	dx, dz = Beam.aim(0, 0, nil)
	check(dz == -1, "No aim at all")
	local off = math.tan(Beam.Beam.Assist / 2) * 20
	dx, dz = Beam.aim(0, -1, { { X = off, Z = -20 }, { X = 0, Z = 30 }, { X = -1, Z = -Beam.Beam.Reach - 5 } })
	check(dx > 0.05 and math.abs(dx * dx + dz * dz - 1) < 1e-6, "Not turned onto a creature just off your aim")
	local wide = math.tan(Beam.Beam.Assist * 1.5) * 20
	dx, dz = Beam.aim(0, -1, { { X = wide, Z = -20 } })
	check(dx == 0, "Turned onto a creature far off your aim")
	dx, dz = Beam.aim(0, -1, { { X = 3, Z = -30 }, { X = -1, Z = -10 } })
	check(dx < 0, "Not the nearest of them")

	local pulse = Beam.damage({ 10, 20, -5 })
	check(math.abs(pulse * Beam.Beam.Pulses - 30 * Beam.Beam.Power) < 1e-9, "The beam's damage")
	check(Beam.damage({}) == 0, "Damage with no one")
end

print(
	string.format(
		"PASS: %d kaiju rule checks (stats, EXP, infusing, revives and danger, healPick and auto heal, taming, spread, slots, enchants (its own element only), names, your team, the support slot, the starter roll, fighting as a team, sizes, follow-the-leader jumps, the HYPERBEAM)",
		checks
	)
)
