--[[
	The Q / E / R triad in a fight (Shared.GemTraits holds the moves; this
	makes them happen). CombatServer calls in at a handful of points:

	  schedule   a cast: dashes start, the payload is queued for the cast's end
	  resolve    the payload lands: self effects, then the strike
	  hitScale / afterHit       a move's hit: bonuses before, riders after
	  swingScale / afterSwing   a sword swing: Empower, Static Brand, boosts
	  incoming / guarded / parried / absorbed / afterIncoming   your defenses
	  tick       walls, auras, heals, refills, pylons, trails, poisons

	Steals and drains are capped per victim over a rolling 10 seconds (20
	Charge, 30 Stamina, never below 15 Stamina) and are 60% in PvP. Stun,
	freeze and root keep CrowdControl's diminishing returns.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CrowdControl = require(ReplicatedStorage.Shared.CrowdControl)
local ArmorSignatures = require(ReplicatedStorage.Shared.ArmorSignatures)

local TriadServer = {}
local api: any = nil
-- CombatServer hands over what the moves need (its state, damage and fx).
function TriadServer.bind(functions)
	api = functions
end

local POISON_COLOR = GemConfig.ElementColors.Poison
local FIRE_COLOR = GemConfig.ElementColors.Fire
local CAPS = GemTraits.Caps

local function triad(st)
	local t = st.Triad
	if not t then
		t = { Zones = {}, Marks = {} }
		st.Triad = t
	end
	return t
end
TriadServer.triad = triad

local function color(definition)
	return GemConfig.ElementColors[definition.Element] or Color3.fromRGB(255, 190, 80)
end

local function weaponDamage(k)
	return k.Weapon.Attack.Damage * api.powerMult(k)
end

local function horizontal(v: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Is the gem's E move an Aura, and ready (its passive is on)?
local function readyAura(player, k, st, now)
	local gem = api.Tech.surgeGem(k.Loadout, "E")
	local move = gem and GemTraits.Moves[gem.Surge]
	if not move or move.Type ~= "Aura" then
		return nil
	end
	if now < (st.TechCooldowns.SurgeE or 0) then
		return nil
	end
	local cached = st.TriadAuraCache
	if cached and cached.Gem == gem.SourceId and cached.Tier == gem.Tier then
		return cached.Aura
	end
	local stats = GemTraits.stats(gem.Surge, gem, player:GetAttribute("MatchRarityCap") ~= nil)
	st.TriadAuraCache = { Gem = gem.SourceId, Tier = gem.Tier, Aura = stats.Aura }
	return stats.Aura
end
TriadServer.readyAura = readyAura

-- Steals and drains ----------------------------------------------------------

-- Takes up to `amount` of `resource` from a target (capped, PvP-scaled).
-- Returns how much it lost. Computer foes have nothing to lose.
local function drain(target, resource: string, amount: number, now: number): number
	if not target.Player or amount <= 0 then
		return 0
	end
	local victim = api.state(target.Player)
	amount *= CAPS.PvP
	local have = victim.Resources[resource] or 0
	if resource == "Stamina" then
		amount = math.min(amount, math.max(0, have - CAPS.StaminaFloor))
	else
		amount = math.min(amount, have)
	end
	amount = ArmorSignatures.budget(victim, "Drained" .. resource, amount, CAPS[resource], now)
	if amount > 0 then
		victim.Resources[resource] = have - amount
		target.Player:SetAttribute(resource, victim.Resources[resource])
	end
	return amount
end
TriadServer.drain = drain

-- Steals: the thief gains what the victim lost (from a computer foe, what
-- it would have lost had it been a player).
local function steal(player, st, target, resource: string, amount: number, now: number)
	local taken = if target.Player then drain(target, resource, amount, now) else amount * CAPS.PvP
	if taken <= 0 then
		return 0
	end
	local max = api.Tech.Resources[resource].Max
	st.Resources[resource] = math.min(max, st.Resources[resource] + taken)
	player:SetAttribute(resource, st.Resources[resource])
	api.fx("TriadSteal", target.Root.Position, player, resource, math.floor(taken + 0.5))
	return taken
end
TriadServer.steal = steal

-- Riders ---------------------------------------------------------------------

local function burn(player, k, target, rider, scale: number?)
	if not rider then
		return
	end
	local power = weaponDamage(k) * rider.Power * (scale or 1)
	if target.Player then
		api.addDot(target.Player, player, power, rider.Time)
	else
		api.Enemies.setBurn(target.Enemy, power, rider.Time, player, FIRE_COLOR)
	end
end

-- Poison: damage over time (its own track, so it never replaces a burn).
local function poison(player, k, st, target, rider, now)
	if not rider then
		return
	end
	local seconds = rider.Time
	local aura = readyAura(player, k, st, now)
	if aura and aura.PoisonLonger then
		seconds *= 1 + aura.PoisonLonger
	end
	local power = weaponDamage(k) * rider.Power
	if target.Player then
		local victim = triad(api.state(target.Player))
		victim.Poisons = victim.Poisons or {}
		victim.Poisons[player] = { Power = power, Last = now, Next = now + 1, Ends = now + seconds }
	else
		api.Enemies.addDot(target.Enemy, power * seconds, seconds, player, POISON_COLOR, "Poisoned")
	end
end

-- Chill: three stacks freeze for 1s. A slow comes with each stack.
local function chill(player, k, st, target, stacks: number, now)
	if not stacks or stacks <= 0 then
		return
	end
	local holder = if target.Player then triad(api.state(target.Player)) else target.Enemy :: any
	local current = if now < (holder.ChillUntil or 0) then holder.Chill or 0 else 0
	current += stacks
	holder.ChillUntil = now + 4
	local slowTime = 2
	local aura = readyAura(player, k, st, now)
	if aura and aura.SlowLonger then
		slowTime *= 1 + aura.SlowLonger
	end
	api.slow(target, 0.15, slowTime)
	if current >= 3 then
		current = 0
		api.applyCC(target, 1, "Frozen")
		api.fx("TriadShatter", target.Root.Position, GemConfig.ElementColors.Frost)
	end
	holder.Chill = current
end

local function vulnerable(target, rider, now)
	if not rider then
		return
	end
	if target.Player then
		CrowdControl.applyDebuff(api.state(target.Player).CC, "Vulnerable", rider.Amount, rider.Time, now, true)
	else
		api.Enemies.addStatus(target.Enemy, "Vulnerable", rider.Amount, rider.Time)
	end
end

-- Bursts every poison on the target now, at `mult` of what was left.
local function burstPoison(player, target, mult: number, now)
	local total = 0
	if target.Player then
		local victim = triad(api.state(target.Player))
		for source, dot in victim.Poisons or {} do
			total += dot.Power * math.max(0, dot.Ends - now)
			victim.Poisons[source] = nil
		end
	else
		local dots = target.Enemy.Dots
		for i = #dots, 1, -1 do
			if dots[i].Status == "Poisoned" then
				total += dots[i].PerTick * dots[i].Ticks
				table.remove(dots, i)
			end
		end
	end
	if total > 0 then
		api.damage(player, target, total * mult, "Poison", true)
		api.fx("TriadShatter", target.Root.Position, POISON_COLOR)
	end
end

-- A target's mark from `player` (Static Brand), if it's live.
local function markOn(player, target, now)
	local marks = if target.Player then triad(api.state(target.Player)).Marks else (target.Enemy :: any).TriadMarks
	local mark = marks and marks[player]
	if mark and now < mark.Until then
		return mark
	end
	return nil
end

-- A cast -----------------------------------------------------------------------

-- Starts a triad cast. Returns false if it can't go off (a dash with nowhere
-- to go), so nothing is spent.
function TriadServer.schedule(player, k, st, definition, aim, now, castTime)
	local _, root = api.alive(player)
	local t = triad(st)
	local at = now + castTime
	if definition.Dash then
		local dash = definition.Dash
		local forward = horizontal(root.CFrame.LookVector)
		local direction = horizontal(aim - root.Position)
		if dash.Dir == "Forward" then
			direction = forward
		elseif dash.Dir == "Back" then
			direction = forward * -1
		elseif dash.Dir == "Side" then
			local side = Vector3.new(-forward.Z, 0, forward.X)
			direction = side * (if side:Dot(direction) < 0 then -1 else 1)
		end
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { player.Character }
		params.RespectCanCollide = true
		local hit = workspace:Blockcast(root.CFrame, Vector3.new(2, 3, 2), direction * dash.Distance, params)
		local distance = if hit then math.max(0, hit.Distance - 0.5) else dash.Distance
		if distance < 1 then
			return false
		end
		st.DodgeMove = {
			Kind = "Shift",
			Root = root,
			Direction = direction,
			Speed = distance / dash.MoveTime,
			Ends = now + dash.MoveTime,
		}
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		api.fx("DodgeRoll", player, root.Position, direction, distance, definition.Untargetable ~= nil)
		at = now + dash.MoveTime + 0.02
		t.DashFrom, t.DashTo = root.Position, root.Position + direction * distance
		if definition.Untargetable then
			t.UntargetableUntil = now + definition.Untargetable + dash.MoveTime
		end
		if definition.IceField then
			TriadServer.zone(player, st, {
				Kind = "Ice",
				Center = root.Position,
				Radius = definition.IceField.Radius,
				Slow = definition.IceField.Slow,
				Chill = definition.IceField.Chill,
				Until = now + definition.IceField.Time,
				Every = 0.5,
				Definition = definition,
			})
		end
	end
	if definition.ConsumeCharge then
		-- Overcharge Strike: everything you have left goes into the blow.
		local spent = st.Resources.Charge
		st.Resources.Charge = 0
		player:SetAttribute("Charge", 0)
		definition = table.clone(definition)
		definition.Damage *= 1 + spent * definition.ConsumeCharge
		definition.ChargeSpent = spent
	end
	local hits = definition.Hits or 1
	for i = 1, hits do
		table.insert(st.Pending, {
			Triad = true,
			Definition = definition,
			Aim = aim,
			At = at + (i - 1) * (definition.Interval or 0.12),
			Last = i == hits,
			First = i == 1,
		})
	end
	api.fx("TriadCast", player, definition.Id, definition.Element, definition.Key, castTime)
	return true
end

-- A cast's payload lands.
function TriadServer.resolve(player, k, st, pending)
	local definition, now = pending.Definition, os.clock()
	if pending.First then
		TriadServer.applySelf(player, k, st, definition, pending.Aim, now)
	end
	local strike = definition
	if pending.Last and definition.LastBurn then
		strike = table.clone(definition)
		strike.Burn = definition.LastBurn
	end
	if not definition.Damage then
		-- (nothing to strike with)
	elseif definition.PathHit then
		-- Heat Haze: everyone you dashed through.
		local t = triad(st)
		local from, to = t.DashFrom, t.DashTo
		if from and to then
			local line = to - from
			for _, target in api.targets(player) do
				local v = target.Root.Position - from
				local along = math.clamp(v:Dot(line.Unit), 0, line.Magnitude)
				if (v - line.Unit * along).Magnitude <= 3.5 then
					api.hit(player, k, target, strike, 1)
				end
			end
		end
	else
		api.strike(player, strike, pending.Aim, nil)
	end
	if definition.Trail and pending.Last then
		local _, root = api.alive(player)
		local t = triad(st)
		local from = t.DashFrom or root.Position
		local to = t.DashTo
		if not to then
			local direction = horizontal(pending.Aim - root.Position)
			to = root.Position + direction * (definition.Range or 10)
			from = root.Position + direction * 2
		end
		TriadServer.zone(player, st, {
			Kind = "Trail",
			From = from,
			To = to,
			Width = definition.Trail.Width,
			Until = now + definition.Trail.Time,
			Every = 0.5,
			Burn = definition.Trail.Burn,
			Poison = definition.Trail.Poison,
			Stun = definition.Trail.Stun,
			Definition = definition,
		})
	end
	if definition.Pylon and pending.Last then
		local _, root = api.alive(player)
		local direction = horizontal(pending.Aim - root.Position)
		local reach = math.min((pending.Aim - root.Position).Magnitude, definition.Range or 25)
		TriadServer.zone(player, st, {
			Kind = "Pylon",
			Center = root.Position + direction * reach,
			Reach = definition.Pylon.Reach,
			Damage = definition.Pylon.Damage,
			Stun = definition.Pylon.Stun,
			Until = now + definition.Pylon.Time,
			Every = definition.Pylon.Every,
			Definition = definition,
		})
	end
end

-- What a move does to you (or around you) as its cast lands.
function TriadServer.applySelf(player, k, st, definition, aim, now)
	local t = triad(st)
	local _, root = api.alive(player)
	local humanoid = api.alive(player)
	local tint = color(definition)
	local function aura(kind, seconds)
		api.fx("TriadAura", player, definition.Id, definition.Element, kind, seconds)
	end
	if definition.Empower then
		local e = definition.Empower
		t.Empower = { Kind = e.Kind, Left = e.Swings, Until = now + (e.Duration or 8), Rider = e, Name = definition.Name }
		aura("Empower", e.Duration or 8)
	end
	if definition.DamageBoost then
		t.Boost = { Amount = definition.DamageBoost.Amount, Until = now + definition.DamageBoost.Time }
		aura("Boost", definition.DamageBoost.Time)
	end
	if definition.NextCrit then
		t.NextCritUntil = now + definition.NextCrit
	end
	if definition.Cleanse then
		TriadServer.cleanse(st, definition.Cleanse, now)
	end
	if definition.Absorb and not definition.Damage then
		st.Shield = math.max(st.Shield, definition.Absorb)
		st.ShieldUntil = math.max(st.ShieldUntil, now + (definition.Duration or 4))
		if definition.Refill then
			t.IonShield = { Max = definition.Absorb, Refill = definition.Refill, Until = now + definition.Duration, LastHit = now }
		end
		if definition.BreakSlow then
			t.Bulwark = { Rider = definition.BreakSlow, Until = now + definition.Duration }
		end
		if definition.Siphon then
			-- Capacitor: what it soaks becomes Charge (the Energy Siphon field).
			st.SiphonUntil, st.SiphonCapacity = now + definition.Duration, definition.Absorb
			st.SiphonRate = definition.Siphon
			st.Shield = 0
		end
		aura("Shield", definition.Duration or 4)
	end
	if definition.Ward and not definition.Damage then
		local ward = definition.Ward
		st.SurgeWardUntil, st.SurgeWardKind = now + ward.Duration, ward.Kind
		st.SurgeWardPower = weaponDamage(k) * (ward.Power or 0)
		st.SurgeWardStun = ward.Stun
	end
	if definition.EndBurst then
		-- Heat Shield bursts as it ends; Phoenix Mantle only on a rebirth.
		if definition.Phoenix then
			t.EndBurst = { Definition = definition, At = math.huge, OnRebirth = true, Expires = now + definition.Phoenix.Time }
		else
			t.EndBurst = { Definition = definition, At = now + (definition.Duration or 4) }
		end
	end
	if definition.Guard then
		-- Ember Guard: the guard goes up and stays up.
		t.Guard = { Share = definition.Guard.Share, Until = now + definition.Guard.Time }
		st.BlockDirection = horizontal(aim - root.Position)
		st.BlockUntil = now + definition.Guard.Time
		st.BlockRaisedAt = now
		st.ParrySpent = false
		player:SetAttribute("Blocking", true)
		aura("Guard", definition.Guard.Time)
	end
	if definition.Wall then
		local wall = definition.Wall
		local facing = horizontal(aim - root.Position)
		local center = root.Position + facing * wall.Distance
		t.Wall = {
			Kind = wall.Kind,
			Center = center,
			Normal = facing,
			Width = wall.Width,
			Until = now + wall.Time,
			Front = wall.Front,
			NoSwing = wall.NoSwing,
			Burn = wall.Burn,
			Slow = wall.Slow,
			Burned = {},
		}
		if wall.NoSwing then
			st.NextAttack = math.max(st.NextAttack, now + wall.Time)
		end
		api.fx(
			"TriadWall",
			player,
			wall.Kind,
			CFrame.lookAt(center, center + facing),
			wall.Width,
			wall.Time,
			definition.Element
		)
	end
	if definition.Heal then
		local h = definition.Heal
		local max = humanoid and humanoid.MaxHealth or 100
		t.Regen = {
			PerSecond = max * h.Share / h.Time,
			Until = now + h.Time,
			Last = now,
			BreakOnHeavy = h.BreakOnHeavy,
		}
		aura("Heal", h.Time)
	end
	if definition.Phoenix then
		t.Phoenix = { Below = definition.Phoenix.Below, Heal = definition.Phoenix.Heal, Until = now + definition.Phoenix.Time }
		aura("Phoenix", definition.Phoenix.Time)
	end
	if definition.DamageCut then
		t.Cut = { Amount = definition.DamageCut.Amount, Until = now + definition.DamageCut.Time, SelfSlow = definition.DamageCut.SelfSlow }
		aura("Armor", definition.DamageCut.Time)
	end
	if definition.ResistAll then
		t.Resist = { Amount = math.min(0.3, definition.ResistAll.Amount), Until = now + definition.ResistAll.Time }
		aura("Resist", definition.ResistAll.Time)
	end
	if definition.FrostRiposte then
		local r = definition.FrostRiposte
		t.Riposte = { Until = now + r.Time, Freeze = r.Freeze, Window = r.Window or 1 }
		aura("Riposte", r.Time)
	end
	if definition.Catch then
		local c = definition.Catch
		t.Catch = { Until = now + c.Time, Window = c.Window, Stun = c.Stun, Steal = c.Steal }
		aura("Catch", c.Time)
	end
	if definition.Deflect then
		t.Deflect = { Until = now + definition.Deflect.Time, Share = definition.Deflect.Share }
		aura("Deflect", definition.Deflect.Time)
	end
	if definition.Grounding then
		t.GroundedUntil = now + definition.Grounding.Time
		aura("Grounded", definition.Grounding.Time)
	end
	if definition.Immune then
		t.ImmuneUntil = now + definition.Immune
		aura("Immune", definition.Immune)
	end
	if definition.CorrosionAura then
		local c = definition.CorrosionAura
		t.Corrosion = { Radius = c.Radius, Stamina = c.Stamina, Shred = c.Shred, Until = now + c.Time, Next = now }
		aura("Corrosion", c.Time)
	end
	if definition.Mantle then
		t.Mantle = { Share = definition.Mantle.Share, Until = now + definition.Mantle.Time }
		aura("Mantle", definition.Mantle.Time)
	end
	if not definition.Damage and not definition.Wall then
		api.fx("TechField", player, tint)
	end
end

-- Cleanse: "Dots" (burns and poisons), "Control" (stun, slow, freeze),
-- "One" (the worst one), "All".
function TriadServer.cleanse(st, kind: string, now: number)
	local t = triad(st)
	local function dots()
		st.Dots = {}
		t.Poisons = {}
	end
	local function control()
		st.StunUntil, st.SlowUntil, st.Slow = 0, 0, 0
		st.CC.Debuffs.Slow = nil
	end
	if kind == "All" then
		api.cleanse(st)
		t.Poisons = {}
		st.BlindUntil = 0
	elseif kind == "Dots" then
		dots()
	elseif kind == "Control" then
		control()
	elseif kind == "One" then
		if now < st.StunUntil or now < st.SlowUntil then
			control()
		elseif next(st.Dots) or next(t.Poisons or {}) then
			dots()
		elseif now < st.SunderUntil then
			st.Sunder, st.SunderUntil, st.CC.Debuffs.Sunder = 0, 0, nil
		else
			st.CC.Debuffs.Vulnerable = nil
		end
	end
end

-- Lingering zones: Trail (a strip), Ice (a slowing patch), Pylon.
function TriadServer.zone(player, st, zone)
	zone.Next = os.clock()
	table.insert(triad(st).Zones, zone)
	local definition = zone.Definition
	if zone.Kind == "Trail" then
		api.fx("TriadTrail", zone.From, zone.To, zone.Width, zone.Until - os.clock(), definition.Element)
	elseif zone.Kind == "Ice" then
		api.fx("TriadField", zone.Center, zone.Radius, zone.Until - os.clock(), definition.Element)
	elseif zone.Kind == "Pylon" then
		api.fx("TriadPylon", zone.Center, zone.Reach, zone.Until - os.clock(), definition.Element)
	end
end

-- Hits -------------------------------------------------------------------------

-- How much harder a triad move hits this target (before it lands).
function TriadServer.hitScale(player, k, st, target, definition, now): number
	local scale = 1
	if definition.LowHealth and target.Humanoid.Health < target.Humanoid.MaxHealth * definition.LowHealth.Below then
		scale *= 1 + definition.LowHealth.Bonus
	end
	if definition.VsChilled then
		local flags = api.comboFlags(target, now)
		if flags.Slowed or flags.Frozen then
			scale *= 1 + definition.VsChilled
		end
	end
	return scale * TriadServer.boost(player, k, st, now)
end

-- Your damage boosts (Thermal Burst, active or as an aura).
function TriadServer.boost(player, k, st, now): number
	local t = st.Triad
	local scale = 1
	if t and t.Boost and now < t.Boost.Until then
		scale *= 1 + t.Boost.Amount
	end
	local aura = readyAura(player, k, st, now)
	if aura and aura.Damage then
		scale *= 1 + aura.Damage
	end
	return scale
end

-- The next hit is a critical (Vector Dash). Spends it.
function TriadServer.takeCrit(st, now): boolean
	local t = st.Triad
	if t and t.NextCritUntil and now < t.NextCritUntil then
		t.NextCritUntil = nil
		return true
	end
	return false
end

-- A triad move landed on `target` for `dealt` damage.
function TriadServer.afterHit(player, k, st, target, definition, dealt: number, now)
	if not definition.Triad then
		return
	end
	local alive = target.Humanoid.Health > 0
	if alive then
		burn(player, k, target, definition.Burn)
		poison(player, k, st, target, definition.Poison, now)
		vulnerable(target, definition.Vulnerable, now)
		if definition.Chill then
			chill(player, k, st, target, definition.Chill, now)
		end
		if definition.Root then
			-- Rooted: held in place, still free to swing.
			if target.Player then
				local victim = api.state(target.Player)
				if not TriadServer.controlImmune(victim, now) then
					triad(victim).RootUntil = now + definition.Root
				end
			else
				api.Enemies.addStatus(target.Enemy, "Slow", 0.95, definition.Root)
			end
			api.fx("TriadRoot", target.Root.Position, definition.Root, definition.Element)
		end
		if definition.Mark then
			local marks
			if target.Player then
				marks = triad(api.state(target.Player)).Marks
			else
				local e = target.Enemy :: any
				e.TriadMarks = e.TriadMarks or {}
				marks = e.TriadMarks
				e.TriadBrandUntil = now + definition.Mark.Time
			end
			marks[player] = { Until = now + definition.Mark.Time, Arc = definition.Mark.Arc, Steal = definition.Mark.Steal }
			api.fx("TriadMark", target.Root, definition.Mark.Time, definition.Element)
		end
		if definition.RefreshSlows then
			local flags = api.comboFlags(target, now)
			if flags.Slowed or flags.Frozen then
				local slowTime = definition.RefreshSlows.Time
				local aura = readyAura(player, k, st, now)
				if aura and aura.SlowLonger then
					slowTime *= 1 + aura.SlowLonger
				end
				api.slow(target, definition.RefreshSlows.Slow, slowTime)
			end
		end
		if definition.StunIfChilled then
			local flags = api.comboFlags(target, now)
			if flags.Slowed or flags.Frozen then
				api.applyCC(target, definition.Stun or 0.6, definition.StunKind or "Frozen")
			end
		end
	end
	if definition.BurstPoison then
		burstPoison(player, target, definition.BurstPoison, now)
	end
	if definition.DrainCharge then
		local lost = drain(target, "Charge", definition.DrainCharge, now)
		if lost > 0 then
			api.fx("TriadSteal", target.Root.Position, nil, "Charge", math.floor(lost + 0.5))
		end
	end
	if definition.StealCharge then
		steal(player, st, target, "Charge", definition.StealCharge, now)
	end
	if definition.StealStamina then
		steal(player, st, target, "Stamina", definition.StealStamina, now)
	end
	if definition.HealPerEnemy and dealt > 0 then
		local humanoid = api.alive(player)
		if humanoid then
			api.heal(player, humanoid.MaxHealth * definition.HealPerEnemy)
		end
	end
	if definition.KillRefund and target.Humanoid.Health <= 0 then
		st.Resources.Charge = math.min(100, st.Resources.Charge + definition.KillRefund)
		player:SetAttribute("Charge", st.Resources.Charge)
	end
	if definition.ArcExtra and not st.TriadArcing then
		-- Circuit Cleave: the hit jumps on to more enemies (once per cast).
		st.TriadArcing = true
		local struck, from = { [target.Root] = true }, target
		local extra = definition.ArcExtra
		for _ = 1, extra.Count do
			local best, bestDistance = nil, extra.Range
			for _, other in api.targets(player) do
				local d = (other.Root.Position - from.Root.Position).Magnitude
				if not struck[other.Root] and d <= bestDistance and api.targetAllowed(player, other) then
					best, bestDistance = other, d
				end
			end
			if not best then
				break
			end
			struck[best.Root] = true
			api.fx("Arc", from.Root.Position, best.Root.Position, color(definition))
			local jump = table.clone(definition)
			jump.ArcExtra = nil
			api.hit(player, k, best, jump, extra.Share)
			from = best
		end
		st.TriadArcing = false
	end
end

-- Sword swings -----------------------------------------------------------------

-- How much harder a swing lands (Thermal Burst, an Empower's bonus).
function TriadServer.swingScale(player, k, st, now): number
	local scale = TriadServer.boost(player, k, st, now)
	local t = st.Triad
	local e = t and t.Empower
	if e and e.Left > 0 and now < e.Until and e.Rider.Bonus then
		scale *= 1 + e.Rider.Bonus
	end
	return scale
end

-- A swing landed (not on a guard): Empower riders and Static Brand.
function TriadServer.afterSwing(player, k, st, target, now)
	local t = st.Triad
	if not t then
		return
	end
	local e = t.Empower
	if e and e.Left > 0 and now < e.Until then
		e.Left -= 1
		local rider = e.Rider
		if e.Kind == "Burn" then
			burn(player, k, target, rider)
		elseif e.Kind == "Chill" then
			chill(player, k, st, target, 1, now)
		elseif e.Kind == "Sap" then
			steal(player, st, target, "Stamina", rider.Steal, now)
			poison(player, k, st, target, rider.Poison, now)
		end
		api.fx("TriadEmpowerHit", target.Root.Position, e.Kind, if e.Left <= 0 then 1 else 0)
		if e.Left <= 0 then
			t.Empower = nil
			api.fx("TriadAura", player, nil, nil, "EmpowerEnd", 0)
		end
	end
	local mark = markOn(player, target, now)
	if mark then
		api.fx("Arc", target.Root.Position + Vector3.new(0, 4, 0), target.Root.Position, GemConfig.ElementColors.Shock)
		api.damage(player, target, weaponDamage(k) * mark.Arc, "Shock", false)
		steal(player, st, target, "Charge", mark.Steal, now)
	end
end

-- Attack speed while Heat Haze is ready.
function TriadServer.attackSpeed(player, k, st, now): number
	local aura = readyAura(player, k, st, now)
	return 1 + (if aura and aura.AttackSpeed then aura.AttackSpeed else 0)
end

-- More Charge from hits while Overload is ready.
function TriadServer.chargeGain(player, k, st, now): number
	local aura = readyAura(player, k, st, now)
	return 1 + (if aura and aura.ChargeGain then aura.ChargeGain else 0)
end

-- Your slows last longer while Winter's Hold is ready.
function TriadServer.slowLonger(player, k, st, now): number
	local aura = readyAura(player, k, st, now)
	return 1 + (if aura and aura.SlowLonger then aura.SlowLonger else 0)
end

-- Defenses -----------------------------------------------------------------------

local function attackerOf(source, enemySource)
	if source then
		local root = source.Character and source.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = source.Character and source.Character:FindFirstChildOfClass("Humanoid")
		return if root and humanoid then { Player = source, Root = root, Humanoid = humanoid } else nil
	elseif enemySource then
		return { Enemy = enemySource, Root = enemySource.Root, Humanoid = enemySource.Humanoid }
	end
	return nil
end
TriadServer.attackerOf = attackerOf

-- A blow is coming at `player`. Returns a damage multiplier (0 = stopped)
-- and whether it was stopped by a wall or deflected.
function TriadServer.incoming(player, st, root, amount, element, source, enemySource, origin, projectile, reflected, now)
	local t = st.Triad
	if not t then
		return 1, false
	end
	if t.UntargetableUntil and now < t.UntargetableUntil then
		return 0, true
	end
	local ranged = projectile or (origin ~= nil and (origin - root.Position).Magnitude > 9)
	local wall = t.Wall
	if wall and now < wall.Until and origin and not reflected then
		local ahead = (origin - root.Position) * Vector3.new(1, 0, 1)
		local front = ahead.Magnitude > 0.1 and ahead.Unit:Dot(wall.Normal) > 0.25
		if wall.Front and front then
			-- Frozen Wall: every frontal hit stops on the ice.
			api.fx("TriadWallHit", wall.Center + Vector3.new(0, 3, 0), "Ice")
			local attacker = attackerOf(source, enemySource)
			if wall.Slow and attacker then
				api.slow(attacker, wall.Slow, 1.5)
			end
			return 0, true
		elseif wall.Kind == "Fire" and ranged and front then
			api.fx("TriadWallHit", wall.Center + Vector3.new(0, 3, 0), "Fire")
			return 0, true
		end
	end
	if t.Deflect and now < t.Deflect.Until and ranged and not reflected then
		local attacker = attackerOf(source, enemySource)
		if attacker then
			api.fx("TriadDeflect", root.Position, attacker.Root.Position)
			api.damage(player, attacker, amount * t.Deflect.Share, element, false, true)
		end
		return 0, true
	end
	local scale = 1
	if element and t.Resist and now < t.Resist.Until then
		scale *= 1 - t.Resist.Amount
	end
	if t.Cut and now < t.Cut.Until then
		scale *= 1 - t.Cut.Amount
	end
	return scale, false
end

-- A blow landed on your raised guard (Ember Guard reflects part of it).
function TriadServer.guarded(player, st, amount, source, enemySource, reflected, now)
	local t = st.Triad
	if not t or reflected or not t.Guard or now >= t.Guard.Until then
		return
	end
	local attacker = attackerOf(source, enemySource)
	if attacker then
		api.fx("TriadDeflect", st.LastRootPosition or attacker.Root.Position, attacker.Root.Position)
		api.damage(player, attacker, amount * t.Guard.Share, "Fire", false, true)
	end
end

-- How wide your timed-block window is (Static Catch, Frost Riposte).
function TriadServer.parryWindow(st, now): number
	local t = st.Triad
	local window = 1
	if t and t.Catch and now < t.Catch.Until then
		window = math.max(window, t.Catch.Window)
	end
	if t and t.Riposte and now < t.Riposte.Until then
		window = math.max(window, t.Riposte.Window)
	end
	return window
end

-- You timed a block: Frost Riposte freezes, Static Catch stuns and steals.
function TriadServer.parried(player, st, source, enemySource, now)
	local t = st.Triad
	if not t then
		return
	end
	local attacker = attackerOf(source, enemySource)
	if not attacker then
		return
	end
	if t.Riposte and now < t.Riposte.Until then
		api.applyCC(attacker, t.Riposte.Freeze, "Frozen")
		api.fx("TriadShatter", attacker.Root.Position, GemConfig.ElementColors.Frost)
	end
	if t.Catch and now < t.Catch.Until then
		api.applyCC(attacker, t.Catch.Stun, "Shocked")
		steal(player, st, attacker, "Charge", t.Catch.Steal, now)
		t.Catch.Until = now -- one catch per cast
	end
end

-- After your shields soaked a blow: Glacial Bulwark bursts when it breaks;
-- Ion Shield notes when it was last hit.
function TriadServer.absorbed(player, st, root, now)
	local t = st.Triad
	if not t then
		return
	end
	if t.IonShield then
		t.IonShield.LastHit = now
	end
	local bulwark = t.Bulwark
	if bulwark and st.Shield <= 0 then
		t.Bulwark = nil
		local rider = bulwark.Rider
		api.fx("TriadBreak", root.Position, rider.Radius, "Frost")
		for _, target in api.targets(player) do
			if (target.Root.Position - root.Position).Magnitude <= rider.Radius and api.targetAllowed(player, target) then
				api.slow(target, rider.Slow, rider.Time)
				if rider.Freeze then
					api.applyCC(target, rider.Freeze, "Frozen")
				end
			end
		end
	end
end

-- The damage about to land, after everything: Phoenix Mantle turns a fall
-- under its line into a rebirth. Returns the damage to take.
function TriadServer.lastStand(player, st, humanoid, damage, now): number
	local t = st.Triad
	local phoenix = t and t.Phoenix
	if not phoenix or now >= phoenix.Until or st.PhoenixSpent then
		return damage
	end
	local line = humanoid.MaxHealth * phoenix.Below
	if humanoid.Health - damage >= line then
		return damage
	end
	st.PhoenixSpent = true
	t.Phoenix = nil
	local kept = math.max(0, humanoid.Health - line)
	t.RebirthHeal = humanoid.MaxHealth * phoenix.Heal -- (healed next frame, after the blow lands)
	local _, root = api.alive(player)
	if root then
		api.fx("TriadPhoenix", player, root.Position)
	end
	if t.EndBurst and t.EndBurst.OnRebirth then
		t.EndBurst.At = now
	end
	api.status(player, "Reborn!")
	return kept
end

-- After a blow landed on you: Toxic Mantle poisons melee attackers; a heavy
-- blow stops Bio Regrowth.
function TriadServer.afterIncoming(player, k, st, damage, source, enemySource, projectile, heavy, reflected, now)
	local t = st.Triad
	if not t then
		return
	end
	if heavy and t.Regen and t.Regen.BreakOnHeavy then
		t.Regen = nil
		api.status(player, "Regrowth broken")
	end
	if t.Mantle and now < t.Mantle.Until and damage > 0 and not projectile and not reflected then
		local attacker = attackerOf(source, enemySource)
		if attacker then
			local total = damage * t.Mantle.Share
			if attacker.Player then
				local victim = triad(api.state(attacker.Player))
				victim.Poisons = victim.Poisons or {}
				victim.Poisons[player] = { Power = total / 3, Last = now, Next = now + 1, Ends = now + 3 }
			else
				api.Enemies.addDot(attacker.Enemy, total, 3, player, POISON_COLOR, "Poisoned")
			end
			api.fx("TriadEmpowerHit", attacker.Root.Position, "Sap", 0)
		end
	end
end

-- Is the player immune to control (Grounding) or new debuffs (Purge Shell)?
function TriadServer.controlImmune(st, now): boolean
	local t = st.Triad
	return t ~= nil and ((t.GroundedUntil or 0) > now or (t.ImmuneUntil or 0) > now)
end

-- How fast you move (Ice Armor slows you a little).
function TriadServer.speed(st, now): number
	local t = st.Triad
	if t and (t.RootUntil or 0) > now then
		return 0
	end
	if t and t.Cut and now < t.Cut.Until and t.Cut.SelfSlow then
		return 1 - t.Cut.SelfSlow
	end
	return 1
end

-- Every frame ---------------------------------------------------------------------

local function inSegment(position: Vector3, from: Vector3, to: Vector3, width: number): boolean
	local line = (to - from) * Vector3.new(1, 0, 1)
	local v = (position - from) * Vector3.new(1, 0, 1)
	if line.Magnitude < 0.1 then
		return v.Magnitude <= width
	end
	local along = math.clamp(v:Dot(line.Unit), 0, line.Magnitude)
	return (v - line.Unit * along).Magnitude <= width / 2 + 1 and math.abs(position.Y - from.Y) < 8
end

function TriadServer.tick(player, k, st, now, humanoid, root)
	local t = st.Triad
	if not t then
		return
	end
	st.LastRootPosition = root.Position
	if t.RebirthHeal then
		api.heal(player, t.RebirthHeal)
		t.RebirthHeal = nil
	end
	-- Poisons on you.
	for source, dot in t.Poisons or {} do
		local fromEnemy = type(source) == "table" and source.Alive ~= nil
		if fromEnemy and not source.Alive then
			t.Poisons[source] = nil
		elseif now >= dot.Next then
			local through = math.min(now, dot.Ends)
			api.dotDamage(player, source, dot.Power * (through - dot.Last), "Poison", "Poisoned", fromEnemy)
			dot.Last, dot.Next = through, math.min(through + 1, dot.Ends)
			if through >= dot.Ends then
				t.Poisons[source] = nil
			end
		end
	end
	if t.Regen then
		if now >= t.Regen.Until + 0.05 then
			t.Regen = nil
		else
			local through = math.min(now, t.Regen.Until)
			if through - t.Regen.Last >= 0.5 then
				api.heal(player, t.Regen.PerSecond * (through - t.Regen.Last))
				t.Regen.Last = through
			end
		end
	end
	local ion = t.IonShield
	if ion then
		if now >= ion.Until then
			t.IonShield = nil
		elseif now - ion.LastHit >= ion.Refill and st.Shield < ion.Max then
			st.Shield = ion.Max
			st.ShieldUntil = math.max(st.ShieldUntil, ion.Until)
			ion.LastHit = now
			api.fx("TriadAura", player, "R_IonShield", "Shock", "Refill", 0.4)
		end
	end
	if t.Bulwark and now >= t.Bulwark.Until then
		t.Bulwark = nil
	end
	if TriadServer.controlImmune(st, now) then
		if (t.GroundedUntil or 0) > now then
			st.StunUntil, st.SlowUntil, st.Slow = math.min(st.StunUntil, now), 0, 0
			t.RootUntil = nil
		end
		if (t.ImmuneUntil or 0) > now then
			st.Dots, t.Poisons = {}, {}
			st.SunderUntil, st.SlowUntil, st.Slow, st.BlindUntil = 0, 0, 0, 0
			st.CC.Debuffs.Vulnerable, st.CC.Debuffs.Aura = nil, nil
		end
	end
	if t.Corrosion then
		local c = t.Corrosion
		if now >= c.Until then
			t.Corrosion = nil
		elseif now >= c.Next then
			c.Next = now + 0.5
			for _, target in api.targets(player) do
				if (target.Root.Position - root.Position).Magnitude <= c.Radius and api.targetAllowed(player, target) then
					drain(target, "Stamina", c.Stamina * 0.5, now)
					if target.Player then
						local victim = api.state(target.Player)
						victim.Sunder = CrowdControl.applyDebuff(victim.CC, "Sunder", c.Shred, 0.75, now, true)
						victim.SunderUntil = victim.CC.Debuffs.Sunder.Until
					else
						api.Enemies.addStatus(target.Enemy, "Sunder", c.Shred, 0.75)
					end
				end
			end
		end
	end
	local wall = t.Wall
	if wall then
		if now >= wall.Until then
			t.Wall = nil
		elseif wall.Burn then
			-- Fire Wall: whoever crosses it burns (once a second each).
			local side = Vector3.new(-wall.Normal.Z, 0, wall.Normal.X)
			local from, to = wall.Center - side * wall.Width / 2, wall.Center + side * wall.Width / 2
			for _, target in api.targets(player) do
				if inSegment(target.Root.Position, from, to, 3) and api.targetAllowed(player, target) then
					if now >= (wall.Burned[target.Root] or 0) then
						wall.Burned[target.Root] = now + 1
						burn(player, k, target, wall.Burn)
					end
				end
			end
		end
	end
	if t.EndBurst and t.EndBurst.Expires and t.EndBurst.At == math.huge and now >= t.EndBurst.Expires then
		t.EndBurst = nil
	end
	if t.EndBurst and now >= t.EndBurst.At then
		local burst = t.EndBurst
		t.EndBurst = nil
		local definition = burst.Definition
		api.fx("TriadBreak", root.Position, definition.EndBurst.Radius, definition.Element)
		local blast = {
			Name = definition.Name,
			Resource = "Charge",
			Triad = true,
			Element = definition.Element,
			Damage = definition.EndBurst.Damage,
			Gem = definition.Gem,
			RarityScaled = true,
			Crit = 0,
		}
		for _, target in api.targets(player) do
			if (target.Root.Position - root.Position).Magnitude <= definition.EndBurst.Radius then
				api.hit(player, k, target, blast, 1)
			end
		end
	end
	for i = #t.Zones, 1, -1 do
		local zone = t.Zones[i]
		if now >= zone.Until then
			table.remove(t.Zones, i)
		elseif now >= zone.Next then
			zone.Next = now + zone.Every
			if zone.Kind == "Pylon" then
				local best, bestDistance = nil, zone.Reach
				for _, target in api.targets(player) do
					local d = (target.Root.Position - zone.Center).Magnitude
					if d <= bestDistance and api.targetAllowed(player, target) then
						best, bestDistance = target, d
					end
				end
				if best then
					api.fx("Arc", zone.Center + Vector3.new(0, 5, 0), best.Root.Position, GemConfig.ElementColors.Shock)
					local zap = table.clone(zone.Definition)
					zap.Damage, zap.Pylon, zap.Radius = zone.Damage, nil, nil
					zap.Stun, zap.StunChance = if zone.Stun then 0.5 else nil, zone.Stun
					api.hit(player, k, best, zap, 1)
				end
			else
				for _, target in api.targets(player) do
					local position = target.Root.Position
					local inside = if zone.Kind == "Trail"
						then inSegment(position, zone.From, zone.To, zone.Width)
						else (position - zone.Center).Magnitude <= zone.Radius
					if inside and api.targetAllowed(player, target) then
						if zone.Kind == "Ice" then
							api.slow(target, zone.Slow, 0.75)
							if zone.Chill then
								chill(player, k, st, target, 0.5, now)
							end
						else
							burn(player, k, target, zone.Burn)
							poison(player, k, st, target, zone.Poison, now)
							if zone.Stun and not zone.Stunned then
								zone.Stunned = true
								api.applyCC(target, zone.Stun, "Shocked")
							end
						end
					end
				end
			end
		end
	end
end

-- Your triad buffs and debuffs, for the status bars.
function TriadServer.statuses(st, now, add)
	local t = st.Triad
	if not t then
		return
	end
	if t.Empower and t.Empower.Left > 0 then
		add("Empowered", t.Empower.Until, t.Empower.Left)
	end
	if t.Boost then
		add("Overheated", t.Boost.Until, t.Boost.Amount * 100)
	end
	if t.Guard then
		add("EmberGuard", t.Guard.Until)
	end
	if t.Wall then
		add(if t.Wall.Kind == "Ice" then "FrozenWall" else "FireWall", t.Wall.Until)
	end
	if t.Regen then
		add("Regrowth", t.Regen.Until)
	end
	if t.Phoenix then
		add("PhoenixMantle", t.Phoenix.Until)
	end
	if t.Cut then
		add("IceArmor", t.Cut.Until, t.Cut.Amount * 100)
	end
	if t.Resist then
		add("ColdResolve", t.Resist.Until, t.Resist.Amount * 100)
	end
	if t.Riposte then
		add("FrostRiposte", t.Riposte.Until)
	end
	if t.Catch then
		add("StaticCatch", t.Catch.Until)
	end
	if t.Deflect then
		add("Deflector", t.Deflect.Until)
	end
	add("Grounded", t.GroundedUntil or 0)
	add("Purged", t.ImmuneUntil or 0)
	if t.Corrosion then
		add("CorrosionAura", t.Corrosion.Until)
	end
	if t.Mantle then
		add("ToxicMantle", t.Mantle.Until, t.Mantle.Share * 100)
	end
	add("Untargetable", t.UntargetableUntil or 0)
	add("Rooted", t.RootUntil or 0)
	for _, dot in t.Poisons or {} do
		add("Poisoned", dot.Ends)
	end
	if (t.ChillUntil or 0) > now and (t.Chill or 0) > 0 then
		add("Chilled", t.ChillUntil, t.Chill)
	end
	for _, mark in t.Marks do
		add("Branded", mark.Until)
	end
end

return TriadServer
