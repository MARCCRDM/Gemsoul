--[[
	Wild kaiju and moon bugs in the Outpost's far quarry (Shared.Kaiju has
	the numbers; see docs/kaiju.md).

	  Wild kaiju  up to Kaiju.Wild.Max roam at once, in packs of up to
	              Kaiju.Wild.Pack of a kind (each its own element), levelled
	              near the kaiju out around them. A pack has a den out in the
	              frontier that moves on now and then; each kaiju wanders
	              round it, stopping to sniff, look about, lie down or roar,
	              and stops to look at anyone who comes close (Kaiju.Roam,
	              KaijuMood on its model for the clients' poses). Most packs
	              den beside an outcrop and claim it (Kaiju.Wild.Claim): its
	              rocks roll luckier gems (KaijuWilds.patchLuck, OutpostServer),
	              and a swing at one stirs the pack, a second makes it growl,
	              the third brings it down on the miner, on foot or not, and
	              their kaiju (KaijuWilds.rockSwing, from OutpostServer). A
	              claimed den stays put; a free one drifts. One
	              leaves you and your kaiju alone until you start a fight:
	              challenge it ("KaijuChallenge", its Challenge prompt, shown
	              only while it isn't in a fight or being tamed) and
	              your kaiju goes in, or hit it while hunting (the combat
	              kit out: SparServer). It fights those who started on it
	              and their kaiju (its packmate close by joins in:
	              Kaiju.Wild.Defend; a pack shares out its foes and flanks
	              one it shares, Shared.Squad), and forgets them once home.
	              With your team all knocked out or called back mid-fight,
	              it comes for you, pick in hand or not (exposed). It walks
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
	              shrunk), in swarms through rifts round a player out past
	              the core (FrontierServer: Shared.Frontier), each one weak
	              alone (Kaiju.Bug). One hops
	              out at whoever drew it (a miner too, or a mech's pilot:
	              KaijuWilds.prey), but a kaiju out close by draws it first
	              (Kaiju.Bug.Draw: the prey's own before any other), the
	              critters about shared out evenly over the kaiju near
	              (Shared.Squad: ten on two, five each). It fights for real:
	              it takes its own place in a ring round its foe (clear of
	              the other critters), bites after a wind-up and hops back
	              out, hops clear of a kaiju's blow it sees coming, and uses
	              its kind's own move (Kaiju.BugMoves: Sahur's Bat Slam,
	              Tralalero's Shark Dash, Patapim's Spore Burst), named on
	              its cast bar. Crocodilo is the swarm's ranged one: it
	              never bites, keeps its distance lobbing bombs (and its
	              Carpet Bomb), jets back from one that closes in, and
	              only ever comes at the back of a swarm (Kaiju.wave). With
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
	  Snatchers   in a gem raid (FrontierServer: your team all knocked out
	              out past the core; Shared.Frontier.Raid) every critter out
	              for you is a snatcher (Raider, on its model too): it goes
	              for you before any kaiju and winds up a LUNGE (its cast
	              bar): a hard hit, never a knock-down (in the Outpost you're
	              killed or you're not). Killed, snatchers run in, and each
	              grabs one of this trip's gems (KaijuWilds.steal:
	              FrontierServer's haul; Snatch.Max a death), holds it up
	              over its head (the very stone it
	              took, drawn by each client: CarryingGem and CarriedGem* on
	              its model, its arms up),
	              cackles and runs for a rift that tears open Carry.Away
	              studs off and waits for it (KaijuWilds.escape). It
	              giggles all the way. Bonk it or knock it out first and the
	              gem drops back to you (KaijuWilds.recover); let it hop in
	              and it's gone (KaijuWilds.lost). Nothing left to take, it
	              blows a raspberry and slips away.
	  Robbers     a knocked-out player robbed (Server.Robbery: out past the
	              core, or in the Rift): the critters near turn robbers
	              (KaijuWilds.rob), and the ones brought through for it come
	              as robbers (spawnBug's Robbery). A robber snatches and
	              runs as a snatcher does, but from what the robbery gives
	              (its Steal, Recover, Lost and Away), and never trips
	              anyone. Once it's over they're critters again
	              (KaijuWilds.unrob). A critter of the Rift's world (Hell)
	              tears through in its colours; one that goes without dying
	              tells its OnGone (a Rift cave's pack counts it gone).

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
	  KaijuWilds.pickWave(count, rng, home?) -> { roster id }   what comes
	                                            through, in order (a ranged
	                                            one last; `home`, a biome's
	                                            element, leans it)
	  KaijuWilds.pickCritter(rng, home?) -> roster id  one on its own (never ranged)
	  KaijuWilds.isCritter(enemy) -> boolean    a rift's critter (not a wild kaiju)
	  KaijuWilds.engagedWith(player, within) -> boolean   in a fight with a wild
	                                            kaiju (or taming one): fewer rifts
	  KaijuWilds.critterOf(model) -> enemy?     the rift's critter a model is
	  KaijuWilds.critterKind(element) -> roster id?   the critter of an element
	                                            (FrontierServer's waves that adapt)
	  KaijuWilds.bonk(enemy, player, from) -> boolean   a pickaxe's bonk on a critter
	  KaijuWilds.rift(at, facing, opts?) -> timeline?  opens a rift (FrontierServer
	                                            sets it; a bug slips back through one)
	  KaijuWilds.done(enemy, killed, totals)    a critter is gone (FrontierServer
	                                            sets it: wandering rifts cleared)
	  KaijuWilds.veinSwing(index, player)       a swing at vein `index`'s rocks
	  KaijuWilds.veinMoved(index, scar)         vein `index` surfaced at `scar`
	  KaijuWilds.raid(enemy)                    a critter out turns snatcher
	  KaijuWilds.rob(player, robbery, near) -> count   the critters near rob a knocked-out player
	  KaijuWilds.unrob(robbery)                 that robbery's over
	  KaijuWilds.steal, recover, lost, escape   a gem raid's hooks
	                                            (Main and FrontierServer set them)
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
local Squad = require(ReplicatedStorage.Shared.Squad)
local Analytics = require(script.Parent.Analytics)
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
	Traits: { [string]: number }?,
	Ability: string?,
	Born: number,
	Tries: number,
	TameAt: { [Player]: number },
	Fighter: any?, -- how a wild kaiju fights (KaijuFighter; a moon bug has none)
	Challenge: ProximityPrompt?, -- a wild kaiju's Challenge prompt
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
	Serial: number, -- its number (a steady order when they share out their foes)
	Raider: boolean?, -- a rift's critter in a gem raid: it trips and snatches (Frontier.Raid)
	Loot: any?, -- the gem a snatcher's running off with
	Carry: any?, -- where it's running to: { Spot, Life (its rift's timeline), GiggleAt, Gem (the stone over its head) }
	Stay: boolean?, -- a Rift's: never slips back, roams its patch till someone comes
	Size: number?, -- how big it stands next to you, if not a critter's (Kaiju.Bug.Size)
	Robbery: any?, -- robbing a knocked-out player (Server.Robbery): it snatches, never trips
	Hell: boolean?, -- in the critters' own world (the Rift): its tears burn its colours
	OnGone: ((any) -> ())?, -- told when it goes without dying (through a tear, or slipped back)
}

-- A pack of roaming wild kaiju: its den out in the frontier (they wander
-- round it, and it moves on now and then), its kind, and its members (the
-- first leads: the others keep near it).
type Pack = {
	Den: Vector3,
	Claim: Vector3?, -- the middle of the seam it dens beside (Kaiju.Wild.Claim): its patch
	Rocks: { Vector3 }?, -- the seam's rocks, every one its own
	Swings: number?, -- swings at its patch since it last calmed (KaijuWilds.rockSwing)
	SwingAt: number?,
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
local serial = 0 -- the last wild kaiju's or critter's number (Wild.Serial)
local PREY_OWN = 20 -- studs nearer its prey's own kaiju counts, for a critter

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end
-- An effect at a creature's size ("Sized": the client draws it, sounds it
-- and shakes your screen as big as it stands, FxSize).
local function sizedFx(size: number, kind: string, ...)
	if size == 1 then
		fx(kind, ...)
	else
		fx("Sized", size, kind, ...)
	end
end
-- How big one stands next to you (Kaiju.size).
local function sizeOf(wild: Wild): number
	return if wild.Bug
		then wild.Size or Kaiju.Bug.Size
		else Kaiju.size(if wild.Guard then Kaiju.Scale.Guardian else Kaiju.Scale.Wild)
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
	for _, pet in KaijuServer.all() do
		local root = rootOf(pet.Owner)
		if root and (root.Position - point).Magnitude <= radius then
			table.insert(levels, pet.Record.Level)
		end
	end
	if #levels == 0 then
		-- (Nobody near yet: the kaiju out anywhere in the Outpost.)
		for _, pet in KaijuServer.all() do
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

local exposed -- (below: one who started on it with no kaiju left out)

-- Its foes inside a circle: kaiju out (not recalled) and hunters (`wide`,
-- a rift's critter: any prey); for `wild`, a wild kaiju, also anyone who
-- started on it whose kaiju are all down or called back (exposed).
local function foesNear(center: Vector3, radius: number, wide: boolean?, wild: any?): { any }
	local list = {}
	for _, pet in KaijuServer.all() do
		if KaijuServer.targetable(pet) and (pet.Root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = pet.Root, Pet = pet })
		end
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local fair = if wide then prey(player) else (hunter(player) or (wild ~= nil and exposed(wild, player)))
		if root and fair and (root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = root, Player = player })
		end
	end
	return list
end

-- Its Challenge prompt shows only while it's free to take on: not while
-- it's in a fight (anyone's started on it) or held by a tame.
local function showChallenge(wild: Wild)
	local prompt = wild.Challenge
	local free = next(wild.Engaged) == nil and not wild.Taming and wild.Enemy.Alive
	if prompt and prompt.Enabled ~= free then
		prompt.Enabled = free
	end
end

-- A wild kaiju leaves you be until you start on it: who has, and since when.
local function engage(wild: Wild, player: Player?, now: number)
	if player and not wild.Bug then
		wild.Engaged[player] = now
		showChallenge(wild)
		-- Its packmate close by comes to its defence (Kaiju.Wild.Defend).
		for _, mate in if wild.Pack then wild.Pack.Members else {} do
			local close = mate ~= wild
				and mate.Enemy.Alive
				and flat(mate.Enemy.Root.Position - wild.Enemy.Root.Position).Magnitude <= Kaiju.Wild.Defend
			if close then
				mate.Engaged[player] = now
				showChallenge(mate)
			end
		end
	end
end
local function engaged(wild: Wild, player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and wild.Engaged[player] ~= nil
end

-- One who started on it with nobody left in front of them: their kaiju
-- all knocked out or called back mid-fight. It comes for them then, on
-- foot or not (out past its leash and home a while, it forgets them as
-- ever); send the team back out and it goes back to them.
function exposed(wild: Wild, player: Player): boolean
	if wild.Bug or not engaged(wild, player) or not prey(player) then
		return false
	end
	for _, pet in KaijuServer.all() do
		if pet.Owner == player and KaijuServer.targetable(pet) then
			return false
		end
	end
	return true
end

-- A guardian, or a pack holding a patch: it goes for miners on foot too.
local function territorial(wild: Wild): boolean
	return wild.Guard == true or (wild.Pack ~= nil and wild.Pack.Claim ~= nil)
end

-- Whether `player` is in a fight with a wild kaiju (started on one, and
-- did something in it in the last `within` seconds) or casting a tame on
-- one: FrontierServer holds its rifts back for them (Frontier.Engaged).
function KaijuWilds.engagedWith(player: Player, within: number): boolean
	local now = os.clock()
	for enemy, wild in wilds do
		if not wild.Bug and enemy.Alive then
			local at = wild.Engaged[player]
			if (at and now - at <= within) or (wild.Taming and wild.Taming.Player == player) then
				return true
			end
		end
	end
	return false
end

-- Its foes near a point (for its E): only those who started on it (a
-- guardian's, miners too).
local function foesOf(wild: Wild)
	return function(center: Vector3, radius: number): { any }
		local list = {}
		for _, victim in foesNear(center, radius, territorial(wild), wild) do
			if engaged(wild, if victim.Pet then victim.Pet.Owner else victim.Player) then
				table.insert(list, victim)
			end
		end
		return list
	end
end

-- A critter's blow on a player out there alone (no kaiju of theirs out:
-- FrontierServer's FrontierAlone) lands Frontier.Alone.Damage times harder.
local function alonePlayer(wild: Wild?, player: Player, amount: number): number
	if wild and wild.Bug and player:GetAttribute("FrontierAlone") == true then
		return amount * Frontier.Alone.Damage
	end
	return amount
end

-- A blow (`heavy` true or false; nil for an E) on a kaiju or a hunter, who
-- may guard, parry or hop clear of it. Returns how it landed.
local function hitFoe(enemy, victim, amount: number, element: string?, status: string?, heavy: boolean?): string
	local wild = wilds[enemy]
	local player = victim.Player
	if victim.Pet then
		return KaijuServer.hurt(victim.Pet, amount, element, status, heavy)
	elseif
		player
		and (
			hunter(player)
			or (wild ~= nil and (wild.Bug or territorial(wild)) and prey(player))
			or (wild ~= nil and exposed(wild, player))
		)
	then
		local _, guarded = Enemies.hitPlayer(player, alonePlayer(wild, player, amount), element, enemy, heavy)
		return if guarded then "Guarded" else "Hit"
	end
	return "Missed"
end

-- Whether `victim` is fair game for it now: still there, a kaiju it may
-- hit or a player it may (a hunter; for a rift's critter or a guardian,
-- any prey), one who started on it (a wild kaiju only), inside its leash.
local function fairFor(enemy, wild: Wild, victim): boolean
	if not victim or not victim.Root or not victim.Root.Parent then
		return false
	end
	if victim.Pet and not KaijuServer.targetable(victim.Pet) then
		return false
	end
	local wide = wild.Bug or territorial(wild)
	if victim.Player and not (if wide then prey(victim.Player) else (hunter(victim.Player) or exposed(wild, victim.Player))) then
		return false
	end
	if not wild.Bug and not engaged(wild, if victim.Pet then victim.Pet.Owner else victim.Player) then
		return false
	end
	local leash = if wild.Bug then Kaiju.Bug.Leash else Kaiju.Wild.Leash
	return (victim.Root.Position - enemy.Home).Magnitude <= leash
end

-- Every kaiju out that can be fought, in a steady order (by owner, then place).
local function kaijuOut(): { any }
	local list = {}
	for _, pet in KaijuServer.all() do
		if KaijuServer.targetable(pet) then
			table.insert(list, pet)
		end
	end
	table.sort(list, function(x, y)
		if x.Owner.UserId ~= y.Owner.UserId then
			return x.Owner.UserId < y.Owner.UserId
		end
		return (x.Slot or 0) < (y.Slot or 0)
	end)
	return list
end

-- Rift critters near kaiju share them out (Shared.Squad): every critter
-- within Kaiju.Bug.Draw of a kaiju out it may bite goes for one, spread
-- evenly over the kaiju about (ten on two: five each; three on two: two and
-- one), its prey's own counting nearer, one already fighting it nearer
-- still, and the one it's on kept unless another's well nearer. Critters
-- with no kaiju near aren't in it. Returns { [critter]: pet }.
local function critterPlan(): { [any]: any }
	local critters = {}
	for enemy, wild in wilds do
		if wild.Bug and enemy.Alive and not wild.Leaving then
			table.insert(critters, enemy)
		end
	end
	table.sort(critters, function(x, y)
		return wilds[x].Serial < wilds[y].Serial
	end)
	return Squad.assign(critters, kaijuOut(), function(enemy, pet)
		local wild = wilds[enemy]
		local distance = (pet.Root.Position - enemy.Root.Position).Magnitude
		if distance > Kaiju.Bug.Draw or not fairFor(enemy, wild, { Root = pet.Root, Pet = pet }) then
			return math.huge
		end
		local current = (enemy :: any).FoeVictim
		return Squad.cost(distance, current ~= nil and current.Pet == pet, pet.Target == enemy)
			- (if pet.Owner == wild.Prey then PREY_OWN else 0)
	end)
end

-- Who it goes after: a rift's critter, its share of the kaiju out close by
-- (critterPlan), else whoever drew it while they're fair game; then whoever
-- hurt it last (a kaiju or a hunter), while they're inside its leash; else
-- its current foe; else the nearest it sees. A wild kaiju only goes after
-- those who started on it (a hit is starting on it) and their kaiju; a
-- guardian, those who mined its vein too, on foot.
local function chooseFoe(enemy, wild: Wild, aggro: number)
	local now = os.clock()
	local e = enemy :: any
	local rifted = wild.Bug
	local wide = rifted or territorial(wild)
	if not wild.Bug then
		if e.LastPet and e.LastPetAt and now - e.LastPetAt < 6 then
			engage(wild, e.LastPet.Owner, e.LastPetAt)
		end
		if enemy.LastSource and now - enemy.LastSourceAt < 6 then
			engage(wild, enemy.LastSource, enemy.LastSourceAt)
		end
	end
	local function valid(victim): boolean
		return fairFor(enemy, wild, victim)
	end
	-- A snatcher goes for its player before any kaiju: it's after the gems.
	if wild.Raider and wild.Prey and wild.Prey.Parent then
		local victim = { Root = rootOf(wild.Prey), Player = wild.Prey }
		if valid(victim) then
			return victim
		end
	end
	-- A rift's critter goes for a kaiju out close by before any player (your
	-- kaiju draws them off you: Kaiju.Bug.Draw), sharing them out with the
	-- other critters; and the kaiju go for them (KaijuServer).
	if rifted then
		local pet = critterPlan()[enemy]
		if pet then
			return { Root = pet.Root, Pet = pet }
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
	for _, victim in foesNear(enemy.Root.Position, aggro, wide, wild) do
		local distance = (victim.Root.Position - enemy.Root.Position).Magnitude
		if valid(victim) and distance <= bestDistance then
			best, bestDistance = victim, distance
		end
	end
	return best
end

-- Who a victim is (a kaiju or a player), to tell two victim tables apart.
local function whoOf(victim): any
	return if victim then (victim.Pet or victim.Player) else nil
end

-- A pack in a fight shares out its foes (Shared.Squad), as your team does:
-- packmates fighting (two or more) split who they take on among the foes
-- each may fight near it (each its own while there are enough), one hurting
-- or fighting it counting nearer, the one it chose kept unless another's
-- well nearer; and two on one flank it. Returns its victim and its flank.
local function packShare(enemy, wild: Wild, victim)
	local pack = wild.Pack
	if not pack or wild.Bug or not victim then
		return victim, nil
	end
	local members = {}
	for _, mate in pack.Members do
		local chosen = (mate.Enemy :: any).FoeVictim
		if mate.Enemy.Alive and not mate.Taming and mate.Fighter and fairFor(mate.Enemy, mate, chosen) then
			table.insert(members, mate)
		end
	end
	if #members < 2 or not table.find(members, wild) then
		return victim, nil
	end
	local foes, seen = {}, {}
	local function add(v)
		local who = whoOf(v)
		if who and not seen[who] then
			seen[who] = v
			table.insert(foes, v)
		end
	end
	for _, mate in members do
		add((mate.Enemy :: any).FoeVictim)
		for _, near in foesNear(mate.Enemy.Root.Position, mate.Enemy.Kind.Aggro, mate.Guard == true, mate) do
			if fairFor(mate.Enemy, mate, near) then
				add(near)
			end
		end
	end
	local plan = Squad.assign(members, foes, function(mate, v)
		if not fairFor(mate.Enemy, mate, v) then
			return math.huge
		end
		local me = mate.Enemy :: any
		local distance = (v.Root.Position - mate.Enemy.Root.Position).Magnitude
		local hurting = (v.Pet ~= nil and (me.LastPet == v.Pet or v.Pet.Target == mate.Enemy))
			or (v.Player ~= nil and me.LastSource == v.Player)
		return Squad.cost(distance, whoOf(me.FoeVictim) == whoOf(v), hurting)
	end)
	local mine = plan[wild] or victim
	local sharing, spots = {}, {}
	for _, mate in members do
		if whoOf(plan[mate]) == whoOf(mine) then
			table.insert(sharing, mate)
			table.insert(spots, mate.Enemy.Root.Position)
		end
	end
	local flank = nil
	if #sharing > 1 then
		flank = Squad.slots(mine.Root.Position, spots)[table.find(sharing, wild)]
	end
	return mine, flank
end

-- A push clear of its own side close by (packmates, or other critters).
local function crowd(enemy, wild: Wild, space: number): Vector3
	local others = {}
	local here = enemy.Root.Position
	for other, w in wilds do
		local mates = if wild.Bug then w.Bug else (wild.Pack ~= nil and w.Pack == wild.Pack)
		if other ~= enemy and mates and other.Alive and flat(other.Root.Position - here).Magnitude < space then
			table.insert(others, other.Root.Position)
		end
	end
	return Squad.apart(here, others, space, wild.Serial)
end

-- Opens a rift (FrontierServer sets this; `opts` as FrontierServer.open's:
-- Height, Hell, ...): returns its timeline, or nil.
KaijuWilds.rift = function(_at: Vector3, _facing: Vector3, _opts: any?)
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
	local life = KaijuWilds.rift(
		root.Position,
		root.Position + root.CFrame.LookVector * 10,
		if wild.Hell then { Hell = true } else nil
	)
	local wait = if life then life.HopAt - workspace:GetServerTimeNow() else 0
	task.delay(math.max(0, wait), function()
		if enemy.Alive then
			wilds[enemy] = nil
			Enemies.remove(enemy)
			if wild.OnGone then
				wild.OnGone(enemy)
			end
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

-- The straight way from `from` to `to` stays out of the keep-out zones
-- (both ends can be clear of one and the way between cut across its edge).
-- One it's somehow inside already, it may walk out of.
local function wayAround(from: Vector3, to: Vector3): boolean
	local way = flat(to - from)
	for _, zone in if site and site.KeepOut then site.KeepOut else {} do
		local center = flat(zone[1])
		local start = flat(from)
		if (start - center).Magnitude >= zone[2] then
			local t = if way.Magnitude > 1e-3 then math.clamp((center - start):Dot(way) / way:Dot(way), 0, 1) else 0
			if (start + way * t - center).Magnitude < zone[2] then
				return false
			end
		end
	end
	return true
end

-- Somewhere to amble to: round its den (a packmate keeps near its leader),
-- with a clear way there.
local function abilityStep(wild: Wild?, point: Vector3, facing: Vector3): Vector3?
	if not wild or not wild.Enemy.Alive then
		return nil
	end
	local enemy = wild.Enemy
	if flat(point - enemy.Home).Magnitude > Kaiju.Wild.Leash
		or not roomy(point, wild.Guard)
		or not wayAround(enemy.Root.Position, point)
		or not clearPath(wild, enemy.Root.Position, point)
	then
		return nil
	end
	KaijuServer.place(enemy.Model, point, facing)
	return enemy.Root.Position
end

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
		fits = fits and (wild.Guard or wayAround(enemy.Root.Position, p))
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
	if pack.Claim then
		return -- (a pack holding a patch stays on it)
	end
	for try = 0, 11 do
		local heading = pack.Heading + rng:NextNumber(-0.7, 0.7) + try * math.pi / 6
		local step = rng:NextNumber(roam.Drift[1], roam.Drift[2])
		local den = pack.Den + Vector3.new(math.cos(heading), 0, math.sin(heading)) * step
		local apart = roomy(den)
		for _, other in packs do
			if other ~= pack and flat(other.Den - den).Magnitude < Kaiju.Wild.Apart then
				apart = false
			end
		end
		-- (Each member walks straight over: not through a keep-out zone.)
		for _, member in pack.Members do
			if member.Enemy.Alive and not wayAround(member.Enemy.Root.Position, den) then
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

-- A critter in a fight ----------------------------------------------------------------------------------

local RAID = Frontier.Raid
local giggle, lungeable -- (a gem raid's: below)
local lunged: { [Player]: number } = {} -- when each player was last lunged at

-- What its body is doing, for every client to pose (BodyPoses: a bite is a
-- Slash) and, for a named move, the cast bar (FoeCastBar).
local function act(enemy, kind: string, windup: number, side: number?, name: string?)
	local model = enemy.Model
	local t = serverNow()
	model:SetAttribute("ActionName", name)
	model:SetAttribute("ActionElement", if name then wilds[enemy] and wilds[enemy].Element else nil)
	model:SetAttribute("ActionKind", kind)
	model:SetAttribute("ActionStart", t)
	model:SetAttribute("ActionAt", t + windup)
	model:SetAttribute("ActionSide", side or 1)
end

-- Faces `at` on the spot.
local function lookAt(root: BasePart, at: Vector3)
	local p = root.Position
	local target = Vector3.new(at.X, p.Y, at.Z)
	if (target - p).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(p, target)
	end
end

-- Those it may hit inside a circle (a move lands on all of them).
local function victimsNear(enemy, wild: Wild, center: Vector3, radius: number): { any }
	local list = {}
	for _, victim in foesNear(center, radius, true) do
		if fairFor(enemy, wild, victim) then
			table.insert(list, victim)
		end
	end
	return list
end

-- A blow coming its way: a kaiju on it winding one up, landing soon.
local function incoming(enemy, now: number): boolean
	for _, pet in KaijuServer.all() do
		local action = pet.Target == enemy and pet.Fighter and pet.Fighter.Action
		if action and action.At > now and action.At - now <= 0.45 then
			return true
		end
	end
	return false
end

-- Its place in a ring round its foe, shared with the other critters on it
-- (Shared.Squad.slots), as a direction from its foe; nil alone on it.
local function ringSlot(enemy, victim): Vector3?
	local who = (enemy :: any).Foe
	local group = {}
	for other, w in wilds do
		if w.Bug and other.Alive and (other :: any).Foe == who then
			table.insert(group, other)
		end
	end
	if #group < 2 then
		return nil
	end
	table.sort(group, function(x, y)
		return wilds[x].Serial < wilds[y].Serial
	end)
	local spots = {}
	for i, other in group do
		spots[i] = other.Root.Position
	end
	return Squad.slots(victim.Root.Position, spots)[table.find(group, enemy)]
end

-- A bomb on its way (a Crocodilo's): a ring where it'll land, then it lands
-- there after its flight, on anyone it may hit inside Radius (anyone who
-- moved off is missed).
local function lob(
	enemy,
	wild: Wild,
	now: number,
	to: Vector3,
	radius: number,
	flight: number,
	amount: number,
	status: string?
)
	local e = enemy :: any
	local from = enemy.Root.Position + Vector3.new(0, 1.5, 0)
	local color = GemConfig.ElementColors[wild.Element]
	sizedFx(sizeOf(wild), "Shot", nil, from, to, color, "Bomb", flight)
	sizedFx(sizeOf(wild), "Nova", to, radius, color, flight) -- (the ring, then the blast as it lands)
	e.Bombs = e.Bombs or {}
	table.insert(e.Bombs, {
		At = now + flight,
		To = to,
		Radius = radius,
		Amount = amount,
		Status = status,
	})
end

local function bombsLand(enemy, wild: Wild, now: number)
	local bombs = (enemy :: any).Bombs
	if not bombs then
		return
	end
	for i = #bombs, 1, -1 do
		local bomb = bombs[i]
		if now >= bomb.At then
			table.remove(bombs, i)
			for _, victim in victimsNear(enemy, wild, bomb.To, bomb.Radius) do
				hitFoe(enemy, victim, bomb.Amount, wild.Element, bomb.Status, nil)
			end
		end
	end
end

-- Its kind's own move lands (Kaiju.BugMoves).
local function release(enemy, wild: Wild, move, victim, now: number)
	local root = enemy.Root
	local color = GemConfig.ElementColors[wild.Element]
	local amount = enemy.Kind.Damage * move.Mult * (1 - Enemies.weakness(enemy))
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + enemy.Humanoid.HipHeight, 0)
	if move.Shape == "Slam" then
		-- (Its warning ring bursts now: critterFight fired it with the wind-up.)
		for _, v in victimsNear(enemy, wild, root.Position, move.Radius) do
			hitFoe(enemy, v, amount, wild.Element, move.Status, move.Heavy == true)
		end
	elseif move.Shape == "Burst" then
		sizedFx(sizeOf(wild), "Zone", feet, move.Radius, move.Linger or 2, color)
		for _, v in victimsNear(enemy, wild, root.Position, move.Radius) do
			hitFoe(enemy, v, amount, wild.Element, move.Status, nil)
		end
	elseif move.Shape == "Dash" then
		-- Straight through its foe: everyone it may hit along the way, once.
		local start = root.Position
		local away = flat(victim.Root.Position - start)
		local dir = if away.Magnitude > 0.05 then away.Unit else root.CFrame.LookVector
		local length = math.min(move.Length, away.Magnitude + 5)
		root.AssemblyLinearVelocity = dir * (length / 0.3) + Vector3.new(0, 4, 0)
		sizedFx(sizeOf(wild), "DodgeRoll", nil, start, dir, length, true)
		sizedFx(sizeOf(wild), "Swing", nil, start, dir, move.Width + 1, 120, color, true)
		for _, v in victimsNear(enemy, wild, start + dir * (length / 2), length / 2 + move.Width) do
			local rel = flat(v.Root.Position - start)
			local along = math.clamp(rel:Dot(dir), 0, length)
			if (rel - dir * along).Magnitude <= move.Width then
				hitFoe(enemy, v, amount, wild.Element, move.Status, nil)
			end
		end
	elseif move.Shape == "Bombs" then
		-- Round where its foe stands now: keep moving.
		local at = victim.Root.Position
		for i = 1, move.Count do
			local spot = at
			if i > 1 then
				local a = (i - 2) * math.pi * 2 / math.max(1, move.Count - 1) + rng:NextNumber(-0.4, 0.4)
				spot = at + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(move.Spread * 0.5, move.Spread)
			end
			lob(enemy, wild, now, spot, move.Radius, move.Flight, amount, move.Status)
		end
	end
end

-- A swarm's pounce on one foe (by its root): { At } (Kaiju.Bug.Rush).
local rushes: { [any]: { At: number } } = {}

-- Whether `enemy` (a fighter of a swarm on `victim`) pounces now: once at
-- least Rush.Min of the swarm's fighters are on that foe, a pounce comes
-- every Rush.Every seconds, and each of them leaps in once within its
-- Window.
local function rushNow(enemy, victim, now: number): boolean
	local rules = Kaiju.Bug.Rush
	local key = victim.Root
	local rush = rushes[key]
	if rush and now <= rush.At + rules.Window then
		return now >= rush.At and (enemy :: any).RushedAt ~= rush.At
	end
	local who, count = (enemy :: any).Foe, 0
	for other, w in wilds do
		if w.Bug and other.Alive and (other :: any).Foe == who and not Kaiju.isRanged(w.Species) then
			count += 1
		end
	end
	if count >= rules.Min then
		rushes[key] = { At = now + rng:NextNumber(rules.Every[1], rules.Every[2]) }
	else
		rushes[key] = nil
	end
	for k, old in rushes do
		if now > old.At + 30 then
			rushes[k] = nil -- (its foe long gone)
		end
	end
	return false
end

-- One think of a critter fighting `victim`: in its place round its foe, it
-- bites and hops back out, hops clear of a blow coming, uses its move,
-- pounces with the rest of its swarm, works round behind a foe that faces
-- it, and turns wary when hurt.
local function critterFight(enemy, wild: Wild, victim, now: number)
	local e = enemy :: any
	local humanoid, root, kind = enemy.Humanoid, enemy.Root, enemy.Kind
	local rules = Kaiju.Bug
	local move = Kaiju.BugMoves[wild.Species]
	local offset = flat(victim.Root.Position - root.Position)
	local distance = offset.Magnitude
	local dir = if distance > 0.01 then offset / distance else root.CFrame.LookVector
	local reach = kind.Reach + victim.Root.Size.X / 2
	local wary = humanoid.Health < humanoid.MaxHealth * rules.Skittish
	if move and e.NextMove == nil then
		e.NextMove = now + rng:NextNumber(1.5, math.max(2, move.Every * 0.6))
	end
	-- Stunned (bonked, parried): whatever it was winding up is lost.
	if now < enemy.StunUntil then
		if e.Action then
			e.Action, e.Windup = nil, nil
			act(enemy, "Stagger", 0)
		end
		humanoid:MoveTo(root.Position)
		return
	end
	-- A wind-up under way: it holds, facing its foe, then lets go.
	local action = e.Action
	if action then
		humanoid:MoveTo(root.Position)
		lookAt(root, victim.Root.Position)
		if now < action.At then
			return
		end
		e.Action, e.Windup = nil, nil
		if action.Kind == "Bite" then
			enemy.LastAttack = now
			if distance > reach + 1 + (if action.Rush then rules.Rush.Leap else 0) then
				return -- (it slipped away)
			end
			sizedFx(
				sizeOf(wild),
				"EnemySwing",
				root.Position,
				victim.Root.Position,
				GemConfig.ElementColors[wild.Element]
			)
			if now < (e.BlindUntil or 0) and math.random() < (e.Blind or 0) then
				return -- swung at nothing
			end
			local outcome = hitFoe(enemy, victim, kind.Damage * (1 - Enemies.weakness(enemy)), wild.Element, nil, false)
			if outcome == "Parried" then
				Enemies.addStatus(enemy, "Stun", 1, KaijuFight.ParryStagger) -- (a kaiju's guard turned its bite)
				return
			end
			-- Out again, to circle a moment before it comes back in (longer, hurt).
			root.AssemblyLinearVelocity = -dir * rules.HopBack * 4 + Vector3.new(0, 8, 0)
			e.RecoverUntil = now + rules.Recover * (if wary then rules.Wary else 1)
			e.Circle = if rng:NextNumber() < 0.5 then 1 else -1
		elseif action.Kind == "Lunge" then
			-- A snatcher's lunge: a hard hit, never a knock-down.
			enemy.LastAttack = now
			root.AssemblyLinearVelocity = dir * math.min(50, distance * 6) + Vector3.new(0, 6, 0)
			e.RecoverUntil = now + rules.Recover
			local player = victim.Player
			if not player or distance > reach + 2.5 then
				return -- (it lunged at nothing)
			end
			local amount = alonePlayer(wild, player, kind.Damage * RAID.Lunge.Damage * (1 - Enemies.weakness(enemy)))
			local dealt, guarded = Enemies.hitPlayer(player, amount, wild.Element, enemy, true)
			lunged[player] = now
			if not guarded and (dealt or 0) > 0 then
				giggle(enemy, "Cackle")
			end
		elseif action.Kind == "Lob" then
			enemy.LastAttack = now
			local lobRules = move.Lob
			lob(
				enemy,
				wild,
				now,
				victim.Root.Position,
				lobRules.Radius,
				lobRules.Flight,
				kind.Damage * lobRules.Mult * (1 - Enemies.weakness(enemy)),
				nil
			)
		else
			release(enemy, wild, move, victim, now)
			e.RecoverUntil = now + rules.Recover
		end
		return
	end
	-- A blow coming its way: a hop aside, by chance.
	if now >= (e.NextDodge or 0) and incoming(enemy, now) then
		e.NextDodge = now + rules.DodgeEvery
		if rng:NextNumber() < ((move and move.Dodge) or rules.Dodge) + (if wary then rules.WaryDodge else 0) then
			local sign = if rng:NextNumber() < 0.5 then 1 else -1
			local side = Vector3.new(-dir.Z, 0, dir.X) * sign
			enemy.DodgeUntil = now + rules.DodgeFor
			root.AssemblyLinearVelocity = (side * 0.85 - dir * 0.5).Unit * 40 + Vector3.new(0, 10, 0)
			act(enemy, "Dodge", 0, sign)
			sizedFx(sizeOf(wild), "DodgeRoll", nil, root.Position, side, 6, true)
			return
		end
	end
	-- Its own move, ready, with its foe in range for it.
	if move and now >= e.NextMove and distance <= move.Range and distance >= (move.Min or 0) then
		e.NextMove = now + move.Every
		e.Action = { Kind = "Move", At = now + move.Windup }
		e.Windup = {
			At = now + move.Windup,
			Heavy = move.Heavy == true or move.Shape == "Dash",
			Cast = move.Shape == "Burst" or move.Shape == "Bombs",
		}
		act(enemy, move.Pose, move.Windup, nil, move.Name)
		if move.Radius and (move.Shape == "Slam" or move.Shape == "Burst") then
			-- The ground at its feet marked in warning: get out of it. A slam's
			-- goes off as it lands; a burst's leaves its element lingering
			-- there (release's Zone).
			local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
			local color = GemConfig.ElementColors[wild.Element]
			if move.Shape == "Slam" then
				sizedFx(sizeOf(wild), "Nova", feet, move.Radius, color, move.Windup)
			else
				sizedFx(sizeOf(wild), "Telegraph", feet, move.Radius, color, move.Windup)
			end
		end
		humanoid:MoveTo(root.Position)
		lookAt(root, victim.Root.Position)
		return
	end
	local keep = move and move.Keep
	local ranged = move ~= nil and move.Ranged == true
	-- A ranged one (a Crocodilo) closed in on: it jets back out of reach.
	if ranged and distance < move.Flee and now >= (e.NextFlee or 0) then
		e.NextFlee = now + move.FleeEvery
		local sign = if rng:NextNumber() < 0.5 then 1 else -1
		local away = (-dir + Vector3.new(-dir.Z, 0, dir.X) * sign * 0.45).Unit
		root.AssemblyLinearVelocity = away * 46 + Vector3.new(0, 14, 0)
		enemy.DodgeUntil = now + rules.DodgeFor
		act(enemy, "Dodge", 0, sign)
		sizedFx(sizeOf(wild), "DodgeRoll", nil, root.Position, away, 8, true)
		humanoid:MoveTo(victim.Root.Position - dir * keep)
		return
	end
	-- From a distance (a Crocodilo): a bomb every so often.
	if keep and move.Lob and distance <= move.Range and now - enemy.LastAttack >= move.Lob.Every then
		e.Action = { Kind = "Lob", At = now + move.Lob.Windup }
		e.Windup = { At = now + move.Lob.Windup, Cast = true }
		act(enemy, "Bolt", move.Lob.Windup)
		humanoid:MoveTo(root.Position)
		lookAt(root, victim.Root.Position)
		return
	end
	-- A snatcher's lunge at its player, wound up on its cast bar (LUNGE:
	-- step out of reach, or bonk it): a hard hit, never a knock-down.
	if wild.Raider and not wild.Robbery and victim.Player and not ranged then
		e.NextLunge = e.NextLunge or now + rng:NextNumber(1, 2.5)
		if distance <= RAID.Lunge.Range and now >= e.NextLunge and lungeable(victim.Player, now) then
			e.NextLunge = now + rng:NextNumber(RAID.Lunge.Every[1], RAID.Lunge.Every[2])
			e.Action = { Kind = "Lunge", At = now + RAID.Lunge.Windup }
			e.Windup = { At = now + RAID.Lunge.Windup, Heavy = true }
			act(enemy, "Lunge", RAID.Lunge.Windup, nil, "Lunge")
			humanoid:MoveTo(root.Position)
			lookAt(root, victim.Root.Position)
			return
		end
	end
	-- The swarm's pounce: every fighter on this foe leaps in at once.
	if not ranged and distance <= reach + rules.Rush.Leap and rushNow(enemy, victim, now) then
		e.RushedAt = rushes[victim.Root].At
		e.RecoverUntil = nil
		e.Action = { Kind = "Bite", At = now + rules.BiteWindup, Rush = true }
		e.Windup = { At = now + rules.BiteWindup }
		root.AssemblyLinearVelocity = dir * math.min(60, distance * 6) + Vector3.new(0, 10, 0)
		act(enemy, "Lunge", rules.BiteWindup)
		lookAt(root, victim.Root.Position)
		return
	end
	-- A bite, once it's in reach and ready (never a ranged one's).
	if not ranged and distance <= reach and now - enemy.LastAttack >= kind.Rate and now >= (e.RecoverUntil or 0) then
		e.Action = { Kind = "Bite", At = now + rules.BiteWindup }
		e.Windup = { At = now + rules.BiteWindup }
		act(enemy, "Slash", rules.BiteWindup)
		humanoid:MoveTo(root.Position)
		lookAt(root, victim.Root.Position)
		return
	end
	-- Else into its place round its foe (circling it a moment after a
	-- bite), clear of the other critters: round its foe, not through it.
	local standoff = keep or math.max(reach * 0.8, 1.5)
	local here = flat(root.Position - victim.Root.Position)
	local slot = ringSlot(enemy, victim)
	local want = slot or (if here.Magnitude > 0.05 then here.Unit else -dir)
	if not slot and not ranged and here.Magnitude > 0.05 then
		-- On its own, with its foe facing it: round toward its back.
		local look = flat(victim.Root.CFrame.LookVector)
		if look.Magnitude > 0.05 and look.Unit:Dot(here.Unit) > 0.5 then
			want = Squad.toward(here.Unit, -look.Unit, rules.Flank)
		end
	end
	if wary then
		standoff += rules.HopBack * 0.5
	end
	if now < (e.RecoverUntil or 0) then
		standoff += rules.HopBack * 0.6
		local swing = math.rad(35) * (e.Circle or 1)
		local c, sn = math.cos(swing), math.sin(swing)
		want = Vector3.new(want.X * c - want.Z * sn, 0, want.X * sn + want.Z * c)
	end
	local spot = victim.Root.Position + Squad.toward(here, want, math.rad(60)) * standoff
	spot += crowd(enemy, wild, Kaiju.Squad.BugSpace)
	if flat(spot - root.Position).Magnitude > 0.8 then
		humanoid:MoveTo(spot)
	else
		humanoid:MoveTo(root.Position)
	end
	if distance <= reach + 4 then
		lookAt(root, victim.Root.Position)
	end
end

-- Gem raids --------------------------------------------------------------------------------------------

-- The newest gem of `player`'s haul, out of their pouch (FrontierServer sets it).
KaijuWilds.steal = function(_player: Player): any
	return nil
end
-- A snatched gem dropped at `at`: back to `player` (FrontierServer sets it).
KaijuWilds.recover = function(_player: Player?, _gem, _at: Vector3) end
-- A snatcher got away with `player`'s gem (FrontierServer sets it).
KaijuWilds.lost = function(_player: Player?, _gem) end
-- A rift at `at` that waits `wait` seconds for a snatcher: its timeline
-- (FrontierServer sets it; `hell`: in the critters' own world's colours).
KaijuWilds.escape = function(_at: Vector3, _facing: Vector3, _wait: number, _hell: boolean?): any
	return nil
end

local snatched: { [Player]: { Down: number, Count: number } } = {} -- gems taken while they're down (killed)

-- A giggle (or a cackle) for everyone near to hear, "hee hee!" over it.
function giggle(enemy, kind: string?)
	local root = enemy.Root
	if root and root.Parent then
		fx("CritterGiggle", root.Position + Vector3.new(0, 2, 0), kind or "Giggle")
	end
end

-- One of a gem raid's critters turns snatcher.
function KaijuWilds.raid(enemy)
	local wild = enemy and wilds[enemy]
	if wild and wild.Bug and not wild.Raider and enemy.Alive then
		wild.Raider = true
		enemy.Model:SetAttribute("Raider", true)
	end
end

-- A knocked-out `player` robbed (Server.Robbery: `robbery`): every critter
-- out within `near` studs of them (not already running off with something,
-- held by a tame or on its way out) comes for them, to grab what
-- robbery.Steal gives. It never trips anyone. Returns how many came.
function KaijuWilds.rob(player: Player, robbery, near: number): number
	local root = rootOf(player)
	if not root then
		return 0
	end
	local came = 0
	for enemy, wild in wilds do
		if not wild.Bug or not enemy.Alive or wild.Leaving or wild.Loot or wild.Taming then
			continue
		end
		if flat(enemy.Root.Position - root.Position).Magnitude > near then
			continue
		end
		if wild.Robbery and wild.Robbery ~= robbery then
			continue -- (robbing someone else)
		end
		wild.Raider, wild.Robbery, wild.Prey = true, robbery, player
		enemy.Model:SetAttribute("Raider", true)
		came += 1
	end
	return came
end

-- `robbery`'s over: its robbers that aren't running off with something are
-- critters again (one that is still runs for its tear).
function KaijuWilds.unrob(robbery)
	for enemy, wild in wilds do
		if wild.Robbery == robbery and not wild.Loot then
			wild.Robbery, wild.Raider = nil, nil
			enemy.Model:SetAttribute("Raider", nil)
		end
	end
end

-- Whether a snatcher may lunge at `player` now: not down, and not too soon after the last.
function lungeable(player: Player, now: number): boolean
	return now - (lunged[player] or -math.huge) >= RAID.Lunge.Gap and not Spar.isDown(player)
end

-- How many more gems snatchers may take from `player` this knock-down (a
-- robbery's own count, robbing them: Server.Robbery).
local function snatchesLeft(player: Player, robbery: any?): number
	if robbery then
		return if robbery.Empty then 0 else robbery.Max - robbery.Taken
	end
	local down = player:GetAttribute("SparDown")
	if type(down) ~= "number" then
		return 0
	end
	local entry = snatched[player]
	if not entry or entry.Down ~= down then
		entry = { Down = down, Count = 0 }
		snatched[player] = entry
	end
	return RAID.Snatch.Max - entry.Count
end

local function weld(part: BasePart, to: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0, joint.Part1 = part, to
	joint.Parent = part
end

-- The gem over a snatcher's head: the very stone it took, held high (its
-- arms up: a held "Buff", BodyPoses). What it is goes on its model (the
-- gem's id, element, rarity and grades: CarriedGem*), and each client
-- builds that stone over its head (GemArt, CritterFx.carried), so it looks
-- like the gem in your pouch did. Returns the parts to clear when it lets
-- go (none: the clients draw it).
local CARRIED = { "CarriedGemId", "CarriedGemElement", "CarriedGemSize", "CarriedGemClarity", "CarriedGemCut" }
local function holdUp(enemy, gem): { BasePart }
	local model = enemy.Model
	model:SetAttribute("CarriedGemId", tostring(gem.Id or "gem"))
	model:SetAttribute("CarriedGemElement", gem.Element)
	model:SetAttribute("CarriedGemSize", tonumber(gem.Size))
	model:SetAttribute("CarriedGemClarity", tonumber(gem.Clarity))
	model:SetAttribute("CarriedGemCut", tonumber(gem.Cut))
	model:SetAttribute("CarryingGem", gem.Tier or "Common")
	act(enemy, "Buff", 0.25)
	model:SetAttribute("ActionHold", serverNow() + 600)
	return {}
end

-- Its hands empty again.
local function letGo(enemy, wild: Wild)
	local carrying = wild.Carry
	if carrying and carrying.Gem then
		for _, part in carrying.Gem do
			part:Destroy()
		end
	end
	wild.Carry, wild.Loot = nil, nil
	enemy.Model:SetAttribute("CarryingGem", nil)
	for _, key in CARRIED do
		enemy.Model:SetAttribute(key, nil)
	end
	enemy.Model:SetAttribute("ActionHold", nil)
end

-- A snatcher drops what it's carrying (bonked, or knocked out): back to its
-- player (a robbery's own way, if it was robbing them).
local function drop(enemy, wild: Wild)
	local gem = wild.Loot
	if not gem then
		return
	end
	local at = enemy.Root.Position
	letGo(enemy, wild)
	local robbery = wild.Robbery
	if robbery then
		robbery.Recover(wild.Prey, gem, at)
	else
		KaijuWilds.recover(wild.Prey, gem, at)
	end
end

-- Into its rift with the gem: gone for good.
local function getAway(enemy, wild: Wild)
	local gem = wild.Loot
	giggle(enemy, "Giggle")
	letGo(enemy, wild)
	wild.Leaving = true
	KaijuWilds.done(enemy, false, nil)
	if gem then
		if wild.Robbery then
			wild.Robbery.Lost(wild.Prey, gem)
		else
			KaijuWilds.lost(wild.Prey, gem)
		end
	end
	wilds[enemy] = nil
	Enemies.remove(enemy)
	if wild.OnGone then
		wild.OnGone(enemy)
	end
end

-- Running off with a gem to the rift waiting for it, giggling all the way.
local function carry(enemy, wild: Wild, now: number)
	local c = wild.Carry
	local humanoid, root = enemy.Humanoid, enemy.Root
	humanoid.WalkSpeed = RAID.Carry.Speed * (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
	if now >= c.GiggleAt then
		c.GiggleAt = now + rng:NextNumber(RAID.Carry.Giggle[1], RAID.Carry.Giggle[2])
		giggle(enemy, "Giggle")
	end
	local t = serverNow()
	-- (Its rift sealing before it got through: a fresh one where it is.)
	if not c.Life or t >= c.Life.CloseAt - 0.3 then
		c.Spot = root.Position
		c.Life =
			KaijuWilds.escape(root.Position, root.Position + root.CFrame.LookVector * 10, Frontier.Rift.Hop, wild.Hell)
	end
	if flat(c.Spot - root.Position).Magnitude > 3 then
		humanoid:MoveTo(c.Spot)
		return
	end
	humanoid:MoveTo(root.Position)
	if c.Life and t >= c.Life.HopAt then
		getAway(enemy, wild)
	end
end

-- Its player down: in for a grab, and off with the newest gem of their haul
-- (robbing them, whatever the robbery gives: Server.Robbery). Returns
-- whether it's busy at it.
local function snatch(enemy, wild: Wild, now: number): boolean
	local player = wild.Prey :: Player
	local target = rootOf(player)
	if not target then
		return false
	end
	local robbery = wild.Robbery
	local e = enemy :: any
	local humanoid, root = enemy.Humanoid, enemy.Root
	local offset = flat(target.Position - root.Position)
	local action = e.Action
	if action and action.Kind == "Snatch" then
		humanoid:MoveTo(root.Position)
		lookAt(root, target.Position)
		if now < action.At then
			return true
		end
		e.Action, e.Windup = nil, nil
		if offset.Magnitude > RAID.Snatch.Reach + 1.5 or snatchesLeft(player, robbery) <= 0 then
			return true
		end
		local gem = if robbery then robbery.Steal(player) else KaijuWilds.steal(player)
		if not gem then
			-- Nothing worth taking: a raspberry, and off it goes (a Rift
			-- cave's own stays, hopping round them: Stay).
			giggle(enemy, "Giggle")
			if not wild.Stay then
				slipBack(wild)
			end
			return true
		end
		if not robbery then
			snatched[player].Count += 1
		end
		wild.Loot = gem
		local spot = if robbery and robbery.Away
			then robbery.Away(root.Position, target.Position)
			else Frontier.escapeSpot(root.Position, target.Position, Outpost.Location.Position, rng)
		spot = KaijuServer.ground(spot)
		wild.Carry = {
			Spot = spot,
			GiggleAt = now + 0.9,
			Gem = holdUp(enemy, gem),
			Life = KaijuWilds.escape(spot, root.Position, RAID.Carry.Wait, wild.Hell),
		}
		giggle(enemy, "Cackle")
		return true
	end
	if offset.Magnitude > RAID.Snatch.Rush or snatchesLeft(player, robbery) <= 0 then
		return false
	end
	e.Action, e.Windup = nil, nil
	if offset.Magnitude > RAID.Snatch.Reach then
		humanoid:MoveTo(target.Position)
		return true
	end
	e.Action = { Kind = "Snatch", At = now + RAID.Snatch.Windup }
	e.Windup = { At = now + RAID.Snatch.Windup }
	act(enemy, "Slash", RAID.Snatch.Windup, nil, "Snatch")
	humanoid:MoveTo(root.Position)
	lookAt(root, target.Position)
	return true
end

-- Its player down and nothing for it to grab: it hops round them, giggling.
local function taunt(enemy, wild: Wild, now: number): boolean
	local target = rootOf(wild.Prey :: Player)
	if not target then
		return false
	end
	local e = enemy :: any
	local root = enemy.Root
	if now >= (e.TauntAt or 0) then
		e.TauntAt = now + rng:NextNumber(0.9, 1.6)
		local angle = rng:NextNumber(0, math.pi * 2)
		e.TauntSpot = target.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(5, 8)
		if rng:NextNumber() < 0.45 then
			root.AssemblyLinearVelocity += Vector3.new(0, 18, 0) -- (a gleeful hop)
			giggle(enemy, "Giggle")
		end
	end
	enemy.Humanoid:MoveTo(e.TauntSpot or root.Position)
	return true
end

-- The brain both kinds share: find a foe and fight it (a wild kaiju as a
-- duellist, KaijuFighter; a moon bug chases and bites), else go home (a
-- rift's critter slips back through a rift).
local tameStep -- (a tame's tick: Taming, below)

-- Cowed by a team's HYPERBEAM winding up (KaijuBeamServer sets CowedUntil
-- and CowedFrom on it, os.clock): it drops whatever it was winding up and
-- backs off from the beam's owner, low and trembling, till the beam fires.
local function cower(enemy, wild: Wild)
	local e = enemy :: any
	local root, humanoid = enemy.Root, enemy.Humanoid
	if e.Action then
		e.Action, e.Windup = nil, nil
	end
	local fighter = wild.Fighter
	if fighter and fighter.Action then
		fighter.Action = nil
		fighter.Humanoid.AutoRotate = true
	end
	if enemy.Model:GetAttribute("ActionKind") ~= nil then
		enemy.Model:SetAttribute("ActionKind", nil)
		enemy.Model:SetAttribute("ActionName", nil)
	end
	setMood(wild, "Cower")
	local away = flat(root.Position - e.CowedFrom)
	local dir = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
	humanoid.WalkSpeed = enemy.Kind.Speed * 0.55
	humanoid:MoveTo(root.Position + dir * 6)
end

local function brain(enemy, now: number)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	local e = enemy :: any
	local humanoid, root = enemy.Humanoid, enemy.Root
	local fighter = wild.Fighter
	-- (A critter's bombs in the air land whatever it's doing now.)
	if wild.Bug then
		bombsLand(enemy, wild, now)
	else
		showChallenge(wild)
	end
	-- Held by a tame: nothing else till it's over.
	if wild.Taming then
		e.FoeVictim, e.Foe = nil, nil
		tameStep(enemy, wild, now)
		return
	end
	if e.CowedUntil then
		if now < e.CowedUntil and typeof(e.CowedFrom) == "Vector3" then
			cower(enemy, wild)
			return
		end
		e.CowedUntil, e.CowedFrom = nil, nil
		if enemy.Model:GetAttribute("KaijuMood") == "Cower" then
			setMood(wild, nil)
		end
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
	-- A snatcher with a gem runs for its rift; with its player down, it
	-- goes in for a grab (or hops round them, giggling).
	if wild.Loot then
		carry(enemy, wild, now)
		return
	end
	if wild.Raider and wild.Prey and Spar.isDown(wild.Prey) then
		if snatch(enemy, wild, now) or taunt(enemy, wild, now) then
			return
		end
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
	if wild.Bug and not wild.Stay and now - wild.Born > (wild.Life or Frontier.Life) then
		slipBack(wild) -- (no critter stays for good)
		return
	end
	if not victim and wild.Bug and wild.Wander and (wild.Stay or lingers(wild)) then
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
			showChallenge(wild)
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
		-- A pack shares out its foes and flanks one it shares; packmates
		-- keep clear of each other (Shared.Squad).
		local flank
		victim, flank = packShare(enemy, wild, victim)
		e.FoeVictim = victim
		e.Foe = victim.Pet or victim.Player
		fighter.Flank = flank
		fighter.Apart = if wild.Pack then crowd(enemy, wild, Kaiju.Squad.Space) else nil
		KaijuFighter.step(fighter, victim, now)
		return
	end
	critterFight(enemy, wild, victim, now)
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
		return 0
	end
	local bugs = tally(Kaiju.roster(profile))
	local coins = math.min(amount, Kaiju.bugCoins(bugs, bugs.Day))
	if coins > 0 then
		bugs.Coins += coins
		PlayerData.addCoins(player, coins, "Critters")
	end
	return coins
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
	sizedFx(sizeOf(wild), "TriadBreak", enemy.Root.Position, 5 * sizeOf(wild), wild.Element)
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
					"Defeated %s %s: its enchant gem is yours (%s, E: %s).",
					if wild.Guard then "the vein's guardian, a" else "a wild",
					title,
					GemConfig.displayName(soul),
					if move then move.Name else "?"
				)
			)
		else
			Remotes.Notify:FireClient(best, "Your gem pouch is full: its enchant gem crumbled to dust.")
		end
		PlayerData.milestone(best, "KaijuSlain")
		if wild.Guard then
			payCoins(best, Frontier.Coins.Guardian)
		end
	end
	gone(wild)
end

-- A wild kaiju at `at` (on the ground there), its `level`, turned to
-- `facing` (any way, if not given), of `species` (any that roams there, if
-- not given: Kaiju.wildKinds); `guard`, the guarded vein's (bigger, one of
-- the Vein's own kinds).
local function newWild(at: Vector3, level: number, guard: boolean, facing: Vector3?, species: string?): Wild
	if not species then
		local band = if guard then "Vein" else Frontier.band(Frontier.distance(at, Outpost.Location.Position))
		local kinds = Kaiju.wildKinds(band)
		kinds = if #kinds > 0 then kinds else Kaiju.Starters
		species = Kaiju.pickKind(kinds, rng)
	end
	-- (Out in one of the biomes, mostly of its element: Frontier.Biome.)
	local biome = Frontier.biomeAt(at - Outpost.Location.Position)
	local element = Frontier.pickElement(biome and biome.Element, rng)
	local scale = if guard then Kaiju.Scale.Guardian else Kaiju.Scale.Wild
	local soul = Kaiju.rollSoul(Gems.random(), element, {
		Id = "wild",
		Time = os.time(),
		Species = species,
		Luck = math.clamp(level / 60, 0, 0.5),
	})
	-- (its own traits: the ones it keeps when it's caught)
	local traits = Kaiju.rollTraits(rng)
	local stats = Kaiju.withTraits(Kaiju.stats(species, level, soul.Tier), traits)
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
	-- (its Grade shows on it, so you can tell a fine one before you catch it)
	model:SetAttribute("KaijuGrade", (Kaiju.grade(traits)))
	local enemy = Enemies.adopt(model, kind, {
		Element = element,
		Title = string.format("%s · Lv %d", title, level),
		Home = model.PrimaryPart.Position,
		Size = Kaiju.size(scale),
	})
	local e = enemy :: any
	local engagedBy = {}
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
		local mult, tag = Kaiju.taken(species, element, hitElement, stats.Guard)
		return mult * Kaiju.spread(), tag
	end
	-- Its R's shell or ward takes its share of a blow (Enemies.damage).
	e.Soak = function(amount: number): number
		return KaijuAbilities.soak(enemy, amount)
	end
	-- (Its own moves: its role's, Kaiju.kitMoves.)
	local moves = Kaiju.kitMoves(species, level)
	local ability = moves.E
	-- And its gem surge, its Gemsoul's E (the one it leaves behind).
	local gem = Kaiju.gemSurge(soul)
	model:SetAttribute("KaijuGemSurge", gem)
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
	-- (F, not E: in first person E is your ability.)
	challenge.KeyboardKeyCode = Enum.KeyCode.F
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
		GemSurge = gem,
		FirstSurge = 4,
		Strike = function(victim, amount: number, heavy: boolean, _name: string): string
			return hitFoe(enemy, victim, amount * (1 - Enemies.weakness(enemy)), element, nil, heavy)
		end,
		Caster = function()
			return {
				Model = model,
				Root = enemy.Root,
				Size = Kaiju.size(scale),
				Element = element,
				Ability = ability,
				Damage = Kaiju.abilityDamage(stats.Damage, soul, ability),
				DamageOf = function(id: string): number
					return Kaiju.abilityDamage(stats.Damage, soul, id)
				end,
				Body = enemy,
				Humanoid = enemy.Humanoid,
				-- Wild variants use the same physical pounce/retreat as pets,
				-- bounded by their home, obstacles and the lobby keep-out zones.
				Leap = function(victim): Vector3?
					local toward = flat(victim.Root.Position - enemy.Root.Position)
					local direction = if toward.Magnitude > 0.01 then toward.Unit else enemy.Root.CFrame.LookVector
					local size = Kaiju.size(scale)
					local distance = math.min(toward.Magnitude + 2.2 * size, 12 * size)
					return abilityStep(wilds[enemy], enemy.Root.Position + direction * distance, victim.Root.Position)
				end,
				Hop = function(direction: Vector3, studs: number): Vector3?
					local point = enemy.Root.Position + direction * math.min(studs, 20 * Kaiju.size(scale))
					return abilityStep(wilds[enemy], point, point + direction)
				end,
				-- A warrior's cry: harder, faster blows for a while (KaijuFighter
				-- reads them off its Body), as a pet's are.
				Rally = function(plan)
					e.RallyUntil = os.clock() + (plan.Duration or 5)
					e.RallyDamage, e.RallyHaste = plan.Damage or 1, plan.Haste or 1
				end,
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
		Traits = traits,
		Ability = ability,
		Born = os.clock(),
		Tries = 0,
		TameAt = {},
		Fighter = fighter,
		Challenge = challenge,
		Bug = false,
		Engaged = engagedBy,
		Guard = guard,
		Swings = 0,
		-- (Each its own, so they don't all burrow at once and leave the quarry empty.)
		Lifetime = Kaiju.Wild.Lifetime * rng:NextNumber(0.7, 1.5),
		Serial = serial + 1,
	}
	serial += 1
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
	local function apartFrom(den: Vector3): boolean
		if not roomy(den) then
			return false
		end
		for _, other in packs do
			if flat(other.Den - den).Magnitude < Kaiju.Wild.Apart then
				return false
			end
		end
		return true
	end
	-- Most packs claim an outcrop: a den a few studs off one of its rocks
	-- (Kaiju.Wild.Claim), the rest of the seam within its radius.
	local claim = Kaiju.Wild.Claim
	local crops = site and site.OutcropSpots or {}
	-- The seam a rock is in: every outcrop rock chained to it a step or so
	-- apart (Kaiju.Wild.Claim.Link), and where its middle is.
	local function seamOf(rock: Vector3): ({ Vector3 }, Vector3)
		local link = Frontier.Outcrop.Step * claim.Link
		local seam, frontier = { rock }, { rock }
		while #frontier > 0 do
			local from = table.remove(frontier) :: Vector3
			for _, index in crops do
				local spot = site.Spots[index]
				local q = spot and spot.Position
				if q and flat(q - from).Magnitude <= link then
					local known = false
					for _, r in seam do
						if flat(r - q).Magnitude < 0.5 then
							known = true
							break
						end
					end
					if not known then
						table.insert(seam, q)
						table.insert(frontier, q)
					end
				end
			end
		end
		local sum = Vector3.zero
		for _, r in seam do
			sum += r
		end
		return seam, sum / #seam
	end
	if #crops > 0 and rng:NextNumber() < claim.Share then
		for _ = 1, 60 do
			local spot = site.Spots[crops[rng:NextInteger(1, #crops)]]
			local rock = spot and spot.Position
			if rock then
				local seam, rockMiddle = seamOf(rock)
				local a = rng:NextNumber(0, math.pi * 2)
				local den = rockMiddle + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(claim.Den[1], claim.Den[2])
				if apartFrom(den) then
					rock = rockMiddle
					-- (A kind that roams that far out, and no other pack's, if there's one.)
					local roams = Kaiju.wildKinds(Frontier.band(Frontier.distance(den, middle)))
					roams = if #roams > 0 then roams else Kaiju.Starters
					local kinds = {}
					for _, species in roams do
						local taken = false
						for _, other in packs do
							taken = taken or other.Species == species
						end
						if not taken then
							table.insert(kinds, species)
						end
					end
					roams = if #kinds > 0 then kinds else roams
					local pack: Pack = {
						Den = Vector3.new(den.X, rock.Y, den.Z),
						Claim = rock,
						Rocks = seam,
						Heading = a,
						MoveAt = math.huge,
						Species = Kaiju.pickKind(roams, rng),
						Members = {},
					}
					table.insert(packs, pack)
					return pack
				end
			end
		end
	end
	for _ = 1, 80 do
		local a = rng:NextNumber(0, math.pi * 2)
		-- Area-weighted dens give the wider outer ground its share of wildlife.
		local r = math.sqrt(rng:NextNumber((Frontier.Core + 30) ^ 2, (Frontier.Rim - 45) ^ 2))
		local den = middle + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if apartFrom(den) then
			-- (A kind that roams that far out, Kaiju.wildKinds, and no other
			-- pack is, if there's one.)
			local roams = Kaiju.wildKinds(Frontier.band(r))
			local kinds = {}
			for _, species in roams do
				local taken = false
				for _, other in packs do
					taken = taken or other.Species == species
				end
				if not taken then
					table.insert(kinds, species)
				end
			end
			kinds = if #kinds > 0 then kinds else roams
			local roam = Kaiju.Roam
			local pack: Pack = {
				Den = den,
				Heading = rng:NextNumber(0, math.pi * 2),
				MoveAt = os.clock() + rng:NextNumber(roam.Every[1], roam.Every[2]),
				Species = Kaiju.pickKind(kinds, rng),
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
		sizedFx(sizeOf(old), "TriadBreak", old.Enemy.Root.Position, 5 * sizeOf(old), old.Element)
		Enemies.remove(old.Enemy)
	end
	if old then
		gone(old)
	end
	spawnGuardian()
end

-- Claimed patches ------------------------------------------------------------------------------------------

-- The pack holding the patch a rock at `position` is in, if any (one of
-- its seam's rocks, or any rock within Kaiju.Wild.Claim.Radius of its den;
-- and someone of it still standing).
local function holds(pack: Pack, position: Vector3): boolean
	if not pack.Claim then
		return false
	end
	for _, rock in pack.Rocks or {} do
		if flat(rock - position).Magnitude < 1.5 then
			return true
		end
	end
	return flat(pack.Den - position).Magnitude <= Kaiju.Wild.Claim.Radius
end
local function packAt(position: Vector3): Pack?
	for _, pack in packs do
		if holds(pack, position) then
			for _, member in pack.Members do
				if member.Enemy.Alive then
					return pack
				end
			end
		end
	end
	return nil
end

-- How much luckier a rock at `position` rolls: Kaiju.Wild.Claim.Luck while
-- a pack holds its patch, else nothing.
function KaijuWilds.patchLuck(position: Vector3): number
	return if packAt(position) then Kaiju.Wild.Claim.Luck else 0
end

-- A swing at a rock at `position`: the pack holding its patch (if one does)
-- stirs at the first, growls at the next, and comes for the miner on the
-- Kaiju.Wild.Claim.Wake'th (a stray swing long ago doesn't count); once
-- roused, every swing at its rocks puts the miner on its list. Returns the
-- pack, or nil for a rock nobody holds.
function KaijuWilds.rockSwing(position: Vector3, player: Player): Pack?
	local pack = packAt(position)
	if not pack then
		return nil
	end
	local now = os.clock()
	local awake = false
	for _, member in pack.Members do
		if member.Enemy.Alive and next(member.Engaged) ~= nil then
			awake = true
		end
	end
	if awake then
		for _, member in pack.Members do
			if member.Enemy.Alive then
				engage(member, player, now)
				member.LastFight = now
			end
		end
		return pack
	end
	if now - (pack.SwingAt or now) > 30 then
		pack.Swings = 0
	end
	pack.Swings = (pack.Swings or 0) + 1
	pack.SwingAt = now
	local root = rootOf(player)
	local at = if root then root.Position else nil
	local wake = Kaiju.Wild.Claim.Wake
	for _, member in pack.Members do
		if member.Enemy.Alive then
			if pack.Swings == wake - 2 then
				startPlan(member, "Look", 4, now, at)
			elseif pack.Swings == wake - 1 then
				member.GrowlAt = now
				startPlan(member, "Roar", 1.6, now, at)
			end
			if pack.Swings >= wake then
				engage(member, player, now)
				member.LastFight = now
				member.Enemy.Model:SetAttribute("ActionAt", serverNow())
			end
		end
	end
	if pack.Swings == wake then
		Remotes.Notify:FireClient(player, "The pack holding this patch is coming for you!")
	end
	return pack
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
		local record = KaijuServer.adopt(player, wild.Species, soul, Kaiju.Tame.Level, wild.Traits)
		if not record then
			tell(player, "Couldn't catch it right now.")
			tameResult(player, "Interrupted")
			return
		end
		sizedFx(sizeOf(wild), "TriadBreak", enemy.Root.Position, 6 * sizeOf(wild), wild.Element)
		Enemies.remove(enemy)
		gone(wild)
		PlayerData.milestone(player, "KaijuTamed")
		Analytics.event(player, "KaijuCaught", wild.Tries + 1, wild.Species, wild.Element)
		tell(player, string.format("Caught! The %s is yours, starting over at level %d.", title, record.Level))
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
		broke = "The catch broke."
	elseif flat(root.Position - enemy.Root.Position).Magnitude > Kaiju.Tame.Break then
		broke = "Too far away: the catch broke."
	elseif body.Health < taming.Health - 0.5 then
		broke = "You were hit: the catch broke."
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
		return reply(false, "There's no wild kaiju there to catch.")
	end
	local root = rootOf(player)
	if not root or player:GetAttribute("Outpost") ~= true then
		return reply(false, "Not right now.")
	end
	if (root.Position - enemy.Root.Position).Magnitude > TAME_RANGE then
		return reply(false, "Get closer to catch it.")
	end
	if wild.Taming then
		return reply(
			false,
			if wild.Taming.Player == player then "Hold steady: you're catching it." else "Someone's catching that one."
		)
	end
	if tamingOf(player) then
		return reply(false, "You're already catching one.")
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
	showChallenge(wild)
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
	local ready = false
	for _, pet in KaijuServer.team(player) do
		ready = ready or KaijuServer.targetable(pet)
	end
	if not ready and not hunter(player) then
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
	drop(enemy, wild) -- (a snatcher knocked out lets go of your gem)
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
		local coins = payCoins(best, rng:NextInteger(Frontier.CritterCoins.Min, Frontier.CritterCoins.Max))
		if coins > 0 then
			Remotes.CombatFx:FireAllClients("CritterCoins", enemy.Root.Position, best.UserId, coins)
		end
	end
	KaijuWilds.done(enemy, true, totals)
end

-- The critter whose element is `element` (DungeonRules.Roster), if any.
-- (KaijuWilds.critterKind: FrontierServer's, the kind its later waves send to counter you.)
local function critterOf(element: string?): string?
	for _, spec in DungeonRules.Roster do
		if spec.Element == element and table.find(Kaiju.Critters, spec.Id) then
			return spec.Id
		end
	end
	return nil
end

KaijuWilds.critterKind = critterOf

-- A critter's roster entry (its Element, Name...) by its id.
function KaijuWilds.critterSpec(id: string?)
	for _, spec in DungeonRules.Roster do
		if spec.Id == id then
			return spec
		end
	end
	return nil
end

-- What comes through for an encounter of `count`: roster ids, in the order
-- they come (Kaiju.wave: a ranged one never alone, and last). Coming
-- through in one of the Outpost's biomes, `home` (its element) leans it
-- toward the biome's own kind (Frontier.Biome.Critter).
function KaijuWilds.pickWave(count: number, r, home: string?): { string }
	return Kaiju.wave(count, r or rng, critterOf(home), Frontier.Biome.Critter)
end

-- One critter on its own (never a ranged one): a roster id.
function KaijuWilds.pickCritter(r, home: string?): string
	return Kaiju.wave(1, r or rng, critterOf(home), Frontier.Biome.Critter)[1]
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
	-- (A snatcher bonked lets go of the gem it's running off with.)
	drop(enemy, wild)
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
--   Raider   a gem raid's: a snatcher from the start
--   Spec     a whole roster entry instead of Critter (a Rift boss's:
--            DungeonRules.Bosses)
--   Scale    its body's scale (Kaiju.Bug.Scale), and its blows' and moves'
--            look with it
--   Health, Damage, Reach   times its kind's
--   Title    its nameplate
--   Stay     never slips back: it roams its patch (Wander) till someone
--            comes (the Rift's: Server.RiftServer)
--   Boss     a Rift boss (RiftBoss on its model, for the clients)
-- }
function KaijuWilds.spawnBug(at: Vector3, opts)
	Duelist = Duelist or require(script.Parent.Duelist)
	local spec = opts.Spec or rosterSpec(opts.Critter) or DungeonRules.Roster[rng:NextInteger(1, #DungeonRules.Roster)]
	local band = opts.Band or "Fringe"
	local level = opts.Level or Frontier.critterLevel(band, rng)
	local grow = 1 + Kaiju.Growth * (level - 1)
	local boost = Frontier.Boost[band] or Frontier.Boost.Fringe
	local scale = opts.Scale or Kaiju.Bug.Scale
	local ok, result = pcall(function()
		local color = GemConfig.ElementColors[spec.Element] or Color3.new(1, 1, 1)
		local rig = Duelist.creatureBody(spec, color)
		rig:ScaleTo(scale)
		for _, joint in rig:GetDescendants() do
			if joint:IsA("Motor6D") and joint:GetAttribute("CreatureMotion") then
				joint:SetAttribute("CreatureRest", joint.C0)
			end
		end
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.HipHeight = 1.9 * scale
		local foot = at + Vector3.new(0, humanoid.HipHeight + 1, 0)
		local facing = opts.Facing or (at + Vector3.new(0, 0, -1))
		local look = Vector3.new(facing.X, foot.Y, facing.Z)
		rig:PivotTo(if (look - foot).Magnitude > 0.1 then CFrame.lookAt(foot, look) else CFrame.new(foot))
		rig.Name = "Moon Bug"
		rig:SetAttribute("Posed", true) -- clients pose its body (BodyPoses)
		rig:SetAttribute("MoonBug", true)
		rig:SetAttribute("RiftBorn", true)
		rig:SetAttribute("CritterLevel", level)
		rig:SetAttribute("CritterRanged", Kaiju.isRanged(spec.Id) or nil) -- (kaiju dive the bomber)
		local kind = {
			Name = "Moon Bug",
			Health = math.floor(Kaiju.Bug.Health * grow * boost.Health * (opts.Health or 1) + 0.5),
			Damage = Kaiju.Bug.Damage * grow * boost.Damage * (opts.Damage or 1),
			Speed = Kaiju.Bug.Speed,
			Reach = Kaiju.Bug.Reach * (opts.Reach or 1),
			Rate = Kaiju.Bug.Rate,
			Aggro = Kaiju.Bug.Aggro,
			Coins = 0,
			DropChance = 0,
			Luck = 0,
			Respawn = 0,
		}
		local size = Kaiju.Bug.Size * scale / Kaiju.Bug.Scale
		local enemy = Enemies.adopt(rig, kind, {
			Element = spec.Element,
			Title = opts.Title or string.format("Moon Bug · %s · Lv %d", spec.Name, level),
			Home = at,
			Size = size,
		})
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
			Serial = serial + 1,
			Raider = (opts.Raider == true or opts.Robbery ~= nil) or nil,
			Stay = opts.Stay == true or nil,
			Size = if scale ~= Kaiju.Bug.Scale then size else nil,
			Robbery = opts.Robbery,
			Hell = opts.Hell == true or nil,
			OnGone = opts.OnGone,
		}
		serial += 1
		if opts.Raider or opts.Robbery then
			rig:SetAttribute("Raider", true)
		end
		if opts.Boss then
			rig:SetAttribute("RiftBoss", true)
		end
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
KaijuWilds._snatched, KaijuWilds._lunged = snatched, lunged
KaijuWilds._rushes = rushes
KaijuWilds._spawnWild, KaijuWilds._packs = spawnWild, packs
KaijuWilds._packAt = packAt
function KaijuWilds._site()
	return site
end
KaijuWilds._spawnGuardian, KaijuWilds._lifetimes = spawnGuardian, lifetimes
function KaijuWilds._guardian()
	return guardian
end
function KaijuWilds._setGuardAt(scar: CFrame?)
	guardAt = scar
end

return KaijuWilds
