-- Server-authoritative universal actions. Only opted-in Arena players can damage each other.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Classes = require(ReplicatedStorage.Shared.Classes)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local EquipmentBalance = require(ReplicatedStorage.Shared.EquipmentBalance)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
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
	return {
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
		}
	end
	return states[player]
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
	if source.Character:FindFirstChildOfClass("ForceField") then return false end
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
	return workspace:Raycast(from, to - from, params) == nil
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
end
local function triggerBlockGem(player, k, st, now)
	if now < st.NextBlockGem then
		return
	end
	local gem = blockGem(k)
	if not gem then
		return
	end
	local values = GemConfig.actionValues(gem, "Block")
	if values.Cleanse then
		cleanse(st)
	end
	local amount = values.FrostShield or values.Recharge
	if amount then
		st.Shield = math.min(25, st.Shield + amount)
		st.ShieldUntil = now + 5
	end
	st.NextBlockGem = now + 3
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
receive = function(player, amount, element, source, origin, projectile, heavy, reflected, enemySource, crit)
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
	local resistance = 0
	for _, slot in Slots.Order do
		local gem = k.Loadout[slot .. "Gem"]
		if slot ~= "Weapon" and gem and gem.Element == element then
			resistance += GemConfig.enchantValues(gem, slot).Resist / 5
		end
	end
	local defense = rating(k, "Defense") * (if now < st.SunderUntil then 1 - st.Sunder else 1)
	local damage = amount
		* Combat.defenseMult(defense)
		* EquipmentBalance.passiveDamageMultiplier(k.Effects.TakenMult, resistance)
	if blocking(st, now) and origin then
		local dot = flat(origin - root.Position):Dot(st.BlockDirection or flat(root.CFrame.LookVector))
		if heavy and dot >= math.cos(math.rad(k.Rules.BlockArc / 2)) then
			st.BlockUntil, st.BlockBrokenUntil = 0, now + Actions.Base.Heavy.BreakSeconds
			player:SetAttribute("Blocking", false)
			Remotes.CombatFx:FireClient(player, "BlockBroken", Actions.Base.Heavy.BreakSeconds)
			fx("BlockSpark", root.Position, true)
		else
			local multiplier, covered = Actions.blockMultiplier(k.Rules, pvp, dot, projectile, heavy)
			if covered then
				fx("BlockSpark", root.Position, false)
				local gem = blockGem(k)
				if gem and element == "Fire" and not reflected then
					local reflect = GemConfig.actionValues(gem, "Block").ReflectThermal
					if reflect and source then
						receive(source, damage * reflect, "Fire", player, root.Position, false, false, true)
					elseif reflect and enemySource then
						Enemies.damage(enemySource, damage * reflect, player, false, GemConfig.ElementColors.Fire)
					end
				end
				damage *= multiplier
			end
		end
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
	return damage
end
local function addDot(player, source, total)
	local st = state(player)
	st.Dots[source] = { Source = source, Remaining = 3, Damage = total / 3, Next = os.clock() + 1 }
end
local function procGem(source, k, target, damage)
	local gem = k.Loadout.WeaponGem
	if not gem then
		return
	end
	local values = GemConfig.actionValues(gem, "Basic")
	if target.Player then
		local st, now = state(target.Player), os.clock()
		if values.Burn then
			addDot(target.Player, source, values.Burn)
		end
		if values.Slow then
			st.Slow, st.SlowUntil = math.max(st.Slow, values.Slow), now + 2
		end
		if values.Sunder then
			st.Sunder, st.SunderUntil = math.min(0.4, math.max(st.Sunder, values.Sunder)), now + 4
		end
	else
		if values.Burn then
			Enemies.addDot(target.Enemy, values.Burn, 3, source, GemConfig.ElementColors.Fire)
		end
		if values.Slow then
			Enemies.addStatus(target.Enemy, "Slow", values.Slow, 2)
		end
		if values.Sunder then
			Enemies.addStatus(target.Enemy, "Sunder", values.Sunder, 4)
		end
	end
	if values.Arc then
		local closest, distance = nil, 14
		for _, other in targets(source) do
			if
				other.Root ~= target.Root
				and targetAllowed(source, other)
				and lineClear(target.Root.Position, other.Root.Position)
			then
				local d = (other.Root.Position - target.Root.Position).Magnitude
				if d < distance then
					closest, distance = other, d
				end
			end
		end
		if closest then
			fx("Arc", target.Root.Position, closest.Root.Position, GemConfig.ElementColors.Shock)
			if closest.Player then
				receive(closest.Player, damage * values.Arc, "Shock", source, target.Root.Position, true, false, false)
			else
				Enemies.damage(closest.Enemy, damage * values.Arc, source, false, GemConfig.ElementColors.Shock)
			end
		end
	end
end
local function strike(source, k, st, target, heavy, projectile)
	if not targetAllowed(source, target) then
		return
	end
	local _, root = alive(source)
	local multiplier = if heavy
		then (if target.Player then k.Rules.HeavyPvPDamage else k.Rules.HeavyDamage)
		else k.Rules.BasicDamage
	local damage = k.Weapon.Attack.Damage * Combat.powerMult(rating(k, "Power")) * multiplier
	if os.clock() < st.AfterDodgeUntil then
		damage *= 1 + (k.Effects.DamageAfterDodge or 0)
	end
	local crit = math.random()
		< math.min(
			0.75,
			Combat.critChance(rating(k, "Speed"), k.Effects.CritAdd) + (if heavy then k.Rules.HeavyCrit else 0)
		)
	if crit then
		damage *= Combat.CritMult
	end
	local gem = k.Loadout.WeaponGem
	local element = gem and gem.Element
	if target.Player then
		damage = receive(target.Player, damage, element, source, root.Position, projectile, heavy, false, nil, crit)
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
		return
	end
	procGem(source, k, target, damage)
	if heavy then
		target.Root:ApplyImpulse(
			flat(target.Root.Position - root.Position) * target.Root.AssemblyMass * k.Rules.Knockback
		)
	elseif k.Rules.Stagger > 0 and os.clock() >= st.NextStagger and math.random() < k.Rules.Stagger then
		st.NextStagger = os.clock() + 1
		if target.Player then
			local victim = state(target.Player)
			victim.StunUntil, victim.ChargeStarted, victim.BlockUntil = os.clock() + 0.2, nil, 0
		else
			Enemies.addStatus(target.Enemy, "Stun", 1, 0.2)
		end
	end
end
local function attack(player, aim, heavy)
	local k = kit(player)
	local humanoid, root = alive(player)
	if not k or not humanoid or not Actions.finiteVector(aim) or not Combat.canFight(root.Position) then
		return false
	end
	local st, now = state(player), os.clock()
	if now < st.NextAttack or now < st.StunUntil or blocking(st, now) or st.DodgeMove then
		return false
	end
	st.NextAttack = now + (if heavy then k.Rules.HeavyCooldown else k.Rules.BasicCooldown)
	st.ChargeStarted = nil
	Remotes.CombatFx:FireClient(player, "Cooldown", if heavy then "Heavy" else "Basic", st.NextAttack - now)
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
				strike(player, k, st, target, heavy, false)
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
			strike(player, k, st, nearest, heavy, true)
		end
		fx("Shot", player, origin, origin + ray * along, color, k.Weapon.Look)
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
	if now < st.NextDodge or now < st.StunUntil or st.DodgeMove then
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
	st.NextDodge, st.DodgeStarted = now + k.Rules.DodgeCooldown, now
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
	st.BlockDirection, st.BlockUntil, st.ChargeStarted = flat(aim - root.Position), now + Actions.BlockLease, nil
	player:SetAttribute("Blocking", true)
	if not wasBlocking then
		triggerBlockGem(player, k, st, now)
		fx("BlockRaise", player)
	end
	return true
end
local function onInput(player, action, a, b)
	local st, now = state(player), os.clock()
	if action == "Block" and a == false then
		block(player, false)
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
	if action == "BeginAttack" then
		if
			now >= st.NextAttack
			and now >= st.StunUntil
			and not blocking(st, now)
			and not st.DodgeMove
			and not st.ChargeStarted
		then
			st.ChargeStarted = now
		end
	elseif action == "ReleaseAttack" and Actions.finiteVector(a) then
		local started = st.ChargeStarted
		st.ChargeStarted = nil
		if started and now - started <= 3 then
			attack(player, a, now - started >= Actions.Base.Heavy.Charge)
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
			st.Dots = {}
			stopDodge(st)
			player:SetAttribute("Blocking", false)
			continue
		end
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
				receive(player, dot.Damage, "Fire", source, nil, false, false, false)
				dot.Next, dot.Remaining = now + 1, dot.Remaining - 1
				if dot.Remaining <= 0 then
					st.Dots[source] = nil
				end
			end
		end
		player:SetAttribute("Shield", math.floor(st.Shield))
		player:SetAttribute("CombatCharging", st.ChargeStarted ~= nil)
	end
end
function CombatServer.start()
	Enemies.hitPlayer = function(player, amount, element, enemy)
		CombatServer.hurt(player, amount, element, enemy)
	end
	Remotes.CombatInput.OnServerEvent:Connect(onInput)
	Shop.register("SetAbilities", function()
		return Shop.reply(false, "Every Warrior uses Attack, Heavy, Dodge and Block. Armor enhances these actions.")
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
CombatServer._attack, CombatServer._dodge, CombatServer._block = attack, dodge, block
CombatServer._input, CombatServer._state, CombatServer._tick, CombatServer._canPvP = onInput, state, tick, canPvP
return CombatServer
