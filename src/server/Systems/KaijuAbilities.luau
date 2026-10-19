--[[
	A kaiju casting one of its Gemsoul's moves (Shared.Kaiju.AbilityPlans):
	its E, its Q (a strike) or its R (a shell, a ward, a mend or a ring):
	where it lands, when, on whom, and how it looks. Pets and wild kaiju cast
	the same way; the caster says who its foes are and how a hit lands on
	them.

	  KaijuAbilities.cast(caster, aim, id?) -> boolean   false if it can't
	                        (id: the move, else its E)
	  KaijuAbilities.soak(body, amount) -> amount   a blow on it, less what
	                        its R's shell or ward takes (KaijuServer.hurt,
	                        Enemies.damage)

	  caster = {
	    Model, Root           the kaiju
	    Size?                 how big it stands next to you (Kaiju.size; 1)
	    Element, Ability      its Gemsoul's element and E (an AbilityPlans id)
	    Damage                its E's whole cast (Kaiju.abilityDamage)
	    DamageOf(id)?         another move's (else Damage)
	    Body?, Humanoid?      where its R's shell sits, and its health (a
	                          shell or a mend needs them)
	    Recharge(seconds)?    brings its next Q and E nearer (Capacitor)
	    Foes(center, radius)  its foes inside a circle -> { victim }
	    Hit(victim, amount, status?)   a hit landing on one of them
	    Alive()               still able to finish a delayed cast
	  }
	  victim = { Root: BasePart, ... } (anything the caster's Hit understands)
	  aim = its foe's victim (where Bolts, Blasts and Lines go)

	The big showcase moves draw with their own look (MoveVfx, "TriadShow");
	the rest with the shared shots, blasts, arcs and pools; an R with the
	triad's auras (TriadAura) on the kaiju.

	Its moves are its size (AbilityPlans are a player's): every radius,
	length and width by its Size, what it hits and what's drawn alike, and
	each effect goes out "Sized" so the client draws it, sounds it and
	shakes your screen that big.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local KaijuAbilities = {}

-- Fires an effect for every client (Remotes.CombatFx). Tests replace it.
KaijuAbilities.fx = function(kind: string, ...)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("CombatFx")
	if event then
		(event :: RemoteEvent):FireAllClients(kind, ...)
	end
end
-- Runs `fn` after `seconds` (task.delay). Tests replace it.
KaijuAbilities.after = function(seconds: number, fn: () -> ())
	task.delay(seconds, fn)
end
-- Its clock, for how long an R holds (os.clock, as KaijuServer and
-- Enemies keep time). Tests replace it.
KaijuAbilities.clock = os.clock

-- Its effects: at its size, "Sized" (the client's FxSize) unless it's yours.
local function sender(caster): (string, ...any) -> ()
	local size = caster.Size or 1
	if size == 1 then
		return KaijuAbilities.fx
	end
	return function(kind: string, ...)
		KaijuAbilities.fx("Sized", size, kind, ...)
	end
end

-- The HUD's attribute for when each key last went off.
local CAST_AT = { Q = "KaijuQAt", E = "KaijuAbilityAt", R = "KaijuRAt" }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Is `point` within `width` of the segment a-b (on the ground plane)?
local function onLine(point: Vector3, a: Vector3, b: Vector3, width: number): boolean
	local ab, ap = flat(b - a), flat(point - a)
	local length = ab.Magnitude
	if length < 0.01 then
		return ap.Magnitude <= width
	end
	local along = math.clamp(ap:Dot(ab) / (length * length), 0, 1)
	return (ap - ab * along).Magnitude <= width
end
KaijuAbilities._onLine = onLine

local function each(caster, center: Vector3, radius: number, fn)
	for _, victim in caster.Foes(center, radius) do
		fn(victim)
	end
end

-- Every foe the sweep from `a` to `b` passes through, once each.
local function sweep(caster, a: Vector3, b: Vector3, width: number, amount: number, status: string?)
	local middle = (a + b) / 2
	local reach = (b - a).Magnitude / 2 + width
	for _, victim in caster.Foes(middle, reach) do
		if onLine(victim.Root.Position, a, b, width) then
			caster.Hit(victim, amount, status)
		end
	end
end

-- Every foe within `radius` of it, hit.
local function ring(caster, radius: number, amount: number, status: string?)
	each(caster, caster.Root.Position, radius, function(victim)
		caster.Hit(victim, amount, status)
	end)
end

-- Shakes off what the elements left on it: burns and poisons, slows, blinds.
local function cleanse(body)
	if not body then
		return
	end
	if type(body.Dots) == "table" then
		table.clear(body.Dots)
	end
	body.SlowUntil, body.BlindUntil = 0, 0
end

-- An R's aura: every second it holds, foes near it take its share.
local function aura(caster, plan, damage: number, seconds: number)
	local a = plan.Aura
	if not a then
		return
	end
	local radius = (a.Radius or 5) * (caster.Size or 1)
	for i = 1, math.max(1, math.floor(seconds)) do
		KaijuAbilities.after(i, function()
			if caster.Alive() then
				ring(caster, radius, damage * (a.Mult or 0.2), a.Status)
			end
		end)
	end
end

function KaijuAbilities.soak(body, amount: number): number
	local d = body and body.Defense
	if not d then
		return amount
	end
	if KaijuAbilities.clock() >= d.Until then
		body.Defense = nil
		return amount
	end
	if d.Reduce then
		amount *= 1 - d.Reduce
	end
	if d.Left then
		local taken = math.min(d.Left, amount)
		d.Left -= taken
		amount -= taken
		if d.Left <= 0 then
			-- Broken: a ward under it holds on; its burst goes off.
			d.Left = nil
			if not d.Reduce then
				body.Defense = nil
			end
			d.Break()
		end
	end
	return amount
end

-- Its R's shell or ward, its mend, or (a ring) nothing here: false.
local function defend(caster, id: string, plan, damage: number): boolean
	local fx = sender(caster)
	local shape = plan.Shape
	local h = caster.Humanoid
	local seconds = plan.Duration or 4
	if shape == "Mend" then
		if not h then
			return false
		end
		cleanse(if plan.Cleanse then caster.Body else nil)
		fx("TriadAura", caster.Root, id, caster.Element, "Heal", seconds)
		local ticks = math.max(1, math.floor(seconds / 0.5))
		for i = 1, ticks do
			KaijuAbilities.after(i * 0.5, function()
				if caster.Alive() then
					h.Health = math.min(h.MaxHealth, h.Health + h.MaxHealth * plan.Heal / ticks)
				end
			end)
		end
		return true
	end
	local body = caster.Body
	if not body then
		return false
	end
	local d = { Until = KaijuAbilities.clock() + seconds }
	if shape == "Shell" then
		d.Left = (if h then h.MaxHealth else 100) * plan.Absorb
	else
		d.Reduce = plan.Reduce
	end
	-- Its burst: once, when the shell breaks or runs out.
	local popped = false
	d.Break = function()
		if popped then
			return
		end
		popped = true
		local burst = plan.Burst
		if burst and caster.Alive() then
			local color = GemConfig.ElementColors[caster.Element] or Color3.new(1, 1, 1)
			local radius = burst.Radius * (caster.Size or 1)
			fx("Nova", caster.Root.Position, radius, color, 0)
			ring(caster, radius, damage * (burst.Mult or 0.3), burst.Status)
		end
	end
	body.Defense = d
	cleanse(if plan.Cleanse then body else nil)
	local look = if plan.Aura and plan.Aura.Status == "Poison"
		then "Mantle"
		elseif shape == "Shell" then "Shield"
		else "Armor"
	fx("TriadAura", caster.Root, id, caster.Element, look, seconds)
	KaijuAbilities.after(seconds, function()
		if body.Defense == d then
			body.Defense = nil
		end
		d.Break()
	end)
	if plan.Recharge and caster.Recharge then
		caster.Recharge(plan.Recharge)
	end
	aura(caster, plan, damage, seconds)
	return true
end

-- Cast a move (its E, unless `id` names another) at `aim`. Returns false
-- if it can't.
function KaijuAbilities.cast(caster, aim, id: string?): boolean
	id = id or caster.Ability
	local plan = id and Kaiju.AbilityPlans[id]
	if not plan or not aim or not aim.Root or not caster.Root then
		return false
	end
	local fx = sender(caster)
	local size = caster.Size or 1
	local color = GemConfig.ElementColors[caster.Element] or Color3.new(1, 1, 1)
	local from = caster.Root.Position
	local at = aim.Root.Position
	local damage = if caster.DamageOf then caster.DamageOf(id) else caster.Damage
	local status = plan.Status
	local model = caster.Model
	local key = string.sub(id :: string, 1, 1)
	caster.Model:SetAttribute(CAST_AT[key] or CAST_AT.E, workspace:GetServerTimeNow())

	if plan.Shape == "Shell" or plan.Shape == "Ward" or plan.Shape == "Mend" then
		return defend(caster, id :: string, plan, damage)
	end

	if plan.Shape == "Bolt" then
		fx("Shot", nil, from, at, color, if id == "E_EmberLance" then "Fireball" else nil)
		KaijuAbilities.after(0.25, function()
			if aim.Root.Parent then
				caster.Hit(aim, damage, status)
			end
		end)
	elseif plan.Shape == "Blast" then
		local radius, delay = (plan.Radius or 8) * size, plan.Delay or 0
		if plan.Show then
			-- (The showcase blasts draw their own warning and burst.)
			KaijuAbilities.after(delay, function()
				fx("TriadShow", model, plan.Show, from, at, radius, caster.Element)
			end)
		else
			fx("Nova", at, radius, color, delay)
		end
		KaijuAbilities.after(delay, function()
			if caster.Alive() then
				each(caster, at, radius, function(victim)
					caster.Hit(victim, damage, status)
				end)
			end
		end)
	elseif plan.Shape == "Nova" then
		local radius = (plan.Radius or 8) * size
		if id == "R_RingOfFire" then
			fx("TriadRing", caster.Root, radius, 1, caster.Element)
		elseif caster.Element == "Poison" then
			fx("TriadBreak", from, radius, caster.Element)
		else
			fx("Nova", from, radius, color, 0)
		end
		each(caster, from, radius, function(victim)
			caster.Hit(victim, damage, status)
		end)
	elseif plan.Shape == "Line" then
		local length, width = (plan.Length or 20) * size, (plan.Width or 4) * size
		local direction = flat(at - from)
		direction = if direction.Magnitude > 0.1 then direction.Unit else flat(caster.Root.CFrame.LookVector).Unit
		local finish = from + direction * length
		if plan.Show == "IonCannon" then
			fx("TriadShow", model, plan.Show, from, finish, width, caster.Element)
		elseif plan.Show then
			fx("TriadShow", model, plan.Show, from, finish, 1, width, caster.Element)
		else
			fx("TriadTrail", from, finish, width, 1, caster.Element)
		end
		sweep(caster, from, finish, width, damage, status)
	elseif plan.Shape == "Field" then
		local radius, duration = (plan.Radius or 8) * size, plan.Duration or 3
		if plan.Show then
			fx("TriadShow", model, plan.Show, at, radius, duration, caster.Element)
		else
			fx("Zone", at, radius, duration, color)
		end
		-- A tick every half second, the damage shared out between them.
		local ticks = math.max(1, math.floor(duration / 0.5))
		for i = 1, ticks do
			KaijuAbilities.after(i * 0.5, function()
				if caster.Alive() then
					each(caster, at, radius, function(victim)
						caster.Hit(victim, damage / ticks, if i == ticks then status else nil)
					end)
				end
			end)
		end
	elseif plan.Shape == "Chain" then
		-- Leaps from foe to foe (never the same one twice), Hits in all.
		local hit, last, point = { [aim] = true }, aim, from
		local hops = { aim }
		local leap = (plan.Radius or 14) * size
		while #hops < (plan.Hits or 3) do
			local nearest, best = nil, leap
			for _, victim in caster.Foes(last.Root.Position, leap) do
				local distance = (victim.Root.Position - last.Root.Position).Magnitude
				if not hit[victim] and distance <= best then
					nearest, best = victim, distance
				end
			end
			if not nearest then
				break
			end
			hit[nearest], last = true, nearest
			table.insert(hops, nearest)
		end
		for i, victim in hops do
			local to = victim.Root.Position
			fx("Arc", point, to, color)
			point = to
			KaijuAbilities.after(0.08 * i, function()
				if victim.Root.Parent then
					caster.Hit(victim, damage / #hops, status)
				end
			end)
		end
	elseif plan.Shape == "Storm" then
		local radius, hits = (plan.Radius or 9) * size, plan.Hits or 5
		fx("TriadShow", model, plan.Show or "StormCall", at, radius, hits * 0.5 + 0.5, caster.Element)
		for i = 1, hits do
			KaijuAbilities.after(i * 0.5, function()
				if not caster.Alive() then
					return
				end
				-- Each bolt hunts the nearest foe in the storm.
				local nearest, best = nil, math.huge
				for _, victim in caster.Foes(at, radius) do
					local distance = (victim.Root.Position - at).Magnitude
					if distance < best then
						nearest, best = victim, distance
					end
				end
				local point = if nearest then nearest.Root.Position else at
				fx("TriadShow", model, "StormBolt", point, 3 * size, if i == hits then 1 else 0, caster.Element)
				if nearest then
					caster.Hit(nearest, damage / hits, if i == hits then status else nil)
				end
			end)
		end
	elseif plan.Shape == "Pylon" then
		local reach, duration = (plan.Radius or 14) * size, plan.Duration or 4
		local center = from + flat(at - from).Unit * 2 * size
		fx("TriadPylon", center, reach, duration, caster.Element)
		local ticks = math.max(1, math.floor(duration / 0.5))
		for i = 1, ticks do
			KaijuAbilities.after(i * 0.5, function()
				local nearest, best = nil, math.huge
				for _, victim in caster.Foes(center, reach) do
					local distance = (victim.Root.Position - center).Magnitude
					if distance < best then
						nearest, best = victim, distance
					end
				end
				if nearest then
					fx("Arc", center + Vector3.new(0, 4 * size, 0), nearest.Root.Position, color)
					caster.Hit(nearest, damage / ticks, nil)
				end
			end)
		end
	else
		return false
	end
	return true
end

return KaijuAbilities
