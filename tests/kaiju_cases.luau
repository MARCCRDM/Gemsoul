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
local benched = 0
for id in Kaiju.Benched do
	benched += 1
	check(Kaiju.Species[id] ~= nil and not table.find(Kaiju.Order, id), id .. " is benched but still in the order, or gone")
	check(#Kaiju.wildKinds("Fringe") > 0 and not table.find(Kaiju.wildKinds("Vein"), id), id .. " is benched but still guards a vein")
end
check(#Kaiju.Order + benched == 90 and #Kaiju.Elements == 4, "Ninety species in four elements")
-- A benched kind already caught stays as it is.
do
	local profile = { Kaiju = { List = { k1 = { Id = "k1", Species = "Starcrop", Element = "Fire", Level = 5 } }, Next = 2 } }
	check(Kaiju.roster(profile).List.k1.Species == "Starcrop", "A benched kind already caught was changed")
end
-- A retired kind (Kaiju.Retired) already caught becomes its stand-in.
do
	local profile = { Kaiju = { List = { k1 = { Id = "k1", Species = "Drillmole", Element = "Fire", Level = 7 } }, Next = 2 } }
	local record = Kaiju.roster(profile).List.k1
	check(Kaiju.Species.Drillmole == nil and record.Species == "Gulper" and record.Level == 7, "A retired kind wasn't swapped for its stand-in")
	-- (and the three Wardens taken out on 2026-10-29: each to the nearest
	-- Warden in its rarity batch)
	for gone, standIn in { Silkling = "Coinmaw", Pipsqueak = "Twinsong", Shadowsphere = "Lumeballoon" } do
		local p = { Kaiju = { List = { k1 = { Id = "k1", Species = gone, Element = "Frost", Level = 3 } }, Next = 2 } }
		local r = Kaiju.roster(p).List.k1
		check(Kaiju.Species[gone] == nil and r.Species == standIn and Kaiju.isSupport(r.Species), gone .. " wasn't swapped for " .. standIn)
	end
end
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
	select(1, Kaiju.health(fireKaiju)) == most and most == Kaiju.withTraits(Kaiju.stats("Bulwark", 5, "Common"), Kaiju.traits(fireKaiju)).Health,
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
-- They lead the way, close in: standing, out ahead of where you look (the
-- first furthest, the two behind it side by side); on the move, ahead of
-- where you're going, not where you look, and further out the faster you
-- go. The support keeps at your shoulder, moving or not.
do
	local V3 = roblox.Vector3.new
	local here, look = V3(0, 0, 0), V3(0, 0, -1)
	local lead = Kaiju.leadSpot(here, look, nil, 1)
	local left, right = Kaiju.leadSpot(here, look, nil, 3), Kaiju.leadSpot(here, look, nil, 2)
	check(lead.Z < -8 and lead.Z > -13 and math.abs(lead.X) < 0.01, "The leader isn't out in front, close in: " .. lead.Z)
	check(right.X > 0 and left.X < 0 and math.abs(left.Z - right.Z) < 0.01 and right.Z > lead.Z and right.Z > -9, "The two aren't side by side, close, behind the leader")
	local support = Kaiju.leadSpot(here, look, nil, Kaiju.SupportSlot)
	check(support.Magnitude <= 4 and support.Z < 0, "The support isn't at your shoulder: " .. tostring(support))
	local supportRunning = Kaiju.leadSpot(here, look, V3(16, 0, 0), Kaiju.SupportSlot)
	check(supportRunning.Magnitude <= 4, "The support ran off ahead of you: " .. tostring(supportRunning))
	-- Running east, looking north: they're out ahead to the east.
	local running = Kaiju.leadSpot(here, look, V3(10, 0, 0), 1)
	check(running.X > 10 and math.abs(running.Z) < 0.01, "Not leading the way you're going: " .. tostring(running))
	local sprint = Kaiju.leadSpot(here, look, V3(40, 0, 0), 1)
	check(sprint.X > running.X and sprint.X <= -Kaiju.TeamSpots[1][2] + Kaiju.Lead.Max + 0.01, "The lead doesn't grow with your speed, or runs off")
	-- Barely moving (turning on the spot): where you look.
	check((Kaiju.leadSpot(here, look, V3(1, 0, 0), 1) - lead).Magnitude < 0.01, "A shuffle swung them round")
end
-- Where you can see them: with your camera's look known (KaijuView),
-- standing about they're out in front of you as your camera sees it (you
-- facing your camera, that's on your far side, not behind the camera off
-- your screen); heading back toward your camera they keep to your far side
-- with no lead; heading across or away, they lead the way you're going. A
-- camera looking straight down says nothing.
do
	local V3 = roblox.Vector3.new
	local here, look = V3(0, 0, 0), V3(0, 0, -1) -- (you face north...)
	local view = V3(0, -0.4, 1) -- (...your camera looks south, at you)
	for slot = 1, #Kaiju.TeamSpots do
		local spot = Kaiju.leadSpot(here, look, nil, slot, view)
		check(spot.Z > 0, "Facing your camera, slot " .. slot .. " stood behind it, off your screen: " .. tostring(spot))
	end
	local standing = Kaiju.leadSpot(here, look, nil, 1, view)
	check(math.abs(standing.Z + Kaiju.TeamSpots[1][2]) < 0.01, "Not out in front of you as your camera sees it: " .. tostring(standing))
	local back = Kaiju.leadSpot(here, look, V3(0, 0, -10), 1, view)
	check(back.Z > 0 and back.Z <= -Kaiju.TeamSpots[1][2] + 0.01, "Walking toward your camera, they led off behind it: " .. tostring(back))
	local across = Kaiju.leadSpot(here, look, V3(10, 0, 0), 1, view)
	check(across.X > 10, "Walking across your camera's view, they didn't lead: " .. tostring(across))
	local away = Kaiju.leadSpot(here, look, V3(0, 0, 10), 1, view)
	check(away.Z > -Kaiju.TeamSpots[1][2], "Walking away from your camera, they didn't lead: " .. tostring(away))
	local down = Kaiju.leadSpot(here, look, nil, 1, V3(0, -1, 0))
	check((down - Kaiju.leadSpot(here, look, nil, 1)).Magnitude < 0.01, "A camera looking straight down moved them")
end
-- They never chase a foe off: Chase studs from where a fight began is as
-- far as one's followed, well inside where they'd give up on a fight
-- you've walked away from; and you come first, over a kaiju's own foe.
check(Kaiju.Follow.Chase > 10 and Kaiju.Follow.Chase < Kaiju.Follow.Leash, "Chase isn't a short way")
check(Kaiju.Follow.Engage >= Kaiju.SupportPulse.StrikeRange, "The support strikes what the team won't take on")

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
	-- (everyday traits, all Mid, so its stats are its kind's: Traits below)
	local mid = { Might = Kaiju.Traits.Mid, Vigor = Kaiju.Traits.Mid, Guard = Kaiju.Traits.Mid, Speed = Kaiju.Traits.Mid }
	local rec = Kaiju.new("k1", "Bulwark", born, 6, mid)
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
-- (Teams fill in the order you catch them: Team 2 only once Team 1 is full.)
check(ids[2] == k2.Id and ids[3] == k3.Id, "Team 1 isn't the first three caught")
check(
	table.concat(Kaiju.teamOf(roster, 2), ",") == k4.Id and #Kaiju.teamOf(roster, 3) == 0 and Kaiju.teamCount(roster) == 2,
	"Team 2 doesn't start once Team 1 is full"
)
check(Kaiju.teamNumber(roster, k4.Id) == 2 and Kaiju.teamNumber(roster, k1.Id) == 1, "teamNumber is wrong")
check(Kaiju.inTeam(roster, k2.Id) and not Kaiju.inTeam(roster, k4.Id), "inTeam is wrong")
Kaiju.setTeam(roster, { k3.Id, k3.Id, "nope", k2.Id })
ids = Kaiju.teamIds(roster)
check(ids[1] == k3.Id and ids[2] == k2.Id and #ids == 3, "setTeam didn't keep its order (once each, owned)")
check(roster.Active == k3.Id and Kaiju.active(roster) == k3, "The lead isn't the first of the team")
check(#roster.Team == 3, "setTeam didn't tidy the team it saved")
roster.List[k3.Id] = nil
-- (A kaiju gone leaves its place empty: nobody slides over from another team.)
check(Kaiju.teamIds(roster)[1] == k2.Id and #Kaiju.teamIds(roster) == 2, "A kaiju gone didn't leave its place empty")
check(Kaiju.teamNumber(roster, k4.Id) == 2, "A kaiju slid from Team 2 into Team 1's empty place")
check(#Kaiju.team(roster) == 2 and Kaiju.team(roster)[1] == k2, "Kaiju.team isn't the records in order")
-- Four teams of three: twelve kaiju fill them in order; the team out is
-- roster.Out (a team with nobody in it isn't one: Team 1); a support kind
-- isn't in a team (its own slot); two swap places, and teams; setTeam puts
-- kaiju in the team out, the ones there taking their places.
do
	local r = Kaiju.roster({})
	local all = {}
	for i = 1, 12 do
		table.insert(all, Kaiju.add(r, if i % 2 == 0 then "Bulwark" else "Razorback", soulFor("Fire", "t" .. i)).Id)
	end
	local jelly = Kaiju.add(r, "Skyjelly", soulFor("Shock", "j"), nil, true)
	check(Kaiju.Teams == 4 and Kaiju.teamCount(r) == 4, "Twelve kaiju aren't four teams")
	for n = 1, 4 do
		local team = Kaiju.teamOf(r, n)
		check(#team == 3 and team[1] == all[n * 3 - 2] and team[3] == all[n * 3], "Team " .. n .. " isn't its three, in order")
	end
	check(jelly and Kaiju.teamNumber(r, jelly.Id) == nil and Kaiju.supportId(r) == jelly.Id, "The support is in a team")
	check(Kaiju.outTeam(r) == 1 and Kaiju.teamIds(r)[1] == all[1], "Team 1 isn't out to start with")
	r.Out = 3
	check(Kaiju.outTeam(r) == 3 and Kaiju.teamIds(r)[2] == all[8], "roster.Out isn't the team out")
	r.Out = 9
	check(Kaiju.outTeam(r) == 4, "A team past the last isn't the last")
	r.Out = 3
	check(Kaiju.swap(r, all[1], all[9]) and Kaiju.teamNumber(r, all[1]) == 3 and Kaiju.teamOf(r, 1)[1] == all[9], "A swap didn't trade places")
	check(not Kaiju.swap(r, all[1], jelly.Id), "A support swapped into a team")
	Kaiju.setTeam(r, { all[2], all[7] })
	check(Kaiju.teamIds(r)[1] == all[2] and Kaiju.teamIds(r)[2] == all[7] and Kaiju.teamNumber(r, all[1]) ~= nil, "setTeam didn't put them in the team out")
	local counts = {}
	for n = 1, 4 do
		counts[n] = #Kaiju.teamOf(r, n)
	end
	check(counts[1] == 3 and counts[2] == 3 and counts[3] == 3 and counts[4] == 3, "setTeam left a team short")
	check(r.Team ~= nil and r.Team[1] == all[2] and r.Active == all[2], "roster.Team and Active aren't the team out")
	-- A team with nobody in it: back to Team 1.
	local small = Kaiju.roster({})
	Kaiju.add(small, "Razorback", soulFor("Fire", "u1"))
	small.Out = 2
	check(Kaiju.outTeam(small) == 1 and #Kaiju.teamIds(small) == 1, "An empty team is out")
end
-- Real teams and a bench (Kaiju.teams, place, benchKaiju, autoFill): a team
-- can have empty places and any team can be filled; a kaiju in no team is on
-- the bench; an old save's line becomes its teams as they stood.
do
	local r = Kaiju.roster({})
	local all = {}
	for i = 1, 6 do
		local record = Kaiju.add(r, if i % 2 == 0 then "Bulwark" else "Razorback", soulFor("Fire", "b" .. i), 20)
		table.insert(all, record.Id) -- (level 20: three places a team)
	end
	check(Kaiju.slots(r) == 3, "Teams aren't three places")
	check(#Kaiju.teamOf(r, 1) == 3 and #Kaiju.teamOf(r, 3) == 0 and #Kaiju.bench(r) == 0, "Caught kaiju didn't fill the first teams with room")
	-- Bench one: its place is empty, it's on the bench, nobody moved.
	check(Kaiju.benchKaiju(r, all[2]), "Couldn't bench a kaiju")
	check(#Kaiju.teamOf(r, 1) == 2 and Kaiju.teamOf(r, 1)[2] == all[3] and Kaiju.bench(r)[1] == all[2], "Benching didn't leave an empty place")
	check(Kaiju.teamNumber(r, all[2]) == nil and Kaiju.teamNumber(r, all[4]) == 2, "teamNumber is wrong for the bench")
	check(not Kaiju.benchKaiju(r, all[2]), "Benched one already on the bench")
	-- Team 4 with Team 3 empty: fine.
	check(Kaiju.place(r, all[2], 4, 1) and Kaiju.teamOf(r, 4)[1] == all[2] and #Kaiju.teamOf(r, 3) == 0, "Couldn't fill Team 4 with Team 3 empty")
	-- On an empty place: it moves there (its old place empties).
	check(Kaiju.place(r, all[1], 4, 3) and Kaiju.teamOf(r, 4)[2] == all[1] and Kaiju.teamNumber(r, all[1]) == 4, "Placing on an empty place didn't move it")
	-- On someone: they trade places; from the bench, the one there goes to the bench.
	Kaiju.benchKaiju(r, all[3])
	check(Kaiju.place(r, all[3], 2, 1) and Kaiju.teamOf(r, 2)[1] == all[3] and Kaiju.teamNumber(r, all[4]) == nil, "From the bench onto someone didn't bench them")
	check(Kaiju.swap(r, all[4], all[5]) and Kaiju.teamNumber(r, all[4]) == 2 and Kaiju.teamNumber(r, all[5]) == nil, "A swap with the bench didn't trade")
	check(not Kaiju.place(r, all[5], 1, 4) and not Kaiju.place(r, all[5], 5, 1) and not Kaiju.place(r, "nope", 1, 1), "Placed somewhere that isn't a place")
	-- Auto fill: the bench's best into the empty places.
	local bench = #Kaiju.bench(r)
	local placed = Kaiju.autoFill(r)
	check(placed == bench and #Kaiju.bench(r) == 0, "Auto fill didn't empty the bench into empty places")
	-- Keep one in a team at least.
	local lone = Kaiju.roster({})
	local only = Kaiju.add(lone, "Razorback", soulFor("Fire", "lone"))
	check(not Kaiju.benchKaiju(lone, only.Id) and Kaiju.teamNumber(lone, only.Id) == 1, "Benched the last kaiju in a team")
	-- The team out with nobody: the first team with someone.
	local r2 = Kaiju.roster({})
	for i = 1, 4 do
		Kaiju.add(r2, "Razorback", soulFor("Fire", "o" .. i), 20)
	end
	Kaiju.place(r2, Kaiju.teamOf(r2, 2)[1], 3, 1)
	r2.Out = 2
	check(Kaiju.outTeam(r2) == 1, "An empty team out isn't the first with someone")
	-- Teams grow (a kaiju levels up past Kaiju.SlotLevels): the new places
	-- fill from the bench, once (Kaiju.roster).
	local slotLevels = Kaiju.SlotLevels
	Kaiju.SlotLevels = { 1, 10, 20 } -- (as if teams grew with your best kaiju)
	local grow = {}
	local g = Kaiju.roster(grow)
	for i = 1, 6 do
		Kaiju.add(g, "Razorback", soulFor("Fire", "g" .. i), 1)
	end
	check(#Kaiju.teamOf(g, 1) == 1 and #Kaiju.bench(g) == 2, "Level 1 kaiju aren't teams of one and a bench")
	Kaiju.roster(grow)
	g.List[Kaiju.teamOf(g, 1)[1]].Level = 20
	Kaiju.roster(grow)
	check(#Kaiju.teamOf(g, 1) == 3 and #Kaiju.bench(g) == 0, "Bigger teams didn't fill from the bench")
	Kaiju.SlotLevels = slotLevels
	-- An old save's line (roster.Order) becomes its teams as they stood.
	local old = Kaiju.roster({})
	for i = 1, 5 do
		Kaiju.add(old, "Razorback", soulFor("Fire", "l" .. i), 20)
	end
	local line = Kaiju.order(old)
	old.Teams = nil
	old.Order = { line[5], line[4], line[3], line[2], line[1] }
	local teams = Kaiju.teams(old)
	check(teams[1][1] == line[5] and teams[1][3] == line[3] and teams[2][1] == line[2] and teams[2][2] == line[1], "An old save's line didn't become its teams")
	Kaiju.saveTeams(old, teams)
	check(old.Order == nil and type(old.Teams) == "table" and Kaiju.teamOf(old, 2)[2] == line[1], "Saving the teams didn't keep them")
end
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
-- Boss rolls: one kaiju a boss, none while the starter roll's owed, only
-- with room, never a support kind.
check(Kaiju.bossRollsOwed({ KaijuBossRolls = 2 }) == 0, "A boss roll came before the starter roll")
check(Kaiju.bossRollsOwed({ KaijuRolled = Kaiju.RollVersion, KaijuBossRolls = 2 }) == 2, "Boss rolls aren't owed")
check(Kaiju.bossRollsOwed({ KaijuRolled = Kaiju.RollVersion }) == 0, "A boss roll owed with no boss beaten")
do
	local full = {}
	for i = 1, Kaiju.MaxOwned do
		full["k" .. i] = {}
	end
	check(Kaiju.bossRollsOwed({ KaijuRolled = Kaiju.RollVersion, KaijuBossRolls = 1, Kaiju = { List = full } }) == 0, "A boss roll with no room for it")
	local rng = Random.new(7)
	for _ = 1, 200 do
		local pick = Kaiju.bossPick(rng)
		check(Kaiju.Species[pick.Species] ~= nil and not Kaiju.isSupport(pick.Species), "A boss roll gave a support kind or none")
		check(table.find(Kaiju.Elements, pick.Element) ~= nil, "A boss roll's element isn't one")
	end
end
-- Rarity by batch: the roster's first 30 kinds the rarest, the next 30
-- less so, the last 30 the most often met (boss rolls and the wild).
do
	local roster = shared("KaijuRoster").Order
	check(Kaiju.batch(roster[1]) == 1 and Kaiju.batch(roster[30]) == 1, "The first batch isn't the first 30")
	check(Kaiju.batch(roster[31]) == 2 and Kaiju.batch(roster[60]) == 2, "The second batch isn't the next 30")
	check(Kaiju.batch(roster[61]) == 3 and Kaiju.batch(roster[#roster]) == 3, "The third batch isn't the last")
	check(Kaiju.batch("Bulwark") == nil, "A starter has a batch")
	check(Kaiju.kindWeight(roster[1]) < Kaiju.kindWeight(roster[31]) and Kaiju.kindWeight(roster[31]) < Kaiju.kindWeight(roster[61]), "The batches aren't rarer the earlier they came")
	local counts = { 0, 0, 0 }
	local rng = Random.new(11)
	for _ = 1, 6000 do
		local pick = Kaiju.bossPick(rng)
		local b = Kaiju.batch(pick.Species)
		if b then
			counts[b] += 1
		end
	end
	check(counts[1] < counts[2] and counts[2] < counts[3], "Boss rolls don't favour the later batches: " .. table.concat(counts, "/"))
	local one = { roster[1], roster[61] }
	local early = 0
	for _ = 1, 2000 do
		early += if Kaiju.pickKind(one, rng) == roster[1] then 1 else 0
	end
	check(early > 150 and early < 450, "pickKind's odds are off: " .. early)
end
-- Kaiju on the Market (Shared.Market): listed out of your roster (never the
-- last one, nor one in the team out), handed over whole with a new id.
do
	local Market = shared("Market")
	local seller = { Kaiju = nil }
	local roster = Kaiju.roster(seller)
	local a = Kaiju.add(roster, "Bulwark", { Element = "Fire", Tier = "Rare" }, 7)
	local others = {}
	for i = 1, Kaiju.slots(roster) do
		table.insert(others, Kaiju.add(roster, "Carapace", { Element = "Frost", Tier = "Common" }, 2).Id)
	end
	Kaiju.setTeam(roster, others)
	check(Market.whyNot(seller, "Kaiju", nil, others[1]) ~= nil, "A kaiju in the team out was listed")
	check(Market.whyNot(seller, "Kaiju", nil, "k999") ~= nil, "A kaiju you don't have was listed")
	check(Market.whyNot(seller, "Kaiju", nil, a.Id) == nil, "A spare kaiju can't be listed: " .. tostring(Market.whyNot(seller, "Kaiju", nil, a.Id)))
	local before = Kaiju.count(roster)
	local payload = Market.take(seller, "Kaiju", nil, a.Id)
	check(payload and payload.Kind == "Kaiju" and payload.Record.Species == "Bulwark" and payload.Record.Level == 7, "The listed kaiju isn't whole")
	check(Kaiju.count(roster) == before - 1 and roster.List[a.Id] == nil and not table.find(Kaiju.order(roster), a.Id), "The listed kaiju is still in the roster")
	check(Market.tab(payload) == "Kaiju" and Market.fits("Kaiju", payload) and not Market.fits("Gems", payload), "A kaiju listing's tab or want")
	local buyer = {}
	local theirs = Kaiju.roster(buyer)
	Kaiju.add(theirs, "Scythe", { Element = "Shock", Tier = "Common" }, 1)
	check(Market.cantReceive(buyer, payload, 10) == nil, "A buyer with room can't take a kaiju")
	check(Market.give(buyer, payload, 10), "The bought kaiju wasn't given")
	local got
	for id, record in theirs.List do
		if record.Species == "Bulwark" then
			got = record
			check(record.Id == id and id ~= "k1", "The bought kaiju kept a clashing id")
		end
	end
	check(got and got.Level == 7 and got.Soul.Tier == "Rare" and table.find(Kaiju.order(theirs), got.Id), "The bought kaiju isn't whole or not in the line")
	local full = {}
	local fullRoster = Kaiju.roster(full)
	for i = 1, Kaiju.MaxOwned do
		Kaiju.add(fullRoster, "Scythe", { Element = "Fire", Tier = "Common" }, 1)
	end
	check(Market.cantReceive(full, payload, 10) ~= nil, "A full roster took a kaiju")
	check(Market.give(full, payload, 10, true), "A kaiju coming home from escrow didn't fit back")
	local one = {}
	local lone = Kaiju.add(Kaiju.roster(one), "Scythe", { Element = "Fire", Tier = "Common" }, 1)
	check(Market.whyNot(one, "Kaiju", nil, lone.Id) ~= nil, "Your last kaiju was listed")
end
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
-- (You come first: a foe on you or your support over a kaiju's own, on it.)
check(Kaiju.Squad.OwnerThreat > Squad.Stick + Squad.Threat, "A foe on you counts for less than a kaiju's own")
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
	-- The support casts what the team's health calls for, not what's ready.
	do
		local all = { Mend = true, BigMend = true, Ward = true, Strike = true }
		local choose = function(healths, foes, ready)
			return Kaiju.supportChoice({ Healths = healths, Foes = foes, Ready = ready or all })
		end
		check(choose({ 1, 1, 1, 1 }, 0) == nil, "It cast with everyone whole and nothing about")
		check(choose({ 1, 1, 1, 1 }, 2) == "Strike", "It didn't attack with everyone whole")
		check(choose({ 0.3, 1, 1, 1 }, 2) == "BigMend", "One nearly down, no big mend")
		check(choose({ 0.4, 0.45, 0.5, 0.45 }, 2) == "BigMend", "The whole team in a bad way, no big mend")
		check(choose({ 0.5, 1, 1, 1 }, 2) == "Mend", "One hurt, no mend")
		check(choose({ 0.7, 0.7, 1, 1 }, 2) == "Mend", "Two worn, no mend")
		check(choose({ 0.78, 1, 1, 1 }, 2) == "Ward", "One taking the hits, no ward")
		check(choose({ 0.78, 1, 1, 1 }, 0) == nil, "A ward with nothing about")
		check(choose({ 0.5, 1, 1, 1 }, 2, { Ward = true, Strike = true }) == "Ward", "One hurt and its mend not back: no ward")
		check(choose({ 0.5, 1, 1, 1 }, 2, { Strike = true }) == nil, "It attacked with one of you hurt and its mend not back")
		check(choose({ 0.3, 1, 1, 1 }, 2, { Mend = true, Strike = true }) == "Mend", "Nearly down and the big mend not back: not even a mend")
		check(choose({}, 1) == "Strike", "On its own (nobody in reach), it didn't attack")
		-- Its gem's R (Guard), on you and itself: in a fight once you're
		-- worn, before a mend; not with you whole, not with nothing about.
		local guard = function(owner, healths, foes, ready)
			return Kaiju.supportChoice({ Healths = healths, Owner = owner, Foes = foes, Ready = ready or { Guard = true, Mend = true, BigMend = true, Ward = true, Strike = true } })
		end
		check(guard(0.6, { 0.6, 1, 1, 1 }, 2) == "Guard", "You worn in a fight, no gem R on you")
		check(guard(1, { 1, 1, 1, 1 }, 2) == "Strike", "Its gem R with you whole")
		check(guard(0.5, { 0.5, 1, 1, 1 }, 0) == "Mend", "Its gem R with nothing about")
		check(guard(0.3, { 0.3, 1, 1, 1 }, 2) == "BigMend", "You nearly down: its gem R before a big mend")
		check(guard(0.5, { 0.5, 1, 1, 1 }, 2, { Mend = true, Strike = true }) == "Mend", "Its gem R not back: no mend")
	end
	-- A support has no gem surge: its gem gives it its R instead (from the
	-- start), whatever R the gem rolled being one it can cast.
	for seed = 1, 12 do
		local element = Kaiju.Elements[(seed - 1) % #Kaiju.Elements + 1]
		local born = Kaiju.rollSoul(Random.new(seed), element, { Id = "g" .. seed, Time = 1, Species = "Skyjelly" })
		local jelly = { Species = "Skyjelly", Element = element, Level = 1, Soul = born }
		check(Kaiju.recordSurge(jelly) == nil, "A support still has a gem surge")
		local r = Kaiju.supportGuard(jelly)
		check(r ~= nil and Kaiju.AbilityPlans[r] ~= nil and string.sub(r, 1, 2) == "R_", "A support's gem gave it no R it can cast")
		check(r == GemTraits.traitFor(born, "R"), "A support's gem R isn't its gem's R")
		check(Kaiju.gemMove(jelly) == r, "A support's gem move isn't its R")
		local fighter = { Species = "Razorback", Element = element, Level = 1, Soul = born }
		check(Kaiju.supportGuard(fighter) == nil and Kaiju.gemMove(fighter) == Kaiju.recordSurge(fighter), "A fighter's gem move changed")
	end
	check(Kaiju.supportId({ List = {}, Next = 1 }) == nil, "A support out of nowhere")
	-- Every new account comes with a Skyjelly (Kaiju.StarterSupport): owed
	-- once, after the roll, unless you have the kind.
	check(Kaiju.StarterSupport.On and Kaiju.StarterSupport.Species == "Skyjelly", "New accounts don't come with a Skyjelly")
	local profile = { Kaiju = { List = {}, Next = 1 } }
	check(not Kaiju.supportOwed(profile), "The support owed before the roll")
	profile.KaijuRolled = Kaiju.RollVersion
	check(Kaiju.supportOwed(profile), "The Skyjelly isn't owed after the roll")
	profile.KaijuSupport = Kaiju.SupportVersion
	check(not Kaiju.supportOwed(profile), "The support owed twice")
	-- No roll deals a support kind, nor the Kaiju of the Day.
	for _, id in Kaiju.rareKinds() do
		check(not Kaiju.isSupport(id), "A rare roll can deal a support kind")
	end
	for _, id in Kaiju.Starters do
		check(not Kaiju.isSupport(id), "A starter can be a support kind")
	end
	-- The Store's kaiju come with their Gemsouls made to order: the Starter
	-- Rare Roll's Rare with its element's best surge, the premium trio's
	-- Ultra Rare with the best Q, E and R.
	for _, element in Kaiju.Elements do
		local best = Kaiju.BestMoves[element]
		check(best ~= nil, "No best moves for " .. element)
		for lane, id in best do
			check(table.find(Kaiju.Moves[element][lane], id) ~= nil, element .. "'s best " .. lane .. " isn't one of its moves")
		end
		local rare = Kaiju.rollSoul(Random.new(5), element, { Id = "r", Time = 1, Species = "Emberjaw", Rarity = Kaiju.Sale.Rare.Rarity, Best = Kaiju.Sale.Rare.Best })
		check(rare.Tier == "Rare" and rare.Traits.Ability == best.Ability, "The Starter Rare Roll's Gemsoul isn't Rare with the best surge")
		local premium = Kaiju.rollSoul(Random.new(6), element, { Id = "p", Time = 1, Species = "Triskull", Rarity = Kaiju.Sale.Premium.Rarity, Best = Kaiju.Sale.Premium.Best })
		check(
			premium.Tier == "UltraRare" and premium.Traits.Ability == best.Ability and premium.Traits.Offense == best.Offense and premium.Traits.Defense == best.Defense,
			"The premium trio's Gemsoul isn't Ultra Rare with the best Q, E and R"
		)
	end
	check(#Kaiju.Sale.Premium.Elements == 3 and Kaiju.species(Kaiju.Sale.Premium.Species) ~= nil, "The premium trio isn't three of a kind")
	for _, shown in Kaiju.Sale.Showcase do
		check(table.find(Kaiju.rareKinds(), shown.Species) ~= nil, "The Starter Rare Roll shows a kind it can't roll: " .. shown.Species)
	end
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

-- The HYPERBEAM: its own charge, full to fire; its phases, the V in front
-- of you, the beam's reach, the aim assist, the biggest threat first and
-- the sweep over the rest, and the damage.
do
	local Beam = shared("KaijuBeam")
	local M = Beam.Charge
	check(Beam.gain(nil, 5) == 5 and Beam.gain(M.Max - 1, 5) == M.Max and Beam.gain(2, -9) == 0, "The charge not clamped to 0..Max")
	check(math.abs(Beam.gain(0, 10, true) - 10 * M.Save) < 1e-9 and M.Save > 1, "SAVE CHARGE doesn't fill faster")
	check(Beam.gain(10, -4, true) == 6, "SAVE CHARGE scales what's taken off too")
	local ready, share = Beam.ready(M.Max)
	check(ready and share == 1, "A full charge not ready")
	ready, share = Beam.ready(M.Max / 2)
	check(not ready and share == 0.5, "Ready half charged")
	ready, share = Beam.ready(nil)
	check(not ready and share == 0, "Ready with no charge")
	-- Earned, never passive: no time-based fill, only blows landing.
	check(M.Trickle == nil and M.Fight == nil, "The HYPERBEAM still fills on its own")
	check(M.Hit * 20 < M.Max, "A handful of blows fill it")

	local at = Beam.timeline()
	check(at.Charge < at.Fire and at.Fire < at.Stop and at.Stop < at.Done and at.Done < 7, "The blast's timeline")
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
	check(spots[1].Back < 0 and spots[3].Back < 0, "The V not in front of you")
	check(spots[3].Back > spots[1].Back and math.abs(spots[3].Side) > math.abs(spots[1].Side), "The V doesn't open out ahead")
	check(spots[5].Side == 0 and spots[5].Up > 0 and spots[5].Back < 0, "The support not hung up in front of you")
	local many = Beam.formation(6)
	check(#many == 6 and many[5].Side > many[3].Side and many[6].Side == -many[5].Side, "Past the four, further out")
	spots[1].Side = 99
	check(Beam.Formation[1].Side ~= 99, "The V handed out to be changed")

	local ahead, up = Beam.focus()
	check(ahead > 0 and up > 0, "The focus not ahead of you and up")
	check(ahead > -spots[1].Back, "The focus not ahead of the V")
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

	-- Into formation: one after another, a beat apart, all down well before
	-- the roar, and the roar before the charge.
	local first, firstDown = Beam.leap(1)
	local second = Beam.leap(2)
	local _, lastDown = Beam.leap(Kaiju.StarterTeam + 1) -- (a full team: three and the support)
	check(first == 0 and second > first and firstDown - first == Beam.Leap.Air, "The leaps' order or timing")
	check(lastDown < Beam.Leap.Roar and Beam.Leap.Roar < at.Charge, "Not all down before the roar, or the roar after the charge")
	check(Beam.leapHeight(0) == Beam.Leap.Height and Beam.leapHeight(30) > Beam.leapHeight(5), "A longer leap isn't higher")
	check(Beam.leapHeight(1000) == Beam.Leap.Top, "A leap goes up out of sight")
	local a0, h0 = Beam.arc(0, 6)
	local a5, h5 = Beam.arc(0.5, 6)
	local a1, h1 = Beam.arc(1, 6)
	check(a0 == 0 and h0 == 0 and a1 == 1 and h1 == 0, "A leap doesn't start and end on the ground")
	check(math.abs(a5 - 0.5) < 1e-9 and math.abs(h5 - 6) < 1e-9, "A leap isn't at its height halfway")
	check(Beam.arc(-1, 6) == 0 and Beam.arc(2, 6) == 1, "A leap past its ends")

	-- The biggest threat first (the toughest; one in a fight with you
	-- bigger still), then round the rest from it; none behind you.
	check(Beam.threat({ MaxHealth = 400 }) > Beam.threat({ MaxHealth = 100 }), "A tougher one not a bigger threat")
	check(Beam.threat({ MaxHealth = 100, Engaged = true }) > Beam.threat({ MaxHealth = 100 }), "One in a fight with you not a bigger threat")
	local foes = {
		{ X = -20, Z = -20, MaxHealth = 100 }, -- (ahead on your left)
		{ X = 20, Z = -25, MaxHealth = 900 }, -- (ahead on your right: the boss)
		{ X = 0, Z = -30, MaxHealth = 100 }, -- (dead ahead)
		{ X = 0, Z = 30, MaxHealth = 5000 }, -- (behind you: never)
		{ X = 25, Z = -20, MaxHealth = 100, Engaged = true }, -- (beside the boss)
	}
	local order = Beam.order(foes, 0, -1)
	check(#order == 4 and order[1] == 2, "The biggest threat isn't first: " .. tostring(order[1]))
	check(not table.find(order, 4), "It swung onto one behind you")
	check(order[2] == 5 and order[3] == 3 and order[4] == 1, "Not round the rest from the first, nearest first")
	check(#Beam.order({}, 0, -1) == 0, "Something to take with no one about")
	local crowd = {}
	for i = 1, Beam.Beam.Most + 3 do
		table.insert(crowd, { X = i, Z = -20, MaxHealth = 50 })
	end
	check(#Beam.order(crowd, 0, -1) == Beam.Beam.Most, "It takes more than Most")
	-- A boss in the fight: the biggest threat whatever else is about (even
	-- behind you, even with an add tougher than it), locked on to first; the
	-- sweep goes on from it to the ones about it.
	local withBoss = table.clone(foes)
	table.insert(withBoss, { X = 10, Z = 35, MaxHealth = 800, Boss = true })
	table.insert(withBoss, { X = 18, Z = 30, MaxHealth = 5000 })
	table.insert(withBoss, { X = -6, Z = 38, MaxHealth = 40 })
	local bossOrder = Beam.order(withBoss, 0, -1)
	check(bossOrder[1] == #withBoss - 2, "With a boss in the fight, it wasn't taken first")
	check(table.find(bossOrder, #withBoss - 1) and table.find(bossOrder, #withBoss), "It didn't go on from the boss to the adds about it")
	-- A crowd spread across in front: one sweep (out to the nearer side's
	-- last, then back across), every one of them, never back and forth.
	local spread = {}
	for i, deg in { 0, -50, 40, -20, 70, 15, -65, 30 } do
		local r = math.rad(deg)
		table.insert(spread, { X = math.sin(r) * 30, Z = -math.cos(r) * 30, MaxHealth = if i == 1 then 500 else 50 })
	end
	local swept = Beam.order(spread, 0, -1)
	check(#swept == #spread and swept[1] == 1, "Not every one in the crowd taken, the biggest first")
	local turns, last = 0, nil
	for k = 2, #swept do
		local a = math.atan2(spread[swept[k]].X, -spread[swept[k]].Z) - math.atan2(spread[swept[k - 1]].X, -spread[swept[k - 1]].Z)
		local sign = if a > 0 then 1 else -1
		if last and sign ~= last then
			turns += 1
		end
		last = sign
	end
	check(turns <= 1, "The sweep goes back and forth over the crowd: " .. turns .. " turns")
	-- Held on the first less with many, so there's time for them all.
	check(Beam.dwell(1) == 1 and Beam.dwell(3) == Beam.Beam.Dwell and Beam.dwell(12) < Beam.Beam.Dwell / 3, "Beam.dwell")
	-- The sweep: held on the first for Dwell, then each in turn, eased.
	check(select(1, Beam.sweep(0.2, 3)) == 1 and select(3, Beam.sweep(0.2, 3)) == 0, "Not held on the first")
	local i, j, blend = Beam.sweep(Beam.Beam.Dwell + 0.001, 3)
	check(i == 1 and j == 2 and blend < 0.01, "The swing to the second doesn't start from the first")
	i, j, blend = Beam.sweep(1, 3)
	check(i == 2 and j == 3 and blend == 1, "Not on the last at the end")
	check(select(1, Beam.sweep(0.9, 1)) == 1, "One alone: not held on it")
	-- Its way: onto each in turn, smoothly (no jump frame to frame), never
	-- behind you, your aim with none.
	local points = { { X = 20, Z = -25 }, { X = -20, Z = -20 } }
	local ax, az = Beam.direction(0.1, 0, 0, 0, -1, points)
	check(ax > 0.5 and az < 0, "Not aimed at the first")
	local bx, bz = Beam.direction(1, 0, 0, 0, -1, points)
	check(bx < -0.5 and bz < 0, "Not on the last at the end")
	local px, pz = Beam.direction(0, 0, 0, 0, -1, points)
	local jump = 0
	for step = 1, 200 do
		local nx, nz = Beam.direction(step / 200, 0, 0, 0, -1, points)
		jump = math.max(jump, math.acos(math.clamp(nx * px + nz * pz, -1, 1)))
		check(math.abs(nx * nx + nz * nz - 1) < 1e-6, "Its way isn't a unit")
		px, pz = nx, nz
	end
	check(jump < math.rad(4), "The beam jumps instead of swinging: " .. math.deg(jump))
	local cx, cz = Beam.direction(0.1, 0, 0, 0, -1, { { X = 0, Z = 40 } })
	check(cz <= -math.cos(Beam.Beam.Swing) + 1e-6 or math.abs(math.atan2(cx, -cz)) <= Beam.Beam.Swing + 1e-6, "It swung behind you")
	local nx, nz = Beam.direction(0.5, 0, 0, 0, -1, {})
	check(nx == 0 and nz == -1, "Not your aim with no one to take")

	local pulse = Beam.damage({ 10, 20, -5 })
	check(math.abs(pulse * Beam.Beam.Pulses - 30 * Beam.Beam.Power) < 1e-9, "The beam's damage")
	check(Beam.damage({}) == 0, "Damage with no one")
end

-- Traits: no two kaiju alike, whatever their level -----------------------------------------
do
	local T = Kaiju.Traits
	check(#T.Names == 4, "Not four traits")
	local rng = Random.new(77)
	local seen = {}
	for _ = 1, 400 do
		local t = Kaiju.rollTraits(rng)
		local key = ""
		for _, name in T.Names do
			check(t[name] >= 0 and t[name] <= T.Max and t[name] == math.floor(t[name]), "A trait rolled out of range")
			key ..= t[name] .. ","
		end
		seen[key] = true
		local good = Kaiju.rollTraits(rng, 14)
		for _, name in T.Names do
			check(good[name] >= 14, "A trait rolled under its floor")
		end
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	check(kinds > 390, "Kaiju roll the same traits")
	-- (with no rng: math.random, as a server does)
	local any = Kaiju.rollTraits()
	check(any.Might >= 0 and any.Speed <= T.Max, "No rng: traits out of range")
	-- A new kaiju has its own; given ones are copied, not shared.
	local soul = Kaiju.rollSoul(Random.new(3), "Fire", { Id = "t1", Time = 1, Species = "Bulwark" })
	local born = Kaiju.new("k1", "Bulwark", soul, 1)
	check(born.Traits and born.Traits.Vigor ~= nil, "A new kaiju has no traits")
	local given = { Might = 20, Vigor = 20, Guard = 20, Speed = 20 }
	local copy = Kaiju.new("k2", "Bulwark", soul, 1, given)
	check(copy.Traits.Might == 20 and copy.Traits ~= given, "Given traits weren't kept (or were shared)")
	-- A save from before traits: its own, the same every time, kept on load.
	local old = { Id = "k7", Species = "Razorback", Element = "Shock", Level = 4, Exp = 0, Soul = { Id = "g9", Found = 123, Tier = "Rare" } }
	local a, b = Kaiju.traits(old), Kaiju.traits(old)
	for _, name in T.Names do
		check(a[name] == b[name] and a[name] >= 0 and a[name] <= T.Max, "An old save's traits change or run out of range")
	end
	local differ = 0
	for n = 1, 50 do
		local other = table.clone(old)
		other.Id = "k" .. n
		local o = Kaiju.traits(other)
		if o.Might ~= a.Might or o.Vigor ~= a.Vigor or o.Guard ~= a.Guard or o.Speed ~= a.Speed then
			differ += 1
		end
	end
	check(differ >= 45, "Old saves all get the same traits")
	local profile = { Kaiju = { List = { k7 = old }, Next = 8 } }
	Kaiju.roster(profile)
	check(old.Traits and old.Traits.Might == a.Might and old.Traits.Speed == a.Speed, "An old save's traits weren't kept on load")
	check(Kaiju.traits({ Traits = { Might = 99, Vigor = -4, Guard = 7.6, Speed = 3 } }).Might == T.Max, "Traits past Max weren't clamped")
	-- What they do: everyday (Mid) changes nothing; the best and worst by Per.
	local base = Kaiju.stats("Bulwark", 10, "Rare")
	local midT = { Might = T.Mid, Vigor = T.Mid, Guard = T.Mid, Speed = T.Mid }
	local same = Kaiju.withTraits(Kaiju.stats("Bulwark", 10, "Rare"), midT)
	check(same.Health == base.Health and same.Damage == base.Damage and same.Speed == base.Speed and same.Guard == base.Guard, "Everyday traits changed its stats")
	local best = Kaiju.withTraits(Kaiju.stats("Bulwark", 10, "Rare"), given)
	local worst = Kaiju.withTraits(Kaiju.stats("Bulwark", 10, "Rare"), { Might = 0, Vigor = 0, Guard = 0, Speed = 0 })
	local span = T.Max - T.Mid
	check(math.abs(best.Health / base.Health - (1 + span * T.Per.Vigor)) < 0.01, "Vigor doesn't raise its health by Per")
	check(math.abs(best.Damage / base.Damage - (1 + span * T.Per.Might)) < 0.01, "Might doesn't raise its damage by Per")
	check(math.abs(best.Guard - (base.Guard + span * T.Per.Guard)) < 0.002, "Guard isn't added to its kind's")
	check(best.Speed > base.Speed and worst.Speed < base.Speed, "Speed doesn't move its speed")
	check(worst.Health < base.Health and worst.Damage < base.Damage and worst.Guard <= base.Guard, "Poor traits didn't lower its stats")
	check(best.Health / worst.Health < 1.3 and best.Damage / worst.Damage < 1.3, "Traits outweigh levels")
	-- (a kaiju of a level above is still stronger than the best of the one below, mostly)
	local next = Kaiju.withTraits(Kaiju.stats("Bulwark", 12, "Rare"), { Might = 0, Vigor = 0, Guard = 0, Speed = 0 })
	check(next.Health < best.Health, "Traits do too little: two levels outweigh the best and worst")
	-- In its stats as it stands: two of one kind and level, unlike.
	local strong = Kaiju.new("k3", "Bulwark", soul, 8, given)
	local weak = Kaiju.new("k4", "Bulwark", soul, 8, { Might = 1, Vigor = 2, Guard = 0, Speed = 3 })
	local sa, sb = Kaiju.recordStats(strong), Kaiju.recordStats(weak)
	check(sa.Health > sb.Health and sa.Damage > sb.Damage and sa.Guard > sb.Guard and sa.Speed > sb.Speed, "Two of one kind and level fight the same")
	check(select(2, Kaiju.health(strong)) == sa.Health, "Its full health isn't its traits' health")
	-- Its Guard in the hits it takes.
	local plainTaken = Kaiju.taken("Bulwark", "Fire", nil)
	check(math.abs(Kaiju.taken("Bulwark", "Fire", nil, sa.Guard) - (1 - sa.Guard)) < 1e-9 and Kaiju.taken("Bulwark", "Fire", nil, sa.Guard) < plainTaken, "Its own Guard didn't soak more")
	-- Its Grade.
	check(Kaiju.grade(given) == "S" and Kaiju.grade({ Might = 0, Vigor = 0, Guard = 0, Speed = 0 }) == "C", "Grades at the ends")
	local last = math.huge
	for _, step in T.Grades do
		check(step[2] < last, "Grades aren't in order")
		last = step[2]
		local at = step[2]
		local t = { Might = math.min(T.Max, at), Vigor = math.clamp(at - T.Max, 0, T.Max), Guard = math.clamp(at - 2 * T.Max, 0, T.Max), Speed = math.clamp(at - 3 * T.Max, 0, T.Max) }
		check(Kaiju.grade(t) == step[1], "A total of " .. at .. " isn't Grade " .. step[1])
	end
	local grades = {}
	for _ = 1, 2000 do
		local g = Kaiju.grade(Kaiju.rollTraits(rng))
		grades[g] = (grades[g] or 0) + 1
	end
	check((grades.S or 0) > 0 and (grades.S or 0) < 200, "Grade S isn't rare")
	check((grades.B or 0) > (grades.S or 0) and (grades.A or 0) > (grades.S or 0), "Grade S is commoner than A or B")
	-- Where they're used.
	local server = fs.readFile(ROOT .. "/src/server/Systems/KaijuServer.luau")
	check(server:find("pet.Stats and pet.Stats.Guard", 1, true) ~= nil, "A pet's own Guard isn't used in the hits it takes")
	check(server:find("Traits = Kaiju.rollTraits(random)", 1, true) ~= nil and server:find("entry.Traits)", 1, true) ~= nil, "The roll's traits aren't the kaiju's")
	check(server:find("Traits = record.Traits", 1, true) ~= nil, "A revive works out health without its traits")
	local wilds = fs.readFile(ROOT .. "/src/server/Systems/KaijuWilds.luau")
	check(wilds:find("Traits = traits", 1, true) ~= nil and wilds:find("wild.Traits)", 1, true) ~= nil, "A caught kaiju doesn't keep its wild traits")
	check(wilds:find('"KaijuGrade"', 1, true) ~= nil and wilds:find("stats.Guard)", 1, true) ~= nil, "A wild kaiju's traits don't show or count")
	local hud = fs.readFile(ROOT .. "/src/client/Modules/KaijuHud.luau")
	check(hud:find("Kaiju.traits(record)", 1, true) ~= nil and hud:find("TraitChips", 1, true) ~= nil, "The kaiju panel doesn't show its traits")
	local market = fs.readFile(ROOT .. "/src/client/Modules/MarketBoardUI.luau")
	check(market:find("Grade %s", 1, true) ~= nil, "The Market doesn't show a kaiju's Grade")
	local roll = fs.readFile(ROOT .. "/src/client/Modules/KaijuRoll.luau")
	check(roll:find("entry.Traits", 1, true) ~= nil, "The roll card doesn't show its traits")
	local bars = fs.readFile(ROOT .. "/src/client/Modules/WildBars.luau")
	check(bars:find('"KaijuGrade"', 1, true) ~= nil, "A wild kaiju's plate doesn't show its Grade")
end

print(
	string.format(
		"PASS: %d kaiju rule checks (stats, EXP, infusing, revives and danger, healPick and auto heal, taming, spread, slots, enchants (its own element only), traits and grades, names, your team, the support slot, the starter roll, fighting as a team, sizes, follow-the-leader jumps, the HYPERBEAM)",
		checks
	)
)
