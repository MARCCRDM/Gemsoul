local ArenaDrop = require(script.Parent.ArenaDrop)
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

	Party Raids (Duelist.startRaid, from Raids): the same fighter as a raid
	boss for a whole party, tougher for every raider and every wave
	(Shared.Matchmaking.Raid). It picks on one raider at a time (Owner, the
	nearest, kept a few seconds), turning on the next when they go down or
	leave. Clear a wave: everyone still standing is paid and a tougher boss
	steps in; lose everyone: the raid is over.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Brain = require(ReplicatedStorage.Shared.DuelistBrain)
local Aggro = require(ReplicatedStorage.Shared.Aggro)
local ElementCombos = require(ReplicatedStorage.Shared.ElementCombos)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local Matchup = require(ReplicatedStorage.Shared.Matchup)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local WeaponForge = require(ReplicatedStorage.Shared.WeaponForge)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local EquipmentBalance = require(ReplicatedStorage.Shared.EquipmentBalance)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local Lottery = require(ReplicatedStorage.Shared.StarterLottery)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
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

local DungeonLoadout = require(ReplicatedStorage.Shared.DungeonLoadout)
local BrainrotSkins = require(script.Parent.BrainrotSkins)
local ExpeditionAmbient = require(script.Parent.ExpeditionAmbient)
local Duelist = {}
local dungeonActors = {}

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

-- Counts a finished 1v1 against a rival (won or lost) in the player's duel
-- record: Played (every duel, rival or player; unlocks lobby modes) and
-- RivalWins. Player-vs-player Wins and Losses stay for the ranked boards.
local function duelsPlayed(owner: Player): number
	local profile = PlayerData.get(owner)
	local record = profile and profile.Duel :: any
	return if record then record.Played or 0 else 0
end
local function countDuel(owner: Player, won: boolean)
	local profile = PlayerData.get(owner)
	if not profile then
		return
	end
	profile.Duel = profile.Duel or { Rating = Matchmaking.StartRating, Wins = 0, Losses = 0, Streak = 0 }
	local record = profile.Duel :: any
	record.Played = (record.Played or 0) + 1
	if won then
		record.RivalWins = (record.RivalWins or 0) + 1
	end
	owner:SetAttribute("DuelsPlayed", record.Played)
	PlayerData.sync(owner)
end

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
		Character = { Class = "Warrior", Weapon = Classes.starterWeapon(class, rng).Id, Armor = class.Armors[1].Id },
		Owned = {},
	}
	Slots.initialize(profile)
	GearRolls.grant(profile, class, rng)
	local c = profile.Character
	c.WeaponQuality = c.WeaponQuality or 1
	c.ArmorQuality = c.ArmorQuality or 1
	-- Its gems come from the very lottery a new player spins
	-- (StarterLottery): a gem in every piece of gear and all three Surge
	-- slots, the four elements shuffled across them, cut 5-8, at least one
	-- better than Common. Rolled afresh for every rival.
	idCounter += 1
	local drawn = 0
	local spin = { Intro = {}, Character = c, Gems = {} }
	Lottery.prepare(spin, rng, function(element)
		drawn += 1
		local gem =
			GemGenerator.generate(rng, "StarterSpin", { Id = "duel-" .. idCounter .. "-" .. drawn, Time = os.time() })
		return GemRoller.setElement(gem, element)
	end)
	Lottery.finish(spin, math.huge)
	return c
end

-- The rival's body, built part by part: a standard R15 layout (the names
-- the armor and Roblox's walk/run animations expect) with rigid Motor6D
-- joints at exactly known spots and no rotation baked into them. Built by
-- hand rather than by Players:CreateHumanoidModelFromDescription so it can't
-- come out with loose physics joints or tilted joint frames (either one bends
-- poses the wrong way and leaves limbs and held gear looking detached).
-- Positions are relative to the root's centre; feet rest 1.9 studs below its
-- bottom (the HipHeight).
local BODY = {
	-- name, size, centre
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.2, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.2, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0) },
	{ "RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, -0.15, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -0.75, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.85, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, -0.15, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -0.75, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -0.9, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, -2.05, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.75, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -0.9, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, -2.05, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.75, 0) },
}
local JOINTS = {
	-- name, parent part, child part, joint position (relative to the root)
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 0, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 1.6, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.5, 1.35, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.5, 0.35, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.5, -0.6, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.5, 1.35, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.5, 0.35, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.5, -0.6, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, -0.3, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, -1.5, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, -2.6, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, -0.3, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, -1.5, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, -2.6, 0) },
}

local function buildBody(skin: Color3): Model
	local rig = Instance.new("Model")
	local parts = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = rig
	parts.HumanoidRootPart = root
	rig.PrimaryPart = root
	for _, spec in BODY do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = CFrame.new(spec[3])
		part.Color = skin
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CanCollide = spec[1] == "UpperTorso" or spec[1] == "LowerTorso" or spec[1] == "Head"
		part.Parent = rig
		parts[spec[1]] = part
	end
	for _, spec in JOINTS do
		local part0, part1 = parts[spec[2]], parts[spec[3]]
		local at = CFrame.new(spec[4])
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0, motor.Part1 = part0, part1
		motor.C0 = part0.CFrame:Inverse() * at
		motor.C1 = part1.CFrame:Inverse() * at
		motor.Parent = part1
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 1.9
	humanoid.AutomaticScalingEnabled = false
	humanoid.Parent = rig
	Instance.new("Animator").Parent = humanoid
	return rig
end

-- An R15 rig in the rival's gear, standing at `at`.
local function buildRig(loadout, name: string, at: CFrame): Model?
	local skin = Color3.fromHSV(0.06 + math.random() * 0.05, 0.25 + math.random() * 0.35, 0.45 + math.random() * 0.5)
	local ok, rig = pcall(buildBody, skin)
	if not ok or not rig then
		warn("Duelist rig failed:", rig)
		return nil
	end
	rig.Name = name
	-- Stream the whole body at once, so clients can pose its joints.
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	rig:PivotTo(at)
	-- Its arms are posed (RivalPose), so it holds the sword in its fist.
	rig:SetAttribute("FistGrip", true)
	Equipment.dressModel(rig, loadout, math.random(1, 1e6))
	return rig
end

function Duelist.despawn(owner: Player)
	for enemy, actor in dungeonActors do
		if actor.Raid and actor.Raid.Dungeon and table.find(actor.Raid.Members, owner) then
			local index = table.find(actor.Raid.Members, owner)
			table.remove(actor.Raid.Members, index)
			if #actor.Raid.Members == 0 then
				dungeonActors[enemy] = nil
				Enemies.remove(enemy)
			end
		end
	end
	local duel = duels[owner]
	duels[owner] = nil
	-- A raider leaving: the boss fights on while anyone's left.
	if duel and duel.Raid then
		local index = table.find(duel.Raid.Members, owner)
		if index then
			table.remove(duel.Raid.Members, index)
		end
		if #duel.Raid.Members > 0 then
			return
		end
	end
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

-- A raid boss: drops raiders who are down or gone and picks who it's after
-- (Owner) by threat (Shared.Aggro). False when nobody's left (the raid is over).
local function raidTarget(duel, now: number): boolean
	local raid = duel.Raid
	for i = #raid.Members, 1, -1 do
		local member = raid.Members[i]
		local _, humanoid = ownerRoot(member)
		if
			not member.Parent
			or not humanoid
			or member:GetAttribute("RaidId") ~= raid.Id
			or member:GetAttribute("CombatSession") ~= "Raid"
		then
			table.remove(raid.Members, i)
			if duels[member] == duel then
				duels[member] = nil
			end
			for _, other in raid.Members do
				Remotes.Notify:FireClient(other, member.DisplayName .. " is down!")
			end
		end
	end
	if #raid.Members == 0 then
		for _, member in raid.All do
			if member.Parent then
				member:SetAttribute("RaidId", nil)
				Remotes.Notify:FireClient(
					member,
					string.format("The raid fell to %s on wave %d. Regroup and try again!", duel.Name, raid.Wave)
				)
			end
		end
		if duel.Enemy.Alive then
			Enemies.remove(duel.Enemy)
		end
		return false
	end
	-- Shared.Aggro decides: whoever is hurting it most (overtaking by 10% up
	-- close, 30% from range), a raider low on health, or the nearest one it
	-- can reach when its target keeps out of reach. Raid time is server time.
	local enemy = duel.Enemy
	local clock = os.clock()
	Aggro.fade(enemy.Threat, enemy.ThreatAt, clock - (enemy.LastThink or clock), clock)
	enemy.LastThink = clock
	local root = enemy.Root
	local candidates = {}
	for _, member in raid.Members do
		local memberRoot, humanoid = ownerRoot(member)
		if memberRoot and humanoid then
			local distance = (memberRoot.Position - root.Position).Magnitude
			table.insert(candidates, {
				Key = member,
				Threat = enemy.Threat[member] or 0,
				Distance = distance,
				InReach = distance <= Brain.Reach + 1.5,
				HealthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth),
			})
		end
	end
	if enemy.Aggro.Target == nil and table.find(raid.Members, duel.Owner) then
		enemy.Aggro.Target, enemy.Aggro.Since = duel.Owner, clock
	end
	local best = Aggro.choose(enemy.Aggro, candidates, clock) or raid.Members[1]
	if best ~= duel.Owner then
		duel.Owner = best
		enemy.Model:SetAttribute("RivalOwner", best.UserId)
		Remotes.CombatFx:FireClient(best, "TechStatus", duel.Name .. " turns on you!")
	end
	return true
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
	model:SetAttribute("ActionHold", nil)
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

-- Turns it toward `target`. With its FaceAlign constraint it turns smoothly
-- (physics, every frame) instead of snapping on each think tick.
local function face(root: BasePart, target: Vector3)
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
-- `critChance` rolls a critical (1.6x, shown as CRIT and in the log), by
-- the same chances a player's attacks have.
function strike(duel, amount: number, element: string?, heavy: boolean?, gem, ability: string, critChance: number?)
	local e = duel.Enemy :: any
	if os.clock() < (e.BlindUntil or 0) and (e.Blind or 0) > 0 and math.random() <= e.Blind then
		-- Blinded (your Solar Flare): the blow goes wide.
		DamageLog.send(duel.Owner, { Dir = "In", Kind = "Miss", Who = duel.Name, Ability = ability, Element = element })
		return 0, false
	end
	local crit = math.random() < (critChance or 0)
	if crit then
		amount *= Combat.CritMult
	end
	-- Its weapon's perk, by the same rules as yours (Shared.WeaponForge).
	local effects = duel.Kit and duel.Kit.Effects
	if effects then
		local _, ownerHumanoid = ownerRoot(duel.Owner)
		amount *= WeaponForge.multiplier(effects, {
			Heavy = heavy == true,
			Crit = crit,
			Combo = 1,
			TargetRatio = if ownerHumanoid then ownerHumanoid.Health / math.max(1, ownerHumanoid.MaxHealth) else 1,
			OwnRatio = e.Humanoid.Health / math.max(1, e.Humanoid.MaxHealth),
			Versus = true,
			TargetGuarding = duel.Owner:GetAttribute("Blocking") == true,
		})
	end
	-- Element combos on you, as yours land on it (Shared.ElementCombos).
	local _, combo =
		ElementCombos.check({ Element = element, Heavy = heavy == true }, CombatServer.comboFlags(duel.Owner))
	if combo then
		amount *= combo.Mult or 1
	end
	local previous = DamageLog.push(ability, element)
	local dealt, guarded = Enemies.hitPlayer(duel.Owner, amount, element, duel.Enemy, heavy, crit)
	DamageLog.pop(previous)
	if combo and type(dealt) == "number" and dealt > 0 then
		CombatServer.comboOnPlayer(duel.Owner, combo, duel.Enemy)
	end
	if type(dealt) == "number" and dealt > 0 and not guarded and gem then
		CombatServer.enemyProc(duel.Owner, gem, duel.Enemy)
	end
	-- Siphon Edge: its weapon heals it too.
	if effects and effects.Lifesteal and type(dealt) == "number" and dealt > 0 and e.Alive then
		e.Humanoid.Health = math.min(e.Humanoid.MaxHealth, e.Humanoid.Health + dealt * effects.Lifesteal)
	end
	return dealt, guarded
end

-- What a landed surge carries besides damage (Blind, Slow), as a player's does.
local function ridersOf(stats)
	if not (stats.Blind or stats.Slow) then
		return nil
	end
	return { Blind = stats.Blind, BlindTime = stats.BlindTime, Slow = stats.Slow, SlowTime = stats.SlowTime }
end

-- Heals itself (anti-heal applies) and tells its player in the combat log.
local function healSelf(duel, share: number, ability: string)
	local enemy = duel.Enemy
	local humanoid = enemy.Humanoid
	local full = humanoid.MaxHealth * share
	local healing = full * Enemies.healingMultiplier(enemy) * (duel.Kit and duel.Kit.Effects.HealingReceived or 1)
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
	duel.CastElement = surge.Element
	if surge.Kind == "Self" then
		animate(duel, surge.Pose, surge.CastTime, nil, surge.Name)
		duel.Action = { Kind = "Buff", Name = surge.Name, At = now + surge.CastTime, Surge = surge }
		return
	end
	if surge.Kind == "Nova" then
		-- A blast with a warning ring: under the player, or around itself.
		local center = if surge.SelfCentered then root.Position else target.Position
		fx("Nova", center - Vector3.new(0, 2.5, 0), surge.Radius, color, surge.CastTime)
		animate(duel, surge.Pose, surge.CastTime, nil, surge.Name)
		duel.Action = {
			Kind = "Nova",
			Name = surge.Name,
			At = now + surge.CastTime,
			Center = center,
			Radius = surge.Radius,
			Power = surge.Power,
			Crit = surge.Crit,
			Element = surge.Element,
			Gem = surge.Gem,
			Cloud = surge.Cloud,
			Riders = surge.Riders,
			Ward = surge.Ward,
			Leech = surge.Leech,
		}
	else
		fx("TechPulse", nil, root.Position, root.Position, color, 3)
		duel.Action = {
			Kind = if surge.Cast == "Channel" then "Channel" else "Bolt",
			Name = surge.Name,
			At = now + surge.CastTime,
			Power = surge.Power,
			Crit = surge.Crit,
			Element = surge.Element,
			Gem = surge.Gem,
			Range = surge.Range,
			Cost = surge.Cost,
			Riders = surge.Riders,
		}
		animate(duel, surge.Pose, surge.CastTime, nil, surge.Name)
	end
end

-- A self surge lands when its cast completes, exactly as a player's: Cryo
-- Shield and Energy Siphon are shields that soak damage; Resonance Echo
-- repeats its hits.
local function applyBuff(enemy, duel, surge, now: number)
	local root = enemy.Root
	local color = GemConfig.ElementColors[surge.Element] or P_GOLD
	fx("TechPulse", nil, root.Position, root.Position, color, 5)
	local stats = Tech.surgeStats(surge.Gem) or {}
	local duration = stats.Duration or 4
	if surge.Id == "CryoShield" then
		local amount = 30 + (surge.Gem and surge.Gem.Size or 1) * 3
		enemy.Shield = math.max(enemy.Shield or 0, amount)
		enemy.ShieldUntil = math.max(enemy.ShieldUntil or 0, now + duration)
		duel.CryoUntil = now + duration
	elseif surge.Id == "EnergySiphon" then
		enemy.Shield = math.max(enemy.Shield or 0, stats.Absorb or 0)
		enemy.ShieldUntil = math.max(enemy.ShieldUntil or 0, now + duration)
	else -- ResonanceEcho
		duel.EchoUntil = now + duration
	end
end

-- How long it holds a beam (a player holds the key; it pours for this long,
-- or until its Charge runs dry or the player steps out of reach).
local CHANNEL_HOLD = 1.5

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
		enemy.DodgeUntil = now + Actions.Base.Hop.PvPInvincible
		animate(duel, "Dodge", 0, sign)
		root.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 6, 0)
		fx("DodgeRoll", nil, root.Position, away, 8, true)
		healSelf(duel, move.Heal, move.Name)
		setStance(duel, "Dodge")
		return
	end
	if move.Riposte then
		-- Riposte Stance: braced; your next blow is turned aside (CombatServer).
		local e = enemy :: any
		e.RiposteUntil = now + move.Riposte
		e.RiposteDamage = duel.Damage * (move.CounterDamage or 1)
		model:SetAttribute("GuardUntil", workspace:GetServerTimeNow() + move.Riposte)
		setStance(duel, "Riposte")
		return
	end
	if move.Leap then
		-- Thruster Leap: airborne at you, landing on its wind-up.
		root.AssemblyLinearVelocity = dir
				* math.min(move.Leap / (move.Windup or 0.4), math.max(10, distance - 3) / (move.Windup or 0.4))
			+ Vector3.new(0, 18, 0)
		fx("DodgeRoll", nil, root.Position, dir, math.min(move.Leap, math.max(2, distance - 3)), false)
	end
	if move.Id == "KineticRam" then
		-- Shoulder-charge in and strike on arrival.
		root.AssemblyLinearVelocity = dir * math.min(80, distance * 5) + Vector3.new(0, 4, 0)
		fx("DodgeRoll", nil, root.Position, dir, math.min(14, math.max(2, distance - 3)), false)
	end
	if move.Windup and not move.Leap then
		fx("Nova", root.Position - Vector3.new(0, 2.5, 0), 4.5, Color3.fromRGB(255, 120, 60), move.Windup)
	end
	setStance(duel, if move.Windup then "Heavy" else "Maneuver")
	duel.CastElement = nil
	-- Same timing as a player's (Actions.castTime): a heavy maneuver's own
	-- wind-up, otherwise a quick move.
	local castTime = move.Windup or Actions.CastTime.Move
	animate(duel, if move.Windup then "Heavy" else "Slash", castTime, nil, move.Name)
	duel.Action = {
		Kind = "Move",
		Name = move.Name,
		At = now + castTime,
		Power = move.Power,
		Crit = move.Crit,
		Heavy = move.Heavy,
		Hits = move.Hits,
		Interrupt = move.Interrupt,
	}
end

-- Its Stamina and Charge, refilled by the same rules as a player's: Stamina
-- pauses after a spend and drains while its guard is up; Charge refills
-- steadily (CombatTechnology.Resources, CombatActions.Stamina).
local function refill(duel, now: number, guardUp: boolean)
	local elapsed = math.clamp(now - (duel.ResourceAt or now), 0, 1)
	duel.ResourceAt = now
	local staminaRule, chargeRule = Tech.Resources.Stamina, Tech.Resources.Charge
	local regen = if guardUp
		then -Actions.Stamina.GuardDrain
		elseif now < (duel.StaminaRestUntil or 0) then 0
		else staminaRule.Regen
	duel.Stamina = math.clamp((duel.Stamina or staminaRule.Max) + regen * elapsed, 0, staminaRule.Max)
	duel.Charge = math.clamp((duel.Charge or chargeRule.Max) + chargeRule.Regen * elapsed, 0, chargeRule.Max)
	duel.Enemy.Model:SetAttribute("RivalStamina", math.floor(duel.Stamina))
	duel.Enemy.Model:SetAttribute("RivalCharge", math.floor(duel.Charge))
end
local function spendStamina(duel, amount: number)
	duel.Stamina = math.max(0, (duel.Stamina or 0) - amount)
	duel.StaminaRestUntil = os.clock() + Actions.Stamina.RegenDelay
end

-- Its own guard (not a Cryo Shield barrier, which only halves hits).
local function guarding(enemy, now: number): boolean
	return enemy.GuardUntil ~= nil and now < enemy.GuardUntil and not enemy.Barrier
end

-- Raises (or keeps up) its guard for `seconds`. Freshly raised, a swing that
-- lands right away is parried (see Enemies.damage).
local function raiseGuard(enemy, duel, now: number, seconds: number)
	if not guarding(enemy, now) then
		if (duel.Stamina or 0) < Actions.Stamina.BlockMin or now < (enemy.GuardBrokenUntil or 0) then
			return -- too winded to raise a guard, like a player
		end
		-- Freshly raised: a parry window, at most every 1.5s (as a player's
		-- high block), and its block gem fires (shield, cleanse).
		enemy.ParrySpent = false
		if now >= (duel.NextHighBlock or 0) then
			enemy.GuardRaisedAt = now
			duel.NextHighBlock = now + 1.5
		end
		local kit = duel.Kit
		if kit and now >= (duel.NextBlockGem or 0) then
			local defense = kit.Defense
			if defense.CleanseInterval < math.huge then
				enemy.Dots, enemy.SlowUntil, enemy.SunderUntil = {}, 0, 0
			end
			if defense.Shield > 0 then
				enemy.Shield = math.max(enemy.Shield or 0, defense.Shield)
				enemy.ShieldUntil = now + defense.Duration
			end
			duel.NextBlockGem = now + defense.Duration + defense.Cooldown
		end
		press(duel, "RMB")
	end
	-- A guard takes off what a player's PvP block does, with its own set's rules.
	enemy.Barrier = nil
	enemy.GuardUntil = math.max(enemy.GuardUntil or 0, now + seconds)
	enemy.GuardMult = Actions.blockMultiplier(
		if duel.Kit then duel.Kit.Rules else Actions.resolve({}, "Sword", 0),
		true,
		1,
		false,
		false
	)
	enemy.Model:SetAttribute("GuardUntil", workspace:GetServerTimeNow() + (enemy.GuardUntil - now))
	setStance(duel, "Guard")
end

-- Lowers its guard to attack or cast.
local function dropGuard(enemy, now: number)
	if guarding(enemy, now) then
		enemy.GuardUntil = 0
		enemy.Model:SetAttribute("GuardUntil", 0)
	end
end

-- Every 0.15s while the rival is alive.
local function think(enemy, now: number)
	local duel = enemy.Duel
	if (enemy.Model:GetAttribute("ArenaDropUntil") or 0) > workspace:GetServerTimeNow() then
		return
	end
	if duel.Dungeon and duel.Dungeon.OpenWorld and ExpeditionAmbient.step(duel, now) then
		return
	end
	if duel.Raid and not raidTarget(duel, now) then
		return
	end
	local owner = duel.Owner
	local root, humanoid = enemy.Root, enemy.Humanoid
	local fallen = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	if fallen and fallen.Health <= 0 then
		if not duel.Raid and not duel.Dungeon then
			countDuel(owner, false)
		end
		Remotes.Notify:FireClient(owner, string.format("Defeated by %s. Enter the PvP Arena for a rematch.", duel.Name))
		Duelist.despawn(owner)
		return
	end
	local target = ownerRoot(owner)
	if not target or owner:GetAttribute("CombatSession") ~= duel.Session or not Combat.canFight(target.Position) then
		Duelist.despawn(owner)
		return
	end
	local offset = flat(target.Position - root.Position)
	local distance = offset.Magnitude
	local dir = if distance > 0.01 then offset.Unit else Vector3.new(0, 0, -1)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	refill(duel, now, guarding(enemy, now))
	local kit = duel.Kit
	if kit then
		-- Ward armour: a fresh shield every 8 seconds, as a player's.
		if kit.Effects.Ward and now >= (duel.NextWard or 0) then
			duel.NextWard = now + 8
			enemy.Shield = math.max(enemy.Shield or 0, kit.Effects.Ward)
			enemy.ShieldUntil = now + 8
		end
		-- A Corrosive aura gem shreds you while it blocks close by.
		local ownerRootPart = ownerRoot(owner)
		if
			kit.Defense.Aura > 0
			and guarding(enemy, now)
			and ownerRootPart
			and (ownerRootPart.Position - root.Position).Magnitude <= GemConfig.Rules.AuraRadius
		then
			CombatServer.rivalAura(owner, kit.Defense.Aura)
		end
	end
	if guarding(enemy, now) and duel.Stamina <= 0 then
		dropGuard(enemy, now) -- held until there was nothing left
	end
	-- A blow it takes on its guard costs Stamina; one it can't pay for breaks
	-- the guard (Enemies.damage asks), just as for a player.
	enemy.GuardCost = enemy.GuardCost
		or function(amount: number): boolean
			local cost = math.max(Actions.Stamina.BlockMin, amount * Actions.Stamina.BlockPerDamage)
			if duel.Stamina >= cost then
				spendStamina(duel, cost)
				return true
			end
			spendStamina(duel, duel.Stamina)
			return false
		end
	humanoid.WalkSpeed = duel.Speed
		* (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
		* (if guarding(enemy, now) then 0.7 else 1) -- a shield-walk
	local color = GemConfig.ElementColors[duel.Element] or Color3.fromRGB(255, 190, 80)

	-- Its lingering pools (Toxic Cloud) tick on the player standing in them.
	for i = #(duel.Zones or {}), 1, -1 do
		local zone = duel.Zones[i]
		if now >= zone.Until then
			table.remove(duel.Zones, i)
		elseif now >= zone.Next then
			zone.Next += zone.Every
			fx("TechPulse", nil, zone.Center, zone.Center, GemConfig.ElementColors[zone.Element] or color, zone.Radius)
			if flat(target.Position - zone.Center).Magnitude <= zone.Radius then
				local dealt, guarded = strike(
					duel,
					duel.Damage * (1 - Enemies.weakness(enemy)) * zone.Power,
					zone.Element,
					false,
					zone.Gem,
					zone.Name,
					nil
				)
				if type(dealt) == "number" and dealt > 0 and not guarded and zone.Shred then
					CombatServer.sunder(owner, zone.Shred, zone.Every * 2)
				end
				if zone.Leech and type(dealt) == "number" and dealt > 0 then
					-- It drinks part of what its pool deals (anti-heal applies).
					local humanoid = enemy.Humanoid
					humanoid.Health = math.min(
						humanoid.MaxHealth,
						humanoid.Health + dealt * zone.Leech * Enemies.healingMultiplier(enemy)
					)
				end
			end
		end
	end

	-- A held beam (Cryo Stream): rooted, it pours a quarter-second at a time,
	-- billing Charge as a player's does.
	local channel = duel.Channel
	if channel then
		if now < enemy.StunUntil or now >= channel.Until or distance > channel.Range + 2 then
			duel.Channel = nil
			enemy.Model:SetAttribute("ActionHold", nil)
			setStance(duel, "")
			duel.NextAttack = now + 0.4
		else
			humanoid:MoveTo(root.Position)
			face(root, target.Position)
			if now >= channel.Next then
				if duel.Charge < channel.Cost * 0.25 then
					channel.Until = now
				else
					duel.Charge -= channel.Cost * 0.25
					channel.Next = now + 0.25
					local from = root.Position + Vector3.new(0, 1.5, 0)
					fx("TechPulse", nil, from, target.Position, GemConfig.ElementColors[channel.Element] or color, 0)
					local dealt, guarded = strike(
						duel,
						duel.Damage * (1 - Enemies.weakness(enemy)) * channel.Power * 0.25,
						channel.Element,
						false,
						channel.Gem,
						channel.Name,
						channel.Crit
					)
					if channel.Riders and type(dealt) == "number" and dealt > 0 and not guarded then
						CombatServer.afflict(owner, channel.Riders)
					end
				end
			end
			return
		end
	end

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
			-- Stamina, as a player's: a heavy it can't afford comes out light,
			-- a light swing it can't afford lands winded.
			if heavy and duel.Stamina < Actions.swingCost(duel.Weapon, true) then
				heavy = false
			end
			local cost = Actions.swingCost(duel.Weapon, heavy)
			local winded = duel.Stamina < cost
			spendStamina(duel, cost)
			fx("Swing", nil, root.Position, dir, Brain.Reach, if heavy then 140 else 100, color, heavy)
			if distance <= Brain.Reach + 1.5 then
				local rules = duel.Kit and duel.Kit.Rules
				local blow = damage
					* (if heavy
						then (rules and rules.HeavyPvPDamage or Actions.Base.Heavy.PvPDamage)
						else (rules and rules.BasicDamage or 1))
					* (if winded then Actions.Stamina.WindedDamage else 1)
				local dealt, guarded = strike(
					duel,
					blow,
					duel.Element,
					heavy,
					duel.WeaponGem,
					SWING_NAMES[action.Kind] or "Swing",
					-- Crits by its Speed, as yours are (heavies a little more).
					math.min(0.75, (duel.Crit or 0) + (if heavy then duel.HeavyCrit or 0 else 0))
				)
				if type(dealt) == "number" and dealt > 0 and not guarded then
					-- Landing its weapon builds its Charge, as yours does.
					local chargeRule = Tech.Resources.Charge
					duel.Charge = math.min(
						chargeRule.Max,
						(duel.Charge or 0) + (if heavy then chargeRule.OnHeavy else chargeRule.OnHit)
					)
					-- Its gear's on-hit effects (Sunder, Slow), as yours land.
					if duel.Kit then
						CombatServer.rivalHitEffects(owner, duel.Kit.Effects)
					end
					-- Resonance Echo repeats the hit, as a player's does.
					if now < (duel.EchoUntil or 0) then
						strike(duel, blow, duel.Element, false, nil, "Resonance Echo")
					end
				end
			end
			-- Combos: up to three swings in a row.
			local hits = (action.Hits or 1) + 1
			-- (A counter is a single blow.)
			if not heavy and action.Kind ~= "Punish" and hits <= 3 and math.random() < 0.65 then
				-- The next swing of the combo at a player's swing pace.
				local gap = duel.SwingCooldown or Actions.Base.Basic.SwordCooldown
				duel.Action = { Kind = "Light", At = now + gap, Hits = hits }
				animate(duel, "Slash", gap)
				press(duel, "LMB")
				return
			end
			setStance(duel, "")
			-- After a counter it presses straight on.
			local pace = if action.Kind == "Punish" then 0.5 else 1
			duel.NextAttack = now + duel.Rate * pace * (0.8 + math.random() * 0.4)
		elseif action.Kind == "Bolt" then
			-- Fired at where the player stands now: step or roll aside and it misses.
			local from = root.Position + Vector3.new(0, 1.5, 0)
			local aim = target.Position
			fx("Shot", nil, from, aim, GemConfig.ElementColors[action.Element] or color, "Fireball")
			task.delay(math.clamp(distance / 140, 0.05, 0.5), function()
				local stillRoot = ownerRoot(owner)
				if (not duel.Dungeon and duels[owner] ~= duel) or not enemy.Alive or not stillRoot then
					return
				end
				if Brain.boltHits(aim, stillRoot.Position) then
					local dealt, guarded = strike(
						duel,
						damage * action.Power,
						action.Element,
						false,
						action.Gem,
						action.Name or "Bolt",
						action.Crit
					)
					if action.Riders and type(dealt) == "number" and dealt > 0 and not guarded then
						CombatServer.afflict(owner, action.Riders)
					end
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
				local dealt = strike(
					duel,
					damage * action.Power,
					duel.Element,
					action.Heavy,
					duel.WeaponGem,
					action.Name or "Maneuver",
					action.Crit
				)
				if action.Interrupt and type(dealt) == "number" and dealt > 0 then
					CombatServer.interrupt(owner, action.Interrupt)
				end
			end
			if (action.Hits or 1) > 1 then
				-- Multi-hit maneuvers (Servo Flurry) strike again quickly.
				duel.Action = {
					Kind = "Move",
					Name = action.Name,
					At = now + 0.2,
					Power = action.Power,
					Crit = action.Crit,
					Hits = action.Hits - 1,
				}
				animate(duel, "Slash", 0.2)
				return
			end
			duel.NextAttack = now + duel.Rate
			setStance(duel, "")
		elseif action.Kind == "Buff" then
			applyBuff(enemy, duel, action.Surge, now)
			duel.NextAttack = now + 0.3
			setStance(duel, "")
		elseif action.Kind == "Channel" then
			-- The beam starts pouring (its first tick lands now).
			duel.Channel = {
				Name = action.Name,
				Until = now + CHANNEL_HOLD,
				Next = now,
				Range = action.Range or Brain.SurgeRange,
				Cost = action.Cost or 0,
				Power = action.Power,
				Crit = action.Crit,
				Element = action.Element,
				Gem = action.Gem,
				Riders = action.Riders,
			}
			duel.Charge += (action.Cost or 0) * 0.25 -- (the cast already billed this first tick)
			enemy.Model:SetAttribute("ActionHold", workspace:GetServerTimeNow() + CHANNEL_HOLD)
		elseif action.Kind == "Nova" then
			-- The closer to the centre, the harder: full damage and a stun at
			-- the core, a stagger in the middle, a glancing hit at the edge.
			-- (A lingering pool lands evenly and then keeps ticking.)
			local distance = flat(target.Position - action.Center).Magnitude
			if action.Ward then
				-- Its barrier rises as the cast lands (Burning Ward, Static Shell).
				local ward, e = action.Ward, enemy :: any
				local size = action.Gem and action.Gem.Size or 1
				enemy.Shield = math.max(enemy.Shield or 0, ward.Shield + size * 3)
				enemy.ShieldUntil = math.max(enemy.ShieldUntil or 0, now + ward.Duration)
				e.WardUntil, e.WardKind, e.WardNext = now + ward.Duration, ward.Kind, 0
				e.WardPower, e.WardStun = duel.Damage * (ward.Power or 0), ward.Stun
			end
			if action.Cloud then
				duel.Zones = duel.Zones or {}
				table.insert(duel.Zones, {
					Name = action.Name,
					Center = action.Center,
					Radius = action.Radius,
					Every = action.Cloud.Every,
					Next = now + action.Cloud.Every,
					Until = now + action.Cloud.Duration,
					Power = action.Cloud.Damage,
					Shred = action.Cloud.Shred,
					Leech = action.Leech,
					Element = action.Element,
					Gem = action.Gem,
				})
			end
			if distance <= action.Radius then
				local scale, cc, seconds = 1, nil, 0
				if not action.Cloud then
					scale, cc, seconds = Actions.blastFalloff(distance, action.Radius)
				end
				local dealt, guarded = strike(
					duel,
					damage * action.Power * scale,
					action.Element,
					false,
					action.Gem,
					action.Name or "Blast",
					action.Crit
				)
				if action.Riders and type(dealt) == "number" and dealt > 0 and not guarded then
					CombatServer.afflict(owner, action.Riders)
				end
				if type(dealt) == "number" and dealt > 0 and cc then
					if guarded then
						-- A raised guard takes it down a step.
						cc, seconds = if cc == "Stunned" then "Staggered" else nil, 0.4
					end
					if cc then
						CombatServer.blastCC(
							owner,
							cc,
							seconds,
							action.Center,
							if cc == "Stunned" then Actions.Blast.Knockback else 0
						)
					end
				end
			end
			duel.NextAttack = now + 0.4
			setStance(duel, "")
		end
		return
	end

	-- Read the player: what they're doing and how they're doing.
	local foe = CombatServer._state(owner)
	local ownerHumanoid = owner.Character and owner.Character:FindFirstChildOfClass("Humanoid")
	-- How hard the player is pressing: their swings in the last few seconds.
	duel.FoeSwings = duel.FoeSwings or {}
	if foe and foe.NextAttack ~= duel.LastFoeNext then
		duel.LastFoeNext = foe.NextAttack
		if foe.NextAttack > now then
			table.insert(duel.FoeSwings, now)
		end
	end
	while duel.FoeSwings[1] and now - duel.FoeSwings[1] > 2.5 do
		table.remove(duel.FoeSwings, 1)
	end
	local lastSwing = duel.FoeSwings[#duel.FoeSwings]
	-- Are you doing anything? Not swinging, blocking, charging or casting
	-- for a moment: it presses the attack instead of waiting on you.
	local foeBusy = (lastSwing ~= nil and now - lastSwing < 1)
		or owner:GetAttribute("Blocking") == true
		or (foe ~= nil and (foe.ChargeStarted ~= nil or #(foe.Pending or {}) > 0 or foe.Channel ~= nil))
	if foeBusy or not duel.FoeIdleSince then
		duel.FoeIdleSince = if foeBusy then nil else now
	end
	local view = {
		Now = now,
		Distance = distance,
		HealthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth),
		Stunned = now < enemy.StunUntil,
		FoeCharging = foe ~= nil and foe.ChargeStarted ~= nil,
		FoeHeavy = foe ~= nil
			and foe.ChargeStarted ~= nil
			and now - foe.ChargeStarted >= Actions.Base.Heavy.Charge - 0.1,
		FoeAttacking = lastSwing ~= nil and now - lastSwing < 0.5,
		FoeAggressive = #duel.FoeSwings >= 2,
		FoeRanged = duel.FoeRanged == true,
		GuardBroken = now < (enemy.GuardBrokenUntil or 0),
		Guarding = guarding(enemy, now),
		JustBlocked = enemy.BlockedAt ~= nil and now - enemy.BlockedAt < 0.5 and duel.RiposteFor ~= enemy.BlockedAt,
		FoeCasting = foe ~= nil and (#(foe.Pending or {}) > 0 or foe.Channel ~= nil),
		FoeBlocking = owner:GetAttribute("Blocking") == true,
		FoeRecovering = foe ~= nil and foe.NextAttack > now + 0.15 and foe.ChargeStarted == nil,
		FoeVulnerable = foe ~= nil and (now < foe.StunUntil or now < (foe.SlowUntil or 0)),
		FoeLow = ownerHumanoid ~= nil and ownerHumanoid.Health < ownerHumanoid.MaxHealth * 0.3,
		FoeIdle = duel.FoeIdleSince ~= nil and now - duel.FoeIdleSince >= Brain.IdleAfter,
		SinceOffense = now - (duel.LastOffense or now),
		NextAttack = duel.NextAttack,
		NextSurge = duel.NextSurge,
		NextDefense = duel.NextDefense,
		NextRetreat = duel.NextRetreat,
		NextLunge = duel.NextLunge,
	}
	if
		(view.FoeCharging or view.FoeCasting or view.FoeAttacking)
		and distance <= Brain.Reach + 4
		and now >= duel.NextDefense
	then
		duel.NextDefense = now + 0.45 -- considered: a beat before it reacts again
	end
	local choice = Brain.decide(view, math.random())
	-- A cast in reach: jab it (most of the time), as a player would.
	if
		view.FoeCasting
		and choice ~= "Stagger"
		and math.random() < 0.75
		and Brain.pickMove(duel.Moves, "Interrupt", now, distance, 0)
	then
		choice = "Interrupt"
	end
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
	if move and duel.Stamina < (move.Cost or 0) then
		move = nil -- can't afford it, like a player
	end
	if move then
		spendStamina(duel, move.Cost or 0)
		duel.LastOffense = now
		humanoid:MoveTo(root.Position)
		dropGuard(enemy, now)
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
		-- Shield up, longer against a flurry, edging sideways behind it.
		local hold = if view.FoeAggressive then 2.2 elseif view.FoeIdle then 0.6 else 1.6
		if not guarding(enemy, now) then
			-- Just raised: a beat before it can swing (keeping it up doesn't
			-- push its next attack back, or it would never strike).
			duel.NextAttack = math.max(duel.NextAttack, now + 0.3)
		end
		raiseGuard(enemy, duel, now, hold)
		humanoid:MoveTo(root.Position + side * duel.Weave * 2)
		face(root, target.Position)
	elseif choice == "GuardAdvance" then
		-- Walk you down behind the shield (refreshed while it advances; it
		-- drops the guard to strike once in reach).
		raiseGuard(enemy, duel, now, 0.8)
		humanoid:MoveTo(target.Position - dir * 3 + side * duel.Weave)
		face(root, target.Position)
	elseif choice == "Riposte" then
		-- It blocked your swing: a fast counter while you're open.
		duel.RiposteFor = enemy.BlockedAt
		dropGuard(enemy, now)
		duel.Action = { Kind = "Punish", At = now + Brain.Windup.Punish, Hits = 1 }
		duel.LastOffense = now
		animate(duel, "Slash", Brain.Windup.Punish, nil, nil)
		setStance(duel, "Counter")
		press(duel, "LMB")
		Remotes.CombatFx:FireClient(owner, "TechStatus", duel.Name .. " counters!")
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	elseif choice == "Dodge" and duel.Stamina >= Actions.Base.Hop.Cost then
		spendStamina(duel, Actions.Base.Hop.Cost)
		local sign = if math.random() < 0.5 then 1 else -1
		local away = side * sign
		enemy.DodgeUntil = now + Actions.Base.Hop.PvPInvincible
		animate(duel, "Dodge", 0, sign)
		setStance(duel, "Dodge")
		press(duel, "SPACE")
		root.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 6, 0)
		fx("DodgeRoll", nil, root.Position, away, 8, true)
	elseif choice == "Punish" then
		dropGuard(enemy, now)
		duel.Action = { Kind = "Punish", At = now + Brain.Windup.Punish, Hits = 1 }
		duel.LastOffense = now
		animate(duel, "Slash", Brain.Windup.Punish)
		setStance(duel, "Counter")
		press(duel, "LMB")
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	elseif choice == "Lunge" then
		-- Dash in and swing as it arrives.
		dropGuard(enemy, now)
		duel.NextLunge = now + 4 + math.random() * 2
		root.AssemblyLinearVelocity = dir * math.min(80, distance * 5) + Vector3.new(0, 4, 0)
		fx("DodgeRoll", nil, root.Position, dir, math.min(14, distance - 3), false)
		duel.Action = { Kind = "Lunge", At = now + Brain.Windup.Lunge, Hits = 1 }
		duel.LastOffense = now
		animate(duel, "Slash", Brain.Windup.Lunge)
		setStance(duel, "Lunge")
		press(duel, "LMB")
		face(root, target.Position)
	elseif choice == "Surge" then
		-- An interrupt (your Pneumatic Jab) locks its surges for a moment.
		local silenced = now < ((enemy :: any).SilenceUntil or 0)
		local surge = if silenced then nil else Brain.pickSurge(duel.Surges, now, distance, view)
		-- A held beam bills a quarter-second at a time, as a player's.
		local cost = if surge and surge.Cast == "Channel" then (surge.Cost or 0) * 0.25 else surge and surge.Cost or 0
		if surge and duel.Charge < cost then
			surge = nil -- not enough Charge, like a player
		end
		if surge then
			duel.Charge -= cost
			duel.LastOffense = now
			dropGuard(enemy, now)
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
		dropGuard(enemy, now)
		local heavy = choice == "Heavy"
		duel.Action = { Kind = choice, At = now + Brain.Windup[choice], Hits = 1 }
		duel.LastOffense = now
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
		local shielded = guarding(enemy, now)
		if
			(duel.Stance == "Guard" and not shielded)
			or duel.Stance == "Dodge"
			or duel.Stance == "Surge"
			or duel.Stance == "Maneuver"
		then
			setStance(duel, "")
		end
		if now >= duel.NextWeave then
			duel.Weave, duel.NextWeave = -duel.Weave, now + 1 + math.random() * 1.2
		end
		if view.FoeIdle then
			-- You're standing there: it circles in close, ready to swing.
			humanoid:MoveTo(target.Position - dir * 4 + side * duel.Weave * 2)
		else
			local keep = if distance < 3 then -dir * 3 else Vector3.zero
			humanoid:MoveTo(root.Position + side * duel.Weave * 4 + keep)
		end
		face(root, target.Position)
	end
	if duel.RetreatUntil and now < duel.RetreatUntil and not duel.Action then
		humanoid:MoveTo(root.Position - dir * 10)
	end
end

-- A raid wave cleared: everyone still in it is paid, then a tougher boss.
local function raidCleared(duel)
	local raid = duel.Raid
	for member, live in duels do
		if live == duel then
			duels[member] = nil
		end
	end
	local coins = Matchmaking.raidCoins(raid.Wave)
	for _, member in raid.Members do
		if member.Parent then
			PlayerData.addCoins(member, coins)
			local profile = PlayerData.get(member)
			if profile then
				profile.Stats.Kills += 1
			end
			Progress.addXP(member, "SlayBrute")
			Remotes.Notify:FireClient(
				member,
				string.format(
					"Wave %d cleared! %s is down: +%d coins. A tougher boss arrives in %d seconds…",
					raid.Wave,
					duel.Name,
					coins,
					Matchmaking.Raid.NextWave
				)
			)
		end
	end
	raid.Wave += 1
	task.delay(Matchmaking.Raid.NextWave, function()
		local still = {}
		for _, member in raid.Members do
			if
				member.Parent
				and member:GetAttribute("RaidId") == raid.Id
				and member:GetAttribute("CombatSession") == "Raid"
				and ownerRoot(member)
			then
				table.insert(still, member)
			end
		end
		raid.Members = still
		if still[1] then
			spawnRival(still[1], raid)
		else
			for _, member in raid.All do
				if member.Parent then
					member:SetAttribute("RaidId", nil)
				end
			end
		end
	end)
end

local function onWin(enemy)
	local duel = enemy.Duel
	if duel.Dungeon then
		dungeonActors[enemy] = nil
		duel.Dungeon.OnDeath(enemy)
		return
	end
	if duel.Raid then
		raidCleared(duel)
		return
	end
	local owner = duel.Owner
	duels[owner] = nil
	if not owner.Parent then
		return
	end
	local session = duel.Session
	countDuel(owner, true)
	if duel.Intro then
		-- The first-duel intro is one match; the client heads to the lobby.
		Remotes.Notify:FireClient(owner, string.format("You beat %s! Welcome to the Saga Outpost.", duel.Name))
		return
	end
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

function spawnRival(owner: Player, raid, encounter)
	if (not encounter and duels[owner]) or starting[owner] then
		return
	end
	-- PvP brings a full-strength rival; Training a sparring partner that hits
	-- for half and gives no rewards; a raid, a boss for the whole party.
	local session = owner:GetAttribute("CombatSession")
	if raid then
		if session ~= "Raid" then
			return
		end
	elseif session ~= "PvP" and session ~= "Training" then
		return
	end
	local sparring = session == "Training"
	local root = ownerRoot(owner)
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = if encounter then encounter.Center else landmarks and landmarks:GetAttribute("ArenaFloor")
	local ownerLoadout = PlayerData.character(owner)
	if not root or typeof(center) ~= "Vector3" or not ownerLoadout then
		return
	end
	starting[owner] = true
	local rng = Random.new()
	local loadout = rollLoadout(rng)
	if encounter then
		encounter.GearTier = encounter.GearTier or (if encounter.Boss then 4 else 1)
		if not encounter.Bandit then
			DungeonLoadout.apply(loadout, encounter.Spec, encounter.GearTier, rng)
		end
	end
	local name = NAMES[rng:NextInteger(1, #NAMES)]
	if raid then
		name = "Warlord " .. name
	end
	if encounter then
		name = (if encounter.Boss then "Colossus " else "")
			.. encounter.Spec.Name
			.. " ["
			.. DungeonLoadout.Labels[encounter.GearTier]
			.. "]"
	end
	if encounter and encounter.Bandit then
		name = "Space Bandit " .. NAMES[rng:NextInteger(1, #NAMES)]
	end
	-- Across the floor from the player, facing them.
	local away = flat(center - root.Position)
	away = if away.Magnitude > 1 then away.Unit else Vector3.new(1, 0, 0)
	local spot = if encounter then encounter.Spot else center + away * 18 + Vector3.new(0, 4, 0)
	local rig = buildRig(loadout, name, CFrame.lookAt(spot, Vector3.new(root.Position.X, spot.Y, root.Position.Z)))
	starting[owner] = nil
	if
		not rig
		or not owner.Parent
		or owner:GetAttribute("CombatSession") ~= session
		or (not encounter and duels[owner])
	then
		if rig then
			rig:Destroy()
		end
		return
	end
	if encounter and encounter.Bandit then
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				part.Color = part.Color:Lerp(Color3.fromRGB(170, 45, 50), 0.48)
			end
		end
	elseif encounter then
		-- Remove cosmetic equipment, retaining the entire jointed animation skeleton.
		for _, child in rig:GetChildren() do
			if child:IsA("Folder") or child:IsA("Accessory") then
				child:Destroy()
			end
		end
		BrainrotSkins.apply(
			rig,
			encounter.Spec,
			GemConfig.ElementColors[encounter.Spec.Element],
			encounter.Boss,
			encounter.GearTier,
			Classes.heldShield(loadout) ~= nil
		)
	end
	-- Equal ground: it's a new player with its own random kit, built by
	-- exactly the rules that build yours. Its health, swing damage, armour,
	-- walk speed, crit chance and swing pace all come from its own gear and
	-- gems (Classes.ratings), as yours do; nothing is scaled to you.
	local mine, theirs = Classes.ratings(loadout), Classes.ratings(ownerLoadout)
	local weapon = Classes.weapon(ownerLoadout.Class, ownerLoadout.Weapon)
	local rivalWeapon = Classes.weapon(loadout.Class, loadout.Weapon)
	-- Its kit comes from the very function that builds a player's (gear
	-- effects, gem defences, set rules), with no Augment Tree perks, as in
	-- any Arena fight.
	local rivalKit = CombatServer.kitFor(loadout, {})
	local rivalEffects = rivalKit.Effects
	local rules = rivalKit.Rules
	local playerHit = (if weapon then weapon.Attack.Damage else 10) * Combat.powerMult(rating(theirs, "Power"))
	local rivalHit = (if rivalWeapon then rivalWeapon.Attack.Damage else 18) * Combat.powerMult(rating(mine, "Power"))
	local ownerHumanoid = owner.Character:FindFirstChildOfClass("Humanoid")
	local health = Classes.maxHealth(rating(mine, "Health"))
	-- A raid boss: more health for every raider and wave, and heavier hits.
	local raidHealth, raidDamage = 1, 1
	if raid then
		raidHealth, raidDamage = Matchmaking.raidScale(#raid.Members, raid.Wave)
		health = math.floor(health * raidHealth)
		if encounter then
			health = math.floor(health * (if encounter.Boss then 2.2 else 0.38))
			raidDamage *= if encounter.Boss then 1 else 0.65
		end
	end
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
		Title = if encounter
			then string.format(
				"%s · %s · weak: %s",
				name,
				GemConfig.elementName(element),
				GemConfig.elementName(encounter.Spec.Weakness)
			)
			else string.format("%s  ·  %s", name, GemConfig.elementName(element)),
		Home = spot,
	})
	enemy.Humanoid.AutoRotate = false
	-- It takes hits as you do (Enemies.damage): its armour (cut by Sunder),
	-- armour passives and gem resistance, and on its guard its gem deflect
	-- and reflect chances.
	enemy.DefenseRating = rating(mine, "Defense")
	enemy.TakenMult = EquipmentBalance.passiveDamageMultiplier(rivalEffects.TakenMult, rivalKit.Defense.Resistance)
	enemy.Deflect = if rivalKit.Defense.Deflect > 0 then rivalKit.Defense.Deflect else nil
	enemy.Reflect = if rivalKit.Defense.Reflect > 0 then rivalKit.Defense.Reflect else nil
	-- Its armor gems resist and leave it weak as yours do (ElementMatchup).
	enemy.ArmorProfile = ElementMatchup.profile(loadout)
	enemy.GuardBreakTime = Actions.Base.Heavy.BreakSeconds
	-- Every bout starts even: the player (every raider) steps in at full health too.
	for _, member in if encounter then {} elseif raid then raid.Members else { owner } do
		local _, memberHumanoid = ownerRoot(member)
		if memberHumanoid then
			memberHumanoid.Health = memberHumanoid.MaxHealth
		end
	end
	-- Its own legs only: the stock Animate script doesn't run on a server rig.
	local animateScript = rig:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end
	animateLegs(enemy.Humanoid)
	rig:SetAttribute("Posed", true) -- clients pose it (BodyPoses)
	-- Smooth turning toward its target (see face).
	do
		local root = enemy.Root
		local attachment = Instance.new("Attachment")
		attachment.Name = "FaceAttachment"
		attachment.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Name = "FaceAlign"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.Responsiveness = 40
		align.MaxTorque = 1e7
		align.CFrame = root.CFrame.Rotation
		align.Parent = root
	end
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
		FoeRanged = weapon ~= nil and weapon.Attack.Kind == "Shot",
		WeaponGem = loadout.WeaponGem,
		Session = session,
		-- A new player's first duel (a sparring match): one match, then the lobby.
		Intro = not raid and not encounter and session == "Training" and duelsPlayed(owner) == 0,
		-- (Training's sparring partner hits for half.)
		Damage = rivalHit * (if sparring then 0.5 else 1) * raidDamage,
		Weapon = rivalWeapon,
		Kit = rivalKit,
		Crit = Combat.critChance(rating(mine, "Speed"), rivalEffects.CritAdd),
		HeavyCrit = rules.HeavyCrit,
		Speed = Classes.combatSpeed(rating(mine, "Speed")) + (rivalEffects.SpeedAdd or 0),
		SwingCooldown = rules.BasicCooldown,
		Rate = if sparring then rules.BasicCooldown * 1.35 else rules.BasicCooldown,
		-- Its own Stamina and Charge, by the same rules as yours.
		Stamina = Tech.Resources.Stamina.Max,
		Charge = Tech.Resources.Charge.Start,
		ResourceAt = os.clock(),
		StaminaRestUntil = 0,
		Action = nil,
		NextAttack = now + 1.2,
		LastOffense = now,
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
	if encounter then
		duel.Dungeon = encounter
		enemy.DungeonId = raid.Id
		enemy.ElementWeakness = encounter.Spec.Weakness
		enemy.Model:SetAttribute("DungeonId", raid.Id)
		enemy.Model:SetAttribute("RaidBandit", encounter.Bandit == true)
		enemy.Model:SetAttribute("ElementWeakness", encounter.Spec.Weakness)
		enemy.Model:SetAttribute("ElementResistance", encounter.Spec.Element)
	end
	-- A reflected blow goes back to whoever struck it, as a player's does.
	enemy.OnReflect = function(_source, amount: number)
		strike(duel, amount, nil, false, nil, "Reflect")
	end
	-- Its loadout and surge, for the player's rival panel.
	local model = enemy.Model
	model:SetAttribute("RivalOwner", owner.UserId)
	model:SetAttribute("RivalName", name)
	model:SetAttribute("RivalElement", element)
	model:SetAttribute("RivalSparring", sparring)
	if raid then
		duel.Raid = raid
		model:SetAttribute("RaidId", raid.Id)
		model:SetAttribute("RaidWave", raid.Wave)
		model:SetAttribute("RaidSize", #raid.Members)
	end
	local gear, score = {}, 0
	for _, slot in Slots.Order do
		local item = Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		local roll = GearRolls.get(loadout, slot)
		for stat, amount in roll and roll.Stats or {} do
			score += if stat == "Critical" or stat == "Cooldown" then amount * 100 else amount
		end
		local gem = loadout[slot .. "Gem"]
		table.insert(
			gear,
			string.format(
				"%s|%s|%d|%s|%s",
				slot,
				if item then item.Name else "?",
				roll and roll.Rarity or 1,
				gem and gem.Element or "",
				gem and gem.Tier or ""
			)
		)
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
				-- A blast is wide (Actions.Blast); a lingering pool keeps its own size.
				Radius = if stats.Cloud then stats.Radius else Actions.blastRadius(stats.Radius),
				-- Cast exactly as a player casts it (Actions.castTime / castPose):
				-- the same wind-up, the same pose, a held beam, a lingering pool.
				Cast = Actions.castKind(stats),
				CastTime = Actions.castTime(stats),
				Pose = Actions.castPose(stats),
				Range = stats.Range,
				Cloud = stats.Cloud,
				-- A player's surge numbers: its damage, Charge cost and recovery.
				Power = stats.Damage or 1,
				Crit = stats.Crit, -- a gem's cut gives its surge a crit chance, as yours
				Cost = stats.Cost or 0,
				Cooldown = math.max(stats.Cooldown or stats.Recovery or 1, 2.5),
				Riders = ridersOf(stats),
				Ward = stats.Ward,
				Leech = stats.Leech,
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
	local pool = table.clone(if encounter then encounter.Spec.Moves else Tech.Order.RigManeuvers)
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
			Heavy = stats.Heavy == true, -- breaks guard, as a player's
			Interrupt = stats.Interrupt,
			Leap = stats.Leap,
			Riposte = stats.Riposte,
			CounterDamage = stats.CounterDamage,
			-- A player's maneuver numbers: its Stamina cost and recovery.
			Cost = stats.Cost or 0,
			Crit = stats.Crit,
			Cooldown = math.max(stats.Cooldown or stats.Recovery or 1, 1.5),
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
		Hit = math.floor(playerHit * Combat.defenseMult(enemy.DefenseRating) * enemy.TakenMult + 0.5), -- after its armour
		Speed = math.floor(Classes.combatSpeed(rating(theirs, "Speed")) * 10 + 0.5) / 10, -- your speed in the fight
		Element = ownerLoadout.WeaponGem and ownerLoadout.WeaponGem.Element,
		Armor = ElementMatchup.profile(ownerLoadout),
		Surges = yourSurges,
		Moves = ownerLoadout.Maneuvers or Tech.DefaultManeuvers,
	}, {
		Name = name,
		Health = health,
		-- Its quick hit after your armor.
		Hit = math.floor(duel.Damage * Combat.defenseMult(rating(theirs, "Defense")) + 0.5),
		Speed = duel.Speed,
		Element = element,
		Armor = ElementMatchup.profile(loadout),
		Surges = duel.Surges,
		Moves = foeMoves,
	})
	model:SetAttribute("Matchup", HttpService:JSONEncode(matchup))
	local surgeList = if #names > 0 then table.concat(names, ", ") else "no surges"
	enemy.Brain = think
	enemy.OnDeath = onWin
	if encounter then
		dungeonActors[enemy] = duel
		return enemy
	end
	if raid then
		for _, member in raid.Members do
			duels[member] = duel
			Remotes.Notify:FireClient(
				member,
				string.format("Wave %d: %s storms in with %s. Fight together!", raid.Wave, name, surgeList)
			)
		end
		return
	end
	duels[owner] = duel
	if ArenaDrop.forRival(session, raid, encounter) and owner.Character then
		local first = not owner:GetAttribute("ArenaInserted")
		owner:SetAttribute("ArenaInserted", true)
		ArenaDrop.begin({ owner.Character, model }, { owner }, if first then nil else { model })
	end
	Remotes.Notify:FireClient(
		owner,
		if sparring
			then string.format("Sparring partner %s steps in (%s). Hits are softened.", name, surgeList)
			else string.format("%s inbound with %s. Prepare for impact.", name, surgeList)
	)
end

-- A party raid begins (Raids): its members are already in the Arena, in a
-- "Raid" session with this RaidId.
function Duelist.startRaid(members: { Player }, id: string)
	local raid = { Id = id, Members = table.clone(members), All = table.clone(members), Wave = 1 }
	if raid.Members[1] then
		spawnRival(raid.Members[1], raid)
	end
	return raid
end

function Duelist.spawnDungeon(members, id, encounter)
	local raid = {
		Id = id,
		Members = table.clone(members),
		All = table.clone(members),
		Wave = if encounter.OpenWorld then 1 else encounter.Room,
		Dungeon = true,
	}
	return spawnRival(members[1], raid, encounter)
end
function Duelist.removeDungeon(id)
	for enemy, duel in dungeonActors do
		if duel.Raid.Id == id then
			dungeonActors[enemy] = nil
			if enemy.Alive then
				Enemies.remove(enemy)
			end
		end
	end
end
function Duelist.start()
	-- Your Pneumatic Jab on a rival mid-cast: the cast is cancelled and its
	-- surges lock for `seconds`. True if there was a cast to cancel.
	Enemies.interrupt = function(enemy, seconds: number): boolean
		local duel = (enemy :: any).Duel
		local action = duel and duel.Action
		local casting = duel ~= nil
			and (
				duel.Channel ~= nil
				or (
					action ~= nil
					and (
						action.Kind == "Nova"
						or action.Kind == "Bolt"
						or action.Kind == "Buff"
						or action.Kind == "Channel"
					)
				)
			)
		if not casting then
			return false
		end
		local now = os.clock()
		duel.Action, duel.Channel = nil, nil;
		(enemy :: any).SilenceUntil = now + seconds
		local model = enemy.Model
		for _, key in { "ActionName", "ActionKind", "ActionElement", "ActionStart", "ActionAt", "ActionHold" } do
			model:SetAttribute(key, nil)
		end
		setStance(duel, "")
		duel.NextAttack = now + 0.5
		Remotes.CombatFx:FireClient(duel.Owner, "TechStatus", "Interrupted " .. duel.Name .. "!")
		Enemies.controlThreat(enemy)
		return true
	end
	-- Its fighting poses, every frame, bent on the server so every client sees them.
	-- Its fighting poses are drawn on every client (BodyPoses, from the
	-- model's "Posed" attribute and its action attributes), at the screen's
	-- frame rate. Posed here they were streamed joint by joint at the network
	-- rate: choppy, and heavy on bandwidth. Dead dungeon fighters drop off.
	RunService.Heartbeat:Connect(function()
		for enemy in dungeonActors do
			if not enemy.Alive then
				dungeonActors[enemy] = nil
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
