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

-- A whole duel: your kaiju and the wild one, twenty seconds of it.
pet.Root.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(2.5, 0, 0))
rootA.CFrame = CFrame.new(enemy.Root.Position + Vector3.new(6, 0, 0))
settle(fighter)
settle(wf)
enemy.LastPet, enemy.LastPetAt, enemy.FoeVictim = pet, now, nil
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

print(
	string.format(
		"PASS: %d kaiju server checks (E abilities, your kaiju, wild kaiju, duels, taming, kills, rifts, critters)",
		checks
	)
)
