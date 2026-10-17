-- lune run tests/kaiju_server_cases.luau <repo>
-- Mini kaiju on the server, against stand-in Roblox pieces (the real
-- Shared.Kaiju, KaijuAbilities, KaijuServer and KaijuWilds; Enemies,
-- PlayerData and the models are stand-ins): every E ability lands where it
-- should; your kaiju comes out in the Outpost (a starter the first time),
-- fights creatures near you and is credited to you, is hurt by element,
-- knocked out and back; recall; switching; feeding; wild kaiju take blows
-- with the spread and their element, go after kaiju and hunters (never a
-- miner), pay EXP and their Gemsoul when killed; taming (range, half health,
-- tries, burrowing, a full roster).
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
function Enemies.damage(enemy, amount, source, _crit, _color, _heavy, element)
	if not enemy.Alive then
		return
	end
	if enemy.TakenScale then
		amount *= (enemy.TakenScale(element))
	end
	amount = math.floor(amount + 0.5)
	enemy.LastHit = os.clock()
	if source then
		enemy.Damage[source] = (enemy.Damage[source] or 0) + amount
		enemy.LastSource, enemy.LastSourceAt = source, os.clock()
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
		enemy.StunUntil = math.max(enemy.StunUntil, os.clock() + seconds)
	end
end
function Enemies.addDot(enemy, total)
	enemy.LastDot = total
end
function Enemies.hitPlayer(player, amount, element, enemy)
	table.insert(playerHits, { player, amount, element, enemy })
end
function Enemies.weakness()
	return 0
end

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
local KaijuAbilities = serverModule("KaijuAbilities")
local KaijuServer = serverModule("KaijuServer")
local KaijuWilds = serverModule("KaijuWilds")

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
	local caster = {
		Model = make("Model"),
		Root = root(Vector3.new(0, 0, 0)),
		Element = "Fire",
		Ability = id,
		Damage = 100,
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
	check((dealt.foe or 0) > 0, id .. " missed its foe")
	check(dealt.far == nil, id .. " hit a foe 200 studs away")
	check(dealt.foe <= 100 + 1e-6, id .. " dealt its foe more than the whole cast")
	if plan.Shape == "Bolt" then
		check(dealt.beside == nil, id .. " (a bolt) hit a second foe")
	end
	if plan.Shape == "Blast" or plan.Shape == "Nova" or plan.Shape == "Line" or plan.Shape == "Field" then
		check((dealt.beside or 0) > 0, id .. " (an area) missed the foe beside")
	end
	if plan.Status and plan.Shape ~= "Storm" then
		check(statuses[plan.Status], id .. " didn't leave " .. plan.Status)
	end
	if plan.Show then
		local shown = false
		for _, entry in fxs do
			shown = shown or (entry[1] == "TriadShow" and entry[3] == plan.Show)
		end
		check(shown, id .. " didn't draw its own look")
	end
	check(caster.Model:GetAttribute("KaijuAbilityAt") == now, id .. ": no cast time for the HUD")
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
KaijuWilds.start({
	Spawn = CFrame.new(outpost),
	Spots = { CFrame.new(outpost + Vector3.new(0, 0, -300)), CFrame.new(outpost + Vector3.new(300, 0, 0)) },
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

check(#KaijuWilds._spots == 2, "Wild spots near the landing pad were used")
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

-- Its brain: a miner walks by unbothered; a hunter or a kaiju is a foe.
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
check(enemy.Foe == a, "A wild kaiju ignored a hunter beside it")
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
-- Your kaiju near it: it fights it, and the blows are yours.
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2, 0, 0))
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(6, 0, 0))
pet.RecallUntil, pet.NextBlow, pet.NextAbility = 0, 0, now + 100
local before = enemy.Humanoid.Health
KaijuServer._think(pet, now, 0.15)
check(pet.Target == enemy, "Your kaiju ignored the wild one beside you")
check(enemy.Humanoid.Health < before and (enemy.KaijuCredit[a] or 0) > 0, "Its blow didn't land, or wasn't yours")
check(pet.Model:GetAttribute("ActionAt") == now, "No blow for the animation")
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
now += Kaiju.RecallSeconds + 1

-- Taming ------------------------------------------------------------------------------------------------------------

local Tame = registered.KaijuTame
check(not Tame(a, make("Model")).Ok, "Tamed a model that isn't a wild kaiju")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(60, 0, 0))
check(Tame(a, enemy.Model).Message:find("closer") ~= nil, "Tamed from across the quarry")
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(5, 0, 0))
enemy.Humanoid.Health = enemy.Humanoid.MaxHealth * 0.8
check(Tame(a, enemy.Model).Message:find("half") ~= nil, "Tamed one at 80%")
enemy.Humanoid.Health = enemy.Humanoid.MaxHealth * 0.2
forcedRoll = 0.99 -- (every try fails)
local first = Tame(a, enemy.Model)
check(not first.Ok and first.Chance > 0 and enemy.Model:GetAttribute("KaijuTries") == 1, "A failed try didn't count")
check(Tame(a, enemy.Model).Message:find("moment") ~= nil, "Tried again at once")
now += Kaiju.TameCooldown
Tame(a, enemy.Model)
now += Kaiju.TameCooldown
local last = Tame(a, enemy.Model)
check(last.Gone and not enemy.Alive and KaijuWilds._wilds[enemy] == nil, "Three failed tries and it stayed")
-- The next one: a lucky try.
local target = wilds[2]
local wild2 = KaijuWilds._wilds[target]
target.Root.CFrame = CFrame.new(rootA.Position + Vector3.new(4, 0, 0))
target.Humanoid.Health = target.Humanoid.MaxHealth * 0.1
forcedRoll = 0.01
local owned = Kaiju.count(roster)
local tamed = Tame(a, target.Model)
check(tamed.Ok and tamed.Tamed, "A lucky try at 10% health failed")
check(
	Kaiju.count(roster) == owned + 1 and roster.List[tamed.Id].Species == wild2.Species,
	"The tamed kaiju isn't yours"
)
check(
	roster.List[tamed.Id].Level == wild2.Level and roster.List[tamed.Id].Soul.Element == wild2.Element,
	"It changed taming"
)
check(not target.Alive, "The tamed one still roams")
-- A full roster: no taming.
local third = wilds[3]
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

-- Moon bugs: swarms of brainrot bodies; a kill pays EXP and a couple of
-- coins, up to the day's cap.
local bugs = {}
for bugEnemy, entry in KaijuWilds._wilds do
	if entry.Bug and bugEnemy.Alive then
		table.insert(bugs, bugEnemy)
	end
end
check(#bugs >= Kaiju.Bug.Swarms * Kaiju.Bug.SwarmSize[1], "Too few moon bugs: " .. #bugs)
check(
	bugs[1].OutpostCreature and bugs[1].Model:GetAttribute("MoonBug") and bugs[1].Model:GetAttribute("Posed"),
	"A bug isn't marked"
)
local coins = profiles[a].Coins
local exp = Kaiju.active(roster).Exp
local level = Kaiju.active(roster).Level
bugs[1].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[1], 1e6)
check(profiles[a].Coins == coins + Kaiju.Bug.Coins, "A bug paid no coins")
check(Kaiju.active(roster).Exp > exp or Kaiju.active(roster).Level > level, "A bug gave no EXP")
roster.Bugs.Coins = Kaiju.Bug.DailyCoins - 1
bugs[2].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[2], 1e6)
check(profiles[a].Coins == coins + Kaiju.Bug.Coins + 1, "The day's cap let more through")
bugs[3].KaijuCredit = { [a] = 10 }
Enemies.damage(bugs[3], 1e6)
check(profiles[a].Coins == coins + Kaiju.Bug.Coins + 1, "Coins past the day's cap")

print(string.format("PASS: %d kaiju server checks (E abilities, your kaiju, wild kaiju, taming, kills)", checks))
