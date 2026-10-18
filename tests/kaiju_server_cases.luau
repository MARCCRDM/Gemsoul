-- lune run tests/kaiju_server_cases.luau <repo>
-- Mini kaiju on the server, against stand-in Roblox pieces (the real
-- Shared.Kaiju, KaijuFight, KaijuAbilities, KaijuFighter, KaijuServer and
-- KaijuWilds; Enemies, CombatServer, PlayerData and the models are
-- stand-ins): every E ability lands where it should; your kaiju comes out
-- in the Outpost (a starter the first time), fights creatures near you and
-- is credited to you, is hurt by element, knocked out and back; recall;
-- switching; feeding; wild kaiju take blows with the spread and their
-- element, go after kaiju and hunters (never a miner); both fight as the
-- Arena's duellist (wind-ups, heavies that break a guard, parries that
-- leave the attacker reeling, hops, reading a hunter's charge, the E after
-- a wind-up, a whole duel between two kaiju); kills pay EXP and the
-- Gemsoul; taming (range, half health, tries, burrowing, a full roster).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

-- Time, randomness ------------------------------------------------------------------------------

local now = 1000
local forcedRoll: number? = nil -- what the next Random:NextNumber() returns, if set
local Random = {
	new = function(seed)
		local state = (seed or 7) % 2147483647
		if state <= 0 then
			state += 2147483646
		end
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = forcedRoll or state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			state = (state * 16807) % 2147483647
			return a + math.floor(state / 2147483647 * (b - a + 1))
		end
		return r
	end,
}
local delayed = {}
local task = {
	delay = function(seconds, fn, ...)
		table.insert(delayed, { At = now + seconds, Fn = fn, Args = { ... } })
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
}

-- Stand-in instances ---------------------------------------------------------------------------------

local function signal()
	local callbacks = {}
	local event = {}
	function event:Connect(fn)
		table.insert(callbacks, fn)
		return { Disconnect = function() end }
	end
	function event.Fire(...)
		for _, fn in callbacks do
			fn(...)
		end
	end
	return event
end

local Fake = {}
Fake.__index = function(self, key)
	return Fake[key] or rawget(self, "_props")[key]
end
Fake.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old and type(old) == "table" and rawget(old, "_children") then
			local list = rawget(old, "_children")
			local at = table.find(list, self)
			if at then
				table.remove(list, at)
			end
		end
		if value and type(value) == "table" and rawget(value, "_children") then
			table.insert(rawget(value, "_children"), self)
		end
	elseif key == "CFrame" and props.ClassName ~= "Camera" then
		props.Position = value.Position
	end
	props[key] = value
end
local function make(className: string, props)
	local self =
		setmetatable({ _props = { ClassName = className, Name = className }, _children = {}, _attributes = {} }, Fake)
	for key, value in props or {} do
		self[key] = value
	end
	return self
end
function Fake:IsA(className)
	return self.ClassName == className
		or (className == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart"))
end
function Fake:SetAttribute(key, value)
	rawget(self, "_attributes")[key] = value
end
function Fake:GetAttribute(key)
	return rawget(self, "_attributes")[key]
end
function Fake:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Fake:GetDescendants()
	local list = {}
	for _, child in rawget(self, "_children") do
		table.insert(list, child)
		for _, d in child:GetDescendants() do
			table.insert(list, d)
		end
	end
	return list
end
function Fake:FindFirstChild(name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function Fake:FindFirstChildOfClass(className)
	for _, child in rawget(self, "_children") do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end
function Fake:Destroy()
	self.Parent = nil
	rawget(self, "_props").Destroyed = true
end
function Fake:ClearAllChildren()
	for _, child in self:GetChildren() do
		child.Parent = nil
	end
end
function Fake:PivotTo(cf)
	local root = self.PrimaryPart
	if root then
		root.CFrame = cf
	end
end
function Fake:SetNetworkOwner() end
function Fake:MoveTo(point)
	self.MovingTo = point
end
function Fake:ScaleTo() end
local Instance = { new = make }

local workspace = make("Workspace")
workspace.GetServerTimeNow = function()
	return now
end
workspace.Raycast = function()
	return nil
end
local workspaceObject = workspace

-- The kaiju's body: a root, a head and a level of attributes (the real
-- models are KaijuModels' tests').
local KaijuModelsStub = {
	build = function(species, element)
		local model = make("Model", { Name = species })
		local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new() })
		root.Parent = model
		local head = make("Part", { Name = "Head", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 2, -1) })
		head.Parent = model
		model.PrimaryPart = root
		model:SetAttribute("KaijuHipHeight", 1)
		model:SetAttribute("KaijuSpecies", species)
		model:SetAttribute("KaijuElement", element)
		return model
	end,
	scale = function() end,
}

-- Players -----------------------------------------------------------------------------------------------

local playerList = {}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return playerList
	end,
}
local function makePlayer(id: number, at: Vector3)
	local player = make("Player", { UserId = id, Name = "P" .. id, DisplayName = "P" .. id, Parent = true })
	local character = make("Model", { Name = "P" .. id })
	local root = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(at) })
	root.Parent = character
	local humanoid = make("Humanoid", { Health = 100, MaxHealth = 100 })
	humanoid.Parent = character
	player.Character = character
	player:SetAttribute("Outpost", true)
	table.insert(playerList, player)
	return player, root
end

-- Services and stand-in server modules ---------------------------------------------------------------------

local notes, fxs = {}, {}
local function noted(player, text)
	for _, note in notes do
		if note[1] == player and string.find(note[2], text, 1, true) then
			return true
		end
	end
	return false
end
local Remotes = {
	Notify = {
		FireClient = function(_, player, text)
			table.insert(notes, { player, text })
		end,
	},
	CombatFx = {
		FireAllClients = function(_, kind, ...)
			table.insert(fxs, { kind, ... })
		end,
	},
}
local registered = {}
local Shop = {
	register = function(name, fn)
		registered[name] = fn
	end,
	reply = function(ok, message, extra)
		local result = extra or {}
		result.Ok, result.Message = ok, message
		return result
	end,
}
local profiles = {}
local synced = 0
local nextGem = 0
local PlayerData = {
	get = function(player)
		return profiles[player]
	end,
	sync = function()
		synced += 1
	end,
	newGemId = function()
		nextGem += 1
		return "g" .. nextGem
	end,
	findGem = function(player, id)
		for _, gem in profiles[player].Gems do
			if gem.Id == id then
				return gem
			end
		end
		return nil
	end,
	removeGem = function(player, id)
		for i, gem in profiles[player].Gems do
			if gem.Id == id then
				return table.remove(profiles[player].Gems, i)
			end
		end
		return nil
	end,
	addGem = function(player, gem)
		if #profiles[player].Gems >= 3 then
			return false -- (a small pouch, to test a full one)
		end
		table.insert(profiles[player].Gems, gem)
		return true
	end,
	addCoins = function(player, coins)
		profiles[player].Coins += coins
	end,
	milestone = function() end,
}

-- Enemies: the parts the kaiju use, as the real module does them.
local enemies = {}
local playerHits = {}
local Enemies = {}
function Enemies.adopt(model, kind, opts)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth, humanoid.Health = kind.Health, kind.Health
	model.Parent = workspaceObject
	local enemy = {
		Model = model,
		Kind = kind,
		Humanoid = humanoid,
		Root = model.PrimaryPart,
		Home = opts.Home or model.PrimaryPart.Position,
		Element = opts.Element,
		Bar = make("Frame"),
		Alive = true,
		LastHit = 0,
		LastAttack = 0,
		Damage = {},
		StunUntil = 0,
		SlowUntil = 0,
		Slow = 0,
		LastSourceAt = 0,
	}
	model:SetAttribute("CombatTitle", opts.Title)
	enemies[model] = enemy
	return enemy
end
function Enemies.all()
	local list = {}
	for _, enemy in enemies do
		if enemy.Alive then
			table.insert(list, enemy)
		end
	end
	return list
end
function Enemies.get(model)
	return enemies[model]
end
function Enemies.remove(enemy)
	enemy.Alive = false
	enemies[enemy.Model] = nil
	enemy.Model:Destroy()
end
function Enemies.damage(enemy, amount, source, _crit, _color, heavy, element)
	if not enemy.Alive then
		return
	end
	if enemy.TakenScale then
		amount *= (enemy.TakenScale(element))
	end
	-- A hop dodges; a heavy breaks a guard and staggers; a guard takes off the rest.
	if enemy.DodgeUntil and now < enemy.DodgeUntil then
		return
	end
	if enemy.GuardUntil and now < enemy.GuardUntil then
		if heavy == true then
			enemy.GuardUntil = 0
			enemy.GuardBrokenUntil = now + 0.9
			enemy.StunUntil = math.max(enemy.StunUntil, now + 0.35)
		else
			amount *= enemy.GuardMult or 0.3
			if heavy ~= nil then
				enemy.BlockedAt = now
			end
		end
	end
	amount = math.floor(amount + 0.5)
	-- (Its own shell soaks what's left, as the real one: a wild kaiju's R.)
	if enemy.Soak then
		amount = math.floor(enemy.Soak(amount) + 0.5)
	end
	enemy.LastHit = now
	if source then
		enemy.Damage[source] = (enemy.Damage[source] or 0) + amount
		enemy.LastSource, enemy.LastSourceAt = source, now
	end
	enemy.Humanoid.Health = math.max(0, enemy.Humanoid.Health - amount)
	if enemy.Humanoid.Health <= 0 then
		enemy.Alive = false
		enemies[enemy.Model] = nil
		if enemy.OnDeath then
			enemy.OnDeath(enemy)
		end
	end
end
function Enemies.addStatus(enemy, status, amount, seconds)
	enemy.LastStatus = { status, amount, seconds }
	if status == "Stun" then
		enemy.StunUntil = math.max(enemy.StunUntil, now + seconds) -- (the modules' clock: `now`)
	end
end
function Enemies.addDot(enemy, total)
	enemy.LastDot = total
end
function Enemies.hitPlayer(player, amount, element, enemy, heavy)
	table.insert(playerHits, { player, amount, element, enemy, heavy })
	return amount, false
end
function Enemies.weakness()
	return 0
end

-- A hunter's fight state, as CombatServer keeps it (what a wild kaiju reads).
local combatStates = {}
local CombatServerStub = {
	_state = function(player)
		combatStates[player] = combatStates[player] or { NextAttack = 0, StunUntil = 0 }
		return combatStates[player]
	end,
}

local GemsStub = {
	random = function()
		return Random.new(42)
	end,
}
-- A moon bug's body (the real brainrot bodies are the Duelist's).
local DuelistStub = {
	creatureBody = function(spec)
		local rig = make("Model", { Name = spec.Id })
		local body = make("Part", { Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new() })
		body.Parent = rig
		rig.PrimaryPart = body
		make("Humanoid", { Health = 100, MaxHealth = 100 }).Parent = rig
		return rig
	end,
}

-- Loading -------------------------------------------------------------------------------------------------

local RunService = { Heartbeat = signal() }
local services = { Players = Players, RunService = RunService }
local loaded = {}
local env
local server = {
	Enemies = Enemies,
	Gems = GemsStub,
	PlayerData = PlayerData,
	Remotes = Remotes,
	Shop = Shop,
	Duelist = DuelistStub,
	CombatServer = CombatServerStub,
}
local sharedEnv
local function load(path: string, name: string, environment)
	return luau.load(fs.readFile(ROOT .. path), { debugName = name, environment = environment or env })()
end
local function shared(name)
	if name == "KaijuModels" then
		return KaijuModelsStub
	end
	if loaded[name] == nil then
		loaded[name] = load("/src/shared/" .. name .. ".luau", name, sharedEnv)
	end
	return loaded[name]
end
local function serverModule(name)
	if server[name] == nil then
		server[name] = load("/src/server/Systems/" .. name .. ".luau", name)
	end
	return server[name]
end
local ReplicatedStorage = {
	Shared = setmetatable({}, {
		__index = function(_, key)
			return { Shared = key }
		end,
	}),
	FindFirstChild = function()
		return nil
	end,
}
services.ReplicatedStorage = ReplicatedStorage
local clock = table.clone(os)
clock.clock = function()
	return now
end
clock.time = function()
	return 1700000000
end
env = setmetatable({
	Color3 = Color3,
	Vector3 = Vector3,
	CFrame = CFrame,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Instance = Instance,
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	Random = Random,
	task = task,
	os = clock,
	workspace = workspace,
	typeof = function(value)
		if type(value) == "table" and getmetatable(value) == Fake then
			return "Instance"
		end
		return typeof(value)
	end,
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	script = {
		Parent = setmetatable({}, {
			__index = function(_, key)
				return { Server = key }
			end,
		}),
	},
	require = function(target)
		if type(target) == "string" then
			return shared(target)
		elseif target.Shared then
			return shared(target.Shared)
		end
		return serverModule(target.Server)
	end,
}, { __index = _G })
-- (Shared modules find each other as script.Parent.Name.)
-- (lune reads an environment's own fields: a copy, not an __index chain.)
sharedEnv = setmetatable(table.clone(env), getmetatable(env))
sharedEnv.script = {
	Parent = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
}

local Kaiju = shared("Kaiju")
local KaijuFight = shared("KaijuFight")
local KaijuAbilities = serverModule("KaijuAbilities")
local KaijuFighter = serverModule("KaijuFighter")
local KaijuServer = serverModule("KaijuServer")
local KaijuWilds = serverModule("KaijuWilds")
-- Its rolls from a seed (or one forced roll), its effects counted.
local fightRng = Random.new(11)
local fightRoll: number? = nil
KaijuFighter.random = function()
	return fightRoll or fightRng:NextNumber()
end
KaijuFighter.fx = function(kind, ...)
	table.insert(fxs, { kind, ... })
end
local function drew(kind)
	for _, entry in fxs do
		if entry[1] == kind then
			return entry
		end
	end
	return nil
end

-- Every E ability ------------------------------------------------------------------------------------------

local queued = {}
KaijuAbilities.after = function(seconds, fn)
	table.insert(queued, fn)
end
KaijuAbilities.fx = function(kind, ...)
	table.insert(fxs, { kind, ... })
end
local function flush()
	while #queued > 0 do
		local list = queued
		queued = {}
		for _, fn in list do
			fn()
		end
	end
end
local function root(at: Vector3)
	return { Position = at, CFrame = CFrame.new(at), Parent = true }
end
for id, plan in Kaiju.AbilityPlans do
	local body = { Dots = { {} }, SlowUntil = 99, BlindUntil = 99 }
	local humanoid = { Health = 50, MaxHealth = 200 }
	local caster = {
		Model = make("Model"),
		Root = root(Vector3.new(0, 0, 0)),
		Element = "Fire",
		Ability = id,
		Damage = 100,
		Body = body,
		Humanoid = humanoid,
	}
	-- Its foe 5 studs ahead (in reach), one more beside it, one far away.
	local foe = { Root = root(Vector3.new(0, 0, -5)), Name = "foe" }
	local beside = { Root = root(Vector3.new(2, 0, -6)), Name = "beside" }
	local far = { Root = root(Vector3.new(0, 0, -200)), Name = "far" }
	local all = { foe, beside, far }
	local dealt = {}
	local statuses = {}
	caster.Foes = function(center, radius)
		local list = {}
		for _, victim in all do
			if (victim.Root.Position - center).Magnitude <= radius then
				table.insert(list, victim)
			end
		end
		return list
	end
	caster.Hit = function(victim, amount, status)
		dealt[victim.Name] = (dealt[victim.Name] or 0) + amount
		if status then
			statuses[status] = true
		end
	end
	caster.Alive = function()
		return true
	end
	table.clear(fxs)
	check(KaijuAbilities.cast(caster, foe), id .. " didn't cast")
	flush()
	check(#fxs > 0, id .. " drew nothing")
	-- An R that guards it: a shell or a ward on it, or its health back.
	local guards = plan.Shape == "Shell" or plan.Shape == "Ward" or plan.Shape == "Mend"
	if plan.Shape == "Mend" then
		check(math.abs(humanoid.Health - (50 + 200 * plan.Heal)) < 1e-6, id .. " didn't heal its share")
	elseif guards then
		check(body.Defense == nil, id .. "'s shell outlasted it")
	end
	if plan.Cleanse then
		check(#body.Dots == 0 and body.SlowUntil == 0 and body.BlindUntil == 0, id .. " didn't cleanse")
	end
	if not guards or plan.Aura or plan.Burst then
		check((dealt.foe or 0) > 0, id .. " missed its foe")
		check(dealt.foe <= 100 + 1e-6 or plan.Aura ~= nil, id .. " dealt its foe more than the whole cast")
	end
	check(dealt.far == nil, id .. " hit a foe 200 studs away")
	if plan.Shape == "Bolt" then
		check(dealt.beside == nil, id .. " (a bolt) hit a second foe")
	end
	if plan.Shape == "Blast" or plan.Shape == "Nova" or plan.Shape == "Line" or plan.Shape == "Field" then
		check((dealt.beside or 0) > 0, id .. " (an area) missed the foe beside")
	end
	if plan.Status and plan.Shape ~= "Storm" then
		check(statuses[plan.Status], id .. " didn't leave " .. plan.Status)
	end
	local extra = plan.Aura or plan.Burst
	if extra and extra.Status then
		check(statuses[extra.Status], id .. " didn't leave " .. extra.Status)
	end
	if plan.Show then
		local shown = false
		for _, entry in fxs do
			shown = shown or (entry[1] == "TriadShow" and entry[3] == plan.Show)
		end
		check(shown, id .. " didn't draw its own look")
	end
	local at = ({ Q = "KaijuQAt", E = "KaijuAbilityAt", R = "KaijuRAt" })[string.sub(id, 1, 1)]
	check(caster.Model:GetAttribute(at) == now, id .. ": no cast time for the HUD")
end
check(
	not KaijuAbilities.cast({ Ability = "E_Nope", Root = root(Vector3.zero) }, { Root = root(Vector3.zero) }),
	"Cast an unknown E"
)
check(KaijuAbilities._onLine(Vector3.new(0, 0, -5), Vector3.zero, Vector3.new(0, 0, -10), 1), "On the line, missed")
check(not KaijuAbilities._onLine(Vector3.new(3, 0, -5), Vector3.zero, Vector3.new(0, 0, -10), 1), "Off the line, hit")
check(not KaijuAbilities._onLine(Vector3.new(0, 0, 5), Vector3.zero, Vector3.new(0, 0, -10), 1), "Behind it, hit")

-- Your kaiju ---------------------------------------------------------------------------------------------------

local outpost = Vector3.new(0, 5, 7000)
local a, rootA = makePlayer(1, outpost)
local b, rootB = makePlayer(2, outpost + Vector3.new(500, 0, 0))
profiles[a] = { Gems = {}, Coins = 0, Milestones = {} }
profiles[b] = { Gems = {}, Coins = 0, Milestones = {} }
KaijuServer.start()
local keepOut = { { outpost + Vector3.new(-260, 0, 0), 60 } } -- (a building out there)
KaijuWilds.start({
	Spawn = CFrame.new(outpost),
	Spots = { CFrame.new(outpost + Vector3.new(0, 0, -300)), CFrame.new(outpost + Vector3.new(300, 0, 0)) },
	KeepOut = keepOut,
})
local kaijuFolder = workspaceObject:FindFirstChild("Kaiju")
check(kaijuFolder ~= nil, "No Kaiju folder")
for _, name in { "KaijuRecall", "KaijuActive", "KaijuFeed", "KaijuTame" } do
	check(registered[name] ~= nil, name .. " isn't a request")
end

-- The starter: the first visit brings one, once.
KaijuServer._upkeep(a, now)
local roster = profiles[a].Kaiju
check(roster and Kaiju.count(roster) == 1 and profiles[a].KaijuStarter, "No starter kaiju")
local starter = Kaiju.active(roster)
check(starter.Level == 1 and Kaiju.isSoul(starter.Soul) and starter.Soul.Element == starter.Element, "A bad starter")
check(noted(a, "Meet your kaiju"), "Nobody told them about their kaiju")
KaijuServer._upkeep(a, now)
check(Kaiju.count(roster) == 1, "A second starter")
local pet = KaijuServer.pets()[a]
check(pet and pet.Model.Parent == kaijuFolder, "The kaiju isn't out")
check(pet.Model:GetAttribute("KaijuOwner") == 1 and pet.Model:GetAttribute("KaijuLevel") == 1, "Its attributes")
check(pet.Humanoid.MaxHealth == Kaiju.stats(starter.Species, 1, starter.Soul.Tier).Health, "Its health")
check((pet.Root.Position - rootA.Position).Magnitude < 10, "It came out far from its owner")
check(KaijuServer.petOf(pet.Model) == pet, "petOf doesn't find it")

-- Out of the Outpost: away; back: out again, as hurt as it was.
pet.Humanoid.Health = 50
a:SetAttribute("Outpost", nil)
KaijuServer._upkeep(a, now)
check(KaijuServer.pets()[a] == nil and pet.Model.Parent == nil, "Out with you outside the Outpost")
a:SetAttribute("Outpost", true)
KaijuServer._upkeep(a, now)
pet = KaijuServer.pets()[a]
check(pet and pet.Humanoid.Health == 50, "Healed by a trip away")
a:SetAttribute("CombatSession", "s1")
KaijuServer._upkeep(a, now)
check(KaijuServer.pets()[a] == nil, "Out with you in an Arena fight")
a:SetAttribute("CombatSession", nil)
KaijuServer._upkeep(a, now)
pet = KaijuServer.pets()[a]
check(pet ~= nil, "Not back after the fight")

-- Hurt by element: its own element 75%, its weakness 125%, less its Guard.
local function hurtBy(element)
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
	KaijuServer.hurt(pet, 40, element, nil)
	return pet.Humanoid.MaxHealth - pet.Humanoid.Health
end
local guard = 1 - Kaiju.Species[pet.Record.Species].Guard
local weak = shared("ElementMatchup").weakTo(pet.Element)
check(hurtBy(pet.Element) == math.floor(40 * 0.75 * guard + 0.5), "Its own element isn't 75%")
check(hurtBy(weak) == math.floor(40 * 1.25 * guard + 0.5), "Its weakness isn't 125%")
-- Knocked out at 0: back in its Gemsoul for a while, then out again.
table.clear(notes)
KaijuServer.hurt(pet, 1e6, nil, nil)
check(KaijuServer.pets()[a] == nil and pet.Model.Parent == nil, "Not knocked out at 0")
check(a:GetAttribute("KaijuDownUntil") == now + Kaiju.KnockoutSeconds, "No knockout time for the HUD")
check(noted(a, "knocked out"), "Not told it was knocked out")
KaijuServer._upkeep(a, now + 5)
check(KaijuServer.pets()[a] == nil, "Back before its time")
now += Kaiju.KnockoutSeconds + 1
KaijuServer._upkeep(a, now)
pet = KaijuServer.pets()[a]
check(
	pet and pet.Humanoid.Health == pet.Humanoid.MaxHealth and a:GetAttribute("KaijuDownUntil") == nil,
	"Not back, whole"
)

-- Recall.
check(registered.KaijuRecall(a).Ok and pet.RecallUntil == now + Kaiju.RecallSeconds, "Recall didn't take")
check(not registered.KaijuRecall(b).Ok, "Recalled a kaiju they don't have")
check(not KaijuServer.targetable(pet), "A recalled kaiju can be fought")
now += Kaiju.RecallSeconds + 0.1
check(KaijuServer.targetable(pet), "Still recalled")

-- Feeding.
local function stone(id, tier, element)
	local gem = { Id = id, Tier = tier, Element = element, Size = 5, Clarity = 5, Cut = 5 }
	table.insert(profiles[a].Gems, gem)
	return gem
end
stone("s1", "Common", "Shock")
stone("s2", "Rare", pet.Element)
local record = pet.Record
local expected = Kaiju.feedExp({ Tier = "Common", Element = "Shock" }, record)
	+ Kaiju.feedExp({ Tier = "Rare", Element = pet.Element }, record)
local result = registered.KaijuFeed(a, { "s1", "s2", "s1", "nope" })
check(result.Ok and result.Exp == expected, "Feeding gave the wrong EXP: " .. tostring(result.Exp))
check(#profiles[a].Gems == 0, "The stones weren't eaten")
check(record.Level > 1, "A rare of its own element didn't level a new kaiju")
check(pet.Model:GetAttribute("KaijuLevel") == record.Level, "The model didn't hear of the level")
check(not registered.KaijuFeed(a, { "nope" }).Ok, "Fed stones they don't have")
check(not registered.KaijuFeed(a, {}).Ok and not registered.KaijuFeed(a, "s1").Ok, "Fed nothing")
local many = {}
for i = 1, 26 do
	many[i] = "x" .. i
end
check(not registered.KaijuFeed(a, many).Ok, "Fed more than the limit at once")
check(not registered.KaijuFeed(b, { "s1" }).Ok, "Fed with no kaiju")

-- Switching: only your own, not mid-fight, and the new one comes out.
local soul = Kaiju.rollSoul(Random.new(3), "Frost", { Id = "soul2", Time = 1, Species = "Carapace" })
local second = KaijuServer.adopt(a, "Carapace", soul, 4)
check(second and roster.List[second.Id] == second and roster.Active ~= second.Id, "Adopting changed who's out")
check(not registered.KaijuActive(a, "nope").Ok, "Sent out a kaiju they don't own")
pet.LastFight = now
check(not registered.KaijuActive(a, second.Id).Ok, "Switched mid-fight")
pet.LastFight = now - 10
check(registered.KaijuActive(a, second.Id).Ok and roster.Active == second.Id, "Couldn't switch")
pet = KaijuServer.pets()[a]
check(pet and pet.Record == second, "The new one didn't come out")
check(not registered.KaijuActive(a, starter.Id).Ok, "Switched again at once")

-- Wild kaiju --------------------------------------------------------------------------------------------------

flush()
-- (Spawning waits a moment after start.)
for _, entry in delayed do
	if entry.At <= now + 10 then
		entry.Fn(table.unpack(entry.Args))
	end
end
table.clear(delayed)
local wilds = {}
for enemy, wild in KaijuWilds._wilds do
	if not wild.Bug then
		table.insert(wilds, enemy)
	end
end
check(#wilds == Kaiju.Wild.Max, "Not " .. Kaiju.Wild.Max .. " wild kaiju: " .. #wilds)
-- In packs of up to two of a kind, each round a den out in the frontier:
-- clear of the rocks, away from the landing pad and the other dens.
local packs = KaijuWilds._packs
check(#packs == math.ceil(Kaiju.Wild.Max / Kaiju.Wild.Pack), "Not packs of two: " .. #packs)
local FrontierRules = shared("Frontier")
for i, pack in packs do
	check(#pack.Members >= 1 and #pack.Members <= Kaiju.Wild.Pack, "A pack of " .. #pack.Members)
	local out = FrontierRules.distance(pack.Den, outpost)
	check(out >= FrontierRules.Core + 10 and out <= FrontierRules.Rim - 10, "A den out of the frontier: " .. out)
	for _, spotAt in { outpost + Vector3.new(0, 0, -300), outpost + Vector3.new(300, 0, 0) } do
		check((pack.Den - spotAt).Magnitude >= 7, "A den on a rock")
	end
	for j, other in packs do
		if j ~= i then
			check((other.Den - pack.Den).Magnitude >= 110, "Two dens side by side")
			check(other.Species ~= pack.Species, "Two packs of one kind")
		end
	end
	for _, member in pack.Members do
		check(member.Species == pack.Species and member.Pack == pack, "A pack of mixed kinds")
		check((member.Enemy.Root.Position - pack.Den).Magnitude < 12, "A packmate far from its den")
	end
end
local enemy = wilds[1]
local wild = KaijuWilds._wilds[enemy]
check(enemy.OutpostCreature and enemy.Model:GetAttribute("KaijuWild") == true, "A wild kaiju isn't marked")
check(math.abs(wild.Level - pet.Record.Level) <= Kaiju.Wild.LevelSpread, "A wild kaiju far from the kaiju out's level")
check(
	enemy.Humanoid.MaxHealth
		== math.floor(Kaiju.stats(wild.Species, wild.Level, wild.Soul.Tier).Health * Kaiju.Wild.Health + 0.5),
	"A wild kaiju's health"
)
-- Every blow on it lands 60%-140%, times its element and Guard.
local lo, hi = math.huge, -math.huge
for _ = 1, 400 do
	local scale = enemy.TakenScale(nil)
	lo, hi = math.min(lo, scale), math.max(hi, scale)
end
local wildGuard = 1 - Kaiju.Species[wild.Species].Guard
check(
	lo >= 0.6 * wildGuard - 1e-9 and hi <= 1.4 * wildGuard + 1e-9 and hi - lo > 0.5 * wildGuard,
	"No spread on a wild kaiju"
)
local own = enemy.TakenScale(wild.Element)
check(own <= 1.4 * 0.75 * wildGuard + 1e-9, "Its own element hits it full")

-- Its brain: it leaves a miner, a hunter and your kaiju alone until someone
-- starts on it (challenges it, or hits it).
enemy.Root.CFrame = CFrame.new(outpost + Vector3.new(30, 0, 0))
enemy.Home = enemy.Root.Position
pet.Root.CFrame = CFrame.new(outpost + Vector3.new(0, 0, 400)) -- (far off)
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(3, 0, 0))
enemy.LastAttack = 0
KaijuWilds._brain(enemy, now)
check(enemy.Foe == nil and #playerHits == 0, "A wild kaiju went after a miner")
a:SetAttribute("Hunt", true)
a:SetAttribute("Spar", true)
KaijuWilds._brain(enemy, now)
check(enemy.Foe == nil and #playerHits == 0, "A wild kaiju went after a hunter who left it alone")
-- Your kaiju beside it, its owner close by: neither picks a fight.
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
pet.RecallUntil = 0
KaijuServer._think(pet, now, 0.15)
check(pet.Target == nil, "Your kaiju picked a fight with a wild one nobody started")
KaijuWilds._brain(enemy, now)
check(enemy.Foe == nil, "A wild kaiju went after a kaiju that left it alone")
pet.Root.CFrame = CFrame.new(outpost + Vector3.new(0, 0, 400)) -- (far off again)
-- Challenged: not from afar, nor something that isn't a wild kaiju; then it's on.
local Challenge = registered.KaijuChallenge
check(Challenge ~= nil, "No way to challenge a wild kaiju")
check(enemy.Root:FindFirstChild("ChallengePrompt") ~= nil, "A wild kaiju has no Challenge prompt")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(40, 0, 0))
check(not Challenge(a, enemy.Model).Ok, "Challenged it from 40 studs")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(3, 0, 0))
check(not Challenge(a, make("Model")).Ok, "Challenged something that isn't a wild kaiju")
check(Challenge(a, enemy.Model).Ok and wild.Engaged[a] ~= nil, "A hunter couldn't challenge it")
KaijuWilds._brain(enemy, now)
check(enemy.Foe == a, "A challenged wild kaiju ignored its challenger")
now += 10
KaijuWilds._brain(enemy, now)
check(#playerHits > 0 and playerHits[#playerHits][1] == a, "It never struck the hunter")
a:SetAttribute("SparDown", now + 3)
enemy.FoeVictim = nil
KaijuWilds._brain(enemy, now)
check(enemy.Foe == nil, "It went after a knocked-down hunter")
a:SetAttribute("SparDown", nil)
a:SetAttribute("Hunt", nil)
a:SetAttribute("Spar", nil)
-- Your kaiju near it: it squares up and fights it as a duellist (wind-ups
-- before its blows), and the blows are yours.
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(6, 0, 0))
pet.RecallUntil = 0
local before = enemy.Humanoid.Health
KaijuServer._think(pet, now, 0.15)
check(pet.Target == enemy, "Your kaiju ignored the wild one beside you")
check(pet.Fighter.Engaged and pet.Humanoid.AutoRotate == false, "It didn't square up to it")
check(pet.Root:FindFirstChild("FaceAlign").Enabled, "It doesn't face its foe as it circles")
local blows, windups = 0, 0
for _ = 1, 40 do
	now += 0.15
	KaijuServer._think(pet, now, 0.15)
	local start, at = pet.Model:GetAttribute("ActionStart"), pet.Model:GetAttribute("ActionAt")
	local kind = pet.Model:GetAttribute("ActionKind")
	if start == now and (kind == "Light" or kind == "Heavy" or kind == "Punish" or kind == "Lunge") then
		blows += 1
		windups += if at > start then 1 else 0
	end
end
check(blows > 0 and windups == blows, "Its blows have no wind-up for the animation")
check(enemy.Humanoid.Health < before and (enemy.KaijuCredit[a] or 0) > 0, "Its blows didn't land, or weren't yours")
enemy.FoeVictim = nil
KaijuWilds._brain(enemy, now)
check(enemy.Foe == pet, "The wild one didn't fight back")
-- Recalled: it stops, and the wild one lets it be.
registered.KaijuRecall(a)
KaijuServer._think(pet, now, 0.15)
check(pet.Target == nil, "A recalled kaiju kept fighting")
enemy.FoeVictim = nil
enemy.LastPet = nil
KaijuWilds._brain(enemy, now)
check(enemy.Foe ~= pet, "A wild kaiju fought a recalled one")
check(not pet.Fighter.Engaged and pet.Humanoid.AutoRotate, "A recalled kaiju stays squared up")
-- With your kaiju recalled and no hunt, there's nothing to challenge it with.
check(not Challenge(a, enemy.Model).Ok, "Challenged with no kaiju out and no hunt")
-- Left alone at home a while, it forgets who started on it, and your kaiju
-- leaves it be again.
pet.Root.CFrame = CFrame.new(outpost + Vector3.new(0, 0, 400)) -- (far off)
now += 9
KaijuWilds._brain(enemy, now)
check(next(wild.Engaged) == nil, "It never forgot who started on it")
now += Kaiju.RecallSeconds + 1
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
KaijuServer._think(pet, now, 0.15)
check(pet.Target == nil, "Your kaiju went back for a wild one that had calmed down")
-- Hitting it starts the fight too: your kaiju's blow (as below) or yours.
local caster = KaijuServer.caster(pet)
check(#caster.Foes(enemy.Root.Position, 10) == 0, "Your kaiju's E would hit a calm wild kaiju")
enemy.LastSource, enemy.LastSourceAt = a, now
a:SetAttribute("Hunt", true)
a:SetAttribute("Spar", true)
KaijuWilds._brain(enemy, now)
check(enemy.Foe == a and wild.Engaged[a] ~= nil, "Hitting it didn't start the fight")
check(#caster.Foes(enemy.Root.Position, 10) == 1, "Your kaiju's E misses the wild one you're fighting")
a:SetAttribute("Hunt", nil)
a:SetAttribute("Spar", nil)
enemy.LastSource, enemy.FoeVictim = nil, nil

-- Fighting as a duellist ------------------------------------------------------------------------------------------

local fighter, wf = pet.Fighter, wild.Fighter
check(KaijuFighter.of(pet.Model) == fighter and KaijuFighter.of(enemy.Model) == wf, "No fighters")
check(fighter.Body == pet and wf.Body == enemy, "A fighter's guard lives somewhere else")
check(math.abs(fighter.Reach - pet.Stats.Reach * Kaiju.Scale.Pet) < 1e-9, "A pet's reach isn't its size")
check(math.abs(wf.Reach - Kaiju.stats(wild.Species, wild.Level).Reach * Kaiju.Scale.Wild) < 1e-9, "A wild one's reach")
local petFoe = { Root = pet.Root, Pet = pet }
local wildFoe = { Root = enemy.Root, Enemy = enemy }
local function settle(f)
	f.Action, f.SwingTimes, f.RecoverUntil, f.LastOffense = nil, {}, 0, now
	f.NextAttack, f.NextDefense, f.NextSurge, f.NextHighBlock = 0, 0, math.huge, 0
	f.Body.StunUntil, f.Body.GuardUntil, f.Body.GuardBrokenUntil, f.Body.DodgeUntil = 0, 0, 0, 0
	f.Body.BlockedAt, f.Body.GuardRaisedAt, f.FoeIdleSince = nil, nil, nil
end
pet.Humanoid.MaxHealth, pet.Humanoid.Health = 1e6, 1e6
enemy.Humanoid.MaxHealth, enemy.Humanoid.Health = 1e6, 1e6
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))

-- A foe behind its guard: a heavy, named on the cast bar, a warning ring at
-- its feet; landing, it breaks the guard and staggers it.
now += 5
settle(fighter)
settle(wf)
KaijuFight.raiseGuard(wf, now - 1, 5)
table.clear(fxs)
fightRoll = 0.1
KaijuFighter.step(fighter, wildFoe, now)
check(
	fighter.Action and fighter.Action.Kind == "Heavy",
	"No heavy against a raised guard: " .. tostring(fighter.Choice)
)
check(pet.Model:GetAttribute("ActionName") == KaijuFight.style(pet.Record.Species).Names.Heavy, "A heavy isn't named")
check(pet.Model:GetAttribute("ActionAt") - now == KaijuFight.windup(fighter.Style, "Heavy"), "A heavy's wind-up")
check(drew("Nova"), "No warning ring for a heavy")
before = enemy.Humanoid.Health
now += KaijuFight.windup(fighter.Style, "Heavy") + 0.01
KaijuFighter.step(fighter, wildFoe, now)
check(enemy.Humanoid.Health < before and not KaijuFight.guarding(enemy, now), "A heavy didn't break the guard")
check(enemy.StunUntil > now and enemy.GuardBrokenUntil > now, "A broken guard didn't stagger it")

-- A light blow just as the wild one braces: parried, and your kaiju reels.
now += 5
settle(fighter)
settle(wf)
KaijuFight.raiseGuard(wf, now, 1.6)
fighter.Action = { Kind = "Light", At = now + 0.1, Hits = 1 }
before = enemy.Humanoid.Health
KaijuFighter.step(fighter, wildFoe, now + 0.1)
check(enemy.Humanoid.Health == before and pet.StunUntil >= now + 0.1 + KaijuFight.ParryStagger, "Not parried")
check(pet.Model:GetAttribute("ActionKind") == "Stagger" and fighter.Action == nil, "It didn't reel")
-- Reeling, it can't act.
KaijuFighter.step(fighter, wildFoe, now + 0.2)
check(fighter.Choice == "Stagger" and fighter.Action == nil, "It acted while reeling")

-- The same the other way: the wild one's light blow on your kaiju's fresh guard.
now += 5
settle(fighter)
settle(wf)
KaijuFight.raiseGuard(fighter, now, 1.6)
wf.Action = { Kind = "Light", At = now + 0.05, Hits = 1 }
before = pet.Humanoid.Health
KaijuFighter.step(wf, petFoe, now + 0.05)
check(
	pet.Humanoid.Health == before and enemy.StunUntil >= now + 0.05 + KaijuFight.ParryStagger,
	"Your kaiju didn't parry"
)
-- Later in its guard: blocked (GuardMult of it), and it can answer.
now += 1
wf.Action = { Kind = "Light", At = now, Hits = 1 }
enemy.StunUntil = 0
local taken = 1 - Kaiju.Species[pet.Record.Species].Guard
KaijuServer.hurt(pet, 100, nil, nil, false)
local dealt = before - pet.Humanoid.Health
check(dealt == math.floor(100 * fighter.Style.GuardMult * taken + 0.5), "A blocked blow: " .. dealt)
check(pet.BlockedAt == now, "A blocked blow it can't answer")
fightRoll = 0.2
KaijuFighter.step(fighter, wildFoe, now + 0.1)
check(fighter.Action and fighter.Action.Kind == "Punish", "No riposte after a block: " .. tostring(fighter.Choice))
-- A heavy breaks your kaiju's guard; a hop dodges everything.
settle(fighter)
KaijuFight.raiseGuard(fighter, now - 1, 5)
before = pet.Humanoid.Health
check(KaijuServer.hurt(pet, 100, nil, nil, true) == "Broken", "A heavy didn't break your kaiju's guard")
check(before - pet.Humanoid.Health == math.floor(100 * taken + 0.5) and pet.StunUntil > now, "A broken guard")
pet.DodgeUntil = now + 0.3
before = pet.Humanoid.Health
check(KaijuServer.hurt(pet, 100, nil, nil, true) == "Dodged" and pet.Humanoid.Health == before, "A hop didn't dodge")

-- A hunter charging a heavy beside a wild kaiju: it hops aside (a swing
-- mid-hop misses), and it waits a beat before it reacts again.
now += 5
settle(wf)
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(3, 0, 0))
CombatServerStub._state(a).ChargeStarted = now - 0.5
table.clear(fxs)
fightRoll = 0.1
KaijuFighter.step(wf, { Root = rootA, Player = a }, now)
check(wf.Choice == "Dodge" and enemy.DodgeUntil > now, "It stood in the way of a hunter's heavy")
check(drew("DodgeRoll") and enemy.Root.AssemblyLinearVelocity.Magnitude > 0, "No hop")
check(wf.NextDefense > now, "No beat before it reacts again")
before = enemy.Humanoid.Health
Enemies.damage(enemy, 50, a, false, nil, true, nil)
check(enemy.Humanoid.Health == before, "A swing mid-hop landed")
CombatServerStub._state(a).ChargeStarted = nil

-- Its E: after a wind-up on the cast bar, then cast (and not again for a while).
now += 5
settle(fighter)
settle(wf)
fighter.NextSurge = now - 1
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(7, 0, 0))
fightRoll = 0.5
KaijuFighter.step(fighter, wildFoe, now)
local plan = Kaiju.AbilityPlans[pet.Ability]
check(fighter.Action and fighter.Action.Kind == "Surge", "No E from range: " .. tostring(fighter.Choice))
check(pet.Model:GetAttribute("ActionKind") == KaijuFight.surgeKind(plan), "Its E's wind-up")
check(pet.Model:GetAttribute("ActionName") == shared("GemTraits").Moves[pet.Ability].Name, "Its E isn't named")
check(pet.Model:GetAttribute("ActionElement") == pet.Element, "Its E's cast bar isn't its element")
now += 1.2
KaijuFighter.step(fighter, wildFoe, now)
flush()
check(pet.Model:GetAttribute("KaijuAbilityAt") == now and fighter.NextSurge == now + Kaiju.AbilityEvery, "No E")
fightRoll = nil

-- Its Q and R, from the same Gemsoul: asleep while it's young (Q wakes at
-- level 5, R at 10), on the model for every client when awake.
local Traits = shared("GemTraits")
local soulQ, soulR = Kaiju.move(pet.Record.Soul, "Q"), Kaiju.move(pet.Record.Soul, "R")
local young = Kaiju.moves(pet.Record.Soul, pet.Record.Level)
check(fighter.Moves.Q == young.Q and fighter.Moves.R == young.R, "Its moves don't follow its level")
check(pet.Model:GetAttribute("KaijuQ") == young.Q and pet.Model:GetAttribute("KaijuR") == young.R, "Its moves aren't on the model")
check(wf.Moves.Q == Kaiju.moves(wild.Soul, wild.Level).Q, "A wild one's moves don't follow its level")
KaijuFighter.setMoves(fighter, Kaiju.moves(pet.Record.Soul, 10))
check(fighter.Moves.Q == soulQ and fighter.Moves.R == soulR, "Level 10 didn't wake Q and R")
-- Q: in place of a blow when it's ready, named on its cast bar.
now += 5
settle(fighter)
settle(wf)
fighter.NextQ, fighter.NextR = now - 1, math.huge
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
KaijuFight.raiseGuard(wf, now - 1, 5) -- (it would swing a heavy)
fightRoll = 0.1
KaijuFighter.step(fighter, wildFoe, now)
check(
	fighter.Choice == "Q" and fighter.Action and fighter.Action.Kind == "Move" and fighter.Action.Id == soulQ,
	"No Q in place of a blow: " .. tostring(fighter.Choice)
)
check(pet.Model:GetAttribute("ActionName") == Traits.Moves[soulQ].Name, "Its Q isn't named on the cast bar")
check(fighter.NextQ == now + Kaiju.QEvery, "Its Q's wait didn't start")
now += 1
KaijuFighter.step(fighter, wildFoe, now)
flush()
check(pet.Model:GetAttribute("KaijuQAt") == now, "Its Q didn't go off")
-- Not again until its wait is over: a blow instead.
settle(fighter)
KaijuFight.raiseGuard(wf, now - 1, 5)
KaijuFighter.step(fighter, wildFoe, now + 0.1)
check(fighter.Choice == "Heavy", "Its Q went off again straight away: " .. tostring(fighter.Choice))
-- R: hard pressed (down to RWhen of its health), it raises it at once.
now += 5
settle(fighter)
settle(wf)
fighter.NextQ, fighter.NextR = math.huge, now - 1
pet.Humanoid.Health = pet.Humanoid.MaxHealth * 0.9
KaijuFighter.step(fighter, wildFoe, now)
check(fighter.Choice ~= "R", "It raised its R untroubled")
settle(fighter)
pet.Humanoid.Health = pet.Humanoid.MaxHealth * (Kaiju.RWhen - 0.05)
KaijuFighter.step(fighter, wildFoe, now)
check(fighter.Choice == "R" and fighter.Action and fighter.Action.Id == soulR, "No R when hard pressed: " .. tostring(fighter.Choice))
check(fighter.NextR == now + Kaiju.REvery and fighter.Action.At - now < 0.5, "Its R is slow, or its wait didn't start")
now += 0.3
KaijuFighter.step(fighter, wildFoe, now)
check(pet.Model:GetAttribute("KaijuRAt") == now, "Its R didn't go up")
flush()
pet.Defense = nil
pet.Humanoid.Health = pet.Humanoid.MaxHealth
-- A shell soaks blows on your kaiju until it breaks; a ward takes its share.
local petCaster = KaijuServer.caster(pet)
pet.Humanoid.MaxHealth, pet.Humanoid.Health = 1000, 1000
settle(fighter)
check(KaijuAbilities.cast(petCaster, wildFoe, "R_IonShield"), "No Ion Shield")
before = pet.Humanoid.Health
KaijuServer.hurt(pet, 100, nil, nil, nil)
check(pet.Humanoid.Health == before and pet.Defense and pet.Defense.Left < 150, "The shell didn't soak a blow")
KaijuServer.hurt(pet, 300, nil, nil, nil)
check(pet.Defense == nil and pet.Humanoid.Health < before, "The shell held past what it soaks")
flush()
check(KaijuAbilities.cast(petCaster, wildFoe, "R_IceArmor"), "No Ice Armor")
before = pet.Humanoid.Health
KaijuServer.hurt(pet, 100, nil, nil, nil)
check(before - pet.Humanoid.Health == math.floor(100 * 0.75 * taken + 0.5), "The ward didn't take its share")
now += 6
KaijuServer.hurt(pet, 100, nil, nil, nil)
check(pet.Defense == nil, "The ward outlasted its time")
flush()
-- A burst when a shell breaks: Glacial Bulwark slows those near.
check(KaijuAbilities.cast(petCaster, wildFoe, "R_GlacialBulwark"), "No Glacial Bulwark")
pet.Defense.Left = 1
KaijuServer.hurt(pet, 100, nil, nil, nil)
check(pet.Defense == nil, "A broken shell stayed up")
flush()
pet.Defense = nil
-- And on a wild kaiju, through Enemies.damage.
check(KaijuAbilities.cast(wf.Caster(), petFoe, "R_IonShield"), "A wild one has no Ion Shield")
before = enemy.Humanoid.Health
Enemies.damage(enemy, 50, a, false, nil, nil, nil)
check(enemy.Humanoid.Health == before and enemy.Defense ~= nil, "A wild one's shell didn't soak a blow")
flush()
enemy.Defense = nil
pet.Humanoid.MaxHealth, pet.Humanoid.Health = 1e6, 1e6
fightRoll = nil

-- A whole duel: your kaiju and the wild one, twenty seconds of it.
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(6, 0, 0))
settle(fighter)
settle(wf)
enemy.LastPet, enemy.LastPetAt, enemy.FoeVictim = pet, now, nil
fighter.NextQ, fighter.NextR = now + 1, now -- (its Q and R awake, as at level 10)
local petBefore, wildBefore = pet.Humanoid.Health, enemy.Humanoid.Health
local choices = {}
local combo = false
for _ = 1, 133 do
	now += 0.15
	KaijuServer._think(pet, now, 0.15)
	KaijuWilds._brain(enemy, now)
	flush()
	choices[fighter.Choice or ""] = true
	choices[wf.Choice or ""] = true
	combo = combo
		or (fighter.Action ~= nil and (fighter.Action.Hits or 1) >= 2)
		or (wf.Action ~= nil and (wf.Action.Hits or 1) >= 2)
end
check(pet.Humanoid.Health < petBefore and enemy.Humanoid.Health < wildBefore, "A duel where nobody was hurt")
check(enemy.Foe == pet, "The wild one fought someone else")
for _, move in { "Light", "Guard" } do
	check(choices[move], "Nobody chose " .. move .. " in a whole duel")
end
check(choices.Heavy or choices.Dodge or choices.Punish or choices.Riposte, "A duel of nothing but swings and guards")
check(choices.Q, "Its Q never went off in a whole duel")
check(combo, "No combos in a whole duel")
-- Out of the fight: it calms (its guard down, its pose cleared).
registered.KaijuRecall(a)
KaijuServer._think(pet, now, 0.15)
check(not fighter.Engaged and not KaijuFight.guarding(pet, now), "Still braced out of the fight")
check(pet.Model:GetAttribute("ActionKind") == nil and pet.Model:GetAttribute("GuardUntil") == 0, "Its pose stuck")
now += Kaiju.RecallSeconds + 1
pet.Humanoid.MaxHealth = Kaiju.stats(pet.Record.Species, pet.Record.Level, pet.Record.Soul.Tier).Health
pet.Humanoid.Health = pet.Humanoid.MaxHealth
enemy.Humanoid.MaxHealth =
	math.floor(Kaiju.stats(wild.Species, wild.Level, wild.Soul.Tier).Health * Kaiju.Wild.Health + 0.5)
enemy.Humanoid.Health = enemy.Humanoid.MaxHealth

-- Taming ------------------------------------------------------------------------------------------------------------

local Tame = registered.KaijuTame
check(not Tame(a, make("Model")).Ok, "Tamed a model that isn't a wild kaiju")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(60, 0, 0))
check(Tame(a, enemy.Model).Message:find("closer") ~= nil, "Tamed from across the quarry")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(5, 0, 0))
enemy.Humanoid.Health = enemy.Humanoid.MaxHealth * 0.8
check(Tame(a, enemy.Model).Message:find("half") ~= nil, "Tamed one at 80%")
enemy.Humanoid.Health = enemy.Humanoid.MaxHealth * 0.2
-- The tame is a cast (Kaiju.Tame): it's held, struggling, untouchable; the
-- roll comes at its end.
local function finishCast(target)
	now += Kaiju.Tame.Cast + 0.01
	KaijuWilds._brain(target, now)
end
forcedRoll = 0.99 -- (every try fails)
local first = Tame(a, enemy.Model)
check(
	first.Ok and first.Casting and first.Chance > 0 and first.Seconds == Kaiju.Tame.Cast,
	"The tame didn't start a cast"
)
check(
	enemy.Model:GetAttribute("KaijuTameBy") == a.UserId and enemy.Model:GetAttribute("KaijuMood") == "Bound",
	"It isn't held by the tame"
)
check(enemy.Model:GetAttribute("KaijuTameEnds") ~= nil, "No end time for the cast bar")
local heldHealth = enemy.Humanoid.Health
Enemies.damage(enemy, 500, b, false, nil, nil, nil)
check(enemy.Alive and enemy.Humanoid.Health == heldHealth, "A held kaiju was hurt")
check(Tame(a, enemy.Model).Message:find("taming") ~= nil, "Cast twice on one")
now += Kaiju.Tame.Cast / 2
KaijuWilds._brain(enemy, now)
check(enemy.Model:GetAttribute("KaijuTameBy") == a.UserId and wild.Tries == 0, "The cast ended early")
check(enemy.FoeVictim == nil, "A held kaiju went for someone")
finishCast(enemy)
check(
	enemy.Model:GetAttribute("KaijuTameBy") == nil and enemy.Model:GetAttribute("KaijuMood") == nil,
	"Still held after the cast"
)
check(
	enemy.Model:GetAttribute("KaijuTries") == 1 and a:GetAttribute("TameResult") == "Broke",
	"A failed try didn't count"
)
check(noted(a, "broke free"), "The tamer didn't hear it broke free")
check(Tame(a, enemy.Model).Message:find("moment") ~= nil, "Tried again at once")
-- Stray too far, or get hit, and the cast breaks (no try spent).
now += Kaiju.TameCooldown
check(Tame(a, enemy.Model).Casting, "Couldn't cast again")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(Kaiju.Tame.Break + 4, 0, 0))
KaijuWilds._brain(enemy, now)
check(
	enemy.Model:GetAttribute("KaijuTameBy") == nil and a:GetAttribute("TameResult") == "Interrupted" and wild.Tries == 1,
	"Walking off didn't break the tame (or spent a try)"
)
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(5, 0, 0))
now += Kaiju.TameCooldown
check(Tame(a, enemy.Model).Casting, "Couldn't cast after a break")
local aHumanoid = a.Character:FindFirstChildOfClass("Humanoid")
aHumanoid.Health -= 10
KaijuWilds._brain(enemy, now)
check(a:GetAttribute("TameResult") == "Interrupted" and noted(a, "hit"), "A hit didn't break the tame")
aHumanoid.Health = aHumanoid.MaxHealth
now += Kaiju.TameCooldown
Tame(a, enemy.Model)
finishCast(enemy)
now += Kaiju.TameCooldown
Tame(a, enemy.Model)
finishCast(enemy)
check(
	a:GetAttribute("TameResult") == "Fled" and not enemy.Alive and KaijuWilds._wilds[enemy] == nil,
	"Three failed tries and it stayed"
)
-- The next one: a lucky try.
local target = wilds[2]
local wild2 = KaijuWilds._wilds[target]
target.Root.CFrame = CFrame.new(rootA.Position + Vector3.new(4, 0, 0))
target.Humanoid.Health = target.Humanoid.MaxHealth * 0.1
forcedRoll = 0.01
local owned = Kaiju.count(roster)
check(Tame(a, target.Model).Casting, "No cast on a weak one")
-- (Your kaiju leaves one being caught alone.)
check(not KaijuServer._fair(a, target), "Your kaiju still fights one being tamed")
finishCast(target)
check(a:GetAttribute("TameResult") == "Tamed", "A lucky try at 10% health failed")
local tamedId
for id, entry in roster.List do
	if entry.Species == wild2.Species and entry.Level == wild2.Level and entry.Soul.Element == wild2.Element then
		tamedId = id
	end
end
check(Kaiju.count(roster) == owned + 1 and tamedId ~= nil, "The tamed kaiju isn't yours (or it changed taming)")
check(not target.Alive, "The tamed one still roams")
-- A full roster: no taming. (Another roams out once they've gone.)
KaijuWilds._spawnWild()
local third
for other, entry in KaijuWilds._wilds do
	if not entry.Bug and other.Alive then
		third = other
	end
end
check(third ~= nil, "No wild kaiju roamed out again")
third.Root.CFrame = CFrame.new(rootA.Position + Vector3.new(4, 0, 0))
third.Humanoid.Health = third.Humanoid.MaxHealth * 0.1
for i = 1, Kaiju.MaxOwned do
	KaijuServer.adopt(a, "Razorback", Kaiju.rollSoul(Random.new(i), "Fire", { Id = "f" .. i, Time = 1 }), 1)
end
check(Kaiju.count(roster) == Kaiju.MaxOwned, "Kept more than the limit")
check(Tame(a, third.Model).Message:find("let one go") ~= nil, "Tamed past the limit")
forcedRoll = nil

-- Killing one: its Gemsoul to whoever did the most, EXP to the kaiju that fought.
local expBefore = Kaiju.active(roster).Exp + 0
local levelBefore = Kaiju.active(roster).Level
third.Damage[b] = 5
third.KaijuCredit = { [a] = 50 }
table.clear(notes)
Enemies.damage(third, 1e6, nil, false, nil, nil, nil)
check(not third.Alive, "Didn't die")
local soulGem = profiles[a].Gems[#profiles[a].Gems]
check(soulGem and Kaiju.isSoul(soulGem) and soulGem.Id ~= "wild", "The top damager didn't get its Gemsoul")
check(noted(a, "Gemsoul is yours"), "Not told about the Gemsoul")
local active = Kaiju.active(roster)
check(active.Level > levelBefore or active.Exp > expBefore, "No EXP for the kill")
check(#profiles[b].Gems == 0, "The one who did less got the Gemsoul too")

-- The frontier: critters come through rifts ------------------------------------------------------------------

-- (Delayed work, in the order it falls due, until nothing more is.)
local function runDelayed()
	while true do
		local due, at = nil, nil
		for i, entry in delayed do
			if entry.At <= now and (not due or entry.At < delayed[due].At) then
				due, at = i, entry
			end
		end
		if not due then
			return
		end
		table.remove(delayed, due)
		at.Fn(table.unpack(at.Args))
	end
end
local Frontier = shared("Frontier")
local FrontierServer = serverModule("FrontierServer")
local riftsFolder
local center = outpost * Vector3.new(1, 0, 1)
FrontierServer.start({ Scars = { CFrame.new(center + Vector3.new(Frontier.Rim + 2, 0, 0)) } })
FrontierServer._setWanderAt(math.huge) -- (wandering rifts have their own checks, below)
riftsFolder = workspaceObject:FindFirstChild("Rifts")
check(riftsFolder ~= nil, "No Rifts folder")
local scar = riftsFolder:FindFirstChild("RiftScar")
check(scar and scar:GetAttribute("Dormant") == true and scar:GetAttribute("Seed"), "No dormant rift at a vein")
local function rifts()
	local list = {}
	for _, child in riftsFolder:GetChildren() do
		if child.Name == "Rift" and not child.Destroyed then
			table.insert(list, child)
		end
	end
	return list
end
local function critterFor(player)
	local list = {}
	for enemy, entry in KaijuWilds._wilds do
		if entry.Bug and entry.Prey == player and enemy.Alive then
			table.insert(list, enemy)
		end
	end
	return list
end
local function clearCritters()
	for enemy, entry in pairs(KaijuWilds._wilds) do
		if entry.Bug then
			enemy.Alive = false
			KaijuWilds._wilds[enemy] = nil
		end
	end
	table.clear(FrontierServer._pending)
end
local east = Vector3.new(1, 0, 0)
local function stand(at: Vector3)
	rootB.CFrame = CFrame.lookAt(at, at + east)
end
-- `count` swings by b, `gap` seconds apart (the rifts' delays run as they fall due).
local function swingFor(count: number, gap: number, until_: (() -> boolean)?)
	for i = 1, count do
		now += gap
		FrontierServer.swing(b)
		FrontierServer._step(gap)
		runDelayed()
		if until_ and until_() then
			return i
		end
	end
	return count
end

-- A miner swinging in the core: no rifts, however long, and no noise.
clearCritters()
table.clear(playerHits)
stand(center + Vector3.new(60, 5, 0))
swingFor(60, 0.5)
check(#rifts() == 0 and #critterFor(b) == 0, "A rift opened in the core")
check(b:GetAttribute("FrontierBand") == "Core", "No band for the HUD")
check((b:GetAttribute("FrontierNoise") or 0) <= Frontier.Noise.Restart + 0.05, "Swinging in the core made noise")

-- Out in the fringe: each swing makes noise (the HUD's ring fills), and
-- about one in 35 brings a rift, near where they face.
stand(center + Vector3.new(200, 5, 0))
local loudest = 0
local swings = swingFor(140, 0.4, function()
	loudest = math.max(loudest, b:GetAttribute("FrontierNoise") or 0)
	return #rifts() > 0
end)
check(b:GetAttribute("FrontierBand") == "Fringe", "Not in the fringe")
check(#rifts() > 0, "No rift tore open round a miner swinging in the fringe")
check(swings >= 15 and swings <= 90, "Not about 1 in 35 swings: " .. swings)
check(loudest >= 0.5, "The noise ring never filled")
local firstRift = rifts()[1]
local open, hop = firstRift:GetAttribute("OpenAt"), firstRift:GetAttribute("HopAt")
local close, finish = firstRift:GetAttribute("CloseAt"), firstRift:GetAttribute("EndAt")
check(open < hop and hop < close and close < finish, "A rift's timeline")
check(hop - open >= 1.5, "Under a second and a half's warning")
check(firstRift:GetAttribute("Prey") == b.UserId, "A rift says nothing of who it's for")
check(firstRift:GetAttribute("Critter") ~= nil, "A rift says nothing of what's coming")
local height = firstRift:GetAttribute("Height")
check(height >= Frontier.Rift.Height[1] and height <= Frontier.Rift.Height[2], "A rift's height")
local away = firstRift.Position - rootB.Position
check(Vector3.new(away.X, 0, away.Z).Magnitude <= Frontier.Rift.Far + 12, "A rift far from whoever drew it")
check(Vector3.new(away.X, 0, away.Z).Unit:Dot(east) >= math.cos(Frontier.Rift.Spread) - 0.05, "A rift behind the miner")
check(#critterFor(b) == 0, "A critter hopped out before the warning was over")
now = hop + 0.05
runDelayed()
local bug = critterFor(b)[1]
check(bug ~= nil, "Nothing hopped out of the rift")
local entry = KaijuWilds._wilds[bug]
check(
	entry.Prey == b and entry.Band == "Fringe" and bug.Model:GetAttribute("RiftBorn"),
	"A critter not drawn by its miner"
)
check(
	entry.Species == firstRift:GetAttribute("Critter") or #critterFor(b) > 1,
	"Not the critter its rift crackled with"
)
check(entry.Level >= 1 and entry.Level <= 4, "A fringe critter's level")
check(bug.Model:GetAttribute("CritterLevel") == entry.Level, "A critter's level isn't on it")
check(string.find(bug.Model:GetAttribute("CombatTitle"), "Lv " .. entry.Level, 1, true), "Its nameplate has no level")
check(bug.Root.AssemblyLinearVelocity.Y > 0, "It didn't hop out")
-- It goes straight for them, kit or no kit (they kite it, or their kaiju fights it).
bug.Root.CFrame = CFrame.new(rootB.Position + Vector3.new(2, 0, 0))
bug.LastAttack = 0
KaijuWilds._brain(bug, now)
check(bug.Foe == b, "A critter ignored the miner who drew it")
check(#playerHits > 0 and playerHits[#playerHits][1] == b and playerHits[#playerHits][5] == false, "It never bit them")
-- More come, but never more than the fringe's cap round one player,
-- counting those still on their way through.
for _ = 1, 160 do
	swingFor(1, 0.4)
	local coming = #critterFor(b) + (FrontierServer._pending[b] or 0)
	check(coming <= Frontier.Caps.Fringe, "More critters than the fringe allows")
end
check(#critterFor(b) >= 2, "Rifts stopped opening round a miner out in the fringe")
-- Standing about out there, not mining: hardly any (a trickle every few minutes).
clearCritters()
local before = #rifts()
for _ = 1, 40 do
	now += 0.5
	FrontierServer._step(0.5)
	runDelayed()
end
check(#critterFor(b) <= 1, "Standing still drew critters like mining")

-- Out at the edge: tougher critters, from level 9.
clearCritters()
stand(center + Vector3.new(360, 5, 0))
local edgeBug
swingFor(200, 0.4, function()
	for _, enemy in critterFor(b) do
		if KaijuWilds._wilds[enemy].Band == "Edge" then
			edgeBug = enemy
		end
	end
	if not edgeBug then
		-- (and on past the warning)
		now += Frontier.Rift.Hop
		runDelayed()
	end
	return edgeBug ~= nil
end)
check(edgeBug ~= nil and b:GetAttribute("FrontierBand") == "Edge", "No critters at the edge")
local edgeLevel = KaijuWilds._wilds[edgeBug].Level
check(edgeLevel >= 9 and edgeLevel <= 13, "An edge critter's level: " .. tostring(edgeLevel))
check(edgeBug.Humanoid.MaxHealth > bug.Humanoid.MaxHealth, "An edge critter isn't tougher")
check(#critterFor(b) <= Frontier.Caps.Edge, "More critters than the edge allows")

-- A mech's pilot: their strikes make noise too, and the critters come for them.
clearCritters()
b:SetAttribute("MechPilot", "Hauler1")
check(KaijuWilds.prey(b) and FrontierServer._eligible(b), "A pilot is safe from the critters")
for _ = 1, 120 do
	now += 0.5
	FrontierServer.swing(b, 3)
	FrontierServer._step(0.5)
	runDelayed()
	if #critterFor(b) > 0 then
		break
	end
end
check(#critterFor(b) > 0, "A mech's mining drew no critters")
b:SetAttribute("MechPilot", nil)
-- Seated in anything else: no rifts round them.
clearCritters()
local seat = make("Part")
b.Character:FindFirstChildOfClass("Humanoid").SeatPart = seat
swingFor(60, 0.5)
check(#critterFor(b) == 0, "Critters came for someone seated")
b.Character:FindFirstChildOfClass("Humanoid").SeatPart = nil
-- Back to the core: their critters give up and slip back through a rift.
swingFor(200, 0.4, function()
	now += Frontier.Rift.Hop
	runDelayed()
	return #critterFor(b) > 0
end)
local leaver = critterFor(b)[1]
check(leaver ~= nil, "No critter to send home")
stand(center + Vector3.new(40, 5, 0))
leaver.Root.CFrame = CFrame.new(center + Vector3.new(200, 5, 0))
leaver.Home = leaver.Root.Position
before = #rifts()
for _ = 1, 20 do
	now += 0.5
	KaijuWilds._brain(leaver, now)
	runDelayed()
	if not leaver.Alive then
		break
	end
end
check(not leaver.Alive and KaijuWilds._wilds[leaver] == nil, "A critter stayed with its miner safe in the core")
check(#rifts() > 0, "It left without a rift")
-- A critter drawn by nobody still leaves when there's nobody to fight (it
-- used to wander home forever).
clearCritters()
local stray = KaijuWilds.spawnBug(center + Vector3.new(250, 0, 200), { Band = "Fringe" })
stray.Home = stray.Root.Position
for _ = 1, 20 do
	now += 0.5
	KaijuWilds._brain(stray, now)
	runDelayed()
	if not stray.Alive then
		break
	end
end
check(not stray.Alive, "A critter with nobody to chase never left")

-- Wandering rifts ------------------------------------------------------------------------------------------
-- One opens by itself Near to Far studs from someone out there, lingering;
-- its critters roam round it, and only go for their player once they're near.
clearCritters()
table.clear(notes)
stand(center + Vector3.new(250, 5, 0))
FrontierServer._setWanderAt(0)
now += 0.5
FrontierServer._step(0.5)
FrontierServer._setWanderAt(math.huge)
local wanderRift
for _, rift in rifts() do
	if rift:GetAttribute("CloseAt") - rift:GetAttribute("HopAt") >= 4 then
		wanderRift = rift
	end
end
check(wanderRift ~= nil and #FrontierServer._wanders == 1, "No wandering rift opened near someone out there")
local off = Vector3.new(wanderRift.Position.X - rootB.Position.X, 0, wanderRift.Position.Z - rootB.Position.Z).Magnitude
check(off >= Frontier.Wander.Near - 1 and off <= Frontier.Wander.Far + 1, "A wandering rift's distance: " .. off)
check(wanderRift:GetAttribute("Prey") == b.UserId, "A wandering rift isn't tied to anyone")
now = wanderRift:GetAttribute("HopAt") + 0.05
runDelayed()
local roamers = critterFor(b)
check(#roamers >= 2 and KaijuWilds._wilds[roamers[1]].Wander ~= nil, "No critters roamed out of the wandering rift")
local roamer = roamers[1]
KaijuWilds._brain(roamer, now)
check(roamer.Foe == nil and roamer.Humanoid.MovingTo ~= nil, "A wandering critter went straight for its player")
local fromRift = roamer.Humanoid.MovingTo - roamer.Home
check(Vector3.new(fromRift.X, 0, fromRift.Z).Magnitude <= Frontier.Wander.Roam + 0.1, "It roamed off its patch")
stand(roamer.Root.Position + Vector3.new(6, 0, 0))
KaijuWilds._brain(roamer, now)
check(roamer.Foe == b, "A wandering critter let its player walk right up")
-- Cleared, every one killed: everyone who helped is Rift Charged.
for i, enemy in roamers do
	if i == 1 then
		enemy.KaijuCredit = { [a] = 5 }
	end
	Enemies.damage(enemy, 1e6, b)
end
check((b:GetAttribute("RiftCharged") or 0) > now and (a:GetAttribute("RiftCharged") or 0) > now, "Nobody Rift Charged")
check(noted(b, "Rift Charged"), "Nobody told them they're Rift Charged")
check(#FrontierServer._wanders == 0, "A cleared wandering rift stayed")
-- One whose player has wandered off by the time they'd hop out: it seals empty.
clearCritters()
a:SetAttribute("RiftCharged", nil)
b:SetAttribute("RiftCharged", nil)
FrontierServer._setWanderAt(0)
now += 0.5
FrontierServer._step(0.5)
FrontierServer._setWanderAt(math.huge)
check(#FrontierServer._wanders == 1, "No second wandering rift")
stand(center + Vector3.new(40, 5, 0))
now += Frontier.Rift.Hop + 0.1
runDelayed()
check(#critterFor(b) == 0 and #FrontierServer._wanders == 0, "A wandering rift let critters out with nobody near")
check(not FrontierServer._pending[b], "Its critters are still on their way")

-- Moon bugs pay: EXP to every kaiju that fought one (by its level and
-- band, a quarter after the day's first 60), coins by band to whoever did
-- the most, within the day's cap; a kill no kaiju was in pays no EXP.
clearCritters()
local bugs = {}
for i = 1, 5 do
	local at = center + Vector3.new(320 + i * 4, 0, 0)
	table.insert(bugs, KaijuWilds.spawnBug(at, { Prey = a, Band = "Edge", Level = 10, Facing = rootA.Position }))
end
check(
	bugs[1].OutpostCreature and bugs[1].Model:GetAttribute("MoonBug") and bugs[1].Model:GetAttribute("Posed"),
	"A bug isn't marked"
)
-- A bug's bite on your kaiju's fresh guard is parried, and the bug reels.
local biter = KaijuWilds.spawnBug(center + Vector3.new(330, 0, 0), { Band = "Fringe" })
KaijuWilds._wilds[biter].Prey = nil
pet = KaijuServer.pets()[a]
biter.Root.CFrame = CFrame.new(pet.Root.Position + Vector3.new(1.5, 0, 0))
biter.Home, biter.LastAttack, pet.RecallUntil = biter.Root.Position, 0, 0
settle(pet.Fighter)
KaijuFight.raiseGuard(pet.Fighter, now, 2)
local health = pet.Humanoid.Health
KaijuWilds._brain(biter, now)
check(biter.Foe == pet and pet.Humanoid.Health == health, "A bug's bite on a fresh guard wasn't parried")
check(biter.StunUntil >= now + KaijuFight.ParryStagger, "A parried bug didn't reel")
local function expOf(record)
	local total = record.Exp
	for level = 1, record.Level - 1 do
		total += Kaiju.expToNext(level)
	end
	return total
end
roster.Bugs = nil -- (a fresh day)
local coins = profiles[a].Coins
local exp = expOf(Kaiju.active(roster))
bugs[1].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[1], 1e6)
check(profiles[a].Coins == coins + Frontier.Coins.Edge, "An edge bug paid the wrong coins")
check(expOf(Kaiju.active(roster)) - exp == Frontier.critterExp(10, "Edge", 0), "A kaiju that fought got the wrong EXP")
check(roster.Bugs.Count == 1, "The day's critters weren't counted")
-- After the day's first 60: a quarter.
roster.Bugs.Count = Frontier.Exp.Daily
exp = expOf(Kaiju.active(roster))
bugs[2].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[2], 1e6)
check(expOf(Kaiju.active(roster)) - exp == Frontier.critterExp(10, "Edge", Frontier.Exp.Daily), "No quarter after 60")
-- A kill with no kaiju in it (a pick, a hunter): coins, no EXP for anyone.
exp = expOf(Kaiju.active(roster))
coins = profiles[a].Coins
Enemies.damage(bugs[3], 1e6, a)
check(expOf(Kaiju.active(roster)) == exp, "A kaiju that never fought got EXP")
check(profiles[a].Coins == coins + Frontier.Coins.Edge, "A pick's kill paid no coins")
-- The day's cap.
roster.Bugs.Coins = Kaiju.Bug.DailyCoins - 1
coins = profiles[a].Coins
bugs[4].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[4], 1e6)
check(profiles[a].Coins == coins + 1, "The day's cap let more through")
bugs[5].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[5], 1e6)
check(profiles[a].Coins == coins + 1, "Coins past the day's cap")

-- The pick's bonk: a share of a critter's health, yours, back it goes,
-- reeling; never on a wild kaiju.
local target = KaijuWilds.spawnBug(center + Vector3.new(300, 0, 40), { Prey = b, Band = "Fringe", Level = 2 })
stand(target.Root.Position + Vector3.new(-4, 0, 0))
local full = target.Humanoid.Health
check(KaijuWilds.critterOf(target.Model) == target, "A critter isn't found from its model")
check(KaijuWilds.bonk(target, b, rootB.Position), "The bonk didn't land")
local taken = full - target.Humanoid.Health
local share = target.Humanoid.MaxHealth * Frontier.Bonk.Share
check(math.abs(taken - share) <= 1, "The bonk took the wrong share: " .. taken)
check(target.Damage[b] and target.Damage[b] > 0, "The bonk isn't credited to the miner")
check(target.Root.AssemblyLinearVelocity.X > 0 and target.StunUntil > now, "It wasn't knocked back, reeling")
for _, wildEntry in KaijuWilds._wilds do
	if not wildEntry.Bug then
		check(KaijuWilds.critterOf(wildEntry.Enemy.Model) == nil, "A wild kaiju counts as a critter")
		check(not KaijuWilds.bonk(wildEntry.Enemy, b, rootB.Position), "A wild kaiju was bonked")
		break
	end
end

-- The vein guardian ------------------------------------------------------------------------------------------

-- One more wild kaiju, asleep in front of the guarded Rift Vein: levels 16
-- to 20, the third swing at its vein wakes it, it goes for a plain miner
-- too, it never burrows of old age, it moves with its vein, and killed it
-- pays coins and nothing takes its place until the vein moves.
local function across(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end
check(Kaiju.Wild.Max == 4 and Kaiju.Wild.Pack == 2, "Not 4 wild kaiju roaming, in pairs")
local Guarded = Frontier.Veins.Guarded
local veinScar = CFrame.new(center + Vector3.new(0, 0, -(Frontier.Rim + 2)))
KaijuWilds._setGuardAt(veinScar)
KaijuWilds._spawnGuardian()
local guard = KaijuWilds._guardian()
check(guard ~= nil and guard.Guard == true and not guard.Bug, "No vein guardian")
local keeper = guard.Enemy
check(guard.Level >= 16 and guard.Level <= 20, "A guardian at level " .. guard.Level)
check(keeper.Model:GetAttribute("KaijuGuardian") == true, "The guardian isn't marked")
check(keeper.Model:GetAttribute("KaijuWild") == true, "The guardian can't be tamed")
local guardHealth = Kaiju.stats(guard.Species, guard.Level, guard.Soul.Tier).Health * Kaiju.Wild.Health
check(keeper.Humanoid.MaxHealth == math.floor(guardHealth + 0.5), "The guardian's health")
local sleepAt = veinScar.Position + Vector3.new(0, 0, Frontier.Guardian.Home)
check(across(keeper.Home - sleepAt).Magnitude < 1, "It doesn't sleep in front of its vein")
KaijuWilds._spawnGuardian()
check(KaijuWilds._guardian() == guard, "A second guardian")
-- Asleep: a miner walking by, or swinging at another vein, doesn't wake it,
-- nor do two swings at its own.
stand(keeper.Root.Position + Vector3.new(3, 0, 0))
table.clear(playerHits)
keeper.LastAttack = 0
KaijuWilds._brain(keeper, now)
check(keeper.Foe == nil, "The guardian woke for a miner walking by")
KaijuWilds.veinSwing(Guarded + 1, b)
check(guard.Swings == 0, "A swing at another vein counted")
-- The first stirs it (it looks round at the miner), the second makes it roar.
KaijuWilds.veinSwing(Guarded, b)
check(guard.Plan and guard.Plan.Mood == "Look", "The first swing didn't stir it")
check(keeper.Model:GetAttribute("KaijuMood") == "Look", "Its stirring isn't shown")
KaijuWilds.veinSwing(Guarded, b)
check(guard.Plan and guard.Plan.Mood == "Roar", "The second swing didn't make it roar")
KaijuWilds._brain(keeper, now)
check(keeper.Foe == nil and next(guard.Engaged) == nil, "The guardian woke before the third swing")
table.clear(notes)
KaijuWilds.veinSwing(Guarded, b)
check(guard.Engaged[b] ~= nil and noted(b, "guardian woke"), "The third swing didn't wake it")
KaijuWilds._brain(keeper, now)
check(keeper.Foe == b, "It didn't go for the miner who woke it")
check(keeper.Model:GetAttribute("KaijuMood") == nil and guard.Plan == nil, "It fights in a mood")
for _ = 1, 80 do
	now += 0.15
	stand(keeper.Root.Position + Vector3.new(3, 0, 0))
	KaijuWilds._brain(keeper, now)
end
check(#playerHits > 0 and playerHits[#playerHits][1] == b, "It never struck the miner")
-- Awake, whoever mines its vein is on its list too.
check(guard.Engaged[a] == nil, "It started on someone who never touched its vein")
KaijuWilds.veinSwing(Guarded, a)
check(guard.Engaged[a] ~= nil, "Mining its vein while it's awake didn't count")
-- Old age doesn't move it on.
guard.Born, guard.LastFight, keeper.LastHit = now - Kaiju.Wild.Lifetime - 100, now - 100, 0
KaijuWilds._lifetimes(now)
check(keeper.Alive and KaijuWilds._guardian() == guard, "The guardian burrowed of old age")
-- Left alone at home a while, it goes back to sleep: three swings again.
table.clear(guard.Engaged)
guard.Engaged[a] = now - 100
guard.Swings = 2
stand(center + Vector3.new(300, 0, 0))
rootA.CFrame = CFrame.new(center + Vector3.new(-300, 0, 0))
keeper.Root.CFrame = CFrame.new(keeper.Home)
keeper.FoeVictim, keeper.LastSource, keeper.LastPet = nil, nil, nil
KaijuWilds._brain(keeper, now)
check(guard.Swings == 0, "Asleep again, it still counts the swings from before")
-- Another vein moving leaves it be; its own moving takes it along.
local newScar = CFrame.new(center + Vector3.new(Frontier.Rim + 2, 0, 0))
KaijuWilds.veinMoved(Guarded + 1, newScar)
check(KaijuWilds._guardian() == guard and keeper.Alive, "Another vein moving moved the guardian")
KaijuWilds.veinMoved(Guarded, newScar)
local moved = KaijuWilds._guardian()
check(not keeper.Alive and KaijuWilds._wilds[keeper] == nil, "The old guardian stayed behind")
check(moved ~= nil and moved ~= guard and moved.Enemy.Alive, "No guardian at the vein's new site")
local newSleep = newScar.Position - Vector3.new(Frontier.Guardian.Home, 0, 0)
check(across(moved.Enemy.Home - newSleep).Magnitude < 1, "The guardian didn't sleep by its vein's new site")
-- Killed: its Gemsoul, and coins, to whoever did the most; and nothing
-- takes its place until its vein moves.
Kaiju.roster(profiles[b]).Bugs = nil
local coinsBefore = profiles[b].Coins
moved.Enemy.Damage[b] = 100
Enemies.damage(moved.Enemy, 1e6, nil, false, nil, nil, nil)
check(not moved.Enemy.Alive and KaijuWilds._guardian() == nil, "The guardian didn't die")
check(profiles[b].Coins == coinsBefore + Frontier.Coins.Guardian, "The guardian paid the wrong coins")
check(noted(b, "vein's guardian"), "Not told they beat the guardian")
now += Kaiju.Wild.Respawn + 1
runDelayed()
check(KaijuWilds._guardian() == nil, "Another guardian came before its vein moved")
KaijuWilds.veinMoved(Guarded, veinScar)
check(KaijuWilds._guardian() ~= nil, "No fresh guardian once its vein moved")

-- A wild kaiju's day ---------------------------------------------------------------------------------------

-- Ten minutes of the Outpost with nobody fighting: every wild one wanders
-- round its pack's den (and the den moves on), stops to sniff, look about,
-- lie down or roar, keeps to the frontier and near its packmate; the
-- guardian paces its beat and naps. (Each step every one thinks, then walks
-- toward where it was sent, at its walking speed.)
local center2 = outpost * Vector3.new(1, 0, 1) + Vector3.new(0, outpost.Y, 0)
local function aWildDay()
	clearCritters()
	now += Kaiju.Wild.Respawn + 1
	runDelayed()
	while true do
		local count = 0
		for _, entry in KaijuWilds._wilds do
			if not entry.Bug and not entry.Guard and entry.Enemy.Alive then
				count += 1
			end
		end
		if count >= Kaiju.Wild.Max then
			break
		end
		KaijuWilds._spawnWild()
	end
	rootA.CFrame = CFrame.new(center2)
	stand(center2 + Vector3.new(4, 0, 0))
	pet.Root.CFrame = CFrame.new(center2 + Vector3.new(0, 0, 4))
	local roamers, walked, moods, worst, dens = {}, {}, {}, {}, {}
	for _, entry in KaijuWilds._wilds do
		if not entry.Bug and entry.Enemy.Alive then
			table.insert(roamers, entry)
			walked[entry], moods[entry], worst[entry] = 0, {}, 0
			entry.Engaged = entry.Engaged or {}
			table.clear(entry.Engaged)
		end
	end
	for _, pack in KaijuWilds._packs do
		dens[pack] = pack.Den
	end
	local apartMost, inCore, inBuilding = 0, 0, 0
	for _ = 1, 4000 do
		now += 0.15
		for _, entry in roamers do
			local e = entry.Enemy
			if e.Alive then
				KaijuWilds._brain(e, now)
				local to = e.Humanoid.MovingTo
				if to then
					local from = e.Root.Position
					local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
					local step = math.min(d.Magnitude, (e.Humanoid.WalkSpeed or 0) * 0.15)
					if d.Magnitude > 1e-3 and step > 0 then
						e.Root.CFrame = CFrame.new(from + d.Unit * step)
						walked[entry] += step
					end
				end
				moods[entry][entry.Plan and entry.Plan.Mood or "?"] = true
				local range = if entry.Guard then Kaiju.Roam.Guard.Range else Kaiju.Roam.Range
				worst[entry] = math.max(worst[entry], across(e.Root.Position - e.Home).Magnitude - range)
				if not entry.Guard and Frontier.distance(e.Root.Position, outpost) < Frontier.Core then
					inCore += 1
				end
				if not entry.Guard and across(e.Root.Position - keepOut[1][1]).Magnitude < keepOut[1][2] - 4 then
					inBuilding += 1
				end
			end
		end
		for _, pack in KaijuWilds._packs do
			local first, second = pack.Members[1], pack.Members[2]
			if first and second then
				local gap = across(first.Enemy.Root.Position - second.Enemy.Root.Position).Magnitude
				apartMost = math.max(apartMost, gap)
			end
		end
	end
	check(#roamers == Kaiju.Wild.Max + 1, "Not every wild kaiju (and the guardian) out: " .. #roamers)
	for _, entry in roamers do
		local name = (if entry.Guard then "The guardian" else "A wild kaiju") .. " (" .. entry.Species .. ")"
		local count = 0
		for _ in moods[entry] do
			count += 1
		end
		if entry.Guard then
			check(walked[entry] > 15, name .. " never paced: " .. walked[entry])
			check(moods[entry].Sleep, name .. " never napped")
		else
			check(walked[entry] > 120, name .. " hardly moved in ten minutes: " .. math.floor(walked[entry]))
			check(count >= 4, name .. " did only " .. count .. " things all day")
		end
		-- (Past its range only as its den moves on, by a step at most: then it walks over.)
		local slack = if entry.Guard then 8 else Kaiju.Roam.Drift[2] + 8
		check(worst[entry] <= slack, name .. " strayed " .. math.floor(worst[entry]) .. " studs past its range")
	end
	check(inCore == 0, "A wild kaiju wandered into the core")
	check(inBuilding == 0, "A wild kaiju wandered into a keep-out zone")
	check(apartMost < 50, "Packmates drifted " .. math.floor(apartMost) .. " studs apart")
	local drifted = false
	for pack, den in dens do
		if table.find(KaijuWilds._packs, pack) and across(pack.Den - den).Magnitude >= Kaiju.Roam.Drift[1] then
			drifted = true
		end
	end
	check(drifted, "No pack's den moved on in ten minutes")
	for _, entry in roamers do
		local shown = entry.Enemy.Model:GetAttribute("KaijuMood")
		local mood = entry.Plan and entry.Plan.Mood
		check(shown == (if mood == "Walk" then nil else mood), "Its mood isn't shown as it is")
	end
	-- Someone comes close: it stops and looks them over (a roar at times), and
	-- leaves them be.
	-- (A pack's leader, or one alone: a packmate far behind its leader gets
	-- up to follow instead.)
	local watcher
	for _, entry in roamers do
		if not entry.Guard and (not entry.Pack or entry.Pack.Members[1] == entry) then
			watcher = entry
			break
		end
	end
	local we = watcher.Enemy
	watcher.Plan = { Mood = "Walk", Until = now + 10, To = we.Home, From = we.Root.Position, Check = now }
	watcher.Noticed = {}
	stand(we.Root.Position + Vector3.new(10, 0, 0))
	table.clear(playerHits)
	KaijuWilds._brain(we, now)
	local mood = watcher.Plan and watcher.Plan.Mood
	check(mood == "Look" or mood == "Roar", "It didn't stop to look at someone close: " .. tostring(mood))
	check(we.Root.CFrame.LookVector.X > 0.9, "It didn't turn to them")
	check(we.Foe == nil and #playerHits == 0, "It went for someone who only came close")
	check(we.Humanoid.MovingTo and (we.Humanoid.MovingTo - we.Root.Position).Magnitude < 0.01, "It kept walking")
end
aWildDay()

-- Your kaiju, with you standing about: after a few seconds it potters round
-- you; you move on and it's up and after you.
pet = KaijuServer.pets()[a]
local function petPotters()
	pet.RecallUntil, pet.StunUntil, pet.Target = 0, 0, nil
	pet.Plan, pet.IdleSpot = nil, nil
	rootA.CFrame = CFrame.new(center2)
	pet.Root.CFrame = CFrame.new(center2 + Vector3.new(3, 0, 5))
	local pottered = {}
	for _ = 1, 120 do
		now += 0.15
		KaijuServer._think(pet, now, 0.15)
		if pet.Plan then
			pottered[pet.Plan.Mood] = true
		end
	end
	local kinds = 0
	for _ in pottered do
		kinds += 1
	end
	check(kinds >= 2, "Your kaiju stood stock-still beside you")
	local petMood = pet.Plan and pet.Plan.Mood
	check(pet.Model:GetAttribute("KaijuMood") == (if petMood == "Walk" then nil else petMood), "Its mood isn't shown")
	rootA.CFrame = CFrame.new(center2 + Vector3.new(0, 0, -12))
	KaijuServer._think(pet, now + 0.15, 0.15)
	check(pet.Plan == nil and pet.Model:GetAttribute("KaijuMood") == nil, "It kept pottering as you left")
	local after = pet.Humanoid.MovingTo
	check(after and (after - pet.Root.Position).Magnitude > 5, "It didn't come after you")
end
petPotters()

-- The Outpost for fifteen minutes ---------------------------------------------------------------------------

-- A miner at work out at the Edge (critters come for the noise), the wild
-- kaiju fresh (as at a server's start) going about their day, the guardian
-- at its vein, their lifetimes running out and others coming up: nothing
-- errors, the critters keep to their caps and come and go, and the quarry
-- is never left without its wild kaiju.
local function outpostSoak()
	clearCritters()
	FrontierServer._setWanderAt(now + 30)
	for _, entry in KaijuWilds._wilds do
		if not entry.Bug then
			entry.Born, entry.LastFight, entry.Enemy.LastHit = now, now, 0
		end
	end
	local edgeSpot = center2 + Vector3.new(330, 0, 0)
	stand(edgeSpot)
	local errors, firstError = 0, nil
	local mostCritters, leastWild, emptyFor, wildRecords = 0, math.huge, 0, 0
	local dt, swingIn, upkeepIn = 0.25, 0, 0
	for step = 1, 3600 do
		now += dt
		swingIn -= dt
		if swingIn <= 0 then
			swingIn = 1.25
			FrontierServer.swing(b)
		end
		FrontierServer._step(dt)
		runDelayed()
		upkeepIn -= dt
		if upkeepIn <= 0 then
			upkeepIn = 5
			KaijuWilds._lifetimes(now)
		end
		local critters, roaming, records = 0, 0, 0
		for e, entry in KaijuWilds._wilds do
			records += 1
			if e.Alive then
				local ok, err = pcall(KaijuWilds._brain, e, now)
				if not ok then
					errors += 1
					firstError = firstError or err
				end
				local to = e.Humanoid.MovingTo
				if to and e.Alive then
					local from = e.Root.Position
					local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
					local stride = math.min(d.Magnitude, (e.Humanoid.WalkSpeed or 0) * dt)
					if d.Magnitude > 1e-3 and stride > 0 then
						e.Root.CFrame = CFrame.new(from + d.Unit * stride)
					end
				end
				if entry.Bug then
					critters += 1
				elseif not entry.Guard then
					roaming += 1
				end
			end
		end
		stand(edgeSpot) -- (the miner keeps at it)
		mostCritters = math.max(mostCritters, critters)
		wildRecords = math.max(wildRecords, records)
		if step * dt > 30 then
			leastWild = math.min(leastWild, roaming)
			if roaming == 0 then
				emptyFor += dt
			end
		end
	end
	check(errors == 0, "Brains errored " .. errors .. " times: " .. tostring(firstError))
	check(mostCritters >= 1, "No critters came for a miner at the Edge in fifteen minutes")
	check(mostCritters <= Frontier.Caps.Server, "Critters past the server's cap: " .. mostCritters)
	check(emptyFor == 0, "The quarry had no wild kaiju for " .. emptyFor .. " seconds")
	check(leastWild >= Kaiju.Wild.Max - 2, "Down to " .. leastWild .. " wild kaiju at one time")
	check(wildRecords <= Kaiju.Wild.Max + 1 + Frontier.Caps.Server + 4, "Wild records pile up: " .. wildRecords)
	FrontierServer._setWanderAt(math.huge)
	clearCritters()
end
outpostSoak()

-- Rifts open on open ground, level with the miner: not on top of the
-- container stack just ahead of them.
local function riftsOnOpenGround()
	clearCritters()
	FrontierServer._setWanderAt(math.huge)
	local miner = center + Vector3.new(330, 5, 0)
	stand(miner) -- (facing east, at the stack)
	local function onStack(p: Vector3): boolean
		return p.X > miner.X + 12 and p.X < miner.X + 26 and math.abs(p.Z - miner.Z) < 5
	end
	local raycast = workspaceObject.Raycast
	workspaceObject.Raycast = function(_, origin)
		if onStack(origin) then
			return { Position = Vector3.new(origin.X, miner.Y + 8, origin.Z), Instance = workspaceObject }
		end
		return nil
	end
	local opened, count = {}, 0
	for _ = 1, 1500 do
		swingFor(1, 0.4)
		for _, rift in rifts() do
			if not opened[rift] then
				opened[rift] = true
				count += 1
			end
		end
		if count >= 6 then
			break
		end
		if count > 0 and #critterFor(b) >= 2 then
			clearCritters()
		end
	end
	workspaceObject.Raycast = raycast
	check(count >= 3, "Too few rifts opened to tell: " .. count)
	for rift in opened do
		check(not onStack(rift.Position), "A rift opened on top of the container stack")
	end
	clearCritters()
end
riftsOnOpenGround()

-- Start on one of a pack and its packmate close by joins in (one far off
-- doesn't); and a wild one only sets off where the way is clear.
local function packsAndPaths()
	local pack
	for _, candidate in KaijuWilds._packs do
		if #candidate.Members == 2 then
			pack = candidate
			break
		end
	end
	check(pack ~= nil, "No pair to test")
	local first, second = pack.Members[1], pack.Members[2]
	table.clear(first.Engaged)
	table.clear(second.Engaged)
	first.Enemy.Root.CFrame = CFrame.new(pack.Den)
	second.Enemy.Root.CFrame = CFrame.new(pack.Den + Vector3.new(Kaiju.Wild.Defend - 10, 0, 0))
	rootA.CFrame = CFrame.new(first.Enemy.Root.Position + Vector3.new(3, 0, 0))
	pet.Root.CFrame = CFrame.new(first.Enemy.Root.Position + Vector3.new(2.5, 0, 0))
	pet.RecallUntil = 0
	check(registered.KaijuChallenge(a, first.Enemy.Model).Ok, "Couldn't challenge one of a pair")
	check(first.Engaged[a] and second.Engaged[a], "Its packmate close by didn't join in")
	table.clear(first.Engaged)
	table.clear(second.Engaged)
	second.Enemy.Root.CFrame = CFrame.new(pack.Den + Vector3.new(Kaiju.Wild.Defend + 10, 0, 0))
	registered.KaijuChallenge(a, first.Enemy.Model)
	check(first.Engaged[a] and not second.Engaged[a], "A packmate far off joined in")
	table.clear(first.Engaged)
	pet.Root.CFrame = CFrame.new(center + Vector3.new(0, 0, 4))
	rootA.CFrame = CFrame.new(center)
	-- (Something solid everywhere east of it: it only ever sets off west.)
	local we = first.Enemy
	we.Root.CFrame = CFrame.new(pack.Den)
	local spherecast = workspaceObject.Spherecast
	workspaceObject.Spherecast = function(_, _from, _radius, direction)
		if direction.X > 0 then
			return { Instance = { CanCollide = true }, Position = we.Root.Position }
		end
		return nil
	end
	local walks, east = 0, 0
	for _ = 1, 400 do
		now += 0.15
		first.Plan = nil
		KaijuWilds._wander(we, first, now)
		if first.Plan and first.Plan.Mood == "Walk" then
			walks += 1
			if first.Plan.To.X > we.Root.Position.X + 0.01 then
				east += 1
			end
		end
	end
	workspaceObject.Spherecast = spherecast
	check(walks >= 20, "Hardly ever set off: " .. walks)
	check(east == 0, "It set off into something solid " .. east .. " times")
end
packsAndPaths()

-- A critter goes for your kaiju before you, and your kaiju for it: they
-- take each other on. Recalled, it comes back for you.
local function crittersAndKaiju()
	clearCritters()
	pet = KaijuServer.pets()[a]
	pet.RecallUntil, pet.StunUntil, pet.Plan, pet.IdleSpot = 0, 0, nil, nil
	local spot = center + Vector3.new(-320, 5, 0)
	rootA.CFrame = CFrame.new(spot)
	pet.Root.CFrame = CFrame.new(spot + Vector3.new(3, 0, 4))
	stand(center + Vector3.new(320, 5, 0)) -- (b far away)
	local critter = KaijuWilds.spawnBug(spot + Vector3.new(14, 0, 0), { Prey = a, Band = "Edge", Level = 9 })
	check(critter ~= nil, "No critter came")
	critter.LastAttack = 0
	KaijuWilds._brain(critter, now)
	check(critter.Foe == pet, "The critter went for its player, not the kaiju beside them")
	pet.Target = nil
	KaijuServer._think(pet, now, 0.15)
	check(pet.Target == critter, "Your kaiju didn't go for the critter after it")
	-- (They trade blows: the critter's land on the kaiju, not on you.)
	table.clear(playerHits)
	local healthBefore = pet.Humanoid.Health
	critter.Root.CFrame = CFrame.new(pet.Root.Position + Vector3.new(2, 0, 0))
	for _ = 1, 20 do
		now += 0.15
		critter.FoeVictim = nil
		KaijuWilds._brain(critter, now)
	end
	check(pet.Humanoid.Health < healthBefore, "The critter never bit the kaiju")
	check(#playerHits == 0, "The critter bit you with your kaiju beside you")
	-- Recalled, it's out of reach: the critter comes back for you.
	registered.KaijuRecall(a)
	critter.FoeVictim = nil
	KaijuWilds._brain(critter, now)
	check(critter.Foe == a, "With your kaiju recalled, the critter didn't come for you")
	-- Someone else's kaiju close by draws it too, but its prey's own comes first.
	now += Kaiju.RecallSeconds + 1
	pet.RecallUntil = 0
	local other = KaijuWilds.spawnBug(spot + Vector3.new(-14, 0, 0), { Prey = b, Band = "Edge", Level = 9 })
	stand(spot + Vector3.new(-20, 0, 0))
	other.FoeVictim = nil
	KaijuWilds._brain(other, now)
	check(other.Foe == pet, "A kaiju close by didn't draw another's critter")
	clearCritters()
	pet.Root.CFrame = CFrame.new(center + Vector3.new(0, 0, 4))
	rootA.CFrame = CFrame.new(center)
	pet.Target, pet.Humanoid.Health = nil, pet.Humanoid.MaxHealth
end
crittersAndKaiju()

-- Mining with it out: EXP for every rock you break (by its size), so it
-- levels while you mine; none while it's down, none with none out.
local function minedWithIt()
	pet = KaijuServer.pets()[a]
	local record = pet.Record
	local level, exp = record.Level, record.Exp or 0
	KaijuServer.mined(a, "Boulder")
	check(
		record.Level > level or record.Exp == exp + Kaiju.MineExp.Boulder,
		"A rock mined with it out gave no EXP"
	)
	check(Kaiju.mineExp("Pebble") < Kaiju.mineExp("Boulder") and Kaiju.mineExp(nil) == Kaiju.MineExp.Pebble, "Rock EXP by size")
	level, exp = record.Level, record.Exp
	pet.Humanoid.Health = 0
	KaijuServer.mined(a, "Boulder")
	check(record.Level == level and record.Exp == exp, "A downed kaiju got mining EXP")
	pet.Humanoid.Health = pet.Humanoid.MaxHealth
	KaijuServer.mined(b, "Boulder") -- (b has none out)
	-- A long session's rocks are worth a few early levels.
	local session = { Level = 1, Exp = 0 }
	for i = 1, 130 do
		Kaiju.addExp(session, Kaiju.mineExp(if i % 8 < 3 then "Boulder" else "Pebble"))
	end
	check(session.Level >= 3 and session.Level <= 5, "A long session's mining made level " .. session.Level)
end
minedWithIt()

-- The rules' moods: the same roll, the same mood, and every one reachable.
local seen = {}
for i = 0, 99 do
	seen[Kaiju.mood(Kaiju.Roam.Moods, i / 100)] = true
end
for name in Kaiju.Roam.Moods do
	check(seen[name], "The mood " .. name .. " never comes")
	check(Kaiju.Roam.Times[name], "No time for the mood " .. name)
end
check(Kaiju.mood(Kaiju.Roam.Moods, 0.37) == Kaiju.mood(Kaiju.Roam.Moods, 0.37), "The same roll, another mood")
check(Kaiju.Scale.Guardian > Kaiju.Scale.Wild and Kaiju.Scale.Wild > Kaiju.Scale.Pet, "The sizes")

print(
	string.format(
		"PASS: %d kaiju server checks (E abilities, your kaiju, wild kaiju, duels, taming, kills, rifts, critters, the vein guardian, a wild kaiju's day)",
		checks
	)
)
