-- The Rift's rules (Shared.RiftRun) and its world (Server.RiftWorld) on
-- Roblox instances (lune's roblox library): the caves' packs, critters and
-- the pathway dungeon's fighters, sized for how many are in, big ones now
-- and then, at the kaiju's level and up; one of the ten brainrot bosses as
-- a Colossus, tougher with more runners, calling critters and fighters
-- through as it weakens; what falling costs, what RESTORE costs and what a
-- win pays. The world: a pathway of walled caves on a grid that never
-- touches itself, floor all the way from the landing to the throne (nowhere
-- to fall), walls too tall to climb, a wall of fire across each way out
-- (until it's opened), the ways home, a scar across the sky, the fallen
-- miners (and in the dungeon's rooms). And nothing else starts for a runner. Run by tests/run_rift.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."
local CFrame, Vector3 = R.CFrame, R.Vector3

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- A seeded Random (lune has none): Park-Miller.
local Random = {
	new = function(seed)
		local state = (seed or 7) % 2147483647
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
			state = (state * 16807) % 2147483647
			return a + math.floor(state / 2147483647 * (b - a + 1))
		end
		return r
	end,
}

local mods = {}
local function proxy(name)
	return setmetatable({ __mod = name }, {
		__index = function(_, key)
			return proxy(key)
		end,
	})
end
local env
local function load(name)
	if mods[name] then
		return mods[name]
	end
	local path = ROOT .. "/src/shared/" .. name .. ".luau"
	if not fs.isFile(path) then
		path = ROOT .. "/src/server/World/" .. name .. ".luau"
	end
	mods[name] = luau.load(fs.readFile(path), { debugName = name, environment = env })()
	return mods[name]
end
local workspace = R.Instance.new("Folder")
workspace.Name = "Workspace"
env = setmetatable({
	Instance = R.Instance,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	Enum = R.Enum,
	UDim = R.UDim,
	UDim2 = R.UDim2,
	ColorSequence = R.ColorSequence,
	ColorSequenceKeypoint = R.ColorSequenceKeypoint,
	NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint,
	NumberRange = R.NumberRange,
	Random = Random,
	workspace = workspace,
	game = {
		GetService = function(_, service)
			return proxy(service)
		end,
	},
	script = { Parent = proxy("Shared") },
	require = function(p)
		return load(p.__mod)
	end,
	typeof = R.typeof or typeof,
}, { __index = _G })

local RiftRun = load("RiftRun")
local Kaiju = load("Kaiju")
local DungeonRules = load("DungeonRules")

-- The packs ---------------------------------------------------------------------------------------------------

check(
	RiftRun.foeCount(1, 1) == RiftRun.Foes[1] and RiftRun.foeCount(RiftRun.Rooms, 1) == RiftRun.Foes[RiftRun.Rooms],
	"A pack's size alone"
)
for room = 2, RiftRun.Rooms do
	check(RiftRun.foeCount(room, 1) >= RiftRun.foeCount(room - 1, 1), "Fewer critters further in")
	check(
		RiftRun.foeCount(room, 1) + RiftRun.fighterCount(room, 1)
			> RiftRun.foeCount(room - 1, 1) + RiftRun.fighterCount(room - 1, 1),
		"The caves don't get harder further in"
	)
	check(RiftRun.fighterTier(room) >= RiftRun.fighterTier(room - 1), "The fighters' gear gets worse further in")
end
check(
	RiftRun.foeCount(1, 2) > RiftRun.foeCount(1, 1) and RiftRun.foeCount(1, 4) > RiftRun.foeCount(1, 2),
	"No more critters for more runners"
)
check(RiftRun.fighterCount(1, 1) >= 1, "A cave without a fighter")
for room = 1, RiftRun.Rooms do
	check(RiftRun.foeCount(room, 1) >= #Kaiju.SlotLevels, "Fewer critters in cave " .. room .. " than a team of kaiju")
end
-- Through tears of their own: spread over the cave's floor, clear of the
-- runners, inside it; crowded, still one for each.
do
	local portal = RiftRun.Portal
	check(portal.Every > 0 and portal.Leader > 7.5 and portal.Boss > portal.Leader, "The tears' timing or sizes")
	local spotRng = Random.new(11)
	local center = Vector3.new(500, 20, -300)
	for trial = 1, 300 do
		local count = 3 + trial % 6
		local runners = { center + Vector3.new(spotRng:NextNumber(-20, 20), 0, spotRng:NextNumber(-20, 20)) }
		local spots = RiftRun.portalSpots(center, 42, count, runners, spotRng)
		check(#spots == count, "Not a tear for each")
		for i, spot in spots do
			local flat = Vector3.new(spot.X - center.X, 0, spot.Z - center.Z)
			check(flat.Magnitude <= 42 * portal.Share + 1e-6 and spot.Y == center.Y, "A tear off the cave's floor")
			local fromRunner = Vector3.new(spot.X - runners[1].X, 0, spot.Z - runners[1].Z).Magnitude
			check(fromRunner >= portal.Clear - 1e-6, "A tear on top of a runner: " .. fromRunner)
			for j = i + 1, #spots do
				local apart = Vector3.new(spot.X - spots[j].X, 0, spot.Z - spots[j].Z).Magnitude
				check(apart >= portal.Apart - 1e-6, "Two tears on top of each other: " .. apart)
			end
		end
	end
	local crowded = RiftRun.portalSpots(center, 6, 9, { center }, spotRng)
	check(#crowded == 9, "A crowded cave lost a tear")
	-- Healing crystals: toward the corners, inset from the walls, clear of
	-- the braziers in the corners (6 in) and of the passages in each wall's
	-- middle (24 wide), never two in one corner. (The caves' and the throne
	-- cave's: the landing has none.)
	local heal = RiftRun.Heal
	for _, size in { 76, 96 } do
		for _ = 1, 40 do
			local spots = RiftRun.healSpots(center, size, heal.PerCave, spotRng)
			check(#spots == heal.PerCave, "Not a cave's crystals")
			for i, spot in spots do
				local off = spot - center
				check(
					math.abs(off.X) <= size / 2 - heal.Inset + 1e-6 and math.abs(off.Z) <= size / 2 - heal.Inset + 1e-6,
					"A crystal in a wall"
				)
				check(math.abs(off.X) > 12 and math.abs(off.Z) > 12, "A crystal in a passage's way")
				local brazier = Vector3.new(math.sign(off.X), 0, math.sign(off.Z)) * (size / 2 - 6)
				check((off - brazier).Magnitude > 8, "A crystal on a brazier")
				for j = i + 1, #spots do
					check((spot - spots[j]).Magnitude > 10, "Two crystals in one corner")
				end
			end
		end
	end
	check(#RiftRun.healSpots(center, 76, 9, spotRng) == 4, "More crystals than corners")
end
check(RiftRun.fighterCount(1, 3) > RiftRun.fighterCount(1, 1), "No more fighters for more runners")
local rng = Random.new(5)
local elites = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
for _ = 1, 200 do
	for room = 1, RiftRun.Rooms do
		local pack = RiftRun.pickFoes(room, 2, rng)
		check(#pack == RiftRun.foeCount(room, 2), "A pack the wrong size")
		local big, rangedSeen = 0, false
		for _, foe in pack do
			check(
				table.find(Kaiju.Critters, foe.Critter) ~= nil,
				"A pack's critter that isn't one: " .. tostring(foe.Critter)
			)
			if Kaiju.isRanged(foe.Critter) then
				rangedSeen = true
				check(not foe.Elite, "A big ranged one")
			else
				check(not rangedSeen, "A ranged one before the fighters")
			end
			if foe.Elite then
				big += 1
			end
		end
		check(big <= 1, "More than one big one in a pack")
		elites[room] += big
		local fighters = RiftRun.pickFighters(room, 2, rng)
		check(#fighters == RiftRun.fighterCount(room, 2), "The wrong number of fighters")
		for _, spec in fighters do
			check(table.find(DungeonRules.Roster, spec) ~= nil, "A fighter that isn't the pathway dungeon's")
			check(spec == fighters[1], "A cave's fighters of two kinds")
		end
	end
end
check(elites[1] == 0, "A big one in the first cave")
check(elites[2] > 40 and elites[RiftRun.Rooms] > 40, "Hardly ever a big one further in")

-- Levels: their kaiju's and up, a level more each cave, the boss's above.
check(RiftRun.level({ 5, 9 }, 1) == 7 + RiftRun.Level.Base, "The first cave's level")
check(RiftRun.level({ 5, 9 }, 4) == 7 + RiftRun.Level.Base + 3 * RiftRun.Level.PerRoom, "The last cave's level")
check(
	RiftRun.level({ 5, 9 }, RiftRun.Rooms + 1) == RiftRun.level({ 5, 9 }, RiftRun.Rooms) + RiftRun.Level.Boss,
	"The boss's level"
)
check(RiftRun.level({}, 1) == 1 + RiftRun.Level.Base, "No kaiju: level one and up")
check(RiftRun.level({ 99 }, 4) == RiftRun.Level.Max, "Past the top level")

-- The boss --------------------------------------------------------------------------------------------------

local bosses = {}
local bossRng = Random.new(17)
for _ = 1, 400 do
	local boss = RiftRun.pickBoss(bossRng)
	check(table.find(DungeonRules.Bosses, boss) ~= nil, "A boss that isn't a brainrot boss")
	bosses[boss.Id] = true
end
for _, spec in DungeonRules.Bosses do
	check(bosses[spec.Id], spec.Name .. " never comes")
	-- (A Colossus: the pathway dungeon's boss fighter, with its every move.)
	check(type(spec.Moves) == "table" and #spec.Moves >= 3, spec.Name .. " has no moves to fight with")
	check(spec.Element and spec.Weakness and spec.Element ~= spec.Weakness, spec.Name .. " has no element")
end
check(RiftRun.bossHealth(1) == RiftRun.Boss.Health and RiftRun.Boss.Health > 1, "The boss alone, no tougher")
check(
	RiftRun.bossHealth(3) > RiftRun.bossHealth(2) and RiftRun.bossHealth(2) > RiftRun.bossHealth(1),
	"The boss isn't tougher with more of you"
)
local tiers = {}
for _ = 1, 200 do
	check(RiftRun.bossTier(1, bossRng) == 4, "A boss alone that isn't gear tier 4")
	tiers[RiftRun.bossTier(3, bossRng)] = true
end
check(tiers[4] and tiers[5] and not tiers[3], "A party's boss isn't tier 4 or 5")
check(RiftRun.addsDue(0.9, {}) == nil, "Critters called at full health")
check(RiftRun.addsDue(0.6, {}) == 1 and RiftRun.addsDue(0.6, { [1] = true }) == nil, "The first call")
check(RiftRun.addsDue(0.2, { [1] = true }) == 2 and RiftRun.addsDue(0.2, {}) == 1, "The second call")
check(RiftRun.Boss.AddCount >= 1 and RiftRun.Boss.AddFighters >= 1, "The boss calls nobody")
-- Its loot (Shared.BossLoot): every boss a threat and a favourite kind of
-- gear; the higher its threat, the tougher it is and the richer its cache.
do
	local BossLoot = load("BossLoot")
	local Slots = load("EquipmentSlots")
	local seen = {}
	for _, boss in DungeonRules.Bosses do
		local threat = BossLoot.threat(boss)
		check(boss.Threat == threat, boss.Id .. "'s threat isn't 1 to 3")
		check(table.find(Slots.Kinds, boss.Loot) ~= nil, boss.Id .. " favours no kind of gear")
		seen[threat] = true
		local m = BossLoot.spec(boss)
		check(m.Element == boss.Element and m.Focus == boss.Loot and m.Name == boss.Name, boss.Id .. "'s cache")
		check(RiftRun.bossHealth(1, boss) == RiftRun.Boss.Health * BossLoot.health(boss), boss.Id .. "'s health")
	end
	check(seen[1] and seen[2] and seen[3], "Not every threat has a boss")
	for t = 2, #BossLoot.Threats do
		local lo, hi = BossLoot.Threats[t - 1], BossLoot.Threats[t]
		check(
			hi.Health > lo.Health and hi.UltraRare > lo.UltraRare and hi.Gems >= lo.Gems and hi.Quality >= lo.Quality,
			"Threat " .. t .. " isn't tougher and richer"
		)
	end
	check(BossLoot.threat({}) == 2 and BossLoot.threat({ Threat = 9 }) == 3 and BossLoot.threat(nil) == 2, "A threat out of range")
	check(BossLoot.numeral(1) == "I" and BossLoot.numeral(3) == "III", "Threat numerals")
	check(BossLoot.FocusCount >= 1 and BossLoot.FocusCount <= 3, "Its favourite kind's share")
end
-- Each biome's ladder (picked at its gate): every boss on exactly one, of
-- its element, threat I (built for one) first and a group boss last, rising;
-- each opens once the one before it is beaten; the Rift's fighters of its
-- element.
do
	local onLadder = {}
	for element, ids in RiftRun.Ladders do
		local ladder = RiftRun.ladder(element)
		check(#ladder == #ids and #ladder >= 2, element .. "'s ladder")
		for i, boss in ladder do
			check(boss.Element == element, boss.Id .. " on another element's ladder")
			check(not onLadder[boss.Id], boss.Id .. " on two ladders")
			onLadder[boss.Id] = true
			if i > 1 then
				check(boss.Threat > ladder[i - 1].Threat, element .. "'s ladder doesn't rise")
			end
		end
		check(ladder[1].Threat == 1, element .. "'s first boss isn't built for one")
		for i, boss in ladder do
			local level = RiftRun.bossLevel({ 6 }, boss)
			check(i == 1 or level > RiftRun.bossLevel({ 6 }, ladder[i - 1]), element .. "'s levels don't rise")
			check(level == RiftRun.level({ 6 }, RiftRun.Rooms) + RiftRun.Level.Threat[boss.Threat], boss.Id .. "'s level")
			check(RiftRun.bossLevel({ 99 }, boss) == RiftRun.Level.Max, boss.Id .. "'s level past the top")
		end
		check(RiftRun.isGroup(ladder[#ladder]) and not RiftRun.isGroup(ladder[1]), element .. "'s last boss isn't a group's")
		check(RiftRun.canFight(element, ladder[1].Id, {}), element .. "'s first boss is locked")
		local ok, why, need = RiftRun.canFight(element, ladder[2].Id, {})
		check(not ok and need == ladder[1] and why == "Beat " .. ladder[1].Name .. " first.", element .. "'s second boss is open")
		check(RiftRun.canFight(element, ladder[2].Id, { [ladder[1].Id] = 1 }), "Beating the first didn't open the second")
		check(
			RiftRun.nextBoss(element, {}) == ladder[1] and RiftRun.nextBoss(element, { [ladder[1].Id] = 2 }) == ladder[2],
			element .. "'s next boss"
		)
		local all = {}
		for _, boss in ladder do
			all[boss.Id] = 1
		end
		check(RiftRun.nextBoss(element, all) == ladder[#ladder], "All beaten, the gate doesn't offer the top")
		for _ = 1, 20 do
			for _, fighter in RiftRun.pickFighters(1, 1, bossRng, element) do
				check(fighter.Element == element, "A fighter of another element")
			end
		end
	end
	for _, boss in DungeonRules.Bosses do
		check(onLadder[boss.Id], boss.Id .. " is on no ladder")
	end
	check(not RiftRun.canFight("Fire", "Paperotti", {}), "Another element's boss behind a gate")
end

-- Falling, restoring, winning ---------------------------------------------------------------------------------

check(RiftRun.robCount(0) == 0 and RiftRun.robCount(1) == 1, "Robbed of nothing, or of the one")
check(RiftRun.robCount(4) == 2 and RiftRun.robCount(3) == 2, "Robbed of the wrong share")
check(RiftRun.restoreCost(0) == RiftRun.Restore.Coins, "RESTORE's first cost")
check(RiftRun.restoreCost(1) == RiftRun.Restore.Coins * RiftRun.Restore.Grow, "RESTORE doesn't go up")
check(RiftRun.cacheLuck(RiftRun.Rooms) > RiftRun.cacheLuck(1), "The caches aren't luckier further in")
check(RiftRun.Reward.Luck > RiftRun.cacheLuck(RiftRun.Rooms), "The boss's cache no luckier than a cave's")
check(RiftRun.rewardCoins(RiftRun.Rooms) > RiftRun.Reward.Coins, "The caves pay nothing")
check(RiftRun.solo(1) and not RiftRun.solo(2), "Alone")

-- The way: the pathway dungeon's rule, a path that never touches itself.
local layoutRng = Random.new(29)
for _ = 1, 300 do
	local cells = RiftRun.layout(layoutRng)
	check(#cells == RiftRun.Rooms + 2, "The way isn't a landing, the caves and the throne")
	check(cells[2].X == 0 and cells[2].Z == 1, "The landing doesn't face the way in")
	local seen = {}
	for i, cell in cells do
		local key = cell.X .. ":" .. cell.Z
		check(not seen[key], "The way crosses itself")
		seen[key] = i
		if i > 1 then
			local prev = cells[i - 1]
			check(math.abs(cell.X - prev.X) + math.abs(cell.Z - prev.Z) == 1, "A cave not next to the last")
		end
	end
	for i, cell in cells do
		for j, other in cells do
			if math.abs(i - j) > 1 then
				check(
					math.abs(cell.X - other.X) + math.abs(cell.Z - other.Z) > 1,
					"Two caves side by side that aren't joined"
				)
			end
		end
	end
end

-- The world ---------------------------------------------------------------------------------------------------

local RiftWorld = load("RiftWorld")
local origin = CFrame.new(-9000, 300, -9000)
local world = RiftWorld.build("T1", origin, Random.new(3))
check(world.Folder.Parent == workspace and world.Folder.Name == "Rift_T1", "The trip's world isn't in the workspace")
check(#world.Rooms == RiftRun.Rooms and #world.Gates == RiftRun.Rooms, "Not a cave and a wall of fire each")
local parts, solid = {}, {}
for _, d in world.Folder:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		if d.CanCollide then
			table.insert(solid, d)
		end
	end
end
check(#parts < 1700, "Too many parts for one trip: " .. #parts)
-- Standing on a point: a solid part right under it (at its floor).
local function standing(at: Vector3): boolean
	for _, p in solid do
		local rel = p.CFrame:PointToObjectSpace(at - Vector3.new(0, 0.5, 0))
		local half = p.Size / 2
		if p.Shape == R.Enum.PartType.Cylinder then
			local r = math.sqrt(rel.Y * rel.Y + rel.Z * rel.Z)
			if math.abs(rel.X) <= half.X + 0.6 and r <= half.Y then
				return true
			end
		elseif math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 0.6 and math.abs(rel.Z) <= half.Z then
			return true
		end
	end
	return false
end
-- A point inside something solid (a wall, a column, the floor's thickness).
local function blocked(at: Vector3): boolean
	for _, p in solid do
		local rel = p.CFrame:PointToObjectSpace(at)
		local half = p.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
			return true
		end
	end
	return false
end
local landing = origin.Position
check(standing(world.Start.Position - Vector3.new(0, 3, 0)), "Nothing to stand on where you land")
local look = world.Start.LookVector
local toFirst = (world.Rooms[1].Center - landing) * Vector3.new(1, 0, 1)
check(look:Dot(toFirst.Unit) > 0.95, "You land facing away from the way in")
-- The way from the landing to the throne: floor all the way (caves and
-- passages, level: nowhere to fall), nothing solid in your way but the
-- walls of fire.
local stops = { landing }
for _, cave in world.Rooms do
	table.insert(stops, cave.Center)
end
table.insert(stops, world.Boss.Center)
local floorY = landing.Y
for i = 2, #stops do
	local a, b = stops[i - 1], stops[i]
	check(math.abs(b.Y - floorY) < 0.01, "A cave off the level")
	local d = (b - a).Magnitude
	check(d > 100, "Two caves on top of each other")
	for t = 0, 1, 0.02 do
		local at = a:Lerp(b, t)
		check(standing(at), string.format("A gap in the floor between %d and %d at %.2f", i - 1, i, t))
		local gate = world.Gates[i - 2]
		local nearGate = gate ~= nil
			and ((gate:FindFirstChild("Wall").CFrame.Position - at) * Vector3.new(1, 0, 1)).Magnitude < 2
		if not nearGate then
			check(
				not blocked(at + Vector3.new(0, 3, 0)),
				string.format("Something in the way between %d and %d at %.2f", i - 1, i, t)
			)
		end
	end
end
-- Each cave: solid floor wall to wall, walled all round (too tall to climb)
-- but where the way goes on.
local function walledIn(area, label: string)
	local half = area.Size / 2
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local side = Vector3.new(-d.Z, 0, d.X)
		local open = false
		for _, s in { 0 } do
			local probe = area.Center + d * (half + 3) + side * s + Vector3.new(0, 3, 0)
			open = not blocked(probe)
		end
		local walls = 0
		for s = -half + 4, half - 4, 6 do
			if math.abs(s) > RiftWorld.Passage / 2 + 2 then
				local probe = area.Center + d * (half + 3) + side * s
				check(blocked(probe + Vector3.new(0, 3, 0)), label .. " has a gap in its wall")
				check(blocked(probe + Vector3.new(0, RiftWorld.Wall - 3, 0)), label .. "'s wall is too low")
				walls += 1
			end
		end
		check(walls > 0, label .. " has no wall")
		if open then
			-- (A way on: the passage's floor carries on out of it.)
			check(standing(area.Center + d * (half + 6)), label .. " opens onto nothing")
		end
	end
	for x = -half + 3, half - 3, 9 do
		for z = -half + 3, half - 3, 9 do
			check(standing(area.Center + Vector3.new(x, 0, z)), label .. " has a hole in its floor")
		end
	end
end
walledIn(world.Landing, "The landing")
for i, cave in world.Rooms do
	walledIn(cave, "Cave " .. i)
	check(cave.Size >= 60, "Cave " .. i .. " is too small to fight in")
	check(
		RiftWorld.inside(cave, cave.Center) and not RiftWorld.inside(cave, cave.Center + Vector3.new(cave.Size, 0, 0)),
		"inside() is wrong"
	)
end
walledIn(world.Boss, "The throne cave")
check(world.Boss.Size > world.Rooms[1].Size, "The throne cave is no bigger than a cave")
-- The passages' arches: high enough to fight under.
for _, d in world.Folder:GetDescendants() do
	if d:IsA("BasePart") and (d.Name == "Arch" or d.Name == "Fang") then
		-- (Each only turned about the vertical, or upside down: its Y is up.)
		local bottom = d.CFrame.Position.Y - d.Size.Y / 2
		check(bottom - floorY > 12, "A passage's roof hangs too low: " .. d.Name)
	end
end
-- The walls of fire: across the passage out of each cave, solid till opened.
for i, gate in world.Gates do
	local wall = gate:FindFirstChild("Wall")
	check(
		wall and wall.CanCollide and wall.Transparency < 1 and gate:GetAttribute("Room") == i,
		"Cave " .. i .. "'s wall of fire isn't there"
	)
	local cave = world.Rooms[i]
	local next_ = if i < #world.Rooms then world.Rooms[i + 1].Center else world.Boss.Center
	local mid = (cave.Center + next_) / 2
	local rel = (wall.CFrame.Position - mid) * Vector3.new(1, 0, 1)
	check(rel.Magnitude < 8, "Cave " .. i .. "'s fire isn't across the way out")
	check(wall.Size.X >= RiftWorld.Passage, "Cave " .. i .. "'s fire doesn't bar the passage")
	local fires, tongues = 0, 0
	for _, d in gate:GetDescendants() do
		if d:IsA("Fire") then
			fires += 1
		end
	end
	for _, d in gate:GetChildren() do
		if d.Name == "Tongue" then
			tongues += 1
		end
	end
	check(fires >= 3 and tongues >= 8, "Cave " .. i .. "'s wall has no flames")
end
RiftWorld.openGate(world.Gates[1])
local wall = world.Gates[1]:FindFirstChild("Wall")
check(
	not wall.CanCollide and wall.Transparency == 1 and world.Gates[1]:GetAttribute("Open"),
	"The fire didn't die down"
)
for _, d in world.Gates[1]:GetChildren() do
	if d.Name == "Tongue" then
		check(d.Transparency == 1, "A flame still licking up in an opened gate")
	end
end
for _, d in world.Gates[1]:GetDescendants() do
	if d:IsA("Fire") then
		check(not d.Enabled, "A flame still burning in an opened gate")
	end
end
check(world.Gates[2]:FindFirstChild("Wall").CanCollide, "Opening one opened another")
-- Where each leads (the arrows on the ground go there once it's open): a
-- little way into the next cave, on the far side of the fire.
for i, gate in world.Gates do
	local into = gate:GetAttribute("Into")
	local next = world.Rooms[i + 1] or world.Boss
	local here = world.Rooms[i]
	check(typeof(into) == "Vector3", "Gate " .. i .. " doesn't say where it leads")
	check(RiftWorld.inside(next, into) and not RiftWorld.inside(here, into), "Gate " .. i .. " doesn't lead into the next cave")
	local wallAt = gate:FindFirstChild("Wall").CFrame.Position
	local on = (next.Center - here.Center) * Vector3.new(1, 0, 1)
	check(((into - wallAt) * Vector3.new(1, 0, 1)):Dot(on.Unit) > 10, "Gate " .. i .. " leads back the way you came")
end
-- The ways home: the landing's open, the throne cave's shut till it's down.
local function promptOf(part)
	return part and part:FindFirstChildOfClass("ProximityPrompt")
end
local exit = promptOf(world.Exit)
check(
	exit and exit.Enabled and exit:GetAttribute("PromptKind") == "RiftExit" and world.Exit.Transparency < 1,
	"No way home in the landing"
)
check(RiftWorld.inside(world.Landing, world.Exit.CFrame.Position), "The landing's way home isn't in the landing")
local opening = world.Home:FindFirstChild("Opening")
local home = promptOf(opening)
check(
	home and not home.Enabled and opening.Transparency == 1,
	"The throne cave's way home is open before the boss is down"
)
check(RiftWorld.inside(world.Boss, opening.CFrame.Position), "The throne cave's way home is outside it")
RiftWorld.openHome(world)
check(home.Enabled and opening.Transparency < 1, "The way home didn't open")
-- No lava, nothing to fall into.
check(world.Folder:FindFirstChild("Lava", true) == nil, "Lava again")
-- The place: a scar torn across the sky, clouds, falling ash, fire to see by.
local sky = world.Folder:FindFirstChild("Sky")
check(sky ~= nil, "No sky")
local scars, clouds = 0, 0
for _, d in sky:GetDescendants() do
	if d.Name == "Scar" then
		scars += 1
		check(d.CFrame.Position.Y - floorY > 150 and not d.CanCollide, "The scar isn't up in the sky")
	elseif d.Name == "Cloud" then
		clouds += 1
	end
end
check(scars >= 8 and clouds >= 8, "No scar or clouds in the sky")
local ash = sky:FindFirstChild("Ash")
check(ash and ash:FindFirstChildOfClass("ParticleEmitter") ~= nil, "No ash falling")
local fires, lights = 0, 0
for _, d in world.Folder:GetDescendants() do
	if d:IsA("Fire") then
		fires += 1
	elseif d:IsA("PointLight") then
		lights += 1
	end
end
check(
	fires >= RiftRun.Rooms * 4 and lights >= RiftRun.Rooms * 4,
	"Not hellish enough: " .. fires .. " fires, " .. lights .. " lights"
)
-- The fallen (Server.World.FallenMiners): a couple by each cave's walls,
-- more round the throne and their heap beside it; props you walk through,
-- never in a passage's way, clear of the way home.
local FallenMiners = load("FallenMiners")
local function flatGap(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
-- How far a point is off the line through two points (a passage's middle).
local function offLine(p: Vector3, a: Vector3, b: Vector3): number
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local rel = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	return (rel - along * rel:Dot(along)).Magnitude
end
local caves = { world.Landing, table.unpack(world.Rooms) }
table.insert(caves, world.Boss)
local fallenIn, heaps = {}, {}
for _, d in world.Folder:GetChildren() do
	if d.Name ~= "FallenMiner" and d.Name ~= "FallenHeap" then
		continue
	end
	local at, count = nil, 0
	for _, p in d:GetDescendants() do
		if p:IsA("BasePart") then
			count += 1
			at = at or p.CFrame.Position
			check(not p.CanCollide and not p.CanTouch and not p.CanQuery, d.Name .. " has a part you'd bump into")
		end
	end
	check(count > 10 and count < 70, d.Name .. " has " .. count .. " parts")
	local home
	for i, cave in caves do
		if RiftWorld.inside(cave, at) then
			home = i
		end
	end
	check(home ~= nil, d.Name .. " lies outside the caves")
	check(home ~= 1, "A fallen miner on the landing (they're further in)")
	if d.Name == "FallenHeap" then
		table.insert(heaps, home)
	else
		check(table.find(FallenMiners.Poses, d:GetAttribute("Pose")) ~= nil, "A fallen miner without a pose")
		fallenIn[home] = (fallenIn[home] or 0) + 1
	end
	-- Not in the way: off the line from the cave's middle to each of its
	-- ways through, and clear of the way home.
	for _, j in { home - 1, home + 1 } do
		local next = caves[j]
		if next then
			local center = caves[home].Center
			local out = Vector3.new(next.Center.X - center.X, 0, next.Center.Z - center.Z)
			if Vector3.new(at.X - center.X, 0, at.Z - center.Z):Dot(out) > 0 then
				check(offLine(at, center, next.Center) > RiftWorld.Passage / 2, d.Name .. " lies in the way through")
			end
		end
	end
	check(flatGap(at, opening.CFrame.Position) > 7, d.Name .. " lies in the way home")
end
check(#heaps == 1 and heaps[1] == #caves, "The heap isn't by the throne")
for i = 2, #caves - 1 do
	check((fallenIn[i] or 0) == FallenMiners.Count.Cave, "Cave " .. (i - 1) .. " has " .. (fallenIn[i] or 0) .. " fallen")
end
check((fallenIn[#caves] or 0) >= FallenMiners.Count.Cave * 2, "No more of them round the throne than in a cave")
-- Scattered alone: by the walls first, clear of what it's told to avoid,
-- out of the doorway.
do
	local holder = R.Instance.new("Folder")
	local avoid = { At = Vector3.new(20, 0, 0), Radius = 12 }
	local placed = FallenMiners.scatter(
		holder,
		Vector3.new(0, 0, 0),
		60,
		8,
		Random.new(5),
		{ Doors = { Vector3.new(0, 0, 1) }, Avoid = { avoid } }
	)
	check(#placed >= 4 and #placed <= 8, "Scattered " .. #placed .. " of 8")
	check(placed[1]:GetAttribute("Pose") == "Curled", "The first isn't curled by a wall")
	for _, model in placed do
		local p = model:FindFirstChildWhichIsA("BasePart", true).CFrame.Position
		check(flatGap(p, avoid.At) >= avoid.Radius - 3, "Scattered onto what it should avoid")
		check(math.abs(p.X) < 31 and math.abs(p.Z) < 31, "Scattered outside the room")
		check(not (p.Z > 22 and math.abs(p.X) < 8), "Scattered in the doorway")
	end
	holder:Destroy()
end
-- And in the dungeon: one in each room, more in the boss's, and the heap.
do
	local DungeonWorld = load("DungeonWorld")
	local rooms = DungeonRules.generate(Random.new(8))
	local at = Vector3.new(4000, 0, 4000)
	local folder = DungeonWorld.build("T3", rooms, at).Folder
	local per, heap = {}, 0
	for _, d in folder:GetChildren() do
		if d.Name == "FallenHeap" then
			heap += 1
		elseif d.Name == "FallenMiner" then
			local p = d:FindFirstChildWhichIsA("BasePart", true).CFrame.Position
			local best, room = math.huge, nil
			for i, r in rooms do
				local gap = flatGap(p, at + Vector3.new(r.X * DungeonRules.Spacing, 0, r.Z * DungeonRules.Spacing))
				if gap < best then
					best, room = gap, i
				end
			end
			check(best < 32, "A dungeon's fallen miner outside its room")
			per[room] = (per[room] or 0) + 1
		end
	end
	check(heap == 1, "No heap in the boss's room")
	for i, room in rooms do
		if room.Boss then
			check((per[i] or 0) > FallenMiners.Count.Room, "No more of them in the boss's room")
		else
			check(per[i] == FallenMiners.Count.Room, "Room " .. i .. " has " .. (per[i] or 0) .. " fallen")
		end
	end
	folder:Destroy()
end
-- Each boss's realm (Shared.RiftRealms): its trip is built in its own
-- colours with its own set pieces by the walls, no two alike, still
-- hellish (fire and light to see by), the floor's middle still clear for
-- the fight, and the client lights the air its way.
local RiftRealms = load("RiftRealms")
local PIECES = {
	Craters = { "Crater", "DudBomb" },
	Logs = { "Trunk", "Burning", "Log" },
	Floes = { "Pond", "Hail" },
	Tide = { "Crest", "Fin" },
	Freezer = { "IceBlock", "Icicle" },
	Vines = { "Vine", "Trunk", "Banana" },
	Spires = { "Spire", "Arc" },
	Blades = { "Blade", "Kunai" },
	Bog = { "Pool", "Reed", "Mound" },
	Grove = { "Trunk", "Bough", "Cap" },
}
local seenGate, seenFeature, seenName = {}, {}, {}
-- How each is built (RiftStyles): its walls, floor, barrier, lamps, arch
-- and throne are each of a kind no other realm has; its sky one of four.
local seenStyle = { Wall = {}, Floor = {}, Gate = {}, Lamp = {}, Arch = {}, Throne = {} }
for n, id in RiftRealms.Order do
	local realm = RiftRealms.of(id)
	check(realm.Id == id and realm.Boss == id and RiftRun.bossById(id) ~= nil, id .. ": not a boss's realm")
	check(realm.Element == RiftRun.bossById(id).Element, id .. ": its realm isn't its element's")
	check(not seenFeature[realm.Feature] and not seenName[realm.Name], id .. ": its realm is another boss's")
	seenFeature[realm.Feature], seenName[realm.Name] = true, true
	for kind, seen in seenStyle do
		local style = realm.Style[kind]
		check(type(style) == "string" and not seen[style], id .. ": its " .. kind .. " is built like " .. tostring(seen[style]) .. "'s")
		seen[style] = id
	end
	check(({ Scar = 1, Aurora = 1, Storm = 1, SporeMoon = 1 })[realm.Style.Sky], id .. ": no sky")
	local trip = RiftWorld.build("R" .. n, origin * CFrame.new(-2000 * n, 0, 0), Random.new(10 + n), realm)
	check(trip.Folder:GetAttribute("Realm") == id, id .. ": the trip isn't marked with its realm")
	local wall = trip.Gates[1]:FindFirstChild("Wall")
	local gateColor = string.format("%.2f/%.2f/%.2f", wall.Color.R, wall.Color.G, wall.Color.B)
	check(not seenGate[gateColor], id .. ": its walls across the passages are " .. tostring(seenGate[gateColor]) .. "'s")
	seenGate[gateColor] = id
	-- Its set pieces, in every cave; fire and light; the rock its colour.
	local found, fires, lights, count, rock = {}, 0, 0, 0, 0
	for _, d in trip.Folder:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			found[d.Name] = (found[d.Name] or 0) + 1
			if d.Name == "RockWall" and d.Color == realm.Rock then
				rock += 1
			end
		elseif d:IsA("Fire") then
			fires += 1
			check(d.Color == realm.Flame, id .. ": a fire not in its colour")
		elseif d:IsA("PointLight") then
			lights += 1
		end
	end
	for _, piece in PIECES[realm.Feature] do
		check((found[piece] or 0) >= 2, id .. ": no " .. piece .. " in its caves")
	end
	check(rock >= 20, id .. ": its walls aren't its rock")
	check(fires >= RiftRun.Rooms * 4 and lights >= RiftRun.Rooms * 6, id .. ": not hellish enough")
	check(count < 1700, id .. ": too many parts, " .. count)
	-- The middle of every cave stays clear for the fight: nothing solid
	-- standing within 16 studs of its centre but the floor.
	for _, cave in { trip.Landing, trip.Boss, table.unpack(trip.Rooms) } do
		for _, d in trip.Folder:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide and d.Name ~= "Floor" then
				local off = (d.CFrame.Position - cave.Center) * Vector3.new(1, 0, 1)
				check(off.Magnitude > 16 or d.CFrame.Position.Y - cave.Center.Y > 20, id .. ": " .. d.Name .. " stands in the middle of a cave")
			end
		end
	end
	local sky = trip.Folder:FindFirstChild("Sky")
	local scars, clouds = 0, 0
	for _, d in sky:GetDescendants() do
		if d.Name == "Scar" then
			scars += 1
		elseif d.Name == "Cloud" then
			clouds += 1
		end
	end
	check(scars >= 8 and clouds >= 8, id .. ": nothing burns in its sky")
	check(sky:FindFirstChild("Ash"):FindFirstChildOfClass("ParticleEmitter").Rate == realm.Ash.Rate, id .. ": its sky drops the wrong ash")
	-- Every barrier bars its passage (a solid Wall across it, 8 strands and
	-- 3 fires at least), and every arch hangs clear of the floor.
	for i, gate in trip.Gates do
		local wall = gate:FindFirstChild("Wall")
		check(wall and wall.CanCollide and wall.Size.X >= RiftWorld.Passage, id .. ": gate " .. i .. " doesn't bar the way")
		local tongues, flames = 0, 0
		for _, d in gate:GetDescendants() do
			if d.Name == "Tongue" then
				tongues += 1
			elseif d:IsA("Fire") then
				flames += 1
			end
		end
		check(tongues >= 8 and flames >= 3, id .. ": gate " .. i .. " has no curtain (" .. tongues .. ", " .. flames .. ")")
	end
	for _, d in trip.Folder:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Arch" or d.Name == "Fang") then
			check(d.CFrame.Position.Y - d.Size.Y / 2 - trip.Boss.Center.Y > 12, id .. ": a passage's roof hangs too low: " .. d.Name)
		end
	end
	check(trip.Folder:FindFirstChild("Throne"):FindFirstChildOfClass("PointLight", true) ~= nil, id .. ": a dark throne")
	trip.Folder:Destroy()
end
check(RiftRealms.of("Nobody") == RiftRealms.Default, "A boss with no realm has no world")
-- The client lights the air in the realm's colours (RiftClient.lightingFor).
do
	local client = fs.readFile(ROOT .. "/src/client/Modules/RiftClient.luau")
	check(client:find("RiftRealms.of(player:GetAttribute(\"RiftRealm\"))", 1, true) ~= nil, "The client doesn't light the realm you're in")
	for _, key in { "Ambient", "Outdoor", "HazeColor", "HazeDecay", "Tint" } do
		check(client:find("\"" .. key .. "\"", 1, true) ~= nil or client:find("air." .. key, 1, true) ~= nil, "The client ignores the realm's " .. key)
	end
	local server = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
	check(server:find('RiftWorld.build, id, origin, rng, RiftRealms.of(boss and boss.Id)', 1, true) ~= nil, "The server doesn't build the boss's realm")
	check(server:find('"RiftRealm"', 1, true) ~= nil, "Runners aren't told their realm")
end
-- Two trips side by side never meet (RiftServer's slots).
local other = RiftWorld.build("T2", origin * CFrame.new(-2000, 0, 0), Random.new(4))
for _, a in { other.Landing, other.Boss, table.unpack(other.Rooms) } do
	for _, b in { world.Landing, world.Boss, table.unpack(world.Rooms) } do
		check((a.Center - b.Center).Magnitude > 400, "Two trips' worlds overlap")
	end
end
world.Folder:Destroy()
other.Folder:Destroy()

-- The server hands out the right things -----------------------------------------------------------------------

local server = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
check(server:find('Gems.award(player, "RiftCache"', 1, true) ~= nil, "Caches aren't Rift gems")
local gems = fs.readFile(ROOT .. "/src/shared/GemConfig.luau")
check(gems:find('RiftCache = "Found in the Rift"', 1, true) ~= nil, "A Rift gem has no source label")
local main = fs.readFile(ROOT .. "/src/server/Main.server.luau")
check(
	main:find("RiftServer.start(OutpostServer.site())", 1, true)
		and main:find("RiftServer.gateAt = OutpostServer.veinGate", 1, true),
	"The Rift isn't started"
)
local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
check(
	scene:find('kind == "Rift"', 1, true) and scene:find('kind == "RiftExit"', 1, true),
	"The gates' prompts aren't heard"
)
-- Nothing else starts for you while you're in there (it would pull you out
-- mid-trip, and the trip would read it as a fall).
for _, name in { "SparServer", "KaijuBattles", "Duels", "Raids", "ArenaSessions", "MineWall" } do
	local source = fs.readFile(ROOT .. "/src/server/Systems/" .. name .. ".luau")
	check(
		source:find('GetAttribute("RiftRun")', 1, true) or source:find('"RiftRun" }', 1, true),
		name .. " starts for a runner in the Rift"
	)
end

-- The KIT OUT bar (Client.SparKit) sits under the strip (Client.RiftClient),
-- never behind it, as it did when both took the top middle.
do
	local kit = fs.readFile(ROOT .. "/src/client/Modules/SparKit.luau")
	local rift = fs.readFile(ROOT .. "/src/client/Modules/RiftClient.luau")
	check(rift:find('Name = "RiftStrip"', 1, true) ~= nil, "The strip isn't named RiftStrip")
	check(
		kit:find('riftGui:FindFirstChild("RiftStrip")', 1, true) ~= nil
			and kit:find("top = riftStrip.AbsolutePosition.Y + riftStrip.AbsoluteSize.Y", 1, true) ~= nil
			and kit:find("bar.Position = UDim2.new(0.5, 0, 0, top)", 1, true) ~= nil,
		"The KIT OUT bar isn't put under the Rift's strip"
	)
end

-- The gate's lobby (Shared.RiftLobby): your party's places, the miners in
-- the Outpost and your friends online, and who you can invite.
do
	local Lobby = load("RiftLobby")
	local others = {
		{ UserId = 35, Name = "Kadey", Level = 14, Outpost = true, Near = true },
		{ UserId = 49, Name = "Mirabel", Level = 9, Outpost = true, Party = "Other" },
		{ UserId = 42, Name = "Orrinn", Level = 22, Outpost = true, InRift = true },
		{ UserId = 56, Name = "Junipers", Level = 30, Outpost = false },
		{ UserId = 63, Name = "Abel", Level = 3, Outpost = true },
	}
	local friends = {
		{ VisitorId = 902, DisplayName = "Theo", PlaceId = 555 },
		{ VisitorId = 901, DisplayName = "Sasha", PlaceId = 7 },
		{ VisitorId = 35, DisplayName = "Kadey", PlaceId = 7 },
	}
	local function rowOf(list, id)
		for _, row in list do
			if row.UserId == id then
				return row
			end
		end
		return nil
	end
	-- On your own: you in the first place, ready, no leader; the rest open.
	local solo = Lobby.lobby({ Me = 1, MeName = "Marc", Players = others, Friends = friends, Invited = {}, PlaceId = 7 })
	check(solo.Lead and solo.Size == 1 and solo.Ready == 0 and not solo.Trip and solo.Known, "On your own, the lobby's wrong")
	check(solo.Slots[1] and solo.Slots[1].You and solo.Slots[1].Name == "Marc" and solo.Slots[1].Ready and not solo.Slots[1].Leader, "Your place on your own")
	check(#solo.Slots == RiftRun.Party and solo.Slots[2] == false and solo.Slots[RiftRun.Party] == false, "The open places")
	-- The Outpost: at the gate first, your friends next, then by name; not
	-- whoever's out of the Outpost; who's in a party or the Rift can't be asked.
	check(#solo.Outpost == 4 and rowOf(solo.Outpost, 56) == nil, "Someone out of the Outpost is listed, or someone's missing")
	check(solo.Outpost[1].UserId == 35 and solo.Outpost[1].Where == "At the gate" and solo.Outpost[1].Friend, "Who's at the gate isn't first")
	check(rowOf(solo.Outpost, 35).Invite == "Party" and rowOf(solo.Outpost, 63).Invite == "Party", "You can't ask a miner into your party")
	check(rowOf(solo.Outpost, 49).Invite == "Busy" and rowOf(solo.Outpost, 42).Invite == "Busy", "You can ask someone in a party or the Rift")
	check(rowOf(solo.Outpost, 42).Where == "In the Rift" and rowOf(solo.Outpost, 63).Where == "In the Outpost", "Where they are")
	-- Friends: here first (into your party), then in this game elsewhere,
	-- then online (Roblox's invite); asked a moment ago, "Invited".
	check(#solo.Friends == 3 and solo.Friends[1].UserId == 35 and solo.Friends[2].UserId == 901 and solo.Friends[3].UserId == 902, "Your friends' order")
	check(solo.Friends[1].Invite == "Party" and solo.Friends[2].Invite == "Game" and solo.Friends[3].Invite == "Game", "Your friends' invites")
	check(solo.Friends[2].Where == "Playing, another server" and solo.Friends[3].Where == "Online", "Where your friends are")
	local asked = Lobby.lobby({ Me = 1, MeName = "Marc", Players = others, Friends = friends, Invited = { [35] = true, [902] = true }, PlaceId = 7 })
	check(rowOf(asked.Outpost, 35).Invite == "Invited" and rowOf(asked.Friends, 902).Invite == "Invited", "Asked a moment ago, not shown as invited")
	check(not Lobby.lobby({ Me = 1, Players = others, Invited = {} }).Known, "Your friends known before they're fetched")
	-- In someone's party: you first, the leader next; only the leader asks.
	local party = {
		Leader = 21,
		Members = {
			{ UserId = 28, Name = "Bram", Ready = false },
			{ UserId = 21, Name = "Ivy", Ready = true },
			{ UserId = 1, Name = "Marc", Ready = true },
		},
	}
	local mates = table.clone(others)
	table.insert(mates, { UserId = 21, Name = "Ivy", Outpost = true, Party = "Mine", Near = true })
	table.insert(mates, { UserId = 28, Name = "Bram", Outpost = true, Party = "Mine" })
	local member = Lobby.lobby({ Me = 1, Party = party, Players = mates, Friends = friends, Invited = {}, PlaceId = 7 })
	check(not member.Lead and member.Size == 3 and member.Ready == 1, "In someone's party, the lobby's wrong")
	check(member.Slots[1].UserId == 1 and member.Slots[2].UserId == 21 and member.Slots[2].Leader and member.Slots[3].UserId == 28, "You, then the leader, then the rest")
	check(member.Slots[2].Where == "At the gate" and member.Slots[3].Where == "In the Outpost" and member.Slots[4] == false, "Where your party is")
	check(rowOf(member.Outpost, 21) == nil and rowOf(member.Outpost, 35).Invite == nil, "Your party's listed again, or you can invite without leading")
	-- Leading a full party: nobody else to ask in.
	party.Leader = 1
	table.insert(party.Members, { UserId = 63, Name = "Abel", Ready = true })
	local full = Lobby.lobby({ Me = 1, Party = party, Players = mates, Friends = friends, Invited = {}, PlaceId = 7 })
	check(full.Lead and full.Size == RiftRun.Party and rowOf(full.Outpost, 35).Invite == nil, "A full party can still invite")
	check(full.Slots[1].Leader and full.Slots[1].You and full.Ready == 2, "Leading: you lead, two of the others ready")
	-- One of your party in the Rift already: going in, you join them.
	mates[#mates].InRift = true
	check(Lobby.lobby({ Me = 1, Party = party, Players = mates, Invited = {} }).Trip, "One of your party in the Rift isn't a trip to join")
	-- Down in the Rift, who you can call in: your party first (no button),
	-- then the Outpost, then your friends, each once.
	local down = Lobby.backup(Lobby.lobby({ Me = 1, Party = party, Players = mates, Friends = friends, Invited = {}, PlaceId = 7 }))
	check(#down >= 3 and down[1].Party and down[2].Party and down[3].Party, "Your party isn't first in the backup list")
	check(down[1].Invite == "Busy" and rowOf(down, 1) == nil, "Your party can be invited again, or you're listed")
	check(rowOf(down, 28).Where == "With you in the Rift", "A party member in the Rift isn't said to be with you")
	check(string.find(rowOf(down, 21).Where, "In your party", 1, true) ~= nil, "A party member's row doesn't say so")
	local ids = {}
	for _, row in down do
		check(not ids[row.UserId], "Someone's in the backup list twice: " .. tostring(row.Name))
		ids[row.UserId] = true
	end
	check(rowOf(down, 35) ~= nil and rowOf(down, 902) ~= nil and rowOf(down, 902).Invite == "Game", "The Outpost and your friends aren't in the backup list")
	check(#Lobby.backup(solo) == #solo.Outpost + #solo.Friends - 1, "On your own, the list isn't the Outpost and your friends (a friend here once)")
	-- The down card draws it, and the server lets the called in join at the throne.
	local client = fs.readFile(ROOT .. "/src/client/Modules/RiftClient.luau")
	local server = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
	check(client:find("CALL FOR BACKUP", 1, true) ~= nil and client:find("RiftLobby.backup(", 1, true) ~= nil, "The down card has no backup list")
	check(client:find('GemClient.request("PartyInvite"', 1, true) ~= nil, "The down card can't invite")
	check(client:find("INVITE A FRIEND", 1, true) == nil, "The old INVITE A FRIEND button's still on the down card")
	check(server:find("run.Room <= RiftRun.Rooms and #run.Members", 1, true) == nil, "Backup can't join at the throne")
end

print(
	string.format(
		"PASS: %d Rift checks (packs and fighters, levels, the ten bosses, falling, RESTORE, rewards, the way, the world: walled caves, floor all the way, walls of fire and where they lead, ways home, the sky, healing crystals, the fallen, each boss's realm; the KIT OUT bar under the strip; the gate's lobby; the down card's backup list; %d parts a trip)",
		checks,
		#parts
	)
)
