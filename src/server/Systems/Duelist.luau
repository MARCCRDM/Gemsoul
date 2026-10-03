--[[
	The PvP Duelist: entering the PvP Arena brings a computer rival with its
	own random loadout (rolled like a new player's: six pieces of gear, a gem
	in the weapon and three Gem Surges). It fights like a player:

	  · closes in weaving, circles you between attacks
	  · quick swings (sometimes a two-hit chain) and slow, telegraphed heavy
	    blows that break your guard
	  · raises its guard or sidesteps when you wind up a swing
	  · a full Surge Array (three rolled surge gems, each on its own
	    cooldown): bolts from range, ground blasts with a warning ring you can
	    step out of, and self-buffs (Cryo Shield, Energy Siphon, Resonance Echo)
	  · backs off now and then when badly hurt

	Your guard, parries, dodges and gems all work against it, because it is an
	Enemy (see Enemies.adopt) and its hits go through CombatServer.hurt. Its
	decisions live in Shared.DuelistBrain.

	Win: coins, XP and a kill; a new rival steps in a few seconds later.
	Lose, leave the Arena or the floor: the rival leaves too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Brain = require(ReplicatedStorage.Shared.DuelistBrain)
local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local Matchup = require(ReplicatedStorage.Shared.Matchup)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local ArenaSessions = require(script.Parent.ArenaSessions)
local CombatServer = require(script.Parent.CombatServer)
local Enemies = require(script.Parent.Enemies)
local Equipment = require(script.Parent.Equipment)
local GemGenerator = require(script.Parent.GemGenerator)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local DamageLog = require(script.Parent.DamageLog)

local Duelist = {}

local NAMES = {
	"Kade Vorn",
	"Mira Flint",
	"Rook Halden",
	"Sable Quarry",
	"Juno Strike",
	"Dax Ironvein",
	"Nyla Shard",
	"Brask Ember",
	"Tova Cinder",
	"Orin Slate",
}
local WIN_COINS = 25
local REMATCH_DELAY = 6

-- [owner] = { Enemy, Owner, Name, Element, Damage, ... } for the live rival.
local duels: { [Player]: any } = {}
local starting: { [Player]: boolean } = {}
local idCounter = 0

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rating(ratings, stat: string): number
	local r = ratings[stat]
	return if r then r.Base + r.Bonus else 0
end

-- A random loadout, rolled the way a new player's starter kit is.
local function rollLoadout(rng: Random)
	local class = Classes.get("Warrior")
	local profile = {
		Character = { Class = "Warrior", Weapon = class.Weapons[1].Id, Armor = class.Armors[1].Id },
		Owned = {},
	}
	Slots.initialize(profile)
	GearRolls.grant(profile, class, rng)
	local c = profile.Character
	c.WeaponQuality = c.WeaponQuality or 1
	c.ArmorQuality = c.ArmorQuality or 1
	idCounter += 1
	local gem = GemGenerator.generate(rng, "PvEDrop", { Id = "duel-w" .. idCounter, Time = os.time() })
	c.WeaponGem = gem
	c.ItemGems.Weapon[c.Weapon] = gem
	-- A full Surge Array, like a player's: three gems rolled like mined ones.
	for i = 1, 3 do
		c["Surge" .. i .. "Gem"] =
			GemGenerator.generate(rng, "PvEDrop", { Id = "duel-s" .. idCounter .. "-" .. i, Time = os.time() })
	end
	return c
end

-- Places with Roblox's newer avatar joints build rigs from physics joints
-- (AnimationConstraints and ball sockets), which let posed limbs swing
-- loose. The rival gets classic rigid Motor6D joints instead, built from the
-- same rig attachments, so its poses hold exactly.
local JOINT_NAMES = {
	Root = true,
	Waist = true,
	Neck = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftHip = true,
	LeftKnee = true,
	LeftAnkle = true,
	RightHip = true,
	RightKnee = true,
	RightAnkle = true,
}
local function classicJoints(rig: Model): number
	local converted = 0
	for _, constraint in rig:GetDescendants() do
		if constraint:IsA("AnimationConstraint") and constraint.Attachment0 and constraint.Attachment1 then
			local a0, a1 = constraint.Attachment0, constraint.Attachment1
			local part0, part1 = a0.Parent, a1.Parent
			if part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart") then
				local name = if JOINT_NAMES[constraint.Name]
					then constraint.Name
					else (string.gsub(a0.Name, "RigAttachment$", ""))
				local motor = Instance.new("Motor6D")
				motor.Name = name
				motor.Part0, motor.Part1 = part0, part1
				motor.C0, motor.C1 = a0.CFrame, a1.CFrame
				motor.Parent = part1
				constraint:Destroy()
				converted += 1
			end
		end
	end
	if converted > 0 then
		-- The ball sockets only limited the physics joints.
		for _, socket in rig:GetDescendants() do
			if socket:IsA("BallSocketConstraint") or socket:IsA("HingeConstraint") then
				socket:Destroy()
			end
		end
	end
	return converted
end

-- An R15 rig in the rival's gear, standing at `at`.
local function buildRig(loadout, name: string, at: CFrame): Model?
	local ok, rig = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin =
			Color3.fromHSV(0.06 + math.random() * 0.05, 0.25 + math.random() * 0.35, 0.45 + math.random() * 0.5)
		description.HeadColor, description.TorsoColor = skin, skin
		description.LeftArmColor, description.RightArmColor = skin, skin
		description.LeftLegColor, description.RightLegColor = skin, skin
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("Duelist rig failed:", rig)
		return nil
	end
	rig.Name = name
	classicJoints(rig)
	-- Stream the whole body at once, so clients can pose its joints.
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	rig:PivotTo(at)
	Equipment.dressModel(rig, loadout, math.random(1, 1e6))
	-- A translucent shield plate that shows while its guard is up.
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	local plate = Instance.new("Part")
	plate.Name = "GuardPlate"
	plate.Size = Vector3.new(3.4, 4, 0.2)
	plate.Material = Enum.Material.ForceField
	plate.Color = Color3.fromRGB(120, 220, 255)
	plate.Transparency = 1
	plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.Massless = false, false, false, true
	plate.CFrame = root.CFrame * CFrame.new(0, 0.5, -1.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, plate
	weld.Parent = plate
	plate.Parent = rig
	return rig
end

function Duelist.despawn(owner: Player)
	local duel = duels[owner]
	duels[owner] = nil
	if duel and duel.Enemy.Alive then
		Enemies.remove(duel.Enemy)
	end
end

local spawnRival
local castSurge
local strike
local P_GOLD = Color3.fromRGB(255, 190, 80)

local function ownerRoot(owner: Player): (BasePart?, Humanoid?)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- What the rival is doing, for the player's rival panel (only on change).
local function setStance(duel, stance: string)
	if duel.Stance ~= stance then
		duel.Stance = stance
		duel.Enemy.Model:SetAttribute("Stance", stance)
	end
end

-- The "button" the rival just pressed (LMB, RMB, SPACE, Q/E/R, 1/2/3), so the
-- player's rival panel can light up its keys like their own controls.
local function press(duel, key: string)
	local model = duel.Enemy.Model
	model:SetAttribute("LastKey", key)
	model:SetAttribute("LastKeyAt", workspace:GetServerTimeNow())
end

-- What its body is doing, for the player's client to pose (see the client's
-- RivalPose): the action, when its wind-up began and when it lands.
-- `name` (a surge, maneuver or "Heavy Blow") shows on the player's enemy
-- cast bar, so they can see it coming and dodge.
local function animate(duel, kind: string, windup: number, side: number?, name: string?)
	local model = duel.Enemy.Model
	local t = workspace:GetServerTimeNow()
	duel.Swings = (duel.Swings or 0) + 1
	model:SetAttribute("ActionName", name)
	model:SetAttribute("ActionElement", if name then duel.CastElement else nil)
	model:SetAttribute("ActionKind", kind)
	model:SetAttribute("ActionStart", t)
	model:SetAttribute("ActionAt", t + windup)
	model:SetAttribute("ActionSide", side or (if duel.Swings % 2 == 0 then -1 else 1))
end

-- Roblox's stock R15 idle, walk and run, played on the server so every
-- client sees its legs move.
local LOCOMOTION = { Idle = 507766388, Walk = 507777826, Run = 507767714 }

local function animateLegs(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for name, id in LOCOMOTION do
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Core
			tracks[name] = track
		end
	end
	local current
	local function play(name: string, speed: number)
		local track = tracks[name]
		if not track then
			return
		end
		if current ~= track then
			if current then
				current:Stop(0.2)
			end
			track:Play(0.2)
			current = track
		end
		track:AdjustSpeed(speed)
	end
	play("Idle", 1)
	humanoid.Running:Connect(function(speed)
		if speed > 12 then
			play("Run", speed / 16)
		elseif speed > 0.5 then
			play("Walk", math.max(0.5, speed / 10))
		else
			play("Idle", 1)
		end
	end)
end

local function face(root: BasePart, target: Vector3)
	local look = flat(target - root.Position)
	if look.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
end

-- Self-buff surges; every other surge is a bolt or, with a radius, a blast.
local SELF_SURGES = { CryoShield = true, EnergySiphon = true, ResonanceEcho = true }

-- Its basic attacks, as named in the combat log.
local SWING_NAMES = { Light = "Quick Swing", Heavy = "Heavy Blow", Punish = "Counterstrike", Lunge = "Lunging Strike" }

local function nextSurgeTime(duel, now: number): number
	local soonest = math.huge
	for _, surge in duel.Surges do
		soonest = math.min(soonest, surge.Next)
	end
	return math.max(soonest, now)
end

-- Lands a blow on its player; a hit that gets through carries its gem's
-- element (burn, slow or freeze, armor shred, shock), as a player's would.
function strike(duel, amount: number, element: string?, heavy: boolean?, gem, ability: string)
	local previous = DamageLog.push(ability, element)
	local dealt, guarded = Enemies.hitPlayer(duel.Owner, amount, element, duel.Enemy, heavy)
	DamageLog.pop(previous)
	if type(dealt) == "number" and dealt > 0 and not guarded and gem then
		CombatServer.enemyProc(duel.Owner, gem, duel.Enemy)
	end
end

-- Heals itself (anti-heal applies) and tells its player in the combat log.
local function healSelf(duel, share: number, ability: string)
	local enemy = duel.Enemy
	local humanoid = enemy.Humanoid
	local full = humanoid.MaxHealth * share
	local healing = full * Enemies.healingMultiplier(enemy)
	local restored = math.min(humanoid.MaxHealth - humanoid.Health, healing)
	humanoid.Health += restored
	DamageLog.send(
		duel.Owner,
		{ Dir = "Foe", Kind = "Heal", Who = duel.Name, Ability = ability, Amount = restored, Blocked = full - healing }
	)
end

function castSurge(enemy, duel, surge, now: number, target: BasePart)
	local root = enemy.Root
	local model = enemy.Model
	local color = GemConfig.ElementColors[surge.Element] or P_GOLD
	surge.Next = now + surge.Cooldown
	-- A short gap after any surge, so it doesn't fire all three at once.
	duel.NextSurge = math.max(nextSurgeTime(duel, now), now + 2.5)
	model:SetAttribute("SurgeReadyAt" .. surge.Slot, workspace:GetServerTimeNow() + surge.Cooldown)
	model:SetAttribute("SurgeCastAt" .. surge.Slot, workspace:GetServerTimeNow())
	setStance(duel, "Surge")
	press(duel, ({ "Q", "E", "R" })[surge.Slot])
	Remotes.CombatFx:FireClient(duel.Owner, "TechStatus", duel.Name .. " casts " .. surge.Name .. "!")
	DamageLog.send(
		duel.Owner,
		{ Dir = "Foe", Kind = "Cast", Who = duel.Name, Ability = surge.Name, Element = surge.Element }
	)
	if surge.Kind == "Self" then
		animate(duel, "Buff", 0.15)
		fx("TechPulse", nil, root.Position, root.Position, color, 5)
		if surge.Id == "CryoShield" then
			enemy.GuardUntil, enemy.GuardMult = now + 4, 0.5 -- a barrier that halves hits
			duel.CryoUntil = now + 4
		elseif surge.Id == "EnergySiphon" then
			healSelf(duel, 0.12, surge.Name)
		else -- ResonanceEcho
			duel.EchoUntil = now + 5
		end
		return
	end
	if surge.Kind == "Nova" then
		-- A blast with a warning ring: under the player, or around itself.
		local center = if surge.SelfCentered then root.Position else target.Position
		fx("Nova", center - Vector3.new(0, 2.5, 0), surge.Radius, color, Brain.Windup.Nova)
		duel.CastElement = surge.Element
		animate(duel, "Nova", Brain.Windup.Nova, nil, surge.Name)
		duel.Action = {
			Kind = "Nova",
			Name = surge.Name,
			At = now + Brain.Windup.Nova,
			Center = center,
			Radius = surge.Radius,
			Power = surge.Power,
			Element = surge.Element,
			Gem = surge.Gem,
		}
	else
		fx("TechPulse", nil, root.Position, root.Position, color, 3)
		duel.Action = {
			Kind = "Bolt",
			Name = surge.Name,
			At = now + Brain.Windup.Bolt,
			Power = surge.Power,
			Element = surge.Element,
			Gem = surge.Gem,
		}
		duel.CastElement = surge.Element
		animate(duel, "Bolt", Brain.Windup.Bolt, nil, surge.Name)
	end
end

-- Uses one of its Rig Maneuvers (keys 1, 2, 3), like a player would.
local function useMove(enemy, duel, move, now: number, target: BasePart, dir: Vector3, side: Vector3, distance: number)
	local root, model = enemy.Root, enemy.Model
	move.Next = now + move.Cooldown
	model:SetAttribute("MoveReadyAt" .. move.Slot, workspace:GetServerTimeNow() + move.Cooldown)
	press(duel, tostring(move.Slot))
	Remotes.CombatFx:FireClient(duel.Owner, "TechStatus", duel.Name .. " uses " .. move.Name .. "!")
	face(root, target.Position)
	if move.Id == "StimDodge" then
		-- Dodge and patch up.
		local sign = if math.random() < 0.5 then 1 else -1
		local away = side * sign
		enemy.DodgeUntil = now + 0.35
		animate(duel, "Dodge", 0, sign)
		root.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 6, 0)
		fx("DodgeRoll", nil, root.Position, away, 8, true)
		healSelf(duel, move.Heal, move.Name)
		setStance(duel, "Dodge")
		return
	end
	if move.Id == "KineticRam" then
		-- Shoulder-charge in and strike on arrival.
		root.AssemblyLinearVelocity = dir * math.min(80, distance * 5) + Vector3.new(0, 4, 0)
		fx("DodgeRoll", nil, root.Position, dir, math.min(14, math.max(2, distance - 3)), false)
	end
	if move.Windup then
		fx("Nova", root.Position - Vector3.new(0, 2.5, 0), 4.5, Color3.fromRGB(255, 120, 60), move.Windup)
	end
	setStance(duel, if move.Windup then "Heavy" else "Maneuver")
	duel.CastElement = nil
	animate(duel, if move.Windup then "Heavy" else "Slash", move.Windup or 0.25, nil, move.Name)
	duel.Action = {
		Kind = "Move",
		Name = move.Name,
		At = now + (move.Windup or 0.25),
		Power = move.Power,
		Heavy = move.Windup ~= nil,
		Hits = move.Hits,
	}
end

-- Every 0.15s while the rival is alive.
local function think(enemy, now: number)
	local duel = enemy.Duel
	local owner = duel.Owner
	local root, humanoid = enemy.Root, enemy.Humanoid
	local fallen = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if fallen and fallen.Health <= 0 then
		Remotes.Notify:FireClient(owner, string.format("Defeated by %s. Enter the PvP Arena for a rematch.", duel.Name))
		Duelist.despawn(owner)
		return
	end
	local target = ownerRoot(owner)
	if not target or owner:GetAttribute("CombatSession") ~= duel.Session or not Combat.canFight(target.Position) then
		Duelist.despawn(owner)
		return
	end
	duel.Plate.Transparency = if enemy.GuardUntil and now < enemy.GuardUntil then 0.35 else 1
	local offset = flat(target.Position - root.Position)
	local distance = offset.Magnitude
	local dir = if distance > 0.01 then offset.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	humanoid.WalkSpeed = duel.Speed * (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
	local color = GemConfig.ElementColors[duel.Element] or Color3.fromRGB(255, 190, 80)

	-- A wind-up in progress: hold still, face the player, then strike.
	local action = duel.Action
	if action then
		if now < enemy.StunUntil then
			duel.Action = nil -- parried or stunned: the blow is lost
			duel.StaggeredFor = enemy.StunUntil
			animate(duel, "Stagger", 0)
			return
		end
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
		if now < action.At then
			return
		end
		duel.Action = nil
		local damage = duel.Damage * (1 - Enemies.weakness(enemy))
		if action.Kind == "Light" or action.Kind == "Heavy" or action.Kind == "Punish" or action.Kind == "Lunge" then
			local heavy = action.Kind == "Heavy"
			fx("Swing", nil, root.Position, dir, Brain.Reach, if heavy then 140 else 100, color, heavy)
			if distance <= Brain.Reach + 1.5 then
				-- Resonance Echo: its swings hit harder for a while.
				local echo = if now < (duel.EchoUntil or 0) then 1.5 else 1
				strike(
					duel,
					damage * (if heavy then 2 else 1) * echo,
					duel.Element,
					heavy,
					duel.WeaponGem,
					SWING_NAMES[action.Kind] or "Swing"
				)
			end
			-- Combos: up to three swings in a row.
			local hits = (action.Hits or 1) + 1
			if not heavy and hits <= 3 and math.random() < 0.65 then
				duel.Action = { Kind = "Light", At = now + 0.32, Hits = hits }
				animate(duel, "Slash", 0.32)
				press(duel, "LMB")
				return
			end
			setStance(duel, "")
			duel.NextAttack = now + duel.Rate * (0.8 + math.random() * 0.4)
		elseif action.Kind == "Bolt" then
			-- Fired at where the player stands now: step or roll aside and it misses.
			local from = root.Position + Vector3.new(0, 1.5, 0)
			local aim = target.Position
			fx("Shot", nil, from, aim, GemConfig.ElementColors[action.Element] or color, "Fireball")
			task.delay(math.clamp(distance / 140, 0.05, 0.5), function()
				local stillRoot = ownerRoot(owner)
				if duels[owner] ~= duel or not stillRoot then
					return
				end
				if Brain.boltHits(aim, stillRoot.Position) then
					strike(duel, damage * action.Power, action.Element, false, action.Gem, action.Name or "Bolt")
				else
					DamageLog.send(
						owner,
						{ Dir = "In", Kind = "Dodge", Who = duel.Name, Ability = action.Name, Element = action.Element }
					)
				end
			end)
			duel.NextAttack = now + 0.4
			setStance(duel, "")
		elseif action.Kind == "Move" then
			fx("Swing", nil, root.Position, dir, Brain.Reach + 1, 150, color, action.Heavy)
			if distance <= Brain.Reach + 2 then
				strike(
					duel,
					damage * action.Power,
					duel.Element,
					action.Heavy,
					duel.WeaponGem,
					action.Name or "Maneuver"
				)
			end
			if (action.Hits or 1) > 1 then
				-- Multi-hit maneuvers (Servo Flurry) strike again quickly.
				duel.Action =
					{ Kind = "Move", Name = action.Name, At = now + 0.2, Power = action.Power, Hits = action.Hits - 1 }
				animate(duel, "Slash", 0.2)
				return
			end
			duel.NextAttack = now + duel.Rate
			setStance(duel, "")
		elseif action.Kind == "Nova" then
			if (flat(target.Position - action.Center)).Magnitude <= action.Radius then
				strike(duel, damage * action.Power * 1.2, action.Element, false, action.Gem, action.Name or "Blast")
			end
			duel.NextAttack = now + 0.4
			setStance(duel, "")
		end
		return
	end

	-- Read the player: what they're doing and how they're doing.
	local foe = CombatServer._state(owner)
	local ownerHumanoid = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	local view = {
		Now = now,
		Distance = distance,
		HealthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth),
		Stunned = now < enemy.StunUntil,
		FoeCharging = foe ~= nil and foe.ChargeStarted ~= nil,
		FoeCasting = foe ~= nil and (#(foe.Pending or {}) > 0 or foe.Channel ~= nil),
		FoeBlocking = owner:GetAttribute("Blocking") == true,
		FoeRecovering = foe ~= nil and foe.NextAttack > now + 0.15 and foe.ChargeStarted == nil,
		FoeVulnerable = foe ~= nil and (now < foe.StunUntil or now < (foe.SlowUntil or 0)),
		FoeLow = ownerHumanoid ~= nil and ownerHumanoid.Health < ownerHumanoid.MaxHealth * 0.3,
		NextAttack = duel.NextAttack,
		NextSurge = duel.NextSurge,
		NextDefense = duel.NextDefense,
		NextRetreat = duel.NextRetreat,
		NextLunge = duel.NextLunge,
	}
	if (view.FoeCharging or view.FoeCasting) and distance <= Brain.Reach + 4 and now >= duel.NextDefense then
		duel.NextDefense = now + 1.6 -- considered: don't react to every swing
	end
	local choice = Brain.decide(view, math.random())
	if choice ~= "Stagger" and now >= duel.NextSurge and view.HealthRatio < 0.6 then
		for _, surge in duel.Surges do
			if surge.Kind == "Self" and now >= surge.Next then
				choice = "Surge"
				break
			end
		end
	end
	-- Like a player, it reaches for a maneuver (1, 2, 3) when one fits.
	local move = choice ~= "Stagger" and Brain.pickMove(duel.Moves, choice, now, distance, math.random())
	if move then
		humanoid:MoveTo(root.Position)
		useMove(enemy, duel, move, now, target, dir, side, distance)
		if choice == "Lunge" then
			duel.NextLunge = now + 4 + math.random() * 2
		end
		return
	end
	if choice == "Stagger" then
		humanoid:MoveTo(root.Position)
		if duel.StaggeredFor ~= enemy.StunUntil then
			duel.StaggeredFor = enemy.StunUntil -- reel once per stun
			animate(duel, "Stagger", 0)
		end
	elseif choice == "Guard" then
		enemy.GuardUntil, enemy.GuardMult = now + 0.9, 0.3
		enemy.Model:SetAttribute("GuardUntil", workspace:GetServerTimeNow() + 0.9)
		setStance(duel, "Guard")
		press(duel, "RMB")
		duel.NextAttack = math.max(duel.NextAttack, now + 0.9)
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	elseif choice == "Dodge" then
		local sign = if math.random() < 0.5 then 1 else -1
		local away = side * sign
		enemy.DodgeUntil = now + 0.35
		animate(duel, "Dodge", 0, sign)
		setStance(duel, "Dodge")
		press(duel, "SPACE")
		root.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 6, 0)
		fx("DodgeRoll", nil, root.Position, away, 8, true)
	elseif choice == "Punish" then
		duel.Action = { Kind = "Punish", At = now + Brain.Windup.Punish, Hits = 1 }
		animate(duel, "Slash", Brain.Windup.Punish)
		setStance(duel, "Counter")
		press(duel, "LMB")
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	elseif choice == "Lunge" then
		-- Dash in and swing as it arrives.
		duel.NextLunge = now + 4 + math.random() * 2
		root.AssemblyLinearVelocity = dir * math.min(80, distance * 5) + Vector3.new(0, 4, 0)
		fx("DodgeRoll", nil, root.Position, dir, math.min(14, distance - 3), false)
		duel.Action = { Kind = "Lunge", At = now + Brain.Windup.Lunge, Hits = 1 }
		animate(duel, "Slash", Brain.Windup.Lunge)
		setStance(duel, "Lunge")
		press(duel, "LMB")
		face(root, target.Position)
	elseif choice == "Surge" then
		local surge = Brain.pickSurge(duel.Surges, now, distance, view)
		if surge then
			castSurge(enemy, duel, surge, now, target)
		else
			duel.NextSurge = now + 1 -- nothing fits right now; look again soon
		end
	elseif choice == "Retreat" then
		duel.NextRetreat = now + 10
		duel.RetreatUntil = now + 1.2
	elseif choice == "Approach" then
		if now >= duel.NextWeave then
			duel.Weave, duel.NextWeave = -duel.Weave, now + 0.8 + math.random()
		end
		humanoid:MoveTo(target.Position - dir * 2 + side * duel.Weave * 1.5)
		face(root, target.Position)
	elseif choice == "Light" or choice == "Heavy" then
		local heavy = choice == "Heavy"
		duel.Action = { Kind = choice, At = now + Brain.Windup[choice], Hits = 1 }
		duel.CastElement = duel.Element
		animate(
			duel,
			if heavy then "Heavy" else "Slash",
			Brain.Windup[choice],
			nil,
			if heavy then "Heavy Blow" else nil
		)
		setStance(duel, if heavy then "Heavy" else "")
		press(duel, "LMB")
		if heavy then
			-- Telegraph: a warning ring at its feet before the blow lands.
			fx("Nova", root.Position - Vector3.new(0, 2.5, 0), 3.5, Color3.fromRGB(255, 120, 60), Brain.Windup.Heavy)
		end
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	else -- Strafe
		if duel.Stance == "Guard" or duel.Stance == "Dodge" or duel.Stance == "Surge" or duel.Stance == "Maneuver" then
			setStance(duel, "")
		end
		if now >= duel.NextWeave then
			duel.Weave, duel.NextWeave = -duel.Weave, now + 1 + math.random() * 1.2
		end
		local keep = if distance < 3 then -dir * 3 else Vector3.zero
		humanoid:MoveTo(root.Position + side * duel.Weave * 4 + keep)
		face(root, target.Position)
	end
	if duel.RetreatUntil and now < duel.RetreatUntil and not duel.Action then
		humanoid:MoveTo(root.Position - dir * 10)
	end
end

local function onWin(enemy)
	local duel = enemy.Duel
	local owner = duel.Owner
	duels[owner] = nil
	if not owner.Parent then
		return
	end
	local session = duel.Session
	if session == "Training" then
		-- Sparring: no rewards, just another partner.
		Remotes.Notify:FireClient(owner, string.format("Sparring won against %s. A new partner steps in…", duel.Name))
		task.delay(REMATCH_DELAY, function()
			if owner.Parent and owner:GetAttribute("CombatSession") == session and not duels[owner] then
				spawnRival(owner)
			end
		end)
		return
	end
	PlayerData.addCoins(owner, WIN_COINS)
	local profile = PlayerData.get(owner)
	if profile then
		profile.Stats.Kills += 1
	end
	Progress.addXP(owner, "SlayBrute")
	Remotes.Notify:FireClient(
		owner,
		string.format("Victory! You defeated %s: +%d coins. A new rival steps in…", duel.Name, WIN_COINS)
	)
	task.delay(REMATCH_DELAY, function()
		if owner.Parent and owner:GetAttribute("CombatSession") == session and not duels[owner] then
			spawnRival(owner)
		end
	end)
end

function spawnRival(owner: Player)
	if duels[owner] or starting[owner] then
		return
	end
	-- PvP brings a full-strength rival; Training a sparring partner that hits
	-- for half and gives no rewards.
	local session = owner:GetAttribute("CombatSession")
	if session ~= "PvP" and session ~= "Training" then
		return
	end
	local sparring = session == "Training"
	local root = ownerRoot(owner)
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = landmarks and landmarks:GetAttribute("ArenaFloor")
	local ownerLoadout = PlayerData.character(owner)
	if not root or typeof(center) ~= "Vector3" or not ownerLoadout then
		return
	end
	starting[owner] = true
	local rng = Random.new()
	local loadout = rollLoadout(rng)
	local name = NAMES[rng:NextInteger(1, #NAMES)]
	-- Across the floor from the player, facing them.
	local away = flat(center - root.Position)
	away = if away.Magnitude > 1 then away.Unit else Vector3.new(1, 0, 0)
	local spot = center + away * 18 + Vector3.new(0, 4, 0)
	local rig = buildRig(loadout, name, CFrame.lookAt(spot, Vector3.new(root.Position.X, spot.Y, root.Position.Z)))
	starting[owner] = nil
	if not rig or not owner.Parent or owner:GetAttribute("CombatSession") ~= session or duels[owner] then
		if rig then
			rig:Destroy()
		end
		return
	end
	-- Balance against the player: its health is about 16 of their basic hits,
	-- and each of its quick swings takes about 1/13 of their health, scaled by
	-- how its rolled gear compares with theirs.
	local mine, theirs = Classes.ratings(loadout), Classes.ratings(ownerLoadout)
	local weapon = Classes.weapon(ownerLoadout.Class, ownerLoadout.Weapon)
	local playerHit = (if weapon then weapon.Attack.Damage else 10) * Combat.powerMult(rating(theirs, "Power"))
	local toughness = math.clamp(rating(mine, "Health") / math.max(1, rating(theirs, "Health")), 0.8, 1.25)
	local strength = math.clamp(rating(mine, "Power") / math.max(1, rating(theirs, "Power")), 0.8, 1.25)
	local ownerHumanoid = owner.Character:FindFirstChildOfClass("Humanoid")
	local health = math.max(150, math.floor(playerHit * 16 * toughness))
	local kind = {
		Name = "Rival Duelist",
		Health = health,
		Damage = 0,
		Speed = 18,
		Reach = Brain.Reach,
		Rate = 0.8,
		Aggro = 0,
		Coins = WIN_COINS,
		DropChance = 0,
		Luck = 0,
		Respawn = 0,
	}
	local element = loadout.WeaponGem.Element
	local enemy = Enemies.adopt(rig, kind, {
		Element = element,
		Title = string.format("%s  ·  %s", name, GemConfig.elementName(element)),
		Home = spot,
	})
	enemy.Humanoid.AutoRotate = false
	-- Every bout starts even: the player steps in at full health too.
	if ownerHumanoid and ownerHumanoid.Health > 0 then
		ownerHumanoid.Health = ownerHumanoid.MaxHealth
	end
	-- Its own legs only: the stock Animate script doesn't run on a server rig.
	local animateScript = rig:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end
	animateLegs(enemy.Humanoid)
	local joints = RivalPose.jointCount(rig)
	if joints < 10 then
		warn(string.format("[Duelist] %s's rig has only %d of 10 poseable joints", name, joints))
	end
	local now = os.clock()
	local duel = {
		Enemy = enemy,
		Owner = owner,
		Name = name,
		Element = element,
		Plate = rig:FindFirstChild("GuardPlate"),
		WeaponGem = loadout.WeaponGem,
		Session = session,
		Damage = (if ownerHumanoid then ownerHumanoid.MaxHealth else 300) / 13 * strength * (if sparring
			then 0.5
			else 1),
		Speed = 18,
		Rate = if sparring then 1.1 else 0.8,
		Action = nil,
		NextAttack = now + 1.2,
		NextSurge = now + 3.5,
		Surges = {},
		Moves = {},
		NextDefense = now,
		NextRetreat = now + 8,
		NextLunge = now + 1,
		NextWeave = now,
		Weave = 1,
		RetreatUntil = 0,
	}
	enemy.Duel = duel
	-- Its loadout and surge, for the player's rival panel.
	local model = enemy.Model
	model:SetAttribute("RivalOwner", owner.UserId)
	model:SetAttribute("RivalName", name)
	model:SetAttribute("RivalElement", element)
	model:SetAttribute("RivalSparring", sparring)
	local gear, score = {}, 0
	for _, slot in Slots.Order do
		local item = Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		local roll = GearRolls.get(loadout, slot)
		for stat, amount in roll and roll.Stats or {} do
			score += if stat == "Critical" or stat == "Cooldown" then amount * 100 else amount
		end
		table.insert(gear, string.format("%s|%s|%d", slot, if item then item.Name else "?", roll and roll.Rarity or 1))
	end
	model:SetAttribute("RivalGear", table.concat(gear, ";"))
	model:SetAttribute("RivalScore", math.floor(score + 0.5))
	-- Its three surges (Q, E, R), each with its own cooldown.
	local names = {}
	for slot = 1, 3 do
		local gem = loadout["Surge" .. slot .. "Gem"]
		local id, tier, rank = Tech.surgeOf(gem)
		local stats = gem and Tech.surgeStats(gem)
		if id and stats then
			local surge = {
				Slot = slot,
				Id = id,
				Name = stats.Name,
				Icon = stats.Icon or "◆",
				Element = gem.Element,
				Gem = gem,
				Kind = if SELF_SURGES[id] then "Self" elseif stats.Radius then "Nova" else "Bolt",
				SelfCentered = stats.Self == true,
				Radius = math.clamp(stats.Radius or 7, 5, 10),
				Power = if stats.Damage then math.clamp(stats.Damage, 0.8, 2.4) else 1,
				Cooldown = 6 + tier * 1.5,
				Next = now + 2.5 + slot * 1.5,
			}
			table.insert(duel.Surges, surge)
			table.insert(names, surge.Name)
			model:SetAttribute("RivalSurge" .. slot, surge.Name)
			model:SetAttribute("RivalSurgeIcon" .. slot, surge.Icon)
			model:SetAttribute("RivalSurgeElement" .. slot, surge.Element)
			model:SetAttribute("RivalSurgeTier" .. slot, tier)
			model:SetAttribute("RivalSurgeRank" .. slot, rank)
			model:SetAttribute("SurgeCooldown" .. slot, surge.Cooldown)
			model:SetAttribute("SurgeReadyAt" .. slot, workspace:GetServerTimeNow() + (surge.Next - now))
		end
	end
	duel.NextSurge = nextSurgeTime(duel, now)
	-- Three Rig Maneuvers on 1, 2, 3, picked from the same list players learn.
	local pool = table.clone(Tech.Order.RigManeuvers)
	for slot = 1, math.min(3, #pool) do
		local id = table.remove(pool, rng:NextInteger(1, #pool))
		local stats = Tech.Catalog[id]
		local move = {
			Slot = slot,
			Id = id,
			Name = stats.Name,
			Power = stats.Damage or 0,
			Windup = stats.Windup,
			Heal = stats.Heal or 0,
			Hits = stats.Hits,
			Cooldown = math.clamp((stats.Recovery or 1) * 3, 3.5, 9),
			Next = now + 2 + slot,
		}
		table.insert(duel.Moves, move)
		model:SetAttribute("RivalMove" .. slot, move.Name)
		model:SetAttribute("RivalMoveIcon" .. slot, stats.Icon or "✦")
		model:SetAttribute("MoveCooldown" .. slot, move.Cooldown)
		model:SetAttribute("MoveReadyAt" .. slot, workspace:GetServerTimeNow() + (move.Next - now))
	end
	-- You vs it, for the player's matchup panel: the numbers each side really
	-- fights with, and each side's strengths and weaknesses.
	local yourSurges = {}
	for slot = 1, 3 do
		local gem = ownerLoadout["Surge" .. slot .. "Gem"]
		local id = gem and Tech.surgeOf(gem)
		local stats = gem and Tech.surgeStats(gem)
		if id and stats then
			table.insert(yourSurges, {
				Id = id,
				Name = stats.Name,
				Kind = if SELF_SURGES[id] then "Self" elseif stats.Radius then "Nova" else "Bolt",
			})
		end
	end
	local foeMoves = {}
	for _, move in duel.Moves do
		table.insert(foeMoves, move.Id)
	end
	local matchup = Matchup.build({
		Name = owner.DisplayName,
		Health = math.floor(ownerHumanoid and ownerHumanoid.MaxHealth or 300),
		Hit = math.floor(playerHit + 0.5),
		Speed = math.floor(ownerHumanoid and ownerHumanoid.WalkSpeed or 16),
		Element = ownerLoadout.WeaponGem and ownerLoadout.WeaponGem.Element,
		Surges = yourSurges,
		Moves = ownerLoadout.Maneuvers or Tech.DefaultManeuvers,
	}, {
		Name = name,
		Health = health,
		-- Its quick hit after your armor.
		Hit = math.floor(duel.Damage * Combat.defenseMult(rating(theirs, "Defense")) + 0.5),
		Speed = duel.Speed,
		Element = element,
		Surges = duel.Surges,
		Moves = foeMoves,
	})
	model:SetAttribute("Matchup", HttpService:JSONEncode(matchup))
	local surgeList = if #names > 0 then table.concat(names, ", ") else "no surges"
	enemy.Brain = think
	enemy.OnDeath = onWin
	duels[owner] = duel
	Remotes.Notify:FireClient(
		owner,
		if sparring
			then string.format("Sparring partner %s steps in (%s). Hits are softened.", name, surgeList)
			else string.format("%s enters the Arena with %s. Fight!", name, surgeList)
	)
end

function Duelist.start()
	-- Its fighting poses, every frame, bent on the server so every client sees them.
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for _, duel in duels do
			local ok, problem = pcall(RivalPose.update, duel.Enemy.Model, dt, now, os.clock())
			if not ok and not duel.PoseWarned then
				duel.PoseWarned = true
				warn("[Duelist] pose update failed: " .. tostring(problem))
			end
		end
	end)
	ArenaSessions.onEnter = function(player: Player, _pvp: boolean)
		task.wait(1.5) -- let the arrival protection settle first
		spawnRival(player)
	end
	ArenaSessions.onLeave = function(player: Player)
		Duelist.despawn(player)
	end
end

return Duelist
