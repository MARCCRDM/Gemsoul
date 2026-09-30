--[[
	Runs combat for players: basic attacks, abilities, resources, buffs and
	the damage monsters deal back. The client only says what it pressed and
	where it aimed (CombatInput); everything else is decided here.

	CombatInput:
	  "Attack", aim             basic attack with the equipped weapon
	  "Ability", slot, aim      slot 1-3 = Q/E/R from your picks, 4 = ultimate
	Request actions:
	  "SetAbilities", { id, id, id }   choose the three on Q / E / R

	CombatFx (to clients) carries what to draw: swings, shots, novas, zones,
	damage numbers; and to the caster: "Cooldown" and "Dash" (the client
	moves its own character for dashes, rolls and blinks).

	Player state is published as attributes: Resource, ResourceMax,
	ResourceKind, Shield.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local CombatServer = {}

type Buff = { Until: number, DamageMult: number, TakenMult: number, RateMult: number }
type State = {
	Resource: number,
	LastCombat: number,
	Cooldowns: { [string]: number },
	NextAttack: number,
	Swings: number,
	Buffs: { Buff },
	Shield: number,
	ShieldUntil: number,
	NextWard: number,
	Inputs: number, -- inputs this second, to ignore spam
	InputWindow: number,
}

local states: { [Player]: State } = {}

local WHITE = Color3.new(1, 1, 1)
local CRIT = Color3.fromRGB(255, 220, 80)
local BLEED = Color3.fromRGB(200, 40, 40)
local POISON = GemConfig.ElementColors.Poison
local FIRE = GemConfig.ElementColors.Fire

-- Setup ---------------------------------------------------------------------------------------

type Kit = {
	Class: any,
	Weapon: any,
	Armor: any,
	Ratings: { [string]: any },
	Loadout: { [string]: any },
	Resource: Combat.Resource,
	Effects: { [string]: any }, -- weapon + armor passive effects merged
}

-- Everything about the player's build that combat needs, fresh each time.
local function kit(player: Player): Kit?
	local loadout = PlayerData.character(player)
	local class = loadout and Classes.get(loadout.Class)
	if not loadout or not class then
		return nil
	end
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	local armor = Classes.armor(loadout.Class, loadout.Armor)
	if not weapon or not armor then
		return nil
	end
	local effects = {}
	for key, value in armor.Passive.Effect do
		effects[key] = value
	end
	for key, value in weapon.Passive.Effect do
		effects[key] = if key == "TakenMult" and effects.TakenMult then effects.TakenMult * value else value
	end
	return {
		Class = class,
		Weapon = weapon,
		Armor = armor,
		Ratings = Classes.ratings(loadout),
		Loadout = loadout,
		Resource = Combat.Resources[class.ResourceId],
		Effects = effects,
	}
end

local function rating(k: Kit, stat: string): number
	return k.Ratings[stat].Base + k.Ratings[stat].Bonus
end

local function state(player: Player): State
	local current = states[player]
	if not current then
		local k = kit(player)
		current = {
			Resource = if k then k.Resource.Start else 0,
			LastCombat = 0,
			Cooldowns = {},
			NextAttack = 0,
			Swings = 0,
			Buffs = {},
			Shield = 0,
			ShieldUntil = 0,
			NextWard = 0,
			Inputs = 0,
			InputWindow = 0,
		}
		states[player] = current
	end
	return current
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root
	end
	return nil, nil
end

local function buffTotal(st: State, field: string): number
	local total = 1
	local now = os.clock()
	for _, buff in st.Buffs do
		if now < buff.Until then
			total *= (buff :: any)[field]
		end
	end
	return total
end

local function gainResource(player: Player, st: State, amount: number)
	local k = kit(player)
	if k and amount ~= 0 then
		st.Resource = math.clamp(st.Resource + amount, 0, k.Resource.Max)
	end
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

-- Targeting ------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function radiusOf(enemy: Enemies.Enemy): number
	local size = enemy.Root.Size
	return math.max(size.X, size.Z) / 2 + 0.5
end

local function inCone(origin: Vector3, direction: Vector3, range: number, arc: number): { Enemies.Enemy }
	local found = {}
	local cosHalf = math.cos(math.rad(arc / 2))
	for _, enemy in Enemies.all() do
		local offset = enemy.Root.Position - origin
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= range + radiusOf(enemy) and math.abs(offset.Y) < 10 then
			if distance < radiusOf(enemy) or flat(offset):Dot(direction) >= cosHalf then
				table.insert(found, enemy)
			end
		end
	end
	return found
end

local function inRadius(center: Vector3, radius: number): { Enemies.Enemy }
	local found = {}
	for _, enemy in Enemies.all() do
		local offset = enemy.Root.Position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + radiusOf(enemy) and math.abs(offset.Y) < 12 then
			table.insert(found, enemy)
		end
	end
	return found
end

-- Enemies along a shot from `origin` toward `aim`, nearest first.
local function alongLine(origin: Vector3, aim: Vector3, range: number): { Enemies.Enemy }
	local direction = aim - origin
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
	local hits = {}
	for _, enemy in Enemies.all() do
		local offset = enemy.Root.Position - origin
		local along = offset:Dot(direction)
		if along > 0 and along <= range + radiusOf(enemy) then
			local miss = (offset - direction * along).Magnitude
			-- A little forgiving: aim near a monster and you'll hit it.
			if miss <= radiusOf(enemy) + 1.5 then
				table.insert(hits, { Enemy = enemy, Along = along })
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.Along < b.Along
	end)
	local list = {}
	for _, hit in hits do
		table.insert(list, hit.Enemy)
	end
	return list
end

local function nearestOther(enemy: Enemies.Enemy, radius: number, skip: { [any]: boolean }): Enemies.Enemy?
	local best, bestDistance = nil, radius
	for _, other in Enemies.all() do
		if other ~= enemy and not skip[other] then
			local distance = (other.Root.Position - enemy.Root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local function clampAim(root: BasePart, aim: Vector3, range: number): Vector3
	local offset = aim - root.Position
	if offset.Magnitude > range then
		return root.Position + offset.Unit * range
	end
	return aim
end

-- Hitting ---------------------------------------------------------------------------------------

type HitOptions = {
	Finisher: boolean?,
	Extras: { [string]: any }?, -- ability extras: Stun, Slow, SlowTime, Taunt, Burn, Poison, Execute...
	NoProcs: boolean?, -- zone ticks and chain echoes don't re-trigger passives
}

local function hit(player: Player, k: Kit, st: State, enemy: Enemies.Enemy, base: number, opts: HitOptions?)
	local o = opts or {}
	local extras = o.Extras or {}
	local _, root = alive(player)
	local damage = base * Combat.powerMult(rating(k, "Power")) * buffTotal(st, "DamageMult")
	if o.Finisher then
		damage *= Combat.FinisherMult
	end
	if k.Effects.FarBonus and root and (enemy.Root.Position - root.Position).Magnitude > 30 then
		damage *= 1 + k.Effects.FarBonus
	end
	local health = enemy.Humanoid
	if extras.ExecuteBelow and health.Health / health.MaxHealth < extras.ExecuteBelow then
		damage *= extras.ExecuteMult or 2
	end
	local crit = math.random() < Combat.critChance(rating(k, "Speed"), k.Effects.CritAdd)
	if crit then
		damage *= Combat.CritMult
	end
	local gem = k.Loadout.WeaponGem
	local color = if crit then CRIT elseif gem then GemConfig.ElementColors[gem.Element] else WHITE
	Enemies.damage(enemy, damage, player, crit, color)
	if not enemy.Alive then
		return
	end

	-- Ability extras.
	if extras.Stun then
		Enemies.addStatus(enemy, "Stun", 1, extras.Stun)
	end
	if extras.Slow then
		Enemies.addStatus(enemy, "Slow", extras.Slow, extras.SlowTime or 2)
	end
	if extras.Taunt then
		Enemies.taunt(enemy, player, extras.Taunt)
	end
	if extras.Burn then
		Enemies.addDot(enemy, damage * extras.Burn, 3, player, FIRE)
	end
	if extras.Poison then
		Enemies.addDot(enemy, damage * extras.Poison, 5, player, POISON)
	end
	if o.NoProcs then
		return
	end

	-- Weapon passives.
	local e = k.Effects
	if e.Sunder then
		Enemies.addStatus(enemy, "Sunder", e.Sunder, 5)
	end
	if e.Bleed then
		Enemies.addDot(enemy, damage * e.Bleed, 3, player, BLEED)
	end
	if e.SlowOnHit then
		Enemies.addStatus(enemy, "Slow", e.SlowOnHit, 2)
	end
	if e.FinisherStun and o.Finisher then
		Enemies.addStatus(enemy, "Stun", 1, e.FinisherStun)
	end
	if e.ResourceOnHit then
		gainResource(player, st, e.ResourceOnHit)
	end

	-- The weapon's socketed gem.
	if gem then
		local v = GemConfig.enchantValues(gem, "Weapon")
		if v.Burn then
			Enemies.addDot(enemy, v.Burn, 3, player, FIRE)
		elseif v.Slow then
			Enemies.addStatus(enemy, "Slow", v.Slow, 2)
		elseif v.Weaken then
			Enemies.addStatus(enemy, "Weaken", v.Weaken, 4)
		elseif v.Arc then
			local other = nearestOther(enemy, 14, {})
			if other then
				fx("Arc", enemy.Root.Position, other.Root.Position, GemConfig.ElementColors.Shock)
				Enemies.damage(other, damage * v.Arc, player, false, GemConfig.ElementColors.Shock)
			end
		end
	end

	-- Hitting things builds Rage and Resolve.
	gainResource(player, st, k.Resource.OnHit)
	st.LastCombat = os.clock()
end

-- A projectile: first enemy in the way (or all with pierce), then splash and
-- chain. Returns where it ended, for the tracer.
local function shoot(
	player: Player,
	k: Kit,
	st: State,
	origin: Vector3,
	aim: Vector3,
	range: number,
	damage: number,
	settings: { [string]: any }
): Vector3
	local targets = alongLine(origin, aim, range)
	local direction = (aim - origin)
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
	local finish = origin + direction * math.min(range, (aim - origin).Magnitude)
	if #targets == 0 then
		return finish
	end
	if not settings.Pierce then
		targets = { targets[1] }
	end
	finish = targets[#targets].Root.Position
	local struck = {}
	for _, enemy in targets do
		struck[enemy] = true
		hit(player, k, st, enemy, damage, { Extras = settings })
	end
	local first = targets[1]
	if settings.Splash then
		fx("Nova", first.Root.Position, settings.Splash, GemConfig.ElementColors.Fire, 0)
		for _, enemy in inRadius(first.Root.Position, settings.Splash) do
			if not struck[enemy] then
				struck[enemy] = true
				hit(player, k, st, enemy, damage * 0.5, { Extras = settings, NoProcs = true })
			end
		end
	end
	if settings.Chain then
		-- A number of jumps (abilities) or a fraction for one jump (Storm Scepter).
		local jumps = if settings.Chain >= 1 then settings.Chain else 1
		local share = if settings.Chain >= 1 then 0.8 else settings.Chain
		local from = first
		for _ = 1, jumps do
			local nextEnemy = nearestOther(from, 16, struck)
			if not nextEnemy then
				break
			end
			struck[nextEnemy] = true
			fx("Arc", from.Root.Position, nextEnemy.Root.Position, GemConfig.ElementColors.Shock)
			hit(player, k, st, nextEnemy, damage * share, { Extras = settings, NoProcs = true })
			from = nextEnemy
		end
	end
	return finish
end

-- Basic attacks ------------------------------------------------------------------------------------

local function attack(player: Player, aim: Vector3)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not root or not k.Weapon.Attack then
		return
	end
	local st = state(player)
	local now = os.clock()
	local a = k.Weapon.Attack
	-- A little slack for network jitter.
	if now < st.NextAttack - 0.08 then
		return
	end
	st.NextAttack = now + a.Rate * buffTotal(st, "RateMult")
	st.LastCombat = now
	local color = k.Class.Color
	local gem = k.Loadout.WeaponGem
	if gem then
		color = GemConfig.ElementColors[gem.Element]
	end
	if a.Kind == "Melee" then
		st.Swings += 1
		local finisher = a.Combo ~= nil and st.Swings % a.Combo == 0
		local direction = flat(aim - root.Position)
		fx("Swing", player, root.Position, direction, a.Range, a.Arc or 90, color, finisher)
		for _, enemy in inCone(root.Position, direction, a.Range, a.Arc or 90) do
			hit(player, k, st, enemy, a.Damage, { Finisher = finisher })
		end
	else
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local target = clampAim(root, aim, a.Range)
		local finish = shoot(player, k, st, origin, target, a.Range, a.Damage, {
			Pierce = k.Effects.Pierce,
			Splash = k.Effects.Splash,
			Chain = k.Effects.Chain,
		})
		fx("Shot", player, origin, finish, color, k.Weapon.Look)
	end
end

-- Abilities -------------------------------------------------------------------------------------------

local function applyBuff(player: Player, st: State, ability: any)
	local humanoid = alive(player)
	if ability.Duration and ability.Duration > 0 then
		table.insert(st.Buffs, {
			Until = os.clock() + ability.Duration,
			DamageMult = ability.DamageMult or 1,
			TakenMult = ability.TakenMult or 1,
			RateMult = ability.RateMult or 1,
		})
	end
	if ability.Heal and humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * ability.Heal)
	end
	if ability.Shield then
		st.Shield = math.max(st.Shield, ability.Shield)
		st.ShieldUntil = os.clock() + (ability.Duration or 8)
	end
end

local function cast(player: Player, slot: number, aim: Vector3)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not root then
		return
	end
	local ability = if slot == 4 then k.Class.Ultimate else Classes.loadout(k.Class.Id, k.Loadout.Abilities)[slot]
	if not ability then
		return
	end
	local st = state(player)
	local now = os.clock()
	if (st.Cooldowns[ability.Id] or 0) > now + 0.1 then
		return
	end
	local cost = ability.Cost or 0
	if st.Resource < cost then
		Remotes.CombatFx:FireClient(player, "NoResource", ability.Id)
		return
	end
	st.Resource -= cost
	gainResource(player, st, ability.Gain or 0)
	local cooldown = ability.Cooldown * (k.Effects.CooldownMult or 1)
	st.Cooldowns[ability.Id] = now + cooldown
	st.LastCombat = now
	Remotes.CombatFx:FireClient(player, "Cooldown", ability.Id, cooldown)

	local color = k.Class.Color
	local kind = ability.Kind
	if kind == "Cone" then
		local direction = flat(aim - root.Position)
		fx("Swing", player, root.Position, direction, ability.Range, ability.Arc, color, true)
		for _, enemy in inCone(root.Position, direction, ability.Range, ability.Arc) do
			hit(player, k, st, enemy, ability.Damage, { Extras = ability })
		end
	elseif kind == "Nova" then
		local center = if ability.AtTarget then clampAim(root, aim, ability.TargetRange) else root.Position
		local delay = ability.Delay or 0
		fx("Nova", center, ability.Radius, color, delay)
		task.delay(delay, function()
			if (ability.Damage or 0) > 0 then
				for _, enemy in inRadius(center, ability.Radius) do
					hit(player, k, st, enemy, ability.Damage, { Extras = ability })
				end
			elseif ability.Taunt then
				for _, enemy in inRadius(center, ability.Radius) do
					Enemies.taunt(enemy, player, ability.Taunt)
				end
			end
		end)
	elseif kind == "Dash" then
		-- The client moves itself; hit around where it lands.
		Remotes.CombatFx:FireClient(
			player,
			"Dash",
			ability.Distance,
			ability.Backward == true,
			ability.Teleport == true,
			aim
		)
		if ability.Damage then
			task.delay(0.35, function()
				local _, landed = alive(player)
				if landed then
					fx("Nova", landed.Position, ability.Radius, color, 0)
					for _, enemy in inRadius(landed.Position, ability.Radius) do
						hit(player, k, st, enemy, ability.Damage, { Extras = ability })
					end
				end
			end)
		end
	elseif kind == "Bolt" then
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local target = clampAim(root, aim, ability.Range)
		local finish = shoot(player, k, st, origin, target, ability.Range, ability.Damage, ability)
		fx("Shot", player, origin, finish, color, ability.Id)
	elseif kind == "Buff" then
		applyBuff(player, st, ability)
		fx("Buff", player, color)
		if ability.TauntRadius then
			fx("Nova", root.Position, ability.TauntRadius, color, 0)
			for _, enemy in inRadius(root.Position, ability.TauntRadius) do
				Enemies.taunt(enemy, player, ability.Taunt or 5)
			end
		end
	elseif kind == "Zone" then
		local center = clampAim(root, aim, ability.TargetRange or 40)
		fx("Zone", center, ability.Radius, ability.Duration, color)
		local ticks = math.floor(ability.Duration / 0.5)
		task.spawn(function()
			for _ = 1, ticks do
				task.wait(0.5)
				for _, enemy in inRadius(center, ability.Radius) do
					hit(player, k, st, enemy, ability.Tick or 0, { Extras = ability, NoProcs = true })
				end
			end
		end)
	end
end

-- Taking damage ------------------------------------------------------------------------------------------

function CombatServer.hurt(player: Player, amount: number, element: string?)
	local humanoid, root = alive(player)
	local k = kit(player)
	if not humanoid or not root or not k then
		return
	end
	local st = state(player)
	local damage = amount * Combat.defenseMult(rating(k, "Defense"))
	damage *= (k.Effects.TakenMult or 1) * buffTotal(st, "TakenMult")
	local armorGem = k.Loadout.ArmorGem
	if element and armorGem and armorGem.Element == element then
		damage *= 1 - GemConfig.enchantValues(armorGem, "Armor").Resist
	end
	damage = math.max(1, math.floor(damage + 0.5))
	if st.Shield > 0 and os.clock() < st.ShieldUntil then
		local absorbed = math.min(st.Shield, damage)
		st.Shield -= absorbed
		damage -= absorbed
	end
	fx("Damage", root.Position + Vector3.new(0, 3, 0), damage, false, Color3.fromRGB(255, 80, 80))
	if damage > 0 then
		humanoid:TakeDamage(damage)
	end
	gainResource(player, st, k.Resource.OnHurt)
	st.LastCombat = os.clock()
end

-- Loadout ---------------------------------------------------------------------------------------------

local function setAbilities(player: Player, ids: any)
	local loadout = PlayerData.character(player)
	local class = loadout and Classes.get(loadout.Class)
	if not class then
		return Shop.reply(false, "Choose a class first.")
	end
	if typeof(ids) ~= "table" or #ids ~= 3 then
		return Shop.reply(false, "Pick three abilities.")
	end
	local seen = {}
	for _, id in ids do
		local ability = Classes.ability(class.Id, id)
		if typeof(id) ~= "string" or not ability or ability.Ultimate or seen[id] then
			return Shop.reply(false, "Those abilities don't work together.")
		end
		seen[id] = true
	end
	PlayerData.setAbilities(player, { ids[1], ids[2], ids[3] })
	return Shop.reply(true, "Abilities set.")
end

-- Wiring -----------------------------------------------------------------------------------------------

local function onInput(player: Player, action: any, a: any, b: any)
	local st = state(player)
	local now = os.clock()
	-- Ignore floods: a real player can't press more than ~20 things a second.
	if now - st.InputWindow > 1 then
		st.InputWindow, st.Inputs = now, 0
	end
	st.Inputs += 1
	if st.Inputs > 20 then
		return
	end
	local _, root = alive(player)
	if not root or not Combat.canFight(root.Position) then
		return
	end
	if action == "Attack" and typeof(a) == "Vector3" then
		attack(player, a)
	elseif action == "Ability" and typeof(a) == "number" and typeof(b) == "Vector3" then
		local slot = math.floor(a)
		if slot >= 1 and slot <= 4 then
			cast(player, slot, b)
		end
	end
end

-- Resources, wards and shields tick four times a second.
local function tick(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local k = kit(player)
		if k then
			local st = state(player)
			local r = k.Resource
			if r.Regen > 0 or now - st.LastCombat > Combat.InCombatSeconds then
				st.Resource = math.clamp(st.Resource + r.Regen * dt, 0, r.Max)
			end
			if k.Effects.Ward and now >= st.NextWard then
				st.NextWard = now + 8
				st.Shield = math.max(st.Shield, k.Effects.Ward)
				st.ShieldUntil = now + 8
			end
			if now >= st.ShieldUntil then
				st.Shield = 0
			end
			for i = #st.Buffs, 1, -1 do
				if now >= st.Buffs[i].Until then
					table.remove(st.Buffs, i)
				end
			end
			player:SetAttribute("Resource", math.floor(st.Resource))
			player:SetAttribute("ResourceMax", r.Max)
			player:SetAttribute("ResourceKind", k.Class.ResourceId)
			player:SetAttribute("Shield", math.floor(st.Shield))
		end
	end
end

function CombatServer.start()
	Enemies.hitPlayer = function(player, amount, element)
		CombatServer.hurt(player, amount, element)
	end
	Remotes.CombatInput.OnServerEvent:Connect(onInput)
	Shop.register("SetAbilities", setAbilities)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	-- A fresh life starts with a fresh resource bar.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local st = states[player]
			if st then
				local k = kit(player)
				st.Resource = if k then k.Resource.Start else 0
				st.Buffs = {}
				st.Shield = 0
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 0.25 then
			tick(timer)
			timer = 0
		end
	end)
end

-- For tests.
CombatServer._attack = attack
CombatServer._cast = cast
CombatServer._state = state

return CombatServer
