--[[
	The Meteor Golem (Shared.MeteorGolem): a new miner's first boss.

	  MeteorGolemServer.start()           (Main, with the Outpost)
	  MeteorGolemServer.swing(player)     a swing at a rock landed (Main chains
	                                      it on OutpostServer.onSwing): the
	                                      first one, eligible, starts the clock
	  MeteorGolemServer.send(player)      the meteor now (once the clock's up)

	Its fall, for everyone near: the meteor (Client.MeteorGolemFx draws it
	and, for whoever it's for, the cinematic: Remotes.MeteorGolem "Fall",
	{ Spot, Start, Owner }); then here, on the beats of Shared.MeteorGolem:
	its crater and the glowing rock in it at Fall, the rock cracking at Crack,
	the golem climbing out of it from Rise to Awake. Its player stands still
	for it, then their combat kit comes out (SparServer.riftKit), and the
	golem's a creature like any (Enemies.adopt, OutpostCreature: your kaiju
	fight it) with a brain of its own: it walks at them, and every Every
	seconds throws a blow, its ring on the ground first (Slam round it close
	in, Rock where they stand from further out). Beaten, it crumbles where it
	stands, and its player gets its cache (ArenaStreaks.bossCache, threat I,
	no kaiju roll) and the milestone; walked away from (past Leash for
	LeashTime), or its player down or gone, it sinks back into its crater,
	and comes again at a swing Retry seconds later.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Rules = require(ReplicatedStorage.Shared.MeteorGolem)
local Enemies = require(script.Parent.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local MeteorGolemServer = {}

local BASALT = Color3.fromRGB(46, 36, 34)
local BASALT_DARK = Color3.fromRGB(30, 23, 22)
local MAGMA = Color3.fromRGB(255, 112, 32)
local MAGMA_HOT = Color3.fromRGB(255, 196, 90)
local WARN = Color3.fromRGB(255, 70, 40)

type Golem = {
	Owner: Player,
	Spot: Vector3,
	Start: number,
	Folder: Folder,
	Enemy: any?,
	Phase: string, -- "Falling" | "Awake" | "Gone"
	Next: number,
	Busy: number,
	Rocks: number,
	FarSince: number?,
	WalkSpeed: number?,
}
local golems: { [Player]: Golem } = {}
local waiting: { [Player]: number } = {} -- the clock: when the meteor comes
local retryAt: { [Player]: number } = {}

-- Bits and pieces -------------------------------------------------------------------------------------------

local function part(parent: Instance, props): BasePart
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function attrsOf(player: Player)
	return {
		Outpost = player:GetAttribute("Outpost"),
		CombatSession = player:GetAttribute("CombatSession"),
		MatchId = player:GetAttribute("MatchId"),
		FirstFight = player:GetAttribute("FirstFight"),
		IntroCover = player:GetAttribute("IntroCover"),
		DungeonId = player:GetAttribute("DungeonId"),
		MechPilot = player:GetAttribute("MechPilot"),
		KaijuBattle = player:GetAttribute("KaijuBattle"),
	}
end

-- The ground under `at` (characters, creatures and kaiju left out).
local function ground(at: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	for _, name in { "Enemies", "Kaiju", "MeteorGolems" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(at + Vector3.new(0, 160, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position
end

-- Where it comes down: Land studs ahead of them, on the ground there.
local function spotFor(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local ahead = Vector3.new(look.X, 0, look.Z)
	ahead = if ahead.Magnitude > 0.1 then ahead.Unit else Vector3.new(0, 0, -1)
	local want = root.Position + ahead * Rules.Land
	return ground(want) or ground(root.Position + ahead * (Rules.Land * 0.5)) or (root.Position - Vector3.new(0, 3, 0))
end

local function fadeOut(p: BasePart, seconds: number)
	TweenService:Create(p, TweenInfo.new(seconds), { Transparency = 1 }):Play()
end

-- A flash of molten light: a hot ball swelling and fading, a light with it.
local function burst(parent: Instance, at: Vector3, size: number)
	local ball = part(parent, {
		Class = "Part",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.3,
		CFrame = CFrame.new(at),
		Material = Enum.Material.Neon,
		Color = MAGMA_HOT,
		Transparency = 0.1,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = MAGMA, size * 3, 4
	light.Parent = ball
	TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size * 2,
		Transparency = 1,
		Color = MAGMA,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	task.delay(0.7, function()
		ball:Destroy()
	end)
end

-- Its crater: a dark scorched disc, a molten rim, rubble thrown round it.
local function crater(folder: Folder, at: Vector3)
	local flat = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part(folder, {
		Class = "Part",
		Name = "Scorch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 22, 22),
		CFrame = flat + Vector3.new(0, 0.12, 0),
		Material = Enum.Material.Basalt,
		Color = BASALT_DARK,
		CastShadow = false,
	})
	part(folder, {
		Class = "Part",
		Name = "Glow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.32, 12, 12),
		CFrame = flat + Vector3.new(0, 0.14, 0),
		Material = Enum.Material.Neon,
		Color = MAGMA,
		Transparency = 0.35,
		CastShadow = false,
	})
	local rng = Random.new()
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local d = rng:NextNumber(8, 12)
		local s = rng:NextNumber(1.2, 2.8)
		part(folder, {
			Name = "Rubble",
			Size = Vector3.new(s, s * 0.8, s * 1.1),
			CFrame = CFrame.new(at + Vector3.new(math.cos(a) * d, s * 0.25, math.sin(a) * d))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.3), rng:NextNumber(-0.5, 0.5)),
			Material = Enum.Material.Basalt,
			Color = if i % 3 == 0 then BASALT_DARK else BASALT,
		})
	end
end

-- The meteor in its crater: a glowing rock, half sunk, cracks of magma on it.
local function boulder(folder: Folder, at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Meteorite"
	model.Parent = folder
	part(model, {
		Class = "Part",
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0)),
		Material = Enum.Material.Basalt,
		Color = BASALT,
	})
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		part(model, {
			Name = "Crack",
			Size = Vector3.new(0.35, 5.5, 0.35),
			CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.new(0, 0, -4.35)
				* CFrame.Angles(0, 0, math.rad(20 * ((i % 3) - 1))),
			Material = Enum.Material.Neon,
			Color = MAGMA,
			CastShadow = false,
		})
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = MAGMA, 22, 2.5
	light.Parent = model.PrimaryPart or model:FindFirstChild("Core")
	return model
end

-- The golem ---------------------------------------------------------------------------------------------------

-- Its body, about 13 studs tall, facing -Z: a rig (a Humanoid and its root)
-- with rock welded on, magma in its cracks, its arms on shoulders that turn
-- (Motor6D) for its blows.
local ROOT_H, HIP = 5, 4.5
local function golemRig(): Model
	local model = Instance.new("Model")
	model.Name = Rules.Boss.Name
	local root = part(model, {
		Name = "HumanoidRootPart",
		Size = Vector3.new(5, ROOT_H, 3.5),
		Transparency = 1,
		CanCollide = true,
		CastShadow = false,
	})
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = HIP
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.Parent = model
	local function rock(parent: Instance, anchor: BasePart, name: string, size: Vector3, at: CFrame, color: Color3?, magma: boolean?)
		local p = part(parent, {
			Name = name,
			Size = size,
			CFrame = anchor.CFrame * at,
			Material = if magma then Enum.Material.Neon else Enum.Material.Basalt,
			Color = color or (if magma then MAGMA else BASALT),
			CastShadow = not magma,
			Massless = true,
		})
		p.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = anchor, p
		weld.Parent = p
		return p
	end
	local function on(name, size, x, y, z, rx, ry, rz, color, magma)
		return rock(model, root, name, size, CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0)), color, magma)
	end
	-- Chest and belly: big slabs, a little askew.
	on("Chest", Vector3.new(7, 4.6, 4.4), 0, 1.2, 0, 0, 0, 3)
	on("Belly", Vector3.new(5.4, 2.6, 3.8), 0, -1.9, 0.1, 0, 0, -4, BASALT_DARK)
	on("Back", Vector3.new(6, 3.6, 1.6), 0, 1.6, 2.4, 8, 0, 0, BASALT_DARK)
	-- Its core, burning through the chest, and the cracks running out of it.
	local core = on("Core", Vector3.new(1.9, 1.9, 0.4), 0, 1.4, -2.25, 0, 0, 45, MAGMA_HOT, true)
	core.Shape = Enum.PartType.Block
	for i, c in { { -1.6, 2.4, 30 }, { 1.7, 2.2, -35 }, { -1.2, -0.2, -40 }, { 1.4, 0, 50 }, { 0.2, 3.1, 0 } } do
		on("Crack" .. i, Vector3.new(0.22, 2.4, 0.15), c[1], c[2], -2.24, 0, 0, c[3], nil, true)
	end
	-- Its head: a craggy block, two burning eyes and a molten mouth.
	on("Head", Vector3.new(3.2, 2.6, 2.8), 0, 4.8, -0.5, -6, 0, 0)
	on("Brow", Vector3.new(3.5, 0.7, 1), 0, 5.5, -1.85, -12, 0, 0, BASALT_DARK)
	on("EyeL", Vector3.new(0.75, 0.42, 0.12), -0.75, 4.95, -1.95, 0, 0, -8, MAGMA_HOT, true)
	on("EyeR", Vector3.new(0.75, 0.42, 0.12), 0.75, 4.95, -1.95, 0, 0, 8, MAGMA_HOT, true)
	on("Mouth", Vector3.new(1.6, 0.28, 0.12), 0, 4.05, -1.95, 0, 0, 0, MAGMA, true)
	-- Shoulders, and legs down to the ground.
	on("ShoulderL", Vector3.new(2.8, 2.4, 2.8), -4.5, 2.9, 0, 0, 0, 12)
	on("ShoulderR", Vector3.new(2.8, 2.4, 2.8), 4.5, 2.9, 0, 0, 0, -12)
	for _, side in { -1, 1 } do
		on("Leg", Vector3.new(2.4, 4.4, 2.6), 1.7 * side, -4.6, 0.2, 0, 0, 0, BASALT_DARK)
		on("Foot", Vector3.new(2.9, 0.9, 3.4), 1.7 * side, -6.55, -0.25, 0, 0, 0)
		on("Knee", Vector3.new(0.2, 1.6, 0.12), 1.7 * side, -4.2, -1.12, 0, 0, 12 * side, nil, true)
	end
	-- The arms: each on a shoulder joint that turns (Motor6D: its C0 is what
	-- a blow tweens), hanging, a fist of rock and magma at the end.
	local arms = {}
	for _, side in { -1, 1 } do
		local shoulder = part(model, {
			Name = if side < 0 then "ArmL" else "ArmR",
			Size = Vector3.new(0.5, 0.5, 0.5),
			Transparency = 1,
			Massless = true,
			CastShadow = false,
		})
		shoulder.Anchored = false
		local joint = Instance.new("Motor6D")
		joint.Name = "Shoulder"
		joint.Part0, joint.Part1 = root, shoulder
		joint.C0 = CFrame.new(4.6 * side, 2.4, 0)
		joint.Parent = root
		shoulder.CFrame = root.CFrame * joint.C0
		rock(model, shoulder, "Upper", Vector3.new(2.2, 3.8, 2.2), CFrame.new(0, -2.2, 0) * CFrame.Angles(0, 0, math.rad(-6 * side)))
		rock(model, shoulder, "Fist", Vector3.new(3.1, 3.2, 3.1), CFrame.new(0.2 * side, -5.4, -0.4) * CFrame.Angles(math.rad(8), 0, 0), BASALT_DARK)
		rock(model, shoulder, "Knuckles", Vector3.new(2.6, 0.3, 0.15), CFrame.new(0.2 * side, -6.1, -1.98), nil, true)
		rock(model, shoulder, "Vein", Vector3.new(0.2, 3, 0.12), CFrame.new(0, -2.4, -1.12) * CFrame.Angles(0, 0, math.rad(15 * side)), nil, true)
		table.insert(arms, { Joint = joint, Rest = joint.C0 })
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = MAGMA, 16, 1.6
	glow.Parent = core
	model:SetAttribute("Arms", #arms)
	;(model :: any)._arms = arms
	return model
end

-- Its arms to `angle` (degrees about X: 0 hanging, 160 overhead, 60 struck
-- down in front) over `seconds`.
local function arms(golem: Golem, angle: number, seconds: number)
	local model = golem.Enemy and golem.Enemy.Model
	local root = model and model.PrimaryPart
	if not root then
		return
	end
	for _, joint in root:GetChildren() do
		if joint:IsA("Motor6D") and joint.Name == "Shoulder" then
			local rest = CFrame.new(joint.C0.Position)
			TweenService:Create(
				joint,
				TweenInfo.new(seconds, if angle < 90 then Enum.EasingStyle.Quad else Enum.EasingStyle.Sine, if angle < 90 then Enum.EasingDirection.In else Enum.EasingDirection.Out),
				{ C0 = rest * CFrame.Angles(math.rad(angle), 0, 0) }
			):Play()
		end
	end
end

-- A blow's ring on the ground at `at`: from small to its full `radius` over
-- `seconds`, red and growing brighter, then gone as the blow lands.
local function ring(golem: Golem, at: Vector3, radius: number, seconds: number)
	local flat = CFrame.new(at + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = part(golem.Folder, {
		Class = "Part",
		Name = "Warning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, radius * 0.6, radius * 0.6),
		CFrame = flat,
		Material = Enum.Material.Neon,
		Color = WARN,
		Transparency = 0.7,
		CastShadow = false,
	})
	local edge = part(golem.Folder, {
		Class = "Part",
		Name = "WarningEdge",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		CFrame = flat - Vector3.new(0, 0.02, 0),
		Material = Enum.Material.Neon,
		Color = WARN,
		Transparency = 0.55,
		CastShadow = false,
	})
	TweenService:Create(disc, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Transparency = 0.35,
	}):Play()
	task.delay(seconds, function()
		disc:Destroy()
		edge:Destroy()
	end)
end

-- Everyone (and their kaiju's owner's) in `radius` of `at` hit by a blow.
local function strike(golem: Golem, at: Vector3, radius: number, share: number)
	local enemy = golem.Enemy
	if not enemy or not enemy.Alive then
		return
	end
	burst(golem.Folder, at + Vector3.new(0, 1, 0), radius)
	for _, player in Players:GetPlayers() do
		local root, humanoid = rootOf(player), humanoidOf(player)
		if root and humanoid and humanoid.Health > 0 then
			local apart = root.Position - at
			if Vector3.new(apart.X, 0, apart.Z).Magnitude <= radius + 1 and math.abs(apart.Y) < radius + 6 then
				pcall(Enemies.hitPlayer, player, math.floor(humanoid.MaxHealth * share + 0.5), "Fire", enemy, true)
			end
		end
	end
	Remotes.MeteorGolem:FireAllClients("Blow", { At = at, Radius = radius })
end

-- A Slam: arms overhead, its ring round it, then both fists down.
local function slam(golem: Golem, now: number)
	local enemy = golem.Enemy
	local rule = Rules.Slam
	local at = enemy.Root.Position - Vector3.new(0, ROOT_H / 2 + HIP, 0) + enemy.Root.CFrame.LookVector * 4
	golem.Busy = now + rule.Windup + 0.55
	enemy.Humanoid.WalkSpeed = 0
	arms(golem, 160, rule.Windup * 0.8)
	ring(golem, at, rule.Radius, rule.Windup)
	task.delay(rule.Windup - 0.12, function()
		arms(golem, 55, 0.12)
	end)
	task.delay(rule.Windup, function()
		strike(golem, at, rule.Radius, rule.Share)
	end)
	task.delay(rule.Windup + 0.45, function()
		arms(golem, 0, 0.4)
		if enemy.Alive then
			enemy.Humanoid.WalkSpeed = Rules.Speed
		end
	end)
	golem.Rocks = 0
end

-- A Rock: it tears one out of itself and lobs it where you stand (its ring
-- there), a molten ball arcing over.
local function hurl(golem: Golem, target: Vector3, now: number)
	local enemy = golem.Enemy
	local rule = Rules.Rock
	local at = ground(target) or target
	golem.Busy = now + rule.Windup + 0.3
	enemy.Humanoid.WalkSpeed = 0
	arms(golem, 150, rule.Windup - rule.Flight)
	ring(golem, at, rule.Radius, rule.Windup)
	task.delay(rule.Windup - rule.Flight, function()
		if not enemy.Alive then
			return
		end
		arms(golem, 20, 0.2)
		local from = enemy.Root.Position + Vector3.new(0, 8, 0)
		local ball = part(golem.Folder, {
			Class = "Part",
			Name = "MoltenRock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = CFrame.new(from),
			Material = Enum.Material.Neon,
			Color = MAGMA,
			CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = MAGMA, 12, 2
		light.Parent = ball
		local started = os.clock()
		while os.clock() - started < rule.Flight do
			local t = (os.clock() - started) / rule.Flight
			ball.CFrame = CFrame.new(from:Lerp(at, t) + Vector3.new(0, math.sin(t * math.pi) * 12, 0))
			task.wait()
		end
		ball:Destroy()
		strike(golem, at, rule.Radius, rule.Share)
		if enemy.Alive then
			enemy.Humanoid.WalkSpeed = Rules.Speed
			arms(golem, 0, 0.4)
		end
	end)
	golem.Rocks += 1
end

-- Gone without a win: it sinks back down, and can come again later.
local function stand(golem: Golem, why: string?)
	if golem.Phase == "Gone" then
		return
	end
	golem.Phase = "Gone"
	golems[golem.Owner] = nil
	retryAt[golem.Owner] = os.clock() + Rules.Retry
	local humanoid = humanoidOf(golem.Owner)
	if humanoid and golem.WalkSpeed and humanoid.WalkSpeed == 0 then
		humanoid.WalkSpeed = golem.WalkSpeed
	end
	if golem.Enemy and golem.Enemy.Alive then
		Enemies.remove(golem.Enemy)
	end
	if why and golem.Owner.Parent then
		Remotes.Notify:FireClient(golem.Owner, why)
	end
	task.delay(4, function()
		golem.Folder:Destroy()
	end)
end

-- Its thinking (Enemies' tick): after its player, a blow when it can.
local function brain(enemy, now: number)
	local golem = (enemy :: any).Golem :: Golem
	if not golem or golem.Phase ~= "Awake" then
		return
	end
	local owner = golem.Owner
	local root, humanoid = rootOf(owner), humanoidOf(owner)
	if not owner.Parent or not root or not humanoid or humanoid.Health <= 0 or owner:GetAttribute("Outpost") ~= true then
		stand(golem, if owner.Parent and humanoid and humanoid.Health <= 0 then "The Magma Golem sank back into its crater. It'll be back..." else nil)
		return
	end
	if (root.Position - golem.Spot).Magnitude > Rules.Leash then
		golem.FarSince = golem.FarSince or now
		if now - golem.FarSince > Rules.LeashTime then
			stand(golem, "You left the Magma Golem behind: it sank back into its crater.")
			return
		end
	else
		golem.FarSince = nil
	end
	if now < golem.Busy then
		return
	end
	local apart = root.Position - enemy.Root.Position
	local distance = Vector3.new(apart.X, 0, apart.Z).Magnitude
	-- Face them, and come on.
	local flat = Vector3.new(root.Position.X, enemy.Root.Position.Y, root.Position.Z)
	if (flat - enemy.Root.Position).Magnitude > 0.5 then
		enemy.Root.CFrame = CFrame.lookAt(enemy.Root.Position, flat)
	end
	if distance > Rules.Slam.Reach * 0.6 then
		enemy.Humanoid:MoveTo(root.Position)
	else
		enemy.Humanoid:MoveTo(enemy.Root.Position)
	end
	if now >= golem.Next then
		local blow = Rules.blow(distance, golem.Rocks)
		if blow == "Slam" then
			golem.Next = now + Rules.Every + Rules.Slam.Windup
			slam(golem, now)
		elseif blow == "Rock" then
			golem.Next = now + Rules.Every + Rules.Rock.Windup
			hurl(golem, root.Position, now)
		end
	end
end

-- It falls: its pieces crumble apart where it stood, glowing out; its
-- player's cache (no kaiju roll) and the milestone.
local function died(enemy)
	local golem = (enemy :: any).Golem :: Golem
	if not golem then
		return
	end
	golem.Phase = "Gone"
	golems[golem.Owner] = nil
	local rng = Random.new()
	local center = enemy.Root.Position
	for _, p in enemy.Model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local bit = p:Clone()
			for _, child in bit:GetChildren() do
				if not child:IsA("Light") then
					child:Destroy()
				end
			end
			bit.Anchored = false
			bit.CanCollide = true
			bit.Massless = false
			bit.Parent = golem.Folder
			local out = (bit.Position - center) * Vector3.new(1, 0, 1)
			out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
			bit.AssemblyLinearVelocity = out * rng:NextNumber(6, 16) + Vector3.new(0, rng:NextNumber(4, 14), 0)
			bit.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4))
			p.Transparency = 1
			task.delay(2.6 + rng:NextNumber(0, 0.8), function()
				if bit.Parent then
					bit.Anchored = true
					fadeOut(bit, 1.2)
				end
			end)
		end
	end
	burst(golem.Folder, center, 10)
	Remotes.MeteorGolem:FireAllClients("Fell", { At = center })
	task.delay(10, function()
		golem.Folder:Destroy()
	end)
	local owner = golem.Owner
	local profile = owner.Parent and PlayerData.get(owner)
	if not profile then
		return
	end
	profile.Milestones = profile.Milestones or {}
	profile.Milestones[Rules.Id] = true
	retryAt[owner] = nil
	Remotes.Notify:FireClient(owner, "You beat the Magma Golem! Its cache is yours.")
	local ArenaStreaks = require(script.Parent.ArenaStreaks)
	pcall(ArenaStreaks.bossCache, owner, Rules.Boss, nil, "Meteor", { NoKaijuRoll = true })
	PlayerData.sync(owner)
end

-- It comes: the meteor, its crater, the golem climbing out.
function MeteorGolemServer.send(player: Player)
	if golems[player] then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	waiting[player] = nil
	local spot = spotFor(root)
	local holder = Workspace:FindFirstChild("MeteorGolems") or Instance.new("Folder")
	holder.Name = "MeteorGolems"
	holder.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "Golem_" .. player.UserId
	folder.Parent = holder
	local start = Workspace:GetServerTimeNow()
	local golem: Golem = {
		Owner = player,
		Spot = spot,
		Start = start,
		Folder = folder,
		Enemy = nil,
		Phase = "Falling",
		Next = 0,
		Busy = 0,
		Rocks = 0,
		FarSince = nil,
		WalkSpeed = nil,
	}
	golems[player] = golem
	-- They stand and watch it come (the cinematic: Client.MeteorGolemFx).
	local humanoid = humanoidOf(player)
	if humanoid then
		golem.WalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
	end
	Remotes.MeteorGolem:FireAllClients("Fall", { Spot = spot, Start = start, Owner = player.UserId })
	task.delay(Rules.Fall, function()
		if golem.Phase ~= "Falling" then
			return
		end
		crater(folder, spot)
		local rock = boulder(folder, spot)
		burst(folder, spot + Vector3.new(0, 2, 0), 14)
		task.delay(Rules.Crack - Rules.Fall, function()
			-- (cracking: its magma flaring brighter)
			for _, p in rock:GetDescendants() do
				if p:IsA("BasePart") and p.Name == "Crack" then
					TweenService:Create(p, TweenInfo.new(0.8), { Size = p.Size * Vector3.new(2.2, 1.2, 2.2), Color = MAGMA_HOT }):Play()
				end
			end
		end)
		task.delay(Rules.Rise - Rules.Fall, function()
			if golem.Phase ~= "Falling" then
				return
			end
			burst(folder, spot + Vector3.new(0, 3, 0), 12)
			rock:Destroy()
			-- The golem, climbing up out of the crater, held till it's out.
			local rig = golemRig()
			local stood = CFrame.new(spot + Vector3.new(0, HIP + ROOT_H / 2, 0))
			local facing = rootOf(player)
			if facing then
				local to = Vector3.new(facing.Position.X, stood.Position.Y, facing.Position.Z)
				if (to - stood.Position).Magnitude > 0.5 then
					stood = CFrame.lookAt(stood.Position, to)
				end
			end
			rig:PivotTo(stood - Vector3.new(0, 14, 0))
			rig.PrimaryPart.Anchored = true
			rig.Parent = folder
			local rise = Instance.new("CFrameValue")
			rise.Value = rig:GetPivot()
			rise.Changed:Connect(function(value)
				if rig.Parent then
					rig:PivotTo(value)
				end
			end)
			TweenService:Create(rise, TweenInfo.new(Rules.Awake - Rules.Rise, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = stood }):Play()
			task.delay(Rules.Awake - Rules.Rise, function()
				rise:Destroy()
				if golem.Phase ~= "Falling" or not rig.Parent then
					return
				end
				rig.PrimaryPart.Anchored = false
				local enemy = Enemies.adopt(rig, {
					Name = Rules.Boss.Name,
					Health = Rules.Health,
					Damage = 0,
					Speed = Rules.Speed,
					Reach = Rules.Slam.Reach,
					Rate = Rules.Every,
					Aggro = Rules.Leash,
					Coins = 0,
					DropChance = 0,
					Luck = 0,
					Respawn = 0,
				}, {
					Element = Rules.Boss.Element,
					Title = string.format("%s · Lv %d", Rules.Boss.Name, Rules.Level),
					Home = spot,
					Size = 2.4,
				})
				local e = enemy :: any
				e.OutpostCreature = true -- (your kaiju fight it)
				e.Golem = golem
				e.Brain = brain
				e.OnDeath = died
				enemy.Model:SetAttribute("MeteorGolem", player.UserId)
				golem.Enemy = enemy
				golem.Phase = "Awake"
				golem.Next = os.clock() + 1.5
				-- Their kit out to fight it, and on their feet again.
				local h = humanoidOf(player)
				if h and golem.WalkSpeed and h.WalkSpeed == 0 then
					h.WalkSpeed = golem.WalkSpeed
				end
				pcall(function()
					require(script.Parent.SparServer).riftKit(player, true)
				end)
			end)
		end)
	end)
	return true
end

-- A swing at a rock landed: the first one (eligible) starts the clock.
function MeteorGolemServer.swing(player: Player)
	if golems[player] or waiting[player] or os.clock() < (retryAt[player] or 0) then
		return
	end
	if not Rules.eligible(PlayerData.get(player), attrsOf(player)) then
		return
	end
	waiting[player] = os.clock() + Rules.Delay
end

local started = false
function MeteorGolemServer.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		waiting[player], retryAt[player] = nil, nil
		local golem = golems[player]
		if golem then
			stand(golem)
		end
	end)
	-- The clock: once it's up, if they're still about (and eligible), it comes.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for player, at in waiting do
				if now >= at then
					waiting[player] = nil
					if player.Parent and Rules.eligible(PlayerData.get(player), attrsOf(player)) then
						local humanoid = humanoidOf(player)
						if humanoid and humanoid.Health > 0 then
							MeteorGolemServer.send(player)
						end
					end
				end
			end
		end
	end)
end

MeteorGolemServer._golems = golems -- (tests)
return MeteorGolemServer
