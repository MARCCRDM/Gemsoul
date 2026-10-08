--[[
	Enemies: training dummies in the Arena and crystal monsters in the
	Crystal Wilds outside the south gate.

	  Training Dummy   never dies, heals up when left alone; for practice
	  Crystal Crawler  small and quick; sometimes drops a stone
	  Shard Brute      big and tough; always drops a stone, luckier rolls

	Monsters have an element. They chase the nearest fighter in range (or
	whoever taunted them), hit in melee, and walk back home, healing, if led
	too far from their camp. When one dies, the player who did the most
	damage gets its coins and loot, and a new one spawns a little later.

	Combat (CombatServer) deals damage through Enemies.damage and adds
	effects with Enemies.addStatus / Enemies.addDot / Enemies.taunt.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Combat)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CrowdControl = require(ReplicatedStorage.Shared.CrowdControl)
local Aggro = require(ReplicatedStorage.Shared.Aggro)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local Gems = require(script.Parent.Gems)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local DamageLog = require(script.Parent.DamageLog)

local DungeonRules = require(ReplicatedStorage.Shared.DungeonRules)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Enemies = {}

-- The Wilds: just outside the south gate, either side of the country road.
Enemies.WildsCenter = Vector3.new(0, 0.5, 300)

type Kind = {
	Name: string,
	Health: number,
	Damage: number,
	Speed: number,
	Reach: number, -- melee range
	Rate: number, -- seconds between hits
	Aggro: number, -- notices players this close
	Coins: number,
	DropChance: number,
	Luck: number,
	Respawn: number,
	Dummy: boolean?,
}

local KINDS: { [string]: Kind } = {
	Dummy = {
		Name = "Training Dummy",
		Health = 5000,
		Damage = 0,
		Speed = 0,
		Reach = 0,
		Rate = 1,
		Aggro = 0,
		Coins = 0,
		DropChance = 0,
		Luck = 0,
		Respawn = 0,
		Dummy = true,
	},
	Crawler = {
		Name = "Crystal Crawler",
		Health = 110,
		Damage = 9,
		Speed = 15,
		Reach = 5,
		Rate = 1.2,
		Aggro = 38,
		Coins = 6,
		DropChance = 0.05, -- monsters pay coins; a gem is a rare bonus
		Luck = 0.15,
		Respawn = 20,
	},
	Brute = {
		Name = "Shard Brute",
		Health = 420,
		Damage = 20,
		Speed = 10,
		Reach = 7,
		Rate = 2,
		Aggro = 32,
		Coins = 22,
		DropChance = 0.15,
		Luck = 0.6,
		Respawn = 40,
	},
}

-- Where monsters live in the Wilds: { kind, offset from the Wilds centre }.
local CAMPS = {
	{ "Crawler", Vector3.new(-30, 0, -20) },
	{ "Crawler", Vector3.new(-40, 0, 5) },
	{ "Crawler", Vector3.new(30, 0, -15) },
	{ "Crawler", Vector3.new(42, 0, 10) },
	{ "Crawler", Vector3.new(-25, 0, 40) },
	{ "Crawler", Vector3.new(28, 0, 45) },
	{ "Brute", Vector3.new(-50, 0, 60) },
	{ "Brute", Vector3.new(50, 0, 70) },
}
local LEASH = 70 -- studs from home before a monster gives up and walks back
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }

export type Dot = {
	PerTick: number,
	Ticks: number,
	Source: Player?,
	Color: Color3,
	Key: string?, -- a keyed dot refreshes instead of stacking (gem burns)
	Every: number?, -- tick every N half-second cycles
	Wait: number?,
}
export type Enemy = {
	Model: Model,
	Kind: Kind,
	KindId: string,
	Humanoid: Humanoid,
	Root: BasePart,
	Home: Vector3,
	Element: string?,
	Bar: Frame,
	Alive: boolean,
	LastHit: number,
	LastAttack: number,
	Damage: { [Player]: number },
	Threat: { [Player]: number },
	ThreatAt: { [Player]: number }, -- when each player last added threat
	Aggro: Aggro.State, -- who it's after (Shared.Aggro)
	LastSource: Player?, -- the last player to hit it, and when
	LastSourceAt: number,
	LastThink: number,
	StunUntil: number,
	SlowUntil: number,
	Slow: number,
	SunderUntil: number,
	Sunder: number, -- extra damage taken, as a fraction
	WeakenUntil: number,
	Weaken: number,
	VulnerableUntil: number,
	Vulnerable: number, -- extra damage taken from Corrosive vulnerability
	AuraUntil: number,
	Aura: number, -- extra damage taken inside a Corrosive aura
	TauntUntil: number,
	Taunter: Player?,
	Dots: { Dot },
	-- Custom fighters (the PvP Duelist) bring their own brain and rules:
	Brain: ((Enemy, number) -> ())?, -- thinks instead of the monster AI
	OnDeath: ((Enemy) -> ())?, -- replaces the usual rewards and respawn
	GuardUntil: number?, -- raised guard: incoming damage x GuardMult
	GuardMult: number?,
	DodgeUntil: number?, -- mid-dodge: hits miss
	[string]: any,
}

local enemies: { [Model]: Enemy } = {}
local folder: Folder

-- Hooks CombatServer fills in (avoids the two modules requiring each other).
Enemies.hitPlayer = function(
	_player: Player,
	_amount: number,
	_element: string?,
	_enemy: Enemy,
	_heavy: boolean?,
	_crit: boolean?
): (number?, boolean?)
	return nil, nil
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

-- Models -------------------------------------------------------------------------------------

local function part(model: Model, root: BasePart, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Name = props.Name or "Body"
	p.Size = props.Size
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = props.CastShadow ~= false
	p.CFrame = root.CFrame * (props.At or CFrame.identity)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function healthBar(root: BasePart, name: string, color: Color3, height: number): Frame
	local board = Instance.new("BillboardGui")
	board.Name = "HealthBar"
	-- FoeBars owns the visible nameplate. Keep this backing frame for health updates.
	board.Enabled = false
	board.Size = UDim2.fromOffset(120, 30)
	board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	board.MaxDistance = 90
	board.AlwaysOnTop = true
	board.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = name
	label.Parent = board
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(10, 18)
	back.Size = UDim2.new(1, -20, 0, 8)
	back.Parent = board
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	return fill
end

local function buildDummy(at: CFrame): (Model, BasePart, number)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 5, 1.2)
	root.CFrame = at * CFrame.new(0, 2.5, 0)
	root.Anchored = true
	root.Color = Color3.fromRGB(150, 110, 70)
	root.Material = Enum.Material.Wood
	root.Parent = model
	local straw = Color3.fromRGB(214, 186, 110)
	part(
		model,
		root,
		{ Size = Vector3.new(2.6, 2.4, 1.6), At = CFrame.new(0, 1, 0), Color = straw, Material = Enum.Material.Fabric }
	)
	part(model, root, {
		Size = Vector3.new(1.6, 1.6, 1.6),
		At = CFrame.new(0, 3.1, 0),
		Color = straw,
		Material = Enum.Material.Fabric,
	})
	part(model, root, {
		Size = Vector3.new(5, 0.5, 0.5),
		At = CFrame.new(0, 1.6, 0),
		Color = Color3.fromRGB(120, 86, 52),
		Material = Enum.Material.Wood,
	})
	-- A red target painted on the chest.
	part(model, root, {
		Size = Vector3.new(1, 1, 0.1),
		At = CFrame.new(0, 1, -0.82),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	return model, root, 5.5
end

local function buildCrawler(at: CFrame, color: Color3): (Model, BasePart, number)
	local model = Instance.new("Model")
	model.Name = "CrystalCrawler"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.6, 1.4, 3.2)
	root.CFrame = at * CFrame.new(0, 2, 0)
	root.Color = Color3.fromRGB(60, 56, 70)
	root.Material = Enum.Material.Slate
	root.Parent = model
	-- A crystal ridge on the back, glowing eyes, and six spiked legs.
	for i, z in { -0.9, 0, 0.9 } do
		part(model, root, {
			Size = Vector3.new(0.8, 1.2 + i * 0.2, 0.8),
			At = CFrame.new(0, 1, z) * CFrame.Angles(0, math.rad(45), math.rad(12 * (i - 2))),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	for _, x in { -0.5, 0.5 } do
		part(model, root, {
			Size = Vector3.new(0.3, 0.3, 0.2),
			At = CFrame.new(x, 0.2, -1.65),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	for _, side in { -1, 1 } do
		for _, z in { -1, 0, 1 } do
			part(model, root, {
				Size = Vector3.new(1.8, 0.3, 0.3),
				At = CFrame.new(side * 1.6, -0.4, z) * CFrame.Angles(0, 0, math.rad(side * -35)),
				Color = Color3.fromRGB(40, 38, 48),
				Material = Enum.Material.Slate,
			})
		end
	end
	return model, root, 3
end

local function buildBrute(at: CFrame, color: Color3): (Model, BasePart, number)
	local model = Instance.new("Model")
	model.Name = "ShardBrute"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4.2, 4.4, 3)
	root.CFrame = at * CFrame.new(0, 5.2, 0)
	root.Color = Color3.fromRGB(70, 66, 78)
	root.Material = Enum.Material.Basalt
	root.Parent = model
	local stone = Color3.fromRGB(60, 56, 66)
	part(
		model,
		root,
		{ Size = Vector3.new(2, 1.8, 1.8), At = CFrame.new(0, 3, -0.2), Color = stone, Material = Enum.Material.Basalt }
	)
	for _, x in { -0.45, 0.45 } do
		part(model, root, {
			Size = Vector3.new(0.4, 0.3, 0.2),
			At = CFrame.new(x, 3.1, -1.12),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	for _, side in { -1, 1 } do
		part(model, root, {
			Size = Vector3.new(1.6, 4.4, 1.6),
			At = CFrame.new(side * 3, -0.8, 0),
			Color = stone,
			Material = Enum.Material.Basalt,
		})
		part(model, root, {
			Size = Vector3.new(1.8, 1.4, 1.8),
			At = CFrame.new(side * 3, -3.4, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		part(model, root, {
			Size = Vector3.new(1.6, 2.8, 1.6),
			At = CFrame.new(side * 1.2, -3.6, 0),
			Color = stone,
			Material = Enum.Material.Basalt,
		})
		-- Crystal shards growing from the shoulders.
		part(model, root, {
			Size = Vector3.new(0.9, 2.2, 0.9),
			At = CFrame.new(side * 2.2, 2.8, 0.4) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	return model, root, 3.2
end

-- Spawning -----------------------------------------------------------------------------------

local function spawn(kindId: string, home: Vector3, facing: Vector3?)
	local kind = KINDS[kindId]
	local element = if kind.Dummy then nil else ELEMENTS[math.random(1, #ELEMENTS)]
	local color = if element then GemConfig.ElementColors[element] else Color3.new(1, 1, 1)
	local at = CFrame.lookAt(home, home + (facing or Vector3.new(0, 0, -1)) * Vector3.new(1, 0, 1))
	local model, root, hipHeight
	if kindId == "Dummy" then
		model, root, hipHeight = buildDummy(at)
	elseif kindId == "Brute" then
		model, root, hipHeight = buildBrute(at, color)
	else
		model, root, hipHeight = buildCrawler(at, color)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = kind.Health
	humanoid.Health = kind.Health
	humanoid.WalkSpeed = kind.Speed
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root

	local title = if element then string.format("%s (%s)", kind.Name, element) else kind.Name
	local bar = healthBar(root, title, color, root.Size.Y / 2 + 2)
	model:SetAttribute("Enemy", kindId)
	model.Parent = folder
	if not root.Anchored then
		pcall(root.SetNetworkOwner, root, nil)
	end

	enemies[model] = {
		Model = model,
		Kind = kind,
		KindId = kindId,
		Humanoid = humanoid,
		Root = root,
		Home = home,
		Element = element,
		Bar = bar,
		Alive = true,
		LastHit = 0,
		LastAttack = 0,
		Damage = {},
		Threat = {},
		ThreatAt = {},
		Aggro = Aggro.new(),
		LastSource = nil,
		LastSourceAt = 0,
		LastThink = 0,
		StunUntil = 0,
		SlowUntil = 0,
		Slow = 0,
		SunderUntil = 0,
		Sunder = 0,
		WeakenUntil = 0,
		Weaken = 0,
		VulnerableUntil = 0,
		Vulnerable = 0,
		AuraUntil = 0,
		Aura = 0,
		TauntUntil = 0,
		Taunter = nil,
		Dots = {},
	}
end

-- Registers a ready-built fighter (a rig with a Humanoid) as an enemy, so
-- every player attack, surge and status already works against it.
function Enemies.adopt(model: Model, kind, opts: { Element: string?, Title: string?, Home: Vector3? }): Enemy
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart
	humanoid.MaxHealth, humanoid.Health = kind.Health, kind.Health
	humanoid.WalkSpeed = kind.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	local color = if opts.Element then GemConfig.ElementColors[opts.Element] else Color3.new(1, 1, 1)
	model:SetAttribute("CombatTitle", opts.Title or kind.Name)
	local head = model:FindFirstChild("Head")
	local bar = healthBar(
		root,
		opts.Title or kind.Name,
		color,
		if head and head:IsA("BasePart")
			then head.Position.Y - root.Position.Y + head.Size.Y / 2 + 1.5
			else root.Size.Y / 2 + 2
	)
	model:SetAttribute("Enemy", kind.Name)
	model.Parent = folder
	pcall(root.SetNetworkOwner, root, nil)
	local enemy = {
		Model = model,
		Kind = kind,
		KindId = kind.Name,
		Humanoid = humanoid,
		Root = root,
		Home = opts.Home or root.Position,
		Element = opts.Element,
		Bar = bar,
		Alive = true,
		LastHit = 0,
		LastAttack = 0,
		Damage = {},
		Threat = {},
		ThreatAt = {},
		Aggro = Aggro.new(),
		LastSource = nil,
		LastSourceAt = 0,
		LastThink = 0,
		StunUntil = 0,
		SlowUntil = 0,
		Slow = 0,
		SunderUntil = 0,
		Sunder = 0,
		WeakenUntil = 0,
		Weaken = 0,
		VulnerableUntil = 0,
		Vulnerable = 0,
		AuraUntil = 0,
		Aura = 0,
		TauntUntil = 0,
		Taunter = nil,
		Dots = {},
	}
	enemies[model] = enemy
	return enemy
end

-- Takes a fighter out without a death (its session ended).
function Enemies.remove(enemy: Enemy)
	enemy.Alive = false
	enemies[enemy.Model] = nil
	enemy.Model:Destroy()
end

-- Damage and effects -------------------------------------------------------------------------

function Enemies.all(): { Enemy }
	local list = {}
	for _, enemy in enemies do
		if enemy.Alive then
			table.insert(list, enemy)
		end
	end
	return list
end

function Enemies.get(model: Model): Enemy?
	return enemies[model]
end

local function updateBar(enemy: Enemy)
	enemy.Bar.Size = UDim2.fromScale(math.clamp(enemy.Humanoid.Health / enemy.Humanoid.MaxHealth, 0, 1), 1)
end

-- The player who did the most damage gets the rewards, and so does every
-- member of their party fighting nearby. Each gets their own loot roll.
local function reward(enemy: Enemy)
	local best, most = nil, 0
	for player, amount in enemy.Damage do
		if player.Parent and amount > most then
			best, most = player, amount
		end
	end
	if not best then
		return
	end
	for _, player in Party.nearby(best, enemy.Root.Position, 90) do
		PlayerData.addCoins(player, enemy.Kind.Coins)
		PlayerData.milestone(player, "Slain")
		local profile = PlayerData.get(player)
		if profile then
			profile.Stats.Kills += 1
		end
		Progress.addXP(player, if enemy.KindId == "Brute" then "SlayBrute" else "SlayCrawler")
		Remotes.Notify:FireClient(player, string.format("Defeated a %s: +%d coins", enemy.Kind.Name, enemy.Kind.Coins))
		if math.random() < enemy.Kind.DropChance then
			Gems.dropFromMonster(player, enemy.Kind.Luck)
		end
	end
end

local function die(enemy: Enemy)
	enemy.Alive = false
	fx(
		"Death",
		enemy.Root.Position,
		if enemy.Element then GemConfig.ElementColors[enemy.Element] else nil,
		enemy.Model:GetAttribute("LastHitElement"),
		enemy.Model
	)
	if enemy.OnDeath then
		enemy.OnDeath(enemy)
	else
		reward(enemy)
	end
	local model = enemy.Model
	task.delay(0.6, function()
		enemies[model] = nil
		model:Destroy()
	end)
	if enemy.Kind.Respawn and enemy.Kind.Respawn > 0 then
		task.delay(enemy.Kind.Respawn, spawn, enemy.KindId, enemy.Home)
	end
end

-- Deals damage. `color` tints the floating number (element hits, crits).
-- Set by CombatServer: stuns a player whose swing was parried.
Enemies.parryPlayer = function(_player: Player, _seconds: number) end
Enemies.ParryWindow = 0.22 -- a swing landing this soon after the guard goes up is parried
Enemies.GuardBreakSeconds = 0.9

-- `heavy` is true/false for weapon swings and shots (nil for surges, burns
-- and other effects): a heavy breaks a raised guard, and a swing landing just
-- as the guard goes up is parried.
function Enemies.damage(
	enemy: Enemy,
	amount: number,
	source: Player?,
	crit: boolean?,
	color: Color3?,
	heavy: boolean?,
	incomingElement: string?
)
	if enemy.Model and (enemy.Model:GetAttribute("ArenaDropUntil") or 0) > workspace:GetServerTimeNow() then
		return
	end
	if source and (source:GetAttribute("ArenaDropUntil") or 0) > workspace:GetServerTimeNow() then
		return
	end
	if enemy.DungeonId and (not source or source:GetAttribute("DungeonId") ~= enemy.DungeonId) then
		return
	end
	local encounter = enemy.Duel and enemy.Duel.Dungeon
	if encounter and encounter.OpenWorld and encounter.Boss then
		local count = 0
		for _, member in enemy.Duel.Raid.Members do
			local h = member.Character and member.Character:FindFirstChildOfClass("Humanoid")
			if member.Parent and member:GetAttribute("DungeonId") == enemy.DungeonId and h and h.Health > 0 then
				count += 1
			end
		end
		if count < (encounter.MinPlayers or 3) then
			return
		end
	end
	-- Elements against its armor (ElementMatchup): a dungeon creature by its
	-- own element and weakness, a rival miner by its armor gem.
	local hitElement = incomingElement or GemConfig.elementOfColor(color)
	local matchMult, matchTag = 1, nil
	if enemy.DungeonId then
		matchMult, matchTag = DungeonRules.elementMultiplier(enemy.Element, enemy.ElementWeakness, hitElement)
	elseif (enemy :: any).ArmorProfile then
		matchMult, matchTag = ElementMatchup.against(hitElement, (enemy :: any).ArmorProfile)
	end
	amount *= matchMult
	if not enemy.Alive or amount <= 0 then
		return
	end
	-- The last elemental blow decides how the body goes (ElementalDeath).
	if hitElement then
		enemy.Model:SetAttribute("LastHitElement", hitElement)
	end
	local now = os.clock()
	local name = DamageLog.nameOf(enemy)
	if enemy.DodgeUntil and now < enemy.DodgeUntil then
		if (enemy :: any).ArmorDodge and heavy ~= nil then
			(enemy :: any).ArmorDodge()
		end
		DamageLog.send(source, { Dir = "Out", Kind = "Dodge", Who = name })
		return -- slipped out of the way
	end
	local exposure = 1 + Enemies.exposure(enemy)
	local blocked = 0
	local e = enemy :: any
	local duelist = e.Duel ~= nil
	-- A rival duelist takes a hit exactly as a player does: its armour
	-- (Defense, cut by Sunder) and armour passives first (not Sunder as
	-- extra damage, the way other enemies take it).
	if e.DefenseRating then
		local sunder = if now < enemy.SunderUntil then enemy.Sunder else 0
		amount *= Combat.defenseMult(e.DefenseRating * (1 - sunder)) * (e.TakenMult or 1)
		exposure -= sunder
	end
	local raw = amount
	if enemy.GuardUntil and now < enemy.GuardUntil then
		if heavy == true and not e.Barrier then
			-- A heavy blow smashes through a raised guard and staggers it
			-- (not a Cryo Shield barrier, which only halves hits). A rival
			-- duelist's guard breaks as a player's does: no stagger, and
			-- a player's break time.
			enemy.GuardUntil = 0
			e.GuardBrokenUntil = now + (if duelist then e.GuardBreakTime or 0.8 else Enemies.GuardBreakSeconds)
			if not duelist then
				enemy.StunUntil = math.max(enemy.StunUntil, now + 0.35)
			end
			e.StunKind = "Stunned"
			enemy.Model:SetAttribute("GuardUntil", 0)
			fx("BlockSpark", enemy.Root.Position, true)
			DamageLog.send(source, { Dir = "Out", Kind = "GuardBreak", Who = name })
		elseif
			heavy == false
			and source
			and e.GuardRaisedAt
			and now - e.GuardRaisedAt <= (if duelist then 0.3 else Enemies.ParryWindow)
			and not e.ParrySpent
		then
			-- Timed perfectly: parried, and the attacker is left open. A rival
			-- duelist parries as a player does: once per raise, the blow cut
			-- to 35% (PvP), the attacker staggered for a quarter second.
			fx("BlockSpark", enemy.Root.Position, false)
			e.BlockedAt = now
			DamageLog.send(source, { Dir = "Out", Kind = "Parried", Who = name })
			if not duelist then
				Enemies.parryPlayer(source, 0.45)
				return
			end
			e.ParrySpent = true
			if e.ArmorTimedBlock then
				e.ArmorTimedBlock()
			end
			Enemies.parryPlayer(source, 0.25)
			blocked = amount * 0.65 * exposure
			amount *= 0.35
		elseif e.GuardCost and not e.Barrier and not e.GuardCost(amount) then
			-- Out of Stamina: the guard breaks and the blow lands in full.
			enemy.GuardUntil = 0
			e.GuardBrokenUntil = now + Enemies.GuardBreakSeconds
			enemy.Model:SetAttribute("GuardUntil", 0)
			fx("BlockSpark", enemy.Root.Position, true)
			DamageLog.send(source, { Dir = "Out", Kind = "GuardBreak", Who = name })
		else
			local guarded = amount * (e.GuardMult or 0.3)
			-- Gem defences on a rival duelist's guard, as on a player's:
			-- a chance to deflect the blow, a chance to reflect it back.
			if e.Deflect and math.random() < e.Deflect then
				guarded = 0
			end
			if e.Reflect and e.OnReflect and source and math.random() < e.Reflect then
				e.OnReflect(source, raw)
			end
			blocked = (amount - guarded) * exposure
			amount = guarded
			if heavy ~= nil then
				e.BlockedAt = now -- a swing it can answer
			end
			fx("BlockSpark", enemy.Root.Position, false)
		end
	end
	amount = math.floor(amount * exposure + 0.5)
	-- Shields (a rival duelist's Cryo Shield, Energy Siphon, block gem or
	-- Ward) soak the blow first, as a player's do.
	local absorbed = 0
	if e.ArmorAbsorb then
		amount, absorbed = e.ArmorAbsorb(amount)
	end
	if (e.Shield or 0) > 0 and now < (e.ShieldUntil or 0) then
		local shieldAbsorb = math.min(e.Shield, amount)
		e.Shield -= shieldAbsorb
		amount -= shieldAbsorb
		absorbed += shieldAbsorb
	end
	DamageLog.send(source, {
		Dir = "Out",
		Kind = "Hit",
		Who = name,
		Amount = amount,
		Crit = crit == true,
		Blocked = blocked,
		Absorbed = if absorbed > 0 then absorbed else nil,
	})
	-- Its body reacts (RivalPose): a jolt of the shield arm when the blow
	-- lands on its guard, a flinch when it gets through.
	if enemy.Model then
		local serverNow = workspace:GetServerTimeNow()
		if blocked > 0 then
			enemy.Model:SetAttribute("BlockedAt", serverNow)
		end
		if amount > 0 and blocked <= amount then
			enemy.Model:SetAttribute("HurtAt", serverNow)
			enemy.Model:SetAttribute("HurtSide", if math.random() < 0.5 then -1 else 1)
		end
	end
	local humanoid = enemy.Humanoid
	enemy.LastHit = os.clock()
	if source then
		if amount > 0 then
			Remotes.CombatFx:FireClient(source, "HitConfirm", crit == true)
		end
		enemy.Damage[source] = (enemy.Damage[source] or 0) + amount
		local loadout = PlayerData.character(source)
		local bonus = if loadout then Classes.effects(loadout).ThreatGeneration or 0 else 0
		Aggro.add(enemy.Threat, enemy.ThreatAt, source, amount * (1 + bonus), os.clock())
		enemy.LastSource, enemy.LastSourceAt = source, os.clock()
	end
	fx(
		"Damage",
		enemy.Root.Position + Vector3.new(0, enemy.Root.Size.Y / 2 + 1, 0),
		amount,
		crit == true,
		color,
		matchTag
	)
	if enemy.Kind.Dummy or (enemy :: any).Training then
		-- Dummies never break; they just count. (A sparring partner in
		-- combat training keeps a quarter of its health until the real spar.)
		local floor = if (enemy :: any).Training then humanoid.MaxHealth * 0.25 else 1
		humanoid.Health = math.max(floor, humanoid.Health - amount)
		updateBar(enemy)
		return
	end
	humanoid.Health = math.max(0, humanoid.Health - amount)
	updateBar(enemy)
	if humanoid.Health <= 0 then
		DamageLog.send(source, { Dir = "Out", Kind = "Kill", Who = name })
		die(enemy)
	end
end

-- Extra damage taken right now: Sunder/armor shred, Vulnerable and Corrosive auras.
function Enemies.exposure(enemy: Enemy): number
	local now = os.clock()
	return (if now < enemy.SunderUntil then enemy.Sunder else 0)
		+ (if now < enemy.VulnerableUntil then enemy.Vulnerable else 0)
		+ (if now < enemy.AuraUntil then enemy.Aura else 0)
end

-- Stun, Slow (fraction), Sunder (fraction, stacks to 3x), Weaken (fraction),
-- Blind (fraction of its blows that miss),
-- Vulnerable and Aura (fractions; the strongest applies, they don't stack).
function Enemies.addStatus(enemy: Enemy, status: string, amount: number, seconds: number)
	local now = os.clock()
	if status == "Stun" then
		enemy.StunUntil = math.max(enemy.StunUntil, now + seconds)
		Enemies.controlThreat(enemy)
	elseif status == "Slow" then
		enemy.Slow = if now < enemy.SlowUntil then math.max(enemy.Slow, amount) else amount
		enemy.SlowUntil = math.max(enemy.SlowUntil, now + seconds)
	elseif status == "Sunder" then
		local current = if now < enemy.SunderUntil then enemy.Sunder else 0
		enemy.Sunder = math.min(amount * 3, current + amount)
		enemy.SunderUntil = now + seconds
	elseif status == "Vulnerable" or status == "Aura" then
		local untilKey = status .. "Until"
		local e = enemy :: any
		e[status] = math.max(if now < e[untilKey] then e[status] else 0, amount)
		e[untilKey] = math.max(e[untilKey], now + seconds)
	elseif status == "Blind" then
		local e = enemy :: any
		e.Blind = amount
		e.BlindUntil = math.max(e.BlindUntil or 0, now + seconds)
	elseif status == "Weaken" then
		enemy.Weaken = math.max(if now < enemy.WeakenUntil then enemy.Weaken else 0, amount)
		enemy.WeakenUntil = now + seconds
	end
end

-- Damage over time: `total` spread over ticks every half second.
-- `status` names it on the status bar ("Burning", "Bleeding").
function Enemies.addDot(enemy: Enemy, total: number, seconds: number, source: Player?, color: Color3, status: string?)
	local ticks = math.max(1, math.floor(seconds / 0.5))
	table.insert(
		enemy.Dots,
		{ PerTick = total / ticks, Ticks = ticks, Source = source, Color = color, Status = status or "Bleeding" }
	)
end

-- A gem burn: `perTick` every second for `seconds`. A new hit refreshes the
-- caster's burn (latest strength, longest time) rather than stacking another.
function Enemies.setBurn(enemy: Enemy, perTick: number, seconds: number, source: Player?, color: Color3)
	local ticks = math.max(1, math.ceil(seconds - 1e-6))
	for _, dot in enemy.Dots do
		if dot.Key == "GemBurn" and dot.Source == source then
			dot.PerTick = perTick
			dot.Ticks = math.max(dot.Ticks, ticks)
			return
		end
	end
	table.insert(enemy.Dots, {
		Key = "GemBurn",
		Status = "Burning",
		PerTick = perTick,
		Ticks = ticks,
		Every = 2,
		Wait = 0,
		Source = source,
		Color = color,
	})
end

-- Stunning or interrupting it makes it angry: a spike of threat for the
-- player whose blow did it (the stun or interrupt rides on that blow).
function Enemies.controlThreat(enemy: Enemy)
	local now = os.clock()
	local source = enemy.LastSource
	if source and source.Parent and now - enemy.LastSourceAt < 0.5 then
		Aggro.add(enemy.Threat, enemy.ThreatAt, source, enemy.Humanoid.MaxHealth * Aggro.ControlThreat, now)
	end
end

function Enemies.taunt(enemy: Enemy, player: Player, seconds: number)
	enemy.Taunter = player
	enemy.TauntUntil = os.clock() + seconds
end

-- Its buffs and debuffs, written to the model's "Statuses" attribute for
-- clients' status bars (see Shared.StatusEffects). Times are server time.
local clockOffset
local function serverTime(t: number): number
	if not clockOffset then
		local ok, server = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		clockOffset = if ok and type(server) == "number" then server - os.clock() else 0
	end
	return t + clockOffset
end

function Enemies.statuses(enemy: Enemy, now: number)
	local list = {}
	local function add(id: string, ends: number, value: number?)
		if ends > now then
			table.insert(list, { Id = id, Ends = serverTime(ends), Value = value or 0 })
		end
	end
	local e = enemy :: any
	add(e.StunKind or "Stunned", enemy.StunUntil)
	for _, dot in enemy.Dots do
		-- Ticks every half second, or every `Every` half-seconds.
		local every = (dot.Every or 1) * 0.5
		add(dot.Status or "Bleeding", now + dot.Ticks * every - (dot.Wait or 0) * 0.5)
	end
	add("Slowed", enemy.SlowUntil, enemy.Slow * 100)
	add("ArmorShred", enemy.SunderUntil, enemy.Sunder * 100)
	add("Vulnerable", enemy.VulnerableUntil, enemy.Vulnerable * 100)
	add("Exposed", e.AuraUntil or 0, (e.Aura or 0) * 100)
	add("Weakened", enemy.WeakenUntil, enemy.Weaken * 100)
	add("Blinded", e.BlindUntil or 0, (e.Blind or 0) * 100)
	add("Silenced", e.SilenceUntil or 0)
	add("RiposteStance", e.RiposteUntil or 0)
	add(if e.WardKind == "Burn" then "BurningWard" else "StaticShell", e.WardUntil or 0)
	-- A rival's own buffs.
	local duel = e.Duel
	if duel then
		local armor = duel.ArmorBuffs
		if armor and (armor.Barrier or 0) > 0 then
			add("Shielded", armor.BarrierUntil or 0, armor.Barrier)
		end
		add("CryoShield", duel.CryoUntil or 0)
		add("ResonanceEcho", duel.EchoUntil or 0)
	end
	for kind, ends in e.HealCuts or {} do
		add(kind, ends)
	end
	return list
end

local function publishStatuses(enemy: Enemy, now: number)
	local text = StatusEffects.encode(Enemies.statuses(enemy, now), serverTime(now))
	local value = if text == "" then nil else text
	if enemy.Model:GetAttribute("Statuses") ~= value then
		enemy.Model:SetAttribute("Statuses", value)
	end
end

-- Anti-heal on an enemy (Grievous Wounds, Mortal Strike), like on players.
function Enemies.healCut(enemy: Enemy, kind: string)
	local e = enemy :: any
	e.HealCuts = e.HealCuts or {}
	e.HealCuts[kind] = os.clock() + CrowdControl.HealCutSeconds
end

-- Multiply this enemy's healing by this.
function Enemies.healingMultiplier(enemy: Enemy): number
	return CrowdControl.healingMultiplier({ HealCuts = (enemy :: any).HealCuts or {} } :: any, os.clock())
end

-- How much less damage this enemy deals right now (Poison weakens).
function Enemies.weakness(enemy: Enemy): number
	return if os.clock() < enemy.WeakenUntil then enemy.Weaken else 0
end

-- Thinking -----------------------------------------------------------------------------------

local function fighterRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and root and Combat.canFight(root.Position) then
		return root
	end
	return nil
end

-- Who it attacks: a taunter, else Shared.Aggro's choice (most threat, with
-- the overtake, low-health and unreachable rules) among players it can see.
local function pickTarget(enemy: Enemy): (Player?, BasePart?)
	local now = os.clock()
	if enemy.Taunter and now < enemy.TauntUntil then
		local root = fighterRoot(enemy.Taunter)
		if root then
			enemy.Aggro.Target, enemy.Aggro.Since = enemy.Taunter, now
			return enemy.Taunter, root
		end
	end
	Aggro.fade(enemy.Threat, enemy.ThreatAt, now - (enemy.LastThink or now), now)
	enemy.LastThink = now
	-- Once hurt, a monster keeps chasing a bit further.
	local reach = enemy.Kind.Aggro * (if now - enemy.LastHit < 6 then 1.6 else 1)
	local candidates, roots = {}, {}
	for _, player in Players:GetPlayers() do
		local root = fighterRoot(player)
		if root then
			local distance = (root.Position - enemy.Root.Position).Magnitude
			local threat = enemy.Threat[player] or 0
			-- Players who've hurt it are chased anywhere inside its leash.
			if (distance < reach or threat > 0) and (root.Position - enemy.Home).Magnitude < LEASH then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
				roots[player] = root
				table.insert(candidates, {
					Key = player,
					Threat = threat,
					Distance = distance,
					InReach = distance <= enemy.Kind.Reach + 1,
					HealthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth),
				})
			end
		end
	end
	local target = Aggro.choose(enemy.Aggro, candidates, now)
	return target, target and roots[target]
end

local function think(enemy: Enemy, now: number)
	local humanoid, root = enemy.Humanoid, enemy.Root
	if now < enemy.StunUntil then
		humanoid:MoveTo(root.Position)
		return
	end
	humanoid.WalkSpeed = enemy.Kind.Speed * (1 - (if now < enemy.SlowUntil then enemy.Slow else 0))
	local fromHome = (root.Position - enemy.Home).Magnitude
	local target, targetRoot = pickTarget(enemy)
	if not target or not targetRoot or fromHome > LEASH then
		-- Walk home and heal up.
		if fromHome > 4 then
			humanoid:MoveTo(enemy.Home)
		end
		if fromHome > LEASH * 0.5 or now - enemy.LastHit > 6 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.05)
			updateBar(enemy)
			if humanoid.Health >= humanoid.MaxHealth then
				table.clear(enemy.Damage)
				table.clear(enemy.Threat)
				table.clear(enemy.ThreatAt)
				enemy.Aggro = Aggro.new()
			end
		end
		return
	end
	local distance = (targetRoot.Position - root.Position).Magnitude
	if distance > enemy.Kind.Reach then
		humanoid:MoveTo(targetRoot.Position)
	else
		humanoid:MoveTo(root.Position)
		if now - enemy.LastAttack >= enemy.Kind.Rate then
			enemy.LastAttack = now
			fx("EnemySwing", root.Position, targetRoot.Position, GemConfig.ElementColors[enemy.Element or "Fire"])
			local damage = enemy.Kind.Damage * (1 - Enemies.weakness(enemy))
			Enemies.hitPlayer(target, damage, enemy.Element, enemy)
		end
	end
end

local function tickDots(enemy: Enemy)
	for i = #enemy.Dots, 1, -1 do
		local dot = enemy.Dots[i]
		dot.Wait = (dot.Wait or 0) + 1
		if dot.Wait >= (dot.Every or 1) then
			dot.Wait = 0
			dot.Ticks -= 1
			local previous = DamageLog.push(dot.Status or "Bleeding", if dot.Status == "Burning" then "Fire" else nil)
			Enemies.damage(
				enemy,
				dot.PerTick,
				dot.Source,
				false,
				dot.Color,
				nil,
				if dot.Status == "Burning" then "Fire" else nil
			)
			DamageLog.pop(previous)
			if dot.Ticks <= 0 then
				table.remove(enemy.Dots, i)
			end
		end
		if not enemy.Alive then
			return
		end
	end
end

function Enemies.start(trainingOnly: boolean?)
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace

	-- The Arena floor has no standing targets: each Arena session brings its
	-- own rival or sparring partner (see Duelist).
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	if not trainingOnly then
		for _, camp in CAMPS do
			spawn(camp[1], Enemies.WildsCenter + camp[2])
		end
	end
	if landmarks then
		landmarks:SetAttribute("Wilds", Enemies.WildsCenter)
	end

	local thinkTimer, dotTimer = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		thinkTimer += dt
		dotTimer += dt
		local now = os.clock()
		if thinkTimer >= 0.15 then
			thinkTimer = 0
			for _, enemy in enemies do
				if enemy.Alive then
					if enemy.Kind.Dummy then
						-- Dummies heal back to full once left alone.
						if now - enemy.LastHit > 4 and enemy.Humanoid.Health < enemy.Humanoid.MaxHealth then
							enemy.Humanoid.Health = enemy.Humanoid.MaxHealth
							updateBar(enemy)
						end
					elseif enemy.Brain then
						enemy.Brain(enemy, now)
					else
						think(enemy, now)
					end
					if enemy.Alive then
						publishStatuses(enemy, now)
					end
				end
			end
		end
		if dotTimer >= 0.5 then
			dotTimer = 0
			for _, enemy in enemies do
				if enemy.Alive and #enemy.Dots > 0 then
					tickDots(enemy)
				end
			end
		end
	end)
end

return Enemies
