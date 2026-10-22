--[[
	A kaiju in a fight (Shared.KaijuFight has the rules): your kaiju
	(KaijuServer) or a wild one (KaijuWilds), against a creature, another
	kaiju or a hunter. It fights exactly as the Arena's duellist does, run by
	the same brain (Shared.DuelistBrain), shrunk to its size: wind-ups and
	combos, telegraphed heavies, guard and parry, hops aside, pounces,
	counters, and its moves (KaijuAbilities) after a wind-up you can see on
	its cast bar: its kind's own E, its Q in place of a blow once it's
	level 5, its R when it's hard pressed once it's level 10, and its gem
	surge (its Gemsoul's E) every Kaiju.GemSurge.Every seconds. A Razorback
	fights from range between its combos (KaijuFight's Ranged): it hops
	back after a combo and looses volleys of spines (Shot "Spine"), then
	closes in again.

	  KaijuFighter.new(spec) -> Fighter
	  KaijuFighter.step(fighter, foe, now)   one think (every 0.15s) against `foe`
	  KaijuFighter.calm(fighter)             out of the fight: guard down, poses cleared
	  KaijuFighter.of(model) -> Fighter?     the fighter a model is
	  KaijuFighter.forget(fighter)           it's gone
	  KaijuFighter.setMoves(fighter, moves)  its Q and R awake (a level)

	spec = {
	  Model, Root, Humanoid, Species, Element, Scale (its size)
	  Body        where its guard and stuns live: its Enemies record (a
	              wild kaiju, so a hunter's blows meet its guard there) or
	              its pet record
	  Stats       Damage, Rate, Speed, Reach (Kaiju.stats)
	  Ability     its own E (Kaiju.kitMoves; nil: none)
	  Moves       its Q and R awake (Kaiju.kitMoves: { Q?, R? })
	  GemSurge    its gem surge (Kaiju.gemSurge: its Gemsoul's E; nil: none)
	  FirstSurge  its E this long into a fight (Kaiju.FirstSurge)
	  Strike(foe, amount, heavy, name) -> outcome   a blow landing on its foe
	              ("Parried" leaves it reeling)
	  Caster()    its caster, for any of its moves (KaijuAbilities.cast)
	  Around()    (optional) the other foes about it, as victims: a heavy
	              sweeps through those in reach inside its arc, and with a
	              crowd of them in reach it swings heavies more
	              (KaijuFight.Cleave)
	}
	foe = { Root, Pet? | Enemy? | Player? } (a victim, as KaijuAbilities' are)

	Fighting beside others (Shared.Squad): whoever runs it may set, before
	each step, f.Flank (a unit direction: the side of its foe it fights
	from, when it shares that foe) and f.Apart (a push clear of its own side
	crowding it). With neither it fights as it does alone.

	Its effects go out "Sized" (Kaiju.size of its Scale: the client draws
	them, sounds them and shakes your screen as big as it stands), and an R
	ring is cast only on a foe inside the ring at its size.

	Its model carries, for every client (CreatureAnimation, FoeCastBar):
	ActionKind (Light, Heavy, Punish, Lunge, Bolt, Nova, Dodge, Stagger; a
	volley of spines winds up as a Bolt),
	ActionStart and ActionAt (server time: its wind-up and the blow),
	ActionSide, ActionName and ActionElement (the cast bar, for a heavy or
	its E), GuardUntil (server time, 0 when down).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brain = require(ReplicatedStorage.Shared.DuelistBrain)
local KaijuFight = require(ReplicatedStorage.Shared.KaijuFight)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Squad = require(ReplicatedStorage.Shared.Squad)
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
-- Its effect, at its size ("Sized") when it isn't a player's.
local function fx(f, kind: string, ...)
	local size = f.Size or 1
	if size ~= 1 then
		KaijuFighter.fx("Sized", size, kind, ...)
	else
		KaijuFighter.fx(kind, ...)
	end
end

local fighters: { [Instance]: any } = {} -- by model

local HEAVY_CHARGE = 0.45 -- a player's charge this long is a heavy (CombatActions Heavy.Charge)
local FIRST_Q = 6 -- its Q this long into a fight (after its E, so they don't land together)
local R_WINDUP = 0.25 -- a shell goes up quickly: it's a reaction
local FLANK_TURN = math.rad(50) -- how far round its foe it works toward its flank each think

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

-- Walks to `point`, nudged clear of its own side (f.Apart).
local function walk(f, point: Vector3)
	local apart = f.Apart
	if apart then
		point += apart
	end
	f.Humanoid:MoveTo(point)
end

-- A spot `standoff` from its foe on its flank (f.Flank), worked round toward
-- it a step at a time so it goes round its foe, not through; `swing`
-- (radians) sways it either side as it circles.
local function flankSpot(f, foePos: Vector3, standoff: number, swing: number): Vector3
	local dir = Squad.toward(flat(f.Root.Position - foePos), f.Flank, FLANK_TURN)
	if swing ~= 0 then
		local c, s = math.cos(swing), math.sin(swing)
		dir = Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
	end
	return foePos + dir * standoff
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
	-- (A critter's wind-up, KaijuWilds: a heavy to hop clear of, a lob or
	-- a burst to read as a cast.)
	local windup = enemy and (enemy :: any).Windup
	local winding = windup ~= nil and now < windup.At
	return {
		Charging = winding and windup.Heavy == true,
		Heavy = winding and windup.Heavy == true,
		LastSwing = last,
		Swings = if last and now - last <= 2.5 then 1 else 0,
		Casting = winding and windup.Cast == true,
		Blocking = false,
		Recovering = enemy ~= nil and now < ((enemy :: any).RecoverUntil or 0),
		Vulnerable = enemy ~= nil and (now < (enemy.StunUntil or 0) or now < (enemy.SlowUntil or 0)),
		Low = h ~= nil and h.Health < h.MaxHealth * 0.3,
		Busy = last ~= nil and now - last < 1,
	}
end

-- Blows -------------------------------------------------------------------------------------------------

-- Winds up a blow (a heavy marks the ground at its feet in warning, in its
-- element's look, and names itself on the cast bar).
local function windup(f, kind: string, now: number)
	local seconds = KaijuFight.windup(f.Style, kind)
	f.Action = { Kind = kind, At = now + seconds, Hits = 1 }
	f.LastOffense = now
	local heavy = kind == "Heavy"
	animate(f, kind, seconds, nil, if heavy then f.Style.Names.Heavy else nil)
	if heavy then
		local feet = f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
		-- (Only the warning: the blow itself lands with its own stomp or cleave.)
		fx(f, "Telegraph", feet, f.Reach + 0.5, GemConfig.ElementColors[f.Element] or Color3.new(1, 1, 1), seconds)
	end
end

-- A ranged fighter's hop back from its foe (along -`dir`), untouchable
-- for a moment.
local function hopBack(f, now: number, dir: Vector3)
	local ranged = f.Style.Ranged
	local k = f.Reach / Brain.Reach
	f.NextHop = now + ranged.HopEvery
	f.Body.DodgeUntil = now + KaijuFight.DodgeFor
	animate(f, "Dodge", 0, if KaijuFighter.random() < 0.5 then 1 else -1)
	f.Root.AssemblyLinearVelocity = -dir * ranged.HopBack * 6 * k + Vector3.new(0, 8 * k, 0)
	fx(f, "DodgeRoll", nil, f.Root.Position, -dir, ranged.HopBack * k, true)
end

-- Out to range: back it hops, and its volleys start.
local function toRange(f, now: number, dir: Vector3)
	local ranged = f.Style.Ranged
	f.Phase, f.MeleeHits = "Range", 0
	f.VolleysLeft, f.NextVolley = ranged.Volleys, now + 0.45
	hopBack(f, now, dir)
end

-- One spine of a volley, from its mouth at its foe: it lands at once if its
-- foe's still within its reach (a hop aside dodges it).
local function spine(f, foe, now: number, distance: number)
	local ranged = f.Style.Ranged
	local root = f.Root
	local color = GemConfig.ElementColors[f.Element] or Color3.new(1, 1, 1)
	local from = root.Position + root.CFrame.LookVector * root.Size.Z * 0.5 + Vector3.new(0, root.Size.Y * 0.2, 0)
	fx(f, "Shot", nil, from, foe.Root.Position, color, ranged.Shot)
	if distance * Brain.Reach / f.Reach > ranged.Reach + KaijuFight.HitRange then
		return
	end
	local body = f.Body
	if now < (body.BlindUntil or 0) and KaijuFighter.random() < (body.Blind or 0.5) then
		return
	end
	f.Strike(foe, f.Stats.Damage * ranged.Mult, nil :: any, ranged.Name)
end

local function reel(f, now: number, seconds: number)
	local body = f.Body
	body.StunUntil = math.max(body.StunUntil or 0, now + seconds)
	body.StunKind = "Stunned"
	f.StaggeredFor = body.StunUntil
	animate(f, "Stagger", 0)
end

-- Is `other` (a victim) within a blow's reach of it (edge to edge, in the
-- brain's studs)?
local function inReach(f, other): boolean
	local center = flat(other.Root.Position - f.Root.Position).Magnitude
	local distance = math.max(0, center - other.Root.Size.X / 2)
	return distance * Brain.Reach / f.Reach <= Brain.Reach + KaijuFight.HitRange
end

-- A wound-up blow lands (if its foe is still in reach), and may chain
-- into the next of a combo.
local function land(f, action, foe, now: number, distance: number, dir: Vector3)
	local body = f.Body
	if action.Kind == "Volley" then
		-- A volley of spines, Gap apart; then the next is a while off, and
		-- after its last it closes in again.
		local ranged = f.Style.Ranged
		spine(f, foe, now, distance)
		if (action.Shots or 1) > 1 then
			f.Action = { Kind = "Volley", At = now + ranged.Gap, Shots = action.Shots - 1 }
			return
		end
		f.VolleysLeft = (f.VolleysLeft or 1) - 1
		f.NextVolley = now + ranged.Every * (0.85 + KaijuFighter.random() * 0.3)
		if f.VolleysLeft <= 0 then
			f.Phase, f.MeleeHits = "Melee", 0
		end
		table.insert(f.SwingTimes, now)
		if #f.SwingTimes > 4 then
			table.remove(f.SwingTimes, 1)
		end
		f.RecoverUntil = now + KaijuFight.Recover
		return
	elseif action.Kind == "Surge" then
		if action.Gem then
			KaijuAbilities.cast(f.Caster(action.Id), foe, action.Id)
		else
			KaijuAbilities.cast(f.Caster(), foe)
			f.NextSurge = now + Kaiju.AbilityEvery
		end
		f.NextAttack = math.max(f.NextAttack, now + 0.4)
		return
	elseif action.Kind == "Move" then
		local caster = f.Caster(action.Id)
		-- (A Capacitor's soaked charge brings its next Q and E nearer.)
		caster.Recharge = function(seconds: number)
			f.NextSurge -= seconds
			f.NextQ -= seconds
		end
		KaijuAbilities.cast(caster, foe, action.Id)
		f.NextAttack = math.max(f.NextAttack, now + 0.4)
		return
	end
	local heavy = action.Kind == "Heavy"
	local color = GemConfig.ElementColors[f.Element] or Color3.new(1, 1, 1)
	local cleave = KaijuFight.Cleave
	local arc = if heavy then f.Style.Arc or cleave.Arc else 100
	fx(f, "Swing", nil, f.Root.Position, dir, f.Reach + 1, arc, color, heavy)
	if heavy and not f.Style.Ranged then
		-- A stomp or a slam: a shockwave at its feet.
		local feet = f.Root.Position - Vector3.new(0, f.Root.Size.Y / 2 + f.Humanoid.HipHeight, 0)
		fx(f, "Nova", feet, f.Reach + 0.5, color, 0)
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
			-- A heavy sweeps on through the rest of a swarm in its arc.
			if heavy and f.Around then
				for _, other in f.Around() do
					if other.Root ~= foe.Root and inReach(f, other) then
						local toward = other.Root.Position - f.Root.Position
						if KaijuFight.inArc(dir, toward, arc) then
							f.Strike(other, amount * cleave.Share, true, name)
						end
					end
				end
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
	-- A ranged fighter's combo done up close: back it hops to shoot.
	local ranged = f.Style.Ranged
	if ranged and f.Phase ~= "Range" then
		f.MeleeHits = (f.MeleeHits or 0) + (action.Hits or 1)
		if f.MeleeHits >= ranged.Combo then
			toRange(f, now, dir)
		end
	end
end

-- A ranged fighter out at range (KaijuFight.rangedMove): it keeps its
-- distance, circling, and looses its volleys; pressed close it hops back,
-- or bites.
local function skirmish(f, foe, now: number, distance: number, dir: Vector3, side: Vector3)
	local ranged = f.Style.Ranged
	local root = f.Root
	local k = f.Reach / Brain.Reach
	local m = KaijuFight.rangedMove(f, distance * Brain.Reach / f.Reach, now)
	f.Choice = m
	if m == "Hop" then
		lower(f, now)
		hopBack(f, now, dir)
	elseif m == "Bite" then
		lower(f, now)
		windup(f, "Light", now)
		f.Humanoid:MoveTo(root.Position)
	elseif m == "Volley" then
		lower(f, now)
		f.LastOffense = now
		f.Action = { Kind = "Volley", At = now + ranged.Windup, Shots = ranged.Shots }
		animate(f, "Bolt", ranged.Windup, nil, ranged.Name)
		f.Humanoid:MoveTo(root.Position)
	else
		if now >= f.NextWeave then
			f.Weave, f.NextWeave = -f.Weave, now + 1 + KaijuFighter.random() * 1.2
		end
		local band = if m == "Close" then ranged.Keep[2] * 0.85 else (ranged.Keep[1] + ranged.Keep[2]) / 2
		walk(f, foe.Root.Position - dir * band * k + side * f.Weave * 3 * k)
	end
	face(f, foe.Root.Position)
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
	if f.NextQ == 0 or now - (f.LastFight or 0) > 6 then
		f.NextQ, f.NextR = now + FIRST_Q, now
	end
	if not f.GemSurge then
		f.NextGem = math.huge
	elseif f.NextGem == 0 or now - (f.LastFight or 0) > 6 then
		f.NextGem = now + Kaiju.GemSurge.First
	end
end

-- Winds up its Q or R (named on its cast bar), and starts that key's wait.
local function move(f, key: string, id: string, foe, now: number)
	local plan = Kaiju.AbilityPlans[id]
	local kind = KaijuFight.surgeKind(plan)
	local seconds = if key == "R" then R_WINDUP else Brain.Windup[kind] * 0.7
	local named = Kaiju.moveInfo(id)
	lower(f, now)
	if key == "Q" then
		f.LastOffense = now
		f.NextQ = now + Kaiju.QEvery
	else
		f.NextR = now + Kaiju.REvery
	end
	f.Action = { Kind = "Move", Key = key, Id = id, At = now + seconds }
	animate(f, kind, seconds, nil, if named then named.Name else key)
	f.Humanoid:MoveTo(f.Root.Position)
	face(f, foe.Root.Position)
end

-- Winds up its gem surge (its Gemsoul's E, named on its cast bar: a cast
-- its foe can read and dodge, as its E is), and starts its wait.
local function gemSurge(f, foe, now: number)
	local id = f.GemSurge
	local kind = KaijuFight.surgeKind(Kaiju.AbilityPlans[id])
	local seconds = Brain.Windup[kind]
	local named = Kaiju.moveInfo(id)
	lower(f, now)
	f.LastOffense = now
	f.NextGem = now + Kaiju.GemSurge.Every
	f.Action = { Kind = "Surge", Gem = true, Id = id, At = now + seconds }
	animate(f, kind, seconds, nil, if named then named.Name else "Gem")
	f.Humanoid:MoveTo(f.Root.Position)
	face(f, foe.Root.Position)
end

-- Is its gem surge due and worth casting now: free to strike, not stunned
-- or silenced, no heavy coming at it (it guards that), its foe in range
-- (a ring round itself only with its foe inside it)?
local function gemReady(f, view, distance: number, now: number): boolean
	if not f.GemSurge or now < f.NextGem or view.Stunned or view.FoeCharging then
		return false
	end
	if now < f.NextAttack or now < ((f.Body :: any).SilenceUntil or 0) then
		return false
	end
	local plan = Kaiju.AbilityPlans[f.GemSurge]
	if plan.Shape == "Nova" then
		return distance <= (plan.Radius or 6) * (f.Size or 1)
	end
	return view.Distance <= Brain.SurgeRange
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
	-- (How many foes it has in reach: a crowd draws a sweeping heavy.)
	if f.Around then
		local crowd = if distance * Brain.Reach / f.Reach <= Brain.Reach + KaijuFight.HitRange then 1 else 0
		for _, other in f.Around() do
			if other.Root ~= foe.Root and inReach(f, other) then
				crowd += 1
			end
		end
		view.Crowd = crowd
	end
	-- Its R, hard pressed: low on health, or a heavy blow or a cast coming
	-- (a ring only with its foe inside it).
	local moves = f.Moves
	local ringR = moves.R and Kaiju.AbilityPlans[moves.R]
	if
		moves.R
		and now >= f.NextR
		and not view.Stunned
		and (ratio <= Kaiju.RWhen or view.FoeHeavy or view.FoeCasting)
		and not (ringR and ringR.Shape == "Nova" and distance > (ringR.Radius or 6) * (f.Size or 1))
	then
		f.Choice = "R"
		move(f, "R", moves.R, foe, now)
		return
	end
	-- Its gem surge, when it's due.
	if gemReady(f, view, distance, now) then
		f.Choice = "Gem"
		gemSurge(f, foe, now)
		return
	end
	local choice = KaijuFight.decide(f, view, KaijuFighter.random())
	f.Choice = choice
	-- Out at range: only a stagger, a hop aside, a guard against a blow
	-- coming or its E break off its shooting.
	if
		f.Phase == "Range"
		and not (
			choice == "Stagger"
			or choice == "Dodge"
			or choice == "Surge"
			or (choice == "Guard" and (view.FoeCharging or view.FoeCasting))
		)
	then
		skirmish(f, foe, now, distance, dir, side)
		return
	end
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
		walk(f, root.Position + side * f.Weave * 2 * k)
		face(f, foe.Root.Position)
	elseif choice == "GuardAdvance" then
		-- Walks its foe down braced (it drops the guard to strike once in reach).
		raise(f, now, 0.8)
		walk(
			f,
			if f.Flank
				then flankSpot(f, foe.Root.Position, 3 * k, 0)
				else foe.Root.Position - dir * 3 * k + side * f.Weave * k
		)
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
		fx(f, "DodgeRoll", nil, root.Position, away, 8 * k * f.Style.Hop, true)
	elseif choice == "Lunge" then
		-- A pounce from mid range, the blow landing as it arrives.
		lower(f, now)
		f.NextLunge = now + 4 + KaijuFighter.random() * 2
		root.AssemblyLinearVelocity = dir * math.min(80 * k, distance * 5) + Vector3.new(0, 4 * k, 0)
		fx(f, "DodgeRoll", nil, root.Position, dir, math.max(1, distance - f.Reach * 0.5), false)
		windup(f, "Lunge", now)
		face(f, foe.Root.Position)
	elseif choice == "Surge" then
		-- Its E, after a wind-up its foe can read (a Pneumatic Jab silences it).
		if f.Ability and now >= ((body :: any).SilenceUntil or 0) then
			local plan = Kaiju.AbilityPlans[f.Ability]
			local kind = KaijuFight.surgeKind(plan)
			local seconds = Brain.Windup[kind]
			local move = Kaiju.moveInfo(f.Ability)
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
		walk(
			f,
			if f.Flank
				then flankSpot(f, foe.Root.Position, 2 * k, f.Weave * 0.2)
				else foe.Root.Position - dir * 2 * k + side * f.Weave * 1.5 * k
		)
		face(f, foe.Root.Position)
	elseif (choice == "Light" or choice == "Heavy") and moves.Q and now >= f.NextQ then
		-- Its Q, in place of a blow.
		f.Choice = "Q"
		move(f, "Q", moves.Q, foe, now)
	elseif choice == "Light" or choice == "Heavy" then
		lower(f, now)
		windup(f, choice, now)
		humanoid:MoveTo(root.Position)
		face(f, foe.Root.Position)
	else -- Strafe: circles its foe between blows
		if now >= f.NextWeave then
			f.Weave, f.NextWeave = -f.Weave, now + 1 + KaijuFighter.random() * 1.2
		end
		if f.Flank then
			-- Sharing its foe: it circles on its own side of it.
			local standoff = if view.FoeIdle then 4 * k else math.max(center, 3 * k)
			walk(f, flankSpot(f, foe.Root.Position, standoff, f.Weave * 0.35))
		elseif view.FoeIdle then
			-- Its foe's standing there: it circles in close, ready to strike.
			walk(f, foe.Root.Position - dir * 4 * k + side * f.Weave * 2 * k)
		else
			local keep = if distance < 1 then -dir * 3 * k else Vector3.zero
			walk(f, root.Position + side * f.Weave * 4 * k + keep)
		end
		face(f, foe.Root.Position)
	end
	if f.RetreatUntil and now < f.RetreatUntil and not f.Action then
		walk(f, root.Position - dir * 10 * k)
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
	f.Phase, f.MeleeHits = nil, 0 -- (its next fight opens up close)
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
	f.Size = Kaiju.size(f.Scale)
	f.FirstSurge = spec.FirstSurge
	f.Strike, f.Caster, f.Around = spec.Strike, spec.Caster, spec.Around
	f.Moves = spec.Moves or {}
	f.GemSurge = spec.GemSurge
	f.NextQ, f.NextR, f.NextGem = 0, 0, 0
	f.Swings, f.Engaged = 0, false
	fighters[spec.Model] = f
	return f
end

-- Its Q and R awake now (Kaiju.moves, at a new level).
function KaijuFighter.setMoves(f, moves)
	f.Moves = moves or {}
end

-- A new gem surge (a new Gemsoul: Kaiju.recordSurge; nil: none), its wait
-- starting over.
function KaijuFighter.setGemSurge(f, id: string?)
	f.GemSurge = id
	f.NextGem = 0
end

-- New stats (a level, a Gemsoul): its blows and reach follow.
function KaijuFighter.restat(f, stats, scale: number?)
	f.Stats, f.Rate = stats, stats.Rate
	f.Reach = KaijuFight.reach(stats.Reach, scale or f.Scale or 1)
end

-- (For tests: what it reads off a foe.)
KaijuFighter._readFoe = readFoe

function KaijuFighter.of(model: Instance?)
	return if model then fighters[model] else nil
end

function KaijuFighter.forget(f)
	if f and fighters[f.Model] == f then
		fighters[f.Model] = nil
	end
end

return KaijuFighter
