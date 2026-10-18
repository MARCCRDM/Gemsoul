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
-- defenses (a barrier and an escape) and the 12 intro moves, every one
-- defined once.
local all, seen = Traits.all(), {}
check(#all == 78, "The matrix holds 78 moves, found " .. #all)
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
-- The intro's Q and E: each its own look (a TriadVfx/MoveVfx show), and each
-- pays off against one opponent (nothing that only arcs, chains or heals per
-- extra enemy).
local moveVfx = fs.readFile(ROOT .. "/src/client/Modules/MoveVfx.luau")
for element, lanes in Traits.Intro do
	for _, lane in { "Offense", "Ability" } do
		for _, id in lanes[lane] do
			local move = Traits.Moves[id]
			check(type(move.Show) == "string", id .. " has no look of its own")
			check(string.find(moveVfx, "SHOW." .. move.Show .. " = ", 1, true) ~= nil, id .. "'s look " .. move.Show .. " isn't drawn")
			check(move.Damage ~= nil, id .. " must hit something")
			check(move.Chain == nil and move.ArcExtra == nil and move.HealPerEnemy == nil, id .. " only shines against a crowd")
			check(not move.PerSecond, id .. " is a held channel")
		end
	end
end
-- Every piece a new move shows has a drawing.
for _, piece in { "MeteorLeapJump", "Crater", "Puddle", "VortexEnd", "StormWarn", "StormBolt", "ToxicFlaskThrow" } do
	check(string.find(moveVfx, "SHOW." .. piece .. " = ", 1, true) ~= nil, piece .. " isn't drawn")
end
-- The old intro Q/E moves all have a replacement in the same element and lane.
for old, new in Traits.IntroReplaced do
	local a, b = Traits.Index[old], Traits.Index[new]
	check(a and b and a.Element == b.Element and a.Lane == b.Lane, old .. " -> " .. new .. " crosses lanes")
end
-- A starter stone carrying an old intro move is moved over; others are left be.
local starter = { Id = "st", Element = "Shock", CutMethod = "Starter", Traits = { Offense = "Q_Railstorm", Ability = "E_ChainLightning", Defense = "R_TeslaFence" } }
local found = { Id = "f", Element = "Shock", Traits = { Offense = "Q_Railstorm", Ability = "E_ChainLightning", Defense = "R_TeslaFence" } }
local save = {
	Gems = { found },
	Character = { WeaponGem = starter, ItemGems = { Shield = { x = table.clone(starter) } } },
	Intro = { Lottery = { Moves = { "Q_Railstorm", "E_ChainLightning", "R_TeslaFence" }, Gems = {} } },
}
save.Character.ItemGems.Shield.x.Traits = table.clone(starter.Traits)
check(Traits.upgradeStarterProfile(save) == 2, "Both starter stones are moved over")
check(starter.Traits.Offense == "Q_Skybreaker" and starter.Traits.Ability == "E_StormCall" and starter.Traits.Defense == "R_TeslaFence", "Railstorm -> Skybreaker, Chain Lightning -> Storm Call, R kept")
check(found.Traits.Offense == "Q_Railstorm", "A mined stone keeps what it rolled")
check(save.Intro.Lottery.Moves[1] == "Q_Skybreaker" and save.Intro.Lottery.Moves[2] == "E_StormCall", "An unclaimed kit gets the new moves")
check(Traits.upgradeStarterProfile(save) == 0, "Moving over twice changes nothing")
-- Gems with no saved roll keep picking from the lanes as they stood, so the
-- new moves never swap anyone's moves under them.
for n = 1, 400 do
	for _, element in { "Fire", "Frost", "Shock", "Poison" } do
		local t = Traits.traitsOf({ Id = "seed-" .. n, Element = element })
		for _, lane in { "Offense", "Ability" } do
			check(table.find(Traits.Matrix[element][lane], t[lane]) <= 5, "A seeded gem rolled a new intro move")
		end
	end
end
-- The numbers say how many hits.
check(string.find(Traits.summary(Traits.stats("E_StormCall", { Tier = "Common" })), "x5", 1, true) ~= nil, "Storm Call's 5 bolts show")
check(string.find(Traits.summary(Traits.stats("E_Hailstorm", { Tier = "Legendary" })), "x8", 1, true) ~= nil, "A Legendary Hailstorm's 8 ticks show")
check(Actions.castKind(Traits.stats("Q_MeteorLeap", { Tier = "Common" })) == "Move", "Meteor Leap moves you as it casts")

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

-- The socket picks the trait: sword -> Q, chest -> E, shield -> R. The
-- gear's own gem sockets are the surge sockets; the old surge array (the
-- core socket, Surge2, too) is retired.
local sword = { Id = "S", Element = "Fire", Tier = "Legendary", Traits = { Offense = "Q_CinderDrill", Ability = "E_Supernova", Defense = "R_FireWall" } }
local core = { Id = "C", Element = "Frost", Tier = "Common", Traits = { Offense = "Q_GlacierFan", Ability = "E_CryoLance", Defense = "R_IceArmor" } }
local shield = { Id = "H", Element = "Shock", Tier = "Rare", Traits = { Offense = "Q_Railstorm", Ability = "E_IonSpark", Defense = "R_StaticCatch" } }
local loadout = { WeaponGem = sword, ArmorGem = core, ShieldGem = shield, Surge1Gem = { Id = "old1", Element = "Fire" }, Surge3Gem = { Id = "old3", Element = "Fire" } }
check(Tech.surgeGem(loadout, "Q").Surge == "Q_CinderDrill", "Q fires the sword gem's Offense")
check(Tech.surgeGem(loadout, "E").Surge == "E_CryoLance", "E fires the chest gem's Ability")
check(Traits.Sockets.E == "Armor" and Traits.SocketNames.E == "Chest", "E isn't the chest's")
check(Traits.KeyOfSocket.Weapon == "Q" and Traits.KeyOfSocket.Armor == "E" and Traits.KeyOfSocket.Shield == "R", "The gear slots don't name their keys")
check(table.find(Traits.ArchivedSockets, "Surge2") and Traits.Moved.Surge2 == "Armor", "The core socket isn't retired onto the chest")
check(Tech.surgeGem({ Surge2Gem = core }, "E") == nil, "A gem left on the old core socket still fires E")
-- An old save's core gem: onto the chest worn, else the pouch, else it waits.
local function save(character, gems)
	return { Character = character, Gems = gems or {} }
end
local onChest = save({ Armor = "PaddedVest", Surge2Gem = core, ItemGems = {} })
local went, clear = Traits.moveCoreGem(onChest, 300)
check(went == "Chest" and clear and onChest.Character.ArmorGem == core and onChest.Character.Surge2Gem == nil, "The core gem didn't go onto the chest")
check(onChest.Character.ItemGems.Armor.PaddedVest == core, "The chest piece doesn't keep its gem")
check(Tech.surgeGem(onChest.Character, "E").Surge == "E_CryoLance", "The moved gem doesn't fire E")
local taken = save({ Armor = "PaddedVest", ArmorGem = sword, Surge2Gem = core }, {})
went, clear = Traits.moveCoreGem(taken, 300)
check(went == "Stash" and clear and taken.Gems[1] == core and taken.Character.ArmorGem == sword, "A chest with a gem lost it, or the core gem was lost")
local full = save({ Surge2Gem = core }, { sword, shield })
went, clear = Traits.moveCoreGem(full, 2)
check(went == nil and not clear and full.Character.Surge2Gem == core and #full.Gems == 2, "With no room the core gem must wait where it is")
went, clear = Traits.moveCoreGem(save({ Armor = "PaddedVest" }), 300)
check(went == nil and clear, "An empty core socket moved something")
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

print("PASS: " .. checks .. " triad checks (78 moves, intro pools and looks, rolls, sockets, stats, casting)")
