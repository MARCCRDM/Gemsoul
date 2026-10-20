--[[
	The Rift on the server (Shared.RiftRun has the rules; see docs/rift.md):
	a trip through a vein's Rift Gate (OutpostWorld.veinMarks) into the
	critters' own world, built for it (World.RiftWorld: walled caves) and
	gone with it.

	  Going in    "RiftEnter", vein: through a gate you're standing at. You
	              join your party's trip if one of them is still on the
	              way (up to RiftRun.Party), or start one. Your combat kit
	              comes out and stays out till you're home
	              (SparServer.riftKit: hunting, so a finishing blow knocks
	              you down rather than kills you); your kaiju come with you
	              (you keep Outpost, so KaijuServer keeps them out).
	  The way     a cave's pack comes up once one of you walks in: brainrot
	              critters (KaijuWilds.spawnBug: Stay, Wander) at your
	              kaiju's level and up, and the pathway dungeon's fighters
	              (Duelist.spawnDungeon, a Rift encounter: anyone in can hit
	              them and be hit, kaiju too). Every one down, the wall of
	              fire on the way out dies (RiftWorld.openGate) and everyone
	              in finds a cache (Gems.award "RiftCache": the gems you've
	              found in here). Through the floor somehow, back in the
	              last cave you reached (RiftRun.Fall).
	  Falling     knocked out on the way (SparServer's knock-down, or
	              killed outright): the critters rob you (RiftRun.robCount
	              of the gems you found in here, out of your pouch) and
	              you're thrown back to base. Knocked out at the boss: you
	              stay down (RiftFallen: SparServer leaves you there) and
	              choose ("RiftChoice"): "Restore" (RiftRun.restoreCost
	              coins: your health and your kaiju's, all of them back:
	              KaijuServer.restoreAll), "Home" (back to base, keeping
	              what you found) or invite a friend (the client's); nothing
	              chosen in RiftRun.Fallen seconds, home you go.
	  The boss    one of the ten brainrot bosses at random, as the pathway
	              dungeon's Colossus (a Duelist fighter with its every move,
	              RiftRun.bossHealth times tougher): it tears through in the
	              throne cave once one of you sets foot there, and calls
	              critters and a fighter through at each of
	              RiftRun.Boss.Adds. Beaten: everyone still in gets
	              RiftRun.rewardCoins, a lucky cache, EXP for their kaiju
	              and swings back on their pick (SwingRestore.Dungeon); the
	              fallen are back up; the way home opens, and its loot comes
	              up: claim, roll or pass ("RiftLootChoice", the pathway
	              dungeon's card: DungeonLoot), a fair roll for its gem
	              (Dungeons.bossGem). RiftRun.Exit seconds after that's
	              settled, everyone's home.
	  Leaving     "RiftLeave": through a way home you're at (the landing's,
	              or the throne cave's once it's open), keeping what you found.
	  The gate    "RiftPeek": what going in looks like (the gate's card):
	              { Party, Joining, Solo }.

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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RiftRun = require(ReplicatedStorage.Shared.RiftRun)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
local Spar = require(ReplicatedStorage.Shared.Spar)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local RiftWorld = require(script.Parent.Parent.World.RiftWorld)
local Duelist = require(script.Parent.Duelist)
local Dungeons = require(script.Parent.Dungeons)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuServer = require(script.Parent.KaijuServer)
local KaijuWilds = require(script.Parent.KaijuWilds)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Restores = require(script.Parent.Restores)
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
	local left = 0
	for _ in run.Foes do
		left += 1
	end
	for _, player in run.Members do
		player:SetAttribute("RiftRoom", run.Room)
		player:SetAttribute("RiftLeft", left)
		player:SetAttribute("RiftRunners", #run.Members)
		player:SetAttribute("RiftBoss", if run.Room > RiftRun.Rooms then run.Boss.Name else nil)
		player:SetAttribute("RiftFound", #(run.Found[player] or {}))
		player:SetAttribute("RiftWon", run.Won or nil)
		player:SetAttribute("RiftExitAt", run.ExitServer)
	end
end

local CLEAR = {
	"RiftRun",
	"RiftRoom",
	"RiftLeft",
	"RiftBoss",
	"RiftFound",
	"RiftRunners",
	"RiftWon",
	"RiftExitAt",
	"RiftFallen",
	"RiftRestore",
	"DungeonLoot",
	"DungeonLootDeadline",
	"DungeonLootTitle",
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

-- The lead kaiju's level of everyone in.
local function levelsOf(run): { number }
	local levels = {}
	for _, player in run.Members do
		local profile = PlayerData.get(player)
		local lead = profile and Kaiju.active(profile.Kaiju)
		if lead then
			table.insert(levels, lead.Level)
		end
	end
	return levels
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
	opts.Facing = run.World.Start.Position
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
	if not boss then
		run.Foes[enemy] = true
	end
	return enemy
end

-- Cave `room`'s pack comes up: its critters, and the pathway dungeon's
-- fighters among them.
local function spawnRoom(run, room: number)
	if run.Spawned[room] then
		return
	end
	run.Spawned[room] = true
	local cave = run.World.Rooms[room]
	local level = RiftRun.level(levelsOf(run), room)
	local band = if room >= 3 then "Edge" else "Fringe"
	for _, foe in RiftRun.pickFoes(room, #run.Members, run.Rng) do
		local at = spotOn(run, cave.Center, cave.Radius, 0.55)
		local spec = nil
		for _, entry in DungeonRules.Roster do
			if entry.Id == foe.Critter then
				spec = entry
			end
		end
		local elite = RiftRun.Elite
		spawnFoe(run, at, {
			Critter = foe.Critter,
			Level = level,
			Band = band,
			Scale = if foe.Elite then elite.Scale else nil,
			Health = if foe.Elite then elite.Health else nil,
			Damage = if foe.Elite then elite.Damage else nil,
			Reach = if foe.Elite then elite.Reach else nil,
			Title = if foe.Elite and spec then string.format("Rift Brute · %s · Lv %d", spec.Name, level) else nil,
		})
	end
	for _, spec in RiftRun.pickFighters(room, #run.Members, run.Rng) do
		spawnFighter(
			run,
			spotOn(run, cave.Center, cave.Radius, 0.45),
			spec,
			RiftRun.fighterTier(room),
			false,
			RiftRun.Fighters.Health
		)
	end
	show(run)
end

-- When a tear opened by KaijuWilds.rift lets its critter through (now, if
-- none opened).
local function hopIn(life): number
	return if life then math.max(0, life.HopAt - serverNow()) else 0
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
	task.delay(hopIn(KaijuWilds.rift(at, run.World.Start.Position)), function()
		if run.Done or run.Won then
			return
		end
		run.BossTier = RiftRun.bossTier(#run.Members, run.Rng)
		local boss = spawnFighter(run, at, run.Boss, run.BossTier, true, RiftRun.bossHealth(#run.Members))
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

-- Some of its critters through at once round the boss, and its fighters
-- (its Adds).
local function callAdds(run)
	local boss = run.BossEnemy
	if not boss or not boss.Alive then
		return
	end
	local rule = RiftRun.Boss
	local level = RiftRun.level(levelsOf(run), RiftRun.Rooms)
	local arena = run.World.Boss
	for _, id in Kaiju.wave(rule.AddCount, run.Rng) do
		local at = spotOn(run, arena.Center, arena.Radius, 0.6)
		task.delay(hopIn(KaijuWilds.rift(at, boss.Root.Position)), function()
			if not run.Done and not run.Won then
				spawnFoe(
					run,
					at,
					{ Critter = id, Level = level, Band = "Edge", Wander = { Home = at, Roam = 14, Notice = 60 } }
				)
				show(run)
			end
		end)
	end
	local fighters = RiftRun.pickFighters(RiftRun.Rooms, 1, run.Rng)
	for _ = 1, rule.AddFighters do
		spawnFighter(
			run,
			spotOn(run, arena.Center, arena.Radius, 0.6),
			fighters[1],
			rule.AddTier,
			false,
			RiftRun.Fighters.Health
		)
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
		announce(run, "The last cave's clear. Something waits on the throne.")
	end
	show(run)
end

local LOOT = { "DungeonLoot", "DungeonLootDeadline", "DungeonLootTitle" }

-- The boss's loot is settled (everyone chose, or the time's up): a fair roll
-- among those who claimed or rolled, the gem to the highest (Dungeons.bossGem,
-- as the pathway dungeon's), and the way home's clock starts.
local function resolveLoot(run)
	local loot = run.Loot
	if not loot or loot.Resolved or run.Done then
		return
	end
	loot.Resolved = true
	local contenders = {}
	for _, player in loot.Eligible do
		if player.Parent and runOf[player] == run and loot.Choices[player] and loot.Choices[player] ~= "Pass" then
			table.insert(contenders, player)
		end
	end
	local winner, best, rolls, tied = nil, -1, {}, {}
	for _, player in contenders do
		local roll = run.Rng:NextInteger(1, 100)
		table.insert(rolls, player.DisplayName .. " " .. roll)
		if roll > best then
			best, tied = roll, { player }
		elseif roll == best then
			table.insert(tied, player)
		end
	end
	if #tied > 0 then
		winner = tied[run.Rng:NextInteger(1, #tied)]
	end
	if winner then
		local gem = Dungeons.bossGem(loot.Element, loot.Tier)
		if PlayerData.addGem(winner, gem) then
			run.Found[winner] = run.Found[winner] or {}
			table.insert(run.Found[winner], gem.Id)
		else
			PlayerData.addCoins(winner, 500)
			notify(winner, "Gem pouch full: boss gem converted to 500 coins.")
		end
	end
	announce(
		run,
		if winner
			then string.format(
				"RIFT LOOT: %s wins the %s gem. %s",
				winner.DisplayName,
				GemConfig.elementName(loot.Element),
				table.concat(rolls, " · ")
			)
			else "The boss's gem was passed."
	)
	for _, player in loot.Eligible do
		if player.Parent then
			for _, key in LOOT do
				player:SetAttribute(key, nil)
			end
		end
	end
	run.ExitAt = os.clock() + RiftRun.Exit
	run.ExitServer = serverNow() + RiftRun.Exit
	show(run)
end

-- The boss's loot comes up for everyone still in: claim, roll or pass
-- (the pathway dungeon's card, Client DungeonLoot), RiftRun.Loot.Seconds.
local function beginLoot(run)
	local eligible = table.clone(run.Members)
	local tier = run.BossTier or 4
	run.Loot = {
		Eligible = eligible,
		Choices = {},
		Tier = tier,
		Element = run.Boss.Element,
		Deadline = os.clock() + RiftRun.Loot.Seconds,
	}
	local label = string.format(
		"%s %s Gem  ·  Tier 4 / Rank III",
		if tier == 5 then "Legendary" else "Ultra Rare",
		GemConfig.elementName(run.Boss.Element)
	)
	for _, player in eligible do
		player:SetAttribute("DungeonLootTitle", "RIFT BOSS DEFEATED")
		player:SetAttribute("DungeonLootDeadline", serverNow() + RiftRun.Loot.Seconds)
		player:SetAttribute("DungeonLoot", label)
	end
	task.delay(RiftRun.Loot.Seconds, function()
		resolveLoot(run)
	end)
end

-- "RiftLootChoice": claim, roll or pass on the boss's gem.
local function lootChoice(player: Player, choice: any)
	local run = runOf[player]
	local loot = run and run.Loot
	if not loot or loot.Resolved or not table.find(loot.Eligible, player) then
		return reply(false, "No boss loot to choose.")
	end
	if choice ~= "Claim" and choice ~= "Roll" and choice ~= "Pass" then
		return reply(false, "Choose Claim, Roll or Pass.")
	end
	if loot.Choices[player] then
		return reply(false, "Your choice is already locked.")
	end
	loot.Choices[player] = choice
	local all = true
	for _, other in loot.Eligible do
		if other.Parent and runOf[other] == run and not loot.Choices[other] then
			all = false
		end
	end
	if all then
		resolveLoot(run)
	end
	return reply(true, "Choice locked: " .. choice)
end

-- The boss is down: the trip's won. Its loot comes up, and the way home
-- opens (and takes everyone RiftRun.Exit seconds after the loot's settled).
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
	for _, player in run.Members do
		if run.Fallen[player] then
			run.Fallen[player] = nil
			standUp(player)
		end
		PlayerData.addCoins(player, coins)
		KaijuServer.reward(player, RiftRun.Reward.Exp)
		local swings = Restores.give(player, SwingRestore.Dungeon)
		pcall(PlayerData.training, player, "Boss")
		notify(
			player,
			string.format("%s is beaten! +%d coins", run.Boss.Name, coins)
				.. (if swings > 0 then string.format(", +%d swings", swings) else "")
				.. ". The way home is open."
		)
	end
	RiftWorld.openHome(run.World)
	beginLoot(run)
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
	if next(run.Foes) == nil and run.Room <= RiftRun.Rooms and run.Spawned[run.Room] then
		cleared(run, run.Room)
	else
		show(run)
	end
end

-- Knocked out on the path: robbed, and back to base.
local function robbed(run, player: Player)
	run.Handled[player] = true
	local found = run.Found[player] or {}
	local count = RiftRun.robCount(#found)
	local profile = PlayerData.get(player)
	local loose = {}
	for _, gem in (profile and GemInventory.available(profile)) or {} do
		loose[gem.Id] = true
	end
	local taken = 0
	for i = #found, 1, -1 do
		if taken >= count then
			break
		end
		local id = found[i]
		if loose[id] and PlayerData.removeGem(player, id) then
			taken += 1
			table.remove(found, i)
		end
	end
	local root = rootOf(player)
	if root then
		fx("CritterGiggle", root.Position + Vector3.new(0, 3, 0), "Cackle")
	end
	notify(
		player,
		if taken > 0
			then string.format(
				"You went down. The critters robbed you: %d of the gems you found in the Rift, gone.",
				taken
			)
			else "You went down. The critters found nothing on you to take."
	)
	task.delay(2.5, function()
		if runOf[player] == run then
			home(player, "Thrown back to base.")
		end
	end)
end

-- Knocked out at the boss: down until they choose (or the time runs out).
local function fallAtBoss(run, player: Player)
	run.Handled[player] = true
	local deadline = serverNow() + RiftRun.Fallen
	run.Fallen[player] = deadline
	player:SetAttribute("RiftFallen", deadline)
	player:SetAttribute("RiftRestore", RiftRun.restoreCost(run.Restores[player] or 0))
	player:SetAttribute("SparDown", deadline + 1)
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

-- Joins `run`: on its landing, the attributes, and word of how many are in.
local function join(run, player: Player)
	table.insert(run.Members, player)
	runOf[player] = run
	run.Found[player] = run.Found[player] or {}
	run.Reached[player] = 0
	player:SetAttribute("RiftRun", run.Id)
	local spot = run.World.Start * CFrame.new((#run.Members - 1) * 3 - 4.5, 0, 0)
	player.Character:PivotTo(spot)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- (In there you fight: your combat kit comes out, and stays out.)
	SparServer.riftKit(player, true)
	show(run)
	for _, other in run.Members do
		if other ~= player then
			notify(other, player.DisplayName .. " came through the gate.")
		end
	end
end

-- A trip that `player` may join: their party's, still on the path, with room.
local function partyRun(player: Player)
	local party = Party.of(player)
	for _, member in (party and party.Members) or {} do
		local run = runOf[member]
		if run and not run.Done and not run.Won and run.Room <= RiftRun.Rooms and #run.Members < RiftRun.Party then
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

local function enter(player: Player, vein: any)
	local why = problem(player)
	if why then
		return reply(false, why)
	end
	-- (At the gate itself.)
	local gate = if type(vein) == "number" then RiftServer.gateAt(vein) else nil
	local root = rootOf(player) :: BasePart
	if not gate or (root.Position - gate.Position).Magnitude > RiftServer.Reach then
		return reply(false, "Walk up to a Rift Gate first.")
	end
	local run = partyRun(player)
	if not run then
		local slot = 1
		while slots[slot] do
			slot += 1
		end
		nextId += 1
		local id = string.format("R%d", nextId)
		local rng = Random.new()
		local origin = CFrame.new(RiftServer.Origin + Vector3.new(-(slot - 1) * RiftServer.SlotGap, 0, 0))
		local ok, world = pcall(RiftWorld.build, id, origin, rng)
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
			Boss = RiftRun.pickBoss(rng),
			BossEnemy = nil,
			Adds = {},
			Found = {},
			Restores = {},
			Fallen = {},
			Handled = {},
			Reached = {},
			Spawned = {},
			Loot = nil,
			Started = os.clock(),
		}
		runs[id] = run
		slots[slot] = run
		join(run, player)
	else
		join(run, player)
	end
	if RiftRun.solo(#run.Members) then
		notify(player, "You're in the Rift alone. It gets hard fast: bring a friend if you can.")
	end
	return reply(true, "", { Runners = #run.Members, Boss = run.Boss.Name })
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
		local used = run.Restores[player] or 0
		local cost = RiftRun.restoreCost(used)
		if not PlayerData.spendCoins(player, cost) then
			return reply(false, string.format("Not enough coins: RESTORE costs %d.", cost))
		end
		run.Restores[player] = used + 1
		run.Fallen[player], run.Handled[player] = nil, nil
		standUp(player)
		KaijuServer.restoreAll(player)
		local root = rootOf(player)
		if root then
			fx("Deploy", root.Position, 6, nil, root.Position)
		end
		notify(player, "Restored: you and your kaiju are back on your feet.")
		show(run)
		return reply(true, "")
	end
	return reply(false, "Choose RESTORE or BACK TO BASE.")
end

-- What going in looks like for `player` (the gate's card, Client.RiftClient):
-- how many in their party, whether they'd join its trip, and whether
-- they'd be on their own.
local function peek(player: Player)
	local party = Party.of(player)
	local size = if party then #party.Members else 1
	local joining = partyRun(player) ~= nil
	return reply(true, "", { Party = size, Joining = joining, Solo = not joining and size <= 1 })
end

-- Vein `index`'s gate: where to stand (OutpostServer sets this).
RiftServer.gateAt = function(_index: number): BasePart?
	return nil
end

function RiftServer.runOf(player: Player)
	return runOf[player]
end

function RiftServer.start(outpost)
	site = outpost
	Shop.register("RiftEnter", enter)
	Shop.register("RiftLeave", leave)
	Shop.register("RiftChoice", choose)
	Shop.register("RiftPeek", peek)
	Shop.register("RiftLootChoice", lootChoice)
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
RiftServer._peek, RiftServer._lootChoice = peek, lootChoice
function RiftServer._setSite(outpost)
	site = outpost
end

return RiftServer
