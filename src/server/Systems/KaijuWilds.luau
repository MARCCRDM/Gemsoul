--[[
	Wild kaiju and moon bugs in the Outpost's far quarry (Shared.Kaiju has
	the numbers; see docs/kaiju.md).

	  Wild kaiju  up to Kaiju.Wild.Max roam at once, in packs of up to
	              Kaiju.Wild.Pack of a kind (each its own element), levelled
	              near the kaiju out around them. A pack has a den out in the
	              frontier that moves on now and then; each kaiju wanders
	              round it, stopping to sniff, look about, lie down or roar,
	              and stops to look at anyone who comes close (Kaiju.Roam,
	              KaijuMood on its model for the clients' poses). One
	              leaves you and your kaiju alone until you start a fight:
	              challenge it ("KaijuChallenge", its Challenge prompt) and
	              your kaiju goes in, or hit it while hunting (the combat
	              kit out: SparServer). It fights those who started on it
	              and their kaiju (its packmate close by joins in:
	              Kaiju.Wild.Defend), and forgets them once home. It walks
	              only where the way is clear (clearPath). It fights as the Arena's duellist does
	              (KaijuFighter: combos, telegraphed heavies, guard and
	              parry, hops, their Gemsoul's E), and walk home to heal if
	              led past their leash. Every blow on one lands anywhere from
	              60% to 140%, by element as well (TakenScale, which
	              Enemies.damage applies), and meets its guard there.
	              Killed: the one who (with their kaiju) did the most gets
	              its Gemsoul, and every kaiju that fought it gets EXP.
	              Tamed ("KaijuTame"): a cast (Kaiju.Tame) that holds it,
	              struggling ("Bound") and untouchable, then the roll; it
	              joins you, Gemsoul and all. The cast breaks if you're hit
	              or stray. Three failed tries and it burrows away; so does
	              one left alone for Kaiju.Wild.Lifetime.
	  Guardian    one more wild kaiju, bigger, pacing and napping in front of
	              the guarded Rift Vein (Shared.Frontier.Guardian: levels 16
	              to 20). The first swing at its vein stirs it, the second
	              makes it roar, the third wakes it (KaijuWilds.veinSwing,
	              from OutpostServer), and it goes for that miner, then anyone
	              else mining its vein, a plain miner too (knocked down, not
	              killed), and their kaiju. Challenge it, beat it or tame it
	              like any wild kaiju; killed, it pays Frontier.Coins.Guardian
	              too. It never burrows of old age, and nothing takes its
	              place until its vein moves (KaijuWilds.veinMoved): then
	              whatever's left of it goes, and a fresh one sleeps at the
	              new site.
	  Moon bugs   the little brainrot creatures (DungeonRules' roster,
	              shrunk), each through a rift of its own round a player out
	              past the core (FrontierServer: Shared.Frontier). One hops
	              out at whoever drew it (a miner too, or a mech's pilot:
	              KaijuWilds.prey), but a kaiju out close by draws it first
	              (Kaiju.Bug.Draw: the prey's own before any other); with
	              nobody to fight for a moment (Frontier.Leave), or after its
	              life (Frontier.Life), it slips back through a rift. One out
	              of a wandering rift (opts.Wander) roams round it instead,
	              going for whoever comes close, its own player only once
	              they're near. Its level comes from where it came through
	              (Frontier.Levels; the edge's are tougher too,
	              Frontier.Boost). Killed: EXP to every kaiju that fought it
	              (Frontier.critterExp), coins to whoever did the most
	              (Frontier.Coins, a day's cap). A pickaxe bonks one
	              (KaijuWilds.bonk, from OutpostServer).

	Both are ordinary Enemies (so every attack, status and nameplate works on
	them) with their own brains, marked OutpostCreature for the kaiju out.
	A wild kaiju's model carries KaijuWild, KaijuLevel, KaijuAbility and
	KaijuTries for the client's tame button (and its glow when it's ready),
	and KaijuTameBy / KaijuTameEnds while a tame is cast on it; the tamer
	gets TameResult / TameResultAt when it ends.

	  "KaijuTame", model        cast a tame on a weakened wild kaiju (within
	                            Kaiju.Tame.Range); the roll at its end
	  "KaijuChallenge", model   start a fight with a wild kaiju (within 20 studs,
	                            with your kaiju out or hunting)

	  KaijuWilds.spawnBug(at, opts) -> enemy?   a moon bug out of a rift
	  KaijuWilds.pickCritter(rng) -> roster id  what comes through next
	  KaijuWilds.isCritter(enemy) -> boolean    a rift's critter (not a wild kaiju)
	  KaijuWilds.critterOf(model) -> enemy?     the rift's critter a model is
	  KaijuWilds.bonk(enemy, player, from) -> boolean   a pickaxe's bonk on a critter
	  KaijuWilds.rift(at, facing) -> timeline?  opens a rift (FrontierServer
	                                            sets it; a bug slips back through one)
	  KaijuWilds.done(enemy, killed, totals)    a critter is gone (FrontierServer
	                                            sets it: wandering rifts cleared)
	  KaijuWilds.veinSwing(index, player)       a swing at vein `index`'s rocks
	  KaijuWilds.veinMoved(index, scar)         vein `index` surfaced at `scar`
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuFight = require(ReplicatedStorage.Shared.KaijuFight)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuAbilities = require(script.Parent.KaijuAbilities)
local KaijuFighter = require(script.Parent.KaijuFighter)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuWilds = {}

local TAME_RANGE = Kaiju.Tame.Range
local CHALLENGE_RANGE = 20
local CALM_AFTER = 8 -- seconds home, out of the fight, before it forgets who started on it
local HOME_HEAL = 0.05 -- share of its health back each second, walking home

type Wild = {
	Enemy: any,
	Species: string,
	Element: string,
	Level: number,
	Soul: any,
	Ability: string?,
	Born: number,
	Tries: number,
	TameAt: { [Player]: number },
	Fighter: any?, -- how a wild kaiju fights (KaijuFighter; a moon bug has none)
	LastFight: number?,
	Bug: boolean,
	Prey: Player?, -- a rift's critter: whoever drew it
	Wander: any?, -- out of a wandering rift: { Home, Roam, Notice }
	Life: number?, -- seconds before a critter slips back (Frontier.Life)
	RoamAt: number?,
	-- A wild kaiju's: who started a fight with it (and when they last did
	-- anything in it). Its Enemies record carries the same table (Engaged),
	-- for the kaiju out.
	Engaged: { [Player]: number },
	Band: string?, -- where its rift opened (Shared.Frontier)
	IdleSince: number?,
	Leaving: boolean?,
	Guard: boolean?, -- the guarded vein's (Frontier.Guardian)
	Swings: number?, -- swings at its vein while it slept, the last at SwingAt
	SwingAt: number?,
	Pack: any?, -- a roaming one's pack (its den, its packmates)
	Plan: any?, -- what it's doing while nobody fights it: { Mood, Until, To? }
	GrowlAt: number?, -- its last roar at someone
	Lifetime: number?, -- a wild one's: seconds unfought before it burrows (each its own)
	Noticed: { [Player]: number }?, -- when it last stopped to look at each player
	Taming: any?, -- a tame being cast on it: { Player, Ends, Health (the tamer's, to see a hit) }
}

-- A pack of roaming wild kaiju: its den out in the frontier (they wander
-- round it, and it moves on now and then), its kind, and its members (the
-- first leads: the others keep near it).
type Pack = {
	Den: Vector3,
	Heading: number,
	MoveAt: number,
	Species: string,
	Members: { Wild },
}

local wilds: { [any]: Wild } = {} -- by Enemies record
local wildCount = 0 -- (roaming: the guardian isn't one of them)
local guardian: Wild? = nil
local guardAt: CFrame? = nil -- its vein's dormant rift
local packs: { Pack } = {}
local site: any = nil -- the Outpost's (its rock spots, live: veins move theirs)
local rng = Random.new()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Hunting: the combat kit out in the Outpost with no partner (SparServer),
-- on their feet.
local function hunter(player: Player): boolean
	return player:GetAttribute("Hunt") == true
		and player:GetAttribute("Outpost") == true
		and Spar.sparring(player)
		and not Spar.isDown(player)
end
KaijuWilds.hunter = hunter

-- Prey for a rift's critter: a hunter anywhere, or anyone else in the
-- Outpost on their feet (or in a mech's cockpit) out past the core, not in
-- a spar or a fight elsewhere. (A critter's blow that would finish a miner
-- knocks them down instead: SparServer.)
local function prey(player: Player): boolean
	if hunter(player) then
		return true
	end
	if
		player:GetAttribute("Outpost") ~= true
		or Spar.sparring(player)
		or Spar.isDown(player)
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("DungeonId") ~= nil
		or player:GetAttribute("Expedition") ~= nil
	then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	-- (A mech's pilot too: its swings draw critters like a pick's.)
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart ~= nil or not root then
		return false
	end
	return Frontier.distance(root.Position, Outpost.Location.Position) >= Frontier.Core - Frontier.Safe
end
KaijuWilds.prey = prey

-- The level of the kaiju out with players near a point.
local function levelsNear(point: Vector3, radius: number): { number }
	local levels = {}
	for player, pet in KaijuServer.pets() do
		local root = rootOf(player)
		if root and (root.Position - point).Magnitude <= radius then
			table.insert(levels, pet.Record.Level)
		end
	end
	if #levels == 0 then
		-- (Nobody near yet: the kaiju out anywhere in the Outpost.)
		for _, pet in KaijuServer.pets() do
			table.insert(levels, pet.Record.Level)
		end
	end
	return levels
end

-- Where the guardian sleeps: in front of its vein, Frontier.Guardian.Home
-- studs in from the dormant rift, facing the outpost.
local function guardHome(scar: CFrame): (Vector3, Vector3)
	local middle = Outpost.Location.Position
	local out = flat(scar.Position - middle)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
	return scar.Position - out * Frontier.Guardian.Home, middle
end

-- Room for a wild kaiju to stand at `p`: clear of the rocks (and, for a
-- roaming one, out in the frontier, away from the landing pad, the guarded
-- vein and the site's keep-out zones: OutpostWorld's KeepOut).
local function roomy(p: Vector3, guard: boolean?): boolean
	local out = Frontier.distance(p, Outpost.Location.Position)
	if out > Frontier.Rim - 10 then
		return false
	end
	if not guard then
		if out < Frontier.Core + 10 then
			return false
		end
		if site and site.Spawn and flat(p - site.Spawn.Position).Magnitude < Kaiju.Wild.FarFromSpawn then
			return false
		end
		if guardAt and flat(p - (guardHome(guardAt :: CFrame))).Magnitude < 55 then
			return false
		end
		-- (Nor into the buildings, the old workings, the ramps or a vein's site.)
		for _, zone in if site and site.KeepOut then site.KeepOut else {} do
			if flat(zone[1] - p).Magnitude < zone[2] then
				return false
			end
		end
	end
	for _, cframe in if site and site.Spots then site.Spots else {} do
		if flat(cframe.Position - p).Magnitude < 7 then
			return false
		end
	end
	return true
end

-- Foes -------------------------------------------------------------------------------------------------

-- Its foes inside a circle: kaiju out (not recalled) and hunters (`wide`,
-- a rift's critter: any prey).
local function foesNear(center: Vector3, radius: number, wide: boolean?): { any }
	local list = {}
	for _, pet in KaijuServer.pets() do
		if KaijuServer.targetable(pet) and (pet.Root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = pet.Root, Pet = pet })
		end
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local fair = if wide then prey(player) else hunter(player)
		if root and fair and (root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = root, Player = player })
		end
	end
	return list
end

-- A wild kaiju leaves you be until you start on it: who has, and since when.
local function engage(wild: Wild, player: Player?, now: number)
	if player and not wild.Bug then
		wild.Engaged[player] = now
		-- Its packmate close by comes to its defence (Kaiju.Wild.Defend).
		for _, mate in if wild.Pack then wild.Pack.Members else {} do
			local close = mate ~= wild
				and mate.Enemy.Alive
				and flat(mate.Enemy.Root.Position - wild.Enemy.Root.Position).Magnitude <= Kaiju.Wild.Defend
			if close then
				mate.Engaged[player] = now
			end
		end
	end
end
local function engaged(wild: Wild, player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and wild.Engaged[player] ~= nil
end

-- Its foes near a point (for its E): only those who started on it (a
-- guardian's, miners too).
local function foesOf(wild: Wild)
	return function(center: Vector3, radius: number): { any }
		local list = {}
		for _, victim in foesNear(center, radius, wild.Guard) do
			if engaged(wild, if victim.Pet then victim.Pet.Owner else victim.Player) then
				table.insert(list, victim)
			end
		end
		return list
	end
end

-- A blow (`heavy` true or false; nil for an E) on a kaiju or a hunter, who
-- may guard, parry or hop clear of it. Returns how it landed.
local function hitFoe(enemy, victim, amount: number, element: string?, status: string?, heavy: boolean?): string
	local wild = wilds[enemy]
	local player = victim.Player
	if victim.Pet then
		return KaijuServer.hurt(victim.Pet, amount, element, status, heavy)
	elseif player and (hunter(player) or (wild ~= nil and (wild.Bug or wild.Guard) and prey(player))) then
		local _, guarded = Enemies.hitPlayer(victim.Player, amount, element, enemy, heavy)
		return if guarded then "Guarded" else "Hit"
	end
	return "Missed"
end

-- Who it goes after: a rift's critter, whoever drew it while they're fair
-- game; then whoever hurt it last (a kaiju or a hunter), while they're
-- inside its leash; else its current foe; else the nearest it sees. A wild
-- kaiju only goes after those who started on it (a hit is starting on it)
-- and their kaiju; a guardian, those who mined its vein too, on foot.
local function chooseFoe(enemy, wild: Wild, aggro: number)
	local now = os.clock()
	local e = enemy :: any
	local rifted = wild.Bug
	local wide = rifted or wild.Guard == true
	local leash = if rifted then Kaiju.Bug.Leash else Kaiju.Wild.Leash
	if not wild.Bug then
		if e.LastPet and e.LastPetAt and now - e.LastPetAt < 6 then
			engage(wild, e.LastPet.Owner, e.LastPetAt)
		end
		if enemy.LastSource and now - enemy.LastSourceAt < 6 then
			engage(wild, enemy.LastSource, enemy.LastSourceAt)
		end
	end
	local function valid(victim): boolean
		if not victim or not victim.Root or not victim.Root.Parent then
			return false
		end
		if victim.Pet and not KaijuServer.targetable(victim.Pet) then
			return false
		end
		if victim.Player and not (if wide then prey(victim.Player) else hunter(victim.Player)) then
			return false
		end
		if not wild.Bug and not engaged(wild, if victim.Pet then victim.Pet.Owner else victim.Player) then
			return false
		end
		return (victim.Root.Position - enemy.Home).Magnitude <= leash
	end
	-- A rift's critter goes for a kaiju out close by before any player (your
	-- kaiju draws them off you: Kaiju.Bug.Draw), its prey's own first; and
	-- the kaiju goes for it (KaijuServer: one after it or its owner).
	if rifted then
		local best, bestScore = nil, math.huge
		for _, pet in KaijuServer.pets() do
			local distance = (pet.Root.Position - enemy.Root.Position).Magnitude
			if distance <= Kaiju.Bug.Draw then
				local victim = { Root = pet.Root, Pet = pet }
				local score = distance - (if pet.Owner == wild.Prey then 100 else 0)
				if score < bestScore and valid(victim) then
					best, bestScore = victim, score
				end
			end
		end
		if best then
			return best
		end
	end
	-- (Out of a wandering rift: its own player only once they come near.)
	if rifted and wild.Prey and wild.Prey.Parent then
		local victim = { Root = rootOf(wild.Prey), Player = wild.Prey }
		local near = not wild.Wander
			or (victim.Root ~= nil and (victim.Root.Position - enemy.Root.Position).Magnitude <= wild.Wander.Notice)
		if near and valid(victim) then
			return victim
		end
	end
	-- Hurt by a kaiju or a player in the last few seconds.
	local pet = e.LastPet
	if pet and e.LastPetAt and now - e.LastPetAt < 6 then
		local victim = { Root = pet.Root, Pet = pet }
		if valid(victim) and (not enemy.LastSource or e.LastPetAt >= enemy.LastSourceAt) then
			return victim
		end
	end
	local source = enemy.LastSource
	if source and now - enemy.LastSourceAt < 6 then
		local victim = { Root = rootOf(source), Player = source }
		if valid(victim) then
			return victim
		end
	end
	local current = e.FoeVictim
	if valid(current) and (current.Root.Position - enemy.Root.Position).Magnitude <= aggro * 1.6 then
		return current
	end
	local best, bestDistance = nil, aggro
	for _, victim in foesNear(enemy.Root.Position, aggro, wide) do
		local distance = (victim.Root.Position - enemy.Root.Position).Magnitude
		if valid(victim) and distance <= bestDistance then
			best, bestDistance = victim, distance
		end
	end
	return best
end

-- Opens a rift (FrontierServer sets this): returns its timeline, or nil.
KaijuWilds.rift = function(_at: Vector3, _facing: Vector3)
	return nil
end
-- A critter is gone, `killed` or slipped back (FrontierServer sets this).
KaijuWilds.done = function(_enemy, _killed: boolean, _totals) end

-- A rift's critter with nobody left to fight (or out too long) slips back
-- through a rift of its own.
local function slipBack(wild: Wild)
	local enemy = wild.Enemy
	if wild.Leaving or not enemy.Alive then
		return
	end
	wild.Leaving = true
	KaijuWilds.done(enemy, false, nil)
	local root = enemy.Root
	enemy.Humanoid:MoveTo(root.Position)
	local life = KaijuWilds.rift(root.Position, root.Position + root.CFrame.LookVector * 10)
	local wait = if life then life.HopAt - workspace:GetServerTimeNow() else 0
	task.delay(math.max(0, wait), function()
		if enemy.Alive then
			wilds[enemy] = nil
			Enemies.remove(enemy)
		end
	end)
end
KaijuWilds._slipBack = slipBack

-- A wandering rift's critter stays while its player is still about.
local function lingers(wild: Wild): boolean
	local player = wild.Prey
	local root = player and player.Parent and rootOf(player)
	return root ~= nil
		and prey(player :: Player)
		and flat(root.Position - wild.Enemy.Home).Magnitude <= Frontier.Wander.Seal * 1.4
end

-- Roaming round its rift: a new spot within Roam every few seconds.
local function roam(enemy, wild: Wild, now: number)
	if now < (wild.RoamAt or 0) then
		return
	end
	wild.RoamAt = now + rng:NextNumber(2.5, 4.5)
	local angle = rng:NextNumber(0, math.pi * 2)
	local reach = rng:NextNumber(4, wild.Wander.Roam)
	enemy.Humanoid:MoveTo(enemy.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach)
end

-- A wild kaiju's day ---------------------------------------------------------------------------------------

-- What it's doing, for every client to pose (CreatureMotion: KaijuMood and
-- KaijuMoodAt on its model; walking is no mood).
local function setMood(wild: Wild, mood: string?)
	local model = wild.Enemy.Model
	local shown = if mood == "Walk" then nil else mood
	if model:GetAttribute("KaijuMood") ~= shown then
		model:SetAttribute("KaijuMood", shown)
		model:SetAttribute("KaijuMoodAt", serverNow())
	end
end

-- It does `mood` for `seconds`, turned to `facing` if given.
local function startPlan(wild: Wild, mood: string, seconds: number, now: number, facing: Vector3?)
	local root = wild.Enemy.Root
	if facing and flat(facing - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(facing.X, root.Position.Y, facing.Z))
	end
	wild.Plan = { Mood = mood, Until = now + seconds }
	setMood(wild, mood)
	return wild.Plan
end

-- Nothing solid in the way from `from` to `to`, about its knee height (a
-- mast, a container, a rock: Roblox's Spherecast; with none to ask, clear).
local function clearPath(wild: Wild, from: Vector3, to: Vector3): boolean
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { wild.Enemy.Model }
		for _, name in { "Enemies", "Kaiju", "Rifts" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				table.insert(skip, folder)
			end
		end
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(skip, player.Character)
			end
		end
		params.FilterDescendantsInstances = skip
		local lift = Vector3.new(0, 1.5, 0)
		local way = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		return workspace:Spherecast(from + lift, 1.5, way, params)
	end)
	return not ok or hit == nil or not hit.Instance.CanCollide
end

-- Somewhere to amble to: round its den (a packmate keeps near its leader),
-- with a clear way there.
local function walkTarget(wild: Wild, range: number): Vector3?
	local enemy = wild.Enemy
	local pack = wild.Pack
	local leader = pack and pack.Members[1]
	local around, reach = enemy.Home, range
	if leader and leader ~= wild and leader.Enemy.Alive then
		around, reach = leader.Enemy.Root.Position, 10
	end
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * reach
		local p = Vector3.new(around.X + math.cos(a) * r, enemy.Home.Y, around.Z + math.sin(a) * r)
		local fits = flat(p - enemy.Home).Magnitude <= range + 4 and roomy(p, wild.Guard)
		if fits and clearPath(wild, enemy.Root.Position, p) then
			return p
		end
	end
	return nil
end

-- Its pack's leader, if it's a packmate following one (and how far off).
local function leaderOf(wild: Wild): (Wild?, number)
	local pack = wild.Pack
	local leader = pack and pack.Members[1]
	if not leader or leader == wild or not leader.Enemy.Alive then
		return nil, 0
	end
	return leader, flat(leader.Enemy.Root.Position - wild.Enemy.Root.Position).Magnitude
end

-- The next thing it does (Kaiju.Roam's moods, by chance; a packmate left
-- behind catches up first).
local function nextPlan(wild: Wild, rules, now: number)
	local mood = Kaiju.mood(rules.Moods, rng:NextNumber())
	local leader, behind = leaderOf(wild)
	if leader and behind > 14 then
		mood = "Walk"
	end
	local times = rules.Times[mood]
	local seconds = rng:NextNumber(times[1], times[2])
	if mood == "Walk" then
		local to = walkTarget(wild, rules.Range)
		if not to then
			return startPlan(wild, "Look", 2, now)
		end
		local plan = startPlan(wild, "Walk", seconds, now)
		plan.To, plan.From, plan.Check = to, wild.Enemy.Root.Position, now
		return plan
	end
	return startPlan(wild, mood, seconds, now)
end

-- The nearest player within `radius` of `at` who's about in the Outpost.
local function playerNear(at: Vector3, radius: number): (Player?, BasePart?)
	local best, bestRoot, bestDistance = nil, nil, radius
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and player:GetAttribute("Outpost") == true then
			local distance = flat(root.Position - at).Magnitude
			if distance <= bestDistance then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
end

-- A pack's den moves on now and then (its leader decides): Kaiju.Roam.Drift
-- studs on, roughly the way it was heading, staying out in the frontier and
-- away from the other dens.
local function driftDen(pack: Pack, now: number)
	local roam = Kaiju.Roam
	pack.MoveAt = now + rng:NextNumber(roam.Every[1], roam.Every[2])
	for try = 0, 11 do
		local heading = pack.Heading + rng:NextNumber(-0.7, 0.7) + try * math.pi / 6
		local step = rng:NextNumber(roam.Drift[1], roam.Drift[2])
		local den = pack.Den + Vector3.new(math.cos(heading), 0, math.sin(heading)) * step
		local apart = roomy(den)
		for _, other in packs do
			if other ~= pack and flat(other.Den - den).Magnitude < 80 then
				apart = false
			end
		end
		if apart then
			pack.Den, pack.Heading = den, heading
			for _, member in pack.Members do
				local home = member.Enemy.Home
				member.Enemy.Home = Vector3.new(den.X, home.Y, den.Z)
			end
			return
		end
	end
end

-- Nobody's fighting it: it wanders round its den, stops to sniff, look
-- about, lie down or roar (the guardian paces in front of its vein and
-- mostly sleeps), and stops to look at anyone who comes close.
local function wander(enemy, wild: Wild, now: number)
	local rules = if wild.Guard then Kaiju.Roam.Guard else Kaiju.Roam
	local humanoid, root = enemy.Humanoid, enemy.Root
	local pack = wild.Pack
	if pack and pack.Members[1] == wild and now >= pack.MoveAt then
		driftDen(pack, now)
	end
	local plan = wild.Plan
	-- Someone close (and it awake): it stops and looks them over; now and
	-- then it roars at them.
	if not (plan and (plan.Mood == "Sleep" or plan.Mood == "Roar")) then
		local player, theirRoot = playerNear(root.Position, Kaiju.Roam.Notice)
		local noticed = wild.Noticed or {}
		wild.Noticed = noticed
		if player and theirRoot and now - (noticed[player] or -math.huge) > 12 then
			for gone in noticed do
				if gone.Parent == nil then
					noticed[gone] = nil -- (they left the game)
				end
			end
			noticed[player] = now
			local roar = now - (wild.GrowlAt or -math.huge) >= Kaiju.Roam.Growl and rng:NextNumber() < 0.5
			if roar then
				wild.GrowlAt = now
			end
			plan = startPlan(wild, if roar then "Roar" else "Look", if roar then 1.6 else 3, now, theirRoot.Position)
		end
	end
	-- A packmate whose leader has wandered off gets up and follows.
	local _, behind = leaderOf(wild)
	if plan and behind > 26 and plan.Mood ~= "Walk" and plan.Mood ~= "Roar" then
		plan.Until = now
	end
	if not plan or now >= plan.Until then
		plan = nextPlan(wild, rules, now)
	end
	if plan.Mood ~= "Walk" then
		humanoid:MoveTo(root.Position)
		return
	end
	local to = plan.To
	if flat(to - root.Position).Magnitude < 3 then
		plan.Until = now -- (there: something else next)
		humanoid:MoveTo(root.Position)
		return
	end
	humanoid.WalkSpeed *= Kaiju.Roam.Amble
	humanoid:MoveTo(to)
	-- Hardly moved in two seconds (a rock in the way): somewhere else.
	if now - plan.Check >= 2 then
		if flat(root.Position - plan.From).Magnitude < 1 then
			plan.Until = now
		end
		plan.From, plan.Check = root.Position, now
	end
end
KaijuWilds._wander = wander

-- The brain both kinds share: find a foe and fight it (a wild kaiju as a
-- duellist, KaijuFighter; a moon bug chases and bites), else go home (a
-- rift's critter slips back through a rift).
local tameStep -- (a tame's tick: Taming, below)

local function brain(enemy, now: number)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	local e = enemy :: any
	local humanoid, root = enemy.Humanoid, enemy.Root
	local fighter = wild.Fighter
	-- Held by a tame: nothing else till it's over.
	if wild.Taming then
		e.FoeVictim, e.Foe = nil, nil
		tameStep(enemy, wild, now)
		return
	end
	if now < enemy.StunUntil and not fighter then
		humanoid:MoveTo(root.Position)
		return
	end
	local kind = enemy.Kind
	humanoid.WalkSpeed = kind.Speed * (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
	if wild.Leaving then
		humanoid:MoveTo(root.Position)
		return
	end
	if not wild.Bug and root.Position.Y < enemy.Home.Y - 40 then
		-- (Fallen through the floor: back up at its den.)
		enemy.Model:PivotTo(CFrame.new(enemy.Home + Vector3.new(0, 4, 0)))
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end
	local fromHome = flat(root.Position - enemy.Home).Magnitude
	local leash = if wild.Bug then Kaiju.Bug.Leash else Kaiju.Wild.Leash
	local victim = if fromHome <= leash then chooseFoe(enemy, wild, kind.Aggro) else nil
	e.FoeVictim = victim
	e.Foe = if victim then (victim.Pet or victim.Player) else nil
	if wild.Bug and now - wild.Born > (wild.Life or Frontier.Life) then
		slipBack(wild) -- (no critter stays for good)
		return
	end
	if not victim and wild.Bug and wild.Wander and lingers(wild) then
		-- Out of a wandering rift, its player still about: it roams its patch.
		wild.IdleSince = nil
		roam(enemy, wild, now)
		return
	end
	if not victim and wild.Bug then
		-- Nobody to fight: a moment's sniffing about, then back where it came from.
		wild.IdleSince = wild.IdleSince or now
		humanoid:MoveTo(root.Position)
		if now - wild.IdleSince >= Frontier.Leave then
			slipBack(wild)
		end
		return
	end
	wild.IdleSince = nil
	if not victim then
		if fighter then
			KaijuFighter.calm(fighter)
			if now < enemy.StunUntil then
				humanoid:MoveTo(root.Position)
				return
			end
		end
		-- Led off: back home, healing on the way. Home a while, it forgets
		-- who started on it, and goes about its day (wander).
		local range = if wild.Guard then Kaiju.Roam.Guard.Range else Kaiju.Roam.Range
		if fromHome > range + 6 then
			if wild.Plan then
				wild.Plan = nil
				setMood(wild, nil)
			end
			humanoid:MoveTo(enemy.Home)
		else
			local awake = next(wild.Engaged) ~= nil
			for player, at in wild.Engaged do
				if now - at > CALM_AFTER then
					wild.Engaged[player] = nil
				end
			end
			if wild.Guard and awake and next(wild.Engaged) == nil then
				wild.Swings = 0 -- (back to sleep)
			end
			wander(enemy, wild, now)
		end
		if now - enemy.LastHit > 6 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * HOME_HEAL * 0.15)
			enemy.Bar.Size = UDim2.fromScale(humanoid.Health / humanoid.MaxHealth, 1)
		end
		return
	end
	wild.LastFight = now
	engage(wild, if victim.Pet then victim.Pet.Owner else victim.Player, now)
	if wild.Plan then
		wild.Plan = nil -- (its day can wait)
		setMood(wild, nil)
	end
	if fighter then
		KaijuFighter.step(fighter, victim, now)
		return
	end
	local reach = kind.Reach + victim.Root.Size.X / 2
	local distance = flat(victim.Root.Position - root.Position).Magnitude
	if distance > reach then
		humanoid:MoveTo(victim.Root.Position)
		return
	end
	humanoid:MoveTo(root.Position)
	local at = root.Position
	local look = Vector3.new(victim.Root.Position.X, at.Y, victim.Root.Position.Z)
	if (look - at).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(at, look)
	end
	if now - enemy.LastAttack >= kind.Rate then
		enemy.LastAttack = now
		enemy.Model:SetAttribute("ActionAt", serverNow())
		fx("EnemySwing", root.Position, victim.Root.Position, GemConfig.ElementColors[wild.Element])
		if now < (e.BlindUntil or 0) and math.random() < (e.Blind or 0) then
			return -- swung at nothing
		end
		local outcome = hitFoe(enemy, victim, kind.Damage * (1 - Enemies.weakness(enemy)), wild.Element, nil, false)
		if outcome == "Parried" then
			Enemies.addStatus(enemy, "Stun", 1, KaijuFight.ParryStagger) -- (a kaiju's guard turned its bite)
		end
	end
end

-- Who did the most to it: players' own blows (Enemies' Damage) and their
-- kaiju's (KaijuCredit), together. Returns the best and everyone's totals.
local function credits(enemy): (Player?, { [Player]: number })
	local totals = {}
	for player, amount in enemy.Damage do
		totals[player] = (totals[player] or 0) + amount
	end
	for player, amount in (enemy :: any).KaijuCredit or {} do
		totals[player] = (totals[player] or 0) + amount
	end
	local best, most = nil, 0
	for player, amount in totals do
		if player.Parent and amount > most then
			best, most = player, amount
		end
	end
	return best, totals
end

-- Pay ----------------------------------------------------------------------------------------------------

-- Today's critter tally on a roster (Bugs = { Day, Coins, Count }), fresh each day.
local function tally(roster)
	local day = math.floor(os.time() / 86400)
	if not roster.Bugs or roster.Bugs.Day ~= day then
		roster.Bugs = { Day = day, Coins = 0, Count = 0 }
	end
	roster.Bugs.Count = roster.Bugs.Count or 0
	return roster.Bugs
end
KaijuWilds._tally = tally

-- Coins for a critter (or a guardian), within the day's cap.
local function payCoins(player: Player, amount: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local bugs = tally(Kaiju.roster(profile))
	local coins = math.min(amount, Kaiju.bugCoins(bugs, bugs.Day))
	if coins > 0 then
		bugs.Coins += coins
		PlayerData.addCoins(player, coins)
	end
end

-- Wild kaiju ------------------------------------------------------------------------------------------

local spawnWild

-- Killed, tamed or burrowed: another roams out a while later (`soon`, after
-- a burrow: Kaiju.Wild.Return; the guardian has none: a fresh one sleeps at
-- its vein once it moves).
local function gone(wild: Wild, soon: boolean?)
	if wild.Taming then
		-- (Gone mid-tame, its vein moving or its time up: the tamer hears.)
		local player = wild.Taming.Player
		wild.Taming = nil
		player:SetAttribute("TameResult", "Interrupted")
		player:SetAttribute("TameResultAt", workspace:GetServerTimeNow())
	end
	KaijuFighter.forget(wild.Fighter)
	wilds[wild.Enemy] = nil
	local pack = wild.Pack
	if pack then
		local at = table.find(pack.Members, wild)
		if at then
			table.remove(pack.Members, at)
		end
		if #pack.Members == 0 then
			local index = table.find(packs, pack)
			if index then
				table.remove(packs, index)
			end
		end
	end
	if wild.Guard then
		if guardian == wild then
			guardian = nil
		end
		return
	end
	wildCount -= 1
	task.delay(if soon then Kaiju.Wild.Return else Kaiju.Wild.Respawn, spawnWild)
end

-- Burrows away (left alone too long, or too many failed tames).
local function burrow(wild: Wild)
	local enemy = wild.Enemy
	if not enemy.Alive then
		return
	end
	fx("TriadBreak", enemy.Root.Position, 5, wild.Element)
	Enemies.remove(enemy)
	gone(wild, true)
end

local function wildDied(enemy)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	local best, totals = credits(enemy)
	local title = Kaiju.title({ Species = wild.Species, Element = wild.Element })
	for player, amount in totals do
		if player.Parent and amount > 0 then
			KaijuServer.reward(player, Kaiju.killExp(wild.Level))
		end
	end
	if best then
		local soul = table.clone(wild.Soul)
		soul.Id = PlayerData.newGemId()
		soul.Found = os.time()
		if PlayerData.addGem(best, soul) then
			local move = GemTraits.Moves[Kaiju.ability(soul) or ""]
			Remotes.Notify:FireClient(
				best,
				string.format(
					"Defeated %s %s: its Gemsoul is yours (%s, E: %s).",
					if wild.Guard then "the vein's guardian, a" else "a wild",
					title,
					GemConfig.displayName(soul),
					if move then move.Name else "?"
				)
			)
		else
			Remotes.Notify:FireClient(best, "Your gem pouch is full: the Gemsoul crumbled to dust.")
		end
		PlayerData.milestone(best, "KaijuSlain")
		if wild.Guard then
			payCoins(best, Frontier.Coins.Guardian)
		end
	end
	gone(wild)
end

-- A wild kaiju at `at` (on the ground there), its `level`, turned to
-- `facing` (any way, if not given), of `species` (any, if not given);
-- `guard`, the guarded vein's (bigger).
local function newWild(at: Vector3, level: number, guard: boolean, facing: Vector3?, species: string?): Wild
	species = species or Kaiju.Order[rng:NextInteger(1, #Kaiju.Order)]
	local element = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
	local scale = if guard then Kaiju.Scale.Guardian else Kaiju.Scale.Wild
	local soul = Kaiju.rollSoul(Gems.random(), element, {
		Id = "wild",
		Time = os.time(),
		Species = species,
		Luck = math.clamp(level / 60, 0, 0.5),
	})
	local stats = Kaiju.stats(species, level, soul.Tier)
	local model, _, _ = KaijuServer.body(species, element, scale)
	local named = Kaiju.title({ Species = species, Element = element })
	local title = (if guard then "Vein Guardian " else "Wild ") .. named
	model.Name = title
	KaijuServer.place(model, at, facing or at + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
	local kind = {
		Name = title,
		Health = math.floor(stats.Health * Kaiju.Wild.Health + 0.5),
		Damage = stats.Damage,
		Speed = stats.Speed,
		Reach = stats.Reach,
		Rate = stats.Rate,
		Aggro = Kaiju.Wild.Aggro,
		Coins = 0,
		DropChance = 0,
		Luck = 0,
		Respawn = 0,
	}
	local enemy = Enemies.adopt(
		model,
		kind,
		{ Element = element, Title = string.format("%s · Lv %d", title, level), Home = model.PrimaryPart.Position }
	)
	local e = enemy :: any
	local engagedBy = {}
	-- (Its name over it from further off than a creature's: they roam far.)
	local board = enemy.Root:FindFirstChild("HealthBar")
	if board and board:IsA("BillboardGui") then
		board.MaxDistance = 160
	end
	e.OutpostCreature = true
	e.Engaged = engagedBy -- (the kaiju out only fight it for those who started on it)
	e.Brain = brain
	e.OnDeath = wildDied
	-- Every blow lands 60%-140%, times its element against this one's
	-- and its kind's Guard.
	e.TakenScale = function(hitElement: string?)
		local held = wilds[enemy]
		if held and held.Taming then
			return 0, nil -- (held by a tame: nothing hurts it)
		end
		local mult, tag = Kaiju.taken(species, element, hitElement)
		return mult * Kaiju.spread(), tag
	end
	-- Its R's shell or ward takes its share of a blow (Enemies.damage).
	e.Soak = function(amount: number): number
		return KaijuAbilities.soak(enemy, amount)
	end
	local ability = Kaiju.ability(soul)
	local moves = Kaiju.moves(soul, level)
	model:SetAttribute("KaijuWild", true)
	model:SetAttribute("KaijuLevel", level)
	model:SetAttribute("KaijuAbility", ability)
	model:SetAttribute("KaijuQ", moves.Q)
	model:SetAttribute("KaijuR", moves.R)
	model:SetAttribute("KaijuTries", 0)
	if guard then
		model:SetAttribute("KaijuGuardian", true)
	end
	-- It leaves you be until you start on it: here, or by hitting it.
	local challenge = Instance.new("ProximityPrompt")
	challenge.Name = "ChallengePrompt"
	challenge.ActionText = "Challenge"
	challenge.ObjectText = string.format("%s · Lv %d", title, level)
	challenge.KeyboardKeyCode = Enum.KeyCode.E
	challenge.HoldDuration = 0.5
	challenge.MaxActivationDistance = 16
	challenge.RequiresLineOfSight = false
	challenge:SetAttribute("PromptKind", "KaijuChallenge")
	challenge.Parent = enemy.Root
	-- It fights as a duellist, its guard and hops on its Enemies record
	-- (so a hunter's swings meet them in Enemies.damage).
	local fighter = KaijuFighter.new({
		Model = model,
		Root = enemy.Root,
		Humanoid = enemy.Humanoid,
		Species = species,
		Element = element,
		Scale = scale,
		Body = enemy,
		Stats = stats,
		Ability = ability,
		Moves = moves,
		FirstSurge = 4,
		Strike = function(victim, amount: number, heavy: boolean, _name: string): string
			return hitFoe(enemy, victim, amount * (1 - Enemies.weakness(enemy)), element, nil, heavy)
		end,
		Caster = function()
			return {
				Model = model,
				Root = enemy.Root,
				Element = element,
				Ability = ability,
				Damage = Kaiju.abilityDamage(stats.Damage, soul, ability),
				DamageOf = function(id: string): number
					return Kaiju.abilityDamage(stats.Damage, soul, id)
				end,
				Body = enemy,
				Humanoid = enemy.Humanoid,
				Foes = function(center: Vector3, radius: number)
					local wild = wilds[enemy]
					return if wild then foesOf(wild)(center, radius) else {}
				end,
				Hit = function(target, amount: number, status: string?)
					hitFoe(enemy, target, amount, element, status, nil)
				end,
				Alive = function(): boolean
					return enemy.Alive
				end,
			}
		end,
	})
	local wild: Wild = {
		Enemy = enemy,
		Species = species,
		Element = element,
		Level = level,
		Soul = soul,
		Ability = ability,
		Born = os.clock(),
		Tries = 0,
		TameAt = {},
		Fighter = fighter,
		Bug = false,
		Engaged = engagedBy,
		Guard = guard,
		Swings = 0,
		-- (Each its own, so they don't all burrow at once and leave the quarry empty.)
		Lifetime = Kaiju.Wild.Lifetime * rng:NextNumber(0.7, 1.5),
	}
	wilds[enemy] = wild
	return wild
end

-- A pack with room for one more, or a new one with a den of its own out in
-- the frontier (away from the other dens and the guarded vein).
local function packFor(): Pack?
	for _, pack in packs do
		if #pack.Members < Kaiju.Wild.Pack then
			return pack
		end
	end
	local middle = Outpost.Location.Position
	for _ = 1, 80 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(Frontier.Core + 30, Frontier.Rim - 45)
		local den = middle + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local apart = roomy(den)
		for _, other in packs do
			if flat(other.Den - den).Magnitude < 110 then
				apart = false
			end
		end
		if apart then
			-- (A kind no other pack is, if there's one.)
			local kinds = {}
			for _, species in Kaiju.Order do
				local taken = false
				for _, other in packs do
					taken = taken or other.Species == species
				end
				if not taken then
					table.insert(kinds, species)
				end
			end
			kinds = if #kinds > 0 then kinds else Kaiju.Order
			local roam = Kaiju.Roam
			local pack: Pack = {
				Den = den,
				Heading = rng:NextNumber(0, math.pi * 2),
				MoveAt = os.clock() + rng:NextNumber(roam.Every[1], roam.Every[2]),
				Species = kinds[rng:NextInteger(1, #kinds)],
				Members = {},
			}
			table.insert(packs, pack)
			return pack
		end
	end
	return nil
end

function spawnWild()
	if wildCount >= Kaiju.Wild.Max then
		return
	end
	local pack = packFor()
	if not pack then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local at = pack.Den + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 9)
	wildCount += 1
	local ok, err = pcall(function()
		local wild = newWild(at, Kaiju.wildLevel(levelsNear(at, 160), rng), false, nil, pack.Species)
		wild.Pack = pack
		local home = wild.Enemy.Home
		wild.Enemy.Home = Vector3.new(pack.Den.X, home.Y, pack.Den.Z)
		table.insert(pack.Members, wild)
	end)
	if not ok then
		wildCount -= 1
		warn("[Kaiju] wild spawn failed:", err)
	end
end

-- The vein guardian -----------------------------------------------------------------------------------------

local function spawnGuardian()
	if guardian or not guardAt then
		return
	end
	local levels = Frontier.Guardian.Levels
	local ok, err = pcall(function()
		local at, facing = guardHome(guardAt :: CFrame)
		guardian = newWild(at, rng:NextInteger(levels[1], levels[2]), true, facing)
	end)
	if not ok then
		warn("[Kaiju] vein guardian spawn failed:", err)
	end
end

-- A swing at vein `index`'s rocks: the guardian (if this is its vein)
-- wakes on the Frontier.Guardian.Wake'th since it last slept (a stray swing
-- long ago doesn't count), and once awake whoever mines its vein is on its
-- list.
function KaijuWilds.veinSwing(index: number, player: Player)
	local wild = guardian
	if index ~= Frontier.Veins.Guarded or not wild or not wild.Enemy.Alive then
		return
	end
	local now = os.clock()
	if next(wild.Engaged) ~= nil then
		engage(wild, player, now)
		return
	end
	if now - (wild.SwingAt or now) > 30 then
		wild.Swings = 0
	end
	wild.Swings = (wild.Swings or 0) + 1
	wild.SwingAt = now
	-- It stirs and looks round at the first, growls at the next, and the
	-- third wakes it.
	local root = rootOf(player)
	local at = if root then root.Position else nil
	if wild.Swings == Frontier.Guardian.Wake - 2 then
		startPlan(wild, "Look", 4, now, at)
	elseif wild.Swings == Frontier.Guardian.Wake - 1 then
		wild.GrowlAt = now
		startPlan(wild, "Roar", 1.6, now, at)
	end
	if wild.Swings >= Frontier.Guardian.Wake then
		engage(wild, player, now)
		wild.LastFight = now
		wild.Enemy.Model:SetAttribute("ActionAt", serverNow())
		Remotes.Notify:FireClient(player, "The vein's guardian woke up!")
	end
end

-- Vein `index` surfaced at `scar`: if it's the guarded one, whatever's left
-- of its guardian goes, and a fresh one sleeps at the new site.
function KaijuWilds.veinMoved(index: number, scar: CFrame)
	if index ~= Frontier.Veins.Guarded then
		return
	end
	guardAt = scar
	-- (A pack denned near the vein's new site moves on.)
	local home = guardHome(scar)
	for _, pack in packs do
		if flat(pack.Den - home).Magnitude < 90 then
			pack.MoveAt = 0
		end
	end
	local old = guardian
	if old and old.Enemy.Alive then
		fx("TriadBreak", old.Enemy.Root.Position, 5, old.Element)
		Enemies.remove(old.Enemy)
	end
	if old then
		gone(old)
	end
	spawnGuardian()
end

-- Taming --------------------------------------------------------------------------------------------------

-- Who's casting a tame on which: one at a time each.
local function tamingOf(player: Player): Wild?
	for _, wild in wilds do
		if wild.Taming and wild.Taming.Player == player then
			return wild
		end
	end
	return nil
end

-- How a tame ended, for the tamer's screen: their TameResult ("Tamed",
-- "Broke", "Fled" or "Interrupted") at TameResultAt (server time).
local function tell(player: Player, text: string)
	if player.Parent then
		Remotes.Notify:FireClient(player, text)
	end
end

local function tameResult(player: Player, result: string)
	if player.Parent then
		player:SetAttribute("TameResult", result)
		player:SetAttribute("TameResultAt", serverNow())
	end
end

-- The cast over, either way: it's let go.
local function release(wild: Wild)
	wild.Taming = nil
	local model = wild.Enemy.Model
	model:SetAttribute("KaijuTameBy", nil)
	model:SetAttribute("KaijuTameEnds", nil)
	setMood(wild, nil)
end

-- The cast's end: the roll (tameChance at its health now).
local function resolveTame(enemy, wild: Wild, player: Player, now: number)
	local humanoid = enemy.Humanoid
	local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
	release(wild)
	wild.TameAt[player] = now -- (a moment before the next try)
	local title = Kaiju.title({ Species = wild.Species, Element = wild.Element })
	local profile = PlayerData.get(player)
	if not profile or Kaiju.count(Kaiju.roster(profile)) >= Kaiju.MaxOwned then
		tell(player, string.format("You can keep %d kaiju: let one go first.", Kaiju.MaxOwned))
		tameResult(player, "Interrupted")
		return
	end
	if rng:NextNumber() < chance then
		local soul = table.clone(wild.Soul)
		soul.Id = PlayerData.newGemId()
		local record = KaijuServer.adopt(player, wild.Species, soul, wild.Level)
		if not record then
			tell(player, "Couldn't tame it right now.")
			tameResult(player, "Interrupted")
			return
		end
		fx("TriadBreak", enemy.Root.Position, 6, wild.Element)
		Enemies.remove(enemy)
		gone(wild)
		PlayerData.milestone(player, "KaijuTamed")
		tell(player, string.format("Tamed! The %s (level %d) is yours.", title, wild.Level))
		tameResult(player, "Tamed")
		return
	end
	wild.Tries += 1
	enemy.Model:SetAttribute("KaijuTries", wild.Tries)
	if wild.Tries >= Kaiju.TameTries then
		burrow(wild)
		tell(player, string.format("The %s broke free and burrowed away!", title))
		tameResult(player, "Fled")
		return
	end
	local left = Kaiju.TameTries - wild.Tries
	tell(
		player,
		string.format(
			"It broke free! (%d%% chance) %d tr%s left.",
			math.floor(chance * 100 + 0.5),
			left,
			if left == 1 then "y" else "ies"
		)
	)
	tameResult(player, "Broke")
end

-- A tick of a cast (its brain's): held still, struggling, turned to its
-- tamer; broken if they stray past Tame.Break, are hit or go; the roll at
-- its end.
function tameStep(enemy, wild: Wild, now: number)
	local taming = wild.Taming
	local player = taming.Player
	local root = rootOf(player)
	local body = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	local broke = nil
	if not player.Parent or not root or not body or body.Health <= 0 or player:GetAttribute("Outpost") ~= true then
		broke = "The tame broke."
	elseif flat(root.Position - enemy.Root.Position).Magnitude > Kaiju.Tame.Break then
		broke = "Too far away: the tame broke."
	elseif body.Health < taming.Health - 0.5 then
		broke = "You were hit: the tame broke."
	end
	if broke then
		release(wild)
		wild.TameAt[player] = now
		tell(player, broke)
		tameResult(player, "Interrupted")
		return
	end
	taming.Health = body.Health -- (healing up meanwhile is fine)
	wild.LastFight = now -- (a tame counts as a fight: it won't burrow of old age mid-cast)
	local at = enemy.Root.Position
	local look = Vector3.new(root.Position.X, at.Y, root.Position.Z)
	if flat(look - at).Magnitude > 0.5 then
		enemy.Root.CFrame = CFrame.lookAt(at, look)
	end
	if now >= taming.Ends then
		resolveTame(enemy, wild, player, now)
	end
end

-- "KaijuTame": start a tame on a weakened wild kaiju (within Tame.Range).
-- It's a cast (Kaiju.Tame): the kaiju is held, struggling, untouchable,
-- for Tame.Cast seconds, then the roll; the tamer hears how it went
-- (Notify, and TameResult on them).
local function tame(player: Player, model: any)
	local enemy = typeof(model) == "Instance" and Enemies.get(model) or nil
	local wild = enemy and wilds[enemy]
	if not wild or wild.Bug or not enemy.Alive then
		return reply(false, "There's no wild kaiju there to tame.")
	end
	local root = rootOf(player)
	if not root or player:GetAttribute("Outpost") ~= true then
		return reply(false, "Not right now.")
	end
	if (root.Position - enemy.Root.Position).Magnitude > TAME_RANGE then
		return reply(false, "Get closer to tame it.")
	end
	if wild.Taming then
		return reply(
			false,
			if wild.Taming.Player == player then "Hold steady: you're taming it." else "Someone's taming that one."
		)
	end
	if tamingOf(player) then
		return reply(false, "You're already taming one.")
	end
	local now = os.clock()
	local last = wild.TameAt[player]
	if last and now - last < Kaiju.TameCooldown then
		return reply(false, "Steady... try again in a moment.")
	end
	local humanoid = enemy.Humanoid
	local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
	if chance <= 0 then
		return reply(false, "Wear it down to half its health first, without killing it.")
	end
	local profile = PlayerData.get(player)
	if not profile or Kaiju.count(Kaiju.roster(profile)) >= Kaiju.MaxOwned then
		return reply(false, string.format("You can keep %d kaiju: let one go first.", Kaiju.MaxOwned))
	end
	local body = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	wild.TameAt[player] = now
	wild.Taming = { Player = player, Ends = now + Kaiju.Tame.Cast, Health = if body then body.Health else 0 }
	wild.Plan = nil
	if wild.Fighter then
		KaijuFighter.calm(wild.Fighter)
	end
	setMood(wild, "Bound")
	enemy.Model:SetAttribute("KaijuTameBy", player.UserId)
	enemy.Model:SetAttribute("KaijuTameEnds", serverNow() + Kaiju.Tame.Cast)
	humanoid:MoveTo(enemy.Root.Position)
	return reply(true, "", { Casting = true, Seconds = Kaiju.Tame.Cast, Chance = chance })
end

-- "KaijuChallenge": start a fight with a wild kaiju, with your kaiju out (it
-- goes in) or hunting.
local function challenge(player: Player, model: any)
	local enemy = typeof(model) == "Instance" and Enemies.get(model) or nil
	local wild = enemy and wilds[enemy]
	if not wild or wild.Bug or not enemy.Alive then
		return reply(false, "There's no wild kaiju there.")
	end
	local root = rootOf(player)
	if
		not root
		or player:GetAttribute("Outpost") ~= true
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
	then
		return reply(false, "Not right now.")
	end
	if (root.Position - enemy.Root.Position).Magnitude > CHALLENGE_RANGE then
		return reply(false, "Get closer to challenge it.")
	end
	local pet = KaijuServer.pets()[player]
	if not (pet and KaijuServer.targetable(pet)) and not hunter(player) then
		return reply(false, "Your kaiju needs to be out to fight it (or press HUNT).")
	end
	local now = os.clock()
	engage(wild, player, now)
	wild.LastFight = now
	local title = Kaiju.title({ Species = wild.Species, Element = wild.Element })
	return reply(true, string.format("You challenged the wild %s!", title))
end

-- Moon bugs -------------------------------------------------------------------------------------------------

local Duelist -- (required when the first moon bug comes through: it's a big module)

local function bugDied(enemy)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	wilds[enemy] = nil
	local best, totals = credits(enemy)
	local band = wild.Band or "Fringe"
	-- EXP to every kaiju that fought it (a kaiju left at home earns none: a
	-- pick's or a hunter's kill pays coins, not EXP), less after the day's
	-- first Frontier.Exp.Daily.
	for player, amount in (enemy :: any).KaijuCredit or {} do
		local profile = player.Parent and amount > 0 and PlayerData.get(player)
		if profile then
			local bugs = tally(Kaiju.roster(profile))
			KaijuServer.reward(player, Frontier.critterExp(wild.Level, band, bugs.Count))
			bugs.Count += 1
		end
	end
	if best then
		payCoins(best, Frontier.Coins[band] or Frontier.Coins.Fringe)
	end
	KaijuWilds.done(enemy, true, totals)
end

-- What comes through the next rift: a roster id (its rift crackles with it).
function KaijuWilds.pickCritter(r): string
	local roll = r or rng
	return DungeonRules.Roster[roll:NextInteger(1, #DungeonRules.Roster)].Id
end

local function rosterSpec(id: string?)
	for _, spec in DungeonRules.Roster do
		if spec.Id == id then
			return spec
		end
	end
	return nil
end

-- A rift's critter (not a wild kaiju).
function KaijuWilds.isCritter(enemy): boolean
	local wild = enemy and wilds[enemy]
	return wild ~= nil and wild.Bug
end

-- The rift's critter a model is, if it is one.
function KaijuWilds.critterOf(model: Instance)
	local enemy = if model:IsA("Model") then Enemies.get(model) else nil
	return if enemy and KaijuWilds.isCritter(enemy) then enemy else nil
end

-- A pickaxe's bonk on a rift's critter (OutpostServer checks who swung and
-- from where): Frontier.Bonk.Share of its health, credited to `player`, and
-- knocked back from `from`, reeling a moment. Returns whether it landed.
function KaijuWilds.bonk(enemy, player: Player, from: Vector3): boolean
	local wild = enemy and wilds[enemy]
	if not wild or not wild.Bug or not enemy.Alive then
		return false
	end
	local root = enemy.Root
	local away = flat(root.Position - from)
	away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
	Enemies.damage(enemy, enemy.Humanoid.MaxHealth * Frontier.Bonk.Share, player, false, Color3.fromRGB(255, 220, 140))
	fx("BlockSpark", root.Position, false)
	if enemy.Alive then
		-- (Back about Knock studs, and it gathers itself before it bites again.)
		root.AssemblyLinearVelocity = away * Frontier.Bonk.Knock * 3 + Vector3.new(0, 14, 0)
		Enemies.addStatus(enemy, "Stun", 1, 0.35)
		enemy.LastAttack = os.clock()
	end
	return true
end

-- A moon bug out of a rift at `at` (its foot, on the ground). `opts` = {
--   Prey     the player who drew the rift: it goes for them first
--   Band     where the rift opened (Shared.Frontier.Boost: the edge's are tougher)
--   Critter  which one (a roster id; any, if not given)
--   Level    its level (Frontier.critterLevel of its band, if not given)
--   Facing   a point it turns to (its prey)
--   Hop      its leap out of the tear (a velocity)
--   Wander   out of a wandering rift: { Home, Roam, Notice }: it roams there
--   Life     seconds before it slips back (Frontier.Life)
-- }
function KaijuWilds.spawnBug(at: Vector3, opts)
	Duelist = Duelist or require(script.Parent.Duelist)
	local spec = rosterSpec(opts.Critter) or DungeonRules.Roster[rng:NextInteger(1, #DungeonRules.Roster)]
	local band = opts.Band or "Fringe"
	local level = opts.Level or Frontier.critterLevel(band, rng)
	local grow = 1 + Kaiju.Growth * (level - 1)
	local boost = Frontier.Boost[band] or Frontier.Boost.Fringe
	local ok, result = pcall(function()
		local color = GemConfig.ElementColors[spec.Element] or Color3.new(1, 1, 1)
		local rig = Duelist.creatureBody(spec, color)
		rig:ScaleTo(Kaiju.Bug.Scale)
		for _, joint in rig:GetDescendants() do
			if joint:IsA("Motor6D") and joint:GetAttribute("CreatureMotion") then
				joint:SetAttribute("CreatureRest", joint.C0)
			end
		end
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.HipHeight = 1.9 * Kaiju.Bug.Scale
		local foot = at + Vector3.new(0, humanoid.HipHeight + 1, 0)
		local facing = opts.Facing or (at + Vector3.new(0, 0, -1))
		local look = Vector3.new(facing.X, foot.Y, facing.Z)
		rig:PivotTo(if (look - foot).Magnitude > 0.1 then CFrame.lookAt(foot, look) else CFrame.new(foot))
		rig.Name = "Moon Bug"
		rig:SetAttribute("Posed", true) -- clients pose its body (BodyPoses)
		rig:SetAttribute("MoonBug", true)
		rig:SetAttribute("RiftBorn", true)
		rig:SetAttribute("CritterLevel", level)
		local kind = {
			Name = "Moon Bug",
			Health = math.floor(Kaiju.Bug.Health * grow * boost.Health + 0.5),
			Damage = Kaiju.Bug.Damage * grow * boost.Damage,
			Speed = Kaiju.Bug.Speed,
			Reach = Kaiju.Bug.Reach,
			Rate = Kaiju.Bug.Rate,
			Aggro = Kaiju.Bug.Aggro,
			Coins = 0,
			DropChance = 0,
			Luck = 0,
			Respawn = 0,
		}
		local enemy = Enemies.adopt(
			rig,
			kind,
			{ Element = spec.Element, Title = string.format("Moon Bug · %s · Lv %d", spec.Name, level), Home = at }
		)
		local e = enemy :: any
		e.OutpostCreature = true
		e.Brain = brain
		e.OnDeath = bugDied
		enemy.LastAttack = os.clock() -- (its first bite a moment after it lands)
		wilds[enemy] = {
			Enemy = enemy,
			Species = spec.Id,
			Element = spec.Element,
			Level = level,
			Soul = nil,
			Ability = nil,
			Born = os.clock(),
			Tries = 0,
			TameAt = {},
			Bug = true,
			Engaged = {}, -- (a critter needs nobody to start on it)
			Prey = opts.Prey,
			Band = band,
			Wander = opts.Wander,
			Life = opts.Life,
		}
		-- Out of the tear, at its prey.
		if opts.Hop then
			enemy.Root.AssemblyLinearVelocity = opts.Hop
		end
		return enemy
	end)
	if not ok then
		warn("[Kaiju] moon bug spawn failed:", result)
		return nil
	end
	return result
end

-- Upkeep ------------------------------------------------------------------------------------------------------

-- A wild kaiju nobody's fought for a while, past its lifetime, burrows
-- (not the guardian: it waits for its vein to move).
local function lifetimes(now: number)
	for _, wild in wilds do
		if not wild.Bug and not wild.Guard and wild.Enemy.Alive then
			local fought = math.max(wild.Enemy.LastHit or 0, wild.LastFight or 0)
			if now - wild.Born > (wild.Lifetime or Kaiju.Wild.Lifetime) and now - fought > 20 then
				burrow(wild)
			end
		end
	end
end

-- `outpost` is the Outpost's site (OutpostServer.site()): wild kaiju roam
-- its frontier in packs, clear of its rocks, and the guardian sleeps at the
-- guarded vein.
function KaijuWilds.start(outpost)
	if not outpost or not outpost.Spots then
		warn("[Kaiju] no Outpost site: no wild kaiju")
		return
	end
	site = outpost
	-- The guarded vein's dormant rift (OutpostWorld; KaijuWilds.veinMoved once it moves).
	local guarded = site.Veins and site.Veins[Frontier.Veins.Guarded]
	local siteInfo = guarded and site.VeinSites and site.VeinSites[guarded.Site]
	guardAt = guardAt or (siteInfo and siteInfo.Scar)
	Shop.register("KaijuTame", tame)
	Shop.register("KaijuChallenge", challenge)
	-- (Moon bugs come through rifts round players out past the core: FrontierServer.)
	task.delay(5, function()
		spawnGuardian() -- (first: the packs keep their dens away from it)
		for _ = 1, Kaiju.Wild.Max do
			spawnWild()
		end
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 5 then
			timer = 0
			lifetimes(os.clock())
		end
	end)
end

-- For tests.
KaijuWilds._tame, KaijuWilds._brain, KaijuWilds._wilds = tame, brain, wilds
KaijuWilds._challenge = challenge
KaijuWilds._spawnWild, KaijuWilds._packs = spawnWild, packs
KaijuWilds._spawnGuardian, KaijuWilds._lifetimes = spawnGuardian, lifetimes
function KaijuWilds._guardian()
	return guardian
end
function KaijuWilds._setGuardAt(scar: CFrame?)
	guardAt = scar
end

return KaijuWilds
