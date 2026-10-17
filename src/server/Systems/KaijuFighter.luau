--[[
	A kaiju in a fight (Shared.KaijuFight has the rules): your kaiju
	(KaijuServer) or a wild one (KaijuWilds), against a creature, another
	kaiju or a hunter. It fights exactly as the Arena's duellist does, run by
	the same brain (Shared.DuelistBrain), shrunk to its size: wind-ups and
	combos, telegraphed heavies, guard and parry, hops aside, pounces,
	counters, and its Gemsoul's E (KaijuAbilities) after a wind-up you can
	see on its cast bar.

	  KaijuFighter.new(spec) -> Fighter
	  KaijuFighter.step(fighter, foe, now)   one think (every 0.15s) against `foe`
	  KaijuFighter.calm(fighter)             out of the fight: guard down, poses cleared
	  KaijuFighter.of(model) -> Fighter?     the fighter a model is
	  KaijuFighter.forget(fighter)           it's gone

	spec = {
	  Model, Root, Humanoid, Species, Element, Scale (its size)
	  Body        where its guard and stuns live: its Enemies record (a
	              wild kaiju, so a hunter's blows meet its guard there) or
	              its pet record
	  Stats       Damage, Rate, Speed, Reach (Kaiju.stats)
	  Ability     its Gemsoul's E (nil: none)
	  FirstSurge  its E this long into a fight (Kaiju.FirstSurge)
	  Strike(foe, amount, heavy, name) -> outcome   a blow landing on its foe
	              ("Parried" leaves it reeling)
	  Caster()    its E's caster (KaijuAbilities.cast)
	}
	foe = { Root, Pet? | Enemy? | Player? } (a victim, as KaijuAbilities' are)

	Its model carries, for every client (CreatureAnimation, FoeCastBar):
	ActionKind (Light, Heavy, Punish, Lunge, Bolt, Nova, Dodge, Stagger),
	ActionStart and ActionAt (server time: its wind-up and the blow),
	ActionSide, ActionName and ActionElement (the cast bar, for a heavy or
	its E), GuardUntil (server time, 0 when down).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brain = require(ReplicatedStorage.Shared.DuelistBrain)
local KaijuFight = require(ReplicatedStorage.Shared.KaijuFight)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemTraits = require(ReplicatedStorage.Shared.GemTraits)
local KaijuAbilities = require(script.Parent.KaijuAbilities)

local KaijuFighter = {}

-- Its rolls (tests replace it).
KaijuFighter.random = math.random
-- Fires an effect for every client (Remotes.CombatFx). Tests replace it.
KaijuFighter.fx = function(kind: string, ...)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("CombatFx")
	if event then
		(event :: RemoteEvent):FireAllClients(kind, ...)
	end
end

local fighters: { [Instance]: any } = {} -- by model

local HEAVY_COLOR = Color3.fromRGB(255, 120, 60)
local HEAVY_CHARGE = 0.45 -- a player's charge this long is a heavy (CombatActions Heavy.Charge)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Turns it toward `target`: smoothly with its FaceAlign (KaijuServer.body),
-- else at once.
local function face(f, target: Vector3)
	local root = f.Root
	local look = flat(target - root.Position)
	if look.Magnitude > 0.1 then
		local align = root:FindFirstChild("FaceAlign")
		if align and align:IsA("AlignOrientation") then
			align.CFrame = CFrame.lookAt(Vector3.zero, look)
		else
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		end
	end
end

-- What its body is doing, for every client to pose: the action, when its
-- wind-up began and when it lands. `name` (a heavy, its E) shows on the
-- cast bar so a hunter can see it coming and dodge.
local function animate(f, kind: string, windup: number, side: number?, name: string?)
	local model = f.Model
	local t = serverNow()
	f.Swings += 1
	model:SetAttribute("ActionName", name)
	model:SetAttribute("ActionElement", if name then f.Element else nil)
	model:SetAttribute("ActionKind", kind)
	model:SetAttribute("ActionStart", t)
	model:SetAttribute("ActionAt", t + windup)
	model:SetAttribute("ActionSide", side or (if f.Swings % 2 == 0 then -1 else 1))
end

local function raise(f, now: number, seconds: number)
	KaijuFight.raiseGuard(f, now, seconds)
	local body = f.Body
	if KaijuFight.guarding(body, now) then
		f.Model:SetAttribute("GuardUntil", serverNow() + (body.GuardUntil - now))
	end
end

local function lower(f, now: number)
	if KaijuFight.guarding(f.Body, now) then
		KaijuFight.dropGuard(f, now)
		f.Model:SetAttribute("GuardUntil", 0)
	end
end

-- Readings ---------------------------------------------------------------------------------------------

local CombatServer -- (a hunter's fight state; required on the first hunter it reads)

-- A hunter, read as the duellist reads a player: their swings (each time
-- their next attack moves on), charges, casts and guard.
local function readPlayer(f, player: Player, now: number)
	CombatServer = CombatServer or require(script.Parent.CombatServer)
	local st = CombatServer._state(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	f.FoeSwings = f.FoeSwings or {}
	if st and st.NextAttack ~= f.LastFoeNext then
		f.LastFoeNext = st.NextAttack
		if st.NextAttack > now then
			table.insert(f.FoeSwings, now)
		end
	end
	while f.FoeSwings[1] and now - f.FoeSwings[1] > 2.5 do
		table.remove(f.FoeSwings, 1)
	end
	local last = f.FoeSwings[#f.FoeSwings]
	local blocking = player:GetAttribute("Blocking") == true
	local charging = st ~= nil and st.ChargeStarted ~= nil
	local casting = st ~= nil and (#(st.Pending or {}) > 0 or st.Channel ~= nil)
	return {
		Charging = charging,
		Heavy = charging and now - st.ChargeStarted >= HEAVY_CHARGE - 0.1,
		LastSwing = last,
		Swings = #f.FoeSwings,
		Casting = casting,
		Blocking = blocking,
		Recovering = st ~= nil and st.NextAttack > now + 0.15 and not charging,
		Vulnerable = st ~= nil and (now < (st.StunUntil or 0) or now < (st.SlowUntil or 0)),
		Low = humanoid ~= nil and humanoid.Health < humanoid.MaxHealth * 0.3,
		Busy = (last ~= nil and now - last < 1) or blocking or charging or casting,
	}
end

-- Its foe this moment: another kaiju as it reads (KaijuFight.read), a
-- hunter as above, any other creature (a moon bug) by its swings alone.
local function readFoe(f, foe, now: number)
	if foe.Player then
		return readPlayer(f, foe.Player, now)
	end
	local model = foe.Root.Parent
	local other = model and fighters[model]
	if other then
		local h = other.Humanoid
		return KaijuFight.read(other, now, h.Health / math.max(1, h.MaxHealth))
	end
	local enemy = foe.Enemy
	local last = if enemy and (enemy.LastAttack or 0) > 0 then enemy.LastAttack else nil
	local h = enemy and enemy.Humanoid
	return {
		Charging = false,
		Heavy = false,
		LastSwing = last,
		Swings = if last and now - last <= 2.5 then 1 else 0,
		Casting = false,
		Blocking = false,
		Recovering = false,
		Vulnerable = enemy ~= nil and (now < (enemy.StunUntil or 0) or now < (enemy.SlowUntil or 0)),
		Low = h ~= nil and h.Health < h.MaxHealth * 0.3,
		Busy = last ~= nil and now - last < 1,
	}
end

-- Blows -------------------------------------------------------------------------------------------------

-- Winds up a blow (a heavy rings its feet in warning and names itself on
-- the cast bar).
local function windup(f, kind: string, now: number)
	local seconds = KaijuFight.windup(f.Style, kind)
	f.Action = { Kind = kind, At = now + seconds, Hits = 1 }
	f.LastOffense = now
	local heavy = kind == "Heavy"
	animate(f, kind, seconds, nil, if heavy then f.Style.Names.Heavy else nil)
	if heavy then
		local feet = f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
		KaijuFighter.fx("Nova", feet, f.Reach + 0.5, HEAVY_COLOR, seconds)
	end
end

local function reel(f, now: number, seconds: number)
	local body = f.Body
	body.StunUntil = math.max(body.StunUntil or 0, now + seconds)
	body.StunKind = "Stunned"
	f.StaggeredFor = body.StunUntil
	animate(f, "Stagger", 0)
end

-- A wound-up blow lands (if its foe is still in reach), and may chain
-- into the next of a combo.
local function land(f, action, foe, now: number, distance: number, dir: Vector3)
	local body = f.Body
	if action.Kind == "Surge" then
		KaijuAbilities.cast(f.Caster(), foe)
		f.NextSurge = now + Kaiju.AbilityEvery
		f.NextAttack = math.max(f.NextAttack, now + 0.4)
		return
	end
	local heavy = action.Kind == "Heavy"
	local color = GemConfig.ElementColors[f.Element] or Color3.new(1, 1, 1)
	local arc = if heavy then (if f.Species == "Razorback" then 220 else 150) else 100
	KaijuFighter.fx("Swing", nil, f.Root.Position, dir, f.Reach + 1, arc, color, heavy)
	if heavy and f.Species ~= "Razorback" then
		-- A stomp or a slam: a shockwave at its feet.
		local feet = f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
		KaijuFighter.fx("Nova", feet, f.Reach + 0.5, color, 0)
	end
	if distance * Brain.Reach / f.Reach <= Brain.Reach + KaijuFight.HitRange then
		local blinded = now < (body.BlindUntil or 0) and KaijuFighter.random() < (body.Blind or 0.5)
		if not blinded then
			local amount = f.Stats.Damage * KaijuFight.blow(f.Style, action.Kind, action.Hits)
			local name = f.Style.Names[action.Kind] or action.Kind
			if f.Strike(foe, amount, heavy, name) == "Parried" then
				-- Turned aside just as its guard went up: it's left reeling.
				reel(f, now, KaijuFight.ParryStagger)
				return
			end
		end
	end
	table.insert(f.SwingTimes, now)
	if #f.SwingTimes > 4 then
		table.remove(f.SwingTimes, 1)
	end
	f.RecoverUntil = now + KaijuFight.Recover
	-- Combos: up to its kind's count of quick blows in a row (a counter is one).
	local hits = (action.Hits or 1) + 1
	if
		not heavy
		and action.Kind ~= "Punish"
		and hits <= f.Style.Combo
		and KaijuFighter.random() < f.Style.ComboChance
	then
		local gap = f.Style.ComboGap
		f.Action = { Kind = "Light", At = now + gap, Hits = hits }
		animate(f, "Light", gap)
		return
	end
	-- After a counter it presses straight on.
	local pace = if action.Kind == "Punish" then 0.5 else 1
	f.NextAttack = now + f.Rate * pace * (0.8 + KaijuFighter.random() * 0.4)
end

-- One think -----------------------------------------------------------------------------------------------

-- Into a fight: it faces its foe as it circles (no turning to walk).
local function engage(f, now: number)
	if f.Engaged then
		return
	end
	f.Engaged = true
	f.Humanoid.AutoRotate = false
	local align = f.Root:FindFirstChild("FaceAlign")
	if align then
		(align :: AlignOrientation).Enabled = true
	end
	if not f.Ability then
		f.NextSurge = math.huge
	elseif f.NextSurge == 0 or now - (f.LastFight or 0) > 6 then
		f.NextSurge = now + (f.FirstSurge or KaijuFight.FirstSurge)
	end
end

function KaijuFighter.step(f, foe, now: number)
	local body, root, humanoid = f.Body, f.Root, f.Humanoid
	engage(f, now)
	f.LastFight = now
	local k = f.Reach / Brain.Reach -- the brain's studs -> its own
	local offset = flat(foe.Root.Position - root.Position)
	local center = offset.Magnitude
	local distance = math.max(0, center - foe.Root.Size.X / 2)
	local dir = if center > 0.01 then offset.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local guarded = KaijuFight.guarding(body, now)
	if not guarded and (f.Model:GetAttribute("GuardUntil") or 0) > 0 then
		f.Model:SetAttribute("GuardUntil", 0) -- (broken, or run out)
	end
	humanoid.WalkSpeed = f.Stats.Speed
		* (1 - (if now < (body.SlowUntil or 0) then body.Slow or 0 else 0))
		* (if guarded then 0.7 else 1) -- a guarded shuffle

	-- A wind-up in progress: hold still, face its foe, then strike.
	local action = f.Action
	if action then
		if now < (body.StunUntil or 0) then
			f.Action = nil -- parried or stunned: the blow is lost
			reel(f, now, 0)
			return
		end
		if action.Kind ~= "Lunge" then
			humanoid:MoveTo(root.Position)
		end
		face(f, foe.Root.Position)
		if now < action.At then
			return
		end
		f.Action = nil
		land(f, action, foe, now, distance, dir)
		return
	end

	local h = humanoid
	local ratio = h.Health / math.max(1, h.MaxHealth)
	local view = KaijuFight.view(f, readFoe(f, foe, now), now, distance, ratio)
	local choice = KaijuFight.decide(f, view, KaijuFighter.random())
	f.Choice = choice
	if choice == "Stagger" then
		humanoid:MoveTo(root.Position)
		if f.StaggeredFor ~= body.StunUntil then
			reel(f, now, 0) -- reel once per stun
		end
	elseif choice == "Guard" then
		-- Braced, longer against a flurry, edging sideways behind it.
		local hold = if view.FoeAggressive then 2.2 elseif view.FoeIdle then 0.6 else 1.6
		if not guarded then
			-- Just braced: a beat before it can strike (keeping it up doesn't
			-- push its next blow back, or it would never strike).
			f.NextAttack = math.max(f.NextAttack, now + 0.3)
		end
		raise(f, now, hold)
		humanoid:MoveTo(root.Position + side * f.Weave * 2 * k)
		face(f, foe.Root.Position)
	elseif choice == "GuardAdvance" then
		-- Walks its foe down braced (it drops the guard to strike once in reach).
		raise(f, now, 0.8)
		humanoid:MoveTo(foe.Root.Position - dir * 3 * k + side * f.Weave * k)
		face(f, foe.Root.Position)
	elseif choice == "Riposte" or choice == "Punish" then
		-- A blocked blow or an opening: a quick counter.
		if choice == "Riposte" then
			f.RiposteFor = body.BlockedAt
		end
		lower(f, now)
		windup(f, "Punish", now)
		humanoid:MoveTo(root.Position)
		face(f, foe.Root.Position)
	elseif choice == "Dodge" then
		-- A hop aside, untouchable for a moment.
		local sign = if KaijuFighter.random() < 0.5 then 1 else -1
		local away = side * sign
		body.DodgeUntil = now + KaijuFight.DodgeFor
		animate(f, "Dodge", 0, sign)
		root.AssemblyLinearVelocity = away * 55 * k * f.Style.Hop + Vector3.new(0, 6 * k, 0)
		KaijuFighter.fx("DodgeRoll", nil, root.Position, away, 8 * k * f.Style.Hop, true)
	elseif choice == "Lunge" then
		-- A pounce from mid range, the blow landing as it arrives.
		lower(f, now)
		f.NextLunge = now + 4 + KaijuFighter.random() * 2
		root.AssemblyLinearVelocity = dir * math.min(80 * k, distance * 5) + Vector3.new(0, 4 * k, 0)
		KaijuFighter.fx("DodgeRoll", nil, root.Position, dir, math.max(1, distance - f.Reach * 0.5), false)
		windup(f, "Lunge", now)
		face(f, foe.Root.Position)
	elseif choice == "Surge" then
		-- Its E, after a wind-up its foe can read (a Pneumatic Jab silences it).
		if f.Ability and now >= ((body :: any).SilenceUntil or 0) then
			local plan = Kaiju.AbilityPlans[f.Ability]
			local kind = KaijuFight.surgeKind(plan)
			local seconds = Brain.Windup[kind]
			local move = GemTraits.Moves[f.Ability]
			lower(f, now)
			f.LastOffense = now
			f.Action = { Kind = "Surge", At = now + seconds }
			animate(f, kind, seconds, nil, if move then move.Name else "E")
			humanoid:MoveTo(root.Position)
			face(f, foe.Root.Position)
		else
			f.NextSurge = now + 1
		end
	elseif choice == "Retreat" then
		f.NextRetreat = now + 10
		f.RetreatUntil = now + 1.2
	elseif choice == "Approach" then
		if now >= f.NextWeave then
			f.Weave, f.NextWeave = -f.Weave, now + 0.8 + KaijuFighter.random()
		end
		humanoid:MoveTo(foe.Root.Position - dir * 2 * k + side * f.Weave * 1.5 * k)
		face(f, foe.Root.Position)
	elseif choice == "Light" or choice == "Heavy" then
		lower(f, now)
		windup(f, choice, now)
		humanoid:MoveTo(root.Position)
		face(f, foe.Root.Position)
	else -- Strafe: circles its foe between blows
		if now >= f.NextWeave then
			f.Weave, f.NextWeave = -f.Weave, now + 1 + KaijuFighter.random() * 1.2
		end
		if view.FoeIdle then
			-- Its foe's standing there: it circles in close, ready to strike.
			humanoid:MoveTo(foe.Root.Position - dir * 4 * k + side * f.Weave * 2 * k)
		else
			local keep = if distance < 1 then -dir * 3 * k else Vector3.zero
			humanoid:MoveTo(root.Position + side * f.Weave * 4 * k + keep)
		end
		face(f, foe.Root.Position)
	end
	if f.RetreatUntil and now < f.RetreatUntil and not f.Action then
		humanoid:MoveTo(root.Position - dir * 10 * k)
	end
end

-- Out of the fight (following its owner, walking home): guard down, its
-- wind-up dropped, turning to walk again.
function KaijuFighter.calm(f)
	if not f.Engaged then
		return
	end
	f.Engaged = false
	f.Action = nil
	f.Body.GuardUntil = 0
	f.FoeIdleSince, f.FarSince, f.RetreatUntil = nil, nil, nil
	f.FoeSwings, f.LastFoeNext = nil, nil
	f.Humanoid.AutoRotate = true
	local align = f.Root:FindFirstChild("FaceAlign")
	if align then
		(align :: AlignOrientation).Enabled = false
	end
	local model = f.Model
	model:SetAttribute("GuardUntil", 0)
	model:SetAttribute("ActionName", nil)
	model:SetAttribute("ActionKind", nil)
end

-- A kaiju's fighter, from its spec (see the top).
function KaijuFighter.new(spec)
	local f =
		KaijuFight.new(spec.Species, spec.Body, KaijuFight.reach(spec.Stats.Reach, spec.Scale or 1), spec.Stats.Rate)
	f.Model, f.Root, f.Humanoid = spec.Model, spec.Root, spec.Humanoid
	f.Element, f.Stats, f.Ability, f.Scale = spec.Element, spec.Stats, spec.Ability, spec.Scale or 1
	f.FirstSurge = spec.FirstSurge
	f.Strike, f.Caster = spec.Strike, spec.Caster
	f.Swings, f.Engaged = 0, false
	fighters[spec.Model] = f
	return f
end

-- New stats (a level, a Gemsoul): its blows and reach follow.
function KaijuFighter.restat(f, stats, scale: number?)
	f.Stats, f.Rate = stats, stats.Rate
	f.Reach = KaijuFight.reach(stats.Reach, scale or f.Scale or 1)
end

function KaijuFighter.of(model: Instance?)
	return if model then fighters[model] else nil
end

function KaijuFighter.forget(f)
	if f and fighters[f.Model] == f then
		fighters[f.Model] = nil
	end
end

return KaijuFighter
