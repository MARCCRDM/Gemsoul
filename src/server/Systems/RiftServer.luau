--[[
	The Rift on the server (Shared.RiftRun has the rules; see docs/rift.md):
	a trip through a vein's Rift Gate (OutpostWorld.veinMarks) into the
	critters' own world, built for it (World.RiftWorld: walled caves) and
	gone with it.

	  Going in    "RiftEnter", vein, bossId, together: through a gate you're
	              standing at, or (vein "Bounty", Shared.Bounties) from
	              the bounty board (Brutus's counter, or the PLAY menu's
	              BOUNTY BOARD bar: anywhere in the Outpost), against any boss
	              on any biome's ladder (its element the ladder's). You join your party's trip if one of them is still on
	              the way (up to RiftRun.Party), whatever boss they chose;
	              or start one against `bossId`, from the gate's biome's
	              ladder (RiftRun.Ladders, by the element of the biome the
	              gate stands in: its fighters and boss are of it), if
	              you've beaten the one before it (profile RiftBosses:
	              { [bossId] = times beaten }; RiftRun.canFight). Your party's
	              leader starting one `together` (the gate's lobby) brings
	              every member who's ready (Party's ready check) in with
	              them, from anywhere in the Outpost; the others are told
	              they can follow. A group
	              boss alone is allowed; the gate warns you first. Your combat kit
	              comes out and stays out till you're home
	              (SparServer.riftKit: hunting, so a finishing blow knocks
	              you down rather than kills you); your kaiju come with you
	              (you keep Outpost, so KaijuServer keeps them out).
	  The way     a cave's pack comes up once one of you walks in, every
	              one of it through a tear of its own in the cave's floor
	              (KaijuWilds.rift, Hell: RiftRun.Portal), a moment apart:
	              brainrot critters (KaijuWilds.spawnBug: Stay, Wander) at
	              your kaiju's level and up, then the pathway dungeon's
	              fighters that lead them (Duelist.spawnDungeon, a Rift
	              encounter: anyone in can hit them and be hit, kaiju too;
	              RiftLeader on their models: your lock takes them, your
	              kaiju their critters). Till the last is through it's on
	              its way (run.Coming, counted in RiftLeft), and the cave
	              isn't clear. Every one down, the wall of
	              fire on the way out dies (RiftWorld.openGate) and everyone
	              in finds a cache (Gems.award "RiftCache": the gems you've
	              found in here). Through the floor somehow, back in the
	              last cave you reached (RiftRun.Fall).
	  Falling     knocked out on the way (SparServer's knock-down, or
	              killed outright): the critters rob you (Server.Robbery):
	              you stay down while the cave's critters come for you, and
	              more tear through round you if too few are near; each
	              grabs one of the gems you found in here (RiftRun.robCount
	              at most, out of your pouch) and runs for a tear with it
	              (bonked or knocked out first, it drops it back). Then
	              you're back at base, shown what they took (the "Robbed"
	              report: Client.RobReport). Knocked out at the boss: you
	              stay down (RiftFallen: SparServer leaves you there, your
	              kaiju are called back: KaijuServer.recallTeam) and
	              choose ("RiftChoice"): "Restore" (RiftRun.restoreCost
	              coins: your health and your kaiju's, all of them back:
	              KaijuServer.restoreAll), "Home" (back to base, keeping
	              what you found) or invite a friend (the client's); nothing
	              chosen in RiftRun.Fallen seconds, home you go.
	  The boss    the one picked at the gate, as the pathway
	              dungeon's Colossus (a Duelist fighter with its every move,
	              RiftRun.bossHealth times tougher, by its threat too, its
	              cave's leader): it tears through in the throne cave once
	              one of you sets foot there, and calls critters and a
	              fighter through tears of their own at each of
	              RiftRun.Boss.Adds. Beaten: everyone still in gets
	              RiftRun.rewardCoins, a lucky cache, EXP for their kaiju
	              and swings back on their pick (SwingRestore.Dungeon); the
	              fallen are back up; the way home opens, and everyone in
	              gets a boss cache of their own (ArenaStreaks.bossCache:
	              its gem, Dungeons.bossGem, and six pieces of gear to keep
	              three of, Shared.BossLoot). RiftRun.Exit seconds on,
	              everyone's home.
	  Leaving     "RiftLeave": through a way home you're at (the landing's,
	              or the throne cave's once it's open), keeping what you found.
	  The gate    "RiftPeek", vein: what going in looks like (the gate's
	              card; for "Bounty", the bounty board's, with Ladders: one
	              { Biome, Element, Ladder, Next } for each biome):
	              { Party, Joining, Solo, Biome, Element, Ladder:
	              { { Id, Name, Element, Threat, Level (bossLevel, at
	              your party's kaiju), Group, Loot, Unlocked, Beaten,
	              Need } }, Next (the boss it offers first), Boss (your
	              party's, joining) and Theirs (its card, joining) }.
	  Armor       "RiftGear", bossId, apply: ADJUST ARMOR (the board's
	              GET READY, a Rift invite): your armor set against the
	              boss's element (Shared.CounterGear.versus, worn by
	              Systems/CounterServer: resist gems and armor pieces from
	              your bag, never your sword or your Q, E and R gems), the
	              plan back as CounterGear.summary.
	  Invites     a party invite from the board says which boss
	              (Party.setInviteContext); one from inside a trip says it's
	              on its way (Live). Accepted (Party.onJoined): into the
	              trip now if it's on its way, coming in at the last cave
	              cleared (join), else ready to go in with them; the
	              invite's ADJUST MY ARMOR sets their armor first. Each boss's portrait waits in
	              ReplicatedStorage.RiftPortraits (portraitOf).
	  Healing     each cave and the throne cave have healing crystals
	              (RiftRun.Heal, World.RiftWorld.healRock): "RiftMine", id
	              is a swing of your pick at one (1 swaps your kit for it:
	              SparServer's Hunt): health back, never gems; the swing
	              that breaks it heals more, and your kaiju out
	              (KaijuServer.mend). It grows back a while later.

	A runner carries RiftRun (the trip's id), RiftRoom (the cave they're on
	the way to: 1..Rooms, Rooms + 1 the throne cave), RiftLeft (foes left
	there), RiftBoss (its name), RiftFound (gems found in here), RiftRunners
	(how many in), RiftWon (the boss down) and RiftExitAt (server time
	they're sent home then); knocked out at the boss, RiftFallen (server time
	the choice runs out) and RiftRestore (what RESTORE costs). Nothing of the
	Outpost's comes for them in there (FrontierServer, OutpostServer,
	HealthRegen leave them be), and nothing else starts for them (spars,
	duels, raids, kaiju battles, the Arena, expeditions).

	  RiftServer.start(site)          site: the Outpost's (OutpostServer.site())
	  RiftServer.runOf(player) -> run?
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RiftRun = require(ReplicatedStorage.Shared.RiftRun)
local RiftRealms = require(ReplicatedStorage.Shared.RiftRealms)
local BossLoot = require(ReplicatedStorage.Shared.BossLoot)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
local Spar = require(ReplicatedStorage.Shared.Spar)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local Store = require(ReplicatedStorage.Shared.Store)
local RiftWorld = require(script.Parent.Parent.World.RiftWorld)
local ArenaStreaks = require(script.Parent.ArenaStreaks)
local Duelist = require(script.Parent.Duelist)
local Dungeons = require(script.Parent.Dungeons)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuServer = require(script.Parent.KaijuServer)
local KaijuWilds = require(script.Parent.KaijuWilds)
local Party = require(script.Parent.Party)
local Bounties = require(ReplicatedStorage.Shared.Bounties)
local CounterGear = require(ReplicatedStorage.Shared.CounterGear)
local CounterServer = require(script.Parent.CounterServer)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local Restores = require(script.Parent.Restores)
local Robbery = require(script.Parent.Robbery)
local Shop = require(script.Parent.Shop)
local SparServer = require(script.Parent.SparServer)

local RiftServer = {}

-- Where the trips are built: far off in the dark, each its own slot.
RiftServer.Origin = Vector3.new(-9000, 300, -9000)
RiftServer.SlotGap = 2000
-- How close to a gate (or a way home) you must be to go through it.
RiftServer.Reach = 24

local reply = Shop.reply
local site = nil
local runs = {}
local runOf: { [Player]: any } = {}
local slots: { [number]: any } = {}
local nextId = 0

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function notify(player: Player, text: string)
	if player.Parent then
		Remotes.Notify:FireClient(player, text)
	end
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

local function announce(run, text: string)
	for _, player in run.Members do
		notify(player, text)
	end
end

-- Every runner's attributes, as the trip stands.
local function show(run)
	local left = run.Coming -- (those still on their way through)
	for _ in run.Foes do
		left += 1
	end
	for _, player in run.Members do
		player:SetAttribute("RiftRoom", run.Room)
		player:SetAttribute("RiftLeft", left)
		player:SetAttribute("RiftRunners", #run.Members)
		player:SetAttribute("RiftBoss", if run.Room > RiftRun.Rooms then run.Boss.Name else nil)
		player:SetAttribute("RiftBossLevel", if run.Room > RiftRun.Rooms then run.BossLevel else nil)
		player:SetAttribute("RiftFound", #(run.Found[player] or {}))
		player:SetAttribute("RiftWon", run.Won or nil)
		player:SetAttribute("RiftExitAt", run.ExitServer)
	end
end

local CLEAR = {
	"RiftRun",
	"RiftRealm",
	"RiftRoom",
	"RiftLeft",
	"RiftBoss",
	"RiftBossLevel",
	"RiftFound",
	"RiftRunners",
	"RiftWon",
	"RiftExitAt",
	"RiftFallen",
	"RiftRestore",
}

-- The trip's over: what's left of it goes.
local function finish(run)
	if run.Done then
		return
	end
	run.Done = true
	runs[run.Id] = nil
	slots[run.Slot] = nil
	for enemy in run.Foes do
		if enemy.Alive then
			Enemies.remove(enemy)
		end
	end
	table.clear(run.Foes)
	Duelist.removeDungeon(run.Id)
	if run.BossEnemy and run.BossEnemy.Alive then
		Enemies.remove(run.BossEnemy)
	end
	for _, player in run.Members do
		if runOf[player] == run then
			runOf[player] = nil
		end
	end
	run.World.Folder:Destroy()
end

-- Back on your feet, whole, a moment's grace (SparServer's getUp, for one
-- the Rift kept down).
local function standUp(player: Player)
	player:SetAttribute("RiftFallen", nil)
	player:SetAttribute("RiftRestore", nil)
	player:SetAttribute("SparDown", nil)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
		local guard = Instance.new("ForceField")
		guard.Name = "SparGuard"
		guard.Visible = false
		guard.Parent = player.Character
		Debris:AddItem(guard, Spar.GuardSeconds)
	end
end

-- Out of the trip and back at base (the Outpost's spawn), whole.
local function home(player: Player, text: string?)
	local run = runOf[player]
	runOf[player] = nil
	for _, key in CLEAR do
		player:SetAttribute(key, nil)
	end
	if run then
		local i = table.find(run.Members, player)
		if i then
			table.remove(run.Members, i)
		end
		run.Fallen[player], run.Handled[player] = nil, nil
	end
	if player.Parent then
		SparServer.riftKit(player, false)
		player:SetAttribute("SparDown", nil)
		local humanoid = humanoidOf(player)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
			if site and player.Character then
				player.Character:PivotTo(site.Spawn)
				local root = rootOf(player)
				if root then
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
		if text then
			notify(player, text)
		end
	end
	if run then
		if #run.Members == 0 then
			finish(run)
		else
			show(run)
		end
	end
end

-- The lead kaiju's level of each of `players`.
local function leadLevels(players: { Player }): { number }
	local levels = {}
	for _, player in players do
		local profile = PlayerData.get(player)
		local lead = profile and Kaiju.active(profile.Kaiju)
		if lead then
			table.insert(levels, lead.Level)
		end
	end
	return levels
end

-- ... of everyone in.
local function levelsOf(run): { number }
	return leadLevels(run.Members)
end

-- The bosses' portraits for the gate's cards (Client.RiftClient): each
-- one's body (Duelist.creatureBody) built once, anchored, and kept in
-- ReplicatedStorage.RiftPortraits by its id.
local function portraitOf(boss)
	local folder = ReplicatedStorage:FindFirstChild("RiftPortraits")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RiftPortraits"
		folder.Parent = ReplicatedStorage
	end
	if folder:FindFirstChild(boss.Id) then
		return
	end
	local ok, body = pcall(Duelist.creatureBody, boss, GemConfig.ElementColors[boss.Element])
	if not ok or not body then
		warn("[Rift] no portrait for", boss.Id, body)
		return
	end
	for _, piece in body:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
		elseif piece:IsA("Humanoid") then
			piece:Destroy()
		end
	end
	body.Name = boss.Id
	body.Parent = folder
end

local foeDied, victory

-- A spot on cave `area`'s floor (a share of its radius out from the middle).
local function spotOn(run, center: Vector3, radius: number, share: number): Vector3
	local a = run.Rng:NextNumber(0, math.pi * 2)
	local r = radius * share * math.sqrt(run.Rng:NextNumber(0.15, 1))
	return center + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
end

-- One of the trip's critters: it stays in its cave, roaming it till
-- someone comes, and its death counts.
local function spawnFoe(run, at: Vector3, opts)
	opts.Stay = true
	opts.Wander = opts.Wander or { Home = at, Roam = 9, Notice = 26 }
	opts.Facing = opts.Facing or run.World.Start.Position
	opts.Hell = true
	-- (Off through a tear with someone's gem: gone from the cave's pack.)
	opts.OnGone = function(e)
		foeDied(run, e)
	end
	local enemy = KaijuWilds.spawnBug(at, opts)
	if not enemy then
		return nil
	end
	enemy.Model:SetAttribute("RiftRun", run.Id)
	local died = enemy.OnDeath
	enemy.OnDeath = function(e)
		if died then
			died(e)
		end
		foeDied(run, e)
	end
	run.Foes[enemy] = true
	return enemy
end

-- One of the pathway dungeon's fighters (Duelist: armed and armoured to
-- `tier`, its every move), in the trip's: whoever's in it can hit it and be
-- hit by it, kaiju too. `boss`: the Colossus.
local function spawnFighter(run, at: Vector3, spec, tier: number, boss: boolean?, scale: number)
	local members = {}
	for _, player in run.Members do
		if player.Parent and player.Character and not run.Fallen[player] then
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return nil
	end
	local enemy = Duelist.spawnDungeon(members, run.Id, {
		Rift = true,
		Room = math.min(run.Room, RiftRun.Rooms + 1),
		GearTier = tier,
		Center = at,
		Spot = at + Vector3.new(0, if boss then 7 else 4, 0),
		Spec = spec,
		Boss = boss == true,
		MinPlayers = 1,
		HealthScale = scale,
		OnDeath = function(e)
			foeDied(run, e)
		end,
	})
	if not enemy then
		return nil
	end
	-- (A pack's leader: the runners' lock goes for it first, their kaiju
	-- for its critters: Client.TargetLock, KaijuServer.)
	enemy.Model:SetAttribute("RiftLeader", true)
	if not boss then
		run.Foes[enemy] = true
	end
	return enemy
end

-- Where the runners stand (those up and about), to keep the tears off them
-- and turn what comes through toward them.
local function runnersAt(run): { Vector3 }
	local list = {}
	for _, player in run.Members do
		local root = rootOf(player)
		if root and not run.Fallen[player] then
			table.insert(list, root.Position)
		end
	end
	return list
end

-- The runner nearest `at` (where to face, and leap at), or `fallback`.
local function nearestRunner(run, at: Vector3, fallback: Vector3): Vector3
	local best, bestDistance = fallback, math.huge
	for _, position in runnersAt(run) do
		local distance = (position - at).Magnitude
		if distance < bestDistance then
			best, bestDistance = position, distance
		end
	end
	return best
end

-- When a tear opened by KaijuWilds.rift lets its critter through (now, if
-- none opened).
local function hopIn(life): number
	return if life then math.max(0, life.HopAt - serverNow()) else 0
end

local checkClear
local spawnHeals -- (below, with the healing crystals)
local welcome -- (below, after going in)

-- One foe through a tear of its own at `at`: the tear opens `after` seconds
-- from now (`height` tall; the Outpost's size when nil) in the critters'
-- world's colours, and out it comes, `arrive(facing)`, toward the nearest
-- runner. It counts as on its way (run.Coming) until it's through.
local function through(run, at: Vector3, after: number, height: number?, arrive: (Vector3) -> ())
	run.Coming += 1
	task.delay(after, function()
		if run.Done or run.Won then
			run.Coming -= 1
			return
		end
		local life =
			KaijuWilds.rift(at, nearestRunner(run, at, run.World.Start.Position), { Hell = true, Height = height })
		task.delay(hopIn(life), function()
			run.Coming -= 1
			if not run.Done and not run.Won then
				arrive(nearestRunner(run, at, run.World.Start.Position))
			end
			show(run)
			checkClear(run)
		end)
	end)
end

-- A critter's leap out of its tear, at the runner it faces.
local function leap(at: Vector3, facing: Vector3): Vector3
	local toward = Vector3.new(facing.X - at.X, 0, facing.Z - at.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	return toward * RiftRun.Portal.Hop + Vector3.new(0, 24, 0)
end

-- Cave `room`'s pack comes up through the cave's floor, a tear at a time
-- (RiftRun.Portal): its critters first, then the pathway dungeon's fighters
-- that lead them.
local function spawnRoom(run, room: number)
	if run.Spawned[room] then
		return
	end
	run.Spawned[room] = true
	local cave = run.World.Rooms[room]
	local level = RiftRun.level(levelsOf(run), room, run.Boss)
	local band = if room >= 3 then "Edge" else "Fringe"
	local foes = RiftRun.pickFoes(room, #run.Members, run.Rng, run.Boss)
	local leaders = RiftRun.pickFighters(room, #run.Members, run.Rng, run.Element, run.Boss)
	local spots = RiftRun.portalSpots(cave.Center, cave.Radius, #foes + #leaders, runnersAt(run), run.Rng)
	local every = RiftRun.Portal.Every
	for i, foe in foes do
		local at = spots[i] + Vector3.new(0, 0.5, 0)
		local spec = nil
		for _, entry in DungeonRules.Roster do
			if entry.Id == foe.Critter then
				spec = entry
			end
		end
		local elite = RiftRun.Elite
		through(run, at, (i - 1) * every, nil, function(facing)
			spawnFoe(run, at, {
				Critter = foe.Critter,
				Level = level,
				Band = band,
				Facing = facing,
				Hop = leap(at, facing),
				Scale = if foe.Elite then elite.Scale else nil,
				Health = if foe.Elite then elite.Health else nil,
				Damage = if foe.Elite then elite.Damage else nil,
				Reach = if foe.Elite then elite.Reach else nil,
				Title = if foe.Elite and spec
					then string.format("Rift Brute · %s · Lv %d", spec.Name, level)
					else nil,
			})
		end)
	end
	for j, spec in leaders do
		local at = spots[#foes + j] + Vector3.new(0, 0.5, 0)
		through(run, at, (#foes + j - 1) * every, RiftRun.Portal.Leader, function()
			spawnFighter(run, at, spec, RiftRun.fighterTier(room, run.Boss), false, RiftRun.Fighters.Health)
		end)
	end
	show(run)
end

-- The boss tears through in the throne cave: the tear opens, then out it
-- comes, the pathway dungeon's Colossus (RiftRun.Boss: tougher yet).
local function summonBoss(run)
	if run.Summoning or run.BossEnemy or run.Won then
		return
	end
	run.Summoning = true
	local arena = run.World.Boss
	local at = arena.Center + Vector3.new(0, 0.5, 0)
	announce(run, string.format("The ground splits open. %s is coming through!", run.Boss.Name))
	-- (Its element, again, as it comes: what it's weak to, what it punishes.)
	local tips = DungeonRules.elementTips(run.Boss)
	announce(run, tips.Lines[3])
	announce(run, tips.Lines[4])
	local life = KaijuWilds.rift(
		at,
		nearestRunner(run, at, run.World.Start.Position),
		{ Hell = true, Height = RiftRun.Portal.Boss }
	)
	task.delay(hopIn(life), function()
		if run.Done or run.Won then
			return
		end
		run.BossTier = RiftRun.bossTier(#run.Members, run.Rng)
		local boss = spawnFighter(run, at, run.Boss, run.BossTier, true, RiftRun.bossHealth(#run.Members, run.Boss))
		if not boss then
			-- (It couldn't come through: rather than a trip stuck for good, it's won.)
			warn("[Rift] the boss couldn't come through")
			victory(run)
			return
		end
		boss.Model:SetAttribute("RiftBoss", true)
		run.BossEnemy = boss
		fx("CritterGiggle", at + Vector3.new(0, 6, 0), "Cackle")
		show(run)
	end)
end

-- Some of its critters through tears round the boss, then its fighters
-- (its Adds), a tear at a time.
local function callAdds(run)
	local boss = run.BossEnemy
	if not boss or not boss.Alive then
		return
	end
	local rule = RiftRun.Boss
	local level = run.BossLevel or RiftRun.bossLevel(levelsOf(run), run.Boss)
	local arena = run.World.Boss
	local wave = Kaiju.wave(rule.AddCount, run.Rng)
	local fighters = RiftRun.pickFighters(RiftRun.Rooms, 1, run.Rng, run.Element, run.Boss)
	local spots = RiftRun.portalSpots(arena.Center, arena.Radius, #wave + rule.AddFighters, runnersAt(run), run.Rng)
	local every = RiftRun.Portal.Every
	for i, id in wave do
		local at = spots[i] + Vector3.new(0, 0.5, 0)
		through(run, at, (i - 1) * every, nil, function(facing)
			spawnFoe(run, at, {
				Critter = id,
				Level = level,
				Band = "Edge",
				Facing = facing,
				Hop = leap(at, facing),
				Wander = { Home = at, Roam = 14, Notice = 60 },
			})
		end)
	end
	for j = 1, rule.AddFighters do
		local at = spots[#wave + j] + Vector3.new(0, 0.5, 0)
		through(run, at, (#wave + j - 1) * every, RiftRun.Portal.Leader, function()
			spawnFighter(run, at, fighters[1], rule.AddTier, false, RiftRun.Fighters.Health)
		end)
	end
	announce(run, string.format("%s calls its critters through!", run.Boss.Name))
	show(run)
end

-- Every runner still in finds a cache: a gem out of the cave, luckier
-- further in.
local function caches(run, luck: number)
	for _, player in run.Members do
		if not run.Fallen[player] then
			local gem = Gems.award(player, "RiftCache", { Luck = luck })
			if gem then
				run.Found[player] = run.Found[player] or {}
				table.insert(run.Found[player], gem.Id)
			end
		end
	end
end

-- Cave `room` is clear: its fire dies down, a cache each, and the next
-- cave's pack waits for whoever walks in.
local function cleared(run, room: number)
	RiftWorld.openGate(run.World.Gates[room])
	caches(run, RiftRun.cacheLuck(room))
	run.Room = room + 1
	if room < RiftRun.Rooms then
		announce(run, "Cave cleared. The fire's down: on to the next.")
	else
		-- (The boss's level, for its adds and the strip: whoever's in now.)
		run.BossLevel = RiftRun.bossLevel(levelsOf(run), run.Boss)
		announce(run, "The last cave's clear. Something waits on the throne.")
	end
	show(run)
end

-- The boss's loot: everyone still in gets a boss cache of their own
-- (Systems/ArenaStreaks.bossCache, Shared.BossLoot): its gem (Dungeons.
-- bossGem, as the pathway dungeon's) and six pieces of gear to keep three
-- of, opened whenever they like.
local function bossLoot(run)
	for _, player in run.Members do
		ArenaStreaks.bossCache(player, run.Boss, Dungeons.bossGem(run.Boss.Element, run.BossTier or 4), "Rift")
	end
end

-- The bosses `player` has beaten in the Rift: { [bossId] = times }.
local function beatenBy(player: Player): { [string]: number }
	local profile = PlayerData.get(player) :: any
	if not profile then
		return {}
	end
	profile.RiftBosses = profile.RiftBosses or {}
	return profile.RiftBosses
end

-- The boss beaten: a tally for each one still in, and word of the next
-- boss on its ladder when this opens it for them.
local function recordWin(run)
	local ladder = RiftRun.ladder(run.Element)
	local nextUp = nil
	for i, boss in ladder do
		if boss == run.Boss then
			nextUp = ladder[i + 1]
		end
	end
	for _, player in run.Members do
		local beaten = beatenBy(player)
		local first = (beaten[run.Boss.Id] or 0) == 0
		beaten[run.Boss.Id] = (beaten[run.Boss.Id] or 0) + 1
		if first and nextUp then
			notify(player, string.format("Unlocked: %s, next on this Rift's ladder.", nextUp.Name))
		end
	end
end

-- The boss is down: the trip's won. Its loot's in everyone's caches, and
-- the way home opens (and takes everyone RiftRun.Exit seconds on).
victory = function(run)
	if run.Won then
		return
	end
	run.Won = true
	for enemy in run.Foes do
		if enemy.Alive then
			Enemies.remove(enemy)
		end
	end
	table.clear(run.Foes)
	Duelist.removeDungeon(run.Id)
	local coins = RiftRun.rewardCoins(RiftRun.Rooms)
	caches(run, RiftRun.Reward.Luck)
	-- XP for you by the boss's level against yours: a higher boss, more
	-- (Shared.Levelling); EXP for your kaiju as before.
	local bossLevel = run.BossLevel or RiftRun.bossLevel(levelsOf(run), run.Boss)
	for _, player in run.Members do
		if run.Fallen[player] then
			run.Fallen[player] = nil
			standUp(player)
		end
		PlayerData.addCoins(player, coins)
		KaijuServer.reward(player, RiftRun.Reward.Exp)
		local xp = Progress.won(player, "RiftBoss", bossLevel, "SlayBrute")
		local swings = Restores.give(player, SwingRestore.Dungeon)
		pcall(PlayerData.training, player, "Boss")
		notify(
			player,
			string.format("%s is beaten! +%d coins, +%d XP", run.Boss.Name, coins, xp)
				.. (if swings > 0 then string.format(", +%d swings", swings) else "")
				.. ". The way home is open."
		)
	end
	RiftWorld.openHome(run.World)
	bossLoot(run)
	recordWin(run)
	run.ExitAt = os.clock() + RiftRun.Exit
	run.ExitServer = serverNow() + RiftRun.Exit
	show(run)
end

foeDied = function(run, enemy)
	if run.Done then
		return
	end
	if enemy == run.BossEnemy then
		victory(run)
		return
	end
	if not run.Foes[enemy] then
		return
	end
	run.Foes[enemy] = nil
	show(run)
	checkClear(run)
end

-- The cave's whole pack is through and down: it's clear.
checkClear = function(run)
	if
		not run.Done
		and run.Room <= RiftRun.Rooms
		and run.Spawned[run.Room]
		and run.Coming == 0
		and next(run.Foes) == nil
	then
		cleared(run, run.Room)
	end
end

-- Robbed while down ------------------------------------------------------------------------------------

-- The cave `position` is in (the landing, one on the way, or the throne
-- cave), or the nearest.
local function areaAt(run, position: Vector3)
	local world = run.World
	local best, bestDistance = world.Landing, math.huge
	local areas = { world.Landing, world.Boss }
	for _, cave in world.Rooms do
		table.insert(areas, cave)
	end
	for _, area in areas do
		local offset = position - area.Center
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance < bestDistance then
			best, bestDistance = area, distance
		end
	end
	return best
end

-- `spot` brought onto `area`'s floor, `margin` studs in from its walls.
local function onFloor(area, spot: Vector3, margin: number): Vector3
	local half = area.Size / 2 - margin
	local c = area.Center
	return Vector3.new(
		math.clamp(spot.X, c.X - half, c.X + half),
		c.Y + 0.5,
		math.clamp(spot.Z, c.Z - half, c.Z + half)
	)
end

-- The gems `player` found in here still loose in their pouch, newest last.
local function looseFound(run, player: Player): { string }
	local profile = PlayerData.get(player)
	local loose = {}
	for _, gem in (profile and GemInventory.available(profile)) or {} do
		loose[gem.Id] = true
	end
	local list = {}
	for _, id in run.Found[player] or {} do
		if loose[id] then
			table.insert(list, id)
		end
	end
	return list
end

-- A robber's grab: the newest gem `player` found in here, out of their pouch.
local function riftSteal(run, player: Player)
	local found = run.Found[player]
	local ids = looseFound(run, player)
	local id = ids[#ids]
	local gem = id and PlayerData.removeGem(player, id)
	if not gem or not found then
		return nil
	end
	local i = table.find(found, id)
	if i then
		table.remove(found, i)
	end
	show(run)
	notify(player, string.format("A critter grabbed your %s!", GemConfig.displayName(gem)))
	return gem
end

-- A robber bonked or knocked out first: the gem's back in their pouch (and
-- among what they found, still in here).
local function riftRecover(run, player: Player?, gem, at: Vector3)
	if not player or not player.Parent or type(gem) ~= "table" then
		return
	end
	PlayerData.returnGem(player, gem)
	if runOf[player] == run and run.Found[player] then
		table.insert(run.Found[player], gem.Id)
		show(run)
	end
	local root = rootOf(player)
	fx(
		"GemRecovered",
		at,
		if root then root.Position else at,
		GemConfig.ElementColors[gem.Element] or GemConfig.TierColors[gem.Tier],
		{ Id = gem.Id, Element = gem.Element, Tier = gem.Tier, Size = gem.Size, Clarity = gem.Clarity, Cut = gem.Cut }
	)
	notify(player, string.format("Recovered. Your %s is back in your pouch.", GemConfig.displayName(gem)))
end

-- Robbers through for `player` (`count`, to `robbery`): tears of the Rift's
-- own round them, on their cave's floor, a moment apart.
local function riftRobbers(run, player: Player, count: number, robbery)
	local root = rootOf(player)
	if not root then
		return
	end
	local here = root.Position
	local area = areaAt(run, here)
	local level = RiftRun.level(levelsOf(run), math.clamp(run.Room, 1, RiftRun.Rooms), run.Boss)
	local band = if run.Room >= 3 then "Edge" else "Fringe"
	for i, spot in Frontier.robSpots(here, count, run.Rng) do
		local at = onFloor(area, spot, 6)
		task.delay((i - 1) * Frontier.Rob.Every, function()
			if robbery.Over or run.Done or runOf[player] ~= run then
				return
			end
			local life = KaijuWilds.rift(at, here, { Hell = true })
			task.delay(hopIn(life), function()
				if robbery.Over or run.Done or runOf[player] ~= run then
					return -- (it's over: the tear seals empty)
				end
				local target = rootOf(player)
				local facing = if target then target.Position else here
				local enemy = KaijuWilds.spawnBug(at, {
					Prey = player,
					Critter = KaijuWilds.pickCritter(run.Rng),
					Level = level,
					Band = band,
					Facing = facing,
					Hop = leap(at, facing),
					Robbery = robbery,
					Hell = true,
				})
				if enemy then
					enemy.Model:SetAttribute("RiftRun", run.Id)
				end
			end)
		end)
	end
end

-- Knocked out on the path: robbed (Server.Robbery). The cave's critters come
-- for you, and more through tears of their own if too few are near; each
-- grabs one of the gems you found in here (RiftRun.robCount of them at
-- most) and runs for a tear. Then you're back at base, shown what they took.
local function robbed(run, player: Player)
	run.Handled[player] = true
	local found = run.Found[player] or {}
	local count = RiftRun.robCount(#found)
	local humanoid, root = humanoidOf(player), rootOf(player)
	if not humanoid or humanoid.Health <= 0 or not root then
		-- (Killed outright, nobody there to rob: they take it all the same.)
		local items = {}
		for _ = 1, count do
			local gem = riftSteal(run, player)
			if not gem then
				break
			end
			table.insert(items, Robbery.summary(gem))
		end
		task.delay(2.5, function()
			if runOf[player] == run then
				home(player, nil)
				Remotes.CombatFx:FireClient(player, "Robbed", { Where = "Rift", Items = items, Empty = #items == 0 })
			end
		end)
		return
	end
	fx("CritterGiggle", root.Position + Vector3.new(0, 3, 0), "Cackle")
	notify(player, "You're down... the critters are coming for what you found!")
	Robbery.start(player, {
		Where = "Rift",
		Max = count,
		Takeable = math.min(count, #looseFound(run, player)),
		Steal = function(who)
			return riftSteal(run, who)
		end,
		Recover = function(who, gem, at)
			riftRecover(run, who, gem, at)
		end,
		-- (Off with it to a tear on the same cave's floor.)
		Away = function(from: Vector3, at: Vector3)
			local away = Vector3.new(from.X - at.X, 0, from.Z - at.Z)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
			local carry = Frontier.Raid.Carry.Away
			return onFloor(areaAt(run, from), from + away * run.Rng:NextNumber(carry[1], carry[2]), 6)
		end,
		Spawn = function(more, robbery)
			riftRobbers(run, player, more, robbery)
		end,
		Done = function(who)
			if runOf[who] == run then
				home(who, nil)
			end
		end,
	})
end

-- Knocked out at the boss: down until they choose (or the time runs out).
-- Their kaiju are called back meanwhile (KaijuServer.recallTeam): they
-- come out again with them, restored or with backup come through.
local function fallAtBoss(run, player: Player)
	run.Handled[player] = true
	local deadline = serverNow() + RiftRun.Fallen
	run.Fallen[player] = deadline
	player:SetAttribute("RiftFallen", deadline)
	player:SetAttribute("RiftRestore", RiftRun.restoreCost(run.Restores[player] or 0))
	player:SetAttribute("SparDown", deadline + 1)
	if KaijuServer.recallTeam(player) then
		notify(player, "Your kaiju are called back while you're down.")
	end
end

-- Back on their feet at the boss, whole, their kaiju restored and out
-- again beside them.
local function revive(run, player: Player, text: string)
	run.Fallen[player], run.Handled[player] = nil, nil
	standUp(player)
	KaijuServer.restoreAll(player)
	KaijuServer.deployTeam(player)
	local root = rootOf(player)
	if root then
		fx("Deploy", root.Position, 6, nil, root.Position)
	end
	notify(player, text)
	show(run)
end

-- Where `player` is on the way: the last cave they've reached (0 the
-- landing, Rooms + 1 the throne cave).
local function checkpoint(run, player: Player, root: BasePart)
	local world = run.World
	local reached = run.Reached[player] or 0
	for i, cave in world.Rooms do
		if i > reached and RiftWorld.inside(cave, root.Position, 2) then
			reached = i
		end
	end
	if RiftWorld.inside(world.Boss, root.Position, 2) then
		reached = RiftRun.Rooms + 1
	end
	run.Reached[player] = reached
	return reached
end

local function step(now: number)
	for _, run in runs do
		if run.Done then
			continue
		end
		local floor = run.World.Origin.Position.Y
		for i = #run.Members, 1, -1 do
			local player = run.Members[i]
			if not player.Parent or player:GetAttribute("RiftRun") ~= run.Id then
				runOf[player] = nil
				table.remove(run.Members, i)
				continue
			end
			local root, humanoid = rootOf(player), humanoidOf(player)
			if not root or not humanoid then
				continue
			end
			local reached = checkpoint(run, player, root)
			if run.Fallen[player] then
				if serverNow() >= run.Fallen[player] then
					home(player, "Back at base, with what you found.")
				end
				continue
			end
			if run.Handled[player] then
				continue
			end
			if humanoid.Health <= 0 or Spar.isDown(player) then
				if run.Room > RiftRun.Rooms and not run.Won and humanoid.Health > 0 then
					fallAtBoss(run, player)
				else
					robbed(run, player)
				end
				continue
			end
			-- (Walled in, nobody falls; through the floor somehow, back in the
			-- last cave reached.)
			if root.Position.Y < floor - RiftRun.Fall.Below then
				local back = if reached > RiftRun.Rooms
					then run.World.Boss.Center
					elseif reached > 0 then run.World.Rooms[reached].Center
					else run.World.Start.Position
				player.Character:PivotTo(CFrame.new(back + Vector3.new(0, 4, 0)))
				root.AssemblyLinearVelocity = Vector3.zero
			end
			-- A cave's pack comes up once someone walks into it.
			if run.Room <= RiftRun.Rooms and reached >= run.Room then
				spawnRoom(run, run.Room)
			end
			if reached > RiftRun.Rooms and run.Room > RiftRun.Rooms then
				summonBoss(run)
			end
		end
		if #run.Members == 0 then
			finish(run)
			continue
		end
		local boss = run.BossEnemy
		if boss and boss.Alive and not run.Won then
			local share = boss.Humanoid.Health / math.max(1, boss.Humanoid.MaxHealth)
			local due = RiftRun.addsDue(share, run.Adds)
			if due then
				run.Adds[due] = true
				callAdds(run)
			end
		end
		if run.Won and run.ExitAt and now >= run.ExitAt then
			for _, player in table.clone(run.Members) do
				home(player, "Back at base. Well fought.")
			end
		end
	end
end

-- Joins `run`: on its landing, or (once a cave's cleared) in the last cave
-- cleared, facing the way on, so one who joins a trip on its way comes in
-- where the party's got to; the attributes, and word of how many are in.
local function join(run, player: Player)
	table.insert(run.Members, player)
	runOf[player] = run
	run.Found[player] = run.Found[player] or {}
	local cleared = math.clamp(run.Room - 1, 0, RiftRun.Rooms)
	run.Reached[player] = cleared
	player:SetAttribute("RiftRun", run.Id)
	player:SetAttribute("RiftRealm", run.World.Folder:GetAttribute("Realm"))
	local spot = run.World.Start * CFrame.new((#run.Members - 1) * 3 - 4.5, 0, 0)
	if cleared > 0 then
		local here = run.World.Rooms[cleared].Center + Vector3.new((#run.Members - 1) * 3 - 4.5, 3, 0)
		local onward = if cleared < RiftRun.Rooms then run.World.Rooms[cleared + 1].Center else run.World.Boss.Center
		spot = CFrame.lookAt(here, Vector3.new(onward.X, here.Y, onward.Z))
	end
	player.Character:PivotTo(spot)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- (In there you fight: your combat kit comes out, till you swap it for
	-- your pick for the healing crystals.)
	SparServer.riftKit(player, true)
	notify(player, "Green crystals by the cave walls heal you: swap to your pick (1, or the kit button) and mine them.")
	show(run)
	if cleared > 0 then
		notify(player, string.format("In at cave %d: your party's cleared the way this far.", cleared))
	end
	for _, other in run.Members do
		if other ~= player then
			notify(other, player.DisplayName .. " came through the gate.")
		end
	end
	-- Backup: anyone of the trip down at the boss is back on their feet
	-- for it, kaiju and all (the down card's CALL FOR BACKUP).
	-- They come back in the cave before the boss, where the one who came
	-- in is, to go on together (each gets the boss's loot of their own).
	for _, other in table.clone(run.Members) do
		if other ~= player and run.Fallen[other] then
			revive(run, other, player.DisplayName .. " came through the gate: you're back on your feet, kaiju and all, in the cave before the boss.")
			local root = rootOf(player)
			if root and other.Character then
				other.Character:PivotTo(root.CFrame * CFrame.new(4, 0, 0))
				local theirs = rootOf(other)
				if theirs then
					theirs.AssemblyLinearVelocity = Vector3.zero
				end
				KaijuServer.deployTeam(other)
			end
			run.Reached[other] = cleared
			notify(player, other.DisplayName .. " was down: your coming in got them back up, here beside you.")
		end
	end
end

-- A trip that `player` may join: their party's, with its boss still
-- standing (the caves, or the throne: backup called from down there),
-- with room.
local function partyRun(player: Player)
	local party = Party.of(player)
	for _, member in (party and party.Members) or {} do
		local run = runOf[member]
		if run and not run.Done and not run.Won and #run.Members < RiftRun.Party then
			return run
		end
	end
	return nil
end

-- What stops `player` going in now, if anything.
local function problem(player: Player): string?
	if player:GetAttribute("Outpost") ~= true then
		return "The Rift Gates are out in the Outpost's quarry."
	elseif runOf[player] then
		return "You're in the Rift already."
	elseif Spar.isDown(player) then
		return "Get back on your feet first."
	elseif player:GetAttribute("SparWith") ~= nil then
		return "Finish your spar first."
	elseif
		player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("DungeonId") ~= nil
		or player:GetAttribute("Expedition") ~= nil
		or player:GetAttribute("KaijuBattle") ~= nil
	then
		return "Not in the middle of something else."
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 or not rootOf(player) then
		return "Not now."
	elseif humanoid.SeatPart ~= nil or player:GetAttribute("MechPilot") ~= nil then
		return "Hop out of the mech first: it won't fit through."
	end
	return nil
end

-- Healing crystals ----------------------------------------------------------------------------------------

-- Crystal `n` of `run`, at `at`: a rock the client mines like the Outpost's
-- (OutpostNode, with NodeId, Size, Hp, MaxHp; HealRock marks it, so the
-- client asks "RiftMine": RiftRun.Heal).
local function growHeal(run, n: number, at: Vector3)
	local rules = RiftRun.Heal
	local model = RiftWorld.healRock(run.World.Folder, at, run.Rng)
	local id = string.format("%s:heal:%d", run.Id, n)
	model:SetAttribute("NodeId", id)
	model:SetAttribute("HealRock", true)
	model:SetAttribute("Size", "Boulder")
	model:SetAttribute("Hp", rules.Hp)
	model:SetAttribute("MaxHp", rules.Hp)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine to heal"
	prompt.ObjectText = ""
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = rules.Reach
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Mine")
	prompt:SetAttribute("NodeId", id)
	prompt.Parent = model.PrimaryPart
	CollectionService:AddTag(model, "OutpostNode")
	run.Heals[id] = { Id = id, N = n, At = at, Model = model, Hp = rules.Hp }
end

-- Each cave's crystals, and the throne cave's (RiftRun.healSpots).
function spawnHeals(run)
	local world = run.World
	local areas = table.clone(world.Rooms)
	table.insert(areas, world.Boss)
	local n = 0
	for _, area in areas do
		for _, at in RiftRun.healSpots(area.Center, area.Size, RiftRun.Heal.PerCave, run.Rng) do
			n += 1
			growHeal(run, n, at)
		end
	end
end

-- "RiftMine", id: a swing of your pick at a healing crystal (your kit away:
-- 1). Each heals you a little; the one that breaks it open heals you more
-- and your kaiju out too, and it grows back a while later.
local function healMine(player: Player, id: any)
	local run = runOf[player]
	local rock = if run and type(id) == "string" then run.Heals[id] else nil
	if not run or not rock then
		return reply(false, "That crystal's spent. It grows back in a while.")
	end
	if Spar.sparring(player) then
		return reply(false, "Press X for your pick to mine.")
	end
	if Spar.isDown(player) or run.Fallen[player] or run.Handled[player] then
		return reply(false, "")
	end
	local now = os.clock()
	if now - (run.Swung[player] or 0) < Outpost.SwingCooldown then
		return reply(false, "")
	end
	local rules = RiftRun.Heal
	local root, humanoid = rootOf(player), humanoidOf(player)
	local body = rock.Model.PrimaryPart
	if not root or not humanoid or not body or (root.Position - body.Position).Magnitude > rules.Reach + 2 then
		return reply(false, "Get closer to the crystal.")
	end
	run.Swung[player] = now
	rock.Hp -= 1
	local broke = rock.Hp <= 0
	local before = humanoid.Health
	local share = rules.Swing + (if broke then rules.Pop else 0)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * share)
	local model = rock.Model
	model:SetAttribute("LastHitBy", player.UserId)
	model:SetAttribute("LastCrit", false)
	model:SetAttribute("Hp", rock.Hp)
	-- (The pick's chop, for everyone to see: RivalPose "Mine".)
	local character = player.Character
	if character then
		local t = serverNow()
		character:SetAttribute("ActionKind", "Mine")
		character:SetAttribute("ActionStart", t - 0.12)
		character:SetAttribute("ActionAt", t + 0.05)
	end
	local mended = 0
	if broke then
		run.Heals[id] = nil
		mended = KaijuServer.mend(player, rules.Kaiju)
		model:SetAttribute("Popped", player.UserId)
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		task.delay(0.9, function()
			model:Destroy()
		end)
		task.delay(rules.Regrow, function()
			if not run.Done then
				growHeal(run, rock.N, rock.At)
			end
		end)
	end
	return reply(true, "", {
		Healed = math.floor(humanoid.Health - before + 0.5),
		Broke = broke,
		Kaiju = mended,
		Hp = math.max(0, rock.Hp),
		MaxHp = rules.Hp,
	})
end

-- The biome vein `vein`'s gate stands in (Shared.Frontier.Biomes: its
-- element is the Rift's), or nil without a gate.
local function gateBiome(vein: any)
	local gate = if type(vein) == "number" then RiftServer.gateAt(vein) else nil
	if not gate then
		return nil
	end
	local offset = gate.Position - Outpost.Location.Position
	return Frontier.biomeAt(offset) or Frontier.biomeOf(math.atan2(offset.Z, offset.X))
end

local function enter(player: Player, vein: any, bossId: any, together: any)
	local why = problem(player)
	if why then
		return reply(false, why)
	end
	-- (At the gate itself. A bounty from anywhere in the Outpost: its board
	-- is at Brutus's counter and on the PLAY menu.)
	local bounty = vein == Bounties.Gate
	if not bounty then
		local gate = if type(vein) == "number" then RiftServer.gateAt(vein) else nil
		local root = rootOf(player) :: BasePart
		if not gate or (root.Position - gate.Position).Magnitude > RiftServer.Reach then
			return reply(false, "Walk up to a Rift Gate first.")
		end
	end
	local run = partyRun(player)
	local boss, element = nil, nil
	if not run then
		-- The boss: picked from this gate's ladder (a bounty: from the
		-- ladder it's on), and open to them.
		local biome = if bounty then nil else gateBiome(vein)
		element = if bounty then Bounties.elementOf(bossId) else biome and biome.Element
		if bounty and not element then
			return reply(false, "Pick a bounty first.")
		end
		local beaten = beatenBy(player)
		if bossId == nil then
			bossId = (RiftRun.nextBoss(element, beaten) or {}).Id
		end
		local ok, why = RiftRun.canFight(element, bossId, beaten)
		if not ok then
			return reply(false, why or "That boss isn't behind this gate.")
		end
		boss = RiftRun.bossById(bossId)
	end
	if not run then
		local slot = 1
		while slots[slot] do
			slot += 1
		end
		nextId += 1
		local id = string.format("R%d", nextId)
		local rng = Random.new()
		local origin = CFrame.new(RiftServer.Origin + Vector3.new(-(slot - 1) * RiftServer.SlotGap, 0, 0))
		local ok, world = pcall(RiftWorld.build, id, origin, rng, RiftRealms.of(boss and boss.Id))
		if not ok then
			warn("[Rift] build failed:", world)
			return reply(false, "The gate won't open just now. Try again in a moment.")
		end
		run = {
			Id = id,
			Slot = slot,
			World = world,
			Rng = rng,
			Members = {},
			Room = 1,
			Foes = {},
			Coming = 0, -- (foes on their way through their tears)
			Boss = boss,
			Element = element,
			BossEnemy = nil,
			Adds = {},
			Found = {},
			Restores = {},
			Fallen = {},
			Handled = {},
			Reached = {},
			Spawned = {},
			Heals = {}, -- [id] = a healing crystal standing: { Id, N, At, Model, Hp }
			Swung = {}, -- [player] = their last swing at one (os.clock)
			Loot = nil,
			Started = os.clock(),
		}
		runs[id] = run
		slots[slot] = run
		local grown, why = pcall(spawnHeals, run)
		if not grown then
			warn("[Rift] healing crystals:", why)
		end
		join(run, player)
		-- Going in together (the party's leader, from the gate's lobby):
		-- everyone in the party who's ready comes too, from wherever they
		-- are in the Outpost; the rest are told they can follow.
		local party = Party.of(player)
		if together == true and party and party.Leader == player then
			for _, member in table.clone(party.Members) do
				if member ~= player then
					if party.Ready[member] and problem(member) == nil and #run.Members < RiftRun.Party then
						join(run, member)
					elseif not runOf[member] then
						notify(
							member,
							player.DisplayName .. " went through a Rift Gate: walk up to any gate, or open the bounty board, to follow."
						)
					end
				end
			end
		end
	else
		join(run, player)
	end
	welcome(run, player)
	return reply(true, "", { Runners = #run.Members, Boss = run.Boss.Name })
end

-- What `player` is told on the way in: a first boss, going alone, and what
-- to bring against it.
function welcome(run, player: Player)
	local starter = DungeonRules.starter(run.Boss)
	if starter then
		notify(
			player,
			string.format("%s: a first boss, recommended solo at level %d. You've got this.", run.Boss.Name, starter.Level)
		)
	elseif RiftRun.solo(#run.Members, run.Boss) then
		notify(
			player,
			if RiftRun.isGroup(run.Boss)
				then string.format("You're in the Rift alone, against %s: it's built for 2 to 4 of you. Bring friends if you can.", run.Boss.Name)
				else "You're in the Rift alone. It gets hard fast: bring a friend if you can."
		)
	end
	-- What to bring: its element, what protects you, what beats it.
	local tips = DungeonRules.elementTips(run.Boss)
	notify(player, tips.Lines[2])
	notify(player, tips.Lines[3])
end

-- ADJUST ARMOR: your armor set against `element` (Shared.CounterGear:
-- resist gems in your helmet, gloves and boots, armor pieces that power
-- them; never your sword or your Q, E and R gems). What it would change,
-- or (apply) changed, as CounterGear.summary.
local function gearUp(player: Player, element: string?, apply: boolean)
	local threat = CounterGear.versus(element)
	if apply then
		CounterServer.wear(player, threat)
	end
	return CounterGear.summary(CounterServer.offer(player, threat))
end

-- The element of a boss by its id (any biome's ladder), or of your
-- party's trip.
local function elementFor(player: Player, bossId: any): (string?, any)
	local run = runOf[player] or partyRun(player)
	if run and run.Boss then
		return run.Boss.Element or run.Element, run.Boss
	end
	local boss = if type(bossId) == "string" then RiftRun.bossById(bossId) else nil
	return boss and (boss.Element or Bounties.elementOf(bossId)), boss
end

-- "RiftGear", bossId, apply: ADJUST ARMOR on the Bounty Board, a gate's
-- lobby or a Rift invite.
local function gear(player: Player, bossId: any, apply: any)
	local element, boss = elementFor(player, bossId)
	if not element then
		return reply(false, "Pick a boss first.")
	end
	local before = if apply == true then gearUp(player, element, false) else nil
	local plan = gearUp(player, element, apply == true)
	local name = GemConfig.elementName(element)
	local message = ""
	if apply == true then
		message = if before and before.Changes > 0
			then string.format("Armor set against %s%s.", name, if boss then " for " .. boss.Name else "")
			else before and before.Note or string.format("Your armor already answers %s as well as your gems can.", name)
	end
	return reply(true, message, { Plan = plan, Applied = before, Element = element })
end

-- One who just joined `player`'s party by an invite: into the party's
-- trip now if it's on its way (to the last cave cleared), else ready to
-- go in with them. `opts.GearUp` sets their armor for its boss first.
local function onJoined(player: Player, from: Player, context: any, opts: any)
	local run = partyRun(player)
	local element = if run then run.Boss.Element or run.Element elseif type(context) == "table" then context.Element else nil
	-- (Busy, in a match say, your armor stays as it is.)
	local why = problem(player)
	if opts.GearUp == true and element and not why then
		local done = gearUp(player, element, false)
		gearUp(player, element, true)
		if done.Changes > 0 then
			notify(player, string.format("Armor set against %s.", GemConfig.elementName(element)))
		end
	end
	if run then
		if why then
			notify(player, from.DisplayName .. "'s party is in the Rift: join them from any Rift Gate or the bounty counter. " .. why)
			return
		end
		join(run, player)
		welcome(run, player)
	elseif type(context) == "table" and context.Kind == "Rift" then
		-- (Ready: the leader's ENTER TOGETHER takes you in with them.)
		local party = Party.of(player)
		local leader = if party and party.Leader then party.Leader else from
		Party.setReady(player, true)
		notify(
			player,
			string.format("You're ready for %s: when %s goes in, you go too.", context.Boss or "the Rift", leader.DisplayName)
		)
	end
end

-- What an invite from `player` says (Party.setInviteContext): the boss of
-- their party's trip (Live), or the one they've picked on the board.
local function inviteContext(player: Player, wanted: any)
	local run = runOf[player]
	if run and not run.Done and not run.Won then
		return {
			Kind = "Rift",
			Live = true,
			Boss = run.Boss.Name,
			BossId = run.Boss.Id,
			Element = run.Boss.Element or run.Element,
			Cave = math.clamp(run.Room - 1, 0, RiftRun.Rooms),
		}
	end
	local bossId = type(wanted) == "table" and wanted.Rift
	local boss = type(bossId) == "string" and RiftRun.bossById(bossId)
	if boss then
		return { Kind = "Rift", Live = false, Boss = boss.Name, BossId = boss.Id, Element = boss.Element or Bounties.elementOf(bossId) }
	end
	return nil
end

-- Home through a way home you're standing at.
local function leave(player: Player)
	local run = runOf[player]
	if not run then
		return reply(false, "You're not in the Rift.")
	end
	if run.Fallen[player] or run.Handled[player] then
		return reply(false, "Not while you're down.")
	end
	local root = rootOf(player)
	local near = false
	for _, opening in { run.World.Exit, if run.Won then run.World.Home:FindFirstChild("Opening") else nil } do
		if root and opening and (root.Position - opening.Position).Magnitude <= RiftServer.Reach then
			near = true
		end
	end
	if not near then
		return reply(
			false,
			"Find a way home first: the gate you came in by, or the throne cave's once its boss is down."
		)
	end
	home(player, "Back home through the Rift, with what you found.")
	return reply(true, "")
end

-- Knocked out at the boss: "Restore" or "Home".
local function choose(player: Player, choice: any)
	local run = runOf[player]
	if not run or not run.Fallen[player] then
		return reply(false, "Nothing to choose.")
	end
	if choice == "Home" then
		home(player, "Back at base, with what you found.")
		return reply(true, "")
	elseif choice == "Restore" then
		-- (A RESTORE bought before, kept: used now, nothing to pay.)
		local profile = PlayerData.get(player) :: any
		if profile and (profile.RiftRestores or 0) > 0 then
			profile.RiftRestores -= 1
			PlayerData.sync(player)
			run.Restores[player] = (run.Restores[player] or 0) + 1
			revive(run, player, "Restored: you and your kaiju are back on your feet.")
			return reply(true, "")
		end
		-- (For Robux once its product is on: the purchase is prompted here,
		-- and RiftServer.restoreBought brings you back up. Coins till then.)
		local product = Store.RobuxProducts.RiftRestore or 0
		if product ~= 0 then
			pcall(function()
				game:GetService("MarketplaceService"):PromptProductPurchase(player, product)
			end)
			return reply(true, "")
		end
		local used = run.Restores[player] or 0
		local cost = RiftRun.restoreCost(used)
		if not PlayerData.spendCoins(player, cost) then
			return Shop.short(player, cost, string.format("Not enough coins: RESTORE costs %d.", cost))
		end
		run.Restores[player] = used + 1
		revive(run, player, "Restored: you and your kaiju are back on your feet.")
		return reply(true, "")
	end
	return reply(false, "Choose RESTORE or BACK TO BASE.")
end

-- A RESTORE bought for Robux (StoreServer's RiftRestore): back on your feet
-- at the boss, kaiju and all, if you're still down there; false if not
-- (StoreServer keeps it for next time).
function RiftServer.restoreBought(player: Player): boolean
	local run = runOf[player]
	if not run or not run.Fallen[player] then
		return false
	end
	run.Restores[player] = (run.Restores[player] or 0) + 1
	revive(run, player, "Restored: you and your kaiju are back on your feet.")
	return true
end

-- What going in looks like for `player` (the gate's card, Client.RiftClient):
-- how many in their party, whether they'd join its trip, and whether
-- they'd be on their own.
local function peek(player: Player, vein: any)
	local party = Party.of(player)
	local size = if party then #party.Members else 1
	local theirs = partyRun(player)
	local beaten = beatenBy(player)
	local levels = leadLevels(if theirs then theirs.Members elseif party then party.Members else { player })
	-- A boss as its card shows it.
	local function entryOf(boss, element: string?)
		local open, _, need = RiftRun.canFight(element or boss.Element, boss.Id, beaten)
		local tips = DungeonRules.elementTips(boss)
		portraitOf(boss)
		return {
			Id = boss.Id,
			Name = boss.Name,
			Element = boss.Element,
			Threat = BossLoot.threat(boss),
			Level = RiftRun.bossLevel(levels, boss),
			Group = RiftRun.isGroup(boss),
			-- (A first boss: recommended solo at its level.)
			Starter = DungeonRules.starter(boss) ~= nil,
			Weakness = tips.Weakness,
			Tips = tips.Lines,
			Loot = boss.Loot,
			Unlocked = open,
			Beaten = beaten[boss.Id] or 0,
			Need = need and need.Name,
		}
	end
	-- One biome's ladder as its cards show it.
	local function ladderOf(element: string?)
		local ladder = {}
		for _, boss in RiftRun.ladder(element) do
			table.insert(ladder, entryOf(boss, element))
		end
		local nextUp = RiftRun.nextBoss(element, beaten)
		return ladder, nextUp and nextUp.Id
	end
	if vein == Bounties.Gate then
		-- Brutus's board: every biome's ladder, a tab each; the first
		-- biome's up first.
		local ladders = {}
		for _, entry in Bounties.list() do
			local ladder, nextId = ladderOf(entry.Element)
			table.insert(ladders, { Biome = entry.Biome, Element = entry.Element, Ladder = ladder, Next = nextId })
		end
		local first = ladders[1] or {}
		return reply(true, "", {
			Party = size,
			Joining = theirs ~= nil,
			Solo = theirs == nil and size <= 1,
			Bounty = true,
			Ladders = ladders,
			Biome = first.Biome,
			Element = first.Element,
			Ladder = first.Ladder or {},
			Next = first.Next,
			Boss = theirs and theirs.Boss.Name,
			Theirs = theirs and entryOf(theirs.Boss),
		})
	end
	local biome = gateBiome(vein)
	local element = biome and biome.Element
	local ladder, nextId = ladderOf(element)
	return reply(true, "", {
		Party = size,
		Joining = theirs ~= nil,
		Solo = theirs == nil and size <= 1,
		Biome = biome and biome.Name,
		Element = element,
		Ladder = ladder,
		Next = nextId,
		Boss = theirs and theirs.Boss.Name,
		Theirs = theirs and entryOf(theirs.Boss),
	})
end

-- Vein `index`'s gate: where to stand (OutpostServer sets this).
RiftServer.gateAt = function(_index: number): BasePart?
	return nil
end

-- Brutus's bounty counter in the Shelter: where to stand for a bounty
-- (OutpostServer sets this).
RiftServer.bountyAt = function(): BasePart?
	return nil
end

function RiftServer.runOf(player: Player)
	return runOf[player]
end

function RiftServer.start(outpost)
	site = outpost
	Shop.register("RiftEnter", enter)
	Shop.register("RiftGear", gear)
	Party.setInviteContext(inviteContext)
	Party.onJoined(onJoined)
	Shop.register("RiftLeave", leave)
	Shop.register("RiftChoice", choose)
	Shop.register("RiftPeek", peek)
	Shop.register("RiftMine", healMine)
	Players.PlayerRemoving:Connect(function(player)
		if runOf[player] then
			home(player, nil)
		end
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 0.25 then
			timer = 0
			local ok, err = pcall(step, os.clock())
			if not ok then
				warn("[Rift]", err)
			end
		end
	end)
end

-- For tests.
RiftServer._runs, RiftServer._step, RiftServer._enter = runs, step, enter
RiftServer._leave, RiftServer._choose, RiftServer._finish = leave, choose, finish
RiftServer._peek = peek
function RiftServer._setSite(outpost)
	site = outpost
end

return RiftServer
