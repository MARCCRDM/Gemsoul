-- lune run tests/triad_cases.luau <repo>
-- The Q / E / R triad (Shared.GemTraits): every gem carries one Offense,
-- one Ability and one Defense; the socket picks which one a key fires.
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
-- A seeded stand-in for Roblox's Random (a small LCG).
local Random = {}
function Random.new(seed)
	local state = (seed or 1) % 2147483647
	local rng = {}
	function rng:NextNumber()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function rng:NextInteger(low, high)
		return low + math.floor(self:NextNumber() * (high - low + 1))
	end
	return rng
end
local Traits = load("GemTraits")
local Tech = load("CombatTechnology")
local Roller = load("GemRoller")
local Actions = load("CombatActions")

-- The matrix: 4 elements x 3 lanes x 5 moves, plus each element's showcase
-- defenses (a barrier and an escape), every one defined once.
local all, seen = Traits.all(), {}
check(#all == 66, "The matrix holds 66 moves, found " .. #all)
for _, id in all do
	check(not seen[id], id .. " sits in the matrix twice")
	seen[id] = true
	local move = Traits.Moves[id]
	check(move ~= nil, id .. " has no definition")
	check(Tech.Catalog[id] == move, id .. " is missing from the combat catalog")
	check(type(move.Name) == "string" and #move.Name > 0, id .. " has no name")
	check(type(move.Description) == "string" and #move.Description > 0, id .. " has no description")
	check(move.Flourish and type(move.Flourish.Text) == "string", id .. " has no Legendary Flourish")
	local resource = if move.Lane == "Defense" then "Stamina" else "Charge"
	check(move.Resource == resource, id .. " should pay with " .. resource)
	-- The lane budgets from the design: Q 20-35 Charge / 6-10s, E 25-50 / 10-18s, R 15-30 Stamina / 10-16s.
	local band = ({ Offense = { 20, 35, 6, 10 }, Ability = { 25, 50, 10, 18 }, Defense = { 15, 30, 10, 16 } })[move.Lane]
	check(move.Cost >= band[1] and move.Cost <= band[2], id .. " costs outside its lane's band")
	check(move.Cooldown >= band[3] and move.Cooldown <= band[4], id .. " cooldown outside its lane's band")
	check(type(move.IconSource) == "string", id .. " has no icon to show")
	if move.Lane == "Ability" then
		check(move.Type == "Strike" or move.Type == "Shift" or move.Type == "Aura", id .. " needs an Ability type")
	end
	if move.Type == "Aura" then
		check(move.Aura ~= nil, id .. " is an Aura with nothing passive")
	end
end
-- The intro pools: two moves per key per element, all of that element and
-- key, made to be seen: no plain shield, every defense a wall, ring,
-- pillar, decoy or slick.
for element, lanes in Traits.Intro do
	for lane, ids in lanes do
		check(#ids == 2, element .. " " .. lane .. " needs two intro moves")
		for _, id in ids do
			local index = Traits.Index[id]
			check(index and index.Element == element and index.Lane == lane, id .. " is in the wrong intro pool")
			local move = Traits.Moves[id]
			check(move.Absorb == nil, id .. " is a shield: not for the intro")
			if lane == "Defense" then
				check(move.Wall or move.Ring or move.Pillar or move.Decoy or move.Slick, id .. " puts nothing into the world")
				check(Traits.Showcase[id] ~= nil, id .. " has no showcase role")
			end
		end
	end
end
-- Each element has one barrier and one escape; a recut keeps the role.
for _, element in { "Fire", "Frost", "Shock", "Poison" } do
	local roles = {}
	for _, id in Traits.Intro[element].Defense do
		roles[Traits.Showcase[id]] = id
	end
	check(roles.Barrier and roles.Escape, element .. " needs a barrier and an escape")
end
local recut = Traits.reElement({ Defense = "R_HoloDecoy" }, "Shock", "Fire")
check(recut.Defense == "R_RingOfFire", "An escape stays an escape on a recut")
recut = Traits.reElement({ Defense = "R_FireWall" }, "Fire", "Poison")
check(recut.Defense == "R_SporeWall", "A barrier stays a barrier on a recut")
recut = Traits.reElement({ Defense = "R_Grounding" }, "Shock", "Frost")
check(recut.Defense == "R_FrostRiposte", "A plain move keeps its slot on a recut")

-- No old surge was taken: every retired id still resolves to its own definition.
for _, id in { "EnergySiphon", "ResonanceEcho", "ResonantReaver", "NullPrism", "ThermalBurst", "Overload", "CryoShield" } do
	check(Tech.Catalog[id] ~= nil and not Tech.Catalog[id].Triad, id .. " must stay in the archive untouched")
end

-- Signature moves roll at half the odds of the others.
local signatures = { Q_OverchargeStrike = "Shock", Q_Dissolution = "Poison", E_AbsoluteZero = "Frost", R_PhoenixMantle = "Fire" }
for id, element in signatures do
	local lane = Traits.Moves[id].Lane
	local odds = Traits.odds(element, lane)
	local other = Traits.Matrix[element][lane][if Traits.Matrix[element][lane][1] == id then 2 else 1]
	check(math.abs(odds[id] - odds[other] * 0.5) < 1e-9, id .. " should roll at half the odds")
end
local rng = Random.new(42)
local counts = {}
for _ = 1, 20000 do
	local t = Traits.roll(rng, "Fire")
	counts[t.Defense] = (counts[t.Defense] or 0) + 1
end
local phoenix = counts.R_PhoenixMantle / 20000
check(phoenix > 0.09 and phoenix < 0.13, "Phoenix Mantle rolls ~11% of Fire gems, got " .. phoenix)

-- Rolled gems carry three traits of their element.
local gem = Roller.roll(Random.new(7))
check(type(gem.Traits) == "table", "A rolled gem carries its traits")
for lane, id in gem.Traits do
	check(Traits.Index[id].Element == gem.Element and Traits.Index[id].Lane == lane, "A trait from the wrong element or lane")
end

-- Old gems: traits seeded from the id, stable, and a matrix surge keeps its lane.
local old = { Id = "G-1234", Element = "Frost", Tier = "Rare", Surge = "CryoLance", Size = 5, Clarity = 5, Cut = 5 }
local a, b = Traits.traitsOf(old), Traits.traitsOf(table.clone(old))
check(a.Offense == b.Offense and a.Ability == b.Ability and a.Defense == b.Defense, "Seeded traits must agree everywhere")
check(a.Ability == "E_CryoLance", "A Cryo Lance gem keeps Cryo Lance as its Ability")
local siphon = { Id = "G-9", Element = "Shock", Tier = "Common", Surge = "EnergySiphon" }
check(Traits.traitsOf(siphon).Defense == "R_Capacitor", "Energy Siphon becomes Capacitor on R")
-- A saved roll wins over the seed.
old.Traits = { Offense = "Q_CryoEdge", Ability = "E_WintersHold", Defense = "R_FrozenWall" }
check(Traits.traitsOf(old).Defense == "R_FrozenWall", "A saved trait roll is kept")

-- The socket picks the trait: sword -> Q, core -> E, shield -> R.
local sword = { Id = "S", Element = "Fire", Tier = "Legendary", Traits = { Offense = "Q_CinderDrill", Ability = "E_Supernova", Defense = "R_FireWall" } }
local core = { Id = "C", Element = "Frost", Tier = "Common", Traits = { Offense = "Q_GlacierFan", Ability = "E_CryoLance", Defense = "R_IceArmor" } }
local shield = { Id = "H", Element = "Shock", Tier = "Rare", Traits = { Offense = "Q_Railstorm", Ability = "E_IonSpark", Defense = "R_StaticCatch" } }
local loadout = { WeaponGem = sword, Surge2Gem = core, ShieldGem = shield, Surge1Gem = { Id = "old1", Element = "Fire" }, Surge3Gem = { Id = "old3", Element = "Fire" } }
check(Tech.surgeGem(loadout, "Q").Surge == "Q_CinderDrill", "Q fires the sword gem's Offense")
check(Tech.surgeGem(loadout, "E").Surge == "E_CryoLance", "E fires the core gem's Ability")
check(Tech.surgeGem(loadout, "R").Surge == "R_StaticCatch", "R fires the shield gem's Defense")
check(loadout.WeaponGem.Surge == nil, "Projecting never touches the saved gem")
check(Tech.surgeGem(loadout, "Q").SourceId == "S", "The projection remembers its gem")
-- No shield carried (a two-handed weapon): the weapon is its own guard.
check(Tech.surgeGem({ WeaponGem = sword }, "R").Surge == "R_FireWall", "Without a shield, R reads the weapon's Defense")
check(Tech.surgeGem({ WeaponGem = sword, Shield = "Buckler" }, "R") == nil, "With an empty shield socket, R is empty")
-- Everyone else (the Arena rival) reads the classic sockets.
check(Tech.surgeGem({ LegacySurges = true, Surge1Gem = { Id = "x", Element = "Fire", Surge = "EmberLance" } }, "Q").Surge == "EmberLance", "The classic array still works")

-- Stats: rarity sets output, not cost; Size, Clarity and Cut fine-tune.
local legendary = Tech.surgeStats(Tech.surgeGem(loadout, "Q"))
check(legendary.Triad and legendary.Id == "Q_CinderDrill", "Triad stats resolve")
check(legendary.Flourished and legendary.Burn ~= nil, "A Legendary gets its Flourish")
local common = Tech.surgeStats(Tech.surgeGem(loadout, "E"))
check(math.abs(common.Damage - 1.2 * 0.6) < 1e-6, "A Common gives 60% output")
check(common.Cost == Traits.Moves.E_CryoLance.Cost, "Rarity never changes cost")
local rare = Tech.surgeStats(Tech.surgeGem(loadout, "R"))
check(rare.Resource == "Stamina" and rare.Catch.Steal == 10 * 0.8, "R pays Stamina; steals scale with output")
local graded = Tech.surgeStats(Traits.project({ Id = "g", Element = "Fire", Tier = "Legendary", Size = 10, Clarity = 10, Cut = 10, Traits = sword.Traits }, "R"))
check(math.abs(graded.Wall.Time - 4.5 * 1.15) < 1e-6, "Clarity 10 stretches durations 15%")
check(math.abs(graded.Cooldown - 14 * 0.85) < 1e-6, "Cut 10 trims the cooldown 15%")
local ranked = Tech.surgeStats(Tech.surgeGem(loadout, "Q"), nil, true)
check(math.abs(ranked.Damage - 0.4 * 0.8) < 1e-6 and not ranked.Flourished, "Ranked levels everyone to 80%, no Flourish")

-- Casting: R casts like a buff; Q sword techniques come out quick.
check(Actions.castKind(rare) == "Buff", "A defense casts as a buff")
check(Actions.castTime(legendary) <= 0.5, "A sword technique has a short wind-up")
check(Actions.castKind(Tech.surgeStats(Traits.project(shield, "E"))) == "Bolt", "Ion Spark is a bolt")

-- Sockets: any elemental gem fits any key; the lanes never repeat a move.
check(Tech.canSocket(core, "Q", loadout) and Tech.canSocket(core, "R", loadout), "Any gem has a trait for every key")
check(not Tech.canSocket({ Id = "plain" }, "E", loadout), "A gem with no element has no traits")

-- Recut: a new element keeps each trait's slot in its lane.
local recut = Roller.setElement({ Element = "Fire", Surge = "EmberLance", Traits = { Offense = "Q_FurnaceCrescent", Ability = "E_EmberLance", Defense = "R_PhoenixMantle" } }, "Frost")
check(recut.Traits.Offense == "Q_GlacierFan" and recut.Traits.Defense == "R_FrostRiposte", "Recut keeps trait slots")

print("PASS: " .. checks .. " triad checks (66 moves, intro pools, rolls, sockets, stats, casting)")
