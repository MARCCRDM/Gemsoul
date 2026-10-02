--[[
	The PvP Duelist: entering the PvP Arena brings a computer rival with its
	own random loadout (rolled like a new player's: six pieces of gear, a gem
	in the weapon and a Gem Surge). It fights like a player:

	  · closes in weaving, circles you between attacks
	  · quick swings (sometimes a two-hit chain) and slow, telegraphed heavy
	    blows that break your guard
	  · raises its guard or sidesteps when you wind up a swing
	  · casts its surge from range: a bolt (Thermal/Ion) or a ground blast you
	    can step out of (Cryo/Corrosive)
	  · backs off now and then when badly hurt

	Your guard, parries, dodges and gems all work against it, because it is an
	Enemy (see Enemies.adopt) and its hits go through CombatServer.hurt. Its
	decisions live in Shared.DuelistBrain.

	Win: coins, XP and a kill; a new rival steps in a few seconds later.
	Lose, leave the Arena or the floor: the rival leaves too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brain = require(ReplicatedStorage.Shared.DuelistBrain)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
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
	-- Its surge shares the weapon gem's element, so the rival has one colour.
	local surge = GemGenerator.generate(rng, "PvEDrop", { Id = "duel-s" .. idCounter, Time = os.time() })
	surge.Element = gem.Element
	surge.Surge = GemRoller.Surges[gem.Element][surge.SurgeTier]
	c.Surge1Gem = surge
	return c
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
	rig.Name = "Rival · " .. name
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

local function ownerRoot(owner: Player): (BasePart?, Humanoid?)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function face(root: BasePart, target: Vector3)
	local look = flat(target - root.Position)
	if look.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end
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
	if not target or owner:GetAttribute("CombatSession") ~= "PvP" or not Combat.canFight(target.Position) then
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
			return
		end
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
		if now < action.At then
			return
		end
		duel.Action = nil
		local damage = duel.Damage * (1 - Enemies.weakness(enemy))
		if action.Kind == "Light" or action.Kind == "Heavy" then
			local heavy = action.Kind == "Heavy"
			fx("Swing", nil, root.Position, dir, Brain.Reach, if heavy then 140 else 100, color, heavy)
			if distance <= Brain.Reach + 1.5 then
				Enemies.hitPlayer(owner, damage * (if heavy then 2 else 1), duel.Element, enemy, heavy)
			end
			if action.Chain and math.random() < 0.5 then
				duel.Action = { Kind = "Light", At = now + 0.4 }
				return
			end
			duel.NextAttack = now + duel.Rate * (0.8 + math.random() * 0.6)
		elseif action.Kind == "Bolt" then
			local from = root.Position + Vector3.new(0, 1.5, 0)
			fx("Shot", nil, from, target.Position, color, "Fireball")
			task.delay(math.clamp(distance / 140, 0.05, 0.5), function()
				local stillRoot = ownerRoot(owner)
				if duels[owner] == duel and stillRoot then
					Enemies.hitPlayer(owner, damage * duel.SurgePower, duel.Element, enemy, false)
				end
			end)
			duel.NextAttack = now + 0.6
		elseif action.Kind == "Nova" then
			if (flat(target.Position - action.Center)).Magnitude <= action.Radius then
				Enemies.hitPlayer(owner, damage * duel.SurgePower * 1.2, duel.Element, enemy, false)
			end
			duel.NextAttack = now + 0.6
		end
		return
	end

	local foe = CombatServer._state(owner)
	local view = {
		Now = now,
		Distance = distance,
		HealthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth),
		Stunned = now < enemy.StunUntil,
		FoeCharging = foe ~= nil and foe.ChargeStarted ~= nil,
		FoeBlocking = owner:GetAttribute("Blocking") == true,
		NextAttack = duel.NextAttack,
		NextSurge = duel.NextSurge,
		NextDefense = duel.NextDefense,
		NextRetreat = duel.NextRetreat,
	}
	if view.FoeCharging and distance <= Brain.Reach + 3 and now >= duel.NextDefense then
		duel.NextDefense = now + 2.2 -- considered: don't react to every swing
	end
	local choice = Brain.decide(view, math.random())
	if choice == "Stagger" then
		humanoid:MoveTo(root.Position)
	elseif choice == "Guard" then
		enemy.GuardUntil, enemy.GuardMult = now + 0.9, 0.3
		duel.NextAttack = math.max(duel.NextAttack, now + 0.9)
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	elseif choice == "Dodge" then
		local away = side * (if math.random() < 0.5 then 1 else -1)
		enemy.DodgeUntil = now + 0.35
		root.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 6, 0)
		fx("DodgeRoll", nil, root.Position, away, 8, true)
	elseif choice == "Surge" then
		duel.NextSurge = now + 8 + math.random() * 4
		Remotes.CombatFx:FireClient(owner, "TechStatus", duel.Name .. " casts " .. duel.SurgeName .. "!")
		if duel.Element == "Frost" or duel.Element == "Poison" then
			-- A ground blast under the player, with a warning ring to step out of.
			local center = target.Position
			fx("Nova", center - Vector3.new(0, 2.5, 0), 7, color, Brain.Windup.Nova)
			duel.Action = { Kind = "Nova", At = now + Brain.Windup.Nova, Center = center, Radius = 7 }
		else
			fx("TechPulse", nil, root.Position, root.Position, color, 3)
			duel.Action = { Kind = "Bolt", At = now + Brain.Windup.Bolt }
		end
	elseif choice == "Retreat" then
		duel.NextRetreat = now + 9
		duel.RetreatUntil = now + 1.6
	elseif choice == "Approach" then
		if now >= duel.NextWeave then
			duel.Weave, duel.NextWeave = -duel.Weave, now + 0.8 + math.random()
		end
		humanoid:MoveTo(target.Position - dir * 3 + side * duel.Weave * 3)
		face(root, target.Position)
	elseif choice == "Light" or choice == "Heavy" then
		local heavy = choice == "Heavy"
		duel.Action = { Kind = choice, At = now + Brain.Windup[choice], Chain = not heavy }
		if heavy then
			-- Telegraph: a warning ring at its feet before the blow lands.
			fx("Nova", root.Position - Vector3.new(0, 2.5, 0), 3.5, Color3.fromRGB(255, 120, 60), Brain.Windup.Heavy)
		end
		humanoid:MoveTo(root.Position)
		face(root, target.Position)
	else -- Strafe
		if now >= duel.NextWeave then
			duel.Weave, duel.NextWeave = -duel.Weave, now + 1 + math.random() * 1.2
		end
		local keep = if distance < 3 then -dir * 3 else Vector3.zero
		humanoid:MoveTo(root.Position + side * duel.Weave * 6 + keep)
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
		if owner.Parent and owner:GetAttribute("CombatSession") == "PvP" and not duels[owner] then
			spawnRival(owner)
		end
	end)
end

function spawnRival(owner: Player)
	if duels[owner] or starting[owner] then
		return
	end
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
	if not rig or not owner.Parent or owner:GetAttribute("CombatSession") ~= "PvP" or duels[owner] then
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
	local surgeId = Tech.surgeOf(loadout.Surge1Gem)
	local surge = surgeId and Tech.Catalog[surgeId]
	local kind = {
		Name = "Rival Duelist",
		Health = health,
		Damage = 0,
		Speed = 16,
		Reach = Brain.Reach,
		Rate = 1.1,
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
	local now = os.clock()
	local duel = {
		Enemy = enemy,
		Owner = owner,
		Name = name,
		Element = element,
		Plate = rig:FindFirstChild("GuardPlate"),
		Damage = (if ownerHumanoid then ownerHumanoid.MaxHealth else 300) / 13 * strength,
		SurgePower = if surge and surge.Damage then math.clamp(surge.Damage, 1, 2) else 1.4,
		SurgeName = if surge then surge.Name else "a Gem Surge",
		Speed = 16,
		Rate = 1.1,
		Action = nil,
		NextAttack = now + 1.5,
		NextSurge = now + 4 + math.random() * 3,
		NextDefense = now,
		NextRetreat = now + 6,
		NextWeave = now,
		Weave = 1,
		RetreatUntil = 0,
	}
	enemy.Duel = duel
	enemy.Brain = think
	enemy.OnDeath = onWin
	duels[owner] = duel
	Remotes.Notify:FireClient(owner, string.format("%s enters the Arena with %s. Fight!", name, duel.SurgeName))
end

function Duelist.start()
	ArenaSessions.onEnter = function(player: Player, pvp: boolean)
		if pvp then
			task.wait(1.5) -- let the arrival protection settle first
			if player:GetAttribute("CombatSession") == "PvP" then
				spawnRival(player)
			end
		end
	end
	ArenaSessions.onLeave = function(player: Player)
		Duelist.despawn(player)
	end
end

return Duelist
