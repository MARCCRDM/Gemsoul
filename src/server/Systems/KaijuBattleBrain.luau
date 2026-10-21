--[[
	A kaiju in a kaiju battle (the Kaiju Arena's auto battle, KaijuBattles):
	it fights by its role (Shared.KaijuRoles), as an auto battler's pieces
	do, not as a duellist:

	  Who      the foe its role picks (KaijuRoles.target), looked at again
	           every think: one down, it's straight onto the next (its
	           nearest, for a melee one), whether it's one on one or three
	           on one; taunted, its taunter.
	  Where    KaijuRoles.spot: a melee one closes to its reach, on its own
	           side of a foe it shares; a shooter holds its ground and
	           shoots while its foe's in range and backs off from one too
	           close; never past the court's rails (no running into them).
	  Blows    every Rate seconds (faster under its War Cry), after a short
	           wind-up its foe can see: a bite, or a spine for a shooter.
	  Moves    its E when its mana's full (KaijuRoles.mana: it fills as it
	           hits and is hit), its Q every QEvery seconds from level 5,
	           its R when its moment comes (KaijuRoles.wantsR) from level 10,
	           each cast by KaijuAbilities. An assassin leaps on their back
	           row the moment the battle starts.
	  Stunned  it stands, and the blow it was winding up is lost.

	  KaijuBattleBrain.step(pet, orders, now, host)   one think (every 0.15s)
	      orders: KaijuServer.battle's ({ Foes, Allies, Bounds })
	      host: KaijuServer (hurt, caster, place, ground)
	  KaijuBattleBrain.reset(pet)   out of a battle: its battle state gone

	Its model carries, as any kaiju's does for every client
	(CreatureAnimation, FoeCastBar): ActionKind (Light, Bolt, Lunge, Nova),
	ActionStart and ActionAt, ActionName and ActionElement for a move.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuRoles = require(ReplicatedStorage.Shared.KaijuRoles)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local KaijuAbilities = require(script.Parent.KaijuAbilities)

local KaijuBattleBrain = {}

-- Fires an effect for every client (Remotes.CombatFx). Tests replace it.
KaijuBattleBrain.fx = function(kind: string, ...)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("CombatFx")
	if event then
		(event :: RemoteEvent):FireAllClients(kind, ...)
	end
end

local MOVE_WINDUP = { E = 0.5, Q = 0.4, R = 0.25 }
local SIZE = Kaiju.size(Kaiju.Scale.Pet)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function sized(kind: string, ...)
	KaijuBattleBrain.fx("Sized", SIZE, kind, ...)
end

-- Its battle state, made the first time it thinks in one.
local function brainOf(pet, now: number)
	local brain = pet.Brain
	if not brain then
		brain = {
			Mana = 0,
			Target = nil,
			NextAttack = now + 0.3,
			NextQ = now + KaijuRoles.FirstQ,
			NextR = now,
			LastHealth = pet.Humanoid.Health,
			Opened = false,
			Action = nil,
			Moving = nil,
		}
		pet.Brain = brain
	end
	return brain
end

-- Its unit for KaijuRoles (kept on it, refreshed each think).
local function unitOf(pet)
	local unit = pet.Unit
	if not unit then
		unit = { Pet = pet }
		pet.Unit = unit
	end
	unit.Role = KaijuRoles.of(pet.Record.Species)
	unit.Pos = pet.Root.Position
	unit.Health = pet.Humanoid.Health
	unit.MaxHealth = pet.Humanoid.MaxHealth
	return unit
end

-- Who each unit is on and who taunted it (other units: set once all are
-- refreshed).
local function link(pet)
	local unit = pet.Unit
	local brain = pet.Brain
	unit.Target = brain and brain.Target and brain.Target.Unit or nil
	unit.TauntBy = pet.TauntBy and pet.TauntBy.Unit or nil
	unit.TauntUntil = pet.TauntUntil
end

-- Turns it to `point` (its FaceAlign, held while it stands to strike).
local function face(pet, point: Vector3)
	local root = pet.Root
	local look = flat(point - root.Position)
	if look.Magnitude < 0.1 then
		return
	end
	local align = root:FindFirstChild("FaceAlign")
	if align and align:IsA("AlignOrientation") then
		align.Enabled = true
		pet.Humanoid.AutoRotate = false
		align.CFrame = CFrame.lookAt(Vector3.zero, look)
	else
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
end

-- Walks it to `point` (turning as it walks), or stops it there.
local function walk(pet, brain, point: Vector3?)
	local h, root = pet.Humanoid, pet.Root
	if point and flat(point - root.Position).Magnitude > 0.6 then
		local align = root:FindFirstChild("FaceAlign")
		if align and align:IsA("AlignOrientation") then
			align.Enabled = false
		end
		h.AutoRotate = true
		h:MoveTo(point)
		brain.Moving = point
	else
		h:MoveTo(root.Position)
		brain.Moving = nil
	end
end

local function animate(pet, kind: string, windup: number, name: string?)
	local model = pet.Model
	local t = serverNow()
	model:SetAttribute("ActionName", name)
	model:SetAttribute("ActionElement", if name then pet.Element else nil)
	model:SetAttribute("ActionKind", kind)
	model:SetAttribute("ActionStart", t)
	model:SetAttribute("ActionAt", t + windup)
	model:SetAttribute("ActionSide", if math.random() < 0.5 then -1 else 1)
end

local function victimOf(foe)
	return { Root = foe.Root, Pet = foe }
end

-- How each move winds up, on its body.
local POSE = {
	Taunt = "Nova",
	Nova = "Nova",
	Shell = "Nova",
	Rally = "Nova",
	Line = "Heavy",
	Blast = "Heavy",
	Storm = "Bolt",
	Vault = "Dodge",
	Leap = "Lunge",
	Flurry = "Light",
	Vanish = "Dodge",
}

-- Starts winding up its move on `key` at `foe`.
local function windupMove(pet, brain, key: string, id: string, foe, now: number)
	local move = KaijuRoles.Moves[id]
	local plan = move and move.Plan
	local seconds = MOVE_WINDUP[key] or 0.4
	brain.Action = { Kind = "Move", Key = key, Id = id, Foe = foe, At = now + seconds }
	animate(pet, POSE[plan and plan.Shape or ""] or "Bolt", seconds, if move then move.Name else key)
	walk(pet, brain, nil)
	if foe then
		face(pet, foe.Root.Position)
	end
end

-- Its blow (or a shooter's spine) on `foe`, if it's still there and in reach.
local function strike(pet, brain, foe, now: number, host)
	local unit = pet.Unit
	local role = KaijuRoles.Roles[unit.Role] or KaijuRoles.Roles.Warrior
	if not foe or not foe.Model.Parent or foe.Humanoid.Health <= 0 then
		return
	end
	local d = flat(foe.Root.Position - pet.Root.Position).Magnitude
	local reach = if role.Range then role.Range + 2 else role.Reach + 1.5
	local color = GemConfig.ElementColors[pet.Element] or Color3.new(1, 1, 1)
	local damage = pet.Stats.Damage
		* KaijuRoles.power(unit.Role, pet.Record and pet.Record.Level)
		* (if now < (pet.RallyUntil or 0) then pet.RallyDamage or 1 else 1)
	if role.Range then
		local root = pet.Root
		local from = root.Position + root.CFrame.LookVector * root.Size.Z * 0.5
		sized("Shot", nil, from, foe.Root.Position, color, "Spine")
	end
	if d > reach then
		return -- (it got away)
	end
	if now < (pet.BlindUntil or 0) and math.random() < 0.5 then
		return
	end
	brain.Mana += KaijuRoles.mana(unit.Role, true, 0)
	pet.LastFight = now
	host.hurt(foe, damage, pet.Element, nil, false)
end

-- Casts its move (the wind-up done).
local function cast(pet, brain, key: string, id: string, foe, host)
	if not foe or not foe.Model.Parent then
		return
	end
	local ok = KaijuAbilities.cast(host.caster(pet), victimOf(foe), id)
	if ok then
		pet.LastFight = os.clock()
	end
end

-- Seconds between its blows (faster under its War Cry).
local function rate(pet, now: number): number
	local haste = if now < (pet.RallyUntil or 0) then pet.RallyHaste or 1 else 1
	return math.max(0.3, pet.Stats.Rate / haste)
end

function KaijuBattleBrain.step(pet, orders, now: number, host)
	local brain = brainOf(pet, now)
	local h, root = pet.Humanoid, pet.Root
	local me = unitOf(pet)
	local role = KaijuRoles.Roles[me.Role] or KaijuRoles.Roles.Warrior
	-- Mana from the health it's lost since it last thought.
	local lost = (brain.LastHealth - h.Health) / math.max(1, h.MaxHealth)
	if lost > 0 then
		brain.Mana += KaijuRoles.mana(me.Role, false, lost)
	end
	brain.LastHealth = h.Health
	brain.Mana = math.min(brain.Mana, KaijuRoles.ManaMax)
	pet.Model:SetAttribute("KaijuMana", math.floor(brain.Mana + 0.5))
	h.WalkSpeed = pet.Stats.Speed * (1 - (if now < (pet.SlowUntil or 0) then pet.Slow or 0 else 0))

	-- Stunned or frozen: it stands, and what it was winding up is lost.
	if now < (pet.StunUntil or 0) then
		brain.Action = nil
		walk(pet, brain, nil)
		return
	end

	local foes, allies = {}, {}
	for _, other in orders.Foes or {} do
		table.insert(foes, unitOf(other))
	end
	for _, other in orders.Allies or {} do
		table.insert(allies, unitOf(other))
	end
	if not table.find(orders.Allies or {}, pet) then
		table.insert(allies, me)
	end
	for _, other in orders.Foes or {} do
		link(other)
	end
	for _, other in orders.Allies or {} do
		link(other)
	end
	link(pet)

	-- A wind-up in progress: it holds still facing its foe, then lands it.
	-- Its foe down meanwhile, it drops it (a move's wait given back) and
	-- turns at once to the next.
	local action = brain.Action
	if action and action.Foe and (not action.Foe.Model.Parent or action.Foe.Humanoid.Health <= 0) then
		brain.Action = nil
		if action.Kind == "Move" then
			if action.Key == "E" then
				brain.Mana = KaijuRoles.ManaMax
			elseif action.Key == "Q" then
				brain.NextQ = now
			else
				brain.NextR = now
			end
		end
		action = nil
	end
	if action then
		local foe = action.Foe
		if foe and foe.Model.Parent then
			face(pet, foe.Root.Position)
		end
		if now < action.At then
			return
		end
		brain.Action = nil
		if action.Kind == "Move" then
			cast(pet, brain, action.Key, action.Id, foe, host)
		else
			strike(pet, brain, foe, now, host)
		end
		return
	end

	if #foes == 0 then
		brain.Target = nil
		walk(pet, brain, nil)
		return
	end
	local level = pet.Record.Level or 1
	local kit = KaijuRoles.kit(pet.Record.Species)

	-- An assassin's opening leap onto their back row.
	if role.Opens and not brain.Opened then
		brain.Opened = true
		local mark = KaijuRoles.target(me, foes, now)
		if mark then
			brain.Target = mark.Pet
			windupMove(pet, brain, "E", kit.E, mark.Pet, now)
			return
		end
	end

	local target = KaijuRoles.target(me, foes, now)
	brain.Target = target and target.Pet
	me.Target = target
	if not target then
		walk(pet, brain, nil)
		return
	end
	local foe = target.Pet
	local d = flat(foe.Root.Position - root.Position).Magnitude

	-- Its R, when its moment comes.
	if level >= KaijuRoles.MoveLevels.R and now >= brain.NextR and KaijuRoles.wantsR(me, foes, now) then
		brain.NextR = now + KaijuRoles.REvery
		windupMove(pet, brain, "R", kit.R, foe, now)
		return
	end
	-- Its E, its mana full (in reach of its foe, or near it).
	local inReach = if role.Range then d <= role.Range else d <= role.Reach + 1.5
	if brain.Mana >= KaijuRoles.ManaMax and (inReach or role.Opens) then
		brain.Mana = 0
		windupMove(pet, brain, "E", kit.E, foe, now)
		return
	end
	-- Its Q.
	if level >= KaijuRoles.MoveLevels.Q and now >= brain.NextQ and inReach then
		brain.NextQ = now + KaijuRoles.QEvery
		windupMove(pet, brain, "Q", kit.Q, foe, now)
		return
	end

	-- Where it goes, and a blow if it can. (A shooter that's backed off
	-- stands its ground a while: BackEvery.)
	me.CanBack = now >= (brain.NextBack or 0)
	local spot, canHit, backing = KaijuRoles.spot(me, target, allies, foes, orders.Bounds)
	if backing then
		brain.NextBack = now + KaijuRoles.BackEvery
		walk(pet, brain, spot)
		return
	end
	if canHit and now >= brain.NextAttack then
		brain.NextAttack = now + rate(pet, now)
		local seconds = role.Windup or 0.35
		brain.Action = { Kind = "Blow", Foe = foe, At = now + seconds }
		animate(pet, if role.Range then "Bolt" else "Light", seconds, nil)
		walk(pet, brain, nil)
		face(pet, foe.Root.Position)
		return
	end
	if canHit and flat(spot - root.Position).Magnitude <= 0.6 then
		walk(pet, brain, nil)
		face(pet, foe.Root.Position)
	else
		walk(pet, brain, spot)
	end
end

-- Out of a battle: its battle state gone, it walks and turns again.
function KaijuBattleBrain.reset(pet)
	pet.Brain = nil
	pet.TauntBy, pet.TauntUntil = nil, nil
	pet.RallyUntil = nil
	if pet.Model and pet.Model.Parent then
		pet.Model:SetAttribute("KaijuMana", nil)
	end
	local root = pet.Root
	local align = root and root:FindFirstChild("FaceAlign")
	if align and align:IsA("AlignOrientation") then
		align.Enabled = false
	end
	if pet.Humanoid then
		pet.Humanoid.AutoRotate = true
	end
end

return KaijuBattleBrain
