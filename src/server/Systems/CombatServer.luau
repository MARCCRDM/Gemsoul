-- Server-authoritative universal actions. Only opted-in Arena players can damage each other.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Classes = require(ReplicatedStorage.Shared.Classes)
local EquipmentBalance = require(ReplicatedStorage.Shared.EquipmentBalance)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local WeaponForge = require(ReplicatedStorage.Shared.WeaponForge)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CrowdControl = require(ReplicatedStorage.Shared.CrowdControl)
local ElementCombos = require(ReplicatedStorage.Shared.ElementCombos)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local Enemies = require(script.Parent.Enemies)
local DamageLog = require(script.Parent.DamageLog)
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
local posePlayer
-- Arena fights are equal ground: only gear and gems count there, so the
-- Augment Tree's perks (and surge/maneuver ranks) sit out.
local function inArena(player): boolean
	return player:GetAttribute("CombatSession") ~= nil
end
-- Everything a loadout fights with: its effects, gem defences, ratings and
-- action rules. `augments` are the Augment Tree's perks ({} for none). The
-- Arena rival is built by this too, so it fights by exactly a player's rules.
local function kitFor(loadout, augments)
	loadout = Classes.activeLoadout(loadout)
	local weapon = loadout and Classes.weapon(loadout.Class, loadout.Weapon)
	if not weapon or not weapon.Attack then
		return nil
	end
	local effects = Classes.effects(loadout)
	effects.StaminaRegen = (effects.StaminaRegen or 0) + (augments.StaminaRegen or 0)
	effects.ChargeRegen = (effects.ChargeRegen or 0) + (augments.ChargeRegen or 0)
	effects.MobilityMult = 1 + (augments.Mobility or 0)
	effects.WeaponAugmentMult = Tree.weaponMultiplier(augments, weapon)
	effects.ThermalMult = 1 + (augments.Thermal or 0)
	-- Overcharge perks, by gem element; Elemental Harmony rewards switching.
	effects.ElementMult = {
		Fire = effects.ThermalMult,
		Poison = 1 + (augments.Corrosive or 0),
		Shock = 1 + (augments.Ion or 0),
		Frost = 1 + (augments.Cryo or 0),
	}
	effects.Harmony = augments.Harmony or 0
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
		Rules = Actions.forWeapon(Classes.setState(loadout).Counts, weapon, effects),
	}
end
local function kit(player)
	local loadout = PlayerData.character(player)
	return kitFor(loadout, if inArena(player) then {} else Tree.effects(PlayerData.get(player)))
end
CombatServer.kitFor = kitFor
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
			Zones = {}, -- lingering surge pools (Toxic Cloud)
			HarmonyElement = nil,
			HarmonyUntil = 0,
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
			-- A surge's Ward (Supernova's Burning Ward, Static Field's Static Shell).
			SurgeWardUntil = 0,
			SurgeWardNext = 0,
			Blind = 0,
			BlindUntil = 0,
			RiposteUntil = 0, -- Riposte Stance: braced to turn the next blow aside
			RiposteDamage = 0,
			SilenceUntil = 0, -- surges locked by an interrupt
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
-- Spends Stamina (swings, guarding, maneuvers, dodges) and holds off its
-- regeneration for a moment, so it never refills mid-flurry.
local function spendStamina(player, st, amount)
	st.Resources.Stamina = math.max(0, st.Resources.Stamina - amount)
	st.StaminaRestUntil = os.clock() + Actions.Stamina.RegenDelay
	player:SetAttribute("Stamina", st.Resources.Stamina)
end
-- Your body acts out what you do, as the Arena rival's does (RivalPose, the
-- same poses, seen by everyone; every client poses it, see BodyPoses): a
-- cast's pose through its wind-up, a slash or heavy blow as it lands, the arm
-- drawn back while you charge, a tuck through a roll, a stagger when stunned.
local poseSides: { [Player]: number } = {}
posePlayer = function(player, kind: string?, windup: number, name: string?, element: string?)
	local character = player.Character
	if not character then
		return
	end
	local t = workspace:GetServerTimeNow()
	poseSides[player] = -(poseSides[player] or 1)
	character:SetAttribute("ActionKind", kind)
	character:SetAttribute("ActionHold", nil)
	character:SetAttribute("ActionStart", t)
	character:SetAttribute("ActionAt", t + windup)
	character:SetAttribute("ActionSide", poseSides[player])
	character:SetAttribute("ActionName", name)
	character:SetAttribute("ActionElement", element)
end
local function updateResources(player, st, k)
	local now = os.clock()
	local elapsed = math.clamp(now - st.ResourceAt, 0, 1)
	st.ResourceAt = now
	for id, rule in Tech.Resources do
		local regen = rule.Regen * (1 + (k.Effects[id .. "Regen"] or 0))
		if id == "Stamina" then
			if now < st.BlockUntil and now >= st.BlockBrokenUntil then
				regen = -Actions.Stamina.GuardDrain -- a raised guard tires you
			elseif now < (st.StaminaRestUntil or 0) then
				regen = 0
			end
		end
		st.Resources[id] = math.clamp(st.Resources[id] + elapsed * regen, 0, rule.Max)
		if id == "Stamina" and regen < 0 and st.Resources.Stamina <= 0 then
			-- Held the guard until there was nothing left: it drops.
			st.BlockUntil, st.BlockBrokenUntil = 0, now + Actions.Stamina.GuardBreakSeconds
			st.StaminaRestUntil = now + Actions.Stamina.RegenDelay
			player:SetAttribute("Blocking", false)
			Remotes.CombatFx:FireClient(player, "BlockBroken", Actions.Stamina.GuardBreakSeconds, "Exhausted")
		end
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
	-- Duel fighters only fight their opponents; party members never each other.
	sameTeam = sameTeam or not Matchmaking.versus(source, target)
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
	return target.Enemy.Alive
		and (not target.Enemy.DungeonId or source:GetAttribute("DungeonId") == target.Enemy.DungeonId)
		and Combat.canFight(target.Root.Position)
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
local wardHitsBack -- (set below, with the surge code)
local applyCC -- (set below)
local function rawDamage(target, amount, source, crit, color)
	if target.Player then
		target.Humanoid:TakeDamage(amount)
		if source then
			Remotes.CombatFx:FireClient(source, "HitConfirm", crit == true)
		end
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
	-- A rival duelist's blows count as PvP too (block, dodge windows).
	local pvp = source ~= nil or (enemySource ~= nil and enemySource.Duel ~= nil)
	if source and not canPvP(source, player) then
		return 0
	end
	if player.Character:FindFirstChildOfClass("ForceField") then
		return 0
	end
	local st, now = state(player), os.clock()
	local attackerName = DamageLog.nameOf(source) or DamageLog.nameOf(enemySource)
	if Actions.invulnerable(st.DodgeStarted, now, k.Rules, pvp, st.DodgeKind) then
		DamageLog.send(player, { Dir = "In", Kind = "Dodge", Who = attackerName })
		DamageLog.send(source, { Dir = "Out", Kind = "Dodge", Who = DamageLog.nameOf(player) })
		return 0
	end
	if origin and not reflected and now < st.RiposteUntil then
		-- Riposte Stance: the blow is turned aside, its attacker staggered
		-- and struck back.
		st.RiposteUntil = 0
		local previous = DamageLog.push("Riposte")
		if source then
			applyCC({ Player = source }, 1, "Stunned")
			receive(source, st.RiposteDamage, nil, player, root.Position, false, false, true)
			DamageLog.send(source, { Dir = "Out", Kind = "Parried", Who = DamageLog.nameOf(player) })
		elseif enemySource then
			Enemies.addStatus(enemySource, "Stun", 1, 1)
			enemySource.StunKind = "Stunned"
			Enemies.damage(enemySource, st.RiposteDamage, player, false, Color3.fromRGB(255, 196, 90))
		end
		DamageLog.pop(previous)
		fx("BlockSpark", root.Position, false)
		Remotes.CombatFx:FireClient(player, "HighBlock")
		Remotes.CombatFx:FireClient(player, "TechStatus", "Riposte!")
		return 0, true
	end
	local resistance = k.Defense.Resistance
	local defense = rating(k, "Defense") * (if now < st.SunderUntil then 1 - st.Sunder else 1)
	local damage = amount
		* Combat.defenseMult(defense)
		* EquipmentBalance.passiveDamageMultiplier(k.Effects.TakenMult, resistance)
	damage *= 1 + CrowdControl.debuff(st.CC, "Vulnerable", now) + CrowdControl.debuff(st.CC, "Aura", now)
	local guarded = false
	local beforeGuard, parriedBefore, guardBroken = damage, st.ParrySpent, false
	if blocking(st, now) and origin and not pierce then
		local dot = flat(origin - root.Position):Dot(st.BlockDirection or flat(root.CFrame.LookVector))
		if heavy and dot >= math.cos(math.rad(k.Rules.BlockArc / 2)) then
			st.BlockUntil, st.BlockBrokenUntil = 0, now + Actions.Base.Heavy.BreakSeconds
			guardBroken = true
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
						attacker.StunKind = "Stunned"
						attacker.ChargeStarted, attacker.ComboSide, attacker.ComboCount = nil, nil, 0
						Remotes.CombatFx:FireClient(source, "Parried", duration)
					elseif enemySource then
						-- A rival duelist is staggered as a player would be.
						Enemies.addStatus(enemySource, "Stun", 1, if enemySource.Duel then 0.25 else 0.5)
						enemySource.StunKind = "Stunned"
					end
					Remotes.CombatFx:FireClient(player, "HighBlock")
				end
				-- Taking the blow on your guard costs Stamina (a parry is free);
				-- one you can't pay for breaks the guard and lands in full.
				local exhausted = false
				if not (st.ParrySpent and not parriedBefore) then
					local cost = math.max(Actions.Stamina.BlockMin, beforeGuard * Actions.Stamina.BlockPerDamage)
						* (1 - (k.Effects.BlockStamina or 0))
					if st.Resources.Stamina >= cost then
						spendStamina(player, st, cost)
					else
						exhausted, guarded, guardBroken = true, false, true
						spendStamina(player, st, st.Resources.Stamina)
						st.BlockUntil = 0
						st.BlockBrokenUntil = now + Actions.Stamina.GuardBreakSeconds
						player:SetAttribute("Blocking", false)
						Remotes.CombatFx:FireClient(
							player,
							"BlockBroken",
							Actions.Stamina.GuardBreakSeconds,
							"Exhausted"
						)
						fx("BlockSpark", root.Position, true)
						multiplier = 1
					end
				end
				if not exhausted then
					fx("BlockSpark", root.Position, false)
					if k.Defense.Deflect > 0 and math.random() < k.Defense.Deflect then
						multiplier = 0
					end
					if not reflected then
						local reflect = if math.random() < k.Defense.Reflect
							then 1
							elseif element == "Fire" then k.Defense.ReflectThermal
							else 0
						local previous = DamageLog.push("Reflect", "Fire")
						if reflect > 0 and source then
							receive(source, damage * reflect, "Fire", player, root.Position, false, false, true)
						elseif reflect > 0 and enemySource then
							Enemies.damage(enemySource, damage * reflect, player, false, GemConfig.ElementColors.Fire)
						end
						DamageLog.pop(previous)
					end
				end
				damage *= multiplier
			end
		end
	end
	-- Retribution (a weapon perk): a melee attacker takes part of its hit back.
	if k.Effects.Thorns and damage > 0 and not projectile and not reflected and origin then
		local previous = DamageLog.push("Retribution")
		if source then
			receive(source, damage * k.Effects.Thorns, nil, player, root.Position, false, false, true)
		elseif enemySource and enemySource.Alive then
			Enemies.damage(enemySource, damage * k.Effects.Thorns, player, false, Color3.fromRGB(255, 196, 90))
		end
		DamageLog.pop(previous)
	end
	if origin and not reflected and now < st.SurgeWardUntil and now >= st.SurgeWardNext then
		local attacker = if source
			then { Player = source, Root = source.Character and source.Character:FindFirstChild("HumanoidRootPart") }
			elseif enemySource then { Enemy = enemySource, Root = enemySource.Root }
			else nil
		if attacker and attacker.Root then
			st.SurgeWardNext = now + 1
			wardHitsBack(st.SurgeWardKind, st.SurgeWardPower, st.SurgeWardStun, attacker, player)
		end
	end
	local blocked = math.max(0, beforeGuard - damage)
	local parried = st.ParrySpent and not parriedBefore
	local beforeAbsorb = damage
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
	-- The body reacts, for everyone to see (RivalPose) and in your own
	-- first-person view: the shield arm jolts when a blow lands on the
	-- guard, the body flinches away from a blow that gets through.
	local character = player.Character
	if character then
		local serverNow = workspace:GetServerTimeNow()
		if blocked > 0 then
			character:SetAttribute("BlockedAt", serverNow)
		end
		-- The last elemental blow decides how the body goes if it dies
		-- (ElementalDeath).
		if damage > 0 and element then
			character:SetAttribute("LastHitElement", element)
		end
		if damage > 0 and blocked <= damage then
			local side = if origin and (origin - root.Position):Dot(root.CFrame.RightVector) < 0 then -1 else 1
			character:SetAttribute("HurtAt", serverNow)
			character:SetAttribute("HurtSide", side)
		end
	end
	local entry = {
		Kind = "Hit",
		Amount = damage,
		Element = element,
		Crit = crit == true,
		Blocked = blocked,
		Absorbed = beforeAbsorb - damage,
		Parried = parried or nil,
		GuardBroken = guardBroken or nil,
	}
	local incoming = table.clone(entry)
	incoming.Dir, incoming.Who = "In", attackerName
	DamageLog.send(player, incoming)
	if not reflected then
		local outgoing = table.clone(entry)
		outgoing.Dir, outgoing.Who = "Out", DamageLog.nameOf(player)
		DamageLog.send(source, outgoing)
	end
	if damage > 0 then
		if origin then
			Remotes.CombatFx:FireClient(player, "IncomingDamage", origin)
		end
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
local publishStatuses
-- `kind` names it on the status bar: Frozen (Cryo), Shocked (Ion) or Stunned.
function applyCC(target, seconds, kind)
	local tracker
	if target.Player then
		-- Unstoppable (a weapon perk): stuns and freezes wear off sooner.
		local k = kit(target.Player)
		if k and k.Effects.Tenacity then
			seconds *= 1 - k.Effects.Tenacity
		end
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
			st.StunKind = kind or "Stunned"
			st.ChargeStarted, st.BlockUntil = nil, 0
			-- Rocked back on your heels (a real stun, not a tiny stagger).
			if duration >= 0.3 then
				posePlayer(target.Player, "Stagger", 0)
			end
		else
			Enemies.addStatus(target.Enemy, "Stun", 1, duration)
			target.Enemy.StunKind = kind or "Stunned"
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
		local burning = values.Burn * k.Effects.ThermalMult
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
			if critical then
				Enemies.healCut(target.Enemy, "GrievousWounds")
			end
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
			applyCC(target, values.FreezeSeconds, "Frozen")
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
				Enemies.healCut(target.Enemy, "MortalStrike")
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
			local previous = DamageLog.push("Ion Arc", "Shock")
			if closest.Player then
				receive(closest.Player, values.Arc, "Shock", source, from.Root.Position, true, false, false)
			else
				Enemies.damage(closest.Enemy, values.Arc, source, false, GemConfig.ElementColors.Shock)
			end
			DamageLog.pop(previous)
			from = closest
		end
		if math.random() < values.Stun then
			applyCC(target, values.StunSeconds, "Shocked")
		end
		if target.Humanoid.Health > 0 and target.Humanoid.Health < target.Humanoid.MaxHealth * values.Execute then
			local previous = DamageLog.push("Ion Execute", "Shock")
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
			DamageLog.pop(previous)
		end
	end
end

-- Blinded (Solar Flare): this share of your blows miss.
local function blindMiss(st, now)
	return now < st.BlindUntil and st.Blind > 0 and math.random() <= st.Blind
end
-- A Ward hits back at whoever struck its owner, at most once a second:
-- a Burning Ward sets them alight, a Static Shell stuns them.
function wardHitsBack(kind, power, stun, attacker, owner)
	if kind == "Burn" then
		local color = GemConfig.ElementColors.Fire
		if attacker.Player then
			addDot(attacker.Player, owner, power, 3)
		else
			Enemies.setBurn(attacker.Enemy, power, 3, owner, color)
		end
	else
		applyCC(attacker, stun or 0.6, "Shocked")
	end
	fx(
		"TechPulse",
		nil,
		attacker.Root.Position,
		attacker.Root.Position,
		GemConfig.ElementColors[if kind == "Burn" then "Fire" else "Shock"],
		4
	)
end
-- What a target is suffering, for element combos (Shared.ElementCombos).
local function comboFlags(target, now)
	if target.Player then
		local v = state(target.Player)
		return {
			Frozen = v.StunKind == "Frozen" and now < v.StunUntil,
			Shredded = now < v.SunderUntil and v.Sunder > 0,
			Slowed = now < v.SlowUntil and v.Slow > 0,
		}
	end
	local e = target.Enemy :: any
	return {
		Frozen = e.StunKind == "Frozen" and now < (e.StunUntil or 0),
		Shredded = now < (e.SunderUntil or 0) and (e.Sunder or 0) > 0,
		Slowed = now < (e.SlowUntil or 0) and (e.Slow or 0) > 0,
	}
end
-- A combo went off: the freeze breaks or a stun lands; both sides hear it.
local function comboLanded(source, target, combo)
	if combo.EndFreeze then
		if target.Player then
			state(target.Player).StunUntil = os.clock()
		else
			target.Enemy.StunUntil = os.clock()
		end
	end
	if combo.Stun then
		applyCC(target, combo.Stun, "Shocked")
	end
	fx("TechPulse", nil, target.Root.Position, target.Root.Position, combo.Color, 5)
	if source then
		Remotes.CombatFx:FireClient(source, "Combo", combo.Name)
		DamageLog.send(
			source,
			{ Dir = "Out", Kind = "Combo", Combo = combo.Name, Who = DamageLog.nameOf(target.Player or target.Enemy) }
		)
	end
	if target.Player then
		Remotes.CombatFx:FireClient(target.Player, "Combo", combo.Name)
		DamageLog.send(
			target.Player,
			{ Dir = "In", Kind = "Combo", Combo = combo.Name, Who = DamageLog.nameOf(source) }
		)
	end
end
-- `player` struck a rival braced in Riposte Stance: the blow is turned
-- aside and answered. True if it was.
local function enemyRiposte(player, enemy)
	local e, now = enemy :: any, os.clock()
	if not e.RiposteUntil or now >= e.RiposteUntil then
		return false
	end
	e.RiposteUntil = 0
	local _, root = alive(player)
	applyCC({ Player = player }, 1, "Stunned")
	if root then
		local previous = DamageLog.push("Riposte")
		receive(player, e.RiposteDamage or 0, nil, nil, enemy.Root.Position, false, false, true, enemy)
		DamageLog.pop(previous)
	end
	DamageLog.send(player, { Dir = "In", Kind = "Parried", Who = DamageLog.nameOf(enemy) })
	Remotes.CombatFx:FireClient(player, "Parried", 1)
	fx("BlockSpark", enemy.Root.Position, false)
	return true
end
-- `player` hit a rival that wears a Ward.
local function enemyWard(player, enemy)
	local now = os.clock()
	local e = enemy :: any
	if not e.WardUntil or now >= e.WardUntil or now < (e.WardNext or 0) then
		return
	end
	local _, root = alive(player)
	if not root then
		return
	end
	e.WardNext = now + 1
	wardHitsBack(e.WardKind, e.WardPower or 0, e.WardStun, { Player = player, Root = root }, enemy)
end
-- A weapon's perk after a blow lands (Shared.WeaponForge): healing, resources,
-- stuns, slows, bleeds and burns, on players and computer foes alike.
-- (Sunder, Bleed and Slow on a computer foe are applied in strike.)
local function weaponPerksOnHit(source, k, st, target, damage: number, guarded: boolean)
	local e, now = k.Effects, os.clock()
	if e.Lifesteal then
		CombatServer.heal(source, damage * e.Lifesteal)
	end
	for _, pair in { { "StaminaOnHit", "Stamina" }, { "ChargeOnHit", "Charge" } } do
		local amount = e[pair[1]]
		if amount then
			local id = pair[2]
			st.Resources[id] = math.min(Tech.Resources[id].Max, st.Resources[id] + Tech.Resources[id].Max * amount)
			source:SetAttribute(id, st.Resources[id])
		end
	end
	if e.KillHeal and target.Humanoid.Health <= 0 then
		local humanoid = alive(source)
		if humanoid then
			CombatServer.heal(source, humanoid.MaxHealth * e.KillHeal)
		end
	end
	if guarded or target.Humanoid.Health <= 0 then
		return
	end
	if e.StunOnHit and math.random() < e.StunOnHit then
		applyCC(target, 0.6, "Shocked")
	end
	local burn = e.BurnOnHit and math.random() < e.BurnOnHit
	if target.Player then
		local foe = state(target.Player)
		if e.SlowOnHit then
			foe.Slow, foe.SlowUntil = math.max(foe.Slow, e.SlowOnHit), now + 2
		end
		if e.Sunder then
			-- Takes that much more damage (as a Vulnerable debuff).
			CrowdControl.applyDebuff(foe.CC, "Vulnerable", e.Sunder, 5, now, true)
		end
		if e.Bleed then
			addDot(target.Player, source, damage * e.Bleed / 3, 3)
		end
		if burn then
			addDot(target.Player, source, damage * 0.4 / 3, 3)
		end
	elseif target.Enemy and burn then
		Enemies.addDot(target.Enemy, damage * 0.4, 3, source, GemConfig.ElementColors.Fire, "Burning")
	end
end
local function strike(source, k, st, target, heavy, projectile, swing)
	if not targetAllowed(source, target) then
		return
	end
	if blindMiss(st, os.clock()) then
		return false, false
	end
	local _, root = alive(source)
	-- A rival duelist is fought by PvP rules, as another player would be.
	local versus = target.Player ~= nil or (target.Enemy ~= nil and target.Enemy.Duel ~= nil)
	local multiplier = if heavy
		then (if versus then k.Rules.HeavyPvPDamage else k.Rules.HeavyDamage)
		else k.Rules.BasicDamage
	local damage = k.Weapon.Attack.Damage
		* Combat.powerMult(rating(k, "Power"))
		* multiplier
		* k.Effects.WeaponAugmentMult
	if swing then
		damage *= swing.Scale * (1 + (swing.Combo - 1) * 0.1)
	end
	if st.Winded then
		damage *= Actions.Stamina.WindedDamage -- swung without the Stamina for it
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
	-- The weapon's perk (Shared.WeaponForge): executes, openers, bloodrage...
	local ownHumanoid = alive(source)
	local targetGuarding = if target.Player
		then blocking(state(target.Player), os.clock())
		else target.Enemy ~= nil
			and (target.Enemy :: any).GuardUntil ~= nil
			and os.clock() < (target.Enemy :: any).GuardUntil
	damage *= WeaponForge.multiplier(k.Effects, {
		Heavy = heavy == true,
		Crit = crit,
		Combo = swing and swing.Combo or 1,
		TargetRatio = target.Humanoid.Health / math.max(1, target.Humanoid.MaxHealth),
		OwnRatio = if ownHumanoid then ownHumanoid.Health / math.max(1, ownHumanoid.MaxHealth) else 1,
		Versus = versus,
		TargetGuarding = targetGuarding,
	})
	local echoDamage = damage
	local guarded = false
	local gem = k.Loadout.WeaponGem
	local element = gem and gem.Element
	if element == "Fire" then
		damage *= k.Effects.ThermalMult
		echoDamage = damage
	end
	if target.Enemy and enemyRiposte(source, target.Enemy) then
		return false, true
	end
	local _, combo = ElementCombos.check({ Element = element, Heavy = heavy == true }, comboFlags(target, os.clock()))
	if combo then
		damage *= combo.Mult or 1
	end
	if target.Player then
		damage, guarded =
			receive(target.Player, damage, element, source, root.Position, projectile, heavy, false, nil, crit)
	else
		Enemies.damage(
			target.Enemy,
			damage,
			source,
			crit,
			if crit then Color3.fromRGB(255, 220, 80) else GemConfig.ElementColors[element] or WHITE,
			heavy == true,
			element
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
		enemyWard(source, target.Enemy)
	end
	if damage > 0 then
		weaponPerksOnHit(source, k, st, target, damage, guarded)
	end
	if combo and damage > 0 then
		comboLanded(source, target, combo)
	end
	if damage <= 0 or target.Humanoid.Health <= 0 then
		return damage > 0 and not guarded, guarded
	end
	if os.clock() < st.EchoUntil then
		local previous = DamageLog.push("Resonance Echo", element)
		if target.Player then
			receive(target.Player, echoDamage, element, source, root.Position, projectile, false, false, nil, false)
		else
			Enemies.damage(target.Enemy, echoDamage, source, false, Color3.fromRGB(70, 180, 255))
		end
		DamageLog.pop(previous)
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
	-- Stamina: a heavy you can't afford comes out as a light swing; a light
	-- swing you can't afford still lands, but winded (weaker).
	updateResources(player, st, k)
	if heavy and st.Resources.Stamina < Actions.swingCost(k.Weapon, true) then
		heavy = false
		if swing then
			swing.Heavy = false
		end
	end
	local cost = Actions.swingCost(k.Weapon, heavy)
	st.Winded = st.Resources.Stamina < cost
	spendStamina(player, st, cost)
	st.NextAttack = now + (if heavy then k.Rules.HeavyCooldown else k.Rules.BasicCooldown)
	st.ChargeStarted = nil
	-- The blow lands now: the body swings through it, as the rival's does.
	posePlayer(player, if heavy then "Heavy" else "Slash", 0)
	Remotes.CombatFx:FireClient(player, "Cooldown", if heavy then "Heavy" else "Basic", st.NextAttack - now)
	local landed, interrupted = false, false
	if swing then
		swing.Combo = Actions.combo(st.ComboSide, st.ComboCount, st.ComboAt, swing.Side, now)
	end
	local label = if k.Weapon.Attack.Kind == "Melee" then "Swing" else "Shot"
	local function hit(target, projectile)
		local previous = DamageLog.push(
			if heavy then "Heavy " .. label else label,
			k.Loadout.WeaponGem and k.Loadout.WeaponGem.Element
		)
		local success, guarded = strike(player, k, st, target, heavy, projectile, swing)
		DamageLog.pop(previous)
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
			if interrupted then "BLOCKED" elseif not landed then "MISS" elseif st.Winded then "WINDED" else swing.Stage,
			swing.Side,
			st.ComboCount
		)
	end
	st.Winded = false
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
-- `kind`: "Hop" (one tap: short, quick, cheap) or "Roll" (double tap, the
-- default: long, with a longer dodge window). A roll can cut a hop short,
-- so tap-tap chains the hop into a roll.
local function dodge(player, requested, kind)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not Combat.canFight(root.Position) or not Actions.finiteVector(requested) then
		return false
	end
	local hop = kind == "Hop"
	local st, now = state(player), os.clock()
	local cost = if hop then Actions.Base.Hop.Cost else Tech.DodgeCost
	local busy = st.DodgeMove ~= nil and not (not hop and st.DodgeMove.Kind == "Hop")
	local ready = if hop then now >= (st.NextHop or 0) else now >= st.NextDodge
	if not ready or now < st.StunUntil or busy or st.Resources.Stamina < cost then
		return false
	end
	local direction = if Vector3.new(requested.X, 0, requested.Z).Magnitude > 0.1
		then flat(requested)
		else flat(root.CFrame.LookVector)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.RespectCanCollide = true
	local distance = if hop then Actions.Base.Hop.Distance else k.Rules.DodgeDistance
	local duration = if hop then Actions.Base.Hop.Duration else Actions.Base.Dodge.Duration
	local collision = workspace:Blockcast(root.CFrame, Vector3.new(2, 3, 2), direction * distance, params)
	local travel = if collision then math.max(0, collision.Distance - 0.2) else distance
	spendStamina(player, st, cost)
	if hop then
		st.NextHop = now + Actions.Base.Hop.Cooldown
	else
		st.NextDodge = now + k.Rules.DodgeCooldown
		st.NextHop = math.max(st.NextHop or 0, now + Actions.Base.Hop.Cooldown)
	end
	st.DodgeStarted, st.DodgeKind = now, if hop then "Hop" else "Roll"
	st.Channel, st.Pending = nil, {}
	st.AfterDodgeUntil, st.BlockUntil, st.ChargeStarted = now + Actions.AfterDodgeSeconds, 0, nil
	if st.DodgeMove then
		stopDodge(st) -- a roll out of a hop
	end
	st.DodgeMove = {
		Kind = st.DodgeKind,
		Root = root,
		Direction = direction,
		Speed = travel / duration,
		Ends = now + duration,
		Lift = if hop then Actions.Base.Hop.Lift else nil,
	}
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	player:SetAttribute("Blocking", false)
	if not hop then
		Remotes.CombatFx:FireClient(player, "Cooldown", "Dodge", k.Rules.DodgeCooldown)
	end
	fx("DodgeRoll", player, root.Position, direction, travel, k.Rules.Deflect and not hop)
	if not hop then
		posePlayer(player, "Dodge", 0)
		local character = player.Character
		if character then
			-- Lean the way you roll.
			local right = root.CFrame.RightVector
			character:SetAttribute("ActionSide", if direction:Dot(right) < 0 then -1 else 1)
		end
	end
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
	if not wasBlocking and st.Resources.Stamina < Actions.Stamina.BlockMin then
		-- Too winded to raise a guard.
		Remotes.CombatFx:FireClient(player, "BlockBroken", 0.4, "Exhausted")
		return false
	end
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
	for _, slot in { "Surge1", "Surge2", "Surge3", "Weapon", "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local gem = loadout[slot .. "Gem"]
		if gem and (not element or gem.Element == element) then
			return gem
		end
	end
	return nil
end
local technologyHitInner
-- Every surge and maneuver hit, labelled for the combat log.
local function technologyHit(player, k, target, definition, scale)
	local previous = DamageLog.push(definition.Name, definition.Element)
	local a, b = technologyHitInner(player, k, target, definition, scale)
	DamageLog.pop(previous)
	return a, b
end
function technologyHitInner(player, k, target, definition, scale)
	if not targetAllowed(player, target) then
		return
	end
	local _, root = alive(player)
	if definition.Resource == "Stamina" and blindMiss(state(player), os.clock()) then
		return
	end
	local gem = if definition.Resource == "Charge"
		then (definition.Gem or surgeGem(k.Loadout, definition.Element))
		else nil
	local damage = k.Weapon.Attack.Damage
		* Combat.powerMult(rating(k, "Power"))
		* definition.Damage
		* (scale or 1)
		* (1 + (k.Effects.SurgeBonus or 0)) -- Saga Conduit (a weapon perk)
	if definition.Resource == "Stamina" then
		damage *= k.Effects.WeaponAugmentMult
	end
	if definition.Element then
		damage *= k.Effects.ElementMult[definition.Element] or 1
		-- Elemental Harmony: switching elements within 5s hits harder.
		local st, now = state(player), os.clock()
		if k.Effects.Harmony > 0 then
			if now < st.HarmonyUntil and st.HarmonyElement ~= definition.Element then
				damage *= 1 + k.Effects.Harmony
			end
			st.HarmonyElement, st.HarmonyUntil = definition.Element, now + 5
		end
	end
	if gem then
		damage *= 1 + math.clamp(gem.Size or 1, 1, 10) * 0.03
	end
	-- A surge gem's Cut sets its critical chance.
	local crit = (definition.Crit or 0) > 0 and math.random() < definition.Crit
	if crit then
		damage *= Combat.CritMult
	end
	local color = GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80)
	if target.Enemy and enemyRiposte(player, target.Enemy) then
		return
	end
	local _, combo = ElementCombos.check(
		{ Element = definition.Element, Heavy = definition.Heavy == true },
		comboFlags(target, os.clock())
	)
	if combo then
		damage *= combo.Mult or 1
	end
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
		Enemies.damage(target.Enemy, damage, player, crit, color, nil, definition.Element)
		enemyWard(player, target.Enemy)
	end
	if damage <= 0 then
		return
	end
	if combo then
		comboLanded(player, target, combo)
	end
	-- Pneumatic Jab: cancel a cast in progress and lock the caster's surges.
	if definition.Interrupt then
		if target.Player then
			CombatServer.interrupt(target.Player, definition.Interrupt)
		elseif Enemies.interrupt then
			Enemies.interrupt(target.Enemy, definition.Interrupt)
		end
	end
	-- Leech (Toxic Cloud): drink part of what it deals.
	if definition.Leech then
		CombatServer.heal(player, damage * definition.Leech)
	end
	if definition.Blind then
		local seconds = definition.BlindTime or 2.5
		if target.Player then
			local victim = state(target.Player)
			victim.Blind, victim.BlindUntil = definition.Blind, math.max(victim.BlindUntil, os.clock() + seconds)
		else
			Enemies.addStatus(target.Enemy, "Blind", definition.Blind, seconds)
		end
	end
	if definition.Stun then
		applyCC(
			target,
			definition.Stun,
			if definition.Element == "Frost"
				then "Frozen"
				elseif definition.Element == "Shock" then "Shocked"
				else "Stunned"
		)
	end
	if definition.Slow then
		if target.Player then
			local victim = state(target.Player)
			local slowTime = definition.SlowTime or 0.75
			victim.Slow = CrowdControl.applyDebuff(victim.CC, "Slow", definition.Slow, slowTime, os.clock(), true)
			victim.SlowUntil = os.clock() + slowTime
		else
			Enemies.addStatus(target.Enemy, "Slow", definition.Slow, definition.SlowTime or 0.75)
		end
	end
	if definition.Shred then
		local now = os.clock()
		if target.Player then
			local victim = state(target.Player)
			victim.Sunder =
				CrowdControl.applyDebuff(victim.CC, "Sunder", definition.Shred, definition.ShredTime or 5, now, true)
			victim.SunderUntil = victim.CC.Debuffs.Sunder.Until
		else
			Enemies.addStatus(target.Enemy, "Sunder", definition.Shred, definition.ShredTime or 5)
		end
	end
	-- Execute: finish a target left below the threshold.
	if definition.Execute and target.Humanoid and target.Humanoid.Health > 0 then
		if target.Humanoid.Health < target.Humanoid.MaxHealth * definition.Execute then
			if target.Player then
				target.Humanoid.Health = 0
			else
				Enemies.damage(target.Enemy, target.Humanoid.MaxHealth * 10, player, true, color)
			end
		end
	end
	if definition.Element == "Fire" and gem then
		local values = GemConfig.stats(gem, "Weapon", { Affinity = k.Affinity, PvP = target.Player ~= nil })
		if target.Player then
			addDot(target.Player, player, values.BurnDamage * k.Effects.ThermalMult, values.BurnDuration)
		else
			Enemies.addDot(
				target.Enemy,
				values.BurnDamage * k.Effects.ThermalMult,
				values.BurnDuration,
				player,
				color,
				"Burning"
			)
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
		or (st.DodgeMove and os.clock() < st.DodgeMove.Ends) -- (a leap lands as it ends)
	then
		return
	end
	if definition.Resource == "Charge" and not definition.Gem and not Tech.hasGem(k.Loadout, definition.Element) then
		return
	end
	if definition.Ward then
		-- The barrier rises as the cast lands (Burning Ward, Static Shell).
		local ward, now = definition.Ward, os.clock()
		local size = definition.Gem and definition.Gem.Size or 1
		st.Shield = math.max(st.Shield, ward.Shield + size * 3)
		st.ShieldUntil = math.max(st.ShieldUntil, now + ward.Duration)
		st.SurgeWardUntil, st.SurgeWardKind = now + ward.Duration, ward.Kind
		st.SurgeWardPower = k.Weapon.Attack.Damage * Combat.powerMult(rating(k, "Power")) * (ward.Power or 0)
		st.SurgeWardStun = ward.Stun
		fx("TechField", player, GemConfig.ElementColors[definition.Element] or WHITE)
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = aim - origin
	local direction = if offset.Magnitude > 0.01 then offset.Unit else root.CFrame.LookVector
	local center = if definition.Self
		then root.Position
		else origin + direction * math.min(offset.Magnitude, definition.Range)
	local color = GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80)
	if definition.Signature and lineClear(origin, center) then
		fx("AbilitySignature", player, origin, center, color, definition.Signature, definition.Radius or 3)
	end
	if definition.Cone then
		-- A cone in front, out to Range (Acid Spray).
		local half = math.cos(math.rad(definition.Cone / 2))
		fx("Swing", player, root.Position, flat(direction), definition.Range, definition.Cone, color, false)
		for _, target in targets(player) do
			local v = target.Root.Position - root.Position
			if
				v.Magnitude <= definition.Range
				and flat(v):Dot(flat(direction)) >= half
				and lineClear(origin, target.Root.Position + Vector3.new(0, 1.5, 0))
			then
				technologyHit(player, k, target, definition, scale)
			end
		end
	elseif definition.Resource == "Stamina" then
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
		if not definition.Self and not lineClear(origin, center) then
			return
		end
		local radius = if definition.Cloud then definition.Radius else Actions.blastRadius(definition.Radius)
		fx("TechPulse", player, origin, center, color, radius)
		if definition.Cloud then
			-- A lingering pool that keeps hitting (Toxic Cloud).
			st.Zones = st.Zones or {}
			local cloud = definition.Cloud
			table.insert(st.Zones, {
				Center = center,
				Radius = definition.Radius,
				Every = cloud.Every,
				Next = os.clock() + cloud.Every,
				Until = os.clock() + (definition.Duration or cloud.Duration),
				Definition = {
					Name = definition.Name,
					Resource = "Charge",
					Gem = definition.Gem,
					Element = definition.Element,
					Damage = cloud.Damage,
					Shred = cloud.Shred,
					ShredTime = cloud.Every * 2,
					Leech = definition.Leech,
				},
			})
		end
		-- A blast lands as anyone's does (Actions.blastFalloff): wide, and
		-- harder the closer to its centre: a stun at the core, a stagger in
		-- the middle, a graze at the edge. (A lingering pool keeps its own size.)
		for _, target in targets(player) do
			local offset = target.Root.Position - center
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance <= radius and lineClear(center, target.Root.Position + Vector3.new(0, 1.5, 0)) then
				local falloff, cc, seconds = 1, nil, 0
				if not definition.Cloud then
					falloff, cc, seconds = Actions.blastFalloff(distance, radius)
				end
				technologyHit(player, k, target, definition, (scale or 1) * falloff)
				if cc and target.Humanoid.Health > 0 then
					if target.Player then
						CombatServer.blastCC(
							target.Player,
							cc,
							seconds,
							center,
							if cc == "Stunned" then Actions.Blast.Knockback else 0
						)
					elseif target.Enemy then
						Enemies.addStatus(target.Enemy, "Stun", 1, seconds)
						target.Enemy.StunKind = cc
					end
				end
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
		if definition.Piercing then
			-- Pierces: everyone along the line, out to Range (Cryo Lance).
			fx("TechPulse", player, origin, origin + direction * definition.Range, color, 0)
			for _, target in targets(player) do
				local v = target.Root.Position + Vector3.new(0, 1.5, 0) - origin
				local projection = v:Dot(direction)
				if
					projection > 0
					and projection <= definition.Range
					and (v - direction * projection).Magnitude <= 2
					and lineClear(origin, target.Root.Position + Vector3.new(0, 1.5, 0))
				then
					technologyHit(player, k, target, definition, scale)
				end
			end
			return
		end
		fx("TechPulse", player, origin, origin + direction * along, color, 0)
		if nearest then
			technologyHit(player, k, nearest, definition, scale)
			-- Chain: bounce on to the nearest new targets, 20% weaker each jump.
			local struck, from = { [nearest.Root] = true }, nearest
			for jump = 1, definition.Chain or 0 do
				local best, bestDistance = nil, definition.ChainRange or 12
				for _, target in targets(player) do
					local distance = (target.Root.Position - from.Root.Position).Magnitude
					if not struck[target.Root] and distance <= bestDistance then
						best, bestDistance = target, distance
					end
				end
				if not best then
					break
				end
				struck[best.Root] = true
				fx("TechPulse", player, from.Root.Position, best.Root.Position, color, 0)
				technologyHit(player, k, best, definition, (scale or 1) * 0.8 ^ jump)
				from = best
			end
			-- Spread: corrosion and half the hit jump to everyone nearby.
			if definition.Spread then
				fx("TechPulse", player, nearest.Root.Position, nearest.Root.Position, color, definition.Spread)
				for _, target in targets(player) do
					if
						target.Root ~= nearest.Root
						and (target.Root.Position - nearest.Root.Position).Magnitude <= definition.Spread
					then
						technologyHit(player, k, target, definition, (scale or 1) * 0.5)
					end
				end
			end
		end
	end
end
-- Rig Maneuvers (learned in the Augment Tree, keys 1-3) and Gem Surges (the
-- gem in Surge Array slot Q, E or R). `surgeKey` marks a surge cast.
-- A self surge taking effect (when its cast completes).
local function applyBuff(player, k, st, id, definition)
	local now = os.clock()
	if id == "EnergySiphon" then
		st.SiphonUntil, st.SiphonCapacity = now + definition.Duration, definition.Absorb
		fx("TechField", player, Tech.Resources.Charge.Color)
	elseif id == "ResonanceEcho" then
		st.EchoUntil = now + definition.Duration
		fx("TechField", player, Tech.Resources.Charge.Color)
	elseif id == "CryoShield" then
		local gem = definition.Gem or surgeGem(k.Loadout, "Frost")
		st.Shield = math.max(st.Shield, 30 + (gem and gem.Size or 1) * 3)
		st.ShieldUntil = math.max(st.ShieldUntil, now + definition.Duration)
		fx("TechField", player, GemConfig.ElementColors.Frost)
	end
end
local function triggerTechnology(player, id, aim, surgeKey)
	local k, st, now = kit(player), state(player), os.clock()
	local humanoid, root = alive(player)
	if not k or not humanoid or not Actions.finiteVector(aim) or not Combat.canFight(root.Position) then
		return false
	end
	local profile = PlayerData.get(player)
	local definition, cooldownKey
	if surgeKey then
		-- The surge comes from the gem: its element and tier pick the ability;
		-- its rank, Size, Clarity and Cut, plus Surge Amplifiers, set the numbers.
		local gem = Tech.surgeGem(k.Loadout, surgeKey)
		if not gem then
			Remotes.CombatFx:FireClient(player, "TechStatus", "Socket a gem in surge slot " .. surgeKey)
			return false
		end
		if now < st.SilenceUntil then
			Remotes.CombatFx:FireClient(player, "TechStatus", "Interrupted: surges locked")
			return false
		end
		definition = Tech.surgeStats(gem, if inArena(player) then nil else Tree.effects(profile))
		cooldownKey = "Surge" .. surgeKey
	else
		local base = if typeof(id) == "string" then Tech.Catalog[id] else nil
		if not base or base.Resource ~= "Stamina" then
			return false
		end
		if not Tree.isLearned(profile, id) then
			Remotes.CombatFx:FireClient(player, "TechStatus", "Unlock " .. base.Name .. " in the Augment Tree.")
			return false
		end
		-- Ranks II and III hit harder, cost less, recover faster and last longer.
		definition = if inArena(player) then Tree.scaled(base, 1) else Tree.techStats(profile, id)
		cooldownKey = id
	end
	if not definition then
		return false
	end
	id = definition.Id or id
	if now < st.StunUntil or st.DodgeMove or blocking(st, now) or st.ChargeStarted then
		return false
	end
	if definition.PerSecond and st.Channel and st.Channel.Key == cooldownKey then
		st.Channel.Aim, st.Channel.Until = aim, now + 0.5
		return true
	end
	if now < st.NextAttack or now < st.NextTech or now < (st.TechCooldowns[cooldownKey] or 0) or st.Channel then
		return false
	end
	if definition.Shield and not Classes.heldShield(k.Loadout) then
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
		local previous = DamageLog.push(definition.Name)
		CombatServer.heal(player, humanoid.MaxHealth * definition.Heal)
		DamageLog.pop(previous)
	elseif definition.Leap then
		-- Thruster Leap: airborne toward the aimed spot; the blow lands on
		-- touchdown (its wind-up), wherever that is.
		local offset = flat(aim - root.Position)
		local reach = (aim - root.Position) * Vector3.new(1, 0, 1)
		local direction = if reach.Magnitude > 0.1 then offset else flat(root.CFrame.LookVector)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		params.RespectCanCollide = true
		local distance = math.clamp(reach.Magnitude - 3, 2, definition.Leap)
		local collision = workspace:Blockcast(root.CFrame, Vector3.new(2, 3, 2), direction * distance, params)
		local travel = if collision then math.max(0, collision.Distance - 0.2) else distance
		local airborne = math.max(0.15, (definition.Windup or 0.4) - 0.05)
		st.DodgeMove = {
			Kind = "Leap",
			Root = root,
			Direction = direction,
			Speed = travel / airborne,
			Ends = now + airborne,
			Lift = 14,
		}
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		fx("DodgeRoll", player, root.Position, direction, travel, false)
		spendStamina(player, st, cost)
	elseif definition.Riposte then
		-- Riposte Stance: braced; the next blow is turned aside (receive).
		st.RiposteUntil = now + definition.Riposte
		st.RiposteDamage = k.Weapon.Attack.Damage
			* Combat.powerMult(rating(k, "Power"))
			* (definition.CounterDamage or 1)
			* k.Effects.WeaponAugmentMult
		fx("BlockRaise", player)
		spendStamina(player, st, cost)
	elseif definition.Resource == "Stamina" then
		spendStamina(player, st, cost)
	else
		Tech.spend(st.Resources, definition.Resource, cost)
	end
	-- A short lockout (Recovery) for everything, and this ability's own cooldown.
	local recovery = definition.Recovery * (k.Effects.CooldownMult or 1)
	local cooldown = math.max(recovery, (definition.Cooldown or definition.Recovery) * (k.Effects.CooldownMult or 1))
	st.TechCooldowns[cooldownKey], st.NextTech = now + cooldown, now + recovery
	st.NextAttack = math.max(st.NextAttack, st.NextTech)
	st.ComboSide, st.ComboCount, st.ComboAt = nil, 0, nil
	player:SetAttribute(definition.Resource, st.Resources[definition.Resource])
	Remotes.CombatFx:FireClient(player, "TechCooldown", cooldownKey, cooldown, recovery)
	Remotes.CombatFx:FireClient(player, "TechStatus", definition.Name)
	-- Every cast takes the same time it takes anyone (Actions.castTime):
	-- the effect lands when the cast completes, the cast bar fills, the
	-- body poses (seen by everyone) and a ground blast shows its warning
	-- ring. A dodge or stun cuts it short.
	local castTime = Actions.castTime(definition)
	local castKind = Actions.castKind(definition)
	posePlayer(player, Actions.castPose(definition), castTime, definition.Name, definition.Element)
	local castSpeed = Actions.castMovement(definition)
	if castSpeed < 1 then
		st.CastUntil, st.CastSpeed = now + castTime, castSpeed
	end
	if castKind == "Blast" or castKind == "Field" then
		local origin = root.Position + Vector3.new(0, 1.5, 0)
		local offset = aim - origin
		local direction = if offset.Magnitude > 0.01 then offset.Unit else root.CFrame.LookVector
		local center = if definition.Self
			then root.Position
			else origin + direction * math.min(offset.Magnitude, definition.Range or 30)
		fx(
			"Nova",
			center - Vector3.new(0, 2.5, 0),
			Actions.blastRadius(definition.Radius),
			GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80),
			castTime
		)
	end
	if not definition.Damage and definition.Resource == "Charge" then
		table.insert(st.Pending, { Buff = id, Definition = definition, At = now + castTime })
	elseif definition.PerSecond then
		table.insert(st.Pending, { Channel = cooldownKey, Definition = definition, Aim = aim, At = now + castTime })
	elseif definition.Damage then
		table.insert(st.Pending, { Definition = definition, Aim = aim, At = now + castTime })
		if definition.Hits == 2 then
			table.insert(st.Pending, { Definition = definition, Aim = aim, At = now + castTime + 0.16 })
		end
		-- Arcane Resonance: a chance for the surge to fire a second time, free.
		if (definition.Echo or 0) > 0 and math.random() < definition.Echo then
			table.insert(st.Pending, { Definition = definition, Aim = aim, At = now + castTime + 0.3 })
			Remotes.CombatFx:FireClient(player, "TechStatus", "Arcane Resonance!")
		end
	end
	return true
end
local function onInput(player, action, a, b)
	if not Actions.validInput(action, a, b) then
		return
	end
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
		posePlayer(player, nil, 0)
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
	if action == "RigManeuver" then
		triggerTechnology(player, a, b)
	elseif action == "Surge" then
		if a == "Q" or a == "E" or a == "R" then
			triggerTechnology(player, nil, b, a)
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
			-- The arm draws back while the blow charges.
			posePlayer(player, "Slash", 3)
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
		dodge(player, a, b)
	elseif action == "Block" and a == true then
		block(player, true, b)
	end
end
-- A monster or Duelist hit. `heavy` blows break a raised guard, like a player's.
-- A ground blast caught `player` (Actions.blastFalloff): stun or stagger
-- them (CrowdControl's diminishing returns apply) and, from the core, throw
-- them out of it. The player's own client moves their character, so the
-- push travels with the "Blasted" message.
-- Armor shred on a player (a rival's Toxic Cloud), as a player's cloud shreds.
function CombatServer.sunder(player, amount, seconds)
	local victim = state(player)
	victim.Sunder = CrowdControl.applyDebuff(victim.CC, "Sunder", amount, seconds, os.clock(), true)
	victim.SunderUntil = victim.CC.Debuffs.Sunder.Until
end

function CombatServer.blastCC(player, kind, seconds, center, push)
	local humanoid, root = alive(player)
	if not humanoid or not kind or seconds <= 0 then
		return
	end
	applyCC({ Player = player }, seconds, kind)
	local away = flat(root.Position - center)
	Remotes.CombatFx:FireClient(player, "Blasted", kind, seconds, away * (push or 0))
end
-- A rival duelist's gear effects landing on `player`, as a player's land on
-- their target: Sunder (5s) and SlowOnHit (2s).
function CombatServer.rivalHitEffects(player, effects)
	local st, now = state(player), os.clock()
	if effects.Sunder then
		st.Sunder = CrowdControl.applyDebuff(st.CC, "Sunder", effects.Sunder, 5, now, true)
		st.SunderUntil = st.CC.Debuffs.Sunder.Until
	end
	if effects.SlowOnHit then
		st.Slow = CrowdControl.applyDebuff(st.CC, "Slow", effects.SlowOnHit, 2, now, true)
		st.SlowUntil = st.CC.Debuffs.Slow.Until
	end
end
-- An interrupt (Pneumatic Jab) on `player`: a surge being cast or poured is
-- cancelled and their surges lock for `seconds`. True if one was cancelled.
function CombatServer.interrupt(player, seconds)
	local st, now = state(player), os.clock()
	local casting = st.Channel ~= nil
	for _, pending in st.Pending do
		if pending.Definition and pending.Definition.Resource == "Charge" then
			casting = true
		end
	end
	if not casting then
		return false
	end
	st.Channel, st.Pending = nil, {}
	st.SilenceUntil = now + seconds
	posePlayer(player, nil, 0)
	Remotes.CombatFx:FireClient(player, "Interrupted", seconds)
	return true
end
-- An element combo landing on `player` from a rival (Shared.ElementCombos).
function CombatServer.comboOnPlayer(player, combo, enemy)
	local _, root = alive(player)
	if root then
		comboLanded(nil, { Player = player, Root = root }, combo)
	end
end
-- What `player` is suffering, for a rival's combos.
function CombatServer.comboFlags(player)
	return comboFlags({ Player = player }, os.clock())
end
-- A rival's surge riders landing on `player`, as a player's land: Blind
-- (Solar Flare) and Slow (Armor Melt, Cryo Stream).
function CombatServer.afflict(player, riders)
	local st, now = state(player), os.clock()
	if riders.Blind then
		st.Blind, st.BlindUntil = riders.Blind, math.max(st.BlindUntil, now + (riders.BlindTime or 2.5))
	end
	if riders.Slow then
		st.Slow = CrowdControl.applyDebuff(st.CC, "Slow", riders.Slow, riders.SlowTime or 0.75, now, true)
		st.SlowUntil = st.CC.Debuffs.Slow.Until
	end
end
-- A rival duelist's Corrosive aura while it blocks (a gem defence).
function CombatServer.rivalAura(player, amount)
	CrowdControl.applyDebuff(state(player).CC, "Aura", amount, 0.5, os.clock(), true)
end

function CombatServer.hurt(player, amount, element, enemy, heavy, crit)
	if enemy and enemy.DungeonId and player:GetAttribute("DungeonId") ~= enemy.DungeonId then
		return 0, false
	end
	return receive(
		player,
		amount,
		element,
		nil,
		enemy and enemy.Root.Position,
		false,
		heavy == true,
		false,
		enemy,
		crit
	)
end
-- os.clock() -> server time, which clients can count down against.
local clockOffset
local function serverTime(t)
	if not clockOffset then
		local ok, server = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		clockOffset = if ok and type(server) == "number" then server - os.clock() else 0
	end
	return t + clockOffset
end
CombatServer._serverTime = serverTime

-- The player's buffs and debuffs, for status bars (see Shared.StatusEffects).
local function playerStatuses(st, now)
	local list = {}
	local function add(id, ends, value)
		if ends > now then
			table.insert(list, { Id = id, Ends = serverTime(ends), Value = value or 0 })
		end
	end
	if st.Shield > 0 then
		add("Shielded", st.ShieldUntil, st.Shield)
	end
	if st.SiphonCapacity > 0 then
		add("EnergySiphon", st.SiphonUntil, st.SiphonCapacity)
	end
	add("ResonanceEcho", st.EchoUntil)
	add(if st.SurgeWardKind == "Burn" then "BurningWard" else "StaticShell", st.SurgeWardUntil)
	add(st.StunKind or "Stunned", st.StunUntil)
	add("Blinded", st.BlindUntil, st.Blind * 100)
	add("RiposteStance", st.RiposteUntil)
	add("Silenced", st.SilenceUntil)
	add("GuardBroken", st.BlockBrokenUntil)
	for _, dot in st.Dots do
		add("Burning", dot.Ends)
	end
	add("Slowed", st.SlowUntil, st.Slow * 100)
	add("ArmorShred", st.SunderUntil, st.Sunder * 100)
	local debuffs = st.CC.Debuffs
	if debuffs.Vulnerable then
		add("Vulnerable", debuffs.Vulnerable.Until, debuffs.Vulnerable.Amount * 100)
	end
	if debuffs.Aura then
		add("Exposed", debuffs.Aura.Until, debuffs.Aura.Amount * 100)
	end
	for kind, ends in st.CC.HealCuts do
		add(kind, ends)
	end
	return list
end
function publishStatuses(owner: Instance, st, now)
	local text = StatusEffects.encode(playerStatuses(st, now), serverTime(now))
	if owner:GetAttribute("Statuses") ~= (if text == "" then nil else text) then
		owner:SetAttribute("Statuses", if text == "" then nil else text)
	end
end

local function tick(dt)
	local now = os.clock()
	-- Players' bodies are posed on every client (Client BodyPoses) from the
	-- attributes set here: a character belongs to its own client, so joint
	-- changes made here would reach the other players late or not at all.
	for _, player in Players:GetPlayers() do
		local st, k = state(player), kit(player)
		local humanoid, root = alive(player)
		if not humanoid or not k or not Combat.canFight(root.Position) then
			st.BlockUntil, st.ChargeStarted, st.DodgeStarted = 0, nil, nil
			st.Dots, st.Pending, st.Channel, st.Zones = {}, {}, nil, {}
			stopDodge(st)
			player:SetAttribute("Blocking", false)
			if player:GetAttribute("Statuses") ~= nil then
				player:SetAttribute("Statuses", nil)
			end
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
				if pending.Buff then
					applyBuff(player, k, st, pending.Buff, pending.Definition)
				elseif pending.Channel then
					technologyStrike(player, pending.Definition, pending.Aim, 0.25)
					st.Channel = {
						Key = pending.Channel,
						Definition = pending.Definition,
						Aim = pending.Aim,
						Until = now + 0.5,
						Next = now + 0.25,
					}
				else
					technologyStrike(player, pending.Definition, pending.Aim)
				end
			end
		end
		for i = #(st.Zones or {}), 1, -1 do
			local zone = st.Zones[i]
			if now >= zone.Until then
				table.remove(st.Zones, i)
			elseif now >= zone.Next then
				zone.Next += zone.Every
				fx(
					"TechPulse",
					player,
					zone.Center,
					zone.Center,
					GemConfig.ElementColors[zone.Definition.Element],
					zone.Radius
				)
				for _, target in targets(player) do
					if (target.Root.Position - zone.Center).Magnitude <= zone.Radius then
						technologyHit(player, k, target, zone.Definition)
					end
				end
			end
		end
		if st.Channel then
			-- A held beam (Cryo Stream): bills a quarter-second at a
			-- time and stops when released, blocked or its gem leaves the slot.
			local channel = st.Channel
			local definition = channel.Definition
			local surgeKey = string.match(channel.Key, "^Surge(%a)$")
			local gemGone = surgeKey ~= nil and Tech.surgeGem(k.Loadout, surgeKey) ~= definition.Gem
			if now >= channel.Until or blocking(st, now) or st.DodgeMove or gemGone then
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
		if st.Channel and player.Character then
			-- Keep the cast pose while the beam pours, as a rival's does.
			local hold = player.Character:GetAttribute("ActionHold")
			local serverNow = workspace:GetServerTimeNow()
			if type(hold) ~= "number" or hold < serverNow + 0.15 then
				player.Character:SetAttribute("ActionHold", serverNow + 0.3)
			end
		end
		player:SetAttribute("Charge", st.Resources.Charge)
		if st.DodgeMove then
			if now >= st.DodgeMove.Ends then
				stopDodge(st)
			else
				local move = st.DodgeMove
				-- A hop leaves the ground once; a roll stays low.
				local lift = if move.Lift
					then (if move.Lifted then root.AssemblyLinearVelocity.Y else move.Lift)
					else math.min(root.AssemblyLinearVelocity.Y, 0)
				move.Lifted = true
				root.AssemblyLinearVelocity = move.Direction * move.Speed + Vector3.new(0, lift, 0)
			end
		end
		if st.ChargeStarted and now - st.ChargeStarted > 3 then
			st.ChargeStarted = nil
		end
		player:SetAttribute("Blocking", blocking(st, now))
		-- The shield comes up for everyone to see, as the rival's does.
		if player.Character then
			player.Character:SetAttribute(
				"GuardUntil",
				if blocking(st, now) then workspace:GetServerTimeNow() + (st.BlockUntil - now) else 0
			)
		end
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
		local speed = Classes.walkSpeed(rating(k, "Speed")) * k.Effects.MobilityMult
		-- Casting: rooted through a wind-up, slowed while a beam pours out or
		-- just after a throw (Actions.castMovement).
		local casting = if st.Channel
			then select(1, Actions.castMovement(st.Channel.Definition))
			elseif now < (st.CastUntil or 0) and (st.CastSpeed > 0 or #st.Pending > 0) then st.CastSpeed
			else 1 -- (a wind-up a dodge or stun cut short frees you)
		humanoid.WalkSpeed = if now < st.StunUntil
			then 0
			else speed
				* (if now < st.SlowUntil then 1 - st.Slow else 1)
				* (if blocking(st, now) then 0.6 else 1)
				* casting
		player:SetAttribute("CastRooted", casting == 0)
		if now >= st.ShieldUntil then
			st.Shield = 0
		end
		if k.Effects.Ward and now >= st.NextWard then
			st.NextWard, st.Shield, st.ShieldUntil = now + 8, math.max(st.Shield, k.Effects.Ward), now + 8
		end
		for source, dot in st.Dots do
			-- A burn from a computer fighter (an enemy table) lasts while it lives.
			local fromEnemy = type(source) == "table" and source.Alive ~= nil
			if if fromEnemy then not source.Alive else not canPvP(source, player) then
				st.Dots[source] = nil
			elseif now >= dot.Next then
				local through = math.min(now, dot.Ends)
				local previous = DamageLog.push("Burning", "Fire")
				if fromEnemy then
					receive(player, dot.Damage * (through - dot.Last), "Fire", nil, nil, false, false, false, source)
				else
					receive(player, dot.Damage * (through - dot.Last), "Fire", source, nil, false, false, false)
				end
				DamageLog.pop(previous)
				dot.Last, dot.Next = through, math.min(through + 1, dot.Ends)
				if through >= dot.Ends then
					st.Dots[source] = nil
				end
			end
		end
		player:SetAttribute("Shield", math.floor(st.Shield))
		player:SetAttribute("CombatCharging", st.ChargeStarted ~= nil)
		publishStatuses(player, st, now)
	end
end
-- A computer fighter's gem landing on a player: the same element effects a
-- player's gem would apply in PvP (burn, slow and freeze, armor shred).
function CombatServer.enemyProc(player, gem, enemy)
	local humanoid, root = alive(player)
	if not humanoid or not gem then
		return
	end
	local values = GemConfig.actionValues(gem, "Basic", { PvP = true })
	local st, now = state(player), os.clock()
	local target = { Player = player, Humanoid = humanoid, Root = root }
	if values.Burn then
		addDot(player, enemy, values.Burn, values.Duration)
		if math.random() < (values.Ignite or 0) then
			CrowdControl.applyHealCut(st.CC, "GrievousWounds", now)
		end
	end
	if values.Slow then
		st.Slow = CrowdControl.applyDebuff(st.CC, "Slow", values.Slow, values.Duration, now, true)
		st.SlowUntil = st.CC.Debuffs.Slow.Until
		if math.random() < (values.Freeze or 0) then
			applyCC(target, values.FreezeSeconds, "Frozen")
		end
	end
	if values.Sunder then
		st.Sunder = CrowdControl.applyDebuff(st.CC, "Sunder", values.Sunder, values.Duration, now, true)
		st.SunderUntil = st.CC.Debuffs.Sunder.Until
		if math.random() < (values.Vulnerable or 0) then
			CrowdControl.applyDebuff(st.CC, "Vulnerable", values.VulnerableAmount, values.Duration, now, true)
			CrowdControl.applyHealCut(st.CC, "MortalStrike", now)
		end
	end
	if values.Arc and math.random() < (values.Stun or 0) then
		applyCC(target, values.StunSeconds, "Shocked")
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
	local cut = amount * (1 + (k.Effects.HealingReceived or 0)) - healing
	DamageLog.send(player, { Dir = "In", Kind = "Heal", Amount = restored, Blocked = cut })
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
	Enemies.hitPlayer = function(player, amount, element, enemy, heavy, crit)
		return CombatServer.hurt(player, amount, element, enemy, heavy, crit)
	end
	-- A rival parried your swing: you're left open for a moment.
	Enemies.parryPlayer = function(player, seconds)
		local st = state(player)
		local now = os.clock()
		st.StunUntil = math.max(st.StunUntil, now + seconds)
		st.StunKind = "Stunned"
		st.ChargeStarted, st.ComboSide, st.ComboCount = nil, nil, 0
		Remotes.CombatFx:FireClient(player, "Parried", seconds)
	end
	Remotes.CombatInput.OnServerEvent:Connect(onInput)
	Shop.register("SetRigManeuvers", function()
		return Shop.reply(
			false,
			"Put Rig Maneuvers on keys 1, 2 and 3 and gems in the Surge Array (Q, E, R) from the Loadout."
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
