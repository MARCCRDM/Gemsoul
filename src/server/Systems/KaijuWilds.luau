--[[
	Wild kaiju and moon bugs in the Outpost's far quarry (Shared.Kaiju has
	the numbers; see docs/kaiju.md).

	  Wild kaiju  up to Kaiju.Wild.Max roam at once, each a random kind and
	              element, levelled near the kaiju out around them. One
	              leaves you and your kaiju alone until you start a fight:
	              challenge it ("KaijuChallenge", its Challenge prompt) and
	              your kaiju goes in, or hit it while hunting (the combat
	              kit out: SparServer). It fights those who started on it
	              and their kaiju, and forgets them once home. It fights as the Arena's duellist does
	              (KaijuFighter: combos, telegraphed heavies, guard and
	              parry, hops, their Gemsoul's E), and walk home to heal if
	              led past their leash. Every blow on one lands anywhere from
	              60% to 140%, by element as well (TakenScale, which
	              Enemies.damage applies), and meets its guard there.
	              Killed: the one who (with their kaiju) did the most gets
	              its Gemsoul, and every kaiju that fought it gets EXP.
	              Tamed ("KaijuTame"): it joins you, Gemsoul and all. Three
	              failed tries and it burrows away; so does one left alone
	              for Kaiju.Wild.Lifetime.
	  Moon bugs   the little brainrot creatures (DungeonRules' roster,
	              shrunk), each through a rift of its own round a player out
	              past the core (FrontierServer: Shared.Frontier). One hops
	              out at whoever drew it (a miner too, or a mech's pilot:
	              KaijuWilds.prey) and goes for them, then their kaiju; with
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
	KaijuTries for the client's tame button.

	  "KaijuTame", model        try to tame a weakened wild kaiju (within 30 studs)
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
local KaijuFighter = require(script.Parent.KaijuFighter)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuWilds = {}

local TAME_RANGE = 30
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
}

local wilds: { [any]: Wild } = {} -- by Enemies record
local wildCount = 0
local spots: { Vector3 } = {}
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

local function spot(): Vector3?
	if #spots == 0 then
		return nil
	end
	local base = spots[rng:NextInteger(1, #spots)]
	local angle = rng:NextNumber(0, math.pi * 2)
	return base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(6, 12)
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
	end
end
local function engaged(wild: Wild, player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and wild.Engaged[player] ~= nil
end

-- Its foes near a point (for its E): only those who started on it.
local function foesOf(wild: Wild)
	return function(center: Vector3, radius: number): { any }
		local list = {}
		for _, victim in foesNear(center, radius) do
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
	elseif player and (hunter(player) or (wild ~= nil and wild.Bug and prey(player))) then
		local _, guarded = Enemies.hitPlayer(victim.Player, amount, element, enemy, heavy)
		return if guarded then "Guarded" else "Hit"
	end
	return "Missed"
end

-- Who it goes after: a rift's critter, whoever drew it while they're fair
-- game; then whoever hurt it last (a kaiju or a hunter), while they're
-- inside its leash; else its current foe; else the nearest it sees. A wild
-- kaiju only goes after those who started on it (a hit is starting on it)
-- and their kaiju.
local function chooseFoe(enemy, wild: Wild, aggro: number)
	local now = os.clock()
	local e = enemy :: any
	local rifted = wild.Bug
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
		if victim.Player and not (if rifted then prey(victim.Player) else hunter(victim.Player)) then
			return false
		end
		if not wild.Bug and not engaged(wild, if victim.Pet then victim.Pet.Owner else victim.Player) then
			return false
		end
		return (victim.Root.Position - enemy.Home).Magnitude <= leash
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
	for _, victim in foesNear(enemy.Root.Position, aggro, rifted) do
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

-- The brain both kinds share: find a foe and fight it (a wild kaiju as a
-- duellist, KaijuFighter; a moon bug chases and bites), else go home (a
-- rift's critter slips back through a rift).
local function brain(enemy, now: number)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	local e = enemy :: any
	local humanoid, root = enemy.Humanoid, enemy.Root
	local fighter = wild.Fighter
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
		-- Home, healing on the way; and home a while, it forgets who started
		-- on it.
		if fromHome > 4 then
			humanoid:MoveTo(enemy.Home)
		else
			for player, at in wild.Engaged do
				if now - at > CALM_AFTER then
					wild.Engaged[player] = nil
				end
			end
		end
		if now - enemy.LastHit > 6 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * HOME_HEAL * 0.15)
			enemy.Bar.Size = UDim2.fromScale(humanoid.Health / humanoid.MaxHealth, 1)
		end
		return
	end
	wild.LastFight = now
	engage(wild, if victim.Pet then victim.Pet.Owner else victim.Player, now)
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

-- Wild kaiju ------------------------------------------------------------------------------------------

local spawnWild

local function gone(wild: Wild)
	KaijuFighter.forget(wild.Fighter)
	wilds[wild.Enemy] = nil
	wildCount -= 1
	task.delay(Kaiju.Wild.Respawn, spawnWild)
end

-- Burrows away (left alone too long, or too many failed tames).
local function burrow(wild: Wild)
	local enemy = wild.Enemy
	if not enemy.Alive then
		return
	end
	fx("TriadBreak", enemy.Root.Position, 5, wild.Element)
	Enemies.remove(enemy)
	gone(wild)
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
					"Defeated a wild %s: its Gemsoul is yours (%s, E: %s).",
					title,
					GemConfig.displayName(soul),
					if move then move.Name else "?"
				)
			)
		else
			Remotes.Notify:FireClient(best, "Your gem pouch is full: the Gemsoul crumbled to dust.")
		end
		PlayerData.milestone(best, "KaijuSlain")
	end
	gone(wild)
end

function spawnWild()
	if wildCount >= Kaiju.Wild.Max then
		return
	end
	local at = spot()
	if not at then
		return
	end
	wildCount += 1
	local ok, err = pcall(function()
		local species = Kaiju.Order[rng:NextInteger(1, #Kaiju.Order)]
		local element = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
		local level = Kaiju.wildLevel(levelsNear(at, 160), rng)
		local soul = Kaiju.rollSoul(Gems.random(), element, {
			Id = "wild",
			Time = os.time(),
			Species = species,
			Luck = math.clamp(level / 60, 0, 0.5),
		})
		local stats = Kaiju.stats(species, level, soul.Tier)
		local model, _, _ = KaijuServer.body(species, element, Kaiju.Scale.Wild)
		local title = "Wild " .. Kaiju.title({ Species = species, Element = element })
		model.Name = title
		KaijuServer.place(model, at, at + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
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
		e.OutpostCreature = true
		e.Engaged = engagedBy -- (the kaiju out only fight it for those who started on it)
		e.Brain = brain
		e.OnDeath = wildDied
		-- Every blow lands 60%-140%, times its element against this one's
		-- and its kind's Guard.
		e.TakenScale = function(hitElement: string?)
			local mult, tag = Kaiju.taken(species, element, hitElement)
			return mult * Kaiju.spread(), tag
		end
		local ability = Kaiju.ability(soul)
		model:SetAttribute("KaijuWild", true)
		model:SetAttribute("KaijuLevel", level)
		model:SetAttribute("KaijuAbility", ability)
		model:SetAttribute("KaijuTries", 0)
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
			Scale = Kaiju.Scale.Wild,
			Body = enemy,
			Stats = stats,
			Ability = ability,
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
		wilds[enemy] = {
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
		}
	end)
	if not ok then
		wildCount -= 1
		warn("[Kaiju] wild spawn failed:", err)
	end
end

-- Taming --------------------------------------------------------------------------------------------------

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
	wild.TameAt[player] = now
	local title = Kaiju.title({ Species = wild.Species, Element = wild.Element })
	if rng:NextNumber() < chance then
		local soul = table.clone(wild.Soul)
		soul.Id = PlayerData.newGemId()
		local record = KaijuServer.adopt(player, wild.Species, soul, wild.Level)
		if not record then
			return reply(false, "Couldn't tame it right now.")
		end
		fx("TriadBreak", enemy.Root.Position, 6, wild.Element)
		Enemies.remove(enemy)
		gone(wild)
		PlayerData.milestone(player, "KaijuTamed")
		return reply(
			true,
			string.format("Tamed! The %s (level %d) is yours.", title, wild.Level),
			{ Tamed = true, Chance = chance, Id = record.Id }
		)
	end
	wild.Tries += 1
	enemy.Model:SetAttribute("KaijuTries", wild.Tries)
	if wild.Tries >= Kaiju.TameTries then
		burrow(wild)
		return reply(
			false,
			string.format("The %s broke free and burrowed away!", title),
			{ Chance = chance, Gone = true }
		)
	end
	return reply(
		false,
		string.format(
			"It broke free! (%d%% chance) %d tr%s left.",
			math.floor(chance * 100 + 0.5),
			Kaiju.TameTries - wild.Tries,
			if Kaiju.TameTries - wild.Tries == 1 then "y" else "ies"
		),
		{ Chance = chance }
	)
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

-- A wild kaiju nobody's fought for a while, past its lifetime, burrows.
local function lifetimes(now: number)
	for _, wild in wilds do
		if not wild.Bug and wild.Enemy.Alive then
			local fought = math.max(wild.Enemy.LastHit or 0, wild.LastFight or 0)
			if now - wild.Born > Kaiju.Wild.Lifetime and now - fought > 20 then
				burrow(wild)
			end
		end
	end
end

-- `site` is the Outpost's (OutpostServer.site()): wild things roam its
-- rock spots far from the landing pad.
function KaijuWilds.start(site)
	if not site or not site.Spots then
		warn("[Kaiju] no Outpost site: no wild kaiju")
		return
	end
	local pad = site.Spawn.Position
	for _, cframe in site.Spots do
		if flat(cframe.Position - pad).Magnitude >= Kaiju.Wild.FarFromSpawn then
			table.insert(spots, cframe.Position)
		end
	end
	if #spots == 0 then
		for _, cframe in site.Spots do
			table.insert(spots, cframe.Position)
		end
	end
	Shop.register("KaijuTame", tame)
	Shop.register("KaijuChallenge", challenge)
	-- (Moon bugs come through rifts round players out past the core: FrontierServer.)
	task.delay(5, function()
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
KaijuWilds._spawnWild, KaijuWilds._spots = spawnWild, spots

return KaijuWilds
