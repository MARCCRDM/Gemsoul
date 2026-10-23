-- lune run tests/boss_targets_cases.luau <repo>
-- A boss picking who it's on, run on the real Duelist code: raidTarget and
-- foeRoot are cut out of Duelist's source (the rest of it needs the whole
-- server) and driven through a Rift fight with two runners and a kaiju.
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
local function read(path: string): string
	return fs.readFile(ROOT .. "/" .. path)
end

-- The clock the slice reads (os.clock for threat, the server clock for
-- knock-downs), moved by hand.
local now = 100
local env = setmetatable({
	Vector3 = roblox.Vector3,
	os = setmetatable({ clock = function()
		return now
	end }, { __index = os }),
	workspace = { GetServerTimeNow = function()
		return now
	end },
}, { __index = _G })

local Aggro = luau.load(read("src/shared/Aggro.luau"), { debugName = "Aggro", environment = env })()

-- What the slice reaches for: the duels table, the brain's reach, the
-- enemy list, remotes (recorded), and the kaiju system (stubbed: `pets`).
local sent = {}
local removed = {}
local pets = {}
env.duels = {}
env.Aggro = Aggro
env.Brain = { Reach = 6.5 }
env.Enemies = { remove = function(enemy)
	enemy.Alive = false
	table.insert(removed, enemy)
end }
env.Remotes = {
	Notify = { FireClient = function(_, player, text)
		table.insert(sent, { To = player, Text = text })
	end },
	CombatFx = { FireClient = function(_, player, kind, text)
		table.insert(sent, { To = player, Kind = kind, Text = text })
	end },
}
env.KaijuServerStub = {
	all = function()
		return pets
	end,
	targetable = function(pet)
		return pet.Model.Parent ~= nil and pet.Humanoid.Health > 0
	end,
}

local duelist = read("src/server/Systems/Duelist.luau")
local from = assert(string.find(duelist, "local function ownerRoot(owner: Player)", 1, true), "Duelist has no ownerRoot")
local to = assert(string.find(duelist, "-- What the rival is doing, for the player's rival panel", from, true), "Duelist has no setStance")
local slice = string.sub(duelist, from, to - 1):gsub("require%(script%.Parent%.KaijuServer%)", "KaijuServerStub")
local Slice = luau.load(
	slice .. "\nreturn { raidTarget = raidTarget, foeRoot = foeRoot, petsOf = petsOf }\n",
	{ debugName = "DuelistSlice", environment = env }
)()

-- Stand-ins -------------------------------------------------------------------------------------------------
local function attrs(t)
	return {
		GetAttribute = function(_, name)
			return t[name]
		end,
		SetAttribute = function(_, name, value)
			t[name] = value
		end,
	}
end
local function body(x: number, health: number?)
	local root = { Position = roblox.Vector3.new(x, 0, 0) }
	local humanoid = { Health = health or 100, MaxHealth = 100 }
	return {
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function(_, class)
			return if class == "Humanoid" then humanoid else nil
		end,
		Root = root,
		Humanoid = humanoid,
	}
end
local function runner(name: string, id: number, x: number)
	local t = { RiftRun = "R1" }
	local p = attrs(t)
	p.Name, p.DisplayName, p.UserId, p.Parent = name, name, id, true
	p.Character = body(x)
	p.Attrs = t
	return p
end
local function kaiju(owner, id: string, name: string, x: number)
	return {
		Record = { Id = id, Name = name },
		Owner = owner,
		Model = { Parent = true },
		Humanoid = { Health = 300, MaxHealth = 300 },
		Root = { Position = roblox.Vector3.new(x, 0, 0) },
	}
end
local A, B = runner("Ada", 11, 3), runner("Bo", 22, 4)
local pebble = kaiju(A, "k-1", "Pebble", 2)
pets = { pebble }
env.KaijuServerStub.all = function()
	return pets
end

local bossAttrs = {}
local enemy = {
	Alive = true,
	Threat = {},
	ThreatAt = {},
	Aggro = Aggro.new(),
	Root = { Position = roblox.Vector3.new(0, 0, 0) },
	Model = attrs(bossAttrs),
}
local raid = { Id = "R1", Members = { A, B }, All = { A, B }, Wave = 1 }
local duel = { Name = "Frigo Camelo", Owner = A, Enemy = enemy, Raid = raid, Dungeon = { Rift = true } }
env.duels[A], env.duels[B] = duel, duel
local function hurt(by, amount)
	Aggro.add(enemy.Threat, enemy.ThreatAt, by, amount, now)
end
local function lastTo(player)
	for i = #sent, 1, -1 do
		if sent[i].To == player then
			return sent[i].Text
		end
	end
	return nil
end

-- 1. The fight opens on the duel's player.
check(Slice.raidTarget(duel, now), "the fight ended before it began")
check(enemy.Aggro.Target == A and duel.Owner == A and duel.PetTarget == nil, "it didn't open on the duel's player")
check(Slice.foeRoot(duel) == A.Character.Root, "its foe isn't the player it opened on")

-- 2. A kaiju out-damages everyone: the boss turns on the kaiju (a kaiju
-- has threat of its own), its owner stays the duel's player and hears so.
hurt(A, 10)
hurt(pebble, 100)
now += 2 -- (past the hold on a fresh target)
check(Slice.raidTarget(duel, now), "the fight ended on a turn")
check(duel.PetTarget == pebble, "the boss didn't turn on the kaiju hurting it most")
check(duel.Owner == A, "turning on a kaiju changed the duel's player")
check(Slice.foeRoot(duel) == pebble.Root, "its foe isn't the kaiju it's on")
check(string.find(lastTo(A) or "", "turns on Pebble", 1, true) ~= nil, "the owner wasn't told the boss turned on their kaiju: " .. tostring(lastTo(A)))

-- 3. Its turn's up: after RotateAfter the next one hurting it at least
-- half as much takes a turn: the other runner, who becomes the duel's
-- player, marked on the model.
hurt(B, 60)
now += Aggro.RotateAfter + 0.1
check(Slice.raidTarget(duel, now), "the fight ended on the rotation")
check(enemy.Aggro.Target == B and duel.PetTarget == nil, "the other runner didn't get a turn")
check(duel.Owner == B and bossAttrs.RivalOwner == 22, "the duel's player didn't follow the turn")
check(lastTo(B) == "Frigo Camelo turns on you!", "the runner wasn't told it turned on them: " .. tostring(lastTo(B)))
check(Slice.foeRoot(duel) == B.Character.Root, "its foe isn't the runner it turned on")

-- 4. The kaiju is called back (its owner knocked down: KaijuServer.recallTeam):
-- however much it hurt the boss, it's no target while it's away.
pebble.Model.Parent = nil
hurt(pebble, 1000)
now += Aggro.RotateAfter + 0.1
check(Slice.raidTarget(duel, now), "the fight ended on a recall")
check(duel.PetTarget == nil, "a called-back kaiju was targeted")
check(#Slice.petsOf(duel, raid.Members) == 0, "a called-back kaiju counted as out")

-- 5. The runner it's on goes down and the kaiju is redeployed (a revive):
-- a downed runner is no target in the Rift, so it's on the kaiju again.
B.Attrs.SparDown = now + 30
pebble.Model.Parent = true
now += 0.1
check(Slice.raidTarget(duel, now), "the fight ended on a knock-down")
check(duel.PetTarget == pebble and duel.Owner == A, "it didn't leave the downed runner for the kaiju")
check(Slice.foeRoot(duel) == pebble.Root, "its foe isn't the redeployed kaiju")

-- 6. A kaiju knocked out mid-turn: its owner is the foe again.
pebble.Humanoid.Health = 0
check(Slice.foeRoot(duel) == A.Character.Root, "a knocked-out kaiju was still its foe")
now += 0.1
check(Slice.raidTarget(duel, now), "the fight ended on a knock-out")
check(duel.PetTarget == nil and enemy.Aggro.Target == A, "it didn't fall back to the kaiju's owner")
pebble.Humanoid.Health = 300

-- 7. Everyone down: the boss waits (the fight isn't over, nobody's left to hit).
A.Attrs.SparDown = now + 30
now += 0.1
check(not Slice.raidTarget(duel, now) and enemy.Alive, "a boss with everyone down ended the fight")
A.Attrs.SparDown, B.Attrs.SparDown = nil, nil
now += 0.1
check(Slice.raidTarget(duel, now), "the fight didn't resume once they were up")

-- 8. A runner leaves the trip: dropped from the raid, their duel cleared;
-- the last one leaving ends it (the boss removed, no notice to anyone).
B.Attrs.RiftRun = nil
now += 0.1
check(Slice.raidTarget(duel, now), "one runner leaving ended the fight")
check(#raid.Members == 1 and raid.Members[1] == A and env.duels[B] == nil, "the leaver wasn't dropped")
local before = #sent
A.Attrs.RiftRun = nil
check(not Slice.raidTarget(duel, now), "the fight went on with nobody in it")
check(#raid.Members == 0 and not enemy.Alive and removed[1] == enemy, "the boss outlived its trip")
check(#sent == before, "a Rift trip's end was announced like a raid's")

print("PASS: " .. checks .. " boss target checks (the real raidTarget: opening on the player, turning on a kaiju, turns, a recall, a knock-down, a knock-out, everyone down, leaving)")
