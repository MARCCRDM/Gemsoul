--[[
	Wild kaiju and moon bugs in the Outpost's far quarry (Shared.Kaiju has
	the numbers; see docs/kaiju.md).

	  Wild kaiju  up to Kaiju.Wild.Max roam at once, each a random kind and
	              element, levelled near the kaiju out around them. They go
	              after kaiju that come near and anyone hunting (the combat
	              kit out: SparServer), cast their Gemsoul's E, and walk home
	              to heal if led past their leash. Every blow on one lands
	              anywhere from 60% to 140%, by element as well (TakenScale,
	              which Enemies.damage applies).
	              Killed: the one who (with their kaiju) did the most gets
	              its Gemsoul, and every kaiju that fought it gets EXP.
	              Tamed ("KaijuTame"): it joins you, Gemsoul and all. Three
	              failed tries and it burrows away; so does one left alone
	              for Kaiju.Wild.Lifetime.
	  Moon bugs   swarms of the little brainrot creatures (DungeonRules'
	              roster, shrunk), for kaiju EXP and a few coins a day.

	Both are ordinary Enemies (so every attack, status and nameplate works on
	them) with their own brains, marked OutpostCreature for the kaiju out.
	A wild kaiju's model carries KaijuWild, KaijuLevel, KaijuAbility and
	KaijuTries for the client's tame button.

	  "KaijuTame", model   try to tame a weakened wild kaiju (within 30 studs)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuAbilities = require(script.Parent.KaijuAbilities)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuWilds = {}

local TAME_RANGE = 30
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
	NextAbility: number,
	LastFight: number?,
	Bug: boolean,
	Swarm: any?,
}

local wilds: { [any]: Wild } = {} -- by Enemies record
local wildCount, swarmCount = 0, 0
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

-- Its foes inside a circle: kaiju out (not recalled) and hunters.
local function foesNear(center: Vector3, radius: number): { any }
	local list = {}
	for _, pet in KaijuServer.pets() do
		if KaijuServer.targetable(pet) and (pet.Root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = pet.Root, Pet = pet })
		end
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and hunter(player) and (root.Position - center).Magnitude <= radius then
			table.insert(list, { Root = root, Player = player })
		end
	end
	return list
end

local function hitFoe(enemy, victim, amount: number, element: string?, status: string?)
	if victim.Pet then
		KaijuServer.hurt(victim.Pet, amount, element, status)
	elseif victim.Player and hunter(victim.Player) then
		Enemies.hitPlayer(victim.Player, amount, element, enemy)
	end
end

-- Who it goes after: whoever hurt it last (a kaiju or a hunter), while
-- they're inside its leash; else its current foe; else the nearest it sees.
local function chooseFoe(enemy, wild: Wild, aggro: number)
	local now = os.clock()
	local e = enemy :: any
	local leash = Kaiju.Wild.Leash
	local function valid(victim): boolean
		if not victim or not victim.Root or not victim.Root.Parent then
			return false
		end
		if victim.Pet and not KaijuServer.targetable(victim.Pet) then
			return false
		end
		if victim.Player and not hunter(victim.Player) then
			return false
		end
		return (victim.Root.Position - enemy.Home).Magnitude <= leash
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
	for _, victim in foesNear(enemy.Root.Position, aggro) do
		local distance = (victim.Root.Position - enemy.Root.Position).Magnitude
		if valid(victim) and distance <= bestDistance then
			best, bestDistance = victim, distance
		end
	end
	return best
end

-- The brain both kinds share: chase, strike, cast (a wild kaiju), go home.
local function brain(enemy, now: number)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	local e = enemy :: any
	local humanoid, root = enemy.Humanoid, enemy.Root
	if now < enemy.StunUntil then
		humanoid:MoveTo(root.Position)
		return
	end
	local kind = enemy.Kind
	humanoid.WalkSpeed = kind.Speed * (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
	local fromHome = flat(root.Position - enemy.Home).Magnitude
	local victim = if fromHome <= Kaiju.Wild.Leash then chooseFoe(enemy, wild, kind.Aggro) else nil
	e.FoeVictim = victim
	e.Foe = if victim then (victim.Pet or victim.Player) else nil
	if not victim then
		-- Home, healing on the way; and the tries on it are forgotten there.
		if fromHome > 4 then
			humanoid:MoveTo(enemy.Home)
		end
		if now - enemy.LastHit > 6 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * HOME_HEAL * 0.15)
			enemy.Bar.Size = UDim2.fromScale(humanoid.Health / humanoid.MaxHealth, 1)
		end
		wild.NextAbility = 0
		return
	end
	wild.LastFight = now
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
	-- Its E, a moment into the fight and then every AbilityEvery seconds.
	if wild.Ability then
		if wild.NextAbility == 0 then
			wild.NextAbility = now + 4
		elseif now >= wild.NextAbility then
			wild.NextAbility = now + Kaiju.AbilityEvery
			local element = wild.Element
			local cast = KaijuAbilities.cast({
				Model = enemy.Model,
				Root = root,
				Element = element,
				Ability = wild.Ability,
				Damage = Kaiju.abilityDamage(kind.Damage, wild.Soul, wild.Ability),
				Foes = foesNear,
				Hit = function(target, amount: number, status: string?)
					hitFoe(enemy, target, amount, element, status)
				end,
				Alive = function(): boolean
					return enemy.Alive
				end,
			}, victim)
			if cast then
				enemy.Model:SetAttribute("ActionAt", serverNow())
				enemy.LastAttack = now
				return
			end
		end
	end
	if now - enemy.LastAttack >= kind.Rate then
		enemy.LastAttack = now
		enemy.Model:SetAttribute("ActionAt", serverNow())
		if wild.Bug then
			fx("EnemySwing", root.Position, victim.Root.Position, GemConfig.ElementColors[wild.Element])
		end
		if now < (e.BlindUntil or 0) and math.random() < (e.Blind or 0) then
			return -- swung at nothing
		end
		hitFoe(enemy, victim, kind.Damage * (1 - Enemies.weakness(enemy)), wild.Element, nil)
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
		e.OutpostCreature = true
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
			NextAbility = 0,
			Bug = false,
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

-- Moon bugs -------------------------------------------------------------------------------------------------

local Duelist -- (required when the first swarm spawns: it's a big module)

local function bugDied(enemy)
	local wild = wilds[enemy]
	if not wild then
		return
	end
	wilds[enemy] = nil
	local best = credits(enemy)
	if best then
		KaijuServer.reward(best, Kaiju.Bug.Exp)
		local profile = PlayerData.get(best)
		if profile then
			local roster = Kaiju.roster(profile)
			local day = math.floor(os.time() / 86400)
			local left = Kaiju.bugCoins(roster.Bugs, day)
			local coins = math.min(Kaiju.Bug.Coins, left)
			if coins > 0 then
				if not roster.Bugs or roster.Bugs.Day ~= day then
					roster.Bugs = { Day = day, Coins = 0 }
				end
				roster.Bugs.Coins += coins
				PlayerData.addCoins(best, coins)
			end
		end
	end
	local swarm = wild.Swarm
	if swarm then
		swarm.Left -= 1
		if swarm.Left <= 0 then
			swarmCount -= 1
			task.delay(Kaiju.Bug.Respawn, KaijuWilds.spawnSwarm)
		end
	end
end

function KaijuWilds.spawnSwarm()
	if swarmCount >= Kaiju.Bug.Swarms then
		return
	end
	local center = spot()
	if not center then
		return
	end
	Duelist = Duelist or require(script.Parent.Duelist)
	local spec = DungeonRules.Roster[rng:NextInteger(1, #DungeonRules.Roster)]
	local levels = levelsNear(center, 160)
	local level = 1
	for _, l in levels do
		level = math.max(level, l)
	end
	local grow = 1 + Kaiju.Growth * (level - 1)
	local size = rng:NextInteger(Kaiju.Bug.SwarmSize[1], Kaiju.Bug.SwarmSize[2])
	local swarm = { Left = 0 }
	swarmCount += 1
	for _ = 1, size do
		local ok, err = pcall(function()
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
			local angle = rng:NextNumber(0, math.pi * 2)
			local at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(2, 7)
			local floor = KaijuServer.ground(at)
			rig:PivotTo(CFrame.new(floor + Vector3.new(0, humanoid.HipHeight + 1, 0)) * CFrame.Angles(0, angle, 0))
			rig.Name = "Moon Bug"
			rig:SetAttribute("Posed", true) -- clients pose its body (BodyPoses)
			rig:SetAttribute("MoonBug", true)
			local kind = {
				Name = "Moon Bug",
				Health = math.floor(Kaiju.Bug.Health * grow + 0.5),
				Damage = Kaiju.Bug.Damage * grow,
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
				{ Element = spec.Element, Title = string.format("Moon Bug · %s", spec.Name), Home = floor }
			)
			local e = enemy :: any
			e.OutpostCreature = true
			e.Brain = brain
			e.OnDeath = bugDied
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
				NextAbility = 0,
				Bug = true,
				Swarm = swarm,
			}
			swarm.Left += 1
		end)
		if not ok then
			warn("[Kaiju] moon bug spawn failed:", err)
		end
	end
	if swarm.Left == 0 then
		swarmCount -= 1
	end
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
	task.delay(5, function()
		for _ = 1, Kaiju.Wild.Max do
			spawnWild()
		end
		for _ = 1, Kaiju.Bug.Swarms do
			KaijuWilds.spawnSwarm()
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
KaijuWilds._spawnWild, KaijuWilds._spots = spawnWild, spots

return KaijuWilds
