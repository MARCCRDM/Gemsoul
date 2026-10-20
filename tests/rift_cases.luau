-- The Rift's rules (Shared.RiftRun) and its world (Server.RiftWorld) on
-- Roblox instances (lune's roblox library): the islands' packs, sized for
-- how many are in and big ones now and then, at the kaiju's level and up;
-- one of the ten brainrot bosses, each with a move of its own, tougher
-- with more runners, calling critters through as it weakens; what falling
-- costs, what RESTORE costs and what a win pays. The world: a landing with
-- its way home, islands one after another joined by causeways you can walk,
-- a wall of fire across the way out of each (until it's opened), the boss's
-- island with its way home shut till the boss is down, lava under it all
-- you fall through. Run by tests/run_rift.py.
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
	check(RiftRun.foeCount(room, 1) > RiftRun.foeCount(room - 1, 1), "The packs don't grow further in")
end
check(
	RiftRun.foeCount(1, 2) > RiftRun.foeCount(1, 1) and RiftRun.foeCount(1, 4) > RiftRun.foeCount(1, 2),
	"No more critters for more runners"
)
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
	end
end
check(elites[1] == 0, "A big one on the first island")
check(elites[2] > 40 and elites[RiftRun.Rooms] > 40, "Hardly ever a big one further in")

-- Levels: their kaiju's and up, a level more each island, the boss above.
check(RiftRun.level({ 5, 9 }, 1) == 7 + RiftRun.Level.Base, "The first island's level")
check(RiftRun.level({ 5, 9 }, 4) == 7 + RiftRun.Level.Base + 3 * RiftRun.Level.PerRoom, "The last island's level")
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
	local move = Kaiju.BugMoves[spec.Id]
	check(
		move and move.Name and (move.Shape == "Slam" or move.Shape == "Dash" or move.Shape == "Burst"),
		spec.Name .. " has no move of its own"
	)
	check(move.Every > 0 and move.Range > 0 and move.Windup > 0, spec.Name .. "'s move can't be used")
	check(not move.Ranged and table.find(Kaiju.Critters, spec.Id) == nil, "A boss among the critters")
	check((move.Radius or move.Length or 0) >= 12, spec.Name .. "'s move is a critter's size")
end
check(RiftRun.bossHealth(1) == RiftRun.Boss.Health, "The boss alone")
check(
	RiftRun.bossHealth(3) > RiftRun.bossHealth(2) and RiftRun.bossHealth(2) > RiftRun.bossHealth(1),
	"The boss isn't tougher with more of you"
)
check(RiftRun.addsDue(0.9, {}) == nil, "Critters called at full health")
check(RiftRun.addsDue(0.6, {}) == 1 and RiftRun.addsDue(0.6, { [1] = true }) == nil, "The first call")
check(RiftRun.addsDue(0.2, { [1] = true }) == 2 and RiftRun.addsDue(0.2, {}) == 1, "The second call")

-- Falling, restoring, winning ---------------------------------------------------------------------------------

check(RiftRun.robCount(0) == 0 and RiftRun.robCount(1) == 1, "Robbed of nothing, or of the one")
check(RiftRun.robCount(4) == 2 and RiftRun.robCount(3) == 2, "Robbed of the wrong share")
check(RiftRun.restoreCost(0) == RiftRun.Restore.Coins, "RESTORE's first cost")
check(RiftRun.restoreCost(1) == RiftRun.Restore.Coins * RiftRun.Restore.Grow, "RESTORE doesn't go up")
check(RiftRun.cacheLuck(RiftRun.Rooms) > RiftRun.cacheLuck(1), "The caches aren't luckier further in")
check(RiftRun.Reward.Luck > RiftRun.cacheLuck(RiftRun.Rooms), "The boss's cache no luckier than an island's")
check(RiftRun.rewardCoins(RiftRun.Rooms) > RiftRun.Reward.Coins, "The path's islands pay nothing")
check(RiftRun.solo(1) and not RiftRun.solo(2), "Alone")

-- The world ---------------------------------------------------------------------------------------------------

local RiftWorld = load("RiftWorld")
local origin = CFrame.new(-9000, 300, -9000)
local world = RiftWorld.build("T1", origin, Random.new(3))
check(world.Folder.Parent == workspace and world.Folder.Name == "Rift_T1", "The trip's world isn't in the workspace")
check(#world.Rooms == RiftRun.Rooms and #world.Gates == RiftRun.Rooms, "Not an island and a wall of fire each")
local parts, solid = {}, {}
for _, d in world.Folder:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		if d.CanCollide then
			table.insert(solid, d)
		end
	end
end
check(#parts < 1400, "Too many parts for one trip: " .. #parts)
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
local landing = origin.Position
check(standing(world.Start.Position - Vector3.new(0, 3, 0)), "Nothing to stand on where you land")
local look = world.Start.LookVector
local toFirst = (world.Rooms[1].Center - landing) * Vector3.new(1, 0, 1)
check(look:Dot(toFirst.Unit) > 0.95, "You land facing away from the way in")
-- The causeway from one island's rim to the next's (each island's floor is
-- flat; the way between slopes from one's height to the other's).
local function walkable(a: Vector3, ra: number, b: Vector3, rb: number, what: string)
	local dir = ((b - a) * Vector3.new(1, 0, 1)).Unit
	local from, to = a + dir * (ra - 3), b - dir * (rb - 3)
	for t = 0, 1, 0.05 do
		check(standing(from:Lerp(to, t)), string.format("A gap in the causeway to %s at %.2f", what, t))
	end
	check(
		math.abs(to.Y - from.Y) / ((to - from) * Vector3.new(1, 0, 1)).Magnitude < 0.2,
		"The way to " .. what .. " is too steep to walk"
	)
end
local radii = { 18 }
local previous = landing
for i, island in world.Rooms do
	check(standing(island.Center), "Island " .. i .. " has no floor")
	check(
		standing(island.Center + Vector3.new(island.Radius * 0.6, 0, 0)),
		"Island " .. i .. " is too small to fight on"
	)
	check((island.Center - previous).Magnitude > 60, "Island " .. i .. " on top of the last")
	check(island.Center.Z < previous.Z, "Island " .. i .. " isn't further in")
	-- The causeway to it: you can walk the whole way.
	walkable(previous, radii[i], island.Center, island.Radius, "island " .. i)
	previous = island.Center
	radii[i + 1] = island.Radius
end
check(standing(world.Boss.Center) and world.Boss.Center.Z < previous.Z, "No boss's island past the last")
walkable(previous, radii[#radii], world.Boss.Center, world.Boss.Radius, "the boss")
-- The walls of fire: across the way out of each island, solid till opened.
for i, gate in world.Gates do
	local wall = gate:FindFirstChild("Wall")
	check(
		wall and wall.CanCollide and wall.Transparency < 1 and gate:GetAttribute("Room") == i,
		"Island " .. i .. "'s wall of fire isn't there"
	)
	local island = world.Rooms[i]
	local next_ = if i < #world.Rooms then world.Rooms[i + 1].Center else world.Boss.Center
	local out = ((next_ - island.Center) * Vector3.new(1, 0, 1)).Unit
	local rel = (wall.CFrame.Position - island.Center) * Vector3.new(1, 0, 1)
	check(
		rel.Magnitude > island.Radius - 8 and rel.Unit:Dot(out) > 0.95,
		"Island " .. i .. "'s fire isn't on the way out"
	)
	local fires = 0
	for _, d in gate:GetDescendants() do
		if d:IsA("Fire") then
			fires += 1
		end
	end
	local tongues = 0
	for _, d in gate:GetChildren() do
		if d.Name == "Tongue" then
			tongues += 1
		end
	end
	check(fires >= 3 and tongues >= 8, "Island " .. i .. "'s wall has no flames")
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
-- The ways home: the landing's open, the boss's shut till it's down.
local function promptOf(part)
	return part and part:FindFirstChildOfClass("ProximityPrompt")
end
local exit = promptOf(world.Exit)
check(
	exit and exit.Enabled and exit:GetAttribute("PromptKind") == "RiftExit" and world.Exit.Transparency < 1,
	"No way home on the landing"
)
check((world.Exit.CFrame.Position - landing).Magnitude < 20, "The landing's way home isn't on the landing")
local opening = world.Home:FindFirstChild("Opening")
local home = promptOf(opening)
check(
	home and not home.Enabled and opening.Transparency == 1,
	"The boss island's way home is open before the boss is down"
)
check(
	(opening.CFrame.Position - world.Boss.Center).Magnitude < world.Boss.Radius,
	"The boss island's way home is off its island"
)
RiftWorld.openHome(world)
check(home.Enabled and opening.Transparency < 1, "The way home didn't open")
-- Lava under it all: glowing, nothing to stand on, under every island.
local lava = world.Folder:FindFirstChild("Lava")
check(lava and lava.Material == R.Enum.Material.Neon and not lava.CanCollide, "No lava (or lava you can stand on)")
check(
	math.abs(lava.CFrame.Position.Y - (landing.Y - RiftWorld.Floor)) < 0.01,
	"The lava isn't where the fall is measured from"
)
for _, island in world.Rooms do
	local rel = lava.CFrame:PointToObjectSpace(island.Center)
	check(math.abs(rel.X) < lava.Size.X / 2 and math.abs(rel.Z) < lava.Size.Z / 2, "An island with no lava under it")
end
check(RiftWorld.Floor < RiftRun.Fall.Below, "You'd stand in the lava before you'd count as fallen")
-- The place: a blood moon, black spires, falling ash, fire to see by.
check(world.Folder:FindFirstChild("BloodMoon") ~= nil, "No blood moon")
local ash = world.Folder:FindFirstChild("Ash")
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
	fires >= RiftRun.Rooms * 4 and lights >= RiftRun.Rooms * 3,
	"Not hellish enough: " .. fires .. " fires, " .. lights .. " lights"
)
-- Two trips side by side never meet (RiftServer's slots).
local other = RiftWorld.build("T2", origin * CFrame.new(-2000, 0, 0), Random.new(4))
check((other.Boss.Center - world.Boss.Center).Magnitude > 1500, "Two trips' worlds overlap")
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

print(
	string.format(
		"PASS: %d Rift checks (packs, levels, the ten bosses and their moves, falling, RESTORE, rewards, the world: islands, causeways, walls of fire, ways home, lava; %d parts a trip)",
		checks,
		#parts
	)
)
