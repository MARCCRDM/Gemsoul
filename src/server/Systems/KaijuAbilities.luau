--[[
	A kaiju casting its Gemsoul's E (Shared.Kaiju.AbilityPlans): where it
	lands, when, on whom, and how it looks. Pets and wild kaiju cast the same
	way; the caster says who its foes are and how a hit lands on them.

	  KaijuAbilities.cast(caster, aim) -> boolean   false if it has no E

	  caster = {
	    Model, Root           the kaiju
	    Element, Ability      its Gemsoul's element and E (an AbilityPlans id)
	    Damage                the whole cast's damage (Kaiju.abilityDamage)
	    Foes(center, radius)  its foes inside a circle -> { victim }
	    Hit(victim, amount, status?)   a hit landing on one of them
	    Alive()               still able to finish a delayed cast
	  }
	  victim = { Root: BasePart, ... } (anything the caster's Hit understands)
	  aim = its foe's victim (where Bolts, Blasts and Lines go)

	The big showcase moves draw with their own look (MoveVfx, "TriadShow");
	the rest with the shared shots, blasts, arcs and pools.
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

-- Cast its E at `aim`. Returns false if it has none.
function KaijuAbilities.cast(caster, aim): boolean
	local plan = Kaiju.AbilityPlans[caster.Ability]
	if not plan or not aim or not aim.Root or not caster.Root then
		return false
	end
	local fx = KaijuAbilities.fx
	local color = GemConfig.ElementColors[caster.Element] or Color3.new(1, 1, 1)
	local from = caster.Root.Position
	local at = aim.Root.Position
	local damage = caster.Damage
	local status = plan.Status
	local model = caster.Model
	caster.Model:SetAttribute("KaijuAbilityAt", workspace:GetServerTimeNow())

	if plan.Shape == "Bolt" then
		fx("Shot", nil, from, at, color, if caster.Ability == "E_EmberLance" then "Fireball" else nil)
		KaijuAbilities.after(0.25, function()
			if aim.Root.Parent then
				caster.Hit(aim, damage, status)
			end
		end)
	elseif plan.Shape == "Blast" then
		local radius, delay = plan.Radius or 8, plan.Delay or 0
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
		local radius = plan.Radius or 8
		if caster.Element == "Poison" then
			fx("TriadBreak", from, radius, caster.Element)
		else
			fx("Nova", from, radius, color, 0)
		end
		each(caster, from, radius, function(victim)
			caster.Hit(victim, damage, status)
		end)
	elseif plan.Shape == "Line" then
		local length, width = plan.Length or 20, plan.Width or 4
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
		local radius, duration = plan.Radius or 8, plan.Duration or 3
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
		while #hops < (plan.Hits or 3) do
			local nearest, best = nil, plan.Radius or 14
			for _, victim in caster.Foes(last.Root.Position, plan.Radius or 14) do
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
		local radius, hits = plan.Radius or 9, plan.Hits or 5
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
				fx("TriadShow", model, "StormBolt", point, 3, if i == hits then 1 else 0, caster.Element)
				if nearest then
					caster.Hit(nearest, damage / hits, if i == hits then status else nil)
				end
			end)
		end
	elseif plan.Shape == "Pylon" then
		local reach, duration = plan.Radius or 14, plan.Duration or 4
		local center = from + flat(at - from).Unit * 2
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
					fx("Arc", center + Vector3.new(0, 4, 0), nearest.Root.Position, color)
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
