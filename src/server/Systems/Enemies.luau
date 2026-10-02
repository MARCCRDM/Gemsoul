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
local Gems = require(script.Parent.Gems)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)

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
		DropChance = 0.35,
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
		DropChance = 1,
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
}

local enemies: { [Model]: Enemy } = {}
local folder: Folder

-- Hooks CombatServer fills in (avoids the two modules requiring each other).
Enemies.hitPlayer = function(_player: Player, _amount: number, _element: string?, _enemy: Enemy) end

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
	board.Size = UDim2.fromOffset(120, 30)
	board.StudsOffset = Vector3.new(0, height, 0)
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
	fx("Death", enemy.Root.Position, if enemy.Element then GemConfig.ElementColors[enemy.Element] else nil)
	reward(enemy)
	local model = enemy.Model
	task.delay(0.6, function()
		enemies[model] = nil
		model:Destroy()
	end)
	task.delay(enemy.Kind.Respawn, spawn, enemy.KindId, enemy.Home)
end

-- Deals damage. `color` tints the floating number (element hits, crits).
function Enemies.damage(enemy: Enemy, amount: number, source: Player?, crit: boolean?, color: Color3?)
	if not enemy.Alive or amount <= 0 then
		return
	end
	amount = math.floor(amount * (1 + Enemies.exposure(enemy)) + 0.5)
	local humanoid = enemy.Humanoid
	enemy.LastHit = os.clock()
	if source then
		if amount > 0 then
			Remotes.CombatFx:FireClient(source, "HitConfirm", crit == true)
		end
		enemy.Damage[source] = (enemy.Damage[source] or 0) + amount
		local loadout = PlayerData.character(source)
		local bonus = if loadout then Classes.effects(loadout).ThreatGeneration or 0 else 0
		enemy.Threat[source] = (enemy.Threat[source] or 0) + amount * (1 + bonus)
	end
	fx("Damage", enemy.Root.Position + Vector3.new(0, enemy.Root.Size.Y / 2 + 1, 0), amount, crit == true, color)
	if enemy.Kind.Dummy then
		-- Dummies never break; they just count.
		humanoid.Health = math.max(1, humanoid.Health - amount)
		updateBar(enemy)
		return
	end
	humanoid.Health = math.max(0, humanoid.Health - amount)
	updateBar(enemy)
	if humanoid.Health <= 0 then
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
-- Vulnerable and Aura (fractions; the strongest applies, they don't stack).
function Enemies.addStatus(enemy: Enemy, status: string, amount: number, seconds: number)
	local now = os.clock()
	if status == "Stun" then
		enemy.StunUntil = math.max(enemy.StunUntil, now + seconds)
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
	elseif status == "Weaken" then
		enemy.Weaken = math.max(if now < enemy.WeakenUntil then enemy.Weaken else 0, amount)
		enemy.WeakenUntil = now + seconds
	end
end

-- Damage over time: `total` spread over ticks every half second.
function Enemies.addDot(enemy: Enemy, total: number, seconds: number, source: Player?, color: Color3)
	local ticks = math.max(1, math.floor(seconds / 0.5))
	table.insert(enemy.Dots, { PerTick = total / ticks, Ticks = ticks, Source = source, Color = color })
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
	table.insert(
		enemy.Dots,
		{ Key = "GemBurn", PerTick = perTick, Ticks = ticks, Every = 2, Wait = 0, Source = source, Color = color }
	)
end

function Enemies.taunt(enemy: Enemy, player: Player, seconds: number)
	enemy.Taunter = player
	enemy.TauntUntil = os.clock() + seconds
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

local function pickTarget(enemy: Enemy): (Player?, BasePart?)
	local now = os.clock()
	if enemy.Taunter and now < enemy.TauntUntil then
		local root = fighterRoot(enemy.Taunter)
		if root then
			return enemy.Taunter, root
		end
	end
	local best, bestRoot, bestDistance = nil, nil, enemy.Kind.Aggro
	local bestThreat = -1
	for _, player in Players:GetPlayers() do
		local root = fighterRoot(player)
		if root then
			local distance = (root.Position - enemy.Root.Position).Magnitude
			-- Once hurt, a monster keeps chasing a bit further.
			local reach = enemy.Kind.Aggro * (if now - enemy.LastHit < 6 then 1.6 else 1)
			local threat = enemy.Threat[player] or 0
			if
				distance < reach
				and (root.Position - enemy.Home).Magnitude < LEASH
				and (threat > bestThreat or (threat == bestThreat and distance < bestDistance))
			then
				bestThreat = threat
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot
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
			Enemies.damage(enemy, dot.PerTick, dot.Source, false, dot.Color)
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

	-- Training dummies in a ring on the Arena floor, facing the middle.
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local arena = landmarks and landmarks:GetAttribute("ArenaFloor")
	if typeof(arena) == "Vector3" then
		for i = 1, 4 do
			local angle = math.rad(i * 90 + 45)
			local spot = arena + Vector3.new(math.cos(angle) * 12, 0.7, math.sin(angle) * 12)
			spawn("Dummy", spot, (arena - spot).Unit)
		end
	end
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
					else
						think(enemy, now)
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
