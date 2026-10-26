-- lune run tests/kaiju_roles_cases.luau <repo>
-- Kaiju battles as an auto battler (Shared.KaijuRoles, Server.
-- KaijuBattleBrain): each species' role and kit, who a kaiju picks, where
-- it stands, and whole battles on a court, played out with the real brain
-- and the real moves (KaijuAbilities) on stand-in bodies that walk where
-- they're told. In every battle: no kaiju stands about while there's a foe
-- (one down, it's straight onto the next), all of a side close on the
-- last foe (3 on 1), a shooter stays back and shoots (it never leads the
-- charge), the tank's roar turns the foes on it, an assassin is on their
-- shooter at once, and no one ever leaves the court.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- The clock everything runs on.
local now = 0

-- Modules: shared by name (script.Parent.X), the server's by name too.
local loaded = {}
local env
local function load(name: string)
	if loaded[name] then
		return loaded[name]
	end
	local path = ROOT .. "/src/shared/" .. name .. ".luau"
	if not fs.isFile(path) then
		path = ROOT .. "/src/server/Systems/" .. name .. ".luau"
	end
	loaded[name] = luau.load(fs.readFile(path), { debugName = name, environment = env })()
	return loaded[name]
end
local function named(name)
	return setmetatable({ __name = name }, {
		__index = function(_, key)
			return named(key)
		end,
	})
end
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
env = setmetatable({
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	Enum = roblox.Enum,
	Random = roblox.Random or Random,
	workspace = workspace,
	os = setmetatable({
		clock = function()
			return now
		end,
	}, { __index = os }),
	script = { Parent = named("Parent") },
	game = {
		GetService = function(_, service)
			if service == "ReplicatedStorage" then
				return {
					Shared = named("Shared"),
					FindFirstChild = function()
						return nil
					end,
				}
			end
			return named(service)
		end,
	},
	require = function(target)
		return load(rawget(target, "__name"))
	end,
}, { __index = _G })

local Kaiju = load("Kaiju")
local KaijuRoles = load("KaijuRoles")
local KaijuBattle = load("KaijuBattle")
local KaijuPit = load("KaijuPit")
local KaijuAbilities = load("KaijuAbilities")
local Brain = load("KaijuBattleBrain")

-- The roles and kits ---------------------------------------------------------------------------------------

check(KaijuRoles.of("Carapace") == "Tank", "A Carapace isn't a tank")
check(KaijuRoles.of("Bulwark") == "Warrior", "A Bulwark isn't a warrior")
check(KaijuRoles.of("Razorback") == "Ranged", "A Razorback isn't ranged")
local function wholeKit(kit, owner: string, role: string)
	for _, key in { "Q", "E", "R" } do
		local id = kit[key]
		local move = KaijuRoles.Moves[id]
		check(move and move.Key == key and move.Role == role, owner .. "'s " .. key .. " isn't its own")
		check(
			move.Name and move.Description and move.IconSource and move.From,
			id .. " is missing a name, words, an icon or what it's from"
		)
		check(Kaiju.AbilityPlans[id] == move.Plan, id .. " can't be cast")
		check(Kaiju.moveInfo(id) == move, id .. " isn't found by its id")
	end
end
for _, role in KaijuRoles.Order do
	local spec = KaijuRoles.Roles[role]
	check(spec and spec.Name and spec.Blurb, role .. " has no name or blurb")
	-- (A breaker's and a warden's moves are only ever their own kind's.)
	if KaijuRoles.Kits[role] then
		wholeKit(KaijuRoles.Kits[role], role, role)
	end
end
-- A support's moves by what they're for: Skyjelly mends small and big,
-- wards, and zaps (Static Bolt, beside its kit); Moonmoth's one mend is
-- both, its Antenna Beam its attack.
do
	local sky = KaijuRoles.supportMoves("Skyjelly")
	check(sky.Mend == "K_PulseMend" and sky.BigMend == "K_BloomSurge" and sky.Ward == "K_StaticVeil" and sky.Strike == "K_StaticBolt", "Skyjelly's support moves")
	local moth = KaijuRoles.supportMoves("Moonmoth")
	check(moth.Mend == "K_SilkCocoon" and moth.BigMend == "K_SilkCocoon" and moth.Ward == "K_ScaleStorm" and moth.Strike == "K_AntennaBeam", "Moonmoth's support moves")
	local bolt = KaijuRoles.Moves.K_StaticBolt
	check(bolt and bolt.Key == "Strike" and bolt.Kind == "Skyjelly" and Kaiju.AbilityPlans.K_StaticBolt == bolt.Plan, "Static Bolt can't be cast")
end
-- The roster's kinds: three moves of their own each, in their role, no
-- other kind's; an assassin's E is how it gets in (a leap or a vanish).
do
	local Roster = load("KaijuRoster")
	local owner = {}
	for _, kind in Roster.Order do
		local role = KaijuRoles.of(kind)
		check(role == Roster.Kinds[kind].Role, kind .. " isn't its role")
		local kit = KaijuRoles.kit(kind)
		check(kit == Roster.Kinds[kind].Kit, kind .. " hasn't its own kit")
		wholeKit(kit, kind, role)
		for _, key in { "Q", "E", "R" } do
			local id = kit[key]
			check(owner[id] == nil, id .. " is two kinds' move")
			owner[id] = kind
			check(KaijuRoles.Moves[id].Kind == kind, id .. " doesn't name its kind")
		end
		if role == "Assassin" then
			local shape = KaijuRoles.Moves[kit.E].Plan.Shape
			check(shape == "Leap" or shape == "Vanish", kind .. "'s E doesn't get it in")
		elseif role == "Tank" then
			check(KaijuRoles.Moves[kit.E].Plan.Shape == "Taunt", kind .. "'s E doesn't draw them")
		end
		check(KaijuRoles.Moves[kit.R].When, kind .. "'s R has no moment")
		local woke = KaijuRoles.move(kind, "E", 1)
		local _, early = KaijuRoles.move(kind, "R", 9)
		check(woke == kit.E and not early, kind .. "'s moves don't wake as a kit's do")
	end
	local count = 0
	for _ in owner do
		count += 1
	end
	check(count == 87, "Not 87 moves of their own")
	-- The warden's team moves land on its friends too.
	local team = 0
	for _, key in { "Q", "E", "R" } do
		local plan = KaijuRoles.Moves[KaijuRoles.kit("Moonmoth")[key]].Plan
		if plan.Team then
			team += 1
			check(plan.Shape == "Ward" or plan.Shape == "Mend", "A team move that isn't a ward or a mend")
		end
	end
	check(team >= 2, "The warden doesn't look after its team")
end
local roar = KaijuRoles.move("Carapace", "E", 1)
local _, slamAwake = KaijuRoles.move("Carapace", "Q", 4)
local _, slamWakes = KaijuRoles.move("Carapace", "Q", 5)
local _, fortWakes = KaijuRoles.move("Carapace", "R", 10)
check(roar == "K_TauntingRoar" and not slamAwake and slamWakes and fortWakes, "A kit's moves don't wake at 1, 5 and 10")
check(
	KaijuRoles.mana("Tank", false, 0.1) > KaijuRoles.mana("Ranged", false, 0.1),
	"A tank doesn't fill its mana faster from the hits it takes"
)
check(
	KaijuRoles.mana("Assassin", true, 0) > KaijuRoles.mana("Tank", true, 0),
	"An assassin's blows don't fill it faster"
)

-- Who it picks, and where it stands -----------------------------------------------------------------------

local function unit(role, x, z, health)
	return { Role = role, Pos = Vector3.new(x, 0, z), Health = health or 100, MaxHealth = 100 }
end
local near, far = unit("Warrior", 0, 3), unit("Ranged", 0, 12, 40)
local foes = { near, far }
check(KaijuRoles.target(unit("Warrior", 0, 0), foes, 0) == near, "A warrior doesn't go for the nearest")
check(KaijuRoles.target(unit("Assassin", 0, 0), foes, 0) == far, "An assassin doesn't go for their shooter")
local shooter = unit("Ranged", 0, -10)
check(
	KaijuRoles.target(shooter, { unit("Tank", 0, 3, 90), unit("Warrior", 3, 2, 20) }, 0).Health == 20,
	"A shooter doesn't pick the weakest in range"
)
-- One down: straight onto the next.
local warrior = unit("Warrior", 0, 0)
warrior.Target = near
check(KaijuRoles.target(warrior, { far }, 0) == far, "One down, it doesn't go on to the next")
-- It keeps on its foe unless another's well nearer.
warrior.Target = far
check(KaijuRoles.target(warrior, { near, far }, 0) == near, "It kept on a foe far off with one right by it")
warrior.Target = near
check(KaijuRoles.target(warrior, { near, unit("Tank", 0, 2.5) }, 0) == near, "It swapped foes for one barely nearer")
-- Taunted: its taunter, whoever's nearer.
local tank = unit("Tank", 0, 20)
warrior.TauntBy, warrior.TauntUntil = tank, 5
check(KaijuRoles.target(warrior, { near, tank }, 1) == tank, "Taunted, it didn't go for the tank")
check(KaijuRoles.target(warrior, { near, tank }, 6) ~= tank, "The taunt outlasted its time")
warrior.TauntBy = nil

local bounds = {
	Center = Vector3.zero,
	Axis = Vector3.new(0, 0, 1),
	Right = Vector3.new(1, 0, 0),
	HalfLength = KaijuPit.Court.HalfLength,
	HalfWidth = KaijuPit.Court.HalfWidth,
}
local function inside(point: Vector3, slack: number?): boolean
	local m = (slack or 0) - KaijuRoles.Inset
	return math.abs(point.X) <= bounds.HalfWidth + m + 1e-6 and math.abs(point.Z) <= bounds.HalfLength + m + 1e-6
end
-- A melee one closes to its reach; a shooter holds its ground in range,
-- closes only to range, and backs off one too close.
local melee = unit("Warrior", 0, -8)
local spot, can = KaijuRoles.spot(melee, unit("Tank", 0, 8), { melee }, { unit("Tank", 0, 8) }, bounds)
check(
	not can and (spot - Vector3.new(0, 0, 8)).Magnitude <= KaijuRoles.Roles.Warrior.Reach + 0.01,
	"A warrior doesn't close to its reach"
)
local archer = unit("Ranged", 0, -9)
local mark = unit("Warrior", 0, 3)
spot, can = KaijuRoles.spot(archer, mark, { archer }, { mark }, bounds)
check(can and (spot - archer.Pos).Magnitude < 0.01, "A shooter in range didn't hold its ground and shoot")
local farMark = unit("Warrior", 0, 14)
spot, can = KaijuRoles.spot(archer, farMark, { archer }, { farMark }, bounds)
check(
	not can and math.abs((spot - farMark.Pos).Magnitude - (KaijuRoles.Roles.Ranged.Range - 1)) < 0.01,
	"A shooter closed past its range"
)
local rusher = unit("Assassin", 0, -6)
spot = KaijuRoles.spot(archer, rusher, { archer }, { rusher }, bounds)
check(spot.Z < archer.Pos.Z - 1.5, "A shooter didn't back off one too close")
-- Backed into the rails: along them, never through.
local cornered = unit("Ranged", 0, -bounds.HalfLength + KaijuRoles.Inset)
local chaser = unit("Assassin", 0.5, -bounds.HalfLength + 4)
spot = KaijuRoles.spot(cornered, chaser, { cornered }, { chaser }, bounds)
check(inside(spot) and math.abs(spot.X - cornered.Pos.X) >= 1.5, "A cornered shooter didn't slip along the rails")
-- Nowhere out of bounds.
for x = -30, 30, 6 do
	for z = -30, 30, 6 do
		check(inside(KaijuRoles.clamp(bounds, Vector3.new(x, 0, z))), "Clamped outside the court")
	end
end

-- Whole battles ---------------------------------------------------------------------------------------------

local fxs = {}
Brain.fx = function(kind, ...)
	table.insert(fxs, { kind, ... })
end
KaijuAbilities.fx = function(kind, ...)
	table.insert(fxs, { kind, ... })
end
local queued = {}
KaijuAbilities.after = function(seconds, fn)
	table.insert(queued, { At = now + seconds, Fn = fn })
end
KaijuAbilities.clock = function()
	return now
end
local function runQueued()
	local ready = {}
	for i = #queued, 1, -1 do
		if queued[i].At <= now then
			table.insert(ready, table.remove(queued, i))
		end
	end
	for i = #ready, 1, -1 do
		ready[i].Fn()
	end
end

local field = { Center = Vector3.zero, Axis = Vector3.new(0, 0, 1) }
-- Each one's gem surge (its Gemsoul's E): a Fire one's, drawn from a fixed
-- seed (the same every run), so no kind or place always draws the same.
local gemSeed = 4242
local function body(species, side, cell, level)
	gemSeed = (gemSeed * 16807) % 2147483647
	local gems = Kaiju.Moves.Fire.Ability
	local stats = Kaiju.stats(if Kaiju.Species[species] then species else "Razorback", level or 1, "Common")
	local at = KaijuBattle.cellSpot(field, side, cell)
	local root = { Position = at, Size = Vector3.new(2, 2, 2), Parent = true }
	root.CFrame = CFrame.lookAt(at, at + KaijuBattle.facing(field, side))
	root.FindFirstChild = function()
		return nil
	end
	local pet
	local model = {
		Parent = true,
		attrs = {},
		SetAttribute = function(self, key, value)
			self.attrs[key] = value
		end,
	}
	local humanoid = { Health = stats.Health, MaxHealth = stats.Health, WalkSpeed = 16, AutoRotate = true }
	function humanoid:MoveTo(point)
		self.Going = point
	end
	pet = {
		Name = species .. "-" .. side .. "-" .. cell,
		Side = side,
		Record = { Species = species, Level = level or 1 },
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Element = "Fire",
		GemSurge = gems[gemSeed % #gems + 1],
		Stats = stats,
		StunUntil = 0,
		SlowUntil = 0,
		Slow = 0,
		BlindUntil = 0,
		Dots = {},
		Hits = 0,
		Shots = {},
	}
	return pet
end

-- A battle: each side's bodies at their cells, stepped every 0.15s; they
-- walk where they're told; it runs till one side's down (or Seconds).
local function battle(sideA, sideB, seconds, watch)
	local all = {}
	for _, pet in sideA do
		table.insert(all, pet)
	end
	for _, pet in sideB do
		table.insert(all, pet)
	end
	local function up(list)
		local out = {}
		for _, pet in list do
			if pet.Model.Parent then
				table.insert(out, pet)
			end
		end
		return out
	end
	local host
	host = {
		hurt = function(foe, amount, element, status)
			if not foe.Model.Parent then
				return "Missed"
			end
			local mult = Kaiju.taken(foe.Record.Species, foe.Element, element)
			amount = KaijuAbilities.soak(foe, amount * mult)
			foe.Humanoid.Health -= amount
			foe.Hits += 1
			if status == "Stun" then
				foe.StunUntil = math.max(foe.StunUntil, now + 0.6)
			elseif status == "Slow" then
				foe.Slow, foe.SlowUntil = 0.4, now + 2
			end
			if foe.Humanoid.Health <= 0 then
				foe.Humanoid.Health = 0
				foe.Model.Parent = nil
				foe.DiedAt = now
			end
			return "Hit"
		end,
		caster = function(pet)
			local function theirs()
				return up(if pet.Side == "A" then sideB else sideA)
			end
			return {
				Model = pet.Model,
				Root = pet.Root,
				Size = Kaiju.size(Kaiju.Scale.Pet),
				Element = pet.Element,
				Damage = pet.Stats.Damage * 2,
				DamageOf = function(id)
					return Kaiju.abilityDamage(pet.Stats.Damage, { Tier = "Common", Size = 1 }, id)
				end,
				Body = pet,
				Humanoid = pet.Humanoid,
				Foes = function(center, radius)
					local list = {}
					for _, other in theirs() do
						if (other.Root.Position - center).Magnitude <= radius then
							table.insert(list, { Root = other.Root, Pet = other })
						end
					end
					return list
				end,
				Hit = function(victim, amount, status)
					host.hurt(victim.Pet, amount, pet.Element, status)
				end,
				Alive = function()
					return pet.Model.Parent ~= nil
				end,
				Taunt = function(victim, secs)
					victim.Pet.TauntBy, victim.Pet.TauntUntil = pet, now + secs
				end,
				Rally = function(plan)
					pet.RallyUntil, pet.RallyDamage, pet.RallyHaste = now + plan.Duration, plan.Damage, plan.Haste
				end,
				Pick = function(kind)
					local best, least = nil, math.huge
					for _, other in theirs() do
						if other.Humanoid.Health < least then
							best, least = other, other.Humanoid.Health
						end
					end
					return if best then { Root = best.Root, Pet = best } else nil
				end,
				Leap = function(victim)
					local at = victim.Root.Position
					local away = at - pet.Root.Position
					away = Vector3.new(away.X, 0, away.Z).Unit
					local spot = KaijuRoles.clamp(bounds, at + away * 2.2)
					pet.Root.Position = spot
					pet.Leapt = (pet.Leapt or 0) + 1
					return spot
				end,
				Hop = function(direction, studs)
					local spot = KaijuRoles.clamp(bounds, pet.Root.Position + direction * studs)
					pet.Root.Position = spot
					return spot
				end,
			}
		end,
	}
	local stats = { Idle = {}, LongestIdle = {}, Out = 0, Ticks = 0 }
	for t = 1, math.floor(seconds / 0.15) do
		now += 0.15
		runQueued()
		local liveA, liveB = up(sideA), up(sideB)
		if #liveA == 0 or #liveB == 0 then
			break
		end
		for _, pet in all do
			if pet.Model.Parent then
				local mine = if pet.Side == "A" then liveA else liveB
				local theirs = if pet.Side == "A" then liveB else liveA
				Brain.step(pet, { Foes = theirs, Allies = mine, Bounds = bounds }, now, host)
				-- (They walk where they're told: a step's worth.)
				local going = pet.Humanoid.Going
				if going then
					local from = pet.Root.Position
					local way = Vector3.new(going.X - from.X, 0, going.Z - from.Z)
					local step = math.min(way.Magnitude, pet.Humanoid.WalkSpeed * 0.15)
					if step > 0.01 then
						pet.Root.Position = from + way.Unit * step
					end
				end
				if not inside(pet.Root.Position, 0.05) then
					stats.Out += 1
				end
				-- Standing about: no wind-up, not walking, no blow for a while.
				local brain = pet.Brain
				local busy = brain.Action ~= nil
					or brain.Moving ~= nil
					or now < pet.StunUntil
					or (now - (pet.Model.attrs.ActionStart or -99)) < pet.Stats.Rate + 0.6
				if busy then
					stats.Idle[pet] = 0
				else
					stats.Idle[pet] = (stats.Idle[pet] or 0) + 0.15
					stats.LongestIdle[pet] = math.max(stats.LongestIdle[pet] or 0, stats.Idle[pet])
				end
			end
		end
		stats.Ticks = t
		if watch then
			watch(t, up(sideA), up(sideB))
		end
	end
	return stats, up(sideA), up(sideB)
end

local function longestIdle(stats)
	local most, who = 0, nil
	for pet, seconds in stats.LongestIdle do
		if seconds > most then
			most, who = seconds, pet.Name
		end
	end
	return most, who
end

-- 1. A full team each: tank and warrior in front, a shooter behind.
now = 0
local A = {
	body("Carapace", "A", "FrontLeft"),
	body("Bulwark", "A", "FrontRight"),
	body("Razorback", "A", "BackCentre"),
}
local B = {
	body("Bulwark", "B", "FrontLeft"),
	body("Bulwark", "B", "FrontRight"),
	body("Razorback", "B", "BackCentre"),
}
local shooterA = A[3]
local shotsFrom, close, ticks = {}, 0, 0
local leadAt3 = nil
local stats, leftA, leftB = battle(A, B, 90, function(t, liveA, liveB)
	if shooterA.Model.Parent and #liveB > 0 then
		ticks += 1
		local nearest = math.huge
		for _, foe in liveB do
			nearest = math.min(nearest, (foe.Root.Position - shooterA.Root.Position).Magnitude)
		end
		if nearest < KaijuRoles.Roles.Ranged.Keep - 1 then
			close += 1
		end
		if shooterA.Model.attrs.ActionKind == "Bolt" and shooterA.Model.attrs.ActionStart == now then
			table.insert(shotsFrom, nearest)
		end
	end
	-- (Three seconds in: who's out front? Not the shooter.)
	if t == 20 then
		local z = {}
		for _, pet in liveA do
			z[pet] = pet.Root.Position.Z
		end
		leadAt3 = z
	end
end)
check(#leftA == 0 or #leftB == 0, "A full battle didn't end in 90s")
check(stats.Out == 0, "A kaiju left the court " .. stats.Out .. " times")
local idle, who = longestIdle(stats)
check(idle <= 1.5, "A kaiju stood about for " .. idle .. "s with foes up: " .. tostring(who))
check(#shotsFrom >= 3, "The shooter hardly shot: " .. #shotsFrom)
local farShots = 0
for _, d in shotsFrom do
	if d >= KaijuRoles.Roles.Ranged.Keep then
		farShots += 1
	end
end
check(
	farShots >= #shotsFrom * 0.6,
	"The shooter shot from up close (" .. farShots .. "/" .. #shotsFrom .. " from range)"
)
check(close <= ticks * 0.3, "The shooter spent too long right on a foe: " .. close .. "/" .. ticks)
check(leadAt3 and leadAt3[shooterA], "No reading three seconds in")
check(
	leadAt3[shooterA] < leadAt3[A[1]] and leadAt3[shooterA] < leadAt3[A[2]],
	"The shooter went in ahead of its front line"
)
print(
	string.format(
		"  3v3: over in %.1fs, longest stand %.2fs, shooter %d shots (%d from range)",
		stats.Ticks * 0.15,
		idle,
		#shotsFrom,
		farShots
	)
)

-- 2. One down, the next: three on one close on the last foe, all of them,
-- and each strikes.
now = 0
A = {
	body("Carapace", "A", "FrontLeft", 6),
	body("Bulwark", "A", "FrontRight", 6),
	body("Razorback", "A", "BackCentre", 6),
}
B = {
	body("Bulwark", "B", "FrontCentre", 3),
	body("Carapace", "B", "BackLeft", 3),
	body("Razorback", "B", "BackRight", 3),
}
local lastFoe, onIt = nil, {}
local deaths, retargeted = {}, {}
stats, leftA, leftB = battle(A, B, 90, function(_, liveA, liveB)
	for _, foe in B do
		if foe.DiedAt and not deaths[foe] then
			deaths[foe] = foe.DiedAt
		end
	end
	-- Within a beat of a kill, every one of yours is on a foe still up.
	for foe, at in deaths do
		if now - at >= 0.3 and now - at < 0.45 and #liveB > 0 then
			for _, pet in liveA do
				local target = pet.Brain and pet.Brain.Target
				retargeted[pet] = retargeted[pet] ~= false and target ~= nil and target.Model.Parent ~= nil
			end
		end
	end
	if #liveB == 1 then
		lastFoe = liveB[1]
		for _, pet in liveA do
			if pet.Brain.Target == lastFoe then
				onIt[pet] = true
			end
		end
	end
end)
check(#leftB == 0, "The stronger side didn't win")
check(next(deaths) ~= nil, "No kills to go on from")
for _, pet in A do
	check(retargeted[pet] ~= false, pet.Name .. " stood about after a kill")
end
check(lastFoe ~= nil, "Never down to one foe")
local closing = 0
for _, pet in A do
	if pet.Model.Parent then
		check(onIt[pet], pet.Name .. " didn't go for the last foe (3 on 1)")
		closing += 1
	end
end
check(closing >= 2, "Not enough of the side left on the last foe to show it")
idle, who = longestIdle(stats)
check(idle <= 1.5, "A kaiju stood about for " .. idle .. "s (3 on 1): " .. tostring(who))
check(stats.Out == 0, "A kaiju left the court (3 on 1)")
for _, foe in B do
	check(foe.Hits > 0, foe.Name .. " was never hit")
end
print(string.format("  3v1: over in %.1fs, longest stand %.2fs", stats.Ticks * 0.15, idle))

-- 3. The tank's roar turns their kaiju on it.
now = 0
A = { body("Carapace", "A", "FrontCentre"), body("Razorback", "A", "BackCentre") }
B = { body("Bulwark", "B", "FrontLeft"), body("Bulwark", "B", "FrontRight") }
A[1].Brain = nil
local roared, turned = false, false
battle(A, B, 20, function()
	if not roared and A[1].Model.attrs.KaijuAbilityAt then
		roared = true
	end
	if roared and not turned then
		for _, foe in B do
			if foe.TauntBy == A[1] and foe.Brain and foe.Brain.Target == A[1] then
				turned = true
			end
		end
	end
end)
check(roared, "The tank never roared (its mana never filled)")
check(turned, "The roar didn't turn a foe on the tank")

-- 4. An assassin's on their shooter the moment it starts.
now = 0
A = { body("Bulwark", "A", "FrontCentre"), body("Razorback", "A", "BackLeft") }
B = { body("Carapace", "B", "FrontCentre"), body("Scythe", "B", "BackRight") }
local onShooter = nil
battle(A, B, 3, function()
	local killer, mark = B[2], A[2]
	if not onShooter and killer.Leapt and mark.Model.Parent then
		onShooter = (killer.Root.Position - mark.Root.Position).Magnitude
	end
end)
check(onShooter and onShooter <= 4, "The assassin didn't leap onto their shooter at the start: " .. tostring(onShooter))
check(B[2].Brain.Target == A[2] or not A[2].Model.Parent, "The assassin left their shooter")

-- 5. A shooter backs off one that leaps on it, inside the court, and keeps
-- shooting.
now = 0
A = { body("Razorback", "A", "BackCentre") }
B = { body("Scythe", "B", "BackCentre") }
local gapAfter = 0
stats = battle(A, B, 4, function(t)
	if t == 20 and A[1].Model.Parent and B[2] == nil then
		gapAfter = (A[1].Root.Position - B[1].Root.Position).Magnitude
	end
end)
check(stats.Out == 0, "The shooter backed out of the court")
check(A[1].Hits > 0 and B[1].Hits > 0, "They didn't fight it out")
print(string.format("  shooter vs assassin: a gap of %.1f studs three seconds in", gapAfter))

-- 6. Every kit's move lands (level 10: all three), in battles of each kind.
now = 0
A = {
	body("Carapace", "A", "FrontLeft", 10),
	body("Bulwark", "A", "FrontRight", 10),
	body("Razorback", "A", "BackCentre", 10),
}
B = {
	body("Carapace", "B", "FrontLeft", 10),
	body("Bulwark", "B", "FrontRight", 10),
	body("Scythe", "B", "BackCentre", 10),
}
table.clear(fxs)
local named = {}
battle(A, B, 90, function(_, liveA, liveB)
	for _, pet in liveA do
		named[pet.Model.attrs.ActionName or ""] = true
	end
	for _, pet in liveB do
		named[pet.Model.attrs.ActionName or ""] = true
	end
end)
local seen = 0
for id, move in KaijuRoles.Moves do
	if named[move.Name] then
		seen += 1
	end
end
check(seen >= 8, "Too few of the kits' moves were cast at level 10: " .. seen)
-- And beside them, their gem surges (each one's own cast time, not its E's).
local surged = 0
for _, pet in A do
	if pet.Model.attrs.KaijuGemAt then
		surged += 1
	end
end
for _, pet in B do
	if pet.Model.attrs.KaijuGemAt then
		surged += 1
	end
end
check(surged >= 3, "Too few gem surges were cast at level 10: " .. surged)
print(string.format("  level 10: %d of the kits' 12 moves cast", seen))

-- 7. The balance. The first four: every team of three (kinds may repeat)
-- against every other, in their default places, at levels 1, 5 and 10; no
-- kind's teams win much more or much less than half (KaijuRoles' Power and
-- the kinds' stats, tuned on this). All 32: too many teams for that, so
-- each kind leads its share of seeded random three-on-threes against teams
-- drawn from every fighting kind, and no kind's teams may win far more or far less
-- than half.
do
	local power = KaijuRoles.power
	check(power("Ranged", 1) == 1.4 and power("Ranged", 5) == 1.6 and power("Ranged", 10) == 1.9, "A shooter's power")
	check(math.abs(power("Ranged", 3) - 1.5) < 1e-9 and power("Ranged", 30) == 1.9, "A shooter's power between levels")
	check(
		power("Tank", 10) < power("Warrior", 10) and power("Warrior", 10) < power("Ranged", 10),
		"The roles' power out of order"
	)
	local function squad(team, side, level)
		local records = {}
		for i, species in team do
			table.insert(records, { Id = side .. i, Species = species })
		end
		local places = KaijuBattle.defaultFormation(records)
		local out = {}
		for i, species in team do
			table.insert(out, body(species, side, places[side .. i], level))
		end
		return out
	end
	-- Plays each pairing in `games`; returns each kind's share of wins.
	local function play(games, level)
		local won, played = {}, {}
		for _, game in games do
			local teamA, teamB = game[1], game[2]
			now = 0
			table.clear(queued)
			local sideA, sideB = squad(teamA, "A", level), squad(teamB, "B", level)
			local _, leftA, leftB = battle(sideA, sideB, 90)
			local shareA, shareB = 0, 0
			for _, pet in leftA do
				shareA += pet.Humanoid.Health / pet.Humanoid.MaxHealth
			end
			for _, pet in leftB do
				shareB += pet.Humanoid.Health / pet.Humanoid.MaxHealth
			end
			local aWon = if #leftB == 0
				then 1
				elseif #leftA == 0 then 0
				elseif shareA > shareB then 1
				elseif shareB > shareA then 0
				else 0.5
			for _, species in teamA do
				won[species] = (won[species] or 0) + aWon
				played[species] = (played[species] or 0) + 1
			end
			for _, species in teamB do
				won[species] = (won[species] or 0) + 1 - aWon
				played[species] = (played[species] or 0) + 1
			end
		end
		local share = {}
		for species, n in played do
			share[species] = won[species] / n
		end
		return share
	end

	local kinds = Kaiju.Starters
	local teams = {}
	for a = 1, #kinds do
		for b = a, #kinds do
			for c = b, #kinds do
				table.insert(teams, { kinds[a], kinds[b], kinds[c] })
			end
		end
	end
	local games = {}
	for i, teamA in teams do
		for j, teamB in teams do
			if i ~= j then
				table.insert(games, { teamA, teamB })
			end
		end
	end
	for _, level in { 1, 5, 10 } do
		local share = play(games, level)
		local line = {}
		for _, species in kinds do
			check(
				share[species] > 0.4 and share[species] < 0.6,
				string.format("Level %d: %s's teams win %.0f%%", level, species, share[species] * 100)
			)
			table.insert(line, string.format("%s %.0f%%", species, share[species] * 100))
		end
		print(string.format("  level %d, %d battles: %s", level, #games, table.concat(line, ", ")))
	end

	-- Every fighting kind, sampled (a fixed seed: the same battles every
	-- run). Not the support kinds: they never take a fighting slot (they
	-- come as a fourth, Kaiju.supportId).
	local seed = 20261021
	local function roll(n: number): number
		seed = (seed * 16807) % 2147483647
		return seed % n + 1
	end
	local all = {}
	for _, kind in Kaiju.Order do
		if not Kaiju.isSupport(kind) then
			table.insert(all, kind)
		end
	end
	local LEAD = 24 -- battles each kind leads (half on each side)
	local BAND = { 0.28, 0.72 }
	for _, level in { 1, 5, 10 } do
		local sampled = {}
		for _, lead in all do
			for i = 1, LEAD do
				local mine = { lead, all[roll(#all)], all[roll(#all)] }
				local theirs = { all[roll(#all)], all[roll(#all)], all[roll(#all)] }
				table.insert(sampled, if i % 2 == 0 then { mine, theirs } else { theirs, mine })
			end
		end
		local share = play(sampled, level)
		local line, low, high = {}, 1, 0
		for _, species in all do
			local s = share[species]
			check(
				s > BAND[1] and s < BAND[2],
				string.format("Level %d (all %d): %s's teams win %.0f%%", level, #all, species, s * 100)
			)
			low, high = math.min(low, s), math.max(high, s)
			table.insert(line, string.format("%s %.0f", species, s * 100))
		end
		print(
			string.format(
				"  level %d, every fighter, %d battles (%.0f%% to %.0f%%): %s",
				level,
				#sampled,
				low * 100,
				high * 100,
				table.concat(line, ", ")
			)
		)
	end
end

-- 1V1 + KAIJU's result (KaijuBattle.mixedWinner): a side whose miner is
-- out of the duel and whose kaiju are all down is beaten; while either
-- side can still reach the other it's not over; out of reach, or out of
-- time, the side with more left (its miner and its kaiju, half each).
do
	local function side(up, share, miner, minerShare)
		return { Up = up, Share = share, Miner = miner, MinerShare = minerShare }
	end
	check(KaijuBattle.mode("Mixed") == "Mixed" and KaijuBattle.mode("Chess") == "Kaiju" and KaijuBattle.mode(nil) == "Kaiju", "A mode that isn't one isn't the kaiju alone")
	check(KaijuBattle.mixedWinner(side(2, 0.5, true, 0.4), side(3, 0.9, true, 0.9)) == nil, "Over with everyone still fighting")
	check(KaijuBattle.mixedWinner(side(1, 0.2, true, 1), side(0, 0, false, 0)) == "A", "Out of the duel with its kaiju down isn't beaten")
	check(KaijuBattle.mixedWinner(side(0, 0, false, 0), side(2, 0.4, true, 0.1)) == "B", "The other side beaten isn't a win")
	check(KaijuBattle.mixedWinner(side(0, 0, false, 0), side(0, 0, false, 0)) == "Draw", "Both beaten at once isn't a draw")
	check(KaijuBattle.mixedWinner(side(1, 0.3, true, 1), side(2, 0.8, false, 0)) == nil, "Over with both sides' kaiju still up")
	check(KaijuBattle.mixedWinner(side(0, 0, true, 0.6), side(2, 0.8, false, 0)) == "B", "Out of reach, the side with more left doesn't win")
	check(KaijuBattle.mixedWinner(side(0, 0, true, 1), side(2, 1, false, 0)) == "Draw", "Out of reach and even isn't a draw")
	check(KaijuBattle.mixedWinner(side(2, 0.5, true, 0.4), side(3, 0.9, true, 0.9), true) == "B", "Out of time, the side with more left doesn't win")
	check(KaijuBattle.mixedWinner(side(2, 0.5, true, 0.5), side(2, 0.5, true, 0.5), true) == "Draw", "Out of time and even isn't a draw")
	check(
		math.abs(KaijuBattle.mixedShare(side(1, 0.6, true, 0.4)) - 0.5) < 1e-9
			and math.abs(KaijuBattle.mixedShare(side(1, 0.6, false, 0.9)) - 0.3) < 1e-9,
		"A side's share isn't its miner's and its kaiju's, half each"
	)
end

print(
	"PASS: "
		.. checks
		.. " kaiju role checks (roles and kits, who it picks and where it stands, whole battles: no standing about, onto the next after a kill, 3 on 1, the shooter at the back, the tank's roar, the assassin's leap, inside the court; the roster's own kits; the balance at levels 1, 5 and 10, the first four and every fighting kind; 1V1 + KAIJU's result)"
)
