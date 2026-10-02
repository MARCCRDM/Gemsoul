-- Server-authoritative universal actions. Only opted-in Arena players can damage each other.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Classes = require(ReplicatedStorage.Shared.Classes)
local EquipmentBalance = require(ReplicatedStorage.Shared.EquipmentBalance)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CrowdControl = require(ReplicatedStorage.Shared.CrowdControl)
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)
local CombatServer = {}
local states = {}
local WHITE = Color3.new(1, 1, 1)
local function fx(kind, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end
local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return humanoid, root
	end
	return nil, nil
end
local function kit(player)
	local loadout = PlayerData.character(player)
	local weapon = loadout and Classes.weapon(loadout.Class, loadout.Weapon)
	if not weapon or not weapon.Attack then
		return nil
	end
	local effects = Classes.effects(loadout)
	local affinity = Classes.affinities(loadout)
	local defense = {
		Shield = 0,
		Duration = GemConfig.Rules.ShieldBaseDuration,
		Cooldown = GemConfig.Rules.ShieldBaseCooldown,
		Resistance = 0,
		Reflect = 0,
		ReflectThermal = 0,
		Deflect = 0,
		Aura = 0,
		CleanseInterval = math.huge,
	}
	local recharge, cooldownCut = 0, 0
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local gem = loadout[slot .. "Gem"]
		if gem then
			local v = GemConfig.stats(gem, slot, { Affinity = affinity })
			defense.Shield += v.ShieldAmount or 0
			defense.Duration += v.ShieldDuration or 0
			cooldownCut += v.CooldownCut or 0
			recharge += v.RechargeRate or 0
			defense.Resistance += v.Resistance or 0
			defense.Reflect += v.ReflectChance or 0
			defense.Deflect += v.DeflectChance or 0
			defense.Aura += v.AuraShred or 0
			if gem.Element == "Fire" then
				defense.ReflectThermal = 0.10
			end
			if v.CleanseRate then
				defense.CleanseInterval = math.min(defense.CleanseInterval, GemConfig.cleanseInterval(v.CleanseRate))
			end
		end
	end
	defense.Cooldown = math.max(GemConfig.Rules.ShieldMinCooldown, defense.Cooldown - cooldownCut) / (1 + recharge)
	return {
		Affinity = affinity,
		Defense = defense,
		Loadout = loadout,
		Weapon = weapon,
		Effects = effects,
		Ratings = Classes.ratings(loadout),
		Rules = Actions.resolve(
			Classes.setState(loadout).Counts,
			if weapon.Attack.Kind == "Melee" then "Sword" else "Pistol",
			1 - (effects.CooldownMult or 1)
		),
	}
end
local function rating(k, stat)
	return k.Ratings[stat].Base + k.Ratings[stat].Bonus
end
local function state(player)
	if not states[player] then
		states[player] = {
			Resources = { Stamina = 100, Charge = 100 },
			ResourceAt = os.clock(),
			TechCooldowns = {},
			NextTech = 0,
			Pending = {},
			SiphonUntil = 0,
			SiphonCapacity = 0,
			EchoUntil = 0,
			NextAttack = 0,
			NextDodge = 0,
			BlockUntil = 0,
			BlockBrokenUntil = 0,
			Shield = 0,
			ShieldUntil = 0,
			NextWard = 0,
			NextBlockGem = 0,
			NextStagger = 0,
			AfterDodgeUntil = 0,
			InputWindow = 0,
			Inputs = 0,
			Dots = {},
			SlowUntil = 0,
			Slow = 0,
			SunderUntil = 0,
			Sunder = 0,
			StunUntil = 0,
			CC = CrowdControl.new(),
			NextCleanse = 0,
		}
	end
	return states[player]
end
local function updateResources(player, st, k)
	local now = os.clock()
	local elapsed = math.clamp(now - st.ResourceAt, 0, 1)
	st.ResourceAt = now
	for id, rule in Tech.Resources do
		local regen = rule.Regen * (1 + (k.Effects[id .. "Regen"] or 0))
		st.Resources[id] = math.min(rule.Max, st.Resources[id] + elapsed * regen)
		if id == "Charge" and not Tech.hasGem(k.Loadout) then
			st.Resources[id] = 0
		end
		player:SetAttribute(id, st.Resources[id])
		player:SetAttribute("Max" .. id, rule.Max)
	end
end
local function flat(v)
	local direction = Vector3.new(v.X, 0, v.Z)
	return if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
end
local function canPvP(source, target)
	local _, a = alive(source)
	local _, b = alive(target)
	if not a or not b then
		return false
	end
	if source.Character:FindFirstChildOfClass("ForceField") then
		return false
	end
	local sameTeam = source.Team ~= nil and source.Team == target.Team and not source.Neutral and not target.Neutral
	return Actions.canPvP(
		source,
		target,
		Combat.inArena(a.Position),
		Combat.inArena(b.Position),
		source:GetAttribute("PvPEnabled"),
		target:GetAttribute("PvPEnabled"),
		sameTeam
	)
end
local function targetAllowed(source, target)
	local _, root = alive(source)
	if not root or not Combat.canFight(root.Position) then
		return false
	end
	if target.Player then
		return canPvP(source, target.Player)
	end
	return target.Enemy.Alive and Combat.canFight(target.Root.Position)
end
local function targets(source)
	local list = {}
	for _, enemy in Enemies.all() do
		if enemy.Alive then
			table.insert(list, { Enemy = enemy, Root = enemy.Root, Humanoid = enemy.Humanoid })
		end
	end
	for _, player in Players:GetPlayers() do
		if canPvP(source, player) then
			local humanoid, root = alive(player)
			table.insert(list, { Player = player, Root = root, Humanoid = humanoid })
		end
	end
	return list
end
local function lineClear(from, to)
	local skip = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(skip, enemies)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	local hit = workspace:Raycast(from, to - from, params)
	return hit == nil or hit.Distance >= (to - from).Magnitude - 0.2
end
local function blocking(st, now)
	return now < st.BlockUntil and now >= st.BlockBrokenUntil
end
local function blockGem(k)
	-- Shield takes precedence; other defensive sockets can supply an action gem.
	for _, slot in { "Shield", "Armor", "Helmet", "Gloves", "Boots" } do
		local gem = k.Loadout[slot .. "Gem"]
		if gem then
			return gem
		end
	end
	return nil
end
local function cleanse(st)
	st.Dots = {}
	st.SlowUntil, st.SunderUntil, st.StunUntil = 0, 0, 0
	-- A cleanse removes effects, not the victim's diminishing-return history.
	st.CC.HealCuts, st.CC.Debuffs = {}, {}
end
local function triggerBlockGem(player, k, st, now)
	if now < st.NextBlockGem then
		return
	end
	local gem = blockGem(k)
	if not gem then
		return
	end
	if k.Defense.CleanseInterval < math.huge then
		cleanse(st)
		st.NextCleanse = now + k.Defense.CleanseInterval
	end
	if k.Defense.Shield > 0 then
		st.Shield = math.max(st.Shield, k.Defense.Shield)
		st.ShieldUntil = now + k.Defense.Duration
	end
	st.NextBlockGem = now + k.Defense.Duration + k.Defense.Cooldown
	fx("BlockGem", player, gem.Element)
end
local receive
local function rawDamage(target, amount, source, crit, color)
	if target.Player then
		target.Humanoid:TakeDamage(amount)
		fx("Damage", target.Root.Position + Vector3.new(0, 3, 0), math.floor(amount + 0.5), crit == true, color)
	else
		Enemies.damage(target.Enemy, amount, source, crit, color)
	end
end
receive = function(player, amount, element, source, origin, projectile, heavy, reflected, enemySource, crit, pierce)
	local humanoid, root = alive(player)
	local k = kit(player)
	if not humanoid or not root or not k or amount <= 0 or not Combat.canFight(root.Position) then
		return 0
	end
	local pvp = source ~= nil
	if pvp and not canPvP(source, player) then
		return 0
	end
	if player.Character:FindFirstChildOfClass("ForceField") then
		return 0
	end
	local st, now = state(player), os.clock()
	if Actions.invulnerable(st.DodgeStarted, now, k.Rules, pvp) then
		return 0
	end
	local resistance = k.Defense.Resistance
	local defense = rating(k, "Defense") * (if now < st.SunderUntil then 1 - st.Sunder else 1)
	local damage = amount
		* Combat.defenseMult(defense)
		* EquipmentBalance.passiveDamageMultiplier(k.Effects.TakenMult, resistance)
	damage *= 1 + CrowdControl.debuff(st.CC, "Vulnerable", now) + CrowdControl.debuff(st.CC, "Aura", now)
	local guarded = false
	if blocking(st, now) and origin and not pierce then
		local dot = flat(origin - root.Position):Dot(st.BlockDirection or flat(root.CFrame.LookVector))
		if heavy and dot >= math.cos(math.rad(k.Rules.BlockArc / 2)) then
			st.BlockUntil, st.BlockBrokenUntil = 0, now + Actions.Base.Heavy.BreakSeconds
			player:SetAttribute("Blocking", false)
			Remotes.CombatFx:FireClient(player, "BlockBroken", Actions.Base.Heavy.BreakSeconds)
			fx("BlockSpark", root.Position, true)
		else
			local multiplier, covered = Actions.blockMultiplier(k.Rules, pvp, dot, projectile, heavy)
			if covered then
				guarded = true
				if
					not projectile
					and not reflected
					and st.BlockRaisedAt
					and now - st.BlockRaisedAt <= 0.3
					and not st.ParrySpent
				then
					st.ParrySpent = true
					multiplier = math.min(multiplier, if pvp then 0.35 else 0.25)
					if source then
						local attacker = state(source)
						local duration = CrowdControl.ApplyCC(attacker.CC, 0.25, now, true)
						attacker.StunUntil = math.max(attacker.StunUntil, now + duration)
						attacker.ChargeStarted, attacker.ComboSide, attacker.ComboCount = nil, nil, 0
						Remotes.CombatFx:FireClient(source, "Parried", duration)
					elseif enemySource then
						Enemies.addStatus(enemySource, "Stun", 1, 0.5)
					end
					Remotes.CombatFx:FireClient(player, "HighBlock")
				end
				fx("BlockSpark", root.Position, false)
				if k.Defense.Deflect > 0 and math.random() < k.Defense.Deflect then
					multiplier = 0
				end
				if not reflected then
					local reflect = if math.random() < k.Defense.Reflect
						then 1
						elseif element == "Fire" then k.Defense.ReflectThermal
						else 0
					if reflect > 0 and source then
						receive(source, damage * reflect, "Fire", player, root.Position, false, false, true)
					elseif reflect > 0 and enemySource then
						Enemies.damage(enemySource, damage * reflect, player, false, GemConfig.ElementColors.Fire)
					end
				end
				damage *= multiplier
			end
		end
	end
	if now < st.SiphonUntil and st.SiphonCapacity > 0 then
		local absorbed = math.min(damage, st.SiphonCapacity)
		st.SiphonCapacity -= absorbed
		st.Resources.Charge = math.min(100, st.Resources.Charge + absorbed * 0.5)
		damage -= absorbed
		player:SetAttribute("Charge", st.Resources.Charge)
	end
	if now < st.ShieldUntil and st.Shield > 0 then
		local absorbed = math.min(st.Shield, damage)
		st.Shield -= absorbed
		damage -= absorbed
	end
	if damage > 0 then
		rawDamage(
			{ Player = player, Humanoid = humanoid, Root = root },
			damage,
			source,
			crit == true,
			GemConfig.ElementColors[element] or WHITE
		)
	end
	return damage, guarded
end
local function addDot(player, source, perTick, duration)
	if duration <= 0 or perTick <= 0 then
		return
	end
	local st, now = state(player), os.clock()
	st.Dots[source] =
		{ Source = source, Damage = perTick, Last = now, Ends = now + duration, Next = now + math.min(1, duration) }
end
local enemyCC = setmetatable({}, { __mode = "k" })
local function applyCC(target, seconds)
	local tracker
	if target.Player then
		tracker = state(target.Player).CC
	else
		tracker = enemyCC[target.Enemy]
		if not tracker then
			tracker = CrowdControl.new()
			enemyCC[target.Enemy] = tracker
		end
	end
	local duration = CrowdControl.ApplyCC(tracker, seconds, os.clock(), target.Player ~= nil)
	if duration > 0 then
		if target.Player then
			local st = state(target.Player)
			st.StunUntil = math.max(st.StunUntil, os.clock() + duration)
			st.ChargeStarted, st.BlockUntil = nil, 0
		else
			Enemies.addStatus(target.Enemy, "Stun", 1, duration)
		end
	end
end
local function procGem(source, k, target)
	local gem = k.Loadout.WeaponGem
	if not gem then
		return
	end
	local values = GemConfig.actionValues(gem, "Basic", { Affinity = k.Affinity, PvP = target.Player ~= nil })
	local st = if target.Player then state(target.Player) else nil
	local now = os.clock()
	if values.Burn then
		local burning = values.Burn
		local critical = math.random() < values.Ignite
		if critical then
			burning *= Combat.CritMult
		end
		if st then
			addDot(target.Player, source, burning, values.Duration)
			if critical then
				CrowdControl.applyHealCut(st.CC, "GrievousWounds", now)
			end
		else
			Enemies.setBurn(target.Enemy, burning, values.Duration, source, GemConfig.ElementColors.Fire)
		end
	end
	if values.Slow then
		if st then
			st.Slow = CrowdControl.applyDebuff(st.CC, "Slow", values.Slow, values.Duration, now, true)
			st.SlowUntil = st.CC.Debuffs.Slow.Until
		else
			Enemies.addStatus(target.Enemy, "Slow", values.Slow, values.Duration)
		end
		if math.random() < values.Freeze then
			applyCC(target, values.FreezeSeconds)
		end
	end
	if values.Sunder then
		if st then
			st.Sunder = CrowdControl.applyDebuff(st.CC, "Sunder", values.Sunder, values.Duration, now, true)
			st.SunderUntil = st.CC.Debuffs.Sunder.Until
		else
			Enemies.addStatus(target.Enemy, "Sunder", values.Sunder, values.Duration)
		end
		if math.random() < values.Vulnerable then
			if st then
				CrowdControl.applyDebuff(st.CC, "Vulnerable", values.VulnerableAmount, values.Duration, now, true)
				CrowdControl.applyHealCut(st.CC, "MortalStrike", now)
			else
				Enemies.addStatus(target.Enemy, "Vulnerable", values.VulnerableAmount, values.Duration)
			end
		end
	end
	if values.Arc then
		local visited, from = { [target.Root] = true }, target
		-- PvP caps this at one jump; no recursive gem procs or cross-boundary chain targets.
		for _ = 1, values.Chain do
			local closest, distance = nil, GemConfig.Rules.ArcRange
			for _, other in targets(source) do
				if
					not visited[other.Root]
					and targetAllowed(source, other)
					and (other.Player ~= nil) == (target.Player ~= nil)
					and lineClear(from.Root.Position, other.Root.Position)
				then
					local d = (other.Root.Position - from.Root.Position).Magnitude
					if d < distance then
						closest, distance = other, d
					end
				end
			end
			if not closest then
				break
			end
			visited[closest.Root] = true
			fx("Arc", from.Root.Position, closest.Root.Position, GemConfig.ElementColors.Shock)
			if closest.Player then
				receive(closest.Player, values.Arc, "Shock", source, from.Root.Position, true, false, false)
			else
				Enemies.damage(closest.Enemy, values.Arc, source, false, GemConfig.ElementColors.Shock)
			end
			from = closest
		end
		if math.random() < values.Stun then
			applyCC(target, values.StunSeconds)
		end
		if target.Humanoid.Health > 0 and target.Humanoid.Health < target.Humanoid.MaxHealth * values.Execute then
			if target.Player then
				receive(
					target.Player,
					target.Humanoid.Health * 20,
					"Shock",
					source,
					source.Character.HumanoidRootPart.Position,
					false,
					false,
					false
				)
			elseif not target.Enemy.Kind.Dummy then
				Enemies.damage(
					target.Enemy,
					target.Humanoid.Health / (1 + Enemies.exposure(target.Enemy)) + 1,
					source,
					true,
					GemConfig.ElementColors.Shock
				)
			end
		end
	end
end

local function strike(source, k, st, target, heavy, projectile, swing)
	if not targetAllowed(source, target) then
		return
	end
	local _, root = alive(source)
	local multiplier = if heavy
		then (if target.Player then k.Rules.HeavyPvPDamage else k.Rules.HeavyDamage)
		else k.Rules.BasicDamage
	local damage = k.Weapon.Attack.Damage * Combat.powerMult(rating(k, "Power")) * multiplier
	if swing then
		damage *= swing.Scale * (1 + (swing.Combo - 1) * 0.1)
	end
	if os.clock() < st.AfterDodgeUntil then
		damage *= 1 + (k.Effects.DamageAfterDodge or 0)
	end
	local crit = (swing and swing.Perfect)
		or math.random()
			< math.min(
				0.75,
				Combat.critChance(rating(k, "Speed"), k.Effects.CritAdd) + (if heavy then k.Rules.HeavyCrit else 0)
			)
	if crit then
		damage *= Combat.CritMult
	end
	local echoDamage = damage
	local guarded = false
	local gem = k.Loadout.WeaponGem
	local element = gem and gem.Element
	if target.Player then
		damage, guarded =
			receive(target.Player, damage, element, source, root.Position, projectile, heavy, false, nil, crit)
	else
		Enemies.damage(
			target.Enemy,
			damage,
			source,
			crit,
			if crit then Color3.fromRGB(255, 220, 80) else GemConfig.ElementColors[element] or WHITE
		)
		if k.Effects.Sunder then
			Enemies.addStatus(target.Enemy, "Sunder", k.Effects.Sunder, 5)
		end
		if k.Effects.Bleed then
			Enemies.addDot(target.Enemy, damage * k.Effects.Bleed, 3, source, Color3.fromRGB(200, 40, 40))
		end
		if k.Effects.SlowOnHit then
			Enemies.addStatus(target.Enemy, "Slow", k.Effects.SlowOnHit, 2)
		end
	end
	if damage <= 0 or target.Humanoid.Health <= 0 then
		return damage > 0 and not guarded, guarded
	end
	if os.clock() < st.EchoUntil then
		if target.Player then
			receive(target.Player, echoDamage, element, source, root.Position, projectile, false, false, nil, false)
		else
			Enemies.damage(target.Enemy, echoDamage, source, false, Color3.fromRGB(70, 180, 255))
		end
		fx(
			"Arc",
			root.Position + Vector3.new(0, 1.5, 0),
			target.Root.Position + Vector3.new(0, 1.5, 0),
			Color3.fromRGB(70, 180, 255)
		)
	end
	procGem(source, k, target)
	if heavy then
		target.Root:ApplyImpulse(
			flat(target.Root.Position - root.Position) * target.Root.AssemblyMass * k.Rules.Knockback
		)
	elseif k.Rules.Stagger > 0 and os.clock() >= st.NextStagger and math.random() < k.Rules.Stagger then
		st.NextStagger = os.clock() + 1
		applyCC(target, 0.2)
	end
	return not guarded, guarded
end
local function attack(player, aim, heavy, swing)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not Actions.finiteVector(aim) or not Combat.canFight(root.Position) then
		return false
	end
	local st, now = state(player), os.clock()
	if now < st.NextAttack or now < st.StunUntil or blocking(st, now) or st.DodgeMove or st.Channel then
		return false
	end
	st.NextAttack = now + (if heavy then k.Rules.HeavyCooldown else k.Rules.BasicCooldown)
	st.ChargeStarted = nil
	Remotes.CombatFx:FireClient(player, "Cooldown", if heavy then "Heavy" else "Basic", st.NextAttack - now)
	local landed, interrupted = false, false
	if swing then
		swing.Combo = Actions.combo(st.ComboSide, st.ComboCount, st.ComboAt, swing.Side, now)
	end
	local function hit(target, projectile)
		local success, guarded = strike(player, k, st, target, heavy, projectile, swing)
		landed = landed or success == true
		interrupted = interrupted or guarded == true
	end
	local a, color =
		k.Weapon.Attack, GemConfig.ElementColors[k.Loadout.WeaponGem and k.Loadout.WeaponGem.Element] or WHITE
	local direction = flat(aim - root.Position)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	if a.Kind == "Melee" then
		fx("Swing", player, root.Position, direction, a.Range, a.Arc or 90, color, heavy == true)
		for _, target in targets(player) do
			local offset = target.Root.Position - root.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if
				distance <= a.Range + 1.5
				and math.abs(offset.Y) < 8
				and (distance < 1.5 or flat(offset):Dot(direction) >= math.cos(math.rad((a.Arc or 90) / 2)))
				and lineClear(origin, target.Root.Position + Vector3.new(0, 1.5, 0))
			then
				hit(target, false)
			end
		end
	else
		local offset = aim - origin
		local ray = if offset.Magnitude > 0.01 then offset.Unit else direction
		local nearest, along = nil, a.Range
		for _, target in targets(player) do
			local v = target.Root.Position + Vector3.new(0, 1.5, 0) - origin
			local projection = v:Dot(ray)
			if
				projection > 0
				and projection <= along
				and (v - ray * projection).Magnitude <= 2
				and lineClear(origin, origin + ray * projection)
			then
				nearest, along = target, projection
			end
		end
		if nearest then
			hit(nearest, true)
		end
		fx("Shot", player, origin, origin + ray * along, color, k.Weapon.Look)
	end
	if swing then
		if landed and not interrupted then
			st.ComboSide, st.ComboCount, st.ComboAt = swing.Side, swing.Combo, now
		else
			st.ComboSide, st.ComboCount, st.ComboAt = nil, 0, nil
		end
		Remotes.CombatFx:FireClient(
			player,
			"AttackTiming",
			if interrupted then "BLOCKED" elseif not landed then "MISS" else swing.Stage,
			swing.Side,
			st.ComboCount
		)
	end
	return true
end
local function stopDodge(st)
	local move = st.DodgeMove
	if move and move.Root.Parent then
		move.Root.AssemblyLinearVelocity = Vector3.new(0, move.Root.AssemblyLinearVelocity.Y, 0)
		pcall(function()
			move.Root:SetNetworkOwnershipAuto()
		end)
	end
	st.DodgeMove = nil
end
local function dodge(player, requested)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not Combat.canFight(root.Position) or not Actions.finiteVector(requested) then
		return false
	end
	local st, now = state(player), os.clock()
	if now < st.NextDodge or now < st.StunUntil or st.DodgeMove or st.Resources.Stamina < Tech.DodgeCost then
		return false
	end
	local direction = if Vector3.new(requested.X, 0, requested.Z).Magnitude > 0.1
		then flat(requested)
		else flat(root.CFrame.LookVector)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.RespectCanCollide = true
	local collision = workspace:Blockcast(root.CFrame, Vector3.new(2, 3, 2), direction * k.Rules.DodgeDistance, params)
	local travel = if collision then math.max(0, collision.Distance - 0.2) else k.Rules.DodgeDistance
	Tech.spend(st.Resources, "Stamina", Tech.DodgeCost)
	player:SetAttribute("Stamina", st.Resources.Stamina)
	st.NextDodge, st.DodgeStarted = now + k.Rules.DodgeCooldown, now
	st.Channel, st.Pending = nil, {}
	st.AfterDodgeUntil, st.BlockUntil, st.ChargeStarted = now + Actions.AfterDodgeSeconds, 0, nil
	st.DodgeMove = {
		Root = root,
		Direction = direction,
		Speed = travel / Actions.Base.Dodge.Duration,
		Ends = now + Actions.Base.Dodge.Duration,
	}
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	player:SetAttribute("Blocking", false)
	Remotes.CombatFx:FireClient(player, "Cooldown", "Dodge", k.Rules.DodgeCooldown)
	fx("DodgeRoll", player, root.Position, direction, travel, k.Rules.Deflect)
	return true
end
local function block(player, held, aim)
	local st = state(player)
	if held == false then
		st.BlockUntil = 0
		player:SetAttribute("Blocking", false)
		return true
	end
	local k = kit(player)
	local humanoid, root = alive(player)
	local now = os.clock()
	if
		not k
		or not humanoid
		or not Combat.canFight(root.Position)
		or st.DodgeMove
		or now < st.StunUntil
		or now < st.BlockBrokenUntil
		or not Actions.finiteVector(aim)
	then
		return false
	end
	local wasBlocking = blocking(st, now)
	if k.Defense.CleanseInterval < math.huge and now >= st.NextCleanse then
		cleanse(st)
		st.NextCleanse = now + k.Defense.CleanseInterval
	end
	st.Channel, st.Pending = nil, {}
	st.BlockDirection, st.BlockUntil, st.ChargeStarted = flat(aim - root.Position), now + Actions.BlockLease, nil
	player:SetAttribute("Blocking", true)
	if not wasBlocking then
		st.ParrySpent = false
		st.BlockRaisedAt = if now >= (st.NextHighBlock or 0) then now else nil
		if st.BlockRaisedAt then
			st.NextHighBlock = now + 1.5
		end
		triggerBlockGem(player, k, st, now)
		fx("BlockRaise", player)
	end
	return true
end
local function surgeGem(loadout, element)
	for _, slot in { "Weapon", "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local gem = loadout[slot .. "Gem"]
		if gem and (not element or gem.Element == element) then
			return gem
		end
	end
	return nil
end
local function technologyHit(player, k, target, definition, scale)
	if not targetAllowed(player, target) then
		return
	end
	local _, root = alive(player)
	local gem = if definition.Resource == "Charge" then surgeGem(k.Loadout, definition.Element) else nil
	local damage = k.Weapon.Attack.Damage * Combat.powerMult(rating(k, "Power")) * definition.Damage * (scale or 1)
	if gem then
		damage *= 1 + math.clamp(gem.Size or 1, 1, 10) * 0.03
	end
	local color = GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80)
	if target.Player then
		damage = receive(
			target.Player,
			damage,
			definition.Element,
			player,
			root.Position,
			definition.Resource == "Charge",
			definition.Heavy == true,
			false,
			nil,
			false,
			definition.Pierce
		)
	else
		Enemies.damage(target.Enemy, damage, player, false, color)
	end
	if damage <= 0 then
		return
	end
	if definition.Stun then
		applyCC(target, definition.Stun)
	end
	if definition.Slow then
		if target.Player then
			local victim = state(target.Player)
			victim.Slow = CrowdControl.applyDebuff(victim.CC, "Slow", definition.Slow, 0.75, os.clock(), true)
			victim.SlowUntil = os.clock() + 0.75
		else
			Enemies.addStatus(target.Enemy, "Slow", definition.Slow, 0.75)
		end
	end
	if definition.Element == "Fire" and gem then
		local values = GemConfig.stats(gem, "Weapon", { Affinity = k.Affinity, PvP = target.Player ~= nil })
		if target.Player then
			addDot(target.Player, player, values.BurnDamage, values.BurnDuration)
		else
			Enemies.addDot(target.Enemy, values.BurnDamage, values.BurnDuration, player, color)
		end
	end
end
local function technologyStrike(player, definition, aim, scale)
	local humanoid, root = alive(player)
	local k, st = kit(player), state(player)
	if
		not humanoid
		or not k
		or not Combat.canFight(root.Position)
		or os.clock() < st.StunUntil
		or blocking(st, os.clock())
		or st.DodgeMove
	then
		return
	end
	if definition.Resource == "Charge" and not Tech.hasGem(k.Loadout, definition.Element) then
		return
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = aim - origin
	local direction = if offset.Magnitude > 0.01 then offset.Unit else root.CFrame.LookVector
	local center = origin + direction * math.min(offset.Magnitude, definition.Range)
	local color = GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80)
	if definition.Resource == "Stamina" then
		fx("Swing", player, root.Position, flat(direction), definition.Range, 100, color, definition.Heavy == true)
		for _, target in targets(player) do
			local v = target.Root.Position - root.Position
			if
				v.Magnitude <= definition.Range
				and flat(v):Dot(flat(direction)) >= 0.5
				and lineClear(origin, target.Root.Position + Vector3.new(0, 1.5, 0))
			then
				technologyHit(player, k, target, definition, scale)
			end
		end
	elseif definition.Radius then
		if not lineClear(origin, center) then
			return
		end
		fx("TechPulse", player, origin, center, color, definition.Radius)
		for _, target in targets(player) do
			if
				(target.Root.Position - center).Magnitude <= definition.Radius
				and lineClear(center, target.Root.Position + Vector3.new(0, 1.5, 0))
			then
				technologyHit(player, k, target, definition, scale)
			end
		end
	else
		local nearest, along = nil, definition.Range
		for _, target in targets(player) do
			local v = target.Root.Position + Vector3.new(0, 1.5, 0) - origin
			local projection = v:Dot(direction)
			if
				projection > 0
				and projection <= along
				and (v - direction * projection).Magnitude <= 2
				and lineClear(origin, target.Root.Position + Vector3.new(0, 1.5, 0))
			then
				nearest, along = target, projection
			end
		end
		fx("TechPulse", player, origin, origin + direction * along, color, 0)
		if nearest then
			technologyHit(player, k, nearest, definition, scale)
		end
	end
end
local function triggerTechnology(player, id, aim)
	local definition = if typeof(id) == "string" then Tech.Catalog[id] else nil
	local k, st, now = kit(player), state(player), os.clock()
	local humanoid, root = alive(player)
	if
		not definition
		or not k
		or not humanoid
		or not Actions.finiteVector(aim)
		or not Combat.canFight(root.Position)
	then
		return false
	end
	if now < st.StunUntil or st.DodgeMove or blocking(st, now) or st.ChargeStarted then
		return false
	end
	if definition.Resource == "Charge" and not Tech.hasGem(k.Loadout, definition.Element) then
		return false
	end
	if id == "CryoStream" and st.Channel then
		st.Channel.Aim, st.Channel.Until = aim, now + 0.5
		return true
	end
	if now < st.NextAttack or now < st.NextTech or now < (st.TechCooldowns[id] or 0) or st.Channel then
		return false
	end
	if definition.Shield and not Classes.gear(k.Loadout.Class, "Shields", k.Loadout.Shield) then
		return false
	end
	local cost = definition.Cost * (if definition.PerSecond then 0.25 else 1)
	if st.Resources[definition.Resource] < cost then
		Remotes.CombatFx:FireClient(player, "TechStatus", "Not enough " .. definition.Resource)
		return false
	end
	if id == "StimDodge" then
		if not dodge(player, aim - root.Position) then
			return false
		end
		CombatServer.heal(player, humanoid.MaxHealth * definition.Heal)
	else
		Tech.spend(st.Resources, definition.Resource, cost)
	end
	local recovery = definition.Recovery * (k.Effects.CooldownMult or 1)
	st.TechCooldowns[id], st.NextTech = now + recovery, now + recovery
	st.NextAttack = math.max(st.NextAttack, st.NextTech)
	st.ComboSide, st.ComboCount, st.ComboAt = nil, 0, nil
	player:SetAttribute(definition.Resource, st.Resources[definition.Resource])
	Remotes.CombatFx:FireClient(player, "TechCooldown", id, recovery)
	Remotes.CombatFx:FireClient(player, "TechStatus", definition.Name)
	if id == "EnergySiphon" then
		st.SiphonUntil, st.SiphonCapacity = now + definition.Duration, 40
		fx("TechField", player, Color3.fromRGB(70, 130, 255))
	elseif id == "CryoShield" then
		local gem = surgeGem(k.Loadout, "Frost")
		st.Shield = math.max(st.Shield, 30 + (gem.Size or 1) * 3)
		st.ShieldUntil = math.max(st.ShieldUntil, now + definition.Duration)
		fx("TechField", player, GemConfig.ElementColors.Frost)
	elseif id == "ResonanceEcho" then
		st.EchoUntil = now + definition.Duration
		fx("TechField", player, Color3.fromRGB(70, 130, 255))
	elseif id == "CryoStream" then
		technologyStrike(player, definition, aim, 0.25)
		st.Channel = { Aim = aim, Until = now + 0.5, Next = now + 0.25 }
	elseif definition.Damage then
		if definition.Windup then
			table.insert(st.Pending, { Id = id, Aim = aim, At = now + definition.Windup })
			fx("TechField", player, Color3.fromRGB(255, 190, 80))
		else
			technologyStrike(player, definition, aim)
			if definition.Hits == 2 then
				table.insert(st.Pending, { Id = id, Aim = aim, At = now + 0.16 })
			end
		end
	end
	return true
end
local function onInput(player, action, a, b)
	local st, now = state(player), os.clock()
	if action == "Block" and a == false then
		block(player, false)
		return
	end
	if action == "CancelTech" then
		st.Channel, st.Pending = nil, {}
		return
	end
	if action == "CancelAttack" then
		st.ChargeStarted = nil
		return
	end
	if now - st.InputWindow >= 1 then
		st.InputWindow, st.Inputs = now, 0
	end
	st.Inputs += 1
	if st.Inputs > 24 then
		return
	end
	local humanoid, root = alive(player)
	if not humanoid or not Combat.canFight(root.Position) then
		return
	end
	local currentKit = kit(player)
	if not currentKit then
		return
	end
	updateResources(player, st, currentKit)
	if action == "RigManeuver" or action == "GemSurge" then
		local definition = typeof(a) == "string" and Tech.Catalog[a]
		if definition and definition.Resource == (if action == "RigManeuver" then "Stamina" else "Charge") then
			triggerTechnology(player, a, b)
		end
	elseif action == "BeginAttack" then
		if
			now >= st.NextAttack
			and now >= st.StunUntil
			and not blocking(st, now)
			and not st.DodgeMove
			and not st.ChargeStarted
			and not st.Channel
		then
			st.ChargeStarted = now
			st.ChargeSide = Actions.side(a)
		end
	elseif action == "ReleaseAttack" and Actions.finiteVector(a) then
		local started = st.ChargeStarted
		st.ChargeStarted = nil
		if started and now - started <= 3 then
			local swing = Actions.charge(now - started)
			swing.Side = st.ChargeSide or "Right"
			attack(player, a, swing.Heavy, swing)
		end
	elseif action == "Attack" and Actions.finiteVector(a) then
		st.ChargeStarted = nil
		attack(player, a, false)
	elseif action == "Dodge" then
		dodge(player, a)
	elseif action == "Block" and a == true then
		block(player, true, b)
	end
end
function CombatServer.hurt(player, amount, element, enemy)
	return receive(player, amount, element, nil, enemy and enemy.Root.Position, false, false, false, enemy)
end
local function tick(_dt)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local st, k = state(player), kit(player)
		local humanoid, root = alive(player)
		if not humanoid or not k or not Combat.canFight(root.Position) then
			st.BlockUntil, st.ChargeStarted, st.DodgeStarted = 0, nil, nil
			st.Dots, st.Pending, st.Channel = {}, {}, nil
			stopDodge(st)
			player:SetAttribute("Blocking", false)
			continue
		end
		updateResources(player, st, k)
		if now < st.StunUntil then
			st.Channel, st.Pending = nil, {}
		end
		for i = #st.Pending, 1, -1 do
			local pending = st.Pending[i]
			if now >= pending.At then
				table.remove(st.Pending, i)
				technologyStrike(player, Tech.Catalog[pending.Id], pending.Aim)
			end
		end
		if st.Channel then
			local channel, definition = st.Channel, Tech.Catalog.CryoStream
			if now >= channel.Until or blocking(st, now) or st.DodgeMove or not Tech.hasGem(k.Loadout, "Frost") then
				st.Channel = nil
			elseif now >= channel.Next then
				if Tech.spend(st.Resources, "Charge", definition.Cost * 0.25) then
					technologyStrike(player, definition, channel.Aim, 0.25)
					channel.Next = now + 0.25
				else
					st.Channel = nil
				end
			end
		end
		player:SetAttribute("Channeling", st.Channel ~= nil)
		player:SetAttribute("Charge", st.Resources.Charge)
		if st.DodgeMove then
			if now >= st.DodgeMove.Ends then
				stopDodge(st)
			else
				root.AssemblyLinearVelocity = st.DodgeMove.Direction * st.DodgeMove.Speed
					+ Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
			end
		end
		if st.ChargeStarted and now - st.ChargeStarted > 3 then
			st.ChargeStarted = nil
		end
		player:SetAttribute("Blocking", blocking(st, now))
		if blocking(st, now) and k.Defense.CleanseInterval < math.huge and now >= st.NextCleanse then
			cleanse(st)
			st.NextCleanse = now + k.Defense.CleanseInterval
		end
		if blocking(st, now) and k.Defense.Aura > 0 then
			for _, target in targets(player) do
				if
					(target.Root.Position - root.Position).Magnitude <= GemConfig.Rules.AuraRadius
					and targetAllowed(player, target)
				then
					if target.Player then
						CrowdControl.applyDebuff(state(target.Player).CC, "Aura", k.Defense.Aura, 0.5, now, true)
					else
						Enemies.addStatus(target.Enemy, "Aura", k.Defense.Aura, 0.5)
					end
				end
			end
		end
		local speed = Classes.walkSpeed(rating(k, "Speed"))
		humanoid.WalkSpeed = if now < st.StunUntil
			then 0
			else speed * (if now < st.SlowUntil then 1 - st.Slow else 1) * (if blocking(st, now) then 0.6 else 1)
		if now >= st.ShieldUntil then
			st.Shield = 0
		end
		if k.Effects.Ward and now >= st.NextWard then
			st.NextWard, st.Shield, st.ShieldUntil = now + 8, math.max(st.Shield, k.Effects.Ward), now + 8
		end
		for source, dot in st.Dots do
			if not canPvP(source, player) then
				st.Dots[source] = nil
			elseif now >= dot.Next then
				local through = math.min(now, dot.Ends)
				receive(player, dot.Damage * (through - dot.Last), "Fire", source, nil, false, false, false)
				dot.Last, dot.Next = through, math.min(through + 1, dot.Ends)
				if through >= dot.Ends then
					st.Dots[source] = nil
				end
			end
		end
		player:SetAttribute("Shield", math.floor(st.Shield))
		player:SetAttribute("CombatCharging", st.ChargeStarted ~= nil)
	end
end
function CombatServer.heal(player, amount)
	local humanoid = alive(player)
	local k = kit(player)
	if not humanoid or not k or amount <= 0 then
		return 0
	end
	local healing = amount
		* (1 + (k.Effects.HealingReceived or 0))
		* CrowdControl.healingMultiplier(state(player).CC, os.clock())
	local restored = math.min(humanoid.MaxHealth - humanoid.Health, healing)
	if restored > 0 then
		humanoid.Health += restored
	end
	return restored
end
function CombatServer.reset(player)
	if states[player] then
		stopDodge(states[player])
	end
	states[player] = nil
	for _, st in states do
		st.Dots[player] = nil
	end
	player:SetAttribute("Blocking", false)
	player:SetAttribute("Shield", 0)
	player:SetAttribute("CombatCharging", false)
	player:SetAttribute("Channeling", false)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("Charge", 0)
end
function CombatServer.start()
	Enemies.hitPlayer = function(player, amount, element, enemy)
		CombatServer.hurt(player, amount, element, enemy)
	end
	Remotes.CombatInput.OnServerEvent:Connect(onInput)
	Shop.register("SetRigManeuvers", function()
		return Shop.reply(
			false,
			"Rig Maneuvers are universal. Cycle your combat rig with Z; trigger with R. Gem Surges use X and F."
		)
	end)
	local function watch(player)
		player.CharacterAdded:Connect(function()
			if states[player] then
				stopDodge(states[player])
			end
			states[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if states[player] then
			stopDodge(states[player])
		end
		states[player] = nil
		for _, st in states do
			st.Dots[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(tick)
end
CombatServer._technology = triggerTechnology
CombatServer._attack, CombatServer._dodge, CombatServer._block = attack, dodge, block
CombatServer._input, CombatServer._state, CombatServer._tick, CombatServer._canPvP = onInput, state, tick, canPvP
return CombatServer
